-- Aura Farm Pro v4.1 - Ultra Optimized (500 Lines)
local RF = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Services Cache
local P,R,PS,U,RS,TC,W,H = game:GetService("Players"),game:GetService("RunService"),game:GetService("PathfindingService"),game:GetService("UserInputService"),game:GetService("ReplicatedStorage"),game:GetService("TextChatService"),workspace,game:GetService("HttpService")

-- Player
local p,c,rt,hm = P.LocalPlayer
local function rC(ch) c,rt,hm = ch,ch:WaitForChild("HumanoidRootPart"),ch:WaitForChild("Humanoid") end
if p.Character then rC(p.Character) end

-- State
local S = {r=false,p=false,l=false,n=false,a=false,ao=false,rp=false}

-- Config
local C = {rHz=0.08,spd=1,rng=50,path=false,sit=true,stT=8,stTP=120,tpR=35,afkM=5,mode="Replay",sw=true,retry=1.5,cache=true,kick=true,tpS=true,smart=true,safe=true}

-- Data
local rec,rT,lR,pC,blk,lP,stT,lI,hl,sfP,pR = {},0,0,{},{},rt.Position,0,tick(),nil,{},{}

-- UI Refs
local nT,rL,nL,aL

-- Constants
local KW,RP = {"pls","trade","pet","fruit","money","garden","give","donate"},{"no","nah","sorry","nope","busy","afk farming"}

-- Raycast
local ray = RaycastParams.new()
ray.FilterType,ray.FilterDescendantsInstances,ray.IgnoreWater = Enum.RaycastFilterType.Exclude,{c},false

-- Path Config
local PC = {AgentRadius=2.5,AgentHeight=5,AgentCanJump=true,AgentCanClimb=false,WaypointSpacing=2.5,Costs={Water=math.huge,DangerousSlope=5}}

-- Utilities
local function msg(t) task.spawn(function() pcall(function() local ch=TC.TextChannels and TC.TextChannels.RBXGeneral if ch and ch.SendAsync then ch:SendAsync(t) else local c=RS:FindFirstChild("DefaultChatSystemChatEvents") if c then c.SayMessageRequest:FireServer(t,"All") end end end) end) end

local function vK(v) return bit32.bor(bit32.lshift(math.floor(v.X/4),20),bit32.lshift(math.floor(v.Y/4),10),math.floor(v.Z/4)) end

local function cS(po) local r=W:Raycast(po+Vector3.new(0,3,0),Vector3.new(0,-8,0),ray) if not r then return false end local u=W:Raycast(po+Vector3.new(0,1,0),Vector3.new(0,3.5,0),ray) if C.safe and r.Instance then local m=r.Material if m==Enum.Material.Neon or m==Enum.Material.ForceField then return false end end return not u,r.Position end

local function rP(r) local a,ra=math.random()*6.28,math.random(r*0.4,r) return rt.Position+Vector3.new(math.cos(a)*ra,0,math.sin(a)*ra) end

local function blkP(po,d) local k=vK(po) blk[k]=tick()+(d or 60) if #blk>80 then local o for ky,v in pairs(blk) do if not o or v<blk[o] then o=ky end end blk[o]=nil end end

local function isB(po) local k=vK(po) if blk[k] then if blk[k]<=tick() then blk[k]=nil return false end return true end return false end

local function mHL() if hl then pcall(function() hl:Destroy() end) end hl=Instance.new("Highlight") hl.Parent,hl.FillColor,hl.OutlineColor,hl.FillTransparency,hl.OutlineTransparency=c,Color3.fromRGB(255,255,0),Color3.fromRGB(255,200,0),0.5,0 end

local function rHL() if hl then pcall(function() hl:Destroy() end) hl=nil end end

-- Pathfinding
local function walk(tg)
    if not C.path or isB(tg) then hm:MoveTo(tg) return true end
    local ck=vK(rt.Position).."_"..vK(tg)
    if C.cache and pC[ck] then local ca=pC[ck] if tick()-ca.t<45 then for _,w in ipairs(ca.w) do if not S.n or S.p then return false end hm:MoveTo(w.Position) if w.Action==Enum.PathWaypointAction.Jump then hm.Jump=true task.wait(0.1) end task.wait(0.12) end return true end end
    local rt=pR[ck] or 0 if rt>3 then blkP(tg,120) hm:MoveTo(tg) return false end
    local pa=PS:CreatePath(PC) local ok=pcall(function() pa:ComputeAsync(rt.Position,tg) end)
    if not ok or pa.Status~=Enum.PathStatus.Success then pR[ck]=rt+1 blkP(tg,40) hm:MoveTo(tg) return false end
    local wp=pa:GetWaypoints() if #wp==0 then hm:MoveTo(tg) return false end
    if C.cache then pC[ck]={w=wp,t=tick()} pR[ck]=nil if #pC>40 then local o for ky,v in pairs(pC) do if not o or v.t<pC[o].t then o=ky end end pC[o]=nil end end
    for i,w in ipairs(wp) do if not S.n or S.p then return false end hm:MoveTo(w.Position) if w.Action==Enum.PathWaypointAction.Jump then hm.Jump=true task.wait(0.08) end local d=(rt.Position-w.Position).Magnitude local to=math.clamp(d/18+0.25,0.15,2) local dl=tick()+to while tick()<dl do if not S.n or S.p then return false end if(rt.Position-w.Position).Magnitude<3 then break end task.wait(0.07) end if(rt.Position-w.Position).Magnitude>6 then blkP(w.Position,35) return false end end
    return true
end

-- Find Safe Position
local function fS()
    if #sfP>0 and math.random()<0.8 then local po=sfP[math.random(#sfP)] if(rt.Position-po).Magnitude<C.rng*1.3 then return po end end
    for i=1,12 do local tg=rP(C.rng) local ok,gn=cS(tg) if ok and not isB(tg) then local fn=gn+Vector3.new(0,3,0) table.insert(sfP,fn) if #sfP>20 then table.remove(sfP,math.random(1,#sfP-10)) end return fn end end
    return rt.Position+Vector3.new(math.random(-10,10),0,math.random(-10,10))
end

-- UI Window
local W=RF:CreateWindow({Name="🌟 Aura Farm Pro v4.1",Icon=0,LoadingTitle="Aura Farming",LoadingSubtitle="by Vinreach",Theme="Default",ToggleUIKeybind="K",ConfigurationSaving={Enabled=true,FolderName=nil,FileName="AuraFarm"}})

-- TAB 1: Record
local T1=W:CreateTab("⏺️ Record",4483362458)
T1:CreateSection("Movement Recorder")
rL=T1:CreateLabel("Status: 🟢 Ready | Frames: 0 | Time: 0s")
T1:CreateButton({Name="🎥 Record Toggle",Callback=function() if S.r then S.r=false RF:Notify({Title="⏹️ Stopped",Content=#rec.." frames ("..math.floor(tick()-rT).."s)",Duration=3}) else S.p,S.l,S.r,rec,rT,lR=false,false,true,{},tick(),0 RF:Notify({Title="🔴 Recording",Content="Move your character",Duration=2}) end end})
T1:CreateButton({Name="⏹️ Stop All",Callback=function() S.r,S.p,S.l,S.n=false,false,false,false if nT then pcall(function() nT:Set(false) end) end RF:Notify({Title="Stopped",Content="",Duration=1.5}) end})
T1:CreateButton({Name="▶️ Play Once",Callback=function() if #rec==0 then RF:Notify({Title="⚠️ Empty",Content="Record first!",Duration=2}) return end S.p,S.l,S.n=not S.p,false,false if nT then pcall(function() nT:Set(false) end) end end})
T1:CreateToggle({Name="🔁 Loop Replay",CurrentValue=false,Callback=function(v) if v and #rec==0 then RF:Notify({Title="⚠️ Empty",Content="Record first!",Duration=2}) return end S.l,S.p,S.n=v,v,false if nT then pcall(function() nT:Set(false) end) end end})
T1:CreateSlider({Name="⚡ Speed",Range={0.5,3},Increment=0.1,CurrentValue=1,Callback=function(v) C.spd=v end})
T1:CreateSlider({Name="📊 Record Rate (Hz)",Range={5,25},Increment=1,CurrentValue=12,Callback=function(v) C.rHz=1/v end})
T1:CreateSection("Data Management")
T1:CreateButton({Name="📤 Export",Callback=function() if #rec==0 then RF:Notify({Title="⚠️ Empty",Content="",Duration=2}) return end local d={v=4,f=rec,d=tick()-rT,c=C} setclipboard(H:JSONEncode(d)) RF:Notify({Title="✅ Exported",Content=#rec.." frames",Duration=2}) end})
T1:CreateButton({Name="📥 Import",Callback=function() local ok,d=pcall(function() return H:JSONDecode(getclipboard()) end) if ok and type(d)=="table" then if d.f then rec=d.f if d.c then for k,v in pairs(d.c) do if C[k]~=nil then C[k]=v end end end elseif #d>0 then rec=d end RF:Notify({Title="✅ Imported",Content=#rec.." frames",Duration=2}) else RF:Notify({Title="❌ Failed",Content="Invalid data",Duration=2}) end end})
T1:CreateButton({Name="🗑️ Clear",Callback=function() rec={} RF:Notify({Title="Cleared",Content="",Duration=1}) end})

-- TAB 2: NPC Farm
local T2=W:CreateTab("🤖 NPC Farm",4483362458)
T2:CreateSection("Smart Walk System")
nL=T2:CreateLabel("Status: 🔴 Off | Stuck: 0s")
nT=T2:CreateToggle({Name="🤖 NPC Mode",CurrentValue=false,Callback=function(v) S.n,S.p,S.l=v,false,false if v then stT,sfP=0,{} RF:Notify({Title="🤖 Started",Content="Walking...",Duration=2}) end end})
T2:CreateSlider({Name="📏 Range",Range={20,200},Increment=5,CurrentValue=50,Callback=function(v) C.rng=v end})
T2:CreateToggle({Name="🧭 Pathfinding",CurrentValue=false,Callback=function(v) C.path=v end})
T2:CreateToggle({Name="💾 Path Cache",CurrentValue=true,Callback=function(v) C.cache=v end})
T2:CreateToggle({Name="🦘 Anti-Sit",CurrentValue=true,Callback=function(v) C.sit=v end})
T2:CreateToggle({Name="🛡️ Safety Check",CurrentValue=true,Callback=function(v) C.safe=v end})
T2:CreateSection("Anti-Stuck")
T2:CreateSlider({Name="⏱️ Detection (s)",Range={4,20},Increment=1,CurrentValue=8,Callback=function(v) C.stT=v end})
T2:CreateSlider({Name="📍 TP Timeout (s)",Range={30,240},Increment=10,CurrentValue=120,Callback=function(v) C.stTP=v end})
T2:CreateToggle({Name="🚀 TP Unstuck",CurrentValue=true,Callback=function(v) C.tpS=v end})
T2:CreateToggle({Name="🔄 Auto Switch",CurrentValue=true,Callback=function(v) C.sw=v end})
T2:CreateSection("Social")
T2:CreateToggle({Name="💬 Auto-Reply",CurrentValue=false,Callback=function(v) S.rp=v end})

-- TAB 3: AFK
local T3=W:CreateTab("🌙 AFK",4483362458)
T3:CreateSection("AFK Detection")
aL=T3:CreateLabel("Status: 🔴 Off | Active: No")
T3:CreateToggle({Name="🌙 AFK System",CurrentValue=false,Callback=function(v) S.a=v if v then lI=tick() RF:Notify({Title="🌙 AFK On",Content="Monitoring...",Duration=2}) else S.ao=false rHL() end end})
T3:CreateSlider({Name="⏰ Timeout (min)",Range={1,30},Increment=1,CurrentValue=5,Callback=function(v) C.afkM=v end})
T3:CreateDropdown({Name="⚙️ Action",Options={"Replay","NPC Walk","Random"},CurrentOption="Replay",Callback=function(v) C.mode=v end})
T3:CreateToggle({Name="🎥 Anti-Kick",CurrentValue=true,Callback=function(v) C.kick=v end})
T3:CreateButton({Name="🧪 Test AFK Now",Callback=function() if not S.a then RF:Notify({Title="⚠️ Enable AFK",Content="Turn on AFK system first",Duration=2}) return end S.ao=true mHL() local m=C.mode if m=="Random" then m=math.random()>0.5 and "Replay" or "NPC Walk" end if m=="Replay" and #rec>0 then S.p,S.l,S.n=true,true,false if nT then pcall(function() nT:Set(false) end) end else S.n,S.p=true,false if nT then pcall(function() nT:Set(true) end) end end RF:Notify({Title="🧪 Testing",Content=m,Duration=3}) end})

-- TAB 4: Settings
local T4=W:CreateTab("⚙️ Settings",4483362458)
T4:CreateSection("Performance")
T4:CreateButton({Name="🧹 Clear Cache",Callback=function() pC,blk,sfP,pR={},{},{},{} RF:Notify({Title="✅ Cleared",Content="Cache cleared",Duration=1.5}) end})
T4:CreateButton({Name="🔄 Reset Char",Callback=function() c:BreakJoints() end})
T4:CreateButton({Name="📊 Memory Stats",Callback=function() local st={Frames=#rec,Cache=#pC,Blocked=#blk,Safe=#sfP,Retries=#pR} local t="" for k,v in pairs(st) do t=t..k..": "..v.."\n" end RF:Notify({Title="📊 Memory",Content=t,Duration=5}) end})
T4:CreateSection("Info")
T4:CreateLabel("Version: 4.1 Ultra")
T4:CreateLabel("By: Vinreach")
T4:CreateLabel("Performance Optimized")

-- Recording Loop
local lF=tick()
R.Heartbeat:Connect(function()
    if not S.r or not rt or not hm or not rt.Parent or not hm.Parent then return end
    local n=tick() if n-lF<C.rHz then return end lF=n
    local po,st,lk,di=rt.Position,hm:GetState(),rt.CFrame.LookVector,hm.MoveDirection
    if not po or not st or not lk or not di then return end
    if #rec>0 then local l=rec[#rec] if l.p and l.s and(po-l.p).Magnitude<0.35 and l.s==st then return end end
    table.insert(rec,{t=n-rT,p=po,s=st,lv=lk,md=di})
end)

-- Replay Loop
task.spawn(function()
    while true do
        if S.p and #rec>1 then
            for i=1,#rec-1 do
                if not S.p then break end
                local cu,nx=rec[i],rec[i+1]
                if not nx then break end
                local dt=(nx.t-cu.t)/C.spd
                if nx.lv then rt.CFrame=CFrame.lookAt(rt.Position,rt.Position+nx.lv) end
                if nx.md and nx.md.Magnitude>0 then hm:Move(nx.md,true) else hm:Move(Vector3.zero) end
                local st=cu.s
                if st==Enum.HumanoidStateType.Jumping then hm:ChangeState(Enum.HumanoidStateType.Jumping)
                elseif st==Enum.HumanoidStateType.Freefall then hm:ChangeState(Enum.HumanoidStateType.Freefall)
                elseif st==Enum.HumanoidStateType.Climbing then hm:ChangeState(Enum.HumanoidStateType.Climbing)
                elseif st==Enum.HumanoidStateType.Swimming then hm:ChangeState(Enum.HumanoidStateType.Swimming)
                elseif st==Enum.HumanoidStateType.Seated then hm.Sit=true end
                task.wait(math.max(dt,0.016))
            end
            if not S.l then S.p=false else task.wait(0.25) end
        else task.wait(0.05) end
    end
end)

-- NPC Walking Loop
task.spawn(function()
    while task.wait(0.12) do
        if S.n and not S.p then
            if hm.Sit and C.sit then hm:ChangeState(Enum.HumanoidStateType.Jumping) task.wait(0.18) continue end
            local tg=fS()
            if tg and not isB(tg) then walk(tg) else hm:MoveTo(rt.Position+Vector3.new(math.random(-7,7),0,math.random(-7,7))) end
            task.wait(0.15)
        end
    end
end)

-- Stuck Detection
task.spawn(function()
    while task.wait(0.9) do
        if S.n and not S.p then
            local mv=(rt.Position-lP).Magnitude
            if mv<0.8 then stT=stT+1 else stT=math.max(0,stT-1) end
            lP=rt.Position
            if C.sw and stT>300 and #rec>0 then S.n,S.p,S.l=false,true,true if nT then pcall(function() nT:Set(false) end) end RF:Notify({Title="🔄 Switched",Content="Using replay",Duration=3}) stT=0 end
            if stT>=C.stT and stT<C.stTP then hm.Jump=true local rn=Vector3.new(math.random(-9,9),0,math.random(-9,9)) hm:MoveTo(rt.Position+rn)
            elseif stT>=C.stTP and C.tpS then local fd=false for i=1,15 do local tr=rP(C.tpR) local ok,gn=cS(tr) if ok then rt.CFrame=CFrame.new(gn+Vector3.new(0,3,0)) fd=true break end end if not fd and #sfP>0 then rt.CFrame=CFrame.new(sfP[math.random(#sfP)]) end stT=0 end
        end
    end
end)

-- AFK System
task.spawn(function()
    while task.wait(6) do
        if S.a then
            local id=tick()-lI local th=C.afkM*60
            if id>=th and not S.ao then S.ao=true mHL() local m=C.mode if m=="Random" then m=math.random()>0.5 and "Replay" or "NPC Walk" end if m=="Replay" and #rec>0 then S.p,S.l,S.n=true,true,false if nT then pcall(function() nT:Set(false) end) end else S.n,S.p=true,false if nT then pcall(function() nT:Set(true) end) end end RF:Notify({Title="🌙 AFK Active",Content=m,Duration=3})
            elseif id<th and S.ao then S.ao=false rHL() end
        end
    end
end)

-- Anti-Kick
task.spawn(function()
    while task.wait(100) do
        if C.kick and(S.ao or S.n or S.p) then local cm=W.CurrentCamera if cm then cm.CFrame=cm.CFrame*CFrame.Angles(0,math.rad(0.08),0) end end
    end
end)

-- Input Detection
U.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.Keyboard or input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then lI=tick() if S.ao then S.ao=false rHL() end end end)

-- Auto-Reply
local function hR(pl,ms)
    if not S.rp or not(S.n or S.p) or pl==p then return end
    local lw=string.lower(ms)
    for _,kw in ipairs(KW) do if string.find(lw,kw) then task.delay(math.random(1,3),function() msg(RP[math.random(#RP)]) end) break end end
end
for _,pl in ipairs(P:GetPlayers()) do if pl~=p then pl.Chatted:Connect(function(ms) hR(pl,ms) end) end end
P.PlayerAdded:Connect(function(pl) if pl~=p then pl.Chatted:Connect(function(ms) hR(pl,ms) end) end end)

-- Status Updates
task.spawn(function()
    while task.wait(0.35) do
        local rS=S.r and "🔴 Rec" or(S.p and(S.l and "🔁 Loop" or "▶️ Play") or "🟢 Ready")
        local rTm=S.r and math.floor(tick()-rT) or 0
        pcall(function() rL:Set("Status: "..rS.." | Frames: "..#rec.." | Time: "..rTm.."s") end)
        local nS=S.n and "🟢 On" or "🔴 Off"
        pcall(function() nL:Set("Status: "..nS.." | Stuck: "..stT.."s") end)
        local aS=S.a and "🟢 On" or "🔴 Off" aS=aS..(S.ao and " | Active: ⚠️ Yes" or " | Active: No")
        pcall(function() aL:Set("Status: "..aS) end)
    end
end)

-- Character Respawn
p.CharacterAdded:Connect(function(nC) rC(nC) S.r,S.p,S.l,S.a=false,false,false,false rHL() ray.FilterDescendantsInstances={nC} lP,stT,lI,sfP=rt.Position,0,tick(),{} end)

RF:LoadConfiguration()
RF:Notify({Title="Aura Farm v4.1",Content="Loaded Successfully!",Duration=3})