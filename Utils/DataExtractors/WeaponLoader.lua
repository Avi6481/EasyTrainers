local Logger = require("Core/Logger")
local DataUtils = require("Utils/DataExtractors/DataUtils")

local RARITY_WEIGHT = {
    iconic = 9,
    ["legendary++"] = 8,
    ["legendary+"] = 7,
    legendary = 6,
    epic = 5,
    rare = 4,
    uncommon = 3,
    common = 2,
    base = 1
}

local TYPE_PATTERNS = {
    { "chainsword", "Chainsword" },
    { "rifle assault", "Assault Rifle" },
    { "rifle precision", "Precision Rifle" },
    { "handgun", "Handgun" },
    { "revolver", "Revolver" },
    { "smg", "SMG" },
    { "sniper", "Sniper" },
    { "shotgun", "Shotgun" },
    { "lmg", "LMG" },
    { "hmg", "Heavy Machine Gun" },
    { "katana", "Katana" },
    { "machete", "Machete" },
    { "knife", "Knife" },
    { "blade", "Blade" },
    { "blunt", "Blunt" },
    { "cyberware", "Cyberware Melee" },
    { "meleeweapon", "Melee" }
}

local RARITY_PATTERNS = {
    { "legendaryplusplus", "Legendary++" },
    { "legendaryplus", "Legendary+" },
    { "legendary", "Legendary" },
    { "epic", "Epic" },
    { "uncommon", "Uncommon" },
    { "rare", "Rare" },
    { "common", "Common" },
    { "base", "Base" }
}

local WALL_WEAPONS = {
    ["Items.Preset_Grad_Panam"] = true,
    ["Items.Preset_Carnage_Mox"] = true,
    ["Items.Preset_Nue_Jackie"] = true,
    ["Items.Preset_Katana_Saburo"] = true,
    ["Items.Preset_Katana_Takemura"] = true,
    ["Items.Preset_Overture_Kerry"] = true,
    ["Items.Preset_Liberty_Dex"] = true,
    ["Items.Preset_Ajax_Moron"] = true,
    ["Items.Preset_Copperhead_Genesis"] = true,
    ["Items.Preset_Tactician_Headsman"] = true,
    ["Items.Preset_Pulsar_Buzzsaw"] = true,
    ["Items.Preset_Igla_Sovereign"] = true,
    ["Items.Preset_Dian_Yinglong"] = true,
    ["Items.Preset_Nekomata_Breakthrough"] = true,
    ["Items.Preset_Burya_Comrade"] = true,
    ["Items.Preset_Zhuo_Eight_Star"] = true,
    ["Items.mq007_skippy"] = true,
    ["Items.Preset_Silverhand_3516"] = true,
    ["Items.sq029_rivers_gun"] = true
}

local WeaponLoader = {
    weapons = {},
    indexById = {}
}

local function MatchPattern(patterns, text)
    for _, pattern in ipairs(patterns) do
        if text:find(pattern[1], 1, true) then return pattern[2] end
    end
    return nil
end

local function GetType(tags)
    local isRanged = false
    for _, pattern in ipairs(TYPE_PATTERNS) do
        for _, tag in ipairs(tags) do
            if tag:lower():find(pattern[1], 1, true) then return pattern[2] end
        end
    end

    for _, tag in ipairs(tags) do
        if tag:lower() == "rangedweapon" then isRanged = true end
    end
    return isRanged and "Ranged" or "Miscellaneous"
end

local function GetRarity(id, record)
    local quality = DataUtils.SafeCall(function() return record:Quality():Type().value end) or ""
    quality = quality:lower()

    return MatchPattern(RARITY_PATTERNS, quality)
        or MatchPattern(RARITY_PATTERNS, id:lower())
        or (quality ~= "" and quality or "Standard")
end

local EVOLUTION_NAMES = { Power = "Power", Smart = "Smart", Tech = "Tech", Blade = "Blade", Blunt = "Blunt" }

local function GetEvolution(record)
    local evolution = DataUtils.SafeCall(function() return record:Evolution():Type().value end)
    return evolution and EVOLUTION_NAMES[evolution] or nil
end

local function BuildWeapon(id, record)
    local tags = DataUtils.GetTags(record)
    return {
        id = id,
        displayName = DataUtils.EscapeString(DataUtils.SafeCall(function()
            return Game.GetLocalizedTextByKey(record:DisplayName())
        end) or "Unknown"),
        type = GetType(tags),
        rarity = GetRarity(id, record),
        manufacturer = DataUtils.EscapeString(DataUtils.SafeCall(function()
            return record:Manufacturer():Name()
        end) or "Unlisted"),
        iconic = DataUtils.HasTag(tags, "iconicweapon"),
        isTech = DataUtils.HasTag(tags, "techweapon"),
        isSmart = DataUtils.HasTag(tags, "smartweapon"),
        isPower = DataUtils.HasTag(tags, "powerweapon"),
        onWall = WALL_WEAPONS[id] == true,
        evolution = GetEvolution(record),
        tags = tags
    }
end

function WeaponLoader:LoadAll()
    self.weapons = {}
    self.indexById = {}

    local records = TweakDB:GetRecords("gamedataWeaponItem_Record")
    if not records or #records == 0 then
        Logger.Log("WeaponLoader: no weapon records found")
        return
    end

    for _, record in ipairs(records) do
        local id = DataUtils.SafeCall(function() return record:GetID().value end)
        if id and id:find("^Items%.") and not self.indexById[id] then
            local weapon = BuildWeapon(id, record)
            if weapon.displayName ~= "Unknown" then
                table.insert(self.weapons, weapon)
                self.indexById[id] = weapon
            end
        end
    end

    Logger.Log(string.format("WeaponLoader: loaded %d weapons", #self.weapons))
end

function WeaponLoader:GetDescription(weapon)
    if weapon.description ~= nil then return weapon.description end

    local record = TweakDB:GetRecord(weapon.id)
    local key = record and DataUtils.SafeCall(function() return record:LocalizedDescription() end)
    local text = key and DataUtils.GetLocalizedSafe(key) or ""
    weapon.description = (text:gsub("<.->", ""))
    return weapon.description
end

function WeaponLoader:GetAll()
    return self.weapons
end

function WeaponLoader:GetById(id)
    return self.indexById[id]
end

function WeaponLoader:Filter(predicate)
    local result = {}
    for _, weapon in ipairs(self.weapons) do
        if predicate(weapon) then table.insert(result, weapon) end
    end
    return result
end

function WeaponLoader:GetByCategory(category, options)
    options = options or {}
    return self:Filter(function(weapon)
        if weapon.type ~= category then return false end
        if options.tech == false and weapon.isTech then return false end
        if options.smart == false and weapon.isSmart then return false end
        if options.power == false and weapon.isPower then return false end
        return true
    end)
end

function WeaponLoader:GetByRarity(rarity)
    local wanted = (rarity or ""):lower()
    return self:Filter(function(weapon) return (weapon.rarity or ""):lower() == wanted end)
end

local function UniqueSorted(weapons, field)
    local seen = {}
    local values = {}
    for _, weapon in ipairs(weapons) do
        local value = weapon[field]
        local key = tostring(value):lower()
        if value and not seen[key] then
            seen[key] = true
            table.insert(values, value)
        end
    end
    table.sort(values)
    return values
end

function WeaponLoader:GetAllRarities()
    return UniqueSorted(self.weapons, "rarity")
end

function WeaponLoader:GetTypes()
    return UniqueSorted(self.weapons, "type")
end

function WeaponLoader:GetRarityWeight(weapon)
    if weapon.iconic then return RARITY_WEIGHT.iconic end
    return RARITY_WEIGHT[(weapon.rarity or ""):lower()] or 0
end

function WeaponLoader:GetWall()
    return self:Filter(function(weapon) return weapon.onWall end)
end

function WeaponLoader:GetIconic()
    return self:Filter(function(weapon) return weapon.iconic end)
end

return WeaponLoader
