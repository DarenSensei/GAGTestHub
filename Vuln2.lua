-- External module
local vuln = {}

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer

-- Wait for ReplicatedStorage to load GameEvents
local GameEvents = ReplicatedStorage:WaitForChild("GameEvents")
local ZenQuestRemoteEvent = GameEvents:WaitForChild("ZenQuestRemoteEvent")

-- Configuration
local autoVulnEnabled = false
local autoVulnConnection = nil
local farmDuration = 60 -- How long to farm at teleport position (seconds)
local waitDuration = 10 -- How long to wait at old position (seconds)
local storedPosition = nil
local teleportPosition = CFrame.new(-102.564087, 2.99999976, -9.10526657) -- Default from your debug info

-- Blacklisted items that should not be equipped
local blacklistedItems = {
    "Tranquil Radar",
    "Corrupt Radar", 
    "Pet Shard Tranquil",
    "Pet Shard Corrupt",
    "Corrupted Kitsune",
    "Tranquil Bloom Seed",
    "Corrupted Zen Crate",
    "Corrupt Staff",
    "Mutation Spray Tranquil",
    "Mutation Spray Corrupt",
    "Tranquil Staff",
    "Corrupted Kodama"
}

-- Position storage and teleportation functions
function vuln.storeCurrentPosition()
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        storedPosition = player.Character.HumanoidRootPart.CFrame
        return true
    end
    return false
end

function vuln.teleportToStoredPosition()
    if storedPosition and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        player.Character.HumanoidRootPart.CFrame = storedPosition
        return true
    end
    return false
end

function vuln.teleportToFarmPosition()
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        player.Character.HumanoidRootPart.CFrame = teleportPosition
        return true
    end
    return false
end

function vuln.setFarmDuration(seconds)
    if seconds and seconds >= 0.1 then
        farmDuration = seconds
        return true, "Farm duration set to " .. seconds .. " seconds"
    else
        return false, "Invalid farm duration. Must be at least 0.1 seconds"
    end
end

function vuln.setWaitDuration(seconds)
    if seconds and seconds >= 0.1 then
        waitDuration = seconds
        return true, "Wait duration set to " .. seconds .. " seconds"
    else
        return false, "Invalid wait duration. Must be at least 0.1 seconds"
    end
end

function vuln.setTeleportPosition(x, y, z)
    if x and y and z then
        teleportPosition = CFrame.new(x, y, z)
        return true, "Teleport position set to (" .. x .. ", " .. y .. ", " .. z .. ")"
    else
        return false, "Invalid coordinates"
    end
end

function vuln.getFarmDuration()
    return farmDuration
end

function vuln.getWaitDuration()
    return waitDuration
end

-- Existing functions
function vuln.findAndEquipFruit(fruitType)
    if not player.Character then return false end
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return false end
    
    -- First, unequip any currently equipped tools
    for _, item in pairs(player.Character:GetChildren()) do
        if item:IsA("Tool") then
            item.Parent = backpack
        end
    end
    
    -- Then find and equip the requested fruit type
    for _, item in pairs(backpack:GetChildren()) do
        if item:IsA("Tool") and string.find(item.Name, fruitType) and string.find(item.Name, "%[.+kg%]") then
            -- Check if item is blacklisted
            local isBlacklisted = false
            for _, blacklistedName in pairs(blacklistedItems) do
                if item.Name == blacklistedName then
                    isBlacklisted = true
                    break
                end
            end
            
            -- Only equip if not blacklisted
            if not isBlacklisted then
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

-- Modified auto vuln submission with fast switching
function vuln.autoVulnSubmission()
    if not autoVulnEnabled then return end
    
    -- Store current position before starting
    vuln.storeCurrentPosition()
    
    -- Teleport to farm position
    vuln.teleportToFarmPosition()
    task.wait(0.5) -- Small delay to ensure teleport completes
    
    -- Farm for specified duration with alternating fruits
    local farmStartTime = tick()
    local useTranquil = true -- Start with Tranquil
    
    while autoVulnEnabled and (tick() - farmStartTime) < farmDuration do
        local fruitType = useTranquil and "Tranquil" or "Corrupt"
        
        -- Unequip, find and equip, submit, switch
        vuln.findAndEquipFruit(fruitType)
        vuln.submitToFox()
        
        -- Switch to the other fruit type for next iteration
        useTranquil = not useTranquil
        
        -- Wait 0.5 seconds before switching to the other fruit
        task.wait(0.5)
    end
    
    -- Return to stored position
    if storedPosition then
        vuln.teleportToStoredPosition()
        task.wait(0.5) -- Small delay to ensure teleport completes
    end
    
    -- Wait at old position
    task.wait(waitDuration)
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
                -- No additional wait here since autoVulnSubmission handles timing
            end
        end)
        
        return true, "Auto Vuln Submission Started - Fast Switch Mode (0.5s intervals) - Farm: " .. farmDuration .. "s, Wait: " .. waitDuration .. "s"
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
