local Weapon = {}

local REFRESH = 0.2
local SLOTS = { Right = "AttachmentSlots.WeaponRight", Left = "AttachmentSlots.WeaponLeft" }

local function NewHand()
    return { Item = nil, Data = nil, StatsID = nil, Record = nil, Key = nil, Version = 0, Ranged = false, Melee = false }
end

Weapon.Right = NewHand()
Weapon.Left = NewHand()

local s_NextRefresh = 0
local s_Shooting = false
local s_RangedAttack = nil
local s_Tags = nil

local function Tags()
    if not s_Tags then
        s_Tags = { Ranged = CName.new("RangedWeapon"), Melee = CName.new("Melee") }
    end
    return s_Tags
end

local function Clear(hand)
    if hand.Key == nil then return end
    hand.Item, hand.Data, hand.StatsID, hand.Record, hand.Key = nil, nil, nil, nil, nil
    hand.Ranged, hand.Melee = false, false
    hand.Version = hand.Version + 1
end

local function Read(hand, player, system, slot)
    local ok, item = pcall(function() return system:GetItemInSlot(player, slot) end)
    if not ok or not item then return Clear(hand) end

    local data = item:GetItemData()
    local id = item:GetItemID()
    if not data or not id then return Clear(hand) end

    local record = TDBID.ToStringDEBUG(id.id)
    local key = record .. "/" .. tostring(id.rngSeed)
    if key == hand.Key then return end

    local tags = Tags()
    hand.Item = item
    hand.Data = data
    hand.StatsID = data:GetStatsObjectID()
    hand.Record = record
    hand.Key = key
    hand.Ranged = data:HasTag(tags.Ranged)
    hand.Melee = data:HasTag(tags.Melee)
    hand.Version = hand.Version + 1
end

function Weapon.Update(player, now)
    if now < s_NextRefresh then return end
    s_NextRefresh = now + REFRESH

    local system = Game.GetTransactionSystem()
    if not system then return end
    Read(Weapon.Right, player, system, SLOTS.Right)
    Read(Weapon.Left, player, system, SLOTS.Left)
end

function Weapon.Refresh()
    s_NextRefresh = 0
end

function Weapon.Name(hand)
    if not hand.Data then return nil end
    local ok, name = pcall(function() return hand.Data:GetNameAsString() end)
    if ok and name and name ~= "" then return name end
    return hand.Record
end

local function RangedAttack(name)
    s_RangedAttack = s_RangedAttack or CName.new("RangedAttack")
    return name ~= nil and name.hash_lo == s_RangedAttack.hash_lo and name.hash_hi == s_RangedAttack.hash_hi
end

function Weapon.Action(action)
    if not RangedAttack(action:GetName(action)) then return end

    local kind = action:GetType(action).value
    if kind == "BUTTON_PRESSED" or kind == "TOGGLE_PRESSED" then
        s_Shooting = true
    elseif kind == "BUTTON_RELEASED" or kind == "TOGGLE_RELEASED" then
        s_Shooting = false
    elseif kind == "AXIS_CHANGE" then
        s_Shooting = (action:GetValue(action) or 0) > 0.5
    end
end

function Weapon.Ranged()
    return Weapon.Right.Ranged or Weapon.Left.Ranged
end

function Weapon.DualWielding()
    return Weapon.Right.Ranged and Weapon.Left.Ranged
end

function Weapon.Shooting()
    return s_Shooting and Weapon.Ranged()
end

function Weapon.Reset()
    Clear(Weapon.Right)
    Clear(Weapon.Left)
    s_Shooting = false
    s_NextRefresh = 0
end

return Weapon
