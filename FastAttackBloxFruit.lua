--// ============================================
--// FAST ATTACK SYSTEM - STABLE EDITION
--// ============================================

_G.FastAttackConfig = _G.FastAttackConfig or {
    Enabled = true,
    AutoClick = true,
    ClickDelay = 0,
    AttackDelay = 0,
    UpdateRate = 0.01,
    MaxAttackDistance = 200000,
    OptimalDistance = 50,
    AttackMobs = true,
    AttackPlayers = true,
    AttackBosses = true,
    PrioritizeBosses = true,
    CheckAlive = true,
    CheckEquipped = true,
    IgnoreGuns = true,
    MultiTarget = true,
    MaxTargets = 10,
    UseRenderStepped = false,
    DebugMode = false
}

local Config = _G.FastAttackConfig
local Services = setmetatable({}, {
    __index = function(_, service)
        return game:GetService(service)
    end
})
local Player = Services.Players.LocalPlayer
if not Player then return end

local Remotes = Services.ReplicatedStorage:FindFirstChild("Remotes")
local RegisterAttack = Remotes and Remotes:FindFirstChild("RE/RegisterAttack")
local RegisterHit = Remotes and Remotes:FindFirstChild("RE/RegisterHit")
local Enemies = workspace:FindFirstChild("Enemies")
local Characters = workspace:FindFirstChild("Characters")

local function IsAlive(model)
    local hum = model:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function GetDistance(pos)
    local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    return hrp and (hrp.Position - pos).Magnitude or math.huge
end

local function IsBoss(enemy)
    return enemy and string.find(enemy.Name, "Boss")
end

local function IsValidTarget(enemy)
    if not enemy or not IsAlive(enemy) then return false end
    if enemy == Player.Character then return false end
    local head = enemy:FindFirstChild("Head")
    if not head then return false end
    if GetDistance(head.Position) > Config.MaxAttackDistance then return false end
    return true
end

local function CollectTargets()
    local targets = {}
    local function scan(folder)
        for _, e in pairs(folder:GetChildren()) do
            if #targets >= Config.MaxTargets then break end
            if IsValidTarget(e) then
                local head = e:FindFirstChild("Head")
                if head then table.insert(targets, {e, head}) end
            end
        end
    end
    if Config.AttackMobs and Enemies then scan(Enemies) end
    if Config.AttackPlayers and Characters then scan(Characters) end
    if Config.PrioritizeBosses then
        table.sort(targets, function(a,b)
            local A,B=IsBoss(a[1]),IsBoss(b[1])
            if A~=B then return A and not B end
            return GetDistance(a[2].Position)<GetDistance(b[2].Position)
        end)
    end
    return targets
end

local FastAttack = {
    Active = false,
    LastTick = 0,
    Connection = nil
}

function FastAttack:AttackOnce()
    if not Config.Enabled or not Player.Character then return end
    if tick() - self.LastTick < Config.AttackDelay then return end
    self.LastTick = tick()

    local tool = Player.Character:FindFirstChildOfClass("Tool")
    if Config.CheckEquipped and (not tool or (Config.IgnoreGuns and tool.ToolTip == "Gun")) then return end

    local targets = CollectTargets()
    if #targets == 0 then return end
    local base = targets[1][2]

    local success, err = pcall(function()
        if RegisterAttack then RegisterAttack:FireServer(Config.ClickDelay) end
        if RegisterHit then RegisterHit:FireServer(base, targets) end
    end)
    if not success then warn("[FastAttack Error]", err) end
end

function FastAttack:Start()
    if self.Active then return end
    self.Active = true
    print("[FastAttack] Started.")

    local RS = Config.UseRenderStepped and Services.RunService.RenderStepped or Services.RunService.Heartbeat

    self.Connection = RS:Connect(function()
        if not Config.Enabled then return end
        if not IsAlive(Player.Character or {}) then
            -- nếu chết thì đợi hồi sinh rồi chạy lại
            repeat Services.RunService.Heartbeat:Wait() until IsAlive(Player.Character or {})
        end
        pcall(function() self:AttackOnce() end)
    end)
end

function FastAttack:Stop()
    if not self.Active then return end
    self.Active = false
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
    print("[FastAttack] Stopped.")
end

FastAttack:Start()
_G.FastAttackAPI = {
    Toggle = function(state)
        Config.Enabled = state
        if state then FastAttack:Start() else FastAttack:Stop() end
    end,
    SetDelay = function(v) Config.AttackDelay = v end,
    SetDistance = function(v) Config.MaxAttackDistance = v end
}

return FastAttack