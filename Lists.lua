--[[

]]

local ADDON_NAME, Internal = ...
local L = Internal.L
local External = _G[ADDON_NAME]

local registeredLists = {}
function External.RegisterList(list)
    if type(list) ~= "table" then
        error(ADDON_NAME .. ".RegisterList(list): list must be a table")
    elseif list.id == nil then
        error(ADDON_NAME .. ".RegisterList(list): list.id is required")
    elseif type(list.id) ~= "string" then
        error(ADDON_NAME .. ".RegisterList(list): list.id must be string")
    elseif registeredLists[list.id] then
        error(ADDON_NAME .. ".RegisterList(list): " .. list.id .. " is already registered")
    elseif list.name == nil then
        error(ADDON_NAME .. ".RegisterList(list): list.name is required")
    elseif list.todos == nil then
        error(ADDON_NAME .. ".RegisterList(list): list.todos is required")
    end

    registeredLists[list.id] = list
end
function External.RegisterLists(tbl)
    for _,list in ipairs(tbl) do
        External.RegisterList(list)
    end
end
function Internal.GetList(id)
    return BtWTodoLists[id] or registeredLists[id]
end
function Internal.IterateLists()
    local tbl = {}
    if BtWTodoLists then
        for id,list in pairs(BtWTodoLists) do
            tbl[id] = list
        end
    end
    for id,list in pairs(registeredLists) do
        if not tbl[id] then
            tbl[id] = list
        end
    end
    return next, tbl, nil
end
function Internal.UpdateList(list)
    if type(list) ~= "table" then
        error(ADDON_NAME .. ".UpdateList(list): list must be a table")
    elseif list.id == nil then
        error(ADDON_NAME .. ".UpdateList(list): list.id is required")
    elseif list.name == nil then
        error(ADDON_NAME .. ".UpdateList(list): list.name is required")
    elseif list.todos == nil then
        error(ADDON_NAME .. ".UpdateList(list): list.todos is required")
    end

    local saved, registered = BtWTodoLists[list.id], registeredLists[list.id]
    if registered and saved then
        if not tCompare(registered, list, 3) then
            BtWTodoLists[list.id] = list
            return tCompare(saved, list, 3)
        else
            BtWTodoLists[list.id] = nil
            return true
        end
    elseif registered and not saved then
        if not tCompare(registered, list, 3) then
            BtWTodoLists[list.id] = list
            return true
        end
    elseif not registered and saved then
        if not tCompare(saved, list, 3) then
            BtWTodoLists[list.id] = list
            return true
        end
    else
        BtWTodoLists[list.id] = list
        return true
    end

    return false
end

local function ADDON_LOADED(_, addon)
    if addon == ADDON_NAME then
        BtWTodoLists = BtWTodoLists or {}

        Internal.UnregisterEvent("ADDON_LOADED", ADDON_LOADED)
    end
end
Internal.RegisterEvent("ADDON_LOADED", ADDON_LOADED, -10)

External.RegisterLists({
    {
        id = "btwtodo:default",
        name = L["Default"],
        todos = {
            {
                id = "btwtodo:itemlevel",
                category = "btwtodo:character",
            },
            {
                id = "btwtodo:renown",
                category = "btwtodo:character",
            },
            {
                id = "btwtodo:91campaign",
                category = "btwtodo:character",
            },
            {
                id = "btwtodo:callings",
                category = "btwtodo:daily",
            },
            {
                id = "btwtodo:korthiadailies",
                category = "btwtodo:daily",
            },
            {
                id = "btwtodo:mawsworncache",
                category = "btwtodo:daily",
                hidden = true,
            },
            {
                id = "btwtodo:invasivemawshroom",
                category = "btwtodo:daily",
                hidden = true,
            },
            {
                id = "btwtodo:nestofunusualmaterials",
                category = "btwtodo:daily",
                hidden = true,
            },
            {
                id = "btwtodo:reliccache",
                category = "btwtodo:daily",
                hidden = true,
            },
            {
                id = "btwtodo:spectralboundchest",
                category = "btwtodo:daily",
                hidden = true,
            },
            {
                id = "btwtodo:riftboundcache",
                category = "btwtodo:daily",
                hidden = true,
            },
            {
                id = "btwtodo:renownquests",
                category = "btwtodo:weekly",
            },
            {
                id = "btwtodo:raidvault",
                category = "btwtodo:weekly",
            },
            {
                id = "btwtodo:dungeonvault",
                category = "btwtodo:weekly",
            },
            {
                id = "btwtodo:keystone",
                category = "btwtodo:weekly",
            },
            {
                id = "btwtodo:mawworldboss",
                category = "btwtodo:weekly",
            },
            {
                id = "btwtodo:torghast",
                category = "btwtodo:weekly",
            },
            {
                id = "btwtodo:mawassault",
                category = "btwtodo:weekly",
            },
            {
                id = "btwtodo:tormentors",
                category = "btwtodo:weekly",
            },
            {
                id = "btwtodo:mawsoulsquest",
                category = "btwtodo:weekly",
            },
            {
                id = "btwtodo:soulcinders",
                category = "btwtodo:currency",
            },
            {
                id = "btwtodo:valor",
                category = "btwtodo:currency",
            },
            {
                id = "btwtodo:towerknowledge",
                category = "btwtodo:currency",
            },
            {
                id = "btwtodo:deathsadvance",
                category = "btwtodo:reputation",
            },
            {
                id = "btwtodo:thearchivistscodex",
                category = "btwtodo:reputation",
            },
        },
    },
    {
        id = "btwtodo:91",
        name = L["Sanctum of Domination"],
        todos = {
            {
                id = "btwtodo:itemlevel",
                category = "btwtodo:character",
            },
            {
                id = "btwtodo:renown",
                category = "btwtodo:character",
            },
            {
                id = "btwtodo:91campaign",
                category = "btwtodo:character",
            },
            {
                id = "btwtodo:callings",
                category = "btwtodo:daily",
            },
            {
                id = "btwtodo:korthiadailies",
                category = "btwtodo:daily",
            },
            {
                id = "btwtodo:mawsworncache",
                category = "btwtodo:daily",
            },
            {
                id = "btwtodo:invasivemawshroom",
                category = "btwtodo:daily",
            },
            {
                id = "btwtodo:nestofunusualmaterials",
                category = "btwtodo:daily",
            },
            {
                id = "btwtodo:reliccache",
                category = "btwtodo:daily",
            },
            {
                id = "btwtodo:spectralboundchest",
                category = "btwtodo:daily",
            },
            {
                id = "btwtodo:riftboundcache",
                category = "btwtodo:daily",
            },
            {
                id = "btwtodo:renownquests",
                category = "btwtodo:weekly",
            },
            {
                id = "btwtodo:raidvault",
                category = "btwtodo:weekly",
            },
            {
                id = "btwtodo:dungeonvault",
                category = "btwtodo:weekly",
            },
            {
                id = "btwtodo:keystone",
                category = "btwtodo:weekly",
            },
            {
                id = "btwtodo:mawworldboss",
                category = "btwtodo:weekly",
            },
            {
                id = "btwtodo:torghast",
                category = "btwtodo:weekly",
            },
            {
                id = "btwtodo:mawassault",
                category = "btwtodo:weekly",
            },
            {
                id = "btwtodo:tormentors",
                category = "btwtodo:weekly",
            },
            {
                id = "btwtodo:mawsoulsquest",
                category = "btwtodo:weekly",
            },
            {
                id = "btwtodo:soulcinders",
                category = "btwtodo:currency",
            },
            {
                id = "btwtodo:valor",
                category = "btwtodo:currency",
            },
            {
                id = "btwtodo:towerknowledge",
                category = "btwtodo:currency",
            },
            {
                id = "btwtodo:deathsadvance",
                category = "btwtodo:reputation",
            },
            {
                id = "btwtodo:thearchivistscodex",
                category = "btwtodo:reputation",
            },
        },
    }
})