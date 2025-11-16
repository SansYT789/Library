-- Enhanced Fast Attack System v2.0
-- Advanced ghost mob detection and optimized attack validation

local _ENV = (getgenv or getrenv or getfenv)()

-- ==================== CONFIGURATION ====================
local Config = {
    FastAttack = false,
    AttackNearest = true,
    AttackMob = true,
    AttackPlayers = false,

    -- Performance Settings
    FastAttackDelay = 0.08,
    ClickDelay = 0,
    AttackDistance = 2000,
    MaxTargets = 8,

    -- Advanced Options
    PriorityMode = "Nearest", -- "Nearest", "Lowest HP", "Highest HP"
    UseSmartDelay = true,
    PreemptiveAttack = false, -- Disabled for better stability
    CacheDuration = 0.05,

    -- Ghost Mob Detection
    EnableGhostDetection = true,
    GhostCheckInterval = 4, -- Check every 4 seconds (increased)
    GhostHealthThreshold = 1, -- If health doesn't drop by 1% in interval (more lenient)
    
    -- Performance Optimization
    UseRenderStepped = false, -- Use Heartbeat for stability
    SkipDeadCheck = false,
    BatchAttacks = true,
    VerifyHitRegistration = true, -- Ensure hits register
}

-- ==================== SERVICES ====================
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()

-- ==================== UTILITY FUNCTIONS ====================
local function SafeWaitForChild(parent, childName, timeout)
    if not parent then return nil end
    local success, result = pcall(function()
        return parent:WaitForChild(childName, timeout or 5)
    end)
    if not success or not result then 
        warn("Missing child: " .. childName) 
        return nil
    end
    return result
end

-- ==================== WORKSPACE REFERENCES ====================
local Remotes = SafeWaitForChild(RS, "Remotes")
if not Remotes then 
    warn("Remotes not found! Fast Attack cannot initialize.") 
    return 
end

local Modules = SafeWaitForChild(RS, "Modules")
local Net = Modules and SafeWaitForChild(Modules, "Net")

if not Net then
    warn("Net module not found! Fast Attack cannot initialize.")
    return
end

local RegisterAttack = SafeWaitForChild(Net, "RE/RegisterAttack")
local RegisterHit = SafeWaitForChild(Net, "RE/RegisterHit")

if not RegisterAttack or not RegisterHit then
    warn("Attack remotes not found! Fast Attack cannot initialize.")
    return
end

local Enemies = workspace:FindFirstChild("Enemies")
local Characters = workspace:FindFirstChild("Characters")

-- ==================== FAST ATTACK MODULE ====================
if _ENV.FastAttackSkibidi then 
    local existing = _ENV.FastAttackSkibidi
    existing.Config = Config
    return existing
end

local FastAttack = {
    Config = Config,
    Cache = {
        Enemies = {},
        LastUpdate = 0,
        PlayerStates = {},
        GhostMobs = {} -- Track ghost mobs
    },
    Stats = {
        AttacksPerSecond = 0,
        LastAttackTime = 0,
        TotalAttacks = 0,
        GhostsDetected = 0
    },
    Running = false,
    Connection = nil
}

-- ==================== PERFORMANCE OPTIMIZATIONS ====================
local sethiddenproperty = sethiddenproperty or function(...) return ... end

local function IsAlive(character)
    if not character then return false end
    local hum = character:FindFirstChild("Humanoid")
    return hum and hum.Health > 0
end

local function GetDistance(pos)
    if not char or not char:FindFirstChild("HumanoidRootPart") then return math.huge end
    return (char.HumanoidRootPart.Position - pos).Magnitude
end

-- ==================== GHOST MOB DETECTION ====================
function FastAttack:InitGhostTracking(enemy)
    if not self.Config.EnableGhostDetection then return end
    if not enemy or not enemy:FindFirstChild("Humanoid") then return end
    
    local enemyId = enemy.Name .. "_" .. tostring(enemy:GetDebugId())
    
    self.Cache.GhostMobs[enemyId] = {
        lastHealth = enemy.Humanoid.Health,
        lastCheckTime = tick(),
        attackCount = 0,
        isGhost = false,
        enemy = enemy
    }
end

function FastAttack:UpdateGhostTracking(enemy)
    if not self.Config.EnableGhostDetection then return false end
    if not enemy or not enemy:FindFirstChild("Humanoid") then return true end
    
    local enemyId = enemy.Name .. "_" .. tostring(enemy:GetDebugId())
    local ghostData = self.Cache.GhostMobs[enemyId]
    
    if not ghostData then
        self:InitGhostTracking(enemy)
        return false
    end
    
    -- Check if already marked as ghost
    if ghostData.isGhost then return true end
    
    local currentTime = tick()
    local timeDiff = currentTime - ghostData.lastCheckTime
    
    -- Update attack count
    ghostData.attackCount = ghostData.attackCount + 1
    
    -- Check every interval
    if timeDiff >= self.Config.GhostCheckInterval then
        local currentHealth = enemy.Humanoid.Health
        local healthDrop = ghostData.lastHealth - currentHealth
        local healthDropPercent = (healthDrop / enemy.Humanoid.MaxHealth) * 100
        
        -- If attacked multiple times but health barely dropped, it's a ghost
        if ghostData.attackCount > 8 and healthDropPercent < self.Config.GhostHealthThreshold then
            ghostData.isGhost = true
            self.Stats.GhostsDetected = self.Stats.GhostsDetected + 1
            warn("Ghost mob detected: " .. enemy.Name .. " (ID: " .. enemyId .. ")")
            return true
        end
        
        -- Reset tracking for next interval
        ghostData.lastHealth = currentHealth
        ghostData.lastCheckTime = currentTime
        ghostData.attackCount = 0
    end
    
    return false
end

function FastAttack:IsGhostMob(enemy)
    if not self.Config.EnableGhostDetection then return false end
    if not enemy then return false end
    
    local enemyId = enemy.Name .. "_" .. tostring(enemy:GetDebugId())
    local ghostData = self.Cache.GhostMobs[enemyId]
    
    return ghostData and ghostData.isGhost or false
end

function FastAttack:CleanGhostCache()
    -- Clean up ghost cache periodically
    local currentTime = tick()
    local toRemove = {}
    
    for enemyId, data in pairs(self.Cache.GhostMobs) do
        -- Check if enemy still exists
        local enemyExists = data.enemy and data.enemy:IsDescendantOf(workspace)
        
        -- Remove if: enemy deleted, or stale data (30s+), or ghost but enemy gone
        if not enemyExists or (currentTime - data.lastCheckTime > 30) or (data.isGhost and not enemyExists) then
            table.insert(toRemove, enemyId)
        end
    end
    
    for _, id in ipairs(toRemove) do
        self.Cache.GhostMobs[id] = nil
    end
end

-- ==================== ENHANCED ENEMY VALIDATION ====================
function FastAttack:IsValidEnemy(enemy)
    if not enemy or enemy == char then return false end
    
    -- Verify enemy still exists in workspace
    if not enemy:IsDescendantOf(workspace) then return false end
    
    local hum = enemy:FindFirstChild("Humanoid")
    local hrp = enemy:FindFirstChild("HumanoidRootPart")
    
    if not hum or not hrp then return false end
    if hum.Health <= 0 or hum.Health > hum.MaxHealth then return false end
    
    -- Check if it's a ghost mob AFTER basic validation
    if self:IsGhostMob(enemy) then return false end
    
    -- Additional health verification - freshly spawned mobs are OK
    if hum.Health >= hum.MaxHealth * 0.95 then
        -- Fresh spawn, initialize tracking
        if not self.Cache.GhostMobs[enemy.Name .. "_" .. tostring(enemy:GetDebugId())] then
            self:InitGhostTracking(enemy)
        end
    end

    local enemyPlayer = Players:GetPlayerFromCharacter(enemy)
    local isPlayer = enemyPlayer ~= nil

    -- MOB validation
    if not isPlayer then
        if not self.Config.AttackMob then return false end
        
        -- Additional mob checks
        if not enemy.Parent then return false end
        
        -- Check if mob has proper name (not empty or weird)
        if enemy.Name == "" or #enemy.Name < 2 then return false end
        
        return true
    end

    -- PLAYER validation
    if not self.Config.AttackPlayers then return false end

    local enemyChar = Characters and Characters:FindFirstChild(enemy.Name)
    if not enemyChar then return false end

    -- Team check
    if enemyPlayer and enemyPlayer.Team and player.Team and enemyPlayer.Team == player.Team then return false end

    -- Cache player GUI checks with shorter duration
    local cacheKey = enemy.Name
    if self.Cache.PlayerStates[cacheKey] and 
       tick() - self.Cache.PlayerStates[cacheKey].time < 0.5 then
        return self.Cache.PlayerStates[cacheKey].valid
    end

    local gui = player:FindFirstChild("PlayerGui")
    if gui and gui:FindFirstChild("Main") then
        local mainGui = gui.Main

        -- PvP Disabled check
        if mainGui:FindFirstChild("PvpDisabled") and mainGui.PvpDisabled.Visible then
            self.Cache.PlayerStates[cacheKey] = {valid = false, time = tick()}
            return false
        end

        -- SafeZone check
        if mainGui:FindFirstChild("BottomHUDList") then
            local safeZone = mainGui.BottomHUDList:FindFirstChild("SafeZone")
            if safeZone and safeZone.Visible then
                self.Cache.PlayerStates[cacheKey] = {valid = false, time = tick()}
                return false
            end
        end
    end

    self.Cache.PlayerStates[cacheKey] = {valid = true, time = tick()}
    return true
end

-- ==================== OPTIMIZED ENEMY GATHERING ====================
function FastAttack:GatherEnemies()
    local enemies = {}
    local maxDist = self.Config.AttackDistance
    
    if not char or not char:FindFirstChild("HumanoidRootPart") then return enemies end

    local function processFolder(folder)
        if not folder then return end
        
        for _, enemy in ipairs(folder:GetChildren()) do
            if #enemies >= self.Config.MaxTargets then break end

            local head = enemy:FindFirstChild("Head")
            local hrp = enemy:FindFirstChild("HumanoidRootPart")
            
            if head and hrp then
                local dist = GetDistance(hrp.Position)
                
                if dist < maxDist and self:IsValidEnemy(enemy) then
                    local hum = enemy:FindFirstChild("Humanoid")
                    
                    table.insert(enemies, {
                        enemy = enemy,
                        head = head,
                        hrp = hrp,
                        distance = dist,
                        health = hum and hum.Health or 0
                    })
                end
            end
        end
    end

    if self.Config.AttackMob and Enemies then
        processFolder(Enemies)
    end

    if self.Config.AttackPlayers and Characters then
        processFolder(Characters)
    end

    return enemies
end

-- ==================== PRIORITY SORTING ====================
function FastAttack:SortEnemies(enemies)
    if self.Config.PriorityMode == "Nearest" then
        table.sort(enemies, function(a, b) return a.distance < b.distance end)
    elseif self.Config.PriorityMode == "Lowest HP" then
        table.sort(enemies, function(a, b) return a.health < b.health end)
    elseif self.Config.PriorityMode == "Highest HP" then
        table.sort(enemies, function(a, b) return a.health > b.health end)
    end
    return enemies
end

-- ==================== ATTACK EXECUTION ====================
function FastAttack:ExecuteAttack(enemies)
    if #enemies == 0 then return false end
    if not RegisterAttack or not RegisterHit then return false end

    -- Double-check primary target is still valid
    local primaryTarget = enemies[1]
    if not primaryTarget.enemy or not primaryTarget.enemy:IsDescendantOf(workspace) then
        return false
    end

    local attackData = {}
    
    -- Build attack data with validation
    for i, data in ipairs(enemies) do
        -- Verify enemy still exists and is valid
        if data.enemy and data.enemy:IsDescendantOf(workspace) and data.head then
            local hum = data.enemy:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                table.insert(attackData, {data.enemy, data.head})
                
                -- Update ghost tracking
                if self.Config.EnableGhostDetection then
                    self:UpdateGhostTracking(data.enemy)
                end
            end
        end
    end
    
    -- Must have at least 1 valid target
    if #attackData == 0 then return false end

    -- Execute attack with error handling
    local success, err = pcall(function()
        RegisterAttack:FireServer(self.Config.ClickDelay)
        RegisterHit:FireServer(primaryTarget.head, attackData)
    end)
    
    if not success then
        warn("Attack execution failed: " .. tostring(err))
        return false
    end

    -- Update stats
    self.Stats.TotalAttacks = self.Stats.TotalAttacks + 1
    self.Stats.LastAttackTime = tick()

    return true
end

-- ==================== MAIN ATTACK LOOP ====================
function FastAttack:AttackCycle()
    if not self.Config.FastAttack then return end
    if not char or not IsAlive(char) then return end

    -- Check if weapon is equipped
    local equipped = char:FindFirstChildOfClass("Tool")
    if not equipped then return end
    
    -- Skip guns
    if equipped.ToolTip == "Gun" or equipped.Name:lower():find("gun") then return end

    -- Gather and sort enemies
    local enemies = self:GatherEnemies()
    if #enemies == 0 then return end

    enemies = self:SortEnemies(enemies)

    -- Execute attack
    self:ExecuteAttack(enemies)
end

-- ==================== ADAPTIVE DELAY SYSTEM ====================
function FastAttack:GetAdaptiveDelay()
    if not self.Config.UseSmartDelay then
        return self.Config.FastAttackDelay
    end

    local ping = player:GetNetworkPing()
    local baseDelay = self.Config.FastAttackDelay

    -- Adjust delay based on ping
    if ping > 0.3 then
        return baseDelay * 2
    elseif ping > 0.2 then
        return baseDelay * 1.5
    elseif ping > 0.1 then
        return baseDelay * 1.2
    else
        return baseDelay * 0.9
    end
end

-- ==================== AUTO-START SYSTEM ====================
function FastAttack:Start()
    if self.Running then return end
    self.Running = true
    
    print("Fast Attack System Started")

    -- Main attack loop using Heartbeat for stability
    self.Connection = RunService.Heartbeat:Connect(function()
        if self.Config.FastAttack then
            pcall(function()
                self:AttackCycle()
            end)
        end
    end)

    -- Backup loop with adaptive delay
    task.spawn(function()
        while self.Running do
            local delay = self:GetAdaptiveDelay()
            task.wait(delay)
            
            if self.Config.FastAttack then
                pcall(function()
                    self:AttackCycle()
                end)
            end
        end
    end)
    
    -- Ghost cache cleanup loop
    if self.Config.EnableGhostDetection then
        task.spawn(function()
            while self.Running do
                task.wait(15)
                self:CleanGhostCache()
            end
        end)
    end
end

function FastAttack:Stop()
    self.Running = false
    print("Fast Attack System Stopped")
    
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
end

-- ==================== CONFIGURATION UPDATE ====================
function FastAttack:UpdateConfig(newConfig)
    for key, value in pairs(newConfig) do
        if self.Config[key] ~= nil then
            self.Config[key] = value
        end
    end

    -- Restart if needed
    if self.Running then
        self:Stop()
        task.wait(0.2)
        self:Start()
    end
end

-- ==================== DEBUG INFO ====================
function FastAttack:GetDebugInfo()
    return {
        Running = self.Running,
        TotalAttacks = self.Stats.TotalAttacks,
        GhostsDetected = self.Stats.GhostsDetected,
        CachedGhosts = #self.Cache.GhostMobs,
        LastAttack = self.Stats.LastAttackTime,
        Config = self.Config
    }
end

-- ==================== CHARACTER RESPAWN HANDLER ====================
player.CharacterAdded:Connect(function(newChar)
    char = newChar
    task.wait(1.5)
    
    if FastAttack.Running then
        FastAttack:Stop()
        task.wait(0.5)
        FastAttack:Start()
    end
end)

-- ==================== WORKSPACE MONITORING ====================
if not Enemies then
    workspace.ChildAdded:Connect(function(child)
        if child.Name == "Enemies" then
            Enemies = child
        end
    end)
end

if not Characters then
    workspace.ChildAdded:Connect(function(child)
        if child.Name == "Characters" then
            Characters = child
        end
    end)
end

-- ==================== AUTO-START ====================
_ENV.FastAttackSkibidi = FastAttack

if Config.FastAttack then
    task.wait(1.5)
    FastAttack:Start()
end

return FastAttack