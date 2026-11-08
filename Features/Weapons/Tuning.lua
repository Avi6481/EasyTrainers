local StatModifiers = require("Utils/StatModifiers")
local Weapon = require("Utils/Weapon")

local Tuning = {
    Enabled = false,
    Damage = 100,
    FireRate = 100,
    ReloadSpeed = 100,
    ExtraMagazine = 0,
    Recoil = 100,
    Spread = 100,
    Range = 100,
    CritChance = 0,
    CritDamage = 0,
    HeadshotBonus = 0,
    ExtraPellets = 0,
    Presets = {}
}

Tuning.Ranges = {
    Damage = { Stock = 100, Min = 10, Max = 1000, Step = 10 },
    FireRate = { Stock = 100, Min = 25, Max = 500, Step = 25 },
    ReloadSpeed = { Stock = 100, Min = 25, Max = 1000, Step = 25 },
    ExtraMagazine = { Stock = 0, Min = 0, Max = 500, Step = 5 },
    Recoil = { Stock = 100, Min = 0, Max = 200, Step = 10 },
    Spread = { Stock = 100, Min = 0, Max = 200, Step = 10 },
    Range = { Stock = 100, Min = 50, Max = 1000, Step = 25 },
    CritChance = { Stock = 0, Min = 0, Max = 100, Step = 5 },
    CritDamage = { Stock = 0, Min = 0, Max = 1000, Step = 25 },
    HeadshotBonus = { Stock = 0, Min = 0, Max = 1000, Step = 25 },
    ExtraPellets = { Stock = 0, Min = 0, Max = 20, Step = 1 }
}

local function Percent(value)
    return value / 100
end

local function Inverse(value)
    return 100 / value
end

local function Flat(value)
    return value
end

local TUNABLES = {
    { Name = "Damage", Scale = Percent, Stats = { "DamagePerHit" } },
    { Name = "FireRate", Scale = Inverse, Stats = { "CycleTime" } },
    { Name = "ReloadSpeed", Scale = Inverse, Stats = { "ReloadTimeBase", "ReloadEndTime", "EmptyReloadTime", "EmptyReloadEndTime" } },
    { Name = "ExtraMagazine", Add = true, Scale = Flat, Stats = { "MagazineCapacityBase" } },
    { Name = "Recoil", Scale = Percent, Stats = { "RecoilKickMin", "RecoilKickMax" } },
    {
        Name = "Spread",
        Scale = Percent,
        Stats = { "SpreadMinX", "SpreadMinY", "SpreadMaxX", "SpreadMaxY", "SpreadAdsMinX", "SpreadAdsMinY", "SpreadAdsMaxX", "SpreadAdsMaxY" }
    },
    { Name = "Range", Scale = Percent, Stats = { "EffectiveRange", "MaximumRange" } },
    { Name = "CritChance", Add = true, Scale = Flat, Stats = { "CritChance" } },
    { Name = "CritDamage", Add = true, Scale = Flat, Stats = { "CritDamage" } },
    { Name = "HeadshotBonus", Add = true, Scale = Percent, Stats = { "HeadshotDamageMultiplier" } },
    { Name = "ExtraPellets", Add = true, Scale = Flat, Stats = { "ProjectilesPerShot" } }
}

local SIDES = {
    { Name = "Right", Owner = "Weapons.Tuning.Right", RangedOnly = false },
    { Name = "Left", Owner = "Weapons.Tuning.Left", RangedOnly = true }
}

local STAT_KEYS = { "Damage", "FireRate", "Pellets", "Magazine", "Reload", "Range", "CritChance", "CritDamage", "DPS" }

local STATS_INTERVAL = 0.25
local WATCH_TIME = 1

local s_LastValues = {}
local s_ValuesVersion = 0
local s_Keys = { Right = {}, Left = {} }
local s_Live = { Right = false, Left = false }
local s_Stats = nil
local s_NextStats = 0
local s_WatchUntil = 0

local function Clamp(name, value)
    local range = Tuning.Ranges[name]
    value = tonumber(value) or range.Stock
    value = math.max(range.Min, math.min(range.Max, value))
    return math.floor(value + 0.5)
end

local function Value(name)
    return Clamp(name, Tuning[name])
end

local function Trim(text)
    return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function AddEntries(entries, tunable)
    local value = Value(tunable.Name)
    if value == Tuning.Ranges[tunable.Name].Stock then return end

    local kind = tunable.Add and gameStatModifierType.Additive or gameStatModifierType.Multiplier
    local amount = tunable.Scale(value)
    for _, stat in ipairs(tunable.Stats) do
        table.insert(entries, { gamedataStatType[stat], kind, amount })
    end
end

local function Build()
    local entries = {}
    for _, tunable in ipairs(TUNABLES) do AddEntries(entries, tunable) end
    return entries
end

local function ValuesVersion()
    for _, tunable in ipairs(TUNABLES) do
        if s_LastValues[tunable.Name] ~= Tuning[tunable.Name] then
            for _, copy in ipairs(TUNABLES) do s_LastValues[copy.Name] = Tuning[copy.Name] end
            s_ValuesVersion = s_ValuesVersion + 1
            return s_ValuesVersion
        end
    end
    return s_ValuesVersion
end

local function HandKey(state, hand, version)
    if state.Version ~= hand.Version or state.Values ~= version then
        state.Version = hand.Version
        state.Values = version
        state.Key = tostring(hand.Version) .. ":" .. tostring(version)
    end
    return state.Key
end

local function Wanted(side, hand)
    if not Tuning.Enabled or not hand.StatsID then return false end
    return hand.Ranged or not side.RangedOnly
end

local function SyncSide(side, version)
    local hand = Weapon[side.Name]
    local wanted = Wanted(side, hand)
    s_Live[side.Name] = wanted

    if not wanted then
        StatModifiers.Sync(side.Owner, false)
        return
    end

    StatModifiers.Sync(side.Owner, true, HandKey(s_Keys[side.Name], hand, version), hand.StatsID, Build)
end

local function GetStat(system, statsID, stat)
    return system:GetStatValue(statsID, gamedataStatType[stat])
end

local function Stat(system, statsID, stat)
    local ok, value = pcall(GetStat, system, statsID, stat)
    if ok and type(value) == "number" then return value end
    return nil
end

local function Scaled(value, factor)
    if not value then return nil end
    return value * factor
end

local function Offset(value, amount)
    if not value then return nil end
    return value - amount
end

local function Dps(stats)
    if not stats.Damage or not stats.FireRate then return nil end
    return stats.Damage * stats.FireRate * math.max(1, stats.Pellets or 1)
end

local function StockStats(stats, applied)
    local stock = {}
    for _, key in ipairs(STAT_KEYS) do stock[key] = stats[key] end
    if not applied then return stock end

    stock.Damage = Scaled(stats.Damage, 100 / Value("Damage"))
    stock.FireRate = Scaled(stats.FireRate, 100 / Value("FireRate"))
    stock.Reload = Scaled(stats.Reload, Value("ReloadSpeed") / 100)
    stock.Range = Scaled(stats.Range, 100 / Value("Range"))
    stock.Magazine = Offset(stats.Magazine, Value("ExtraMagazine"))
    stock.CritChance = Offset(stats.CritChance, Value("CritChance"))
    stock.CritDamage = Offset(stats.CritDamage, Value("CritDamage"))
    stock.Pellets = Offset(stats.Pellets, Value("ExtraPellets"))
    stock.DPS = Dps(stock)
    return stock
end

local function ReadStats(hand, applied)
    local statsID = hand.StatsID
    if not statsID then return nil end

    local system = Game.GetStatsSystem()
    if not system then return nil end

    local cycle = Stat(system, statsID, "CycleTime")
    local stats = {
        Name = Weapon.Name(hand),
        Ranged = hand.Ranged,
        Enabled = applied,
        Damage = Stat(system, statsID, "DamagePerHit"),
        FireRate = cycle and cycle > 0 and 1 / cycle or nil,
        Pellets = Stat(system, statsID, "ProjectilesPerShot"),
        Magazine = Stat(system, statsID, "MagazineCapacity"),
        Reload = Stat(system, statsID, "ReloadTime"),
        Range = Stat(system, statsID, "EffectiveRange"),
        CritChance = Stat(system, statsID, "CritChance"),
        CritDamage = Stat(system, statsID, "CritDamage")
    }
    stats.DPS = Dps(stats)
    stats.Stock = StockStats(stats, applied)
    return stats
end

local function SameStats(first, second)
    if not first or not second then return false end
    if first.Name ~= second.Name or first.Ranged ~= second.Ranged or first.Enabled ~= second.Enabled then return false end
    for _, key in ipairs(STAT_KEYS) do
        if first[key] ~= second[key] or first.Stock[key] ~= second.Stock[key] then return false end
    end
    return true
end

local function RefreshStats(now)
    if now < s_NextStats then return end
    s_NextStats = now + STATS_INTERVAL

    local stats = ReadStats(Weapon.Right, s_Live.Right)
    if not SameStats(stats, s_Stats) then s_Stats = stats end
end

local function Release()
    for _, side in ipairs(SIDES) do
        pcall(StatModifiers.Remove, side.Owner)
        s_Live[side.Name] = false
    end
end

function Tuning.Watch()
    s_WatchUntil = os.clock() + WATCH_TIME
end

function Tuning.Active()
    return Tuning.Enabled or s_Live.Right or s_Live.Left or os.clock() < s_WatchUntil
end

function Tuning.Stats()
    return s_Stats
end

function Tuning.ResetValues()
    for _, tunable in ipairs(TUNABLES) do Tuning[tunable.Name] = Tuning.Ranges[tunable.Name].Stock end
end

function Tuning.SavePreset(name)
    name = Trim(name)
    if name == "" then name = tip("weapons.tuning.presets.default", { count = #Tuning.Presets + 1 }) end

    local values = {}
    for _, tunable in ipairs(TUNABLES) do values[tunable.Name] = Value(tunable.Name) end
    table.insert(Tuning.Presets, { Name = name, Values = values })
    return name
end

function Tuning.LoadPreset(preset)
    local values = type(preset) == "table" and preset.Values or nil
    if type(values) ~= "table" then return end

    for _, tunable in ipairs(TUNABLES) do
        if values[tunable.Name] ~= nil then Tuning[tunable.Name] = Clamp(tunable.Name, values[tunable.Name]) end
    end
end

function Tuning.DeletePreset(preset)
    for index, saved in ipairs(Tuning.Presets) do
        if saved == preset then
            table.remove(Tuning.Presets, index)
            return
        end
    end
end

function Tuning.Update(_, now)
    local version = ValuesVersion()
    for _, side in ipairs(SIDES) do SyncSide(side, version) end
    if now < s_WatchUntil then RefreshStats(now) end
end

function Tuning.Reset()
    Release()
    s_Keys = { Right = {}, Left = {} }
    s_Stats = nil
    s_NextStats = 0
end

function Tuning.Shutdown()
    Release()
end

return Tuning
