local Logger = require("Core/Logger")

local Session = {}

local CHECK_INTERVAL = 0.25
local LOAD_TIMEOUT = 30

local s_Loaded = false
local s_Hud = false
local s_FirstCheck = true
local s_NewPlayer = false
local s_Loading = false
local s_LoadingUntil = 0
local s_NextCheck = 0
local s_Listeners = {}

local function PreGame()
    local ok, result = pcall(function()
        return GetSingleton("inkMenuScenario"):GetSystemRequestsHandler():IsPreGame()
    end)
    return ok and result == true
end

local function Loaded()
    local player = Game.GetPlayer()
    if not player or not player:IsAttached() then return false end
    return not PreGame()
end

local function Notify(loaded, reason)
    s_Loaded = loaded
    Logger.Log("Session " .. reason)
    for _, callback in ipairs(s_Listeners) do callback(loaded) end
end

local function End(reason)
    s_Loading = true
    s_LoadingUntil = os.clock() + LOAD_TIMEOUT
    if s_Loaded then Notify(false, reason) end
end

function Session.Initialize()
    Observe("PlayerPuppet", "OnGameAttached", function(player)
        if player:IsReplacer() then return end
        s_NewPlayer = true
    end)
    Observe("PlayerPuppet", "OnDetach", function(player)
        if player:IsReplacer() then return end
        End("ended (player detached)")
    end)
    Observe("LoadGameMenuGameController", "LoadSaveInGame", function()
        End("ended (loading a save)")
    end)
    Observe("LoadGameMenuGameController", "OnLoadSaveInGameCanceled", function()
        s_Loading = false
    end)
    Observe("QuestTrackerGameController", "OnInitialize", function() s_Hud = true end)
    Observe("QuestTrackerGameController", "OnUninitialize", function() s_Hud = false end)
end

function Session.Listen(callback)
    table.insert(s_Listeners, callback)
end

function Session.Update()
    local now = os.clock()
    if not s_NewPlayer and now < s_NextCheck then return end
    s_NextCheck = now + CHECK_INTERVAL

    local newPlayer = s_NewPlayer
    if newPlayer then
        s_NewPlayer = false
        s_Loading = false
    elseif s_Loading then
        if now < s_LoadingUntil then return end
        s_Loading = false
    end

    local loaded = Loaded()
    if s_FirstCheck then
        s_FirstCheck = false
        if loaded then s_Hud = true end
    end
    if newPlayer then
        Notify(loaded, "new player")
        return
    end

    if loaded ~= s_Loaded then Notify(loaded, loaded and "loaded" or "ended") end
end

function Session.IsLoaded()
    return s_Loaded
end

function Session.InGame()
    return s_Loaded and s_Hud
end

return Session
