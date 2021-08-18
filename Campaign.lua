--[[
    State provider for campaign
]]

local ADDON_NAME, Internal = ...
local External = _G[ADDON_NAME]
local L = Internal.L

local campaignMapNameToID = {}

local function GetCampaignFaction(id)
    if id == 1 then
        return 1
    elseif id == 2 then
        return 2
    end
    return 0
end

local CampaignMixin = CreateFromMixins(External.StateMixin)
function CampaignMixin:Init(campaignID)
	External.StateMixin.Init(self, campaignID)

    Mixin(self, C_CampaignInfo.GetCampaignInfo(campaignID))
    self.campaignFaction = GetCampaignFaction(campaignID)

    if self.campaignFaction == 1 then
        self.name = format("%s (%s)", self.name, FACTION_ALLIANCE)
    elseif self.campaignFaction == 2 then
        self.name = format("%s (%s)", self.name, FACTION_HORDE)
    end

	self.chapterIDs = C_CampaignInfo.GetChapterIDs(campaignID) or {};
end
function CampaignMixin:GetDisplayName()
    return string.format(L["Campaign: %s"], self:GetName())
end
function CampaignMixin:GetUniqueKey()
	return "campaign:" .. self:GetID()
end
function CampaignMixin:GetName()
    return self.name
end
function CampaignMixin:IsState(state)
	if self:GetCharacter():IsPlayer() then
		return C_CampaignInfo.GetState(self:GetID()) == state
	else
		return self:GetCharacter():GetData("campaignState", self:GetID()) == state
	end
end
function CampaignMixin:IsCompleted()
    return self:IsState(Enum.CampaignState.Complete)
end
function CampaignMixin:IsInProgress()
    return self:IsState(Enum.CampaignState.InProgress)
end
function CampaignMixin:IsStalled()
    return self:IsState(Enum.CampaignState.Stalled)
end
function CampaignMixin:GetChapterName(index)
    local info = C_CampaignInfo.GetCampaignChapterInfo(self.chapterIDs[index])
    return info and info.name
end
function CampaignMixin:IsChapterCompleted(index)
    local questLineID = self.chapterIDs[index]
    if self:GetCharacter():IsPlayer() then
        return questLineID and C_QuestLine.IsComplete(questLineID)
    else
        return questLineID and self:GetCharacter():GetData("questLineCompleted", questLineID)
    end
end
function CampaignMixin:IsChapterInProgress(index)
    local questLineID = self.chapterIDs[index]
	local quests = C_QuestLine.GetQuestLineQuests(questLineID);
    if self:GetCharacter():IsPlayer() then
        for _,questID in ipairs(quests) do
            if C_QuestLog.IsOnQuest(questID) or C_QuestLog.IsQuestFlaggedCompleted(questID) then
                return true;
            end
        end
    else
        for _,questID in ipairs(quests) do
            if self:GetCharacter():GetData("questActive", questID) or self:GetCharacter():GetData("questCompleted", questID) then
                return true;
            end
        end
    end

	return false;
end
function CampaignMixin:GetChaptersCompleted()
    local count = 0
    if self:GetCharacter():IsPlayer() then
        for _,id in ipairs(self.chapterIDs) do
            if C_QuestLine.IsComplete(id) then
                count = count + 1
            end
        end
    else
        for _,id in ipairs(self.chapterIDs) do
            if self:GetCharacter():GetData("questLineCompleted", id) then
                count = count + 1
            end
        end
    end
    return count
end
function CampaignMixin:GetChaptersTotal()
    return #self.chapterIDs
end
function CampaignMixin:RegisterEventsFor(driver)
    driver:RegisterEvents("PLAYER_ENTERING_WORLD", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "DAILY_RESET", "HALF_WEEKLY_RESET")
end

local CampaignProviderMixin = CreateFromMixins(External.StateProviderMixin)
function CampaignProviderMixin:GetID()
	return "campaign"
end
function CampaignProviderMixin:GetName()
	return L["Campaign"]
end
function CampaignProviderMixin:Acquire(...)
	return CreateAndInitFromMixin(CampaignMixin, ...)
end
function CampaignProviderMixin:GetFunctions()
	return {
		{
			name = "IsCompleted",
			returnValue = "bool",
		},
    }
end
function CampaignProviderMixin:GetDefaults()
	return { -- Completed
        "or", {"IsWeeklyCapped"}, {"IsCapped"},
	}, { -- Text
		{"GetQuantity"}
	}
end
function CampaignProviderMixin:ParseInput(input)
	local num = tonumber(input)
	if num ~= nil then
		return true, num
	end
	if campaignMapNameToID[input] then
        return true, campaignMapNameToID[input]
    end
	return false, L["Invalid campaign"]
end
function CampaignProviderMixin:FillAutoComplete(tbl, text, offset, length)
    local text = strsub(text, offset, length):lower()
    for value in pairs(campaignMapNameToID) do
        local name = value:lower()
        if #name >= #text and strsub(name, offset, length) == text then
            tbl[#tbl+1] = value
        end
    end
    table.sort(tbl)
end
Internal.RegisterStateProvider(CreateFromMixins(CampaignProviderMixin))

local campaigns = {
    1, -- Alliance War Campaign
    2, -- Horde War Campaign
    111, -- The Master of Revendreth
    113, -- Venthyr Campaign
    114, -- Bastion
    115, -- The Art of War (Necrolord Campaign)
    117, -- Night Fae Campaign
    118, -- Blade of the Primus (Maldraxxus)
    119, -- Kyrian Campaign
    124, -- The Groves of Ardenweald
    138, -- Chains of Domination
}
-- Save Campaign Data for Player
local function SaveCampaignData (event, questID)
    if event == "PLAYER_ENTERING_WORLD" or C_CampaignInfo.IsCampaignQuest(questID) then
        local player = Internal.GetPlayer()
        local campaignState = player:GetDataTable("campaignState")
        local questLineCompleted = player:GetDataTable("questLineCompleted")
        wipe(campaignState)
        wipe(questLineCompleted)

        for _,id in ipairs(campaigns) do
            local state = C_CampaignInfo.GetState(id)

            local chapterIDs = C_CampaignInfo.GetChapterIDs(id)
            if chapterIDs then
                local count = 0
                for _,questLineID in ipairs(chapterIDs) do
                    if C_QuestLine.IsComplete(questLineID) then
                        count = count + 1
                        questLineCompleted[questLineID] = true
                    end
                end

                -- The state is Invalid for campaigns that are no longer relavent?
                if state == 0 then
                    if count == #chapterIDs then
                        state = Enum.CampaignState.Complete
                    elseif count > 0 then
                        state = Enum.CampaignState.InProgress
                    else
                        local questIDs = C_QuestLine.GetQuestLineQuests(chapterIDs[1])
                        for _,questID in ipairs(questIDs) do
                            if C_QuestLog.IsQuestFlaggedCompleted(questID) or C_QuestLog.GetLogIndexForQuestID(questID) then
                                state = Enum.CampaignState.InProgress
                                break
                            end
                        end
                    end
                end
            end

            if state ~= 0 then
                campaignState[id] = state
            end
        end
    end
end
Internal.RegisterEvent("PLAYER_ENTERING_WORLD", SaveCampaignData, -1)
Internal.RegisterEvent("QUEST_TURNED_IN", SaveCampaignData, -1)
Internal.RegisterEvent("QUEST_REMOVED", SaveCampaignData, -1)

Internal.RegisterEvent("PLAYER_ENTERING_WORLD", function ()
    -- Add possible unknown campaigns to our list
    for _,ID in ipairs(C_CampaignInfo.GetAvailableCampaigns()) do
        if not tContains(campaigns, ID) then
            campaigns[#campaigns+1] = ID
        end
    end
    -- Update the campaign map store
    for _,ID in ipairs(campaigns) do
        if ID ~= 1 and ID ~= 2 then
            local info = C_CampaignInfo.GetCampaignInfo(ID)
            campaignMapNameToID[info.name] = ID
        end
    end

    -- War campaign cheats
    local info = C_CampaignInfo.GetCampaignInfo(1)
    campaignMapNameToID[format("%s (%s)", info.name, FACTION_ALLIANCE)] = 1
    campaignMapNameToID[format("%s (%s)", info.name, FACTION_HORDE)] = 2
end, -2)