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
local AutoBuy = safeLoad("https://raw.githubusercontent.com/DarenSensei/GrowAFilipino/refs/heads/main/AutoBuy.lua", "AutoBuy")
local PetFunctions = safeLoad("https://raw.githubusercontent.com/DarenSensei/GrowAFilipino/refs/heads/main/PetMiddleFunctions.lua", "PetFunctions")
local LocalPlayer = safeLoad("https://raw.githubusercontent.com/DarenSensei/GrowAFilipino/refs/heads/main/LocalPlayer.lua", "LocalPlayer")
local Vuln = safeLoad("https://raw.githubusercontent.com/DarenSensei/GAGTestHub/refs/heads/main/Vuln.lua", "Vuln")
local esp = safeLoad("https://raw.githubusercontent.com/DarenSensei/GrowAFilipino/refs/heads/main/esp.lua", "esp")
local SettingsManager = safeLoad("https://raw.githubusercontent.com/DarenSensei/GrowAFilipino/refs/heads/main/SettingsManager.lua", "SettingsManager")
if not CoreFunctions then
    error("Failed to load CoreFunctions - script cannot continue")
end

local settings
local Settings = SettingsManager.create({
    fileName = "GenzuraHub_Settings.json",
    envKey = "GenzuraHubSettings",
    autoSaveInterval = 30,
    debug = false, -- Silent operation
    defaultSettings = {
        toggles = {
            autoMiddleEnabled = false,
            autoShovelEnabled = false,
            noClip = false,
            infiniteJump = false,
            blackScreenOverlay = false,
            fruitESP = false,
            selectAllSprinklers = false,
            teleportEnabled = true,
            buySelectedZenItems = false,
            buySelectedMerchantItems = false,
            toggleEgg = false,
            toggleSeed = false,
            toggleGear = false,
            autoCraftEnabled = false
        },
        dropdowns = {
            selectedPets = {},
            selectedSprinklers = {},
            selectedCrops = {},
            selectedZenItems = {},
            selectedMerchantItems = {},
            selectedEggs = {},
            selectedSeeds = {},
            selectedGear = {},
            selectedCraftItems = {}
        },
        inputs = {
            weightThreshold = 50,
            jobId = "",
            targetFruitWeight = 50
        },
        other = {
            windowPosition = {X = 0, Y = 0},
            lastPlayTime = 0,
            totalPlayTime = 0
        }
    }
})


-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local StarterGui = game:GetService("StarterGui")
local playerGui = player:WaitForChild("PlayerGui")
local userInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PetMutationMachineService_RE = ReplicatedStorage.GameEvents.PetMutationMachineService_RE

-- Variables initialization
local selectedPets = {}
local includedPets = {}
local allPetsSelected = false
local autoMiddleEnabled = false
local currentPetsList = {}
local petDropdown = nil
local cropDropdown = nil
local blackScreenGui = nil

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
    Title = "Genzura Hub",
    Author = "[☘️] Made by Yura",
    SubTitle = "Grow A Garden",
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

local function notify(title, content, duration)
    WindUI:Notify({
        Title = title,
        Content = content,
        Duration = duration or 3
    })
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
    Title = "📜Changelogs : (v.1.2.5)",
    Desc = "Added : Added Vuln, ESP (Crops KG)",
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
        game:GetService("TeleportService"):Teleport(game.PlaceId, game:GetService("Players").LocalPlayer)
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

MainTab:Section({
    Title = "---- Local Player ----"
})

MainTab:Toggle({
    Title = "No-Clip",
    Value = Settings:loadToggle("noClip"), -- Load saved state
    Callback = function(Value)
        Settings:saveToggle("noClip", Value) -- Save new state
        if LocalPlayer and LocalPlayer.setNoClip then
            LocalPlayer.setNoClip(Value)
        end
    end
})

MainTab:Toggle({
    Title = "Infinite Jump",
    Value = Settings:loadToggle("infiniteJump"), -- Load saved state
    Callback = function(Value)
        Settings:saveToggle("infiniteJump", Value) -- Save new state
        
        if Value then
            local connection
            connection = userInputService.JumpRequest:Connect(function()
                if player.Character then
                    local humanoid = player.Character:FindFirstChildOfClass('Humanoid')
                    if humanoid then
                        humanoid:ChangeState("Jumping")
                    end
                end
            end)
            getgenv().infiniteJumpConnection = connection
        else
            if getgenv().infiniteJumpConnection then
                getgenv().infiniteJumpConnection:Disconnect()
                getgenv().infiniteJumpConnection = nil
            end
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

local sprinklerDropdown = Tab:Dropdown({
    Title = "Select Sprinkler to Delete",
    Values = (function()
        local options = {"None"}
        if CoreFunctions and CoreFunctions.getSprinklerTypes then
            for _, sprinklerType in ipairs(CoreFunctions.getSprinklerTypes()) do
                table.insert(options, sprinklerType)
            end
        end
        return options
    end)(),
    Value = Settings:loadDropdown("selectedSprinklers"), -- Load saved selection
    Multi = true,
    AllowNone = true,
    Callback = function(selectedValues)
        Settings:saveDropdown("selectedSprinklers", selectedValues) -- Save selection
        
        -- Your existing sprinkler logic here...
        if CoreFunctions then
            safeCall(CoreFunctions.clearSelectedSprinklers, "clearSelectedSprinklers")
            
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
                        safeCall(CoreFunctions.addSprinklerToSelection, "addSprinklerToSelection", sprinklerName)
                    end
                    
                    notify("Selection Updated", string.format("Selected %d sprinklers", #selectedValues), 3)
                end
            end
        end
    end
})

-- Select all sprinklers toggle with settings
Tab:Toggle({
    Title = "Select All Sprinkler",
    Value = Settings:loadToggle("selectAllSprinklers"), -- Load saved state
    Callback = function(Value)
        Settings:saveToggle("selectAllSprinklers", Value) -- Save new state
        
        if Value and CoreFunctions then
            local allSprinklers = safeCall(CoreFunctions.getSprinklerTypes, "getSprinklerTypes") or {}
            Settings:saveDropdown("selectedSprinklers", allSprinklers)
            notify("All Selected", string.format("Selected all %d sprinkler types", #allSprinklers), 3)
        else
            Settings:saveDropdown("selectedSprinklers", {})
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
    Title = "Pet Exploit:",
    Desc = "Choose your pet to Stay Middle",
    Icon = "info"
})

petDropdown = Tab:Dropdown({
    Title = "Select Pets to Include in Middle",
    Values = {"None"},
    Value = {"None"},
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

ShopTab:Dropdown({
    Title = "Select Zen Items",
    Values = (AutoBuy and AutoBuy.zenItems) and (function()
        local options = {"None"}
        for _, item in pairs(AutoBuy.zenItems) do
            table.insert(options, item)
        end
        return options
    end)() or {"None"},
    Multi = true,
    AllowNone = true,
    Value = Settings:loadDropdown("selectedZenItems"), -- Load saved selection
    Callback = function(selectedValues)
        Settings:saveDropdown("selectedZenItems", selectedValues) -- Save selection
        
        if AutoBuy and AutoBuy.setSelectedZenItems then
            pcall(function()
                AutoBuy.setSelectedZenItems(selectedValues)
            end)
        end
    end
})

ShopTab:Toggle({
    Title = "Auto Buy Zen Items",
    Value = Settings:loadToggle("buySelectedZenItems"), -- Load saved state
    Icon = "zap",
    Callback = function(Value)
        Settings:saveToggle("buySelectedZenItems", Value) -- Save state
        
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
    Value = Settings:loadDropdown("selectedMerchantItems"),
    Callback = function(selectedValues)
        Settings:saveDropdown("selectedMerchantItems", selectedValues) -- Save selection
        
        local success, error = pcall(function()
            if AutoBuy and AutoBuy.setSelectedMerchantItems and type(AutoBuy.setSelectedMerchantItems) == "function" then
                local count = AutoBuy.setSelectedMerchantItems(selectedValues)
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
    Value = Settings:loadToggle("buySelectedMerchantItems"), -- Load saved state
    Callback = function(Value)
        Settings:saveToggle("buySelectedMerchantItems", Value) -- Save state
    
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
    Value = Settings:loadDropdown("selectedEggs"),
    Callback = function(selectedValues)
        Settings:saveDropdown("selectedEggs", selectedValues)
        local success, error = pcall(function()
            if AutoBuy and AutoBuy.setSelectedEggs and type(AutoBuy.setSelectedEggs) == "function" then
                local count = AutoBuy.setSelectedEggs(selectedValues)
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
    Value = Settings:loadToggle("toggleEgg"), -- Load saved state
    Callback = function(Value)
        Settings:saveToggle("toggleEgg", Value) -- Save state
        
        if AutoBuy and AutoBuy.toggleEgg and type(AutoBuy.toggleEgg) == "function" then
            AutoBuy.toggleEgg(Value)
            if Value then
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
    Value = Settings:loadDropdown("selectedSeeds"),
    Callback = function(selectedValues)
        Settings:saveDropdown("selectedSeeds", selectedValues)
        local success, error = pcall(function()
            if AutoBuy and AutoBuy.setSelectedSeeds and type(AutoBuy.setSelectedSeeds) == "function" then
                local count = AutoBuy.setSelectedSeeds(selectedValues)
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
    Value = Settings:loadToggle("toggleSeed"), -- Load saved state
    Callback = function(Value)
        Settings:saveToggle("toggleSeed", Value) -- Save state
        
        if AutoBuy and AutoBuy.toggleSeed and type(AutoBuy.toggleSeed) == "function" then
            AutoBuy.toggleSeed(Value)
            if Value then
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
    Value = Settings:loadDropdown("selectedGear"),
    Callback = function(selectedValues)
        Settings:saveDropdown("selectedGear", selectedValues)
        local success, error = pcall(function()
            if AutoBuy and AutoBuy.setSelectedGear and type(AutoBuy.setSelectedGear) == "function" then
                local count = AutoBuy.setSelectedGear(selectedValues)
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
    Value = Settings:loadToggle("toggleGear"), -- Load saved state
    Callback = function(Value)
        Settings:saveToggle("toggleGear", Value) -- Save state
        
        if AutoBuy and AutoBuy.toggleGear and type(AutoBuy.toggleGear) == "function" then
            AutoBuy.toggleGear(Value)
            if Value then
                notify("Auto Buy", "Auto Buy Gear enabled!", 2)
            end
        end
    end
})

-- Initialize AutoBuy module
if AutoBuy and AutoBuy.init and type(AutoBuy.init) == "function" then
    AutoBuy.init()
end

-- =========================
-- Vuln Tab
-- =========================

local VulnTab = Window:Tab({
    Title = "Vuln",
    Icon = "syringe",
    Desc = "Vulnerable Data to Exploit"
})

VulnTab:Paragraph({
    Title = "Vuln",
    Desc = "Exploit of the week",
    Icon = "zap"
})

-- Dropdown for selecting craft items
local selectedCraftItems = {}
local autoCraftEnabled = false
local teleportEnabled = true
local autoCraftConnection = nil

-- Function to process selected values (extracted to avoid duplication)
local function processSelectedValues(selectedValues)
    -- Clear existing selected items
    selectedCraftItems = {}
    
    if selectedValues and #selectedValues > 0 then
        local hasNone = false
        for _, value in pairs(selectedValues) do
            if value == "None" then
                hasNone = true
                break
            end
        end
        
        if not hasNone then
            for _, itemName in pairs(selectedValues) do
                selectedCraftItems[itemName] = true
            end
        end
    end
    
    -- Update Vuln functions if available
    if Vuln and Vuln.setSelectedCraftItems then
        pcall(function()
            Vuln.setSelectedCraftItems(selectedCraftItems)
        end)
    end
    
    -- If auto craft is currently enabled and no items are selected, stop it
    if autoCraftEnabled and (not selectedCraftItems or next(selectedCraftItems) == nil) then
        autoCraftEnabled = false
        Settings:saveToggle("autoCraftEnabled", false)
        
        WindUI:Notify({
            Title = "Auto Craft Stopped",
            Content = "Auto craft disabled due to no selected items.",
            Duration = 3,
            Icon = "alert-triangle"
        })
    end
end

-- Load saved values first and initialize
local savedValues = Settings:loadDropdown("selectedCraftItems", {})
local savedTeleportEnabled = Settings:loadToggle("teleportEnabled", true)
local savedAutoCraftEnabled = Settings:loadToggle("autoCraftEnabled", false)

-- Initialize teleport setting
teleportEnabled = savedTeleportEnabled
if Vuln and Vuln.setTeleportEnabled then
    pcall(function()
        Vuln.setTeleportEnabled(teleportEnabled)
    end)
end

-- Process the loaded dropdown values immediately to populate selectedCraftItems
if savedValues and #savedValues > 0 then
    local success, error = pcall(function()
        processSelectedValues(savedValues)
    end)
    
    if not success then
        print("Error processing loaded craft items:", error)
    end
end

-- Initialize auto craft state
autoCraftEnabled = savedAutoCraftEnabled

-- Dropdown for selecting craft items
VulnTab:Dropdown({
    Title = "Select Items to Craft",
    Values = {"Dino Egg", "Ancient Seed Pack", "Primal Egg"},
    Value = savedValues, -- Use the loaded values
    Multi = true,
    AllowNone = true,
    Callback = function(selectedValues)
        Settings:saveDropdown("selectedCraftItems", selectedValues) -- Save selection
        
        local success, error = pcall(function()
            processSelectedValues(selectedValues)
        end)
        
        if not success then
            print("Error in craft dropdown callback:", error)
        end
    end
})

-- Toggle for auto rejoin (only sets the preference, doesn't start rejoin)
VulnTab:Toggle({
    Title = "Auto Rejoin",
    Value = teleportEnabled, -- Use the loaded state
    Icon = "refresh-ccw",
    Callback = function(value)
        teleportEnabled = value
        Settings:saveToggle("teleportEnabled", value) -- Save new state
        
        -- Update Vuln module
        if Vuln and Vuln.setTeleportEnabled then
            pcall(function()
                Vuln.setTeleportEnabled(value)
            end)
        end
        
        WindUI:Notify({
            Title = "Auto Rejoin " .. (value and "Enabled" or "Disabled"),
            Content = value and "Will rejoin after crafting when Auto Craft is enabled" or "Auto rejoin disabled",
            Duration = 2,
            Icon = value and "check-circle" or "x-circle"
        })
    end
})

-- Toggle for Auto Craft
VulnTab:Toggle({
    Title = "Auto Craft",
    Value = autoCraftEnabled, -- Use the loaded state
    Icon = "play",
    Callback = function(Value)
        local success, error = pcall(function()
            if Value then
                -- Starting Auto Craft
                if not selectedCraftItems or next(selectedCraftItems) == nil then
                    WindUI:Notify({
                        Title = "No Items Selected",
                        Content = "Please select items to craft from the dropdown above.",
                        Duration = 3,
                        Icon = "alert-triangle"
                    })
                    -- Reset the toggle state since we can't start
                    autoCraftEnabled = false
                    Settings:saveToggle("autoCraftEnabled", false)
                    return
                end
                
                autoCraftEnabled = true
                Settings:saveToggle("autoCraftEnabled", true) -- Save new state
                
                -- Start crafting process with current rejoin setting
                if Vuln and Vuln.startAutoCraft then
                    Vuln.startAutoCraft(selectedCraftItems, teleportEnabled)
                else
                    -- Fallback to local crafting functions if available
                    if startLocalAutoCraft then
                        startLocalAutoCraft(teleportEnabled)
                    end
                end
                
                local rejoinStatus = teleportEnabled and " (Auto Rejoin: ON)" or " (Auto Rejoin: OFF)"
                WindUI:Notify({
                    Title = "Auto Craft Started",
                    Content = "Crafting selected items..." .. rejoinStatus,
                    Duration = 3,
                    Icon = "check-circle"
                })
                
            else
                -- Stopping Auto Craft
                autoCraftEnabled = false
                Settings:saveToggle("autoCraftEnabled", false) -- Save new state
                
                if Vuln and Vuln.stopAutoCraft then
                    Vuln.stopAutoCraft()
                end
                
                -- Disconnect any connections if they exist
                if autoCraftConnection then
                    autoCraftConnection:Disconnect()
                    autoCraftConnection = nil
                end
                
                WindUI:Notify({
                    Title = "Auto Craft Stopped",
                    Content = "Auto crafting has been disabled.",
                    Duration = 2,
                    Icon = "stop-circle"
                })
            end
        end)
        
        if not success then
            -- On error, ensure the state is consistent
            autoCraftEnabled = false
            Settings:saveToggle("autoCraftEnabled", false)
            WindUI:Notify({
                Title = "Error",
                Content = "Failed to toggle auto craft: " .. tostring(error),
                Duration = 5,
                Icon = "x-circle"
            })
        end
    end
})

VulnTab:Divider()

VulnTab:Section({
    Title = "--Pet Mutation--"
})

VulnTab:Paragraph({
    Title = "Pet Mutation",
    Desc = "Start Machine's Timer so the next time you put a pet, it will finish instantly (use the button for putting a pet)",
    Icon = "zap"
})

VulnTab:Button({
    Title = "Start Machine",
    Icon = "play",
    Callback = function()
        if PetMutationMachineService_RE then
            PetMutationMachineService_RE:FireServer("StartMachine")
            
            WindUI:Notify({
                Title = "Success",
                Content = "Machine Started!",
                Duration = 2,
                Icon = "check-circle"
            })
        end
    end
})

VulnTab:Button({
    Title = "Submit Held Pet",
    Icon = "send",
    Callback = function()
        if PetMutationMachineService_RE then
            PetMutationMachineService_RE:FireServer("SubmitHeldPet")
            
            WindUI:Notify({
                Title = "Success",
                Content = "Pet Submitted!",
                Duration = 2,
                Icon = "check-circle"
            })
        end
    end
})

VulnTab:Divider()

VulnTab:Section({
        Title = "-- Zen Auto --"
    })

VulnTab:Button({
    Title = "Zen Aura Submit",
    Desc = "Submit all plants for Zen Aura",
    Icon = "leaf",
    Callback = function()
        game:GetService("ReplicatedStorage").GameEvents.ZenAuraRemoteEvent:FireServer("SubmitAllPlants")
    end
})

VulnTab:Button({
    Title = "Zen Quest Submit", 
    Desc = "Submit all plants for Zen Quest",
    Icon = "target",
    Callback = function()
        game:GetService("ReplicatedStorage").GameEvents.ZenQuestRemoteEvent:FireServer("SubmitAllPlants")
    end
})

-- ===========================================
-- MISC TAB (Updated for WindUI)
-- ===========================================
local MiscTab = Window:Tab({
    Title = "Misc",
    Icon = "settings",
    Desc = "Performance optimization and miscellaneous features"
})

MiscTab:Section({ Title = "-- Config --" })

MiscTab:Divider()

MiscTab:Button({
    Title = "Save Config",
    Desc = "Manually save all current settings",
    Icon = "save",
    Callback = function()
        if Settings:save() then
            notify("Settings Saved", "All settings saved successfully!", 3)
        else
            notify("Save Failed", "Could not save settings to file", 3)
        end
    end
})

MiscTab:Button({
    Title = "Export Config",
    Desc = "Copy settings as JSON to clipboard",
    Icon = "copy",
    Callback = function()
        if setclipboard then
            local exportData = Settings:export()
            setclipboard(exportData)
            notify("Config Exported", "Config copied to clipboard!", 3)
        else
            notify("Export Failed", "Clipboard not available", 3)
        end
    end
})

MiscTab:Input({
    Title = "Import Config",
    Desc = "Paste JSON settings data to import",
    Placeholder = "Paste settings JSON here...",
    Callback = function(jsonData)
        if jsonData and jsonData ~= "" then
            if Settings:import(jsonData) then
                notify("Config Imported", "Config imported successfully! Please reload script.", 5)
            else
                notify("Import Failed", "Invalid settings data", 3)
            end
        end
    end
})

MiscTab:Button({
    Title = "Reset Functions",
    Desc = "Reset all Functions to default values",
    Icon = "refresh-cw",
    Callback = function()
        Settings:reset()
        notify("Functions Reset", "All Functions reset to defaults. Please reload script.", 5)
    end
})

MiscTab:Section({
    Title = "--Performance--"
})

MiscTab:Divider()

MiscTab:Paragraph({
    Title = "Lag Reduction",
    Desc = "Remove lag-causing objects to improve game performance",
    Icon = "zap"
})

MiscTab:Button({
    Title = "Reduce Textures",
    Desc = "Remove all textures to reduce fps drop",
    Icon = "trash-2",
    Callback = function()
        local ToDisable = {
            Textures = true,
            VisualEffects = true,
            Parts = true,
            Particles = true,
            Sky = true
        }
        local ToEnable = {
            FullBright = false
        }
        local Stuff = {}
        for _, v in next, game:GetDescendants() do
            if ToDisable.Parts then
                if v:IsA("Part") or v:IsA("Union") or v:IsA("BasePart") then
                    v.Material = Enum.Material.SmoothPlastic
                    table.insert(Stuff, 1, v)
                end
            end
            
            if ToDisable.Particles then
                if v:IsA("ParticleEmitter") or v:IsA("Smoke") or v:IsA("Explosion") or v:IsA("Sparkles") or v:IsA("Fire") then
                    v.Enabled = false
                    table.insert(Stuff, 1, v)
                end
            end
            
            if ToDisable.VisualEffects then
                if v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("DepthOfFieldEffect") or v:IsA("SunRaysEffect") then
                    v.Enabled = false
                    table.insert(Stuff, 1, v)
                end
            end
            
            if ToDisable.Textures then
                if v:IsA("Decal") or v:IsA("Texture") then
                    v.Texture = ""
                    table.insert(Stuff, 1, v)
                end
            end
            
            if ToDisable.Sky then
                if v:IsA("Sky") then
                    v.Parent = nil
                    table.insert(Stuff, 1, v)
                end
            end
        end
        game:GetService("TestService"):Message("Effects Disabler Script : Successfully disabled "..#Stuff.." assets / effects. Settings :")
        for i, v in next, ToDisable do
            print(tostring(i)..": "..tostring(v))
        end
        if ToEnable.FullBright then
            local Lighting = game:GetService("Lighting")
            
            Lighting.FogColor = Color3.fromRGB(255, 255, 255)
            Lighting.FogEnd = math.huge
            Lighting.FogStart = math.huge
            Lighting.Ambient = Color3.fromRGB(255, 255, 255)
            Lighting.Brightness = 5
            Lighting.ColorShift_Bottom = Color3.fromRGB(255, 255, 255)
            Lighting.ColorShift_Top = Color3.fromRGB(255, 255, 255)
            Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
            Lighting.Outlines = true
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

MiscTab:Toggle({
    Title = "Black Screen Overlay",
    Value = false,
    Icon = "monitor",
    Callback = function(value)
        if value then
            -- TOGGLE ON: Create and show black screen
            pcall(function()
                -- Clean up any existing black screen first
                if blackScreenGui then
                    blackScreenGui:Destroy()
                    blackScreenGui = nil
                end
                
                -- Hide specific Core GUI elements (including backpack)
                StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
                StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
                StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
                StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, false)
                
                -- Create ScreenGui
                blackScreenGui = Instance.new("ScreenGui")
                blackScreenGui.Name = "BlackScreenGui"
                blackScreenGui.ResetOnSpawn = false
                blackScreenGui.IgnoreGuiInset = true
                blackScreenGui.DisplayOrder = 999999 -- Ensure it's on top
                blackScreenGui.Parent = playerGui
                
                -- Black Frame (covers everything)
                local blackFrame = Instance.new("Frame")
                blackFrame.Name = "BlackBackground"
                blackFrame.Size = UDim2.new(1, 0, 1, 0)
                blackFrame.Position = UDim2.new(0, 0, 0, 0)
                blackFrame.BackgroundColor3 = Color3.new(0, 0, 0)
                blackFrame.BackgroundTransparency = 1 -- Start transparent for fade
                blackFrame.BorderSizePixel = 0
                blackFrame.ZIndex = 1
                blackFrame.Parent = blackScreenGui
                
                -- Logo Image (keeping the logo as requested)
                local logoImage = Instance.new("ImageLabel")
                logoImage.Name = "Logo"
                logoImage.Size = UDim2.new(0, 200, 0, 200)
                logoImage.Position = UDim2.new(0.5, -100, 0.5, -100)
                logoImage.BackgroundTransparency = 1
                logoImage.ImageTransparency = 1 -- Start transparent for fade
                logoImage.Image = "rbxassetid://124132063885927"
                logoImage.ScaleType = Enum.ScaleType.Fit
                logoImage.ZIndex = 2
                logoImage.Parent = blackFrame
                
                -- Add fade in effect
                local fadeIn = TweenService:Create(
                    blackFrame, 
                    TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    {BackgroundTransparency = 0}
                )
                
                local logoFadeIn = TweenService:Create(
                    logoImage,
                    TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    {ImageTransparency = 0.6}
                )
                
                fadeIn:Play()
                logoFadeIn:Play()
                
                print("Black screen overlay enabled - Image and backpack hidden")
            end)
        else
            -- TOGGLE OFF: Hide black screen and restore all core GUI
            pcall(function()
                -- Hide the black screen GUI
                if blackScreenGui and blackScreenGui.Parent then
                    blackScreenGui:Destroy()
                    blackScreenGui = nil
                end
                
                -- Restore only specific core GUI (NOT backpack)
                StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
                StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
                StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, true)
                -- Backpack stays hidden as requested
                
                print("Black screen overlay disabled - Backpack remains hidden")
            end)
        end
    end
})

MiscTab:Section({
    Title = "--ESP--"
})


MiscTab:Divider()

MiscTab:Dropdown({
    Title = "Select Crops to Monitor",
    Values = safeCall(esp.getCropTypes, "getCropTypes") or {"All Plants"},
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
        
        safeCall(esp.setSelectedCrops, "setSelectedCrops", selectedCrops)
    end
})


MiscTab:Toggle({
    Title = "Fruit ESP",
    Value = false,
    Callback = function(Value)
        esp.toggle(Value)
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
    Desc = "@atutubieee",
    Icon = "music",
    Color = "Blue"
})

SocialTab:Paragraph({
    Title = "YouTube",
    Desc = "@YuraScripts",
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
game:GetService("LogService"):ClearOutput()
notify("Genzura Hub", "Genzura Hub loaded successfully! +999 Pogi Points! for you!", 4)
