local Inventory = require("Utils/Inventory")

local RecipeBook = {}

local function Call(callback)
    local ok, result = pcall(callback)
    if ok then return result end
    return nil
end

local function CraftBook()
    local container = Game.GetScriptableSystemsContainer()
    local system = container and container:Get("CraftingSystem")
    return system and Call(function() return system:GetPlayerCraftBook() end) or nil
end

local function Target(record)
    local data = TweakDB:GetRecord(record)
    if not data then return nil end
    return Call(function() return data:CraftingResult():Item():GetID() end)
end

local function Known(book, target)
    if not book then return false end
    return Call(function() return book:KnowsRecipe(target) end) == true
end

function RecipeBook.Unlock(ids, seen)
    seen = seen or {}
    local book = CraftBook()
    local unlocked, known, failed = 0, 0, 0

    for _, id in ipairs(ids) do
        local record = "Items." .. id
        if not seen[record] then
            seen[record] = true
            local target = Target(record)
            if not target then
                failed = failed + 1
            elseif Known(book, target) then
                known = known + 1
            elseif Inventory.Give(record, 1) then
                unlocked = unlocked + 1
            else
                failed = failed + 1
            end
        end
    end
    return unlocked, known, failed
end

return RecipeBook
