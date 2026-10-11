-- feather-chat autocomplete for Feather Weapons' player commands. Names come
-- from Config so renamed commands stay in sync; a disabled command is not
-- advertised. Registered once Chat is ready and again on `chat.ready.v1`
-- (Chat rebuilds its registry on every restart).
local registered = false

local function Definitions()
    local list = {}
    local function Add(key, command, description)
        if type(command) == 'string' and command ~= '' then
            list[#list + 1] = { key = 'feather-weapons.' .. key, trigger = '/' .. command, description = description }
        end
    end
    local controls = Config.Controls or {}
    if controls.unload and controls.unload.enabled then
        Add('unload', controls.unload.command, 'Unload the equipped weapon')
    end
    if controls.modify and controls.modify.enabled then
        Add('modify', controls.modify.command, 'Install or remove barrels and sights (at a gunsmith bench)')
    end
    if controls.ammunition and controls.ammunition.enabled then
        Add('ammunition', controls.ammunition.command, 'Manage the ammunition of your equipped weapons')
    end
    if controls.inspect and controls.inspect.enabled then
        Add('inspect', controls.inspect.command, 'Inspect the weapon in your hands')
    end
    if Config.DevMode and Config.Cosmetics and Config.Cosmetics.PlacementCommand then
        Add('cosmetics-place', Config.Cosmetics.PlacementCommand, 'Dev: place the gunsmith preview weapon and print its spot')
    end
    return list
end

local function Register()
    if registered or GetResourceState('feather-chat') ~= 'started' then return end
    local health = exports['feather-chat']:GetHealth()
    if not health.ok or health.value.state ~= 'ready' then return end
    for _, definition in ipairs(Definitions()) do
        local result = exports['feather-chat']:RegisterSuggestion(definition)
        if not result.ok and result.code ~= 'conflict' then
            print('[feather-weapons] chat suggestion registration failed code=' .. tostring(result.code)
                .. ' trigger=' .. definition.trigger)
            return
        end
    end
    registered = true
end

AddEventHandler('chat.ready.v1', Register)
AddEventHandler('onResourceStop', function(resource) if resource == 'feather-chat' then registered = false end end)
CreateThread(Register)
