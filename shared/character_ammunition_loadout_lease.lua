-- Server-owned revision binding; a snapshot is not a permanent item lease.
WeaponCharacterAmmoLoadoutLease={}
-- Same synchronous no-SQL guard is used by production registration and the
-- disposable cross-resource rollback probe. The predicate is server-owned.
function WeaponCharacterAmmoLoadoutLease.Guard(isBound)
    return function(instance)
        if isBound(instance.id) then
            return false,'Native loadout still owns this item; complete its release first.'
        end
        return true
    end
end
local function copy(v)
    if type(v)~='table' then return v end
    local out={}; for k,x in pairs(v) do out[k]=copy(x) end; return out
end
local function equal(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
function WeaponCharacterAmmoLoadoutLease.New(plan)
    assert(type(plan)=='table' and type(plan.identity)=='table' and type(plan.items)=='table','Creation plan required')
    local expected=copy(plan)
    return {Validate=function(snapshot,catalog,registry)
        if type(snapshot)~='table' or snapshot.characterId~=expected.identity.characterId
            or type(snapshot.equipment)~='table' then return false,'loadout_identity_changed' end
        local actual,reason=WeaponCharacterAmmoMaterialization.Build(snapshot.equipment,catalog,registry,expected.identity)
        if not actual then return false,reason end
        if not equal(actual,expected) then return false,'loadout_revision_or_content_changed' end
        return true
    end,Contains=function(itemId)
        for _,item in ipairs(expected.items) do if item.itemInstanceId==tonumber(itemId) then return true end end
        return false
    end}
end
