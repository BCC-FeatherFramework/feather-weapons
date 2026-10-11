-- Weapon cosmetics: the look players choose at a gunsmith bench (grips,
-- engravings, materials, tints, wraps, straps). The choice is stored in the
-- weapon item's metadata.cosmetics as { [category] = nativeComponentName }, so
-- it travels with the item when it is stored, dropped, picked up or given, and
-- goes away with it when the item is destroyed. Functional attachments stay in
-- metadata.attachments and are never offered or saved here.
--
-- These RPCs answer { ok, value } or { ok = false, code } (the shape the
-- cosmetics client and its translations use), not WeaponResult.
CosmeticsService = {}

local function Ok(value) return { ok = true, value = value } end
local function Err(code) return { ok = false, code = code } end

local function ResultCode(result, fallback)
    if type(result) ~= "table" then return fallback end
    if type(result.error) == "table" and result.error.code then return tostring(result.error.code) end
    return result.code and tostring(result.code) or fallback
end

local function AtStation(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    local position = GetEntityCoords(ped)
    local interaction = Config.Cosmetics.Interaction or {}
    local reach = (tonumber(interaction.distance) or 2.0) + (tonumber(interaction.serverTolerance) or 3.0)
    for _, station in pairs(Config.Cosmetics.Stations or {}) do
        if #(position - station.coords) <= reach then return true end
    end
    return false
end

-- Native component names of every attachment the weapon definition allows:
-- these belong to Feather's attachment system, never to cosmetics.
local function ReservedComponents(definition)
    local reserved = {}
    for _, attachmentIds in pairs(definition.attachmentSlots or {}) do
        for _, attachmentId in ipairs(attachmentIds) do
            local attachment = WeaponDefinitionCatalog.attachments[attachmentId]
            if attachment and attachment.nativeComponentName then reserved[attachment.nativeComponentName] = true end
        end
    end
    return reserved
end

-- Native component names of the attachments installed on an item.
local function InstalledComponents(attachments)
    local names = {}
    for _, installed in ipairs(attachments or {}) do
        local attachment = WeaponDefinitionCatalog.attachments[installed.definitionId]
        if attachment and attachment.nativeComponentName then names[#names + 1] = attachment.nativeComponentName end
    end
    return names
end

local function ListOf(set)
    local list = {}
    for value in pairs(set or {}) do list[#list + 1] = value end
    table.sort(list)
    return list
end

local function NativeWeaponNames()
    local names = {}
    for _, definition in pairs(WeaponDefinitionCatalog.weapons or {}) do
        if definition.nativeWeaponName then names[#names + 1] = definition.nativeWeaponName end
    end
    table.sort(names)
    return names
end

local function EquippedSlots(source)
    local inspected = ReconciliationService.InspectMetadata(tonumber(source))
    if type(inspected) ~= "table" or inspected.ok ~= true then
        return nil, ResultCode(inspected, "unavailable")
    end
    return inspected.value.slots or {}
end

-- The equipped weapons that can be customized, with their saved look.
function CosmeticsService.Loadout(source)
    local slots, failure = EquippedSlots(source)
    if not slots then return Err(failure) end

    local entries = {}
    for slotName, equipped in pairs(slots) do
        local definition = WeaponDefinitionCatalog.weapons[equipped.definitionId]
        local reserved = definition and ReservedComponents(definition)
        local catalog = definition and CosmeticsCatalog.Catalog(definition.nativeWeaponName, reserved)
        if catalog then
            entries[#entries + 1] = {
                slot = slotName,
                itemInstanceId = equipped.itemInstanceId,
                serialNumber = equipped.serialNumber,
                definitionId = equipped.definitionId,
                label = definition.label,
                nativeWeaponName = definition.nativeWeaponName,
                reserved = ListOf(reserved),
                functional = InstalledComponents(equipped.attachments),
                cosmetics = CosmeticsCatalog.Sanitize(catalog, equipped.cosmetics)
            }
        end
    end
    return Ok({ slots = entries, nativeWeapons = NativeWeaponNames() })
end

-- Saves a look on one of the character's equipped weapons. An empty selection
-- puts the weapon back to its native look.
function CosmeticsService.Save(source, rpcContext, params)
    params = type(params) == "table" and params or {}
    if not AtStation(source) then return Err("not_at_station") end

    local slots, failure = EquippedSlots(source)
    if not slots then return Err(failure) end

    -- Only a weapon this character has equipped right now can be changed, so a
    -- client cannot name another player's item instance.
    local equipped
    for _, candidate in pairs(slots) do
        if tostring(candidate.itemInstanceId) == tostring(params.itemInstanceId) then equipped = candidate; break end
    end
    if not equipped then return Err("not_equipped") end

    local definition = WeaponDefinitionCatalog.weapons[equipped.definitionId]
    local catalog = definition and CosmeticsCatalog.Catalog(definition.nativeWeaponName, ReservedComponents(definition))
    if not catalog then return Err("weapon_unsupported") end

    local selection, invalid = CosmeticsCatalog.Normalize(catalog, params.cosmetics)
    if not selection then return Err(invalid) end

    local context = {
        actorSource = source,
        actorCharacterId = rpcContext.characterId,
        characterId = rpcContext.characterId,
        sessionId = rpcContext.sessionId,
        correlationId = rpcContext.correlationId,
        reason = "cosmetics",
        resource = "feather-weapons"
    }
    local transaction = InventoryAdapter.Transaction(context, function(tx)
        local item = tx:GetItemForUpdate(equipped.itemInstanceId)
        if not item or type(item.metadata) ~= "table" then
            return WeaponResult.Error(WeaponErrors.ITEM_NOT_OWNED,
                "Equipped weapon is no longer owned", nil, context.correlationId)
        end
        item.metadata.cosmetics = selection
        local definitionResult = DefinitionRegistry.Get("weapon", item.metadata.weaponDefinitionId)
        if not definitionResult.ok then return definitionResult end
        local validation = WeaponMetadata.Validate(item.metadata, definitionResult.value, context.correlationId)
        if not validation.ok then return validation end
        if not tx:SetMetadata(item.id, item.metadata, item.metadataRevision) then
            return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
                "Weapon metadata changed while saving cosmetics", nil, context.correlationId)
        end
        return { itemInstanceId = item.id, cosmetics = selection }
    end)
    if not transaction.ok then
        local code = ResultCode(transaction, "unavailable")
        if Config.DevMode then
            print(("[feather-weapons cosmetics] save failed source=%s item=%s code=%s"):format(
                tostring(source), tostring(equipped.itemInstanceId), code))
        end
        return Err(code == WeaponErrors.ITEM_NOT_OWNED and "not_equipped" or "unavailable")
    end
    return Ok(transaction.value)
end

-- Errors raised inside a handler are reported as "unavailable" to the player
-- and printed for the server owner.
local function Guarded(name, handler)
    return function(params, respond, source, context)
        local called, result = pcall(handler, source, context, params)
        if not called then
            print(("[feather-weapons cosmetics] %s failed for source %s: %s"):format(name, tostring(source), tostring(result)))
            result = Err("unavailable")
        end
        respond(result)
    end
end

FeatherCore.RPC.Register("feather-weapons:cosmetics:loadout", Guarded("loadout", function(source)
    return CosmeticsService.Loadout(source)
end), { requireCharacter = true, windowMs = 1000, maxCalls = 4, maxPayloadBytes = 128 })

FeatherCore.RPC.Register("feather-weapons:cosmetics:save", Guarded("save", CosmeticsService.Save),
    { requireCharacter = true, windowMs = 2000, maxCalls = 3, maxPayloadBytes = 4096 })
