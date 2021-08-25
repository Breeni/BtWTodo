--[[
    State provider for the weekly vault
]]

local ADDON_NAME, Internal = ...
local External = _G[ADDON_NAME]
local L = Internal.L

local autoCompleteList = {
	[Enum.WeeklyRewardChestThresholdType.Raid] = RAIDS,
	[Enum.WeeklyRewardChestThresholdType.MythicPlus] = MYTHIC_DUNGEONS,
	[Enum.WeeklyRewardChestThresholdType.RankedPvP] = PVP,
}

local VaultMixin = CreateFromMixins(External.StateMixin)
function VaultMixin:GetDisplayName()
	return string.format(L["Vault Progress: %s"], autoCompleteList[self:GetID()] or self:GetID())
end
function VaultMixin:GetUniqueKey()
	return "vault:" .. self:GetID()
end
function VaultMixin:GetProgress()
	local character = self:GetCharacter()
	if character:IsPlayer() then
		local data = C_WeeklyRewards.GetActivities(self:GetID())
		return data[1] and data[1].progress or 0
	else
		return character:GetData("vaultProgress", self:GetID()) or 0
	end

	return 0
end
function VaultMixin:GetTotal()
	local data = C_WeeklyRewards.GetActivities(self:GetID())
	table.sort(data, function (a, b)
		return a.index > b.index
	end)
	return data[1].threshold
end
function VaultMixin:IsProgress(progress)
	return self:GetProgress() >= progress
end
function VaultMixin:GetThreshold()
	local data = C_WeeklyRewards.GetActivities(self:GetID())
	local progress = self:GetProgress()
	table.sort(data, function (a, b)
		return a.index > b.index
	end)
	for _,item in ipairs(data) do
		if progress >= item.threshold then
			return item.index
		end
	end

	return 0
end
function VaultMixin:IsThreshold(index)
	return self:GetThreshold() >= index
end
function VaultMixin:GetCap()
	local data = C_WeeklyRewards.GetActivities(self:GetID())
	return #data
end
function VaultMixin:IsCapped()
	return self:IsThreshold(self:GetCap())
end
function VaultMixin:GetLevel(index)
	local character = self:GetCharacter()
	if character:IsPlayer() then
		local data = C_WeeklyRewards.GetActivities(self:GetID())
		-- Assumption, there are no missing indexes and they start from 1
		table.sort(data, function (a, b)
			return a.index < b.index
		end)
		return data[index] and data[index].level or 0
	else
		local levels = character:GetData("vaultLevels", self:GetID())
		return levels and levels[index] or 0
	end
end
function VaultMixin:GetLevelInitial(index)
	local result = self:GetLevel(index)
	if self:GetID() == Enum.WeeklyRewardChestThresholdType.Raid then
		if result == 14 then
			return 'N'
		elseif result == 15 then
			return 'H'
		elseif result == 16 then
			return 'M'
		else
			return '-'
		end
	else
		return result
	end
end
function VaultMixin:IsLevel(index, level)
	return self:GetLevel(index) > level
end
function VaultMixin:RegisterEventsFor(driver)
    driver:RegisterEvents("PLAYER_ENTERING_WORLD", "WEEKLY_REWARDS_UPDATE", "WEEKLY_RESET") -- , "ENCOUNTER_END", "CHALLENGE_MODE_COMPLETED", "PVP_MATCH_COMPLETE"
end

local VaultProviderMixin = CreateFromMixins(External.StateProviderMixin)
function VaultProviderMixin:GetID()
	return "vault"
end
function VaultProviderMixin:GetName()
	return L["Vault Progress"]
end
function VaultProviderMixin:GetAddTitle()
	return string.format(BTWTODO_ADD_ITEM, self:GetName()), L["Enter the type of vault data below, either raids, mythic dungeons, or pvp"]
end
function VaultProviderMixin:Acquire(...)
	return CreateAndInitFromMixin(VaultMixin, ...)
end
function VaultProviderMixin:GetFunctions()
	return {
		{
			name = "IsCapped",
			returnValue = "bool",
		}
	}
end
function VaultProviderMixin:GetDefaults()
	return { -- Completed
		{"IsCapped"}
	}, { -- Text
		{"GetLevel", 1}
	}
end
function VaultProviderMixin:ParseInput(value)
	local num = tonumber(value)
	if num ~= nil then
		return true, num
	end
	for id,name in pairs(autoCompleteList) do
		if value == name then
			return true, id
		end
	end
	return false, L["Invalid vault type"]
end
function VaultProviderMixin:FillAutoComplete(tbl, text, offset, length)
    local text = strsub(text, offset, length):lower()
	for _,value in pairs(autoCompleteList) do
        local name = value:lower()
        if #name >= #text and strsub(name, offset, length) == text then
            tbl[#tbl+1] = value
        end
    end
end
Internal.RegisterStateProvider(CreateFromMixins(VaultProviderMixin))

-- Weekly reset has happened, we have no progress towards vault now
Internal.RegisterEvent("WEEKLY_RESET", function ()
    for _,character in Internal.IterateCharacters() do
		local progress = character:GetDataTable("vaultProgress")
		local levels = character:GetDataTable("vaultLevels")
		for _,id in pairs(Enum.WeeklyRewardChestThresholdType) do
			progress[id] = nil
			levels[id] = nil
		end
	end
end, -1)

-- Save Quest Data for Player
Internal.RegisterEvent("PLAYER_LOGOUT", function ()
    local player = Internal.GetPlayer()
	local progress = player:GetDataTable("vaultProgress")
	local levels = player:GetDataTable("vaultLevels")
	for _,id in pairs(Enum.WeeklyRewardChestThresholdType) do
		local activityData = C_WeeklyRewards.GetActivities(id)
		table.sort(activityData, function (a, b)
			return a.index < b.index
		end)
		if activityData[1] and activityData[1] ~= 0 then
			progress[id] = activityData[1].progress

			levels[id] = {}
			for _,item in ipairs(activityData) do
				levels[id][item.index] = item.level
			end
		else
			progress[id] = nil
			levels[id] = nil
		end
	end
end)

Internal.RegisterCustomStateFunction("OpenVaultFrame", function ()
	WeeklyRewards_ShowUI()
end)