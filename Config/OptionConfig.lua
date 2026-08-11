local JsonHelper = require("Core/JsonHelper")
local Logger = require("Core/Logger")
local Registry = require("UI/Registry/OptionRegistry")

local OptionConfig = {
    FilePath = "Config/JSON/Options.json",
    Registry = Registry,
}

local function InferCategory(id)
    return id:match("^[^.]+%.([^.]+)") or "general"
end

local function ValuesMatch(left, right)
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end
    for key, value in pairs(left) do
        if not ValuesMatch(value, right[key]) then return false end
    end
    for key, value in pairs(right) do
        if not ValuesMatch(value, left[key]) then return false end
    end
    return true
end

---Register a structured option definition.
---The legacy (id, ref, default) signature remains supported during migration.
function OptionConfig.Register(specOrId, ref, default)
    if type(specOrId) == "table" then return Registry.Register(specOrId) end
    return Registry.Register({
        Id = specOrId,
        Kind = Registry.Kind.Toggle,
        Ref = ref,
        Default = default,
        Category = InferCategory(specOrId or ""),
    })
end

function OptionConfig.RegisterAll(specs)
    return Registry.RegisterAll(specs)
end

OptionConfig.DefineToggle = Registry.DefineToggle
OptionConfig.DefineButton = Registry.DefineButton
OptionConfig.DefineDropdown = Registry.DefineDropdown
OptionConfig.DefineSubmenu = Registry.DefineSubmenu

function OptionConfig.Load()
    local values, _, err = JsonHelper.LoadOrCreate(OptionConfig.FilePath, {})
    if type(values) ~= "table" then
        Logger.Log("OptionConfig: Failed to load options (" .. tostring(err) .. ")")
        return false
    end

    Registry.LoadValues(values)
    return true
end

function OptionConfig.Save()
    local existing, _, status = JsonHelper.ReadOptional(OptionConfig.FilePath)
    if status and status ~= "missing" then return false end
    if type(existing) ~= "table" then existing = {} end

    local values = Registry.ExportValues(existing)
    if ValuesMatch(existing, values) then
        Registry.ClearDirty()
        return true
    end

    local ok, err = JsonHelper.Write(OptionConfig.FilePath, values)
    if not ok then
        Logger.Log("OptionConfig: Failed to save options (" .. tostring(err) .. ")")
        return false
    end

    Registry.ClearDirty()
    return true
end

function OptionConfig.Get(id)
    return Registry.Get(id)
end

function OptionConfig.Search(query, options)
    return Registry.Search(query, options)
end

function OptionConfig.Activate(id)
    local activated = Registry.Activate(id)
    if activated then OptionConfig.Save() end
    return activated
end

function OptionConfig.SetHotkey(id, hotkey)
    return Registry.SetHotkey(id, hotkey)
end

return OptionConfig
