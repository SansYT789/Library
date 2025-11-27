local _ENV = getgenv and getgenv() or getfenv(2)

local Config = {
    Enabled = true,
    AttackMobs = true,
    AttackPlayers = true,

    -- Performance Settings
    AttackDistance = 65,
    MaxTargets = 15, -- Reduced for better performance
    AttackCooldown = 0,
    UpdateRate = 0.01, -- Target update throttle

    -- Combat Settings
    UseAdvancedHit = true,
    ComboMode = true,
    MaxCombo = 4,
    ComboResetTime = 0.15,

    -- Smart Targeting
    PrioritizeClosest = true,
    PrioritizeLowHealth = true,
    HealthWeightFactor = 0.6,
    IgnoreBoats = true,
    IgnoreForceField = true,
    RespectTeams = true,

    -- Tool-Based Auto Toggle
    AutoStopWithoutTool = true, -- Stop when no tool equipped
    ToolCheckInterval = 0.1, -- How often to check for tool

    -- Hitbox Optimization
    HitboxLimbs = {
        "Head", "UpperTorso", "HumanoidRootPart",
        "RightUpperArm", "LeftUpperArm"
    },

    -- Gun Settings
    AutoShootGuns = true,
    GunRange = 120,
    SpecialShoots = {
        ["Skull Guitar"] = "TAP",
        ["Bazooka"] = "Position",
        ["Cannon"] = "Position",
        ["Dragonstorm"] = "Overheat"
    },

    -- Performance Optimization
    SkipStunCheck = false,
    SkipBusyCheck = false,
    UseObjectPooling = true, -- Reuse tables to reduce GC

    DebugMode = false
}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")

local Player = Players.LocalPlayer
local Character, HRP, Humanoid

local Remotes = {}
local AdvancedFunctions = {}

-- Object Pooling for tables (reduce GC pressure)
local TablePool = {}
local function GetTable()
    return table.remove(TablePool) or {}
end

local function RecycleTable(t)
    table.clear(t)
    if #TablePool < 20 then
        table.insert(TablePool, t)
    end
end

local function DebugLog(...)
    if Config.DebugMode then
        print("[FastAttack]", ...)
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

    DebugLog("Character initialized")
    return HRP and Humanoid
end

local function IsEntityAlive(entity)
    if not entity or not entity.Parent then return false end
    local humanoid = entity:FindFirstChild("Humanoid")
    return humanoid and humanoid.Health > 0
end

local function CanAttack()
    if not Character or not Humanoid or not HRP then return false end
    if not Character.Parent then return false end

    local tool = Character:FindFirstChildOfClass("Tool")
    if not tool then return false end

    if not Config.SkipStunCheck then
        local stun = Character:FindFirstChild("Stun")
        if stun and stun.Value > 0 then return false end
    end

    if not Config.SkipBusyCheck then
        local busy = Character:FindFirstChild("Busy")
        if busy and busy.Value then return false end
    end

    if Humanoid.Sit then
        local tooltip = tool.ToolTip
        if tooltip ~= "Sword" and tooltip ~= "Melee" and tooltip ~= "Blox Fruit" and tooltip ~= "Gun" then
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
    -- Try preferred limbs first
    for _, limbName in ipairs(Config.HitboxLimbs) do
        local limb = enemy:FindFirstChild(limbName)
        if limb then return limb end
    end

    return enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart
end

-- Smart target scoring system
local function CalculateTargetScore(enemy, distance, health, maxHealth)
    if not Config.PrioritizeLowHealth then
        return -distance -- Just use distance
    end

    -- Normalize values (0-1)
    local distScore = 1 - (distance / Config.AttackDistance)
    local healthScore = 1 - (health / math.max(maxHealth, 1))

    -- Weighted combination
    local weight = Config.HealthWeightFactor
    return (healthScore * weight) + (distScore * (1 - weight))
end

local LastTargetUpdate = 0
local CachedTargets = {}
local function GetAllTargets()
    if not HRP or not Config.Enabled then return {} end

    local now = tick()

    -- Throttle target updates for performance
    if (now - LastTargetUpdate) < Config.UpdateRate and #CachedTargets > 0 then
        return CachedTargets
    end

    LastTargetUpdate = now

    local targets = Config.UseObjectPooling and GetTable() or {}
    local hrpPos = HRP.Position
    local maxDist = Config.AttackDistance

    if Config.AttackMobs then
        local enemies = Workspace:FindFirstChild("Enemies")
        if enemies then
            for _, enemy in ipairs(enemies:GetChildren()) do
                if #targets >= Config.MaxTargets then break end

                if Config.IgnoreBoats and (
                    enemy:GetAttribute("IsBoat") or 
                    enemy.Name == "FishBoat" or 
                    enemy.Name == "PirateBrigade" or 
                    enemy.Name == "PirateGrandBrigade"
                ) then
                    continue
                end

                local hrp = enemy:FindFirstChild("HumanoidRootPart")
                if not hrp then continue end

                local dist = (hrp.Position - hrpPos).Magnitude
                if dist > maxDist then continue end

                if not IsEntityAlive(enemy) then continue end

                local humanoid = enemy:FindFirstChild("Humanoid")
                local health = humanoid and humanoid.Health or 0
                local maxHealth = humanoid and humanoid.MaxHealth or 100

                local hitbox = GetOptimalHitbox(enemy)
                if hitbox then
                    local score = CalculateTargetScore(enemy, dist, health, maxHealth)
                    table.insert(targets, {enemy, hitbox, dist, score, health})
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

                local humanoid = enemy:FindFirstChild("Humanoid")
                local health = humanoid and humanoid.Health or 0
                local maxHealth = humanoid and humanoid.MaxHealth or 100

                local hitbox = enemy:FindFirstChild("Head") or hrp
                local score = CalculateTargetScore(enemy, dist, health, maxHealth)
                table.insert(targets, {enemy, hitbox, dist, score, health})
            end
        end
    end

    -- Sort by score (higher is better)
    if #targets > 1 then
        table.sort(targets, function(a, b) return a[4] > b[4] end)
    end

    -- Cache and recycle old cached targets
    if Config.UseObjectPooling and #CachedTargets > 0 then
        RecycleTable(CachedTargets)
    end
    CachedTargets = targets

    return targets
end

local ComboTracker = {Count = 0, LastHit = 0}
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

    if ShootType == "Position" or (ShootType == "TAP" and tool:FindFirstChild("RemoteEvent")) then
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

local AttackDebounce = 0
local LastToolCheck = 0
local HasTool = false
local function AttackCycle()
    if not Config.Enabled then return end

    local now = tick()

    -- Tool-based auto toggle
    if Config.AutoStopWithoutTool and (now - LastToolCheck) >= Config.ToolCheckInterval then
        LastToolCheck = now
        local currentTool = Character and Character:FindFirstChildOfClass("Tool")
        HasTool = currentTool ~= nil

        if not HasTool then
            return -- Skip attack cycle if no tool
        end
    end

    if not CanAttack() then return end
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
    elseif tooltip == "Gun" then
        local closestTarget = targets[1]
        if closestTarget and closestTarget[3] <= Config.GunRange then
            ExecuteGunAttack(tool, closestTarget[2].Position)
        end
    elseif tooltip == "Melee" or tooltip == "Sword" then
        ExecuteMeleeAttack(targets, combo)
    end
end

local FastAttack = {
    Running = false,
    Connection = nil
}

function FastAttack:Start()
    if self.Running then return end
    self.Running = true

    if not InitializeCharacter() then
        DebugLog("Failed to initialize character!")
        self.Running = false
        return
    end

    if not Remotes.RegisterAttack or not Remotes.RegisterHit then
        if not InitializeRemotes() then
            DebugLog("Failed to initialize remotes!")
            self.Running = false
            return
        end
    end

    -- Use Heartbeat for maximum performance
    self.Connection = RunService.Heartbeat:Connect(function()
        pcall(AttackCycle)
    end)

    DebugLog("✅ Started")
end

function FastAttack:Stop()
    if not self.Running then return end
    self.Running = false

    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end

    DebugLog("⏸️ Stopped")
end

function FastAttack:Toggle()
    Config.Enabled = not Config.Enabled
    DebugLog(Config.Enabled and "✅ ON" or "❌ OFF")
end

function FastAttack:SetEnabled(state)
    if Config.Enabled ~= state then
        Config.Enabled = state

        if Config.Enabled and not self.Running then
            FastAttack:Start()
        elseif not Config.Enabled and self.Running then
            FastAttack:Stop()
        end
        DebugLog("Set to:", state and "✅ ON" or "❌ OFF")
    end
end

function FastAttack:UpdateConfig(newConfig)
    if not newConfig or type(newConfig) ~= "table" then return end
    for key, value in pairs(newConfig) do
        if Config[key] ~= nil then
            Config[key] = value
        end
    end
    DebugLog("Config updated")
end

-- Character respawn handler
Player.CharacterAdded:Connect(function()
    task.wait(1)
    InitializeCharacter()
    ComboTracker = {Count = 0, LastHit = 0}
    CachedTargets = {}

    if FastAttack.Running then
        FastAttack:Stop()
        task.wait(0.5)
        FastAttack:Start()
    end
end)

-- Initial setup
InitializeCharacter()
InitializeRemotes()

-- Disable camera shake
pcall(function()
    local CameraShaker = require(ReplicatedStorage.Util.CameraShaker)
    CameraShaker:Stop()
end)

-- Export
_ENV.FastAttack = FastAttack
_ENV.FastAttackConfig = Config

-- Auto-start
if Config.Enabled then
    task.spawn(function()
        task.wait(1)
        FastAttack:Start()
    end)
end
print("Fast Attack Loaded")

return FastAttack