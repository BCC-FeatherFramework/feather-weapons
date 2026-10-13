local routes={}
Config={CharacterAmmunitionEnabled=false,CharacterAmmoTransportEnabled=false}
WeaponResult={Error=function(code,message) return {ok=false,error={code=code,message=message}} end}
FeatherCore={RPC={Register=function(name,fn) routes[name]=fn end}}
for _,file in ipairs({'equip','ammo','maintenance','repair','attachments'}) do
    dofile('server/services/'..file..'.lua')
end
local methods={
    {EquipService,{'Request','Acknowledge','Restore','Unequip'}},
    {AmmoService,{'NormalizeSharedPools','Escrow','LoadSlot','SwitchSlot','GetInventoryAvailability',
        'Unload','SyncPools','SyncPoolBatch','SyncConsumption','SyncPair'}},
    {MaintenanceService,{'Sync'}},{RepairService,{'Repair','BeginSelection','Select'}},
    {AttachmentService,{'Install','Remove'}},
}
for _,flags in ipairs({{true,false},{false,true},{true,true}}) do
    Config.CharacterAmmunitionEnabled,Config.CharacterAmmoTransportEnabled=table.unpack(flags)
    for _,entry in ipairs(methods) do
        for _,name in ipairs(entry[2]) do
            local result=entry[1][name]() -- Nil args prove quarantine precedes legacy state/DB access.
            assert(result.ok==false and result.error.code=='hybrid_runtime_disabled',name)
        end
    end
    for name,handler in pairs(routes) do
        local response
        handler({},function(value) response=value end,2,{})
        assert(response and response.error.code=='hybrid_runtime_disabled',name)
    end
end
print('character_ammunition_legacy_quarantine_spec PASS (either native flag blocks legacy services/RPC before mutation)')
