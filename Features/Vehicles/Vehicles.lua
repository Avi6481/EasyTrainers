local Logger = require("Core/Logger")
local Notify = require("Utils/Notify")
local Vehicle = require("Utils/Vehicle")
local Catalog = require("Features/Vehicles/Catalog")
local Garage = require("Features/Vehicles/Garage")
local Spawner = require("Features/Vehicles/Spawner")
local Controls = require("Features/Vehicles/Controls")
local GodMode = require("Features/Vehicles/GodMode")
local Repair = require("Features/Vehicles/Repair")
local LostParts = require("Features/Vehicles/LostParts")
local Nitro = require("Features/Vehicles/Nitro")
local BunnyHop = require("Features/Vehicles/BunnyHop")
local Upright = require("Features/Vehicles/Upright")
local Lights = require("Features/Vehicles/Lights")
local TwinTone = require("Features/Vehicles/TwinTone")
local Preview = require("Features/Vehicles/Preview")
local InstantStop = require("Features/Vehicles/InstantStop")
local Paint = require("Features/Vehicles/Paint")
local Performance = require("Features/Vehicles/Performance")
local Speedometer = require("Features/Vehicles/Speedometer")
local Bounce = require("Features/Vehicles/Bounce")
local AutoFlip = require("Features/Vehicles/AutoFlip")
local StayOnBike = require("Features/Vehicles/StayOnBike")

local Vehicles = {
    SpawnDistance = 7,
    MountOnSpawn = true,
    ReplacePrevious = true,
    AddToGarage = false,
    GarageFilter = "All"
}

Vehicles.Controls = Controls
Vehicles.GodMode = GodMode
Vehicles.Repair = Repair
Vehicles.Nitro = Nitro
Vehicles.BunnyHop = BunnyHop
Vehicles.Lights = Lights
Vehicles.Preview = Preview
Vehicles.InstantStop = InstantStop
Vehicles.Paint = Paint
Vehicles.Performance = Performance
Vehicles.Speedometer = Speedometer
Vehicles.Bounce = Bounce
Vehicles.AutoFlip = AutoFlip
Vehicles.StayOnBike = StayOnBike

local WATCH_TIME = 1
local GARAGE_INTERVAL = 1
local MAX_DELTA = 0.1

local s_Queue = {}
local s_WatchUntil = 0
local s_NextGarage = 0
local s_LastClock = nil
local s_Failed = {}

local function Try(name, callback, ...)
    local ok, err = pcall(callback, ...)
    if not ok and not s_Failed[name] then
        s_Failed[name] = true
        Logger.Log(name .. " failed: " .. tostring(err))
    end
    return ok
end

function Vehicles.Watch()
    s_WatchUntil = os.clock() + WATCH_TIME
end

local function Queue(action)
    table.insert(s_Queue, action)
end

local function Mounted(action)
    Queue(function(player)
        local vehicle = Vehicle.Mounted(player)
        if not vehicle then return Notify.Warning(L("vehicles.mounted.none")) end
        action(player, vehicle)
    end)
end

Vehicles.Mounted = Mounted

function Vehicles.Spawn(vehicle)
    Queue(function(player)
        Preview.Clear(player)
        Spawner.Spawn(player, vehicle, Vehicles.SpawnDistance, Vehicles.MountOnSpawn, Vehicles.ReplacePrevious)
        if Vehicles.AddToGarage and not Garage.IsUnlocked(vehicle) then Garage.Set(vehicle, true) end
    end)
end

function Vehicles.WantPreview(vehicle)
    if Preview.Enabled then Preview.Want(vehicle) end
end

function Vehicles.BringLast()
    Queue(function(player)
        local vehicle = Spawner.Last()
        if not vehicle then return Notify.Warning(L("vehicles.despawnlast.none")) end
        local transform = Vehicle.SpawnTransform(player, Vehicles.SpawnDistance)
        local position = transform.Position:ToVector4()
        Game.GetTeleportationFacility():Teleport(vehicle, position, EulerAngles.new(0, 0, player:GetWorldYaw()))
    end)
end

function Vehicles.DespawnLast()
    Queue(function(player)
        if not Spawner.DespawnLast(player) then Notify.Warning(L("vehicles.despawnlast.none")) end
    end)
end

function Vehicles.DespawnAll()
    Queue(function(player)
        local count = Spawner.DespawnAll(player)
        if count > 0 then
            Notify.Success(tip("notify.vehicles.despawned", { count = count }))
        else
            Notify.Info(L("vehicles.despawnlast.none"))
        end
    end)
end

function Vehicles.SetGarage(vehicle, enable)
    Queue(function() Garage.Set(vehicle, enable) end)
end

function Vehicles.SetGarageMany(predicate, enable)
    Queue(function()
        Garage.SetMany(predicate, enable)
        s_NextGarage = 0
    end)
end

function Vehicles.RepairNow()
    Mounted(function(_, vehicle)
        Repair.Fix(vehicle)
        Notify.Success(L("notify.vehicles.repaired"))
    end)
end

function Vehicles.RestoreParts()
    Mounted(function(player, vehicle) LostParts.Restore(player, vehicle) end)
end

function Vehicles.Flip()
    Mounted(function(_, vehicle) Upright.Flip(vehicle) end)
end

function Vehicles.Roof()
    Mounted(function(player) Vehicle.Unmount(player, true) end)
end

function Vehicles.LightColor(kind, color)
    Mounted(function(_, vehicle)
        if kind then
            Lights.SetColor(vehicle, kind, color)
        else
            Lights.SetAll(vehicle, color)
        end
    end)
end

function Vehicles.LightStrength(strength, kind)
    Mounted(function(_, vehicle) Lights.SetStrength(vehicle, strength, kind) end)
end

function Vehicles.LightResetOne(kind)
    Mounted(function(_, vehicle) Lights.ResetOne(vehicle, kind) end)
end

function Vehicles.ReloadCatalog()
    Queue(function()
        Catalog.Load()
        s_NextGarage = 0
        Notify.Success(tip("notify.vehicles.reloaded", { count = #Catalog.Browsable }))
    end)
end

function Vehicles.LightSwitch(kind, on)
    Mounted(function(_, vehicle) Lights.Switch(vehicle, kind, on) end)
end

function Vehicles.LightReset()
    Mounted(function(_, vehicle) Lights.Reset(vehicle) end)
end

function Vehicles.Bind(store)
    store:Bind("Vehicles", Vehicles, { "SpawnDistance", "MountOnSpawn", "ReplacePrevious", "AddToGarage", "GarageFilter" })
    store:Bind("Vehicles.Preview", Preview, { "Enabled" })
    store:Bind("Vehicles.InstantStop", InstantStop, { "Enabled" })
    store:Bind("Vehicles.GodMode", GodMode, { "Enabled" })
    store:Bind("Vehicles.Repair", Repair, { "Auto" })
    store:Bind("Vehicles.Nitro", Nitro, { "Enabled", "Strength" })
    store:Bind("Vehicles.BunnyHop", BunnyHop, { "Enabled", "Height" })
    store:Bind("Vehicles.Bounce", Bounce, { "Enabled", "Strength", "Tempo" })
    store:Bind("Vehicles.AutoFlip", AutoFlip, { "Enabled" })
    store:Bind("Vehicles.StayOnBike", StayOnBike, { "Enabled" })
    store:Bind("Vehicles.Lights", Lights, { "Fade", "FadeSpeed", "AllColor", "SingleColor", "Strength", "SingleStrength", "Kind" })
    store:Bind("Vehicles.Controls", Controls, { "Binds" })
    store:Bind("Vehicles.Paint", Paint, { "AnyVehicle", "Primary", "Secondary", "Saved" })
    store:Bind("Vehicles.Performance", Performance, {
        "Enabled", "EnginePower", "TopSpeedBonus", "Acceleration", "ShiftSpeed", "FrontGrip", "RearGrip",
        "SteeringLock", "Downforce", "AirControl", "Braking", "Handbrake", "Presets"
    })
    store:Bind("Vehicles.Speedometer", Speedometer, {
        "Enabled", "ShowRpm", "UseMph", "HideGameSpeedometer", "AutoMax", "MaxSpeed", "Scale", "Position",
        "OffsetX", "OffsetY", "ActiveColor", "NeedleColor", "TextColor", "MutedColor", "RingColor"
    })
    Controls.Fill()
end

function Vehicles.Initialize()
    Try("Twin tone", TwinTone.Initialize)
    Try("Vehicle paint", Paint.Initialize)
    Try("Stay on bike", StayOnBike.Initialize)
    Try("Speedometer", Speedometer.Initialize)
end

local function RunQueue(player)
    local queue = s_Queue
    s_Queue = {}
    for _, action in ipairs(queue) do Try("Vehicle action", action, player) end
end

local function Driving()
    return GodMode.Enabled or Repair.Auto or Nitro.Enabled or BunnyHop.Enabled or InstantStop.Enabled or Lights.Fade
        or Speedometer.Enabled or Performance.Active() or Bounce.Enabled or AutoFlip.Enabled
end

local function Drive(player, now)
    local delta = math.min(MAX_DELTA, now - (s_LastClock or now))
    s_LastClock = now
    if not Driving() then
        Lights.Update(nil, delta, now)
        Try("Vehicle speedometer", Speedometer.Update, nil, delta, now)
        return
    end

    local vehicle = Vehicle.Mounted(player)
    if Nitro.Enabled or BunnyHop.Enabled or InstantStop.Enabled then Controls.Update() end

    Try("Vehicle god mode", GodMode.Update, vehicle)
    Try("Vehicle auto repair", Repair.Update, vehicle, now)
    Try("Vehicle nitro", Nitro.Update, vehicle, delta)
    Try("Vehicle bunny hop", BunnyHop.Update, vehicle, now)
    Try("Vehicle instant stop", InstantStop.Update, vehicle)
    Try("Vehicle auto flip", AutoFlip.Update, vehicle, now)
    Try("Vehicle bounce", Bounce.Update, vehicle, delta)
    Try("Vehicle light fade", Lights.Update, vehicle, delta, now)
    Try("Vehicle performance", Performance.Update, vehicle, delta, now)
    Try("Vehicle speedometer", Speedometer.Update, vehicle, delta, now)
end

function Vehicles.Update(player)
    local now = os.clock()
    Try("Vehicle spawner", Spawner.Update, player)
    if #s_Queue > 0 then RunQueue(player) end
    Drive(player, now)
    Try("Vehicle preview", Preview.Update, player, now, Vehicles.SpawnDistance)
    Try("Vehicle paint", Paint.Update, player, now)

    if now >= s_WatchUntil then return end
    if not Catalog.Loaded then Try("Vehicle catalog", Catalog.Load) end
    if now >= s_NextGarage then
        s_NextGarage = now + GARAGE_INTERVAL
        Try("Vehicle garage", Garage.Refresh)
    end
end

function Vehicles.Reset()
    s_Queue = {}
    Spawner.Reset()
    Garage.Clear()
    GodMode.Reset()
    Lights.Forget()
    Preview.Reset()
    Paint.Forget()
    Performance.Reset()
    Speedometer.Reset()
end

function Vehicles.Shutdown()
    s_Queue = {}
    Try("Vehicle god mode", GodMode.Shutdown)
    Try("Vehicle performance", Performance.Shutdown)
    Try("Vehicle speedometer", Speedometer.Shutdown)
end

return Vehicles
