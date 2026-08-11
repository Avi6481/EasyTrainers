local Buttons = require("UI").Buttons

local function DrawAbout()
    Buttons.OptionExtended("EasyTrainer", "", "v2.0", "An accessible Cyberpunk 2077 trainer with keyboard, controller, and mouse support.")
    Buttons.Break("Credits", "")
    Buttons.OptionExtended("Created by", "", "Avi", "EasyTrainer creator and maintainer.")
    Buttons.OptionExtended("Inspired by", "", "SimpleMenu", "Inspired by Dank Rafft and capncoolio2.")
    Buttons.OptionExtended("Teleport data", "", "LocationKingGRP", "Additional teleport location data.")
    Buttons.Break("Project", "")
    Buttons.OptionExtended("Source repository", "", "Avi6481 / EasyTrainers","github.com/Avi6481/EasyTrainers")
end

return { title = "About", view = DrawAbout }
