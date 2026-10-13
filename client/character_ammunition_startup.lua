-- Development-only normal-manifest host. Disabled defaults keep legacy startup.
CreateThread(function()
    if Config.CharacterAmmunitionEnabled~=true or Config.CharacterAmmoTransportEnabled~=true then return end
    if Config.DevMode~=true or Config.NativeAlphaRuntime~=true
        or type(Config.NativeAlphaCharacterId)~='string' or Config.NativeAlphaCharacterId=='' then
        print('[feather-weapons] native alpha startup refused: explicit scoped configuration required')
        return
    end
    local deadline=GetGameTimer()+30000
    while GetGameTimer()<deadline do
        if Config.CharacterAmmunitionEnabled~=true or Config.CharacterAmmoTransportEnabled~=true
            or Config.NativeAlphaRuntime~=true then return end
        local result=WeaponCharacterAmmoWorldContext.Read()
        if result.ok==true and result.value.characterId==Config.NativeAlphaCharacterId then
            local owner,reason=WeaponCharacterAmmoNativeOwner.New()
            if not owner then print('[feather-weapons] native alpha owner refused: '..tostring(reason)); return end
            WeaponCharacterAmmoActiveOwner=owner
            local started,why=owner.Start()
            if not started then print('[feather-weapons] native alpha startup failed: '..tostring(why)); return end
            local bound,failure=owner.BindReadiness()
            if not bound then print('[feather-weapons] native alpha readiness failed: '..tostring(failure)); return end
            print('[feather-weapons] scoped native alpha client started; awaiting authoritative loadout')
            return
        end
        Wait(250)
    end
    print('[feather-weapons] native alpha startup waiting expired; no loadout requested')
end)

RegisterCommand('weaponNativeStatus',function()
    if Config.DevMode~=true or Config.NativeAlphaRuntime~=true then
        print('[feather-weapons] native alpha is disabled'); return
    end
    local owner=WeaponCharacterAmmoActiveOwner
    if not owner then print('[feather-weapons] native alpha NOT READY: owner not started'); return end
    local status=owner.Status()
    local runtime=status.bootstrap and status.bootstrap.runtime
    local active=status.phase=='started' and runtime and runtime.phase=='active'
        and not runtime.fault and not runtime.runtimeBusy
    print('[feather-weapons] native alpha '..(active and 'ACTIVE' or 'NOT ACTIVE')..': '..json.encode(status))
end,false)
