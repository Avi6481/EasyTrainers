local Notify = require("Utils/Notify")
local Vehicle = require("Utils/Vehicle")

local Paint = {
    AnyVehicle = false,
    Primary = { R = 226 / 255, G = 44 / 255, B = 92 / 255, A = 1 },
    Secondary = { R = 20 / 255, G = 20 / 255, B = 24 / 255, A = 1 },
    Saved = {}
}

Paint.Presets = {
    { Key = "arasaka", Primary = "#A10E1A", Secondary = "#141414" },
    { Key = "militech", Primary = "#4A5136", Secondary = "#1C1F17" },
    { Key = "kangtao", Primary = "#C8A23C", Secondary = "#121214" },
    { Key = "ncpd", Primary = "#1B2A48", Secondary = "#E9ECEF" },
    { Key = "trauma", Primary = "#EEF1F3", Secondary = "#1F8A70" },
    { Key = "samurai", Primary = "#C8102E", Secondary = "#0B0B0B" },
    { Key = "maelstrom", Primary = "#7A0F14", Secondary = "#3A3A3A" },
    { Key = "tygerclaws", Primary = "#D6267A", Secondary = "#1A1033" },
    { Key = "valentinos", Primary = "#D4AF37", Secondary = "#5E0B22" },
    { Key = "voodoo", Primary = "#1E6B52", Secondary = "#0D1B16" },
    { Key = "aldecaldos", Primary = "#B89A6A", Secondary = "#5A3826" },
    { Key = "neon", Primary = "#FF2E88", Secondary = "#22D3EE" },
    { Key = "synthwave", Primary = "#FF6B35", Secondary = "#6A1B9A" },
    { Key = "chrome", Primary = "#D9DEE4", Secondary = "#5B6670" },
    { Key = "midnight", Primary = "#0E1F4D", Secondary = "#B8C1CC" },
    { Key = "acid", Primary = "#9BE22D", Secondary = "#101010" },
    { Key = "pearl", Primary = "#F2EEE9", Secondary = "#B76E79" },
    { Key = "stealth", Primary = "#141416", Secondary = "#3C3C40" },
    { Key = "badlands", Primary = "#D35400", Secondary = "#2C2C2C" },
    { Key = "royal", Primary = "#4B1F7A", Secondary = "#D9C27A" }
}

local APPLY_DELAY = 0.4
local GAMMA = 2.2

local s_ChangedAt = nil
local s_Warned = nil

local function Byte(value)
    return math.floor((math.max(0, math.min(1, tonumber(value) or 0)) * 255) + 0.5)
end

local function Linear(value)
    return math.floor((((Byte(value) / 255) ^ GAMMA) * 255) + 0.5)
end

local function ToHex(color)
    return string.format("#%02X%02X%02X", Byte(color.R), Byte(color.G), Byte(color.B))
end

local function HexDigits(text)
    if type(text) ~= "string" then return nil end
    return text:match("^%s*#?(%x%x%x%x%x%x)%s*$")
end

local function Assign(color, digits)
    color.R = tonumber(digits:sub(1, 2), 16) / 255
    color.G = tonumber(digits:sub(3, 4), 16) / 255
    color.B = tonumber(digits:sub(5, 6), 16) / 255
    color.A = 1
end

local function Roll(color)
    color.R = math.random(0, 255) / 255
    color.G = math.random(0, 255) / 255
    color.B = math.random(0, 255) / 255
    color.A = 1
end

local function Template()
    local primary, secondary = Paint.Primary, Paint.Secondary

    local data = GenericTemplatePersistentData.new()
    data.primaryColorDefined = true
    data.primaryColorR = Linear(primary.R)
    data.primaryColorG = Linear(primary.G)
    data.primaryColorB = Linear(primary.B)
    data.secondaryColorDefined = true
    data.secondaryColorR = Linear(secondary.R)
    data.secondaryColorG = Linear(secondary.G)
    data.secondaryColorB = Linear(secondary.B)

    local template = VehicleVisualCustomizationTemplate.new()
    template.hasUniqueTemplate = false
    template.genericData = data
    return template
end

local function Send(vehicle, template, reset)
    local event = NewVehicleVisualCustomizationEvent.new()
    event.template = template
    event.reset = reset
    vehicle:QueueEvent(event)
end

local function Supported(vehicle)
    local record = vehicle and vehicle:GetRecord()
    return record ~= nil and record:HasVisualCustomization() and not record:VisualCustomizationTeaser()
end

Paint.Supported = Supported

local function PaintAllowed(component, wrapped)
    if Paint.AnyVehicle then
        local ok, supported = pcall(function() return Supported(component:GetEntity()) end)
        if ok and supported then return true end
    end
    return wrapped()
end

function Paint.Initialize()
    Override("VehicleComponent", "GetIsVehicleVisualCustomizationEnabled", PaintAllowed)
end

function Paint.Changed()
    s_ChangedAt = os.clock()
end

function Paint.Swap()
    local primary, secondary = Paint.Primary, Paint.Secondary
    primary.R, secondary.R = secondary.R, primary.R
    primary.G, secondary.G = secondary.G, primary.G
    primary.B, secondary.B = secondary.B, primary.B
    Paint.Changed()
end

function Paint.Randomize()
    Roll(Paint.Primary)
    Roll(Paint.Secondary)
    Paint.Changed()
end

function Paint.Load(entry)
    local primary, secondary = HexDigits(entry.Primary), HexDigits(entry.Secondary)
    if not primary or not secondary then return false end

    Assign(Paint.Primary, primary)
    Assign(Paint.Secondary, secondary)
    return true
end

function Paint.Save(name)
    local primary, secondary = ToHex(Paint.Primary), ToHex(Paint.Secondary)
    name = tostring(name or ""):match("^%s*(.-)%s*$")
    if name == "" then name = primary .. " / " .. secondary end

    table.insert(Paint.Saved, { Name = name, Primary = primary, Secondary = secondary })
    return name
end

function Paint.Color(hex)
    local color = { R = 0, G = 0, B = 0, A = 1 }
    local digits = HexDigits(hex)
    if digits then Assign(color, digits) end
    return color
end

function Paint.Delete(entry)
    for index, saved in ipairs(Paint.Saved) do
        if saved == entry then
            table.remove(Paint.Saved, index)
            return
        end
    end
end

local function Warn(vehicle, explicit, key)
    local id = vehicle:GetEntityID().hash
    if not explicit and s_Warned == id then return end
    s_Warned = id
    Notify.Warning(L(key))
end

function Paint.Apply(vehicle, explicit)
    s_ChangedAt = nil

    if not Supported(vehicle) then
        Warn(vehicle, explicit, "notify.paint.unsupported")
        return false
    end

    local component = vehicle:GetVehicleComponent()
    if not component:GetIsVehicleVisualCustomizationEnabled() then
        Warn(vehicle, explicit, "vehicles.paint.locked")
        return false
    end

    vehicle:GetVehiclePS():SetVehicleVisualCustomizationnBlockedByDamage(false)

    local template = Template()
    if not component:CanApplyTemplateOnVehicle(template, true) then
        if explicit then Notify.Warning(L("notify.paint.busy")) end
        return false
    end

    Send(vehicle, template, false)
    if explicit then Notify.Success(L("notify.paint.applied")) end
    return true
end

function Paint.Reset(vehicle)
    s_ChangedAt = nil
    if not Supported(vehicle) then
        Notify.Warning(L("notify.paint.unsupported"))
        return
    end
    Send(vehicle, VehicleVisualCustomizationTemplate.new(), true)
    Notify.Success(L("notify.paint.reset"))
end

function Paint.Update(player, now)
    if not s_ChangedAt or now - s_ChangedAt < APPLY_DELAY then return end
    s_ChangedAt = nil

    local vehicle = Vehicle.Mounted(player)
    if vehicle then Paint.Apply(vehicle) end
end

function Paint.Forget()
    s_ChangedAt = nil
    s_Warned = nil
end

return Paint
