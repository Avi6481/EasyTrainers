-- Utils/Weapon.lua
local Weapon = {
    isAiming = false,
    isShooting = false,
    lastWeaponID = nil,
    lastItemKey = nil,
    hasChanged = false,
    snapshotValid = false,
    currentItem = nil,
    currentItemData = nil,
    currentItemID = nil,
    currentIsRanged = false,
    currentIsMelee = false,
    lastCheckTime = 0,
    checkInterval = 1
}

function Weapon.HandleInputAction(action)
    local player = Game.GetPlayer()
    if not player then return end

    Weapon.isAiming = player.isAiming

    local actionName = Game.NameToString(action:GetName(action))
    local actionType = action:GetType(action).value

    if actionName == "RangedAttack" then
        if actionType == "BUTTON_PRESSED" then
            Weapon.isShooting = true
        elseif actionType == "BUTTON_RELEASED" then
            Weapon.isShooting = false
        end
    end
end

function Weapon.IsPlayerAiming()
    return Weapon.isAiming
end

function Weapon.IsPlayerShooting()
    return Weapon.isShooting
end

-- Get all ranged weapons in inventory (returns { {id, data}, ... })
function Weapon.GetAllRangedWeapons()
    local player = Game.GetPlayer()
    local ts = Game.GetTransactionSystem()
    if not player or not ts then return {} end

    local success, allItems = ts:GetItemList(player)
    if not success or type(allItems) ~= "table" then
        return {}
    end

    local ranged = {}
    for _, itemData in ipairs(allItems) do
        if itemData
            and itemData:HasTag(CName("Weapon"))
            and itemData:HasTag(CName("RangedWeapon")) then
            table.insert(ranged, {
                id   = itemData:GetID(),
                data = itemData
            })
        end
    end
    return ranged
end

local function ReadEquippedRightHand()
    local player = Game.GetPlayer()
    local ts = Game.GetTransactionSystem()
    if not player or not ts then return nil, nil, nil end

    local item = ts:GetItemInSlot(player, "AttachmentSlots.WeaponRight")
    if not item then return nil, nil, nil end

    local itemData = item:GetItemData()
    if not itemData then return item, nil, item:GetItemID() end

    return item, itemData, item:GetItemID()
end

-- Get equipped right-hand weapon (returns {item, itemData, itemID} or nils).
-- Weapon.Tick caches this lookup for the rest of the frame because every enabled
-- weapon modifier asks for the same data while processing a weapon switch.
function Weapon.GetEquippedRightHand()
    if Weapon.snapshotValid then
        return Weapon.currentItem, Weapon.currentItemData, Weapon.currentItemID
    end

    return ReadEquippedRightHand()
end

function Weapon.IsRangedEquipped()
    if Weapon.snapshotValid then
        return Weapon.currentIsRanged
    end

    local _, itemData = Weapon.GetEquippedRightHand()
    return itemData and itemData:HasTag(CName("RangedWeapon")) or false
end

function Weapon.IsMeleeEquipped()
    if Weapon.snapshotValid then
        return Weapon.currentIsMelee
    end

    local _, itemData = Weapon.GetEquippedRightHand()
    return itemData and itemData:HasTag(CName("Melee")) or false -- Actually don't remember if the tags include this word but I assume they would
end

function Weapon.IsShootingRangedADS()
    return Weapon.isAiming
       and Weapon.isShooting
       and Weapon.IsRangedEquipped()
end

function Weapon.IsShootingRanged()
    return Weapon.isShooting and Weapon.IsRangedEquipped()
end

function Weapon.Tick(deltaTime)
    if not Weapon.snapshotValid then
        local item, itemData, itemID = ReadEquippedRightHand()
        Weapon.currentItem = item
        Weapon.currentItemData = itemData
        Weapon.currentItemID = itemID
        Weapon.currentIsRanged = itemData and itemData:HasTag(CName("RangedWeapon")) or false
        Weapon.currentIsMelee = itemData and itemData:HasTag(CName("Melee")) or false
        Weapon.snapshotValid = true
    end

    local itemData = Weapon.currentItemData
    local itemID = Weapon.currentItemID
    if not itemID then
        if Weapon.lastItemKey ~= nil then
            Weapon.lastItemKey = nil
            Weapon.lastWeaponID = nil
            Weapon.hasChanged = true
        end
        return
    end

    local itemKey = tostring(itemID)
    if itemKey ~= Weapon.lastItemKey then
        Weapon.hasChanged = true
        Weapon.lastItemKey = itemKey
        Weapon.lastWeaponID = itemData and itemData:GetStatsObjectID() or nil
    end
end

function Weapon.HasChanged()
    return Weapon.hasChanged
end

-- Keep a queued weapon refresh visible to one modifier on a later update.
-- CET game API calls stay on onUpdate; the scheduler in Features/Weapons/Tick
-- uses this to spread expensive modifier rebuilds across separate frames.
function Weapon.MarkChanged()
    Weapon.hasChanged = true
end

function Weapon.EndFrame()
    Weapon.hasChanged = false
    Weapon.snapshotValid = false
    Weapon.currentItem = nil
    Weapon.currentItemData = nil
    Weapon.currentItemID = nil
    Weapon.currentIsRanged = false
    Weapon.currentIsMelee = false
end


function Weapon.GetCurrentWeaponID()
    return Weapon.lastWeaponID
end

return Weapon
