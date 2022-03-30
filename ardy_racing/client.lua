gameBuild = GetGameBuildNumber()
isAdmin = false
adminKey = nil

currentState = 0
currentRace = nil

raceList = nil
raceListTitle = nil

availableEvents = {}
isCountdownFrozen = false

notificationsBlocked = GetResourceKvpInt('cnf_notificationsBlocked') == 1
debugMode = GetResourceKvpInt('cnf_debugMode') == 1
alwaysAllBlips = GetResourceKvpInt('cnf_alwaysAllBlips') == 1

menuDefaultSprite =
{
    TextureDict = 'menu_textures',
    TextureName = 'logo',
    X = 1200.0,
    Y = 548.0
}

function SetCurrentRace(race)
    SetWaypointOff()
    SetEnableVehicleSlipstreaming(false)

    if currentRace ~= nil and currentRace.Checkpoints ~= nil then
        for _, checkpoint in pairs(currentRace.Checkpoints) do
            if checkpoint.blip ~= nil then
                RemoveBlip(checkpoint.blip)
                checkpoint.blip = nil
            end
            if checkpoint.checkpoint ~= nil then
                DeleteCheckpoint(checkpoint.checkpoint)
                checkpoint.checkpoint = nil
            end
        end
    end

    currentRace = race

    if currentRace ~= nil and currentRace.Checkpoints ~= nil then
        for index, checkpoint in pairs(currentRace.Checkpoints) do
            if checkpoint.coords ~= nil then
                checkpoint.blip = CreateRaceBlip(checkpoint.coords, index)
            end
        end
    end
end

function RegenerateMenu(forceReopen)

    local wasOpen = exports.ardy_easymenu:IsAnyMenuVisible()
    exports.ardy_easymenu:CloseMenu()

    if wasOpen == true or forceReopen == true then
        OpenMenu()
    end
end

function SetCurrentState(state, race, forceReopen)
    if state == STATE_PREJOIN and currentState > state then
        return
    end
    currentState = state
    SetCurrentRace(race)

    if state == STATE_JOINED then
        SetBlipRoute(currentRace.Checkpoints[2].blip, true)
    elseif state == STATE_PREPARE then
        currentRace.StartIn = 60
        currentRace.IsPublic = true
        currentRace.AllowSlipstream = false
        currentRace.OriginalLaps = currentRace.Laps
        currentRace.EndTimerAfterFirst = 0
        currentRace.ValidateProgress = true
        currentRace.AllowExitCar = true
        currentRace.IsRanked = true
    end

    RegenerateMenu(forceReopen)
end

RegisterNetEvent("ardy_racing:RaceSaved")
AddEventHandler("ardy_racing:RaceSaved", function()
    SetCurrentState(STATE_NONE, nil, false)
end)

RegisterNetEvent("ardy_racing:RaceDeleted")
AddEventHandler("ardy_racing:RaceDeleted", function()
    SetCurrentState(STATE_NONE, nil, false)
end)

RegisterNetEvent("ardy_racing:NewRaceEvent")
AddEventHandler("ardy_racing:NewRaceEvent", function(raceEvent)
    for _, r in pairs(availableEvents) do
        if r.EventUID == raceEvent.EventUID then
            return
        end
    end
    
    table.insert(availableEvents, raceEvent)
    
    if raceEvent.EventCreatorServerId ~= GetPlayerServerId(PlayerId()) and notificationsBlocked ~= true and raceEvent.IsPublic == true then
        NotifyPlayerAlert_client('New race event available! Start in '..GetStartInSecondsString(raceEvent.StartTime))
    end
end)

RegisterNetEvent("ardy_racing:AnnounceRaceWinner")
AddEventHandler("ardy_racing:AnnounceRaceWinner", function(eventUID, eventType, player)
    local inCarString = ''
    if player.VehicleData ~= nil then
        if player.VehicleData.Name ~= nil then
            inCarString = '~n~Car: ' .. player.VehicleData.Name
        else
            inCarString = '~n~Car: ' .. player.VehicleData.Hash
        end
    end

    if eventType == RACETYPE_SPRINT or eventType == RACETYPE_CIRCUIT then
        NotifyPlayerAlert_client(player.Name .. ' won the race~n~Time: '.. FormatTimeCustom(player.TotalTime) .. inCarString)
    elseif eventType == RACETYPE_DRIFT then
        if player.DriftScore == nil then
            player.DriftScore = 0
        end
        NotifyPlayerAlert_client(player.Name .. ' won the race~n~Score: '.. tostring(player.DriftScore) .. ' pts' .. inCarString)
    elseif eventType == RACETYPE_DRIFTCIRCUIT then
        if player.BestLapDrift == nil then
            player.BestLapDrift = 0
        end
        NotifyPlayerAlert_client(player.Name .. ' won the race~n~Best lap: '.. tostring(player.BestLapDrift) .. ' pts' .. inCarString)
    end
end)

RegisterNetEvent("ardy_racing:PlayerJoinedEvent")
AddEventHandler("ardy_racing:PlayerJoinedEvent", function(eventUID, playerObj)
    local foundEvent = nil
    
    for _, r in pairs(availableEvents) do
        if r.EventUID == eventUID then
            foundEvent = r
            break
        end
    end
    
    if foundEvent == nil then
        if debugMode == true then
            NotifyPlayerError_client('Joined event UID not found: ' .. tostring(eventUID))
        end
        return -- shouldnt happen, but if somehow... at least it wont crash
    end

    table.insert(foundEvent.Players, playerObj)
    CallRefresh()
    
    if playerObj.Id == GetPlayerServerId(PlayerId()) then
        exports.ardy_utils:NotifySuccess('Joined race event')
        SetCurrentState(STATE_JOINED, foundEvent, false)
    end
end)

RegisterNetEvent("ardy_racing:PlayerLeftEvent")
AddEventHandler("ardy_racing:PlayerLeftEvent", function(eventUID, playerServerId, reason)
    local foundEvent = nil
    
    for _, r in pairs(availableEvents) do
        if r.EventUID == eventUID then
            foundEvent = r
            break
        end
    end
    
    if foundEvent ~= nil then
        for index, player in pairs(foundEvent.Players) do
            if player.Id == playerServerId then
                table.remove(foundEvent.Players, index)
                break
            end
        end
    end

    CallRefresh()
    
    if playerServerId == GetPlayerServerId(PlayerId()) then
        driftEnabled = GetResourceKvpInt('cnf_driftEnabled') == 1
        local reasonString = ''
        if reason ~= nil then
            reasonString = ': ' .. reason
        end
        NotifyPlayerAlert_client('Race event left' .. reasonString)
        SetCurrentState(STATE_NONE, nil, false)
        if foundEvent ~= nil then
            SetCurrentState(STATE_PREJOIN, foundEvent, true)
        end
    end
end)

RegisterNetEvent("ardy_racing:PlayerDisqualified")
AddEventHandler("ardy_racing:PlayerDisqualified", function(eventUID, playerServerId, reason)
    if currentRace == nil or currentRace.EventUID ~= eventUID then
        return
    end

    local foundPlayer = nil

    if currentRace ~= nil then
        for index, player in pairs(currentRace.Players) do
            if player.Id == playerServerId then
                foundPlayer = player
                break
            end
        end
    end

    if foundPlayer ~= nil then
        foundPlayer.DNF = true
        foundPlayer.HasFinished = true
    end

    CallRefresh()

    if playerServerId == GetPlayerServerId(PlayerId()) then
        NotifyPlayerAlert_client('You have been disqualified: ' .. tostring(reason))
        driftEnabled = GetResourceKvpInt('cnf_driftEnabled') == 1
        SetCurrentState(STATE_AFTERRACE, currentRace, true)
    elseif foundPlayer ~= nil then
        NotifyPlayerAlert_client(foundPlayer.Name .. ' have been disqualified')
        if currentState == STATE_AFTERRACE then
            RegenerateMenu(false)
        end
    end
    
end)

RegisterNetEvent("ardy_racing:NewRecordSet")
AddEventHandler("ardy_racing:NewRecordSet", function(playerServerId, isAllCars, position, eventName, eventType, carHash, record, playerName)

    if playerServerId ~= GetPlayerServerId(PlayerId()) and notificationsBlocked == true then
        return
    end

    local carName = GetDisplayNameFromVehicleModel(carHash)
    local leaderboard = nil
    local recordString = nil
    local recordScoreString = nil

    if isAllCars == true then
        leaderboard = ""
    else
        leaderboard = "~n~Leaderboard: CAR SPECIFIC"
    end

    if eventType == RACETYPE_SPRINT or eventType == RACETYPE_CIRCUIT then
        recordString = '~n~Time: '
        recordScoreString = FormatTimeCustom(record)
    else
        recordString = '~n~Score: '
        recordScoreString = tostring(record) .. ' pts'
    end

    --NotifyPlayerAlert_client(playerName .. ' set new record~n~Race:' .. eventName .. '~n~Race type: ' .. GetRaceTypeText(eventType) .. '~n~Leaderboard: ' .. leaderboard .. '~n~Rank: #' .. tostring(position) .. '~n~Car: ' .. tostring(carName) .. recordString .. recordScoreString)
    NotifyPlayerAlert_client(playerName .. ' set new record~n~Race:' .. eventName .. leaderboard .. '~n~Rank: #' .. tostring(position) .. '~n~Car: ' .. tostring(carName) .. recordString .. recordScoreString)
end)

RegisterNetEvent("ardy_racing:RaceServerHeartbeat")
AddEventHandler("ardy_racing:RaceServerHeartbeat", function(eventUID, players)
    if currentRace == nil or currentRace.EventUID ~= eventUID then
        return
    end

    currentRace.Players = players

    CallRefresh()
end)

RegisterNetEvent("ardy_racing:RaceRenamed")
AddEventHandler("ardy_racing:RaceRenamed", function(oldName, newName)
    if currentRace ~= nil and currentRace.Name == oldName then
        SetCurrentState(STATE_NONE, nil, false)
        NotifyPlayerAlert_client('Menu refreshed - current race was renamed')
    end
end)

RegisterNetEvent("ardy_racing:AdminLoginSuccess")
AddEventHandler("ardy_racing:AdminLoginSuccess", function(key)
    exports.ardy_utils:NotifySuccess('Logged as admin')

    isAdmin = true
    adminKey = key

    RegenerateMenu(false)
end)

RegisterNetEvent("ardy_racing:PlayerFinishedEvent")
AddEventHandler("ardy_racing:PlayerFinishedEvent", function(eventUID, playerObj, players)
    if currentState ~= STATE_RACING and currentState ~= STATE_AFTERRACE then
        if debugMode then NotifyPlayerAlert_client('DEBUG: PlayerFinishedEvent - not in specific state') end
        return
    end

    if currentRace == nil or currentRace.EventUID ~= eventUID then
        if debugMode then NotifyPlayerAlert_client('DEBUG: PlayerFinishedEvent - different eventUID') end
        return
    end
    
    currentRace.Players = players
    -- for index, player in pairs(currentRace.Players) do
    --     if player.Id == playerObj.Id then
    --         currentRace.Players[index] = playerObj
    --         break
    --     end
    -- end

    if currentState == STATE_AFTERRACE then
        RegenerateMenu(false)
    end
    
    if playerObj.Id == GetPlayerServerId(PlayerId()) then
        driftEnabled = GetResourceKvpInt('cnf_driftEnabled') == 1
        --exports.ardy_utils:NotifySuccess('You finished the race!') -- useless spam
    else
        NotifyPlayerAlert_client(playerObj.Name .. ' finished the race!')
    end
end)

RegisterNetEvent("ardy_racing:OpenCreatedEvent")
AddEventHandler("ardy_racing:OpenCreatedEvent", function(raceEvent)
    local isFound = false
    for _, r in pairs(availableEvents) do
        if r.EventUID == raceEvent.EventUID then
            isFound = true
            raceEvent = r
        end
    end
    
    if isFound == false then
        table.insert(availableEvents, raceEvent) -- in case previous event didn't arrive?
    end
    
    SetCurrentState(STATE_PREJOIN, raceEvent, true)
end)

RegisterNetEvent("ardy_racing:RaceVerificationSet")
AddEventHandler("ardy_racing:RaceVerificationSet", function(raceName, isVerified)
    if currentRace ~= nil and currentRace.Name == raceName then
        currentRace.IsVerified = isVerified
        CallRefresh()
    end 
    
    exports.ardy_utils:NotifySuccess('Verification updated!')
end)

RegisterNetEvent("ardy_racing:RaceUnlistedSet")
AddEventHandler("ardy_racing:RaceUnlistedSet", function(raceName, isUnlisted)
    if currentRace ~= nil and currentRace.Name == raceName then
        currentRace.IsUnlisted = isUnlisted
        CallRefresh()
    end 
    
    exports.ardy_utils:NotifySuccess('Listed status updated!')
end)

RegisterNetEvent("ardy_racing:OpenRaceLeaderboards")
AddEventHandler("ardy_racing:OpenRaceLeaderboards", function(raceName, raceType, leaderboard)
    if leaderboard == nil then
        return
    end

    local isHigherBetter = leaderboard['IsHigherBetter'] == true

    menu = 
    {
        MenuTitle = 'Leaderboards', --  [' .. raceName .. ']',
        Sprite = menuDefaultSprite,
        Buttons = {}
    }

    if leaderboard[ALLCAR] ~= nil then
        table.sort(leaderboard[ALLCAR], function(left, right) return (isHigherBetter == true and left.Record > right.Record) or (isHigherBetter == false and left.Record < right.Record) end)

        local submenu = {
            MenuTitle = 'Global',
            Sprite = menuDefaultSprite,
            Buttons = {}
        }

        for index, k in pairs(leaderboard[ALLCAR]) do
            local carName = GetDisplayNameFromVehicleModel(k.CarHash)

            if carName == nil then
                carName = 'Unknown - dev error'
            end
            table.insert(submenu.Buttons,{
                Name = '#' .. tostring(index) .. ' ' .. k.AuthorName,
                NameRight = FormatLeaderboardScore(raceType, k.Record),
                ExtraLeft = 'Car',
                ExtraRight = carName
            })
        end

        table.insert(submenu.Buttons,{
            Name = 'Back',
            Icon = 'back3_w256',
            IsBack = true
        })

        table.insert(menu.Buttons, {
            Name = 'Global - All cars',
            Icon = 'star_w256',
            SubMenu = submenu
        })
    end

    for key, cat in pairs(leaderboard) do
        local carHash = tonumber(key)
        if key ~= ALLCAR and key~= 'IsHigherBetter' and carHash ~= nil then
            local carName = GetDisplayNameFromVehicleModel(carHash)

            if carName == nil then
                carName = 'Unknown - dev error'
            end

            table.sort(cat, function(left, right) return (isHigherBetter == true and left.Record > right.Record) or (isHigherBetter == false and left.Record < right.Record) end)

            local submenu = {
                MenuTitle = carName,
                Sprite = menuDefaultSprite,
                Buttons = {}
            }

            for index, k in pairs(cat) do
                table.insert(submenu.Buttons,{
                    Name = '#' .. tostring(index) .. ' ' .. k.AuthorName,
                    NameRight = FormatLeaderboardScore(raceType, k.Record)
                })
            end

            table.insert(submenu.Buttons,{
                Name = 'Back',
                Icon = 'back3_w256',
                IsBack = true
            })

            table.insert(menu.Buttons, {
                Name = carName,
                Icon = 'car_w256',
                --NameRight = carName,
                SubMenu = submenu
            })
        end
    end

    table.insert(menu.Buttons, {
        Name = 'Back',
        Icon = 'back3_w256',
        IsBack = true
    })

    exports.ardy_easymenu:ShowMenuAsSubMenu(GetCurrentResourceName(), menu)
end)

RegisterNetEvent("ardy_racing:ListRaces")
AddEventHandler("ardy_racing:ListRaces", function(races, menuName)
    raceList = races
    raceListTitle = menuName
    currentState = STATE_NONE
    SetWaypointOff()
    SetCurrentRace(nil)
    exports.ardy_easymenu:CloseMenu()
    OpenListMenu()
end)

-- menu key
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        if IsControlJustReleased(1, Config.menu_open_key) then
            local isOpen = exports.ardy_easymenu:IsAnyMenuVisible()
            if isOpen then
                exports.ardy_easymenu:HideMenuIfNotHidden(GetCurrentResourceName())
            else
                OpenMenu()
            end
        end

        if debugMode == true then
            exports.ardy_utils:Draw2DText(Config.debug_x, Config.debug_y, 'State: ' .. tostring(currentState), 0.3, false, 255, 255, 255)
        end
    end
end)

--available events periodic cleanup
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        
        if availableEvents ~= nil and #availableEvents > 0 then
            local currentTime = GetNetworkTime()

            for i = #availableEvents, 1, -1 do
                if availableEvents[i].StartTime < currentTime then
                    table.remove(availableEvents, i)
                end
            end
        end
    end
end)

--racing loop
Citizen.CreateThread(function()
    while true do
        if currentState == STATE_JOINED or currentState == STATE_RACING then
            local currentTime = GetNetworkTime()
            local raceTimer = currentTime - currentRace.StartTime
            local raceCleanTime = raceTimer - Config.race_start_freezetime

            if debugMode == true then
                exports.ardy_utils:Draw2DText(Config.debug_x, Config.debug_y + 0.06, 'RaceTimer: ' .. tostring(raceTimer), 0.3, false, 255, 200, 0)
            end

            if currentState == STATE_JOINED then
                if raceTimer >= 0 then
                    currentState = STATE_RACING
                    currentRace.CheckpointCurrent = 1
                    currentRace.CheckpointTimestamp = currentTime
                    currentRace.DriftScore = 0
                    currentRace.CheckpointProximity = 0
                    if IsRaceCircuitType() == true then
                        currentRace.CurrentLap = 1
                        currentRace.LastLapStartTime = currentRace.StartTime + Config.race_start_freezetime
                        currentRace.BestLapTime = nil
                    else
                        currentRace.CurrentLap = nil
                    end

                    if #currentRace.Checkpoints > 4 and not alwaysAllBlips then
                        RemoveBlip(currentRace.Checkpoints[currentRace.CheckpointCurrent].blip)
                        currentRace.Checkpoints[currentRace.CheckpointCurrent].blip = nil
                    else
                        SetBlipColour(currentRace.Checkpoints[currentRace.CheckpointCurrent].blip, Config.blip_passed_color)
                    end

                    SetBlipRoute(currentRace.Checkpoints[currentRace.CheckpointCurrent + 1].blip, true)
                    SetBlipRouteColour(currentRace.Checkpoints[currentRace.CheckpointCurrent + 1].blip, Config.blip_color)
                    CheckpointPassed()

                    local checkpointType = nil
                    local targetCheckpointCoords = {0,0,0}
                    if #currentRace.Checkpoints > 2 then
                        checkpointType = Config.race_checkpoint_type
                        targetCheckpointCoords = {currentRace.Checkpoints[currentRace.CheckpointCurrent + 2].coords.x, currentRace.Checkpoints[currentRace.CheckpointCurrent + 2].coords.y, currentRace.Checkpoints[currentRace.CheckpointCurrent + 2].coords.z}
                    else
                        if IsRaceCircuitType() == true then
                            if currentRace.Laps > 1 then
                                checkpointType = Config.race_checkpoint_nextlap_type
                            else
                                checkpointType = Config.race_checkpoint_finish_type
                            end
                        else
                            checkpointType = Config.race_checkpoint_finish_type
                        end
                    end

                    currentRace.Checkpoints[currentRace.CheckpointCurrent + 1].checkpoint = CreateCheckpoint(checkpointType, currentRace.Checkpoints[currentRace.CheckpointCurrent + 1].coords.x,  currentRace.Checkpoints[currentRace.CheckpointCurrent + 1].coords.y, currentRace.Checkpoints[currentRace.CheckpointCurrent + 1].coords.z + Config.checkpoint_z_offset, targetCheckpointCoords[1], targetCheckpointCoords[2], targetCheckpointCoords[3] + Config.checkpoint_z_offset, Config.checkpoint_radius, 255, 200, 0, 160, 0)
                    SetCheckpointCylinderHeight(currentRace.Checkpoints[currentRace.CheckpointCurrent + 1].checkpoint, Config.checkpoint_height, Config.checkpoint_height, Config.checkpoint_radius)

                    currentRace.CheckpointCurrent = currentRace.CheckpointCurrent + 1
                    currentRace.CheckpointTimestamp = currentTime
                else
                    local player = GetPlayerPed(-1)
                    local position = GetEntityCoords(player)
                    local proximity = GetDistanceBetweenCoords(position.x, position.y, position.z, currentRace.Checkpoints[1].coords.x, currentRace.Checkpoints[1].coords.y, currentRace.Checkpoints[1].coords.z, true)

                    if proximity > (Config.start_radius / 2.0) then
                        TriggerServerEvent("ardy_racing:LeaveEvent", currentRace, 'You were far from start')
                    end
                end
            end

            if currentState == STATE_RACING then
                local player = GetPlayerPed(-1)
                if IsPedInAnyVehicle(player, false) then
                    local position = GetEntityCoords(player)
                    local vehicle = GetVehiclePedIsIn(player, false)

                    if raceCleanTime < 0 then
                        exports.ardy_utils:Draw2DText(0.5, 0.4, ("~y~%d"):format(math.ceil((raceCleanTime * -1)/1000.0)), 3.0, true, 255, 255, 255)
                        if isCountdownFrozen == false then
                            if currentRace.Type == RACETYPE_DRIFT or currentRace.Type == RACETYPE_DRIFTCIRCUIT then
                                driftEnabled = true
                            end
                            FreezeEntityPosition(vehicle, true)
                            isCountdownFrozen = true
                            if currentRace.AllowSlipstream == true then
                                SetEnableVehicleSlipstreaming(true)
                            end
                            local vehHash = GetEntityModel(vehicle)
                            local vehDName = GetDisplayNameFromVehicleModel(vehHash)
                            TriggerServerEvent("ardy_racing:RegisterEventPlayerVehicle", currentRace.EventUID, {Hash = vehHash, Name = vehDName})
                            exports.ardy_easymenu:HideMenuIfNotHidden(GetCurrentResourceName())
                            RegenerateMenu(false)

                            if #currentRace.Checkpoints > 4 and not alwaysAllBlips then
                                for i = 5, #currentRace.Checkpoints, 1 do
                                    if currentRace.Checkpoints[i].blip ~= nil then
                                        RemoveBlip(currentRace.Checkpoints[i].blip)
                                        currentRace.Checkpoints[i].blip = nil
                                    end
                                end
                            end
                        end
                    elseif raceCleanTime >= 0 and isCountdownFrozen == true then
                        FreezeEntityPosition(vehicle, false)
                        isCountdownFrozen = false
                    end

                    local checkpointProximity = GetDistanceBetweenCoords(position.x, position.y, position.z, currentRace.Checkpoints[currentRace.CheckpointCurrent].coords.x, currentRace.Checkpoints[currentRace.CheckpointCurrent].coords.y, currentRace.Checkpoints[currentRace.CheckpointCurrent].coords.z, false)
                    UpdateCheckpointDistance(checkpointProximity)
                    currentRace.CheckpointProximity = checkpointProximity
                    if checkpointProximity < (Config.checkpoint_radius / 2) * 1.2 then                        
                        if currentRace.Checkpoints[currentRace.CheckpointCurrent].checkpoint ~= nil then
                            DeleteCheckpoint(currentRace.Checkpoints[currentRace.CheckpointCurrent].checkpoint)
                        end

                        CheckpointPassed()
                        
                        if (currentRace.CheckpointCurrent == #currentRace.Checkpoints and currentRace.CurrentLap == nil) or (currentRace.CheckpointCurrent == 1 and currentRace.CurrentLap ~= nil and currentRace.CurrentLap == currentRace.Laps) then
                            PlaySoundFrontend(-1, "ScreenFlash", "WastedSounds")
                            
                            RaceLapFinished(currentTime)
                            RaceFinished(currentTime)

                            local vehHash = GetEntityModel(vehicle)
                            local vehDName = GetDisplayNameFromVehicleModel(vehHash)
                            TriggerServerEvent('ardy_racing:RaceFinished', currentRace.EventUID, {totalTime = currentRace.TotalTime, bestLapTime = currentRace.BestLapTime, driftScore = currentRace.DriftScore, bestLapDrift = currentRace.BestDriftLap, vehData = {Hash = vehHash, Name = vehDName}})
                            SetCurrentState(STATE_AFTERRACE, currentRace, true)
                        else
                            local nextIndex = currentRace.CheckpointCurrent + 1
                            local nextNextIndex = currentRace.CheckpointCurrent + 2
                            local nextNextNextIndex = currentRace.CheckpointCurrent + 3

                            if nextIndex > #currentRace.Checkpoints then
                                nextIndex = nextIndex - #currentRace.Checkpoints
                            end
                            if nextNextIndex > #currentRace.Checkpoints then
                                nextNextIndex = nextNextIndex - #currentRace.Checkpoints
                            end
                            if nextNextNextIndex > #currentRace.Checkpoints then -- TODO refactor this crap
                                nextNextNextIndex = nextNextNextIndex - #currentRace.Checkpoints
                            end

                            if not alwaysAllBlips and #currentRace.Checkpoints > 4 then
                                RemoveBlip(currentRace.Checkpoints[currentRace.CheckpointCurrent].blip)
                                currentRace.Checkpoints[currentRace.CheckpointCurrent].blip = nil

                                if nextNextNextIndex <= #currentRace.Checkpoints and currentRace.Checkpoints[nextNextNextIndex].blip == nil then
                                    if currentRace.CurrentLap == nil then --SPRINT
                                        if currentRace.CheckpointCurrent < nextNextNextIndex then
                                            if currentRace.Checkpoints[nextNextNextIndex].coords ~= nil then
                                                currentRace.Checkpoints[nextNextNextIndex].blip = CreateRaceBlip(currentRace.Checkpoints[nextNextNextIndex].coords, nextNextNextIndex)
                                            end
                                        end
                                    else --CIRCUIT
                                        if currentRace.CheckpointCurrent < nextNextNextIndex or
                                           currentRace.CurrentLap < currentRace.Laps or 
                                           (currentRace.CurrentLap == currentRace.Laps and nextNextNextIndex == 1) then
                                            if currentRace.Checkpoints[nextNextNextIndex].coords ~= nil then
                                                currentRace.Checkpoints[nextNextNextIndex].blip = CreateRaceBlip(currentRace.Checkpoints[nextNextNextIndex].coords, nextNextNextIndex)
                                            end
                                        end
                                    end
                                end
                            else
                                SetBlipColour(currentRace.Checkpoints[currentRace.CheckpointCurrent].blip, Config.blip_passed_color)

                                if nextIndex == 2 then
                                    for _, point in pairs(currentRace.Checkpoints) do
                                        if point.blip ~= nil then
                                            SetBlipColour(point.blip, Config.blip_color)
                                        end
                                    end
                                end
                            end

                            PlaySoundFrontend(-1, "RACE_PLACED", "HUD_AWARDS")

                            SetBlipRoute(currentRace.Checkpoints[nextIndex].blip, true)
                            SetBlipRouteColour(currentRace.Checkpoints[nextIndex].blip, Config.blip_color)
 
                            local checkpointType = nil
                            local targetCheckpointCoords = {0,0,0}
                            if currentRace.CurrentLap == nil then --SPRINT
                                if nextIndex == #currentRace.Checkpoints then
                                    checkpointType = Config.race_checkpoint_finish_type
                                else
                                    checkpointType = Config.race_checkpoint_type
                                    targetCheckpointCoords = {currentRace.Checkpoints[nextNextIndex].coords.x, currentRace.Checkpoints[nextNextIndex].coords.y, currentRace.Checkpoints[nextNextIndex].coords.z}
                                end
                            else --CIRCUIT
                                if nextIndex == 1 and currentRace.CurrentLap == currentRace.Laps then
                                    checkpointType = Config.race_checkpoint_finish_type
                                else
                                    if nextIndex == 1 then
                                        checkpointType = Config.race_checkpoint_nextlap_type
                                    else
                                        checkpointType = Config.race_checkpoint_type
                                    end
                                    
                                    targetCheckpointCoords = {currentRace.Checkpoints[nextNextIndex].coords.x, currentRace.Checkpoints[nextNextIndex].coords.y, currentRace.Checkpoints[nextNextIndex].coords.z}
                                end
                            end
                            

                            currentRace.Checkpoints[nextIndex].checkpoint = CreateCheckpoint(checkpointType, currentRace.Checkpoints[nextIndex].coords.x,  currentRace.Checkpoints[nextIndex].coords.y, currentRace.Checkpoints[nextIndex].coords.z + Config.checkpoint_z_offset, targetCheckpointCoords[1], targetCheckpointCoords[2], targetCheckpointCoords[3] + Config.checkpoint_z_offset, Config.checkpoint_radius, 255, 200, 0, 160, 0)
                            SetCheckpointCylinderHeight(currentRace.Checkpoints[nextIndex].checkpoint, Config.checkpoint_height, Config.checkpoint_height, Config.checkpoint_radius)

                            if currentRace.CheckpointCurrent == 1 and currentRace.CurrentLap ~= nil then
                                currentRace.CurrentLap = currentRace.CurrentLap + 1
                                RaceLapFinished(currentTime)
                            end
                            currentRace.CheckpointCurrent = nextIndex
                            currentRace.CheckpointProximity = 0
                            currentRace.CheckpointTimestamp = currentTime
                        end
                    end

                else
                    if currentRace.AllowExitCar ~= true then
                        TriggerServerEvent("ardy_racing:LeaveEvent", currentRace, 'You left your car')
                    end
                end
            end       

            Citizen.Wait(0)
        else
            Citizen.Wait(500)
        end
    end
end)

--Auto menu refresh during some states + heartbeat
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        
        if currentState == STATE_AVAILABLEEVENTS or currentState == STATE_PREJOIN or currentState == STATE_JOINED or currentState == STATE_AFTERRACE then
            CallRefresh()
        end

        if currentState == STATE_RACING then
            local checkpointNum = currentRace.CheckpointCurrent - 1
            if checkpointNum <= 0 then
                checkpointNum = checkpointNum + #currentRace.Checkpoints
            end

            TriggerServerEvent('ardy_racing:RaceClientHeartbeat', currentRace.EventUID, {
                currentCheckpoint = checkpointNum,
                checkpointTimestamp = currentRace.CheckpointTimestamp,
                currentLap = currentRace.CurrentLap,
                bestLapDrift = currentRace.BestDriftLap,
                driftScore = currentRace.DriftScore,
                checkpointProximity = currentRace.CheckpointProximity
            })
        end
    end
end)

--Checkpoint recording
Citizen.CreateThread(function()
    while true do
        if currentState ~= STATE_EDITOR then
            Citizen.Wait(1000)
        else
            Citizen.Wait(100)
            
            if IsWaypointActive() and currentRace.Checkpoints ~= nil then
                local waypointCoords = GetBlipInfoIdCoord(GetFirstBlipInfoId(8))
                local retval, coords = GetClosestVehicleNode(waypointCoords.x, waypointCoords.y, waypointCoords.z, 1)
                SetWaypointOff()

                for index, checkpoint in pairs(currentRace.Checkpoints) do
                    if GetDistanceBetweenCoords(coords.x, coords.y, coords.z, checkpoint.coords.x, checkpoint.coords.y, checkpoint.coords.z, false) < 20.0 then
                        RemoveBlip(checkpoint.blip)
                        table.remove(currentRace.Checkpoints, index)
                        coords = nil

                        for i = index, #currentRace.Checkpoints do
                            ShowNumberOnBlip(currentRace.Checkpoints[i].blip, i)
                        end
                        break
                    end
                end

                if (coords ~= nil) then
                    local blip = CreateRaceBlip(coords, #currentRace.Checkpoints+1)
                    table.insert(currentRace.Checkpoints, {blip = blip, coords = coords})
                end

                CallRefresh()
            end

        end
    end
end)

-- race join draw
Citizen.CreateThread(function() 
    while true do
        local player = GetPlayerPed(-1)
        local position = GetEntityCoords(player)
        local isDrawing = false

        for index, event in pairs(availableEvents) do
            local currentTime = GetNetworkTime()            

            if event.StartTime > currentTime then
                local proximity = GetDistanceBetweenCoords(position.x, position.y, position.z, event.Checkpoints[1].coords.x, event.Checkpoints[1].coords.y, event.Checkpoints[1].coords.z, true)
                if proximity < 80 then
                    isDrawing = true
                    local startIn = GetStartInSecondsString(event.StartTime)

                    exports.ardy_utils:Draw3DText(event.Checkpoints[1].coords.x, event.Checkpoints[1].coords.y, event.Checkpoints[1].coords.z+1.3, ("A race is starting in ~y~%s~w~"):format(startIn), 2, 255, 255, 255)
                    if currentState == STATE_JOINED then
                        exports.ardy_utils:Draw3DText(event.Checkpoints[1].coords.x, event.Checkpoints[1].coords.y, event.Checkpoints[1].coords.z+0.80, "[~g~Joined~w~]", 2, 255, 255, 255)
                        DrawMarker(1, event.Checkpoints[1].coords.x, event.Checkpoints[1].coords.y, event.Checkpoints[1].coords.z - 5.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, Config.start_radius, Config.start_radius, 10.0, 255, 200, 0, 160, false, true, 2, false, false, false, false)
                    else
                        exports.ardy_utils:Draw3DText(event.Checkpoints[1].coords.x, event.Checkpoints[1].coords.y, event.Checkpoints[1].coords.z+0.80, "Press [~g~E~w~] for join menu", 2, 255, 255, 255)
                    end
                    DrawMarker(4, event.Checkpoints[1].coords.x, event.Checkpoints[1].coords.y, event.Checkpoints[1].coords.z+2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 2.0, 2.0, 255, 200, 0, 160, false, true, 2, false, false, false, false)

                    if IsControlJustReleased(1, 38) and ((exports.ardy_easymenu:IsAnyMenuVisible() == false and currentState <= STATE_PREJOIN) or (exports.ardy_easymenu:IsAnyMenuVisible() == true and currentState < STATE_PREJOIN)) then
                        SetCurrentState(STATE_PREJOIN, event, true)
                    end
                end
            end
        end

        if isDrawing == true then
            Citizen.Wait(0)
        else
            Citizen.Wait(500)
        end
    end
end)

function OpenMenu()
    if currentState == STATE_INSPECT then
        if exports.ardy_easymenu:ToggleMenuVisible(GetCurrentResourceName()) == true then
            return
        else
            currentState = STATE_NONE
            SetWaypointOff()
            SetCurrentRace(nil)
        end
    end

    if currentState == STATE_NONE then
        menu = 
        {
            MenuTitle = 'Menu',
            Sprite = menuDefaultSprite,
            Buttons = 
            {
                {Name = 'Joinable events', Icon = 'racing_w256', FuncOnSelected = function()
                    SetCurrentState(STATE_AVAILABLEEVENTS, nil, false)
                end},
                {Name = 'My races', Icon = 'race-track_w256', FuncOnSelected = function()
                    TriggerServerEvent('ardy_racing:GetMyRaces')
                end},
                {Name = 'Verified races', Icon = 'race-track_w128', FuncOnSelected = function()
                    TriggerServerEvent('ardy_racing:GetVerifiedRaces')
                end},
                {Name = 'All listed races', Icon = 'race-track_w256', FuncOnSelected = function()
                    TriggerServerEvent('ardy_racing:GetAllRaces')
                end},
                {Name = 'Create new race template', Icon = 'new-page_w256', FuncOnSelected = function()
                    SetCurrentState(STATE_EDITOR, 
                    { 
                        Name = 'New race', 
                        Checkpoints = {}, 
                        Type = RACETYPE_SPRINT, 
                        Laps = nil,
                        IsUnlisted = true
                    }, true)
                end},
                {Name = 'Settings and Tools', Icon = 'settings_w256', SubMenu = {
                    MenuTitle = 'Settings and Tools',
                    Sprite = menuDefaultSprite,
                    Buttons = {
                        {Name = 'Car drift tires', NameRight = GetBoolTextDriftTyres(driftTyre), FuncOnSelected = function(buttonRef) 
                            if gameBuild >= 2189 then
                                if Config.enable_drift_tire_manipultion == true then 
                                    local player = GetPlayerPed(-1)
                                    
                                    if IsPedInAnyVehicle(player, false) then
                                        local veh = GetVehiclePedIsIn(player, false)
                                        driftTyre = GetDriftTyresEnabledSafe(veh)
                
                                        driftTyre = not driftTyre
                                        SetDriftTyresEnabled(veh, driftTyre)
                                    end
                
                                    buttonRef.NameRight = GetBoolTextDriftTyres(driftTyre) 
                                    return buttonRef
                                else
                                    NotifyPlayerError_client('Server admin has disabled this feature')
                                end
                            else
                                NotifyPlayerError_client('Server has unsupported build')
                            end
                        end,
                        FuncRefresh = function(buttonRef)
                            buttonRef.NameRight = GetBoolTextDriftTyres(driftTyre) 
                            return buttonRef
                        end},
                        {Name = 'Drift HUD in freeroam', NameRight = GetBoolText(driftEnabled), FuncOnSelected = function(buttonRef)
                            driftEnabled = not driftEnabled
                            SetResourceKvpInt('cnf_driftEnabled', GetBoolInt(driftEnabled))
                            if driftEnabled == true then
                                driftTotalScore = 0
                            end
        
                            buttonRef.NameRight = GetBoolText(driftEnabled) 
                            return buttonRef 
                        end},
                        {Name = 'Flash lights on horn', NameRight = GetBoolText(honkEnabled), FuncOnSelected = function(buttonRef)
                            honkEnabled = not honkEnabled
                            SetResourceKvpInt('cnf_honkEnabled', GetBoolInt(honkEnabled))
        
                            buttonRef.NameRight = GetBoolText(honkEnabled) 
                            return buttonRef 
                        end},
                        {Name = 'Block notifications out of race', NameRight = GetBoolText(notificationsBlocked), FuncOnSelected = function(buttonRef)
                            notificationsBlocked = not notificationsBlocked
                            SetResourceKvpInt('cnf_notificationsBlocked', GetBoolInt(notificationsBlocked))
        
                            buttonRef.NameRight = GetBoolText(notificationsBlocked) 
                            return buttonRef 
                        end},
                        {Name = 'Show all blips in race', NameRight = GetBoolText(alwaysAllBlips), FuncOnSelected = function(buttonRef)
                            alwaysAllBlips = not alwaysAllBlips
                            SetResourceKvpInt('cnf_alwaysAllBlips', GetBoolInt(alwaysAllBlips))
        
                            buttonRef.NameRight = GetBoolText(alwaysAllBlips) 
                            return buttonRef 
                        end},
                        {Name = 'Debug mode', NameRight = GetBoolText(debugMode), FuncOnSelected = function(buttonRef)
                            debugMode = not debugMode
                            SetResourceKvpInt('cnf_debugMode', GetBoolInt(debugMode))
        
                            buttonRef.NameRight = GetBoolText(debugMode) 
                            return buttonRef 
                        end},
                        {Name = 'Back', Icon = 'back3_w256', IsBack = true}
                    }
                }},
                {Name = 'About', Icon = 'info_w256', SubMenu = {
                    MenuTitle = 'About',
                    Sprite = menuDefaultSprite,
                    Buttons = {
                        {Name = 'Back', Icon = 'back3_w256', IsBack = true},
                        {Name = ' ', IsUnselectable = true},
                        {Name = 'Version', NameRight = '1.2' },
                        {Name = 'Author', NameRight = 'Ardy'}
                    }
                }},
                {Name = 'Close', Icon = 'close3_w256', IsBack = true},
            }
        }

        local settingsButtons = menu.Buttons[#menu.Buttons - 2].SubMenu.Buttons
        if isAdmin == false then
            table.insert(settingsButtons, #settingsButtons, {Name = 'Admin login', IsTextInput = true, TextInputRequest = 'Enter password', TextInputMaxLen = 30, FuncOnTextInput = function(input)
                input = input:match'^%s*(.*%S)' or ''
                TriggerServerEvent("ardy_racing:AdminLogin", input)
            end})
        else
            table.insert(settingsButtons, #settingsButtons, {Name = 'Logged as admin!'})
            table.insert(settingsButtons, #settingsButtons, {Name = '[Admin] Delete car model leaderboard', IsTextInput = true, TextInputRequest = 'Delete car from EVERY leaderboard', TextInputMaxLen = 60, FuncOnTextInput = function(input)
                input = input:match'^%s*(.*%S)' or ''
                local hash = GetHashKey(input)
                if hash == nil then
                    NotifyPlayerError_client('Invalid model - can not get hash')
                else
                    TriggerServerEvent("ardy_racing:Admin_clearHashFromLeaderboards", adminKey, hash)
                end
            end})

            local insIndex = 1
            for index, b in pairs(menu.Buttons) do
                if b.Name == 'All listed races' then
                    insIndex = (index + 1)
                    break
                end
            end

            table.insert(menu.Buttons, insIndex, {
                Name = '[Admin] All unlisted races', FuncOnSelected = function()
                    TriggerServerEvent('ardy_racing:GetAllUnlistedRaces', adminKey)
                end
            })
        end
    elseif currentState == STATE_EDITOR then
        menu = 
        {
            MenuTitle = 'Editor',
            Sprite = menuDefaultSprite,
            Buttons = 
            {
                {Name = 'Race name', ExtraLeft = currentRace.Name, IsTextInput = true, TextInputRequest = 'Enter name', TextInputPrefill = 'ExtraLeft', TextInputMaxLen = 30, FuncOnTextInput = function(input)
                    input = input:match'^%s*(.*%S)' or ''
                    currentRace.Name = input
                end, FuncRefresh = function(buttonRef) 
                    buttonRef.ExtraLeft = currentRace.Name
                    return buttonRef
                end},
                {Name = 'Race type', NameRight = GetRaceTypeText(currentRace.Type), SubMenu = {
                    MenuTitle = 'Set race type',
                    Sprite = menuDefaultSprite,
                    Buttons = {
                        {Name = GetRaceTypeText(RACETYPE_SPRINT), IsBack = true, FuncOnSelected = function() 
                            currentRace.Type = RACETYPE_SPRINT
                            currentRace.Laps = nil
                        end},
                        {Name = GetRaceTypeText(RACETYPE_CIRCUIT), IsBack = true, FuncOnSelected = function() 
                            currentRace.Type = RACETYPE_CIRCUIT
                            currentRace.Laps = 3
                        end},
                        {Name = GetRaceTypeText(RACETYPE_DRIFT), IsBack = true, FuncOnSelected = function() 
                            currentRace.Type = RACETYPE_DRIFT
                            currentRace.Laps = nil
                        end},
                        {Name = GetRaceTypeText(RACETYPE_DRIFTCIRCUIT), IsBack = true, FuncOnSelected = function() 
                            currentRace.Type = RACETYPE_DRIFTCIRCUIT
                            currentRace.Laps = 3
                        end}
                    }
                }, FuncRefresh = function(buttonRef)
                    buttonRef.NameRight = GetRaceTypeText(currentRace.Type) 
                    return buttonRef
                end},
                {Name = 'Listed publicly', NameRight = GetBoolYesNoTextInverted(currentRace.IsUnlisted), FuncOnSelected = function(buttonRef)
                    if currentRace.IsUnlisted == nil then
                        currentRace.IsUnlisted = false
                    end
                    currentRace.IsUnlisted = not currentRace.IsUnlisted

                    CallRefresh()
                    buttonRef.NameRight = GetBoolYesNoTextInverted(currentRace.IsUnlisted)
                    return buttonRef 
                end, FuncRefresh = function(buttonRef)
                    buttonRef.NameRight = GetBoolYesNoTextInverted(currentRace.IsUnlisted)
                    return buttonRef
                end},
                {Name = 'Laps', NameRight = GetLapsString(currentRace.Laps), IsTextInput = true, TextInputRequest = 'Enter laps count', TextInputMaxLen = 2, FuncOnTextInput = function(input)
                    input = input:match'^%s*(.*%S)' or ''
                    local laps = tonumber(input)
                    if currentRace.Type ~= RACETYPE_CIRCUIT and currentRace.Type ~= RACETYPE_DRIFTCIRCUIT then
                        NotifyPlayerError_client('Not a circuit!')
                    elseif laps == nil then
                        NotifyPlayerError_client('Invalid number!')
                    else
                        currentRace.Laps = laps
                    end
                end, FuncRefresh = function(buttonRef) 
                    buttonRef.NameRight = GetLapsString(currentRace.Laps)
                    return buttonRef
                end},
                {Name = 'Checkpoint count', NameRight = tostring(#currentRace.Checkpoints), FuncRefresh = function(buttonRef)
                    buttonRef.NameRight = tostring(#currentRace.Checkpoints)
                    return buttonRef
                end},
                {Name = 'Add checkpoint here', FuncOnSelected = function(buttonRef)
                    local entity = GetPlayerPed(-1)
                    if IsPedInAnyVehicle(entity, false) then
                        entity = GetVehiclePedIsIn(entity, false)
                    end
                    local coords = GetEntityCoords(entity)

                    if (coords ~= nil) then
                        -- Add numbered checkpoint blip
                        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
                        SetBlipColour(blip, Config.blip_color)
                        SetBlipAsShortRange(blip, true)
                        ShowNumberOnBlip(blip, #currentRace.Checkpoints+1)
    
                        -- Add checkpoint to array
                        table.insert(currentRace.Checkpoints, {blip = blip, coords = coords})
                    end
    
                    CallRefresh()

                    return buttonRef
                end},
                {Name = 'Remove last checkpoint', FuncOnSelected = function(buttonRef)
                    index = #currentRace.Checkpoints

                    if index > 0 then
                        RemoveBlip(currentRace.Checkpoints[index].blip)
                        table.remove(currentRace.Checkpoints, index)

                        CallRefresh()
                    else
                        NotifyPlayerError_client('No checkpoint to remove!')
                    end

                    return buttonRef
                end},
                {Name = ' ', IsUnselectable = true},
                {Name = 'Save race', SubMenu = {
                    MenuTitle = 'Finish and save race?',
                    Sprite = menuDefaultSprite,
                    Buttons = {
                        {Name = 'No', IsBack = true},
                        {Name = 'Yes', FuncOnSelected = function()
                            TriggerServerEvent('ardy_racing:SaveRace', currentRace)
                        end}
                    }
                }},
                {Name = 'Discard race', SubMenu = {
                    MenuTitle = 'Discard all changes?',
                    Sprite = menuDefaultSprite,
                    Buttons = {
                        {Name = 'No', IsBack = true},
                        {Name = 'Yes', FuncOnSelected = function()
                            SetCurrentState(STATE_NONE, nil, false)
                        end}
                    }
                }},
            }
        }
    elseif currentState == STATE_PREPARE then
        menu = 
        {
            MenuTitle = 'Race setup',
            Sprite = menuDefaultSprite,
            Buttons = 
            {
                {Name = 'Public event', NameRight = GetBoolYesNoText(currentRace.IsPublic), FuncOnSelected = function(buttonRef)
                    currentRace.IsPublic = not currentRace.IsPublic

                    buttonRef.NameRight = GetBoolYesNoText(currentRace.IsPublic)
                    return buttonRef 
                end, FuncRefresh = function(buttonRef)
                    buttonRef.NameRight = GetBoolYesNoText(currentRace.IsPublic)
                    return buttonRef
                end},
                {Name = 'Allow slipstream', NameRight = GetBoolYesNoText(currentRace.AllowSlipstream), FuncOnSelected = function(buttonRef)
                    currentRace.AllowSlipstream = not currentRace.AllowSlipstream

                    CallRefresh()
                    buttonRef.NameRight = GetBoolYesNoText(currentRace.AllowSlipstream)
                    return buttonRef 
                end, FuncRefresh = function(buttonRef)
                    buttonRef.NameRight = GetBoolYesNoText(currentRace.AllowSlipstream)
                    return buttonRef
                end},
                -- TODO: doresit validovani progressu, zatim nema cenu to zapinat a vypinat kdyz to nic nedela
                -- {Name = 'Validate progress', NameRight = GetBoolYesNoText(currentRace.ValidateProgress), FuncOnSelected = function(buttonRef)
                --     currentRace.ValidateProgress = not currentRace.ValidateProgress

                --     CallRefresh()
                --     buttonRef.NameRight = GetBoolYesNoText(currentRace.ValidateProgress)
                --     return buttonRef 
                -- end, FuncRefresh = function(buttonRef)
                --     buttonRef.NameRight = GetBoolYesNoText(currentRace.ValidateProgress)
                --     return buttonRef
                -- end},
                {Name = 'Allow exit car', NameRight = GetBoolYesNoText(currentRace.AllowExitCar), FuncOnSelected = function(buttonRef)
                    currentRace.AllowExitCar = not currentRace.AllowExitCar

                    CallRefresh()
                    buttonRef.NameRight = GetBoolYesNoText(currentRace.AllowExitCar)
                    return buttonRef 
                end, FuncRefresh = function(buttonRef)
                    buttonRef.NameRight = GetBoolYesNoText(currentRace.AllowExitCar)
                    return buttonRef
                end},
                {Name = 'Laps', NameRight = GetLapsString(currentRace.Laps), IsTextInput = true, TextInputRequest = 'Enter laps count', TextInputMaxLen = 2, FuncOnTextInput = function(input)
                    input = input:match'^%s*(.*%S)' or ''
                    local laps = tonumber(input)
                    if currentRace.Type ~= RACETYPE_CIRCUIT and currentRace.Type ~= RACETYPE_DRIFTCIRCUIT then
                        NotifyPlayerError_client('Not a circuit!')
                    elseif laps == nil then
                        NotifyPlayerError_client('Invalid number!')
                    else
                        currentRace.Laps = laps
                    end
                end, FuncRefresh = function(buttonRef) 
                    buttonRef.NameRight = GetLapsString(currentRace.Laps)
                    return buttonRef
                end},
                -- {Name = 'DNF timer after leader finish', NameRight = GetTimeZeroNoString(currentRace.EndTimerAfterFirst), IsTextInput = true, TextInputRequest = 'Enter time in seconds, 0 to disable', TextInputMaxLen = 3, FuncOnTextInput = function(input)
                --     input = input:match'^%s*(.*%S)' or ''
                --     local seconds = tonumber(input)
                --     if (seconds == nil) then
                --         NotifyPlayerError_client('Invalid number!')
                --     else
                --         currentRace.EndTimerAfterFirst = seconds
                --     end
                -- end, FuncRefresh = function(buttonRef) 
                --     buttonRef.NameRight = GetTimeZeroNoString(currentRace.EndTimerAfterFirst)
                --     return buttonRef
                -- end},
                {Name = 'Race start in', NameRight = GetTimeZeroNoString(currentRace.StartIn), IsTextInput = true, TextInputRequest = 'Enter time in seconds, minimum is 10', TextInputMaxLen = 4, FuncOnTextInput = function(input)
                    input = input:match'^%s*(.*%S)' or ''
                    local seconds = tonumber(input)
                    if (seconds == nil) then
                        NotifyPlayerError_client('Invalid number!')
                    elseif (seconds < 10) then
                        NotifyPlayerError_client('Minimum is 10 seconds!')
                    else
                        currentRace.StartIn = seconds
                    end
                end, FuncRefresh = function(buttonRef) 
                    buttonRef.NameRight = GetTimeZeroNoString(currentRace.StartIn)
                    return buttonRef
                end},
                {Name = 'Leaderboards enabled', NameRight = GetBoolYesNoText(currentRace.IsRanked), FuncRefresh = function(buttonRef)
                    if 
                        currentRace.AllowSlipstream == false and
                        (currentRace.Type ~= RACETYPE_CIRCUIT or currentRace.Laps == currentRace.OriginalLaps) and
                        currentRace.ValidateProgress == true
                    then
                        currentRace.IsRanked = true
                    else
                        currentRace.IsRanked = false
                    end

                    buttonRef.NameRight = GetBoolYesNoText(currentRace.IsRanked)
                    return buttonRef
                end},
                {Name = ' ', IsUnselectable = true},
                {Name = 'Create event', Icon = 'finish-flag_w256', SubMenu = {
                    MenuTitle = 'Confirm event setup?',
                    Sprite = menuDefaultSprite,
                    Buttons = {
                        {Name = 'No', IsBack = true},
                        {Name = 'Yes', FuncOnSelected = function()
                            TriggerServerEvent('ardy_racing:CreateEvent', currentRace)
                        end}
                    }
                }},
                {Name = 'Cancel', Icon = 'close3_w256', SubMenu = {
                    MenuTitle = 'Cancel race setup?',
                    Sprite = menuDefaultSprite,
                    Buttons = {
                        {Name = 'No', IsBack = true},
                        {Name = 'Yes', FuncOnSelected = function()
                            SetCurrentState(STATE_NONE, nil, false)
                        end}
                    }
                }},
                {Name = ' ', IsUnselectable = true},
                {Name = 'Race name', ExtraLeft = currentRace.Name},
                {Name = 'Race author', ExtraLeft = currentRace.AuthorName},
                {Name = 'Race type', NameRight = GetRaceTypeText(currentRace.Type)},
                {Name = 'Checkpoint count', NameRight = tostring(#currentRace.Checkpoints)}
            }
        }
    elseif currentState == STATE_PREJOIN then
        menu = 
        {
            MenuTitle = 'Race event',
            Sprite = menuDefaultSprite,
            Buttons = 
            {
                {Name = 'Join event', Icon = 'finish-flag_w256', ColorOverride = {200, 150, 0, 150, 100, 0}, FuncOnSelected = function()
                    local player = GetPlayerPed(-1)
                    local position = GetEntityCoords(player)     
                    local proximity = GetDistanceBetweenCoords(position.x, position.y, position.z, currentRace.Checkpoints[1].coords.x, currentRace.Checkpoints[1].coords.y, currentRace.Checkpoints[1].coords.z, true)
                        if currentRace.StartTime < GetNetworkTime() then
                            NotifyPlayerError_client('Race has already started')
                        elseif proximity > (Config.start_radius / 2.0) then
                            NotifyPlayerAlert_client('You are too far away from start')
                        else
                            TriggerServerEvent('ardy_racing:JoinEvent', currentRace)
                        end
                end},
                {Name = 'Set waypoint', Icon = 'target_w256', FuncOnSelected = function()
                    SetWaypointOff()
                    SetNewWaypoint(currentRace.Checkpoints[1].coords.x, currentRace.Checkpoints[1].coords.y)
                end},
                {Name = 'Leaderboards', Icon = 'list_w256', FuncOnSelected = function() 
                    TriggerServerEvent('ardy_racing:GetRaceLeaderboards', currentRace) 
                end},
                {Name = 'Hide menu', Icon = 'hidden_w256', IsHide = true},
                {Name = 'Back to event list', Icon = 'back3_w256', IsNavBack = true, FuncOnSelected = function()
                    SetCurrentState(STATE_AVAILABLEEVENTS, nil, false)
                end},
                {Name = ' ', IsUnselectable = true},
                {Name = 'Race name', ExtraLeft = currentRace.Name},
                {Name = 'Race author', ExtraLeft = currentRace.AuthorName},
                {Name = 'Race type', NameRight = GetRaceTypeText(currentRace.Type)},
                {Name = 'Checkpoint count', NameRight = tostring(#currentRace.Checkpoints)},
                {Name = 'Laps', NameRight = GetLapsString(currentRace.Laps)},
                {Name = 'Registered players ', NameRight = tostring(#currentRace.Players), FuncRefresh = function(buttonRef) 
                    buttonRef.NameRight = tostring(#currentRace.Players)
                    return buttonRef
                end},
                {Name = 'Race starts in ', Icon = 'start_w256', NameRight = tostring(GetStartInSecondsString(currentRace.StartTime)), FuncRefresh = function(buttonRef) 
                    buttonRef.NameRight = tostring(GetStartInSecondsString(currentRace.StartTime))
                    return buttonRef
                end},
                {Name = 'Leaderboards enabled', NameRight = GetBoolYesNoText(currentRace.IsRanked)}
            }
        }
        if Config.enable_teleport_to_race_start == true then
            table.insert(menu.Buttons, 2, 
            {
                Name = 'Teleport to start',
                Icon = 'target_w256',
                FuncOnSelected = function()
                    local player = GetPlayerPed(-1)
                    if IsPedInAnyVehicle(player, false) then
                        local veh = GetVehiclePedIsIn(player, false)
                        SetEntityCoords(veh, currentRace.Checkpoints[1].coords.x, currentRace.Checkpoints[1].coords.y, currentRace.Checkpoints[1].coords.z + 3.0, false, false, false, false)
                    else
                        SetEntityCoords(player, currentRace.Checkpoints[1].coords.x, currentRace.Checkpoints[1].coords.y, currentRace.Checkpoints[1].coords.z + 3.0, false, false, false, false)
                    end
                end
            })
        end
    elseif currentState == STATE_JOINED then
        menu = 
        {
            MenuTitle = 'Race event info',
            Sprite = menuDefaultSprite,
            Buttons = 
            {
                {Name = 'Joined!', Icon = 'confirm_w256', ColorOverride = {0, 200, 0, 0, 150, 0}},
                {Name = 'Leaderboards', Icon = 'list_w256', FuncOnSelected = function() 
                    TriggerServerEvent('ardy_racing:GetRaceLeaderboards', currentRace) 
                end},
                {Name = 'Hide menu', Icon = 'hidden_w256', IsHide = true},
                {Name = 'Leave event', Icon = 'close3_w256', SubMenu = {
                    MenuTitle = 'Really leave event?',
                    Sprite = menuDefaultSprite,
                    Buttons = {
                        {Name = 'No', IsBack = true},
                        {Name = 'Yes', FuncOnSelected = function()
                            TriggerServerEvent('ardy_racing:LeaveEvent', currentRace)
                        end}
                    }
                }},
                {Name = ' ', IsUnselectable = true},
                {Name = 'Race name', ExtraLeft = currentRace.Name},
                {Name = 'Race author', ExtraLeft = currentRace.AuthorName},
                {Name = 'Race type', NameRight = GetRaceTypeText(currentRace.Type)},
                {Name = 'Checkpoint count', NameRight = tostring(#currentRace.Checkpoints)},
                {Name = 'Laps', NameRight = GetLapsString(currentRace.Laps)},
                {Name = 'Registered players ', NameRight = tostring(#currentRace.Players), FuncRefresh = function(buttonRef) 
                    buttonRef.NameRight = tostring(#currentRace.Players)
                    return buttonRef
                end},
                {Name = 'Race starts in ', Icon = 'start_w256', NameRight = tostring(GetStartInSecondsString(currentRace.StartTime)), FuncRefresh = function(buttonRef) 
                    buttonRef.NameRight = tostring(GetStartInSecondsString(currentRace.StartTime))
                    return buttonRef
                end},
                {Name = 'Leaderboards enabled', NameRight = GetBoolYesNoText(currentRace.IsRanked)}
            }
        }

        if currentRace.Type == RACETYPE_DRIFT or currentRace.Type == RACETYPE_DRIFTCIRCUIT then
            table.insert(menu.Buttons, 3, {Name = 'Car drift tires', Icon = 'drift_w256', NameRight = GetBoolTextDriftTyres(driftTyre), FuncOnSelected = function(buttonRef) 
                if gameBuild >= 2189 then
                    if Config.enable_drift_tire_manipultion == true then 
                        local player = GetPlayerPed(-1)
                        
                        if IsPedInAnyVehicle(player, false) then
                            local veh = GetVehiclePedIsIn(player, false)
                            driftTyre = GetDriftTyresEnabledSafe(veh)
    
                            driftTyre = not driftTyre
                            SetDriftTyresEnabled(veh, driftTyre)
                        end
    
                        buttonRef.NameRight = GetBoolTextDriftTyres(driftTyre) 
                        return buttonRef
                    else
                        NotifyPlayerError_client('Server admin has disabled this feature')
                    end
                else
                    NotifyPlayerError_client('Server has unsupported build')
                end
            end,
            FuncRefresh = function(buttonRef)
                buttonRef.NameRight = GetBoolTextDriftTyres(driftTyre) 
                return buttonRef
            end})
        end
    elseif currentState == STATE_RACING then
        menu = 
        {
            MenuTitle = 'Race in progress',
            Sprite = menuDefaultSprite,
            Buttons = 
            {
                {Name = 'Hide menu', Icon = 'hidden_w256', IsHide = true},
                {Name = 'Leave event', Icon = 'close3_w256', SubMenu = {
                    MenuTitle = 'Really leave event?',
                    Sprite = menuDefaultSprite,
                    Buttons = {
                        {Name = 'No', IsBack = true},
                        {Name = 'Yes', FuncOnSelected = function()
                            TriggerServerEvent('ardy_racing:LeaveEvent', currentRace)
                        end}
                    }
                }}
            }
        }
    elseif currentState == STATE_AFTERRACE then
        menu = 
        {
            MenuTitle = 'Event recap',
            Sprite = menuDefaultSprite,
            Buttons = 
            {
                {Name = 'Race name', ExtraLeft = currentRace.Name},
                {Name = 'Race type', NameRight = GetRaceTypeText(currentRace.Type)},
                {Name = 'Leaderboards', Icon = 'list_w256', FuncOnSelected = function() 
                    TriggerServerEvent('ardy_racing:GetRaceLeaderboards', currentRace) 
                end},
                {Name = 'Leave event', Icon = 'close3_w256', SubMenu = {
                    MenuTitle = 'Really leave event?',
                    Sprite = menuDefaultSprite,
                    Buttons = {
                        {Name = 'No', IsBack = true},
                        {Name = 'Yes', FuncOnSelected = function()
                            SetCurrentState(STATE_NONE, nil, false)
                        end}
                    }
                }},
                {Name = ' ', IsUnselectable = true},
            }
        }

        GenerateCurrentRacePlayers(menu)
    elseif currentState == STATE_AVAILABLEEVENTS then
        menu = AvailableEventsMenu()
    end

    if menu ~= nil then
        exports.ardy_easymenu:ShowMenu(GetCurrentResourceName(), menu)
    end
end

function OpenListMenu()
    menu = 
    {
        MenuTitle = raceListTitle,
        Sprite = menuDefaultSprite,
        Buttons = {}
    }

    table.insert(menu.Buttons, {Name = 'Back', Icon = 'back3_w256', IsNavBack = true, FuncOnSelected = function()
        SetCurrentState(STATE_NONE, nil, false)
    end})

    if raceList ~= nil and #raceList > 0 then
        table.sort(raceList, function(left, right) return left.Name:upper() < right.Name:upper() end)

        local authorSubmenus = {}
        local raceTypeSubmenus = {}

        for _, race in pairs(raceList) do
            local raceBtn = 
            {
                Name = race.Name, SubMenu = GenerateInspectSubMenu(race), 
                FuncOnSelected = function()
                    currentState = STATE_INSPECT
                    SetWaypointOff()
                    SetCurrentRace(race)
                end
            }
    
            local raceTypeText = GetRaceTypeText(race.Type)

            table.insert(menu.Buttons, raceBtn)

            if authorSubmenus[race.AuthorName] == nil then
                authorSubmenus[race.AuthorName] = 
                {
                    MenuTitle = race.AuthorName,
                    Sprite = menuDefaultSprite,
                    Buttons = {{Name = 'Back', Icon = 'back3_w256', IsBack = true}}
                }
            end

            table.insert(authorSubmenus[race.AuthorName].Buttons, raceBtn)

            if raceTypeSubmenus[raceTypeText] == nil then
                raceTypeSubmenus[raceTypeText] = 
                {
                    MenuTitle = raceTypeText,
                    Sprite = menuDefaultSprite,
                    Buttons = {{Name = 'Back', Icon = 'back3_w256', IsBack = true}}
                }
            end

            table.insert(raceTypeSubmenus[raceTypeText].Buttons, raceBtn)
        end

        local authorSubmenu = {
            MenuTitle = 'By author',
            Sprite = menuDefaultSprite,
            Buttons = {{Name = 'Back', Icon = 'back3_w256', IsBack = true}}
        }

        for key, sm in pairs(authorSubmenus) do
            table.insert(authorSubmenu.Buttons, {Name = key, SubMenu = sm})
        end

        local raceTypeSubmenu = {
            MenuTitle = 'By race type',
            Sprite = menuDefaultSprite,
            Buttons = {{Name = 'Back', Icon = 'back3_w256', IsBack = true}}
        }

        for key, sm in pairs(raceTypeSubmenus) do
            table.insert(raceTypeSubmenu.Buttons, {Name = key, SubMenu = sm})
        end

        table.insert(menu.Buttons, 2, {Name = 'Filter: race type', Icon = 'filter_w256', SubMenu = raceTypeSubmenu})
        table.insert(menu.Buttons, 2, {Name = 'Filter: author', Icon = 'filter_w256', SubMenu = authorSubmenu})
    end


    if menu ~= nil then
        exports.ardy_easymenu:ShowMenu(GetCurrentResourceName(), menu)
    end
end

function GenerateInspectSubMenu(race)
    local menu = 
        {
            MenuTitle = 'Race details',
            Sprite = menuDefaultSprite,
            Buttons = 
            {
                {Name = 'Create event', Icon = 'finish-flag_w256', FuncOnSelected = function() 
                    SetCurrentState(STATE_PREPARE, race, true) 
                end},
                {Name = 'Leaderboards', Icon = 'list_w256', FuncOnSelected = function() 
                    TriggerServerEvent('ardy_racing:GetRaceLeaderboards', race) 
                end},
                {Name = 'Back', Icon = 'back3_w256', IsBack = true, FuncOnSelected = function()
                    if currentRace ~= nil then 
                        race.IsVerified = currentRace.IsVerified
                    end
                    currentState = STATE_NONE
                    SetWaypointOff()
                    SetCurrentRace(nil)
                end},
                {Name = ' ', IsUnselectable = true},
                {Name = 'Race name', ExtraLeft = race.Name},
                {Name = 'Race author', ExtraLeft = race.AuthorName},
                {Name = 'Race type', NameRight = GetRaceTypeText(race.Type)},
                {Name = 'Checkpoint count', NameRight = tostring(#race.Checkpoints)},
                {Name = 'Laps', NameRight = GetLapsString(race.Laps)},
                {Name = 'Listed publicly [Editable]', NameRight = GetBoolYesNoTextInverted(race.IsUnlisted), FuncOnSelected = function(buttonRef)
                    if currentRace ~= nil then
                        if currentRace.IsUnlisted == nil then
                            currentRace.IsUnlisted = false
                        end
                        TriggerServerEvent("ardy_racing:SetRaceUnlisted", not currentRace.IsUnlisted == true, currentRace)
                        buttonRef.NameRight = GetBoolYesNoTextInverted(currentRace.IsUnlisted) --currentRace... sketchy but should work
                    end
                    return buttonRef 
                end, FuncRefresh = function(buttonRef)
                    if currentRace ~= nil then
                        buttonRef.NameRight = GetBoolYesNoTextInverted(currentRace.IsUnlisted)
                    end
                    return buttonRef
                end},
                {Name = ' ', IsUnselectable = true},
                {Name = 'Delete Race', SubMenu = {
                    MenuTitle = 'Really delete this race?',
                    Sprite = menuDefaultSprite,
                    Buttons = {
                        {Name = 'No', IsBack = true},
                        {Name = 'Yes', FuncOnSelected = function() TriggerServerEvent('ardy_racing:DeleteRace', race) end}
                    }
                }}
            }
        }

        if isAdmin == true then
            table.insert(menu.Buttons, #menu.Buttons, {Name = '[Admin] Verified', NameRight = GetBoolYesNoText(race.IsVerified), FuncOnSelected = function(buttonRef)
                if currentRace ~= nil then
                    TriggerServerEvent("ardy_racing:VerifyRace", not currentRace.IsVerified == true, currentRace, adminKey)
                    buttonRef.NameRight = GetBoolYesNoText(currentRace.IsVerified) --currentRace... sketchy but should work
                end
                return buttonRef 
            end, FuncRefresh = function(buttonRef)
                if currentRace ~= nil then
                    buttonRef.NameRight = GetBoolYesNoText(currentRace.IsVerified)
                end
                return buttonRef
            end})

            local nameBtn = nil
            for _, b in pairs(menu.Buttons) do
                if b.Name == 'Race name' then
                    nameBtn = b
                    break
                end
            end

            if nameBtn ~= nil then
                nameBtn.IsTextInput = true
                nameBtn.TextInputRequest = '[Admin] Enter new name'
                nameBtn.TextInputMaxLen = 30
                nameBtn.FuncOnTextInput = function(input)
                    input = input:match'^%s*(.*%S)' or ''
                    if input ~= nil and input ~= '' then
                        TriggerServerEvent("ardy_racing:Admin_renameRace", adminKey, race.Name, input)
                    end
                end
            end
        end

    return menu
end

function AvailableEventsMenu()
    menu = 
    {
        MenuTitle = 'Starting events',
        Sprite = menuDefaultSprite,
        Buttons = {}
    }

    table.insert(menu.Buttons, {Name = 'Back', Icon = 'back3_w256', IsNavBack = true, FuncOnSelected = function()
        SetCurrentState(STATE_NONE, nil, false)
    end})

    if availableEvents ~= nil and #availableEvents > 0 then
        table.sort(availableEvents, function(left, right) return left.StartTime < right.StartTime end)

        for _, race in pairs(availableEvents) do
            if race.IsPublic == true then
                table.insert(menu.Buttons, {Name = race.Name, NameRight = GetStartInSecondsString(race.StartTime), FuncOnSelected = function()
                    SetCurrentState(STATE_PREJOIN, race, true)
                end, FuncRefresh = function(buttonRef) 
                    buttonRef.NameRight = GetStartInSecondsString(race.StartTime)
                    return buttonRef
                end})
            end
        end
    end

    return menu
end

function GenerateCurrentRacePlayers(menu)
    if currentRace == nil or currentRace.Players == nil or #currentRace.Players <= 0 then
        return
    end

    table.sort(currentRace.Players, function(left, right) 
        return left.Position < right.Position
    end)

    for index, p in pairs(currentRace.Players) do
        local btn = {
            Name = '#' .. tostring(p.Position) .. ' ' .. p.Name, 
            Icon = 'user_w256',
            NameRight = GetFinishedPlayerRaceScore(p, currentRace.Type)
        }

        table.insert(menu.Buttons, btn)
    end

end


RegisterCommand('aracing', OpenMenu, false)