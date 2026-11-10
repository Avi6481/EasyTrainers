local StatModifiers = require("Utils/StatModifiers")

local Armor = {
    Enabled = false,
    Amount = 200,
    Min = 50,
    Max = 1000
}

local OWNER = "Armor"
local INTERVAL = 0.5

local s_Next = 0
local s_Reduction = nil

local function Build()
    return { { gamedataStatType.Armor, gameStatModifierType.Additive, Armor.Amount } }
end

local function Measure(player)
    local stats = Game.GetStatsSystem()
    local data = Game.GetStatsDataSystem()
    if not stats or not data then return nil end

    local id = player:GetEntityID()
    local armor = stats:GetStatValue(id, gamedataStatType.Armor)
    local effectiveness = data:GetArmorEffectivenessValue(true) * stats:GetStatValue(id, gamedataStatType.ArmorEffectivenessMultiplier)
    if armor <= 0 or effectiveness <= 0 then return 0 end
    return (1 - 1 / (1 + armor * effectiveness)) * 100
end

function Armor.Reduction()
    return s_Reduction
end

function Armor.Update(player)
    Armor.Amount = math.max(Armor.Min, math.min(Armor.Max, Armor.Amount))
    StatModifiers.Sync(OWNER, Armor.Enabled, Armor.Amount, player:GetEntityID(), Build)

    local now = os.clock()
    if now < s_Next then return end
    s_Next = now + INTERVAL

    local ok, value = pcall(Measure, player)
    s_Reduction = ok and value or nil
end

function Armor.Reset()
    s_Reduction = nil
end

return Armor
