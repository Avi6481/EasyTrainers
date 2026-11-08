local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local WorldEditor = require("Features/WorldEditor/WorldEditor")
local Saves = require("Features/WorldEditor/Saves")
local Editing = require("Features/WorldEditor/Editing")

local SavesView = {}

local MAX_NAME = 40

local s_Names = { Scene = "" }
local s_SceneName = Ref.Field(s_Names, "Scene")
local s_Focus = nil

local function Pressed(key)
    local pressed = Widgets.Button(L(key .. ".label"))
    Widgets.Tip(L(key .. ".tip"))
    return pressed
end

local function UniqueLabels()
    local seen = {}
    return function(label)
        seen[label] = (seen[label] or 0) + 1
        if seen[label] == 1 then return label end
        return string.format("%s (%d)", label, seen[label])
    end
end

local function SaveView()
    local save = s_Focus
    if not save then
        Widgets.ValueRow(L("worldeditor.saves.gone.label"), "")
        Widgets.Tip(L("worldeditor.saves.gone.tip"))
        return
    end

    if Pressed("worldeditor.saves.load") then WorldEditor.Run(function() Editing.Load(save, false) end) end
    if Pressed("worldeditor.saves.loadhere") then WorldEditor.Run(function() Editing.Load(save, true) end) end
    Widgets.ValueRow(L("worldeditor.saves.props.label"), tostring(Saves.Count(save)))
    Widgets.Tip(L("worldeditor.saves.props.tip"))

    Widgets.Break("")
    if Widgets.HoldButton(L("worldeditor.saves.delete.label")) then
        s_Focus = nil
        WorldEditor.Run(function() Editing.DeleteSave(save) end)
    end
    Widgets.Tip(L("worldeditor.saves.delete.tip"))
end

local s_SaveMenu = Submenu.Create("worldeditor.saves.save.title", SaveView)

local function View()
    if Widgets.InputText(L("worldeditor.saves.saveas.label"), s_SceneName, MAX_NAME, L("worldeditor.saves.placeholder")) then
        local name = s_Names.Scene
        s_Names.Scene = ""
        WorldEditor.Run(function() Editing.SaveScene(name) end)
    end
    Widgets.Tip(L("worldeditor.saves.saveas.tip"))

    local saves = Saves.List()
    if #saves == 0 then return end

    Widgets.Break(tip("worldeditor.saves.list", { count = #saves }))
    local label = UniqueLabels()
    for _, save in ipairs(saves) do
        local name = tostring(save.Name)
        local count = Saves.Count(save)
        if Widgets.SubmenuButton(label(name), s_SaveMenu, tostring(count)) then
            s_Focus = save
            s_SaveMenu.Title = name
        end
        if Widgets.Selected() then Widgets.Tip(tip("worldeditor.saves.row.tip", { count = count })) end
    end
end

SavesView.Menu = Submenu.Create("worldeditor.saves.label", View)

return SavesView
