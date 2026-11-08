local Input = require("Core/Input")

local NavigationStyle = {}

function NavigationStyle.Initialize()
    NavigationStyle.RepeatDelay = 0.35
    NavigationStyle.RepeatRate = 0.09
    NavigationStyle.RepeatRateMedium = 0.05
    NavigationStyle.RepeatRateFast = 0.03
    NavigationStyle.MediumAfter = 1
    NavigationStyle.FastAfter = 2
    NavigationStyle.AccelThreshold = 1.25
    NavigationStyle.AccelStep = 0.01
    NavigationStyle.ScrollSmoothTime = 0.11
    NavigationStyle.MouseHoverSelects = true
    NavigationStyle.PageSlideTime = 0.09
    NavigationStyle.PageSlideDistance = 18
    NavigationStyle.CursorToggleKey = 0x58
    NavigationStyle.CursorlessClicks = false
    NavigationStyle.RightClickBack = false
    NavigationStyle.EditKey = 0x71
    NavigationStyle.BindKey = Input.VK.F3
    NavigationStyle.BindButton = Input.Button.Y
    NavigationStyle.ShiftWheelAdjust = true
    NavigationStyle.AdjustBoostMedium = 2
    NavigationStyle.AdjustBoostFast = 5
    NavigationStyle.MouseWheelNavigation = true
    NavigationStyle.MouseWheelRows = 1
    NavigationStyle.MouseWheelCooldown = 0.07
end

NavigationStyle.Initialize()

return NavigationStyle
