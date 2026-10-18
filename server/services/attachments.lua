AttachmentService = {}

local function Context(source, rpcContext, reason)
    return {
        actorSource = source,
        actorCharacterId = rpcContext.characterId,
        characterId = rpcContext.characterId,
        sessionId = rpcContext.sessionId,
        correlationId = rpcContext.correlationId,
        reason = reason,
        resource = "feather-weapons"
    }
end

local function Equipped(source, rpcContext, request)
    request = type(request) == "table" and request or {}
    local slot = WeaponRuntime.NormalizeSlot(request.slot)
    if not slot then
        return nil, WeaponResult.Error(WeaponErrors.ITEM_INVALID,
            "Weapon equipment slot is invalid", nil, rpcContext.correlationId)
    end
    local runtime = WeaponRuntime.Get(source)
    local equipped = runtime and runtime.slots and runtime.slots[slot] or nil
    if not runtime or runtime.sessionId ~= rpcContext.sessionId or not equipped then
        return nil, WeaponResult.Error(WeaponErrors.NOT_EQUIPPED, "Equip a weapon before modifying it", nil,
            rpcContext.correlationId)
    end
    if not WeaponRuntime.MatchesLease(source, rpcContext.sessionId,
        request.itemInstanceId, tonumber(request.generation), slot) then
        return nil, WeaponResult.Error(WeaponErrors.SESSION_EXPIRED,
            "The equipped weapon lease is no longer current", { slot = slot }, rpcContext.correlationId)
    end
    return equipped, nil, slot
end

local function AtGunsmithStation(source, rpcContext)
    local settings = Config.Attachments or {}
    if settings.requireStation ~= true then return WeaponResult.Ok(true, rpcContext.correlationId) end
    local ped = GetPlayerPed(source)
    if not ped or ped <= 0 then
        return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT, "Unable to verify gunsmith location", nil,
            rpcContext.correlationId)
    end
    local position = GetEntityCoords(ped, false, true)
    local tolerance = tonumber(settings.serverTolerance) or 3.0
    for stationId, station in pairs(settings.stations or {}) do
        local coords = station.coords
        if coords then
            local dx, dy, dz = position.x - coords.x, position.y - coords.y, position.z - coords.z
            if math.sqrt(dx * dx + dy * dy + dz * dz) <= tolerance then
                return WeaponResult.Ok({ stationId = stationId, label = station.label }, rpcContext.correlationId)
            end
        end
    end
    return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
        "Weapon attachments can only be modified at a gunsmith bench", nil, rpcContext.correlationId)
end

local function ClientAttachments(metadata)
    local result = {}
    for _, installed in ipairs(metadata.attachments or {}) do
        local definition = DefinitionRegistry.Get("attachment", installed.definitionId)
        if definition.ok then
            result[#result + 1] = {
                definitionId = definition.value.id,
                slot = definition.value.slot,
                nativeComponentName = definition.value.nativeComponentName
            }
        end
    end
    return result
end

local function AuthorizeModification(source, rpcContext, station, operation, equipped, attachment)
    local authorization = (Config.Attachments or {}).authorization or {}
    if authorization.enabled ~= true then return WeaponResult.Ok(true, rpcContext.correlationId) end

    local action = authorization.action
    if type(action) ~= "string" or action == "" then
        return WeaponResult.Error(WeaponErrors.AUTHORIZATION_INVALID,
            "Gunsmith authorization is not configured", nil, rpcContext.correlationId)
    end

    local called, decision = pcall(function()
        return exports["feather-core"]:Authorize(action, {
            source = source,
            correlationId = rpcContext.correlationId,
            subject = {
                operation = operation,
                stationId = type(station.value) == "table" and station.value.stationId or nil,
                weaponDefinitionId = equipped.definitionId,
                attachmentId = attachment.id
            }
        })
    end)
    if not called or type(decision) ~= "table" or decision.ok ~= true
        or type(decision.value) ~= "table" or type(decision.value.allowed) ~= "boolean" then
        return WeaponResult.Error(WeaponErrors.AUTHORIZATION_INVALID,
            "Gunsmith authorization is unavailable", nil, rpcContext.correlationId)
    end
    if decision.value.allowed ~= true then
        return WeaponResult.Error(WeaponErrors.AUTHORIZATION_INVALID,
            "This character is not authorized to modify weapons", {
                action = action,
                code = decision.value.code
            }, rpcContext.correlationId)
    end
    return WeaponResult.Ok(true, rpcContext.correlationId)
end

-- Shared server station/authorization policy; native ownership and generation
-- are independently reserved by the native transition coordinator, not legacy.
function AttachmentService.AuthorizeNativeModification(source,context,operation,weapon,attachment)
    if operation~='install' and operation~='remove' then return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,'Invalid native attachment action') end
    local station=AtGunsmithStation(source,context)
    if not station.ok then return station end
    return AuthorizeModification(source,context,station,operation,{definitionId=weapon.id},attachment)
end

function AttachmentService.Install(source, rpcContext, request)
    if Config.CharacterAmmunitionEnabled==true or Config.CharacterAmmoTransportEnabled==true then
        return WeaponResult.Error('hybrid_runtime_disabled','Legacy gameplay is disabled for native ammunition')
    end
    request = type(request) == "table" and request or {}
    local equipped, failure, slot = Equipped(source, rpcContext, request)
    if not equipped then return failure end
    local station = AtGunsmithStation(source, rpcContext)
    if not station.ok then return station end
    local attachmentId = request.attachmentId
    local attachmentResult = DefinitionRegistry.Get("attachment", attachmentId)
    if not attachmentResult.ok then return attachmentResult end
    local attachment = attachmentResult.value
    if not DefinitionRegistry.IsAttachmentCompatible(equipped.definitionId, attachment.id) then
        return WeaponResult.Error(WeaponErrors.ITEM_INVALID, "Attachment is not compatible with the equipped weapon", {
            weaponId = equipped.definitionId, attachmentId = attachment.id
        }, rpcContext.correlationId)
    end
    local authorization = AuthorizeModification(source, rpcContext, station,
        "install", equipped, attachment)
    if not authorization.ok then return authorization end

    local context = Context(source, rpcContext, "attachment_install")
    local transaction = InventoryAdapter.Transaction(context, function(tx)
        local item = tx:GetItemForUpdate(equipped.itemInstanceId)
        if not item then
            return WeaponResult.Error(WeaponErrors.ITEM_NOT_OWNED, "Equipped weapon is no longer owned", nil,
                context.correlationId)
        end
        local weaponResult = DefinitionRegistry.Get("weapon", equipped.definitionId)
        if not weaponResult.ok then return weaponResult end
        local metadata = item.metadata
        local validated = WeaponMetadata.Validate(metadata, weaponResult.value, context.correlationId)
        if not validated.ok then return validated end
        for _, installed in ipairs(metadata.attachments) do
            if installed.definitionId == attachment.id then
                return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT, "Attachment is already installed", nil,
                    context.correlationId)
            end
            if installed.slot == attachment.slot then
                return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT, "That attachment slot is already occupied", {
                    slot = attachment.slot, installed = installed.definitionId
                }, context.correlationId)
            end
        end
        if tx:GetQuantity(attachment.itemName) < 1 or not tx:RemoveQuantity(attachment.itemName, 1) then
            return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT, "Required attachment item is unavailable", {
                itemName = attachment.itemName
            }, context.correlationId)
        end
        metadata.attachments[#metadata.attachments + 1] = { definitionId = attachment.id, slot = attachment.slot }
        local attachmentSet = DefinitionRegistry.ValidateAttachmentSet(equipped.definitionId, metadata.attachments)
        if not attachmentSet.ok then return attachmentSet end
        if not tx:SetMetadata(item.id, metadata, item.metadataRevision) then
            return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT, "Weapon metadata changed during installation", nil,
                context.correlationId)
        end
        return {
            slot = slot,
            generation = equipped.generation,
            itemInstanceId = item.id,
            attachmentId = attachment.id,
            installed = true,
            attachments = ClientAttachments(metadata)
        }
    end)
    if not transaction.ok then return transaction end
    if WeaponRuntime.MatchesLease(source, rpcContext.sessionId, equipped.itemInstanceId,
        equipped.generation, slot) then
        WeaponRuntime.SetSlotAttachments(source, rpcContext.sessionId, slot,
            transaction.value.attachments, rpcContext.correlationId)
    end
    return WeaponResult.Ok(transaction.value, rpcContext.correlationId)
end

function AttachmentService.Remove(source, rpcContext, request)
    if Config.CharacterAmmunitionEnabled==true or Config.CharacterAmmoTransportEnabled==true then
        return WeaponResult.Error('hybrid_runtime_disabled','Legacy gameplay is disabled for native ammunition')
    end
    request = type(request) == "table" and request or {}
    local equipped, failure, slot = Equipped(source, rpcContext, request)
    if not equipped then return failure end
    local station = AtGunsmithStation(source, rpcContext)
    if not station.ok then return station end
    local attachmentId = request.attachmentId
    local attachmentResult = DefinitionRegistry.Get("attachment", attachmentId)
    if not attachmentResult.ok then return attachmentResult end
    local attachment = attachmentResult.value
    if not attachment.removable then
        return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT, "Attachment cannot be removed", nil,
            rpcContext.correlationId)
    end
    local authorization = AuthorizeModification(source, rpcContext, station,
        "remove", equipped, attachment)
    if not authorization.ok then return authorization end

    local context = Context(source, rpcContext, "attachment_remove")
    local transaction = InventoryAdapter.Transaction(context, function(tx)
        local item = tx:GetItemForUpdate(equipped.itemInstanceId)
        if not item then
            return WeaponResult.Error(WeaponErrors.ITEM_NOT_OWNED, "Equipped weapon is no longer owned", nil,
                context.correlationId)
        end
        local weaponResult = DefinitionRegistry.Get("weapon", equipped.definitionId)
        if not weaponResult.ok then return weaponResult end
        local metadata = item.metadata
        local validated = WeaponMetadata.Validate(metadata, weaponResult.value, context.correlationId)
        if not validated.ok then return validated end
        local found, remaining = false, {}
        for _, installed in ipairs(metadata.attachments) do
            if installed.definitionId == attachment.id then found = true else remaining[#remaining + 1] = installed end
        end
        if not found then
            return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT, "Attachment is not installed", nil,
                context.correlationId)
        end
        local attachmentSet = DefinitionRegistry.ValidateAttachmentSet(equipped.definitionId, remaining)
        if not attachmentSet.ok then return attachmentSet end
        if not tx:AddQuantity(attachment.itemName, 1) then
            return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT, "Inventory cannot accept the removed attachment",
                {
                    itemName = attachment.itemName
                }, context.correlationId)
        end
        metadata.attachments = remaining
        if not tx:SetMetadata(item.id, metadata, item.metadataRevision) then
            return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT, "Weapon metadata changed during removal", nil,
                context.correlationId)
        end
        return {
            slot = slot,
            generation = equipped.generation,
            itemInstanceId = item.id,
            attachmentId = attachment.id,
            installed = false,
            attachments = ClientAttachments(metadata)
        }
    end)
    if not transaction.ok then return transaction end
    if WeaponRuntime.MatchesLease(source, rpcContext.sessionId, equipped.itemInstanceId,
        equipped.generation, slot) then
        WeaponRuntime.SetSlotAttachments(source, rpcContext.sessionId, slot,
            transaction.value.attachments, rpcContext.correlationId)
    end
    return WeaponResult.Ok(transaction.value, rpcContext.correlationId)
end

FeatherCore.RPC.Register("feather-weapons:attachment:install", function(params, respond, source, context)
    respond(AttachmentService.Install(source, context, params))
end, { requireCharacter = true, windowMs = 2000, maxCalls = 3, maxPayloadBytes = 256 })

FeatherCore.RPC.Register("feather-weapons:attachment:remove", function(params, respond, source, context)
    respond(AttachmentService.Remove(source, context, params))
end, { requireCharacter = true, windowMs = 2000, maxCalls = 3, maxPayloadBytes = 256 })
