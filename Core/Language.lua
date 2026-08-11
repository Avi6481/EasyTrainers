local Logger = require("Core/Logger")
local JsonHelper = require("Core/JsonHelper")

local Language = {}

Language.defaultLang = "en"
Language.currentLang = "en"
Language.translations = {}
Language.fallbackTranslations = {}

local function isValidLanguageCode(langCode)
    return type(langCode) == "string" and langCode:match("^[%w_%-]+$") ~= nil
end

local function readLanguage(langCode)
    if not isValidLanguageCode(langCode) then
        return nil, "Invalid language code: " .. tostring(langCode)
    end

    local path = string.format("lang/%s.json", langCode)
    local data, err = JsonHelper.Read(path)
    if type(data) ~= "table" then
        return nil, err or ("Unexpected localization format in: " .. path)
    end

    return data
end

local function lookup(data, key)
    if type(data) ~= "table" or type(key) ~= "string" or key == "" then
        return nil
    end

    local value = data
    for part in key:gmatch("[^%.]+") do
        if type(value) ~= "table" then return nil end
        value = value[part]
        if value == nil then return nil end
    end

    return type(value) == "string" and value or nil
end

function Language.Load(langCode)
    local requested = langCode or Language.defaultLang
    local fallback, fallbackErr = readLanguage(Language.defaultLang)
    if not fallback then
        Logger.Log("Localization: Failed to load fallback language: " .. tostring(fallbackErr))
        return false
    end

    local data = fallback
    if requested ~= Language.defaultLang then
        local requestedData, err = readLanguage(requested)
        if not requestedData then
            Logger.Log("Localization: Failed to load language '" .. tostring(requested) .. "': " .. tostring(err))
            return false
        end
        data = requestedData
    end

    Language.currentLang = requested
    Language.translations = data
    Language.fallbackTranslations = fallback
    Logger.Log("Localization: Loaded language '" .. requested .. "'.")
    return true
end

function Language.GetAvailable(folder)
    local languages = {}
    local seen = {}
    local files = dir(folder or "lang") or {}

    for _, entry in ipairs(files) do
        local filename = type(entry) == "table" and entry.name or entry
        local code = type(filename) == "string" and filename:match("^(.+)%.json$") or nil
        if code and isValidLanguageCode(code) and not seen[code] then
            local data = readLanguage(code)
            if data then
                local name = lookup(data, "_meta.name") or lookup(data, "language.name") or code
                table.insert(languages, { code = code, name = name })
                seen[code] = true
            else
                Logger.Log("Localization: Ignoring invalid language file: " .. tostring(filename))
            end
        end
    end

    table.sort(languages, function(a, b)
        if a.code == Language.defaultLang then return true end
        if b.code == Language.defaultLang then return false end
        return a.name:lower() < b.name:lower()
    end)

    return languages
end

function Language.Has(key)
    return lookup(Language.translations, key) ~= nil
        or lookup(Language.fallbackTranslations, key) ~= nil
end

function Language.Get(key)
    if type(key) ~= "string" then
        return tostring(key or "")
    end

    return lookup(Language.translations, key)
        or lookup(Language.fallbackTranslations, key)
        or key
end

function Language.GetCurrentCode()
    return Language.currentLang
end

function Language.GetCurrentName()
    return lookup(Language.translations, "_meta.name")
        or lookup(Language.translations, "language.name")
        or Language.currentLang
end

function Language.tip(key, placeholders)
    local tipText = Language.Get(key)

    if type(placeholders) == "table" then
        for placeholder, value in pairs(placeholders) do
            local resolved = type(value) == "string" and Language.Get(value) or tostring(value)
            tipText = tipText:gsub("{" .. placeholder .. "}", resolved)
        end
    end

    return tipText
end

-- Only really used in the binding button so don't really need it to be a global
function Language.GetInputKey(code)
    return Language.translations.inputkeys and Language.translations.inputkeys[tostring(code)]
        or Language.fallbackTranslations.inputkeys and Language.fallbackTranslations.inputkeys[tostring(code)]
        or tostring(code)
end

function Language.GetInputButton(code)
    return Language.translations.inputbuttons and Language.translations.inputbuttons[tostring(code)]
        or Language.fallbackTranslations.inputbuttons and Language.fallbackTranslations.inputbuttons[tostring(code)]
        or "Btn" .. tostring(code)
end

L = function(key) return Language.Get(key) end
tip = function(key, placeholders) return Language.tip(key, placeholders) end

return Language
