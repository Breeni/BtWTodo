--[[
    State provider for Mythic Keystones
]]

local ADDON_NAME, Internal = ...
local External = _G[ADDON_NAME]
local L = Internal.L

local KeystoneMixin = CreateFromMixins(External.StateMixin)
function KeystoneMixin:Init() -- Unlike most, this doesnt need an id
	External.StateMixin.Init(self)
end
function KeystoneMixin:GetDisplayName()
    return L["Mythic Keystone"]
end
function KeystoneMixin:GetUniqueKey()
	return "keystone"
end
function KeystoneMixin:GetChallengeMapID()
    if self:GetCharacter():IsPlayer() then
        return C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    else
        local tbl = self:GetCharacter():GetDataTable("keystone")
        return tbl and tbl.challengeMapID
    end
end
function KeystoneMixin:GetLevel()
    if self:GetCharacter():IsPlayer() then
        return C_MythicPlus.GetOwnedKeystoneLevel()
    else
        local tbl = self:GetCharacter():GetDataTable("keystone")
        return tbl and tbl.level or nil
    end
end
function KeystoneMixin:GetChallengeMapName()
    local mapID = self:GetChallengeMapID()
    if mapID then
        return (C_ChallengeMode.GetMapUIInfo(mapID))
    end
end
local shortNames = {
    -- Shadowlands
    [375] = L["Mists"],
    [376] = L["NW"],
    [377] = L["DoS"],
    [378] = L["HoA"],
    [379] = L["PF"],
    [380] = L["SD"],
    [381] = L["SoA"],
    [382] = L["ToP"],
}
function KeystoneMixin:GetChallengeShortMapName()
    local mapID = self:GetChallengeMapID()
    if mapID then
        return shortNames[mapID] or (C_ChallengeMode.GetMapUIInfo(mapID))
    end
end
function KeystoneMixin:RegisterEventsFor(target)
    target:RegisterEvents("PLAYER_ENTERING_WORLD", "CHALLENGE_MODE_MAPS_UPDATE", "CHALLENGE_MODE_START", "BAG_UPDATE_DELAYED", "GOSSIP_CLOSED", "WEEKLY_RESET")
end

local KeystoneProviderMixin = CreateFromMixins(External.StateProviderMixin)
function KeystoneProviderMixin:GetID()
	return "keystone"
end
function KeystoneProviderMixin:GetName()
	return L["Mythic Keystone"]
end
function KeystoneProviderMixin:RequiresID()
	return false
end
function KeystoneProviderMixin:Acquire(...)
	return CreateAndInitFromMixin(KeystoneMixin, ...)
end
function KeystoneProviderMixin:GetFunctions()
	return {
    }
end
function KeystoneProviderMixin:GetDefaults()
	return {}, { -- Text
		{"GetValue"}
	}
end
Internal.RegisterStateProvider(CreateFromMixins(KeystoneProviderMixin))

local function UpdatePlayerKeystone ()
    Internal.GetPlayer():SetDataTable("keystone", {
        challengeMapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID(),
        level = C_MythicPlus.GetOwnedKeystoneLevel(),
    })
end
local function RegisterEvents()
    Internal.RegisterEvent("PLAYER_ENTERING_WORLD", UpdatePlayerKeystone)
    Internal.RegisterEvent("CHALLENGE_MODE_START", UpdatePlayerKeystone) -- Dungeon start, keystone is -1 levels
    Internal.RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE", UpdatePlayerKeystone) -- Dungeon end, CHALLENGE_MODE_COMPLETED is too early for new keystone
    Internal.RegisterEvent("BAG_UPDATE_DELAYED", UpdatePlayerKeystone) -- Got keystone from vault
    Internal.RegisterEvent("GOSSIP_CLOSED", UpdatePlayerKeystone) -- Lowered keystone within Oribos

    Internal.UnregisterEvent("PLAYER_ENTERING_WORLD", RegisterEvents)

    UpdatePlayerKeystone()
end
Internal.RegisterEvent("PLAYER_ENTERING_WORLD", RegisterEvents)

Internal.RegisterEvent("WEEKLY_RESET", function ()
    for _,character in Internal.IterateCharacters() do
		local keystone = character:GetDataTable("keystone")
		wipe(keystone)
	end
end, -1)
