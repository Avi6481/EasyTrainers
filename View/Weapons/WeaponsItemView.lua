local Buttons = require("UI/Options/Buttons")
local Submenu = require("UI/Navigation/Submenu")
local SidePanel = require("UI/Panels/SidePanel/SidePanel")
local Notification = require("UI/Panels/Notification/Notification")
local Inventory = require("Utils/Inventory")
local WeaponLoader = require("Utils/DataExtractors/WeaponLoader")

local ACTION_REMOVE = "weaponsitems.removeweapon"
local ACTION_OPTIONS = { "weaponsitems.addweapon", ACTION_REMOVE }

local SORT = {
    Name = "Name",
    TierHigh = "Tier: High to Low",
    TierLow = "Tier: Low to High",
    OwnedHigh = "Owned: Most First"
}
local SORT_OPTIONS = { SORT.Name, SORT.TierHigh, SORT.TierLow, SORT.OwnedHigh }
local ALL = "All"
local CLASS_OPTIONS = { ALL, "Power", "Tech", "Smart", "Blade", "Blunt" }

local OWNED_REFRESH = 1.0
local STATS_REFRESH = 0.5

local s_Action = { index = 1 }
local s_Quantity = { value = 1, min = 1, max = 50, step = 1 }
local s_Tier = { index = 1 }
local s_Class = { index = 1 }
local s_Sort = { index = 1 }
local s_Search = { value = "", capturing = false }

local s_List = { Title = "", Source = nil, Key = nil }
local s_Cache = { Key = nil, Tier = nil, Class = nil, Sort = nil, Result = nil, Tiers = { ALL } }

local s_Owned = {}
local s_OwnedTotal = 0
local s_NextOwned = 0
local s_Stats = { Id = nil, Next = 0, Values = nil }
local s_Types = nil

local function IsRemoving()
    return ACTION_OPTIONS[s_Action.index or 1] == ACTION_REMOVE
end

local function ActionSummary()
    return (IsRemoving() and "-" or "+") .. tostring(s_Quantity.value)
end

local function RefreshOwned(force)
    local now = os.clock()
    if not force and now < s_NextOwned then return end
    s_NextOwned = now + OWNED_REFRESH

    s_Owned, s_OwnedTotal = {}, 0
    for _, item in ipairs(Inventory.GetAllItems() or {}) do
        if WeaponLoader:GetById(item.id) then
            if not s_Owned[item.id] then s_OwnedTotal = s_OwnedTotal + 1 end
            s_Owned[item.id] = (s_Owned[item.id] or 0) + (item.quantity or 1)
        end
    end
end

local function OwnedCount(weapon)
    return s_Owned[weapon.id] or 0
end

local function ApplyWeapon(weapon)
    local amount = s_Quantity.value
    if IsRemoving() then
        amount = math.min(amount, OwnedCount(weapon))
        if amount <= 0 then return false end
        return Inventory.RemoveItem(weapon.id, amount)
    end
    return Inventory.GiveItem(weapon.id, amount)
end

local function OwnedStats(weapon)
    local now = os.clock()
    if s_Stats.Id == weapon.id and now < s_Stats.Next then return s_Stats.Values end
    s_Stats.Id, s_Stats.Next, s_Stats.Values = weapon.id, now + STATS_REFRESH, nil
    if OwnedCount(weapon) == 0 then return nil end

    local player = Game.GetPlayer()
    local transactionSystem = Game.GetTransactionSystem()
    local stats = Game.GetStatsSystem()
    local ok, items = transactionSystem:GetItemList(player)
    if not ok or not stats then return nil end

    for _, itemData in ipairs(items) do
        if TDBID.ToStringDEBUG(itemData:GetID().id) == weapon.id then
            local statsID = itemData:GetStatsObjectID()
            local function Stat(statType)
                local statOk, value = pcall(function() return stats:GetStatValue(statsID, statType) end)
                return statOk and value or nil
            end

            local cycle = Stat(gamedataStatType.CycleTime)
            local values = {
                Damage = Stat(gamedataStatType.DamagePerHit),
                FireRate = cycle and cycle > 0 and 1 / cycle or nil,
                Pellets = math.max(1, Stat(gamedataStatType.ProjectilesPerShot) or 1),
                Magazine = Stat(gamedataStatType.MagazineCapacity),
                Reload = Stat(gamedataStatType.ReloadTime),
                Range = Stat(gamedataStatType.EffectiveRange),
                CritChance = Stat(gamedataStatType.CritChance),
                Headshot = Stat(gamedataStatType.HeadshotDamageMultiplier)
            }
            if values.Damage and values.FireRate then values.DPS = values.Damage * values.FireRate * values.Pellets end
            s_Stats.Values = values
            return values
        end
    end
    return nil
end

local function Format(value, pattern, suffix)
    if not value then return nil end
    return string.format(pattern, value) .. (suffix or "")
end

local function SubmitWeaponInfo(weapon)
    local owned = OwnedCount(weapon)
    local rows = {
        { Label = "Type", Value = weapon.type or "Miscellaneous" },
        { Label = "Tier", Value = weapon.rarity or "Standard" },
        { Label = "Class", Value = weapon.evolution or (weapon.isSmart and "Smart" or weapon.isTech and "Tech" or weapon.isPower and "Power" or "Standard") },
        { Label = "Manufacturer", Value = weapon.manufacturer or "Unlisted" },
        { Label = "Stash wall", Value = weapon.onWall and "Yes" or "No" },
        { Label = "Owned", Value = owned > 0 and ("x" .. tostring(owned)) or "No" }
    }

    local stats = OwnedStats(weapon)
    if stats then
        local function Row(label, value)
            if value then table.insert(rows, { Label = label, Value = value }) end
        end
        Row("Damage", Format(stats.Damage, "%.0f", stats.Pellets > 1 and (" x" .. tostring(math.floor(stats.Pellets))) or nil))
        Row("Fire rate", Format(stats.FireRate, "%.2f", "/s"))
        Row("DPS", Format(stats.DPS, "%.0f"))
        Row("Magazine", Format(stats.Magazine, "%.0f"))
        Row("Reload", Format(stats.Reload, "%.2f", "s"))
        Row("Range", Format(stats.Range, "%.0f", "m"))
        Row("Crit chance", Format(stats.CritChance, "%.0f", "%"))
        Row("Headshot", Format(stats.Headshot, "x%.1f"))
    end

    local description = WeaponLoader:GetDescription(weapon)
    local footer = stats and "" or "\n\nOwn one to see its live damage, fire rate, and DPS here."
    SidePanel.SubmitInfo("weapon-record", {
        Eyebrow = weapon.iconic and "ICONIC WEAPON" or string.upper(weapon.rarity or "WEAPON"),
        Title = weapon.displayName or "Unknown Weapon",
        Icon = weapon.id,
        Rows = rows,
        Description = (description ~= "" and (description .. "\n\n") or "") .. weapon.id .. footer
    }, { Width = 340 })
end

local function TierName(weapon)
    return weapon.rarity or "Standard"
end

local function ClassName(weapon)
    return weapon.evolution or (weapon.isSmart and "Smart" or weapon.isTech and "Tech" or weapon.isPower and "Power" or nil)
end

local function BuildTiers(weapons)
    local weights, tiers = {}, {}
    for _, weapon in ipairs(weapons) do
        local name = TierName(weapon)
        if not weights[name] then
            weights[name] = WeaponLoader:GetRarityWeight({ rarity = name })
            table.insert(tiers, name)
        end
    end
    table.sort(tiers, function(a, b)
        if weights[a] == weights[b] then return a < b end
        return weights[a] > weights[b]
    end)
    table.insert(tiers, 1, ALL)
    return tiers
end

local function VisibleWeapons()
    local key = s_List.Key
    if s_Cache.Key ~= key then
        local source = s_List.Source and s_List.Source() or {}
        s_Cache.Key, s_Cache.Source, s_Cache.Tiers, s_Cache.Result = key, source, BuildTiers(source), nil
        s_Tier.index = 1
    end

    s_Tier.index = math.min(s_Tier.index or 1, #s_Cache.Tiers)
    local tier = s_Cache.Tiers[s_Tier.index]
    local class = CLASS_OPTIONS[s_Class.index or 1]
    local sort = SORT_OPTIONS[s_Sort.index or 1]
    if s_Cache.Result and s_Cache.Tier == tier and s_Cache.Class == class and s_Cache.Sort == sort then return s_Cache.Result end

    local result = {}
    for _, weapon in ipairs(s_Cache.Source) do
        if (tier == ALL or TierName(weapon) == tier) and (class == ALL or ClassName(weapon) == class) then
            table.insert(result, weapon)
        end
    end

    table.sort(result, function(a, b)
        if sort == SORT.OwnedHigh and OwnedCount(a) ~= OwnedCount(b) then return OwnedCount(a) > OwnedCount(b) end
        if sort == SORT.TierHigh or sort == SORT.TierLow then
            local left, right = WeaponLoader:GetRarityWeight(a), WeaponLoader:GetRarityWeight(b)
            if left ~= right then
                if sort == SORT.TierHigh then return left > right end
                return left < right
            end
        end
        return a.displayName < b.displayName
    end)

    s_Cache.Tier, s_Cache.Class, s_Cache.Sort, s_Cache.Result = tier, class, sort, result
    return result
end

local function ApplyToAll(weapons)
    local applied = 0
    for _, weapon in ipairs(weapons) do
        if ApplyWeapon(weapon) then applied = applied + 1 end
    end
    RefreshOwned(true)
    s_Cache.Result = nil
    Notification.Success((IsRemoving() and "Removed " or "Added ") .. tostring(applied) .. " weapons", 2)
end

local function DrawActionControls()
    Buttons.Dropdown(L("weaponsitems.actionmode.label"), s_Action, ACTION_OPTIONS, L("weaponsitems.actionmode.tip"))
    Buttons.Int("Quantity", s_Quantity, "Number of copies to add or remove per selection.")
end

local function WeaponRow(weapon)
    local owned = OwnedCount(weapon)
    local value = (owned > 0 and ("x" .. tostring(owned) .. "  ") or "") .. ActionSummary()
    local _, data = Buttons.OptionExtended(weapon.displayName, "", value, "Apply the selected inventory action.", function()
        if ApplyWeapon(weapon) then
            RefreshOwned(true)
            s_Stats.Id = nil
        end
    end)
    if data and data.Visible and (data.Selected or data.Hovered) then SubmitWeaponInfo(weapon) end
end

local function ListView()
    RefreshOwned()
    DrawActionControls()
    VisibleWeapons()
    Buttons.Dropdown("Tier", s_Tier, s_Cache.Tiers, "Only show weapons of this tier.")
    Buttons.Dropdown("Class", s_Class, CLASS_OPTIONS, "Only show Power, Tech, Smart, Blade, or Blunt weapons.")
    Buttons.Dropdown("Sort", s_Sort, SORT_OPTIONS, "Order the list by name, tier, or how many you own.")

    local weapons = VisibleWeapons()
    Buttons.Option((IsRemoving() and "Remove " or "Add ") .. "Every Weapon Shown", "Apply the inventory action to every weapon in the filtered list below.", function()
        ApplyToAll(weapons)
    end)

    Buttons.Break(tostring(#weapons) .. " " .. s_List.Title)
    for _, weapon in ipairs(weapons) do WeaponRow(weapon) end
    if #weapons == 0 then Buttons.Break(L("weaponsitems.noweaponsfound.label")) end
end

local ListMenu = Submenu.Create("weaponsitems.title", ListView)

local function OpenList(title, key, source)
    return function()
        s_List.Title, s_List.Key, s_List.Source = title, key, source
        s_Class.index = 1
        RefreshOwned(true)
    end
end

local function SearchResults()
    local term = (s_Search.value or ""):lower()
    if term == "" then return {} end
    return WeaponLoader:Filter(function(weapon)
        return weapon.displayName:lower():find(term, 1, true) ~= nil or weapon.id:lower():find(term, 1, true) ~= nil
    end)
end

local function SearchView()
    Buttons.Text("Search Name or Item ID", s_Search, "Searches both the display name and the internal item ID.")
    local term = s_Search.value or ""
    if s_List.Key ~= "search:" .. term then OpenList("Results", "search:" .. term, SearchResults)() end
    ListView()
end

local SearchMenu = Submenu.Create("Search Weapons", SearchView)

local function TypesView()
    s_Types = s_Types or WeaponLoader:GetTypes()
    for _, weaponType in ipairs(s_Types) do
        Buttons.Submenu(weaponType, ListMenu, tip("weaponsitems.categorybreak.tip", { category = weaponType }),
            OpenList(weaponType, "type:" .. weaponType, function() return WeaponLoader:GetByCategory(weaponType) end))
    end
end

local TypesMenu = Submenu.Create("weaponsitems.categories.label", TypesView)

local function OwnedWeapons()
    RefreshOwned(true)
    return WeaponLoader:Filter(function(weapon) return OwnedCount(weapon) > 0 end)
end

local WHEEL_SLOTS = 4
local s_Loadout = { Next = 0, Slots = {}, Drawn = nil }

local function RecordOf(itemID)
    if not itemID then return nil end
    local ok, record = pcall(function() return ItemID.IsValid(itemID) and TDBID.ToStringDEBUG(itemID.id) or nil end)
    return ok and record and WeaponLoader:GetById(record) or nil
end

local function RefreshLoadout()
    local now = os.clock()
    if now < s_Loadout.Next then return end
    s_Loadout.Next = now + OWNED_REFRESH

    local player = Game.GetPlayer()
    local equipment = Game.GetScriptableSystemsContainer():Get("EquipmentSystem")
    local data = player and equipment and equipment:GetPlayerData(player)
    s_Loadout.Slots = {}
    for index = 0, WHEEL_SLOTS - 1 do
        local ok, itemID = pcall(function() return data:GetItemInEquipSlot(gamedataEquipmentArea.Weapon, index) end)
        s_Loadout.Slots[index + 1] = ok and RecordOf(itemID) or false
    end

    local item = player and Game.GetTransactionSystem():GetItemInSlot(player, "AttachmentSlots.WeaponRight")
    s_Loadout.Drawn = item and RecordOf(item:GetItemID()) or nil
end

local function LoadoutRow(label, weapon)
    if not weapon then
        Buttons.OptionExtended(label, "", "Empty", "Nothing equipped here.")
        return
    end
    local _, data = Buttons.OptionExtended(label, "", weapon.displayName, "Hover for the full weapon card and live stats.")
    if data and data.Visible and (data.Selected or data.Hovered) then SubmitWeaponInfo(weapon) end
end

local function DrawLoadout()
    RefreshLoadout()
    Buttons.Break("Your Loadout")
    LoadoutRow("In Hands", s_Loadout.Drawn)
    for index, weapon in ipairs(s_Loadout.Slots) do
        if weapon or index <= 3 then LoadoutRow("Slot " .. tostring(index), weapon or nil) end
    end
    Buttons.OptionExtended("Different Weapons Owned", "", tostring(s_OwnedTotal), "Open Owned Weapons to manage them.")
end

local function WeaponItemsView()
    RefreshOwned()
    Buttons.Submenu("Search Weapons", SearchMenu, "Find a weapon by its display name or internal ID.")
    Buttons.Submenu(L("weaponsitems.categories.label"), TypesMenu, "Browse every weapon by type, with tier, class, and sort filters.")
    Buttons.Submenu("Iconic Weapons", ListMenu, "Every iconic weapon in the game.",
        OpenList("Iconic Weapons", "iconic", function() return WeaponLoader:GetIconic() end))
    Buttons.Submenu("Stash Wall Weapons", ListMenu, "Weapons that can be mounted on the apartment stash wall.",
        OpenList("Stash Wall Weapons", "wall", function() return WeaponLoader:GetWall() end))
    Buttons.Submenu("Owned Weapons", ListMenu, "Weapons in your inventory right now, with live stats in the side panel.",
        OpenList("Owned Weapons", "owned:" .. tostring(os.time()), OwnedWeapons))
    Buttons.Submenu("All Weapons", ListMenu, "Every weapon record the game has.",
        OpenList("Weapons", "all", function() return WeaponLoader:GetAll() end))

    DrawLoadout()
end

return Submenu.Create("weaponsitems.title", WeaponItemsView)
