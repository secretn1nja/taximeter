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

    if vehicle ~= 0 and GetEntityModel(vehicle) == GetHashKey(Config.TaxiModel) then
        return true
    else
        return false
    end
end

function toggleDisplay()
    if isPlayerInTaxi() then
        display = not display
        SetNuiFocus(false, false)
        SendNUIMessage({
            type = "ui",
            status = display
        })
    end
end

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

        if isPlayerInTaxi() and IsControlJustPressed(0, Config.Keys.Start) then
            startMeter()
        end

        if isPlayerInTaxi() and IsControlJustPressed(0, Config.Keys.Pause) then
            stopMeter()
        end

        if isPlayerInTaxi() and IsControlJustPressed(0, Config.Keys.Reset) then
            if fare > 0 and distance > 0 then
                addRideToHistory(fare, distance)
            end
            resetMeter()
            isRideRecorded = false
        end

        if IsControlJustPressed(0, Config.Keys.ToggleDisplay) then
            toggleDisplay()
        end

        if IsControlJustPressed(0, Config.Keys.History) then
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
