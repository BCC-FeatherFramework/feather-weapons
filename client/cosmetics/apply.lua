-- Keeps the player's equipped weapons showing their saved cosmetics.
--
-- Feather Weapons recreates the native weapon (GiveWeaponToPed) on equip,
-- restore, reconcile and resource restart, which drops every component it did
-- not add itself, and it raises no client event when that happens. So this
-- watches the ped instead: when the set of Feather weapons on the ped changes,
-- or a saved component goes missing, it reloads the loadout from the server and
-- applies it again. Applying only gives or removes cosmetic components; it never
-- touches ammunition, condition or Feather's functional attachments.
WeaponCosmetics = {}

local WATCH_INTERVAL_MS = 1000
local SETTLE_DELAY_MS = 750
local REAPPLY_THROTTLE_MS = 1500
local SLOT_ORDER = { primary = 1, offhand = 2, shoulder = 3, back = 4 }

local entries = {}          -- [itemInstanceId string] = entry
local featherWeaponHashes = {}
local refreshToken, refreshInFlight, refreshAgain = 0, false, false
local applyRequested, applyRunning = false, false
local lastSignature = nil
local listeners = {}
local driftHistory = {}     -- [itemInstanceId string] = { count, since }
-- What this script last put on each weapon, for categories whose "has" check
-- cannot be trusted: [itemInstanceId string] = { model, categories = { [cat] = name } }
local appliedState = {}

local function PedHasWeapon(ped, weaponHash)
    return Citizen.InvokeNative(0x8DECB02F88F428BC, ped, weaponHash, 0, false, Citizen.ResultAsInteger()) ~= 0 -- HasPedGotWeapon
end

local function PedHasComponent(ped, componentHash, weaponHash)
    return Citizen.InvokeNative(0xBBC67A6F965C688A, ped, componentHash, weaponHash, Citizen.ResultAsInteger()) ~= 0 -- _HasPedGotWeaponComponent
end

local function RemoveComponent(ped, componentHash, weaponHash)
    Citizen.InvokeNative(0x19F70C4D80494FF8, ped, componentHash, weaponHash) -- _RemoveWeaponComponentFromPed
end

-- `entity` is the ped (with its weapon hash) or a weapon object (with -1).
local function GiveComponent(entity, componentHash, weaponHash)
    local model = Citizen.InvokeNative(0x59DE03442B6C9598, componentHash, Citizen.ResultAsInteger()) -- GetWeaponComponentTypeModel
    if model and model ~= 0 then
        RequestModel(model, false)
        local deadline = GetGameTimer() + 2000
        while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(0) end
    end
    Citizen.InvokeNative(0x74C9090FDD1BB48E, entity, componentHash, weaponHash, true) -- _GiveWeaponComponentToEntity
    if model and model ~= 0 then SetModelAsNoLongerNeeded(model) end
end

local function HeldWeaponEntityAt(ped, attachPoint)
    return Citizen.InvokeNative(0x3B390A939AF0B5FC, ped, attachPoint, Citizen.ResultAsInteger()) -- GetCurrentPedWeaponEntityIndex
end

local function EntityHasComponent(entity, componentHash)
    return Citizen.InvokeNative(0x76A18844E743BF91, entity, componentHash, Citizen.ResultAsInteger()) ~= 0 -- _HasWeaponGotWeaponComponent
end

local function Unsigned(hash)
    return (tonumber(hash) or 0) & 0xFFFFFFFF
end

-- The visible model of a weapon the ped has out: in a hand or holstered/slung.
local function VisibleWeaponModel(ped, weaponHash)
    for _, attachPoint in ipairs(Config.Cosmetics.WeaponAttachPoints or { 0, 1, 2, 3, 9, 10 }) do
        local present, hash = GetCurrentPedWeapon(ped, true, attachPoint, true)
        if present and Unsigned(hash) == Unsigned(weaponHash) then
            local entity = HeldWeaponEntityAt(ped, attachPoint)
            if entity and entity ~= 0 and DoesEntityExist(entity) then return entity end
        end
    end
    return nil
end

-- Where components are applied: the weapon the player carries, or the preview
-- model at the bench. Both take the same component hashes.
--
-- For the carried weapon, the ped's record alone is not enough: when Feather
-- rebuilds the weapon (equip, draw, restore) the ped can still report a part
-- that the model you see no longer has, and trusting it left a held weapon
-- bare. So a part counts as there only when the ped AND the visible model have
-- it (given otherwise), and is removed when the ped has it. Checking first still
-- matters: every add or remove makes the game rebuild the weapon, so a correct
-- look must be left untouched or applying loops.
local function PedTarget(ped, weaponHash)
    local model = VisibleWeaponModel(ped, weaponHash)
    return {
        model = model,
        complete = function(componentHash)
            if not PedHasComponent(ped, componentHash, weaponHash) then return false end
            return not model or EntityHasComponent(model, componentHash)
        end,
        -- Removal follows the ped only. The model check reports some parts as
        -- present that are not (every sight material, seen in game), and a
        -- rebuilt model is made from the ped, so it cannot carry parts the ped
        -- does not have.
        present = function(componentHash) return PedHasComponent(ped, componentHash, weaponHash) end,
        remove = function(componentHash) RemoveComponent(ped, componentHash, weaponHash) end,
        give = function(componentHash) GiveComponent(ped, componentHash, weaponHash) end
    }
end

local function ObjectTarget(object)
    return {
        remove = function(componentHash)
            Citizen.InvokeNative(0xF7D82B0D66777611, object, componentHash) -- _RemoveWeaponComponentFromWeaponObject
        end,
        give = function(componentHash) GiveComponent(object, componentHash, -1) end
    }
end


local function Copy(map)
    local copy = {}
    for key, value in pairs(map or {}) do copy[key] = value end
    return copy
end

local function Selection(entry)
    return entry.preview or entry.cosmetics
end

-- Removes every other part of a category, then gives the wanted one.
-- On the ped only what is actually there is removed and only what is missing
-- is given, so a correct look is left untouched. A weapon object (the preview
-- model) has no reliable check (citizenfx/fivem#4026): there every other part is
-- removed without asking, or leftovers stack with the new part, like every
-- barrel and scope showing at once.
local function ApplyItems(target, items, wanted)
    for _, item in ipairs(items) do
        if item.name ~= wanted and (not target.present or target.present(joaat(item.name))) then
            target.remove(joaat(item.name))
            target.changed = true
            if target.log then target.log[#target.log + 1] = '-' .. item.name end
        end
    end
    if wanted and (not target.complete or not target.complete(joaat(wanted))) then
        target.give(joaat(wanted))
        target.changed = true
        if target.log then target.log[#target.log + 1] = '+' .. wanted end
    end
end

-- On the ped, the "has component" check for shared materials, tints and
-- engravings answers yes for every option of a category once any option of it
-- is on (seen in game: every SIGHT_MATERIAL_n "present" at once). When more
-- than one option reports present, the check means nothing for that category.
local function CategoryUnreliable(target, items)
    if not target.present then return false end
    local count = 0
    for _, item in ipairs(items) do
        if target.present(joaat(item.name)) then
            count = count + 1
            if count > 1 then return true end
        end
    end
    return false
end

-- For such a category: never remove what this script did not put there, and
-- give the choice when it changed, when the weapon model was rebuilt (draw,
-- holster, Feather restore), or when an earlier part in this pass changed (a
-- wrap material, for one, resets the wrap tint on top of it). What was last
-- applied is remembered instead of trusting the check.
local function ApplyUnreliable(target, entry, category, wanted, trusted)
    local state = appliedState[tostring(entry.itemInstanceId)]
    local last = state.categories[category]
    if wanted then
        -- When the check can be trusted and confirms the part is really there,
        -- nothing needs giving (e.g. right after a resource restart).
        local confirmed = trusted and not target.changed and target.complete(joaat(wanted))
        if not confirmed and (wanted ~= last or state.rebuilt or target.changed) then
            target.give(joaat(wanted))
            target.changed = true
            if target.log then target.log[#target.log + 1] = '+' .. wanted end
        end
    elseif last then
        target.remove(joaat(last))
        target.changed = true
        if target.log then target.log[#target.log + 1] = '-' .. last end
    end
    state.categories[category] = wanted
end

local function ApplyCategory(target, entry, category)
    local catalog = entry.catalog
    local wanted = CosmeticsCatalog.Wanted(catalog, Selection(entry), category)
    local items = catalog.categories[category].items
    -- Parts RedM drops from held weapons (#4026) never pass the check either; giving
    -- them on every pass would keep resetting what sits on top of them (the wrap
    -- tint), so they are given once per choice and weapon model like the above.
    local unreliable = target.present and CategoryUnreliable(target, items)
    if target.present and (unreliable or catalog.heldBroken[category]) then
        ApplyUnreliable(target, entry, category, wanted, not unreliable)
    else
        ApplyItems(target, items, wanted)
        if target.present then appliedState[tostring(entry.itemInstanceId)].categories[category] = wanted end
    end

    -- A grip brings its matching wood piece (forend, clip or stock). A grip with
    -- no matching piece keeps the standard one.
    if (Config.Cosmetics.PairedCategories or {})[category] then
        local chosen = wanted and catalog.pairs[wanted] or {}
        local standard = catalog.categories[category].default
        standard = standard and catalog.pairs[standard] or {}
        for partner, items in pairs(catalog.pairedItems) do
            ApplyItems(target, items, chosen[partner] or standard[partner])
        end
    end
end

local function ApplySelection(target, entry)
    -- A frame style can rebuild the weapon model, so it goes first and Feather's
    -- installed barrel/sight are re-shown after it. Those are only mirrored from
    -- Feather's metadata, never chosen here.
    if entry.catalog.categories.FRAME_VERTDATA then ApplyCategory(target, entry, 'FRAME_VERTDATA') end
    for _, componentName in ipairs(entry.functional) do
        if not target.complete or not target.complete(joaat(componentName)) then target.give(joaat(componentName)) end
    end
    for _, category in ipairs(entry.catalog.order) do
        if category ~= 'FRAME_VERTDATA' then ApplyCategory(target, entry, category) end
    end
end

-- Every part a weapon can take, in apply order: frame style first, then the
-- structural parts, Feather's attachments, the cosmetic categories and their
-- paired wood pieces.
local function AllParts(entry)
    local list, seen = {}, {}
    local function Add(name)
        if name and not seen[name] then seen[name] = true; list[#list + 1] = name end
    end
    local catalog = entry.catalog
    for _, item in ipairs(catalog.categories.FRAME_VERTDATA and catalog.categories.FRAME_VERTDATA.items or {}) do
        Add(item.name)
    end
    for _, items in pairs(catalog.structural) do for _, item in ipairs(items) do Add(item.name) end end
    for _, name in ipairs(entry.functional) do Add(name) end
    for _, category in ipairs(catalog.order) do
        for _, item in ipairs(catalog.categories[category].items) do Add(item.name) end
    end
    for _, items in pairs(catalog.pairedItems) do for _, item in ipairs(items) do Add(item.name) end end
    return list
end

-- femga: "FRAME_VERTDATA breaks colors for other components. You must remove it
-- for the other components to work." While a frame style is chosen, material and
-- tint categories are not applied (and reported as blocked).
local function IsColorCategory(category)
    return category:find('_MATERIAL$') ~= nil or category:find('_TINT$') ~= nil
end

-- Rebuilds the preview weapon object. It always shows the player's cosmetic
-- choices (a weapon object renders parts RedM drops from a held weapon), with
-- grip-matched wood pieces following the grip. Barrel, sight and other
-- structural parts are copied from the carried weapon, and Feather's installed
-- attachments are always shown. A fresh model does not carry the right parts,
-- so it is always cleared first.
function WeaponCosmetics.ApplyToObject(entry, object)
    if not object or not DoesEntityExist(object) then return end
    local target = ObjectTarget(object)
    local ped = PlayerPedId()

    if not PedHasWeapon(ped, entry.hash) then
        for _, items in pairs(entry.catalog.structural) do ApplyItems(target, items, nil) end
        ApplySelection(target, entry)
        return
    end

    local source = PedTarget(ped, entry.hash)
    local catalog, selection = entry.catalog, Selection(entry)
    local frame = catalog.categories.FRAME_VERTDATA and CosmeticsCatalog.Wanted(catalog, selection, 'FRAME_VERTDATA') or nil
    local parts, keep, decided = AllParts(entry), {}, {}

    -- Cosmetic categories: the selection (or the category's standard part).
    for category, info in pairs(catalog.categories) do
        for _, item in ipairs(info.items) do decided[item.name] = true end
        local blocked = frame and category ~= 'FRAME_VERTDATA' and IsColorCategory(category)
        local wanted = not blocked and CosmeticsCatalog.Wanted(catalog, selection, category) or nil
        if wanted then keep[wanted] = true end
    end
    -- Wood pieces follow the grip choice; no match keeps the standard piece.
    for gripCategory in pairs(Config.Cosmetics.PairedCategories or {}) do
        if catalog.categories[gripCategory] then
            local choice = CosmeticsCatalog.Wanted(catalog, selection, gripCategory)
            local chosen = choice and catalog.pairs[choice] or {}
            local standard = catalog.categories[gripCategory].default
            standard = standard and catalog.pairs[standard] or {}
            for partner, items in pairs(catalog.pairedItems) do
                for _, item in ipairs(items) do decided[item.name] = true end
                local piece = chosen[partner] or standard[partner]
                if piece then keep[piece] = true end
            end
        end
    end
    -- Structural parts: whatever the carried weapon has.
    for _, name in ipairs(parts) do
        if not decided[name] and source.complete(joaat(name)) then keep[name] = true end
    end
    for _, name in ipairs(entry.functional) do keep[name] = true end

    for _, name in ipairs(parts) do
        if not keep[name] then target.remove(joaat(name)) end
    end
    for _, name in ipairs(parts) do
        if keep[name] then target.give(joaat(name)) end
    end
end

local ReportApplied -- defined below, next to ScheduleApply
local forceNextRefresh = false

-- What should be on a carried weapon: its cosmetic choices and Feather's
-- functional attachments. An apply runs only when this changes, when the weapon
-- was re-equipped, or when a part that can be checked reliably went missing.
local function ApplySignature(entry)
    local parts = {}
    for category, name in pairs(Selection(entry)) do parts[#parts + 1] = category .. '=' .. name end
    table.sort(parts)
    return table.concat(parts, ',') .. '|' .. table.concat(entry.functional or {}, ',')
end

-- Brings the carried weapon to the selection: removes the parts it reports
-- having that are not wanted, then gives the frame style, Feather's functional
-- attachments (barrel, sight) and the chosen parts in apply order.
-- Only reported parts are removed: every add or remove makes RedM rebuild the
-- weapon, and parts given during a burst of rebuilds can be lost. Categories
-- RedM cannot show on a held weapon (#4026) are left to the preview model; a
-- wrap material given here would also reset the wrap tint.
-- Returns the set of categories blocked by a frame style.
local function ApplyClean(ped, entry)
    local catalog, selection = entry.catalog, Selection(entry)
    local frame = catalog.categories.FRAME_VERTDATA and CosmeticsCatalog.Wanted(catalog, selection, 'FRAME_VERTDATA') or nil

    local plan, wanted, blocked = {}, {}, {}
    local function Want(name)
        if name and not wanted[name] then
            wanted[name] = true
            plan[#plan + 1] = name
        end
    end
    for _, name in ipairs(entry.functional) do wanted[name] = true end
    if frame then wanted[frame] = true end
    for _, category in ipairs(catalog.order) do
        local skipped = catalog.skipInHand[category] == true
        if category ~= 'FRAME_VERTDATA' and not skipped then
            if frame and IsColorCategory(category) then
                blocked[category] = true
            else
                local choice = CosmeticsCatalog.Wanted(catalog, selection, category)
                Want(choice)
                -- A grip brings its matching wood piece; no match keeps the standard one.
                if (Config.Cosmetics.PairedCategories or {})[category] then
                    local chosen = choice and catalog.pairs[choice] or {}
                    local standard = catalog.categories[category].default
                    standard = standard and catalog.pairs[standard] or {}
                    for partner in pairs(catalog.pairedItems) do Want(chosen[partner] or standard[partner]) end
                end
            end
        end
    end

    local function RemoveUnwanted(items)
        for _, item in ipairs(items) do
            local hash = joaat(item.name)
            if not wanted[item.name] and PedHasComponent(ped, hash, entry.hash) then
                RemoveComponent(ped, hash, entry.hash)
            end
        end
    end
    for _, category in ipairs(catalog.order) do
        if not catalog.skipInHand[category] then
            RemoveUnwanted(catalog.categories[category].items)
        end
    end
    for _, items in pairs(catalog.pairedItems) do RemoveUnwanted(items) end
    Wait(0)

    -- A frame style can rebuild the weapon model, so it goes first.
    if frame then GiveComponent(ped, joaat(frame), entry.hash) end
    for _, name in ipairs(entry.functional) do GiveComponent(ped, joaat(name), entry.hash) end
    for _, name in ipairs(plan) do GiveComponent(ped, joaat(name), entry.hash) end
    return blocked
end

-- Removes every cosmetic part the carried weapon reports having, including
-- hidden categories and parts RedM cannot show in hand. Runs once per weapon
-- after this resource starts, so leftovers from before the restart (or from
-- categories hidden since) are cleared before the saved look is applied.
local function ClearAll(ped, entry)
    local function Clear(items)
        for _, item in ipairs(items) do
            local hash = joaat(item.name)
            if PedHasComponent(ped, hash, entry.hash) then RemoveComponent(ped, hash, entry.hash) end
        end
    end
    for _, info in pairs(entry.catalog.categories) do Clear(info.items) end
    for _, items in pairs(entry.catalog.hidden or {}) do Clear(items) end
    Wait(0)
end

local function ApplyEntry(entry)
    local ped = PlayerPedId()
    if not PedHasWeapon(ped, entry.hash) then return end

    local id = tostring(entry.itemInstanceId)
    local state = appliedState[id] or {}
    appliedState[id] = state
    local signature = ApplySignature(entry)
    if state.signature == signature and not state.force then return end
    state.force = nil
    -- appliedState starts empty when this resource starts: the first apply of
    -- each weapon clears it fully before applying the saved look.
    if not state.cleared then
        ClearAll(ped, entry)
        state.cleared = true
        CosmeticsDebug(('cleared %s after resource start'):format(entry.nativeWeaponName))
    end
    local blocked = ApplyClean(ped, entry)
    state.signature = signature
    CosmeticsDebug(('applied %s'):format(entry.nativeWeaponName))

    -- Let RedM finish rebuilding the weapon before checking it.
    Wait(250)
    local target = PedTarget(ped, entry.hash)
    entry.probes = {}
    local report = {}
    for category, componentName in pairs(Selection(entry)) do
        local info = entry.catalog.categories[category]
        local status
        if blocked[category] then
            status = 'blocked'
        elseif entry.catalog.previewOnly[componentName] then
            status = 'held_broken'
        elseif entry.catalog.skipInHand[category] then
            status = 'held_broken'
        elseif entry.catalog.heldBroken[category] then
            status = 'held_risky'
        elseif info and CategoryUnreliable(target, info.items) then
            -- RedM cannot check these; Config.Cosmetics.ConfirmedCategories
            -- lists the ones seen working in game, in hand and on the model.
            status = (Config.Cosmetics.ConfirmedCategories or {})[category] and 'confirmed' or 'unverifiable'
        elseif target.present(joaat(componentName)) then
            status = 'applied'
            entry.probes[#entry.probes + 1] = joaat(componentName)
        else
            status = 'missing'
        end
        report[#report + 1] = { category = category, name = componentName, status = status }
    end
    -- Feather's attachments are reliable probes for a weapon Feather re-created.
    for _, componentName in ipairs(entry.functional) do
        local present = target.present(joaat(componentName))
        if present then entry.probes[#entry.probes + 1] = joaat(componentName) end
        report[#report + 1] = { category = 'ATTACHMENT', name = componentName,
            status = present and 'applied' or 'missing' }
    end
    ReportApplied(entry, report)
    entry.appliedAt = GetGameTimer()
end

-- DevMode console report: after an apply, prints only the parts whose result
-- changed since the last report for that weapon.
--   green  applied       on the weapon (checked)
--   yellow given         given, but RedM cannot confirm this kind of part
--   green  given (confirmed) RedM cannot check it, but it was confirmed in game
--                        (Config.Cosmetics.ConfirmedCategories)
--   yellow given (risky)  given, but RedM may not show it in hand (bug #4026)
--   red    not in hand   skipped in hand (Config.Cosmetics.HeldRenderIssues.skipInHand)
--   red    blocked       a frame style is chosen (femga: it breaks colors)
--   red    not applied   not on the weapon
local lastReport = {} -- [itemInstanceId string] = { [category] = 'COMPONENT|status' }

function ReportApplied(entry, report)
    if not Config.DevMode then return end
    local id = tostring(entry.itemInstanceId)
    local previous = lastReport[id] or {}
    local current, changed = {}, {}
    for _, line in ipairs(report) do
        local key = line.name .. '|' .. line.status
        current[line.category .. ':' .. line.name] = key
        if previous[line.category .. ':' .. line.name] ~= key then changed[#changed + 1] = line end
    end
    lastReport[id] = current
    if #changed == 0 then return end

    table.sort(changed, function(a, b) return a.category < b.category end)
    local formats = {
        applied = '^2[feather-weapons cosmetics] %s: applied %s (%s)^7',
        unverifiable = '^3[feather-weapons cosmetics] %s: given %s (%s, RedM cannot confirm this part)^7',
        confirmed = '^2[feather-weapons cosmetics] %s: given %s (%s, confirmed in game)^7',
        held_broken = '^1[feather-weapons cosmetics] %s: %s not shown in hand (%s, RedM bug #4026, preview only)^7',
        held_risky = '^3[feather-weapons cosmetics] %s: given %s (%s; RedM may not show it in hand, bug #4026)^7',
        blocked = '^1[feather-weapons cosmetics] %s: %s not applied (%s, blocked by the frame style: femga says FRAME_VERTDATA breaks colors)^7',
        missing = '^1[feather-weapons cosmetics] %s: %s not applied (%s)^7'
    }
    for _, line in ipairs(changed) do
        print(formats[line.status]:format(entry.nativeWeaponName, line.name, line.category))
    end
end

-- `reason` is only logged (DevMode), to show what requested an apply pass.
local function ScheduleApply(reason)
    CosmeticsDebug(('apply pass requested: %s%s'):format(tostring(reason), applyRunning and ' (queued)' or ''))
    applyRequested = true
    if applyRunning then return end
    applyRunning = true
    CreateThread(function()
        while applyRequested do
            applyRequested = false
            for _, entry in pairs(entries) do ApplyEntry(entry) end
            if CosmeticsPreview and CosmeticsPreview.Active() then
                -- Let the visible weapon model catch up before the preview copies it.
                Wait(150)
                CosmeticsPreview.Refresh()
            end
        end
        applyRunning = false
    end)
end

local function NotifyListeners()
    for _, listener in pairs(listeners) do pcall(listener) end
end

local function SetOf(list)
    local set = {}
    for _, value in ipairs(list or {}) do set[value] = true end
    return set
end

local function Refresh()
    if refreshInFlight then refreshAgain = true; return end
    refreshInFlight = true
    repeat
        refreshAgain = false
        local result = CosmeticsCall('feather-weapons:cosmetics:loadout')
        if result.ok then
            local hashes = {}
            for _, name in ipairs(result.value.nativeWeapons or {}) do hashes[#hashes + 1] = joaat(name) end
            featherWeaponHashes = hashes

            local loaded = {}
            for _, slot in ipairs(result.value.slots or {}) do
                local catalog = CosmeticsCatalog.Catalog(slot.nativeWeaponName, SetOf(slot.reserved))
                if catalog then
                    local id = tostring(slot.itemInstanceId)
                    local previous = entries[id]
                    loaded[id] = {
                        itemInstanceId = slot.itemInstanceId,
                        slot = slot.slot,
                        serialNumber = slot.serialNumber,
                        label = slot.label,
                        nativeWeaponName = slot.nativeWeaponName,
                        hash = joaat(slot.nativeWeaponName),
                        catalog = catalog,
                        functional = slot.functional or {},
                        cosmetics = slot.cosmetics or {},
                        -- An open preview survives a reload of the same weapon.
                        preview = previous and previous.preview or nil,
                        probes = {}
                    }
                end
            end
            entries = loaded
            -- The weapons on the ped changed: Feather re-created them, which drops
            -- every component it did not add, so apply even if nothing was chosen.
            if forceNextRefresh then
                forceNextRefresh = false
                for id in pairs(loaded) do
                    appliedState[id] = appliedState[id] or {}
                    appliedState[id].force = true
                end
            end
            ScheduleApply('loadout refresh')
            NotifyListeners()
        elseif result.code == 'character_required' then
            entries = {}
            NotifyListeners()
        else
            CosmeticsDebug('loadout refresh failed:', result.code)
        end
    until not refreshAgain
    refreshInFlight = false
end

function WeaponCosmetics.RequestRefresh(delayMs, reason)
    CosmeticsDebug(('loadout refresh requested in %dms: %s'):format(delayMs or 0, tostring(reason)))
    refreshToken = refreshToken + 1
    local token = refreshToken
    SetTimeout(delayMs or 0, function()
        if token == refreshToken then CreateThread(Refresh) end
    end)
end

-- Reloads the loadout and waits for it. Must run in a thread.
function WeaponCosmetics.RefreshNow()
    CosmeticsDebug('loadout refresh requested now: menu')
    if refreshInFlight then
        refreshAgain = true
        while refreshInFlight do Wait(50) end
    else
        Refresh()
    end
end

function WeaponCosmetics.Clear()
    refreshToken = refreshToken + 1
    entries, lastSignature = {}, nil
    NotifyListeners()
end

-- Equipped weapons that can be customized, in slot order.
function WeaponCosmetics.Entries()
    local list = {}
    for _, entry in pairs(entries) do list[#list + 1] = entry end
    table.sort(list, function(a, b) return (SLOT_ORDER[a.slot] or 9) < (SLOT_ORDER[b.slot] or 9) end)
    return list
end

function WeaponCosmetics.Find(itemInstanceId)
    return entries[tostring(itemInstanceId)]
end

function WeaponCosmetics.OnChanged(key, listener)
    listeners[key] = listener
end

function WeaponCosmetics.BeginPreview(entry)
    if not entry.preview then entry.preview = Copy(entry.cosmetics) end
end

-- Changes one category in the preview and shows it on the weapon. Clearing an
-- engraving also clears the material that depends on it.
function WeaponCosmetics.SetPreview(entry, category, componentName)
    WeaponCosmetics.BeginPreview(entry)
    local required = (Config.Cosmetics.ComponentDependencies or {})[category]
    if componentName and required and not entry.preview[required] then
        return false, 'dependency_missing'
    end
    local entryInfo = entry.catalog.categories[category]
    CosmeticsDebug(('preview change: %s -> %s'):format(category, tostring(componentName)))
    entry.preview[category] = (componentName ~= entryInfo.default) and componentName or nil
    local cleared = {}
    local function Clear(target)
        if entry.preview[target] then
            entry.preview[target] = nil
            cleared[#cleared + 1] = target
        end
        for _, dependent in ipairs(CosmeticsCatalog.Dependents(target)) do
            if entry.preview[dependent] then
                entry.preview[dependent] = nil
                cleared[#cleared + 1] = dependent
            end
        end
    end
    if not entry.preview[category] then
        for _, dependent in ipairs(CosmeticsCatalog.Dependents(category)) do
            if entry.preview[dependent] then
                entry.preview[dependent] = nil
                cleared[#cleared + 1] = dependent
            end
        end
    else
        -- Config.Cosmetics.ExclusiveCategories: the others in this category's group go.
        for _, other in ipairs(CosmeticsCatalog.ExclusiveOthers(entry.nativeWeaponName, category)) do Clear(other) end
    end
    ScheduleApply('preview change ' .. category)
    return true, cleared
end

function WeaponCosmetics.HasChanges(entry)
    if not entry.preview then return false end
    for category, componentName in pairs(entry.preview) do
        if entry.cosmetics[category] ~= componentName then return true end
    end
    for category in pairs(entry.cosmetics) do
        if entry.preview[category] == nil then return true end
    end
    return false
end

-- Ends a preview; without a save the weapon goes back to its saved look.
function WeaponCosmetics.EndPreview(entry)
    if not entry.preview then return end
    entry.preview = nil
    driftHistory[tostring(entry.itemInstanceId)] = nil
    ScheduleApply('end preview')
end

function WeaponCosmetics.EndAllPreviews()
    for _, entry in pairs(entries) do WeaponCosmetics.EndPreview(entry) end
end

function WeaponCosmetics.Commit(entry, cosmetics)
    entry.cosmetics = Copy(cosmetics)
    entry.preview = Copy(cosmetics)
    ScheduleApply('save')
end

local function WeaponSignature(ped)
    local present = {}
    for _, hash in ipairs(featherWeaponHashes) do
        if PedHasWeapon(ped, hash) then present[#present + 1] = tostring(hash) end
    end
    return table.concat(present, ',')
end

-- Stops re-applying a weapon whose components keep disappearing (more than
-- DRIFT_LIMIT times inside DRIFT_WINDOW_MS) until its loadout changes.
local DRIFT_LIMIT, DRIFT_WINDOW_MS = 3, 20000

local function AllowDriftReapply(entry)
    local id, now = tostring(entry.itemInstanceId), GetGameTimer()
    local history = driftHistory[id]
    if not history or now - history.since > DRIFT_WINDOW_MS then
        history = { count = 0, since = now }
        driftHistory[id] = history
    end
    history.count = history.count + 1
    if history.count == DRIFT_LIMIT + 1 then
        CosmeticsDebug(('components keep dropping on %s; pausing re-apply'):format(entry.nativeWeaponName))
    end
    return history.count <= DRIFT_LIMIT
end

-- A probe part (one whose presence RedM reports reliably) went missing from the
-- carried weapon: Feather or the game re-created it. The weapon model alone is
-- not used: the game makes a new one on every draw, holster and component change.
local function Drifted(ped, entry)
    if not PedHasWeapon(ped, entry.hash) then return false end
    if GetGameTimer() - (entry.appliedAt or 0) < REAPPLY_THROTTLE_MS then return false end
    for _, componentHash in ipairs(entry.probes or {}) do
        if not PedHasComponent(ped, componentHash, entry.hash) then
            CosmeticsDebug(('reapply: %s lost component %s'):format(entry.nativeWeaponName, tostring(componentHash)))
            if not AllowDriftReapply(entry) then return false end
            local id = tostring(entry.itemInstanceId)
            appliedState[id] = appliedState[id] or {}
            appliedState[id].force = true
            return true
        end
    end
    return false
end

CreateThread(function()
    while true do
        Wait(WATCH_INTERVAL_MS)
        if #featherWeaponHashes > 0 then
            local ped = PlayerPedId()
            local signature = WeaponSignature(ped)
            if signature ~= lastSignature then
                -- Let Feather finish equipping or restoring before reading it.
                CosmeticsDebug(('reload: Feather weapons on the ped changed (%s -> %s)'):format(
                    tostring(lastSignature), signature))
                lastSignature = signature
                driftHistory = {}
                forceNextRefresh = true
                WeaponCosmetics.RequestRefresh(SETTLE_DELAY_MS, 'watcher: Feather weapons on the ped changed')
            elseif not refreshInFlight and not applyRunning then
                for _, entry in pairs(entries) do
                    if Drifted(ped, entry) then
                        WeaponCosmetics.RequestRefresh(0, 'watcher: drift on ' .. tostring(entry.nativeWeaponName))
                        break
                    end
                end
            end
        end
    end
end)

-- Experimental workaround for citizenfx/fivem#4026 (off by default): some
-- long-gun parts (grip stock tint, grip material, wrap material) report as given
-- to the ped but never reach the weapon it holds, while they render on a
-- standalone weapon object. With the workaround on, those parts are also put
-- straight onto the weapon models at Config.Cosmetics.HeldRenderIssues.attachPoints.
-- Tested on RedM b1491: the ped route is ignored, adding to the held model makes
-- RedM rebuild the weapon (new model every try, part never shown), and the
-- weapon-object native crashes. Kept, guarded, for a RedM build that fixes it.
-- ['item:attachPoint'] = { signature, entity, triedAt, rebuilds, gaveUp }
local heldFix = {}


-- The parts an entry needs on its weapon entity, and every other part of those
-- categories (to clear when the choice changes).
local function HeldFixParts(entry)
    local wanted, others, names = {}, {}, {}
    for category in pairs(entry.catalog.heldFix or {}) do
        local chosen = CosmeticsCatalog.Wanted(entry.catalog, Selection(entry), category)
        for _, item in ipairs(entry.catalog.categories[category].items) do
            if item.name == chosen then
                wanted[#wanted + 1] = joaat(item.name)
                names[#names + 1] = item.name
            else
                others[#others + 1] = joaat(item.name)
            end
        end
    end
    table.sort(names)
    return wanted, others, table.concat(names, ',')
end

-- One try per weapon model. The game makes a new model on every draw and
-- holster, and that new model gets its own try. But if the model is replaced
-- right after a try, the try itself made RedM rebuild the weapon (seen in game:
-- a new model every 250 ms, part never shown); after `maxRebuilds` of those the
-- fix gives up for that weapon and choice instead of looping, until the choice
-- changes or the resource restarts.
local function FixWeaponEntity(entity, entry, attachPoint)
    local wanted, others, signature = HeldFixParts(entry)
    local key = ('%s:%s'):format(tostring(entry.itemInstanceId), tostring(attachPoint))
    local fix = heldFix[key]
    if not fix or fix.signature ~= signature then
        if fix then
            -- The player changed the choice: clear the old parts from this model
            -- once, without asking (the entity check is the unreliable one).
            for _, componentHash in ipairs(others) do
                Citizen.InvokeNative(0xF7D82B0D66777611, entity, componentHash) -- _RemoveWeaponComponentFromWeaponObject
            end
        end
        fix = { signature = signature, rebuilds = 0 }
        heldFix[key] = fix
    end
    if fix.gaveUp or fix.entity == entity then return end

    local issues = Config.Cosmetics.HeldRenderIssues or {}
    local now = GetGameTimer()
    if fix.triedAt and now - fix.triedAt < (issues.rebuildWindowMs or 1500) then
        fix.rebuilds = fix.rebuilds + 1
        if fix.rebuilds >= (issues.maxRebuilds or 2) then
            fix.gaveUp = true
            print(('[feather-weapons cosmetics] held fix: RedM rebuilds %s every time %s is added at attach point %s, so it cannot be shown in hand on this build. Giving up for this weapon; set Config.Cosmetics.HeldRenderIssues.workaround = false to hide these parts.')
                :format(entry.nativeWeaponName, signature, tostring(attachPoint)))
            return
        end
    else
        fix.rebuilds = 0 -- a normal draw or holster, not caused by a try
    end
    fix.entity = entity

    local missing = {}
    for _, componentHash in ipairs(wanted) do
        if not EntityHasComponent(entity, componentHash) then missing[#missing + 1] = componentHash end
    end
    if #missing == 0 then return end
    -- Do NOT use _GiveWeaponComponentToWeaponObject (0x1A47699E8D533E8F) here: on
    -- RedM b1491 it crashes the native call (exception in GTAProcess) on a held
    -- weapon model. This route does not crash, but RedM may rebuild the weapon;
    -- the rebuild guard above stops that.
    for _, componentHash in ipairs(missing) do GiveComponent(entity, componentHash, -1) end
    fix.triedAt = now
    CosmeticsDebug(('held fix: %s parts %s onto model %s at point %s (rebuilds so far %d)'):format(
        entry.nativeWeaponName, signature, tostring(entity), tostring(attachPoint), fix.rebuilds))
end

-- One pass over the player's weapon entities. Must run in a thread.
function WeaponCosmetics.FixHeldWeapons()
    local issues = Config.Cosmetics.HeldRenderIssues or {}
    if issues.workaround ~= true or not next(entries) then return end
    local byHash = {}
    for _, entry in pairs(entries) do
        if next(entry.catalog.heldFix or {}) then byHash[Unsigned(entry.hash)] = entry end
    end
    if not next(byHash) then return end

    local ped, seen = PlayerPedId(), {}
    for _, attachPoint in ipairs(issues.attachPoints or { 0, 1, 9, 10 }) do
        local present, weaponHash = GetCurrentPedWeapon(ped, true, attachPoint, true)
        local entry = present and byHash[Unsigned(weaponHash)] or nil
        local entity = entry and HeldWeaponEntityAt(ped, attachPoint) or 0
        if entity ~= 0 and DoesEntityExist(entity) and not seen[entity] then
            seen[entity] = true
            FixWeaponEntity(entity, entry, attachPoint)
        end
    end
end

CreateThread(function()
    while true do
        Wait((Config.Cosmetics.HeldRenderIssues or {}).intervalMs or 250)
        WeaponCosmetics.FixHeldWeapons()
    end
end)

AddEventHandler('Feather:Character:Spawned', function() WeaponCosmetics.RequestRefresh(1500) end)
AddEventHandler('feather-character:client:runtime-ready.v1', function() WeaponCosmetics.RequestRefresh(1500) end)
AddEventHandler('Feather:Character:Logout', function() WeaponCosmetics.Clear() end)

-- Cosmetics are part of feather-weapons: when it starts, the weapons are being
-- re-created without any cosmetic part, so the first apply is forced.
AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    forceNextRefresh = true
    WeaponCosmetics.RequestRefresh(3000, 'feather-weapons started')
end)

