local Modules = {}
Modules.__index = Modules
Modules.Version = "1.6.1"

-- Service caching
local Services = {
    Players = game:GetService("Players"),
    Workspace = game:GetService("Workspace"),
    RunService = game:GetService("RunService"),
    TweenService = game:GetService("TweenService"),
    ReplicatedStorage = game:GetService("ReplicatedStorage")
}

-- Configuration
local Config = {
    Tween = {
        defaultTweenSpeed = 300,
        defaultBoatTweenSpeed = 150
    }
}

-- Local references
local Player = Services.Players.LocalPlayer
local Character, HRP, Humanoid

-- Game detection
local placeId = game.PlaceId
local Sea1 = placeId == 2753915549
local Sea2 = placeId == 4442272183
local Sea3 = placeId == 7449423635

if not (Sea1 or Sea2 or Sea3) then 
    warn("This is not Blox Fruits! Some features may not work.") 
end

-- State management
local State = {
    currentTween = nil,
    isInitialized = false,
    btnStateTween = false,
    isTweening = false
}

-- Remote setup with proper error handling
local Remotes = Services.ReplicatedStorage:WaitForChild("Remotes", 5)
local CommF_ = Remotes and Remotes:FindFirstChild("CommF_")

if not CommF_ then 
    warn("CommF_ not found! Portal features may not work.") 
end

-- Utility Functions
function Modules:SafePcall(func, ...)
    local success, result = pcall(func, ...)
    return success, result
end

function Modules:IsAlive(char)
    char = char or Character
    if not char or not char.Parent then return false end
    
    local h = char:FindFirstChild("Humanoid")
    return h and h.Health > 0 and h.Parent ~= nil
end

function Modules:ValidateReferences()
    return Character and Character.Parent
        and HRP and HRP.Parent
        and Humanoid and Humanoid.Parent
        and Humanoid.Health > 0
end

function Modules:GetTweenSpeed()
    return Config.Tween.defaultTweenSpeed
end

function Modules:GetBoatSpeed()
    return Config.Tween.defaultBoatTweenSpeed
end

-- Boat detection
function Modules.CheckMyBoat()
    if not Modules:ValidateReferences() then return nil end

    local boats = Services.Workspace:FindFirstChild("Boats")
    if not boats then return nil end

    for _, boat in ipairs(boats:GetChildren()) do
        local owner = boat:FindFirstChild("Owner")
        if not owner then continue end

        -- Check if player owns the boat
        if tostring(owner.Value) == Player.Name then
            return boat
        end

        -- Check if sitting in someone else's boat
        if Humanoid.Sit then
            local vehicleSeat = boat:FindFirstChild("VehicleSeat")
            if vehicleSeat and (HRP.Position - vehicleSeat.Position).Magnitude <= 5 then
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

    return Humanoid.Sit and (HRP.Position - vehicleSeat.Position).Magnitude <= 5
end

-- Portal System
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

    local targetPos = targetCFrame.Position
    local hrpPos = HRP.Position
    local directDist = (targetPos - hrpPos).Magnitude

    local closestPortal = nil
    local bestSaving = 0

    for _, portalPos in pairs(seaTable) do
        local distToPortal = (portalPos - hrpPos).Magnitude
        local distFromPortal = (targetPos - portalPos).Magnitude
        local totalDist = distToPortal + distFromPortal
        local saving = directDist - totalDist

        -- Only use portal if it saves at least 1000 studs
        if saving > 1000 and saving > bestSaving then
            bestSaving = saving
            closestPortal = portalPos
        end
    end

    return closestPortal
end

-- Tween System
Modules.Tween = {}

function Modules.Tween:ToTarget(targetCFrame, btnState)
    if not Modules:ValidateReferences() then return end
    if State.isTweening then
        self:StopAll(false)
        task.wait(0.1)
    end

    State.isTweening = true

    -- Unsit if sitting
    if Humanoid.Sit then
        Humanoid.Sit = false
        task.wait(0.1)
    end

    local dist = (targetCFrame.Position - HRP.Position).Magnitude
    
    -- Instant teleport for short distances
    if dist <= 300 then
        HRP.CFrame = targetCFrame
        State.isTweening = false
        return
    end

    -- Monitor button state
    local monitorTask = task.spawn(function()
        while State.isTweening do
            State.btnStateTween = btnState or false
            
            if btnState then
                State.isTweening = false
                break
            end

            if not Modules:ValidateReferences() then
                State.isTweening = false
                if State.currentTween then
                    State.currentTween:Cancel()
                end
                break
            end
            
            task.wait(0.1)
        end
    end)

    -- Calculate tween parameters
    local tweenSpeed = Modules:GetTweenSpeed()
    local tweenDuration = dist / tweenSpeed
    local tweenInfo = TweenInfo.new(tweenDuration, Enum.EasingStyle.Linear)

    -- Handle portal logic
    local portal = Modules.Portal:GetClosest(targetCFrame)
    
    if portal and CommF_ then
        self:HandlePortalTeleport(portal, targetCFrame, tweenInfo)
    else
        -- Direct tween without portal
        State.currentTween = Services.TweenService:Create(HRP, tweenInfo, {CFrame = targetCFrame})
        State.currentTween:Play()
    end

    -- Return control object
    local tweenPlrFunc = {}
    function tweenPlrFunc:Stop()
        State.isTweening = false
        if State.currentTween then
            State.currentTween:Cancel()
            State.currentTween = nil
        end
        if monitorTask then
            task.cancel(monitorTask)
        end
    end

    if State.currentTween then
        State.currentTween.Completed:Wait()
        if Modules:ValidateReferences() then
            HRP.CFrame = targetCFrame
        end
    end

    State.isTweening = false

    return tweenPlrFunc
end

function Modules.Tween:HandlePortalTeleport(portal, targetCFrame, tweenInfo)
    local templePos = Vector3.new(28282.5703125, 14896.8505859375, 105.1042709350586)
    
    -- Temple of Time
    if (portal - Vector3.new(28282.5703, 14896.8506, 105.1043)).Magnitude < 10 then
        local mapStash = Services.ReplicatedStorage:WaitForChild("MapStash", 5)
        local temple = mapStash and mapStash:FindFirstChild("Temple of Time")
        
        if temple and not Services.Workspace:FindFirstChild("Temple of Time") then
            temple.Parent = Services.Workspace:WaitForChild("Map", 5)
        end
        
        local timeout = 0
        while not Services.Workspace:FindFirstChild("Temple of Time") and timeout < 50 do
            task.wait(0.1)
            timeout = timeout + 1
        end
        
        if Services.Workspace:FindFirstChild("Temple of Time") and (templePos - HRP.Position).Magnitude > 1000 then
            CommF_:InvokeServer("requestEntrance", templePos)
            task.wait(0.5)
        end
    
    -- Great Tree
    elseif (portal - Vector3.new(3028.209228515625, 2280.84619140625, -7324.2880859375)).Magnitude < 10 then
        if (templePos - HRP.Position).Magnitude > 1000 then
            CommF_:InvokeServer("requestEntrance", templePos)
            task.wait(0.5)
        end

        HRP.CFrame = CFrame.new(28609.650390625, 14896.5458984375, 105.68901062011719)
        task.wait(0.3)

        if Modules:ValidateReferences() and (HRP.Position - Vector3.new(28609.6504, 14896.5459, 105.6890)).Magnitude <= 20 then
            CommF_:InvokeServer("RaceV4Progress", "TeleportBack")
            task.wait(0.5)
        end
    
    -- Dimension Shift
    elseif (portal - Vector3.new(-2097.3447265625, 4776.24462890625, -15013.4990234375)).Magnitude < 10 then
        local map = Services.Workspace:FindFirstChild("Map")
        local cake = map and map:FindFirstChild("CakeLoaf")
        local mirror = cake and cake:FindFirstChild("BigMirror")

        if mirror and mirror:FindFirstChild("Other") and mirror.Other.Transparency == 0 then
            local main = mirror:FindFirstChild("Main")
            if main then
                HRP.CFrame = main.CFrame
                task.wait(0.3)
            end
        end
    
    -- Submerged Island
    elseif (portal - Vector3.new(10213.701171875, -1733.5025634765625, 9940.189453125)).Magnitude < 10 then
        local castlePos = Vector3.new(-5058.7749, 314.5155, -3155.8833)
        local submarinePos = Vector3.new(-16269.408203125, 23.979995727539062, 1371.662353515625)

        -- First go to castle if far away
        if (castlePos - HRP.Position).Magnitude > 2000 then
            CommF_:InvokeServer("requestEntrance", castlePos)
            task.wait(0.5)

            if Modules:ValidateReferences() then
                HRP.CFrame = CFrame.new(-5097.1318359375, 318.50201416015625, -3178.3984375)
                task.wait(0.3)
            end
        end
        
        -- Tween to submarine
        local subDist = (submarinePos - HRP.Position).Magnitude
        local subDuration = subDist / Modules:GetTweenSpeed()
        local subTweenInfo = TweenInfo.new(subDuration, Enum.EasingStyle.Linear)
        
        State.currentTween = Services.TweenService:Create(HRP, subTweenInfo, {CFrame = CFrame.new(submarinePos)})
        State.currentTween:Play()
        State.currentTween.Completed:Wait()

        task.wait(0.2)

        if Modules:ValidateReferences() and (submarinePos - HRP.Position).Magnitude <= 30 then
            local rep = Services.ReplicatedStorage
            local modules = rep:FindFirstChild("Modules")
            local net = modules and modules:FindFirstChild("Net")
            local rf = net and net:FindFirstChild("RF/SubmarineWorkerSpeak")
            
            if rf then
                rf:InvokeServer("TravelToSubmergedIsland")
                task.wait(1)
            end
        end
    
    -- Tiki Outpost
    elseif (portal - Vector3.new(-16799.091796875, 84.32279968261719, 291.0728454589844)).Magnitude < 10 then
        local castlePos = Vector3.new(-5058.7749, 314.5155, -3155.8833)
        
        if (castlePos - HRP.Position).Magnitude > 2000 then
            CommF_:InvokeServer("requestEntrance", castlePos)
            task.wait(0.5)

            if Modules:ValidateReferences() then
                HRP.CFrame = CFrame.new(-5097.1318359375, 318.50201416015625, -3178.3984375)
                task.wait(0.3)
            end
        end

        task.wait(0.2)
    
    -- Generic portal
    else
        CommF_:InvokeServer("requestEntrance", portal)
        task.wait(0.5)
    end

    -- Final tween to target
    if not Modules:ValidateReferences() then return end
    
    local finalDist = (targetCFrame.Position - HRP.Position).Magnitude
    local finalDuration = finalDist / Modules:GetTweenSpeed()
    local finalTweenInfo = TweenInfo.new(finalDuration, Enum.EasingStyle.Linear)
    
    State.currentTween = Services.TweenService:Create(HRP, finalTweenInfo, {CFrame = targetCFrame})
    State.currentTween:Play()
end

function Modules.Tween:Boat(targetCFrame)
    local myShip = Modules.CheckMyBoat()
    if not myShip then return end

    local vehicleSeat = myShip:FindFirstChild("VehicleSeat")
    if not vehicleSeat then return end

    local dist = (targetCFrame.Position - vehicleSeat.Position).Magnitude
    local boatSpeed = Modules:GetBoatSpeed()
    local duration = dist / boatSpeed
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)

    local tween = Services.TweenService:Create(vehicleSeat, tweenInfo, {CFrame = targetCFrame})
    tween:Play()
    
    local boatTweenFunc = {}
    function boatTweenFunc:Stop()
        if tween then
            tween:Cancel()
        end
    end
    
    return boatTweenFunc
end

function Modules.Tween:StopAll(stopMovement)
    State.isTweening = false
    
    if State.currentTween and State.currentTween.PlaybackState == Enum.PlaybackState.Playing then
        State.currentTween:Cancel()
        State.currentTween = nil
    end

    if stopMovement ~= false and Modules:ValidateReferences() then
        HRP.CFrame = HRP.CFrame
        HRP.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        
        local hoverClip = HRP:FindFirstChild("VinreachHoverClip")
        if hoverClip then
            hoverClip:Destroy()
        end
    end
end

-- Initialization
local function InitializeReferences()
    local success = Modules:SafePcall(function()
        Character = Player.Character or Player.CharacterAdded:Wait()
        HRP = Character:WaitForChild("HumanoidRootPart", 10)
        Humanoid = Character:WaitForChild("Humanoid", 10)
    end)

    return success and HRP and Humanoid and Humanoid.Health > 0
end

function Modules:Initialize()
    if State.isInitialized then return true end
    if not InitializeReferences() then return false end

    State.isInitialized = true
    _G.ModulesInitialized = true
    _G.ModulesVersion = Modules.Version
    
    return true
end

-- Character respawn handling
Player.CharacterAdded:Connect(function(newChar)
    State.isInitialized = false
    State.isTweening = false
    Character = newChar
    task.wait(0.5)

    if not Modules:Initialize() then
        task.wait(0.5)
        Modules:Initialize()
    end
end)

-- Configuration management
function Modules:UpdateConfig(newConfig)
    if type(newConfig) ~= "table" then return end

    for key, value in pairs(newConfig) do
        if key == "Tween" and type(value) == "table" then
            for k, v in pairs(value) do
                Config.Tween[k] = v
            end
        elseif Config[key] ~= nil then
            Config[key] = value
        end
    end
end

function Modules:GetConfig(key)
    if key then
        if key == "Tween" or Config.Tween[key] then
            return Config.Tween[key]
        else
            return Config[key]
        end
    else
        -- Return deep copy
        local copy = {}
        for k, v in pairs(Config) do
            if type(v) == "table" then
                copy[k] = {}
                for k2, v2 in pairs(v) do
                    copy[k][k2] = v2
                end
            else
                copy[k] = v
            end
        end
        return copy
    end
end

-- Public API
function Modules:ToPos(input, btn)
    if not State.isInitialized then return end
    return Modules.Tween:ToTarget(input, btn)
end

function Modules:BoatTween(input)
    if not State.isInitialized then return end
    return Modules.Tween:Boat(input)
end

function Modules:StopTween(stopMovement)
    Modules.Tween:StopAll(stopMovement)
end

function Modules:GetToposButtonState()
    return State.btnStateTween
end

-- Initialize on load
local initSuccess = Modules:Initialize()
if not initSuccess then
    task.wait(0.5)
    Modules:Initialize()
end

print("Modules Loaded v" .. Modules.Version)
return Modules