local RF = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local char,rt,hm,cam = nil,nil,nil,nil
local function setup(ch) char=ch; rt=ch:WaitForChild("HumanoidRootPart"); hm=ch:WaitForChild("Humanoid"); cam=Workspace.CurrentCamera end
if player.Character then setup(player.Character) else player.CharacterAdded:Wait(); setup(player.Character) end
local S={rec=false,play=false,loop=false,npc=false,afk=false,afkAct=false,reply=false,ai=false,cin=false,hm=false}
local C={
 rHz=0.06,spd=1,rng=50,path=true,sit=true,stT=6,stTP=90,tpR=35,afkM=5,mode="Replay",sw=true,cache=true,kick=true,tpS=true,
 aiSpd=18,aiVr=0.85,aiRng=60,aiJmp=0.25,aiTh=4,aiStyle="Balanced",cmSm=0.8,fov=75,vidQ=60,prL=25,memL=100,autoR=true,dbg=false
}
local rec,recStart,vidFrames,pCache,blocked,pattempts,safePoints,camTrail = {},0,{}, {},{}, {},{}, {}
local lastPos = nil
local stuckT,lastInput = 0,tick()
local hl = nil
local aiState = {act="idle",next=0,lk=nil,cx=0,cy=0,mem={}}
local KW={"pls","trade","pet","fruit","money","garden","give","donate","help"}
local RP={"busy farming","afk","nty","not now","maybe later"}
local AI_ACT = {"walk","jump","spin","zigzag","explore","idle","circle","dash","crouch","look","wave","patrol","dodge","backup","wander","scan","follow","evade"}
local ray = RaycastParams.new(); ray.FilterType=Enum.RaycastFilterType.Exclude; ray.FilterDescendantsInstances={char}; ray.IgnoreWater=false
local PATH_CONFIG={AgentRadius=2,AgentHeight=5,AgentCanJump=true,AgentCanClimb=false,WaypointSpacing=2,Costs={Water=math.huge}}
local function msg(t) task.spawn(function() pcall(function() local ch=game:GetService("TextChatService").TextChannels and game:GetService("TextChatService").TextChannels.RBXGeneral if ch and ch.SendAsync then ch:SendAsync(t) else local c=ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents") if c then c.SayMessageRequest:FireServer(t,"All") end end end) end) end
local function vK(v) return bit32.bor(bit32.lshift(math.floor(v.X/4),20),bit32.lshift(math.floor(v.Y/4),10),math.floor(v.Z/4)) end
local function groundOK(p)
 local d=Workspace:Raycast(p+Vector3.new(0,3,0),Vector3.new(0,-8,0),ray)
 if not d then return false end
 local u=Workspace:Raycast(p+Vector3.new(0,1,0),Vector3.new(0,3.5,0),ray)
 if C.safeM and d.Instance then local m=d.Material if m==Enum.Material.Neon or m==Enum.Material.ForceField or m==Enum.Material.Glass then return false end end
 return not u,d.Position
end
local function randPos(r) local a=math.random()*6.283185307179586; local ra=math.random(r*0.5,r); return rt.Position+Vector3.new(math.cos(a)*ra,0,math.sin(a)*ra) end
local function blockAdd(p,d) local k=vK(p); blocked[k]=tick()+(d or 50); if table.create then end
 local count=0 for _ in pairs(blocked) do count=count+1 end
 if count> C.memL then local o; for ky,v in pairs(blocked) do if not o or v<blocked[o] then o=ky end end blocked[o]=nil end end
local function isBlocked(p) local k=vK(p) if blocked[k] then if blocked[k]<=tick() then blocked[k]=nil; return false end return true end return false end
local function hOn() if hl then pcall(function() hl:Destroy() end) end; hl=Instance.new("Highlight"); hl.Parent=char; hl.FillColor=Color3.fromRGB(30,170,255); hl.OutlineColor=Color3.fromRGB(20,100,170); hl.FillTransparency=0.45; hl.OutlineTransparency=0 end
local function hOff() if hl then pcall(function() hl:Destroy() end) hl=nil end end
local function aiPick()
 local w={walk=3,explore=2.5,patrol=2,wander=2,idle=1.5,jump=1.2,zigzag=1.2,circle=1,dash=0.8,spin=0.7,look=0.6,crouch=0.5,dodge=0.5,backup=0.4,wave=0.3,scan=1.2,follow=1.2,evade=1.1}
 local acts=AI_ACT; local tot=0 for _,a in ipairs(acts) do tot=tot+(w[a]or 1) end
 local r=math.random()*tot; local sel
 for _,a in ipairs(acts) do r=r-(w[a]or 1); if r<=0 then sel=a; break end end
 sel=sel or acts[1]; local dur=math.random(2,C.aiTh)
 aiState.act=sel; aiState.next=tick()+dur; aiState.last=tick(); return sel,dur
end
local function aiStep()
 if not S.ai or S.play then return end
 if tick()>=aiState.next then aiPick() end
 local act=aiState.act
 local function moveTo(tg,spd) local d=(tg-rt.Position)*Vector3.new(1,0,1) if d.Magnitude>1.5 then local n=d.Unit; local v=spd or C.aiSpd; humanoid=hm; humanoid:MoveTo(rt.Position+n*math.min(d.Magnitude,v)) end end
 if act=="walk" or act=="wander" then
  local tg=aiState.lk or randPos(C.aiRng*0.7); if not aiState.lk or (rt.Position-aiState.lk).Magnitude<5 then aiState.lk=randPos(C.aiRng*0.7); tg=aiState.lk end
  if not isBlocked(tg) then moveTo(tg,C.aiSpd) end
 elseif act=="jump" then if math.random()>1-C.aiJmp then hm.Jump=true end; moveTo(rt.Position+Vector3.new(math.random(-6,6),0,math.random(-6,6)))
 elseif act=="spin" then rt.CFrame=rt.CFrame*CFrame.Angles(0,math.rad(12),0)
 elseif act=="zigzag" then aiState.cx=(aiState.cx or 0)+1; local d=(aiState.cx%2==0) and 1 or -1; moveTo(rt.Position+Vector3.new(d*7,0,math.random(-2,2)))
 elseif act=="explore" or act=="patrol" then if #safePoints>0 and math.random()>0.4 then moveTo(safePoints[math.random(#safePoints)]) else moveTo(randPos(C.aiRng)) end
 elseif act=="circle" then aiState.cy=(aiState.cy or 0)+0.15; local r=10; moveTo(rt.Position+Vector3.new(math.cos(aiState.cy)*r,0,math.sin(aiState.cy)*r))
 elseif act=="dash" then hm:MoveTo(rt.Position+rt.CFrame.LookVector*15)
 elseif act=="look" then local pl=Players:GetPlayers() if #pl>1 then local t=pl[math.random(#pl)] if t~=player and t.Character and t.Character:FindFirstChild("HumanoidRootPart") then rt.CFrame=CFrame.lookAt(rt.Position,t.Character.HumanoidRootPart.Position) end end
 elseif act=="crouch" then hm:ChangeState(Enum.HumanoidStateType.Seated); task.wait(0.5); hm:ChangeState(Enum.HumanoidStateType.Running)
 elseif act=="dodge" then local d=Vector3.new(math.random()-0.5,0,math.random()-0.5).Unit; hm:MoveTo(rt.Position+d*8)
 elseif act=="backup" then hm:MoveTo(rt.Position-rt.CFrame.LookVector*6)
 elseif act=="idle" then hm:MoveTo(rt.Position)
 elseif act=="scan" then local found=false; for _,pl in ipairs(Players:GetPlayers()) do if pl~=player and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") then found=true; break end end if not found then moveTo(randPos(30)) end
 elseif act=="follow" then local pl=Players:GetPlayers(); if #pl>1 then local t=pl[math.random(#pl)]; if t~=player and t.Character and t.Character:FindFirstChild("HumanoidRootPart") then moveTo(t.Character.HumanoidRootPart.Position, C.aiSpd*0.9) end end
 elseif act=="evade" then hm:MoveTo(rt.Position-rt.CFrame.LookVector*10)
 end
end
local cmObj={o=CFrame.new(),t=CFrame.new(),s=0,d=0,idx=1}
local function camUpdate()
 if not S.cin or not cam or #camTrail<2 then return end
 local now=tick()
 if now-cmObj.s>=cmObj.d then cmObj.idx=(cmObj.idx%#camTrail)+1; local nxt=camTrail[cmObj.idx]; if nxt and nxt.cf then cmObj.o=cam.CFrame; cmObj.t=nxt.cf; cmObj.s=now; cmObj.d=math.random(2,5)*C.cmSm end end
 if cmObj.d>0 then local a=math.clamp((now-cmObj.s)/cmObj.d,0,1); local ea=TweenService:GetValue(a,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut); cam.CFrame=cmObj.o:Lerp(cmObj.t,ea); cam.FieldOfView=C.fov end
end
local function camRecord() if rt then table.insert(camTrail,{cf=cam.CFrame,p=rt.Position,t=tick()-recStart}); if #camTrail>200 then table.remove(camTrail,1) end end end
local function vidStart() S.rec=true; vidFrames={}; recStart=tick(); RF:Notify({Title="Recording V2",Content="Started",Duration=2}) end
local function vidStop() S.rec=false; local data={v=6,f=vidFrames,d=tick(),fps=C.vidQ,cam=camTrail}; pcall(function() setclipboard(HttpService:JSONEncode(data)) end); RF:Notify({Title="Exported V2",Content=#vidFrames.." frames",Duration=2}) end
local function walkTo(tg)
 if not C.path or isBlocked(tg) then hm:MoveTo(tg); return true end
 local key=vK(rt.Position).."_"..vK(tg)
 if C.cache and pCache[key] and tick()-pCache[key].t<60 then for _,w in ipairs(pCache[key].w) do if not S.n or S.play then return false end hm:MoveTo(w.Position); if w.Action==Enum.PathWaypointAction.Jump then hm.Jump=true; task.wait(0.06) end task.wait(0.08) end return true end
 local attempts=pattempts[key] or 0
 if attempts>2 then blockAdd(tg,100); hm:MoveTo(tg); return false end
 local path=PathfindingService:CreatePath(PATH_CONFIG)
 local ok=pcall(function() path:ComputeAsync(rt.Position,tg) end)
 if not ok or path.Status~=Enum.PathStatus.Success then pattempts[key]=(attempts+1); blockAdd(tg,30); hm:MoveTo(tg); return false end
 local wps=path:GetWaypoints()
 if #wps==0 then hm:MoveTo(tg); return false end
 if C.cache then pCache[key]={w=wps,t=tick()}; pattempts[key]=nil; end
 for _,wp in ipairs(wps) do if not S.n or S.play then return false end hm:MoveTo(wp.Position); if wp.Action==Enum.PathWaypointAction.Jump then hm.Jump=true; task.wait(0.06) end local dl=tick()+math.clamp((rt.Position-wp.Position).Magnitude/20+0.2,0.12,1.2) while tick()<dl do if not S.n or S.play then return false end if (rt.Position-wp.Position).Magnitude<2.5 then break end task.wait(0.04) end end
 return true
end
local function findSpot()
 if #safePoints>0 and math.random()<0.75 then local pnt=safePoints[math.random(#safePoints)]; if (rt.Position-pnt).Magnitude<C.rng*1.2 then return pnt end end
 for i=1,10 do local tg=randPos(C.rng); local ok,gn=groundOK(tg); if ok and not isBlocked(tg) then local fn=gn+Vector3.new(0,3,0); table.insert(safePoints,fn); if #safePoints>30 then table.remove(safePoints,math.random(1,#safePoints-15)) end return fn end end
 return rt.Position+Vector3.new(math.random(-8,8),0,math.random(-8,8))
end
local lastRecTick=tick()
RunService.Heartbeat:Connect(function()
 if not S.rec then return end
 local now=tick()
 if now-lastRecTick<C.rHz then return end
 lastRecTick=now
 if rt and hm and rt.Parent then
  local po=rt.Position; local st=hm:GetState(); local lv=rt.CFrame.LookVector; local md=hm.MoveDirection
  if #rec>0 then local l=rec[#rec] if l.p and l.s and (po-l.p).Magnitude<0.3 and l.s==st then return end end
  table.insert(rec,{t=now-recStart,p=po,s=st,lv=lv,md=md}); camRecord()
  table.insert(vidFrames,{t=now,p=po,cf=cam.CFrame,fov=cam.FieldOfView})
 end
end)
task.spawn(function()
 while task.wait(0.02) do
  if S.play and #rec>1 then
   for i=1,#rec-1 do
    if not S.play then break end
    local cur, nxt = rec[i], rec[i+1]
    if not nxt then break end
    local dt=(nxt.t-cur.t)/C.spd
    if S.hm then dt=dt*(1+math.random()*0.15-0.075) end
    if nxt.lv then rt.CFrame=CFrame.lookAt(rt.Position,rt.Position+nxt.lv) end
    if nxt.md and nxt.md.Magnitude>0 then hm:Move(nxt.md,true) else hm:Move(Vector3.zero) end
    if cur.s==Enum.HumanoidStateType.Jumping then hm:ChangeState(Enum.HumanoidStateType.Jumping) elseif cur.s==Enum.HumanoidStateType.Seated then hm.Sit=true end
    task.wait(math.max(dt,0.015))
   end
   if not S.loop then S.play=false else task.wait(0.2) end
  else task.wait(0.05) end
 end
end)
task.spawn(function()
 while task.wait(0.1) do
  if (S.npc or S.ai) and not S.play then
   if hm.Sit and C.sit then hm:ChangeState(Enum.HumanoidStateType.Jumping); task.wait(0.15); continue end
   if S.ai then aiStep() else local tg=findSpot(); if tg and not isBlocked(tg) then walkTo(tg) end end
   task.wait(0.12)
  end
 end
end)
task.spawn(function()
 while task.wait(0.025) do if S.cin then camUpdate() end end
end)
task.spawn(function()
 while task.wait(0.8) do
  if (S.npc or S.ai) and not S.play then
   local mv=(rt.Position-lastPos).Magnitude if not lastPos then mv=0 end
   if mv<0.6 then stuckT=stuckT+1 else stuckT=math.max(0,stuckT-1) end
   lastPos=rt.Position
   if C.sw and stuckT>250 and #rec>0 then S.npc,S.ai,S.play,S.loop=false,false,true,true; stuckT=0 end
   if stuckT>=C.stT and stuckT<C.stTP then hm.Jump=true; hm:MoveTo(rt.Position+Vector3.new(math.random(-8,8),0,math.random(-8,8)))
   elseif stuckT>=C.stTP and C.tpS then for i=1,12 do local tr=randPos(C.tpR); local ok,gn=groundOK(tr); if ok then rt.CFrame=CFrame.new(gn+Vector3.new(0,3,0)); break end end stuckT=0 end
  end
 end
end)
task.spawn(function()
 while task.wait(5) do
  if S.afk then
   local idle=tick()-lastInput; local th=C.afkM*60
   if idle>=th and not S.afkAct then
    S.afkAct=true; hOn()
    if C.mode=="AI Walk" then S.ai,S.npc,S.play=true,true,false
    elseif C.mode=="Replay" and #rec>0 then S.play,S.loop,S.npc,S.ai=true,true,false,false
    else S.npc,S.play,S.ai=true,false,false end
   elseif idle<th and S.afkAct and C.autoR then S.afkAct=false; hOff() end
  end
 end
end)
task.spawn(function()
 while task.wait(90) do if C.kick and (S.afkAct or S.npc or S.play or S.ai) and cam then cam.CFrame=cam.CFrame*CFrame.Angles(0,math.rad(0.05),0) end end end)
UserInputService.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Keyboard or i.UserInputType==Enum.UserInputType.MouseButton1 then lastInput=tick(); if S.afkAct and C.autoR then S.afkAct=false; hOff() end end end)
local function autoReply(pl,ms) if not S.reply or not (S.npc or S.play or S.ai) or pl==player then return end local lw=string.lower(ms) for _,k in ipairs(KW) do if string.find(lw,k) then task.delay(math.random(1,3),function() msg(RP[math.random(#RP)]) end); break end end end
for _,pl in ipairs(Players:GetPlayers()) do if pl~=player then pl.Chatted:Connect(function(ms) autoReply(pl,ms) end) end end
Players.PlayerAdded:Connect(function(pl) if pl~=player then pl.Chatted:Connect(function(ms) autoReply(pl,ms) end) end end)
local W = RF:CreateWindow({Name="Aura Farm v6",LoadingTitle="Aura Farm",LoadingSubtitle="Aura Core Edition",ToggleUIKeybind="K",ConfigurationSaving={Enabled=true,FolderName=nil,FileName="AuraFarm"}})
local T1 = W:CreateTab("Main",4483362458)
local statusLabel = T1:CreateLabel("Status: Ready | Mode: Idle | FPS: 0 | Frames: 0")
local T2 = W:CreateTab("AI",4483362458)
local aiLabel = T2:CreateLabel("AI: Off | Action: idle | Next: 0s")
local aiToggle = T2:CreateToggle({Name="AI Walk Active",CurrentValue=false,Callback=function(v) S.ai=v; S.npc=v; if v then aiPick() end end})
T2:CreateDropdown({Name="AI Style",Options={"Balanced","Passive","Aggressive"},CurrentOption="Balanced",Callback=function(v) C.aiStyle=v end})
T2:CreateSlider({Name="AI Speed",Range={10,30},Increment=1,CurrentValue=C.aiSpd,Callback=function(v) C.aiSpd=v end})
T2:CreateSlider({Name="AI Range",Range={30,150},Increment=5,CurrentValue=C.aiRng,Callback=function(v) C.aiRng=v end})
T2:CreateSlider({Name="Action Time",Range={2,10},Increment=1,CurrentValue=C.aiTh,Callback=function(v) C.aiTh=v end})
local T3 = W:CreateTab("Record",4483362458)
local rLabel = T3:CreateLabel("Record: Idle | Frames: 0")
T3:CreateButton({Name="Start Record V2",Callback=vidStart})
T3:CreateButton({Name="Stop & Export V2",Callback=vidStop})
T3:CreateToggle({Name="Cinematic Mode",CurrentValue=false,Callback=function(v) S.cin=v end})
T3:CreateSlider({Name="Record Hz",Range={0.01,0.2},Increment=0.01,CurrentValue=C.rHz,Callback=function(v) C.rHz=v end})
local T4 = W:CreateTab("NPC",4483362458)
local npcLabel = T4:CreateLabel("NPC: Off | Stuck: 0s")
T4:CreateToggle({Name="NPC Mode",CurrentValue=false,Callback=function(v) S.npc=v; S.ai=v; if v then stuckT=0; safePoints={} end end})
T4:CreateToggle({Name="Smooth Walk",CurrentValue=true,Callback=function(v) C.path=v end})
T4:CreateToggle({Name="Jump Assist",CurrentValue=true,Callback=function(v) C.aiJmp = v and 0.25 or 0 end})
T4:CreateToggle({Name="Auto Unstuck",CurrentValue=true,Callback=function(v) C.sw=v end})
T4:CreateSlider({Name="Range",Range={20,200},Increment=5,CurrentValue=C.rng,Callback=function(v) C.rng=v end})
local T5 = W:CreateTab("Settings",4483362458)
T5:CreateSection("Toggles")
T5:CreateToggle({Name="AFK System",CurrentValue=false,Callback=function(v) S.afk=v; if v then lastInput=tick() else S.afkAct=false; hOff() end end})
T5:CreateToggle({Name="Auto Reply",CurrentValue=false,Callback=function(v) S.reply=v end})
T5:CreateToggle({Name="AntiKick",CurrentValue=true,Callback=function(v) C.kick=v end})
T5:CreateDropdown({Name="AFK Action",Options={"Replay","NPC","AI"},CurrentOption="Replay",Callback=function(v) C.mode=v end})
T5:CreateSection("Advanced")
T5:CreateSlider({Name="AI Variation",Range={0.3,1},Increment=0.05,CurrentValue=C.aiVr,Callback=function(v) C.aiVr=v end})
T5:CreateSlider({Name="Memory Limit",Range={50,200},Increment=10,CurrentValue=C.memL,Callback=function(v) C.memL=v end})
T5:CreateToggle({Name="Debug Mode",CurrentValue=false,Callback=function(v) C.dbg=v end})
local T6 = W:CreateTab("Debug",4483362458)
local dbgLabel = T6:CreateLabel("Debug: Off")
T6:CreateButton({Name="Clear Cache",Callback=function() pCache,blocked,pattempts,safePoints={}, {}, {}, {} RF:Notify({Title="Cleared",Duration=1}) end})
T6:CreateButton({Name="Reset AI",Callback=function() aiState={act="idle",next=0,lk=nil,cx=0,cy=0,mem={}} aiPick() end})
task.spawn(function() while task.wait(0.3) do
 local fps=math.floor(1/math.max(0.0001,RunService.RenderStepped:Wait() or 0.016))
 statusLabel:Set("Status: "..(S.play and "Playing" or S.rec and "Recording" or S.npc and "NPC" or "Idle").." | Mode: "..(S.ai and "AI" or S.npc and "NPC" or "Replay").." | FPS: "..fps.." | Frames: "..#rec)
 rLabel:Set("Record: "..(S.rec and "Recording V2" or "Idle").." | Frames: "..#vidFrames)
 npcLabel:Set("NPC: "..(S.npc and "On" or "Off").." | Stuck: "..stuckT.."s")
 aiLabel:Set("AI: "..(S.ai and "On" or "Off").." | Action: "..(aiState.act or "idle").." | Next: "..math.max(0,math.floor((aiState.next or 0)-tick())).."s")
 dbgLabel:Set("Debug: "..(C.dbg and "On" or "Off"))
end end)
player.CharacterAdded:Connect(function(ch) setup(ch); S.rec,S.play,S.loop,S.npc,S.afk,S.afkAct,S.ai,S.cin=false,false,false,false,false,false,false,false; hOff(); ray.FilterDescendantsInstances={ch}; lastPos=rt.Position; stuckT=0; aiState={act="idle",next=0,lk=nil,cx=0,cy=0,mem={}} end)
RF:LoadConfiguration()
RF:Notify({Title="Aura Farm v6",Content="Dark Edition Loaded",Duration=3})