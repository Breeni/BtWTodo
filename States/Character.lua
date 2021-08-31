--[[
    State provider for currencies
]]

local ADDON_NAME, Internal = ...
local External = _G[ADDON_NAME]
local L = Internal.L

local CharacterDataEnum = {
    Level = 1,
    Class = 2,
    Race = 3,
    Faction = 4,
    Gender = 5,
    ItemLevel = 6,
    ItemLevelEquipped = 7,
    ItemLevelPvP = 8,
    Money = 9,
}
local characterDataMapIDToName = {
    [CharacterDataEnum.Level] = L["Level"],
    [CharacterDataEnum.Class] = L["Class"],
    [CharacterDataEnum.Race] = L["Race"],
    [CharacterDataEnum.Faction] = L["Faction"],
    [CharacterDataEnum.Gender] = L["Gender"],
    [CharacterDataEnum.ItemLevel] = L["Item Level (Overall)"],
    [CharacterDataEnum.ItemLevelEquipped] = L["Item Level (Equipped)"],
    [CharacterDataEnum.ItemLevelPvP] = L["Item Level (PvP)"],
    [CharacterDataEnum.Money] = L["Money"],
}
local characterDataMapNameToID = {}
for id,name in pairs(characterDataMapIDToName) do
    characterDataMapNameToID[name] = id
end
characterDataMapNameToID[L["Sex"]] = CharacterDataEnum.Gender
characterDataMapNameToID[L["Gold"]] = CharacterDataEnum.Money

local CharacterMixin = CreateFromMixins(External.StateMixin)
function CharacterMixin:Init(dataID)
	External.StateMixin.Init(self, dataID)

    self.name = characterDataMapIDToName[dataID]
end
function CharacterMixin:GetDisplayName()
    return string.format(L["Character: %s"], self:GetName())
end
function CharacterMixin:GetUniqueKey()
	return "character:" .. self:GetID()
end
function CharacterMixin:GetName()
    return self.name
end
function CharacterMixin:GetValue()
    if self.id == CharacterDataEnum.Level then
	    return self:GetCharacter():GetLevel() or 1
    elseif self.id == CharacterDataEnum.Class then
        local data = C_CreatureInfo.GetClassInfo(self:GetCharacter():GetClass() or 0)
	    return data and data.className or ""
    elseif self.id == CharacterDataEnum.Race then
        local data = C_CreatureInfo.GetRaceInfo(self:GetCharacter():GetRace() or 0)
	    return data and data.raceName or ""
    elseif self.id == CharacterDataEnum.Faction then
        local data = C_CreatureInfo.GetFactionInfo(self:GetCharacter():GetRace() or 0)
	    return data and data.name or ""
    elseif self.id == CharacterDataEnum.Sex then
        local gender = self:GetCharacter():GetSex()
        if gender == 2 then
	        return L["Male"]
        elseif gender == 3 then
	        return L["Female"]
        end
        return ""
    elseif self.id == CharacterDataEnum.ItemLevel then
	    return format("%.2f", self:GetCharacter():GetItemLevel() or 0)
    elseif self.id == CharacterDataEnum.ItemLevelEquipped then
	    return format("%.2f", self:GetCharacter():GetItemLevelEquipped() or 0)
    elseif self.id == CharacterDataEnum.ItemLevelPvP then
	    return format("%.2f", self:GetCharacter():GetItemLevelPvP() or 0)
    elseif self.id == CharacterDataEnum.Money then
	    return GetCoinTextureString(self:GetCharacter():GetMoney() or 0)
    end
end
function CharacterMixin:RegisterEventsFor(target)
    local id = self:GetID()
    if id == CharacterDataEnum.ItemLevel or id == CharacterDataEnum.ItemLevelEquipped or id == CharacterDataEnum.ItemLevelPvP then
        target:RegisterEvents("PLAYER_ENTERING_WORLD", "PLAYER_AVG_ITEM_LEVEL_UPDATE")
    elseif id == CharacterDataEnum.Money then
        target:RegisterEvents("PLAYER_ENTERING_WORLD", "PLAYER_MONEY")
    end
end

local CharacterProviderMixin = CreateFromMixins(External.StateProviderMixin)
function CharacterProviderMixin:GetID()
	return "character"
end
function CharacterProviderMixin:GetName()
	return L["Character Data"]
end
function CharacterProviderMixin:GetAddTitle()
	return string.format(BTWTODO_ADD_ITEM, self:GetName()), L["Enter the type of character data below"]
end
function CharacterProviderMixin:Acquire(...)
	return CreateAndInitFromMixin(CharacterMixin, ...)
end
function CharacterProviderMixin:GetFunctions()
	return {
		{
			name = "GetValue",
			returnValue = "string",
		},
    }
end
function CharacterProviderMixin:GetDefaults()
	return {}, { -- Text
		{"GetValue"}
	}
end
function CharacterProviderMixin:ParseInput(value)
	local num = tonumber(value)
	if num ~= nil and characterDataMapIDToName[num] then
		return true, num
	end
	if characterDataMapNameToID[value] then
        return true, characterDataMapNameToID[value]
    end
	return false, L["Invalid character data type"]
end
function CharacterProviderMixin:FillAutoComplete(tbl, text, offset, length)
    local text = strsub(text, offset, length):lower()
    for value in pairs(characterDataMapNameToID) do
        local name = value:lower()
        if #name >= #text and strsub(name, offset, length) == text then
            tbl[#tbl+1] = value
        end
    end
end
Internal.RegisterStateProvider(CreateFromMixins(CharacterProviderMixin))