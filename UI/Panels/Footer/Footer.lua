local Context = require("UI/Core/Context")
local Draw = require("UI/Core/Draw")
local Layout = require("UI/Style/Layout")
local Navigation = require("UI/Navigation/Navigation")
local Style = require("UI/Style/Style")

local Footer = {
    Version = "by Avi  /  v2.0",
    ShowVersion = true,
    ShowNavigation = true,
    ShowFps = false,
}

function Footer.Draw()
    local bounds = Context.Bounds
    local drawList = ImGui.GetWindowDrawList()
    local y = bounds.Y + bounds.Height - Layout.FooterHeight
    local textY = y + ((Layout.FooterHeight - ImGui.GetFontSize()) * 0.5)

    Draw.Line(drawList, bounds.X, y, bounds.X + bounds.Width, y, Style.Border, 1)
    if Footer.ShowVersion then
        Draw.Text(drawList, bounds.X + Layout.Padding, textY, Style.TextDisabled, Footer.Version)
    end

    if Footer.ShowNavigation then
        local navigation = string.format("%d / %d", Navigation.State.Current, Navigation.State.Total)
        local width = ImGui.CalcTextSize(navigation)
        Draw.Text(drawList, bounds.X + bounds.Width - Layout.Padding - width,
            textY, Style.TextDisabled, navigation)
    end
end

return Footer

