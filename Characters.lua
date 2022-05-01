--[[
    Handles storing data for characters, this gets passed to State Providers before completion states are checked
]]
local ADDON_NAME, Internal = ...
local External = _G[ADDON_NAME]
local CovenantsSupported = C_Covenants ~= nil

local CharacterMixin = {}
function CharacterMixin:Init(name, realm, data)
    self.name = name
    self.realm = realm
    self.data = data
end
function CharacterMixin:GetName()
    return self.name
end
function CharacterMixin:GetRealm()
    return self.realm
end
function CharacterMixin:IsPlayer()
    return false
end
function CharacterMixin:GetDisplayName(includeRealm, dontColorCode)
    local name = self:GetName()
    if not dontColorCode then
        local classID = self:GetClass()
        local classInfo = classID and C_CreatureInfo.GetClassInfo(classID);
        local classColor = classInfo and C_ClassColor.GetClassColor(classInfo.classFile);
        name = classColor and classColor:WrapTextInColorCode(self:GetName()) or name;
    end
    if includeRealm then
        return format("%s-%s", name, self:GetRealm())
    else
        return name
    end
end
function CharacterMixin:GetClass()
    return self.data.classID
end
function CharacterMixin:GetLevel()
    return self.data.level
end
function CharacterMixin:GetRace()
    return self.data.raceID
end
function CharacterMixin:GetSex()
    return self.data.sex
end
function CharacterMixin:GetItemLevel()
    return self.data.itemLevel
end
function CharacterMixin:GetItemLevelEquipped()
    return self.data.itemLevelEquipped
end
function CharacterMixin:GetItemLevelPvP()
    return self.data.itemLevelPvP
end
function CharacterMixin:GetMoney()
    return self.data.money
end
function CharacterMixin:GetCurrentCypherEquipmentLevel()
    return self.data.cypherEquipment and self.data.cypherEquipment.current or 0
end
function CharacterMixin:GetMaxCypherEquipmentLevel()
    return self.data.cypherEquipment and self.data.cypherEquipment.max or 0
end
function CharacterMixin:GetCyphersToNextEquipmentLevel()
    return self.data.cypherEquipment and self.data.cypherEquipment.next or 0
end
if CovenantsSupported then
    function CharacterMixin:GetCovenant()
        return self.data.covenantID
    end
end
function CharacterMixin:IsQuestFlaggedCompleted(questID)
    return self:GetData("questCompleted", questID)
end
function CharacterMixin:GetDataTable(type)
    self.data[type] = self.data[type] or {}
    return self.data[type]
end
function CharacterMixin:SetDataTable(type, tbl)
    self.data[type] = tbl
end
function CharacterMixin:SetData(type, id, value)
    local tbl = self:GetDataTable(type)
    tbl[id] = value
end
function CharacterMixin:GetData(type, id)
    local tbl = self:GetDataTable(type)
    return tbl[id]
end
function CharacterMixin:IsRemote()
    return self.data.remote and true or false
end
function CharacterMixin:RegisterRemoteEvents(target, ...)
    local slug = self.name .. "-" .. self.realm
    for i=1,select('#', ...) do
        local event = select(i, ...)
        target:RegisterEvents("REMOTE:" .. slug .. ":" .. event)
        Internal.RegisterRemoteCharacterEvent(slug, event)
    end
end

local PlayerMixin = CreateFromMixins(CharacterMixin)
function PlayerMixin:Init(data)
    self.name, self.realm = UnitFullName("player")
    self.data = data
end
function PlayerMixin:IsPlayer()
    return true
end
function PlayerMixin:GetClass()
    return (select(3, UnitClass("player")))
end
function PlayerMixin:GetLevel()
    return UnitLevel("player")
end
function PlayerMixin:GetRace()
    return (select(3, UnitRace("player")))
end
function PlayerMixin:GetSex()
    return UnitSex("player")
end
function PlayerMixin:GetItemLevel()
    return (GetAverageItemLevel())
end
function PlayerMixin:GetItemLevelEquipped()
    return (select(2, GetAverageItemLevel()))
end
function PlayerMixin:GetItemLevelPvP()
    return (select(3, GetAverageItemLevel()))
end
if CovenantsSupported then
    function PlayerMixin:GetCovenant()
        return C_Covenants.GetActiveCovenantID()
    end
end
function PlayerMixin:GetMoney()
    return GetMoney()
end
function PlayerMixin:IsQuestFlaggedCompleted(questID)
    return C_QuestLog.IsQuestFlaggedCompleted(questID)
end
function PlayerMixin:GetCurrentCypherEquipmentLevel()
    return C_Garrison.GetCurrentCypherEquipmentLevel();
end
function PlayerMixin:GetMaxCypherEquipmentLevel()
    return C_Garrison.GetMaxCypherEquipmentLevel();
end
function PlayerMixin:GetCyphersToNextEquipmentLevel()
    return C_Garrison.GetCyphersToNextEquipmentLevel();
end

local characters = {}
function Internal.HasCharacter(name, realm)
    local key = name
    if realm ~= nil then
        key = realm .. "-" .. name
    end

    return BtWTodoCharacters[key] ~= nil
end
function Internal.GetCharacter(name, realm)
    local key = name
    if realm ~= nil then
        key = realm .. "-" .. name
    else
        realm, name = strsplit("-", key)
        if realm == nil or name == nil then
            error("Usage Internal.GetCharacter(name, realm): missing name or realm for character")
        end
    end
    local tbl = BtWTodoCharacters[key]
    local result = characters[key]

    -- Data store
    if not tbl then
        print("[" .. ADDON_NAME .. "]: Adding character " .. key)
        tbl = {}
        BtWTodoCharacters[key] = tbl
    end

    -- Mixin store
    if not result then
        local playerName, playerRealm = UnitFullName("player")
        if name == playerName and realm == playerRealm then
            result = CreateAndInitFromMixin(PlayerMixin, tbl)
        else
            result = CreateAndInitFromMixin(CharacterMixin, name, realm, tbl)
        end

        result.key = key

        characters[key] = result
    end

    return result
end
local player
function Internal.GetPlayer()
    if not player then
        local name, realm = UnitFullName("player")
        assert(name and realm, "GetPlayer called to early, UnitFullName missing name or realm" .. (Internal.GetActiveEvent() ~= nil and (", during event " .. Internal.GetActiveEvent()) or ""))
        player = Internal.GetCharacter(name, realm)
    end

    return player
end
function Internal.IterateCharacters()
    return function (tbl, prev)
        local key = next(tbl, prev)
        if key then
            return key, Internal.GetCharacter(key)
        end
    end, BtWTodoCharacters, nil
end
function Internal.FindCharacter(key)
    local name, realm = strsplit("-", key, 2)
    if realm == nil then
        realm = select(2, UnitFullName("player"))
    end

    local character
    if Internal.HasCharacter(name, realm) then
        character = Internal.GetCharacter(name, realm) -- Case sensitive
    else
        name, realm = string.lower(name), string.lower(realm)
        for _,possible in Internal.IterateCharacters() do
            if possible.name:lower() == name and possible.realm:lower() == realm then
                character = possible
                break
            end
        end
    end

    return character
end

-- Save general character data
Internal.RegisterEvent("PLAYER_LOGOUT", function ()
    local player = Internal.GetPlayer()
	player.data.classID = player:GetClass()
	player.data.level = player:GetLevel()
	player.data.raceID = player:GetRace()
	player.data.sex = player:GetSex()
end)
Internal.RegisterEvent("PLAYER_ENTERING_WORLD", function ()
	player.data.itemLevel, player.data.itemLevelEquipped, player.data.itemLevelPvP = GetAverageItemLevel()
    if CovenantsSupported then
        player.data.covenantID = player:GetCovenant()
    end
end)
Internal.RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE", function ()
	player.data.itemLevel, player.data.itemLevelEquipped, player.data.itemLevelPvP = GetAverageItemLevel()
end)
if CovenantsSupported then
    Internal.RegisterEvent("COVENANT_CHOSEN", function ()
        player.data.covenantID = player:GetCovenant()
    end)
end
Internal.RegisterEvent("PLAYER_MONEY", function ()
    player.data.money = player:GetMoney()
end)
local function UpdateCypherEquipment()
    local current = player:GetCurrentCypherEquipmentLevel()
    local max = player:GetMaxCypherEquipmentLevel()
    local next = player:GetCyphersToNextEquipmentLevel()
    if player.data.cypherEquipment and next == 740 and current == 1 then
        return
    end
    player.data.cypherEquipment = {
        current = current,
        max = max,
        next = next,
    }
end
Internal.RegisterEvent("PLAYER_ENTERING_WORLD", function ()
    C_Timer.After(1, function ()
        External.TriggerEvent("CYPHER_EQUIPMENT_UPDATE")
    end)
end)
Internal.RegisterEvent("CYPHER_EQUIPMENT_UPDATE", UpdateCypherEquipment)
Internal.RegisterEvent("GARRISON_TALENT_COMPLETE", UpdateCypherEquipment)
Internal.RegisterEvent("GARRISON_TALENT_UPDATE", UpdateCypherEquipment)
