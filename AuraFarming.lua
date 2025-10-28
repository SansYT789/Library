-- Aura Farm Pro v5.0
local RF=loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Services
local P,R,PS,U,RS,TC,W,H,TS=game:GetService("Players"),game:GetService("RunService"),game:GetService("PathfindingService"),game:GetService("UserInputService"),game:GetService("ReplicatedStorage"),game:GetService("TextChatService"),workspace,game:GetService("HttpService"),game:GetService("TweenService")

-- Player
local p,c,rt,hm,cam=P.LocalPlayer
local function rC(ch)c,rt,hm=ch,ch:WaitForChild("HumanoidRootPart"),ch:WaitForChild("Humanoid")cam=W.CurrentCamera end
if p.Character then rC(p.Character)else p.CharacterAdded:Wait()rC(p.Character)end

-- State
local S={r=false,p=false,l=false,n=false,a=false,ao=false,rp=false,ai=false,cm=false,rec=false}

-- Config
local C={rHz=0.08,spd=1,rng=50,path=false,sit=true,stT=8,stTP=120,tpR=35,afkM=5,mode="Replay",sw=true,cache=true,kick=true,tpS=true,ai=false,cmS=true,cmSm=0.7,fov=70,vidQ=60}

-- Data
local rec,rT,lR,pC,blk,lP,stT,lI,hl,sfP,pR,cmD,vidF={},0,0,{},{},rt.Position,0,tick(),nil,{},{},{},{}

-- UI Refs
local nT,rL,nL,aL,aiT,cmL

-- Constants
local KW={"pls","trade","pet","fruit","money","garden","give","donate"}
local RP={"no","nah","sorry","nope","busy","afk farming"}

-- Raycast
local ray=RaycastParams.new()
ray.FilterType,ray.FilterDescendantsInstances,ray.IgnoreWater=Enum.RaycastFilterType.Exclude,{c},false

-- Path Config
local PC={AgentRadius=2.5,AgentHeight=5,AgentCanJump=true,AgentCanClimb=false,WaypointSpacing=2.5,Costs={Water=math.huge,DangerousSlope=5}}

-- Utilities
local function msg(t)task.spawn(function()pcall(function()local ch=TC.TextChannels and TC.TextChannels.RBXGeneral if ch and ch.SendAsync then ch:SendAsync(t)else local c=RS:FindFirstChild("DefaultChatSystemChatEvents")if c then c.SayMessageRequest:FireServer(t,"All")end end end)end)end

local function vK(v)return bit32.bor(bit32.lshift(math.floor(v.X/4),20),bit32.lshift(math.floor(v.Y/4),10),math.floor(v.Z/4))end

local function cS(po)local r=W:Raycast(po+Vector3.new(0,3,0),Vector3.new(0,-8,0),ray)if not r then return false end local u=W:Raycast(po+Vector3.new(0,1,0),Vector3.new(0,3.5,0),ray)if C.safe and r.Instance then local m=r.Material if m==Enum.Material.Neon or m==Enum.Material.ForceField then return false end end return not u,r.Position end

local function rP(r)local a,ra=math.random()*6.28,math.random(r*0.4,r)return rt.Position+Vector3.new(math.cos(a)*ra,0,math.sin(a)*ra)end

local function blkP(po,d)local k=vK(po)blk[k]=tick()+(d or 60)if#blk>80 then local o for ky,v in pairs(blk)do if not o or v<blk[o]then o=ky end end blk[o]=nil end end

local function isB(po)local k=vK(po)if blk[k]then if blk[k]<=tick()then blk[k]=nil return false end return true end return false end

local function mHL()if hl then pcall(function()hl:Destroy()end)end hl=Instance.new("Highlight")hl.Parent,hl.FillColor,hl.OutlineColor,hl.FillTransparency,hl.OutlineTransparency=c,Color3.fromRGB(255,255,0),Color3.fromRGB(255,200,0),0.5,0 end

local function rHL()if hl then pcall(function()hl:Destroy()end)hl=nil end end

-- AI Walk System
local aiS={lT=0,lA="idle",aT=0,mem={}}
local function aiD()
    local acts={"walk","jump","spin","zigzag","explore"}
    local act=acts[math.random(#acts)]
    local dur=math.random(2,8)
    aiS.lA,aiS.aT=act,tick()+dur
    return act,dur
end

local function aiW()
    if not S.ai or S.p then return end
    local now=tick()
    if now<aiS.aT then
        local act=aiS.lA
        if act=="walk"then
            local tg=rP(C.rng*0.6)
            if not isB(tg)then hm:MoveTo(tg)end
        elseif act=="jump"then
            if math.random()>0.7 then hm.Jump=true end
            hm:MoveTo(rt.Position+Vector3.new(math.random(-5,5),0,math.random(-5,5)))
        elseif act=="spin"then
            rt.CFrame=rt.CFrame*CFrame.Angles(0,math.rad(15),0)
            task.wait(0.05)
        elseif act=="zigzag"then
            local dir=math.random()>0.5 and 1 or -1
            hm:MoveTo(rt.Position+Vector3.new(dir*8,0,math.random(-3,3)))
        elseif act=="explore"then
            if#sfP>0 and math.random()>0.5 then
                hm:MoveTo(sfP[math.random(#sfP)])
            else
                local tg=rP(C.rng*0.8)
                hm:MoveTo(tg)
            end
        end
    else
        aiD()
    end
end

-- Cinematic Camera
local cmO={o=CFrame.new(),t=CFrame.new(),s=0,d=0}
local function cmU()
    if not S.cm or not cam then return end
    local now=tick()
    if now-cmO.s>=cmO.d and#cmD>1 then
        local idx=math.random(1,#cmD)
        local nxt=cmD[idx]
        if nxt and nxt.cf then
            cmO.o=cam.CFrame
            cmO.t=nxt.cf
            cmO.s,cmO.d=now,math.random(2,5)
        end
    end
    if cmO.d>0 then
        local a=math.clamp((now-cmO.s)/cmO.d,0,1)
        local ea=TS:GetValue(a,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut)
        cam.CFrame=cmO.o:Lerp(cmO.t,ea)
        cam.FieldOfView=C.fov
    end
end

local function cmR()
    if not rt then return end
    table.insert(cmD,{cf=cam.CFrame,p=rt.Position,t=tick()-rT})
    if#cmD>150 then table.remove(cmD,1)end
end

-- Video Recording
local function vidS()
    S.rec=true
    vidF={}
    RF:Notify({Title="🎬 Recording",Content="Video started",Duration=2})
end

local function vidE()
    S.rec=false
    local data={v=5,f=vidF,d=tick(),fps=C.vidQ}
    setclipboard(H:JSONEncode(data))
    RF:Notify({Title="✅ Saved",Content=#vidF.." frames",Duration=3})
end

-- Pathfinding
local function walk(tg)
    if not C.path or isB(tg)then hm:MoveTo(tg)return true end
    local ck=vK(rt.Position).."_"..vK(tg)
    if C.cache and pC[ck]then local ca=pC[ck]if tick()-ca.t<45 then for _,w in ipairs(ca.w)do if not S.n or S.p then return false end hm:MoveTo(w.Position)if w.Action==Enum.PathWaypointAction.Jump then hm.Jump=true task.wait(0.1)end task.wait(0.12)end return true end end
    local rt=pR[ck]or 0 if rt>3 then blkP(tg,120)hm:MoveTo(tg)return false end
    local pa=PS:CreatePath(PC)local ok=pcall(function()pa:ComputeAsync(rt.Position,tg)end)
    if not ok or pa.Status~=Enum.PathStatus.Success then pR[ck]=rt+1 blkP(tg,40)hm:MoveTo(tg)return false end
    local wp=pa:GetWaypoints()if#wp==0 then hm:MoveTo(tg)return false end
    if C.cache then pC[ck]={w=wp,t=tick()}pR[ck]=nil if#pC>40 then local o for ky,v in pairs(pC)do if not o or v.t<pC[o].t then o=ky end end pC[o]=nil end end
    for i,w in ipairs(wp)do if not S.n or S.p then return false end hm:MoveTo(w.Position)if w.Action==Enum.PathWaypointAction.Jump then hm.Jump=true task.wait(0.08)end local d=(rt.Position-w.Position).Magnitude local to=math.clamp(d/18+0.25,0.15,2)local dl=tick()+to while tick()<dl do if not S.n or S.p then return false end if(rt.Position-w.Position).Magnitude<3 then break end task.wait(0.07)end if(rt.Position-w.Position).Magnitude>6 then blkP(w.Position,35)return false end end
    return true
end

local function fS()
    if#sfP>0 and math.random()<0.8 then local po=sfP[math.random(#sfP)]if(rt.Position-po).Magnitude<C.rng*1.3 then return po end end
    for i=1,12 do local tg=rP(C.rng)local ok,gn=cS(tg)if ok and not isB(tg)then local fn=gn+Vector3.new(0,3,0)table.insert(sfP,fn)if#sfP>20 then table.remove(sfP,math.random(1,#sfP-10))end return fn end end
    return rt.Position+Vector3.new(math.random(-10,10),0,math.random(-10,10))
end

-- UI
local W=RF:CreateWindow({Name="🌟 Aura Farm v5.0",Icon=0,LoadingTitle="Aura Farming",LoadingSubtitle="Ultimate Edition",Theme="Default",ToggleUIKeybind="K",ConfigurationSaving={Enabled=true,FolderName=nil,FileName="AuraFarm"}})

-- TAB 1: Record
local T1=W:CreateTab("⏺️ Record",4483362458)
T1:CreateSection("Movement Recorder")
rL=T1:CreateLabel("Status: 🟢 Ready | Frames: 0 | Time: 0s")
T1:CreateButton({Name="🎥 Record",Callback=function()if S.r then S.r=false RF:Notify({Title="⏹️ Stopped",Content=#rec.." frames",Duration=3})else S.p,S.l,S.r,rec,rT,lR=false,false,true,{},tick(),0 RF:Notify({Title="🔴 Recording",Content="Move character",Duration=2})end end})
T1:CreateButton({Name="⏹️ Stop All",Callback=function()S.r,S.p,S.l,S.n,S.ai=false,false,false,false,false if nT then pcall(function()nT:Set(false)end)end if aiT then pcall(function()aiT:Set(false)end)end RF:Notify({Title="Stopped",Content="",Duration=1.5})end})
T1:CreateButton({Name="▶️ Play",Callback=function()if#rec==0 then RF:Notify({Title="⚠️ Empty",Content="Record first!",Duration=2})return end S.p,S.l,S.n,S.ai=not S.p,false,false,false if nT then pcall(function()nT:Set(false)end)end if aiT then pcall(function()aiT:Set(false)end)end end})
T1:CreateToggle({Name="🔁 Loop",CurrentValue=false,Callback=function(v)if v and#rec==0 then RF:Notify({Title="⚠️ Empty",Content="Record first!",Duration=2})return end S.l,S.p,S.n,S.ai=v,v,false,false if nT then pcall(function()nT:Set(false)end)end if aiT then pcall(function()aiT:Set(false)end)end end})
T1:CreateSlider({Name="⚡ Speed",Range={0.5,3},Increment=0.1,CurrentValue=1,Callback=function(v)C.spd=v end})
T1:CreateSection("Data")
T1:CreateButton({Name="📤 Export",Callback=function()if#rec==0 then return end local d={v=5,f=rec,d=tick()-rT,c=C,cm=cmD}setclipboard(H:JSONEncode(d))RF:Notify({Title="✅ Exported",Content=#rec.." frames",Duration=2})end})
T1:CreateButton({Name="📥 Import",Callback=function()local ok,d=pcall(function()return H:JSONDecode(getclipboard())end)if ok and type(d)=="table"then if d.f then rec=d.f if d.c then for k,v in pairs(d.c)do if C[k]~=nil then C[k]=v end end end if d.cm then cmD=d.cm end elseif#d>0 then rec=d end RF:Notify({Title="✅ Imported",Content=#rec.." frames",Duration=2})else RF:Notify({Title="❌ Failed",Content="Invalid data",Duration=2})end end})
T1:CreateButton({Name="🗑️ Clear",Callback=function()rec={}cmD={}RF:Notify({Title="Cleared",Content="",Duration=1})end})

-- TAB 2: NPC Farm
local T2=W:CreateTab("🤖 NPC",4483362458)
T2:CreateSection("Smart Walk")
nL=T2:CreateLabel("Status: 🔴 Off | Stuck: 0s")
nT=T2:CreateToggle({Name="🤖 NPC Mode",CurrentValue=false,Callback=function(v)S.n,S.p,S.l,S.ai=v,false,false,false if aiT then pcall(function()aiT:Set(false)end)end if v then stT,sfP=0,{}RF:Notify({Title="🤖 Started",Content="Walking...",Duration=2})end end})
T2:CreateToggle({Name="🧠 AI Walk",CurrentValue=false,Callback=function(v)C.ai=v if aiT then pcall(function()aiT:Set(v)end)end end})
aiT=T2:CreateToggle({Name="🎯 AI Active",CurrentValue=false,Callback=function(v)S.ai,S.n,S.p=v,v,false if v then aiS.lT=tick()aiD()RF:Notify({Title="🧠 AI On",Content="Smart movement",Duration=2})end end})
T2:CreateSlider({Name="📏 Range",Range={20,200},Increment=5,CurrentValue=50,Callback=function(v)C.rng=v end})
T2:CreateToggle({Name="🧭 Pathfinding",CurrentValue=false,Callback=function(v)C.path=v end})
T2:CreateToggle({Name="💾 Cache",CurrentValue=true,Callback=function(v)C.cache=v end})
T2:CreateToggle({Name="🦘 Anti-Sit",CurrentValue=true,Callback=function(v)C.sit=v end})
T2:CreateSection("Anti-Stuck")
T2:CreateSlider({Name="⏱️ Detect (s)",Range={4,20},Increment=1,CurrentValue=8,Callback=function(v)C.stT=v end})
T2:CreateSlider({Name="📍 TP Timeout",Range={30,240},Increment=10,CurrentValue=120,Callback=function(v)C.stTP=v end})
T2:CreateToggle({Name="🚀 TP Unstuck",CurrentValue=true,Callback=function(v)C.tpS=v end})
T2:CreateToggle({Name="🔄 Auto Switch",CurrentValue=true,Callback=function(v)C.sw=v end})

-- TAB 3: Cinematic
local T3=W:CreateTab("🎬 Cinema",4483362458)
T3:CreateSection("Camera System")
cmL=T3:CreateLabel("Status: 🔴 Off | Frames: 0")
T3:CreateToggle({Name="🎥 Cinematic Cam",CurrentValue=false,Callback=function(v)S.cm=v if v then if#cmD<2 then RF:Notify({Title="⚠️ No Data",Content="Record movement first",Duration=2})S.cm=false return end cam.CameraType=Enum.CameraType.Scriptable cmO.s,cmO.d=0,0 RF:Notify({Title="🎬 Cinema On",Content="Smooth camera",Duration=2})else cam.CameraType=Enum.CameraType.Custom end end})
T3:CreateSlider({Name="🎯 FOV",Range={50,120},Increment=5,CurrentValue=70,Callback=function(v)C.fov=v end})
T3:CreateSlider({Name="⚡ Smoothness",Range={0.3,1},Increment=0.1,CurrentValue=0.7,Callback=function(v)C.cmSm=v end})
T3:CreateToggle({Name="📹 Auto Record Cam",CurrentValue=true,Callback=function(v)C.cmS=v end})
T3:CreateSection("Video Recording")
T3:CreateButton({Name="🎬 Start Video",Callback=vidS})
T3:CreateButton({Name="⏹️ Stop & Export",Callback=vidE})
T3:CreateSlider({Name="📊 Quality (FPS)",Range={30,120},Increment=10,CurrentValue=60,Callback=function(v)C.vidQ=v end})
T3:CreateButton({Name="🗑️ Clear Camera",Callback=function()cmD={}RF:Notify({Title="Cleared",Content="Camera data reset",Duration=1.5})end})

-- TAB 4: AFK
local T4=W:CreateTab("🌙 AFK",4483362458)
T4:CreateSection("AFK Detection")
aL=T4:CreateLabel("Status: 🔴 Off | Active: No")
T4:CreateToggle({Name="🌙 AFK System",CurrentValue=false,Callback=function(v)S.a=v if v then lI=tick()RF:Notify({Title="🌙 AFK On",Content="Monitoring...",Duration=2})else S.ao=false rHL()end end})
T4:CreateSlider({Name="⏰ Timeout (min)",Range={1,30},Increment=1,CurrentValue=5,Callback=function(v)C.afkM=v end})
T4:CreateDropdown({Name="⚙️ Action",Options={"Replay","NPC Walk","AI Walk"},CurrentOption="Replay",Callback=function(v)C.mode=v end})
T4:CreateToggle({Name="🎥 Anti-Kick",CurrentValue=true,Callback=function(v)C.kick=v end})
T4:CreateToggle({Name="💬 Auto-Reply",CurrentValue=false,Callback=function(v)S.rp=v end})

-- TAB 5: Settings
local T5=W:CreateTab("⚙️ Settings",4483362458)
T5:CreateButton({Name="🧹 Clear Cache",Callback=function()pC,blk,sfP,pR={},{},{},{}RF:Notify({Title="✅ Cleared",Content="Cache reset",Duration=1.5})end})
T5:CreateButton({Name="🔄 Reset Char",Callback=function()c:BreakJoints()end})
T5:CreateButton({Name="📊 Stats",Callback=function()local st="Frames: "..#rec.."\nCache: "..#pC.."\nBlocked: "..#blk.."\nSafe: "..#sfP.."\nCamera: "..#cmD RF:Notify({Title="📊 Memory",Content=st,Duration=5})end})
T5:CreateLabel("Version: 5.0 Ultimate")

-- Recording Loop
local lF=tick()
R.Heartbeat:Connect(function()
    if not S.r or not rt or not hm or not rt.Parent or not hm.Parent then return end
    local n=tick()if n-lF<C.rHz then return end lF=n
    local po,st,lk,di=rt.Position,hm:GetState(),rt.CFrame.LookVector,hm.MoveDirection
    if not po or not st or not lk or not di then return end
    if#rec>0 then local l=rec[#rec]if l.p and l.s and(po-l.p).Magnitude<0.35 and l.s==st then return end end
    table.insert(rec,{t=n-rT,p=po,s=st,lv=lk,md=di})
    if C.cmS and S.r then cmR()end
    if S.rec then table.insert(vidF,{t=n,p=po,cf=cam.CFrame,fov=cam.FieldOfView})end
end)

-- Replay Loop
task.spawn(function()
    while true do
        if S.p and#rec>1 then
            for i=1,#rec-1 do
                if not S.p then break end
                local cu,nx=rec[i],rec[i+1]
                if not nx then break end
                local dt=(nx.t-cu.t)/C.spd
                if nx.lv then rt.CFrame=CFrame.lookAt(rt.Position,rt.Position+nx.lv)end
                if nx.md and nx.md.Magnitude>0 then hm:Move(nx.md,true)else hm:Move(Vector3.zero)end
                local st=cu.s
                if st==Enum.HumanoidStateType.Jumping then hm:ChangeState(Enum.HumanoidStateType.Jumping)
                elseif st==Enum.HumanoidStateType.Freefall then hm:ChangeState(Enum.HumanoidStateType.Freefall)
                elseif st==Enum.HumanoidStateType.Climbing then hm:ChangeState(Enum.HumanoidStateType.Climbing)
                elseif st==Enum.HumanoidStateType.Swimming then hm:ChangeState(Enum.HumanoidStateType.Swimming)
                elseif st==Enum.HumanoidStateType.Seated then hm.Sit=true end
                task.wait(math.max(dt,0.016))
            end
            if not S.l then S.p=false else task.wait(0.25)end
        else task.wait(0.05)end
    end
end)

-- NPC/AI Loop
task.spawn(function()
    while task.wait(0.12)do
        if(S.n or S.ai)and not S.p then
            if hm.Sit and C.sit then hm:ChangeState(Enum.HumanoidStateType.Jumping)task.wait(0.18)continue end
            if S.ai and C.ai then
                aiW()
            else
                local tg=fS()
                if tg and not isB(tg)then walk(tg)else hm:MoveTo(rt.Position+Vector3.new(math.random(-7,7),0,math.random(-7,7)))end
            end
            task.wait(0.15)
        end
    end
end)

-- Camera Loop
task.spawn(function()
    while task.wait(0.03)do
        if S.cm then cmU()end
    end
end)

-- Stuck Detection
task.spawn(function()
    while task.wait(0.9)do
        if(S.n or S.ai)and not S.p then
            local mv=(rt.Position-lP).Magnitude
            if mv<0.8 then stT=stT+1 else stT=math.max(0,stT-1)end
            lP=rt.Position
            if C.sw and stT>300 and#rec>0 then S.n,S.ai,S.p,S.l=false,false,true,true if nT then pcall(function()nT:Set(false)end)end if aiT then pcall(function()aiT:Set(false)end)end RF:Notify({Title="🔄 Switched",Content="Using replay",Duration=3})stT=0 end
            if stT>=C.stT and stT<C.stTP then hm.Jump=true local rn=Vector3.new(math.random(-9,9),0,math.random(-9,9))hm:MoveTo(rt.Position+rn)
            elseif stT>=C.stTP and C.tpS then local fd=false for i=1,15 do local tr=rP(C.tpR)local ok,gn=cS(tr)if ok then rt.CFrame=CFrame.new(gn+Vector3.new(0,3,0))fd=true break end end if not fd and#sfP>0 then rt.CFrame=CFrame.new(sfP[math.random(#sfP)])end stT=0 end
        end
    end
end)

-- AFK System
task.spawn(function()
    while task.wait(6)do
        if S.a then
            local id=tick()-lI local th=C.afkM*60
            if id>=th and not S.ao then S.ao=true mHL()local m=C.mode if m=="AI Walk"then S.ai,S.n,S.p=true,true,false if aiT then pcall(function()aiT:Set(true)end)end elseif m=="Replay"and#rec>0 then S.p,S.l,S.n,S.ai=true,true,false,false if nT then pcall(function()nT:Set(false)end)end if aiT then pcall(function()aiT:Set(false)end)end else S.n,S.p,S.ai=true,false,false if nT then pcall(function()nT:Set(true)end)end if aiT then pcall(function()aiT:Set(false)end)end end RF:Notify({Title="🌙 AFK Active",Content=m,Duration=3})
            elseif id<th and S.ao then S.ao=false rHL()end
        end
    end
end)

-- Anti-Kick
task.spawn(function()
    while task.wait(100)do
        if C.kick and(S.ao or S.n or S.p or S.ai)then if cam then cam.CFrame=cam.CFrame*CFrame.Angles(0,math.rad(0.08),0)end end
    end
end)

-- Input Detection
U.InputBegan:Connect(function(input)if input.UserInputType==Enum.UserInputType.Keyboard or input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then lI=tick()if S.ao then S.ao=false rHL()end end end)

-- Auto-Reply
local function hR(pl,ms)
    if not S.rp or not(S.n or S.p or S.ai)or pl==p then return end
    local lw=string.lower(ms)
    for _,kw in ipairs(KW)do if string.find(lw,kw)then task.delay(math.random(1,3),function()msg(RP[math.random(#RP)])end)break end end
end
for _,pl in ipairs(P:GetPlayers())do if pl~=p then pl.Chatted:Connect(function(ms)hR(pl,ms)end)end end
P.PlayerAdded:Connect(function(pl)if pl~=p then pl.Chatted:Connect(function(ms)hR(pl,ms)end)end end)

-- Status Updates
task.spawn(function()
    while task.wait(0.35)do
        local rS=S.r and "🔴 Rec"or(S.p and(S.l and "🔁 Loop"or "▶️ Play")or "🟢 Ready")
        local rTm=S.r and math.floor(tick()-rT)or 0
        pcall(function()rL:Set("Status: "..rS.." | Frames: "..#rec.." | Time: "..rTm.."s")end)
        local nS=(S.n or S.ai)and "🟢 On"or "🔴 Off"
        pcall(function()nL:Set("Status: "..nS.." | Stuck: "..stT.."s")end)
        local aS=S.a and "🟢 On"or "🔴 Off"aS=aS..(S.ao and " | Active: ⚠️ Yes"or " | Active: No")
        pcall(function()aL:Set("Status: "..aS)end)
        local cmS=S.cm and "🎬 On"or "🔴 Off"
        pcall(function()cmL:Set("Status: "..cmS.." | Frames: "..#cmD)end)
    end
end)

-- Character Respawn
p.CharacterAdded:Connect(function(nC)rC(nC)S.r,S.p,S.l,S.a,S.ai,S.cm=false,false,false,false,false,false rHL()ray.FilterDescendantsInstances={nC}lP,stT,lI,sfP=rt.Position,0,tick(),{}end)

RF:LoadConfiguration()
RF:Notify({Title="Aura Farm v5.0",Content="Aura Farming Loaded!",Duration=3})