-- Main GAGSL Hub Script (CONNECTED & FIXED)
repeat task.wait() until game:IsLoaded()

local CoreFunctions = loadstring(game:HttpGet("https://raw.githubusercontent.com/DarenSensei/GAGTestHub/refs/heads/main/CoreFunctions.lua"))()

local PetFunctions = loadstring(game:HttpGet("https://raw.githubusercontent.com/DarenSensei/GrowAFilipino/refs/heads/main/PetMiddleFunctions.lua"))()

local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/YuraScripts/GrowAFilipinoy/refs/heads/main/TEST.lua"))()

-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

-- Pet Control Variables (Initialize from PetFunctions)
local selectedPets = {}
local excludedPets = {}
local excludedPetESPs = {}
local allPetsSelected = false
local autoMiddleEnabled = false
local currentPetsList = {}
local petCountLabel = nil
local petDropdown = nil
local sprinklerTypes = {"Basic Sprinkler", "Advanced Sprinkler", "Master Sprinkler", "Godly Sprinkler", "Honey Sprinkler", "Chocolate Sprinkler"}
local selectedSprinklers = {}

-- Auto-buy variables
local autoBuyEnabled = false
local buyConnection = nil

-- Orion UI
local Window = OrionLib:MakeWindow({
	Name = "GAGSL Hub (v1.2)",
	HidePremium = false,
	IntroText = "Grow A Garden Script Loader",
	SaveConfig = false
})

-- Wait for intro to finish before showing the main GUI with a transition
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

-- Helper functions for sprinklers
local function getSprinklerTypes()
    return sprinklerTypes
end

local function setSelectedSprinklers(selected)
    selectedSprinklers = selected
end

local function getSelectedSprinklers()
    return selectedSprinklers
end

local function clearSelectedSprinklers()
    selectedSprinklers = {}
end

local function addSprinklerToSelection(sprinklerName)
    for i, sprinkler in ipairs(selectedSprinklers) do
        if sprinkler == sprinklerName then
            return false
        end
    end
    table.insert(selectedSprinklers, sprinklerName)
    return true
end

local function getSelectedSprinklersCount()
    return #selectedSprinklers
end

local function getSelectedSprinklersString()
    if #selectedSprinklers == 0 then
        return "None"
    end
    local selectionText = table.concat(selectedSprinklers, ", ")
    return #selectionText > 50 and (selectionText:sub(1, 47) .. "...") or selectionText
end

-- Helper functions for pets
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
    if buyConnection then
        buyConnection:Disconnect()
        buyConnection = nil
    end
    -- Clean up auto shovel connection
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

-- New Tab: Tools
local ToolsTab = Window:MakeTab({
	Name = "Main",
	Icon = "rbxassetid://6031280882",
	PremiumOnly = false
})

-- Display Server Version
ToolsTab:AddParagraph("Server Version🌐", tostring(game.PrivateServerId ~= "" and "Private Server" or game.PlaceVersion))

-- Input JobID
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

-- Copy Current Job ID Button
ToolsTab:AddButton({
	Name = "Copy Current Job ID",
	Callback = function()
		if setclipboard then
			local jobId = game.JobId
			setclipboard(jobId)
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

-- Rejoin Current Server
ToolsTab:AddButton({
	Name = "Rejoin Server",
	Callback = function()
		game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
	end
})

-- Server Hop
ToolsTab:AddButton({
	Name = "Server Hop",
	Callback = function()
		local HttpService = game:GetService("HttpService")
		local TeleportService = game:GetService("TeleportService")

		local function getServers()
			local success, result = pcall(function()
				return game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100")
			end)
			if success then
				local decoded = HttpService:JSONDecode(result)
				if decoded and decoded.data then
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
			OrionLib:MakeNotification({
				Name = "Server Found",
				Content = "Found server with " .. tostring(playerCount) .. " players.",
				Time = 3
			})
			task.wait(3)
			TeleportService:TeleportToPlaceInstance(game.PlaceId, foundServer, player)
		else
			OrionLib:MakeNotification({
				Name = "No Servers",
				Content = "Couldn't find a suitable server.",
				Time = 3
			})
		end
	end
})

local Tab = Window:MakeTab({
	Name = "Farm",
	Icon = "rbxassetid://6031280882",
	PremiumOnly = false
})

-- Sprinkler Section
Tab:AddParagraph("Shovel Sprikler", "Inf. Sprinkler Glitch")

-- Create sprinkler UI manually (since the function doesn't exist in CoreFunctions)
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
        -- Clear all previous selections
        clearSelectedSprinklers()
        
        -- Handle the selected values (array of sprinkler names)
        if selectedValues and #selectedValues > 0 then
            -- Check if "None" is selected
            local hasNone = false
            for _, value in pairs(selectedValues) do
                if value == "None" then
                    hasNone = true
                    break
                end
            end
            
            if not hasNone then
                -- Add all selected sprinklers to selection
                for _, sprinklerName in pairs(selectedValues) do
                    addSprinklerToSelection(sprinklerName)
                end
                
                -- Show notification of selection
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
        else
            OrionLib:MakeNotification({
                Name = "Selection Cleared",
                Content = "No sprinklers selected",
                Time = 2
            })
        end
    end
})

-- Select All Toggle
Tab:AddToggle({
    Name = "Select All Sprinkler",
    Default = false,
    Callback = function(Value)
        if Value then
            -- Create a copy of all sprinkler types
            local allSprinklers = {}
            for _, sprinklerType in ipairs(getSprinklerTypes()) do
                table.insert(allSprinklers, sprinklerType)
            end
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

-- Delete Button
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

-- Pet Control Section
Tab:AddParagraph("Pet Exploit", "Auto Middle Pets, Select Pet to Exclude.")

-- Get initial pets
local initialPets = refreshPets()

petCountLabel = Tab:AddLabel("Pets Found: 0 | Selected: 0 | Excluded: 0")

-- Set the label in PetFunctions
PetFunctions.setPetCountLabel(petCountLabel)

-- Update pet count initially and periodically
updatePetCount()

task.spawn(function()
    while true do
        updatePetCount()
        task.wait(1)
    end
end)

-- Pet Exclusion Dropdown
petDropdown = Tab:AddDropdown({
    Name = "Select Pets to Exclude",
    Default = {}, -- Start with no exclusions
    Options = {"None"},
    Callback = function(selectedValues)
        -- Get current pets and excluded pets from PetFunctions
        excludedPets = PetFunctions.getExcludedPets()
        currentPetsList = PetFunctions.getCurrentPetsList()
        
        -- Clear all previous exclusions
        for petId, _ in pairs(excludedPets) do
            removeESPMarker(petId)
        end
        excludedPets = {}
        
        -- Handle the selected values (array of pet names)
        if selectedValues and #selectedValues > 0 then
            -- Check if "None" is selected or if array is empty
            local hasNone = false
            for _, value in pairs(selectedValues) do
                if value == "None" then
                    hasNone = true
                    break
                end
            end
            
            if not hasNone then
                -- Add all selected pets to exclusions
                for _, petName in pairs(selectedValues) do
                    local selectedPet = currentPetsList[petName]
                    if selectedPet then
                        excludedPets[selectedPet.id] = true
                        createESPMarker(selectedPet)
                    end
                end
            end
        end
        
        -- Update excluded pets in PetFunctions
        PetFunctions.setExcludedPets(excludedPets)
        updatePetCount()
        
        -- Show notification about exclusions
        local excludedCount = 0
        for _ in pairs(excludedPets) do
            excludedCount = excludedCount + 1
        end
        
        if excludedCount > 0 then
            OrionLib:MakeNotification({
                Name = "Pets Excluded",
                Content = "Excluded " .. excludedCount .. " pets from auto middle.",
                Image = "rbxassetid://4483345998",
                Time = 2
            })
        end
    end
})

-- Set the dropdown in PetFunctions
PetFunctions.setPetDropdown(petDropdown)

-- Combined Refresh and Auto Select All Button
Tab:AddButton({
    Name = "Refresh & Auto Select All Pets",
    Callback = function()
        -- Refresh pets
        local newPets = refreshPets()
        
        -- Auto select all pets (this will also clear exclusions via the dropdown callback)
        selectAllPets()
        updatePetCount()
        
        -- Clear the exclusion dropdown when selecting all pets
        if petDropdown then
            petDropdown:ClearAll()
        end
        
        OrionLib:MakeNotification({
            Name = "Pets Refreshed & Selected",
            Content = "Found " .. #newPets .. " pets and selected all for auto middle.",
            Image = "rbxassetid://4483345998",
            Time = 3
        })
    end
})

-- Auto Middle Toggle
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

Tab:AddParagraph("Auto Shovel", "Automatically shovel fruits based on weight threshold.")

-- FIXED: Fruit Selection Dropdown
local fruitDropdown = Tab:AddDropdown({
    Name = "Select Fruits to Shovel",
    Default = {},
    Options = (function()
        local options = {"None"}
        local fruitTypes = getFruitTypes()
        for _, fruitType in ipairs(fruitTypes) do
            table.insert(options, fruitType)
        end
        return options
    end)(),
    Callback = function(selectedValues)
        -- Clear all previous selections
        clearSelectedFruits()

        -- Handle the selected values (array of fruit names)
        if selectedValues and #selectedValues > 0 then
            -- Check if "None" is selected
            local hasNone = false
            for _, value in pairs(selectedValues) do
                if value == "None" then
                    hasNone = true
                    break
                end
            end

            if not hasNone then
                -- Add all selected fruits to selection
                for _, fruitName in pairs(selectedValues) do
                    addFruitToSelection(fruitName)
                end

                -- Show notification of selection
                OrionLib:MakeNotification({
                    Name = "Fruits Selected",
                    Content = string.format("Selected (%d): %s", 
                        getSelectedFruitsCount(), 
                        getSelectedFruitsString()),
                    Time = 3
                })
            else
                OrionLib:MakeNotification({
                    Name = "Selection Cleared",
                    Content = "No fruits selected",
                    Time = 2
                })
            end
        else
            OrionLib:MakeNotification({
                Name = "Selection Cleared",
                Content = "No fruits selected",
                Time = 2
            })
        end
    end
})

-- FIXED: Weight Threshold Input
Tab:AddTextbox({
    Name = "Weight Threshold (KG)",
    Default = "30",
    TextDisappear = false,
    Callback = function(value)
        local num = tonumber(value)
        if num and num >= 0 and num <= 500 then
            weightThreshold = num
            OrionLib:MakeNotification({
                Name = "Weight Updated",
                Content = "Weight threshold set to " .. value .. " KG",
                Time = 2
            })
        else
            OrionLib:MakeNotification({
                Name = "Invalid Weight",
                Content = "Please enter a number between 0 and 500",
                Time = 3
            })
        end
    end
})

-- FIXED: Refresh Fruit List Button
Tab:AddButton({
    Name = "Refresh Fruit List",
    Callback = function()
        local options = {"None"}
        local fruitTypes = getFruitTypes()
        for _, fruitType in ipairs(fruitTypes) do
            table.insert(options, fruitType)
        end

        -- Update the dropdown with new options
        fruitDropdown:Refresh(options, true)

        OrionLib:MakeNotification({
            Name = "List Refreshed",
            Content = "Fruit list updated with " .. (#options - 1) .. " types",
            Time = 2
        })
    end
})

Tab:AddToggle({
    Name = "Auto Shovel",
    Default = false,
    Callback = function(value)
        autoShovelEnabled = value
        
        if value then
            if autoShovelConnection then autoShovelConnection:Disconnect() end
            autoShovelConnection = RunService.Heartbeat:Connect(function()
                if autoShovelEnabled then
                    autoShovel()
                    task.wait(2) -- Increased wait time to reduce spam
                end
            end)
            
            OrionLib:MakeNotification({
                Name = "Auto Shovel Enabled",
                Content = "Shoveling fruits with weight < " .. weightThreshold .. " KG",
                Time = 2
            })
        else
            if autoShovelConnection then
                autoShovelConnection:Disconnect()
                autoShovelConnection = nil
            end
            
            OrionLib:MakeNotification({
                Name = "Auto Shovel Disabled",
                Content = "Stopped auto shoveling",
                Time = 2
            })
        end
    end
})

local ShopTab = Window:MakeTab({
    Name = "Shop",
    Icon = "rbxassetid://4835310745",
    PremiumOnly = false
})

-- Add Toggle
ShopTab:AddToggle({
    Name = "Auto Buy Zen",
    Default = false,
    Callback = function(Value)
        autoBuyEnabled = Value
        
        if autoBuyEnabled then
            -- Start auto buying
            buyConnection = RunService.Heartbeat:Connect(function()
                buyAllZenItems()
                task.wait(0.1) -- Small delay to prevent spam
            end)
            
            OrionLib:MakeNotification({
                Name = "Auto Buy Zen",
                Content = "Auto Buy Zen enabled!",
                Image = "rbxassetid://4483345998",
                Time = 2
            })
        else
            -- Stop auto buying
            if buyConnection then
                buyConnection:Disconnect()
                buyConnection = nil
            end
        end
    end    
})

ShopTab:AddToggle({
    Name = "Auto Buy Traveling Merchants",
    Default = false,
    Callback = function(Value)
        autoBuyEnabled = Value
        
        if autoBuyEnabled then
            -- Start auto buying
            buyConnection = RunService.Heartbeat:Connect(function()
                buyAllMerchantItems()
                task.wait(0.1) -- Small delay to prevent spam
            end)

            OrionLib:MakeNotification({
                Name = "Auto Buy Traveling Merchant",
                Content = "Auto Buy Traveling Merchant enabled!",
                Image = "rbxassetid://4483345998",
                Time = 2
            })

        else
            -- Stop auto buying
            if buyConnection then
                buyConnection:Disconnect()
                buyConnection = nil
            end
        end
    end    
})

ShopTab:AddParagraph("AUTO BUY GEARS", "COMING SOON...")
ShopTab:AddParagraph("AUTO BUY SEEDS", "COMING SOON...")

-- Misc Tab
local MiscTab = Window:MakeTab({
	Name = "Misc",
	Icon = "rbxassetid://6031280882",
	PremiumOnly = false
})

-- Lag Reduction Section
MiscTab:AddParagraph("Performance", "Reduce game lag by removing lag-causing objects.")

-- New Reduce Lag Button
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

-- NEW: Remove Farms Button
MiscTab:AddButton({
	Name = "Remove Farms (Stay close to your farm)",
	Callback = function()
		removeFarms()
	end
})

-- Social Tab
local SocialTab = Window:MakeTab({
	Name = "Social",
	Icon = "rbxassetid://6031075938", -- You can change this icon
	PremiumOnly = false
})

-- TikTok Section
SocialTab:AddParagraph("TIKTOK", "@yurahaxyz        |        @yurahayz")

-- YouTube Section
SocialTab:AddParagraph("YOUTUBE", "YUraxYZ")

-- Discord Button
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

-- Cleanup on script end
Players.PlayerRemoving:Connect(function(player)
    if player == Players.LocalPlayer then
        cleanup()
    end
end)

-- Final notification
OrionLib:MakeNotification({
    Name = "GAGSL Hub Loaded",
    Content = "GAGSL Hub loaded with +999 Pogi Points!",
})
