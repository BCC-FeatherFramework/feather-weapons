local calls,threads={},{ }
RegisterCommand=function() end
CreateThread=function(fn) threads[#threads+1]=coroutine.create(fn) end
json={encode=function() return '' end}
local function result() return {ok=true,value={}} end
CoreAdapter={CheckCapabilities=result,CheckCharacterCapabilities=result}
DefinitionRegistry={Start=function() calls[#calls+1]='definitions'; return result() end}
WeaponCharacterAmmoInventoryProvider={Install=function() calls[#calls+1]='native-guards'; return true end}
WeaponProvenanceService={Start=function() error('legacy provenance must not start') end}
InstallFeatherInventoryProvider=function() error('legacy usable provider must not install') end
ReconciliationService={BootstrapActiveSessions=function() error('legacy restoration must not start') end}
local function server()
    threads={}; dofile('server/main.lua'); return coroutine.resume(threads[1])
end
Config={DevMode=true,CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true}
assert(not server() and #calls==0,'native flags alone are not an alpha startup authorization')
Config.NativeAlphaRuntime=true; Config.NativeAlphaCharacterId='Jane'
assert(server() and #calls==2 and calls[2]=='native-guards')
Config.DevMode=false; assert(not server() and #calls==2); Config.DevMode=true
local now,readied,starts,binds=0,false,0,0
GetGameTimer=function() return now end
Wait=function() coroutine.yield() end
WeaponCharacterAmmoWorldContext={Read=function()
    return readied and {ok=true,value={characterId='Jane'}} or {ok=false}
end}
WeaponCharacterAmmoNativeOwner={New=function() return {Start=function() starts=starts+1; return true end,
    BindReadiness=function() binds=binds+1; return true end} end}
threads={}; dofile('client/character_ammunition_startup.lua')
assert(coroutine.resume(threads[1]) and starts==0)
readied=true; assert(coroutine.resume(threads[1]) and starts==1 and binds==1)
assert(coroutine.status(threads[1])=='dead')
threads={}; Config.CharacterAmmoTransportEnabled=false
dofile('client/character_ammunition_startup.lua'); assert(coroutine.resume(threads[1]) and starts==1)
Config.CharacterAmmoTransportEnabled=true; readied=false
threads={}; dofile('client/character_ammunition_startup.lua'); assert(coroutine.resume(threads[1]))
Config.NativeAlphaRuntime=false; assert(coroutine.resume(threads[1]) and starts==1)
print('character_ammunition_startup_spec PASS (explicit alpha gates, native-only provider, alive wait/shutdown)')
