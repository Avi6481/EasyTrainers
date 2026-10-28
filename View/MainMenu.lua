local Buttons = require("UI/Options/Buttons")
local Submenu = require("UI/Navigation/Submenu")
local Navigation = require("UI/Navigation/Navigation")
local Renderer = require("UI/Render")
local Notification = require("UI/Panels/Notification/Notification")
local OptionRegistry = require("UI/Registry/OptionRegistry")
local State = require("Controls/State")

local SelfConfig = require("Features/Self/SelfConfig")
local TeleportConfig = require("Features/Teleports/TeleportConfig")
local VehicleConfig = require("Features/Vehicles/VehicleConfig")
local WeaponConfig = require("Features/Weapons/WeaponConfig")
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
local WorldEditorView = require("View/WorldEditor/WorldEditorView")

local MainMenu = {}

local s_Initialized = false

local function MainView()
    Buttons.Submenu(L("mainmenu.self.label"), SelfView, tip("mainmenu.self.tip"))
    Buttons.Submenu(L("mainmenu.development.label"), SelfDevelopmentView, tip("mainmenu.development.tip"), function()
        Notification.Warning(L("mainmenu.development.warning"))
    end)
    Buttons.Submenu(L("mainmenu.modifiers.label"), SelfModifiersView, tip("mainmenu.modifiers.tip"))
    Buttons.Submenu(L("mainmenu.teleport.label"), TeleportView, tip("mainmenu.teleport.tip"))
    Buttons.Submenu(L("mainmenu.weapon.label"), WeaponView, tip("mainmenu.weapon.tip"))
    Buttons.Submenu(L("mainmenu.vehicle.label"), VehicleView, tip("mainmenu.vehicle.tip"))
    Buttons.Submenu(L("mainmenu.facts.label"), FactsView, tip("mainmenu.facts.tip"), function()
        Notification.Warning(L("mainmenu.facts.warning"))
    end)
    Buttons.Submenu(L("mainmenu.time.label"), TimeView, tip("mainmenu.time.tip"))
    Buttons.Submenu(L("mainmenu.weather.label"), WeatherView, tip("mainmenu.weather.tip"))
    Buttons.Submenu(L("mainmenu.items.label"), ItemsView, tip("mainmenu.items.tip"))
    Buttons.Submenu(L("mainmenu.worldeditor.label"), WorldEditorView, tip("mainmenu.worldeditor.tip"))
    Buttons.Submenu(L("mainmenu.settingsmenu.label"), SettingsView, tip("mainmenu.settingsmenu.tip"))
end

function MainMenu.Initialize()
    if s_Initialized then return end

    SelfConfig()
    WeaponConfig()
    VehicleConfig()
    TeleportConfig()
    WorldConfig()
    OptionRegistry.RegisterHotkeyActions()

    Renderer.Initialize(Submenu.Create("EasyTrainer", MainView))
    Renderer.Enable(true)
    Notification.Info("EasyTrainer initialized!")
    s_Initialized = true
end

function MainMenu.Render(deltaTime)
    if not s_Initialized then return end

    local open = State.MenuOpen
    Renderer.Enable(open)
    Navigation.State.MouseEnabled = open and (State.OverlayOpen or State.MouseEnabled)
    Renderer.SetInput({
        UpPressed = open and State.UpPressed,
        DownPressed = open and State.DownPressed,
        LeftPressed = open and State.LeftPressed,
        RightPressed = open and State.RightPressed,
        SelectPressed = open and State.SelectPressed,
        BackPressed = open and State.BackPressed
    })
    Renderer.Render(deltaTime)
end

return MainMenu
