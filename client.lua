local display = false
local historyDisplay = false
local isMeterRunning = false
local fare = 0.0
local distance = 0.0
local fareRate = Config.FareRate
local lastPosition = nil
local rideHistory = {}
local isRideRecorded = false

function addRideToHistory(fare, distance)
    if fare > 0 and distance > 0 then
        if not isRideRecorded then
            if #rideHistory >= Config.MaxRidesHistory then
                table.remove(rideHistory, 1)
            end
            table.insert(rideHistory, {
                fare = fare,
                distance = distance,
            })
            SendNUIMessage({
                type = "updateHistory",
                history = rideHistory
            })

            isRideRecorded = true
        end
    else
        TriggerEvent('chat:addMessage', {
            args = { "Cannot add empty ride to history. Ensure distance and fare are non-zero." }
        })
    end
end

function isPlayerInTaxi()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    for _, model in ipairs(Config.TaxiModel) do
        if vehicle ~= 0 and GetEntityModel(vehicle) == GetHashKey(model) then
            return true
        end
    end
    return false
end

function toggleDisplay()
    if isPlayerInTaxi() and isPlayerTaxiDriver() then
        local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
        if vehicle ~= 0 then
            local vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)
            TriggerServerEvent('taximeter:toggleDisplayForVehicle', vehicleNetId)
        end
    else
        TriggerEvent('chat:addMessage', { args = { "You must be the taxi driver to control the meter display." } })
    end
end

function updateRoleForPlayer()
    local isDriver = isPlayerTaxiDriver()
    SendNUIMessage({
        type = "role",
        isDriver = isDriver
    })
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        if isPlayerInTaxi() then
            updateRoleForPlayer()
        end
    end
end)

function toggleHistoryDisplay()
    historyDisplay = not historyDisplay
    SendNUIMessage({
        type = "historyUI",
        status = historyDisplay
    })
end

function startMeter()
    if isPlayerInTaxi() then
        if not isMeterRunning then
            isMeterRunning = true
            local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)

            if vehicle ~= 0 then
                lastPosition = GetEntityCoords(vehicle)
            end

            Citizen.CreateThread(function()
                while isMeterRunning do
                    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
                    if vehicle ~= 0 then
                        local currentPosition = GetEntityCoords(vehicle)

                        if lastPosition then
                            local dist = Vdist(currentPosition.x, currentPosition.y, currentPosition.z, lastPosition.x,
                                lastPosition.y, lastPosition.z)

                            distance = distance + dist
                            fare = distance * Config.FareRate
                            SendNUIMessage({
                                type = "update",
                                fare = fare,
                                distance = distance
                            })
                        end
                        lastPosition = currentPosition
                    end

                    Citizen.Wait(1000)
                end
            end)
        end
    else
        TriggerEvent('chat:addMessage', {
            args = { "You must be in a taxi to start the meter." }
        })
    end
end

function stopMeter()
    isMeterRunning = false
end

function resetMeter()
    if fare > 0 and distance > 0 then
        addRideToHistory(fare, distance)
    end
    fare = 0.0
    distance = 0.0
    lastPosition = nil
    SendNUIMessage({
        type = "update",
        fare = fare,
        distance = distance
    })
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        if isPlayerInTaxi() and isPlayerTaxiDriver() and IsControlJustPressed(0, Config.Keys.Start) then
            startMeter()
            SendNUIMessage({ action = 'setActive', button = 'start' })
            SendNUIMessage({ action = 'removeActive', button = 'reset' })

            SendNUIMessage({ action = 'removeActive', button = 'pause' })
        end

        if isPlayerInTaxi() and isPlayerTaxiDriver() and IsControlJustPressed(0, Config.Keys.Pause) then
            stopMeter()
            SendNUIMessage({ action = 'setActive', button = 'pause' })
            SendNUIMessage({ action = 'removeActive', button = 'start' })
        end

        if isPlayerInTaxi() and isPlayerTaxiDriver() and IsControlJustPressed(0, Config.Keys.Reset) then
            if fare > 0 and distance > 0 then
                addRideToHistory(fare, distance)
            end

            if Config.PauseOnReset == true then
                stopMeter()
                SendNUIMessage({ action = 'setActive', button = 'pause' })
            elseif Config.PauseOnReset == false then
                SendNUIMessage({ action = 'removeActive', button = 'pause' })
                startMeter()
            end
            resetMeter()
            isRideRecorded = false
            SendNUIMessage({ action = 'removeActive', button = 'start' })
            SendNUIMessage({ action = 'setActive', button = 'reset' })
        end

        if IsControlJustPressed(0, Config.Keys.ToggleDisplay) then
            toggleDisplay()
        end

        if isPlayerTaxiDriver() and IsControlJustPressed(0, Config.Keys.History) then
            toggleHistoryDisplay()
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(2500)
        if not isPlayerInTaxi() and display then
            display = false
            SetNuiFocus(false, false)
            SendNUIMessage({
                type = "ui",
                status = display
            })
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

function isPlayerTaxiDriver()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    local seat = -1

    if GetPedInVehicleSeat(vehicle, seat) == ped then
        for _, model in ipairs(Config.TaxiModel) do
            if GetEntityModel(vehicle) == GetHashKey(model) then
                return true
            end
        end
    end
    return false
end

function updateMeterData()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if vehicle ~= 0 and isPlayerTaxiDriver() then
        local vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)
        local passengerCount = 0

        for seat = 0, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
            if not IsVehicleSeatFree(vehicle, seat) then
                passengerCount = passengerCount + 1
            end
        end

        TriggerServerEvent('taximeter:updateMeterData', vehicleNetId, fare, distance, passengerCount)
    end
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        if isPlayerTaxiDriver() and display then
            updateMeterData()
        end
    end
end)
