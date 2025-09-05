local HttpService = game:GetService("HttpService")
local SaveLib = {}
SaveLib.__index = SaveLib

-- Config
local basePath = "MangoHub/Script-Exploits/Game/"
local gameName = tostring(game.PlaceId)
local savePath = basePath .. gameName .. ".json"
local autoSave = true
local cache = {}

local function updateSavePath()
    savePath = basePath .. gameName .. ".json"
end

function SaveLib:Load()
    if isfile(savePath) then
        local content = readfile(savePath)
        local success, data = pcall(function()
            return HttpService:JSONDecode(content)
        end)
        if success and type(data) == "table" then
            cache = data
            return data
        end
    end
    cache = {}
    return cache
end

function SaveLib:Save(data)
    assert(type(data) == "table", "Data must be a table")
    local json = HttpService:JSONEncode(data)
    if not isfolder(basePath) then
        makefolder(basePath)
    end
    writefile(savePath, json)
end

function SaveLib:Clear()
    if isfile(savePath) then
        delfile(savePath)
    end
    cache = {}
end

function SaveLib:Exists()
    return isfile(savePath)
end

function SaveLib:Get(key, default)
    return cache[key] ~= nil and cache[key] or default
end

function SaveLib:Set(key, value)
    cache[key] = value
    if autoSave then
        self:Save(cache)
    end
end

function SaveLib:Reset()
    cache = {}
    self:Save(cache)
end

function SaveLib:Append(key, value)
    if type(cache[key]) ~= "table" then
        cache[key] = {}
    end
    table.insert(cache[key], value)
    if autoSave then
        self:Save(cache)
    end
end

function SaveLib:SetAutoSave(state)
    assert(type(state) == "boolean", "State must be true/false")
    autoSave = state
end

function SaveLib:SetNewPath(path)
    assert(type(path) == "string", "Path must be a string")
    basePath = path
    updateSavePath()
end

function SaveLib:SetNewGameName(name)
    assert(type(name) == "string", "Name must be a string")
    gameName = name:gsub("[%c%p%s]", "") -- sanitize
    updateSavePath()
end

-- Init với auto-save qua getgenv()
function SaveLib:Init()
    self:Load()
    local lib = self

    setmetatable(getgenv(), {
        __newindex = function(t, k, v)
            rawset(t, k, v)
            cache[k] = v
            if autoSave then
                lib:Save(cache)
            end
        end,
        __index = function(t, k)
            if cache[k] ~= nil then
                return cache[k]
            end
            return rawget(t, k)
        end
    })

    for k, v in pairs(cache) do
        rawset(getgenv(), k, v)
    end
end

return SaveLib