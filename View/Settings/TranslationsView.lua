local Buttons = require("UI").Buttons
local JsonHelper = require("Core/JsonHelper")
local Language = require("Core/Language")
local Notification = require("UI").Notification

local configPath = "Config/JSON/Settings.json"
local langFolder = "lang" -- Leaving this here so other authors don't have to adjust their language pack 

local config
local availableLangs = {}
local languageRadio = { index = 1 }
local languageOptions = {}
local initialized = false 

local function LoadAvailableLanguages()
    availableLangs = Language.GetAvailable(langFolder)
    languageOptions = {}
    config = JsonHelper.LoadOrCreate(configPath, { shown = false, Lang = "en" }) or { Lang = "en" }
    local selectedLangIndex = 1
    local currentCode = config.Lang or Language.GetCurrentCode()

    for index, language in ipairs(availableLangs) do
        table.insert(languageOptions, language.name)
        if language.code == currentCode then
            selectedLangIndex = index
        end
    end

    languageRadio.index = selectedLangIndex
end

local function SetLanguage(language)
    if not language or not Language.Load(language.code) then
        Notification.Error(L("languagemenu.loadfailed"))
        return
    end

    config.Lang = language.code
    local saved = JsonHelper.Write(configPath, config)
    if not saved then
        Notification.Warning(L("languagemenu.savefailed"))
        return
    end

    local loadMessage = Language.Get("loadmessage")
    if loadMessage ~= "" then
        Notification.Success(loadMessage)
    end
end

local function LanguageMenuView()
    if not initialized then
        LoadAvailableLanguages()
        initialized = true
    end

    Buttons.Option(L("languagemenu.reload.label"), L("languagemenu.reload.tip"), function()
        LoadAvailableLanguages()
    end)

    Buttons.Break(L("languagemenu.tip"))
    Buttons.Break(L("languagemenu.current") .. ": " .. Language.GetCurrentName())
    if #availableLangs <= 1 then
        Buttons.Break(L("languagemenu.onlyone"))
    end

    Buttons.Radio("", languageRadio, languageOptions, "", function()
        SetLanguage(availableLangs[languageRadio.index])
    end)
end

return {
    title = "languagemenu.title",
    view = LanguageMenuView
}
