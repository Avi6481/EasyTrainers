local Draw = require("Core/Draw")

local RichText = {}

local function Push(runs, text, strong)
    if text == "" then return end

    local last = runs[#runs]
    if last and last.Strong == strong then
        last.Text = last.Text .. text
        return
    end
    table.insert(runs, { Text = text, Strong = strong })
end

local function Trim(paragraphs)
    while #paragraphs > 0 and #paragraphs[#paragraphs] == 0 do table.remove(paragraphs) end
    while #paragraphs > 0 and #paragraphs[1] == 0 do table.remove(paragraphs, 1) end
    return paragraphs
end

function RichText.Parse(text)
    text = tostring(text or ""):gsub("\r", ""):gsub("<[Bb][Rr]%s*/?>", "\n"):gsub("{[^}]*}", "")

    local paragraphs = {}
    local depth = 0
    for line in (text .. "\n"):gmatch("(.-)\n") do
        local runs = {}
        local position = 1

        while true do
            local first, last, tag = line:find("<([^>]*)>", position)
            if not first then break end

            Push(runs, line:sub(position, first - 1), depth > 0)
            if tag:sub(1, 1) == "/" then
                depth = math.max(0, depth - 1)
            elseif tag:lower():find("^rich") then
                depth = depth + 1
            end
            position = last + 1
        end

        Push(runs, line:sub(position), depth > 0)
        if #runs == 1 and not runs[1].Text:find("%S") then runs = {} end
        table.insert(paragraphs, runs)
    end
    return Trim(paragraphs)
end

local function Words(runs)
    local words = {}
    local word = nil

    for _, run in ipairs(runs) do
        local text = run.Text
        local position = 1
        while position <= #text do
            local first, last = text:find("%s+", position)
            if first == position then
                word = nil
                position = last + 1
            else
                local stop = first and (first - 1) or #text
                if not word then
                    word = {}
                    table.insert(words, word)
                end
                table.insert(word, { Text = text:sub(position, stop), Strong = run.Strong })
                position = stop + 1
            end
        end
    end
    return words
end

local function Append(line, x, text, strong, gap)
    local last = line[#line]
    if last and last.Strong == strong then
        last.Text = last.Text .. (gap and " " or "") .. text
        return
    end
    table.insert(line, { X = x, Text = text, Strong = strong })
end

function RichText.Layout(paragraphs, width, size)
    local _, lineHeight = Draw.TextSize("Ag", size)
    local space = Draw.TextSize(" ", size)
    local lines = {}

    for _, runs in ipairs(paragraphs) do
        local line = {}
        local x = 0

        for _, word in ipairs(Words(runs)) do
            local wordWidth = 0
            for _, part in ipairs(word) do
                part.Width = Draw.TextSize(part.Text, size)
                wordWidth = wordWidth + part.Width
            end

            local gap = #line > 0
            local start = gap and (x + space) or 0
            if gap and start + wordWidth > width then
                table.insert(lines, line)
                line = {}
                gap = false
                start = 0
            end

            x = start
            for index, part in ipairs(word) do
                Append(line, x, part.Text, part.Strong, gap and index == 1)
                x = x + part.Width
            end
        end
        table.insert(lines, line)
    end
    return lines, lineHeight
end

return RichText
