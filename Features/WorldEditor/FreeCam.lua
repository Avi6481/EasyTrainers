local Input = require("Core/Input")
local Mouse = require("Core/Mouse")
local Logger = require("Core/Logger")
local Cron = require("Core/cp2077-cet-kit/Cron")
local Bindings = require("Controls/Bindings")
local State = require("Controls/State")

local FreeCam = {}

FreeCam.MoveSpeed = { value = 8.0, min = 0.5, max = 150.0, step = 0.5, unit = "m/s" }
FreeCam.FastMultiplier = { value = 4.0, min = 1.0, max = 20.0, step = 0.5, unit = "x" }
FreeCam.SlowMultiplier = { value = 0.2, min = 0.05, max = 1.0, step = 0.05, unit = "x" }
FreeCam.Smoothing = { value = 10, min = 0, max = 30, step = 1 }
FreeCam.MouseSensitivity = { value = 1.0, min = 0.1, max = 5.0, step = 0.1, unit = "x" }
FreeCam.StickLookSpeed = { value = 120, min = 20, max = 400, step = 10, unit = "deg/s" }
FreeCam.InvertLook = { value = false }
FreeCam.FieldOfView = { value = 70, min = 20, max = 120, step = 1, unit = "deg" }
FreeCam.WheelAdjustsSpeed = { value = true }
FreeCam.GamepadDeadzone = { value = 7849, min = 0, max = 16000, step = 250 }
FreeCam.BlendTime = { value = 0.6, min = 0.0, max = 3.0, step = 0.1, unit = "s" }

FreeCam.Velocity = 0
FreeCam.SpeedMultiplier = 1
FreeCam.WheelLocked = false
FreeCam.LookLocked = false

local CAMERA_ENTITY = "base\\entities\\cameras\\simple_free_camera.ent"
local CAMERA_COMPONENT = "camera"
local COLLIDER_COMPONENT = "collider"
local SPAWN_TIMEOUT = 5.0
local MOUSE_DEGREES = 0.1
local PITCH_LIMIT = 89
local EYE_HEIGHT = 1.7
local WHEEL_STEP = 1.15
local DESPAWN_MARGIN = 0.2
local STICK_RANGE = 32768

local s_Phase = "Idle"
local s_EntityID = nil
local s_Entity = nil
local s_Camera = nil
local s_SpawnStarted = 0
local s_BaseZoom = nil
local s_Origin = nil
local s_Position = { x = 0, y = 0, z = 0 }
local s_Velocity = { x = 0, y = 0, z = 0 }
local s_Yaw = 0
local s_Pitch = 0
local s_MouseX = 0
local s_MouseY = 0
local s_LockedYaw = 0
local s_LockedPitch = 0

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function WrapYaw(yaw)
    yaw = yaw % 360
    if yaw > 180 then return yaw - 360 end
    return yaw
end

local function Orientation(yaw, pitch)
    local halfYaw, halfPitch = math.rad(yaw) * 0.5, math.rad(pitch) * 0.5
    local sinYaw, cosYaw = math.sin(halfYaw), math.cos(halfYaw)
    local sinPitch, cosPitch = math.sin(halfPitch), math.cos(halfPitch)
    return Quaternion.new(cosYaw * sinPitch, sinYaw * sinPitch, sinYaw * cosPitch, cosYaw * cosPitch)
end

local function Axes()
    local yaw, pitch = math.rad(s_Yaw), math.rad(s_Pitch)
    local cosPitch = math.cos(pitch)
    local forward = { x = -math.sin(yaw) * cosPitch, y = math.cos(yaw) * cosPitch, z = math.sin(pitch) }
    local right = { x = math.cos(yaw), y = math.sin(yaw), z = 0 }
    return forward, right
end

local function Stick(axis)
    local value = Input.GetGamepadAxis(axis)
    if math.abs(value) < FreeCam.GamepadDeadzone.value then return 0 end
    return value / STICK_RANGE
end

local function Axis(positive, negative)
    local value = 0
    if Bindings.IsActionDown(positive) then value = value + 1 end
    if Bindings.IsActionDown(negative) then value = value - 1 end
    return value
end

local function InputBlocked()
    return State.TypingEnabled or State.BindingKey
end

local function ReadMovement()
    if InputBlocked() then return 0, 0, 0 end

    local forward = Axis("EDITOR_FORWARD", "EDITOR_BACKWARD") + Stick(Input.GP_AXIS.LEFT_Y)
    local right = Axis("EDITOR_RIGHT", "EDITOR_LEFT") + Stick(Input.GP_AXIS.LEFT_X)
    local up = Axis("EDITOR_UP", "EDITOR_DOWN")
    return Clamp(forward, -1, 1), Clamp(right, -1, 1), up
end

local function UpdateLook(deltaTime)
    local mouseX, mouseY = s_MouseX, s_MouseY
    s_MouseX, s_MouseY = 0, 0
    if InputBlocked() or State.MouseEnabled then return end

    local invert = FreeCam.InvertLook.value and -1 or 1
    local mouseScale = MOUSE_DEGREES * FreeCam.MouseSensitivity.value
    local stickScale = FreeCam.StickLookSpeed.value * deltaTime
    local yawDelta = -mouseX * mouseScale - Stick(Input.GP_AXIS.RIGHT_X) * stickScale
    local pitchDelta = (mouseY * mouseScale + Stick(Input.GP_AXIS.RIGHT_Y) * stickScale) * invert

    if FreeCam.LookLocked then
        s_LockedYaw = s_LockedYaw + yawDelta
        s_LockedPitch = s_LockedPitch + pitchDelta
        return
    end

    s_Yaw = WrapYaw(s_Yaw + yawDelta)
    s_Pitch = Clamp(s_Pitch + pitchDelta, -PITCH_LIMIT, PITCH_LIMIT)
end

local function UpdateWheel()
    if FreeCam.WheelLocked or not FreeCam.WheelAdjustsSpeed.value or State.MouseEnabled or State.OverlayOpen then return end

    local wheel = Mouse.GetWheel()
    if wheel == 0 then return end
    local speed = FreeCam.MoveSpeed
    speed.value = Clamp(speed.value * (WHEEL_STEP ^ wheel), speed.min, speed.max)
end

local function SpeedMultiplier()
    if Bindings.IsActionDown("EDITOR_FAST") then return FreeCam.FastMultiplier.value end
    if Bindings.IsActionDown("EDITOR_SLOW") then return FreeCam.SlowMultiplier.value end
    return 1
end

local function UpdateMovement(deltaTime)
    UpdateWheel()
    FreeCam.SpeedMultiplier = SpeedMultiplier()

    local forwardInput, rightInput, upInput = ReadMovement()
    local forward, right = Axes()
    local speed = FreeCam.MoveSpeed.value * FreeCam.SpeedMultiplier
    local target = {
        x = (forward.x * forwardInput + right.x * rightInput) * speed,
        y = (forward.y * forwardInput + right.y * rightInput) * speed,
        z = (forward.z * forwardInput + upInput) * speed
    }

    local smoothing = FreeCam.Smoothing.value
    local blend = smoothing > 0 and math.min(1, deltaTime * smoothing) or 1
    for _, axis in ipairs({ "x", "y", "z" }) do
        s_Velocity[axis] = s_Velocity[axis] + (target[axis] - s_Velocity[axis]) * blend
        s_Position[axis] = s_Position[axis] + s_Velocity[axis] * deltaTime
    end
    FreeCam.Velocity = math.sqrt(s_Velocity.x ^ 2 + s_Velocity.y ^ 2 + s_Velocity.z ^ 2)
end

local function ApplyTransform()
    local origin = s_Origin or s_Entity:GetWorldPosition()
    local offset = Vector4.new(s_Position.x - origin.x, s_Position.y - origin.y, s_Position.z - origin.z, 1.0)
    s_Camera:SetLocalTransform(offset, Orientation(s_Yaw, s_Pitch))

    s_Camera:SetFOV(FreeCam.FieldOfView.value)
    if s_BaseZoom then pcall(function() s_Camera:SetZoom(s_BaseZoom) end) end
end

local function SpawnTransform()
    local transform = Game.GetPlayer():GetWorldTransform()
    transform:SetPosition(transform, Vector4.new(s_Position.x, s_Position.y, s_Position.z, 1.0))
    transform:SetOrientation(transform, Quaternion.new(0, 0, 0, 1))
    return transform
end

function FreeCam.AnglesFromForward(forward)
    local yaw = math.deg(math.atan2(-forward.x, forward.y))
    local pitch = math.deg(math.asin(Clamp(forward.z, -1, 1)))
    return yaw, pitch
end

local function CaptureStartView()
    local player = Game.GetPlayer()
    local origin = player:GetWorldPosition()
    s_Position = { x = origin.x, y = origin.y, z = origin.z + EYE_HEIGHT }

    local ok, forward = pcall(function() return Game.GetCameraSystem():GetActiveCameraForward() end)
    if ok and forward then
        local yaw, pitch = FreeCam.AnglesFromForward(forward)
        s_Yaw, s_Pitch = WrapYaw(yaw), Clamp(pitch, -PITCH_LIMIT, PITCH_LIMIT)
    else
        s_Yaw, s_Pitch = player:GetWorldOrientation():ToEulerAngles().yaw, 0
    end
    s_Velocity = { x = 0, y = 0, z = 0 }
end

local function Despawn(blendTime)
    local camera, entity = s_Camera, s_Entity
    blendTime = blendTime or 0

    if camera then pcall(function() camera:Deactivate(blendTime, false) end) end
    pcall(function() Game.GetPlayer():GetFPPCameraComponent():Activate(blendTime, false) end)
    if not entity then return end

    if blendTime <= 0 then
        pcall(exEntitySpawner.Despawn, entity)
        return
    end
    Cron.After(blendTime + DESPAWN_MARGIN, function() pcall(exEntitySpawner.Despawn, entity) end)
end

function FreeCam.Forget()
    s_Phase = "Idle"
    s_EntityID = nil
    s_Entity = nil
    s_Camera = nil
    s_BaseZoom = nil
    s_Origin = nil
    s_MouseX, s_MouseY = 0, 0
    s_LockedYaw, s_LockedPitch = 0, 0
    FreeCam.Velocity = 0
    FreeCam.LookLocked = false
end

local function Fail(reason)
    Logger.Log("FreeCam: " .. reason)
    Despawn()
    FreeCam.Forget()
end

local function TryAttach()
    local ok, entity = pcall(Game.FindEntityByID, s_EntityID)
    if not ok or not entity then
        if os.clock() - s_SpawnStarted > SPAWN_TIMEOUT then Fail("camera entity never appeared") end
        return
    end

    s_Entity = entity
    s_Camera = entity:FindComponentByName(CName.new(CAMERA_COMPONENT))
    if not s_Camera then
        Fail("spawned entity has no camera component")
        return
    end

    local collider = entity:FindComponentByName(CName.new(COLLIDER_COMPONENT))
    if collider then collider:Toggle(false) end

    local ok, zoom = pcall(function() return s_Camera:GetZoom() end)
    s_BaseZoom = ok and zoom or nil
    ApplyTransform()
    s_Camera:Activate(FreeCam.BlendTime.value, false)
    s_Phase = "Active"
    Logger.Log("FreeCam: camera entity active")
end

function FreeCam.IsActive()
    return s_Phase ~= "Idle"
end

function FreeCam.IsReady()
    return s_Phase == "Active"
end

function FreeCam.Start()
    if s_Phase ~= "Idle" then return true end
    if not Game.GetPlayer() then return false end

    CaptureStartView()
    local ok, entityID = pcall(exEntitySpawner.Spawn, CAMERA_ENTITY, SpawnTransform())
    if not ok or not entityID then
        Logger.Log("FreeCam: failed to spawn camera entity (" .. tostring(entityID) .. ")")
        return false
    end

    s_EntityID = entityID
    s_SpawnStarted = os.clock()
    s_Phase = "Spawning"
    Logger.Log("FreeCam: spawning camera entity")
    return true
end

function FreeCam.Stop()
    if s_Phase == "Idle" then return end
    Despawn(s_Phase == "Active" and FreeCam.BlendTime.value or 0)
    FreeCam.Forget()
    Logger.Log("FreeCam: stopped")
end

function FreeCam.HandleAction(action)
    if s_Phase ~= "Active" then return end

    local name = Game.NameToString(action:GetName(action))
    if name == "CameraMouseX" then
        s_MouseX = s_MouseX + action:GetValue(action)
    elseif name == "CameraMouseY" then
        s_MouseY = s_MouseY + action:GetValue(action)
    end
end

function FreeCam.ResetToPlayer()
    if s_Phase ~= "Active" then return end

    local player = Game.GetPlayer()
    local origin = player:GetWorldPosition()
    s_Position = { x = origin.x, y = origin.y, z = origin.z + EYE_HEIGHT }
    s_Yaw, s_Pitch = player:GetWorldOrientation():ToEulerAngles().yaw, 0
    s_Velocity = { x = 0, y = 0, z = 0 }
end

function FreeCam.Rebase()
    if s_Phase ~= "Active" or not EasyEntityTools then return end
    local position = Vector4.new(s_Position.x, s_Position.y, s_Position.z, 1.0)
    local ok, moved = pcall(function() return EasyEntityTools.SetWorldTransform(s_Entity, position, Quaternion.new(0, 0, 0, 1)) end)
    if not ok or not moved then return end
    s_Origin = { x = s_Position.x, y = s_Position.y, z = s_Position.z }
    pcall(ApplyTransform)
end

function FreeCam.GetPosition()
    return { x = s_Position.x, y = s_Position.y, z = s_Position.z }
end

function FreeCam.GetRotation()
    return s_Yaw, s_Pitch
end

function FreeCam.GetForward()
    local forward = Axes()
    return forward
end

function FreeCam.ConsumeLockedLook()
    local yaw, pitch = s_LockedYaw, s_LockedPitch
    s_LockedYaw, s_LockedPitch = 0, 0
    return yaw, pitch
end

function FreeCam.GetRight()
    local _, right = Axes()
    return right
end

function FreeCam.Tick(deltaTime)
    if s_Phase == "Spawning" then
        TryAttach()
        return
    end
    if s_Phase ~= "Active" then return end

    UpdateLook(deltaTime)
    UpdateMovement(deltaTime)

    local ok, err = pcall(ApplyTransform)
    if not ok then Fail("failed to move camera (" .. tostring(err) .. ")") end
end

return FreeCam
