-- Weapon cosmetics. Run from the feather-weapons directory: lua tests/cosmetics.lua
local ROOT = './'
local failures, passes = 0, 0
local function check(name, condition, detail)
    if condition then passes = passes + 1 else failures = failures + 1; print('FAIL ' .. name .. ' ' .. tostring(detail or '')) end
end

-- 1. Syntax of every new file.
for _, path in ipairs({ 'config.lua', 'config_cosmetics.lua', 'shared/cosmetics/definitions/components.lua',
    'shared/cosmetics/definitions/shared_components.lua', 'shared/cosmetics/definitions/shared_groups.lua',
    'shared/cosmetics/catalog.lua', 'client/cosmetics/imports.lua', 'client/cosmetics/apply.lua',
    'client/cosmetics/preview.lua', 'client/cosmetics/stations.lua', 'client/cosmetics/menu.lua',
    'client/cosmetics/placement.lua',
    'server/services/cosmetics.lua', 'translations/cosmetics_en_us.lua', 'translations/cosmetics_ro.lua',
    'fxmanifest.lua' }) do
    local chunk, problem = loadfile(ROOT .. path)
    check('syntax ' .. path, chunk ~= nil, problem)
end

-- 2. Shared catalog with the real component data.
local vec = {}
vec.__index = vec
vec.__sub = function(a, b) return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, vec) end
vec.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
vec.__add = function(a, b) return setmetatable({ x = a.x + b.x, y = a.y + b.y, z = a.z + b.z }, vec) end
vec.__mul = function(a, k) return setmetatable({ x = a.x * k, y = a.y * k, z = a.z * k }, vec) end
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, vec) end
json = { encode = function(t) return t end, decode = function(t) return t end }

for _, path in ipairs({ 'config.lua', 'config_cosmetics.lua', 'shared/cosmetics/definitions/shared_groups.lua',
    'shared/cosmetics/definitions/components.lua', 'shared/cosmetics/definitions/shared_components.lua',
    'shared/cosmetics/catalog.lua' }) do
    dofile(ROOT .. path)
end

local cattleReserved = { COMPONENT_REVOLVER_CATTLEMAN_BARREL_LONG = true, COMPONENT_REVOLVER_CATTLEMAN_SIGHT_WIDE = true }
local catalog = CosmeticsCatalog.Catalog('WEAPON_REVOLVER_CATTLEMAN', cattleReserved)
check('cattleman catalog exists', catalog ~= nil)
check('barrel excluded', catalog.categories.BARREL == nil)
check('sight excluded', catalog.categories.SIGHT == nil)
check('grip offered', catalog.categories.GRIP ~= nil)
check('grip default is standard', catalog.categories.GRIP.default == 'COMPONENT_REVOLVER_CATTLEMAN_GRIP',
    catalog.categories.GRIP.default)
check('shared materials offered', catalog.categories.FRAME_MATERIAL ~= nil)
check('frame vertdata ordered first', catalog.order[1] == 'FRAME_VERTDATA', catalog.order[1])
local categoryCount = 0
for _ in pairs(catalog.categories) do categoryCount = categoryCount + 1 end
print(('cattleman cosmetic categories: %d (%s)'):format(categoryCount, table.concat(catalog.order, ',')))

-- Automatic exclusion: a category holding a Feather component is dropped even if not in FunctionalCategories.
Config.Cosmetics.FunctionalCategories.SIGHT = nil
local auto = CosmeticsCatalog.Catalog('WEAPON_REVOLVER_CATTLEMAN', cattleReserved)
check('reserved component excludes category automatically', auto.categories.SIGHT == nil)
Config.Cosmetics.FunctionalCategories.SIGHT = true

-- Scopes are functional (they change aiming): never a cosmetic choice.
local carcano = CosmeticsCatalog.Catalog('WEAPON_SNIPERRIFLE_CARCANO', {})
check('scope not offered as a cosmetic', carcano and carcano.categories.SCOPE == nil)
local scoped, scopeCode = CosmeticsCatalog.Normalize(carcano, { SCOPE = 'COMPONENT_RIFLE_SCOPE02' })
check('scope rejected on save', scoped == nil and scopeCode == 'invalid_component', scopeCode)
check('unknown weapon unsupported', CosmeticsCatalog.Catalog('WEAPON_NOT_REAL', {}) == nil)
check('carbine catalog', CosmeticsCatalog.Catalog('WEAPON_REPEATER_CARBINE', { COMPONENT_REPEATER_CARBINE_SIGHT_WIDE = true }) ~= nil)
check('knife catalog', CosmeticsCatalog.Catalog('WEAPON_MELEE_KNIFE', {}) ~= nil)

local pearl = 'COMPONENT_REVOLVER_CATTLEMAN_GRIP_PEARL'
local engraving = catalog.categories.FRAME_ENGRAVING.items[1].name
local engravingMaterial = catalog.categories.FRAME_ENGRAVING_MATERIAL.items[1].name

local normalized, code = CosmeticsCatalog.Normalize(catalog, { GRIP = pearl })
check('valid grip accepted', normalized and normalized.GRIP == pearl, code)
normalized = CosmeticsCatalog.Normalize(catalog, { GRIP = 'COMPONENT_REVOLVER_CATTLEMAN_GRIP' })
check('default grip stored as nothing', normalized and next(normalized) == nil)
normalized, code = CosmeticsCatalog.Normalize(catalog, { BARREL = 'COMPONENT_REVOLVER_CATTLEMAN_BARREL_LONG' })
check('functional category rejected', normalized == nil and code == 'invalid_component', code)
normalized, code = CosmeticsCatalog.Normalize(catalog, { GRIP = 'COMPONENT_PISTOL_MAUSER_GRIP_PEARL' })
check('other weapon component rejected', normalized == nil and code == 'invalid_component', code)
normalized, code = CosmeticsCatalog.Normalize(catalog, { FRAME_ENGRAVING_MATERIAL = engravingMaterial })
check('material without engraving rejected', normalized == nil and code == 'dependency_missing', code)
normalized = CosmeticsCatalog.Normalize(catalog, { FRAME_ENGRAVING = engraving, FRAME_ENGRAVING_MATERIAL = engravingMaterial })
check('engraving with material accepted', normalized and normalized.FRAME_ENGRAVING_MATERIAL == engravingMaterial)
normalized, code = CosmeticsCatalog.Normalize(catalog, 'nope')
check('non-table rejected', normalized == nil and code == 'invalid_selection', code)
normalized, code = CosmeticsCatalog.Normalize(catalog, { [1] = pearl })
check('array key rejected', normalized == nil, code)

local cleaned = CosmeticsCatalog.Sanitize(catalog, { GRIP = pearl, BARREL = 'X', FRAME_ENGRAVING_MATERIAL = engravingMaterial })
check('sanitize keeps valid', cleaned.GRIP == pearl)
check('sanitize drops invalid', cleaned.BARREL == nil)
check('sanitize drops orphan material', cleaned.FRAME_ENGRAVING_MATERIAL == nil)

-- 3. Server save/loadout: the look is stored in the weapon item's metadata.cosmetics.
local rpcs = {}
local playerPos = vector3(-277.455, 779.197, 119.504)
local equippedSlots, items, conflictNext, inspectFailure, lastContext
local function DeepCopy(value)
    if type(value) ~= 'table' then return value end
    local copy = {}
    for key, inner in pairs(value) do copy[key] = DeepCopy(inner) end
    return copy
end
function GetPlayerPed() return 1 end
function GetEntityCoords() return playerPos end
function CreateThread(fn) fn() end
function AddEventHandler() end
function print(...) io.write(table.concat({ ... }, '\t'), '\n') end
FeatherCore = { RPC = { Register = function(name, cb) rpcs[name] = cb end } }
WeaponErrors = { ITEM_NOT_OWNED = 'WEAPON_ITEM_NOT_OWNED', OPERATION_CONFLICT = 'WEAPON_OPERATION_CONFLICT' }
WeaponResult = { Error = function(code, message) return { ok = false, error = { code = code, message = message } } end }
WeaponDefinitionCatalog = {
    weapons = { revolver_cattleman = { id = 'revolver_cattleman', label = 'Cattleman Revolver',
        nativeWeaponName = 'WEAPON_REVOLVER_CATTLEMAN',
        attachmentSlots = { barrel = { 'cattleman_long_barrel' }, sight = { 'cattleman_wide_sight' } } } },
    attachments = {
        cattleman_long_barrel = { nativeComponentName = 'COMPONENT_REVOLVER_CATTLEMAN_BARREL_LONG' },
        cattleman_wide_sight = { nativeComponentName = 'COMPONENT_REVOLVER_CATTLEMAN_SIGHT_WIDE' } }
}
-- Like the real inspection: each slot carries the item's saved metadata.cosmetics.
ReconciliationService = { InspectMetadata = function()
    if inspectFailure then return { ok = false, error = { code = inspectFailure } } end
    local slots = {}
    for name, equipped in pairs(equippedSlots) do
        local copy = DeepCopy(equipped)
        local item = items[equipped.itemInstanceId]
        copy.cosmetics = item and DeepCopy(item.metadata.cosmetics) or {}
        slots[name] = copy
    end
    return { ok = true, value = { slots = slots } }
end }
DefinitionRegistry = { Get = function() return { ok = true, value = {} } end }
WeaponMetadata = { Validate = function(metadata)
    return { ok = type(metadata.cosmetics) == 'table' }
end }
InventoryAdapter = { Transaction = function(context, fn)
    local tx = {
        GetItemForUpdate = function(_, id)
            local item = items[id]
            if not item then return nil end
            return { id = item.id, metadata = DeepCopy(item.metadata), metadataRevision = item.revision }
        end,
        SetMetadata = function(_, id, metadata, revision)
            if conflictNext then conflictNext = false; return false end
            if items[id].revision ~= revision then return false end
            items[id].metadata, items[id].revision, lastContext = metadata, revision + 1, context
            return true
        end
    }
    local result = fn(tx)
    if type(result) == 'table' and result.ok == false then return result end
    return { ok = true, value = result }
end }
dofile(ROOT .. 'server/services/cosmetics.lua')

local function call(route, params)
    local response
    rpcs[route](params, function(result) response = result end, 7,
        { characterId = 'char-1', sessionId = 'session-1', correlationId = 'corr-1' })
    return response
end

equippedSlots = { primary = { itemInstanceId = 68, serialNumber = 'SN-68', definitionId = 'revolver_cattleman',
    attachments = { { definitionId = 'cattleman_long_barrel', slot = 'barrel' } } } }
items = { [68] = { id = 68, revision = 3, metadata = { weaponDefinitionId = 'revolver_cattleman', serialNumber = 'SN-68',
    attachments = { { definitionId = 'cattleman_long_barrel', slot = 'barrel' } }, cosmetics = {} } } }

local loadout = call('feather-weapons:cosmetics:loadout', {})
check('loadout ok', loadout.ok, loadout.code)
local slot = loadout.value.slots[1]
check('loadout slot', slot and slot.itemInstanceId == 68 and slot.slot == 'primary')
check('loadout mirrors feather barrel', slot.functional[1] == 'COMPONENT_REVOLVER_CATTLEMAN_BARREL_LONG')
check('loadout reserved list', #slot.reserved == 2)
check('loadout native list', loadout.value.nativeWeapons[1] == 'WEAPON_REVOLVER_CATTLEMAN')

local saved = call('feather-weapons:cosmetics:save', { itemInstanceId = 68, cosmetics = { GRIP = pearl } })
check('save ok', saved.ok, saved.code)
check('saved into metadata.cosmetics', items[68].metadata.cosmetics.GRIP == pearl)
check('rest of the metadata kept', items[68].metadata.attachments[1].definitionId == 'cattleman_long_barrel'
    and items[68].metadata.serialNumber == 'SN-68')
check('saved through a revision-checked transaction', items[68].revision == 4 and lastContext.reason == 'cosmetics'
    and lastContext.characterId == 'char-1')
loadout = call('feather-weapons:cosmetics:loadout', {})
check('loadout returns saved', loadout.value.slots[1].cosmetics.GRIP == pearl)

saved = call('feather-weapons:cosmetics:save', { itemInstanceId = 99, cosmetics = { GRIP = pearl } })
check('unequipped item rejected', not saved.ok and saved.code == 'not_equipped', saved.code)
saved = call('feather-weapons:cosmetics:save', { itemInstanceId = 68, cosmetics = { BARREL = 'COMPONENT_REVOLVER_CATTLEMAN_BARREL_LONG' } })
check('functional save rejected', not saved.ok and saved.code == 'invalid_component', saved.code)

playerPos = vector3(0, 0, 0)
saved = call('feather-weapons:cosmetics:save', { itemInstanceId = 68, cosmetics = {} })
check('away from bench rejected', not saved.ok and saved.code == 'not_at_station', saved.code)
check('metadata untouched when rejected', items[68].metadata.cosmetics.GRIP == pearl)
playerPos = vector3(-277.455, 779.197, 119.504)

conflictNext = true
saved = call('feather-weapons:cosmetics:save', { itemInstanceId = 68, cosmetics = {} })
check('concurrent change reported as unavailable', not saved.ok and saved.code == 'unavailable', saved.code)
check('metadata untouched on conflict', items[68].metadata.cosmetics.GRIP == pearl)

saved = call('feather-weapons:cosmetics:save', { itemInstanceId = 68, cosmetics = {} })
check('empty save ok', saved.ok, saved.code)
check('empty save leaves an empty cosmetics table', type(items[68].metadata.cosmetics) == 'table'
    and next(items[68].metadata.cosmetics) == nil)

local kept = items[68]
items[68] = nil
saved = call('feather-weapons:cosmetics:save', { itemInstanceId = 68, cosmetics = { GRIP = pearl } })
check('item gone during save reported as not equipped', not saved.ok and saved.code == 'not_equipped', saved.code)
items[68] = kept

inspectFailure = 'WEAPON_SESSION_EXPIRED'
loadout = call('feather-weapons:cosmetics:loadout', {})
check('inspection failure passed on', not loadout.ok and loadout.code == 'WEAPON_SESSION_EXPIRED', loadout.code)
inspectFailure = nil

-- 4. Client preview logic with stubbed natives.
function CosmeticsDebug() end
local applied = {}
Citizen = { InvokeNative = function() return 1 end, ResultAsInteger = function() end }
function joaat(name) return name end
function PlayerPedId() return 1 end
function Wait() end
function GetGameTimer() return 0 end
function SetTimeout() end
function RequestModel() end
function HasModelLoaded() return true end
function SetModelAsNoLongerNeeded() end
function GetCurrentPedWeapon() return true, 0 end
CreateThread = function() end -- keep the watcher loop from running
dofile(ROOT .. 'client/cosmetics/apply.lua')

local entry = { itemInstanceId = 68, slot = 'primary', nativeWeaponName = 'WEAPON_REVOLVER_CATTLEMAN', hash = 1,
    catalog = catalog, functional = {}, cosmetics = { GRIP = pearl }, probes = {} }
WeaponCosmetics.BeginPreview(entry)
check('no changes after begin', not WeaponCosmetics.HasChanges(entry))
local ok, detail = WeaponCosmetics.SetPreview(entry, 'FRAME_ENGRAVING_MATERIAL', engravingMaterial)
check('preview dependency blocked', not ok and detail == 'dependency_missing', detail)
ok = WeaponCosmetics.SetPreview(entry, 'FRAME_ENGRAVING', engraving)
WeaponCosmetics.SetPreview(entry, 'FRAME_ENGRAVING_MATERIAL', engravingMaterial)
check('preview has changes', WeaponCosmetics.HasChanges(entry))
ok, detail = WeaponCosmetics.SetPreview(entry, 'FRAME_ENGRAVING', nil)
check('clearing engraving clears material', ok and detail[1] == 'FRAME_ENGRAVING_MATERIAL'
    and entry.preview.FRAME_ENGRAVING_MATERIAL == nil)
WeaponCosmetics.SetPreview(entry, 'GRIP', 'COMPONENT_REVOLVER_CATTLEMAN_GRIP')
check('choosing default clears grip', entry.preview.GRIP == nil and WeaponCosmetics.HasChanges(entry))
WeaponCosmetics.EndPreview(entry)
check('end preview restores saved', entry.preview == nil and entry.cosmetics.GRIP == pearl)
WeaponCosmetics.Commit(entry, { GRIP = pearl, FRAME_ENGRAVING = engraving })
check('commit stores', entry.cosmetics.FRAME_ENGRAVING == engraving and not WeaponCosmetics.HasChanges(entry))


-- 5. Preview model and camera controls with stubbed natives.
local objectNatives, camera = {}, {}
spawnedAt, nextObject, onCreate, alive = nil, nil, nil, {}
Citizen.InvokeNative = function(hash, ...)
    if hash == 0x9888652B8BA77F73 then -- CreateWeaponObject
        local args = { ... }
        spawnedAt = vector3(args[3], args[4], args[5])
        nextObject = (nextObject or 499) + 1
        alive[nextObject] = true
        if onCreate then onCreate() end
        return nextObject
    end
    if hash == 0x74C9090FDD1BB48E then objectNatives[#objectNatives + 1] = { ... } end
    if hash == 0xFF07CF465F48B830 then return 1 end -- _HasWeaponAssetLoaded
    if hash == 0x76A18844E743BF91 or hash == 0xBBC67A6F965C688A or hash == 0x8DECB02F88F428BC then return 0 end
    return 0
end
function DoesEntityExist(entity) if alive[entity] ~= nil then return alive[entity] end return true end
function HasWeaponAssetLoaded() return true end
function GetEntityCoords() return vector3(0, 0, 0) end
function GetEntityHeading() return 90.0 end
function GetEntityForwardVector() return vector3(0, 1, 0) end -- player faces the bench (+y)
local pedHeadings = {}
function SetEntityHeading(_, heading) pedHeadings[#pedHeadings + 1] = heading end
function GetOffsetFromEntityInWorldCoords(_, x, y, z) return vector3(x, y, z) end
-- A bench 0.5 m in front of the player (y = 0.5) blocks every probe that crosses it.
local probeEnd
function StartExpensiveSynchronousShapeTestLosProbe(x1, y1, z1, x2, y2, z2)
    if (y1 < 0.5 and y2 > 0.5) or (y1 > 0.5 and y2 < 0.5) then
        local t = (0.5 - y1) / (y2 - y1)
        probeEnd = vector3(x1 + (x2 - x1) * t, 0.5, z1 + (z2 - z1) * t)
    else
        probeEnd = nil
    end
    return 1
end
function GetShapeTestResult() return 2, probeEnd ~= nil, probeEnd end
function SetEntityCollision() end
heldWeapon = 0
function GetCurrentPedWeapon() return true, heldWeapon end
function SetCurrentPedWeapon(_, hash) heldWeapon = hash end
visibleEntities = {}
function SetEntityVisible(entity, value) visibleEntities[entity] = value end
entityCoords = {}
function SetEntityCoords(entity, x, y, z) entityCoords[entity] = vector3(x, y, z) end
function SetEntityRotation() end
function SetEntityQuaternion(entity, x, y, z, w) quaternions[entity] = { x = x, y = y, z = z, w = w } end
quaternions = {}
function FreezeEntityPosition() end
function CreateCam() return 900 end
function DoesCamExist() return true end
function SetCamCoord(_, x, y, z) camera.x, camera.y, camera.z = x, y, z end
function PointCamAtCoord(_, x, y, z) camera.fx, camera.fy, camera.fz, camera.entity = x, y, z, nil end
-- The model sits where it was created (spawnedAt).
function PointCamAtEntity(_, entity, ox, oy, oz)
    camera.entity = entity
    camera.fx, camera.fy, camera.fz = spawnedAt.x + ox, spawnedAt.y + oy, spawnedAt.z + oz
end
lookAt = {}
function TaskLookAtEntity(ped, entity, duration) lookAt[ped] = { entity = entity, duration = duration } end
function TaskClearLookAt(ped) lookAt[ped] = nil end
-- The character's head is 0.65 m above their position.
function GetEntityBoneIndexByName() return 5 end
function GetWorldPositionOfEntityBone() return vector3(0.0, 0.0, 0.65) end
function SetCamFov(_, fov) camera.fov = fov end
function SetCamActive() end
function RenderScriptCams() end
function DestroyCam() end
function SetFocusEntity() end
function ClearFocus() end
local deleted = false
local missionMarked = {}
function SetEntityAsMissionEntity(entity) missionMarked[entity] = true end
function DeleteEntity(entity) deleted = true; alive[entity] = false end
local clientHandlers = {}
function AddEventHandler(name, handler) clientHandlers[name] = handler end
function GetCurrentResourceName() return 'feather-weapons' end
function CosmeticsDebug() end
dofile(ROOT .. 'client/cosmetics/preview.lua')

local previewEntry = { itemInstanceId = 68, nativeWeaponName = 'WEAPON_REVOLVER_CATTLEMAN', hash = 7,
    catalog = catalog, functional = { 'COMPONENT_REVOLVER_CATTLEMAN_BARREL_LONG' },
    cosmetics = { GRIP = pearl }, probes = {} }
-- A station's saved spot puts the model exactly there, turned to its heading.
local savedSpot = Config.Cosmetics.Stations.valentine.preview
Config.Cosmetics.Stations.valentine.preview = { coords = vector3(0.0, -2.0, 0.9), heading = 86.5 }
CosmeticsPreview.Start(previewEntry, 'valentine')
check('saved preview spot used', spawnedAt and spawnedAt.x == 0.0 and spawnedAt.y == -2.0 and spawnedAt.z == 0.9)
local spotAngle = math.rad(86.5)
-- The character stands at the origin, 2 m from the spot: the camera looks from their side.
check('camera looks at the saved spot from the character side', camera.y > -1.5,
    ('%.2f,%.2f'):format(camera.x or 0, camera.y or 0))
CosmeticsPreview.Stop()
-- The rest checks automatic placement (no saved spot).
Config.Cosmetics.Stations.valentine.preview = nil
for index in pairs(pedHeadings) do pedHeadings[index] = nil end
check('preview starts', CosmeticsPreview.Start(previewEntry, 'valentine') == true and CosmeticsPreview.Active())
check('character holds the chosen weapon', heldWeapon == 7)
local onObject = false
for _, call in ipairs(objectNatives) do
    if call[1] == 500 and call[2] == pearl and call[3] == -1 then onObject = true end
end
check('selection applied to preview model', onObject)
local barrelOnObject = false
for _, call in ipairs(objectNatives) do
    if call[1] == 500 and call[2] == 'COMPONENT_REVOLVER_CATTLEMAN_BARREL_LONG' then barrelOnObject = true end
end
check('Feather barrel mirrored on preview model', barrelOnObject)
local D = Config.Cosmetics.Preview.distance
check('model avoids the bench in front', spawnedAt and spawnedAt.y < 0.5 and math.abs(spawnedAt.x - D) < 1e-6,
    spawnedAt and ('%.2f,%.2f'):format(spawnedAt.x, spawnedAt.y))
check('camera stays clear of the bench', camera.y and camera.y < 0.5, camera.y)
-- The model is at +x, the character at the origin: the camera stands beyond the
-- character (x < 0), off the line by the shoulder angle.
-- First person: 0.2 m in front of the head toward the weapon, locked on the model.
local H = Config.Cosmetics.Preview.height -- the model's height
local eyeLine = math.sqrt(D * D + (0.65 - H) ^ 2) -- head (0,0,0.65) -> model (D,0,H)
check('camera starts at the character\'s eyes', CosmeticsPreview.ViewKey() == 'eyes' and camera.entity == nextObject
    and math.abs(math.sqrt((camera.x - D) ^ 2 + camera.y ^ 2 + (camera.z - H) ^ 2) - (eyeLine - 0.2)) < 1e-6
    and math.abs(camera.y) < 1e-9, ('%.3f,%.3f,%.3f'):format(camera.x or 0, camera.y or 0, camera.z or 0))
CosmeticsPreview.SetZoom(100)
check('eyes zoom moves toward the weapon', math.abs(math.sqrt((camera.x - D) ^ 2 + (camera.z - H) ^ 2) - 0.25) < 1e-6)
CosmeticsPreview.SetView('scene')
-- Character & Weapon: in front of the character, beyond the model (+x), on the
-- side away from the bench (y < 0).
check('character view faces the character', camera.fov == 45.0 and camera.x > D and camera.y < -0.1,
    ('%.2f,%.2f'):format(camera.x or 0, camera.y or 0))
check('character view hides the floating model', visibleEntities[nextObject] == false)
check('character view frames the character', math.abs(camera.fx) < 1e-9 and math.abs(camera.fy) < 1e-9
    and math.abs(camera.fz - Config.Cosmetics.Preview.characterHeight) < 1e-9)
check('character stops looking at the hidden model', lookAt[1] == nil)
CosmeticsPreview.SetView('full')
check('weapon view shows the model again', visibleEntities[nextObject] == true)
check('character looks at the weapon', lookAt[1] and lookAt[1].entity == nextObject and lookAt[1].duration == -1)
check('weapon view locks onto the model', camera.entity == nextObject)
CosmeticsPreview.SetView('scene')
check('character view takes the side away from the bench', camera.y < 0)
check('character turned to face the weapon', math.abs((pedHeadings[1] or -1) - 270.0) < 1e-6, pedHeadings[1])
CosmeticsPreview.SetZoom(100)
check('full zoom in the character view stays on the character', math.abs(camera.fx) < 1e-9)
CosmeticsPreview.SetView('full')
check('weapon view focuses the model', math.abs(camera.fx - D) < 1e-9)
CosmeticsPreview.SetZoom(500)
check('zoom clamped to max', CosmeticsPreview.Zoom() == 100)
local nearX, nearY = camera.x, camera.y
CosmeticsPreview.SetZoom(-5)
check('zoom clamped to min', CosmeticsPreview.Zoom() == 0)
local function DistanceToModel() return math.sqrt((camera.x - camera.fx) ^ 2 + (camera.y - camera.fy) ^ 2) end
local farDistance = DistanceToModel()
CosmeticsPreview.ZoomBy(Config.Cosmetics.Preview.keyZoomStep)
check('zoom in moves the camera closer', DistanceToModel() < farDistance)
check('zoom does not change the lens', camera.fov == Config.Cosmetics.Preview.views.full.fov)
check('max zoom is closest', math.abs(math.sqrt((nearX - camera.fx) ^ 2 + (nearY - camera.fy) ^ 2) - Config.Cosmetics.Preview.zoom.near) < 1e-6)
local focusBefore = camera.fz
CosmeticsPreview.Move(0, 1)
check('move up raises the camera focus', camera.fz > focusBefore)
for _ = 1, 100 do CosmeticsPreview.Move(1, 0) end
local panX = camera.fx
CosmeticsPreview.Move(1, 0)
check('move is limited', camera.fx == panX)
CosmeticsPreview.SetView('close')
check('view change sets its lens and zoom', camera.fov == Config.Cosmetics.Preview.views.close.fov
    and math.abs(DistanceToModel() - Config.Cosmetics.Preview.views.close.distance) < 0.01)
check('view change recenters', math.abs(camera.fz - Config.Cosmetics.Preview.height) < 1e-9 and math.abs(camera.fx - D) < 1e-9)
CosmeticsPreview.SetView('nope')
check('unknown view ignored', CosmeticsPreview.ViewKey() == 'close')
-- Keys 1-4 move the weapon; the camera keeps its place and aim.
CosmeticsPreview.SetView('full')
local camBefore = vector3(camera.x, camera.y, camera.z)
local spot = entityCoords[nextObject]
CosmeticsPreview.MoveModel(1, 0)
local moved = entityCoords[nextObject]
local step = Config.Cosmetics.Preview.moveStep
check('move weapon shifts the model one step', math.abs(#(moved - spot) - step) < 1e-9)
check('camera stays put while the weapon moves', #(vector3(camera.x, camera.y, camera.z) - camBefore) < 1e-9
    and camera.entity == nil)
CosmeticsPreview.MoveModel(-1, 0)
check('weapon back on its spot relocks the camera', #(entityCoords[nextObject] - spot) < 1e-9 and camera.entity == nextObject)
for _ = 1, 100 do CosmeticsPreview.MoveModel(0, 1) end
check('weapon move is limited', math.abs(entityCoords[nextObject].z - spot.z - Config.Cosmetics.Preview.moveLimit) < 1e-9)
CosmeticsPreview.Reset()
check('reset puts the weapon back', #(entityCoords[nextObject] - spot) < 1e-9)
CosmeticsPreview.SetView('close')
CosmeticsPreview.Tilt(45)
CosmeticsPreview.Reset()
local q = quaternions[nextObject]
-- Camera on -y, model side-on: heading 180 and no tilt is a pure turn about z.
check('reset turns the model back untilted', q and math.abs(q.x) < 1e-9 and math.abs(q.y) < 1e-9)
local firstObject = nextObject
CosmeticsPreview.Stop()
check('stop removes preview', deleted and not CosmeticsPreview.Active() and alive[firstObject] == false)
check('stop gives back the weapon held before', heldWeapon == 0)
check('character turned back on stop', pedHeadings[#pedHeadings] == 90.0)
check('character stops looking at the weapon', lookAt[1] == nil)
check('model marked as script-owned before delete', missionMarked[firstObject] == true)
Config.Cosmetics.Stations.valentine.preview = savedSpot

-- Menu closed while the model was still loading: the late model removes itself.
onCreate = function() onCreate = nil; CosmeticsPreview.Stop() end
check('late start reports no preview', CosmeticsPreview.Start(previewEntry, 'valentine') == false)
check('late model deleted', alive[nextObject] == false and not CosmeticsPreview.Active())

-- Resource restart removes the active model and hands the camera back.
CosmeticsPreview.Start(previewEntry, 'valentine')
local activeObject = nextObject
clientHandlers.onClientResourceStop('feather-weapons')
check('resource stop removes the model', alive[activeObject] == false and not CosmeticsPreview.Active())


-- 6. Grip sets, held-render issues, unconditional removal, preview rebuild.
local db = CosmeticsCatalog.Catalog('WEAPON_SHOTGUN_DOUBLEBARREL', {})
check('double-barrel exotic grip pairs with exotic forend',
    db.pairs.COMPONENT_SHOTGUN_DOUBLEBARREL_GRIP_EXOTIC
    and db.pairs.COMPONENT_SHOTGUN_DOUBLEBARREL_GRIP_EXOTIC.MAG == 'COMPONENT_SHOTGUN_DOUBLEBARREL_MAG_EXOTIC')
check('standard grip pairs with plain forend',
    db.pairs.COMPONENT_SHOTGUN_DOUBLEBARREL_GRIP.MAG == 'COMPONENT_SHOTGUN_DOUBLEBARREL_MAG')
check('pump grip pairs with clip', CosmeticsCatalog.Catalog('WEAPON_SHOTGUN_PUMP', {})
    .pairs.COMPONENT_SHOTGUN_PUMP_GRIP_IRONWOOD.CLIP == 'COMPONENT_SHOTGUN_PUMP_CLIP_IRONWOOD')
check('sawed-off grip pairs with stock', CosmeticsCatalog.Catalog('WEAPON_SHOTGUN_SAWEDOFF', {})
    .pairs.COMPONENT_SHOTGUN_SAWEDOFF_GRIP_EBONY.STOCK == 'COMPONENT_SHOTGUN_SAWEDOFF_STOCK_EBONY')
local m1899 = CosmeticsCatalog.Catalog('WEAPON_PISTOL_M1899', {})
check('plain clips are never paired', m1899.pairedItems.CLIP == nil)
local byDefault = CosmeticsCatalog.Catalog('WEAPON_SNIPERRIFLE_ROLLINGBLOCK', {})
check('issue 4026 categories shown by default', Config.Cosmetics.HeldRenderIssues.show == true
    and byDefault.categories.GRIP_MATERIAL ~= nil and byDefault.categories.GRIPSTOCK_TINT ~= nil
    and byDefault.categories.WRAP_MATERIAL ~= nil)
check('workaround off by default: nothing flagged for the in-hand fix', next(byDefault.heldFix) == nil)
Config.Cosmetics.HeldRenderIssues.workaround = true -- the remaining sections exercise the experimental path
local rolling = CosmeticsCatalog.Catalog('WEAPON_SNIPERRIFLE_ROLLINGBLOCK', {})
check('issue 4026 categories offered with the workaround', rolling.categories.GRIPSTOCK_TINT ~= nil
    and rolling.categories.GRIP_MATERIAL ~= nil and rolling.categories.WRAP_MATERIAL ~= nil)
check('issue 4026 categories flagged for the entity fix', rolling.heldFix.GRIP_MATERIAL == true
    and rolling.heldFix.WRAP_MATERIAL == true and rolling.heldFix.WRAP_TINT == nil)
check('working long-gun categories still offered', rolling.categories.WRAP_TINT ~= nil
    and rolling.categories.BARREL_ENGRAVING ~= nil)
check('scope still rebuilt on the preview model', rolling.structural.SCOPE ~= nil)
Config.Cosmetics.HeldRenderIssues.show = false
local hidden = CosmeticsCatalog.Catalog('WEAPON_SNIPERRIFLE_ROLLINGBLOCK', {})
check('show = false hides them', hidden.categories.GRIP_MATERIAL == nil
    and hidden.structural.GRIP_MATERIAL ~= nil and next(hidden.heldFix) == nil)
Config.Cosmetics.HeldRenderIssues.show = true
check('revolvers keep their tint categories', CosmeticsCatalog.Catalog('WEAPON_REVOLVER_CATTLEMAN', cattleReserved)
    .categories.GRIPSTOCK_TINT ~= nil)

local removed, given, pedHas, modelHas, carried = {}, {}, {}, {}, false
Citizen.InvokeNative = function(hash, a, b, c)
    if hash == 0x9888652B8BA77F73 then nextObject = nextObject + 1; alive[nextObject] = true; return nextObject end
    if hash == 0xFF07CF465F48B830 then return 1 end
    if hash == 0x8DECB02F88F428BC then return carried and 1 or 0 end -- player carries the weapon?
    if hash == 0xBBC67A6F965C688A then return pedHas[b] and 1 or 0 end -- ped reports only these
    if hash == 0x3B390A939AF0B5FC then return (carried and b == 0) and 4000 or 0 end -- model in hand
    if hash == 0x76A18844E743BF91 then return (a == 4000 and modelHas[b]) and 1 or 0 end
    if hash == 0x19F70C4D80494FF8 then removed[#removed + 1] = { 'ped', b } end
    if hash == 0xF7D82B0D66777611 then removed[#removed + 1] = { a, b } end
    if hash == 0x74C9090FDD1BB48E then given[#given + 1] = { a, b } end
    return 0
end
local function Did(list, target, name)
    for _, call in ipairs(list) do if call[1] == target and call[2] == name then return true end end
    return false
end

local dbEntry = { itemInstanceId = 77, slot = 'shoulder', nativeWeaponName = 'WEAPON_SHOTGUN_DOUBLEBARREL', hash = 9,
    catalog = db, functional = {}, cosmetics = { GRIP = 'COMPONENT_SHOTGUN_DOUBLEBARREL_GRIP_EXOTIC' }, probes = {} }
WeaponCosmetics.ApplyToObject(dbEntry, 1000) -- alive[1000] is nil -> DoesEntityExist true
check('exotic grip given', Did(given, 1000, 'COMPONENT_SHOTGUN_DOUBLEBARREL_GRIP_EXOTIC'))
check('exotic forend given with it', Did(given, 1000, 'COMPONENT_SHOTGUN_DOUBLEBARREL_MAG_EXOTIC'))
check('standard grip removed even though nothing reported it', Did(removed, 1000, 'COMPONENT_SHOTGUN_DOUBLEBARREL_GRIP'))
check('plain forend removed', Did(removed, 1000, 'COMPONENT_SHOTGUN_DOUBLEBARREL_MAG'))

removed, given = {}, {}
dbEntry.cosmetics = {}
WeaponCosmetics.ApplyToObject(dbEntry, 1001)
check('standard grip brings plain forend back', Did(given, 1001, 'COMPONENT_SHOTGUN_DOUBLEBARREL_MAG')
    and Did(given, 1001, 'COMPONENT_SHOTGUN_DOUBLEBARREL_GRIP'))

-- Carried weapon: the preview copies exactly what that weapon has.
carried = true
removed, given = {}, {}
pedHas = { COMPONENT_RIFLE_SCOPE02 = true }
local rbEntry = { itemInstanceId = 78, slot = 'back', nativeWeaponName = 'WEAPON_SNIPERRIFLE_ROLLINGBLOCK', hash = 10,
    catalog = rolling, functional = {}, cosmetics = {}, probes = {} }
WeaponCosmetics.ApplyToObject(rbEntry, 1002)
check('preview keeps the scope the weapon has', Did(given, 1002, 'COMPONENT_RIFLE_SCOPE02'))
check('preview removes the other scopes', Did(removed, 1002, 'COMPONENT_RIFLE_SCOPE03')
    and Did(removed, 1002, 'COMPONENT_RIFLE_SCOPE04') and not Did(given, 1002, 'COMPONENT_RIFLE_SCOPE03'))
check('preview removes sights the weapon lacks', Did(removed, 1002, 'COMPONENT_RIFLE_ROLLINGBLOCK_SIGHT_WIDE')
    and not Did(given, 1002, 'COMPONENT_RIFLE_ROLLINGBLOCK_SIGHT_WIDE'))

-- The screenshot case: the ped records the Pearl tint but RedM dropped it from
-- the model in hand (#4026). The preview must not show it either.
local pearlTint = 'COMPONENT_LONGARM_GRIPSTOCK_TINT_PEARL'
GetCurrentPedWeapon = function(_, _, attachPoint)
    if attachPoint == 0 then return true, 10 end
    return false, 0
end
removed, given = {}, {}
pedHas = { COMPONENT_RIFLE_SCOPE02 = true, [pearlTint] = true }
modelHas = { COMPONENT_RIFLE_SCOPE02 = true }
rbEntry.cosmetics = { GRIPSTOCK_TINT = pearlTint }
WeaponCosmetics.ApplyToObject(rbEntry, 1003)
check('preview copies what the weapon in hand shows', Did(given, 1003, 'COMPONENT_RIFLE_SCOPE02'))
check('a part missing from the weapon in hand is not shown on the preview',
    not Did(given, 1003, pearlTint) and Did(removed, 1003, pearlTint))
carried = false
GetCurrentPedWeapon = function() return true, 0 end


-- 7. Held-weapon entity workaround for citizenfx/fivem#4026.
local burled = 'COMPONENT_LONGARM_GRIP_MATERIAL_BURLED'
CreateThread = function(fn) fn() end
CosmeticsCall = function()
    return { ok = true, value = { nativeWeapons = { 'WEAPON_SNIPERRIFLE_ROLLINGBLOCK' }, slots = { {
        slot = 'back', itemInstanceId = 90, serialNumber = 'S90', label = 'Rolling Block',
        nativeWeaponName = 'WEAPON_SNIPERRIFLE_ROLLINGBLOCK', reserved = {}, functional = {},
        cosmetics = { GRIP_MATERIAL = burled } } } } }
end
local entityGives, entityRemoves = {}, {}
crashNative = false
local heldModel, clock = 2000, 0
function GetGameTimer() return clock end
Citizen.InvokeNative = function(hash, a, b)
    if hash == 0x3B390A939AF0B5FC then return b == 9 and heldModel or 0 end -- weapon model at attach point
    if hash == 0x76A18844E743BF91 then return 0 end -- model never reports the part (the bug)
    if hash == 0x1A47699E8D533E8F then crashNative = true end -- crashes RedM b1491: must never be called
    if hash == 0x74C9090FDD1BB48E and a == heldModel then entityGives[#entityGives + 1] = a .. ':' .. b end
    if hash == 0xF7D82B0D66777611 and a == heldModel then entityRemoves[#entityRemoves + 1] = b end
    return 0
end
function GetCurrentPedWeapon(_, _, attachPoint)
    if attachPoint == 9 then return true, 'WEAPON_SNIPERRIFLE_ROLLINGBLOCK' end
    return false, 0
end
local realPrint, warnings = print, {}
print = function(line) if tostring(line):find('held fix', 1, true) then warnings[#warnings + 1] = line end end
WeaponCosmetics.RefreshNow()
WeaponCosmetics.FixHeldWeapons()
check('part put on the carried weapon model', entityGives[1] == '2000:' .. burled)
check('crashing object native never called', crashNative == false)
for _ = 1, 20 do WeaponCosmetics.FixHeldWeapons() end
check('one try per model, no retry loop on the same model', #entityGives == 1)

-- A normal redraw much later: new model, gets one try.
clock, heldModel = 10000, 2001
WeaponCosmetics.FixHeldWeapons()
check('a later draw gets its own try', #entityGives == 2)

-- The try makes RedM rebuild the weapon at once: new model each pass.
clock, heldModel = 10250, 2002
WeaponCosmetics.FixHeldWeapons()
clock, heldModel = 10500, 2003
WeaponCosmetics.FixHeldWeapons()
clock, heldModel = 10750, 2004
WeaponCosmetics.FixHeldWeapons()
check('rebuild loop detected and stopped', #entityGives == 3, #entityGives)
check('giving up is logged once', #warnings == 1)
clock, heldModel = 60000, 2005
WeaponCosmetics.FixHeldWeapons()
check('stays stopped for that weapon and choice', #entityGives == 3)
print = realPrint

local held = WeaponCosmetics.Find(90)
WeaponCosmetics.SetPreview(held, 'GRIP_MATERIAL', nil)
entityGives, entityRemoves = {}, {}
WeaponCosmetics.FixHeldWeapons()
local function Count(list, name) local n = 0; for _, v in ipairs(list) do if v == name then n = n + 1 end end; return n end
check('clearing the choice removes it from the model', Count(entityRemoves, burled) == 1 and #entityGives == 0)
GetGameTimer = function() return 0 end

-- 8. No loop: a ped weapon that already has the saved look is left untouched.
-- A fresh copy of the reconciler runs on a small coroutine scheduler so its
-- threads (apply worker, watcher, held-weapon fix) really run.
local threads = {}
CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
Wait = function() coroutine.yield() end
local function Pump(times)
    for _ = 1, times or 10 do
        for i = #threads, 1, -1 do
            local co = threads[i]
            if coroutine.status(co) == 'dead' then table.remove(threads, i)
            else local ok, problem = coroutine.resume(co); if not ok then error(problem) end end
        end
    end
end
local function Run(fn) CreateThread(fn); Pump() end
local wrap3 = 'COMPONENT_RIFLE_ROLLINGBLOCK_WRAP3'
CosmeticsCall = function()
    return { ok = true, value = { nativeWeapons = { 'WEAPON_SNIPERRIFLE_ROLLINGBLOCK' }, slots = { {
        slot = 'back', itemInstanceId = 90, serialNumber = 'S90', label = 'Rolling Block',
        nativeWeaponName = 'WEAPON_SNIPERRIFLE_ROLLINGBLOCK', reserved = {}, functional = {},
        cosmetics = { WRAP = wrap3 } } } } }
end
local pedCalls = {}
local pedParts = { COMPONENT_SNIPERRIFLE_ROLLINGBLOCK_GRIP = true, [wrap3] = true }
Citizen.InvokeNative = function(hash, a, b)
    if hash == 0x8DECB02F88F428BC then return 1 end -- player carries the weapon
    if hash == 0xBBC67A6F965C688A then return pedParts[b] and 1 or 0 end
    if hash == 0x19F70C4D80494FF8 then pedCalls[#pedCalls + 1] = 'remove ' .. tostring(b) end
    if hash == 0x74C9090FDD1BB48E and a == 1 then pedCalls[#pedCalls + 1] = 'give ' .. tostring(b) end
    return 0
end
dofile(ROOT .. 'client/cosmetics/apply.lua')
Run(function() WeaponCosmetics.RefreshNow() end)
check('correct look: reload touches nothing on the ped weapon', #pedCalls == 0, table.concat(pedCalls, ', '))
Run(function() WeaponCosmetics.RefreshNow() end)
Pump(30) -- watcher and worker keep running: still nothing to do
check('repeated reloads and watcher passes stay idle', #pedCalls == 0, table.concat(pedCalls, ', '))
pedParts[wrap3] = nil
Run(function() WeaponCosmetics.RefreshNow() end)
check('missing part: only that part is given back', #pedCalls == 1 and pedCalls[1] == 'give ' .. wrap3,
    table.concat(pedCalls, ', '))
pedParts[wrap3] = true


-- 9. Held weapon: the ped still reports a part that the model in hand lost
-- (Feather rebuilt it). The part is given again, and only until it shows.
local wrapTint = 'COMPONENT_LONGARM_WRAP_TINT_BLACK'
CosmeticsCall = function()
    return { ok = true, value = { nativeWeapons = { 'WEAPON_SNIPERRIFLE_ROLLINGBLOCK' }, slots = { {
        slot = 'back', itemInstanceId = 91, serialNumber = 'S91', label = 'Rolling Block',
        nativeWeaponName = 'WEAPON_SNIPERRIFLE_ROLLINGBLOCK', reserved = {}, functional = {},
        cosmetics = { WRAP_TINT = wrapTint } } } } }
end
local inHand, modelParts = 3000, {}
pedParts = { COMPONENT_SNIPERRIFLE_ROLLINGBLOCK_GRIP = true, [wrapTint] = true } -- ped record says it is there
pedCalls = {}
Citizen.InvokeNative = function(hash, a, b)
    if hash == 0x8DECB02F88F428BC then return 1 end
    if hash == 0xBBC67A6F965C688A then return pedParts[b] and 1 or 0 end
    if hash == 0x3B390A939AF0B5FC then return b == 0 and inHand or 0 end -- visible model in hand
    if hash == 0x76A18844E743BF91 then return (a == inHand and modelParts[b]) and 1 or 0 end
    if hash == 0x19F70C4D80494FF8 then pedCalls[#pedCalls + 1] = 'remove ' .. tostring(b) end
    if hash == 0x74C9090FDD1BB48E and a == 1 then
        pedCalls[#pedCalls + 1] = 'give ' .. tostring(b)
        modelParts[b] = true -- giving through the ped puts it on the visible model
    end
    return 0
end
function GetCurrentPedWeapon(_, _, attachPoint)
    if attachPoint == 0 then return true, 'WEAPON_SNIPERRIFLE_ROLLINGBLOCK' end
    return false, 0
end
modelParts = { COMPONENT_SNIPERRIFLE_ROLLINGBLOCK_GRIP = true } -- held model lost the wrap tint
Run(function() WeaponCosmetics.RefreshNow() end)
check('held model missing a part: it is given even though the ped reports it',
    #pedCalls == 1 and pedCalls[1] == 'give ' .. wrapTint, table.concat(pedCalls, ', '))
pedCalls = {}
Run(function() WeaponCosmetics.RefreshNow() end)
Pump(30)
check('once it shows on the held model, nothing more is done', #pedCalls == 0, table.concat(pedCalls, ', '))


-- 10. The model check reports every sight material as present (seen in game);
-- the ped does not have them, so nothing is removed.
modelParts = setmetatable({ [wrapTint] = true }, { __index = function() return true end })
pedCalls = {}
Run(function() WeaponCosmetics.RefreshNow() end)
check('model claiming parts the ped lacks causes no removals', #pedCalls == 0, table.concat(pedCalls, ', '))


-- 11. The log case: the ped reports every sight material as present once any is
-- on. Nothing is removed; the choice is given once per weapon model.
local sight7 = 'COMPONENT_LONGARM_SIGHT_MATERIAL_7'
CosmeticsCall = function()
    return { ok = true, value = { nativeWeapons = { 'WEAPON_SNIPERRIFLE_ROLLINGBLOCK' }, slots = { {
        slot = 'back', itemInstanceId = 92, serialNumber = 'S92', label = 'Rolling Block',
        nativeWeaponName = 'WEAPON_SNIPERRIFLE_ROLLINGBLOCK', reserved = {}, functional = {},
        cosmetics = { SIGHT_MATERIAL = sight7 } } } } }
end
local function SightLie(name) return tostring(name):find('SIGHT_MATERIAL', 1, true) ~= nil end
pedParts = setmetatable({ COMPONENT_SNIPERRIFLE_ROLLINGBLOCK_GRIP = true }, { __index = function(_, k) return SightLie(k) end })
modelParts = setmetatable({ COMPONENT_SNIPERRIFLE_ROLLINGBLOCK_GRIP = true }, { __index = function(_, k) return SightLie(k) end })
inHand, pedCalls = 5000, {}
local function Gives(name) local n = 0; for _, c in ipairs(pedCalls) do if c == 'give ' .. name then n = n + 1 end end; return n end
local function Removes() local n = 0; for _, c in ipairs(pedCalls) do if c:sub(1, 7) == 'remove ' then n = n + 1 end end; return n end
Run(function() WeaponCosmetics.RefreshNow() end)
check('lying category: nothing removed', Removes() == 0, table.concat(pedCalls, ', '))
check('lying category: choice given once', Gives(sight7) == 1, table.concat(pedCalls, ', '))
pedCalls = {}
Run(function() WeaponCosmetics.RefreshNow() end)
check('same model: choice not given again', #pedCalls == 0, table.concat(pedCalls, ', '))
inHand, pedCalls = 5001, {}
Run(function() WeaponCosmetics.RefreshNow() end)
check('rebuilt model: choice given again once', Gives(sight7) == 1 and Removes() == 0, table.concat(pedCalls, ', '))


-- 12. Wrap material Cloth (#4026: never sticks) under a wrap tint (check lies).
-- The material is not re-given every pass, so it stops wiping the tint; when it
-- is given, the tint after it is given again in the same pass.
local cloth, tint = 'COMPONENT_LONGARM_WRAP_MATERIAL_CLOTH', 'COMPONENT_LONGARM_WRAP_TINT_B_6'
CosmeticsCall = function()
    return { ok = true, value = { nativeWeapons = { 'WEAPON_SNIPERRIFLE_ROLLINGBLOCK' }, slots = { {
        slot = 'back', itemInstanceId = 93, serialNumber = 'S93', label = 'Rolling Block',
        nativeWeaponName = 'WEAPON_SNIPERRIFLE_ROLLINGBLOCK', reserved = {}, functional = {},
        cosmetics = { WRAP_MATERIAL = cloth, WRAP_TINT = tint } } } } }
end
local function TintLie(name) return tostring(name):find('WRAP_TINT', 1, true) ~= nil end
pedParts = setmetatable({ COMPONENT_SNIPERRIFLE_ROLLINGBLOCK_GRIP = true }, { __index = function(_, k) return TintLie(k) end })
modelParts = setmetatable({ COMPONENT_SNIPERRIFLE_ROLLINGBLOCK_GRIP = true }, { __index = function(_, k) return TintLie(k) end })
inHand, pedCalls = 6000, {}
Run(function() WeaponCosmetics.RefreshNow() end)
local function Index(name) for i, c in ipairs(pedCalls) do if c == 'give ' .. name then return i end end end
check('first pass: material then tint given', Index(cloth) and Index(tint) and Index(cloth) < Index(tint),
    table.concat(pedCalls, ', '))
pedCalls = {}
Run(function() WeaponCosmetics.RefreshNow() end)
Pump(30)
check('next passes: the never-sticking material is not re-given, tint left alone', #pedCalls == 0,
    table.concat(pedCalls, ', '))

print(('RESULT passes=%d failures=%d'):format(passes, failures))
