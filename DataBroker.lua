local ADDON_NAME, Internal = ...
local External = _G[ADDON_NAME]
local L = Internal.L

local ldb = LibStub("LibDataBroker-1.1")
local ldbi = LibStub("LibDBIcon-1.0")

local dataBroker = ldb:NewDataObject(ADDON_NAME, {
    type = "launcher",
    label = ADDON_NAME,
    icon = 3586266,
    OnClick = function(clickedframe, button)
        if button == "LeftButton" then
            if IsShiftKeyDown() then
                External.RunAction(BtWTodoDataBroker.shiftLeftClickAction)
            else
                External.RunAction(BtWTodoDataBroker.leftClickAction)
            end
        else
            External.RunAction(BtWTodoDataBroker.rightClickAction)
        end
    end,
    OnEnter = function(button)
        local show = not BtWTodoDataBroker.hideTooltip
        if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then
            show = BtWTodoConfigPanel.MinimapTooltipButton:GetChecked()
        elseif SettingsPanel and SettingsPanel:IsShown() then
            show = BtWTodoConfigPanel.MinimapTooltipButton:GetChecked()
        end
        if show then
            BtWTodoTooltipFrame:ClearAllPoints()
            BtWTodoTooltipFrame:SetPoint("TOPRIGHT", button, "TOPLEFT")
            BtWTodoTooltipFrame:Show()
        end
    end,
    OnLeave = function()
        BtWTodoTooltipFrame:Hide()
    end,
})

local function ADDON_LOADED(_, addon)
    if addon == ADDON_NAME then
        if not BtWTodoDataBroker then
            BtWTodoDataBroker = {}
        end

        -- defaults
        if not BtWTodoDataBroker.leftClickAction then BtWTodoDataBroker.leftClickAction = "toggleWindow:main" end
        if not BtWTodoDataBroker.shiftLeftClickAction then BtWTodoDataBroker.shiftLeftClickAction = "toggleWindow:small" end
        if not BtWTodoDataBroker.rightClickAction then BtWTodoDataBroker.rightClickAction = "openConfig" end

        ldbi:Register(ADDON_NAME, dataBroker, BtWTodoDataBroker)
        ldbi:Refresh(ADDON_NAME)

        Internal.UnregisterEvent("ADDON_LOADED", ADDON_LOADED)
    end
end
Internal.RegisterEvent("ADDON_LOADED", ADDON_LOADED)