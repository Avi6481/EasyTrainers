local Lights = {
    Fade = false,
    FadeSpeed = 0.2,
    AllColor = { R = 1, G = 1, B = 1, A = 1 },
    SingleColor = { R = 1, G = 1, B = 1, A = 1 },
    Strength = 1,
    SingleStrength = 1,
    Kind = 1
}

Lights.Types = { "Head", "Brake", "LeftBlinker", "RightBlinker", "Reverse", "Interior", "Utility", "Default", "Blinkers" }

local FADE_STEP = 0.05

local s_Fading = nil
local s_Hue = 0
local s_NextFade = 0

local function Controller(vehicle)
    return vehicle and vehicle:GetAccessoryController()
end

local function GameColor(color)
    return Color.new({
        Red = math.floor((color.R * 255) + 0.5),
        Green = math.floor((color.G * 255) + 0.5),
        Blue = math.floor((color.B * 255) + 0.5),
        Alpha = 255
    })
end

local function Hue(hue)
    local sector = math.floor(hue * 6)
    local part = (hue * 6) - sector
    local rising, falling = part, 1 - part
    local colors = {
        { 1, rising, 0 }, { falling, 1, 0 }, { 0, 1, rising },
        { 0, falling, 1 }, { rising, 0, 1 }, { 1, 0, falling }
    }
    local rgb = colors[(sector % 6) + 1]
    return { R = rgb[1], G = rgb[2], B = rgb[3], A = 1 }
end

function Lights.SetColor(vehicle, kind, color)
    local controller = Controller(vehicle)
    if controller then controller:SetLightColor(vehicleELightType[kind], GameColor(color), 0) end
end

function Lights.SetAll(vehicle, color)
    local controller = Controller(vehicle)
    if not controller then return end

    local value = GameColor(color)
    for _, kind in ipairs(Lights.Types) do controller:SetLightColor(vehicleELightType[kind], value, 0) end
end

function Lights.SetStrength(vehicle, strength, kind)
    local controller = Controller(vehicle)
    if not controller then return end
    if kind then
        controller:SetLightStrength(vehicleELightType[kind], strength, 0)
        return
    end
    for _, each in ipairs(Lights.Types) do controller:SetLightStrength(vehicleELightType[each], strength, 0) end
end

function Lights.ResetOne(vehicle, kind)
    local controller = Controller(vehicle)
    if not controller then return end
    controller:ResetLightColor(vehicleELightType[kind], 0)
    controller:ResetLightStrength(vehicleELightType[kind], 0)
end

function Lights.Switch(vehicle, kind, on)
    local controller = Controller(vehicle)
    if controller then controller:ToggleLights(on, vehicleELightType[kind], 0, "", false) end
end

function Lights.Reset(vehicle)
    local controller = Controller(vehicle)
    if not controller then return end

    for _, kind in ipairs(Lights.Types) do
        controller:ResetLightColor(vehicleELightType[kind], 0)
        controller:ResetLightStrength(vehicleELightType[kind], 0)
    end
end

function Lights.Update(vehicle, delta, now)
    if not Lights.Fade then
        if s_Fading then
            Lights.Reset(s_Fading)
            s_Fading = nil
        end
        return
    end
    if not vehicle then return end

    s_Fading = vehicle
    s_Hue = (s_Hue + (Lights.FadeSpeed * delta)) % 1
    if now < s_NextFade then return end
    s_NextFade = now + FADE_STEP
    Lights.SetAll(vehicle, Hue(s_Hue))
end

function Lights.Forget()
    s_Fading = nil
end

return Lights
