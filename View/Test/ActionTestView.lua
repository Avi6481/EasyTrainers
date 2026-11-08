local Logger = require("Core/Logger")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")

local ActionTestView = {}

local LONG_HOLD = 2

local s_State = {
    Presses = 0,
    Last = "None"
}

local function Pressed(name)
    s_State.Presses = s_State.Presses + 1
    s_State.Last = name
end

function ActionTestView.Draw()
    if Widgets.Button("Button") then Pressed("Button") end
    Widgets.Tip("Counts presses in the results below.")
    if Widgets.Button("Second Button") then Pressed("Second Button") end
    Widgets.Tip("Another button for the same counter.")
    if Widgets.Button("Log To Console") then
        Pressed("Log To Console")
        Logger.Log("UI Test: hello from the test page")
    end
    Widgets.Tip("Prints a line to the CET console.")

    Widgets.Break("Hold Buttons")
    if Widgets.HoldButton("Quick Hold") then Pressed("Quick Hold") end
    Widgets.Tip("Uses the default hold time.")
    if Widgets.HoldButton("Long Hold", LONG_HOLD) then Pressed("Long Hold") end
    Widgets.Tip("Hold for 2 seconds.")

    Widgets.Break("Results")
    Widgets.ValueRow("Presses", tostring(s_State.Presses))
    Widgets.Tip("How many buttons fired.")
    Widgets.ValueRow("Last Action", s_State.Last)
    Widgets.Tip("The last button that fired.")
end

ActionTestView.Menu = Submenu.Create("Actions", ActionTestView.Draw)

return ActionTestView
