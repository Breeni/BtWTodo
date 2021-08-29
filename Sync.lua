local ADDON_NAME, Internal = ...
local External = _G[ADDON_NAME]
local L = Internal.L

local PREFIX = ADDON_NAME

C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)

-- First character of sent messages decribe what the message is about
local ControlCharacters = {
    RequestAccess = '\1', -- Request access to character data
    RequestAccessResponse = '\2', -- Response for access request

    AuthorityNotification = '\3', -- Notify someone that you are an authority for a character

    RegisterCharacterEventsMultiple = '\4', -- Register for character data events, more parts to follow
    RegisterCharacterEventsLast = '\5', -- Register for character data events, last or only part

    CharacterDataMultiple = '\6', -- Character data, more parts to follow
    CharacterDataLast = '\7', -- Character data, last or only part

    Ping = '\8', -- Check if a player is still online
    Pong = '\9', -- Respond to ping

    RequestSharedData = '\10',
    SendSharedData = '\11',
}

local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")

function Internal.RequestAccessToCharacter(name, realm)
    ChatThrottleLib:SendAddonMessage("NORMAL", PREFIX, ControlCharacters.RequestAccess, "WHISPER", name .. "-" .. realm);
end
local MAX_LENGTH = 253
function Internal.RegisterRemoteCharacterEvents(slug, ...)
    --@TODO get a character to request this data from instead of always from the target

    local compressed = LibDeflate:CompressDeflate(slug .. " " .. table.concat({...}, " "))
    local encoded = LibDeflate:EncodeForWoWAddonChannel(compressed)

    for i=1,#encoded,MAX_LENGTH do
        local data = strsub(encoded, i, math.min(i + MAX_LENGTH,#encoded))
        if i + MAX_LENGTH >= #encoded then
            ChatThrottleLib:SendAddonMessage("NORMAL", PREFIX, ControlCharacters.RegisterCharacterEventsLast .. data, "WHISPER", slug);
        else
            ChatThrottleLib:SendAddonMessage("NORMAL", PREFIX, ControlCharacters.RegisterCharacterEventsMultiple .. data, "WHISPER", slug);
        end
    end
end

local eventsToRegister = {}
local registerFrame = CreateFrame("Frame")
registerFrame:SetScript("OnUpdate", function (self)
    local tbl = {}
    for character,events in pairs(eventsToRegister) do
        wipe(tbl)
        for event in pairs(events) do
            tbl[#tbl+1] = event
        end

        Internal.RegisterRemoteCharacterEvents(character, unpack(tbl))
    end
    wipe(eventsToRegister)
    self:Hide()
end)
function Internal.RegisterRemoteCharacterEvent(slug, event)
    local tbl = eventsToRegister[slug]
    if not tbl then
        tbl = {}
        eventsToRegister[slug] = tbl
    end

    tbl[event] = true
    registerFrame:Show()
end
do
    -- local 
    function Internal.SendRemoteCharacterDataTable(slug, key, ...)

    end
end

-- This is here because I thought a ping/pong might be useful
local PingTimers = {}
function Internal.PingCharacter(name, realm)
    local slug = realm and (name .. "-" .. realm) or name

    if PingTimers[slug] ~= false then
        PingTimers[slug] = false
        ChatThrottleLib:SendAddonMessage("NORMAL", PREFIX, ControlCharacters.Ping, "WHISPER", slug);

        -- If we dont get a response in 10 minutes wipe the value and allow for more pings
        C_Timer.After(10, function ()
            if PingTimers[slug] == false then
                PingTimers[slug] = nil
            end
        end)
    end
end

local function ADDON_LOADED(event, name)
    if name == ADDON_NAME then
        if BtWTodoAuthorization == nil then
            BtWTodoAuthorization = {} -- Characters that are authorized to view data
        end

        -- for character in pairs(BtWTodoAuthorization) do
        --     Internal.PingCharacter(character)
        -- end

        Internal.UnregisterEvent("ADDON_LOADED", ADDON_LOADED)
    end
end
Internal.RegisterEvent("ADDON_LOADED", ADDON_LOADED)

Internal.RegisterEvent("PING", function (event, character)
    print(character)
end)

-- Used to store multipart messages
local CharacterEventsStore = {}
local CharacterDataStore = {}
Internal.RegisterEvent("CHAT_MSG_ADDON", function (event, prefix, text, channel, sender, target, zoneChannelID, localID, name, instanceID)
    if prefix ~= PREFIX then
        return
    end
    if channel ~= "WHISPER" then -- Currently only handle whispers
        return
    end

    local control = strsub(text, 1, 1)

    if control == ControlCharacters.RequestAccess then
        External.TriggerEvent("REQUEST_ACCESS", sender)
    elseif control == ControlCharacters.RequestAccessResponse then
        External.TriggerEvent("REQUEST_ACCESS_RESPONSE", strsub(text, 2, 2) == 1)
    elseif control == ControlCharacters.AuthorityNotification then
        External.TriggerEvent("AUTHORITY_NOTIFICATION", strsub(text, 2), sender)
    elseif control == ControlCharacters.RegisterCharacterEventsMultiple or control == ControlCharacters.RegisterCharacterEventsLast then
        local tbl = CharacterEventsStore[sender]
        if not tbl then
            tbl = {}
            CharacterEventsStore[sender] = tbl
        end

        tbl[#tbl+1] = strsub(text, 2)

        if control == ControlCharacters.RegisterCharacterEventsLast then
            local compressed = LibDeflate:DecodeForWoWAddonChannel(table.concat(tbl, ""))
            local data = LibDeflate:DecompressDeflate(compressed)

            -- print(sender, strsplit(" ", data))
            External.TriggerEvent("REGISTER_CHARACTER_EVENT", sender, strsplit(" ", data))

            CharacterEventsStore[sender] = nil
        end
    elseif control == ControlCharacters.OnCharacterEvent then
        local compressed = LibDeflate:DecodeForWoWAddonChannel(strsub(text, 2))
        local data = LibDeflate:DecompressDeflate(compressed)

        External.TriggerEvent("ON_CHARACTER_EVENT", sender, strsplit(" ", data))
    elseif control == ControlCharacters.CharacterDataMultiple or control == ControlCharacters.CharacterDataLast then
        local tbl = CharacterDataStore[sender]
        if not tbl then
            tbl = {}
            CharacterDataStore[sender] = tbl
        end

        tbl[#tbl+1] = strsub(text, 2)

        if control == ControlCharacters.CharacterDataLast then
            local compressed = LibDeflate:DecodeForWoWAddonChannel(table.concat(tbl, ""))
            local data = LibDeflate:DecompressDeflate(compressed)
            External.TriggerEvent("CHARACTER_DATA", sender, LibSerialize:Deserialize(data))

            CharacterDataStore[sender] = nil
        end
    elseif control == ControlCharacters.Ping or control == ControlCharacters.Pong then
        PingTimers[sender] = GetTime()

        if control == ControlCharacters.Ping then
            ChatThrottleLib:SendAddonMessage("NORMAL", PREFIX, ControlCharacters.Pong, "WHISPER", sender);
        end

        External.TriggerEvent("PING", sender)
    elseif control == ControlCharacters.RequestSharedData then
        local id = strsub(text, 2)
        Internal.SendSharedData(id)
    elseif control == ControlCharacters.SendSharedData then
        local encoded = strsub(text, 2)
        local compressed = LibDeflate:DecodeForWoWAddonChannel(encoded)
        local full = LibDeflate:DecompressDeflate(compressed)
        local id, serialized = strsplit(" ", full, 2)
        local data = LibSerialize:Deserialize(serialized)

        BtWTodoCache[id] = data

        Internal.TriggerEvent("SHARED_DATA:" .. id, data)
    end
end)

-- Shared data is anything that can be shared to other players, like which are the available korthia dailies, which quests for the current assault
local lastRequested = {}
function Internal.GetSharedData(id)
    if type(id) ~= "string" or id:match("[^%w-_]") then
        error(L["Shared data id must be a string containing only word characters, dashes, and underscores"])
    end

    local data = BtWTodoCache[id]

    if not data and (lastRequested[id] == nil or lastRequested[id] < GetTime() - 60) then
        if IsInGuild() then
            ChatThrottleLib:SendAddonMessage("NORMAL", PREFIX, ControlCharacters.RequestSharedData .. id, "GUILD")
        end
        if IsInGroup(LE_PARTY_CATEGORY_HOME) then
            ChatThrottleLib:SendAddonMessage("NORMAL", PREFIX, ControlCharacters.RequestSharedData .. id, "RAID")
        end
        if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
            ChatThrottleLib:SendAddonMessage("NORMAL", PREFIX, ControlCharacters.RequestSharedData .. id, "INSTANCE_CHAT")
        end
    end

    return data
end
function Internal.SaveSharedData(id, data)
    local send = type(BtWTodoCache[id]) ~= type(data) or not tCompare(data, BtWTodoCache[id], 10)

    BtWTodoCache[id] = data

    if send then
        Internal.SendSharedData(id)
    end
end
function Internal.WipeSharedData(id)
    Internal.SaveSharedData(id, nil)
end
function Internal.SendSharedData(id)
    local data = BtWTodoCache[id]

    if data == nil then -- Dont send wiping data, everyone else will probably be wiping too
        return
    end

    local serialized = LibSerialize:Serialize(data)
    local compressed = LibDeflate:CompressDeflate(id .. " " .. serialized)
    local encoded = ControlCharacters.SendSharedData .. LibDeflate:EncodeForWoWAddonChannel(compressed)

    if #encoded > 254 then -- We dont chunk shared data, just keep it smaller
        return
    end

    if IsInGuild() then
        ChatThrottleLib:SendAddonMessage("NORMAL", PREFIX, encoded, "GUILD")
    end
    if IsInGroup(LE_PARTY_CATEGORY_HOME) then
        ChatThrottleLib:SendAddonMessage("NORMAL", PREFIX, encoded, "RAID")
    end
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        ChatThrottleLib:SendAddonMessage("NORMAL", PREFIX, encoded, "INSTANCE_CHAT")
    end
end
Internal.RegisterEvent("GROUP_JOINED", function (event)
    
end)
