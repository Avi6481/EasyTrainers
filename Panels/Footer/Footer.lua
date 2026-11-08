local Draw = require("Core/Draw")
local Icons = require("Core/Icons")
local Input = require("Core/Input")
local State = require("Core/State")
local Style = require("Style/Style")
local Layout = require("Style/Layout")
local Scale = require("Style/Scale")
local FooterStyle = require("Panels/Footer/FooterStyle")
local ResizeStyle = require("Panels/Resize/ResizeStyle")

local Footer = {}

local s_Current = 0
local s_Total = 0
local s_Scroll = 0

local function FooterY()
    local menu = State.Menu
    return menu.Y + menu.Height - Scale.S(Layout.FooterHeight)
end

local function UpArrow()
    local menu = State.Menu
    local centerX = menu.X + (menu.Width * 0.5)
    local width = Scale.S(FooterStyle.ArrowWidth)
    return { X = centerX - width, Y = FooterY(), W = width, H = Scale.S(Layout.FooterHeight) }
end

local function DownArrow()
    local menu = State.Menu
    local centerX = menu.X + (menu.Width * 0.5)
    return { X = centerX, Y = FooterY(), W = Scale.S(FooterStyle.ArrowWidth), H = Scale.S(Layout.FooterHeight) }
end

local function Hovered(rect)
    if not FooterStyle.ShowArrows or not State.Menu.Cursor or State.IsBusy() then return false end
    return Input.MouseIn(rect.X, rect.Y, rect.W, rect.H)
end

local function DeviceIcon()
    local device = State.Device.Device
    if device == State.Devices.Keyboard then return Icons.Get("Keyboard") end
    if device == State.Devices.Controller then return Icons.Get("Controller") end
    return Icons.Get("Mouse")
end

local function DrawArrow(rect, icon)
    local color = Hovered(rect) and Style.Accent or Style.TextDisabled
    Draw.TextCentered(rect.X, rect.Y, rect.W, rect.H, color, icon, Scale.FontSize())
end

function Footer.SetFooterCount(current, total)
    s_Current = current or 0
    s_Total = total or 0
end

function Footer.FooterScroll()
    return s_Scroll
end

function Footer.Update()
    s_Scroll = 0
    if not Input.MousePressed(Input.Mouse.Left) then return end

    if Hovered(UpArrow()) then
        s_Scroll = -1
    elseif Hovered(DownArrow()) then
        s_Scroll = 1
    end
end

function Footer.Draw()
    local menu = State.Menu
    local y = FooterY()
    local padding = Scale.S(Layout.Padding)
    local fontSize = Scale.FontSize()
    local textY = y + ((Scale.S(Layout.FooterHeight) - fontSize) * 0.5)

    Draw.Line(menu.X, y, menu.X + menu.Width, y, Style.Border, 1)

    local leftX = menu.X + padding

    if FooterStyle.ShowDevice then
        local icon = DeviceIcon()
        local iconWidth = Draw.TextSize(icon, fontSize)
        Draw.Text(leftX, textY, Style.TextDisabled, icon, fontSize)
        leftX = leftX + iconWidth + Scale.S(FooterStyle.IconSpacing)
    end

    if FooterStyle.ShowVersion and FooterStyle.Version ~= "" then
        Draw.Text(leftX, textY, Style.TextDisabled, FooterStyle.Version, fontSize)
    end

    if FooterStyle.ShowArrows then
        DrawArrow(UpArrow(), Icons.Get("ChevronUp"))
        DrawArrow(DownArrow(), Icons.Get("ChevronDown"))
    end

    if not FooterStyle.ShowCount then return end

    local count = string.format("%d / %d", s_Current, s_Total)
    local gripSpace = ResizeStyle.Enabled and Scale.S(ResizeStyle.Size) or 0
    local countWidth = Draw.TextSize(count, fontSize)
    Draw.Text(menu.X + menu.Width - padding - countWidth - gripSpace, textY, Style.TextDisabled, count, fontSize)
end

return Footer
