--[[
    Enhanced ESP Library v2.0
    Optimized performance with caching, debouncing, and efficient rendering
    Modular configuration system for easy management
]]

local ESPLibrary = {}
ESPLibrary.__index = ESPLibrary

-- Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

-- Configuration v2
local Config = {
    General = {
        UpdateRate = 0.5, -- Update ESP every 0.5 seconds
        MaxRenderDistance = 5000, -- Maximum distance to render ESP
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
        FilterList = {}, -- Empty = show all, or specify: {"Blue Icicle Berry", "Red Cherry Berry"}
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

-- Cache system for improved performance
local Cache = {
    ESPObjects = {},
    LastUpdate = 0,
    PlayerCharacters = {},
}

-- Utility Functions
local function round(n)
    return math.floor(tonumber(n) + 0.5)
end

local function getDistance(pos1, pos2)
    return round((pos1 - pos2).Magnitude / 3)
end

local function isWithinRenderDistance(pos1, pos2)
    return (pos1 - pos2).Magnitude <= Config.General.MaxRenderDistance
end

local function getPlayerCharacter()
    local player = Players.LocalPlayer
    return player and player.Character
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
    label.Font = Config.General.Font
    label.FontSize = Config.General.FontSize
    label.TextWrapped = true
    label.Size = UDim2.new(1, 0, 1, 0)
    label.TextYAlignment = 'Top'
    label.BackgroundTransparency = 1
    label.TextStrokeTransparency = Config.General.StrokeTransparency
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

-- Player ESP System
function ESPLibrary:UpdatePlayerESP()
    if not Config.Players.Enabled then
        for player, _ in pairs(Cache.PlayerCharacters) do
            local char = Cache.PlayerCharacters[player]
            if char and char:FindFirstChild("Head") then
                destroyESP(char.Head, "NameEspPlayer")
            end
        end
        Cache.PlayerCharacters = {}
        return
    end
    
    local localPlayer = Players.LocalPlayer
    local char = getPlayerCharacter()
    if not char or not char:FindFirstChild("Head") then return end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player == localPlayer then continue end
        
        pcall(function()
            local targetChar = player.Character or Workspace.Characters:FindFirstChild(player.Name)
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
                if Config.Players.ShowDistance then
                    text = text .. " | " .. distance .. "M"
                end
                
                if Config.Players.ShowHealth then
                    text = text .. "\nHealth: " .. health .. "%"
                end
                
                if Config.Players.TeamCheck and player.Team ~= localPlayer.Team then
                    if Config.Players.ShowKen then
                        local kenActive = player:GetAttribute("KenActive") and "Ken: ON" or "Ken: OFF"
                        local dodgeLeft = player:GetAttribute("KenDodgesLeft") or 0
                        text = text .. "\n" .. kenActive .. " | Dodge: " .. dodgeLeft
                    end
                    
                    if Config.Players.ShowV4 then
                        local v4Active = (targetChar:FindFirstChild("RaceTransformed") and targetChar.RaceTransformed.Value) and "V4: ON" or "V4: OFF"
                        local v4Ready = (targetChar:FindFirstChild("RaceEnergy") and targetChar.RaceEnergy.Value == 1) and "Ready" or "Not Ready"
                        text = text .. "\n" .. v4Active .. " | " .. v4Ready
                    end
                    
                    label.TextColor3 = Config.Players.EnemyColor
                else
                    label.TextColor3 = Config.Players.TeamColor
                end
                
                label.Text = text
            end)
        end)
    end
end

-- Chest ESP System
function ESPLibrary:UpdateChestESP()
    if not Config.Chests.Enabled then return end
    
    local char = getPlayerCharacter()
    if not char or not char:FindFirstChild("Head") then return end
    
    local chests = CollectionService:GetTagged("_ChestTagged")
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
                local chestType = chest.Name:match("Diamond") and "Diamond" or
                                 chest.Name:match("Gold") and "Gold" or
                                 chest.Name:match("Silver") and "Silver" or "Default"
                
                label.TextColor3 = Config.Chests.Colors[chestType]
                label.Text = chest.Name:gsub("Label", "") .. "\n" .. distance .. "M"
            end)
        end)
    end
end

-- Berry ESP System (Optimized)
function ESPLibrary:UpdateBerryESP()
    if not Config.Berries.Enabled then return end
    
    local char = getPlayerCharacter()
    if not char or not char:FindFirstChild("Head") then return end
    
    local berryBushes = CollectionService:GetTagged("BerryBush")
    for _, bush in ipairs(berryBushes) do
        pcall(function()
            local bushModel = bush.Parent
            if not bushModel or not bushModel:IsA("Model") then return end
            
            local berriesFolder = bushModel:FindFirstChild("Berries")
            if not berriesFolder or #berriesFolder:GetChildren() == 0 then
                destroyESP(bush, "NameEspBerry")
                return
            end
            
            -- Find berry name from attributes
            local berryName = nil
            for key, value in pairs(bush:GetAttributes()) do
                if Config.Berries.Colors[key] then
                    berryName = key
                    break
                elseif Config.Berries.Colors[value] then
                    berryName = value
                    break
                end
            end
            
            if not berryName then
                destroyESP(bush, "NameEspBerry")
                return
            end
            
            -- Check filter list
            if #Config.Berries.FilterList > 0 and not table.find(Config.Berries.FilterList, berryName) then
                destroyESP(bush, "NameEspBerry")
                return
            end
            
            local firstBerry = berriesFolder:GetChildren()[1]
            local espTarget = firstBerry:IsA("BasePart") and firstBerry or firstBerry:FindFirstChildWhichIsA("BasePart")
            
            if not espTarget then
                destroyESP(bush, "NameEspBerry")
                return
            end
            
            if not isWithinRenderDistance(char.Head.Position, espTarget.Position) then
                destroyESP(bush, "NameEspBerry")
                return
            end
            
            updateOrCreateESP(espTarget, "NameEspBerry", function(label, isNew)
                local distance = getDistance(char.Head.Position, espTarget.Position)
                local colorData = Config.Berries.Colors[berryName]
                
                label.TextColor3 = colorData[1]
                label.Text = string.format("[%s]\n%dM", colorData[2], distance)
            end)
        end)
    end
end

-- Devil Fruit ESP System
function ESPLibrary:UpdateDevilFruitESP()
    if not Config.DevilFruits.Enabled then return end
    
    local char = getPlayerCharacter()
    if not char or not char:FindFirstChild("Head") then return end
    
    for _, v in ipairs(Workspace:GetChildren()) do
        pcall(function()
            if not v.Name:find("Fruit") or not v:FindFirstChild("Handle") then return end
            
            local handle = v.Handle
            
            if not isWithinRenderDistance(char.Head.Position, handle.Position) then
                destroyESP(handle, "NameEspFruit")
                return
            end
            
            updateOrCreateESP(handle, "NameEspFruit", function(label, isNew)
                local distance = getDistance(char.Head.Position, handle.Position)
                label.TextColor3 = Config.DevilFruits.Color
                label.Text = v.Name .. "\n" .. distance .. "M"
            end)
        end)
    end
end

-- Island ESP System
function ESPLibrary:UpdateIslandESP()
    if not Config.Islands.Enabled then return end
    
    local char = getPlayerCharacter()
    if not char or not char:FindFirstChild("Head") then return end
    
    local locations = Workspace:FindFirstChild("_WorldOrigin")
    if not locations then return end
    locations = locations:FindFirstChild("Locations")
    if not locations then return end
    
    for _, island in ipairs(locations:GetChildren()) do
        pcall(function()
            if table.find(Config.Islands.ExcludeList, island.Name) then return end
            
            updateOrCreateESP(island, "NameEspIsland", function(label, isNew)
                local distance = getDistance(char.Head.Position, island.Position)
                label.TextColor3 = Config.Islands.Color
                label.Text = island.Name .. "\n" .. distance .. "M"
            end)
        end)
    end
end

-- Event Island ESP System
function ESPLibrary:UpdateEventIslandESP()
    if not Config.EventIslands.Enabled then return end
    
    local char = getPlayerCharacter()
    if not char or not char:FindFirstChild("Head") then return end
    
    local locations = Workspace:FindFirstChild("_WorldOrigin")
    if not locations then return end
    locations = locations:FindFirstChild("Locations")
    if not locations then return end
    
    for islandName, color in pairs(Config.EventIslands.Islands) do
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

-- NPC ESP System
function ESPLibrary:UpdateNPCESP()
    if not Config.NPCs.Enabled then return end
    
    local char = getPlayerCharacter()
    if not char or not char:FindFirstChild("Head") then return end
    
    local npcs = Workspace:FindFirstChild("NPCs")
    if not npcs then return end
    
    for _, npcName in ipairs(Config.NPCs.Targets) do
        for _, npc in ipairs(npcs:GetChildren()) do
            pcall(function()
                if npc.Name ~= npcName then return end
                
                if not isWithinRenderDistance(char.Head.Position, npc.Position) then
                    destroyESP(npc, "NameEspNPC")
                    return
                end
                
                updateOrCreateESP(npc, "NameEspNPC", function(label, isNew)
                    local distance = getDistance(char.Head.Position, npc.Position)
                    label.TextColor3 = Config.NPCs.Color
                    label.Text = npc.Name .. "\n" .. distance .. "M"
                end)
            end)
        end
    end
end

-- Main Update Loop with Debouncing
function ESPLibrary:StartUpdateLoop()
    if self.UpdateConnection then return end
    
    self.UpdateConnection = RunService.Heartbeat:Connect(function()
        local currentTime = tick()
        if currentTime - Cache.LastUpdate < Config.General.UpdateRate then return end
        Cache.LastUpdate = currentTime
        
        self:UpdatePlayerESP()
        self:UpdateChestESP()
        self:UpdateBerryESP()
        self:UpdateDevilFruitESP()
        self:UpdateIslandESP()
        self:UpdateEventIslandESP()
        self:UpdateNPCESP()
    end)
end

function ESPLibrary:StopUpdateLoop()
    if self.UpdateConnection then
        self.UpdateConnection:Disconnect()
        self.UpdateConnection = nil
    end
end

-- Configuration Management
function ESPLibrary:SetConfig(category, key, value)
    if Config[category] and Config[category][key] ~= nil then
        Config[category][key] = value
        return true
    end
    return false
end

function ESPLibrary:GetConfig(category, key)
    if Config[category] then
        return key and Config[category][key] or Config[category]
    end
    return nil
end

function ESPLibrary:EnableCategory(category)
    if Config[category] then
        Config[category].Enabled = true
    end
end

function ESPLibrary:DisableCategory(category)
    if Config[category] then
        Config[category].Enabled = false
    end
end

function ESPLibrary:ClearAllESP()
    for parent, data in pairs(Cache.ESPObjects) do
        if data.billboard then
            data.billboard:Destroy()
        end
    end
    Cache.ESPObjects = {}
end

-- Initialize
function ESPLibrary:Init()
    self:StartUpdateLoop()
    print("ESP Library Initialized")
end

function ESPLibrary:Destroy()
    self:StopUpdateLoop()
    self:ClearAllESP()
    print("ESP Library Destroyed")
end

return ESPLibrary