-- GAGSL Hub Script (Wind UI Version) - FIXED
repeat wait() until game:IsLoaded()

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

-- Load Wind UI library
local WindUI = safeLoad("https://raw.githubusercontent.com/YuraScripts/Grow-A-Pinoy/refs/heads/main/WindUI.lua", "WindUI")

if not WindUI then
    error("Failed to load Wind UI - script cannot continue")
end

-- Load external functions with error handling
local CoreFunctions = safeLoad("https://raw.githubusercontent.com/DarenSensei/GrowAFilipino/refs/heads/main/CoreFunctions.lua", "CoreFunctions")
local PetFunctions = safeLoad("https://raw.githubusercontent.com/DarenSensei/GrowAFilipino/refs/heads/main/PetMiddleFunctions.lua", "PetFunctions")
local AutoBuy = safeLoad("https://raw.githubusercontent.com/DarenSensei/GAGTestHub/refs/heads/main/AutoBuy.lua", "AutoBuy")

-- Check if all dependencies loaded successfully
if not CoreFunctions then
    error("Failed to load CoreFunctions - script cannot continue")
end

if not PetFunctions then
    error("Failed to load PetFunctions - script cannot continue")
end

-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

-- Variables initialization
local selectedPets = {}
local includedPets = {}
local allPetsSelected = false
local autoMiddleEnabled = false
local currentPetsList = {}
local petDropdown = nil
local cropDropdown = nil

-- Sprinkler variables
local sprinklerTypes = {"Basic Sprinkler", "Advanced Sprinkler", "Master Sprinkler", "Godly Sprinkler", "Honey Sprinkler", "Chocolate Sprinkler"}
local selectedSprinklers = {}

-- Auto Shovel variables
local selectedFruitTypes = {}
local weightThreshold = 50
local autoShovelEnabled = false
local autoShovelConnection = nil

-- Auto-buy variables
local autoBuyEnabled = false
local buyConnection = nil

-- Create Wind UI Window
local Window = WindUI:CreateWindow({
    Icon = "rbxassetid://124132063885927",
    Title = "Genzura Hub (v1.2.3)",
    Desc = "Made by Yura",
    SubTitle = "Grow A Garden Script Loader",
    TabWidth = 160,
    Size = UDim2.fromOffset(470, 350),
    Acrylic = true,
    Theme = "Dark"
})

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

local function autoEquipShovel()
    safeCall(CoreFunctions.autoEquipShovel, "autoEquipShovel")
end

local function deleteSprinklers()
    safeCall(CoreFunctions.deleteSprinklers, "deleteSprinklers", selectedSprinklers, WindUI)
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

local function removeFarms()
    safeCall(CoreFunctions.removeFarms, "removeFarms", WindUI)
end

-- ===========================================
-- MAIN TAB
-- ===========================================
local MainTab = Window:Tab({ 
    Title = "Main", 
    Icon = "house" 
})

MainTab:Paragraph({
    Title = "📜Changelogs : (v.1.2.3)",
    Desc = "Added : New GUI",
    color = "#c7c0b7",
})

-- Server info section
MainTab:Section({ Title = "Server Information" })

MainTab:Paragraph({
    Title = "Server Version",
    Desc = tostring(" Version : " .. game.PlaceVersion),
    Icon = "server",
})

-- Server controls
MainTab:Section({ Title = "Server Controls" })

MainTab:Input({
    Title = "Join Job ID",
    Desc = "Enter Job ID to teleport",
    Placeholder = "Paste Job ID here...",
    Callback = function(jobId)
        if jobId and jobId ~= "" then
            local success, error = pcall(function()
                game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, jobId, player)
            end)
            if not success then
                WindUI:Notify({
                    Title = "Error",
                    Content = "Failed to teleport: " .. tostring(error),
                    Duration = 5,
                    Icon = "alert-triangle"
                })
            else
                WindUI:Notify({
                    Title = "Teleporting",
                    Content = "Joining server...",
                    Duration = 3,
                    Icon = "zap"
                })
            end
        end
    end
})

MainTab:Button({
    Title = "Copy Current Job ID",
    Desc = "Copy this server's Job ID to clipboard",
    Icon = "copy",
    Callback = function()
        if setclipboard then
            setclipboard(game.JobId)
            WindUI:Notify({
                Title = "Success",
                Content = "Job ID copied to clipboard!",
                Duration = 3,
                Icon = "check"
            })
        else
            WindUI:Notify({
                Title = "Error",
                Content = "Clipboard access not available",
                Duration = 3,
                Icon = "x"
            })
        end
    end
})

MainTab:Button({
    Title = "Rejoin Server",
    Desc = "Rejoin the current server",
    Icon = "refresh-cw",
    Callback = function()
        local success, error = pcall(function()
            game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
        end)
        if not success then
            WindUI:Notify({
                Title = "Error",
                Content = "Failed to rejoin: " .. tostring(error),
                Duration = 5,
                Icon = "alert-triangle"
            })
        end
    end
})

MainTab:Button({
    Title = "Server Hop",
    Desc = "Find and join a different server",
    Icon = "shuffle",
    Callback = function()
        local foundServer, playerCount = safeCall(CoreFunctions.serverHop, "serverHop")
        if foundServer then
            WindUI:Notify({
                Title = "Server Found",
                Content = "Found server with " .. tostring(playerCount) .. " players",
                Duration = 3,
                Icon = "users"
            })
            task.wait(3)
            local success, error = pcall(function()
                game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, foundServer, player)
            end)
            if not success then
                WindUI:Notify({
                    Title = "Error",
                    Content = "Failed to server hop: " .. tostring(error),
                    Duration = 5,
                    Icon = "alert-triangle"
                })
            end
        else
            WindUI:Notify({
                Title = "No Servers",
                Content = "Couldn't find a suitable server",
                Duration = 3,
                Icon = "search-x"
            })
        end
    end
})

-- FARM TAB
local Tab = Window:Tab({
    Title = "Farm",
    Icon = "tractor", -- Using WindUI's lucide icon system
})

Tab:Section({
    Title = "--INF. Sprinkler--"
})

-- Sprinkler dropdown
local sprinklerDropdown = Tab:Dropdown({
    Title = "Select Sprinkler to Delete",
    Values = (function()
        local options = {"None"}
        for _, sprinklerType in ipairs(getSprinklerTypes()) do
            table.insert(options, sprinklerType)
        end
        return options
    end)(),
    Value = {},
    Multi = true,
    AllowNone = true,
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
                
                WindUI:Notify({
                    Title = "Selection Updated",
                    Content = string.format("Selected (%d): %s", 
                        getSelectedSprinklersCount(), 
                        getSelectedSprinklersString()),
                    Duration = 3,
                    Icon = "check-circle"
                })
            else
                WindUI:Notify({
                    Title = "Selection Cleared",
                    Content = "No sprinklers selected",
                    Duration = 2,
                    Icon = "x-circle"
                })
            end
        end
    end
})

-- Select all sprinklers toggle
Tab:Toggle({
    Title = "Select All Sprinkler",
    Value = false,
    Callback = function(Value)
        if Value then
            local allSprinklers = getSprinklerTypes()
            setSelectedSprinklers(allSprinklers)
            
            WindUI:Notify({
                Title = "All Selected",
                Content = string.format("Selected all %d sprinkler types", #allSprinklers),
                Duration = 3,
                Icon = "check-square"
            })
        else
            clearSelectedSprinklers()
        end
    end
})

-- Delete sprinkler button
Tab:Button({
    Title = "Delete Sprinkler",
    Icon = "trash-2",
    Callback = function()
        local selectedArray = getSelectedSprinklers()
        
        if #selectedArray == 0 then
            WindUI:Notify({
                Title = "No Selection",
                Content = "Please select sprinkler type(s) first",
                Duration = 4,
                Icon = "alert-triangle"
            })
            return
        end
        
        deleteSprinklers()
    end
})

Tab:Divider()

Tab:Section({
    Title = "--PET EXPLOIT--"
})

Tab:Paragraph({
    Title = "How to use:",
    Desc = "Refresh Pets > Choose Exclude Pets, ones has an X Marker in it > Auto Middle Pets",
    Icon = "info"
})

petDropdown = Tab:Dropdown({
    Title = "Select Pets to Include in Middle",
    Values = {"None"},
    Value = {},
    Multi = true,
    AllowNone = true,
    Callback = function(selectedValues)
        -- Safely get current data
        local success, error = pcall(function()
            if PetFunctions then
                includedPets = safeCall(PetFunctions.getIncludedPets, "getIncludedPets") or {}
                currentPetsList = safeCall(PetFunctions.getCurrentPetsList, "getCurrentPetsList") or {}
            end

            -- Clear existing included pets
            includedPets = {}

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
                        local petGroup = currentPetsList[petName]
                        if petGroup then
                            -- If it's a group of pets, include all pets in the group
                            if type(petGroup) == "table" and #petGroup > 0 then
                                for _, pet in pairs(petGroup) do
                                    if pet and pet.id then
                                        includedPets[pet.id] = true
                                        -- Also include in PetFunctions
                                        if PetFunctions and PetFunctions.includePet then
                                            safeCall(PetFunctions.includePet, "includePet", pet.id)
                                        end
                                    end
                                end
                            else
                                -- Single pet
                                includedPets[petGroup.id] = true
                                if PetFunctions and PetFunctions.includePet then
                                    safeCall(PetFunctions.includePet, "includePet", petGroup.id)
                                end
                            end
                        end
                    end
                end
            end

            -- Update PetFunctions
            if PetFunctions and PetFunctions.setIncludedPets then
                PetFunctions.setIncludedPets(includedPets)
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

-- Refresh pets only
Tab:Button({
    Title = "Refresh Pets",
    Icon = "refresh-cw",
    Callback = function()
        local newPets = refreshPets()

        -- Clear dropdown selection
        if petDropdown and petDropdown.ClearAll then
            pcall(function()
                petDropdown:ClearAll()
            end)
        end

        -- Clear included pets
        includedPets = {}
        if PetFunctions and PetFunctions.setIncludedPets then
            pcall(function()
                PetFunctions.setIncludedPets({})
            end)
        end

        WindUI:Notify({
            Title = "Pets Refreshed",
            Content = "Found " .. #newPets .. " pets. Please manually select pets to include in middle function.",
            Duration = 3,
            Icon = "check-circle"
        })
    end
})

-- Auto middle toggle
Tab:Toggle({
    Title = "Auto Middle Pets",
    Value = false,
    Icon = "zap",
    Callback = function(value)
        autoMiddleEnabled = value
        if PetFunctions and PetFunctions.setAutoMiddleEnabled then
            pcall(function()
                PetFunctions.setAutoMiddleEnabled(value)
            end)
        end
        if value then
            if PetFunctions and PetFunctions.setupZoneAbilityListener then
                safeCall(PetFunctions.setupZoneAbilityListener, "setupZoneAbilityListener")
            end
            if PetFunctions and PetFunctions.startInitialLoop then
                safeCall(PetFunctions.startInitialLoop, "startInitialLoop")
            end
        else
            if PetFunctions and PetFunctions.cleanup then
                safeCall(PetFunctions.cleanup, "cleanup")
            end
        end
    end
})
Tab:Divider()

Tab:Section({
    Title = "--AUTO SHOVEL--"
})

cropDropdown = Tab:Dropdown({
    Title = "Select Crops to Monitor",
    Values = safeCall(CoreFunctions.getCropTypes, "getCropTypes") or {"All Plants"},
    Value = {""},
    Multi = true,
    AllowNone = true,
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

Tab:Button({
    Title = "Refresh Crop List",
    Icon = "rotate-cw",
    Callback = function()
        local newCropTypes = safeCall(CoreFunctions.getCropTypes, "getCropTypes") or {"All Plants"}
        if cropDropdown and cropDropdown.Refresh then
            pcall(function()
                cropDropdown:Refresh(newCropTypes, true)
            end)
        end
        
        WindUI:Notify({
            Title = "List Refreshed",
            Content = string.format("Found %d crop types", #newCropTypes - 1),
            Duration = 2,
            Icon = "refresh-cw"
        })
    end
})

Tab:Input({
    Title = "Remove Fruits Below (kg)",
    Value = tostring(safeCall(CoreFunctions.getTargetFruitWeight, "getTargetFruitWeight") or 50),
    Placeholder = "Enter weight threshold",
    InputIcon = "weight",
    Callback = function(value)
        local weight = tonumber(value)
        if weight and weight > 0 then
            local success = safeCall(CoreFunctions.setTargetFruitWeight, "setTargetFruitWeight", weight)
            if success then
                WindUI:Notify({
                    Title = "Weight Updated",
                    Content = string.format("Target weight set to %.1fkg", weight),
                    Duration = 2,
                    Icon = "check"
                })
            end
        else
            WindUI:Notify({
                Title = "Invalid Weight",
                Content = "Please enter a valid number above 0",
                Duration = 3,
                Icon = "alert-triangle"
            })
        end
    end
})

Tab:Toggle({
    Title = "Enable Auto Shovel",
    Value = safeCall(CoreFunctions.getAutoShovelStatus, "getAutoShovelStatus") or false,
    Icon = "shovel",
    Callback = function(enabled)
        local success, message = safeCall(CoreFunctions.toggleAutoShovel, "toggleAutoShovel", enabled)
        if success and message then
            WindUI:Notify({
                Title = "Auto Shovel",
                Content = message,
                Duration = 2,
                Icon = enabled and "check-circle" or "x-circle"
            })
        end
    end
})

-- ===========================================
-- SHOP TAB (Updated for WindUI)
-- ===========================================
local ShopTab = Window:Tab({
    Title = "Shop",
    Icon = "shopping-cart",
    Desc = "Auto buy system for various shop items"
})

ShopTab:Paragraph({
    Title = "Auto Buy System",
    Desc = "Automatically purchase items even while AFK",
    Icon = "shopping-cart"
})

-- Zen Shop Section
ShopTab:Divider()

ShopTab:Section({
    Title = "--Zen--"
})

local zenItemOptions = {"None"}
if AutoBuy and AutoBuy.zenItems and type(AutoBuy.zenItems) == "table" then
    for _, item in pairs(AutoBuy.zenItems) do
        table.insert(zenItemOptions, item)
    end
end

ShopTab:Dropdown({
    Title = "Select Zen Items",
    Desc = "Choose zen items to auto buy",
    Values = zenItemOptions,
    Multi = true,
    AllowNone = true,
    Value = {},
    Callback = function(selectedValues)
        local success, error = pcall(function()
            if AutoBuy and AutoBuy.setSelectedZenItems and type(AutoBuy.setSelectedZenItems) == "function" then
                local count = AutoBuy.setSelectedZenItems(selectedValues)
                if count > 0 then
                    notify("Zen Items", "Selected " .. count .. " zen items for auto buy", 3)
                end
            end
        end)
        if not success then
            warn("Error setting zen items: " .. tostring(error))
        end
    end
})

ShopTab:Toggle({
    Title = "Auto Buy Zen Items",
    Desc = "Automatically purchase selected zen items",
    Icon = "zap",
    Value = false,
    Callback = function(Value)
        if AutoBuy and AutoBuy.buySelectedZenItems and type(AutoBuy.buySelectedZenItems) == "function" then
            AutoBuy.buySelectedZenItems(Value)
            if Value then
                notify("Auto Buy", "Zen auto buy enabled!", 3)
            end
        end
    end
})

-- Traveling Merchant Section
ShopTab:Divider()

ShopTab:Section({
    Title = "--Traveling Merchant--"
})

local merchantItemOptions = {"None"}
if AutoBuy and AutoBuy.merchantItems and type(AutoBuy.merchantItems) == "table" then
    for _, item in pairs(AutoBuy.merchantItems) do
        table.insert(merchantItemOptions, item)
    end
end

ShopTab:Dropdown({
    Title = "Select Merchant Items",
    Desc = "Choose merchant items to auto buy",
    Values = merchantItemOptions,
    Multi = true,
    AllowNone = true,
    Value = {},
    Callback = function(selectedValues)
        local success, error = pcall(function()
            if AutoBuy and AutoBuy.setSelectedMerchantItems and type(AutoBuy.setSelectedMerchantItems) == "function" then
                local count = AutoBuy.setSelectedMerchantItems(selectedValues)
                if count > 0 then
                    notify("Merchant Items", "Selected " .. count .. " merchant items for auto buy", 3)
                end
            end
        end)
        if not success then
            warn("Error setting merchant items: " .. tostring(error))
        end
    end
})

ShopTab:Toggle({
    Title = "Auto Buy Merchant Items",
    Desc = "Automatically purchase selected merchant items",
    Icon = "user",
    Value = false,
    Callback = function(Value)
        if AutoBuy and AutoBuy.buySelectedMerchantItems and type(AutoBuy.buySelectedMerchantItems) == "function" then
            AutoBuy.buySelectedMerchantItems(Value)
            if Value then
                notify("Auto Buy", "Merchant auto buy enabled!", 3)
            end
        end
    end
})

-- Pet Eggs Section
ShopTab:Divider()

ShopTab:Section({
    Title = "--Egg Shop--"
})

ShopTab:Dropdown({
    Title = "Select Eggs to Auto Buy",
    Desc = "Choose eggs to automatically purchase",
    Values = (AutoBuy and AutoBuy.eggOptions) or {"None"},
    Multi = true,
    AllowNone = true,
    Value = {},
    Callback = function(selectedValues)
        local success, error = pcall(function()
            if AutoBuy and AutoBuy.setSelectedEggs and type(AutoBuy.setSelectedEggs) == "function" then
                local count = AutoBuy.setSelectedEggs(selectedValues)
                if count > 0 then
                    notify("Eggs", "Selected " .. count .. " eggs for auto buy", 3)
                end
            end
        end)
        if not success then
            warn("Error setting eggs: " .. tostring(error))
        end
    end
})

ShopTab:Toggle({
    Title = "Auto Buy Eggs",
    Desc = "Automatically purchase selected eggs",
    Icon = "egg",
    Value = false,
    Callback = function(value)
        if AutoBuy and AutoBuy.toggleEgg and type(AutoBuy.toggleEgg) == "function" then
            AutoBuy.toggleEgg(value)
            if value then
                notify("Auto Buy", "Auto Buy Eggs enabled!", 2)
            end
        end
    end
})

-- Seeds Section
ShopTab:Divider()

ShopTab:Section({
    Title = "--Seed Shop--"
})

ShopTab:Dropdown({
    Title = "Select Seeds to Auto Buy",
    Desc = "Choose seeds to automatically purchase",
    Values = (AutoBuy and AutoBuy.seedOptions) or {"None"},
    Multi = true,
    AllowNone = true,
    Value = {},
    Callback = function(selectedValues)
        local success, error = pcall(function()
            if AutoBuy and AutoBuy.setSelectedSeeds and type(AutoBuy.setSelectedSeeds) == "function" then
                local count = AutoBuy.setSelectedSeeds(selectedValues)
                if count > 0 then
                    notify("Seeds", "Selected " .. count .. " seeds for auto buy", 3)
                end
            end
        end)
        if not success then
            warn("Error setting seeds: " .. tostring(error))
        end
    end
})

ShopTab:Toggle({
    Title = "Auto Buy Seeds",
    Desc = "Automatically purchase selected seeds",
    Icon = "sprout",
    Value = false,
    Callback = function(value)
        if AutoBuy and AutoBuy.toggleSeed and type(AutoBuy.toggleSeed) == "function" then
            AutoBuy.toggleSeed(value)
            if value then
                notify("Auto Buy", "Auto Buy Seeds enabled!", 2)
            end
        end
    end
})

-- Gear & Tools Section
ShopTab:Divider()

ShopTab:Section({
    Title = "--Gears Shop--"
})

ShopTab:Dropdown({
    Title = "Select Gear to Auto Buy",
    Desc = "Choose gear items to automatically purchase",
    Values = (AutoBuy and AutoBuy.gearOptions) or {"None"},
    Multi = true,
    AllowNone = true,
    Value = {},
    Callback = function(selectedValues)
        local success, error = pcall(function()
            if AutoBuy and AutoBuy.setSelectedGear and type(AutoBuy.setSelectedGear) == "function" then
                local count = AutoBuy.setSelectedGear(selectedValues)
                if count > 0 then
                    notify("Gear", "Selected " .. count .. " gear items for auto buy", 3)
                end
            end
        end)
        if not success then
            warn("Error setting gear: " .. tostring(error))
        end
    end
})

ShopTab:Toggle({
    Title = "Auto Buy Gear",
    Desc = "Automatically purchase selected gear",
    Icon = "wrench",
    Value = false,
    Callback = function(value)
        if AutoBuy and AutoBuy.toggleGear and type(AutoBuy.toggleGear) == "function" then
            AutoBuy.toggleGear(value)
            if value then
                notify("Auto Buy", "Auto Buy Gear enabled!", 2)
            end
        end
    end
})

-- Initialize AutoBuy module
if AutoBuy and AutoBuy.init and type(AutoBuy.init) == "function" then
    AutoBuy.init()
end
-- ===========================================
-- MISC TAB (Updated for WindUI)
-- ===========================================
local MiscTab = Window:Tab({
    Title = "Misc",
    Icon = "settings",
    Desc = "Performance optimization and miscellaneous features"
})

MiscTab:Divider()

MiscTab:Paragraph({
    Title = "Lag Reduction",
    Desc = "Remove lag-causing objects to improve game performance",
    Icon = "zap"
})

MiscTab:Button({
    Title = "Reduce Lag",
    Desc = "Remove all lag-causing objects from workspace",
    Icon = "trash-2",
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
            notify("Performance", "All lag objects have been removed", 3)
        else
            notify("Error", "Failed to reduce lag: " .. tostring(error), 5)
        end
    end
})

MiscTab:Button({
    Title = "Remove Farms",
    Desc = "Remove other players' farms (stay close to your farm)",
    Icon = "x-circle",
    Callback = function()
        removeFarms()
        notify("Farms", "Farm removal initiated", 2)
    end
})

-- ===========================================
-- SOCIAL TAB (Updated for WindUI)
-- ===========================================
local SocialTab = Window:Tab({
    Title = "Social",
    Icon = "users",
    Desc = "Social media links and community features"
})

SocialTab:Paragraph({
    Title = "TikTok",
    Desc = "@yurahaxyz | @yurahayz",
    Icon = "music",
    Color = "Blue"
})

SocialTab:Paragraph({
    Title = "YouTube",
    Desc = "YUraxYZ",
    Icon = "play",
    Color = "Red"
})

SocialTab:Divider()

SocialTab:Button({
    Title = "Join Discord Community",
    Desc = "Copy Discord invite link to clipboard",
    Icon = "copy",
    Callback = function()
        if setclipboard then
            setclipboard("https://discord.gg/gpR7YQjnFt")
            notify("Success", "Discord invite copied to clipboard!", 3)
        else
            notify("Error", "Clipboard access not available", 3)
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
notify("GAGSL Hub", "Wind UI version loaded successfully! +999 Pogi Points!", 4)
