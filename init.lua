local Logger = require("Core/Logger")
local Input = require("Core/Input")
local State = require("Core/State")

local EasyTrainer = {
    Version = "2.4"
}

local MAX_DELTA = 0.1

local s_Render = nil
local s_Features = nil
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

registerForEvent("onInit", function()
    Input.Initialize()
    require("Features/Settings/Settings").Initialize()

    local features = require("Features/Features")
    features.Initialize()

    local render = require("Render")
    render.Initialize(require("View/MainMenu").Root())

    s_Features = features
    s_Render = render
    Logger.Log("EasyTrainer " .. EasyTrainer.Version .. " initialized")
end)

registerForEvent("onUpdate", function()
    if s_Features then Try("Features", s_Features.Update) end
end)

registerForEvent("onOverlayOpen", function()
    State.OverlayOpen = true
end)

registerForEvent("onOverlayClose", function()
    State.OverlayOpen = false
end)

registerForEvent("onDraw", function()
    if not s_Render then return end

    local now = os.clock()
    local delta = s_LastClock and (now - s_LastClock) or (1 / 60)
    s_LastClock = now

    Try("Render", s_Render.Draw, math.max(0, math.min(MAX_DELTA, delta)))
end)

registerForEvent("onShutdown", function()
    if s_Features then Try("Features shutdown", s_Features.Shutdown) end
    if s_Render then Try("Render shutdown", s_Render.Shutdown) end
end)

return EasyTrainer
