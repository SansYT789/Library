local _ENV = getgenv and getgenv() or getfenv(2)

local Config = {
    Enabled = true,
    AttackMobs = true,
    AttackPlayers = true,
    
    -- Performance Settings
    AttackDistance = 65,
    MaxTargets = 25,
    AttackCooldown = 0,
    
    -- Combat Settings
    UseAdvancedHit = true,
    ComboMode = true,
    MaxCombo = 4,
    ComboResetTime = 0.3,
    
    -- Targeting Priority
    PrioritizeClosest = true,
    IgnoreBoats = true,
    IgnoreForceField = true,
    RespectTeams = true,
    
    -- Ghost Detection (Anti-Stuck) - ADJUSTED
    GhostDetection = true,
    GhostTimeout = 15, -- Increased from 10
    GhostRetryAttempts = 8, -- Increased from 5
    
    -- Hitbox Optimization
    HitboxLimbs = {
        "RightLowerArm", "RightUpperArm", "LeftLowerArm", "LeftUpperArm",
        "RightHand", "LeftHand", "Head", "UpperTorso"
    },
    
    -- Gun Settings
    AutoShootGuns = true,
    GunRange = 120,
    SpecialShoots = {["Skull Guitar"] = "TAP", ["Bazooka"] = "Position", ["Cannon"] = "Position", ["Dragonstorm"] = "Overheat"},
    
    -- Reliability Settings (NEW)
    AutoRestart = true, -- Auto-restart if stopped
    RestartDelay = 2, -- Seconds before auto-restart
    SkipStunCheck = false, -- Skip stun checks (risky but more reliable)
    SkipBusyCheck = false, -- Skip busy checks (risky but more reliable)
    
    DebugMode = false
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")

local Player = Players.LocalPlayer
local Character, HRP, Humanoid

local Remotes = {}
local AdvancedFunctions = {}

-- Health monitor to detect death/respawn
local HealthMonitor = {
    LastHealth = 100,
    IsDead = false
}

local function DebugLog(...)
    if Config.DebugMode then
        print("[FastAttack Debug]", ...)
    end
end

local function InitializeRemotes()
    local success = pcall(function()
        local Modules = ReplicatedStorage:WaitForChild("Modules", 10)
        local Net = Modules:WaitForChild("Net", 10)
        
        Remotes.RegisterAttack = Net:WaitForChild("RE/RegisterAttack", 10)
        Remotes.RegisterHit = Net:WaitForChild("RE/RegisterHit", 10)
        Remotes.ShootGunEvent = Net:FindFirstChild("RE/ShootGunEvent")
        Remotes.Modules = Modules
        
        pcall(function()
            AdvancedFunctions.CombatFlags = require(Modules.Flags).COMBAT_REMOTE_THREAD
        end)
        
        pcall(function()
            local LocalScript = Player:WaitForChild("PlayerScripts"):FindFirstChildOfClass("LocalScript")
            if LocalScript and getsenv then
                AdvancedFunctions.HitFunction = getsenv(LocalScript)._G.SendHitsToServer
            end
        end)
        
        pcall(function()
            Remotes.GunValidator = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Validator2")
            local CombatController = require(ReplicatedStorage.Controllers.CombatController)
            AdvancedFunctions.ShootFunction = getupvalue(CombatController.Attack, 9)
        end)
    end)
    
    DebugLog("Remotes initialized:", success)
    return success
end

local function InitializeCharacter()
    Character = Player.Character or Player.CharacterAdded:Wait()
    HRP = Character:WaitForChild("HumanoidRootPart", 5)
    Humanoid = Character:WaitForChild("Humanoid", 5)
    
    -- Reset health monitor
    if Humanoid then
        HealthMonitor.LastHealth = Humanoid.Health
        HealthMonitor.IsDead = false
    end
    
    DebugLog("Character initialized:", HRP ~= nil, Humanoid ~= nil)
    return HRP and Humanoid
end

local GhostTracker = {}
local LastCleanup = 0

local function IsGhostEnemy(enemy)
    if not Config.GhostDetection then return false end
    
    local track = GhostTracker[enemy]
    if not track then
        GhostTracker[enemy] = {
            firstSeen = tick(),
            attempts = 0,
            lastHealth = enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health or 0
        }
        return false
    end
    
    local currentHealth = enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health or 0
    local timeSinceFirst = tick() - track.firstSeen
    
    -- If health decreased, reset tracking (not a ghost)
    if currentHealth < track.lastHealth - 0.1 then -- Small threshold for floating point
        track.lastHealth = currentHealth
        track.firstSeen = tick()
        track.attempts = 0
        return false
    end
    
    track.lastHealth = currentHealth
    
    -- More lenient ghost detection
    if timeSinceFirst > Config.GhostTimeout and track.attempts > Config.GhostRetryAttempts then
        DebugLog("Ghost detected:", enemy.Name)
        return true
    end
    
    track.attempts = track.attempts + 1
    return false
end

local function CleanGhostTracker()
    local now = tick()
    if (now - LastCleanup) < 10 then return end
    
    for enemy, _ in pairs(GhostTracker) do
        if not enemy or not enemy.Parent then
            GhostTracker[enemy] = nil
        end
    end
    LastCleanup = now
end

local function IsEntityAlive(entity)
    if not entity or not entity.Parent then return false end
    local humanoid = entity:FindFirstChild("Humanoid")
    return humanoid and humanoid.Health > 0
end

local function CanAttack()
    if not Character or not Humanoid or not HRP then 
        DebugLog("CanAttack: Missing character components")
        return false 
    end
    
    if not Character.Parent then
        DebugLog("CanAttack: Character not in workspace")
        return false
    end
    
    local tool = Character:FindFirstChildOfClass("Tool")
    if not tool then 
        DebugLog("CanAttack: No tool equipped")
        return false 
    end
    
    -- Skip stun/busy checks if configured (more aggressive attacking)
    if not Config.SkipStunCheck then
        local stun = Character:FindFirstChild("Stun")
        if stun and stun.Value > 0 then
            DebugLog("CanAttack: Stunned")
            return false
        end
    end
    
    if not Config.SkipBusyCheck then
        local busy = Character:FindFirstChild("Busy")
        if busy and busy.Value then
            DebugLog("CanAttack: Busy")
            return false
        end
    end
    
    -- More lenient sitting check
    if Humanoid.Sit then
        local tooltip = tool.ToolTip
        if tooltip ~= "Sword" and tooltip ~= "Melee" and tooltip ~= "Blox Fruit" and tooltip ~= "Gun" then
            DebugLog("CanAttack: Invalid tool while sitting")
            return false
        end
    end
    
    return true
end

local function IsInSafeZone()
    if not Config.IgnoreForceField then return false end
    
    local gui = Player:FindFirstChild("PlayerGui")
    if not gui then return false end
    
    local main = gui:FindFirstChild("Main")
    if not main then return false end
    
    local bottomHUD = main:FindFirstChild("BottomHUDList")
    if bottomHUD then
        local safeZone = bottomHUD:FindFirstChild("SafeZone")
        if safeZone and safeZone.Visible then return true end
    end
    
    local pvpDisabled = main:FindFirstChild("PvpDisabled")
    if pvpDisabled and pvpDisabled.Visible then return true end
    
    return false
end

local function GetOptimalHitbox(enemy)
    for i = 1, 3 do
        local limbName = Config.HitboxLimbs[math.random(#Config.HitboxLimbs)]
        local limb = enemy:FindFirstChild(limbName)
        if limb then return limb end
    end
    
    return enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart
end

local function GetAllTargets()
    if not HRP or not Config.Enabled then return {} end
    
    local targets = {}
    local hrpPos = HRP.Position
    local maxDist = Config.AttackDistance
    
    if Config.AttackMobs then
        local enemies = Workspace:FindFirstChild("Enemies")
        if enemies then
            for _, enemy in ipairs(enemies:GetChildren()) do
                if #targets >= Config.MaxTargets then break end
                
                if Config.IgnoreBoats then
                    if enemy:GetAttribute("IsBoat") or 
                       enemy.Name == "FishBoat" or 
                       enemy.Name == "PirateBrigade" or 
                       enemy.Name == "PirateGrandBrigade" then
                        continue
                    end
                end
                
                local hrp = enemy:FindFirstChild("HumanoidRootPart")
                if not hrp then continue end
                
                local dist = (hrp.Position - hrpPos).Magnitude
                if dist > maxDist then continue end
                
                if not IsEntityAlive(enemy) then continue end
                
                if IsGhostEnemy(enemy) then continue end
                
                local hitbox = GetOptimalHitbox(enemy)
                if hitbox then
                    table.insert(targets, {enemy, hitbox, dist})
                end
            end
        end
    end
    
    if Config.AttackPlayers and not IsInSafeZone() then
        local chars = Workspace:FindFirstChild("Characters")
        if chars then
            for _, enemy in ipairs(chars:GetChildren()) do
                if #targets >= Config.MaxTargets then break end
                if enemy == Character then continue end
                
                if Config.RespectTeams then
                    local enemyPlayer = Players:GetPlayerFromCharacter(enemy)
                    if enemyPlayer and Player.Team and enemyPlayer.Team == Player.Team then
                        continue
                    end
                end
                
                local hrp = enemy:FindFirstChild("HumanoidRootPart")
                if not hrp then continue end
                
                local dist = (hrp.Position - hrpPos).Magnitude
                if dist > maxDist then continue end
                
                if not IsEntityAlive(enemy) then continue end
                
                local hitbox = enemy:FindFirstChild("Head") or hrp
                table.insert(targets, {enemy, hitbox, dist})
            end
        end
    end
    
    if Config.PrioritizeClosest and #targets > 1 then
        table.sort(targets, function(a, b) return a[3] < b[3] end)
    end
    
    return targets
end

local ComboTracker = {
    Count = 0,
    LastHit = 0
}

local function GetComboCount()
    if not Config.ComboMode then return 0 end
    
    local timeSinceLast = tick() - ComboTracker.LastHit
    
    if timeSinceLast > Config.ComboResetTime then
        ComboTracker.Count = 0
    end
    
    ComboTracker.Count = ComboTracker.Count + 1
    if ComboTracker.Count > Config.MaxCombo then
        ComboTracker.Count = 1
    end
    
    ComboTracker.LastHit = tick()
    return ComboTracker.Count
end

local function ExecuteMeleeAttack(targets, combo)
    if not targets or #targets == 0 then return end
    
    local mainTarget = targets[1][2]
    
    pcall(function()
        Remotes.RegisterAttack:FireServer(combo or 0)
    end)
    
    pcall(function()
        if Config.UseAdvancedHit and AdvancedFunctions.CombatFlags and AdvancedFunctions.HitFunction then
            AdvancedFunctions.HitFunction(mainTarget, targets)
        else
            Remotes.RegisterHit:FireServer(mainTarget, targets)
        end
    end)
end

local function ExecuteFruitAttack(tool, targets, combo)
    if not tool:FindFirstChild("LeftClickRemote") then return end
    if not targets or #targets == 0 then return end
    
    local direction = (targets[1][2].Position - HRP.Position).Unit
    
    pcall(function()
        tool.LeftClickRemote:FireServer(direction, combo or 1)
    end)
end

local function GetGunValidator()
    if not AdvancedFunctions.ShootFunction then return nil, 0 end
    
    local v1 = getupvalue(AdvancedFunctions.ShootFunction, 15)
    local v2 = getupvalue(AdvancedFunctions.ShootFunction, 13)
    local v3 = getupvalue(AdvancedFunctions.ShootFunction, 16)
    local v4 = getupvalue(AdvancedFunctions.ShootFunction, 17)
    local v5 = getupvalue(AdvancedFunctions.ShootFunction, 14)
    local v6 = getupvalue(AdvancedFunctions.ShootFunction, 12)
    local v7 = getupvalue(AdvancedFunctions.ShootFunction, 18)
    
    local v8 = v6 * v2
    local v9 = (v5 * v2 + v6 * v1) % v3
    v9 = (v9 * v3 + v8) % v4
    v5 = math.floor(v9 / v3)
    v6 = v9 - v5 * v3
    v7 = v7 + 1
    
    setupvalue(AdvancedFunctions.ShootFunction, 14, v5)
    setupvalue(AdvancedFunctions.ShootFunction, 12, v6)
    setupvalue(AdvancedFunctions.ShootFunction, 18, v7)
    
    return math.floor(v9 / v4 * 16777215), v7
end

local ShootDebounce = 0
local function ExecuteGunAttack(tool, targetPos)
    if not Config.AutoShootGuns or not targetPos then return end
    
    local now = tick()
    local cooldown = tool:FindFirstChild("Cooldown") and tool.Cooldown.Value or 0.3
    if (now - ShootDebounce) < cooldown then return end
    
    local ShootType = Config.SpecialShoots[tool.Name] or "Normal"
    if ShootType == "Position" or ShootType == "Overheat" or (ShootType == "TAP" and tool:FindFirstChild("RemoteEvent")) then
        pcall(function()
            tool:SetAttribute("LocalTotalShots", (tool:GetAttribute("LocalTotalShots") or 0) + 1)
        end)
        
        pcall(function()
            if Remotes.GunValidator and AdvancedFunctions.ShootFunction then
                local v1, v2 = GetGunValidator()
                if v1 then
                    Remotes.GunValidator:FireServer(v1, v2)
                end
            end
        end)
        
        if ShootType == "TAP" then
            pcall(function()
                tool.RemoteEvent:FireServer("TAP", targetPos)
            end)
        elseif ShootType == "Overheat" then
            pcall(function()
                Remotes.ShootGunEvent:FireServer(targetPos, {})
            end)
        else
            pcall(function()
                Remotes.ShootGunEvent:FireServer(targetPos)
            end)
        end
        ShootDebounce = now
    else
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
        end)
        ShootDebounce = now
    end
end

local LastAttack = 0
local AttackDebounce = 0
local LastSuccessfulAttack = tick()

local function AttackCycle()
    if not Config.Enabled then return end
    if not CanAttack() then return end
    
    local now = tick()
    if (now - AttackDebounce) < Config.AttackCooldown then return end
    
    local tool = Character:FindFirstChildOfClass("Tool")
    if not tool then return end
    
    local tooltip = tool.ToolTip
    local targets = GetAllTargets()
    
    if #targets == 0 then return end
    
    local combo = GetComboCount()
    AttackDebounce = now
    
    if tooltip == "Blox Fruit" then
        ExecuteFruitAttack(tool, targets, combo)
        LastSuccessfulAttack = now
    elseif tooltip == "Gun" then
        local closestTarget = targets[1]
        if closestTarget and closestTarget[3] <= Config.GunRange then
            ExecuteGunAttack(tool, closestTarget[2].Position)
            LastSuccessfulAttack = now
        end
    elseif tooltip == "Melee" or tooltip == "Sword" then
        ExecuteMeleeAttack(targets, combo)
        LastSuccessfulAttack = now
    end
    
    CleanGhostTracker()
end

local FastAttack = {
    Running = false,
    Connection = nil,
    HealthConnection = nil,
    RestartAttempts = 0
}

-- Watchdog to auto-restart if stuck
local LastWatchdogCheck = tick()
function FastAttack:Watchdog()
    if not Config.AutoRestart then return end
    if not self.Running then return end
    
    local now = tick()
    if (now - LastWatchdogCheck) < 5 then return end
    LastWatchdogCheck = now
    
    -- Check if we haven't attacked in a while despite having targets
    if (now - LastSuccessfulAttack) > 10 then
        local targets = GetAllTargets()
        if #targets > 0 and CanAttack() then
            warn("[FastAttack] Watchdog: Script seems stuck, restarting...")
            self:Stop()
            task.wait(Config.RestartDelay)
            self:Start()
            self.RestartAttempts = self.RestartAttempts + 1
        end
    end
end

function FastAttack:Start()
    if self.Running then 
        DebugLog("Already running")
        return 
    end
    self.Running = true
    
    -- Ensure character is valid
    if not InitializeCharacter() then
        warn("[FastAttack] Failed to initialize character!")
        self.Running = false
        return
    end
    
    -- Ensure remotes are valid
    if not Remotes.RegisterAttack or not Remotes.RegisterHit then
        warn("[FastAttack] Remotes not initialized, attempting reinitialization...")
        if not InitializeRemotes() then
            warn("[FastAttack] Failed to initialize remotes!")
            self.Running = false
            return
        end
    end
    
    self.Connection = RunService.Heartbeat:Connect(function()
        pcall(AttackCycle)
        pcall(function() self:Watchdog() end)
    end)
    
    -- Monitor health to detect death
    if Humanoid and not self.HealthConnection then
        self.HealthConnection = Humanoid.HealthChanged:Connect(function(health)
            if health <= 0 and not HealthMonitor.IsDead then
                HealthMonitor.IsDead = true
                DebugLog("Player died, preparing for respawn...")
            end
        end)
    end
    
    print("[FastAttack] ✅ Started successfully!")
    LastSuccessfulAttack = tick()
end

function FastAttack:Stop()
    if not self.Running then return end
    self.Running = false
    
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
    
    if self.HealthConnection then
        self.HealthConnection:Disconnect()
        self.HealthConnection = nil
    end
    
    print("[FastAttack] ⏸️ Stopped")
end

function FastAttack:Toggle()
    Config.Enabled = not Config.Enabled
    print("[FastAttack] Toggled:", Config.Enabled and "✅ ON" or "❌ OFF")
end

function FastAttack:SetEnabled(state)
    if Config.Enabled ~= state then
        Config.Enabled = state
        print("[FastAttack] Set to:", state and "✅ ON" or "❌ OFF")
    end
end

function FastAttack:UpdateConfig(newConfig)
    if not newConfig or type(newConfig) ~= "table" then return end
    
    for key, value in pairs(newConfig) do
        if Config[key] ~= nil then
            Config[key] = value
        end
    end
    
    print("[FastAttack] Config updated")
end

function FastAttack:GetConfig()
    return Config
end

function FastAttack:GetStatus()
    return {
        Running = self.Running,
        Enabled = Config.Enabled,
        HasCharacter = Character ~= nil,
        HasHRP = HRP ~= nil,
        HasTool = Character and Character:FindFirstChildOfClass("Tool") ~= nil,
        TargetCount = #GetAllTargets(),
        RestartAttempts = self.RestartAttempts,
        LastAttack = LastSuccessfulAttack
    }
end

-- Character respawn handler with better reliability
Player.CharacterAdded:Connect(function(newChar)
    DebugLog("Character added, reinitializing...")
    
    -- Wait for character to fully load
    task.wait(1)
    
    InitializeCharacter()
    GhostTracker = {}
    ComboTracker = {Count = 0, LastHit = 0}
    LastSuccessfulAttack = tick()
    
    if FastAttack.Running then
        DebugLog("Restarting after respawn...")
        FastAttack:Stop()
        task.wait(Config.RestartDelay)
        FastAttack:Start()
    end
end)

-- Initial setup
InitializeCharacter()
if not InitializeRemotes() then
    warn("[FastAttack] ⚠️ Failed to initialize remotes! Some features may not work.")
end

-- Disable camera shake
pcall(function()
    local CameraShaker = require(ReplicatedStorage.Util.CameraShaker)
    CameraShaker:Stop()
end)

-- Export to global environment
_ENV.FastAttack = FastAttack
_ENV.FastAttackConfig = Config

-- Auto-start if enabled
if Config.Enabled then
    task.spawn(function()
        task.wait(1.5)
        FastAttack:Start()
    end)
end

-- Utility commands for debugging
_ENV.FAStatus = function()
    local status = FastAttack:GetStatus()
    print("=== FastAttack Status ===")
    for k, v in pairs(status) do
        print(k .. ":", v)
    end
end

_ENV.FARestart = function()
    print("Manually restarting FastAttack...")
    FastAttack:Stop()
    task.wait(1)
    FastAttack:Start()
end

return FastAttack