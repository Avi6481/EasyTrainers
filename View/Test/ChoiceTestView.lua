local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")

local ChoiceTestView = {}

local LONG_COUNT = 24

local SIMPLE = { "First", "Second", "Third" }

local DETAILED = {
    { Label = "Small", Detail = "1x", Tip = "The smallest size." },
    { Label = "Medium", Detail = "2x", Tip = "The middle size." },
    { Label = "Large", Detail = "4x", Tip = "The largest size." }
}

local RADIO = { "Low", "Medium", "High", "Ultra" }

local LONG = {}
for index = 1, LONG_COUNT do LONG[index] = "Option " .. index end

local s_State = {
    Simple = 1,
    Detailed = 2,
    Long = 1,
    Preview = 1,
    Previewing = nil,
    Radio = 2,
    Level = 2,
    Locked = 3
}

local s_Simple = Ref.Field(s_State, "Simple")
local s_Detailed = Ref.Field(s_State, "Detailed")
local s_Long = Ref.Field(s_State, "Long")
local s_Preview = Ref.Field(s_State, "Preview")
local s_Radio = Ref.Field(s_State, "Radio")
local s_Level = Ref.Field(s_State, "Level")
local s_Locked = Ref.Field(s_State, "Locked")

local function Preview(index)
    s_State.Previewing = index
end

function ChoiceTestView.Draw()
    Widgets.Dropdown("Simple Dropdown", s_Simple, SIMPLE)
    Widgets.Tip("Three plain text choices.")
    Widgets.Dropdown("Detailed Dropdown", s_Detailed, DETAILED)
    Widgets.Tip("Choices with details and their own tips.")
    Widgets.Dropdown("Long Dropdown", s_Long, LONG)
    Widgets.Tip("24 choices to test scrolling in the sheet.")
    Widgets.Dropdown("Preview Dropdown", s_Preview, SIMPLE, Preview)
    Widgets.Tip("Reports which choice is highlighted before you pick it.")
    Widgets.ValueRow("Previewing", s_State.Previewing and SIMPLE[s_State.Previewing] or "None")
    Widgets.Tip("Shows what the preview dropdown is hovering.")

    Widgets.Break("Radio List")
    Widgets.RadioList(s_Radio, RADIO)

    Widgets.Break("Level Pips")
    Widgets.LevelPips("Level", s_Level, 5)
    Widgets.Tip("Press or use left and right to change the level.")
    Widgets.LevelPips("Locked Level", s_Locked, 5, true)
    Widgets.Tip("Locked, so it can't change.")
end

ChoiceTestView.Menu = Submenu.Create("Choices", ChoiceTestView.Draw)

return ChoiceTestView
