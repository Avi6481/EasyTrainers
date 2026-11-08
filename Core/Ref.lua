local Ref = {}

function Ref.New(read, write)
    return setmetatable({}, {
        __index = function(_, name)
            if name == "Value" then return read() end
        end,
        __newindex = function(_, name, value)
            if name == "Value" then write(value) end
        end
    })
end

function Ref.Field(target, key)
    return Ref.New(function() return target[key] end, function(value) target[key] = value end)
end

function Ref.Scaled(target, key, factor)
    return Ref.New(function() return target[key] * factor end, function(value) target[key] = value / factor end)
end

function Ref.Choice(target, key, values)
    local function Index()
        for index, value in ipairs(values) do
            if value == target[key] then return index end
        end
        return 1
    end

    return Ref.New(Index, function(index)
        if values[index] ~= nil then target[key] = values[index] end
    end)
end

return Ref
