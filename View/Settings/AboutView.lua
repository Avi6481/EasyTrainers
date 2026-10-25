local Buttons = require("UI/Options/Buttons")
local Submenu = require("UI/Navigation/Submenu")

local function AboutView()
    Buttons.OptionExtended("EasyTrainer", "", "v2.3", "An accessible Cyberpunk 2077 trainer with keyboard, controller, and mouse support.")

    Buttons.Break("Credits")
    Buttons.OptionExtended("Created By", "", "Avi", "EasyTrainer creator and maintainer.")
    Buttons.OptionExtended("Inspired By", "", "SimpleMenu", "Inspired by Dank Rafft and capncoolio2.")
    Buttons.OptionExtended("Teleport Data", "", "LocationKingGRP", "Additional teleport location data.")

    Buttons.Break("Project")
    Buttons.OptionExtended("Source Repository", "", "Avi6481 / EasyTrainers", "github.com/Avi6481/EasyTrainers")
end

return Submenu.Create("About", AboutView)
