local commands,output={},{}
Config={DevMode=true,CharacterAmmunitionEnabled=false,CharacterAmmoTransportEnabled=false}
RegisterCommand=function(name,fn) commands[name]=fn end
local proof='stopped'
GetResourceState=function() return proof end
local approved='6a2fd060-c46f-11f1-9ae2-e0d55eaa2deb'
local character=approved
local current=true
CoreAdapter={ResolveSession=function() return {ok=true,value={characterId=character,sessionId='s'}} end,
    IsSessionCurrent=function() return current end}
local issued,receipt=0,nil
IssuanceService={Issue=function(context,request,resource)
    assert(context.characterId==approved and request.characterId==approved and resource=='feather-weapons')
    assert(request.definitionId=='revolver_cattleman' and request.requestId=='native-test-jane-cattleman-v1')
    if receipt then return {ok=true,value={itemInstanceId=99,replayed=true}} end
    issued=issued+1; receipt=true; return {ok=true,value={itemInstanceId=99}}
end}
local originalPrint=print
print=function(value) output[#output+1]=value end
dofile('server/services/commands.lua')
local run=commands.WeaponNativeTestPrepare
run(1,{'1',approved}); assert(issued==0 and #output==0,'console only')
run(0,{'1','original'}); assert(issued==0)
character='e5e9955d-c29e-11f1-9ae2-e0d55eaa2deb'
run(0,{'1',approved}); assert(issued==0,'source reuse cannot target original character')
character=approved; current=false; run(0,{'1',approved}); assert(issued==0)
current=true; proof='started'; run(0,{'1',approved}); assert(issued==0)
proof='stopped'; Config.CharacterAmmoTransportEnabled=true; run(0,{'1',approved}); assert(issued==0)
Config.CharacterAmmoTransportEnabled=false
run(0,{'1',approved}); run(0,{'1',approved})
assert(issued==1 and output[#output]:find('replayed=true',1,true),'stable issuance request reused')
Config.DevMode=false; run(0,{'1',approved}); assert(issued==1)
print=originalPrint
print('dedicated test prepare PASS (console/dev gates, exact UUID, current session, no proof/native overlap, stable issuance request; mocked issuance)')
