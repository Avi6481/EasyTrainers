local StatModifiers = require("Utils/StatModifiers")
local Weapon = require("Utils/Weapon")
local PresetStore = require("Utils/PresetStore")

local WeaponTuning = { Name = "WeaponTuning" }
local LEFT_OWNER = { Name = "WeaponTuning.Left" }

WeaponTuning.Enabled = { value = false }
WeaponTuning.Damage = { value = 100, min = 10, max = 1000, step = 10, unit = "%" }
WeaponTuning.FireRate = { value = 100, min = 25, max = 500, step = 25, unit = "%" }
WeaponTuning.ReloadSpeed = { value = 100, min = 25, max = 1000, step = 25, unit = "%" }
WeaponTuning.ExtraMagazine = { value = 0, min = 0, max = 500, step = 5, unit = "rds" }
WeaponTuning.Recoil = { value = 100, min = 0, max = 200, step = 10, unit = "%" }
WeaponTuning.Spread = { value = 100, min = 0, max = 200, step = 10, unit = "%" }
WeaponTuning.Range = { value = 100, min = 50, max = 1000, step = 25, unit = "%" }
WeaponTuning.CritChance = { value = 0, min = 0, max = 100, step = 5, unit = "%" }
WeaponTuning.CritDamage = { value = 0, min = 0, max = 1000, step = 25, unit = "%" }
WeaponTuning.HeadshotBonus = { value = 0, min = 0, max = 1000, step = 25, unit = "%" }
WeaponTuning.ExtraPellets = { value = 0, min = 0, max = 20, step = 1, unit = "pellets" }

local STATS_INTERVAL = 0.25

local s_LastValues = {}
local s_ValuesVersion = 0
local s_Stats = nil
local s_NextStats = 0

local ADD = gameStatModifierType.Additive
local MULTIPLY = gameStatModifierType.Multiplier
local STAT = gamedataStatType

local TUNABLES = {
    { Ref = WeaponTuning.Damage, Default = 100, Build = function(value) return { { STAT.DamagePerHit, MULTIPLY, value / 100 } } end },
    { Ref = WeaponTuning.FireRate, Default = 100, Build = function(value) return { { STAT.CycleTime, MULTIPLY, 100 / value } } end },
    { Ref = WeaponTuning.ReloadSpeed, Default = 100, Build = function(value)
        local scale = 100 / value
        return {
            { STAT.ReloadTimeBase, MULTIPLY, scale },
            { STAT.ReloadEndTime, MULTIPLY, scale },
            { STAT.EmptyReloadTime, MULTIPLY, scale },
            { STAT.EmptyReloadEndTime, MULTIPLY, scale }
        }
    end },
    { Ref = WeaponTuning.ExtraMagazine, Default = 0, Build = function(value) return { { STAT.MagazineCapacityBase, ADD, value } } end },
    { Ref = WeaponTuning.Recoil, Default = 100, Build = function(value)
        local scale = value / 100
        return { { STAT.RecoilKickMin, MULTIPLY, scale }, { STAT.RecoilKickMax, MULTIPLY, scale } }
    end },
    { Ref = WeaponTuning.Spread, Default = 100, Build = function(value)
        local scale = value / 100
        return {
            { STAT.SpreadMinX, MULTIPLY, scale }, { STAT.SpreadMinY, MULTIPLY, scale },
            { STAT.SpreadMaxX, MULTIPLY, scale }, { STAT.SpreadMaxY, MULTIPLY, scale },
            { STAT.SpreadAdsMinX, MULTIPLY, scale }, { STAT.SpreadAdsMinY, MULTIPLY, scale },
            { STAT.SpreadAdsMaxX, MULTIPLY, scale }, { STAT.SpreadAdsMaxY, MULTIPLY, scale }
        }
    end },
    { Ref = WeaponTuning.Range, Default = 100, Build = function(value)
        local scale = value / 100
        return { { STAT.EffectiveRange, MULTIPLY, scale }, { STAT.MaximumRange, MULTIPLY, scale } }
    end },
    { Ref = WeaponTuning.CritChance, Default = 0, Build = function(value) return { { STAT.CritChance, ADD, value } } end },
    { Ref = WeaponTuning.CritDamage, Default = 0, Build = function(value) return { { STAT.CritDamage, ADD, value } } end },
    { Ref = WeaponTuning.HeadshotBonus, Default = 0, Build = function(value) return { { STAT.HeadshotDamageMultiplier, ADD, value / 100 } } end },
    { Ref = WeaponTuning.ExtraPellets, Default = 0, Build = function(value) return { { STAT.ProjectilesPerShot, ADD, value } } end }
}

WeaponTuning.Presets = PresetStore.Create("Config/JSON/WeaponTuningPresets.json", {
    Damage = WeaponTuning.Damage,
    FireRate = WeaponTuning.FireRate,
    ReloadSpeed = WeaponTuning.ReloadSpeed,
    ExtraMagazine = WeaponTuning.ExtraMagazine,
    Recoil = WeaponTuning.Recoil,
    Spread = WeaponTuning.Spread,
    Range = WeaponTuning.Range,
    CritChance = WeaponTuning.CritChance,
    CritDamage = WeaponTuning.CritDamage,
    HeadshotBonus = WeaponTuning.HeadshotBonus,
    ExtraPellets = WeaponTuning.ExtraPellets
})

local function ValuesVersion()
    for index, tunable in ipairs(TUNABLES) do
        if s_LastValues[index] ~= tunable.Ref.value then
            for copyIndex, copy in ipairs(TUNABLES) do s_LastValues[copyIndex] = copy.Ref.value end
            s_ValuesVersion = s_ValuesVersion + 1
            break
        end
    end
    return s_ValuesVersion
end

local function BuildModifiers()
    local modifiers = {}
    for _, tunable in ipairs(TUNABLES) do
        if tunable.Ref.value ~= tunable.Default then
            for _, modifier in ipairs(tunable.Build(tunable.Ref.value)) do table.insert(modifiers, modifier) end
        end
    end
    return modifiers
end

function WeaponTuning.IsActive()
    return WeaponTuning.Enabled.value or StatModifiers.IsApplied(WeaponTuning) or StatModifiers.IsApplied(LEFT_OWNER)
end

local function SyncLeft(version)
    local itemKey = Weapon.GetLeftItemKey()
    if not WeaponTuning.Enabled.value or not itemKey or not Weapon.IsLeftRangedEquipped() then
        StatModifiers.Sync(LEFT_OWNER, false)
        return
    end

    local applied = StatModifiers.GetKey(LEFT_OWNER)
    if applied and applied.Item == itemKey and applied.Version == version then return end

    local _, itemData = Weapon.GetEquippedLeftHand()
    local statsID = itemData and itemData:GetStatsObjectID() or nil
    if not statsID then return end
    StatModifiers.Add(LEFT_OWNER, statsID, { Item = itemKey, Version = version }, BuildModifiers())
end

function WeaponTuning.Tick()
    local itemKey = Weapon.GetCurrentItemKey()
    local version = ValuesVersion()
    SyncLeft(version)

    if not WeaponTuning.Enabled.value or not itemKey then
        StatModifiers.Sync(WeaponTuning, false)
        return
    end

    local applied = StatModifiers.GetKey(WeaponTuning)
    if applied and applied.Item == itemKey and applied.Version == version then return end
    local key = { Item = itemKey, Version = version }

    local _, itemData = Weapon.GetEquippedRightHand()
    local statsID = itemData and itemData:GetStatsObjectID() or nil
    if not statsID then return end
    StatModifiers.Add(WeaponTuning, statsID, key, BuildModifiers())
end

local function StatValue(stats, statsID, stat)
    local ok, value = pcall(function() return stats:GetStatValue(statsID, stat) end)
    return ok and value or nil
end

local function ItemName(itemData)
    local ok, name = pcall(function() return itemData:GetNameAsString() end)
    return ok and name or "Current Weapon"
end

local function Stock(current, applied, compute)
    if not current then return nil end
    if not applied then return current end
    return compute(current)
end

local function ReadStats()
    local _, itemData = Weapon.GetEquippedRightHand()
    local statsID = itemData and itemData:GetStatsObjectID() or nil
    local stats = Game.GetStatsSystem()
    if not statsID or not stats then return nil end

    local applied = StatModifiers.IsApplied(WeaponTuning)
    local cycleTime = StatValue(stats, statsID, STAT.CycleTime)
    local result = {
        Name = ItemName(itemData),
        Ranged = Weapon.IsRangedEquipped(),
        Damage = StatValue(stats, statsID, STAT.DamagePerHit),
        FireRate = cycleTime and cycleTime > 0 and 1 / cycleTime or nil,
        Pellets = StatValue(stats, statsID, STAT.ProjectilesPerShot),
        Magazine = StatValue(stats, statsID, STAT.MagazineCapacity),
        Reload = StatValue(stats, statsID, STAT.ReloadTime),
        Range = StatValue(stats, statsID, STAT.EffectiveRange),
        CritChance = StatValue(stats, statsID, STAT.CritChance),
        CritDamage = StatValue(stats, statsID, STAT.CritDamage)
    }

    result.StockDamage = Stock(result.Damage, applied, function(value) return value / (WeaponTuning.Damage.value / 100) end)
    result.StockFireRate = Stock(result.FireRate, applied, function(value) return value / (WeaponTuning.FireRate.value / 100) end)
    result.StockMagazine = Stock(result.Magazine, applied, function(value) return value - WeaponTuning.ExtraMagazine.value end)
    result.StockReload = Stock(result.Reload, applied, function(value) return value * (WeaponTuning.ReloadSpeed.value / 100) end)
    result.StockRange = Stock(result.Range, applied, function(value) return value / (WeaponTuning.Range.value / 100) end)
    result.StockCritChance = Stock(result.CritChance, applied, function(value) return value - WeaponTuning.CritChance.value end)
    result.StockCritDamage = Stock(result.CritDamage, applied, function(value) return value - WeaponTuning.CritDamage.value end)

    local pellets = math.max(1, result.Pellets or 1)
    if result.Damage and result.FireRate then result.DPS = result.Damage * result.FireRate * pellets end
    if result.StockDamage and result.StockFireRate then
        result.StockDPS = result.StockDamage * result.StockFireRate * math.max(1, pellets - (applied and WeaponTuning.ExtraPellets.value or 0))
    end
    return result
end

function WeaponTuning.GetStats()
    local now = os.clock()
    if now < s_NextStats then return s_Stats end
    s_NextStats = now + STATS_INTERVAL
    s_Stats = ReadStats()
    return s_Stats
end

function WeaponTuning.ResetValues()
    for _, tunable in ipairs(TUNABLES) do tunable.Ref.value = tunable.Default end
end

return WeaponTuning
