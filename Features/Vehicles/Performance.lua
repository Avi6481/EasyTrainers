local Input = require("Core/Input")
local Impulse = require("Utils/Impulse")

local Performance = {
    Enabled = false,
    EnginePower = 1,
    TopSpeedBonus = 0,
    Acceleration = 0,
    ShiftSpeed = 1,
    FrontGrip = 1,
    RearGrip = 1,
    SteeringLock = 1,
    Downforce = 0,
    AirControl = false,
    Braking = 0,
    Handbrake = 1,
    Presets = {}
}

Performance.Ranges = {
    EnginePower = { Stock = 1, Min = 0.5, Max = 5, Step = 0.1 },
    TopSpeedBonus = { Stock = 0, Min = 0, Max = 400, Step = 10 },
    Acceleration = { Stock = 0, Min = 0, Max = 30, Step = 0.5 },
    ShiftSpeed = { Stock = 1, Min = 1, Max = 10, Step = 0.5 },
    FrontGrip = { Stock = 1, Min = 0.3, Max = 3, Step = 0.1 },
    RearGrip = { Stock = 1, Min = 0.3, Max = 3, Step = 0.1 },
    SteeringLock = { Stock = 1, Min = 0.5, Max = 2, Step = 0.05 },
    Downforce = { Stock = 0, Min = 0, Max = 30, Step = 1 },
    Braking = { Stock = 0, Min = 0, Max = 40, Step = 1 },
    Handbrake = { Stock = 1, Min = 0.5, Max = 5, Step = 0.1 }
}

local FLATS = {
    { Value = "EnginePower", Source = "Engine", Field = "engineMaxTorque" },
    { Value = "ShiftSpeed", Source = "Engine", Field = "gearChangeTime", Invert = true },
    { Value = "ShiftSpeed", Source = "Engine", Field = "gearChangeCooldown", Invert = true },
    { Value = "FrontGrip", Source = "Front", Field = "tireFrictionCoef" },
    { Value = "RearGrip", Source = "Rear", Field = "tireFrictionCoef" },
    { Value = "SteeringLock", Source = "Drive", Field = "maxWheelTurnDeg" },
    { Value = "Handbrake", Source = "Drive", Field = "handbrakeBrakingTorque" }
}

local STATS = { "Enabled", "TopSpeed", "Torque", "Shift", "FrontGrip", "RearGrip", "Steering", "Handbrake" }

local MS_TO_KPH = 3.6
local TOP_SPEED_PUSH = 9
local NEAR_TOP_SPEED = 0.9
local MIN_BRAKE_SPEED = 1
local MIN_DELTA = 0.001
local DOWNFORCE_FULL_SPEED = 40
local STATS_INTERVAL = 0.25
local WATCH_TIME = 1

local s_Originals = {}
local s_Applied = {}
local s_AppliedHash = nil
local s_AirId = nil
local s_AirOriginal = nil
local s_Stock = {}
local s_Stats = nil
local s_NextStats = 0
local s_WatchUntil = 0

local function Clamp(name, value)
    local range = Performance.Ranges[name]
    value = tonumber(value) or range.Stock
    return math.max(range.Min, math.min(range.Max, value))
end

local function Trim(text)
    return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function RecordKey(recordID)
    return tostring(recordID.hash) .. ":" .. tostring(recordID.length)
end

local function SetFlat(flat, value)
    TweakDB:SetFlat(flat, value)
end

local function UpdateRecord(recordID)
    TweakDB:Update(recordID)
end

local function RestoreRecords()
    local records = {}
    for key, original in pairs(s_Originals) do
        pcall(SetFlat, original.Flat, original.Value)
        records[original.RecordKey] = original.Record
        s_Originals[key] = nil
    end
    for _, recordID in pairs(records) do pcall(UpdateRecord, recordID) end
    s_AppliedHash = nil
end

local function ScaleFlat(recordID, field, scale)
    local recordKey = RecordKey(recordID)
    local key = recordKey .. field
    local original = s_Originals[key]
    if not original then
        local flat = TweakDBID.new(recordID, "." .. field)
        local value = TweakDB:GetFlat(flat)
        if type(value) ~= "number" then return false end
        original = { Flat = flat, Record = recordID, RecordKey = recordKey, Value = value }
        s_Originals[key] = original
    end

    SetFlat(original.Flat, original.Value * scale)
    return true
end

local function StockFlat(recordID, field)
    if not recordID then return nil end

    local original = s_Originals[RecordKey(recordID) .. field]
    if original then return original.Value end

    local value = TweakDB:GetFlat(TweakDBID.new(recordID, "." .. field))
    if type(value) == "number" then return value end
    return nil
end

local function SourceIDs(record)
    local engine = record:VehEngineData()
    local drive = record:VehDriveModelData()
    local wheels = drive and drive:WheelSetup() or nil
    local front = wheels and wheels:FrontPreset() or nil
    local rear = wheels and wheels:BackPreset() or nil
    return {
        Engine = engine and engine:GetID() or nil,
        Drive = drive and drive:GetID() or nil,
        Front = front and front:GetID() or nil,
        Rear = rear and rear:GetID() or nil
    }
end

local function FlatScale(flat)
    local value = Clamp(flat.Value, Performance[flat.Value])
    if flat.Invert then return 1 / value end
    return value
end

local function ApplyRecords(record)
    local ids = SourceIDs(record)
    local records = {}
    for _, flat in ipairs(FLATS) do
        local recordID = ids[flat.Source]
        local scale = FlatScale(flat)
        if recordID and scale ~= 1 and ScaleFlat(recordID, flat.Field, scale) then
            records[RecordKey(recordID)] = recordID
        end
    end
    for _, recordID in pairs(records) do UpdateRecord(recordID) end
end

local function Changed()
    for _, flat in ipairs(FLATS) do
        if s_Applied[flat.Value] ~= Performance[flat.Value] then return true end
    end
    return false
end

local function SyncRecords(vehicle, hash)
    if hash == s_AppliedHash and not Changed() then return end

    RestoreRecords()
    s_AppliedHash = hash
    for _, flat in ipairs(FLATS) do s_Applied[flat.Value] = Performance[flat.Value] end
    ApplyRecords(vehicle:GetRecord())
end

local function RestoreAir(id, enable)
    local vehicle = Game.FindEntityByID(id)
    if vehicle then vehicle:EnableAirControl(enable) end
end

local function ReleaseAir()
    if s_AirId then pcall(RestoreAir, s_AirId, s_AirOriginal == true) end
    s_AirId, s_AirOriginal = nil, nil
end

local function SyncAir(vehicle)
    if not Performance.AirControl then
        if s_AirId then ReleaseAir() end
        return
    end

    local id = vehicle:GetEntityID()
    if s_AirId and s_AirId.hash == id.hash then return end

    ReleaseAir()
    s_AirOriginal = vehicle:IsAirControlEnabled()
    s_AirId = id
    vehicle:EnableAirControl(true)
end

local function Release()
    if s_AppliedHash then RestoreRecords() end
    if s_AirId then ReleaseAir() end
end

local function TopSpeed(record)
    local engine = record:VehEngineData()
    if not engine then return nil end

    local top = nil
    for index = 0, engine:GetGearsCount() - 1 do
        local gear = engine:GetGearsItem(index)
        if gear then top = math.max(top or 0, gear:MaxSpeed()) end
    end
    return top and top * MS_TO_KPH or nil
end

local function Stock(vehicle, hash)
    local stock = s_Stock[hash]
    if stock then return stock end

    local record = vehicle:GetRecord()
    local ids = SourceIDs(record)
    stock = {
        Name = vehicle:GetDisplayName(),
        Mass = Impulse.Mass(vehicle),
        TopSpeed = TopSpeed(record),
        Torque = StockFlat(ids.Engine, "engineMaxTorque"),
        Shift = StockFlat(ids.Engine, "gearChangeTime"),
        FrontGrip = StockFlat(ids.Front, "tireFrictionCoef"),
        RearGrip = StockFlat(ids.Rear, "tireFrictionCoef"),
        Steering = StockFlat(ids.Drive, "maxWheelTurnDeg"),
        Handbrake = StockFlat(ids.Drive, "handbrakeBrakingTorque")
    }
    s_Stock[hash] = stock
    return stock
end

local function Tuned(value, scale)
    if value and Performance.Enabled then return value * scale end
    return value
end

local function BuildStats(stock)
    local bonus = Performance.Enabled and Clamp("TopSpeedBonus", Performance.TopSpeedBonus) or 0
    return {
        Stock = stock,
        Name = stock.Name,
        Enabled = Performance.Enabled,
        Mass = stock.Mass,
        TopSpeed = stock.TopSpeed and stock.TopSpeed + bonus or nil,
        Torque = Tuned(stock.Torque, Clamp("EnginePower", Performance.EnginePower)),
        Shift = Tuned(stock.Shift, 1 / Clamp("ShiftSpeed", Performance.ShiftSpeed)),
        FrontGrip = Tuned(stock.FrontGrip, Clamp("FrontGrip", Performance.FrontGrip)),
        RearGrip = Tuned(stock.RearGrip, Clamp("RearGrip", Performance.RearGrip)),
        Steering = Tuned(stock.Steering, Clamp("SteeringLock", Performance.SteeringLock)),
        Handbrake = Tuned(stock.Handbrake, Clamp("Handbrake", Performance.Handbrake))
    }
end

local function SameStats(first, second)
    if not first or not second or first.Stock ~= second.Stock then return false end
    for _, key in ipairs(STATS) do
        if first[key] ~= second[key] then return false end
    end
    return true
end

local function RefreshStats(vehicle, hash, now)
    if now < s_NextStats then return end
    s_NextStats = now + STATS_INTERVAL

    if not vehicle then
        s_Stats = nil
        return
    end

    local stats = BuildStats(Stock(vehicle, hash))
    if not SameStats(stats, s_Stats) then s_Stats = stats end
end

local function Assisting()
    return Performance.Acceleration > 0 or Performance.TopSpeedBonus > 0 or Performance.Downforce > 0 or Performance.Braking > 0
end

local function ThrottleHeld()
    return Input.KeyDown(Input.VK.W) or Input.ButtonDown(Input.Button.RightTrigger)
end

local function BrakeHeld()
    return Input.KeyDown(Input.VK.S) or Input.ButtonDown(Input.Button.LeftTrigger)
end

local function Push(vehicle, direction, amount)
    Impulse.Push(vehicle, direction.x * amount, direction.y * amount, direction.z * amount)
end

local function ExtraAcceleration(stock, speed)
    local extra = Clamp("Acceleration", Performance.Acceleration)
    if not stock.TopSpeed or stock.TopSpeed <= 0 then return extra end

    local top = stock.TopSpeed / MS_TO_KPH
    local bonus = Clamp("TopSpeedBonus", Performance.TopSpeedBonus) / MS_TO_KPH
    if speed >= top + bonus then return 0 end
    if bonus > 0 and speed >= top * NEAR_TOP_SPEED then extra = extra + TOP_SPEED_PUSH end
    return extra
end

local function Assist(vehicle, stock, delta)
    if delta <= 0 or not Assisting() or vehicle:IsInAir() then return end

    local forward = vehicle:GetWorldForward()
    local velocity = vehicle:GetLinearVelocity()
    local speed = (velocity.x * forward.x) + (velocity.y * forward.y) + (velocity.z * forward.z)

    local downforce = Clamp("Downforce", Performance.Downforce)
    if downforce > 0 and speed > 0 then
        Push(vehicle, vehicle:GetWorldUp(), -stock.Mass * downforce * math.min(1, speed / DOWNFORCE_FULL_SPEED) * delta)
    end

    if ThrottleHeld() and speed >= 0 then
        local extra = ExtraAcceleration(stock, speed)
        if extra > 0 then Push(vehicle, forward, stock.Mass * extra * delta) end
    elseif BrakeHeld() and speed > MIN_BRAKE_SPEED then
        local braking = math.min(Clamp("Braking", Performance.Braking), speed / math.max(delta, MIN_DELTA))
        if braking > 0 then Push(vehicle, forward, -stock.Mass * braking * delta) end
    end
end

function Performance.Watch()
    s_WatchUntil = os.clock() + WATCH_TIME
end

function Performance.Active()
    return Performance.Enabled or s_AppliedHash ~= nil or s_AirId ~= nil or os.clock() < s_WatchUntil
end

function Performance.GetStats()
    return s_Stats
end

function Performance.ResetValues()
    for key, range in pairs(Performance.Ranges) do Performance[key] = range.Stock end
    Performance.AirControl = false
end

function Performance.SavePreset(name)
    name = Trim(name)
    if name == "" then name = tip("vehicles.performance.presets.default", { count = #Performance.Presets + 1 }) end

    local values = { AirControl = Performance.AirControl == true }
    for key in pairs(Performance.Ranges) do values[key] = Clamp(key, Performance[key]) end
    table.insert(Performance.Presets, { Name = name, Values = values })
    return name
end

function Performance.LoadPreset(preset)
    local values = type(preset) == "table" and preset.Values or nil
    if type(values) ~= "table" then return end

    for key in pairs(Performance.Ranges) do
        if values[key] ~= nil then Performance[key] = Clamp(key, values[key]) end
    end
    if type(values.AirControl) == "boolean" then Performance.AirControl = values.AirControl end
end

function Performance.DeletePreset(preset)
    for index, saved in ipairs(Performance.Presets) do
        if saved == preset then
            table.remove(Performance.Presets, index)
            return
        end
    end
end

function Performance.Update(vehicle, delta, now)
    local hash = vehicle and vehicle:GetRecordID().hash or nil
    if now < s_WatchUntil then RefreshStats(vehicle, hash, now) end

    if not Performance.Enabled then
        Release()
        return
    end

    if not vehicle or not vehicle:IsPlayerDriver() then
        if s_AirId then ReleaseAir() end
        return
    end

    SyncRecords(vehicle, hash)
    SyncAir(vehicle)
    Assist(vehicle, Stock(vehicle, hash), delta or 0)
end

function Performance.Reset()
    RestoreRecords()
    s_AirId, s_AirOriginal = nil, nil
    s_Stock = {}
    s_Stats = nil
    s_NextStats = 0
end

function Performance.Shutdown()
    RestoreRecords()
    ReleaseAir()
end

return Performance
