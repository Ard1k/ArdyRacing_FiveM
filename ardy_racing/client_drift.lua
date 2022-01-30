local driftTotalScore = 0.0
local angle = 0.0
local angleFactor = 0.0
local speed = 0.0
local speedFactor = 0.0
drift = {}
driftTyre = false
local lastVeh = nil
driftEnabled = GetResourceKvpInt('cnf_driftEnabled') == 1
checkpointDistance = 0.0
checkpointMinDistance = math.huge



local flashText_display_ms = 1000
local flashText_displayed_for = 0
local flashTextColor = {r = 255, g = 255, b = 255}
flashText = nil

function ResetDrift()
    drift.duration = 0.0
    drift.points = 0.0
    drift.nodriftduration = 0.0
    drift.multipler = 1.0
end

ResetDrift()

function UpdateCheckpointDistance(newDist)
    if checkpointMinDistance > newDist then
        checkpointMinDistance = newDist
    end

    checkpointDistance = newDist
end

function CheckpointPassed()
    checkpointMinDistance = math.huge
end

function DriftFinished()
    if drift.duration < Config.drift_min_duration then
        ResetDrift()
    else
        local resPoints = math.floor((drift.points / 1000) * drift.multipler)
        DriftResultText('+'.. tostring(resPoints), 0, 255, 0)
        driftTotalScore = driftTotalScore + resPoints
        if currentRace ~= nil and currentState == STATE_RACING and (currentRace.Type == RACETYPE_DRIFT or currentRace.Type == RACETYPE_DRIFTCIRCUIT) then 
            if currentRace.DriftScore == nil then
                currentRace.DriftScore = 0
            end
            currentRace.DriftScore = currentRace.DriftScore + resPoints
        end
        ResetDrift()
    end
end

function DriftFailed(reason)
    DriftResultText(tostring(reason), 255, 0, 0)
    ResetDrift()
end

function DriftResultText(text, r, g, b)
    flashText = text
    flashTextColor.r = r
    flashTextColor.g = g
    flashTextColor.b = b
    flashText_displayed_for = 0
end

-- Drift tires refresh
Citizen.CreateThread(function()
    if gameBuild >= 2189 then
        while true do
            local player = GetPlayerPed(-1)
            if IsPedInAnyVehicle(player, false) then
                local veh = GetVehiclePedIsIn(player, false)
                if lastVeh == nil or veh ~= lastVeh then
                    driftTyre = GetDriftTyresEnabledSafe(veh)
                    lastVeh = veh
                    CallRefresh()
                end
            else
                driftTyre = false
            end

            Citizen.Wait(0)
        end
    end
end)

--Drift UI
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        if driftEnabled then
            if (drift.duration >= Config.drift_min_duration) then
                local coordsMe = GetEntityCoords(GetPlayerPed(-1), false)
                local colorMod = math.floor((drift.nodriftduration / Config.drift_end_after_ms) * 255)
                exports.ardy_utils:Draw3DText(coordsMe['x'], coordsMe['y'], coordsMe['z']+1.30, 'Drift: ' .. string.format("%.0f", math.floor(drift.points/1000)) .. ' x ' .. drift.multipler, 2, 255 - colorMod, 255 - colorMod, 255 - colorMod)
            end

            if debugMode then
                exports.ardy_utils:Draw2DText(Config.debug_x, Config.debug_y + 0.02, 'Score: ' .. string.format("%.0f", driftTotalScore), 0.3, false, 255, 255, 255)
                exports.ardy_utils:Draw2DText(Config.debug_x, Config.debug_y + 0.04, 'DriftTires: ' .. GetBoolTextDriftTyres(driftTyre), 0.3, false, 255, 255, 255)
                exports.ardy_utils:Draw2DText(Config.debug_x, Config.debug_y + 0.20, 'Angle: ' .. string.format("%.0f", angle), 0.3, false, 255, 255, 255)
                exports.ardy_utils:Draw2DText(Config.debug_x, Config.debug_y + 0.22, 'Speed: ' .. string.format("%.0f", speed), 0.3, false, 255, 255, 255)
                exports.ardy_utils:Draw2DText(Config.debug_x, Config.debug_y + 0.24, 'Checkpoint dist: ' .. string.format("%.0f", checkpointDistance), 0.3, false, 255, 255, 255)
            end
        end
    end
end)

--Flash text drawing
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        if flashText_displayed_for < flashText_display_ms and flashText ~= nil then
            local frameTime = GetFrameTime() * 1000
            flashText_displayed_for = flashText_displayed_for + frameTime
            local percentTime = 1 - flashText_displayed_for / flashText_display_ms
            exports.ardy_utils:Draw2DText(0.5, 0.3, flashText, 0.5 + 1 * percentTime, true, flashTextColor.r, flashTextColor.g, flashTextColor.b)
        end
    end
end)

-- Oceneni aktualniho driftu
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        if driftEnabled then 

            local frameTime = GetFrameTime() * 1000

            local player = GetPlayerPed(-1)
            if IsPedInAnyVehicle(player, false) then
                local veh = GetVehiclePedIsIn(player, false)
                local vehPos = GetEntityCoords(veh)
                local fwdVector = GetEntityForwardVector(veh);
                local movementVector = GetEntitySpeedVector(veh, false);

                if debugMode == true then
                    DrawLine(vehPos.x, vehPos.y, vehPos.z + 1.1, vehPos.x + fwdVector.x, vehPos.y + fwdVector.y, vehPos.z + 1.1, 255, 0, 0, 255)
                    DrawLine(vehPos.x, vehPos.y, vehPos.z + 1.1, vehPos.x + movementVector.x, vehPos.y + movementVector.y, vehPos.z + 1.1, 0, 255, 0, 255)
                end

                if currentRace ~= nil and currentState == STATE_RACING and (checkpointDistance - checkpointMinDistance) > Config.drift_max_reverse_dist then 
                    currentRace.DriftScore = 0
                    ResetDrift()
                    DriftResultText('DONT CHEAT', 255, 200, 0)
                end

                speed = GetEntitySpeed(veh)
                speedFactor = speed
                if speedFactor > Config.drift_speed_cap then speedFactor = Config.drift_speed_cap end
                angle = math.acos((fwdVector.x * movementVector.x + fwdVector.y * movementVector.y) / (math.sqrt(fwdVector.x^2+fwdVector.y^2) * math.sqrt(movementVector.x^2+movementVector.y^2))) * 180/math.pi
                angleFactor = angle
                if angleFactor > Config.drift_angle_max then angleFactor = Config.drift_angle_max end

                local isDrifting = speed > Config.drift_min_speed and angle > Config.drift_angle_min

                if not isDrifting then
                    drift.nodriftduration = drift.nodriftduration + frameTime

                    if drift.nodriftduration > Config.drift_end_after_ms then 
                        DriftFinished() 
                    end
                else
                    drift.nodriftduration = 0
                    if drift.multipler == nil or drift.multipler < Config.drift_multipler_cap then drift.multipler = 1 + math.floor(drift.duration/1000) * 0.2
                    elseif drift.multipler > Config.drift_multipler_cap then drift.multipler = Config.drift_multipler_cap end
                    drift.points = drift.points + ((angleFactor * (speedFactor/Config.drift_speed_cap) + (speedFactor * Config.drift_effect_speedfactor)) * Config.drift_effect_mult * (frameTime / 1))
                    drift.duration = drift.duration + frameTime
                end

                local isOverturn = angle > Config.drift_overturn_angle
                if isOverturn and drift.duration > Config.drift_min_duration then
                    DriftFailed('OVERTURN')
                end
            elseif drift.points > 0 then
                ResetDrift()
            end

            if not IsPedInAnyVehicle(player, false) then -- DEBUG, fuj
                driftTotalScore = 0
            end
        end 
    end
end)