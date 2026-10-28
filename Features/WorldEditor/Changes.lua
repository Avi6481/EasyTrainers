local Changes = {}

local s_MarkedAt = nil
local s_Muted = false

function Changes.Mark()
    if not s_Muted then s_MarkedAt = os.clock() end
end

function Changes.MarkedAt()
    return s_MarkedAt
end

function Changes.Clear()
    s_MarkedAt = nil
end

function Changes.Mute(muted)
    s_Muted = muted == true
end

return Changes
