-- Gunsmith benches: a map blip and a hold prompt that opens the gunsmith menu.
local toolkit = CosmeticsProviders.Toolkit
local promptGroup = GetRandomIntInRange(0, 0xffffff)
local promptId

local function Value(result)
    return type(result) == 'table' and result.ok == true and result.value or nil
end

local function CreateStationPrompt()
    local created = Value(toolkit:CreatePrompt({
        label = CosmeticsT('prompt_open'),
        control = Config.Cosmetics.Interaction.promptKey,
        groupId = promptGroup,
        enabled = true,
        mode = 'hold',
        holdMode = Config.Cosmetics.Interaction.holdMode
    }))
    promptId = created and created.id or nil
end

local function PromptCompleted()
    local completed = promptId and Value(toolkit:IsPromptCompleted(promptId))
    return completed and completed.completed == true
end

local function NearestStation()
    local position = GetEntityCoords(PlayerPedId())
    local nearestId, nearestDistance
    for stationId, station in pairs(Config.Cosmetics.Stations or {}) do
        local distance = #(position - station.coords)
        if not nearestDistance or distance < nearestDistance then
            nearestId, nearestDistance = stationId, distance
        end
    end
    return nearestId, nearestDistance
end

CreateThread(function()
    for _, station in pairs(Config.Cosmetics.Stations or {}) do
        if station.blip then
            toolkit:CreateBlip({
                name = CosmeticsT(station.label),
                sprite = joaat(Config.Cosmetics.Interaction.blipSprite),
                x = station.coords.x, y = station.coords.y, z = station.coords.z
            })
        end
    end
    CreateStationPrompt()

    while true do
        local stationId, distance = NearestStation()
        if stationId and distance <= Config.Cosmetics.Interaction.distance and not CosmeticsMenuOpen() then
            toolkit:ShowPromptGroup(promptGroup, CosmeticsT(Config.Cosmetics.Stations[stationId].label))
            if PromptCompleted() then OpenCosmeticsMenu(stationId) end
            Wait(0)
        else
            Wait((distance and distance < 25.0) and 250 or 1000)
        end
    end
end)
