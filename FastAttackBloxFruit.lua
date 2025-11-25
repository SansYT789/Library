local _ENV = getgenv and getgenv() or getfenv(2)

local Config = {
    Enabled = true,
    AttackMobs = true,
    AttackPlayers = true,
    
    -- Performance Settings
    AttackDistance = 65,
    MaxTargets = 25,
    AttackCooldown = 0.05,
    
    -- Combat Settings
    UseAdvancedHit = true, -- Use advanced hit function if available
    ComboMode = true,
    MaxCombo = 4,
    ComboResetTime = 0.35,
    
    -- Targeting Priority
    PrioritizeClosest = true,
    IgnoreBoats = true,
    IgnoreForceField = true,
    RespectTeams = true,
    
    -- Ghost Detection (Anti-Stuck)
    GhostDetection = true,
    GhostTimeout = 10,
    GhostRetryAttempts = 5,
    
    -- Hitbox Optimization
    HitboxLimbs = {
        "RightLowerArm", "RightUpperArm", "LeftLowerArm", "LeftUpperArm",
        "RightHand", "LeftHand", "Head", "UpperTorso"
    },
    
    -- Gun Settings
    AutoShootGuns = true,
    GunRange = 120,
    
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

local function InitializeRemotes()
    local success = pcall(function()
        local Modules = ReplicatedStorage:WaitForChild("Modules", 10)
        local Net = Modules:WaitForChild("Net", 10)
        
        Remotes.RegisterAttack = Net:WaitForChild("RE/RegisterAttack", 10)
        Remotes.RegisterHit = Net:WaitForChild("RE/RegisterHit", 10)
        Remotes.ShootGunEvent = Net:FindFirstChild("RE/ShootGunEvent")
        Remotes.Modules = Modules
        
        -- Try to get combat flags
        pcall(function()
            AdvancedFunctions.CombatFlags = require(Modules.Flags).COMBAT_REMOTE_THREAD
        end)
        
        -- Try to get advanced hit function
        pcall(function()
            local LocalScript = Player:WaitForChild("PlayerScripts"):FindFirstChildOfClass("LocalScript")
            if LocalScript and getsenv then
                AdvancedFunctions.HitFunction = getsenv(LocalScript)._G.SendHitsToServer
            end
        end)
        
        -- Try to get gun validator
        pcall(function()
            Remotes.GunValidator = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Validator2")
            local CombatController = require(ReplicatedStorage.Controllers.CombatController)
            AdvancedFunctions.ShootFunction = getupvalue(CombatController.Attack, 9)
        end)
    end)
    
    return success
end

local function InitializeCharacter()
    Character = Player.Character or Player.CharacterAdded:Wait()
    HRP = Character:WaitForChild("HumanoidRootPart", 5)
    Humanoid = Character:WaitForChild("Humanoid", 5)
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
    
    -- Check if health is changing (not a ghost)
    if currentHealth < track.lastHealth then
        track.lastHealth = currentHealth
        track.firstSeen = tick()
        track.attempts = 0
        return false
    end
    
    -- Mark as ghost if stuck too long
    if timeSinceFirst > Config.GhostTimeout and track.attempts > Config.GhostRetryAttempts then
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
    if not entity then return false end
    local humanoid = entity:FindFirstChild("Humanoid")
    return humanoid and humanoid.Health > 0
end

local function CanAttack()
    if not Character or not Humanoid or not HRP then return false end
    
    local tool = Character:FindFirstChildOfClass("Tool")
    if not tool then return false end
    
    -- Check stun/busy status
    local stun = Character:FindFirstChild("Stun")
    local busy = Character:FindFirstChild("Busy")
    
    if (stun and stun.Value > 0) or (busy and busy.Value) then
        return false
    end
    
    -- Check if sitting (some weapons allow attacking while sitting)
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

-- ==================== TARGET ACQUISITION ====================
local function GetOptimalHitbox(enemy)
    -- Try to get a random limb for better hit registration
    for i = 1, 3 do
        local limbName = Config.HitboxLimbs[math.random(#Config.HitboxLimbs)]
        local limb = enemy:FindFirstChild(limbName)
        if limb then return limb end
    end
    
    -- Fallback to primary parts
    return enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart
end

local function GetAllTargets()
    if not HRP or not Config.Enabled then return {} end
    
    local targets = {}
    local hrpPos = HRP.Position
    local maxDist = Config.AttackDistance
    
    -- Scan Enemies (Mobs)
    if Config.AttackMobs then
        local enemies = Workspace:FindFirstChild("Enemies")
        if enemies then
            for _, enemy in ipairs(enemies:GetChildren()) do
                if #targets >= Config.MaxTargets then break end
                
                -- Skip boats and special entities
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
                
                -- Ghost detection
                if IsGhostEnemy(enemy) then continue end
                
                local hitbox = GetOptimalHitbox(enemy)
                if hitbox then
                    table.insert(targets, {enemy, hitbox, dist})
                end
            end
        end
    end
    
    -- Scan Players
    if Config.AttackPlayers and not IsInSafeZone() then
        local chars = Workspace:FindFirstChild("Characters")
        if chars then
            for _, enemy in ipairs(chars:GetChildren()) do
                if #targets >= Config.MaxTargets then break end
                if enemy == Character then continue end
                
                -- Team check
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
    
    -- Sort by distance if priority enabled
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
    
    -- Fire attack registration
    pcall(function()
        Remotes.RegisterAttack:FireServer(combo or 0)
    end)
    
    -- Fire hit registration with advanced function if available
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

local function ExecuteGunAttack(tool, targetPos)
    if not Config.AutoShootGuns or not targetPos then return end
    
    local cooldown = tool:FindFirstChild("Cooldown") and tool.Cooldown.Value or 0.3
    
    -- Update shot count for validation
    pcall(function()
        tool:SetAttribute("LocalTotalShots", (tool:GetAttribute("LocalTotalShots") or 0) + 1)
    end)
    
    -- Try to use gun validator
    pcall(function()
        if Remotes.GunValidator and AdvancedFunctions.ShootFunction then
            local v1, v2 = GetGunValidator()
            if v1 then
                Remotes.GunValidator:FireServer(v1, v2)
            end
        end
    end)
    
    -- Fire gun event
    pcall(function()
        if tool:FindFirstChild("RemoteEvent") then
            tool.RemoteEvent:FireServer("TAP", targetPos)
        elseif Remotes.ShootGunEvent then
            Remotes.ShootGunEvent:FireServer(targetPos)
        else
            -- Fallback to virtual mouse click
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
        end
    end)
    
    task.wait(cooldown)
end

local LastAttack = 0
local AttackDebounce = 0

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
    
    -- Execute attack based on weapon type
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
    
    -- Cleanup ghosts periodically
    CleanGhostTracker()
end

local FastAttack = {
    Running = false,
    Connection = nil
}

function FastAttack:Start()
    if self.Running then return end
    self.Running = true
    
    self.Connection = RunService.Heartbeat:Connect(function()
        pcall(AttackCycle)
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
    Config.Enabled = not Config.Enabled
    print("[FastAttack] Toggled:", Config.Enabled and "ON" or "OFF")
end

function FastAttack:SetEnabled(state)
    if Config.Enabled ~= state then
        Config.Enabled = state
        print("[FastAttack] Set to:", state and "ON" or "OFF")
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

Player.CharacterAdded:Connect(function(newChar)
    task.wait(0.5)
    InitializeCharacter()
    GhostTracker = {}
    ComboTracker = {Count = 0, LastHit = 0}
    
    if FastAttack.Running then
        FastAttack:Stop()
        task.wait(0.3)
        FastAttack:Start()
    end
end)

InitializeCharacter()
if not InitializeRemotes() then
    warn("[FastAttack] Failed to initialize remotes! Please rejoin or report this issue.")
    return nil
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
    task.wait(1)
    FastAttack:Start()
end

return FastAttack