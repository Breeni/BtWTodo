local ADDON_NAME, Internal = ...
local External = _G[ADDON_NAME]
local L = Internal.L

local DEFAULT_COMPLETED_FUNCTION = "return self:IsFlaggedCompleted()"
local DEFAULT_TEXT_FUNCTION = [[return self:IsCompleted() and Images.COMPLETE or "-"]]
local DEFAULT_CLICK_FUNCTION = [[self:SetFlaggedCompleted(not self:IsFlaggedCompleted())]]

-- DST doesnt effect daily/weekly/halfweekly resets so these should always be accurate
local SECONDS_PER_HOUR = 60 * 60
local SECONDS_PER_WEEK = 60 * 60 * 24 * 7
local SECONDS_PER_HALF_WEEK = 60 * 60 * 24 * 3.5

local function GetNextWeeklyResetTimestamp()
    return math.floor((GetServerTime() + C_DateAndTime.GetSecondsUntilWeeklyReset()) / SECONDS_PER_HOUR + 0.5) * SECONDS_PER_HOUR
end
local function GetNextDailyResetTimestamp()
    return math.floor((GetServerTime() + C_DateAndTime.GetSecondsUntilDailyReset()) / SECONDS_PER_HOUR + 0.5) * SECONDS_PER_HOUR
end
Internal.GetNextWeeklyResetTimestamp = GetNextWeeklyResetTimestamp
Internal.GetNextDailyResetTimestamp = GetNextDailyResetTimestamp

local function ADDON_LOADED(event, addon)
    if addon == ADDON_NAME then
        BtWTodoData = BtWTodoData or {}

        BtWTodoCategories = BtWTodoCategories or {}

        BtWTodoCharacters = BtWTodoCharacters or {}

        BtWTodoCache = BtWTodoCache or {}
        BtWTodoCache.quests = BtWTodoCache.quests or {}
        BtWTodoCache.currencies = BtWTodoCache.currencies or {}
        BtWTodoCache.factions = BtWTodoCache.factions or {}
        BtWTodoCache.callings = BtWTodoCache.callings or {[1] = {}, [2] = {}, [3] = {}, [4] = {}}
        BtWTodoCache.resets = BtWTodoCache.resets or {}

        Internal.UnregisterEvent("ADDON_LOADED", ADDON_LOADED)
    end
end
Internal.RegisterEvent("ADDON_LOADED", ADDON_LOADED, -10)


local function HandleResets()
    local season = C_MythicPlus.GetCurrentSeason()
    local nextDailyReset = GetNextDailyResetTimestamp()
    local nextWeeklyReset = GetNextWeeklyResetTimestamp()
    local nextHalfWeeklyReset = nextWeeklyReset - SECONDS_PER_HALF_WEEK

    if season == -1 then -- During login it isnt available
        C_Timer.After(5, HandleResets)
    elseif season ~= BtWTodoCache.resets.season then
        -- print("SEASON_RESET", season, BtWTodoCache.resets.season)
        External.TriggerEvent("SEASON_RESET")
        BtWTodoCache.resets.season = season
    end
    -- We do +10 for each of these as the reset times can fluctuate, most I've seen
    -- is 1 second more but no harm in doing 10 since it should jump by 1 week/3.5 days/1 day
    if nextWeeklyReset > (BtWTodoCache.resets.weekly or 0) + 10 then
        -- print("WEEKLY_RESET", nextWeeklyReset, (BtWTodoCache.resets.weekly or 0))

        External.TriggerEvent("WEEKLY_RESET")
        External.TriggerEvent("HALF_WEEKLY_RESET", true)
        External.TriggerEvent("DAILY_RESET", true)

        BtWTodoCache.resets.weekly = nextWeeklyReset
        BtWTodoCache.resets.halfweekly = nextHalfWeeklyReset
        BtWTodoCache.resets.daily = nextDailyReset
    elseif nextHalfWeeklyReset > (BtWTodoCache.resets.halfweekly or 0) + 10 then
        -- print("HALF_WEEKLY_RESET", nextHalfWeeklyReset, (BtWTodoCache.resets.halfweekly or 0))

        External.TriggerEvent("HALF_WEEKLY_RESET", false)
        BtWTodoCache.resets.halfweekly = nextHalfWeeklyReset
    elseif nextDailyReset > (BtWTodoCache.resets.daily or 0) + 10 then
        -- print("DAILY_RESET", nextDailyReset, (BtWTodoCache.resets.daily or 0))

        External.TriggerEvent("DAILY_RESET", false)
        BtWTodoCache.resets.daily = nextDailyReset
    end
end
Internal.RegisterEvent("PLAYER_LOGIN", HandleResets)
Internal.RegisterEvent("CHAT_MSG_SYSTEM", function (event, ...)
    if ... == DAILY_QUESTS_RESET then
        -- This should happen as the C_DateAndTime.GetSecondsUntilDailyReset() timer rolls over
        -- but may happen slightly early and since its annoying to test that we are just gonna
        -- deal with that possibility
        local dailyReset = C_DateAndTime.GetSecondsUntilDailyReset()
        if dailyReset > 10 then
            dailyReset = 1
        end
        C_Timer.After(dailyReset, HandleResets)
    end
end)

local function HalfWeeklyResetTimer(runReset)
    local timer = C_DateAndTime.GetSecondsUntilWeeklyReset() - SECONDS_PER_HALF_WEEK
    if timer >= 0 then
        C_Timer.After(timer, function () HalfWeeklyResetTimer(true) end)
    end
    if runReset then
        HandleResets()
    end
end
HalfWeeklyResetTimer()

local registeredTodos = {}
function External.RegisterTodo(todo)
    if type(todo) ~= "table" then
        error("External.RegisterTodo(todo): todo must be a table")
    elseif todo.id == nil then
        error("External.RegisterTodo(todo): todo.id is required")
    elseif type(todo.id) ~= "string" then
        error("External.RegisterTodo(todo): todo.id must be string")
    elseif registeredTodos[todo.id] then
        error("External.RegisterTodo(todo): " .. todo.id .. " is already registered")
    elseif todo.name == nil then
        error("External.RegisterTodo(todo): todo.name is required")
    end

    todo.registered = true
    registeredTodos[todo.id] = todo
end
function External.RegisterTodos(todos)
    for _,todo in ipairs(todos) do
        External.RegisterTodo(todo)
    end
end
function Internal.GetTodo(id)
    return BtWTodoData[id] or registeredTodos[id]
end
-- Used for reverting todos to their registered version
function Internal.GetRegisteredTodo(id)
    return registeredTodos[id]
end
function Internal.CheckTodoForUpdate(id, current)
    local current, new = current, current
    if not current and BtWTodoData[id] then
        local data = BtWTodoData[id]
        current, new = data.version or 0, data.version or 0
    end
    if registeredTodos[id] then
        local data = registeredTodos[id]
        current, new = current or data.version or 0, data.version or 0
    end
    return current ~= new, current, new
end
function Internal.GetTodoChangeLog(id, start)
    if not registeredTodos[id] then
        return
    end
    local result = {}
    local source = registeredTodos[id].changeLog
    if source then
        for i=start or 1,#source do
            local item = source[i]
            if type(item) == "table" then
                for _,line in ipairs(item) do
                    result[#result+1] = line
                end
            else
                result[#result+1] = item
            end
        end
    end

    return result
end

local registeredCategories = {}
function External.RegisterCategory(category)
    if type(category) ~= "table" then
        error("External.RegisterCategory(category): category must be a table")
    elseif category.id == nil then
        error("External.RegisterCategory(category): category.id is required")
    elseif type(category.id) ~= "string" then
        error("External.RegisterCategory(category): category.id must be string")
    elseif registeredCategories[category.id] then
        error("External.RegisterCategory(category): " .. category.id .. " is already registered")
    elseif category.name == nil then
        error("External.RegisterCategory(category): category.name is required")
    elseif category.color == nil then
        error("External.RegisterCategory(category): category.color is required")
    end

    registeredCategories[category.id] = category
end
function External.RegisterCategories(items)
    for _,item in ipairs(items) do
        External.RegisterCategory(item)
    end
end
function External.GetCategory(id)
    local saved, registered = BtWTodoCategories[id], registeredCategories[id]
    if type(saved) ~= "table" and type(registered) ~= "table" then
        error("External.GetCategory(category): unknown category " .. tostring(id))
    end

    -- Clone the color, the config ui edits this color return from here, if we return the color
    -- stored without cloning then when saving the color it'll always be considered the same
    -- as the original registered color and not be saved
    local color
    if saved and saved.color then
        color = CreateColor(unpack(saved.color))
    else
        color = CreateColor(registered.color:GetRGB())
    end

    return { id = id, name = saved and saved.name or registered.name, color = color }
end
function External.UpdateCategory(id, name, color)
    local category = BtWTodoCategories[id]
    if not category then
        category = {}
        BtWTodoCategories[id] = category
    end

    category.name = name or category.name
    category.color = color and {color:GetRGBA()} or category.color

    local registered = registeredCategories[id]
    if registered then
        if registered.name == category.name then
            category.name = nil
        end
        if registered.color.r == category.color[1] and registered.color.g == category.color[2] and registered.color.b == category.color[3] then
            category.color = nil
        end
        if next(category) == nil then
            BtWTodoCategories[id] = nil
        end
    end
end
function External.ResetCategory(id)
    BtWTodoCategories[id] = nil
end
function Internal.IterateCategories()
    local tbl = {}
    for id in pairs(BtWTodoCategories) do
        tbl[id] = External.GetCategory(id)
    end
    for id in pairs(registeredCategories) do
        if not tbl[id] then
            tbl[id] = External.GetCategory(id)
        end
    end
    return next, tbl, nil
end
function External.GetCategoryByName(name)
    for id,category in pairs(registeredCategories) do
        if category.name == name then
            return id
        end
    end
end

function External.GetTodoName(id)
    local tbl
    if BtWTodoData[id] then
        tbl = BtWTodoData[id]
    else
        tbl = registeredTodos[id]
    end
    if tbl == nil then
        error("External.GetTodoName(id): unknown todo " .. tostring(id))
    end

    return tbl.name
end
function Internal.IterateTodos()
    local tbl = {}
    for id,todo in pairs(BtWTodoData) do
        tbl[id] = todo
    end
    for id,todo in pairs(registeredTodos) do
        if not tbl[id] then
            tbl[id] = todo
        end
    end
    return next, tbl, nil
end
function External.CreateTodoByID(id)
    local tbl
    if BtWTodoData[id] then
        tbl = BtWTodoData[id]
    else
        tbl = registeredTodos[id]
    end
    if tbl == nil then
        error("External.CreateTodoByID(id): unknown todo " .. tostring(id))
    end
    
    local id, name, states, completed, text, click, tooltip = tbl.id, tbl.name, tbl.states, tbl.completed or DEFAULT_COMPLETED_FUNCTION, tbl.text or DEFAULT_TEXT_FUNCTION, tbl.click, tbl.tooltip
    return Internal.CreateStateDriver(id, name, states, completed, text, click, tooltip)
end
function Internal.CompareTodos(a, b) -- Compare everything except id, and version data
    if a.name ~= b.name then
        return false
    end
    if #a.states ~= #b.states then
        return false
    end
    for i=1,#a.states do
        local aState, bState = a.states[i], b.states[i]
        if aState.type ~= bState.type or aState.id ~= bState.id or type(aState.values) ~= type(bState.values) or (type(aState.values) == "table" and not tCompare(a.values, b.values, 3)) then
            return false
        end
    end
    if a.completed ~= b.completed or a.text ~= b.text or a.tooltip ~= b.tooltip or a.click ~= b.click then
        return false
    end
    return true
end
function Internal.SaveTodo(tbl)
    local id = tbl.id
    if registeredTodos[id] and Internal.CompareTodos(tbl, registeredTodos[id]) then
        BtWTodoData[id] = nil
    else
        BtWTodoData[id] = tbl
    end
end
