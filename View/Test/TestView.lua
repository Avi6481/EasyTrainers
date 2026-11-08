local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local AllTestView = require("View/Test/AllTestView")
local SelfLayoutTestView = require("View/Test/SelfLayoutTestView")
local ToggleTestView = require("View/Test/ToggleTestView")
local SliderTestView = require("View/Test/SliderTestView")
local ChoiceTestView = require("View/Test/ChoiceTestView")
local TextTestView = require("View/Test/TextTestView")
local SearchTestView = require("View/Test/SearchTestView")
local DisplayTestView = require("View/Test/DisplayTestView")
local ActionTestView = require("View/Test/ActionTestView")
local ColorTestView = require("View/Test/ColorTestView")

local TestView = {}

local PAGES = {
    { "Everything", "Every widget on one long page.", AllTestView },
    { "Self Layout", "The Self page's exact layout with no game features behind it.", SelfLayoutTestView },
    { "Toggles", "Toggles, long labels and a bulk list.", ToggleTestView },
    { "Sliders", "Whole, decimal and toggled sliders plus number actions.", SliderTestView },
    { "Choices", "Dropdowns, a radio list and level pips.", ChoiceTestView },
    { "Text & Binds", "Text boxes and key binds.", TextTestView },
    { "Search", "A search bar filtering a list.", SearchTestView },
    { "Display", "Value rows, meters and break styles.", DisplayTestView },
    { "Actions", "Buttons and hold buttons.", ActionTestView },
    { "Colors", "Color pickers.", ColorTestView }
}

local function View()
    for _, page in ipairs(PAGES) do
        Widgets.SubmenuButton(page[1], page[3].Menu)
        Widgets.Tip(page[2])
    end
end

TestView.Menu = Submenu.Create("UI Test", View)

return TestView
