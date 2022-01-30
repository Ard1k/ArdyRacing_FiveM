function GetBoolTextDriftTyres(boolVar)
    if gameBuild < 2189 then
        return 'OLDBUILD'
    end
    
    local player = GetPlayerPed(-1)
                
    if not IsPedInAnyVehicle(player, false) then
        return 'NOVEH'
    elseif boolVar == true then
        return 'ON'
    else
        return 'OFF'
    end
end

function GetBoolText(boolVar)
    if boolVar == true then
        return 'ON'
    else
        return 'OFF'
    end
end

function GetBoolInt(boolVar)
    if boolVar == true then
        return 1
    else
        return 0
    end
end

function GetDriftTyresEnabledSafe(veh)
    local res = GetDriftTyresEnabled(veh)
    res = tostring(res)

    if res == 'true' or res == '1' then
        return true
    else
        return false
    end
end

function GetBoolYesNoText(boolVar)
    if boolVar == true then
        return 'YES'
    else
        return 'NO'
    end
end

function GetBoolYesNoTextInverted(boolVar)
    if boolVar ~= true then -- Nil returns yes, this saves mi some logic outside
        return 'YES'
    else
        return 'NO'
    end
end

function GetLapsString(laps)
    if laps == nil then
        return 'N/A'
    else
        return tostring(laps)
    end
end

function GetTimeZeroNoString(number)
    if number == nil or number == 0 then
        return 'NO'
    else
        return tostring(number) .. 's'
    end
end

function GetRaceTypeText(intVar)
    if intVar == RACETYPE_SPRINT then
        return 'SPRINT'
    elseif intVar == RACETYPE_CIRCUIT then
        return 'CIRCUIT'
    elseif intVar == RACETYPE_DRIFT then
        return 'DRIFT SPRINT'
    elseif intVar == RACETYPE_DRIFTCIRCUIT then
        return 'DRIFT CIRCUIT'
    end

    return '???'
end

function CallRefresh()
    exports.ardy_easymenu:Refresh()
end

function GetStartInSecondsString(startTime)
    local currentTime = GetNetworkTime()
    if currentTime > startTime then
        return 'STARTED'
    end
    return tostring(math.ceil((startTime - currentTime)/1000.0)) .. 's'
end

function CreateRaceBlip(coords, number)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipColour(blip, Config.blip_color)
    SetBlipAsShortRange(blip, true)
    ShowNumberOnBlip(blip, number)

    return blip
end

function RaceLapFinished(currentTime)
    if currentRace == nil or currentRace.CurrentLap == nil then
        return
    end

    local lapTime = currentTime - currentRace.LastLapStartTime

    if currentRace.BestLapTime == nil or currentRace.BestLapTime > lapTime then
        currentRace.BestLapTime = lapTime
    end

    currentRace.LastLapStartTime = currentTime

    if IsRaceDriftType() == true then
        DriftFinished()
    end

    if currentRace.Type == RACETYPE_DRIFTCIRCUIT then
        if currentRace.BestDriftLap == nil or currentRace.BestDriftLap < currentRace.DriftScore then
            currentRace.BestDriftLap = currentRace.DriftScore
        end

        currentRace.LastDriftLap = currentRace.DriftScore
        currentRace.DriftScore = 0
    end
end

function RaceFinished(currentTime)
    if currentRace == nil then
        return
    end

    if IsRaceDriftType() == true then
        DriftFinished()
    end

    currentRace.TotalTime = (currentTime - currentRace.StartTime) - Config.race_start_freezetime
end

function GetRaceHudData()
    if currentRace == nil or currentRace.StartTime == nil then
        return nil
    end
    local checkpointNum = currentRace.CheckpointCurrent - 1
    if checkpointNum <= 0 then
        checkpointNum = checkpointNum + #currentRace.Checkpoints
    end

    local checkpoint = tostring(checkpointNum) .. ' / ' .. tostring(#currentRace.Checkpoints)
    local currentTime = GetNetworkTime()
    local raceCleanTime = FormatTimeCustom((currentTime - currentRace.StartTime) - Config.race_start_freezetime)
    local raceCurrentLapTime = '---'
    local bestLapTime = '---'
    local laps = '---'
    if IsRaceCircuitType() == true then
        raceCurrentLapTime = FormatTimeCustom(currentTime - currentRace.LastLapStartTime)
        if currentRace.BestLapTime ~= nil then
            bestLapTime = FormatTimeCustom(currentRace.BestLapTime)
        else
            bestLapTime = '---'
        end

        laps = tostring(currentRace.CurrentLap) .. ' / ' .. tostring(currentRace.Laps)
    end
    local myPlayer = nil
    local myServerId = GetPlayerServerId(PlayerId())
    for _, p in pairs(currentRace.Players) do
        if p.Id == myServerId then
            myPlayer = p
            break
        end
    end
    local myPos = 1
    if myPlayer ~= nil and myPlayer.Position ~= nil then
        myPos = myPlayer.Position
    end
    local racePosition = tostring(myPos) .. ' / ' .. tostring(#currentRace.Players)
    local driftScore = '---'
    local driftScoreBestLap = '---'
    local driftScoreLastLap = '---'
    if IsRaceDriftType() == true then
        driftScore = tostring(currentRace.DriftScore) .. ' pts'
        if currentRace.Type == RACETYPE_DRIFTCIRCUIT then
            if currentRace.BestDriftLap ~= nil then
                driftScoreBestLap = tostring(currentRace.BestDriftLap) .. ' pts'
            else
                driftScoreBestLap = '---'
            end

            if currentRace.LastDriftLap ~= nil then
                driftScoreLastLap = tostring(currentRace.LastDriftLap) .. ' pts'
            else
                driftScoreLastLap = '---'
            end
        end
    end

    return {
        RaceTime = raceCleanTime,
        LapTime = raceCurrentLapTime,
        BestLapTime = bestLapTime,
        RacePos = racePosition,
        Checkpoint = checkpoint,
        Laps = laps,
        DriftScore = driftScore,
        DriftScoreBestLap = driftScoreBestLap,
        DriftScoreLastLap = driftScoreLastLap
    }
end

function IsRaceDriftType()
    if currentRace ~= nil and (currentRace.Type == RACETYPE_DRIFT or currentRace.Type == RACETYPE_DRIFTCIRCUIT) then
        return true
    else
        return false
    end
end

function IsRaceCircuitType()
    if currentRace ~= nil and (currentRace.Type == RACETYPE_CIRCUIT or currentRace.Type == RACETYPE_DRIFTCIRCUIT) then
        return true
    else
        return false
    end
end

function FormatLeaderboardScore(raceType, score)
    if raceType == RACETYPE_SPRINT or raceType == RACETYPE_CIRCUIT then
        return FormatTimeCustom(score)
    else
        return tostring(score) .. ' pts'
    end
end

function FormatTimeCustom(time)
    if time == nil then
        return '---'
    end

    local prefix = ''
    if time < 0 then
        prefix = '-'
    end

    time = math.abs(time)
    local ms = math.floor((time % 1000)/10)
    local temp = math.floor(time / 1000)
    local h = math.floor(temp / 3600) --3600 = 1h
    temp = temp - (h * 3600)
    local m = math.floor(temp / 60)
    local s = temp - (m * 60)

    local result = prefix
    if h > 0 then
        result = result .. string.format("%02d", h) .. ':'
    end

    if m > 0 then
        result = result .. string.format("%02d", m) .. ':'
    end

    result = result .. string.format("%02d", s) .. '.' .. string.format("%02d", ms)
    return result
end

function GetFinishedPlayerRaceScore(player, raceType)
    if player.DNF == true then
        return 'DNF'
    end
    if player.HasFinished ~= true then
        return 'RACING...'
    end

    if raceType == RACETYPE_SPRINT or raceType == RACETYPE_CIRCUIT then
        return FormatTimeCustom(player.TotalTime)
    elseif raceType == RACETYPE_DRIFT then
        return tostring(player.DriftScore) .. ' pts'
    elseif raceType == RACETYPE_DRIFTCIRCUIT then
        return tostring(player.BestLapDrift) .. ' pts'
    end
end