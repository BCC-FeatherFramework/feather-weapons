WeaponMetadata = {}

-- Opted-in carriers keep one authoritative total per ammunition definition.
-- The legacy clip/reserve fields are only a projection of the selected pool.
function WeaponMetadata.EnsureAmmunitionPools(metadata, definition)
    if definition.multiTypeAmmunition ~= true then return end
    if metadata.ammo.pools == nil then
        metadata.ammo.pools = {
            [metadata.ammo.type or definition.ammunitionType] =
                (tonumber(metadata.ammo.loaded) or 0) + (tonumber(metadata.ammo.reserve) or 0)
        }
    end
    if definition.family ~= 'throwing_knife' and metadata.ammo.clips == nil then
        metadata.ammo.clips = {
            [metadata.ammo.type or definition.ammunitionType] = metadata.ammo.loaded or 0
        }
    end
end

function WeaponMetadata.ProjectAmmunitionPool(metadata, definition, ammunitionType, reportedLoaded)
    WeaponMetadata.EnsureAmmunitionPools(metadata, definition)
    local total = metadata.ammo.pools[ammunitionType] or 0
    metadata.ammo.pools[ammunitionType] = total
    local loaded = math.min(definition.capacity, total)
    if metadata.ammo.clips and metadata.ammo.clips[ammunitionType] ~= nil then
        loaded = math.min(loaded, metadata.ammo.clips[ammunitionType])
    end
    -- Firearm checkpoints must preserve the actual cylinder/clip, not refill
    -- it merely because reserve ammunition remains in this pool.
    if reportedLoaded ~= nil then
        loaded = math.min(definition.capacity, total, math.max(0, math.floor(reportedLoaded)))
    end
    metadata.ammo.type = ammunitionType
    metadata.ammo.loaded = loaded
    metadata.ammo.reserve = total - loaded
    metadata.ammo.chambered = loaded > 0
    if metadata.ammo.clips then metadata.ammo.clips[ammunitionType] = loaded end
end

function WeaponMetadata.SaveSelectedAmmunitionPool(metadata, definition)
    if definition.multiTypeAmmunition ~= true then return end
    WeaponMetadata.EnsureAmmunitionPools(metadata, definition)
    metadata.ammo.pools[metadata.ammo.type or definition.ammunitionType] =
        (tonumber(metadata.ammo.loaded) or 0) + (tonumber(metadata.ammo.reserve) or 0)
    if metadata.ammo.clips then
        metadata.ammo.clips[metadata.ammo.type or definition.ammunitionType] = metadata.ammo.loaded
    end
end

local function NormalizeMaintenance(value)
    value = type(value) == "table" and value or {}
    local function Unit(number)
        return math.max(0.0, math.min(1.0, tonumber(number) or 0.0))
    end
    return {
        degradation = Unit(value.degradation),
        permanentDegradation = Unit(value.permanentDegradation),
        damage = Unit(value.damage),
        dirt = Unit(value.dirt),
        soot = Unit(value.soot)
    }
end

function WeaponMetadata.Build(definition, options)
    options = type(options) == "table" and options or {}
    local metadata = {
        schemaVersion = WeaponConstants.MetadataSchemaVersion,
        weaponDefinitionId = definition.id,
        serialNumber = options.serialNumber,
        condition = tonumber(options.condition) or definition.condition.maximum,
        maintenance = NormalizeMaintenance(options.maintenance),
        quality = tonumber(options.quality) or 100,
        ammo = {
            type = options.ammunitionType or definition.ammunitionType,
            loaded = tonumber(options.loadedAmmo) or 0,
            reserve = tonumber(options.reserveAmmo) or 0,
            chambered = options.chambered == true
        },
        attachments = options.attachments or {},
        cosmetics = options.cosmetics or {},
        flags = {
            stolen = options.stolen == true,
            evidence = options.evidence == true,
            disabled = options.disabled == true
        },
        provenance = options.provenance or {}
    }

    WeaponMetadata.EnsureAmmunitionPools(metadata, definition)
    local valid, errors = WeaponValidation.Metadata(metadata, definition)
    if not valid then
        return WeaponResult.Error(WeaponErrors.ITEM_INVALID, "Generated weapon metadata is invalid", errors)
    end
    local attachments = DefinitionRegistry.ValidateAttachmentSet(definition.id, metadata.attachments)
    if not attachments.ok then return attachments end
    return WeaponResult.Ok(metadata)
end

function WeaponMetadata.Validate(metadata, definition, correlationId)
    if type(metadata)=='table' and type(metadata.ammo)=='table' and metadata.ammo.ownership=='character' then
        if Config.CharacterAmmunitionEnabled~=true then
            return WeaponResult.Error(WeaponErrors.ITEM_INVALID,'Character ammunition integration is disabled',nil,correlationId)
        end
        local checked,reason,errors=WeaponCharacterAmmoItem.Validate(metadata,definition)
        if not checked then return WeaponResult.Error(WeaponErrors.ITEM_INVALID,reason,errors,correlationId) end
        local attachments=DefinitionRegistry.ValidateAttachmentSet(definition.id,checked.attachments)
        if not attachments.ok then return attachments end
        return WeaponResult.Ok(checked,correlationId)
    end
    -- Retire only the explicitly rejected candidate's empty, unselected key.
    -- Never discard nonzero ownership or silently change a retired selection.
    if definition.id == 'throwable_throwing_knives' and type(metadata) == 'table'
        and type(metadata.ammo) == 'table' and type(metadata.ammo.pools) == 'table'
        and metadata.ammo.type ~= 'ammo_throwing_knives_improved'
        and metadata.ammo.pools.ammo_throwing_knives_improved == 0 then
        metadata.ammo.pools.ammo_throwing_knives_improved = nil
    end
    if type(metadata) == "table" and type(metadata.ammo) == "table"
        and metadata.ammo.reserve == nil then
        metadata.ammo.reserve = 0
    end
    if type(metadata) == "table" and metadata.maintenance ~= nil then
        metadata.maintenance = NormalizeMaintenance(metadata.maintenance)
    end
    if type(metadata) == "table" and type(metadata.ammo) == "table"
        and metadata.ammo.pools == nil then
        -- Only import already-valid legacy metadata. A malformed existing pool
        -- must fail validation instead of being overwritten by a projection.
        local legacyValid = WeaponValidation.Metadata(metadata, definition)
        if legacyValid then WeaponMetadata.EnsureAmmunitionPools(metadata, definition) end
    end
    local valid, errors = WeaponValidation.Metadata(metadata, definition)
    if not valid then
        return WeaponResult.Error(WeaponErrors.ITEM_INVALID, "Weapon item metadata is invalid", errors, correlationId)
    end
    local attachments = DefinitionRegistry.ValidateAttachmentSet(definition.id, metadata.attachments)
    if not attachments.ok then
        attachments.correlationId = correlationId
        return attachments
    end
    return WeaponResult.Ok(metadata, correlationId)
end
