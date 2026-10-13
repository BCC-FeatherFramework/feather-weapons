-- Dormant owner: creation -> pool restore -> server acknowledgement -> active.
-- Owner must provide input blocking, native creation adapter and lifecycle ticks.
WeaponCharacterAmmoSession={}
function WeaponCharacterAmmoSession.New(api,registry)
    local controller=WeaponCharacterAmmoController.New(api)
    local phase,records,creator='closed',nil,nil
    local T={}
    local function blocked(value) api.block(value) end
    local function freeze(reason) phase='frozen'; blocked(true); return nil,reason end
    function T.Begin(bundle)
        if phase~='closed' then return nil,'native_session_not_closed' end
        if type(bundle)~='table' then return nil,'invalid_creation_bundle' end
        local valid,reason=WeaponCharacterAmmoMaterialization.Validate(bundle.creation,registry,bundle.runtime)
        if not valid then return nil,reason end
        -- Preflight every ammo value before granting any weapon. Names/limits
        -- come from the owner's trusted registry, never from bundle credit hints.
        local check=WeaponCharacterAmmoClient.New()
        local ped=api.ped()
        local baseline
        baseline,reason=check.Begin(bundle.runtime,registry.limits,ped)
        if not baseline or api.ready()~=true then return nil,reason or 'world_not_ready' end
        local native
        native,reason=WeaponCharacterAmmoNative.New(registry.names,registry.limits,api)
        if not native then return nil,reason end
        local before
        before,reason=native.Read(ped,true)
        if not before then return nil,reason end
        blocked(true); phase='creating'
        local ok,adapter=pcall(api.creation,ped,bundle.creation.identity)
        if not ok or type(adapter)~='table' then return freeze('creation_adapter_unavailable') end
        creator=adapter
        local executor=WeaponCharacterAmmoLoadout.New(adapter)
        local created
        created,reason=executor.Create(bundle.creation)
        if not created then return freeze(reason) end
        records=created.handles
        if api.owned then api.owned(creator,records) end
        if api.ped()~=ped or api.ready()~=true then return freeze('creation_world_changed') end
        local after
        after,reason=native.Read(ped,true)
        if not after then return freeze(reason) end
        for id,count in pairs(before) do
            if after[id]~=count then return freeze('creation_changed_native_pool') end
        end
        phase='restoring'
        local opened
        opened,reason=controller.Begin(baseline,registry.names,registry.limits)
        if not opened then return freeze(reason) end
        return true
    end
    function T.Tick()
        if phase=='closed' or phase=='creating' or phase=='frozen' then return nil,'native_session_not_ready' end
        local state=controller.Status()
        if phase=='cleanup_pending' then
            if state.phase=='released' then
                controller.Close(); creator,records=nil,nil; phase='closed'; return true,'released'
            end
            if state.phase=='frozen' or state.phase=='suspended' then return freeze('cleanup_ack_failed') end
            return nil,'cleanup_ack_pending'
        end
        phase=state.phase
        blocked(phase~='active' or state.closing==true or state.pendingKind=='transfer')
        if phase=='frozen' or phase=='suspended' or phase=='sealed' then return nil,phase end
        local result,reason=controller.Tick()
        state=controller.Status(); phase=state.phase
        blocked(phase~='active' or state.closing==true or state.pendingKind=='transfer')
        return result,reason
    end
    function T.Finalize()
        local state=controller.Status()
        if state.phase~='active' then return nil,'native_session_not_active' end
        blocked(true)
        return controller.Finalize()
    end
    function T.Transfer(id,amount,operationId) return controller.Transfer(id,amount,operationId) end
    function T.FinalizeDeath()
        if controller.Status().phase~='active' then return nil,'death_seal_not_active' end
        blocked(true)
        return controller.FinalizeDeath()
    end
    function T.Cleanup()
        if controller.Status().deathClosing then return nil,'death_recovery_required' end
        if phase=='cleanup_pending' then return nil,'cleanup_ack_pending' end
        -- Never close an unsealed active session and lose its final observations.
        if controller.Status().phase~='sealed' and phase~='frozen' then return nil,'seal_required_before_cleanup' end
        blocked(true)
        for index=#(records or {}),1,-1 do
            local ok,removed=pcall(creator.remove,records[index])
            if not ok or removed~=true then return freeze('native_cleanup_failed') end
            table.remove(records,index)
        end
        -- Appearance/permission ownership belongs to the same sealed cleanup.
        -- Never acknowledge cleanup while a provisioned setup remains owned.
        if creator and creator.cleanupSetup then
            local ok,cleaned=pcall(creator.cleanupSetup)
            if not ok or cleaned~=true then return freeze('native_setup_cleanup_failed') end
        end
        local confirmed,reason=controller.ConfirmCleanup()
        if not confirmed then return freeze(reason) end
        phase='cleanup_pending'
        -- Keep input blocked and ownership until the exact server ack arrives.
        return true
    end
    function T.RecoverDeath()
        local allowed,why=controller.AllowDeathCleanup()
        if not allowed then return nil,why end
        return T.Cleanup()
    end
    function T.Status() return {phase=phase,ammo=controller.Status(),copies=records and #records or 0} end
    return T
end
