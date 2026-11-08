local DualWield = {
    Enabled = false
}

local s_Ranged = nil

local function Ranged()
    s_Ranged = s_Ranged or CName.new("RangedWeapon")
    return s_Ranged
end

local function CanDualWield(itemData, owner, wrapped)
    if DualWield.Enabled and itemData and itemData:HasTag(Ranged()) then return true end
    return wrapped(owner)
end

local function HasPlayerDualWield(_, wrapped)
    if DualWield.Enabled then return true end
    return wrapped()
end

function DualWield.Initialize()
    Override("gameItemData", "CanDualWield", CanDualWield)
    Override("InventoryDataManagerV2", "HasPlayerDualWield", HasPlayerDualWield)
end

return DualWield
