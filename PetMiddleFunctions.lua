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
local LOOP_DELAY = 3
local INITIAL_LOOP_TIME = 5
local ZONE_ABILITY_DELAY = 5
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

-- Universal Cooldown Variables
local universalCooldownEnabled = false
local universalCooldownConnection = nil
local cooldownDuration = 80 -- Default 80 seconds (1:20)

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

-- Function to check if cooldown timer should block middle function (Universal)
function PetFunctions.shouldBlockMiddleFunction()
    if not universalCooldownEnabled then
        return false -- Universal monitoring disabled, don't block
    end
    
    -- Get all included pets
    local includedPetIds = PetFunctions.getIncludedPetIds()
    
    if #includedPetIds == 0 and not allPetsSelected then
        return false -- No pets to monitor
    end
    
    local petsToCheck = {}
    if allPetsSelected then
        -- Check all pets
        local allPets = PetFunctions.getAllPets()
        for _, pet in pairs(allPets) do
            table.insert(petsToCheck, pet.id)
        end
    else
        -- Check only included pets
        petsToCheck = includedPetIds
    end
    
    -- Check each pet's cooldown
    for _, petId in pairs(petsToCheck) do
        local actualCooldown = PetFunctions.getPetCooldown(petId)
        
        if actualCooldown and actualCooldown > cooldownDuration then
            -- At least one pet has cooldown above threshold, block middle function
            return true
        end
    end
    
    -- All pets have cooldown at or below threshold, allow middle function
    return false
end

-- Function to get remaining cooldown time (now shows worst case)
function PetFunctions.getRemainingCooldownTime()
    if not universalCooldownEnabled then
        return 0
    end
    
    local status, allReady = PetFunctions.getUniversalCooldownStatus()
    
    if type(status) ~= "table" or allReady then
        return 0
    end
    
    -- Return the longest time until any pet is ready
    local maxTimeLeft = 0
    for _, pet in pairs(status) do
        if pet.timeLeft > maxTimeLeft then
            maxTimeLeft = pet.timeLeft
        end
    end
    
    return maxTimeLeft
end

-- Function to format time for display (MM:SS)
function PetFunctions.formatTime(seconds)
    local minutes = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%02d:%02d", minutes, secs)
end

-- Function to get status of all monitored pets
function PetFunctions.getUniversalCooldownStatus()
    if not universalCooldownEnabled then
        return "Universal monitoring disabled"
    end
    
    local includedPetIds = PetFunctions.getIncludedPetIds()
    local petsToCheck = {}
    
    if allPetsSelected then
        local allPets = PetFunctions.getAllPets()
        for _, pet in pairs(allPets) do
            table.insert(petsToCheck, {id = pet.id, name = pet.name})
        end
    else
        local allPets = PetFunctions.getAllPets()
        for _, pet in pairs(allPets) do
            if PetFunctions.isPetIncluded(pet.id) then
                table.insert(petsToCheck, {id = pet.id, name = pet.name})
            end
        end
    end
    
    local status = {}
    local allReady = true
    
    for _, pet in pairs(petsToCheck) do
        local actualCooldown = PetFunctions.getPetCooldown(pet.id) or 0
        local isReady = actualCooldown <= cooldownDuration
        
        table.insert(status, {
            name = pet.name,
            id = pet.id,
            cooldown = actualCooldown,
            ready = isReady,
            timeLeft = math.max(0, actualCooldown - cooldownDuration)
        })
        
        if not isReady then
            allReady = false
        end
    end
    
    return status, allReady
end

-- Function to start universal cooldown monitoring
function PetFunctions.startUniversalCooldownMonitoring(thresholdDuration)
    -- Stop any existing monitoring
    PetFunctions.stopUniversalCooldownMonitoring()
    
    cooldownDuration = thresholdDuration or 80
    universalCooldownEnabled = true
    
    print("Started universal cooldown monitoring for all included pets")
    print("Threshold: " .. PetFunctions.formatTime(cooldownDuration))
    
    -- Set up monitoring connection
    universalCooldownConnection = RunService.Heartbeat:Connect(function()
        if not universalCooldownEnabled then
            return
        end
        
        -- Optional: Log status every few seconds
        -- You can uncomment this for debugging
        --[[
        local status, allReady = PetFunctions.getUniversalCooldownStatus()
        if type(status) == "table" then
            local readyCount = 0
            for _, pet in pairs(status) do
                if pet.ready then readyCount = readyCount + 1 end
            end
            print("Pets ready: " .. readyCount .. "/" .. #status .. " | Middle function: " .. (allReady and "ACTIVE" or "BLOCKED"))
        end
        ]]--
    end)
end

-- Function to stop universal cooldown monitoring
function PetFunctions.stopUniversalCooldownMonitoring()
    universalCooldownEnabled = false
    
    if universalCooldownConnection then
        universalCooldownConnection:Disconnect()
        universalCooldownConnection = nil
    end
    
    print("Stopped universal cooldown monitoring")
end

-- Legacy functions for compatibility (now redirect to universal system)
function PetFunctions.startCooldownTimer(petId, thresholdDuration)
    -- Redirect to universal system
    PetFunctions.startUniversalCooldownMonitoring(thresholdDuration)
end

function PetFunctions.stopCooldownTimer()
    -- Redirect to universal system
    PetFunctions.stopUniversalCooldownMonitoring()
end

-- Function to run the auto middle loop (modified to respect cooldown timer)
function PetFunctions.runAutoMiddleLoop()
    if not autoMiddleEnabled then return end
    
    -- Check if cooldown timer should block the middle function
    if PetFunctions.shouldBlockMiddleFunction() then
        return
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
    
    -- If universal cooldown is enabled, start monitoring
    if universalCooldownEnabled and cooldownDuration > 0 then
        PetFunctions.startUniversalCooldownMonitoring(cooldownDuration)
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
    PetFunctions.stopUniversalCooldownMonitoring()

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

-- Function to get pets available for cooldown timer (only included pets)
function PetFunctions.getCooldownTimerPets()
    local pets = PetFunctions.getAllPets()
    local availablePets = {"None"}
    local petMap = {}
    
    for _, pet in pairs(pets) do
        -- Only include pets that are in the middle function
        if PetFunctions.isPetIncluded(pet.id) or allPetsSelected then
            local displayName = pet.name .. " (" .. string.sub(pet.id, 2, 9) .. "...)"
            table.insert(availablePets, displayName)
            petMap[displayName] = pet.id
        end
    end
    
    return availablePets, petMap
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

-- Universal Cooldown Getters and Setters
function PetFunctions.getUniversalCooldownEnabled()
    return universalCooldownEnabled
end

function PetFunctions.getCooldownDuration()
    return cooldownDuration
end

function PetFunctions.setCooldownDuration(duration)
    cooldownDuration = duration
end

-- Legacy compatibility functions (deprecated but maintained for backward compatibility)
function PetFunctions.getCooldownTimerEnabled()
    return universalCooldownEnabled
end

function PetFunctions.getCooldownTargetPetId()
    -- Return nil since universal monitoring doesn't target specific pets
    return nil
end

function PetFunctions.setCooldownTargetPet(petId)
    -- This function is now deprecated with universal monitoring
    warn("setCooldownTargetPet is deprecated. Use universal cooldown monitoring instead.")
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

-- Make universal cooldown functions available globally
_G.startUniversalCooldownMonitoring = PetFunctions.startUniversalCooldownMonitoring
_G.stopUniversalCooldownMonitoring = PetFunctions.stopUniversalCooldownMonitoring
_G.getUniversalCooldownStatus = PetFunctions.getUniversalCooldownStatus
_G.getRemainingCooldownTime = PetFunctions.getRemainingCooldownTime
_G.getCooldownTimerPets = PetFunctions.getCooldownTimerPets

-- Legacy global functions for backward compatibility
_G.startCooldownTimer = PetFunctions.startCooldownTimer
_G.stopCooldownTimer = PetFunctions.stopCooldownTimer

return PetFunctions
