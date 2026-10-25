local Weapon = {}

local REFRESH_INTERVAL = 0.2

local s_IsShooting = false
local s_RangedAttack = nil
local s_NextRefresh = 0
local s_Item = nil
local s_ItemData = nil
local s_ItemID = nil
local s_IsRanged = false
local s_IsMelee = false
local s_LastItemID = nil
local s_Generation = 0
local s_Left = { Item = nil, ItemData = nil, ItemID = nil, IsRanged = false, LastItemID = nil, Generation = 0 }

local function RangedAttackName()
    s_RangedAttack = s_RangedAttack or CName.new("RangedAttack")
    return s_RangedAttack
end

local function IsRangedAttack(name)
    local target = RangedAttackName()
    return name ~= nil and name.hash_lo == target.hash_lo and name.hash_hi == target.hash_hi
end

function Weapon.HandleInputAction(action)
    if not IsRangedAttack(action:GetName(action)) then return end

    local actionType = action:GetType(action).value
    if actionType == "BUTTON_PRESSED" or actionType == "TOGGLE_PRESSED" then
        s_IsShooting = true
    elseif actionType == "BUTTON_RELEASED" or actionType == "TOGGLE_RELEASED" then
        s_IsShooting = false
    elseif actionType == "AXIS_CHANGE" then
        s_IsShooting = (action:GetValue(action) or 0) > 0.5
    end
end

function Weapon.ResetInput()
    s_IsShooting = false
end

function Weapon.IsPlayerShooting()
    return s_IsShooting
end

local function HasTag(itemData, tag)
    return itemData and itemData:HasTag(CName(tag)) or false
end

local function TrackChange()
    if s_ItemID == nil and s_LastItemID == nil then return end
    if s_ItemID ~= nil and s_LastItemID ~= nil and s_ItemID == s_LastItemID then return end

    s_Generation = s_Generation + 1
    s_LastItemID = s_ItemID
end

local function RefreshLeft(player, transactionSystem)
    local item = player and transactionSystem and transactionSystem:GetItemInSlot(player, "AttachmentSlots.WeaponLeft") or nil
    s_Left.Item = item
    s_Left.ItemData = item and item:GetItemData() or nil
    s_Left.ItemID = item and item:GetItemID() or nil
    s_Left.IsRanged = HasTag(s_Left.ItemData, "RangedWeapon")

    if s_Left.ItemID == nil and s_Left.LastItemID == nil then return end
    if s_Left.ItemID ~= nil and s_Left.LastItemID ~= nil and s_Left.ItemID == s_Left.LastItemID then return end

    s_Left.Generation = s_Left.Generation + 1
    s_Left.LastItemID = s_Left.ItemID
end

local function Refresh()
    local now = os.clock()
    if now < s_NextRefresh then return end
    s_NextRefresh = now + REFRESH_INTERVAL

    s_Item, s_ItemData, s_ItemID = nil, nil, nil
    local player = Game.GetPlayer()
    local transactionSystem = Game.GetTransactionSystem()
    local item = player and transactionSystem and transactionSystem:GetItemInSlot(player, "AttachmentSlots.WeaponRight") or nil
    if item then
        s_Item = item
        s_ItemData = item:GetItemData()
        s_ItemID = item:GetItemID()
    end

    s_IsRanged = HasTag(s_ItemData, "RangedWeapon")
    s_IsMelee = HasTag(s_ItemData, "Melee")
    TrackChange()
    RefreshLeft(player, transactionSystem)
end

function Weapon.Tick()
    Refresh()
end

function Weapon.GetEquippedRightHand()
    Refresh()
    return s_Item, s_ItemData, s_ItemID
end

function Weapon.GetEquippedLeftHand()
    Refresh()
    return s_Left.Item, s_Left.ItemData, s_Left.ItemID
end

function Weapon.IsLeftRangedEquipped()
    Refresh()
    return s_Left.IsRanged
end

function Weapon.GetLeftItemKey()
    if s_Left.LastItemID == nil then return nil end
    return s_Left.Generation
end

function Weapon.IsRangedEquipped()
    Refresh()
    return s_IsRanged
end

function Weapon.IsMeleeEquipped()
    Refresh()
    return s_IsMelee
end

function Weapon.IsShootingRanged()
    return s_IsShooting and Weapon.IsRangedEquipped()
end

function Weapon.GetCurrentItemKey()
    if s_LastItemID == nil then return nil end
    return s_Generation
end

function Weapon.Invalidate()
    s_NextRefresh = 0
end

return Weapon
