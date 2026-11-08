local Input = require("Core/Input")
local State = require("Core/State")

local Controls = {
    Binds = {}
}

Controls.Actions = { "Blackwall" }

local DEFAULTS = {
    Blackwall = { Keys = { Input.VK.B }, Buttons = {} }
}

local s_Held = {}
local s_Pressed = {}

local function Copy(binding)
    local copy = { Keys = {}, Buttons = {} }
    for index, key in ipairs(binding.Keys) do copy.Keys[index] = key end
    for index, button in ipairs(binding.Buttons) do copy.Buttons[index] = button end
    return copy
end

local function Valid(binding)
    return type(binding) == "table" and type(binding.Keys) == "table" and type(binding.Buttons) == "table"
end

function Controls.Fill()
    if type(Controls.Binds) ~= "table" then Controls.Binds = {} end
    for action in pairs(Controls.Binds) do
        if not DEFAULTS[action] then Controls.Binds[action] = nil end
    end
    for _, action in ipairs(Controls.Actions) do
        if not Valid(Controls.Binds[action]) then Controls.Binds[action] = Copy(DEFAULTS[action]) end
    end
end

function Controls.Reset()
    for _, action in ipairs(Controls.Actions) do Controls.Binds[action] = Copy(DEFAULTS[action]) end
end

Controls.Fill()

local function Down(codes, check)
    if #codes == 0 then return false end
    for _, code in ipairs(codes) do
        if not check(code) then return false end
    end
    return true
end

function Controls.Update()
    local blocked = State.Menu.Open or State.OverlayOpen
    for _, action in ipairs(Controls.Actions) do
        local binding = Controls.Binds[action]
        local held = not blocked and (Down(binding.Keys, Input.KeyDown) or Down(binding.Buttons, Input.ButtonDown))
        s_Pressed[action] = held and not s_Held[action]
        s_Held[action] = held
    end
end

function Controls.Pressed(action)
    return s_Pressed[action] == true
end

return Controls
