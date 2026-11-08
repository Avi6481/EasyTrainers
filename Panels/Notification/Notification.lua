local Animation = require("Core/Animation")
local Draw = require("Core/Draw")
local State = require("Core/State")
local Style = require("Style/Style")
local Layout = require("Style/Layout")
local Scale = require("Style/Scale")

local Notification = {}

local s_Queue = {}
local s_NextId = 1
local s_Kinds = nil

function Notification.InitializeStyle()
    Notification.Style = {
        Enabled = true,
        Position = "Auto",
        Width = 320,
        Margin = 16,
        Gap = 8,
        PaddingX = 16,
        PaddingY = 10,
        LabelScale = 0.72,
        TextScale = 0.9,
        BarHeight = 2,
        AccentWidth = 3,
        Duration = 3,
        FadeOut = 0.22,
        FadeSpeed = 15,
        SlideSpeed = 17,
        SlideDistance = 28,
        TypeSpeed = 64
    }
end

Notification.InitializeStyle()

local function Kinds()
    if s_Kinds then return s_Kinds end
    s_Kinds = {
        info = { Label = L("notify.kinds.info") },
        success = { Label = L("notify.kinds.success"), Color = Draw.RGBA(100, 217, 139, 255) },
        warning = { Label = L("notify.kinds.warning"), Color = Draw.RGBA(255, 200, 87, 255) },
        error = { Label = L("notify.kinds.error"), Color = Draw.RGBA(255, 102, 122, 255) }
    }
    return s_Kinds
end

function Notification.Push(text, kind, duration)
    text = tostring(text or "")
    if text == "" then return end

    local writer = Animation.NewTypewriter()
    Animation.TypewriterSet(writer, text)
    table.insert(s_Queue, {
        Id = s_NextId,
        Text = text,
        Kind = Kinds()[kind] and kind or "info",
        Duration = math.max(0.5, duration or Notification.Style.Duration),
        Created = os.clock(),
        Alpha = 0,
        Slide = 1,
        Writer = writer
    })
    s_NextId = s_NextId + 1
end

local PLACES = {
    TopLeft = { "Left", true },
    TopCenter = { "Center", true },
    TopRight = { "Right", true },
    BottomLeft = { "Left", false },
    BottomCenter = { "Center", false },
    BottomRight = { "Right", false }
}

local function Corner()
    local place = PLACES[Notification.Style.Position]
    if place then return place[1], place[2] end

    local menu = State.Menu
    local screenWidth, screenHeight = GetDisplayResolution()
    local left = menu.X + (menu.Width * 0.5) < screenWidth * 0.5
    local top = menu.Y + (menu.Height * 0.5) < screenHeight * 0.5
    return left and "Right" or "Left", top
end

local function Left(side, screenWidth, width, margin, slide)
    if side == "Right" then return screenWidth - width - margin + slide end
    if side == "Center" then return (screenWidth - width) * 0.5 end
    return margin - slide
end

local function Measure(entry, width, labelSize, textSize)
    if entry.Width == width and entry.TextSize == textSize then return entry.Height end

    local style = Notification.Style
    local _, labelHeight = Draw.TextSize("Ag", labelSize)
    entry.Width = width
    entry.TextSize = textSize
    entry.Height = (Scale.S(style.PaddingY) * 2) + labelHeight + Scale.S(4)
        + Draw.WrapHeight(entry.Text, width - (Scale.S(style.PaddingX) * 2), textSize) + Scale.S(style.BarHeight) + Scale.S(4)
    return entry.Height
end

local function DrawEntry(entry, x, y, width, height, labelSize, textSize, progress)
    local style = Notification.Style
    local kind = Kinds()[entry.Kind]
    local accent = kind.Color or Style.Accent
    local rounding = Scale.S(Layout.Rounding)
    local padX, padY = Scale.S(style.PaddingX), Scale.S(style.PaddingY)

    Draw.SetAlpha(entry.Alpha)
    Draw.RectFilled(x + 2, y + 2, width - 2, height - 2, Style.Shadow, rounding)
    Draw.RectFilled(x, y, width - 2, height - 2, Style.BackgroundLight, rounding)
    Draw.LeftAccent(x, y, height - 2, accent, rounding, Scale.S(style.AccentWidth))
    Draw.Rect(x, y, width - 2, height - 2, Style.Border, rounding, nil, 1)

    local barHeight = Scale.S(style.BarHeight)
    Draw.RectFilled(x + 8, y + height - barHeight - 5, (width - 18) * progress, barHeight, accent, 1)

    local _, labelHeight = Draw.TextSize("Ag", labelSize)
    Draw.Text(x + padX, y + padY, accent, kind.Label, labelSize)
    Draw.TextWrapped(x + padX, y + padY + labelHeight + Scale.S(4), width - (padX * 2), Style.Text, entry.Writer.Displayed, textSize)
end

local function Show(entry, x, y, width, height, labelSize, textSize, progress)
    local ok, err = true, nil
    if Draw.BeginWindow("##EasyTrainerNotification" .. entry.Id, x, y, width, height) then
        ok, err = pcall(DrawEntry, entry, x, y, width, height, labelSize, textSize, progress)
    end
    Draw.EndWindow()
    Draw.SetAlpha(1)
    if not ok then error(err, 0) end
end

function Notification.Draw()
    if #s_Queue == 0 then return end

    local style = Notification.Style
    if not style.Enabled then
        s_Queue = {}
        return
    end

    local now = os.clock()
    local delta = State.Time.Delta
    local width = Scale.S(style.Width)
    local margin = Scale.S(style.Margin)
    local labelSize = Scale.FontSize() * style.LabelScale
    local textSize = Scale.FontSize() * style.TextScale
    local side, top = Corner()
    local screenWidth, screenHeight = GetDisplayResolution()
    local offset = 0

    for index = #s_Queue, 1, -1 do
        local entry = s_Queue[index]
        local remaining = entry.Duration - (now - entry.Created)
        local showing = remaining > style.FadeOut
        entry.Alpha = Animation.Animate(entry.Alpha, showing and 1 or 0, style.FadeSpeed, delta)
        entry.Slide = Animation.Animate(entry.Slide, showing and 0 or 1, style.SlideSpeed, delta)
        Animation.TypewriterUpdate(entry.Writer, delta, style.TypeSpeed)

        if remaining <= 0 and entry.Alpha < 0.02 then
            table.remove(s_Queue, index)
        else
            local height = Measure(entry, width, labelSize, textSize)
            local slide = Scale.S(style.SlideDistance) * entry.Slide
            local x = Left(side, screenWidth, width, margin, slide)
            local y = top and (margin + offset) or (screenHeight - height - margin - offset)
            Show(entry, x, y, width, height, labelSize, textSize, math.max(0, math.min(1, remaining / entry.Duration)))
            offset = offset + height + Scale.S(style.Gap)
        end
    end
end

function Notification.Clear()
    s_Queue = {}
end

return Notification
