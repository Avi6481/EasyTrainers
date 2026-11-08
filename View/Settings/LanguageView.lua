local Language = require("Core/Language")
local Logger = require("Core/Logger")
local Settings = require("Features/Settings/Settings")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")

local LanguageView = {}

local LANGUAGE_FOLDER = "lang"

local s_Languages = nil
local s_Names = {}
local s_Selected = { Value = 1 }

local function LoadLanguages()
    s_Languages = Language.GetAvailable(LANGUAGE_FOLDER)
    s_Names = {}
    s_Selected.Value = 1

    local current = Language.GetCurrentCode()
    for index, language in ipairs(s_Languages) do
        table.insert(s_Names, language.name)
        if language.code == current then s_Selected.Value = index end
    end
end

local function SetLanguage(index)
    local language = s_Languages[index]
    if language and Settings.SetLanguage(language.code) then return end

    Logger.Error(L("languagemenu.loadfailed"))
end

local function View()
    if not s_Languages then LoadLanguages() end

    Widgets.ValueRow(L("languagemenu.current"), Language.GetCurrentName())
    Widgets.Tip(#s_Languages <= 1 and L("languagemenu.onlyone") or L("languagemenu.tip"))
    if Widgets.Button(L("languagemenu.reload.label")) then LoadLanguages() end
    Widgets.Tip(L("languagemenu.reload.tip"))

    Widgets.Break(L("languagemenu.label"))
    if Widgets.RadioList(s_Selected, s_Names) then SetLanguage(s_Selected.Value) end
end

LanguageView.Menu = Submenu.Create("languagemenu.title", View)

return LanguageView
