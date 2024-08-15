local ADDON_NAME, Internal = ...
local External = _G[ADDON_NAME]
local L = Internal.L

local challengeMapIDs = {
    -- Cataclysm
    438, -- The Vortex Pinnacle
    456, -- Throne of the Tides
    507, -- Grim Batol

    -- Mists of Pandaria
      2, -- Temple of the Jade Serpent

    -- Warlords of Draenor
    165, -- Shadowmoon Burial Grounds
    166, -- Grimrail
    169, -- Iron Docks

    -- Legion
    200, -- Halls of Valor
    210, -- Court of Stars
    227, -- Lower Kara
    234, -- Upper Kara

    -- Battle for Azeroth
    244, -- AD
    245, -- Freehold
    246, -- TD
    247, -- Motherloade
    248, -- WM
    249, -- KR
    250, -- ToS
    251, -- Underrot
    252, -- SotS
    353, -- SoB
    369, -- Junkyard
    370, -- Workshop

    -- Shadowlands
    375, -- mists
    376, -- nw
    377, -- dos
    378, -- hoa
    379, -- pf
    380, -- sd
    381, -- soa
    382, -- top
    391, -- streets
    392, -- gambit

    -- Dragonflight
    399, -- Ruby Life Pools
    400, -- The Nokhud Offensive
    401, -- The Azure Vault
    402, -- Algeth'ar Academy
    403, -- Uldaman: Legacy of Tyr
    404, -- Neltharus
    405, -- Brackenhide Hollow
    406, -- Halls of Infusion
    463, -- Dawn of the Infinite: Galakrond's Fall
    464, -- Dawn of the Infinite: Murozond's Rise

    409, -- Priory of the Sacred Flame
    500, -- The Rookery
    501, -- The Stonevault
    502, -- City of Threads
    503, -- Ara-Kara, City of Echoes
    504, -- Darkflame Cleft
    505, -- The Dawnbreaker
    506, -- Cinderbrew Meadery
}
local sortedNames = {}
local idToNameMap = {
    [0] = L["Overall"],
}
local nameToIDMap = {
    [L["Overall"]] = 0,
}
for _,id in ipairs(challengeMapIDs) do
    local info = C_ChallengeMode.GetMapUIInfo(id)
    if info then
        sortedNames[#sortedNames+1] = info
        idToNameMap[id] = info
        nameToIDMap[info] = id
    end
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
            return C_ChallengeMode.GetOverallDungeonScore() or 0
        else
            return (select(2, C_MythicPlus.GetSeasonBestAffixScoreInfoForMap(id))) or 0
        end
    else
		return self:GetCharacter():GetData("mythicPlusRating", self:GetID()) or 0
    end
end
function MythicPlusRatingMixin:GetRatingColor()
    if self:GetID() == 0 then
        return C_ChallengeMode.GetDungeonScoreRarityColor(self:GetRating()) or WHITE_FONT_COLOR
    else
        return C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor(self:GetRating()) or WHITE_FONT_COLOR
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

local function UpdateRatings()
    local player = Internal.GetPlayer()
    local ratings = {}

    ratings[0] = C_ChallengeMode.GetOverallDungeonScore()
    for _,id in ipairs(challengeMapIDs) do
        ratings[id] = select(2, C_MythicPlus.GetSeasonBestAffixScoreInfoForMap(id))
    end

    player:SetDataTable("mythicPlusRating", ratings)
end
Internal.RegisterEvent("PLAYER_ENTERING_WORLD", UpdateRatings)
Internal.RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE", UpdateRatings)