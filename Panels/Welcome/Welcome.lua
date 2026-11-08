local Animation = require("Core/Animation")
local Draw = require("Core/Draw")
local Session = require("Core/Session")
local State = require("Core/State")
local Style = require("Style/Style")
local Layout = require("Style/Layout")
local Scale = require("Style/Scale")
local KeyBind = require("Widgets/KeyBind/KeyBind")
local Notification = require("Panels/Notification/Notification")

local Welcome = {
    Seen = false
}

local STYLE = {
    Width = 440,
    Padding = 22,
    RowGap = 8,
    TitleScale = 1.3,
    TextScale = 0.9,
    AccentWidth = 3,
    FadeSpeed = 9,
    LoadedTime = 8,
    ShowTime = 20,
    NotifyDelay = 1.5
}

local ROWS = { "open", "move", "select", "back", "adjust", "cursor" }
local DEFAULT_OPEN = "F4 | RB + D-Pad Right"

local s_Notified = false
local s_InGameAt = nil
local s_Visible = false
local s_ShownAt = 0
local s_Alpha = 0
local s_Content = nil

local function OpenKeys()
    local binding = State.Hotkeys.ToggleMenu
    if type(binding) ~= "table" then return DEFAULT_OPEN end

    local text = KeyBind.FormatBinding(binding)
    if text == "None" then return DEFAULT_OPEN end
    return text
end

local function Content()
    if s_Content then return s_Content end

    local open = OpenKeys()
    s_Content = { Title = L("welcome.title"), Intro = L("welcome.intro"), Footer = L("welcome.footer"), Rows = {} }
    for _, key in ipairs(ROWS) do
        local keys = key == "open" and open or L("welcome.rows." .. key .. ".keys")
        table.insert(s_Content.Rows, { Label = L("welcome.rows." .. key .. ".label"), Keys = keys })
    end
    return s_Content
end


local function Measure(content, width, titleSize, textSize)
    local padding = Scale.S(STYLE.Padding)
    local inner = width - (padding * 2)
    local _, titleHeight = Draw.TextSize(content.Title, titleSize)
    local _, rowHeight = Draw.TextSize("Ag", textSize)
    local height = padding + titleHeight + Scale.S(10)
        + Draw.WrapHeight(content.Intro, inner, textSize) + Scale.S(14)
        + (#content.Rows * (rowHeight + Scale.S(STYLE.RowGap)))
        + Scale.S(8) + Draw.WrapHeight(content.Footer, inner, textSize) + padding
    return height, titleHeight, rowHeight
end

local function DrawBox(content, x, y, width, height, titleSize, textSize, titleHeight, rowHeight)
    local padding = Scale.S(STYLE.Padding)
    local inner = width - (padding * 2)
    local rounding = Scale.S(Layout.Rounding)

    Draw.RectFilled(x + 3, y + 3, width - 3, height - 3, Style.Shadow, rounding)
    Draw.RectFilled(x, y, width - 3, height - 3, Style.BackgroundLight, rounding)
    Draw.LeftAccent(x, y, height - 3, Style.Accent, rounding, Scale.S(STYLE.AccentWidth))
    Draw.Rect(x, y, width - 3, height - 3, Style.Border, rounding, nil, 1)

    local cursor = y + padding
    Draw.Text(x + padding, cursor, Style.Text, content.Title, titleSize)
    cursor = cursor + titleHeight + Scale.S(10)

    Draw.TextWrapped(x + padding, cursor, inner, Style.TextSoft, content.Intro, textSize)
    cursor = cursor + Draw.WrapHeight(content.Intro, inner, textSize) + Scale.S(14)

    for _, row in ipairs(content.Rows) do
        local keysWidth = Draw.TextSize(row.Keys, textSize)
        Draw.Text(x + padding, cursor, Style.TextSoft, row.Label, textSize)
        Draw.Text(x + width - padding - keysWidth, cursor, Style.Accent, row.Keys, textSize)
        cursor = cursor + rowHeight + Scale.S(STYLE.RowGap)
    end

    cursor = cursor + Scale.S(8)
    Draw.TextWrapped(x + padding, cursor, inner, Style.TextDisabled, content.Footer, textSize)
end

local function Show()
    local content = Content()
    local screenWidth, screenHeight = GetDisplayResolution()
    local width = Scale.S(STYLE.Width)
    local titleSize = Scale.FontSize() * STYLE.TitleScale
    local textSize = Scale.FontSize() * STYLE.TextScale
    local height, titleHeight, rowHeight = Measure(content, width, titleSize, textSize)
    local menu = State.Menu
    local center = screenWidth * 0.5
    if menu.X + (menu.Width * 0.5) < center then
        center = (menu.X + menu.Width + screenWidth) * 0.5
    else
        center = menu.X * 0.5
    end
    local x = math.max(0, math.min(screenWidth - width, center - (width * 0.5)))
    local y = (screenHeight - height) * 0.5

    local ok, err = true, nil
    Draw.SetAlpha(s_Alpha)
    if Draw.BeginWindow("##EasyTrainerWelcome", x, y, width, height) then
        ok, err = pcall(DrawBox, content, x, y, width, height, titleSize, textSize, titleHeight, rowHeight)
    end
    Draw.EndWindow()
    Draw.SetAlpha(1)
    if not ok then error(err, 0) end
end

local function Track()
    if not Session.InGame() then
        s_Visible = false
        s_InGameAt = nil
        return
    end

    local now = os.clock()
    s_InGameAt = s_InGameAt or now
    if not s_Notified and now - s_InGameAt >= STYLE.NotifyDelay then
        s_Notified = true
        Notification.Push(tip("notify.loaded", { key = OpenKeys() }), "success", STYLE.LoadedTime)
    end

    if not Welcome.Seen and State.Menu.Open then
        Welcome.Seen = true
        s_Visible = true
        s_ShownAt = now
    end
    if s_Visible and (not State.Menu.Open or now - s_ShownAt > STYLE.ShowTime) then s_Visible = false end
end

function Welcome.Draw()
    Track()

    s_Alpha = Animation.Animate(s_Alpha, s_Visible and 1 or 0, STYLE.FadeSpeed, State.Time.Delta)
    if s_Alpha < 0.01 then return end
    Show()
end

return Welcome
