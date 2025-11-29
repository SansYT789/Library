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
    Performance = {
        updateInterval = 0.1,
        validationCacheTime = 0.5,
        maxConcurrentTweens = 3,
        useAdaptiveQuality = true
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
    isInitialized = false,
    lastValidation = 0,
    validationCache = true,
    performance = {
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
    Character = newChar
    task.wait(0.5)

    if not Modules:Initialize() then
        task.wait(0.5)
        Modules:Initialize()
    end
end)

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