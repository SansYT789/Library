-- ===============================
-- 🦅 AFK Bot Headless (No UI)
-- ===============================

--// Services
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local Workspace = workspace
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ChatService = game:GetService("Chat")

--// Player references
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HRP = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

--// Config
local Config = {
    WalkRange = 50,
    AvoidDistance = 15,
    StepBack = 10,
    JumpWhenSit = true,
    IdleDanceTimeRange = {25,65},
    IdleJumpTimeRange = {10,35},
    StuckCheckSeconds = 10,
    StuckTPSeconds = 150,
    PathAgent = {
        AgentRadius = 3.5,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentCanClimb = true,
        AgentJumpHeight = 7,
        AgentMaxSlope = 45,
    },
    PathRetryDelay = 2,
    BlockedPathTTL = 120,
    MaxBlockedEntries = 100,
    CheckBlockedEvery = 30,
    StuckTeleportTries = 12,
    TPSearchRadius = 40
}

-- Auto reply
local AutoReplyKeywords = {"plss","pls","trade","pet","fruit","money","garden"}
local AutoReplyMessages = {"no","nah","sorry","nope","not giving"}

-- Raycast params
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Blacklist
rayParams.FilterDescendantsInstances = {Character}

-- Helper functions
local function vec3Key(v)
    return string.format("%d_%d_%d", math.floor(v.X/2), math.floor(v.Y/2), math.floor(v.Z/2))
end

local function isPositionStandable(pos)
    local down = Workspace:Raycast(pos + Vector3.new(0,5,0), Vector3.new(0,-10,0), rayParams)
    if not down then return false end
    local upCheck = Workspace:Raycast(pos + Vector3.new(0,1,0), Vector3.new(0,3,0), rayParams)
    if upCheck then return false end
    return true, down.Position
end

local function randomNearbyPosition(radius)
    local angle = math.random()*math.pi*2
    local distance = math.random(math.floor(radius/2), math.floor(radius))
    local offset = Vector3.new(math.cos(angle)*distance,0,math.sin(angle)*distance)
    return HRP.Position + offset
end

-- Blocked paths
local BlockedPaths = {}
local BlockedListOrder = {}
local function addBlockedPath(pos)
    local key = vec3Key(pos)
    BlockedPaths[key] = {pos=pos, expires=tick()+Config.BlockedPathTTL}
    table.insert(BlockedListOrder,key)
    while #BlockedListOrder > Config.MaxBlockedEntries do
        local k = table.remove(BlockedListOrder,1)
        BlockedPaths[k] = nil
    end
end
local function removeBlockedPathKey(key)
    BlockedPaths[key]=nil
    for i,k in ipairs(BlockedListOrder) do
        if k==key then table.remove(BlockedListOrder,i); break end
    end
end
local function isBlocked(pos)
    local key = vec3Key(pos)
    local entry = BlockedPaths[key]
    if entry then
        if entry.expires <= tick() then removeBlockedPathKey(key); return false else return true end
    end
    return false
end

task.spawn(function()
    while task.wait(Config.CheckBlockedEvery) do
        for key,entry in pairs(BlockedPaths) do
            local canStand = isPositionStandable(entry.pos)
            if canStand or entry.expires<=tick() then removeBlockedPathKey(key) end
        end
    end
end)

-- Pathfinding
local function computeAndFollowPath(targetPos)
    if isBlocked(targetPos) then return false,"blocked" end
    local path = PathfindingService:CreatePath(Config.PathAgent)
    path:ComputeAsync(HRP.Position,targetPos)
    if path.Status==Enum.PathStatus.Success or path.Status==Enum.PathStatus.Complete then
        for _,wp in ipairs(path:GetWaypoints()) do
            if isBlocked(wp.Position) then addBlockedPath(wp.Position); return false,"blocked_waypoint" end
            Humanoid:MoveTo(wp.Position)
            if wp.Action==Enum.PathWaypointAction.Jump then Humanoid.Jump=true end
            local ok = Humanoid.MoveToFinished:Wait(2)
            if not ok then addBlockedPath(wp.Position); return false,"move_failed" end
        end
        return true,"arrived"
    else addBlockedPath(targetPos); return false,"compute_failed" end
end

local function tryAlternateThenPath(targetPos)
    local ok = computeAndFollowPath(targetPos)
    if ok then return true end
    for i=1,3 do
        local offset = Vector3.new(math.random(-8,8),0,math.random(-8,8))
        local newTarget = targetPos+offset
        if not isBlocked(newTarget) then
            if computeAndFollowPath(newTarget) then return true end
        end
    end
    return false
end

-- Stuck detection
local lastPos = HRP.Position
local stuckSeconds = 0
task.spawn(function()
    while task.wait(1) do
        if (HRP.Position-lastPos).Magnitude<1.5 then stuckSeconds=stuckSeconds+1 else stuckSeconds=0 end
        lastPos=HRP.Position
        if stuckSeconds>=Config.StuckCheckSeconds and stuckSeconds<Config.StuckTPSeconds then
            Humanoid.Jump=true
            Humanoid:MoveTo(HRP.Position+Vector3.new(math.random(-6,6),0,math.random(-6,6)))
            task.wait(1)
        end
        if stuckSeconds>=Config.StuckTPSeconds then
            local teleported=false
            for i=1,Config.StuckTeleportTries do
                local offset=Vector3.new(math.random(-Config.TPSearchRadius,Config.TPSearchRadius),0,math.random(-Config.TPSearchRadius,Config.TPSearchRadius))
                local tryPos=HRP.Position+offset
                local okStand,ground=isPositionStandable(tryPos)
                if okStand then
                    local upCheck=Workspace:Raycast(ground+Vector3.new(0,3,0),Vector3.new(0,-3,0),rayParams)
                    if not upCheck then HRP.CFrame=CFrame.new(ground+Vector3.new(0,3,0)); teleported=true; break end
                end
            end
            if not teleported then HRP.CFrame=HRP.CFrame+Vector3.new(0,3,0) end
            stuckSeconds=0
        end
    end
end)

-- Obstacle handling
local function detectForwardObstacle(dist)
    return Workspace:Raycast(HRP.Position,HRP.CFrame.LookVector*dist,rayParams)
end

local function handleObstacleInFront()
    local result=detectForwardObstacle(4)
    if not result then return false end
    local inst=result.Instance
    local heightDiff=result.Position.Y-HRP.Position.Y
    if heightDiff<3 then Humanoid.Jump=true; return true end
    if inst.Name:lower():find("ladder") or inst:IsA("Climbable") then
        local basePos=Vector3.new(result.Position.X,HRP.Position.Y,result.Position.Z)-HRP.CFrame.LookVector*1
        Humanoid:MoveTo(basePos)
        Humanoid.MoveToFinished:Wait(1)
        return true
    end
    local leftOffset=HRP.CFrame*CFrame.new(-3,0,0)
    local rightOffset=HRP.CFrame*CFrame.new(3,0,0)
    if isPositionStandable(leftOffset.Position) then Humanoid:MoveTo(leftOffset.Position); Humanoid.MoveToFinished:Wait(1); return true
    elseif isPositionStandable(rightOffset.Position) then Humanoid:MoveTo(rightOffset.Position); Humanoid.MoveToFinished:Wait(1); return true
    else addBlockedPath(result.Position); return false end
end

-- Idle dance
task.spawn(function()
    while task.wait(math.random(Config.IdleDanceTimeRange[1],Config.IdleDanceTimeRange[2])) do
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local danceNum=math.random(1,4)
            ReplicatedStorage:WaitForChild("DefaultChatSystemChatEvents")
                .SayMessageRequest:FireServer("/e dance"..danceNum,"All")
        end
    end
end)

-- Idle jump
task.spawn(function()
    while task.wait(math.random(Config.IdleJumpTimeRange[1],Config.IdleJumpTimeRange[2])) do
        if Humanoid and Humanoid.Parent then
            Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            task.wait(math.random(8,16))
        end
    end
end)

-- Auto reply
local _AutoReplyEnabled = true
local function autoReplyNo(player,msg)
    if not _AutoReplyEnabled then return end
    for _,k in ipairs(AutoReplyKeywords) do
        if string.find(string.lower(msg),k) then
            local plrChar=player.Character
            if plrChar and plrChar:FindFirstChild("HumanoidRootPart") then
                local dir=(HRP.Position-plrChar.HumanoidRootPart.Position)
                dir=Vector3.new(dir.X,0,dir.Z).Unit
                local backPos=HRP.Position+dir*Config.StepBack
                if isPositionStandable(backPos) then Humanoid:MoveTo(backPos)
                else Humanoid:MoveTo(HRP.Position+Vector3.new(math.random(-10,10),0,math.random(-10,10))) end
            end
            if math.random()<0.3 then task.delay(math.random(1,4),function()
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head") then
                    local reply=AutoReplyMessages[math.random(1,#AutoReplyMessages)]
                    ChatService:Chat(LocalPlayer.Character.Head,reply,Enum.ChatColor.Red)
                end
            end) end
            break
        end
    end
end

for _,plr in ipairs(Players:GetPlayers()) do
    if plr~=LocalPlayer then plr.Chatted:Connect(function(msg) autoReplyNo(plr,msg) end) end
end
Players.PlayerAdded:Connect(function(plr)
    if plr~=LocalPlayer then plr.Chatted:Connect(function(msg) autoReplyNo(plr,msg) end) end
end)

-- ==========================
-- Main auto-walk loop (headless)
-- ==========================
task.spawn(function()
    while task.wait(0.2) do
        if Humanoid.Sit and Config.JumpWhenSit then Humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
        local didHandle=handleObstacleInFront()
        if didHandle then task.wait(0.3); continue end
        local attempts=0
        local targetPos
        repeat
            targetPos=randomNearbyPosition(Config.WalkRange)
            attempts=attempts+1
            if attempts>10 then break end
        until (not isBlocked(targetPos)) and isPositionStandable(targetPos)
        if not targetPos or isBlocked(targetPos) then
            Humanoid:MoveTo(HRP.Position+Vector3.new(math.random(-6,6),0,math.random(-6,6)))
            task.wait(1)
        else
            local ok=tryAlternateThenPath(targetPos)
            if not ok then addBlockedPath(targetPos); task.wait(Config.PathRetryDelay) end
        end
        task.wait(0.5)
    end
end)

-- Random hello to nearby players
task.spawn(function()
    while task.wait(60) do
        if math.random()<0.3 then
            local otherPlayers={}
            for _,plr in ipairs(Players:GetPlayers()) do
                if plr~=LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                    table.insert(otherPlayers,plr)
                end
            end
            if #otherPlayers>0 then
                local targetPlr=otherPlayers[math.random(1,#otherPlayers)]
                local targetPos=targetPlr.Character.HumanoidRootPart.Position-(targetPlr.Character.HumanoidRootPart.CFrame.LookVector*2)
                if tryAlternateThenPath(targetPos) then
                    task.wait(0.5)
                    ReplicatedStorage:WaitForChild("DefaultChatSystemChatEvents")
                        .SayMessageRequest:FireServer("/e hello","All")
                end
            end
        end
    end
end)

-- Cleanup expired blocked paths
task.spawn(function()
    while task.wait(60) do
        for key,entry in pairs(BlockedPaths) do
            if entry.expires<=tick() then removeBlockedPathKey(key) end
        end
    end
end)
