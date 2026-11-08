local Logger = require("Core/Logger")
local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")

local SearchTestView = {}

local WORDS = {
    "Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot", "Golf", "Hotel", "India",
    "Juliett", "Kilo", "Lima", "Mike", "November", "Oscar", "Papa", "Quebec", "Romeo",
    "Sierra", "Tango", "Uniform", "Victor", "Whiskey", "X-ray", "Yankee", "Zulu"
}

local s_State = {
    Query = ""
}

local s_Query = Ref.Field(s_State, "Query")

local function Matches()
    local matches = {}
    for _, word in ipairs(WORDS) do
        if Widgets.SearchMatch(word, s_State.Query) then table.insert(matches, word) end
    end
    return matches
end

local function View()
    local matches = Matches()
    Widgets.SearchRow(s_Query, "Search the list", #matches)

    for _, word in ipairs(matches) do
        if Widgets.Button(word) then Logger.Log("UI Test: picked " .. word) end
    end

    if #matches == 0 then Widgets.ValueRow("No Matches", "Try another word") end
end

SearchTestView.Menu = Submenu.Create("Search", View)

return SearchTestView
