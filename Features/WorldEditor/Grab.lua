local Input = require("Core/Input")
local Mouse = require("Core/Mouse")
local Bindings = require("Controls/Bindings")
local State = require("Controls/State")
local Physics = require("Utils/Physics")
local Rotation = require("Utils/Rotation")
local Notification = require("UI/Panels/Notification/Notification")
local FreeCam = require("Features/WorldEditor/FreeCam")
local Inspector = require("Features/WorldEditor/Inspector")
local Selection = require("Features/WorldEditor/Selection")
local Grabbables = require("Features/WorldEditor/Grabbables")
local Attachments = require("Features/WorldEditor/Attachments")
local Scene = require("Features/WorldEditor/Scene")

local Grab = {}

Grab.HoldDelay = { value = 0.25, min = 0.1, max = 1.0, step = 0.05, unit = "s" }
Grab.KeepFacing = { value = true }
Grab.SnapPedsToGround = { value = true }
Grab.NudgeSpeed = { value = 0.5, min = 0.05, max = 5.0, step = 0.05, unit = "m/s" }
Grab.RotateSpeed = { value = 1.0, min = 0.1, max = 5.0, step = 0.1, unit = "x" }

local MIN_DISTANCE = 1.5
local MAX_DISTANCE = 80
local WHEEL_STEP = 1.12
local SETTLE_DELAY = 0.3
local MOUSE_KEYS = { [Input.VK.LBUTTON] = Mouse.IsDown, [Input.VK.RBUTTON] = Mouse.IsRightDown }

local s_Carry = nil
local s_Adjust = nil
local s_Press = nil
local s_ButtonHeld = false
local s_GroundHeld = false

local function Safe(callback)
    local ok, value = pcall(callback)
    if ok then return value end
    return nil
end

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function Distance(a, b)
    return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
end

local function InputAllowed()
    return not State.MouseEnabled and not State.OverlayOpen and not State.TypingEnabled and not State.BindingKey
end

local function MouseFallback(action)
    local binding = Bindings.Actions[action]
    for _, key in ipairs(binding and binding.keys or {}) do
        local isDown = MOUSE_KEYS[key]
        if isDown and isDown() then return true end
    end
    return false
end

local function IsDown(action)
    if not InputAllowed() then return false end
    return Bindings.IsActionDown(action) or MouseFallback(action)
end

local function Axis(positive, negative)
    local value = 0
    if IsDown(positive) then value = value + 1 end
    if IsDown(negative) then value = value - 1 end
    return value
end

local function EntityRotation(entity)
    local orientation = Safe(function() return entity:GetWorldOrientation() end)
    if orientation then return Rotation.FromQuaternion(orientation) end
    return Rotation.FromYaw(Safe(function() return entity:GetWorldYaw() end) or 0)
end

local function Turn(rotation, yaw, pitch)
    if yaw == 0 and pitch == 0 then return rotation end
    local turned = Rotation.Multiply(Rotation.FromYaw(yaw), rotation)
    turned = Rotation.Multiply(Rotation.FromAxisAngle(FreeCam.GetRight(), -pitch), turned)
    return Rotation.Normalize(turned)
end

local function ReleaseOptions(entity)
    local attached = Attachments.IsAttached(entity)
    return { SnapToGround = Grab.SnapPedsToGround.value and not attached, KeepCollision = attached }
end

local function EndAdjust()
    if not s_Adjust then return end
    if s_Adjust.Held then Physics.Release(s_Adjust.Held, ReleaseOptions(s_Adjust.Entity)) end
    s_Adjust = nil
end

local function BlockAdjust(message)
    if s_Adjust.Held then Physics.Release(s_Adjust.Held, {}) end
    s_Adjust.Held = nil
    s_Adjust.Blocked = true
    Notification.Warning(message)
end

local function BeginAdjust(selected)
    if s_Adjust and s_Adjust.Entity == selected.Entity then
        if s_Adjust.Blocked then return nil end
        return s_Adjust
    end
    EndAdjust()

    local entity = selected.Entity
    local position = Safe(function() return entity:GetWorldPosition() end)
    if not position then return nil end

    s_Adjust = {
        Entity = entity,
        Position = { x = position.x, y = position.y, z = position.z },
        Rotation = EntityRotation(entity),
        LastInput = os.clock()
    }
    if selected.Kind == "Vehicle" and not Physics.LeaveTraffic(entity) then
        BlockAdjust("This car couldn't be taken out of traffic, so it can't be moved.")
        return nil
    end
    s_Adjust.Held = Physics.Hold(entity, selected.Kind)
    Scene.Add(entity, selected.Name, selected.Kind)
    return s_Adjust
end

local function StartCarry(target)
    local entity = target.Entity
    EndAdjust()
    if target.Kind == "Vehicle" and not Physics.LeaveTraffic(entity) then
        Notification.Warning("This car couldn't be taken out of traffic, so it can't be picked up.")
        return
    end

    local position = entity:GetWorldPosition()
    s_Carry = {
        Target = target,
        Held = Physics.Hold(entity, target.Kind),
        Distance = Clamp(Distance(FreeCam.GetPosition(), position), MIN_DISTANCE, MAX_DISTANCE),
        Rotation = EntityRotation(entity),
        CameraYaw = (FreeCam.GetRotation())
    }
    Selection.Select(target)
    Scene.Add(entity, target.DisplayName or target.Record or target.ClassName, target.Kind)
    FreeCam.WheelLocked = true
end

function Grab.Drop()
    EndAdjust()
    if not s_Carry then return end
    Physics.Release(s_Carry.Held, ReleaseOptions(s_Carry.Held.Entity))
    s_Carry = nil
    FreeCam.WheelLocked = false
end

function Grab.IsHolding()
    return s_Carry ~= nil
end

local function SameEntity(a, b)
    local hash = a and Safe(function() return tostring(a:GetEntityID().hash) end)
    return hash ~= nil and b ~= nil and hash == Safe(function() return tostring(b:GetEntityID().hash) end)
end

function Grab.IsMoving(entity)
    return (s_Carry ~= nil and SameEntity(s_Carry.Held.Entity, entity)) or (s_Adjust ~= nil and SameEntity(s_Adjust.Entity, entity))
end

function Grab.IsGrounded()
    return s_Carry ~= nil and s_Carry.Grounded == true
end

function Grab.CanNudge()
    return not State.MenuOpen
end

function Grab.GetTarget()
    return s_Carry and s_Carry.Target or nil
end

function Grab.GetDistance()
    return s_Carry and s_Carry.Distance or 0
end

function Grab.Forget()
    s_Carry = nil
    s_Adjust = nil
    s_Press = nil
    s_ButtonHeld = false
    s_GroundHeld = false
    FreeCam.WheelLocked = false
    FreeCam.LookLocked = false
end

local function ReadRotation(active)
    FreeCam.LookLocked = active
    local yaw, pitch = FreeCam.ConsumeLockedLook()
    if not active then return 0, 0 end

    local scale = Grab.RotateSpeed.value
    if Bindings.IsActionDown("EDITOR_SLOW") then scale = scale * FreeCam.SlowMultiplier.value end
    return yaw * scale, pitch * scale
end

local function Carry(yaw, pitch, grounded)
    local wheel = InputAllowed() and Mouse.GetWheel() or 0
    if wheel ~= 0 then s_Carry.Distance = Clamp(s_Carry.Distance * (WHEEL_STEP ^ wheel), MIN_DISTANCE, MAX_DISTANCE) end

    local cameraYaw = FreeCam.GetRotation()
    if Grab.KeepFacing.value then yaw = yaw + cameraYaw - s_Carry.CameraYaw end
    s_Carry.CameraYaw = cameraYaw
    s_Carry.Rotation = Turn(s_Carry.Rotation, yaw, pitch)

    local camera = FreeCam.GetPosition()
    local forward = FreeCam.GetForward()
    local distance = s_Carry.Distance
    local x, y, z = camera.x + forward.x * distance, camera.y + forward.y * distance, camera.z + forward.z * distance

    local entity = s_Carry.Held.Entity
    s_Carry.Grounded = false
    if grounded then
        local ground = Physics.FindGround({ x = x, y = y, z = math.max(camera.z, z) }, entity)
        if ground then
            z = ground - Grabbables.GetBottom(entity, s_Carry.Rotation)
            s_Carry.Grounded = true
        end
    end

    if not Physics.Move(s_Carry.Held, Vector4.new(x, y, z, 1.0), s_Carry.Rotation) then
        Notification.Warning("This entity can't be moved.")
        Grab.Drop()
    end
end

local function NudgeInput()
    if not Grab.CanNudge() then return 0, 0 end
    return Axis("EDITOR_ADJUST_FORWARD", "EDITOR_ADJUST_BACKWARD"), Axis("EDITOR_ADJUST_RIGHT", "EDITOR_ADJUST_LEFT")
end

local function Adjust(deltaTime, yaw, pitch, groundPressed)
    local selected = Selection.Count() == 1 and Selection.Get() or nil
    if not selected or not selected.Entity then
        EndAdjust()
        return
    end
    if s_Adjust and s_Adjust.Entity ~= selected.Entity then EndAdjust() end

    local forward, right = NudgeInput()
    if forward == 0 and right == 0 and yaw == 0 and pitch == 0 and not groundPressed then
        if s_Adjust and not s_Adjust.Blocked and os.clock() - s_Adjust.LastInput > SETTLE_DELAY then EndAdjust() end
        return
    end

    local adjust = BeginAdjust(selected)
    if not adjust then return end
    adjust.LastInput = os.clock()

    local radians = math.rad((FreeCam.GetRotation()))
    local step = Grab.NudgeSpeed.value * FreeCam.SpeedMultiplier * deltaTime
    adjust.Position.x = adjust.Position.x + (-math.sin(radians) * forward + math.cos(radians) * right) * step
    adjust.Position.y = adjust.Position.y + (math.cos(radians) * forward + math.sin(radians) * right) * step
    adjust.Rotation = Turn(adjust.Rotation, yaw, pitch)

    if groundPressed then
        local bottom = Grabbables.GetBottom(adjust.Entity, adjust.Rotation)
        local ground = Physics.GroundBelow({ x = adjust.Position.x, y = adjust.Position.y, z = adjust.Position.z + bottom }, adjust.Entity)
        if ground then adjust.Position.z = ground - bottom end
    end

    local position = Vector4.new(adjust.Position.x, adjust.Position.y, adjust.Position.z, 1.0)
    if not Physics.Place(adjust.Entity, position, adjust.Rotation) then BlockAdjust("This entity can't be moved.") end
end

local function Click(target)
    if target and target.Entity then
        Selection.Select(target)
    else
        Selection.Clear()
    end
end

function Grab.Tick(deltaTime)
    if not FreeCam.IsReady() then
        Grab.Drop()
        s_Press = nil
        s_ButtonHeld = false
        s_GroundHeld = false
        FreeCam.LookLocked = false
        return
    end

    local down = IsDown("EDITOR_SELECT")
    local now = os.clock()

    if down and not s_ButtonHeld then s_Press = { Time = now, Target = Inspector.Target, Multi = IsDown("EDITOR_MULTI") } end

    if down and s_Press and not s_Press.Carried and not s_Press.Multi and now - s_Press.Time >= Grab.HoldDelay.value then
        s_Press.Carried = true
        local target = s_Press.Target
        if target and target.Entity then StartCarry(target) end
    end

    if not down and s_ButtonHeld then
        if s_Carry then
            Grab.Drop()
        elseif s_Press and s_Press.Multi then
            Selection.Toggle(s_Press.Target)
        elseif s_Press and not s_Press.Carried then
            Click(s_Press.Target)
        end
        s_Press = nil
    end
    s_ButtonHeld = down

    local hasSubject = s_Carry ~= nil or Selection.Count() == 1
    local yaw, pitch = ReadRotation(hasSubject and IsDown("EDITOR_ROTATE"))
    local ground = IsDown("EDITOR_GROUND")
    local groundPressed = ground and not s_GroundHeld
    s_GroundHeld = ground

    if s_Carry then
        Carry(yaw, pitch, ground)
    else
        Adjust(deltaTime or 0, yaw, pitch, groundPressed)
    end
end

return Grab
