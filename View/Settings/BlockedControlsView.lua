local InputBlock = require("Core/InputBlock")
local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")

local BlockedControlsView = {}

local KEY = "settings.blockedcontrols."

local GROUPS = { "keyboard", "mouse", "controller" }

local s_BlockGame = Ref.Field(InputBlock, "Enabled")
local s_Refs = {}
local s_MenuDoc = nil

for _, extra in ipairs(InputBlock.Extras) do s_Refs[extra.Id] = Ref.Field(InputBlock.Extra, extra.Id) end

local function MenuInfo()
    if s_MenuDoc then return s_MenuDoc end

    s_MenuDoc = {
        { Kind = "Eyebrow", Text = L(KEY .. "title") },
        { Kind = "Title", Text = L(KEY .. "info.title") },
        { Kind = "Separator" },
        { Kind = "Entry", Label = L(KEY .. "keyboard"), LabelSample = L(KEY .. "controller"), Text = L(KEY .. "info.keyboard") },
        { Kind = "Entry", Label = L(KEY .. "mouse"), LabelSample = L(KEY .. "controller"), Text = L(KEY .. "info.mouse") },
        { Kind = "Entry", Label = L(KEY .. "controller"), LabelSample = L(KEY .. "controller"), Text = L(KEY .. "info.controller") },
        { Kind = "Text", Text = L(KEY .. "info.typing"), Tone = "Dim" }
    }
    return s_MenuDoc
end

local function Group(group)
    Widgets.Break(L(KEY .. group))
    for _, extra in ipairs(InputBlock.Extras) do
        if extra.Group == group then
            local key = KEY .. extra.Id:lower()
            Widgets.Toggle(L(key .. ".label"), s_Refs[extra.Id])
            Widgets.Tip(L(key .. ".tip"))
        end
    end
end

local function View()
    Widgets.Toggle(L("navigation.blockgame.label"), s_BlockGame)
    Widgets.Tip(L("navigation.blockgame.tip"))
    Widgets.Info(MenuInfo)

    for _, group in ipairs(GROUPS) do Group(group) end

    Widgets.Break("")
    if Widgets.Button(L(KEY .. "reset.label")) then InputBlock.ResetExtras() end
    Widgets.Tip(L(KEY .. "reset.tip"))
end

BlockedControlsView.Menu = Submenu.Create("settings.blockedcontrols.title", View)

return BlockedControlsView
