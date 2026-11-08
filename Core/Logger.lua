local Logger = {}

local PREFIX = "[EasyTrainer] "

function Logger.Log(message)
    local text = PREFIX .. tostring(message)
    spdlog.info(text)
    print(text)
end

function Logger.Error(message)
    local text = PREFIX .. "Error: " .. tostring(message)
    spdlog.error(text)
    print(text)
end

return Logger
