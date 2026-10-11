-- Placement tool for a gunsmith bench's preview spot (DevMode only).
-- /cosmeticsplace spawns a model of the weapon in hand (or a Cattleman) where
-- the preview would put it and opens a small menu to move and turn it. "Print
-- to F8" writes the line to paste into Config.Cosmetics.Stations[...].preview.
if not Config.DevMode or not Config.Cosmetics.PlacementCommand then return end

local Menu = CosmeticsProviders.Menu
local STATION_RANGE = 15.0
local STEPS = {
    { value = 1, label = '1 cm / 1°', meters = 0.01, degrees = 1.0 },
    { value = 2, label = '5 cm / 5°', meters = 0.05, degrees = 5.0 },
    { value = 3, label = '10 cm / 15°', meters = 0.10, degrees = 15.0 }
}

-- { menuId, pageId, coordsElement, object, coords, heading, step, forward, right, stationId }
local placing

local function Value(result)
    if type(result) ~= 'table' or result.ok ~= true then
        error(('feather-menu-v2: %s'):format(type(result) == 'table' and tostring(result.message) or 'invalid response'))
    end
    return result.value
end

local function NearestStation()
    local position = GetEntityCoords(PlayerPedId())
    local nearestId, nearestDistance
    for stationId, station in pairs(Config.Cosmetics.Stations or {}) do
        local distance = #(position - station.coords)
        if distance <= STATION_RANGE and (not nearestDistance or distance < nearestDistance) then
            nearestId, nearestDistance = stationId, distance
        end
    end
    return nearestId
end

local function Describe()
    local c = placing.coords
    return ('X %.3f  Y %.3f  Z %.3f\nHeading %.1f°'):format(c.x, c.y, c.z, placing.heading % 360.0)
end

local function Update()
    if not placing or not DoesEntityExist(placing.object) then return end
    local c = placing.coords
    SetEntityCoords(placing.object, c.x, c.y, c.z, false, false, false, false)
    CosmeticsPreview.SetModelHeading(placing.object, placing.heading)
    pcall(function() Menu:SetElementValue(placing.menuId, placing.pageId, placing.coordsElement, Describe()) end)
end

-- Moves relative to where the player faced when the tool opened.
local function Move(forwardSteps, rightSteps, upSteps)
    if not placing then return end
    local meters = STEPS[placing.step].meters
    local f, r = placing.forward, placing.right
    placing.coords = vector3(
        placing.coords.x + (f.x * forwardSteps + r.x * rightSteps) * meters,
        placing.coords.y + (f.y * forwardSteps + r.y * rightSteps) * meters,
        placing.coords.z + upSteps * meters)
    Update()
end

local function Turn(direction)
    if not placing then return end
    placing.heading = (placing.heading + direction * STEPS[placing.step].degrees) % 360.0
    Update()
end

local function SnapToSurface()
    if not placing then return end
    local surface = CosmeticsPreview.SurfaceBelow(vector3(placing.coords.x, placing.coords.y, placing.coords.z + 0.5))
    if not surface then
        CosmeticsNotify('No bench or table under the weapon.')
        return
    end
    placing.coords = surface
    Update()
end

local function Print()
    if not placing then return end
    local c = placing.coords
    print(('[feather-weapons cosmetics] preview spot for station %s:'):format(tostring(placing.stationId or '?')))
    print(('preview = { coords = vector3(%.3f, %.3f, %.3f), heading = %.1f },'):format(
        c.x, c.y, c.z, placing.heading % 360.0))
    CosmeticsNotify('Preview spot printed to F8.')
end

local function Cleanup()
    if not placing then return end
    CosmeticsPreview.DeleteModel(placing.object)
    placing = nil
end

local function BuildMenu()
    local menuId = Value(Menu:CreateMenu({
        key = 'feather-weapons:cosmetics-placement',
        draggable = true,
        closable = true,
        size = { width = '22rem', maxHeight = '85vh' },
        position = Config.Cosmetics.MenuPosition,
        theme = { preset = 'redemption', accent = '#CC9900' }
    })).menuId
    placing.menuId = menuId
    Value(Menu:RegisterMenuLifecycle(menuId, function(event)
        if type(event) == 'table' and event.event == 'closed' then
            Cleanup()
            pcall(function() Menu:DestroyMenu(menuId) end)
        end
    end))
    local pageId = Value(Menu:CreatePage(menuId, { key = 'placement' })).pageId
    placing.pageId = pageId
    local count = 0
    local function Add(kind, spec, callback)
        count = count + 1
        spec.key = ('%s-%d'):format(kind, count)
        return Value(Menu:AddElement(menuId, pageId, kind, spec, callback)).elementId
    end

    Add('header', { value = 'Preview Spot', slot = 'header' })
    Add('subheader', { value = placing.stationId and ('Station: %s'):format(placing.stationId)
        or 'No station nearby', slot = 'header' })
    placing.coordsElement = Add('textdisplay', { value = Describe(), slot = 'content' })

    local stepOptions = {}
    for _, step in ipairs(STEPS) do stepOptions[#stepOptions + 1] = { value = step.value, label = step.label } end
    Add('dropdown', { label = 'Step', value = placing.step, options = stepOptions, slot = 'content' }, function(event)
        local value = type(event) == 'table' and tonumber(event.value) or nil
        if placing and value and STEPS[value] then placing.step = value end
    end)

    Add('button', { label = 'Forward', row = 'fb', slot = 'content' }, function() Move(1, 0, 0) end)
    Add('button', { label = 'Back', row = 'fb', slot = 'content' }, function() Move(-1, 0, 0) end)
    Add('button', { label = '← Left', row = 'lr', slot = 'content' }, function() Move(0, -1, 0) end)
    Add('button', { label = 'Right →', row = 'lr', slot = 'content' }, function() Move(0, 1, 0) end)
    Add('button', { label = '↑ Up', row = 'ud', slot = 'content' }, function() Move(0, 0, 1) end)
    Add('button', { label = 'Down ↓', row = 'ud', slot = 'content' }, function() Move(0, 0, -1) end)
    Add('button', { label = '⟲ Turn left', row = 'turn', slot = 'content' }, function() Turn(1) end)
    Add('button', { label = 'Turn right ⟳', row = 'turn', slot = 'content' }, function() Turn(-1) end)
    Add('button', { label = 'Drop onto bench', slot = 'content' }, SnapToSurface)
    Add('line', { slot = 'content' })
    Add('button', { label = 'Print to F8', slot = 'content' }, Print)
    Add('button', { label = 'Close', slot = 'content' }, function()
        pcall(function() Menu:CloseMenu(menuId) end)
    end)

    Value(Menu:OpenMenu(menuId, { pageId = pageId }))
end

local function Open()
    if placing then return end
    if CosmeticsMenuOpen() then
        CosmeticsNotify('Close the gunsmith menu first.')
        return
    end
    local ped = PlayerPedId()
    local present, weaponHash = GetCurrentPedWeapon(ped, true, 0, false)
    if not (present == true or present == 1) or weaponHash == joaat('WEAPON_UNARMED') then
        weaponHash = joaat('WEAPON_REVOLVER_CATTLEMAN')
    end

    local stationId = NearestStation()
    local station = stationId and Config.Cosmetics.Stations[stationId]
    local spot = station and station.preview
    local coords = (spot and spot.coords) or CosmeticsPreview.DefaultSpot(stationId)
    local object, failure = CosmeticsPreview.SpawnModel(weaponHash, coords)
    if not object then
        CosmeticsNotify(('Could not spawn the weapon model: %s'):format(tostring(failure)))
        return
    end
    SetEntityCollision(object, false, false)
    FreezeEntityPosition(object, true)

    local forward = GetEntityForwardVector(ped)
    local length = math.sqrt(forward.x * forward.x + forward.y * forward.y)
    if length < 0.0001 then forward, length = vector3(0.0, 1.0, 0.0), 1.0 end
    local fx, fy = forward.x / length, forward.y / length
    placing = {
        object = object,
        coords = coords,
        -- Side-on to the player, like the preview (Config.Cosmetics.Preview.rotation.z adds 90).
        heading = (spot and tonumber(spot.heading)) or ((GetEntityHeading(ped) + 180.0) % 360.0),
        step = 1,
        forward = { x = fx, y = fy },
        right = { x = fy, y = -fx },
        stationId = stationId
    }
    Update()

    local built, problem = pcall(function()
        Value(Menu:AwaitReady(5000))
        BuildMenu()
    end)
    if not built then
        print(('[feather-weapons cosmetics] placement menu failed: %s'):format(tostring(problem)))
        CosmeticsNotify('The placement menu could not be opened.')
        Cleanup()
    end
end

RegisterCommand(Config.Cosmetics.PlacementCommand, function() CreateThread(Open) end, false)

AddEventHandler('onClientResourceStop', function(resource)
    if resource == GetCurrentResourceName() then Cleanup() end
end)
