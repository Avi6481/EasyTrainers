local Input = require("Core/Input")

local Mouse = {}

local BUTTON_KEYS = { [0] = 0x01, [1] = 0x02 }

local s_Down = false
local s_WasDown = false
local s_RightDown = false
local s_X = 0
local s_Y = 0
local s_Wheel = 0

local function ReadButton(button)
    local native = Input.IsMouseButtonDown(button)
    if native ~= nil then return native end
    return Input.IsKeyDown(BUTTON_KEYS[button]) or ImGui.IsMouseDown(button)
end

function Mouse.Update()
    s_WasDown = s_Down
    s_Down = ReadButton(0)
    s_RightDown = ReadButton(1)

    local x, y = Input.GetMousePosition()
    if x then
        s_X, s_Y = x, y
    else
        s_X, s_Y = ImGui.GetMousePos()
    end
    s_Wheel = Input.ConsumeMouseWheel()
end

function Mouse.IsDown()
    return s_Down
end

function Mouse.IsRightDown()
    return s_RightDown
end

function Mouse.IsClicked()
    return s_Down and not s_WasDown
end

function Mouse.GetPosition()
    return s_X, s_Y
end

function Mouse.GetWheel()
    return s_Wheel
end

function Mouse.IsInside(x, y, width, height)
    return s_X >= x and s_X <= x + width and s_Y >= y and s_Y <= y + height
end

return Mouse
