local ADDON_NAME, Internal = ...
local External = _G[ADDON_NAME]
local L = Internal.L

--@TODO Match these to wing ids from TOWER_START combat log events
local widgetSetID = 399
local wingNameAreaIDs = {
    13403, -- Fracture Chambers
    13400, -- Skoldus Hall
    13404, -- Soulforges
    13411, -- Coldheart Interstitia
    13412, -- Mort'regar
    13413, -- The Upper Reaches
}
local wingNameWidgetIDs = {
    2925, -- Fracture Chambers
    2926, -- Skoldus Hall
    2924, -- Soulforges
    2927, -- Coldheart Interstitia
    2928, -- Mort'regar
    2929, -- The Upper Reaches
}
local wingLayerWidgetIDs = {
    2930, -- Fracture Chambers
    2932, -- Skoldus Hall
    2934, -- Soulforges
    2936, -- Coldheart Interstitia
    2938, -- Mort'regar
    2940, -- The Upper Reaches
}
local function GetWingName(id)
    return (C_Map.GetAreaInfo(wingNameAreaIDs[id]))
end
local function IsWingAvilable(id)
    local info = C_UIWidgetManager.GetTextWithStateWidgetVisualizationInfo(wingNameWidgetIDs[id])
    if info then
        return info.shownState == 1
    end
end
local function GetWingCompletedLayer(id)
    local info = C_UIWidgetManager.GetTextWithStateWidgetVisualizationInfo(wingLayerWidgetIDs[id])
    if info and info.text then
        local number = string.match(info.text, "^|c[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f].-([%d]+)")
        return tonumber(number)
    end
    return 0
end

local soulAshPerLayer = {
    180, 330, 460, 565, 655, 730,
    800, 860, 915, 960, 660, 680, -- Last 2 correct?
}
local soulCindersPerLayer = {
    0,  0,  0,  0,  0,  0,
    0, 50, 40, 30, 30, 30,
}
local function GetMaxTorghastLayerForWeek(week)
    return math.min(9 + week, 12)
end
local function GetWeeklyMaxSoulCindersForSeasonWeek(character, week)
    local layer = GetMaxTorghastLayerForWeek(week)
    local fromTorghastWing = 0
    for i=8,layer do
        fromTorghastWing = fromTorghastWing + soulCindersPerLayer[i]
    end
    local fromAssaults = 50
    if Internal.IsBeforeHalfWeeklyReset() or character.data.firstMawAssaultCompleted then
        fromAssaults = fromAssaults + 50
    end
    return 50 -- Tormentors of Torghast
         + fromAssaults -- Covenant Assault
         + fromTorghastWing * 2 -- Torghast
end
Internal.RegisterCustomStateFunction("GetWeeklyMaxSoulCindersForSeasonWeek", GetWeeklyMaxSoulCindersForSeasonWeek)

local function GetWeeklySoulCindersEarned(character)
    local count = 0
    if character:IsPlayer() then
        -- Tormentors of Torghast
        if C_QuestLog.IsQuestFlaggedCompleted(63854) then
            count = count + 50
        end

        -- Assault
        if C_QuestLog.IsQuestFlaggedCompleted(63543) or
           C_QuestLog.IsQuestFlaggedCompleted(63822) or
           C_QuestLog.IsQuestFlaggedCompleted(63823) or
           C_QuestLog.IsQuestFlaggedCompleted(63824) then
            count = count + 50
        end

        -- First Assault
        if not Internal.IsBeforeHalfWeeklyReset() and character.data.firstMawAssaultCompleted then
            count = count + 50
        end

        -- Torghast
        for i=1,6 do
            local layer = GetWingCompletedLayer(i)
            local fromTorghastWing = 0
            for i=8,layer do
                fromTorghastWing = fromTorghastWing + soulCindersPerLayer[i]
            end
            count = count + fromTorghastWing
        end
    else
        local questCompleted = character:GetDataTable("questCompleted")
        local wingCompleted = character:GetDataTable("torghastLayerCompleted")

        -- Tormentors of Torghast
        if questCompleted[63854] then
            count = count + 50
        end

        -- Assault
        if questCompleted[63543] or
           questCompleted[63822] or
           questCompleted[63823] or
           questCompleted[63824] then
            count = count + 50
        end

        -- First Assault
        if not Internal.IsBeforeHalfWeeklyReset() and character.data.firstMawAssaultCompleted then
            count = count + 50
        end

        -- Torghast
        for i=1,6 do
            local layer = wingCompleted and wingCompleted[i] or 0
            local fromTorghastWing = 0
            for i=8,layer do
                fromTorghastWing = fromTorghastWing + soulCindersPerLayer[i]
            end
            count = count + fromTorghastWing
        end
        -- @TODO
    end
    return count
end
Internal.RegisterCustomStateFunction("GetWeeklySoulCindersEarned", GetWeeklySoulCindersEarned)

local TorghastMixin = CreateFromMixins(External.StateMixin)
function TorghastMixin:Init(id)
	External.StateMixin.Init(self, id)

	self.name = GetWingName(id)
end
function TorghastMixin:GetDisplayName()
    return string.format(L["Torghast Wing: %s"], self:GetName())
end
function TorghastMixin:GetUniqueKey()
	return "torghast:" .. self:GetID()
end
function TorghastMixin:GetName()
    return self.name or self:GetID()
end
function TorghastMixin:IsAvailable()
    return IsWingAvilable(self:GetID())
end
function TorghastMixin:HasCompletedLayer(layer)
    return self:GetCompletedLayer() >= layer
end
function TorghastMixin:GetCompletedLayer()
	if self:GetCharacter():IsPlayer() then
		return GetWingCompletedLayer(self:GetID())
	else
		return self:GetCharacter():GetData("torghastLayerCompleted", self:GetID()) or 0
	end
end
function TorghastMixin:IsCompleted()
    return self:HasCompletedLayer(GetMaxTorghastLayerForWeek(Internal.GetSeasonWeek()))
end
function TorghastMixin:RegisterEventsFor(driver)
    driver:RegisterEvents("PLAYER_ENTERING_WORLD", "WEEKLY_RESET") -- @TODO Need a torghast end event
end

local TorghastProviderMixin = CreateFromMixins(External.StateProviderMixin)
function TorghastProviderMixin:GetID()
	return "torghast"
end
function TorghastProviderMixin:GetName()
	return L["Torghast Wing"]
end
function TorghastProviderMixin:Acquire(...)
	return CreateAndInitFromMixin(TorghastMixin, ...)
end
function TorghastProviderMixin:GetFunctions()
	return {
		{
			name = "IsCompleted",
			returnValue = "bool",
		},
    }
end
function TorghastProviderMixin:GetDefaults()
	return { -- Completed
        "or", {"IsWeeklyCapped"}, {"IsCapped"},
	}, { -- Text
		{"GetQuantity"}
	}
end
function TorghastProviderMixin:ParseInput(value)
	local num = tonumber(value)
	if num ~= nil and wingNameAreaIDs[num] ~= nil then
		return true, num
	end
    for id in ipairs(wingNameAreaIDs) do
        if GetWingName(id):lower() == value:lower() then
            return true, id
        end
    end
	return false, L["Invalid torghast wing"]
end
function TorghastProviderMixin:FillAutoComplete(tbl, text, offset, length)
    local text = strsub(text, offset, length):lower()
    for id in ipairs(wingNameAreaIDs) do
        local value = GetWingName(id)
        local name = value:lower()
        if #name >= #text and strsub(name, offset, length) == text then
            tbl[#tbl+1] = value
        end
    end
end
Internal.RegisterStateProvider(CreateFromMixins(TorghastProviderMixin))

-- Update our list of currencies to save for players
Internal.RegisterEvent("PLAYER_LOGIN", function()
    local player = Internal.GetPlayer()
	local completed = player:GetDataTable("torghastLayerCompleted")
    wipe(completed)

    for wing in ipairs(wingLayerWidgetIDs) do
        completed[wing] = GetWingCompletedLayer(wing)
    end
end)
