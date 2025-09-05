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

-- Improved helper function to create directory structure
local function ensureDirectoryExists()
    -- Split path and create nested folders
    local pathParts = {}
    for part in basePath:gmatch("[^/]+") do
        if part ~= "" then -- Skip empty parts
            table.insert(pathParts, part)
        end
    end
    
    if #pathParts == 0 then
        return -- No folders to create
    end
    
    local currentPath = ""
    for i, part in ipairs(pathParts) do
        if i == 1 then
            currentPath = part
        else
            currentPath = currentPath .. "/" .. part
        end
        
        -- Debug print to see what folders we're trying to create
        print("SaveLib: Checking folder: " .. currentPath)
        
        if not isfolder(currentPath) then
            print("SaveLib: Creating folder: " .. currentPath)
            local success, err = pcall(function()
                makefolder(currentPath)
            end)
            if not success then
                warn("SaveLib: Failed to create folder '" .. currentPath .. "' - " .. tostring(err))
                return false
            end
        else
            print("SaveLib: Folder already exists: " .. currentPath)
        end
    end
    return true
end

-- Initialize path on load
updateSavePath()

function SaveLib:Load()
    updateSavePath() -- Ensure path is current
    ensureDirectoryExists() -- Create folders if they don't exist
    
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
    
    if not ensureDirectoryExists() then
        error("SaveLib: Failed to create required directories")
    end
    
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
    print("SaveLib: New path set to: " .. basePath)
end

function SaveLib:SetNewGameName(name)
    assert(type(name) == "string", "Name must be a string")
    -- More comprehensive sanitization for filename
    gameName = name:gsub("[<>:\"/\\|?*%c]", ""):gsub("^%s*(.-)%s*$", "%1") -- Remove invalid chars and trim
    if gameName == "" then
        gameName = "default"
    end
    updateSavePath()
    print("SaveLib: New game name set to: " .. gameName)
end

function SaveLib:GetCurrentPath()
    updateSavePath()
    return savePath
end

function SaveLib:GetBasePath()
    return basePath
end

-- Method to manually create folders
function SaveLib:CreateFolders()
    return ensureDirectoryExists()
end

-- Init with auto-save via getgenv()
function SaveLib:Init()
    print("SaveLib: Initializing...")
    print("SaveLib: Base path: " .. basePath)
    print("SaveLib: Game name: " .. gameName)
    
    -- Ensure folders exist before doing anything else
    updateSavePath()
    print("SaveLib: Full save path: " .. savePath)
    
    local folderSuccess = ensureDirectoryExists()
    if not folderSuccess then
        warn("SaveLib: Failed to create directories during initialization")
    end
    
    -- Load data
    self:Load()
    local lib = self
    local env = getgenv()

    -- Store original metatable if it exists
    local originalMT = getmetatable(env)
    
    -- Remove existing metatable temporarily to avoid conflicts
    setmetatable(env, nil)
    
    -- Populate getgenv() with cached values first
    for k, v in pairs(cache) do
        env[k] = v
    end
    
    -- Set up new metatable
    setmetatable(env, {
        __newindex = function(t, k, v)
            -- Always use rawset to avoid recursive calls
            rawset(t, k, v)
            
            -- Update our cache
            cache[k] = v
            if autoSave then
                local success, err = pcall(function()
                    lib:Save(cache)
                end)
                if not success then
                    warn("SaveLib: Auto-save failed - " .. tostring(err))
                end
            end
        end,
        __index = function(t, k)
            -- First check if key exists in the table itself
            local rawValue = rawget(t, k)
            if rawValue ~= nil then
                return rawValue
            end
            
            -- Then check our cache
            if cache[k] ~= nil then
                return cache[k]
            end
            
            -- Return nil if not found anywhere
            return nil
        end
    })
    
    -- Test save to ensure everything is working
    pcall(function()
        lib:Save(cache)
    end)
    
    print("SaveLib: Initialized with path: " .. self:GetCurrentPath())
end

-- Simple init without metatable
function SaveLib:InitSimple()
    print("SaveLib: Simple initialization...")
    print("SaveLib: Base path: " .. basePath)
    print("SaveLib: Game name: " .. gameName)
    
    self:Load()
    
    -- Simply populate getgenv() with cached values
    for k, v in pairs(cache) do
        getgenv()[k] = v
    end
    
    print("SaveLib: Simple init completed with path: " .. self:GetCurrentPath())
    print("SaveLib: Use SaveLib:Set(key, value) to save data")
end

return SaveLib