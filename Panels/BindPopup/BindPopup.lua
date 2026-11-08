local Animation = require("Core/Animation")
local Draw = require("Core/Draw")
local Input = require("Core/Input")
local Language = require("Core/Language")
local State = require("Core/State")
local Style = require("Style/Style")
local Layout = require("Style/Layout")
local Scale = require("Style/Scale")
local Navigation = require("Navigation/Navigation")
local NavigationStyle = require("Navigation/NavigationStyle")
local Widget = require("Widgets/Core/Widget")
local KeyBind = require("Widgets/KeyBind/KeyBind")
local Sheet = require("Panels/Sheet/Sheet")
local TipBox = require("Panels/TipBox/TipBox")
local ControlsHud = require("Panels/ControlsHud/ControlsHud")
local Notify = require("Utils/Notify")
local Hotkeys = require("Features/Hotkeys/Hotkeys")

local BindPopup = {}

local STYLE = {
    Width = 400,
    Padding = 20,
    Gap = 10,
    EyebrowScale = 0.72,
    TitleScale = 1.25,
    TextScale = 0.9,
    AccentWidth = 3,
    FadeSpeed = 14
}

local CAPTURE_ID = "##EasyTrainerBindPopup"

local s_Definition = nil
local s_Shown = nil
local s_Before = ""
local s_Alpha = 0
local s_TipFor = nil
local s_TipVersion = -1
local s_TipCode = nil
local s_Tip = ""
local s_StatusKey = nil
local s_StatusSeconds = -1
local s_Status = ""

ControlsHud.SetBindKeys(KeyBind.KeyName(NavigationStyle.BindKey), KeyBind.ButtonName(NavigationStyle.BindButton))

local function Empty(binding)
    return #binding.Keys == 0 and #binding.Buttons == 0
end

local function HotkeyTip(definition)
    local version = Hotkeys.Version()
    local code = Language.GetCurrentCode()
    if s_TipFor == definition and s_TipVersion == version and s_TipCode == code then return s_Tip end

    s_TipFor, s_TipVersion, s_TipCode = definition, version, code
    local binding = Hotkeys.Binding(definition)
    s_Tip = Empty(binding) and "" or tip("bindpopup.tiphotkey", { keys = KeyBind.FormatBinding(binding) })
    return s_Tip
end

local function Selected()
    local label, kind = Widget.BindableRow()
    if not label then return nil end
    return Hotkeys.ForLabel(label, kind)
end

local function BindPressed()
    return Input.KeyPressed(NavigationStyle.BindKey) or Input.ButtonPressed(NavigationStyle.BindButton)
end

local function CanOpen()
    local menu = State.Menu
    if not menu.Open or menu.Typing or State.OverlayOpen or not Input.IsAvailable() then return false end
    return not Navigation.State.Editing and not Sheet.SheetVisible() and not KeyBind.IsCapturing()
end

local function Open(definition)
    s_Definition = definition
    s_Shown = definition
    s_Before = KeyBind.FormatBinding(Hotkeys.Binding(definition))
    KeyBind.Begin(CAPTURE_ID)
end

local function Finish(result)
    local definition = s_Definition
    s_Definition = nil

    local name = Hotkeys.Name(definition)
    local results = KeyBind.Results
    if result == results.Cancelled then
        Notify.Info(tip("notify.bindpopup.cancelled", { name = name }))
        return
    end
    if result == results.TimedOut then
        Notify.Warning(tip("notify.bindpopup.timedout", { name = name }))
        return
    end
    if KeyBind.FormatBinding(Hotkeys.Binding(definition)) == s_Before then
        Notify.Info(tip("notify.bindpopup.unchanged", { name = name }))
        return
    end

    Hotkeys.Changed(definition)
end

local function UpdateCapture()
    if KeyBind.CaptureId() ~= CAPTURE_ID then
        s_Definition = nil
        return
    end

    if not State.Menu.Open then
        KeyBind.Cancel()
        Finish(KeyBind.Results.Cancelled)
        return
    end

    local result = KeyBind.Update(Hotkeys.Binding(s_Definition))
    if result then Finish(result) end
end

function BindPopup.IsOpen()
    return s_Definition ~= nil
end

function BindPopup.Update()
    if s_Definition then
        ControlsHud.SetBindHint(false)
        UpdateCapture()
        return
    end

    local definition = Selected()
    ControlsHud.SetBindHint(definition ~= nil)
    if not definition then return end

    TipBox.SetSuffix(HotkeyTip(definition))
    if BindPressed() and CanOpen() then Open(definition) end
end

local function StatusText()
    local counting, seconds = KeyBind.Countdown()
    local key = counting and "bindpopup.countdown" or "bindpopup.waiting"
    if s_StatusKey ~= key or s_StatusSeconds ~= seconds then
        s_StatusKey, s_StatusSeconds = key, seconds
        s_Status = tip(key, { seconds = seconds })
    end
    return s_Status
end

local function Sizes()
    local font = Scale.FontSize()
    local sizes = {
        Eyebrow = font * STYLE.EyebrowScale,
        Title = font * STYLE.TitleScale,
        Text = font * STYLE.TextScale,
        Padding = Scale.S(STYLE.Padding),
        Gap = Scale.S(STYLE.Gap)
    }
    local _, keyHeight = Draw.TextSize("Ag", font * KeyBind.Style.KeyScale)
    local _, textHeight = Draw.TextSize("Ag", sizes.Text)
    sizes.Line = math.max(textHeight, keyHeight + Scale.S(KeyBind.Style.KeyPaddingY * 2))
    return sizes
end

local function Measure(sizes, width, name, hints)
    local inner = width - (sizes.Padding * 2)
    local _, eyebrowHeight = Draw.TextSize("Ag", sizes.Eyebrow)
    local titleHeight = Draw.WrapHeight(name, inner, sizes.Title)
    return sizes.Padding + eyebrowHeight + (sizes.Gap * 0.5) + titleHeight + (sizes.Gap * 1.5)
        + sizes.Line + sizes.Gap + sizes.Line + (sizes.Gap * 1.5)
        + Draw.WrapHeight(hints, inner, sizes.Text) + sizes.Padding
end

local function DrawValue(names, right, centerY, color, empty, size)
    if #names > 0 then
        KeyBind.DrawKeycaps(names, right, centerY, color, Style.Text)
        return
    end

    local width, height = Draw.TextSize(empty, size)
    Draw.Text(right - width, centerY - (height * 0.5), Style.TextDisabled, empty, size)
end

local function DrawBox(x, y, width, height, sizes, name, hints)
    local padding = sizes.Padding
    local inner = width - (padding * 2)
    local rounding = Scale.S(Layout.Rounding)
    local right = x + width - padding - 3

    Draw.RectFilled(x + 3, y + 3, width - 3, height - 3, Style.Shadow, rounding)
    Draw.RectFilled(x, y, width - 3, height - 3, Style.BackgroundLight, rounding)
    Draw.LeftAccent(x, y, height - 3, Style.Accent, rounding, Scale.S(STYLE.AccentWidth))
    Draw.Rect(x, y, width - 3, height - 3, Style.Border, rounding, nil, 1)

    local cursor = y + padding
    local eyebrow = L("bindpopup.title"):upper()
    local _, eyebrowHeight = Draw.TextSize(eyebrow, sizes.Eyebrow)
    Draw.Text(x + padding, cursor, Style.Accent, eyebrow, sizes.Eyebrow)
    cursor = cursor + eyebrowHeight + (sizes.Gap * 0.5)

    Draw.TextWrapped(x + padding, cursor, inner, Style.Text, name, sizes.Title)
    cursor = cursor + Draw.WrapHeight(name, inner, sizes.Title) + (sizes.Gap * 1.5)

    local binding = Hotkeys.Binding(s_Shown)
    local centerY = cursor + (sizes.Line * 0.5)
    local label = L("bindpopup.current")
    local _, labelHeight = Draw.TextSize(label, sizes.Text)
    Draw.Text(x + padding, centerY - (labelHeight * 0.5), Style.TextSoft, label, sizes.Text)
    DrawValue(KeyBind.Names(binding.Keys, binding.Buttons), right, centerY, Style.Border, L("hotkeys.info.none"), sizes.Text)
    cursor = cursor + sizes.Line + sizes.Gap

    centerY = cursor + (sizes.Line * 0.5)
    local capturing = s_Definition ~= nil and KeyBind.CaptureId() == CAPTURE_ID
    local held = capturing and KeyBind.HeldNames() or {}
    local pulse = 0.55 + (0.45 * ((math.sin(State.Time.Time * 6) + 1) * 0.5))
    local status = capturing and StatusText() or ""
    local statusWidth, statusHeight = Draw.TextSize(status, sizes.Text)
    if #held > 0 then
        Draw.Text(x + padding, centerY - (statusHeight * 0.5), Style.TextSoft, L("bindpopup.new"), sizes.Text)
        KeyBind.DrawKeycaps(held, right, centerY, Style.Accent, Style.Text)
    elseif status ~= "" then
        Draw.Text(x + ((width - 3 - statusWidth) * 0.5), centerY - (statusHeight * 0.5), Draw.WithAlpha(Style.Accent, pulse), status, sizes.Text)
    end
    cursor = cursor + sizes.Line + (sizes.Gap * 1.5)

    Draw.TextWrapped(x + padding, cursor, inner, Style.TextDisabled, hints, sizes.Text)
end

function BindPopup.Draw()
    s_Alpha = Animation.Animate(s_Alpha, s_Definition and 1 or 0, STYLE.FadeSpeed, State.Time.Delta)
    if s_Alpha < 0.01 or not s_Shown then return end

    local screenWidth, screenHeight = GetDisplayResolution()
    local sizes = Sizes()
    local name = Hotkeys.Name(s_Shown)
    local hints = L("bindpopup.hints")
    local width = math.min(Scale.S(STYLE.Width), screenWidth)
    local height = Measure(sizes, width, name, hints)
    local x = (screenWidth - width) * 0.5
    local y = (screenHeight - height) * 0.5

    local previous = Draw.GetAlpha()
    local ok, err = true, nil
    Draw.SetAlpha(s_Alpha)
    if Draw.BeginWindow("##EasyTrainerBindPopup", x, y, width, height) then
        ok, err = pcall(DrawBox, x, y, width, height, sizes, name, hints)
    end
    Draw.EndWindow()
    Draw.SetAlpha(previous)
    if not ok then error(err, 0) end
end

return BindPopup
