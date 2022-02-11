local IsHidden = true;
local CurrentMenu = nil;
local ResourceNameMenu = nil;

-- Main Loop
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if not IsHidden and CurrentMenu ~= nil then
            UpdateSelection() -- musi byt pred renderem
            RenderMenu()
        end
    end
end
)

function CheckCurrentMenu()
    if CurrentMenu == nil then
        return
    end

    if CurrentMenu.SelectedIndex == nil or CurrentMenu.SelectedIndex < 1 then
        CurrentMenu.SelectedIndex = 1
    end

    if CurrentMenu.SelectedIndexVisible == nil or CurrentMenu.SelectedIndexVisible < 0 then
        CurrentMenu.SelectedIndexVisible = 0
    end

    --for i = 1, i <= CurrentMenu.Buttons, 1 do
        
    --end
end

function RenderMenu()
    if CurrentMenu == nil then
        return
    end

    local screen_w, screen_h = GetActiveScreenResolution()
    local htow = screen_h/screen_w
    local wtoh = screen_w/screen_h

    local xOffset = 0.7
    local xLenght = 0.15
    local xExtraLenght = 0.11

    local yOffset = 0.25
	local yHeight = 0.03
    local spacing = 0.000

    local textScale = 0.36 --0.34
    local textYOffset = textScale/28.0
    local textMarginName = 0.004
    local textMarginNameRight = xLenght * (2.0/3.0)
    local textMarginExtraLeft = textMarginName
    local textMarginExtraRight = xExtraLenght * (2.0/3.0)
    local textMarginMenuTitle = textMarginName

    local iconScaleFactor = 0.75

    local indexMin = CurrentMenu.SelectedIndex - 1 - (CurrentMenu.SelectedIndexVisible);
	local indexMax = CurrentMenu.SelectedIndex - 1 + (Config.max_menuitems_count - 1 - CurrentMenu.SelectedIndexVisible);

    if not HasStreamedTextureDictLoaded('menu_textures') then
        RequestStreamedTextureDict('menu_textures', true) --fuck the wait, might be just white for few frames
    end

    if CurrentMenu.Sprite ~= nil then
        if not HasStreamedTextureDictLoaded(CurrentMenu.Sprite.TextureDict) then
            RequestStreamedTextureDict(CurrentMenu.Sprite.TextureDict, true) --fuck the wait, might be just white for few frames
        end
        if CurrentMenu.Sprite.X == nil then CurrentMenu.Sprite.X = 1.0 end
        if CurrentMenu.Sprite.Y == nil then CurrentMenu.Sprite.Y = 1.0 end
        local ytox = CurrentMenu.Sprite.Y/CurrentMenu.Sprite.X
        DrawSprite(CurrentMenu.Sprite.TextureDict, CurrentMenu.Sprite.TextureName, xOffset, yOffset - spacing/2 - (xLenght * ytox * wtoh / 2.0) - yHeight/2.0, xLenght, xLenght * ytox * wtoh, 0, 255, 255, 255, 255)
    end

	if CurrentMenu.MenuTitle ~= nil then
        local extraYOffset = 0.0
        local scaleModifier = 1.0
        if CurrentMenu.Sprite == nil then
		    SetTextColour(0, 0, 0, 255)
        else
            SetTextColour(255, 255, 255, 255)
            scaleModifier = 1.2
            extraYOffset = 0.004
        end
	    SetTextScale(textScale * scaleModifier, textScale * scaleModifier)
		SetTextEntry("STRING")
		AddTextComponentString("~h~" .. CurrentMenu.MenuTitle)
		DrawText(xOffset - xLenght/2.0 + textMarginMenuTitle, (yOffset + (yHeight * -1) - (textYOffset * scaleModifier) - extraYOffset))
		
        if CurrentMenu.Sprite == nil then
            DrawRect(xOffset, yOffset + (yHeight * -1), xLenght, yHeight - spacing, 255, 255, 255, 200)
        end
    end

	if indexMin + 1 > 1 then
        --DrawRect(xOffset - (((yHeight + spacing) / 2.0) * htow + xLenght / 2.0), (yOffset + yHeight * 0), (yHeight - spacing) * htow, yHeight - spacing, 255, 255, 255, 199)
        DrawSprite('menu_textures', 'arrow_b256', xOffset - (((yHeight + spacing) / 2.0) * htow + xLenght / 2.0), (yOffset + yHeight * 0), (yHeight - spacing) * htow, yHeight - spacing, 180.0, 255, 255, 255, 150)
    end

	if indexMax + 1 < #CurrentMenu.Buttons then
        --DrawRect(xOffset - (((yHeight + spacing) / 2.0) * htow + xLenght / 2.0), (yOffset + yHeight * (Config.max_menuitems_count - 1)), (yHeight - spacing) * htow, yHeight - spacing, 255, 255, 255, 199)
        DrawSprite('menu_textures', 'arrow_b256', xOffset - (((yHeight + spacing) / 2.0) * htow + xLenght / 2.0), (yOffset + yHeight * (Config.max_menuitems_count - 1)), (yHeight - spacing) * htow, yHeight - spacing, 0.0, 255, 255, 255, 150)
    end

	for i = 1, #CurrentMenu.Buttons, 1 do
		if (i - 1) >= indexMin and (i - 1) <= indexMax then
			local boxColor = nil

			if CurrentMenu.Buttons[i].Active then
                if CurrentMenu.Buttons[i].ColorOverride ~= nil then
                    boxColor = {CurrentMenu.Buttons[i].ColorOverride[1], CurrentMenu.Buttons[i].ColorOverride[2], CurrentMenu.Buttons[i].ColorOverride[3], 233}
				elseif CurrentMenu.Buttons[i].ColorAsUnavailable ~= nil and CurrentMenu.Buttons[i].ColorAsUnavailable then
					boxColor = { 60, 20, 20, 233 }
				else
					boxColor = { 13, 11, 10, 233 }
                   end
			else
                local alphaColor = 230
                if CurrentMenu.Buttons[i].IsUnselectable == true then
                    alphaColor = 0
                end

                if CurrentMenu.Buttons[i].ColorOverride ~= nil then
                    boxColor = {CurrentMenu.Buttons[i].ColorOverride[4], CurrentMenu.Buttons[i].ColorOverride[5], CurrentMenu.Buttons[i].ColorOverride[6], alphaColor}
				elseif CurrentMenu.Buttons[i].ColorAsUnavailable ~= nil and CurrentMenu.Buttons[i].ColorAsUnavailable then
					boxColor = { 120, 45, 45, alphaColor }
				else
					boxColor = { 45, 45, 45, alphaColor }
                end
            end

            DrawRect(xOffset, yOffset + (yHeight * (i - 1 - indexMin)), xLenght, yHeight - spacing, boxColor[1], boxColor[2], boxColor[3], boxColor[4])

			if CurrentMenu.Buttons[i].ExtraLeft ~= nil or CurrentMenu.Buttons[i].ExtraRight ~= nil then
				DrawRect(xOffset + (xLenght + xExtraLenght)/2.0 + spacing, yOffset + (yHeight * (i - 1 - indexMin)), xExtraLenght, yHeight - spacing, 255, 255, 255, 199)
            end

            local iconOffset = 0.0
            if CurrentMenu.Buttons[i].Icon ~= nil then
                local iconScale = iconScaleFactor
                if CurrentMenu.Buttons[i].IconScale ~= nil then iconScale = CurrentMenu.Buttons[i].IconScale end
                DrawSprite('menu_textures', CurrentMenu.Buttons[i].Icon, xOffset + (((yHeight - spacing) / 2.0) * htow) - (xLenght / 2.0), (yOffset + yHeight * (i - 1 - indexMin)), (yHeight - spacing) * iconScale * htow, (yHeight - spacing) * iconScale, 0.0, 255, 255, 255, 200)
                iconOffset = (yHeight - spacing) * htow - textMarginName
            end
			

			if CurrentMenu.Buttons[i].Name ~= nil or CurrentMenu.Buttons[i].Active == true then
                SetTextFont(4);
				SetTextScale(textScale, textScale)
				SetTextColour(255, 255, 255, 255)
				SetTextEntry("STRING")
                local stringSelected = ''
                local stringName = ''
                if CurrentMenu.Buttons[i].Active then
                    stringSelected = ' ' 
				end
                if CurrentMenu.Buttons[i].Name ~= nil then
                    stringName = CurrentMenu.Buttons[i].Name
                end
                AddTextComponentString(stringSelected .. stringName)
				DrawText(xOffset - xLenght/2.0 + iconOffset + textMarginName, (yOffset + (yHeight * (i - 1 - indexMin)) - textYOffset))
            end

			if CurrentMenu.Buttons[i].NameRight ~= nil then
				SetTextFont(4)
				SetTextScale(textScale, textScale)
				SetTextColour(255, 255, 255, 255)
				SetTextEntry("STRING")
				AddTextComponentString(CurrentMenu.Buttons[i].NameRight)
				DrawText(xOffset - xLenght/2.0 + textMarginNameRight, (yOffset + (yHeight * (i - 1 - indexMin)) - textYOffset))
            end

			if CurrentMenu.Buttons[i].ExtraLeft ~= nil then
				SetTextFont(4)
				SetTextScale(textScale, textScale)
				SetTextColour(11, 11, 11, 255)
				SetTextEntry("STRING")
				AddTextComponentString(CurrentMenu.Buttons[i].ExtraLeft)
				DrawText(xOffset + xLenght/2.0 + spacing + textMarginExtraLeft, (yOffset + (yHeight * (i - 1 - indexMin)) - textYOffset))
            end

			if CurrentMenu.Buttons[i].ExtraRight ~= nil then
				SetTextFont(4)
				SetTextScale(textScale, textScale)
				SetTextColour(11, 11, 11, 255)
				SetTextEntry("STRING")
				AddTextComponentString(CurrentMenu.Buttons[i].ExtraRight)
				DrawText(xOffset + xLenght/2.0 + spacing + textMarginExtraRight, (yOffset + (yHeight * (i - 1 - indexMin)) - textYOffset))
            end
        end
    end
end

function UpdateSelection()
    if IsHidden then
        return
    end

    DisableControlAction(0, Config.nav_back_key, true)
    DisableControlAction(0, Config.nav_hide_key, true)

    if IsDisabledControlJustPressed(1, Config.nav_hide_key) then
        -- disable hide key for 0.5s after menu is hidden
        Citizen.CreateThread(function() 
            local time = 0
            while time < 0.5 do
                DisableControlAction(0, Config.nav_hide_key, true)
                time = time + GetFrameTime()
                Citizen.Wait(0)
            end
        end)

        IsHidden = true
        return
    end

    local autoPressSelect = false
    if IsDisabledControlJustPressed(1, Config.nav_back_key) then
        local foundBackKey = false
        
        for _, btn in pairs(CurrentMenu.Buttons) do
            if btn.IsBack == true or btn.IsNavBack == true then
                foundBackKey = true
                break
            end
        end

        if foundBackKey == true then
            repeat
                if CurrentMenu.SelectedIndex < #CurrentMenu.Buttons then
                    CurrentMenu.SelectedIndex = CurrentMenu.SelectedIndex + 1
                    if CurrentMenu.SelectedIndexVisible < Config.max_menuitems_count - 1 then
                    CurrentMenu.SelectedIndexVisible = CurrentMenu.SelectedIndexVisible + 1
                    end
                else
                    CurrentMenu.SelectedIndex = 1
                    CurrentMenu.SelectedIndexVisible = 0
                end
            until CurrentMenu.Buttons[CurrentMenu.SelectedIndex].IsBack == true or CurrentMenu.Buttons[CurrentMenu.SelectedIndex].IsNavBack == true

            autoPressSelect = true
        end
    end

    if IsControlJustPressed(1, Config.nav_down_key) then --down
        PlaySound(l_208, "NAV_UP_DOWN", "HUD_MINI_GAME_SOUNDSET", 0, 0, 1)
        repeat
            if CurrentMenu.SelectedIndex < #CurrentMenu.Buttons then
                CurrentMenu.SelectedIndex = CurrentMenu.SelectedIndex + 1
                if CurrentMenu.SelectedIndexVisible < Config.max_menuitems_count - 1 then
                CurrentMenu.SelectedIndexVisible = CurrentMenu.SelectedIndexVisible + 1
                end
            else
                CurrentMenu.SelectedIndex = 1
                CurrentMenu.SelectedIndexVisible = 0
            end

            if CurrentMenu.Buttons[CurrentMenu.SelectedIndex].FuncOnHover ~= nil then
                CurrentMenu.Buttons[CurrentMenu.SelectedIndex].FuncOnHover()
            end
        until CurrentMenu.Buttons[CurrentMenu.SelectedIndex].IsUnselectable ~= true 
    elseif IsControlJustPressed(1, Config.nav_up_key) then --up
        PlaySound(l_208, "NAV_UP_DOWN", "HUD_MINI_GAME_SOUNDSET", 0, 0, 1);
        repeat
            if CurrentMenu.SelectedIndex > 1 then
                CurrentMenu.SelectedIndex = CurrentMenu.SelectedIndex - 1
                if CurrentMenu.SelectedIndexVisible > 0 then
                    CurrentMenu.SelectedIndexVisible = CurrentMenu.SelectedIndexVisible - 1
                end
            else
                CurrentMenu.SelectedIndex = #CurrentMenu.Buttons
                if #CurrentMenu.Buttons <= Config.max_menuitems_count then
                    CurrentMenu.SelectedIndexVisible = #CurrentMenu.Buttons - 1
                else 
                    CurrentMenu.SelectedIndexVisible = Config.max_menuitems_count - 1
                end
            end

            if CurrentMenu.Buttons[CurrentMenu.SelectedIndex].FuncOnHover ~= nil then
                CurrentMenu.Buttons[CurrentMenu.SelectedIndex].FuncOnHover()
            end
        until CurrentMenu.Buttons[CurrentMenu.SelectedIndex].IsUnselectable ~= true
    elseif autoPressSelect == true or IsControlJustPressed(1, Config.nav_select_key) or (Config.nav_select2_key > 0 and IsControlJustPressed(1, Config.nav_select2_key)) then
        PlaySound(-1, "SELECT", "HUD_MINI_GAME_SOUNDSET", 0, 0, 1);
        local isBack = CurrentMenu.Buttons[CurrentMenu.SelectedIndex].IsBack == true
        local isHide = CurrentMenu.Buttons[CurrentMenu.SelectedIndex].IsHide == true
        local funcOnSelected = nil
        local currentButton = CurrentMenu.Buttons[CurrentMenu.SelectedIndex]

        if CurrentMenu.Buttons[CurrentMenu.SelectedIndex].FuncOnSelected ~= nil then
            funcOnSelected = CurrentMenu.Buttons[CurrentMenu.SelectedIndex].FuncOnSelected
        end


        if CurrentMenu.Buttons[CurrentMenu.SelectedIndex].IsTextInput then
            iRequest = 'Enter text'
            iPrefill = ''
            iMaxLen = 60

            if CurrentMenu.Buttons[CurrentMenu.SelectedIndex].TextInputRequest ~= nil then
                iRequest = CurrentMenu.Buttons[CurrentMenu.SelectedIndex].TextInputRequest
            end

            if CurrentMenu.Buttons[CurrentMenu.SelectedIndex].TextInputPrefill ~= nil then
                iPrefill = CurrentMenu.Buttons[CurrentMenu.SelectedIndex].TextInputPrefill
                if iPrefill == 'NameRight' then
                    iPrefill = CurrentMenu.Buttons[CurrentMenu.SelectedIndex].NameRight
                elseif iPrefill == 'ExtraLeft' then
                    iPrefill = CurrentMenu.Buttons[CurrentMenu.SelectedIndex].ExtraLeft
                end
            end

            if CurrentMenu.Buttons[CurrentMenu.SelectedIndex].TextInputMaxLen ~= nil then
                iMaxLen = CurrentMenu.Buttons[CurrentMenu.SelectedIndex].TextInputMaxLen
            end

            iRequest = iRequest .. ' [' .. 'max length: ' .. iMaxLen .. ']'

            AddTextEntry('FMMC_KEY_TIP1', iRequest) --Sets the Text above the typing field in the black square
	        DisplayOnscreenKeyboard(1, "FMMC_KEY_TIP1", "", iPrefill, "", "", "", iMaxLen) --Actually calls the Keyboard Input
	        blockinput = true --Blocks new input while typing if **blockinput** is used

	        while UpdateOnscreenKeyboard() ~= 1 and UpdateOnscreenKeyboard() ~= 2 do --While typing is not aborted and not finished, this loop waits
		        Citizen.Wait(0)
	        end
		
	        if UpdateOnscreenKeyboard() == 1 then
		        local result = GetOnscreenKeyboardResult() --Gets the result of the typing
		        Citizen.Wait(50) --Little Time Delay, so the Keyboard won't open again if you press enter to finish the typing
		        blockinput = false --This unblocks new Input when typing is done
		        if CurrentMenu.Buttons[CurrentMenu.SelectedIndex].FuncOnTextInput ~= nil then
                    CurrentMenu.Buttons[CurrentMenu.SelectedIndex].FuncOnTextInput(result)
                    Refresh()
                end
	        else
		        Citizen.Wait(50) --Little Time Delay, so the Keyboard won't open again if you press enter to finish the typing
		        blockinput = false --This unblocks new Input when typing is done
	        end
        end

        if CurrentMenu.Buttons[CurrentMenu.SelectedIndex].SubMenu ~= nil then
            local prevMenu = CurrentMenu
            CurrentMenu = CurrentMenu.Buttons[CurrentMenu.SelectedIndex].SubMenu
            CurrentMenu.PreviousMenu = prevMenu
            CheckCurrentMenu()
            Refresh()
        end

        if funcOnSelected ~= nil then
            local res = funcOnSelected(currentButton)
            UpdateMenuItem(currentButton, res)
        end

        if isHide then
            IsHidden = true
        end

        if isBack then
            BackOrClose()
            return
        end
    end

    for i = 1, #CurrentMenu.Buttons, 1 do
        if i == CurrentMenu.SelectedIndex then
            CurrentMenu.Buttons[i].Active = true
        else
            CurrentMenu.Buttons[i].Active = false
        end
    end
end

function UpdateMenuItem(item, update)
    if update == nil then return end

    item.Name = update.Name
    item.NameRight = update.NameRight
    item.ExtraLeft = update.ExtraLeft
    item.ExtraRight = update.ExtraRight
end

function ShowMenu(resourceName, menu)
    CurrentMenu = menu
    ResourceNameMenu = resourceName
    CheckCurrentMenu()
    IsHidden = false
end

function ShowMenuAsSubMenu(resourceName, menu)
    if ResourceNameMenu ~= nil and ResourceNameMenu ~= resourceName then
        return
    end

    if ResourceNameMenu == nil then
        ResourceNameMenu = resourceName
    end

    if CurrentMenu == nil then
        CurrentMenu = menu
        CheckCurrentMenu()
        IsHidden = false
        return
    end

    local lastMenu = CurrentMenu
    CurrentMenu = menu
    CurrentMenu.PreviousMenu = lastMenu
    CheckCurrentMenu()
    IsHidden = false
end

function CloseMenu()
    CurrentMenu = nil
    ResourceNameMenu = nil
    IsHidden = true
end

function ToggleMenuVisible(resourceName)
    if CurrentMenu ~= nil and ResourceNameMenu == resourceName then
        IsHidden = not IsHidden
        Refresh()
        return true
    end

    return false
end

function HideMenuIfNotHidden(resourceName)
    if CurrentMenu ~= nil and ResourceNameMenu == resourceName and not IsHidden then
        IsHidden = true
        return true
    end

    return false
end

function IsAnyMenuVisible()
    return not IsHidden
end

function Refresh()
    if IsHidden then return end

    for i = 1, #CurrentMenu.Buttons, 1 do
        if CurrentMenu.Buttons[i].FuncRefresh ~= nil then
            local func = CurrentMenu.Buttons[i].FuncRefresh
            local res = func(CurrentMenu.Buttons[i])
            UpdateMenuItem(CurrentMenu.Buttons[i], res) 
        end
    end
end

function BackOrClose()
    if IsHidden or CurrentMenu == nil then
        return
    end

    if CurrentMenu.PreviousMenu ~= nil then
        CurrentMenu = CurrentMenu.PreviousMenu
        Refresh()
    else
        CurrentMenu = nil
        ResourceNameMenu = nil
        IsHidden = true
    end
end