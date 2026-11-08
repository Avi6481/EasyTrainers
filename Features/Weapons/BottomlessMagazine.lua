local Weapon = require("Utils/Weapon")

local BottomlessMagazine = {
    Enabled = false
}

local function Refill(weapon)
    local capacity = WeaponObject.GetMagazineCapacity(weapon)
    if capacity <= 0 or WeaponObject.GetMagazineAmmoCount(weapon) >= capacity then return end

    local event = SetAmmoCountEvent.new()
    event.ammoTypeID = WeaponObject.GetAmmoType(weapon)
    event.count = capacity
    weapon:QueueEvent(event)
end

local function Hand(hand)
    if hand.Ranged and hand.Item then pcall(Refill, hand.Item) end
end

function BottomlessMagazine.Update()
    if not BottomlessMagazine.Enabled then return end
    Hand(Weapon.Right)
    Hand(Weapon.Left)
end

return BottomlessMagazine
