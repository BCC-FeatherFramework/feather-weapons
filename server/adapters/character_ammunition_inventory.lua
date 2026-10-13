-- Native-only Inventory guard composition. Explicit installation only; does
-- not register legacy usable handlers or enable either runtime flag.
WeaponCharacterAmmoInventory={}
local function callable(value)
    return type(value)=='function' or type(value)=='table'
        and type(rawget(value,'__cfx_functionReference'))=='string'
end
function WeaponCharacterAmmoInventory.New(getInventory,isBound,administrativePolicy)
    assert(callable(getInventory) and callable(isBound) and callable(administrativePolicy),
        'native_inventory_callbacks_required')
    local phase='dormant'
    local surface
    local T={}
    local function fail(code) phase='failed'; return nil,code end
    local function guard(instance)
        if type(instance)~='table' or type(instance.id)~='number'
            or instance.id<1 or instance.id%1~=0 then
            return false,'Unable to verify native item ownership.'
        end
        local ok,bound=pcall(isBound,instance.id)
        if not ok or type(bound)~='boolean' then
            return false,'Unable to verify native item ownership.'
        end
        if bound then return false,'Native loadout still owns this item; complete its release first.' end
        return true
    end
    local function movementGuard(instance)
        local permitted,reason=guard(instance)
        if not permitted then return false,reason end
        local checked,equipped=pcall(surface.Equipment.IsInstanceEquipped,instance.id)
        if not checked or type(equipped)~='table' or equipped.ok~=true
            or type(equipped.value)~='boolean' then return false,'Unable to verify equipped state.' end
        if equipped.value then return false,'Unequip this item before moving or removing it.' end
        local called,allowed,why=pcall(administrativePolicy,instance)
        if not called or type(allowed)~='boolean' then return false,'Unable to verify administrative state.' end
        return allowed,why
    end
    function T.Install()
        if phase~='dormant' then return nil,'native_inventory_already_attempted' end
        if Config.CharacterAmmunitionEnabled~=true or Config.CharacterAmmoTransportEnabled~=true then
            return nil,'character_ammunition_disabled'
        end
        phase='installing'
        local ok,inventory=pcall(getInventory)
        if not ok or type(inventory)~='table' or not callable(inventory.GetCapabilities)
            or type(inventory.Guards)~='table' or type(inventory.Equipment)~='table'
            or not callable(inventory.Equipment.IsInstanceEquipped) then return fail('native_inventory_unavailable') end
        local got,caps=pcall(inventory.GetCapabilities)
        local value=got and type(caps)=='table' and caps.ok==true and caps.value
        if type(value)~='table' or (tonumber(value.contractVersion) or 0)<Config.Inventory.requiredContract
            or type(value.characterIdentity)~='table' or value.characterIdentity.uuid~=true
            or value.characterIdentity.mode~='uuid' then return fail('native_inventory_contract') end
        for _,name in ipairs({'RegisterMoveGuard','RegisterDestroyGuard','RegisterInstanceChangeGuard'}) do
            if not callable(inventory.Guards[name]) then return fail('native_inventory_guard_missing') end
        end
        surface=inventory
        for _,name in ipairs({'RegisterMoveGuard','RegisterDestroyGuard','RegisterInstanceChangeGuard'}) do
            if Config.CharacterAmmunitionEnabled~=true or Config.CharacterAmmoTransportEnabled~=true then
                return fail('character_ammunition_disabled')
            end
            local callback=name=='RegisterInstanceChangeGuard' and guard or movementGuard
            local registered,result=pcall(inventory.Guards[name],'feather-weapons',callback)
            if not registered or type(result)~='table' or result.ok~=true then
                return fail('native_inventory_guard_failed')
            end
        end
        if Config.CharacterAmmunitionEnabled~=true or Config.CharacterAmmoTransportEnabled~=true then
            return fail('character_ammunition_disabled')
        end
        phase='ready'; return true
    end
    function T.Status() return phase end
    return T
end
-- Construction is inert. The eventual startup owner explicitly calls Install.
WeaponCharacterAmmoInventoryProvider=WeaponCharacterAmmoInventory.New(function()
    assert(GetResourceState('feather-inventory')=='started','inventory_not_started')
    return exports['feather-inventory'].initiate()
end,function(id) return WeaponCharacterAmmoService.IsNativeItemBound(id) end,function(instance)
    local name=type(instance.definition)=='table' and instance.definition.name
    for _,definition in pairs(WeaponDefinitionCatalog.weapons) do
        if definition.itemName==name then
            return WeaponOwnershipService.EvaluateAdministrativeHold(instance.metadata)
        end
    end
    return true
end)
