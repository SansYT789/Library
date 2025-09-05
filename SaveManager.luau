local HttpService = game:GetService("HttpService")
local SaveLib = {}
SaveLib.__index = SaveLib

-- Config
local basePath = "MangoHub/Script-Exploits/Game"
local gameName = tostring(game.PlaceId)
local savePath = ""
local autoSave = true
local cache = {}

-- Helper function to ensure path ends without slash and create proper file path
local function updateSavePath()
    -- Remove trailing slash if present
    local cleanBasePath = basePath:gsub("/$", "")
    savePath = cleanBasePath .. "/" .. gameName .. ".json"
end

-- Helper function to create directory structure
local function ensureDirectoryExists()
    -- Split path and create nested folders
    local pathParts = {}
    for part in basePath:gmatch("[^/]+") do
        table.insert(pathParts, part)
    end
    
    local currentPath = ""
    for i, part in ipairs(pathParts) do
        if i == 1 then
            currentPath = part
        else
            currentPath = currentPath .. "/" .. part
        end
        
        if not isfolder(currentPath) then
            makefolder(currentPath)
        end
    end
end

-- Initialize path on load
updateSavePath()

function SaveLib:Load()
    updateSavePath() -- Ensure path is current
    
    if isfile(savePath) then
        local content = readfile(savePath)
        local success, data = pcall(function()
            return HttpService:JSONDecode(content)
        end)
        if success and type(data) == "table" then
            cache = data
            return data
        else
            warn("SaveLib: Failed to decode JSON data, using empty cache")
        end
    end
    cache = {}
    return cache
end

function SaveLib:Save(data)
    assert(type(data) == "table", "Data must be a table")
    
    updateSavePath() -- Ensure path is current
    
    local success, json = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    
    if not success then
        error("SaveLib: Failed to encode data to JSON")
    end
    
    ensureDirectoryExists()
    
    local writeSuccess, writeError = pcall(function()
        writefile(savePath, json)
    end)
    
    if not writeSuccess then
        error("SaveLib: Failed to write file - " .. tostring(writeError))
    end
    
    cache = data -- Update cache after successful save
end

function SaveLib:Clear()
    updateSavePath()
    
    if isfile(savePath) then
        local success, error = pcall(function()
            delfile(savePath)
        end)
        if not success then
            warn("SaveLib: Failed to delete file - " .. tostring(error))
        end
    end
    cache = {}
end

function SaveLib:Exists()
    updateSavePath()
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
    if autoSave then
        self:Save(cache)
    end
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
    -- Clean the path - remove trailing slashes and invalid characters
    basePath = path:gsub("\\", "/"):gsub("/+$", ""):gsub("[<>:\"|?*]", "")
    updateSavePath()
end

function SaveLib:SetNewGameName(name)
    assert(type(name) == "string", "Name must be a string")
    -- More comprehensive sanitization for filename
    gameName = name:gsub("[<>:\"/\\|?*%c]", ""):gsub("^%s*(.-)%s*$", "%1") -- Remove invalid chars and trim
    if gameName == "" then
        gameName = "default"
    end
    updateSavePath()
end

function SaveLib:GetCurrentPath()
    updateSavePath()
    return savePath
end

-- Init with auto-save via getgenv()
function SaveLib:Init()
    self:Load()
    local lib = self

    -- Store original metatable if it exists
    local originalMT = getmetatable(getgenv())
    local originalNewIndex = originalMT and originalMT.__newindex
    local originalIndex = originalMT and originalMT.__index

    setmetatable(getgenv(), {
        __newindex = function(t, k, v)
            -- Call original newindex if it exists
            if originalNewIndex then
                originalNewIndex(t, k, v)
            else
                rawset(t, k, v)
            end
            
            -- Update our cache
            cache[k] = v
            if autoSave then
                local success, error = pcall(function()
                    lib:Save(cache)
                end)
                if not success then
                    warn("SaveLib: Auto-save failed - " .. tostring(error))
                end
            end
        end,
        __index = function(t, k)
            -- Check our cache first
            if cache[k] ~= nil then
                return cache[k]
            end
            
            -- Fall back to original index or rawget
            if originalIndex then
                return originalIndex(t, k)
            else
                return rawget(t, k)
            end
        end
    })

    -- Populate getgenv() with cached values
    for k, v in pairs(cache) do
        rawset(getgenv(), k, v)
    end
    
    print("SaveLib: Initialized with path: " .. self:GetCurrentPath())
end

return SaveLib