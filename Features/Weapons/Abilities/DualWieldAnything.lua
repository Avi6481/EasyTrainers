local DualWieldAnything = {}

DualWieldAnything.Enabled = { value = false }

local s_RangedTag = nil

local function RangedTag()
    s_RangedTag = s_RangedTag or CName.new("RangedWeapon")
    return s_RangedTag
end

function DualWieldAnything.CanDualWield(itemData)
    if not DualWieldAnything.Enabled.value or not itemData then return nil end
    if not itemData:HasTag(RangedTag()) then return nil end
    return true
end

function DualWieldAnything.HasPlayerDualWield()
    if not DualWieldAnything.Enabled.value then return nil end
    return true
end

return DualWieldAnything
