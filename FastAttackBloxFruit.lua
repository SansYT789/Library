-- ============================================
-- FAST ATTACK SYSTEM V2.0
-- Optimized & Enhanced Version
-- ============================================

-- Utility function
function nHgshEJpoqgHTBEJZ(c)
    local tab = {}
    for i = 1, #c do
        local x = string.len(c[i])
        local y = string.char(x)
        table.insert(tab, y)
    end
    return table.concat(tab)
end

-- ============================================
-- CONFIGURATION SETTINGS
-- ============================================
_G.FastAttackConfig = _G.FastAttackConfig or {
    -- Core Settings
    Enabled = true,
    AutoClick = true,
    
    -- Performance Settings
    ClickDelay = 0,
    AttackDelay = 0,
    UpdateRate = 0.01,
    
    -- Distance Settings
    MaxAttackDistance = 200000,
    OptimalDistance = 50,
    
    -- Target Settings
    AttackMobs = true,
    AttackPlayers = false,
    AttackBosses = true,
    PrioritizeBosses = true,
    
    -- Safety Settings
    CheckAlive = true,
    CheckEquipped = true,
    IgnoreGuns = true,
    
    -- Advanced Settings
    MultiTarget = true,
    MaxTargets = 10,
    UseFastMode = true,
    UseRenderStepped = false,
    
    -- Debug Settings
    DebugMode = false,
    ShowWarnings = true,
    LogErrors = true
}

local Config = _G.FastAttackConfig

-- ============================================
-- INITIALIZATION
-- ============================================
if not Config.Enabled then
    warn("Fast Attack System is disabled")
    return
end

local _ENV = (getgenv or getrenv or getfenv)()

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================
local function SafeWaitForChild(parent, childName, timeout)
    timeout = timeout or 10
    local success, result = pcall(function()
        return parent:WaitForChild(childName, timeout)
    end)
    
    if not success or not result then
        if Config.ShowWarnings then
            warn(string.format("Failed to find child: %s", childName))
        end
        return nil
    end
    
    return result
end

local function WaitChilds(path, ...)
    local last = path
    for _, child in {...} do
        last = last:FindFirstChild(child) or SafeWaitForChild(last, child)
        if not last then
            break
        end
    end
    return last
end

local function DebugLog(message)
    if Config.DebugMode then
        print(string.format("[FastAttack Debug] %s", message))
    end
end

local function ErrorLog(message)
    if Config.LogErrors then
        warn(string.format("[FastAttack Error] %s", message))
    end
end

-- ============================================
-- SERVICE INITIALIZATION
-- ============================================
local Services = {
    VirtualInput = game:GetService("VirtualInputManager"),
    Collection = game:GetService("CollectionService"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    Teleport = game:GetService("TeleportService"),
    RunService = game:GetService("RunService"),
    Players = game:GetService("Players")
}

local Player = Services.Players.LocalPlayer

if not Player then
    ErrorLog("Local player not found")
    return
end

-- ============================================
-- GAME OBJECTS
-- ============================================
local Remotes = SafeWaitForChild(Services.ReplicatedStorage, "Remotes")
if not Remotes then
    ErrorLog("Remotes not found")
    return
end

local GameObjects = {
    Validator = SafeWaitForChild(Remotes, "Validator"),
    CommF = SafeWaitForChild(Remotes, "CommF_"),
    CommE = SafeWaitForChild(Remotes, "CommE"),
    ChestModels = SafeWaitForChild(workspace, "ChestModels"),
    WorldOrigin = SafeWaitForChild(workspace, "_WorldOrigin"),
    Characters = SafeWaitForChild(workspace, "Characters"),
    Enemies = SafeWaitForChild(workspace, "Enemies"),
    Map = SafeWaitForChild(workspace, "Map")
}

if GameObjects.WorldOrigin then
    GameObjects.EnemySpawns = SafeWaitForChild(GameObjects.WorldOrigin, "EnemySpawns")
    GameObjects.Locations = SafeWaitForChild(GameObjects.WorldOrigin, "Locations")
end

-- ============================================
-- NET MODULES
-- ============================================
local Modules = SafeWaitForChild(Services.ReplicatedStorage, "Modules")
local Net = Modules and SafeWaitForChild(Modules, "Net")

if not Net then
    ErrorLog("Net module not found")
    return
end

local RegisterAttack = SafeWaitForChild(Net, "RE/RegisterAttack")
local RegisterHit = SafeWaitForChild(Net, "RE/RegisterHit")

-- ============================================
-- COMPATIBILITY FUNCTIONS
-- ============================================
local sethiddenproperty = sethiddenproperty or function(...) return ... end
local setupvalue = setupvalue or (debug and debug.setupvalue)
local getupvalue = getupvalue or (debug and debug.getupvalue)

-- ============================================
-- FAST ATTACK MODULE
-- ============================================
local Module = {}

Module.FastAttack = (function()
    -- Return existing instance if available
    if _ENV.rz_FastAttack then
        DebugLog("Using existing FastAttack instance")
        return _ENV.rz_FastAttack
    end
    
    local FastAttack = {
        Active = false,
        LastAttackTick = 0,
        TargetCache = {},
        Statistics = {
            TotalAttacks = 0,
            TotalHits = 0,
            LastUpdate = tick()
        }
    }
    
    -- ========================================
    -- HELPER FUNCTIONS
    -- ========================================
    local function IsAlive(character)
        if not Config.CheckAlive then return true end
        return character 
            and character:FindFirstChild("Humanoid") 
            and character.Humanoid.Health > 0
    end
    
    local function IsBoss(enemy)
        return enemy 
            and enemy:FindFirstChild("Humanoid") 
            and enemy.Humanoid:FindFirstChild("IsBoss")
    end
    
    local function GetDistance(position)
        return Player:DistanceFromCharacter(position)
    end
    
    local function IsValidTarget(enemy)
        if not enemy or not IsAlive(enemy) then
            return false
        end
        
        if enemy == Player.Character then
            return false
        end
        
        local head = enemy:FindFirstChild("Head")
        if not head then
            return false
        end
        
        local distance = GetDistance(head.Position)
        if distance > Config.MaxAttackDistance then
            return false
        end
        
        return true
    end
    
    local function SortByPriority(a, b)
        local aIsBoss = IsBoss(a[1])
        local bIsBoss = IsBoss(b[1])
        
        if Config.PrioritizeBosses then
            if aIsBoss and not bIsBoss then return true end
            if bIsBoss and not aIsBoss then return false end
        end
        
        local aDist = GetDistance(a[2].Position)
        local bDist = GetDistance(b[2].Position)
        
        return aDist < bDist
    end
    
    -- ========================================
    -- TARGET PROCESSING
    -- ========================================
    local function ProcessEnemies(enemyList, folder, shouldAttack)
        if not folder or not shouldAttack then return nil end
        
        local basePart = nil
        local processed = 0
        
        for _, enemy in folder:GetChildren() do
            if Config.MultiTarget and processed >= Config.MaxTargets then
                break
            end
            
            if IsValidTarget(enemy) then
                local head = enemy:FindFirstChild("Head")
                if head then
                    table.insert(enemyList, {enemy, head})
                    basePart = basePart or head
                    processed = processed + 1
                    
                    DebugLog(string.format("Target added: %s (Distance: %.2f)", 
                        enemy.Name, GetDistance(head.Position)))
                end
            end
        end
        
        return basePart
    end
    
    function FastAttack:GatherTargets()
        local targets = {}
        local primaryTarget = nil
        
        -- Process mobs
        if Config.AttackMobs and GameObjects.Enemies then
            primaryTarget = ProcessEnemies(targets, GameObjects.Enemies, true)
        end
        
        -- Process players
        if Config.AttackPlayers and GameObjects.Characters then
            local playerTarget = ProcessEnemies(targets, GameObjects.Characters, true)
            primaryTarget = primaryTarget or playerTarget
        end
        
        -- Sort by priority
        if #targets > 1 then
            table.sort(targets, SortByPriority)
        end
        
        return primaryTarget, targets
    end
    
    -- ========================================
    -- ATTACK FUNCTIONS
    -- ========================================
    function FastAttack:ExecuteAttack(basePart, targets)
        if not basePart or #targets == 0 then
            return false
        end
        
        if not RegisterAttack or not RegisterHit then
            ErrorLog("Attack remotes not available")
            return false
        end
        
        local success, error = pcall(function()
            RegisterAttack:FireServer(Config.ClickDelay)
            RegisterHit:FireServer(basePart, targets)
        end)
        
        if success then
            self.Statistics.TotalAttacks = self.Statistics.TotalAttacks + 1
            self.Statistics.TotalHits = self.Statistics.TotalHits + #targets
            DebugLog(string.format("Attack executed: %d targets", #targets))
            return true
        else
            ErrorLog(string.format("Attack failed: %s", tostring(error)))
            return false
        end
    end
    
    function FastAttack:PerformAttack()
        -- Check rate limiting
        local currentTick = tick()
        if currentTick - self.LastAttackTick < Config.AttackDelay then
            return
        end
        self.LastAttackTick = currentTick
        
        -- Check equipment
        if Config.CheckEquipped then
            local equipped = IsAlive(Player.Character) 
                and Player.Character:FindFirstChildOfClass("Tool")
            
            if not equipped then
                return
            end
            
            if Config.IgnoreGuns and equipped.ToolTip == "Gun" then
                return
            end
        end
        
        -- Gather and attack targets
        local primaryTarget, targets = self:GatherTargets()
        
        if #targets > 0 then
            self:ExecuteAttack(primaryTarget, targets)
        end
    end
    
    -- ========================================
    -- MAIN LOOP
    -- ========================================
    function FastAttack:Start()
        if self.Active then
            return
        end
        
        self.Active = true
        DebugLog("Fast Attack System started")
        
        local updateEvent = Config.UseRenderStepped 
            and Services.RunService.RenderStepped 
            or Services.RunService.Heartbeat
        
        self.Connection = updateEvent:Connect(function()
            if Config.Enabled and Config.AutoClick then
                self:PerformAttack()
            end
        end)
    end
    
    function FastAttack:Stop()
        if not self.Active then
            return
        end
        
        self.Active = false
        
        if self.Connection then
            self.Connection:Disconnect()
            self.Connection = nil
        end
        
        DebugLog("Fast Attack System stopped")
    end
    
    function FastAttack:GetStatistics()
        return {
            TotalAttacks = self.Statistics.TotalAttacks,
            TotalHits = self.Statistics.TotalHits,
            AverageHitsPerAttack = self.Statistics.TotalAttacks > 0 
                and (self.Statistics.TotalHits / self.Statistics.TotalAttacks) 
                or 0,
            Uptime = tick() - self.Statistics.LastUpdate
        }
    end
    
    function FastAttack:ResetStatistics()
        self.Statistics = {
            TotalAttacks = 0,
            TotalHits = 0,
            LastUpdate = tick()
        }
    end
    
    -- ========================================
    -- AUTO START
    -- ========================================
    FastAttack:Start()
    
    -- Cache globally
    _ENV.rz_FastAttack = FastAttack
    
    return FastAttack
end)()

-- ============================================
-- GLOBAL API
-- ============================================
_G.FastAttackAPI = {
    Toggle = function(state)
        Config.Enabled = state
        DebugLog(string.format("System %s", state and "enabled" or "disabled"))
    end,
    
    SetDistance = function(distance)
        Config.MaxAttackDistance = distance
        DebugLog(string.format("Max distance set to %d", distance))
    end,
    
    SetDelay = function(delay)
        Config.AttackDelay = delay
        DebugLog(string.format("Attack delay set to %.3f", delay))
    end,
    
    GetStats = function()
        return Module.FastAttack:GetStatistics()
    end,
    
    ResetStats = function()
        Module.FastAttack:ResetStatistics()
    end,
    
    GetConfig = function()
        return Config
    end,
    
    UpdateConfig = function(newConfig)
        for key, value in pairs(newConfig) do
            if Config[key] ~= nil then
                Config[key] = value
            end
        end
        DebugLog("Configuration updated")
    end
}

return Module