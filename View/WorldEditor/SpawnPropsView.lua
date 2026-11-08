local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local WorldEditor = require("Features/WorldEditor/WorldEditor")
local PropCatalog = require("Features/WorldEditor/PropCatalog")
local PropSpawner = require("Features/WorldEditor/PropSpawner")
local VehicleCatalog = require("Features/WorldEditor/VehicleCatalog")
local Editing = require("Features/WorldEditor/Editing")
local VehicleInfo = require("View/Vehicles/VehicleInfo")

local SpawnPropsView = {}

local s_State = { Query = "" }
local s_Query = Ref.Field(s_State, "Query")
local s_Results = {}
local s_ResultsFor = nil
local s_CategoryMenus = {}
local s_GroupMenus = {}
local s_ClassMenus = {}
local s_Badges = {}
local s_Docs = setmetatable({}, { __mode = "k" })

local function Badge(count)
    local badge = s_Badges[count]
    if not badge then
        badge = tostring(count)
        s_Badges[count] = badge
    end
    return badge
end

local function CountTip(count)
    if Widgets.Selected() then Widgets.Tip(tip("worldeditor.spawn.count", { count = count })) end
end

local function Row(key, value)
    return { Kind = "Row", Label = L(key), Value = value or "" }
end

local function InfoRows(entry, card, pending)
    local size = card and card.Size or pending
    if PropSpawner.IsMesh(entry) then
        local supported = PropSpawner.MeshSupportKnown() ~= false
        return {
            Row("worldeditor.spawn.info.group", entry.Group),
            Row("worldeditor.spawn.info.type", L(supported and "worldeditor.spawn.info.mesh" or "worldeditor.spawn.info.meshupdate")),
            Row("worldeditor.spawn.info.size", size),
            Row("worldeditor.spawn.info.collision", L("worldeditor.spawn.info.editorbox"))
        }
    end

    local physics = card and L(card.Dynamic and "worldeditor.spawn.info.dynamic" or "worldeditor.spawn.info.static")
    return {
        Row("worldeditor.spawn.info.group", entry.Group),
        Row("worldeditor.spawn.info.type", card and card.ClassName or pending),
        Row("worldeditor.spawn.info.size", size),
        Row("worldeditor.spawn.info.physics", physics or pending)
    }
end

local function PropInfo(entry)
    local card = PropSpawner.GetPreviewCard(entry)
    local version = card and card.Version or 0
    local preview = PropSpawner.PreviewEnabled
    local mesh = PropSpawner.MeshSupportKnown()
    local cached = s_Docs[entry]
    if cached and cached.Version == version and cached.Preview == preview and cached.Mesh == mesh then return cached.Doc end

    local pending = L(preview and "worldeditor.spawn.info.loading" or "worldeditor.spawn.info.previewoff")
    local doc = {
        { Kind = "Eyebrow", Text = entry.Category },
        { Kind = "Title", Text = entry.Name },
        { Kind = "Separator" }
    }
    for _, row in ipairs(InfoRows(entry, card, pending)) do table.insert(doc, row) end
    table.insert(doc, { Kind = "Text", Text = entry.Path, Tone = "Dim" })

    s_Docs[entry] = { Version = version, Preview = preview, Mesh = mesh, Doc = doc }
    return doc
end

local function PropRow(entry)
    if Widgets.Button(entry.Name) then WorldEditor.Run(function() Editing.Place(entry) end) end
    Widgets.Tip(L(entry.Vehicle and "worldeditor.spawn.vehicle.tip" or "worldeditor.spawn.prop.tip"))
    if not Widgets.Selected() then return end
    PropSpawner.Preview(entry)
    if entry.Vehicle then
        Widgets.Info(VehicleInfo.Get, entry.Vehicle)
    else
        Widgets.Info(PropInfo, entry)
    end
end

local function PropList(props)
    PropSpawner.Browse()
    for _, entry in ipairs(props) do PropRow(entry) end
end

local function GroupMenu(category, group)
    local key = category.Name .. "/" .. group.Name
    if not s_GroupMenus[key] then
        s_GroupMenus[key] = Submenu.Create(group.Name, function() PropList(group.Props) end)
    end
    return s_GroupMenus[key]
end

local function CategoryView(category)
    if #category.Groups == 1 then
        PropList(category.Groups[1].Props)
        return
    end
    for _, group in ipairs(category.Groups) do
        Widgets.SubmenuButton(group.Name, GroupMenu(category, group), Badge(#group.Props))
        CountTip(#group.Props)
    end
end

local function CategoryMenu(category)
    if not s_CategoryMenus[category.Name] then
        s_CategoryMenus[category.Name] = Submenu.Create(category.Name, function() CategoryView(category) end)
    end
    return s_CategoryMenus[category.Name]
end

local function ClassMenu(class)
    if not s_ClassMenus[class.Name] then
        s_ClassMenus[class.Name] = Submenu.Create(class.Name, function() PropList(class.Vehicles) end)
    end
    return s_ClassMenus[class.Name]
end

local function VehiclesView()
    WorldEditor.LoadCatalog()
    if not VehicleCatalog.IsLoaded() then
        Widgets.ValueRow(L("worldeditor.spawn.vehicleloading.label"), "")
        Widgets.Tip(L("worldeditor.spawn.vehicleloading.tip"))
        return
    end
    for _, class in ipairs(VehicleCatalog.GetClasses()) do
        Widgets.SubmenuButton(class.Name, ClassMenu(class), Badge(#class.Vehicles))
        CountTip(#class.Vehicles)
    end
end

local s_VehiclesMenu = Submenu.Create("worldeditor.spawn.vehicles.label", VehiclesView)

local function Results()
    if s_ResultsFor ~= s_State.Query then
        s_ResultsFor = s_State.Query
        s_Results = VehicleCatalog.Search(s_State.Query)
        for _, entry in ipairs(PropCatalog.Search(s_State.Query)) do table.insert(s_Results, entry) end
    end
    return s_Results
end

local function View()
    WorldEditor.LoadCatalog()

    local searching = s_State.Query ~= "" and PropCatalog.IsLoaded()
    local results = searching and Results() or nil
    Widgets.SearchRow(s_Query, L("worldeditor.spawn.search"), results and #results or -1)

    if results then
        if #results == 0 then
            Widgets.ValueRow(L("worldeditor.spawn.none.label"), "")
            Widgets.Tip(L("worldeditor.spawn.none.tip"))
            return
        end
        PropList(results)
        return
    end

    if not PropCatalog.IsLoaded() then
        Widgets.ValueRow(L("worldeditor.spawn.loading.label"), "")
        Widgets.Tip(L("worldeditor.spawn.loading.tip"))
        return
    end

    Widgets.SubmenuButton(L("worldeditor.spawn.vehicles.label"), s_VehiclesMenu, VehicleCatalog.IsLoaded() and Badge(VehicleCatalog.Count()) or nil)
    Widgets.Tip(L("worldeditor.spawn.vehicles.tip"))

    Widgets.Break(tip("worldeditor.spawn.categories", { count = PropCatalog.Count() }))
    for _, category in ipairs(PropCatalog.GetCategories()) do
        Widgets.SubmenuButton(category.Name, CategoryMenu(category), Badge(category.Count))
        CountTip(category.Count)
    end
end

SpawnPropsView.Menu = Submenu.Create("worldeditor.spawnprops.label", View)

return SpawnPropsView
