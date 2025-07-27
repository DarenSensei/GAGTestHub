-- External module
local vuln = {}

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
-- Wait for ReplicatedStorage to load GameEvents
local GameEvents = ReplicatedStorage:WaitForChild("GameEvents")
local ZenQuestRemoteEvent = GameEvents:WaitForChild("ZenQuestRemoteEvent")
-- Configuration
local autoVulnEnabled = false
local autoVulnConnection = nil

-- Function to check if an item is a fruit
local function isFruitItem(item)
    -- Check if the item has the fruit item configuration
    local itemConfig = item:FindFirstChild("ItemConfig")
    if itemConfig then
        local itemType = itemConfig:FindFirstChild("ItemType")
        if itemType and itemType.Value == "Fruit" then
            return true
        end
    end
    return false
end

-- Functions
function vuln.findAndEquipFruit(fruitType)
    if not player.Character then return false end
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return false end
    
    for _, item in pairs(backpack:GetChildren()) do
        if item:IsA("Tool") and string.find(item.Name, fruitType) then
            -- Only equip if it's actually a fruit item
            if isFruitItem(item) then
                item.Parent = player.Character
                return true
            end
        end
    end
    return false
end
function vuln.submitToFox()
    if ZenQuestRemoteEvent then
        ZenQuestRemoteEvent:FireServer("SubmitToFox")
    end
end
function vuln.returnItemToBackpack()
    if not player.Character then return end
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return end
    
    for _, item in pairs(player.Character:GetChildren()) do
        if item:IsA("Tool") then
            item.Parent = backpack
        end
    end
end
function vuln.autoVulnSubmission()
    if not autoVulnEnabled then return end
    
    -- Tranquil first
    if vuln.findAndEquipFruit("Tranquil") then
        task.wait(0.5)
        vuln.submitToFox()
        task.wait(1)
        vuln.returnItemToBackpack()
        task.wait(0.5)
    end
    
    -- Corrupt second
    if vuln.findAndEquipFruit("Corrupt") then
        task.wait(0.5)
        vuln.submitToFox()
        task.wait(1)
        vuln.returnItemToBackpack()
        task.wait(0.5)
    end
end
function vuln.getAutoVulnStatus()
    return autoVulnEnabled
end
function vuln.toggleAutoVuln(enabled)
    autoVulnEnabled = enabled
    
    if enabled then
        if autoVulnConnection then 
            task.cancel(autoVulnConnection)
            autoVulnConnection = nil
        end
        
        autoVulnConnection = task.spawn(function()
            while autoVulnEnabled do
                vuln.autoVulnSubmission()
                task.wait(2)
            end
        end)
        
        return true, "Auto Vuln Submission Started"
    else
        if autoVulnConnection then
            task.cancel(autoVulnConnection)
            autoVulnConnection = nil
        end
        autoVulnEnabled = false
        
        return true, "Auto Vuln Submission Stopped"
    end
end
return vuln
