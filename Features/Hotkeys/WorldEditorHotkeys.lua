local Define = require("Features/Hotkeys/Define")
local WorldEditor = require("Features/WorldEditor/WorldEditor")

local Toggle, Action = Define.Toggle, Define.Action

local function ResetCamera()
    WorldEditor.Run(WorldEditor.ResetCamera)
end

local function MovePlayerHere()
    WorldEditor.Run(WorldEditor.MovePlayerHere)
end

local WorldEditorHotkeys = {
    Toggle("Enabled", "worldeditor.enabled", WorldEditor),
    Action("ResetCamera", "worldeditor.resetcamera", ResetCamera),
    Action("MovePlayerHere", "worldeditor.movev", MovePlayerHere)
}

return WorldEditorHotkeys
