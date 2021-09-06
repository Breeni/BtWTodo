--[[
    Register custom functions, to-dos, categories, and lists for Mainline WoW
]]

local ADDON_NAME, Internal = ...
local External = _G[ADDON_NAME]
local L = Internal.L

local DEFAULT_COMPLETED_FUNCTION = "return self:IsFlaggedCompleted()"
local DEFAULT_TEXT_FUNCTION = [[return self:IsCompleted() and Images.COMPLETE or ""]]
local DEFAULT_CLICK_FUNCTION = [[self:SetFlaggedCompleted(not self:IsFlaggedCompleted())]]

-- DST doesnt effect daily/weekly/halfweekly resets so these should always be accurate
local SECONDS_PER_HOUR = 60 * 60
local SECONDS_PER_WEEK = 60 * 60 * 24 * 7
local SECONDS_PER_HALF_WEEK = 60 * 60 * 24 * 3.5

local SEASON_START_TIMESTAMP = {
    [1] = 1625583600, -- US
    [2] = 1625698800, -- TW
    [3] = 1625641200, -- EU
    [4] = 1625698800, -- KR
    [5] = 1625698800, -- CN
}

-- Week 0 is preseason week
-- Week 1 is Normal/Heroic week
-- Week 2 is Mythic
local function GetSeasonWeek()
    -- Sometimes there is a 1 to 3 second difference, we need to make sure this doesnt mess with the result
    -- hopefully rounding to the nearest hour will work

    local nextWeeklyReset = Internal.GetNextWeeklyResetTimestamp()
    local secondsSinceSeasonStart = nextWeeklyReset - SEASON_START_TIMESTAMP[GetCurrentRegion()]
    return secondsSinceSeasonStart / SECONDS_PER_WEEK
end
Internal.GetSeasonWeek = GetSeasonWeek
Internal.RegisterCustomStateFunction("GetSeasonWeek", GetSeasonWeek)

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

local function GetSeasonStartTimestamp()
    return SEASON_START_TIMESTAMP[GetCurrentRegion()]
end
Internal.GetSeasonStartTimestamp = GetSeasonStartTimestamp
Internal.RegisterCustomStateFunction("GetSeasonStartTimestamp", GetSeasonStartTimestamp)

local function tMap(tbl, func)
	local result = {}
	for k,v in pairs(tbl) do
		result[k] = func(k, v, tbl)
	end
	return result
end

-- Korthia Dailies
do
	local korthiaDailies = {
		[64271] = true,
		[63783] = true,
		[63779] = true,
		[63934] = true,
		[63793] = true,
		[63964] = true,
		[63794] = true,
		[63790] = true,
		[63792] = true,
		[63963] = true,
		[63791] = true,
		[64129] = true,
		[63787] = true,
		[63788] = true,
		[63789] = true,
		[63785] = true,
		[63775] = true,
		[63936] = true,
		[64080] = true,
		[64240] = true,
		[63784] = true,
		[64015] = true,
		[64065] = true,
		[63781] = true,
		[63782] = true,
		[63937] = true,
		[63962] = true,
		[63959] = true,
		[63776] = true,
		[63957] = true,
		[63958] = true,
		[63960] = true,
		[64103] = true,
		[64040] = true,
		[64017] = true,
		[64016] = true,
		[63989] = true,
		[63935] = true,
		[64166] = true,
		[63950] = true,
		[63961] = true,
		[63777] = true,
		[63954] = true,
		[63955] = true,
		[63956] = true,
		[63780] = true,
		[64430] = true,
		[64070] = true,
		[64432] = true,
		[63786] = true,
		[64089] = true,
		[64101] = true,
		[64018] = true,
		[64104] = true,
		[64194] = true,
		[63778] = true,
		[64043] = true,
		[63965] = true,
	}
	local SharedDataID = "KORTHIA_DAILIES"
	Internal.RegisterSharedData(SharedDataID, function (id, data)
		if not data or not data.unlocked then
			return false
		end
		local count = 0
		for k in pairs(data) do
			if type(k) == "number" then
				count = count + 1
			end
		end
		return count == 4 or count == 5
	end)
	local function GetKorthiaDailies()
		local dailies = Internal.GetSharedData(SharedDataID)
		if C_Map.GetBestMapForUnit("player") == 1961 then
			local unlocked = C_QuestLog.IsQuestFlaggedCompleted(63727)

			local quests = tMap(tFilter(C_TaskQuest.GetQuestsForPlayerByMapID(1961), function (item)
				return korthiaDailies[item.questId]
			end, true), function (k, v)
				return v.questId
			end)

			local questIDs = {}
			for _,questID in ipairs(quests) do
				questIDs[questID] = true
			end
			-- Complete quests arent returned by C_TaskQuest.GetQuestsForPlayerByMapID so we will add those ourselves
			for questID in pairs(korthiaDailies) do
				if not questIDs[questID] and C_QuestLog.IsQuestFlaggedCompleted(questID) then
					questIDs[questID] = true
					quests[#quests+1] = questID
				end
			end
			if not questIDs[64103] and C_QuestLog.GetLogIndexForQuestID(64103) then -- This one doesnt show on the map for some reason so we add it if we are on it
				questIDs[64103] = true
				quests[#quests+1] = 64103
			end
			if not unlocked then -- Fill in missing quests that unlock later
				for k in pairs(dailies) do
					if k ~= "n" then
						if not questIDs[k] then
							questIDs[k] = true
							quests[#quests+1] = k
						end
					end
				end
			end
			questIDs.n = #quests
			questIDs.unlocked = unlocked

			Internal.SaveSharedData(SharedDataID, questIDs)

			dailies = questIDs
		end

		return dailies
	end
	Internal.RegisterCustomStateFunction("GetKorthiaDailies", GetKorthiaDailies)
	local baseDailies = {
		[64271] = nil,   -- A More Civilized Way
		[63783] = true,  -- Anima Reclamation
		[63779] = nil,   -- A Semblance of Normalcy
		[63934] = true,  -- Assail Mail
		[63793] = true,  -- Broker's Bounty: Ensydius the Defiler
		[63964] = true,  -- ? Broker's Bounty: Grimtalon
		[63794] = true,  -- Broker's Bounty: Hungering Behemoth
		[63790] = true,  -- Broker's Bounty: Lord Azzorak
		[63792] = true,  -- ? Broker's Bounty: Nocturnus the Unraveler
		[63963] = true,  -- Broker's Bounty: Ripmaul
		[63791] = true,  -- Broker's Bounty: Valdinar the Curseborn
		[64129] = false, -- Charge of the Wild Hunt
		[63787] = true,  -- Continued Efforts: Mauler's Outlook
		[63788] = true,  -- Continued Efforts: Sanctuary of Guidance
		[63789] = true,  -- Continued Efforts: Scholar's Den
		[63785] = true,  -- ? Continued Efforts: Seeker's Quorum
		[63775] = false, -- Cryptograms and Keys
		[63936] = true,  -- Devoured Anima
		[64080] = nil,   -- Down to Earth
		[64240] = nil,   -- Flight of the Kyrian
		[63784] = true,  -- Gold's No Object
		[64015] = nil,   -- Into the Meat Grinder
		[64065] = false, -- Local Reagents
		[63781] = nil,   -- Mawsworn Battle Plans
		[63782] = true,  -- Mawsworn Rituals
		[63937] = nil,   -- Nasty, Big, Pointy Teeth
		[63962] = true,  -- Observational Records
		[63959] = true,  -- ? Observational Records
		[63776] = true,  -- ? Observational Records
		[63957] = true,  -- ? Observational Records
		[63958] = true,  -- Observational Records
		[63960] = true,  -- ? Observational Records
		[64103] = false, -- Old Tricks Work Best
		[64040] = nil,   -- Once More, with Healing
		[64017] = false, -- Oozing with Character
		[64016] = false, -- Oozing with Character
		[63989] = false, -- Oozing with Character
		[63935] = true,  -- Precious Roots
		[64166] = nil,   -- Random Memory Access
		[63965] = nil,   -- Razorwing Egg Rescue
		[63950] = true,  -- Razorwing Talons
		[63961] = true,  -- Sealed Secrets
		[63777] = true,  -- Sealed Secrets
		[63954] = true,  -- Sealed Secrets
		[63955] = true,  -- Sealed Secrets
		[63956] = true,  -- ? Sealed Secrets
		[63780] = true,  -- See How THEY Like It!
		[64430] = nil,   -- Spill the Tea
		[64070] = nil,   -- Staying Scrappy
		[64432] = nil,   -- Strength to Weakness
		[63786] = false, -- Sweep the Windswept Aerie
		[64089] = nil,   -- Teas and Tinctures
		[64101] = true,  -- The Proper Procedures
		[64018] = false, -- The Weight of Stone
		[64104] = nil,   -- Think of the Critters
		[64194] = nil,   -- War Prototype
		[63778] = false, -- We Move Forward
		[64043] = nil,   -- We Need a Healer - You!
	}
	Internal.RegisterCustomStateFunction("IsBaseKorthiaDaily", function (questID)
		return baseDailies[questID]
	end)
	Internal.RegisterEvent("DAILY_RESET", function ()
		BtWTodoCache.korthiaDailies = nil
		Internal.WipeSharedData(SharedDataID)
	end)
end

-- Tormentors of Torghast
do
	--@TODO currently shows local time, should be an option?
	Internal.RegisterCustomStateFunction("GetTormentorTimers", function ()
		local seasonStartTimestamp = Internal.GetSeasonStartTimestamp()
		local previous = seasonStartTimestamp + math.floor((GetServerTime() - seasonStartTimestamp) / (2 * 60 * 60)) * (2 * 60 * 60)
		if GetServerTime() - previous <= 5 * 60 then
			return date("%H:%M:%S", previous + (2 * 60 * 60)), date("%H:%M:%S", previous), false, true
		elseif (previous + (2 * 60 * 60)) - GetServerTime() <= 5 * 60 then
			return date("%H:%M:%S", previous + (2 * 60 * 60)), date("%H:%M:%S", previous), true, false
		else
			return date("%H:%M:%S", previous + (2 * 60 * 60)), date("%H:%M:%S", previous), false, false
		end
	end)

	Internal.RegisterCustomStateFunction("GetTormentorCountdown", function ()
		local seasonStartTimestamp = Internal.GetSeasonStartTimestamp()
		local previous = seasonStartTimestamp + math.floor((GetServerTime() - seasonStartTimestamp) / (2 * 60 * 60)) * (2 * 60 * 60)

		local result = previous + (2 * 60 * 60) - GetServerTime()
		return result, GetServerTime() - previous <= 420
	end)
end

-- Maw Assault
do
	local SharedDataID = "MAW_ASSAULT_QUESTS"
	local assaultOrder = {
		63823, 63822,    63824, 63543,
		63822, 63823,    63543, 63824,
	}
	local assaultQuests = {
		[63543] = { -- Necrolord Assault
            63774,
            63455,
            63664,
            63625,
            63669,
            59004,
            63773,
            63772,
            63753,
            63621,
            63545,
		},
		[63824] = { -- Kyrian Assault
            63858,
            63827,
            63843,
            63853,
            63828,
            63829,
            63859,
            63864,
            63846,
            63863,
		},
		[63823] = { -- Night Fae Assault
            63951,
            63968,
            63973,
            63952,
            63972,
            63969,
            63970,
            63971,
            63974,
            63945,
		},
		[63822] = { -- Venthyr Assault
            63837,
            63838,
            63836,
            63839,
            63841,
            63833,
            63842,
            63840,
            63834,
            63835,
		}
	}
	local function GetActiveMawAssaultQuest()
		local week = Internal.GetSeasonWeek() % 4
		local index = week * 2 + (Internal.IsBeforeHalfWeeklyReset() and 0 or 1) + 1
		return assaultOrder[index]
	end
	Internal.RegisterSharedData(SharedDataID, function (id, data)
		local assaultQuest = GetActiveMawAssaultQuest()
		if not data or not data.quests or data.assaultQuest ~= assaultQuest then
			return
		end

		local count = 0
		for k in pairs(data.quests) do
            if k ~= 63772 then
			    count = count + 1
            end
		end

		return count == 4
	end)
	-- Returns which assaults for the current week
	Internal.RegisterCustomStateFunction("GetMawAssaults", function ()
		local week = Internal.GetSeasonWeek() % 4
		local index = week * 2 + 1
		return unpack(assaultOrder, index, index + 1)
	end)
	Internal.RegisterCustomStateFunction("GetActiveMawAssaultQuests", function ()
		local data = Internal.GetSharedData(SharedDataID) or {}
		local assaultQuest = GetActiveMawAssaultQuest()

		if data.assaultQuest ~= assaultQuest then
			data.quests = {}
		end

		data.assaultQuest = assaultQuest
		data.quests = data.quests or {}

		local save = false
		for _,k in pairs(assaultQuests[assaultQuest]) do
			if C_QuestLog.GetLogIndexForQuestID(k) or C_QuestLog.IsQuestFlaggedCompleted(k) then
				data.quests[k] = true
				save = true
			end
		end

		if save then
			Internal.SaveSharedData(SharedDataID, data)
		end

		return data
	end)

	Internal.RegisterEvent("HALF_WEEKLY_RESET", function (event, isWeekly)
		Internal.WipeSharedData(SharedDataID)
	end, -1)
end

-- Reservoir Anima
local reservoirQuests = {
	61982, -- Replenish the Reservoir - Kyrian
	61981, -- Replenish the Reservoir - Venthyr
	61984, -- Replenish the Reservoir - Night Fae
	61983, -- Replenish the Reservoir - Necrolord
}
Internal.RegisterCustomStateFunction("GetReservoirQuestForCovenant", function (covenantID)
	return reservoirQuests[covenantID]
end)

External.RegisterTodos({
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
            for index, _, name, level, completed in states[2]:IterateRuns() do
                local text
                if completed then
                    text = format("%s (%d)", name, level)
                else
                    text = format("%s- (%d)", name, level)
                end

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
                version = 2,
            },
            {
                id = "btwtodo:renown",
                category = "btwtodo:character",
            },
            {
                id = "btwtodo:91campaign",
                category = "btwtodo:character",
            },
            {
                id = "btwtodo:callings",
                category = "btwtodo:daily",
            },
            {
                id = "btwtodo:korthiadailies",
                category = "btwtodo:daily",
            },
            {
                id = "btwtodo:mawsworncache",
                category = "btwtodo:daily",
                hidden = true,
            },
            {
                id = "btwtodo:invasivemawshroom",
                category = "btwtodo:daily",
                hidden = true,
            },
            {
                id = "btwtodo:nestofunusualmaterials",
                category = "btwtodo:daily",
                hidden = true,
            },
            {
                id = "btwtodo:reliccache",
                category = "btwtodo:daily",
                hidden = true,
            },
            {
                id = "btwtodo:spectralboundchest",
                category = "btwtodo:daily",
                hidden = true,
            },
            {
                id = "btwtodo:riftboundcache",
                category = "btwtodo:daily",
                hidden = true,
            },
            {
                id = "btwtodo:renownquests",
                category = "btwtodo:weekly",
            },
            {
                id = "btwtodo:raidvault",
                category = "btwtodo:weekly",
            },
            {
                id = "btwtodo:dungeonvault",
                category = "btwtodo:weekly",
            },
            {
                id = "btwtodo:keystone",
                category = "btwtodo:weekly",
            },
            {
                id = "btwtodo:mawworldboss",
                category = "btwtodo:weekly",
            },
            {
                id = "btwtodo:torghast",
                category = "btwtodo:weekly",
            },
            {
                id = "btwtodo:mawassault",
                category = "btwtodo:weekly",
            },
            {
                id = "btwtodo:tormentors",
                category = "btwtodo:weekly",
            },
            {
                id = "btwtodo:mawsoulsquest",
                category = "btwtodo:weekly",
            },
            {
                id = "btwtodo:deathboundshard",
                category = "btwtodo:weekly",
                hidden = true,
            },
            {
                id = "btwtodo:soulcinders",
                category = "btwtodo:currency",
            },
            {
                id = "btwtodo:valor",
                category = "btwtodo:currency",
            },
            {
                id = "btwtodo:towerknowledge",
                category = "btwtodo:currency",
            },
            {
                id = "btwtodo:deathsadvance",
                category = "btwtodo:reputation",
            },
            {
                id = "btwtodo:thearchivistscodex",
                category = "btwtodo:reputation",
            },
        },
    },
    {
        id = "btwtodo:91",
        name = L["Chains of Domination"],
        version = 1,
        todos = {
            {
                id = "btwtodo:itemlevel",
                category = "btwtodo:character",
            },
            {
                id = "btwtodo:gold",
                category = "btwtodo:character",
                version = 1,
            },
            {
                id = "btwtodo:renown",
                category = "btwtodo:character",
            },
            {
                id = "btwtodo:91campaign",
                category = "btwtodo:character",
            },
            {
                id = "btwtodo:callings",
                category = "btwtodo:daily",
            },
            {
                id = "btwtodo:korthiadailies",
                category = "btwtodo:daily",
            },
            {
                id = "btwtodo:mawsworncache",
                category = "btwtodo:daily",
                hidden = true,
            },
            {
                id = "btwtodo:invasivemawshroom",
                category = "btwtodo:daily",
                hidden = true,
            },
            {
                id = "btwtodo:nestofunusualmaterials",
                category = "btwtodo:daily",
                hidden = true,
            },
            {
                id = "btwtodo:reliccache",
                category = "btwtodo:daily",
                hidden = true,
            },
            {
                id = "btwtodo:spectralboundchest",
                category = "btwtodo:daily",
                hidden = true,
            },
            {
                id = "btwtodo:riftboundcache",
                category = "btwtodo:daily",
                hidden = true,
            },
            {
                id = "btwtodo:renownquests",
                category = "btwtodo:weekly",
            },
            {
                id = "btwtodo:raidvault",
                category = "btwtodo:weekly",
            },
            {
                id = "btwtodo:dungeonvault",
                category = "btwtodo:weekly",
            },
            {
                id = "btwtodo:keystone",
                category = "btwtodo:weekly",
            },
            {
                id = "btwtodo:mawworldboss",
                category = "btwtodo:weekly",
            },
            {
                id = "btwtodo:torghast",
                category = "btwtodo:weekly",
            },
            {
                id = "btwtodo:mawassault",
                category = "btwtodo:weekly",
            },
            {
                id = "btwtodo:tormentors",
                category = "btwtodo:weekly",
            },
            {
                id = "btwtodo:mawsoulsquest",
                category = "btwtodo:weekly",
            },
            {
                id = "btwtodo:deathboundshard",
                category = "btwtodo:weekly",
                hidden = true,
            },
            {
                id = "btwtodo:soulcinders",
                category = "btwtodo:currency",
            },
            {
                id = "btwtodo:valor",
                category = "btwtodo:currency",
            },
            {
                id = "btwtodo:towerknowledge",
                category = "btwtodo:currency",
            },
            {
                id = "btwtodo:deathsadvance",
                category = "btwtodo:reputation",
            },
            {
                id = "btwtodo:thearchivistscodex",
                category = "btwtodo:reputation",
            },
        },
    }
})
