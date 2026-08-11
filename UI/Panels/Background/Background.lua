local Context = require("UI/Core/Context")
local Draw = require("UI/Core/Draw")
local Layout = require("UI/Style/Layout")
local Style = require("UI/Style/Style")

local Background = { Enabled = true }

function Background.Draw()
    if not Background.Enabled then return end
    local bounds = Context.Bounds
    Draw.RectFilled(ImGui.GetWindowDrawList(), bounds.X, bounds.Y, bounds.Width, bounds.Height,
        Style.Background, Layout.Rounding)
end

return Background

