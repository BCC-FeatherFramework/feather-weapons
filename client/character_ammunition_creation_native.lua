-- Explicit creation adapter. Never touches ammo totals, clips or ammo selection.
-- Entitlement/appearance readiness is supplied by the owning lifecycle adapter.
WeaponCharacterAmmoCreationNative={}
function WeaponCharacterAmmoCreationNative.New(ped,current,prepareDual)
    assert(type(current)=='function' and type(prepareDual)=='function','Local lifecycle callbacks required')
    local function yes(v) return v==true or v==1 end
    local function buffer() return string.rep('\0',104) end
    local function resolve(parent,item,slot)
        local out=buffer()
        return yes(Citizen.InvokeNative(0x886DFD3E185C8A89,1,parent,joaat(item),slot,out)) and out or nil
    end
    local function ready(identity)
        local ok,valid=pcall(current,identity)
        return ok and valid==true and PlayerPedId()==ped
            and yes(DoesEntityExist(ped)) and not yes(IsEntityDead(ped))
    end
    local function entity(point,name)
        local present,hash=GetCurrentPedWeapon(ped,true,point,true)
        local handle=GetCurrentPedWeaponEntityIndex(ped,point)
        return yes(present) and hash==joaat(name) and type(handle)=='number' and handle>0 and handle or nil
    end
    local function settle(records,identity)
        -- Native inventory activation/holstering can finish on later frames.
        -- Validate the identity on every yield; never accept an unbounded wait.
        local started=GetGameTimer()
        for frame=1,120 do
            if not ready(identity) then return false,'creation_identity_changed' end
            local complete,seen=true,{}
            for _,record in ipairs(records) do
                record.entity=entity(record.point,record.name)
                if not record.entity or seen[record.entity] then complete=false end
                if record.entity then seen[record.entity]=true end
            end
            if complete then return true end
            if GetGameTimer()-started>=1500 then break end
            Wait(0)
        end
        return false,'holster_entities_not_settled'
    end
    local function remove(record)
        if record.guid then
            return yes(Citizen.InvokeNative(0x3E4E811480B3AE79,1,record.guid,1,joaat('REMOVE_REASON_DEFAULT')))
        end
        -- Single creation refused preexisting ownership; do not remove a later
        -- replacement model/entity that no longer belongs to this attempt.
        if yes(DoesEntityExist(ped)) then
            for _,point in ipairs({0,1,2,3,9,10}) do
                if entity(point,record.name)==record.entity then
                    RemoveWeaponFromPed(ped,joaat(record.name)); return true
                end
            end
        end
        return false
    end
    local function clean(records)
        for i=#records,1,-1 do pcall(remove,records[i]) end
    end
    local function empty(item)
        return type(item)=='table' and type(item.nativeWeaponName)=='string'
            and type(item.attachments)=='table' and next(item.attachments)==nil
            and type(item.cosmetics)=='table' and next(item.cosmetics)==nil
            and not yes(HasPedGotWeapon(ped,joaat(item.nativeWeaponName),false))
    end
    local function single(item,ammo,identity)
        if ammo~=0 then return nil,'single_creation_precondition: nonzero_ammo' end
        if not ready(identity) then return nil,'single_creation_precondition: lifecycle_not_ready' end
        if not empty(item) then
            local existing=type(item)=='table' and type(item.nativeWeaponName)=='string'
                and yes(HasPedGotWeapon(ped,joaat(item.nativeWeaponName),false))
            return nil,'single_creation_precondition: '..(existing and 'preexisting_weapon' or 'unsupported_item_state')
        end
        if not ({[2]=true,[3]=true,[9]=true,[10]=true})[item.point] then
            return nil,'single_creation_precondition: unsupported_point'
        end
        local record={name=item.nativeWeaponName,point=item.point}
        local ok,failure=pcall(function()
            GiveWeaponToPed(ped,joaat(item.nativeWeaponName),0,false,true,item.point,false,
                0.5,1.0,joaat('ADD_REASON_DEFAULT'),true,0.0,false)
            local settled,reason=settle({record},identity)
            assert(settled,reason)
        end)
        if not ok or not record.entity then
            -- Preserve the existing compensation policy; report the swallowed
            -- native/settlement error instead of masking it at the caller.
            RemoveWeaponFromPed(ped,joaat(item.nativeWeaponName))
            return nil,'single_creation_or_settlement_failed: '..tostring(failure or 'missing_entity')
        end
        return record
    end
    local function pair(items,identity)
        if not ready(identity) or #items~=2 or items[1].point~=2 or items[2].point~=3
            or items[1].nativeWeaponName~=items[2].nativeWeaponName
            or not empty(items[1]) or not empty(items[2]) then return nil,'pair_creation_precondition' end
        local character=resolve(nil,'CHARACTER',0xA1212100)
        local parent=character and resolve(character,'CARRIED_WEAPONS',joaat('SLOTID_CARRIED_WEAPONS'))
        if not parent then return nil,'carried_weapon_inventory_unavailable' end
        local owned={}
        local ok,reason=pcall(function()
            for index=1,2 do
                local out=buffer()
                assert(yes(Citizen.InvokeNative(0xCB5D11F9508A928D,1,out,parent,joaat(items[index].nativeWeaponName),
                    joaat('SLOTID_WEAPON_0'),1,joaat('ADD_REASON_DEFAULT'))),'copy insert failed')
                local record={guid=out,slot=0,name=items[index].nativeWeaponName,point=items[index].point}
                owned[#owned+1]=record
                assert(yes(Citizen.InvokeNative(0x734311E2852760D0,1,out,true)),'copy equip failed')
                Citizen.InvokeNative(0x12FB95FE3D579238,ped,out,true,0,false,false)
                if index==1 then
                    local moved=buffer()
                    assert(yes(Citizen.InvokeNative(0xDCCAA7C3BFD88862,1,out,parent,joaat('SLOTID_WEAPON_1'),1,moved)),'copy move failed')
                    record.guid,record.slot=moved,1
                end
            end
            for _,index in ipairs({2,1}) do
                local record=owned[index]
                Citizen.InvokeNative(0x12FB95FE3D579238,ped,record.guid,true,record.slot,false,false)
            end
            Citizen.InvokeNative(0x94A3C1B804D291EC,ped,true,true,true,true)
            -- The original proof completes GUID activation by selecting unarmed.
            -- Request that transition BEFORE waiting for carried points2/3;
            -- otherwise the copies can remain at hand points0/1 throughout.
            SetCurrentPedWeapon(ped,joaat('WEAPON_UNARMED'),true,0,false,false)
            local settled,failure=settle(owned,identity)
            assert(settled,failure)
        end)
        if not ok then clean(owned); return nil,tostring(reason) end
        return owned
    end
    return {current=ready,prepareDual=function(identity) return ready(identity) and prepareDual(ped)==true end,
        createSingle=single,createPair=pair,remove=remove,finish=function(records,identity)
            if not ready(identity) then return false end
            SetCurrentPedWeapon(ped,joaat('WEAPON_UNARMED'),true,0,false,false)
            for _,record in ipairs(records) do
                if entity(record.point,record.name)~=record.entity then return false end
            end
            return true
        end}
end

-- Lifecycle-bound factory only. Never assumes entitlement/appearance ownership;
-- caller supplies both preparation and cleanup for the same scoped setup.
function WeaponCharacterAmmoCreationNative.Scoped(ped,identity,prepareDual,cleanupDual)
    if type(identity)~='table' or type(identity.characterId)~='string'
        or type(identity.sessionId)~='string' or type(identity.epoch)~='string'
        or identity.characterId=='' or identity.sessionId=='' or identity.epoch==''
        or type(prepareDual)~='function' or type(cleanupDual)~='function' then
        return nil,'invalid_scoped_creation'
    end
    local expected={characterId=identity.characterId,sessionId=identity.sessionId,epoch=identity.epoch}
    local function current(check)
        if Config.CharacterAmmunitionEnabled~=true or Config.CharacterAmmoTransportEnabled~=true
            or type(check)~='table' then return false end
        for key,value in pairs(expected) do if check[key]~=value then return false end end
        local context=WeaponCharacterAmmoWorldContext
        if type(context)~='table' then return false end
        local called,result=pcall(context.Read)
        local value=called and type(result)=='table' and result.ok==true and result.value
        return type(value)=='table' and value.characterId==expected.characterId
            and value.sessionId==expected.sessionId and value.ped==ped and PlayerPedId()==ped
    end
    if not current(expected) then return nil,'scoped_creation_world_not_ready' end
    local adapter=WeaponCharacterAmmoCreationNative.New(ped,current,prepareDual)
    adapter.cleanupSetup=function()
        if not current(expected) then return nil,'scoped_cleanup_world_changed' end
        return cleanupDual()
    end
    return adapter
end
