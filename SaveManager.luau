local HttpService = game:GetService("HttpService")
local SaveLib = {}
SaveLib.__index = SaveLib

-- Config
local basePath = "MangoHub/Script-Exploits/Game/"
local function getGameName()
    local success, name = pcall(function()
        return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
    end)
    return success and name or tostring(game.PlaceId)
end
local gameName = getGameName()
local savePath = basePath .. gameName .. ".json"
local autoSave = true

-- Update savePath helper
local function updateSavePath()
    savePath = basePath .. gameName .. ".json"
end

-- Load file
function SaveLib:Load()
    if isfile(savePath) then
        local content = readfile(savePath)
        local success, data = pcall(function()
            return HttpService:JSONDecode(content)
        end)
        if success then
            return data
        end
    end
    return {}
end

-- Save file
function SaveLib:Save(data)
    assert(type(data) == "table", "Data must be a table")
    local json = HttpService:JSONEncode(data)
    if not isfolder(basePath) then
        makefolder(basePath)
    end
    writefile(savePath, json)
end

-- Clear file
function SaveLib:Clear()
    if isfile(savePath) then
        delfile(savePath)
    end
end

-- Check file exists
function SaveLib:Exists()
    return isfile(savePath)
end

-- Get value by key
function SaveLib:Get(key, default)
    local data = self:Load()
    if data[key] ~= nil then
        return data[key]
    end
    return default
end

-- Set value by key
function SaveLib:Set(key, value)
    local data = self:Load()
    data[key] = value
    if autoSave then
        self:Save(data)
    end
end

-- Reset file to {}
function SaveLib:Reset()
    self:Save({})
end

-- Append value to list key
function SaveLib:Append(key, value)
    local data = self:Load()
    if type(data[key]) ~= "table" then
        data[key] = {}
    end
    table.insert(data[key], value)
    if autoSave then
        self:Save(data)
    end
end

-- Enable / Disable Auto Save
function SaveLib:AutoSaveMode(state)
    assert(type(state) == "boolean", "State must be true/false")
    autoSave = state
end

-- Change Path
function SaveLib:ChangeNewPath(path)
    assert(type(path) == "string", "Path must be a string")
    basePath = path
    updateSavePath()
end

-- Change Game Name
function SaveLib:ChangeNewGameName(name)
    assert(type(name) == "string", "Name must be a string")
    gameName = name
    updateSavePath()
end

return SaveLib