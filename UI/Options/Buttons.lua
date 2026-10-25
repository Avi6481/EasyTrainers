local BindButton = require("UI/Options/BindButton")
local Icons = require("UI/Style/Icons")
local Break = require("UI/Widgets/Break/Break")
local Button = require("UI/Widgets/Button/Button")
local Dropdown = require("UI/Widgets/Dropdown/Dropdown")
local Navigation = require("UI/Navigation/Navigation")
local OptionConfig = require("Config/OptionConfig")
local OptionRegistry = require("UI/Registry/OptionRegistry")
local Submenu = require("UI/Navigation/Submenu")
local Toggle = require("UI/Widgets/Toggle/Toggle")
local ControlState = require("Controls/State")
local Layout = require("UI/Style/Layout")
local Style = require("UI/Style/Style")
local ColorPicker = require("UI/Widgets/ColorPicker/ColorPicker")
local Draw = require("UI/Core/Draw")
local Mouse = require("Core/Mouse")
local Typing = require("Core/Typing")

local Buttons = {}
local s_ActiveTextRef = nil
local s_TextBuffer = ""
local s_PreviousMouseEnabled = false
local s_ColorMetadata = setmetatable({}, { __mode = "k" })

local function Id(label, ref, suffix)
    local registered = type(ref) == "table" and OptionRegistry.FindByRef(ref) or nil
    if registered then return registered.Id .. "##" .. (suffix or "option") end
    local refKey = type(ref) == "table" and tostring(ref) or ""
    return table.concat({ tostring(label or "option"), refKey, suffix or "" }, "##")
end

local function Translate(value)
    return type(L) == "function" and L(value) or tostring(value or "")
end

local function HotkeyFor(target)
    local entry = type(target) == "function" and OptionRegistry.FindByAction(target) or OptionRegistry.FindByRef(target)
    if not entry or not OptionRegistry.IsHotkeyable(entry) then return nil end
    return OptionRegistry.GetHotkeyAction(entry)
end

local function HotkeyTip(tip, hotkey)
    local bound = BindButton.Format(hotkey)
    local hint = "Hotkey: " .. bound .. ". Press " .. BindButton.Format("MISC") .. " to rebind."
    if not tip or tip == "" then return hint end
    return tip .. " " .. hint
end

function Buttons.Option(label, tip, action)
    local hotkey = action and HotkeyFor(action)
    if hotkey and BindButton.IsCapturing(hotkey) then
        BindButton.Option(label, hotkey, tip)
        return false
    end

    local activated, data = Button.Draw(label, hotkey and HotkeyTip(tip, hotkey) or tip, nil, Id(label, action, "button"))
    if hotkey and data and data.Selected and ControlState.MiscPressed then
        BindButton.Begin(hotkey, label)
        return false
    end

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
    local activated, data = Button.Draw(label, tip, Icons.Submenu, Id(label, submenu, "submenu"))
    if activated then
        if action then action() end
        if submenu then Submenu.Open(submenu, Navigation) end
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

    local hotkey = HotkeyFor(ref)
    if hotkey and BindButton.IsCapturing(hotkey) then
        BindButton.Option(label, hotkey, tip)
        return false
    end

    local changed, data = Toggle.Draw(label, ref, hotkey and HotkeyTip(tip, hotkey) or tip, Id(label, ref, "toggle"))
    if hotkey and data and data.Selected and ControlState.MiscPressed then
        if changed then ref.value = not ref.value end
        BindButton.Begin(hotkey, label)
        return false
    end

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

local function Decimals(step, isFloat)
    if not isFloat or step >= 1 then return 0 end
    if step >= 0.1 then return 1 end
    return 2
end

local function FormatNumber(ref, decimals)
    local text = string.format("%." .. decimals .. "f", tonumber(ref.value) or 0)
    if ref.unit then text = text .. " " .. ref.unit end
    if ref.enabled ~= nil then text = text .. (ref.enabled and "  ON" or "  OFF") end
    return text
end

local function Snap(value, minimum, step)
    return minimum + math.floor(((value - minimum) / step) + 0.5) * step
end

local function Numeric(label, ref, tip, isFloat, clickOnly)
    local minimum = ref.min or 0
    local maximum = ref.max or (isFloat and 1 or 100)
    local step = ref.step or (isFloat and 0.05 or 1)
    local decimals = Decimals(step, isFloat)
    local current = tonumber(ref.value) or minimum
    local ratio = maximum > minimum and (current - minimum) / (maximum - minimum) or nil

    local activated, data = Button.DrawValue(label, tip, FormatNumber(ref, decimals), Id(label, ref, isFloat and "float" or "int"), ratio)
    local changed = false
    if data and data.Visible and data.Selected and Navigation.State.ModeCurrent == Navigation.State.Mode.Menu then
        if data.ValueRatio then
            ref.value = Snap(minimum + data.ValueRatio * (maximum - minimum), minimum, step)
            changed = true
        elseif data.ValueDirection == -1 or Navigation.Input.LeftPressed then
            ref.value = current - step
            if ref.value < minimum then ref.value = maximum end
            changed = true
        elseif data.ValueDirection == 1 or Navigation.Input.RightPressed then
            ref.value = current + step
            if ref.value > maximum then ref.value = minimum end
            changed = true
        elseif activated and ref.enabled ~= nil then
            ref.enabled = not ref.enabled
            changed = true
        end
    end

    ref.value = math.max(minimum, math.min(maximum, tonumber(ref.value) or minimum))
    if isFloat then ref.value = tonumber(string.format("%.4f", ref.value)) end
    if clickOnly then return activated and data.ValueDirection == nil and data.ValueRatio == nil end
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
        local marker = ref.index == index and Icons.Selected or ""
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
    s_ColorMetadata[tbl] = s_ColorMetadata[tbl] or {}
    s_ColorMetadata[tbl][key] = s_ColorMetadata[tbl][key] or {}
    local ref = s_ColorMetadata[tbl][key]
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

local TEXT_WIDTH = 440
local TEXT_HEIGHT = 150
local TEXT_BUTTON_WIDTH = 92
local TEXT_BUTTON_HEIGHT = 28

local function CloseText()
    Typing.End()
    s_ActiveTextRef = nil
    ControlState.TypingEnabled = false
    ControlState.MouseEnabled = s_PreviousMouseEnabled
end

local function TextButton(drawList, x, y, label)
    local hovered = Mouse.IsInside(x, y, TEXT_BUTTON_WIDTH, TEXT_BUTTON_HEIGHT)
    Draw.RectFilled(drawList, x, y, TEXT_BUTTON_WIDTH, TEXT_BUTTON_HEIGHT, hovered and Style.Accent or Style.BackgroundDark, 5)
    Draw.Rect(drawList, x, y, TEXT_BUTTON_WIDTH, TEXT_BUTTON_HEIGHT, Style.Border, 5, 1)
    Draw.Text(drawList, x + (TEXT_BUTTON_WIDTH - ImGui.CalcTextSize(label)) * 0.5, y + (TEXT_BUTTON_HEIGHT - ImGui.GetFontSize()) * 0.5, Style.Text, label)
    return hovered and Mouse.IsClicked()
end

local function DrawTextWindow(label)
    local screenWidth, screenHeight = GetDisplayResolution()
    local x, y = (screenWidth - TEXT_WIDTH) * 0.5, (screenHeight - TEXT_HEIGHT) * 0.5
    ImGui.SetNextWindowPos(x, y)
    ImGui.SetNextWindowSize(TEXT_WIDTH, TEXT_HEIGHT)
    ImGui.PushStyleColor(ImGuiCol.WindowBg, 0, 0, 0, 0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowBorderSize, 0)
    ImGui.Begin("###EasyTrainerTextInput", ImGuiWindowFlags.NoDecoration + ImGuiWindowFlags.NoSavedSettings + ImGuiWindowFlags.NoMove)
    Layout.ApplyFontScale()

    local drawList = ImGui.GetWindowDrawList()
    Draw.RectFilled(drawList, x, y, TEXT_WIDTH, TEXT_HEIGHT, Style.Background, 8)
    Draw.Rect(drawList, x, y, TEXT_WIDTH, TEXT_HEIGHT, Style.Border, 8, 1)
    Draw.Text(drawList, x + 16, y + 14, Style.Accent, label)

    local boxY = y + 44
    local caret = math.floor(os.clock() * 2) % 2 == 0 and "|" or ""
    Draw.RectFilled(drawList, x + 16, boxY, TEXT_WIDTH - 32, 30, Style.BackgroundDark, 5)
    Draw.Rect(drawList, x + 16, boxY, TEXT_WIDTH - 32, 30, Style.Accent, 5, 1)
    Draw.Text(drawList, x + 24, boxY + (30 - ImGui.GetFontSize()) * 0.5, Style.Text, Draw.FitText(s_TextBuffer .. caret, TEXT_WIDTH - 48))
    Draw.Text(drawList, x + 16, boxY + 38, Style.TextDisabled, "Enter to apply, Esc to cancel.")

    local buttonY = y + TEXT_HEIGHT - TEXT_BUTTON_HEIGHT - 12
    local apply = TextButton(drawList, x + TEXT_WIDTH - (TEXT_BUTTON_WIDTH * 2) - 24, buttonY, "Apply")
    local cancel = TextButton(drawList, x + TEXT_WIDTH - TEXT_BUTTON_WIDTH - 16, buttonY, "Cancel")

    ImGui.End()
    ImGui.PopStyleVar()
    ImGui.PopStyleColor()
    return apply, cancel
end

function Buttons.Text(label, ref, tip, action)
    local activated = Button.Draw(label, tip, ref.value or "", Id(label, ref, "text"))
    if activated then
        s_ActiveTextRef = ref
        s_TextBuffer = ref.value or ""
        s_PreviousMouseEnabled = ControlState.MouseEnabled
        ControlState.TypingEnabled = true
        ControlState.MouseEnabled = true
        Typing.Begin()
    end
    if s_ActiveTextRef ~= ref then return false end

    local buffer, submitted, cancelled = Typing.Update(s_TextBuffer)
    s_TextBuffer = buffer

    local apply, cancel = DrawTextWindow(label)
    if cancelled or cancel then
        CloseText()
        return false
    end
    if not submitted and not apply then return false end

    ref.value = s_TextBuffer
    CloseText()
    if action then action(ref.value) end
    return true
end

return Buttons
