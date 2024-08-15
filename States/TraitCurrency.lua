local ADDON_NAME, Internal = ...

if not Internal.Is100000OrBeyond then
    return
end

local External = _G[ADDON_NAME]
local L = Internal.L

local supported = {
    [2563] = {
        treeID = 672,
        name = GENERIC_TRAIT_FRAME_DRAGONRIDING_TITLE,
    }
}
local nameToIDMap = {};
for id,currency in pairs(supported) do
    nameToIDMap[currency.name] = id;
end

local TraitCurrencyMixin = CreateFromMixins(External.StateMixin)
function TraitCurrencyMixin:Init(traitCurrencyID, treeID)
	External.StateMixin.Init(self, traitCurrencyID)

    if supported[traitCurrencyID] then
        Mixin(self, supported[traitCurrencyID])
    end

    self.treeID = treeID or self.treeID
    if not self.name then
        self.name = tostring(traitCurrencyID)
    end
end
function TraitCurrencyMixin:GetDisplayName()
    return string.format(L["Trait Currency: %s"], self:GetName())
end
function TraitCurrencyMixin:GetDataKey()
	return self:GetID() .. ":" .. self.treeID
end
function TraitCurrencyMixin:GetUniqueKey()
	return "traitcurrency:" .. self:GetDataKey()
end
function TraitCurrencyMixin:GetName()
    return self.name
end
function TraitCurrencyMixin:GetCurrencyInfo()
    local traitCurrencyID = self:GetID()
    local treeCurrencies = C_Traits.GetTreeCurrencyInfo(C_Traits.GetConfigIDByTreeID(self.treeID), self.treeID, true)
    for _,currencyInfo in ipairs(treeCurrencies) do
        if currencyInfo.traitCurrencyID == traitCurrencyID then
            return currencyInfo;
        end
    end
end
function TraitCurrencyMixin:GetQuantity()
	if self:GetCharacter():IsPlayer() then
        local currencyInfo = self:GetCurrencyInfo()
		return currencyInfo and currencyInfo.quantity or 0;
	else
		return self:GetCharacter():GetData("traitCurrencyQuantity",self:GetDataKey()) or 0
	end
end
function TraitCurrencyMixin:GetSpent()
	if self:GetCharacter():IsPlayer() then
        local currencyInfo = self:GetCurrencyInfo()
		return currencyInfo and currencyInfo.spent or 0;
	else
		return self:GetCharacter():GetData("traitCurrencySpent",self:GetDataKey()) or 0
	end
end
function TraitCurrencyMixin:GetTotalEarned()
	return self:GetQuantity() + self:GetSpent()
end
function TraitCurrencyMixin:HaveSpentAll()
    return self:GetSpent() >= self:GetMaxQuantity()
end
function TraitCurrencyMixin:RegisterEventsFor(driver)
    driver:RegisterEvents("PLAYER_ENTERING_WORLD", "TRAIT_TREE_CURRENCY_INFO_UPDATED")
end

local TraitCurrencyProviderMixin = CreateFromMixins(External.StateProviderMixin)
function TraitCurrencyProviderMixin:GetID()
	return "traitcurrency"
end
function TraitCurrencyProviderMixin:GetName()
	return L["Trait Currency"]
end
function TraitCurrencyProviderMixin:Acquire(...)
	return CreateAndInitFromMixin(TraitCurrencyMixin, ...)
end
function TraitCurrencyProviderMixin:GetFunctions()
	return {
		{
			name = "IsCapped",
			returnValue = "bool",
		},
		{
			name = "IsWeeklyCapped",
			returnValue = "bool",
		},
    }
end
function TraitCurrencyProviderMixin:GetDefaults()
	return { -- Completed
        "or", {"IsWeeklyCapped"}, {"IsCapped"},
	}, { -- Text
		{"GetQuantity"}
	}
end
function TraitCurrencyProviderMixin:ParseInput(value)
	local num = tonumber(value)
	if num ~= nil then
		return true, num
	end
	if nameToIDMap[value] then
        return true, nameToIDMap[value]
    end
	return false, L["Invalid trait currency"]
end
function TraitCurrencyProviderMixin:FillAutoComplete(tbl, text, offset, length)
    local text = strsub(text, offset, length):lower()
    for value in pairs(nameToIDMap) do
        local name = value:lower()
        if #name >= #text and strsub(name, offset, length) == text then
            tbl[#tbl+1] = value
        end
    end
    table.sort(tbl)
end
Internal.RegisterStateProvider(CreateFromMixins(TraitCurrencyProviderMixin))
