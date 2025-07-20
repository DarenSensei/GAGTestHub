-- Complete Functions for Grow A Garden Script Loader
-- External for MAIN
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

-- Auto Shovel Variables (FIXED: Added missing declarations)
local selectedFruitTypes = {}
local weightThreshold = 50
local autoShovelEnabled = false
local autoShovelConnection = nil

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

function Functions.autoShovelEquipShovel()
    if not player.Character then return end
    local backpack = player:FindFirstChild("Backpack")
    local shovel = backpack and backpack:FindFirstChild(shovelName)
    if shovel then
        shovel.Parent = player.Character
        task.wait(0.1)
    end
end

-- RECONSTRUCTED AUTO SHOVEL FUNCTIONS
local RunService = game:GetService("RunService")

-- Variables
local selectedFruitTypes = {}
local weightThreshold = 30
local autoShovelEnabled = false
local autoShovelConnection = nil

-- Helper function to check if fruit should be shoveled
local function shouldShovelFruit(fruit)
    if not fruit or not fruit.Parent then 
        return false 
    end
    
    -- Check if the fruit has a Weight property
    local weightObject = fruit:FindFirstChild("Weight")
    if not weightObject then 
        return false 
    end
    
    local success, weight = pcall(function()
        return weightObject.Value
    end)
    
    if not success or not weight then 
        return false 
    end
    
    return weight < weightThreshold
end

-- Function to shovel individual fruit (NOT the tree)
local function shovelFruit(fruit)
    if not fruit or not fruit.Parent then 
        print("Fruit no longer exists, skipping")
        return false
    end
    
    print("Attempting to shovel fruit: " .. (fruit.Name or "Unknown"))
    
    -- Auto equip shovel first
    if Functions.autoEquipShovel then
        Functions.autoEquipShovel()
        task.wait(0.1) -- Small delay after equipping
    end
    
    -- Double check fruit still exists after delay
    if not fruit or not fruit.Parent then 
        print("Fruit disappeared after equipping shovel")
        return false
    end
    
    -- Get the Remove_Item event to remove ONLY the individual fruit
    local success, Remove_Item = pcall(function()
        return game:GetService("ReplicatedStorage").GameEvents.Remove_Item
    end)
    
    if success and Remove_Item then
        local removeSuccess = pcall(function()
            -- IMPORTANT: Only pass the individual fruit object, NOT the tree
            Remove_Item:FireServer(fruit)
            print("Successfully sent remove request for fruit: " .. fruit.Name)
        end)
        return removeSuccess
    else
        print("Could not find Remove_Item event, trying fallback")
        -- Fallback method
        local success2, gameEvents = pcall(function()
            return game:GetService("ReplicatedStorage"):FindFirstChild("GameEvents")
        end)
        
        if success2 and gameEvents then
            local altEvent = gameEvents:FindFirstChild("Remove_Item")
            if altEvent then
                local removeSuccess = pcall(function()
                    -- Again, only pass the individual fruit
                    altEvent:FireServer(fruit)
                    print("Successfully sent remove request via fallback for fruit: " .. fruit.Name)
                end)
                return removeSuccess
            end
        end
    end
    
    print("Failed to remove fruit: " .. fruit.Name)
    return false
end

-- Group fruits by name to handle duplicates
local function groupFruitsByName(fruitsFolder)
    local groupedFruits = {}
    
    for _, fruit in pairs(fruitsFolder:GetChildren()) do
        if fruit:FindFirstChild("Weight") then
            local fruitName = fruit.Name
            if not groupedFruits[fruitName] then
                groupedFruits[fruitName] = {}
            end
            table.insert(groupedFruits[fruitName], fruit)
        end
    end
    
    return groupedFruits
end

-- Check if fruit type is selected
local function isFruitTypeSelected(fruitName)
    if #selectedFruitTypes == 0 then
        return false
    end
    
    for _, selectedType in ipairs(selectedFruitTypes) do
        -- Exact match or partial match
        if fruitName == selectedType or 
           fruitName:find(selectedType) or 
           selectedType:find(fruitName) then
            return true
        end
    end
    return false
end

-- Main auto shovel function
local function autoShovel()
    if not autoShovelEnabled then 
        return 
    end
    
    if #selectedFruitTypes == 0 then
        return
    end
    
    -- Get the plants physical folder (where all trees/plants are located)
    local success, plantsPhysical = pcall(function()
        return workspace.Farm.Farm.Important.Plants_Physical
    end)
    
    if not success or not plantsPhysical then 
        print("Could not access Plants_Physical folder")
        return 
    end
    
    -- Get all trees/plants from Plants_Physical
    local allTrees = plantsPhysical:GetChildren()
    print("Found " .. #allTrees .. " trees/plants to check")
    
    -- Process each tree/plant
    for treeIndex, tree in pairs(allTrees) do
        if tree and tree.Parent then
            print("Checking tree " .. treeIndex .. ": " .. (tree.Name or "Unknown"))
            
            -- Look for the Fruits folder inside this tree/plant
            local fruitsFolder = tree:FindFirstChild("Fruits")
            if fruitsFolder then
                print("Found Fruits folder in tree " .. treeIndex)
                
                -- Get all individual fruits from this tree's Fruits folder
                local allFruitsInTree = fruitsFolder:GetChildren()
                print("Found " .. #allFruitsInTree .. " fruits in this tree")
                
                -- Group fruits by name to handle duplicates properly
                local groupedFruits = groupFruitsByName(fruitsFolder)
                
                -- Process each fruit group
                for fruitName, fruitGroup in pairs(groupedFruits) do
                    print("Processing fruit group: " .. fruitName .. " (Count: " .. #fruitGroup .. ")")
                    
                    -- Check if this fruit type is selected for shoveling
                    if isFruitTypeSelected(fruitName) then
                        print("Fruit type " .. fruitName .. " is selected for shoveling")
                        
                        -- Process each individual fruit in the group
                        for fruitIndex, individualFruit in pairs(fruitGroup) do
                            if individualFruit and individualFruit.Parent then
                                -- Check if this specific fruit meets weight criteria
                                if shouldShovelFruit(individualFruit) then
                                    print("Shoveling fruit " .. fruitIndex .. " of type " .. fruitName)
                                    local success = shovelFruit(individualFruit)
                                    if success then
                                        task.wait(0.15) -- Small delay between shoveling each fruit
                                    end
                                else
                                    print("Fruit " .. fruitIndex .. " does not meet weight criteria")
                                end
                            end
                        end
                    else
                        print("Fruit type " .. fruitName .. " is not selected for shoveling")
                    end
                end
            else
                print("No Fruits folder found in tree " .. treeIndex)
            end
        end
    end
end

-- Get all available fruit types by checking all trees
function Functions.getFruitTypes()
    local fruitTypes = {}
    
    -- Access the trees/plants folder
    local success, plantsPhysical = pcall(function()
        return workspace.Farm.Farm.Important.Plants_Physical
    end)
    
    if not success or not plantsPhysical then 
        print("Could not access Plants_Physical for getting fruit types")
        return fruitTypes
    end
    
    -- Get all trees/plants
    local allTrees = plantsPhysical:GetChildren()
    print("Scanning " .. #allTrees .. " trees for fruit types")
    
    -- Collect unique fruit names from all trees
    local uniqueFruits = {}
    for treeIndex, tree in pairs(allTrees) do
        if tree:FindFirstChild("Fruits") then
            local fruitsFolder = tree.Fruits
            local fruitsInTree = fruitsFolder:GetChildren()
            
            for _, fruit in pairs(fruitsInTree) do
                -- Only include fruits that have a Weight property
                if fruit:FindFirstChild("Weight") and not uniqueFruits[fruit.Name] then
                    uniqueFruits[fruit.Name] = true
                    table.insert(fruitTypes, fruit.Name)
                    print("Found fruit type: " .. fruit.Name .. " in tree " .. treeIndex)
                end
            end
        end
    end
    
    -- Sort alphabetically for better organization
    table.sort(fruitTypes)
    print("Total unique fruit types found: " .. #fruitTypes)
    return fruitTypes
end

-- Refresh fruit list for dropdown
function Functions.refreshFruitList()
    local newOptions = {"None"}
    local fruitTypes = Functions.getFruitTypes()
    for _, fruitType in ipairs(fruitTypes) do
        table.insert(newOptions, fruitType)
    end
    return newOptions
end

-- Clear selected fruits
function Functions.clearSelectedFruits()
    selectedFruitTypes = {}
end

-- Add fruit to selection
function Functions.addFruitToSelection(fruitName)
    if fruitName and fruitName ~= "None" and not table.find(selectedFruitTypes, fruitName) then
        table.insert(selectedFruitTypes, fruitName)
    end
end

-- Set weight threshold
function Functions.setFruitWeightThreshold(weight)
    local num = tonumber(weight)
    if num and num >= 0 and num <= 500 then
        weightThreshold = num
        return true
    end
    return false
end

-- Set selected fruits array
function Functions.setSelectedFruits(fruitArray)
    selectedFruitTypes = fruitArray or {}
end

-- Get selected fruits
function Functions.getSelectedFruits()
    return selectedFruitTypes
end

-- Get selected fruits count
function Functions.getSelectedFruitsCount()
    return #selectedFruitTypes
end

-- Get selected fruits as string
function Functions.getSelectedFruitsString()
    if #selectedFruitTypes == 0 then
        return "None"
    end
    return table.concat(selectedFruitTypes, ", ")
end

-- Toggle auto shovel
function Functions.toggleAutoShovel(enabled, OrionLib)
    autoShovelEnabled = enabled
    
    if enabled then
        -- Disconnect existing connection
        if autoShovelConnection then 
            autoShovelConnection:Disconnect() 
        end
        
        -- Create new connection with proper error handling
        autoShovelConnection = RunService.Heartbeat:Connect(function()
            if autoShovelEnabled then
                pcall(function()
                    autoShovel()
                end)
                task.wait(1) -- Check every second
            end
        end)
        
        if OrionLib then
            OrionLib:MakeNotification({
                Name = "Auto Shovel",
                Content = "Auto Shovel enabled for " .. Functions.getSelectedFruitsCount() .. " fruit types",
                Time = 2
            })
        end
    else
        -- Disable auto shovel
        if autoShovelConnection then
            autoShovelConnection:Disconnect()
            autoShovelConnection = nil
        end
        
        if OrionLib then
            OrionLib:MakeNotification({
                Name = "Auto Shovel",
                Content = "Auto Shovel disabled",
                Time = 2
            })
        end
    end
end

-- Export the main auto shovel function
Functions.autoShovel = autoShovel

-- Export variables for external access
Functions.selectedFruitTypes = selectedFruitTypes
Functions.weightThreshold = weightThreshold
Functions.autoShovelEnabled = autoShovelEnabled
        
        if OrionLib then
            OrionLib:MakeNotification({
                Name = "Auto Shovel",
                Content = "Auto Shovel disabled",
                Time = 2
            })
        end
    end
end

-- Export auto shovel variables
Functions.selectedFruitTypes = selectedFruitTypes
Functions.weightThreshold = weightThreshold
Functions.autoShovelEnabled = autoShovelEnabled

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
    
    -- Clean up auto shovel connection
    if autoShovelConnection then
        autoShovelConnection:Disconnect()
        autoShovelConnection = nil
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
