local Notify = require("Utils/Notify")
local GameFacts = require("Features/World/GameFacts")

local Facts = {
    Values = {},
    Pending = {},
    Custom = { Name = "", Value = nil }
}

Facts.Categories = {
    {
        Key = "romance",
        Facts = {
            { Key = "judyromanceable", Name = "judy_romanceable" },
            { Key = "riverromanceable", Name = "river_romanceable" },
            { Key = "kerryromanceable", Name = "kerry_romanceable" },
            { Key = "judylover", Name = "sq030_judy_lover" },
            { Key = "panamlover", Name = "sq027_panam_lover" },
            { Key = "riverlover", Name = "sq029_river_lover" },
            { Key = "kerrylover", Name = "sq028_kerry_relationship" },
            { Key = "judyending", Name = "q115_judy_romance_chosen", Risky = true },
            { Key = "panamending", Name = "q115_panam_romance_chosen", Risky = true },
            { Key = "riverending", Name = "q115_river_romance_chosen", Risky = true },
            { Key = "kerryending", Name = "q115_kerry_romance_chosen", Risky = true },
            { Key = "judyvisits", Name = "mq055_judy" },
            { Key = "panamvisits", Name = "mq055_panam" },
            { Key = "rivervisits", Name = "mq055_river" },
            { Key = "kerryvisits", Name = "mq055_kerry" },
            { Key = "meredith", Name = "q003_stout_sex_done" }
        }
    },
    {
        Key = "friends",
        Facts = {
            { Key = "judyfriend", Name = "sq030_friendship" },
            { Key = "kerryfriend", Name = "sq028_kerry_friend" },
            { Key = "riverfriend", Name = "sq021_sobchak_friend" },
            { Key = "helpedpanam", Name = "q103_helped_panam" },
            { Key = "roguedate", Name = "sq031_rogue_date_done" }
        }
    },
    {
        Key = "johnny",
        Facts = {
            { Key = "johnnyfriend", Name = "sq032_johnny_friend" },
            { Key = "roguemetjohnny", Name = "sq031_rogue_met_johnny" },
            { Key = "jackiefamily", Name = "q005_jackie_to_mama" },
            { Key = "jackiedelamain", Name = "q005_jackie_stay_notell" },
            { Key = "mamawelles", Name = "sq018_01_mama_welles_talked" }
        }
    },
    {
        Key = "story",
        Facts = {
            { Key = "dumdumdead", Name = "q003_dumdum_dead" },
            { Key = "roycedead", Name = "q003_royce_dead", Risky = true },
            { Key = "bricksaved", Name = "q003_brick_saved", Risky = true },
            { Key = "mitchrescued", Name = "q104_mitch_rescued" },
            { Key = "woodmandead", Name = "q105_woodman_dead", Risky = true },
            { Key = "voodooqueendead", Name = "q110_voodoo_queen_dead" },
            { Key = "takemuradead", Name = "q112_takemura_dead" },
            { Key = "randysaved", Name = "sq021_randy_saved" },
            { Key = "weylandsaved", Name = "q115_jungle_weyland_saved", Risky = true },
            { Key = "solotower", Name = "q115_did_it_solo", Risky = true },
            { Key = "roguedead", Name = "q116_rogue_dead" }
        }
    },
    {
        Key = "sidejobs",
        Facts = {
            { Key = "peraleztruth", Name = "sq006_fact_truth_hurts" },
            { Key = "sampsondead", Name = "sq024_sampson_dead", Risky = true },
            {
                Key = "delamainfate",
                Name = "sq025_delamain_fate",
                Values = { { Value = 0, Key = "notset" }, { Value = 1, Key = "reset" }, { Value = 2, Key = "destroyed" }, { Value = 3, Key = "merged" } }
            },
            { Key = "maikodead", Name = "sq026_maiko_dead", Risky = true },
            { Key = "graysonkilled", Name = "sq031_grayson_killed" },
            { Key = "fortunateson", Name = "mq021_happy_ending" },
            { Key = "bratchampion", Name = "mq025_08_finale_player_wins" }
        }
    },
    {
        Key = "phantomliberty",
        Facts = {
            { Key = "songbirdpath", Name = "q304_songbirds_path", Values = { { Value = 0, Key = "reed" }, { Value = 1, Key = "songbird" } } },
            { Key = "kurtdead", Name = "q304_kurt_dead" },
            { Key = "kurtspared", Name = "q304_kurt_spared" },
            { Key = "alexdead", Name = "q304_alex_dead" },
            { Key = "songbirdalive", Name = "q305_songbird_alive" },
            { Key = "songbirddead", Name = "q305_fact_songbird_dead" },
            { Key = "somibetrayed", Name = "q306_somi_betrayed" },
            { Key = "reedkilled", Name = "q306_reed_killed" },
            { Key = "andersondead", Name = "sts_ep1_01_anderson_dead", Risky = true },
            { Key = "wagnerdead", Name = "sts_ep1_03_wagner_dead", Risky = true },
            { Key = "dodgerdead", Name = "sts_ep1_10_dodger_dead", Risky = true },
            { Key = "milkodead", Name = "sts_ep1_12_milko_dead", Risky = true }
        }
    },
    {
        Key = "unlocks",
        Facts = {
            { Key = "crystalcoat", Name = "vvc_visual_customization_unlocked" },
            { Key = "crystalcoatall", Name = "vvc_visual_customization_for_all_vehicles" },
            { Key = "relictree", Name = "ep1_tree_unlocked" },
            { Key = "creole", Name = "creole_translator_unlocked" },
            { Key = "nibbles", Name = "nibbles_unlocked" },
            { Key = "apartmentdowntown", Name = "dlc6_apart_cct_dtn_purchased", Risky = true },
            { Key = "apartmentglen", Name = "dlc6_apart_hey_gle_purchased", Risky = true },
            { Key = "apartmentnorthside", Name = "dlc6_apart_wat_nid_purchased", Risky = true },
            { Key = "apartmentjapantown", Name = "dlc6_apart_wbr_jpn_purchased", Risky = true }
        }
    },
    {
        Key = "censorship",
        Facts = {
            { Key = "nudity", Name = "censorship_nudity" },
            { Key = "suggestive", Name = "censorship_suggestive" },
            { Key = "oversexualized", Name = "censorship_oversexualized" },
            { Key = "gore", Name = "censorship_gore" },
            { Key = "drugs", Name = "censorship_drugs" },
            { Key = "religion", Name = "censorship_religion" },
            { Key = "samesex", Name = "censorship_homosexuality" }
        }
    }
}

local REFRESH_INTERVAL = 0.5
local WATCH_TIME = 1
local MAX_NAME = 128

local s_Queue = {}
local s_WatchUntil = 0
local s_NextRefresh = 0

function Facts.Watch()
    local now = os.clock()
    if now > s_WatchUntil then Notify.Warning(L("notify.world.factssave"), 6) end
    s_WatchUntil = now + WATCH_TIME
end

local function Valid(name)
    return type(name) == "string" and name ~= "" and #name <= MAX_NAME and name:match("^[%w_%-%.#%+ ]+$") ~= nil
end

function Facts.ValidName(name)
    return Valid(name)
end

function Facts.SetCustomName(name)
    Facts.Custom.Name = name or ""
    Facts.Custom.Value = nil
    s_NextRefresh = 0
end

function Facts.Set(name, value)
    if not Valid(name) then return end
    value = math.floor(tonumber(value) or 0)
    Facts.Values[name] = value
    Facts.Pending[name] = nil
    if name == Facts.Custom.Name then Facts.Custom.Value = value end
    table.insert(s_Queue, { Name = name, Value = value })
end

function Facts.Shown(name)
    local pending = Facts.Pending[name]
    if pending then return pending end
    return Facts.Values[name] or 0
end

function Facts.SetPending(name, value)
    if value == (Facts.Values[name] or 0) then
        Facts.Pending[name] = nil
        return
    end
    Facts.Pending[name] = value
end

function Facts.Apply(name)
    local pending = Facts.Pending[name]
    if pending then
        Facts.Set(name, pending)
        return
    end
    Facts.Set(name, (Facts.Values[name] or 0) > 0 and 0 or 1)
end

local function Write(quests, entry)
    quests:SetFactStr(entry.Name, entry.Value)
    local value = quests:GetFactStr(entry.Name)
    Facts.Values[entry.Name] = value

    if value == entry.Value then
        Notify.Success(tip("notify.world.factset", { name = entry.Name, value = value }))
    else
        Notify.Error(tip("notify.world.factfailed", { name = entry.Name }))
    end
end

local function Refresh(quests)
    for _, category in ipairs(Facts.Categories) do
        for _, fact in ipairs(category.Facts) do
            Facts.Values[fact.Name] = quests:GetFactStr(fact.Name)
        end
    end

    local custom = Facts.Custom
    if Valid(custom.Name) then
        custom.Value = quests:GetFactStr(custom.Name)
    else
        custom.Value = nil
    end
end

function Facts.Update(now)
    if now >= s_WatchUntil and #s_Queue == 0 and not GameFacts.Busy() then return end

    GameFacts.Load()

    local quests = Game.GetQuestsSystem()
    if not quests then return end

    local queue = s_Queue
    s_Queue = {}
    for _, entry in ipairs(queue) do Write(quests, entry) end

    GameFacts.Update(quests, now, Facts.Values)

    if #queue == 0 and now < s_NextRefresh then return end
    s_NextRefresh = now + REFRESH_INTERVAL
    Refresh(quests)
end

function Facts.Reset()
    s_Queue = {}
    s_NextRefresh = 0
    Facts.Values = {}
    Facts.Pending = {}
    Facts.Custom.Value = nil
    GameFacts.Reset()
end

function Facts.Shutdown()
    s_Queue = {}
end

return Facts
