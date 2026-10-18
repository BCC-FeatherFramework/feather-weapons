-- WeaponProvenanceService.Start() now calls DB.* (feather-mysql), which requires a yieldable
-- coroutine for every call, not just transactions; this whole startup sequence runs inside
-- CreateThread for that reason. The internal early `return`s below now exit the thread's
-- function body instead of the file chunk, which is equivalent for this sequential flow.
CreateThread(function()
    local function FailStartup(message, details)
        print(("[feather-weapons] startup failed: %s"):format(message))
        if details and Config.DevMode then print(json.encode(details)) end
        error(message)
    end

    local coreResult = CoreAdapter.CheckCapabilities()
    if not coreResult.ok then
        FailStartup(coreResult.error.message, coreResult.error.details)
        return
    end

    local characterResult = CoreAdapter.CheckCharacterCapabilities()
    if not characterResult.ok then
        FailStartup(characterResult.error.message, characterResult.error.details)
        return
    end

    if Config.CharacterAmmunitionEnabled==true or Config.CharacterAmmoTransportEnabled==true then
        if Config.CharacterAmmunitionEnabled~=true or Config.CharacterAmmoTransportEnabled~=true
            or Config.DevMode~=true or Config.NativeAlphaRuntime~=true
            or type(Config.NativeAlphaCharacterId)~='string' or Config.NativeAlphaCharacterId=='' then
            FailStartup('native_cutover_not_ready: explicit scoped alpha configuration required')
            return
        end
        local definitions=DefinitionRegistry.Start()
        if not definitions.ok then FailStartup(definitions.error.message,definitions.error.details); return end
        local readerReady,readerReason=WeaponNativeOwnershipReader.Install()
        if not readerReady then FailStartup(readerReason); return end
        local provenance=WeaponProvenanceService.Start()
        if not provenance.ok then FailStartup(provenance.error.message,provenance.error.details); return end
        local installed,reason=WeaponCharacterAmmoInventoryProvider.Install()
        if not installed then FailStartup(reason); return end
        print('[feather-weapons] scoped native alpha firearms host ready; legacy gameplay disabled')
        return -- Never install legacy usable items/provider or hybrid restoration.
    end

    local definitionResult = DefinitionRegistry.Start()
    if not definitionResult.ok then
        FailStartup(definitionResult.error.message, definitionResult.error.details)
        return
    end

    local provenanceResult = WeaponProvenanceService.Start()
    if not provenanceResult.ok then
        FailStartup(provenanceResult.error.message, provenanceResult.error.details)
        return
    end

    local offhandConfigResult = EquipService.ValidateConfiguration()
    if not offhandConfigResult.ok then
        FailStartup(offhandConfigResult.error.message, offhandConfigResult.error.details)
        return
    end

    local inventoryProviderResult = InstallFeatherInventoryProvider()
    if not inventoryProviderResult.ok then
        FailStartup(inventoryProviderResult.error.message, inventoryProviderResult.error.details)
        return
    end

    ReconciliationService.BootstrapActiveSessions()
    ReconciliationService.MarkStartupReady()

    local counts = definitionResult.value
    print(("[feather-weapons] foundation ready: %d weapon, %d ammunition, %d attachment definitions")
        :format(counts.weapon, counts.ammunition, counts.attachment))

    if InventoryAdapter.IsReady() then
        local capabilities = InventoryAdapter.GetCapabilities()
        print(("[feather-weapons] inventory provider active: %s")
            :format(tostring(capabilities.provider or "unknown")))
    end
end)
