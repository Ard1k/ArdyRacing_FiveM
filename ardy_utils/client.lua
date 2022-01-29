-- Draw 3D text at coordinates
function Draw3DText(x, y, z, text, scale, r, g, b)
    -- Check if coords are visible and get 2D screen coords
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        -- Calculate text scale to use
        local dist = GetDistanceBetweenCoords(GetGameplayCamCoords(), x, y, z, 1)
        local scale = 1.8*(1/dist)*(1/GetGameplayCamFov())*100*scale

        -- Draw text on screen
        SetTextScale(scale, scale)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(r, g, b, 255)
        SetTextDropShadow(0, 0, 0, 0,255)
        SetTextDropShadow()
        SetTextEdge(4, 0, 0, 0, 255)
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

-- Draw 2D text on screen
function Draw2DText(x, y, text, scale, center, r, g, b)
    -- Draw text on screen
    SetTextFont(4)
    SetTextProportional(7)
    SetTextScale(scale, scale)
    SetTextColour(r, g, b, 255)
    SetTextDropShadow(0, 0, 0, 0,255)
    SetTextDropShadow()
    SetTextEdge(4, 0, 0, 0, 255)
    SetTextOutline()
    SetTextEntry("STRING")
    SetTextCentre(center)
    AddTextComponentString(text)
    DrawText(x, y)
end

-- Draw 2D text on screen
function Draw2DTextRight(x, y, text, scale, r, g, b)
    -- Draw text on screen
    SetTextFont(4)
    SetTextProportional(7)
    SetTextScale(scale, scale)
    SetTextColour(r, g, b, 255)
    SetTextDropShadow(0, 0, 0, 0,255)
    SetTextDropShadow()
    SetTextEdge(4, 0, 0, 0, 255)
    SetTextOutline()
    SetTextEntry("STRING")
    SetTextWrap(0, x)
    SetTextJustification(2)
    AddTextComponentString(text)
    DrawText(x, y)
end

function SplitByChunk(text, chunkSize)
    local s = {}
    for i=1, #text, chunkSize do
        s[#s+1] = text:sub(i,i+chunkSize - 1)
    end
    return s
end

function NotifyError(message)
    CustomNotification("~r~~h~Error~h~~s~: " .. message);
end

function NotifySuccess(message)
    CustomNotification("~g~~h~Success~h~~s~: " .. message);
end

function NotifyAlert(message)
    CustomNotification("~y~~h~Alert~h~~s~: " .. message);
end

function CustomNotification(message)
    SetNotificationTextEntry("CELL_EMAIL_BCON")
    local stringArray = SplitByChunk(message, 99)

    for _, s in pairs(stringArray) do
        AddTextComponentSubstringPlayerName(tostring(s))
    end

    DrawNotification(true, true)
end

RegisterNetEvent("ardy_utils:NotifyError")
AddEventHandler("ardy_utils:NotifyError", function(msg)
    NotifyError(msg)
end)

RegisterNetEvent("ardy_utils:NotifyAlert")
AddEventHandler("ardy_utils:NotifyAlert", function(msg)
    NotifyAlert(msg)
end)

RegisterNetEvent("ardy_utils:NotifySuccess")
AddEventHandler("ardy_utils:NotifySuccess", function(msg)
    NotifySuccess(msg)
end)