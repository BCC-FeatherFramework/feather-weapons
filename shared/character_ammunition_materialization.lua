-- Data-only native creation plan. Execution/Inventory authorization are separate.
WeaponCharacterAmmoMaterialization={}
-- Client preflight against its trusted definition registry. A server bundle is
-- not permission to invoke arbitrary weapon hashes/points or fabricate ammo.
function WeaponCharacterAmmoMaterialization.Validate(plan,registry,baseline)
    if type(plan)~='table' or type(plan.identity)~='table' or type(plan.items)~='table'
        or type(registry)~='table' or type(registry.weapons)~='table' or type(baseline)~='table' then return nil,'invalid_creation_bundle' end
    for _,key in ipairs({'characterId','sessionId','epoch'}) do
        if plan.identity[key]~=baseline[key] then return nil,'creation_identity_mismatch' end
    end
    local slots={primary=2,offhand=3,shoulder=10,back=9}
    local seen,ids,models={},{},{}
    local count=0
    for key,item in pairs(plan.items) do
        count=count+1
        if type(key)~='number' or key<1 or key%1~=0 or key>4 or type(item)~='table'
            or not slots[item.slot] or seen[item.slot] or slots[item.slot]~=item.point then return nil,'invalid_creation_slot' end
        local definition=registry.weapons[item.definitionId]
        if not definition or definition.nativeWeaponName~=item.nativeWeaponName
            or not definition.compatible[item.preferredAmmoType] then return nil,'untrusted_creation_definition' end
        local sidearm=definition.family=='pistol' or definition.family=='revolver'
        if sidearm~=(item.slot=='primary' or item.slot=='offhand') then return nil,'invalid_creation_category' end
        for _,field in ipairs({'itemInstanceId','itemRevision'}) do
            local value=item[field]
            if type(value)~='number' or value<0 or value%1~=0 or value==math.huge then return nil,'invalid_creation_item' end
        end
        if item.itemInstanceId==0 or ids[item.itemInstanceId] then return nil,'duplicate_creation_item' end
        if item.copyKey~=('%s:%s:%s'):format(item.slot,item.itemInstanceId,item.itemRevision) then return nil,'invalid_copy_key' end
        if type(item.attachments)~='table' or next(item.attachments) or type(item.cosmetics)~='table' or next(item.cosmetics) then
            return nil,'creation_customization_not_implemented'
        end
        seen[item.slot]=item; ids[item.itemInstanceId]=true
        models[item.nativeWeaponName]=(models[item.nativeWeaponName] or 0)+1
    end
    for index=1,count do if not plan.items[index] then return nil,'sparse_creation_items' end end
    if seen.offhand and not seen.primary then return nil,'primary_required_for_offhand' end
    local same=seen.primary and seen.offhand and seen.primary.nativeWeaponName==seen.offhand.nativeWeaponName or false
    if plan.dual~=(seen.offhand~=nil) or plan.sameModel~=same then return nil,'creation_pair_flags_mismatch' end
    for _,item in ipairs(plan.items) do
        local pair=same and (item.slot=='primary' or item.slot=='offhand')
        if models[item.nativeWeaponName]>1 and not pair then return nil,'unsupported_creation_duplicates' end
        if item.creation~=(pair and 'inventory_guid_pair' or 'native_zero_ammo_grant') then return nil,'invalid_creation_strategy' end
    end
    return true
end
local function clone(v)
    if type(v)~='table' then return v end
    local out={}; for k,x in pairs(v) do out[k]=clone(x) end; return out
end
function WeaponCharacterAmmoMaterialization.Build(rows,catalog,registry,identity)
    if type(identity)~='table' then return nil,'invalid_materialization_identity' end
    for _,key in ipairs({'characterId','sessionId','epoch'}) do
        if type(identity[key])~='string' or #identity[key]<1 or #identity[key]>128 then
            return nil,'invalid_materialization_identity'
        end
    end
    local loadout,reason=WeaponCharacterAmmoItem.Loadout(rows,catalog,registry)
    if not loadout then return nil,reason end
    local plan={identity={characterId=identity.characterId,sessionId=identity.sessionId,epoch=identity.epoch},
        dual=loadout.dual,sameModel=loadout.sameModel,items={}}
    for _,slot in ipairs({'primary','offhand','shoulder','back'}) do
        local item=loadout.slots[slot]
        if item then
            local entry=clone(item)
            entry.slot=slot
            -- Never use the model hash as copy identity. Native GUID/entity
            -- creation must return a distinct handle for each entry at execution.
            entry.copyKey=('%s:%s:%s'):format(slot,item.itemInstanceId,item.itemRevision)
            entry.creation=loadout.sameModel and (slot=='primary' or slot=='offhand')
                and 'inventory_guid_pair' or 'native_zero_ammo_grant'
            plan.items[#plan.items+1]=entry
        end
    end
    -- No ammo totals, clips, selected-type writes, give-ammo amounts or handles.
    -- preferredAmmoType is retained as data, not a native creation instruction.
    return plan
end
