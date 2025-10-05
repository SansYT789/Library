-- Aura Farming Pro v3.0 - Optimized & Enhanced
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Services (Cached)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local TCS = game:GetService("TextChatService")
local WS = workspace

-- Player Cache
local plr = Players.LocalPlayer
local char, hrp, hum
local function updateChar()
    char = plr.Character or plr.CharacterAdded:Wait()
    hrp = char:WaitForChild("HumanoidRootPart")
    hum = char:WaitForChild("Humanoid")
end
updateChar()

-- State Machine (Optimized)
local State = {
    recording = false,
    replaying = false,
    loopReplay = false,
    npcWalking = false,
    afkEnabled = false,
    afkActive = false,
    autoReply = false,
    smartAvoid = false,
}

-- Config (Enhanced)
local Cfg = {
    recordInterval = 0.08,
    replaySpeed = 1,
    walkRange = 50,
    usePathfinding = false,
    jumpWhenSit = true,
    stuckCheck = 8,
    stuckTP = 120,
    tpRadius = 35,
    afkMinutes = 5,
    afkMode = "Replay",
    autoSwitchStuck = true,
    pathRetry = 1.5,
    smartPathCache = true,
    antiKick = true,
    teleportOnStuck = true,
}

-- Data Storage (Memory Optimized)
local recordData = {}
local recordStart = 0
local lastRecordTime = 0
local pathCache = {}
local blockedPaths = {}
local lastPos = hrp.Position
local stuckTime = 0
local lastInputTime = tick()
local afkHL = nil
local safePositions = {}

-- UI References
local npcToggle, recordStatus, npcStatus, afkStatus

-- Constants
local KEYWORDS = {"pls","trade","pet","fruit","money","garden","give"}
local REPLIES = {"no","nah","sorry","nope","busy"}

-- Optimized Raycast Setup
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = {char}
rayParams.IgnoreWater = false

-- Path Config (Enhanced)
local PathCfg = {
    AgentRadius = 2.5,
    AgentHeight = 5,
    AgentCanJump = true,
    AgentCanClimb = false,
    WaypointSpacing = 3,
}

-- Window Setup
local Win = Rayfield:CreateWindow({
    Name = "Aura Farming Pro v3.0",
    Icon = 0,
    LoadingTitle = "Enhanced Farming System",
    LoadingSubtitle = "by Vinreach | Optimized",
    Theme = "Default",
    ToggleUIKeybind = "K",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = nil,
        FileName = "AuraFarmingProV3"
    },
})

-- Utility Functions (Optimized)
local function sendMsg(msg)
    task.spawn(function()
        pcall(function()
            local ch = TCS.TextChannels and TCS.TextChannels.RBXGeneral
            if ch and ch.SendAsync then
                ch:SendAsync(msg)
            else
                local chat = RS:FindFirstChild("DefaultChatSystemChatEvents")
                if chat then chat.SayMessageRequest:FireServer(msg, "All") end
            end
        end)
    end)
end

local function vecKey(v)
    return bit32.bor(
        bit32.lshift(math.floor(v.X/4), 20),
        bit32.lshift(math.floor(v.Y/4), 10),
        math.floor(v.Z/4)
    )
end

local function isStandable(pos)
    local ray = WS:Raycast(pos + Vector3.new(0,3,0), Vector3.new(0,-8,0), rayParams)
    if not ray then return false end
    local up = WS:Raycast(pos + Vector3.new(0,1,0), Vector3.new(0,3.5,0), rayParams)
    return not up, ray.Position
end

local function randomPos(radius)
    local ang = math.random() * 6.28
    local r = math.random(radius * 0.5, radius)
    return hrp.Position + Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r)
end

local function blockPath(pos, duration)
    duration = duration or 60
    local key = vecKey(pos)
    blockedPaths[key] = tick() + duration
    -- Cleanup old blocks
    if #blockedPaths > 100 then
        local oldest
        for k, v in pairs(blockedPaths) do
            if not oldest or v < blockedPaths[oldest] then oldest = k end
        end
        blockedPaths[oldest] = nil
    end
end

local function isBlocked(pos)
    local key = vecKey(pos)
    if blockedPaths[key] then
        if blockedPaths[key] <= tick() then
            blockedPaths[key] = nil
            return false
        end
        return true
    end
    return false
end

local function createHL()
    if afkHL then pcall(function() afkHL:Destroy() end) end
    afkHL = Instance.new("Highlight")
    afkHL.Parent = char
    afkHL.FillColor = Color3.fromRGB(255, 255, 0)
    afkHL.OutlineColor = Color3.fromRGB(255, 200, 0)
    afkHL.FillTransparency = 0.6
    afkHL.OutlineTransparency = 0
end

local function removeHL()
    if afkHL then pcall(function() afkHL:Destroy() end); afkHL = nil end
end

-- Enhanced Pathfinding (Cached & Optimized)
local function walkPath(target)
    if not Cfg.usePathfinding or isBlocked(target) then
        hum:MoveTo(target)
        return true
    end
    
    -- Check cache
    local cacheKey = vecKey(hrp.Position) .. "_" .. vecKey(target)
    if Cfg.smartPathCache and pathCache[cacheKey] then
        local cached = pathCache[cacheKey]
        if tick() - cached.time < 30 then
            for _, wp in ipairs(cached.waypoints) do
                if not State.npcWalking or State.replaying then return false end
                hum:MoveTo(wp.Position)
                if wp.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
                task.wait(0.15)
            end
            return true
        end
    end
    
    local path = PathfindingService:CreatePath(PathCfg)
    local ok = pcall(function() path:ComputeAsync(hrp.Position, target) end)
    
    if not ok or path.Status ~= Enum.PathStatus.Success then
        blockPath(target, 45)
        hum:MoveTo(target)
        return false
    end
    
    local wps = path:GetWaypoints()
    if #wps == 0 then
        hum:MoveTo(target)
        return false
    end
    
    -- Cache successful path
    if Cfg.smartPathCache then
        pathCache[cacheKey] = {waypoints = wps, time = tick()}
        -- Limit cache size
        if table.getn(pathCache) > 50 then
            local oldest
            for k, v in pairs(pathCache) do
                if not oldest or v.time < pathCache[oldest].time then oldest = k end
            end
            pathCache[oldest] = nil
        end
    end
    
    -- Follow path with smart waiting
    for i, wp in ipairs(wps) do
        if not State.npcWalking or State.replaying then return false end
        
        hum:MoveTo(wp.Position)
        if wp.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
        
        local dist = (hrp.Position - wp.Position).Magnitude
        local timeout = math.min(dist / 16 + 0.3, 2.5)
        local deadline = tick() + timeout
        
        while tick() < deadline do
            if not State.npcWalking or State.replaying then return false end
            if (hrp.Position - wp.Position).Magnitude < 3.5 then break end
            task.wait(0.08)
        end
        
        if (hrp.Position - wp.Position).Magnitude > 5 then
            blockPath(wp.Position, 30)
            return false
        end
    end
    
    return true
end

-- Smart Position Finder (New)
local function findSafePos()
    -- Try cached safe positions first
    if #safePositions > 0 then
        local pos = safePositions[math.random(#safePositions)]
        if (hrp.Position - pos).Magnitude < Cfg.walkRange * 1.5 then
            return pos
        end
    end
    
    -- Find new safe position
    for i = 1, 10 do
        local target = randomPos(Cfg.walkRange)
        local ok, ground = isStandable(target)
        if ok and not isBlocked(target) then
            table.insert(safePositions, ground + Vector3.new(0, 3, 0))
            if #safePositions > 15 then table.remove(safePositions, 1) end
            return ground + Vector3.new(0, 3, 0)
        end
    end
    
    return hrp.Position + Vector3.new(math.random(-10, 10), 0, math.random(-10, 10))
end

-- TAB 1: RECORD & REPLAY (Enhanced)
local T1 = Win:CreateTab("Record & Replay", 4483362458)
T1:CreateSection("Movement Recorder")

recordStatus = T1:CreateLabel("Status: 🟢 Ready | Frames: 0 | Time: 0s")

T1:CreateButton({
    Name = "🎥 Start/Stop Recording",
    Callback = function()
        if State.recording then
            State.recording = false
            Rayfield:Notify({Title = "Recording Stopped", Content = #recordData .. " frames in " .. math.floor(tick() - recordStart) .. "s", Duration = 3})
        else
            State.replaying = false
            State.loopReplay = false
            State.recording = true
            recordData = {}
            recordStart = tick()
            lastRecordTime = 0
            Rayfield:Notify({Title = "Recording Started", Content = "Move to record path", Duration = 2})
        end
    end,
})

T1:CreateButton({
    Name = "⏹ Stop All",
    Callback = function()
        State.recording = false
        State.replaying = false
        State.loopReplay = false
        State.npcWalking = false
        if npcToggle then pcall(function() npcToggle:Set(false) end) end
        Rayfield:Notify({Title = "All Stopped", Content = "", Duration = 2})
    end,
})

T1:CreateButton({
    Name = "▶️ Replay Once",
    Callback = function()
        if #recordData == 0 then
            Rayfield:Notify({Title = "No Recording", Content = "Record first!", Duration = 2})
            return
        end
        State.replaying = not State.replaying
        State.loopReplay = false
        State.npcWalking = false
        if npcToggle then pcall(function() npcToggle:Set(false) end) end
    end,
})

T1:CreateToggle({
    Name = "🔁 Loop Replay",
    CurrentValue = false,
    Callback = function(v)
        if v and #recordData == 0 then
            Rayfield:Notify({Title = "No Data", Content = "Record first!", Duration = 2})
            return
        end
        State.loopReplay = v
        State.replaying = v
        State.npcWalking = false
        if npcToggle then pcall(function() npcToggle:Set(false) end) end
    end,
})

T1:CreateSlider({
    Name = "Replay Speed",
    Range = {0.5, 3},
    Increment = 0.1,
    CurrentValue = 1,
    Callback = function(v) Cfg.replaySpeed = v end,
})

T1:CreateSlider({
    Name = "Record Rate (Hz)",
    Range = {5, 20},
    Increment = 1,
    CurrentValue = 12,
    Callback = function(v) Cfg.recordInterval = 1/v end,
})

T1:CreateSection("Data Management")

T1:CreateButton({
    Name = "📤 Export to Clipboard",
    Callback = function()
        if #recordData == 0 then
            Rayfield:Notify({Title = "No Data", Content = "", Duration = 2})
            return
        end
        local data = {version = 3, frames = recordData, duration = tick() - recordStart}
        setclipboard(game:GetService("HttpService"):JSONEncode(data))
        Rayfield:Notify({Title = "Exported", Content = #recordData .. " frames", Duration = 2})
    end,
})

T1:CreateButton({
    Name = "📥 Import from Clipboard",
    Callback = function()
        local ok, data = pcall(function()
            return game:GetService("HttpService"):JSONDecode(getclipboard())
        end)
        if ok and type(data) == "table" then
            if data.frames then
                recordData = data.frames
            elseif #data > 0 then
                recordData = data
            end
            Rayfield:Notify({Title = "Imported", Content = #recordData .. " frames", Duration = 2})
        else
            Rayfield:Notify({Title = "Import Failed", Content = "Invalid data", Duration = 2})
        end
    end,
})

T1:CreateButton({
    Name = "🗑️ Clear Recording",
    Callback = function()
        recordData = {}
        Rayfield:Notify({Title = "Cleared", Content = "", Duration = 1})
    end,
})

-- TAB 2: NPC FARMING (Enhanced)
local T2 = Win:CreateTab("NPC Farming", 4483362458)
T2:CreateSection("Smart NPC Walk")

npcStatus = T2:CreateLabel("Status: 🔴 Off | Stuck: 0s")

npcToggle = T2:CreateToggle({
    Name = "🤖 Enable NPC Mode",
    CurrentValue = false,
    Callback = function(v)
        State.npcWalking = v
        State.replaying = false
        State.loopReplay = false
        if v then
            stuckTime = 0
            safePositions = {}
            Rayfield:Notify({Title = "NPC Started", Content = "Walking mode active", Duration = 2})
        end
    end,
})

T2:CreateSlider({
    Name = "Walk Range",
    Range = {20, 150},
    Increment = 5,
    CurrentValue = 50,
    Callback = function(v) Cfg.walkRange = v end,
})

T2:CreateToggle({
    Name = "Smart Pathfinding",
    CurrentValue = false,
    Callback = function(v) Cfg.usePathfinding = v end,
})

T2:CreateToggle({
    Name = "Path Caching (Faster)",
    CurrentValue = true,
    Callback = function(v) Cfg.smartPathCache = v end,
})

T2:CreateToggle({
    Name = "Auto Jump (Anti-Sit)",
    CurrentValue = true,
    Callback = function(v) Cfg.jumpWhenSit = v end,
})

T2:CreateSection("Anti-Stuck System")

T2:CreateSlider({
    Name = "Stuck Detection (s)",
    Range = {5, 20},
    Increment = 1,
    CurrentValue = 8,
    Callback = function(v) Cfg.stuckCheck = v end,
})

T2:CreateSlider({
    Name = "TP on Stuck (s)",
    Range = {30, 180},
    Increment = 10,
    CurrentValue = 120,
    Callback = function(v) Cfg.stuckTP = v end,
})

T2:CreateToggle({
    Name = "Teleport Unstuck",
    CurrentValue = true,
    Callback = function(v) Cfg.teleportOnStuck = v end,
})

T2:CreateToggle({
    Name = "Auto Switch to Replay",
    CurrentValue = true,
    Callback = function(v) Cfg.autoSwitchStuck = v end,
})

T2:CreateSection("Social Features")

T2:CreateToggle({
    Name = "Auto-Reply (Anti-Beg)",
    CurrentValue = false,
    Callback = function(v) State.autoReply = v end,
})

-- TAB 3: AFK SYSTEM (Enhanced)
local T3 = Win:CreateTab("AFK System", 4483362458)
T3:CreateSection("AFK Detection")

afkStatus = T3:CreateLabel("Status: 🔴 Off | Active: No")

T3:CreateToggle({
    Name = "🌙 Enable AFK System",
    CurrentValue = false,
    Callback = function(v)
        State.afkEnabled = v
        if v then
            lastInputTime = tick()
            Rayfield:Notify({Title = "AFK Enabled", Content = "Monitoring...", Duration = 2})
        else
            State.afkActive = false
            removeHL()
        end
    end,
})

T3:CreateSlider({
    Name = "AFK Timeout (min)",
    Range = {1, 30},
    Increment = 1,
    CurrentValue = 5,
    Callback = function(v) Cfg.afkMinutes = v end,
})

T3:CreateDropdown({
    Name = "AFK Action",
    Options = {"Replay", "NPC Walk", "Random"},
    CurrentOption = "Replay",
    Callback = function(v) Cfg.afkMode = v end,
})

T3:CreateToggle({
    Name = "Anti-Kick (Move Camera)",
    CurrentValue = true,
    Callback = function(v) Cfg.antiKick = v end,
})

-- TAB 4: SETTINGS (New)
local T4 = Win:CreateTab("Settings", 4483362458)
T4:CreateSection("Performance")

T4:CreateButton({
    Name = "🗑️ Clear Path Cache",
    Callback = function()
        pathCache = {}
        blockedPaths = {}
        safePositions = {}
        Rayfield:Notify({Title = "Cache Cleared", Content = "", Duration = 1})
    end,
})

T4:CreateButton({
    Name = "🔄 Reset Character",
    Callback = function()
        char:BreakJoints()
    end,
})

T4:CreateSection("Info")

T4:CreateLabel("Version: 3.0 Enhanced")
T4:CreateLabel("By: Vinreach")
T4:CreateLabel("Optimized for Performance")

-- CORE LOOPS (Optimized)

-- Recording Loop (Heartbeat Optimized)
local lastFrame = tick()
RunService.Heartbeat:Connect(function()
    if not State.recording then return end
    local now = tick()
    if now - lastFrame < Cfg.recordInterval then return end
    lastFrame = now
    
    if #recordData > 0 then
        local last = recordData[#recordData]
        if (hrp.Position - last.p).Magnitude < 0.4 and last.s == hum:GetState() then
            return
        end
    end
    
    table.insert(recordData, {
        t = now - recordStart,
        p = hrp.Position,
        s = hum:GetState(),
    })
end)

-- Replay Loop (Enhanced)
task.spawn(function()
    while true do
        if State.replaying and #recordData > 0 then
            for i = 1, #recordData - 1 do
                if not State.replaying then break end
                
                local cur = recordData[i]
                local nxt = recordData[i + 1]
                if not nxt then break end
                
                local dist = (nxt.p - cur.p).Magnitude
                local wait_t = (nxt.t - cur.t) / Cfg.replaySpeed
                
                if dist > 0.8 then
                    hum:MoveTo(nxt.p)
                    
                    if cur.s == Enum.HumanoidStateType.Jumping then
                        task.wait(0.05)
                        hum:ChangeState(Enum.HumanoidStateType.Jumping)
                    end
                    
                    local start = tick()
                    local timeout = math.max(wait_t, 0.15)
                    
                    while tick() - start < timeout do
                        if not State.replaying then break end
                        if (hrp.Position - nxt.p).Magnitude < 2.5 then break end
                        task.wait(0.05)
                    end
                else
                    task.wait(math.max(wait_t, 0.05))
                end
            end
            
            if State.loopReplay then
                task.wait(0.3)
            else
                State.replaying = false
            end
        else
            task.wait(0.1)
        end
    end
end)

-- NPC Walking Loop (Optimized)
task.spawn(function()
    while task.wait(0.15) do
        if State.npcWalking and not State.replaying then
            if hum.Sit and Cfg.jumpWhenSit then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
                task.wait(0.2)
                continue
            end
            
            local target = findSafePos()
            if target and not isBlocked(target) then
                walkPath(target)
            else
                hum:MoveTo(hrp.Position + Vector3.new(math.random(-8, 8), 0, math.random(-8, 8)))
            end
            
            task.wait(0.2)
        end
    end
end)

-- Stuck Detection (Enhanced)
task.spawn(function()
    while task.wait(1) do
        if State.npcWalking and not State.replaying then
            local moved = (hrp.Position - lastPos).Magnitude
            
            if moved < 1 then
                stuckTime = stuckTime + 1
            else
                stuckTime = 0
            end
            
            lastPos = hrp.Position
            
            -- Auto switch on long stuck
            if Cfg.autoSwitchStuck and stuckTime > 300 and #recordData > 0 then
                State.npcWalking = false
                State.replaying = true
                State.loopReplay = true
                if npcToggle then pcall(function() npcToggle:Set(false) end) end
                Rayfield:Notify({Title = "Auto-Switched", Content = "Using replay", Duration = 3})
                stuckTime = 0
            end
            
            -- Handle stuck
            if stuckTime >= Cfg.stuckCheck and stuckTime < Cfg.stuckTP then
                hum.Jump = true
                local rnd = Vector3.new(math.random(-8, 8), 0, math.random(-8, 8))
                hum:MoveTo(hrp.Position + rnd)
            elseif stuckTime >= Cfg.stuckTP and Cfg.teleportOnStuck then
                local found = false
                for i = 1, 12 do
                    local try = randomPos(Cfg.tpRadius)
                    local ok, ground = isStandable(try)
                    if ok then
                        hrp.CFrame = CFrame.new(ground + Vector3.new(0, 3, 0))
                        found = true
                        break
                    end
                end
                if not found and #safePositions > 0 then
                    hrp.CFrame = CFrame.new(safePositions[math.random(#safePositions)])
                end
                stuckTime = 0
            end
        end
    end
end)

-- AFK System (Enhanced)
task.spawn(function()
    while task.wait(8) do
        if State.afkEnabled then
            local idle = tick() - lastInputTime
            local threshold = Cfg.afkMinutes * 60
            
            if idle >= threshold and not State.afkActive then
                State.afkActive = true
                createHL()
                
                local mode = Cfg.afkMode
                if mode == "Random" then
                    mode = math.random() > 0.5 and "Replay" or "NPC Walk"
                end
                
                if mode == "Replay" and #recordData > 0 then
                    State.replaying = true
                    State.loopReplay = true
                    State.npcWalking = false
                    if npcToggle then pcall(function() npcToggle:Set(false) end) end
                else
                    State.npcWalking = true
                    State.replaying = false
                    if npcToggle then pcall(function() npcToggle:Set(true) end) end
                end
                
                Rayfield:Notify({Title = "AFK Active", Content = mode, Duration = 3})
            elseif idle < threshold and State.afkActive then
                State.afkActive = false
                removeHL()
            end
        end
    end
end)

-- Anti-Kick (Camera Movement)
task.spawn(function()
    while task.wait(120) do
        if Cfg.antiKick and (State.afkActive or State.npcWalking or State.replaying) then
            local cam = workspace.CurrentCamera
            if cam then
                cam.CFrame = cam.CFrame * CFrame.Angles(0, math.rad(0.1), 0)
            end
        end
    end
end)

-- Input Detection (Optimized)
UIS.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Keyboard or 
       inp.UserInputType == Enum.UserInputType.MouseButton1 or
       inp.UserInputType == Enum.UserInputType.Touch then
        lastInputTime = tick()
        if State.afkActive then
            State.afkActive = false
            removeHL()
        end
    end
end)

-- Auto-Reply System
local function handleReply(p, msg)
    if not State.autoReply or not (State.npcWalking or State.replaying) or p == plr then return end
    
    local low = string.lower(msg)
    for _, kw in ipairs(KEYWORDS) do
        if string.find(low, kw) then
            task.delay(math.random(1, 2), function()
                sendMsg(REPLIES[math.random(#REPLIES)])
            end)
            break
        end
    end
end

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= plr then
        p.Chatted:Connect(function(m) handleReply(p, m) end)
    end
end

Players.PlayerAdded:Connect(function(p)
    if p ~= plr then
        p.Chatted:Connect(function(m) handleReply(p, m) end)
    end
end)

-- Status Updates (Optimized)
task.spawn(function()
    while task.wait(0.4) do
        local recS = State.recording and "🔴 Recording" or (State.replaying and (State.loopReplay and "🔁 Loop" or "▶️ Play") or "🟢 Ready")
        local recT = State.recording and math.floor(tick() - recordStart) or 0
        pcall(function() recordStatus:Set("Status: " .. recS .. " | Frames: " .. #recordData .. " | Time: " .. recT .. "s") end)
        
        local npcS = State.npcWalking and "🟢 Active" or "🔴 Off"
        pcall(function() npcStatus:Set("Status: " .. npcS .. " | Stuck: " .. stuckTime .. "s") end)
        
        local afkS = State.afkEnabled and "🟢 On" or "🔴 Off"
        afkS = afkS .. (State.afkActive and " | Active: Yes ⚠️" or " | Active: No")
        pcall(function() afkStatus:Set("Status: " .. afkS) end)
    end
end)

-- Character Respawn Handler
plr.CharacterAdded:Connect(function(newChar)
    updateChar()
    State.recording = false
    State.replaying = false
    State.loopReplay = false
    State.afkActive = false
    removeHL()
    rayParams.FilterDescendantsInstances = {char}
    lastPos = hrp.Position
    stuckTime = 0
    lastInputTime = tick()
    safePositions = {}
end)

Rayfield:LoadConfiguration()
Rayfield:Notify({Title = "Aura Farm v3.0", Content = "Loaded Successfully!", Duration = 3})