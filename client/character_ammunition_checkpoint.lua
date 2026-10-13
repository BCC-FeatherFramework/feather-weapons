-- Dormant Character-compatible voluntary checkpoint. No registration/exports.
-- Independent host identity, not the supplied checkpoint context, is authority.
WeaponCharacterAmmoCheckpoint={}
function WeaponCharacterAmmoCheckpoint.New(receiver,api)
    local running=false
    local T={}
    local function err(code) return {ok=false,error={code=code},code=code} end
    function T.Run(context)
        if api.caller()~='feather-character' then return err('checkpoint_caller_denied') end
        if running then return err('checkpoint_in_flight') end
        if type(context)~='table' or (context.reason~='logout' and context.reason~='save_quit') then
            return err('invalid_checkpoint_context')
        end
        local identity=api.identity()
        if type(identity)~='table' or identity.characterId~=context.characterId
            or type(identity.sessionId)~='string' or identity.sessionId=='' then
            return err('checkpoint_identity_mismatch')
        end
        -- Reserve before the first yield. Even after successful cleanup, this
        -- retiring receiver cannot accept another loadout during logout RPC.
        running=true; receiver.Quiesce()
        local ok,result=pcall(function()
            local release=WeaponCharacterAmmoRelease.New(receiver,api)
            local requested,reason=release.Request(10000)
            if not requested then return err(reason) end
            while true do
                local current=api.identity()
                if type(current)~='table' or current.characterId~=identity.characterId
                    or current.sessionId~=identity.sessionId then
                    receiver.Suspend('checkpoint_world_changed'); return err('checkpoint_world_changed')
                end
                local done,why=release.Step()
                if done then
                    if receiver.Status().phase~='closed' then return err('checkpoint_not_released') end
                    return {ok=true,value={released=true,characterId=identity.characterId,sessionId=identity.sessionId}}
                end
                if release.Status().phase=='failed' then return err(why) end
                api.wait(0)
            end
        end)
        running=false
        if not ok then receiver.Suspend('checkpoint_failed'); return err('checkpoint_failed') end
        return result
    end
    return T
end
