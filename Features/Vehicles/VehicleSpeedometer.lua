local Vehicle = require("Utils/Vehicle")
local Animation = require("UI/Widgets/Animation/Animation")
local Draw = require("UI/Core/Draw")
local Style = require("UI/Style/Style")
local Navigation = require("UI/Navigation/Navigation")
local UIConfig = require("Config/UIConfig")
local Mouse = require("Core/Mouse")

local Speedometer = {
    Enabled = { value = false },
    ShowRPM = { value = true },
    UseMPH = { value = false },
    AutomaticMaxSpeed = { value = false },
    HideGameSpeedometer = { value = false },
    MaxSpeed = { value = 320, min = 160, max = 500, step = 20, unit = "km/h" },
    Scale = { value = 1.0, min = 0.7, max = 1.4, step = 0.05, unit = "x" },
    Position = { index = 1 },
    Positions = { "Bottom Right", "Bottom Left", "Top Right", "Top Left" },
    OffsetX = { value = 0, min = -4000, max = 4000, step = 5, unit = "px" },
    OffsetY = { value = 0, min = -4000, max = 4000, step = 5, unit = "px" },
    Colors = {
        Active = 0xFFA56E3A,
        Needle = 0xFFFFFFFF,
        Text = 0xFFFFFFFF,
        Muted = 0xFFA08C78,
        Ring = 0xFF6E5A50
    },
    SpeedMPH = 0,
    RPM = 0,
    MaxRPM = 8000,
    DetectedMaxSpeed = nil,
    Gear = "N",
    Alpha = 0
}

UIConfig.RegisterSection("Speedometer", {
    MaxSpeed = Speedometer.MaxSpeed,
    AutomaticMaxSpeed = Speedometer.AutomaticMaxSpeed,
    ShowRPM = Speedometer.ShowRPM,
    HideGameSpeedometer = Speedometer.HideGameSpeedometer,
    Scale = Speedometer.Scale,
    Position = Speedometer.Position,
    OffsetX = Speedometer.OffsetX,
    OffsetY = Speedometer.OffsetY,
    Colors = Speedometer.Colors
})

local MPH_TO_KPH = 1.61
local MARGIN = 24
local BASE_WIDTH = 300
local BASE_HEIGHT = 220
local FADE_SPEED = 8
local NEEDLE_SPEED = 10
local MOVE_SPEED = 12
local SPEED_DIVISIONS = 10
local RPM_DIVISIONS = 5
local SPEED_STEPS = { 10, 20, 30, 40, 50, 60, 80, 100 }
local RPM_STEPS = { 1, 2 }

local s_CurveSet = nil
local s_CurveName = nil
local s_VehicleHash = nil
local s_HudController = nil
local s_HudHidden = false
local s_Dragging = false
local s_DragX = 0
local s_DragY = 0
local s_DrawX = nil
local s_DrawY = nil
local s_LastRender = nil

local function Curves()
    if not s_CurveSet then
        s_CurveSet = CName.new("vehicle_ui")
        s_CurveName = CName.new("speed_to_multiplier")
    end
    return s_CurveSet, s_CurveName
end

local function RawSpeedToMPH(rawSpeed)
    rawSpeed = math.abs(rawSpeed or 0)
    local statsData = Game.GetStatsDataSystem()
    if not statsData then return rawSpeed end

    local curveSet, curveName = Curves()
    local multiplier = statsData:GetValueFromCurve(curveSet, rawSpeed, curveName) or 1
    return rawSpeed * multiplier
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

local function ReadEngine(vehicle)
    Speedometer.MaxRPM = 8000
    Speedometer.DetectedMaxSpeed = nil

    local ok, engine = pcall(function() return vehicle:GetRecord():VehEngineData() end)
    if not ok or not engine then return end

    Speedometer.MaxRPM = math.max(1000, engine:MaxRPM() or 8000)

    local topSpeed = 0
    for index = 0, (engine:GetGearsCount() or 0) - 1 do
        local gear = engine:GetGearsItem(index)
        if gear then topSpeed = math.max(topSpeed, gear:MaxSpeed() or 0) end
    end

    if topSpeed > 0 then
        Speedometer.DetectedMaxSpeed = math.max(80, math.min(500, RoundUp(RawSpeedToMPH(topSpeed) * MPH_TO_KPH, 20)))
    end
end

local function GearLabel(gear, speedMPH)
    if gear < 0 then return "R" end
    if gear == 0 then return speedMPH < 1 and "N" or "1" end
    return tostring(gear)
end

local function IsThirdPerson()
    local blackboards = Game.GetBlackboardSystem()
    local defs = GetAllBlackboardDefs()
    local activeVehicle = blackboards and blackboards:Get(defs.UI_ActiveVehicleData) or nil
    return activeVehicle ~= nil and activeVehicle:GetBool(defs.UI_ActiveVehicleData.IsTPPCameraOn)
end

local function ApplyHudVisibility()
    if not s_HudController then return end

    local hide = Speedometer.Enabled.value and Speedometer.HideGameSpeedometer.value
    local ok, root = pcall(function() return s_HudController:GetRootWidget() end)
    if not ok or not root then
        s_HudController = nil
        return
    end

    if hide then
        root:SetVisible(false)
    elseif s_HudHidden then
        root:SetVisible(IsThirdPerson())
    end
    s_HudHidden = hide
end

function Speedometer.OnHudCameraChanged(controller)
    s_HudController = controller
    if Speedometer.Enabled.value and Speedometer.HideGameSpeedometer.value then ApplyHudVisibility() end
end

local function ResetReadings(deltaTime)
    Speedometer.SpeedMPH = Animation.Animate(Speedometer.SpeedMPH, 0, FADE_SPEED, deltaTime)
    Speedometer.RPM = Animation.Animate(Speedometer.RPM, 0, FADE_SPEED, deltaTime)
    Speedometer.Gear = "N"
    s_VehicleHash = nil
end

function Speedometer.Update(deltaTime)
    local dt = math.max(0.001, deltaTime or (1 / 60))
    local wantHudHidden = Speedometer.Enabled.value and Speedometer.HideGameSpeedometer.value
    if wantHudHidden ~= s_HudHidden then ApplyHudVisibility() end

    if not Speedometer.Enabled.value then
        Speedometer.Alpha = 0
        s_VehicleHash = nil
        return
    end

    local vehicle = Vehicle.GetMountedVehicleSafe()
    Speedometer.Alpha = Animation.Animate(Speedometer.Alpha, vehicle and 1 or 0, FADE_SPEED, dt)
    if not vehicle then
        ResetReadings(dt)
        return
    end

    local hash = vehicle:GetEntityID().hash
    if hash ~= s_VehicleHash then
        s_VehicleHash = hash
        ReadEngine(vehicle)
    end

    local blackboard = vehicle:GetBlackboard()
    if not blackboard then return end

    local defs = GetAllBlackboardDefs().Vehicle
    local speedMPH = RawSpeedToMPH(blackboard:GetFloat(defs.SpeedValue))
    local rpm = blackboard:GetFloat(defs.RPMValue) or 0
    local gear = blackboard:GetInt(defs.GearValue) or 0

    Speedometer.SpeedMPH = Animation.Animate(Speedometer.SpeedMPH, speedMPH, NEEDLE_SPEED, dt)
    Speedometer.RPM = Animation.Animate(Speedometer.RPM, rpm, NEEDLE_SPEED, dt)
    Speedometer.Gear = GearLabel(gear, speedMPH)
end

local function BasePosition(width, height)
    local screenWidth, screenHeight = GetDisplayResolution()
    local selected = Speedometer.Positions[Speedometer.Position.index or 1]
    if selected == "Bottom Left" then return MARGIN, screenHeight - height - MARGIN end
    if selected == "Top Right" then return screenWidth - width - MARGIN, MARGIN end
    if selected == "Top Left" then return MARGIN, MARGIN end
    return screenWidth - width - MARGIN, screenHeight - height - MARGIN
end

local function Position(width, height)
    local screenWidth, screenHeight = GetDisplayResolution()
    local baseX, baseY = BasePosition(width, height)
    local x = baseX + (Speedometer.OffsetX.value or 0)
    local y = baseY + (Speedometer.OffsetY.value or 0)
    return math.max(0, math.min(screenWidth - width, x)), math.max(0, math.min(screenHeight - height, y))
end

local function UpdateDragging(x, y, width, height)
    if not Navigation.State.MouseEnabled then
        s_Dragging = false
        return false
    end

    local mouseX, mouseY = Mouse.GetPosition()
    local inside = mouseX >= x and mouseX <= x + width and mouseY >= y and mouseY <= y + height

    if inside and Mouse.IsClicked() then
        s_Dragging = true
        s_DragX = mouseX - x
        s_DragY = mouseY - y
    end

    if s_Dragging then
        if Mouse.IsDown() then
            local baseX, baseY = BasePosition(width, height)
            Speedometer.OffsetX.value = math.floor(mouseX - s_DragX - baseX)
            Speedometer.OffsetY.value = math.floor(mouseY - s_DragY - baseY)
        else
            s_Dragging = false
            UIConfig.Save()
        end
    end

    return true
end

local function Polar(centerX, centerY, radius, angle)
    return centerX + (math.cos(angle) * radius), centerY + (math.sin(angle) * radius)
end

local function TextCentered(drawList, x, y, color, text)
    local width = ImGui.CalcTextSize(text)
    Draw.Text(drawList, x - (width * 0.5), y, color, text)
end

local function DrawGauge(drawList, centerX, centerY, radius, ratio, maximum, divisions, label, alpha, scale, centerLabel, centerValue)
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
        TextCentered(drawList, labelX, labelY - (ImGui.GetFontSize() * 0.5), muted, tostring(math.floor((maximum * tickRatio) + 0.5)))
    end

    local needleX, needleY = Polar(centerX, centerY, radius - (19 * scale), startAngle + (sweep * ratio))
    Draw.Line(drawList, centerX, centerY, needleX, needleY, shadow, 6 * scale)
    Draw.Line(drawList, centerX, centerY, needleX, needleY, needle, 3 * scale)
    Draw.RectFilled(drawList, centerX - (5 * scale), centerY - (5 * scale), 10 * scale, 10 * scale, text, 5 * scale)

    if centerLabel then TextCentered(drawList, centerX, centerY + (14 * scale), muted, centerLabel) end
    if centerValue then TextCentered(drawList, centerX, centerY + (30 * scale), accent, centerValue) end
    TextCentered(drawList, centerX, centerY + radius - (6 * scale), muted, label)
end

local function DisplayValues()
    local useMPH = Speedometer.UseMPH.value
    local maximumKPH = math.max(1, (Speedometer.AutomaticMaxSpeed.value and Speedometer.DetectedMaxSpeed) or Speedometer.MaxSpeed.value)
    local speed = useMPH and Speedometer.SpeedMPH or Speedometer.SpeedMPH * MPH_TO_KPH
    local maximum, divisions = NiceScale(useMPH and maximumKPH / MPH_TO_KPH or maximumKPH, SPEED_STEPS, SPEED_DIVISIONS)
    return speed, maximum, divisions, useMPH and "MPH" or "KM/H"
end

local function FrameDelta()
    local now = os.clock()
    local delta = s_LastRender and (now - s_LastRender) or 0
    s_LastRender = now
    return math.max(0, math.min(0.1, delta))
end

local function SmoothPosition(width, height)
    local targetX, targetY = Position(width, height)
    local delta = FrameDelta()
    if not s_DrawX or s_Dragging then
        s_DrawX, s_DrawY = targetX, targetY
    else
        s_DrawX = Animation.Animate(s_DrawX, targetX, MOVE_SPEED, delta)
        s_DrawY = Animation.Animate(s_DrawY, targetY, MOVE_SPEED, delta)
    end
    return s_DrawX, s_DrawY
end

function Speedometer.Render(gameMenuOpen)
    if not Speedometer.Enabled.value or gameMenuOpen or Speedometer.Alpha < 0.01 then
        s_DrawX, s_LastRender = nil, nil
        return
    end

    local scale = Speedometer.Scale.value
    local width, height = BASE_WIDTH * scale, BASE_HEIGHT * scale
    local x, y = SmoothPosition(width, height)
    local draggable = UpdateDragging(x, y, width, height)
    if s_Dragging then x, y = SmoothPosition(width, height) end

    ImGui.SetNextWindowPos(x, y, ImGuiCond.Always)
    ImGui.SetNextWindowSize(width, height, ImGuiCond.Always)
    ImGui.PushStyleColor(ImGuiCol.WindowBg, 0, 0, 0, 0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowBorderSize, 0)
    ImGui.Begin("##EasyTrainerSpeedometer", ImGuiWindowFlags.NoDecoration + ImGuiWindowFlags.NoSavedSettings
        + ImGuiWindowFlags.NoResize + ImGuiWindowFlags.NoMove + ImGuiWindowFlags.NoScrollbar
        + ImGuiWindowFlags.NoScrollWithMouse + ImGuiWindowFlags.NoInputs + ImGuiWindowFlags.NoFocusOnAppearing)

    local drawList = ImGui.GetWindowDrawList()
    local alpha = Speedometer.Alpha
    local speed, maximum, divisions, unit = DisplayValues()

    if draggable then
        Draw.Rect(drawList, x, y, width, height, Animation.WithAlpha(Speedometer.Colors.Active, alpha * 0.6), 8 * scale, 1)
        TextCentered(drawList, x + width * 0.5, y + 4 * scale, Animation.WithAlpha(Speedometer.Colors.Muted, alpha), "Drag to move")
    end

    DrawGauge(drawList, x + (105 * scale), y + (104 * scale), 88 * scale, speed / maximum, maximum, divisions, unit, alpha, scale, "GEAR", Speedometer.Gear)
    if Speedometer.ShowRPM.value then
        local rpmMaximum, rpmDivisions = NiceScale(math.max(1, Speedometer.MaxRPM / 1000), RPM_STEPS, RPM_DIVISIONS)
        DrawGauge(drawList, x + (243 * scale), y + (151 * scale), 52 * scale, Speedometer.RPM / (rpmMaximum * 1000),
            rpmMaximum, rpmDivisions, "RPM x1000", alpha, scale)
    end

    ImGui.End()
    ImGui.PopStyleVar()
    ImGui.PopStyleColor()
end

return Speedometer
