local Dropdown = require("UI/Widgets/Dropdown/Dropdown")
local Button = require("UI/Widgets/Button/Button")
local Toggle = require("UI/Widgets/Toggle/Toggle")
local Break = require("UI/Widgets/Break/Break")
local SubmenuButton = require("UI/Widgets/SubmenuButton/SubmenuButton")
local Registry = require("UI/Registry/OptionRegistry")
local Option = {}

function Option.Dropdown(label, valueRef, items, tip, action, id)
    id = id or label
    Registry.Observe(id, {
        Kind = Registry.Kind.Dropdown,
        Ref = valueRef,
        Label = label,
        Tip = tip,
        Action = action,
    })
    return Dropdown.Option(id, label, valueRef, items, tip, action)
end

function Option.Button(label, tip, action, id)
    if id then Registry.Observe(id, { Kind = Registry.Kind.Button, Label = label, Tip = tip, Action = action }) end
    local activated = Button.Draw(label, tip, nil, id)
    if activated and action then action() end
    return activated
end

function Option.Toggle(label, valueRef, tip, action, id)
    Registry.Observe(id or valueRef, {
        Kind = Registry.Kind.Toggle,
        Label = label,
        Tip = tip,
        Action = action,
    })
    local changed = Toggle.Draw(label, valueRef, tip, id)
    if changed then
        Registry.MarkChanged(id or valueRef)
        if action then action(valueRef.value) end
    end
    return changed
end

function Option.Submenu(label, submenu, tip, action, id)
    if id then Registry.Observe(id, { Kind = Registry.Kind.Submenu, Label = label, Tip = tip, Action = action }) end
    local opened = SubmenuButton.Draw(label, submenu, tip, id)
    if opened and action then action() end
    return opened
end

function Option.Break(label, alignment)
    Break.Draw(label, alignment)
end

function Option.Spec(kind, label, options)
    options = options or {}
    options.Kind = kind
    options.Label = label or ""
    return options
end

function Option.Register(spec)
    return Registry.Register(spec)
end

function Option.DrawRegistered(id)
    local entry = Registry.Get(id)
    if not entry then return false end

    local label = Registry.GetLabel(entry)
    local tip = Registry.GetTip(entry)
    if entry.Kind == Registry.Kind.Toggle then
        return Option.Toggle(label, entry.Ref, tip, entry.Action, entry.Id)
    elseif entry.Kind == Registry.Kind.Dropdown then
        return Option.Dropdown(label, entry.Ref, entry.Items or {}, tip, entry.Action, entry.Id)
    elseif entry.Kind == Registry.Kind.Submenu then
        return Option.Submenu(label, entry.Submenu, tip, entry.Action, entry.Id)
    elseif entry.Kind == Registry.Kind.Break then
        return Option.Break(label, entry.Alignment)
    end
    return Option.Button(label, tip, entry.Action, entry.Id)
end

return Option

