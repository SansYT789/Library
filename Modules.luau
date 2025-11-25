local Modules = {}
Modules.__index = Modules
Modules.Version = "1.3"

local Services = {
    Players = game:GetService("Players"),
    Workspace = game:GetService("Workspace"),
    RunService = game:GetService("RunService"),
    TweenService = game:GetService("TweenService"),
    ReplicatedStorage = game:GetService("ReplicatedStorage")
}

local Config = {
    -- Debug & Performance
    DebugInfo = false,
    PerformanceMode = false,
    
    -- Tween Speeds
    DefaultTweenSpeed = 300,
    DefaultBoatSpeed = 150,
    FastTweenSpeed = 450,
    SlowTweenSpeed = 250,
    
    -- Distance Thresholds
    SnapDistance = 40,
    MaxTweenDistance = 200,
    
    -- Safety & Validation
    EnableSafetyChecks = true,
    AutoRecoverHoverBlock = true,
    EnableNoclip = true,
    
    -- Timing
    TweenUpdateRate = 0.1,
    PortalRetryDelay = 0.15,
    MaxPortalRetries = 2,
    
    -- Boat Settings
    BoatSnapDistance = 50,
    EnableBoatCollision = false,
}

local Player = Services.Players.LocalPlayer
local Character, HRP, Humanoid

local placeId = game.PlaceId
local Sea1 = placeId == 2753915549
local Sea2 = placeId == 4442272183
local Sea3 = placeId == 7449423635

if not Sea1 and not Sea2 and not Sea3 then 
    warn("⚠️ This is not Blox Fruits! Some features may not work.") 
end

local State = {
    -- Tween States
    currentTween = nil,
    boatTween = nil,
    hoverBlock = nil,
    
    -- Flags
    shouldTween = false,
    onFarm = false,
    tweenBtnFix = false,
    stopBoatTween = false,
    isInitialized = false,
    
    -- Locks
    isTweeningPlayer = false,
    isTweeningBoat = false,
    isPortalActive = false,
    
    -- Counters
    tweenCount = 0,
    errorCount = 0,
    lastNoclipState = nil,
}

function Modules:DebugPrint(...)
    if Config.DebugInfo then
        local args = {...}
        local formatted = {}
        for i, v in ipairs(args) do
            formatted[i] = tostring(v)
        end
        print(string.format("[%.3f] [Modules]", tick()), table.unpack(formatted))
    end
end

function Modules:SafePcall(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        State.errorCount = State.errorCount + 1
        Modules:DebugPrint("❌ Error #" .. State.errorCount .. ":", result)
        
        -- Auto-recovery for critical errors
        if State.errorCount > 10 and Config.EnableSafetyChecks then
            Modules:DebugPrint("⚠️ Too many errors, attempting recovery...")
            task.spawn(function()
                Modules:RecoverFromError()
            end)
        end
    end
    return success, result
end

local Remotes = Services.ReplicatedStorage:WaitForChild("Remotes", 3)
if not Remotes then
    Modules:DebugPrint("Remotes do not exist or load too slowly")
end
local CommF_ = Remotes:WaitForChild("CommF_", 3)
if not CommF_ then
    Modules:DebugPrint("CommF_ does not exist in Remotes")
end

function Modules:RecoverFromError()
    State.errorCount = 0
    self:StopTween("all")
    
    if Config.AutoRecoverHoverBlock and State.hoverBlock then
        task.wait(0.5)
        Modules.HoverBlock:Initialize()
    end
end

function Modules:IsAlive(char)
    char = char or Character
    if not char then return false end
    local h = char:FindFirstChild("Humanoid")
    return h and h.Health > 0 and h.Parent
end

function Modules:ValidateReferences()
    if not Character or not Character.Parent then return false end
    if not HRP or not HRP.Parent then return false end
    if not Humanoid or not Humanoid.Parent then return false end
    if Humanoid.Health <= 0 then return false end
    return true
end

function Modules:GetTweenSpeed(speedType)
    speedType = speedType or "default"
    
    -- Check for external config first
    if getConfig then
        local externalSpeed = getConfig("Tween Speed")
        if externalSpeed and type(externalSpeed) == "number" and externalSpeed > 0 then
            return externalSpeed
        end
    end
    
    -- Fallback to internal config
    if speedType == "fast" then
        return Config.FastTweenSpeed
    elseif speedType == "slow" then
        return Config.SlowTweenSpeed
    else
        return Config.DefaultTweenSpeed
    end
end

function Modules:GetBoatSpeed()
    if getConfig then
        local externalSpeed = getConfig("Boat Tween Speed")
        if externalSpeed and type(externalSpeed) == "number" and externalSpeed > 0 then
            return externalSpeed
        end
    end
    return Config.DefaultBoatSpeed
end

function Modules.CheckMyBoat()
    if not Modules:ValidateReferences() then return nil end
    
    local boats = Services.Workspace:FindFirstChild("Boats")
    if not boats then return nil end

    for _, boat in ipairs(boats:GetChildren()) do
        if not boat:FindFirstChild("Owner") then continue end
        
        local ownerValue = boat.Owner.Value
        
        -- Own boat
        if tostring(ownerValue) == tostring(Player.Name) then
            return boat
        end
        
        -- Sitting in someone else's boat
        if Humanoid and Humanoid.Sit then
            local vehicleSeat = boat:FindFirstChild("VehicleSeat")
            if vehicleSeat and (HRP.Position - vehicleSeat.Position).Magnitude <= 2.5 then
                return boat
            end
        end
    end
    
    return nil
end

function Modules.CheckInMyBoat()
    if not Modules:ValidateReferences() then return false end

    local myBoat = Modules.CheckMyBoat()
    if not myBoat then 
        Modules:DebugPrint("⚠️ No boat found")
        return false
    end

    local vehicleSeat = myBoat:FindFirstChild("VehicleSeat")
    if not vehicleSeat then 
        Modules:DebugPrint("⚠️ Boat has no VehicleSeat")
        return false
    end
    
    if Humanoid.Sit == true and (HRP.Position - vehicleSeat.Position).Magnitude <= 2.5 then
        return true
    end
    
    return false
end

Modules.HoverBlock = {}
function Modules.HoverBlock:Create()
    local oldBlock = Services.Workspace:FindFirstChild("HoverBlock")
    if oldBlock then 
        Modules:SafePcall(function() oldBlock:Destroy() end)
    end

    local hoverBlock = Instance.new("Part")
    hoverBlock.Name = "HoverBlock"
    hoverBlock.Size = Vector3.new(1, 1, 1)
    hoverBlock.Anchored = true
    hoverBlock.CanCollide = false
    hoverBlock.CanTouch = false
    hoverBlock.CanQuery = false
    hoverBlock.Transparency = 1
    hoverBlock.Material = Enum.Material.SmoothPlastic
    
    -- Add tag for easy identification
    if hoverBlock:FindFirstChild("ModuleTag") == nil then
        local tag = Instance.new("BoolValue")
        tag.Name = "ModuleTag"
        tag.Value = true
        tag.Parent = hoverBlock
    end
    
    Modules:SafePcall(function()
        hoverBlock.Parent = Services.Workspace
    end)

    State.hoverBlock = hoverBlock
    return hoverBlock
end

function Modules.HoverBlock:Validate()
    if not State.hoverBlock or not State.hoverBlock.Parent then
        return false
    end
    
    -- Check if it's actually in workspace
    if State.hoverBlock.Parent ~= Services.Workspace then
        return false
    end
    
    return true
end

function Modules.HoverBlock:Initialize()
    local hoverBlock = self:Create()
    
    if not hoverBlock then
        warn("❌ Failed to create hover block!")
        return nil
    end

    -- Heartbeat safety check with validation
    Services.RunService.Heartbeat:Connect(function()
        if not Config.AutoRecoverHoverBlock then return end
        
        if not self:Validate() then
            Modules:DebugPrint("🔄 Recovering hover block...")
            State.hoverBlock = self:Create()
            
            if HRP and State.hoverBlock then
                State.hoverBlock.CFrame = HRP.CFrame
            end
        end
    end)

    -- Main update loop with enhanced error handling
    task.spawn(function()
        repeat task.wait(0.1) until Character and Character:FindFirstChild("HumanoidRootPart")
        
        Modules:DebugPrint("✅ Hover block update loop started")
        
        -- Initial positioning
        if self:Validate() and HRP then
            State.hoverBlock.CFrame = HRP.CFrame
        end

        while task.wait(Config.TweenUpdateRate) do
            if not Modules:ValidateReferences() then
                getgenv().OnFarm = false
                continue
            end
            
            if not self:Validate() then
                continue
            end

            -- Update farm state
            local shouldBeFarming = State.shouldTween == true
            getgenv().OnFarm = shouldBeFarming
            
            if shouldBeFarming then
                local distance = (HRP.Position - State.hoverBlock.Position).Magnitude
                
                -- Smooth position sync
                if distance <= Config.MaxTweenDistance then
                    Modules:SafePcall(function()
                        if Modules.CheckInMyBoat() then
                            State.hoverBlock.CFrame = HRP.CFrame
                        else
                            HRP.CFrame = State.hoverBlock.CFrame
                        end
                    end)
                else
                    Modules:SafePcall(function()
                        State.hoverBlock.CFrame = HRP.CFrame
                    end)
                end
            end

            -- Enhanced noclip handling
            if Config.EnableNoclip then
                if State.lastNoclipState ~= shouldBeFarming then
                    State.lastNoclipState = shouldBeFarming
                    
                    Modules:SafePcall(function()
                        for _, part in ipairs(Character:GetChildren()) do
                            if part:IsA("BasePart") then
                                part.CanCollide = not shouldBeFarming
                            end
                        end
                    end)
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
        ["Beautiful Pirate"] = Vector3.new(5314.5820, 25.4194, -125.9423)
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
    if not targetCFrame or not Modules:ValidateReferences() then 
        return nil 
    end

    local seaTable = Sea3 and PortalLocations.Sea3 
                  or Sea2 and PortalLocations.Sea2 
                  or Sea1 and PortalLocations.Sea1
    
    if not seaTable then return nil end

    local closestPortal = nil
    local closestName = nil
    local minDistance = math.huge
    local targetPos = targetCFrame.Position
    local hrpPos = HRP.Position
    local directDist = (targetPos - hrpPos).Magnitude

    for name, portalPos in pairs(seaTable) do
        local distToPortal = (portalPos - targetPos).Magnitude

        if distToPortal < minDistance then
            minDistance = distToPortal
            closestPortal = portalPos
            closestName = name
        end
    end
    
    -- Only return portal if it saves significant distance
    if closestPortal and minDistance < directDist then
        Modules:DebugPrint("📍 Portal found:", closestName, "| Saves:", math.floor(directDist - minDistance), "studs")
        return closestPortal
    end
    
    return nil
end

function Modules.Portal:RequestEntrance(portalPos, btnState)
    if not portalPos or not Modules:ValidateReferences() then 
        return false 
    end
    
    if State.isPortalActive then
        Modules:DebugPrint("⚠️ Portal already active, skipping...")
        return false
    end
    
    State.isPortalActive = true
    local completed = false

    local success, err = Modules:SafePcall(function()
        -- Temple of Time → Great Tree
        if portalPos == Vector3.new(3028.209228515625, 2280.84619140625, -7324.2880859375) then
            local templePos = Vector3.new(28282.5703125, 14896.8505859375, 105.1042709350586)
            
            if (templePos - HRP.Position).Magnitude > 10000 then
                CommF_:InvokeServer("requestEntrance", templePos)
            end

            HRP.CFrame = CFrame.new(28609.650390625, 14896.5458984375, 105.68901062011719)
            task.wait(0.15)
            
            if (HRP.Position - Vector3.new(28609.6504, 14896.5459, 105.6890)).Magnitude <= 10 then
                CommF_:InvokeServer("RaceV4Progress", "TeleportBack")
            end
            
            completed = (HRP.Position - portalPos).Magnitude <= 5

        -- Dimension Shift (Cake Island Mirror)
        elseif portalPos == Vector3.new(-2097.3447265625, 4776.24462890625, -15013.4990234375) then
            task.wait(0.05)
            
            local map = Services.Workspace:FindFirstChild("Map")
            local cake = map and map:FindFirstChild("CakeLoaf")
            local mirror = cake and cake:FindFirstChild("BigMirror")

            if mirror and mirror:FindFirstChild("Other") and mirror.Other.Transparency == 0 then
                if mirror:FindFirstChild("Main") then
                    HRP.CFrame = mirror.Main.CFrame
                    task.wait(0.08)
                    completed = true
                end
            end

        -- Submerged Island
        elseif portalPos == Vector3.new(10213.701171875, -1733.5025634765625, 9940.189453125) then
            local submarinePos = Vector3.new(-16269.408203125, 23.979995727539062, 1371.662353515625)
            
            if (submarinePos - HRP.Position).Magnitude > 1205 then
                CommF_:InvokeServer("requestEntrance", Vector3.new(-5058.7749, 314.5155, -3155.8833))
                task.wait(0.15)
                
                HRP.CFrame = CFrame.new(-5097.1318359375, 318.50201416015625, -3178.3984375)
                task.wait(0.1)
            end

            -- Navigate to submarine worker
            local tempState = State.isPortalActive
            State.isPortalActive = false
            Modules.Tween:ToTarget(CFrame.new(submarinePos), btnState)
            
            -- Wait for arrival
            local timeout = 30
            local elapsed = 0
            while (submarinePos - HRP.Position).Magnitude > 15 and elapsed < timeout do
                task.wait(0.5)
                elapsed = elapsed + 0.5
            end
            
            State.isPortalActive = tempState
            
            if (submarinePos - HRP.Position).Magnitude <= 15 then
                local rep = Services.ReplicatedStorage
                local modules = rep:WaitForChild("Modules", 3)
                if modules then
                    local net = modules:WaitForChild("Net", 3)
                    if net then
                        local rf = net:WaitForChild("RF/SubmarineWorkerSpeak", 3)
                        if rf then
                            rf:InvokeServer("TravelToSubmergedIsland")
                            task.wait(0.2)
                        end
                    end
                end
            end
            
            completed = (portalPos - HRP.Position).Magnitude <= 5

        -- Tiki Outpost
        elseif portalPos == Vector3.new(-16799.091796875, 84.32279968261719, 291.0728454589844) then
            CommF_:InvokeServer("requestEntrance", Vector3.new(-5058.7749, 314.5155, -3155.8833))
            task.wait(0.15)
            
            HRP.CFrame = CFrame.new(-5097.1318359375, 318.50201416015625, -3178.3984375)
            task.wait(0.15)
            
            completed = (portalPos - HRP.Position).Magnitude <= 5

        -- Standard portal
        else
            if CommF_ then
                CommF_:InvokeServer("requestEntrance", portalPos)
                task.wait(0.08)
                completed = true
            end
        end
    end)

    State.isPortalActive = false

    if not success then
        Modules:DebugPrint("❌ Portal entrance error:", err)
        return false
    end

    return completed
end

Modules.Tween = {}
function Modules.Tween:ToTarget(targetCFrame, btnState, speedOverride)
    if not Modules:ValidateReferences() then return false end
    if not targetCFrame then return false end
    if not State.hoverBlock or not State.hoverBlock.Parent then return false end

    -- Prevent concurrent player tweens
    if State.isTweeningBoat then
        Modules:DebugPrint("🚫 Player tween blocked: boat tween active")
        return false
    end

    if getgenv().TweenBtnFix and State.shouldTween and not btnState then 
        return false 
    end
    
    local dist = (targetCFrame.Position - HRP.Position).Magnitude
    
    -- Instant snap for close distances
    if dist <= Config.SnapDistance then
        Modules:SafePcall(function()
            State.hoverBlock.CFrame = targetCFrame
            if dist <= 10 then
                HRP.CFrame = targetCFrame
            end
        end)
        return true
    end

    -- Cancel existing tween if button pressed
    if btnState then
        if State.currentTween and State.currentTween.PlaybackState == Enum.PlaybackState.Playing then
            State.currentTween:Cancel()
            State.currentTween = nil
        end
        
        getgenv().TweenBtnFix = true
        State.shouldTween = true
    end

    State.isTweeningPlayer = true
    State.tweenCount = State.tweenCount + 1

    -- Calculate tween parameters
    local tweenSpeed = speedOverride or Modules:GetTweenSpeed()
    local tweenDuration = dist / tweenSpeed

    -- Create tween
    local tweenInfo = TweenInfo.new(
        tweenDuration, 
        Enum.EasingStyle.Linear,
        Enum.EasingDirection.InOut,
        0,
        false,
        0
    )
    
    local tween = Services.TweenService:Create(
        State.hoverBlock, 
        tweenInfo, 
        {CFrame = targetCFrame}
    )
    
    State.currentTween = tween
 
    -- Handle sitting characters (adjust Y position only)
    if Humanoid.Sit == true then
        Modules:SafePcall(function()
            State.hoverBlock.CFrame = CFrame.new(
                State.hoverBlock.Position.X, 
                targetCFrame.Position.Y, 
                State.hoverBlock.Position.Z
            )
        end)
    end
    
    Modules:DebugPrint("🎯 Tween started | Distance:", math.floor(dist), "| Duration:", string.format("%.1f", tweenDuration) .. "s")
    
    tween:Play()

    -- Monitor tween with enhanced checks
    task.spawn(function()
        while tween and tween.PlaybackState == Enum.PlaybackState.Playing do
            -- Check for cancellation
            if not State.shouldTween then
                tween:Cancel()
                State.isTweeningPlayer = false

                if btnState then
                    getgenv().TweenBtnFix = false
                    State.shouldTween = false
                end
                
                Modules:DebugPrint("🛑 Tween cancelled by user")
                break
            end
            
            -- Validate references mid-tween
            if not Modules:ValidateReferences() or not State.hoverBlock then
                tween:Cancel()
                State.isTweeningPlayer = false
                Modules:DebugPrint("⚠️ Tween cancelled: invalid references")
                break
            end
            
            task.wait(Config.TweenUpdateRate)
        end
    end)

    -- Handle completion
    if btnState then
        tween.Completed:Connect(function(playbackState)
            if playbackState == Enum.PlaybackState.Completed then
                -- Final snap to target if close
                if Modules:ValidateReferences() then
                    if (targetCFrame.Position - HRP.Position).Magnitude <= Config.SnapDistance then
                        Modules:SafePcall(function()
                            HRP.CFrame = targetCFrame
                        end)
                    end
                end
                
                Modules:DebugPrint("✅ Tween completed successfully")
            elseif playbackState == Enum.PlaybackState.Cancelled then
                Modules:DebugPrint("⚠️ Tween was cancelled")
            end

            getgenv().TweenBtnFix = false
            State.shouldTween = false
            State.isTweeningPlayer = false
        end)
    else
        tween.Completed:Connect(function()
            State.isTweeningPlayer = false
        end)
    end
    
    return true
end

function Modules.Tween:WithPortal(targetCFrame, btnState, speedOverride)
    if not targetCFrame or not Modules:ValidateReferences() then 
        return false 
    end

    local portalPos = Modules.Portal:GetClosest(targetCFrame)

    if portalPos then
        Modules:DebugPrint("🌀 Attempting portal shortcut...")
        
        local retries = 0
        local success = false
        
        while retries < Config.MaxPortalRetries and not success do
            success = Modules.Portal:RequestEntrance(portalPos, btnState)
            
            if not success then
                retries = retries + 1
                if retries < Config.MaxPortalRetries then
                    Modules:DebugPrint("⚠️ Retry", retries, "of", Config.MaxPortalRetries)
                    task.wait(Config.PortalRetryDelay)
                end
            end
        end

        if success then
            task.wait(Config.PortalRetryDelay)
            return self:ToTarget(targetCFrame, btnState, speedOverride)
        else
            Modules:DebugPrint("⚠️ Portal failed after", Config.MaxPortalRetries, "attempts, using direct path")
            return self:ToTarget(targetCFrame, btnState, speedOverride)
        end
    else
        return self:ToTarget(targetCFrame, btnState, speedOverride)
    end
end

function Modules.Tween:Boat(targetCFrame)
    if not Modules:ValidateReferences() then return false end
    if not targetCFrame then return false end
    
    -- Prevent concurrent tweens
    if State.isTweeningPlayer then
        Modules:DebugPrint("🚫 Boat tween blocked: player tween active")
        return false
    end

    local myShip = Modules.CheckMyBoat()
    if not myShip then 
        Modules:DebugPrint("⚠️ No boat found")
        return false
    end
    
    local vehicleSeat = myShip:FindFirstChild("VehicleSeat")
    if not vehicleSeat then 
        Modules:DebugPrint("⚠️ Boat has no VehicleSeat")
        return false
    end
    
    State.isTweeningBoat = true
    
    local dist = (targetCFrame.Position - vehicleSeat.Position).Magnitude
    
    -- Snap if close
    if dist <= Config.BoatSnapDistance then
        Modules:SafePcall(function()
            vehicleSeat.CFrame = targetCFrame
        end)
        State.isTweeningBoat = false
        return true
    end
    
    local boatSpeed = Modules:GetBoatSpeed()
    local duration = dist / boatSpeed

    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
    local tween = Services.TweenService:Create(vehicleSeat, tweenInfo, {CFrame = targetCFrame})
    State.boatTween = tween

    Modules:DebugPrint("⛵ Boat tween started | Distance:", math.floor(dist))
    
    tween:Play()

    -- Monitor for stop signal or completion
    task.spawn(function()
        while tween.PlaybackState == Enum.PlaybackState.Playing do
            if getgenv().StopBoatTween then
                tween:Cancel()
                State.isTweeningBoat = false
                Modules:DebugPrint("🛑 Boat tween stopped")
                break
            end
            task.wait(Config.TweenUpdateRate)
        end
    end)
    
    tween.Completed:Connect(function(playbackState)
        State.isTweeningBoat = false
        if playbackState == Enum.PlaybackState.Completed then
            Modules:DebugPrint("✅ Boat tween completed")
        end
    end)
    
    return true
end

function Modules.Tween:StopAll(mode)
    mode = mode or "all"
    
    Modules:DebugPrint("🛑 Stopping tweens | Mode:", mode)
    
    if mode == "player" or mode == "all" then
        getgenv().TweenBtnFix = false
        State.shouldTween = false
        State.isTweeningPlayer = false
        
        if State.currentTween then
            Modules:SafePcall(function()
                if State.currentTween.PlaybackState == Enum.PlaybackState.Playing then
                    State.currentTween:Cancel()
                end
                State.currentTween = nil
            end)
        end
        
        if Modules:ValidateReferences() then
            if HRP:FindFirstChild("VinreachHoverClip") then
                Modules:SafePcall(function()
                    HRP:FindFirstChild("VinreachHoverClip"):Destroy()
                end)
            end
        end

        if State.hoverBlock and State.hoverBlock.Parent and HRP then
            Modules:SafePcall(function()
                State.hoverBlock.CFrame = HRP.CFrame
            end)
        end
    end

    if mode == "boat" or mode == "all" then
        getgenv().StopBoatTween = true
        State.isTweeningBoat = false
        
        if State.boatTween then
            Modules:SafePcall(function()
                if State.boatTween.PlaybackState == Enum.PlaybackState.Playing then
                    State.boatTween:Cancel()
                end
                State.boatTween = nil
            end)
        end
    end

    -- Reset flags after brief delay
    task.delay(0.15, function()
        if mode == "all" or mode == "boat" then
            getgenv().StopBoatTween = false
        end
    end)
    
    return true
end

local function InitializeReferences()
    local success = Modules:SafePcall(function()
        Character = Player.Character or Player.CharacterAdded:Wait()
        HRP = Character:WaitForChild("HumanoidRootPart", 10)
        Humanoid = Character:WaitForChild("Humanoid", 10)
    end)

    if not success or not HRP or not Humanoid then
        warn("❌ Failed to initialize character references!")
        return false
    end
    
    -- Validate health
    if Humanoid.Health <= 0 then
        warn("⚠️ Character is dead, waiting for respawn...")
        return false
    end
    
    return true
end

function Modules:Initialize()
    if State.isInitialized then
        Modules:DebugPrint("⚠️ Already initialized, reinitializing...")
    end

    if not InitializeReferences() then
        warn("❌ Critical initialization failure!")
        return false
    end

    Modules:DebugPrint("✅ Character references initialized")
    Modules:DebugPrint("📍 Player:", Player.Name)
    Modules:DebugPrint("🌊 Sea:", Sea3 and "3" or Sea2 and "2" or Sea1 and "1" or "Unknown")
    
    -- Initialize hover block system
    local hoverBlock = Modules.HoverBlock:Initialize()
    if not hoverBlock then
        warn("❌ Failed to initialize hover block!")
        return false
    end
    
    Modules:DebugPrint("✅ Hover block system initialized")
    
    State.isInitialized = true
    State.errorCount = 0
    _G.ModulesInitialized = true
    
    Modules:DebugPrint("🚀 Tween Library v" .. Modules.Version .. " fully initialized!")
    return true
end

Player.CharacterAdded:Connect(function(newChar)
    Modules:DebugPrint("🔄 Character respawned, reinitializing...")
    
    -- Reset states
    State.isInitialized = false
    State.isTweeningPlayer = false
    State.isTweeningBoat = false
    State.shouldTween = false
    getgenv().TweenBtnFix = false
    
    -- Cancel any active tweens
    Modules.Tween:StopAll("all")
    
    Character = newChar
    task.wait(0.5)

    local success = Modules:Initialize()
    if success then
        Modules:DebugPrint("✅ Reinitialization successful")
    else
        warn("⚠️ Reinitialization failed, retrying in 2s...")
        task.wait(2)
        Modules:Initialize()
    end
end)

function Modules:UpdateConfig(newConfig)
    if not newConfig or type(newConfig) ~= "table" then 
        warn("⚠️ Invalid config provided")
        return false
    end

    local updated = 0
    for key, value in pairs(newConfig) do
        if Config[key] ~= nil then
            -- Handle nested tables
            if type(Config[key]) == "table" and type(value) == "table" then
                for k, v in pairs(value) do
                    Config[key][k] = v
                    updated = updated + 1
                end
            else
                Config[key] = value
                updated = updated + 1
            end
            Modules:DebugPrint("⚙️ Config updated:", key, "=", tostring(value))
        else
            Modules:DebugPrint("⚠️ Unknown config key:", key)
        end
    end
    
    Modules:DebugPrint("✅ Updated", updated, "config values")
    return true
end

function Modules:GetConfig(key)
    if key then
        return Config[key]
    else
        -- Return copy of entire config
        local copy = {}
        for k, v in pairs(Config) do
            copy[k] = v
        end
        return copy
    end
end

function Modules:TweenToTarget(input, btn, speedOverride)
    if not State.isInitialized then
        warn("⚠️ Module not initialized!")
        return false
    end
    return Modules.Tween:WithPortal(input, btn, speedOverride) 
end

function Modules:TweenByBoatToTarget(input)
    if not State.isInitialized then
        warn("⚠️ Module not initialized!")
        return false
    end
    return Modules.Tween:Boat(input) 
end

function Modules:StopTween(mode)
    return Modules.Tween:StopAll(mode)
end

function Modules:GetStatus()
    return {
        initialized = State.isInitialized,
        version = Modules.Version,
        tweenCount = State.tweenCount,
        errorCount = State.errorCount,
        isTweeningPlayer = State.isTweeningPlayer,
        isTweeningBoat = State.isTweeningBoat,
        shouldTween = State.shouldTween,
        onFarm = getgenv().OnFarm,
        tweenBtnFix = getgenv().TweenBtnFix,
        hoverBlockExists = State.hoverBlock and State.hoverBlock.Parent ~= nil,
        characterAlive = Modules:IsAlive(),
        currentSea = Sea3 and 3 or Sea2 and 2 or Sea1 and 1 or 0
    }
end

function Modules:GetBtnTweenStatus()
    return getgenv().TweenBtnFix == true
end

function Modules:SetShouldTween(state)
    if type(state) ~= "boolean" then
        state = false
    end
    
    State.shouldTween = state
    Modules:DebugPrint("🎛️ shouldTween set to:", state)
    return state
end

function Modules:GetTweenState()
    return {
        player = State.isTweeningPlayer,
        boat = State.isTweeningBoat,
        should = State.shouldTween
    }
end

function Modules:EnableDebug(enable)
    Config.DebugInfo = enable == true
    Modules:DebugPrint("🐛 Debug mode:", Config.DebugInfo and "ENABLED" or "DISABLED")
end

function Modules:EnablePerformanceMode(enable)
    Config.PerformanceMode = enable == true
    
    if Config.PerformanceMode then
        Config.TweenUpdateRate = 0.2
        Config.EnableSafetyChecks = false
        Modules:DebugPrint("⚡ Performance mode ENABLED")
    else
        Config.TweenUpdateRate = 0.1
        Config.EnableSafetyChecks = true
        Modules:DebugPrint("🔒 Performance mode DISABLED (safety enabled)")
    end
end

_G.Tween = function(input, btnState)
    return Modules:TweenToTarget(input, btnState)
end

_G.toTarget = function(target, btnState)
    return Modules.Tween:ToTarget(target, btnState)
end

_G.Tween2 = function(input)
    return Modules:TweenByBoatToTarget(input)
end

_G.stopTweenAll = function()
    return Modules:StopTween("all")
end

_G.getPortal = function(check)
    return Modules.Portal:GetClosest(check)
end

_G.requestEntrance = function(checkPos, btnState)
    return Modules.Portal:RequestEntrance(checkPos, btnState)
end

_G.checkMyBoat = function()
    return Modules.CheckMyBoat()
end

local initSuccess = Modules:Initialize()
if not initSuccess then
    warn("⚠️ Initial startup failed, retrying in 3 seconds...")
    task.wait(3)
    initSuccess = Modules:Initialize()
    
    if not initSuccess then
        warn("❌ Critical failure! Module may not work correctly.")
    end
end

return Modules