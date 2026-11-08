local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local ToggleTestView = require("View/Test/ToggleTestView")
local SliderTestView = require("View/Test/SliderTestView")
local ChoiceTestView = require("View/Test/ChoiceTestView")
local TextTestView = require("View/Test/TextTestView")
local DisplayTestView = require("View/Test/DisplayTestView")
local ActionTestView = require("View/Test/ActionTestView")
local ColorTestView = require("View/Test/ColorTestView")

local AllTestView = {}

local SECTIONS = {
    { "Toggles", ToggleTestView },
    { "Sliders", SliderTestView },
    { "Choices", ChoiceTestView },
    { "Text & Binds", TextTestView },
    { "Display", DisplayTestView },
    { "Actions", ActionTestView },
    { "Colors", ColorTestView }
}

local function View()
    for index, section in ipairs(SECTIONS) do
        if index > 1 then Widgets.Break(section[1]) end
        section[2].Draw()
    end
end

AllTestView.Menu = Submenu.Create("Everything", View)

return AllTestView
