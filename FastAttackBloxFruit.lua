-- Enhanced Fast Attack System with Advanced Configuration
-- Optimized for maximum performance and reaction time

local _ENV = (getgenv or getrenv or getfenv)()

-- ==================== CONFIGURATION ====================
local Config = {
    FastAttack = false,
    AttackNearest = true,
    AttackMob = true,
    AttackPlayers = false,

    -- Performance Settings
    FastAttackDelay = 0.1, -- Reduced from default
    ClickDelay = 0,
    AttackDistance = 2000,
    MaxTargets = 10, -- Limit targets per attack for performance

    -- Advanced Options
    PriorityMode = "Nearest", -- "Nearest", "Lowest HP", "Highest HP"
    UseSmartDelay = true, -- Adaptive delay based on ping
    PreemptiveAttack = true, -- Attack before full validation
    CacheDuration = 0.1, -- Cache enemy positions

    -- Performance Optimization
    UseRenderStepped = true, -- Use RenderStepped for faster reactions
    SkipDeadCheck = true, -- Skip extra checks on dead enemies
    BatchAttacks = true, -- Send attacks in batches
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
if not Remotes then warn("Remotes not found!") return end

local Modules = SafeWaitForChild(RS, "Modules")
local Net = SafeWaitForChild(Modules, "Net")

local RegisterAttack = SafeWaitForChild(Net, "RE/RegisterAttack")
local RegisterHit = SafeWaitForChild(Net, "RE/RegisterHit")

local Enemies = SafeWaitForChild(workspace, "Enemies")
local Characters = SafeWaitForChild(workspace, "Characters")

-- ==================== FAST ATTACK MODULE ====================
if _ENV.FastAttackSkibidi then 
    -- Update existing instance
    local existing = _ENV.FastAttackSkibidi
    existing.Config = Config
    return existing
end

local FastAttack = {
    Config = Config,
    Cache = {
        Enemies = {},
        LastUpdate = 0,
        PlayerStates = {}
    },
    Stats = {
        AttacksPerSecond = 0,
        LastAttackTime = 0,
        TotalAttacks = 0
    }
}

-- ==================== PERFORMANCE OPTIMIZATIONS ====================
local sethiddenproperty = sethiddenproperty or function(...) return ... end
local IsAlive = function(character)
    if not character then return false end
    local hum = character:FindFirstChild("Humanoid")
    return hum and hum.Health > 0
end

local GetDistance = function(pos)
    if not char or not char:FindFirstChild("HumanoidRootPart") then return math.huge end
    return (char.HumanoidRootPart.Position - pos).Magnitude
end

-- ==================== SMART CACHING SYSTEM ====================
function FastAttack:UpdateCache()
    local currentTime = tick()
    if currentTime - self.Cache.LastUpdate < self.Config.CacheDuration then
        return self.Cache.Enemies
    end

    self.Cache.Enemies = {}
    self.Cache.LastUpdate = currentTime
    return self.Cache.Enemies
end

-- ==================== ENHANCED ENEMY VALIDATION ====================
function FastAttack:IsValidEnemy(enemy)
    if not enemy or enemy == char then return false end

    -- Quick dead check
    if self.Config.SkipDeadCheck then
        if not enemy:FindFirstChild("Humanoid") then return false end
    else
        if not IsAlive(enemy) then return false end
    end

    local enemyPlayer = Players:FindFirstChild(enemy.Name)
    local isPlayer = enemyPlayer ~= nil

    -- MOB validation
    if not isPlayer then
        if not self.Config.AttackMob then return false end
        local hum = enemy:FindFirstChild("Humanoid")
        local hrp = enemy:FindFirstChild("HumanoidRootPart")
        return hum and hrp and hum.Health > 0
    end

    -- PLAYER validation
    if not self.Config.AttackPlayers then return false end

    local enemyChar = Characters:FindFirstChild(enemy.Name)
    if not enemyChar then return false end

    local enemyHrp = enemyChar:FindFirstChild("HumanoidRootPart")
    local enemyHum = enemyChar:FindFirstChild("Humanoid")
    if not enemyHrp or not enemyHum or enemyHum.Health <= 0 then return false end

    -- Team check
    if enemyPlayer.Team == player.Team then return false end

    -- Cache player GUI checks
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

    local function processFolder(folder)
        for _, enemy in ipairs(folder:GetChildren()) do
            if #enemies >= self.Config.MaxTargets then break end

            local head = enemy:FindFirstChild("Head")
            if head then
                local dist = GetDistance(head.Position)
                if dist < maxDist and self:IsValidEnemy(enemy) then
                    table.insert(enemies, {
                        enemy = enemy,
                        head = head,
                        distance = dist,
                        health = enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health or 0
                    })
                end
            end
        end
    end

    if self.Config.AttackMob then
        processFolder(Enemies)
    end

    if self.Config.AttackPlayers then
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

    local attackData = {}
    local basePart = enemies[1].head

    for i, data in ipairs(enemies) do
        table.insert(attackData, {data.enemy, data.head})
    end

    -- Preemptive attack without waiting
    if self.Config.PreemptiveAttack then
        pcall(function()
            RegisterAttack:FireServer(self.Config.ClickDelay)
            RegisterHit:FireServer(basePart, attackData)
        end)
    else
        local success = pcall(function()
            RegisterAttack:FireServer(self.Config.ClickDelay)
            RegisterHit:FireServer(basePart, attackData)
        end)
        if not success then return false end
    end

    -- Update stats
    self.Stats.TotalAttacks = self.Stats.TotalAttacks + 1
    self.Stats.LastAttackTime = tick()

    return true
end

-- ==================== MAIN ATTACK LOOP ====================
function FastAttack:AttackCycle()
    if not self.Config.FastAttack then return end

    -- Check if weapon is equipped
    local equipped = IsAlive(char) and char:FindFirstChildOfClass("Tool")
    if not equipped or equipped.ToolTip == "Gun" then return end

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
    if ping > 0.2 then
        return baseDelay * 1.5
    elseif ping > 0.1 then
        return baseDelay * 1.2
    else
        return baseDelay
    end
end

-- ==================== AUTO-START SYSTEM ====================
function FastAttack:Start()
    if self.Running then return end
    self.Running = true

    local connection
    if self.Config.UseRenderStepped then
        -- Fastest possible updates
        connection = RunService.RenderStepped:Connect(function()
            if self.Config.FastAttack then
                self:AttackCycle()
            end
        end)
    else
        -- Standard heartbeat
        connection = RunService.Heartbeat:Connect(function()
            if self.Config.FastAttack then
                self:AttackCycle()
            end
        end)
    end

    self.Connection = connection

    -- Backup loop with adaptive delay
    spawn(function()
        while self.Running do
            local delay = self:GetAdaptiveDelay()
            task.wait(delay)
            if self.Config.FastAttack then
                self:AttackCycle()
            end
        end
    end)
end

function FastAttack:Stop()
    self.Running = false
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
        task.wait(0.1)
        self:Start()
    end
end

-- ==================== CHARACTER RESPAWN HANDLER ====================
player.CharacterAdded:Connect(function(newChar)
    char = newChar
    task.wait(1)
    if FastAttack.Running then
        FastAttack:Stop()
        task.wait(0.5)
        FastAttack:Start()
    end
end)

-- ==================== AUTO-START ====================
_ENV.FastAttackSkibidi = FastAttack

if Config.FastAttack then
    task.wait(1)
    FastAttack:Start()
end

return FastAttack