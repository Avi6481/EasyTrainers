local JsonHelper = require("Core/JsonHelper")
local Logger = require("Core/Logger")
local Layout = require("UI/Style/Layout")
local Style = require("UI/Style/Style")

local UIConfig = { FilePath = "Config/JSON/UI.json", SchemaVersion = 2, Sections = {}, LoadedSections = {} }

local function CopyInto(target, source)
    if type(source) ~= "table" then return end
    for key, value in pairs(source) do
        if type(value) ~= "table" then target[key] = value end
    end
end

local function SerializableCopy(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        local valueType = type(value)
        if valueType == "number" or valueType == "string" or valueType == "boolean" then
            copy[key] = value
        elseif valueType == "table" then
            copy[key] = SerializableCopy(value)
        end
    end
    return copy
end

local function MergeInto(target, source)
    if type(target) ~= "table" or type(source) ~= "table" then return end
    for key, value in pairs(source) do
        if type(value) == "table" and type(target[key]) == "table" then
            MergeInto(target[key], value)
        elseif type(value) ~= "table" then
            target[key] = value
        end
    end
end

local function CollectData()
    return {
        SchemaVersion = UIConfig.SchemaVersion,
        Layout = SerializableCopy(Layout),
        Colors = SerializableCopy(Style),
        Sections = SerializableCopy(UIConfig.Sections),
    }
end

local function ApplyLegacy(data)
    if type(data.Colors) == "table" then
        Style.Background = data.Colors.Background or Style.Background
        Style.Text = data.Colors.Text or Style.Text
        Style.TextDisabled = data.Colors.MutedText or Style.TextDisabled
        Style.Border = data.Colors.Border or Style.Border
        Style.Accent = data.Colors.Highlight or Style.Accent
    end
end

function UIConfig.Load()
    local data, _, err = JsonHelper.LoadOrCreate(UIConfig.FilePath, CollectData())
    if type(data) ~= "table" then
        Logger.Log("UIConfig: Failed to load UI settings (" .. tostring(err) .. ")")
        return false
    end

    if data.SchemaVersion == UIConfig.SchemaVersion then
        CopyInto(Layout, data.Layout)
        CopyInto(Style, data.Colors)
        UIConfig.LoadedSections = type(data.Sections) == "table" and data.Sections or {}
        for name, section in pairs(UIConfig.Sections) do MergeInto(section, UIConfig.LoadedSections[name]) end
        Logger.Log(string.format(
            "UIConfig: Loaded schema %d position=(%.1f, %.1f), size=(%.1f, %.1f).",
            UIConfig.SchemaVersion, Layout.X, Layout.Y, Layout.Width, Layout.Height))
    else
        ApplyLegacy(data)
        Logger.Log("UIConfig: Loaded legacy appearance values for the consolidated UI.")
    end
    return true
end

function UIConfig.RegisterSection(name, section)
    if type(name) ~= "string" or type(section) ~= "table" then return end
    UIConfig.Sections[name] = section
    MergeInto(section, UIConfig.LoadedSections[name])
end

function UIConfig.Save()
    local ok, err = JsonHelper.Write(UIConfig.FilePath, CollectData())
    if not ok then
        Logger.Log("UIConfig: Failed to save UI settings (" .. tostring(err) .. ")")
        return false
    end
    return true
end

return UIConfig
