local _ENV = getgenv and getgenv() or getfenv(2)

-- ==================== CONFIGURATION ====================
local Config = {
    -- Core Settings
    FastAttack = false,
    AttackMobs = true,
    AttackPlayers = false,
    DebugMode = false,

    -- Performance
    FastAttackDelay = 0.05,
    ClickDelay = 0,
    AttackDistance = 65,
    MaxTargets = 15,
    
    -- Optimization
    SpatialPartitionSize = 100,
    TargetCacheTime = 0.1,
    
    -- Priority
    PriorityMode = "Nearest", -- "Nearest", "LowestHP", "HighestHP"

    -- Filters
    IgnoreForceField = true,
    RespectTeams = true,
    MinHealthPercent = 0.01,

    -- Ghost Detection (Enhanced)
    GhostDetection = {
        Enabled = true,
        Timeout = 15,
        RetryDelay = 2,
        AllowDuringSkills = true,
        AdaptiveLearning = true,
        ConfidenceThreshold = 3
    },
    
    -- Gun Settings
    GunConfig = {
        Enabled = true,
        MaxDistance = 120,
        AutoShoot = true
    },
    
    -- Combo System
    ComboConfig = {
        Enabled = true,
        MaxCombo = 4,
        ResetTime = 0.3
    }
}

-- ==================== SERVICES ====================
local Services = {
    RS = game:GetService("ReplicatedStorage"),
    RunService = game:GetService("RunService"),
    Players = game:GetService("Players"),
    Workspace = game:GetService("Workspace"),
    VirtualInput = game:GetService("VirtualInputManager")
}

local Player = Services.Players.LocalPlayer
local Character, HRP, Humanoid

-- ==================== UTILITIES ====================
local Utils = {
    LastCleanup = 0,
    Cache = {
        Targets = {},
        LastUpdate = 0,
        SafeZone = {visible = false, time = 0},
        PvP = {disabled = false, time = 0}
    }
}

function Utils.IsAlive(char)
    if not char then return false end
    local h = char:FindFirstChild("Humanoid")
    return h and h.Health > 0
end

function Utils.GetDistance(pos1, pos2)
    return (pos1 - pos2).Magnitude
end

function Utils.HasForceField(char)
    return char:FindFirstChildOfClass("ForceField") ~= nil
end

function Utils.DebugPrint(...)
    if Config.DebugMode then
        print(string.format("[FastAttackV5][%.2f]", tick()), ...)
    end
end

function Utils.SafePcall(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        Utils.DebugPrint("Error:", result)
    end
    return success, result
end

-- Optimized distance check using squared distance
function Utils.IsWithinRange(pos1, pos2, range)
    local dx = pos1.X - pos2.X
    local dy = pos1.Y - pos2.Y
    local dz = pos1.Z - pos2.Z
    return (dx*dx + dy*dy + dz*dz) <= (range*range)
end

-- ==================== INITIALIZATION ====================
local function InitializeReferences()
    Character = Player.Character or Player.CharacterAdded:Wait()
    HRP = Character:WaitForChild("HumanoidRootPart", 5)
    Humanoid = Character:WaitForChild("Humanoid", 5)

    if not HRP or not Humanoid then
        warn("[FastAttackV5] Failed to get character parts!")
        return nil
    end

    local Modules = Services.RS:WaitForChild("Modules", 10)
    if not Modules then
        warn("[FastAttackV5] Modules not found!")
        return nil
    end

    local Net = Modules:WaitForChild("Net", 10)
    if not Net then
        warn("[FastAttackV5] Net not found!")
        return nil
    end

    local RegisterAttack = Net:WaitForChild("RE/RegisterAttack", 10)
    local RegisterHit = Net:WaitForChild("RE/RegisterHit", 10)
    local ShootGunEvent = Net:FindFirstChild("RE/ShootGunEvent")
    
    local GunValidator = Services.RS:FindFirstChild("Remotes")
    if GunValidator then
        GunValidator = GunValidator:FindFirstChild("Validator2")
    end

    if not RegisterAttack or not RegisterHit then
        warn("[FastAttackV5] Attack remotes not found!")
        return nil
    end

    local Enemies = Services.Workspace:FindFirstChild("Enemies")
    local Characters = Services.Workspace:FindFirstChild("Characters")

    -- Try to get combat functions
    local CombatFlags, HitFunction, ShootFunction
    Utils.SafePcall(function()
        CombatFlags = require(Modules.Flags).COMBAT_REMOTE_THREAD
        
        local CombatController = Services.RS:FindFirstChild("Controllers")
        if CombatController then
            CombatController = CombatController:FindFirstChild("CombatController")
            if CombatController then
                ShootFunction = getupvalue(require(CombatController).Attack, 9)
            end
        end
        
        local LocalScript = Player:WaitForChild("PlayerScripts"):FindFirstChildOfClass("LocalScript")
        if LocalScript and getsenv then
            HitFunction = getsenv(LocalScript)._G.SendHitsToServer
        end
    end)

    return {
        RegisterAttack = RegisterAttack,
        RegisterHit = RegisterHit,
        ShootGunEvent = ShootGunEvent,
        GunValidator = GunValidator,
        Enemies = Enemies,
        Characters = Characters,
        CombatFlags = CombatFlags,
        HitFunction = HitFunction,
        ShootFunction = ShootFunction
    }
end

local Refs = InitializeReferences()
if not Refs then
    warn("[FastAttackV5] Critical initialization failure!")
    return
end

Utils.DebugPrint("Initialization successful!")

-- ==================== GHOST MOB DETECTION V2 ====================
local GhostDetection = {
    Tracked = {},
    Patterns = {} -- Adaptive learning patterns
}

function GhostDetection:Track(mob)
    if not Config.GhostDetection.Enabled or not mob then return true end
    
    local hum = mob:FindFirstChild("Humanoid")
    if not hum then return true end

    local currentHealth = hum.Health
    local now = tick()

    -- Initialize tracking
    if not self.Tracked[mob] then
        self.Tracked[mob] = {
            firstSeen = now,
            lastHealthChange = now,
            lastHealth = currentHealth,
            attackAttempts = 0,
            successfulHits = 0,
            suspectedGhost = false,
            confirmedGhost = false,
            lastRetry = 0,
            pattern = {}
        }
        return true
    end

    local track = self.Tracked[mob]
    
    -- Detect health change
    if math.abs(currentHealth - track.lastHealth) > 0.1 then
        track.lastHealthChange = now
        track.lastHealth = currentHealth
        track.successfulHits = track.successfulHits + 1
        track.suspectedGhost = false
        track.confirmedGhost = false
        
        -- Record successful hit pattern
        if Config.GhostDetection.AdaptiveLearning then
            table.insert(track.pattern, {time = now, success = true})
        end
        
        Utils.DebugPrint("Hit confirmed:", mob.Name, "HP:", currentHealth)
        return true
    end

    track.attackAttempts = track.attackAttempts + 1
    
    local timeSinceHealthChange = now - track.lastHealthChange
    
    -- Grace period (skills, animations, lag)
    if Config.GhostDetection.AllowDuringSkills and timeSinceHealthChange < Config.GhostDetection.RetryDelay then
        return true
    end

    -- Suspected ghost - periodic retry
    if timeSinceHealthChange >= Config.GhostDetection.RetryDelay and timeSinceHealthChange < Config.GhostDetection.Timeout then
        if not track.suspectedGhost then
            track.suspectedGhost = true
            Utils.DebugPrint("Suspected ghost:", mob.Name)
        end
        
        -- Retry with backoff
        if (now - track.lastRetry) >= Config.GhostDetection.RetryDelay then
            track.lastRetry = now
            return true
        end
        return false
    end

    -- Confirmed ghost (adaptive threshold)
    local confidenceThreshold = Config.GhostDetection.ConfidenceThreshold
    local failureRate = track.attackAttempts > 0 and (1 - track.successfulHits / track.attackAttempts) or 1
    
    if timeSinceHealthChange >= Config.GhostDetection.Timeout and failureRate > 0.9 then
        if not track.confirmedGhost then
            track.confirmedGhost = true
            Utils.DebugPrint("CONFIRMED ghost:", mob.Name, "Attempts:", track.attackAttempts, "Success:", track.successfulHits)
        end
        return false
    end

    return true
end

function GhostDetection:Cleanup()
    for mob, _ in pairs(self.Tracked) do
        if not mob or not mob.Parent or not Utils.IsAlive(mob) then
            self.Tracked[mob] = nil
        end
    end
end

function GhostDetection:Reset()
    self.Tracked = {}
    Utils.DebugPrint("Ghost tracking reset")
end

function GhostDetection:GetStats()
    local total, suspected, confirmed = 0, 0, 0
    for _, track in pairs(self.Tracked) do
        total = total + 1
        if track.suspectedGhost then suspected = suspected + 1 end
        if track.confirmedGhost then confirmed = confirmed + 1 end
    end
    return {total = total, suspected = suspected, confirmed = confirmed}
end

-- ==================== FAST ATTACK ENGINE ====================
local FastAttack = {
    Running = false,
    LastAttack = 0,
    ComboState = {
        Current = 0,
        LastHit = 0
    },
    GunState = {
        LastShot = 0,
        Overheat = {Dragonstorm = {MaxOverheat = 3, Cooldown = 0, TotalOverheat = 0, Distance = 350, Shooting = false}},
        SpecialShoots = {["Skull Guitar"] = "TAP", ["Bazooka"] = "Position", ["Cannon"] = "Position", ["Dragonstorm"] = "Overheat"}
    },
    Stats = {
        TPS = 0,
        TotalAttacks = 0,
        SuccessfulHits = 0,
        Errors = 0,
        TargetsHit = 0
    },
    Connection = nil
}

-- ==================== VALIDATION ====================
function FastAttack:CheckStun()
    if not Character or not Humanoid then return false end
    
    local tool = Character:FindFirstChildOfClass("Tool")
    if not tool then return false end
    
    local stun = Character:FindFirstChild("Stun")
    local busy = Character:FindFirstChild("Busy")
    
    if Humanoid.Sit and (tool.ToolTip == "Sword" or tool.ToolTip == "Melee" or tool.ToolTip == "Blox Fruit") then
        return false
    end
    
    if (stun and stun.Value > 0) or (busy and busy.Value) then
        return false
    end
    
    return true
end

function FastAttack:ValidateEnemy(enemy)
    if not enemy or enemy == Character then return false end

    local hum = enemy:FindFirstChild("Humanoid")
    local hrp = enemy:FindFirstChild("HumanoidRootPart")
    
    if not hum or not hrp then return false end
    if hum.Health <= 0 then return false end

    local healthPercent = hum.Health / hum.MaxHealth
    if healthPercent < Config.MinHealthPercent then return false end

    if Config.IgnoreForceField and Utils.HasForceField(enemy) then
        return false
    end

    local enemyPlayer = Services.Players:GetPlayerFromCharacter(enemy)
    local isPlayer = enemyPlayer ~= nil

    -- MOB VALIDATION
    if not isPlayer then
        if not Config.AttackMobs then return false end
        return GhostDetection:Track(enemy)
    end

    -- PLAYER VALIDATION
    if not Config.AttackPlayers then return false end
    if enemyPlayer == Player then return false end

    if Config.RespectTeams and Player.Team and enemyPlayer.Team then
        if enemyPlayer.Team == Player.Team then return false end
    end

    -- PvP checks (cached)
    local now = tick()
    if (now - Utils.Cache.SafeZone.time) > 0.5 then
        local gui = Player:FindFirstChild("PlayerGui")
        if gui then
            local main = gui:FindFirstChild("Main")
            if main then
                local bottomHUD = main:FindFirstChild("BottomHUDList")
                if bottomHUD then
                    local safeZone = bottomHUD:FindFirstChild("SafeZone")
                    Utils.Cache.SafeZone = {
                        visible = safeZone and safeZone.Visible or false,
                        time = now
                    }
                end
            end
        end
    end

    if Utils.Cache.SafeZone.visible then return false end

    if (now - Utils.Cache.PvP.time) > 0.5 then
        local gui = Player:FindFirstChild("PlayerGui")
        if gui then
            local main = gui:FindFirstChild("Main")
            if main then
                local pvpDisabled = main:FindFirstChild("PvpDisabled")
                Utils.Cache.PvP = {
                    disabled = pvpDisabled and pvpDisabled.Visible or false,
                    time = now
                }
            end
        end
    end

    return not Utils.Cache.PvP.disabled
end

-- ==================== TARGET ACQUISITION (OPTIMIZED) ====================
function FastAttack:GetTargets()
    if not HRP then return {} end
    
    local now = tick()
    
    -- Return cached targets if still valid
    if (now - Utils.Cache.LastUpdate) < Config.TargetCacheTime and #Utils.Cache.Targets > 0 then
        return Utils.Cache.Targets
    end
    
    local targets = {}
    local maxDist = Config.AttackDistance
    local hrpPos = HRP.Position

    local function scanFolder(folder)
        if not folder then return end

        for _, enemy in ipairs(folder:GetChildren()) do
            if #targets >= Config.MaxTargets then break end

            local hrp = enemy:FindFirstChild("HumanoidRootPart")
            if not hrp then continue end

            -- Fast distance check
            if not Utils.IsWithinRange(hrpPos, hrp.Position, maxDist) then continue end

            if not self:ValidateEnemy(enemy) then continue end

            local head = enemy:FindFirstChild("Head")
            if not head then continue end
            
            local hum = enemy:FindFirstChild("Humanoid")
            local dist = Utils.GetDistance(hrpPos, hrp.Position)
            
            table.insert(targets, {
                entity = enemy,
                head = head,
                hrp = hrp,
                distance = dist,
                hp = hum and hum.Health or 0,
                maxHp = hum and hum.MaxHealth or 1
            })
        end
    end

    if Config.AttackMobs and Refs.Enemies then 
        scanFolder(Refs.Enemies)
    end

    if Config.AttackPlayers and Refs.Characters then 
        scanFolder(Refs.Characters)
    end

    -- Sort by priority
    if #targets > 1 then
        if Config.PriorityMode == "Nearest" then
            table.sort(targets, function(a, b) return a.distance < b.distance end)
        elseif Config.PriorityMode == "LowestHP" then
            table.sort(targets, function(a, b) return a.hp < b.hp end)
        elseif Config.PriorityMode == "HighestHP" then
            table.sort(targets, function(a, b) return a.hp > b.hp end)
        end
    end
    
    -- Update cache
    Utils.Cache.Targets = targets
    Utils.Cache.LastUpdate = now
    
    return targets
end

-- ==================== COMBO SYSTEM ====================
function FastAttack:GetCombo()
    if not Config.ComboConfig.Enabled then return 1 end
    
    local now = tick()
    local timeSinceLastHit = now - self.ComboState.LastHit
    
    if timeSinceLastHit > Config.ComboConfig.ResetTime then
        self.ComboState.Current = 1
    else
        self.ComboState.Current = (self.ComboState.Current % Config.ComboConfig.MaxCombo) + 1
    end
    
    self.ComboState.LastHit = now
    return self.ComboState.Current
end

-- ==================== ATTACK EXECUTION ====================
function FastAttack:ExecuteMeleeAttack(targets)
    if not targets or #targets == 0 then return false end

    local hitData = {}
    for _, target in ipairs(targets) do
        table.insert(hitData, {target.entity, target.hrp or target.head})
    end

    local basePart = targets[1].head

    local success = Utils.SafePcall(function()
        Refs.RegisterAttack:FireServer(Config.ClickDelay)
        
        if Refs.CombatFlags and Refs.HitFunction then
            Refs.HitFunction(basePart, hitData)
        else
            Refs.RegisterHit:FireServer(basePart, hitData)
        end
    end)

    if success then
        self.Stats.TotalAttacks = self.Stats.TotalAttacks + 1
        self.Stats.TargetsHit = self.Stats.TargetsHit + #targets
    else
        self.Stats.Errors = self.Stats.Errors + 1
    end

    return success
end

function FastAttack:ExecuteFruitAttack(tool, targets)
    if not tool:FindFirstChild("LeftClickRemote") then return false end
    if not targets or #targets == 0 then return false end
    
    local combo = self:GetCombo()
    local direction = (targets[1].hrp.Position - HRP.Position).Unit
    
    local success = Utils.SafePcall(function()
        tool.LeftClickRemote:FireServer(direction, combo)
    end)
    
    if success then
        self.Stats.TotalAttacks = self.Stats.TotalAttacks + 1
    end
    
    return success
end

function FastAttack:ExecuteGunAttack(tool, target)
    if not Config.GunConfig.Enabled or not Refs.ShootGunEvent then return false end
    
    local now = tick()
    local cooldown = tool:FindFirstChild("Cooldown") and tool.Cooldown.Value or 0.3
    
    if (now - self.GunState.LastShot) < cooldown then return false end
    
    local ShootType = self.GunState.SpecialShoots[tool.Name] or "Normal"
    if ShootType == "Position" or (ShootType == "TAP" and tool:FindFirstChild("RemoteEvent")) then
        if ShootType == "TAP" then
            local success = Utils.SafePcall(function()
                tool.RemoteEvent:FireServer("TAP", target)
            end)
        else
            local success = Utils.SafePcall(function()
                Refs.ShootGunEvent:FireServer(target)
            end)
        end

        if success then
            self.GunState.LastShot = now
            self.Stats.TotalAttacks = self.Stats.TotalAttacks + 1
        end
    else
        local success = Utils.SafePcall(function()
            Services.VirtualInput:SendMouseButtonEvent(0, 0, 0, true, game, 1)
            task.wait(0.05)
            Services.VirtualInput:SendMouseButtonEvent(0, 0, 0, false, game, 1)
        end)
    
        if success then
            self.GunState.LastShot = now
            self.Stats.TotalAttacks = self.Stats.TotalAttacks + 1
        end
    end
    
    return success
end

-- ==================== MAIN CYCLE ====================
function FastAttack:Cycle()
    if not Config.FastAttack then return end
    if not Utils.IsAlive(Character) then return end
    if not self:CheckStun() then return end

    local tool = Character:FindFirstChildOfClass("Tool")
    if not tool then return end

    local now = tick()
    if (now - self.LastAttack) < Config.FastAttackDelay then return end

    local toolTip = tool.ToolTip
    local targets = self:GetTargets()
    
    if toolTip == "Gun" then
        if #targets > 0 then
            self:ExecuteGunAttack(tool, targets[1])
        end
    elseif toolTip == "Blox Fruit" then
        if #targets > 0 then
            self:ExecuteFruitAttack(tool, targets)
        end
    elseif toolTip == "Sword" or toolTip == "Melee" then
        if #targets > 0 then
            self:ExecuteMeleeAttack(targets)
        end
    end
    
    self.LastAttack = now
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
        perfStartTime = now
    end
end

-- ==================== PERIODIC CLEANUP ====================
function FastAttack:PeriodicCleanup()
    local now = tick()
    if (now - Utils.LastCleanup) < 5 then return end
    
    GhostDetection:Cleanup()
    Utils.Cache.Targets = {}
    collectgarbage("collect")
    
    Utils.LastCleanup = now
    Utils.DebugPrint("Cleanup completed")
end

-- ==================== START/STOP ====================
function FastAttack:Start()
    if self.Running then return end
    self.Running = true

    Utils.DebugPrint("Starting Fast Attack V5...")

    self.Connection = Services.RunService.Heartbeat:Connect(function()
        self:Cycle()
        self:UpdatePerformance()
        self:PeriodicCleanup()
    end)

    print("[FastAttack V5] Started!")
end

function FastAttack:Stop()
    if not self.Running then return end
    self.Running = false

    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end

    print("[FastAttack V5] Stopped")
end

function FastAttack:Toggle()
    Config.FastAttack = not Config.FastAttack
    print("[FastAttack V5] Toggled:", Config.FastAttack and "ON" or "OFF")

    if Config.FastAttack and not self.Running then
        self:Start()
    elseif not Config.FastAttack and self.Running then
        self:Stop()
    end
end

-- ==================== CONFIG UPDATE ====================
function FastAttack:UpdateConfig(newConfig)
    if not newConfig then return end

    for key, value in pairs(newConfig) do
        if Config[key] ~= nil then
            if type(Config[key]) == "table" and type(value) == "table" then
                for k, v in pairs(value) do
                    Config[key][k] = v
                end
            else
                Config[key] = value
            end
            Utils.DebugPrint("Config Update:", key, "=", tostring(value))
        end
    end

    if newConfig.FastAttack ~= nil then
        if newConfig.FastAttack and not self.Running then
            self:Start()
        elseif not newConfig.FastAttack and self.Running then
            self:Stop()
        end
    end
end

-- ==================== CHARACTER RESPAWN ====================
Player.CharacterAdded:Connect(function(newChar)
    Character = newChar
    Utils.DebugPrint("Character respawned, reinitializing...")

    GhostDetection:Reset()
    Utils.Cache.Targets = {}

    task.wait(0.5)

    local newRefs = InitializeReferences()
    if newRefs then
        Refs = newRefs
        Utils.DebugPrint("References reinitialized")
    end

    if FastAttack.Running then
        FastAttack:Stop()
        task.wait(0.3)
        FastAttack:Start()
    end
end)

-- ==================== GLOBAL EXPORT ====================
_ENV.FastAttackV5 = FastAttack

-- Basic Controls
_ENV.FA_Toggle = function() FastAttack:Toggle() end
_ENV.FA_Start = function() FastAttack:Start() end
_ENV.FA_Stop = function() FastAttack:Stop() end

-- Configuration
_ENV.FA_Config = function(key, value)
    if not key then
        print("=== Current Configuration ===")
        for k, v in pairs(Config) do
            if type(v) ~= "table" then
                print(k, "=", v)
            end
        end
        return
    end
    
    if Config[key] ~= nil then
        if value ~= nil then
            Config[key] = value
            print("[FastAttack V5]", key, "set to:", value)
        else
            print("[FastAttack V5]", key, "=", Config[key])
        end
    else
        print("[FastAttack V5] Unknown config key:", key)
    end
end

-- Debug
_ENV.FA_Debug = function(enabled)
    if enabled == nil then
        Config.DebugMode = not Config.DebugMode
    else
        Config.DebugMode = enabled
    end
    print("[FastAttack V5] Debug Mode:", Config.DebugMode and "ON" or "OFF")
end

-- Statistics
_ENV.FA_Stats = function()
    print("=== FastAttack V5 Statistics ===")
    print("Status:", FastAttack.Running and "RUNNING" or "STOPPED")
    print("FastAttack:", Config.FastAttack and "ENABLED" or "DISABLED")
    print("")
    print("Performance:")
    print("  TPS:", FastAttack.Stats.TPS)
    print("  Total Attacks:", FastAttack.Stats.TotalAttacks)
    print("  Targets Hit:", FastAttack.Stats.TargetsHit)
    print("  Errors:", FastAttack.Stats.Errors)
    print("")
    local ghostStats = GhostDetection:GetStats()
    print("Ghost Detection:")
    print("  Tracked Mobs:", ghostStats.total)
    print("  Suspected:", ghostStats.suspected)
    print("  Confirmed:", ghostStats.confirmed)
    print("")
    print("Configuration:")
    print("  Attack Distance:", Config.AttackDistance)
    print("  Max Targets:", Config.MaxTargets)
    print("  Priority Mode:", Config.PriorityMode)
    print("  Attack Delay:", Config.FastAttackDelay)
end

-- Ghost Management
_ENV.FA_ClearGhosts = function()
    GhostDetection:Reset()
    print("[FastAttack V5] Cleared all ghost mob tracking")
end

_ENV.FA_ListGhosts = function()
    print("=== Tracked Mobs ===")
    local count = 0
    for mob, track in pairs(GhostDetection.Tracked) do
        if mob and mob.Parent then
            count = count + 1
            local status = track.confirmedGhost and "GHOST" or (track.suspectedGhost and "SUSPECTED" or "OK")
            local successRate = track.attackAttempts > 0 and 
                string.format("%.1f%%", (track.successfulHits / track.attackAttempts) * 100) or "N/A"
            print(string.format("%s [%s] - Attacks: %d | Success: %s | Time: %.1fs", 
                mob.Name, status, track.attackAttempts, successRate, tick() - track.firstSeen))
        end
    end
    print("Total:", count, "mobs")
end

-- Presets
_ENV.FA_Preset = function(preset)
    local presets = {
        speed = {FastAttackDelay = 0.03, AttackDistance = 65, MaxTargets = 20},
        balanced = {FastAttackDelay = 0.05, AttackDistance = 65, MaxTargets = 15},
        safe = {FastAttackDelay = 0.1, AttackDistance = 50, MaxTargets = 10},
        pvp = {AttackPlayers = true, AttackMobs = false, RespectTeams = true, MaxTargets = 5}
    }
    
    if not preset then
        print("Available presets: speed, balanced, safe, pvp")
        return
    end
    
    if presets[preset] then
        FastAttack:UpdateConfig(presets[preset])
        print("[FastAttack V5] Applied preset:", preset)
    else
        print("[FastAttack V5] Unknown preset:", preset)
    end
end

-- Help
_ENV.FA_Help = function()
    print("=== FastAttack V5 Commands ===")
    print("")
    print("BASIC CONTROLS:")
    print("  FA_Toggle()              - Toggle on/off")
    print("  FA_Start()               - Start attacking")
    print("  FA_Stop()                - Stop attacking")
    print("  FA_Stats()               - Show statistics")
    print("")
    print("CONFIGURATION:")
    print("  FA_Config()              - Show all config")
    print("  FA_Config(key, value)    - Set config value")
    print("  FA_Preset('speed')       - Apply preset (speed/balanced/safe/pvp)")
    print("")
    print("GHOST DETECTION:")
    print("  FA_ListGhosts()          - List tracked mobs")
    print("  FA_ClearGhosts()         - Clear ghost tracking")
    print("")
    print("DEBUGGING:")
    print("  FA_Debug()               - Toggle debug mode")
end

-- ==================== AUTO-START ====================
if Config.FastAttack then
    task.wait(1)
    FastAttack:Start()
    print("[FastAttack V5] Auto-started")
end

print("FastAttack V5 Loaded - Type FA_Help() for commands")

return FastAttack