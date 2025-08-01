-- Pet Control Functions Module
-- This module contains all pet-related functionality

local PetFunctions = {}

-- Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Pet Radius Control Configuration
local RADIUS = 3
local LOOP_DELAY = 1
local INITIAL_LOOP_TIME = 3
local ZONE_ABILITY_DELAY = 1
local ZONE_ABILITY_LOOP_TIME = 3
local AUTO_LOOP_INTERVAL = 240 -- 4 minutes in seconds

-- Pet Control Services
local ActivePetService = ReplicatedStorage.GameEvents.ActivePetService
local PetZoneAbility = ReplicatedStorage.GameEvents.PetZoneAbility
local Notification = ReplicatedStorage.GameEvents.Notification
local GetPetCooldown = ReplicatedStorage.GameEvents.GetPetCooldown

-- Pet Control Variables
local activePetUI = nil
local scrollingFrame = nil
local selectedPets = {}
local includedPets = {}
local allPetsSelected = false
local autoMiddleEnabled = false
local autoMiddleConnection = nil
local zoneAbilityConnection = nil
local notificationConnection = nil
local loopTimer = nil
local delayTimer = nil
local isLooping = false
local petDropdown = nil
local currentPetsList = {}
local lastZoneAbilityTime = 0 -- Track last zone ability time

-- Cooldown Timer Variables
local cooldownTimerEnabled = false
local cooldownTargetPetId = nil
local cooldownDuration = 80 -- Default 80 seconds (1:20)
local cooldownMonitorConnection = nil

-- Function to check if string is UUID format
function PetFunctions.isValidUUID(str)
    if not str or type(str) ~= "string" then return false end
    str = string.gsub(str, "[{}]", "")
    return string.match(str, "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
end

-- Function to initialize ActivePetUI references
function PetFunctions.initializeActivePetUI()
    local player = Players.LocalPlayer
    if not player then return false end

    local playerGui = player:WaitForChild("PlayerGui", 5)
    if not playerGui then return false end

    activePetUI = playerGui:WaitForChild("ActivePetUI", 5)
    if not activePetUI then return false end

    local frame = activePetUI:WaitForChild("Frame", 2)
    if not frame then return false end

    local main = frame:WaitForChild("Main", 2)
    if not main then return false end

    scrollingFrame = main:WaitForChild("ScrollingFrame", 2)
    if not scrollingFrame then return false end

    return true
end

-- Function to find pet mover in workspace by UUID
function PetFunctions.findPetMoverByUUID(uuid)
    -- Remove curly braces for comparison
    local cleanUUID = string.gsub(uuid, "[{}]", "")

    -- Search through workspace for pet movers
    local function searchInFolder(folder)
        for _, child in pairs(folder:GetChildren()) do
            if child:IsA("Part") and child.Name == "PetMover" then
                local petId = PetFunctions.getPetIdFromPetMover(child)
                if petId then
                    local cleanPetId = string.gsub(tostring(petId), "[{}]", "")
                    if cleanPetId == cleanUUID then
                        return child
                    end
                end
            elseif child:IsA("Model") or child:IsA("Folder") then
                local result = searchInFolder(child)
                if result then return result end
            end
        end
        return nil
    end

    return searchInFolder(Workspace)
end

-- Function to get pet ID from PetMover
function PetFunctions.getPetIdFromPetMover(petMover)
    if not petMover then return nil end

    local petId = petMover:GetAttribute("PetId") or 
                 petMover:GetAttribute("Id") or 
                 petMover:GetAttribute("UUID") or
                 petMover:GetAttribute("petId")

    if petId then return petId end

    if petMover.Parent and PetFunctions.isValidUUID(petMover.Parent.Name) then
        return petMover.Parent.Name
    end

    if PetFunctions.isValidUUID(petMover.Name) then
        return petMover.Name
    end

    return petMover:GetFullName()
end

-- Function to get all pets from ActivePetUI
function PetFunctions.getAllPets()
    local pets = {}

    if not scrollingFrame then
        if not PetFunctions.initializeActivePetUI() then
            return pets
        end
    end

    -- Iterate through children of ScrollingFrame
    for _, child in pairs(scrollingFrame:GetChildren()) do
        if child:IsA("Frame") and PetFunctions.isValidUUID(child.Name) then
            local uuid = child.Name
            local petType = "Pet" -- Default type

            -- Try to get pet type from PET_TYPE child
            local petTypeChild = child:FindFirstChild("PET_TYPE")
            if petTypeChild and petTypeChild:IsA("TextLabel") then
                petType = petTypeChild.Text or "Pet"
            end

            -- Find the corresponding PetMover in workspace
            local petMover = PetFunctions.findPetMoverByUUID(uuid)

            -- Create pet entry
            local petEntry = {
                id = uuid,
                name = petType,
                model = child, -- UI element
                mover = petMover, -- Physical part in workspace
                position = petMover and petMover.Position or Vector3.new(0, 0, 0)
            }

            table.insert(pets, petEntry)
        end
    end

    return pets
end

-- Function to get farm center point
function PetFunctions.getFarmCenterPoint()
    local player = Players.LocalPlayer
    if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return nil
    end

    local playerPosition = player.Character.HumanoidRootPart.Position
    local farmFolder = Workspace:FindFirstChild("Farm")

    if farmFolder then
        local closestFarm = nil
        local closestDistance = math.huge

        for _, farm in pairs(farmFolder:GetChildren()) do
            local centerPoint = farm:FindFirstChild("Center_Point")
            if centerPoint then
                local distance = (playerPosition - centerPoint.Position).Magnitude
                if distance < closestDistance then
                    closestDistance = distance
                    closestFarm = centerPoint.Position
                end
            end
        end

        return closestFarm
    end

    return playerPosition
end

-- Function to format pet ID to UUID format
function PetFunctions.formatPetIdToUUID(petId)
    if string.match(petId, "^{%x+%-%x+%-%x+%-%x+%-%x+}$") then
        return petId
    end

    petId = string.gsub(petId, "[{}]", "")
    return "{" .. petId .. "}"
end

-- Function to set pet state
function PetFunctions.setPetState(petId, state)
    local formattedPetId = PetFunctions.formatPetIdToUUID(petId)
    pcall(function()
        ActivePetService:FireServer("SetPetState", formattedPetId, state)
    end)
end

-- Function to get pet cooldown
function PetFunctions.getPetCooldown(petId)
    local formattedPetId = PetFunctions.formatPetIdToUUID(petId)
    local success, result = pcall(function()
        return GetPetCooldown:InvokeServer(formattedPetId)
    end)
    
    if success then
        return result
    else
        warn("Failed to get pet cooldown for " .. tostring(petId) .. ": " .. tostring(result))
        return nil
    end
end

-- Function to check if cooldown timer should block middle function
function PetFunctions.shouldBlockMiddleFunction()
    if not cooldownTimerEnabled or not cooldownTargetPetId then
        return false -- No cooldown monitoring, don't block
    end
    
    -- Get the target pet's cooldown
    local targetCooldown = PetFunctions.getPetCooldown(cooldownTargetPetId)
    
    if not targetCooldown then
        return false -- Can't get cooldown, don't block
    end
    
    -- Block if target pet's cooldown is above threshold
    return targetCooldown > cooldownDuration
end

-- Function to get target pet cooldown status
function PetFunctions.getTargetPetCooldownStatus()
    if not cooldownTimerEnabled or not cooldownTargetPetId then
        return {
            enabled = false,
            targetPet = nil,
            currentCooldown = 0,
            threshold = cooldownDuration,
            blocked = false,
            timeUntilReady = 0
        }
    end
    
    local currentCooldown = PetFunctions.getPetCooldown(cooldownTargetPetId) or 0
    local blocked = currentCooldown > cooldownDuration
    local timeUntilReady = math.max(0, currentCooldown - cooldownDuration)
    
    return {
        enabled = true,
        targetPet = cooldownTargetPetId,
        currentCooldown = currentCooldown,
        threshold = cooldownDuration,
        blocked = blocked,
        timeUntilReady = timeUntilReady
    }
end

-- Function to format time for display (MM:SS)
function PetFunctions.formatTime(seconds)
    local minutes = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%02d:%02d", minutes, secs)
end

-- Function to start cooldown monitoring
function PetFunctions.startCooldownMonitoring(targetPetId, thresholdDuration)
    -- Stop any existing monitoring
    PetFunctions.stopCooldownMonitoring()
    
    cooldownTargetPetId = targetPetId
    cooldownDuration = thresholdDuration or 80
    cooldownTimerEnabled = true
    
    print("Started cooldown monitoring for pet: " .. tostring(targetPetId))
    print("Threshold: " .. PetFunctions.formatTime(cooldownDuration))
    
    -- Set up monitoring connection
    cooldownMonitorConnection = RunService.Heartbeat:Connect(function()
        if not cooldownTimerEnabled then
            return
        end
        
        -- Monitor the target pet's cooldown
        local status = PetFunctions.getTargetPetCooldownStatus()
        -- You can add debugging here if needed
    end)
end

-- Function to stop cooldown monitoring
function PetFunctions.stopCooldownMonitoring()
    cooldownTimerEnabled = false
    cooldownTargetPetId = nil
    
    if cooldownMonitorConnection then
        cooldownMonitorConnection:Disconnect()
        cooldownMonitorConnection = nil
    end
    
    print("Stopped cooldown monitoring")
end

-- Function to get first pet ID from a pet type group
function PetFunctions.getFirstPetFromType(petType)
    if not currentPetsList or not currentPetsList[petType] then
        return nil
    end
    
    local petGroup = currentPetsList[petType]
    if type(petGroup) == "table" and #petGroup > 0 then
        return petGroup[1].id
    end
    
    return nil
end

-- Function to run the auto middle loop (modified to respect cooldown timer)
function PetFunctions.runAutoMiddleLoop()
    if not autoMiddleEnabled then return end
    
    -- Check if cooldown timer should block the middle function
    if PetFunctions.shouldBlockMiddleFunction() then
        return -- Block execution when target pet cooldown is above threshold
    end

    local pets = PetFunctions.getAllPets()
    local farmCenterPoint = PetFunctions.getFarmCenterPoint()

    if not farmCenterPoint then return end

    for _, pet in pairs(pets) do
        -- Check if pet should be included in middle function
        local shouldInclude = false
        
        if allPetsSelected then
            shouldInclude = true
        elseif PetFunctions.isPetIncluded(pet.id) then
            shouldInclude = true
        elseif selectedPets[pet.id] then
            shouldInclude = true
        end

        -- Only process pets that should be included
        if shouldInclude then
            -- Only process if we have a physical mover
            if pet.mover then
                local distance = (pet.mover.Position - farmCenterPoint).Magnitude
                if distance > RADIUS then
                    PetFunctions.setPetState(pet.id, "Idle")
                end
            end
        end
    end
end

-- Function to start the heartbeat loop
function PetFunctions.startLoop()
    if autoMiddleConnection then
        autoMiddleConnection:Disconnect()
    end

    isLooping = true
    autoMiddleConnection = RunService.Heartbeat:Connect(function()
        if not isLooping then return end
        PetFunctions.runAutoMiddleLoop()
        task.wait(LOOP_DELAY)
    end)
end

-- Function to stop the heartbeat loop
function PetFunctions.stopLoop()
    isLooping = false
    if autoMiddleConnection then
        autoMiddleConnection:Disconnect()
        autoMiddleConnection = nil
    end
end

-- Function to start initial loop
function PetFunctions.startInitialLoop()
    if not autoMiddleEnabled then return end

    PetFunctions.startLoop()

    if loopTimer then
        task.cancel(loopTimer)
    end

    loopTimer = task.spawn(function()
        task.wait(INITIAL_LOOP_TIME)
        if autoMiddleEnabled then
            PetFunctions.stopLoop()
        end
    end)
end

-- Function to start the auto middle system with cooldown timer integration
function PetFunctions.startAutoMiddleWithCooldownTimer()
    if not autoMiddleEnabled then return end
    
    -- If cooldown monitoring is enabled, ensure it's running
    if cooldownTimerEnabled and cooldownTargetPetId then
        PetFunctions.startCooldownMonitoring(cooldownTargetPetId, cooldownDuration)
    end
    
    -- Setup listeners and start the main loop
    PetFunctions.setupZoneAbilityListener()
    PetFunctions.setupNotificationListener()
    PetFunctions.startInitialLoop()
end

-- Function to handle PetZoneAbility detection
function PetFunctions.onPetZoneAbility()
    if not autoMiddleEnabled then return end

    -- Update the last zone ability time
    lastZoneAbilityTime = tick()

    if delayTimer then
        task.cancel(delayTimer)
    end

    delayTimer = task.spawn(function()
        task.wait(ZONE_ABILITY_DELAY)
        if autoMiddleEnabled then
            PetFunctions.startLoop()
            task.wait(ZONE_ABILITY_LOOP_TIME)
            if autoMiddleEnabled then
                PetFunctions.stopLoop()
            end
        end
    end)
end

-- Function to handle Notification signal detection
function PetFunctions.onNotificationSignal()
    if not autoMiddleEnabled then return end

    -- Run the loop when notification signal is detected
    PetFunctions.startLoop()
    task.wait(INITIAL_LOOP_TIME)
    if autoMiddleEnabled then
        PetFunctions.stopLoop()
    end
end

-- Function to setup PetZoneAbility listener
function PetFunctions.setupZoneAbilityListener()
    if zoneAbilityConnection then
        zoneAbilityConnection:Disconnect()
    end
    zoneAbilityConnection = PetZoneAbility.OnClientEvent:Connect(PetFunctions.onPetZoneAbility)
end

-- Function to setup Notification listener
function PetFunctions.setupNotificationListener()
    if notificationConnection then
        notificationConnection:Disconnect()
    end
    notificationConnection = Notification.OnClientEvent:Connect(PetFunctions.onNotificationSignal)
end

-- Function to cleanup all timers and connections
function PetFunctions.cleanup()
    PetFunctions.stopLoop()
    PetFunctions.stopCooldownMonitoring()

    if zoneAbilityConnection then
        zoneAbilityConnection:Disconnect()
        zoneAbilityConnection = nil
    end

    if notificationConnection then
        notificationConnection:Disconnect()
        notificationConnection = nil
    end

    if loopTimer then
        task.cancel(loopTimer)
        loopTimer = nil
    end
    if delayTimer then
        task.cancel(delayTimer)
        delayTimer = nil
    end
end

-- Function to select all pets
function PetFunctions.selectAllPets()
    selectedPets = {}
    allPetsSelected = true
    local pets = PetFunctions.getAllPets()
    for _, pet in pairs(pets) do
        selectedPets[pet.id] = true
    end
end

-- Function to update dropdown options
function PetFunctions.updateDropdownOptions()
    local pets = PetFunctions.getAllPets()
    currentPetsList = {}
    local dropdownOptions = {"None"}
    local petTypeGroups = {}

    -- Group pets by their type
    for i, pet in pairs(pets) do
        local petType = pet.name
        if not petTypeGroups[petType] then
            petTypeGroups[petType] = {}
        end
        table.insert(petTypeGroups[petType], pet)
    end

    -- Create dropdown options with grouped pets
    for petType, petGroup in pairs(petTypeGroups) do
        table.insert(dropdownOptions, petType)
        currentPetsList[petType] = petGroup -- Store the entire group
    end

    -- Update the dropdown options
    if petDropdown and petDropdown.Refresh then
        petDropdown:Refresh(dropdownOptions, true)
    end
end

-- Function to refresh pets
function PetFunctions.refreshPets()
    selectedPets = {}
    allPetsSelected = false
    -- Re-initialize ActivePetUI references
    PetFunctions.initializeActivePetUI()
    local pets = PetFunctions.getAllPets()

    PetFunctions.updateDropdownOptions()
    return pets
end

-- Helper functions for managing pet selection state
function PetFunctions.getSelectedPets()
    return selectedPets or {}
end

function PetFunctions.getIncludedPets()
    return includedPets or {}
end

function PetFunctions.getAllPetsSelected()
    return allPetsSelected or false
end

function PetFunctions.setSelectedPets(pets)
    selectedPets = pets
end

function PetFunctions.setIncludedPets(pets)
    includedPets = pets
end

function PetFunctions.setAllPetsSelected(value)
    allPetsSelected = value
end

-- Function to select individual pets
function PetFunctions.selectPet(petId)
    if not selectedPets then
        selectedPets = {}
    end

    selectedPets[petId] = true
    allPetsSelected = false -- Individual selection means not all are selected
end

-- Function to deselect individual pets
function PetFunctions.deselectPet(petId)
    if selectedPets then
        selectedPets[petId] = nil
    end
    allPetsSelected = false
end

-- Function to include pets for middle function
function PetFunctions.includePet(petId)
    if not includedPets then
        includedPets = {}
    end

    includedPets[petId] = true
end

-- Function to remove pets from included list
function PetFunctions.unincludePet(petId)
    if includedPets then
        includedPets[petId] = nil
    end
end

-- Helper functions for managing pet inclusions
function PetFunctions.isPetIncluded(petId)
    local mainIncludedPets = includedPets or {}
    return mainIncludedPets[petId] == true
end

function PetFunctions.getIncludedPetCount()
    local mainIncludedPets = includedPets or {}
    local count = 0
    for _ in pairs(mainIncludedPets) do
        count = count + 1
    end
    return count
end

function PetFunctions.getIncludedPetIds()
    local mainIncludedPets = includedPets or {}
    local ids = {}
    for petId, _ in pairs(mainIncludedPets) do
        table.insert(ids, petId)
    end
    return ids
end

-- Getters and Setters
function PetFunctions.setAutoMiddleEnabled(enabled)
    autoMiddleEnabled = enabled
    if enabled then
        lastZoneAbilityTime = tick() -- Reset timer when enabling
    else
        if notificationConnection then
            notificationConnection:Disconnect()
            notificationConnection = nil
        end
    end
end

function PetFunctions.getAutoMiddleEnabled()
    return autoMiddleEnabled
end

function PetFunctions.setPetDropdown(dropdown)
    petDropdown = dropdown
end

function PetFunctions.getCurrentPetsList()
    return currentPetsList
end

-- Cooldown Timer Getters and Setters
function PetFunctions.getCooldownTimerEnabled()
    return cooldownTimerEnabled
end

function PetFunctions.getCooldownTargetPetId()
    return cooldownTargetPetId
end

function PetFunctions.setCooldownTargetPet(petId)
    cooldownTargetPetId = petId
end

function PetFunctions.getCooldownDuration()
    return cooldownDuration
end

function PetFunctions.setCooldownDuration(duration)
    cooldownDuration = duration
end

-- Legacy functions for compatibility
function PetFunctions.startCooldownTimer(petId, duration)
    PetFunctions.startCooldownMonitoring(petId, duration)
end

function PetFunctions.stopCooldownTimer()
    PetFunctions.stopCooldownMonitoring()
end

function PetFunctions.getRemainingCooldownTime()
    local status = PetFunctions.getTargetPetCooldownStatus()
    return status.timeUntilReady or 0
end

-- Initialize the system with auto refresh
task.spawn(function()
    task.wait(1) -- Wait a moment for everything to load
    PetFunctions.initializeActivePetUI()
    PetFunctions.refreshPets()
end)

PetFunctions.updateDropdownOptions()

-- Make functions available globally if needed
_G.updateDropdownOptions = PetFunctions.updateDropdownOptions
_G.refreshPets = PetFunctions.refreshPets
_G.isPetIncluded = PetFunctions.isPetIncluded
_G.getIncludedPetCount = PetFunctions.getIncludedPetCount
_G.getIncludedPetIds = PetFunctions.getIncludedPetIds
_G.includePet = PetFunctions.includePet
_G.unincludePet = PetFunctions.unincludePet

-- Make cooldown functions available globally
_G.startCooldownMonitoring = PetFunctions.startCooldownMonitoring
_G.stopCooldownMonitoring = PetFunctions.stopCooldownMonitoring
_G.getTargetPetCooldownStatus = PetFunctions.getTargetPetCooldownStatus
_G.getRemainingCooldownTime = PetFunctions.getRemainingCooldownTime

-- Legacy global functions for backward compatibility
_G.startCooldownTimer = PetFunctions.startCooldownTimer
_G.stopCooldownTimer = PetFunctions.stopCooldownTimer

return PetFunctions
