-- Main GAGSL Hub Script (FIXED & OPTIMIZED)
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
local PetFunctions = safeLoad("https://raw.githubusercontent.com/DarenSensei/GrowAFilipino/refs/heads/main/PetMiddleFunctions.lua", "PetFunctions")
local OrionLib = safeLoad("https://raw.githubusercontent.com/YuraScripts/GrowAFilipinoy/refs/heads/main/TEST.lua", "OrionLib")

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
local petCountLabel = nil
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
    Name = "GAGSL Hub (v1.2)",
    HidePremium = false,
    IntroText = "Grow A Garden Script Loader",
    SaveConfig = false
})

-- Fade in animation
local function fadeInMainTab()
    local success, error = pcall(function()
        local screenGui = player:WaitForChild("PlayerGui"):WaitForChild("Orion")
        local mainFrame = screenGui:WaitForChild("Main")
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

-- Pet helper functions
local function refreshPets()
    return safeCall(PetFunctions.refreshPets, "refreshPets") or {}
end

local function updatePetCount()
    safeCall(PetFunctions.updatePetCount, "updatePetCount")
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

-- Sprinkler Section
Tab:AddParagraph("Shovel Sprinkler", "Inf. Sprinkler Glitch")

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
            OrionLib:MakeNotification({
                Name = "Selection Cleared",
                Content = "All selections cleared",
                Time = 2
            })
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

-- Pet Section
Tab:AddParagraph("Pet Exploit", "Auto Middle Pets, Select Pet to Exclude.")

petCountLabel = Tab:AddLabel("Pets Found: 0 | Selected: 0 | Excluded: 0")
if PetFunctions and PetFunctions.setPetCountLabel then
    PetFunctions.setPetCountLabel(petCountLabel)
end

updatePetCount()
task.spawn(function()
    while true do
        updatePetCount()
        task.wait(1)
    end
end)

-- Pet exclusion dropdown
petDropdown = Tab:AddDropdown({
    Name = "Select Pets to Exclude",
    Default = {},
    Options = {"None"},
    Callback = function(selectedValues)
        if PetFunctions then
            excludedPets = safeCall(PetFunctions.getExcludedPets, "getExcludedPets") or {}
            currentPetsList = safeCall(PetFunctions.getCurrentPetsList, "getCurrentPetsList") or {}
        end
        
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
        
        if PetFunctions and PetFunctions.setExcludedPets then
            PetFunctions.setExcludedPets(excludedPets)
        end
        updatePetCount()
        
        local excludedCount = 0
        for _ in pairs(excludedPets) do
            excludedCount = excludedCount + 1
        end
        
        if excludedCount > 0 then
            OrionLib:MakeNotification({
                Name = "Pets Excluded",
                Content = "Excluded " .. excludedCount .. " pets from auto middle.",
                Time = 2
            })
        end
    end
})

if PetFunctions and PetFunctions.setPetDropdown then
    PetFunctions.setPetDropdown(petDropdown)
end

-- Refresh and select all pets
Tab:AddButton({
    Name = "Refresh & Auto Select All Pets",
    Callback = function()
        local newPets = refreshPets()
        selectAllPets()
        updatePetCount()
        
        if petDropdown then
            petDropdown:ClearAll()
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
            PetFunctions.setAutoMiddleEnabled(value)
        end
        if value then
            setupZoneAbilityListener()
            startInitialLoop()
        else
            cleanup()
        end
    end
})

-- Auto Shovel Section - Create the tab first
local AutoShovelTab = Window:MakeTab({
    Name = "Auto Shovel",
    Icon = "rbxassetid://6031280882",
    PremiumOnly = false
})

AutoShovelTab:AddParagraph("Auto Shovel Crops", "Automatically shovel crops based on weight threshold.")

AutoShovelTab:AddSection({Name = "Crop Selection"})

cropDropdown = AutoShovelTab:AddDropdown({
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

AutoShovelTab:AddButton({
    Name = "Refresh Crop List",
    Callback = function()
        local newCropTypes = safeCall(CoreFunctions.getCropTypes, "getCropTypes") or {"All Plants"}
        if cropDropdown and cropDropdown.Refresh then
            cropDropdown:Refresh(newCropTypes, true)
        end
        
        OrionLib:MakeNotification({
            Name = "List Refreshed",
            Content = string.format("Found %d crop types", #newCropTypes - 1),
            Time = 2
        })
    end
})

-- Weight Settings Section
AutoShovelTab:AddSection({Name = "Weight Settings"})

AutoShovelTab:AddTextbox({
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

-- Auto Shovel Control Section
AutoShovelTab:AddSection({Name = "Auto Shovel Control"})

AutoShovelTab:AddToggle({
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
    Icon = "rbxassetid://4835310745",
    PremiumOnly = false
})

-- Auto buy zen
ShopTab:AddToggle({
    Name = "Auto Buy Zen",
    Default = false,
    Callback = function(Value)
        safeCall(CoreFunctions.toggleAutoBuyZen, "toggleAutoBuyZen", Value)
        
        if Value then
            OrionLib:MakeNotification({
                Name = "Auto Buy Zen",
                Content = "Auto Buy Zen enabled!",
                Time = 2
            })
        end
    end    
})

-- Auto buy merchant
ShopTab:AddToggle({
    Name = "Auto Buy Traveling Merchants",
    Default = false,
    Callback = function(Value)
        safeCall(CoreFunctions.toggleAutoBuyMerchant, "toggleAutoBuyMerchant", Value)
        
        if Value then
            OrionLib:MakeNotification({
                Name = "Auto Buy Traveling Merchant",
                Content = "Auto Buy Traveling Merchant enabled!",
                Time = 2
            })
        end
    end    
})

ShopTab:AddParagraph("AUTO BUY GEARS", "COMING SOON...")
ShopTab:AddParagraph("AUTO BUY SEEDS", "COMING SOON...")

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
    Name = "Yura Community Discord",
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
