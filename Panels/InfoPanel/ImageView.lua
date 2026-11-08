local Draw = require("Core/Draw")
local Logger = require("Core/Logger")

local ImageView = {}

local s_Textures = {}

local function Texture(path)
    local texture = s_Textures[path]
    if texture ~= nil then return texture or nil end

    local loaded, err = ImGui.LoadTexture(path)
    s_Textures[path] = loaded or false
    if not loaded then Logger.Log("Image: " .. tostring(err or ("couldn't load " .. path))) end
    return loaded
end

function ImageView.Draw(x, y, width, height, image)
    local texture = Texture(image.Sheet)
    if not texture then return end

    ImGui.SetCursorScreenPos(x, y)
    ImGui.PushStyleVar(ImGuiStyleVar.Alpha, Draw.GetAlpha())
    ImGui.Image(texture, ImVec2.new(width, height), ImVec2.new(image.U0, image.V0), ImVec2.new(image.U1, image.V1))
    ImGui.PopStyleVar(1)
end

return ImageView
