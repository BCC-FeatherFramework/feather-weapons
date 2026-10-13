exports=function() end
Config={DevMode=false,NativeAlphaRuntime=true,CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true,NativeAlphaCharacterId='Jane'}
local events,commands,sent,timers={},{},{},{}
RegisterNetEvent=function(name,fn) events[name]=fn end
RegisterCommand=function(name,fn) commands[name]=fn end
AddEventHandler=function(name,fn) events[name]=fn end
SetTimeout=function(_,fn) timers[#timers+1]=fn end
GetResourceState=function() return 'stopped' end
GetGameTimer=function() return 10 end
TriggerClientEvent=function(name,target,request) sent[#sent+1]={name=name,target=target,request=request} end
local old={characterId='Jane',sessionId='s',epoch='old'}
local new={characterId='Jane',sessionId='s',epoch='new'}
local state={phase='active',identity=old}
local starts=0
CoreAdapter={ResolveSession=function() return {ok=true,value={characterId='Jane',sessionId='s'}} end,
 IsSessionCurrent=function(source,sid,char) return source==5 and sid=='s' and char=='Jane' end}
WeaponCharacterAmmoDispatcher={Status=function() return state end,Start=function(target)
 assert(target==5 and state.phase=='released')
 starts=starts+1
 local bundle={runtime=new}
 WeaponNativeEquipmentBindings.Attach(target,bundle)
 assert(bundle.equipmentTransition.ticket==sent[1].request.ticket and bundle.equipmentTransition.oldEpoch=='old')
 state={phase='restoring',identity=new}
 return {ok=true,value=new}
end}
local originalPrint=print
local output={}
print=function(v) output[#output+1]=v end
dofile('server/services/native_equipment_transition.lua')
commands.WeaponNativeEquipmentDryRun(0,{'5'}); assert(#sent==0)
Config.DevMode=true
commands.WeaponNativeEquipmentDryRun(1,{'5'}); assert(#sent==0)
commands.WeaponNativeEquipmentDryRun(0,{'5'}); assert(#sent==1 and starts==0)
local ticket=sent[1].request.ticket
source=7; events['feather-weapons:server:native-equipment-released'](ticket,old,true); assert(starts==0)
source=5
state={phase='released',identity=old}
events['feather-weapons:server:native-equipment-released'](ticket,old,true)
assert(starts==1)
events['feather-weapons:server:native-equipment-released'](ticket,old,true); assert(starts==1)
state={phase='active',identity=new}
events['feather-weapons:server:native-equipment-restored'](ticket,new)
assert(output[#output]:find('PASS final seal/owned cleanup/server release',1,true))
timers[1]()
print=originalPrint
print('Native equipment dry-run bindings PASS (console/alpha gates, source binding, authoritative release, fresh dispatch/restore)')
