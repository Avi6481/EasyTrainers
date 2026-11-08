local Logger = require("Core/Logger")
local Notify = require("Utils/Notify")

local GameFacts = {
    Ready = false,
    Failed = false,
    Total = 0,
    LoadedCount = 0,
    Version = 0,
    Categories = {},
    All = {}
}

local FOLDER = "Data/GameFacts/"
local INDEX = FOLDER .. "Index.json"
local MAX_SHOWN = 64
local READ_INTERVAL = 0.5
local MAX_LABEL = 40

local s_WantIndex = false
local s_WantAll = false
local s_Bulk = false
local s_Queue = {}
local s_Shown = {}
local s_ShownCount = 0
local s_NextRead = 0

local function ReadJson(path)
    local file = io.open(path, "r")
    if not file then return nil end

    local text = file:read("*a")
    file:close()

    local ok, data = pcall(json.decode, text)
    if not ok or type(data) ~= "table" then return nil end
    return data
end

local function Label(name)
    if #name <= MAX_LABEL then return name end
    return name:sub(1, MAX_LABEL - 3) .. "..."
end

local function Build(row, category, group)
    local name = tostring(row[1] or "")
    return {
        Name = name,
        Label = Label(name),
        Seen = tostring(row[2] or ""),
        Sets = tonumber(row[3]) or 0,
        Checks = tonumber(row[4]) or 0,
        SetIn = type(row[5]) == "table" and row[5] or {},
        CheckedIn = type(row[6]) == "table" and row[6] or {},
        Search = (name .. " " .. group.Name):lower(),
        Group = group,
        Category = category
    }
end

local function LoadCategory(category)
    category.Pending = false

    local data = ReadJson(FOLDER .. category.File .. ".json")
    if not data or type(data.Groups) ~= "table" then
        category.Failed = true
        Logger.Log("Game facts: couldn't read " .. category.File)
        return
    end

    category.Sources = type(data.Sources) == "table" and data.Sources or {}
    for _, entry in ipairs(data.Groups) do
        local group = { Name = tostring(entry.Name or ""), Facts = {} }
        for _, row in ipairs(type(entry.Facts) == "table" and entry.Facts or {}) do
            local fact = Build(row, category, group)
            if fact.Name ~= "" then
                table.insert(group.Facts, fact)
                table.insert(category.Facts, fact)
                table.insert(GameFacts.All, fact)
            end
        end
        table.insert(category.Groups, group)
    end

    category.Loaded = true
    GameFacts.LoadedCount = GameFacts.LoadedCount + #category.Facts
    GameFacts.Version = GameFacts.Version + 1
end

local function LoadIndex()
    local data = ReadJson(INDEX)
    if not data or type(data.Categories) ~= "table" then
        GameFacts.Failed = true
        Logger.Log("Game facts: couldn't read " .. INDEX)
        Notify.Error(L("notify.world.gamefactsfailed"))
        return
    end

    for _, entry in ipairs(data.Categories) do
        local file = tostring(entry.File or "")
        if file:match("^%w+$") then
            table.insert(GameFacts.Categories, {
                Key = tostring(entry.Key or file):lower(),
                File = file,
                Count = tonumber(entry.Count) or 0,
                Loaded = false,
                Pending = false,
                Failed = false,
                Sources = {},
                Groups = {},
                Facts = {}
            })
        end
    end

    GameFacts.Total = tonumber(data.Total) or 0
    GameFacts.Ready = true
    Logger.Log("Game facts: index lists " .. GameFacts.Total .. " facts in " .. #GameFacts.Categories .. " categories")
end

function GameFacts.Open()
    if GameFacts.Ready or GameFacts.Failed then return end
    s_WantIndex = true
end

function GameFacts.Request(category)
    if category.Loaded or category.Pending or category.Failed then return end
    category.Pending = true
    table.insert(s_Queue, category)
end

local function QueueAll()
    for _, category in ipairs(GameFacts.Categories) do GameFacts.Request(category) end
    if #s_Queue == 0 then
        Notify.Info(tip("notify.world.gamefactsloaded", { count = GameFacts.LoadedCount }))
        return
    end
    s_Bulk = true
end

function GameFacts.LoadAll()
    if GameFacts.Failed then
        Notify.Error(L("notify.world.gamefactsfailed"))
        return
    end
    if not GameFacts.Ready then
        s_WantIndex = true
        s_WantAll = true
        return
    end
    QueueAll()
end

function GameFacts.Busy()
    return s_WantIndex or #s_Queue > 0
end

function GameFacts.SourceNames(fact, indices)
    local names = {}
    local sources = fact.Category.Sources
    for _, index in ipairs(indices) do
        local name = sources[(tonumber(index) or -1) + 1]
        if name then table.insert(names, tostring(name)) end
    end
    return table.concat(names, ", ")
end

function GameFacts.Show(fact)
    if s_ShownCount >= MAX_SHOWN then return end
    s_ShownCount = s_ShownCount + 1
    s_Shown[s_ShownCount] = fact
end

function GameFacts.Load()
    if s_WantIndex then
        s_WantIndex = false
        LoadIndex()
        if s_WantAll and GameFacts.Ready then QueueAll() end
        s_WantAll = false
        return
    end

    local category = table.remove(s_Queue, 1)
    if not category then return end

    LoadCategory(category)
    if #s_Queue > 0 or not s_Bulk then return end

    s_Bulk = false
    Notify.Success(tip("notify.world.gamefactsloaded", { count = GameFacts.LoadedCount }))
end

function GameFacts.Update(quests, now, values)
    local count = s_ShownCount
    s_ShownCount = 0
    if count == 0 then return end

    local refresh = now >= s_NextRead
    if refresh then s_NextRead = now + READ_INTERVAL end

    for index = 1, count do
        local name = s_Shown[index].Name
        if refresh or values[name] == nil then values[name] = quests:GetFactStr(name) end
        s_Shown[index] = nil
    end
end

function GameFacts.Reset()
    s_ShownCount = 0
    s_NextRead = 0
end

return GameFacts
