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
                External.ToggleSmallFrame()
            else
                External.ToggleMainFrame()
            end
        else
            External.OpenConfiguration()
        end
    end,
    OnEnter = function(button)
        BtWTodoTooltipFrame:ClearAllPoints()
        BtWTodoTooltipFrame:SetPoint("TOPRIGHT", button, "TOPLEFT")
        BtWTodoTooltipFrame:Show()
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

        ldbi:Register(ADDON_NAME, dataBroker, BtWTodoDataBroker)

        Internal.UnregisterEvent("ADDON_LOADED", ADDON_LOADED)
    end
end
Internal.RegisterEvent("ADDON_LOADED", ADDON_LOADED)