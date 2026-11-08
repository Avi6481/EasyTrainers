local Animation = require("Core/Animation")
local Draw = require("Core/Draw")
local Style = require("Style/Style")
local Layout = require("Style/Layout")
local Scale = require("Style/Scale")
local Highlight = require("Widgets/Core/Highlight")
local Row = require("Widgets/Core/Row")
local Widget = require("Widgets/Core/Widget")
local SliderStyle = require("Widgets/Slider/SliderStyle")
local Toggle = require("Widgets/Toggle/Toggle")
local Sheet = require("Panels/Sheet/Sheet")

local Dropdown = {}

local s_Previewing = {}

local function ItemLabel(items, index)
    local item = items[index]
    if item == nil then return "" end
    if type(item) == "table" then return tostring(item.Label or "") end
    return tostring(item)
end

local function SheetItems(items)
    local converted = {}
    for index, item in ipairs(items) do
        if type(item) == "table" then
            converted[index] = { Label = tostring(item.Label or ""), Detail = item.Detail or "", Tip = item.Tip or "" }
        else
            converted[index] = { Label = tostring(item), Detail = "", Tip = "" }
        end
    end
    return converted
end

local function UpdatePreview(id, preview)
    local index = Sheet.SheetHighlighted(id)
    if index then
        s_Previewing[id] = true
        preview(index)
    elseif s_Previewing[id] then
        s_Previewing[id] = nil
        preview(nil)
    end
end

function Dropdown.Draw(label, ref, items, preview, always)
    local data = Widget.Begin(label)
    local state = Row.Animate(data)

    local changed = false

    local picked = Sheet.TakeSheetResult(data.Id)
    if picked ~= nil and (always or picked ~= ref.Value) then
        ref.Value = picked
        changed = true
    end

    if preview then UpdatePreview(data.Id, preview) end

    if data.Activated and #items > 0 then
        Sheet.OpenSheet(data.Id, label, SheetItems(items), ref.Value)
    end

    local padding = Scale.S(Layout.Padding)
    local valueSize = Scale.FontSize() * SliderStyle.ValueScale
    local chevron = Scale.S(SliderStyle.ChevronSize)
    local gap = Scale.S(SliderStyle.ChevronGap)
    local controlWidth = Toggle.ControlWidth()

    local columnCenter = data.X + data.Width - padding - (controlWidth * 0.5)
    local right = data.X + data.Width - padding - controlWidth - Scale.S(SliderStyle.ValueGap)

    local value = ItemLabel(items, ref.Value)
    local textWidth, textHeight = Draw.TextSize(value, valueSize)
    local valueX = right - textWidth

    if data.Selected then
        Highlight.SetHint(Highlight.SelectHint(), (data.X + data.Width - padding) - valueX + gap)
    end

    if not data.Visible then return changed end

    Row.DrawBackground(data, state)
    Row.DrawLabel(data, state, label)

    local centerY = data.Y + (data.Height * 0.5)
    local active = math.max(state.Select, state.Hover)

    local textColor = Animation.LerpColor(Style.TextSoft, Style.Text, active)
    Draw.Text(valueX, centerY - (textHeight * 0.5), textColor, value, valueSize)

    local chevronColor = Animation.LerpColor(Style.TextDisabled, Style.Text, active * 0.6)
    Draw.Chevron(columnCenter, centerY, chevron, "Up", chevronColor, Scale.S(SliderStyle.ChevronThickness))

    return changed
end

return Dropdown
