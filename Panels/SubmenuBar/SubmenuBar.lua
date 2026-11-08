local Animation = require("Core/Animation")
local Draw = require("Core/Draw")
local State = require("Core/State")
local Style = require("Style/Style")
local Layout = require("Style/Layout")
local Scale = require("Style/Scale")
local SubmenuBarStyle = require("Panels/SubmenuBar/SubmenuBarStyle")

local SubmenuBar = {}

local s_Breadcrumb = ""
local s_Height = 0
local s_Velocity = 0
local s_Writer = Animation.NewTypewriter()

function SubmenuBar.SetBreadcrumb(text)
    s_Breadcrumb = text or ""
end

function SubmenuBar.Height()
    return s_Height
end

function SubmenuBar.Draw()
    local menu = State.Menu
    local delta = State.Time.Delta

    local show = SubmenuBarStyle.Enabled and s_Breadcrumb ~= ""
    local target = show and Scale.S(Layout.SubmenuBarHeight) or 0
    s_Height, s_Velocity = Animation.SmoothDamp(s_Height, target, s_Velocity, SubmenuBarStyle.SmoothTime, delta)

    Animation.TypewriterSet(s_Writer, s_Breadcrumb)
    Animation.TypewriterUpdate(s_Writer, delta, SubmenuBarStyle.TypeSpeed)

    if s_Height < 0.5 then return end

    local y = menu.Y + Scale.S(Layout.HeaderHeight)
    local padding = Scale.S(Layout.Padding)
    local fontSize = Scale.FontSize()

    Draw.RectFilled(menu.X, y, menu.Width, s_Height, Style.BackgroundLight)

    if s_Height > fontSize then
        local textY = y + ((s_Height - fontSize) * 0.5)
        local text = Draw.FitText(s_Writer.Displayed, menu.Width - (padding * 2), fontSize)
        Draw.Text(menu.X + padding, textY, Style.TextDisabled, text, fontSize)
    end

    Draw.Line(menu.X, y + s_Height, menu.X + menu.Width, y + s_Height, Style.Border, 1)
end

return SubmenuBar
