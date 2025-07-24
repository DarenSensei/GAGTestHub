-- Vuln
-- Vuln External Functions (DinoTable removed)
local Vuln = {}

-- State variables
local selectedCraftItems = {}
local craftDropdown = nil
local teleportEnabled = false

-- Services (assuming these are available globally)
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Backpack = LocalPlayer:WaitForChild("Backpack")
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local CraftingService = ReplicatedStorage.GameEvents.CraftingGlobalObjectService

-- Helper function for safe calls
local function safeCall(func, funcName, ...)
    if not func then
        print("Warning: Function", funcName, "is nil")
        return nil
    end
    
    local success, result = pcall(func, ...)
    if not success then
        print("Error in", funcName, ":", result)
        return nil
    end
    return result
end

-- Get Dino Table function (improved error handling)
function Vuln.getDinoTable()
    local maxAttempts = 5
    local attempt = 0
    
    while attempt < maxAttempts do
        attempt = attempt + 1
        print("Attempting to get dino table, attempt:", attempt)
        
        local success, result = pcall(function()
            -- Try multiple locations for the dino event
            local dinoEvent = workspace:FindFirstChild("DinoEvent")
            
            if not dinoEvent then
                -- Look in ReplicatedStorage
                dinoEvent = ReplicatedStorage:FindFirstChild("DinoEvent")
                if dinoEvent then
                    print("Found DinoEvent in ReplicatedStorage, moving to workspace")
                    dinoEvent.Parent = workspace
                end
            end
            
            if not dinoEvent then
                -- Try to find it in modules
                local modules = ReplicatedStorage:FindFirstChild("Modules")
                if modules then
                    local updateService = modules:FindFirstChild("UpdateService")
                    if updateService then
                        dinoEvent = updateService:FindFirstChild("DinoEvent")
                        if dinoEvent then
                            print("Found DinoEvent in UpdateService, moving to workspace")
                            dinoEvent.Parent = workspace
                        end
                    end
                end
            end
            
            if not dinoEvent then
                error("DinoEvent not found in any location")
            end
            
            -- Wait for the crafting table
            local craftingTable = dinoEvent:WaitForChild("DinoCraftingTable", 10)
            if not craftingTable then
                error("DinoCraftingTable not found")
            end
            
            print("Successfully found crafting table:", craftingTable)
            return craftingTable
        end)
        
        if success and result then
            print("Dino table acquired successfully")
            return result
        else
            print("Failed to get dino table, attempt", attempt, "Error:", result)
            if attempt < maxAttempts then
                task.wait(2) -- Wait before retry
            end
        end
    end
    
    print("Failed to get dino table after", maxAttempts, "attempts")
    return nil
end

-- Enhanced crafting function with validation
function Vuln.safeCraftingOperation(craftFunction, recipeName)
    local table = Vuln.getDinoTable()
    if not table then 
        print("ERROR: Could not get dino table for", recipeName)
        return false
    end
    
    print("Setting recipe for:", recipeName)
    local success = pcall(function()
        CraftingService:FireServer("SetRecipe", table, "DinoEventWorkbench", recipeName)
    end)
    
    if not success then
        print("ERROR: Failed to set recipe for", recipeName)
        return false
    end
    
    task.wait(0.5) -- Increased wait time
    
    return craftFunction(table)
end

-- Auto Dino Egg crafting function
function Vuln.autoDinoEgg()
    return Vuln.safeCraftingOperation(function(table)
        print("Crafting Dinosaur Egg - Looking for ingredients")
        
        -- Find and input Common Egg (slot 1)
        local commonEggFound = false
        for _, tool in ipairs(Backpack:GetChildren()) do
            if tool:IsA("Tool") and tool:GetAttribute("h") == "Common Egg" then
                tool.Parent = Character
                task.wait(0.3)
                local uuid = tool:GetAttribute("c")
                if uuid then
                    local success = pcall(function()
                        CraftingService:FireServer("InputItem", table, "DinoEventWorkbench", 1, {
                            ItemType = "PetEgg",
                            ItemData = { UUID = uuid }
                        })
                    end)
                    if success then
                        print("Successfully input Common Egg")
                        commonEggFound = true
                    else
                        print("ERROR: Failed to input Common Egg")
                    end
                end
                tool.Parent = Backpack
                break
            end
        end
        
        if not commonEggFound then
            print("ERROR: No Common Egg found in backpack")
            return false
        end
        
        -- Find and input Bone Blossom (slot 2)
        local blossomFound = false
        for _, tool in ipairs(Backpack:GetChildren()) do
            if tool:IsA("Tool") and tool:GetAttribute("f") == "Bone Blossom" then
                -- Remove any equipped tools first
                for _, t in ipairs(Character:GetChildren()) do
                    if t:IsA("Tool") then
                        t.Parent = Backpack
                    end
                end
                tool.Parent = Character
                task.wait(0.3)
                local uuid = tool:GetAttribute("c")
                if uuid then
                    local success = pcall(function()
                        CraftingService:FireServer("InputItem", table, "DinoEventWorkbench", 2, {
                            ItemType = "Holdable",
                            ItemData = { UUID = uuid }
                        })
                    end)
                    if success then
                        print("Successfully input Bone Blossom")
                        blossomFound = true
                    else
                        print("ERROR: Failed to input Bone Blossom")
                    end
                end
                tool.Parent = Backpack
                break
            end
        end
        
        if not blossomFound then
            print("ERROR: No Bone Blossom found in backpack")
            return false
        end
        
        task.wait(0.3)
        print("All ingredients input successfully - attempting to craft")
        local success = pcall(function()
            CraftingService:FireServer("Craft", table, "DinoEventWorkbench")
        end)
        
        if not success then
            print("ERROR: Failed to craft Dinosaur Egg")
            return false
        end
        
        print("Dinosaur Egg crafting completed successfully")
        task.wait(1.5)
        
        if teleportEnabled then 
            print("Saving state before teleport - Teleport:", teleportEnabled)
            task.wait(1)
            TeleportService:Teleport(game.PlaceId) 
        else
            print("Auto-teleport disabled - continuing to craft more eggs")
        end
        return true
    end, "Dinosaur Egg")
end

-- Auto Ancient Pack crafting function
function Vuln.autoAncientPack()
    return Vuln.safeCraftingOperation(function(table)
        print("Crafting Ancient Seed Pack")
        
        -- Find and equip dinosaur egg
        local eggFound = false
        for _, tool in ipairs(Backpack:GetChildren()) do
            if tool:IsA("Tool") and tool:GetAttribute("h") == "Dinosaur Egg" then
                tool.Parent = Character
                task.wait(0.5)
                local uuid = tool:GetAttribute("c")
                if uuid then
                    local success = pcall(function()
                        CraftingService:FireServer("InputItem", table, "DinoEventWorkbench", 1, {
                            ItemType = "PetEgg",
                            ItemData = { UUID = uuid }
                        })
                    end)
                    if not success then
                        print("ERROR: Failed to input Dinosaur Egg")
                    else
                        eggFound = true
                    end
                end
                tool.Parent = Backpack
                break
            end
        end
        
        if not eggFound then
            print("ERROR: No Dinosaur Egg found in backpack")
            return false
        end
        
        task.wait(0.5)
        local success = pcall(function()
            CraftingService:FireServer("Craft", table, "DinoEventWorkbench")
        end)
        
        if not success then
            print("ERROR: Failed to craft Ancient Seed Pack")
            return false
        end
        
        task.wait(1.5)
        
        if teleportEnabled then 
            print("Saving state before teleport - Teleport:", teleportEnabled)
            task.wait(1)
            TeleportService:Teleport(game.PlaceId) 
        end
        return true
    end, "Ancient Seed Pack")
end

-- Auto Primal Egg crafting function
function Vuln.autoPrimalEgg()
    return Vuln.safeCraftingOperation(function(table)
        print("Crafting Primal Egg")
        
        -- Find and equip dinosaur egg
        local eggFound = false
        for _, tool in ipairs(Backpack:GetChildren()) do
            if tool:IsA("Tool") and tool:GetAttribute("h") == "Dinosaur Egg" then
                tool.Parent = Character
                task.wait(0.5)
                local uuid = tool:GetAttribute("c")
                if uuid then
                    local success = pcall(function()
                        CraftingService:FireServer("InputItem", table, "DinoEventWorkbench", 1, {
                            ItemType = "PetEgg",
                            ItemData = { UUID = uuid }
                        })
                    end)
                    if not success then
                        print("ERROR: Failed to input Dinosaur Egg")
                    else
                        eggFound = true
                    end
                end
                tool.Parent = Backpack
                break
            end
        end
        
        if not eggFound then
            print("ERROR: No Dinosaur Egg found in backpack")
            return false
        end
        
        -- Find and equip bone blossom
        local blossomFound = false
        for _, tool in ipairs(Backpack:GetChildren()) do
            if tool:IsA("Tool") and tool:GetAttribute("f") == "Bone Blossom" then
                -- Remove any equipped tools first
                for _, t in ipairs(Character:GetChildren()) do
                    if t:IsA("Tool") then
                        t.Parent = Backpack
                    end
                end
                tool.Parent = Character
                task.wait(0.5)
                local uuid = tool:GetAttribute("c")
                if uuid then
                    local success = pcall(function()
                        CraftingService:FireServer("InputItem", table, "DinoEventWorkbench", 2, {
                            ItemType = "Holdable",
                            ItemData = { UUID = uuid }
                        })
                    end)
                    if not success then
                        print("ERROR: Failed to input Bone Blossom")
                    else
                        blossomFound = true
                    end
                end
                tool.Parent = Backpack
                break
            end
        end
        
        if not blossomFound then
            print("ERROR: No Bone Blossom found in backpack")
            return false
        end
        
        task.wait(0.5)
        local success = pcall(function()
            CraftingService:FireServer("Craft", table, "DinoEventWorkbench")
        end)
        
        if not success then
            print("ERROR: Failed to craft Primal Egg")
            return false
        end
        
        task.wait(1.5)
        
        if teleportEnabled then 
            print("Saving state before teleport - Teleport:", teleportEnabled)
            task.wait(1)
            TeleportService:Teleport(game.PlaceId) 
        end
        return true
    end, "Primal Egg")
end

-- Craft functions mapping
local craftFunctions = {
    ["Dino Egg"] = Vuln.autoDinoEgg,
    ["Ancient Seed Pack"] = Vuln.autoAncientPack,
    ["Primal Egg"] = Vuln.autoPrimalEgg
}

-- Start auto craft function (now accepts teleportEnabled parameter)
function Vuln.startAutoCraft(selectedItems, shouldTeleport)
    if not selectedItems or next(selectedItems) == nil then
        print("No items selected for crafting")
        return
    end
    
    -- Update teleport setting for this crafting session
    teleportEnabled = shouldTeleport or false
    print("Starting auto craft with teleport enabled:", teleportEnabled)
    
    -- Start crafting loop for selected items
    spawn(function()
        while next(selectedCraftItems) ~= nil do
            for itemName, _ in pairs(selectedItems) do
                if selectedCraftItems[itemName] then
                    local craftFunc = craftFunctions[itemName]
                    if craftFunc then
                        local success = safeCall(craftFunc, "craft" .. itemName:gsub(" ", ""))
                        if not success then
                            print("Failed to craft", itemName, "- retrying in 3 seconds")
                            task.wait(3)
                        else
                            task.wait(1.5)
                        end
                    end
                end
            end
            task.wait(1) -- Small delay between cycles
        end
    end)
end

-- Stop auto craft function
function Vuln.stopAutoCraft()
    selectedCraftItems = {}
    print("Auto craft stopped")
end

-- Setter functions for external use
function Vuln.setSelectedCraftItems(items)
    selectedCraftItems = items or {}
end

function Vuln.setCraftDropdown(dropdown)
    craftDropdown = dropdown
end

function Vuln.setTeleportEnabled(enabled)
    teleportEnabled = enabled
end

-- Getter functions
function Vuln.getSelectedCraftItems()
    return selectedCraftItems
end

function Vuln.getTeleportEnabled()
    return teleportEnabled
end

return Vuln
