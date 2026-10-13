-- Server-owned authority only. No net routes/client integration are enabled yet.
WeaponCharacterAmmoService={}
local S=WeaponCharacterAmmoService
local runtime=WeaponCharacterAmmoRuntime.New(function(source,session,character)
    return Config.CharacterAmmunitionEnabled==true and CoreAdapter.IsSessionCurrent(source,session,character)
end)
local sequence=0
local loadouts={}
local opening={}
local function copy(value)
    if type(value)~='table' then return value end
    local out={}; for key,item in pairs(value) do out[key]=copy(item) end; return out
end
local function failure(code) return {ok=false,error={code=code,message=code}} end
local function enabled() return Config.CharacterAmmunitionEnabled==true end
function S.Open(source,limits)
    if not enabled() then return failure('character_ammunition_disabled') end
    if loadouts[source] then return failure('native_loadout_release_required') end
    limits=copy(limits)
    local reservation=opening[source]
    local resolved=CoreAdapter.ResolveSession(source)
    if not resolved.ok then return resolved end
    local session=resolved.value
    if not reservation or opening[source]~=reservation then return failure('open_reservation_lost') end
    reservation.sessionId=session.sessionId
    local context={actorSource=source,characterId=session.characterId,sessionId=session.sessionId}
    local ok,baseline=pcall(function() return exports['feather-inventory']:GetCharacterAmmunitionSnapshot(context,copy(limits)) end)
    if not ok then return failure('inventory_snapshot_unavailable') end
    if type(baseline)~='table' then return failure('invalid_snapshot') end
    if not baseline.ok then return baseline end
    if opening[source]~=reservation or not enabled()
        or not CoreAdapter.IsSessionCurrent(source,session.sessionId,session.characterId) then
        return failure('open_context_changed')
    end
    sequence=sequence+1
    local epoch=('%s:%s:%s:%s'):format(session.sessionId,os.time(),GetGameTimer(),sequence)
    local value,reason=runtime.Open({source=source,characterId=session.characterId,sessionId=session.sessionId},baseline.value,limits,epoch)
    return value and {ok=true,value=value} or failure(reason)
end
function S.ConfirmRestore(source,report)
    if not enabled() then return failure('character_ammunition_disabled') end
    if loadouts[source] then
        local live=runtime.Get(source)
        if not live or type(report)~='table' or report.epoch~=live.epoch
            or report.sessionId~=live.sessionId or report.characterId~=live.characterId then
            return failure('stale_loadout_restore')
        end
        local checked=S.ValidateLoadout(source)
        if not checked.ok then return checked end
    end
    local value,reason=runtime.ConfirmRestore(source,report)
    return value and {ok=true,value=value} or failure(reason)
end
-- Dormant combined-open path. The Inventory snapshot binds belt + equipped item
-- revisions in one transaction; the caller still needs lifecycle movement guards
-- before dispatching creation. This function does not send/grant anything.
function S.OpenLoadout(source,catalog,policy)
    if not enabled() then return failure('character_ammunition_disabled') end
    if loadouts[source] then return failure('native_loadout_release_required') end
    -- Preserve the exact policy/catalog used before the Inventory export yields.
    catalog,policy=copy(catalog),copy(policy)
    local registry,reason=WeaponCharacterAmmoCatalog.Build(catalog,policy)
    if not registry then return failure(reason) end
    local reservation=opening[source]
    local resolved=CoreAdapter.ResolveSession(source)
    if not resolved.ok then return resolved end
    local session=resolved.value
    if not reservation or opening[source]~=reservation then return failure('open_reservation_lost') end
    reservation.sessionId=session.sessionId
    local context={actorSource=source,characterId=session.characterId,sessionId=session.sessionId}
    local ok,snapshot=pcall(function()
        return exports['feather-inventory']:GetCharacterFirearmRuntimeSnapshot(context,registry.limits)
    end)
    if not ok or type(snapshot)~='table' then return failure('inventory_runtime_snapshot_unavailable') end
    if not snapshot.ok then return snapshot end
    if opening[source]~=reservation or not enabled()
        or not CoreAdapter.IsSessionCurrent(source,session.sessionId,session.characterId) then
        return failure('open_context_changed')
    end
    if type(snapshot.value)~='table' or snapshot.value.characterId~=session.characterId
        or type(snapshot.value.equipment)~='table' then return failure('invalid_runtime_snapshot') end
    sequence=sequence+1
    local epoch=('%s:%s:%s:%s'):format(session.sessionId,os.time(),GetGameTimer(),sequence)
    local plan
    plan,reason=WeaponCharacterAmmoMaterialization.Build(snapshot.value.equipment,catalog,registry,
        {characterId=session.characterId,sessionId=session.sessionId,epoch=epoch})
    if not plan then return failure(reason) end
    local opened
    opened,reason=runtime.Open({source=source,characterId=session.characterId,sessionId=session.sessionId},
        snapshot.value,registry.limits,epoch)
    if not opened then return failure(reason) end
    loadouts[source]={sessionId=session.sessionId,characterId=session.characterId,epoch=epoch,registry=registry,catalog=catalog,
        lease=WeaponCharacterAmmoLoadoutLease.New(plan)}
    return {ok=true,value={runtime=opened,creation=plan,names=copy(registry.names),limits=copy(registry.limits)}}
end
-- Explicit recheck for lifecycle dispatch/ack integration. Does not authorize
-- arbitrary client plans, dispatch grants, or silently refresh stale revisions.
function S.ValidateLoadout(source)
    if not enabled() then return failure('character_ammunition_disabled') end
    local bound=loadouts[source]
    if not bound then return failure('loadout_not_bound') end
    if bound.invalid then return failure('loadout_frozen_release_required') end
    if not CoreAdapter.IsSessionCurrent(source,bound.sessionId,bound.characterId) then
        runtime.Revoke(source); bound.invalid=true; return failure('loadout_session_changed')
    end
    local ok,snapshot=pcall(function()
        return exports['feather-inventory']:GetCharacterFirearmRuntimeSnapshot(
            {actorSource=source,characterId=bound.characterId,sessionId=bound.sessionId},bound.registry.limits)
    end)
    if loadouts[source]~=bound then return failure('loadout_lifecycle_changed') end
    if not enabled() or bound.invalid then return failure('loadout_frozen_release_required') end
    local valid,reason
    if ok and type(snapshot)=='table' and snapshot.ok then
        valid,reason=bound.lease.Validate(snapshot.value,bound.catalog,bound.registry)
    end
    if not valid or not CoreAdapter.IsSessionCurrent(source,bound.sessionId,bound.characterId) then
        -- Stop accepting ammo reports, but retain movement/destruction holds
        -- until trusted lifecycle cleanup releases the old native copies.
        runtime.Revoke(source); bound.invalid=true; return failure(reason or 'loadout_recheck_failed')
    end
    return {ok=true,value=true}
end
function S.IsNativeItemBound(itemId)
    for _,bound in pairs(loadouts) do if bound.lease.Contains(itemId) then return true end end
    return false
end
-- Dispatch failure/timeout invalidates ammo authority but retains native holds.
-- Only a trusted lifecycle recovery may release a frozen materialization.
function S.FreezeLoadout(source,identity)
    local bound=loadouts[source]
    if not bound or type(identity)~='table' or identity.epoch~=bound.epoch
        or identity.sessionId~=bound.sessionId or identity.characterId~=bound.characterId then
        return failure('stale_loadout_freeze')
    end
    runtime.Revoke(source); bound.invalid=true
    return {ok=true,value=true}
end
local function commit(request,method)
    local ok,result=pcall(function() return exports['feather-inventory'][method](exports['feather-inventory'],request.context,request.spec) end)
    local value,reason=runtime.Complete(request.context,ok and result or {ok=false})
    return value and {ok=true,value=value} or failure(reason)
end
function S.Observe(source,report)
    if not enabled() then return failure('character_ammunition_disabled') end
    local request,reason=runtime.PrepareObservation(source,report)
    if not request then return failure(reason) end
    if request.unchanged then return {ok=true,value=request.value} end
    return commit(request,'ObserveCharacterAmmunition')
end
function S.Transfer(source,report,id,amount,operationId)
    if not enabled() then return failure('character_ammunition_disabled') end
    if loadouts[source] then
        local live=runtime.Get(source)
        if not live or type(report)~='table' or report.epoch~=live.epoch
            or report.sessionId~=live.sessionId or report.characterId~=live.characterId then
            return failure('stale_loadout_transfer')
        end
        local checked=S.ValidateLoadout(source)
        if not checked.ok then return checked end
    end
    local request,reason=runtime.PrepareTransfer(source,report,id,amount,operationId)
    if not request then return failure(reason) end
    return commit(request,'MutateCharacterAmmunition')
end
function S.CheckpointAndSeal(source,report)
    if not enabled() then return failure('character_ammunition_disabled') end
    local request,reason=runtime.PrepareFinalObservation(source,report)
    if not request then return failure(reason) end
    if request.unchanged then return {ok=true,value=request.value} end
    -- Final reductions must commit before the old epoch is eligible for reset.
    -- Complete seals in the same pure transition that accepts the DB result.
    return commit(request,'ObserveCharacterAmmunition')
end
function S.ConfirmCleanup(source,report)
    if not enabled() then return failure('character_ammunition_disabled') end
    if loadouts[source] and loadouts[source].invalid then return failure('loadout_frozen_release_required') end
    local released,reason=runtime.ConfirmCleanup(source,report)
    if not released then return failure(reason) end
    loadouts[source]=nil
    return {ok=true,value=released}
end
function S.Revoke(source,sessionId)
    if opening[source] and (not sessionId or opening[source].sessionId==sessionId) then opening[source]=nil end
    runtime.Revoke(source,sessionId)
    if loadouts[source] and (not sessionId or loadouts[source].sessionId==sessionId) then loadouts[source]=nil end
end
-- Reserve before Core/Inventory may yield. Both open paths share the slot.
-- A cancelled coroutine cannot clear a newer reservation when it resumes.
for _,name in ipairs({'Open','OpenLoadout'}) do
    local implementation=S[name]
    S[name]=function(source,...)
        if not enabled() then return failure('character_ammunition_disabled') end
        if opening[source] then return failure('open_in_flight') end
        local reservation={}
        opening[source]=reservation
        local called,result=pcall(implementation,source,...)
        if opening[source]==reservation then opening[source]=nil end
        if not called then return failure('open_failed') end
        return result
    end
end
exports('ValidateCharacterAmmoRuntimeOperation',function(context,operation,spec)
    return GetInvokingResource()=='feather-inventory' and enabled()
        and runtime.IsOperationCurrent(context,operation,spec)==true
end)
AddEventHandler('playerDropped',function() S.Revoke(source) end)
AddEventHandler('core.session.left.v1',function(session)
    -- Local Core lifecycle event, not a client-triggerable net route.
    if type(session)=='table' and session.source and session.sessionId then S.Revoke(session.source,session.sessionId) end
end)
