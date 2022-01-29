honkEnabled = GetResourceKvpInt('cnf_honkEnabled') == 1

Citizen.CreateThread(function()
    while true do
        if honkEnabled == true then
            local player = GetPlayerPed(-1)
            if IsPedInAnyVehicle(player, false) then
                local veh = GetVehiclePedIsIn(player, false)
                if GetPedInVehicleSeat(veh, -1) == player then
                    if IsDisabledControlJustPressed(0, 86) then
                        SetVehicleLights(veh, 2)
                        SetVehicleLightMultiplier(veh, 12.0)
                    elseif IsDisabledControlJustReleased(0, 86) then
                        SetVehicleLights(veh, 0)
                        SetVehicleLightMultiplier(veh, 1.0)
                    end
                end
            end
            Citizen.Wait(0)
        else
            Citizen.Wait(1000)
        end
    end
end)