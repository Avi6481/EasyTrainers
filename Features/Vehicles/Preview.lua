local Spawner = require("Features/Vehicles/Spawner")

local Preview = {
    Enabled = false
}

local SETTLE = 0.35
local LINGER = 0.5

local s_Wanted = nil
local s_WantedAt = 0
local s_SeenAt = 0
local s_Shown = nil
local s_ShownId = nil

function Preview.Want(vehicle)
    local now = os.clock()
    s_SeenAt = now
    if vehicle ~= s_Wanted then
        s_Wanted = vehicle
        s_WantedAt = now
    end
end

function Preview.Clear(player)
    if s_ShownId then Spawner.Despawn(player, s_ShownId) end
    s_Shown = nil
    s_ShownId = nil
    s_Wanted = nil
end

function Preview.Update(player, now, distance)
    if not Preview.Enabled or now - s_SeenAt > LINGER then
        if s_ShownId then Preview.Clear(player) end
        return
    end
    if not s_Wanted or s_Wanted == s_Shown or now - s_WantedAt < SETTLE then return end

    if s_ShownId then Spawner.Despawn(player, s_ShownId) end
    s_Shown = s_Wanted
    s_ShownId = Spawner.SpawnPreview(player, s_Wanted, distance)
end

function Preview.Reset()
    s_Shown = nil
    s_ShownId = nil
    s_Wanted = nil
end

return Preview
