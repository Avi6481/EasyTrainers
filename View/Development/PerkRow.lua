local Ref = require("Core/Ref")
local Widgets = require("Widgets/Widgets")
local Development = require("Features/Development/Development")
local Perks = require("Features/Development/Perks")
local Snapshot = require("Features/Development/Snapshot")
local PerkInfo = require("View/Development/PerkInfo")

local PerkRow = {}

local s_Levels = {}
local s_Refs = {}

local function LevelRef(perk)
    local ref = s_Refs[perk.Key]
    if ref then return ref end

    s_Levels[perk.Key] = { Value = 0 }
    ref = Ref.Field(s_Levels[perk.Key], "Value")
    s_Refs[perk.Key] = ref
    return ref
end

function PerkRow.Draw(perk)
    local force = Development.ForceBuy
    local locked = not force and Snapshot.Locked(perk)
    local ref = LevelRef(perk)
    s_Levels[perk.Key].Value = Snapshot.Level(perk)

    if Widgets.LevelPips(perk.Name, ref, perk.MaxLevel, locked) then
        Development.Queue(Perks.SetLevel, perk, ref.Value, force)
    end
    Widgets.Tip(L(locked and "development.perk.locked" or "development.perk.tip"))
    Widgets.Info(PerkInfo.Get, perk)
end

return PerkRow
