local GameText = require("Utils/GameText")
local Logger = require("Core/Logger")
local Notify = require("Utils/Notify")

local Catalog = {
    Loaded = false,
    Version = 0,
    Progress = 0,
    All = {},
    ByRecord = {},
    Categories = {},
    Lists = {}
}

Catalog.STANDARD = "Standard"

local ICONS = "Assets/Icons/ItemIcons"
local MISSING = "Label Not Found"
local STEP_TIME = 0.006
local CHECK_EVERY = 16
local RECIPES = "gamedataItemRecipe_Record"

local RECORD_TYPES = {
    RECIPES,
    "gamedataGrenade_Record",
    "gamedataGadget_Record",
    "gamedataConsumableItem_Record",
    "gamedataClothing_Record",
    "gamedataItem_Record"
}

local QUALITY_WEIGHT = {
    Common = 1, CommonPlus = 1.5, Uncommon = 2, UncommonPlus = 2.5, Rare = 3, RarePlus = 3.5,
    Epic = 4, EpicPlus = 4.5, Legendary = 5, LegendaryPlus = 5.5, LegendaryPlusPlus = 5.8, Iconic = 6
}

local CATEGORIES = {
    "consumables", "crafting", "clothing", "cyberware", "mods", "quickhacks", "recipes",
    "progression", "rewards", "quest", "readables", "misc", "advanced"
}

local TYPES = {
    Con_Edible = { "consumables", "food" },
    Con_Inhaler = { "consumables", "inhalers" },
    Con_Injector = { "consumables", "injectors" },
    Con_LongLasting = { "consumables", "boosters" },
    Con_Ammo = { "consumables", "ammo" },
    Gad_Grenade = { "consumables", "grenades" },
    Prt_GrenadeCore = { "crafting", "grenadeparts" },
    Prt_DeliveryMethod = { "crafting", "grenadeparts" },
    Clo_Head = { "clothing", "head" },
    Clo_Face = { "clothing", "face" },
    Clo_OuterChest = { "clothing", "outerchest" },
    Clo_InnerChest = { "clothing", "innerchest" },
    Clo_Legs = { "clothing", "legs" },
    Clo_Feet = { "clothing", "feet" },
    Clo_Outfit = { "clothing", "outfits" },
    Prt_Fragment = { "cyberware", "cyberwaremods" },
    Prt_Program = { "quickhacks", "quickhacks" },
    Prt_Muzzle = { "mods", "muzzles" },
    Prt_HandgunMuzzle = { "mods", "muzzles" },
    Prt_RifleMuzzle = { "mods", "muzzles" },
    Prt_Scope = { "mods", "scopes" },
    Prt_ShortScope = { "mods", "scopes" },
    Prt_LongScope = { "mods", "scopes" },
    Prt_TechSniperScope = { "mods", "scopes" },
    Prt_PowerSniperScope = { "mods", "scopes" },
    Prt_Magazine = { "mods", "parts" },
    Prt_Stock = { "mods", "parts" },
    Prt_TargetingSystem = { "mods", "parts" },
    Prt_ScopeRail = { "mods", "parts" },
    Prt_Receiver = { "mods", "parts" },
    Prt_Capacitor = { "mods", "parts" },
    Prt_Mod = { "mods", "rangedmods" },
    Prt_RangedMod = { "mods", "rangedmods" },
    Prt_PowerMod = { "mods", "rangedmods" },
    Prt_TechMod = { "mods", "rangedmods" },
    Prt_SmartMod = { "mods", "rangedmods" },
    Prt_AR_SMG_LMGMod = { "mods", "rangedmods" },
    Prt_HandgunMod = { "mods", "rangedmods" },
    Prt_Precision_Sniper_RifleMod = { "mods", "rangedmods" },
    Prt_ShotgunMod = { "mods", "rangedmods" },
    Prt_MeleeMod = { "mods", "meleemods" },
    Prt_BladeMod = { "mods", "meleemods" },
    Prt_BluntMod = { "mods", "meleemods" },
    Prt_ThrowableMod = { "mods", "meleemods" },
    Prt_FabricEnhancer = { "mods", "clothingmods" },
    Prt_HeadFabricEnhancer = { "mods", "clothingmods" },
    Prt_FaceFabricEnhancer = { "mods", "clothingmods" },
    Prt_OuterTorsoFabricEnhancer = { "mods", "clothingmods" },
    Prt_TorsoFabricEnhancer = { "mods", "clothingmods" },
    Prt_PantsFabricEnhancer = { "mods", "clothingmods" },
    Prt_BootsFabricEnhancer = { "mods", "clothingmods" },
    Con_Skillbook = { "progression", "skillbooks" },
    CyberwareStatsShard = { "progression", "cyberwareshards" },
    CyberwareUpgradeShard = { "progression", "cyberwareshards" },
    Gen_MoneyShard = { "rewards", "currency" },
    Tok_VendorToken = { "rewards", "tokens" },
    Gen_Keycard = { "quest", "keycards" },
    Gen_Readable = { "readables", "shards" },
    Gen_DataBank = { "readables", "databanks" },
    Gen_Junk = { "misc", "junk" },
    Gen_Jewellery = { "misc", "jewellery" },
    Gen_Tarot = { "misc", "tarot" },
    Gen_Misc = { "misc", "other" }
}

local CYBERWARE = {
    Cyberware = true,
    CyberwareStyle = true,
    Cyb_Ability = true,
    Cyb_HealingAbility = true,
    Cyb_Launcher = true,
    Cyb_MantisBlades = true,
    Cyb_NanoWires = true,
    Cyb_StrongArms = true
}

local AREAS = {
    SystemReplacementCW = "os",
    FrontalCortexCW = "frontalcortex",
    EyesCW = "eyes",
    FaceCW = "face",
    MusculoskeletalSystemCW = "skeleton",
    NervousSystemCW = "nervoussystem",
    CardiovascularSystemCW = "circulatory",
    ImmuneSystemCW = "immunesystem",
    IntegumentarySystemCW = "integumentary",
    HandsCW = "hands",
    ArmsCW = "arms",
    ArmsCWStyle = "armstyles",
    LegsCW = "legs",
    PersonalLink = "personallink"
}

local loaded, manifest = pcall(require, ICONS)
local s_Icons = (loaded and type(manifest) == "table") and manifest or { Sheets = {}, Parts = {} }
local s_Resolver = nil
local s_Unlisted = {}
local s_Lists = nil
local s_List = 1
local s_Index = 1
local s_Total = 0
local s_Done = 0
local s_All = {}
local s_ByRecord = {}
local s_Announce = false

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

local function Friendly(value)
    return (tostring(value or ""):gsub("_", " "):gsub("(%l)(%u)", "%1 %2"))
end

local function RecordId(record)
    return Call(function() return record:GetID().value end)
end

local function NameOf(record)
    local key = Call(function() return record:DisplayName() end)
    local name = key and GameText.FromName(key, nil)
    if not name or name == "" or name == MISSING then return nil end
    return name
end

local function Deprecated(record)
    return Call(function() return record:Deprecated() end) == true
end

local function KindOf(record)
    return Text(Call(function() return record:ItemType():Name() end))
end

local function Tagged(record, tag)
    return Call(function() return record:TagsContains(CName.new(tag)) end) == true
end

local function QualityOf(record)
    local quality = Call(function() return record:Quality():Name() end)
    if type(quality) ~= "string" or quality == "" then return Catalog.STANDARD end
    return quality
end

local function QualityName(quality)
    return (quality:gsub("PlusPlus$", "++"):gsub("Plus$", "+"))
end

local function Craftable(record)
    return Call(function()
        local data = record:CraftingData()
        return data ~= nil and data:GetCraftingRecipeCount() > 0
    end) == true
end

local function AreaOf(record)
    local id = Text(Call(function() return record:EquipArea():GetID().value end))
    return AREAS[id:match("([^%.]+)$") or ""] or "othercyberware"
end

local function RecipeGroup(record)
    local result = Call(function() return record:CraftingResult():Item() end)
    local kind = result and KindOf(result) or ""
    if kind:find("^Wea_") then return "weaponrecipes" end
    if kind == "Prt_Program" then return "quickhackrecipes" end
    if kind:find("^Clo_") or kind:find("FabricEnhancer$") then return "clothingrecipes" end
    if CYBERWARE[kind] or kind == "Prt_Fragment" then return "cyberwarerecipes" end
    if kind:find("^Prt_") then return "modrecipes" end
    if kind == "Gad_Grenade" then return "grenaderecipes" end
    if kind:find("^Con_") then return "consumablerecipes" end
    if kind == "Gen_CraftingMaterial" then return "componentrecipes" end
    return "otherrecipes"
end

local function GroupKey(key)
    return "items.groups." .. key
end

local function Place(record, kind, recipe)
    if recipe then return "recipes", GroupKey(RecipeGroup(record)) end
    if kind == "Gen_CraftingMaterial" then
        return "crafting", GroupKey(Tagged(record, "QuickhackCraftingMaterials") and "quickhackcomponents" or "itemcomponents")
    end
    if CYBERWARE[kind] then return "cyberware", GroupKey(AreaOf(record)) end
    if kind == "Gen_Misc" or kind == "Gen_Junk" then
        if Tagged(record, "Currency") then return "rewards", GroupKey("currency") end
        if Tagged(record, "Quest") then return "quest", GroupKey("questitems") end
    end

    local place = TYPES[kind]
    if place then return place[1], GroupKey(place[2]) end
    if kind == "" then return "advanced", GroupKey("other") end
    return "advanced", Friendly(kind)
end

local function Build(id, record, name, recipe)
    local kind = KindOf(record)
    local category, group = Place(record, kind, recipe)
    local quality = QualityOf(record)

    return {
        Id = id,
        Name = name,
        Order = name:lower(),
        Search = (name .. " " .. id):lower(),
        Kind = kind,
        Category = category,
        Group = group,
        Quality = quality,
        QualityName = QualityName(quality),
        Weight = QUALITY_WEIGHT[quality] or 0,
        Craftable = Craftable(record),
        Unlisted = false,
        Icon = nil,
        Description = nil,
        Resolved = false
    }
end

local function ByName(first, second)
    if first.Order ~= second.Order then return first.Order < second.Order end
    return first.Id < second.Id
end

local function Add(record, recipe)
    local id = RecordId(record)
    if not id or not id:find("^Items%.") or s_ByRecord[id] then return end
    if Deprecated(record) then return end

    local name = NameOf(record)
    if not name then return end

    local item = Build(id, record, name, recipe)
    table.insert(s_All, item)
    s_ByRecord[id] = item
end

local function Start()
    s_Lists = {}
    s_List = 1
    s_Index = 1
    s_Total = 0
    s_Done = 0
    s_All = {}
    s_ByRecord = {}
end

local function Fetch()
    local kind = RECORD_TYPES[#s_Lists + 1]
    local records = Call(function() return TweakDB:GetRecords(kind) end) or {}
    table.insert(s_Lists, { Recipe = kind == RECIPES, Records = records })
    s_Total = s_Total + #records
end

local function ListLabel(list)
    return L(list.Label):lower()
end

local function ByLabel(first, second)
    local left, right = ListLabel(first), ListLabel(second)
    if left ~= right then return left < right end
    return first.Key < second.Key
end

local function Group(items)
    local categories, byKey, lists = {}, {}, {}
    for _, key in ipairs(CATEGORIES) do
        byKey[key] = {
            Key = key,
            Label = "items.categories." .. key .. ".label",
            Tip = "items.categories." .. key .. ".tip",
            All = {},
            Lists = {}
        }
    end

    for _, item in ipairs(items) do
        local category = byKey[item.Category]
        local key = item.Category .. ":" .. item.Group
        local list = lists[key]
        if not list then
            list = { Key = key, Label = item.Group, Items = {} }
            lists[key] = list
            table.insert(category.Lists, list)
        end
        table.insert(list.Items, item)
        table.insert(category.All, item)
    end

    for _, key in ipairs(CATEGORIES) do
        local category = byKey[key]
        if #category.All > 0 then
            table.sort(category.Lists, ByLabel)
            table.insert(categories, category)
        end
    end
    return categories, lists
end

local function Finish()
    table.sort(s_All, ByName)
    Catalog.All = s_All
    Catalog.ByRecord = s_ByRecord
    Catalog.Categories, Catalog.Lists = Group(s_All)
    Catalog.Progress = 1
    Catalog.Loaded = true
    Catalog.Version = Catalog.Version + 1
    s_Lists = nil
    s_All = {}
    s_ByRecord = {}
    s_Unlisted = {}

    Logger.Log(string.format("Items: %d items in %d categories", #Catalog.All, #Catalog.Categories))
    if s_Announce then Notify.Success(tip("notify.items.reloaded", { count = #Catalog.All })) end
    s_Announce = false
end

function Catalog.Step()
    if Catalog.Loaded then return end
    if not s_Lists then Start() end
    if #s_Lists < #RECORD_TYPES then
        Fetch()
        return
    end

    local deadline = os.clock() + STEP_TIME
    local count = 0
    while s_List <= #s_Lists do
        local list = s_Lists[s_List]
        local record = list.Records[s_Index]
        if record then
            s_Index = s_Index + 1
            s_Done = s_Done + 1
            count = count + 1
            Add(record, list.Recipe)
            if count % CHECK_EVERY == 0 and os.clock() >= deadline then break end
        else
            s_List = s_List + 1
            s_Index = 1
        end
    end

    Catalog.Progress = s_Total > 0 and (s_Done / s_Total) or 1
    if s_List > #s_Lists then Finish() end
end

function Catalog.Reload()
    Catalog.Loaded = false
    Catalog.Progress = 0
    s_Lists = nil
    s_Announce = true
end

function Catalog.Category(key)
    for _, category in ipairs(Catalog.Categories) do
        if category.Key == key then return category end
    end
    return nil
end

function Catalog.List(key)
    return Catalog.Lists[key]
end

local function Plain(id)
    return {
        Id = id,
        Name = id,
        Order = id:lower(),
        Search = id:lower(),
        Kind = "",
        Category = "advanced",
        Group = GroupKey("other"),
        Quality = Catalog.STANDARD,
        QualityName = Catalog.STANDARD,
        Weight = 0,
        Craftable = false,
        Unlisted = true,
        Icon = nil,
        Description = nil,
        Resolved = false
    }
end

function Catalog.Lookup(id)
    local item = Catalog.ByRecord[id] or s_Unlisted[id]
    if item then return item end

    local record = TweakDB:GetRecord(id)
    if record then
        item = Build(id, record, NameOf(record) or id, false)
        item.Unlisted = true
    else
        item = Plain(id)
    end
    s_Unlisted[id] = item
    return item
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
    local parts = s_Icons.Parts
    local first = ItemPart(record, id)
    if parts[first] then return parts[first] end

    local second = RecordPart(record)
    return parts[second]
end

local function Image(entry)
    return {
        Sheet = s_Icons.Sheets[entry[1]],
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

function Catalog.Resolve(item)
    if not item or item.Resolved then return end
    item.Resolved = true

    local record = TweakDB:GetRecord(item.Id)
    if not record then
        item.Icon = false
        item.Description = ""
        return
    end

    local entry = Part(record, item.Id)
    item.Icon = entry and Image(entry) or false
    item.Description = Describe(record)
end

if not loaded then Logger.Log("Items: couldn't load the icon manifest") end

return Catalog
