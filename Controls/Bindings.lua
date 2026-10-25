local Input = require("Core/Input")

local Bindings = {}

local function Normalize(list)
    local seen = {}
    local result = {}
    for _, value in ipairs(list or {}) do
        if not seen[value] then
            table.insert(result, value)
            seen[value] = true
        end
    end
    table.sort(result)
    return result
end

local function Copy(binding)
    return { keys = Normalize(binding.keys), btns = Normalize(binding.btns) }
end

Bindings.Normalize = Normalize

Bindings.DefaultActions = {
    UP = { keys = { Input.VK.UP }, btns = { Input.GP.DPAD_UP } },
    DOWN = { keys = { Input.VK.DOWN }, btns = { Input.GP.DPAD_DOWN } },
    LEFT = { keys = { Input.VK.LEFT }, btns = { Input.GP.DPAD_LEFT } },
    RIGHT = { keys = { Input.VK.RIGHT }, btns = { Input.GP.DPAD_RIGHT } },
    SELECT = { keys = { Input.VK.ENTER }, btns = { Input.GP.A } },
    BACK = { keys = { Input.VK.BACKSPACE }, btns = { Input.GP.B } },
    MISC = { keys = { Input.VK.C }, btns = { Input.GP.LEFT_BUMPER, Input.GP.A } },
    TOGGLE = { keys = { Input.VK.F4 }, btns = { Input.GP.RIGHT_BUMPER, Input.GP.A } },
    TOGGLE_MOUSE = { keys = { Input.VK.X }, btns = {} },
    NOCLIP_UP = { keys = { Input.VK.SPACE }, btns = { Input.GP.RIGHT_BUMPER } },
    NOCLIP_DOWN = { keys = { Input.VK.CTRL }, btns = { Input.GP.LEFT_BUMPER } },
    NOCLIP_BOOST = { keys = { Input.VK.SHIFT }, btns = { Input.GP.LEFT_STICK } },
    NOCLIP_FORWARD = { keys = { Input.VK.W }, btns = {} },
    NOCLIP_BACKWARD = { keys = { Input.VK.S }, btns = {} },
    NOCLIP_LEFT = { keys = { Input.VK.A }, btns = {} },
    NOCLIP_RIGHT = { keys = { Input.VK.D }, btns = {} },
    NITRO = { keys = { Input.VK.SHIFT }, btns = { Input.GP.X } },
    BLACKWALL_FORCE = { keys = { Input.VK.B }, btns = {} }
}

Bindings.Actions = {}
for action, binding in pairs(Bindings.DefaultActions) do
    Bindings.Actions[action] = Copy(binding)
end

local function AllDown(list, isDown)
    if not list or #list == 0 then return false end
    for _, code in ipairs(list) do
        if not isDown(code) then return false end
    end
    return true
end

function Bindings.IsComboActive(combo)
    return AllDown(combo.keys, Input.IsKeyDown) or AllDown(combo.btns, Input.IsButtonDown)
end

function Bindings.IsActionDown(action)
    local binding = Bindings.Actions[action]
    return binding ~= nil and Bindings.IsComboActive(binding)
end

function Bindings.EnsureAction(action)
    Bindings.Actions[action] = Bindings.Actions[action] or { keys = {}, btns = {} }
    return Bindings.Actions[action]
end

function Bindings.Rebind(action, binding)
    local current = Bindings.EnsureAction(action)
    if binding.keys then current.keys = Normalize(binding.keys) end
    if binding.btns then current.btns = Normalize(binding.btns) end
    return true
end

function Bindings.Clear(action, clearKeys, clearButtons)
    local current = Bindings.EnsureAction(action)
    if clearKeys then current.keys = {} end
    if clearButtons then current.btns = {} end
end

function Bindings.ResetAction(action)
    local default = Bindings.DefaultActions[action]
    if not default then return end
    Bindings.Actions[action] = Copy(default)
    require("Config/BindingsConfig").Save()
end

function Bindings.ResetAll()
    for action, binding in pairs(Bindings.DefaultActions) do
        Bindings.Actions[action] = Copy(binding)
    end
    require("Config/BindingsConfig").Save()
end

return Bindings
