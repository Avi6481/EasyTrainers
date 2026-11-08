local Highlight = require("Widgets/Core/Highlight")
local Row = require("Widgets/Core/Row")
local Widget = require("Widgets/Core/Widget")

local Button = {}

function Button.Draw(label)
    local data = Widget.Begin(label)
    local state = Row.Animate(data)
    Widget.Bindable(data, label, Widget.Kinds.Action)

    if data.Selected then Highlight.SetHint(Highlight.SelectHint()) end

    if not data.Visible then return data.Activated end

    Row.DrawBackground(data, state)
    Row.DrawLabel(data, state, label)

    return data.Activated
end

return Button
