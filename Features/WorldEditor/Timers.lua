local Timers = {}

local FLUSH_PASSES = 4

local s_List = {}

local function Add(delay, interval, callback)
    local timer = { At = os.clock() + delay, Interval = interval, Callback = callback }
    table.insert(s_List, timer)
    return timer
end

function Timers.After(delay, callback)
    return Add(delay, nil, callback)
end

function Timers.Every(interval, callback)
    return Add(interval, interval, callback)
end

function Timers.Halt(timer)
    if timer then timer.Halted = true end
end

function Timers.Update()
    if #s_List == 0 then return end

    local now = os.clock()
    local list = s_List
    local due = {}
    s_List = {}

    for _, timer in ipairs(list) do
        if not timer.Halted then
            if now < timer.At then
                table.insert(s_List, timer)
            else
                table.insert(due, timer)
                if timer.Interval then
                    timer.At = now + timer.Interval
                    table.insert(s_List, timer)
                end
            end
        end
    end

    local failure = nil
    for _, timer in ipairs(due) do
        if not timer.Halted then
            local ok, err = pcall(timer.Callback, timer)
            if not ok and not failure then failure = err end
        end
    end
    if failure then error(failure, 0) end
end

function Timers.Flush()
    for _ = 1, FLUSH_PASSES do
        local list = s_List
        s_List = {}
        if #list == 0 then return end
        for _, timer in ipairs(list) do
            if not timer.Halted and not timer.Interval then pcall(timer.Callback, timer) end
        end
    end
    s_List = {}
end

function Timers.Clear()
    s_List = {}
end

return Timers
