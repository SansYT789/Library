-- ==================== ULTRA-OPTIMIZED FAST ATTACK SYSTEM V2 ====================
-- Maximum performance with advanced error handling and reliability improvements

local _ENV = getgenv and getgenv() or getfenv(2)

-- ==================== CONFIGURATION ====================
local Config = {
    -- Core Settings
    FastAttack = false,
    AttackNearest = true,
    AttackMob = true,
    AttackPlayers = false,

    -- Performance (Ultra-Low Delay)
    FastAttackDelay = 0.05, -- Reduced from 0.1
    ClickDelay = 0,
    AttackDistance = 2000,
    MaxTargets = 15,
    
    -- Optimization Flags
    UseRenderStepped = true, -- Highest priority loop
    UseDeferredThread = true, -- Non-blocking operations
    SkipRedundantChecks = true,
    AggressiveCaching = true,
    ParallelProcessing = true,
    
    -- Advanced Options
    PriorityMode = "Nearest", -- "Nearest", "Lowest HP", "Highest HP"
    PreemptiveAttack = true,
    CacheDuration = 0.08,
    
    -- Anti-Detection
    RandomizeDelay = false,
    DelayVariance = 0.02,
}

-- ==================== SERVICE CACHE ====================
local Services = {
    RS = game:GetService("ReplicatedStorage"),
    RunService = game:GetService("RunService"),
    Players = game:GetService("Players"),
    Workspace = game:GetService("Workspace")
}

local Player = Services.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local HRP, Humanoid

-- ==================== FAST UTILITY FUNCTIONS ====================
local FastUtils = {}

-- Optimized alive check
function FastUtils.IsAlive(char)
    if not char then return false end
    local h = char:FindFirstChild("Humanoid")
    return h and h.Health > 0
end

-- Cached distance calculation
function FastUtils.GetDistance(pos)
    if not HRP then return math.huge end
    return (HRP.Position - pos).Magnitude
end

-- Safe remote access with caching
local RemoteCache = {}
function FastUtils.GetRemote(path)
    if RemoteCache[path] then return RemoteCache[path] end
    
    local current = Services.RS
    for segment in string.gmatch(path, "[^/]+") do
        current = current:FindFirstChild(segment)
        if not current then return nil end
    end
    
    RemoteCache[path] = current
    return current
end

-- ==================== INITIALIZATION ====================
local function InitializeReferences()
    HRP = Character and Character:FindFirstChild("HumanoidRootPart")
    Humanoid = Character and Character:FindFirstChild("Humanoid")
    
    -- Get remotes
    local Modules = Services.RS:WaitForChild("Modules", 5)
    local Net = Modules and Modules:WaitForChild("Net", 5)
    
    return {
        RegisterAttack = Net and Net:WaitForChild("RE/RegisterAttack", 5),
        RegisterHit = Net and Net:WaitForChild("RE/RegisterHit", 5),
        Enemies = Services.Workspace:WaitForChild("Enemies", 5),
        Characters = Services.Workspace:WaitForChild("Characters", 5)
    }
end

local Refs = InitializeReferences()
if not Refs.RegisterAttack or not Refs.RegisterHit then
    warn("[FastAttack] Failed to initialize remotes!")
    return
end

-- ==================== FAST ATTACK ENGINE ====================
local FastAttack = {
    Config = Config,
    Running = false,
    LastAttack = 0,
    AttackQueue = {},
    
    -- Performance Tracking
    Stats = {
        TPS = 0, -- Ticks per second
        APS = 0, -- Attacks per second
        AvgDelay = 0,
        Errors = 0
    },
    
    -- Advanced Cache
    Cache = {
        Enemies = {},
        ValidTargets = {},
        LastUpdate = 0,
        PlayerStates = {},
        LastClear = 0
    }
}

-- ==================== OPTIMIZED VALIDATION ====================
local ValidationCache = {}
setmetatable(ValidationCache, {__mode = "k"}) -- Weak keys for GC

function FastAttack:FastValidate(enemy)
    local now = tick()
    local cached = ValidationCache[enemy]
    
    if cached and (now - cached.time) < 0.1 then
        return cached.valid
    end
    
    -- Quick checks first
    if not enemy or enemy == Character then 
        ValidationCache[enemy] = {valid = false, time = now}
        return false 
    end
    
    local hum = enemy:FindFirstChild("Humanoid")
    local hrp = enemy:FindFirstChild("HumanoidRootPart")
    
    if not hum or not hrp or hum.Health <= 0 then
        ValidationCache[enemy] = {valid = false, time = now}
        return false
    end
    
    local enemyPlayer = Services.Players:FindFirstChild(enemy.Name)
    local isPlayer = enemyPlayer ~= nil
    
    -- MOB validation
    if not isPlayer then
        local valid = self.Config.AttackMob
        ValidationCache[enemy] = {valid = valid, time = now}
        return valid
    end
    
    -- PLAYER validation
    if not self.Config.AttackPlayers then 
        ValidationCache[enemy] = {valid = false, time = now}
        return false 
    end
    
    -- Team check
    if enemyPlayer.Team == Player.Team then 
        ValidationCache[enemy] = {valid = false, time = now}
        return false 
    end
    
    -- GUI checks (cached)
    local stateKey = enemy.Name
    local state = self.Cache.PlayerStates[stateKey]
    
    if state and (now - state.time) < 0.3 then
        return state.valid
    end
    
    -- Fast GUI validation
    local gui = Player:FindFirstChild("PlayerGui")
    if gui then
        local main = gui:FindFirstChild("Main")
        if main then
            if main:FindFirstChild("PvpDisabled") and main.PvpDisabled.Visible then
                self.Cache.PlayerStates[stateKey] = {valid = false, time = now}
                ValidationCache[enemy] = {valid = false, time = now}
                return false
            end
            
            local bottomHUD = main:FindFirstChild("BottomHUDList")
            if bottomHUD then
                local safeZone = bottomHUD:FindFirstChild("SafeZone")
                if safeZone and safeZone.Visible then
                    self.Cache.PlayerStates[stateKey] = {valid = false, time = now}
                    ValidationCache[enemy] = {valid = false, time = now}
                    return false
                end
            end
        end
    end
    
    self.Cache.PlayerStates[stateKey] = {valid = true, time = now}
    ValidationCache[enemy] = {valid = true, time = now}
    return true
end

-- ==================== HIGH-SPEED TARGET ACQUISITION ====================
function FastAttack:GetTargets()
    local now = tick()
    
    -- Use cached targets if still valid
    if Config.AggressiveCaching and 
       (now - self.Cache.LastUpdate) < Config.CacheDuration and 
       #self.Cache.ValidTargets > 0 then
        return self.Cache.ValidTargets
    end
    
    local targets = {}
    local maxDist = Config.AttackDistance
    local count = 0
    
    local function scan(folder)
        if not folder then return end
        
        for _, enemy in ipairs(folder:GetChildren()) do
            if count >= Config.MaxTargets then break end
            
            local head = enemy:FindFirstChild("Head")
            if head then
                local dist = FastUtils.GetDistance(head.Position)
                
                if dist < maxDist and self:FastValidate(enemy) then
                    count = count + 1
                    table.insert(targets, {
                        entity = enemy,
                        head = head,
                        distance = dist,
                        hp = enemy.Humanoid.Health or 0
                    })
                end
            end
        end
    end
    
    -- Parallel scanning
    if Config.AttackMob then scan(Refs.Enemies) end
    if Config.AttackPlayers then scan(Refs.Characters) end
    
    -- Sort by priority
    if Config.PriorityMode == "Nearest" then
        table.sort(targets, function(a, b) return a.distance < b.distance end)
    elseif Config.PriorityMode == "Lowest HP" then
        table.sort(targets, function(a, b) return a.hp < b.hp end)
    elseif Config.PriorityMode == "Highest HP" then
        table.sort(targets, function(a, b) return a.hp > b.hp end)
    end
    
    self.Cache.ValidTargets = targets
    self.Cache.LastUpdate = now
    
    return targets
end

-- ==================== ULTRA-FAST ATTACK EXECUTION ====================
function FastAttack:Strike(targets)
    if not targets or #targets == 0 then return false end
    
    local hitData = {}
    for _, t in ipairs(targets) do
        table.insert(hitData, {t.entity, t.head})
    end
    
    local basePart = targets[1].head
    local success = false
    
    -- Preemptive fire (no waiting)
    if Config.PreemptiveAttack then
        task.spawn(function()
            pcall(function()
                Refs.RegisterAttack:FireServer(Config.ClickDelay)
                Refs.RegisterHit:FireServer(basePart, hitData)
            end)
        end)
        success = true
    else
        success = pcall(function()
            Refs.RegisterAttack:FireServer(Config.ClickDelay)
            Refs.RegisterHit:FireServer(basePart, hitData)
        end)
    end
    
    if not success then
        self.Stats.Errors = self.Stats.Errors + 1
    end
    
    return success
end

-- ==================== MAIN ATTACK CYCLE ====================
local lastCycle = 0
function FastAttack:Cycle()
    if not Config.FastAttack then return end
    if not FastUtils.IsAlive(Character) then return end
    
    -- Check equipped weapon
    local tool = Character:FindFirstChildOfClass("Tool")
    if not tool or tool.ToolTip == "Gun" then return end
    
    -- Adaptive delay with randomization
    local now = tick()
    local delay = Config.FastAttackDelay
    
    if Config.RandomizeDelay then
        delay = delay + (math.random() * Config.DelayVariance * 2 - Config.DelayVariance)
    end
    
    if (now - lastCycle) < delay then return end
    lastCycle = now
    
    -- Get and strike targets
    local targets = self:GetTargets()
    if #targets > 0 then
        self:Strike(targets)
        self.Stats.APS = self.Stats.APS + 1
    end
end

-- ==================== ADAPTIVE PERFORMANCE MONITORING ====================
local perfMonitor = tick()
local tickCount = 0

function FastAttack:UpdateStats()
    tickCount = tickCount + 1
    local now = tick()
    
    if (now - perfMonitor) >= 1 then
        self.Stats.TPS = tickCount
        tickCount = 0
        
        -- Auto-adjust based on performance
        if self.Stats.TPS < 30 and Config.FastAttackDelay > 0.03 then
            Config.FastAttackDelay = Config.FastAttackDelay * 0.95
        elseif self.Stats.TPS > 100 then
            Config.FastAttackDelay = Config.FastAttackDelay * 1.05
        end
        
        self.Stats.APS = 0
        perfMonitor = now
    end
end

-- ==================== START/STOP SYSTEM ====================
function FastAttack:Start()
    if self.Running then return end
    self.Running = true
    
    -- Primary loop (RenderStepped for max speed)
    if Config.UseRenderStepped then
        self.Connection = Services.RunService.RenderStepped:Connect(function()
            self:Cycle()
            self:UpdateStats()
        end)
    else
        self.Connection = Services.RunService.Heartbeat:Connect(function()
            self:Cycle()
            self:UpdateStats()
        end)
    end
    
    -- Backup loop with deferred threading
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
    
    -- Cache cleanup
    task.spawn(function()
        while self.Running do
            task.wait(5)
            if tick() - self.Cache.LastClear > 10 then
                self.Cache.PlayerStates = {}
                ValidationCache = {}
                self.Cache.LastClear = tick()
            end
        end
    end)
    
    print("[FastAttack] Started with ultra-low delay mode")
end

function FastAttack:Stop()
    self.Running = false
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
    print("[FastAttack] Stopped")
end

function FastAttack:Toggle()
    Config.FastAttack = not Config.FastAttack
    print("[FastAttack] Toggled:", Config.FastAttack)
end

function FastAttack:UpdateConfig(newConfig)
    for k, v in pairs(newConfig) do
        if Config[k] ~= nil then
            Config[k] = v
        end
    end
end

-- ==================== CHARACTER RESPAWN ====================
Player.CharacterAdded:Connect(function(newChar)
    Character = newChar
    task.wait(0.5)
    
    HRP = Character:WaitForChild("HumanoidRootPart", 5)
    Humanoid = Character:WaitForChild("Humanoid", 5)
    
    if FastAttack.Running then
        FastAttack:Stop()
        task.wait(0.3)
        FastAttack:Start()
    end
end)

-- ==================== GLOBAL EXPORT ====================
_ENV.FastAttackSkibidi = FastAttack

-- Auto-start if enabled
if Config.FastAttack then
    task.wait(1)
    FastAttack:Start()
end

-- ==================== DEBUG COMMANDS ====================
_ENV.FA_Toggle = function() FastAttack:Toggle() end
_ENV.FA_Start = function() FastAttack:Start() end
_ENV.FA_Stop = function() FastAttack:Stop() end
_ENV.FA_Stats = function() 
    print("=== FastAttack Stats ===")
    print("TPS:", FastAttack.Stats.TPS)
    print("APS:", FastAttack.Stats.APS)
    print("Errors:", FastAttack.Stats.Errors)
    print("Delay:", Config.FastAttackDelay)
end

return FastAttack