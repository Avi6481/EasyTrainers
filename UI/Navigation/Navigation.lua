local State = require("UI/Navigation/State")
local Input = require("UI/Navigation/Input")
local Context = require("UI/Core/Context")

local Navigation = {}

Navigation.State = State
Navigation.Input = Input
Navigation.NonSelectable = {}
Navigation.NonSelectableNext = {}

function Navigation.Initialize()
    State.Initialize()
    Input.Clear()
    Navigation.NonSelectable = {}
    Navigation.NonSelectableNext = {}
end

function Navigation.Begin()
    State.Index = 0
    State.Total = 0
    Navigation.NonSelectableNext = {}
end

function Navigation.Next()
    State.Index = State.Index + 1
    State.Total = State.Total + 1
    return State.Index
end

function Navigation.RegisterNonSelectable(index)
    Navigation.NonSelectableNext[index] = true
end

function Navigation.IsCurrent(index)
    return State.Current == index
end

local function move(direction)
    if State.Total <= 0 then return end

    local attempts = 0
    repeat
        State.Current = State.Current + direction
        if State.Current < 1 then State.Current = State.Total end
        if State.Current > State.Total then State.Current = 1 end
        attempts = attempts + 1
    until not Navigation.NonSelectable[State.Current] or attempts >= State.Total
end

function Navigation.MoveUp()
    move(-1)
end

function Navigation.MoveDown()
    move(1)
end

function Navigation.SyncScroll(layout)
    local pageSize = math.max(1, State.VisibleItems)
    State.FirstVisible = math.max(0, State.Current - pageSize)
    State.TargetScrollOffset = State.FirstVisible * (layout.OptionHeight + layout.Spacing)
    State.ScrollOffset = State.TargetScrollOffset
end

function Navigation.Update(layout, deltaTime)
    Navigation.NonSelectable = Navigation.NonSelectableNext

    if State.ModeCurrent == State.Mode.Menu and not State.BlockInput then
        if Input.UpPressed then Navigation.MoveUp() end
        if Input.DownPressed then Navigation.MoveDown() end
    end

    if State.Total > 0 and Navigation.NonSelectable[State.Current] then
        if Input.UpPressed then Navigation.MoveUp() else Navigation.MoveDown() end
    end

    if State.Total <= 0 then
        State.Current = 1
        State.FirstVisible = 0
        State.ScrollOffset = 0
        State.TargetScrollOffset = 0
        return
    end

    State.Current = math.max(1, math.min(State.Current, State.Total))

    local contentHeight = layout.Height - layout.HeaderHeight - Context.SubmenuBarHeight
        - layout.FooterHeight - (layout.Padding * 2)
    State.VisibleItems = math.max(1, math.floor(contentHeight / (layout.OptionHeight + layout.Spacing)))

    local pageSize = State.VisibleItems
    if State.Current - 1 < State.FirstVisible then State.FirstVisible = State.Current - 1 end
    if State.Current > State.FirstVisible + pageSize then State.FirstVisible = State.Current - pageSize end

    local maxFirst = math.max(0, State.Total - pageSize)
    State.FirstVisible = math.max(0, math.min(State.FirstVisible, maxFirst))
    State.TargetScrollOffset = State.FirstVisible * (layout.OptionHeight + layout.Spacing)

    local amount = 1 - math.exp(-13 * (deltaTime or 0))
    State.ScrollOffset = State.ScrollOffset + (State.TargetScrollOffset - State.ScrollOffset) * amount
    if math.abs(State.TargetScrollOffset - State.ScrollOffset) < 0.25 then
        State.ScrollOffset = State.TargetScrollOffset
    end
end

return Navigation

