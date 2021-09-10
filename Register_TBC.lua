--[[
    Register custom functions, to-dos, categories, and lists for TBC WoW
]]

local ADDON_NAME, Internal = ...
local External = _G[ADDON_NAME]
local L = Internal.L

local DEFAULT_COMPLETED_FUNCTION = "return self:IsFlaggedCompleted()"
local DEFAULT_TEXT_FUNCTION = [[return self:IsCompleted() and Images.COMPLETE or "-"]]
local DEFAULT_CLICK_FUNCTION = [[self:SetFlaggedCompleted(not self:IsFlaggedCompleted())]]

-- DST doesnt effect daily/weekly/halfweekly resets so these should always be accurate
local SECONDS_PER_HOUR = 60 * 60
local SECONDS_PER_WEEK = 60 * 60 * 24 * 7
local SECONDS_PER_HALF_WEEK = 60 * 60 * 24 * 3.5

External.RegisterTodos({

})

External.RegisterLists({
    {
        id = "btwtodo:default",
        name = L["Default"],
        todos = {
            {
                id = "btwtodo:itemlevel",
                category = "btwtodo:character",
            },
            {
                id = "btwtodo:gold",
                category = "btwtodo:character",
            },
        },
    },
})
