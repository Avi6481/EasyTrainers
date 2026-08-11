local UI = {}

UI.Context = require("UI/Core/Context")
UI.Layout = require("UI/Style/Layout")
UI.Style = require("UI/Style/Style")
UI.Navigation = require("UI/Navigation/Navigation")
UI.Submenus = require("UI/Navigation/Submenu")
UI.Options = require("UI/Option/Option")
UI.Renderer = require("UI/Render")
UI.MainMenu = require("UI/MainMenu/MainMenu")
UI.MainTabs = require("UI/MainMenu/MainTabs")
UI.Surface = require("UI/Widgets/Surface/Surface")
UI.Dropdown = require("UI/Widgets/Dropdown/Dropdown")
UI.ColorPicker = require("UI/Widgets/ColorPicker/ColorPicker")
UI.Tip = require("UI/Panels/Tip/Tip")
UI.SidePanel = require("UI/Panels/SidePanel/SidePanel")

UI.Notification = require("UI/Panels/Notification/Notification")
UI.Buttons = require("UI/Options/Buttons")
UI.OptionRegistry = require("UI/Registry/OptionRegistry")


return UI
