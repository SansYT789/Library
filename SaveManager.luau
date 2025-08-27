local HttpService = game:GetService("HttpService")
local SaveLib = {}

local function getGameName()
    local success, name = pcall(function()
        return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
    end)
    return success and name or tostring(game.PlaceId)
end

local basePath = "MangoHub/Script-Exploits/Game/"
local gameName = getGameName()
local savePath = basePath .. gameName .. ".json"

-- Load file
function SaveLib.Load()
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
function SaveLib.Save(data)
    assert(type(data) == "table", "Data must be a table")
    local json = HttpService:JSONEncode(data)
    if not isfolder(basePath) then
        makefolder(basePath)
    end
    writefile(savePath, json)
end

-- Clear file
function SaveLib.Clear()
    if isfile(savePath) then
        delfile(savePath)
    end
end

-- Check file exists
function SaveLib.Exists()
    return isfile(savePath)
end

-- Get value by key
function SaveLib.Get(key, default)
    local data = SaveLib.Load()
    if data[key] ~= nil then
        return data[key]
    end
    return default
end

-- Set value by key (auto save)
function SaveLib.Set(key, value)
    local data = SaveLib.Load()
    data[key] = value
    SaveLib.Save(data)
end

-- Reset file to {}
function SaveLib.Reset()
    SaveLib.Save({})
end

-- Append value to list key
function SaveLib.Append(key, value)
    local data = SaveLib.Load()
    if type(data[key]) ~= "table" then
        data[key] = {}
    end
    table.insert(data[key], value)
    SaveLib.Save(data)
end

return SaveLib
