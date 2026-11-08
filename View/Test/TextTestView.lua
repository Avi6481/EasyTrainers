local Input = require("Core/Input")
local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")

local TextTestView = {}

local s_State = {
    Empty = "",
    Filled = "Night City",
    Short = "",
    Unbound = { Keys = {}, Buttons = {} },
    Single = { Keys = { Input.VK.F1 }, Buttons = {} },
    Combo = { Keys = { Input.VK.LControl, 0x4B }, Buttons = { Input.Button.LeftShoulder, Input.Button.A } }
}

local s_Empty = Ref.Field(s_State, "Empty")
local s_Filled = Ref.Field(s_State, "Filled")
local s_Short = Ref.Field(s_State, "Short")

function TextTestView.Draw()
    Widgets.InputText("Empty Text", s_Empty, 32, "Type something")
    Widgets.Tip("Starts empty with a placeholder.")
    Widgets.InputText("Filled Text", s_Filled, 32)
    Widgets.Tip("Starts with text already in it.")
    Widgets.InputText("Short Text", s_Short, 8, "8 max")
    Widgets.Tip("Stops at 8 characters.")

    Widgets.Break("Key Binds")
    Widgets.KeyBind("Unbound", s_State.Unbound)
    Widgets.Tip("Starts with nothing bound.")
    Widgets.KeyBind("Single Key", s_State.Single)
    Widgets.Tip("Starts bound to F1. Not hooked to anything.")
    Widgets.KeyBind("Combo", s_State.Combo)
    Widgets.Tip("A keyboard combo plus a controller combo.")
end

TextTestView.Menu = Submenu.Create("Text & Binds", TextTestView.Draw)

return TextTestView
