local UI = require("UI")
local State = require("Controls/State")

local ControlsConfig = require("Controls/ControlsConfig")
local SelfConfig = require("Features/Self/SelfConfig")
local TeleportConfig = require("Features/Teleports/TeleportConfig")
local VehicleConfig = require("Features/Vehicles/VehicleConfig")
local WeaponsConfig = require("Features/Weapons/WeaponConfig")
local WorldConfig = require("Features/World/WorldConfig")

local SelfView = require("View/Self/SelfMenuView")
local SelfDevelopmentView = require("View/Self/SelfDevelopment")
local SelfModifiersView = require("View/Self/SelfModifierView")
local TeleportView = require("View/Teleports/TeleportView")
local WeaponView = require("View/Weapons/WeaponMenuView")
local VehicleView = require("View/Vehicle/VehicleMenuView")
local SettingsView = require("View/Settings/SettingsView")
local WeatherView = require("View/World/WeatherView")
local TimeView = require("View/World/TimeView")
local FactsView = require("View/World/FactView")
local ItemsView = require("View/Items/ItemBrowserView")

local MainMenu = { Initialized = false }

local function DrawMainMenu()
    UI.Buttons.Submenu(L("mainmenu.self.label"), SelfView, tip("mainmenu.self.tip"))
    UI.Buttons.Submenu(L("mainmenu.development.label"), SelfDevelopmentView, tip("mainmenu.development.tip"), function()
        UI.Notification.Warning(L("mainmenu.development.warning"))
    end)
    UI.Buttons.Submenu(L("mainmenu.modifiers.label"), SelfModifiersView, tip("mainmenu.modifiers.tip"))
    UI.Buttons.Submenu(L("mainmenu.teleport.label"), TeleportView, tip("mainmenu.teleport.tip"))
    UI.Buttons.Submenu(L("mainmenu.weapon.label"), WeaponView, tip("mainmenu.weapon.tip"))
    UI.Buttons.Submenu(L("mainmenu.vehicle.label"), VehicleView, tip("mainmenu.vehicle.tip"))
    UI.Buttons.Submenu(L("mainmenu.facts.label"), FactsView, tip("mainmenu.facts.tip"), function()
        UI.Notification.Warning(L("mainmenu.facts.warning"))
    end)
    UI.Buttons.Submenu(L("mainmenu.time.label"), TimeView, tip("mainmenu.time.tip"))
    UI.Buttons.Submenu(L("mainmenu.weather.label"), WeatherView, tip("mainmenu.weather.tip"))
    UI.Buttons.Submenu(L("mainmenu.items.label"), ItemsView, tip("mainmenu.items.tip"))
    UI.Buttons.Submenu(L("mainmenu.settingsmenu.label"), SettingsView, tip("mainmenu.settingsmenu.tip"))
end

function MainMenu.Initialize()
    if MainMenu.Initialized then return end

    ControlsConfig()
    SelfConfig()
    WeaponsConfig()
    VehicleConfig()
    TeleportConfig()
    WorldConfig()
    UI.OptionRegistry.RegisterHotkeyActions()

    local root = UI.Submenus.Create("EasyTrainer", DrawMainMenu)
    UI.Renderer.Initialize(root)
    UI.Renderer.Enable(true)
    UI.Notification.Info("EasyTrainer initialized!")
    MainMenu.Initialized = true
end

function MainMenu.Render()
    if not MainMenu.Initialized then return end

    UI.Renderer.Enable(State.menuOpen)
    UI.Navigation.State.MouseEnabled = State.menuOpen and (State.overlayOpen or State.mouseEnabled)
    local active = State.menuOpen
    UI.Renderer.SetInput({
        UpPressed = active and State.upPressed,
        DownPressed = active and State.downPressed,
        LeftPressed = active and State.leftPressed,
        RightPressed = active and State.rightPressed,
        SelectPressed = active and State.selectPressed,
        BackPressed = active and State.backPressed,
    })
    UI.Renderer.Render(1 / 60)
end

return MainMenu
