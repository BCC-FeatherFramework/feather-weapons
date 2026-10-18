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
    function T.ProbeGuidComponent(action)
        local owned=lease
        local function guard()
            local state=bootstrap and bootstrap.Status().runtime
            local ammo=state and state.session and state.session.ammo
            local baseline=ammo and ammo.baseline
            local flag=action and 'feather_native_child_component_probe' or 'feather_native_guid_component_probe'
            if Config.DevMode~=true or Config.NativeAlphaRuntime~=true or GetConvarInt(flag,0)~=1
                or lease~=owned or not owned or owned.cleaned or phase~='started' or not state or state.phase~='active'
                or state.runtimeBusy or state.receiving or state.quiescing or not ammo or ammo.phase~='active'
                or ammo.pending or ammo.closing or ammo.deathClosing or not baseline
                or baseline.characterId~=Config.NativeAlphaCharacterId or baseline.epoch~=owned.identity.epoch
                or baseline.sessionId~=owned.identity.sessionId or not current(owned.identity,owned.ped) then return false end
            for _,amount in pairs(baseline.pools or {}) do if amount~=0 then return false end end
            return true
        end
        local method=owned and owned.adapter and (action and owned.adapter.probeInventoryComponent or owned.adapter.probeGuidComponent)
        if not guard() or type(method)~='function' then return nil,'guid_probe_settled_empty_scope_required' end
        for _,record in ipairs(owned.records or {}) do
            if record.itemInstanceId==135 then return method(record,owned.identity,guard,action) end
        end
        return nil,'guid_probe_equipped135_required'
    end
    function T.InspectTrackedEntities()
        local owned=lease
        local state=bootstrap and bootstrap.Status().runtime
        if Config.DevMode~=true or not owned or owned.cleaned or phase~='started'
            or not state or state.phase~='active' or state.runtimeBusy or state.receiving or state.quiescing
            or not current(owned.identity,owned.ped) or type(owned.adapter.inspectTrackedEntity)~='function' then
            return nil,'diagnostic_settled_owner_required'
        end
        local out={epoch=owned.identity.epoch,items={},noNativeWrites=true,noSQLWrites=true}
        for _,record in ipairs(owned.records or {}) do
            local value,why=owned.adapter.inspectTrackedEntity(record,owned.identity)
            if not value then return nil,why end
            out.items[#out.items+1]=value
        end
        if lease~=owned or not current(owned.identity,owned.ped) then return nil,'diagnostic_owner_changed' end
        return out
    end
    function T.MaintenanceStatus(allowReserved)
        local owned=lease
        local state=bootstrap and bootstrap.Status().runtime
        if phase~='started' or not owned or owned.cleaned or not state or state.phase~='active'
            or (state.runtimeBusy and allowReserved~=true) or state.receiving or state.quiescing or not current(owned.identity,owned.ped)
            or type(owned.adapter.readMaintenance)~='function' then return nil,'maintenance_owner_not_settled' end
        local ammo=state.session and state.session.ammo
        if not ammo or ammo.phase~='active' or ammo.pending or ammo.closing or ammo.deathClosing then
            return nil,'maintenance_owner_not_settled'
        end
        local baseline=ammo.baseline
        if not baseline or baseline.epoch~=owned.identity.epoch then return nil,'maintenance_epoch_changed' end
        local out={epoch=baseline.epoch,items={}}
        for _,record in ipairs(owned.records or {}) do
            local called,values=pcall(owned.adapter.readMaintenance,record,owned.identity)
            if not called or not values then return nil,'maintenance_readback_unavailable' end
            out.items[#out.items+1]={itemInstanceId=record.itemInstanceId,itemRevision=record.itemRevision,
                name=record.name,maintenance=values}
        end
        if lease~=owned or not current(owned.identity,owned.ped) then return nil,'maintenance_owner_changed' end
        return out
    end
    function T.FinalWear(identity)
        if not lease or type(identity)~='table' then return nil,'final_wear_owner_missing' end
        for _,key in ipairs({'characterId','sessionId','epoch'}) do
            if identity[key]~=lease.identity[key] then return nil,'final_wear_owner_changed' end
        end
        return T.MaintenanceStatus(true) -- only the runtime release reservation may already be busy
    end
    function T.DeathWear(context)
        local owned=lease
        local state=bootstrap and bootstrap.Status().runtime
        local ammo=state and state.session and state.session.ammo
        if Config.NativeAlphaLifecycleWearEnabled~=true or phase~='started' or not owned or owned.cleaned
            or not state or state.phase~='active' or state.receiving or state.quiescing or state.fault
            or not ammo or ammo.phase~='active' or not ammo.baseline or ammo.baseline.epoch~=owned.identity.epoch
            or type(owned.adapter.readDeathMaintenance)~='function' or type(context)~='table'
            or context.characterId~=owned.identity.characterId or context.sessionId~=owned.identity.sessionId
            or context.ped~=owned.ped or d.ped()~=owned.ped or context.lifeState~='dead' then return nil,'death_wear_owner_not_settled' end
        local out={epoch=owned.identity.epoch,medicalRevision=context.medicalRevision,items={}}
        for _,record in ipairs(owned.records or {}) do
            local called,values=pcall(owned.adapter.readDeathMaintenance,record,owned.identity)
            if not called or not values then return nil,'death_wear_readback_unavailable' end
            out.items[#out.items+1]={itemInstanceId=record.itemInstanceId,itemRevision=record.itemRevision,maintenance=values}
        end
        local called,result=pcall(WeaponCharacterAmmoWorldContext.ReadDeath)
        local after=called and type(result)=='table' and result.ok==true and result.value
        if lease~=owned or not after or after.characterId~=context.characterId or after.sessionId~=context.sessionId
            or after.ped~=context.ped or after.medicalRevision~=context.medicalRevision then return nil,'death_wear_context_changed' end
        return out
    end
    function T.StopZeroAmmo()
        -- Synchronous, narrowly safe stop cleanup. No SQL/transport, pool reset,
        -- seal/release acknowledgement or recovery claim is made here.
        if phase~='started' or not bootstrap or not lease or lease.cleaned then return nil,'stop_owner_not_tracked' end
        local owned=lease
        local state=bootstrap.Status().runtime
        local ammo=state and state.session and state.session.ammo
        local baseline=ammo and ammo.baseline
        if not state or state.phase~='active' or state.runtimeBusy or state.receiving or state.quiescing or state.fault
            or not ammo or ammo.phase~='active' or ammo.pending or ammo.closing or ammo.deathClosing
            or not baseline or baseline.epoch~=owned.identity.epoch or not current(owned.identity,owned.ped)
            or type(owned.records)~='table' then return nil,'stop_owner_not_settled' end
        local function read()
            if d.readPools then return d.readPools(owned.ped) end
            local registry=WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog)
            if not registry then return nil end
            local native=WeaponCharacterAmmoNative.New(registry.names,registry.limits)
            return native and native.Read(owned.ped,true)
        end
        local function empty()
            if lease~=owned or not current(owned.identity,owned.ped) then return false end
            local called,pools=pcall(read)
            if not called or type(pools)~='table' or next(pools)==nil or type(baseline.pools)~='table' then return false end
            for id,count in pairs(pools) do if count~=0 or baseline.pools[id]~=0 then return false end end
            for id,count in pairs(baseline.pools) do if count~=0 or pools[id]~=0 then return false end end
            return true
        end
        if not empty() then return nil,'stop_nonzero_or_unreadable_ammo_requires_orderly_release' end
        for i=#owned.records,1,-1 do
            if not empty() then return nil,'stop_cleanup_context_changed' end
            local called,removed=pcall(owned.adapter.remove,owned.records[i])
            if not called or removed~=true then return nil,'stop_owned_copy_cleanup_failed' end
            table.remove(owned.records,i)
        end
        if not empty() then return nil,'stop_cleanup_context_changed' end
        local called,cleaned=pcall(owned.adapter.cleanupSetup)
        if not called or cleaned~=true then return nil,'stop_owned_setup_cleanup_failed' end
        phase,reason='stopped','zero_ammo_owned_stop_cleanup'
        return true
    end
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
