local Arsenal = require("Features/Weapons/Arsenal")
local Catalog = require("Features/Weapons/Catalog")

local WeaponItemInfo = {}

local s_Docs = setmetatable({}, { __mode = "k" })
local s_Slots = {}
local s_Unlisted = setmetatable({}, { __mode = "k" })
local s_Owned = nil
local s_OwnedVersion = nil

local function Row(doc, key, value, tone)
    if value == nil or value == "" then return end
    table.insert(doc, { Kind = "Row", Label = L("weapons.items.info." .. key), Value = tostring(value), Tone = tone })
end

local function Format(value, pattern, suffix)
    if not value then return nil end
    return string.format(pattern, value) .. (suffix or "")
end

local function Positive(value, pattern, suffix)
    if not value or value <= 0 then return nil end
    return Format(value, pattern, suffix)
end

local function ClassName(weapon)
    if not weapon.Class then return L("weapons.items.info.standard") end
    return L("weapons.items.classes." .. weapon.Class:lower())
end

local function Stats(doc, stats)
    local pellets = stats.Pellets > 1 and (" x" .. tostring(math.floor(stats.Pellets))) or nil
    table.insert(doc, { Kind = "Heading", Text = L("weapons.items.info.stats") })
    Row(doc, "damage", Format(stats.Damage, "%.0f", pellets))
    Row(doc, "firerate", Format(stats.FireRate, "%.2f", "/s"))
    Row(doc, "dps", Format(stats.DPS, "%.0f"))
    Row(doc, "magazine", Positive(stats.Magazine, "%.0f"))
    Row(doc, "reload", Positive(stats.Reload, "%.2f", "s"))
    Row(doc, "range", Positive(stats.Range, "%.0f", "m"))
    Row(doc, "crit", Format(stats.CritChance, "%.0f", "%"))
    Row(doc, "headshot", Format(stats.Headshot, "x%.1f"))
end

local function Build(weapon, owned, stats)
    local doc = {
        { Kind = "Eyebrow", Text = weapon.Iconic and L("weapons.items.info.iconic") or weapon.Tier },
        { Kind = "Title", Text = weapon.Name },
        { Kind = "Separator" }
    }
    if weapon.Icon then table.insert(doc, { Kind = "Image", Image = weapon.Icon }) end

    Row(doc, "type", weapon.Type)
    Row(doc, "tier", weapon.Tier)
    Row(doc, "class", ClassName(weapon))
    Row(doc, "manufacturer", weapon.Manufacturer)
    Row(doc, "wall", L(weapon.Wall and "weapons.items.info.yes" or "weapons.items.info.no"), weapon.Wall and "Text" or "Soft")
    Row(doc, "owned", owned > 0 and ("x" .. tostring(owned)) or L("weapons.items.info.no"), owned > 0 and "Strong" or "Soft")
    if stats then Stats(doc, stats) end

    if weapon.Description and weapon.Description ~= "" then
        table.insert(doc, { Kind = "Text", Text = weapon.Description, Tone = "Soft" })
    end
    table.insert(doc, { Kind = "Text", Text = weapon.Id, Tone = "Dim" })
    if owned == 0 then table.insert(doc, { Kind = "Text", Text = L("weapons.items.info.note"), Tone = "Dim" }) end
    return doc
end

function WeaponItemInfo.Get(weapon)
    local owned = Arsenal.Count(weapon)
    local stats = Arsenal.Stats(weapon)
    local cached = s_Docs[weapon]
    if cached and cached.Owned == owned and cached.Stats == stats and cached.Resolved == weapon.Resolved then return cached.Doc end

    cached = { Owned = owned, Stats = stats, Resolved = weapon.Resolved, Doc = Build(weapon, owned, stats) }
    s_Docs[weapon] = cached
    return cached.Doc
end

function WeaponItemInfo.Slot(label)
    local doc = s_Slots[label]
    if doc then return doc end

    doc = {
        { Kind = "Eyebrow", Text = L("weapons.items.loadout.title") },
        { Kind = "Title", Text = label },
        { Kind = "Separator" },
        { Kind = "Text", Text = L("weapons.items.info.emptyslot"), Tone = "Soft" },
        { Kind = "Text", Text = L("weapons.items.info.emptynote"), Tone = "Dim" }
    }
    s_Slots[label] = doc
    return doc
end

function WeaponItemInfo.Unlisted(entry)
    local doc = s_Unlisted[entry]
    if doc then return doc end

    doc = {
        { Kind = "Eyebrow", Text = L("weapons.items.loadout.title") },
        { Kind = "Title", Text = entry.Name },
        { Kind = "Separator" },
        { Kind = "Text", Text = L("weapons.items.info.unlisted"), Tone = "Soft" },
        { Kind = "Text", Text = entry.Record, Tone = "Dim" }
    }
    s_Unlisted[entry] = doc
    return doc
end

function WeaponItemInfo.Owned()
    if s_Owned and s_OwnedVersion == Arsenal.OwnedVersion then return s_Owned end

    s_Owned = {
        { Kind = "Eyebrow", Text = L("weapons.items.loadout.title") },
        { Kind = "Title", Text = L("weapons.items.loadout.owned.label") },
        { Kind = "Separator" }
    }
    Row(s_Owned, "kinds", tostring(Arsenal.Kinds), Arsenal.Kinds > 0 and "Strong" or "Soft")
    Row(s_Owned, "copies", tostring(Arsenal.Copies))
    Row(s_Owned, "iconicowned", tostring(Arsenal.IconicOwned))
    Row(s_Owned, "wallowned", tip("weapons.items.info.outof", { count = Arsenal.WallOwned, total = #Catalog.Wall }))
    table.insert(s_Owned, { Kind = "Text", Text = L("weapons.items.info.ownednote"), Tone = "Dim" })
    s_OwnedVersion = Arsenal.OwnedVersion
    return s_Owned
end

return WeaponItemInfo
