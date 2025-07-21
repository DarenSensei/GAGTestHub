-- ========================================
-- AUTOBUY FUNCTIONS (EXTERNAL)
-- ========================================

local AutoBuy = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Remote Events
local BuyPetEgg = ReplicatedStorage.GameEvents.BuyPetEgg
local BuyGearStock = ReplicatedStorage.GameEvents.BuyGearStock
local BuySeedStock = ReplicatedStorage.GameEvents.BuySeedStock

-- Auto Buy States
AutoBuy.states = {
    seed = false,
    gear = false,
    egg = false
}

-- Selected Items Storage
AutoBuy.selectedItems = {
    eggs = {},
    gear = {},
    seeds = {}
}

-- Item Lists
AutoBuy.eggOptions = {
    "None",
    "Common Egg",
    "Common Summer Egg", 
    "Rare Summer Egg",
    "Mythical Egg",
    "Paradise Egg",
    "Bug Egg"
}

AutoBuy.gearOptions = {
    "None",
    "Watering Can",
    "Trowel",
    "Recall Wrench",
    "Basic Sprinkler",
    "Advanced Sprinkler",
    "Godly Sprinkler",
    "Magnifying Glass",
    "Tanning Mirror",
    "Master Sprinkler",
    "Cleaning Spray",
    "Favorite Tool",
    "Harvest Tool",
    "Friendship Pot",
    "Medium Toy",
    "Medium Treat",
    "Levelup Lollipop"
}

AutoBuy.seedOptions = {
    "None",
    "Carrot",
    "Strawberry",
    "Blueberry",
    "Orange Tulip",
    "Tomato",
    "Corn",
    "Daffodil",
    "Watermelon",
    "Pumpkin",
    "Apple",
    "Bamboo",
    "Coconut",
    "Cactus",
    "Dragon Fruit",
    "Mango",
    "Grape",
    "Mushroom",
    "Pepper",
    "Cacao",
    "Beanstalk",
    "Ember Lily",
    "Sugar Apple",
    "Burning Bud",
    "Giant Pinecone"
}

-- Safe function call helper
function AutoBuy.safeCall(func, funcName, ...)
    if func then
        local success, result = pcall(func, ...)
        if success then
            return result
        else
            warn("Error calling " .. funcName .. ": " .. tostring(result))
        end
    end
    return nil
end

-- Auto Buy Functions
function AutoBuy.buyEggs()
    if not AutoBuy.states.egg then return end
    
    for _, eggName in pairs(AutoBuy.selectedItems.eggs) do
        if eggName ~= "None" then
            local success, error = pcall(function()
                BuyPetEgg:FireServer(eggName)
            end)
            if not success then
                warn("Failed to buy egg " .. eggName .. ": " .. tostring(error))
            end
        end
    end
end

function AutoBuy.buyGear()
    if not AutoBuy.states.gear then return end
    
    for _, gearName in pairs(AutoBuy.selectedItems.gear) do
        if gearName ~= "None" then
            local success, error = pcall(function()
                BuyGearStock:FireServer(gearName)
            end)
            if not success then
                warn("Failed to buy gear " .. gearName .. ": " .. tostring(error))
            end
        end
    end
end

function AutoBuy.buySeeds()
    if not AutoBuy.states.seed then return end
    
    for _, seedName in pairs(AutoBuy.selectedItems.seeds) do
        if seedName ~= "None" then
            local success, error = pcall(function()
                BuySeedStock:FireServer(seedName)
            end)
            if not success then
                warn("Failed to buy seed " .. seedName .. ": " .. tostring(error))
            end
        end
    end
end

-- Main Auto Buy Function
function AutoBuy.run()
    AutoBuy.buyEggs()
    AutoBuy.buySeeds()
    AutoBuy.buyGear()
end

-- Set selected items functions
function AutoBuy.setSelectedEggs(selectedValues)
    AutoBuy.selectedItems.eggs = {}
    
    if selectedValues and #selectedValues > 0 then
        local hasNone = false
        for _, value in pairs(selectedValues) do
            if value == "None" then
                hasNone = true
                break
            end
        end
        
        if not hasNone then
            for _, eggName in pairs(selectedValues) do
                table.insert(AutoBuy.selectedItems.eggs, eggName)
            end
        end
    end
    
    return #AutoBuy.selectedItems.eggs
end

function AutoBuy.setSelectedSeeds(selectedValues)
    AutoBuy.selectedItems.seeds = {}
    
    if selectedValues and #selectedValues > 0 then
        local hasNone = false
        for _, value in pairs(selectedValues) do
            if value == "None" then
                hasNone = true
                break
            end
        end
        
        if not hasNone then
            for _, seedName in pairs(selectedValues) do
                table.insert(AutoBuy.selectedItems.seeds, seedName)
            end
        end
    end
    
    return #AutoBuy.selectedItems.seeds
end

function AutoBuy.setSelectedGear(selectedValues)
    AutoBuy.selectedItems.gear = {}
    
    if selectedValues and #selectedValues > 0 then
        local hasNone = false
        for _, value in pairs(selectedValues) do
            if value == "None" then
                hasNone = true
                break
            end
        end
        
        if not hasNone then
            for _, gearName in pairs(selectedValues) do
                table.insert(AutoBuy.selectedItems.gear, gearName)
            end
        end
    end
    
    return #AutoBuy.selectedItems.gear
end

-- Toggle state functions
function AutoBuy.toggleEgg(state)
    AutoBuy.states.egg = state
end

function AutoBuy.toggleSeed(state)
    AutoBuy.states.seed = state
end

function AutoBuy.toggleGear(state)
    AutoBuy.states.gear = state
end

-- Auto Buy Loop - Runs every 5 seconds
function AutoBuy.startLoop()
    spawn(function()
        while true do
            wait(0.5) -- 5 second interval
            AutoBuy.run()
        end
    end)
end

return AutoBuy
