local Animation = require("UI/Widgets/Animation/Animation")
local Context = require("UI/Core/Context")
local Draw = require("UI/Core/Draw")
local Layout = require("UI/Style/Layout")
local Style = require("UI/Style/Style")
local Submenu = require("UI/Navigation/Submenu")

local SubmenuBar = {
    Height = Layout.SubmenuBarHeight,
    Writer = Animation.CreateTypewriter(),
}

local function Translate(text)
    return type(L) == "function" and L(text) or tostring(text or "")
end

function SubmenuBar.Build(path, separator)
    local labels = {}
    for index, title in ipairs(path or {}) do
        if index > 1 then table.insert(labels, Translate(title)) end
    end
    return table.concat(labels, separator or " / ")
end

function SubmenuBar.Draw()
    local breadcrumb = SubmenuBar.Build(Submenu.GetPath())
    local targetHeight = breadcrumb == "" and 0 or Layout.SubmenuBarHeight
    SubmenuBar.Height = Animation.Animate(SubmenuBar.Height, targetHeight, 15, Context.DeltaTime)
    Context.SubmenuBarHeight = SubmenuBar.Height
    Animation.SetText(SubmenuBar.Writer, breadcrumb)
    Animation.UpdateTypewriter(SubmenuBar.Writer, Context.DeltaTime, 58)
    if SubmenuBar.Height < 0.5 then return end

    local bounds = Context.Bounds
    local drawList = ImGui.GetWindowDrawList()
    local y = bounds.Y + Layout.HeaderHeight
    local textY = y + ((SubmenuBar.Height - ImGui.GetFontSize()) * 0.5)
    local text = Draw.FitText(SubmenuBar.Writer.Displayed, bounds.Width - (Layout.Padding * 2))

    Draw.RectFilled(drawList, bounds.X, y, bounds.Width, SubmenuBar.Height, Style.BackgroundLight, 0)
    if SubmenuBar.Height > ImGui.GetFontSize() then
        Draw.Text(drawList, bounds.X + Layout.Padding, textY, Style.TextDisabled, text)
    end
    Draw.Line(drawList, bounds.X, y + SubmenuBar.Height,
        bounds.X + bounds.Width, y + SubmenuBar.Height, Style.Border, 1)
end

return SubmenuBar
