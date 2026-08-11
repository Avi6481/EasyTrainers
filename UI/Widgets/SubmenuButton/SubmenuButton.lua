local SubmenuButton = {}

local Button = require("UI/Widgets/Button/Button")
local Navigation = require("UI/Navigation/Navigation")
local Submenu = require("UI/Navigation/Submenu")

function SubmenuButton.Create(label, submenu, tip)
    return { Kind = "submenu", Label = label, Submenu = submenu, Tip = tip or "" }
end

function SubmenuButton.Draw(label, submenu, tip, id)
    local activated, data = Button.Draw(label, tip, ">", id)
    if activated then Submenu.Open(submenu, Navigation) end
    return activated, data
end

return SubmenuButton

