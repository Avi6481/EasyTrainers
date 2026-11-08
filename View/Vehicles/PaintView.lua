local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local Notify = require("Utils/Notify")
local Vehicles = require("Features/Vehicles/Vehicles")
local Paint = require("Features/Vehicles/Paint")

local PaintView = {}

local MAX_NAME = 40

local s_State = { Name = "" }
local s_Name = Ref.Field(s_State, "Name")
local s_AnyVehicle = Ref.Field(Paint, "AnyVehicle")
local s_Presets = nil
local s_Swatches = setmetatable({}, { __mode = "k" })
local s_Docs = setmetatable({}, { __mode = "k" })

local function ApplyTo(_, vehicle)
    Paint.Apply(vehicle, true)
end

local function ResetTo(_, vehicle)
    Paint.Reset(vehicle)
end

local function ApplyNow()
    Vehicles.Mounted(ApplyTo)
end

local function ResetNow()
    Vehicles.Mounted(ResetTo)
end

local function PaintWith(entry)
    if Paint.Load(entry) then ApplyNow() end
end

local function Swatches(entry)
    local swatches = s_Swatches[entry]
    if swatches then return swatches end

    swatches = { Paint.Color(entry.Primary), Paint.Color(entry.Secondary) }
    s_Swatches[entry] = swatches
    return swatches
end

local function SwatchDoc(entry, name)
    local doc = s_Docs[entry]
    if doc then return doc end

    local swatches = Swatches(entry)
    doc = {
        { Kind = "Eyebrow", Text = L("vehicles.paint.label") },
        { Kind = "Title", Text = name },
        { Kind = "Separator" },
        { Kind = "Swatch", Color = swatches[1], Label = L("vehicles.paint.primary.label"), Value = tostring(entry.Primary) },
        { Kind = "Swatch", Color = swatches[2], Label = L("vehicles.paint.secondary.label"), Value = tostring(entry.Secondary) }
    }
    s_Docs[entry] = doc
    return doc
end

local function PresetDoc(row)
    return SwatchDoc(row.Preset, row.Label)
end

local function SavedDoc(entry)
    return SwatchDoc(entry, tostring(entry.Name))
end

local function Presets()
    if s_Presets then return s_Presets end

    s_Presets = {}
    for index, preset in ipairs(Paint.Presets) do
        s_Presets[index] = { Label = L("vehicles.paint.presets.names." .. preset.Key), Preset = preset }
    end
    return s_Presets
end

local function Link(key, menu)
    Widgets.SubmenuButton(L(key .. ".label"), menu)
    Widgets.Tip(L(key .. ".tip"))
end

local function Button(key, action, hold)
    local pressed
    if hold then
        pressed = Widgets.HoldButton(L(key .. ".label"))
    else
        pressed = Widgets.Button(L(key .. ".label"))
    end
    if pressed then action() end
    Widgets.Tip(L(key .. ".tip"))
end

local function PresetsView()
    for _, row in ipairs(Presets()) do
        if Widgets.Preset(row.Label, Swatches(row.Preset)) then PaintWith(row.Preset) end
        Widgets.Tip(L("vehicles.paint.preset.tip"))
        Widgets.Info(PresetDoc, row)
    end
end

local function DeleteView()
    if #Paint.Saved == 0 then
        Widgets.ValueRow(L("vehicles.paint.saved.none"), "")
        return
    end

    local removed = nil
    for _, entry in ipairs(Paint.Saved) do
        if Widgets.HoldButton(tostring(entry.Name)) then removed = entry end
        Widgets.Tip(L("vehicles.paint.remove.tip"))
        Widgets.Info(SavedDoc, entry)
    end
    if removed then
        Paint.Delete(removed)
        Notify.Info(tip("notify.paint.deleted", { name = tostring(removed.Name) }))
    end
end

local PresetsMenu = Submenu.Create("vehicles.paint.presets.label", PresetsView)
local DeleteMenu = Submenu.Create("vehicles.paint.delete.label", DeleteView)

local function SavedView()
    Link("vehicles.paint.delete", DeleteMenu)

    if Widgets.InputText(L("vehicles.paint.save.label"), s_Name, MAX_NAME, L("vehicles.paint.save.placeholder")) then
        local name = Paint.Save(s_State.Name)
        s_State.Name = ""
        Notify.Success(tip("notify.paint.saved", { name = name }))
    end
    Widgets.Tip(L("vehicles.paint.save.tip"))

    if #Paint.Saved == 0 then
        Widgets.ValueRow(L("vehicles.paint.saved.none"), "")
        return
    end

    for _, entry in ipairs(Paint.Saved) do
        if Widgets.Preset(tostring(entry.Name), Swatches(entry)) then PaintWith(entry) end
        Widgets.Tip(L("vehicles.paint.entry.tip"))
        Widgets.Info(SavedDoc, entry)
    end
end

local SavedMenu = Submenu.Create("vehicles.paint.saved.label", SavedView)

local function View()
    Link("vehicles.paint.presets", PresetsMenu)
    Link("vehicles.paint.saved", SavedMenu)

    Widgets.Toggle(L("vehicles.paint.anyvehicle.label"), s_AnyVehicle)
    Widgets.Tip(L("vehicles.paint.anyvehicle.tip"))

    Widgets.Break(L("vehicles.paint.colors"))
    Widgets.ColorPicker(L("vehicles.paint.primary.label"), Paint.Primary, false, Paint.Changed)
    Widgets.Tip(L("vehicles.paint.primary.tip"))
    Widgets.ColorPicker(L("vehicles.paint.secondary.label"), Paint.Secondary, false, Paint.Changed)
    Widgets.Tip(L("vehicles.paint.secondary.tip"))
    Button("vehicles.paint.swap", Paint.Swap)
    Button("vehicles.paint.randomize", Paint.Randomize)

    Widgets.Break(L("vehicles.paint.job"))
    Button("vehicles.paint.apply", ApplyNow)
    Button("vehicles.paint.reset", ResetNow, true)
end

PaintView.Menu = Submenu.Create("vehicles.paint.label", View)

return PaintView
