-- ==================== FAST ATTACK SYSTEM V4 - FIXED & STREAMLINED ====================
-- FIXED: Player detection, target prioritization, continuous attack flow
-- OPTIMIZED: Removed unnecessary features, lighter code, accurate nearest targeting

local _ENV = getgenv and getgenv() or getfenv(2)

-- ==================== CONFIGURATION ====================
local Config = {
    -- Core Settings
    FastAttack = false,
    AttackMob = true,
    AttackPlayers = false,
    DebugMode = false,

    -- Performance
    FastAttackDelay = 0.02,
    ClickDelay = 0,
    AttackDistance = 500,
    MaxTargets = 15,

    -- Priority Settings
    PriorityMode = "Nearest",       -- "Nearest", "Lowest HP", "Highest HP"
    
    -- Filters
    IgnoreForceField = true,
    RespectTeams = true,
    MinHealthPercent = 0.01,
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
    }
}

-- ==================== SIMPLE VALIDATION ====================
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
            Utils.DebugPrint("Skipping mob (AttackMob disabled):", enemy.Name)
            return false 
        end
        Utils.DebugPrint("Valid mob:", enemy.Name)
        return true
    end

    -- PLAYER VALIDATION
    if not Config.AttackPlayers then 
        Utils.DebugPrint("Skipping player (AttackPlayers disabled):", enemy.Name)
        return false 
    end

    -- Self check
    if enemyPlayer == Player then 
        Utils.DebugPrint("Skipping self")
        return false 
    end

    -- Team check
    if Config.RespectTeams and Player.Team and enemyPlayer.Team then
        if enemyPlayer.Team == Player.Team then
            Utils.DebugPrint("Skipping teammate:", enemy.Name)
            return false
        end
    end

    -- PvP/SafeZone checks (cached for performance)
    local now = tick()
    
    -- Check cache first
    if (now - self.Cache.SafeZoneCheck.time) > 0.5 then
        local gui = Player:FindFirstChild("PlayerGui")
        if gui then
            local main = gui:FindFirstChild("Main")
            if main then
                -- Check SafeZone
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
        Utils.DebugPrint("In SafeZone, skipping player")
        return false
    end

    -- Check PvP disabled
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
        Utils.DebugPrint("PvP disabled, skipping player")
        return false
    end

    Utils.DebugPrint("Valid player:", enemy.Name)
    return true
end

-- ==================== TARGET ACQUISITION ====================
function FastAttack:GetTargets()
    local targets = {}
    local maxDist = Config.AttackDistance

    local function scanFolder(folder, folderName)
        if not folder then return end

        Utils.DebugPrint("Scanning", folderName)
        
        for _, enemy in ipairs(folder:GetChildren()) do
            if #targets >= Config.MaxTargets then break end

            -- Get head for distance
            local head = enemy:FindFirstChild("Head")
            if not head then continue end

            -- Distance check FIRST (fastest rejection)
            local dist = Utils.GetDistance(head.Position)
            if dist >= maxDist then continue end

            -- Then validate
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

    -- IMPORTANT: Scan order matters for consistent behavior
    -- Always scan in same order each cycle
    if Config.AttackMob and Refs.Enemies then 
        scanFolder(Refs.Enemies, "Enemies")
    end

    if Config.AttackPlayers and Refs.Characters then 
        scanFolder(Refs.Characters, "Characters")
    end

    Utils.DebugPrint("Found", #targets, "valid targets")

    -- Sort ONCE after all targets collected
    if #targets > 1 then
        if Config.PriorityMode == "Nearest" then
            table.sort(targets, function(a, b) return a.distance < b.distance end)
        elseif Config.PriorityMode == "Lowest HP" then
            table.sort(targets, function(a, b) return a.hp < b.hp end)
        elseif Config.PriorityMode == "Highest HP" then
            table.sort(targets, function(a, b) return a.hp > b.hp end)
        end
    end

    -- Debug first target
    if #targets > 0 then
        Utils.DebugPrint("Primary target:", targets[1].entity.Name, "Distance:", math.floor(targets[1].distance))
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

    -- Execute attack (simple, no retries)
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

function FastAttack:Cycle()
    -- Check if enabled
    if not Config.FastAttack then return end

    -- Check if alive
    if not Utils.IsAlive(Character) then return end

    -- Check weapon
    local tool = Character:FindFirstChildOfClass("Tool")
    if not tool then return end
    if tool.ToolTip == "Gun" then return end

    -- Delay check
    local now = tick()
    if (now - lastCycleTime) < Config.FastAttackDelay then return end
    lastCycleTime = now

    -- Get fresh targets EVERY cycle (no caching issues)
    local targets = self:GetTargets()
    
    if #targets > 0 then
        self:ExecuteAttack(targets)
    else
        Utils.DebugPrint("No valid targets found")
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

    -- Single primary loop (RenderStepped for best performance)
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

    -- Handle FastAttack toggle
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

-- Simple commands
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
    print("Delay:", Config.FastAttackDelay)
    print("Distance:", Config.AttackDistance)
    print("Max Targets:", Config.MaxTargets)
    print("Priority:", Config.PriorityMode)
    print("---")
    print("Attack Mobs:", Config.AttackMob)
    print("Attack Players:", Config.AttackPlayers)
    print("Respect Teams:", Config.RespectTeams)
end

_ENV.FA_AttackMobs = function(enabled)
    if enabled == nil then
        Config.AttackMob = not Config.AttackMob
    else
        Config.AttackMob = enabled == true or enabled == "true" or enabled == "on"
    end
    print("[FastAttack V4] Attack Mobs:", Config.AttackMob and "ON" or "OFF")
end

_ENV.FA_AttackPlayers = function(enabled)
    if enabled == nil then
        Config.AttackPlayers = not Config.AttackPlayers
    else
        Config.AttackPlayers = enabled == true or enabled == "true" or enabled == "on"
    end
    print("[FastAttack V4] Attack Players:", Config.AttackPlayers and "ON" or "OFF")
end

_ENV.FA_Priority = function(mode)
    if not mode then
        print("Current Priority:", Config.PriorityMode)
        print("Options: Nearest, Lowest HP, Highest HP")
        return
    end
    
    local validModes = {
        ["Nearest"] = true,
        ["Lowest HP"] = true,
        ["Highest HP"] = true
    }
    
    if validModes[mode] then
        Config.PriorityMode = mode
        print("[FastAttack V4] Priority set to:", mode)
    else
        print("[FastAttack V4] Invalid mode. Use: Nearest, Lowest HP, or Highest HP")
    end
end

_ENV.FA_Delay = function(delay)
    if not delay then
        print("Current Delay:", Config.FastAttackDelay)
        return
    end
    
    delay = tonumber(delay)
    if not delay or delay < 0 then
        print("[FastAttack V4] Invalid delay")
        return
    end
    
    Config.FastAttackDelay = delay
    print("[FastAttack V4] Delay set to:", delay)
end

_ENV.FA_Distance = function(distance)
    if not distance then
        print("Current Distance:", Config.AttackDistance)
        return
    end
    
    distance = tonumber(distance)
    if not distance or distance <= 0 then
        print("[FastAttack V4] Invalid distance")
        return
    end
    
    Config.AttackDistance = distance
    print("[FastAttack V4] Distance set to:", distance)
end

_ENV.FA_MaxTargets = function(max)
    if not max then
        print("Current Max Targets:", Config.MaxTargets)
        return
    end
    
    max = tonumber(max)
    if not max or max <= 0 then
        print("[FastAttack V4] Invalid value")
        return
    end
    
    Config.MaxTargets = max
    print("[FastAttack V4] Max Targets set to:", max)
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
        print("[FastAttack V4] Invalid setting:", setting)
        return
    end
    
    if value == nil then
        print(setting, "=", tostring(Config[setting]))
        return
    end
    
    -- Type conversion
    if value == "true" then value = true
    elseif value == "false" then value = false
    elseif tonumber(value) then value = tonumber(value)
    end
    
    FastAttack:UpdateConfig({[setting] = value})
    print("[FastAttack V4]", setting, "set to", tostring(value))
end

_ENV.FA_Help = function()
    print("=== FastAttack V4 - Fixed & Optimized ===")
    print("")
    print("BASIC COMMANDS:")
    print("  FA_Toggle()           - Toggle on/off")
    print("  FA_Start()            - Start attacking")
    print("  FA_Stop()             - Stop attacking")
    print("  FA_Stats()            - Show statistics")
    print("")
    print("CONFIGURATION:")
    print("  FA_AttackMobs()       - Toggle mob attacking")
    print("  FA_AttackPlayers()    - Toggle player attacking")
    print("  FA_Priority('mode')   - Set priority (Nearest/Lowest HP/Highest HP)")
    print("  FA_Delay(0.02)        - Set attack delay")
    print("  FA_Distance(500)      - Set attack range")
    print("  FA_MaxTargets(15)     - Set max targets")
    print("  FA_Config()           - Show all settings")
    print("")
    print("DEBUGGING:")
    print("  FA_Debug()            - Toggle debug mode")
    print("")
    print("Example: FA_AttackPlayers(true) or FA_AttackPlayers('on')")
end

-- ==================== AUTO-START ====================
if Config.FastAttack then
    task.wait(1)
    FastAttack:Start()
    print("[FastAttack V4] Auto-started")
end

print("[FastAttack V4] Loaded - Type FA_Help() for commands")

return FastAttack