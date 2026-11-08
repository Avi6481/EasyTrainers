local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local Dev = require("Features/Development/Dev")
local Catalog = require("Features/Development/Catalog")
local Development = require("Features/Development/Development")
local Snapshot = require("Features/Development/Snapshot")
local Attributes = require("Features/Development/Attributes")
local Points = require("Features/Development/Points")
local Money = require("Features/Development/Money")
local ForceRespec = require("Features/Development/ForceRespec")
local AttributeView = require("View/Development/AttributeView")
local SkillsView = require("View/Development/SkillsView")
local PerkSearchView = require("View/Development/PerkSearchView")

local DevelopmentView = {}

local s_ForceBuy = Ref.Field(Development, "ForceBuy")
local s_Points = {}
local s_PointRefs = {}
local s_Money = { Value = "" }
local s_MoneyRef = Ref.Field(s_Money, "Value")
local s_MoneyShownFor = nil
local s_MoneyShown = ""
local s_RespecDoc = nil
local s_RespecSignature = nil

for _, point in ipairs(Dev.Points) do
    s_Points[point.Id] = { Value = 0 }
    s_PointRefs[point.Id] = Ref.Field(s_Points[point.Id], "Value")
end

local function Badge(attribute)
    local owned = Snapshot.Owned[attribute.Id] or 0
    local total = #(Catalog.ByAttribute[attribute.Id] or {})
    if attribute.Relic then return string.format("%d/%d", owned, total) end
    return string.format("%d  |  %d/%d", Snapshot.Attributes[attribute.Id] or 0, owned, total)
end

local function AttributeLinks()
    for _, attribute in ipairs(Dev.Attributes) do
        if not attribute.Relic or Snapshot.RelicUnlocked then
            local key = "development.attributes." .. attribute.Id:lower()
            Widgets.SubmenuButton(L(key .. ".label"), AttributeView.Menu(attribute), Badge(attribute))
            Widgets.Tip(L(key .. ".tip"))
        end
    end

    Widgets.SubmenuButton(L("development.skills.title"), SkillsView.Menu, tip("development.skills.badge", { level = Snapshot.Skills.Level or 1 }))
    Widgets.Tip(L("development.skills.tip"))
    Widgets.SubmenuButton(L("development.search.title"), PerkSearchView.Menu)
    Widgets.Tip(L("development.search.tip"))
end

local function PointSlider(point)
    local key = "development.points." .. point.Id:lower()
    local ref = s_PointRefs[point.Id]
    local current = Snapshot.Points[point.Id] or 0
    s_Points[point.Id].Value = current

    if Widgets.SliderInt(L(key .. ".label"), ref, 0, math.max(point.Max, current), 1, "%d") then
        Development.Queue(Points.Set, point, ref.Value)
    end
    Widgets.Tip(L(key .. ".tip"))
end

local function Digit(character)
    return character:match("^%d$") ~= nil
end

local function Grouped(value)
    if s_MoneyShownFor ~= value then
        s_MoneyShownFor = value
        s_MoneyShown = tostring(math.floor(value)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    end
    return s_MoneyShown
end

local function MoneyInput()
    s_Money.Value = Grouped(Snapshot.Money or 0)
    if Widgets.InputText(L("development.points.eddies.label"), s_MoneyRef, 13, "0", Digit) then
        local value = tonumber((s_MoneyRef.Value:gsub("%D", "")))
        if value then Development.Queue(Money.Set, value) end
    end
    Widgets.Tip(L("development.points.eddies.tip"))
end

local function RespecInfo()
    local totals = ForceRespec.Totals()
    local relic = Snapshot.RelicUnlocked
    local signature = totals.Primary + (totals.Attribute * 1000) + (totals.Espionage * 1000000) + (relic and 0.5 or 0)
    if s_RespecDoc and s_RespecSignature == signature then return s_RespecDoc end

    s_RespecDoc = {
        { Kind = "Eyebrow", Text = L("development.forcerespec.eyebrow") },
        { Kind = "Title", Text = L("development.forcerespec.title") },
        { Kind = "Separator" },
        { Kind = "Row", Label = L("development.points.perk.label"), Value = tostring(totals.Primary) },
        { Kind = "Row", Label = L("development.points.attribute.label"), Value = tostring(totals.Attribute) }
    }
    if relic then
        table.insert(s_RespecDoc, { Kind = "Row", Label = L("development.points.relic.label"), Value = tostring(totals.Espionage) })
    end
    table.insert(s_RespecDoc, { Kind = "Text", Text = L("development.forcerespec.note"), Tone = "Soft" })
    s_RespecSignature = signature
    return s_RespecDoc
end

local function View()
    Development.Watch()
    if not Snapshot.Ready then
        Widgets.ValueRow(L("development.loading"), "")
        return
    end

    AttributeLinks()

    Widgets.Break(L("development.points.title"))
    for _, point in ipairs(Dev.Points) do
        if not point.Relic or Snapshot.RelicUnlocked then PointSlider(point) end
    end
    MoneyInput()

    Widgets.Break(L("development.options"))
    Widgets.Toggle(L("development.forcebuy.label"), s_ForceBuy)
    Widgets.Tip(L("development.forcebuy.tip"))

    if Widgets.HoldButton(L("development.maxeverything.label")) then
        Development.Queue(Attributes.MaxEverything, Development.ForceBuy)
    end
    Widgets.Tip(L("development.maxeverything.tip"))

    if Widgets.HoldButton(L("development.forcerespec.label")) then Development.Queue(ForceRespec.Run) end
    Widgets.Tip(L("development.forcerespec.tip"))
    Widgets.Info(RespecInfo)
end

DevelopmentView.Menu = Submenu.Create("development.title", View)

return DevelopmentView
