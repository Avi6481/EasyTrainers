local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")

local ColorTestView = {}

local s_State = {
    Solid = { R = 0.95, G = 0.3, B = 0.35, A = 1 },
    Glass = { R = 0.2, G = 0.8, B = 0.9, A = 0.5 },
    White = { R = 1, G = 1, B = 1, A = 1 },
    Last = "None"
}

local function Changed(color)
    s_State.Last = Widgets.ColorToHex(color, true)
end

function ColorTestView.Draw()
    Widgets.ColorPicker("Solid Color", s_State.Solid, false, Changed)
    Widgets.Tip("Opens the color editor without transparency.")
    Widgets.ColorPicker("Color With Alpha", s_State.Glass, true, Changed)
    Widgets.Tip("Opens the color editor with a transparency slider.")
    Widgets.ColorPicker("White", s_State.White, false)
    Widgets.Tip("Has no change callback.")
    Widgets.ValueRow("Last Change", s_State.Last)
    Widgets.Tip("The last color picked in the editor.")
end

ColorTestView.Menu = Submenu.Create("Colors", ColorTestView.Draw)

return ColorTestView
