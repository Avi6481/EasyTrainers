local Catalog = require("Features/Items/Catalog")
local ItemBrowserState = require("Features/Items/ItemBrowserState")

local ItemInfo = {}

local s_Docs = setmetatable({}, { __mode = "k" })
local s_Sections = {}

local function Row(doc, key, value, tone)
    if value == nil or value == "" then return end
    table.insert(doc, { Kind = "Row", Label = L("items.info." .. key), Value = tostring(value), Tone = tone })
end

local function Owned(doc, owned)
    Row(doc, "owned", owned > 0 and ("x" .. tostring(owned)) or L("items.info.no"), owned > 0 and "Strong" or "Soft")
end

local function Head(doc, item)
    table.insert(doc, { Kind = "Title", Text = item.Name })
    table.insert(doc, { Kind = "Separator" })
    if item.Icon then table.insert(doc, { Kind = "Image", Image = item.Icon }) end
end

local function Tail(doc, item)
    if item.Description and item.Description ~= "" then
        table.insert(doc, { Kind = "Text", Text = item.Description, Tone = "Soft" })
    end
    table.insert(doc, { Kind = "Text", Text = item.Id, Tone = "Dim" })
end

local function Eyebrow(item)
    if item.QualityName and item.Quality ~= Catalog.STANDARD then return item.QualityName end
    return L("items.info.database")
end

local function Category(item)
    if item.Unlisted or not item.Category then return L("items.info.unlisted") end
    return L("items.categories." .. item.Category .. ".label")
end

local function Build(item, owned)
    local doc = { { Kind = "Eyebrow", Text = Eyebrow(item) } }
    Head(doc, item)
    Row(doc, "category", Category(item))
    Row(doc, "group", L(item.Group))
    Row(doc, "quality", item.QualityName)
    Row(doc, "craftable", L(item.Craftable and "items.info.yes" or "items.info.no"), item.Craftable and "Text" or "Soft")
    Owned(doc, owned)
    Tail(doc, item)
    return doc
end

function ItemInfo.Get(item)
    local owned = ItemBrowserState.Count(item)
    local cached = s_Docs[item]
    if cached and cached.Owned == owned and cached.Resolved == item.Resolved then return cached.Doc end

    cached = { Owned = owned, Resolved = item.Resolved, Doc = Build(item, owned) }
    s_Docs[item] = cached
    return cached.Doc
end

local function Essential(title, item, owned, summary)
    local doc = { { Kind = "Eyebrow", Text = L("items.info.essential") } }
    Head(doc, item)
    Row(doc, "section", L(title))
    Row(doc, "group", L("items.essentials.groups." .. item.Group:lower()))
    Owned(doc, owned)
    Row(doc, "action", summary)
    Tail(doc, item)
    return doc
end

function ItemInfo.Section(title)
    local builder = s_Sections[title]
    if builder then return builder end

    local docs = setmetatable({}, { __mode = "k" })
    builder = function(item)
        local owned = ItemBrowserState.Count(item)
        local summary = ItemBrowserState.Summary()
        local cached = docs[item]
        if cached and cached.Owned == owned and cached.Summary == summary and cached.Resolved == item.Resolved then return cached.Doc end

        cached = { Owned = owned, Summary = summary, Resolved = item.Resolved, Doc = Essential(title, item, owned, summary) }
        docs[item] = cached
        return cached.Doc
    end
    s_Sections[title] = builder
    return builder
end

return ItemInfo
