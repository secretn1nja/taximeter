local vehicleDisplayStates = {}
local vehicleMeterData = {}

RegisterNetEvent('taximeter:toggleDisplayForVehicle')
AddEventHandler('taximeter:toggleDisplayForVehicle', function(vehicleNetId)
    local src = source
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)

    if vehicle ~= 0 then
        if not vehicleDisplayStates[vehicleNetId] then
            vehicleDisplayStates[vehicleNetId] = false
            vehicleMeterData[vehicleNetId] = { fare = 0.0, distance = 0.0 }
        end

        local newDisplayState = not vehicleDisplayStates[vehicleNetId]
        vehicleDisplayStates[vehicleNetId] = newDisplayState

        TriggerClientEvent('taximeter:requestPassengers', src, vehicleNetId, newDisplayState)
    else
        print("Invalid vehicle for NetID:", vehicleNetId)
    end
end)

RegisterNetEvent('taximeter:reportPassengers')
AddEventHandler('taximeter:reportPassengers', function(vehicleNetId, passengers, displayState)
    for _, passengerId in ipairs(passengers) do
        TriggerClientEvent('taximeter:toggleDisplay', passengerId, displayState)
    end
end)

RegisterNetEvent('taximeter:updateMeterData')
AddEventHandler('taximeter:updateMeterData', function(vehicleNetId, fare, distance, passengerCount)
    if vehicleNetId then
        local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
        if vehicle and vehicle ~= 0 then
            for seat = -1, 4 do
                local ped = GetPedInVehicleSeat(vehicle, seat)
                if ped and ped ~= 0 then
                    local playerId = NetworkGetEntityOwner(ped)
                    if playerId then
                        TriggerClientEvent('taximeter:updateData', playerId, fare, distance, passengerCount)
                    end
                end
            end
        end
    else
        print("Invalid vehicle NetID for meter data update:", vehicleNetId)
    end
end)

local function GetPlayerFromPed(ped)
    for i = 0, GetNumPlayerIndices() - 1 do
        local player = GetPlayerFromIndex(i)
        if GetPlayerPed(player) == ped then
            return player
        end
    end
    return nil
end
