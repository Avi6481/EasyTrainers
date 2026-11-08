local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local SelfView = require("View/Self/SelfView")
local ModifiersView = require("View/Modifiers/ModifiersView")
local DevelopmentView = require("View/Development/DevelopmentView")
local TeleportsView = require("View/Teleports/TeleportsView")
local VehiclesView = require("View/Vehicles/VehiclesView")
local WeaponsView = require("View/Weapons/WeaponsView")
local ItemsView = require("View/Items/ItemsView")
local FactsView = require("View/World/FactsView")
local TimeView = require("View/World/TimeView")
local WeatherView = require("View/World/WeatherView")
local WorldEditorView = require("View/WorldEditor/WorldEditorView")
local SettingsView = require("View/Settings/SettingsView")
local TestView = require("View/Test/TestView")

local MainMenu = {}

local function Link(key, submenu)
    Widgets.SubmenuButton(L(key .. ".label"), submenu)
    Widgets.Tip(L(key .. ".tip"))
end

local function View()
    Link("mainmenu.self", SelfView.Menu)
    Link("mainmenu.modifiers", ModifiersView.Menu)
    Link("mainmenu.development", DevelopmentView.Menu)
    Link("mainmenu.teleport", TeleportsView.Menu)
    Link("mainmenu.vehicle", VehiclesView.Menu)
    Link("mainmenu.weapon", WeaponsView.Menu)
    Link("mainmenu.items", ItemsView.Menu)
    Link("mainmenu.facts", FactsView.Menu)
    Link("mainmenu.time", TimeView.Menu)
    Link("mainmenu.weather", WeatherView.Menu)
    Link("mainmenu.worldeditor", WorldEditorView.Menu)
    Link("mainmenu.settingsmenu", SettingsView.Menu)
   -- Link("mainmenu.uitest", TestView.Menu)
end

local ROOT_MENU = Submenu.Create("mainmenu.title", View)

function MainMenu.Root()
    return ROOT_MENU
end

return MainMenu
