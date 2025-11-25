local Modules = {}
Modules.__index = Modules
Modules.Version = "1.5"

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
    
    -- Tween Speeds (Optimized)
    DefaultTweenSpeed = 350,
    DefaultBoatSpeed = 180,
    FastTweenSpeed = 500,
    SlowTweenSpeed = 250,
    
    -- Distance Thresholds (Improved)
    SnapDistance = 50,
    MaxTweenDistance = 250,
    PortalMinDistance = 800,
    
    -- Safety & Validation
    EnableSafetyChecks = true,
    AutoRecoverHoverBlock = true,
    EnableNoclip = true,
    EnableSmoothing = true,
    
    -- Timing (Ultra-Smooth)
    TweenUpdateRate = 0.08,
    PortalRetryDelay = 0.12,
    MaxPortalRetries = 3,
    SmoothingFactor = 0.15,
    
    -- Boat Settings
    BoatSnapDistance = 60,
    EnableBoatCollision = false,
    BoatSmoothDocking = true,
    
    -- Advanced Features
    PredictivePositioning = true,
    AdaptiveSpeed = true,
    AntiStuck = true,
    StuckThreshold = 3,
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
    successCount = 0,
    portalUseCount = 0,
    
    -- Advanced Tracking
    lastPosition = nil,
    lastMoveTime = 0,
    stuckCounter = 0,
    lastNoclipState = nil,
    tweenStartTime = 0,
    avgTweenSpeed = 0,
}

local Remotes = Services.ReplicatedStorage:WaitForChild("Remotes", 5)
local CommF_ = Remotes and Remotes:WaitForChild("CommF_", 5)

if not CommF_ then
    warn("⚠️ CommF_ not found! Portal features may not work.")
end

function Modules:DebugPrint(...)
    if Config.DebugInfo then
        local args = {...}
        local formatted = {}
        for i, v in ipairs(args) do
            formatted[i] = tostring(v)
        end
        print(string.format("[%.3f] [TweenLib v%s]", tick(), Modules.Version), table.unpack(formatted))
    end
end

function Modules:SafePcall(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        State.errorCount = State.errorCount + 1
        Modules:DebugPrint("❌ Error #" .. State.errorCount .. ":", result)
        
        -- Auto-recovery for critical errors
        if State.errorCount > 15 and Config.EnableSafetyChecks then
            Modules:DebugPrint("⚠️ Too many errors, attempting recovery...")
            task.spawn(function()
                Modules:RecoverFromError()
            end)
        end
    else
        State.successCount = State.successCount + 1
    end
    return success, result
end

function Modules:RecoverFromError()
    Modules:DebugPrint("🔄 Initiating error recovery...")
    
    State.errorCount = 0
    self:StopTween("all")
    
    -- Reset stuck counter
    State.stuckCounter = 0
    
    if Config.AutoRecoverHoverBlock and State.hoverBlock then
        task.wait(0.5)
        Modules.HoverBlock:Initialize()
    end
    
    Modules:DebugPrint("✅ Recovery complete")
end

function Modules:IsAlive(char)
    char = char or Character
    if not char or not char.Parent then return false end
    local h = char:FindFirstChild("Humanoid")
    return h and h.Health > 0 and h.Parent ~= nil
end

function Modules:ValidateReferences()
    if not Character or not Character.Parent then return false end
    if not HRP or not HRP.Parent then return false end
    if not Humanoid or not Humanoid.Parent then return false end
    if Humanoid.Health <= 0 then return false end
    return true
end

function Modules:CheckStuck()
    if not Config.AntiStuck or not HRP then return false end
    
    local currentPos = HRP.Position
    local currentTime = tick()
    
    if State.lastPosition then
        local distance = (currentPos - State.lastPosition).Magnitude
        local timeDiff = currentTime - State.lastMoveTime
        
        -- If barely moved in the last second while tweening
        if timeDiff > 1 and distance < 2 and State.shouldTween then
            State.stuckCounter = State.stuckCounter + 1
            
            if State.stuckCounter >= Config.StuckThreshold then
                Modules:DebugPrint("⚠️ Stuck detected! Counter:", State.stuckCounter)
                return true
            end
        else
            State.stuckCounter = 0
        end
    end
    
    State.lastPosition = currentPos
    State.lastMoveTime = currentTime
    
    return false
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
    
    -- Adaptive speed based on distance (NEW in v1.5)
    if Config.AdaptiveSpeed and speedType == "default" then
        local dist = State.lastPosition and HRP and 
                     (State.hoverBlock and State.hoverBlock.Position) and
                     (HRP.Position - State.hoverBlock.Position).Magnitude or 0
        
        if dist > 5000 then
            return Config.FastTweenSpeed
        elseif dist < 1000 then
            return Config.SlowTweenSpeed
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
        
        -- Sitting in someone else's boat (more lenient range)
        if Humanoid and Humanoid.Sit then
            local vehicleSeat = boat:FindFirstChild("VehicleSeat")
            if vehicleSeat and (HRP.Position - vehicleSeat.Position).Magnitude <= 8 then
                return boat
            end
        end
    end
    
    return nil
end

function Modules.CheckInMyBoat()
    if not Modules:ValidateReferences() then return false end

    local myBoat = Modules.CheckMyBoat()
    if not myBoat then return false end

    local vehicleSeat = myBoat:FindFirstChild("VehicleSeat")
    if not vehicleSeat then return false end
    
    if Humanoid.Sit == true and (HRP.Position - vehicleSeat.Position).Magnitude <= 5 then
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
    hoverBlock.Material = Enum.Material.ForceField
    hoverBlock.Massless = true
    
    -- Enhanced identification
    local tag = Instance.new("StringValue")
    tag.Name = "ModuleVersion"
    tag.Value = Modules.Version
    tag.Parent = hoverBlock
    
    Modules:SafePcall(function()
        hoverBlock.Parent = Services.Workspace
    end)

    State.hoverBlock = hoverBlock
    Modules:DebugPrint("✨ Hover block created")
    return hoverBlock
end

function Modules.HoverBlock:Validate()
    if not State.hoverBlock or not State.hoverBlock.Parent then
        return false
    end
    
    if State.hoverBlock.Parent ~= Services.Workspace then
        return false
    end
    
    return true
end

function Modules.HoverBlock:SmoothFollow()
    if not Config.EnableSmoothing or not self:Validate() or not HRP then return end
    
    -- Smooth interpolation for better visual experience
    local current = State.hoverBlock.CFrame
    local target = HRP.CFrame
    local alpha = Config.SmoothingFactor
    
    Modules:SafePcall(function()
        State.hoverBlock.CFrame = current:Lerp(target, alpha)
    end)
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

    -- Main update loop with enhanced smoothing
    task.spawn(function()
        repeat task.wait(0.1) until Character and Character:FindFirstChild("HumanoidRootPart")
        
        Modules:DebugPrint("✅ Hover block update loop started")
        
        -- Initial positioning
        if self:Validate() and HRP then
            State.hoverBlock.CFrame = HRP.CFrame
        end

        local updateCounter = 0
        
        while task.wait(Config.TweenUpdateRate) do
            updateCounter = updateCounter + 1
            
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
                
                -- Smooth position sync with boat detection
                if distance <= Config.MaxTweenDistance then
                    Modules:SafePcall(function()
                        if Modules.CheckInMyBoat() then
                            -- In boat, keep hover block at player
                            State.hoverBlock.CFrame = HRP.CFrame
                        else
                            -- Normal tween, move player to hover block
                            if Config.EnableSmoothing and distance > 10 then
                                -- Smooth approach for better visuals
                                local alpha = math.clamp(Config.SmoothingFactor * 2, 0, 1)
                                HRP.CFrame = HRP.CFrame:Lerp(State.hoverBlock.CFrame, alpha)
                            else
                                HRP.CFrame = State.hoverBlock.CFrame
                            end
                        end
                    end)
                else
                    Modules:SafePcall(function()
                        State.hoverBlock.CFrame = HRP.CFrame
                    end)
                end
            end

            -- Enhanced noclip handling (less frequent updates)
            if Config.EnableNoclip and updateCounter % 3 == 0 then
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
            
            -- Anti-stuck check (every 10 updates)
            if Config.AntiStuck and updateCounter % 10 == 0 then
                if Modules:CheckStuck() then
                    Modules:DebugPrint("🔧 Attempting unstuck procedure...")
                    
                    -- Try to unstuck by repositioning
                    if State.hoverBlock then
                        State.hoverBlock.CFrame = State.hoverBlock.CFrame + Vector3.new(0, 5, 0)
                        task.wait(0.1)
                    end
                    
                    State.stuckCounter = 0
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

    -- Don't use portal for close distances
    if directDist < Config.PortalMinDistance then
        return nil
    end

    for name, portalPos in pairs(seaTable) do
        local distToPortal = (portalPos - targetPos).Magnitude
        
        -- Improved selection: consider both distance to portal and from portal to target
        local totalPathDist = (portalPos - hrpPos).Magnitude + distToPortal
        
        if distToPortal < minDistance and totalPathDist < directDist * 0.85 then
            minDistance = distToPortal
            closestPortal = portalPos
            closestName = name
        end
    end
    
    -- Only return portal if it saves significant distance (15%+)
    if closestPortal then
        local savings = math.floor(directDist - minDistance)
        Modules:DebugPrint("🌀 Portal found:", closestName, "| Saves:", savings, "studs")
        return closestPortal
    end
    
    return nil
end

function Modules.Portal:RequestEntrance(portalPos, btnState)
    if not portalPos or not Modules:ValidateReferences() then 
        return false 
    end
    
    if not CommF_ then
        Modules:DebugPrint("⚠️ CommF_ not available")
        return false
    end
    
    if State.isPortalActive then
        Modules:DebugPrint("⚠️ Portal already active, skipping...")
        return false
    end
    
    State.isPortalActive = true
    State.portalUseCount = State.portalUseCount + 1
    local completed = false

    local success, err = Modules:SafePcall(function()
        -- Temple of Time → Great Tree
        if portalPos == Vector3.new(3028.209228515625, 2280.84619140625, -7324.2880859375) then
            local templePos = Vector3.new(28282.5703125, 14896.8505859375, 105.1042709350586)
            
            if (templePos - HRP.Position).Magnitude > 10000 then
                CommF_:InvokeServer("requestEntrance", templePos)
                task.wait(0.1)
            end

            HRP.CFrame = CFrame.new(28609.650390625, 14896.5458984375, 105.68901062011719)
            task.wait(0.15)
            
            if (HRP.Position - Vector3.new(28609.6504, 14896.5459, 105.6890)).Magnitude <= 15 then
                CommF_:InvokeServer("RaceV4Progress", "TeleportBack")
                task.wait(0.12)
            end
            
            completed = (HRP.Position - portalPos).Magnitude <= 100

        -- Dimension Shift (Cake Island Mirror)
        elseif portalPos == Vector3.new(-2097.3447265625, 4776.24462890625, -15013.4990234375) then
            task.wait(0.05)
            
            local map = Services.Workspace:FindFirstChild("Map")
            local cake = map and map:FindFirstChild("CakeLoaf")
            local mirror = cake and cake:FindFirstChild("BigMirror")

            if mirror and mirror:FindFirstChild("Other") and mirror.Other.Transparency == 0 then
                if mirror:FindFirstChild("Main") then
                    HRP.CFrame = mirror.Main.CFrame
                    task.wait(0.1)
                    completed = true
                end
            end

        -- Submerged Island (Improved)
        elseif portalPos == Vector3.new(10213.701171875, -1733.5025634765625, 9940.189453125) then
            local submarinePos = Vector3.new(-16269.408203125, 23.979995727539062, 1371.662353515625)
            
            if (submarinePos - HRP.Position).Magnitude > 1205 then
                CommF_:InvokeServer("requestEntrance", Vector3.new(-5058.7749, 314.5155, -3155.8833))
                task.wait(0.15)
                
                HRP.CFrame = CFrame.new(-5097.1318359375, 318.50201416015625, -3178.3984375)
                task.wait(0.12)
            end

            -- Navigate to submarine worker
            local tempState = State.isPortalActive
            State.isPortalActive = false
            Modules.Tween:ToTarget(CFrame.new(submarinePos), btnState)
            
            -- Wait for arrival with timeout
            local timeout = 35
            local elapsed = 0
            while (submarinePos - HRP.Position).Magnitude > 20 and elapsed < timeout do
                task.wait(0.3)
                elapsed = elapsed + 0.3
            end
            
            State.isPortalActive = tempState
            
            if (submarinePos - HRP.Position).Magnitude <= 20 then
                local rep = Services.ReplicatedStorage
                local modules = rep:FindFirstChild("Modules")
                if modules then
                    local net = modules:FindFirstChild("Net")
                    if net then
                        local rf = net:FindFirstChild("RF/SubmarineWorkerSpeak")
                        if rf then
                            rf:InvokeServer("TravelToSubmergedIsland")
                            task.wait(0.25)
                        end
                    end
                end
            end
            
            task.wait(0.1)
            completed = (portalPos - HRP.Position).Magnitude <= 200

        -- Tiki Outpost
        elseif portalPos == Vector3.new(-16799.091796875, 84.32279968261719, 291.0728454589844) then
            CommF_:InvokeServer("requestEntrance", Vector3.new(-5058.7749, 314.5155, -3155.8833))
            task.wait(0.15)
            
            HRP.CFrame = CFrame.new(-5097.1318359375, 318.50201416015625, -3178.3984375)
            task.wait(0.15)
            
            completed = (portalPos - HRP.Position).Magnitude <= 100

        -- Standard portal
        else
            CommF_:InvokeServer("requestEntrance", portalPos)
            task.wait(0.1)
            completed = true
        end
    end)

    State.isPortalActive = false

    if not success then
        Modules:DebugPrint("❌ Portal entrance error:", err)
        return false
    end

    if completed then
        Modules:DebugPrint("✅ Portal entrance successful")
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
            if Config.EnableSmoothing and dist > 5 then
                -- Smooth final approach
                local steps = 3
                for i = 1, steps do
                    local alpha = i / steps
                    State.hoverBlock.CFrame = State.hoverBlock.CFrame:Lerp(targetCFrame, alpha)
                    task.wait(0.03)
                end
            else
                State.hoverBlock.CFrame = targetCFrame
            end
            
            if dist <= 15 then
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
    State.tweenStartTime = tick()
    State.stuckCounter = 0

    -- Calculate tween parameters with adaptive speed
    local tweenSpeed = speedOverride or Modules:GetTweenSpeed()
    local tweenDuration = dist / tweenSpeed

    -- Enhanced easing for smoother experience
    local easingStyle = dist > 3000 and Enum.EasingStyle.Quad or Enum.EasingStyle.Linear
    
    -- Create tween
    local tweenInfo = TweenInfo.new(
        tweenDuration, 
        easingStyle,
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
 
    -- Handle sitting characters (improved)
    if Humanoid.Sit == true and not Modules.CheckInMyBoat() then
        Modules:SafePcall(function()
            State.hoverBlock.CFrame = CFrame.new(
                State.hoverBlock.Position.X, 
                targetCFrame.Position.Y, 
                State.hoverBlock.Position.Z
            )
        end)
    end
    
    Modules:DebugPrint("🎯 Tween started | Dist:", math.floor(dist), "| Speed:", tweenSpeed, "| Duration:", string.format("%.1f", tweenDuration) .. "s")
    
    tween:Play()

    -- Monitor tween with enhanced checks
    task.spawn(function()
        local checkInterval = Config.TweenUpdateRate
        local lastDist = dist
        
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
            
            -- Progress tracking (NEW in v1.5)
            local currentDist = (targetCFrame.Position - HRP.Position).Magnitude
            if currentDist < lastDist then
                lastDist = currentDist
            end
            
            task.wait(checkInterval)
        end
    end)

    -- Handle completion
    if btnState then
        tween.Completed:Connect(function(playbackState)
            local duration = tick() - State.tweenStartTime
            
            if playbackState == Enum.PlaybackState.Completed then
                -- Calculate average speed for analytics
                State.avgTweenSpeed = dist / duration
                
                -- Final snap to target if close
                if Modules:ValidateReferences() then
                    local finalDist = (targetCFrame.Position - HRP.Position).Magnitude
                    
                    if finalDist <= Config.SnapDistance then
                        Modules:SafePcall(function()
                            HRP.CFrame = targetCFrame
                        end)
                    end
                end
                
                Modules:DebugPrint("✅ Tween completed | Time:", string.format("%.2f", duration) .. "s")
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
    
    -- Smooth docking for close distances (NEW in v1.5)
    if dist <= Config.BoatSnapDistance then
        if Config.BoatSmoothDocking and dist > 15 then
            Modules:DebugPrint("🚢 Smooth docking initiated...")
            
            -- Gradual approach for better docking
            local steps = 4
            for i = 1, steps do
                if not Modules:ValidateReferences() then break end
                
                local alpha = i / steps
                local intermediateCFrame = vehicleSeat.CFrame:Lerp(targetCFrame, alpha)
                
                Modules:SafePcall(function()
                    vehicleSeat.CFrame = intermediateCFrame
                end)
                
                task.wait(0.1)
            end
        else
            Modules:SafePcall(function()
                vehicleSeat.CFrame = targetCFrame
            end)
        end
        
        State.isTweeningBoat = false
        Modules:DebugPrint("✅ Boat docked")
        return true
    end
    
    local boatSpeed = Modules:GetBoatSpeed()
    local duration = dist / boatSpeed

    -- Smoother easing for boats
    local tweenInfo = TweenInfo.new(
        duration, 
        Enum.EasingStyle.Sine,
        Enum.EasingDirection.InOut
    )
    
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
            
            -- Validate boat still exists
            if not myShip or not myShip.Parent or not vehicleSeat.Parent then
                tween:Cancel()
                State.isTweeningBoat = false
                Modules:DebugPrint("⚠️ Boat tween cancelled: boat lost")
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
        State.stuckCounter = 0
        
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
    
    -- Reset all counters
    State.isInitialized = true
    State.errorCount = 0
    State.successCount = 0
    State.tweenCount = 0
    State.portalUseCount = 0
    State.stuckCounter = 0
    
    _G.ModulesInitialized = true
    _G.ModulesVersion = Modules.Version
    
    Modules:DebugPrint("🚀 Tween Library v" .. Modules.Version .. " fully initialized!")
    return true
end

Player.CharacterAdded:Connect(function(newChar)
    Modules:DebugPrint("🔄 Character respawned, reinitializing...")
    
    -- Reset all states
    State.isInitialized = false
    State.isTweeningPlayer = false
    State.isTweeningBoat = false
    State.shouldTween = false
    State.stuckCounter = 0
    State.lastPosition = nil
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
        -- Core Info
        initialized = State.isInitialized,
        version = Modules.Version,
        
        -- Statistics
        tweenCount = State.tweenCount,
        errorCount = State.errorCount,
        successCount = State.successCount,
        portalUseCount = State.portalUseCount,
        avgTweenSpeed = State.avgTweenSpeed,
        
        -- States
        isTweeningPlayer = State.isTweeningPlayer,
        isTweeningBoat = State.isTweeningBoat,
        shouldTween = State.shouldTween,
        onFarm = getgenv().OnFarm,
        tweenBtnFix = getgenv().TweenBtnFix,
        
        -- Validation
        hoverBlockExists = State.hoverBlock and State.hoverBlock.Parent ~= nil,
        characterAlive = Modules:IsAlive(),
        currentSea = Sea3 and 3 or Sea2 and 2 or Sea1 and 1 or 0,
        
        -- NEW in v1.5
        stuckCounter = State.stuckCounter,
        inBoat = Modules.CheckInMyBoat(),
        uptime = State.isInitialized and (tick() - (State.tweenStartTime or tick())) or 0
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
        should = State.shouldTween,
        portal = State.isPortalActive
    }
end

function Modules:EnableDebug(enable)
    Config.DebugInfo = enable == true
    Modules:DebugPrint("🐛 Debug mode:", Config.DebugInfo and "ENABLED" or "DISABLED")
    print("🐛 Debug mode:", Config.DebugInfo and "ENABLED" or "DISABLED")
end

function Modules:EnablePerformanceMode(enable)
    Config.PerformanceMode = enable == true
    
    if Config.PerformanceMode then
        Config.TweenUpdateRate = 0.15
        Config.EnableSafetyChecks = false
        Config.EnableSmoothing = false
        Modules:DebugPrint("⚡ Performance mode ENABLED")
    else
        Config.TweenUpdateRate = 0.08
        Config.EnableSafetyChecks = true
        Config.EnableSmoothing = true
        Modules:DebugPrint("🔒 Performance mode DISABLED (safety enabled)")
    end
end

function Modules:ResetStatistics()
    State.tweenCount = 0
    State.errorCount = 0
    State.successCount = 0
    State.portalUseCount = 0
    State.stuckCounter = 0
    Modules:DebugPrint("📊 Statistics reset")
end

function Modules:GetStatistics()
    return {
        totalTweens = State.tweenCount,
        totalErrors = State.errorCount,
        totalSuccess = State.successCount,
        portalsUsed = State.portalUseCount,
        successRate = State.tweenCount > 0 and 
                     string.format("%.1f%%", (State.successCount / State.tweenCount) * 100) or "N/A",
        avgSpeed = State.avgTweenSpeed > 0 and 
                  string.format("%.1f studs/s", State.avgTweenSpeed) or "N/A"
    }
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

_G.checkInMyBoat = function()
    return Modules.CheckInMyBoat()
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