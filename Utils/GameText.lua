local GameText = {}

function GameText.Get(key, fallback)
    if type(key) ~= "string" or key == "" then return fallback end
    local ok, text = pcall(Game.GetLocalizedText, key)
    if not ok or type(text) ~= "string" or text == "" or text == key then return fallback end
    return text
end

function GameText.FromName(name, fallback)
    if not name then return fallback end

    local ok, text = pcall(Game.GetLocalizedTextByKey, name)
    if ok and type(text) == "string" and text ~= "" then return text end

    local found, key = pcall(Game.LocKeyToString, name)
    if found then return GameText.Get(key, fallback) end
    return fallback
end

function GameText.Number(value)
    local shown = string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")
    if shown == "-0" then return "0" end
    return shown
end

local function Replace(text, name, shown)
    local function Wrap(percent) return "<Rich>" .. shown .. percent .. "</>" end
    text = text:gsub("{" .. name .. "}(%%?)", Wrap)
    text = text:gsub("{" .. name .. ",[^}]*}(%%?)", Wrap)
    return text
end

local function Values(ui, package)
    local ok, values = pcall(package, ui)
    if ok and values then return values.floatValues, values.intValues, values.nameValues, values.statValues end
    return ui:FloatValues(), ui:IntValues(), nil, nil
end

function GameText.Fill(text, ui, package)
    if not ui then return text end

    local floats, ints, names, stats = Values(ui, package)
    for index, value in ipairs(floats or {}) do text = Replace(text, "float_" .. (index - 1), GameText.Number(value)) end
    for index, value in ipairs(ints or {}) do text = Replace(text, "int_" .. (index - 1), tostring(value)) end
    for index, value in ipairs(stats or {}) do text = Replace(text, "stat_" .. (index - 1), GameText.Number(value)) end
    for index, value in ipairs(names or {}) do
        local name = Game.NameToString(value)
        text = Replace(text, "name_" .. (index - 1), GameText.Get(name, name))
    end
    return text
end

return GameText
