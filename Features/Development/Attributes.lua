local Dev = require("Features/Development/Dev")
local Catalog = require("Features/Development/Catalog")
local Perks = require("Features/Development/Perks")
local Notify = require("Utils/Notify")

local Attributes = {}

local function ClearAbove(data, player, attribute, value)
    local list = Catalog.ByAttribute[attribute.Id] or {}
    for index = #list, 1, -1 do
        local perk = list[index]
        if perk.Required > value then
            while data:IsNewPerkBought(perk.Type) > 0 do
                if not Perks.Remove(data, player, perk, true) then return false end
            end
        end
    end
    return true
end

local function Charge(data, delta, force)
    if force or delta == 0 then return true end

    local pointType = gamedataDevelopmentPointType.Attribute
    if delta > 0 and data:GetDevPoints(pointType) < delta then
        Notify.Warning(L("notify.dev.points"))
        return false
    end
    data:AddDevelopmentPoints(-delta, pointType)
    return true
end

function Attributes.Set(attribute, value, force)
    if attribute.Relic then return false end

    local data, player = Dev.Data()
    if not data then return false end

    local current = data:GetAttributePoints(Dev.AttributeData(attribute))
    value = math.max(Dev.MIN_ATTRIBUTE, math.min(Dev.MAX_ATTRIBUTE, value))
    if value == current then return true end

    local done = true
    if value < current and not force then
        if player:IsInCombat() then
            Notify.Warning(L("notify.dev.combat"))
            return false
        end
        done = ClearAbove(data, player, attribute, value)
    end

    if done and Charge(data, value - current, force) then
        data:SetAttribute(gamedataStatType[attribute.Stat], value)
    else
        done = false
    end

    Perks.Relock(data, attribute)
    data:UpdateUIBB()
    return done
end

function Attributes.MaxEverything(force)
    for _, attribute in ipairs(Dev.Attributes) do
        if attribute.Relic then
            if Dev.RelicUnlocked() then Perks.MaxAll(attribute, force) end
        elseif Attributes.Set(attribute, Dev.MAX_ATTRIBUTE, force) then
            Perks.MaxAll(attribute, force)
        end
    end
end

return Attributes
