local MainTabs = require("UI/MainMenu/MainTabs")
local Options = require("UI/Option/Option")
local Submenu = require("UI/Navigation/Submenu")

local MainMenu = {
    Title = "EasyTrainer",
    Root = nil,
}

local function DrawTabs()
    for _, entry in ipairs(MainTabs.GetEnabled()) do
        Options.Submenu(entry.Title, entry.Submenu, entry.Tip, entry.Action, entry.Id)
    end
end

function MainMenu.Initialize(title)
    MainTabs.Initialize()
    MainMenu.Title = title or MainMenu.Title
    MainMenu.Root = Submenu.Create(MainMenu.Title, DrawTabs)
    return MainMenu.Root
end

function MainMenu.Register(id, title, submenu, tip, action)
    return MainTabs.Register({
        Id = id,
        Title = title,
        Submenu = submenu,
        Tip = tip or "",
        Action = action,
        Enabled = true,
    })
end

function MainMenu.GetRoot()
    return MainMenu.Root or MainMenu.Initialize()
end

return MainMenu

