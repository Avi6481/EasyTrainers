local Logger = require("Core/Logger")

local OptionRegistry = {
    Entries = {},
    Ordered = {},
    LoadedValues = {},
    Dirty = false,
}

OptionRegistry.Kind = {
    Button = "button",
    Toggle = "toggle",
    Dropdown = "dropdown",
    Submenu = "submenu",
    Break = "break",
    Number = "number",
}

local RefIndex = setmetatable({}, { __mode = "k" })
local HotkeyDown = {}

local function HotkeyAction(id)
    return "OPTION_" .. tostring(id or ""):upper():gsub("[^A-Z0-9]+", "_")
end

local function InferCategory(id)
    return tostring(id or ""):match("^[^.]+%.([^.]+)") or "general"
end

local function CopyList(values)
    local copy = {}
    for _, value in ipairs(values or {}) do table.insert(copy, value) end
    return copy
end

local function ResolveText(text, key, fallback)
    if text and text ~= "" then return tostring(text) end
    if key and key ~= "" then
        if type(L) == "function" then
            local ok, translated = pcall(L, key)
            if ok and translated and translated ~= "" then return tostring(translated) end
        end
        return tostring(key)
    end
    return fallback or ""
end

local function Merge(entry, metadata)
    if not metadata then return entry end

    local fields = {
        "Kind", "Label", "LabelKey", "Tip", "TipKey", "Category", "Action",
        "OnChange", "Hotkey", "ParentId", "Searchable", "Persistent",
        "Items", "Submenu", "Alignment", "Default",
    }
    for _, field in ipairs(fields) do
        if metadata[field] ~= nil then entry[field] = metadata[field] end
    end
    if metadata.Keywords ~= nil then entry.Keywords = CopyList(metadata.Keywords) end
    return entry
end

local function ApplyLoadedValue(entry)
    if not entry.Ref then return end

    local loaded = OptionRegistry.LoadedValues[entry.Id]
    if loaded ~= nil then
        if type(loaded) == "table" then
            for key, value in pairs(loaded) do
                if type(value) ~= "table" then entry.Ref[key] = value end
            end
        else
            entry.Ref.value = loaded
        end
    elseif entry.Ref.value == nil and entry.Default ~= nil then
        entry.Ref.value = entry.Default
    end
end

function OptionRegistry.Register(spec)
    if type(spec) ~= "table" or type(spec.Id) ~= "string" or spec.Id == "" then
        Logger.Log("OptionRegistry: registration requires a stable string Id.")
        return nil
    end

    local existing = OptionRegistry.Entries[spec.Id]
    if existing then
        if spec.Ref and existing.Ref and existing.Ref ~= spec.Ref then
            Logger.Log("OptionRegistry: duplicate Id uses a different state ref: " .. spec.Id)
            return nil
        end
        Merge(existing, spec)
        if spec.Ref and not existing.Ref then
            existing.Ref = spec.Ref
            RefIndex[spec.Ref] = existing
        end
        ApplyLoadedValue(existing)
        return existing
    end

    local entry = {
        Id = spec.Id,
        Kind = spec.Kind or OptionRegistry.Kind.Toggle,
        Ref = spec.Ref,
        Default = spec.Default,
        Label = spec.Label,
        LabelKey = spec.LabelKey,
        Tip = spec.Tip,
        TipKey = spec.TipKey,
        Category = spec.Category or InferCategory(spec.Id),
        Keywords = CopyList(spec.Keywords),
        Action = spec.Action,
        OnChange = spec.OnChange,
        Hotkey = spec.Hotkey,
        ParentId = spec.ParentId,
        Items = spec.Items,
        Submenu = spec.Submenu,
        Alignment = spec.Alignment,
        Searchable = spec.Searchable ~= false,
        Persistent = spec.Persistent,
        Order = #OptionRegistry.Ordered + 1,
    }
    if entry.Kind == OptionRegistry.Kind.Toggle and not entry.Hotkey then
        entry.Hotkey = HotkeyAction(entry.Id)
    end
    if entry.Persistent == nil then
        entry.Persistent = entry.Ref ~= nil and entry.Ref.value ~= nil
    end

    OptionRegistry.Entries[entry.Id] = entry
    table.insert(OptionRegistry.Ordered, entry)
    if entry.Ref then RefIndex[entry.Ref] = entry end
    ApplyLoadedValue(entry)
    return entry
end

function OptionRegistry.Define(id, kind, metadata)
    local spec = {}
    for key, value in pairs(metadata or {}) do spec[key] = value end
    spec.Id = id
    spec.Kind = kind
    return spec
end

function OptionRegistry.DefineToggle(id, ref, default, metadata)
    local spec = OptionRegistry.Define(id, OptionRegistry.Kind.Toggle, metadata)
    spec.Ref = ref
    spec.Default = default
    return spec
end

function OptionRegistry.DefineButton(id, action, metadata)
    local spec = OptionRegistry.Define(id, OptionRegistry.Kind.Button, metadata)
    spec.Action = action
    spec.Persistent = false
    return spec
end

function OptionRegistry.DefineDropdown(id, ref, items, metadata)
    local spec = OptionRegistry.Define(id, OptionRegistry.Kind.Dropdown, metadata)
    spec.Ref = ref
    spec.Items = items
    return spec
end

function OptionRegistry.DefineSubmenu(id, submenu, metadata)
    local spec = OptionRegistry.Define(id, OptionRegistry.Kind.Submenu, metadata)
    spec.Submenu = submenu
    spec.Persistent = false
    return spec
end

function OptionRegistry.RegisterAll(specs)
    local registered = {}
    for _, spec in ipairs(specs or {}) do
        local entry = OptionRegistry.Register(spec)
        if entry then table.insert(registered, entry) end
    end
    return registered
end

function OptionRegistry.Get(id)
    return OptionRegistry.Entries[id]
end

function OptionRegistry.FindByRef(ref)
    return ref and RefIndex[ref] or nil
end

function OptionRegistry.GetAll()
    local entries = {}
    for _, entry in ipairs(OptionRegistry.Ordered) do table.insert(entries, entry) end
    return entries
end

function OptionRegistry.Observe(target, metadata)
    local entry = type(target) == "string" and OptionRegistry.Get(target) or OptionRegistry.FindByRef(target)
    if not entry then return nil end
    return Merge(entry, metadata)
end

function OptionRegistry.GetLabel(entryOrId)
    local entry = type(entryOrId) == "table" and entryOrId or OptionRegistry.Get(entryOrId)
    if not entry then return "" end
    return ResolveText(entry.Label, entry.LabelKey, entry.Id)
end

function OptionRegistry.GetTip(entryOrId)
    local entry = type(entryOrId) == "table" and entryOrId or OptionRegistry.Get(entryOrId)
    if not entry then return "" end
    return ResolveText(entry.Tip, entry.TipKey, "")
end

function OptionRegistry.GetValue(id)
    local entry = OptionRegistry.Get(id)
    return entry and entry.Ref and entry.Ref.value or nil
end

function OptionRegistry.SetValue(id, value, invokeChange)
    local entry = OptionRegistry.Get(id)
    if not entry or not entry.Ref then return false end
    if entry.Ref.value == value then return false end

    entry.Ref.value = value
    OptionRegistry.Dirty = true
    if invokeChange ~= false and entry.OnChange then entry.OnChange(value, entry) end
    return true
end

function OptionRegistry.Activate(id)
    local entry = OptionRegistry.Get(id)
    if not entry then return false end

    if entry.Kind == OptionRegistry.Kind.Toggle and entry.Ref then
        local changed = OptionRegistry.SetValue(id, not entry.Ref.value)
        if changed and entry.Action then entry.Action(entry.Ref.value, entry) end
        return changed
    end

    if entry.Action then
        entry.Action(entry)
        return true
    end
    return false
end

function OptionRegistry.SetHotkey(id, hotkey)
    local entry = OptionRegistry.Get(id)
    if not entry or entry.Kind ~= OptionRegistry.Kind.Toggle or type(hotkey) ~= "table" then return false end
    local Bindings = require("Controls/Bindings")
    local BindingsConfig = require("Config/BindingsConfig")
    entry.Hotkey = HotkeyAction(entry.Id)
    Bindings.Rebind(entry.Hotkey, hotkey)
    return BindingsConfig.Save()
end

function OptionRegistry.GetHotkeyAction(entryOrId)
    local entry = type(entryOrId) == "table" and entryOrId or OptionRegistry.Get(entryOrId)
    return entry and (entry.Hotkey or HotkeyAction(entry.Id)) or nil
end

function OptionRegistry.RegisterHotkeyActions()
    local Bindings = require("Controls/Bindings")
    local count = 0
    for _, entry in ipairs(OptionRegistry.Ordered) do
        if entry.Kind == OptionRegistry.Kind.Toggle then
            Bindings.EnsureAction(OptionRegistry.GetHotkeyAction(entry))
            count = count + 1
        end
    end
    return count
end

function OptionRegistry.UpdateHotkeys()
    local Bindings = require("Controls/Bindings")
    local changed = false
    for _, entry in ipairs(OptionRegistry.Ordered) do
        if entry.Kind == OptionRegistry.Kind.Toggle and entry.Ref then
            local action = HotkeyAction(entry.Id)
            local down = Bindings.IsActionDown(action)
            if down and not HotkeyDown[action] then
                OptionRegistry.Activate(entry.Id)
                changed = true
            end
            HotkeyDown[action] = down
        end
    end
    return changed
end

function OptionRegistry.Search(query, options)
    options = options or {}
    local terms = {}
    for term in tostring(query or ""):lower():gmatch("%S+") do table.insert(terms, term) end

    local matches = {}
    for _, entry in ipairs(OptionRegistry.Ordered) do
        local categoryMatches = not options.Category or entry.Category == options.Category
        if entry.Searchable and categoryMatches then
            local values = {}
            local function Add(value)
                if value ~= nil and value ~= "" then table.insert(values, tostring(value)) end
            end
            Add(entry.Id)
            Add(OptionRegistry.GetLabel(entry))
            Add(OptionRegistry.GetTip(entry))
            Add(entry.LabelKey)
            Add(entry.TipKey)
            Add(entry.Category)
            for _, keyword in ipairs(entry.Keywords or {}) do table.insert(values, keyword) end
            local haystack = table.concat(values, " "):lower()

            local matched = true
            for _, term in ipairs(terms) do
                if not haystack:find(term, 1, true) then
                    matched = false
                    break
                end
            end
            if matched then table.insert(matches, entry) end
        end
    end
    return matches
end

function OptionRegistry.GetCategories()
    local categories, seen = {}, {}
    for _, entry in ipairs(OptionRegistry.Ordered) do
        if not seen[entry.Category] then
            seen[entry.Category] = true
            table.insert(categories, entry.Category)
        end
    end
    return categories
end

function OptionRegistry.LoadValues(values)
    OptionRegistry.LoadedValues = type(values) == "table" and values or {}
    for _, entry in ipairs(OptionRegistry.Ordered) do ApplyLoadedValue(entry) end
    OptionRegistry.Dirty = false
end

function OptionRegistry.ExportValues(seed)
    local values = {}
    for key, value in pairs(type(seed) == "table" and seed or {}) do values[key] = value end
    for _, entry in ipairs(OptionRegistry.Ordered) do
        if entry.Persistent and entry.Ref then
            if entry.Ref.enabled ~= nil then
                values[entry.Id] = { value = entry.Ref.value, enabled = entry.Ref.enabled }
            else
                values[entry.Id] = entry.Ref.value
            end
        end
    end
    return values
end

function OptionRegistry.MarkChanged(target)
    local entry = type(target) == "string" and OptionRegistry.Get(target) or OptionRegistry.FindByRef(target)
    if entry then OptionRegistry.Dirty = true end
    return entry
end

function OptionRegistry.ClearDirty()
    OptionRegistry.Dirty = false
end

return OptionRegistry
