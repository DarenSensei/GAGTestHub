-- AutoBuy.lua - Complete External AutoBuy Module
-- Handles automatic purchasing for all shop types: Zen Shop, Merchant Shop, Pet Eggs, Gear, and Seeds

local AutoBuy = {}

-- Services
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Private variables for Zen/Merchant shops
local autoBuyZenEnabled = false
local autoBuyMerchantEnabled = false
local zenBuyConnection = nil
local merchantBuyConnection = nil
local selectedZenItems = {}
local selectedMerchantItems = {}

-- Auto Buy States for basic shops
AutoBuy.states = {
    seed = false,
    gear = false,
    egg = false,
    zen = false,
    merchant = false
}

-- Selected Items Storage
AutoBuy.selectedItems = {
    eggs = {},
    gear = {},
    seeds = {},
    zen = {},
    merchant = {}
}

-- Item Lists - Zen Shop
AutoBuy.zenItems = {
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

-- Item Lists - Merchant Shop
AutoBuy.merchantItems = {
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

-- Item Lists - Basic Shops
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

-- Helper function to get remote events safely
local function getRemoteEvent(folderName)
    local folder = ReplicatedStorage:FindFirstChild(folderName)
    return folder or {}
end

-- Get remote events
local function getRemoteEvents()
    local gameEvents = getRemoteEvent("GameEvents")
    return {
        BuyEventShopStock = gameEvents.BuyEventShopStock,
        BuyTravelingMerchantShopStock = gameEvents.BuyTravelingMerchantShopStock,
        BuyPetEgg = gameEvents.BuyPetEgg,
        BuyGearStock = gameEvents.BuyGearStock,
        BuySeedStock = gameEvents.BuySeedStock
    }
end

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

-- ===========================================
-- ZEN SHOP FUNCTIONS (Connection-based)
-- ===========================================

function AutoBuy.toggleAutoBuyZen(enabled)
    autoBuyZenEnabled = enabled
    AutoBuy.states.zen = enabled
    
    if enabled then
        if zenBuyConnection then zenBuyConnection:Disconnect() end
        zenBuyConnection = RunService.Heartbeat:Connect(function()
            if autoBuyZenEnabled then
                AutoBuy.buySelectedZenItems()
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

function AutoBuy.buySelectedZenItems()
    local remotes = getRemoteEvents()
    if not remotes.BuyEventShopStock then return end
    
    local itemsToBuy = #selectedZenItems > 0 and selectedZenItems or AutoBuy.selectedItems.zen
    if #itemsToBuy == 0 then return end
    
    local hasNone = false
    for _, item in pairs(itemsToBuy) do
        if item == "None" then
            hasNone = true
            break
        end
    end
    
    if hasNone then return end
    
    -- Buy selected items
    for _, item in pairs(itemsToBuy) do
        pcall(function()
            remotes.BuyEventShopStock:FireServer(item)
        end)
    end
end

-- ===========================================
-- MERCHANT SHOP FUNCTIONS (Connection-based)
-- ===========================================

function AutoBuy.toggleAutoBuyMerchant(enabled)
    autoBuyMerchantEnabled = enabled
    AutoBuy.states.merchant = enabled
    
    if enabled then
        if merchantBuyConnection then merchantBuyConnection:Disconnect() end
        merchantBuyConnection = RunService.Heartbeat:Connect(function()
            if autoBuyMerchantEnabled then
                AutoBuy.buySelectedMerchantItems()
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

function AutoBuy.buySelectedMerchantItems()
    local remotes = getRemoteEvents()
    if not remotes.BuyTravelingMerchantShopStock then return end
    
    local itemsToBuy = #selectedMerchantItems > 0 and selectedMerchantItems or AutoBuy.selectedItems.merchant
    if #itemsToBuy == 0 then return end
    
    local hasNone = false
    for _, item in pairs(itemsToBuy) do
        if item == "None" then
            hasNone = true
            break
        end
    end
    
    if hasNone then return end
    
    -- Buy selected items
    for _, item in pairs(itemsToBuy) do
        pcall(function()
            remotes.BuyTravelingMerchantShopStock:FireServer(item)
        end)
    end
end

-- ===========================================
-- BASIC SHOP FUNCTIONS (Loop-based)
-- ===========================================

function AutoBuy.buyEggs()
    if not AutoBuy.states.egg then return end
    local remotes = getRemoteEvents()
    if not remotes.BuyPetEgg then return end
    
    for _, eggName in pairs(AutoBuy.selectedItems.eggs) do
        if eggName ~= "None" then
            local success, error = pcall(function()
                remotes.BuyPetEgg:FireServer(eggName)
            end)
            if not success then
                warn("Failed to buy egg " .. eggName .. ": " .. tostring(error))
            end
        end
    end
end

function AutoBuy.buyGear()
    if not AutoBuy.states.gear then return end
    local remotes = getRemoteEvents()
    if not remotes.BuyGearStock then return end
    
    for _, gearName in pairs(AutoBuy.selectedItems.gear) do
        if gearName ~= "None" then
            local success, error = pcall(function()
                remotes.BuyGearStock:FireServer(gearName)
            end)
            if not success then
                warn("Failed to buy gear " .. gearName .. ": " .. tostring(error))
            end
        end
    end
end

function AutoBuy.buySeeds()
    if not AutoBuy.states.seed then return end
    local remotes = getRemoteEvents()
    if not remotes.BuySeedStock then return end
    
    for _, seedName in pairs(AutoBuy.selectedItems.seeds) do
        if seedName ~= "None" then
            local success, error = pcall(function()
                remotes.BuySeedStock:FireServer(seedName)
            end)
            if not success then
                warn("Failed to buy seed " .. seedName .. ": " .. tostring(error))
            end
        end
    end
end

-- ===========================================
-- SETTER FUNCTIONS
-- ===========================================

-- Zen Items Setters (supports both methods)
function AutoBuy.setSelectedZenItems(items)
    selectedZenItems = items or {}
    AutoBuy.selectedItems.zen = selectedZenItems
end

-- Merchant Items Setters (supports both methods)
function AutoBuy.setSelectedMerchantItems(items)
    selectedMerchantItems = items or {}
    AutoBuy.selectedItems.merchant = selectedMerchantItems
end

-- Basic Shop Setters
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

-- ===========================================
-- GETTER FUNCTIONS
-- ===========================================

function AutoBuy.getSelectedZenItems()
    return selectedZenItems
end

function AutoBuy.getSelectedMerchantItems()
    return selectedMerchantItems
end

function AutoBuy.getSelectedEggs()
    return AutoBuy.selectedItems.eggs
end

function AutoBuy.getSelectedSeeds()
    return AutoBuy.selectedItems.seeds
end

function AutoBuy.getSelectedGear()
    return AutoBuy.selectedItems.gear
end

-- ===========================================
-- TOGGLE STATE FUNCTIONS
-- ===========================================

function AutoBuy.toggleEgg(state)
    AutoBuy.states.egg = state
end

function AutoBuy.toggleSeed(state)
    AutoBuy.states.seed = state
end

function AutoBuy.toggleGear(state)
    AutoBuy.states.gear = state
end

-- ===========================================
-- STATUS FUNCTIONS
-- ===========================================

function AutoBuy.isZenAutoBuyEnabled()
    return autoBuyZenEnabled
end

function AutoBuy.isMerchantAutoBuyEnabled()
    return autoBuyMerchantEnabled
end

function AutoBuy.isEggAutoBuyEnabled()
    return AutoBuy.states.egg
end

function AutoBuy.isSeedAutoBuyEnabled()
    return AutoBuy.states.seed
end

function AutoBuy.isGearAutoBuyEnabled()
    return AutoBuy.states.gear
end

-- ===========================================
-- MAIN EXECUTION FUNCTIONS
-- ===========================================

-- Main Auto Buy Function for basic shops (called by loop)
function AutoBuy.run()
    AutoBuy.buyEggs()
    AutoBuy.buySeeds()
    AutoBuy.buyGear()
end

-- Auto Buy Loop - Runs every 0.5 seconds for basic shops
function AutoBuy.startLoop()
    spawn(function()
        while true do
            wait(0.5)
            AutoBuy.run()
        end
    end)
end

-- Manual buy all function
function AutoBuy.buyAll()
    AutoBuy.buySelectedZenItems()
    AutoBuy.buySelectedMerchantItems()
    AutoBuy.buyEggs()
    AutoBuy.buySeeds()
    AutoBuy.buyGear()
end

-- ===========================================
-- CLEANUP AND INITIALIZATION
-- ===========================================

-- Cleanup function
function AutoBuy.cleanup()
    if zenBuyConnection then
        zenBuyConnection:Disconnect()
        zenBuyConnection = nil
    end
    if merchantBuyConnection then
        merchantBuyConnection:Disconnect()
        merchantBuyConnection = nil
    end
    
    -- Reset all states
    autoBuyZenEnabled = false
    autoBuyMerchantEnabled = false
    AutoBuy.states.seed = false
    AutoBuy.states.gear = false
    AutoBuy.states.egg = false
    AutoBuy.states.zen = false
    AutoBuy.states.merchant = false
end

-- Initialize the module
function AutoBuy.init()
    -- Handle player leaving
    game.Players.LocalPlayer.AncestryChanged:Connect(function()
        if not game.Players.LocalPlayer.Parent then
            AutoBuy.cleanup()
        end
    end)
    
    -- Start the loop for basic shops
    AutoBuy.startLoop()
    
    print("Complete AutoBuy Module initialized successfully!")
end

return AutoBuy
