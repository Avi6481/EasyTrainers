local Input = require("Core/Input")
local State = require("Core/State")
local Notify = require("Utils/Notify")
local Controls = require("Features/WorldEditor/Controls")
local Physics = require("Features/WorldEditor/Physics")
local Rotation = require("Features/WorldEditor/Rotation")
local Entities = require("Features/WorldEditor/Entities")
local FreeCam = require("Features/WorldEditor/FreeCam")
local Inspector = require("Features/WorldEditor/Inspector")
local Selection = require("Features/WorldEditor/Selection")
local Grabbables = require("Features/WorldEditor/Grabbables")
local Attachments = require("Features/WorldEditor/Attachments")
local Scene = require("Features/WorldEditor/Scene")
local Changes = require("Features/WorldEditor/Changes")

local Grab = {
    HoldDelay = 0.25,
    KeepFacing = true,
    SnapPedsToGround = true,
    NudgeSpeed = 0.5,
    RotateSpeed = 1.0
}

local MIN_DISTANCE = 1.5
local MAX_DISTANCE = 80
local WHEEL_STEP = 1.12
local DISTANCE_RATE = 2
local SETTLE_DELAY = 0.3

local s_Carry = nil
local s_Adjust = nil
local s_Press = nil
local s_ButtonHeld = false
local s_GroundHeld = false

local Safe = Entities.Safe
local SameEntity = Entities.Same

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function Distance(a, b)
    return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
end

local function InputAllowed()
    return not (State.Menu.Open and State.Menu.Cursor) and not Controls.Blocked()
end

local function IsDown(action)
    return InputAllowed() and Controls.Held(action)
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
    return { SnapToGround = Grab.SnapPedsToGround and not attached, KeepCollision = attached }
end

local function DisableCollision(entity)
    if Attachments.IsAttached(entity) then return nil end
    return Physics.DisableCollision(entity)
end

local function EndAdjust()
    if not s_Adjust then return end
    Physics.RestoreCollision(s_Adjust.Collision)
    if s_Adjust.Held then
        Physics.Release(s_Adjust.Held, ReleaseOptions(s_Adjust.Entity))
        Changes.Mark()
    end
    Attachments.EndMove(s_Adjust.Entity)
    s_Adjust = nil
end

local function BlockAdjust(message)
    Physics.RestoreCollision(s_Adjust.Collision)
    s_Adjust.Collision = nil
    if s_Adjust.Held then Physics.Release(s_Adjust.Held, {}) end
    Attachments.EndMove(s_Adjust.Entity)
    s_Adjust.Held = nil
    s_Adjust.Blocked = true
    Notify.Warning(message)
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
        BlockAdjust(L("notify.worldeditor.traffic.move"))
        return nil
    end
    Attachments.BeginMove(entity)
    s_Adjust.Held = Physics.Hold(entity, selected.Kind)
    s_Adjust.Collision = DisableCollision(entity)
    Scene.Add(entity, selected.Name, selected.Kind)
    return s_Adjust
end

local function StartCarry(target)
    local entity = target.Entity
    EndAdjust()
    if target.Kind == "Vehicle" and not Physics.LeaveTraffic(entity) then
        Notify.Warning(L("notify.worldeditor.traffic.carry"))
        return
    end

    Attachments.BeginMove(entity)
    local position = entity:GetWorldPosition()
    s_Carry = {
        Target = target,
        Held = Physics.Hold(entity, target.Kind),
        Distance = Clamp(Distance(FreeCam.GetPosition(), position), MIN_DISTANCE, MAX_DISTANCE),
        Rotation = EntityRotation(entity),
        CameraYaw = (FreeCam.GetRotation()),
        Collision = DisableCollision(entity)
    }
    Selection.Select(target)
    Scene.Add(entity, target.DisplayName or target.Record or target.ClassName, target.Kind)
    FreeCam.WheelLocked = true
end

function Grab.Drop()
    EndAdjust()
    if not s_Carry then return end
    Physics.RestoreCollision(s_Carry.Collision)
    Physics.Release(s_Carry.Held, ReleaseOptions(s_Carry.Held.Entity))
    Attachments.EndMove(s_Carry.Held.Entity)
    Changes.Mark()
    s_Carry = nil
    FreeCam.WheelLocked = false
end

function Grab.IsHolding()
    return s_Carry ~= nil
end

function Grab.IsBusy()
    return s_Carry ~= nil or (s_Adjust ~= nil and not s_Adjust.Blocked)
end

function Grab.IsMoving(entity)
    return (s_Carry ~= nil and SameEntity(s_Carry.Held.Entity, entity)) or (s_Adjust ~= nil and SameEntity(s_Adjust.Entity, entity))
end

function Grab.IsGrounded()
    return s_Carry ~= nil and s_Carry.Grounded == true
end

function Grab.CanNudge()
    return not State.Menu.Open
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

    local scale = Grab.RotateSpeed
    if Controls.Held("Slow") then scale = scale * FreeCam.SlowMultiplier end
    return yaw * scale, pitch * scale
end

local function NudgeInput()
    if not Grab.CanNudge() then return 0, 0 end
    return Axis("NudgeForward", "NudgeBack"), Axis("NudgeRight", "NudgeLeft")
end

local function Wheel()
    if State.Menu.Open or State.OverlayOpen then return 0 end
    return Input.MouseWheel()
end

local function Carry(delta, yaw, pitch, grounded)
    local wheel = Wheel()
    if wheel ~= 0 then s_Carry.Distance = Clamp(s_Carry.Distance * (WHEEL_STEP ^ wheel), MIN_DISTANCE, MAX_DISTANCE) end
    local push = NudgeInput()
    if push ~= 0 then
        local scale = DISTANCE_RATE ^ (push * FreeCam.SpeedMultiplier * delta)
        s_Carry.Distance = Clamp(s_Carry.Distance * scale, MIN_DISTANCE, MAX_DISTANCE)
    end

    local cameraYaw = FreeCam.GetRotation()
    if Grab.KeepFacing then yaw = yaw + cameraYaw - s_Carry.CameraYaw end
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
        Notify.Warning(L("notify.worldeditor.cantmove"))
        Grab.Drop()
    end
end

local function Adjust(delta, yaw, pitch, groundPressed)
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
    local step = Grab.NudgeSpeed * FreeCam.SpeedMultiplier * delta
    adjust.Position.x = adjust.Position.x + (-math.sin(radians) * forward + math.cos(radians) * right) * step
    adjust.Position.y = adjust.Position.y + (math.cos(radians) * forward + math.sin(radians) * right) * step
    adjust.Rotation = Turn(adjust.Rotation, yaw, pitch)

    if groundPressed then
        local bottom = Grabbables.GetBottom(adjust.Entity, adjust.Rotation)
        local ground = Physics.GroundBelow({ x = adjust.Position.x, y = adjust.Position.y, z = adjust.Position.z + bottom }, adjust.Entity)
        if ground then adjust.Position.z = ground - bottom end
    end

    local position = Vector4.new(adjust.Position.x, adjust.Position.y, adjust.Position.z, 1.0)
    if not Physics.Place(adjust.Entity, position, adjust.Rotation) then BlockAdjust(L("notify.worldeditor.cantmove")) end
end

local function Click(target)
    if target and target.Entity then
        Selection.Select(target)
    else
        Selection.Clear()
    end
end

function Grab.Tick(delta)
    if not FreeCam.IsReady() then
        Grab.Drop()
        s_Press = nil
        s_ButtonHeld = false
        s_GroundHeld = false
        FreeCam.LookLocked = false
        return
    end

    local down = IsDown("Select")
    local now = os.clock()

    if down and not s_ButtonHeld then s_Press = { Time = now, Target = Inspector.Target } end

    if down and s_Press and not s_Press.Carried and now - s_Press.Time >= Grab.HoldDelay then
        s_Press.Carried = true
        local target = s_Press.Target
        if target and target.Entity then StartCarry(target) end
    end

    if not down and s_ButtonHeld then
        if s_Carry then
            Grab.Drop()
        elseif s_Press and not s_Press.Carried then
            Click(s_Press.Target)
        end
        s_Press = nil
    end
    s_ButtonHeld = down

    local hasSubject = s_Carry ~= nil or Selection.Count() == 1
    local yaw, pitch = ReadRotation(hasSubject and IsDown("Rotate"))
    local ground = IsDown("Ground")
    local groundPressed = ground and not s_GroundHeld
    s_GroundHeld = ground

    if s_Carry then
        Carry(delta or 0, yaw, pitch, ground)
    else
        Adjust(delta or 0, yaw, pitch, groundPressed)
    end
end

return Grab
