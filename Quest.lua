--[[
    State provider for quests
]]

local ADDON_NAME, Internal = ...
local External = _G[ADDON_NAME]
local L = Internal.L

local QuestFrequencyHalfWeekly = 3

local questMapNameToID = {}

local specialEventQuests = {
	-- [63854] = "", -- Tormentors

	-- Relic Cache
	[64316] = "LOOT_READY",
	[64317] = "LOOT_READY",
	[64318] = "LOOT_READY",
	[64564] = "LOOT_READY",
	[64565] = "LOOT_READY",

	-- Nest of Unusual Materials
	[64358] = "LOOT_READY",
	[64359] = "LOOT_READY",
	[64360] = "LOOT_READY",
	[64361] = "LOOT_READY",
	[64362] = "LOOT_READY",

	-- Invasive Mawshroom
	[64351] = "LOOT_READY",
	[64354] = "LOOT_READY",
	[64355] = "LOOT_READY",
	[64356] = "LOOT_READY",
	[64357] = "LOOT_READY",

	-- Mawsworn Cache
	[64021] = "LOOT_READY",
	[64363] = "LOOT_READY",
	[64364] = "LOOT_READY",

	-- Spectral Bound Chest
	[64247] = "LOOT_READY",
	[64248] = "CRITERIA_UPDATE",
	[64249] = "CRITERIA_UPDATE",
	[64250] = "CRITERIA_UPDATE",

	-- Riftbound Chest
    [64470] = "LOOT_READY",
    [64471] = "LOOT_READY",
    [64472] = "LOOT_READY",
    [64456] = "LOOT_READY",

	-- Death-Bound Shard
	[64347] = "CHAT_MSG_LOOT",
}

local QuestMixin = CreateFromMixins(External.StateMixin)
function QuestMixin:Init(questID)
	External.StateMixin.Init(self, questID)

    if Internal.data and Internal.data.quests and Internal.data.quests[questID] then
		Mixin(self, Internal.data.quests[questID]);
    end
    if BtWTodoCache.quests[questID] then
		Mixin(self, BtWTodoCache.quests[questID]);
    end

	local questLogIndex = C_QuestLog.GetLogIndexForQuestID(questID); -- may not exist, if it doesn't then you get minimal info
	if questLogIndex then
		Mixin(self, C_QuestLog.GetInfo(questLogIndex));

		-- Remove all dynamic data that could become stale
		self.questLogIndex = nil;
		self.isOnMap = nil;
		self.isCollapsed = nil;
		self.hasLocalPOI = nil;

        -- Used for data that is only available while the quest is in the log
		if self.frequency ~= Enum.QuestFrequency.Default and (not Internal.data.quests[questID] or not Internal.data.quests[questID].authority) then
			Internal.data.quests[questID] = {
				frequency = self.frequency
			}
		end
	end

	self.title = "";
	self.isRepeatable = false;
	self.isLegendary = false;
	self.objectives = nil;

	QuestEventListener:AddCallback(questID, function()
		self.title = QuestUtils_GetQuestName(questID);
		self.isRepeatable = C_QuestLog.IsRepeatableQuest(questID);
		self.isLegendary = C_QuestLog.IsLegendaryQuest(questID);
		self.objectives = C_QuestLog.GetQuestObjectives(questID);
		for _,objective in ipairs(self.objectives) do
			objective.numFulfilled = nil
			objective.finished = nil
		end
	end);
end
function QuestMixin:GetDisplayName(supportCallback)
	local title = self:GetTitle()
	if title == "" and supportCallback then
		local callback, result = nil, nil
		QuestEventListener:AddCallback(self:GetID(), function()
			title = self:GetTitle()
			result = string.format(L["Quest: %s"], title ~= "" and title or self:GetID())
			if callback then
				callback(result)
			end
		end);
		return function (func)
			callback = func
			if result then
				callback(result)
			else
				callback(string.format(L["Quest: %s"], self:GetID()))
			end
		end
	else
		return string.format(L["Quest: %s"], title ~= "" and title or self:GetID())
	end
end
function QuestMixin:GetUniqueKey()
	return "quest:" .. self:GetID()
end
function QuestMixin:GetTitle()
	return self.title
end
function QuestMixin:IsActive()
	if self:GetCharacter():IsPlayer() then
		return C_QuestLog.GetLogIndexForQuestID(self:GetID()) ~= nil;
	else
		return self:GetCharacter():GetData("questLog", self:GetID()) ~= nil
	end
end
function QuestMixin:IsComplete()
	if self:GetCharacter():IsPlayer() then
		return C_QuestLog.IsComplete(self:GetID());
	else
		return self:GetCharacter():GetData("questLog", self:GetID()) == true
	end
end
function QuestMixin:IsCompleted()
	if self:GetCharacter():IsPlayer() then
		return C_QuestLog.IsQuestFlaggedCompleted(self:GetID());
	else
		return self:GetCharacter():GetData("questCompleted", self:GetID())
	end
end
function QuestMixin:IsCampaign()
	return self:GetCampaignID() ~= 0;
end
function QuestMixin:GetCampaignID()
	if self.campaignID == nil then
		self.campaignID = C_CampaignInfo.GetCampaignID(self:GetID());
	end

	return self.campaignID;
end
function QuestMixin:IsCalling()
	if self.isCalling == nil then
		self.isCalling = C_QuestLog.IsQuestCalling(self:GetID());
	end

	return self.isCalling;
end
function QuestMixin:IsRepeatableQuest()
	return self.isRepeatable;
end
function QuestMixin:IsLegendary()
	return self.isLegendary;
end
function QuestMixin:GetNumObjectives()
	return #self.objectives;
end
function QuestMixin:GetObjectives()
	return self.objectives;
end
function QuestMixin:GetObjective(index)
	return self:GetObjectives()[index];
end
function QuestMixin:GetObjectiveFulfilled(index)
	if self:GetCharacter():IsPlayer() then
		return (select(4, GetQuestObjectiveInfo(self:GetID(), index, false)))
	else
		return 0
	end
end
function QuestMixin:RegisterEventsFor(driver)
	if self:GetCharacter():IsRemote() then
		self:GetCharacter():RegisterRemoteEvents(driver, "questLog", "questCompleted")
	else
		driver:RegisterEvents("PLAYER_ENTERING_WORLD", "QUEST_TURNED_IN", "QUEST_REMOVED", "QUEST_ACCEPTED", "DAILY_RESET", "HALF_WEEKLY_RESET")
		if specialEventQuests[self:GetID()] then
			driver:RegisterEvents(specialEventQuests[self:GetID()])
		end
	end
end

local QuestProviderMixin = CreateFromMixins(External.StateProviderMixin)
function QuestProviderMixin:GetID()
	return "quest"
end
function QuestProviderMixin:GetName()
	return L["Quest"]
end
function QuestProviderMixin:GetAddTitle()
	return string.format(BTWTODO_ADD_ITEM, self:GetName()), L["Enter the quest name or id below"]
end
function QuestProviderMixin:Acquire(...)
	return CreateAndInitFromMixin(QuestMixin, ...)
end
function QuestProviderMixin:GetFunctions()
	return {
		{
			name = "GetTitle",
			returnValue = "string",
			description = L["Quest title"]
		},
		{
			name = "IsComplete",
			returnValue = "bool",
			description = L["Quest is ready to hand in"]
		},
		{
			name = "IsCompleted",
			returnValue = "bool",
			description = L["Is the quest flagged as completed"]
		},
	}
end
function QuestProviderMixin:GetDefaults()
	return { -- Completed Default
		{"IsCompleted"}
	}, nil -- Text Default
end
function QuestProviderMixin:ParseInput(value)
	local num = tonumber(value)
	if num ~= nil then
		return true, num
	end
	if questMapNameToID[value] then
        return true, questMapNameToID[value]
    end
	return false, L["Unknown quest"]
end
function QuestProviderMixin:FillAutoComplete(tbl, text, offset, length)
    local text = strsub(text, offset, length):lower()
    for value in pairs(questMapNameToID) do
        local name = value:lower()
        if #name >= #text and strsub(name, offset, length) == text then
            tbl[#tbl+1] = value
        end
    end
    table.sort(tbl)
end
Internal.RegisterStateProvider(CreateFromMixins(QuestProviderMixin))

-- Set up quest cache
local questData = {
	-- 9.1 Covenant assaults
	[63543] = {frequency = QuestFrequencyHalfWeekly, authority = true},
	[63822] = {frequency = QuestFrequencyHalfWeekly, authority = true},
	[63823] = {frequency = QuestFrequencyHalfWeekly, authority = true},
	[63824] = {frequency = QuestFrequencyHalfWeekly, authority = true},

	-- World Boss
	[64547] = {frequency = Enum.QuestFrequency.Weekly, authority = true},

	-- Tormentors of Torghast
	[63854] = {frequency = Enum.QuestFrequency.Weekly, authority = true},

	-- Korthia Dailies
	[64271] = {frequency = Enum.QuestFrequency.Daily},
	[63783] = {frequency = Enum.QuestFrequency.Daily},
	[63779] = {frequency = Enum.QuestFrequency.Daily},
	[63934] = {frequency = Enum.QuestFrequency.Daily},
	[63793] = {frequency = Enum.QuestFrequency.Daily},
	[63964] = {frequency = Enum.QuestFrequency.Daily},
	[63794] = {frequency = Enum.QuestFrequency.Daily},
	[63790] = {frequency = Enum.QuestFrequency.Daily},
	[63792] = {frequency = Enum.QuestFrequency.Daily},
	[63963] = {frequency = Enum.QuestFrequency.Daily},
	[63791] = {frequency = Enum.QuestFrequency.Daily},
	[64129] = {frequency = Enum.QuestFrequency.Daily},
	[63787] = {frequency = Enum.QuestFrequency.Daily},
	[63788] = {frequency = Enum.QuestFrequency.Daily},
	[63789] = {frequency = Enum.QuestFrequency.Daily},
	[63785] = {frequency = Enum.QuestFrequency.Daily},
	[63775] = {frequency = Enum.QuestFrequency.Daily},
	[63936] = {frequency = Enum.QuestFrequency.Daily},
	[64080] = {frequency = Enum.QuestFrequency.Daily},
	[64240] = {frequency = Enum.QuestFrequency.Daily},
	[63784] = {frequency = Enum.QuestFrequency.Daily},
	[64015] = {frequency = Enum.QuestFrequency.Daily},
	[64065] = {frequency = Enum.QuestFrequency.Daily},
	[63781] = {frequency = Enum.QuestFrequency.Daily},
	[63782] = {frequency = Enum.QuestFrequency.Daily},
	[63937] = {frequency = Enum.QuestFrequency.Daily},
	[63962] = {frequency = Enum.QuestFrequency.Daily},
	[63959] = {frequency = Enum.QuestFrequency.Daily},
	[63776] = {frequency = Enum.QuestFrequency.Daily},
	[63957] = {frequency = Enum.QuestFrequency.Daily},
	[63958] = {frequency = Enum.QuestFrequency.Daily},
	[63960] = {frequency = Enum.QuestFrequency.Daily},
	[64103] = {frequency = Enum.QuestFrequency.Daily},
	[64040] = {frequency = Enum.QuestFrequency.Daily},
	[64017] = {frequency = Enum.QuestFrequency.Daily},
	[64016] = {frequency = Enum.QuestFrequency.Daily},
	[63989] = {frequency = Enum.QuestFrequency.Daily},
	[63935] = {frequency = Enum.QuestFrequency.Daily},
	[64166] = {frequency = Enum.QuestFrequency.Daily},
	[63950] = {frequency = Enum.QuestFrequency.Daily},
	[63961] = {frequency = Enum.QuestFrequency.Daily},
	[63777] = {frequency = Enum.QuestFrequency.Daily},
	[63954] = {frequency = Enum.QuestFrequency.Daily},
	[63955] = {frequency = Enum.QuestFrequency.Daily},
	[63956] = {frequency = Enum.QuestFrequency.Daily},
	[63780] = {frequency = Enum.QuestFrequency.Daily},
	[64430] = {frequency = Enum.QuestFrequency.Daily},
	[64070] = {frequency = Enum.QuestFrequency.Daily},
	[64432] = {frequency = Enum.QuestFrequency.Daily},
	[63786] = {frequency = Enum.QuestFrequency.Daily},
	[64089] = {frequency = Enum.QuestFrequency.Daily},
	[64101] = {frequency = Enum.QuestFrequency.Daily},
	[64018] = {frequency = Enum.QuestFrequency.Daily},
	[64104] = {frequency = Enum.QuestFrequency.Daily},
	[64194] = {frequency = Enum.QuestFrequency.Daily},
	[63778] = {frequency = Enum.QuestFrequency.Daily},
	[64043] = {frequency = Enum.QuestFrequency.Daily},
	[63965] = {frequency = Enum.QuestFrequency.Daily},
}
function Internal.IterateQuestData()
	return pairs(questData)
end
Internal.RegisterEvent("ADDON_LOADED", function (event, addon)
	if addon == ADDON_NAME then
        BtWTodoCache.quests = BtWTodoCache.quests or {}
		Internal.data.quests = setmetatable({}, {
			__index = Mixin(questData, BtWTodoCache.quests),
			__newindex = function (self, key, data)
				if self[key] == nil or not tCompare(self[key], data, 1) then
					questData[key] = data
					BtWTodoCache.quests[key] = data
				end
			end,
		})
	end
end, -5)

local mawAssaults = {
	63543, 63822, 63823, 63824
}
-- Save Quest Data for Player
local function SavedQuests()
    local player = Internal.GetPlayer()
	local questLog = player:GetDataTable("questLog")
	local questCompleted = player:GetDataTable("questCompleted")
	wipe(questLog)
	wipe(questCompleted)

	for questLogIndex = 1, C_QuestLog.GetNumQuestLogEntries() do
		local info = C_QuestLog.GetInfo(questLogIndex);
		if info and not info.isHeader then
			local objectives = C_QuestLog.GetQuestObjectives(info.questID)
			local isComplete = C_QuestLog.IsComplete(info.questID)
			if isComplete then
				questLog[info.questID] = true
			else
				for _,objective in ipairs(objectives) do
					objective.text = nil
					objective.type = nil
					objective.numRequired = nil
				end
				questLog[info.questID] = objectives
			end
		end
	end

	local quests = C_QuestLog.GetAllCompletedQuestIDs()
	for _,questID in ipairs(quests) do
		questCompleted[questID] = true
	end

	-- Record if the first maw assault happened before the half weekly reset
	if Internal.IsBeforeHalfWeeklyReset() then
		for _,questID in ipairs(mawAssaults) do
			if C_QuestLog.IsQuestFlaggedCompleted(questID) then
				player.data.firstMawAssaultCompleted = questID
				break
			end
		end
	end
end
Internal.RegisterEvent("PLAYER_ENTERING_WORLD", SavedQuests)
Internal.RegisterEvent("QUEST_REMOVED", SavedQuests)

-- Reset our records for daily/weekly quests
Internal.RegisterEvent("DAILY_RESET", function (event, isWeekly)
    for _,character in Internal.IterateCharacters() do
		-- print("[" .. ADDON_NAME .. "]: Clearing daily quests for " .. character:GetDisplayName())
		local data = character:GetDataTable("questCompleted")
		for questID,quest in Internal.IterateQuestData() do
			if quest.frequency == Enum.QuestFrequency.Daily then
				-- print("Clear daily quest " .. questID)
				data[questID] = nil
			elseif quest.frequency == Enum.QuestFrequency.Weekly and isWeekly then
				-- print("Clear weekly quest " .. questID)
				data[questID] = nil
			end
		end
	end
end, -1)
Internal.RegisterEvent("HALF_WEEKLY_RESET", function (event, isWeekly)
    for _,character in Internal.IterateCharacters() do
		-- print("[" .. ADDON_NAME .. "]: Clearing half weekly quests for " .. character:GetDisplayName())
		local data = character:GetDataTable("questCompleted")
		for questID,quest in Internal.IterateQuestData() do
			if quest.frequency == QuestFrequencyHalfWeekly then
				-- print("Clear half weekly quest " .. questID)
				data[questID] = nil
			end
		end
	end
end, -1)
-- Clear the flag for the first maw assault being complete
Internal.RegisterEvent("WEEKLY_RESET", function (event)
    for _,character in Internal.IterateCharacters() do
		character.data.firstMawAssaultCompleted = nil
	end
end, -1)

-- Store quest data for use with the add quest auto complete/name scan
Internal.RegisterEvent("QUEST_DATA_LOAD_RESULT", function (event, questID, success)
    if success then
		local title = QuestUtils_GetQuestName(questID);
		if title ~= "" then
			questMapNameToID[format("%s (%s)", title, questID)] = questID
		end
	end
end)

Internal.RegisterCustomStateFunction("AddQuestToTooltip", function (state, tooltip)
	local name = state:GetTitle()
	if name == "" then
		name = state:GetUniqueKey()
	end
	if IsShiftKeyDown() then
		name = format("%s [%d]", name, state:GetID())
	end

	if state:IsCompleted() then
		tooltip:AddLine(Internal.Images.COMPLETE .. name, 0, 1, 0)
	elseif state:IsComplete() then
		tooltip:AddLine(Internal.Images.QUEST_TURN_IN .. name, 1, 1, 0)
	elseif state:IsActive() then
		tooltip:AddLine(Internal.Images.PADDING .. name, 1, 1, 0)
	else
		tooltip:AddLine(Internal.Images.QUEST_PICKUP .. name, 1, 1, 1)
	end
end)

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

			if unlocked and #quests > 3 then
				Internal.SaveSharedData(SharedDataID, questIDs)
			end

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
	local function GetActiveMawAssaultQuest()
		local week = Internal.GetSeasonWeek() % 2
		if week == 0 then
			if Internal.IsBeforeHalfWeeklyReset() then
				return 63823 -- Night Fae
			else
				return 63822 -- Venthyr
			end
		else
			if Internal.IsBeforeHalfWeeklyReset() then
				return 63543 -- Necrolord
			else
				return 63824 -- Kyrian
			end
		end
	end
	-- Returns which assaults for the current week
	Internal.RegisterCustomStateFunction("GetMawAssaults", function ()
		local week = Internal.GetSeasonWeek() % 2
		if week == 0 then
			return 63823, 63822 -- Night Fae and Venthyr
		else
			return 63543, 63824 -- Necrolord and Kyrian
		end
	end)

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
	Internal.RegisterCustomStateFunction("GetActiveMawAssaultQuests", function ()
		local data = Internal.GetSharedData(SharedDataID) or {}
		local assaultQuest = GetActiveMawAssaultQuest()

		if data.assaultQuest ~= assaultQuest then
			data.quests = {}
		end

		data.assaultQuest = assaultQuest
		data.quests = data.quests or {}

		for _,k in pairs(assaultQuests[assaultQuest]) do
			if C_QuestLog.GetLogIndexForQuestID(k) or C_QuestLog.IsQuestFlaggedCompleted(k) then
				data.quests[k] = true
			end
		end

		Internal.SaveSharedData(SharedDataID, data)
		return data
	end)

	Internal.RegisterEvent("HALF_WEEKLY_RESET", function (event, isWeekly)
		Internal.WipeSharedData(SharedDataID)
	end, -1)
end
