local Modules = {}
Modules.__index = Modules

local Services = {
    Players = game:GetService("Players"),
    Workspace = game:GetService("Workspace"),
    RunService = game:GetService("RunService"),
    TweenService = game:GetService("TweenService"),
    ReplicatedStorage = game:GetService("ReplicatedStorage")
}

local Config = {
    DebugInfo = false,
    DefaultTweenSpeed = 300,
    DefaultBoatSpeed = 150,
    SnapDistance = 40,
    MaxTweenDistance = 200,
}

local Player = Services.Players.LocalPlayer
local Character, HRP, Humanoid

local placeId = game.PlaceId
local Sea1 = placeId == 2753915549
local Sea2 = placeId == 4442272183
local Sea3 = placeId == 7449423635

if not Sea1 and not Sea2 and not Sea3 then 
    warn("⚠️ This is not Blox Fruits!") 
end

local State = {
    currentTween = nil,
    hoverBlock = nil,
    shouldTween = false,
    onFarm = false,
    tweenBtnFix = false,
    stopBoatTween = false
}

Modules.Initialized = false

function Modules:DebugPrint(...)
    if Config.DebugInfo then
        print(string.format("[%.2f]", tick()), ...)
    end
end

function Modules:SafePcall(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        Modules:DebugPrint("❌ Error:", result)
    end
    return success, result
end

function Modules:IsAlive(char)
    if not char then return false end
    local h = char:FindFirstChild("Humanoid")
    return h and h.Health > 0
end

function Modules.CheckMyBoat()
    local boats = Services.Workspace:FindFirstChild("Boats")
    if not boats then return false end
    if not Character or not Humanoid or not HRP then return false end

    for _, v in ipairs(boats:GetChildren()) do
        if v:FindFirstChild("Owner") then
            if tostring(v.Owner.Value) == tostring(Player.Name) then
                return v
            end

            if (Humanoid and Humanoid.Sit == true) and v:FindFirstChild("VehicleSeat") and tostring(v.Owner.Value) ~= tostring(Player.Name) and (HRP and (HRP.Position - v.VehicleSeat.Position).Magnitude <= 2.5) then
                return v
            end
        end
    end
    return false
end

Modules.HoverBlock = {}
function Modules.HoverBlock:Create()
    local oldBlock = Services.Workspace:FindFirstChild("HoverBlock")
    if oldBlock then oldBlock:Destroy() end

    local hoverBlock = Instance.new("Part")
    hoverBlock.Name = "HoverBlock"
    hoverBlock.Size = Vector3.new(1, 1, 1)
    hoverBlock.Anchored = true
    hoverBlock.CanCollide = false
    hoverBlock.CanTouch = false
    hoverBlock.Transparency = 1
    hoverBlock.Parent = Services.Workspace

    State.hoverBlock = hoverBlock
    return hoverBlock
end

function Modules.HoverBlock:Initialize()
    local hoverBlock = self:Create()

    -- Heartbeat safety check
    Services.RunService.Heartbeat:Connect(function()
        if not State.hoverBlock or not State.hoverBlock.Parent then
            State.hoverBlock = self:Create()
            if HRP then
                State.hoverBlock.CFrame = HRP.CFrame
            end
        end
    end)

    -- Main update loop
    task.spawn(function()
        repeat task.wait() until Character and Character:FindFirstChild("HumanoidRootPart")
        
        if Services.Workspace:FindFirstChild("HoverBlock") and State.hoverBlock and State.hoverBlock.Parent then
            State.hoverBlock.CFrame = HRP.CFrame
        end

        while task.wait() do
            if not (State.hoverBlock and State.hoverBlock.Parent and HRP) then
                getgenv().OnFarm = false
                continue
            end

            getgenv().OnFarm = State.shouldTween == true
            
            if getgenv().OnFarm then
                local distance = (HRP.Position - State.hoverBlock.Position).Magnitude
                
                if distance <= Config.MaxTweenDistance then
                    HRP.CFrame = State.hoverBlock.CFrame
                else
                    State.hoverBlock.CFrame = HRP.CFrame
                end
            end

            -- Noclip handling
            local lastNoclipState = nil
            if lastNoclipState ~= getgenv().OnFarm then
                lastNoclipState = getgenv().OnFarm
                for _, part in ipairs(Character:GetChildren()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = not lastNoclipState
                    end
                end
            end
        end
    end)

    return hoverBlock
end

Modules.Portal = {}
local PortalLocations = {
    Sea3 = {
        ["Castle On The Sea"] = Vector3.new(-5058.7749, 314.5155, -3155.8833),
        ["Tiki Outpost"] = Vector3.new(-16799.091796875, 84.32279968261719, 291.0728454589844),
        ["Submerged Island"] = Vector3.new(10213.701171875, -1733.5025634765625, 9940.189453125),
        ["Floating Turtle"] = Vector3.new(-11993.5801, 334.7813, -8844.1826),
        ["Dimension Shift"] = Vector3.new(-2097.3447265625, 4776.24462890625, -15013.4990234375),
        ["Hydra Island"] = Vector3.new(5756.8374, 610.4240, -253.9254),
        ["Mansion"] = Vector3.new(-12463.8740, 374.9145, -7523.7739),
        ["Great Tree"] = Vector3.new(3028.209228515625, 2280.84619140625, -7324.2880859375),
        ["Temple Of Time"] = Vector3.new(28282.5703, 14896.8506, 105.1043),
        ["Beautiful Pirate Room"] = Vector3.new(5314.5820, 25.4194, -125.9423)
    },
    Sea2 = {
        ["Mansion"] = Vector3.new(-288.4625, 306.1306, 598.0),
        ["Don Swan Room"] = Vector3.new(2284.9121, 15.1520, 905.4829),
        ["Cursed Ship"] = Vector3.new(923.2125, 126.9760, 32852.8320),
        ["Zombie Island"] = Vector3.new(-6508.5581, 89.0350, -132.8395)
    },
    Sea1 = {
        ["Sky 3"] = Vector3.new(-7894.6201, 5545.4917, -380.2467),
        ["Sky 2"] = Vector3.new(-4607.8228, 872.5423, -1667.5569),
        ["Underwater City"] = Vector3.new(61163.8516, 11.7595, 1819.7842),
        ["Whirlpool"] = Vector3.new(3876.2805, 35.1061, -1939.3202)
    }
}

function Modules.Portal:GetClosest(targetCFrame)
    if not targetCFrame or not HRP then return nil end

    local seaTable = Sea3 and PortalLocations.Sea3 
                  or Sea2 and PortalLocations.Sea2 
                  or Sea1 and PortalLocations.Sea1
    
    if not seaTable then return nil end

    local closestPortal = nil
    local minDistance = math.huge
    local targetPos = targetCFrame.Position
    local hrpPos = HRP.Position

    for _, portalPos in pairs(seaTable) do
        local dist = (portalPos - targetPos).Magnitude
        if dist < minDistance then
            minDistance = dist
            closestPortal = portalPos
        end
    end
    
    -- Only return portal if it's actually closer than direct path
    if minDistance <= (targetPos - hrpPos).Magnitude then
        return closestPortal
    end
    
    return nil
end

function Modules.Portal:RequestEntrance(portalPos, btnState)
    if not portalPos or not HRP then return false end

    local completed = false

    local success, err = pcall(function()
        -- Temple of Time → Great Tree
        if portalPos == Vector3.new(3028.209228515625, 2280.84619140625, -7324.2880859375) then
            if (Vector3.new(28282.5703125, 14896.8505859375, 105.1042709350586) - HRP.Position).Magnitude > 10000 then
                CommF_:InvokeServer("requestEntrance", Vector3.new(28282.5703125, 14896.8505859375, 105.1042709350586))
            end

            task.wait(0.1)
            State.hoverBlock.CFrame = CFrame.new(28609.650390625, 14896.5458984375, 105.68901062011719)
            task.wait(0.15)
            
            if (HRP.Position - Vector3.new(28609.6504, 14896.5459, 105.6890)).Magnitude <= 10 then
                CommF_:InvokeServer("RaceV4Progress", "TeleportBack")
            end
            
            task.wait(0.1)
            completed = (HRP.Position - portalPos).Magnitude <= 5

        -- Dimension Shift (Cake Island Mirror)
        elseif portalPos == Vector3.new(-2097.3447265625, 4776.24462890625, -15013.4990234375) then
            task.wait(0.1)
            
            local map = Services.Workspace:FindFirstChild("Map")
            local cake = map and map:FindFirstChild("CakeLoaf")
            local mirror = cake and cake:FindFirstChild("BigMirror")

            if mirror and mirror.Other.Transparency == 0 then
                HRP.CFrame = mirror.Main.CFrame
                task.wait(0.05)
                completed = true
            end

        -- Submerged Island
        elseif portalPos == Vector3.new(10213.701171875, -1733.5025634765625, 9940.189453125) then
            if (Vector3.new(-16269.408203125, 23.979995727539062, 1371.662353515625) - HRP.Position).Magnitude > 1205 then
                CommF_:InvokeServer("requestEntrance", Vector3.new(-5058.7749, 314.5155, -3155.8833))
                task.wait(0.15)

                State.hoverBlock.CFrame = CFrame.new(-5097.1318359375, 318.50201416015625, -3178.3984375)
                task.wait(0.1)
            end

            Modules.Tween:ToTarget(CFrame.new(-16269.408203125, 23.979995727539062, 1371.662353515625), btnState)
            task.wait(0.15)
            
            if (Vector3.new(-16269.408203125, 23.979995727539062, 1371.662353515625) - HRP.Position).Magnitude <= 10 then
                game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Net"):WaitForChild("RF/SubmarineWorkerSpeak"):InvokeServer("TravelToSubmergedIsland")
            end
            
            task.wait(0.1)
            completed = (portalPos - HRP.Position).Magnitude <= 100

        -- Tiki Outpost
        elseif portalPos == Vector3.new(-16799.091796875, 84.32279968261719, 291.0728454589844) then
            CommF_:InvokeServer("requestEntrance", Vector3.new(-5058.7749, 314.5155, -3155.8833))
            task.wait(0.15)

            State.hoverBlock.CFrame = CFrame.new(-5097.1318359375, 318.50201416015625, -3178.3984375)
            task.wait(0.1)
            completed = (portalPos - HRP.Position).Magnitude <= 5

        -- Standard portal
        else
            CommF_:InvokeServer("requestEntrance", portalPos)
            task.wait(0.05)
            completed = true
        end
    end)

    if not success then
        Modules:DebugPrint("❌ Portal entrance error:", err)
    end

    return completed
end

Modules.Tween = {}
function Modules.Tween:ToTarget(targetCFrame, btnState)
    if not (HRP and Humanoid and Humanoid.Health > 0) then return end
    if not targetCFrame then return end
    if not State.hoverBlock then return end

    if getgenv().TweenBtnFix and State.shouldTween then return end
    
    local dist = (targetCFrame.Position - HRP.Position).Magnitude
    
    -- Snap if close enough
    if dist <= Config.SnapDistance then
        State.hoverBlock.CFrame = targetCFrame
        return
    end

    -- Handle button state
    if btnState then
        if State.currentTween and State.currentTween.PlaybackState == Enum.PlaybackState.Playing then
            State.currentTween:Cancel()
            State.currentTween = nil
        end
        
        getgenv().TweenBtnFix = true
        State.shouldTween = true
    end

    -- Calculate tween duration
    local tweenSpeed = getConfig and getConfig("Tween Speed") or Config.DefaultTweenSpeed
    local tweenDuration = dist / tweenSpeed

    -- Create and play tween
    local tweenInfo = TweenInfo.new(tweenDuration, Enum.EasingStyle.Linear)
    local tween = Services.TweenService:Create(State.hoverBlock, tweenInfo, {CFrame = targetCFrame})
    State.currentTween = tween
 
    -- Handle sitting characters
    if Humanoid.Sit == true then
        State.hoverBlock.CFrame = CFrame.new(
            State.hoverBlock.Position.X, 
            targetCFrame.Y, 
            State.hoverBlock.Position.Z
        )
    end
    
    tween:Play()

    -- Monitor tween cancellation
    task.spawn(function()
        while tween.PlaybackState == Enum.PlaybackState.Playing do
            if not State.shouldTween then
                tween:Cancel()

                if btnState then
                    getgenv().TweenBtnFix = false
                    State.shouldTween = false
                end
                break
            end
            task.wait(0.1)
        end
    end)

    -- Handle completion for button state
    if btnState then
        tween.Completed:Connect(function()
            if (targetCFrame.Position - HRP.Position).Magnitude <= Config.SnapDistance then
                HRP.CFrame = targetCFrame
            end

            getgenv().TweenBtnFix = false
            State.shouldTween = false
        end)
    end
end

function Modules.Tween:WithPortal(targetCFrame, btnState)
    if not targetCFrame or not HRP then return end

    local portalPos = Modules.Portal:GetClosest(targetCFrame)

    if portalPos then
        Modules:DebugPrint("🌀 Using portal shortcut")
        
        local success = Modules.Portal:RequestEntrance(portalPos, btnState)
        
        -- Retry once if failed
        if not success then
            Modules:DebugPrint("⚠️ Retrying portal entrance...")
            success = Modules.Portal:RequestEntrance(portalPos, btnState)
        end

        if success then
            task.wait(0.15)
            self:ToTarget(targetCFrame, btnState)
        else
            Modules:DebugPrint("⚠️ Portal failed, using direct path")
            self:ToTarget(targetCFrame, btnState)
        end
    else
        self:ToTarget(targetCFrame, btnState)
    end
end

function Modules.Tween:Boat(targetCFrame)
    if not (HRP and Humanoid and Humanoid.Health > 0) then return end
    if not targetCFrame then return end

    local myShip = Modules.CheckMyBoat()
    if not myShip then return end
    
    local vehicleSeat = myShip:FindFirstChild("VehicleSeat")
    if not vehicleSeat then return end

    local dist = (targetCFrame.Position - vehicleSeat.Position).Magnitude
    local boatSpeed = Config.DefaultBoatSpeed
    local duration = dist / boatSpeed

    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
    local tween = Services.TweenService:Create(vehicleSeat, tweenInfo, {CFrame = targetCFrame})
    
    tween:Play()

    -- Monitor for stop signal
    task.spawn(function()
        while tween.PlaybackState == Enum.PlaybackState.Playing do
            if getgenv().StopBoatTween then
                tween:Cancel()
                break
            end
            task.wait(0.1)
        end
    end)
end

function Modules.Tween:StopAll()
    getgenv().TweenBtnFix = false
    getgenv().StopBoatTween = true
    State.shouldTween = false
    
    if State.currentTween and State.currentTween.PlaybackState == Enum.PlaybackState.Playing then
        State.currentTween:Cancel()
        State.currentTween = nil
    end
    
    if HRP:FindFirstChild("VinreachHoverClip") then
        HRP:FindFirstChild("VinreachHoverClip"):Destroy()
    end
    
    if Services.Workspace:FindFirstChild("HoverBlock") and State.hoverBlock and State.hoverBlock.Parent then
        State.hoverBlock.CFrame = HRP.CFrame
    end
    
    task.wait(0.1)
    getgenv().StopBoatTween = false
    
    Modules:DebugPrint("🛑 All tweens stopped")
end

local function InitializeReferences()
    Character = Player.Character or Player.CharacterAdded:Wait()
    HRP = Character:WaitForChild("HumanoidRootPart", 5)
    Humanoid = Character:WaitForChild("Humanoid", 5)

    if not HRP or not Humanoid then
        warn("❌ Failed to get character parts!")
        return false
    end
    
    return true
end

function Modules:Initialize()
    if not InitializeReferences() then
        warn("❌ Critical initialization failure!")
        return false
    end

    Modules:DebugPrint("✅ Character references initialized")
    
    -- Initialize hover block system
    Modules.HoverBlock:Initialize()
    Modules:DebugPrint("✅ Hover block system initialized")
    
    Modules:DebugPrint("🚀 Tween Library fully initialized!")
    
    Modules.Initialized = true
    _G.ModulesInitialized = true
    return true
end

-- Auto-initialize
local Refs = Modules:Initialize()
if not Refs then
    warn("Critical initialization failure!")
    return
end
Modules:DebugPrint("Initialization successful!")
print("Modules Loaded")

Player.CharacterAdded:Connect(function(newChar)
    Character = newChar
    Modules:DebugPrint("Character respawned, reinitializing...")

    task.wait(0.5)

    local newRefs = Modules:Initialize()
    if newRefs then
        Refs = newRefs
        Modules:DebugPrint("References reinitialized")
    end
end)

function Modules:UpdateConfig(newConfig)
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
            Modules:DebugPrint("Config Update:", key, "=", tostring(value))
        end
    end
end

function Modules:TweenToTarget(input, btn)
    return Modules.Tween:WithPortal(input, btn) 
end

function Modules:TweenByBoatToTarget(input)
    return Modules.Tween:Boat(input) 
end

function Modules:StopAllTween()
    return Modules.Tween:StopAll()
end

function Modules:GetBtnTweenStatus()
    return getgenv().TweenBtnFix
end

return Modules