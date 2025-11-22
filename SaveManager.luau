--[[
    SaveManager v2.0 - Enhanced Configuration System
    Optimized for performance, reliability, and developer control
]]

local SaveManager = {}
SaveManager.__index = SaveManager

-- ========================================
-- Configuration
-- ========================================
local CONFIG = {
    -- File settings
    folderPath = "VinreachHub",
    filePrefix = "BloxFruits_",
    fileExtension = ".json",
    
    -- Save behavior
    autoSave = true,                    -- Enable/disable auto-save
    autoSaveInterval = 30,              -- Seconds between auto-saves
    saveOnChange = false,               -- Save immediately when value changes (not recommended for performance)
    
    -- Performance
    maxFileSize = 10485760,             -- 10MB limit
    chunkSize = 524288,                 -- 512KB chunks for large files
    debounceDelay = 0.5,                -- Debounce rapid changes (seconds)
    
    -- Validation
    validateOnLoad = true,              -- Validate file integrity on load
    strictMode = true,                  -- Remove unknown keys from config
    minKeyMatchRatio = 0.5,             -- Minimum 50% of default keys must match
    
    -- Backup
    maxBackups = 3,                     -- Keep last N backups
    backupOnCorruption = true,          -- Backup corrupted files
    
    -- Debug
    debugMode = false,                  -- Enable debug prints
    logErrors = true,                   -- Log errors to console
    performanceTracking = false,        -- Track operation times
    
    -- Version
    version = "2.0"
}

-- ========================================
-- Services
-- ========================================
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- ========================================
-- Utilities
-- ========================================
local Utils = {}

-- Check if executor supports file operations
function Utils.checkSupport()
    return pcall(function()
        assert(readfile, "readfile not supported")
        assert(writefile, "writefile not supported")
        assert(isfile, "isfile not supported")
        assert(isfolder, "isfolder not supported")
        assert(makefolder, "makefolder not supported")
        assert(delfile, "delfile not supported")
    end)
end

-- Deep copy table
function Utils.deepCopy(original)
    local copy
    if type(original) == 'table' then
        copy = {}
        for k, v in pairs(original) do
            copy[Utils.deepCopy(k)] = Utils.deepCopy(v)
        end
    else
        copy = original
    end
    return copy
end

-- Deep compare tables
function Utils.deepEqual(t1, t2)
    if t1 == t2 then return true end
    if type(t1) ~= "table" or type(t2) ~= "table" then return false end
    
    for k, v in pairs(t1) do
        if not Utils.deepEqual(v, t2[k]) then return false end
    end
    
    for k in pairs(t2) do
        if t1[k] == nil then return false end
    end
    
    return true
end

-- Count table keys
function Utils.countKeys(tbl)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

-- Convert boolean map to array (for UI compatibility)
function Utils.boolMapToArray(map)
    if type(map) ~= "table" then return map end
    
    -- Check if it's a boolean map
    local isBoolMap = true
    for _, v in pairs(map) do
        if type(v) ~= "boolean" then
            isBoolMap = false
            break
        end
    end
    
    if not isBoolMap then return map end
    
    -- Convert to array of keys where value is true
    local array = {}
    for k, v in pairs(map) do
        if v == true then
            table.insert(array, k)
        end
    end
    
    return array
end

-- Convert array back to boolean map
function Utils.arrayToBoolMap(array)
    if type(array) ~= "table" then return array end
    
    -- Check if it's an array (sequential numeric keys)
    local isArray = #array > 0
    if not isArray then return array end
    
    -- Convert to boolean map
    local map = {}
    for _, v in ipairs(array) do
        map[v] = true
    end
    
    return map
end

-- Safe JSON encode with error handling
function Utils.jsonEncode(data)
    local success, result = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    
    if success then
        return result, nil
    else
        return nil, "JSON encode failed: " .. tostring(result)
    end
end

-- Safe JSON decode with error handling
function Utils.jsonDecode(str)
    local success, result = pcall(function()
        return HttpService:JSONDecode(str)
    end)
    
    if success then
        return result, nil
    else
        return nil, "JSON decode failed: " .. tostring(result)
    end
end

-- Performance timer
local Timer = {}
function Timer.start()
    return tick()
end

function Timer.stop(startTime, operation)
    local elapsed = tick() - startTime
    if CONFIG.performanceTracking then
        print(string.format("⏱️ %s took %.3fms", operation, elapsed * 1000))
    end
    return elapsed
end

-- ========================================
-- Logger
-- ========================================
local Logger = {}

function Logger.debug(...)
    if CONFIG.debugMode then
        print("[SaveManager]", ...)
    end
end

function Logger.info(...)
    print("[SaveManager]", ...)
end

function Logger.warn(...)
    if CONFIG.logErrors then
        warn("[SaveManager]", ...)
    end
end

function Logger.error(...)
    if CONFIG.logErrors then
        warn("[SaveManager] ERROR:", ...)
    end
end

-- ========================================
-- File Operations
-- ========================================
local FileOps = {}

-- Ensure folder exists
function FileOps.ensureFolder(path)
    if not isfolder(path) then
        local success, err = pcall(makefolder, path)
        if not success then
            Logger.error("Failed to create folder:", err)
            return false
        end
    end
    return true
end

-- Atomic write with verification
function FileOps.writeAtomic(path, content)
    local tempPath = path .. ".tmp"
    local contentLen = #content
    
    -- Write to temp file
    local success = pcall(writefile, tempPath, content)
    if not success then
        Logger.error("Failed to write temp file")
        return false
    end
    
    -- Verify temp file
    if not isfile(tempPath) then
        Logger.error("Temp file not found after write")
        return false
    end
    
    local verify = readfile(tempPath)
    if #verify ~= contentLen then
        Logger.error("Temp file size mismatch:", #verify, "vs", contentLen)
        pcall(delfile, tempPath)
        return false
    end
    
    -- Atomic replace: delete old, rename temp
    if isfile(path) then
        pcall(delfile, path)
    end
    
    success = pcall(writefile, path, content)
    pcall(delfile, tempPath)
    
    if not success then
        Logger.error("Failed to write final file")
        return false
    end
    
    -- Final verification
    if not isfile(path) then
        Logger.error("Final file not found")
        return false
    end
    
    local finalVerify = readfile(path)
    if #finalVerify ~= contentLen then
        Logger.error("Final file size mismatch")
        return false
    end
    
    return true
end

-- Chunked read for large files
function FileOps.readSafe(path)
    if not isfile(path) then
        return nil, "File not found"
    end
    
    local success, content = pcall(readfile, path)
    if not success then
        return nil, "Failed to read file: " .. tostring(content)
    end
    
    return content, nil
end

-- List backup files
function FileOps.listBackups(basePath)
    local backups = {}
    
    for i = 1, CONFIG.maxBackups do
        local backupPath = basePath .. ".bak" .. i
        if isfile(backupPath) then
            table.insert(backups, {
                path = backupPath,
                index = i,
                size = #readfile(backupPath)
            })
        end
    end
    
    return backups
end

-- Rotate backups
function FileOps.rotateBackups(basePath, newContent)
    -- Delete oldest backup
    local oldestBackup = basePath .. ".bak" .. CONFIG.maxBackups
    if isfile(oldestBackup) then
        pcall(delfile, oldestBackup)
    end
    
    -- Shift backups
    for i = CONFIG.maxBackups - 1, 1, -1 do
        local currentBackup = basePath .. ".bak" .. i
        local nextBackup = basePath .. ".bak" .. (i + 1)
        
        if isfile(currentBackup) then
            local content = readfile(currentBackup)
            pcall(writefile, nextBackup, content)
        end
    end
    
    -- Save current as backup 1
    if newContent then
        pcall(writefile, basePath .. ".bak1", newContent)
    end
end

-- ========================================
-- Validator
-- ========================================
local Validator = {}

-- Validate JSON structure
function Validator.validateJSON(content)
    if not content or #content < 2 then
        return false, "Empty or too small"
    end
    
    -- Trim whitespace
    local trimmed = content:match("^%s*(.-)%s*$")
    
    -- Check basic structure
    if not (trimmed:sub(1,1) == "{" and trimmed:sub(-1) == "}") then
        return false, "Not properly enclosed"
    end
    
    -- Count braces
    local openCount, closeCount = 0, 0
    for i = 1, #trimmed do
        local char = trimmed:sub(i, i)
        if char == "{" then openCount = openCount + 1
        elseif char == "}" then closeCount = closeCount + 1
        end
    end
    
    if openCount ~= closeCount then
        return false, string.format("Unbalanced braces: %d open, %d close", openCount, closeCount)
    end
    
    -- Try to decode
    local decoded, err = Utils.jsonDecode(trimmed)
    if not decoded then
        return false, err
    end
    
    if type(decoded) ~= "table" then
        return false, "Not a table"
    end
    
    return true, decoded
end

-- Validate against defaults (schema validation)
function Validator.validateAgainstDefaults(data, defaults)
    if type(data) ~= "table" or type(defaults) ~= "table" then
        return false, "Invalid data types"
    end
    
    -- Count matching keys
    local matchCount = 0
    local totalDefaults = Utils.countKeys(defaults)
    
    for key in pairs(defaults) do
        if data[key] ~= nil then
            matchCount = matchCount + 1
        end
    end
    
    -- Check match ratio
    local ratio = matchCount / totalDefaults
    if ratio < CONFIG.minKeyMatchRatio then
        return false, string.format("Too few matching keys: %d/%d (%.1f%%)", 
            matchCount, totalDefaults, ratio * 100)
    end
    
    return true, nil
end

-- Check file size
function Validator.validateSize(content)
    if #content > CONFIG.maxFileSize then
        return false, string.format("File too large: %d bytes (max %d)", 
            #content, CONFIG.maxFileSize)
    end
    return true, nil
end

-- ========================================
-- SaveManager Class
-- ========================================

function SaveManager.new(player, defaults)
    local self = setmetatable({}, SaveManager)
    
    -- Validation
    if not player or not player:IsA("Player") then
        Logger.error("Invalid player object")
        return nil
    end
    
    if not defaults or type(defaults) ~= "table" then
        Logger.error("Invalid defaults table")
        return nil
    end
    
    -- Check executor support
    local supported, err = Utils.checkSupport()
    if not supported then
        Logger.error("Executor not supported:", err)
        return nil
    end
    
    -- Initialize properties
    self.player = player
    self.defaults = Utils.deepCopy(defaults)
    self.settings = Utils.deepCopy(defaults)
    
    -- State
    self.initialized = false
    self.isDirty = false
    self.isSaving = false
    self.lastSaveTime = 0
    self.lastChangeTime = 0
    
    -- Paths
    self.folderPath = CONFIG.folderPath
    self.fileName = CONFIG.filePrefix .. player.Name .. CONFIG.fileExtension
    self.filePath = self.folderPath .. "/" .. self.fileName
    
    -- Auto-save
    self.autoSaveThread = nil
    self.debounceThread = nil
    
    -- Ensure folder
    if not FileOps.ensureFolder(self.folderPath) then
        Logger.error("Failed to create save folder")
        return nil
    end
    
    -- Load settings
    self:load()
    
    -- Start auto-save if enabled
    if CONFIG.autoSave then
        self:startAutoSave()
    end
    
    -- Cleanup on player leave
    Players.PlayerRemoving:Connect(function(p)
        if p == self.player then
            self:shutdown()
        end
    end)
    
    Logger.info("Initialized for player:", player.Name)
    return self
end

-- ========================================
-- Core Methods
-- ========================================

-- Load settings from file
function SaveManager:load()
    local startTime = Timer.start()
    
    -- Check if file exists
    if not isfile(self.filePath) then
        Logger.debug("No save file found, creating new")
        self:save(true) -- Force save defaults
        self.initialized = true
        Timer.stop(startTime, "Initial save")
        return true
    end
    
    -- Read file
    local content, err = FileOps.readSafe(self.filePath)
    if not content then
        Logger.error("Failed to read file:", err)
        self:restoreFromBackup()
        return false
    end
    
    -- Validate JSON
    local isValid, decoded = Validator.validateJSON(content)
    if not isValid then
        Logger.warn("Corrupted file:", decoded)
        if CONFIG.backupOnCorruption then
            self:backupCorrupted(content)
        end
        self:restoreFromBackup()
        return false
    end
    
    -- Validate against defaults
    if CONFIG.validateOnLoad then
        local valid, err = Validator.validateAgainstDefaults(decoded, self.defaults)
        if not valid then
            Logger.warn("Schema validation failed:", err)
        end
    end
    
    -- Merge with defaults (add missing keys, optionally remove unknown)
    local merged = self:mergeWithDefaults(decoded)
    
    -- Check if merge changed anything
    local needsSave = not Utils.deepEqual(decoded, merged)
    
    -- Apply settings
    self.settings = merged
    self.initialized = true
    
    -- Save if needed
    if needsSave then
        Logger.debug("Settings merged with defaults, saving")
        self:save(true)
    end
    
    Timer.stop(startTime, "Load")
    Logger.info("Loaded successfully")
    return true
end

-- Save settings to file
function SaveManager:save(force)
    if not self.initialized then
        Logger.warn("Cannot save: not initialized")
        return false
    end
    
    if self.isSaving then
        Logger.debug("Save already in progress")
        return false
    end
    
    if not force and not self.isDirty then
        Logger.debug("No changes to save")
        return false
    end
    
    local startTime = Timer.start()
    self.isSaving = true
    
    -- Add metadata
    local dataToSave = Utils.deepCopy(self.settings)
    dataToSave["_version"] = CONFIG.version
    dataToSave["_lastSaved"] = os.time()
    dataToSave["_player"] = self.player.Name
    
    -- Encode
    local encoded, err = Utils.jsonEncode(dataToSave)
    if not encoded then
        Logger.error("Encode failed:", err)
        self.isSaving = false
        return false
    end
    
    -- Validate size
    local sizeValid, sizeErr = Validator.validateSize(encoded)
    if not sizeValid then
        Logger.error(sizeErr)
        self.isSaving = false
        return false
    end
    
    -- Rotate backups before saving
    if isfile(self.filePath) then
        local currentContent = readfile(self.filePath)
        FileOps.rotateBackups(self.filePath, currentContent)
    end
    
    -- Write atomically
    local success = FileOps.writeAtomic(self.filePath, encoded)
    
    if success then
        self.isDirty = false
        self.lastSaveTime = os.time()
        Logger.debug("Saved successfully:", #encoded, "bytes")
    else
        Logger.error("Write failed")
    end
    
    self.isSaving = false
    Timer.stop(startTime, "Save")
    return success
end

-- Merge loaded data with defaults
function SaveManager:mergeWithDefaults(loaded)
    local merged = Utils.deepCopy(self.defaults)
    
    -- Apply loaded values
    for key, value in pairs(loaded) do
        -- Skip metadata
        if key:sub(1, 1) ~= "_" then
            -- In strict mode, only keep keys that exist in defaults
            if CONFIG.strictMode then
                if merged[key] ~= nil then
                    merged[key] = value
                else
                    Logger.debug("Removing unknown key:", key)
                end
            else
                merged[key] = value
            end
        end
    end
    
    -- Add missing keys from defaults
    for key, value in pairs(self.defaults) do
        if loaded[key] == nil then
            Logger.debug("Adding missing key:", key)
            merged[key] = value
        end
    end
    
    return merged
end

-- Restore from backup
function SaveManager:restoreFromBackup()
    Logger.info("Attempting to restore from backup")
    
    local backups = FileOps.listBackups(self.filePath)
    
    -- Try each backup in order
    for _, backup in ipairs(backups) do
        Logger.debug("Trying backup:", backup.index)
        
        local content, err = FileOps.readSafe(backup.path)
        if content then
            local isValid, decoded = Validator.validateJSON(content)
            if isValid then
                Logger.info("Restored from backup", backup.index)
                
                local merged = self:mergeWithDefaults(decoded)
                self.settings = merged
                self.initialized = true
                self.isDirty = true
                
                -- Save restored data
                self:save(true)
                return true
            end
        end
    end
    
    -- No valid backup found, use defaults
    Logger.warn("No valid backup found, using defaults")
    self.settings = Utils.deepCopy(self.defaults)
    self.initialized = true
    self:save(true)
    return false
end

-- Backup corrupted file
function SaveManager:backupCorrupted(content)
    local corruptedPath = string.format("%s.corrupted.%d", self.filePath, os.time())
    pcall(writefile, corruptedPath, content)
    Logger.debug("Backed up corrupted file:", corruptedPath)
end

-- ========================================
-- Public API
-- ========================================

-- Get setting value
function SaveManager:get(key)
    if not key then return nil end
    
    local value = self.settings[key]
    
    -- Convert boolean maps to arrays for UI compatibility
    if type(value) == "table" then
        return Utils.boolMapToArray(value)
    end
    
    return value
end

-- Set setting value
function SaveManager:set(key, value, skipSave)
    if not key or not self.initialized then return false end
    
    -- Convert arrays back to boolean maps for storage
    if type(value) == "table" then
        value = Utils.arrayToBoolMap(value)
    end
    
    -- Check if value actually changed
    if Utils.deepEqual(self.settings[key], value) then
        return true -- No change needed
    end
    
    self.settings[key] = value
    self.isDirty = true
    self.lastChangeTime = tick()
    
    Logger.debug("Set:", key, "=", value)
    
    -- Handle save behavior
    if not skipSave then
        if CONFIG.saveOnChange then
            self:save()
        elseif CONFIG.autoSave and CONFIG.debounceDelay > 0 then
            self:debounceSave()
        end
    end
    
    return true
end

-- Batch set multiple values
function SaveManager:setBatch(values)
    if type(values) ~= "table" then return false end
    
    for key, value in pairs(values) do
        self:set(key, value, true) -- Skip individual saves
    end
    
    if CONFIG.saveOnChange then
        self:save()
    end
    
    return true
end

-- Reset to defaults
function SaveManager:reset()
    Logger.info("Resetting to defaults")
    
    -- Backup current settings
    if isfile(self.filePath) then
        local backupPath = string.format("%s.reset.%d.bak", self.filePath, os.time())
        local content = readfile(self.filePath)
        pcall(writefile, backupPath, content)
    end
    
    -- Reset to defaults
    self.settings = Utils.deepCopy(self.defaults)
    self.isDirty = true
    
    return self:save(true)
end

-- Force save
function SaveManager:forceSave()
    return self:save(true)
end

-- ========================================
-- Auto-Save
-- ========================================

-- Debounced save (waits for changes to stop)
function SaveManager:debounceSave()
    if self.debounceThread then
        task.cancel(self.debounceThread)
    end
    
    self.debounceThread = task.delay(CONFIG.debounceDelay, function()
        if self.isDirty then
            self:save()
        end
    end)
end

-- Start auto-save loop
function SaveManager:startAutoSave()
    if self.autoSaveThread then return end
    
    Logger.debug("Starting auto-save")
    
    self.autoSaveThread = task.spawn(function()
        while self.autoSaveThread do
            task.wait(CONFIG.autoSaveInterval)
            
            if self.isDirty and not self.isSaving then
                self:save()
            end
        end
    end)
end

-- Stop auto-save loop
function SaveManager:stopAutoSave()
    if self.autoSaveThread then
        task.cancel(self.autoSaveThread)
        self.autoSaveThread = nil
        Logger.debug("Stopped auto-save")
    end
end

-- ========================================
-- Lifecycle
-- ========================================

-- Shutdown and cleanup
function SaveManager:shutdown()
    Logger.info("Shutting down")
    
    -- Stop auto-save
    self:stopAutoSave()
    
    -- Cancel debounce
    if self.debounceThread then
        task.cancel(self.debounceThread)
    end
    
    -- Final save
    if self.isDirty then
        self:save(true)
    end
    
    self.initialized = false
end

-- ========================================
-- Developer API
-- ========================================

-- Get all settings (raw)
function SaveManager:getAll()
    return Utils.deepCopy(self.settings)
end

-- Get statistics
function SaveManager:getStats()
    return {
        initialized = self.initialized,
        isDirty = self.isDirty,
        isSaving = self.isSaving,
        lastSaveTime = self.lastSaveTime,
        lastChangeTime = self.lastChangeTime,
        fileSize = isfile(self.filePath) and #readfile(self.filePath) or 0,
        backupCount = #FileOps.listBackups(self.filePath),
        settingCount = Utils.countKeys(self.settings)
    }
end

-- Export settings as JSON string
function SaveManager:export()
    local encoded, err = Utils.jsonEncode(self.settings)
    return encoded, err
end

-- Import settings from JSON string
function SaveManager:import(jsonString)
    local decoded, err = Utils.jsonDecode(jsonString)
    if not decoded then
        return false, err
    end
    
    local merged = self:mergeWithDefaults(decoded)
    self.settings = merged
    self.isDirty = true
    
    return self:save(true)
end

-- Delete save file
function SaveManager:deleteSave()
    Logger.warn("Deleting save file")
    
    if isfile(self.filePath) then
        pcall(delfile, self.filePath)
    end
    
    -- Delete backups
    local backups = FileOps.listBackups(self.filePath)
    for _, backup in ipairs(backups) do
        pcall(delfile, backup.path)
    end
    
    return true
end

-- ========================================
-- Configuration API
-- ========================================

-- Update configuration
function SaveManager.setConfig(key, value)
    if CONFIG[key] ~= nil then
        CONFIG[key] = value
        Logger.debug("Config updated:", key, "=", value)
        return true
    end
    return false
end

-- Get configuration
function SaveManager.getConfig(key)
    return CONFIG[key]
end

-- Get all configuration
function SaveManager.getAllConfig()
    return Utils.deepCopy(CONFIG)
end

-- ========================================
-- Return Module
-- ========================================

return SaveManager