local Input = require("Core/Input")
local Utils = require("Utils")
local StatusEffect = Utils.StatusEffect
local Teleport = Utils.Teleport
local Bindings = require("Controls/Bindings")
local Noclip = {}
Noclip.toggleNoClip = { value = false }
Noclip.moveSpeed = { value = 1.5, min = 0.25, max = 10.0, step = 0.25 }
Noclip.verticalSpeed = { value = 1.0, min = 0.25, max = 5.0, step = 0.25 }
Noclip.boostMultiplier = { value = 2.5, min = 1.0, max = 8.0, step = 0.25 }
Noclip.precisionMultiplier = { value = 0.7, min = 0.1, max = 1.0, step = 0.05 }
Noclip.gamepadDeadzone = { value = 7849, min = 0, max = 16000, step = 250 }

local yaw = 0
local noclipRestrictions = {
    "GameplayRestriction.NoZooming",
    "GameplayRestriction.NoMovement",
    "GameplayRestriction.NoCombat",
    "GameplayRestriction.InDaClub",
    "GameplayRestriction.NoJump",
    "GameplayRestriction.NoFallDamage",
}

local noclipWasOn = false

local function ApplyNoclipRestrictions(enable)
    for _, eff in ipairs(noclipRestrictions) do
        StatusEffect.Set(eff, enable)
    end
end

local function RemoveRestriction()
    if not Noclip.toggleNoClip.value and noclipWasOn then
        ApplyNoclipRestrictions(false)
        noclipWasOn = false
    end
end

function Noclip.HandleMouseLook(action)
    local actionName = Game.NameToString(action:GetName(action))
    if actionName ~= "CameraMouseX" then return end

    local x = action:GetValue(action)
    local sens = Game.GetSettingsSystem():GetVar("/controls/fppcameramouse", "FPP_MouseX"):GetValue() / 2.9
    yaw = yaw - (x / 35) * sens
end

function Noclip.Tick()
    RemoveRestriction()
    if not Noclip.toggleNoClip.value then return end

    local player = Game.GetPlayer()
    if not player then return end

    -- initialize yaw once when toggling on
    if not noclipWasOn then
        local rot = player:GetWorldOrientation():ToEulerAngles()
        yaw = rot.yaw
    end

    ApplyNoclipRestrictions(true)
    noclipWasOn = true

    -- input axes
    local lx = Input.GetGamepadAxis(Input.GP_AXIS.LEFT_X)
    local ly = -Input.GetGamepadAxis(Input.GP_AXIS.LEFT_Y)
    local rx = Input.GetGamepadAxis(Input.GP_AXIS.RIGHT_X)

    local deadzone = Noclip.gamepadDeadzone.value
    if math.abs(lx) < deadzone then lx = 0 end
    if math.abs(ly) < deadzone then ly = 0 end

    if math.abs(rx) > deadzone then
        local sens = Game.GetSettingsSystem():GetVar("/controls/fppcamerapad", "FPP_PadX"):GetValue() / 10
        yaw = yaw - (rx / 32768) * 1.7 * sens
    end

    -- button inputs
    local goUp = Bindings.IsActionDown("NOCLIP_UP")
    local goDown = Bindings.IsActionDown("NOCLIP_DOWN")
    local speedBoost = Bindings.IsActionDown("NOCLIP_BOOST")

    local forward = Bindings.IsActionDown("NOCLIP_FORWARD") or ly < 0
    local backward = Bindings.IsActionDown("NOCLIP_BACKWARD") or ly > 0
    local strafeL = Bindings.IsActionDown("NOCLIP_LEFT") or lx < 0
    local strafeR = Bindings.IsActionDown("NOCLIP_RIGHT") or lx > 0

    local frameSpeed = Noclip.moveSpeed.value
        * (speedBoost and Noclip.boostMultiplier.value or Noclip.precisionMultiplier.value)
    local verticalSpeed = Noclip.verticalSpeed.value
        * (speedBoost and Noclip.boostMultiplier.value or Noclip.precisionMultiplier.value)

    local pos = player:GetWorldPosition()
    if forward then
        local fwd = Teleport.GetForwardOffset(frameSpeed, yaw)
        pos.x, pos.y = fwd.x, fwd.y
    end
    if backward then
        local back = Teleport.GetForwardOffset(-frameSpeed, yaw)
        pos.x, pos.y = back.x, back.y
    end
    if strafeR then
        local right = Teleport.GetRightOffset(-frameSpeed, yaw)
        pos.x, pos.y = right.x, right.y
    end
    if strafeL then
        local left = Teleport.GetRightOffset(frameSpeed, yaw)
        pos.x, pos.y = left.x, left.y
    end

    if goUp then pos.z = pos.z + verticalSpeed end
    if goDown then pos.z = pos.z - verticalSpeed end

    if yaw < 0 then yaw = yaw + 360 end
    if yaw > 360 then yaw = yaw - 360 end

    local rot = player:GetWorldOrientation():ToEulerAngles()
    rot.yaw = yaw
    Teleport.TeleportEntity(player, Vector4.new(pos.x, pos.y, pos.z, 1.0), rot)
end

return Noclip
