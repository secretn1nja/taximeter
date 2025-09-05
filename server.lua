-- Server-side state management
local vehicleDisplayStates = {}
local vehicleMeterData = {}

-- Utility function to validate vehicle network ID
local function isValidVehicleNetId(vehicleNetId)
    if not vehicleNetId or vehicleNetId == 0 then
        return false
    end
    
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    return vehicle and vehicle ~= 0 and DoesEntityExist(vehicle)
end

-- Clean up old vehicle data periodically
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(300000) -- Clean every 5 minutes
        
        local currentTime = os.time()
        local toRemove = {}
        
        for netId, data in pairs(vehicleMeterData) do
            if not isValidVehicleNetId(netId) or (data.lastUpdate and currentTime - data.lastUpdate > 600) then
                table.insert(toRemove, netId)
            end
        end
        
        for _, netId in ipairs(toRemove) do
            vehicleDisplayStates[netId] = nil
            vehicleMeterData[netId] = nil
            if Config.Debug then
                print("^3[TAXIMETER SERVER] ^7Cleaned up data for vehicle NetID: " .. netId)
            end
        end
    end
end)

-- Toggle display for vehicle with improved validation
RegisterNetEvent('taximeter:toggleDisplayForVehicle')
AddEventHandler('taximeter:toggleDisplayForVehicle', function(vehicleNetId)
    local src = source
    
    if not vehicleNetId or not isValidVehicleNetId(vehicleNetId) then
        if Config.Debug then
            print("^1[TAXIMETER SERVER] ^7Invalid vehicle NetID from player " .. src .. ": " .. tostring(vehicleNetId))
        end
        return
    end
    
    -- Initialize vehicle data if needed
    if not vehicleDisplayStates[vehicleNetId] then
        vehicleDisplayStates[vehicleNetId] = false
        vehicleMeterData[vehicleNetId] = { 
            fare = 0.0, 
            distance = 0.0, 
            lastUpdate = os.time()
        }
    end
    
    -- Toggle display state
    local newDisplayState = not vehicleDisplayStates[vehicleNetId]
    vehicleDisplayStates[vehicleNetId] = newDisplayState
    
    if Config.Debug then
        print("^2[TAXIMETER SERVER] ^7Display toggled for vehicle " .. vehicleNetId .. ": " .. tostring(newDisplayState))
    end
    
    TriggerClientEvent('taximeter:requestPassengers', src, vehicleNetId, newDisplayState)
end)

-- Report passengers with validation
RegisterNetEvent('taximeter:reportPassengers')
AddEventHandler('taximeter:reportPassengers', function(vehicleNetId, passengers, displayState)
    local src = source
    
    if not vehicleNetId or not isValidVehicleNetId(vehicleNetId) then
        if Config.Debug then
            print("^1[TAXIMETER SERVER] ^7Invalid vehicle NetID in reportPassengers: " .. tostring(vehicleNetId))
        end
        return
    end
    
    if not passengers or type(passengers) ~= "table" then
        if Config.Debug then
            print("^1[TAXIMETER SERVER] ^7Invalid passengers data from player " .. src)
        end
        return
    end
    
    -- Determine if player is driver
    local isDriver = false
    for _, passengerId in ipairs(passengers) do
        if passengerId == src then
            isDriver = true
            break
        end
    end
    
    -- Send display update to all passengers
    for _, passengerId in ipairs(passengers) do
        if GetPlayerPing(passengerId) > 0 then -- Check if player is still connected
            TriggerClientEvent('taximeter:toggleDisplay', passengerId, displayState, passengerId == src)
        end
    end
    
    if Config.Debug then
        print("^2[TAXIMETER SERVER] ^7Updated display for " .. #passengers .. " passengers in vehicle " .. vehicleNetId)
    end
end)

-- Update meter data with improved validation and performance
RegisterNetEvent('taximeter:updateMeterData')
AddEventHandler('taximeter:updateMeterData', function(vehicleNetId, fare, distance, passengerCount)
    local src = source
    
    if not vehicleNetId or not isValidVehicleNetId(vehicleNetId) then
        if Config.Debug then
            print("^1[TAXIMETER SERVER] ^7Invalid vehicle NetID in updateMeterData: " .. tostring(vehicleNetId))
        end
        return
    end
    
    -- Validate data
    if not fare or not distance or type(fare) ~= "number" or type(distance) ~= "number" then
        if Config.Debug then
            print("^1[TAXIMETER SERVER] ^7Invalid meter data from player " .. src)
        end
        return
    end
    
    -- Update meter data with timestamp
    vehicleMeterData[vehicleNetId] = {
        fare = fare,
        distance = distance,
        passengerCount = passengerCount or 0,
        lastUpdate = os.time()
    }
    
    -- Get all players in the vehicle and update their displays
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if vehicle and DoesEntityExist(vehicle) then
        local playersInVehicle = {}
        
        -- Check all seats for players
        for seat = -1, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
            local ped = GetPedInVehicleSeat(vehicle, seat)
            if ped and ped ~= 0 then
                local playerId = NetworkGetEntityOwner(ped)
                if playerId and GetPlayerPing(playerId) > 0 then
                    table.insert(playersInVehicle, playerId)
                end
            end
        end
        
        -- Update all players in vehicle
        for _, playerId in ipairs(playersInVehicle) do
            TriggerClientEvent('taximeter:updateData', playerId, fare, distance, passengerCount)
        end
        
        if Config.Debug and #playersInVehicle > 0 then
            print("^2[TAXIMETER SERVER] ^7Updated meter data for " .. #playersInVehicle .. " players in vehicle " .. vehicleNetId)
        end
    end
end)

-- Utility function to get player from ped (improved performance)
local function GetPlayerFromPed(ped)
    local players = GetPlayers()
    for _, playerId in ipairs(players) do
        if GetPlayerPed(playerId) == ped then
            return playerId
        end
    end
    return nil
end

-- Event handlers for player disconnection cleanup
AddEventHandler('playerDropped', function(reason)
    local src = source
    if Config.Debug then
        print("^3[TAXIMETER SERVER] ^7Player " .. src .. " disconnected, cleaning up vehicle states")
    end
    
    -- Clean up any vehicle states associated with this player
    -- This is handled automatically by the periodic cleanup thread
end)
