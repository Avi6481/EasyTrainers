local State = require("Core/State")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local Hotkeys = require("Features/Hotkeys/Hotkeys")
local HotkeyRow = require("View/Settings/HotkeyRow")

local HotkeysView = {}

local MAX_LISTED = 10

local s_Menus = {}
local s_Counts = {}
local s_BoundDoc = nil
local s_BoundVersion = nil

local function Count(count)
    if count == 0 then return nil end
    if not s_Counts[count] then s_Counts[count] = tostring(count) end
    return s_Counts[count]
end

local function BoundInfo()
    local version = Hotkeys.Version()
    if s_BoundDoc and s_BoundVersion == version then return s_BoundDoc end

    local bound = Hotkeys.Bound()
    local doc = {
        { Kind = "Eyebrow", Text = L("hotkeys.title") },
        { Kind = "Title", Text = L("hotkeys.bound.label") },
        { Kind = "Separator" }
    }

    if #bound == 0 then table.insert(doc, { Kind = "Text", Text = L("hotkeys.bound.none"), Tone = "Soft" }) end
    for index, definition in ipairs(bound) do
        if index > MAX_LISTED then
            table.insert(doc, { Kind = "Text", Text = tip("hotkeys.bound.more", { count = #bound - MAX_LISTED }), Tone = "Dim" })
            break
        end
        table.insert(doc, { Kind = "Row", Label = Hotkeys.Name(definition), Value = Widgets.FormatBinding(Hotkeys.Binding(definition)) })
    end

    s_BoundDoc = doc
    s_BoundVersion = version
    return doc
end

local function BoundView()
    local bound = Hotkeys.Bound()
    if #bound == 0 then
        Widgets.ValueRow(L("hotkeys.bound.none"), "")
        Widgets.Tip(L("hotkeys.bound.nonetip"))
        return
    end

    for _, definition in ipairs(bound) do HotkeyRow.Draw(definition) end
end

local BoundMenu = Submenu.Create("hotkeys.bound.label", BoundView)

local function CategoryView(category)
    for index, definition in ipairs(category.List) do
        if index > 1 and definition.Break then Widgets.Break(L(definition.Break)) end
        HotkeyRow.Draw(definition)
    end
end

for _, category in ipairs(Hotkeys.Categories) do
    s_Menus[category] = Submenu.Create(category.Title .. ".label", function() CategoryView(category) end)
end

local function Links()
    Widgets.SubmenuButton(L("hotkeys.bound.label"), BoundMenu, Count(#Hotkeys.Bound()))
    Widgets.Tip(L("hotkeys.bound.tip"))
    Widgets.Info(BoundInfo)

    for _, category in ipairs(Hotkeys.Categories) do
        Widgets.SubmenuButton(L(category.Title .. ".label"), s_Menus[category], Count(Hotkeys.BoundIn(category)))
        if Widgets.Selected() then Widgets.Tip(tip("hotkeys.category.tip", { name = category.Title .. ".label" })) end
    end
end

local function View()
    Links()

    Widgets.Break("")
    if Widgets.KeyBind(L("navigation.togglemenu.label"), State.Hotkeys.ToggleMenu) then Hotkeys.MenuChanged() end
    Widgets.Tip(L("navigation.togglemenu.tip"))
    if Widgets.HoldButton(L("hotkeys.clearall.label")) then Hotkeys.ClearAll() end
    Widgets.Tip(L("hotkeys.clearall.tip"))
end

HotkeysView.Menu = Submenu.Create("hotkeys.title", View)

function HotkeysView.BoundInfo()
    return BoundInfo()
end

return HotkeysView
