local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/SansYT789/Library/refs/heads/main/SaveManager.luau"))()
local Modules = {}
Modules.__index = Modules
Modules.Version = "1.3"

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
        instantTeleportDistance = 300,
        maxTweenSpeed = 350,
        velocityCap = 150,
    },

    Performance = {
        updateInterval = 0.1,
        validationCacheTime = 0.5,
    },
    
    Safety = {
        autoStopOnDeath = true,
        maxVelocityMagnitude = 150,
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
    isTweening = false,
    lastValidation = 0,
    validationCache = true,
    hoverClip = nil,
    boatHoverClips = {},
    tweenCooldown = 0,
    boatOriginalCollision = {},
    tweenStates = {},
    continuousTweens = {},
    tweenQueue = {},
    loopDetection = {
        history = {},
        active = {}
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
local ESPCache = {
    Players = {},
    LastFullUpdate = 0,
    UpdateInterval = 0.5,
    QuickUpdateInterval = 0.1,
    LastQuickUpdate = 0
}

local ChestCache = {
    Chests = {},
    LastUpdate = 0,
    UpdateInterval = 0.3
}

local BerryCache = {
    Bushes = {},
    LastUpdate = 0,
    UpdateInterval = 0.4,
    AttributeCache = {}
}

local FruitCache = {
    Fruits = {},
    NameCache = {},
    LastUpdate = 0,
    UpdateInterval = 0.5
}

local IslandCache = {
    LocationsFolder = nil,
    Islands = {},
    ExcludeSet = {},
    EventIslandSet = {},
    LastUpdate = 0,
    UpdateInterval = 1.0,
    LastStructureCheck = 0,
    StructureCheckInterval = 5.0
}

local NPCCache = {
    TrackedNPCs = {},
    TargetSet = {},
    LastUpdate = 0,
    UpdateInterval = 0.8
}

local RealFruitCache = {
    Fruits = {},
    LastUpdate = 0,
    UpdateInterval = 0.5
}

local FlowerCache = {
    Flowers = {},
    LastUpdate = 0,
    UpdateInterval = 0.6
}

local GearCache = {
    Gears = {},
    LastUpdate = 0,
    UpdateInterval = 0.7
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

local function isWithinMaxDistance(pos1, pos2)
    return getDistance(pos1, pos2) <= Config.Esp.General.MaxRenderDistance
end

function Modules:GetSaveManagerInstance()
    return _G.SaveManagerInstance
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
    if not h or not h.Parent or h.Health <= 0 then return false end
    
    return true
end

function Modules:ValidateReferences()
    if State.validationCache then
        local now = tick()
        if (now - State.lastValidation) < Config.Performance.validationCacheTime then
            return true
        end
    end
    
    local now = tick()
    State.lastValidation = now
    
    if not Character or not Character.Parent then
        State.validationCache = false
        return false
    end
    
    if not HRP or not HRP.Parent then
        State.validationCache = false
        return false
    end
    
    if not Humanoid or not Humanoid.Parent then
        State.validationCache = false
        return false
    end
    
    State.validationCache = Humanoid.Health > 0
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
    end
end

local function updateOrCreateESP(parent, espName, updateFunc)
    if not parent then return end

    local existingESP = parent:FindFirstChild(espName)

    if not existingESP then
        local bill, label = createESPBillboard(parent, espName)
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

-- ESP Update Functions
function Modules:UpdatePlayerESP()
    if not Config.Esp.Players.Enabled then
        for player, data in pairs(ESPCache.Players) do
            if data.head and data.head:FindFirstChild("NameEspPlayer") then
                data.head.NameEspPlayer:Destroy()
            end
        end
        ESPCache.Players = {}
        return
    end

    local char = getPlayerCharacter()
    if not char or not char:FindFirstChild("Head") then return end
    
    local currentTime = tick()
    local isFullUpdate = (currentTime - ESPCache.LastFullUpdate) >= ESPCache.UpdateInterval
    local isQuickUpdate = (currentTime - ESPCache.LastQuickUpdate) >= ESPCache.QuickUpdateInterval
    
    if not isFullUpdate and not isQuickUpdate then return end
    
    local charHeadPos = char.Head.Position
    local allPlayers = Services.Players:GetPlayers()
    
    for _, player in ipairs(allPlayers) do
        if player == Player then continue end
        
        local cacheData = ESPCache.Players[player]
        
        local targetChar = (cacheData and cacheData.character) or player.Character or Services.Workspace.Characters:FindFirstChild(player.Name)
        if not targetChar or not targetChar.Parent then
            targetChar = player.Character or Services.Workspace.Characters:FindFirstChild(player.Name)
            if not targetChar then 
                if cacheData then
                    ESPCache.Players[player] = nil
                end
                continue 
            end
        end
        
        local head = targetChar:FindFirstChild("Head")
        if not head then continue end
        
        local dist = getDistance(charHeadPos, head.Position)

        if not isWithinMaxDistance(charHeadPos, head.Position) then
            destroyESP(head, "NameEspPlayer")
            ESPCache.Players[player] = nil
            continue
        end
        
        if not cacheData then
            cacheData = {
                character = targetChar,
                head = head,
                humanoid = targetChar:FindFirstChildOfClass("Humanoid"),
                lastUpdate = 0,
            }
            ESPCache.Players[player] = cacheData
        else
            cacheData.character = targetChar
            cacheData.humanoid = targetChar:FindFirstChildOfClass("Humanoid")
        end
        
        if isFullUpdate then
            updateOrCreateESP(head, "NameEspPlayer", function(label, isNew)
                local distance = dist
                local textLines = {}

                local line1 = player.Name
                if Config.Esp.Players.ShowDistance then
                    line1 = line1 .. " (" .. distance .. "M)"
                end
                
                if Config.Esp.Players.ShowHealth and cacheData.humanoid then
                    local maxHealth = cacheData.humanoid.MaxHealth
                    local health = cacheData.humanoid.Health
                    if maxHealth and maxHealth > 0 then
                        if health <= 0 then
                            line1 = line1 .. " | Death!"
                        else
                            local healthPercent = math.floor(health * 100 / maxHealth)
                            line1 = line1 .. " | HP: " .. healthPercent .. "%"
                        end
                    else
                        line1 = line1 .. " | Death!"
                    end
                end
                table.insert(textLines, line1)
                
                local isEnemy = Config.Esp.Players.TeamCheck and isEnemyPlayer(player)
                if isEnemy then
                    if Config.Esp.Players.ShowKen then
                        local kenActive = player:GetAttribute("KenActive")
                        local dodgeLeft = player:GetAttribute("KenDodgesLeft") or 0
                        local kenLine = (kenActive and "Ken: ON" or "Ken: OFF") .. " | DodgeLeft: " .. dodgeLeft
                        table.insert(textLines, kenLine)
                    end
                    
                    if Config.Esp.Players.ShowV4 then
                        local raceTransformed = targetChar:FindFirstChild("RaceTransformed")
                        local raceEnergy = targetChar:FindFirstChild("RaceEnergy")
                        local v4Active = raceTransformed and raceTransformed.Value
                        local v4Ready = raceEnergy and raceEnergy.Value == 1
                        local v4Line = (v4Active and "V4: ON" or "V4: OFF") .. " | " .. (v4Ready and "Ready" or "Not Ready")
                        table.insert(textLines, v4Line)
                    end
                end
                
                label.TextColor3 = isEnemy and Config.Esp.Players.EnemyColor or Config.Esp.Players.TeamColor
                label.Text = table.concat(textLines, "\n")
            end)
        end
    end
    
    if isFullUpdate then
        ESPCache.LastFullUpdate = currentTime
    end
    if isQuickUpdate then
        ESPCache.LastQuickUpdate = currentTime
    end
end

function Modules:UpdateChestESP()
    if not Config.Esp.Chests.Enabled then
        for chest, _ in pairs(ChestCache.Chests) do
            pcall(function() 
                destroyESP(chest, "NameEspChest") 
            end)
        end
        ChestCache.Chests = {}
        return
    end

    local currentTime = tick()
    if (currentTime - ChestCache.LastUpdate) < ChestCache.UpdateInterval then
        return
    end
    ChestCache.LastUpdate = currentTime

    local char = getPlayerCharacter()
    if not char or not char:FindFirstChild("Head") then return end
    
    local charHeadPos = char.Head.Position
    local chests = Services.CollectionService:GetTagged("_ChestTagged")
    local activeChests = {}
    
    for _, chest in ipairs(chests) do
        pcall(function()
            if chest:GetAttribute("IsDisabled") then
                destroyESP(chest, "NameEspChest")
                return
            end
            
            activeChests[chest] = true
            
            local chestPos = chest:IsA("BasePart") and chest.Position or chest:GetPivot().Position
            local dist = getDistance(charHeadPos, chestPos)
            
            if not isWithinMaxDistance(charHeadPos, chestPos) then
                destroyESP(chest, "NameEspChest")
                return
            end
            
            updateOrCreateESP(chest, "NameEspChest", function(label, isNew)
                local distance = dist
                
                local chestType = chest.Name:match("Chest3") and "Diamond" or
                                 chest.Name:match("Chest2") and "Gold" or
                                 chest.Name:match("Chest1") and "Silver" or "Default"

                label.TextColor3 = Config.Esp.Chests.Colors[chestType]
                label.Text = chest.Name:gsub("Label", "") .. "\n" .. distance .. "M"
            end)
        end)
    end
    
    for chest, _ in pairs(ChestCache.Chests) do
        if not activeChests[chest] then
            destroyESP(chest, "NameEspChest")
            ChestCache.Chests[chest] = nil
        end
    end
    
    ChestCache.Chests = activeChests
end

function Modules:UpdateBerryESP()
    if not Config.Esp.Berries.Enabled then
        for bush, data in pairs(BerryCache.Bushes) do
            if data and data.espTarget then
                destroyESP(data.espTarget, "NameEspBerry")
            end
        end
        BerryCache.Bushes = {}
        BerryCache.AttributeCache = {}
        return
    end

    local currentTime = tick()
    if (currentTime - BerryCache.LastUpdate) < BerryCache.UpdateInterval then
        return
    end
    BerryCache.LastUpdate = currentTime

    local char = getPlayerCharacter()
    if not char or not char:FindFirstChild("Head") then return end
    
    local charHeadPos = char.Head.Position
    local filterList = Config.Esp.Berries.FilterList
    local hasFilter = #filterList > 0
    
    local filterLookup = {}
    if hasFilter then
        for _, name in ipairs(filterList) do
            filterLookup[name] = true
        end
    end
    
    local berryBushes = Services.CollectionService:GetTagged("BerryBush")
    local activeBushes = {}
    
    for _, bush in ipairs(berryBushes) do
        pcall(function()
            local bushModel = bush.Parent
            if not bushModel or not bushModel:IsA("Model") then return end

            local cachedData = BerryCache.Bushes[bush]
            local berriesFolder = cachedData and cachedData.berriesFolder
            
            if not berriesFolder or not berriesFolder.Parent then
                berriesFolder = bushModel:FindFirstChild("Berries")
            end
            
            if not berriesFolder then
                destroyESP(bush, "NameEspBerry")
                return
            end
            
            local berryCount = cachedData and cachedData.berryCount or #berriesFolder:GetChildren()
            
            if berryCount == 0 then
                destroyESP(bush, "NameEspBerry")
                BerryCache.Bushes[bush] = nil
                return
            end
            
            local berryName = BerryCache.AttributeCache[bush]
            
            if not berryName then
                local attributes = bush:GetAttributes()
                for key, value in pairs(attributes) do
                    if Config.Esp.Berries.Colors[key] then
                        berryName = key
                        BerryCache.AttributeCache[bush] = key
                        break
                    elseif Config.Esp.Berries.Colors[value] then
                        berryName = value
                        BerryCache.AttributeCache[bush] = value
                        break
                    end
                end
            end

            if not berryName or (hasFilter and not filterLookup[berryName]) then
                destroyESP(bush, "NameEspBerry")
                return
            end

            local espTarget = cachedData and cachedData.espTarget
            
            if not espTarget or not espTarget.Parent then
                local firstBerry = berriesFolder:GetChildren()[1]
                if not firstBerry then return end
                
                espTarget = firstBerry:IsA("BasePart") and firstBerry 
                    or firstBerry:FindFirstChildWhichIsA("BasePart")
                
                if not espTarget then return end
            end

            local dist = getDistance(charHeadPos, espTarget.Position)
            
            if not isWithinMaxDistance(charHeadPos, espTarget.Position) then
                destroyESP(espTarget, "NameEspBerry")
                return
            end

            activeBushes[bush] = true
            BerryCache.Bushes[bush] = {
                berriesFolder = berriesFolder,
                espTarget = espTarget,
                berryName = berryName,
                berryCount = berryCount
            }

            updateOrCreateESP(espTarget, "NameEspBerry", function(label, isNew)
                local distance = dist
                local colorData = Config.Esp.Berries.Colors[berryName]

                label.TextColor3 = colorData[1]
                label.Text = string.format("[%s]\n%dM", colorData[2], distance)
            end)
        end)
    end
    
    for bush, _ in pairs(BerryCache.Bushes) do
        if not activeBushes[bush] then
            local data = BerryCache.Bushes[bush]
            if data and data.espTarget then
                destroyESP(data.espTarget, "NameEspBerry")
            end
            BerryCache.Bushes[bush] = nil
            BerryCache.AttributeCache[bush] = nil
        end
    end
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

local function getAccurateFruitNameCached(v)
    local cached = FruitCache.NameCache[v]
    if cached then return cached end
    
    if not v then return "Fruit [ ??? ]" end

    local clean = v.Name:lower():gsub("%s+", "")
    if isValidFruitName(v.Name) and clean ~= "fruit" then 
        FruitCache.NameCache[v] = v.Name
        return v.Name 
    end

    local fruitModel = v:FindFirstChild("Fruit")
    if not fruitModel then 
        local fallback = v.Name .. " [ ??? ]"
        FruitCache.NameCache[v] = fallback
        return fallback
    end

    local idleObj = fruitModel:FindFirstChild("Idle")
        or fruitModel:FindFirstChildWhichIsA("Animation")
        or fruitModel:FindFirstChildWhichIsA("MeshPart")
        or fruitModel:FindFirstChild("Fruit")
    
    if not idleObj then 
        local fallback = v.Name .. " [ ??? ]"
        FruitCache.NameCache[v] = fallback
        return fallback
    end

    local assetId
    if idleObj:IsA("Animation") then
        assetId = idleObj.AnimationId
    elseif idleObj:IsA("MeshPart") then
        assetId = idleObj.MeshId
    end
    
    if not assetId or assetId == "" then 
        local fallback = v.Name .. " [ ??? ]"
        FruitCache.NameCache[v] = fallback
        return fallback
    end

    local normalized = normalizeIdValue(assetId)
    if not normalized then 
        local fallback = v.Name .. " [ ??? ]"
        FruitCache.NameCache[v] = fallback
        return fallback
    end

    local nameId = realFruitNameIds[normalized]
    local result = nameId and (v.Name .. "[ " .. nameId .. " ]") or "Fruit [ ??? ]"
    
    FruitCache.NameCache[v] = result
    return result
end

function Modules:UpdateDevilFruitESP()
    if not Config.Esp.DevilFruits.Enabled then
        -- Bulk cleanup
        for fruit, data in pairs(FruitCache.Fruits) do
            if data and data.handle then
                destroyESP(data.handle, "NameEspFruit")
            end
        end
        FruitCache.Fruits = {}
        FruitCache.NameCache = {}
        return
    end

    local currentTime = tick()
    if (currentTime - FruitCache.LastUpdate) < FruitCache.UpdateInterval then
        return
    end
    FruitCache.LastUpdate = currentTime

    local char = getPlayerCharacter()
    if not char or not char:FindFirstChild("Head") then return end
    
    local charHeadPos = char.Head.Position
    local showId = Config.Esp.DevilFruits.ShowUnkDevilFruitId
    
    -- Get workspace children once
    local workspaceChildren = Services.Workspace:GetChildren()
    local activeFruits = {}

    for _, v in ipairs(workspaceChildren) do
        pcall(function()
            -- Quick name check (cheaper than FindFirstChild)
            if not v.Name:find("Fruit") then return end
            
            -- Check cache for handle
            local cachedData = FruitCache.Fruits[v]
            local handle = cachedData and cachedData.handle
            
            if not handle or not handle.Parent then
                handle = v:FindFirstChild("Handle")
                if not handle then return end
            end

            -- Fast distance check
            local dist = getDistance(charHeadPos, handle.Position)

            if not isWithinMaxDistance(charHeadPos, handle.Position) then
                destroyESP(handle, "NameEspFruit")
                FruitCache.Fruits[v] = nil
                return
            end

            -- Get name (use cached if available)
            local name = cachedData and cachedData.name
            
            if not name or (showId and not name:find("%[")) then
                name = showId and getAccurateFruitNameCached(v) or v.Name
            end

            -- Update cache
            activeFruits[v] = true
            FruitCache.Fruits[v] = {
                handle = handle,
                name = name
            }

            -- Update ESP
            updateOrCreateESP(handle, "NameEspFruit", function(label, isNew)
                local distance = dist
                label.TextColor3 = Config.Esp.DevilFruits.Color
                label.Text = name .. "\n" .. distance .. "M"
            end)
        end)
    end
    
    -- Cleanup removed fruits
    for fruit, data in pairs(FruitCache.Fruits) do
        if not activeFruits[fruit] then
            if data and data.handle then
                destroyESP(data.handle, "NameEspFruit")
            end
            FruitCache.Fruits[fruit] = nil
            FruitCache.NameCache[fruit] = nil
        end
    end
end

local function buildExcludeLookup()
    IslandCache.ExcludeSet = {}
    for _, name in ipairs(Config.Esp.Islands.ExcludeList) do
        IslandCache.ExcludeSet[name] = true
    end
end

-- Build event island lookup table once
local function buildEventIslandLookup()
    IslandCache.EventIslandSet = {}
    for name, color in pairs(Config.Esp.EventIslands.Islands) do
        IslandCache.EventIslandSet[name] = color
    end
end

-- Get locations folder with caching
local function getLocationsFolder()
    local now = tick()
    
    -- Check structure every 5 seconds (in case of map changes)
    if (now - IslandCache.LastStructureCheck) > IslandCache.StructureCheckInterval then
        IslandCache.LastStructureCheck = now
        
        local worldOrigin = Services.Workspace:FindFirstChild("_WorldOrigin")
        IslandCache.LocationsFolder = worldOrigin and worldOrigin:FindFirstChild("Locations")
    end
    
    return IslandCache.LocationsFolder
end
-- Initialize lookups
buildExcludeLookup()
buildEventIslandLookup()

function Modules:UpdateIslandESP()
    local locations = getLocationsFolder()
    if not locations then return end

    if not Config.Esp.Islands.Enabled then
        -- Bulk cleanup
        for island, _ in pairs(IslandCache.Islands) do
            destroyESP(island, "NameEspIsland")
        end
        IslandCache.Islands = {}
        return
    end

    local currentTime = tick()
    if (currentTime - IslandCache.LastUpdate) < IslandCache.UpdateInterval then
        return
    end
    IslandCache.LastUpdate = currentTime

    local char = getPlayerCharacter()
    if not char or not char:FindFirstChild("Head") then return end
    
    local charHeadPos = char.Head.Position
    local activeIslands = {}

    -- Single iteration with O(1) lookup
    for _, island in ipairs(locations:GetChildren()) do
        -- Fast lookup instead of table.find
        if IslandCache.ExcludeSet[island.Name] then continue end
        
        activeIslands[island] = true

        pcall(function()
            updateOrCreateESP(island, "NameEspIsland", function(label, isNew)
                local distance = getDistance(charHeadPos, island.Position)
                label.TextColor3 = Config.Esp.Islands.Color
                label.Text = island.Name .. "\n" .. distance .. "M"
            end)
        end)
    end
    
    -- Cleanup removed islands
    for island, _ in pairs(IslandCache.Islands) do
        if not activeIslands[island] then
            destroyESP(island, "NameEspIsland")
        end
    end
    
    IslandCache.Islands = activeIslands
end

function Modules:UpdateEventIslandESP()
    local locations = getLocationsFolder()
    if not locations then return end

    if not Config.Esp.EventIslands.Enabled then
        for _, island in ipairs(locations:GetChildren()) do
            pcall(function() destroyESP(island, "NameEspEvent") end)
        end
        return
    end

    local char = getPlayerCharacter()
    if not char or not char:FindFirstChild("Head") then return end
    
    local charHeadPos = char.Head.Position

    -- Single optimized iteration
    for _, island in ipairs(locations:GetChildren()) do
        local color = IslandCache.EventIslandSet[island.Name]
        
        -- Skip if not an event island
        if not color then continue end

        pcall(function()
            updateOrCreateESP(island, "NameEspEvent", function(label, isNew)
                local distance = getDistance(charHeadPos, island.Position)
                label.TextColor3 = color
                label.Text = island.Name .. "\n" .. distance .. "M"
            end)
        end)
    end
end

local function buildNPCTargetLookup()
    NPCCache.TargetSet = {}
    for _, name in ipairs(Config.Esp.NPCs.Targets) do
        NPCCache.TargetSet[name] = true
    end
end
buildNPCTargetLookup()

function Modules:UpdateNPCESP()
    local npcs = Services.Workspace:FindFirstChild("NPCs")
    
    if not Config.Esp.NPCs.Enabled then
        if npcs then
            for npc, _ in pairs(NPCCache.TrackedNPCs) do
                destroyESP(npc, "NameEspNPC")
            end
        end
        NPCCache.TrackedNPCs = {}
        return
    end

    local currentTime = tick()
    if (currentTime - NPCCache.LastUpdate) < NPCCache.UpdateInterval then
        return
    end
    NPCCache.LastUpdate = currentTime

    local char = getPlayerCharacter()
    if not char or not char:FindFirstChild("Head") or not npcs then return end
    
    local charHeadPos = char.Head.Position
    local activeNPCs = {}

    -- Single iteration with O(1) lookup
    for _, npc in ipairs(npcs:GetChildren()) do
        -- Fast lookup instead of nested loop
        if not NPCCache.TargetSet[npc.Name] then continue end

        pcall(function()
            local dist = getDistance(charHeadPos, npc.Position)

            if not isWithinMaxDistance(charHeadPos, npc.Position) then
                destroyESP(npc, "NameEspNPC")
                return
            end

            activeNPCs[npc] = true

            updateOrCreateESP(npc, "NameEspNPC", function(label, isNew)
                local distance = dist
                label.TextColor3 = Config.Esp.NPCs.Color
                label.Text = npc.Name .. "\n" .. distance .. "M"
            end)
        end)
    end
    
    -- Cleanup
    for npc, _ in pairs(NPCCache.TrackedNPCs) do
        if not activeNPCs[npc] then
            destroyESP(npc, "NameEspNPC")
        end
    end
    
    NPCCache.TrackedNPCs = activeNPCs
end

function Modules:UpdateRealFruitESP()
    if not Config.Esp.RealFruits.Enabled then
        for fruit, data in pairs(RealFruitCache.Fruits) do
            if data and data.part then
                destroyESP(data.part, "NameEspRealFruit")
            end
        end
        RealFruitCache.Fruits = {}
        return
    end

    local currentTime = tick()
    if (currentTime - RealFruitCache.LastUpdate) < RealFruitCache.UpdateInterval then
        return
    end
    RealFruitCache.LastUpdate = currentTime

    local char = getPlayerCharacter()
    if not char or not char:FindFirstChild("Head") then return end
    
    local charHeadPos = char.Head.Position
    local activeFruits = {}
    
    -- Search in Map folder
    local map = Services.Workspace:FindFirstChild("Map")
    if not map then return end

    for _, obj in ipairs(map:GetDescendants()) do
        if obj:IsA("Model") and (obj.Name == "AppleSpawner" or obj.Name == "PineappleSpawner" or obj.Name == "BananaSpawner") then
            local part = obj:FindFirstChildWhichIsA("BasePart")
            if not part then continue end
            
            local dist = getDistance(charHeadPos, part.Position)
            if not isWithinMaxDistance(charHeadPos, part.Position) then continue end
            
            activeFruits[obj] = true
            
            pcall(function()
                updateOrCreateESP(part, "NameEspRealFruit", function(label, isNew)
                    local distance = dist
                    local color = Config.Esp.RealFruits.Colors[obj.Name]
                    
                    label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
                    label.Text = obj.Name .. "\n" .. distance .. "M"
                end)
            end)
        end
    end
    
    -- Cleanup
    for fruit, data in pairs(RealFruitCache.Fruits) do
        if not activeFruits[fruit] and data.part then
            destroyESP(data.part, "NameEspRealFruit")
        end
    end
    
    RealFruitCache.Fruits = activeFruits
end

function Modules:UpdateFlowerESP()
    if not Config.Esp.Flowers.Enabled then
        for flower, data in pairs(FlowerCache.Flowers) do
            if data and data.part then
                destroyESP(data.part, "NameEspFlower")
            end
        end
        FlowerCache.Flowers = {}
        return
    end

    local currentTime = tick()
    if (currentTime - FlowerCache.LastUpdate) < FlowerCache.UpdateInterval then
        return
    end
    FlowerCache.LastUpdate = currentTime

    local char = getPlayerCharacter()
    if not char or not char:FindFirstChild("Head") then return end
    
    local charHeadPos = char.Head.Position
    local activeFlowers = {}
    
    -- Search in Workspace
    for _, obj in ipairs(Services.Workspace:GetChildren()) do
        if obj:IsA("Model") and (obj.Name == "Flower1" or obj.Name == "Flower2") then
            local part = obj:FindFirstChildWhichIsA("BasePart")
            if not part then continue end
            
            local dist = getDistance(charHeadPos, part.Position)
            if not isWithinMaxDistance(charHeadPos, part.Position) then continue end
            
            activeFlowers[obj] = true
            
            pcall(function()
                updateOrCreateESP(part, "NameEspFlower", function(label, isNew)
                    local distance = dist
                    local colorData = Config.Esp.Flowers.Colors[obj.Name]
                    
                    label.TextColor3 = colorData[1]
                    label.Text = colorData[2] .. "\n" .. distance .. "M"
                end)
            end)
        end
    end
    
    -- Cleanup
    for flower, data in pairs(FlowerCache.Flowers) do
        if not activeFlowers[flower] and data.part then
            destroyESP(data.part, "NameEspFlower")
        end
    end
    
    FlowerCache.Flowers = activeFlowers
end

function Modules:UpdateGearESP()
    if not Config.Esp.Gear.Enabled then
        for gear, data in pairs(GearCache.Gears) do
            if data and data.part then
                destroyESP(data.part, "NameEspGear")
            end
        end
        GearCache.Gears = {}
        return
    end

    local currentTime = tick()
    if (currentTime - GearCache.LastUpdate) < GearCache.UpdateInterval then
        return
    end
    GearCache.LastUpdate = currentTime

    local char = getPlayerCharacter()
    if not char or not char:FindFirstChild("Head") then return end
    
    local charHeadPos = char.Head.Position
    local activeGears = {}

    local mirageIsland = Services.Workspace.Map:FindFirstChild("MysticIsland")
    if not mirageIsland then return end
    
    -- Search in Workspace
    for _, obj in ipairs(mirageIsland:GetChildren()) do
        if v:IsA("MeshPart") and v.Material ==  Enum.Material.Neon then
            local part = obj:FindFirstChildWhichIsA("BasePart")
            if not part then continue end
            
            local dist = getDistance(charHeadPos, part.Position)
            if not isWithinMaxDistance(charHeadPos, part.Position) then continue end
            
            activeGears[obj] = true
            
            pcall(function()
                updateOrCreateESP(part, "NameEspGear", function(label, isNew)
                    local distance = dist
                    
                    label.TextColor3 = Config.Esp.Gear.Color
                    label.Text = obj.Name .. "\n" .. distance .. "M"
                end)
            end)
        end
    end
    
    -- Cleanup
    for gear, data in pairs(GearCache.Gears) do
        if not activeGears[gear] and data.part then
            destroyESP(data.part, "NameEspGear")
        end
    end
    
    GearCache.Gears = activeGears
end

function Modules:StartESP()
    if self.UpdateConnection then return end
    
    local updateCount = 0
    self.UpdateConnection = Services.RunService.Heartbeat:Connect(function(deltaTime)
        local startTime = tick()
        updateCount = updateCount + 1
        
        -- FPS tracking
        local fps = deltaTime > 0 and (1 / deltaTime) or 60
        
        -- Stagger updates across 10 frames
        local frame = updateCount % 10
        
        if frame == 0 then 
            local t = tick()
            self:UpdatePlayerESP()
        end
        
        if frame == 1 then 
            local t = tick()
            self:UpdateChestESP()
        end
        
        if frame == 2 then 
            local t = tick()
            self:UpdateBerryESP()
        end
        
        if frame == 3 then 
            local t = tick()
            self:UpdateDevilFruitESP()
        end
        
        if frame == 4 then 
            local t = tick()
            self:UpdateIslandESP()
        end
        
        if frame == 5 then 
            local t = tick()
            self:UpdateEventIslandESP()
        end
        
        if frame == 6 then 
            local t = tick()
            self:UpdateNPCESP()
        end
        
        if frame == 7 then 
            local t = tick()
            self:UpdateRealFruitESP()
        end
        
        if frame == 8 then 
            local t = tick()
            self:UpdateFlowerESP()
        end
        
        if frame == 9 then 
            local t = tick()
            self:UpdateGearESP()
        end
    end)
    
    print("✓ ESP Started")
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
        
        if category == "NPCs" and key == "Targets" then
            buildNPCTargetLookup()
        elseif category == "Islands" and key == "ExcludeList" then
            buildExcludeLookup()
        elseif category == "EventIslands" and key == "Islands" then
            buildEventIslandLookup()
        end
        
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
    if not tweenId then return nil end
    if not State.tweenStates then return nil end
    return State.tweenStates[tweenId]
end

function TweenStateManager:IsActive(tweenId)
    if not tweenId then return false end
    if not State.tweenStates then return false end
    local state = State.tweenStates[tweenId]
    return state and state.active or false
end

function TweenStateManager:Stop(tweenId, silent)
    if not tweenId then return end
    if not State.tweenStates then return end
    local state = State.tweenStates[tweenId]
    if not state then return end
    
    state.active = false
    if State.continuousTweens then
        State.continuousTweens[tweenId] = nil
    end
    
    if not silent and state.stopCallback then
        pcall(state.stopCallback)
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

function Modules:GetMobSpawnPoints(name, originPos)
    -- Validate input
    if type(name) ~= "string" or name == "" then return {} end
    if typeof(originPos) ~= "Vector3" then return {} end

    local worldOrigin = Services.Workspace:FindFirstChild("_WorldOrigin")
    if not worldOrigin then return {} end

    local enemySpawns = worldOrigin:FindFirstChild("EnemySpawns")
    if not enemySpawns then return {} end

    local spawns = {}
    local nearest = nil
    local nearestDist = math.huge

    for _, obj in ipairs(enemySpawns:GetChildren()) do
        if type(obj.Name) == "string" and string.find(obj.Name, name) then
            local part = nil

            -- Determine part for position reference
            if obj:IsA("BasePart") then
                part = obj
            elseif obj:IsA("Model") and obj.PrimaryPart then
                part = obj.PrimaryPart
            else
                part = obj:FindFirstChildWhichIsA("BasePart")
            end

            if part and part:IsA("BasePart") then
                local dist = (part.Position - originPos).Magnitude

                -- Track nearest spawn point
                if dist < nearestDist then
                    nearestDist = dist
                    nearest = {object = obj, part = part, dist = dist}
                end

                -- Add to full list
                table.insert(spawns, {object = obj, part = part, dist = dist})
            else
                warn("GetMobSpawnPoints: Could not find a BasePart for spawn '" .. obj.Name .. "'")
            end
        end
    end

    if not nearest then
        -- No spawn found matching name
        return {}
    end

    -- Move nearest to top of list
    for i, v in ipairs(spawns) do
        if v.object == nearest.object then
            table.remove(spawns, i)
            break
        end
    end
    table.insert(spawns, 1, nearest)

    return spawns
end

Modules.Hover = {
    _originalCollisions = {}
}
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
    State.hoverClip.MaxForce = Vector3.new(100000, 100000, 100000)
    State.hoverClip.Velocity = Vector3.new(0, 0, 0)
    State.hoverClip.P = 5000
    State.hoverClip.Parent = HRP
    
    return State.hoverClip
end

function Modules.Hover:IsHoverEnabled()
    if not Modules:ValidateReferences() then return false end
    if State.hoverClip and State.hoverClip.Parent == HRP then 
        return true
    end
    return false
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

local BoatPartCache = {}
function Modules:ManageBoatHover(boat, enabled)
    if not boat or not boat:FindFirstChild("VehicleSeat") then return end

    local vehicleSeat = boat.VehicleSeat
    local bv = vehicleSeat:FindFirstChild("boatHoverTweenVin")
    
    -- Initialize cache for this boat
    State.boatOriginalCollision[boat] = State.boatOriginalCollision[boat] or {}
    local cache = State.boatOriginalCollision[boat]
    
    if enabled then
        -- Create BodyVelocity if needed
        if not bv then
            bv = Instance.new("BodyVelocity")
            bv.Name = "boatHoverTweenVin"
            bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            bv.Velocity = Vector3.new(0, 0, 0)
            bv.Parent = vehicleSeat
            State.boatHoverClips[boat] = bv
        end
        
        -- Get or cache boat parts
        local parts = BoatPartCache[boat]
        if not parts then
            parts = {}
            for _, part in pairs(boat:GetDescendants()) do
                if part:IsA("BasePart") then
                    table.insert(parts, part)
                end
            end
            BoatPartCache[boat] = parts
        end
        
        -- Disable collision (faster iteration)
        for _, part in ipairs(parts) do
            if part and part.Parent then
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
        
        -- Restore collision from cache
        for part, original in pairs(cache) do
            if part and part.Parent and part:IsA("BasePart") then
                part.CanCollide = original
            end
        end
        
        -- Cleanup
        State.boatOriginalCollision[boat] = nil
        BoatPartCache[boat] = nil
    end
end

Services.RunService.Heartbeat:Connect(function()
    if not State.isTweening and not Modules.CheckInMyBoat() then
        -- Cleanup all boat hovers when not needed
        for boat, bv in pairs(State.boatHoverClips) do
            Modules:ManageBoatHover(boat, false)
        end
        return
    end
    
    -- Update active boat hover
    local myBoat = Modules.CheckMyBoat()
    if myBoat and State.boatHoverClips[myBoat] then
        local bv = State.boatHoverClips[myBoat]
        if bv and bv.Parent then
            bv.Velocity = Vector3.new(0, 0, 0)
        end
    end
end)

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

local boatHoverConnection
local function startBoatHoverMonitor()
    if boatHoverConnection then return end
    
    boatHoverConnection = Services.RunService.Heartbeat:Connect(function()
        if not State.isTweening and not Modules.CheckInMyBoat() then
            -- Stop monitoring if not needed
            if boatHoverConnection then
                boatHoverConnection:Disconnect()
                boatHoverConnection = nil
            end
            
            -- Clean up all boat hovers
            for boat, _ in pairs(State.boatHoverClips) do
                Modules:ManageBoatHover(boat, false)
            end
            return
        end
        
        local myBoat = Modules.CheckMyBoat()
        if myBoat then
            Modules:ManageBoatHover(myBoat, true)
        end
    end)
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
    
    -- Normalize options
    if type(options) == "boolean" then
        options = {stopOnToggle = options}
    elseif type(options) ~= "table" then
        options = {}
    end
    
    local tweenId = "tween_" .. tostring(tick()):gsub("%.", "_")
    
    -- Create tween state with cleanup tracking
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
    startBoatHoverMonitor()

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
    
    -- Unified connection management
    local connections = {}
    local cleanupPerformed = false
    
    local function performCleanup()
        if cleanupPerformed then return end
        cleanupPerformed = true
        
        -- Disconnect all connections
        for _, conn in ipairs(connections) do
            if conn and conn.Connected then
                conn:Disconnect()
            end
        end
        connections = {}
        
        -- Stop tween
        if State.currentTween and State.currentTween.PlaybackState == Enum.PlaybackState.Playing then
            pcall(function() State.currentTween:Cancel() end)
        end
        
        -- Reset velocity
        if Modules:ValidateReferences() then
            pcall(function()
                HRP.AssemblyLinearVelocity = Vector3.zero
                HRP.AssemblyAngularVelocity = Vector3.zero
            end)
        end
        
        -- Remove from active tweens
        for i = #State.activeTweens, 1, -1 do
            if State.activeTweens[i] == State.currentTween then
                table.remove(State.activeTweens, i)
            end
        end
    end
    
    -- Velocity control with proper limits
    local velocityControl = Services.RunService.Heartbeat:Connect(function()
        if not State.isTweening or not Modules:ValidateReferences() then 
            performCleanup()
            return 
        end
        
        local currentVelocity = HRP.AssemblyLinearVelocity
        local velMag = currentVelocity.Magnitude
        
        if velMag > Config.Safety.maxVelocityMagnitude then
            HRP.AssemblyLinearVelocity = currentVelocity.Unit * Config.Safety.maxVelocityMagnitude
        end
    end)
    table.insert(connections, velocityControl)

    -- Monitor task with better exit conditions
    local monitorTask = task.spawn(function()
        local lastCheck = tick()
        local CHECK_INTERVAL = Config.Performance.updateInterval
        
        while State.isTweening and TweenStateManager:IsActive(tweenId) do
            if not State.tweenStates or not State.tweenStates[tweenId] then
                break
            end

            local now = tick()
            
            -- Throttle checks
            if (now - lastCheck) < CHECK_INTERVAL then
                task.wait(CHECK_INTERVAL)
                continue
            end
            lastCheck = now
            
            -- Stop conditions
            if options.stopOnToggle and not TweenStateManager:IsActive(tweenId) then
                State.isTweening = false
                break
            end

            if not Modules:ValidateReferences() then
                State.isTweening = false
                performCleanup()
                break
            end
            
            -- Loop detection (only for continuous)
            if (options.continuous or options.loopMode) and Modules:ValidateReferences() then
                local isLoop = LoopDetector:Track(HRP.Position)
                if isLoop then
                    LoopDetector:RegisterLoop(tweenId)
                end
            end
            
            task.wait(CHECK_INTERVAL)
        end
    end)

    -- Create and play tween
    local tweenInfo = self:CalculateTweenInfo(dist)
    local portal = Modules.Portal:GetClosest(targetCFrame)
    
    if portal and CommF_ then
        self:HandlePortalTeleport(portal, targetCFrame, tweenInfo)
    else
        State.currentTween = Services.TweenService:Create(HRP, tweenInfo, {CFrame = targetCFrame})
        State.currentTween:Play()
        table.insert(State.activeTweens, State.currentTween)
    end

    -- Control object with proper cleanup
    local tweenControl = {}
    function tweenControl:Stop()
        TweenStateManager:Stop(tweenId)
        State.isTweening = false
        performCleanup()
        Modules.Hover:SetNoClip(false)
        LoopDetector:UnregisterLoop(tweenId)
        
        if monitorTask then
            task.cancel(monitorTask)
        end
    end
    
    function tweenControl:GetState()
        return TweenStateManager:Get(tweenId)
    end
    
    function tweenControl:IsActive()
        return TweenStateManager:IsActive(tweenId)
    end

    -- Wait for completion with timeout
    if State.currentTween then
        local startTime = tick()
        local maxDuration = (dist / Modules:GetTweenSpeed()) + 5 -- 5 second buffer
        
        local success = pcall(function()
            while State.currentTween.PlaybackState == Enum.PlaybackState.Playing do
                if (tick() - startTime) > maxDuration then
                    warn("⚠️ Tween timeout reached")
                    break
                end
                task.wait(0.1)
            end
        end)
        
        if success and tweenState.completeCallback then
            task.spawn(tweenState.completeCallback)
        end
        
        -- Final position snap
        if Modules:ValidateReferences() then
            task.wait(0.1)
            HRP.CFrame = targetCFrame
            HRP.AssemblyLinearVelocity = Vector3.zero
            HRP.AssemblyAngularVelocity = Vector3.zero
        end
    end

    performCleanup()
    
    -- Only stop if not continuous
    if not TweenStateManager:ShouldContinue(tweenId) then
        State.isTweening = false
        LoopDetector:UnregisterLoop(tweenId)
    end
    
    TweenStateManager:Cleanup(tweenId)
    return tweenControl
end

function Modules.Tween:HandlePortalTeleport(portal, targetCFrame, tweenInfo)
    local templePos = Vector3.new(28282.5703125, 14896.8505859375, 105.1042709350586)
    
    -- Helper function for waiting with validation
    local function smartWait(duration, validateFunc)
        local startTime = tick()
        while (tick() - startTime) < duration do
            if validateFunc and not validateFunc() then
                return false -- Abort if validation fails
            end
            task.wait(0.1)
        end
        return true
    end
    
    -- Temple of Time
    if (portal - templePos).Magnitude < 10 then
        local mapStash = Services.ReplicatedStorage:WaitForChild("MapStash", 3)
        local temple = mapStash and mapStash:FindFirstChild("Temple of Time")
        
        if temple and not Services.Workspace:FindFirstChild("Temple of Time") then
            temple.Parent = Services.Workspace:WaitForChild("Map", 3)
        end
        
        -- Reduced timeout with smarter checking
        local attempts = 0
        while not Services.Workspace:FindFirstChild("Temple of Time") and attempts < 20 do
            task.wait(0.05) -- Faster polling
            attempts = attempts + 1
        end
        
        if Services.Workspace:FindFirstChild("Temple of Time") and (templePos - HRP.Position).Magnitude > 1000 then
            CommF_:InvokeServer("requestEntrance", templePos)
            smartWait(0.5, function() return Modules:ValidateReferences() end) -- Reduced from 1s
        end
    
    -- Great Tree
    elseif (portal - Vector3.new(3028.209228515625, 2280.84619140625, -7324.2880859375)).Magnitude < 10 then
        if (templePos - HRP.Position).Magnitude > 1000 then
            CommF_:InvokeServer("requestEntrance", templePos)
            smartWait(0.5, function() return Modules:ValidateReferences() end)
        end

        HRP.CFrame = CFrame.new(28609.650390625, 14896.5458984375, 105.68901062011719)
        smartWait(0.3, function() return Modules:ValidateReferences() end) -- Reduced from 0.5s

        if Modules:ValidateReferences() and (HRP.Position - Vector3.new(28609.6504, 14896.5459, 105.6890)).Magnitude <= 20 then
            CommF_:InvokeServer("RaceV4Progress", "TeleportBack")
            smartWait(0.5, function() return Modules:ValidateReferences() end)
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
                smartWait(0.3, function() return Modules:ValidateReferences() end)
            end
        end
    
    -- Submerged Island
    elseif (portal - Vector3.new(10213.701171875, -1733.5025634765625, 9940.189453125)).Magnitude < 10 then
        local castlePos = Vector3.new(-5058.7749, 314.5155, -3155.8833)
        local submarinePos = Vector3.new(-16269.408203125, 23.979995727539062, 1371.662353515625)

        if (submarinePos - HRP.Position).Magnitude > 1205 then
            CommF_:InvokeServer("requestEntrance", castlePos)
            smartWait(0.5, function() return Modules:ValidateReferences() end)

            if Modules:ValidateReferences() then
                HRP.CFrame = CFrame.new(-5097.1318359375, 318.50201416015625, -3178.3984375)
                smartWait(0.3, function() return Modules:ValidateReferences() end)
            end
        end
        
        local subDist = (submarinePos - HRP.Position).Magnitude
        local subTweenInfo = self:CalculateTweenInfo(subDist)
        
        State.currentTween = Services.TweenService:Create(HRP, subTweenInfo, {CFrame = CFrame.new(submarinePos)})
        State.currentTween:Play()
        
        -- Non-blocking wait
        local connection
        connection = State.currentTween.Completed:Connect(function()
            connection:Disconnect()
        end)
        State.currentTween.Completed:Wait()

        smartWait(0.3, function() return Modules:ValidateReferences() end)

        if Modules:ValidateReferences() and (submarinePos - HRP.Position).Magnitude <= 15 then
            local rep = Services.ReplicatedStorage
            local modules = rep:FindFirstChild("Modules")
            local net = modules and modules:FindFirstChild("Net")
            local rf = net and net:FindFirstChild("RF/SubmarineWorkerSpeak")
            
            self:StopAll(true)
            if rf then
                rf:InvokeServer("TravelToSubmergedIsland")
                smartWait(1.0, function() return Modules:ValidateReferences() end) -- This one needs to be longer
            end
        end
    
    -- Tiki Outpost
    elseif (portal - Vector3.new(-16799.091796875, 84.32279968261719, 291.0728454589844)).Magnitude < 10 then
        local castlePos = Vector3.new(-5058.7749, 314.5155, -3155.8833)
        local tikiPos = Vector3.new(-16799.091796875, 84.32279968261719, 291.0728454589844)
        local tikiWaypoint = Vector3.new(-5097.1318359375, 318.50201416015625, -3178.3984375)
        
        if (tikiPos - HRP.Position).Magnitude > 2000 then
            CommF_:InvokeServer("requestEntrance", castlePos)
            smartWait(0.5, function() return Modules:ValidateReferences() end)

            if Modules:ValidateReferences() then
                HRP.CFrame = CFrame.new(tikiWaypoint)
                smartWait(0.3, function() return Modules:ValidateReferences() end)
            end
        elseif (castlePos - HRP.Position).Magnitude < 750 then
            if (tikiWaypoint - HRP.Position).Magnitude < 100 then
                if Modules:ValidateReferences() then
                    if State.isTweening then
                        self:StopAll(true)
                    end
                    HRP.CFrame = CFrame.new(tikiWaypoint)
                    smartWait(0.3, function() return Modules:ValidateReferences() end)
                end
            else
                local dist = (tikiWaypoint - HRP.Position).Magnitude
                local tweenInfo = self:CalculateTweenInfo(dist)
            
                State.currentTween = Services.TweenService:Create(HRP, tweenInfo, {CFrame = CFrame.new(tikiWaypoint)})
                State.currentTween:Play()
                State.currentTween.Completed:Wait()
            end
        end

        smartWait(0.3, function() return Modules:ValidateReferences() end)
    
    -- Generic portal
    else
        CommF_:InvokeServer("requestEntrance", portal)
        smartWait(0.5, function() return Modules:ValidateReferences() end)
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
    
    -- Start monitoring if needed
    startBoatHoverMonitor()

    -- Manage hover (default enabled)
    if autoManage ~= false then
        Modules:ManageBoatHover(myShip, true)
    end

    -- Calculate distance and tween info
    local dist = (targetCFrame.Position - vehicleSeat.Position).Magnitude
    local boatSpeed = Modules:GetBoatSpeed()
    local tweenInfo = self:CalculateTweenInfo(dist, boatSpeed)

    -- Create tween
    local tween = Services.TweenService:Create(vehicleSeat, tweenInfo, {CFrame = targetCFrame})
    tween:Play()
    
    table.insert(State.activeTweens, tween)
    
    -- Control object
    local boatControl = {
        tween = tween,
        ship = myShip,
        autoManage = autoManage,
        completed = false
    }
    
    function boatControl:Stop()
        if self.completed then return end
        self.completed = true
        
        -- Cancel tween
        if self.tween and self.tween.PlaybackState == Enum.PlaybackState.Playing then
            pcall(function() self.tween:Cancel() end)
        end
        
        -- Remove from active list
        for i = #State.activeTweens, 1, -1 do
            if State.activeTweens[i] == self.tween then
                table.remove(State.activeTweens, i)
                break
            end
        end
        
        -- Disable hover
        if self.autoManage ~= false and self.ship then
            Modules:ManageBoatHover(self.ship, false)
        end
    end
    
    -- Auto-cleanup on completion
    tween.Completed:Connect(function()
        if boatControl.completed then return end
        boatControl.completed = true
        
        -- Disable hover
        if autoManage ~= false then
            Modules:ManageBoatHover(myShip, false)
        end
        
        -- Remove from active list
        for i = #State.activeTweens, 1, -1 do
            if State.activeTweens[i] == tween then
                table.remove(State.activeTweens, i)
                break
            end
        end
    end)
    
    return boatControl
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

local deathConnection
local function setupDeathHandler()
    if deathConnection then
        deathConnection:Disconnect()
    end
    
    if Humanoid then
        deathConnection = Humanoid.Died:Connect(function()
            if Config.Safety.autoStopOnDeath then
                Modules.Tween:StopAll(true)
            end
        end)
    end
end

-- Initialization
local function InitializeReferences()
    local success, err = Modules:SafePcall(function()
        -- Wait for character with timeout
        local waitStart = tick()
        while not Player.Character and (tick() - waitStart) < 10 do
            task.wait(0.1)
        end
        
        if not Player.Character then
            error("Character not found after 10 seconds")
        end
        
        Character = Player.Character
        
        -- Wait for essential components
        HRP = Character:WaitForChild("HumanoidRootPart", 10)
        Humanoid = Character:WaitForChild("Humanoid", 10)
        
        if not HRP or not Humanoid then
            error("Essential character components not found")
        end
        
        -- Validate health
        if Humanoid.Health <= 0 then
            error("Character is dead on initialization")
        end
    end)

    if not success then
        warn("⚠️ Initialization failed:", err)
        return false
    end
    
    return true
end

function Modules:Initialize()
    if State.isInitialized then  return true end
    if not InitializeReferences() then return false end

    State.isInitialized = true
    setupDeathHandler()

    _G.ModulesInitialized = true
    _G.ModulesVersion = Modules.Version
    return true
end

-- Character respawn handling
Player.CharacterAdded:Connect(function(newChar)
    -- Stop all active processes
    State.isInitialized = false
    State.isTweening = false
    
    -- Clear tween state
    State.activeTweens = {}
    State.tweenQueue = {}
    State.tweenStates = {}
    State.continuousTweens = {}
    State.currentTween = nil
    
    -- Clear validation cache
    State.validationCache = false
    State.lastValidation = 0
    
    -- Clear performance metrics
    State.performance = {
        tweenCount = 0,
        avgTweenTime = 0,
        lastFrameTime = tick()
    }
    
    ESPCache.Players = {}
    ChestCache.Chests = {}
    BerryCache.Bushes = {}
    BerryCache.AttributeCache = {}
    FruitCache.Fruits = {}
    FruitCache.NameCache = {}
    IslandCache.Islands = {}
    NPCCache.TrackedNPCs = {}
    RealFruitCache.Fruits = {}
    FlowerCache.Flowers = {}
    GearCache.Gears = {}
    
    -- Clear boat caches
    State.boatOriginalCollision = {}
    State.boatHoverClips = {}
    BoatPartCache = {}
    
    -- Stop all tweens
    TweenStateManager:StopAll()
    LoopDetector:Clear()
    
    -- Remove hover
    Modules.Hover:Remove()
    
    -- Update character reference
    Character = newChar
    
    -- Wait for character to load
    task.wait(0.5)
    
    -- Re-initialize
    if not Modules:Initialize() then
        task.wait(0.5)
        Modules:Initialize()
    end
    
    print("✓ Character respawned, all systems reinitialized")
end)

function Modules:InitSaveManager(mango)
    _G.SaveManagerInstance = mango
    if not mango then warn("[SaveManager] Save mode is currently not working, the modules may not save settings anymore.") end
    return mango
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
    if not State.isInitialized then return end
    Modules.Tween:StopAll(stopMovement)
end

function Modules:IsTweening()
    return State.isInitialized and (State.isTweening or TweenStateManager:HasContinuousTweens())
end

function Modules:WaitForTweenEnd()
    if not State.isInitialized then return false end
    while self:IsTweening() do
        task.wait()
    end
    return true
end

function Modules:GetTweenStates()
    return State.tweenStates
end

function Modules:IsInLoop()
    return LoopDetector:IsInLoop()
end

local StuckDetector = {
    enabled = Config.Safety.preventStuck,
    lastPosition = nil,
    stuckTime = 0,
    stuckThreshold = 1.5, -- Seconds before considering stuck
    movementThreshold = 2, -- Studs moved to not be stuck
    unstuckAttempts = 0,
    maxUnstuckAttempts = 3,
    lastUnstuckTime = 0,
    unstuckCooldown = 5 -- Seconds between unstuck attempts
}

function StuckDetector:Check()
    if not self.enabled or not State.isTweening or not Modules:ValidateReferences() then
        self:Reset()
        return
    end
    
    local currentPos = HRP.Position
    local now = tick()
    
    if self.lastPosition then
        local moved = (currentPos - self.lastPosition).Magnitude
        
        if moved < self.movementThreshold then
            self.stuckTime = self.stuckTime + (1/60) -- Heartbeat delta
            
            if self.stuckTime > self.stuckThreshold then
                -- Check cooldown
                if (now - self.lastUnstuckTime) > self.unstuckCooldown then
                    self:Unstuck()
                end
            end
        else
            -- Moving normally, reset
            self.stuckTime = 0
            self.unstuckAttempts = 0
        end
    end
    
    self.lastPosition = currentPos
end

function StuckDetector:Unstuck()
    if self.unstuckAttempts >= self.maxUnstuckAttempts then
        warn("⚠️ Maximum unstuck attempts reached, stopping tween")
        Modules.Tween:StopAll(true)
        self:Reset()
        return
    end
    
    self.unstuckAttempts = self.unstuckAttempts + 1
    self.lastUnstuckTime = tick()
    
    local methods = {
        -- Method 1: Jump up and forward
        function()
            local lookVector = HRP.CFrame.LookVector
            HRP.CFrame = HRP.CFrame + Vector3.new(0, 10, 0) + (lookVector * 15)
        end,
        
        -- Method 2: Teleport to the side
        function()
            local rightVector = HRP.CFrame.RightVector
            HRP.CFrame = HRP.CFrame + (rightVector * 20)
        end,
        
        -- Method 3: Teleport high up
        function()
            HRP.CFrame = HRP.CFrame + Vector3.new(0, 50, 0)
        end
    }
    
    -- Use different method each attempt
    local method = methods[self.unstuckAttempts] or methods[1]
    pcall(method)
    
    print(string.format("⚠️ Stuck detected, applying unstuck method %d", self.unstuckAttempts))
    
    self.stuckTime = 0
end

function StuckDetector:Reset()
    self.lastPosition = nil
    self.stuckTime = 0
    self.unstuckAttempts = 0
end

-- Integrate into heartbeat
local stuckCheckConnection
if Config.Safety.preventStuck then
    stuckCheckConnection = Services.RunService.Heartbeat:Connect(function()
        StuckDetector:Check()
    end)
end

-- Configuration management
function Modules:UpdateConfig(newConfig)
    if type(newConfig) ~= "table" then return end

    for key, value in pairs(newConfig) do
        if key == "Tween" and type(value) == "table" then
            for k, v in pairs(value) do
                Config.Tween[k] = v
            end
        elseif key == "Performance" and type(value) == "table" then
            for k, v in pairs(value) do
                Config.Performance[k] = v
            end
        elseif key == "Safety" and type(value) == "table" then
            for k, v in pairs(value) do
                Config.Safety[k] = v
            end
        elseif Config[key] ~= nil then
            Config[key] = value
        end
    end
end

function Modules:GetConfig(key)
    if key then
        if Config.Tween[key] then
            return Config.Tween[key]
        elseif Config.Performance[key] then
            return Config.Performance[key]
        elseif Config.Safety[key] then
            return Config.Safety[key]
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

local function AutoInitialize()
    local maxRetries = 3
    local retryDelay = 1
    
    for attempt = 1, maxRetries do
        if Modules:Initialize() then
            return true
        end
        
        if attempt < maxRetries then
            warn(string.format("⚠️ Initialization attempt %d/%d failed, retrying in %ds...", 
                attempt, maxRetries, retryDelay))
            task.wait(retryDelay)
        end
    end
    
    warn("❌ Failed to initialize after", maxRetries, "attempts")
    return false
end

-- Start initialization
AutoInitialize()
print("✓ Modules v" .. Modules.Version .. " initialized successfully")

-- Global access
_G.Modules = Modules
return Modules