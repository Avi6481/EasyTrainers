local GameText = require("Utils/GameText")
local Logger = require("Core/Logger")

local Catalog = {
    Loaded = false,
    Version = 0,
    All = {},
    ByRecord = {},
    Types = {},
    ByType = {},
    Iconic = {},
    Wall = {}
}

Catalog.CLASSES = { "Power", "Tech", "Smart", "Blade", "Blunt" }

local ICONS = "Assets/Icons/WeaponIcons"
local STANDARD = "Standard"
local UNLISTED = "Unlisted"
local RANGED = "Ranged"
local MISCELLANEOUS = "Miscellaneous"
local MISSING = "Label Not Found"

local TIER_WEIGHTS = {
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

local TYPES = {
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

local TIERS = {
    { "legendaryplusplus", "Legendary++" },
    { "legendaryplus", "Legendary+" },
    { "legendary", "Legendary" },
    { "epic", "Epic" },
    { "uncommon", "Uncommon" },
    { "rare", "Rare" },
    { "common", "Common" },
    { "base", "Base" }
}

local EVOLUTIONS = { Power = "Power", Smart = "Smart", Tech = "Tech", Blade = "Blade", Blunt = "Blunt" }

local CLASS_TAGS = {
    { "smartweapon", "Smart" },
    { "techweapon", "Tech" },
    { "powerweapon", "Power" }
}

local WALL = {
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

local s_Icons = nil
local s_Resolver = nil
local s_Manufacturers = {}

local function Call(callback)
    local ok, result = pcall(callback)
    if ok then return result end
    return nil
end

local function Text(value)
    if type(value) == "string" then return value end
    if value == nil then return "" end
    local text = Call(function() return value.value end) or Call(function() return Game.NameToString(value) end)
    if type(text) ~= "string" or text == "None" then return "" end
    return text
end

local function Match(patterns, text)
    for _, pattern in ipairs(patterns) do
        if text:find(pattern[1], 1, true) then return pattern[2] end
    end
    return nil
end

local function Tags(record)
    local list = {}
    local set = {}
    for _, tag in ipairs(Call(function() return record:Tags() end) or {}) do
        local value = Call(function() return tag.value end)
        if value then
            local lower = value:lower()
            table.insert(list, lower)
            set[lower] = true
        end
    end
    return list, set
end

local function TypeOf(list, set)
    for _, pattern in ipairs(TYPES) do
        for _, tag in ipairs(list) do
            if tag:find(pattern[1], 1, true) then return pattern[2] end
        end
    end
    return set.rangedweapon and RANGED or MISCELLANEOUS
end

local function TierOf(id, record)
    local quality = Call(function() return record:Quality():Type().value end)
    quality = type(quality) == "string" and quality:lower() or ""

    local tier = Match(TIERS, quality) or Match(TIERS, id:lower())
    if tier then return tier end
    if quality == "" then return STANDARD end
    return quality:sub(1, 1):upper() .. quality:sub(2)
end

local function ClassOf(record, set)
    local evolution = Call(function() return record:Evolution():Type().value end)
    if evolution and EVOLUTIONS[evolution] then return EVOLUTIONS[evolution] end

    for _, pattern in ipairs(CLASS_TAGS) do
        if set[pattern[1]] then return pattern[2] end
    end
    return nil
end

local function ManufacturerOf(record)
    local name = Call(function() return record:Manufacturer():Name() end)
    if type(name) ~= "string" or name == "" then return UNLISTED end

    local shown = s_Manufacturers[name]
    if shown then return shown end

    shown = GameText.Get(name, name)
    if shown == "" or shown == MISSING then shown = UNLISTED end
    s_Manufacturers[name] = shown
    return shown
end

local function NameOf(record)
    local key = Call(function() return record:DisplayName() end)
    local name = key and GameText.FromName(key, nil)
    if not name or name == "" or name == MISSING then return nil end
    return name
end

local function RecordId(record)
    return Call(function() return record:GetID().value end)
end

function Catalog.Weight(tier)
    return TIER_WEIGHTS[tostring(tier or ""):lower()] or 0
end

local function Build(id, record, name)
    local list, set = Tags(record)
    local tier = TierOf(id, record)
    local iconic = set.iconicweapon == true

    return {
        Id = id,
        Name = name,
        Order = name:lower(),
        Search = (name .. " " .. id):lower(),
        Type = TypeOf(list, set),
        Tier = tier,
        Class = ClassOf(record, set),
        Manufacturer = ManufacturerOf(record),
        Iconic = iconic,
        Wall = WALL[id] == true,
        Weight = iconic and TIER_WEIGHTS.iconic or Catalog.Weight(tier),
        Icon = nil,
        Description = nil,
        Resolved = false
    }
end

local function ByName(first, second)
    if first.Order ~= second.Order then return first.Order < second.Order end
    return first.Id < second.Id
end

local function Group(weapon)
    local list = Catalog.ByType[weapon.Type]
    if not list then
        list = {}
        Catalog.ByType[weapon.Type] = list
        table.insert(Catalog.Types, weapon.Type)
    end
    table.insert(list, weapon)
    if weapon.Iconic then table.insert(Catalog.Iconic, weapon) end
    if weapon.Wall then table.insert(Catalog.Wall, weapon) end
end

function Catalog.Load()
    Catalog.Loaded = true
    Catalog.All = {}
    Catalog.ByRecord = {}
    Catalog.Types = {}
    Catalog.ByType = {}
    Catalog.Iconic = {}
    Catalog.Wall = {}
    s_Manufacturers = {}

    for _, record in ipairs(TweakDB:GetRecords("gamedataWeaponItem_Record") or {}) do
        local id = RecordId(record)
        local name = id and id:find("^Items%.") and not Catalog.ByRecord[id] and NameOf(record)
        if name then
            local weapon = Build(id, record, name)
            table.insert(Catalog.All, weapon)
            Catalog.ByRecord[id] = weapon
        end
    end

    table.sort(Catalog.All, ByName)
    for _, weapon in ipairs(Catalog.All) do Group(weapon) end
    table.sort(Catalog.Types)
    Catalog.Version = Catalog.Version + 1

    Logger.Log(string.format("Weapons: %d weapons, %d types, %d iconic, %d stash wall",
        #Catalog.All, #Catalog.Types, #Catalog.Iconic, #Catalog.Wall))
end

local function Icons()
    if s_Icons then return s_Icons end

    local ok, manifest = pcall(require, ICONS)
    s_Icons = { Sheets = {}, Parts = {} }
    if ok and type(manifest) == "table" then
        s_Icons = manifest
    else
        Logger.Log("Weapons: couldn't load the icon manifest")
    end
    return s_Icons
end

local function Resolver()
    if s_Resolver == nil then s_Resolver = Call(function() return IconsNameResolver.GetIconsNameResolver() end) or false end
    return s_Resolver or nil
end

local function ItemPart(record, id)
    local icon = Text(Call(function() return record:IconPath() end))
    if icon == "" then
        local resolver = Resolver()
        if resolver then icon = Text(Call(function() return resolver:TranslateItemToIconName(TweakDBID.new(id), false) end)) end
    end
    if icon == "" then return "" end

    local part = Text(Call(function() return TweakDB:GetFlat("UIIcon." .. icon .. ".atlasPartName") end))
    return part ~= "" and part or icon
end

local function RecordPart(record)
    local icon = Call(function() return record:Icon() end)
    return icon and Text(Call(function() return icon:AtlasPartName() end)) or ""
end

local function Part(record, id)
    local parts = Icons().Parts
    local first = ItemPart(record, id)
    if parts[first] then return parts[first] end

    local second = RecordPart(record)
    return parts[second]
end

local function Image(entry)
    return {
        Sheet = Icons().Sheets[entry[1]],
        U0 = entry[2],
        V0 = entry[3],
        U1 = entry[4],
        V1 = entry[5],
        Width = entry[6],
        Height = entry[7]
    }
end

local function Describe(record)
    local key = Call(function() return record:LocalizedDescription() end)
    local text = key and GameText.FromName(key, nil)
    if not text or text == MISSING then return "" end
    return (text:gsub("<.->", ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function Catalog.Resolve(weapon)
    if not weapon or weapon.Resolved then return end
    weapon.Resolved = true

    local record = TweakDB:GetRecord(weapon.Id)
    if not record then
        weapon.Icon = false
        weapon.Description = ""
        return
    end

    local entry = Part(record, weapon.Id)
    weapon.Icon = entry and Image(entry) or false
    weapon.Description = Describe(record)
end

return Catalog
