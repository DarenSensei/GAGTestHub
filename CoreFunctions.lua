-- Complete Functions for Grow A Garden Script Loader
-- External for MAIN
-- Name : CoreFunctions
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

-- Crop Control Variables
local selectedCropTypes = {}
local cropWeightThreshold = 1
local autoShovelCropsEnabled = false
local autoShovelCropsConnection = nil

-- NEW: Tree Control Variables
local selectedTreeTypes = {}
local treeWeightThreshold = 1
local autoShovelTreesEnabled = false
local autoShovelTreesConnection = nil
local currentFarm = nil

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

-- NEW: FARM DETECTION SYSTEM

-- Function to detect current farm (nearest farm to player)
local function detectCurrentFarm()
    local farmFolder = Workspace:FindFirstChild("Farm")
    if not farmFolder then 
        warn("Farm folder not found in Workspace")
        return nil 
    end

    local playerCharacter = player.Character
    local rootPart = playerCharacter and playerCharacter:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        warn("Player character or position not found")
        return nil
    end

    local nearestFarm = nil
    local closestDistance = math.huge

    -- Find the nearest farm to the player
    for _, farm in ipairs(farmFolder:GetChildren()) do
        if farm:IsA("Model") or farm:IsA("Folder") then
            local farmRoot = farm:FindFirstChild("HumanoidRootPart") or farm:FindFirstChildWhichIsA("BasePart")
            if farmRoot then
                local distance = (farmRoot.Position - rootPart.Position).Magnitude
                if distance < closestDistance then
                    closestDistance = distance
                    nearestFarm = farm
                end
            end
        end
    end

    if nearestFarm then
        print("Detected current farm: " .. nearestFarm.Name .. " (Distance: " .. math.floor(closestDistance) .. ")")
    else
        warn("No farm detected")
    end

    return nearestFarm
end

-- Function to get Plants_Physical folder from current farm
local function getPlantsPhysicalFolder()
    if not currentFarm then
        currentFarm = detectCurrentFarm()
    end
    
    if not currentFarm then 
        return nil 
    end
    
    local success, plantsPhysical = pcall(function()
        return currentFarm:FindFirstChild("Farm"):FindFirstChild("Important"):FindFirstChild("Plants_Physical")
    end)
    
    if success and plantsPhysical then
        return plantsPhysical
    else
        warn("Could not access Plants_Physical folder in current farm")
        return nil
    end
end

-- NEW: TREE DETECTION SYSTEM

-- Helper function to check if fruit (tree) should be shoveled
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
    
    return weight < treeWeightThreshold
end

-- Function to shovel individual fruit (tree)
local function shovelFruit(fruit)
    if not fruit or not fruit.Parent then 
        warn("Fruit no longer exists, skipping")
        return false
    end
    
    -- Auto equip shovel first
    Functions.autoEquipShovel()
    task.wait(0.1) -- Small delay after equipping
    
    -- Double check fruit still exists after delay
    if not fruit or not fruit.Parent then 
        warn("Fruit disappeared after equipping shovel")
        return false
    end
    
    -- Use RemoveItem to delete the fruit
    if not RemoveItem then
        warn("Remove_Item event not found")
        return false
    end
    
    local removeSuccess = pcall(function()
        RemoveItem:FireServer(fruit)
    end)
    
    if removeSuccess then
        print("Successfully sent remove request for fruit: " .. fruit.Name)
    else
        warn("Failed to remove fruit: " .. fruit.Name)
    end
    
    return removeSuccess
end

-- Check if tree type is selected
local function isTreeTypeSelected(treeName)
    if #selectedTreeTypes == 0 then
        return false
    end
    
    for _, selectedType in ipairs(selectedTreeTypes) do
        -- Exact match or partial match
        if treeName == selectedType or 
           treeName:find(selectedType) or 
           selectedType:find(treeName) then
            return true
        end
    end
    return false
end

-- Main auto shovel trees function
local function autoShovelTrees()
    if not autoShovelTreesEnabled then 
        return 
    end
    
    if #selectedTreeTypes == 0 then
        return
    end
    
    -- Get Plants_Physical folder from current farm
    local plantsPhysical = getPlantsPhysicalFolder()
    if not plantsPhysical then 
        return 
    end
    
    -- Get all plants from Plants_Physical
    local allPlants = plantsPhysical:GetChildren()
    
    -- Process each plant for fruits (trees)
    for plantIndex, plant in pairs(allPlants) do
        if plant and plant.Parent then
            -- Look for Fruits folder in each plant
            local fruitsFolder = plant:FindFirstChild("Fruits")
            if fruitsFolder then
                local allFruits = fruitsFolder:GetChildren()
                
                for _, fruit in pairs(allFruits) do
                    -- Check if this fruit has Weight property
                    if fruit:FindFirstChild("Weight") then
                        local fruitName = fruit.Name
                        
                        -- Check if this tree type is selected for shoveling
                        if isTreeTypeSelected(fruitName) then
                            -- Check if this specific fruit meets weight criteria
                            if shouldShovelFruit(fruit) then
                                local success = shovelFruit(fruit)
                                if success then
                                    task.wait(0.15) -- Small delay between shoveling each fruit
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Get all available tree types by checking all plants' fruits
function Functions.getTreeTypes()
    local treeTypes = {}
    
    -- Get Plants_Physical folder
    local plantsPhysical = getPlantsPhysicalFolder()
    if not plantsPhysical then 
        return treeTypes
    end
    
    -- Get all plants
    local allPlants = plantsPhysical:GetChildren()
    
    -- Collect unique fruit names from all plants
    local uniqueFruits = {}
    for plantIndex, plant in pairs(allPlants) do
        local fruitsFolder = plant:FindFirstChild("Fruits")
        if fruitsFolder then
            local allFruits = fruitsFolder:GetChildren()
            
            for _, fruit in pairs(allFruits) do
                -- Only include items that have a Weight property
                if fruit:FindFirstChild("Weight") and not uniqueFruits[fruit.Name] then
                    uniqueFruits[fruit.Name] = true
                    table.insert(treeTypes, fruit.Name)
                end
            end
        end
    end
    
    -- Sort alphabetically for better organization
    table.sort(treeTypes)
    return treeTypes
end

-- Refresh tree list for dropdown
function Functions.refreshTreeList()
    currentFarm = detectCurrentFarm() -- Update current farm
    local newOptions = {"None"}
    local treeTypes = Functions.getTreeTypes()
    for _, treeType in ipairs(treeTypes) do
        table.insert(newOptions, treeType)
    end
    return newOptions
end

-- Clear selected trees
function Functions.clearSelectedTrees()
    selectedTreeTypes = {}
end

-- Add tree to selection
function Functions.addTreeToSelection(treeName)
    if treeName and treeName ~= "None" and not table.find(selectedTreeTypes, treeName) then
        table.insert(selectedTreeTypes, treeName)
    end
end

-- Set tree weight threshold
function Functions.setTreeWeightThreshold(weight)
    local num = tonumber(weight)
    if num and num >= 0 and num <= 500 then
        treeWeightThreshold = num
        return true
    end
    return false
end

-- Set selected trees array
function Functions.setSelectedTrees(treeArray)
    selectedTreeTypes = treeArray or {}
end

-- Get selected trees
function Functions.getSelectedTrees()
    return selectedTreeTypes
end

-- Get selected trees count
function Functions.getSelectedTreesCount()
    return #selectedTreeTypes
end

-- Get selected trees as string
function Functions.getSelectedTreesString()
    if #selectedTreeTypes == 0 then
        return "None"
    end
    return table.concat(selectedTreeTypes, ", ")
end

-- Toggle auto shovel trees
function Functions.toggleAutoShovelTrees(enabled, OrionLib)
    autoShovelTreesEnabled = enabled
    
    if enabled then
        -- Disconnect existing connection
        if autoShovelTreesConnection then 
            autoShovelTreesConnection:Disconnect() 
        end
        
        -- Create new connection with proper error handling
        autoShovelTreesConnection = RunService.Heartbeat:Connect(function()
            if autoShovelTreesEnabled then
                pcall(function()
                    autoShovelTrees()
                end)
                task.wait(1) -- Check every second
            end
        end)
        
        if OrionLib then
            OrionLib:MakeNotification({
                Name = "Auto Shovel Trees",
                Content = "Enabled for " .. Functions.getSelectedTreesCount() .. " types",
                Time = 2
            })
        end
    else
        -- Disable auto shovel trees
        if autoShovelTreesConnection then
            autoShovelTreesConnection:Disconnect()
            autoShovelTreesConnection = nil
        end
        
        if OrionLib then
            OrionLib:MakeNotification({
                Name = "Auto Shovel Trees",
                Content = "Disabled",
                Time = 1
            })
        end
    end
end

-- EXISTING CROP SYSTEM FUNCTIONS (Updated to use new farm detection)

-- Helper function to check if crop should be shoveled
local function shouldShovelCrop(crop)
    if not crop or not crop.Parent then 
        return false 
    end
    
    -- Check if the crop has a Weight property
    local weightObject = crop:FindFirstChild("Weight")
    if not weightObject then 
        return false 
    end
    
    local success, weight = pcall(function()
        return weightObject.Value
    end)
    
    if not success or not weight then 
        return false 
    end
    
    return weight < cropWeightThreshold
end

-- Function to shovel individual crop
local function shovelCrop(crop)
    if not crop or not crop.Parent then 
        warn("Crop no longer exists, skipping")
        return false
    end
    
    -- Auto equip shovel first
    Functions.autoEquipShovel()
    task.wait(0.1) -- Small delay after equipping
    
    -- Double check crop still exists after delay
    if not crop or not crop.Parent then 
        warn("Crop disappeared after equipping shovel")
        return false
    end
    
    -- Use RemoveItem to delete the crop
    if not RemoveItem then
        warn("Remove_Item event not found")
        return false
    end
    
    local removeSuccess = pcall(function()
        RemoveItem:FireServer(crop)
    end)
    
    if removeSuccess then
        print("Successfully sent remove request for crop: " .. crop.Name)
    else
        warn("Failed to remove crop: " .. crop.Name)
    end
    
    return removeSuccess
end

-- Check if crop type is selected
local function isCropTypeSelected(cropName)
    if #selectedCropTypes == 0 then
        return false
    end
    
    for _, selectedType in ipairs(selectedCropTypes) do
        -- Exact match or partial match
        if cropName == selectedType or 
           cropName:find(selectedType) or 
           selectedType:find(cropName) then
            return true
        end
    end
    return false
end

-- Main auto shovel crops function (Updated)
local function autoShovelCrops()
    if not autoShovelCropsEnabled then 
        return 
    end
    
    if #selectedCropTypes == 0 then
        return
    end
    
    -- Get Plants_Physical folder from current farm
    local plantsPhysical = getPlantsPhysicalFolder()
    if not plantsPhysical then 
        return 
    end
    
    -- Get all plants/trees from Plants_Physical
    local allPlants = plantsPhysical:GetChildren()
    
    -- Process each plant for crops (different from fruits)
    for plantIndex, plant in pairs(allPlants) do
        if plant and plant.Parent then
            -- Look for direct crop children (not in a "Fruits" folder)
            local allChildren = plant:GetChildren()
            
            for _, child in pairs(allChildren) do
                -- Check if this child is a crop (has Weight property and is not a folder)
                if child:FindFirstChild("Weight") and not child:IsA("Folder") then
                    local cropName = child.Name
                    
                    -- Check if this crop type is selected for shoveling
                    if isCropTypeSelected(cropName) then
                        -- Check if this specific crop meets weight criteria
                        if shouldShovelCrop(child) then
                            local success = shovelCrop(child)
                            if success then
                                task.wait(0.15) -- Small delay between shoveling each crop
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Get all available crop types by checking all plants (Updated)
function Functions.getCropTypes()
    local cropTypes = {}
    
    -- Get Plants_Physical folder from current farm
    local plantsPhysical = getPlantsPhysicalFolder()
    if not plantsPhysical then 
        return cropTypes
    end
    
    -- Get all plants
    local allPlants = plantsPhysical:GetChildren()
    
    -- Collect unique crop names from all plants
    local uniqueCrops = {}
    for plantIndex, plant in pairs(allPlants) do
        local allChildren = plant:GetChildren()
        
        for _, child in pairs(allChildren) do
            -- Only include items that have a Weight property and are not folders
            if child:FindFirstChild("Weight") and not child:IsA("Folder") and not uniqueCrops[child.Name] then
                uniqueCrops[child.Name] = true
                table.insert(cropTypes, child.Name)
            end
        end
    end
    
    -- Sort alphabetically for better organization
    table.sort(cropTypes)
    return cropTypes
end

-- Refresh crop list for dropdown (Updated)
function Functions.refreshCropList()
    currentFarm = detectCurrentFarm() -- Update current farm
    local newOptions = {"None"}
    local cropTypes = Functions.getCropTypes()
    for _, cropType in ipairs(cropTypes) do
        table.insert(newOptions, cropType)
    end
    return newOptions
end

-- Clear selected crops
function Functions.clearSelectedCrops()
    selectedCropTypes = {}
end

-- Add crop to selection
function Functions.addCropToSelection(cropName)
    if cropName and cropName ~= "None" and not table.find(selectedCropTypes, cropName) then
        table.insert(selectedCropTypes, cropName)
    end
end

-- Set crop weight threshold
function Functions.setCropWeightThreshold(weight)
    local num = tonumber(weight)
    if num and num >= 0 and num <= 500 then
        cropWeightThreshold = num
        return true
    end
    return false
end

-- Set selected crops array
function Functions.setSelectedCrops(cropArray)
    selectedCropTypes = cropArray or {}
end

-- Get selected crops
function Functions.getSelectedCrops()
    return selectedCropTypes
end

-- Get selected crops count
function Functions.getSelectedCropsCount()
    return #selectedCropTypes
end

-- Get selected crops as string
function Functions.getSelectedCropsString()
    if #selectedCropTypes == 0 then
        return "None"
    end
    return table.concat(selectedCropTypes, ", ")
end

-- Toggle auto shovel crops
function Functions.toggleAutoShovelCrops(enabled, OrionLib)
    autoShovelCropsEnabled = enabled
    
    if enabled then
        -- Disconnect existing connection
        if autoShovelCropsConnection then 
            autoShovelCropsConnection:Disconnect() 
        end
        
        -- Create new connection with proper error handling
        autoShovelCropsConnection = RunService.Heartbeat:Connect(function()
            if autoShovelCropsEnabled then
                pcall(function()
                    autoShovelCrops()
                end)
                task.wait(1) -- Check every second
            end
        end)
        
        if OrionLib then
            OrionLib:MakeNotification({
                Name = "Auto Shovel Crops",
                Content = "Enabled for " .. Functions.getSelectedCropsCount() .. " types",
                Time = 2
            })
        end
    else
        -- Disable auto shovel crops
        if autoShovelCropsConnection then
            autoShovelCropsConnection:Disconnect()
            autoShovelCropsConnection = nil
        end
        
        if OrionLib then
            OrionLib:MakeNotification({
                Name = "Auto Shovel Crops",
                Content = "Disabled",
                Time = 1
            })
        end
    end
end

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
    
    -- Clean up auto shovel crops connection
    if autoShovelCropsConnection then
        autoShovelCropsConnection:Disconnect()
        autoShovelCropsConnection = nil
    end
    
    -- Clean up auto shovel trees connection
    if autoShovelTreesConnection then
        autoShovelTreesConnection:Disconnect()
        autoShovelTreesConnection = nil
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

-- Export the crop variables to the main Functions table
Functions.selectedCropTypes = selectedCropTypes
Functions.cropWeightThreshold = cropWeightThreshold
Functions.autoShovelCropsEnabled = autoShovelCropsEnabled

-- Export the tree variables to the main Functions table
Functions.selectedTreeTypes = selectedTreeTypes
Functions.treeWeightThreshold = treeWeightThreshold
Functions.autoShovelTreesEnabled = autoShovelTreesEnabled

-- Export the main auto shovel functions
Functions.autoShovelCrops = autoShovelCrops
Functions.autoShovelTrees = autoShovelTrees

-- Export farm detection functions
Functions.detectCurrentFarm = detectCurrentFarm
Functions.getPlantsPhysicalFolder = getPlantsPhysicalFolder
Functions.currentFarm = currentFarm

return Functions
