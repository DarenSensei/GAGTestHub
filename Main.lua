-- Main GAGSL Hub Script (FIXED)
repeat task.wait() until game:IsLoaded()

-- Load the GG-Functions module (Script 2)
local Functions = loadstring(game:HttpGet("https://raw.githubusercontent.com/DarenSensei/GAGTestHub/refs/heads/main/CoreFunctions.lua"))()

local PetFunctions = loadstring(game:HttpGet("https://raw.githubusercontent.com/DarenSensei/GAGTestHub/refs/heads/main/PetMiddleFunctions.lua"))()

local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/YuraScripts/GrowAFilipinoy/refs/heads/main/TEST.lua"))()

-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

-- Variables
local autoBuyZenEnabled = false
local autoBuyMerchantEnabled = false
local autoShovelEnabled = false

-- Orion UI
local Window = OrionLib:MakeWindow({
    Name = "GAGSL Hub (v1.2)",
    HidePremium = false,
    IntroText = "Grow A Garden Script Loader",
    SaveConfig = false
})

-- Wait for intro to finish before showing the main GUI with a transition
local function fadeInMainTab()
    Functions.fadeInMainTab()
end

task.delay(1.5, fadeInMainTab)

-- Tools Tab
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
        local foundServer, playerCount = Functions.serverHop()
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

-- Farm Tab
local Tab = Window:MakeTab({
    Name = "Farm",
    Icon = "rbxassetid://6031280882",
    PremiumOnly = false
})

-- Sprinkler Section
Tab:AddParagraph("Shovel Sprinkler", "Inf. Sprinkler Glitch")

-- Create sprinkler dropdown
local sprinklerDropdown = Tab:AddDropdown({
    Name = "Select Sprinkler to Delete",
    Default = {},
    Options = (function()
        local options = {"None"}
        for _, sprinklerType in ipairs(Functions.getSprinklerTypes()) do
            table.insert(options, sprinklerType)
        end
        return options
    end)(),
    Callback = function(selectedValues)
        -- Clear all previous selections
        Functions.clearSelectedSprinklers()
        
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
                    Functions.addSprinklerToSelection(sprinklerName)
                end
                
                -- Show notification of selection
                OrionLib:MakeNotification({
                    Name = "Selection Updated",
                    Content = string.format("Selected (%d): %s", 
                        Functions.getSelectedSprinklersCount(), 
                        Functions.getSelectedSprinklersString()),
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
            for _, sprinklerType in ipairs(Functions.getSprinklerTypes()) do
                table.insert(allSprinklers, sprinklerType)
            end
            Functions.setSelectedSprinklers(allSprinklers)
            
            OrionLib:MakeNotification({
                Name = "All Selected",
                Content = string.format("Selected all %d sprinkler types", #allSprinklers),
                Time = 3
            })
        else
            Functions.clearSelectedSprinklers()
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
        local selectedArray = Functions.getSelectedSprinklers()
        
        if #selectedArray == 0 then
            OrionLib:MakeNotification({
                Name = "No Selection",
                Content = "Please select sprinkler type(s) first",
                Time = 4
            })
            return
        end
        
        Functions.deleteSprinklers(selectedArray, OrionLib)
    end
})

-- Auto Shovel Section
Tab:AddParagraph("Auto Shovel", "Auto Shovel Trees Based on Weight")

local treeDropdown = Tab:AddDropdown({
    Name = "Select Trees to Shovel",
    Default = {},
    Options = (function()
        local options = {"None"}
        for _, treeType in ipairs(Functions.getTreeTypes()) do
            table.insert(options, treeType)
        end
        return options
    end)(),
    Callback = function(selectedValues)
        Functions.clearSelectedTrees()
        
        if selectedValues and #selectedValues > 0 then
            local hasNone = false
            for _, value in pairs(selectedValues) do
                if value == "None" then
                    hasNone = true
                    break
                end
            end
            
            if not hasNone then
                for _, treeName in pairs(selectedValues) do
                    Functions.addTreeToSelection(treeName)
                end
                
                OrionLib:MakeNotification({
                    Name = "Trees Selected",
                    Content = string.format("Selected (%d): %s", 
                        Functions.getSelectedTreesCount(), 
                        Functions.getSelectedTreesString()),
                    Time = 3
                })
            end
        end
    end
})

local weightSlider = Tab:AddSlider({
    Name = "Weight Threshold (kg)",
    Min = 1,
    Max = 500,
    Default = 1,
    Color = Color3.fromRGB(255, 255, 255),
    Increment = 1,
    ValueName = "kg",
    Callback = function(Value)
        Functions.setWeightThreshold(Value, OrionLib)
    end    
})

local autoShovelToggle = Tab:AddToggle({
    Name = "Auto Shovel Fruits",
    Default = false,
    Callback = function(Value)
        if Value then
            -- Check if any trees are selected
            if Functions.getSelectedTreesCount() == 0 then
                OrionLib:MakeNotification({
                    Name = "No Trees Selected",
                    Content = "Please select trees from the dropdown first",
                    Time = 3
                })
                autoShovelToggle:Set(false)
                return
            end
        end
        autoShovelEnabled = Functions.toggleAutoShovel(OrionLib)
    end
})

-- Shop Tab
local ShopTab = Window:MakeTab({
    Name = "Shop",
    Icon = "rbxassetid://4835310745",
    PremiumOnly = false
})

-- Auto Buy Zen Toggle
ShopTab:AddToggle({
    Name = "Auto Buy Zen",
    Default = false,
    Callback = function(Value)
        autoBuyZenEnabled = Value
        Functions.toggleAutoBuyZen(Value)
        
        if Value then
            OrionLib:MakeNotification({
                Name = "Auto Buy Zen",
                Content = "Auto Buy Zen enabled!",
                Image = "rbxassetid://4483345998",
                Time = 2
            })
        else
            OrionLib:MakeNotification({
                Name = "Auto Buy Zen",
                Content = "Auto Buy Zen disabled!",
                Time = 2
            })
        end
    end    
})

ShopTab:AddToggle({
    Name = "Auto Buy Traveling Merchants",
    Default = false,
    Callback = function(Value)
        autoBuyMerchantEnabled = Value
        Functions.toggleAutoBuyMerchant(Value)

        if Value then
            OrionLib:MakeNotification({
                Name = "Auto Buy Traveling Merchant",
                Content = "Auto Buy Traveling Merchant enabled!",
                Image = "rbxassetid://4483345998",
                Time = 2
            })
        else
            OrionLib:MakeNotification({
                Name = "Auto Buy Traveling Merchant",
                Content = "Auto Buy Traveling Merchant disabled!",
                Time = 2
            })
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

-- Reduce Lag Button
MiscTab:AddButton({
    Name = "Reduce Lag",
    Callback = function()
        Functions.reduceLag()
        
        OrionLib:MakeNotification({
            Name = "Lag Reduced",
            Content = "All lag objects have been removed.",
            Time = 3
        })
    end
})

-- Remove Farms Button
MiscTab:AddButton({
    Name = "Remove Farms (Stay close to your farm)",
    Callback = function()
        Functions.removeFarms(OrionLib)
    end
})

-- Social Tab
local SocialTab = Window:MakeTab({
    Name = "Social",
    Icon = "rbxassetid://6031075938",
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
        Functions.copyDiscordLink()
    end
})

-- Cleanup on script end
Players.PlayerRemoving:Connect(function(playerLeaving)
    if playerLeaving == Players.LocalPlayer then
        Functions.cleanup()
    end
end)

-- Final notification
OrionLib:MakeNotification({
    Name = "GAGSL Hub Loaded",
    Content = "GAGSL Hub loaded with +999 Pogi Points!",
})
