-- State variables
local display = false
local historyDisplay = false
local isMeterRunning = false
local fare = 0.0
local distance = 0.0
local fareRate = Config.FareRate
local lastPosition = nil
local rideHistory = {}
local isRideRecorded = false

-- Performance cache variables
local playerPed = nil
local currentVehicle = nil
local isInTaxi = false
local isDriver = false
local lastVehicleCheck = 0
local lastRoleUpdate = 0

-- Add ride to history with validation
function addRideToHistory(fare, distance)
    if not fare or not distance or fare <= 0 or distance <= 0 then
        if Config.Debug then
            print("^3[TAXIMETER] ^7Cannot add empty ride to history. Fare: " .. tostring(fare) .. ", Distance: " .. tostring(distance))
        end
        return false
    end
    
    if not isRideRecorded then
        -- Maintain history limit
        if #rideHistory >= Config.MaxRidesHistory then
            table.remove(rideHistory, 1)
        end
        
        -- Add new ride with timestamp
        table.insert(rideHistory, {
            fare = math.floor(fare * 100) / 100, -- Round to 2 decimals
            distance = math.floor(distance * 10) / 10, -- Round to 1 decimal
            timestamp = os.time()
        })
        
        SendNUIMessage({
            type = "updateHistory",
            history = rideHistory
        })
        
        isRideRecorded = true
        return true
    end
    return false
end

-- Check if player is in taxi (optimized with caching)
function isPlayerInTaxi()
    local gameTime = GetGameTimer()
    
    -- Update cache every 500ms instead of every frame
    if gameTime - lastVehicleCheck > 500 then
        lastVehicleCheck = gameTime
        playerPed = PlayerPedId()
        currentVehicle = GetVehiclePedIsIn(playerPed, false)
        
        if currentVehicle ~= 0 then
            local vehicleModel = GetEntityModel(currentVehicle)
            isInTaxi = false
            
            for _, model in ipairs(Config.TaxiModel) do
                if vehicleModel == GetHashKey(model) then
                    isInTaxi = true
                    break
                end
            end
        else
            isInTaxi = false
        end
    end
    
    return isInTaxi and currentVehicle ~= 0
end

-- Toggle display with validation
function toggleDisplay()
    if not isPlayerInTaxi() then
        if Config.Debug then
            print("^3[TAXIMETER] ^7Player must be in a taxi to toggle display")
        end
        return
    end
    
    if not isPlayerTaxiDriver() then
        TriggerEvent('chat:addMessage', { 
            args = { "^3[TAXIMETER]^7 You must be the taxi driver to control the meter display." } 
        })
        return
    end
    
    if currentVehicle ~= 0 then
        local vehicleNetId = NetworkGetNetworkIdFromEntity(currentVehicle)
        TriggerServerEvent('taximeter:toggleDisplayForVehicle', vehicleNetId)
    end
end

-- Update role for player (optimized)
function updateRoleForPlayer()
    local gameTime = GetGameTimer()
    
    -- Update role every 1 second instead of every frame when in taxi
    if gameTime - lastRoleUpdate > 1000 then
        lastRoleUpdate = gameTime
        isDriver = isPlayerTaxiDriver()
        
        SendNUIMessage({
            type = "role",
            isDriver = isDriver
        })
    end
end

-- Optimized role update thread
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000) -- Check every second instead of every frame
        
        if isPlayerInTaxi() then
            updateRoleForPlayer()
        end
    end
end)

-- Toggle history display
function toggleHistoryDisplay()
    historyDisplay = not historyDisplay
    SendNUIMessage({
        type = "historyUI",
        status = historyDisplay
    })
    
    if Config.Debug then
        print("^2[TAXIMETER] ^7History display toggled: " .. tostring(historyDisplay))
    end
end

-- Start meter with improved validation and performance
function startMeter()
    if not isPlayerInTaxi() then
        TriggerEvent('chat:addMessage', {
            args = { "^3[TAXIMETER]^7 You must be in a taxi to start the meter." }
        })
        return false
    end
    
    if isMeterRunning then
        if Config.Debug then
            print("^3[TAXIMETER] ^7Meter is already running")
        end
        return false
    end
    
    isMeterRunning = true
    
    if currentVehicle ~= 0 then
        lastPosition = GetEntityCoords(currentVehicle)
    end
    
    -- Optimized meter calculation thread
    Citizen.CreateThread(function()
        while isMeterRunning do
            if currentVehicle ~= 0 and isPlayerInTaxi() then
                local currentPosition = GetEntityCoords(currentVehicle)
                
                if lastPosition then
                    local dist = #(currentPosition - lastPosition)
                    
                    if dist > 0.1 then -- Only update if significant movement
                        distance = distance + dist
                        fare = distance * Config.FareRate
                        
                        SendNUIMessage({
                            type = "update",
                            fare = fare,
                            distance = distance
                        })
                    end
                end
                lastPosition = currentPosition
            else
                -- Auto-stop if no longer in taxi
                isMeterRunning = false
                break
            end
            
            Citizen.Wait(1000) -- Update every second for better performance
        end
    end)
    
    return true
end

-- Stop meter
function stopMeter()
    if isMeterRunning then
        isMeterRunning = false
        if Config.Debug then
            print("^2[TAXIMETER] ^7Meter stopped")
        end
        return true
    end
    return false
end

-- Reset meter with improved logic
function resetMeter()
    local wasRecorded = false
    
    if fare > 0 and distance > 0 then
        wasRecorded = addRideToHistory(fare, distance)
    end
    
    fare = 0.0
    distance = 0.0
    lastPosition = nil
    isRideRecorded = false
    
    SendNUIMessage({
        type = "update",
        fare = fare,
        distance = distance
    })
    
    if Config.Debug then
        print("^2[TAXIMETER] ^7Meter reset. Ride recorded: " .. tostring(wasRecorded))
    end
    
    return wasRecorded
end

-- Main control thread (optimized)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0) -- Keep this for input responsiveness
        
        -- Only process if player is in taxi and is driver
        if isPlayerInTaxi() and isPlayerTaxiDriver() then
            -- Start meter
            if IsControlJustPressed(0, Config.Keys.Start) then
                if startMeter() then
                    SendNUIMessage({ action = 'setActive', button = 'start' })
                    SendNUIMessage({ action = 'removeActive', button = 'reset' })
                    SendNUIMessage({ action = 'removeActive', button = 'pause' })
                end
            end
            
            -- Pause meter
            if IsControlJustPressed(0, Config.Keys.Pause) then
                if stopMeter() then
                    SendNUIMessage({ action = 'setActive', button = 'pause' })
                    SendNUIMessage({ action = 'removeActive', button = 'start' })
                end
            end
            
            -- Reset meter
            if IsControlJustPressed(0, Config.Keys.Reset) then
                if fare > 0 and distance > 0 then
                    addRideToHistory(fare, distance)
                end
                
                if Config.PauseOnReset then
                    stopMeter()
                    SendNUIMessage({ action = 'setActive', button = 'pause' })
                else
                    SendNUIMessage({ action = 'removeActive', button = 'pause' })
                    startMeter()
                end
                
                resetMeter()
                SendNUIMessage({ action = 'removeActive', button = 'start' })
                SendNUIMessage({ action = 'setActive', button = 'reset' })
            end
        end
        
        -- Toggle display (available to all players in taxi)
        if IsControlJustPressed(0, Config.Keys.ToggleDisplay) then
            toggleDisplay()
        end
        
        -- History toggle (only for drivers)
        if isPlayerTaxiDriver() and IsControlJustPressed(0, Config.Keys.History) then
            toggleHistoryDisplay()
        end
    end
end)

-- Auto-hide UI when not in taxi (optimized)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5000) -- Check every 5 seconds instead of 2.5 seconds
        
        if not isPlayerInTaxi() and display then
            display = false
            SetNuiFocus(false, false)
            SendNUIMessage({
                type = "ui",
                status = display
            })
            
            if Config.Debug then
                print("^3[TAXIMETER] ^7Auto-hiding UI - player not in taxi")
            end
        end
    end
end)

RegisterNetEvent('taximeter:toggleDisplay')
AddEventHandler('taximeter:toggleDisplay', function(toggle, isDriver)
    display = toggle
    SetNuiFocus(false, false)
    SendNUIMessage({
        type = "ui",
        status = display
    })
    SendNUIMessage({
        type = "role",
        isDriver = isDriver
    })
end)

RegisterNetEvent('taximeter:requestPassengers')
AddEventHandler('taximeter:requestPassengers', function(vehicleNetId, displayState)
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    local passengers = {}

    if vehicle ~= 0 then
        for seat = -1, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
            local ped = GetPedInVehicleSeat(vehicle, seat)
            if ped ~= 0 then
                local playerId = NetworkGetPlayerIndexFromPed(ped)
                if playerId ~= -1 then
                    local serverId = GetPlayerServerId(playerId)
                    table.insert(passengers, serverId)
                end
            end
        end

        TriggerServerEvent('taximeter:reportPassengers', vehicleNetId, passengers, displayState)
    end
end)

RegisterNetEvent('taximeter:updateData')
AddEventHandler('taximeter:updateData', function(newFare, newDistance)
    fare = newFare
    distance = newDistance

    if display then
        SendNUIMessage({
            type = "update",
            fare = fare,
            distance = distance
        })
    end
end)

-- Check if player is taxi driver (optimized)
function isPlayerTaxiDriver()
    if not isPlayerInTaxi() or currentVehicle == 0 then
        return false
    end
    
    -- Check if player is in driver seat (-1)
    return GetPedInVehicleSeat(currentVehicle, -1) == playerPed
end

-- Optimized meter data update thread
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(2000) -- Update every 2 seconds instead of 1 second
        
        if isPlayerTaxiDriver() and display and currentVehicle ~= 0 then
            local vehicleNetId = NetworkGetNetworkIdFromEntity(currentVehicle)
            local passengerCount = 0
            
            -- Count passengers more efficiently
            for seat = 0, GetVehicleMaxNumberOfPassengers(currentVehicle) - 1 do
                if not IsVehicleSeatFree(currentVehicle, seat) then
                    passengerCount = passengerCount + 1
                end
            end
            
            TriggerServerEvent('taximeter:updateMeterData', vehicleNetId, fare, distance, passengerCount)
        end
    end
end)
