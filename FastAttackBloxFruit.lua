-- ==================== ULTRA-OPTIMIZED FAST ATTACK SYSTEM V3 ====================
-- FIXED: Mob detection, validation logic, and performance improvements

local _ENV = getgenv and getgenv() or getfenv(2)

-- ==================== CONFIGURATION ====================
local Config = {
    -- Core Settings
    FastAttack = false,
    AttackNearest = true,
    AttackMob = true,
    AttackPlayers = false,
    DebugMode = false, -- Toggle debug prints

    -- Performance (Ultra-Low Delay)
    FastAttackDelay = 0.05,
    ClickDelay = 0,
    AttackDistance = 2000,
    MaxTargets = 15,
    
    -- Optimization Flags
    UseRenderStepped = true,
    UseDeferredThread = true,
    PreemptiveAttack = true,
    
    -- Advanced Options
    PriorityMode = "Nearest", -- "Nearest", "Lowest HP", "Highest HP"
    CacheDuration = 0.08,
    
    -- Anti-Detection
    RandomizeDelay = false,
    DelayVariance = 0.02,
}

-- ==================== SERVICE INITIALIZATION ====================
local Services = {
    RS = game:GetService("ReplicatedStorage"),
    RunService = game:GetService("RunService"),
    Players = game:GetService("Players"),
    Workspace = game:GetService("Workspace")
}

local Player = Services.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local HRP, Humanoid

-- ==================== UTILITY FUNCTIONS ====================
local FastUtils = {}

function FastUtils.IsAlive(char)
    if not char then return false end
    local h = char:FindFirstChild("Humanoid")
    return h and h.Health > 0
end

function FastUtils.GetDistance(pos)
    if not HRP then return math.huge end
    return (HRP.Position - pos).Magnitude
end

function FastUtils.DebugPrint(...)
    if Config.DebugMode then
        print("[FastAttack]", ...)
    end
end

-- ==================== INITIALIZATION ====================
local function InitializeReferences()
    -- Update character references
    HRP = Character and Character:FindFirstChild("HumanoidRootPart")
    Humanoid = Character and Character:FindFirstChild("Humanoid")
    
    if not HRP or not Humanoid then
        warn("[FastAttack] Failed to get character parts!")
        return nil
    end
    
    -- Get remotes with better error handling
    local Modules = Services.RS:FindFirstChild("Modules")
    if not Modules then
        Modules = Services.RS:WaitForChild("Modules", 10)
    end
    
    if not Modules then
        warn("[FastAttack] Modules folder not found!")
        return nil
    end
    
    local Net = Modules:FindFirstChild("Net")
    if not Net then
        Net = Modules:WaitForChild("Net", 10)
    end
    
    if not Net then
        warn("[FastAttack] Net folder not found!")
        return nil
    end
    
    local RegisterAttack = Net:FindFirstChild("RE/RegisterAttack")
    local RegisterHit = Net:FindFirstChild("RE/RegisterHit")
    
    if not RegisterAttack or not RegisterHit then
        RegisterAttack = Net:WaitForChild("RE/RegisterAttack", 10)
        RegisterHit = Net:WaitForChild("RE/RegisterHit", 10)
    end
    
    local Enemies = Services.Workspace:FindFirstChild("Enemies")
    local Characters = Services.Workspace:FindFirstChild("Characters")
    
    if not Enemies then
        Enemies = Services.Workspace:WaitForChild("Enemies", 10)
    end
    if not Characters then
        Characters = Services.Workspace:WaitForChild("Characters", 10)
    end
    
    return {
        RegisterAttack = RegisterAttack,
        RegisterHit = RegisterHit,
        Enemies = Enemies,
        Characters = Characters
    }
end

local Refs = InitializeReferences()
if not Refs or not Refs.RegisterAttack or not Refs.RegisterHit then
    warn("[FastAttack] Critical initialization failure!")
    return
end

FastUtils.DebugPrint("Initialization successful!")

-- ==================== FAST ATTACK ENGINE ====================
local FastAttack = {
    Config = Config,
    Running = false,
    LastAttack = 0,
    
    Stats = {
        TPS = 0,
        APS = 0,
        TotalAttacks = 0,
        Errors = 0
    },
    
    Cache = {
        ValidTargets = {},
        LastUpdate = 0,
        PlayerStates = {},
        LastClear = 0
    }
}

-- ==================== IMPROVED VALIDATION ====================
function FastAttack:ValidateEnemy(enemy)
    -- Basic validation
    if not enemy or enemy == Character then 
        return false 
    end
    
    -- Check required parts
    local hum = enemy:FindFirstChild("Humanoid")
    local hrp = enemy:FindFirstChild("HumanoidRootPart")
    local head = enemy:FindFirstChild("Head")
    
    if not hum or not hrp or not head then
        return false
    end
    
    -- Health check
    if hum.Health <= 0 then
        return false
    end
    
    -- Determine if player or mob
    local enemyPlayer = Services.Players:GetPlayerFromCharacter(enemy)
    local isPlayer = enemyPlayer ~= nil
    
    -- MOB validation - SIMPLIFIED AND FIXED
    if not isPlayer then
        -- It's a mob, check if we should attack mobs
        if not Config.AttackMob then
            return false
        end
        
        -- Additional mob checks (optional)
        -- Some games have "friendly" mobs, you can add checks here
        
        return true -- Valid mob
    end
    
    -- PLAYER validation
    if not Config.AttackPlayers then 
        return false 
    end
    
    -- Self check (redundant but safe)
    if enemyPlayer == Player then
        return false
    end
    
    -- Team check
    if Player.Team and enemyPlayer.Team and enemyPlayer.Team == Player.Team then 
        return false 
    end
    
    -- GUI checks with caching
    local now = tick()
    local stateKey = enemy.Name
    local cached = self.Cache.PlayerStates[stateKey]
    
    if cached and (now - cached.time) < 0.5 then
        return cached.valid
    end
    
    -- Check PvP status
    local gui = Player:FindFirstChild("PlayerGui")
    if gui then
        local main = gui:FindFirstChild("Main")
        if main then
            -- PvP Disabled check
            local pvpDisabled = main:FindFirstChild("PvpDisabled")
            if pvpDisabled and pvpDisabled.Visible then
                self.Cache.PlayerStates[stateKey] = {valid = false, time = now}
                return false
            end
            
            -- SafeZone check
            local bottomHUD = main:FindFirstChild("BottomHUDList")
            if bottomHUD then
                local safeZone = bottomHUD:FindFirstChild("SafeZone")
                if safeZone and safeZone.Visible then
                    self.Cache.PlayerStates[stateKey] = {valid = false, time = now}
                    return false
                end
            end
        end
    end
    
    self.Cache.PlayerStates[stateKey] = {valid = true, time = now}
    return true
end

-- ==================== OPTIMIZED TARGET ACQUISITION ====================
function FastAttack:GetTargets()
    local targets = {}
    local maxDist = Config.AttackDistance
    
    local function scanFolder(folder, folderName)
        if not folder then 
            FastUtils.DebugPrint("Folder", folderName, "is nil!")
            return 
        end
        
        local children = folder:GetChildren()
        FastUtils.DebugPrint("Scanning", folderName, "- Found", #children, "entities")
        
        for _, enemy in ipairs(children) do
            if #targets >= Config.MaxTargets then break end
            
            -- Get head for distance calculation
            local head = enemy:FindFirstChild("Head")
            if not head then continue end
            
            -- Distance check first (fastest rejection)
            local dist = FastUtils.GetDistance(head.Position)
            if dist >= maxDist then continue end
            
            -- Validate enemy
            local isValid = self:ValidateEnemy(enemy)
            FastUtils.DebugPrint("  ->", enemy.Name, "Dist:", math.floor(dist), "Valid:", isValid)
            
            if isValid then
                local hum = enemy:FindFirstChild("Humanoid")
                table.insert(targets, {
                    entity = enemy,
                    head = head,
                    distance = dist,
                    hp = hum and hum.Health or 0
                })
            end
        end
    end
    
    -- Scan appropriate folders
    FastUtils.DebugPrint("=== Target Scan ===")
    FastUtils.DebugPrint("AttackMob:", Config.AttackMob, "| AttackPlayers:", Config.AttackPlayers)
    
    if Config.AttackMob and Refs.Enemies then 
        scanFolder(Refs.Enemies, "Enemies")
    end
    
    if Config.AttackPlayers and Refs.Characters then 
        scanFolder(Refs.Characters, "Characters")
    end
    
    FastUtils.DebugPrint("Total valid targets:", #targets)
    
    -- Sort by priority
    if #targets > 0 then
        if Config.PriorityMode == "Nearest" then
            table.sort(targets, function(a, b) return a.distance < b.distance end)
        elseif Config.PriorityMode == "Lowest HP" then
            table.sort(targets, function(a, b) return a.hp < b.hp end)
        elseif Config.PriorityMode == "Highest HP" then
            table.sort(targets, function(a, b) return a.hp > b.hp end)
        end
    end
    
    return targets
end

-- ==================== ATTACK EXECUTION ====================
function FastAttack:ExecuteAttack(targets)
    if not targets or #targets == 0 then return false end
    
    -- Prepare hit data
    local hitData = {}
    for _, target in ipairs(targets) do
        table.insert(hitData, {target.entity, target.head})
    end
    
    local basePart = targets[1].head
    
    -- Execute attack
    local success = false
    if Config.PreemptiveAttack then
        -- Non-blocking attack
        task.spawn(function()
            pcall(function()
                Refs.RegisterAttack:FireServer(Config.ClickDelay)
                Refs.RegisterHit:FireServer(basePart, hitData)
            end)
        end)
        success = true
    else
        -- Blocking attack with error handling
        success = pcall(function()
            Refs.RegisterAttack:FireServer(Config.ClickDelay)
            Refs.RegisterHit:FireServer(basePart, hitData)
        end)
    end
    
    if success then
        self.Stats.TotalAttacks = self.Stats.TotalAttacks + 1
        self.Stats.APS = self.Stats.APS + 1
    else
        self.Stats.Errors = self.Stats.Errors + 1
    end
    
    return success
end

-- ==================== MAIN ATTACK CYCLE ====================
local lastCycleTime = 0
function FastAttack:Cycle()
    -- Check if attack is enabled
    if not Config.FastAttack then return end
    
    -- Check if character is alive
    if not FastUtils.IsAlive(Character) then return end
    
    -- Check if weapon is equipped
    local tool = Character:FindFirstChildOfClass("Tool")
    if not tool then return end
    if tool.ToolTip == "Gun" then return end -- Skip guns
    
    -- Delay management
    local now = tick()
    local delay = Config.FastAttackDelay
    
    if Config.RandomizeDelay then
        delay = delay + (math.random() * Config.DelayVariance * 2 - Config.DelayVariance)
    end
    
    if (now - lastCycleTime) < delay then return end
    lastCycleTime = now
    
    -- Get targets and attack
    local targets = self:GetTargets()
    if #targets > 0 then
        self:ExecuteAttack(targets)
    end
end

-- ==================== PERFORMANCE MONITORING ====================
local perfStartTime = tick()
local perfTickCount = 0

function FastAttack:UpdatePerformance()
    perfTickCount = perfTickCount + 1
    local now = tick()
    
    if (now - perfStartTime) >= 1 then
        self.Stats.TPS = perfTickCount
        perfTickCount = 0
        
        -- Auto-tune delay based on performance
        if self.Stats.TPS < 30 and Config.FastAttackDelay > 0.03 then
            Config.FastAttackDelay = Config.FastAttackDelay * 0.95
        elseif self.Stats.TPS > 100 then
            Config.FastAttackDelay = Config.FastAttackDelay * 1.05
        end
        
        self.Stats.APS = 0
        perfStartTime = now
    end
end

-- ==================== START/STOP ====================
function FastAttack:Start()
    if self.Running then return end
    self.Running = true
    
    FastUtils.DebugPrint("Starting Fast Attack...")
    
    -- Primary attack loop
    if Config.UseRenderStepped then
        self.Connection = Services.RunService.RenderStepped:Connect(function()
            self:Cycle()
            self:UpdatePerformance()
        end)
    else
        self.Connection = Services.RunService.Heartbeat:Connect(function()
            self:Cycle()
            self:UpdatePerformance()
        end)
    end
    
    -- Backup loop
    if Config.UseDeferredThread then
        task.defer(function()
            while self.Running do
                task.wait(Config.FastAttackDelay)
                if Config.FastAttack then
                    self:Cycle()
                end
            end
        end)
    end
    
    -- Cache cleanup loop
    task.spawn(function()
        while self.Running do
            task.wait(10)
            self.Cache.PlayerStates = {}
            self.Cache.LastClear = tick()
            FastUtils.DebugPrint("Cache cleared")
        end
    end)
    
    print("[FastAttack] Started successfully!")
end

function FastAttack:Stop()
    if not self.Running then return end
    self.Running = false
    
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
    
    print("[FastAttack] Stopped")
end

function FastAttack:Toggle()
    Config.FastAttack = not Config.FastAttack
    print("[FastAttack] Toggled:", Config.FastAttack and "ON" or "OFF")
end

-- ==================== CONFIG UPDATE ====================
function FastAttack:UpdateConfig(newConfig)
    if not newConfig then return end
    
    for key, value in pairs(newConfig) do
        if Config[key] ~= nil then
            local oldValue = Config[key]
            Config[key] = value
            FastUtils.DebugPrint("Config Update:", key, oldValue, "->", value)
        end
    end
    
    -- Handle FastAttack state change
    if newConfig.FastAttack ~= nil then
        if newConfig.FastAttack and not self.Running then
            self:Start()
        elseif not newConfig.FastAttack and self.Running then
            self:Stop()
        end
    end
    
    FastUtils.DebugPrint("Config updated successfully")
end

-- ==================== CHARACTER RESPAWN ====================
Player.CharacterAdded:Connect(function(newChar)
    Character = newChar
    FastUtils.DebugPrint("Character respawned, reinitializing...")
    
    task.wait(0.5)
    
    -- Reinitialize references
    local newRefs = InitializeReferences()
    if newRefs then
        Refs = newRefs
        FastUtils.DebugPrint("References reinitialized")
    end
    
    -- Restart if was running
    if FastAttack.Running then
        FastAttack:Stop()
        task.wait(0.3)
        FastAttack:Start()
    end
end)

-- ==================== GLOBAL EXPORT ====================
_ENV.FastAttackSkibidi = FastAttack

-- Debug commands
_ENV.FA_Toggle = function() FastAttack:Toggle() end
_ENV.FA_Start = function() FastAttack:Start() end
_ENV.FA_Stop = function() FastAttack:Stop() end
_ENV.FA_Debug = function() 
    Config.DebugMode = not Config.DebugMode
    print("[FastAttack] Debug Mode:", Config.DebugMode and "ON" or "OFF")
end
_ENV.FA_Stats = function() 
    print("=== FastAttack Stats ===")
    print("Running:", FastAttack.Running)
    print("TPS:", FastAttack.Stats.TPS)
    print("APS:", FastAttack.Stats.APS)
    print("Total Attacks:", FastAttack.Stats.TotalAttacks)
    print("Errors:", FastAttack.Stats.Errors)
    print("Delay:", Config.FastAttackDelay)
    print("AttackMob:", Config.AttackMob)
    print("AttackPlayers:", Config.AttackPlayers)
    print("FastAttack:", Config.FastAttack)
end

-- Auto-start if enabled
if Config.FastAttack then
    task.wait(1)
    FastAttack:Start()
end

return FastAttack