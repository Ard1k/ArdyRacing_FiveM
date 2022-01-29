RunningEvents = {}
EventIdCounter = 1000
EventIdLock = false

math.randomseed(os.time())
math.random(); math.random(); math.random()
AdminKey = math.random(10000, 99999)

function GetNextEventIdSafe()
    while EventIdLock == true do
        Citizen.Wait(0)
    end

    EventIdLock = true

    EventIdCounter = EventIdCounter + 1
    local newId = EventIdCounter

    EventIdLock = false

    return newId
end

function ProcessLeaderboard(event, playerData, sourceCopy, startVehicle, finisVehicle)
    Citizen.CreateThread(function() 
        local evt = event
        local pdat = playerData
        local src = sourceCopy

        if (evt == nil) then
            print('Aracing - ProcessLeaderboard - missing event data')
            return
        end

        if evt.IsRanked ~= true then
            return
        end

        if (startVehicle == nil or startVehicle.Hash == nil) then
            print('Aracing - ProcessLeaderboard - missing start vehicle data')
            return
        end

        if (finisVehicle == nil or finisVehicle.Hash == nil) then
            print('Aracing - ProcessLeaderboard - missing finish vehicle data')
            return
        end

        if startVehicle.Hash ~= finisVehicle.Hash then
            NotifyPlayerError(src, 'Leaderboard skipped. Car model changed during race!')
            return
        end

        local record = 
        {
            AuthorName = playerData.Name,
            CarHash = pdat.VehicleData.Hash
        }

        if evt.Type == RACETYPE_SPRINT or evt.Type == RACETYPE_CIRCUIT then
            record.Record = pdat.TotalTime
        elseif evt.Type == RACETYPE_DRIFT then
            record.Record = pdat.DriftScore
        elseif evt.Type == RACETYPE_DRIFTCIRCUIT then
            record.Record = pdat.BestLapDrift
        else
            print('Aracing - ProcessLeaderboard - unknown race type')
            return
        end

        local result = GetLeaderboardPosition(evt.Name, evt.Type, record)

        if (evt.IsVerified) then
            if result.Overall > 0 then
                TriggerClientEvent("ardy_racing:NewRecordSet", -1, src, true, result.Overall, evt.Name, evt.Type, record.CarHash, record.Record, record.AuthorName)
            end
            if result.Car > 0 and Config.enable_car_specific_leaderboard_notif == true then
                TriggerClientEvent("ardy_racing:NewRecordSet", -1, src, false, result.Car, evt.Name, evt.Type, record.CarHash, record.Record, record.AuthorName)
            end
        end
    end)
end

RegisterNetEvent("ardy_racing:SaveRace")
AddEventHandler("ardy_racing:SaveRace", function(race)
    local src = source
    if race == nil then
        NotifyPlayerError(src, 'Race data invalid')
        return
    end

    if race.Checkpoints == nil or #race.Checkpoints <= 0 then
        NotifyPlayerError(src, 'Race must have at least 2 checkpoints')
        return
    end

    if race.Name == nil or race.Name == '' then
        NotifyPlayerError(src, 'Race must have name')
        return
    end

    for _, checkpoint in pairs(race.Checkpoints) do
        checkpoint.blip = nil
        checkpoint.coords = {x = checkpoint.coords.x, y = checkpoint.coords.y, z = checkpoint.coords.z}
    end

    while DataLocked == true do
        Citizen.Wait(0)
    end

    DataLocked = true

    if DoesRaceWithNameExist(race.Name) then
        DataLocked = false
        NotifyPlayerError(src, 'Race with this name already exist')
        return
    end

    race.AuthorUID = GetPlayerUID(src)
    race.AuthorName = GetPlayerAuthorName(src)

    AddRace(race)
    DataLocked = false

    NotifyPlayerSuccess(src, 'Race saved!')
    TriggerClientEvent('ardy_racing:RaceSaved', src)
end)

RegisterNetEvent("ardy_racing:AdminLogin")
AddEventHandler("ardy_racing:AdminLogin", function(pass)
    local src = source
    if pass ~= AdminPassword then
        NotifyPlayerError(src, 'Invalid password')
        return
    end

    TriggerClientEvent('ardy_racing:AdminLoginSuccess', src, AdminKey)
end)

RegisterNetEvent("ardy_racing:Admin_clearHashFromLeaderboards")
AddEventHandler("ardy_racing:Admin_clearHashFromLeaderboards", function(admKey, hash)
    local src = source
    if admKey ~= AdminKey then
        NotifyPlayerError(src, 'Unauthorized')
        return
    end

    RemoveVehicleHashFromLeaderboards(hash)
    NotifyPlayerSuccess(src, tostring(hash) .. ' removed from leaderboards')
end)

RegisterNetEvent("ardy_racing:Admin_renameRace")
AddEventHandler("ardy_racing:Admin_renameRace", function(admKey, oldName, newName)
    local src = source
    if admKey ~= AdminKey then
        NotifyPlayerError(src, 'Unauthorized')
        return
    end

    if DoesRaceWithNameExist(newName) then
        NotifyPlayerError(src, 'Race with this name already exist')
        return
    end

    RenameRace(oldName, newName)
    NotifyPlayerSuccess(src, 'Race renamed from: ' .. oldName .. 'To: ' .. newName)
    TriggerClientEvent("ardy_racing:RaceRenamed", -1, oldName, newName)
end)

RegisterNetEvent("ardy_racing:VerifyRace")
AddEventHandler("ardy_racing:VerifyRace", function(isVerified, race, admKey)
    local src = source
    if admKey ~= AdminKey then
        NotifyPlayerError(src, 'Unauthorized')
        return
    end

    if race == nil then
        NotifyPlayerError(src, 'Invalid data')
        return
    end

    local ret = SetRaceVerified(race.Name, isVerified)

    if ret == false then
        NotifyPlayerError(src, 'Unable to verify')
        return
    end

    TriggerClientEvent('ardy_racing:RaceVerificationSet', src, race.Name, isVerified)
end)

RegisterNetEvent("ardy_racing:SetRaceUnlisted")
AddEventHandler("ardy_racing:SetRaceUnlisted", function(isUnlisted, race)
    local src = source

    if race == nil then
        NotifyPlayerError(src, 'Invalid data')
        return
    end

    local ret = SetRaceUnlisted(race.Name, isUnlisted)

    if ret == false then
        NotifyPlayerError(src, 'Unable to set unlisted status')
        return
    end

    TriggerClientEvent('ardy_racing:RaceUnlistedSet', src, race.Name, isUnlisted)
end)

RegisterNetEvent("ardy_racing:DeleteRace")
AddEventHandler("ardy_racing:DeleteRace", function(race)
    local src = source
    if race == nil then
        NotifyPlayerError(src, 'Race data invalid')
        return
    end

    while DataLocked == true do
        Citizen.Wait(0)
    end

    DataLocked = true

    local serverRace = GetRaceByName(race.Name)

    if serverRace == nil then
        DataLocked = false
        NotifyPlayerError(src, 'Race with this name does not exist')
        return
    end

    if serverRace.AuthorUID ~= GetPlayerUID(src) then
        DataLocked = false
        NotifyPlayerError(src, 'You are not author of this race')
        return
    end

    if serverRace.IsVerified == true then
        DataLocked = false
        NotifyPlayerError(src, 'You can not delete verified race')
        return
    end

    DeleteRace(race)
    DataLocked = false

    NotifyPlayerSuccess(src, 'Race deleted!')
    TriggerClientEvent('ardy_racing:RaceDeleted', src)

    DeleteLeaderboards(race.Name)
end)

RegisterNetEvent("ardy_racing:CreateEvent")
AddEventHandler("ardy_racing:CreateEvent", function(race)
    local src = source
    if race == nil then
        NotifyPlayerError(src, 'Event data invalid')
        return
    end

    if race.Checkpoints == nil or #race.Checkpoints < 2 then
        NotifyPlayerError(src, 'Not enough checkpoints')
        return
    end

    for _, checkpoint in pairs(race.Checkpoints) do
        checkpoint.blip = nil
        checkpoint.coords = {x = checkpoint.coords.x, y = checkpoint.coords.y, z = checkpoint.coords.z}
    end

    race.StartTime = GetGameTimer() + (race.StartIn * 1000)
    race.EventUID = GetNextEventIdSafe()
    race.EventCreatorServerId = src
    race.Players = {}

    table.insert(RunningEvents, race)

    TriggerClientEvent('ardy_racing:NewRaceEvent', -1, race)

    TriggerClientEvent('ardy_racing:OpenCreatedEvent', src, race)
    NotifyPlayerSuccess(src, 'Event created!')
end)

RegisterNetEvent("ardy_racing:JoinEvent")
AddEventHandler("ardy_racing:JoinEvent", function(race)
    local src = source
    if race == nil then
        NotifyPlayerError(src, 'Event data invalid')
        return
    end

    local foundEvent = nil

    for _, event in pairs(RunningEvents) do
        if event.EventUID == race.EventUID then
            foundEvent = event
            break
        end
    end

    if foundEvent == nil then
        NotifyPlayerError(src, 'Event is no longer available')
        return
    end

    for _, player in pairs(foundEvent.Players) do
        if player.Id == src then
            NotifyPlayerError(src, 'You are already joined in this race')
            return
        end
    end

    local playerObj = {
        Id = src, 
        Name = GetPlayerAuthorName(src),
        LastBeat = foundEvent.StartTime,
        Position = 1,
        CurrentCheckpoint = 0,
        CurrentLap = 0,
        CheckpointTimestamp = 0,
        DriftScore = 0,
        BestLapDrift = 0,
        CheckpointProximity = 0
    }

    table.insert(foundEvent.Players, playerObj)

    TriggerClientEvent('ardy_racing:PlayerJoinedEvent', -1, foundEvent.EventUID, playerObj)
end)

RegisterNetEvent("ardy_racing:RegisterEventPlayerVehicle")
AddEventHandler("ardy_racing:RegisterEventPlayerVehicle", function(eventUID, vehicleData)
    local src = source
    if vehicleData == nil then
        NotifyPlayerError(src, 'VehicleData data invalid')
        return
    end

    local foundEvent = nil

    for _, event in pairs(RunningEvents) do
        if event.EventUID == eventUID then
            foundEvent = event
            break
        end
    end

    if foundEvent == nil then
        NotifyPlayerError(src, 'Event not found')
        return
    end

    local foundPlayer = nil
    for _, player in pairs(foundEvent.Players) do
        if player.Id == src then
            foundPlayer = player
        end
    end

    if foundPlayer ~= nil then
        foundPlayer.VehicleData = vehicleData
    end
end)

RegisterNetEvent("ardy_racing:LeaveEvent")
AddEventHandler("ardy_racing:LeaveEvent", function(race, reason)
    local src = source
    if race == nil then
        NotifyPlayerError(src, 'Event data invalid')
        return
    end

    local foundEvent = nil

    for _, event in pairs(RunningEvents) do
        if event.EventUID == race.EventUID then
            foundEvent = event
            break
        end
    end

    if foundEvent ~= nil then
        for index, player in pairs(foundEvent.Players) do
            if player.Id == src then
                local currentTime = GetGameTimer()
                local raceTime = (currentTime - foundEvent.StartTime)
                if raceTime > 0 then
                    player.DNF = true
                    player.HadFinished = true

                    local disqReason = 'You left'
                    if reason ~= nil then
                        disqReason = reason
                    end
                    TriggerClientEvent("ardy_racing:PlayerDisqualified", -1, foundEvent.EventUID, src, disqReason)
                else
                    table.remove(foundEvent.Players, index)
                    TriggerClientEvent('ardy_racing:PlayerLeftEvent', -1, foundEvent.EventUID, src, reason)
                end
                break
            end
        end
        
    end
end)

RegisterNetEvent("ardy_racing:GetMyRaces")
AddEventHandler("ardy_racing:GetMyRaces", function()
    local src = source
    local races = GetRacesByAuthorUID(GetPlayerUID(src))

    if races == nil or #races <= 0 then
        NotifyPlayerError(src, 'No races found')
        return
    end

    TriggerClientEvent('ardy_racing:ListRaces', src, races, 'Your races')
end)

RegisterNetEvent("ardy_racing:GetRaceLeaderboards")
AddEventHandler("ardy_racing:GetRaceLeaderboards", function(race)
    if race == nil then
        NotifyPlayerError(src, 'Invalid race data')
        return
    end

    local src = source
    local lb = GetRaceLeaderboards(race.Name, race.Type)

    TriggerClientEvent('ardy_racing:OpenRaceLeaderboards', src, race.Name, race.Type, lb)
end)

RegisterNetEvent("ardy_racing:GetAllRaces")
AddEventHandler("ardy_racing:GetAllRaces", function()
    local src = source
    local races = GetAllRaces()

    if races == nil or #races <= 0 then
        NotifyPlayerError(src, 'No races found')
        return
    end

    TriggerClientEvent('ardy_racing:ListRaces', src, races, 'All races')
end)

RegisterNetEvent("ardy_racing:GetAllUnlistedRaces")
AddEventHandler("ardy_racing:GetAllUnlistedRaces", function(admKey)
    local src = source
    if admKey ~= AdminKey then
        NotifyPlayerError(src, 'Unauthorized')
        return
    end

    local races = GetAllUnlistedRaces()

    if races == nil or #races <= 0 then
        NotifyPlayerError(src, 'No races found')
        return
    end

    TriggerClientEvent('ardy_racing:ListRaces', src, races, 'All unlisted races')
end)

RegisterNetEvent("ardy_racing:GetVerifiedRaces")
AddEventHandler("ardy_racing:GetVerifiedRaces", function()
    local src = source
    local races = GetVerifiedRaces()

    if races == nil or #races <= 0 then
        NotifyPlayerError(src, 'No races found')
        return
    end

    TriggerClientEvent('ardy_racing:ListRaces', src, races, 'Verified races')
end)

RegisterNetEvent("ardy_racing:RaceFinished")
AddEventHandler("ardy_racing:RaceFinished", function(eventUID, paramTbl)
    local src = source

    if eventUID == nil then
        NotifyPlayerError(src, 'Invalid data')
        return
    end

    local foundEvent = nil

    for _, event in pairs(RunningEvents) do
        if event.EventUID == eventUID then
            foundEvent = event
            break
        end
    end

    if foundEvent == nil then
        NotifyPlayerError(src, 'Race event not found')
        return
    end

    local foundPlayer = nil

    for index, player in pairs(foundEvent.Players) do
        if player.Id == src then
            foundPlayer = player
            break
        end
    end

    if foundPlayer == nil then
        NotifyPlayerError(src, 'You are not recognized as participant')
        return
    end

    local startVeh = foundPlayer.VehicleData
    if paramTbl.vehData ~= nil then
        foundPlayer.VehicleData = paramTbl.vehData
    end

    foundPlayer.HasFinished = true
    foundPlayer.TotalTime = paramTbl.totalTime
    foundPlayer.BestLapTime = paramTbl.bestLapTime
    foundPlayer.DriftScore = paramTbl.driftScore
    foundPlayer.BestLapDrift = paramTbl.bestLapDrift
    
    ProcessLeaderboard(foundEvent, foundPlayer, src, startVeh, paramTbl.vehData)

    SortEventPlayers(foundEvent)
    TriggerClientEvent('ardy_racing:PlayerFinishedEvent', -1, foundEvent.EventUID, foundPlayer, foundEvent.Players)
end)

RegisterNetEvent("ardy_racing:RaceClientHeartbeat")
AddEventHandler("ardy_racing:RaceClientHeartbeat", function(eventUID, paramTbl)
    local src = source
    if eventUID == nil then
        NotifyPlayerError(src, 'DEBUG: Invalid data')
        return
    end

    local foundEvent = nil

    for _, event in pairs(RunningEvents) do
        if event.EventUID == eventUID then
            foundEvent = event
            break
        end
    end

    if foundEvent == nil then
        NotifyPlayerError(src, 'DEBUG: Race event not found')
        return
    end

    local foundPlayer = nil

    for index, player in pairs(foundEvent.Players) do
        if player.Id == src then
            foundPlayer = player
            break
        end
    end

    if foundPlayer == nil then
        NotifyPlayerError(src, 'DEBUG: You are not recognized as participant')
        return
    end

    foundPlayer.CurrentCheckpoint = paramTbl.currentCheckpoint
    foundPlayer.CheckpointTimestamp = paramTbl.checkpointTimestamp
    foundPlayer.CurrentLap = paramTbl.currentLap
    foundPlayer.BestLapDrift = paramTbl.bestLapDrift
    foundPlayer.DriftScore = paramTbl.driftScore
    foundPlayer.CheckpointProximity = paramTbl.checkpointProximity
    foundPlayer.LastBeat = GetGameTimer()
end)

function SortEventPlayers(event)
    if (event == nil or event.Players == nil or #event.Players <= 0) then
        return
    end

    -- compare -> Is left before right?
    table.sort(event.Players, function(left, right) 
        if left.DNF ~= true and right.DNF == true then
            return true
        elseif left.DNF == true and right.DNF ~= true then
            return false
        end

        if left.HasFinished ~= true and right.HasFinished == true then
            return false
        elseif left.HasFinished == true and right.HasFinished ~= true then
            return true
        end

        if event.Type == RACETYPE_SPRINT then
            if left.TotalTime ~= nil and left.TotalTime > 0 and (right.TotalTime == nil or right.TotalTime <= 0) then
                return true
            elseif (left.TotalTime == nil or left.TotalTime <= 0) and right.TotalTime ~= nil and right.TotalTime > 0 then
                return false
            elseif left.TotalTime ~= nil and left.TotalTime > 0 and right.TotalTime ~= nil and right.TotalTime > 0 then
                return left.TotalTime < right.TotalTime
            end 

            return 
                (left.CurrentCheckpoint > right.CurrentCheckpoint) or
                (left.CurrentCheckpoint == right.CurrentCheckpoint and left.CheckpointProximity < right.CheckpointProximity) or
                (left.CurrentCheckpoint == right.CurrentCheckpoint and left.CheckpointProximity == right.CheckpointProximity and left.CheckpointTimestamp < right.CheckpointTimestamp)
        elseif event.Type == RACETYPE_CIRCUIT then
            if left.TotalTime ~= nil and left.TotalTime > 0 and (right.TotalTime == nil or right.TotalTime <= 0) then
                return true
            elseif (left.TotalTime == nil or left.TotalTime <= 0) and right.TotalTime ~= nil and right.TotalTime > 0 then
                return false
            elseif left.TotalTime ~= nil and left.TotalTime > 0 and right.TotalTime ~= nil and right.TotalTime > 0 then
                return left.TotalTime < right.TotalTime
            end 

            return 
                (left.CurrentLap > right.CurrentLap) or
                (left.CurrentLap == right.CurrentLap and left.CurrentCheckpoint > right.CurrentCheckpoint) or
                (left.CurrentLap == right.CurrentLap and left.CurrentCheckpoint == right.CurrentCheckpoint and left.CheckpointProximity < right.CheckpointProximity) or
                (left.CurrentLap == right.CurrentLap and left.CurrentCheckpoint == right.CurrentCheckpoint and left.CheckpointProximity == right.CheckpointProximity and left.CheckpointTimestamp < right.CheckpointTimestamp)
        elseif event.Type == RACETYPE_DRIFT then
            return left.DriftScore > right.DriftScore
        elseif event.Type == RACETYPE_DRIFTCIRCUIT then
            if left.BestLapDrift ~= nil and right.BestLapDrift == nil then
                return true
            elseif left.BestLapDrift == nil and right.BestLapDrift ~= nil then
                return false
            end

            return 
                (left.BestLapDrift ~= nil and right.BestLapDrift ~= nil and left.BestLapDrift > right.BestLapDrift) or
                ((left.BestLapDrift == nil and right.BestLapDrift == nil or left.BestLapDrift == right.BestLapDrift) and left.DriftScore > right.DriftScore)
        end
    end)

    for index, p in pairs(event.Players) do
        p.Position = index
    end
end

Citizen.CreateThread(function() 
    while true do
        if RunningEvents ~= nil and #RunningEvents > 0 then
            local currentTime = GetGameTimer()

            for eventIndex, event in pairs(RunningEvents) do
                local raceTime = (currentTime - event.StartTime)
                local cleanRaceTime = raceTime - Config.race_start_freezetime


                if raceTime > 0 and (event.Players == null or #event.Players <= 0) then
                    RunningEvents[eventIndex] = nil
                elseif cleanRaceTime > 0 then
                    for _, p in pairs(event.Players) do
                        if p.DNF ~= true and p.HasFinished ~= true and currentTime - p.LastBeat > 10000 then
                            p.DNF = true
                            p.HadFinished = true
                            TriggerClientEvent("ardy_racing:PlayerDisqualified", -1, event.EventUID, p.Id, 'Offline')
                        end
                    end

                    SortEventPlayers(event)

                    local isAnyoneRacing = false
                    local firstPlayer = nil

                    for index, p in pairs(event.Players) do
                        if index == 1 then
                            firstPlayer = p
                        end

                        if p.HasFinished ~= true and p.DNF ~= true then
                            isAnyoneRacing = true
                        end
                    end

                    for _, p in pairs(event.Players) do
                        TriggerClientEvent("ardy_racing:RaceServerHeartbeat", p.Id, event.EventUID, event.Players) 
                    end

                    if event.WinnerAnnounced ~= true and firstPlayer.HasFinished == true and (event.Type == RACETYPE_SPRINT or event.Type == RACETYPE_CIRCUIT) then
                        event.WinnerAnnounced = true
                        for index, p in pairs(event.Players) do
                            TriggerClientEvent("ardy_racing:AnnounceRaceWinner", p.Id, event.EventUID, event.Type, firstPlayer)
                        end
                    end

                    if isAnyoneRacing == false then
                        if event.Type == RACETYPE_DRIFT or event.Type == RACETYPE_DRIFTCIRCUIT then
                            for index, p in pairs(event.Players) do
                                TriggerClientEvent("ardy_racing:AnnounceRaceWinner", p.Id, event.EventUID, event.Type, firstPlayer)
                            end
                        end
                        RunningEvents[eventIndex] = nil
                    end
                end
            end

            for i = #RunningEvents, 1, -1 do
                if RunningEvents[i] == nil then
                    table.remove(RunningEvents, i)
                end
            end
        end
        Citizen.Wait(1000)
    end
end)