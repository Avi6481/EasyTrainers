local Ref = require("Core/Ref")
local Navigation = require("Navigation/Navigation")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local Notify = require("Utils/Notify")
local Facts = require("Features/World/Facts")
local GameFacts = require("Features/World/GameFacts")

local FactsView = {}

local KEY = "facts."
local ITEMS = KEY .. "items."
local CATEGORIES = KEY .. "categories."
local ALL = KEY .. "all."
local ALL_CATEGORIES = ALL .. "categories."
local MAX_NAME = 128
local MIN_VALUE = -1
local MAX_VALUE = 9999
local GAME_MIN = -9999
local GAME_MAX = 99999
local MARGIN_ROWS = 2

local s_Menus = {}
local s_Toggles = {}
local s_Choices = {}
local s_Docs = {}
local s_Badges = {}
local s_CustomName = { Value = "" }
local s_CustomNameRef = Ref.Field(s_CustomName, "Value")
local s_CustomValue = { Value = 1 }
local s_CustomValueRef = Ref.Field(s_CustomValue, "Value")
local s_CustomDoc = nil
local s_CustomSignature = nil

local s_RowFact = nil
local s_RowRef = Ref.New(function()
    return Facts.Shown(s_RowFact.Name)
end, function(value)
    Facts.SetPending(s_RowFact.Name, value)
end)
local s_AllSearch = { Query = "", Matched = nil, Version = nil, Results = {} }
local s_AllSearchRef = Ref.Field(s_AllSearch, "Query")
local s_Searches = {}
local s_CategoryMenus = {}
local s_Counts = {}
local s_Headings = {}
local s_WindowTop = 0
local s_WindowBottom = 0
local s_LoadAll = { Loaded = nil, Total = nil, Text = "" }

local function ValueText(value)
    if value == nil then return L(KEY .. "panel.unread") end
    return tostring(value)
end

local function ToggleRef(fact)
    local ref = s_Toggles[fact.Name]
    if not ref then
        ref = Ref.New(function()
            return (Facts.Values[fact.Name] or 0) > 0
        end, function(value)
            Facts.Set(fact.Name, value and 1 or 0)
        end)
        s_Toggles[fact.Name] = ref
    end
    return ref
end

local function ChoiceRef(fact)
    local ref = s_Choices[fact.Name]
    if not ref then
        ref = Ref.New(function()
            local current = Facts.Values[fact.Name] or 0
            for index, option in ipairs(fact.Values) do
                if option.Value == current then return index end
            end
            return 1
        end, function(index)
            local option = fact.Values[index]
            if option then Facts.Set(fact.Name, option.Value) end
        end)
        s_Choices[fact.Name] = ref
    end
    return ref
end

local function ChoiceItems(fact)
    local items = {}
    for _, option in ipairs(fact.Values) do
        local key = ITEMS .. fact.Key .. ".values." .. option.Key
        table.insert(items, { Label = L(key), Tip = tip(KEY .. "panel.setto", { value = option.Value }) })
    end
    return items
end

local function FactInfo(entry)
    local fact = entry.Fact
    local value = Facts.Values[fact.Name]
    local cached = s_Docs[fact.Name]
    if cached and cached.Value == value then return cached.Doc end

    local doc = {
        { Kind = "Eyebrow", Text = L(CATEGORIES .. entry.Category .. ".label") },
        { Kind = "Title", Text = L(ITEMS .. fact.Key .. ".label") },
        { Kind = "Separator" },
        { Kind = "Row", Label = L(KEY .. "panel.fact"), Value = fact.Name },
        { Kind = "Row", Label = L(KEY .. "panel.value"), Value = ValueText(value), Tone = "Strong" },
        { Kind = "Text", Text = L(ITEMS .. fact.Key .. ".info") }
    }
    if fact.Risky then table.insert(doc, { Kind = "Text", Text = L(KEY .. "panel.risky"), Tone = "Warn" }) end
    table.insert(doc, { Kind = "Text", Text = L(KEY .. "panel.note"), Tone = "Warn" })
    s_Docs[fact.Name] = { Value = value, Doc = doc }
    return doc
end

local function FactRow(fact, entry)
    local label = L(ITEMS .. fact.Key .. ".label")
    if fact.Values then
        if not entry.Items then entry.Items = ChoiceItems(fact) end
        Widgets.Dropdown(label, ChoiceRef(fact), entry.Items)
    else
        Widgets.Toggle(label, ToggleRef(fact))
    end
    Widgets.Tip(L(ITEMS .. fact.Key .. ".tip"))
    Widgets.Info(FactInfo, entry)
end

local function CategoryMenu(category)
    local entries = {}
    for _, fact in ipairs(category.Facts) do
        table.insert(entries, { Fact = fact, Category = category.Key })
    end

    return Submenu.Create(CATEGORIES .. category.Key .. ".label", function()
        Facts.Watch()
        for index, fact in ipairs(category.Facts) do FactRow(fact, entries[index]) end
    end)
end

for _, category in ipairs(Facts.Categories) do s_Menus[category.Key] = CategoryMenu(category) end

local function Badge(category)
    local active = 0
    for _, fact in ipairs(category.Facts) do
        if (Facts.Values[fact.Name] or 0) > 0 then active = active + 1 end
    end

    local badge = s_Badges[category.Key]
    if not badge or badge.Active ~= active then
        badge = { Active = active, Text = string.format("%d/%d", active, #category.Facts) }
        s_Badges[category.Key] = badge
    end
    return badge.Text
end

local function Count(value)
    local text = s_Counts[value]
    if text then return text end

    text = tostring(value)
    s_Counts[value] = text
    return text
end

local function Heading(count)
    local text = s_Headings[count]
    if text then return text end

    text = tip(ALL .. "results", { count = count })
    s_Headings[count] = text
    return text
end

local function Empty(key)
    Widgets.ValueRow(L(ALL .. key .. ".label"), "")
    Widgets.Tip(L(ALL .. key .. ".tip"))
end

local function BeginWindow()
    local content = Navigation.Content()
    local margin = Navigation.RowStep() * MARGIN_ROWS
    s_WindowTop = content.Y - margin
    s_WindowBottom = content.Y + content.Height + margin
end

local function OnScreen()
    local nav = Navigation.State
    local index = nav.Index + 1
    if index == nav.Current then return true end

    local y = Navigation.RowY(index)
    return y > s_WindowTop and y < s_WindowBottom
end

local function GameFactInfo(fact)
    local value = Facts.Values[fact.Name]
    if fact.Doc and fact.DocValue == value then return fact.Doc end

    local none = L(ALL .. "panel.none")
    local setIn = GameFacts.SourceNames(fact, fact.SetIn)
    local checkedIn = GameFacts.SourceNames(fact, fact.CheckedIn)
    fact.DocValue = value
    fact.Doc = {
        { Kind = "Eyebrow", Text = L(ALL_CATEGORIES .. fact.Category.Key .. ".label") },
        { Kind = "Title", Text = fact.Name },
        { Kind = "Separator" },
        { Kind = "Row", Label = L(KEY .. "panel.value"), Value = ValueText(value), Tone = "Strong" },
        { Kind = "Row", Label = L(ALL .. "panel.quest"), Value = fact.Group.Name },
        { Kind = "Row", Label = L(ALL .. "panel.seen"), Value = fact.Seen ~= "" and fact.Seen or none },
        { Kind = "Row", Label = L(ALL .. "panel.sets"), Value = Count(fact.Sets) },
        { Kind = "Row", Label = L(ALL .. "panel.checks"), Value = Count(fact.Checks) },
        { Kind = "Row", Label = L(ALL .. "panel.setin"), Value = setIn ~= "" and setIn or none },
        { Kind = "Row", Label = L(ALL .. "panel.checkedin"), Value = checkedIn ~= "" and checkedIn or none },
        { Kind = "Text", Text = L(KEY .. "panel.note"), Tone = "Warn" }
    }
    return fact.Doc
end

local function GameFactRow(fact)
    if not OnScreen() then
        Navigation.Next()
        return
    end

    s_RowFact = fact
    if Widgets.NumberActionInt(fact.Label, s_RowRef, GAME_MIN, GAME_MAX, 1, "%d") then Facts.Apply(fact.Name) end
    Widgets.Tip(L(ALL .. "row.tip"))
    Widgets.Info(GameFactInfo, fact)
    GameFacts.Show(fact)
end

local function GroupBreak(text)
    if not OnScreen() then
        Navigation.NextBreak()
        return
    end
    Widgets.Break(text)
end

local function Matches(search, source, version)
    if search.Matched == search.Query and search.Version == version then return search.Results end

    local results = {}
    for _, fact in ipairs(source) do
        if Widgets.SearchMatch(fact.Search, search.Query) then table.insert(results, fact) end
    end
    search.Matched = search.Query
    search.Version = version
    search.Results = results
    return results
end

local function Results(results)
    Widgets.Break(Heading(#results))
    BeginWindow()
    for _, fact in ipairs(results) do GameFactRow(fact) end
    if #results == 0 then Empty("none") end
end

local function Search(category)
    local search = s_Searches[category.Key]
    if search then return search end

    search = { Query = "", Matched = nil, Version = nil, Results = {} }
    search.Ref = Ref.Field(search, "Query")
    s_Searches[category.Key] = search
    return search
end

local function GameCategoryView(category)
    Facts.Watch()
    GameFacts.Request(category)

    local search = Search(category)
    local searching = search.Query ~= "" and category.Loaded
    local results = searching and Matches(search, category.Facts, GameFacts.Version) or nil
    Widgets.SearchRow(search.Ref, L(ALL .. "search.category"), results and #results or -1)
    Widgets.Tip(L(ALL .. "search.categorytip"))

    if not category.Loaded then
        Empty(category.Failed and "missing" or "loading")
        return
    end

    if results then
        Results(results)
        return
    end

    BeginWindow()
    for _, group in ipairs(category.Groups) do
        GroupBreak(group.Name)
        for _, fact in ipairs(group.Facts) do GameFactRow(fact) end
    end
end

local function GameCategoryMenu(category)
    local menu = s_CategoryMenus[category.Key]
    if menu then return menu end

    menu = Submenu.Create(ALL_CATEGORIES .. category.Key .. ".label", function() GameCategoryView(category) end)
    s_CategoryMenus[category.Key] = menu
    return menu
end

local function LoadAllValue()
    local cache = s_LoadAll
    if cache.Loaded == GameFacts.LoadedCount and cache.Total == GameFacts.Total then return cache.Text end

    cache.Loaded = GameFacts.LoadedCount
    cache.Total = GameFacts.Total
    cache.Text = cache.Loaded .. " / " .. cache.Total
    return cache.Text
end

local function AllView()
    Facts.Watch()
    GameFacts.Open()

    local searching = s_AllSearch.Query ~= "" and GameFacts.LoadedCount > 0
    local results = searching and Matches(s_AllSearch, GameFacts.All, GameFacts.Version) or nil
    Widgets.SearchRow(s_AllSearchRef, L(ALL .. "search.all"), results and #results or -1)
    Widgets.Tip(L(ALL .. "search.alltip"))

    if not GameFacts.Ready then
        Empty(GameFacts.Failed and "missing" or "loading")
        return
    end

    if results then
        Results(results)
        return
    end

    if s_AllSearch.Query ~= "" then
        Empty("empty")
        return
    end

    for _, category in ipairs(GameFacts.Categories) do
        Widgets.SubmenuButton(L(ALL_CATEGORIES .. category.Key .. ".label"), GameCategoryMenu(category), Count(category.Count))
        Widgets.Tip(L(ALL_CATEGORIES .. category.Key .. ".tip"))
    end

    Widgets.Break("")
    if Widgets.ValueRow(L(ALL .. "loadall.label"), LoadAllValue(), true) then GameFacts.LoadAll() end
    Widgets.Tip(L(ALL .. "loadall.tip"))
end

local AllMenu = Submenu.Create(ALL .. "label", AllView)

local function NameCharacter(character)
    return character:match("^[%w_%-%.]$") ~= nil
end

local function CustomInfo()
    local custom = Facts.Custom
    local signature = custom.Name .. "#" .. tostring(custom.Value)
    if s_CustomDoc and s_CustomSignature == signature then return s_CustomDoc end

    s_CustomDoc = {
        { Kind = "Eyebrow", Text = L(KEY .. "custom.label") },
        { Kind = "Title", Text = custom.Name ~= "" and custom.Name or L(KEY .. "custom.empty") },
        { Kind = "Separator" },
        { Kind = "Row", Label = L(KEY .. "panel.value"), Value = ValueText(custom.Value), Tone = "Strong" },
        { Kind = "Text", Text = L(KEY .. "custom.info") },
        { Kind = "Text", Text = L(KEY .. "panel.note"), Tone = "Warn" }
    }
    s_CustomSignature = signature
    return s_CustomDoc
end

local function CustomView()
    Facts.Watch()
    local custom = Facts.Custom

    Widgets.SubmenuButton(L(ALL .. "label"), AllMenu, GameFacts.Ready and Count(GameFacts.Total) or nil)
    Widgets.Tip(L(ALL .. "tip"))
    Widgets.Break("")

    s_CustomName.Value = custom.Name
    if Widgets.InputText(L(KEY .. "custom.name.label"), s_CustomNameRef, MAX_NAME, L(KEY .. "custom.name.placeholder"), NameCharacter) then
        Facts.SetCustomName(s_CustomNameRef.Value)
    end
    Widgets.Tip(L(KEY .. "custom.name.tip"))
    Widgets.Info(CustomInfo)

    Widgets.ValueRow(L(KEY .. "custom.value.label"), Facts.ValidName(custom.Name) and ValueText(custom.Value) or "")
    Widgets.Tip(L(KEY .. "custom.value.tip"))
    Widgets.Info(CustomInfo)

    if Widgets.NumberActionInt(L(KEY .. "custom.set.label"), s_CustomValueRef, MIN_VALUE, MAX_VALUE, 1, "%d") then
        if Facts.ValidName(custom.Name) then
            Facts.Set(custom.Name, s_CustomValue.Value)
        else
            Notify.Error(L("notify.world.factname"))
        end
    end
    Widgets.Tip(L(KEY .. "custom.set.tip"))
    Widgets.Info(CustomInfo)
end

local CustomMenu = Submenu.Create(KEY .. "custom.label", CustomView)

local function View()
    Facts.Watch()

    for _, category in ipairs(Facts.Categories) do
        Widgets.SubmenuButton(L(CATEGORIES .. category.Key .. ".label"), s_Menus[category.Key], Badge(category))
        Widgets.Tip(L(CATEGORIES .. category.Key .. ".tip"))
    end

    Widgets.Break("")
    Widgets.SubmenuButton(L(KEY .. "custom.label"), CustomMenu)
    Widgets.Tip(L(KEY .. "custom.tip"))
end

FactsView.Menu = Submenu.Create("facts.title", View)

return FactsView
