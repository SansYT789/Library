local _ENV = getgenv and getgenv() or getfenv(2)

local Config = {
    FastAttack = true,
    AttackMobs = true,
    AttackPlayers = false,
    
    -- Performance
    AttackDelay = 0,  -- No delay for maximum speed
    AttackDistance = 60,
    MaxTargets = 20,
    
    -- Filters
    IgnoreForceField = true,
    RespectTeams = true,
    MinHealthPercent = 0,  -- Attack even at 1% HP
    
    -- Ghost Detection (SIMPLIFIED)
    GhostTimeout = 8,  -- Much shorter timeout
    GhostRetryAttempts = 3,  -- Retry a few times before skipping
    
    DebugMode = false
}

-- ==================== SERVICES ====================
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer
local Character, HRP, Humanoid

-- ==================== INITIALIZATION ====================
local function InitCharacter()
    Character = Player.Character or Player.CharacterAdded:Wait()
    HRP = Character:WaitForChild("HumanoidRootPart", 5)
    Humanoid = Character:WaitForChild("Humanoid", 5)
    return HRP and Humanoid
end

local function InitRemotes()
    local Modules = RS:WaitForChild("Modules", 10)
    if not Modules then return nil end
    
    local Net = Modules:WaitForChild("Net", 10)
    if not Net then return nil end
    
    return {
        RegisterAttack = Net:WaitForChild("RE/RegisterAttack", 10),
        RegisterHit = Net:WaitForChild("RE/RegisterHit", 10),
        Modules = Modules
    }
end

InitCharacter()
local Remotes = InitRemotes()
if not Remotes then
    warn("[FastAttack] Failed to initialize remotes!")
    return
end

-- Try to get advanced combat function
local HitFunction
pcall(function()
    local localScript = Player:WaitForChild("PlayerScripts"):FindFirstChildOfClass("LocalScript")
    if localScript and getsenv then
        HitFunction = getsenv(localScript)._G.SendHitsToServer
    end
end)

local CombatFlags
pcall(function()
    CombatFlags = require(Remotes.Modules.Flags).COMBAT_REMOTE_THREAD
end)

-- ==================== GHOST DETECTION (SIMPLIFIED) ====================
local GhostTracker = {}

local function IsGhost(enemy)
    if not Config.GhostTimeout then return false end
    
    local track = GhostTracker[enemy]
    if not track then
        -- First time seeing this enemy
        GhostTracker[enemy] = {
            firstSeen = tick(),
            attempts = 0
        }
        return false
    end
    
    local timeSinceFirst = tick() - track.firstSeen
    
    -- If we've been attacking this mob for too long, it's probably a ghost
    if timeSinceFirst > Config.GhostTimeout and track.attempts > Config.GhostRetryAttempts then
        return true
    end
    
    track.attempts = track.attempts + 1
    return false
end

local function CleanGhostTracker()
    for enemy, data in pairs(GhostTracker) do
        if not enemy or not enemy.Parent then
            GhostTracker[enemy] = nil
        end
    end
end

-- ==================== UTILITIES ====================
local function IsAlive(char)
    if not char then return false end
    local h = char:FindFirstChild("Humanoid")
    return h and h.Health > 0
end

local function CanAttack()
    if not Character or not Humanoid then return false end
    
    local tool = Character:FindFirstChildOfClass("Tool")
    if not tool then return false end
    
    -- Check stun/busy
    local stun = Character:FindFirstChild("Stun")
    local busy = Character:FindFirstChild("Busy")
    
    if (stun and stun.Value > 0) or (busy and busy.Value) then
        return false
    end
    
    -- Don't attack while sitting (unless using certain weapons)
    if Humanoid.Sit then
        local tt = tool.ToolTip
        if tt ~= "Sword" or tt ~= "Melee" or tt ~= "Blox Fruit" or tt ~= "Gun" then
            return false
        end
    end
    
    return true
end

local function GetTargets()
    if not HRP then return {} end
    
    local targets = {}
    local hrpPos = HRP.Position
    local maxDist = Config.AttackDistance
    
    -- Scan enemies
    if Config.AttackMobs then
        local enemies = Workspace:FindFirstChild("Enemies")
        if enemies then
            for _, enemy in ipairs(enemies:GetChildren()) do
                if #targets >= Config.MaxTargets then break end
                
                if enemy.Name == "FishBoat" or mob.Name == "PirateBrigade" or mob.Name == "PirateGrandBrigade" then continue end
                
                local hrp = enemy:FindFirstChild("HumanoidRootPart")
                if not hrp then continue end
                
                -- Fast distance check
                local dist = (hrp.Position - hrpPos).Magnitude
                if dist > maxDist then continue end
                
                -- Alive check
                if not IsAlive(enemy) then continue end
                
                -- Ghost check (simplified)
                if IsGhost(enemy) then continue end
                
                -- Get hitbox (prefer limbs for better registration)
                local hitboxLimbs = {
                    "RightLowerArm", "RightUpperArm", "LeftLowerArm", "LeftUpperArm",
                    "RightHand", "LeftHand", "Head", "UpperTorso"
                }
                
                local hitbox = nil
                for _, limbName in ipairs(hitboxLimbs) do
                    hitbox = enemy:FindFirstChild(limbName)
                    if hitbox then break end
                end
                
                if not hitbox then
                    hitbox = enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart
                end
                
                if hitbox then
                    table.insert(targets, {enemy, hitbox})
                end
            end
        end
    end
    
    -- Scan players
    if Config.AttackPlayers then
        local chars = Workspace:FindFirstChild("Characters")
        if chars then
            for _, enemy in ipairs(chars:GetChildren()) do
                if #targets >= Config.MaxTargets then break end
                if enemy == Character then continue end
                
                local hrp = enemy:FindFirstChild("HumanoidRootPart")
                if not hrp then continue end
                
                local dist = (hrp.Position - hrpPos).Magnitude
                if dist > maxDist then continue end
                
                if not IsAlive(enemy) then continue end
                
                -- Team check
                if Config.RespectTeams then
                    local enemyPlayer = Players:GetPlayerFromCharacter(enemy)
                    if enemyPlayer and Player.Team and enemyPlayer.Team == Player.Team then
                        continue
                    end
                end
                
                if Config.IgnoreForceField then
                    local gui = Player:FindFirstChild("PlayerGui")
			        if gui then
			            local main = gui:FindFirstChild("Main")
			            if main then
			                local bottomHUD = main:FindFirstChild("BottomHUDList")
			                if bottomHUD then
			                    local safeZone = bottomHUD:FindFirstChild("SafeZone")
								local pvpDisabled = main:FindFirstChild("PvpDisabled")
			                    if (safeZone and safeZone.Visible == true) or (pvpDisabled and pvpDisabled.Visible == true) then
									continue
								end
			                end
			            end
			        end
                end
                
                local head = enemy:FindFirstChild("Head") or hrp
                table.insert(targets, {enemy, head})
            end
        end
    end
    
    return targets
end

local function ExecuteAttack(targets)
    if not targets or #targets == 0 then return end
    
    local mainTarget = targets[1][2]  -- Use first target's hitbox as main
    
    -- Fire attack
    pcall(function()
        Remotes.RegisterAttack:FireServer(0)
    end)
    
    -- Fire hit
    pcall(function()
        if CombatFlags and HitFunction then
            HitFunction(mainTarget, targets)
        else
            Remotes.RegisterHit:FireServer(mainTarget, targets)
        end
    end)
end

local FastAttack = {
    Running = false,
    Connection = nil,
    LastCleanup = 0
}

function FastAttack:Cycle()
    if not Config.FastAttack then return end
    if not CanAttack() then return end
    
    local targets = GetTargets()
    if #targets > 0 then
        ExecuteAttack(targets)
    end
    
    -- Periodic cleanup
    local now = tick()
    if (now - self.LastCleanup) > 5 then
        CleanGhostTracker()
        self.LastCleanup = now
    end
end

function FastAttack:Start()
    if self.Running then return end
    self.Running = true
    
    self.Connection = RunService.Heartbeat:Connect(function()
        self:Cycle()
    end)
    
    print("[FastAttack] Started!")
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
    Config.FastAttack = not Config.FastAttack
    print("[FastAttack] Toggled:", Config.FastAttack and "ON" or "OFF")
end

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

Player.CharacterAdded:Connect(function(newChar)
    task.wait(0.5)
    InitCharacter()
    GhostTracker = {}
    
    if FastAttack.Running then
        FastAttack:Stop()
        task.wait(0.3)
        FastAttack:Start()
    end
end)

_ENV.FastAttack = FastAttack
if Config.FastAttack then
    task.wait(1)
    FastAttack:Start()
end

print("[FastAttack] Loaded")
return FastAttack