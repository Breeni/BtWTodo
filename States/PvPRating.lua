local ADDON_NAME, Internal = ...
local External = _G[ADDON_NAME]
local L = Internal.L

local names = {
    ARENA_BATTLES_2V2,
    ARENA_BATTLES_3V3,
    PVP_RATED_BATTLEGROUNDS,
}
local nameToIDMap = {}
for id,name in pairs(names) do
    nameToIDMap[name] = id
end

local PvPRatingMixin = CreateFromMixins(External.StateMixin)
function PvPRatingMixin:Init(id)
	External.StateMixin.Init(self, id)

    self.name = names[id]

    -- local rating, seasonBest, weeklyBest, seasonPlayed, seasonWon, weeklyPlayed, weeklyWon, lastWeeksBest, hasWon, pvpTier, ranking = GetPersonalRatedInfo(id);
end
function PvPRatingMixin:GetDisplayName()
    return string.format(L["PvP Rating: %s"], self:GetName())
end
function PvPRatingMixin:GetUniqueKey()
	return "pvprating:" .. self:GetID()
end
function PvPRatingMixin:GetName()
    return self.name or self:GetID()
end
function PvPRatingMixin:GetRating()
    if self:GetCharacter():IsPlayer() then
        return (GetPersonalRatedInfo(self:GetID()))
    else
		return self:GetCharacter():GetData("pvpRating", self:GetID())
    end
end
function PvPRatingMixin:GetSeasonBestRating()
    if self:GetCharacter():IsPlayer() then
        return (select(2, GetPersonalRatedInfo(self:GetID())))
    else
		return self:GetCharacter():GetData("pvpRatingSeasonBest", self:GetID())
    end
end
function PvPRatingMixin:GetWeeklyBestRating()
    if self:GetCharacter():IsPlayer() then
        return (select(3, GetPersonalRatedInfo(self:GetID())))
    else
		return self:GetCharacter():GetData("pvpRatingWeeklyBest", self:GetID())
    end
end
function PvPRatingMixin:GetSeasonPlayed()
    if self:GetCharacter():IsPlayer() then
        return (select(4, GetPersonalRatedInfo(self:GetID())))
    else
		return self:GetCharacter():GetData("pvpRatingSeasonPlayed", self:GetID())
    end
end
function PvPRatingMixin:GetSeasonWon()
    if self:GetCharacter():IsPlayer() then
        return (select(5, GetPersonalRatedInfo(self:GetID())))
    else
		return self:GetCharacter():GetData("pvpRatingSeasonWon", self:GetID())
    end
end
function PvPRatingMixin:GetWeeklyPlayed()
    if self:GetCharacter():IsPlayer() then
        return (select(6, GetPersonalRatedInfo(self:GetID())))
    else
		return self:GetCharacter():GetData("pvpRatingWeeklyPlayed", self:GetID())
    end
end
function PvPRatingMixin:GetWeeklyWon()
    if self:GetCharacter():IsPlayer() then
        return (select(7, GetPersonalRatedInfo(self:GetID())))
    else
		return self:GetCharacter():GetData("pvpRatingWeeklyWon", self:GetID())
    end
end
function PvPRatingMixin:RegisterEventsFor(driver)
    driver:RegisterEvents("PLAYER_ENTERING_WORLD", "WEEKLY_RESET")
end

local PvPRatingProviderMixin = CreateFromMixins(External.StateProviderMixin)
function PvPRatingProviderMixin:GetID()
	return "pvprating"
end
function PvPRatingProviderMixin:GetName()
	return L["PvP Rating"]
end
function PvPRatingProviderMixin:Acquire(...)
	return CreateAndInitFromMixin(PvPRatingMixin, ...)
end
function PvPRatingProviderMixin:GetFunctions()
	return {
		{
			name = "IsCompleted",
			returnValue = "bool",
		},
    }
end
function PvPRatingProviderMixin:GetDefaults()
	return { -- Completed
        "or", {"IsWeeklyCapped"}, {"IsCapped"},
	}, { -- Text
		{"GetQuantity"}
	}
end
function PvPRatingProviderMixin:ParseInput(value)
	local num = tonumber(value)
	if num ~= nil and names[num] ~= nil then
		return true, num
	end
    if nameToIDMap[value] then
        return true, nameToIDMap[value]
    end
	return false, L["Invalid PvP Rating"]
end
function PvPRatingProviderMixin:FillAutoComplete(tbl, text, offset, length)
    local text = strsub(text, offset, length):lower()
    for _,value in ipairs(names) do
        local name = value:lower()
        if #name >= #text and strsub(name, offset, length) == text then
            tbl[#tbl+1] = value
        end
    end
end
Internal.RegisterStateProvider(CreateFromMixins(PvPRatingProviderMixin))
