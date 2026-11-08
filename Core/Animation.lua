local Animation = {}

local s_Delta = 0

function Animation.SetDelta(delta)
    s_Delta = delta or 0
end

function Animation.Delta()
    return s_Delta
end

function Animation.Clamp(value, minimum, maximum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

function Animation.Animate(current, target, speed, delta)
    return current + ((target - current) * (1 - math.exp(-speed * delta)))
end

function Animation.SmoothDamp(current, target, velocity, smoothTime, delta)
    if delta <= 0 then return current, velocity end

    smoothTime = math.max(0.0001, smoothTime)
    local omega = 2 / smoothTime
    local x = omega * delta
    local decay = 1 / (1 + x + (0.48 * x * x) + (0.235 * x * x * x))
    local change = current - target
    local temp = (velocity + (omega * change)) * delta
    velocity = (velocity - (omega * temp)) * decay
    local output = target + ((change + temp) * decay)

    if (target - current > 0) == (output > target) then
        output = target
        velocity = 0
    end

    return output, velocity
end

function Animation.EaseOut(t)
    t = Animation.Clamp(t, 0, 1)
    local inverse = 1 - t
    return 1 - (inverse * inverse * inverse)
end

function Animation.Lerp(a, b, t)
    return a + ((b - a) * t)
end

local function Channels(color)
    local r = color % 256
    local g = math.floor(color / 0x100) % 256
    local b = math.floor(color / 0x10000) % 256
    local a = math.floor(color / 0x1000000) % 256
    return r, g, b, a
end

function Animation.LerpColor(first, second, t)
    if t <= 0 then return first end
    if t >= 1 then return second end

    local r1, g1, b1, a1 = Channels(first)
    local r2, g2, b2, a2 = Channels(second)
    local r = math.floor(r1 + ((r2 - r1) * t) + 0.5)
    local g = math.floor(g1 + ((g2 - g1) * t) + 0.5)
    local b = math.floor(b1 + ((b2 - b1) * t) + 0.5)
    local a = math.floor(a1 + ((a2 - a1) * t) + 0.5)
    return (a * 0x1000000) + (b * 0x10000) + (g * 0x100) + r
end

function Animation.NewTypewriter()
    return { Current = "", Displayed = "", Index = 0, Accumulator = 0, Typing = false }
end

local function IsContinuation(text, index)
    local byte = text:byte(index)
    return byte ~= nil and byte >= 0x80 and byte < 0xC0
end

function Animation.TypewriterSet(writer, text)
    if text == writer.Current then return end

    local shared = 0
    local limit = math.min(#writer.Displayed, #text)
    while shared < limit and writer.Displayed:byte(shared + 1) == text:byte(shared + 1) do
        shared = shared + 1
    end
    while shared > 0 and shared < #text and IsContinuation(text, shared + 1) do
        shared = shared - 1
    end

    writer.Current = text
    writer.Displayed = text:sub(1, shared)
    writer.Index = shared
    writer.Accumulator = 0
    writer.Typing = writer.Index < #text
end

function Animation.TypewriterUpdate(writer, delta, charactersPerSecond)
    if not writer.Typing then return end

    writer.Accumulator = writer.Accumulator + (charactersPerSecond * delta)
    while writer.Accumulator >= 1 and writer.Index < #writer.Current do
        local index = writer.Index + 1
        while index < #writer.Current and IsContinuation(writer.Current, index + 1) do
            index = index + 1
        end
        writer.Index = index
        writer.Displayed = writer.Current:sub(1, index)
        writer.Accumulator = writer.Accumulator - 1
    end

    if writer.Index >= #writer.Current then writer.Typing = false end
end

return Animation
