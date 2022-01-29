hudData = nil
local hudLeftIndex = 0
local hudRightIndex = 0

--[[
    hud_left_pos_x = 0.2,
    hud_left_pos_y = 0.2,

    hud_right_pos_x = 0.95,
    hud_right_pos_y = 0.05,
]]--

-- update hud data
Citizen.CreateThread(function() 
    while true do
        if (currentRace ~= nil and currentState == STATE_RACING) then
            hudData = GetRaceHudData()

            Citizen.Wait(50)
        else
            Citizen.Wait(1000)
        end
    end
end)

-- update hud data
Citizen.CreateThread(function() 
    while true do
        if currentRace ~= nil and currentState == STATE_RACING and hudData ~= nil then
            if currentRace.Type == RACETYPE_CIRCUIT then
                exports.ardy_utils:Draw2DText(Config.hud_left_pos_x, Config.hud_left_pos_y + 0.00, '~y~RaceTime~s~ ' .. hudData['RaceTime'], 0.8, false, 255, 255, 255)
                exports.ardy_utils:Draw2DText(Config.hud_left_pos_x, Config.hud_left_pos_y + 0.04, '~y~LapTime~s~ ' .. hudData['LapTime'], 0.5, false, 255, 255, 255)
                exports.ardy_utils:Draw2DText(Config.hud_left_pos_x, Config.hud_left_pos_y + 0.065, '~g~BestLap~s~ ' .. hudData['BestLapTime'], 0.5, false, 255, 255, 255)

                exports.ardy_utils:Draw2DTextRight(Config.hud_right_pos_x, Config.hud_right_pos_y + 0.00, '~y~Position~s~ ' .. hudData['RacePos'], 1.0, 255, 255, 255)
                exports.ardy_utils:Draw2DTextRight(Config.hud_right_pos_x, Config.hud_right_pos_y + 0.05, '~y~Checkpoint~s~ ' .. hudData['Checkpoint'] .. '  ~y~Lap~s~ ' .. hudData['Laps'], 0.6, 255, 255, 255)
            elseif currentRace.Type == RACETYPE_DRIFTCIRCUIT then
                exports.ardy_utils:Draw2DText(Config.hud_left_pos_x, Config.hud_left_pos_y + 0.00, '~y~Score~s~ ' .. hudData['DriftScore'], 0.8, false, 255, 255, 255)
                exports.ardy_utils:Draw2DText(Config.hud_left_pos_x, Config.hud_left_pos_y + 0.04, '~y~LastLap~s~ ' .. hudData['DriftScoreLastLap'], 0.5, false, 255, 255, 255)
                exports.ardy_utils:Draw2DText(Config.hud_left_pos_x, Config.hud_left_pos_y + 0.065, '~g~BestLap~s~ ' .. hudData['DriftScoreBestLap'], 0.5, false, 255, 255, 255)
                exports.ardy_utils:Draw2DText(Config.hud_left_pos_x, Config.hud_left_pos_y + 0.090, '~y~RaceTime~s~ ' .. hudData['RaceTime'], 0.5, false, 255, 255, 255)

                exports.ardy_utils:Draw2DTextRight(Config.hud_right_pos_x, Config.hud_right_pos_y + 0.00, '~y~Position~s~ ' .. hudData['RacePos'], 1.0, 255, 255, 255)
                exports.ardy_utils:Draw2DTextRight(Config.hud_right_pos_x, Config.hud_right_pos_y + 0.05, '~y~Checkpoint~s~ ' .. hudData['Checkpoint'] .. '  ~y~Lap~s~ ' .. hudData['Laps'], 0.6, 255, 255, 255)
            elseif currentRace.Type == RACETYPE_SPRINT then
                exports.ardy_utils:Draw2DText(Config.hud_left_pos_x, Config.hud_left_pos_y + 0.00, '~y~RaceTime~s~ ' .. hudData['RaceTime'], 0.8, false, 255, 255, 255)

                exports.ardy_utils:Draw2DTextRight(Config.hud_right_pos_x, Config.hud_right_pos_y + 0.00, '~y~Position~s~ ' .. hudData['RacePos'], 1.0, 255, 255, 255)
                exports.ardy_utils:Draw2DTextRight(Config.hud_right_pos_x, Config.hud_right_pos_y + 0.05, '~y~Checkpoint~s~ ' .. hudData['Checkpoint'], 0.6, 255, 255, 255)
            elseif currentRace.Type == RACETYPE_DRIFT then
                exports.ardy_utils:Draw2DText(Config.hud_left_pos_x, Config.hud_left_pos_y + 0.00, '~y~Score~s~ ' .. hudData['DriftScore'], 0.8, false, 255, 255, 255)
                exports.ardy_utils:Draw2DText(Config.hud_left_pos_x, Config.hud_left_pos_y + 0.04, '~y~RaceTime~s~ ' .. hudData['RaceTime'], 0.5, false, 255, 255, 255)

                exports.ardy_utils:Draw2DTextRight(Config.hud_right_pos_x, Config.hud_right_pos_y + 0.00, '~y~Position~s~ ' .. hudData['RacePos'], 1.0, 255, 255, 255)
                exports.ardy_utils:Draw2DTextRight(Config.hud_right_pos_x, Config.hud_right_pos_y + 0.05, '~y~Checkpoint~s~ ' .. hudData['Checkpoint'], 0.6, 255, 255, 255)
            end
            Citizen.Wait(0)
        else
            Citizen.Wait(1000)
        end
    end
end)