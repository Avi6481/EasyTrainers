local ConfigManager = require("Config/OptionConfig")
local State = require("Controls/State")
local Toggle = ConfigManager.DefineToggle

State.menuOpen = true
State.mouseEnabled = false

local function RegisterMenuOptions()
    ConfigManager.RegisterAll({
        Toggle("toggle.trackMenuOpen", State.trackMenuOpen, true, {
            Label = "Remember menu state",
            Category = "controls",
            Keywords = { "menu", "open", "startup" },
        }),
        Toggle("toggle.trackMouseOn", State.trackMouseOn, true, {
            Label = "Remember cursor state",
            Category = "controls",
            Keywords = { "mouse", "cursor", "startup" },
        }),
    })
end


return RegisterMenuOptions
