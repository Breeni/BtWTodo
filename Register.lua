--[[
    Register custom functions, to-dos, categories, and lists for all WoW variants
]]

local ADDON_NAME, Internal = ...
local External = _G[ADDON_NAME]
local L = Internal.L

-- DST doesnt effect daily/weekly/halfweekly resets so these should always be accurate
local SECONDS_PER_HOUR = 60 * 60
local SECONDS_PER_WEEK = 60 * 60 * 24 * 7
local SECONDS_PER_HALF_WEEK = 60 * 60 * 24 * 3.5

function Internal.IsBeforeHalfWeeklyReset()
    local nextHalfWeeklyReset = Internal.GetNextWeeklyResetTimestamp() - SECONDS_PER_HALF_WEEK
    return nextHalfWeeklyReset > GetServerTime();
end
Internal.RegisterCustomStateFunction("IsBeforeHalfWeeklyReset", Internal.IsBeforeHalfWeeklyReset)
Internal.RegisterCustomStateFunction("GetHalfWeeklyCountdown", function ()
    local nextHalfWeeklyReset = Internal.GetNextWeeklyResetTimestamp() - SECONDS_PER_HALF_WEEK
    local timestamp = GetServerTime()
    if nextHalfWeeklyReset < timestamp then
        return Internal.GetNextWeeklyResetTimestamp() - GetServerTime(), true
    else
        return nextHalfWeeklyReset - GetServerTime(), false
    end
end)

External.RegisterCategories({
    { id = "btwtodo:character", name = L["Character"], color = CreateColor(0.91, 0.310, 0.392, 1) },
    { id = "btwtodo:daily", name = L["Daily"], color = CreateColor(0.898, 0.447, 0.333, 1) },
    { id = "btwtodo:weekly", name = L["Weekly"], color = CreateColor(0.898, 0.769, 0.325, 1) },
    { id = "btwtodo:currency", name = L["Currency"], color = CreateColor(0.322, 0.824, 0.451, 1) },
    { id = "btwtodo:reputation", name = L["Reputation"], color = CreateColor(0.275, 0.741, 0.875, 1) },
})

External.RegisterTodos({
    {
        id = "btwtodo:itemlevel",
        name = L["Item Level"],
        states = {
            { type = "character", id = 6, },
            { type = "character", id = 7, },
        },
        completed = [[return true]],
        text = [[return states[2]:GetValue()]],
        tooltip = [[
tooltip:AddLine(self:GetName())
tooltip:AddLine(format(L["Overall %.2f (Equipped %.2f)"], states[1]:GetValue(), states[2]:GetValue()), 1, 1, 1)
]],
    },
    {
        id = "btwtodo:gold",
        name = L["Gold"],
        states = {
            { type = "character", id = 9, },
        },
        completed = [[return true]],
        text = [[return states[1]:GetValue()]],
    },
})
