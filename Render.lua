local Animation = require("Core/Animation")
local Draw = require("Core/Draw")
local Input = require("Core/Input")
local Logger = require("Core/Logger")
local InputBlock = require("Core/InputBlock")
local State = require("Core/State")
local Style = require("Style/Style")
local Layout = require("Style/Layout")
local Menu = require("Style/Menu")
local Scale = require("Style/Scale")
local Navigation = require("Navigation/Navigation")
local Submenu = require("Navigation/Submenu")
local Settings = require("Features/Settings/Settings")
local Widget = require("Widgets/Core/Widget")
local Highlight = require("Widgets/Core/Highlight")
local Background = require("Panels/Background/Background")
local Header = require("Panels/Header/Header")
local SubmenuBar = require("Panels/SubmenuBar/SubmenuBar")
local Footer = require("Panels/Footer/Footer")
local Resize = require("Panels/Resize/Resize")
local Sheet = require("Panels/Sheet/Sheet")
local ControlsHud = require("Panels/ControlsHud/ControlsHud")
local TipBox = require("Panels/TipBox/TipBox")
local Speedometer = require("Features/Vehicles/Speedometer")
local WorldEditor = require("Features/WorldEditor/WorldEditor")
local Notification = require("Panels/Notification/Notification")
local Welcome = require("Panels/Welcome/Welcome")
local InfoPanel = require("Panels/InfoPanel/InfoPanel")
local Hotkeys = require("Features/Hotkeys/Hotkeys")
local BindPopup = require("Panels/BindPopup/BindPopup")

local Render = {}

local s_Alpha = 0
local s_Failed = {}

local function Try(name, callback, ...)
    local ok, err = pcall(callback, ...)
    if not ok and not s_Failed[name] then
        s_Failed[name] = true
        Logger.Log(name .. " failed: " .. tostring(err))
    end
    return ok
end

function Render.Initialize(root)
    Navigation.Initialize()
    Submenu.SetRoot(root)
end

local function UpdateMove()
    local menu = State.Menu
    State.UpdateMove(menu.X, menu.Y, menu.Width, Scale.S(Layout.HeaderHeight))
end

local function DrawEdgeFades(content)
    if not Menu.ShowEdgeFade then return end

    local nav = Navigation.State
    local fade = Scale.S(Menu.EdgeFade)
    local solid = Style.Background
    local clear = Draw.WithAlpha(solid, 0)

    if nav.ScrollOffset > 0.5 then
        Draw.Gradient(content.X, Navigation.ScrollTop(), content.Width, fade, solid, solid, clear, clear)
    end

    local contentBottom = (nav.Total * Navigation.RowStep()) - Scale.S(Layout.Spacing) - nav.ScrollOffset
    if contentBottom > content.Height + 0.5 then
        Draw.Gradient(content.X, content.Y + content.Height - fade, content.Width, fade, clear, clear, solid, solid)
    end
end

local function DrawContent()
    Navigation.Begin()

    local content = Navigation.Content()
    local clipX = content.X - Navigation.State.OffsetX

    Draw.SetAlpha(s_Alpha * Submenu.TransitionAlpha())
    Draw.PushClip(clipX, content.Y, content.Width, content.Height)
    Highlight.DrawHighlight()
    Submenu.DrawCurrent()
    Navigation.EndRows()
    DrawEdgeFades(content)
    Draw.PopClip()
    Draw.SetAlpha(s_Alpha)

    Navigation.End()
    Widget.EndFrame()
    Submenu.ApplyPending()
end

local function DrawFrame()
    Background.Draw()
    Header.Draw()
    SubmenuBar.Draw()

    DrawContent()
    Sheet.Draw()

    Footer.Draw()
    Resize.Draw()
end

local function DrawWindow()
    local menu = State.Menu

    if Draw.BeginWindow("##EasyTrainerMenu", menu.X, menu.Y, menu.Width, menu.Height) then
        Try("Menu", DrawFrame)
    end

    Draw.EndWindow()
end

local function UpdateMenu()
    if State.Menu.Open then
        Resize.Update()
        UpdateMove()
        Footer.Update()
    end

    Navigation.UpdateInput()
    Sheet.Update()

    if Navigation.State.BackPressed and not Sheet.SheetVisible() then Submenu.Close() end

    Submenu.UpdateTransition()
    SubmenuBar.SetBreadcrumb(Submenu.Breadcrumb())
end

function Render.Draw(delta)
    Animation.SetDelta(delta)
    Input.Update(State.Time.Time)
    Scale.Update(State.Rescale)
    State.Update(delta)
    Try("Hotkeys", Hotkeys.Detect)
    InputBlock.Update()
    Settings.Update(delta)

    s_Alpha = Animation.Animate(s_Alpha, State.Menu.Open and 1 or 0, Menu.FadeSpeed, delta)
    Try("Speedometer", Speedometer.Draw)
    Try("World editor HUD", WorldEditor.Draw)
    Try("Notifications", Notification.Draw)
    Try("Welcome", Welcome.Draw)
    if not State.Menu.Open and s_Alpha < 0.01 then return end

    Try("Menu update", UpdateMenu)

    Draw.SetAlpha(s_Alpha)
    DrawWindow()
    Try("Bind popup", BindPopup.Update)

    InfoPanel.Draw()
    TipBox.Draw()
    ControlsHud.Draw()
    Try("Bind popup draw", BindPopup.Draw)

    Draw.SetAlpha(1)
end

function Render.Shutdown()
    Settings.Shutdown()
    InputBlock.Shutdown()
    State.Shutdown()
    Input.EndText()
end

return Render
