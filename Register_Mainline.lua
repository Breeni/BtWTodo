--[[
    Register custom functions, to-dos, categories, and lists for Mainline WoW
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

local SEASON_91_START_TIMESTAMP = {
    [1] = 1625583600, -- US
    [2] = 1625698800, -- TW (+115200)
    [3] = 1625641200, -- EU (+57600)
    [4] = 1625698800, -- KR (+115200)
    [5] = 1625698800, -- CN (+115200)
}

local SEASON_92_START_TIMESTAMP = {
    [1] = 1645542000, -- US
    [2] = 1645657200, -- TW (+115200)
    [3] = 1645599600, -- EU (+57600)
    [4] = 1645657200, -- KR (+115200)
    [5] = 1645657200, -- CN (+115200)
}

-- Week 0 is preseason week
-- Week 1 is Normal/Heroic week
-- Week 2 is Mythic
-- Sometimes there is a 1 to 3 second difference, we need to make sure this doesnt mess with the result
-- hopefully rounding to the nearest hour will work
local function Get91SeasonWeek()
    local nextWeeklyReset = Internal.GetNextWeeklyResetTimestamp()
    local secondsSinceSeasonStart = nextWeeklyReset - SEASON_91_START_TIMESTAMP[GetCurrentRegion()]
    return secondsSinceSeasonStart / SECONDS_PER_WEEK
end
Internal.Get91SeasonWeek = Get91SeasonWeek
Internal.RegisterCustomStateFunction("Get91SeasonWeek", Get91SeasonWeek)
Internal.RegisterCustomStateFunction("GetSeasonWeek", Get91SeasonWeek) -- Deprecated GetSeasonWeek, use the specific season ones
local function Get92SeasonWeek()
    local nextWeeklyReset = Internal.GetNextWeeklyResetTimestamp()
    local secondsSinceSeasonStart = nextWeeklyReset - SEASON_92_START_TIMESTAMP[GetCurrentRegion()]
    return secondsSinceSeasonStart / SECONDS_PER_WEEK
end
Internal.Get92SeasonWeek = Get92SeasonWeek
Internal.RegisterCustomStateFunction("Get92SeasonWeek", Get92SeasonWeek)

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
    return math.min(MAX_RENOWN_FOR_WEEK[6] + (week - 6) * 2, 80)
end
Internal.RegisterCustomStateFunction("GetMaxRenownForWeek", GetMaxRenownForWeek)

local function GetSeason91StartTimestamp()
    return SEASON_91_START_TIMESTAMP[GetCurrentRegion()]
end
Internal.GetSeason91StartTimestamp = GetSeason91StartTimestamp
Internal.RegisterCustomStateFunction("GetSeason91StartTimestamp", GetSeason91StartTimestamp)

local function GetSeasonStartTimestamp()
    return SEASON_92_START_TIMESTAMP[GetCurrentRegion()]
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
			if not unlocked and dailies then -- Fill in missing quests that unlock later
				for k in pairs(dailies) do
					if type(k) == "number" then
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
		[63779] = false, -- A Semblance of Normalcy
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
		[63959] = true,  -- Observational Records
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
		[64166] = false, -- Random Memory Access
		[63965] = nil,   -- Razorwing Egg Rescue
		[63950] = true,  -- Razorwing Talons
		[63961] = true,  -- Sealed Secrets
		[63777] = true,  -- Sealed Secrets
		[63954] = true,  -- Sealed Secrets
		[63955] = true,  -- Sealed Secrets
		[63956] = true,  -- ? Sealed Secrets
		[63780] = true,  -- See How THEY Like It!
		[64430] = nil,   -- Spill the Tea
		[64070] = false, -- Staying Scrappy
		[64432] = false, -- Strength to Weakness
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
    local bosses = {
        (GetAchievementCriteriaInfoByID(15054, 52105)), -- L["Manifestation of Pain"],
        (GetAchievementCriteriaInfoByID(15054, 51655)), -- L["Versya the Damned"],
        (GetAchievementCriteriaInfoByID(15054, 52101)), -- L["Zul'gath the Flayer"],
        (GetAchievementCriteriaInfoByID(15054, 52106)), -- L["Golmak the Monstrosity"],
        (GetAchievementCriteriaInfoByID(15054, 51643)), -- L["Sentinel Pyrophus"],
        (GetAchievementCriteriaInfoByID(15054, 51660)), -- L["Mugrem the Soul Devourer"],
        (GetAchievementCriteriaInfoByID(15054, 52104)), -- L["Kazj the Sentinel"],
        (GetAchievementCriteriaInfoByID(15054, 51644)), -- L["Promathiz"],
        (GetAchievementCriteriaInfoByID(15054, 52103)), -- L["Sentinel Shakorzeth"],
        (GetAchievementCriteriaInfoByID(15054, 51661)), -- L["Intercessor Razzram"],
        (GetAchievementCriteriaInfoByID(15054, 51653)), -- L["Gruukuuek the Elder"],
        (GetAchievementCriteriaInfoByID(15054, 52102)), -- L["Algel the Haunter"],
        (GetAchievementCriteriaInfoByID(15054, 51648)), -- L["Malleus Grakizz"],
        (GetAchievementCriteriaInfoByID(15054, 51654)), -- L["Gralebboih"],
        (GetAchievementCriteriaInfoByID(15054, 51639)), -- L["The Mass of Souls"],
    }
    _G['bosses'] = bosses
    local bossRegionOffset = {
        [1] = 3, -- US
        [2] = 0, -- TW
        [3] = 0, -- EU
        [4] = 0, -- KR
        [5] = 0, -- CN
    }
	Internal.RegisterCustomStateFunction("GetTormentorsBoss", function ()
		local seasonStartTimestamp = Internal.GetSeason91StartTimestamp()
		local previous = math.floor((GetServerTime() - seasonStartTimestamp) / (2 * 60 * 60)) + bossRegionOffset[GetCurrentRegion()]
        return bosses[previous % #bosses + 1], bosses[(previous + 1) % #bosses + 1], bosses[(previous + 2) % #bosses + 1], bosses[(previous + 3) % #bosses + 1], bosses[(previous + 4) % #bosses + 1]
    end)
    local vignetteIDs = {
        [4723] = true,
        [4773] = true,
    }
    -- returns vignette table and if the tormentors is within countdown
	Internal.RegisterCustomStateFunction("GetActiveTormentorsInfo", function ()
		for _,vignetteGUID in ipairs(C_VignetteInfo.GetVignettes()) do
            local vignette = C_VignetteInfo.GetVignetteInfo(vignetteGUID)
            if vignette and vignetteIDs[vignette.vignetteID] then
                local widgets = C_UIWidgetManager.GetAllWidgetsBySetID(vignette.widgetSetID)
                local widget = C_UIWidgetManager.GetTextWithStateWidgetVisualizationInfo(widgets[1].widgetID)
                return vignette, widget.hasTimer
            end
        end
    end)

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
		local seasonStartTimestamp = Internal.GetSeason91StartTimestamp()
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
		local week = Internal.Get91SeasonWeek() % 4
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
		local week = Internal.Get91SeasonWeek() % 4
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

-- Return Lost Souls
local returnLostSouls = {
    61332, 62861, 62862, 62863, -- Return Lost Souls - Kyrian
    61334, 62867, 62868, 62869, -- Return Lost Souls - Venthyr
    61331, 62858, 62859, 62860, -- Return Lost Souls - Night Fae
    61333, 62864, 62865, 62866, -- Return Lost Souls - Necrolord
}
Internal.RegisterCustomStateFunction("GetReturnLostSoulQuestsForCovenant", function (covenantID)
    local index = (covenantID - 1) * 4
    return returnLostSouls[index + 1], returnLostSouls[index + 2], returnLostSouls[index + 3], returnLostSouls[index + 4]
end)

External.RegisterTodos({
    {
        id = "btwtodo:mythicplusrating",
        name = L["M+ Rating"],
        states = {
            { type = "mythicplusrating", id = 0, },

            { type = "mythicplusrating", id = 391, },
            { type = "mythicplusrating", id = 392, },
            
            { type = "mythicplusrating", id = 234, },
            { type = "mythicplusrating", id = 227, },
            
            { type = "mythicplusrating", id = 370, },
            { type = "mythicplusrating", id = 369, },
            
            { type = "mythicplusrating", id = 169, },
            { type = "mythicplusrating", id = 166, },
        },
        completed = [[return false]],
        text = [[return states[1]:GetRatingColor():WrapTextInColorCode(states[1]:GetRating())]],
        tooltip = [[
tooltip:SetText(self:GetName())
for _,state in ipairs(states) do
    if state:GetID() ~= 0 then
        tooltip:AddLine(format(L["%s (Rating: %s)"], state:GetName(), state:GetRatingColor():WrapTextInColorCode(state:GetRating())), 1, 1, 1)
    end
end]]
    },

    {
        id = "btwtodo:renown",
        name = L["Renown"],
        version = 1,
        changeLog = {
            L["Updated for new season start"],
        },
        states = {
            { type = "currency", id = 1822, },
        },
        completed = [[return states[1]:GetQuantity() + 1 == Custom.GetMaxRenownForWeek(Custom.Get91SeasonWeek())]],
        text = [[return format("%d / %d", states[1]:GetQuantity() + 1, Custom.GetMaxRenownForWeek(Custom.Get91SeasonWeek()))]],
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
        text = [[return format("%s / %s", states[1]:GetStandingQuantity(), states[1]:GetStandingMaxQuantity())]],
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
        completed = [[return tCount(states, "IsCompleted") == 3]],
        text = [[return format("%s / %s", tCount(states, "IsCompleted"), 3)]],
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
        version = 1,
        changeLog = {
            L["Fixed tooltip displaying entire lockout instead of only bosses the character has defeated."],
        },
        states = {
            { type = "vault", id = Enum.WeeklyRewardChestThresholdType.Raid, },
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
for _,encounter in ipairs(states[1]:GetEncounters()) do
    local name = encounter.name
    if encounter.bestDifficulty == 16 then
        tooltip:AddLine(format("%s (%s)", name, encounter.difficultyName), Colors.LEGENDARY:GetRGB())
    elseif encounter.bestDifficulty == 15 then
        tooltip:AddLine(format("%s (%s)", name, encounter.difficultyName), Colors.EPIC:GetRGB())
    elseif encounter.bestDifficulty == 14 then
        tooltip:AddLine(format("%s (%s)", name, encounter.difficultyName), Colors.RARE:GetRGB())
    elseif encounter.bestDifficulty == 17 then
        tooltip:AddLine(format("%s (%s)", name, encounter.difficultyName), Colors.UNCOMMON:GetRGB())
    else
        tooltip:AddLine(name, 1, 1, 1)
    end
end
]],
        click = [[Custom.OpenVaultFrame()]]
    },
    {
        id = "btwtodo:dungeonvault",
        name = L["Dungeon Vault"],
        states = {
            { type = "vault", id = Enum.WeeklyRewardChestThresholdType.MythicPlus, },
            { type = "mythicplusruns", },
        },
        version = 1,
        changeLog = {
            L["Fixed showing the tenth run as a gear item instead of 8th"],
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

    if index == 1 or index == 4 or index == 8 then
        tooltip:AddLine(format("%s : %d ilvl", text, Custom.GetRewardLevelForDifficultyLevel(level)), 0, 1, 0)
    else
        tooltip:AddLine(text, 1, 1, 1)
    end
    -- Only show max top 8
    if index == 8 then
        break
    end
end
]],
        click = [[Custom.OpenVaultFrame()]]
    },
    {
        id = "btwtodo:keystone",
        name = L["Keystone"],
        version = 1,
        changeLog = {
            L["Added shift clicking keystone to chat"],
        },
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
        click = [[Custom.LinkKeystone(states[1]:GetChallengeMapID(), states[1]:GetLevel(), Custom.GetCurrentAffixes())]]
    },
    {
        id = "btwtodo:anima",
        name = L["Anima"],
        states = {
            { type = "currency", id = 1813, },
        },
        completed = "return false",
        text = "return states[1]:GetQuantity()",
    },
    {
        id = "btwtodo:valor",
        name = L["Valor"],
        version = 3,
        changeLog = {
            L["Valor has been uncapped, switching to more standard currency display"],
            L["Valor is now season capped for Shadowlands Season 3"],
            L["Updated for change to uncapped"],
        },
        states = {
            { type = "currency", id = 1191, },
        },
        completed = [[
if states[1]:GetMaxQuantity() ~= 0 then
    return states[1]:IsCapped()
else
    return false
end
        ]],
        text = [[
if states[1]:GetMaxQuantity() ~= 0 then
    return format("%s / %s / %s", states[1]:GetQuantity(), states[1]:GetTotalEarned(), states[1]:GetMaxQuantity())
else
    return format("%s", states[1]:GetQuantity())
end
]],
        tooltip = [[
local quantity = states[1]:GetQuantity()
local earned = states[1]:GetTotalEarned()
local total = states[1]:GetMaxQuantity()
tooltip:AddLine(self:GetName())
tooltip:AddLine(format(L["Quantity: %d"], quantity), 1, 1, 1)
tooltip:AddLine(format(L["Earned this season: %d"], earned), 1, 1, 1)
if total ~= 0 then
    tooltip:AddLine(format(L["Max this season: %d"], total), 1, 1, 1)
end
]],
    },
    {
        id = "btwtodo:conquest",
        name = L["Conquest"],
        version = 3,
        changeLog = {
            L["Conquest has been uncapped, switching to more standard currency display"],
            L["Conquest is now season capped for Shadowlands Season 3"],
            L["Updated for change to uncapped"],
        },
        states = {
            { type = "currency", id = 1602, },
        },
        completed = [[
if states[1]:GetMaxQuantity() ~= 0 then
    return states[1]:IsCapped()
else
    return false
end
        ]],
        text = [[
if states[1]:GetMaxQuantity() ~= 0 then
    return format("%s / %s / %s", states[1]:GetQuantity(), states[1]:GetTotalEarned(), states[1]:GetMaxQuantity())
else
    return format("%s", states[1]:GetQuantity())
end
]],
        tooltip = [[
local quantity = states[1]:GetQuantity()
local earned = states[1]:GetTotalEarned()
local total = states[1]:GetMaxQuantity()
tooltip:AddLine(self:GetName())
tooltip:AddLine(format(L["Quantity: %d"], quantity), 1, 1, 1)
tooltip:AddLine(format(L["Earned this season: %d"], earned), 1, 1, 1)
if total ~= 0 then
    tooltip:AddLine(format(L["Max this season: %d"], total), 1, 1, 1)
end
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
        version = 1,
        changeLog = {
            L["Soul Cinders has been uncapped, switching to standard currency display"],
        },
        states = {
            { type = "currency", id = 1906, },
        },
        completed = "return false",
        text = [[return states[1]:GetQuantity()]],
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
        completed = [[return tCount(states, "IsCompleted") == 2]],
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
        text = [[
if states[1]:GetTotalEarned() == 3510 then
    return Images.COMPLETE
else
    return format("%s / %s / %s", states[1]:GetQuantity(), states[1]:GetTotalEarned(), states[1]:GetMaxQuantity())
end
]],
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
        version = 1,
        changeLog = {
            L["Updated display to show completed quest count and tooltip to show countdown to second weekly assault"],
        },
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
        completed = [[return not Custom.IsBeforeHalfWeeklyReset() and (states[1]:IsCompleted() or states[2]:IsCompleted() or states[3]:IsCompleted() or states[4]:IsCompleted())]],
        text = [[
local current = "-"
local state
if Custom.IsBeforeHalfWeeklyReset() then
    state = states['quest:' .. Custom.GetMawAssaults()]
else
    state = states['quest:' .. select(2, Custom.GetMawAssaults())]
end
if state:IsCompleted() then
    current = Images.COMPLETE
else
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
    current = tCount(states, "IsCompleted", first, last)
    if tCount(states, "IsActive", first, last) == 0 then
        current = Images.QUEST_PICKUP
    end
end

local a, b = "-", "-"
if Custom.IsBeforeHalfWeeklyReset() then
    a = current
else
    if character.data.firstMawAssaultCompleted then
        a = Images.COMPLETE
    end
    b = current
end

return a .. " / " .. b
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
if Custom.IsBeforeHalfWeeklyReset() then
    local countdown = Custom.GetHalfWeeklyCountdown()
    tooltip:AddLine(Images.PADDING .. format(L["Active in %s"], SecondsToTime(countdown)), 1, 1, 1)
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

local vignette, isCountdown = Custom.GetActiveTormentorsInfo()
local next, isActive = Custom.GetTormentorCountdown()
local bosses = {Custom.GetTormentorsBoss()}
if vignette or isActive then
    if vignette and not isCountdown then
        tooltip:AddLine(format(L["Active!"]), 1, 1, 1)
        tooltip:AddLine(format(L[" - %s"], bosses[1]), 1, 1, 1)
    else
        tooltip:AddLine(format(L["Active soon"]), 1, 1, 1)
        tooltip:AddLine(format(L[" - %s"], bosses[1]), 1, 1, 1)
    end

    tooltip:AddLine(" ")

    tooltip:AddLine(format(L["Next in about %s"], SecondsToTime(next)), 1, 1, 1)
    tooltip:AddLine(format(L[" - %s"], bosses[2]), 1, 1, 1)
else
    tooltip:AddLine(format(L["Active in about %s"], SecondsToTime(next)), 1, 1, 1)
    tooltip:AddLine(format(L[" - %s"], bosses[2]), 1, 1, 1)
end
if IsShiftKeyDown() then
    for i=3,#bosses do
        tooltip:AddLine(format(L[" - %s"], bosses[i]), 1, 1, 1)
    end
end
return 1
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
        completed = [[return tCount(states, "IsCompleted") == 3]],
        text = [[return format("%s / %s", tCount(states, "IsCompleted"), 3)]],
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
        completed = [[return tCount(states, "IsCompleted") == 5]],
        text = [[return format("%s / %s", tCount(states, "IsCompleted"), 5)]],
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
        completed = [[return tCount(states, "IsCompleted") == 5]],
        text = [[return format("%s / %s", tCount(states, "IsCompleted"), 5)]],
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
        completed = [[return tCount(states, "IsCompleted") == 5]],
        text = [[return format("%s / %s", tCount(states, "IsCompleted"), 5)]],
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
        completed = [[return states[1]:IsCompleted()]],
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
        completed = [[return tCount(states, "IsCompleted") == 4]],
        text = [[return format("%s / %s", tCount(states, "IsCompleted"), 4)]],
    },
    {
        id = "btwtodo:covenantcampaign",
        name = L["Covenant Campaign"],
        version = 1,
        changeLog = {
            L["Fixed an error for characters that have not selected a covenant yet."],
        },
        states = { -- Ordered by covenant id
            { type = "campaign", id = 119, }, -- Kyrian
            { type = "campaign", id = 113, }, -- Venthyr
            { type = "campaign", id = 117, }, -- Night Fae
            { type = "campaign", id = 115, }, -- Necrolord
        },
        completed = [[
            local state = states[character:GetCovenant()]
            if state then
                return state:IsCompleted()
            end
        ]],
        text = [=[
local state = states[character:GetCovenant()]
if state then
    local text = format("%s / %s", state:GetChaptersCompleted(), state:GetChaptersTotal())
    if state:IsStalled() then
        return Colors.STALLED:WrapTextInColorCode(text)
    else
        return text
    end
else
    return "0 / 9"
end
]=],
        tooltip = [[
local state = states[character:GetCovenant()]
if state then
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
end
]],
    },
    {
        id = "btwtodo:deathboundshard",
        name = L["Death-Bound Shard"],
        states = {
            { type = "quest", id = 64347, },
        },
        completed = [[return states[1]:IsCompleted()]],
        text = DEFAULT_TEXT_FUNCTION,
    },
    {
        id = "btwtodo:bonusevents",
        name = L["Weekly Bonus Event"],
        states = {
            { type = "bonusevent", id = 186401, }, -- Skirmishes
            { type = "bonusevent", id = 186403, }, -- Battlegrounds
            { type = "bonusevent", id = 186406, }, -- Pet Battles
            { type = "bonusevent", id = 225787, }, -- Shadowlands Dungeons
            { type = "bonusevent", id = 225788, }, -- World Quests
            { type = "bonusevent", id = 335148, }, -- Burning Crusade Timewalking
            { type = "bonusevent", id = 335149, }, -- Wrath of the Lich King Timewalking
            { type = "bonusevent", id = 335150, }, -- Cataclysm Timewalking
            { type = "bonusevent", id = 335151, }, -- Mists of Pandaria Timewalking
            { type = "bonusevent", id = 335152, }, -- Warlords of Draenor Timewalking
            { type = "bonusevent", id = 359082, }, -- Legion Timewalking
        },
        completed = [[
local _, state = tFirst(states, "IsActive")
if state then
    return state:IsCompleted()
end
        ]],
        text = [[
local _, state = tFirst(states, "IsActive")
if state then
    if state:IsCompleted() then
        return Images.COMPLETE
    elseif not state:IsAvailable() then
        return "-"
    else
        local text = format("%d / %d", state:GetNumFulfilled(), state:GetNumRequired())
        if not state:IsInProgress() then
            return Colors.STALLED:WrapTextInColorCode(text)
        else
            return text
        end
    end
end
        ]],
        tooltip = [[
tooltip:SetText(self:GetName())
local _, state = tFirst(states, "IsActive")
if state then
    if not state:IsAvailable() then
        tooltip:AddLine(format(L["%s - %s"], state:GetName(), L["Unavailable"]), 1, 1, 1)
    elseif state:IsCompleted() then
        tooltip:AddLine(format(L["%s - %s"], state:GetName(), L["Completed"]), 1, 1, 1)
    else
        tooltip:AddLine(format(L["%s - %d / %d"], state:GetName(), state:GetNumFulfilled(), state:GetNumRequired()), 1, 1, 1)
        if not state:IsInProgress() then
            tooltip:AddLine(L["Check Adventure Journal for quest"])
        end
    end
else
    tooltip:AddLine(L["Unknown"], 1, 1, 1)
end
]]
    },
})

if select(4, GetBuildInfo()) >= 90200 then --@TODO hard code change when 9.2 is released
    External.RegisterTodos({
        {
            id = "btwtodo:92campaign",
            name = L["9.2 Campaign"],
            states = {
                { type = "campaign", id = 158, },
            },
            completed = "return states[1]:IsCompleted()",
            text = [=[
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
            id = "btwtodo:automa",
            name = L["Automa"],
            states = {
                { type = "faction", id = 2480, },
            },
            completed = "return states[1]:HasParagonAvailable()",
            text = [[return format("%s / %s", states[1]:GetStandingQuantity(), states[1]:GetStandingMaxQuantity())]],
        },
        {
            id = "btwtodo:theenlightened",
            name = L["The Enlightened"],
            states = {
                { type = "faction", id = 2478, },
            },
            completed = "return states[1]:HasParagonAvailable()",
            text = [[return format("%s / %s", states[1]:GetStandingQuantity(), states[1]:GetStandingMaxQuantity())]],
        },
        {
            id = "btwtodo:zerethmortisworldboss",
            name = L["Antros"],
            states = {
                { type = "quest", id = 65143, }, -- This is the world quest id, not the tracking id
            },
            completed = "return states[1]:IsCompleted()",
            text = DEFAULT_TEXT_FUNCTION,
        },
        {
            id = "btwtodo:patternswithinpatterns",
            name = L["Patterns Within Patterns"],
            states = {
                { type = "quest", id = 66042, },
            },
            completed = "return states[1]:IsCompleted()",
            text = DEFAULT_TEXT_FUNCTION,
        },
        {
            id = "btwtodo:cosmicflux",
            name = L["Cosmic Flux"],
            states = {
                { type = "currency", id = 2009, },
            },
            completed = "return false",
            text = [[return states[1]:GetQuantity()]],
        },
        {
            id = "btwtodo:cyphersofthefirstones",
            name = L["Cyphers of the First Ones"],
            version = 1,
            changeLog = {
                L["Added displaying Cypher Equipment upgrade progress"],
            },
            states = {
                { type = "currency", id = 1979, },
                { type = "character", id = 11, },
                { type = "character", id = 12, },
                { type = "character", id = 13, },
            },
            completed = "return false",
            text = [[
                return format("%d (%d/%d)", states[1]:GetQuantity(), states[2]:GetValue(), states[3]:GetValue())
            ]],
            tooltip = [[
tooltip:AddLine(self:GetName())
tooltip:AddLine(format(L["CYPHER_EQUIPMENT_LEVEL_FORMAT"], states[2]:GetValue(), states[3]:GetValue()))
local toNextLevel = states[4]:GetValue()
if toNextLevel == nil then
    tooltip:AddLine(L["CYPHER_EQUIPMENT_MAX_LEVEL_TOOLTIP"], 1, 0.82, 0, true)
elseif toNextLevel <= states[1]:GetQuantity() then
    tooltip:AddLine(L["CYPHER_EQUIPMENT_LEVEL_TOOLTIP_GREEN"]:format(toNextLevel), 1, 0.82, 0, true);
else
    tooltip:AddLine(L["CYPHER_EQUIPMENT_LEVEL_TOOLTIP_MATH"]:format(states[1]:GetQuantity(), (toNextLevel - states[1]:GetQuantity())), 1, 0.82, 0, true);
end
]],
        },
    })
end

External.RegisterLists({
    {
        id = "btwtodo:91",
        name = L["Chains of Domination"],
        version = 5,
        todos = {
            {
                id = "btwtodo:itemlevel",
                category = "btwtodo:character",
            },
            {
                id = "btwtodo:mythicplusrating",
                category = "btwtodo:character",
                version = 3,
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
                id = "btwtodo:anima",
                category = "btwtodo:currency",
                version = 4,
            },
            {
                id = "btwtodo:soulcinders",
                category = "btwtodo:currency",
                version = 5,
            },
            {
                id = "btwtodo:valor",
                category = "btwtodo:currency",
            },
            {
                id = "btwtodo:conquest",
                category = "btwtodo:currency",
                version = 2,
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

if select(4, GetBuildInfo()) >= 90200 then
    External.RegisterLists({
        {
            id = "btwtodo:default",
            name = L["Default"],
            version = 7,
            todos = {
                {
                    id = "btwtodo:itemlevel",
                    category = "btwtodo:character",
                },
                {
                    id = "btwtodo:mythicplusrating",
                    category = "btwtodo:character",
                    version = 3,
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
                    hidden = true,
                    version = 6,
                },
                {
                    id = "btwtodo:92campaign",
                    category = "btwtodo:character",
                    version = 6,
                },
                {
                    id = "btwtodo:callings",
                    category = "btwtodo:daily",
                },
                {
                    id = "btwtodo:korthiadailies",
                    category = "btwtodo:daily",
                    hidden = true,
                    version = 6,
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
                    hidden = true,
                    version = 6,
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
                    hidden = true,
                    version = 6,
                },
                {
                    id = "btwtodo:zerethmortisworldboss",
                    category = "btwtodo:weekly",
                    version = 6,
                },
                {
                    id = "btwtodo:torghast",
                    category = "btwtodo:weekly",
                    hidden = true,
                    version = 6,
                },
                {
                    id = "btwtodo:mawassault",
                    category = "btwtodo:weekly",
                    hidden = true,
                    version = 6,
                },
                {
                    id = "btwtodo:tormentors",
                    category = "btwtodo:weekly",
                    hidden = true,
                    version = 6,
                },
                {
                    id = "btwtodo:mawsoulsquest",
                    category = "btwtodo:weekly",
                    hidden = true,
                    version = 6,
                },
                {
                    id = "btwtodo:deathboundshard",
                    category = "btwtodo:weekly",
                    hidden = true,
                },
                {
                    id = "btwtodo:patternswithinpatterns",
                    category = "btwtodo:weekly",
                    version = 6,
                },
                {
                    id = "btwtodo:bonusevents",
                    category = "btwtodo:weekly",
                    version = 7,
                },
                {
                    id = "btwtodo:cosmicflux",
                    category = "btwtodo:currency",
                    version = 6,
                },
                {
                    id = "btwtodo:cyphersofthefirstones",
                    category = "btwtodo:currency",
                    version = 6,
                },
                {
                    id = "btwtodo:anima",
                    category = "btwtodo:currency",
                    version = 4,
                },
                {
                    id = "btwtodo:soulcinders",
                    category = "btwtodo:currency",
                    version = 5,
                },
                {
                    id = "btwtodo:valor",
                    category = "btwtodo:currency",
                },
                {
                    id = "btwtodo:conquest",
                    category = "btwtodo:currency",
                    version = 2,
                },
                {
                    id = "btwtodo:towerknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 6,
                },
                {
                    id = "btwtodo:deathsadvance",
                    category = "btwtodo:reputation",
                    hidden = true,
                    version = 6,
                },
                {
                    id = "btwtodo:thearchivistscodex",
                    category = "btwtodo:reputation",
                    hidden = true,
                    version = 6,
                },
                {
                    id = "btwtodo:theenlightened",
                    category = "btwtodo:reputation",
                    version = 6,
                },
            },
        },
        {
            id = "btwtodo:92",
            name = L["Eternity's End"],
            version = 1,
            todos = {
                {
                    id = "btwtodo:itemlevel",
                    category = "btwtodo:character",
                },
                {
                    id = "btwtodo:mythicplusrating",
                    category = "btwtodo:character",
                },
                {
                    id = "btwtodo:gold",
                    category = "btwtodo:character",
                },
                {
                    id = "btwtodo:renown",
                    category = "btwtodo:character",
                },
                {
                    id = "btwtodo:92campaign",
                    category = "btwtodo:character",
                },
                {
                    id = "btwtodo:callings",
                    category = "btwtodo:daily",
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
                    id = "btwtodo:zerethmortisworldboss",
                    category = "btwtodo:weekly",
                },
                {
                    id = "btwtodo:patternswithinpatterns",
                    category = "btwtodo:weekly",
                },
                {
                    id = "btwtodo:bonusevents",
                    category = "btwtodo:weekly",
                    version = 1,
                },
                {
                    id = "btwtodo:cosmicflux",
                    category = "btwtodo:currency",
                },
                {
                    id = "btwtodo:cyphersofthefirstones",
                    category = "btwtodo:currency",
                },
                {
                    id = "btwtodo:anima",
                    category = "btwtodo:currency",
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
                    id = "btwtodo:conquest",
                    category = "btwtodo:currency",
                },
                {
                    id = "btwtodo:towerknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:theenlightened",
                    category = "btwtodo:reputation",
                },
            },
        }
    })
else
    External.RegisterLists({
        {
            id = "btwtodo:default",
            name = L["Default"],
            version = 5,
            todos = {
                {
                    id = "btwtodo:itemlevel",
                    category = "btwtodo:character",
                },
                {
                    id = "btwtodo:mythicplusrating",
                    category = "btwtodo:character",
                    version = 3,
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
                    id = "btwtodo:anima",
                    category = "btwtodo:currency",
                    version = 4,
                },
                {
                    id = "btwtodo:soulcinders",
                    category = "btwtodo:currency",
                    version = 5,
                },
                {
                    id = "btwtodo:valor",
                    category = "btwtodo:currency",
                },
                {
                    id = "btwtodo:conquest",
                    category = "btwtodo:currency",
                    version = 2,
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
    })
end

