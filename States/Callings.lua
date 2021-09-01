
--[[
    State provider for Mythic Plus Runs
]]

local ADDON_NAME, Internal = ...
local External = _G[ADDON_NAME]
local L = Internal.L

local CallingMixin = CreateFromMixins(External.StateMixin)
function CallingMixin:Init(id)
    self.data = {}
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
        if not self.data[questID] then
            QuestEventListener:AddCallback(questID, function()
                local data = {
                    title = QuestUtils_GetQuestName(questID),
                    isRepeatable = C_QuestLog.IsRepeatableQuest(questID),
                    isLegendary = C_QuestLog.IsLegendaryQuest(questID),
                    objectives = C_QuestLog.GetQuestObjectives(questID),
                }
                for _,objective in ipairs(data.objectives) do
                    objective.numFulfilled = nil
                    objective.finished = nil
                end
                self.data[questID] = data
                Mixin(self, data)
            end);
        else
            Mixin(self, self.data[questID])
        end
    end
end
function CallingMixin:GetDisplayName()
    return L["Calling"] .. " " .. self:GetID()
end
function CallingMixin:GetUniqueKey()
	return "calling:" .. self:GetID()
end
function CallingMixin:GetQuestID()
    local covenantID = self:GetCharacter():GetCovenant()
    if covenantID and covenantID ~= 0 then
        local questID = BtWTodoCache.callings[covenantID][self:GetID()]
        if questID ~= self.questID then
            self.questID = questID
            self:RefreshCache()
        end
        return questID
    end
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
    C_CovenantCallings.RequestCallings() -- Triggers COVENANT_CALLINGS_UPDATED below
end
Internal.RegisterEvent("DAILY_RESET", DAILY_RESET)

-- A list of all groups of calling quests, each group is ordered by covenant id - Kyrian, Venthyr, Night Fae, Necrolord
local CallingQuests = {
    { 60391, 60389, 60381, 60390, }, -- Aiding Ardenweald
    { 60392, 60394, 60384, 60393, }, -- Aiding Bastion
    { 60395, 60397, 60383, 60396, }, -- Aiding Maldraxxus
    { 60400, 60399, 60382, 60398, }, -- Aiding Revendreth

    { 60415, 60417, 60414, 60416, }, -- Rare Resources
    { 60458, 60460, 60457, 60459, }, -- Anima Salvage
    { 60380, 60378, 60373, 60379, }, -- A Source of Sorrowvine
    { 60372, 60370, 60369, 60371, }, -- A Wealth of Wealdwood
    { 60465, 60463, 60462, 60464, }, -- Anima Appeal
    { 60358, 60365, 60364, 60363, }, -- Gildenite Grab
    { 60377, 60375, 60374, 60376, }, -- Bonemetal Bonanza

    { 60403, 60401, 60388, 60402, }, -- Training in Ardenweald
    { 60404, 60406, 60387, 60405, }, -- Training in Bastion
    { 60407, 60409, 60386, 60408, }, -- Training in Maldraxxus
    { 60412, 60410, 60385, 60411, }, -- Training in Revendreth

    { 60424, 60422, 60419, 60423, }, -- A Call to Ardenweald
    { 60425, 60427, 60418, 60426, }, -- A Call to Bastion
    { 60430, 60431, 60420, 60429, }, -- A Call to Maldraxxus
    { 60434, 60432, 60421, 60433, }, -- A Call to Revendreth

    { 60439, 60441, 60438, 60440, }, -- Challenges in Ardenweald
    { 60442, 60444, 60437, 60443, }, -- Challenges in Bastion
    { 60447, 60446, 60436, 60445, }, -- Challenges in Maldraxxus
    { 60450, 60448, 60435, 60449, }, -- Challenges in Revendreth

    { 60454, 60456, 60452, 60455, }, -- Storm the Maw
}
-- Convert the previous table into a map of questID => { questID... } to get the other covenants quest ids
local CallingQuestMap = {}
for _,ids in ipairs(CallingQuests) do
    for _,questID in ipairs(ids) do
        CallingQuestMap[questID] = ids
    end
end

local SECONDS_PER_DAY = 24 * 60 * 60
local function COVENANT_CALLINGS_UPDATED(event, calling)
    -- We are doing the daily reset checking here instead of in DAILY_RESET event because the chat message is timed incorrectly

    local covenantID = C_Covenants.GetActiveCovenantID()
    local cache = BtWTodoCache.callings[covenantID]
    local callingResets = 0
    for _,calling in ipairs(calling) do
        if calling and calling.questID then
            local timeLeft = C_TaskQuest.GetQuestTimeLeftSeconds(calling.questID)
            if timeLeft then -- Sometimes nil
                if timeLeft <= SECONDS_PER_DAY * 1 then
                    if cache[3] ~= nil and cache[3] == calling.questID then -- Its been 2 daily resets
                        callingResets = 2
                        break
                    elseif cache[2] ~= nil and cache[2] == calling.questID then
                        callingResets = 1
                        break
                    end
                elseif timeLeft <= SECONDS_PER_DAY * 2 then
                    if cache[3] ~= nil and cache[3] == calling.questID then
                        callingResets = 1
                        break
                    end
                end
            end
        end
    end

    for i=1,callingResets do -- Its past the daily reset, shift callings along 1 day
        for _,calling in ipairs(BtWTodoCache.callings) do
            tremove(calling, 1)
        end
    end

    -- If its been 3 daily resets it doesnt matter, everything will be replaced

    for _,calling in ipairs(calling) do
        local timeLeft = C_TaskQuest.GetQuestTimeLeftSeconds(calling.questID)
        local questIDs = CallingQuestMap[calling.questID]
        if questIDs ~= nil and timeLeft ~= nil then -- Too soon?
            for covenantID,questID in ipairs(questIDs) do
                if timeLeft <= SECONDS_PER_DAY then
                    BtWTodoCache.callings[covenantID][1] = questID
                elseif timeLeft <= SECONDS_PER_DAY * 2 then
                    BtWTodoCache.callings[covenantID][2] = questID
                elseif timeLeft <= SECONDS_PER_DAY * 3 then
                    BtWTodoCache.callings[covenantID][3] = questID
                end
            end
        end
    end
end
Internal.RegisterEvent("COVENANT_CALLINGS_UPDATED", COVENANT_CALLINGS_UPDATED)
