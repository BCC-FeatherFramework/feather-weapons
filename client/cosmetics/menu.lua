-- Gunsmith menu: pick an equipped weapon, preview cosmetic parts on it, save.
-- Barrels and sights hand off to Feather Weapons' own menu.
local Menu = CosmeticsProviders.Menu

local menuId
local isOpen = false
local currentStation, stationLabel
local tracked = {} -- [itemInstanceId string][category] = { pageId, elementId, indexOf }
local previewControls = { views = {}, zooms = {} } -- camera elements on every page, kept in sync

function CosmeticsMenuOpen()
    return isOpen
end

local function Value(result)
    if type(result) ~= 'table' or result.ok ~= true then
        error(('feather-menu-v2: %s'):format(type(result) == 'table' and tostring(result.message) or 'invalid response'))
    end
    return result.value
end

local function NewPage(key)
    return { id = Value(Menu:CreatePage(menuId, { key = key })).pageId, count = 0 }
end

-- Stacked buttons get a spacer between them (Config.Cosmetics.MenuSpacing). Buttons on
-- the same row already have the menu's row gap.
local function SpaceBefore(page, kind, spec)
    local slot = spec.slot or 'content'
    page.last = page.last or {}
    local previous = page.last[slot]
    page.last[slot] = { kind = kind, row = spec.row }
    if not Config.Cosmetics.MenuSpacing or kind ~= 'button' or not previous or previous.kind ~= 'button' then return end
    if spec.row and spec.row == previous.row then return end
    page.count = page.count + 1
    Value(Menu:AddElement(menuId, page.id, 'spacer', {
        key = ('spacer-%d'):format(page.count), size = Config.Cosmetics.MenuSpacing, slot = slot
    }))
end

local function Add(page, kind, spec, callback)
    SpaceBefore(page, kind, spec)
    page.count = page.count + 1
    spec.key = ('%s-%d'):format(kind, page.count)
    return Value(Menu:AddElement(menuId, page.id, kind, spec, callback)).elementId
end

local function Go(page)
    Value(Menu:NavigateToPage(menuId, page.id))
end

local function InThread(callback)
    return function(data)
        CreateThread(function()
            local called, problem = pcall(callback, data)
            if not called then print(('[feather-weapons cosmetics] menu action failed: %s'):format(tostring(problem))) end
        end)
    end
end

local function Close()
    if menuId then pcall(function() Menu:CloseMenu(menuId) end) end
end

-- Puts each tracked arrows element back in line with the entry's selection.
local function SyncElements(entry, categories)
    local elements = tracked[tostring(entry.itemInstanceId)] or {}
    local selection = entry.preview or entry.cosmetics
    for category, element in pairs(elements) do
        if not categories or categories[category] then
            pcall(function()
                Menu:SetElementValue(menuId, element.pageId, element.elementId, element.indexOf(selection[category]))
            end)
        end
    end
end

local function Find(itemInstanceId)
    local entry = WeaponCosmetics.Find(itemInstanceId)
    if not entry then CosmeticsNotify(CosmeticsT('error_not_equipped')) end
    return entry
end

-- Category names come from translations; an untranslated one shows as-is.
local function CategoryLabel(category)
    local key = 'category_' .. category
    local label = CosmeticsT(key)
    return label ~= key and label or category
end

local function SyncPreviewControls()
    local view, zoom = CosmeticsPreview.ViewKey(), CosmeticsPreview.Zoom()
    for _, element in ipairs(previewControls.views) do
        pcall(function() Menu:SetElementValue(menuId, element.pageId, element.elementId, view) end)
    end
    for _, element in ipairs(previewControls.zooms) do
        pcall(function() Menu:SetElementValue(menuId, element.pageId, element.elementId, zoom) end)
    end
end

-- `[5] ← Left` for each configured key (Config.Cosmetics.PreviewKeys), joined
-- with ` · `; actions without a key are left out.
local function KeyText(pairs)
    local parts = {}
    for _, pair in ipairs(pairs) do
        local key = (Config.Cosmetics.PreviewKeys or {})[pair[1]]
        if type(key) == 'string' and key ~= '' then
            parts[#parts + 1] = ('[%s] %s'):format(key:upper(), CosmeticsT(pair[2]))
        end
    end
    return table.concat(parts, '  ·  ')
end

-- Footer camera controls: the camera view and zoom slider, then the keyboard
-- shortcuts as text (rotate, tilt, zoom, camera moves and reset are keys only).
local function AddPreviewControls(page)
    local viewOptions = {}
    for _, key in ipairs(Config.Cosmetics.Preview.viewOrder) do
        viewOptions[#viewOptions + 1] = { value = key, label = CosmeticsT('view_' .. key) }
    end
    previewControls.views[#previewControls.views + 1] = { pageId = page.id, elementId = Add(page, 'dropdown', {
        label = CosmeticsT('preview_view'), value = CosmeticsPreview.ViewKey(), options = viewOptions, slot = 'footer'
    }, function(event)
        if type(event) ~= 'table' or event.value == CosmeticsPreview.ViewKey() then return end
        CosmeticsPreview.SetView(event.value)
        SyncPreviewControls()
    end) }

    local zoom = Config.Cosmetics.Preview.zoom
    previewControls.zooms[#previewControls.zooms + 1] = { pageId = page.id, elementId = Add(page, 'slider', {
        label = CosmeticsT('preview_zoom'), value = CosmeticsPreview.Zoom(), min = 0, max = 100, step = zoom.step, slot = 'footer'
    }, function(event)
        local value = type(event) == 'table' and tonumber(event.value) or nil
        if not value or math.abs(value - CosmeticsPreview.Zoom()) < 0.5 then return end
        CosmeticsPreview.SetZoom(value)
        SyncPreviewControls()
    end) }
    local zoomKeys = KeyText({ { 'zoomOut', 'zoom_out' }, { 'zoomIn', 'zoom_in' } })
    if zoomKeys ~= '' then Add(page, 'textdisplay', { value = zoomKeys, slot = 'footer' }) end

    local rotateKeys = KeyText({ { 'rotateLeft', 'rotate_left' }, { 'rotateRight', 'rotate_right' } })
    local tiltKeys = KeyText({ { 'tiltUp', 'rotate_up' }, { 'tiltDown', 'rotate_down' } })
    if rotateKeys ~= '' or tiltKeys ~= '' then
        Add(page, 'subheader', { value = CosmeticsT('preview_rotate'), slot = 'footer' })
        if rotateKeys ~= '' then Add(page, 'textdisplay', { value = rotateKeys, slot = 'footer' }) end
        if tiltKeys ~= '' then Add(page, 'textdisplay', { value = tiltKeys, slot = 'footer' }) end
    end

    local moveKeys = KeyText({ { 'moveLeft', 'move_left' }, { 'moveRight', 'move_right' },
        { 'moveUp', 'move_up' }, { 'moveDown', 'move_down' } })
    if moveKeys ~= '' then
        Add(page, 'subheader', { value = CosmeticsT('preview_move'), slot = 'footer' })
        Add(page, 'textdisplay', { value = moveKeys, slot = 'footer' })
    end

    local resetKey = KeyText({ { 'reset', 'preview_reset' } })
    if resetKey ~= '' then Add(page, 'textdisplay', { value = resetKey, slot = 'footer' }) end
end

-- Keyboard shortcuts for the preview (Config.Cosmetics.PreviewKeys). The menu
-- holds keyboard focus, so feather-menu-v2 passes these keys back as key
-- actions; holding a key repeats it. Both letter cases are registered so Caps
-- Lock or Shift does not matter.
local function RegisterPreviewKeys()
    local settings = Config.Cosmetics.Preview
    local turn, zoom = settings.keyRotateStep or 5.0, settings.keyZoomStep or 5
    local actions = {
        rotateLeft = function() CosmeticsPreview.Rotate(-turn) end,
        rotateRight = function() CosmeticsPreview.Rotate(turn) end,
        tiltUp = function() CosmeticsPreview.Tilt(-turn) end,
        tiltDown = function() CosmeticsPreview.Tilt(turn) end,
        zoomOut = function() CosmeticsPreview.ZoomBy(-zoom); SyncPreviewControls() end,
        zoomIn = function() CosmeticsPreview.ZoomBy(zoom); SyncPreviewControls() end,
        moveLeft = function() CosmeticsPreview.MoveModel(-1, 0) end,
        moveRight = function() CosmeticsPreview.MoveModel(1, 0) end,
        moveUp = function() CosmeticsPreview.MoveModel(0, 1) end,
        moveDown = function() CosmeticsPreview.MoveModel(0, -1) end,
        reset = function() CosmeticsPreview.Reset(); SyncPreviewControls() end
    }
    for action, key in pairs(Config.Cosmetics.PreviewKeys or {}) do
        local callback = actions[action]
        if callback and type(key) == 'string' and key ~= '' then
            for _, variant in ipairs({ key:lower(), key:upper() }) do
                local called, result = pcall(function() return Menu:RegisterKeyAction(menuId, variant, callback) end)
                if not called or type(result) ~= 'table' or result.ok ~= true then
                    CosmeticsDebug(('preview key %s (%s) not registered'):format(variant, action))
                end
            end
        end
    end
end

local function BuildGroupPage(entry, groupKey, categories, parent)
    local itemInstanceId = entry.itemInstanceId
    local page = NewPage(('group:%s:%s'):format(tostring(itemInstanceId), groupKey))
    local label = groupKey == 'OTHER' and CosmeticsT('menu_other') or CosmeticsT('group_' .. groupKey)
    Add(page, 'header', { value = entry.label, slot = 'header' })
    Add(page, 'subheader', { value = label, slot = 'header' })

    -- Parts RedM shows on the weapon model but not on the weapon in hand are
    -- marked with * (Config.Cosmetics.HeldRenderIssues, Config.Cosmetics.PreviewOnlyComponents).
    local catalog = entry.catalog
    local function Marked(componentName) return catalog.previewOnly[componentName] == true end
    local anyMarked = false
    for _, category in ipairs(categories) do
        if catalog.heldBroken[category] then anyMarked = true end
        for _, item in ipairs(catalog.categories[category].items) do
            if Marked(item.name) then anyMarked = true end
        end
    end
    if anyMarked then
        Add(page, 'textdisplay', { value = CosmeticsT('menu_preview_only_note'), slot = 'header' })
    end
    -- Parts RedM shows on the weapon in hand but not on the preview model are
    -- marked with ** (Config.Cosmetics.HandOnlyCategories).
    local anyHandOnly = false
    for _, category in ipairs(categories) do
        if catalog.handOnly[category] then anyHandOnly = true end
    end
    if anyHandOnly then
        Add(page, 'textdisplay', { value = CosmeticsT('menu_hand_only_note'), slot = 'header' })
    end

    local elements = tracked[tostring(itemInstanceId)]
    for _, category in ipairs(categories) do
        local info = entry.catalog.categories[category]
        local options, componentByIndex, indexByComponent = {}, {}, {}
        local defaultLabel = CosmeticsT('option_none')
        for _, item in ipairs(info.items) do
            if item.name == info.default then
                defaultLabel = item.label .. (Marked(item.name) and ' *' or '')
            end
        end
        options[1] = { value = 1, label = defaultLabel }
        for _, item in ipairs(info.items) do
            if item.name ~= info.default then
                local index = #options + 1
                options[index] = { value = index, label = item.label .. (Marked(item.name) and ' *' or '') }
                componentByIndex[index], indexByComponent[item.name] = item.name, index
            end
        end
        local function IndexOf(componentName) return indexByComponent[componentName] or 1 end

        local selection = entry.preview or entry.cosmetics
        local elementId
        elementId = Add(page, 'arrows', {
            label = CategoryLabel(category) .. (catalog.heldBroken[category] and ' *' or '')
                .. (catalog.handOnly[category] and ' **' or ''),
            options = options,
            value = IndexOf(selection[category]),
            slot = 'content'
        }, InThread(function(data)
            local index = tonumber(data and data.value)
            local current = Find(itemInstanceId)
            if not index or not current then return end
            local ok, detail = WeaponCosmetics.SetPreview(current, category, componentByIndex[index])
            if not ok then
                CosmeticsNotify(CosmeticsT('notify_dependency'))
                SyncElements(current, { [category] = true })
            elseif #detail > 0 then
                local cleared = {}
                for _, dependent in ipairs(detail) do cleared[dependent] = true end
                SyncElements(current, cleared)
            end
        end))
        elements[category] = { pageId = page.id, elementId = elementId, indexOf = IndexOf }
    end

    Add(page, 'button', { label = CosmeticsT('menu_back'), slot = 'content' }, function() Go(parent) end)
    AddPreviewControls(page)
    return page
end

local function Save(itemInstanceId)
    local entry = Find(itemInstanceId)
    if not entry then return end
    if not WeaponCosmetics.HasChanges(entry) then
        CosmeticsNotify(CosmeticsT('notify_saved'))
        return
    end
    local result = CosmeticsCall('feather-weapons:cosmetics:save', {
        itemInstanceId = entry.itemInstanceId,
        cosmetics = entry.preview
    })
    if result.ok then
        local current = WeaponCosmetics.Find(itemInstanceId)
        if current then WeaponCosmetics.Commit(current, result.value.cosmetics or {}) end
        CosmeticsNotify(CosmeticsT('notify_saved'))
    else
        CosmeticsNotifyFailure(result)
    end
end

local function BuildWeaponPage(entry, home)
    local itemInstanceId = entry.itemInstanceId
    tracked[tostring(itemInstanceId)] = {}
    local page = NewPage('weapon:' .. tostring(itemInstanceId))
    Add(page, 'header', { value = entry.label, slot = 'header' })
    Add(page, 'subheader', { value = CosmeticsT('slot_' .. entry.slot), slot = 'header' })
    Add(page, 'textdisplay', {
        value = CosmeticsT('menu_serial', tostring(entry.serialNumber or '-')) .. '\n' .. CosmeticsT('menu_hold_hint'),
        slot = 'content'
    })

    local grouped = {}
    for _, group in ipairs(Config.Cosmetics.CategoryGroups or {}) do
        local categories = {}
        for _, category in ipairs(group.categories) do
            if entry.catalog.categories[category] then
                categories[#categories + 1] = category
                grouped[category] = true
            end
        end
        if #categories > 0 then
            -- Built the first time it is opened: building every page up front
            -- froze the game for seconds at open.
            local groupPage
            Add(page, 'button', { label = CosmeticsT('group_' .. group.key), slot = 'content' }, InThread(function()
                groupPage = groupPage or BuildGroupPage(entry, group.key, categories, page)
                Go(groupPage)
            end))
        end
    end
    local others = {}
    for _, category in ipairs(entry.catalog.order) do
        if not grouped[category] then others[#others + 1] = category end
    end
    if #others > 0 then
        local otherPage
        Add(page, 'button', { label = CosmeticsT('menu_other'), slot = 'content' }, InThread(function()
            otherPage = otherPage or BuildGroupPage(entry, 'OTHER', others, page)
            Go(otherPage)
        end))
    end

    Add(page, 'line', { slot = 'content' })
    Add(page, 'button', { label = CosmeticsT('menu_save'), slot = 'content' }, InThread(function() Save(itemInstanceId) end))
    Add(page, 'button', { label = CosmeticsT('menu_discard'), slot = 'content' }, InThread(function()
        local current = Find(itemInstanceId)
        if not current then return end
        WeaponCosmetics.EndPreview(current)
        WeaponCosmetics.BeginPreview(current)
        SyncElements(current)
        CosmeticsNotify(CosmeticsT('notify_discarded'))
    end))
    Add(page, 'button', { label = CosmeticsT('menu_back'), slot = 'content' }, function()
        CosmeticsPreview.Stop()
        Go(home)
    end)
    AddPreviewControls(page)
    return page
end

local function OnClosed()
    isOpen = false
    tracked = {}
    previewControls = { views = {}, zooms = {} }
    CosmeticsPreview.Stop()
    -- Anything not saved goes back to the saved look.
    WeaponCosmetics.EndAllPreviews()
end

local function BuildMenu()
    if menuId then pcall(function() Menu:DestroyMenu(menuId) end) end
    tracked = {}
    previewControls = { views = {}, zooms = {} }
    menuId = Value(Menu:CreateMenu({
        key = 'feather-weapons:cosmetics',
        draggable = true,
        closable = true,
        size = { width = '28rem', maxHeight = '85vh' },
        position = Config.Cosmetics.MenuPosition,
        theme = { preset = 'redemption', accent = '#CC9900' }
    })).menuId
    Value(Menu:RegisterMenuLifecycle(menuId, function(event)
        if type(event) == 'table' and event.event == 'closed' then OnClosed() end
    end))
    RegisterPreviewKeys()

    local home = NewPage('home')
    Add(home, 'header', { value = CosmeticsT('menu_title'), slot = 'header' })
    Add(home, 'subheader', { value = stationLabel or '', slot = 'header' })

    local entries = WeaponCosmetics.Entries()
    if #entries == 0 then
        Add(home, 'textdisplay', { value = CosmeticsT('menu_no_weapons'), slot = 'content' })
    else
        Add(home, 'textdisplay', { value = CosmeticsT('menu_choose_weapon'), slot = 'content' })
        for _, entry in ipairs(entries) do
            local weaponPage -- built the first time this weapon is chosen
            local itemInstanceId = entry.itemInstanceId
            Add(home, 'button', {
                label = ('%s: %s'):format(CosmeticsT('slot_' .. entry.slot), entry.label),
                slot = 'content'
            }, InThread(function()
                local current = WeaponCosmetics.Find(itemInstanceId)
                if not current then return end
                weaponPage = weaponPage or BuildWeaponPage(current, home)
                WeaponCosmetics.BeginPreview(current)
                if not CosmeticsPreview.Start(current, currentStation) then CosmeticsNotify(CosmeticsT('error_preview')) end
                SyncPreviewControls()
                Go(weaponPage)
            end))
        end
    end

    Value(Menu:OpenMenu(menuId, { pageId = home.id }))
end

function OpenCosmeticsMenu(stationId)
    if isOpen then return end
    isOpen = true
    currentStation = stationId
    stationLabel =Config.Cosmetics.Stations[stationId] and CosmeticsT(Config.Cosmetics.Stations[stationId].label) or nil
    CreateThread(function()
        local built, problem = pcall(function()
            Value(Menu:AwaitReady(5000))
            WeaponCosmetics.RefreshNow()
            BuildMenu()
        end)
        if not built then
            isOpen = false
            print(('[feather-weapons cosmetics] unable to open the gunsmith menu: %s'):format(tostring(problem)))
            CosmeticsNotify(CosmeticsT('error_unavailable'))
        end
    end)
end

-- Logging out with the menu open closes it, which also removes the preview.
AddEventHandler('Feather:Character:Logout', function()
    if isOpen then Close() end
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource == 'feather-menu-v2' then
        menuId = nil
        if isOpen then OnClosed() end
    elseif resource == GetCurrentResourceName() and isOpen then
        Close()
    end
end)
