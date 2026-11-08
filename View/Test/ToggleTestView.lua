local Logger = require("Core/Logger")
local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")

local ToggleTestView = {}

local BULK_COUNT = 10

local s_State = {
    Off = false,
    On = true,
    Long = false,
    Logged = false,
    Bulk = {}
}

local s_Off = Ref.Field(s_State, "Off")
local s_On = Ref.Field(s_State, "On")
local s_Long = Ref.Field(s_State, "Long")
local s_Logged = Ref.Field(s_State, "Logged")
local s_Bulk = {}

for index = 1, BULK_COUNT do
    s_State.Bulk[index] = index % 3 == 0
    s_Bulk[index] = Ref.Field(s_State.Bulk, index)
end

function ToggleTestView.Draw()
    Widgets.Toggle("Starts Off", s_Off)
    Widgets.Tip("A toggle that starts off.")
    Widgets.Toggle("Starts On", s_On)
    Widgets.Tip("A toggle that starts on.")
    Widgets.Toggle("A Much Longer Toggle Label To Test How It Fits", s_Long)
    Widgets.Tip("Checks how long labels sit next to the control.")
    if Widgets.Toggle("Logs When Flipped", s_Logged) then
        Logger.Log("UI Test: toggle flipped " .. (s_State.Logged and "on" or "off"))
    end
    Widgets.Tip("Prints to the console each time it flips.")

    Widgets.Break("Bulk")
    for index = 1, BULK_COUNT do
        Widgets.Toggle("Bulk Toggle " .. index, s_Bulk[index])
    end
end

ToggleTestView.Menu = Submenu.Create("Toggles", ToggleTestView.Draw)

return ToggleTestView
