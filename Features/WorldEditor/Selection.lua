local Selection = {}

Selection.Highlight = { value = true }

local OUTLINE_CHILD = 1
local OUTLINE_PARENT = 6

local s_List = {}

local function Safe(callback)
    local ok, value = pcall(callback)
    if ok then return value end
    return nil
end

local function Hash(entity)
    return entity and Safe(function() return tostring(entity:GetEntityID().hash) end)
end

local function SetOutline(entity, outline)
    if not EasyWorldEditor or not entity then return end
    if outline then
        Safe(function() EasyWorldEditor.SetHighlight(entity, 0, outline, 1.0, true) end)
    else
        Safe(function() EasyWorldEditor.ClearHighlight(entity) end)
    end
end

local function IsValid(entity)
    local id = Safe(function() return entity:GetEntityID() end)
    return id ~= nil and Safe(function() return Game.FindEntityByID(id) end) ~= nil
end

local function Refresh()
    for index, entry in ipairs(s_List) do
        local outline = nil
        if Selection.Highlight.value then
            outline = (#s_List > 1 and index == #s_List) and OUTLINE_PARENT or OUTLINE_CHILD
        end
        SetOutline(entry.Entity, outline)
    end
end

local function Entry(target)
    return {
        Entity = target.Entity,
        EntityHash = target.EntityHash or Hash(target.Entity),
        Kind = target.Kind or "Prop",
        Name = target.DisplayName or target.Record or target.ClassName or "Entity",
        Record = target.Record,
        ClassName = target.ClassName,
        Appearance = target.Appearance
    }
end

local function Find(hash)
    for index, entry in ipairs(s_List) do
        if entry.EntityHash == hash then return index end
    end
    return nil
end

function Selection.Select(target)
    if not target or not target.Entity then
        Selection.Clear()
        return
    end
    local entry = Entry(target)
    if #s_List == 1 and s_List[1].EntityHash == entry.EntityHash then return end

    Selection.Clear()
    s_List = { entry }
    Refresh()
end

function Selection.Toggle(target)
    if not target or not target.Entity then return end
    local entry = Entry(target)
    local index = Find(entry.EntityHash)
    if index then
        SetOutline(s_List[index].Entity, nil)
        table.remove(s_List, index)
    else
        table.insert(s_List, entry)
    end
    Refresh()
end

function Selection.Clear()
    for _, entry in ipairs(s_List) do SetOutline(entry.Entity, nil) end
    s_List = {}
end

function Selection.Get()
    return s_List[#s_List]
end

function Selection.GetAll()
    return s_List
end

function Selection.Count()
    return #s_List
end

function Selection.Contains(entity)
    return Find(Hash(entity)) ~= nil
end

function Selection.GetPosition()
    local selected = Selection.Get()
    local position = selected and Safe(function() return selected.Entity:GetWorldPosition() end)
    if not position then return nil end
    return { x = position.x, y = position.y, z = position.z }
end

function Selection.Replace(old, new)
    local index = Find(Hash(old))
    if not index then return end
    s_List[index].Entity = new
    s_List[index].EntityHash = Hash(new)
    Refresh()
end

function Selection.RefreshHighlight()
    if not Selection.Highlight.value then
        for _, entry in ipairs(s_List) do SetOutline(entry.Entity, nil) end
        return
    end
    Refresh()
end

function Selection.Tick()
    local removed = false
    for index = #s_List, 1, -1 do
        if not IsValid(s_List[index].Entity) then
            table.remove(s_List, index)
            removed = true
        end
    end
    if removed then Refresh() end
end

function Selection.Forget()
    s_List = {}
end

return Selection
