local Animation = require("Core/Animation")
local Draw = require("Core/Draw")
local Style = require("Style/Style")
local Themes = require("Style/Themes")
local HighlightStyle = require("Widgets/Core/HighlightStyle")
local ToggleStyle = require("Widgets/Toggle/ToggleStyle")
local SliderStyle = require("Widgets/Slider/SliderStyle")
local MeterStyle = require("Widgets/Meter/MeterStyle")
local SheetStyle = require("Panels/Sheet/SheetStyle")

local Theme = {}

Theme.Keys = { "Accent", "Background", "BackgroundLight", "Text", "TextSoft", "TextDisabled", "Border", "Overlay" }

Theme.Settings = {
    Name = Themes[1].Id,
    Opacity = 100,
    Custom = {}
}

local TRANSITION_TIME = 0.25

local SEE_THROUGH = {
    Background = true,
    BackgroundLight = true
}

local OVERLAYS = {
    { Target = HighlightStyle, Key = "Fill", Alpha = 26 },
    { Target = HighlightStyle, Key = "Border", Alpha = 40 },
    { Target = ToggleStyle, Key = "TrackOff", Alpha = 22 },
    { Target = ToggleStyle, Key = "TrackBorderOff", Alpha = 45 },
    { Target = ToggleStyle, Key = "LightRingOff", Alpha = 60 },
    { Target = ToggleStyle, Key = "LightCoreOff", Alpha = 12 },
    { Target = ToggleStyle, Key = "OrbitDotOff", Alpha = 80 },
    { Target = SliderStyle, Key = "RingOff", Alpha = 30 },
    { Target = SliderStyle, Key = "TrackOff", Alpha = 28 },
    { Target = SheetStyle, Key = "DotOff", Alpha = 60 },
    { Target = MeterStyle, Key = "Empty", Alpha = 26 },
    { Target = MeterStyle.Pips, Key = "Empty", Alpha = 70 }
}

local s_From = {}
local s_To = {}
local s_Progress = 1
local s_Preview = nil

local function ToHex(color)
    return string.format("%02X%02X%02X%02X", Draw.Channels(color))
end

local function FromHex(text)
    if type(text) ~= "string" or not text:match("^%x%x%x%x%x%x%x%x$") then return nil end
    return Draw.RGBA(tonumber(text:sub(1, 2), 16), tonumber(text:sub(3, 4), 16), tonumber(text:sub(5, 6), 16), tonumber(text:sub(7, 8), 16))
end

function Theme.List()
    return Themes
end

function Theme.Index()
    for index, theme in ipairs(Themes) do
        if theme.Id == Theme.Settings.Name then return index end
    end
    return 1
end

function Theme.Color(key)
    return FromHex(Theme.Settings.Custom[key]) or Themes[Theme.Index()].Colors[key]
end

function Theme.IsEdited()
    return next(Theme.Settings.Custom) ~= nil
end

local function Palette(index)
    local theme = Themes[index] or Themes[1]
    local edited = index == Theme.Index()
    local opacity = Animation.Clamp(Theme.Settings.Opacity / 100, 0, 1)

    local palette = {}
    for _, key in ipairs(Theme.Keys) do
        local color = edited and FromHex(Theme.Settings.Custom[key]) or theme.Colors[key]
        if SEE_THROUGH[key] then color = Draw.ScaleAlpha(color, opacity) end
        palette[key] = color
    end
    return palette
end

local function Write(palette)
    for _, key in ipairs(Theme.Keys) do Style[key] = palette[key] end

    local tint = palette.Overlay % 0x1000000
    for _, overlay in ipairs(OVERLAYS) do
        overlay.Target[overlay.Key] = tint + (overlay.Alpha * 0x1000000)
    end
end

local function Displayed()
    local palette = {}
    for _, key in ipairs(Theme.Keys) do palette[key] = Style[key] or s_To[key] end
    return palette
end

function Theme.Refresh(instant)
    s_To = Palette(s_Preview or Theme.Index())

    if instant then
        s_Progress = 1
        Write(s_To)
        return
    end

    s_From = Displayed()
    s_Progress = 0
end

function Theme.Update(delta)
    if s_Progress >= 1 then return end

    s_Progress = math.min(1, s_Progress + (delta / TRANSITION_TIME))
    local t = Animation.EaseOut(s_Progress)

    local palette = {}
    for _, key in ipairs(Theme.Keys) do palette[key] = Animation.LerpColor(s_From[key], s_To[key], t) end
    Write(palette)
end

function Theme.Select(index)
    if not Themes[index] then return end

    Theme.Settings.Name = Themes[index].Id
    Theme.Settings.Custom = {}
    Theme.Refresh(false)
end

function Theme.Preview(index)
    if index == s_Preview then return end

    s_Preview = index
    Theme.Refresh(false)
end

function Theme.SetColor(key, color)
    local base = Themes[Theme.Index()].Colors[key]
    Theme.Settings.Custom[key] = color ~= base and ToHex(color) or nil
    Theme.Refresh(true)
end

function Theme.ResetColors()
    Theme.Settings.Custom = {}
    Theme.Refresh(false)
end

return Theme
