local Animation = require("Core/Animation")
local Language = require("Core/Language")
local State = require("Core/State")
local Scale = require("Style/Scale")
local Navigation = require("Navigation/Navigation")
local NavigationStyle = require("Navigation/NavigationStyle")
local Highlight = require("Widgets/Core/Highlight")

local Submenu = {}

local s_Stack = {}
local s_Pending = nil
local s_Transition = 1
local s_TransitionVelocity = 0
local s_Direction = 1

function Submenu.Create(title, view)
    return { Title = title, View = view }
end

local function StartTransition(direction)
    s_Transition = 0
    s_TransitionVelocity = 0
    s_Direction = direction
    Highlight.ResetHighlight()
end

function Submenu.SetRoot(root)
    s_Stack = { { Menu = root, Return = nil } }
    s_Pending = nil
    Navigation.ResetPosition()
end

function Submenu.Open(submenu)
    s_Pending = submenu
end

function Submenu.ApplyPending()
    if not s_Pending then return end

    table.insert(s_Stack, { Menu = s_Pending, Return = Navigation.SavePosition() })
    s_Pending = nil
    Navigation.ResetPosition()
    StartTransition(1)
end

function Submenu.Close()
    if #s_Stack <= 1 then return false end

    local page = table.remove(s_Stack)
    Navigation.RestorePosition(page.Return)
    StartTransition(-1)
    return true
end

function Submenu.IsRoot()
    return #s_Stack <= 1
end

function Submenu.Depth()
    return #s_Stack
end

function Submenu.Current()
    local page = s_Stack[#s_Stack]
    return page and page.Menu or nil
end

function Submenu.DrawCurrent()
    local current = Submenu.Current()
    if not current or not current.View then return end

    current.View()
end

function Submenu.Breadcrumb(separator)
    separator = separator or " / "
    local parts = {}
    for index = 2, #s_Stack do
        table.insert(parts, Language.Get(s_Stack[index].Menu.Title))
    end
    return table.concat(parts, separator)
end

function Submenu.UpdateTransition()
    s_Transition, s_TransitionVelocity = Animation.SmoothDamp(s_Transition, 1, s_TransitionVelocity, NavigationStyle.PageSlideTime, State.Time.Delta)
    Navigation.State.OffsetX = s_Direction * Scale.S(NavigationStyle.PageSlideDistance) * (1 - s_Transition)
end

function Submenu.TransitionAlpha()
    return math.max(0, math.min(1, s_Transition))
end

return Submenu
