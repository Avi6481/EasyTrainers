local JsonHelper = require("Core/JsonHelper")
local Logger = require("Core/Logger")
local Layout = require("Features/WorldEditor/Layout")

local Saves = {}

local PATH = "Config/WorldEditorSaves.json"
local LEGACY_PATH = "Config/JSON/WorldEditorSaves.json"
local VERSION = 1

local s_List = nil

local function Read(path)
    local data = JsonHelper.ReadOptional(path)
    if type(data) == "table" and type(data.Saves) == "table" then return data.Saves end
    return nil
end

local function Load()
    if s_List then return s_List end
    s_List = Read(PATH)
    if not s_List then
        s_List = Read(LEGACY_PATH) or {}
        if #s_List > 0 then Logger.Log(string.format("WorldEditor: read %d saves from %s", #s_List, LEGACY_PATH)) end
    end
    return s_List
end

local function Write()
    return JsonHelper.Write(PATH, { Version = VERSION, Saves = Load() }) == true
end

local function Clean(name)
    name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then name = tip("worldeditor.saves.default", { count = #Load() + 1 }) end
    return name
end

local function IndexOf(save)
    for index, entry in ipairs(Load()) do
        if entry == save then return index end
    end
    return nil
end

local function FindName(name)
    for index, entry in ipairs(Load()) do
        if entry.Name == name then return index end
    end
    return nil
end

function Saves.List()
    return Load()
end

function Saves.Count(save)
    return type(save.Items) == "table" and #save.Items or 0
end

function Saves.Save(name, items)
    local layout, skipped = Layout.Capture(Layout.WithChildren(items))
    if #layout.Items == 0 then return nil, skipped, false end

    local save = { Name = Clean(name), Items = layout.Items, Links = layout.Links }
    local index = FindName(save.Name)
    local previous = index and Load()[index] or nil
    if index then
        Load()[index] = save
    else
        table.insert(Load(), save)
    end
    if Write() then return save, skipped, false end

    if previous then
        Load()[index] = previous
    else
        table.remove(Load())
    end
    return nil, skipped, true
end

function Saves.Load(save, here)
    if not save or Saves.Count(save) == 0 then return 0 end
    local layout = { Items = save.Items, Links = type(save.Links) == "table" and save.Links or {} }

    local offset = nil
    if here then
        local target = Layout.Target()
        if not target then return 0 end
        offset = Layout.OffsetTo(layout, target)
    end
    return Layout.Spawn(layout, offset, { OnDone = Layout.SelectRoot })
end

function Saves.Delete(save)
    local index = IndexOf(save)
    if not index then return false end
    table.remove(Load(), index)
    return Write()
end

return Saves
