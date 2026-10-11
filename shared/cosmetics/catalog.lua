-- Cosmetic component catalog and validation shared by client and server.
-- A selection is a map { CATEGORY = 'COMPONENT_NAME' } holding only the
-- categories the player changed away from the native look.
CosmeticsCatalog = {}

local MAX_CATEGORIES = 64

local dependentsOf = {}
for dependent, required in pairs(Config.Cosmetics.ComponentDependencies or {}) do
    dependentsOf[required] = dependentsOf[required] or {}
    dependentsOf[required][#dependentsOf[required] + 1] = dependent
end

local catalogCache = {}

local function CacheKey(nativeWeaponName, reserved)
    local names = {}
    for name in pairs(reserved or {}) do names[#names + 1] = name end
    table.sort(names)
    local issues = Config.Cosmetics.HeldRenderIssues or {}
    return nativeWeaponName .. '|' .. table.concat(names, ',') .. '|' .. tostring(issues.show ~= false)
        .. '|' .. tostring(issues.workaround == true)
end

-- Every component category a native weapon exposes: its model-specific
-- categories from WeaponComponentCatalog.models, then the categories of each
-- shared group it belongs to. Returns { CATEGORY = { { name, label }, ... } }.
local function NativeCategories(nativeWeaponName)
    local model = (WeaponComponentCatalog.models or {})[nativeWeaponName]
    local groups = (WeaponComponentCatalog.weaponGroups or {})[nativeWeaponName]
    if not model and not groups then return nil end

    local categories, seen = {}, {}
    local function Append(category, items)
        if type(category) ~= 'string' or type(items) ~= 'table' then return end
        categories[category] = categories[category] or {}
        seen[category] = seen[category] or {}
        for _, item in ipairs(items) do
            local name = type(item) == 'table' and (item.name or item[1]) or item
            if type(name) == 'string' and name ~= '' and not seen[category][name] then
                seen[category][name] = true
                local list = categories[category]
                list[#list + 1] = { name = name, label = type(item) == 'table' and item.label or name }
            end
        end
    end

    for category, entry in pairs(model or {}) do
        Append(category, type(entry) == 'table' and (entry.items or entry) or nil)
    end
    for _, groupName in ipairs(groups or {}) do
        for category, items in pairs((WeaponComponentCatalog.shared or {})[groupName] or {}) do
            Append(category, items)
        end
    end
    return categories
end

-- The item that represents a category's native look, for Config.Cosmetics.StandardCategories.
local function StandardItem(category, items)
    if not (Config.Cosmetics.StandardCategories or {})[category] or #items == 0 then return nil end
    for _, item in ipairs(items) do
        local searchable = (item.name .. ' ' .. tostring(item.label)):lower()
        if searchable:find('standard', 1, true) or searchable:find('default', 1, true) then return item.name end
    end
    return items[1].name
end

-- Builds the cosmetic categories for one native weapon. `reserved` is the set of
-- component names Feather Weapons catalogs for this weapon; a category holding
-- any of them belongs to Feather and is left out, as are Config.Cosmetics.FunctionalCategories.
function CosmeticsCatalog.Catalog(nativeWeaponName, reserved)
    if type(nativeWeaponName) ~= 'string' then return nil end
    nativeWeaponName = nativeWeaponName:upper()
    local key = CacheKey(nativeWeaponName, reserved)
    if catalogCache[key] then return catalogCache[key] end

    local categories = NativeCategories(nativeWeaponName)
    if not categories then return nil end

    -- Categories RedM cannot render on a held weapon for this weapon's groups:
    -- offered unless `show = false`; flagged for the entity workaround when on.
    local issues = Config.Cosmetics.HeldRenderIssues or {}
    local heldBroken = {}
    for _, groupName in ipairs((WeaponComponentCatalog.weaponGroups or {})[nativeWeaponName] or {}) do
        for category in pairs((issues.groups or {})[groupName] or {}) do heldBroken[category] = true end
    end
    local hideBroken = issues.show == false
    -- Categories never given to the held weapon, for this weapon's groups.
    local skipInHand = {}
    for _, groupName in ipairs((WeaponComponentCatalog.weaponGroups or {})[nativeWeaponName] or {}) do
        for category in pairs((issues.skipInHand or {})[groupName] or {}) do
            skipInHand[category] = true
            heldBroken[category] = true
        end
    end

    local catalog = {
        nativeWeaponName = nativeWeaponName, categories = {}, order = {}, componentCategory = {},
        -- Categories not offered here (barrel, sight, scope, forend, ...). The preview
        -- model clears and rebuilds them from the player's real weapon.
        structural = {},
        -- Grip choice -> matching wood pieces in other categories (see Config.Cosmetics.PairedCategories).
        pairs = {}, pairedItems = {},
        -- Offered categories that also need the held-weapon entity workaround.
        heldFix = {},
        -- Offered categories RedM drops from held weapons (citizenfx/fivem#4026).
        heldBroken = {},
        -- Categories hidden for this weapon (Config.Cosmetics.HiddenCategories): never
        -- offered, only cleared from the weapon after a resource restart.
        hidden = {},
        -- Options shown on the weapon model only (Config.Cosmetics.PreviewOnlyComponents).
        previewOnly = {},
        -- Categories shown on the weapon in hand only (Config.Cosmetics.HandOnlyCategories).
        handOnly = {},
        -- Categories never given to the held weapon (HeldRenderIssues.skipInHand).
        skipInHand = skipInHand
    }
    local hidden = (Config.Cosmetics.HiddenCategories or {})[nativeWeaponName] or {}
    local allowed = (Config.Cosmetics.AllowedComponents or {})[nativeWeaponName] or {}
    local disabledPatterns = {}
    for _, key in ipairs({ 'ALL', nativeWeaponName }) do
        for _, pattern in ipairs((Config.Cosmetics.DisabledComponents or {})[key] or {}) do
            disabledPatterns[#disabledPatterns + 1] = pattern
        end
    end
    local function Disabled(name)
        for _, pattern in ipairs(disabledPatterns) do
            if name:find(pattern) then return true end
        end
        return false
    end
    for category, items in pairs(categories) do
        if hidden[category] then
            catalog.hidden[category] = items
            goto continue
        end
        -- Options this weapon cannot show are left out. Those not in
        -- Config.Cosmetics.AllowedComponents are still cleared from the weapon; those in
        -- Config.Cosmetics.DisabledComponents are not (an Exotic variant's own grip).
        do
            local allow
            if allowed[category] then
                allow = {}
                for _, name in ipairs(allowed[category]) do allow[name] = true end
            end
            local kept, dropped = {}, {}
            for _, item in ipairs(items) do
                if not Disabled(item.name) then
                    local list = (not allow or allow[item.name]) and kept or dropped
                    list[#list + 1] = item
                end
            end
            items = kept
            if #dropped > 0 then catalog.hidden[category] = dropped end
        end
        local owned = (Config.Cosmetics.FunctionalCategories or {})[category] == true
        for _, item in ipairs(items) do
            if reserved and reserved[item.name] then owned = true; break end
        end
        if owned or (heldBroken[category] and hideBroken) then
            catalog.structural[category] = items
        elseif #items > 0 then
            if heldBroken[category] then catalog.heldBroken[category] = true end
            if (Config.Cosmetics.HandOnlyCategories or {})[category] then catalog.handOnly[category] = true end
            if heldBroken[category] and issues.workaround == true then catalog.heldFix[category] = true end
            catalog.categories[category] = {
                items = items,
                default = StandardItem(category, items)
            }
            catalog.order[#catalog.order + 1] = category
            for _, item in ipairs(items) do catalog.componentCategory[item.name] = category end
        end
        ::continue::
    end
    -- Options RedM cannot show on a held weapon, for this weapon's shared groups.
    for _, groupName in ipairs((WeaponComponentCatalog.weaponGroups or {})[nativeWeaponName] or {}) do
        for _, pattern in ipairs((Config.Cosmetics.PreviewOnlyComponents or {})[groupName] or {}) do
            for _, info in pairs(catalog.categories) do
                for _, item in ipairs(info.items) do
                    if item.name:find(pattern) then catalog.previewOnly[item.name] = true end
                end
            end
        end
    end

    table.sort(catalog.order, function(a, b)
        local orderA = (Config.Cosmetics.CategoryOrder or {})[a] or 1000
        local orderB = (Config.Cosmetics.CategoryOrder or {})[b] or 1000
        if orderA ~= orderB then return orderA < orderB end
        return a < b
    end)

    -- Wood grip sets: GRIP_IRONWOOD goes with MAG_IRONWOOD (or CLIP_/STOCK_...).
    -- A partner category counts only when it has at least one matching variant,
    -- so plain magazines/clips are never touched.
    for gripCategory, partners in pairs(Config.Cosmetics.PairedCategories or {}) do
        local grips = catalog.categories[gripCategory]
        for _, partner in ipairs(grips and partners or {}) do
            local partnerItems = categories[partner] or {}
            local byName, matched = {}, false
            for _, item in ipairs(partnerItems) do byName[item.name] = true end
            local found = {}
            for _, grip in ipairs(grips.items) do
                local prefix, suffix = grip.name:match('^(.*)_' .. gripCategory .. '(.*)$')
                local candidate = prefix and (prefix .. '_' .. partner .. suffix)
                if candidate and byName[candidate] then
                    found[grip.name] = candidate
                    if suffix ~= '' then matched = true end
                end
            end
            if matched then
                catalog.pairedItems[partner] = partnerItems
                for gripName, partnerName in pairs(found) do
                    catalog.pairs[gripName] = catalog.pairs[gripName] or {}
                    catalog.pairs[gripName][partner] = partnerName
                end
            end
        end
    end

    catalogCache[key] = catalog
    return catalog
end

function CosmeticsCatalog.Dependents(category)
    return dependentsOf[category] or {}
end

-- The other categories that cannot be combined with `category` on this weapon
-- (Config.Cosmetics.ExclusiveCategories).
function CosmeticsCatalog.ExclusiveOthers(nativeWeaponName, category)
    local others = {}
    for _, group in ipairs((Config.Cosmetics.ExclusiveCategories or {})[tostring(nativeWeaponName):upper()] or {}) do
        local inGroup = false
        for _, member in ipairs(group) do
            if member == category then inGroup = true end
        end
        if inGroup then
            for _, member in ipairs(group) do
                if member ~= category then others[#others + 1] = member end
            end
        end
    end
    return others
end

-- Keeps only the first (in apply order) of each exclusive group in a selection,
-- dropping the rest and anything that depends on them.
local function KeepFirstExclusive(catalog, selection)
    for _, category in ipairs(catalog.order) do
        if selection[category] then
            for _, other in ipairs(CosmeticsCatalog.ExclusiveOthers(catalog.nativeWeaponName, category)) do
                if selection[other] then
                    selection[other] = nil
                    for _, dependent in ipairs(CosmeticsCatalog.Dependents(other)) do selection[dependent] = nil end
                end
            end
        end
    end
end

local function CategoryHas(entry, componentName)
    for _, item in ipairs(entry.items) do
        if item.name == componentName then return true end
    end
    return false
end

-- Returns a clean selection, or nil plus an error code. Choices equal to a
-- category's standard item are dropped so only real changes are stored.
function CosmeticsCatalog.Normalize(catalog, selection)
    if type(catalog) ~= 'table' then return nil, 'weapon_unsupported' end
    if type(selection) ~= 'table' then return nil, 'invalid_selection' end

    local normalized, count = {}, 0
    for category, componentName in pairs(selection) do
        count = count + 1
        if count > MAX_CATEGORIES then return nil, 'invalid_selection' end
        local entry = type(category) == 'string' and catalog.categories[category] or nil
        if not entry or type(componentName) ~= 'string' or not CategoryHas(entry, componentName) then
            return nil, 'invalid_component'
        end
        if componentName ~= entry.default then normalized[category] = componentName end
    end

    for category in pairs(normalized) do
        for _, other in ipairs(CosmeticsCatalog.ExclusiveOthers(catalog.nativeWeaponName, category)) do
            if normalized[other] then return nil, 'invalid_selection' end
        end
    end

    for dependent, required in pairs(Config.Cosmetics.ComponentDependencies or {}) do
        if normalized[dependent] and not normalized[required] then
            return nil, 'dependency_missing'
        end
    end
    return normalized
end

-- Drops anything a stored selection no longer allows (config or Feather catalog
-- changed since it was saved) instead of rejecting the whole row.
function CosmeticsCatalog.Sanitize(catalog, selection)
    local cleaned = {}
    if type(catalog) ~= 'table' or type(selection) ~= 'table' then return cleaned end
    for category, componentName in pairs(selection) do
        local entry = catalog.categories[category]
        if entry and type(componentName) == 'string' and CategoryHas(entry, componentName)
            and componentName ~= entry.default then
            cleaned[category] = componentName
        end
    end
    KeepFirstExclusive(catalog, cleaned)
    for dependent, required in pairs(Config.Cosmetics.ComponentDependencies or {}) do
        if cleaned[dependent] and not cleaned[required] then cleaned[dependent] = nil end
    end
    return cleaned
end

-- The component each category should show: the player's choice, else the
-- category's standard item, else nil (native look, nothing to apply).
function CosmeticsCatalog.Wanted(catalog, selection, category)
    local entry = catalog.categories[category]
    if not entry then return nil end
    return (selection and selection[category]) or entry.default
end
