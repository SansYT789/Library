local Modules = {}
Modules.__index = Modules
Modules.Version = "1.6"

local Services = {
    Players = game:GetService("Players"),
    Workspace = game:GetService("Workspace"),
    RunService = game:GetService("RunService"),
    TweenService = game:GetService("TweenService"),
    ReplicatedStorage = game:GetService("ReplicatedStorage")
}

local Config = {
    Tween = {
    	defaultTweenSpeed = 300,
        defaultBoatTweenSpeed = 150
    }
}

local Player = Services.Players.LocalPlayer
local Character, HRP, Humanoid

local placeId = game.PlaceId
local Sea1 = placeId == 2753915549
local Sea2 = placeId == 4442272183
local Sea3 = placeId == 7449423635
if not Sea1 and not Sea2 and not Sea3 then warn("This is not Blox Fruits! Some features may not work.") end

local State = {currentTween = nil, isInitialized = false, btnStateTween = false}

local Remotes = Services.ReplicatedStorage:WaitForChild("Remotes", 5)
local CommF_ = Remotes and Remotes:WaitForChild("CommF_", 5)
if not CommF_ then warn("CommF_ not found! Portal features may not work.") end

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
    if not Character or not Character.Parent then return false end
    if not HRP or not HRP.Parent then return false end
    if not Humanoid or not Humanoid.Parent then return false end
    if Humanoid.Health <= 0 then return false end
    return true
end

function Modules:GetTweenSpeed()
    return Config.Tween.defaultTweenSpeed
end

function Modules:GetBoatSpeed()
    return Config.Tween.defaultBoatTweenSpeed
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

    if Humanoid.Sit == true and (HRP.Position - vehicleSeat.Position).Magnitude <= 5 then
        return true
    end

    return false
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
    local minDistance = math.huge

    local targetPos = targetCFrame.Position
    local hrpPos = HRP.Position

    for name, portalPos in pairs(seaTable) do
        local distToPortal = (portalPos - targetPos).Magnitude
        if distToPortal < minDistance then
            minDistance = distToPortal
            closestPortal = portalPos
        end
    end

    if minDistance <= (targetPos - hrpPos).Magnitude then
        return closestPortal
    end
end

Modules.Tween = {}
function Modules.Tween:ToTarget(targetCFrame, btnState)
    if not Modules:ValidateReferences() then return end

    if Humanoid.Sit then
        Humanoid.Sit = false
    end

    if State.currentTween and State.currentTween.PlaybackState == Enum.PlaybackState.Playing then
        State.currentTween:Cancel()
        State.currentTween = nil
    end

    local dist = (targetCFrame.Position - HRP.Position).Magnitude
    if dist <= 300 then
        HRP.CFrame = targetCFrame
    end
    
    task.spawn(function()
        while State.currentTween and State.currentTween.PlaybackState == Enum.PlaybackState.Playing do
            if btnState then
                State.btnStateTween = true
                break
            else
                State.btnStateTween = false
                break
            end

            if not Modules:ValidateReferences() then
                State.currentTween:Cancel()
                break
            end
            task.wait(0.1)
        end
    end)
    
    local tweenSpeed = Modules:GetTweenSpeed()
    local tweenDuration = dist / tweenSpeed
    local tweenInfo = TweenInfo.new(tweenDuration, Enum.EasingStyle.Linear)

    local portal = Modules.Portal:GetClosest(targetCFrame)
    local templePos = Vector3.new(28282.5703125, 14896.8505859375, 105.1042709350586)
    if portal == Vector3.new(28282.5703, 14896.8506, 105.1043) then
        local mapStash = Services.ReplicatedStorage:WaitForChild("MapStash")
        local temple = mapStash:FindFirstChild("Temple of Time")
        if temple and not workspace:FindFirstChild("Temple of Time") then
            temple.Parent = workspace:WaitForChild("Map")
        end
        while not workspace:FindFirstChild("Temple of Time") do
            task.wait(0.1)
        end
        
        if workspace:FindFirstChild("Temple of Time") then
            if (templePos - HRP.Position).Magnitude > 10000 then
                CommF_:InvokeServer("requestEntrance", templePos)
            end
        end
    elseif portal == Vector3.new(3028.209228515625, 2280.84619140625, -7324.2880859375) then
        if (templePos - HRP.Position).Magnitude > 10000 then
            CommF_:InvokeServer("requestEntrance", templePos)
        end

        HRP.CFrame = CFrame.new(28609.650390625, 14896.5458984375, 105.68901062011719)
        task.wait(0.1)

        if (HRP.Position - Vector3.new(28609.6504, 14896.5459, 105.6890)).Magnitude <= 15 then
            CommF_:InvokeServer("RaceV4Progress", "TeleportBack")
        end
    elseif portal == Vector3.new(-2097.3447265625, 4776.24462890625, -15013.4990234375) then
        local map = Services.Workspace:FindFirstChild("Map")
        local cake = map and map:FindFirstChild("CakeLoaf")
        local mirror = cake and cake:FindFirstChild("BigMirror")

        if mirror and mirror:FindFirstChild("Other") and mirror.Other.Transparency == 0 then
            if mirror:FindFirstChild("Main") then
                HRP.CFrame = mirror.Main.CFrame
                task.wait(0.1)
            end
        end
    elseif portalPos == Vector3.new(10213.701171875, -1733.5025634765625, 9940.189453125) then
        local submarinePos = Vector3.new(-16269.408203125, 23.979995727539062, 1371.662353515625)

        if (submarinePos - HRP.Position).Magnitude > 1205 then
            CommF_:InvokeServer("requestEntrance", Vector3.new(-5058.7749, 314.5155, -3155.8833))
            task.wait(0.1)

            HRP.CFrame = CFrame.new(-5097.1318359375, 318.50201416015625, -3178.3984375)
            task.wait(0.15)
        end
        
        State.currentTween = Services.TweenService:Create(HRP, tweenInfo, {CFrame = CFrame.new(submarinePos)})
        State.currentTween:Play()

        if (submarinePos - HRP.Position).Magnitude <= 20 then
            local rep = Services.ReplicatedStorage
            local modules = rep:FindFirstChild("Modules")
            if modules then
                local net = modules:FindFirstChild("Net")
                if net then
                    local rf = net:FindFirstChild("RF/SubmarineWorkerSpeak")
                    if rf then
                        rf:InvokeServer("TravelToSubmergedIsland")
                        State.currentTween:Cancel()
                        task.wait(0.2)
                    end
                end
            end
        end
    elseif portal == Vector3.new(-16799.091796875, 84.32279968261719, 291.0728454589844) then
        CommF_:InvokeServer("requestEntrance", Vector3.new(-5058.7749, 314.5155, -3155.8833))
        task.wait(0.1)

        HRP.CFrame = CFrame.new(-5097.1318359375, 318.50201416015625, -3178.3984375)
        task.wait(0.15)
    else
        CommF_:InvokeServer("requestEntrance", portal)
    end

    State.currentTween = Services.TweenService:Create(HRP, tweenInfo, {CFrame = targetCFrame})
    State.currentTween:Play()

    local tweenPlrFunc = {}
    function tweenPlrFunc:Stop()
        State.currentTween:Cancel()
    end

    State.currentTween.Completed:Wait()
    HRP.CFrame = targetCFrame

    return tweenPlrFunc
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
        tween:Cancel()
    end
    return boatTweenFunc
end

function Modules.Tween:StopAll(target)
    if State.currentTween.PlaybackState == Enum.PlaybackState.Playing then
        State.currentTween:Cancel()
        State.currentTween = nil
    end

    if not target then
        if Modules:ValidateReferences() then
            HRP.CFrame = HRP.CFrame + Vector3.new(0, 0.01, 0)
            if HRP:FindFirstChild("VinreachHoverClip") then
                HRP:FindFirstChild("VinreachHoverClip"):Destroy()
            end
        end
    end
end

local function InitializeReferences()
    local success = Modules:SafePcall(function()
        Character = Player.Character or Player.CharacterAdded:Wait()
        HRP = Character:WaitForChild("HumanoidRootPart", 10)
        Humanoid = Character:WaitForChild("Humanoid", 10)
    end)

    if not success or not HRP or not Humanoid then return false end
    if Humanoid.Health <= 0 then return false end
    return true
end

function Modules:Initialize()
    if State.isInitialized then return end
    if not InitializeReferences() then return end

    State.isInitialized = true
    _G.ModulesInitialized = true
    _G.ModulesVersion = Modules.Version
end

Player.CharacterAdded:Connect(function(newChar)
    State.isInitialized = false
    Character = newChar
    task.wait(0.5)

    local success = Modules:Initialize()
    if not success then
        Modules:Initialize()
    end
end)

function Modules:UpdateConfig(newConfig)
    if type(newConfig) ~= "table" then return end

    local tweenLocal = {defaultTweenSpeed=true, fastTweenSpeed=true, slowTweenSpeed=true, defaultBoatTweenSpeed=true}
    for key, value in pairs(newConfig) do
        if Config[key] ~= nil then
            if type(Config[key]) == "table" and type(value) == "table" then
                for k,v in pairs(value) do
                    Config[key][k] = v
                end
            else
                Config[key] = value
            end
        elseif tweenLocal[key] then
            Config.Tween = Config.Tween or {}
            Config.Tween[key] = value
        end
    end
end

function Modules:GetConfig(key)
    local tweenLocal = {defaultTweenSpeed=true, fastTweenSpeed=true, slowTweenSpeed=true, defaultBoatTweenSpeed=true}
    if key then
        if tweenLocal[key] then
            return Config.Tween and Config.Tween[key]
        else
            return Config[key]
        end
    else
        local copy = {}
        for k,v in pairs(Config) do
            copy[k] = v
        end
        return copy
    end
end

function Modules:ToPos(input, btn)
    if not State.isInitialized then return end
    Modules.Tween:ToTarget(input, btn)
end

function Modules:BoatTween(input)
    if not State.isInitialized then return end
    Modules.Tween:Boat(input) 
end

function Modules:StopTween(target)
    Modules.Tween:StopAll(target)
end

function Modules:GetToposButtonState()
    return State.btnStateTween or false
end

local initSuccess = Modules:Initialize()
if not initSuccess then
    Modules:Initialize()
end
print("Modules Loaded")

return Modules