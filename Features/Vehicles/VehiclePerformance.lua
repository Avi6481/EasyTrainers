local Logger = require("Core/Logger")
local Lifecycle = require("Core/Lifecycle")
local Input = require("Core/Input")
local Vehicle = require("Utils/Vehicle")
local PresetStore = require("Utils/PresetStore")

local VehiclePerformance = {}

VehiclePerformance.Enabled = { value = false }
VehiclePerformance.TopSpeedBonus = { value = 0, min = 0, max = 400, step = 10, unit = "km/h" }
VehiclePerformance.Acceleration = { value = 0, min = 0, max = 30, step = 0.5, unit = "m/s²" }
VehiclePerformance.Braking = { value = 0, min = 0, max = 40, step = 1, unit = "m/s²" }
VehiclePerformance.Downforce = { value = 0, min = 0, max = 30, step = 1, unit = "m/s²" }
VehiclePerformance.EnginePower = { value = 1.0, min = 0.5, max = 5.0, step = 0.1, unit = "x" }
VehiclePerformance.ShiftSpeed = { value = 1.0, min = 1.0, max = 10.0, step = 0.5, unit = "x" }
VehiclePerformance.FrontGrip = { value = 1.0, min = 0.3, max = 3.0, step = 0.1, unit = "x" }
VehiclePerformance.RearGrip = { value = 1.0, min = 0.3, max = 3.0, step = 0.1, unit = "x" }
VehiclePerformance.SteeringLock = { value = 1.0, min = 0.5, max = 2.0, step = 0.05, unit = "x" }
VehiclePerformance.Handbrake = { value = 1.0, min = 0.5, max = 5.0, step = 0.1, unit = "x" }
VehiclePerformance.AirControl = { value = false }

local KEY_W = 0x57
local KEY_S = 0x53
local TRIGGER_THRESHOLD = 0.1
local FALLBACK_MASS = 1500.0
local TOP_SPEED_PUSH = 9.0
local NEAR_TOP_SPEED = 0.9
local MIN_BRAKE_SPEED = 1.0
local DOWNFORCE_FULL_SPEED = 40.0
local MS_TO_KPH = 3.6
local STATS_INTERVAL = 0.25

local RECORD_TUNABLES = {
    { Ref = VehiclePerformance.ShiftSpeed, Source = "Engine", Field = "gearChangeTime", Invert = true },
    { Ref = VehiclePerformance.ShiftSpeed, Source = "Engine", Field = "gearChangeCooldown", Invert = true },
    { Ref = VehiclePerformance.EnginePower, Source = "Engine", Field = "engineMaxTorque" },
    { Ref = VehiclePerformance.FrontGrip, Source = "Front", Field = "tireFrictionCoef" },
    { Ref = VehiclePerformance.RearGrip, Source = "Rear", Field = "tireFrictionCoef" },
    { Ref = VehiclePerformance.SteeringLock, Source = "Drive", Field = "maxWheelTurnDeg" },
    { Ref = VehiclePerformance.Handbrake, Source = "Drive", Field = "handbrakeBrakingTorque" }
}

local s_Originals = {}
local s_AppliedHash = nil
local s_AppliedValues = {}
local s_Stats = nil
local s_NextStats = 0
local s_RecordHash = nil
local s_StockTopSpeed = nil
local s_StockCache = {}
local s_AirVehicle = nil
local s_AirOriginal = nil

VehiclePerformance.Presets = PresetStore.Create("Config/JSON/VehiclePerformancePresets.json", {
    TopSpeedBonus = VehiclePerformance.TopSpeedBonus,
    Acceleration = VehiclePerformance.Acceleration,
    Braking = VehiclePerformance.Braking,
    Downforce = VehiclePerformance.Downforce,
    EnginePower = VehiclePerformance.EnginePower,
    ShiftSpeed = VehiclePerformance.ShiftSpeed,
    FrontGrip = VehiclePerformance.FrontGrip,
    RearGrip = VehiclePerformance.RearGrip,
    SteeringLock = VehiclePerformance.SteeringLock,
    Handbrake = VehiclePerformance.Handbrake
})

local function FlatID(recordID, field)
    return TweakDBID.new(recordID, "." .. field)
end

local function FlatKey(recordID, field)
    return tostring(recordID.hash) .. ":" .. tostring(recordID.length) .. field
end

local function StockFlat(recordID, field)
    if not recordID then return nil end
    local original = s_Originals[FlatKey(recordID, field)]
    if original then return original.Value end
    local value = TweakDB:GetFlat(FlatID(recordID, field))
    return type(value) == "number" and value or nil
end

local function ScaleFlat(recordID, field, scale)
    local flatID = FlatID(recordID, field)
    local key = FlatKey(recordID, field)
    if not s_Originals[key] then
        local original = TweakDB:GetFlat(flatID)
        if type(original) ~= "number" then return end
        s_Originals[key] = { Flat = flatID, Record = recordID, Value = original }
    end

    TweakDB:SetFlat(flatID, s_Originals[key].Value * scale)
    TweakDB:Update(recordID)
end

local function RestoreRecords()
    for key, original in pairs(s_Originals) do
        pcall(function()
            TweakDB:SetFlat(original.Flat, original.Value)
            TweakDB:Update(original.Record)
        end)
        s_Originals[key] = nil
    end
    s_AppliedHash = nil
end

local function SourceIDs(record)
    local ids = {}
    local engine = record:VehEngineData()
    local drive = record:VehDriveModelData()
    local wheels = drive and drive:WheelSetup() or nil
    ids.Engine = engine and engine:GetID() or nil
    ids.Drive = drive and drive:GetID() or nil
    ids.Front = wheels and wheels:FrontPreset() and wheels:FrontPreset():GetID() or nil
    ids.Rear = wheels and wheels:BackPreset() and wheels:BackPreset():GetID() or nil
    return ids
end

local function ApplyRecords(record)
    local ids = SourceIDs(record)
    for _, tunable in ipairs(RECORD_TUNABLES) do
        local recordID = ids[tunable.Source]
        local value = tunable.Ref.value
        if recordID and value ~= 1 then ScaleFlat(recordID, tunable.Field, tunable.Invert and 1 / value or value) end
    end
end

local function ValuesChanged()
    for index, tunable in ipairs(RECORD_TUNABLES) do
        if s_AppliedValues[index] ~= tunable.Ref.value then return true end
    end
    return false
end

local function SyncRecords(vehicle)
    local hash = vehicle:GetRecordID().hash
    if hash == s_AppliedHash and not ValuesChanged() then return end

    RestoreRecords()
    local ok, err = pcall(ApplyRecords, vehicle:GetRecord())
    if not ok then Logger.Log("VehiclePerformance: record tuning failed (" .. tostring(err) .. ")") end
    s_AppliedHash = hash
    for index, tunable in ipairs(RECORD_TUNABLES) do s_AppliedValues[index] = tunable.Ref.value end
end

local function ReleaseAirControl()
    if s_AirVehicle and s_AirOriginal ~= nil then pcall(function() s_AirVehicle:EnableAirControl(s_AirOriginal) end) end
    s_AirVehicle, s_AirOriginal = nil, nil
end

local function SyncAirControl(vehicle)
    local wanted = VehiclePerformance.AirControl.value
    if not wanted then
        ReleaseAirControl()
        return
    end
    if s_AirVehicle == vehicle then return end

    ReleaseAirControl()
    s_AirVehicle, s_AirOriginal = vehicle, vehicle:IsAirControlEnabled()
    vehicle:EnableAirControl(true)
end

local function ReadStockTopSpeed(vehicle)
    local recordID = vehicle:GetRecordID()
    if recordID.hash == s_RecordHash then return s_StockTopSpeed end

    s_RecordHash = recordID.hash
    s_StockTopSpeed = nil
    pcall(function()
        local engine = vehicle:GetRecord():VehEngineData()
        for index = 0, engine:GetGearsCount() - 1 do
            local gear = engine:GetGearsItem(index)
            if gear then s_StockTopSpeed = math.max(s_StockTopSpeed or 0, gear:MaxSpeed()) end
        end
    end)
    return s_StockTopSpeed
end

local function IsThrottle()
    return Input.IsKeyDown(KEY_W) or Input.GetRightTriggerNormalized() > TRIGGER_THRESHOLD
end

local function IsBraking()
    return Input.IsKeyDown(KEY_S) or Input.GetLeftTriggerNormalized() > TRIGGER_THRESHOLD
end

local function ForwardSpeed(vehicle, forward)
    local velocity = vehicle:GetLinearVelocity()
    return velocity.x * forward.x + velocity.y * forward.y + velocity.z * forward.z
end

local function Push(vehicle, direction, amount)
    local position = vehicle:GetWorldPosition()
    local event = PhysicalImpulseEvent.new()
    event.worldImpulse = Vector3.new(direction.x * amount, direction.y * amount, direction.z * amount)
    event.worldPosition = Vector3.new(position.x, position.y, position.z)
    event.radius = 1.0
    vehicle:QueueEvent(event)
end

local function AccelerationFor(vehicle, speed)
    local extra = VehiclePerformance.Acceleration.value
    local stockTop = ReadStockTopSpeed(vehicle)
    if not stockTop or stockTop <= 0 then return extra end

    local bonus = VehiclePerformance.TopSpeedBonus.value / MS_TO_KPH
    if speed >= stockTop + bonus then return 0 end
    if bonus > 0 and speed >= stockTop * NEAR_TOP_SPEED then extra = extra + TOP_SPEED_PUSH end
    return extra
end

local function Assist(vehicle, deltaTime)
    if vehicle:IsInAir() then return end

    local forward = vehicle:GetWorldForward()
    local speed = ForwardSpeed(vehicle, forward)
    local mass = math.max(vehicle:GetTotalMass() or FALLBACK_MASS, 1)

    if VehiclePerformance.Downforce.value > 0 and speed > 0 then
        local up = vehicle:GetWorldUp()
        local amount = VehiclePerformance.Downforce.value * math.min(1, speed / DOWNFORCE_FULL_SPEED)
        Push(vehicle, up, -mass * amount * deltaTime)
    end

    if IsThrottle() and speed >= 0 then
        local acceleration = AccelerationFor(vehicle, speed)
        if acceleration > 0 then Push(vehicle, forward, mass * acceleration * deltaTime) end
    elseif IsBraking() and speed > MIN_BRAKE_SPEED and VehiclePerformance.Braking.value > 0 then
        local braking = math.min(VehiclePerformance.Braking.value, speed / math.max(deltaTime, 0.001))
        Push(vehicle, forward, -mass * braking * deltaTime)
    end
end

function VehiclePerformance.Tick(deltaTime)
    if not VehiclePerformance.Enabled.value then
        if s_AppliedHash then RestoreRecords() end
        if s_AirVehicle then ReleaseAirControl() end
        return
    end

    local vehicle = Vehicle.GetMountedVehicleSafe()
    if not vehicle or not vehicle:IsPlayerDriver() then return end

    SyncRecords(vehicle)
    SyncAirControl(vehicle)
    local ok, err = pcall(Assist, vehicle, deltaTime or 0)
    if not ok then Logger.Log("VehiclePerformance: assist failed (" .. tostring(err) .. ")") end
end

local function Tuned(stock, scale)
    if not stock then return nil end
    return VehiclePerformance.Enabled.value and stock * scale or stock
end

local function ReadStats()
    local vehicle = Vehicle.GetMountedVehicleSafe()
    if not vehicle then return nil end

    local stats = {}
    pcall(function()
        stats.Name = vehicle:GetDisplayName()
        stats.Mass = vehicle:GetTotalMass()

        local stockTop = ReadStockTopSpeed(vehicle)
        stats.StockTopSpeed = stockTop and stockTop * MS_TO_KPH or nil

        local hash = vehicle:GetRecordID().hash
        local stock = s_StockCache[hash]
        if not stock then
            local ids = SourceIDs(vehicle:GetRecord())
            stock = {
                Torque = StockFlat(ids.Engine, "engineMaxTorque"),
                Shift = StockFlat(ids.Engine, "gearChangeTime"),
                FrontGrip = StockFlat(ids.Front, "tireFrictionCoef"),
                RearGrip = StockFlat(ids.Rear, "tireFrictionCoef"),
                Steering = StockFlat(ids.Drive, "maxWheelTurnDeg"),
                Handbrake = StockFlat(ids.Drive, "handbrakeBrakingTorque")
            }
            s_StockCache[hash] = stock
        end

        stats.StockTorque = stock.Torque
        stats.StockShift = stock.Shift
        stats.StockFrontGrip = stock.FrontGrip
        stats.StockRearGrip = stock.RearGrip
        stats.StockSteering = stock.Steering
        stats.StockHandbrake = stock.Handbrake
    end)

    stats.TopSpeed = stats.StockTopSpeed and (VehiclePerformance.Enabled.value and stats.StockTopSpeed + VehiclePerformance.TopSpeedBonus.value or stats.StockTopSpeed) or nil
    stats.Torque = Tuned(stats.StockTorque, VehiclePerformance.EnginePower.value)
    stats.Shift = Tuned(stats.StockShift, 1 / VehiclePerformance.ShiftSpeed.value)
    stats.FrontGrip = Tuned(stats.StockFrontGrip, VehiclePerformance.FrontGrip.value)
    stats.RearGrip = Tuned(stats.StockRearGrip, VehiclePerformance.RearGrip.value)
    stats.Steering = Tuned(stats.StockSteering, VehiclePerformance.SteeringLock.value)
    stats.Handbrake = Tuned(stats.StockHandbrake, VehiclePerformance.Handbrake.value)
    return stats
end

function VehiclePerformance.GetStats()
    local now = os.clock()
    if now < s_NextStats then return s_Stats end
    s_NextStats = now + STATS_INTERVAL
    s_Stats = ReadStats()
    return s_Stats
end

function VehiclePerformance.ResetValues()
    VehiclePerformance.TopSpeedBonus.value = 0
    VehiclePerformance.Acceleration.value = 0
    VehiclePerformance.Braking.value = 0
    VehiclePerformance.Downforce.value = 0
    VehiclePerformance.EnginePower.value = 1.0
    VehiclePerformance.ShiftSpeed.value = 1.0
    VehiclePerformance.FrontGrip.value = 1.0
    VehiclePerformance.RearGrip.value = 1.0
    VehiclePerformance.SteeringLock.value = 1.0
    VehiclePerformance.Handbrake.value = 1.0
    VehiclePerformance.AirControl.value = false
end

Lifecycle.Register("VehiclePerformance", {
    OnSessionEnd = function()
        RestoreRecords()
        s_AirVehicle, s_AirOriginal = nil, nil
        s_RecordHash = nil
    end,
    OnShutdown = function()
        RestoreRecords()
        ReleaseAirControl()
    end
})

return VehiclePerformance
