local Surface = {}

local Animation = require("UI/Widgets/Animation/Animation")
local Context = require("UI/Core/Context")
local Draw = require("UI/Core/Draw")
local DefaultStyle = require("UI/Widgets/Surface/SurfaceStyle")

function Surface.Create(id)
    return {
        Id = id,
        Active = false,
        Open = false,
        Ready = false,
        X = 0,
        Y = 0,
        Width = 0,
        Height = 0,
        Alpha = 0,
        Scale = 0,
    }
end

function Surface.Open(surface)
    if not surface.Open then
        surface.Alpha = 0
        surface.Scale = DefaultStyle.ClosedScale
    end
    surface.Open = true
    surface.Active = true
end

function Surface.Close(surface)
    surface.Open = false
end

function Surface.Initialize(surface)
    surface.Active = false
    surface.Open = false
    surface.Ready = false
    surface.X = 0
    surface.Y = 0
    surface.Width = 0
    surface.Height = 0
    surface.Alpha = 0
    surface.Scale = 0
end

function Surface.Begin(surface, width, height, style)
    style = style or DefaultStyle

    local targetAlpha = surface.Open and 1 or 0
    local targetScale = surface.Open and 1 or style.ClosedScale
    surface.Alpha = Animation.Animate(surface.Alpha, targetAlpha, style.AnimationSpeed, Context.DeltaTime)
    surface.Scale = Animation.Animate(surface.Scale, targetScale, style.AnimationSpeed, Context.DeltaTime)
    surface.Ready = surface.Alpha > 0.92
    surface.Active = true
    surface.Width = width
    surface.Height = height

    if not surface.Open and surface.Alpha < 0.01 then
        surface.Active = false
        return false
    end

    local animatedWidth = width * surface.Scale
    local animatedHeight = height * surface.Scale
    local bounds = Context.Bounds
    surface.X = bounds.X + ((bounds.Width - animatedWidth) * 0.5)
    surface.Y = bounds.Y + ((bounds.Height - animatedHeight) * 0.5)

    local drawList = ImGui.GetWindowDrawList()
    Draw.RectFilled(drawList, surface.X + 3, surface.Y + 3, animatedWidth, animatedHeight,
        Animation.WithAlpha(style.Shadow, surface.Alpha), style.Rounding)
    Draw.RectFilled(drawList, surface.X, surface.Y, animatedWidth, animatedHeight,
        Animation.WithAlpha(style.Background, surface.Alpha), style.Rounding)
    Draw.Rect(drawList, surface.X, surface.Y, animatedWidth, animatedHeight,
        Animation.WithAlpha(style.Border, surface.Alpha), style.Rounding, style.BorderSize)

    ImGui.PushID(surface.Id)
    ImGui.SetCursorScreenPos(surface.X + style.Padding, surface.Y + style.Padding)
    ImGui.BeginGroup()
    return true
end

function Surface.End(surface)
    ImGui.EndGroup()
    ImGui.PopID()
    surface.Active = false
end

return Surface

