-- Main GAGSL Hub Script (FIXED UI ERRORS)
repeat task.wait() until game:IsLoaded()

-- Safe loading function with error handling
local function safeLoad(url, name)
    local success, result = pcall(function()
        local response = game:HttpGet(url)
        if not response or response == "" then
            error("Empty response from " .. name)
        end
        local loadedFunction = loadstring(response)
        if not loadedFunction then
            error("Failed to compile " .. name)
        end
        return loadedFunction()
    end)
    
    if not success then
        warn("Failed to load " .. name .. ": " .. tostring(result))
        return nil
    end
    
    return result
end

-- Load external functions with error handling
local CoreFunctions = safeLoad("https://raw.githubusercontent.com/DarenSensei/GAGTestHub/refs/heads/main/CoreFunctions.lua", "CoreFunctions")
local PetFunctions = safeLoad("https://raw.githubusercontent.com/DarenSensei/GAGTestHub/refs/heads/main/PetMiddleFunctions.lua", "PetFunctions")
local OrionLib = safeLoad("https://raw.githubusercontent.com/YuraScripts/GrowAFilipinoy/refs/heads/main/TEST.lua", "OrionLib")
local AutoBuy = safeLoad("https://raw.githubusercontent.com/DarenSensei/GAGTestHub/refs/heads/main/AutoBuy.lua", "AutoBuy")

-- Check if all dependencies loaded successfully
if not CoreFunctions then
    error("Failed to load CoreFunctions - script cannot continue")
end

if not PetFunctions then
    error("Failed to load PetFunctions - script cannot continue")
end

if not OrionLib then
    error("Failed to load OrionLib - script cannot continue")
end

-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

-- Variables initialization
local selectedPets = {}
local excludedPets = {}
local excludedPetESPs = {}
local allPetsSelected = false
local autoMiddleEnabled = false
local currentPetsList = {}
local petDropdown = nil
local cropDropdown = nil

-- Sprinkler variables
local sprinklerTypes = {"Basic Sprinkler", "Advanced Sprinkler", "Master Sprinkler", "Godly Sprinkler", "Honey Sprinkler", "Chocolate Sprinkler"}
local selectedSprinklers = {}

-- Auto Shovel variables (FIXED)
local selectedFruitTypes = {}
local weightThreshold = 50
local autoShovelEnabled = false
local autoShovelConnection = nil

-- Auto-buy variables
local autoBuyEnabled = false
local buyConnection = nil

-- Create Orion UI
local Window = OrionLib:MakeWindow({
    Name = "GAGSL Hub (v1.2.1)",
    HidePremium = false,
    IntroText = "Grow A Garden Script Loader",
    SaveConfig = false
})

-- Fade in animation with better error handling
local function fadeInMainTab()
    local success, error = pcall(function()
        local playerGui = player:WaitForChild("PlayerGui", 5)
        if not playerGui then return end
        
        local orionGui = playerGui:WaitForChild("Orion", 5)
        if not orionGui then return end
        
        local mainFrame = orionGui:WaitForChild("Main", 5)
        if not mainFrame then return end
        
        mainFrame.BackgroundTransparency = 1

        local tween = TweenService:Create(
            mainFrame,
            TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { BackgroundTransparency = 0.2 }
        )
        tween:Play()
    end)
    
    if not success then
        warn("Failed to create fade animation: " .. tostring(error))
    end
end

task.delay(1.5, fadeInMainTab)

-- Safe function call wrapper
local function safeCall(func, funcName, ...)
    if not func then
        warn(funcName .. " function not available")
        return nil
    end
    
    local success, result = pcall(func, ...)
    if not success then
        warn("Error calling " .. funcName .. ": " .. tostring(result))
        return nil
    end
    
    return result
end

-- FIXED: Sprinkler helper functions using CoreFunctions
local function getSprinklerTypes()
    return safeCall(CoreFunctions.getSprinklerTypes, "getSprinklerTypes") or sprinklerTypes
end

local function setSelectedSprinklers(selected)
    selectedSprinklers = selected
    safeCall(CoreFunctions.setSelectedSprinklers, "setSelectedSprinklers", selected)
end

local function getSelectedSprinklers()
    return safeCall(CoreFunctions.getSelectedSprinklers, "getSelectedSprinklers") or selectedSprinklers
end

local function clearSelectedSprinklers()
    selectedSprinklers = {}
    safeCall(CoreFunctions.clearSelectedSprinklers, "clearSelectedSprinklers")
end

local function addSprinklerToSelection(sprinklerName)
    local success = safeCall(CoreFunctions.addSprinklerToSelection, "addSprinklerToSelection", sprinklerName)
    if success then
        table.insert(selectedSprinklers, sprinklerName)
    end
    return success
end

local function getSelectedSprinklersCount()
    return safeCall(CoreFunctions.getSelectedSprinklersCount, "getSelectedSprinklersCount") or #selectedSprinklers
end

local function getSelectedSprinklersString()
    return safeCall(CoreFunctions.getSelectedSprinklersString, "getSelectedSprinklersString") or table.concat(selectedSprinklers, ", ")
end

local function refreshPets()
    return safeCall(PetFunctions.refreshPets, "refreshPets") or {}
end

local function selectAllPets()
    safeCall(PetFunctions.selectAllPets, "selectAllPets")
    allPetsSelected = true
end

local function createESPMarker(pet)
    safeCall(PetFunctions.createESPMarker, "createESPMarker", pet)
end

local function removeESPMarker(petId)
    safeCall(PetFunctions.removeESPMarker, "removeESPMarker", petId)
end

local function autoEquipShovel()
    safeCall(CoreFunctions.autoEquipShovel, "autoEquipShovel")
end

local function deleteSprinklers()
    safeCall(CoreFunctions.deleteSprinklers, "deleteSprinklers", selectedSprinklers, OrionLib)
end

local function setupZoneAbilityListener()
    safeCall(PetFunctions.setupZoneAbilityListener, "setupZoneAbilityListener")
end

local function startInitialLoop()
    safeCall(PetFunctions.startInitialLoop, "startInitialLoop")
end

local function cleanup()
    safeCall(PetFunctions.cleanup, "PetFunctions.cleanup")
    safeCall(CoreFunctions.cleanup, "CoreFunctions.cleanup")
    if buyConnection then
        buyConnection:Disconnect()
        buyConnection = nil
    end
    if autoShovelConnection then
        autoShovelConnection:Disconnect()
        autoShovelConnection = nil
    end
end

local function buyAllZenItems()
    safeCall(CoreFunctions.buyAllZenItems, "buyAllZenItems")
end

local function buyAllMerchantItems()
    safeCall(CoreFunctions.buyAllMerchantItems, "buyAllMerchantItems")
end

local function removeFarms()
    safeCall(CoreFunctions.removeFarms, "removeFarms", OrionLib)
end

-- MAIN TAB
local ToolsTab = Window:MakeTab({
    Name = "Main",
    Icon = "rbxassetid://6031280882",
    PremiumOnly = false
})

-- Server info
ToolsTab:AddParagraph("Server Version🌐", tostring(game.PrivateServerId ~= "" and "Private Server" or game.PlaceVersion))

-- Job ID input
ToolsTab:AddTextbox({
    Name = "Join Job ID",
    Default = "",
    TextDisappear = true,
    PlaceholderText = "Paste Job ID & press Enter",
    Callback = function(jobId)
        if jobId and jobId ~= "" then
            local success, error = pcall(function()
                game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, jobId, player)
            end)
            if not success then
                warn("Failed to teleport: " .. tostring(error))
            end
        end
    end
})

-- Copy Job ID
ToolsTab:AddButton({
    Name = "Copy Current Job ID",
    Callback = function()
        if setclipboard then
            setclipboard(game.JobId)
            OrionLib:MakeNotification({
                Name = "Copied!",
                Content = "Current Job ID copied to clipboard.",
                Time = 3
            })
        else
            warn("Clipboard access not available.")
        end
    end
})

-- Rejoin server
ToolsTab:AddButton({
    Name = "Rejoin Server",
    Callback = function()
        local success, error = pcall(function()
            game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
        end)
        if not success then
            warn("Failed to rejoin: " .. tostring(error))
        end
    end
})

-- Server hop
ToolsTab:AddButton({
    Name = "Server Hop",
    Callback = function()
        local foundServer, playerCount = safeCall(CoreFunctions.serverHop, "serverHop")
        if foundServer then
            OrionLib:MakeNotification({
                Name = "Server Found",
                Content = "Found server with " .. tostring(playerCount) .. " players.",
                Time = 3
            })
            task.wait(3)
            local success, error = pcall(function()
                game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, foundServer, player)
            end)
            if not success then
                warn("Failed to server hop: " .. tostring(error))
            end
        else
            OrionLib:MakeNotification({
                Name = "No Servers",
                Content = "Couldn't find a suitable server.",
                Time = 3
            })
        end
    end
})

-- FARM TAB
local Tab = Window:MakeTab({
    Name = "Farm",
    Icon = "rbxassetid://6031280882",
    PremiumOnly = false
})

Tab:AddSection({Name = "INF. Sprinkler"})

-- Sprinkler dropdown
local sprinklerDropdown = Tab:AddDropdown({
    Name = "Select Sprinkler to Delete",
    Default = {},
    Options = (function()
        local options = {"None"}
        for _, sprinklerType in ipairs(getSprinklerTypes()) do
            table.insert(options, sprinklerType)
        end
        return options
    end)(),
    Callback = function(selectedValues)
        clearSelectedSprinklers()
        
        if selectedValues and #selectedValues > 0 then
            local hasNone = false
            for _, value in pairs(selectedValues) do
                if value == "None" then
                    hasNone = true
                    break
                end
            end
            
            if not hasNone then
                for _, sprinklerName in pairs(selectedValues) do
                    addSprinklerToSelection(sprinklerName)
                end
                
                OrionLib:MakeNotification({
                    Name = "Selection Updated",
                    Content = string.format("Selected (%d): %s", 
                        getSelectedSprinklersCount(), 
                        getSelectedSprinklersString()),
                    Time = 3
                })
            else
                OrionLib:MakeNotification({
                    Name = "Selection Cleared",
                    Content = "No sprinklers selected",
                    Time = 2
                })
            end
        end
    end
})

-- Select all sprinklers toggle
Tab:AddToggle({
    Name = "Select All Sprinkler",
    Default = false,
    Callback = function(Value)
        if Value then
            local allSprinklers = getSprinklerTypes()
            setSelectedSprinklers(allSprinklers)
            
            OrionLib:MakeNotification({
                Name = "All Selected",
                Content = string.format("Selected all %d sprinkler types", #allSprinklers),
                Time = 3
            })
        else
            clearSelectedSprinklers()
        end
    end
})

-- Delete sprinkler button
Tab:AddButton({
    Name = "Delete Sprinkler",
    Callback = function()
        local selectedArray = getSelectedSprinklers()
        
        if #selectedArray == 0 then
            OrionLib:MakeNotification({
                Name = "No Selection",
                Content = "Please select sprinkler type(s) first",
                Time = 4
            })
            return
        end
        
        deleteSprinklers()
    end
})

Tab:AddSection({Name = "-PET EXPLOIT-"})

-- Pet exclusion dropdown
petDropdown = Tab:AddDropdown({
    Name = "Select Pets to Exclude",
    Default = {},
    Options = {"None"},
    Callback = function(selectedValues)
        -- Safely get current data
        local success, error = pcall(function()
            if PetFunctions then
                excludedPets = safeCall(PetFunctions.getExcludedPets, "getExcludedPets") or {}
                currentPetsList = safeCall(PetFunctions.getCurrentPetsList, "getCurrentPetsList") or {}
            end
            
            -- Clear existing ESP markers
            for petId, _ in pairs(excludedPets) do
                removeESPMarker(petId)
            end
            excludedPets = {}
            
            if selectedValues and #selectedValues > 0 then
                local hasNone = false
                for _, value in pairs(selectedValues) do
                    if value == "None" then
                        hasNone = true
                        break
                    end
                end
                
                if not hasNone then
                    for _, petName in pairs(selectedValues) do
                        local selectedPet = currentPetsList[petName]
                        if selectedPet then
                            excludedPets[selectedPet.id] = true
                            createESPMarker(selectedPet)
                        end
                    end
                end
            end
            
            -- Update PetFunctions
            if PetFunctions and PetFunctions.setExcludedPets then
                PetFunctions.setExcludedPets(excludedPets)
            end
        end)
    end
})

-- Set up dropdown reference safely
if PetFunctions and PetFunctions.setPetDropdown then
    pcall(function()
        PetFunctions.setPetDropdown(petDropdown)
    end)
end

-- Refresh and select all pets
Tab:AddButton({
    Name = "Refresh & Auto Select All Pets",
    Callback = function()
        local newPets = refreshPets()
        selectAllPets()
        
        if petDropdown and petDropdown.ClearAll then
            pcall(function()
                petDropdown:ClearAll()
            end)
        end
        
        OrionLib:MakeNotification({
            Name = "Pets Refreshed & Selected",
            Content = "Found " .. #newPets .. " pets and selected all for auto middle.",
            Time = 3
        })
    end
})

-- Auto middle toggle
Tab:AddToggle({
    Name = "Auto Middle Pets",
    Default = false,
    Callback = function(value)
        autoMiddleEnabled = value
        if PetFunctions and PetFunctions.setAutoMiddleEnabled then
            pcall(function()
                PetFunctions.setAutoMiddleEnabled(value)
            end)
        end
        if value then
            setupZoneAbilityListener()
            startInitialLoop()
        else
            cleanup()
        end
    end
})

Tab:AddSection({Name = "AUTO SHOVEL"})

cropDropdown = Tab:AddDropdown({
    Name = "Select Crops to Monitor",
    Default = {"All Plants"},
    Options = safeCall(CoreFunctions.getCropTypes, "getCropTypes") or {"All Plants"},
    Callback = function(selectedValues)
        local selectedCrops = {}
        
        if selectedValues and #selectedValues > 0 then
            local hasAllPlants = false
            for _, value in pairs(selectedValues) do
                if value == "All Plants" then
                    hasAllPlants = true
                    break
                end
            end
            
            if not hasAllPlants then
                for _, cropName in pairs(selectedValues) do
                    selectedCrops[cropName] = true
                end
            end
        end
        
        safeCall(CoreFunctions.setSelectedCrops, "setSelectedCrops", selectedCrops)
    end
})

Tab:AddButton({
    Name = "Refresh Crop List",
    Callback = function()
        local newCropTypes = safeCall(CoreFunctions.getCropTypes, "getCropTypes") or {"All Plants"}
        if cropDropdown and cropDropdown.Refresh then
            pcall(function()
                cropDropdown:Refresh(newCropTypes, true)
            end)
        end
        
        OrionLib:MakeNotification({
            Name = "List Refreshed",
            Content = string.format("Found %d crop types", #newCropTypes - 1),
            Time = 2
        })
    end
})

Tab:AddTextbox({
    Name = "Remove Fruits Below (kg)",
    Default = tostring(safeCall(CoreFunctions.getTargetFruitWeight, "getTargetFruitWeight") or 50),
    TextDisappear = false,
    Callback = function(value)
        local weight = tonumber(value)
        if weight and weight > 0 then
            local success = safeCall(CoreFunctions.setTargetFruitWeight, "setTargetFruitWeight", weight)
            if success then
                OrionLib:MakeNotification({
                    Name = "Weight Updated",
                    Content = string.format("Target weight set to %.1fkg", weight),
                    Time = 2
                })
            end
        else
            OrionLib:MakeNotification({
                Name = "Invalid Weight",
                Content = "Please enter a valid number above 0",
                Time = 3
            })
        end
    end
})

Tab:AddToggle({
    Name = "Enable Auto Shovel",
    Default = safeCall(CoreFunctions.getAutoShovelStatus, "getAutoShovelStatus") or false,
    Callback = function(enabled)
        local success, message = safeCall(CoreFunctions.toggleAutoShovel, "toggleAutoShovel", enabled)
        if success and message then
            OrionLib:MakeNotification({
                Name = "Auto Shovel",
                Content = message,
                Time = 2
            })
        end
    end
})

-- SHOP TAB
local ShopTab = Window:MakeTab({
    Name = "Shop",
    Icon = "rbxassetid://6031280882",
    PremiumOnly = false
})

ShopTab:AddParagraph("Auto Buy", "Auto Buy, Buy even AFK")

-- ===========================================
-- SHOP TAB CREATION
-- ===========================================

ShopTab:AddSection({
    Name = "-Zen Shop-"
})

-- Zen Items Multi-Select Dropdown
local zenItemOptions = {"None"}
if AutoBuy.zenItems and type(AutoBuy.zenItems) == "table" then
    for _, item in pairs(AutoBuy.zenItems) do
        table.insert(zenItemOptions, item)
    end
end

ShopTab:AddDropdown({
    Name = "Select Zen Items to Auto Buy",
    Default = {},
    Options = zenItemOptions,
    Callback = function(selectedValues)
        local success, error = pcall(function()
            if AutoBuy.setSelectedZenItems and type(AutoBuy.setSelectedZenItems) == "function" then
                local count = AutoBuy.setSelectedZenItems(selectedValues)
                if count > 0 then
                    print("Selected " .. count .. " zen items for auto buy")
                end
            else
                warn("AutoBuy.setSelectedZenItems is not a function")
            end
        end)
        if not success then
            warn("Error setting zen items: " .. tostring(error))
        end
    end
})

ShopTab:AddToggle({
    Name = "Auto Buy Zen",
    Default = false,
    Callback = function(Value)
        if AutoBuy.buySelectedZenItems and type(AutoBuy.buySelectedZenItems) == "function" then
            AutoBuy.buySelectedZenItems(Value)
        else
            warn("AutoBuy.buySelectedZenItems is not a function")
        end
        
        if Value then
            OrionLib:MakeNotification({
                Name = "Auto Buy Zen",
                Content = "Zen auto buy enabled!",
                Image = "rbxassetid://4483345998",
                Time = 3
            })
        end
    end
})

-- ===========================================
-- TRAVELING MERCHANT SECTION
-- ===========================================

ShopTab:AddSection({
    Name = "-Traveling Merchant-"
})

-- Merchant Items Multi-Select Dropdown
local merchantItemOptions = {"None"}
if AutoBuy.merchantItems and type(AutoBuy.merchantItems) == "table" then
    for _, item in pairs(AutoBuy.merchantItems) do
        table.insert(merchantItemOptions, item)
    end
end

ShopTab:AddDropdown({
    Name = "Select Merchant Items to Auto Buy",
    Default = {},
    Options = merchantItemOptions,
    Callback = function(selectedValues)
        local success, error = pcall(function()
            if AutoBuy.setSelectedMerchantItems and type(AutoBuy.setSelectedMerchantItems) == "function" then
                local count = AutoBuy.setSelectedMerchantItems(selectedValues)
                if count > 0 then
                    print("Selected " .. count .. " merchant items for auto buy")
                end
            else
                warn("AutoBuy.setSelectedMerchantItems is not a function")
            end
        end)
        if not success then
            warn("Error setting merchant items: " .. tostring(error))
        end
    end
})

ShopTab:AddToggle({
    Name = "Auto Buy Merchant",
    Default = false,
    Callback = function(Value)
        if AutoBuy.buySelectedMerchantItems and type(AutoBuy.buySelectedMerchantItems) == "function" then
            AutoBuy.buySelectedMerchantItems(Value)
        else
            warn("AutoBuy.buySelectedMerchantItems is not a function")
        end
        
        if Value then
            OrionLib:MakeNotification({
                Name = "Auto Buy Merchant",
                Content = "Merchant auto buy enabled!",
                Image = "rbxassetid://4483345998",
                Time = 3
            })
        end
    end
})

-- ===========================================
-- EGG SECTION
-- ===========================================

ShopTab:AddSection({
    Name = "-Pet Eggs-"
})

-- Egg Multi-Select Dropdown
ShopTab:AddDropdown({
    Name = "Select Eggs to Auto Buy",
    Default = {},
    Options = AutoBuy.eggOptions or {"None"},
    Callback = function(selectedValues)
        local success, error = pcall(function()
            if AutoBuy.setSelectedEggs and type(AutoBuy.setSelectedEggs) == "function" then
                local count = AutoBuy.setSelectedEggs(selectedValues)
                if count > 0 then
                    print("Selected " .. count .. " eggs for auto buy")
                end
            else
                warn("AutoBuy.setSelectedEggs is not a function")
            end
        end)
        if not success then
            warn("Error setting eggs: " .. tostring(error))
        end
    end
})

-- Auto Buy Egg Toggle
ShopTab:AddToggle({
    Name = "Auto Buy Eggs",
    Default = false,
    Callback = function(value)
        if AutoBuy.toggleEgg and type(AutoBuy.toggleEgg) == "function" then
            AutoBuy.toggleEgg(value)
        else
            warn("AutoBuy.toggleEgg is not a function")
        end
        
        if value then
            OrionLib:MakeNotification({
                Name = "Auto Buy Eggs",
                Content = "Auto Buy Eggs enabled!",
                Image = "rbxassetid://4483345998",
                Time = 2
            })
        end
    end
})

-- ===========================================
-- SEED SECTION
-- ===========================================

ShopTab:AddSection({
    Name = "-Seeds-"
})

-- Seed Multi-Select Dropdown
ShopTab:AddDropdown({
    Name = "Select Seeds to Auto Buy",
    Default = {},
    Options = AutoBuy.seedOptions or {"None"},
    Callback = function(selectedValues)
        local success, error = pcall(function()
            if AutoBuy.setSelectedSeeds and type(AutoBuy.setSelectedSeeds) == "function" then
                local count = AutoBuy.setSelectedSeeds(selectedValues)
                if count > 0 then
                    print("Selected " .. count .. " seeds for auto buy")
                end
            else
                warn("AutoBuy.setSelectedSeeds is not a function")
            end
        end)
        if not success then
            warn("Error setting seeds: " .. tostring(error))
        end
    end
})

-- Auto Buy Seed Toggle
ShopTab:AddToggle({
    Name = "Auto Buy Seeds",
    Default = false,
    Callback = function(value)
        if AutoBuy.toggleSeed and type(AutoBuy.toggleSeed) == "function" then
            AutoBuy.toggleSeed(value)
        else
            warn("AutoBuy.toggleSeed is not a function")
        end
        
        if value then
            OrionLib:MakeNotification({
                Name = "Auto Buy Seeds",
                Content = "Auto Buy Seeds enabled!",
                Image = "rbxassetid://4483345998",
                Time = 2
            })
        end
    end
})

-- ===========================================
-- GEAR SECTION
-- ===========================================

ShopTab:AddSection({
    Name = "-Gear & Tools-"
})

-- Gear Multi-Select Dropdown
ShopTab:AddDropdown({
    Name = "Select Gear to Auto Buy",
    Default = {},
    Options = AutoBuy.gearOptions or {"None"},
    Callback = function(selectedValues)
        local success, error = pcall(function()
            if AutoBuy.setSelectedGear and type(AutoBuy.setSelectedGear) == "function" then
                local count = AutoBuy.setSelectedGear(selectedValues)
                if count > 0 then
                    print("Selected " .. count .. " gear items for auto buy")
                end
            else
                warn("AutoBuy.setSelectedGear is not a function")
            end
        end)
        if not success then
            warn("Error setting gear: " .. tostring(error))
        end
    end
})

-- Auto Buy Gear Toggle
ShopTab:AddToggle({
    Name = "Auto Buy Gear",
    Default = false,
    Callback = function(value)
        if AutoBuy.toggleGear and type(AutoBuy.toggleGear) == "function" then
            AutoBuy.toggleGear(value)
        else
            warn("AutoBuy.toggleGear is not a function")
        end
        
        if value then
            OrionLib:MakeNotification({
                Name = "Auto Buy Gear",
                Content = "Auto Buy Gear enabled!",
                Image = "rbxassetid://4483345998",
                Time = 2
            })
        end
    end
})

-- Initialize the AutoBuy module
if AutoBuy.init and type(AutoBuy.init) == "function" then
    AutoBuy.init()
else
    warn("AutoBuy.init is not a function or doesn't exist")
end

-- MISC TAB
local MiscTab = Window:MakeTab({
    Name = "Misc",
    Icon = "rbxassetid://6031280882",
    PremiumOnly = false
})

MiscTab:AddParagraph("Performance", "Reduce game lag by removing lag-causing objects.")

-- Reduce lag
MiscTab:AddButton({
    Name = "Reduce Lag",
    Callback = function()
        local success, error = pcall(function()
            repeat
                local lag = game.Workspace:findFirstChild("Lag", true)
                if (lag ~= nil) then
                    lag:remove()
                end
                wait()
            until (game.Workspace:findFirstChild("Lag", true) == nil)
        end)
        
        if success then
            OrionLib:MakeNotification({
                Name = "Lag Reduced",
                Content = "All lag objects have been removed.",
                Time = 3
            })
        else
            warn("Failed to reduce lag: " .. tostring(error))
        end
    end
})

-- Remove farms
MiscTab:AddButton({
    Name = "Remove Farms (Stay close to your farm)",
    Callback = function()
        removeFarms()
    end
})

-- SOCIAL TAB
local SocialTab = Window:MakeTab({
    Name = "Social",
    Icon = "rbxassetid://6031075938",
    PremiumOnly = false
})

SocialTab:AddParagraph("TIKTOK", "@yurahaxyz        |        @yurahayz")
SocialTab:AddParagraph("YOUTUBE", "YUraxYZ")

-- Discord button
SocialTab:AddButton({
    Name = "GAGSL Community Discord",
    Callback = function()
        if setclipboard then
            setclipboard("https://discord.gg/gpR7YQjnFt")
            OrionLib:MakeNotification({
                Name = "Copied!",
                Content = "Discord invite copied to clipboard.",
                Time = 3
            })
        else
            warn("Clipboard access not available.")
        end
    end
})

-- Cleanup on exit
Players.PlayerRemoving:Connect(function(playerLeaving)
    if playerLeaving == Players.LocalPlayer then
        cleanup()
    end
end)

-- Final notification
OrionLib:MakeNotification({
    Name = "GAGSL Hub Loaded",
    Content = "GAGSL Hub loaded with +999 Pogi Points!",
    Time = 4
})
