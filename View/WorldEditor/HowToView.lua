local State = require("Core/State")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")

local HowToView = {}

local TOPICS = {
    { Key = "fly", Keyboard = true, Controller = true },
    { Key = "spawn", All = true },
    { Key = "select", Keyboard = true, Controller = true },
    { Key = "options", Keyboard = true, Controller = true },
    { Key = "carry", Keyboard = true, Controller = true },
    { Key = "ground", Controller = true },
    { Key = "rotate", Keyboard = true, Controller = true },
    { Key = "nudge", Keyboard = true, Controller = true },
    { Key = "attach", Keyboard = true, Controller = true },
    { Key = "detach", Keyboard = true, Controller = true },
    { Key = "scene", All = true },
    { Key = "copies", All = true },
    { Key = "mapentities", All = true },
    { Key = "copypaste", Keyboard = true, Controller = true },
    { Key = "save", All = true },
    { Key = "undo", Keyboard = true, Controller = true }
}

local function View()
    local controller = State.Device.Device == State.Devices.Controller
    for _, topic in ipairs(TOPICS) do
        local variant = nil
        if topic.All then
            variant = "all"
        elseif controller and topic.Controller then
            variant = "controller"
        elseif not controller and topic.Keyboard then
            variant = "keyboard"
        end

        if variant then
            local key = "worldeditor.howto." .. topic.Key
            Widgets.ValueRow(L(key .. ".label"), "")
            Widgets.Tip(L(key .. "." .. variant))
        end
    end
end

HowToView.Menu = Submenu.Create("worldeditor.howto.label", View)

return HowToView
