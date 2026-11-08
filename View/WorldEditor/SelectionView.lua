local State = require("Core/State")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local WorldEditor = require("Features/WorldEditor/WorldEditor")
local Selection = require("Features/WorldEditor/Selection")
local Clipboard = require("Features/WorldEditor/Clipboard")
local Editing = require("Features/WorldEditor/Editing")
local ContextMenu = require("Features/WorldEditor/ContextMenu")

local SelectionView = {}

local s_PasteCount = nil
local s_PasteText = "0"

local function Button(key, action)
    if Widgets.Button(L(key .. ".label")) then WorldEditor.Run(action) end
    Widgets.Tip(L(key .. ".tip"))
end

local function PasteText()
    local count = Clipboard.Count()
    if count ~= s_PasteCount then
        s_PasteCount = count
        s_PasteText = tostring(count)
    end
    return s_PasteText
end

local function UniqueLabels()
    local seen = {}
    return function(label)
        seen[label] = (seen[label] or 0) + 1
        if seen[label] == 1 then return label end
        return string.format("%s (%d)", label, seen[label])
    end
end

local function SelectedRows(selected)
    if #selected == 0 then
        Widgets.ValueRow(L("worldeditor.selection.empty.label"), "")
        Widgets.Tip(L("worldeditor.selection.empty.tip"))
        return
    end

    local controller = State.Device.Device == State.Devices.Controller
    local rowTip = L(controller and "worldeditor.selection.row.controller" or "worldeditor.selection.row.keyboard")
    local label = UniqueLabels()
    for _, entry in ipairs(selected) do
        Widgets.ValueRow(label(entry.Name), "")
        Widgets.Tip(rowTip)
    end
end

local function AttachSelection()
    ContextMenu.StartAttach(Selection.GetAll())
end

local function View()
    WorldEditor.Watch()

    Button("worldeditor.selection.attach", AttachSelection)
    Button("worldeditor.selection.detach", WorldEditor.DetachSelection)
    Button("worldeditor.selection.copy", Clipboard.Copy)
    Button("worldeditor.selection.cut", Clipboard.Cut)
    if Widgets.ValueRow(L("worldeditor.selection.paste.label"), PasteText(), true) then WorldEditor.Run(Clipboard.Paste) end
    Widgets.Tip(L("worldeditor.selection.paste.tip"))
    Button("worldeditor.selection.delete", Clipboard.DeleteSelection)
    Button("worldeditor.selection.addtoscene", Editing.AddSelectionToScene)
    Button("worldeditor.selection.clear", Selection.Clear)

    local selected = Selection.GetAll()
    Widgets.Break(tip("worldeditor.selection.selected", { count = #selected }))
    SelectedRows(selected)
end

SelectionView.Menu = Submenu.Create("worldeditor.selection.label", View)

return SelectionView
