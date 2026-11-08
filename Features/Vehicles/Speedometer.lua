local Animation = require("Core/Animation")
local Draw = require("Core/Draw")
local Input = require("Core/Input")
local State = require("Core/State")
local Style = require("Style/Style")
local Scale = require("Style/Scale")

local Speedometer = {
    Enabled = false,
    ShowRpm = false,
    UseMph = false,
    HideGameSpeedometer = false,
    AutoMax = false,
    MaxSpeed = 320,
    Scale = 1,
    Position = "BottomRight",
    OffsetX = 0,
    OffsetY = 0,
    ActiveColor = { R = 58 / 255, G = 110 / 255, B = 165 / 255, A = 1 },
    NeedleColor = { R = 1, G = 1, B = 1, A = 1 },
    TextColor = { R = 1, G = 1, B = 1, A = 1 },
    MutedColor = { R = 120 / 255, G = 140 / 255, B = 160 / 255, A = 1 },
    RingColor = { R = 80 / 255, G = 90 / 255, B = 110 / 255, A = 1 }
}

Speedometer.Positions = { "BottomRight", "BottomLeft", "TopRight", "TopLeft" }

local KPH_PER_MPH = 1.60934
local DEFAULT_MAX_RPM = 8000
local MARGIN = 24
local FULL_WIDTH = 300
local SPEED_WIDTH = 210
local HEIGHT = 220
local FADE_SPEED = 8
local NEEDLE_SPEED = 10
local MOVE_SPEED = 12
local STALE_TIME = 0.5
local MIN_ALPHA = 0.01
local SPEED_DIVISIONS = 10
local RPM_DIVISIONS = 5
local SPEED_STEPS = { 10, 20, 30, 40, 50, 60, 80, 100 }
local RPM_STEPS = { 1, 2 }
local SEGMENTS = 48
local SEGMENT_FILL = 0.72
local START_ANGLE = math.rad(135)
local SWEEP = math.rad(270)
local TICK_TEXT = 0.8
local LABEL_TEXT = 0.75
local GEAR_TEXT = 1.4
local SPEED_GAUGE = { X = 105, Y = 104, Radius = 88 }
local RPM_GAUGE = { X = 243, Y = 151, Radius = 52 }

local s_CurveSet = nil
local s_CurveName = nil
local s_VehicleHash = nil
local s_MaxRpm = DEFAULT_MAX_RPM
local s_DetectedMax = nil
local s_SpeedMph = 0
local s_Rpm = 0
local s_Gear = "N"
local s_Alpha = 0
local s_SeenAt = 0
local s_HudController = nil
local s_HudHidden = false
local s_DrawX = nil
local s_DrawY = nil
local s_Drag = nil
local s_Colors = {}

local function Curves()
    if not s_CurveSet then
        s_CurveSet = CName.new("vehicle_ui")
        s_CurveName = CName.new("speed_to_multiplier")
    end
    return s_CurveSet, s_CurveName
end

local function RawToMph(raw)
    raw = math.abs(raw or 0)
    local stats = Game.GetStatsDataSystem()
    if not stats then return raw end

    local curveSet, curveName = Curves()
    return raw * (stats:GetValueFromCurve(curveSet, raw, curveName) or 1)
end

local function RoundUp(value, step)
    return math.ceil(value / step) * step
end

local function NiceScale(maximum, steps, maxDivisions)
    local step = steps[#steps]
    for _, candidate in ipairs(steps) do
        if math.ceil((maximum / candidate) - 0.001) <= maxDivisions then
            step = candidate
            break
        end
    end

    local divisions = math.max(1, math.ceil((maximum / step) - 0.001))
    return divisions * step, divisions
end

local function EngineData(vehicle)
    return vehicle:GetRecord():VehEngineData()
end

local function ReadEngine(vehicle)
    s_MaxRpm = DEFAULT_MAX_RPM
    s_DetectedMax = nil

    local ok, engine = pcall(EngineData, vehicle)
    if not ok or not engine then return end

    s_MaxRpm = math.max(1000, engine:MaxRPM() or DEFAULT_MAX_RPM)

    local topSpeed = 0
    for index = 0, (engine:GetGearsCount() or 0) - 1 do
        local gear = engine:GetGearsItem(index)
        if gear then topSpeed = math.max(topSpeed, gear:MaxSpeed() or 0) end
    end

    if topSpeed > 0 then
        s_DetectedMax = Animation.Clamp(RoundUp(RawToMph(topSpeed) * KPH_PER_MPH, 20), 80, 500)
    end
end

local function GearLabel(gear, speedMph)
    if gear < 0 then return "R" end
    if gear == 0 then return speedMph < 1 and "N" or "1" end
    return tostring(gear)
end

local function InMenu()
    local defs = Game.GetAllBlackboardDefs()
    local blackboard = Game.GetBlackboardSystem():Get(defs.UI_System)
    return blackboard ~= nil and blackboard:GetBool(defs.UI_System.IsInMenu)
end

local function ThirdPerson()
    local defs = Game.GetAllBlackboardDefs()
    local blackboard = Game.GetBlackboardSystem():Get(defs.UI_ActiveVehicleData)
    return blackboard ~= nil and blackboard:GetBool(defs.UI_ActiveVehicleData.IsTPPCameraOn)
end

local function HideWanted()
    return Speedometer.Enabled and Speedometer.HideGameSpeedometer
end

local function GameHudShown(controller)
    return controller.m_driver == true and controller.m_activeVehicle ~= nil and ThirdPerson()
end

local function SetHud(controller, hide)
    controller:GetRootWidget():SetVisible(not hide and GameHudShown(controller))
end

local function ApplyHud(hide)
    s_HudHidden = hide
    if s_HudController and not pcall(SetHud, s_HudController, hide) then s_HudController = nil end
end

local function OnCameraModeChanged(controller)
    s_HudController = controller
    if HideWanted() then controller:GetRootWidget():SetVisible(false) end
end

function Speedometer.Initialize()
    ObserveAfter("hudCarController", "OnCameraModeChanged", OnCameraModeChanged)
end

function Speedometer.DetectedMax()
    return s_DetectedMax
end

function Speedometer.ResetPosition()
    Speedometer.OffsetX = 0
    Speedometer.OffsetY = 0
end

local function Settle(delta)
    s_VehicleHash = nil
    s_SpeedMph = Animation.Animate(s_SpeedMph, 0, FADE_SPEED, delta)
    s_Rpm = Animation.Animate(s_Rpm, 0, FADE_SPEED, delta)
    s_Gear = "N"
end

local function Read(vehicle, delta)
    local hash = vehicle:GetEntityID().hash
    if hash ~= s_VehicleHash then
        s_VehicleHash = hash
        ReadEngine(vehicle)
    end

    local blackboard = vehicle:GetBlackboard()
    if not blackboard then return end

    local defs = Game.GetAllBlackboardDefs().Vehicle
    local speedMph = RawToMph(blackboard:GetFloat(defs.SpeedValue))
    s_SpeedMph = Animation.Animate(s_SpeedMph, speedMph, NEEDLE_SPEED, delta)
    s_Rpm = Animation.Animate(s_Rpm, blackboard:GetFloat(defs.RPMValue) or 0, NEEDLE_SPEED, delta)
    s_Gear = GearLabel(blackboard:GetInt(defs.GearValue) or 0, speedMph)
end

function Speedometer.Update(vehicle, delta, now)
    local hide = HideWanted()
    if hide ~= s_HudHidden then ApplyHud(hide) end

    s_SeenAt = now
    if not Speedometer.Enabled then
        s_Alpha = 0
        s_VehicleHash = nil
        return
    end

    local driving = vehicle ~= nil and not InMenu()
    s_Alpha = Animation.Animate(s_Alpha, driving and 1 or 0, FADE_SPEED, delta)

    if driving then
        Read(vehicle, delta)
    elseif not vehicle then
        Settle(delta)
    end
end

local function Target(width, height)
    local screenWidth, screenHeight = GetDisplayResolution()
    local margin = Scale.S(MARGIN)
    local position = Speedometer.Position
    local left = position == "BottomLeft" or position == "TopLeft"
    local top = position == "TopRight" or position == "TopLeft"

    local x = (left and margin or (screenWidth - width - margin)) + Speedometer.OffsetX
    local y = (top and margin or (screenHeight - height - margin)) + Speedometer.OffsetY
    return Animation.Clamp(x, 0, math.max(0, screenWidth - width)), Animation.Clamp(y, 0, math.max(0, screenHeight - height))
end

local function Draggable()
    return State.Menu.Open and State.Menu.Cursor
end

local function OverMenu()
    local menu = State.Menu
    return Input.MouseIn(menu.X, menu.Y, menu.Width, menu.Height)
end

local function Drag(x, y, width, height)
    if not Draggable() then
        s_Drag = nil
        return false
    end

    local mouseX, mouseY = Input.MousePos()
    if not s_Drag then
        if Input.MousePressed(Input.Mouse.Left) and Input.MouseIn(x, y, width, height) and not OverMenu() then
            s_Drag = { MouseX = mouseX, MouseY = mouseY, OffsetX = Speedometer.OffsetX, OffsetY = Speedometer.OffsetY }
        end
        return s_Drag ~= nil
    end

    if not Input.MouseDown(Input.Mouse.Left) then
        s_Drag = nil
        return false
    end

    Speedometer.OffsetX = math.floor(s_Drag.OffsetX + (mouseX - s_Drag.MouseX))
    Speedometer.OffsetY = math.floor(s_Drag.OffsetY + (mouseY - s_Drag.MouseY))
    return true
end

local function Place(width, height)
    local x, y = Target(width, height)
    if not s_DrawX or s_Drag then
        s_DrawX, s_DrawY = x, y
    else
        local delta = State.Time.Delta
        s_DrawX = Animation.Animate(s_DrawX, x, MOVE_SPEED, delta)
        s_DrawY = Animation.Animate(s_DrawY, y, MOVE_SPEED, delta)
    end
    return s_DrawX, s_DrawY
end

local function UpdateColors()
    s_Colors.Active = Draw.FromColorTable(Speedometer.ActiveColor)
    s_Colors.Needle = Draw.FromColorTable(Speedometer.NeedleColor)
    s_Colors.Text = Draw.FromColorTable(Speedometer.TextColor)
    s_Colors.Muted = Draw.FromColorTable(Speedometer.MutedColor)
    s_Colors.Ring = Draw.FromColorTable(Speedometer.RingColor)
end

local function Polar(centerX, centerY, radius, angle)
    return centerX + (math.cos(angle) * radius), centerY + (math.sin(angle) * radius)
end

local function CenterText(x, y, color, text, size)
    local width = Draw.TextSize(text, size)
    Draw.Text(x - (width * 0.5), y, color, text, size)
end

local function DrawRing(centerX, centerY, radius, ratio, scale)
    local lift = 2 * scale
    for index = 0, SEGMENTS - 1 do
        local x1, y1 = Polar(centerX, centerY, radius, START_ANGLE + (SWEEP * (index / SEGMENTS)))
        local x2, y2 = Polar(centerX, centerY, radius, START_ANGLE + (SWEEP * ((index + SEGMENT_FILL) / SEGMENTS)))
        Draw.Line(x1, y1 + lift, x2, y2 + lift, Style.Shadow, 5 * scale)
        Draw.Line(x1, y1, x2, y2, (index / SEGMENTS) <= ratio and s_Colors.Active or s_Colors.Ring, 3 * scale)
    end
end

local function DrawTicks(centerX, centerY, radius, maximum, divisions, scale, size)
    for index = 0, divisions do
        local ratio = index / divisions
        local angle = START_ANGLE + (SWEEP * ratio)
        local outerX, outerY = Polar(centerX, centerY, radius - (5 * scale), angle)
        local innerX, innerY = Polar(centerX, centerY, radius - (14 * scale), angle)
        Draw.Line(innerX, innerY, outerX, outerY, s_Colors.Text, 2 * scale)

        local text = tostring(math.floor((maximum * ratio) + 0.5))
        local width, height = Draw.TextSize(text, size)
        local labelX, labelY = Polar(centerX, centerY, radius - (28 * scale), angle)
        Draw.Text(labelX - (width * 0.5), labelY - (height * 0.5), s_Colors.Muted, text, size)
    end
end

local function DrawNeedle(centerX, centerY, radius, ratio, scale)
    local x, y = Polar(centerX, centerY, radius - (19 * scale), START_ANGLE + (SWEEP * ratio))
    Draw.Line(centerX, centerY, x, y, Style.Shadow, 6 * scale)
    Draw.Line(centerX, centerY, x, y, s_Colors.Needle, 3 * scale)
    Draw.CircleFilled(centerX, centerY, 5 * scale, s_Colors.Text)
end

local function DrawGauge(x, y, gauge, ratio, maximum, divisions, label, scale, textSize)
    local centerX = x + (gauge.X * scale)
    local centerY = y + (gauge.Y * scale)
    local radius = gauge.Radius * scale
    ratio = Animation.Clamp(ratio, 0, 1)

    DrawRing(centerX, centerY, radius, ratio, scale)
    DrawTicks(centerX, centerY, radius, maximum, divisions, scale, textSize * TICK_TEXT)
    DrawNeedle(centerX, centerY, radius, ratio, scale)
    CenterText(centerX, centerY + radius - (6 * scale), s_Colors.Muted, label, textSize * LABEL_TEXT)
end

local function DrawGear(x, y, scale, textSize)
    local centerX = x + (SPEED_GAUGE.X * scale)
    local centerY = y + (SPEED_GAUGE.Y * scale)
    CenterText(centerX, centerY + (14 * scale), s_Colors.Muted, L("vehicles.speedometer.gauge.gear"), textSize * LABEL_TEXT)
    CenterText(centerX, centerY + (30 * scale), s_Colors.Active, s_Gear, textSize * GEAR_TEXT)
end

local function MaxKph()
    if Speedometer.AutoMax and s_DetectedMax then return s_DetectedMax end
    return math.max(1, Speedometer.MaxSpeed)
end

local function DrawGauges(x, y, scale)
    UpdateColors()

    local textSize = Scale.FontSize() * Speedometer.Scale
    local mph = Speedometer.UseMph
    local maximum, divisions = NiceScale(mph and (MaxKph() / KPH_PER_MPH) or MaxKph(), SPEED_STEPS, SPEED_DIVISIONS)
    local speed = mph and s_SpeedMph or (s_SpeedMph * KPH_PER_MPH)
    local unit = L(mph and "vehicles.speedometer.gauge.mph" or "vehicles.speedometer.gauge.kmh")

    DrawGauge(x, y, SPEED_GAUGE, speed / maximum, maximum, divisions, unit, scale, textSize)
    DrawGear(x, y, scale, textSize)

    if not Speedometer.ShowRpm then return end

    local rpmMaximum, rpmDivisions = NiceScale(math.max(1, s_MaxRpm / 1000), RPM_STEPS, RPM_DIVISIONS)
    DrawGauge(x, y, RPM_GAUGE, s_Rpm / (rpmMaximum * 1000), rpmMaximum, rpmDivisions,
        L("vehicles.speedometer.gauge.rpm"), scale, textSize)
end

function Speedometer.Draw()
    if not Speedometer.Enabled or s_Alpha < MIN_ALPHA or os.clock() - s_SeenAt > STALE_TIME then
        s_DrawX = nil
        return
    end

    local scale = Scale.S(Speedometer.Scale)
    local width = (Speedometer.ShowRpm and FULL_WIDTH or SPEED_WIDTH) * scale
    local height = HEIGHT * scale
    local x, y = Place(width, height)
    if Drag(x, y, width, height) then x, y = Place(width, height) end

    local previous = Draw.GetAlpha()
    Draw.SetAlpha(s_Alpha)

    local ok, err = true, nil
    if Draw.BeginWindow("##EasyTrainerSpeedometer", x, y, width, height) then
        ok, err = pcall(DrawGauges, x, y, scale)
        if ok and Draggable() then Draw.Rect(x, y, width, height, Style.Accent, Scale.S(6), nil, s_Drag and 2 or 1) end
    end
    Draw.EndWindow()
    Draw.SetAlpha(previous)

    if not ok then error(err, 0) end
end

function Speedometer.Reset()
    s_HudController = nil
    s_HudHidden = false
    s_VehicleHash = nil
    s_Alpha = 0
    s_SpeedMph = 0
    s_Rpm = 0
    s_Gear = "N"
    s_DrawX = nil
end

function Speedometer.Shutdown()
    if s_HudHidden then ApplyHud(false) end
    s_HudController = nil
end

return Speedometer
