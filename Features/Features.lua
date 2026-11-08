local Config = require("Core/Config")
local Session = require("Core/Session")
local Self = require("Features/Self/Self")
local Modifiers = require("Features/Modifiers/Modifiers")
local Development = require("Features/Development/Development")
local Teleports = require("Features/Teleports/Teleports")
local Vehicles = require("Features/Vehicles/Vehicles")
local Weapons = require("Features/Weapons/Weapons")
local Items = require("Features/Items/Items")
local World = require("Features/World/World")
local WorldEditor = require("Features/WorldEditor/WorldEditor")
local Hotkeys = require("Features/Hotkeys/Hotkeys")

local Features = {}

local GROUPS = {
    Self,
    Modifiers,
    Development,
    Teleports,
    Vehicles,
    Weapons,
    Items,
    World,
    WorldEditor
}

local s_Store = Config.New("Config/Options.json")

local function Each(stage, ...)
    for _, group in ipairs(GROUPS) do group[stage](...) end
end

function Features.Initialize()
    s_Store:Load()
    Each("Bind", s_Store)
    Each("Initialize")

    Session.Initialize()
    Session.Listen(function()
        Hotkeys.Reset()
        Each("Reset")
    end)
end

function Features.Update()
    s_Store:Update()
    Session.Update()
    if not Session.IsLoaded() then return end

    local player = Game.GetPlayer()
    if not player then return end

    Hotkeys.Update()
    Each("Update", player)
end

function Features.Shutdown()
    s_Store:Flush()

    local player = Session.IsLoaded() and Game.GetPlayer() or nil
    Each("Shutdown", player)
end

return Features
