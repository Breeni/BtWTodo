--[[
    Register custom functions, to-dos, categories, and lists for Mainline WoW
]]

local ADDON_NAME, Internal = ...
local External = _G[ADDON_NAME]
local L = Internal.L

local DEFAULT_COMPLETED_FUNCTION = "return self:IsFlaggedCompleted()"
local DEFAULT_TEXT_FUNCTION = [[return self:IsCompleted() and Images.COMPLETE or "-"]]
local DEFAULT_CLICK_FUNCTION = [[self:SetFlaggedCompleted(not self:IsFlaggedCompleted())]]
local DEFAULT_QUEST_TOOLTIP = [[
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
]]

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
    [72] = 1625583600, -- US
}

local SEASON_92_START_TIMESTAMP = {
    [1] = 1645542000, -- US
    [2] = 1645657200, -- TW (+115200)
    [3] = 1645599600, -- EU (+57600)
    [4] = 1645657200, -- KR (+115200)
    [5] = 1645657200, -- CN (+115200)
    [72] = 1645542000, -- US
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


local function GetDFPreSeasonTimestamp(region)
    local timestamps = {
        [1] = 1669734000, -- US
        [2] = 1669849200, -- TW (+115200)
        [3] = 1669780800, -- EU (+46800)
        [4] = 1669849200, -- KR (+115200)
        [5] = 1669849200, -- CN (+115200)
        [72] = 1669734000, -- PTR
    }
    return timestamps[region or GetCurrentRegion()];
end
Internal.RegisterCustomStateFunction("GetDFPreSeasonTimestamp", GetDFPreSeasonTimestamp)

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

local function FormatDuration(duration, format)
    if not format then
        format = {hours = true, minutes = true, seconds = true}
    end
    if type(format) == "number" then
        format = {hours = true, minutes = true, seconds = true, count = format}
    end
    local count = format.count or 10

    local result = {}

    if format.hours then
        local amount = (format.minutes and math.floor or math.ceil)(duration / 3600)
        if amount ~= 0 then
            result[#result+1] = amount .. " h"
            duration = duration - amount * 3600
            count = count - 1
        end
    end
    if format.minutes and count > 0 then
        local amount = (format.seconds and math.floor or math.ceil)(duration / 60)
        if amount ~= 0 then
            result[#result+1] = amount .. " m"
            duration = duration - amount * 60
            count = count - 1
        end
    end
    if format.seconds and count > 0 then
        if duration ~= 0 then
            result[#result+1] = duration .. " s"
        end
    end

    return table.concat(result, " ")
end
Internal.RegisterCustomStateFunction("FormatDuration", FormatDuration)

-- Verified for NA and EU
local function GetDragonbaneKeepCountdown()
    local start = GetDFPreSeasonTimestamp()
    local current = GetServerTime()
    local seconds = (current - start) % 7200
    if seconds < 3600 then
        return true, 3600 - seconds
    else
        return false, 7200 - seconds
    end
end
Internal.RegisterCustomStateFunction("GetDragonbaneKeepCountdown", GetDragonbaneKeepCountdown)

-- Verified for NA and EU
local function GetGrandHuntCountdown()
    local start = GetDFPreSeasonTimestamp()
    local current = GetServerTime()
    local seconds = (current - start) % 7200
    return 7200 - seconds
end
Internal.RegisterCustomStateFunction("GetGrandHuntCountdown", GetGrandHuntCountdown)

local function GetCommunityFeastCountdown()
    local start = GetDFPreSeasonTimestamp()
    if GetCurrentRegion() == 1 then
        start = start - 1800
    end
    local current = GetServerTime()
    local seconds = (current - start) % 5400
    if seconds < 900 then
        return true, 900 - seconds
    else
        return false, 5400 - seconds
    end
end
Internal.RegisterCustomStateFunction("GetCommunityFeastCountdown", GetCommunityFeastCountdown)

local function GetPrimalStormCountdown()
    local start = GetDFPreSeasonTimestamp()
    local current = GetServerTime()
    local seconds = (current - start) % 10800
    if seconds < 7200 then
        return true, 7200 - seconds
    else
        return false, 10800 - seconds
    end
end
Internal.RegisterCustomStateFunction("GetPrimalStormCountdown", GetPrimalStormCountdown)

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
    local bossRegionOffset = {
        [1] = 3, -- US
        [2] = 0, -- TW
        [3] = 0, -- EU
        [4] = 0, -- KR
        [5] = 0, -- CN
        [72] = 3, -- PTR
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
local instanceName = nil
for _,encounter in ipairs(states[1]:GetEncounters()) do
    if instanceName ~= encounter.instanceName then
        tooltip:AddLine(format("%s", encounter.instanceName), 1, 1, 1)
        instanceName = encounter.instanceName
    end
    local name = encounter.name
    if encounter.bestDifficulty == 16 then
        tooltip:AddLine(format("- %s (%s)", name, encounter.difficultyName), Colors.LEGENDARY:GetRGB())
    elseif encounter.bestDifficulty == 15 then
        tooltip:AddLine(format("- %s (%s)", name, encounter.difficultyName), Colors.EPIC:GetRGB())
    elseif encounter.bestDifficulty == 14 then
        tooltip:AddLine(format("- %s (%s)", name, encounter.difficultyName), Colors.RARE:GetRGB())
    elseif encounter.bestDifficulty == 17 then
        tooltip:AddLine(format("- %s (%s)", name, encounter.difficultyName), Colors.UNCOMMON:GetRGB())
    else
        tooltip:AddLine(format("- %s", name), 0.5, 0.5, 0.5)
    end
end
]],
        click = [[Custom.OpenVaultFrame()]]
    },
    {
        id = "btwtodo:dungeonvault",
        name = L["Dungeon Vault"],
        states = {
            { type = "vault", id = Enum.WeeklyRewardChestThresholdType.Activities, },
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

-- M+ Ratings
local function MythicPlusRating(tbl)
    if Internal.IsShadowlandsSeason3 then
        tbl.version = 1
        tbl.changeLog = {
            L["Updated for Eternity's End"],
        }
        tbl.states = {
            { type = "mythicplusrating", id = 0, },

            { type = "mythicplusrating", id = 391, },
            { type = "mythicplusrating", id = 392, },
            
            { type = "mythicplusrating", id = 234, },
            { type = "mythicplusrating", id = 227, },
            
            { type = "mythicplusrating", id = 370, },
            { type = "mythicplusrating", id = 369, },
            
            { type = "mythicplusrating", id = 169, },
            { type = "mythicplusrating", id = 166, },
        }
    elseif Internal.IsShadowlandsSeason4 then
        tbl.version = 2
        tbl.changeLog = {
            L["Updated for Eternity's End"],
            L["Updated for Shadowlands Season 4"],
            L["Updated for Dragonflight Season 1"],
        }
        tbl.states = {
            { type = "mythicplusrating", id = 0, },

            { type = "mythicplusrating", id = 391, },
            { type = "mythicplusrating", id = 392, },
            
            { type = "mythicplusrating", id = 234, },
            { type = "mythicplusrating", id = 227, },
            
            { type = "mythicplusrating", id = 370, },
            { type = "mythicplusrating", id = 369, },
            
            { type = "mythicplusrating", id = 169, },
            { type = "mythicplusrating", id = 166, },
        }
    elseif Internal.IsDragonflightSeason1 then
        tbl.version = 3
        tbl.changeLog = {
            L["Updated for Eternity's End"],
            L["Updated for Shadowlands Season 4"],
            L["Updated for Dragonflight Season 1"],
        }
        tbl.states = {
            { type = "mythicplusrating", id = 0, },

            { type = "mythicplusrating", id = 399, },
            { type = "mythicplusrating", id = 400, },
            
            { type = "mythicplusrating", id = 401, },
            { type = "mythicplusrating", id = 402, },
            
            { type = "mythicplusrating", id = 2, },
            { type = "mythicplusrating", id = 210, },
            
            { type = "mythicplusrating", id = 200, },
            { type = "mythicplusrating", id = 165, },
        }
    else -- if Internal.IsTheWarWithinSeason1 then
        tbl.version = 7
        tbl.changeLog = {
            L["Updated for Eternity's End"],
            L["Updated for Shadowlands Season 4"],
            L["Updated for Dragonflight Season 1"],
            L["Updated for The War Within Season 1"],
        }
        tbl.states = {
            { type = "mythicplusrating", id = 0, },

            { type = "mythicplusrating", id = 503, }, -- Ara-Kara, City of Echoes
            { type = "mythicplusrating", id = 502, }, -- City of Threads
            
            { type = "mythicplusrating", id = 501, }, -- The Stonevault
            { type = "mythicplusrating", id = 505, }, -- The Dawnbreaker
            
            { type = "mythicplusrating", id = 375, }, -- Mists of Tirna Scithe
            { type = "mythicplusrating", id = 376, }, -- Nacrotic Wake
            
            { type = "mythicplusrating", id = 353, }, -- Seige of Boralus
            { type = "mythicplusrating", id = 507, }, -- Grim Batol
        }
    end

    return tbl
end
External.RegisterTodos({
    MythicPlusRating({
        id = "btwtodo:mythicplusrating",
        name = L["M+ Rating"],
        completed = [[return false]],
        text = [[return states[1]:GetRatingColor():WrapTextInColorCode(states[1]:GetRating())]],
        tooltip = [[
tooltip:SetText(self:GetName())
for _,state in ipairs(states) do
    if state:GetID() ~= 0 then
        tooltip:AddLine(format(L["%s (Rating: %s)"], state:GetName(), state:GetRatingColor():WrapTextInColorCode(state:GetRating())), 1, 1, 1)
    end
end]]
    }),
})

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

if Internal.Is90200OrBeyond then
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

    External.RegisterLists({
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
end
if Internal.Is100000OrBeyond then
    External.RegisterTodos({
        {
            id = "btwtodo:dragonflyingglyphs",
            name = L["Skyriding Talents"],
            version = 2,
            changeLog = {
                L["Updated for The War Within"],
            },
            states = {
                { type = "traitcurrency", id = 2563, },
            },
            completed = [[
                return states[1]:GetSpent() == 11
            ]],
            text = [[
                local quantity = states[1]:GetQuantity()
                local text
                if quantity == 0 then
                    text = format("%d / %d", states[1]:GetSpent(), 11)
                else
                    text = format("%d + %d / %d", states[1]:GetSpent(), quantity, 11)
                end
                if states[1]:GetTotalEarned() == 11 and quantity ~= 0 then
                    text = Colors.STALLED:WrapTextInColorCode(text)
                end
                return text
            ]],
            tooltip = [[
                local quantity = states[1]:GetQuantity()
                local spent = states[1]:GetSpent()
                tooltip:AddLine(self:GetName())
                tooltip:AddLine(format(L["Quantity: %d"], quantity), 1, 1, 1)
                tooltip:AddLine(format(L["Spent: %d"], spent), 1, 1, 1)
                tooltip:AddLine(format(L["Total: %d"], 11), 1, 1, 1)
            ]]
        },
        {
            id = "btwtodo:dragonislessupplies",
            name = L["Dragon Isle Supplies"],
            states = {
                { type = "currency", id = 2003, },
            },
            completed = "return false",
            text = [[return states[1]:GetQuantity()]],
        },
        {
            id = "btwtodo:elementaloverflow",
            name = L["Elemental Overflow"],
            states = {
                { type = "currency", id = 2118, },
            },
            completed = "return false",
            text = [[return states[1]:GetQuantity()]],
        },
        {
            id = "btwtodo:stormsigil",
            name = L["Storm Sigil"],
            states = {
                { type = "currency", id = 2122, },
            },
            completed = "return false",
            text = [[return states[1]:GetQuantity()]],
        },
        {
            id = "btwtodo:primalstorms",
            name = L["Primal Storms"],
            states = {
                { type = "quest", id = 70753, }, -- Air Invasions -  Primal Air Core -  Dissipating the Air Primalists
                { type = "quest", id = 70723, }, -- Earth Invasions -  Primal Earth Core -  Shattering the Earth Primalists
                { type = "quest", id = 70754, }, -- Fire Invasions -  Primal Fire Core -  Extinguishing the Fire Primalists
                { type = "quest", id = 70752, }, -- Water Invasions -  Primal Water Core -  Vaporizing the Water Primalists
            },
            completed = [[return tCount(states, "IsCompleted") == 4]],
            text = [[
                local items = {};
                for index,letter in ipairs({"A", "E", "F", "W"}) do
                    if states[index]:IsCompleted() then
                        letter = Colors.COMPLETE:WrapTextInColorCode(letter);
                    elseif states[index]:IsActive() then
                        letter = Colors.STALLED:WrapTextInColorCode(letter);
                    end
                    items[#items+1] = letter;
                end
                return table.concat(items, " / ");
            ]],
        },
        {
            id = "btwtodo:blacksmithingprofessionknowledge",
            name = L["Blacksmithing Profession Knowledge"],
            states = {
                { type = "currency", id = 2023, }, -- Blacksmithing
                -- { type = "currency", id = 2025, }, -- Leatherworking
                -- { type = "currency", id = 2024, }, -- Alchemy
                -- { type = "currency", id = 2034, }, -- Herbalism
                -- { type = "currency", id = 2035, }, -- Mining
                -- { type = "currency", id = 2026, }, -- Tailoring
                -- { type = "currency", id = 2027, }, -- Engineering
                -- { type = "currency", id = 2030, }, -- Enchanting
                -- { type = "currency", id = 2033, }, -- Skinning
                -- { type = "currency", id = 2029, }, -- Jewelcrafting
                -- { type = "currency", id = 2028, }, -- Inscription
            },
            completed = "return false",
            text = [[return states[1]:GetQuantity()]],
        },
        {
            id = "btwtodo:leatherworkingprofessionknowledge",
            name = L["Leatherworking Profession Knowledge"],
            states = {
                { type = "currency", id = 2025, }, -- Leatherworking
            },
            completed = "return false",
            text = [[return states[1]:GetQuantity()]],
        },
        {
            id = "btwtodo:alchemyprofessionknowledge",
            name = L["Alchemy Profession Knowledge"],
            states = {
                { type = "currency", id = 2024, }, -- Alchemy
            },
            completed = "return false",
            text = [[return states[1]:GetQuantity()]],
        },
        {
            id = "btwtodo:herbalismprofessionknowledge",
            name = L["Herbalism Profession Knowledge"],
            states = {
                { type = "currency", id = 2034, }, -- Herbalism
            },
            completed = "return false",
            text = [[return states[1]:GetQuantity()]],
        },
        {
            id = "btwtodo:miningprofessionknowledge",
            name = L["Mining Profession Knowledge"],
            states = {
                { type = "currency", id = 2035, }, -- Mining
            },
            completed = "return false",
            text = [[return states[1]:GetQuantity()]],
        },
        {
            id = "btwtodo:tailoringprofessionknowledge",
            name = L["Tailoring Profession Knowledge"],
            states = {
                { type = "currency", id = 2026, }, -- Tailoring
            },
            completed = "return false",
            text = [[return states[1]:GetQuantity()]],
        },
        {
            id = "btwtodo:engineeringprofessionknowledge",
            name = L["Engineering Profession Knowledge"],
            states = {
                { type = "currency", id = 2027, }, -- Engineering
            },
            completed = "return false",
            text = [[return states[1]:GetQuantity()]],
        },
        {
            id = "btwtodo:enchantingprofessionknowledge",
            name = L["Enchanting Profession Knowledge"],
            states = {
                { type = "currency", id = 2030, }, -- Enchanting
            },
            completed = "return false",
            text = [[return states[1]:GetQuantity()]],
        },
        {
            id = "btwtodo:skinningprofessionknowledge",
            name = L["Skinning Profession Knowledge"],
            states = {
                { type = "currency", id = 2033, }, -- Skinning
            },
            completed = "return false",
            text = [[return states[1]:GetQuantity()]],
        },
        {
            id = "btwtodo:jewelcraftingprofessionknowledge",
            name = L["Jewelcrafting Profession Knowledge"],
            states = {
                { type = "currency", id = 2029, }, -- Jewelcrafting
            },
            completed = "return false",
            text = [[return states[1]:GetQuantity()]],
        },
        {
            id = "btwtodo:inscriptionprofessionknowledge",
            name = L["Inscription Profession Knowledge"],
            states = {
                { type = "currency", id = 2028, }, -- Inscription
            },
            completed = "return false",
            text = [[return states[1]:GetQuantity()]],
        },
        {
            id = "btwtodo:dragonscaleexpedition",
            name = L["Dragonscale Expedition"],
            states = {
                { type = "faction", id = 2507, },
                { type = "currency", id = 2021, },
            },
            completed = "return states[2]:IsCapped()",
            text = [[
if self:IsCompleted() then
    return Images.COMPLETE
else
    return format("%s / %s (%d / %d)", states[1]:GetStandingQuantity(), states[1]:GetStandingMaxQuantity(), states[2]:GetQuantity(), states[2]:GetMaxQuantity())
end
]],
        },
        {
            id = "btwtodo:iskaaratuskarr",
            name = L["Iskaara Tuskarr"],
            states = {
                { type = "faction", id = 2511, },
                { type = "currency", id = 2087, },
            },
            completed = "return states[2]:IsCapped()",
            text = [[
if self:IsCompleted() then
    return Images.COMPLETE
else
    return format("%s / %s (%d / %d)", states[1]:GetStandingQuantity(), states[1]:GetStandingMaxQuantity(), states[2]:GetQuantity(), states[2]:GetMaxQuantity())
end
]],
        },
        {
            id = "btwtodo:maruukcentaur",
            name = L["Maruuk Centaur"],
            states = {
                { type = "faction", id = 2503, },
                { type = "currency", id = 2002, },
            },
            completed = "return states[2]:IsCapped()",
            text = [[
if self:IsCompleted() then
    return Images.COMPLETE
else
    return format("%s / %s (%d / %d)", states[1]:GetStandingQuantity(), states[1]:GetStandingMaxQuantity(), states[2]:GetQuantity(), states[2]:GetMaxQuantity())
end
]],
        },
        {
            id = "btwtodo:valdrakkenaccord",
            name = L["Valdrakken Accord"],
            states = {
                { type = "faction", id = 2510, },
                { type = "currency", id = 2088, },
            },
            completed = "return states[2]:IsCapped()",
            text = [[
if self:IsCompleted() then
    return Images.COMPLETE
else
    return format("%s / %s (%d / %d)", states[1]:GetStandingQuantity(), states[1]:GetStandingMaxQuantity(), states[2]:GetQuantity(), states[2]:GetMaxQuantity())
end
]],
        },
        {
            id = "btwtodo:winterpeltfurbolg",
            name = L["Winterpelt Furbolg"],
            states = {
                { type = "faction", id = 2526, },
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
            id = "btwtodo:artisansconsortium",
            name = L["Artisan's Consortium"],
            version = 1,
            changeLog = {
                L["Updated to show faction rank"],
            },
            states = {
                { type = "faction", id = 2544, },
            },
            completed = [[
local ranks = {0, 500, 2500, 5500, 12500}
return Custom.GetFactionRank(states[1]:GetQuantity(), ranks) > 5
]],
            text = [[
if self:IsCompleted() then
    return Images.COMPLETE
else
    local ranks = {0, 500, 2500, 5500, 12500}
    local rank = Custom.GetFactionRank(states[1]:GetQuantity(), ranks)
    return format("%d / %d (%d / %d)", states[1]:GetStandingQuantity(), states[1]:GetStandingMaxQuantity(), rank, #ranks)
end
]],
        },
        {
            id = "btwtodo:cobaltassembly",
            name = L["Cobalt Assembly"],
            version = 1,
            changeLog = {
                L["Updated to show faction rank"],
            },
            states = {
                { type = "faction", id = 2550, },
            },
            completed = "return states[1]:IsCapped()",
            text = [[
if self:IsCompleted() then
    return Images.COMPLETE
else
    local ranks = {0, 300, 1200, 1360, 10000}
    local rank = Custom.GetFactionRank(states[1]:GetQuantity(), ranks)
    return format("%d / %d (%d / %d)", states[1]:GetStandingQuantity(), states[1]:GetStandingMaxQuantity(), rank, #ranks)
end
]],
        },
        {
            id = "btwtodo:sabellian",
            name = L["Sabellian"],
            version = 1,
            changeLog = {
                L["Updated to show faction rank"],
            },
            states = {
                { type = "faction", id = 2518, },
            },
            completed = "return states[1]:IsCapped()",
            text = [[
if self:IsCompleted() then
    return Images.COMPLETE
else
    local quantity, max = states[1]:GetStandingQuantity(), states[1]:GetStandingMaxQuantity()
    return format("%d / %d (%d / %d)", quantity, max, math.ceil(states[1]:GetQuantity() / 8400), math.ceil(states[1]:GetMaxQuantity() / 8400) + 1)
end
]],
        },
        {
            id = "btwtodo:wrathion",
            name = L["Wrathion"],
            version = 1,
            changeLog = {
                L["Updated to show faction rank"],
            },
            states = {
                { type = "faction", id = 2517, },
            },
            completed = "return states[1]:IsCapped()",
            text = [[
if self:IsCompleted() then
    return Images.COMPLETE
else
    local quantity, max = states[1]:GetStandingQuantity(), states[1]:GetStandingMaxQuantity()
    return format("%d / %d (%d / %d)", quantity, max, math.ceil(states[1]:GetQuantity() / 8400), math.ceil(states[1]:GetMaxQuantity() / 8400) + 1)
end
]],
        },
        {
            id = "btwtodo:dragonflightworldboss",
            name = L["World Boss"],
            version = 1,
            changeLog = {
                L["Added support for Basrikron"],
            },
            states = {
                { type = "quest", id = 69929, }, -- World Quest for Strunraan
                { type = "quest", id = 72055, }, -- Possible tracking quest for Strunraan
                
                { type = "quest", id = 69930, }, -- World Quest for Basrikron
                { type = "quest", id = 72056, }, -- Possible tracking quest for Basrikron
                
                { type = "quest", id = 69927, }, -- World Quest for Bazual
                { type = "quest", id = 72054, }, -- Possible tracking quest for Bazual
                
                { type = "quest", id = 69928, }, -- World Quest for Liskanoth
                { type = "quest", id = 72053, }, -- Possible tracking quest for Liskanoth
                { type = "quest", id = 72057, }, -- Possible tracking quest for Liskanoth
            },
            completed = [[return tCount(states, "IsCompleted") > 0]],
            text = DEFAULT_TEXT_FUNCTION,
        },
        {
            id = "btwtodo:aidingtheaccord",
            name = L["Aiding the Accord"],
            states = {
                { type = "quest", id = 70750, },
                { type = "quest", id = 72068, },
                { type = "quest", id = 72373, },
                { type = "quest", id = 72374, },
                { type = "quest", id = 72375, },
                { type = "quest", id = 75259, },
            },
            completed = [[return tCount(states, "IsCompleted") > 0]],
            text = DEFAULT_TEXT_FUNCTION,
        },
        {
            id = "btwtodo:dragonbanekeep",
            name = L["Siege of Dragonbane Keep"],
            states = {
                { type = "quest", id = 70866, },
            },
            completed = [[return tCount(states, "IsCompleted") > 0]],
            text = DEFAULT_TEXT_FUNCTION,
            tooltip = [[
tooltip:AddLine(self:GetName())

local active, duration = Custom.GetDragonbaneKeepCountdown()
if active then
    tooltip:AddLine(L["Active for"] .. " " .. Custom.FormatDuration(duration, 2), 1, 1, 1)
else
    tooltip:AddLine(L["Next event in"] .. " " .. Custom.FormatDuration(duration, 2), 1, 1, 1)
end
return 1
]],
        },
        {
            id = "btwtodo:grandhunts",
            name = L["Grand Hunts"],
            states = {
                { type = "quest", id = 70906, },
                { type = "quest", id = 71136, }, -- 70002??
                { type = "quest", id = 71137, },
            },
            completed = [[return tCount(states, "IsCompleted") == 3]],
            text = [[
return table.concat(tMap(states, function (_, state)
    return state:IsCompleted() and Images.COMPLETE or "-"
end), " / ")
]],
            tooltip = [[
tooltip:AddLine(self:GetName())

local duration = Custom.GetGrandHuntCountdown()
tooltip:AddLine(L["Moves in"] .. " " .. Custom.FormatDuration(duration, 2), 1, 1, 1)
return 1
]],
        },
        {
            id = "btwtodo:communityfeast",
            name = L["Community Feast"],
            states = {
                { type = "quest", id = 70893, },
                -- { type = "quest", id = 74097, }, -- Boss tracking quest
            },
            completed = [[return tCount(states, "IsCompleted") > 0]],
            text = [[
local state = states[1];
if state:IsCompleted() then
    return Images.COMPLETE
elseif state:IsComplete() then
    return Images.QUEST_TURN_IN
elseif state:IsActive() then
    local objectiveType = state:GetObjectiveType(1)
    local fulfilled, required = state:GetObjectiveProgress(1)
    local text
    if objectiveType == "progressbar" then
        text = format("%d%%", math.ceil(fulfilled / required * 100))
    else
        text = format("%d / %d", fulfilled, required)
    end
    return Colors.STALLED:WrapTextInColorCode(text)
else
    return "-"
end
]],
            tooltip = [[
tooltip:AddLine(self:GetName())

local active, duration = Custom.GetCommunityFeastCountdown()
if active then
    tooltip:AddLine(L["Active for"] .. " " .. Custom.FormatDuration(duration, 2), 1, 1, 1)
else
    tooltip:AddLine(L["Next event in"] .. " " .. Custom.FormatDuration(duration, 2), 1, 1, 1)
end
return 1
]],
        },
        {
            id = "btwtodo:trialoflements",
            name = L["Trial of Elements"],
            states = {
                { type = "quest", id = 71995, },
            },
            completed = [[return tCount(states, "IsCompleted") > 0]],
            text = DEFAULT_TEXT_FUNCTION,
        },
        {
            id = "btwtodo:trialoftides",
            name = L["Trial of Tides"],
            states = {
                { type = "quest", id = 71033, },
            },
            completed = [[return tCount(states, "IsCompleted") > 0]],
            text = DEFAULT_TEXT_FUNCTION,
        },
        {
            id = "btwtodo:fishinghole",
            name = L["Fishing Hole Dailies"],
            states = {
                { type = "quest", id = 70438, },

                { type = "quest", id = 70450, },

                { type = "quest", id = 71194, },

                { type = "quest", id = 72072, },
                { type = "quest", id = 72074, },
                { type = "quest", id = 72075, },
            },
            completed = [[return tCount(states, "IsCompleted") == 3]],
            text = DEFAULT_TEXT_FUNCTION,
            tooltip = DEFAULT_QUEST_TOOLTIP,
        },
        {
            id = "btwtodo:rivermouthfishingweeklies",
            name = L["River Mouth Fishing Weeklies"],
            states = {
                -- Catch and Release: Scalebelly Mackerel
                { type = "quest", id = 70199, },
                { type = "quest", id = 72828, },

                -- Catch and Release: Thousandbite Piranha
                { type = "quest", id = 70200, },
                { type = "quest", id = 72827, },

                -- Catch and Release: Aileron Seamoth
                { type = "quest", id = 70201, },
                { type = "quest", id = 72826, },

                -- Catch and Release: Cerulean Spinefish
                { type = "quest", id = 70202, },
                { type = "quest", id = 72825, },

                -- Catch and Release: Temporal Dragonhead
                { type = "quest", id = 70203, },
                { type = "quest", id = 72824, },

                -- Catch and Release: Islefin Dorado
                { type = "quest", id = 70935, },
                { type = "quest", id = 72823, },
            },
            completed = [[return tCount(states, "IsCompleted") == 6]],
            text = DEFAULT_TEXT_FUNCTION,
            tooltip = [[
tooltip:AddLine(self:GetName())
for i=1,#states,2 do
    local state = states[i+1]
    local name = states[i]:GetTitle()
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
    })

    External.RegisterLists({
        {
            id = "btwtodo:10",
            name = L["Dragonflight"],
            version = 3,
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
                    id = "btwtodo:dragonflyingglyphs",
                    category = "btwtodo:character",
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
                    id = "btwtodo:dragonflightworldboss",
                    category = "btwtodo:weekly",
                },
                {
                    id = "btwtodo:aidingtheaccord",
                    category = "btwtodo:weekly",
                    version = 2,
                },
                {
                    id = "btwtodo:dragonbanekeep",
                    category = "btwtodo:weekly",
                    version = 2,
                },
                {
                    id = "btwtodo:grandhunts",
                    category = "btwtodo:weekly",
                    version = 2,
                },
                {
                    id = "btwtodo:communityfeast",
                    category = "btwtodo:weekly",
                    version = 2,
                },
                {
                    id = "btwtodo:trialoflements",
                    category = "btwtodo:weekly",
                    version = 2,
                },
                {
                    id = "btwtodo:trialoftides",
                    category = "btwtodo:weekly",
                    version = 2,
                },
                {
                    id = "btwtodo:primalstorms",
                    category = "btwtodo:weekly",
                    version = 3,
                },
                {
                    id = "btwtodo:dragonislessupplies",
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
                    id = "btwtodo:blacksmithingprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:leatherworkingprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:alchemyprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:herbalismprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:miningprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:tailoringprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:engineeringprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:enchantingprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:skinningprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:jewelcraftingprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:inscriptionprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:elementaloverflow",
                    category = "btwtodo:currency",
                },
                {
                    id = "btwtodo:stormsigil",
                    category = "btwtodo:currency",
                },
                {
                    id = "btwtodo:dragonscaleexpedition",
                    category = "btwtodo:reputation",
                },
                {
                    id = "btwtodo:iskaaratuskarr",
                    category = "btwtodo:reputation",
                },
                {
                    id = "btwtodo:maruukcentaur",
                    category = "btwtodo:reputation",
                },
                {
                    id = "btwtodo:valdrakkenaccord",
                    category = "btwtodo:reputation",
                },
                {
                    id = "btwtodo:artisansconsortium",
                    category = "btwtodo:reputation",
                    hidden = true,
                },
                {
                    id = "btwtodo:cobaltassembly",
                    category = "btwtodo:reputation",
                    hidden = true,
                },
                {
                    id = "btwtodo:sabellian",
                    category = "btwtodo:reputation",
                    hidden = true,
                },
                {
                    id = "btwtodo:wrathion",
                    category = "btwtodo:reputation",
                    hidden = true,
                },
                {
                    id = "btwtodo:winterpeltfurbolg",
                    category = "btwtodo:reputation",
                    hidden = true,
                },
            },
        }
    })

    Internal.RegisterCustomStateFunction("GetFirstProfession", function ()
        local index = GetProfessions();
        local skillLineID = select(7, GetProfessionInfo(index));
        return skillLineID;
    end)
    Internal.RegisterCustomStateFunction("GetSecondProfession", function ()
        local _, index = GetProfessions();
        local skillLineID = select(7, GetProfessionInfo(index));
        return skillLineID;
    end)
    local skillLineToKnowledgeCurrency = {
        [164] = 2023, -- Blacksmithing
        [165] = 2025, -- Leatherworking
        [171] = 2024, -- Alchemy
        [182] = 2034, -- Herbalism
        -- [185] = TEMP, -- Cooking
        [186] = 2035, -- Mining
        [197] = 2026, -- Tailoring
        [202] = 2027, -- Engineering
        [333] = 2030, -- Enchanting
        -- [356] = TEMP, -- Fishing
        [393] = 2033, -- Skinning
        [755] = 2029, -- Jewelcrafting
        [773] = 2028, -- Inscription
    }
    Internal.RegisterCustomStateFunction("GetProfessionKnowledgeCurrency", function (skillLineID)
        return skillLineToKnowledgeCurrency[skillLineID];
    end)
end

if Internal.Is110000OrBeyond then
    External.RegisterTodos({
        {
            id = "btwtodo:kej",
            name = L["Kej"],
            states = {
                { type = "currency", id = 3750, },
            },
            completed = "return false",
            text = [[return states[1]:GetQuantity()]],
        },
        {
            id = "btwtodo:resonancecrystals",
            name = L["Resonance Crystals"],
            states = {
                { type = "currency", id = 2815, },
            },
            completed = "return false",
            text = [[return states[1]:GetQuantity()]],
        },
        {
            id = "btwtodo:undercoin",
            name = L["Undercoin"],
            states = {
                { type = "currency", id = 2803, },
            },
            completed = "return false",
            text = [[return states[1]:GetQuantity()]],
        },
        {
            id = "btwtodo:valorstones",
            name = L["Valorstones"],
            states = {
                { type = "currency", id = 3008, },
            },
            completed = "return false",
            text = [[
if states[1]:GetMaxQuantity() ~= 0 then
    return format("%s / %s", states[1]:GetQuantity(), states[1]:GetMaxQuantity())
else
    return format("%s", states[1]:GetQuantity())
end
]],
        },
        {
            id = "btwtodo:weatheredharbingercrest",
            name = L["Weathered Harbinger Crest"],
            states = {
                { type = "currency", id = 2914, },
            },
            completed = "return false",
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
            id = "btwtodo:carvedharbingercrest",
            name = L["Carved  Harbinger Crest"],
            states = {
                { type = "currency", id = 2915, },
            },
            completed = "return false",
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
            id = "btwtodo:runedharbingercrest",
            name = L["Runed Harbinger Crest"],
            states = {
                { type = "currency", id = 2916, },
            },
            completed = "return false",
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
            id = "btwtodo:gildedharbingercrest",
            name = L["Gilded Harbinger Crest"],
            states = {
                { type = "currency", id = 2917, },
            },
            completed = "return false",
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
            id = "btwtodo:councilofdornogal",
            name = L["Council of Dornogal"],
            states = {
                { type = "faction", id = 2590, },
                { type = "currency", id = 2900, },
            },
            completed = "return states[2]:IsCapped()",
            text = [[
if self:IsCompleted() then
    return Images.COMPLETE
else
    return format("%s / %s (%d / %d)", states[1]:GetStandingQuantity(), states[1]:GetStandingMaxQuantity(), states[2]:GetQuantity(), states[2]:GetMaxQuantity())
end
]],
        },
        {
            id = "btwtodo:theassemblyofthedeeps",
            name = L["The Assembly of the Deeps"],
            states = {
                { type = "faction", id = 2594, },
                { type = "currency", id = 2898, },
            },
            completed = "return states[2]:IsCapped()",
            text = [[
if self:IsCompleted() then
    return Images.COMPLETE
else
    return format("%s / %s (%d / %d)", states[1]:GetStandingQuantity(), states[1]:GetStandingMaxQuantity(), states[2]:GetQuantity(), states[2]:GetMaxQuantity())
end
]],
        },
        {
            id = "btwtodo:hallowfallarathi",
            name = L["Hallowfall Arathi"],
            states = {
                { type = "faction", id = 2570, },
                { type = "currency", id = 2901, },
            },
            completed = "return states[2]:IsCapped()",
            text = [[
if self:IsCompleted() then
    return Images.COMPLETE
else
    return format("%s / %s (%d / %d)", states[1]:GetStandingQuantity(), states[1]:GetStandingMaxQuantity(), states[2]:GetQuantity(), states[2]:GetMaxQuantity())
end
]],
        },
        {
            id = "btwtodo:theseveredthreads",
            name = L["The Severed Threads"],
            states = {
                { type = "faction", id = 2600, },
                { type = "currency", id = 2904, },
                { type = "faction", id = 2605, },
                { type = "faction", id = 2607, },
                { type = "faction", id = 2601, },
            },
            completed = "return states[2]:IsCapped()",
            text = [[
if self:IsCompleted() then
    return Images.COMPLETE
else
    return format("%d / %d", states[2]:GetQuantity(), states[2]:GetMaxQuantity())
end
]],
tooltip = [[
tooltip:AddLine(self:GetName())
tooltip:AddLine(format(L["%s: %d / %d"], states[3]:GetName(),  states[3]:GetStandingQuantity(), states[3]:GetStandingMaxQuantity()), 1, 1, 1)
tooltip:AddLine(format(L["%s: %d / %d"], states[4]:GetName(),  states[4]:GetStandingQuantity(), states[4]:GetStandingMaxQuantity()), 1, 1, 1)
tooltip:AddLine(format(L["%s: %d / %d"], states[5]:GetName(),  states[5]:GetStandingQuantity(), states[5]:GetStandingMaxQuantity()), 1, 1, 1)
]],
        },



        {
            id = "btwtodo:brannbronzebeard",
            name = L["Brann Bronzebeard"],
            states = {
                { type = "faction", id = 2640, },
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


        -- {
        --     id = "btwtodo:thewarwithinworldboss",
        --     name = L["World Boss"],
        --     states = {
        --         { type = "quest", id = , }, -- World Quest for Kordac, the Dormant Protector
        --         { type = "quest", id = , }, -- Possible tracking quest for Kordac, the Dormant Protector
                
        --         { type = "quest", id = , }, -- World Quest for Aggregation of Horrors
        --         { type = "quest", id = , }, -- Possible tracking quest for Aggregation of Horrors
                
        --         { type = "quest", id = , }, -- World Quest for Shurrai, Atrocity of the Undersea
        --         { type = "quest", id = , }, -- Possible tracking quest for Shurrai, Atrocity of the Undersea
                
        --         { type = "quest", id = , }, -- World Quest for Orta, the Broken Mountain
        --         { type = "quest", id = , }, -- Possible tracking quest for Orta, the Broken Mountain
        --     },
        --     completed = [[return tCount(states, "IsCompleted") > 0]],
        --     text = DEFAULT_TEXT_FUNCTION,
        -- },
    })

    External.RegisterLists({
        {
            id = "btwtodo:110",
            name = L["The War Within"],
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
                    id = "btwtodo:dragonflyingglyphs",
                    category = "btwtodo:character",
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
                -- {
                --     id = "btwtodo:thewarwithinworldboss",
                --     category = "btwtodo:weekly",
                -- },
                {
                    id = "btwtodo:weatheredharbingercrest",
                    category = "btwtodo:currency",
                },
                {
                    id = "btwtodo:carvedharbingercrest",
                    category = "btwtodo:currency",
                },
                {
                    id = "btwtodo:runedharbingercrest",
                    category = "btwtodo:currency",
                },
                {
                    id = "btwtodo:gildedharbingercrest",
                    category = "btwtodo:currency",
                },
                {
                    id = "btwtodo:valorstones",
                    category = "btwtodo:currency",
                },
                {
                    id = "btwtodo:conquest",
                    category = "btwtodo:currency",
                },
                {
                    id = "btwtodo:blacksmithingprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:leatherworkingprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:alchemyprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:herbalismprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:miningprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:tailoringprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:engineeringprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:enchantingprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:skinningprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:jewelcraftingprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:inscriptionprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:kej",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:resonancecrystals",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:undercoin",
                    category = "btwtodo:currency",
                    hidden = true,
                },

                {
                    id = "btwtodo:councilofdornogal",
                    category = "btwtodo:reputation",
                },
                {
                    id = "btwtodo:theassemblyofthedeeps",
                    category = "btwtodo:reputation",
                },
                {
                    id = "btwtodo:hallowfallarathi",
                    category = "btwtodo:reputation",
                },
                {
                    id = "btwtodo:theseveredthreads",
                    category = "btwtodo:reputation",
                },
                {
                    id = "btwtodo:brannbronzebeard",
                    category = "btwtodo:reputation",
                    hidden = true,
                },
            },
        }
    })
end

if Internal.Is110100OrBeyond then
    External.RegisterTodos({
        {
            id = "btwtodo:weatheredunderminecrest",
            name = L["Weathered Undermine Crest"],
            states = {
                { type = "currency", id = 3107, },
            },
            completed = "return false",
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
            id = "btwtodo:carvedunderminecrest",
            name = L["Carved  Undermine Crest"],
            states = {
                { type = "currency", id = 3108, },
            },
            completed = "return false",
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
            id = "btwtodo:runedunderminecrest",
            name = L["Runed Undermine Crest"],
            states = {
                { type = "currency", id = 3109, },
            },
            completed = "return false",
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
            id = "btwtodo:gildedunderminecrest",
            name = L["Gilded Undermine Crest"],
            states = {
                { type = "currency", id = 3110, },
            },
            completed = "return false",
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
            id = "btwtodo:thecartelsofundermine",
            name = L["The Cartels of Undermine"],
            states = {
                { type = "faction", id = 2653, },
                { type = "currency", id = 3120, },
            },
            completed = "return states[2]:IsCapped()",
            text = [[
if self:IsCompleted() then
    return Images.COMPLETE
else
    return format("%s / %s (%d / %d)", states[1]:GetStandingQuantity(), states[1]:GetStandingMaxQuantity(), states[2]:GetQuantity(), states[2]:GetMaxQuantity())
end
]],
        },
    })

    External.RegisterLists({
        {
            id = "btwtodo:111",
            name = L["Undermined"],
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
                    id = "btwtodo:dragonflyingglyphs",
                    category = "btwtodo:character",
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
                -- {
                --     id = "btwtodo:thewarwithinworldboss",
                --     category = "btwtodo:weekly",
                -- },
                {
                    id = "btwtodo:weatheredunderminecrest",
                    category = "btwtodo:currency",
                },
                {
                    id = "btwtodo:carvedunderminecrest",
                    category = "btwtodo:currency",
                },
                {
                    id = "btwtodo:runedunderminecrest",
                    category = "btwtodo:currency",
                },
                {
                    id = "btwtodo:gildedunderminecrest",
                    category = "btwtodo:currency",
                },
                {
                    id = "btwtodo:valorstones",
                    category = "btwtodo:currency",
                },
                {
                    id = "btwtodo:conquest",
                    category = "btwtodo:currency",
                },
                {
                    id = "btwtodo:blacksmithingprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:leatherworkingprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:alchemyprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:herbalismprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:miningprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:tailoringprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:engineeringprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:enchantingprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:skinningprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:jewelcraftingprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:inscriptionprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:kej",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:resonancecrystals",
                    category = "btwtodo:currency",
                    hidden = true,
                },
                {
                    id = "btwtodo:undercoin",
                    category = "btwtodo:currency",
                    hidden = true,
                },

                {
                    id = "btwtodo:councilofdornogal",
                    category = "btwtodo:reputation",
                },
                {
                    id = "btwtodo:theassemblyofthedeeps",
                    category = "btwtodo:reputation",
                },
                {
                    id = "btwtodo:hallowfallarathi",
                    category = "btwtodo:reputation",
                },
                {
                    id = "btwtodo:theseveredthreads",
                    category = "btwtodo:reputation",
                },
                {
                    id = "btwtodo:thecartelsofundermine",
                    category = "btwtodo:reputation",
                },
                {
                    id = "btwtodo:brannbronzebeard",
                    category = "btwtodo:reputation",
                    hidden = true,
                },
            },
        }
    })
end

-- Update default list based on patch/season
if Internal.IsShadowlandsSeason2 then
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
elseif Internal.IsShadowlandsSeason3 then
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
    });
elseif Internal.IsDragonflightSeason1 or Internal.IsDragonflightSeason2 or Internal.IsDragonflightSeason3 or Internal.IsDragonflightSeason4 then
    External.RegisterLists({
        {
            id = "btwtodo:default",
            name = L["Default"],
            version = 10,
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
                    hidden = true,
                    version = 8,
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
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:dragonflyingglyphs",
                    category = "btwtodo:character",
                    version = 8,
                },
                {
                    id = "btwtodo:callings",
                    category = "btwtodo:daily",
                    hidden = true,
                    version = 8,
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
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:dragonflightworldboss",
                    category = "btwtodo:weekly",
                    version = 8,
                },
                {
                    id = "btwtodo:aidingtheaccord",
                    category = "btwtodo:weekly",
                    version = 9,
                },
                {
                    id = "btwtodo:dragonbanekeep",
                    category = "btwtodo:weekly",
                    version = 9,
                },
                {
                    id = "btwtodo:grandhunts",
                    category = "btwtodo:weekly",
                    version = 9,
                },
                {
                    id = "btwtodo:communityfeast",
                    category = "btwtodo:weekly",
                    version = 9,
                },
                {
                    id = "btwtodo:trialoflements",
                    category = "btwtodo:weekly",
                    version = 9,
                },
                {
                    id = "btwtodo:trialoftides",
                    category = "btwtodo:weekly",
                    version = 9,
                },
                {
                    id = "btwtodo:primalstorms",
                    category = "btwtodo:weekly",
                    version = 10,
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
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:bonusevents",
                    category = "btwtodo:weekly",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:cosmicflux",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:cyphersofthefirstones",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:anima",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:soulcinders",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:dragonislessupplies",
                    category = "btwtodo:currency",
                    version = 8,
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
                    id = "btwtodo:blacksmithingprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:leatherworkingprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:alchemyprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:herbalismprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:miningprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:tailoringprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:engineeringprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:enchantingprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:skinningprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:jewelcraftingprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:inscriptionprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:elementaloverflow",
                    category = "btwtodo:currency",
                    version = 8,
                },
                {
                    id = "btwtodo:stormsigil",
                    category = "btwtodo:currency",
                    version = 8,
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
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:dragonscaleexpedition",
                    category = "btwtodo:reputation",
                    version = 8,
                },
                {
                    id = "btwtodo:iskaaratuskarr",
                    category = "btwtodo:reputation",
                    version = 8,
                },
                {
                    id = "btwtodo:maruukcentaur",
                    category = "btwtodo:reputation",
                    version = 8,
                },
                {
                    id = "btwtodo:valdrakkenaccord",
                    category = "btwtodo:reputation",
                    version = 8,
                },
                {
                    id = "btwtodo:artisansconsortium",
                    category = "btwtodo:reputation",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:cobaltassembly",
                    category = "btwtodo:reputation",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:sabellian",
                    category = "btwtodo:reputation",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:wrathion",
                    category = "btwtodo:reputation",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:winterpeltfurbolg",
                    category = "btwtodo:reputation",
                    hidden = true,
                    version = 8,
                },
            },
        },
    });
elseif Internal.IsTheWarWithinSeason1 then
    External.RegisterLists({
        {
            id = "btwtodo:default",
            name = L["Default"],
            version = 15,
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
                    hidden = true,
                    version = 8,
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
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:dragonflyingglyphs",
                    category = "btwtodo:character",
                    version = 8,
                },

                -- Daily
                {
                    id = "btwtodo:callings",
                    category = "btwtodo:daily",
                    hidden = true,
                    version = 8,
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

                -- Weekly
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
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:dragonflightworldboss",
                    category = "btwtodo:weekly",
                    hidden = true,
                    version = 15,
                },
                -- {
                --     id = "btwtodo:thewarwithinworldboss",
                --     category = "btwtodo:weekly",
                -- },
                {
                    id = "btwtodo:aidingtheaccord",
                    category = "btwtodo:weekly",
                    hidden = true,
                    version = 15,
                },
                {
                    id = "btwtodo:dragonbanekeep",
                    category = "btwtodo:weekly",
                    hidden = true,
                    version = 15,
                },
                {
                    id = "btwtodo:grandhunts",
                    category = "btwtodo:weekly",
                    hidden = true,
                    version = 15,
                },
                {
                    id = "btwtodo:communityfeast",
                    category = "btwtodo:weekly",
                    hidden = true,
                    version = 15,
                },
                {
                    id = "btwtodo:trialoflements",
                    category = "btwtodo:weekly",
                    hidden = true,
                    version = 15,
                },
                {
                    id = "btwtodo:trialoftides",
                    category = "btwtodo:weekly",
                    hidden = true,
                    version = 15,
                },
                {
                    id = "btwtodo:primalstorms",
                    category = "btwtodo:weekly",
                    hidden = true,
                    version = 15,
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
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:bonusevents",
                    category = "btwtodo:weekly",
                    hidden = true,
                    version = 8,
                },

                -- Currency
                {
                    id = "btwtodo:cosmicflux",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:cyphersofthefirstones",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:anima",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:soulcinders",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:dragonislessupplies",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 15,
                },
                {
                    id = "btwtodo:weatheredharbingercrest",
                    category = "btwtodo:currency",
                    version = 15,
                },
                {
                    id = "btwtodo:carvedharbingercrest",
                    category = "btwtodo:currency",
                    version = 15,
                },
                {
                    id = "btwtodo:runedharbingercrest",
                    category = "btwtodo:currency",
                    version = 15,
                },
                {
                    id = "btwtodo:gildedharbingercrest",
                    category = "btwtodo:currency",
                    version = 15,
                },
                {
                    id = "btwtodo:weatheredunderminecrest",
                    category = "btwtodo:currency",
                },
                {
                    id = "btwtodo:carvedunderminecrest",
                    category = "btwtodo:currency",
                },
                {
                    id = "btwtodo:runedunderminecrest",
                    category = "btwtodo:currency",
                },
                {
                    id = "btwtodo:gildedunderminecrest",
                    category = "btwtodo:currency",
                },
                {
                    id = "btwtodo:valorstones",
                    category = "btwtodo:currency",
                    version = 15,
                },
                {
                    id = "btwtodo:valor",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 15,
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
                    id = "btwtodo:blacksmithingprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:leatherworkingprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:alchemyprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:herbalismprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:miningprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:tailoringprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:engineeringprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:enchantingprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:skinningprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:jewelcraftingprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:inscriptionprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:elementaloverflow",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 15,
                },
                {
                    id = "btwtodo:stormsigil",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 15,
                },
                {
                    id = "btwtodo:kej",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 15,
                },
                {
                    id = "btwtodo:resonancecrystals",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 15,
                },
                {
                    id = "btwtodo:undercoin",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 15,
                },

                -- Reputation
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
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:dragonscaleexpedition",
                    category = "btwtodo:reputation",
                    hidden = true,
                    version = 15,
                },
                {
                    id = "btwtodo:iskaaratuskarr",
                    category = "btwtodo:reputation",
                    hidden = true,
                    version = 15,
                },
                {
                    id = "btwtodo:maruukcentaur",
                    category = "btwtodo:reputation",
                    hidden = true,
                    version = 15,
                },
                {
                    id = "btwtodo:valdrakkenaccord",
                    category = "btwtodo:reputation",
                    hidden = true,
                    version = 15,
                },
                {
                    id = "btwtodo:artisansconsortium",
                    category = "btwtodo:reputation",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:cobaltassembly",
                    category = "btwtodo:reputation",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:sabellian",
                    category = "btwtodo:reputation",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:wrathion",
                    category = "btwtodo:reputation",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:winterpeltfurbolg",
                    category = "btwtodo:reputation",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:councilofdornogal",
                    category = "btwtodo:reputation",
                    version = 15,
                },
                {
                    id = "btwtodo:theassemblyofthedeeps",
                    category = "btwtodo:reputation",
                    version = 15,
                },
                {
                    id = "btwtodo:hallowfallarathi",
                    category = "btwtodo:reputation",
                    version = 15,
                },
                {
                    id = "btwtodo:theseveredthreads",
                    category = "btwtodo:reputation",
                    version = 15,
                },
                {
                    id = "btwtodo:brannbronzebeard",
                    category = "btwtodo:reputation",
                    hidden = true,
                    version = 15,
                },
            },
        },
    });
elseif Internal.IsTheWarWithinSeason2 then
    External.RegisterLists({
        {
            id = "btwtodo:default",
            name = L["Default"],
            version = 16,
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
                    hidden = true,
                    version = 8,
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
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:dragonflyingglyphs",
                    category = "btwtodo:character",
                    version = 8,
                },

                -- Daily
                {
                    id = "btwtodo:callings",
                    category = "btwtodo:daily",
                    hidden = true,
                    version = 8,
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

                -- Weekly
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
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:dragonflightworldboss",
                    category = "btwtodo:weekly",
                    hidden = true,
                    version = 15,
                },
                -- {
                --     id = "btwtodo:thewarwithinworldboss",
                --     category = "btwtodo:weekly",
                -- },
                {
                    id = "btwtodo:aidingtheaccord",
                    category = "btwtodo:weekly",
                    hidden = true,
                    version = 15,
                },
                {
                    id = "btwtodo:dragonbanekeep",
                    category = "btwtodo:weekly",
                    hidden = true,
                    version = 15,
                },
                {
                    id = "btwtodo:grandhunts",
                    category = "btwtodo:weekly",
                    hidden = true,
                    version = 15,
                },
                {
                    id = "btwtodo:communityfeast",
                    category = "btwtodo:weekly",
                    hidden = true,
                    version = 15,
                },
                {
                    id = "btwtodo:trialoflements",
                    category = "btwtodo:weekly",
                    hidden = true,
                    version = 15,
                },
                {
                    id = "btwtodo:trialoftides",
                    category = "btwtodo:weekly",
                    hidden = true,
                    version = 15,
                },
                {
                    id = "btwtodo:primalstorms",
                    category = "btwtodo:weekly",
                    hidden = true,
                    version = 15,
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
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:bonusevents",
                    category = "btwtodo:weekly",
                    hidden = true,
                    version = 8,
                },

                -- Currency
                {
                    id = "btwtodo:cosmicflux",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:cyphersofthefirstones",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:anima",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:soulcinders",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:dragonislessupplies",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 15,
                },
                {
                    id = "btwtodo:weatheredharbingercrest",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 16,
                },
                {
                    id = "btwtodo:carvedharbingercrest",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 16,
                },
                {
                    id = "btwtodo:runedharbingercrest",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 16,
                },
                {
                    id = "btwtodo:gildedharbingercrest",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 16,
                },
                {
                    id = "btwtodo:weatheredunderminecrest",
                    category = "btwtodo:currency",
                    version = 16,
                },
                {
                    id = "btwtodo:carvedunderminecrest",
                    category = "btwtodo:currency",
                    version = 16,
                },
                {
                    id = "btwtodo:runedunderminecrest",
                    category = "btwtodo:currency",
                    version = 16,
                },
                {
                    id = "btwtodo:gildedunderminecrest",
                    category = "btwtodo:currency",
                    version = 16,
                },
                {
                    id = "btwtodo:valorstones",
                    category = "btwtodo:currency",
                    version = 15,
                },
                {
                    id = "btwtodo:valor",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 15,
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
                    id = "btwtodo:blacksmithingprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:leatherworkingprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:alchemyprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:herbalismprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:miningprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:tailoringprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:engineeringprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:enchantingprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:skinningprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:jewelcraftingprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:inscriptionprofessionknowledge",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:elementaloverflow",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 15,
                },
                {
                    id = "btwtodo:stormsigil",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 15,
                },
                {
                    id = "btwtodo:kej",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 15,
                },
                {
                    id = "btwtodo:resonancecrystals",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 15,
                },
                {
                    id = "btwtodo:undercoin",
                    category = "btwtodo:currency",
                    hidden = true,
                    version = 15,
                },

                -- Reputation
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
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:dragonscaleexpedition",
                    category = "btwtodo:reputation",
                    hidden = true,
                    version = 15,
                },
                {
                    id = "btwtodo:iskaaratuskarr",
                    category = "btwtodo:reputation",
                    hidden = true,
                    version = 15,
                },
                {
                    id = "btwtodo:maruukcentaur",
                    category = "btwtodo:reputation",
                    hidden = true,
                    version = 15,
                },
                {
                    id = "btwtodo:valdrakkenaccord",
                    category = "btwtodo:reputation",
                    hidden = true,
                    version = 15,
                },
                {
                    id = "btwtodo:artisansconsortium",
                    category = "btwtodo:reputation",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:cobaltassembly",
                    category = "btwtodo:reputation",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:sabellian",
                    category = "btwtodo:reputation",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:wrathion",
                    category = "btwtodo:reputation",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:winterpeltfurbolg",
                    category = "btwtodo:reputation",
                    hidden = true,
                    version = 8,
                },
                {
                    id = "btwtodo:councilofdornogal",
                    category = "btwtodo:reputation",
                    version = 15,
                },
                {
                    id = "btwtodo:theassemblyofthedeeps",
                    category = "btwtodo:reputation",
                    version = 15,
                },
                {
                    id = "btwtodo:hallowfallarathi",
                    category = "btwtodo:reputation",
                    version = 15,
                },
                {
                    id = "btwtodo:theseveredthreads",
                    category = "btwtodo:reputation",
                    version = 15,
                },
                {
                    id = "btwtodo:thecartelsofundermine",
                    category = "btwtodo:reputation",
                    version = 16,
                },
                {
                    id = "btwtodo:brannbronzebeard",
                    category = "btwtodo:reputation",
                    hidden = true,
                    version = 15,
                },
            },
        },
    });
end