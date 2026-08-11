local BindButton = require("UI/Options/BindButton")
local Break = require("UI/Widgets/Break/Break")
local Button = require("UI/Widgets/Button/Button")
local Dropdown = require("UI/Widgets/Dropdown/Dropdown")
local Navigation = require("UI/Navigation/Navigation")
local OptionConfig = require("Config/OptionConfig")
local OptionRegistry = require("UI/Registry/OptionRegistry")
local Submenu = require("UI/Navigation/Submenu")
local Toggle = require("UI/Widgets/Toggle/Toggle")
local ControlState = require("Controls/State")
local Style = require("UI/Style/Style")
local ColorPicker = require("UI/Widgets/ColorPicker/ColorPicker")

local Buttons = {}
local ActiveTextRef = nil
local TextBuffer = ""
local PreviousMouseEnabled = false
local ColorMetadata = setmetatable({}, { __mode = "k" })

local function Id(label, ref, suffix)
    local registered = type(ref) == "table" and OptionRegistry.FindByRef(ref) or nil
    if registered then return registered.Id .. "##" .. (suffix or "option") end
    return table.concat({ tostring(label or "option"), tostring(ref or ""), suffix or "" }, "##")
end

local function Translate(value)
    return type(L) == "function" and L(value) or tostring(value or "")
end

local function NormalizeSubmenu(submenu)
    if not submenu then return nil end
    if submenu.Title and submenu.View then return submenu end
    if not submenu._ConsolidatedSubmenu then
        submenu._ConsolidatedSubmenu = Submenu.Create(submenu.title or "", submenu.view)
    end
    return submenu._ConsolidatedSubmenu
end

function Buttons.Option(label, tip, action)
    local activated, data = Button.Draw(label, tip, nil, Id(label, action, "button"))
    if activated and action then action() end
    return activated, data
end

function Buttons.OptionExtended(left, center, right, tip, action)
    local value = right and right ~= "" and right or center
    local activated, data = Button.Draw(left, tip, value, Id(left, action, "extended"))
    if activated and action then action() end
    return activated, data
end

function Buttons.Break(left, center, right)
    local label, alignment = left, "left"
    if center and center ~= "" then label, alignment = center, "center" end
    if right and right ~= "" then label, alignment = right, "right" end
    Break.Draw(label or "", alignment)
    return false
end

function Buttons.Submenu(label, submenu, tip, action)
    local target = NormalizeSubmenu(submenu)
    local activated, data = Button.Draw(label, tip, ">", Id(label, submenu, "submenu"))
    if activated then
        if action then action() end
        if target then Submenu.Open(target, Navigation) end
    end
    return activated, data
end

function Buttons.Toggle(label, ref, tip, action)
    OptionRegistry.Observe(ref, {
        Kind = OptionRegistry.Kind.Toggle,
        Label = label,
        Tip = tip,
        Action = action,
    })
    local changed = Toggle.Draw(label, ref, tip, Id(label, ref, "toggle"))
    if changed then
        OptionRegistry.MarkChanged(ref)
        OptionConfig.Save()
        if action then action(ref.value) end
    end
    return changed
end

function Buttons.GhostToggle(label, ref, tip, action)
    local changed, data = Toggle.Draw(label, ref, tip, Id(label, ref, "ghost"))
    if changed and action then action(ref.value) end
    return changed, data
end

local function Numeric(label, ref, tip, isFloat, clickOnly)
    local minimum = ref.min or 0
    local maximum = ref.max or (isFloat and 1 or 100)
    local step = ref.step or (isFloat and 0.05 or 1)
    local decimals = isFloat and 2 or 0
    local valueText = string.format("%." .. decimals .. "f", tonumber(ref.value) or minimum)
    if ref.enabled ~= nil then valueText = valueText .. (ref.enabled and "  ON" or "  OFF") end

    local activated, data = Button.DrawValue(label, tip, valueText, Id(label, ref, isFloat and "float" or "int"))
    local changed = false
    if data and data.Visible and data.Selected and Navigation.State.ModeCurrent == Navigation.State.Mode.Menu then
        if data.ValueDirection == -1 or Navigation.Input.LeftPressed then
            ref.value = (tonumber(ref.value) or minimum) - step
            if ref.value < minimum then ref.value = maximum end
            changed = true
        elseif data.ValueDirection == 1 or Navigation.Input.RightPressed then
            ref.value = (tonumber(ref.value) or minimum) + step
            if ref.value > maximum then ref.value = minimum end
            changed = true
        elseif activated and ref.enabled ~= nil then
            ref.enabled = not ref.enabled
            changed = true
        end
    end

    ref.value = math.max(minimum, math.min(maximum, tonumber(ref.value) or minimum))
    if isFloat then ref.value = tonumber(string.format("%.2f", ref.value)) end
    if clickOnly then return activated and data.ValueDirection == nil end
    return changed or activated
end

function Buttons.Int(label, ref, tip, action)
    local changed = Numeric(label, ref, tip, false, false)
    if changed and OptionRegistry.MarkChanged(ref) then OptionConfig.Save() end
    if changed and action then action(ref.value) end
    return changed
end

function Buttons.Float(label, ref, tip, action)
    local changed = Numeric(label, ref, tip, true, false)
    if changed and OptionRegistry.MarkChanged(ref) then OptionConfig.Save() end
    if changed and action then action(ref.value) end
    return changed
end

function Buttons.IntClick(label, ref, tip, action)
    local clicked = Numeric(label, ref, tip, false, true)
    if clicked and action then action(ref.value) end
    return clicked
end

function Buttons.FloatClick(label, ref, tip, action)
    local clicked = Numeric(label, ref, tip, true, true)
    if clicked and action then action(ref.value) end
    return clicked
end

function Buttons.Dropdown(label, ref, options, tip, action)
    local function OnChange(index, value)
        if OptionRegistry.MarkChanged(ref) then OptionConfig.Save() end
        if action then action(index, value) end
    end
    return Dropdown.Option(Id(label, ref, "dropdown"), label, ref, options, tip, OnChange)
end

function Buttons.Radio(_, ref, options, tip, action)
    local changed = false
    for index, option in ipairs(options or {}) do
        local marker = ref.index == index and "*" or ""
        if Button.Draw(Translate(option), tip, marker, Id(option, ref, "radio" .. index)) then
            ref.index = index
            changed = true
            if action then action(index, option) end
        end
    end
    return changed
end

local function Cycle(label, ref, options, tip, clickOnly)
    if #options == 0 then return false end
    ref.index = math.max(1, math.min(ref.index or 1, #options))
    local activated, data = Button.DrawValue(label, tip, Translate(options[ref.index]), Id(label, ref, "cycle"))
    local changed = false
    if data and data.Visible and data.Selected and Navigation.State.ModeCurrent == Navigation.State.Mode.Menu then
        if data.ValueDirection == -1 or Navigation.Input.LeftPressed then
            ref.index = ((ref.index - 2) % #options) + 1
            changed = true
        elseif data.ValueDirection == 1 or Navigation.Input.RightPressed then
            ref.index = (ref.index % #options) + 1
            changed = true
        end
    end
    if clickOnly then return activated and data.ValueDirection == nil end
    return changed or activated
end

function Buttons.StringCycler(label, ref, options, tip)
    return Cycle(label, ref, options, tip, false)
end

function Buttons.StringCyclerClick(label, ref, options, tip)
    return Cycle(label, ref, options, tip, true)
end

function Buttons.Color(label, ref, tip)
    return ColorPicker.Option(Id(label, ref, "color"), label, ref, tip)
end

function Buttons.Bind(label, action, tip)
    return BindButton.Option(label, action, tip)
end

function Buttons.ColorHex(label, tbl, key, tip)
    ColorMetadata[tbl] = ColorMetadata[tbl] or {}
    ColorMetadata[tbl][key] = ColorMetadata[tbl][key] or {}
    local ref = ColorMetadata[tbl][key]
    local ownerId = Id(label, ref, "color")
    if not ColorPicker.IsOwner(ownerId) then
        local color = ImGui.ColorConvertU32ToFloat4(tbl[key])
        ref.Red, ref.Green, ref.Blue, ref.Alpha =
            math.floor(color[1] * 255), math.floor(color[2] * 255),
            math.floor(color[3] * 255), math.floor(color[4] * 255)
    end
    local changed = Buttons.Color(label, ref, tip)
    if changed then
        tbl[key] = ImGui.ColorConvertFloat4ToU32({ ref.Red / 255, ref.Green / 255, ref.Blue / 255, ref.Alpha / 255 })
    end
    return changed
end

function Buttons.Text(label, ref, tip, action)
    local activated = Button.Draw(label, tip, ref.value or "", Id(label, ref, "text"))
    if activated then
        ActiveTextRef = ref
        TextBuffer = ref.value or ""
        PreviousMouseEnabled = ControlState.mouseEnabled
        ControlState.typingEnabled = true
        ControlState.mouseEnabled = true
    end
    if ActiveTextRef ~= ref then return false end

    local width, height = 440, 150
    local screenWidth, screenHeight = GetDisplayResolution()
    local background = ImGui.ColorConvertU32ToFloat4(Style.Background)
    local border = ImGui.ColorConvertU32ToFloat4(Style.Border)
    local frame = ImGui.ColorConvertU32ToFloat4(Style.BackgroundDark)
    local accent = ImGui.ColorConvertU32ToFloat4(Style.Accent)
    ImGui.SetNextWindowPos((screenWidth - width) * 0.5, (screenHeight - height) * 0.5)
    ImGui.SetNextWindowSize(width, height)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 8)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 5)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 16, 14)
    ImGui.PushStyleColor(ImGuiCol.WindowBg, background[1], background[2], background[3], background[4])
    ImGui.PushStyleColor(ImGuiCol.Border, border[1], border[2], border[3], border[4])
    ImGui.PushStyleColor(ImGuiCol.FrameBg, frame[1], frame[2], frame[3], frame[4])
    ImGui.PushStyleColor(ImGuiCol.Button, frame[1], frame[2], frame[3], frame[4])
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, accent[1], accent[2], accent[3], accent[4])
    ImGui.Begin("Edit Value###EasyTrainerTextInput", ImGuiWindowFlags.NoResize + ImGuiWindowFlags.NoCollapse)
    ImGui.TextColored(accent[1], accent[2], accent[3], accent[4], label)
    ImGui.Spacing()
    ImGui.PushItemWidth(-1)
    local value, edited = ImGui.InputText("##Value", TextBuffer, 256)
    ImGui.PopItemWidth()
    if edited then TextBuffer = value end
    ImGui.Spacing()
    local committed = false
    if ImGui.Button("Apply", 92, 28) then
        ref.value = TextBuffer
        ActiveTextRef = nil
        ControlState.typingEnabled = false
        ControlState.mouseEnabled = PreviousMouseEnabled
        committed = true
        if action then action(ref.value) end
    end
    ImGui.SameLine()
    if ImGui.Button("Cancel", 92, 28) then
        ActiveTextRef = nil
        ControlState.typingEnabled = false
        ControlState.mouseEnabled = PreviousMouseEnabled
    end
    ImGui.End()
    ImGui.PopStyleColor(5)
    ImGui.PopStyleVar(3)
    return committed
end

return Buttons
