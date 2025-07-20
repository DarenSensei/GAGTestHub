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

-- Configuration
local shovelName = "Shovel"
local weightThreshold = 1
local autoShovelEnabled = false
local selectedTrees = {}
local autoShovelConnection = nil

-- References
local plantsPhysical = game:GetService("Workspace").Farm.Farm.Important.Plants_Physical
local shovelClient = nil

-- Try to find shovel client
pcall(function()
    shovelClient = player.PlayerGui:FindFirstChild("ShovelClient", true) or 
                   player.PlayerScripts:FindFirstChild("ShovelClient", true)
end)

-- Functions table
local Functions = {}

-- Get all tree types
function Functions.getTreeTypes()
    local treeTypes = {}
    for _, child in ipairs(plantsPhysical:GetChildren()) do
        if child:IsA("Folder") or child:IsA("Model") then
            table.insert(treeTypes, child.Name)
        end
    end
    return treeTypes
end

-- Tree selection functions
function Functions.clearSelectedTrees()
    selectedTrees = {}
end

function Functions.addTreeToSelection(treeName)
    selectedTrees[treeName] = true
end

function Functions.getSelectedTrees()
    local selected = {}
    for treeName, _ in pairs(selectedTrees) do
        table.insert(selected, treeName)
    end
    return selected
end

function Functions.getSelectedTreesCount()
    local count = 0
    for _, _ in pairs(selectedTrees) do
        count = count + 1
    end
    return count
end

function Functions.getSelectedTreesString()
    local selected = Functions.getSelectedTrees()
    if #selected == 0 then
        return "None"
    elseif #selected <= 3 then
        return table.concat(selected, ", ")
    else
        return string.format("%s and %d more", table.concat({selected[1], selected[2]}, ", "), #selected - 2)
    end
end

-- Auto equip shovel
function Functions.autoEquipShovel()
    if not player.Character then return end
    local backpack = player:FindFirstChild("Backpack")
    local shovel = backpack and backpack:FindFirstChild(shovelName)
    if shovel then
        shovel.Parent = player.Character
    end
end

-- Get tree weight
function Functions.getTreeWeight(treeName)
    local tree = plantsPhysical:FindFirstChild(treeName)
    if tree and tree:FindFirstChild("Weight") then
        return tree.Weight.Value or 0
    end
    return 0
end

-- Get fruits from tree
function Functions.getTreeFruits(treeName)
    local fruits = {}
    local tree = plantsPhysical:FindFirstChild(treeName)
    if tree and tree:FindFirstChild("Fruit_Spawn") then
        for _, fruit in ipairs(tree.Fruit_Spawn:GetChildren()) do
            table.insert(fruits, fruit)
        end
    end
    return fruits
end

-- Shovel fruit
function Functions.shovelFruit(fruit)
    if not fruit or not fruit.Parent or not shovelClient then return false end
    
    Functions.autoEquipShovel()
    task.wait(0.1)
    
    local success, destroyEnv = pcall(function()
        return getsenv and getsenv(shovelClient) or nil
    end)
    
    if not success or not destroyEnv then return false end
    
    local shoveled = false
    pcall(function()
        if destroyEnv and destroyEnv.Destroy then
            destroyEnv.Destroy(fruit)
            shoveled = true
        end
    end)
    
    return shoveled
end

-- Auto shovel tree
function Functions.autoShovelTree(treeName)
    local treeWeight = Functions.getTreeWeight(treeName)
    if treeWeight >= weightThreshold then return 0 end
    
    local fruits = Functions.getTreeFruits(treeName)
    local shoveledCount = 0
    
    for _, fruit in ipairs(fruits) do
        if Functions.shovelFruit(fruit) then
            shoveledCount = shoveledCount + 1
            task.wait(0.1)
        end
    end
    
    return shoveledCount
end

-- Auto shovel selected trees
function Functions.autoShovelSelectedTrees()
    local selected = Functions.getSelectedTrees()
    if #selected == 0 then return 0 end
    
    local totalShoveled = 0
    for _, treeName in ipairs(selected) do
        totalShoveled = totalShoveled + Functions.autoShovelTree(treeName)
        task.wait(0.2)
    end
    
    return totalShoveled
end

-- Set weight threshold
function Functions.setWeightThreshold(newThreshold, OrionLib)
    if type(newThreshold) == "number" and newThreshold >= 0 then
        weightThreshold = newThreshold
        if OrionLib then
            OrionLib:MakeNotification({
                Name = "Weight Threshold Updated",
                Content = string.format("New threshold: %d", weightThreshold),
                Time = 3
            })
        end
        return true
    end
    return false
end

-- Toggle auto shovel
function Functions.toggleAutoShovel(OrionLib)
    autoShovelEnabled = not autoShovelEnabled
    
    if autoShovelEnabled then
        if autoShovelConnection then
            autoShovelConnection:Disconnect()
        end
        autoShovelConnection = Functions.autoShovelSelectedLoop()
        
        if OrionLib then
            OrionLib:MakeNotification({
                Name = "Auto Shovel Enabled",
                Content = string.format("Automatically shoveling fruits below %dkg...", weightThreshold),
                Time = 3
            })
        end
    else
        if autoShovelConnection then
            autoShovelConnection:Disconnect()
            autoShovelConnection = nil
        end
        
        if OrionLib then
            OrionLib:MakeNotification({
                Name = "Auto Shovel Disabled",
                Content = "Auto shovel stopped",
                Time = 3
            })
        end
    end
    
    return autoShovelEnabled
end

-- Auto shovel loop
function Functions.autoShovelSelectedLoop()
    return RunService.Heartbeat:Connect(function()
        if autoShovelEnabled and Functions.getSelectedTreesCount() > 0 then
            Functions.autoShovelSelectedTrees()
            task.wait(2)
        end
    end)
end

-- ===========AUTO MIDDLE PETS===============

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
