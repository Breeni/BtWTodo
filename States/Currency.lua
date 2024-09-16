--[[
    State provider for currencies
]]

local ADDON_NAME, Internal = ...
local External = _G[ADDON_NAME]
local L = Internal.L

local currencyMapNameToID = {}

local CurrencyMixin = CreateFromMixins(External.StateMixin)
function CurrencyMixin:Init(currencyID)
	External.StateMixin.Init(self, currencyID)

    if Internal.data and Internal.data.currencies and Internal.data.currencies[currencyID] then
		Mixin(self, Internal.data.currencies[currencyID]);
    end
    if BtWTodoCache.currencies[currencyID] then
		Mixin(self, BtWTodoCache.currencies[currencyID]);
    end

    Mixin(self, C_CurrencyInfo.GetCurrencyInfo(currencyID))

    if not BtWTodoCache.currencies[currencyID] then
        BtWTodoCache.currencies[currencyID] = {}
    end

    self.discovered = nil
    self.isShowInBackpack = nil
    self.quantity = nil
    self.quantityEarnedThisWeek = nil
    self.totalEarned = nil
end
function CurrencyMixin:GetDisplayName()
    return string.format(L["Currency: %s"], self:GetName())
end
function CurrencyMixin:GetUniqueKey()
	return "currency:" .. self:GetID()
end
function CurrencyMixin:GetName()
    return self.name
end
function CurrencyMixin:GetQuantity()
	if self:GetCharacter():IsPlayer() then
        local info = C_CurrencyInfo.GetCurrencyInfo(self:GetID());
		return info and info.quantity or 0;
	else
		return self:GetCharacter():GetData("currencyQuantity", self:GetID()) or 0
	end
end
function CurrencyMixin:GetQuantityEarnedThisWeek()
	if self:GetCharacter():IsPlayer() then
        local info = C_CurrencyInfo.GetCurrencyInfo(self:GetID());
		return info and info.quantityEarnedThisWeek or 0;
	else
		return self:GetCharacter():GetData("currencyEarnedThisWeek", self:GetID()) or 0
	end
end
function CurrencyMixin:GetTotalEarned()
	if self:GetCharacter():IsPlayer() then
        local info = C_CurrencyInfo.GetCurrencyInfo(self:GetID());
		return info and info.totalEarned or 0;
	else
		return self:GetCharacter():GetData("currencyTotalEarned", self:GetID()) or 0
	end
end
function CurrencyMixin:GetMaxQuantity()
	return self.maxQuantity or 0
end
function CurrencyMixin:GetMaxWeeklyQuantity()
	return self.maxWeeklyQuantity or 0
end
function CurrencyMixin:UseTotalEarnedForMaxQty()
	return self.useTotalEarnedForMaxQty or 0
end
function CurrencyMixin:IsCapped()
    if self:UseTotalEarnedForMaxQty() then
        return self:GetTotalEarned() >= self:GetMaxQuantity()
    else
        return self:GetQuantity() >= self:GetMaxQuantity()
    end
end
function CurrencyMixin:IsWeeklyCapped()
    return self:GetQuantityEarnedThisWeek() > self:GetMaxWeeklyQuantity()
end
function CurrencyMixin:HasWeeklyCap()
	return self:GetMaxWeeklyQuantity() ~= 0
end
function CurrencyMixin:HasCap()
    return self:GetMaxQuantity() ~= 0
end
function CurrencyMixin:RegisterEventsFor(driver)
    if self:GetID() == 1822 then
        driver:RegisterEvents("PLAYER_ENTERING_WORLD", "COVENANT_SANCTUM_RENOWN_LEVEL_CHANGED", "WEEKLY_RESET")
    else
        driver:RegisterEvents("PLAYER_ENTERING_WORLD", "CURRENCY_DISPLAY_UPDATE", "CHAT_MSG_CURRENCY", "DAILY_RESET", "HALF_WEEKLY_RESET")
    end
end

local CurrencyProviderMixin = CreateFromMixins(External.StateProviderMixin)
function CurrencyProviderMixin:GetID()
	return "currency"
end
function CurrencyProviderMixin:GetName()
	return L["Currency"]
end
function CurrencyProviderMixin:Acquire(...)
	return CreateAndInitFromMixin(CurrencyMixin, ...)
end
function CurrencyProviderMixin:GetFunctions()
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
function CurrencyProviderMixin:GetDefaults()
	return { -- Completed
        "or", {"IsWeeklyCapped"}, {"IsCapped"},
	}, { -- Text
		{"GetQuantity"}
	}
end
function CurrencyProviderMixin:ParseInput(value)
	local num = tonumber(value)
	if num ~= nil then
		return true, num
	end
	if currencyMapNameToID[value] then
        return true, currencyMapNameToID[value]
    end
	return false, L["Invalid currency"]
end
function CurrencyProviderMixin:FillAutoComplete(tbl, text, offset, length)
    local text = strsub(text, offset, length):lower()
    for value in pairs(currencyMapNameToID) do
        local name = value:lower()
        if #name >= #text and strsub(name, offset, length) == text then
            tbl[#tbl+1] = value
        end
    end
    table.sort(tbl)
end
Internal.RegisterStateProvider(CreateFromMixins(CurrencyProviderMixin))

-- Update our list of currencies to save for players
Internal.RegisterEvent("PLAYER_ENTERING_WORLD", function()
    for index=1,C_CurrencyInfo.GetCurrencyListSize() do
        local link = C_CurrencyInfo.GetCurrencyListLink(index)
        if link then
            local _, id = strsplit(":", string.match(link, "currency:[:%d]+"))
            id = tonumber(id)

            if id then
                local data = BtWTodoCache.currencies[id] or {}
                BtWTodoCache.currencies[id] = data
            end
        end
    end

    -- Update the currency map store
    for id in pairs(BtWTodoCache.currencies) do
        local info = C_CurrencyInfo.GetCurrencyInfo(id)
        if info then
            currencyMapNameToID[info.name] = id
        end
    end
end, -2)

-- Save Currency Data for Player
Internal.RegisterEvent("PLAYER_LOGOUT", function ()
    local player = Internal.GetPlayer()
	local quantity = player:GetDataTable("currencyQuantity")
	local totalEarned = player:GetDataTable("currencyTotalEarned")
    wipe(quantity)
    wipe(totalEarned)

    for id in pairs(BtWTodoCache.currencies) do
        local currency = C_CurrencyInfo.GetCurrencyInfo(id)
        if currency then
            if currency.quantity ~= 0 then
                quantity[id] = currency.quantity
            end
            if currency.totalEarned ~= 0 then
                totalEarned[id] = currency.totalEarned
            end
        end
    end
end)

-- Handle currencies that reset each season
local seasonalCurrencies = {
    [1191] = true, -- Valor
    [1602] = true, -- Conquest
    [1904] = true, -- Tower Knowledge
}
Internal.RegisterEvent("SEASON_RESET", function ()
    for _,character in Internal.IterateCharacters() do
		local quantity = character:GetDataTable("currencyQuantity")
		local totalEarned = character:GetDataTable("currencyTotalEarned")
		for currencyID in pairs(seasonalCurrencies) do
            quantity[currencyID] = nil
            totalEarned[currencyID] = nil
		end
	end
end)
