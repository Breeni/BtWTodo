local ADDON_NAME, Internal = ...
local External = _G[ADDON_NAME]
local L = Internal.L

local ldbi = LibStub("LibDBIcon-1.0")

SLASH_BTWTODO1 = "/btwtodo"
SlashCmdList["BTWTODO"] = function(msg)
    if msg == "minimap" then
        if InterfaceOptionsFrame:IsShown() then
            BtWTodoConfigPanel.MinimapIconButton:Click()
        else
            local icon = ldbi:GetMinimapButton(ADDON_NAME)

            BtWTodoDataBroker.hide = not BtWTodoDataBroker.hide
            if BtWTodoDataBroker.hide then
                icon:Hide()
            else
                if not icon then
                    ldbi:Show(ADDON_NAME)
                else
                    icon:Show()
                end
            end
        end
    elseif msg == "small" then
        External.ToggleSmallFrame()
    elseif msg == "main" or msg == "" then
        External.ToggleMainFrame()
    else
        print(L[ [[BtWTodo usage:
/btwtodo [main]: Toggle main frame
/btwtodo minimap: Toggle minimap icon
/btwtodo small: Toggle small frame
/btwtodo usage: Show this message
]] ])
    end
end