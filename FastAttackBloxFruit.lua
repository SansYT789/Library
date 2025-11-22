-- ==================== FAST ATTACK SYSTEM V4 - GHOST MOB FIX ====================
-- FIXED: Ghost mob detection, proper skill blocking handling, persistent targeting
-- The system now properly handles temporary attack blocks without marking mobs as invalid

local _ENV = getgenv and getgenv() or getfenv(2)

-- ==================== CONFIGURATION ====================
local Config = {
    -- Core Settings
    FastAttack = false,
    AttackMob = true,
    AttackPlayers = false,
    DebugMode = false,

    -- Performance
    FastAttackDelay = 0.05,
    ClickDelay = 0,
    AttackDistance = 350,
    MaxTargets = 15,

    -- Priority Settings
    PriorityMode = "Nearest",       -- "Nearest", "Lowest HP", "Highest HP"

    -- Filters
    IgnoreForceField = true,
    RespectTeams = true,
    MinHealthPercent = 0.01,
    
    -- Ghost Mob Detection (NEW - CRITICAL FIX)
    GhostMobTimeout = 15,           -- Time (seconds) before considering a mob truly "ghost"
    GhostMobRetryDelay = 2,         -- Time to wait before retrying a suspected ghost mob
    AllowAttackDuringSkills = true, -- Continue attacking even if hits don't register temporarily
}

-- ==================== SERVICES ====================
local Services = {
    RS = game:GetService("ReplicatedStorage"),
    RunService = game:GetService("RunService"),
    Players = game:GetService("Players"),
    Workspace = game:GetService("Workspace")
}

local Player = Services.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local HRP, Humanoid

-- ==================== UTILITIES ====================
local Utils = {}

function Utils.IsAlive(char)
    if not char then return false end
    local h = char:FindFirstChild("Humanoid")
    return h and h.Health > 0
end

function Utils.GetDistance(pos)
    if not HRP then return math.huge end
    return (HRP.Position - pos).Magnitude
end

function Utils.HasForceField(char)
    return char and char:FindFirstChildOfClass("ForceField") ~= nil
end

function Utils.DebugPrint(...)
    if Config.DebugMode then
        print("[FastAttackV4]", ...)
    end
end

-- ==================== INITIALIZATION ====================
local function InitializeReferences()
    HRP = Character and Character:FindFirstChild("HumanoidRootPart")
    Humanoid = Character and Character:FindFirstChild("Humanoid")

    if not HRP or not Humanoid then
        warn("[FastAttackV4] Failed to get character parts!")
        return nil
    end

    local Modules = Services.RS:FindFirstChild("Modules") or Services.RS:WaitForChild("Modules", 10)
    if not Modules then
        warn("[FastAttackV4] Modules not found!")
        return nil
    end

    local Net = Modules:FindFirstChild("Net") or Modules:WaitForChild("Net", 10)
    if not Net then
        warn("[FastAttackV4] Net not found!")
        return nil
    end

    local RegisterAttack = Net:FindFirstChild("RE/RegisterAttack") or Net:WaitForChild("RE/RegisterAttack", 10)
    local RegisterHit = Net:FindFirstChild("RE/RegisterHit") or Net:WaitForChild("RE/RegisterHit", 10)

    if not RegisterAttack or not RegisterHit then
        warn("[FastAttackV4] Attack remotes not found!")
        return nil
    end

    local Enemies = Services.Workspace:FindFirstChild("Enemies")
    local Characters = Services.Workspace:FindFirstChild("Characters")

    return {
        RegisterAttack = RegisterAttack,
        RegisterHit = RegisterHit,
        Enemies = Enemies,
        Characters = Characters
    }
end

local Refs = InitializeReferences()
if not Refs or not Refs.RegisterAttack or not Refs.RegisterHit then
    warn("[FastAttackV4] Critical initialization failure!")
    return
end

Utils.DebugPrint("Initialization successful!")

-- ==================== FAST ATTACK ENGINE ====================
local FastAttack = {
    Config = Config,
    Running = false,
    LastAttack = 0,

    Stats = {
        TPS = 0,
        TotalAttacks = 0,
        Errors = 0
    },

    Cache = {
        SafeZoneCheck = {visible = false, time = 0},
        PvpCheck = {disabled = false, time = 0}
    },
    
    -- NEW: Ghost Mob Tracking System
    MobTracking = {}  -- Format: [mob] = {firstSeen, lastHealthChange, lastHealth, suspectedGhost, lastRetry}
}

-- ==================== GHOST MOB DETECTION (NEW - FIXED) ====================
function FastAttack:TrackMobHealth(mob)
    if not mob then return true end -- Allow attack if no tracking needed
    
    local hum = mob:FindFirstChild("Humanoid")
    if not hum then return true end
    
    local currentHealth = hum.Health
    local now = tick()
    
    -- Initialize tracking for new mobs
    if not self.MobTracking[mob] then
        self.MobTracking[mob] = {
            firstSeen = now,
            lastHealthChange = now,
            lastHealth = currentHealth,
            suspectedGhost = false,
            lastRetry = 0,
            attackAttempts = 0
        }
        Utils.DebugPrint("Started tracking:", mob.Name, "HP:", currentHealth)
        return true -- Always allow first attack
    end
    
    local track = self.MobTracking[mob]
    
    -- Check if health changed (successful hit)
    if math.abs(currentHealth - track.lastHealth) > 0.1 then
        Utils.DebugPrint("Health changed for", mob.Name, "from", track.lastHealth, "to", currentHealth)
        track.lastHealthChange = now
        track.lastHealth = currentHealth
        track.suspectedGhost = false
        track.attackAttempts = 0
        return true -- Health changed, definitely not a ghost
    end
    
    -- CRITICAL FIX: Don't immediately mark as ghost during temporary blocks
    local timeSinceHealthChange = now - track.lastHealthChange
    local timeSinceFirstSeen = now - track.firstSeen
    
    track.attackAttempts = track.attackAttempts + 1
    
    -- Allow attacks during the "grace period" (skills, loading, etc.)
    if Config.AllowAttackDuringSkills and timeSinceHealthChange < Config.GhostMobRetryDelay then
        Utils.DebugPrint("Grace period for", mob.Name, "- allowing attack despite no damage")
        return true
    end
    
    -- After grace period, check if it's suspected ghost
    if timeSinceHealthChange >= Config.GhostMobRetryDelay and timeSinceHealthChange < Config.GhostMobTimeout then
        -- Suspected ghost - retry periodically
        if not track.suspectedGhost then
            track.suspectedGhost = true
            Utils.DebugPrint("Suspected ghost mob:", mob.Name, "- will retry periodically")
        end
        
        -- Retry every GhostMobRetryDelay seconds
        if (now - track.lastRetry) >= Config.GhostMobRetryDelay then
            track.lastRetry = now
            Utils.DebugPrint("Retrying suspected ghost:", mob.Name)
            return true -- Retry attack
        else
            return false -- Skip this cycle
        end
    end
    
    -- After timeout, mark as true ghost
    if timeSinceHealthChange >= Config.GhostMobTimeout then
        if not track.confirmedGhost then
            track.confirmedGhost = true
            Utils.DebugPrint("CONFIRMED ghost mob:", mob.Name, "- ignoring permanently")
        end
        return false -- True ghost, don't attack
    end
    
    -- Default: allow attack (we're still learning about this mob)
    return true
end

-- Clean up tracking for dead/removed mobs
function FastAttack:CleanupMobTracking()
    for mob, _ in pairs(self.MobTracking) do
        if not mob or not mob.Parent or not Utils.IsAlive(mob) then
            Utils.DebugPrint("Cleanup tracking for:", mob and mob.Name or "removed mob")
            self.MobTracking[mob] = nil
        end
    end
end

-- ==================== VALIDATION ====================
function FastAttack:ValidateEnemy(enemy)
    if not enemy or enemy == Character then return false end

    -- Basic parts check
    local hum = enemy:FindFirstChild("Humanoid")
    local hrp = enemy:FindFirstChild("HumanoidRootPart")
    local head = enemy:FindFirstChild("Head")

    if not hum or not hrp or not head then return false end
    if hum.Health <= 0 then return false end

    -- Health threshold
    local healthPercent = hum.Health / hum.MaxHealth
    if healthPercent < Config.MinHealthPercent then return false end

    -- Force field check
    if Config.IgnoreForceField and Utils.HasForceField(enemy) then
        return false
    end

    -- Check if it's a player or mob
    local enemyPlayer = Services.Players:GetPlayerFromCharacter(enemy)
    local isPlayer = enemyPlayer ~= nil

    -- MOB VALIDATION
    if not isPlayer then
        if not Config.AttackMob then 
            return false 
        end
        
        -- NEW: Ghost mob check for NPCs/Mobs only
        if not self:TrackMobHealth(enemy) then
            Utils.DebugPrint("Skipping ghost mob:", enemy.Name)
            return false
        end
        
        return true
    end

    -- PLAYER VALIDATION (no ghost tracking needed)
    if not Config.AttackPlayers then 
        return false 
    end

    if enemyPlayer == Player then 
        return false 
    end

    if Config.RespectTeams and Player.Team and enemyPlayer.Team then
        if enemyPlayer.Team == Player.Team then
            return false
        end
    end

    -- Check cache first
    local now = tick()

    if (now - self.Cache.SafeZoneCheck.time) > 0.5 then
        local gui = Player:FindFirstChild("PlayerGui")
        if gui then
            local main = gui:FindFirstChild("Main")
            if main then
                local bottomHUD = main:FindFirstChild("BottomHUDList")
                if bottomHUD then
                    local safeZone = bottomHUD:FindFirstChild("SafeZone")
                    self.Cache.SafeZoneCheck = {
                        visible = safeZone and safeZone.Visible or false,
                        time = now
                    }
                end
            end
        end
    end

    if self.Cache.SafeZoneCheck.visible then
        return false
    end

    if (now - self.Cache.PvpCheck.time) > 0.5 then
        local gui = Player:FindFirstChild("PlayerGui")
        if gui then
            local main = gui:FindFirstChild("Main")
            if main then
                local pvpDisabled = main:FindFirstChild("PvpDisabled")
                self.Cache.PvpCheck = {
                    disabled = pvpDisabled and pvpDisabled.Visible or false,
                    time = now
                }
            end
        end
    end

    if self.Cache.PvpCheck.disabled then
        return false
    end

    return true
end

-- ==================== TARGET ACQUISITION ====================
function FastAttack:GetTargets()
    local targets = {}
    local maxDist = Config.AttackDistance

    local function scanFolder(folder, folderName)
        if not folder then return end

        for _, enemy in ipairs(folder:GetChildren()) do
            if #targets >= Config.MaxTargets then break end

            local head = enemy:FindFirstChild("Head")
            if not head then continue end

            local dist = Utils.GetDistance(head.Position)
            if dist >= maxDist then continue end

            if not self:ValidateEnemy(enemy) then continue end

            local hum = enemy:FindFirstChild("Humanoid")
            table.insert(targets, {
                entity = enemy,
                head = head,
                distance = dist,
                hp = hum and hum.Health or 0
            })
        end
    end

    if Config.AttackMob and Refs.Enemies then 
        scanFolder(Refs.Enemies, "Enemies")
    end

    if Config.AttackPlayers and Refs.Characters then 
        scanFolder(Refs.Characters, "Characters")
    end

    if #targets > 1 then
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

    local hitData = {}
    for _, target in ipairs(targets) do
        table.insert(hitData, {target.entity, target.head})
    end

    local basePart = targets[1].head

    local success = pcall(function()
        Refs.RegisterAttack:FireServer(Config.ClickDelay)
        Refs.RegisterHit:FireServer(basePart, hitData)
    end)

    if success then
        self.Stats.TotalAttacks = self.Stats.TotalAttacks + 1
    else
        self.Stats.Errors = self.Stats.Errors + 1
    end

    return success
end

-- ==================== MAIN CYCLE ====================
local lastCycleTime = 0
local cleanupTimer = 0

function FastAttack:Cycle()
    if not Config.FastAttack then return end
    if not Utils.IsAlive(Character) then return end

    local tool = Character:FindFirstChildOfClass("Tool")
    if not tool then return end
    if tool.ToolTip == "Gun" then return end

    local now = tick()
    if (now - lastCycleTime) < Config.FastAttackDelay then return end
    lastCycleTime = now
    
    -- Periodic cleanup (every 5 seconds)
    if (now - cleanupTimer) >= 5 then
        self:CleanupMobTracking()
        cleanupTimer = now
    end

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
        perfStartTime = now
    end
end

-- ==================== START/STOP ====================
function FastAttack:Start()
    if self.Running then return end
    self.Running = true

    Utils.DebugPrint("Starting Fast Attack V4...")

    self.Connection = Services.RunService.RenderStepped:Connect(function()
        self:Cycle()
        self:UpdatePerformance()
    end)

    print("[FastAttack V4] Started!")
end

function FastAttack:Stop()
    if not self.Running then return end
    self.Running = false

    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end

    print("[FastAttack V4] Stopped")
end

function FastAttack:Toggle()
    Config.FastAttack = not Config.FastAttack
    print("[FastAttack V4] Toggled:", Config.FastAttack and "ON" or "OFF")

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
            Config[key] = value
            Utils.DebugPrint("Config Update:", key, "=", value)
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
    
    -- Clear mob tracking on respawn
    FastAttack.MobTracking = {}

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
_ENV.FastAttackV4 = FastAttack

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
    print("=== FastAttack V4 Stats ===")
    print("Running:", FastAttack.Running)
    print("FastAttack:", Config.FastAttack)
    print("---")
    print("TPS:", FastAttack.Stats.TPS)
    print("Total Attacks:", FastAttack.Stats.TotalAttacks)
    print("Errors:", FastAttack.Stats.Errors)
    print("---")
    print("Tracked Mobs:", #FastAttack.MobTracking)
    print("Ghost Timeout:", Config.GhostMobTimeout, "seconds")
    print("Retry Delay:", Config.GhostMobRetryDelay, "seconds")
    print("---")
    print("Delay:", Config.FastAttackDelay)
    print("Distance:", Config.AttackDistance)
    print("Max Targets:", Config.MaxTargets)
    print("Priority:", Config.PriorityMode)
end

_ENV.FA_ClearGhosts = function()
    FastAttack.MobTracking = {}
    print("[FastAttack V4] Cleared all ghost mob tracking")
end

_ENV.FA_ListTracked = function()
    print("=== Tracked Mobs ===")
    local count = 0
    for mob, track in pairs(FastAttack.MobTracking) do
        if mob and mob.Parent then
            count = count + 1
            local status = track.confirmedGhost and "GHOST" or (track.suspectedGhost and "SUSPECTED" or "OK")
            print(string.format("%s [%s] - Attacks: %d, Time: %.1fs", 
                mob.Name, status, track.attackAttempts, tick() - track.firstSeen))
        end
    end
    print("Total:", count, "mobs")
end

_ENV.FA_GhostTimeout = function(seconds)
    if not seconds then
        print("Current Ghost Timeout:", Config.GhostMobTimeout)
        return
    end
    
    seconds = tonumber(seconds)
    if seconds and seconds > 0 then
        Config.GhostMobTimeout = seconds
        print("[FastAttack V4] Ghost Timeout set to:", seconds, "seconds")
    end
end

_ENV.FA_Help = function()
    print("=== FastAttack V4 ===")
    print("")
    print("BASIC COMMANDS:")
    print("  FA_Toggle()           - Toggle on/off")
    print("  FA_Start()            - Start attacking")
    print("  FA_Stop()             - Stop attacking")
    print("  FA_Stats()            - Show statistics")
    print("")
    print("GHOST MOB MANAGEMENT:")
    print("  FA_ListTracked()      - List all tracked mobs")
    print("  FA_ClearGhosts()      - Clear ghost mob tracking")
    print("  FA_GhostTimeout(15)   - Set ghost detection timeout")
    print("")
    print("DEBUGGING:")
    print("  FA_Debug()            - Toggle debug mode")
    print("")
    print("The system now properly handles:")
    print("  - Skill usage blocking")
    print("  - Mob repositioning/loading")
    print("  - Temporary attack blocks")
    print("  - True ghost mobs (15s timeout)")
end

-- ==================== AUTO-START ====================
if Config.FastAttack then
    task.wait(1)
    FastAttack:Start()
    print("[FastAttack V4] Auto-started")
end

print("FastAttack V4 Loaded - Type FA_Help() for commands")

return FastAttack