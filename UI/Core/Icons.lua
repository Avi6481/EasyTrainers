local Logger = require("Core/Logger")

local Icons = {}

local MANIFESTS = { "Assets/Icons/WeaponIcons", "Assets/Icons/ItemIcons", "Assets/Icons/VehicleIcons" }

local s_Parts = nil
local s_Sheets = {}
local s_Textures = {}
local s_PartNames = {}
local s_Reported = {}

local function LoadManifests()
    s_Parts = {}
    for _, path in ipairs(MANIFESTS) do
        local ok, manifest = pcall(require, path)
        if ok and type(manifest) == "table" then
            local offset = #s_Sheets
            for _, sheet in ipairs(manifest.Sheets or {}) do table.insert(s_Sheets, sheet) end
            for name, part in pairs(manifest.Parts or {}) do
                s_Parts[name] = { Sheet = part[1] + offset, U0 = part[2], V0 = part[3], U1 = part[4], V1 = part[5], Width = part[6], Height = part[7] }
            end
        else
            Logger.Log("Icons: could not load manifest " .. path)
        end
    end
end

local function ReportOnce(key, message)
    if s_Reported[key] then return end
    s_Reported[key] = true
    Logger.Log(message)
end

local function ToName(value)
    if type(value) == "string" then return value end
    if value and value.value then return value.value end
    return ""
end

local function ItemPartName(record, tweakID)
    local iconName = record:IconPath() or ""
    if iconName == "" then
        local resolver = IconsNameResolver.GetIconsNameResolver()
        if resolver then iconName = ToName(resolver:TranslateItemToIconName(tweakID, false)) end
    end
    if iconName == "" then return "" end

    local partName = ToName(TweakDB:GetFlat("UIIcon." .. iconName .. ".atlasPartName"))
    return partName ~= "" and partName or iconName
end

local function IconRecordPartName(record)
    local icon = record:Icon()
    return icon and ToName(icon:AtlasPartName()) or ""
end

local RESOLVERS = { ItemPartName, IconRecordPartName }

local function ResolvePartName(recordID)
    local record = TweakDB:GetRecord(recordID)
    if not record then return "" end

    local tweakID = TweakDBID.new(recordID)
    local tried = ""
    for _, resolve in ipairs(RESOLVERS) do
        local ok, partName = pcall(resolve, record, tweakID)
        if ok and partName and partName ~= "" then
            if s_Parts[partName] then return partName end
            if tried == "" then tried = partName end
        end
    end
    return tried
end

local function GetPart(recordID, quiet)
    if not s_Parts then LoadManifests() end

    local partName = s_PartNames[recordID]
    if partName == nil then
        local ok, result = pcall(ResolvePartName, recordID)
        partName = ok and result or ""
        s_PartNames[recordID] = partName
    end

    local part = s_Parts[partName]
    if not part and not quiet then ReportOnce(recordID, "Icons: no icon for " .. recordID .. " (part '" .. partName .. "')") end
    return part
end

local function GetTexture(sheet)
    local texture = s_Textures[sheet]
    if texture ~= nil then return texture or nil end
    if not ImGui.LoadTexture then
        ReportOnce("LoadTexture", "Icons: this CET build has no ImGui.LoadTexture")
        s_Textures[sheet] = false
        return nil
    end

    local loaded, err = ImGui.LoadTexture(s_Sheets[sheet])
    s_Textures[sheet] = loaded or false
    if not loaded then Logger.Log("Icons: " .. tostring(err or ("failed to load " .. tostring(s_Sheets[sheet])))) end
    return loaded
end

function Icons.GetSize(recordID, maxWidth, maxHeight)
    local part = GetPart(recordID)
    if not part then return nil end
    local scale = math.min(maxWidth / part.Width, (maxHeight or math.huge) / part.Height)
    return part.Width * scale, part.Height * scale
end

function Icons.Has(recordID)
    return GetPart(recordID, true) ~= nil
end

function Icons.Draw(recordID, maxWidth, maxHeight)
    local part = GetPart(recordID)
    if not part then return false end
    local texture = GetTexture(part.Sheet)
    if not texture then return false end

    local width, height = Icons.GetSize(recordID, maxWidth, maxHeight)
    ImGui.Image(texture, ImVec2.new(width, height), ImVec2.new(part.U0, part.V0), ImVec2.new(part.U1, part.V1))
    return true
end

return Icons
