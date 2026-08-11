local Animation = require("UI/Widgets/Animation/Animation")
local Context = require("UI/Core/Context")
local Draw = require("UI/Core/Draw")
local Layout = require("UI/Style/Layout")
local Style = require("UI/Style/Style")

local Highlight = {}

Highlight.Position = 0
Highlight.TargetPosition = 0
Highlight.Height = 0
Highlight.TargetHeight = 0

function Highlight.Initialize()
    Highlight.Position = 0
    Highlight.TargetPosition = 0
    Highlight.Height = 0
    Highlight.TargetHeight = 0
end

function Highlight.Set(y, height)
    Highlight.TargetPosition = y
    Highlight.TargetHeight = height
    if Highlight.Position <= 0 then Highlight.Position = y end
    if Highlight.Height <= 0 then Highlight.Height = height end
end

function Highlight.Update()
    Highlight.Position = Animation.Animate(Highlight.Position, Highlight.TargetPosition, 18, Context.DeltaTime)
    Highlight.Height = Animation.Animate(Highlight.Height, Highlight.TargetHeight, 18, Context.DeltaTime)
end

function Highlight.Draw()
    if Highlight.Height <= 0 then return end

    local bounds = Context.Bounds
    local drawList = ImGui.GetWindowDrawList()
    local x = bounds.X + Layout.Padding
    local width = bounds.Width - (Layout.Padding * 2)

    Draw.RectFilled(drawList, x, Highlight.Position, width, Highlight.Height, 0x1AFFFFFF, Layout.Rounding)
    Draw.LeftAccent(drawList, x, Highlight.Position, Highlight.Height, Style.Accent, Layout.Rounding, 3)
    Draw.Rect(drawList, x, Highlight.Position, width, Highlight.Height, 0x28FFFFFF, Layout.Rounding, 1)
end

return Highlight

