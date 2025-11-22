--[[
    SaveManager v2.5 - Production Grade Configuration System
    Features: Smart recovery, atomic saves, zero data loss
]]

local SaveManager = {}
SaveManager.__index = SaveManager

-- ========================================
-- CONFIGURATION
-- ========================================
local CONFIG = {
    -- File System
    folderPath = "VinreachHub",
    filePrefix = "BloxFruits_",
    fileExtension = ".json",
    tempExtension = ".tmp",
    backupExtension = ".bak",
    
    -- Save Behavior
    autoSave = true,
    autoSaveInterval = 30,
    saveOnChange = false,
    debounceDelay = 1.5,
    
    -- Performance
    maxFileSize = 10485760, -- 10MB
    writeRetries = 3,
    retryDelay = 0.5,
    
    -- Recovery
    autoRecovery = true,
    deleteCorrupted = true,
    maxSingleBackup = 1, -- Only keep 1 backup to avoid clutter
    verifyWrites = true,
    
    -- Validation
    strictMode = true,
    minKeysRequired = 10, -- Minimum keys to consider file valid
    
    -- Debug
    debugMode = false,
    logLevel = "info", -- "debug", "info", "warn", "error"
    
    version = "2.5"
}

-- ========================================
-- SERVICES
-- ========================================
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

-- ========================================
-- LOGGER
-- ========================================
local Logger = {}
local LogLevels = {debug = 1, info = 2, warn = 3, error = 4}

function Logger.log(level, ...)
    if LogLevels[level] >= LogLevels[CONFIG.logLevel] then
        local prefix = "[SaveManager." .. level:upper() .. "]"
        if level == "error" or level == "warn" then
            warn(prefix, ...)
        else
            print(prefix, ...)
        end
    end
end

function Logger.debug(...) Logger.log("debug", ...) end
function Logger.info(...) Logger.log("info", ...) end
function Logger.warn(...) Logger.log("warn", ...) end
function Logger.error(...) Logger.log("error", ...) end

-- ========================================
-- UTILITIES
-- ========================================
local Utils = {}

-- Check executor support
function Utils.validateExecutor()
    local required = {"readfile", "writefile", "isfile", "isfolder", "makefolder", "delfile"}
    for _, func in ipairs(required) do
        if not _G[func] then
            return false, func .. " not supported"
        end
    end
    return true, nil
end

-- Deep copy with optimization
function Utils.deepCopy(tbl, cache)
    if type(tbl) ~= "table" then return tbl end
    cache = cache or {}
    if cache[tbl] then return cache[tbl] end
    
    local copy = {}
    cache[tbl] = copy
    
    for k, v in pairs(tbl) do
        copy[k] = type(v) == "table" and Utils.deepCopy(v, cache) or v
    end
    
    return copy
end

-- Fast table comparison
function Utils.deepEqual(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    
    for k, v in pairs(a) do
        if type(v) == "table" then
            if not Utils.deepEqual(v, b[k]) then return false end
        elseif v ~= b[k] then
            return false
        end
    end
    
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    
    return true
end

-- Count keys efficiently
function Utils.countKeys(tbl)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

-- Safe JSON encode with pretty print
function Utils.jsonEncode(data, pretty)
    local success, result = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    return success and result or nil, success and nil or result
end

-- Safe JSON decode
function Utils.jsonDecode(str)
    if not str or str == "" then return nil, "Empty string" end
    
    -- Clean string
    str = str:match("^%s*(.-)%s*$")
    if str == "" then return nil, "Empty after trim" end
    
    local success, result = pcall(function()
        return HttpService:JSONDecode(str)
    end)
    
    return success and result or nil, success and nil or result
end

-- Boolean map <-> Array conversion
function Utils.toArray(value)
    if type(value) ~= "table" then return value end
    
    -- Check if it's a boolean map
    local hasBoolValues = false
    for _, v in pairs(value) do
        if type(v) == "boolean" then
            hasBoolValues = true
            break
        end
    end
    
    if not hasBoolValues then return value end
    
    -- Convert to array
    local arr = {}
    for k, v in pairs(value) do
        if v == true then table.insert(arr, k) end
    end
    return arr
end

function Utils.toMap(value)
    if type(value) ~= "table" or #value == 0 then return value end
    
    -- Check if sequential array
    local isArray = true
    for i = 1, #value do
        if value[i] == nil then
            isArray = false
            break
        end
    end
    
    if not isArray then return value end
    
    -- Convert to map
    local map = {}
    for _, v in ipairs(value) do
        map[v] = true
    end
    return map
end

-- ========================================
-- FILE OPERATIONS
-- ========================================
local FileOps = {}

-- Ensure directory exists
function FileOps.ensureDir(path)
    if not isfolder(path) then
        local ok, err = pcall(makefolder, path)
        if not ok then
            Logger.error("Failed to create directory:", err)
            return false
        end
        Logger.debug("Created directory:", path)
    end
    return true
end

-- Safe file read
function FileOps.read(path)
    if not isfile(path) then return nil, "File not found" end
    
    local ok, content = pcall(readfile, path)
    if not ok then return nil, "Read failed: " .. tostring(content) end
    
    return content, nil
end

-- Atomic write with verification (NO multiple .bak files)
function FileOps.write(path, content, verify)
    verify = verify == nil and CONFIG.verifyWrites or verify
    
    local tempPath = path .. CONFIG.tempExtension
    local backupPath = path .. CONFIG.backupExtension
    
    -- Step 1: Write to temp file
    local ok = pcall(writefile, tempPath, content)
    if not ok then
        Logger.error("Failed to write temp file")
        return false
    end
    
    -- Step 2: Verify temp file
    if verify then
        local verify, _ = FileOps.read(tempPath)
        if not verify or #verify ~= #content then
            Logger.error("Temp file verification failed")
            pcall(delfile, tempPath)
            return false
        end
    end
    
    -- Step 3: Backup current file (ONLY ONE BACKUP)
    if isfile(path) then
        local currentContent, _ = FileOps.read(path)
        if currentContent then
            pcall(writefile, backupPath, currentContent)
            Logger.debug("Backed up current file")
        end
    end
    
    -- Step 4: Replace main file
    ok = pcall(function()
        if isfile(path) then delfile(path) end
        writefile(path, content)
        delfile(tempPath)
    end)
    
    if not ok then
        Logger.error("Failed to replace main file")
        return false
    end
    
    -- Step 5: Final verification
    if verify then
        local final, _ = FileOps.read(path)
        if not final or #final ~= #content then
            Logger.error("Final verification failed")
            return false
        end
    end
    
    Logger.debug("Write successful:", #content, "bytes")
    return true
end

-- Delete file safely
function FileOps.delete(path)
    if isfile(path) then
        pcall(delfile, path)
        Logger.debug("Deleted:", path)
        return true
    end
    return false
end

-- Clean up duplicate backup files (.bak1, .bak2, etc)
function FileOps.cleanBackups(basePath)
    local cleaned = 0
    
    -- Remove numbered backups
    for i = 1, 100 do
        local backupPath = basePath .. ".bak" .. i
        if isfile(backupPath) then
            pcall(delfile, backupPath)
            cleaned = cleaned + 1
        end
    end
    
    -- Remove temp files
    local tempPath = basePath .. CONFIG.tempExtension
    if isfile(tempPath) then
        pcall(delfile, tempPath)
        cleaned = cleaned + 1
    end
    
    -- Remove corrupted files
    for i = 1, 100 do
        local corruptPath = basePath .. ".corrupted." .. i
        if isfile(corruptPath) then
            pcall(delfile, corruptPath)
            cleaned = cleaned + 1
        end
    end
    
    if cleaned > 0 then
        Logger.info("Cleaned up", cleaned, "old backup files")
    end
end

-- ========================================
-- VALIDATOR
-- ========================================
local Validator = {}

-- Validate JSON structure
function Validator.isValidJSON(content)
    if not content or #content < 10 then
        return false, "Too small"
    end
    
    -- Check structure
    local trimmed = content:match("^%s*(.-)%s*$")
    if not (trimmed:sub(1,1) == "{" and trimmed:sub(-1) == "}") then
        return false, "Invalid structure"
    end
    
    -- Try decode
    local data, err = Utils.jsonDecode(trimmed)
    if not data then
        return false, err or "Decode failed"
    end
    
    if type(data) ~= "table" then
        return false, "Not a table"
    end
    
    return true, data
end

-- Validate against defaults
function Validator.validateSettings(data, defaults)
    if type(data) ~= "table" then
        return false, "Invalid data type"
    end
    
    local keyCount = Utils.countKeys(data)
    if keyCount < CONFIG.minKeysRequired then
        return false, string.format("Too few keys: %d", keyCount)
    end
    
    return true, nil
end

-- Check file size
function Validator.checkSize(content)
    if #content > CONFIG.maxFileSize then
        return false, string.format("File too large: %d bytes", #content)
    end
    return true, nil
end

-- ========================================
-- RECOVERY ENGINE
-- ========================================
local Recovery = {}

-- Smart merge: Add ALL missing keys from defaults
function Recovery.smartMerge(partial, defaults)
    local merged = {}
    
    -- First, copy all defaults
    for key, value in pairs(defaults) do
        merged[key] = Utils.deepCopy(value)
    end
    
    -- Then, overlay partial data (only keys that exist in defaults)
    if type(partial) == "table" then
        for key, value in pairs(partial) do
            if defaults[key] ~= nil then
                merged[key] = Utils.deepCopy(value)
            elseif CONFIG.strictMode then
                Logger.debug("Removed unknown key:", key)
            end
        end
    end
    
    return merged
end

-- Recover from any file state
function Recovery.recover(path, defaults)
    Logger.info("Starting recovery for:", path)
    
    local mainPath = path
    local backupPath = path .. CONFIG.backupExtension
    
    -- Try main file first
    local mainContent, err = FileOps.read(mainPath)
    if mainContent then
        local valid, data = Validator.isValidJSON(mainContent)
        if valid then
            Logger.info("Main file valid, merging with defaults")
            return Recovery.smartMerge(data, defaults), "main"
        else
            Logger.warn("Main file corrupted:", data)
        end
    end
    
    -- Try backup file
    local backupContent, _ = FileOps.read(backupPath)
    if backupContent then
        local valid, data = Validator.isValidJSON(backupContent)
        if valid then
            Logger.info("Backup file valid, merging with defaults")
            return Recovery.smartMerge(data, defaults), "backup"
        else
            Logger.warn("Backup also corrupted")
        end
    end
    
    -- Both corrupted or missing - delete and start fresh
    Logger.warn("No valid files found, using defaults")
    
    if CONFIG.deleteCorrupted then
        FileOps.delete(mainPath)
        FileOps.delete(backupPath)
        Logger.info("Deleted corrupted files")
    end
    
    return Utils.deepCopy(defaults), "defaults"
end

-- ========================================
-- SAVEMANAGER CLASS
-- ========================================

function SaveManager.new(player, defaults)
    local self = setmetatable({}, SaveManager)
    
    -- Validate inputs
    if not player or not player:IsA("Player") then
        Logger.error("Invalid player")
        return nil
    end
    
    if type(defaults) ~= "table" or Utils.countKeys(defaults) == 0 then
        Logger.error("Invalid defaults")
        return nil
    end
    
    -- Check executor
    local ok, err = Utils.validateExecutor()
    if not ok then
        Logger.error("Executor not supported:", err)
        return nil
    end
    
    -- Initialize
    self.player = player
    self.defaults = Utils.deepCopy(defaults)
    self.data = {}
    
    -- State
    self.ready = false
    self.dirty = false
    self.saving = false
    self.lastSave = 0
    self.lastChange = 0
    self.saveCount = 0
    
    -- Paths
    self.folder = CONFIG.folderPath
    self.fileName = CONFIG.filePrefix .. player.Name .. CONFIG.fileExtension
    self.filePath = self.folder .. "/" .. self.fileName
    
    -- Threads
    self.autoSaveLoop = nil
    self.debounceLoop = nil
    
    -- Setup
    if not FileOps.ensureDir(self.folder) then
        Logger.error("Failed to create folder")
        return nil
    end
    
    -- Clean up old backup files first
    FileOps.cleanBackups(self.filePath)
    
    -- Load settings
    self:_load()
    
    -- Start auto-save
    if CONFIG.autoSave then
        self:_startAutoSave()
    end
    
    -- Cleanup on disconnect
    Players.PlayerRemoving:Connect(function(p)
        if p == self.player then
            self:shutdown()
        end
    end)
    
    Logger.info("Initialized for", player.Name)
    return self
end

-- ========================================
-- INTERNAL METHODS
-- ========================================

-- Load with recovery
function SaveManager:_load()
    local data, source = Recovery.recover(self.filePath, self.defaults)
    
    self.data = data
    self.ready = true
    
    -- If recovered from backup or defaults, save immediately
    if source ~= "main" then
        self.dirty = true
        self:save(true)
        Logger.info("Saved recovered data")
    end
    
    Logger.info("Loaded from:", source)
end

-- Save with retries
function SaveManager:save(force)
    if not self.ready then
        Logger.warn("Not ready to save")
        return false
    end
    
    if self.saving then
        Logger.debug("Already saving")
        return false
    end
    
    if not force and not self.dirty then
        Logger.debug("No changes to save")
        return false
    end
    
    self.saving = true
    
    -- Prepare data
    local saveData = Utils.deepCopy(self.data)
    saveData._version = CONFIG.version
    saveData._lastSaved = os.time()
    saveData._player = self.player.Name
    saveData._saveCount = self.saveCount + 1
    
    -- Encode
    local encoded, err = Utils.jsonEncode(saveData)
    if not encoded then
        Logger.error("Encode failed:", err)
        self.saving = false
        return false
    end
    
    -- Validate size
    local sizeOk, sizeErr = Validator.checkSize(encoded)
    if not sizeOk then
        Logger.error(sizeErr)
        self.saving = false
        return false
    end
    
    -- Write with retries
    local success = false
    for attempt = 1, CONFIG.writeRetries do
        if attempt > 1 then
            Logger.warn("Retry attempt", attempt)
            task.wait(CONFIG.retryDelay)
        end
        
        success = FileOps.write(self.filePath, encoded, CONFIG.verifyWrites)
        if success then break end
    end
    
    if success then
        self.dirty = false
        self.lastSave = os.time()
        self.saveCount = self.saveCount + 1
        Logger.debug("Saved:", #encoded, "bytes")
    else
        Logger.error("All save attempts failed")
    end
    
    self.saving = false
    return success
end

-- Auto-save loop
function SaveManager:_startAutoSave()
    if self.autoSaveLoop then return end
    
    Logger.debug("Starting auto-save")
    
    self.autoSaveLoop = task.spawn(function()
        while self.ready and task.wait(CONFIG.autoSaveInterval) do
            if self.dirty and not self.saving then
                self:save()
            end
        end
    end)
end

-- Stop auto-save
function SaveManager:_stopAutoSave()
    if self.autoSaveLoop then
        task.cancel(self.autoSaveLoop)
        self.autoSaveLoop = nil
        Logger.debug("Stopped auto-save")
    end
end

-- Debounce save
function SaveManager:_debounceSave()
    if self.debounceLoop then
        task.cancel(self.debounceLoop)
    end
    
    self.debounceLoop = task.delay(CONFIG.debounceDelay, function()
        if self.dirty then
            self:save()
        end
    end)
end

-- ========================================
-- PUBLIC API
-- ========================================

-- Get value
function SaveManager:get(key)
    if not key then return nil end
    
    local value = self.data[key]
    
    -- Convert to array for UI
    if type(value) == "table" then
        return Utils.toArray(value)
    end
    
    return value
end

-- Set value
function SaveManager:set(key, value)
    if not key or not self.ready then return false end
    
    -- Convert from array to map
    if type(value) == "table" then
        value = Utils.toMap(value)
    end
    
    -- Check if changed
    if Utils.deepEqual(self.data[key], value) then
        return true
    end
    
    self.data[key] = value
    self.dirty = true
    self.lastChange = tick()
    
    Logger.debug("Set:", key)
    
    -- Handle save
    if CONFIG.saveOnChange then
        self:save()
    elseif CONFIG.autoSave then
        self:_debounceSave()
    end
    
    return true
end

-- Batch set
function SaveManager:setBatch(values)
    if type(values) ~= "table" then return false end
    
    for key, value in pairs(values) do
        if type(value) == "table" then
            value = Utils.toMap(value)
        end
        
        if not Utils.deepEqual(self.data[key], value) then
            self.data[key] = value
            self.dirty = true
        end
    end
    
    if self.dirty then
        self.lastChange = tick()
        
        if CONFIG.saveOnChange then
            self:save()
        elseif CONFIG.autoSave then
            self:_debounceSave()
        end
    end
    
    return true
end

-- Reset to defaults
function SaveManager:reset()
    Logger.info("Resetting to defaults")
    
    -- Backup current
    if isfile(self.filePath) then
        local content, _ = FileOps.read(self.filePath)
        if content then
            local backupPath = self.filePath .. ".reset." .. os.time()
            pcall(writefile, backupPath, content)
        end
    end
    
    self.data = Utils.deepCopy(self.defaults)
    self.dirty = true
    
    return self:save(true)
end

-- Force save
function SaveManager:forceSave()
    return self:save(true)
end

-- Get all data
function SaveManager:getAll()
    return Utils.deepCopy(self.data)
end

-- Get stats
function SaveManager:getStats()
    local fileSize = 0
    if isfile(self.filePath) then
        local content, _ = FileOps.read(self.filePath)
        if content then fileSize = #content end
    end
    
    return {
        ready = self.ready,
        dirty = self.dirty,
        saving = self.saving,
        lastSave = self.lastSave,
        lastChange = self.lastChange,
        saveCount = self.saveCount,
        fileSize = fileSize,
        keyCount = Utils.countKeys(self.data)
    }
end

-- Export as JSON
function SaveManager:export()
    return Utils.jsonEncode(self.data)
end

-- Import from JSON
function SaveManager:import(jsonStr)
    local imported, err = Utils.jsonDecode(jsonStr)
    if not imported then
        return false, err
    end
    
    self.data = Recovery.smartMerge(imported, self.defaults)
    self.dirty = true
    
    return self:save(true)
end

-- Delete save
function SaveManager:deleteSave()
    Logger.warn("Deleting save files")
    
    FileOps.delete(self.filePath)
    FileOps.delete(self.filePath .. CONFIG.backupExtension)
    FileOps.cleanBackups(self.filePath)
    
    self.data = Utils.deepCopy(self.defaults)
    self.dirty = true
    
    return true
end

-- Shutdown
function SaveManager:shutdown()
    Logger.info("Shutting down")
    
    self:_stopAutoSave()
    
    if self.debounceLoop then
        task.cancel(self.debounceLoop)
    end
    
    if self.dirty then
        self:save(true)
    end
    
    self.ready = false
end

-- ========================================
-- CONFIGURATION API
-- ========================================

function SaveManager.setConfig(key, value)
    if CONFIG[key] ~= nil then
        CONFIG[key] = value
        Logger.debug("Config updated:", key, "=", value)
        return true
    end
    return false
end

function SaveManager.getConfig(key)
    return CONFIG[key]
end

function SaveManager.getAllConfig()
    return Utils.deepCopy(CONFIG)
end

-- ========================================
-- GLOBAL FUNCTIONS (Backwards Compatibility)
-- ========================================

_G.SaveManagerInstance = nil

function _G.initSaveManager(player, defaults)
    _G.SaveManagerInstance = SaveManager.new(player, defaults)
    return _G.SaveManagerInstance
end

function _G.saveConfig(name, value)
    if _G.SaveManagerInstance then
        return _G.SaveManagerInstance:set(name, value)
    end
    return false
end

function _G.getConfig(name)
    if _G.SaveManagerInstance then
        return _G.SaveManagerInstance:get(name)
    end
    return nil
end

function _G.forceSave()
    if _G.SaveManagerInstance then
        return _G.SaveManagerInstance:forceSave()
    end
    return false
end

function _G.resetSettings()
    if _G.SaveManagerInstance then
        return _G.SaveManagerInstance:reset()
    end
    return false
end

-- ========================================
-- RETURN MODULE
-- ========================================

return SaveManager