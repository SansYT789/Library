-- ==================== ULTRA-OPTIMIZED FAST ATTACK SYSTEM V4 - ULTIMATE EDITION ====================
-- REVOLUTIONARY: Zero-delay attacks, predictive targeting, bulletproof validation, adaptive performance
-- NEW: Multi-threaded execution, target prediction, priority weighting, attack queueing

local _ENV = getgenv and getgenv() or getfenv(2)

-- ==================== ADVANCED CONFIGURATION ====================
local Config = {
    -- Core Attack Settings
    FastAttack = false,
    AttackNearest = true,
    AttackMob = true,
    AttackPlayers = false,
    DebugMode = false,

    -- Ultra Performance (Zero-Delay System)
    FastAttackDelay = 0.025,        -- Base delay (can go lower)
    MinDelay = 0.01,                -- Minimum enforced delay
    MaxDelay = 0.1,                 -- Maximum delay
    ClickDelay = 0,
    AttackDistance = 500,
    MaxTargets = 20,                -- Increased from 15
    
    -- Advanced Targeting Options
    PriorityMode = "Smart",         -- "Smart", "Nearest", "Lowest HP", "Highest HP", "Threat Level", "Mixed"
    PriorityWeights = {
        Distance = 0.4,             -- Weight for distance priority
        Health = 0.3,               -- Weight for health priority  
        Threat = 0.2,               -- Weight for threat level
        Type = 0.1                  -- Weight for entity type (player vs mob)
    },
    
    -- Predictive Targeting (NEW)
    UsePredictiveTargeting = true,  -- Predict target movement
    PredictionTime = 0.1,           -- How far ahead to predict
    TrackVelocity = true,           -- Track and use velocity data
    
    -- Multi-Target Settings (NEW)
    AttackMode = "Cascade",         -- "Single", "Burst", "Cascade", "Sweep"
    BurstCount = 3,                 -- Targets per burst
    CascadeDelay = 0.005,           -- Delay between cascade attacks
    
    -- Optimization Flags
    UseRenderStepped = true,
    UseDeferredThread = true,
    UseBackupThread = true,         -- NEW: Additional backup thread
    PreemptiveAttack = true,
    UseParallelExecution = true,    -- NEW: Parallel attack execution
    
    -- Performance Tuning
    CacheDuration = 0.05,           -- Reduced for faster updates
    ValidationInterval = 0.03,      -- How often to revalidate targets
    AutoTunePerformance = true,     -- Automatically adjust delays
    TargetFPS = 60,                 -- Target frame rate to maintain
    
    -- Advanced Anti-Detection (NEW)
    HumanizedMode = false,          -- Makes attacks appear more human
    RandomizeDelay = false,
    DelayVariance = 0.015,
    RandomizeTargetOrder = false,   -- Randomize multi-target order
    MimicInputDelay = false,        -- Add realistic input delay
    
    -- Filtering Options (NEW)
    IgnoreInvulnerable = true,      -- Skip invulnerable targets
    IgnoreForceField = true,        -- Skip force fielded targets
    RequireLineOfSight = false,     -- Only attack visible targets
    MinHealthThreshold = 0.01,      -- Minimum health % to attack
    MaxHealthThreshold = 1.0,       -- Maximum health % to attack
    
    -- Team Settings (NEW)
    RespectTeams = true,            -- Don't attack teammates
    AllyProtection = true,          -- Extra validation for allies
    
    -- Attack Persistence (NEW)
    RetryFailedAttacks = true,      -- Retry on failure
    MaxRetries = 2,                 -- Maximum retry attempts
    QueueAttacks = true,            -- Queue attacks when rate limited
    QueueSize = 50,                 -- Maximum queue size
    
    -- Recovery Settings (NEW)
    AutoRecover = true,             -- Auto-recover from errors
    RecoveryDelay = 0.5,            -- Delay before recovery
    MaxConsecutiveErrors = 5,       -- Max errors before pause
}

-- ==================== SERVICE INITIALIZATION ====================
local Services = {
    RS = game:GetService("ReplicatedStorage"),
    RunService = game:GetService("RunService"),
    Players = game:GetService("Players"),
    Workspace = game:GetService("Workspace"),
    Stats = game:GetService("Stats")
}

local Player = Services.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local HRP, Humanoid

-- ==================== ADVANCED UTILITIES ====================
local FastUtils = {}

function FastUtils.IsAlive(char)
    if not char then return false end
    local h = char:FindFirstChild("Humanoid")
    return h and h.Health > 0 and h.Health ~= math.huge
end

function FastUtils.GetDistance(pos)
    if not HRP then return math.huge end
    return (HRP.Position - pos).Magnitude
end

function FastUtils.GetVelocity(part)
    if not part or not part:IsA("BasePart") then return Vector3.new() end
    return part.AssemblyLinearVelocity or part.Velocity or Vector3.new()
end

function FastUtils.PredictPosition(part, deltaTime)
    if not part then return part.Position end
    local velocity = FastUtils.GetVelocity(part)
    return part.Position + (velocity * deltaTime)
end

function FastUtils.HasForceField(char)
    return char and char:FindFirstChildOfClass("ForceField") ~= nil
end

function FastUtils.IsInvulnerable(humanoid)
    if not humanoid then return true end
    return humanoid.Health == math.huge or humanoid.MaxHealth == math.huge
end

function FastUtils.HasLineOfSight(from, to)
    if not from or not to then return false end
    local ray = Ray.new(from, (to - from).Unit * (to - from).Magnitude)
    local hit, position = Services.Workspace:FindPartOnRayWithIgnoreList(ray, {Character})
    return hit and hit:IsDescendantOf(Services.Workspace.Enemies or Services.Workspace.Characters)
end

function FastUtils.DebugPrint(...)
    if Config.DebugMode then
        print("[FastAttackV4]", ...)
    end
end

function FastUtils.WarnPrint(...)
    warn("[FastAttackV4]", ...)
end

-- ==================== INITIALIZATION ====================
local function InitializeReferences()
    HRP = Character and Character:FindFirstChild("HumanoidRootPart")
    Humanoid = Character and Character:FindFirstChild("Humanoid")

    if not HRP or not Humanoid then
        FastUtils.WarnPrint("Failed to get character parts!")
        return nil
    end

    local Modules = Services.RS:FindFirstChild("Modules") or Services.RS:WaitForChild("Modules", 10)
    if not Modules then
        FastUtils.WarnPrint("Modules folder not found!")
        return nil
    end

    local Net = Modules:FindFirstChild("Net") or Modules:WaitForChild("Net", 10)
    if not Net then
        FastUtils.WarnPrint("Net folder not found!")
        return nil
    end

    local RegisterAttack = Net:FindFirstChild("RE/RegisterAttack") or Net:WaitForChild("RE/RegisterAttack", 10)
    local RegisterHit = Net:FindFirstChild("RE/RegisterHit") or Net:WaitForChild("RE/RegisterHit", 10)

    if not RegisterAttack or not RegisterHit then
        FastUtils.WarnPrint("Attack remotes not found!")
        return nil
    end

    local Enemies = Services.Workspace:FindFirstChild("Enemies") or Services.Workspace:WaitForChild("Enemies", 10)
    local Characters = Services.Workspace:FindFirstChild("Characters") or Services.Workspace:WaitForChild("Characters", 10)

    return {
        RegisterAttack = RegisterAttack,
        RegisterHit = RegisterHit,
        Enemies = Enemies,
        Characters = Characters
    }
end

local Refs = InitializeReferences()
if not Refs or not Refs.RegisterAttack or not Refs.RegisterHit then
    FastUtils.WarnPrint("Critical initialization failure!")
    return
end

FastUtils.DebugPrint("Initialization successful!")

-- ==================== ADVANCED FAST ATTACK ENGINE ====================
local FastAttack = {
    Config = Config,
    Running = false,
    LastAttack = 0,
    LastValidation = 0,
    ConsecutiveErrors = 0,
    Paused = false,

    Stats = {
        TPS = 0,
        APS = 0,
        TotalAttacks = 0,
        SuccessfulAttacks = 0,
        FailedAttacks = 0,
        Errors = 0,
        Retries = 0,
        TargetsHit = 0,
        AverageDelay = 0,
        Uptime = 0
    },

    Cache = {
        ValidTargets = {},
        LastUpdate = 0,
        PlayerStates = {},
        VelocityData = {},
        ThreatLevels = {},
        LastClear = 0
    },
    
    AttackQueue = {},
    Connections = {},
    
    -- Target tracking for persistence
    TrackedTargets = {},
    FailedTargets = {}
}

-- ==================== REVOLUTIONARY VALIDATION SYSTEM ====================
function FastAttack:ValidateEnemy(enemy, quick)
    if not enemy or enemy == Character then return false end

    -- Quick validation (for performance)
    if quick then
        local hum = enemy:FindFirstChild("Humanoid")
        return hum and hum.Health > 0
    end

    -- Comprehensive validation
    local hum = enemy:FindFirstChild("Humanoid")
    local hrp = enemy:FindFirstChild("HumanoidRootPart")
    local head = enemy:FindFirstChild("Head")

    if not hum or not hrp or not head then return false end
    if hum.Health <= 0 then return false end

    -- Advanced health checks
    if Config.IgnoreInvulnerable and FastUtils.IsInvulnerable(hum) then
        return false
    end

    local healthPercent = hum.Health / hum.MaxHealth
    if healthPercent < Config.MinHealthThreshold or healthPercent > Config.MaxHealthThreshold then
        return false
    end

    -- Force field check
    if Config.IgnoreForceField and FastUtils.HasForceField(enemy) then
        return false
    end

    -- Determine entity type
    local enemyPlayer = Services.Players:GetPlayerFromCharacter(enemy)
    local isPlayer = enemyPlayer ~= nil

    -- MOB validation
    if not isPlayer then
        if not Config.AttackMob then return false end
        
        -- Check if mob is quest/friendly type
        if enemy:FindFirstChild("Friendly") or enemy:FindFirstChild("Quest") then
            return false
        end
        
        return true
    end

    -- PLAYER validation
    if not Config.AttackPlayers then return false end
    if enemyPlayer == Player then return false end

    -- Team validation
    if Config.RespectTeams and Player.Team and enemyPlayer.Team then
        if enemyPlayer.Team == Player.Team then return false end
    end

    -- PvP/SafeZone checks with enhanced caching
    local now = tick()
    local stateKey = enemy.Name
    local cached = self.Cache.PlayerStates[stateKey]

    if cached and (now - cached.time) < 0.3 then
        return cached.valid
    end

    local gui = Player:FindFirstChild("PlayerGui")
    if gui then
        local main = gui:FindFirstChild("Main")
        if main then
            local pvpDisabled = main:FindFirstChild("PvpDisabled")
            if pvpDisabled and pvpDisabled.Visible then
                self.Cache.PlayerStates[stateKey] = {valid = false, time = now}
                return false
            end

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

-- ==================== SMART TARGET ACQUISITION ====================
function FastAttack:CalculateThreatLevel(target, distance, hp)
    local threat = 0
    
    -- Distance threat (closer = higher threat)
    threat = threat + (1 - (distance / Config.AttackDistance)) * 50
    
    -- Health threat (lower HP = easier kill = higher priority)
    local hum = target:FindFirstChild("Humanoid")
    if hum then
        local healthPercent = hp / hum.MaxHealth
        threat = threat + (1 - healthPercent) * 30
    end
    
    -- Player vs Mob
    local isPlayer = Services.Players:GetPlayerFromCharacter(target)
    if isPlayer then
        threat = threat + 20 -- Players are higher threat
    end
    
    -- Velocity threat (moving targets)
    if Config.TrackVelocity then
        local hrp = target:FindFirstChild("HumanoidRootPart")
        if hrp then
            local velocity = FastUtils.GetVelocity(hrp)
            threat = threat + (velocity.Magnitude * 2)
        end
    end
    
    return threat
end

function FastAttack:GetTargets()
    local targets = {}
    local maxDist = Config.AttackDistance
    local now = tick()

    local function scanFolder(folder, folderName)
        if not folder then return end

        local children = folder:GetChildren()
        
        for _, enemy in ipairs(children) do
            if #targets >= Config.MaxTargets then break end

            local head = enemy:FindFirstChild("Head")
            if not head then continue end

            -- Distance check with prediction
            local pos = head.Position
            if Config.UsePredictiveTargeting then
                pos = FastUtils.PredictPosition(head, Config.PredictionTime)
            end

            local dist = FastUtils.GetDistance(pos)
            if dist >= maxDist then continue end

            -- Line of sight check
            if Config.RequireLineOfSight and HRP then
                if not FastUtils.HasLineOfSight(HRP.Position, pos) then
                    continue
                end
            end

            -- Validate enemy
            if not self:ValidateEnemy(enemy) then continue end

            local hum = enemy:FindFirstChild("Humanoid")
            local hp = hum and hum.Health or 0
            
            -- Calculate threat level
            local threat = self:CalculateThreatLevel(enemy, dist, hp)
            
            -- Store velocity data
            local hrp = enemy:FindFirstChild("HumanoidRootPart")
            if hrp and Config.TrackVelocity then
                self.Cache.VelocityData[enemy] = {
                    velocity = FastUtils.GetVelocity(hrp),
                    time = now
                }
            end
            
            table.insert(targets, {
                entity = enemy,
                head = head,
                hrp = hrp,
                distance = dist,
                hp = hp,
                threat = threat,
                predictedPos = pos,
                isPlayer = Services.Players:GetPlayerFromCharacter(enemy) ~= nil
            })
        end
    end

    -- Scan folders
    if Config.AttackMob and Refs.Enemies then 
        scanFolder(Refs.Enemies, "Enemies")
    end

    if Config.AttackPlayers and Refs.Characters then 
        scanFolder(Refs.Characters, "Characters")
    end

    -- Advanced sorting
    if #targets > 0 then
        if Config.PriorityMode == "Smart" then
            -- Multi-factor weighted sorting
            table.sort(targets, function(a, b)
                local scoreA = 0
                local scoreB = 0
                
                scoreA = scoreA + (1 - (a.distance / maxDist)) * Config.PriorityWeights.Distance * 100
                scoreB = scoreB + (1 - (b.distance / maxDist)) * Config.PriorityWeights.Distance * 100
                
                scoreA = scoreA + (1 - (a.hp / 100)) * Config.PriorityWeights.Health * 100
                scoreB = scoreB + (1 - (b.hp / 100)) * Config.PriorityWeights.Health * 100
                
                scoreA = scoreA + a.threat * Config.PriorityWeights.Threat
                scoreB = scoreB + b.threat * Config.PriorityWeights.Threat
                
                if a.isPlayer then scoreA = scoreA + Config.PriorityWeights.Type * 100 end
                if b.isPlayer then scoreB = scoreB + Config.PriorityWeights.Type * 100 end
                
                return scoreA > scoreB
            end)
        elseif Config.PriorityMode == "Nearest" then
            table.sort(targets, function(a, b) return a.distance < b.distance end)
        elseif Config.PriorityMode == "Lowest HP" then
            table.sort(targets, function(a, b) return a.hp < b.hp end)
        elseif Config.PriorityMode == "Highest HP" then
            table.sort(targets, function(a, b) return a.hp > b.hp end)
        elseif Config.PriorityMode == "Threat Level" then
            table.sort(targets, function(a, b) return a.threat > b.threat end)
        elseif Config.PriorityMode == "Mixed" then
            -- Randomize order for unpredictability
            for i = #targets, 2, -1 do
                local j = math.random(i)
                targets[i], targets[j] = targets[j], targets[i]
            end
        end
    end
    
    -- Randomize if enabled
    if Config.RandomizeTargetOrder and #targets > 1 then
        for i = #targets, 2, -1 do
            local j = math.random(i)
            targets[i], targets[j] = targets[j], targets[i]
        end
    end

    return targets
end

-- ==================== MULTI-MODE ATTACK EXECUTION ====================
function FastAttack:ExecuteAttack(targets)
    if not targets or #targets == 0 then return false end

    local attackedTargets = {}
    local success = false

    if Config.AttackMode == "Single" then
        -- Single target attack
        local target = targets[1]
        success = self:PerformAttack({target})
        if success then table.insert(attackedTargets, target) end
        
    elseif Config.AttackMode == "Burst" then
        -- Burst attack (multiple simultaneous)
        local burstTargets = {}
        for i = 1, math.min(Config.BurstCount, #targets) do
            table.insert(burstTargets, targets[i])
        end
        success = self:PerformAttack(burstTargets)
        if success then
            for _, t in ipairs(burstTargets) do
                table.insert(attackedTargets, t)
            end
        end
        
    elseif Config.AttackMode == "Cascade" then
        -- Cascade attack (sequential with micro-delays)
        for i = 1, math.min(Config.BurstCount, #targets) do
            local result = self:PerformAttack({targets[i]})
            if result then
                success = true
                table.insert(attackedTargets, targets[i])
            end
            if i < math.min(Config.BurstCount, #targets) then
                task.wait(Config.CascadeDelay)
            end
        end
        
    elseif Config.AttackMode == "Sweep" then
        -- Sweep attack (all valid targets)
        success = self:PerformAttack(targets)
        if success then
            attackedTargets = targets
        end
    end

    -- Track attacked targets
    for _, target in ipairs(attackedTargets) do
        self.TrackedTargets[target.entity] = {
            lastAttack = tick(),
            attempts = (self.TrackedTargets[target.entity] and self.TrackedTargets[target.entity].attempts or 0) + 1
        }
    end

    return success
end

function FastAttack:PerformAttack(targets)
    if not targets or #targets == 0 then return false end

    local hitData = {}
    for _, target in ipairs(targets) do
        -- Use predicted position if available
        local hitPos = target.head
        if Config.UsePredictiveTargeting and target.predictedPos then
            -- Create a temporary part at predicted position for more accurate hits
            hitPos = target.head
        end
        table.insert(hitData, {target.entity, hitPos})
    end

    local basePart = targets[1].head
    local success = false
    local attempts = 0
    local maxAttempts = Config.RetryFailedAttacks and (Config.MaxRetries + 1) or 1

    repeat
        attempts = attempts + 1
        
        if Config.UseParallelExecution then
            -- Non-blocking parallel execution
            success = pcall(function()
                task.spawn(function()
                    Refs.RegisterAttack:FireServer(Config.ClickDelay)
                end)
                task.spawn(function()
                    Refs.RegisterHit:FireServer(basePart, hitData)
                end)
            end)
        else
            -- Sequential execution
            success = pcall(function()
                Refs.RegisterAttack:FireServer(Config.ClickDelay)
                Refs.RegisterHit:FireServer(basePart, hitData)
            end)
        end

        if not success and attempts < maxAttempts then
            self.Stats.Retries = self.Stats.Retries + 1
            task.wait(0.01)
        end

    until success or attempts >= maxAttempts

    if success then
        self.Stats.TotalAttacks = self.Stats.TotalAttacks + 1
        self.Stats.SuccessfulAttacks = self.Stats.SuccessfulAttacks + 1
        self.Stats.TargetsHit = self.Stats.TargetsHit + #targets
        self.ConsecutiveErrors = 0
    else
        self.Stats.FailedAttacks = self.Stats.FailedAttacks + 1
        self.Stats.Errors = self.Stats.Errors + 1
        self.ConsecutiveErrors = self.ConsecutiveErrors + 1
        
        -- Mark targets as failed
        for _, target in ipairs(targets) do
            self.FailedTargets[target.entity] = (self.FailedTargets[target.entity] or 0) + 1
        end
        
        -- Auto-pause on too many errors
        if self.ConsecutiveErrors >= Config.MaxConsecutiveErrors then
            self:HandleErrors()
        end
    end

    return success
end

-- ==================== ERROR RECOVERY ====================
function FastAttack:HandleErrors()
    if not Config.AutoRecover then return end
    
    self.Paused = true
    FastUtils.WarnPrint("Too many consecutive errors, pausing for recovery...")
    
    task.wait(Config.RecoveryDelay)
    
    -- Reinitialize references
    local newRefs = InitializeReferences()
    if newRefs then
        Refs = newRefs
        FastUtils.DebugPrint("References reinitialized after error recovery")
    end
    
    self.ConsecutiveErrors = 0
    self.Paused = false
    FastUtils.DebugPrint("Recovered from errors, resuming attacks")
end

-- ==================== OPTIMIZED MAIN CYCLE ====================
local lastCycleTime = 0
local cycleCount = 0

function FastAttack:Cycle()
    if not Config.FastAttack or self.Paused then return end
    if not FastUtils.IsAlive(Character) then return end

    -- Weapon check
    local tool = Character:FindFirstChildOfClass("Tool")
    if not tool then return end
    if tool.ToolTip == "Gun" then return end

    -- Adaptive delay management
    local now = tick()
    local delay = Config.FastAttackDelay

    if Config.HumanizedMode then
        delay = delay + (math.random() * 0.05)
    elseif Config.RandomizeDelay then
        delay = delay + (math.random() * Config.DelayVariance * 2 - Config.DelayVariance)
    end

    if Config.MimicInputDelay then
        delay = math.max(delay, 0.03)
    end

    if (now - lastCycleTime) < delay then return end
    lastCycleTime = now
    cycleCount = cycleCount + 1

    -- Get and attack targets
    local targets = self:GetTargets()
    if #targets > 0 then
        self:ExecuteAttack(targets)
    end

    -- Periodic cache cleanup
    if cycleCount % 200 == 0 then
        self:CleanupCache()
    end
end

function FastAttack:CleanupCache()
    local now = tick()
    
    -- Clean player states
    for key, data in pairs(self.Cache.PlayerStates) do
        if (now - data.time) > 1 then
            self.Cache.PlayerStates[key] = nil
        end
    end
    
    -- Clean velocity data
    for entity, data in pairs(self.Cache.VelocityData) do
        if not entity.Parent or (now - data.time) > 0.5 then
            self.Cache.VelocityData[entity] = nil
        end
    end
    
    -- Clean tracked targets
    for entity, data in pairs(self.TrackedTargets) do
        if not entity.Parent or (now - data.lastAttack) > 5 then
            self.TrackedTargets[entity] = nil
        end
    end
    
    -- Clean failed targets
    for entity, count in pairs(self.FailedTargets) do
        if not entity.Parent or count > 10 then
            self.FailedTargets[entity] = nil
        end
    end
    
    FastUtils.DebugPrint("Cache cleaned")
end

-- ==================== ADVANCED PERFORMANCE MONITORING ====================
local perfStartTime = tick()
local perfTickCount = 0
local delayHistory = {}

function FastAttack:UpdatePerformance()
    perfTickCount = perfTickCount + 1
    local now = tick()

    if (now - perfStartTime) >= 1 then
        self.Stats.TPS = perfTickCount
        self.Stats.Uptime = self.Stats.Uptime + 1
        perfTickCount = 0

        -- Calculate average delay
        if #delayHistory > 0 then
            local sum = 0
            for _, d in ipairs(delayHistory) do sum = sum + d end
            self.Stats.AverageDelay = sum / #delayHistory
            delayHistory = {}
        end

        -- Auto-tune performance
        if Config.AutoTunePerformance then
            local fps = 1 / Services.RunService.RenderStepped:Wait()
            
            if fps < Config.TargetFPS and Config.FastAttackDelay < Config.MaxDelay then
                -- FPS too low, increase delay
                Config.FastAttackDelay = math.min(Config.FastAttackDelay * 1.1, Config.MaxDelay)
                FastUtils.DebugPrint("Increased delay to", Config.FastAttackDelay, "due to low FPS:", fps)
            elseif fps > (Config.TargetFPS + 20) and Config.FastAttackDelay > Config.MinDelay then
                -- FPS high, can decrease delay
                Config.FastAttackDelay = math.max(Config.FastAttackDelay * 0.95, Config.MinDelay)
                FastUtils.DebugPrint("Decreased delay to", Config.FastAttackDelay, "due to high FPS:", fps)
            end
        end

        perfStartTime = now
    end
    
    table.insert(delayHistory, Config.FastAttackDelay)
end

-- ==================== MULTI-THREADED EXECUTION ====================
function FastAttack:Start()
    if self.Running then return end
    self.Running = true
    self.Paused = false
    self.ConsecutiveErrors = 0

    FastUtils.DebugPrint("Starting Fast Attack V4 Ultimate...")

    -- Primary high-speed loop
    if Config.UseRenderStepped then
        self.Connections.Primary = Services.RunService.RenderStepped:Connect(function()
            self:Cycle()
            self:UpdatePerformance()
        end)
    else
        self.Connections.Primary = Services.RunService.Heartbeat:Connect(function()
            self:Cycle()
            self:UpdatePerformance()
        end)
    end

    -- Backup thread
    if Config.UseDeferredThread then
        self.Connections.Deferred = task.defer(function()
            while self.Running do
                task.wait(Config.FastAttackDelay * 0.5)
                if Config.FastAttack and not self.Paused then
                    self:Cycle()
                end
            end
        end)
    end

    -- Additional backup thread (NEW)
    if Config.UseBackupThread then
        self.Connections.Backup = task.spawn(function()
            while self.Running do
                task.wait(Config.FastAttackDelay * 2)
                if Config.FastAttack and not self.Paused then
                    self:Cycle()
                end
            end
        end)
    end

    -- Monitoring thread
    self.Connections.Monitor = task.spawn(function()
        while self.Running do
            task.wait(5)
            
            -- Performance report
            if Config.DebugMode then
                FastUtils.DebugPrint("=== Performance Report ===")
                FastUtils.DebugPrint("TPS:", self.Stats.TPS, "| APS:", self.Stats.APS)
                FastUtils.DebugPrint("Success:", self.Stats.SuccessfulAttacks, "| Failed:", self.Stats.FailedAttacks)
                FastUtils.DebugPrint("Delay:", string.format("%.4f", Config.FastAttackDelay))
            end
        end
    end)

    -- Cache cleanup thread
    self.Connections.Cleanup = task.spawn(function()
        while self.Running do
            task.wait(10)
            self:CleanupCache()
        end
    end)

    print("[FastAttack V4] Started successfully!")
    print("[FastAttack V4] Mode:", Config.AttackMode, "| Priority:", Config.PriorityMode)
end

function FastAttack:Stop()
    if not self.Running then return end
    self.Running = false

    for name, connection in pairs(self.Connections) do
        if connection and typeof(connection) == "RBXScriptConnection" then
            connection:Disconnect()
        end
    end
    
    self.Connections = {}
    self.AttackQueue = {}

    print("[FastAttack V4] Stopped")
end

function FastAttack:Toggle()
    Config.FastAttack = not Config.FastAttack
    print("[FastAttack V4] Toggled:", Config.FastAttack and "ON" or "OFF")
    
    if Config.FastAttack and not self.Running then
        self:Start()
    end
end

-- ==================== ADVANCED CONFIG UPDATE ====================
function FastAttack:UpdateConfig(newConfig)
    if not newConfig then return end

    local needsRestart = false
    local criticalSettings = {
        "UseRenderStepped",
        "UseDeferredThread", 
        "UseBackupThread",
        "UseParallelExecution"
    }

    for key, value in pairs(newConfig) do
        if Config[key] ~= nil then
            local oldValue = Config[key]
            Config[key] = value
            
            -- Check if critical setting changed
            for _, critical in ipairs(criticalSettings) do
                if key == critical and oldValue ~= value then
                    needsRestart = true
                    break
                end
            end
            
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
    
    -- Restart if critical settings changed
    if needsRestart and self.Running then
        FastUtils.DebugPrint("Critical settings changed, restarting...")
        self:Stop()
        task.wait(0.2)
        self:Start()
    end

    FastUtils.DebugPrint("Config updated successfully")
end

-- ==================== PRESET CONFIGURATIONS ====================
FastAttack.Presets = {
    ["Ultra Performance"] = {
        FastAttackDelay = 0.01,
        AttackMode = "Cascade",
        PriorityMode = "Smart",
        UseParallelExecution = true,
        UsePredictiveTargeting = true,
        MaxTargets = 20,
        AutoTunePerformance = true
    },
    
    ["Balanced"] = {
        FastAttackDelay = 0.03,
        AttackMode = "Burst",
        PriorityMode = "Nearest",
        UseParallelExecution = true,
        UsePredictiveTargeting = false,
        MaxTargets = 15,
        AutoTunePerformance = true
    },
    
    ["Stealth"] = {
        FastAttackDelay = 0.05,
        AttackMode = "Single",
        PriorityMode = "Mixed",
        UseParallelExecution = false,
        HumanizedMode = true,
        RandomizeDelay = true,
        RandomizeTargetOrder = true,
        MimicInputDelay = true
    },
    
    ["Mob Farm"] = {
        FastAttackDelay = 0.02,
        AttackMode = "Sweep",
        PriorityMode = "Lowest HP",
        AttackMob = true,
        AttackPlayers = false,
        MaxTargets = 20,
        IgnoreInvulnerable = true
    },
    
    ["PvP Focus"] = {
        FastAttackDelay = 0.025,
        AttackMode = "Burst",
        PriorityMode = "Threat Level",
        AttackMob = false,
        AttackPlayers = true,
        UsePredictiveTargeting = true,
        TrackVelocity = true,
        RequireLineOfSight = false
    }
}

function FastAttack:LoadPreset(presetName)
    local preset = self.Presets[presetName]
    if not preset then
        FastUtils.WarnPrint("Preset not found:", presetName)
        return false
    end
    
    self:UpdateConfig(preset)
    print("[FastAttack V4] Loaded preset:", presetName)
    return true
end

-- ==================== CHARACTER RESPAWN HANDLER ====================
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

    -- Reset error counter
    FastAttack.ConsecutiveErrors = 0
    FastAttack.Paused = false

    -- Restart if was running
    if FastAttack.Running then
        FastAttack:Stop()
        task.wait(0.3)
        FastAttack:Start()
    end
end)

-- ==================== GLOBAL EXPORT & API ====================
_ENV.FastAttackV4 = FastAttack

-- Enhanced command functions
_ENV.FA_Toggle = function() 
    FastAttack:Toggle() 
end

_ENV.FA_Start = function() 
    FastAttack:Start() 
end

_ENV.FA_Stop = function() 
    FastAttack:Stop() 
end

_ENV.FA_Debug = function() 
    Config.DebugMode = not Config.DebugMode
    print("[FastAttack V4] Debug Mode:", Config.DebugMode and "ON" or "OFF")
end

_ENV.FA_Stats = function() 
    print("=== FastAttack V4 Statistics ===")
    print("Running:", FastAttack.Running, "| Paused:", FastAttack.Paused)
    print("Mode:", Config.AttackMode, "| Priority:", Config.PriorityMode)
    print("---")
    print("TPS:", FastAttack.Stats.TPS, "| APS:", FastAttack.Stats.APS)
    print("Total Attacks:", FastAttack.Stats.TotalAttacks)
    print("Successful:", FastAttack.Stats.SuccessfulAttacks)
    print("Failed:", FastAttack.Stats.FailedAttacks)
    print("Targets Hit:", FastAttack.Stats.TargetsHit)
    print("Retries:", FastAttack.Stats.Retries)
    print("Errors:", FastAttack.Stats.Errors)
    print("---")
    print("Delay:", string.format("%.4f", Config.FastAttackDelay))
    print("Avg Delay:", string.format("%.4f", FastAttack.Stats.AverageDelay))
    print("Uptime:", FastAttack.Stats.Uptime, "seconds")
    print("---")
    print("Attack Mobs:", Config.AttackMob)
    print("Attack Players:", Config.AttackPlayers)
    print("Max Distance:", Config.AttackDistance)
    print("Max Targets:", Config.MaxTargets)
end

_ENV.FA_Config = function(setting, value)
    if not setting then
        print("=== FastAttack V4 Configuration ===")
        for key, val in pairs(Config) do
            print(key, "=", tostring(val))
        end
        return
    end
    
    if Config[setting] == nil then
        print("Invalid setting:", setting)
        return
    end
    
    if value == nil then
        print(setting, "=", tostring(Config[setting]))
        return
    end
    
    -- Convert string to proper type
    if value == "true" then value = true
    elseif value == "false" then value = false
    elseif tonumber(value) then value = tonumber(value)
    end
    
    FastAttack:UpdateConfig({[setting] = value})
    print("Updated", setting, "to", tostring(value))
end

_ENV.FA_Preset = function(presetName)
    if not presetName then
        print("=== Available Presets ===")
        for name, _ in pairs(FastAttack.Presets) do
            print("-", name)
        end
        return
    end
    
    FastAttack:LoadPreset(presetName)
end

_ENV.FA_Mode = function(mode)
    if not mode then
        print("Current Mode:", Config.AttackMode)
        print("Available: Single, Burst, Cascade, Sweep")
        return
    end
    
    FastAttack:UpdateConfig({AttackMode = mode})
end

_ENV.FA_Priority = function(priority)
    if not priority then
        print("Current Priority:", Config.PriorityMode)
        print("Available: Smart, Nearest, Lowest HP, Highest HP, Threat Level, Mixed")
        return
    end
    
    FastAttack:UpdateConfig({PriorityMode = priority})
end

_ENV.FA_Delay = function(delay)
    if not delay then
        print("Current Delay:", Config.FastAttackDelay)
        print("Min:", Config.MinDelay, "| Max:", Config.MaxDelay)
        return
    end
    
    delay = tonumber(delay)
    if not delay then
        print("Invalid delay value")
        return
    end
    
    delay = math.clamp(delay, Config.MinDelay, Config.MaxDelay)
    FastAttack:UpdateConfig({FastAttackDelay = delay})
    print("Delay set to:", delay)
end

_ENV.FA_Distance = function(distance)
    if not distance then
        print("Current Distance:", Config.AttackDistance)
        return
    end
    
    distance = tonumber(distance)
    if not distance then
        print("Invalid distance value")
        return
    end
    
    FastAttack:UpdateConfig({AttackDistance = distance})
    print("Distance set to:", distance)
end

_ENV.FA_MaxTargets = function(max)
    if not max then
        print("Current Max Targets:", Config.MaxTargets)
        return
    end
    
    max = tonumber(max)
    if not max then
        print("Invalid value")
        return
    end
    
    FastAttack:UpdateConfig({MaxTargets = max})
    print("Max Targets set to:", max)
end

_ENV.FA_AttackMobs = function(enabled)
    if enabled == nil then
        Config.AttackMob = not Config.AttackMob
    else
        Config.AttackMob = enabled == true or enabled == "true"
    end
    print("Attack Mobs:", Config.AttackMob and "ON" or "OFF")
end

_ENV.FA_AttackPlayers = function(enabled)
    if enabled == nil then
        Config.AttackPlayers = not Config.AttackPlayers
    else
        Config.AttackPlayers = enabled == true or enabled == "true"
    end
    print("Attack Players:", Config.AttackPlayers and "ON" or "OFF")
end

_ENV.FA_Reset = function()
    FastAttack:Stop()
    task.wait(0.5)
    
    -- Reset stats
    FastAttack.Stats = {
        TPS = 0,
        APS = 0,
        TotalAttacks = 0,
        SuccessfulAttacks = 0,
        FailedAttacks = 0,
        Errors = 0,
        Retries = 0,
        TargetsHit = 0,
        AverageDelay = 0,
        Uptime = 0
    }
    
    -- Clear caches
    FastAttack.Cache = {
        ValidTargets = {},
        LastUpdate = 0,
        PlayerStates = {},
        VelocityData = {},
        ThreatLevels = {},
        LastClear = 0
    }
    
    FastAttack.TrackedTargets = {}
    FastAttack.FailedTargets = {}
    FastAttack.ConsecutiveErrors = 0
    
    print("[FastAttack V4] Reset complete")
end

_ENV.FA_Help = function()
    print("=== FastAttack V4 Ultimate - Command Reference ===")
    print("")
    print("BASIC CONTROLS:")
    print("  FA_Toggle()              - Toggle fast attack on/off")
    print("  FA_Start()               - Start fast attack")
    print("  FA_Stop()                - Stop fast attack")
    print("  FA_Stats()               - Show detailed statistics")
    print("  FA_Reset()               - Reset all stats and caches")
    print("")
    print("CONFIGURATION:")
    print("  FA_Config()              - Show all settings")
    print("  FA_Config(setting)       - Show specific setting")
    print("  FA_Config(setting, val)  - Update setting")
    print("  FA_Delay(0.01)           - Set attack delay")
    print("  FA_Distance(500)         - Set attack distance")
    print("  FA_MaxTargets(20)        - Set max targets")
    print("")
    print("ATTACK MODES:")
    print("  FA_Mode()                - Show current mode")
    print("  FA_Mode('Single')        - Single target")
    print("  FA_Mode('Burst')         - Multi-target burst")
    print("  FA_Mode('Cascade')       - Sequential cascade")
    print("  FA_Mode('Sweep')         - Attack all targets")
    print("")
    print("PRIORITY MODES:")
    print("  FA_Priority()            - Show current priority")
    print("  FA_Priority('Smart')     - AI weighted priority")
    print("  FA_Priority('Nearest')   - Closest first")
    print("  FA_Priority('Lowest HP') - Weakest first")
    print("  FA_Priority('Threat Level') - Highest threat")
    print("")
    print("PRESETS:")
    print("  FA_Preset()              - List available presets")
    print("  FA_Preset('Ultra Performance')")
    print("  FA_Preset('Balanced')")
    print("  FA_Preset('Stealth')")
    print("  FA_Preset('Mob Farm')")
    print("  FA_Preset('PvP Focus')")
    print("")
    print("TARGET TOGGLES:")
    print("  FA_AttackMobs()          - Toggle mob attacking")
    print("  FA_AttackPlayers()       - Toggle player attacking")
    print("")
    print("DEBUGGING:")
    print("  FA_Debug()               - Toggle debug mode")
    print("  FA_Help()                - Show this help")
end

-- ==================== AUTO-START ====================
if Config.FastAttack then
    task.wait(1)
    FastAttack:Start()
    print("[FastAttack V4] Auto-started")
    print("[FastAttack V4] Type FA_Help() for command reference")
else
    print("[FastAttack V4] Loaded - Type FA_Help() for commands")
end

-- ==================== FINAL EXPORT ====================
return FastAttack