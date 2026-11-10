local GameText = require("Utils/GameText")
local JsonHelper = require("Core/JsonHelper")
local Logger = require("Core/Logger")

local MapPins = {
    Ready = false,
    Sections = {},
    All = {}
}

local ALL = "All"
local ACTIVE = "Active"

local SECTIONS = {
    { Id = "FastTravel", Group = "Locations", Mode = ALL, Key = "fasttravel", Variants = { "FastTravelVariant" } },
    { Id = "Metro", Group = "Locations", Mode = ALL, Key = "metro", Variants = { "Zzz17_NCARTVariant" } },
    { Id = "Apartments", Group = "Locations", Mode = ALL, Key = "apartments", Variants = { "ApartmentVariant", "Zzz05_ApartmentToPurchaseVariant" } },
    { Id = "Guns", Group = "Vendors", Mode = ALL, Variants = { "ServicePointGunsVariant" } },
    { Id = "Ripperdoc", Group = "Vendors", Mode = ALL, Variants = { "ServicePointRipperdocVariant" } },
    { Id = "Meds", Group = "Vendors", Mode = ALL, Variants = { "ServicePointMedsVariant" } },
    { Id = "Clothes", Group = "Vendors", Mode = ALL, Variants = { "ServicePointClothesVariant" } },
    { Id = "Food", Group = "Vendors", Mode = ALL, Variants = { "ServicePointFoodVariant" } },
    { Id = "Bar", Group = "Vendors", Mode = ALL, Variants = { "ServicePointBarVariant" } },
    { Id = "Junk", Group = "Vendors", Mode = ALL, Variants = { "ServicePointJunkVariant" } },
    { Id = "Netrunner", Group = "Vendors", Mode = ALL, Variants = { "ServicePointNetTrainerVariant" } },
    { Id = "Melee", Group = "Vendors", Mode = ALL, Variants = { "ServicePointMeleeTrainerVariant" } },
    { Id = "BlackMarket", Group = "Vendors", Mode = ALL, Variants = { "Zzz14_ServicePointBlackMarketVariant" } },
    { Id = "Joytoys", Group = "Vendors", Mode = ALL, Variants = { "ServicePointProstituteVariant" } },
    {
        Id = "Gigs", Group = "Activities", Mode = ACTIVE, Key = "gigs", Breaks = true,
        Variants = {
            "FixerVariant", "ThieveryVariant", "SabotageVariant", "RetrievingVariant", "CourierVariant",
            "BountyHuntVariant", "ClientInDistressVariant", "Zzz10_RemoteControlDrivingVariant"
        }
    },
    {
        Id = "NCPD", Group = "Activities", Mode = ACTIVE, Key = "ncpd", Breaks = true,
        Variants = {
            "GangWatchVariant", "OutpostVariant", "HuntForPsychoVariant", "HiddenStashVariant", "ResourceVariant",
            "MinorActivityVariant", "Zzz12_WorldEncounterVariant", "ConvoyVariant", "SmugglersDenVariant", "DropboxVariant"
        }
    },
    { Id = "Sandbox", Group = "Activities", Mode = ACTIVE, Variants = { "Zzz09_CourierSandboxActivityVariant" } },
    { Id = "Racing", Group = "Activities", Mode = ACTIVE, Variants = { "Zzz18_RacingVariant" } },
    { Id = "Tarot", Group = "Activities", Mode = ACTIVE, Variants = { "TarotVariant" } },
    { Id = "Quests", Group = "Activities", Mode = ACTIVE, Key = "quests", Breaks = true, Variants = { "DefaultQuestVariant", "QuestionMarkVariant", "ExclamationMarkVariant" } }
}

local FILE = "Data/MapPins.json"
local CAPTURED = "Data/CapturedPins.json"
local TARGETS = { "Map", "World", "Minimap" }
local FAST_TRAVEL = "FastTravelVariant"
local METRO = "Zzz17_NCARTVariant"
local APARTMENT = "ApartmentVariant"
local FRONT_DESK = "Zzz05_ApartmentToPurchaseVariant"
local SAME_SPOT = 5

local s_ByName = nil
local s_ByValue = nil
local s_Sections = nil
local s_Phases = nil
local s_Data = nil
local s_Captured = nil
local s_StateFailed = false

local function Readable(name)
    name = name:gsub("^Zzz%d+_", ""):gsub("Variant$", ""):gsub("^ServicePoint", "")
    return (name:gsub("(%l)(%u)", "%1 %2"))
end

local function VariantLabel(name, value)
    local ok, key = pcall(MappinUIUtils.MappinToString, value)
    local label = ok and GameText.FromName(key, nil) or nil
    if not label or label == "" or label:find("UI%-MappinTypes") then label = Readable(name) end
    return label
end

local function Variant(name)
    local ok, value = pcall(function() return gamedataMappinVariant[name] end)
    if ok then return value end
    return nil
end

local function BuildLookup()
    s_ByName = {}
    s_ByValue = {}
    s_Sections = {}
    s_Phases = {
        Undiscovered = EnumInt(gamedataMappinPhase.UndiscoveredPhase),
        Completed = EnumInt(gamedataMappinPhase.CompletedPhase)
    }

    for _, section in ipairs(SECTIONS) do
        s_Sections[section.Id] = section
        for index, name in ipairs(section.Variants) do
            local value = Variant(name)
            if value then
                local kind = { Section = section, Name = name, Index = index, Label = VariantLabel(name, value) }
                s_ByName[name] = kind
                s_ByValue[EnumInt(value)] = kind
            end
        end
    end
end

local function ReadPins(path)
    local data = JsonHelper.ReadOptional(path)
    if type(data) ~= "table" or type(data.pins) ~= "table" then return {} end
    return data.pins
end

local function List(call)
    local ok, list = pcall(call)
    if ok and type(list) == "table" then return list end
    return {}
end

local function SectionLabel(section, kind)
    if section.Key then return L("teleports.sections." .. section.Key .. ".label") end
    return kind.Label
end

local function Group(sections, kind)
    local definition = kind.Section
    local section = sections[definition.Id]
    if not section then
        section = {
            Id = definition.Id,
            Group = definition.Group,
            Breaks = definition.Breaks,
            Key = definition.Key,
            Label = SectionLabel(definition, kind),
            Groups = {},
            Order = {},
            All = {},
            Count = 0
        }
        sections[definition.Id] = section
    end

    local group = section.Groups[kind.Name]
    if not group then
        group = { Name = kind.Name, Label = kind.Label, Index = kind.Index, Pins = {}, Names = {} }
        section.Groups[kind.Name] = group
        table.insert(section.Order, group)
    end
    return section, group
end

local function UniqueName(group, name)
    local count = (group.Names[name] or 0) + 1
    group.Names[name] = count
    if count == 1 then return name end
    return name .. " " .. count
end

local function Add(state, kind, entry)
    local section, group = Group(state.Sections, kind)
    entry.Name = UniqueName(group, entry.Name)
    entry.Kind = kind.Label
    entry.Search = table.concat({ entry.Name, kind.Label, entry.District or "", entry.Area or "" }, " "):lower()
    entry.Tag = section.Breaks and kind.Label or nil

    table.insert(group.Pins, entry)
    table.insert(section.All, entry)
    table.insert(state.All, entry)
    section.Count = section.Count + 1
end

local function FastTravel(state, system)
    local container = Game.GetScriptableSystemsContainer()
    local fastTravel = container and container:Get("FastTravelSystem")
    if not fastTravel or not s_ByName[FAST_TRAVEL] then return end

    for _, point in ipairs(List(function() return fastTravel:GetFastTravelPoints() end)) do
        local ok, pin = pcall(function() return system:GetMappin(point.mappinID) end)
        if ok and pin then
            local position = pin:GetWorldPosition()
            local kind = (point:IsSubway() and s_ByName[METRO]) or s_ByName[FAST_TRAVEL]
            Add(state, kind, {
                Name = GameText.Get(point:GetPointDisplayName(), kind.Label),
                District = GameText.Get(point:GetDistrictDisplayName(), nil),
                Status = EnumInt(pin:GetPhase()) == s_Phases.Undiscovered and "undiscovered" or "discovered",
                X = position.x,
                Y = position.y,
                Z = position.z
            })
        end
    end
end

local function Status(system, hash)
    local ok, found, phase, _, active = pcall(function() return system:GetPointOfInterestMappinSavedState(hash) end)
    if not ok then
        if not s_StateFailed then
            s_StateFailed = true
            Logger.Log("Teleports: map pin states unavailable, listing every activity")
        end
        return "unknown"
    end
    if found ~= true or phase == s_Phases.Undiscovered then return "undiscovered" end
    if phase == s_Phases.Completed or active == false then return "completed" end
    return "discovered"
end

local function Listed(kind, status, undiscovered)
    if kind.Section.Mode == ALL then return true end
    if status == "completed" then return false end
    return status ~= "undiscovered" or undiscovered
end

local function VendorName(hash)
    local ok, text = pcall(function()
        local entry = Game.GetJournalManager():GetEntry(hash)
        if not entry then return nil end
        local id = entry:GetId()
        if not id or id == "" then return nil end
        local record = TweakDBInterface.GetVendorRecord(TweakDBID.new("Vendors." .. id))
        if not record then return nil end
        return GameText.Get(record:LocalizedName(), nil)
    end)
    if ok and text and not text:find("^LocKey") then return text end
    return nil
end

local function PinName(kind, pin)
    if pin.name then return pin.name end
    local title = pin.title and GameText.Get(pin.title, nil)
    if title and not title:find("^LocKey") then return title end

    local area = pin.area or pin.district
    if area then
        if kind.Name == APARTMENT then return area .. " Apartment" end
        if kind.Name == FRONT_DESK then return area .. " Front Desk" end
        if kind.Section.Group == "Vendors" then
            local vendor = VendorName(pin.hash)
            if vendor then return vendor .. " - " .. area end
        end
        return area
    end
    return kind.Label
end

local function Expansion()
    local ok, installed = pcall(Game.IsEP1)
    return not ok or installed == true
end

local function Static(state, system, undiscovered)
    local expansion = Expansion()
    for _, pin in ipairs(s_Data) do
        local kind = s_ByName[pin.variant]
        if kind and (expansion or not pin.ep1) then
            local status = Status(system, pin.hash)
            if Listed(kind, status, undiscovered) then
                Add(state, kind, {
                    Name = PinName(kind, pin),
                    District = pin.district,
                    Area = pin.area,
                    Status = status,
                    X = pin.x,
                    Y = pin.y,
                    Z = pin.z
                })
            end
        end
    end
end

local function Captured(state)
    for _, pin in ipairs(s_Captured) do
        local kind = s_ByName[pin.variant]
        if kind and kind.Section.Mode == ALL then
            Add(state, kind, {
                Name = pin.name or kind.Label,
                Status = "discovered",
                X = pin.x,
                Y = pin.y,
                Z = pin.z
            })
        end
    end
end

local function Prepare()
    if not s_ByName then BuildLookup() end
    if not s_Data then s_Data = ReadPins(FILE) end
    if not s_Captured then s_Captured = ReadPins(CAPTURED) end
end

function MapPins.Collect(undiscovered)
    Prepare()

    local system = Game.GetMappinSystem()
    local state = { Sections = {}, All = {} }
    FastTravel(state, system)
    Static(state, system, undiscovered)
    Captured(state)

    for _, section in pairs(state.Sections) do
        table.sort(section.Order, function(first, second) return first.Index < second.Index end)
    end

    MapPins.Sections = state.Sections
    MapPins.All = state.All
    MapPins.Ready = true
    Logger.Log("Teleports: " .. #state.All .. " map pins")
end

local function Known(variant, x, y)
    for _, list in ipairs({ s_Data, s_Captured }) do
        for _, pin in ipairs(list) do
            if pin.variant == variant and math.abs(pin.x - x) < SAME_SPOT and math.abs(pin.y - y) < SAME_SPOT then return true end
        end
    end
    return false
end

local function ReadLive(system, target)
    local pins = List(function() return system:GetMappins(target) end)
    if #pins > 0 then return pins end

    for _, entry in ipairs(List(function() return system:GetMappinEntries(target) end)) do
        local pin = system:GetMappin(entry.id)
        if pin then table.insert(pins, pin) end
    end
    return pins
end

function MapPins.Capture()
    Prepare()

    local system = Game.GetMappinSystem()
    local read, added = 0, 0
    for _, target in ipairs(TARGETS) do
        for _, pin in ipairs(ReadLive(system, gamemappinsMappinTargetType[target])) do
            read = read + 1
            local kind = s_ByValue[EnumInt(pin:GetVariant())]
            if kind and kind.Section.Mode == ALL and kind.Name ~= FAST_TRAVEL and kind.Name ~= METRO then
                local position = pin:GetWorldPosition()
                if not Known(kind.Name, position.x, position.y) then
                    local name = pin:GetDisplayName()
                    table.insert(s_Captured, {
                        variant = kind.Name,
                        name = (name and name ~= "") and GameText.Get(name, name) or nil,
                        x = math.floor(position.x * 1000 + 0.5) / 1000,
                        y = math.floor(position.y * 1000 + 0.5) / 1000,
                        z = math.floor(position.z * 1000 + 0.5) / 1000
                    })
                    added = added + 1
                end
            end
        end
    end

    if added > 0 then JsonHelper.Write(CAPTURED, { pins = s_Captured }) end
    Logger.Log(string.format("Teleports: capture read %d live pins, added %d, %d captured in total", read, added, #s_Captured))
    return read, added, #s_Captured
end

function MapPins.SectionIds(group)
    local ids = {}
    for _, section in ipairs(SECTIONS) do
        if section.Group == group then table.insert(ids, section.Id) end
    end
    return ids
end

function MapPins.Clear()
    MapPins.Ready = false
    MapPins.Sections = {}
    MapPins.All = {}
end

return MapPins
