local Input = require("Core/Input")

local Mouse = {}

local VK_LBUTTON = 0x01

local s_Down = false
local s_WasDown = false
local s_X = 0
local s_Y = 0
local s_Wheel = 0

local function ReadDown()
    local native = Input.IsMouseButtonDown(0)
    if native ~= nil then return native end
    return Input.IsKeyDown(VK_LBUTTON) or ImGui.IsMouseDown(0)
end

function Mouse.Update()
    s_WasDown = s_Down
    s_Down = ReadDown()

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
