local Animation = require("Core/Animation")
local Draw = require("Core/Draw")
local Input = require("Core/Input")
local State = require("Core/State")
local Layout = require("Style/Layout")
local Scale = require("Style/Scale")
local NavigationStyle = require("Navigation/NavigationStyle")
local Footer = require("Panels/Footer/Footer")
local SubmenuBar = require("Panels/SubmenuBar/SubmenuBar")

local Navigation = {}

Navigation.State = {
    Current = 1,
    Total = 0,
    Index = 0,
    FirstVisible = 0,
    VisibleRows = 0,
    ScrollOffset = 0,
    OffsetX = 0,
    SelectPressed = false,
    BackPressed = false,
    EditPressed = false,
    Adjust = 0,
    Editing = false
}

local s_Up = { Held = false, Time = 0, Repeat = 0, Accelerate = true }
local s_Down = { Held = false, Time = 0, Repeat = 0, Accelerate = true }
local s_Left = { Held = false, Time = 0, Repeat = 0 }
local s_Right = { Held = false, Time = 0, Repeat = 0 }
local s_ScrollVelocity = 0

local s_Breaks = {}
local s_NextBreaks = {}
local s_Pinned = 0
local s_NextPinned = 0
local s_ScrollClip = false
local s_LastWheel = -10

local s_Content = { X = 0, Y = 0, Width = 0, Height = 0 }
local s_HoveredRow = 0
local s_Suppressed = false

local s_Sheet = nil

local function Sheet()
    if not s_Sheet then s_Sheet = require("Panels/Sheet/Sheet") end
    return s_Sheet
end

local function RepeatRate(holdTime)
    if holdTime > NavigationStyle.FastAfter then return NavigationStyle.RepeatRateFast end
    if holdTime > NavigationStyle.MediumAfter then return NavigationStyle.RepeatRateMedium end
    return NavigationStyle.RepeatRate
end

local function Interval(hold)
    if not hold.Accelerate then return RepeatRate(hold.Time) end

    local base = NavigationStyle.RepeatRate
    if hold.Time < NavigationStyle.AccelThreshold then
        hold.Interval = base
        return base
    end

    local floor = math.min(base, NavigationStyle.RepeatRateFast)
    hold.Interval = math.max(floor, (hold.Interval or base) - NavigationStyle.AccelStep)
    return hold.Interval
end

local function UpHeld()
    return Input.KeyDown(Input.VK.Up) or Input.KeyDown(Input.VK.Numpad8)
        or Input.ButtonDown(Input.Button.DpadUp)
end

local function DownHeld()
    return Input.KeyDown(Input.VK.Down) or Input.KeyDown(Input.VK.Numpad2)
        or Input.ButtonDown(Input.Button.DpadDown)
end

local function LeftHeld()
    return Input.KeyDown(Input.VK.Left) or Input.KeyDown(Input.VK.Numpad4)
        or Input.ButtonDown(Input.Button.DpadLeft)
end

local function RightHeld()
    return Input.KeyDown(Input.VK.Right) or Input.KeyDown(Input.VK.Numpad6)
        or Input.ButtonDown(Input.Button.DpadRight)
end

local function AdjustBoost(holdTime)
    if holdTime > NavigationStyle.FastAfter then return NavigationStyle.AdjustBoostFast end
    if holdTime > NavigationStyle.MediumAfter then return NavigationStyle.AdjustBoostMedium end
    return 1
end

local function AdjustLeft()
    Navigation.State.Adjust = Navigation.State.Adjust - AdjustBoost(s_Left.Time)
end

local function AdjustRight()
    Navigation.State.Adjust = Navigation.State.Adjust + AdjustBoost(s_Right.Time)
end

local function StepUp()
    if Sheet().SheetOpen() then
        Sheet().SheetMove(-1)
    else
        Navigation.MoveUp()
    end
end

local function StepDown()
    if Sheet().SheetOpen() then
        Sheet().SheetMove(1)
    else
        Navigation.MoveDown()
    end
end

local function SelectPressed()
    return Input.KeyPressed(Input.VK.Return) or Input.KeyPressed(Input.VK.Numpad5) or Input.ButtonPressed(Input.Button.A)
end

local function BackPressed()
    return Input.KeyPressed(Input.VK.Back) or Input.KeyPressed(Input.VK.Numpad0) or Input.ButtonPressed(Input.Button.B)
end

local function UpdateHold(hold, held, move)
    if not held then
        hold.Held, hold.Time, hold.Repeat, hold.Interval = false, 0, 0, nil
        return
    end

    if not hold.Held then
        hold.Held = true
        move()
        return
    end

    hold.Time = hold.Time + State.Time.Delta
    if hold.Time < NavigationStyle.RepeatDelay then return end

    hold.Repeat = hold.Repeat + State.Time.Delta
    if hold.Repeat < (hold.Interval or NavigationStyle.RepeatRate) then return end

    hold.Repeat = 0
    hold.Interval = Interval(hold)
    move()
end

local function KeepHeld(hold, held)
    hold.Held, hold.Time, hold.Repeat, hold.Interval = held, 0, 0, nil
end

local function UpdateWheel()
    if not NavigationStyle.MouseWheelNavigation then return end

    local wheel = Input.MouseWheel()
    if wheel == 0 then return end

    if NavigationStyle.ShiftWheelAdjust and Input.KeyDown(Input.VK.Shift) then
        Navigation.State.Adjust = Navigation.State.Adjust + (wheel > 0 and 1 or -1)
        return
    end

    local now = State.Time.Time
    if now - s_LastWheel < NavigationStyle.MouseWheelCooldown then return end
    s_LastWheel = now

    local rows = math.max(1, math.min(5, NavigationStyle.MouseWheelRows))
    for _ = 1, rows do
        if wheel > 0 then StepUp() else StepDown() end
    end
end

function Navigation.Initialize()
    local nav = Navigation.State
    nav.Current = 1
    nav.Total = 0
    nav.Index = 0
    nav.FirstVisible = 0
    nav.ScrollOffset = 0
    nav.OffsetX = 0
    nav.Editing = false
    KeepHeld(s_Up, false)
    KeepHeld(s_Down, false)
    KeepHeld(s_Left, false)
    KeepHeld(s_Right, false)
    s_ScrollVelocity = 0
end

function Navigation.Suppress()
    s_Suppressed = true
end

function Navigation.UpdateInput()
    local nav = Navigation.State
    nav.SelectPressed = false
    nav.BackPressed = false
    nav.EditPressed = false
    nav.Adjust = 0

    local suppressed = s_Suppressed
    s_Suppressed = false

    local blocked = suppressed or not State.Menu.Open or nav.Editing or (State.OverlayOpen and Input.IsAvailable())
    if blocked then
        KeepHeld(s_Up, UpHeld())
        KeepHeld(s_Down, DownHeld())
        KeepHeld(s_Left, LeftHeld())
        KeepHeld(s_Right, RightHeld())
        return
    end

    if Input.KeyPressed(NavigationStyle.CursorToggleKey) then State.SetCursor(not State.Menu.Cursor) end

    UpdateHold(s_Up, UpHeld(), StepUp)
    UpdateHold(s_Down, DownHeld(), StepDown)
    UpdateHold(s_Left, LeftHeld(), AdjustLeft)
    UpdateHold(s_Right, RightHeld(), AdjustRight)
    UpdateWheel()

    nav.EditPressed = Input.KeyPressed(NavigationStyle.EditKey)

    local scroll = Footer.FooterScroll()
    if scroll < 0 then
        StepUp()
    elseif scroll > 0 then
        StepDown()
    end

    if Sheet().SheetOpen() then
        nav.Adjust = 0
        nav.EditPressed = false
    end

    local leftClick = Input.MouseReleased(Input.Mouse.Left)
    local rightClick = Input.MouseReleased(Input.Mouse.Right)
    local cursorless = not State.Menu.Cursor and NavigationStyle.CursorlessClicks

    nav.SelectPressed = SelectPressed() or (cursorless and leftClick)
    nav.BackPressed = BackPressed() or (NavigationStyle.RightClickBack and rightClick)
end

local function UpdateContent()
    local menu = State.Menu
    local padding = Scale.S(Layout.Padding)
    local top = menu.Y + Scale.S(Layout.HeaderHeight) + SubmenuBar.Height() + padding
    local bottom = menu.Y + menu.Height - Scale.S(Layout.FooterHeight) - padding

    s_Content.X = menu.X + padding + Navigation.State.OffsetX
    s_Content.Y = top
    s_Content.Width = menu.Width - (padding * 2)
    s_Content.Height = math.max(0, bottom - top)
end

function Navigation.Content()
    return s_Content
end

function Navigation.HoveredRow()
    return s_HoveredRow
end

function Navigation.RowStep()
    return Scale.S(Layout.OptionHeight + Layout.Spacing)
end

local function PinnedCount()
    if Navigation.State.Index == 0 then return s_Pinned end
    return s_NextPinned
end

function Navigation.IsPinned(index)
    return index >= 1 and index <= PinnedCount()
end

function Navigation.PinnedHeight()
    return PinnedCount() * Navigation.RowStep()
end

function Navigation.ScrollTop()
    return Navigation.Content().Y + Navigation.PinnedHeight()
end

function Navigation.RowY(index)
    local offset = Navigation.IsPinned(index) and 0 or Navigation.State.ScrollOffset
    return Navigation.Content().Y + ((index - 1) * Navigation.RowStep()) - offset
end

local function MouseFree()
    local menu = State.Menu
    return menu.Open and menu.Cursor and not State.IsBusy() and not Sheet().SheetVisible()
end

local function UpdateHoveredRow()
    s_HoveredRow = 0
    if not MouseFree() then return end

    local content = s_Content
    if not Input.MouseIn(content.X, content.Y, content.Width, content.Height) then return end

    local _, mouseY = Input.MousePos()
    local step = Navigation.RowStep()
    local offset = mouseY - content.Y
    if offset >= s_Pinned * step then offset = offset + Navigation.State.ScrollOffset end

    local row = math.floor(offset / step)
    if offset - (row * step) >= Scale.S(Layout.OptionHeight) then return end
    s_HoveredRow = row + 1
end

function Navigation.Begin()
    Navigation.State.Index = 0
    s_NextBreaks = {}
    s_NextPinned = 0
    s_ScrollClip = false

    UpdateContent()
    UpdateHoveredRow()
end

local function EnterScrollRows()
    if s_ScrollClip or s_NextPinned == 0 then return end

    local content = Navigation.Content()
    local top = Navigation.ScrollTop()
    Draw.PushClip(content.X - Navigation.State.OffsetX, top, content.Width, math.max(0, content.Y + content.Height - top))
    s_ScrollClip = true
end

function Navigation.Next()
    EnterScrollRows()
    local nav = Navigation.State
    nav.Index = nav.Index + 1
    s_NextBreaks[nav.Index] = false
    return nav.Index
end

function Navigation.NextBreak()
    EnterScrollRows()
    local nav = Navigation.State
    nav.Index = nav.Index + 1
    s_NextBreaks[nav.Index] = true
    return nav.Index
end

function Navigation.NextPinned()
    local nav = Navigation.State
    if nav.Index ~= s_NextPinned then return Navigation.Next() end

    nav.Index = nav.Index + 1
    s_NextPinned = s_NextPinned + 1
    s_NextBreaks[nav.Index] = false
    return nav.Index
end

function Navigation.EndRows()
    if s_ScrollClip then Draw.PopClip() end
    s_ScrollClip = false
end

function Navigation.IsSelectable(index)
    return s_Breaks[index] ~= true
end

local function AnySelectable()
    for index = 1, Navigation.State.Total do
        if Navigation.IsSelectable(index) then return true end
    end
    return false
end

local function SettleOnSelectable()
    local nav = Navigation.State
    if not AnySelectable() or Navigation.IsSelectable(nav.Current) then return end

    for index = nav.Current + 1, nav.Total do
        if Navigation.IsSelectable(index) then
            nav.Current = index
            return
        end
    end

    for index = nav.Current - 1, 1, -1 do
        if Navigation.IsSelectable(index) then
            nav.Current = index
            return
        end
    end
end

local function UpdateFooterCount()
    local nav = Navigation.State
    local position, total = 0, 0

    for index = 1, nav.Total do
        if Navigation.IsSelectable(index) then
            total = total + 1
            if index <= nav.Current then position = total end
        end
    end

    Footer.SetFooterCount(total > 0 and position or 0, total)
end

function Navigation.End()
    local nav = Navigation.State
    nav.Total = nav.Index
    s_Breaks = s_NextBreaks
    s_Pinned = s_NextPinned

    if nav.Total <= 0 then
        nav.Current = 1
        nav.FirstVisible = 0
    else
        nav.Current = math.max(1, math.min(nav.Total, nav.Current))
        SettleOnSelectable()
    end

    local spacing = Scale.S(Layout.Spacing)
    nav.VisibleRows = math.max(1, math.floor((Navigation.Content().Height + spacing) / Navigation.RowStep()))

    local scrollRows = math.max(1, nav.VisibleRows - s_Pinned)
    local scrollTotal = nav.Total - s_Pinned
    local maxFirst = math.max(0, scrollTotal - scrollRows)
    local current = nav.Current - s_Pinned

    if current >= 1 then
        if current - 1 < nav.FirstVisible then nav.FirstVisible = current - 1 end
        if current > nav.FirstVisible + scrollRows then nav.FirstVisible = current - scrollRows end
    end

    nav.FirstVisible = math.max(0, math.min(maxFirst, nav.FirstVisible))

    local target = nav.FirstVisible * Navigation.RowStep()
    nav.ScrollOffset, s_ScrollVelocity = Animation.SmoothDamp(nav.ScrollOffset, target, s_ScrollVelocity, NavigationStyle.ScrollSmoothTime, State.Time.Delta)

    UpdateFooterCount()
end

local function Step(direction)
    local nav = Navigation.State
    if nav.Total <= 0 or not AnySelectable() then return end

    for _ = 1, nav.Total do
        nav.Current = nav.Current + direction
        if nav.Current < 1 then
            nav.Current = nav.Total
        elseif nav.Current > nav.Total then
            nav.Current = 1
        end

        if Navigation.IsSelectable(nav.Current) then return end
    end
end

function Navigation.MoveUp()
    Step(-1)
end

function Navigation.MoveDown()
    Step(1)
end

function Navigation.SavePosition()
    local nav = Navigation.State
    return { Current = nav.Current, FirstVisible = nav.FirstVisible, ScrollOffset = nav.ScrollOffset }
end

function Navigation.RestorePosition(position)
    local nav = Navigation.State
    nav.Current = position.Current
    nav.FirstVisible = position.FirstVisible
    nav.ScrollOffset = position.ScrollOffset
    s_ScrollVelocity = 0
    s_Breaks = {}
    s_Pinned = 0
end

function Navigation.ResetPosition()
    Navigation.RestorePosition({ Current = 1, FirstVisible = 0, ScrollOffset = 0 })
end

return Navigation
