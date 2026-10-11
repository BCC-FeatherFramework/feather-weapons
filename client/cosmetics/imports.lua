-- Providers and helpers used by the weapon cosmetics client (client/cosmetics).
-- Everything there goes through these instead of calling provider exports
-- directly.
CosmeticsProviders = {
    Menu = exports['feather-menu-v2'],
    Toolkit = exports['feather-toolkit']
}

-- Feather Core keeps one translation table per locale for every resource, so
-- cosmetics keys are registered with this prefix to stay clear of other
-- resources' keys. Callers keep using the short keys.
local LOCALE_PREFIX = 'cosmetics_'

CosmeticsLocale = {
    register = function(locale, translations)
        local prefixed = {}
        for key, value in pairs(translations) do prefixed[LOCALE_PREFIX .. key] = value end
        local result = exports['feather-core']:RegisterLocale(locale, prefixed)
        if type(result) ~= 'table' or result.ok ~= true then
            error(('[feather-weapons cosmetics] locale registration failed for %s: %s'):format(
                tostring(locale), tostring(type(result) == 'table' and result.code or 'invalid_result')))
        end
        return result
    end
}

-- Returns the translation, or the short key itself when there is none.
function CosmeticsT(key, ...)
    local prefixed = LOCALE_PREFIX .. tostring(key)
    local result = exports['feather-core']:TranslateLocale(0, prefixed, ...)
    if type(result) == 'table' and result.ok == true and type(result.value) == 'string'
        and result.value ~= prefixed then
        return result.value
    end
    return tostring(key)
end

function CosmeticsNotify(message)
    local called, result = pcall(function()
        return exports['feather-notify']:ShowNotification({
            style = 'right',
            message = message,
            duration = 3500
        })
    end)
    if not called or type(result) ~= 'table' or result.ok ~= true then
        print(('[feather-weapons cosmetics] notification failed code=%s'):format(
            tostring(called and type(result) == 'table' and result.code or 'provider_unavailable')))
    end
end

-- Calls one of the cosmetics server RPCs and always returns a result table
-- shaped { ok, value } or { ok = false, code }. Must run in a thread.
function CosmeticsCall(route, params)
    local result, rpcError = exports['feather-core']:CallRPCAsync(route, params or {}, nil, nil)
    if type(result) == 'table' and type(result.ok) == 'boolean' then return result end
    return { ok = false, code = type(rpcError) == 'table' and rpcError.code or 'unavailable' }
end

function CosmeticsNotifyFailure(result)
    local key = 'error_' .. tostring(type(result) == 'table' and result.code or 'generic')
    local message = CosmeticsT(key)
    CosmeticsNotify(message ~= key and message or CosmeticsT('error_generic'))
end

function CosmeticsDebug(...)
    if Config.DevMode then print('[feather-weapons cosmetics]', ...) end
end
