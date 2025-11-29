local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/SansYT789/Library/refs/heads/main/SaveManager.luau"))()
local Modules = {}
Modules.__index = Modules
Modules.Version = "1.0"

-- Service caching
local Services = {
    Players = game:GetService("Players"),
    Workspace = game:GetService("Workspace"),
    RunService = game:GetService("RunService"),
    TweenService = game:GetService("TweenService"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    UserInputService = game:GetService("UserInputService"),
    CollectionService = game:GetService("CollectionService")
}

-- Configuration
local Config = {
	Tween = {
        defaultTweenSpeed = 300,
        defaultBoatTweenSpeed = 150,
        adaptiveSpeed = false,
        smoothTransition = true,
        instantTeleportDistance = 300,
        maxTweenSpeed = 350,
        velocityCap = 150,
        positionUpdateRate = 0.05
    },

    Performance = {
        updateInterval = 0.1,
        validationCacheTime = 0.5,
        maxConcurrentTweens = 3,
        useAdaptiveQuality = true
    },
    
    Safety = {
        autoStopOnDeath = true,
        preventStuck = true,
        collisionCheckInterval = 0.2,
        maxVelocityMagnitude = 150,
        smoothingFactor = 0.3
    },

    Esp = {
        General = {
            UpdateRate = 0.5,
            MaxRenderDistance = 5000,
            FontSize = Enum.FontSize.Size14,
            Font = Enum.Font.GothamBold,
            StrokeTransparency = 0.5,
        },

        Players = {
            Enabled = false,
            ShowDistance = true,
            ShowHealth = true,
            ShowKen = true,
            ShowV4 = true,
            TeamCheck = true,
            TeamColor = Color3.fromRGB(0, 255, 100),
            EnemyColor = Color3.fromRGB(255, 80, 80),
        },

        Chests = {
            Enabled = false,
            ShowDistance = true,
            Colors = {
                Diamond = Color3.fromRGB(85, 255, 255),
                Gold = Color3.fromRGB(255, 215, 0),
                Silver = Color3.fromRGB(192, 192, 192),
                Default = Color3.fromRGB(255, 255, 255),
            },
        },

        Berries = {
            Enabled = false,
            ShowDistance = true,
            FilterList = {},
            Colors = {
                ["Blue Icicle Berry"] = {Color3.fromRGB(100, 180, 255), "Blue Icicle"},
                ["Green Toad Berry"] = {Color3.fromRGB(80, 255, 100), "Green Toad"},
                ["Orange Berry"] = {Color3.fromRGB(255, 160, 60), "Orange"},
                ["Pink Pig Berry"] = {Color3.fromRGB(255, 140, 200), "Pink Pig"},
                ["Purple Jelly Berry"] = {Color3.fromRGB(200, 100, 255), "Purple Jelly"},
                ["Red Cherry Berry"] = {Color3.fromRGB(255, 100, 100), "Red Cherry"},
                ["White Cloud Berry"] = {Color3.fromRGB(255, 255, 255), "White Cloud"},
                ["Yellow Star Berry"] = {Color3.fromRGB(255, 240, 100), "Yellow Star"},
            },
        },

        DevilFruits = {
            Enabled = false,
            ShowUnkDevilFruitId = true,
            ShowDistance = true,
            Color = Color3.fromRGB(255, 255, 255),
        },

        RealFruits = {
            Enabled = false,
            ShowDistance = true,
            Colors = {
                Apple = Color3.fromRGB(255, 0, 0),
                Pineapple = Color3.fromRGB(255, 174, 0),
                Banana = Color3.fromRGB(251, 255, 0),
            },
        },

        Flowers = {
            Enabled = false,
            ShowDistance = true,
            Colors = {
                Flower1 = {Color3.fromRGB(0, 0, 255), "Blue Flower"},
                Flower2 = {Color3.fromRGB(255, 0, 0), "Red Flower"},
            },
        },

        Islands = {
            Enabled = false,
            ShowDistance = true,
            Color = Color3.fromRGB(7, 236, 240),
            ExcludeList = {"Sea"},
        },

        EventIslands = {
            Enabled = false,
            ShowDistance = true,
            Islands = {
                ["Mirage Island"] = Color3.fromRGB(80, 245, 245),
                ["Kitsune Island"] = Color3.fromRGB(120, 253, 245),
                ["Prehistoric Island"] = Color3.fromRGB(255, 100, 40),
                ["Frozen Dimension"] = Color3.fromRGB(100, 220, 255),
            },
        },

        NPCs = {
            Enabled = false,
            ShowDistance = true,
            Color = Color3.fromRGB(80, 245, 245),
            Targets = {
                "Advanced Fruit Dealer",
                "Barista Cousin",
                "Legendary Sword Dealer",
            },
        },

        Gear = {
            Enabled = false,
            ShowDistance = true,
            Color = Color3.fromRGB(80, 245, 245),
        },
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
    activeTweens = {},
    isInitialized = false,
    tweenStates = {},
    continuousTweens = {},
    isTweening = false,
    lastValidation = 0,
    validationCache = true,
    tweenQueue = {},
    hoverClip = nil,
    boatHoverClips = {},
    tweenCooldown = 0,
    boatOriginalCollision = {},
    loopDetection = {
        active = {},
        history = {}
    },
    performance = {
    	tweenCount = 0,
        avgTweenTime = 0,
        lastFrameTime = tick()
    }
}

-- Remote setup
local Remotes = Services.ReplicatedStorage:WaitForChild("Remotes", 5)
local CommF_ = Remotes and Remotes:FindFirstChild("CommF_")

if not CommF_ then 
    warn("CommF_ not found! Portal features may not work.") 
end

-- Cache
local Cache = {
    ESPObjects = {},
    LastUpdate = 0,
    PlayerCharacters = {},
}

-- Devil Fruit IDs
local realFruitNameIds = {
    ["rbxassetid://15124425041"] = "Rocket-Rocket",
    ["rbxassetid://15123685330"] = "Spin-Spin",
    ["rbxassetid://15123613404"] = "Blade-Blade",
    ["rbxassetid://15104782377"] = "Blade-Blade",
    ["rbxassetid://15123689268"] = "Spring-Spring",
    ["rbxassetid://15123595806"] = "Bomb-Bomb",
    ["rbxassetid://15123677932"] = "Smoke-Smoke",
    ["rbxassetid://15124220207"] = "Spike-Spike",
    ["rbxassetid://121545956771325"] = "Flame-Flame",
    ["rbxassetid://15123673019"] = "Sand-Sand",
    ["rbxassetid://15123618591"] = "Dark-Dark",
    ["rbxassetid://77885466312115"] = "Eagle-Eagle",
    ["rbxassetid://15112600534"] = "Diamond-Diamond",
    ["rbxassetid://15123640714"] = "Light-Light",
    ["rbxassetid://15123668008"] = "Rubber-Rubber",
    ["rbxassetid://15123662036"] = "Ghost-Ghost",
    ["rbxassetid://15123645682"] = "Magma-Magma",
    ["rbxassetid://15123606541"] = "Buddha-Buddha",
    ["rbxassetid://15123643097"] = "Love-Love",
    ["rbxassetid://15123681598"] = "Spider-Spider",
    ["rbxassetid://116828771482820"] = "Creation-Creation",
    ["rbxassetid://15123679712"] = "Sound-Sound",
    ["rbxassetid://15123654553"] = "Phoenix-Phoenix",
    ["rbxassetid://15123656798"] = "Portal-Portal",
    ["rbxassetid://15123670514"] = "Rumble-Rumble",
    ["rbxassetid://15123652069"] = "Pain-Pain",
    ["rbxassetid://15123587371"] = "Blizzard-Blizzard",
    ["rbxassetid://15123633312"] = "Gravity-Gravity",
    ["rbxassetid://15123648309"] = "Mammoth-Mammoth",
    ["rbxassetid://15694681122"] = "T-Rex-T-Rex",
    ["rbxassetid://15123624401"] = "Dough-Dough",
    ["rbxassetid://15123675904"] = "Shadow-Shadow",
    ["rbxassetid://10773719142"] = "Venom-Venom",
    ["rbxassetid://15123616275"] = "Control-Control",
    ["rbxassetid://11911905519"] = "Spirit-Spirit",
    ["rbxassetid://15123638064"] = "Leopard-Leopard",
    ["rbxassetid://15487764876"] = "Kitsune-Kitsune",
    ["rbxassetid://115276580506154"] = "Yeti-Yeti",
    ["rbxassetid://118054805452821"] = "Gas-Gas",
    ["rbxassetid://95749033139458"] = "Dragon East-Dragon East"
}

-- Utility Functions
local function round(n)
    return math.floor(tonumber(n) + 0.5)
end

local function getDistance(pos1, pos2)
    return round((pos1 - pos2).Magnitude / 3)
end

local function isWithinRenderDistance(pos1, pos2)
    return (pos1 - pos2).Magnitude <= Config.Esp.General.MaxRenderDistance
end

function Modules:SafePcall(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        warn("SafePcall Error:", result)
    end
    return success, result
end

function Modules:IsAlive(char)
    char = char or Character
    if not char or not char.Parent then return false end
    
    local h = char:FindFirstChild("Humanoid")
    return h and h.Health > 0 and h.Parent ~= nil
end

function Modules:ValidateReferences()
    local now = tick()
    if now - State.lastValidation < Config.Performance.validationCacheTime then
        return State.validationCache
    end
    
    State.lastValidation = now
    State.validationCache = Character and Character.Parent
        and HRP and HRP.Parent
        and Humanoid and Humanoid.Parent
        and Humanoid.Health > 0
    
    return State.validationCache
end

local function getPlayerCharacter()
    return Player and Player.Character
end

-- ESP Creation and Management
local function createESPBillboard(parent, name, offset)
    local bill = Instance.new('BillboardGui')
    bill.Name = name or 'NameEsp'
    bill.ExtentsOffset = offset or Vector3.new(0, 1, 0)
    bill.Size = UDim2.new(1, 200, 1, 30)
    bill.Adornee = parent
    bill.AlwaysOnTop = true
    bill.Parent = parent

    local label = Instance.new('TextLabel')
    label.Name = "TextLabel"
    label.Font = Config.Esp.General.Font
    label.FontSize = Config.Esp.General.FontSize
    label.TextWrapped = true
    label.Size = UDim2.new(1, 0, 1, 0)
    label.TextYAlignment = 'Top'
    label.BackgroundTransparency = 1
    label.TextStrokeTransparency = Config.Esp.General.StrokeTransparency
    label.Parent = bill

    return bill, label
end

local function destroyESP(parent, espName)
    local existing = parent:FindFirstChild(espName)
    if existing then
        existing:Destroy()
        Cache.ESPObjects[parent] = nil
    end
end

local function updateOrCreateESP(parent, espName, updateFunc)
    if not parent then return end

    local existingESP = parent:FindFirstChild(espName)

    if not existingESP then
        local bill, label = createESPBillboard(parent, espName)
        Cache.ESPObjects[parent] = {billboard = bill, label = label}
        updateFunc(label, true)
    else
        local label = existingESP:FindFirstChild("TextLabel")
        if label then
            updateFunc(label, false)
        end
    end
end

local function isEnemyPlayer(plr)
    if not Player or not plr or plr == Player then return false end

    local myTeam = Player.Team
    local hisTeam = plr.Team

    if myTeam and myTeam.Name == "Pirates" then return true end
    if myTeam and myTeam.Name == "Marines" then return not (hisTeam and hisTeam == myTeam) end
    if myTeam == hisTeam then return false end

    return true
end

-- Devil Fruit Helpers
local function isValidFruitName(name)
    return type(name) == "string" and string.find(string.lower(name), "fruit")
end

local function normalizeIdValue(idValue)
    local strId = tostring(idValue or "")
    local assetId = strId:match("rbxassetid://(%d+)") or strId:match("(%d+)")
    return assetId and ("rbxassetid://" .. assetId) or nil
end

local function getAccurateFruitName(v)
    if not v then return "Fruit [ ??? ]" end

    local clean = v.Name:lower():gsub("%s+", "")
    if isValidFruitName(v.Name) and clean ~= "fruit" then return v.Name end

    local fruitModel = v:FindFirstChild("Fruit") or v:WaitForChild("Fruit", 3)
    if not fruitModel then return v.Name .. " [ ??? ]" end

    local idleObj = fruitModel:FindFirstChildWhichIsA("Animation") or fruitModel:FindFirstChildWhichIsA("MeshPart") or fruitModel:FindFirstChild("Fruit")
    if not idleObj then return v.Name .. " [ ??? ]" end

    local assetId = nil
    if idleObj:IsA("Animation") then
        assetId = idleObj.AnimationId
    elseif idleObj:IsA("MeshPart") then
        assetId = idleObj.MeshId
    end
    if not assetId or assetId == "" then return v.Name .. " [ ??? ]" end

    local normalized = normalizeIdValue(assetId)
    if not normalized then return v.Name .. " [ ??? ]" end

    local nameId = realFruitNameIds[normalized]
    if nameId then return v.Name .. "[ " .. nameId .. " ]" end

    return "Fruit [ ??? ]"
end

-- ESP Update Functions
function Modules:UpdatePlayerESP()
    if not Config.Esp.Players.Enabled then
        for player, char in pairs(Cache.PlayerCharacters) do
            if char and char:FindFirstChild("Head") then
                destroyESP(char.Head, "NameEspPlayer")
            end
        end
        Cache.PlayerCharacters = {}
        return
    end

    local char = getPlayerCharacter()
    if not char or not char:FindFirstChild("Head") then return end

    for _, player in ipairs(Services.Players:GetPlayers()) do
        if player == Player then continue end

        pcall(function()
            local targetChar = player.Character or Services.Workspace.Characters:FindFirstChild(player.Name)
            if not targetChar or not targetChar:FindFirstChild("Head") then return end

            Cache.PlayerCharacters[player] = targetChar
            local head = targetChar.Head

            if not isWithinRenderDistance(char.Head.Position, head.Position) then
                destroyESP(head, "NameEspPlayer")
                return
            end

            updateOrCreateESP(head, "NameEspPlayer", function(label, isNew)
                local distance = getDistance(char.Head.Position, head.Position)
                local humanoid = targetChar:FindFirstChildOfClass("Humanoid")
                local health = humanoid and round(humanoid.Health * 100 / humanoid.MaxHealth) or 0

                local text = player.Name
                if Config.Esp.Players.ShowDistance then
                    text = text .. " | " .. distance .. "M"
                end

                if Config.Esp.Players.ShowHealth then
                    text = text .. "\nHealth: " .. health .. "%"
                end

                if Config.Esp.Players.TeamCheck and isEnemyPlayer(player) then
                    if Config.Esp.Players.ShowKen then
                        local kenActive = player:GetAttribute("KenActive") and "Ken: ON" or "Ken: OFF"
                        local dodgeLeft = player:GetAttribute("KenDodgesLeft") or 0
                        text = text .. "\n" .. kenActive .. " | Dodge: " .. dodgeLeft
                    end

                    if Config.Esp.Players.ShowV4 then
                        local v4Active = (targetChar:FindFirstChild("RaceTransformed") and targetChar.RaceTransformed.Value) and "V4: ON" or "V4: OFF"
                        local v4Ready = (targetChar:FindFirstChild("RaceEnergy") and targetChar.RaceEnergy.Value == 1) and "Ready" or "Not Ready"
                        text = text .. "\n" .. v4Active .. " | " .. v4Ready
                    end

                    label.TextColor3 = Config.Esp.Players.EnemyColor
                else
                    label.TextColor3 = Config.Esp.Players.TeamColor
                end

                label.Text = text
            end)
        end)
    end
end

function Modules:UpdateChestESP()
    if not Config.Esp.Chests.Enabled then
        local chests = Services.CollectionService:GetTagged("_ChestTagged")
        for _, chest in ipairs(chests) do
            pcall(function() destroyESP(chest, "NameEspChest") end)
        end
        return
    end

    local char = getPlayerCharacter()
    if not char or not char:FindFirstChild("Head") then return end

    local chests = Services.CollectionService:GetTagged("_ChestTagged")
    for _, chest in ipairs(chests) do
        pcall(function()
            if chest:GetAttribute("IsDisabled") then
                destroyESP(chest, "NameEspChest")
                return
            end

            local chestPos = chest:IsA("BasePart") and chest.Position or chest:GetPivot().Position

            if not isWithinRenderDistance(char.Head.Position, chestPos) then
                destroyESP(chest, "NameEspChest")
                return
            end

            updateOrCreateESP(chest, "NameEspChest", function(label, isNew)
                local distance = getDistance(char.Head.Position, chestPos)
                local chestType = chest.Name:match("Chest3") and "Diamond" or
                                 chest.Name:match("Chest2") and "Gold" or
                                 chest.Name:match("Chest1") and "Silver" or "Default"

                label.TextColor3 = Config.Esp.Chests.Colors[chestType]
                label.Text = chest.Name:gsub("Label", "") .. "\n" .. distance .. "M"
            end)
        end)
    end
end

function Modules:UpdateBerryESP()
    if not Config.Esp.Berries.Enabled then
        local berryBushes = Services.CollectionService:GetTagged("BerryBush")
        for _, bush in ipairs(berryBushes) do
            pcall(function()
                local bushModel = bush.Parent
                if bushModel and bushModel:IsA("Model") then
                    local berriesFolder = bushModel:FindFirstChild("Berries")
                    if berriesFolder then
                        local firstBerry = berriesFolder:GetChildren()[1]
                        if firstBerry then
                            local espTarget = firstBerry:IsA("BasePart") and firstBerry or firstBerry:FindFirstChildWhichIsA("BasePart")
                            if espTarget then destroyESP(espTarget, "NameEspBerry") end
                        end
                    end
                end
            end)
        end
        return
    end

    local char = getPlayerCharacter()
    if not char or not char:FindFirstChild("Head") then return end

    local berryBushes = Services.CollectionService:GetTagged("BerryBush")
    for _, bush in ipairs(berryBushes) do
        pcall(function()
            local bushModel = bush.Parent
            if not bushModel or not bushModel:IsA("Model") then return end

            local berriesFolder = bushModel:FindFirstChild("Berries")
            if not berriesFolder or #berriesFolder:GetChildren() == 0 then
                destroyESP(bush, "NameEspBerry")
                return
            end

            local berryName = nil
            for key, value in pairs(bush:GetAttributes()) do
                if Config.Esp.Berries.Colors[key] then
                    berryName = key
                    break
                elseif Config.Esp.Berries.Colors[value] then
                    berryName = value
                    break
                end
            end

            if not berryName or (#Config.Esp.Berries.FilterList > 0 and not table.find(Config.Esp.Berries.FilterList, berryName)) then
                destroyESP(bush, "NameEspBerry")
                return
            end

            local firstBerry = berriesFolder:GetChildren()[1]
            local espTarget = firstBerry:IsA("BasePart") and firstBerry or firstBerry:FindFirstChildWhichIsA("BasePart")

            if not espTarget or not isWithinRenderDistance(char.Head.Position, espTarget.Position) then
                destroyESP(bush, "NameEspBerry")
                return
            end

            updateOrCreateESP(espTarget, "NameEspBerry", function(label, isNew)
                local distance = getDistance(char.Head.Position, espTarget.Position)
                local colorData = Config.Esp.Berries.Colors[berryName]

                label.TextColor3 = colorData[1]
                label.Text = string.format("[%s]\n%dM", colorData[2], distance)
            end)
        end)
    end
end

function Modules:UpdateDevilFruitESP()
    if not Config.Esp.DevilFruits.Enabled then
        for _, v in ipairs(Services.Workspace:GetChildren()) do
            pcall(function()
                if v.Name:find("Fruit") and v:FindFirstChild("Handle") then
                    destroyESP(v.Handle, "NameEspFruit")
                end
            end)
        end
        return
    end

    local char = getPlayerCharacter()
    if not char or not char:FindFirstChild("Head") then return end

    for _, v in ipairs(Services.Workspace:GetChildren()) do
        pcall(function()
            if not v.Name:find("Fruit") or not v:FindFirstChild("Handle") then return end

            local handle = v.Handle
            local name = v.Name

            if not isWithinRenderDistance(char.Head.Position, handle.Position) then
                destroyESP(handle, "NameEspFruit")
                return
            end

            if Config.Esp.DevilFruits.ShowUnkDevilFruitId then
                name = getAccurateFruitName(v)
            end

            updateOrCreateESP(handle, "NameEspFruit", function(label, isNew)
                local distance = getDistance(char.Head.Position, handle.Position)
                label.TextColor3 = Config.Esp.DevilFruits.Color
                label.Text = name .. "\n" .. distance .. "M"
            end)
        end)
    end
end

function Modules:UpdateIslandESP()
    local locations = Services.Workspace:FindFirstChild("_WorldOrigin")
    if locations then locations = locations:FindFirstChild("Locations") end
    if not locations then return end

    if not Config.Esp.Islands.Enabled then
        for _, island in ipairs(locations:GetChildren()) do
            pcall(function() destroyESP(island, "NameEspIsland") end)
        end
        return
    end

    local char = getPlayerCharacter()
    if not char or not char:FindFirstChild("Head") then return end

    for _, island in ipairs(locations:GetChildren()) do
        pcall(function()
            if table.find(Config.Esp.Islands.ExcludeList, island.Name) then return end

            updateOrCreateESP(island, "NameEspIsland", function(label, isNew)
                local distance = getDistance(char.Head.Position, island.Position)
                label.TextColor3 = Config.Esp.Islands.Color
                label.Text = island.Name .. "\n" .. distance .. "M"
            end)
        end)
    end
end

function Modules:UpdateEventIslandESP()
    local locations = Services.Workspace:FindFirstChild("_WorldOrigin")
    if locations then locations = locations:FindFirstChild("Locations") end
    if not locations then return end

    if not Config.Esp.EventIslands.Enabled then
        for _, island in ipairs(locations:GetChildren()) do
            pcall(function() destroyESP(island, "NameEspEvent") end)
        end
        return
    end

    local char = getPlayerCharacter()
    if not char or not char:FindFirstChild("Head") then return end

    for islandName, color in pairs(Config.Esp.EventIslands.Islands) do
        for _, island in ipairs(locations:GetChildren()) do
            pcall(function()
                if island.Name ~= islandName then return end

                updateOrCreateESP(island, "NameEspEvent", function(label, isNew)
                    local distance = getDistance(char.Head.Position, island.Position)
                    label.TextColor3 = color
                    label.Text = island.Name .. "\n" .. distance .. "M"
                end)
            end)
        end
    end
end

function Modules:UpdateNPCESP()
    local npcs = Services.Workspace:FindFirstChild("NPCs")
    
    if not Config.Esp.NPCs.Enabled then
        if npcs then
            for _, npc in ipairs(npcs:GetChildren()) do
                pcall(function() destroyESP(npc, "NameEspNPC") end)
            end
        end
        return
    end

    local char = getPlayerCharacter()
    if not char or not char:FindFirstChild("Head") or not npcs then return end

    for _, npcName in ipairs(Config.Esp.NPCs.Targets) do
        for _, npc in ipairs(npcs:GetChildren()) do
            pcall(function()
                if npc.Name ~= npcName then return end

                if not isWithinRenderDistance(char.Head.Position, npc.Position) then
                    destroyESP(npc, "NameEspNPC")
                    return
                end

                updateOrCreateESP(npc, "NameEspNPC", function(label, isNew)
                    local distance = getDistance(char.Head.Position, npc.Position)
                    label.TextColor3 = Config.Esp.NPCs.Color
                    label.Text = npc.Name .. "\n" .. distance .. "M"
                end)
            end)
        end
    end
end

-- ESP Control Functions
function Modules:StartESP()
    if self.UpdateConnection then return end

    self.UpdateConnection = Services.RunService.Heartbeat:Connect(function()
        local currentTime = tick()
        if currentTime - Cache.LastUpdate < Config.Esp.General.UpdateRate then return end
        Cache.LastUpdate = currentTime

        self:UpdatePlayerESP()
        self:UpdateChestESP()
        self:UpdateBerryESP()
        self:UpdateDevilFruitESP()
        self:UpdateIslandESP()
        self:UpdateEventIslandESP()
        self:UpdateNPCESP()
    end)
    
    print("ESP Started")
end

function Modules:StopESP()
    if self.UpdateConnection then
        self.UpdateConnection:Disconnect()
        self.UpdateConnection = nil
    end
    print("ESP Stopped")
end

function Modules:SetESPConfig(category, key, value)
    if Config.Esp[category] and Config.Esp[category][key] ~= nil then
        Config.Esp[category][key] = value
        return true
    end
    return false
end

function Modules:GetESPConfig(category, key)
    if Config.Esp[category] then
        return key and Config.Esp[category][key] or Config.Esp[category]
    end
    return nil
end

function Modules:EnableESPCategory(category)
    if Config.Esp[category] then
        Config.Esp[category].Enabled = true
    end
end

function Modules:DisableESPCategory(category)
    if Config.Esp[category] then
        Config.Esp[category].Enabled = false
    end
end

function Modules:ClearAllESP()
    for parent, data in pairs(Cache.ESPObjects) do
        if data.billboard then
            data.billboard:Destroy()
        end
    end
    Cache.ESPObjects = {}
end

local TweenStateManager = {}
function TweenStateManager:Create(tweenId, options)
    options = options or {}
    
    State.tweenStates[tweenId] = {
        id = tweenId,
        active = true,
        continuous = options.continuous or false,
        loopMode = options.loopMode or false,
        stopCallback = options.stopCallback,
        completeCallback = options.completeCallback,
        startTime = tick(),
        metadata = options.metadata or {}
    }
    
    if options.continuous or options.loopMode then
        State.continuousTweens[tweenId] = true
    end
    
    return State.tweenStates[tweenId]
end

function TweenStateManager:Get(tweenId)
    return State.tweenStates[tweenId]
end

function TweenStateManager:IsActive(tweenId)
    local state = State.tweenStates[tweenId]
    return state and state.active
end

function TweenStateManager:Stop(tweenId, silent)
    local state = State.tweenStates[tweenId]
    if not state then return end
    
    state.active = false
    State.continuousTweens[tweenId] = nil
    
    if not silent and state.stopCallback then
        task.spawn(state.stopCallback)
    end
end

function TweenStateManager:StopAll(category)
    for id, state in pairs(State.tweenStates) do
        if not category or state.metadata.category == category then
            self:Stop(id, false)
        end
    end
end

function TweenStateManager:Cleanup(tweenId)
    State.tweenStates[tweenId] = nil
    State.continuousTweens[tweenId] = nil
end

function TweenStateManager:ShouldContinue(tweenId)
    local state = State.tweenStates[tweenId]
    return state and state.active and (state.continuous or state.loopMode)
end

function TweenStateManager:HasContinuousTweens()
    return next(State.continuousTweens) ~= nil
end

local LoopDetector = {}
function LoopDetector:Track(position, threshold)
    threshold = threshold or 50
    local history = State.loopDetection.history
    
    table.insert(history, {pos = position, time = tick()})
    
    -- Keep only last 10 positions
    if #history > 10 then
        table.remove(history, 1)
    end
    
    -- Detect if we're looping (visiting same area repeatedly)
    if #history >= 5 then
        local recent = history[#history].pos
        local count = 0
        
        for i = #history - 1, math.max(1, #history - 5), -1 do
            if (recent - history[i].pos).Magnitude < threshold then
                count = count + 1
            end
        end
        
        return count >= 3 -- Loop detected if 3+ similar positions
    end
    
    return false
end

function LoopDetector:Clear()
    State.loopDetection.history = {}
end

function LoopDetector:IsInLoop()
    return #State.loopDetection.active > 0
end

function LoopDetector:RegisterLoop(loopId)
    State.loopDetection.active[loopId] = true
end

function LoopDetector:UnregisterLoop(loopId)
    State.loopDetection.active[loopId] = nil
end

function Modules:GetTweenSpeed()
    local manager = self:GetSaveManagerInstance()
    if manager and manager.ready then
        local savedSpeed = manager:get("Tween Speed")
        if savedSpeed and type(savedSpeed) == "number" then
            return math.clamp(savedSpeed, 150, 350)
        end
    end
    
    local baseSpeed = Config.Tween.defaultTweenSpeed
    
    if Config.Tween.adaptiveSpeed then
        local currentTime = tick()
        local deltaTime = currentTime - State.performance.lastFrameTime
        State.performance.lastFrameTime = currentTime
        
        local fps = deltaTime > 0 and (1 / deltaTime) or 60
        
        if fps < 30 then
            baseSpeed = baseSpeed * 0.85
        elseif fps > 60 then
            baseSpeed = baseSpeed * 1.1
        end
    end
    
    return math.clamp(baseSpeed, 50, 500)
end

function Modules:GetBoatSpeed()
    local manager = self:GetSaveManagerInstance()
    if manager and manager.ready then
        local savedSpeed = manager:get("Boat Tween Speed")
        if savedSpeed and type(savedSpeed) == "number" then
            return math.clamp(savedSpeed, 150, 300)
        end
    end
    
    return math.clamp(Config.Tween.defaultBoatTweenSpeed, 50, 300)
end

Modules.Hover = {}
Modules.Hover._originalCollisions = Modules.Hover._originalCollisions or {}
function Modules.Hover:Ensure()
    if not Modules:ValidateReferences() then return end
    
    if State.hoverClip and State.hoverClip.Parent == HRP then 
        return State.hoverClip
    end

    if State.hoverClip then 
        State.hoverClip:Destroy() 
    end

    State.hoverClip = Instance.new("BodyVelocity")
    State.hoverClip.Name = "VinreachHoverClip"
    State.hoverClip.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    State.hoverClip.Velocity = Vector3.new(0, 0, 0)
    State.hoverClip.P = 5000
    State.hoverClip.Parent = HRP
    
    return State.hoverClip
end

function Modules.Hover:Remove()
    if State.hoverClip then
        State.hoverClip:Destroy()
        State.hoverClip = nil
    end
end

function Modules.Hover:SetNoClip(enabled)
    if not Modules:ValidateReferences() then return end
    local cache = Modules.Hover._originalCollisions

    if enabled then
        self:Ensure()
        for _, part in pairs(Character:GetDescendants()) do
            if part:IsA("BasePart") then
                if cache[part] == nil then
                    cache[part] = part.CanCollide
                end
                part.CanCollide = false
            end
        end
    else
        self:Remove()
        for part, originalState in pairs(cache) do
            if part and part:IsA("BasePart") then
                part.CanCollide = originalState
            end
        end
        table.clear(cache)
    end
end

-- Heartbeat for hover with continuous tween support
Services.RunService.Heartbeat:Connect(function()
    if State.hoverClip and State.hoverClip.Parent then
        if State.isTweening or TweenStateManager:HasContinuousTweens() then
            State.hoverClip.Velocity = Vector3.new(0, 0, 0)
        end
    end
end)

function Modules.CheckMyBoat()
    if not Modules:ValidateReferences() then return nil end

    local boats = Services.Workspace:FindFirstChild("Boats")
    if not boats then return nil end

    for _, boat in ipairs(boats:GetChildren()) do
        local owner = boat:FindFirstChild("Owner")
        if not owner then continue end

        if tostring(owner.Value) == Player.Name then
            return boat
        end

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

function Modules:ManageBoatHover(boat, enabled)
    if not boat or not boat:FindFirstChild("VehicleSeat") then return end

    local vehicleSeat = boat.VehicleSeat
    local bv = vehicleSeat:FindFirstChild("boatHoverTweenVin")
    
    -- Prepare cache for this boat
    State.boatOriginalCollision[boat] = State.boatOriginalCollision[boat] or {}
    local cache = State.boatOriginalCollision[boat]
    
    if enabled then
        -- Create BodyVelocity if not exists
        if not bv then
            bv = Instance.new("BodyVelocity")
            bv.Name = "boatHoverTweenVin"
            bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            bv.Velocity = Vector3.new(0, 0, 0)
            bv.Parent = vehicleSeat
            State.boatHoverClips[boat] = bv
        end
        -- Turn off collision (and cache original state)
        for _, part in pairs(boat:GetDescendants()) do
            if part:IsA("BasePart") then
                if cache[part] == nil then
                    cache[part] = part.CanCollide
                end
                part.CanCollide = false
            end
        end
    else
        -- Destroy hover force
        if bv then
            bv:Destroy()
            State.boatHoverClips[boat] = nil
        end
        
        -- Restore original collision
        for part, original in pairs(cache) do
            if part and part:IsA("BasePart") then
                part.CanCollide = original
            end
        end
        
        -- Cleanup cache for this boat
        State.boatOriginalCollision[boat] = nil
    end
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
    if not targetCFrame or not Modules:ValidateReferences() then return nil end

    local seaTable = Sea3 and PortalLocations.Sea3 
                  or Sea2 and PortalLocations.Sea2 
                  or Sea1 and PortalLocations.Sea1

    if not seaTable then return nil end

    local targetPos = targetCFrame.Position
    local hrpPos = HRP.Position
    local closestPortal = nil
    local closestDist = math.huge

    for _, portalPos in pairs(seaTable) do
        local distFromPortal = (portalPos - targetPos).Magnitude
        if distFromPortal < closestDist then
            closestPortal = portalPos
            closestDist = distFromPortal
        end
    end
    
    if closestPortal and closestDist <= (targetPos - hrpPos).Magnitude then
        return closestPortal
    end
    
    return nil
end

Modules.Tween = {}
function Modules.Tween:CalculateTweenInfo(distance, customSpeed)
    local speed = customSpeed or Modules:GetTweenSpeed()
    speed = math.clamp(speed, 150, Config.Tween.maxTweenSpeed)
    local duration = distance / speed
    
    return TweenInfo.new(
        duration,
        Enum.EasingStyle.Linear,
        Enum.EasingDirection.InOut
    )
end

function Modules.Tween:ToTarget(targetCFrame, options)
    if not Modules:ValidateReferences() then return end
    
    -- Support both old (btnState) and new (options table) API
    if type(options) == "boolean" then
        options = {stopOnToggle = options}
    elseif type(options) ~= "table" then
        options = {}
    end
    
    -- Generate unique tween ID
    local tweenId = "tween_" .. tostring(tick()):gsub("%.", "_")
    
    -- Create tween state
    local tweenState = TweenStateManager:Create(tweenId, {
        continuous = options.continuous or false,
        loopMode = options.loopMode or false,
        stopCallback = options.onStop,
        completeCallback = options.onComplete,
        metadata = options.metadata or {}
    })
    
    -- Cooldown check
    if tick() < State.tweenCooldown then 
        return 
    end
    State.tweenCooldown = tick() + 0.15
    
    if State.isTweening and not options.continuous then
        self:StopAll(false)
        task.wait(0.2)
    end

    State.isTweening = true

    if Humanoid.Sit then
        Humanoid.Sit = false
        task.wait(0.2)
    end

    local dist = (targetCFrame.Position - HRP.Position).Magnitude
    
    if dist <= Config.Tween.instantTeleportDistance then
        HRP.CFrame = targetCFrame
        State.isTweening = false
        TweenStateManager:Cleanup(tweenId)
        return
    end

    Modules.Hover:SetNoClip(true)
    
    local velocityControl
    local monitorTask
    
    velocityControl = Services.RunService.Heartbeat:Connect(function()
        if not State.isTweening or not Modules:ValidateReferences() then return end
        
        local currentVelocity = HRP.AssemblyLinearVelocity
        if currentVelocity.Magnitude > Config.Safety.maxVelocityMagnitude then
            HRP.AssemblyLinearVelocity = currentVelocity.Unit * Config.Safety.maxVelocityMagnitude
        end
    end)

    -- NEW: Enhanced monitor with state checking
    monitorTask = task.spawn(function()
        while State.isTweening and TweenStateManager:IsActive(tweenId) do
            -- Check stop conditions
            if options.stopOnToggle and not TweenStateManager:IsActive(tweenId) then
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
            
            -- Loop detection for continuous tweens
            if options.continuous or options.loopMode then
                local isLoop = LoopDetector:Track(HRP.Position)
                if isLoop then
                    LoopDetector:RegisterLoop(tweenId)
                end
            end
            
            task.wait(Config.Performance.updateInterval)
        end
    end)

    local tweenInfo = self:CalculateTweenInfo(dist)
    local portal = Modules.Portal:GetClosest(targetCFrame)
    
    if portal and CommF_ then
        self:HandlePortalTeleport(portal, targetCFrame, tweenInfo)
    else
        State.currentTween = Services.TweenService:Create(HRP, tweenInfo, {CFrame = targetCFrame})
        State.currentTween:Play()
        table.insert(State.activeTweens, State.currentTween)
    end

    -- Return control object
    local tweenControl = {}
    function tweenControl:Stop()
        TweenStateManager:Stop(tweenId)
        State.isTweening = false
        
        if velocityControl then
            velocityControl:Disconnect()
        end
        
        if State.currentTween and State.currentTween.PlaybackState == Enum.PlaybackState.Playing then
            State.currentTween:Cancel()
        end
        State.currentTween = nil
        
        if monitorTask then
            task.cancel(monitorTask)
        end
        
        if Modules:ValidateReferences() then
            HRP.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            HRP.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
        
        Modules.Hover:SetNoClip(false)
        LoopDetector:UnregisterLoop(tweenId)
    end
    
    function tweenControl:GetState()
        return TweenStateManager:Get(tweenId)
    end
    
    function tweenControl:IsActive()
        return TweenStateManager:IsActive(tweenId)
    end

    -- Wait for completion
    if State.currentTween then
        local startTime = tick()
        local success = pcall(function()
            State.currentTween.Completed:Wait()
        end)
        
        if success then
            local tweenTime = tick() - startTime
            State.performance.tweenCount = State.performance.tweenCount + 1
            State.performance.avgTweenTime = (State.performance.avgTweenTime + tweenTime) / 2
            
            if tweenState.completeCallback then
                task.spawn(tweenState.completeCallback)
            end
        end
        
        if Modules:ValidateReferences() then
            task.wait(0.1)
            HRP.CFrame = targetCFrame
            HRP.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            HRP.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
    end

    if velocityControl then
        velocityControl:Disconnect()
    end
    
    -- Only stop if not continuous
    if not TweenStateManager:ShouldContinue(tweenId) then
        State.isTweening = false
        Modules.Hover:SetNoClip(false)
        LoopDetector:UnregisterLoop(tweenId)
    end

    for i = #State.activeTweens, 1, -1 do
        if State.activeTweens[i] == State.currentTween then
            table.remove(State.activeTweens, i)
        end
    end
    
    TweenStateManager:Cleanup(tweenId)
    return tweenControl
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
            task.wait(1) -- Increased wait for server
        end
    
    -- Great Tree
    elseif (portal - Vector3.new(3028.209228515625, 2280.84619140625, -7324.2880859375)).Magnitude < 10 then
        if (templePos - HRP.Position).Magnitude > 1000 then
            CommF_:InvokeServer("requestEntrance", templePos)
            task.wait(1)
        end

        HRP.CFrame = CFrame.new(28609.650390625, 14896.5458984375, 105.68901062011719)
        task.wait(0.5)

        if Modules:ValidateReferences() and (HRP.Position - Vector3.new(28609.6504, 14896.5459, 105.6890)).Magnitude <= 20 then
            CommF_:InvokeServer("RaceV4Progress", "TeleportBack")
            task.wait(1)
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
                task.wait(0.5)
            end
        end
    
    -- Submerged Island
    elseif (portal - Vector3.new(10213.701171875, -1733.5025634765625, 9940.189453125)).Magnitude < 10 then
        local castlePos = Vector3.new(-5058.7749, 314.5155, -3155.8833)
        local submarinePos = Vector3.new(-16269.408203125, 23.979995727539062, 1371.662353515625)

        if (submarinePos - HRP.Position).Magnitude > 1205 then
            CommF_:InvokeServer("requestEntrance", castlePos)
            task.wait(1)

            if Modules:ValidateReferences() then
                HRP.CFrame = CFrame.new(-5097.1318359375, 318.50201416015625, -3178.3984375)
                task.wait(0.5)
            end
        end
        
        local subDist = (submarinePos - HRP.Position).Magnitude
        local subTweenInfo = self:CalculateTweenInfo(subDist)
        
        State.currentTween = Services.TweenService:Create(HRP, subTweenInfo, {CFrame = CFrame.new(submarinePos)})
        State.currentTween:Play()
        State.currentTween.Completed:Wait()

        task.wait(0.5)

        if Modules:ValidateReferences() and (submarinePos - HRP.Position).Magnitude <= 15 then
            local rep = Services.ReplicatedStorage
            local modules = rep:FindFirstChild("Modules")
            local net = modules and modules:FindFirstChild("Net")
            local rf = net and net:FindFirstChild("RF/SubmarineWorkerSpeak")
            
            self:StopAll(true)
            if rf then
                rf:InvokeServer("TravelToSubmergedIsland")
                task.wait(2)
            end
        end
    
    -- Tiki Outpost
    elseif (portal - Vector3.new(-16799.091796875, 84.32279968261719, 291.0728454589844)).Magnitude < 10 then
        local castlePos = Vector3.new(-5058.7749, 314.5155, -3155.8833)
        local tikiPos = Vector3.new(-16799.091796875, 84.32279968261719, 291.0728454589844)
        
        if (tikiPos - HRP.Position).Magnitude > 2000 then
            CommF_:InvokeServer("requestEntrance", castlePos)
            task.wait(1)

            if Modules:ValidateReferences() then
                HRP.CFrame = CFrame.new(-5097.1318359375, 318.50201416015625, -3178.3984375)
                task.wait(0.5)
            end
        elseif (castlePos - HRP.Position).Magnitude < 750 then
            if (Vector3.new(-5097.1318359375, 318.50201416015625, -3178.3984375) - HRP.Position).Magnitude < 100 then
                if Modules:ValidateReferences() then
                    if State.isTweening then
                        self:StopAll(true)
                    end

                    HRP.CFrame = CFrame.new(-5097.1318359375, 318.50201416015625, -3178.3984375)
                    task.wait(0.5)
                end
            else
                local tikiDist = (Vector3.new(-5097.1318359375, 318.50201416015625, -3178.3984375) - HRP.Position).Magnitude
                local tikiTweenInfo = self:CalculateTweenInfo(tikiDist)
            
                State.currentTween = Services.TweenService:Create(HRP, tikiTweenInfo, {CFrame = CFrame.new(-5097.1318359375, 318.50201416015625, -3178.3984375)})
                State.currentTween:Play()
                State.currentTween.Completed:Wait()
            end
        end

        task.wait(0.5)
    
    -- Generic portal
    else
        CommF_:InvokeServer("requestEntrance", portal)
        task.wait(1)
    end

    -- Final tween to target
    if not Modules:ValidateReferences() then return end
    
    local finalDist = (targetCFrame.Position - HRP.Position).Magnitude
    local finalTweenInfo = self:CalculateTweenInfo(finalDist)
    
    State.currentTween = Services.TweenService:Create(HRP, finalTweenInfo, {CFrame = targetCFrame})
    State.currentTween:Play()
end

function Modules.Tween:Boat(targetCFrame, autoManage)
    local myShip = Modules.CheckMyBoat()
    if not myShip then return end

    local vehicleSeat = myShip:FindFirstChild("VehicleSeat")
    if not vehicleSeat then return end

    if autoManage ~= false then
        Modules:ManageBoatHover(myShip, true)
    end

    local dist = (targetCFrame.Position - vehicleSeat.Position).Magnitude
    -- Use slower speed for boats
    local tweenInfo = self:CalculateTweenInfo(dist, Config.Tween.defaultBoatTweenSpeed)

    local tween = Services.TweenService:Create(vehicleSeat, tweenInfo, {CFrame = targetCFrame})
    tween:Play()
    
    table.insert(State.activeTweens, tween)
    
    local boatTweenFunc = {}
    function boatTweenFunc:Stop()
        if tween and tween.PlaybackState == Enum.PlaybackState.Playing then
            tween:Cancel()
        end
        
        for i = #State.activeTweens, 1, -1 do
            if State.activeTweens[i] == tween then
                table.remove(State.activeTweens, i)
                break
            end
        end
        
        if autoManage ~= false then
            Modules:ManageBoatHover(myShip, false)
        end
    end
    
    tween.Completed:Connect(function()
        if autoManage ~= false then
            Modules:ManageBoatHover(myShip, false)
        end
        
        for i = #State.activeTweens, 1, -1 do
            if State.activeTweens[i] == tween then
                table.remove(State.activeTweens, i)
                break
            end
        end
    end)
    
    return boatTweenFunc
end

function Modules.Tween:StopAll(stopMovement)
    State.isTweening = false
    TweenStateManager:StopAll()
    LoopDetector:Clear()
    
    for i = #State.activeTweens, 1, -1 do
        local tween = State.activeTweens[i]
        if tween and tween.PlaybackState == Enum.PlaybackState.Playing then
            pcall(function() tween:Cancel() end)
        end
        State.activeTweens[i] = nil
    end
    
    table.clear(State.activeTweens)
    
    if State.currentTween then
        if State.currentTween.PlaybackState == Enum.PlaybackState.Playing then
            pcall(function() State.currentTween:Cancel() end)
        end
        State.currentTween = nil
    end

    if stopMovement ~= false and Modules:ValidateReferences() then
        pcall(function()
            HRP.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            HRP.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            HRP.CFrame = HRP.CFrame
        end)
        
        Modules.Hover:Remove()
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
    
    print("✓ Modules v" .. Modules.Version .. " initialized successfully")
    return true
end

-- Character respawn handling
Player.CharacterAdded:Connect(function(newChar)
    State.isInitialized = false
    State.isTweening = false
    State.activeTweens = {}
    State.tweenQueue = {}
    State.tweenStates = {}
    State.continuousTweens = {}
    Character = newChar
    
    Modules.Hover:Remove()
    TweenStateManager:StopAll()
    LoopDetector:Clear()

    task.wait(0.5)
    if not Modules:Initialize() then
        task.wait(0.5)
        Modules:Initialize()
    end
end)

function Modules:InitCode(settings)
    local manager = SaveManager.new(Player, settings)
    _G.SaveManagerInstance = manager
    
    if not manager then 
        warn("[SaveManager] Save mode is currently not working, the script may not save settings anymore.") 
    end
    
    return manager
end

function Modules:ToPos(input, options)
    if not State.isInitialized then return end
    return Modules.Tween:ToTarget(input, options)
end

function Modules:BoatTween(input, autoManage)
    if not State.isInitialized then return end
    return Modules.Tween:Boat(input, autoManage)
end

function Modules:StopTween(stopMovement)
    Modules.Tween:StopAll(stopMovement)
end

function Modules:IsTweening()
    return State.isTweening or TweenStateManager:HasContinuousTweens()
end

function Modules:GetTweenStates()
    return State.tweenStates
end

function Modules:IsInLoop()
    return LoopDetector:IsInLoop()
end

task.spawn(function()
    while task.wait(Config.Performance.updateInterval) do
        Modules:SafePcall(function()
            local myBoat = Modules.CheckMyBoat()
            
            if myBoat then
                local shouldManage = State.isTweening or Modules.CheckInMyBoat()
                
                if shouldManage then
                    Modules:ManageBoatHover(myBoat, true)
                else
                    Modules:ManageBoatHover(myBoat, false)
                end
            end
        end)
    end
end)

if Config.Safety.preventStuck then
    local lastPosition = nil
    local stuckTime = 0
    
    task.spawn(function()
        while task.wait(Config.Safety.collisionCheckInterval) do
            Modules:SafePcall(function()
                if not State.isTweening or not Modules:ValidateReferences() then 
                    lastPosition = nil
                    stuckTime = 0
                    return 
                end
                
                local currentPos = HRP.Position
                
                if lastPosition then
                    local moved = (currentPos - lastPosition).Magnitude
                    
                    -- If moved less than 2 studs in 0.2 seconds while tweening
                    if moved < 2 then
                        stuckTime = stuckTime + Config.Safety.collisionCheckInterval
                        
                        -- If stuck for more than 1 second, try to unstuck
                        if stuckTime > 1 then
                            -- Teleport slightly up and forward
                            local lookVector = HRP.CFrame.LookVector
                            HRP.CFrame = HRP.CFrame + Vector3.new(0, 5, 0) + (lookVector * 10)
                            stuckTime = 0
                        end
                    else
                        stuckTime = 0
                    end
                end
                
                lastPosition = currentPos
            end)
        end
    end)
end

-- Initialize on load
local initSuccess = Modules:Initialize()
if not initSuccess then
    task.wait(0.5)
    initSuccess = Modules:Initialize()
    
    if not initSuccess then
        warn("Failed to initialize Modules v" .. Modules.Version)
    end
end

-- Global access
_G.Modules = Modules
return Modules