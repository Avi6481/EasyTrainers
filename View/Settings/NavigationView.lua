local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local NavigationStyle = require("Navigation/NavigationStyle")
local HighlightStyle = require("Widgets/Core/HighlightStyle")
local Widgets = require("Widgets/Widgets")

local NavigationView = {}

local s_HoverSelects = Ref.Field(NavigationStyle, "MouseHoverSelects")
local s_CursorlessClicks = Ref.Field(NavigationStyle, "CursorlessClicks")
local s_RightClickBack = Ref.Field(NavigationStyle, "RightClickBack")
local s_WheelScrolls = Ref.Field(NavigationStyle, "MouseWheelNavigation")
local s_WheelRows = Ref.Field(NavigationStyle, "MouseWheelRows")
local s_RepeatDelay = Ref.Field(NavigationStyle, "RepeatDelay")
local s_RepeatRate = Ref.Field(NavigationStyle, "RepeatRate")
local s_AccelThreshold = Ref.Field(NavigationStyle, "AccelThreshold")
local s_AccelStep = Ref.Scaled(NavigationStyle, "AccelStep", 1000)
local s_FastestRate = Ref.Field(NavigationStyle, "RepeatRateFast")
local s_ScrollSmoothing = Ref.Field(NavigationStyle, "ScrollSmoothTime")
local s_HighlightSmoothing = Ref.Field(HighlightStyle, "SmoothTime")

local function Toggle(key, ref)
    Widgets.Toggle(L(key .. ".label"), ref)
    Widgets.Tip(L(key .. ".tip"))
end

local function Seconds(key, ref, min, max, step)
    Widgets.SliderFloat(L(key .. ".label"), ref, min, max, step, "%.2fs")
    Widgets.Tip(L(key .. ".tip"))
end

local function View()
    Seconds("navigation.repeatdelay", s_RepeatDelay, 0.15, 0.8, 0.05)
    Seconds("navigation.repeatrate", s_RepeatRate, 0.03, 0.2, 0.01)
    Seconds("navigation.accelthreshold", s_AccelThreshold, 0.1, 5, 0.05)
    Widgets.SliderInt(L("navigation.accelstep.label"), s_AccelStep, 0, 50, 1, "%d ms")
    Widgets.Tip(L("navigation.accelstep.tip"))
    Seconds("navigation.fastestrate", s_FastestRate, 0.01, 0.1, 0.01)
    Seconds("navigation.scrollsmoothing", s_ScrollSmoothing, 0.02, 0.3, 0.01)
    Seconds("navigation.highlightsmoothing", s_HighlightSmoothing, 0.02, 0.3, 0.01)

    Widgets.Break(L("navigation.mouse"))
    Toggle("navigation.hoverselects", s_HoverSelects)
    Toggle("navigation.cursorlessclicks", s_CursorlessClicks)
    Toggle("navigation.rightclickback", s_RightClickBack)
    Toggle("navigation.wheelscrolls", s_WheelScrolls)
    Widgets.SliderInt(L("navigation.wheelrows.label"), s_WheelRows, 1, 5, 1)
    Widgets.Tip(L("navigation.wheelrows.tip"))
end

NavigationView.Menu = Submenu.Create("navigation.title", View)

return NavigationView
