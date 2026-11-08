local Draw = require("Core/Draw")
local Input = require("Core/Input")
local State = require("Core/State")
local Style = require("Style/Style")
local Scale = require("Style/Scale")
local ResizeStyle = require("Panels/Resize/ResizeStyle")

local Resize = {}

local function GripPos()
    local menu = State.Menu
    local size = Scale.S(ResizeStyle.Size)
    return menu.X + menu.Width - size, menu.Y + menu.Height - size
end

function Resize.GripHovered()
    local x, y = GripPos()
    local size = Scale.S(ResizeStyle.Size)
    return Input.MouseIn(x, y, size, size)
end

function Resize.Update()
    if not ResizeStyle.Enabled or not State.Menu.Cursor then return end

    local x, y = GripPos()
    local size = Scale.S(ResizeStyle.Size)
    State.UpdateResize(x, y, size, size)
end

function Resize.Draw()
    if not ResizeStyle.Enabled then return end

    local menu = State.Menu
    local right = menu.X + menu.Width - Scale.S(ResizeStyle.Inset)
    local bottom = menu.Y + menu.Height - Scale.S(ResizeStyle.Inset)
    local longLine = Scale.S(ResizeStyle.LongLine)
    local shortLine = Scale.S(ResizeStyle.ShortLine)

    local active = menu.Resizing or (menu.Cursor and Resize.GripHovered())
    local color = active and Style.Accent or Style.Border

    Draw.Line(right - longLine, bottom, right, bottom - longLine, color, ResizeStyle.Thickness)
    Draw.Line(right - shortLine, bottom, right, bottom - shortLine, color, ResizeStyle.Thickness)
end

return Resize
