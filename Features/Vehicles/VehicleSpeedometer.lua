local Vehicle = require("Utils/Vehicle")
local Animation = require("UI/Widgets/Animation/Animation")
local Draw = require("UI/Core/Draw")
local Style = require("UI/Style/Style")
local UIConfig = require("Config/UIConfig")

local Speedometer = {
    Enabled = { value = true },
    ShowRPM = { value = true },
    UseMPH = { value = false },
    AutomaticMaxSpeed = { value = true },
    MaxSpeed = { value = 320, min = 160, max = 500, step = 20 },
    Scale = { value = 1.0, min = 0.7, max = 1.4, step = 0.05 },
    Position = { index = 1 },
    Positions = { "Bottom Right", "Bottom Left", "Top Right", "Top Left" },
    OffsetX = { value = 0, min = -1000, max = 1000, step = 5 },
    OffsetY = { value = 0, min = -1000, max = 1000, step = 5 },
    Colors = {
        Active = 0xFFA56E3A,
        Needle = 0xFFFFFFFF,
        Text = 0xFFFFFFFF,
        Muted = 0xFFA08C78,
        Ring = 0xFF6E5A50,
    },
    SpeedKPH = 0,
    RPM = 0,
    MaxRPM = 8000,
    DetectedMaxSpeed = nil,
    Gear = "N",
    Mounted = false,
    Alpha = 0,
}

UIConfig.RegisterSection("Speedometer", {
    MaxSpeed = Speedometer.MaxSpeed,
    AutomaticMaxSpeed = Speedometer.AutomaticMaxSpeed,
    ShowRPM = Speedometer.ShowRPM,
    Scale = Speedometer.Scale,
    Position = Speedometer.Position,
    OffsetX = Speedometer.OffsetX,
    OffsetY = Speedometer.OffsetY,
    Colors = Speedometer.Colors,
})

local lastPosition
local lastEntity
local profile

local function SafeMethod(object, name)
    if not object then return nil end
    local ok, value = pcall(function() return object[name](object) end)
    return ok and value or nil
end

local function Number(value)
    if type(value) == "number" then return value end
    if type(value) == "table" or type(value) == "userdata" then
        return tonumber(value.value)
    end
    return tonumber(value)
end

local function EntityKey(vehicle)
    local id = SafeMethod(vehicle, "GetEntityID")
    return id and tostring(id) or tostring(vehicle)
end

local function GetPosition(vehicle)
    local value = SafeMethod(vehicle, "GetWorldPosition")
    if value and value.x and value.y and value.z then return value end
    local transform = SafeMethod(vehicle, "GetWorldTransform")
    if transform and transform.Position then
        local position = transform.Position:ToVector4()
        if position then return position end
    end
end

local function GetVelocitySpeed(vehicle)
    local velocity = SafeMethod(vehicle, "GetVelocity") or SafeMethod(vehicle, "GetLinearVelocity")
    if not (velocity and velocity.x and velocity.y and velocity.z) then return nil end
    return math.sqrt((velocity.x * velocity.x) + (velocity.y * velocity.y) + (velocity.z * velocity.z))
end

local function ReadProfile(vehicle)
    local record = SafeMethod(vehicle, "GetRecord")
    if not record then return nil end
    local engine = SafeMethod(record, "VehEngineData")
    if not engine then return nil end

    local result = {
        MinRPM = Number(SafeMethod(engine, "MinRPM")) or 800,
        MaxRPM = Number(SafeMethod(engine, "MaxRPM")) or 8000,
        Gears = {},
    }
    local count = Number(SafeMethod(engine, "GearsCount")) or 0
    for index = 0, count - 1 do
        local gear = SafeMethod(engine, "GearsItem" .. tostring(index))
        if not gear then
            local ok, value = pcall(function() return engine:GearsItem(index) end)
            if ok then gear = value end
        end
        if gear then
            table.insert(result.Gears, {
                MinSpeed = Number(SafeMethod(gear, "MinSpeed")) or 0,
                MaxSpeed = Number(SafeMethod(gear, "MaxSpeed")) or 0,
                MinRPM = Number(SafeMethod(gear, "MinEngineRPM")) or result.MinRPM,
                MaxRPM = Number(SafeMethod(gear, "MaxEngineRPM")) or result.MaxRPM,
            })
        end
    end
    local maximum = 0
    for _, gear in ipairs(result.Gears) do maximum = math.max(maximum, gear.MaxSpeed or 0) end
    if maximum > 0 then
        result.MaxSpeedKPH = maximum > 180 and maximum or maximum * 3.6
        result.MaxSpeedKPH = math.max(80, math.min(500, result.MaxSpeedKPH))
    end
    return result
end

local function RuntimeValue(vehicle, component, names)
    for _, name in ipairs(names) do
        local value = Number(SafeMethod(component, name)) or Number(SafeMethod(vehicle, name))
        if value ~= nil then return value end
    end
end

local function EstimateDrivetrain(speedMPS)
    if not profile or #profile.Gears < 2 then
        local gear = speedMPS < 0.5 and 0 or math.min(6, math.max(1, math.floor(speedMPS / 9) + 1))
        local ratio = math.min(1, (speedMPS % 9) / 9)
        return gear, 900 + (ratio * 6100)
    end

    local selected = 2
    for index = 2, #profile.Gears do
        local gear = profile.Gears[index]
        selected = index
        if speedMPS <= gear.MaxSpeed or index == #profile.Gears then break end
    end
    local gear = profile.Gears[selected]
    local range = math.max(0.01, gear.MaxSpeed - gear.MinSpeed)
    local ratio = math.max(0, math.min(1, (speedMPS - gear.MinSpeed) / range))
    return selected - 1, gear.MinRPM + ((gear.MaxRPM - gear.MinRPM) * ratio)
end

local function GearLabel(value, speedMPS)
    if value == nil then return "--" end
    value = math.floor(value + 0.5)
    if value < 0 then return "R" end
    if value == 0 then return speedMPS < 0.5 and "N" or "1" end
    return tostring(value)
end

function Speedometer.Update(deltaTime)
    local dt = math.max(0.001, deltaTime or (1 / 60))
    local vehicle = Vehicle.GetMountedVehicleSafe()
    Speedometer.Mounted = vehicle ~= nil
    Speedometer.Alpha = Animation.Animate(Speedometer.Alpha, vehicle and 1 or 0, 8, dt)
    if not vehicle then
        lastPosition, lastEntity, profile = nil, nil, nil
        Speedometer.SpeedKPH = Animation.Animate(Speedometer.SpeedKPH, 0, 8, dt)
        Speedometer.RPM = Animation.Animate(Speedometer.RPM, 0, 8, dt)
        Speedometer.Gear = "N"
        return
    end

    local entity = EntityKey(vehicle)
    if entity ~= lastEntity then
        lastEntity = entity
        lastPosition = nil
        profile = ReadProfile(vehicle)
        Speedometer.DetectedMaxSpeed = profile and profile.MaxSpeedKPH or nil
    end

    local speedMPS = GetVelocitySpeed(vehicle)
    local position = GetPosition(vehicle)
    if speedMPS == nil and position and lastPosition then
        local dx, dy, dz = position.x - lastPosition.x, position.y - lastPosition.y, position.z - lastPosition.z
        speedMPS = math.sqrt((dx * dx) + (dy * dy) + (dz * dz)) / dt
        if speedMPS > 150 then speedMPS = 0 end
    end
    if position then lastPosition = { x = position.x, y = position.y, z = position.z } end
    speedMPS = math.max(0, speedMPS or 0)

    local component = SafeMethod(vehicle, "GetVehicleComponent")
    local runtimeGear = RuntimeValue(vehicle, component, { "GetCurrentGear", "GetCurrentGearIndex", "GetGear" })
    local runtimeRPM = RuntimeValue(vehicle, component, { "GetCurrentRPM", "GetEngineRPM", "GetRPM" })
    local estimatedGear, estimatedRPM = EstimateDrivetrain(speedMPS)
    local maxRPM = math.max(1000, profile and profile.MaxRPM or 8000)
    if runtimeRPM and runtimeRPM <= 1.5 then runtimeRPM = runtimeRPM * maxRPM end

    Speedometer.SpeedKPH = Animation.Animate(Speedometer.SpeedKPH, speedMPS * 3.6, 10, dt)
    Speedometer.RPM = Animation.Animate(Speedometer.RPM, runtimeRPM or estimatedRPM, 9, dt)
    Speedometer.MaxRPM = maxRPM
    Speedometer.Gear = GearLabel(runtimeGear or estimatedGear, speedMPS)
end

local function Position(width, height)
    local screenWidth, screenHeight = GetDisplayResolution()
    local margin = 24
    local selected = Speedometer.Positions[Speedometer.Position.index or 1]
    local x, y = screenWidth - width - margin, screenHeight - height - margin
    if selected == "Bottom Left" then x, y = margin, screenHeight - height - margin end
    if selected == "Top Right" then x, y = screenWidth - width - margin, margin end
    if selected == "Top Left" then x, y = margin, margin end
    x = x + (Speedometer.OffsetX.value or 0)
    y = y + (Speedometer.OffsetY.value or 0)
    return math.max(0, math.min(screenWidth - width, x)), math.max(0, math.min(screenHeight - height, y))
end

local function Polar(centerX, centerY, radius, angle)
    return centerX + (math.cos(angle) * radius), centerY + (math.sin(angle) * radius)
end

local function TextCentered(drawList, x, y, color, text)
    local width = ImGui.CalcTextSize(text)
    Draw.Text(drawList, x - (width * 0.5), y, color, text)
end

local function DrawGauge(drawList, centerX, centerY, radius, ratio, maximum, divisions, label,
    alpha, scale, centerLabel, centerValue)
    local startAngle, sweep = math.rad(135), math.rad(270)
    local colors = Speedometer.Colors
    local accent = Animation.WithAlpha(colors.Active, alpha)
    local needle = Animation.WithAlpha(colors.Needle, alpha)
    local text = Animation.WithAlpha(colors.Text, alpha)
    local muted = Animation.WithAlpha(colors.Muted, alpha)
    local border = Animation.WithAlpha(colors.Ring, alpha)
    local shadow = Animation.WithAlpha(Style.Shadow, alpha)
    local segments = 48

    ratio = math.max(0, math.min(1, ratio))
    for index = 0, segments - 1 do
        local first = startAngle + (sweep * (index / segments))
        local second = startAngle + (sweep * ((index + 0.72) / segments))
        local x1, y1 = Polar(centerX, centerY, radius, first)
        local x2, y2 = Polar(centerX, centerY, radius, second)
        Draw.Line(drawList, x1, y1 + (2 * scale), x2, y2 + (2 * scale), shadow, 5 * scale)
        Draw.Line(drawList, x1, y1, x2, y2, (index / segments) <= ratio and accent or border, 3 * scale)
    end

    for index = 0, divisions do
        local tickRatio = index / divisions
        local angle = startAngle + (sweep * tickRatio)
        local outerX, outerY = Polar(centerX, centerY, radius - (5 * scale), angle)
        local innerX, innerY = Polar(centerX, centerY, radius - (14 * scale), angle)
        Draw.Line(drawList, innerX, innerY, outerX, outerY, text, 2 * scale)
        local labelX, labelY = Polar(centerX, centerY, radius - (28 * scale), angle)
        TextCentered(drawList, labelX, labelY - (ImGui.GetFontSize() * 0.5), muted,
            tostring(math.floor((maximum * tickRatio) + 0.5)))
    end

    local needleAngle = startAngle + (sweep * ratio)
    local needleX, needleY = Polar(centerX, centerY, radius - (19 * scale), needleAngle)
    Draw.Line(drawList, centerX, centerY, needleX, needleY, shadow, 6 * scale)
    Draw.Line(drawList, centerX, centerY, needleX, needleY, needle, 3 * scale)
    Draw.RectFilled(drawList, centerX - (5 * scale), centerY - (5 * scale), 10 * scale, 10 * scale,
        text, 5 * scale)

    if centerLabel then TextCentered(drawList, centerX, centerY + (14 * scale), muted, centerLabel) end
    if centerValue then TextCentered(drawList, centerX, centerY + (30 * scale), accent, centerValue) end
    TextCentered(drawList, centerX, centerY + radius - (6 * scale), muted, label)
end

function Speedometer.Render()
    if not Speedometer.Enabled.value or Speedometer.Alpha < 0.01 then return end

    local scale = Speedometer.Scale.value
    local width, height = 300 * scale, 220 * scale
    local x, y = Position(width, height)
    ImGui.SetNextWindowPos(x, y, ImGuiCond.Always)
    ImGui.SetNextWindowSize(width, height, ImGuiCond.Always)
    ImGui.PushStyleColor(ImGuiCol.WindowBg, 0, 0, 0, 0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowBorderSize, 0)
    ImGui.Begin("##EasyTrainerSpeedometer", ImGuiWindowFlags.NoDecoration + ImGuiWindowFlags.NoSavedSettings
        + ImGuiWindowFlags.NoResize + ImGuiWindowFlags.NoMove + ImGuiWindowFlags.NoScrollbar
        + ImGuiWindowFlags.NoScrollWithMouse + ImGuiWindowFlags.NoInputs)

    local drawList = ImGui.GetWindowDrawList()
    local alpha = Speedometer.Alpha
    local speedX, speedY = x + (105 * scale), y + (104 * scale)
    local rpmX, rpmY = x + (243 * scale), y + (151 * scale)
    local speedRadius, rpmRadius = 88 * scale, 52 * scale
    local displaySpeed = Speedometer.UseMPH.value and Speedometer.SpeedKPH * 0.621371 or Speedometer.SpeedKPH
    local configuredMaximum = Speedometer.AutomaticMaxSpeed.value and Speedometer.DetectedMaxSpeed or nil
    configuredMaximum = math.max(1, configuredMaximum or Speedometer.MaxSpeed.value)
    local maxSpeed = Speedometer.UseMPH.value and configuredMaximum * 0.621371 or configuredMaximum
    local rpmMaximum = math.max(1, Speedometer.MaxRPM / 1000)
    DrawGauge(drawList, speedX, speedY, speedRadius, displaySpeed / maxSpeed, maxSpeed, 8,
        Speedometer.UseMPH.value and "MPH" or "KM/H", alpha, scale, "GEAR", Speedometer.Gear)
    if Speedometer.ShowRPM.value then
        DrawGauge(drawList, rpmX, rpmY, rpmRadius, Speedometer.RPM / Speedometer.MaxRPM, rpmMaximum, 4,
            "RPM x1000", alpha, scale)
    end

    ImGui.End()
    ImGui.PopStyleVar()
    ImGui.PopStyleColor()
end

return Speedometer
