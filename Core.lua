local ADDON_NAME, Internal = ...
local External = _G[ADDON_NAME]
local L = Internal.L

local DEFAULT_COMPLETED_FUNCTION = "return self:IsFlaggedCompleted()"
local DEFAULT_TEXT_FUNCTION = "return self:IsCompleted() and Images.COMPLETE or \"\""
local DEFAULT_CLICK_FUNCTION = [[self:SetFlaggedCompleted(not self:IsFlaggedCompleted())]]

-- DST doesnt effect daily/weekly/halfweekly resets so these should always be accurate
local SECONDS_PER_HOUR = 60 * 60
local SECONDS_PER_WEEK = 60 * 60 * 24 * 7
local SECONDS_PER_HALF_WEEK = 60 * 60 * 24 * 3.5

local function GetNextWeeklyResetTimestamp()
    return math.floor((GetServerTime() + C_DateAndTime.GetSecondsUntilWeeklyReset()) / SECONDS_PER_HOUR + 0.5) * SECONDS_PER_HOUR
end
local function GetNextDailyResetTimestamp()
    return math.floor((GetServerTime() + C_DateAndTime.GetSecondsUntilDailyReset()) / SECONDS_PER_HOUR + 0.5) * SECONDS_PER_HOUR
end

local function ADDON_LOADED(event, addon)
    if addon == ADDON_NAME then
        BtWTodoData = BtWTodoData or {}

        BtWTodoCategories = BtWTodoCategories or {}

        BtWTodoCharacters = BtWTodoCharacters or {}

        BtWTodoCache = BtWTodoCache or {}
        BtWTodoCache.quests = BtWTodoCache.quests or {}
        BtWTodoCache.currencies = BtWTodoCache.currencies or {}
        BtWTodoCache.factions = BtWTodoCache.factions or {}
        BtWTodoCache.callings = BtWTodoCache.callings or {[1] = {}, [2] = {}, [3] = {}, [4] = {}}
        BtWTodoCache.resets = BtWTodoCache.resets or {}

        Internal.UnregisterEvent("ADDON_LOADED", ADDON_LOADED)
    end
end
Internal.RegisterEvent("ADDON_LOADED", ADDON_LOADED, -10)


local function HandleResets()
    local season = C_MythicPlus.GetCurrentSeason()
    local nextDailyReset = GetNextDailyResetTimestamp()
    local nextWeeklyReset = GetNextWeeklyResetTimestamp()
    local nextHalfWeeklyReset = nextWeeklyReset - SECONDS_PER_HALF_WEEK

    if season == -1 then -- During login it isnt available
        C_Timer.After(5, HandleResets)
    elseif season ~= BtWTodoCache.resets.season then
        -- print("SEASON_RESET", season, BtWTodoCache.resets.season)
        External.TriggerEvent("SEASON_RESET")
        BtWTodoCache.resets.season = season
    end
    -- We do +10 for each of these as the reset times can fluctuate, most I've seen
    -- is 1 second more but no harm in doing 10 since it should jump by 1 week/3.5 days/1 day
    if nextWeeklyReset > (BtWTodoCache.resets.weekly or 0) + 10 then
        -- print("WEEKLY_RESET", nextWeeklyReset, (BtWTodoCache.resets.weekly or 0))

        External.TriggerEvent("WEEKLY_RESET")
        External.TriggerEvent("HALF_WEEKLY_RESET", true)
        External.TriggerEvent("DAILY_RESET", true)

        BtWTodoCache.resets.weekly = nextWeeklyReset
        BtWTodoCache.resets.halfweekly = nextHalfWeeklyReset
        BtWTodoCache.resets.daily = nextDailyReset
    elseif nextHalfWeeklyReset > (BtWTodoCache.resets.halfweekly or 0) + 10 then
        -- print("HALF_WEEKLY_RESET", nextHalfWeeklyReset, (BtWTodoCache.resets.halfweekly or 0))

        External.TriggerEvent("HALF_WEEKLY_RESET", false)
        BtWTodoCache.resets.halfweekly = nextHalfWeeklyReset
    elseif nextDailyReset > (BtWTodoCache.resets.daily or 0) + 10 then
        -- print("DAILY_RESET", nextDailyReset, (BtWTodoCache.resets.daily or 0))

        External.TriggerEvent("DAILY_RESET", false)
        BtWTodoCache.resets.daily = nextDailyReset
    end
end
Internal.RegisterEvent("PLAYER_LOGIN", HandleResets)
Internal.RegisterEvent("CHAT_MSG_SYSTEM", function (event, ...)
    if ... == DAILY_QUESTS_RESET then
        -- This should happen as the C_DateAndTime.GetSecondsUntilDailyReset() timer rolls over
        -- but may happen slightly early and since its annoying to test that we are just gonna
        -- deal with that possibility
        local dailyReset = C_DateAndTime.GetSecondsUntilDailyReset()
        if dailyReset > 10 then
            dailyReset = 1
        end
        C_Timer.After(dailyReset, HandleResets)
    end
end)

local function HalfWeeklyResetTimer(runReset)
    local timer = C_DateAndTime.GetSecondsUntilWeeklyReset() - SECONDS_PER_HALF_WEEK
    if timer >= 0 then
        C_Timer.After(timer, function () HalfWeeklyResetTimer(true) end)
    end
    if runReset then
        HandleResets()
    end
end
HalfWeeklyResetTimer()


local SEASON_START_TIMESTAMP = {
    [1] = 1625583600, -- US
    [2] = 1625698800, -- TW
    [3] = 1625641200, -- EU
    [4] = 1625698800, -- KR
    [5] = 1625698800, -- CN
}
local function GetSeasonStartTimestamp()
    return SEASON_START_TIMESTAMP[GetCurrentRegion()]
end
Internal.GetSeasonStartTimestamp = GetSeasonStartTimestamp
Internal.RegisterCustomStateFunction("GetSeasonStartTimestamp", GetSeasonStartTimestamp)
-- Week 0 is preseason week
-- Week 1 is Normal/Heroic week
-- Week 2 is Mythic
local function GetSeasonWeek()
    -- Sometimes there is a 1 to 3 second difference, we need to make sure this doesnt mess with the result
    -- hopefully rounding to the nearest hour will work

    local nextWeeklyReset = GetNextWeeklyResetTimestamp()
    local secondsSinceSeasonStart = nextWeeklyReset - SEASON_START_TIMESTAMP[GetCurrentRegion()]
    return secondsSinceSeasonStart / SECONDS_PER_WEEK
end
Internal.GetSeasonWeek = GetSeasonWeek
Internal.RegisterCustomStateFunction("GetSeasonWeek", GetSeasonWeek)
function Internal.IsBeforeHalfWeeklyReset()
    local nextHalfWeeklyReset = GetNextWeeklyResetTimestamp() - SECONDS_PER_HALF_WEEK
    return nextHalfWeeklyReset > GetServerTime();
end
Internal.RegisterCustomStateFunction("IsBeforeHalfWeeklyReset", Internal.IsBeforeHalfWeeklyReset)
local MAX_RENOWN_FOR_WEEK = {
    [0] = 42,
    [1] = 45,
    [2] = 48,
    [3] = 51,
    [4] = 54,
    [5] = 57,
    [6] = 60,
}
local function GetMaxRenownForWeek(week)
    if week <= 6 then
        return MAX_RENOWN_FOR_WEEK[week]
    end
    return MAX_RENOWN_FOR_WEEK[6] + (week - 6) * 2
end
Internal.RegisterCustomStateFunction("GetMaxRenownForWeek", GetMaxRenownForWeek)

local registeredTodos = {}
function External.RegisterTodo(todo)
    if type(todo) ~= "table" then
        error("External.RegisterTodo(todo): todo must be a table")
    elseif todo.id == nil then
        error("External.RegisterTodo(todo): todo.id is required")
    elseif type(todo.id) ~= "string" then
        error("External.RegisterTodo(todo): todo.id must be string")
    elseif registeredTodos[todo.id] then
        error("External.RegisterTodo(todo): " .. todo.id .. " is already registered")
    elseif todo.name == nil then
        error("External.RegisterTodo(todo): todo.name is required")
    end

    todo.registered = true
    registeredTodos[todo.id] = todo
end
function External.RegisterTodos(todos)
    for _,todo in ipairs(todos) do
        External.RegisterTodo(todo)
    end
end
function Internal.GetTodo(id)
    return BtWTodoData[id] or registeredTodos[id]
end

External.RegisterTodos({
    {
        id = "btwtodo:itemlevel",
        name = L["Item Level"],
        states = {
            { type = "character", id = 7, },
        },
        completed = [[
            return true
        ]],
        text = [[
            return states[1]:GetValue()
        ]],
    },
    {
        id = "btwtodo:renown",
        name = L["Renown"],
        states = {
            { type = "currency", id = 1822, },
        },
        completed = [[
            return states[1]:GetQuantity() + 1 == Custom.GetMaxRenownForWeek(Custom.GetSeasonWeek())
        ]],
        text = [[
            return format("%d / %d", states[1]:GetQuantity() + 1, Custom.GetMaxRenownForWeek(Custom.GetSeasonWeek()))
        ]],
    },
    {
        id = "btwtodo:91campaign",
        name = L["9.1 Campaign"],
        states = {
            { type = "campaign", id = 138, },
        },
        completed = "return states[1]:IsCompleted() -- Test Comment for editor",
        text = [=[
            if self:IsCompleted() then -- Last chapter doesnt show as completed correctly, it has an extra quest
                return format("%s / %s", states[1]:GetChaptersTotal(), states[1]:GetChaptersTotal())
            end
            local text = format("%s / %s", states[1]:GetChaptersCompleted(), states[1]:GetChaptersTotal())
            if states[1]:IsStalled() then
                return Colors.STALLED:WrapTextInColorCode(text)
            else
                return text
            end
        ]=],
        tooltip = [[
            tooltip:AddLine(self:GetName())
            for i=1,states[1]:GetChaptersTotal() do
                local name = states[1]:GetChapterName(i)
                if self:IsCompleted() or states[1]:IsChapterCompleted(i) then
                    tooltip:AddLine(name, 0, 1, 0)
                elseif states[1]:IsChapterInProgress(i) then
                    tooltip:AddLine(name, 1, 1, 1)
                else
                    tooltip:AddLine(name, 0.5, 0.5, 0.5)
                end
            end
        ]],
    },
    {
        id = "btwtodo:thearchivistscodex",
        name = L["The Archivists' Codex"],
        states = {
            { type = "faction", id = 2472, },
        },
        completed = "return states[1]:IsCapped()",
        text = [[
            if self:IsCompleted() then
                return Images.COMPLETE
            else
                return format("%s / %s", states[1]:GetStandingQuantity(), states[1]:GetStandingMaxQuantity())
            end
        ]],
    },
    {
        id = "btwtodo:deathsadvance",
        name = L["Death's Advance"],
        states = {
            { type = "faction", id = 2470, },
        },
        completed = "return states[1]:HasParagonAvailable()",
        text = [[
            return format("%s / %s", states[1]:GetStandingQuantity(), states[1]:GetStandingMaxQuantity())
        ]],
    },
    {
        id = "btwtodo:deathsadvanceexalted",
        name = L["Death's Advance"],
        states = {
            { type = "faction", id = 2470, },
        },
        completed = "return states[1]:IsCapped()",
        text = [[
            if self:IsCompleted() then
                return Images.COMPLETE
            else
                return format("%s / %s", states[1]:GetStandingQuantity(), states[1]:GetStandingMaxQuantity())
            end
        ]],
    },

    { 
        id = "btwtodo:callings",
        name = L["Callings"],
        states = {
            { type = "calling", id = 1, },
            { type = "calling", id = 2, },
            { type = "calling", id = 3, },
        },
        completed = [[
            return tCount(states, "IsCompleted") == 3
        ]],
        text = [[
            return format("%s / %s", tCount(states, "IsCompleted"), 3)
        ]],
        tooltip = [[
            tooltip:AddLine(self:GetName())
            for i=1,#states do
                local state = states[i]
                local name = state:GetTitle()
                if name == "" then
                    name = L["Unknown"]
                end
                if state:IsCompleted() then
                    tooltip:AddLine(Images.COMPLETE .. name, 0, 1, 0)
                elseif state:IsComplete() then
                    tooltip:AddLine(Images.QUEST_TURN_IN .. name, 1, 1, 0)
                elseif state:IsActive() then
                    local objectiveType = state:GetObjectiveType(1)
                    local fulfilled, required = state:GetObjectiveProgress(1)
                    if objectiveType == "progressbar" then
                        tooltip:AddLine(Images.PADDING .. format("%s (%d%%)", name, math.ceil(fulfilled / required * 100)), 1, 1, 1)
                    else
                        tooltip:AddLine(Images.PADDING .. format("%s (%d/%d)", name, fulfilled, required), 1, 1, 1)
                    end
                else
                    tooltip:AddLine(Images.QUEST_PICKUP .. name, 1, 1, 1)
                end
            end
        ]],
    },
    { 
        id = "btwtodo:korthiadailies",
        name = L["Korthia"],
        states = {
            { type = "quest", id = 63727, }, -- Last Quest of The Last Sigal chapter of the campaign, changes how many dailies are available

            { type = "quest", id = 64271, },
            { type = "quest", id = 63783, },
            -- { type = "quest", id = 64560, }, -- One of the "fake" daily quests when unlocking Korthia
            { type = "quest", id = 63779, },
            { type = "quest", id = 63934, },
            { type = "quest", id = 63793, },
            { type = "quest", id = 63964, },
            { type = "quest", id = 63794, },
            { type = "quest", id = 63790, },
            { type = "quest", id = 63792, },
            { type = "quest", id = 63963, },
            { type = "quest", id = 63791, },
            { type = "quest", id = 64129, },
            { type = "quest", id = 63787, },
            { type = "quest", id = 63788, },
            { type = "quest", id = 63789, },
            { type = "quest", id = 63785, },
            { type = "quest", id = 63775, },
            { type = "quest", id = 63936, },
            { type = "quest", id = 64080, },
            { type = "quest", id = 64240, },
            { type = "quest", id = 63784, },
            { type = "quest", id = 64015, },
            { type = "quest", id = 64065, },
            { type = "quest", id = 63781, },
            { type = "quest", id = 63782, },
            { type = "quest", id = 63937, },
            { type = "quest", id = 63962, },
            { type = "quest", id = 63959, },
            { type = "quest", id = 63776, },
            { type = "quest", id = 63957, },
            { type = "quest", id = 63958, },
            { type = "quest", id = 63960, },
            -- { type = "quest", id = 64561, }, -- One of the "fake" daily quests when unlocking Korthia
            { type = "quest", id = 64103, },
            { type = "quest", id = 64040, },
            { type = "quest", id = 64017, },
            { type = "quest", id = 64016, },
            { type = "quest", id = 63989, },
            { type = "quest", id = 63935, },
            { type = "quest", id = 64166, },
            { type = "quest", id = 63950, },
            { type = "quest", id = 63961, },
            { type = "quest", id = 63777, },
            { type = "quest", id = 63954, },
            { type = "quest", id = 63955, },
            { type = "quest", id = 63956, },
            { type = "quest", id = 63780, },
            { type = "quest", id = 64430, },
            { type = "quest", id = 64070, },
            { type = "quest", id = 64432, },
            { type = "quest", id = 63786, },
            { type = "quest", id = 64089, },
            { type = "quest", id = 64101, },
            { type = "quest", id = 64018, },
            { type = "quest", id = 64104, },
            { type = "quest", id = 64194, },
            { type = "quest", id = 63778, },
            { type = "quest", id = 64043, },
            -- { type = "quest", id = 64562, }, -- One of the "fake" daily quests when unlocking Korthia
            { type = "quest", id = 63965, },
        },
        completed = [[
            local unlocked = states[1]:IsCompleted() -- The Last Sigil
            local active = Custom.GetKorthiaDailies()
            local count = 3
            if unlocked then
                count = active and active.n or 5
            end
            return tCount(states, "IsCompleted", 2) == count
        ]],
        text = [[
            local unlocked = states[1]:IsCompleted() -- The Last Sigil
            local active = Custom.GetKorthiaDailies()
            local count = 3
            local default = active == nil
            if unlocked then
                if active and active.n <= 3 then
                    count = 5
                    default = true
                else
                    count = active and active.n or 5
                end
            end
            if default then
                return format("%s / %s*", tCount(states, "IsCompleted", 2), count)
            else
                return format("%s / %s", tCount(states, "IsCompleted", 2), count)
            end
        ]],
        tooltip = [[
            local unlocked = states[1]:IsCompleted() -- The Last Sigil
            local active = Custom.GetKorthiaDailies()

            tooltip:AddLine(self:GetName())
            if active then
                for i=2,#states do
                    local state = states[i]
                    local questID = state:GetID()
                    if state:IsCompleted() or state:IsActive() or (active[questID] and (unlocked or Custom.IsBaseKorthiaDaily(questID))) then
                        Custom.AddQuestToTooltip(state, tooltip)
                    end
                end
            end
        ]],
    },

    {
        id = "btwtodo:renownquests",
        name = L["Renown Quests"],
        states = {
            { type = "quest", id = 61982, }, -- Replenish the Reservoir - Kyrian
            { type = "quest", id = 61981, }, -- Replenish the Reservoir - Venthyr
            { type = "quest", id = 61984, }, -- Replenish the Reservoir - Night Fae
            { type = "quest", id = 61983, }, -- Replenish the Reservoir - Necrolord
            { type = "quest", id = 63949, }, -- Shaping Fates
        },
        completed = [[
            local covenantID = character:GetCovenant()
            local state = covenantID ~= 0 and states["quest:" .. Custom.GetReservoirQuestForCovenant(covenantID)] or states[1]
            return state:IsCompleted() and states["quest:63949"]:IsCompleted()
        ]],
        text = [[
            local covenantID = character:GetCovenant()
            local state = covenantID ~= 0 and states["quest:" .. Custom.GetReservoirQuestForCovenant(covenantID)] or states[1]
            return format("%d / %d", (state:IsCompleted() and 1 or 0) + (states["quest:63949"]:IsCompleted() and 1 or 0), 2)
        ]],
        tooltip = [[
            tooltip:AddLine(self:GetName())
            local covenantID = character:GetCovenant()
            local state = covenantID ~= 0 and states["quest:" .. Custom.GetReservoirQuestForCovenant(covenantID)] or states[1]
            Custom.AddQuestToTooltip(state, tooltip)
            Custom.AddQuestToTooltip(states["quest:63949"], tooltip)
        ]]
    },
    {
        id = "btwtodo:raidvault",
        name = L["Raid Vault"],
        states = {
            { type = "vault", id = Enum.WeeklyRewardChestThresholdType.Raid, },
            { type = "lockout", id = 2450, values = { 17 }, }, -- LFR
            { type = "lockout", id = 2450, values = { 14 }, }, -- Normal
            { type = "lockout", id = 2450, values = { 15 }, }, -- Heroic
            { type = "lockout", id = 2450, values = { 16 }, }, -- Mythic
        },
        completed = "return states[1]:IsThreshold(3)",
        text = [[
            local text = format("%s / %s / %s", states[1]:GetLevelInitial(1), states[1]:GetLevelInitial(2), states[1]:GetLevelInitial(3))
            if self:IsCompleted() then
                return text -- Already color coded
            elseif states[1]:IsThreshold(2) then
                return Colors.STALLED:WrapTextInColorCode(text)
            elseif states[1]:IsThreshold(1) then
                return Colors.STARTED:WrapTextInColorCode(text)
            else
                return text
            end
        ]],
        tooltip = [[
            tooltip:AddLine(self:GetName())
            local state = states[5]
            for i=1,state:GetBossCount() do
                local name = state:GetBossName(i)
                if states[5]:IsBossCompleted(i) then
                    tooltip:AddLine(format("%s (%s)", name, states[5]:GetDifficultyName()), Colors.LEGENDARY:GetRGB())
                elseif states[4]:IsBossCompleted(i) then
                    tooltip:AddLine(format("%s (%s)", name, states[4]:GetDifficultyName()), Colors.EPIC:GetRGB())
                elseif states[3]:IsBossCompleted(i) then
                    tooltip:AddLine(format("%s (%s)", name, states[3]:GetDifficultyName()), Colors.RARE:GetRGB())
                elseif states[2]:IsBossCompleted(i) then
                    tooltip:AddLine(format("%s (%s)", name, states[2]:GetDifficultyName()), Colors.UNCOMMON:GetRGB())
                else
                    tooltip:AddLine(name, 1, 1, 1)
                end
            end
        ]],
        click = [[
            Custom.OpenVaultFrame()
        ]]
    },
    {
        id = "btwtodo:dungeonvault",
        name = L["Dungeon Vault"],
        states = {
            { type = "vault", id = Enum.WeeklyRewardChestThresholdType.MythicPlus, },
            { type = "mythicplusruns", },
        },
        completed = "return states[1]:GetLevel(3) >= 15",
        text = [[
            local a, b, c = states[1]:GetLevel(1), states[1]:GetLevel(2), states[1]:GetLevel(3)
            local text = format("%s / %s / %s", a == 0 and "-" or a, b == 0 and "-" or b, c == 0 and "-" or c)
            if self:IsCompleted() then
                return text -- Already color coded
            elseif states[1]:IsThreshold(2) then
                return Colors.STALLED:WrapTextInColorCode(text)
            elseif states[1]:IsThreshold(1) then
                return Colors.STARTED:WrapTextInColorCode(text)
            else
                return text
            end
        ]],
        tooltip = [[
            tooltip:AddLine(self:GetName())
            for index, _, name, level in states[2]:IterateRuns() do
                local text = format("%s (%d)", name, level)
                if index == 1 or index == 4 or index == 10 then
                    tooltip:AddLine(format("%s : %d ilvl", text, Custom.GetRewardLevelForDifficultyLevel(level)), 0, 1, 0)
                else
                    tooltip:AddLine(text, 1, 1, 1)
                end
                -- Only show max top 10
                if index == 10 then
                    break
                end
            end
        ]],
        click = [[
            Custom.OpenVaultFrame()
        ]]
    },
    {
        id = "btwtodo:keystone",
        name = L["Keystone"],
        states = {
            { type = "keystone", },
        },
        completed = "return states[1]:GetChallengeMapID() ~= nil",
        text = [[
            local short, level = states[1]:GetChallengeShortMapName(), states[1]:GetLevel()
            if short then
                return format("%s (%d)", short, level)
            else
                return ""
            end
        ]],
        tooltip = [[
            if states[1]:GetChallengeMapID() then
                local name, level = states[1]:GetChallengeMapName(), states[1]:GetLevel()
                local _, ilvl = Custom.GetRewardLevelForDifficultyLevel(level)
                tooltip:AddLine(format(L["%s (Level %d)"], name, level))
                tooltip:AddLine(format(L["Rewards item level %d"], ilvl), 1, 1, 1)
            end
        ]],
    },
    {
        id = "btwtodo:valor",
        name = L["Valor"],
        states = {
            { type = "currency", id = 1191, },
        },
        completed = "return states[1]:IsCapped()",
        text = "return format(\"%s / %s / %s\", states[1]:GetQuantity(), states[1]:GetTotalEarned(), states[1]:GetMaxQuantity())",
        tooltip = [[
            local quantity = states[1]:GetQuantity()
            local earned = states[1]:GetTotalEarned()
            local total = states[1]:GetMaxQuantity()
            tooltip:AddLine(self:GetName())
            tooltip:AddLine(format(L["Quantity: %d"], quantity), 1, 1, 1)
            tooltip:AddLine(format(L["Earned this season: %d"], earned), 1, 1, 1)
            tooltip:AddLine(format(L["Max this season: %d"], total), 1, 1, 1)
        ]],
    },
    {
        id = "btwtodo:mawworldboss",
        name = L["Maw World Boss"],
        states = {
            { type = "quest", id = 64547, },
        },
        completed = "return states[1]:IsCompleted()",
        text = DEFAULT_TEXT_FUNCTION,
    },
    {
        id = "btwtodo:soulcinders",
        name = L["Soul Cinders"],
        states = {
            { type = "currency", id = 1906, },
        },
        completed = "return Custom.GetWeeklySoulCindersEarned(character) == Custom.GetWeeklyMaxSoulCindersForSeasonWeek(character, Custom.GetSeasonWeek())",
        text = [[
            local quantity = states[1]:GetQuantity()
            local earned = Custom.GetWeeklySoulCindersEarned(character)
            local total = Custom.GetWeeklyMaxSoulCindersForSeasonWeek(character, Custom.GetSeasonWeek())
            local text = format("%s / %s / %s", quantity, earned, total)
            if Custom.IsBeforeHalfWeeklyReset() and earned == total - 50 then
                return Colors.STALLED:WrapTextInColorCode(text)
            else
                return text
            end
        ]],
        tooltip = [[
            local quantity = states[1]:GetQuantity()
            local earned = Custom.GetWeeklySoulCindersEarned(character)
            local total = Custom.GetWeeklyMaxSoulCindersForSeasonWeek(character, Custom.GetSeasonWeek())
            tooltip:AddLine(self:GetName())
            tooltip:AddLine(format(L["Quantity: %d"], quantity), 1, 1, 1)
            tooltip:AddLine(format(L["Earned this week: %d*"], earned), 1, 1, 1)
            tooltip:AddLine(format(L["Max this week: %d*"], total), 1, 1, 1)
        ]],
    },
    {
        id = "btwtodo:torghast",
        name = L["Torghast"],
        states = {
            { type = "torghast", id = 1, },
            { type = "torghast", id = 2, },
            { type = "torghast", id = 3, },
            { type = "torghast", id = 4, },
            { type = "torghast", id = 5, },
            { type = "torghast", id = 6, },
        },
        completed = [[
            return tCount(states, "IsCompleted") == 2
        ]],
        text = [[
            local layers = {}
            for _,state in ipairs(states) do
                if state:IsAvailable() then
                    local value = state:GetCompletedLayer()
                    if value == 0 then
                        value = "-"
                    end
                    layers[#layers+1] = value
                end
            end
            return concat(layers, " / ")
        ]],
        tooltip = [[
            tooltip:AddLine(self:GetName())
            for _,state in ipairs(states) do
                local name = state:GetName()
                if state:IsCompleted() then
                    tooltip:AddLine(format(L["%s (Layer %d)"], name, state:GetCompletedLayer()), 0, 1, 0)
                elseif state:IsAvailable() then
                    if state:GetCompletedLayer() ~= 0 then
                        tooltip:AddLine(format(L["%s (Layer %d)"], name, state:GetCompletedLayer()), 1, 1, 1)
                    else
                        tooltip:AddLine(name, 1, 1, 1)
                    end
                end
            end
        ]],
    },
    {
        id = "btwtodo:towerknowledge",
        name = L["Tower Knowledge"],
        states = {
            { type = "currency", id = 1904, },
        },
        completed = "return states[1]:IsCapped()",
        text = "return format(\"%s / %s / %s\", states[1]:GetQuantity(), states[1]:GetTotalEarned(), states[1]:GetMaxQuantity())",
        tooltip = [[
            local quantity = states[1]:GetQuantity()
            local earned = states[1]:GetTotalEarned()
            local total = states[1]:GetMaxQuantity()
            tooltip:AddLine(self:GetName())
            tooltip:AddLine(format(L["Quantity: %d"], quantity), 1, 1, 1)
            tooltip:AddLine(format(L["Earned this season: %d"], earned), 1, 1, 1)
            tooltip:AddLine(format(L["Max this season: %d"], total), 1, 1, 1)
        ]],
    },
    {
        id = "btwtodo:mawassault",
        name = L["Maw Assault"],
        states = {
            { type = "quest", id = 63543, }, -- Necrolord Assault
            { type = "quest", id = 63824, }, -- Kyrian Assault
            { type = "quest", id = 63823, }, -- Night Fae Assault
            { type = "quest", id = 63822, }, -- Venthyr Assault

            -- Necrolord Assault
            { type = "quest", id = 63774, }, -- [5]
            { type = "quest", id = 63455, },
            { type = "quest", id = 63664, },
            { type = "quest", id = 63625, },
            { type = "quest", id = 63669, },
            { type = "quest", id = 59004, },
            { type = "quest", id = 63773, },
            { type = "quest", id = 63772, },
            { type = "quest", id = 63753, },
            { type = "quest", id = 63621, },
            { type = "quest", id = 63545, }, -- [15]

            -- Kyrian Assault
            { type = "quest", id = 63858, }, -- [16]
            { type = "quest", id = 63827, },
            { type = "quest", id = 63843, },
            { type = "quest", id = 63853, },
            { type = "quest", id = 63828, },
            { type = "quest", id = 63829, },
            { type = "quest", id = 63859, },
            { type = "quest", id = 63864, },
            { type = "quest", id = 63846, },
            { type = "quest", id = 63863, }, -- [25]

            -- Night Fae Assault
            { type = "quest", id = 63951, }, -- [26]
            { type = "quest", id = 63968, },
            { type = "quest", id = 63973, },
            { type = "quest", id = 63952, },
            { type = "quest", id = 63972, },
            { type = "quest", id = 63969, },
            { type = "quest", id = 63970, },
            { type = "quest", id = 63971, },
            { type = "quest", id = 63974, },
            { type = "quest", id = 63945, }, -- [35]

            -- Venthyr Assault
            { type = "quest", id = 63837, }, -- [36]
            { type = "quest", id = 63838, },
            { type = "quest", id = 63836, },
            { type = "quest", id = 63839, },
            { type = "quest", id = 63841, },
            { type = "quest", id = 63833, },
            { type = "quest", id = 63842, },
            { type = "quest", id = 63840, },
            { type = "quest", id = 63834, },
            { type = "quest", id = 63835, }, -- [45]
        },
        completed = [[
            return not Custom.IsBeforeHalfWeeklyReset() and (states[1]:IsCompleted() or states[2]:IsCompleted() or states[3]:IsCompleted() or states[4]:IsCompleted())
        ]],
        text = [[
            local count = 0
            if states[1]:IsCompleted() or states[2]:IsCompleted() or states[3]:IsCompleted() or states[4]:IsCompleted() then
                count = count + 1
            end
            if not Custom.IsBeforeHalfWeeklyReset() and character.data.firstMawAssaultCompleted then
                count = count + 1
            end
            local total = 2
            if not Custom.IsBeforeHalfWeeklyReset() and not character.data.firstMawAssaultCompleted then
                total = 1
            end
            local text = format("%d / %d", count, total)
            if Custom.IsBeforeHalfWeeklyReset() and count == 1 then
                return Colors.STALLED:WrapTextInColorCode(text)
            else
                return text
            end
        ]],
        tooltip = [[
            tooltip:AddLine(self:GetName())
            local quests = {Custom.GetMawAssaults()}
            local data = Custom.GetActiveMawAssaultQuests()

            for index,questID in ipairs(quests) do
                local state = states['quest:' .. questID]
                local name = state:GetTitle()
                if name == "" then
                    name = state:GetUniqueKey()
                end
                if IsShiftKeyDown() then
                    name = format("%s [%d]", name, questID)
                end
                if index == 1 and not Custom.IsBeforeHalfWeeklyReset() and not character.data.firstMawAssaultCompleted then
                    name = Colors.COMMON:WrapTextInColorCode(name)
                end

                if state:IsCompleted() or state:GetID() == character.data.firstMawAssaultCompleted then
                    tooltip:AddLine(name, 0, 1, 0)
                else
                    tooltip:AddLine(name, 1, 1, 1)
                end

                local first, last
                if state == states[1] then -- Necrolord
                    first, last = 5, 15
                elseif state == states[2] then -- Kyrian
                    first, last = 16, 25
                elseif state == states[3] then -- Night Fae
                    first, last = 26, 35
                elseif state == states[4] then -- Venthyr
                    first, last = 36, 45
                end

                for i=first,last do
                    local state = states[i]

                    if state:IsActive() or state:IsCompleted() or data.quests[state:GetID()] then
                        Custom.AddQuestToTooltip(state, tooltip)
                    end
                end
            end
        ]],
    },
    {
        id = "btwtodo:tormentors",
        name = L["Tormentors of Torghast"],
        states = {
            { type = "quest", id = 63854, },
        },
        completed = "return states[1]:IsCompleted()",
        text = DEFAULT_TEXT_FUNCTION,
        tooltip = [[
            tooltip:AddLine(self:GetName())

            local next, isActive = Custom.GetTormentorCountdown()
            if isActive then
                tooltip:AddLine(format(L["Active!"]), 1, 1, 1)
            else
                tooltip:AddLine(format(L["Active in %s"], SecondsToTime(next)), 1, 1, 1)
                return 1
            end
        ]],
    },
    {
        id = "btwtodo:mawsoulsquest",
        name = L["Maw Souls"],
        states = {
            { type = "quest", id = 62863, }, -- Kyrian Anima
            { type = "quest", id = 62866, }, -- Necrolord
            { type = "quest", id = 62869, }, -- Venthyr
            { type = "quest", id = 62860, }, -- Night Fae Anima
        },
        completed = "return states[1]:IsCompleted() or states[2]:IsCompleted() or states[3]:IsCompleted() or states[4]:IsCompleted()",
        text = DEFAULT_TEXT_FUNCTION,
    },

    {
        id = "btwtodo:mawsworncache",
        name = L["Mawsworn Cache"],
        states = {
            { type = "quest", id = 64021, },
            { type = "quest", id = 64363, },
            { type = "quest", id = 64364, },
        },
        completed = [[
            return tCount(states, "IsCompleted") == 3
        ]],
        text = [[
            return format("%s / %s", tCount(states, "IsCompleted"), 3)
        ]],
    },
    {
        id = "btwtodo:invasivemawshroom",
        name = L["Invasive Mawshroom"],
        states = {
            { type = "quest", id = 64351, },
            { type = "quest", id = 64354, },
            { type = "quest", id = 64355, },
            { type = "quest", id = 64356, },
            { type = "quest", id = 64357, },
        },
        completed = [[
            return tCount(states, "IsCompleted") == 5
        ]],
        text = [[
            return format("%s / %s", tCount(states, "IsCompleted"), 5)
        ]],
    },
    {
        id = "btwtodo:nestofunusualmaterials",
        name = L["Nest of Unusual Materials"],
        states = {
            { type = "quest", id = 64358, },
            { type = "quest", id = 64359, },
            { type = "quest", id = 64360, },
            { type = "quest", id = 64361, },
            { type = "quest", id = 64362, },
        },
        completed = [[
            return tCount(states, "IsCompleted") == 5
        ]],
        text = [[
            return format("%s / %s", tCount(states, "IsCompleted"), 5)
        ]],
    },
    {
        id = "btwtodo:reliccache",
        name = L["Relic Cache"],
        states = {
            { type = "quest", id = 64316, },
            { type = "quest", id = 64317, },
            { type = "quest", id = 64318, },
            { type = "quest", id = 64564, },
            { type = "quest", id = 64565, },
        },
        completed = [[
            return tCount(states, "IsCompleted") == 5
        ]],
        text = [[
            return format("%s / %s", tCount(states, "IsCompleted"), 5)
        ]],
    },
    {
        id = "btwtodo:spectralboundchest",
        name = L["Spectral Bound Chest"],
        states = {
            { type = "quest", id = 64247, },

            { type = "quest", id = 64248, },
            { type = "quest", id = 64249, },
            { type = "quest", id = 64250, },
        },
        completed = [[
            return states[1]:IsCompleted()
        ]],
        text = [[
            if states[1]:IsCompleted() then
                return Images.COMPLETE
            else
                local count = tCount(states, "IsCompleted", 2)
                local text = format("%s / %s", count, 3)
                if count == 3 then
                    return Colors.STALLED:WrapTextInColorCode(text)
                else
                    return text
                end
            end
        ]],
    },
    {
        id = "btwtodo:riftboundcache",
        name = L["Riftbound Cache"],
        states = {
            { type = "quest", id = 64470, },
            { type = "quest", id = 64471, },
            { type = "quest", id = 64472, },
            { type = "quest", id = 64456, },
        },
        completed = [[
            return tCount(states, "IsCompleted") == 4
        ]],
        text = [[
            return format("%s / %s", tCount(states, "IsCompleted"), 4)
        ]],
    },
    {
        id = "btwtodo:covenantcampaign",
        name = L["Covenant Campaign"],
        states = { -- Ordered by covenant id
            { type = "campaign", id = 119, }, -- Kyrian
            { type = "campaign", id = 113, }, -- Venthyr
            { type = "campaign", id = 117, }, -- Night Fae
            { type = "campaign", id = 115, }, -- Necrolord
        },
        completed = [[
            return states[character:GetCovenant()]:IsCompleted()
        ]],
        text = [=[
            local state = states[character:GetCovenant()]
            local text = format("%s / %s", state:GetChaptersCompleted(), state:GetChaptersTotal())
            if state:IsStalled() then
                return Colors.STALLED:WrapTextInColorCode(text)
            else
                return text
            end
        ]=],
        tooltip = [[
            local state = states[character:GetCovenant()]
            tooltip:AddLine(self:GetName())
            for i=1,state:GetChaptersTotal() do
                local name = state:GetChapterName(i)
                if state:IsChapterCompleted(i) then
                    tooltip:AddLine(name, 0, 1, 0)
                elseif state:IsChapterInProgress(i) then
                    tooltip:AddLine(name, 1, 1, 1)
                else
                    tooltip:AddLine(name, 0.5, 0.5, 0.5)
                end
            end
        ]],
    },
    {
        id = "btwtodo:deathboundshard",
        name = L["Death-Bound Shard"],
        states = {
            { type = "quest", id = 64347, },
        },
        completed = [[
            return states[1]:IsCompleted()
        ]],
        text = DEFAULT_TEXT_FUNCTION,
    },
})

local registeredCategories = {}
function External.RegisterCategory(category)
    if type(category) ~= "table" then
        error("External.RegisterCategory(category): category must be a table")
    elseif category.id == nil then
        error("External.RegisterCategory(category): category.id is required")
    elseif type(category.id) ~= "string" then
        error("External.RegisterCategory(category): category.id must be string")
    elseif registeredCategories[category.id] then
        error("External.RegisterCategory(category): " .. category.id .. " is already registered")
    elseif category.name == nil then
        error("External.RegisterCategory(category): category.name is required")
    elseif category.color == nil then
        error("External.RegisterCategory(category): category.color is required")
    end

    registeredCategories[category.id] = category
end
function External.RegisterCategories(items)
    for _,item in ipairs(items) do
        External.RegisterCategory(item)
    end
end
function External.GetCategory(id)
    local saved, registered = BtWTodoCategories[id], registeredCategories[id]
    if type(saved) ~= "table" and type(registered) ~= "table" then
        error("External.GetCategory(category): unknown category " .. tostring(id))
    end

    -- Clone the color, the config ui edits this color return from here, if we return the color
    -- stored without cloning then when saving the color it'll always be considered the same
    -- as the original registered color and not be saved
    local color
    if saved and saved.color then
        color = CreateColor(unpack(saved.color))
    else
        color = CreateColor(registered.color:GetRGB())
    end

    return { id = id, name = saved and saved.name or registered.name, color = color }
end
function External.UpdateCategory(id, name, color)
    local category = BtWTodoCategories[id]
    if not category then
        category = {}
        BtWTodoCategories[id] = category
    end

    category.name = name or category.name
    category.color = color and {color:GetRGBA()} or category.color

    local registered = registeredCategories[id]
    if registered then
        if registered.name == category.name then
            category.name = nil
        end
        if registered.color.r == category.color[1] and registered.color.g == category.color[2] and registered.color.b == category.color[3] then
            category.color = nil
        end
        if next(category) == nil then
            BtWTodoCategories[id] = nil
        end
    end
end
function External.ResetCategory(id)
    BtWTodoCategories[id] = nil
end
function Internal.IterateCategories()
    local tbl = {}
    for id in pairs(BtWTodoCategories) do
        tbl[id] = External.GetCategory(id)
    end
    for id in pairs(registeredCategories) do
        if not tbl[id] then
            tbl[id] = External.GetCategory(id)
        end
    end
    return next, tbl, nil
end
function External.GetCategoryByName(name)
    for id,category in pairs(registeredCategories) do
        if category.name == name then
            return id
        end
    end
end
External.RegisterCategories({
    { id = "btwtodo:character", name = L["Character"], color = CreateColor(0.91, 0.310, 0.392, 1) },
    { id = "btwtodo:daily", name = L["Daily"], color = CreateColor(0.898, 0.447, 0.333, 1) },
    { id = "btwtodo:weekly", name = L["Weekly"], color = CreateColor(0.898, 0.769, 0.325, 1) },
    { id = "btwtodo:currency", name = L["Currency"], color = CreateColor(0.322, 0.824, 0.451, 1) },
    { id = "btwtodo:reputation", name = L["Reputation"], color = CreateColor(0.275, 0.741, 0.875, 1) },
})

function External.GetTodoName(id)
    local tbl
    if BtWTodoData[id] then
        tbl = BtWTodoData[id]
    else
        tbl = registeredTodos[id]
    end
    if tbl == nil then
        error("External.GetTodoName(id): unknown todo " .. tostring(id))
    end

    return tbl.name
end
function Internal.IterateTodos()
    local tbl = {}
    for id,todo in pairs(BtWTodoData) do
        tbl[id] = todo
    end
    for id,todo in pairs(registeredTodos) do
        if not tbl[id] then
            tbl[id] = todo
        end
    end
    return next, tbl, nil
end
function External.CreateTodoByID(id)
    local tbl
    if BtWTodoData[id] then
        tbl = BtWTodoData[id]
    else
        tbl = registeredTodos[id]
    end
    if tbl == nil then
        error("External.CreateTodoByID(id): unknown todo " .. tostring(id))
    end
    
    local id, name, states, completed, text, click, tooltip = tbl.id, tbl.name, tbl.states, tbl.completed or DEFAULT_COMPLETED_FUNCTION, tbl.text or DEFAULT_TEXT_FUNCTION, tbl.click, tbl.tooltip
    return Internal.CreateStateDriver(id, name, states, completed, text, click, tooltip)
end
function Internal.SaveTodo(tbl)
    local id = tbl.id
    if not BtWTodoData[id] and registeredTodos[id] then
        if tCompare(tbl, registeredTodos[id], 3) then
            BtWTodoData[id] = nil
        else
            BtWTodoData[id] = tbl
        end
    else
        BtWTodoData[id] = tbl
    end
end
