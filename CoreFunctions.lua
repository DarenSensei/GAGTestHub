-- Complete CoreFunctions for Grow A Garden Script Loader
-- External Module for MAIN
local CoreFunctions = {}

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

local LocalPlayer = Players.LocalPlayer
local Farms = workspace.Farm

--// Mutation Data
local Mutations = {
    Amber = 10, AncientAmber = 50, Aurora = 90, Bloodlit = 5, Burnt = 4,
    Celestial = 120, Ceramic = 30, Chakra = 15, Chilled = 2, Choc = 2,
    Clay = 5, Cloudtouched = 5, Cooked = 10, Corrupt = 20, Dawnbound = 150, Disco = 125,
    Drenched = 5, Eclipsed = 15, Enlightened = 35, FoxfireChakra = 90,
    Friendbound = 70, Frozen = 10, Galactic = 120, Gold = 20, Heavenly = 5,
    HoneyGlazed = 5, Infected = 75, Molten = 25, Moonlit = 2, Meteoric = 125,
    OldAmber = 20, Paradisal = 100, Plasma = 5, Pollinated = 3, Radioactive = 80,
    Rainbow = 50, Sandy = 3, Shocked = 100, Sundried = 85, Tempestuous = 19,
    Toxic = 12, Tranquil = 20, Twisted = 5, Verdant = 5, Voidtouched = 135,
    Wet = 2, Windstruck = 2, Wiltproof = 4, Zombified = 25
}

--// Configuration
local selectedCrops = {}
local whitelistMutations = {}
local blacklistMutations = {}
local autoHarvestEnabled = false
local autoHarvestConnection = nil

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

-- Auto Shovel Variables
local selectedCrops = {}
local targetFruitWeight = 30
local autoShovelEnabled = false
local autoShovelConnection = nil

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

-- ==========================================
-- AUTO-BUY FUNCTIONS
-- ==========================================

function CoreFunctions.toggleAutoBuyZen(enabled)
    autoBuyZenEnabled = enabled
    
    if enabled then
        if zenBuyConnection then zenBuyConnection:Disconnect() end
        zenBuyConnection = RunService.Heartbeat:Connect(function()
            if autoBuyZenEnabled then
                CoreFunctions.buyAllZenItems()
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

function CoreFunctions.toggleAutoBuyMerchant(enabled)
    autoBuyMerchantEnabled = enabled
    
    if enabled then
        if merchantBuyConnection then merchantBuyConnection:Disconnect() end
        merchantBuyConnection = RunService.Heartbeat:Connect(function()
            if autoBuyMerchantEnabled then
                CoreFunctions.buyAllMerchantItems()
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

function CoreFunctions.buyAllZenItems()
    if not BuyEventShopStock then return end
    for _, item in pairs(zenItems) do
        pcall(function()
            BuyEventShopStock:FireServer(item)
        end)
    end
end

function CoreFunctions.buyAllMerchantItems()
    if not BuyTravelingMerchantShopStock then return end
    for _, item in pairs(merchantItems) do
        pcall(function()
            BuyTravelingMerchantShopStock:FireServer(item)
        end)
    end
end

-- ==========================================
-- SHOVEL FUNCTIONS
-- ==========================================

function CoreFunctions.autoEquipShovel()
    if not player.Character then return false end
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return false end
    
    local shovel = backpack:FindFirstChild(shovelName)
    if shovel then
        shovel.Parent = player.Character
        return true
    end
    return false
end

function CoreFunctions.getCurrentFarm()
    local farm = Workspace:FindFirstChild("Farm")
    return farm and farm:FindFirstChild("Farm")
end

function CoreFunctions.getFruitsToRemove()
    local farm = CoreFunctions.getCurrentFarm()
    if not farm or not farm:FindFirstChild("Important") or not farm.Important:FindFirstChild("Plants_Physical") then
        return {}
    end
    
    local fruitsToRemove = {}
    local selectedCount = 0
    for _ in pairs(selectedCrops) do selectedCount = selectedCount + 1 end
    
    for _, plant in pairs(farm.Important.Plants_Physical:GetChildren()) do
        if not plant or not plant.Name then continue end
        
        local shouldProcess = selectedCount == 0 or selectedCrops[plant.Name]
        
        if shouldProcess and plant:FindFirstChild("Fruits") then
            for _, fruit in pairs(plant.Fruits:GetChildren()) do
                -- Skip plant Base
                if fruit.Name == "Base" and fruit.Parent == plant then continue end
                
                -- NEW: Skip fruits with LockBillboardGui (locked fruits)
                if fruit:FindFirstChild("LockBillboardGui") then continue end
                
                local fruitWeight = fruit:FindFirstChild("Weight")
                local fruitPrimaryPart = fruit.PrimaryPart
                local fruitBase = fruit:FindFirstChild("Base")
                local fruitPrimaryPartChild = fruit:FindFirstChild("PrimaryPart")
                
                if fruitWeight and (fruitPrimaryPart or fruitBase or fruitPrimaryPartChild) then
                    if fruitWeight.Value < targetFruitWeight then
                        local partsToRemove = {}
                        
                        if fruitPrimaryPart then
                            table.insert(partsToRemove, {part = fruitPrimaryPart, partType = "PrimaryPart(Property)"})
                        end
                        
                        if fruitPrimaryPartChild then
                            table.insert(partsToRemove, {part = fruitPrimaryPartChild, partType = "PrimaryPart(Child)"})
                        end
                        
                        if fruitBase then
                            table.insert(partsToRemove, {part = fruitBase, partType = "Base"})
                        end
                        
                        if #partsToRemove > 0 then
                            table.insert(fruitsToRemove, {
                                fruit = fruit,
                                fruitWeight = fruitWeight.Value,
                                cropType = plant.Name,
                                partsToRemove = partsToRemove
                            })
                        end
                    end
                end
            end
        end
    end
    
    return fruitsToRemove
end

function CoreFunctions.removeFruit(fruitData)
    if not fruitData.fruit or not fruitData.fruit.Parent then return 0 end
    if not fruitData.partsToRemove or #fruitData.partsToRemove == 0 then return 0 end
    
    local shovel = player.Character:FindFirstChild(shovelName)
    if not shovel or not RemoveItem then return 0 end
    
    local successCount = 0
    
    for _, partData in pairs(fruitData.partsToRemove) do
        pcall(function()
            if partData.part and partData.part.Parent and partData.part.Parent == fruitData.fruit then
                RemoveItem:FireServer(partData.part)
                successCount = successCount + 1
                task.wait(0.05)
            end
        end)
    end
    
    return successCount
end

function CoreFunctions.autoShovel()
    if not autoShovelEnabled then return end
    
    local fruitsToRemove = CoreFunctions.getFruitsToRemove()
    if #fruitsToRemove == 0 then return end
    
    local deletedCount = 0
    local maxFruitsPerCycle = 5
    local processed = 0
    
    if not CoreFunctions.autoEquipShovel() then return end
    
    for _, fruitData in pairs(fruitsToRemove) do
        if processed >= maxFruitsPerCycle then break end
        
        local partsRemoved = CoreFunctions.removeFruit(fruitData)
        if partsRemoved > 0 then
            deletedCount = deletedCount + 1
            processed = processed + 1
        end
        
        task.wait(0.1)
    end
    
    -- Return shovel to backpack
    local equippedShovel = player.Character:FindFirstChild(shovelName)
    if equippedShovel then
        equippedShovel.Parent = player.Backpack
    end
end

function CoreFunctions.getCropTypes()
    local farm = CoreFunctions.getCurrentFarm()
    if not farm or not farm:FindFirstChild("Important") or not farm.Important:FindFirstChild("Plants_Physical") then
        return {"All Plants"}
    end
    
    local cropTypes = {"All Plants"}
    local addedTypes = {}
    
    for _, plant in pairs(farm.Important.Plants_Physical:GetChildren()) do
        if not addedTypes[plant.Name] then
            table.insert(cropTypes, plant.Name)
            addedTypes[plant.Name] = true
        end
    end
    
    return cropTypes
end

function CoreFunctions.toggleAutoShovel(enabled)
    autoShovelEnabled = enabled
    
    if enabled then
        if not RemoveItem then
            return false, "RemoveItem event not found!"
        end
        
        if autoShovelConnection then autoShovelConnection:Disconnect() end
        
        -- NEW: Continuous loop instead of single run
        autoShovelConnection = RunService.Heartbeat:Connect(function()
            while autoShovelEnabled do
                CoreFunctions.autoShovel()
                task.wait(3) -- Wait 3 seconds between cycles
            end
        end)
        
        return true, string.format("Auto Shovel Started (Continuous Loop) - Removing fruits below %.1fkg", targetFruitWeight)
    else
        if autoShovelConnection then
            autoShovelConnection:Disconnect()
            autoShovelConnection = nil
        end
        
        return true, "Auto Shovel Stopped"
    end
end

-- ==========================================
-- AUTO COLLECT
-- ==========================================

--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Functions
function CoreFunctions.getCurrentFarm()
    local farm = workspace:FindFirstChild("Farm")
    if not farm then return nil end
    
    for _, Farm in next, farm:GetChildren() do
        local Important = Farm:FindFirstChild("Important")
        if Important then
            local Data = Important:FindFirstChild("Data")
            if Data then
                local Owner = Data:FindFirstChild("Owner")
                if Owner and Owner.Value == LocalPlayer.Name then
                    return Farm
                end
            end
        end
    end
    return nil
end

function CoreFunctions.canHarvest(Plant)
    local Prompt = Plant:FindFirstChild("ProximityPrompt", true)
    if not Prompt then return false end
    
    -- Check if the prompt is actually enabled (meaning the plant is ready)
    if not Prompt.Enabled then return false end
    
    -- Additional check: see if the plant has fruits ready to harvest
    local Fruits = Plant:FindFirstChild("Fruits")
    if Fruits then
        local fruitsChildren = Fruits:GetChildren()
        if #fruitsChildren == 0 then return false end
    end
    
    return true
end

function CoreFunctions.getPlantMutations(Plant)
    local mutationList = {}
    for mutation, _ in pairs(Mutations) do
        if Plant:GetAttribute(mutation) == true then
            table.insert(mutationList, mutation)
        end
    end
    return mutationList
end

function CoreFunctions.isTargetPlant(Plant)
    local selectedCount = 0
    for _ in pairs(selectedCrops) do selectedCount = selectedCount + 1 end
    
    -- Check if plant matches selected crops
    local shouldProcess = selectedCount == 0 or selectedCrops[Plant.Name]
    if not shouldProcess then return false end
    
    -- Check mutations
    local mutations = CoreFunctions.getPlantMutations(Plant)
    
    -- Check whitelist (if specified)
    local whitelistCount = 0
    for _ in pairs(whitelistMutations) do whitelistCount = whitelistCount + 1 end
    
    if whitelistCount > 0 then
        local hasWhitelistMutation = false
        for _, mutation in ipairs(mutations) do
            if whitelistMutations[mutation] then
                hasWhitelistMutation = true
                break
            end
        end
        if not hasWhitelistMutation then return false end
    end
    
    -- Check blacklist
    for _, mutation in ipairs(mutations) do
        if blacklistMutations[mutation] then
            return false
        end
    end
    
    return true
end

function CoreFunctions.getHarvestTarget(Fruit)
    -- Try to find PrimaryPart first
    if Fruit.PrimaryPart then
        return Fruit.PrimaryPart
    end
    
    -- If no PrimaryPart, try to find Base
    local Base = Fruit:FindFirstChild("Base")
    if Base then
        return Base
    end
    
    -- If neither found, return nil
    return nil
end

function CoreFunctions.collectHarvestable(Parent, Plants)
    for _, Plant in next, Parent:GetChildren() do
        local Fruits = Plant:FindFirstChild("Fruits")
        if Fruits then
            CoreFunctions.collectHarvestable(Fruits, Plants)
        end
        
        if CoreFunctions.canHarvest(Plant) and CoreFunctions.isTargetPlant(Plant) then
            table.insert(Plants, Plant)
        end
    end
    return Plants
end

function CoreFunctions.getCropsToHarvest()
    local Plants = {}
    local MyFarm = CoreFunctions.getCurrentFarm()
    if not MyFarm then return Plants end
    
    local Important = MyFarm:FindFirstChild("Important")
    if not Important then return Plants end
    
    local PlantsPhysical = Important:FindFirstChild("Plants_Physical")
    if not PlantsPhysical then return Plants end
    
    return CoreFunctions.collectHarvestable(PlantsPhysical, Plants)
end

function CoreFunctions.harvestPlant(Plant)
    local Prompt = Plant:FindFirstChild("ProximityPrompt", true)
    if Prompt and Prompt.Enabled then -- Only harvest if prompt is enabled (plant is ready)
        
        -- Method 1: Try setting MaxActivationDistance to a very large number
        local originalMaxDistance = Prompt.MaxActivationDistance
        Prompt.MaxActivationDistance = 9999999
        
        local success = pcall(function()
            fireproximityprompt(Prompt)
        end)
        
        -- Restore original distance
        Prompt.MaxActivationDistance = originalMaxDistance
        
        if success then
            return true
        end
        
        -- Method 2: Try moving the prompt closer temporarily
        local Players = game:GetService("Players")
        local LocalPlayer = Players.LocalPlayer
        local character = LocalPlayer.Character
        
        if character and character:FindFirstChild("HumanoidRootPart") then
            local humanoidRootPart = character.HumanoidRootPart
            local promptParent = Prompt.Parent
            local originalParent = promptParent.Parent
            local originalCFrame = promptParent.CFrame
            
            -- Temporarily move the prompt's parent close to player
            if promptParent and promptParent:IsA("BasePart") then
                promptParent.CFrame = humanoidRootPart.CFrame + Vector3.new(0, 0, -5)
                
                task.wait(0.05)
                fireproximityprompt(Prompt)
                task.wait(0.05)
                
                -- Move it back
                promptParent.CFrame = originalCFrame
                return true
            end
        end
        
        -- Method 3: Fallback - just try firing it normally
        fireproximityprompt(Prompt)
        return true
    end
    return false
end

function CoreFunctions.autoHarvest()
    if not autoHarvestEnabled then return end
    
    local Plants = CoreFunctions.getCropsToHarvest()
    if #Plants == 0 then return end
    
    local harvestedCount = 0
    local maxPlantsPerCycle = 50
    
    for i, Plant in next, Plants do
        if i > maxPlantsPerCycle then break end
        
        if CoreFunctions.harvestPlant(Plant) then
            harvestedCount = harvestedCount + 1
        end
    end
end

function CoreFunctions.getCropTypes()
    local farm = workspace:FindFirstChild("Farm")
    if not farm then return {"All Plants"} end
    
    local MyFarm = CoreFunctions.getCurrentFarm()
    if not MyFarm then return {"All Plants"} end
    
    local Important = MyFarm:FindFirstChild("Important")
    if not Important then return {"All Plants"} end
    
    local PlantsPhysical = Important:FindFirstChild("Plants_Physical")
    if not PlantsPhysical then return {"All Plants"} end
    
    local cropTypes = {"All Plants"}
    local addedTypes = {}
    
    for _, plant in pairs(PlantsPhysical:GetChildren()) do
        if plant.Name and not addedTypes[plant.Name] then
            table.insert(cropTypes, plant.Name)
            addedTypes[plant.Name] = true
        end
    end
    
    return cropTypes
end

function CoreFunctions.getMutationTypes()
    local mutationList = {}
    for mutation, _ in pairs(Mutations) do
        table.insert(mutationList, mutation)
    end
    table.sort(mutationList)
    return mutationList
end

function CoreFunctions.setSelectedCrops(crops)
    selectedCrops = crops or {}
end

function CoreFunctions.setWhitelistMutations(mutations)
    whitelistMutations = mutations or {}
end

function CoreFunctions.setBlacklistMutations(mutations)
    blacklistMutations = mutations or {}
end

function CoreFunctions.getAutoHarvestStatus()
    return autoHarvestEnabled
end

function CoreFunctions.toggleAutoHarvest(enabled)
    autoHarvestEnabled = enabled
    
    if enabled then
        if autoHarvestConnection then 
            autoHarvestConnection:Disconnect() 
            autoHarvestConnection = nil
        end
        
        autoHarvestConnection = task.spawn(function()
            while autoHarvestEnabled do
                CoreFunctions.autoHarvest()
                task.wait(2)
            end
        end)
        
        return true, "Auto Harvest Started"
    else
        if autoHarvestConnection then
            task.cancel(autoHarvestConnection)
            autoHarvestConnection = nil
        end
        autoHarvestEnabled = false
        
        return true, "Auto Harvest Stopped"
    end
end
-- ==========================================
-- SPRINKLER FUNCTIONS
-- ==========================================

function CoreFunctions.deleteSprinklers(sprinklerArray, OrionLib)
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
    CoreFunctions.autoEquipShovel()
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

-- Sprinkler selection helper functions
function CoreFunctions.getSprinklerTypes()
    return sprinklerTypes
end

function CoreFunctions.addSprinklerToSelection(sprinklerName)
    for i, sprinkler in ipairs(selectedSprinklers) do
        if sprinkler == sprinklerName then
            return false -- Already exists
        end
    end
    table.insert(selectedSprinklers, sprinklerName)
    return true
end

function CoreFunctions.removeSprinklerFromSelection(sprinklerName)
    for i, sprinkler in ipairs(selectedSprinklers) do
        if sprinkler == sprinklerName then
            table.remove(selectedSprinklers, i)
            return true
        end
    end
    return false
end

function CoreFunctions.setSelectedSprinklers(sprinklerArray)
    selectedSprinklers = sprinklerArray or {}
end

function CoreFunctions.getSelectedSprinklers()
    return selectedSprinklers
end

function CoreFunctions.clearSelectedSprinklers()
    selectedSprinklers = {}
end

function CoreFunctions.isSprinklerSelected(sprinklerName)
    for _, sprinkler in ipairs(selectedSprinklers) do
        if sprinkler == sprinklerName then
            return true
        end
    end
    return false
end

function CoreFunctions.getSelectedSprinklersCount()
    return #selectedSprinklers
end

function CoreFunctions.getSelectedSprinklersString()
    if #selectedSprinklers == 0 then
        return "None"
    end
    local selectionText = table.concat(selectedSprinklers, ", ")
    return #selectionText > 50 and (selectionText:sub(1, 47) .. "...") or selectionText
end
-- ==========================================
-- FARM MANAGEMENT FUNCTIONS
-- ==========================================

function CoreFunctions.removeFarms(OrionLib)
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

-- ==========================================
-- UTILITY FUNCTIONS
-- ==========================================

function CoreFunctions.serverHop()
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

function CoreFunctions.copyDiscordLink()
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

-- ==========================================
-- AUTO SELL
-- ==========================================

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Variables
local player = Players.LocalPlayer
local targetPosition = Vector3.new(86.58466339111328, 2.9999997615814, 0.5647135376930237)
local Sell_Inventory = ReplicatedStorage.GameEvents.Sell_Inventory

-- Function to teleport player
function CoreFunctions.teleportTo(position)
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        player.Character.HumanoidRootPart.CFrame = CFrame.new(position)
    end
end

-- Function to get current position
function CoreFunctions.getCurrentPosition()
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        return player.Character.HumanoidRootPart.Position
    end
    return nil
end

-- Auto sell function
function CoreFunctions.performAutoSell()
    -- Save current position
    local originalPosition = CoreFunctions.getCurrentPosition()
    if not originalPosition then
        return
    end
    
    -- Teleport to sell location
    CoreFunctions.teleportTo(targetPosition)
    
    -- Wait a brief moment for teleport to complete
    wait(0.3)
    
    -- Fire sell event
    Sell_Inventory:FireServer()
    
    -- Wait a brief moment
    wait(0.1)
    
    -- Return to original position
    CoreFunctions.teleportTo(originalPosition)
end

-- ==========================================
-- CONFIGURATION GETTERS/SETTERS
-- ==========================================

function CoreFunctions.setSelectedCrops(crops)
    selectedCrops = crops or {}
end

function CoreFunctions.getSelectedCrops()
    return selectedCrops
end

function CoreFunctions.setTargetFruitWeight(weight)
    if weight and weight > 0 then
        targetFruitWeight = weight
        return true
    end
    return false
end

function CoreFunctions.getTargetFruitWeight()
    return targetFruitWeight
end

function CoreFunctions.getAutoShovelStatus()
    return autoShovelEnabled
end

function CoreFunctions.getAutoBuyZenStatus()
    return autoBuyZenEnabled
end

function CoreFunctions.getAutoBuyMerchantStatus()
    return autoBuyMerchantEnabled
end

-- ==========================================
-- CLEANUP FUNCTION
-- ==========================================

function CoreFunctions.cleanup()
    -- Cleanup auto-buy connections
    if zenBuyConnection then
        zenBuyConnection:Disconnect()
        zenBuyConnection = nil
    end
    if merchantBuyConnection then
        merchantBuyConnection:Disconnect()
        merchantBuyConnection = nil
    end
    
    -- Cleanup auto-shovel connection
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
    
    -- Reset states
    autoBuyZenEnabled = false
    autoBuyMerchantEnabled = false
    autoShovelEnabled = false
end

-- ==========================================
-- EXPORT CONFIGURATION TABLES
-- ==========================================

CoreFunctions.sprinklerTypes = sprinklerTypes
CoreFunctions.zenItems = zenItems
CoreFunctions.merchantItems = merchantItems
CoreFunctions.selectedPets = selectedPets
CoreFunctions.excludedPets = excludedPets
CoreFunctions.excludedPetESPs = excludedPetESPs
CoreFunctions.allPetsSelected = allPetsSelected
CoreFunctions.currentPetsList = currentPetsList

return CoreFunctions
