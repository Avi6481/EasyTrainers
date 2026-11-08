local Define = {}

Define.Kinds = {
    Toggle = "Toggle",
    Slider = "Slider",
    Action = "Action"
}

local function New(kind, name, key, options)
    options = options or {}
    return {
        Kind = kind,
        Name = name,
        Key = key,
        Label = key .. ".label",
        Tip = options.Note or (key .. ".tip"),
        Pattern = options.Pattern,
        Break = options.Break,
        Set = options.Set,
        Silent = options.Silent == true
    }
end

function Define.Toggle(name, key, target, field, options)
    local definition = New(Define.Kinds.Toggle, name, key, options)
    definition.Target = target
    definition.Field = field or "Enabled"
    return definition
end

function Define.Slider(name, key, target, value, format, options)
    local definition = New(Define.Kinds.Slider, name, key, options)
    definition.Target = target
    definition.Field = (options and options.Field) or "Enabled"
    definition.Value = value
    definition.Format = format
    return definition
end

function Define.Action(name, key, run, options)
    local definition = New(Define.Kinds.Action, name, key, options)
    definition.Run = run
    return definition
end

return Define
