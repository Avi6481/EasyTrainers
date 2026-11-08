local Logger = require("Core/Logger")

local JsonHelper = {}

function JsonHelper.Read(path, options)
    options = options or {}

    local file, err, code = io.open(path, "r")
    if not file then
        local missing = code == 2 or tostring(err):lower():find("no such file", 1, true) ~= nil
        local status = missing and "missing" or "open_failed"
        if not missing or not options.SilentMissing then
            Logger.Log("JsonHelper: failed to open " .. tostring(path) .. " (" .. tostring(err) .. ")")
        end
        return nil, "Could not open file: " .. path, status
    end

    local content = file:read("*a")
    file:close()

    local ok, result = pcall(json.decode, content)
    if not ok or result == nil then
        Logger.Log("JsonHelper: invalid JSON in " .. tostring(path))
        return nil, "Invalid JSON format in: " .. path, "invalid"
    end

    return result, nil
end

function JsonHelper.ReadOptional(path)
    return JsonHelper.Read(path, { SilentMissing = true })
end

local function Backup(path)
    local source = io.open(path, "r")
    if not source then return false end
    local content = source:read("*a")
    source:close()

    local target = io.open(path .. ".bak", "w")
    if not target then return false end
    target:write(content or "")
    target:close()
    return true
end

function JsonHelper.LoadOrCreate(path, defaults)
    local data, err, status = JsonHelper.ReadOptional(path)
    if type(data) == "table" then return data, false, nil end
    if status == "open_failed" then return nil, false, err end
    if status ~= "missing" then
        local kept = Backup(path)
        Logger.Log("JsonHelper: replacing unreadable " .. tostring(path) .. (kept and ", old copy kept as .bak" or ""))
    end

    local ok, writeErr = JsonHelper.Write(path, defaults or {})
    if not ok then return nil, false, writeErr end

    Logger.Log("JsonHelper: created default file " .. tostring(path))
    return defaults or {}, true, nil
end

function JsonHelper.Write(path, data)
    local ok, content = pcall(json.encode, data)
    if not ok then
        Logger.Log("JsonHelper: failed to encode " .. tostring(path) .. " (" .. tostring(content) .. ")")
        return false, "Failed to encode JSON: " .. tostring(content)
    end

    local file, err = io.open(path, "w")
    if not file then
        Logger.Log("JsonHelper: failed to open for write " .. tostring(path) .. " (" .. tostring(err) .. ")")
        return false, "Could not open file for writing: " .. path
    end

    local written, writeErr = file:write(content)
    local closed = file:close()
    if not written or not closed then
        Logger.Log("JsonHelper: failed to write " .. tostring(path) .. " (" .. tostring(writeErr) .. ")")
        return false, "Could not write file: " .. path
    end
    return true
end

return JsonHelper
