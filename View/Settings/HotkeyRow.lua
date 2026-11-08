local Widgets = require("Widgets/Widgets")
local Hotkeys = require("Features/Hotkeys/Hotkeys")

local HotkeyRow = {}

local TIPS = {
    [Hotkeys.Kinds.Toggle] = "hotkeys.tips.toggle",
    [Hotkeys.Kinds.Slider] = "hotkeys.tips.slider",
    [Hotkeys.Kinds.Action] = "hotkeys.tips.action"
}

local KINDS = {
    [Hotkeys.Kinds.Toggle] = "hotkeys.kinds.toggle",
    [Hotkeys.Kinds.Slider] = "hotkeys.kinds.slider",
    [Hotkeys.Kinds.Action] = "hotkeys.kinds.action"
}

local s_Docs = setmetatable({}, { __mode = "k" })

local function Status(definition)
    if definition.Kind == Hotkeys.Kinds.Action then return nil end

    local text = L(definition.Target[definition.Field] == true and "hotkeys.info.on" or "hotkeys.info.off")
    if definition.Kind ~= Hotkeys.Kinds.Slider then return text end
    return text .. "  " .. string.format(definition.Format, definition.Target[definition.Value] or 0)
end

local function Notes(doc, definition, binding)
    if Hotkeys.MenuOnly(binding) then
        table.insert(doc, { Kind = "Text", Text = L("hotkeys.info.menuonly"), Tone = "Dim" })
    end

    local other = Hotkeys.SharedWith(definition)
    if other then
        table.insert(doc, { Kind = "Text", Text = tip("hotkeys.info.shared", { name = Hotkeys.Name(other) }), Tone = "Warn" })
    end
end

local function Info(definition)
    local binding = Hotkeys.Binding(definition)
    local keys = Widgets.FormatBinding(binding)
    local status = Status(definition)
    local version = Hotkeys.Version()
    local cached = s_Docs[definition]
    if cached and cached.Keys == keys and cached.Status == status and cached.Version == version then return cached.Doc end

    local doc = {
        { Kind = "Eyebrow", Text = L(definition.Category.Title .. ".label") },
        { Kind = "Title", Text = Hotkeys.Name(definition) },
        { Kind = "Text", Text = L(definition.Tip), Tone = "Soft" },
        { Kind = "Separator" },
        { Kind = "Row", Label = L("hotkeys.info.type"), Value = L(KINDS[definition.Kind]) },
        { Kind = "Row", Label = L("hotkeys.info.hotkey"), Value = keys == "None" and L("hotkeys.info.none") or keys }
    }
    if status then table.insert(doc, { Kind = "Row", Label = L("hotkeys.info.now"), Value = status }) end
    Notes(doc, definition, binding)

    s_Docs[definition] = { Keys = keys, Status = status, Version = version, Doc = doc }
    return doc
end

function HotkeyRow.Draw(definition)
    if Widgets.KeyBind(Hotkeys.Name(definition), Hotkeys.Binding(definition)) then Hotkeys.Changed(definition) end
    if not Widgets.Selected() then return end

    Widgets.Tip(tip(TIPS[definition.Kind], { name = Hotkeys.Name(definition) }))
    Widgets.Info(Info, definition)
end

return HotkeyRow
