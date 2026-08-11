local Animation = { States = {} }

function Animation.Animate(current, target, speed, deltaTime)
    local amount = 1 - math.exp(-(speed or 12) * (deltaTime or 0))
    return current + (target - current) * amount
end

Animation.Approach = Animation.Animate

function Animation.Value(id, target, speed, deltaTime, initial)
    local current = Animation.States[id]
    if current == nil then current = initial == nil and target or initial end
    current = Animation.Animate(current, target, speed, deltaTime)
    Animation.States[id] = current
    return current
end

function Animation.Lerp(a, b, amount)
    return a + ((b - a) * amount)
end

function Animation.LerpColor(a, b, amount)
    local first = ImGui.ColorConvertU32ToFloat4(a)
    local second = ImGui.ColorConvertU32ToFloat4(b)
    return ImGui.ColorConvertFloat4ToU32({
        Animation.Lerp(first[1], second[1], amount),
        Animation.Lerp(first[2], second[2], amount),
        Animation.Lerp(first[3], second[3], amount),
        Animation.Lerp(first[4], second[4], amount),
    })
end

function Animation.WithAlpha(color, alpha)
    local baseAlpha = math.floor(color / 0x1000000) % 0x100
    local scaledAlpha = math.floor(baseAlpha * math.max(0, math.min(1, alpha)))
    return (color % 0x1000000) + (scaledAlpha * 0x1000000)
end

local function NextUtf8(text, index)
    local byte = text:byte(index)
    if not byte then return index end
    if byte < 0x80 then return index + 1 end
    if byte < 0xE0 then return index + 2 end
    if byte < 0xF0 then return index + 3 end
    return index + 4
end

function Animation.CreateTypewriter()
    return { Current = "", Displayed = "", ByteIndex = 1, Accumulator = 0, CursorTimer = 0, Typing = false }
end

function Animation.SetText(writer, text)
    text = tostring(text or "")
    if writer.Current == text then return end

    local shared = 0
    local limit = math.min(#writer.Displayed, #text)
    while shared < limit and writer.Displayed:byte(shared + 1) == text:byte(shared + 1) do
        shared = shared + 1
    end
    while shared > 0 and text:byte(shared) >= 0x80 and text:byte(shared) < 0xC0 do
        shared = shared - 1
    end

    writer.Current = text
    writer.Displayed = text:sub(1, shared)
    writer.ByteIndex = shared + 1
    writer.Accumulator = 0
    writer.CursorTimer = 0
    writer.Typing = writer.ByteIndex <= #text
end

function Animation.UpdateTypewriter(writer, deltaTime, charactersPerSecond)
    local dt = deltaTime or 0
    writer.CursorTimer = writer.CursorTimer + dt
    if not writer.Typing then return end

    writer.Accumulator = writer.Accumulator + ((charactersPerSecond or 45) * dt)
    while writer.Accumulator >= 1 and writer.ByteIndex <= #writer.Current do
        local nextIndex = NextUtf8(writer.Current, writer.ByteIndex)
        writer.Displayed = writer.Current:sub(1, nextIndex - 1)
        writer.ByteIndex = nextIndex
        writer.Accumulator = writer.Accumulator - 1
    end
    if writer.ByteIndex > #writer.Current then writer.Typing = false end
end

function Animation.CursorVisible(writer)
    return writer.Typing and (writer.CursorTimer % 1) < 0.5
end

return Animation
