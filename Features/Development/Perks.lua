local Dev = require("Features/Development/Dev")
local Catalog = require("Features/Development/Catalog")
local Logger = require("Core/Logger")
local Notify = require("Utils/Notify")

local Perks = {}

local function PointType(perk)
    if perk.Attribute.Relic then return gamedataDevelopmentPointType.Espionage end
    return gamedataDevelopmentPointType.Primary
end

local function Buy(data, perk, force)
    if force and not data:IsNewPerkUnlocked(perk.Type) then data:UnlockNewPerk(perk.Type) end
    return data:BuyNewPerk(perk.Type, force)
end

local function TakeRefund(data, perk)
    local pointType = PointType(perk)
    local amount = math.min(perk.Cost, math.max(0, data:GetDevPoints(pointType)))
    if amount > 0 then data:AddDevelopmentPoints(-amount, pointType) end
end

function Perks.Remove(data, player, perk, refund)
    local level = data:IsNewPerkBought(perk.Type)
    if level == 0 then return true end

    local check = PlayerDevelopmentSystem.CanSellNewPerk(player, perk.Type)
    if not check.success then
        Notify.Warning(tip("notify.dev.cyberware", { perk = perk.Name }))
        return false
    end

    if not data:ForceSellNewPerk(perk.Type) then return false end

    local event = NewPerkSoldEvent.new()
    event.perkType = perk.Type
    event.perkLevelSold = level
    player:QueueEvent(event)

    if not refund then TakeRefund(data, perk) end
    return true
end

function Perks.Relock(data, attribute)
    for _, perk in ipairs(Catalog.ByAttribute[attribute.Id] or {}) do
        if data:IsNewPerkBought(perk.Type) == 0 and data:IsNewPerkUnlocked(perk.Type) then data:LockNewPerk(perk.Type) end
    end
    data:UnlockFreeNewPerks(Dev.AttributeData(attribute))
end

local function RemoveChildren(data, player, perk)
    for _, child in ipairs(perk.Children) do
        if not RemoveChildren(data, player, child) then return false end
        while data:IsNewPerkBought(child.Type) > 0 do
            if not Perks.Remove(data, player, child, true) then return false end
        end
    end
    return true
end

local function Raise(data, perk, target, force)
    if not force then
        for _, parent in ipairs(perk.Parents) do
            if not Raise(data, parent, parent.MaxLevel, false) then return false end
        end
        data:UnlockFreeNewPerks(Dev.AttributeData(perk.Attribute))
    end

    while data:IsNewPerkBought(perk.Type) < target do
        if not Buy(data, perk, force) then return false end
    end
    return true
end

local function Lower(data, player, perk, target, force)
    if not force and not RemoveChildren(data, player, perk) then return false end

    while data:IsNewPerkBought(perk.Type) > target do
        if not Perks.Remove(data, player, perk, not force) then return false end
    end
    return true
end

local function Apply(data, player, perk, target, force)
    target = math.max(0, math.min(perk.MaxLevel, target))
    local level = data:IsNewPerkBought(perk.Type)
    if target == level then return true, false end

    if target < level and player:IsInCombat() then
        Notify.Warning(L("notify.dev.combat"))
        return false, false
    end

    local done
    if target > level then
        done = Raise(data, perk, target, force)
    else
        done = Lower(data, player, perk, target, force)
    end
    if not done then Logger.Log("Development: couldn't change " .. perk.Name) end
    return done, target < level
end

local function Finish(data, attribute, lowered)
    if lowered then
        Perks.Relock(data, attribute)
    else
        data:UnlockFreeNewPerks(Dev.AttributeData(attribute))
    end
    data:UpdateUIBB()
end

function Perks.SetLevel(perk, target, force)
    local data, player = Dev.Data()
    if not data then return false end

    local done, lowered = Apply(data, player, perk, target, force)
    Finish(data, perk.Attribute, lowered)
    return done
end

function Perks.MaxAll(attribute, force)
    local data, player = Dev.Data()
    if not data then return end

    local points = data:GetAttributePoints(Dev.AttributeData(attribute))
    for _, perk in ipairs(Catalog.ByAttribute[attribute.Id] or {}) do
        if force or attribute.Relic or perk.Required <= points then
            if not Apply(data, player, perk, perk.MaxLevel, force) then break end
        end
    end
    Finish(data, attribute, false)
end

function Perks.SellAll(attribute, force)
    local data, player = Dev.Data()
    if not data then return end

    if player:IsInCombat() then
        Notify.Warning(L("notify.dev.combat"))
        return
    end

    local list = Catalog.ByAttribute[attribute.Id] or {}
    local kept = 0
    for index = #list, 1, -1 do
        local perk = list[index]
        while data:IsNewPerkBought(perk.Type) > 0 do
            if not Perks.Remove(data, player, perk, not force) then
                kept = kept + 1
                break
            end
        end
    end

    Perks.Relock(data, attribute)
    data:UpdateUIBB()
    if kept > 0 then Notify.Warning(tip("notify.dev.kept", { count = kept })) end
end

return Perks
