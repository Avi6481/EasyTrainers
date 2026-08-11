local Submenu = {}

Submenu.Stack = {}
Submenu.PositionStack = {}

function Submenu.Create(title, view, parent)
    return { Title = title, View = view, Parent = parent }
end

function Submenu.Initialize(root)
    Submenu.Stack = root and { root } or {}
    Submenu.PositionStack = {}
end

function Submenu.Open(submenu, navigation)
    submenu.Parent = Submenu.Stack[#Submenu.Stack]
    table.insert(Submenu.PositionStack, navigation.State.Current)
    table.insert(Submenu.Stack, submenu)
    navigation.State.Current = 1
end

function Submenu.Close(navigation, layout)
    if #Submenu.Stack <= 1 then return false end
    table.remove(Submenu.Stack)
    navigation.State.Current = table.remove(Submenu.PositionStack) or 1
    navigation.SyncScroll(layout)
    return true
end

function Submenu.Current()
    return Submenu.Stack[#Submenu.Stack]
end

function Submenu.DrawCurrent()
    local current = Submenu.Current()
    if current and current.View then current.View() end
end

function Submenu.GetPath()
    local path = {}
    for _, submenu in ipairs(Submenu.Stack) do
        table.insert(path, submenu.Title)
    end
    return path
end

function Submenu.IsRoot()
    return #Submenu.Stack <= 1
end

return Submenu
