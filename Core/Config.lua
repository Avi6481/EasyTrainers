local JsonHelper = require("Core/JsonHelper")
local Logger = require("Core/Logger")
local Notify = require("Utils/Notify")

local Config = {}
Config.__index = Config

local CHECK_INTERVAL = 0.5
local SAVE_DELAY = 1

local function Copy(value)
    if type(value) ~= "table" then return value end

    local copy = {}
    for key, item in pairs(value) do copy[key] = Copy(item) end
    return copy
end

local function Serialize(value)
    if type(value) ~= "table" then return tostring(value) end

    local parts = {}
    for key, item in pairs(value) do
        table.insert(parts, tostring(key) .. "=" .. Serialize(item))
    end
    table.sort(parts)
    return "{" .. table.concat(parts, ",") .. "}"
end

local function Snapshot(binding)
    local parts = {}
    for _, key in ipairs(binding.Keys) do
        table.insert(parts, Serialize(binding.Target[key]))
    end
    return table.concat(parts, ";")
end

local function Restore(binding, values)
    if type(values) ~= "table" then return end

    for _, key in ipairs(binding.Keys) do
        local value = values[key]
        if value ~= nil and type(value) == type(binding.Defaults[key]) then
            binding.Target[key] = Copy(value)
        end
    end
end

function Config.New(path)
    return setmetatable({
        Path = path,
        Saved = {},
        Bindings = {},
        Dirty = false,
        ChangedAt = 0,
        NextCheck = 0,
        Locked = false,
        Warned = false
    }, Config)
end

function Config:Load()
    local data = JsonHelper.LoadOrCreate(self.Path, {})
    self.Saved = type(data) == "table" and data or {}
    self.Locked = type(data) ~= "table"
    if self.Locked then Logger.Error("Couldn't read " .. self.Path .. ", so changes this session won't be saved") end
end

function Config:Bind(section, target, keys)
    local binding = { Section = section, Target = target, Keys = keys, Defaults = {} }
    for _, key in ipairs(keys) do binding.Defaults[key] = Copy(target[key]) end

    Restore(binding, self.Saved[section])
    binding.Snapshot = Snapshot(binding)
    table.insert(self.Bindings, binding)
end

function Config:Warn()
    if self.Warned then return end
    self.Warned = true
    Notify.Warning(tip("settings.savefailed", { file = self.Path }), 8)
end

function Config:Save()
    self.Dirty = false
    if self.Locked then return self:Warn() end

    local data = {}
    for section, values in pairs(self.Saved) do data[section] = values end
    for _, binding in ipairs(self.Bindings) do
        local values = {}
        for _, key in ipairs(binding.Keys) do values[key] = Copy(binding.Target[key]) end
        data[binding.Section] = values
    end

    if JsonHelper.Write(self.Path, data) then return end
    Logger.Error("Couldn't save " .. self.Path)
    self:Warn()
end

function Config:Update()
    local now = os.clock()

    if now >= self.NextCheck then
        self.NextCheck = now + CHECK_INTERVAL

        for _, binding in ipairs(self.Bindings) do
            local snapshot = Snapshot(binding)
            if snapshot ~= binding.Snapshot then
                binding.Snapshot = snapshot
                self.Dirty = true
                self.ChangedAt = now
            end
        end
    end

    if self.Dirty and now - self.ChangedAt >= SAVE_DELAY then self:Save() end
end

function Config:Reset(keep)
    for _, binding in ipairs(self.Bindings) do
        if not (keep and keep[binding.Section]) then
            for _, key in ipairs(binding.Keys) do binding.Target[key] = Copy(binding.Defaults[key]) end
        end
    end
end

function Config:Flush()
    for _, binding in ipairs(self.Bindings) do
        if Snapshot(binding) ~= binding.Snapshot then self.Dirty = true end
    end
    if self.Dirty then self:Save() end
end

return Config
