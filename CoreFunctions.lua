-- GG-Functions.lua
-- Complete Functions for Grow A Garden Script Loader

local Functions = {}

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local player = Players.LocalPlayer

-- Configuration
local shovelName = "Shovel [Destroy Plants]"
local sprinklerTypes = {
    "Basic Sprinkler",
    "Advanced Sprinkler",
    "Master Sprinkler",
    "Godly Sprinkler",
    "Honey Sprinkler",
    "Chocolate Sprinkler"
}
local selectedSprinklers = {}

local zenItems = {
    "Zen Seed Pack",
    "Zen Egg",
    "Hot Spring",
    "Zen Flare",
    "Zen Crate",
    "Soft Sunshine",
    "Koi",
    "Zen Gnome Crate",
    "Spiked Mango",
    "Pet Shard Tranquil",
    "Zen Sand"
}

local merchantItems = {
    "Star Caller",
    "Night Staff",
    "Bee Egg",
    "Honey Sprinkler",
    "Flower Seed Pack",
    "Cloudtouched Spray",
    "Mutation Spray Disco",
    "Mutation Spray Verdant",
    "Mutation Spray Windstruck",
    "Mutation Spray Wet"
}

-- Pet Control Variables
local selectedPets = {}
local excludedPets = {}
local excludedPetESPs = {}
local allPetsSelected = false
local petsFolder = nil
local currentPetsList = {}

-- Auto-buy states
local autoBuyZenEnabled = false
local autoBuyMerchantEnabled = false
local zenBuyConnection = nil
local merchantBuyConnection = nil

-- Remote Events with error handling
local function getRemoteEvent(path)
    local success, result = pcall(function()
        return ReplicatedStorage:WaitForChild(path, 5)
    end)
    return success and result or nil
end

local BuyEventShopStock = getRemoteEvent("GameEvents") and getRemoteEvent("GameEvents").BuyEventShopStock
local BuyTravelingMerchantShopStock = getRemoteEvent("GameEvents") and getRemoteEvent("GameEvents").BuyTravelingMerchantShopStock
local DeleteObject = getRemoteEvent("GameEvents") and getRemoteEvent("GameEvents").DeleteObject
local RemoveItem = getRemoteEvent("GameEvents") and getRemoteEvent("GameEvents").Remove_Item
local ActivePetService = getRemoteEvent("GameEvents") and getRemoteEvent("GameEvents").ActivePetService
local PetZoneAbility = getRemoteEvent("GameEvents") and getRemoteEvent("GameEvents").PetZoneAbility

-- Core folders/scripts with error handling
local shovelClient = nil
local shovelPrompt = nil
local objectsFolder = nil

-- Initialize core objects safely
pcall(function()
    shovelClient = player:WaitForChild("PlayerScripts", 5):WaitForChild("Shovel_Client", 5)
end)

pcall(function()
    shovelPrompt = player:WaitForChild("PlayerGui", 5):WaitForChild("ShovelPrompt", 5)
end)

pcall(function()
    objectsFolder = Workspace:WaitForChild("Farm", 5):WaitForChild("Farm", 5):WaitForChild("Important", 5):WaitForChild("Objects_Physical", 5)
end)

-- Auto-buy functions with proper connection management
function Functions.toggleAutoBuyZen(enabled)
    autoBuyZenEnabled = enabled
    
    if enabled then
        if zenBuyConnection then zenBuyConnection:Disconnect() end
        zenBuyConnection = RunService.Heartbeat:Connect(function()
            if autoBuyZenEnabled then
                Functions.buyAllZenItems()
                task.wait(1) -- Prevent spam
            end
        end)
    else
        if zenBuyConnection then
            zenBuyConnection:Disconnect()
            zenBuyConnection = nil
        end
    end
end

function Functions.toggleAutoBuyMerchant(enabled)
    autoBuyMerchantEnabled = enabled
    
    if enabled then
        if merchantBuyConnection then merchantBuyConnection:Disconnect() end
        merchantBuyConnection = RunService.Heartbeat:Connect(function()
            if autoBuyMerchantEnabled then
                Functions.buyAllMerchantItems()
                task.wait(1) -- Prevent spam
            end
        end)
    else
        if merchantBuyConnection then
            merchantBuyConnection:Disconnect()
            merchantBuyConnection = nil
        end
    end
end

-- Function to buy all zen items
function Functions.buyAllZenItems()
    if not BuyEventShopStock then return end
    for _, item in pairs(zenItems) do
        pcall(function()
            BuyEventShopStock:FireServer(item)
        end)
    end
end

-- Function to buy all merchant items
function Functions.buyAllMerchantItems()
    if not BuyTravelingMerchantShopStock then return end
    for _, item in pairs(merchantItems) do
        pcall(function()
            BuyTravelingMerchantShopStock:FireServer(item)
        end)
    end
end

-- Equip Shovel function
function Functions.autoEquipShovel()
    if not player.Character then return end
    local backpack = player:FindFirstChild("Backpack")
    local shovel = backpack and backpack:FindFirstChild(shovelName)
    if shovel then
        shovel.Parent = player.Character
    end
end

-- Sprinklers 
function Functions.deleteSprinklers(sprinklerArray, OrionLib)
    local targetSprinklers = sprinklerArray or selectedSprinklers
    
    if #targetSprinklers == 0 then
        if OrionLib then
            OrionLib:MakeNotification({
                Name = "No Selection",
                Content = "No sprinkler types selected.",
                Time = 3
            })
        end
        return
    end

    -- Auto equip shovel first
    Functions.autoEquipShovel()
    task.wait(0.5)

    -- Check if shovelClient and objectsFolder exist
    if not shovelClient or not objectsFolder then
        if OrionLib then
            OrionLib:MakeNotification({
                Name = "Error",
                Content = "Required objects not found.",
                Time = 3
            })
        end
        return
    end

    local success, destroyEnv = pcall(function()
        return getsenv and getsenv(shovelClient) or nil
    end)
    
    if not success or not destroyEnv then
        if OrionLib then
            OrionLib:MakeNotification({
                Name = "Error",
                Content = "Could not access shovel environment.",
                Time = 3
            })
        end
        return
    end

    local deletedCount = 0
    local deletedTypes = {}

    for _, obj in ipairs(objectsFolder:GetChildren()) do
        for _, typeName in ipairs(targetSprinklers) do
            if obj.Name == typeName then
                -- Track which types we actually deleted
                if not deletedTypes[typeName] then
                    deletedTypes[typeName] = 0
                end
                deletedTypes[typeName] = deletedTypes[typeName] + 1
                
                -- Destroy the object safely
                pcall(function()
                    if destroyEnv and destroyEnv.Destroy and typeof(destroyEnv.Destroy) == "function" then
                        destroyEnv.Destroy(obj)
                    end
                    if DeleteObject then
                        DeleteObject:FireServer(obj)
                    end
                    if RemoveItem then
                        RemoveItem:FireServer(obj)
                    end
                end)
                deletedCount = deletedCount + 1
            end
        end
    end

    if OrionLib then
        OrionLib:MakeNotification({
            Name = "Sprinklers Deleted",
            Content = string.format("Deleted %d sprinklers", deletedCount),
            Time = 3
        })
    end
end

-- Enhanced helper functions for sprinkler selection
function Functions.getSprinklerTypes()
    return sprinklerTypes
end

function Functions.addSprinklerToSelection(sprinklerName)
    -- Check if sprinkler is already in the array
    for i, sprinkler in ipairs(selectedSprinklers) do
        if sprinkler == sprinklerName then
            return false -- Already exists, don't add duplicate
        end
    end
    -- Add to array
    table.insert(selectedSprinklers, sprinklerName)
    return true
end

function Functions.removeSprinklerFromSelection(sprinklerName)
    -- Find and remove from array
    for i, sprinkler in ipairs(selectedSprinklers) do
        if sprinkler == sprinklerName then
            table.remove(selectedSprinklers, i)
            return true
        end
    end
    return false
end

function Functions.setSelectedSprinklers(sprinklerArray)
    selectedSprinklers = sprinklerArray or {}
end

function Functions.getSelectedSprinklers()
    return selectedSprinklers
end

function Functions.clearSelectedSprinklers()
    selectedSprinklers = {}
end

function Functions.isSprinklerSelected(sprinklerName)
    for _, sprinkler in ipairs(selectedSprinklers) do
        if sprinkler == sprinklerName then
            return true
        end
    end
    return false
end

function Functions.getSelectedSprinklersCount()
    return #selectedSprinklers
end

function Functions.getSelectedSprinklersString()
    if #selectedSprinklers == 0 then
        return "None"
    end
    local selectionText = table.concat(selectedSprinklers, ", ")
    return #selectionText > 50 and (selectionText:sub(1, 47) .. "...") or selectionText
end

-- Remove Farms function
function Functions.removeFarms(OrionLib)
    local farmFolder = Workspace:FindFirstChild("Farm")
    if not farmFolder then
        if OrionLib then
            OrionLib:MakeNotification({
                Name = "No Farms Found",
                Content = "Farm folder not found in Workspace.",
                Time = 3
            })
        end
        return
    end

    local playerCharacter = player.Character
    local rootPart = playerCharacter and playerCharacter:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        if OrionLib then
            OrionLib:MakeNotification({
                Name = "Player Not Found",
                Content = "Player character or position not found.",
                Time = 3
            })
        end
        return
    end

    local currentFarm = nil
    local closestDistance = math.huge

    for _, farm in ipairs(farmFolder:GetChildren()) do
        if farm:IsA("Model") or farm:IsA("Folder") then
            local farmRoot = farm:FindFirstChild("HumanoidRootPart") or farm:FindFirstChildWhichIsA("BasePart")
            if farmRoot then
                local distance = (farmRoot.Position - rootPart.Position).Magnitude
                if distance < closestDistance then
                    closestDistance = distance
                    currentFarm = farm
                end
            end
        end
    end

    for _, farm in ipairs(farmFolder:GetChildren()) do
        if farm ~= currentFarm then
            pcall(function()
                farm:Destroy()
            end)
        end
    end

    if OrionLib then
        OrionLib:MakeNotification({
            Name = "Farms Removed",
            Content = "All other farms have been deleted.",
            Time = 3
        })
    end
end

-- Function to check if string is UUID format
function Functions.isValidUUID(str)
    if not str or type(str) ~= "string" then return false end
    str = string.gsub(str, "[{}]", "")
    return string.match(str, "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
end

-- Function to find pets folder
function Functions.findPetsFolder()
    local possiblePaths = {"PetsPhysical", "Active Pets", "Pets", "ActivePets", "PetModels"}
    
    for _, path in pairs(possiblePaths) do
        local folder = Workspace:FindFirstChild(path)
        if folder then return folder end
    end
    
    local player = Players.LocalPlayer
    if player and player.Character then
        for _, path in pairs(possiblePaths) do
            local folder = player.Character:FindFirstChild(path)
            if folder then return folder end
        end
    end
    
    return nil
end

-- Function to get pet ID from PetMover
function Functions.getPetIdFromPetMover(petMover)
    if not petMover then return nil end
    
    local petId = petMover:GetAttribute("PetId") or 
                 petMover:GetAttribute("Id") or 
                 petMover:GetAttribute("UUID") or
                 petMover:GetAttribute("petId")
    
    if petId then return petId end
    
    if petMover.Parent and Functions.isValidUUID(petMover.Parent.Name) then
        return petMover.Parent.Name
    end
    
    if Functions.isValidUUID(petMover.Name) then
        return petMover.Name
    end
    
    return petMover:GetFullName()
end

-- Function to create ESP "X" marker
function Functions.createESPMarker(pet)
    if excludedPetESPs[pet.id] then
        return -- ESP already exists
    end
    
    local success, billboard = pcall(function()
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "ExcludedPetESP"
        billboard.Adornee = pet.mover
        billboard.Size = UDim2.new(0, 50, 0, 50)
        billboard.StudsOffset = Vector3.new(0, 2, 0)
        billboard.LightInfluence = 0
        billboard.AlwaysOnTop = true
        
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.BackgroundTransparency = 1
        frame.Parent = billboard
        
        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = "X"
        textLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
        textLabel.TextScaled = true
        textLabel.Font = Enum.Font.SourceSansBold
        textLabel.TextStrokeTransparency = 0
        textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        textLabel.Parent = frame
        
        billboard.Parent = pet.mover
        return billboard
    end)
    
    if success and billboard then
        excludedPetESPs[pet.id] = billboard
    end
end

-- Function to remove ESP marker
function Functions.removeESPMarker(petId)
    if excludedPetESPs[petId] then
        pcall(function()
            excludedPetESPs[petId]:Destroy()
        end)
        excludedPetESPs[petId] = nil
    end
end

-- Function to get all pets
function Functions.getAllPets()
    local pets = {}
    
    local function processPetContainer(container)
        local petMover = container:FindFirstChild("PetMover")
        if petMover and petMover:IsA("BasePart") then
            local petId = Functions.getPetIdFromPetMover(petMover)
            if petId then
                table.insert(pets, {
                    id = petId,
                    name = "Pet",
                    model = container,
                    mover = petMover,
                    position = petMover.Position
                })
            end
        end
    end
    
    local function findStandalonePetMovers(parent)
        for _, child in pairs(parent:GetChildren()) do
            if child:IsA("Part") and child.Name == "PetMover" then
                local petId = Functions.getPetIdFromPetMover(child)
                if petId then
                    table.insert(pets, {
                        id = petId,
                        name = "Pet",
                        model = child.Parent,
                        mover = child,
                        position = child.Position
                    })
                end
            elseif child:IsA("Model") or child:IsA("Folder") then
                findStandalonePetMovers(child)
            end
        end
    end
    
    if not petsFolder then
        petsFolder = Functions.findPetsFolder()
    end
    
    if petsFolder then
        if petsFolder.Name == "PetsPhysical" then
            local petMoverFolder = petsFolder:FindFirstChild("PetMover")
            if petMoverFolder then
                for _, petContainer in pairs(petMoverFolder:GetChildren()) do
                    if petContainer:IsA("Model") and Functions.isValidUUID(petContainer.Name) then
                        processPetContainer(petContainer)
                    end
                end
            end
        else
            for _, child in pairs(petsFolder:GetChildren()) do
                if child:IsA("Model") then
                    processPetContainer(child)
                end
            end
        end
    end
    
    findStandalonePetMovers(Workspace)
    
    return pets
end

-- Function to get farm center point
function Functions.getFarmCenterPoint()
    local player = Players.LocalPlayer
    if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return nil
    end
    
    local playerPosition = player.Character.HumanoidRootPart.Position
    local farmFolder = Workspace:FindFirstChild("Farm")
    
    if farmFolder then
        local closestFarm = nil
        local closestDistance = math.huge
        
        for _, farm in pairs(farmFolder:GetChildren()) do
            local centerPoint = farm:FindFirstChild("Center_Point")
            if centerPoint then
                local distance = (playerPosition - centerPoint.Position).Magnitude
                if distance < closestDistance then
                    closestDistance = distance
                    closestFarm = centerPoint.Position
                end
            end
        end
        
        return closestFarm
    end
    
    return playerPosition
end

-- Function to format pet ID to UUID format
function Functions.formatPetIdToUUID(petId)
    if string.match(petId, "^{%x+%-%x+%-%x+%-%x+%-%x+}$") then
        return petId
    end
    
    petId = string.gsub(petId, "[{}]", "")
    return "{" .. petId .. "}"
end

-- Function to set pet state
function Functions.setPetState(petId, state)
    if not ActivePetService then return end
    local formattedPetId = Functions.formatPetIdToUUID(petId)
    pcall(function()
        ActivePetService:FireServer("SetPetState", formattedPetId, state)
    end)
end

-- Function to run the auto middle loop
function Functions.runAutoMiddleLoop(RADIUS)
    local pets = Functions.getAllPets()
    local farmCenterPoint = Functions.getFarmCenterPoint()
    
    if not farmCenterPoint then return end
    
    for _, pet in pairs(pets) do
        -- Skip excluded pets
        if not excludedPets[pet.id] then
            if allPetsSelected or selectedPets[pet.id] then
                local distance = (pet.mover.Position - farmCenterPoint).Magnitude
                if distance > RADIUS then
                    Functions.setPetState(pet.id, "Idle")
                end
            end
        end
    end
end

-- Function to select all pets
function Functions.selectAllPets()
    selectedPets = {}
    allPetsSelected = true
    local pets = Functions.getAllPets()
    for _, pet in pairs(pets) do
        selectedPets[pet.id] = true
    end
end

-- Function to update dropdown options
function Functions.updateDropdownOptions()
    local pets = Functions.getAllPets()
    currentPetsList = {}
    local dropdownOptions = {"None"}
    
    for i, pet in pairs(pets) do
        local shortId = string.sub(tostring(pet.id), 1, 8)
        local displayName = "Pet (" .. shortId .. "...)"
        table.insert(dropdownOptions, displayName)
        currentPetsList[displayName] = pet
    end
    
    return dropdownOptions
end

-- Function to refresh pets
function Functions.refreshPets()
    selectedPets = {}
    allPetsSelected = false
    petsFolder = Functions.findPetsFolder()
    local pets = Functions.getAllPets()
    return pets
end

-- Helper functions
function Functions.isPetExcluded(petId)
    return excludedPets[petId] == true
end

function Functions.getExcludedPetCount()
    local count = 0
    for _ in pairs(excludedPets) do
        count = count + 1
    end
    return count
end

function Functions.getExcludedPetIds()
    local ids = {}
    for petId, _ in pairs(excludedPets) do
        table.insert(ids, petId)
    end
    return ids
end

-- Function to reduce lag
function Functions.reduceLag()
    pcall(function()
        repeat
            local lag = game.Workspace:findFirstChild("Lag", true)
            if (lag ~= nil) then
                lag:remove()
            end
            wait(0.1) -- Add small delay to prevent infinite tight loop
        until (game.Workspace:findFirstChild("Lag", true) == nil)
    end)
end

-- Function to fade in main tab
function Functions.fadeInMainTab()
    pcall(function()
        local screenGui = player:WaitForChild("PlayerGui", 5):WaitForChild("Orion", 5)
        local mainFrame = screenGui:WaitForChild("Main", 5)
        if mainFrame then
            mainFrame.BackgroundTransparency = 1

            local tween = TweenService:Create(
                mainFrame,
                TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { BackgroundTransparency = 0.2 }
            )
            tween:Play()
        end
    end)
end

-- Server hopping function
function Functions.serverHop()
    local function getServers()
        local success, result = pcall(function()
            return game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100")
        end)
        if success then
            local success2, decoded = pcall(function()
                return HttpService:JSONDecode(result)
            end)
            if success2 and decoded and decoded.data then
                for _, server in ipairs(decoded.data) do
                    if server.playing < server.maxPlayers and server.id ~= game.JobId then
                        return server.id, server.playing
                    end
                end
            end
        end
        return nil
    end

    local foundServer, playerCount = getServers()
    if foundServer then
        return foundServer, playerCount
    else
        return nil, nil
    end
end

-- Function to copy Discord link
function Functions.copyDiscordLink()
    pcall(function()
        if setclipboard then
            setclipboard("https://discord.gg/yura") -- Replace with actual Discord link
            if _G.OrionLib then
                _G.OrionLib:MakeNotification({
                    Name = "Discord Link Copied",
                    Content = "Discord link copied to clipboard!",
                    Time = 3
                })
            end
        else
            warn("Clipboard access not available.")
        end
    end)
end

-- Cleanup function
function Functions.cleanup()
    -- Cleanup auto-buy connections
    if zenBuyConnection then
        zenBuyConnection:Disconnect()
        zenBuyConnection = nil
    end
    if merchantBuyConnection then
        merchantBuyConnection:Disconnect()
        merchantBuyConnection = nil
    end
    
    -- Clean up ESP markers
    for petId, esp in pairs(excludedPetESPs) do
        if esp then
            pcall(function()
                esp:Destroy()
            end)
        end
    end
    excludedPetESPs = {}
end

-- Export configuration tables and variables
Functions.sprinklerTypes = sprinklerTypes
Functions.zenItems = zenItems
Functions.merchantItems = merchantItems
Functions.selectedPets = selectedPets
Functions.excludedPets = excludedPets
Functions.excludedPetESPs = excludedPetESPs
Functions.allPetsSelected = allPetsSelected
Functions.currentPetsList = currentPetsList

return Functions
