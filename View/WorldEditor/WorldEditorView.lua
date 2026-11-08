local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local WorldEditor = require("Features/WorldEditor/WorldEditor")
local Selection = require("Features/WorldEditor/Selection")
local Scene = require("Features/WorldEditor/Scene")
local History = require("Features/WorldEditor/History")
local SettingsView = require("View/WorldEditor/SettingsView")
local SpawnPropsView = require("View/WorldEditor/SpawnPropsView")
local SceneView = require("View/WorldEditor/SceneView")
local SelectionView = require("View/WorldEditor/SelectionView")
local SavesView = require("View/WorldEditor/SavesView")
local HowToView = require("View/WorldEditor/HowToView")

local WorldEditorView = {}

local s_Enabled = Ref.Field(WorldEditor, "Enabled")
local s_Badges = {}

local function Badge(key, count)
    local badge = s_Badges[key]
    if not badge or badge.Count ~= count then
        badge = { Count = count, Text = tostring(count) }
        s_Badges[key] = badge
    end
    return badge.Text
end

local function Link(key, menu, badge)
    Widgets.SubmenuButton(L(key .. ".label"), menu, badge)
    Widgets.Tip(L(key .. ".tip"))
end

local function Toggle(key, ref)
    Widgets.Toggle(L(key .. ".label"), ref)
    Widgets.Tip(L(key .. ".tip"))
end

local function Button(key, action)
    if Widgets.Button(L(key .. ".label")) then WorldEditor.Run(action) end
    Widgets.Tip(L(key .. ".tip"))
end

local function View()
    WorldEditor.Watch()

    Link("worldeditor.settings", SettingsView.Menu)
    Link("worldeditor.spawnprops", SpawnPropsView.Menu)
    Link("worldeditor.scene", SceneView.Menu, Badge("Scene", Scene.Count()))
    Link("worldeditor.selection", SelectionView.Menu, Badge("Selection", Selection.Count()))
    Link("worldeditor.saves", SavesView.Menu)

    Widgets.Break("")
    Toggle("worldeditor.enabled", s_Enabled)
    Button("worldeditor.undo", History.Undo)
    Button("worldeditor.redo", History.Redo)
    Button("worldeditor.resetcamera", WorldEditor.ResetCamera)
    Button("worldeditor.movev", WorldEditor.MovePlayerHere)

    Widgets.Break("")
    Link("worldeditor.howto", HowToView.Menu)
end

WorldEditorView.Menu = Submenu.Create("worldeditor.title", View)

return WorldEditorView
