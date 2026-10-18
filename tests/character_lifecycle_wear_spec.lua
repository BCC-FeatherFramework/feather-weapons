Config={AmmunitionPools={enabled=false},Escrow={maxTotal=200}}
dofile('shared/constants.lua'); dofile('shared/definitions/ammunition.lua'); dofile('shared/definitions/weapons.lua')
dofile('shared/validation.lua'); dofile('shared/character_ammunition_item.lua'); dofile('shared/character_maintenance.lua')
dofile('shared/character_lifecycle_wear.lua')
local definition=WeaponDefinitionCatalog.weapons.revolver_cattleman
local metadata={schemaVersion=2,weaponDefinitionId=definition.id,serialNumber='serial',condition=90,quality=100,
 maintenance={degradation=0.1,permanentDegradation=0.1,damage=0.1,dirt=0,soot=0},
 ammo={ownership='character',type=definition.ammunitionType},attachments={},cosmetics={},
 flags={stolen=false,evidence=false,disabled=false},provenance={}}
local rows={primary={id=128,revision=2,itemName=definition.itemName,metadata=metadata}}
local report={epoch='e',items={{itemInstanceId=128,itemRevision=2,
 maintenance={degradation=0.10000000149,permanentDegradation=0.10000000149,damage=0.1,dirt=0,soot=0}}}}
assert(#WeaponCharacterLifecycleWear.Plan(rows,report,WeaponDefinitionCatalog,'e')==0)
report.items[1].maintenance.dirt=0.3
local changes=assert(WeaponCharacterLifecycleWear.Plan(rows,report,WeaponDefinitionCatalog,'e'))
assert(#changes==1 and changes[1].after.maintenance.dirt==0.3 and metadata.maintenance.dirt==0)
assert(not WeaponCharacterLifecycleWear.Plan(rows,report,WeaponDefinitionCatalog,'old'))
report.items[1].itemRevision=1; assert(not WeaponCharacterLifecycleWear.Plan(rows,report,WeaponDefinitionCatalog,'e'))
report.items[1].itemRevision=2; report.items[2]=report.items[1]
assert(not WeaponCharacterLifecycleWear.Plan(rows,report,WeaponDefinitionCatalog,'e'))
report.items={}; assert(not WeaponCharacterLifecycleWear.Plan(rows,report,WeaponDefinitionCatalog,'e'))
assert(#WeaponCharacterLifecycleWear.Plan({},report,WeaponDefinitionCatalog,'e')==0)
print('character_lifecycle_wear_spec PASS (complete exact copy/revision snapshot, monotonic wear/noise, missing/duplicate/stale rejection)')
