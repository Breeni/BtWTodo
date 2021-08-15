
--[[
    State provider for Mythic Plus Runs
]]

local ADDON_NAME, Internal = ...
local External = _G[ADDON_NAME]
local L = Internal.L

local CallingMixin = CreateFromMixins(External.StateMixin)
function CallingMixin:Init(id)
	External.StateMixin.Init(self, id)

    self:RefreshCache()
end
function CallingMixin:RefreshCache()
    local questID = self.questID

	self.title = "";
	self.isRepeatable = false;
	self.isLegendary = false;
	self.objectives = nil;
    self.campaignID = nil;
    self.isCalling = nil;

    if questID ~= nil then
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
end
function CallingMixin:GetDisplayName()
    return L["Calling "] .. self:GetID()
end
function CallingMixin:GetUniqueKey()
	return "calling:" .. self:GetID()
end
function CallingMixin:GetCalling()
    local covenantID = self:GetCharacter():GetCovenant()
    if covenantID and covenantID ~= 0 then
        local calling = BtWTodoCache.callings[covenantID][self:GetID()]
        if calling and calling.questID ~= self.questID then
            self.questID = calling.questID
            self:RefreshCache()
        end
        return calling
    end
end
function CallingMixin:GetQuestID()
    local calling = self:GetCalling()
    return calling and calling.questID
end
function CallingMixin:GetTitle()
    local questID = self:GetQuestID()
    return questID and self.title or ""
end
function CallingMixin:IsActive()
    local questID = self:GetQuestID()
    if not questID then
        return false
    end

	if self:GetCharacter():IsPlayer() then
		return C_QuestLog.GetLogIndexForQuestID(questID) ~= nil;
	else
		return self:GetCharacter():GetData("questLog", questID) ~= nil
	end
end
function CallingMixin:IsComplete()
    local questID = self:GetQuestID()
    if not questID then
        return false
    end

	if self:GetCharacter():IsPlayer() then
		return C_QuestLog.IsComplete(questID);
	else
		return self:GetCharacter():GetData("questLog", questID) == true
	end
end
function CallingMixin:IsCompleted()
    local questID = self:GetQuestID()
    if not questID then
        return false
    end

    if self:GetCharacter():IsPlayer() then
		return C_QuestLog.IsQuestFlaggedCompleted(questID);
    else
		return self:GetCharacter():GetData("questCompleted", questID)
    end
end
function CallingMixin:GetCampaignID()
    local questID = self:GetQuestID()
    if not questID then
        return false
    end

	if self.campaignID == nil then
		self.campaignID = C_CampaignInfo.GetCampaignID(questID);
	end

	return self.campaignID;
end
function CallingMixin:IsCalling() -- If this somehow doesnt return true I'll eat a hat or whatever the kids say
    local questID = self:GetQuestID()
    if not questID then
        return false
    end

    if self.isCalling == nil then
		self.isCalling = C_QuestLog.IsQuestCalling(questID);
	end

	return self.isCalling;
end
function CallingMixin:IsRepeatableQuest()
    local questID = self:GetQuestID()
    return questID and self.isRepeatable or false
end
function CallingMixin:IsLegendary()
    local questID = self:GetQuestID()
    return questID and self.isLegendary or false
end
function CallingMixin:GetNumObjectives()
    local questID = self:GetQuestID()
    return questID and self.objectives and #self.objectives or nil
end
function CallingMixin:GetObjectives()
    local questID = self:GetQuestID()
    return questID and self.objectives or nil
end
function CallingMixin:GetObjective(index)
    local objectives = self:GetObjectives()
	return objectives and objectives[index] or nil;
end
function CallingMixin:GetObjectiveType(index)
    local objectives = self:GetObjectives()
	return objectives and objectives[index] and objectives[index].type or nil;
end
function CallingMixin:GetObjectiveProgress(index)
    if self:GetCharacter():IsPlayer() then
        local objectives = C_QuestLog.GetQuestObjectives(self:GetQuestID())
	    return objectives[index].numFulfilled, objectives[index].numRequired;
    else
		local objectives = self:GetCharacter():GetData("questLog", self:GetQuestID())
        return objectives and objectives[index] and objectives[index].numFulfilled or 0, self:GetObjectives()[index].numRequired;
    end
end
function CallingMixin:RegisterEventsFor(target)
    target:RegisterEvents("PLAYER_ENTERING_WORLD", "COVENANT_CALLINGS_UPDATED", "QUEST_TURNED_IN", "QUEST_REMOVED", "QUEST_ACCEPTED")
end

local CallingProviderMixin = CreateFromMixins(External.StateProviderMixin)
function CallingProviderMixin:GetID()
	return "calling"
end
function CallingProviderMixin:GetName()
	return L["Calling"]
end
function CallingProviderMixin:GetAddTitle()
	return L["Add Calling"], L["Insert calling index 1 to 3"]
end
function CallingProviderMixin:Acquire(...)
	return CreateAndInitFromMixin(CallingMixin, ...)
end
function CallingProviderMixin:GetFunctions()
	return {
    }
end
function CallingProviderMixin:GetDefaults()
	return {}, { -- Text
		{"GetValue"}
	}
end
function CallingProviderMixin:ParseInput(input)
    local num = tonumber(input)
    if not num or num >= 4 or num <= 0 then
        return false, L["Invalid calling index, must between 1 and 3"]
    end
    return true, num
end
Internal.RegisterStateProvider(CreateFromMixins(CallingProviderMixin))

local function DAILY_RESET()
    -- Remove the calling from the now previous day
    for _,calling in ipairs(BtWTodoCache.callings) do
        tremove(calling, 1)
    end
end
Internal.RegisterEvent("DAILY_RESET", DAILY_RESET)

local SECONDS_PER_DAY = 24*60*60
local function COVENANT_CALLINGS_UPDATED(event, calling)
    local covenantID = C_Covenants.GetActiveCovenantID()
    local cache = BtWTodoCache.callings[covenantID]

    for _,calling in ipairs(calling) do
        local timeLeft = C_TaskQuest.GetQuestTimeLeftSeconds(calling.questID)
        if timeLeft ~= nil then -- Too soon?
            if timeLeft <= SECONDS_PER_DAY then
                cache[1] = calling
            elseif timeLeft <= SECONDS_PER_DAY * 2 then
                cache[2] = calling
            elseif timeLeft <= SECONDS_PER_DAY * 3 then
                cache[3] = calling
            end
        end
    end
end
Internal.RegisterEvent("COVENANT_CALLINGS_UPDATED", COVENANT_CALLINGS_UPDATED)
