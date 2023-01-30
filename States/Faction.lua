--[[
    State provider for currencies
]]

local ADDON_NAME, Internal = ...
local External = _G[ADDON_NAME]
local L = Internal.L

local factionMapNameToID = {}

local FactionMixin = CreateFromMixins(External.StateMixin)
function FactionMixin:Init(factionID)
	External.StateMixin.Init(self, factionID)

    if Internal.data and Internal.data.factions and Internal.data.factions[factionID] then
		Mixin(self, Internal.data.factions[factionID]);
    end
    if BtWTodoCache.factions[factionID] then
		Mixin(self, BtWTodoCache.factions[factionID]);
    end

    local _
    self.name, self.description, _, _, _, _, self.canToggleAtWar = GetFactionInfoByID(self:GetID())

    local friendshipInfo = C_GossipInfo and C_GossipInfo.GetFriendshipReputation and C_GossipInfo.GetFriendshipReputation(self:GetID()) or nil
    if friendshipInfo then
        self.max = friendshipInfo.maxRep > 0 and friendshipInfo.maxRep or 42000
    else
        self.max = (select(3, GetFriendshipReputation(self:GetID()))) or 42000
    end
    self.paragonMax = select(2, C_Reputation.GetFactionParagonInfo(self:GetID())) or 0
    self.isMajorFaction = (C_MajorFactions and C_MajorFactions.GetMajorFactionData and C_MajorFactions.GetMajorFactionData(factionID)) ~= nil
end
function FactionMixin:GetDisplayName()
    return string.format(L["Faction: %s"], self:GetName())
end
function FactionMixin:GetUniqueKey()
	return "faction:" .. self:GetID()
end
function FactionMixin:GetName()
    return self.name
end
function FactionMixin:GetDescription()
    return self.description
end
function FactionMixin:HasParagon()
    return C_Reputation.GetFactionParagonInfo(self:GetID()) ~= nil
end
function FactionMixin:HasParagonAvailable()
	if self:GetCharacter():IsPlayer() then
        return select(4, C_Reputation.GetFactionParagonInfo(self:GetID())) or false
    else
		return self:GetCharacter():GetData("factionParagonAvailable", self:GetID())
    end
end
function FactionMixin:IsMajorFaction()
    return self.isMajorFaction
end
function FactionMixin:GetStanding()
	if self:GetCharacter():IsPlayer() then
        if self.isMajorFaction then
            local majorFactionData = C_MajorFactions.GetMajorFactionData(self:GetID())
            return majorFactionData.renownLevel or 0
        end

        local friendshipInfo = C_GossipInfo and C_GossipInfo.GetFriendshipReputation and C_GossipInfo.GetFriendshipReputation(self:GetID()) or nil
        if friendshipInfo then
            return friendshipInfo.standing
        end

        return (select(3, GetFactionInfoByID(self:GetID())) or 0)
	else
		return self:GetCharacter():GetData("factionStanding", self:GetID()) or 0
	end
end
function FactionMixin:IsStanding(standing)
    return self:GetStanding() >= standing
end
function FactionMixin:GetMaxQuantity()
    return self.max
end
function FactionMixin:GetQuantity()
	if self:GetCharacter():IsPlayer() then
        if self.isMajorFaction then
            local majorFactionData = C_MajorFactions.GetMajorFactionData(self:GetID())
            return (majorFactionData.renownLevelThreshold or 0) * ((majorFactionData.renownLevel or 1) - 1) + (majorFactionData.renownReputationEarned or 0)
        end

        local friendshipInfo = C_GossipInfo and C_GossipInfo.GetFriendshipReputation and C_GossipInfo.GetFriendshipReputation(self:GetID()) or nil
        if friendshipInfo then
            return friendshipInfo.standing
        end

        return (select(6, GetFactionInfoByID(self:GetID())) or 0)
	else
		return self:GetCharacter():GetData("factionQuantity", self:GetID()) or 0
	end
end
function FactionMixin:IsCapped()
    return self:GetQuantity() >= self:GetMaxQuantity()
end
function FactionMixin:GetTotalMaxQuantity()
    return self.max + self.paragonMax
end
function FactionMixin:GetTotalQuantity()
	if self:GetCharacter():IsPlayer() then
        if self.isMajorFaction then
            local majorFactionData = C_MajorFactions.GetMajorFactionData(self:GetID())
            return (majorFactionData.renownLevelThreshold or 0) * ((majorFactionData.renownLevel or 1) - 1) + (majorFactionData.renownReputationEarned or 0)
        end

        local currentValue, _, _, hasRewardPending = C_Reputation.GetFactionParagonInfo(self:GetID())
        if currentValue ~= nil then
            currentValue = currentValue % 10000
            if hasRewardPending then
                currentValue = currentValue + 10000
            end
        end

        local standingMin, _, standingValue = select(4, GetFactionInfoByID(self:GetID()))
        return (standingMin or 0) + (standingValue or 0) + (currentValue or 0)
	else
		return self:GetCharacter():GetData("factionTotalQuantity", self:GetID()) or 0
	end
end
function FactionMixin:IsTotalCapped()
    return self:GetTotalQuantity() >= self:GetTotalMax()
end
function FactionMixin:GetStandingMaxQuantity()
	if self:GetCharacter():IsPlayer() then
        if self.isMajorFaction then
            local majorFactionData = C_MajorFactions.GetMajorFactionData(self:GetID())
            return majorFactionData.renownLevelThreshold or 0
        end

        if C_GossipInfo and C_GossipInfo.GetFriendshipReputation then
            local info = C_GossipInfo.GetFriendshipReputation(self:GetID())

            if info and info.friendshipFactionID == self:GetID() then
                return (info.nextThreshold or info.reactionThreshold) - info.reactionThreshold
            end
        end

        local currentValue, threshold = C_Reputation.GetFactionParagonInfo(self:GetID())
        if currentValue ~= nil and currentValue ~= 0 then
            return threshold
        end

        local standingMin, standingMax = select(4, GetFactionInfoByID(self:GetID()))
        return standingMax - standingMin
	else
		return self:GetCharacter():GetData("factionStandingMax", self:GetID()) or 0
    end
end
function FactionMixin:GetStandingQuantity()
	if self:GetCharacter():IsPlayer() then
        if self.isMajorFaction then
            local majorFactionData = C_MajorFactions.GetMajorFactionData(self:GetID())
            return majorFactionData.renownReputationEarned or 0
        end

        if C_GossipInfo and C_GossipInfo.GetFriendshipReputation then
            local info = C_GossipInfo.GetFriendshipReputation(self:GetID())
            if info and info.friendshipFactionID == self:GetID() then
                return info.standing - info.reactionThreshold
            end
        end

        local currentValue, _, _, hasRewardPending = C_Reputation.GetFactionParagonInfo(self:GetID())
        if currentValue ~= nil and currentValue ~= 0 then
            currentValue = currentValue % 10000
            if hasRewardPending then
                currentValue = currentValue + 10000
            end
            return currentValue
        end

        local standingMin, _, standingValue = select(4, GetFactionInfoByID(self:GetID()))
        return standingValue - standingMin
	else
		return self:GetCharacter():GetData("factionStandingQuantity", self:GetID()) or 0
	end
end
-- Get the number of paragon boxes looted, not counting if 1 is available
function FactionMixin:GetParagonLooted()
	if self:GetCharacter():IsPlayer() then
        local currentValue, _, _, hasRewardPending = C_Reputation.GetFactionParagonInfo(self:GetID())
        if currentValue == nil then
            return 0
        end
        if hasRewardPending then
            currentValue = currentValue - 10000
        end
        return math.floor(currentValue * 0.0001)
	else
		return self:GetCharacter():GetData("factionParagonLooted", self:GetID()) or 0
	end
end
function FactionMixin:RegisterEventsFor(driver)
    driver:RegisterEvents("PLAYER_ENTERING_WORLD", "UPDATE_FACTION", "DAILY_RESET", "HALF_WEEKLY_RESET")
end

local FactionProviderMixin = CreateFromMixins(External.StateProviderMixin)
function FactionProviderMixin:GetID()
	return "faction"
end
function FactionProviderMixin:GetName()
	return L["Faction"]
end
function FactionProviderMixin:Acquire(...)
	return CreateAndInitFromMixin(FactionMixin, ...)
end
function FactionProviderMixin:GetFunctions()
	return {
		{
			name = "IsCapped",
			returnValue = "bool",
		},
    }
end
function FactionProviderMixin:GetDefaults()
	return { -- Completed
        {"IsCapped"},
	}, { -- Text
		{"GetQuantity"}
	}
end
function FactionProviderMixin:ParseInput(value)
	local num = tonumber(value)
	if num ~= nil then
		return true, num
	end
	if factionMapNameToID[value] then
        return true, factionMapNameToID[value]
    end
	return false, L["Invalid Faction"]
end
function FactionProviderMixin:FillAutoComplete(tbl, text, offset, length)
    local text = strsub(text, offset, length):lower()
    for value in pairs(factionMapNameToID) do
        local name = value:lower()
        if #name >= #text and strsub(name, offset, length) == text then
            tbl[#tbl+1] = value
        end
    end
    table.sort(tbl)
end
Internal.RegisterStateProvider(CreateFromMixins(FactionProviderMixin))

-- Update our list of currencies to save for players
Internal.RegisterEvent("PLAYER_LOGIN", function()
    for index=1,GetNumFactions() do
        local name, isHeader, id = GetFactionInfo(index), select(9, GetFactionInfo(index)), select(14, GetFactionInfo(index))
        if not isHeader then
            local data = BtWTodoCache.factions[id] or {}
            data.name = name
            BtWTodoCache.factions[id] = data
        end
    end

    -- Update the faction map store
    for id in pairs(BtWTodoCache.factions) do
        local name =  GetFactionInfo(id)
        if not name then
            local data = BtWTodoCache.factions[id]
            name = data and data.name
        end
        if name then
            factionMapNameToID[name] = id
        end
    end
end)

-- Save Faction Data for Player
Internal.RegisterEvent("PLAYER_ENTERING_WORLD", function ()
    local player = Internal.GetPlayer()
	local standing = player:GetDataTable("factionStanding")
	local quantity = player:GetDataTable("factionQuantity")
	local totalQuantity = player:GetDataTable("factionTotalQuantity")
	local standingMax = player:GetDataTable("factionStandingMax")
	local standingQuantity = player:GetDataTable("factionStandingQuantity")
	local paragonAvailable = player:GetDataTable("factionParagonAvailable")
	local paragonLooted = player:GetDataTable("factionParagonLooted")
    wipe(standing)
    wipe(quantity)
    wipe(totalQuantity)
    wipe(standingMax)
    wipe(standingQuantity)
    wipe(paragonAvailable)
    wipe(paragonLooted)

    for id in pairs(BtWTodoCache.factions) do
        local standingID, standingMin, standingMaxValue, standingValue = select(3, GetFactionInfoByID(id))
        if standingValue then
            local paragonValue, threshold, _, hasRewardPending = C_Reputation.GetFactionParagonInfo(id)
            local currentValue, numLooted
            if paragonValue ~= nil and paragonValue ~= 0 then
                currentValue = paragonValue
                numLooted = paragonValue

                currentValue = currentValue % 10000
                if hasRewardPending then
                    currentValue = currentValue + 10000
                    numLooted = numLooted - 10000
                end
                numLooted = math.floor(numLooted * 0.0001)
            end

            standing[id] = standingID
            if standingValue ~= 0 then
                quantity[id] = standingValue
            end
            if standingMin + standingValue + (currentValue or 0) ~= 0 then
                totalQuantity[id] = standingMin + standingValue + (currentValue or 0)
            end
            if currentValue ~= nil and currentValue ~= 0 then
                standingMax[id] = threshold
            elseif standingMaxValue - standingMin ~= 0 then
                standingMax[id] = standingMaxValue - standingMin
            end
            if currentValue or (standingValue - standingMin) ~= 0 then
                standingQuantity[id] = currentValue or (standingValue - standingMin)
            end
            if hasRewardPending then
                paragonAvailable[id] = true
            end
            if numLooted ~= nil and numLooted ~= 0 then
                paragonLooted[id] = numLooted
            end
        end
    end
end)

Internal.RegisterCustomStateFunction("GetFactionRank", function (quantity, ranks)
    if quantity == 0 then
        return 0
    end
    for i,amount in ipairs(ranks) do
        if quantity <= amount then
            return i - (ranks[1] == 0 and 1 or 0)
        end
    end
    return #ranks + (ranks[1] == 0 and 1 or 0)
end)
