-- Explicit owning composition. Construction is inert; Start remains opt-in.
-- The same lease owns zero-ammo creation, dual setup and sealed cleanup.
WeaponCharacterAmmoNativeOwner={}
function WeaponCharacterAmmoNativeOwner.New(dependencies)
    local d=dependencies or {
        context=WeaponCharacterAmmoWorldContext.Read,
        ped=PlayerPedId,
        dual=WeaponCharacterAmmoDualNative.New,
        creation=WeaponCharacterAmmoCreationNative.Scoped,
        bootstrap=WeaponCharacterAmmoClientBindings.Bootstrap,
    }
    for _,name in ipairs({'context','ped','dual','creation','bootstrap'}) do
        if type(d[name])~='function' then return nil,'missing_native_owner_'..name end
    end
    local bootstrap,lease,phase,reason=nil,nil,'dormant',nil
    local function enabled()
        return Config.CharacterAmmunitionEnabled==true and Config.CharacterAmmoTransportEnabled==true
    end
    local function current(expected,ped)
        if not enabled() or d.ped()~=ped then return false end
        local called,result=pcall(d.context)
        local value=called and type(result)=='table' and result.ok==true and result.value
        return type(value)=='table' and value.characterId==expected.characterId
            and value.sessionId==expected.sessionId and value.ped==ped
    end
    local function create(ped,identity)
        if type(identity)~='table' or type(identity.epoch)~='string' or identity.epoch==''
            or not current(identity,ped) then return nil,'native_owner_world_changed' end
        if lease and not lease.cleaned then return nil,'native_owner_cleanup_required' end
        local expected={characterId=identity.characterId,sessionId=identity.sessionId,epoch=identity.epoch}
        local owned={identity=expected,ped=ped,cleaned=false}
        -- Reserve before any native factory can yield. Failure retains the
        -- reservation rather than claiming partial setup has been removed.
        lease=owned
        local dual
        local adapter,reason=d.creation(ped,expected,function()
            if not current(expected,ped) then return false end
            -- Primary-only plans must not read/write offhand appearance.
            if not dual then dual=d.dual(ped,function() return current(expected,ped) end) end
            return dual.Ensure()==true
        end,function()
            if lease~=owned or not current(expected,ped) then return nil,'native_owner_cleanup_world_changed' end
            if owned.records and #owned.records>0 then return nil,'native_owner_copies_remain' end
            local removed,why=true,nil
            if dual then removed,why=dual.Cleanup() end
            if removed==true then owned.cleaned=true end
            return removed,why
        end)
        if not adapter then return nil,reason end
        owned.adapter=adapter
        return adapter
    end
    local function track(adapter,records)
        assert(lease and lease.adapter==adapter and not lease.cleaned,'native_owner_tracking_mismatch')
        lease.records=records -- Session mutates this exact list during cleanup.
    end
    local T={}
    function T.Start()
        if phase~='dormant' then return nil,'native_owner_already_started' end
        if not enabled() then return nil,'character_ammunition_disabled' end
        phase='starting'
        local called,value,why=pcall(d.bootstrap,create,track)
        if not called or type(value)~='table' or type(value.Start)~='function'
            or type(value.Status)~='function' then
            phase,reason='failed',why or 'native_owner_bootstrap_failed'; return nil,reason
        end
        bootstrap=value
        if not enabled() then phase,reason='failed','character_ammunition_disabled'; return nil,reason end
        local started,result,failure=pcall(bootstrap.Start)
        if not started or result~=true then
            phase,reason='failed',failure or 'native_owner_start_failed'; return nil,reason
        end
        phase='started'; return true
    end
    function T.Status()
        return {phase=phase,reason=reason,bootstrap=bootstrap and bootstrap.Status() or {phase='dormant'},
            ownedCopies=lease and lease.records and #lease.records or 0,
            cleanupComplete=lease==nil or lease.cleaned==true}
    end
    function T.Readiness()
        if not enabled() or phase~='started' or not bootstrap then return nil,'native_owner_not_started' end
        local state=bootstrap.Status()
        if state.phase~='started' or not state.runtime or state.runtime.phase~='closed'
            or state.runtime.fault or state.runtime.runtimeBusy then return nil,'native_owner_not_closed' end
        if lease and not lease.cleaned then return nil,'native_owner_cleanup_required' end
        if lease and lease.records and #lease.records>0 then return nil,'native_owner_copies_remain' end
        local called,result=pcall(d.context)
        local value=called and type(result)=='table' and result.ok==true and result.value
        if type(value)~='table' or value.ped~=d.ped() then return nil,'native_owner_world_not_ready' end
        -- No pool, limit, slot, item or epoch credit is exposed as readiness.
        return {characterId=value.characterId,sessionId=value.sessionId}
    end
    function T.BindReadiness()
        if phase~='started' then return nil,'native_owner_not_started' end
        return WeaponCharacterAmmoClientBindings.Readiness(T)
    end
    function T.Transfer(id,amount,operationId,scope)
        if not enabled() or phase~='started' or not bootstrap then return nil,'native_owner_not_started' end
        local result=d.context()
        local value=type(result)=='table' and result.ok==true and result.value
        if type(value)~='table' or not lease or lease.cleaned
            or not current(lease.identity,lease.ped) then return nil,'native_owner_world_not_ready' end
        if type(scope)~='table' or scope.characterId~=lease.identity.characterId
            or scope.sessionId~=lease.identity.sessionId or scope.epoch~=lease.identity.epoch then
            return nil,'ammunition_panel_expired_reopen'
        end
        return bootstrap.Transfer(id,amount,operationId)
    end
    function T.Recovery()
        local hint=T.Readiness()
        if not hint or not lease or not lease.cleaned then return nil end
        local state=bootstrap.Status().runtime
        local recovery=state and state.deathRecovery
        if type(recovery)~='table' or recovery.characterId~=hint.characterId
            or recovery.sessionId~=hint.sessionId or recovery.ped~=lease.ped
            or recovery.epoch~=lease.identity.epoch then return nil end
        return {characterId=hint.characterId,sessionId=hint.sessionId,epoch=recovery.epoch}
    end
    return T
end
