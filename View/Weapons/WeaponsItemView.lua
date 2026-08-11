local UI = require("UI")
local Buttons = UI.Buttons
local SidePanel = UI.SidePanel
local Inventory = require("Utils").Inventory
local WeaponLoader = require("Utils/DataExtractors/WeaponLoader")


local selectedMode = { index = 1 }
local modeOptions = {
    "weaponsitems.categories.label",
    "weaponsitems.onlyiconic.label",
    "weaponsitems.onlywall.label",
    "weaponsitems.onlyinventory.label"
}

local actionMode = { index = 1 }
local actionOptions = { "weaponsitems.addweapon", "weaponsitems.removeweapon" }
local quantity = { value = 1, min = 1, max = 50, step = 1 }

local selectedSort = { index = 1 }
local sortModes = { "weaponsitems.quantityH", "weaponsitems.quantityL", "weaponsitems.rarity" }

local showTech = { value = true }
local showSmart = { value = true }
local showPower = { value = true }

local matchedWeapons = {}
local weaponTypes = {}
local initialized = false
local selectedCategory = ""

local function IsRemoving()
    return actionOptions[actionMode.index or 1] == "weaponsitems.removeweapon"
end

local function ApplyWeapon(weapon, amount)
    amount = amount or quantity.value
    if IsRemoving() then
        return Inventory.RemoveItem(weapon.id, amount)
    end
    return Inventory.GiveItem(weapon.id, amount)
end

local function IsFocused(data)
    return data and data.Visible and (data.Selected or data.Hovered)
end

local function SubmitWeaponInfo(weapon)
    local technology = weapon.isSmart and "Smart" or weapon.isTech and "Tech" or weapon.isPower and "Power" or "Standard"
    SidePanel.SubmitInfo("weapon-record", {
        Eyebrow = weapon.iconic and "ICONIC WEAPON" or "WEAPON DATABASE",
        Title = weapon.displayName or weapon.name or "Unknown Weapon",
        Rows = {
            { Label = "Type", Value = weapon.type or "Miscellaneous" },
            { Label = "Rarity", Value = weapon.rarity or "Standard" },
            { Label = "Technology", Value = technology },
            { Label = "Manufacturer", Value = weapon.manufacturer or "Unlisted" },
            { Label = "Stash wall", Value = weapon.onWall and "Yes" or "No" },
        },
        Description = weapon.id,
    }, { Width = 320 })
end

local function MatchInventoryToKnownWeapons()
    matchedWeapons = {}
    local allItems = Inventory.GetAllItems()
    if not allItems then return end

    local knownByID = {}
    for _, w in ipairs(WeaponLoader:GetAll()) do
        knownByID[w.id] = w
    end

    local weaponMap = {}
    for _, item in ipairs(allItems) do
        local data = knownByID[item.id]
        if data then
            local entry = weaponMap[item.id]
            if entry then
                entry.count = entry.count + (item.quantity or 1)
            else
                weaponMap[item.id] = {
                    name = data.displayName,
                    id = data.id,
                    rarity = data.rarity,
                    iconic = data.iconic,
                    onWall = data.onWall,
                    type = data.type,
                    manufacturer = data.manufacturer,
                    isTech = data.isTech,
                    isSmart = data.isSmart,
                    isPower = data.isPower,
                    count = item.quantity or 1
                }
            end
        end
    end

    for _, weapon in pairs(weaponMap) do
        table.insert(matchedWeapons, weapon)
    end
end

local function WeaponCategorySubmenuView()
    local hasTech, hasSmart, hasPower = false, false, false
    for _, w in ipairs(WeaponLoader:GetAll()) do
        if w.type == selectedCategory then
            if w.isTech then hasTech = true end
            if w.isSmart then hasSmart = true end
            if w.isPower then hasPower = true end
        end
    end

    if hasTech then Buttons.Toggle(L("weaponsitems.categorytoggle_tech.label"), showTech,
            tip("weaponsitems.categorytoggle_tech.tip", { category = selectedCategory })) end
    if hasSmart then Buttons.Toggle(L("weaponsitems.categorytoggle_smart.label"), showSmart,
            tip("weaponsitems.categorytoggle_smart.tip", { category = selectedCategory })) end
    if hasPower then Buttons.Toggle(L("weaponsitems.categorytoggle_power.label"), showPower,
            tip("weaponsitems.categorytoggle_power.tip", { category = selectedCategory })) end

    local weapons = WeaponLoader:GetByCategory(selectedCategory, {
        tech = showTech.value,
        smart = showSmart.value,
        power = showPower.value
    })

    Buttons.Break("", tip("weaponsitems.categorybreak.tip", { category = selectedCategory }))

    for _, w in ipairs(weapons) do
        local tipData = {
            id = w.id,
            type = w.type,
            rarity = w.rarity,
            iconic = w.iconic and "\n" .. L("weaponsitems.iconic") or "",
            wall = w.onWall and "\n".. L("weaponsitems.wallmount") or ""
        }
        local summary = (IsRemoving() and "-" or "+") .. tostring(quantity.value)
        local _, data = Buttons.OptionExtended(w.displayName, "", summary, "Apply the selected inventory action.",
            function()
                ApplyWeapon(w)
            end)
        if IsFocused(data) then SubmitWeaponInfo(w) end
    end
end

local categorySubmenu = {
    title = "weaponsitems.categories.label",
    view = WeaponCategorySubmenuView
}

local function BuildWeaponTypeList()
    weaponTypes = WeaponLoader:GetTypes()
end

local function DrawWeaponCategories()
    for _, weaponType in ipairs(weaponTypes) do
        Buttons.Submenu(weaponType, categorySubmenu, tip("weaponsitems.categorybreak.tip", { category = weaponType }),
            function()
                selectedCategory = weaponType
                showTech.value = true
                showSmart.value = true
                showPower.value = true
            end)
    end
end

local function DrawInventoryWeapons()
    table.sort(matchedWeapons, function(a, b)
        local mode = sortModes[selectedSort.index or 1]
        if mode == "weaponsitems.quantityH" then
            if a.count == b.count then return a.name < b.name end
            return a.count > b.count
        elseif mode == "weaponsitems.quantityL" then
            if a.count == b.count then return a.name < b.name end
            return a.count < b.count
        elseif mode == "weaponsitems.rarity" then
            local weightA = WeaponLoader:GetRarityWeight(a)
            local weightB = WeaponLoader:GetRarityWeight(b)
            if weightA == weightB then return a.name < b.name end
            return weightA > weightB
        end
    end)

    for _, w in ipairs(matchedWeapons) do
        local tipData = {
            id = w.id,
            type = w.type,
            rarity = w.rarity,
            iconic = w.iconic and "\n" .. L("weaponsitems.iconic") or "",
            wall = w.onWall and "\n".. L("weaponsitems.wallmount") or ""
        }
        local _, data = Buttons.OptionExtended(w.name, "", "x" .. tostring(w.count), "Apply the selected inventory action.",
            function()
                local amount = math.min(quantity.value, IsRemoving() and w.count or quantity.value)
                if amount > 0 then
                    ApplyWeapon(w, amount)
                    w.count = math.max(0, w.count + (IsRemoving() and -amount or amount))
                end
            end)
        if IsFocused(data) then SubmitWeaponInfo(w) end
    end

    if #matchedWeapons == 0 then
        Buttons.Break("", L("weaponsitems.noinventoryweapons.label"))
    end
end

local function DrawFilteredWeapons(mode)
    local filtered = {}
    if mode == L("weaponsitems.onlyiconic.label") then
        filtered = WeaponLoader:GetIconic()
    elseif mode == L("weaponsitems.onlywall.label") then
        filtered = WeaponLoader:GetWall()
    end

    for _, w in ipairs(filtered) do
        local tipData = {
            id = w.id,
            type = w.type,
            rarity = w.rarity,
            iconic = w.iconic and "\n" .. L("weaponsitems.iconic") or "",
            wall = w.onWall and "\n".. L("weaponsitems.wallmount") or ""
        }
        local summary = (IsRemoving() and "-" or "+") .. tostring(quantity.value)
        local _, data = Buttons.OptionExtended(w.displayName, "", summary, "Apply the selected inventory action.",
        function()
            ApplyWeapon(w)
        end)
        if IsFocused(data) then SubmitWeaponInfo(w) end
    end

    if #filtered == 0 then
        Buttons.Break("", L("weaponsitems.noweaponsfound.label"))
    end
end

local function WeaponInventoryView()
    if not initialized then
        BuildWeaponTypeList()
        MatchInventoryToKnownWeapons()
        initialized = true
    end

    Buttons.Dropdown(L("weaponsitems.mode.label"), selectedMode, modeOptions, L("weaponsitems.mode.tip"))
    Buttons.Dropdown(L("weaponsitems.actionmode.label"), actionMode, actionOptions, L("weaponsitems.actionmode.tip"))
    Buttons.Int("Quantity", quantity, "Number of copies to add or remove per selection.")

    local mode = modeOptions[selectedMode.index or 1]
    if mode == "weaponsitems.onlyinventory.label" then
        Buttons.Option(L("weaponsitems.refreshinventory.label"), L("weaponsitems.refreshinventory.tip"),
            MatchInventoryToKnownWeapons)
        Buttons.Dropdown(L("weaponsitems.sortinventory.label"), selectedSort, sortModes,
            L("weaponsitems.sortinventory.tip"))
    end

    Buttons.Break("", L("weaponsitems.title"))

    if mode == "weaponsitems.categories.label" then
        DrawWeaponCategories()
    elseif mode == "weaponsitems.onlyinventory.label" then
        DrawInventoryWeapons()
    else
        DrawFilteredWeapons(L(mode))
    end
end

return {
    title = "weaponsitems.title",
    view = WeaponInventoryView
}
