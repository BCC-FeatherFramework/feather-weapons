-- Server-owned protocol factory plus an explicitly requested, gated dry-run.
-- Player routes remain disabled; console alpha equipment changes are explicit.
WeaponNativeEquipmentTransition={}
local denied,identity,same
local function copy(value)
    if type(value)~='table' then return value end
    local out={}; for key,item in pairs(value) do out[key]=copy(item) end; return out
end

-- First concrete gate is a no-equipment-write roundtrip through the actual
-- normal host. Player equip routes remain disabled until CAS wiring is ready.
local function InstallDryRun()
WeaponNativeEquipmentBindings={}
local pending={}
local sequence=0
local function enabled()
    return Config.DevMode==true and Config.NativeAlphaRuntime==true
        and Config.CharacterAmmunitionEnabled==true and Config.CharacterAmmoTransportEnabled==true
end
local coordinator
local uiPending={}
local adapters={
    enabled=enabled,
    prepare=function(source,intent)
        if intent.action~='dry-run' and intent.action~='equip' and intent.action~='unequip' and intent.action~='options' then return denied('invalid_equipment_action') end
        local session=CoreAdapter.ResolveSession(source)
        local state=WeaponCharacterAmmoDispatcher.Status(source)
        if not session or not session.ok or session.value.characterId~=Config.NativeAlphaCharacterId
            or not state or state.phase~='active' or state.busy or not same(state.identity,
                {characterId=session.value.characterId,sessionId=session.value.sessionId,epoch=state.identity and state.identity.epoch}) then
            return denied('active_scoped_native_owner_required')
        end
        local bound=copy(state.identity)
        if intent.scope and not same(intent.scope,bound) then return denied('equipment_panel_expired_reopen') end
        if intent.action=='dry-run' then return {ok=true,value={identity=bound,spec={characterId=bound.characterId,action='dry-run'}}} end
        local slots={weapon='primary',weapon_offhand='offhand',weapon_shoulder='shoulder',weapon_back='back'}
        local slot=slots[intent.slot]
        if intent.action~='options' and (not slot or (intent.action=='unequip' and intent.itemId~=nil)) then return denied('invalid_equipment_slot_or_item') end
        local checked=WeaponCharacterAmmoService.ValidateLoadout(source)
        if not checked or not checked.ok then return denied('native_loadout_changed') end
        local context={actorSource=source,characterId=bound.characterId,sessionId=bound.sessionId}
        local snapshot=exports['feather-inventory']:ReadNativeEquipmentTransition(context,(intent.action=='equip' or intent.action=='options') and intent.itemId or nil)
        if not snapshot or not snapshot.ok or type(snapshot.value)~='table' or snapshot.value.characterId~=bound.characterId then
            return denied('equipment_snapshot_unavailable')
        end
        local value=snapshot.value
        if type(value.expected)~='table' or type(value.equipment)~='table' then return denied('equipment_snapshot_invalid') end
        if intent.action=='options' then
            if type(value.candidate)~='table' or value.candidate.id~=intent.itemId then return denied('owned_candidate_required') end
            local catalog=copy(WeaponDefinitionCatalog)
            local registry=WeaponCharacterAmmoPolicy.Build(catalog)
            if not registry then return denied('equipment_catalog_unavailable') end
            local options,assigned={},nil
            for equipped,row in pairs(value.expected) do if row.itemId==intent.itemId then assigned=equipped end end
            local labels={weapon='Primary',weapon_offhand='Offhand',weapon_shoulder='Shoulder',weapon_back='Back'}
            for _,dbSlot in ipairs({'weapon','weapon_offhand','weapon_shoulder','weapon_back'}) do
                local action=assigned and assigned==dbSlot and 'unequip' or not assigned and 'equip' or nil
                if action then
                    local proposed=copy(value.equipment)
                    proposed[slots[dbSlot]]=action=='equip' and copy(value.candidate) or nil
                    local plan=WeaponCharacterAmmoMaterialization.Build(proposed,catalog,registry,bound)
                    if plan and WeaponCharacterAmmoMaterialization.Validate(plan,registry,bound)==true then
                        options[#options+1]={action=action,slot=dbSlot,label=(action=='equip' and 'Equip — ' or 'Unequip — ')..labels[dbSlot]}
                    end
                end
            end
            local now=WeaponCharacterAmmoDispatcher.Status(source)
            if not now or now.phase~='active' or now.busy or not same(now.identity,bound)
                or not CoreAdapter.IsSessionCurrent(source,bound.sessionId,bound.characterId) then return denied('native_owner_changed') end
            return {ok=true,value={identity=bound,options=options,itemId=intent.itemId}}
        end
        local spec={characterId=bound.characterId,action=intent.action,slot=intent.slot,expected=copy(value.expected)}
        local proposed=copy(value.equipment)
        if intent.action=='equip' then
            local candidate=value.candidate
            if type(candidate)~='table' or candidate.id~=intent.itemId then return denied('owned_candidate_required') end
            for equipped,row in pairs(value.expected) do
                if row.itemId==candidate.id then return denied('item_already_equipped') end
            end
            spec.itemId,spec.itemRevision=candidate.id,candidate.revision
            proposed[slot]=copy(candidate)
        else
            if not value.expected[intent.slot] then return denied('slot_not_equipped') end
            if intent.selectedItemId and value.expected[intent.slot].itemId~=intent.selectedItemId then
                return denied('selected_equipment_changed')
            end
            proposed[slot]=nil
        end
        local catalog=copy(WeaponDefinitionCatalog)
        local registry=WeaponCharacterAmmoPolicy.Build(catalog)
        if not registry then return denied('equipment_catalog_unavailable') end
        local plan,reason=WeaponCharacterAmmoMaterialization.Build(proposed,catalog,registry,bound)
        if not plan then return denied(reason or 'equipment_loadout_invalid') end
        -- Reject unsupported customization before retiring the current copies.
        local valid=WeaponCharacterAmmoMaterialization.Validate(plan,registry,bound)
        if not valid then return denied('equipment_creation_not_supported') end
        local now=WeaponCharacterAmmoDispatcher.Status(source)
        if not now or now.phase~='active' or now.busy or not same(now.identity,bound) then return denied('native_owner_changed') end
        return {ok=true,value={identity=bound,spec=spec}}
    end,
    current=function(source,identity)
        return enabled() and identity.characterId==Config.NativeAlphaCharacterId
            and CoreAdapter.IsSessionCurrent(source,identity.sessionId,identity.characterId)==true
    end,
    released=function(source,identity)
        local state=WeaponCharacterAmmoDispatcher.Status(source)
        return state and state.phase=='released' and not state.busy and same(state.identity,identity) or false
    end,
    ticket=function(source) sequence=sequence+1; return ('equipment:%s:%s:%s'):format(source,GetGameTimer(),sequence) end,
    requestRelease=function(source,request)
        pending[source]=copy(request)
        TriggerClientEvent('feather-weapons:client:native-equipment-release',source,request)
        SetTimeout(45000,function()
            if pending[source] and pending[source].ticket==request.ticket then
                local state=coordinator.Status(source)
                if state and state.phase~='active' then coordinator.Cancel(source,request.identity.sessionId) end
            end
        end)
        return true
    end,
    commit=function(context,spec)
        if not coordinator.CanCommit(context,spec) then return denied('equipment_commit_ticket_denied') end
        if spec.action=='dry-run' then return {ok=true,value={unchanged=true}} end
        return exports['feather-inventory']:CommitNativeEquipmentTransition(context,spec)
    end,
    rebuild=function(source) return WeaponCharacterAmmoDispatcher.Start(source) end,
    restored=function(source,identity)
        local state=WeaponCharacterAmmoDispatcher.Status(source)
        return state and state.phase=='active' and not state.busy and same(state.identity,identity) or false
    end,
}
coordinator=WeaponNativeEquipmentTransition.New(adapters)
local function replyUI(target,result)
    local request=uiPending[target]
    if not request then return end
    uiPending[target]=nil
    TriggerClientEvent('feather-weapons:client:native-equipment-result',target,request.id,request.scope,result)
end
RegisterNetEvent('feather-weapons:server:native-equipment-ui',function(id,kind,intent)
    local target=source
    if not enabled() or GetResourceState('feather-weapons-native-proof')~='stopped'
        or type(id)~='string' or #id<1 or #id>128 or type(intent)~='table'
        or not identity(intent.scope) or uiPending[target] then return end
    if kind~='options' and kind~='change' then return end
    if kind=='change' and intent.action~='equip' and intent.action~='unequip' then return end
    local request={id=id,scope=copy(intent.scope)}; uiPending[target]=request -- reserve before Core/SQL yields
    local safe={action=kind=='options' and 'options' or intent.action,slot=intent.slot,
        itemId=intent.itemId,scope=copy(intent.scope)}
    if kind=='change' then
        -- UI identifies the clicked item even for Unequip. Resolve its actual
        -- assigned slot from fresh server options, not the client's slot hint.
        local called,preview=pcall(adapters.prepare,target,{action='options',itemId=intent.itemId,scope=safe.scope})
        if uiPending[target]~=request then return end
        if not called or not preview or not preview.ok then return replyUI(target,denied('equipment_preview_changed')) end
        local valid=false
        for _,option in ipairs(preview.value.options) do if option.action==safe.action and option.slot==safe.slot then valid=true end end
        if not valid then return replyUI(target,denied('equipment_option_unavailable')) end
        if safe.action=='unequip' then safe.selectedItemId=safe.itemId; safe.itemId=nil end
    end
    if uiPending[target]~=request then return end
    local called,result=pcall(kind=='options' and adapters.prepare or coordinator.Begin,target,safe)
    if uiPending[target]~=request then return end
    if not called then return replyUI(target,denied('equipment_request_uncertain_no_retry')) end
    if kind=='options' or not result.ok then return replyUI(target,result) end
    SetTimeout(45000,function()
        if uiPending[target]==request then replyUI(target,denied('equipment_completion_timeout_no_retry')) end
    end)
end)
function WeaponNativeEquipmentBindings.Attach(source,bundle)
    local request=pending[source]
    local state=coordinator.Status(source)
    if request and state and state.phase=='rebuilding' then
        bundle.equipmentTransition={ticket=request.ticket,oldEpoch=request.identity.epoch}
    end
end
exports('ValidateNativeEquipmentCommit',function(context,spec)
    -- Inventory cannot manufacture or reuse an intent after the writing phase.
    return GetInvokingResource()=='feather-inventory' and enabled()
        and type(spec)=='table' and (spec.action=='equip' or spec.action=='unequip')
        and coordinator.CanCommit(context,spec)==true
end)
RegisterNetEvent('feather-weapons:server:native-equipment-released',function(ticket,identity,success)
    local playerSource=source
    if not enabled() then return end
    local request=pending[playerSource]
    if not request or ticket~=request.ticket or not same(identity,request.identity) then return end
    if success~=true then
        coordinator.Cancel(playerSource,request.identity.sessionId)
        replyUI(playerSource,denied('equipment_release_failed_no_retry'))
        return print('[WeaponNativeEquipmentDryRun] FAIL client release refused; ownership retained')
    end
    local result=coordinator.Released(playerSource,ticket,identity)
    if not result.ok then replyUI(playerSource,result); print('[WeaponNativeEquipmentTransition] FAIL '..tostring(result.error.code)) end
end)
RegisterNetEvent('feather-weapons:server:native-equipment-restored',function(ticket,identity)
    local playerSource=source
    if not enabled() then return end
    local result=coordinator.Restored(playerSource,ticket,identity)
    if result.ok then
        pending[playerSource]=nil
        replyUI(playerSource,{ok=true,value={identity=copy(identity),phase='active'}})
        local state=coordinator.Status(playerSource)
        print(state.committed and '[WeaponNativeEquipmentChange] PASS conditional equipment commit/fresh same-session restore; no ammo economic writes'
            or '[WeaponNativeEquipmentDryRun] PASS final seal/owned cleanup/server release/fresh same-session restore; no equipment/ammo economic writes')
    end
end)
RegisterCommand('WeaponNativeEquipmentDryRun',function(source,args)
    if source~=0 or not enabled() or GetResourceState('feather-weapons-native-proof')~='stopped' then return end
    local target=tonumber(args and args[1])
    local result=coordinator.Begin(target,{action='dry-run'})
    print('[WeaponNativeEquipmentDryRun] '..(result.ok and 'STARTED; no equipment write requested' or 'REFUSED '..tostring(result.error.code)))
end,true)
RegisterCommand('WeaponNativeEquipmentChange',function(source,args)
    if source~=0 or not enabled() or GetResourceState('feather-weapons-native-proof')~='stopped' then return end
    local action=args and args[2]
    if not args or (action~='equip' and action~='unequip') or (action=='equip' and #args~=4)
        or (action=='unequip' and #args~=3) then return print('[WeaponNativeEquipmentChange] usage: serverId equip|unequip slot [itemId]') end
    local result=coordinator.Begin(tonumber(args[1]),{action=action,slot=args[3],itemId=action=='equip' and tonumber(args[4]) or nil})
    print('[WeaponNativeEquipmentChange] '..(result.ok and 'STARTED; conditional equipment write requested' or 'REFUSED '..tostring(result.error.code)))
end,true)
AddEventHandler('core.session.left.v1',function(session)
    if type(session)=='table' then
        coordinator.Cancel(session.source,session.sessionId)
        local request=uiPending[session.source]
        if request and request.scope.sessionId==session.sessionId then replyUI(session.source,denied('equipment_session_closed_no_retry')) end
    end
end)
AddEventHandler('playerDropped',function() coordinator.Cancel(source); uiPending[source]=nil end)
end
denied=function(code) return {ok=false,error={code=code}} end
identity=function(value)
    if type(value)~='table' then return false end
    for _,key in ipairs({'characterId','sessionId','epoch'}) do
        if type(value[key])~='string' or value[key]=='' or #value[key]>128 then return false end
    end
    return true
end
same=function(a,b)
    return identity(a) and identity(b) and a.characterId==b.characterId and a.sessionId==b.sessionId and a.epoch==b.epoch
end
function WeaponNativeEquipmentTransition.New(api)
    for _,key in ipairs({'enabled','prepare','current','released','requestRelease','commit','rebuild','restored','ticket'}) do
        if type(api[key])~='function' then return nil,'missing_transition_adapter_'..key end
    end
    local states,retired={},{}
    local T={}
    local function frozen(source,state,code)
        if states[source]~=state then return denied('equipment_transition_superseded') end
        state.phase,state.reason='frozen',code
        return denied(code) -- retains evidence; never auto-reverts a committed write
    end
    local function current(source,state)
        if states[source]~=state or state.phase=='frozen' or api.enabled()~=true then return false end
        local called,valid=pcall(api.current,source,copy(state.identity))
        return called and valid==true and states[source]==state and state.phase~='frozen' and api.enabled()==true
    end
    function T.Begin(source,intent)
        if api.enabled()~=true then return denied('equipment_transition_disabled') end
        if type(source)~='number' or source<1 or source%1~=0 or type(intent)~='table' then return denied('invalid_equipment_intent') end
        local previous=states[source]
        if previous and previous.phase~='active' then return denied('equipment_transition_in_flight') end
        local state={phase='preparing'}; states[source]=state
        -- prepare must resolve actual Core identity, active native epoch, owned
        -- item/catalog/slot policy and expected equipment snapshot server-side.
        local called,prepared=pcall(api.prepare,source,copy(intent))
        if states[source]~=state then return denied('equipment_transition_superseded') end
        if not called or type(prepared)~='table' or prepared.ok~=true then
            -- No release was requested, so a policy refusal must not strand an
            -- otherwise active owner. A concurrent lifecycle cancellation wins.
            if state.phase~='preparing' then return denied('equipment_context_changed') end
            states[source]=previous
            return denied(type(prepared)=='table' and prepared.error and prepared.error.code or 'equipment_preflight_failed')
        end
        local value=prepared.value
        if type(value)~='table' or not identity(value.identity) or type(value.spec)~='table'
            or value.spec.characterId~=value.identity.characterId then return frozen(source,state,'equipment_preflight_invalid') end
        state.identity,state.spec=copy(value.identity),copy(value.spec)
        if state.cancelledSessions and state.cancelledSessions[state.identity.sessionId] then
            return frozen(source,state,'equipment_transition_cancelled')
        end
        if not current(source,state) then return frozen(source,state,'equipment_context_changed') end
        local made,ticket=pcall(api.ticket,source,copy(state.identity))
        if state.phase~='preparing' or not current(source,state) then return frozen(source,state,'equipment_context_changed') end
        if not made or type(ticket)~='string' or ticket=='' or #ticket>128 then return frozen(source,state,'equipment_ticket_failed') end
        state.ticket=ticket; state.phase='releasing'
        local sent,accepted=pcall(api.requestRelease,source,{ticket=ticket,identity=copy(state.identity)})
        if states[source]~=state or state.phase~='releasing' then return denied('equipment_release_lifecycle_changed') end
        if not sent or accepted~=true then return frozen(source,state,'equipment_release_dispatch_failed') end
        return {ok=true,value={phase='releasing'}}
    end
    function T.Released(source,ticket,hint)
        local state=states[source]
        if not state or state.phase~='releasing' or ticket~=state.ticket or not same(hint,state.identity) then
            return denied('stale_equipment_release')
        end
        state.phase='checking_release' -- reserve before authoritative adapters yield
        if not current(source,state) then return frozen(source,state,'equipment_context_changed') end
        local checked,released=pcall(api.released,source,copy(state.identity))
        if not checked or released~=true or not current(source,state) then return frozen(source,state,'equipment_release_not_acknowledged') end
        state.phase='writing'
        local context={actorSource=source,characterId=state.identity.characterId,sessionId=state.identity.sessionId,
            epoch=state.identity.epoch,ticket=state.ticket}
        local called,committed=pcall(api.commit,copy(context),copy(state.spec))
        if states[source]~=state or state.phase~='writing' then return denied('equipment_commit_lifecycle_changed') end
        if not called then return frozen(source,state,'equipment_commit_uncertain_no_retry') end
        if type(committed)~='table' or committed.ok~=true then return frozen(source,state,'equipment_commit_refused') end
        state.committed=not (type(committed.value)=='table' and committed.value.unchanged==true)
        if not current(source,state) then return frozen(source,state,'equipment_committed_context_changed') end
        state.phase='rebuilding'
        local started,result=pcall(api.rebuild,source,copy(context))
        if states[source]~=state or state.phase~='rebuilding' then return denied('equipment_rebuild_lifecycle_changed') end
        local new=type(result)=='table' and result.ok==true and result.value
        if not started or not identity(new) or new.characterId~=state.identity.characterId
            or new.sessionId~=state.identity.sessionId or new.epoch==state.identity.epoch then
            return frozen(source,state,'equipment_committed_rebuild_failed')
        end
        state.newIdentity=copy(new)
        return {ok=true,value={phase='rebuilding'}}
    end
    function T.CanCommit(context,spec)
        local state=type(context)=='table' and states[context.actorSource]
        if not state or state.phase~='writing' or context.ticket~=state.ticket or not same(context,state.identity)
            or type(spec)~='table' then return false end
        local function equal(a,b)
            if type(a)~=type(b) then return false end
            if type(a)~='table' then return a==b end
            for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
            for k in pairs(b) do if a[k]==nil then return false end end
            return true
        end
        if not equal(spec,state.spec) or not current(context.actorSource,state) then return false end
        local called,released=pcall(api.released,context.actorSource,copy(state.identity))
        return called and released==true and current(context.actorSource,state) and state.phase=='writing'
    end
    function T.Restored(source,ticket,hint)
        local state=states[source]
        if not state or state.phase~='rebuilding' or ticket~=state.ticket or not same(hint,state.newIdentity) then
            return denied('stale_equipment_restore')
        end
        state.phase='checking_restore'
        local called,active=pcall(api.restored,source,copy(state.newIdentity))
        if not called or active~=true or not current(source,state) then return frozen(source,state,'equipment_restore_not_acknowledged') end
        state.phase='active'
        return {ok=true,value={phase='active'}}
    end
    function T.Cancel(source,sessionId)
        local state=states[source]
        if not state then return false end
        if sessionId and not state.identity then
            -- Core/SQL preflight may be yielding. Do not let a delayed old
            -- session event cancel a different session whose identity is unread.
            state.cancelledSessions=state.cancelledSessions or {}
            state.cancelledSessions[sessionId]=true
            return true
        end
        if sessionId and sessionId~=state.identity.sessionId then return false end
        if state.phase=='active' then
            -- Completed restore has no outstanding write/release authority.
            -- Keep the last completed evidence, but allow next-login preflight.
            retired[source]=state; states[source]=nil; return true
        end
        state.phase,state.reason='frozen','equipment_transition_cancelled'; return true
    end
    function T.Status(source)
        local state=states[source]
        return state and {phase=state.phase,reason=state.reason,committed=state.committed==true} or nil
    end
    return T
end
if type(RegisterNetEvent)=='function' and type(RegisterCommand)=='function' then InstallDryRun() end
