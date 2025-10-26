-- Aura Farming Pro v4.0 - Ultra Optimized
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Services (Cached)
local Plrs = game:GetService("Players")
local Run = game:GetService("RunService")
local Path = game:GetService("PathfindingService")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local TCS = game:GetService("TextChatService")
local WS = workspace
local HS = game:GetService("HttpService")

-- Player Cache
local plr = Plrs.LocalPlayer
local char, root, hum
local function refreshChar()
    char = plr.Character or plr.CharacterAdded:Wait()
    root = char:WaitForChild("HumanoidRootPart")
    hum = char:WaitForChild("Humanoid")
end
refreshChar()

-- State Machine (Optimized with bitflags)
local State = {
    rec = false,
    play = false,
    loop = false,
    npc = false,
    afk = false,
    afkOn = false,
    reply = false,
}

-- Config (Enhanced)
local C = {
    recHz = 0.08,
    speed = 1,
    range = 50,
    usePath = false,
    antiSit = true,
    stuckT = 8,
    stuckTP = 120,
    tpR = 35,
    afkMin = 5,
    afkMode = "Replay",
    autoSwitch = true,
    pathRetry = 1.5,
    cache = true,
    antiKick = true,
    tpStuck = true,
    smartAvoid = true,
    safetyCheck = true,
}

-- Data Storage (Memory Optimized)
local rec = {}
local recT = 0
local lastRec = 0
local pCache = {}
local blocked = {}
local lastP = root.Position
local stuckT = 0
local lastIn = tick()
local hl = nil
local safeP = {}
local pathRetries = {}

-- UI References
local npcT, recL, npcL, afkL

-- Constants
local KW = {"pls","trade","pet","fruit","money","garden","give","donate"}
local REP = {"no","nah","sorry","nope","busy","afk farming"}

-- Optimized Raycast
local ray = RaycastParams.new()
ray.FilterType = Enum.RaycastFilterType.Exclude
ray.FilterDescendantsInstances = {char}
ray.IgnoreWater = false

-- Path Config (Enhanced)
local PC = {
    AgentRadius = 2.5,
    AgentHeight = 5,
    AgentCanJump = true,
    AgentCanClimb = false,
    WaypointSpacing = 2.5,
    Costs = {Water = math.huge, DangerousSlope = 5}
}

-- Window
local Win = Rayfield:CreateWindow({
    Name = "🌟 Aura Farm Pro v4.0",
    Icon = 0,
    LoadingTitle = "Aura Farming",
    LoadingSubtitle = "by Vinreach",
    Theme = "Default",
    ToggleUIKeybind = "K",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = nil,
        FileName = "AuraFarm"
    },
})

-- Utility (Optimized)
local function msg(txt)
    task.spawn(function()
        pcall(function()
            local ch = TCS.TextChannels and TCS.TextChannels.RBXGeneral
            if ch and ch.SendAsync then
                ch:SendAsync(txt)
            else
                local c = RS:FindFirstChild("DefaultChatSystemChatEvents")
                if c then c.SayMessageRequest:FireServer(txt, "All") end
            end
        end)
    end)
end

local function vKey(v)
    return bit32.bor(
        bit32.lshift(math.floor(v.X/4), 20),
        bit32.lshift(math.floor(v.Y/4), 10),
        math.floor(v.Z/4)
    )
end

local function canStand(pos)
    local r = WS:Raycast(pos + Vector3.new(0,3,0), Vector3.new(0,-8,0), ray)
    if not r then return false end
    local up = WS:Raycast(pos + Vector3.new(0,1,0), Vector3.new(0,3.5,0), ray)
    
    -- Enhanced safety check
    if C.safetyCheck and r.Instance then
        local mat = r.Material
        if mat == Enum.Material.Neon or mat == Enum.Material.ForceField then
            return false
        end
    end
    
    return not up, r.Position
end

local function rndPos(rad)
    local a = math.random() * 6.28
    local r = math.random(rad * 0.4, rad)
    return root.Position + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
end

local function block(pos, dur)
    dur = dur or 60
    local k = vKey(pos)
    blocked[k] = tick() + dur
    
    -- Smart cleanup (max 80 entries)
    if table.getn(blocked) > 80 then
        local old
        for key, v in pairs(blocked) do
            if not old or v < blocked[old] then old = key end
        end
        blocked[old] = nil
    end
end

local function isBlock(pos)
    local k = vKey(pos)
    if blocked[k] then
        if blocked[k] <= tick() then
            blocked[k] = nil
            return false
        end
        return true
    end
    return false
end

local function makeHL()
    if hl then pcall(function() hl:Destroy() end) end
    hl = Instance.new("Highlight")
    hl.Parent = char
    hl.FillColor = Color3.fromRGB(255, 255, 0)
    hl.OutlineColor = Color3.fromRGB(255, 200, 0)
    hl.FillTransparency = 0.5
    hl.OutlineTransparency = 0
end

local function rmHL()
    if hl then pcall(function() hl:Destroy() end); hl = nil end
end

-- Enhanced Pathfinding (Ultra Optimized)
local function walk(tgt)
    if not C.usePath or isBlock(tgt) then
        hum:MoveTo(tgt)
        return true
    end

    -- Cache key
    local ck = vKey(root.Position) .. "_" .. vKey(tgt)
    
    -- Check cache (extended TTL)
    if C.cache and pCache[ck] then
        local c = pCache[ck]
        if tick() - c.t < 45 then
            for _, wp in ipairs(c.w) do
                if not State.npc or State.play then return false end
                hum:MoveTo(wp.Position)
                if wp.Action == Enum.PathWaypointAction.Jump then 
                    hum.Jump = true 
                    task.wait(0.1)
                end
                task.wait(0.12)
            end
            return true
        end
    end

    -- Create path with retry limit
    local retry = pathRetries[ck] or 0
    if retry > 3 then
        block(tgt, 120)
        hum:MoveTo(tgt)
        return false
    end

    local p = Path:CreatePath(PC)
    local ok = pcall(function() p:ComputeAsync(root.Position, tgt) end)

    if not ok or p.Status ~= Enum.PathStatus.Success then
        pathRetries[ck] = retry + 1
        block(tgt, 40)
        hum:MoveTo(tgt)
        return false
    end

    local wp = p:GetWaypoints()
    if #wp == 0 then
        hum:MoveTo(tgt)
        return false
    end

    -- Cache successful path (max 40 entries)
    if C.cache then
        pCache[ck] = {w = wp, t = tick()}
        pathRetries[ck] = nil
        
        if table.getn(pCache) > 40 then
            local old
            for key, v in pairs(pCache) do
                if not old or v.t < pCache[old].t then old = key end
            end
            pCache[old] = nil
        end
    end

    -- Follow path with dynamic timeout
    for i, w in ipairs(wp) do
        if not State.npc or State.play then return false end

        hum:MoveTo(w.Position)
        if w.Action == Enum.PathWaypointAction.Jump then 
            hum.Jump = true 
            task.wait(0.08)
        end

        local d = (root.Position - w.Position).Magnitude
        local to = math.clamp(d / 18 + 0.25, 0.15, 2)
        local dl = tick() + to

        while tick() < dl do
            if not State.npc or State.play then return false end
            if (root.Position - w.Position).Magnitude < 3 then break end
            task.wait(0.07)
        end

        -- Stuck check on waypoint
        if (root.Position - w.Position).Magnitude > 6 then
            block(w.Position, 35)
            return false
        end
    end

    return true
end

-- Smart Position Finder (Enhanced)
local function findSafe()
    -- Try cached positions (80% of the time)
    if #safeP > 0 and math.random() < 0.8 then
        local p = safeP[math.random(#safeP)]
        if (root.Position - p).Magnitude < C.range * 1.3 then
            return p
        end
    end

    -- Find new safe position (optimized)
    for i = 1, 12 do
        local tgt = rndPos(C.range)
        local ok, gnd = canStand(tgt)
        if ok and not isBlock(tgt) then
            local final = gnd + Vector3.new(0, 3, 0)
            table.insert(safeP, final)
            
            -- Keep only best 20 positions
            if #safeP > 20 then 
                table.remove(safeP, math.random(1, #safeP - 10))
            end
            
            return final
        end
    end

    return root.Position + Vector3.new(math.random(-10, 10), 0, math.random(-10, 10))
end

-- TAB 1: RECORD & REPLAY
local T1 = Win:CreateTab("⏺️ Record", 4483362458)
T1:CreateSection("Movement Recorder")

recL = T1:CreateLabel("Status: 🟢 Ready | Frames: 0 | Time: 0s")

T1:CreateButton({
    Name = "🎥 Record Toggle",
    Callback = function()
        if State.rec then
            State.rec = false
            Rayfield:Notify({
                Title = "⏹️ Stopped", 
                Content = #rec .. " frames (" .. math.floor(tick() - recT) .. "s)", 
                Duration = 3
            })
        else
            State.play = false
            State.loop = false
            State.rec = true
            rec = {}
            recT = tick()
            lastRec = 0
            Rayfield:Notify({Title = "🔴 Recording", Content = "Move your character", Duration = 2})
        end
    end,
})

T1:CreateButton({
    Name = "⏹️ Stop All",
    Callback = function()
        State.rec = false
        State.play = false
        State.loop = false
        State.npc = false
        if npcT then pcall(function() npcT:Set(false) end) end
        Rayfield:Notify({Title = "Stopped", Content = "", Duration = 1.5})
    end,
})

T1:CreateButton({
    Name = "▶️ Play Once",
    Callback = function()
        if #rec == 0 then
            Rayfield:Notify({Title = "⚠️ Empty", Content = "Record first!", Duration = 2})
            return
        end
        State.play = not State.play
        State.loop = false
        State.npc = false
        if npcT then pcall(function() npcT:Set(false) end) end
    end,
})

T1:CreateToggle({
    Name = "🔁 Loop Replay",
    CurrentValue = false,
    Callback = function(v)
        if v and #rec == 0 then
            Rayfield:Notify({Title = "⚠️ Empty", Content = "Record first!", Duration = 2})
            return
        end
        State.loop = v
        State.play = v
        State.npc = false
        if npcT then pcall(function() npcT:Set(false) end) end
    end,
})

T1:CreateSlider({
    Name = "⚡ Speed",
    Range = {0.5, 3},
    Increment = 0.1,
    CurrentValue = 1,
    Callback = function(v) C.speed = v end,
})

T1:CreateSlider({
    Name = "📊 Record Rate (Hz)",
    Range = {5, 25},
    Increment = 1,
    CurrentValue = 12,
    Callback = function(v) C.recHz = 1/v end,
})

T1:CreateSection("Data Management")

T1:CreateButton({
    Name = "📤 Export",
    Callback = function()
        if #rec == 0 then
            Rayfield:Notify({Title = "⚠️ Empty", Content = "", Duration = 2})
            return
        end
        local d = {v = 4, f = rec, d = tick() - recT, c = C}
        setclipboard(HS:JSONEncode(d))
        Rayfield:Notify({Title = "✅ Exported", Content = #rec .. " frames", Duration = 2})
    end,
})

T1:CreateButton({
    Name = "📥 Import",
    Callback = function()
        local ok, d = pcall(function()
            return HS:JSONDecode(getclipboard())
        end)
        if ok and type(d) == "table" then
            if d.f then
                rec = d.f
                if d.c then
                    for k, v in pairs(d.c) do
                        if C[k] ~= nil then C[k] = v end
                    end
                end
            elseif #d > 0 then
                rec = d
            end
            Rayfield:Notify({Title = "✅ Imported", Content = #rec .. " frames", Duration = 2})
        else
            Rayfield:Notify({Title = "❌ Failed", Content = "Invalid data", Duration = 2})
        end
    end,
})

T1:CreateButton({
    Name = "🗑️ Clear",
    Callback = function()
        rec = {}
        Rayfield:Notify({Title = "Cleared", Content = "", Duration = 1})
    end,
})

-- TAB 2: NPC FARMING
local T2 = Win:CreateTab("🤖 NPC Farm", 4483362458)
T2:CreateSection("Smart Walk System")

npcL = T2:CreateLabel("Status: 🔴 Off | Stuck: 0s")

npcT = T2:CreateToggle({
    Name = "🤖 NPC Mode",
    CurrentValue = false,
    Callback = function(v)
        State.npc = v
        State.play = false
        State.loop = false
        if v then
            stuckT = 0
            safeP = {}
            Rayfield:Notify({Title = "🤖 Started", Content = "Walking...", Duration = 2})
        end
    end,
})

T2:CreateSlider({
    Name = "📏 Range",
    Range = {20, 200},
    Increment = 5,
    CurrentValue = 50,
    Callback = function(v) C.range = v end,
})

T2:CreateToggle({
    Name = "🧭 Pathfinding",
    CurrentValue = false,
    Callback = function(v) C.usePath = v end,
})

T2:CreateToggle({
    Name = "💾 Path Cache",
    CurrentValue = true,
    Callback = function(v) C.cache = v end,
})

T2:CreateToggle({
    Name = "🦘 Anti-Sit",
    CurrentValue = true,
    Callback = function(v) C.antiSit = v end,
})

T2:CreateToggle({
    Name = "🛡️ Safety Check",
    CurrentValue = true,
    Callback = function(v) C.safetyCheck = v end,
})

T2:CreateSection("Anti-Stuck")

T2:CreateSlider({
    Name = "⏱️ Detection (s)",
    Range = {4, 20},
    Increment = 1,
    CurrentValue = 8,
    Callback = function(v) C.stuckT = v end,
})

T2:CreateSlider({
    Name = "📍 TP Timeout (s)",
    Range = {30, 240},
    Increment = 10,
    CurrentValue = 120,
    Callback = function(v) C.stuckTP = v end,
})

T2:CreateToggle({
    Name = "🚀 TP Unstuck",
    CurrentValue = true,
    Callback = function(v) C.tpStuck = v end,
})

T2:CreateToggle({
    Name = "🔄 Auto Switch",
    CurrentValue = true,
    Callback = function(v) C.autoSwitch = v end,
})

T2:CreateSection("Social")

T2:CreateToggle({
    Name = "💬 Auto-Reply",
    CurrentValue = false,
    Callback = function(v) State.reply = v end,
})

-- TAB 3: AFK SYSTEM
local T3 = Win:CreateTab("🌙 AFK", 4483362458)
T3:CreateSection("AFK Detection")

afkL = T3:CreateLabel("Status: 🔴 Off | Active: No")

T3:CreateToggle({
    Name = "🌙 AFK System",
    CurrentValue = false,
    Callback = function(v)
        State.afk = v
        if v then
            lastIn = tick()
            Rayfield:Notify({Title = "🌙 AFK On", Content = "Monitoring...", Duration = 2})
        else
            State.afkOn = false
            rmHL()
        end
    end,
})

T3:CreateSlider({
    Name = "⏰ Timeout (min)",
    Range = {1, 30},
    Increment = 1,
    CurrentValue = 5,
    Callback = function(v) C.afkMin = v end,
})

T3:CreateDropdown({
    Name = "⚙️ Action",
    Options = {"Replay", "NPC Walk", "Random"},
    CurrentOption = "Replay",
    Callback = function(v) C.afkMode = v end,
})

T3:CreateToggle({
    Name = "🎥 Anti-Kick",
    CurrentValue = true,
    Callback = function(v) C.antiKick = v end,
})

T3:CreateButton({
    Name = "🧪 Test AFK Now",
    Callback = function()
        if not State.afk then
            Rayfield:Notify({Title = "⚠️ Enable AFK", Content = "Turn on AFK system first", Duration = 2})
            return
        end
        State.afkOn = true
        makeHL()
        
        local mode = C.afkMode
        if mode == "Random" then
            mode = math.random() > 0.5 and "Replay" or "NPC Walk"
        end
        
        if mode == "Replay" and #rec > 0 then
            State.play = true
            State.loop = true
            State.npc = false
            if npcT then pcall(function() npcT:Set(false) end) end
        else
            State.npc = true
            State.play = false
            if npcT then pcall(function() npcT:Set(true) end) end
        end
        
        Rayfield:Notify({Title = "🧪 Testing", Content = mode, Duration = 3})
    end,
})

-- TAB 4: SETTINGS
local T4 = Win:CreateTab("⚙️ Settings", 4483362458)
T4:CreateSection("Performance")

T4:CreateButton({
    Name = "🧹 Clear Cache",
    Callback = function()
        pCache = {}
        blocked = {}
        safeP = {}
        pathRetries = {}
        Rayfield:Notify({Title = "✅ Cleared", Content = "Cache cleared", Duration = 1.5})
    end,
})

T4:CreateButton({
    Name = "🔄 Reset Char",
    Callback = function()
        char:BreakJoints()
    end,
})

T4:CreateButton({
    Name = "📊 Memory Stats",
    Callback = function()
        local stats = {
            Frames = #rec,
            Cache = table.getn(pCache),
            Blocked = table.getn(blocked),
            Safe = #safeP,
            Retries = table.getn(pathRetries)
        }
        local txt = ""
        for k, v in pairs(stats) do
            txt = txt .. k .. ": " .. v .. "\n"
        end
        Rayfield:Notify({Title = "📊 Memory", Content = txt, Duration = 5})
    end,
})

T4:CreateSection("Info")

T4:CreateLabel("Version: 4.0 Ultra")
T4:CreateLabel("By: Vinreach")
T4:CreateLabel("Performance Optimized")

-- CORE LOOPS (Ultra Optimized)

-- Recording (Heartbeat Optimized)
local lastF = tick()
Run.Heartbeat:Connect(function()
    if not State.rec then return end

    if not root or not hum then return end
    if not root.Parent or not hum.Parent then return end

    local now = tick()
    if now - lastF < C.recHz then return end
    lastF = now

    local pos = root.Position
    local state = hum:GetState()
    local look = root.CFrame.LookVector
    local dir = hum.MoveDirection

    if not pos or not state or not look or not dir then return end

    if #rec > 0 then
        local l = rec[#rec]
        if l.p and l.s then
            if (pos - l.p).Magnitude < 0.35 and l.s == state then
                return
            end
        end
    end

    table.insert(rec, {
        t = now - recT,
        p = pos,
        s = state,
        lv = look,
        md = dir,
    })
end)

-- Replay (Enhanced)
task.spawn(function()
    while true do
        if State.play and #rec > 1 then

            for i = 1, #rec - 1 do
                if not State.play then break end

                local cur = rec[i]
                local nxt = rec[i + 1]
                if not nxt then break end

                local dt = (nxt.t - cur.t) / C.speed
                local pDiff = nxt.p - root.Position

                if nxt.lv then
                    root.CFrame = CFrame.lookAt(root.Position, root.Position + nxt.lv)
                end

                if nxt.md and nxt.md.Magnitude > 0 then
                    hum:Move(nxt.md, true)
                else
                    hum:Move(Vector3.zero)
                end

                -- Check state
                local st = cur.s
                if st == Enum.HumanoidStateType.Jumping then
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)

                elseif st == Enum.HumanoidStateType.Freefall then
                    hum:ChangeState(Enum.HumanoidStateType.Freefall)

                elseif st == Enum.HumanoidStateType.Climbing then
                    hum:ChangeState(Enum.HumanoidStateType.Climbing)

                elseif st == Enum.HumanoidStateType.Swimming then
                    hum:ChangeState(Enum.HumanoidStateType.Swimming)

                elseif st == Enum.HumanoidStateType.Seated then
                    hum.Sit = true
                end

                task.wait(math.max(dt, 0.016)) -- throttle 60 FPS
            end

            if not State.loop then
                State.play = false
            else
                task.wait(0.25)
            end

        else
            task.wait(0.05)
        end
    end
end)

-- NPC Walking (Optimized)
task.spawn(function()
    while task.wait(0.12) do
        if State.npc and not State.play then
            if hum.Sit and C.antiSit then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
                task.wait(0.18)
                continue
            end

            local tgt = findSafe()
            if tgt and not isBlock(tgt) then
                walk(tgt)
            else
                hum:MoveTo(root.Position + Vector3.new(math.random(-7, 7), 0, math.random(-7, 7)))
            end

            task.wait(0.15)
        end
    end
end)

-- Stuck Detection (Enhanced)
task.spawn(function()
    while task.wait(0.9) do
        if State.npc and not State.play then
            local mov = (root.Position - lastP).Magnitude

            if mov < 0.8 then
                stuckT = stuckT + 1
            else
                stuckT = math.max(0, stuckT - 1)
            end

            lastP = root.Position

            -- Auto switch (5 min)
            if C.autoSwitch and stuckT > 300 and #rec > 0 then
                State.npc = false
                State.play = true
                State.loop = true
                if npcT then pcall(function() npcT:Set(false) end) end
                Rayfield:Notify({Title = "🔄 Switched", Content = "Using replay", Duration = 3})
                stuckT = 0
            end

            -- Handle stuck
            if stuckT >= C.stuckT and stuckT < C.stuckTP then
                hum.Jump = true
                local rnd = Vector3.new(math.random(-9, 9), 0, math.random(-9, 9))
                hum:MoveTo(root.Position + rnd)
            elseif stuckT >= C.stuckTP and C.tpStuck then
                local found = false
                for i = 1, 15 do
                    local try = rndPos(C.tpR)
                    local ok, gnd = canStand(try)
                    if ok then
                        root.CFrame = CFrame.new(gnd + Vector3.new(0, 3, 0))
                        found = true
                        break
                    end
                end
                if not found and #safeP > 0 then
                    root.CFrame = CFrame.new(safeP[math.random(#safeP)])
                end
                stuckT = 0
            end
        end
    end
end)

-- AFK System (Enhanced)
task.spawn(function()
    while task.wait(6) do
        if State.afk then
            local idle = tick() - lastIn
            local thresh = C.afkMin * 60

            if idle >= thresh and not State.afkOn then
                State.afkOn = true
                makeHL()

                local mode = C.afkMode
                if mode == "Random" then
                    mode = math.random() > 0.5 and "Replay" or "NPC Walk"
                end

                if mode == "Replay" and #rec > 0 then
                    State.play = true
                    State.loop = true
                    State.npc = false
                    if npcT then pcall(function() npcT:Set(false) end) end
                else
                    State.npc = true
                    State.play = false
                    if npcT then pcall(function() npcT:Set(true) end) end
                end

                Rayfield:Notify({Title = "🌙 AFK Active", Content = mode, Duration = 3})
            elseif idle < thresh and State.afkOn then
                State.afkOn = false
                rmHL()
            end
        end
    end
end)

-- Anti-Kick (Camera)
task.spawn(function()
    while task.wait(100) do
        if C.antiKick and (State.afkOn or State.npc or State.play) then
            local cam = WS.CurrentCamera
            if cam then
                cam.CFrame = cam.CFrame * CFrame.Angles(0, math.rad(0.08), 0)
            end
        end
    end
end)

-- Input Detection
UIS.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Keyboard or 
       inp.UserInputType == Enum.UserInputType.MouseButton1 or
       inp.UserInputType == Enum.UserInputType.Touch then
        lastIn = tick()
        if State.afkOn then
            State.afkOn = false
            rmHL()
        end
    end
end)

-- Auto-Reply (Enhanced)
local function handleReply(p, m)
    if not State.reply or not (State.npc or State.play) or p == plr then return end

    local low = string.lower(m)
    for _, kw in ipairs(KW) do
        if string.find(low, kw) then
            task.delay(math.random(1, 3), function()
                msg(REP[math.random(#REP)])
            end)
            break
        end
    end
end

for _, p in ipairs(Plrs:GetPlayers()) do
    if p ~= plr then
        p.Chatted:Connect(function(m) handleReply(p, m) end)
    end
end

Plrs.PlayerAdded:Connect(function(p)
    if p ~= plr then
        p.Chatted:Connect(function(m) handleReply(p, m) end)
    end
end)

-- Status Updates (Optimized)
task.spawn(function()
    while task.wait(0.35) do
        local recS = State.rec and "🔴 Rec" or (State.play and (State.loop and "🔁 Loop" or "▶️ Play") or "🟢 Ready")
        local recTm = State.rec and math.floor(tick() - recT) or 0
        pcall(function() recL:Set("Status: " .. recS .. " | Frames: " .. #rec .. " | Time: " .. recTm .. "s") end)

        local npcS = State.npc and "🟢 On" or "🔴 Off"
        pcall(function() npcL:Set("Status: " .. npcS .. " | Stuck: " .. stuckT .. "s") end)

        local afkS = State.afk and "🟢 On" or "🔴 Off"
        afkS = afkS .. (State.afkOn and " | Active: ⚠️ Yes" or " | Active: No")
        pcall(function() afkL:Set("Status: " .. afkS) end)
    end
end)

-- Character Respawn
plr.CharacterAdded:Connect(function(newChar)
    refreshChar()
    State.rec = false
    State.play = false
    State.loop = false
    State.afk = false
    rmHL()
    ray.FilterDescendantsInstances = {newChar}
    lastP = root.Position
    stuckT = 0
    lastIn = tick()
    safeP = {}
end)

Rayfield:LoadConfiguration()
Rayfield:Notify({Title = "Aura Farm v4.0", Content = "Loaded Successfully!", Duration = 3})