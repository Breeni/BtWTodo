local ADDON_NAME, Internal = ...
local External = _G[ADDON_NAME]
local L = Internal.L

local challengeMapIDs = {
    -- Shadowlands
    375, -- mists
    376, -- nw
    377, -- dos
    378, -- hoa
    379, -- pf
    380, -- sd
    381, -- soa
    382, -- top
}
local sortedNames = {}
local idToNameMap = {
    [0] = L["Overall"],
}
local nameToIDMap = {
    [L["Overall"]] = 0,
}
for _,id in ipairs(challengeMapIDs) do
    sortedNames[#sortedNames+1] = C_ChallengeMode.GetMapUIInfo(id)
    idToNameMap[id] = C_ChallengeMode.GetMapUIInfo(id)
    nameToIDMap[C_ChallengeMode.GetMapUIInfo(id)] = id
end
table.sort(sortedNames)

local MythicPlusRatingMixin = CreateFromMixins(External.StateMixin)
function MythicPlusRatingMixin:Init(id)
	External.StateMixin.Init(self, id)

    self.name = idToNameMap[id]
end
function MythicPlusRatingMixin:GetDisplayName()
    return string.format(L["Mythic Plus Rating: %s"], self:GetName())
end
function MythicPlusRatingMixin:GetUniqueKey()
	return "mythicplusrating:" .. self:GetID()
end
function MythicPlusRatingMixin:GetName()
    return self.name or self:GetID()
end
function MythicPlusRatingMixin:GetRating()
    if self:GetCharacter():IsPlayer() then
        local id = self:GetID()
        if id == 0 then
            return C_ChallengeMode.GetOverallDungeonScore()
        else
            return (select(2, C_MythicPlus.GetSeasonBestAffixScoreInfoForMap(id)))
        end
    else
		return self:GetCharacter():GetData("mythicPlusRating", self:GetID())
    end
end
function MythicPlusRatingMixin:GetRatingColor()
    if self:GetID() == 0 then
        return C_ChallengeMode.GetDungeonScoreRarityColor(self:GetRating())
    else
        return C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor(self:GetRating())
    end
end
function MythicPlusRatingMixin:RegisterEventsFor(driver)
    driver:RegisterEvents("PLAYER_ENTERING_WORLD", "WEEKLY_RESET")
end

local MythicPlusRatingProviderMixin = CreateFromMixins(External.StateProviderMixin)
function MythicPlusRatingProviderMixin:GetID()
	return "mythicplusrating"
end
function MythicPlusRatingProviderMixin:GetName()
	return L["Mythic Plus Rating"]
end
function MythicPlusRatingProviderMixin:Acquire(...)
	return CreateAndInitFromMixin(MythicPlusRatingMixin, ...)
end
function MythicPlusRatingProviderMixin:GetFunctions()
	return {
		{
			name = "IsCompleted",
			returnValue = "bool",
		},
    }
end
function MythicPlusRatingProviderMixin:GetDefaults()
	return { -- Completed
        "or", {"IsWeeklyCapped"}, {"IsCapped"},
	}, { -- Text
		{"GetQuantity"}
	}
end
function MythicPlusRatingProviderMixin:ParseInput(value)
	local num = tonumber(value)
	if num ~= nil and idToNameMap[num] ~= nil then
		return true, num
	end
    if nameToIDMap[value] then
        return true, nameToIDMap[value]
    end
	return false, L["Invalid Mythic Plus Rating"]
end
function MythicPlusRatingProviderMixin:FillAutoComplete(tbl, text, offset, length)
    local text = strsub(text, offset, length):lower()

    do
        local value = L["Overall"]
        local name = value:lower()
        if #name >= #text and strsub(name, offset, length) == text then
            tbl[#tbl+1] = value
        end
    end

    for _,value in ipairs(sortedNames) do
        local name = value:lower()
        if #name >= #text and strsub(name, offset, length) == text then
            tbl[#tbl+1] = value
        end
    end
end
Internal.RegisterStateProvider(CreateFromMixins(MythicPlusRatingProviderMixin))
