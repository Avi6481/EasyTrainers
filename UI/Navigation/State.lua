local State = {}

State.Mode = {
    Menu = 1,
    Dropdown = 2,
    Input = 3,
    Color = 4,
    ToggleDropdown = 5,
}

State.Index = 0
State.Current = 1
State.Total = 0
State.VisibleItems = 10
State.FirstVisible = 0
State.ScrollOffset = 0
State.TargetScrollOffset = 0
State.ScrollVelocity = 0
State.BlockInput = false
State.BlockMouseInput = false
State.MouseEnabled = false
State.ModeCurrent = State.Mode.Menu

function State.Initialize()
    State.Index = 0
    State.Current = 1
    State.Total = 0
    State.VisibleItems = 10
    State.FirstVisible = 0
    State.ScrollOffset = 0
    State.TargetScrollOffset = 0
    State.ScrollVelocity = 0
    State.BlockInput = false
    State.BlockMouseInput = false
    State.MouseEnabled = false
    State.ModeCurrent = State.Mode.Menu
end

function State.EnterMode(mode)
    State.ModeCurrent = mode
    State.BlockInput = mode ~= State.Mode.Menu
end

function State.LeaveMode()
    State.ModeCurrent = State.Mode.Menu
    State.BlockInput = false
    State.BlockMouseInput = false
end

return State
