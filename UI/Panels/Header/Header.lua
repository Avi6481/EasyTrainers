local Context = require("UI/Core/Context")
local Draw = require("UI/Core/Draw")
local Layout = require("UI/Style/Layout")
local Style = require("UI/Style/Style")

local Header = { Title = "EasyTrainer", Subtitle = "NC // 2077" }

function Header.Draw()
    local bounds = Context.Bounds
    local drawList = ImGui.GetWindowDrawList()
    local textY = bounds.Y + ((Layout.HeaderHeight - ImGui.GetFontSize()) * 0.5)
    Draw.Text(drawList, bounds.X + Layout.Padding, textY, Style.Text, Header.Title)
    local subtitleWidth = ImGui.CalcTextSize(Header.Subtitle)
    Draw.Text(drawList, bounds.X + bounds.Width - Layout.Padding - subtitleWidth,
        textY, Style.TextDisabled, Header.Subtitle)
    Draw.RectFilled(drawList, bounds.X, bounds.Y + Layout.HeaderHeight - 2,
        bounds.Width, 2, Style.Accent, 0)
end

return Header

