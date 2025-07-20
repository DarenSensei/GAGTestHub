-- Main GAGSL Hub Script (FIXED & OPTIMIZED)
repeat task.wait() until game:IsLoaded()

-- Load external functions
local CoreFunctions = loadstring(game:HttpGet("https://raw.githubusercontent.com/DarenSensei/GAGTestHub/refs/heads/main/CoreFunctions.lua"))()
local PetFunctions = loadstring(game:HttpGet("https://raw.githubusercontent.com/DarenSensei/GrowAFilipino/refs/heads/main/PetMiddleFunctions.lua"))()
local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/YuraScripts/GrowAFilipinoy/refs/heads/main/TEST.lua"))()

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
    local screenGui = player:WaitForChild("PlayerGui"):WaitForChild("Orion")
    local mainFrame = screenGui:WaitForChild("Main")
    mainFrame.BackgroundTransparency = 1

    local tween = TweenService:Create(
        mainFrame,
        TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { BackgroundTransparency = 0.2 }
    )
    tween:Play()
end

task.delay(1.5, fadeInMainTab)

-- FIXED: Sprinkler helper functions using CoreFunctions
local function getSprinklerTypes()
    return CoreFunctions.getSprinklerTypes()
end

local function setSelectedSprinklers(selected)
    selectedSprinklers = selected
    CoreFunctions.setSelectedSprinklers(selected)
end

local function getSelectedSprinklers()
    return CoreFunctions.getSelectedSprinklers()
end

local function clearSelectedSprinklers()
    selectedSprinklers = {}
    CoreFunctions.clearSelectedSprinklers()
end

local function addSprinklerToSelection(sprinklerName)
    local success = CoreFunctions.addSprinklerToSelection(sprinklerName)
    if success then
        table.insert(selectedSprinklers, sprinklerName)
    end
    return success
end

local function getSelectedSprinklersCount()
    return CoreFunctions.getSelectedSprinklersCount()
end

local function getSelectedSprinklersString()
    return CoreFunctions.getSelectedSprinklersString()
end

-- Pet helper functions
local function refreshPets()
    return PetFunctions.refreshPets()
end

local function updatePetCount()
    PetFunctions.updatePetCount()
end

local function selectAllPets()
    PetFunctions.selectAllPets()
    allPetsSelected = true
end

local function createESPMarker(pet)
    PetFunctions.createESPMarker(pet)
end

local function removeESPMarker(petId)
    PetFunctions.removeESPMarker(petId)
end

local function autoEquipShovel()
    CoreFunctions.autoEquipShovel()
end

local function deleteSprinklers()
    CoreFunctions.deleteSprinklers(selectedSprinklers, OrionLib)
end

local function setupZoneAbilityListener()
    PetFunctions.setupZoneAbilityListener()
end

local function startInitialLoop()
    PetFunctions.startInitialLoop()
end

local function cleanup()
    PetFunctions.cleanup()
    CoreFunctions.cleanup()
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
    CoreFunctions.buyAllZenItems()
end

local function buyAllMerchantItems()
    CoreFunctions.buyAllMerchantItems()
end

local function removeFarms()
    CoreFunctions.removeFarms(OrionLib)
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
            game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, jobId, player)
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
        game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
    end
})

-- Server hop
ToolsTab:AddButton({
    Name = "Server Hop",
    Callback = function()
        local foundServer, playerCount = CoreFunctions.serverHop()
        if foundServer then
            OrionLib:MakeNotification({
                Name = "Server Found",
                Content = "Found server with " .. tostring(playerCount) .. " players.",
                Time = 3
            })
            task.wait(3)
            game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, foundServer, player)
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
PetFunctions.setPetCountLabel(petCountLabel)

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
        excludedPets = PetFunctions.getExcludedPets()
        currentPetsList = PetFunctions.getCurrentPetsList()
        
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
        
        PetFunctions.setExcludedPets(excludedPets)
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

PetFunctions.setPetDropdown(petDropdown)

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
        PetFunctions.setAutoMiddleEnabled(value)
        if value then
            setupZoneAbilityListener()
            startInitialLoop()
        else
            cleanup()
        end
    end
})

-- Auto Shovel Section - FIXED
Tab:AddParagraph("Auto Shovel Crops", "Automatically shovel crops based on weight threshold.")

-- Crop selection dropdown - FIXED to use CoreFunctions
local cropDropdown = Tab:AddDropdown({
    Name = "Select Crops to Shovel",
    Default = {},
    Options = (function()
        local options = {"None"}
        local cropTypes = CoreFunctions.getCropTypes()  -- Changed from Functions to CoreFunctions
        for _, cropType in ipairs(cropTypes) do
            table.insert(options, cropType)
        end
        return options
    end)(),
    Callback = function(selectedValues)
        CoreFunctions.clearSelectedCrops()  -- Changed from Functions to CoreFunctions
        if selectedValues and #selectedValues > 0 then
            local hasNone = false
            for _, value in pairs(selectedValues) do
                if value == "None" then
                    hasNone = true
                    break
                end
            end
            if not hasNone then
                for _, cropName in pairs(selectedValues) do
                    CoreFunctions.addCropToSelection(cropName)  -- Changed from Functions to CoreFunctions
                end
            end
        end
    end
})

-- Crop weight threshold input - FIXED
Tab:AddTextbox({
    Name = "Crop Weight Threshold (KG)",
    Default = "1",
    TextDisappear = false,
    Callback = function(value)
        CoreFunctions.setCropWeightThreshold(value)  -- Changed from Functions to CoreFunctions
    end
})

-- Refresh crop list button - FIXED
Tab:AddButton({
    Name = "Refresh Crop List",
    Callback = function()
        local options = CoreFunctions.refreshCropList()  -- Changed from Functions to CoreFunctions
        cropDropdown:Refresh(options, true)
    end
})

-- Auto shovel crops toggle - FIXED
Tab:AddToggle({
    Name = "Auto Shovel Crops",
    Default = false,
    Callback = function(value)
        CoreFunctions.toggleAutoShovelCrops(value, OrionLib)  -- Changed from Functions to CoreFunctions
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
        CoreFunctions.toggleAutoBuyZen(Value)
        
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
        CoreFunctions.toggleAutoBuyMerchant(Value)
        
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
        repeat
            local lag = game.Workspace:findFirstChild("Lag", true)
            if (lag ~= nil) then
                lag:remove()
            end
            wait()
        until (game.Workspace:findFirstChild("Lag", true) == nil)
        
        OrionLib:MakeNotification({
            Name = "Lag Reduced",
            Content = "All lag objects have been removed.",
            Time = 3
        })
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
        setclipboard("https://discord.gg/gpR7YQjnFt")
        OrionLib:MakeNotification({
            Name = "Copied!",
            Content = "Discord invite copied to clipboard.",
            Time = 3
        })
    end
})

-- Cleanup on exit
Players.PlayerRemoving:Connect(function(player)
    if player == Players.LocalPlayer then
        cleanup()
    end
end)

-- Final notification
OrionLib:MakeNotification({
    Name = "GAGSL Hub Loaded",
    Content = "GAGSL Hub loaded with +999 Pogi Points!",
    Time = 4
})
