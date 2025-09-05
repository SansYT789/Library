local HttpService = game:GetService("HttpService")
local SaveLib = {}
SaveLib.__index = SaveLib

-- Config
local basePath = "MangoHub/Script-Exploits/Game"
local gameName = tostring(game.PlaceId)
local savePath = ""
local autoSave = true
local cache = {}
local isInitialized = false
local foldersCreated = false

-- Helper function to ensure path ends without slash and create proper file path
local function updateSavePath()
    local cleanBasePath = basePath:gsub("/$", "")
    savePath = cleanBasePath .. "/" .. gameName .. ".json"
end

-- Improved helper function to create directory structure
local function ensureDirectoryExists()
    if foldersCreated then
        return true -- Already created, don't try again
    end
    
    local pathParts = {}
    for part in basePath:gmatch("[^/]+") do
        if part ~= "" then
            table.insert(pathParts, part)
        end
    end

    if #pathParts == 0 then
        foldersCreated = true
        return true
    end

    local currentPath = ""
    for i, part in ipairs(pathParts) do
        if i == 1 then
            currentPath = part
        else
            currentPath = currentPath .. "/" .. part
        end

        if not isfolder(currentPath) then
            local success, err = pcall(function()
                makefolder(currentPath)
            end)
            if not success then
                warn("SaveLib: Failed to create folder '" .. currentPath .. "' - " .. tostring(err))
                return false
            end
        end
    end
    
    foldersCreated = true
    return true
end

-- Initialize path on load
updateSavePath()

function SaveLib:Load()
    updateSavePath()
    
    -- Only create folders if not already created
    if not foldersCreated then
        ensureDirectoryExists()
    end

    if isfile(savePath) then
        local success, content = pcall(readfile, savePath)
        if not success then
            warn("SaveLib: Failed to read file - " .. tostring(content))
            cache = {}
            return cache
        end
        
        local decodeSuccess, data = pcall(function()
            return HttpService:JSONDecode(content)
        end)
        
        if decodeSuccess and type(data) == "table" then
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
    if type(data) ~= "table" then
        warn("SaveLib: Data must be a table, got " .. type(data))
        return false
    end

    updateSavePath()

    local success, json = pcall(function()
        return HttpService:JSONEncode(data)
    end)

    if not success then
        warn("SaveLib: Failed to encode data to JSON - " .. tostring(json))
        return false
    end

    if not ensureDirectoryExists() then
        warn("SaveLib: Failed to create required directories")
        return false
    end

    local writeSuccess, writeError = pcall(function()
        writefile(savePath, json)
    end)

    if not writeSuccess then
        warn("SaveLib: Failed to write file - " .. tostring(writeError))
        return false
    end

    cache = data
    return true
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
    if autoSave and isInitialized then
        local success = self:Save(cache)
        if not success then
            warn("SaveLib: Failed to auto-save data for key: " .. tostring(key))
        end
    end
end

function SaveLib:Reset()
    cache = {}
    if autoSave and isInitialized then
        local success = self:Save(cache)
        if not success then
            warn("SaveLib: Failed to save reset data")
        end
    end
end

function SaveLib:Append(key, value)
    if type(cache[key]) ~= "table" then
        cache[key] = {}
    end
    table.insert(cache[key], value)
    if autoSave and isInitialized then
        local success = self:Save(cache)
        if not success then
            warn("SaveLib: Failed to save appended data for key: " .. tostring(key))
        end
    end
end

function SaveLib:SetAutoSave(state)
    if type(state) ~= "boolean" then
        warn("SaveLib: SetAutoSave state must be true/false, got " .. type(state))
        return
    end
    autoSave = state
end

function SaveLib:SetNewPath(path)
    if type(path) ~= "string" then
        warn("SaveLib: Path must be a string, got " .. type(path))
        return
    end
    
    basePath = path:gsub("\\", "/"):gsub("/+$", ""):gsub("[<>:\"|?*]", "")
    foldersCreated = false -- Reset folder creation flag
    updateSavePath()
end

function SaveLib:SetNewGameName(name)
    if type(name) ~= "string" then
        warn("SaveLib: Name must be a string, got " .. type(name))
        return
    end
    
    gameName = name:gsub("[<>:\"/\\|?*%c]", ""):gsub("^%s*(.-)%s*$", "%1")
    if gameName == "" then
        gameName = "default"
    end
    updateSavePath()
end

function SaveLib:GetCurrentPath()
    updateSavePath()
    return savePath
end

function SaveLib:GetBasePath()
    return basePath
end

function SaveLib:CreateFolders()
    foldersCreated = false -- Force recreation
    return ensureDirectoryExists()
end

-- Safe initialization without metatable complications
function SaveLib:Init()
    if isInitialized then
        warn("SaveLib: Already initialized!")
        return
    end
    
    print("SaveLib: Initializing...")
    print("SaveLib: Base path: " .. basePath)
    print("SaveLib: Game name: " .. gameName)

    updateSavePath()
    print("SaveLib: Full save path: " .. savePath)

    -- Create folders and load data
    local folderSuccess = ensureDirectoryExists()
    if not folderSuccess then
        warn("SaveLib: Failed to create directories during initialization")
        return false
    end

    -- Load existing data
    self:Load()
    
    -- Populate getgenv() with cached values
    local env = getgenv()
    for k, v in pairs(cache) do
        env[k] = v
    end
    
    -- Mark as initialized
    isInitialized = true
    
    -- Test save to ensure everything works
    local testSaveSuccess = self:Save(cache)
    if not testSaveSuccess then
        warn("SaveLib: Test save failed during initialization")
        return false
    end
    
    print("SaveLib: Successfully initialized!")
    print("SaveLib: Loaded " .. tostring(table.getn and table.getn(cache) or 0) .. " cached values")
    return true
end

-- Alternative method for manual sync
function SaveLib:SyncToGlobal()
    if not isInitialized then
        warn("SaveLib: Must call Init() first")
        return
    end
    
    local env = getgenv()
    for k, v in pairs(cache) do
        env[k] = v
    end
end

-- Alternative method for manual sync from global
function SaveLib:SyncFromGlobal()
    if not isInitialized then
        warn("SaveLib: Must call Init() first")
        return
    end
    
    -- Note: This is dangerous as it will save ALL global variables
    -- Only use if you know what you're doing
    warn("SaveLib: SyncFromGlobal is dangerous - it will save all global variables!")
end

-- Status check
function SaveLib:GetStatus()
    return {
        initialized = isInitialized,
        foldersCreated = foldersCreated,
        autoSave = autoSave,
        basePath = basePath,
        gameName = gameName,
        savePath = savePath,
        cacheSize = 0
    }
end

return SaveLib