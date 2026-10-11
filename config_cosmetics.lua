Config = Config or {}
-- Weapon cosmetics: gunsmith benches where players customize the look of the
-- weapons they have equipped. Choices are saved in the weapon item metadata
-- (metadata.cosmetics).
Config.Cosmetics = {}


-- Gunsmith benches where players customize the weapons they have equipped.
-- Barrels and sights are installed through Feather Weapons' own menu, which only
-- opens near a station in Config.Attachments.stations. Keep these
-- coordinates on those benches so both menus work from the same place.
Config.Cosmetics.Stations = {
    valentine = {
        -- Translation key from translations/*.lua.
        label = 'station_valentine',
        coords = vector3(-277.455, 779.197, 119.504),
        blip = true,
        -- Fixed spot for the preview model on the bench top (from /cosmeticsplace).
        -- Without it the model goes on the bench in front of the player.
        preview = { coords = vector3(-276.347, 779.010, 119.634), heading = 86.5 }
    }
}

-- The weapon being customized is shown as a model with its own camera. The
-- controls match feather-character's creator: camera view, zoom (in the scene
-- view zooming in moves onto the weapon), rotate left/right and up/down, plus
-- moving the camera left/right/up/down.
-- DevMode only: /cosmeticsplace spawns a weapon model where the preview goes
-- and opens a small menu to move it; "Print to F8" writes the `preview = {...}`
-- line to paste into the station above.
Config.Cosmetics.PlacementCommand = 'cosmeticsplace'

-- Keyboard shortcuts while the gunsmith menu is open: the number keys 1-9.
-- Zoom is the slider only. Values are key names as the browser reports them
-- ('1', or a letter such as 'a'); the arrow keys are taken by the menu. Set
-- one to false to drop it.
Config.Cosmetics.PreviewKeys = {
    moveLeft = '1', moveRight = '2',
    moveUp = '3', moveDown = '4',
    rotateLeft = '5', rotateRight = '6',
    tiltUp = '7', tiltDown = '8',
    reset = '9',
    zoomOut = false, zoomIn = false
}

Config.Cosmetics.Preview = {
    -- Where the model goes when the station has no preview spot: `distance`
    -- meters in front of the player, on top of the bench there (`surfaceClearance`
    -- meters above it). With no bench it floats `height` meters above the
    -- player's position. When the front is blocked the first open side is used
    -- instead: right, left, then back.
    distance = 0.6,
    height = 0.25,
    surfaceClearance = 0.12,
    -- Height of the character's framing point (chest) for the camera.
    characterHeight = 0.25,
    -- Turn the character to face the weapon while previewing (turned back after).
    facePlayer = true,
    minDistance = 0.6,
    -- Model rotation; z = 90 shows the weapon side-on to the player.
    rotation = { x = 0.0, y = 0.0, z = 90.0 },
    keyRotateStep = 5.0, -- degrees per tick while a rotate/tilt key is held
    keyZoomStep = 5,     -- zoom per tick while a zoom key is held
    moveStep = 0.05,   -- meters per tick while a move key is held (weapon or camera)
    moveLimit = 0.5,   -- furthest the weapon (or camera) can be moved from its spot
    -- Zoom moves the camera closer to or farther from the model. The slider runs
    -- 0-100 (larger is closer): 0 puts the camera `far` meters away, 100 `near`.
    zoom = { near = 0.2, far = 1.4, step = 1 },
    -- The camera looks at the weapon from behind the character, this many
    -- degrees off the character-weapon line so it sees over their shoulder.
    shoulderAngle = 25.0,
    -- Character & Weapon view: the camera stands in front of the character,
    -- beyond the weapon and this many degrees to one side, facing them.
    sceneAngle = 35.0,
    -- Opens on the character's own view (first person, the character is not in
    -- the shot); zooming in moves from their eyes toward the weapon.
    defaultView = 'eyes',
    -- Camera framings: starting distance, height above the focus point, and the
    -- lens field of view (fixed per view). `scene` frames the character and the
    -- weapon together and has its own zoom range (near/far); the others frame
    -- the weapon alone and use the zoom range above.
    views = {
        -- First person: `faceGap` meters in front of the character's head, down
        -- to `near` meters from the weapon at full zoom. The camera cannot go
        -- further back than the head, so a wider `fov` (field of view, degrees)
        -- is what fits a long weapon in the shot.
        eyes = { focus = 'eyes', faceGap = 0.2, near = 0.25, fov = 55.0 },
        -- Character & Weapon: the character holding their weapon (the floating
        -- model is hidden); zoom moves in on the character.
        scene = { focus = 'scene', distance = 2.4, near = 1.2, far = 3.5, height = 0.4, fov = 45.0 },
        full = { distance = 0.75, height = 0.05, fov = 40.0 },
        close = { distance = 0.45, height = 0.02, fov = 30.0 },
        top = { distance = 0.6, height = 0.9, fov = 50.0 }
    },
    viewOrder = { 'eyes', 'scene', 'full', 'close', 'top' },
    -- Lights drawn while previewing so parts are easy to see, even indoors.
    -- Neutral white keeps grip, wrap and material colors true.
    light = {
        enabled = true,
        color = { r = 255, g = 255, b = 255 },
        -- Lights the side the camera is looking at.
        key = { range = 2.5, intensity = 6.0 },
        -- Fills shadows from above the model (height in meters).
        top = { height = 0.8, range = 3.0, intensity = 4.0 },
        -- Inside a building (e.g. the gunsmith shop on a sunny day) the key and
        -- top lights are multiplied by this, and the room light is added above
        -- the character to light the room around them.
        interiorBoost = 3.0,
        room = { height = 2.0, range = 6.0, intensity = 6.0 }
    }
}

-- Space between stacked buttons in the gunsmith menu: 'small', 'medium',
-- 'large', or false for none.
Config.Cosmetics.MenuSpacing = 'small'

-- Where the gunsmith and placement menus open: the CENTER of the menu, as a
-- CSS length of the screen (%, vw, vh, px or rem). The menu is rebuilt on every
-- open, which clears a dragged position, so it always opens here.
Config.Cosmetics.MenuPosition = { x = '84%', y = '47%' }

Config.Cosmetics.Interaction = {
    -- Distance at which the open prompt is shown.
    distance = 2.0,
    -- Extra distance the server accepts when saving, to absorb position lag.
    serverTolerance = 3.0,
    promptKey = 0xCEFD9220, -- E
    holdMode = 'SHORT_TIMED_EVENT',
    blipSprite = 'blip_shop_gunsmith'
}


-- Weapon attach points checked for the visible weapon model: hands (0, 1),
-- pistol holsters (2, 3) and long-gun slots (9, 10).
Config.Cosmetics.WeaponAttachPoints = { 0, 1, 2, 3, 9, 10 }

-- Categories that change how a weapon performs. Feather Weapons owns these, so
-- Cosmetics never offers, applies or saves them. Any category that contains a
-- component from the Feather attachment catalog is excluded automatically as well.
Config.Cosmetics.FunctionalCategories = {
    BARREL = true,
    BARREL_RIFLING = true,
    SIGHT = true,
    SCOPE = true,
    CLIP = true,
    MAG = true,
    TUBE = true,
    STOCK = true
}

-- Wood grip sets: choosing a grip also applies the matching piece in these
-- categories (double-barrel/Elephant forend MAG, pump/Varmint CLIP, sawed-off
-- STOCK). Only categories with matching variants are touched.
Config.Cosmetics.PairedCategories = {
    GRIP = { 'MAG', 'CLIP', 'STOCK' }
}

-- Categories RedM renders on a weapon model but not on a weapon a player holds
-- (RedM bug: https://github.com/citizenfx/fivem/issues/4026).
-- show = true: offer them. They show on the preview model, but on RedM b1491
--   they may not show on the weapon in the player's hands.
-- show = false: hide them, so a saved look never vanishes when drawn.
-- workaround = true: also try to put them straight onto the player's weapon
--   models. On RedM b1491 this does NOT work (RedM rebuilds the weapon and drops
--   the part; the guard stops it after 2 rebuilds and logs it). Only for testing
--   a newer RedM build.
Config.Cosmetics.HeldRenderIssues = {
    show = true,
    workaround = false,
    -- Hand (0, 1) and carried long-gun (9, 10) weapon attach points.
    attachPoints = { 0, 1, 9, 10 },
    -- How often the weapon entities are checked.
    intervalMs = 250,
    -- One try per weapon model. If the model is replaced within rebuildWindowMs
    -- of a try, the try made RedM rebuild the weapon; after maxRebuilds of those
    -- the fix gives up for that weapon (logged) instead of looping.
    rebuildWindowMs = 1500,
    maxRebuilds = 2,
    groups = {
        LONGARM = {
            GRIPSTOCK_TINT = true,
            GRIP_MATERIAL = true,
            WRAP_MATERIAL = true
        }
    },
    -- The parts above are still given to the weapon in hand (they work on some
    -- guns; the bug was seen on the Rolling Block) and reported in yellow.
    -- Categories listed here (keyed by shared group) are never given in hand,
    -- only shown on the preview; the menu marks them with * and the console
    -- reports them in red.
    --   * WRAP_MATERIAL: given to the held weapon it resets the wrap tint.
    --   * GRIPSTOCK_TINT: never shows on a held long gun (Carcano, Rolling Block).
    skipInHand = {
        LONGARM = {
            WRAP_MATERIAL = true,
            GRIPSTOCK_TINT = true
        }
    }
}

-- Single options RedM shows on a weapon model but not on a weapon in the
-- player's hands, keyed by shared group, as Lua patterns on the component name.
-- They stay selectable; the menu marks them with * and explains, and the
-- console reports them as preview only.
--
-- Found in game (Rolling Block, Carcano): the wood grips (Standard, Ironwood,
-- Engraved, Burled) never change on the held rifle; Reaper does.
-- Remove a pattern if a newer RedM build fixes it.
Config.Cosmetics.PreviewOnlyComponents = {
    LONGARM = {
        '_GRIP$',
        '_GRIP_IRONWOOD$',
        '_GRIP_ENGRAVED$',
        '_GRIP_BURLED$'
    }
}

-- Categories whose "Standard" item is put back when the player clears their choice.
Config.Cosmetics.StandardCategories = {
    GRIP = true
}


-- Apply order. FRAME_VERTDATA can rebuild the weapon model, so it goes first;
-- grip visuals go last because frame and wrap components can overwrite them.
-- Each part follows femga's documented example order: material, then
-- engraving, then engraving material (a later material paints over an earlier
-- engraving material). Categories not listed are applied after these, A-Z.
Config.Cosmetics.CategoryOrder = {
    FRAME_VERTDATA = 5,
    BARREL_MATERIAL = 10,
    BARREL_ENGRAVING = 11,
    BARREL_ENGRAVING_MATERIAL = 12,
    BARREL_TINT = 15,
    CYLINDER_MATERIAL = 20,
    CYLINDER_ENGRAVING = 21,
    CYLINDER_ENGRAVING_MATERIAL = 22,
    CYLINDER_TINT = 23,
    SIGHT_MATERIAL = 25,
    FRAME_MATERIAL = 30,
    FRAME_ENGRAVING = 31,
    FRAME_ENGRAVING_MATERIAL = 32,
    HAMMER_MATERIAL = 34,
    TRIGGER_MATERIAL = 35,
    TRIGGER_TINT = 36,
    GRIP = 40,
    GRIP_TINT = 44,
    WRAP = 50,
    WRAP_MATERIAL = 60,
    WRAP_TINT = 70,
    STRAP = 80,
    STRAP_TINT = 90,
    MELEE_BLADE_MATERIAL = 180,
    MELEE_BLADE_ENGRAVING = 190,
    MELEE_BLADE_ENGRAVING_MATERIAL = 200,
    GRIP_MATERIAL = 1980,
    GRIPSTOCK_ENGRAVING = 1990,
    GRIPSTOCK_TINT = 2000
}

-- Categories never offered for a weapon, keyed by native weapon name.
-- Shared groups (SHORTARM, LONGARM, ...) list parts for every gun in the group,
-- but a gun only really has some of them. A category for a part the gun does
-- not have lands on another part instead and fights it. Hide it here.
-- Saved looks that contain a hidden category are cleaned up automatically.
--
-- Found in game:
--   * Rolling Block: no cylinder. CYLINDER_* draws over the barrel engraving,
--     the cylinder material does nothing, and the barrel engraving material
--     stops applying after a cylinder part was used.
--   * Carcano, Rolling Block: strap tints change nothing on the strap.
Config.Cosmetics.HiddenCategories = {
    WEAPON_SNIPERRIFLE_CARCANO = {
        STRAP_TINT = true
    },
    WEAPON_SNIPERRIFLE_ROLLINGBLOCK = {
        CYLINDER_MATERIAL = true,
        CYLINDER_ENGRAVING = true,
        CYLINDER_ENGRAVING_MATERIAL = true,
        STRAP_TINT = true
    }
}

-- Only these options are offered in a category, keyed by native weapon name.
-- For shared categories where the gun can show just some of the options; the
-- rest are left out (and cleared from the weapon after a resource restart).
--
-- Found in game:
--   * Carcano, Rolling Block: of the four straps only the Repeater Cloth Strap
--     shows; the others never appear.
Config.Cosmetics.AllowedComponents = {
    WEAPON_SNIPERRIFLE_CARCANO = {
        STRAP = { 'COMPONENT_REPEATER_CLOTH_STRAP01' }
    },
    WEAPON_SNIPERRIFLE_ROLLINGBLOCK = {
        STRAP = { 'COMPONENT_REPEATER_CLOTH_STRAP01' }
    }
}

-- Options never offered, keyed by native weapon name (ALL = every weapon), as
-- Lua patterns on the component name. For options that do not work at all;
-- they are left out of the menu and dropped from saved looks. They are not
-- removed from the weapon: on the Exotic weapon variants the Exotic Grip is
-- the gun's own grip.
--
-- Found in game:
--   * Every weapon: the Exotic Grip shows neither on the preview nor in hand.
Config.Cosmetics.DisabledComponents = {
    ALL = {
        '_GRIP_EXOTIC$'
    }
}

-- Categories RedM cannot check on a weapon (it reports several parts at once),
-- but which were confirmed in game to show both in hand and on the preview
-- model. The DevMode console reports them as confirmed instead of unchecked;
-- they are still applied the careful way.
Config.Cosmetics.ConfirmedCategories = {
    WRAP_TINT = true
}

-- Categories RedM shows on the weapon in the player's hands but not on the
-- preview model at the bench (the opposite of Config.Cosmetics.HeldRenderIssues).
-- The menu marks them with ** and explains.
--
-- Found in game (Carcano, Rolling Block): the strap never shows on the preview.
Config.Cosmetics.HandOnlyCategories = {
    STRAP = true,
    STRAP_TINT = true
}

-- Categories that cannot be combined on a weapon, keyed by native weapon name.
-- Some guns have a single engraving layer: whichever engraving is applied last
-- spreads over the others. Choosing one category of a group clears the others
-- (and their engraving materials). Saved looks keep only the first of a group.
--
-- Found in game:
--   * Rolling Block: the frame engraving draws over the barrel engraving (and
--     the cylinder engraving did too, before cylinder parts were hidden).
Config.Cosmetics.ExclusiveCategories = {
    WEAPON_SNIPERRIFLE_ROLLINGBLOCK = {
        { 'BARREL_ENGRAVING', 'FRAME_ENGRAVING' }
    }
}

-- Rules the apply step follows (for reference; not settings):
--   * FRAME_VERTDATA (frame style, e.g. Reaper Engraving) breaks the colors of
--     other parts (femga). While one is chosen, *_MATERIAL and *_TINT parts are
--     not applied and the console reports them as blocked.
--   * Order: material, then engraving, then engraving material (femga's example),
--     see Config.Cosmetics.CategoryOrder.
--   * Parts in Config.Cosmetics.HeldRenderIssues.groups (RedM bug #4026) are given in hand
--     but may not show there; those in skipInHand only show on the preview.
--   * Console colors (DevMode): green applied, yellow given but RedM cannot
--     confirm it (or may not show it in hand), red not applied / blocked /
--     preview only. Yellow usually means fine: on the Carcano the hammer,
--     trigger and sight materials report yellow and show correctly in hand.

-- A material category only renders when its engraving is chosen.
Config.Cosmetics.ComponentDependencies = {
    BARREL_ENGRAVING_MATERIAL = 'BARREL_ENGRAVING',
    CYLINDER_ENGRAVING_MATERIAL = 'CYLINDER_ENGRAVING',
    FRAME_ENGRAVING_MATERIAL = 'FRAME_ENGRAVING',
    MELEE_BLADE_ENGRAVING_MATERIAL = 'MELEE_BLADE_ENGRAVING'
}

-- Menu pages. Categories not listed here appear under "Other". Page and
-- category names come from translations/*.lua (group_<KEY>, category_<NAME>).
Config.Cosmetics.CategoryGroups = {
    { key = 'BARREL', categories = { 'BARREL_MATERIAL', 'BARREL_TINT', 'BARREL_ENGRAVING', 'BARREL_ENGRAVING_MATERIAL' } },
    { key = 'CYLINDER', categories = { 'CYLINDER_MATERIAL', 'CYLINDER_TINT', 'CYLINDER_ENGRAVING', 'CYLINDER_ENGRAVING_MATERIAL' } },
    { key = 'GRIP', categories = { 'GRIP', 'GRIP_MATERIAL', 'GRIP_TINT', 'GRIPSTOCK_ENGRAVING', 'GRIPSTOCK_TINT' } },
    { key = 'FRAME', categories = { 'FRAME_VERTDATA', 'FRAME_MATERIAL', 'FRAME_ENGRAVING', 'FRAME_ENGRAVING_MATERIAL' } },
    { key = 'METAL', categories = { 'HAMMER_MATERIAL', 'TRIGGER_MATERIAL', 'TRIGGER_TINT', 'SIGHT_MATERIAL' } },
    { key = 'WRAP', categories = { 'WRAP', 'WRAP_MATERIAL', 'WRAP_TINT' } },
    { key = 'STRAP', categories = { 'STRAP', 'STRAP_TINT' } },
    { key = 'BLADE', categories = { 'MELEE_BLADE_MATERIAL', 'MELEE_BLADE_ENGRAVING', 'MELEE_BLADE_ENGRAVING_MATERIAL' } }
}
