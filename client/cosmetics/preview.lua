-- Preview of the weapon being customized: a local weapon model floating beside
-- the player, with a camera that frames the character and the weapon together
-- (or the weapon alone in the close views). The menu drives it with the same
-- controls as feather-character's creator (camera view, rotate) plus zoom and
-- camera moves.
CosmeticsPreview = {}

local state -- { itemInstanceId, object, hash, camera, anchor, playerPoint, sceneDir, toCamera, heading, tilt, view, fov, zoom, panRight, panUp, ped, pedHeading, previousWeapon }
local rotationTicket = 0
-- Bumped by every Start and Stop. A Start that finishes loading after the
-- preview was stopped (menu closed while the asset loaded) sees a newer
-- generation and removes its own model.
local generation = 0
local spawned = {} -- every model this resource created and has not deleted yet

local ASSET_TIMEOUT_MS = 5000

-- Both natives are underscore natives on this build, so they are called by hash.
-- The result is read as an integer: a plain call returns 0/1, and 0 is truthy in Lua.
local function WeaponAssetLoaded(hash)
    return Citizen.InvokeNative(0xFF07CF465F48B830, hash, Citizen.ResultAsInteger()) ~= 0 -- _HasWeaponAssetLoaded
end

local function LoadWeaponAsset(hash)
    if WeaponAssetLoaded(hash) then return true end
    Citizen.InvokeNative(0x72D4CB5DB927009C, hash, 31, false) -- _RequestWeaponAsset
    local deadline = GetGameTimer() + ASSET_TIMEOUT_MS
    while not WeaponAssetLoaded(hash) and GetGameTimer() < deadline do Wait(0) end
    return WeaponAssetLoaded(hash)
end

local function DeletePreviewObject(object)
    if not object then return end
    spawned[object] = nil
    if not DoesEntityExist(object) then return end
    -- A script object must be owned by the script before DeleteEntity reliably removes it.
    SetEntityAsMissionEntity(object, true, true)
    DeleteEntity(object)
end

-- Returns the object, or nil plus the step that failed.
local function CreatePreviewObject(hash, coords)
    if not LoadWeaponAsset(hash) then return nil, 'weapon asset did not load' end
    local deadline = GetGameTimer() + ASSET_TIMEOUT_MS
    repeat
        local object = Citizen.InvokeNative(0x9888652B8BA77F73, hash, 0, coords.x + 0.0, coords.y + 0.0,
            coords.z + 0.0, true, 1.0, Citizen.ResultAsInteger()) -- _CreateWeaponObject
        if object and object ~= 0 and object ~= -1 and DoesEntityExist(object) then
            spawned[object] = true
            return object
        end
        Wait(100)
    until GetGameTimer() >= deadline
    return nil, 'weapon object was not created'
end

local function SetHeading(object, heading)
    local rotation = Config.Cosmetics.Preview.rotation or {}
    SetEntityRotation(object, rotation.x or 0.0, rotation.y or 0.0, heading % 360.0, 2, true)
end

local function View()
    return Config.Cosmetics.Preview.views[state.view] or Config.Cosmetics.Preview.views[Config.Cosmetics.Preview.defaultView]
end

-- How far from `from` toward `to` is free of world geometry and objects, and
-- whether anything was hit at all.
local function FreeDistance(from, to, ignore)
    local handle = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z,
        17, ignore or 0, 4) -- map + objects
    local _, hit, endCoords = GetShapeTestResult(handle)
    local full = #(to - from)
    if (hit == true or hit == 1) and endCoords then return math.min(full, #(endCoords - from)), true end
    return full, false
end

-- Zoom is 0-100 (larger is closer) over the view's far..near meters; views
-- without their own range use Config.Cosmetics.Preview.zoom.
local function ZoomRange(view)
    local settings = Config.Cosmetics.Preview.zoom
    return view.far or settings.far, view.near or settings.near
end

local function DistanceFor(view, zoom)
    local far, near = ZoomRange(view)
    return far - (far - near) * (zoom / 100.0)
end

local function ZoomFor(view, distance)
    local far, near = ZoomRange(view)
    local zoom = (far - distance) / (far - near) * 100.0
    return math.floor(math.max(0.0, math.min(100.0, zoom)) + 0.5)
end

local function Unit(x, y)
    local length = math.sqrt(x * x + y * y)
    if length < 0.0001 then return { x = 0.0, y = 1.0 } end
    return { x = x / length, y = y / length }
end

-- Places the camera facing the scene (character and weapon) or the weapon,
-- shifted by the moves and kept short of any wall behind it.
-- Where the character's eyes are, from the head bone (a fixed point above the
-- ped when the bone cannot be read).
local function EyePosition(ped)
    local bone = GetEntityBoneIndexByName(ped, 'SKEL_Head')
    if bone and bone ~= -1 then
        local head = GetWorldPositionOfEntityBone(ped, bone)
        if head and (head.x ~= 0.0 or head.y ~= 0.0 or head.z ~= 0.0) then return head end
    end
    return GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.0, 0.65)
end

-- First-person view: the camera sits just in front of the character's eyes and
-- looks at the weapon; zooming in moves it along that line toward the weapon.
local function UpdateEyesCamera(view)
    local anchor, eyes = state.anchor, state.eyes
    local line = eyes - anchor
    local length = #line
    local far = math.max(0.3, length - (view.faceGap or 0.2))
    local near = math.min(view.near or 0.25, far)
    local distance = far - (far - near) * (state.zoom / 100.0)
    local dir = Unit(line.x, line.y)
    local rightX, rightY = -dir.y, dir.x
    local offset = vector3(rightX * state.panRight, rightY * state.panRight, state.panUp)
    state.cameraCoords = anchor + line * (distance / length) + offset
    state.focus = anchor + offset
    SetCamCoord(state.camera, state.cameraCoords.x, state.cameraCoords.y, state.cameraCoords.z)
    if state.panRight == 0.0 and state.panUp == 0.0 and not state.modelMoved then
        PointCamAtEntity(state.camera, state.object, 0.0, 0.0, 0.0, true)
    else
        PointCamAtCoord(state.camera, state.focus.x, state.focus.y, state.focus.z)
    end
    SetCamFov(state.camera, state.fov)
end

-- Starting zoom of a view: the eyes view starts at the eyes.
local function StartZoom(view)
    if view.focus == 'eyes' then return 0 end
    return ZoomFor(view, view.distance)
end

-- Character & Weapon shows the character holding their weapon: the floating
-- model is hidden and the character stops looking at it. Every other view
-- shows the model, with the character's head and eyes following it.
local function ApplyViewPresentation()
    if not state or not state.object or not DoesEntityExist(state.object) then return end
    local scene = View().focus == 'scene'
    SetEntityVisible(state.object, not scene)
    if scene and state.lookingAtModel then
        TaskClearLookAt(state.ped)
        state.lookingAtModel = false
    elseif not scene and not state.lookingAtModel then
        TaskLookAtEntity(state.ped, state.object, -1, 2048, 3, 0)
        state.lookingAtModel = true
    end
end

local function UpdateCamera()
    if not state or not state.camera then return end
    local view = View()
    if view.focus == 'eyes' then return UpdateEyesCamera(view) end
    local dir = view.focus == 'scene' and state.sceneDir or state.toCamera
    local rightX, rightY = -dir.y, dir.x
    -- Character & Weapon frames the character holding their weapon (the
    -- floating model is hidden there); the other views frame the model.
    local center = view.focus == 'scene' and state.playerPoint or state.anchor
    local focus = vector3(center.x + rightX * state.panRight, center.y + rightY * state.panRight,
        center.z + state.panUp)
    state.focus = focus
    local zoomDistance = DistanceFor(view, state.zoom)
    local wanted = vector3(focus.x + dir.x * zoomDistance, focus.y + dir.y * zoomDistance, focus.z + view.height)
    local distance = zoomDistance
    local free, blocked = FreeDistance(focus, wanted, state.object)
    if blocked then
        -- Stop 8 cm short of whatever is behind the camera.
        distance = math.max(0.15, zoomDistance * (free / #(wanted - focus)) - 0.08)
    end
    state.cameraCoords = vector3(focus.x + dir.x * distance, focus.y + dir.y * distance, focus.z + view.height)
    SetCamCoord(state.camera, state.cameraCoords.x, state.cameraCoords.y, state.cameraCoords.z)
    if view.focus ~= 'scene' and state.panRight == 0.0 and state.panUp == 0.0 and not state.modelMoved then
        -- Centred on the weapon: lock onto the model itself.
        PointCamAtEntity(state.camera, state.object, 0.0, 0.0, 0.0, true)
    else
        PointCamAtCoord(state.camera, focus.x, focus.y, focus.z)
    end
    SetCamFov(state.camera, state.fov)
end

-- A bench or table top under `point`: probes straight down and returns the spot
-- just above the surface, or nil when only the floor is there.
local function OnSurface(point, ped)
    local from = vector3(point.x, point.y, point.z + 0.3)
    local to = vector3(point.x, point.y, point.z - 1.2)
    local handle = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 17, ped, 4)
    local _, hit, endCoords = GetShapeTestResult(handle)
    if not ((hit == true or hit == 1) and endCoords) then return nil end
    local pedZ = GetEntityCoords(ped).z
    -- The ped's position is about hip height: a floor is far below it.
    if endCoords.z < pedZ - 0.5 then return nil end
    return vector3(point.x, point.y, endCoords.z + (Config.Cosmetics.Preview.surfaceClearance or 0.12))
end

-- Picks where the model goes: the station's fixed spot, or in front of the
-- player on the bench there (floating when there is none), else beside them in
-- the first open direction (right, left, back), never inside the bench.
local function Anchor(stationId)
    local ped = PlayerPedId()
    local station = Config.Cosmetics.Stations[stationId]
    local spot = station and station.preview
    local origin = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.0, Config.Cosmetics.Preview.height)
    if spot and spot.coords then return spot.coords end

    local wanted, minimum, margin = Config.Cosmetics.Preview.distance, Config.Cosmetics.Preview.minDistance or 0.6, 0.3
    for _, offset in ipairs({ { 0.0, 1.0 }, { 1.0, 0.0 }, { -1.0, 0.0 }, { 0.0, -1.0 } }) do
        local target = GetOffsetFromEntityInWorldCoords(ped, offset[1] * wanted, offset[2] * wanted, Config.Cosmetics.Preview.height)
        local free, blocked = FreeDistance(origin, target, ped)
        local distance = blocked and math.min(wanted, free - margin) or wanted
        if distance >= minimum then
            local step = target - origin
            local point = origin + step * (distance / #step)
            -- On the bench in front of the player when there is one.
            return OnSurface(point, ped) or point
        end
    end
    CosmeticsDebug('preview: no open space around the player; using the minimum distance to the right')
    return GetOffsetFromEntityInWorldCoords(ped, minimum, 0.0, Config.Cosmetics.Preview.height)
end

-- The camera looks at the weapon from behind the character, turned
-- Config.Cosmetics.Preview.shoulderAngle degrees off the character-weapon line
-- so it sees past them, over the shoulder. The other shoulder is used when a
-- wall is closer on the first side.
local function CameraDirection(playerPoint, anchor, object)
    local toPlayer = Unit(playerPoint.x - anchor.x, playerPoint.y - anchor.y)
    local reach = (Config.Cosmetics.Preview.views.scene or {}).distance or 2.4
    local best, bestFree
    for _, sign in ipairs({ 1.0, -1.0 }) do
        local angle = math.rad((Config.Cosmetics.Preview.shoulderAngle or 25.0) * sign)
        local c, s = math.cos(angle), math.sin(angle)
        local dir = Unit(toPlayer.x * c - toPlayer.y * s, toPlayer.x * s + toPlayer.y * c)
        local free = FreeDistance(anchor, vector3(anchor.x + dir.x * reach, anchor.y + dir.y * reach, anchor.z), object)
        if free >= reach then return dir end
        if not bestFree or free > bestFree then best, bestFree = dir, free end
    end
    return best
end

-- Character & Weapon view: the camera stands in front of the character, beyond
-- the weapon and Config.Cosmetics.Preview.sceneAngle degrees to one side, so it
-- sees their face with the weapon between them. Each side is tried, then the
-- straight sides; with walls everywhere, the over-the-shoulder direction.
local function SceneDirection(playerPoint, anchor, center, object, fallback)
    local along = Unit(anchor.x - playerPoint.x, anchor.y - playerPoint.y)
    local reach = (Config.Cosmetics.Preview.views.scene or {}).distance or 2.4
    local sceneAngle = Config.Cosmetics.Preview.sceneAngle or 35.0
    for _, degrees in ipairs({ sceneAngle, -sceneAngle, 90.0, -90.0 }) do
        local angle = math.rad(degrees)
        local c, s = math.cos(angle), math.sin(angle)
        local dir = Unit(along.x * c - along.y * s, along.x * s + along.y * c)
        local free = FreeDistance(center, vector3(center.x + dir.x * reach, center.y + dir.y * reach, center.z), object)
        if free >= reach then return dir end
    end
    return fallback
end

-- Game heading of a direction: 0 faces north (+y), 90 faces west (-x). Same as
-- GET_HEADING_FROM_VECTOR_2D, without depending on its Lua name.
local function HeadingOf(dir)
    return math.deg(math.atan(-dir.x, dir.y)) % 360.0
end

local function DrawLight(coords, color, range, intensity)
    Citizen.InvokeNative(0xD2D9E04C0DF927F4, coords.x + 0.0, coords.y + 0.0, coords.z + 0.0,
        color.r, color.g, color.b, range + 0.0, intensity + 0.0) -- DrawLightWithRange
end

-- Lights must be drawn every frame; the loop ends with the preview.
local function StartLights(previewState)
    local light = Config.Cosmetics.Preview.light
    if not light or light.enabled == false then return end
    CreateThread(function()
        local indoors, checkAt = false, 0
        while state == previewState do
            local color = light.color or { r = 255, g = 255, b = 255 }
            local focus = state.focus or state.anchor
            -- Inside a building the game exposes for the bright windows on a sunny
            -- day, so the room looks dark: lights are boosted and a room light is
            -- added there. Checked twice a second.
            if GetGameTimer() >= checkAt then
                checkAt = GetGameTimer() + 500
                indoors = (GetInteriorFromEntity(state.ped) or 0) ~= 0
            end
            local boost = indoors and (light.interiorBoost or 1.0) or 1.0
            if light.key and state.cameraCoords then
                -- Reaches from the camera to whatever it frames, the character included.
                local reach = light.key.range + #(state.cameraCoords - focus)
                DrawLight(state.cameraCoords, color, reach, light.key.intensity * boost)
            end
            if light.top then
                local above = vector3(focus.x, focus.y, focus.z + light.top.height)
                DrawLight(above, color, light.top.range, light.top.intensity * boost)
            end
            if indoors and light.room then
                local room = GetOffsetFromEntityInWorldCoords(state.ped, 0.0, 0.0, light.room.height)
                DrawLight(room, color, light.room.range, light.room.intensity)
            end
            Wait(0)
        end
    end)
end

local function CurrentWeapon(ped)
    local present, current = GetCurrentPedWeapon(ped, true, 0, false)
    if present ~= true and present ~= 1 then return nil end
    return current
end

-- Puts `weaponHash` in the character's hands (a plain hold, no animation task).
local function HoldWeapon(ped, weaponHash)
    if weaponHash and CurrentWeapon(ped) ~= weaponHash then
        SetCurrentPedWeapon(ped, weaponHash, true, 0, false, false)
    end
end

-- Shows `entry` at the station, held by the character. Must run in a thread.
function CosmeticsPreview.Start(entry, stationId)
    -- Switching weapons in the menu keeps what the character held before the
    -- menu, so it is what they get back at the end.
    local previousWeapon = state and state.previousWeapon or CurrentWeapon(PlayerPedId())
    CosmeticsPreview.Stop(true)
    generation = generation + 1
    local ticket = generation
    local anchor = Anchor(stationId)
    local object, failure = CreatePreviewObject(entry.hash, anchor)
    if ticket ~= generation then
        -- Stopped (menu closed, another weapon chosen) while the model loaded.
        if object then DeletePreviewObject(object) end
        return false
    end
    if not object then
        print(('[feather-weapons cosmetics] preview failed for %s (hash %s) at %.2f %.2f %.2f: %s'):format(
            tostring(entry.nativeWeaponName), tostring(entry.hash), anchor.x, anchor.y, anchor.z, failure))
        return false
    end
    local ped = PlayerPedId()
    local playerPoint = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.0, Config.Cosmetics.Preview.characterHeight or 0.25)
    local toCamera = CameraDirection(playerPoint, anchor, object)
    CosmeticsDebug(('preview %s at %.2f %.2f %.2f, camera dir %.2f %.2f'):format(
        entry.nativeWeaponName, anchor.x, anchor.y, anchor.z, toCamera.x, toCamera.y))
    -- Shown side-on to the camera (Config.Cosmetics.Preview.rotation.z = 90),
    -- unless the station's preview spot sets its own heading.
    local station = Config.Cosmetics.Stations[stationId]
    local spot = station and station.preview
    local heading = (spot and tonumber(spot.heading)) or HeadingOf(toCamera)
    SetEntityCollision(object, false, false)
    SetEntityCoords(object, anchor.x, anchor.y, anchor.z, false, false, false, false)
    SetHeading(object, heading)
    FreezeEntityPosition(object, true)

    -- The character turns to face the weapon and is turned back when the
    -- preview ends.
    local pedHeading = GetEntityHeading(ped)
    if Config.Cosmetics.Preview.facePlayer ~= false then
        SetEntityHeading(ped, HeadingOf(Unit(anchor.x - playerPoint.x, anchor.y - playerPoint.y)))
    end

    local view = Config.Cosmetics.Preview.views[Config.Cosmetics.Preview.defaultView]
    state = {
        itemInstanceId = entry.itemInstanceId, object = object, hash = entry.hash,
        anchor = anchor, toCamera = toCamera, heading = heading,
        sceneDir = SceneDirection(playerPoint, anchor, playerPoint, object, toCamera), baseHeading = heading, tilt = 0.0,
        playerPoint = playerPoint,
        view = Config.Cosmetics.Preview.defaultView, fov = view.fov, zoom = StartZoom(view),
        panRight = 0.0, panUp = 0.0, ped = ped, pedHeading = pedHeading, previousWeapon = previousWeapon,
        eyes = EyePosition(ped)
    }
    HoldWeapon(ped, entry.hash)
    state.camera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    UpdateCamera()
    SetCamActive(state.camera, true)
    RenderScriptCams(true, true, 400, true, false, 0)
    SetFocusEntity(object)
    ApplyViewPresentation()
    StartLights(state)

    WeaponCosmetics.ApplyToObject(entry, object)
    return true
end

-- `keepWeapon`: the next preview follows straight away, so the character keeps
-- holding a weapon instead of putting this one away first.
function CosmeticsPreview.Stop(keepWeapon)
    rotationTicket = rotationTicket + 1
    generation = generation + 1
    if not state then return end
    if state.camera and DoesCamExist(state.camera) then
        RenderScriptCams(false, true, 250, true, false, 0)
        DestroyCam(state.camera, false)
    end
    ClearFocus()
    if state.ped and DoesEntityExist(state.ped) then TaskClearLookAt(state.ped) end
    DeletePreviewObject(state.object)
    if Config.Cosmetics.Preview.facePlayer ~= false and state.ped and DoesEntityExist(state.ped) then
        SetEntityHeading(state.ped, state.pedHeading)
    end
    if not keepWeapon and state.ped and DoesEntityExist(state.ped) then
        HoldWeapon(state.ped, state.previousWeapon or joaat('WEAPON_UNARMED'))
    end
    state = nil
end

function CosmeticsPreview.Active()
    return state ~= nil
end

-- Re-applies the entry's current selection to the model after any change.
function CosmeticsPreview.Refresh()
    if not state then return end
    local entry = WeaponCosmetics.Find(state.itemInstanceId)
    if entry then WeaponCosmetics.ApplyToObject(entry, state.object) end
end

function CosmeticsPreview.ViewKey()
    return state and state.view or Config.Cosmetics.Preview.defaultView
end

-- Current zoom, 0-100 (larger is closer).
function CosmeticsPreview.Zoom()
    local view = Config.Cosmetics.Preview.views[Config.Cosmetics.Preview.defaultView]
    return state and state.zoom or StartZoom(view)
end

-- A view sets its own lens and starting zoom, and recenters the camera.
function CosmeticsPreview.SetView(viewKey)
    if not state or not Config.Cosmetics.Preview.views[viewKey] then return end
    local view = Config.Cosmetics.Preview.views[viewKey]
    state.view = viewKey
    state.fov = view.fov
    state.zoom = StartZoom(view)
    state.panRight, state.panUp = 0.0, 0.0
    ApplyViewPresentation()
    UpdateCamera()
end

function CosmeticsPreview.SetZoom(zoom)
    if not state then return end
    state.zoom = math.max(0, math.min(100, math.floor((tonumber(zoom) or state.zoom) + 0.5)))
    UpdateCamera()
end

function CosmeticsPreview.ZoomBy(delta)
    if not state then return end
    CosmeticsPreview.SetZoom(state.zoom + (tonumber(delta) or 0))
end

-- Moves the camera left/right (x) and up/down (z), within Config.Cosmetics.Preview.moveLimit.
function CosmeticsPreview.Move(stepsRight, stepsUp)
    if not state then return end
    local step, limit = Config.Cosmetics.Preview.moveStep, Config.Cosmetics.Preview.moveLimit
    state.panRight = math.max(-limit, math.min(limit, state.panRight + stepsRight * step))
    state.panUp = math.max(-limit, math.min(limit, state.panUp + stepsUp * step))
    UpdateCamera()
end

local function Quaternion(ax, ay, az, degrees)
    local half = math.rad(degrees) / 2
    local sin = math.sin(half)
    return { x = ax * sin, y = ay * sin, z = az * sin, w = math.cos(half) }
end

local function Multiply(a, b)
    return {
        w = a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z,
        x = a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
        y = a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
        z = a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w
    }
end

-- Turns the model: `heading` around the vertical, then `tilt` around the level
-- axis across the camera's view, so tilting shows the top or the bottom of the
-- weapon whichever way it is turned.
local function Orient(object, heading, tilt)
    if not DoesEntityExist(object) then return end
    local rotation = Config.Cosmetics.Preview.rotation or {}
    local base = Multiply(Quaternion(0, 0, 1, heading % 360.0),
        Multiply(Quaternion(1, 0, 0, rotation.x or 0.0), Quaternion(0, 1, 0, rotation.y or 0.0)))
    local dir = state.toCamera
    local q = Multiply(Quaternion(-dir.y, dir.x, 0, tilt), base)
    SetEntityQuaternion(object, q.x, q.y, q.z, q.w)
end

-- Turns the model left/right (`degrees`) and up/down (`tiltDegrees`), eased
-- like feather-character's creator rotation.
local function Turn(degrees, tiltDegrees)
    if not state then return end
    rotationTicket = rotationTicket + 1
    local ticket, object = rotationTicket, state.object
    local startHeading, startTilt = state.heading, state.tilt
    local deltaHeading, deltaTilt = tonumber(degrees) or 0.0, tonumber(tiltDegrees) or 0.0
    state.heading = (startHeading + deltaHeading) % 360.0
    state.tilt = (startTilt + deltaTilt) % 360.0
    local duration = 450
    CreateThread(function()
        local started = GetGameTimer()
        while ticket == rotationTicket and state and DoesEntityExist(object) do
            local progress = math.min(1.0, (GetGameTimer() - started) / duration)
            local eased = progress * progress * (3.0 - (2.0 * progress))
            Orient(object, startHeading + deltaHeading * eased, startTilt + deltaTilt * eased)
            if progress >= 1.0 then break end
            Wait(0)
        end
    end)
end

-- Left/right: turns the weapon around the vertical.
function CosmeticsPreview.Rotate(degrees)
    Turn(degrees, 0.0)
end

-- Up/down: tips the weapon toward or away from the camera.
function CosmeticsPreview.Tilt(degrees)
    Turn(0.0, degrees)
end

-- Recenters the camera and turns the weapon back to its starting side-on pose.
-- Moves the model left/right (as seen by the camera) and up/down, within
-- Config.Cosmetics.Preview.moveLimit of its spot. The camera keeps its place
-- and aim, so the weapon visibly moves. Preview only: nothing is saved.
function CosmeticsPreview.MoveModel(stepsRight, stepsUp)
    if not state or not state.object or not state.cameraCoords or not state.focus then return end
    local step, limit = Config.Cosmetics.Preview.moveStep, Config.Cosmetics.Preview.moveLimit
    local forward = Unit(state.focus.x - state.cameraCoords.x, state.focus.y - state.cameraCoords.y)
    local offset = state.modelOffset or { x = 0.0, y = 0.0, z = 0.0 }
    local x = offset.x + forward.y * stepsRight * step
    local y = offset.y - forward.x * stepsRight * step
    local z = math.max(-limit, math.min(limit, offset.z + stepsUp * step))
    local across = math.sqrt(x * x + y * y)
    if across > limit then x, y = x * limit / across, y * limit / across end
    state.modelOffset = { x = x, y = y, z = z }
    state.modelMoved = math.abs(x) + math.abs(y) + math.abs(z) > 1e-6
    SetEntityCoords(state.object, state.anchor.x + x, state.anchor.y + y, state.anchor.z + z, false, false, false, false)
    -- The camera keeps its place; it aims at the spot (the weapon then moves
    -- in view), or locks back onto the model once it is back on its spot.
    UpdateCamera()
end

function CosmeticsPreview.Reset()
    if not state then return end
    rotationTicket = rotationTicket + 1
    state.heading, state.tilt = state.baseHeading, 0.0
    if state.modelMoved then
        state.modelOffset, state.modelMoved = nil, false
        SetEntityCoords(state.object, state.anchor.x, state.anchor.y, state.anchor.z, false, false, false, false)
    end
    Orient(state.object, state.heading, state.tilt)
    CosmeticsPreview.SetView(state.view)
end

-- Helpers for the placement tool (client/cosmetics/placement.lua). Models it
-- spawns are tracked like preview models, so a restart removes them too.
CosmeticsPreview.SpawnModel = CreatePreviewObject -- (hash, coords) -> object | nil, failure
CosmeticsPreview.DeleteModel = DeletePreviewObject
CosmeticsPreview.SetModelHeading = SetHeading
CosmeticsPreview.DefaultSpot = Anchor -- (stationId) -> coords
function CosmeticsPreview.SurfaceBelow(point)
    return OnSurface(point, PlayerPedId())
end

-- On a restart the camera is handed back and every model this resource created
-- is removed, including one that was still loading.
AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    CosmeticsPreview.Stop()
    for object in pairs(spawned) do DeletePreviewObject(object) end
end)
