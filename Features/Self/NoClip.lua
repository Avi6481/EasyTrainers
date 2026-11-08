local Input = require("Core/Input")
local InputBlock = require("Core/InputBlock")
local Logger = require("Core/Logger")
local State = require("Core/State")
local Landing = require("Utils/Landing")

local NoClip = {
    Enabled = false,
    Speed = 2,
    Boost = 4,
    FollowCamera = true,
    Controls = {}
}

NoClip.Actions = { "Forward", "Back", "Left", "Right", "Up", "Down", "Boost" }

local DEFAULT_CONTROLS = {
    Forward = { Keys = { Input.VK.W }, Buttons = {} },
    Back = { Keys = { Input.VK.S }, Buttons = {} },
    Left = { Keys = { Input.VK.A }, Buttons = {} },
    Right = { Keys = { Input.VK.D }, Buttons = {} },
    Up = { Keys = { Input.VK.Space }, Buttons = { Input.Button.RightShoulder } },
    Down = { Keys = { Input.VK.Control }, Buttons = { Input.Button.LeftShoulder } },
    Boost = { Keys = { Input.VK.Shift }, Buttons = { Input.Button.LeftStick } }
}

local OWNER = "NoClip"
local BASE_SPEED = 8
local MIN_SPEED = 0.5
local MAX_SPEED = 10
local SPEED_STEP = 0.5
local MAX_DELTA = 0.1
local MOUSE_SCALE = 1 / 35
local MOUSE_DEFAULT = 2.9
local PAD_RATE = 100
local PAD_DEFAULT = 10
local PAD_DEADZONE = 0.24

local ALWAYS_KEYS = { Input.VK.Space, Input.VK.Control }
local ALWAYS_BUTTONS = { Input.Button.A, Input.Button.B }

local SIDES = {
    [Input.VK.Shift] = { Input.VK.LShift, Input.VK.RShift },
    [Input.VK.Control] = { Input.VK.LControl, Input.VK.RControl },
    [Input.VK.Menu] = { Input.VK.LMenu, Input.VK.RMenu }
}

local s_Active = false
local s_Position = nil
local s_Yaw = 0
local s_LastClock = nil
local s_MouseSensitivity = 1
local s_PadSensitivity = 1
local s_MouseX = nil

local function Copy(binding)
    local copy = { Keys = {}, Buttons = {} }
    for index, key in ipairs(binding.Keys) do copy.Keys[index] = key end
    for index, button in ipairs(binding.Buttons) do copy.Buttons[index] = button end
    return copy
end

local function Valid(binding)
    return type(binding) == "table" and type(binding.Keys) == "table" and type(binding.Buttons) == "table"
end

local function FillControls()
    if type(NoClip.Controls) ~= "table" then NoClip.Controls = {} end

    for _, action in ipairs(NoClip.Actions) do
        if not Valid(NoClip.Controls[action]) then NoClip.Controls[action] = Copy(DEFAULT_CONTROLS[action]) end
    end
end

FillControls()

local function ComboDown(codes, down)
    if #codes == 0 then return false end
    for _, code in ipairs(codes) do
        if not down(code) then return false end
    end
    return true
end

local function Held(action)
    local binding = NoClip.Controls[action]
    return ComboDown(binding.Keys, Input.KeyDown) or ComboDown(binding.Buttons, Input.ButtonDown)
end

local function BlockSpec()
    local keys, seenKeys = {}, {}
    local buttons, seenButtons = 0, {}

    local function AddKey(vk)
        if seenKeys[vk] then return end
        seenKeys[vk] = true
        table.insert(keys, vk)
        for _, side in ipairs(SIDES[vk] or {}) do AddKey(side) end
    end

    local function AddButton(flag)
        if seenButtons[flag] then return end
        seenButtons[flag] = true
        buttons = buttons + flag
    end

    for _, vk in ipairs(ALWAYS_KEYS) do AddKey(vk) end
    for _, flag in ipairs(ALWAYS_BUTTONS) do AddButton(flag) end
    for _, action in ipairs(NoClip.Actions) do
        local binding = NoClip.Controls[action]
        for _, vk in ipairs(binding.Keys) do AddKey(vk) end
        for _, flag in ipairs(binding.Buttons) do AddButton(flag) end
    end

    return { Keys = keys, Buttons = buttons, Sticks = { Input.Stick.Left }, Wheel = true }
end

local function Setting(group, name, default)
    local ok, value = pcall(function()
        return Game.GetSettingsSystem():GetVar(group, name):GetValue()
    end)
    if not ok or type(value) ~= "number" or value <= 0 then return 1 end
    return value / default
end

local function WrapYaw(yaw)
    return ((yaw + 180) % 360) - 180
end

local function Axis(positive, negative)
    return (positive and 1 or 0) - (negative and 1 or 0)
end

local function Clamp(value)
    return math.max(-1, math.min(1, value))
end

local function Delta()
    local now = os.clock()
    local delta = s_LastClock and math.min(MAX_DELTA, now - s_LastClock) or 0
    s_LastClock = now
    return delta
end

local function Look(action)
    if not s_Active or not ListenerAction.IsAction(action, s_MouseX) then return end
    s_Yaw = WrapYaw(s_Yaw - (ListenerAction.GetValue(action) * MOUSE_SCALE * s_MouseSensitivity))
end

local function TurnWithStick(delta)
    local stick = Input.AxisValue(Input.Axis.RightX)
    if math.abs(stick) < PAD_DEADZONE then return end
    s_Yaw = WrapYaw(s_Yaw - (stick * PAD_RATE * s_PadSensitivity * delta))
end

local function ScrollSpeed()
    local wheel = Input.MouseWheel()
    if wheel == 0 then return end

    local speed = NoClip.Speed + ((wheel > 0 and 1 or -1) * SPEED_STEP)
    NoClip.Speed = math.max(MIN_SPEED, math.min(MAX_SPEED, speed))
end

local function Pitch(camera)
    if not NoClip.FollowCamera then return 0 end
    return Clamp(camera:GetActiveCameraForward().z)
end

local function Move(camera, delta)
    local stickX, stickY = Input.LeftStick()
    local forward = Clamp(Axis(Held("Forward"), Held("Back")) + stickY)
    local right = Clamp(Axis(Held("Right"), Held("Left")) + stickX)
    local up = Axis(Held("Up"), Held("Down"))
    if forward == 0 and right == 0 and up == 0 then return end

    local yaw = math.rad(s_Yaw)
    local climb = Pitch(camera)
    local level = math.sqrt(1 - (climb * climb))
    local step = BASE_SPEED * NoClip.Speed * (Held("Boost") and NoClip.Boost or 1) * delta

    local x = (-math.sin(yaw) * level * forward) + (math.cos(yaw) * right)
    local y = (math.cos(yaw) * level * forward) + (math.sin(yaw) * right)
    local z = (climb * forward) + up

    s_Position = Vector4.new(s_Position.x + (x * step), s_Position.y + (y * step), s_Position.z + (z * step), 1)
end

local function Start(player)
    local position = player:GetWorldPosition()
    s_Position = Vector4.new(position.x, position.y, position.z, 1)
    s_Yaw = player:GetWorldOrientation():ToEulerAngles().yaw
    s_MouseSensitivity = Setting("/controls/fppcameramouse", "FPP_MouseX", MOUSE_DEFAULT)
    s_PadSensitivity = Setting("/controls/fppcamerapad", "FPP_PadX", PAD_DEFAULT)
    s_LastClock = nil
    s_Active = true

    InputBlock.Hold(OWNER, BlockSpec())
    Landing.Hold(OWNER, true)
    Logger.Log("NoClip on")
end

local function Stop()
    if not s_Active then return end

    s_Active = false
    s_Position = nil
    InputBlock.Release(OWNER)
    Landing.Hold(OWNER, false)
    Logger.Log("NoClip off")
end

function NoClip.ApplyControls()
    FillControls()
    if s_Active then InputBlock.Hold(OWNER, BlockSpec()) end
end

function NoClip.ResetControls()
    NoClip.Controls = {}
    NoClip.ApplyControls()
end

function NoClip.Initialize()
    FillControls()
    Landing.Initialize()
    s_MouseX = CName.new("CameraMouseX")
    Observe("PlayerPuppet", "OnAction", function(_, action) Look(action) end)
end

function NoClip.Update(player)
    if not NoClip.Enabled or Game.GetMountedVehicle(player) then
        Stop()
        return
    end

    if not s_Active then Start(player) end

    local camera = Game.GetCameraSystem()
    if not camera then return end

    local delta = Delta()
    TurnWithStick(delta)
    if not State.Menu.Open and not State.OverlayOpen then
        ScrollSpeed()
        Move(camera, delta)
    end
    Game.GetTeleportationFacility():Teleport(player, s_Position, EulerAngles.new(0, 0, s_Yaw))
end

function NoClip.Reset()
    Stop()
    NoClip.Enabled = false
end

function NoClip.Shutdown()
    Stop()
end

return NoClip
