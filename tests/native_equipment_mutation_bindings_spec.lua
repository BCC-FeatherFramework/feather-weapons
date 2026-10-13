local commands,events,registered={},{},{}
Config={DevMode=true,NativeAlphaRuntime=true,CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true,NativeAlphaCharacterId='Jane'}
RegisterCommand=function(name,fn) commands[name]=fn end
RegisterNetEvent=function(name,fn) events[name]=fn end
AddEventHandler=function(name,fn) events[name]=fn end
SetTimeout=function() end
GetGameTimer=function() return 10 end
GetResourceState=function() return 'stopped' end
local id={characterId='Jane',sessionId='s',epoch='e1'}
local state={phase='active',identity=id}
local assigned=true
local writes,starts=0,0
local request
local replies={}
TriggerClientEvent=function(name,target,value,scope,result)
 assert(target==1)
 if name=='feather-weapons:client:native-equipment-result' then replies[#replies+1]={id=value,scope=scope,result=result}
 else request=value end
end
CoreAdapter={ResolveSession=function() return {ok=true,value={characterId='Jane',sessionId='s'}} end,
 IsSessionCurrent=function(target,s,c) return target==1 and s=='s' and c=='Jane' end}
WeaponCharacterAmmoService={ValidateLoadout=function() return {ok=true} end}
WeaponDefinitionCatalog={}
WeaponCharacterAmmoPolicy={Build=function() return {} end}
WeaponCharacterAmmoMaterialization={Build=function(rows)
 if rows.offhand and not rows.primary then return nil,'primary_required_for_offhand' end
 if rows.primary and rows.primary.itemName~='cattleman' then return nil,'unregistered_firearm' end
 return {items=rows}
end,Validate=function() return true end}
local candidate={id=112,revision=1,itemName='cattleman',metadata={}}
GetInvokingResource=function() return 'feather-inventory' end
exports=setmetatable({['feather-inventory']={
 ReadNativeEquipmentTransition=function(_,context,item)
  assert(context.actorSource==1)
  return {ok=true,value={characterId='Jane',expected=assigned and {weapon={itemId=112,revision=1}} or {},
   equipment=assigned and {primary=candidate} or {},candidate=item and candidate or nil}}
 end,
 CommitNativeEquipmentTransition=function(_,context,spec)
  assert(state.phase=='released' and registered.ValidateNativeEquipmentCommit(context,spec))
  assert(spec.slot=='weapon' and spec.characterId=='Jane')
  if spec.action=='unequip' then assert(spec.expected.weapon.itemId==112); assigned=false
  else assert(not next(spec.expected) and spec.itemRevision==1); assigned=true end
  writes=writes+1; return {ok=true,value={slot='weapon'}}
 end
}},{__call=function(_,name,fn) registered[name]=fn end})
WeaponCharacterAmmoDispatcher={Status=function() return state end,Start=function()
 starts=starts+1
 local bundle={}; WeaponNativeEquipmentBindings.Attach(1,bundle)
 assert(bundle.equipmentTransition.ticket==request.ticket)
 id={characterId='Jane',sessionId='s',epoch='e'..(starts+1)}
 state={phase='restoring',identity=id}; return {ok=true,value=id}
end}
dofile('server/services/native_equipment_transition.lua')
commands.WeaponNativeEquipmentChange(0,{'1','unequip','invalid'})
assert(not request and writes==0)
commands.WeaponNativeEquipmentChange(0,{'1','unequip','weapon'})
assert(request and writes==0)
local function finish()
 local old=request.identity
 state={phase='released',identity=old}; source=1
 events['feather-weapons:server:native-equipment-released'](request.ticket,old,true)
 assert(state.phase=='restoring')
 state={phase='active',identity=id}
 events['feather-weapons:server:native-equipment-restored'](request.ticket,id)
 assert(not registered.ValidateNativeEquipmentCommit({actorSource=1},{}))
end
finish(); assert(writes==1 and not assigned)
commands.WeaponNativeEquipmentChange(0,{'1','equip','weapon','112'})
assert(writes==1); finish(); assert(writes==2 and assigned and starts==2)
commands.WeaponNativeEquipmentChange(0,{'1','equip','weapon','112'})
assert(writes==2 and starts==2,'already equipped refused without release/write')
source=1
events['feather-weapons:server:native-equipment-ui']('preview','options',{itemId=112,scope=id})
assert(replies[#replies].result.ok and replies[#replies].result.value.options[1].action=='unequip')
local old=id
events['feather-weapons:server:native-equipment-ui']('change','change',{itemId=112,action='unequip',slot='weapon',scope=id})
assert(writes==2,'UI cannot write before acknowledged release')
events['core.session.left.v1']({source=1,sessionId='older-session'})
assert(replies[#replies].id=='preview','old-session event must not clear newer pending UI request')
events['feather-weapons:server:native-equipment-ui']('overlap','change',{itemId=112,action='unequip',slot='weapon',scope=id})
finish(); assert(writes==3 and not assigned)
assert(replies[#replies].id=='change' and replies[#replies].result.ok)
events['feather-weapons:server:native-equipment-ui']('stale','change',{itemId=112,action='equip',slot='weapon',scope=old})
assert(not replies[#replies].result.ok and writes==3)
print('Native equipment mutation bindings PASS (console policy/retry, server snapshot, release-before-CAS, unequip/equip rebuild)')
