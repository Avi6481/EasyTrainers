local Logger = require("Core/Logger")
local Event = require("Core/Event")
local Input = require("Core/Input")
local Language = require("Core/Language")
local JsonHelper = require("Core/JsonHelper")
local Lifecycle = require("Core/Lifecycle")
local SaveGuard = require("Core/SaveGuard")
local Session = require("Core/cp2077-cet-kit/GameSession")
local Cron = require("Core/cp2077-cet-kit/Cron")

local BindingsConfig = require("Config/BindingsConfig")
local NavigationConfig = require("Config/NavigationConfig")
local OptionConfig = require("Config/OptionConfig")
local UIConfig = require("Config/UIConfig")

local State = require("Controls/State")
local Handler = require("Controls/Handler")
local Restrictions = require("Controls/Restrictions")

local Notification = require("UI/Panels/Notification/Notification")
local StatusEffect = require("Utils/StatusEffect")
local StatModifiers = require("Utils/StatModifiers")

local VehicleLoader = require("Utils/DataExtractors/VehicleLoader")
local WeaponLoader = require("Utils/DataExtractors/WeaponLoader")
local PerkLoader = require("Utils/DataExtractors/PerkLoader")
local GeneralLoader = require("Utils/DataExtractors/GeneralLoader")
local TeleportLocations = require("Features/Teleports/TeleportLocations")
local DualWieldAnything = require("Features/Weapons/Abilities/DualWieldAnything")
local Mouse = require("Core/Mouse")

local s_Modules = nil
local s_DeltaTime = 1 / 60
local s_Session = { isLoaded = false, isPaused = false, isBlurred = false, isDead = false }

registerForEvent("onOverlayOpen", function() State.OverlayOpen = true end)
registerForEvent("onOverlayClose", function() State.OverlayOpen = false end)

local function LoadModules()
    if s_Modules or not Session.IsLoaded() then return end

    local ok, result = pcall(function()
        return {
            Self = require("Features/Self"),
            SelfTick = require("Features/Self/Tick"),
            WeaponTick = require("Features/Weapons/Tick"),
            Vehicles = require("Features/Vehicles"),
            AutoTeleport = require("Features/Teleports/AutoTeleport"),
            WorldWeather = require("Features/World/WorldWeather"),
            WorldTime = require("Features/World/WorldTime"),
            WorldEditor = require("Features/WorldEditor"),
            Weapon = require("Utils/Weapon"),
            MainMenu = require("View/MainMenu")
        }
    end)

    if not ok then
        Logger.Log("Module initialization failed: " .. tostring(result))
        return
    end

    s_Modules = result
    Logger.Log("Game modules initialized")
end

local function EndSession()
    if s_Modules then s_Modules.Weapon.ResetInput() end
    Lifecycle.SessionEnd()
    StatusEffect.Forget()
    StatModifiers.Forget()
    Logger.Log("Session ended, trainer state forgotten")
end

local function UpdateSessionState()
    s_Session.isLoaded = Session.IsLoaded()
    s_Session.isPaused = Session.IsPaused()
    s_Session.isBlurred = Session.IsBlurred()
    s_Session.isDead = Session.IsDead()
end

local function OnSessionEvent(state)
    UpdateSessionState()
    if state.event == "Start" then LoadModules() end
    if state.event == "End" then EndSession() end
end

local function LoadLanguage()
    local settings = JsonHelper.LoadOrCreate("Config/JSON/Settings.json", { shown = false, Lang = "en" })
    local code = settings and settings.Lang or "en"
    if Language.Load(code) then return end

    Logger.Log("Language failed to load, falling back to English")
    Language.Load("en")
end

local function LoadData()
    TeleportLocations.LoadAll()
    PerkLoader:LoadAll()
    WeaponLoader:LoadAll()
    VehicleLoader:LoadAll()
    GeneralLoader:LoadAll()
end

local function LoadConfigs()
    BindingsConfig.Load()
    UIConfig.Load()
    NavigationConfig.Load()
    OptionConfig.Load()
end

local function RegisterHooks()
    Event.Observe("PlayerPuppet", "OnAction", function(_, action)
        if not s_Modules then return end
        s_Modules.Self.NoClip.HandleMouseLook(action)
        s_Modules.WorldEditor.FreeCam.HandleAction(action)
        s_Modules.Weapon.HandleInputAction(action)
    end)

    Event.Observe("BaseProjectile", "ProjectileHit", function(projectile, eventData)
        if s_Modules then s_Modules.WeaponTick.HandleProjectileHit(projectile, eventData) end
    end)

    Event.Observe("ShootEvents", "OnEnter", function()
        if s_Modules then s_Modules.WeaponTick.HandleShot() end
    end)

    Event.Observe("ScriptedPuppet", "OnHit", function(_, hitEvent)
        if s_Modules then s_Modules.WeaponTick.HandleHit(hitEvent) end
    end)

    Event.ObserveAfter("LocomotionAirEvents", "OnEnter", function(self, context, result)
        if s_Modules then s_Modules.Self.GodMode.DisableFallFX(self, context, result) end
    end)

    Event.ObserveAfter("MinimapContainerController", "OnCountdownTimerActiveUpdated", function()
        if s_Modules then s_Modules.Vehicles.FreezeQuestTimer.HandleCountdownTimer() end
    end)

    Event.ObserveAfter("hudCarController", "OnCameraModeChanged", function(controller)
        if s_Modules then s_Modules.Vehicles.VehicleSpeedometer.OnHudCameraChanged(controller) end
    end)

    Event.Override("LocomotionTransition", "WantsToDodge", function(transition, stateContext, scriptInterface, wrappedFunc)
        if not s_Modules then return wrappedFunc(stateContext, scriptInterface) end
        return s_Modules.Self.InfiniteAirDash.HandleAirDash(transition, stateContext, scriptInterface, wrappedFunc)
    end)

    Event.Override("ZoomLevelBaseDecisions", "ToZoomLevelAim", function(transition, stateContext, scriptInterface, wrappedFunc)
        if s_Modules and s_Modules.WorldEditor.IsActive() then return false end
        return wrappedFunc(stateContext, scriptInterface)
    end)

    Event.Override("gameItemData", "CanDualWield", function(itemData, owner, wrappedMethod)
        if DualWieldAnything.CanDualWield(itemData) then return true end
        return wrappedMethod(owner)
    end)

    Event.Override("InventoryDataManagerV2", "HasPlayerDualWield", function(_, wrappedMethod)
        if DualWieldAnything.HasPlayerDualWield() then return true end
        return wrappedMethod()
    end)

    Event.Override("scannerDetailsGameController", "ShouldDisplayTwintoneTab", function(this, wrappedMethod)
        if not s_Modules then return wrappedMethod() end
        return VehicleLoader:HandleTwinToneScan(this, wrappedMethod)
    end)
end

Event.RegisterInit(function()
    Logger.Initialize()
    Input.Initialize()

    SaveGuard.Track("StatusEffects", {
        Capture = StatusEffect.GetOwnedEffects,
        Restore = StatusEffect.RemoveUnowned
    })
    SaveGuard.Initialize()

    Session.Listen(OnSessionEvent)
    Cron.After(0.1, UpdateSessionState)
    Cron.Every(1.0, UpdateSessionState)
    Cron.Every(0.5, LoadModules)

    LoadLanguage()
    LoadData()
    LoadConfigs()
    RegisterHooks()

    Logger.Log("Initialized")
end)

Event.RegisterUpdate(function(deltaTime)
    s_DeltaTime = deltaTime
    Cron.Update(deltaTime)

    if not s_Modules then return end
    SaveGuard.Tick()

    if not s_Session.isLoaded or s_Session.isPaused or s_Session.isDead then return end

    s_Modules.SelfTick.TickHandler()
    s_Modules.WeaponTick.TickHandler()
    s_Modules.Vehicles.Tick(deltaTime)
    s_Modules.AutoTeleport.Tick(deltaTime)
    s_Modules.WorldWeather.Update()
    s_Modules.WorldTime.Update(deltaTime)
    s_Modules.WorldEditor.Tick(deltaTime)
end)

Event.RegisterDraw(function()
    Mouse.Update()
    Notification.Render()
    if not s_Modules then return end

    local gameMenuOpen = s_Session.isPaused or s_Session.isBlurred or not s_Session.isLoaded
    s_Modules.WorldEditor.Render(s_DeltaTime, gameMenuOpen)
    s_Modules.Vehicles.VehicleSpeedometer.Render(gameMenuOpen or s_Modules.WorldEditor.IsActive())
    s_Modules.MainMenu.Initialize()
    Handler.Update()
    s_Modules.MainMenu.Render(s_DeltaTime)
end)

Event.RegisterShutdown(function()
    if s_Modules then
        Restrictions.Clear()
        Lifecycle.Shutdown()
        StatusEffect.ClearAll()
        StatModifiers.RemoveAll()
        BindingsConfig.Save()
        OptionConfig.Save()
    end
    Logger.Log("Shutdown cleanup finished")
end)
