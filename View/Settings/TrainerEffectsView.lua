local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local Hotkeys = require("Features/Hotkeys/Hotkeys")
local TrainerEffects = require("Features/Settings/TrainerEffects")

local TrainerEffectsView = {}

local Kinds = TrainerEffects.Kinds

local INPUTS = {
    { Field = "Keys", Key = "effects.info.keys" },
    { Field = "Buttons", Key = "effects.info.buttons" },
    { Field = "Sticks", Key = "effects.info.sticks" },
    { Field = "Mouse", Key = "effects.info.mouse" }
}

local s_Values = setmetatable({}, { __mode = "k" })
local s_Docs = setmetatable({}, { __mode = "k" })
local s_Tips = setmetatable({}, { __mode = "k" })
local s_Counts = {}

local function Value(entry)
    local text = s_Values[entry]
    if text then return text end

    text = L(entry.Target)
    if entry.Count then text = tip("effects.value", { target = entry.Target, count = entry.Count }) end
    s_Values[entry] = text
    return text
end

local function Tip(entry)
    local text = s_Tips[entry]
    if text then return text end

    text = L("effects.row.returntip")
    if entry.Definition then
        text = tip("effects.row.tip", { name = Hotkeys.Name(entry.Definition) })
    elseif entry.Kind == Kinds.Weather then
        text = L("effects.row.weathertip")
    end
    s_Tips[entry] = text
    return text
end

local function Details(doc, entry)
    if entry.Kind == Kinds.Stat then
        table.insert(doc, { Kind = "Heading", Text = L("effects.info.stats") })
        for _, stat in ipairs(TrainerEffects.Stats(entry)) do
            table.insert(doc, { Kind = "Row", Label = stat.Label, Value = stat.Value })
        end
        return
    end

    if entry.Kind == Kinds.Hold then
        table.insert(doc, { Kind = "Heading", Text = L("effects.info.blocked") })
        for _, input in ipairs(INPUTS) do
            local count = entry.Inputs[input.Field]
            if count > 0 then table.insert(doc, { Kind = "Row", Label = L(input.Key), Value = tostring(count) }) end
        end
        return
    end

    if entry.Kind == Kinds.Weather and entry.State ~= "" then
        table.insert(doc, { Kind = "Row", Label = L("effects.info.weather"), Value = entry.State })
    end
end

local function Info(entry)
    local cached = s_Docs[entry]
    if cached then return cached end

    local option = entry.Definition and Hotkeys.Name(entry.Definition) or L("hotkeys.info.none")
    local doc = {
        { Kind = "Eyebrow", Text = L("effects.title") },
        { Kind = "Title", Text = entry.Name },
        { Kind = "Separator" },
        { Kind = "Row", Label = L("effects.info.target"), Value = L(entry.Target) },
        { Kind = "Row", Label = L("effects.info.option"), Value = option }
    }
    Details(doc, entry)

    local note = "effects.info.turnsoff"
    if TrainerEffects.Returns(entry) then note = "effects.info.mayreturn" end
    if entry.Kind == Kinds.Weather then note = "effects.info.weathernote" end
    table.insert(doc, { Kind = "Text", Text = L(note), Tone = TrainerEffects.Returns(entry) and "Warn" or "Dim" })

    s_Docs[entry] = doc
    return doc
end

local function View()
    if Widgets.HoldButton(L("effects.clearall.label")) then TrainerEffects.ClearAll() end
    Widgets.Tip(L("effects.clearall.tip"))

    Widgets.Break(L("effects.active"))
    local list = TrainerEffects.List()
    if #list == 0 then
        Widgets.ValueRow(L("effects.none.label"), "")
        Widgets.Tip(L("effects.none.tip"))
        return
    end

    for _, entry in ipairs(list) do
        if Widgets.ValueRow(entry.Name, Value(entry), true) then TrainerEffects.Remove(entry) end
        if Widgets.Selected() then
            Widgets.Tip(Tip(entry))
            Widgets.Info(Info, entry)
        end
    end
end

TrainerEffectsView.Menu = Submenu.Create("effects.title", View)

function TrainerEffectsView.Count()
    local count = #TrainerEffects.List()
    if count == 0 then return nil end
    if not s_Counts[count] then s_Counts[count] = tostring(count) end
    return s_Counts[count]
end

return TrainerEffectsView
