local Dev = require("Features/Development/Dev")
local Catalog = require("Features/Development/Catalog")
local Snapshot = require("Features/Development/Snapshot")
local Perks = require("Features/Development/Perks")
local Logger = require("Core/Logger")
local Notify = require("Utils/Notify")

local ForceRespec = {}

local function PointKey(perk)
    return perk.Attribute.Relic and "Espionage" or "Primary"
end

function ForceRespec.Totals()
    local totals = { Primary = 0, Attribute = 0, Espionage = 0 }

    for _, perk in ipairs(Catalog.Perks) do
        local key = PointKey(perk)
        totals[key] = totals[key] + (Snapshot.Level(perk) * perk.Cost)
    end
    for _, attribute in ipairs(Dev.Attributes) do
        if not attribute.Relic then
            local value = Snapshot.Attributes[attribute.Id] or Dev.MIN_ATTRIBUTE
            totals.Attribute = totals.Attribute + math.max(0, value - Dev.MIN_ATTRIBUTE)
        end
    end
    return totals
end

local function Points(data)
    return {
        Primary = data:GetDevPoints(gamedataDevelopmentPointType.Primary),
        Attribute = data:GetDevPoints(gamedataDevelopmentPointType.Attribute),
        Espionage = data:GetDevPoints(gamedataDevelopmentPointType.Espionage)
    }
end

local function RemovePerks(data, player, refund)
    local kept = 0
    for _, perk in ipairs(Catalog.Perks) do
        local key = PointKey(perk)
        while data:IsNewPerkBought(perk.Type) > 0 do
            if not Perks.Remove(data, player, perk, true) then
                kept = kept + 1
                break
            end
            refund[key] = refund[key] + perk.Cost
        end
    end
    return kept
end

local function ResetAttributes(data, refund)
    for _, attribute in ipairs(Dev.Attributes) do
        if not attribute.Relic then
            local value = data:GetAttributePoints(Dev.AttributeData(attribute))
            if value > Dev.MIN_ATTRIBUTE then
                data:SetAttribute(gamedataStatType[attribute.Stat], Dev.MIN_ATTRIBUTE)
                refund.Attribute = refund.Attribute + (value - Dev.MIN_ATTRIBUTE)
            end
        end
    end
end

function ForceRespec.Run()
    local data, player = Dev.Data()
    if not data then return end

    if player:IsInCombat() then
        Notify.Warning(L("notify.dev.combat"))
        return
    end

    local before = Points(data)
    local refund = { Primary = 0, Attribute = 0, Espionage = 0 }
    local kept = RemovePerks(data, player, refund)
    ResetAttributes(data, refund)

    for key, amount in pairs(refund) do
        data:SetDevelopmentsPoint(gamedataDevelopmentPointType[key], before[key] + amount)
    end
    for _, attribute in ipairs(Dev.Attributes) do Perks.Relock(data, attribute) end
    data:UpdateUIBB()

    Logger.Log(string.format("Development: force respec refunded %d perk, %d attribute and %d Relic points",
        refund.Primary, refund.Attribute, refund.Espionage))
    Notify.Success(tip("notify.dev.respec", { perk = refund.Primary, attribute = refund.Attribute, relic = refund.Espionage }))
    if kept > 0 then Notify.Warning(tip("notify.dev.kept", { count = kept })) end
end

return ForceRespec
