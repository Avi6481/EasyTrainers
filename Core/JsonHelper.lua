local JsonHelper = {}
local Logger = require("Core/Logger")

---Read and decode a JSON file.
---@param path string
---@param options table|nil { SilentMissing:boolean }
---@return table|nil data
---@return string|nil err
---@return string|nil status "missing", "open_failed", or "invalid"
function JsonHelper.Read(path, options)
    options = options or {}
    local file, err, code = io.open(path, "r")
    if not file then
        local message = "Could not open file: " .. path
        local missing = code == 2 or tostring(err):lower():find("no such file", 1, true) ~= nil
        local status = missing and "missing" or "open_failed"
        if status ~= "missing" or not options.SilentMissing then
            Logger.Log("Failed to open for read: " .. tostring(path) .. " (" .. tostring(err) .. ")")
        end
        return nil, message, status
    end

    local content = file:read("*a")
    file:close()

    local ok, result = pcall(json.decode, content)
    if not ok or result == nil then
        Logger.Log("Invalid JSON format in: " .. tostring(path))
        return nil, "Invalid JSON format in: " .. path, "invalid"
    end

    return result, nil
end

---Read a file that is allowed not to exist yet.
function JsonHelper.ReadOptional(path)
    return JsonHelper.Read(path, { SilentMissing = true })
end

---Load JSON or create it from defaults on first run.
---Existing unreadable or malformed files are never overwritten.
---@return table|nil data
---@return boolean created
---@return string|nil err
function JsonHelper.LoadOrCreate(path, defaults)
    local data, err, status = JsonHelper.ReadOptional(path)
    if type(data) == "table" then return data, false, nil end
    if status ~= "missing" then return nil, false, err end

    local ok, writeErr = JsonHelper.Write(path, defaults or {})
    if not ok then return nil, false, writeErr end

    Logger.Log("Created default JSON file: " .. tostring(path))
    return defaults or {}, true, nil
end

---Encode and write a table to a JSON file  
---@param path string Path to the file to write  
---@param data table Table to serialize into JSON  
---@return boolean ok True if written successfully  
---@return string|nil err Error message if failed  
function JsonHelper.Write(path, data)
    local ok, content = pcall(json.encode, data)
    if not ok then
        Logger.Log("Failed to encode JSON for: " .. tostring(path) .. " (" .. tostring(content) .. ")")
        return false, "Failed to encode JSON: " .. tostring(content)
    end

    local file, err = io.open(path, "w")
    if not file then
        Logger.Log("Failed to open for write: " .. tostring(path) .. " (" .. tostring(err) .. ")")
        return false, "Could not open file for writing: " .. path
    end

    file:write(content)
    file:close()

    return true
end

---Update a JSON file with new key-value pairs  
---Merges newData into existing JSON contents  
---@param path string Path to the JSON file  
---@param newData table New key-value pairs to merge  
---@return boolean ok True if saved successfully  
---@return string|nil err Error message if failed  
function JsonHelper.Update(path, newData)
    local existing, _, status = JsonHelper.ReadOptional(path)
    if status and status ~= "missing" then
        return false, "Could not safely update file: " .. path
    end
    if type(existing) ~= "table" then
        existing = {}
    end

    for k, v in pairs(newData) do
        existing[k] = v
    end

    return JsonHelper.Write(path, existing)
end

---Delete a key from a JSON file  
---@param path string Path to the JSON file  
---@param key string Key to remove  
---@return boolean ok True if saved successfully  
---@return string|nil err Error message if failed  
function JsonHelper.DeleteKey(path, key)
    local data, err = JsonHelper.Read(path)
    if not data then
        Logger.Log("DeleteKey failed (read error): " .. tostring(err))
        return false, err
    end

    data[key] = nil
    return JsonHelper.Write(path, data)
end

return JsonHelper
