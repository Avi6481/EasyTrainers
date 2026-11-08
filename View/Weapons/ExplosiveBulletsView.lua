local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local Weapons = require("Features/Weapons/Weapons")

local ExplosiveBulletsView = {}

local Explosive = Weapons.ExplosiveBullets

local KEY = "weapons.explosivebullets."

local s_Enabled = Ref.Field(Explosive, "Enabled")
local s_Type = Ref.Field(Explosive, "Type")
local s_Damage = Ref.Field(Explosive, "Damage")
local s_Rate = Ref.Field(Explosive, "Rate")
local s_Chance = Ref.Field(Explosive, "Chance")
local s_OnEnemies = Ref.Field(Explosive, "OnEnemies")
local s_OnSurfaces = Ref.Field(Explosive, "OnSurfaces")
local s_Types = nil

local function Types()
    if s_Types then return s_Types end

    s_Types = {}
    for index, entry in ipairs(Explosive.Types) do
        s_Types[index] = { Label = L(KEY .. "types." .. entry.Key), Tip = "" }
    end
    return s_Types
end

local function Toggle(key, ref)
    Widgets.Toggle(L(KEY .. key .. ".label"), ref)
    Widgets.Tip(L(KEY .. key .. ".tip"))
end

local function Slider(key, ref, min, max, step, format)
    Widgets.SliderInt(L(KEY .. key .. ".label"), ref, min, max, step, format)
    Widgets.Tip(L(KEY .. key .. ".tip"))
end

local function View()
    Widgets.Toggle(L(KEY .. "label"), s_Enabled)
    Widgets.Tip(L(KEY .. "tip"))
    Widgets.Dropdown(L(KEY .. "type.label"), s_Type, Types())
    Widgets.Tip(L(KEY .. "type.tip"))

    Widgets.Break(L(KEY .. "explosions"))
    Slider("damage", s_Damage, 0, 5000, 100, "%d%%")
    Slider("rate", s_Rate, 1, 25, 1, "%d/s")
    Slider("chance", s_Chance, 5, 100, 5, "%d%%")
    Toggle("onenemies", s_OnEnemies)
    Toggle("onsurfaces", s_OnSurfaces)
end

ExplosiveBulletsView.Menu = Submenu.Create("weapons.explosivebullets.label", View)

return ExplosiveBulletsView
