Config={CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true,DevMode=true,NativeAlphaRuntime=true,
 NativeAlphaLifecycleWearEnabled=true,NativeAlphaCharacterId='Jane',AmmunitionPools={enabled=false},Escrow={maxTotal=200}}
dofile('shared/constants.lua'); dofile('shared/definitions/ammunition.lua'); dofile('shared/definitions/weapons.lua')
dofile('shared/validation.lua'); dofile('shared/character_ammunition_item.lua'); dofile('shared/character_maintenance.lua')
dofile('shared/character_lifecycle_wear.lua'); dofile('shared/character_ammunition.lua'); dofile('shared/character_ammunition_runtime.lua')
dofile('shared/character_ammunition_loadout_lease.lua')
local function copy(v) if type(v)~='table' then return v end; local out={}; for k,x in pairs(v) do out[k]=copy(x) end; return out end
local definition=WeaponDefinitionCatalog.weapons.revolver_cattleman
local original={schemaVersion=2,weaponDefinitionId=definition.id,serialNumber='fixture',condition=90,quality=100,
 maintenance={degradation=0.1,permanentDegradation=0.1,damage=0.1,dirt=0.4,soot=0},
 ammo={ownership='character',type=definition.ammunitionType},attachments={},cosmetics={},
 flags={stolen=false,evidence=false,disabled=false},provenance={}}
WeaponCharacterAmmoCatalog={Build=function() return {limits={ammo=10}} end}
WeaponCharacterAmmoMaterialization={Build=function(rows,_,_,identity)
 local row=rows.primary
 return {identity=copy(identity),items={{itemInstanceId=row.id,itemRevision=row.revision,metadata=copy(row.metadata)}}}
end}
local registered,handlers={},{}
exports=setmetatable({},{__call=function(_,name,fn) registered[name]=fn end})
GetInvokingResource=function() return 'feather-inventory' end
GetGameTimer=function() return 1 end
AddEventHandler=function(name,fn) handlers[name]=fn end
CoreAdapter={IsSessionCurrent=function() return true end,ResolveSession=function() return {ok=true,value={characterId='Jane',sessionId='s'}} end}
local medical={characterId='Jane',sessionId='s',lifeState='dead',revision=7,episodeId='death'}
local item,ledger,writes,mode
local inventory={}
exports['feather-inventory']=inventory
exports['feather-medical']={ReadNativeWeaponCondition=function() return {ok=true,value=copy(medical)} end}
local function equipment() return {primary=copy(item)} end
inventory.GetCharacterFirearmRuntimeSnapshot=function() return {ok=true,value={characterId='Jane',revision=ledger.revision,pools=copy(ledger.pools),equipment=equipment()}} end
inventory.ReadNativeEquipmentTransition=function() return {ok=true,value={characterId='Jane',equipment=equipment(),expected={weapon={itemId=128,revision=item.revision}}}} end
inventory.ObserveCharacterAmmunition=function(_,context,spec)
 assert(registered.ValidateCharacterAmmoRuntimeOperation(context,'observe',spec))
 local change=spec.finalWear.lifecycleWear[1]
 assert(change and change.itemId==128 and change.after.maintenance.dirt==0.5)
 local guard={operation='metadata_write',resource='feather-weapons',actorSource=1,runtimeEpoch=context.runtimeEpoch,
  runtimeTicket=context.runtimeTicket,expectedRevision=4,metadata=copy(change.after)}
 guard.metadata.maintenance.damage=0.100000000000001
 assert(WeaponCharacterAmmoService.IsDeathWearWriteAuthorized(128,guard),'JSON decimal noise permitted only for wear')
 guard.metadata.serialNumber='forged'; assert(not WeaponCharacterAmmoService.IsDeathWearWriteAuthorized(128,guard)); guard.metadata=copy(change.after)
 guard.operation='move'; assert(not WeaponCharacterAmmoService.IsDeathWearWriteAuthorized(128,guard)); guard.operation='metadata_write'
 guard.runtimeTicket='foreign'; assert(not WeaponCharacterAmmoService.IsDeathWearWriteAuthorized(128,guard)); guard.runtimeTicket=context.runtimeTicket
 assert(not WeaponCharacterAmmoService.IsDeathWearWriteAuthorized(112,guard))
 if mode=='medical-change' then medical.revision=8; assert(not registered.ValidateCharacterAmmoRuntimeOperation(context,'observe',spec)); return {ok=false} end
 if mode=='cas-fail' then return {ok=false} end
 item.metadata=copy(change.after); item.revision=5; writes=writes+1
 local changed=spec.pools.ammo~=ledger.pools.ammo
 ledger={revision=ledger.revision+(changed and 1 or 0),pools=copy(spec.pools)}
 return {ok=true,value={characterId='Jane',revision=ledger.revision,pools=copy(ledger.pools)}}
end
dofile('server/services/character_ammunition_runtime.lua')
local S=WeaponCharacterAmmoService
local function reset(funded)
 S.Revoke(1); medical.lifeState='dead'; medical.revision=7
 item={id=128,revision=4,itemName=definition.itemName,metadata=copy(original)}
 ledger={revision=25,pools={ammo=funded and 1 or 0}}; writes=0; mode=nil
 local bundle=assert(S.OpenLoadout(1,WeaponDefinitionCatalog,{}).value)
 local report=copy(bundle.runtime)
 assert(S.ConfirmRestore(1,report).ok)
 report.deathWear={epoch=report.epoch,medicalRevision=7,items={{itemInstanceId=128,itemRevision=4,
  maintenance={degradation=0.1,permanentDegradation=0.1,damage=0.1,dirt=0.5,soot=0}}}}
 return report
end
local report=reset(false)
local result=S.CheckpointAndSeal(1,report)
assert(result.ok and result.value.phase=='sealed' and result.value.revision==25 and item.revision==5 and writes==1)
assert(S.IsNativeItemBound(128),'death seal retains owned native hold until doctor cleanup')
assert(not S.CheckpointAndSeal(1,report).ok and writes==1,'duplicate cannot repeat wear CAS')
report=reset(true); report.pools.ammo=0
result=S.CheckpointAndSeal(1,report)
assert(result.ok and result.value.revision==26 and item.revision==5 and writes==1,'funded final reduction and wear share operation')
report=reset(false); report.deathWear=nil; assert(not S.CheckpointAndSeal(1,report).ok and writes==0)
report=reset(false); report.deathWear.items[1].itemRevision=3; assert(not S.CheckpointAndSeal(1,report).ok and writes==0)
report=reset(false); report.deathWear.items[1].itemInstanceId=112; assert(not S.CheckpointAndSeal(1,report).ok and writes==0)
report=reset(false); medical.lifeState='alive'; assert(not S.CheckpointAndSeal(1,report).ok and writes==0)
report=reset(false); mode='medical-change'; assert(not S.CheckpointAndSeal(1,report).ok and item.revision==4 and writes==0)
report=reset(false); mode='cas-fail'; assert(not S.CheckpointAndSeal(1,report).ok and item.revision==4 and writes==0)
print('Death wear service PASS (actual reserved runtime/lease/plan, zero/funded belt, dead revision, exact metadata guard, foreign/stale/duplicate/CAS failures)')
