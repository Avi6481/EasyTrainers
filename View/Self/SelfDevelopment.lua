local Buttons = require("UI/Options/Buttons")
local Submenu = require("UI/Navigation/Submenu")
local SidePanel = require("UI/Panels/SidePanel/SidePanel")
local Notification = require("UI/Panels/Notification/Notification")
local PerkLoader = require("Utils/DataExtractors/PerkLoader")
local PlayerDevelopment = require("Utils/PlayerDevelopment")
local Inventory = require("Utils/Inventory")

local POINT = gamedataDevelopmentPointType
local PROFICIENCY = gamedataProficiencyType

local ATTRIBUTE_MAX = 20
local UNLOCK_PASSES = 6

local ATTRIBUTES = {
    { Key = "playerdev.attributes.body", Name = "Body", Stat = gamedataStatType.Strength, Core = true },
    { Key = "playerdev.attributes.reflexes", Name = "Reflexes", Stat = gamedataStatType.Reflexes, Core = true },
    { Key = "playerdev.attributes.technical", Name = "Technical Ability", Stat = gamedataStatType.TechnicalAbility, Core = true },
    { Key = "playerdev.attributes.intelligence", Name = "Intelligence", Stat = gamedataStatType.Intelligence, Core = true },
    { Key = "playerdev.attributes.cool", Name = "Cool", Stat = gamedataStatType.Cool, Core = true },
    { Key = "playerdev.attributes.relic", Name = "Relic", Stat = gamedataStatType.Espionage, Core = false }
}

local PERK_FILTER = { All = 1, Active = 2, Inactive = 3 }
local PERK_FILTER_OPTIONS = {
    "playerdev.perks.filter.all",
    "playerdev.perks.filter.active",
    "playerdev.perks.filter.inactive"
}

local PROFICIENCIES = {
    { Name = "playerdev.proficiencies.playerlevel", Type = PROFICIENCY.Level },
    { Name = "playerdev.proficiencies.streetcred", Type = PROFICIENCY.StreetCred },
    { Name = "playerdev.proficiencies.assault", Type = PROFICIENCY.Assault },
    { Name = "playerdev.proficiencies.athletics", Type = PROFICIENCY.Athletics },
    { Name = "playerdev.proficiencies.brawling", Type = PROFICIENCY.Brawling },
    { Name = "playerdev.proficiencies.coldblood", Type = PROFICIENCY.ColdBlood },
    { Name = "playerdev.proficiencies.combathacking", Type = PROFICIENCY.CombatHacking },
    { Name = "playerdev.proficiencies.cool", Type = PROFICIENCY.CoolSkill },
    { Name = "playerdev.proficiencies.crafting", Type = PROFICIENCY.Crafting },
    { Name = "playerdev.proficiencies.demolition", Type = PROFICIENCY.Demolition },
    { Name = "playerdev.proficiencies.engineering", Type = PROFICIENCY.Engineering },
    { Name = "playerdev.proficiencies.espionage", Type = PROFICIENCY.Espionage },
    { Name = "playerdev.proficiencies.gunslinger", Type = PROFICIENCY.Gunslinger },
    { Name = "playerdev.proficiencies.hacking", Type = PROFICIENCY.Hacking },
    { Name = "playerdev.proficiencies.intelligence", Type = PROFICIENCY.IntelligenceSkill },
    { Name = "playerdev.proficiencies.kenjutsu", Type = PROFICIENCY.Kenjutsu },
    { Name = "playerdev.proficiencies.reflexes", Type = PROFICIENCY.ReflexesSkill },
    { Name = "playerdev.proficiencies.stealth", Type = PROFICIENCY.Stealth },
    { Name = "playerdev.proficiencies.strength", Type = PROFICIENCY.StrengthSkill },
    { Name = "playerdev.proficiencies.technical", Type = PROFICIENCY.TechnicalAbilitySkill }
}

local s_PerkFilter = { index = PERK_FILTER.All }
local s_SortedPerks = {}
local s_ProficiencyRefs = {}
local s_AttributeRefs = {}
local s_Eddies = { value = 1000, min = 1, max = 1000000, step = 100 }
local s_PerkPoints = { value = 1, min = 1, max = 100, step = 1 }
local s_AttributePoints = { value = 1, min = 1, max = 100, step = 1 }

local function RefreshProficiencies()
    for _, proficiency in ipairs(PROFICIENCIES) do
        s_ProficiencyRefs[proficiency.Type] = {
            value = PlayerDevelopment.GetLevel(proficiency.Type) or 1,
            min = 0,
            max = PlayerDevelopment.GetMaxLevel(proficiency.Type),
            step = 1
        }
    end
end

local function RefreshAttributes()
    for _, attribute in ipairs(ATTRIBUTES) do
        s_AttributeRefs[attribute.Name] = {
            value = math.floor(PlayerDevelopment.GetAttribute(attribute.Stat) or 3),
            min = 1,
            max = ATTRIBUTE_MAX,
            step = 1
        }
    end
end

local function ProficiencyView()
    if next(s_ProficiencyRefs) == nil then RefreshProficiencies() end
    for _, proficiency in ipairs(PROFICIENCIES) do
        Buttons.Int(L(proficiency.Name), s_ProficiencyRefs[proficiency.Type], tip("playerdev.proficiencies.tip", { name = L(proficiency.Name) }), function(value)
            PlayerDevelopment.SetLevel(proficiency.Type, value)
        end)
    end
end

local ProficiencyMenu = Submenu.Create("playerdev.submenus.proficiencies.label", ProficiencyView)

local function AttributeView()
    if next(s_AttributeRefs) == nil then RefreshAttributes() end
    for _, attribute in ipairs(ATTRIBUTES) do
        Buttons.Int(L(attribute.Key), s_AttributeRefs[attribute.Name], tip("playerdev.attributerows.tip", { attribute = L(attribute.Key) }), function(value)
            PlayerDevelopment.SetAttribute(attribute.Stat, value)
        end)
    end
end

local AttributeMenu = Submenu.Create("playerdev.attributes.label", AttributeView)

local function AddMoney(amount)
    Inventory.GiveItem("Items.money", amount)
end

local function PointOption(key, pointType, amount, tipText)
    Buttons.Option(L(key), tipText, function() PlayerDevelopment.AddDevPoints(pointType, amount()) end)
end

local function Fixed(amount)
    return function() return amount end
end

local function ResourceView()
    Buttons.Break(L("playerdev.eddies.label"))
    Buttons.Option(L("playerdev.eddies.add1k.label"), tip("playerdev.eddies.add1k.tip"), function() AddMoney(1000) end)
    Buttons.Option(L("playerdev.eddies.add10k.label"), tip("playerdev.eddies.add10k.tip"), function() AddMoney(10000) end)
    Buttons.Option(L("playerdev.eddies.add100k.label"), tip("playerdev.eddies.add100k.tip"), function() AddMoney(100000) end)
    Buttons.Int(L("playerdev.eddies.custom.label"), s_Eddies, tip("playerdev.eddies.custom.tip"))
    Buttons.Option(L("playerdev.eddies.addcustom.label"), tip("playerdev.eddies.addcustom.tip"), function() AddMoney(s_Eddies.value) end)
    Buttons.Option(L("playerdev.eddies.removecustom.label"), tip("playerdev.eddies.removecustom.tip"), function()
        Inventory.RemoveItem("Items.money", s_Eddies.value)
    end)

    Buttons.Break(L("playerdev.perkpoints.label"))
    PointOption("playerdev.perkpoints.add1", POINT.Primary, Fixed(1), "Adds one perk point.")
    PointOption("playerdev.perkpoints.remove1", POINT.Primary, Fixed(-1), "Removes one perk point.")
    Buttons.Int(L("playerdev.perkpoints.custom"), s_PerkPoints, "Amount used by the custom perk point options.")
    PointOption("playerdev.perkpoints.addcustom", POINT.Primary, function() return s_PerkPoints.value end, "Adds the custom amount of perk points.")
    PointOption("playerdev.perkpoints.removecustom", POINT.Primary, function() return -s_PerkPoints.value end, "Removes the custom amount of perk points.")

    Buttons.Break(L("playerdev.attributepoints.label"))
    PointOption("playerdev.attributepoints.add1", POINT.Attribute, Fixed(1), "Adds one attribute point.")
    PointOption("playerdev.attributepoints.remove1", POINT.Attribute, Fixed(-1), "Removes one attribute point.")
    Buttons.Int(L("playerdev.attributepoints.custom"), s_AttributePoints, "Amount used by the custom attribute point options.")
    PointOption("playerdev.attributepoints.addcustom", POINT.Attribute, function() return s_AttributePoints.value end, "Adds the custom amount of attribute points.")
    PointOption("playerdev.attributepoints.removecustom", POINT.Attribute, function() return -s_AttributePoints.value end, "Removes the custom amount of attribute points.")

    Buttons.Break(L("playerdev.relicpoints.label"))
    PointOption("playerdev.relicpoints.add1", POINT.Espionage, Fixed(1), "Adds one Relic point.")
    PointOption("playerdev.relicpoints.remove1", POINT.Espionage, Fixed(-1), "Removes one Relic point.")
end

local ResourceMenu = Submenu.Create("playerdev.submenus.resources.label", ResourceView)

local function MissingRequirements(perk)
    local missing = {}
    for _, required in ipairs(perk.requirements and perk.requirements.perks or {}) do
        if not PlayerDevelopment.HasPerk(required.type) then table.insert(missing, required.name) end
    end
    return missing
end

local function NotifyMissing(perk, missing)
    Notification.Error(tip("playerdev.perks.notifications.requirement_failed", {
        perk = perk.name,
        requirements = table.concat(missing, ", ")
    }))
end

local function RemoveLevels(perk, current)
    local removed = 0
    for _ = 1, current do
        if PlayerDevelopment.RemovePerk(perk.type) then removed = removed + 1 end
    end
    return removed
end

local function ResetPerk(perk, current)
    local removed = RemoveLevels(perk, current)
    if removed > 0 then
        Notification.Info(tip("playerdev.perks.notifications.reset", { perk = perk.name, count = tostring(removed) }))
    else
        Notification.Error(tip("playerdev.perks.notifications.reset_failed", { perk = perk.name }))
    end
end

local function TogglePerk(perk, current, maxLevel, missing)
    if current >= maxLevel then
        if maxLevel == 1 then
            if PlayerDevelopment.RemovePerk(perk.type) then
                Notification.Info(tip("playerdev.perks.notifications.unequipped", { perk = perk.name }))
            else
                Notification.Error(tip("playerdev.perks.notifications.unequip_failed", { perk = perk.name }))
            end
            return
        end
        ResetPerk(perk, current)
        return
    end

    if #missing > 0 then
        NotifyMissing(perk, missing)
        return
    end

    if not PlayerDevelopment.AddPerk(perk.type, true) then
        local key = maxLevel == 1 and "playerdev.perks.notifications.equip_failed" or "playerdev.perks.notifications.level_failed"
        Notification.Error(tip(key, { perk = perk.name }))
        return
    end

    if maxLevel == 1 then
        Notification.Success(tip("playerdev.perks.notifications.equipped", { perk = perk.name }))
    else
        Notification.Success(tip("playerdev.perks.notifications.level_increased", { perk = perk.name, level = tostring(current + 1) }))
    end
end

local function SortedPerks(attributeName)
    if s_SortedPerks[attributeName] then return s_SortedPerks[attributeName] end

    local perks = {}
    for _, perk in pairs(PerkLoader.attribute[attributeName] or {}) do table.insert(perks, perk) end
    table.sort(perks, function(a, b)
        if a.category ~= b.category then return a.category < b.category end
        return a.name < b.name
    end)
    s_SortedPerks[attributeName] = perks
    return perks
end

local function UnlockPerks(perks)
    local added = 0
    for _ = 1, UNLOCK_PASSES do
        local progressed = false
        for _, perk in ipairs(perks) do
            local maxLevel = PlayerDevelopment.GetPerkMaxLevel(perk.type) or 1
            local level = PlayerDevelopment.GetPerkLevel(perk.type)
            if level < maxLevel and #MissingRequirements(perk) == 0 then
                while level < maxLevel and PlayerDevelopment.AddPerk(perk.type, true) do
                    local nextLevel = PlayerDevelopment.GetPerkLevel(perk.type)
                    if nextLevel <= level then break end
                    level = nextLevel
                    added = added + 1
                    progressed = true
                end
            end
        end
        if not progressed then break end
    end
    return added
end

local function RemovePerks(perks)
    local removed = 0
    for _, perk in ipairs(perks) do
        removed = removed + RemoveLevels(perk, PlayerDevelopment.GetPerkLevel(perk.type))
    end
    return removed
end

local function AllPerks()
    local perks = {}
    for _, attribute in ipairs(ATTRIBUTES) do
        for _, perk in ipairs(SortedPerks(attribute.Name)) do table.insert(perks, perk) end
    end
    return perks
end

local function PerkStatus(current, maxLevel, missing)
    if current == 0 and #missing > 0 then return L("playerdev.perks.locked") end
    if current == 0 then return L("playerdev.perks.unequipped") end
    return L("playerdev.perks.equipped") .. string.format(" %d / %d", current, maxLevel)
end

local function PerkTip(perk, maxLevel)
    local key = maxLevel > 1 and "playerdev.perks.tipmulti" or "playerdev.perks.tipsingle"
    return tip(key, { category = perk.category, levels = maxLevel })
end

local function SubmitPerkInfo(perk, current, maxLevel, missing)
    local requirements = {}
    for _, required in ipairs(perk.requirements and perk.requirements.perks or {}) do table.insert(requirements, required.name) end

    SidePanel.SubmitInfo("perk-record", {
        Eyebrow = L("playerdev.perkbrowser.eyebrow"),
        Title = perk.name,
        Rows = {
            { Label = L("playerdev.perkbrowser.attribute"), Value = perk.attribute },
            { Label = L("playerdev.perkbrowser.category"), Value = perk.category },
            { Label = L("playerdev.perkbrowser.level"), Value = string.format("%d / %d", current, maxLevel) },
            { Label = L("playerdev.perkbrowser.requires"), Value = #requirements > 0 and table.concat(requirements, ", ") or L("playerdev.perkbrowser.none") }
        },
        Description = (perk.description or "") .. (#missing > 0 and ("\n\n" .. tip("playerdev.perks.notifications.requirement_failed", { perk = perk.name, requirements = table.concat(missing, ", ") })) or "")
    }, { Width = 330 })
end

local function DrawPerk(perk)
    local current = PlayerDevelopment.GetPerkLevel(perk.type)
    if s_PerkFilter.index == PERK_FILTER.Active and current == 0 then return end
    if s_PerkFilter.index == PERK_FILTER.Inactive and current > 0 then return end

    local maxLevel = PlayerDevelopment.GetPerkMaxLevel(perk.type) or 1
    local missing = MissingRequirements(perk)
    local _, data = Buttons.OptionExtended(perk.name, "", PerkStatus(current, maxLevel, missing), PerkTip(perk, maxLevel), function()
        TogglePerk(perk, current, maxLevel, missing)
    end)
    if data and data.Visible and (data.Selected or data.Hovered) then SubmitPerkInfo(perk, current, maxLevel, missing) end
end

local function AttributePerkView(attribute)
    local name = L(attribute.Key)
    local perks = SortedPerks(attribute.Name)

    Buttons.StringCycler(L("playerdev.perks.filter.label"), s_PerkFilter, PERK_FILTER_OPTIONS, tip("playerdev.perks.filter.tip"))
    Buttons.Option(tip("playerdev.perkbrowser.unlockall.label", { attribute = name }), tip("playerdev.perkbrowser.unlockall.tip"), function()
        Notification.Success(tip("playerdev.quick.unlockperks.done", { count = tostring(UnlockPerks(perks)) }))
    end)
    Buttons.Option(tip("playerdev.perkbrowser.removeall.label", { attribute = name }), tip("playerdev.perkbrowser.removeall.tip"), function()
        Notification.Info(tip("playerdev.quick.resetperks.done", { count = tostring(RemovePerks(perks)) }))
    end)

    local category
    for _, perk in ipairs(perks) do
        if perk.category ~= category then
            category = perk.category
            Buttons.Break(category)
        end
        DrawPerk(perk)
    end
end

local s_AttributePerkMenus = {}
for _, attribute in ipairs(ATTRIBUTES) do
    s_AttributePerkMenus[attribute.Name] = Submenu.Create(attribute.Key, function() AttributePerkView(attribute) end)
end

local function PerkBrowserView()
    for _, attribute in ipairs(ATTRIBUTES) do
        Buttons.Submenu(L(attribute.Key), s_AttributePerkMenus[attribute.Name], tip("playerdev.perkbrowser.attributetip", { attribute = L(attribute.Key) }))
    end
end

local PerkBrowserMenu = Submenu.Create("playerdev.perkbrowser.label", PerkBrowserView)

local function MaxLevel()
    for _, proficiency in ipairs({ PROFICIENCY.Level, PROFICIENCY.StreetCred }) do
        PlayerDevelopment.SetLevel(proficiency, PlayerDevelopment.GetMaxLevel(proficiency))
    end
    Notification.Success(L("playerdev.quick.maxlevel.done"))
end

local function MaxAttributes()
    for _, attribute in ipairs(ATTRIBUTES) do
        if attribute.Core then PlayerDevelopment.SetAttribute(attribute.Stat, ATTRIBUTE_MAX) end
    end
    RefreshAttributes()
    Notification.Success(L("playerdev.quick.maxattributes.done"))
end

local function MaxSkills()
    for _, proficiency in ipairs(PROFICIENCIES) do
        if proficiency.Type ~= PROFICIENCY.Level and proficiency.Type ~= PROFICIENCY.StreetCred then
            PlayerDevelopment.SetLevel(proficiency.Type, PlayerDevelopment.GetMaxLevel(proficiency.Type))
        end
    end
    Notification.Success(L("playerdev.quick.maxskills.done"))
end

local function Overview(labelKey, value, tipText)
    Buttons.OptionExtended(L(labelKey), "", tostring(value or 0), tipText)
end

local function PlayerDevelopmentView()
    Buttons.Submenu(L("playerdev.attributes.label"), AttributeMenu, tip("playerdev.attributes.tip"), RefreshAttributes)
    Buttons.Submenu(L("playerdev.perkbrowser.label"), PerkBrowserMenu, tip("playerdev.perkbrowser.tip"))
    Buttons.Submenu(L("playerdev.submenus.proficiencies.label"), ProficiencyMenu, tip("playerdev.submenus.proficiencies.tip"), RefreshProficiencies)
    Buttons.Submenu(L("playerdev.submenus.resources.label"), ResourceMenu, tip("playerdev.submenus.resources.tip"))

    Buttons.Break(L("playerdev.overview.header"))
    Overview("playerdev.overview.level.label", PlayerDevelopment.GetLevel(PROFICIENCY.Level), tip("playerdev.overview.level.tip"))
    Overview("playerdev.overview.streetcred.label", PlayerDevelopment.GetLevel(PROFICIENCY.StreetCred), tip("playerdev.overview.streetcred.tip"))
    Overview("playerdev.perkpoints.available.label", PlayerDevelopment.GetDevPoints(POINT.Primary), tip("playerdev.perkpoints.available.tip"))
    Overview("playerdev.attributepoints.available.label", PlayerDevelopment.GetDevPoints(POINT.Attribute), tip("playerdev.attributepoints.available.tip"))
    Overview("playerdev.relicpoints.available.label", PlayerDevelopment.GetDevPoints(POINT.Espionage), tip("playerdev.relicpoints.available.tip"))

    Buttons.Break(L("playerdev.quick.header"))
    Buttons.Option(L("playerdev.quick.maxlevel.label"), tip("playerdev.quick.maxlevel.tip"), MaxLevel)
    Buttons.Option(L("playerdev.quick.maxattributes.label"), tip("playerdev.quick.maxattributes.tip"), MaxAttributes)
    Buttons.Option(L("playerdev.quick.maxskills.label"), tip("playerdev.quick.maxskills.tip"), MaxSkills)
    Buttons.Option(L("playerdev.quick.unlockperks.label"), tip("playerdev.quick.unlockperks.tip"), function()
        Notification.Success(tip("playerdev.quick.unlockperks.done", { count = tostring(UnlockPerks(AllPerks())) }))
    end)
    Buttons.Option(L("playerdev.quick.resetperks.label"), tip("playerdev.quick.resetperks.tip"), function()
        Notification.Info(tip("playerdev.quick.resetperks.done", { count = tostring(RemovePerks(AllPerks())) }))
    end)
end

return Submenu.Create("playerdev.title", PlayerDevelopmentView)
