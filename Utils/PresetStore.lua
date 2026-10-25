local JsonHelper = require("Core/JsonHelper")

local PresetStore = {}

local function Clamp(ref, value)
    value = tonumber(value) or ref.value
    if ref.min then value = math.max(ref.min, value) end
    if ref.max then value = math.min(ref.max, value) end
    return value
end

function PresetStore.Create(path, refs)
    local store = {}
    local s_Presets = nil

    local function Load()
        if s_Presets then return s_Presets end
        local data = JsonHelper.LoadOrCreate(path, { Presets = {} })
        s_Presets = type(data) == "table" and type(data.Presets) == "table" and data.Presets or {}
        return s_Presets
    end

    local function Write()
        JsonHelper.Write(path, { Presets = Load() })
    end

    function store.List()
        return Load()
    end

    function store.Save(name)
        name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if name == "" then name = "Preset " .. tostring(#Load() + 1) end

        local values = {}
        for key, ref in pairs(refs) do values[key] = ref.value end
        table.insert(Load(), { Name = name, Values = values })
        Write()
        return name
    end

    function store.Apply(index)
        local preset = Load()[index]
        if not preset then return nil end
        for key, ref in pairs(refs) do
            if preset.Values[key] ~= nil then ref.value = Clamp(ref, preset.Values[key]) end
        end
        return preset.Name
    end

    function store.Delete(index)
        if not Load()[index] then return nil end
        local removed = table.remove(Load(), index)
        Write()
        return removed.Name
    end

    return store
end

return PresetStore
