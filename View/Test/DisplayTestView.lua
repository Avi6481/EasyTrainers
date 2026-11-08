local Submenu = require("Navigation/Submenu")
local Break = require("Widgets/Break/Break")
local Widgets = require("Widgets/Widgets")

local DisplayTestView = {}

local PULSE_SPEED = 2

local s_State = {
    Clicks = 0
}

local function Pulse()
    return 50 + (50 * math.sin(os.clock() * PULSE_SPEED))
end

function DisplayTestView.Draw()
    Widgets.ValueRow("Value Row", "Plain value")
    Widgets.Tip("Shows a value with no action.")
    Widgets.ValueRow("Long Value", "This value is far too long to fit and should trail off")
    Widgets.Tip("Long values get cut to fit.")
    if Widgets.ValueRow("Clickable Value", tostring(s_State.Clicks), true) then s_State.Clicks = s_State.Clicks + 1 end
    Widgets.Tip("Counts how many times it's pressed.")

    Widgets.Break("Meters")
    Widgets.Meter("Quarter", 25, 0, 100, "%.0f%%")
    Widgets.Tip("A meter at 25%.")
    Widgets.Meter("Full", 100, 0, 100, "%.0f%%")
    Widgets.Tip("A meter at 100%.")
    Widgets.Meter("Pulsing", Pulse(), 0, 100, "%.0f%%")
    Widgets.Tip("Moves every frame to test animation.")

    Widgets.Break("Centered Break", Break.Align.Center)
    Widgets.ValueRow("Under Centered", "Row")
    Widgets.Break("Right Break", Break.Align.Right)
    Widgets.ValueRow("Under Right", "Row")
    Widgets.Break()
    Widgets.ValueRow("Under Plain Line", "Row")
end

DisplayTestView.Menu = Submenu.Create("Display", DisplayTestView.Draw)

return DisplayTestView
