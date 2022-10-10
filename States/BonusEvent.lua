--[[
    State provider for the weekly bonus events
]]

local ADDON_NAME, Internal = ...
local External = _G[ADDON_NAME]
local L = Internal.L

local bonusEvents = {
	-- [186400] = {
    --     name = L["Apexis Crystal"],
    -- },
	[186401] = {
        questID = 62640,
        numRequired = 10,
        name = L["Skirmishes"],
        eventIDs = {561, 610, 611, 612}
    },
	[186403] = {
        questID = 62637,
        numRequired = 4,
        name = L["Battlegrounds"],
        eventIDs = {563, 602, 603, 604}
    },
	-- [186404] = {
    --     questID = 00000,
    --     name = L["Draenor Dungeons"],
    -- },
    [186406] = {
        questID = 62639,
        numRequired = 5,
        name = L["Pet Battles"],
        eventIDs = {565, 599, 600, 601}
    },
    [225787] = {
        questID = 62638,
        numRequired = 4,
        name = L["Shadowlands Dungeons"],
        eventIDs = {1217, 1218, 1219, 1220}
    },
    [225788] = {
        questID = 62631,
        numRequired = 20,
        name = L["World Quests"],
        eventIDs = {592, 613, 614, 615}
    },
    [335148] = {
        questID = 62632,
        numRequired = 5,
        name = L["Burning Crusade Timewalking"],
        eventIDs = {559, 622, 623, 624}
    },
    [335149] = {
        questID = 62633,
        numRequired = 5,
        name = L["Wrath of the Lich King Timewalking"],
        eventIDs = {562, 616, 617, 618}
    },
    [335150] = {
        questID = 62634,
        numRequired = 5,
        name = L["Cataclysm Timewalking"],
        eventIDs = {587, 628, 629, 630}
    },
    [335151] = {
        questID = 62635,
        numRequired = 5,
        name = L["Mists of Pandaria Timewalking"],
        eventIDs = {643, 652, 654, 656}
    },
    [335152] = {
        questID = 62636,
        numRequired = 5,
        name = L["Warlords of Draenor Timewalking"],
        eventIDs = {1056, 1063, 1065, 1068}
    },
    [359082] = {
        questID = 64709,
        numRequired = 5,
        name = L["Legion Timewalking"],
        eventIDs = {1263, 1265, 1267, 1269, 1271, 1273, 1275, 1277}
    },
}

local BonusEventMixin = CreateFromMixins(External.StateMixin)
function BonusEventMixin:Init(ID)
	External.StateMixin.Init(self, ID)

    self.objectives = {}
    local questID = self:GetQuestID()
    if questID then
	    QuestEventListener:AddCallback(questID, function()
            self.objectives = C_QuestLog.GetQuestObjectives(questID)
            for _,objective in ipairs(self.objectives) do
                objective.numFulfilled = nil
                objective.finished = nil
            end
        end);
    end
end
function BonusEventMixin:GetDisplayName()
	return string.format(L["Bonus Event: %s"], self:GetName())
end
function BonusEventMixin:GetName()
    local event = bonusEvents[self:GetID()]
	return event and event.name or self:GetID()
end
function BonusEventMixin:GetUniqueKey()
	return "bonusevent:" .. self:GetID()
end
function BonusEventMixin:GetQuestID()
    local event = bonusEvents[self:GetID()]
    return event and event.questID
end
function BonusEventMixin:IsAvailable()
    return UnitLevel("player") == 60 --@TODO Is it only level 60s that can do these events?
end
function BonusEventMixin:IsActive()
    local GetPlayerAuraBySpellID = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID or GetPlayerAuraBySpellID
    if GetPlayerAuraBySpellID(self:GetID()) ~= nil then
        return true
    end
    if UnitLevel("player") < 60 then
        local event = bonusEvents[self:GetID()]
        if event.eventIDs then
            local currentCalendarTime = C_DateAndTime.GetCurrentCalendarTime()
            for _,id in ipairs(event.eventIDs) do
                local index = C_Calendar.GetEventIndexInfo(id)
                if index then
                    local info = C_Calendar.GetHolidayInfo(index.offsetMonths, index.monthDay, index.eventIndex)
                    if info then
                        return C_DateAndTime.CompareCalendarTime(info.startTime, currentCalendarTime) > -1 and C_DateAndTime.CompareCalendarTime(currentCalendarTime, info.endTime) > -1
                    end
                end
            end
        end
    end
    return false
end
function BonusEventMixin:IsInProgress()
    local questID = self:GetQuestID()
    if not questID then
        return false
    end
    
    local character = self:GetCharacter()
    if character:IsPlayer() then
        return C_QuestLog.GetLogIndexForQuestID(questID)
    else
        return character:GetData("questLog", questID) ~= nil
    end
end
function BonusEventMixin:GetNumFulfilled()
	if self:GetCharacter():IsPlayer() then
		return (select(4, GetQuestObjectiveInfo(self:GetQuestID(), 1, false))) or 0
	else
		return 0
	end
end
function BonusEventMixin:GetNumRequired()
    local event = bonusEvents[self:GetID()]
    local objective = self.objectives and self.objectives[1]
    local numRequired = objective and objective.numRequired or 0
	return numRequired ~= 0 and numRequired or event.numRequired
end
function BonusEventMixin:IsComplete()
    local questID = self:GetQuestID()
    if not questID then
        return false
    end

    local character = self:GetCharacter()
    if character:IsPlayer() then
		return C_QuestLog.IsComplete(questID);
	else
		return character:GetData("questLog", questID) == true
	end
end
function BonusEventMixin:IsCompleted()
    local questID = self:GetQuestID()
    if not questID then
        return false
    end

    local character = self:GetCharacter()
    if character:IsPlayer() then
		return C_QuestLog.IsQuestFlaggedCompleted(questID);
	else
		return character:GetData("questCompleted", questID) == true
	end
end
function BonusEventMixin:RegisterEventsFor(driver)
    driver:RegisterEvents("PLAYER_ENTERING_WORLD", "WEEKLY_RESET", "QUEST_TURNED_IN", "QUEST_REMOVED", "QUEST_ACCEPTED", "CALENDAR_UPDATE_EVENT_LIST")
end

local BonusEventProviderMixin = CreateFromMixins(External.StateProviderMixin)
function BonusEventProviderMixin:GetID()
	return "bonusevent"
end
function BonusEventProviderMixin:GetName()
	return L["Bonus Event"]
end
function BonusEventProviderMixin:Acquire(...)
	return CreateAndInitFromMixin(BonusEventMixin, ...)
end
function BonusEventProviderMixin:GetFunctions()
	return {
		{
			name = "IsCompleted",
			returnValue = "bool",
		}
	}
end
function BonusEventProviderMixin:GetDefaults()
	return { -- Completed
		{"IsCompleted"}
	}, { -- Text
		{"GetLevel", 1}
	}
end
function BonusEventProviderMixin:ParseInput(value)
	local num = tonumber(value)
	if num ~= nil then
		return true, num
	end
	for id,event in pairs(bonusEvents) do
		if value == event.name then
			return true, id
		end
	end
	return false, L["Invalid bonus event type"]
end
function BonusEventProviderMixin:FillAutoComplete(tbl, text, offset, length)
    local text = strsub(text, offset, length):lower()
	for _,event in pairs(bonusEvents) do
        local name = event.name:lower()
        if #name >= #text and strsub(name, offset, length) == text then
            tbl[#tbl+1] = event.name
        end
    end
end
Internal.RegisterStateProvider(CreateFromMixins(BonusEventProviderMixin))

Internal.RegisterEvent("PLAYER_LOGIN", function ()
    C_Calendar.OpenCalendar() -- Doesnt actually open the calendar, but does load events
end)
