-- Native weapon inspection: RedM's hold animation, weapon stats card and clean
-- prompt. Cleaning runs the normal repair transaction, so the material check
-- and maintenance reset stay on the server; the client only plays the scene.
local inspecting = false
local activeCard = nil
local INSPECT_STATE_MACHINE = -813354801
local INSPECT_HUD_CONTEXT = -1847602092
local CLEAN_PROMPT = 'GENERIC_WEAPON_CLEAN_PROMPT_AVAILABLE'

local function NativeTrue(value)
    return value == true or value == 1
end

local function Notify(message)
    FeatherWeaponsClient.Notify(message)
end

local function NeedsCleaning(object)
    local permanent = GetWeaponPermanentDegradation(object)
    return GetWeaponDegradation(object) - permanent > 0.005
        or GetWeaponDamage(object) - permanent > 0.005
        or GetWeaponDirt(object) > 0.005
        or GetWeaponSoot(object) > 0.005
end

local function StatsGuid(nativeWeaponName)
    return FeatherGuidWeapons.ResolveCarried(nativeWeaponName) or FeatherGuidWeapons.NewBuffer(8 * 13)
end

-- Rusted weapons show their "worn" name variant on the card.
local function ItemLabel(nativeWeaponName, object)
    local permanent = GetWeaponPermanentDegradation(object)
    if permanent > 0.0 then
        return joaat(GetWeaponNameWithPermanentDegradation(joaat(nativeWeaponName), permanent))
    end
    return joaat(nativeWeaponName)
end

-- Game text for clean / worn-to-floor / needs-cleaning.
local function TipText(object)
    local degradation = GetWeaponDegradation(object)
    local permanent = GetWeaponPermanentDegradation(object)
    if degradation <= 0.0 then return GetStringFromHashKey(1803343570) end
    if permanent > 0.0 and math.abs(degradation - permanent) < 0.005 then
        return GetStringFromHashKey(-1933427003)
    end
    return GetStringFromHashKey(-54957657)
end

local function OpenCard(nativeWeaponName, object)
    local ped = PlayerPedId()
    local flowblock = UiflowblockRequest(joaat('PM_FLOW_WEAPON_INSPECT'))
    local card = {}
    card.container = DatabindingAddDataContainerFromPath('', 'ItemInspection')
    card.visible = DatabindingAddDataBool(card.container, 'Visible', false)
    card.stats = Citizen.InvokeNative(0x46DB71883EE9D5AF, card.container, 'stats', StatsGuid(nativeWeaponName), ped)
    card.itemLabel = DatabindingAddDataHash(card.container, 'itemLabel', ItemLabel(nativeWeaponName, object))
    card.tipText = DatabindingAddDataString(card.container, 'tipText', TipText(object))

    EnableHudContext(INSPECT_HUD_CONTEXT)
    local deadline = GetGameTimer() + 5000
    while not NativeTrue(UiflowblockIsLoaded(flowblock)) and GetGameTimer() < deadline do Wait(0) end
    UiflowblockEnter(flowblock, 0)
    if not NativeTrue(UiStateMachineExists(INSPECT_STATE_MACHINE)) then
        UiStateMachineCreate(INSPECT_STATE_MACHINE, flowblock)
    end
    return card
end

local function RefreshCard(card, nativeWeaponName, object)
    Citizen.InvokeNative(0x951847CEF3D829FF, card.stats, StatsGuid(nativeWeaponName), PlayerPedId())
    DatabindingWriteDataHashString(card.itemLabel, ItemLabel(nativeWeaponName, object))
    DatabindingWriteDataString(card.tipText, TipText(object))
end

local function CloseCard(card)
    StopAudioSceneset('Inspect_Item_Scenes')
    UiStateMachineDestroy(INSPECT_STATE_MACHINE)
    DatabindingRemoveDataEntry(card.container)
    DisableHudContext(INSPECT_HUD_CONTEXT)
end

-- feather-world hides a prompt type and blocks some controls every frame; the
-- native inspect needs both for its own prompts (Put Away, Clean), so that is
-- paused while inspecting, the same way VORP's inspect relies on them.
local function PauseWorldSuppression(paused)
    pcall(function() exports['feather-world']:SetInputSuppressionPaused(paused) end)
end

local function IsState(current, longarm, shortarm)
    return current == joaat(longarm) or current == joaat(shortarm)
end

local function Inspect()
    if inspecting then return end
    local ped = PlayerPedId()
    if IsEntityDead(ped) or IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false) then return end

    local slot, state = FeatherWeaponsClient.HeldWeapon()
    if not slot then
        Notify('Hold a gun to inspect it.')
        return
    end
    local nativeWeaponName = state.nativeWeaponName
    local weaponHash = joaat(nativeWeaponName)
    if not NativeTrue(IsWeaponAGun(weaponHash)) then
        Notify('Only guns can be inspected.')
        return
    end
    local object = GetPedWeaponObject(ped, true)
    if not object or object == 0 or not DoesEntityExist(object) then return end

    inspecting = true
    local interaction = NativeTrue(IsWeaponTwoHanded(weaponHash)) and 'LONGARM_HOLD_ENTER' or 'SHORTARM_HOLD_ENTER'
    TaskItemInteraction_2(ped, weaponHash, object, 0, joaat(interaction), 0, 0, 0.0)
    local deadline = GetGameTimer() + 3000
    while not NativeTrue(IsPedRunningInspectionTask(ped)) do
        if GetGameTimer() > deadline then
            inspecting = false
            return
        end
        Wait(0)
    end

    PauseWorldSuppression(true)
    SetPedBlackboardBool(ped, CLEAN_PROMPT, NeedsCleaning(object), -1)
    local card = OpenCard(nativeWeaponName, object)
    activeCard = card
    StartAudioSceneset('weapon', 'Inspect_Item_Scenes')

    -- approved: nil while the server decides, then true/false.
    local cleaning, approved, refreshAt = false, nil, nil
    while true do
        Wait(0)
        if IsEntityDead(ped) or not NativeTrue(IsPedRunningInspectionTask(ped)) then break end
        local current = GetItemInteractionState(ped)
        if IsState(current, 'LONGARM_HOLD_EXIT', 'SHORTARM_HOLD_EXIT') then break end

        DisableControlAction(0, joaat('INPUT_NEXT_CAMERA'), false)
        if not NativeTrue(DatabindingReadDataBool(card.visible))
            and IsState(current, 'LONGARM_HOLD', 'SHORTARM_HOLD') then
            DatabindingWriteDataBool(card.visible, true)
        end

        if not cleaning and IsState(current, 'LONGARM_CLEAN_ENTER', 'SHORTARM_CLEAN_ENTER') then
            cleaning, approved = true, nil
            SetPedBlackboardBool(ped, CLEAN_PROMPT, false, -1)
            FeatherWeaponsClient.Clean(slot, function(result)
                approved = result and result.ok == true
                if approved then
                    -- Repair schedules the native maintenance restore; read
                    -- the card back once it has landed.
                    refreshAt = GetGameTimer() + 300
                else
                    local failure = result and result.error
                    Notify(failure and failure.message or 'Unable to clean this weapon.')
                end
            end)
        end

        if cleaning and approved == false then
            ClearPedTasks(ped)
            break
        end

        if cleaning and IsState(current, 'LONGARM_CLEAN_EXIT', 'SHORTARM_CLEAN_EXIT') then
            cleaning = false
            if approved then refreshAt = GetGameTimer() end
        end

        if refreshAt and GetGameTimer() >= refreshAt then
            refreshAt = nil
            RefreshCard(card, nativeWeaponName, object)
        end
    end

    SetPedBlackboardBool(ped, CLEAN_PROMPT, false, -1)
    PauseWorldSuppression(false)
    CloseCard(card)
    activeCard = nil
    inspecting = false
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() or not activeCard then return end
    CloseCard(activeCard)
    ClearPedTasks(PlayerPedId())
end)

if Config.Controls and Config.Controls.inspect and Config.Controls.inspect.enabled then
    local inspectControl = Config.Controls.inspect
    -- Command only (no key binding): /weaponinspect by default.
    RegisterCommand(inspectControl.command, function() CreateThread(Inspect) end, false)
end
