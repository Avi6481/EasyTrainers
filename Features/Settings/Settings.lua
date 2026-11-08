local Config = require("Core/Config")
local InputBlock = require("Core/InputBlock")
local Language = require("Core/Language")
local Logger = require("Core/Logger")
local State = require("Core/State")
local Layout = require("Style/Layout")
local Menu = require("Style/Menu")
local Scale = require("Style/Scale")
local Theme = require("Style/Theme")
local NavigationStyle = require("Navigation/NavigationStyle")
local ButtonStyle = require("Widgets/Button/ButtonStyle")
local HighlightStyle = require("Widgets/Core/HighlightStyle")
local SliderStyle = require("Widgets/Slider/SliderStyle")
local ToggleStyle = require("Widgets/Toggle/ToggleStyle")
local ControlsHudStyle = require("Panels/ControlsHud/ControlsHudStyle")
local SubmenuBarStyle = require("Panels/SubmenuBar/SubmenuBarStyle")
local TipBox = require("Panels/TipBox/TipBox")
local InfoPanel = require("Panels/InfoPanel/InfoPanel")
local Welcome = require("Panels/Welcome/Welcome")
local Notification = require("Panels/Notification/Notification")
local Hotkeys = require("Features/Hotkeys/Hotkeys")

local Settings = {}

Settings.Language = {
    Code = Language.DefaultCode
}

Settings.Window = {
    X = State.Menu.X,
    Y = State.Menu.Y,
    Width = State.Menu.Width,
    Height = State.Menu.Height
}

local KEEP_ON_RESET = {
    Language = true,
    Hotkeys = true,
    OptionHotkeys = true
}

local s_Store = Config.New("Config/Settings.json")

local function LoadLanguage()
    if Language.Load(Settings.Language.Code) then return end

    Logger.Log("Language failed to load, falling back to English")
    Settings.Language.Code = Language.DefaultCode
    Language.Load(Language.DefaultCode)
end

local function ApplyWindow()
    local menu = State.Menu
    local window = Settings.Window
    menu.X = Scale.S(window.X)
    menu.Y = Scale.S(window.Y)
    menu.Width = Scale.S(window.Width)
    menu.Height = Scale.S(window.Height)
    State.ClampToScreen()
end

local function TrackWindow()
    local menu = State.Menu
    local window = Settings.Window
    window.X = menu.X / Scale.Current
    window.Y = menu.Y / Scale.Current
    window.Width = menu.Width / Scale.Current
    window.Height = menu.Height / Scale.Current
end

local function SyncRounding()
    HighlightStyle.Rounding = Layout.Rounding
    ButtonStyle.HoverRounding = Layout.Rounding
    ControlsHudStyle.Rounding = Layout.Rounding
    TipBox.Style.Rounding = Layout.Rounding
    InfoPanel.Style.Rounding = Layout.Rounding
end

function Settings.Initialize()
    s_Store:Load()

    s_Store:Bind("Language", Settings.Language, { "Code" })
    s_Store:Bind("Window", Settings.Window, { "X", "Y", "Width", "Height" })
    s_Store:Bind("Theme", Theme.Settings, { "Name", "Opacity", "Custom" })
    s_Store:Bind("Scale", Scale, { "Auto", "Manual", "TextScale" })
    s_Store:Bind("Layout", Layout, { "OptionHeight", "Spacing", "Padding", "Rounding" })
    s_Store:Bind("Menu", Menu, { "ShowEdgeFade" })
    s_Store:Bind("SubmenuBar", SubmenuBarStyle, { "Enabled" })
    s_Store:Bind("ControlsHud", ControlsHudStyle, { "Enabled" })
    s_Store:Bind("TipBox", TipBox.Style, { "Enabled" })
    s_Store:Bind("InfoPanel", InfoPanel.Style, { "Enabled" })
    s_Store:Bind("Notification", Notification.Style, { "Enabled", "Duration", "Position" })
    s_Store:Bind("Welcome", Welcome, { "Seen" })
    s_Store:Bind("Highlight", HighlightStyle, { "ShowHint", "SmoothTime" })
    s_Store:Bind("Toggle", ToggleStyle, { "Shape" })
    s_Store:Bind("Slider", SliderStyle, { "Shape" })
    s_Store:Bind("Navigation", NavigationStyle, {
        "RepeatDelay", "RepeatRate", "RepeatRateFast", "AccelThreshold", "AccelStep", "ScrollSmoothTime", "MouseHoverSelects",
        "CursorlessClicks", "RightClickBack", "MouseWheelNavigation", "MouseWheelRows"
    })
    s_Store:Bind("InputBlock", InputBlock, { "Enabled" })
    s_Store:Bind("BlockedControls", InputBlock.Extra, InputBlock.ExtraIds())
    s_Store:Bind("Hotkeys", State.Hotkeys, { "ToggleMenu" })
    s_Store:Bind("OptionHotkeys", Hotkeys.Bindings, Hotkeys.Ids())
    Hotkeys.Fill()

    Scale.Update(nil)
    ApplyWindow()
    SyncRounding()
    Theme.Refresh(true)
    LoadLanguage()
end

function Settings.Update(delta)
    TrackWindow()
    SyncRounding()
    Theme.Update(delta)
    s_Store:Update()
end

function Settings.SetWindowSize(key, value)
    if math.abs(value - Settings.Window[key]) < 0.5 then return end

    State.Menu[key] = Scale.S(value)
    State.ClampToScreen()
end

function Settings.SetLanguage(code)
    if not Language.Load(code) then return false end

    Settings.Language.Code = code
    return true
end

function Settings.Reset()
    s_Store:Reset(KEEP_ON_RESET)
    ApplyWindow()
    Theme.Refresh(false)
end

function Settings.Shutdown()
    s_Store:Flush()
end

return Settings
