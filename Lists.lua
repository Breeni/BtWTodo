--[[

]]

local ADDON_NAME, Internal = ...
local L = Internal.L
local External = _G[ADDON_NAME]

local registeredLists = {}

local function GetTodoIndex(list, id)
    for index,todo in ipairs(list.todos) do
        if todo.id == id then
            return index
        end
    end
end
-- Add new items from the registered version of the list to the saved version, also update the version numbers if
-- they are missing/incorrect so saving lists will flush registered lists correctly
local function UpdateListVersion(id)
    if not BtWTodoLists then -- Called before ADDON_LOADED
        return
    end
    if registeredLists[id] and BtWTodoLists[id] then
        local registered, list = registeredLists[id], BtWTodoLists[id]
        local version = list.version or 0 -- Currently active version
        local addedCount, newVersion = 0, nil

        if (registered.version or 0) > version then
            for index,todo in ipairs(registered.todos) do
                local current = GetTodoIndex(list, todo.id)
                if current then -- Item is already in saved list
                    list.todos[current].version = todo.version -- Make sure the version number is correct
                elseif type(todo.version) == "number" and todo.version > version then
                    local inserted = false
                    if index ~= 1 then
                        -- Find the offset for the item before the one we will insert, going back until we find one
                        for i=index-1,1,-1 do
                            local offset = GetTodoIndex(list, registered.todos[i].id)
                            if offset then
                                local result = CopyTable(todo)
                                -- If the previous item has had its category changed then change the new items category too
                                if registered.todos[i].category == todo.category and list.todos[offset].category ~= registered.todos[i].category then
                                    result.category = list.todos[i].category
                                end
                                table.insert(list.todos, offset + 1, result)
                                inserted = true
                                break
                            end
                        end
                    end
                    if not inserted then -- Either it's the first item or we couldnt find any of its previous items in the list
                        table.insert(list.todos, index, CopyTable(todo))
                    end

                    addedCount = addedCount + 1
                    newVersion = math.max(todo.version, newVersion or 0)
                end
            end

            if newVersion then
                for index,todo in ipairs(list.todos) do
                    todo.orderIndex = index
                end

                print("[" .. ADDON_NAME .. "]: " .. format(L["Updated list %s to version %d, added %d items"], list.name, newVersion, addedCount))
                list.version = newVersion
            else -- Registered version is somehow newer than the saved version but no new items needed adding
                list.version = registered.version
            end
        end
    end
end

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

    UpdateListVersion(list.id)
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

        for id in pairs(BtWTodoLists) do
            UpdateListVersion(id)
        end

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
                id = "btwtodo:gold",
                category = "btwtodo:character",
                version = 2,
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
                id = "btwtodo:deathboundshard",
                category = "btwtodo:weekly",
                hidden = true,
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
        name = L["Chains of Domination"],
        version = 1,
        todos = {
            {
                id = "btwtodo:itemlevel",
                category = "btwtodo:character",
            },
            {
                id = "btwtodo:gold",
                category = "btwtodo:character",
                version = 1,
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
                id = "btwtodo:deathboundshard",
                category = "btwtodo:weekly",
                hidden = true,
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