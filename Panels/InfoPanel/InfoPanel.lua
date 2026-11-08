local Animation = require("Core/Animation")
local Draw = require("Core/Draw")
local State = require("Core/State")
local Style = require("Style/Style")
local Layout = require("Style/Layout")
local Scale = require("Style/Scale")
local RichText = require("Utils/RichText")
local MapView = require("Panels/InfoPanel/MapView")
local ImageView = require("Panels/InfoPanel/ImageView")

local InfoPanel = {}

local s_Pending = nil
local s_Shown = nil
local s_Built = nil
local s_BuiltFor = nil
local s_BuiltWidth = 0
local s_BuiltSize = 0
local s_Alpha = 0
local s_TextAlpha = 0
local s_Height = 0
local s_HeightVelocity = 0
local s_Slide = 0
local s_Tones = {}

function InfoPanel.InitializeStyle()
    InfoPanel.Style = {
        Enabled = true,
        Width = 340,
        Gap = 10,
        ScreenMargin = 16,
        PaddingX = 16,
        PaddingY = 14,
        BlockGap = 6,
        SectionGap = 14,
        ItemGap = 8,
        Rounding = Layout.Rounding,
        AccentWidth = 3,
        EyebrowScale = 0.75,
        TitleScale = 1.15,
        HeadingScale = 0.8,
        TextScale = 0.9,
        IconScale = 0.85,
        ImageMaxRatio = 0.6,
        SwatchHeight = 46,
        SmoothTime = 0.08,
        FadeSpeed = 14,
        SlideDistance = 24,
        SlideSpeed = 18
    }
end

InfoPanel.InitializeStyle()

function InfoPanel.Set(doc)
    s_Pending = doc
end

local function AddText(ops, x, y, text, tone, size)
    if text == "" then return end
    table.insert(ops, { X = x, Y = y, Text = text, Tone = tone, Size = size })
end

local function AddRich(ops, x, y, width, text, tone, size)
    local lines, lineHeight = RichText.Layout(RichText.Parse(text), width, size)
    local strong = tone == "Dim" and "Dim" or "Strong"

    for index, line in ipairs(lines) do
        local lineY = y + ((index - 1) * lineHeight)
        for _, part in ipairs(line) do
            AddText(ops, x + part.X, lineY, part.Text, part.Strong and strong or tone, size)
        end
    end
    return #lines * lineHeight
end

local BUILDERS = {}

function BUILDERS.Eyebrow(ops, block, x, y, width, fontSize)
    local size = fontSize * InfoPanel.Style.EyebrowScale
    local text = Draw.FitText(tostring(block.Text):upper(), width, size)
    local _, height = Draw.TextSize(text, size)
    AddText(ops, x, y, text, "Strong", size)
    return height
end

function BUILDERS.Title(ops, block, x, y, width, fontSize)
    return AddRich(ops, x, y, width, block.Text, "Text", fontSize * InfoPanel.Style.TitleScale)
end

function BUILDERS.Separator(ops, block, x, y, width)
    table.insert(ops, { Line = true, X = x, Y = y, Width = width })
    return 1
end

function BUILDERS.Heading(ops, block, x, y, width, fontSize)
    local size = fontSize * InfoPanel.Style.HeadingScale
    local text = Draw.FitText(tostring(block.Text):upper(), width, size)
    local _, height = Draw.TextSize(text, size)
    AddText(ops, x, y, text, block.Tone or "Soft", size)
    return height
end

function BUILDERS.Text(ops, block, x, y, width, fontSize)
    return AddRich(ops, x, y, width, block.Text, block.Tone or "Text", fontSize * InfoPanel.Style.TextScale)
end

function BUILDERS.Row(ops, block, x, y, width, fontSize)
    local size = fontSize * InfoPanel.Style.TextScale
    local label = tostring(block.Label or "")
    local value = tostring(block.Value or "")
    local labelWidth, height = Draw.TextSize(label, size)
    local valueWidth = Draw.TextSize(value, size)
    local tone = block.Tone or "Text"

    AddText(ops, x, y, label, "Dim", size)
    if labelWidth + Scale.S(InfoPanel.Style.ItemGap) + valueWidth <= width then
        AddText(ops, x + width - valueWidth, y, value, tone, size)
        return height
    end
    return height + AddRich(ops, x, y + height, width, value, tone, size)
end

function BUILDERS.Item(ops, block, x, y, width, fontSize)
    local style = InfoPanel.Style
    local size = fontSize * style.TextScale
    local tone = block.Tone or "Text"
    local indent = 0

    if block.Icon and block.Icon ~= "" then
        local iconSize = size * style.IconScale
        local iconWidth, iconHeight = Draw.TextSize(block.Icon, iconSize)
        local _, lineHeight = Draw.TextSize("Ag", size)
        AddText(ops, x, y + ((lineHeight - iconHeight) * 0.5), block.Icon, block.IconTone or tone, iconSize)
        indent = iconWidth + Scale.S(style.ItemGap)
    end
    return AddRich(ops, x + indent, y, width - indent, block.Text, tone, size)
end

function BUILDERS.Entry(ops, block, x, y, width, fontSize)
    local style = InfoPanel.Style
    local size = fontSize * style.TextScale
    local labelWidth = Draw.TextSize(block.LabelSample or block.Label, size)
    local indent = labelWidth + Scale.S(style.ItemGap)

    AddText(ops, x, y, block.Label, block.LabelTone or "Strong", size)
    return AddRich(ops, x + indent, y, width - indent, block.Text, block.Tone or "Text", size)
end

function BUILDERS.Swatch(ops, block, x, y, width, fontSize)
    local style = InfoPanel.Style
    local height = Scale.S(style.SwatchHeight)
    local color = block.Color
    table.insert(ops, {
        Swatch = Draw.RGBA(math.floor((color.R * 255) + 0.5), math.floor((color.G * 255) + 0.5), math.floor((color.B * 255) + 0.5), 255),
        X = x,
        Y = y,
        Width = width,
        Height = height
    })
    local gap = Scale.S(style.BlockGap)
    return height + gap + BUILDERS.Row(ops, { Label = block.Label, Value = block.Value }, x, y + height + gap, width, fontSize)
end

function BUILDERS.Image(ops, block, x, y, width)
    local image = block.Image
    local height = math.min(width * (image.Height / image.Width), width * InfoPanel.Style.ImageMaxRatio)
    local drawWidth = height * (image.Width / image.Height)
    table.insert(ops, { Image = image, X = x + ((width - drawWidth) * 0.5), Y = y, Width = drawWidth, Height = height })
    return height
end

function BUILDERS.Map(ops, block, x, y, width)
    if not block.View then block.View = MapView.Fit(block.Focus, block.Points) end
    table.insert(ops, { Map = block, X = x, Y = y, Size = width })
    return width
end

local function Build(doc, width, fontSize)
    local style = InfoPanel.Style
    local padX = Scale.S(style.PaddingX)
    local inner = width - (padX * 2)
    local ops = {}
    local y = Scale.S(style.PaddingY)

    for index, block in ipairs(doc) do
        local builder = BUILDERS[block.Kind]
        if builder then
            if index > 1 then y = y + Scale.S(block.Kind == "Heading" and style.SectionGap or style.BlockGap) end
            y = y + builder(ops, block, padX, y, inner, fontSize)
        end
    end
    return { Ops = ops, Height = y + Scale.S(style.PaddingY) }
end

local function Refresh(width, fontSize)
    if s_Built and s_BuiltFor == s_Shown and s_BuiltWidth == width and s_BuiltSize == fontSize then return end

    s_Built = Build(s_Shown, width, fontSize)
    s_BuiltFor = s_Shown
    s_BuiltWidth = width
    s_BuiltSize = fontSize
end

local function DrawOps(x, y, alpha)
    s_Tones.Text = Style.Text
    s_Tones.Soft = Style.TextSoft
    s_Tones.Dim = Style.TextDisabled
    s_Tones.Strong = Style.AccentHover
    s_Tones.Warn = Style.AccentActive

    local previous = Draw.GetAlpha()
    Draw.SetAlpha(previous * alpha)
    for _, op in ipairs(s_Built.Ops) do
        if op.Line then
            Draw.Line(x + op.X, y + op.Y, x + op.X + op.Width, y + op.Y, Style.Border, 1)
        elseif op.Map then
            MapView.Draw(x + op.X, y + op.Y, op.Size, op.Map)
        elseif op.Image then
            ImageView.Draw(x + op.X, y + op.Y, op.Width, op.Height, op.Image)
        elseif op.Swatch then
            local rounding = Scale.S(InfoPanel.Style.Rounding)
            Draw.RectFilled(x + op.X, y + op.Y, op.Width, op.Height, op.Swatch, rounding)
            Draw.Rect(x + op.X, y + op.Y, op.Width, op.Height, Style.Border, rounding, nil, 1)
        else
            Draw.Text(x + op.X, y + op.Y, s_Tones[op.Tone] or Style.Text, op.Text, op.Size)
        end
    end
    Draw.SetAlpha(previous)
end

local function DrawPanel(x, y, width, height)
    local style = InfoPanel.Style
    local rounding = Scale.S(style.Rounding)
    local previous = Draw.GetAlpha()
    Draw.SetAlpha(previous * s_Alpha)

    Draw.RectFilled(x + 2, y + 2, width - 2, height - 2, Style.Shadow, rounding)
    Draw.RectFilled(x, y, width - 2, height - 2, Style.Background, rounding)
    Draw.LeftAccent(x, y, height - 2, Style.Accent, rounding, Scale.S(style.AccentWidth))
    Draw.Rect(x, y, width - 2, height - 2, Style.Border, rounding, nil, 1)

    Draw.PushClip(x, y, width, height)
    DrawOps(x, y, s_TextAlpha)
    Draw.PopClip()
    Draw.SetAlpha(previous)
end

local function Position(width, height)
    local style = InfoPanel.Style
    local menu = State.Menu
    local gap = Scale.S(style.Gap)
    local margin = Scale.S(style.ScreenMargin)
    local screenWidth, screenHeight = GetDisplayResolution()

    local right = menu.X + menu.Width + gap
    local left = right + width > screenWidth - margin

    local x = left and (menu.X - gap - width) or right
    local slide = Scale.S(style.SlideDistance) * s_Slide
    x = x + (left and slide or -slide)

    local y = math.max(margin, math.min(menu.Y, screenHeight - margin - height))
    return x, y, math.min(height, screenHeight - y - margin)
end

function InfoPanel.Draw()
    local style = InfoPanel.Style
    local doc = s_Pending
    s_Pending = nil

    local visible = style.Enabled and doc ~= nil and State.Menu.Open
    if visible and doc ~= s_Shown then
        if s_Shown then s_TextAlpha = math.min(s_TextAlpha, 0.35) end
        s_Shown = doc
    end

    local delta = State.Time.Delta
    s_Alpha = Animation.Animate(s_Alpha, visible and 1 or 0, style.FadeSpeed, delta)
    s_TextAlpha = Animation.Animate(s_TextAlpha, visible and 1 or 0, style.FadeSpeed, delta)
    s_Slide = Animation.Animate(s_Slide, visible and 0 or 1, style.SlideSpeed, delta)

    if not s_Shown or (not visible and s_Alpha < 0.01) then
        s_Shown = nil
        s_Built = nil
        s_BuiltFor = nil
        s_Height = 0
        s_HeightVelocity = 0
        s_Slide = 1
        return
    end

    local width = Scale.S(style.Width)
    Refresh(width, Scale.FontSize())

    if s_Height < 1 then s_Height = s_Built.Height end
    s_Height, s_HeightVelocity = Animation.SmoothDamp(s_Height, s_Built.Height, s_HeightVelocity, style.SmoothTime, delta)

    local x, y, height = Position(width, s_Height)
    local ok, err = true, nil
    if Draw.BeginWindow("##EasyTrainerInfo", x, y, width, height) then
        ok, err = pcall(DrawPanel, x, y, width, height)
    end
    Draw.EndWindow()

    if not ok then error(err, 0) end
end

return InfoPanel
