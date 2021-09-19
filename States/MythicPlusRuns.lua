--[[
    State provider for Mythic Plus Runs
]]

local ADDON_NAME, Internal = ...
local External = _G[ADDON_NAME]
local L = Internal.L

local MythicPlusRunsMixin = CreateFromMixins(External.StateMixin)
function MythicPlusRunsMixin:Init() -- Unlike most, this doesnt need an id
	External.StateMixin.Init(self)
end
function MythicPlusRunsMixin:GetDisplayName()
    return L["Mythic Plus Runs"]
end
function MythicPlusRunsMixin:GetUniqueKey()
	return "mythicplusruns"
end
function MythicPlusRunsMixin:IterateRuns()
    local runHistory
    if self:GetCharacter():IsPlayer() then
        runHistory = C_MythicPlus.GetRunHistory(false, true);
	    table.sort(runHistory, function (a, b)
            if a.level == b.level then
                return a.mapChallengeModeID < b.mapChallengeModeID;
            else
                return a.level > b.level;
            end
        end)
    else
        runHistory = self:GetCharacter():GetDataTable("mythicPlusRuns")
    end
    return function (tbl, index)
        index = index + 1
        if tbl[index] then
            local mapChallengeModeID = tbl[index].mapChallengeModeID
            return index, mapChallengeModeID, C_ChallengeMode.GetMapUIInfo(mapChallengeModeID), tbl[index].level, tbl[index].completed
        end
    end, runHistory, 0
end
-- FROM: None of these should be used really
function MythicPlusRunsMixin:GetCount()
    if self:GetCharacter():IsPlayer() then
	    return #C_MythicPlus.GetRunHistory(false, true);
    else
        return #self:GetCharacter():GetDataTable("mythicPlusRuns")
    end
end
function MythicPlusRunsMixin:GetRun(index)
    if self:GetCharacter():IsPlayer() then
        local runHistory = C_MythicPlus.GetRunHistory(false, true);
	    table.sort(runHistory, function (a, b)
            if a.level == b.level then
                return a.mapChallengeModeID < b.mapChallengeModeID;
            else
                return a.level > b.level;
            end
        end)
        return runHistory[index]
    else
        return self:GetCharacter():GetData("mythicPlusRuns", 1)
    end
end
function MythicPlusRunsMixin:GetRunDungeon(index)
    return self:GetRun(index).mapChallengeModeID
end
function MythicPlusRunsMixin:GetRunDungeonName(index)
    return C_ChallengeMode.GetMapUIInfo(self:GetRunDungeon(index));
end
function MythicPlusRunsMixin:GetRunLevel(index)
    return self:GetRun(index).level
end
function MythicPlusRunsMixin:IsRunInTime(index)
    return self:GetRun(index).completed
end
-- TO: None of these should be used really
function MythicPlusRunsMixin:RegisterEventsFor(target)
    target:RegisterEvents("PLAYER_ENTERING_WORLD", "CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_MAPS_UPDATE")
end

local MythicPlusRunsProviderMixin = CreateFromMixins(External.StateProviderMixin)
function MythicPlusRunsProviderMixin:GetID()
	return "mythicplusruns"
end
function MythicPlusRunsProviderMixin:GetName()
	return L["Mythic Plus Runs"]
end
function MythicPlusRunsProviderMixin:RequiresID()
	return false
end
function MythicPlusRunsProviderMixin:Acquire(...)
	return CreateAndInitFromMixin(MythicPlusRunsMixin, ...)
end
function MythicPlusRunsProviderMixin:GetFunctions()
	return {
    }
end
function MythicPlusRunsProviderMixin:GetDefaults()
	return {}, { -- Text
		{"GetValue"}
	}
end
Internal.RegisterStateProvider(CreateFromMixins(MythicPlusRunsProviderMixin))

Internal.RegisterCustomStateFunction("GetRewardLevelForDifficultyLevel", function (level)
    return C_MythicPlus.GetRewardLevelForDifficultyLevel(level)
end)

local function PLAYER_LOGOUT()
    local player = Internal.GetPlayer()

    local runHistory = C_MythicPlus.GetRunHistory(false, true);
    table.sort(runHistory, function (a, b)
        if a.level == b.level then
            return a.mapChallengeModeID < b.mapChallengeModeID;
        else
            return a.level > b.level;
        end
    end)

    player:SetDataTable("mythicPlusRuns", runHistory)
end
Internal.RegisterEvent("PLAYER_LOGOUT", PLAYER_LOGOUT)

-- The C_MythicPlus.RequestMapInfo will update C_MythicPlus.GetRunHistory but there is a limit on how
-- often it will cause the update, below we put a minute delay before we call it since the previous call
local previousRequest = nil
hooksecurefunc(C_MythicPlus, "RequestMapInfo", function ()
    --@debug@
    print("RequestMapInfo called")
    --@end-debug@
    previousRequest = GetTime()
end)
--@debug@
Internal.RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE", function ()
    print("Run Count", #C_MythicPlus.GetRunHistory(false, true))
end)
--@end-debug@
local function RequestMapInfoAsap()
    if previousRequest <= GetTime() - 70 then
        C_MythicPlus.RequestMapInfo()
    else
        C_Timer.After(previousRequest + 70 - GetTime(), RequestMapInfoAsap)
    end
end
Internal.RegisterEvent("CHALLENGE_MODE_COMPLETED", function ()
    C_Timer.After(5, RequestMapInfoAsap)
end)
