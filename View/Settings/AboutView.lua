local Dependencies = require("Core/Dependencies")
local Input = require("Core/Input")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local FooterStyle = require("Panels/Footer/FooterStyle")

local AboutView = {}

local AUTHOR = "Avi"
local LOCATIONS = "LocationKingGRP"
local SOURCE = "Avi6481 / EasyTrainers"

local function LoadedText(loaded)
    return loaded and L("status.loaded") or L("status.missing")
end

local function BlockingText()
    local status = Input.GetBlockStatus()
    if status == Input.BlockStatus.Both then return L("status.both") end
    if status == Input.BlockStatus.Keyboard then return L("status.keyboard") end
    if status == Input.BlockStatus.Controller then return L("status.controller") end
    return L("status.off")
end

local function Row(key, value)
    Widgets.ValueRow(L(key .. ".label"), value)
    Widgets.Tip(L(key .. ".tip"))
end

local function View()
    Row("about.trainer", FooterStyle.Version)
    Row("about.author", AUTHOR)
    Row("about.source", SOURCE)

    Widgets.Break(L("about.credits"))
    Row("about.locations", LOCATIONS)

    Widgets.Break(L("status.title"))
    Row("status.redscript", LoadedText(Dependencies.Redscript()))
    Row("status.inputhandler", LoadedText(Dependencies.InputHandler()))
    Row("status.utility", LoadedText(EasyEntityTools ~= nil))
    Row("status.inputblocking", BlockingText())
end

AboutView.Menu = Submenu.Create("about.title", View)

return AboutView
