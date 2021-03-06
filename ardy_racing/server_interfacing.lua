----- DATA LAYER ------
ServerData = nil;
DataLocked = false; -- !!! used in server.lua, take care when converting to SQL

LeaderboardData = nil;
LeaderboardLocked = false;

local sqlEnabled = (Config.use_sql == true and MySQL ~= nil)
if sqlEnabled == false then
    local stringData = GetResourceKvpString('data');
    if stringData ~= nil then
        ServerData = json.decode(stringData)
    else
        ServerData = {}
        ServerData.Races = {}
    end

    local stringLeaderboardData = GetResourceKvpString('leaderBoardData');
    if stringLeaderboardData ~= nil then
        LeaderboardData = json.decode(stringLeaderboardData)
    else
        LeaderboardData = {}
        LeaderboardData.Races = {}
    end
else
    ServerData = {}
    ServerData.Races = {}

    LeaderboardData = {}
    LeaderboardData.Races = {}
end

Citizen.CreateThread(function()
    if sqlEnabled == true then
        MySQL.query.await(' CREATE TABLE IF NOT EXISTS aracing_races (`NAME` CHAR(30) NOT NULL, `DATA` LONGTEXT, PRIMARY KEY(`NAME`)) ', {})
        MySQL.query.await(' CREATE TABLE IF NOT EXISTS aracing_leaderboards (`NAME` CHAR(30) NOT NULL, `DATA` LONGTEXT, PRIMARY KEY(`NAME`)) ', {})

        if Config.migrate_nonsql_data == true then
            local stringData = GetResourceKvpString('data');
            if stringData ~= nil then
                local serverDataMigrate = json.decode(stringData)
                for _, race in pairs(serverDataMigrate.Races) do
                    MySQL.query(' INSERT INTO aracing_races (`NAME`, `DATA`) VALUES (:name, :data) ON DUPLICATE KEY UPDATE data = :data ', {name = race.Name, data = json.encode(race)})
                end

                print(tostring(#serverDataMigrate.Races) .. ' races migrated')
            end

            local stringLeaderboardData = GetResourceKvpString('leaderBoardData');
            if stringLeaderboardData ~= nil then
                local leaderboardDataMigrate = json.decode(stringLeaderboardData)
                for key, race in pairs(leaderboardDataMigrate.Races) do
                    MySQL.query(' INSERT INTO aracing_leaderboards (`NAME`, `DATA`) VALUES (:name, :data) ON DUPLICATE KEY UPDATE data = :data ', {name = key, data = json.encode(race)})
                end
            end

            print('!!! A-racing storage migration to sql finished. Please disable the migration parameter in config now!')
        end

        MySQL.query(' SELECT `NAME`, `DATA` FROM aracing_races ', {}, function(result)
            if result then
                for _, row in pairs(result) do
                    if row.NAME ~= nil then
                        local temp = json.decode(row.DATA)
                        table.insert(ServerData.Races, temp)
                    end
                end
            end
        end)

        MySQL.query(' SELECT `NAME`, `DATA` FROM aracing_leaderboards ', {}, function(result)
            if result then
                for _, row in pairs(result) do
                    if row.NAME ~= nil then
                        local temp = json.decode(row.DATA)
                        LeaderboardData.Races[row.NAME] = json.decode(row.DATA)
                    end
                end
            end
        end)
    end
end)

Citizen.CreateThread(function()
    local i = 0
    while sqlEnabled == false do
        Citizen.Wait(1000)
        i = i + 1

        if i > 300 then
            SetResourceKvp('data', json.encode(ServerData))
            SetResourceKvp('leaderBoardData', json.encode(LeaderboardData))
            i = 0
        end
    end
end)

function GetLeaderboardPosition(raceName, raceType, record)
    while LeaderboardLocked == true do
        Citizen.Wait(0)
    end

    LeaderboardLocked = true

    if LeaderboardData.Races[raceName] == nil then
        LeaderboardData.Races[raceName] = {}
        LeaderboardData.Races[raceName]['IsHigherBetter'] = (raceType == RACETYPE_DRIFT or raceType == RACETYPE_DRIFTCIRCUIT)
    end

    if LeaderboardData.Races[raceName][ALLCAR] == nil then
        LeaderboardData.Races[raceName][ALLCAR] = {}
    end

    local carHashString = tostring(record.CarHash)

    if LeaderboardData.Races[raceName][carHashString] == nil then
        LeaderboardData.Races[raceName][carHashString] = {}
    end
    local isHigherBetter = LeaderboardData.Races[raceName]['IsHigherBetter']

    table.sort(LeaderboardData.Races[raceName][ALLCAR], function(left, right) return (isHigherBetter == true and left.Record > right.Record) or (isHigherBetter == false and left.Record < right.Record) end)
    table.sort(LeaderboardData.Races[raceName][carHashString], function(left, right) return (isHigherBetter == true and left.Record > right.Record) or (isHigherBetter == false and left.Record < right.Record) end)

    local indexOverall = -1
    local overallFound = false
    local overallImproved = false
    local indexCar = -1
    local carFound = false
    local carImproved = false
    
    --ALLCAR
    for index, k in pairs(LeaderboardData.Races[raceName][ALLCAR]) do
        if k.AuthorName == record.AuthorName and k.CarHash == record.CarHash then
            overallFound = true
            if (isHigherBetter == true and record.Record > k.Record) or (isHigherBetter == false and record.Record < k.Record) then
                overallImproved = true
                k.Record = record.Record
                break
            end
        end
    end

    if overallFound == true then
        if overallImproved then
            table.sort(LeaderboardData.Races[raceName][ALLCAR], function(left, right) return (isHigherBetter == true and left.Record > right.Record) or (isHigherBetter == false and left.Record < right.Record) end)
            for index, k in pairs(LeaderboardData.Races[raceName][ALLCAR]) do
                if k.AuthorName == record.AuthorName and k.CarHash == record.CarHash then
                    indexOverall = index
                    break
                end
            end
        end
    else
        for index, k in pairs(LeaderboardData.Races[raceName][ALLCAR]) do
            if (isHigherBetter == true and record.Record > k.Record) or (isHigherBetter == false and record.Record < k.Record) then
                indexOverall = index
                break
            end
        end
        
        if (indexOverall == -1) then
            indexOverall = #LeaderboardData.Races[raceName][ALLCAR] + 1
        end
        
        if indexOverall <= 20 then
            table.insert(LeaderboardData.Races[raceName][ALLCAR], indexOverall, record)
            if #LeaderboardData.Races[raceName][ALLCAR] > 20 then
                table.remove(LeaderboardData.Races[raceName][ALLCAR], #LeaderboardData.Races[raceName][ALLCAR])
            end
        else
            indexOverall = -1
        end
    end
    
    --CAR SPECIFIC
    for index, k in pairs(LeaderboardData.Races[raceName][carHashString]) do
        if k.AuthorName == record.AuthorName then
            carFound = true
            if (isHigherBetter == true and record.Record > k.Record) or (isHigherBetter == false and record.Record < k.Record) then
                carImproved = true
                k.Record = record.Record
                break
            end
        end
    end

    if carFound == true then
        if carImproved then
            table.sort(LeaderboardData.Races[raceName][carHashString], function(left, right) return (isHigherBetter == true and left.Record > right.Record) or (isHigherBetter == false and left.Record < right.Record) end)
            for index, k in pairs(LeaderboardData.Races[raceName][carHashString]) do
                if k.AuthorName == record.AuthorName then
                    indexCar = index
                    break
                end
            end
        end
    else
        for index, k in pairs(LeaderboardData.Races[raceName][carHashString]) do
            if (isHigherBetter == true and record.Record > k.Record) or (isHigherBetter == false and record.Record < k.Record) then
                indexCar = index
                break
            end
        end
        
        if (indexCar == -1) then
            indexCar = #LeaderboardData.Races[raceName][carHashString] + 1
        end
        
        if indexCar <= 20 then
            table.insert(LeaderboardData.Races[raceName][carHashString], indexCar, record)
            if #LeaderboardData.Races[raceName][carHashString] > 20 then
                table.remove(LeaderboardData.Races[raceName][carHashString], #LeaderboardData.Races[raceName][carHashString])
            end
        else
            indexCar = -1
        end
    end
    if sqlEnabled == true then
        MySQL.query(' INSERT INTO aracing_leaderboards (`NAME`, `DATA`) VALUES (:name, :data) ON DUPLICATE KEY UPDATE data = :data ', {name = raceName, data = json.encode(LeaderboardData.Races[raceName])})
    end
    LeaderboardLocked = false

    return { Overall = indexOverall, Car = indexCar}
end

function RemoveVehicleHashFromLeaderboards(hash)
    while LeaderboardLocked == true do
        Citizen.Wait(0)
    end

    local stringHash = tostring(hash)
    print(stringHash)
    LeaderboardLocked = true
    for key,race in pairs(LeaderboardData.Races) do
        if race[stringHash] ~= nil then
            race[stringHash] = nil
        end

        if race[ALLCAR] ~= nil then
            for j = #race[ALLCAR], 1, -1 do
                if race[ALLCAR][j].CarHash == hash then
                    table.remove(race[ALLCAR], j)
                end
            end
        end

        if sqlEnabled == true then
            MySQL.query(' INSERT INTO aracing_leaderboards (`NAME`, `DATA`) VALUES (:name, :data) ON DUPLICATE KEY UPDATE data = :data ', {name = key, data = json.encode(race)}) --celkem zabijak, ale je to admin funkce :D
        end
    end
    LeaderboardLocked = false
end

function GetRaceLeaderboards(raceName, raceType)
    if LeaderboardData.Races[raceName] == nil then
        LeaderboardData.Races[raceName] = {}
        LeaderboardData.Races[raceName]['IsHigherBetter'] = (raceType == RACETYPE_DRIFT or raceType == RACETYPE_DRIFTCIRCUIT)
    end

    return LeaderboardData.Races[raceName]
end

function DeleteLeaderboards(raceName)
    while LeaderboardLocked == true do
        Citizen.Wait(0)
    end

    LeaderboardLocked = true
    LeaderboardData.Races[raceName] = nil
    if sqlEnabled == true then
        MySQL.query(' DELETE FROM aracing_leaderboards WHERE name = :name ', {name = raceName})
    end
    LeaderboardLocked = false
end

function DoesRaceWithNameExist(name)
    for _, race in pairs(ServerData.Races) do
        if race.Name == name then
            return true
        end
    end

    return false
end

function GetRacesByAuthorUID(pUID)
    local races = {}

    for _, race in pairs(ServerData.Races) do
        if race.AuthorUID == pUID then
            table.insert(races, race)
        end
    end

    return races
end

function GetAllRaces()
    --return ServerData.Races
    local races = {}

    for _, race in pairs(ServerData.Races) do
        if race.IsUnlisted ~= true then
            table.insert(races, race)
        end
    end

    return races
end

function GetAllUnlistedRaces()
    local races = {}

    for _, race in pairs(ServerData.Races) do
        if race.IsUnlisted == true then
            table.insert(races, race)
        end
    end

    return races
end

function GetVerifiedRaces()
    local races = {}

    for _, race in pairs(ServerData.Races) do
        if race.IsVerified == true then
            table.insert(races, race)
        end
    end

    return races
end

function GetRaceByName(raceName)
    for _, race in pairs(ServerData.Races) do
        if race.Name == raceName then
            return race
        end
    end

    return nil
end

function AddRace(race)
    table.insert(ServerData.Races, race)
    if sqlEnabled == true then
        MySQL.query(' INSERT INTO aracing_races (`NAME`, `DATA`) VALUES (:name, :data) ON DUPLICATE KEY UPDATE data = :data ', {name = race.Name, data = json.encode(race)})
    end
end

function DeleteRace(raceToDelete)
    for index, race in pairs(ServerData.Races) do
        if race.Name == raceToDelete.Name then
            table.remove(ServerData.Races, index)
            if sqlEnabled == true then
                MySQL.query(' DELETE FROM aracing_races WHERE name = :name ', {name = race.Name})
            end
            break
        end
    end
end

function SetRaceVerified(raceName, verified)
    for index, race in pairs(ServerData.Races) do
        if race.Name == raceName then
            race.IsVerified = verified
            if sqlEnabled == true then
                MySQL.query(' INSERT INTO aracing_races (`NAME`, `DATA`) VALUES (:name, :data) ON DUPLICATE KEY UPDATE data = :data ', {name = race.Name, data = json.encode(race)})
            end
            return true
        end
    end

    return false
end

function SetRaceUnlisted(raceName, isUnlisted)
    for index, race in pairs(ServerData.Races) do
        if race.Name == raceName then
            race.IsUnlisted = isUnlisted
            if sqlEnabled == true then
                MySQL.query(' INSERT INTO aracing_races (`NAME`, `DATA`) VALUES (:name, :data) ON DUPLICATE KEY UPDATE data = :data ', {name = race.Name, data = json.encode(race)})
            end
            return true
        end
    end

    return false
end

function RenameRace(oldName, newName)
    while LeaderboardLocked == true or DataLocked == true do
        Citizen.Wait(0)
    end

    LeaderboardLocked = true 
    DataLocked = true

    for index, race in pairs(ServerData.Races) do
        if race.Name == oldName then
            race.Name = newName
            if sqlEnabled == true then
                MySQL.query(' INSERT INTO aracing_races (`NAME`, `DATA`) VALUES (:name, :data) ON DUPLICATE KEY UPDATE data = :data ', {name = race.Name, data = json.encode(race)})
                MySQL.query(' DELETE FROM aracing_races WHERE name = :name ', {name = oldName})
            end
            break
        end
    end

    if LeaderboardData.Races[oldName] ~= nil then
        if sqlEnabled == true then
            MySQL.query(' INSERT INTO aracing_leaderboards (`NAME`, `DATA`) VALUES (:name, :data) ON DUPLICATE KEY UPDATE data = :data ', {name = newName, data = json.encode(LeaderboardData.Races[oldName])})
            MySQL.query(' DELETE FROM aracing_leaderboards WHERE name = :name ', {name = oldName})
        end
        LeaderboardData.Races[newName] = LeaderboardData.Races[oldName]
        LeaderboardData.Races[oldName] = nil
    end

    LeaderboardLocked = false 
    DataLocked = false
end

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
      return
    end

    if sqlEnabled == false then
        SetResourceKvp('data', json.encode(ServerData))
        SetResourceKvp('leaderBoardData', json.encode(LeaderboardData))
    end
end)
  

----- END OF DATA LAYER ------

function NotifyPlayerAlert_server(source, msg)
	TriggerClientEvent('ardy_utils:NotifyAlert', source, msg)
end

function NotifyPlayerError_server(source, msg)
	TriggerClientEvent('ardy_utils:NotifyError', source, msg)
end

function NotifyPlayerSuccess_server(source, msg)
	TriggerClientEvent('ardy_utils:NotifySuccess', source, msg)
end

function GetPlayerUID(source)
    return string.sub(GetPlayerIdentifier(source, 0), 9, -1)
end

function GetPlayerAuthorName(source)
	return GetPlayerName(source)
end