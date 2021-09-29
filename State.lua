local ADDON_NAME, Internal = ...
local External = _G[ADDON_NAME]

local function tMap(tbl, func)
	local result = {}
	for k,v in pairs(tbl) do
		result[k] = func(k, v, tbl)
	end
	return result
end

-- Base Mixin for State
local StateMixin = {}
function StateMixin:Init(id)
    self.id = id;
end
function StateMixin:GetID()
	return self.id;
end
function StateMixin:GetDisplayName(supportsCallback)
    
end
function StateMixin:GetUniqueKey()
	-- Return a unique key for the states table so advanced scripts can access by key instead of by index
    -- built in states use the [StateProvider id]:[State id] for example quest:63819
end
function StateMixin:SetCharacter(character)
    self.character = character;
end
function StateMixin:GetCharacter()
    if self.character then
	    return self.character
    elseif self.driver then
	    return self.driver:GetCharacter()
    else
	    return Internal.GetPlayer()
    end
end
function StateMixin:SetDriver(driver)
    self.driver = driver
end
-- Override this to register events to trigger updating completed and text
-- target might be a state driver or a ui element
-- isPlayer == true: Register events for updating the character that is online
-- isPlayer == true: Register events for updating for characters not online
-- isPlayer == nil: Register events for updating anyone
function StateMixin:RegisterEventsFor(target, isPlayer)
    -- target:RegisterEvents("PLAYER_ENTERING_WORLD", "MY_CUSTOM_EVENT")
end
External.StateMixin = StateMixin

-- Base Mixin for State Providers
local StateProviderMixin = {}
function StateProviderMixin:Init(id, name, mixin)
    self.id = id
    self.name = name
    self.mixin = mixin
end
function StateProviderMixin:GetID()
	return self.id
end
function StateProviderMixin:GetName()
	return self.name
end
function StateProviderMixin:RequiresID()
	return true
end
-- Returns the title and optional description used for the config panel when adding a new state
function StateProviderMixin:GetAddTitle()
	return string.format(BTWTODO_ADD_ITEM, self:GetName())
end
function StateProviderMixin:Acquire(...)
	return CreateFromMixinAndInit(self.mixin, ...)
end
-- Returns data describing the possible basic functions
function StateProviderMixin:GetFunctions()
	return {}
end
-- Returns the default functions for completed and text functions used for basic options
function StateProviderMixin:GetDefaults()
	return nil, nil
end
function StateProviderMixin:ParseInput(input)
    -- return true plus one or more values that can be passed to Aquire based on input
end
function StateProviderMixin:FillAutoComplete(tbl, text, offset, length)
	-- Add items to tbl that are filted by text for auto completing adding an item, values can be passed to ParseInput
end
External.StateProviderMixin = StateProviderMixin
function External.CreateBasicStateProvider(id, name, mixin)
    assert(type(id) == "string", "Usage: CreateBasicStateProvider(id, name, mixin): expected id to be string")
    assert(type(name) == "string", "Usage: CreateBasicStateProvider(id, name, mixin): expected name to be string")
    assert(type(mixin) == "table", "Usage: CreateBasicStateProvider(id, name, mixin): expected mixin to be table")

    return CreateFromMixinAndInit(StateProviderMixin, id, name, mixin)
end

local stateProviders = {}
function External.RegisterStateProvider(provider)
    stateProviders[provider:GetID()] = provider
    Internal.TriggerEvent("REGISTER_STATE_PROVIDER")
end
local internalStateProviders = {}
function Internal.RegisterStateProvider(provider)
    internalStateProviders[provider:GetID()] = provider
end
function Internal.GetStateProvider(provider)
    assert(type(provider) == "string", "Usage: GetStateProvider(provider): expected provider to be string")
    return internalStateProviders[provider] or stateProviders[provider]
end
function Internal.CreateState(provider, id, ...)
    assert(type(provider) == "string", "Usage: CreateState(provider, id, ...): expected provider to be string")

    local state
    if internalStateProviders[provider] then
        state = internalStateProviders[provider]:Acquire(id, ...)
    elseif stateProviders[provider] then
        state = stateProviders[provider]:Acquire(id, ...)
    else
        error("Usage: CreateState(provider, id, ...): provider " .. tostring(provider) .. " has not been registered")
    end

    return state
end
function Internal.IterateStateProviders()
    local tbl = Mixin({}, stateProviders, internalStateProviders)
    return next, tbl, nil
end

local CustomStateFunctions = {}
function Internal.RegisterCustomStateFunction(name, callback)
    if type(name) ~= "string" then
        error("Usage: RegisterCustomStateFunction(name, callback): name must be a string")
    end
    if CustomStateFunctions[name] ~= nil then
        error("Usage: RegisterCustomStateFunction(name, callback): function with name \"" .. name .. "\" already registered")
    end

    CustomStateFunctions[name] = callback
end
local Colors = {
    COMPLETE = CreateColor(0,1,0,1),
    STALLED = CreateColor(1,1,0,1),
    STARTED = ARTIFACT_GOLD_COLOR,

	COMMON = COMMON_GRAY_COLOR,
	UNCOMMON = UNCOMMON_GREEN_COLOR,
	RARE = RARE_BLUE_COLOR,
	EPIC = EPIC_PURPLE_COLOR,
	LEGENDARY = LEGENDARY_ORANGE_COLOR,
	ARTIFACT = ARTIFACT_GOLD_COLOR,
	HEIRLOOM = HEIRLOOM_BLUE_COLOR,
	WOWTOKEN = HEIRLOOM_BLUE_COLOR,
}
local Images = {
    PADDING = [[|T982414:0|t]],
    COMPLETE = "|A:achievementcompare-GreenCheckmark:0:0|a",
    STALLED = "|A:achievementcompare-YellowCheckmark:0:0|a",
    QUEST_PICKUP = "|A:QuestNormal:0:0|a",
    QUEST_TURN_IN = "|A:QuestTurnin:0:0|a",
}
Internal.Images = Images
local EnvironmentMixin = {
    print = print,
    format = format,
    ipairs = ipairs,
    concat = table.concat,
    select = select,
    math = math,
    tCount = function (tbl, func, from, to, every, ...)
        from = from or 1
        to = to or #tbl
        every = every or 1

        local result = 0
        for i=from,to,every do
            local item = tbl[i]
            if item[func](item, ...) then
                result = result + 1
            end
        end
        return result
    end,
    Custom = CustomStateFunctions,
    Colors = Colors,
    Images = Images,
    table = table,
    tFilter = tFilter,
    tInvert = tInvert,
    tMap = tMap,

    GetMoneyString = GetMoneyString,
    SecondsToTime = SecondsToTime,

    IsAltKeyDown = IsAltKeyDown,
    IsShiftKeyDown = IsShiftKeyDown,
    IsControlKeyDown = IsControlKeyDown,
    IsModifierKeyDown = IsModifierKeyDown,
    IsLeftShiftKeyDown = IsLeftShiftKeyDown,
    IsRightShiftKeyDown = IsRightShiftKeyDown,
}
local function CreateStateDriverFunction(driver, type, source, required, args)
    if not required and not source then
        return
    end

    local func, err = loadstring('local self, character, states' .. (args ~= nil and (', ' .. args) or '') .. ' = ...;' .. source, '[' .. driver:GetName() .. ':' .. type .. ']')
    if not func then
        return false, err
    end

    setfenv(func, CreateFromMixins(EnvironmentMixin))

    return func
end
Internal.CreateStateDriverFunction = CreateStateDriverFunction

-- {3, "IsWeeklyCapped", 1, 2.3, "test"}
local function GenerateFunctionCall(tbl)
    local values = {}
    for i=3,#tbl do
        local value = tbl[i]
        if type(value) == "string" then
            value = string.format("%q", value)
        end
        values[i] = value
    end
    return "states[" .. tbl[1] .. "]:" .. tbl[2] .. "(" .. table.concat(values, ", ") .. ")"
end
local function GenerateTextFunctionCalls(tbl)
    local merger = "strjoin"
    local arg = ", "
    local index = 1

    if type(tbl[index]) == "string" then
        merger = tbl[index]
        arg = tbl[index+1]

        index = index + 2
    end

    local values = {}
    for i=index,#tbl do
        local value = tbl[i]
        if type(value[1]) == "number" then
            value = GenerateFunctionCall(value)
        else
            value = GenerateTextFunctionCalls(value)
        end
        values[#values+1] = value
    end

    return format("%s(%q, %s)", merger, arg, table.concat(values, ", "))
end
--[[
    {
        "and",
        {1, "IsCapped"},
        {2, "IsCapped"},
        {
            "or",
            {3, "IsWeeklyCapped"},
            {3, "IsCapped"},
        }
    }
]]
local function GenerateCompletedFunctionCalls(tbl)
    local merger = "and"
    local index = 1

    if type(tbl[index]) == "string" then
        merger = tbl[index]
        index = index + 1
    end

    local values = {}
    for i=index,#tbl do
        local value = tbl[i]
        if type(value[1]) == "number" then
            value = GenerateFunctionCall(value)
        else
            value = "(" .. GenerateCompletedFunctionCalls(value) .. ")"
        end
        values[#values+1] = value
    end

    return table.concat(values, " " .. merger .. " ")
end
function Internal.GenerateFunctionFromTable(mode, tbl)
    if mode == "completed" then
        return "return " .. GenerateCompletedFunctionCalls(tbl)
    else
        return "return " .. GenerateTextFunctionCalls(tbl)
    end
end

-- print(Internal.GenerateFunctionFromTable("completed", {
--     "and",
--     {1, "IsCapped"},
--     {2, "IsCapped"},
--     {
--         "or",
--         {3, "IsWeeklyCapped"},
--         {3, "IsCapped"},
--     }
-- }))
-- print(Internal.GenerateFunctionFromTable("text", {
--     "strjoin", ", ",
--     {1, "GetLevel", 1},
-- }))

local StateDriverMixin = CreateFromMixins(Internal.ScriptHandlerMixin)
function StateDriverMixin:Init(id, name, states, completed, text, click, tooltip)
    Internal.ScriptHandlerMixin.OnLoad(self)
    self:RegisterSupportedScriptHandlers("OnEvent")

    self.id = id
    self.name = name
    self.states = states

    for _,state in ipairs(states) do
        state:SetDriver(self)
    end

    local err
    self.completed, err = CreateStateDriverFunction(self, "Completed", completed, true)
    if not self.completed then
        error(err)
    end

    self.text, err = CreateStateDriverFunction(self, "Text", text, true, 'L')
    if not self.text then
        error(err)
    end

    self.click, err = CreateStateDriverFunction(self, "Click", click, false, 'button')
    if self.click == false then
        error(err)
    end

    self.tooltip, err = CreateStateDriverFunction(self, "Tooltip", tooltip, false, 'L, tooltip')
    if self.tooltip == false then
        error(err)
    end
end
function StateDriverMixin:Deinit()
    Internal.UnregisterEventsFor(self)
end
function StateDriverMixin:GetID()
    return self.id
end
function StateDriverMixin:GetName()
    return self.name
end
function StateDriverMixin:SetCharacter(character)
    self.character = character
end
function StateDriverMixin:GetCharacter()
    return self.character
end
function StateDriverMixin:SetFlaggedCompleted(value)
    value = value and true or false

    local character = self:GetCharacter()
    assert(character ~= nil, "Call driver:SetCharacter before calling SetFlaggedCompleted")

    character:SetData("todoFlaggedCompleted", self:GetID(), value and true or nil)

    External.TriggerEvent("TODO_FLAGGED_COMPLETED", self:GetID(), value)
    self:OnEvent("TODO_FLAGGED_COMPLETED", value) -- We dont actually register TODO_FLAGGED_COMPLETED so we will just trigger it manually here
end
function StateDriverMixin:IsFlaggedCompleted() -- Has the todo been clicked on
    local character = self:GetCharacter()
    assert(character ~= nil, "Call driver:SetCharacter before calling IsFlaggedCompleted")
    return character:GetData("todoFlaggedCompleted", self:GetID())
end
function StateDriverMixin:IsCompleted()
    local success, result = xpcall(function ()
        return self.completed({
            GetName = function ()
                return self:GetName()
            end,
            IsFlaggedCompleted = function ()
                return self:IsFlaggedCompleted()
            end,
        }, self:GetCharacter(), self.states) == true
    end, geterrorhandler())
    if success then
        return result
    else
        return false
    end
end
local SUCCESS_TEXT_WRAPPER = "|cff00ff00%s|r"
function StateDriverMixin:GetText()
    local success, result = xpcall(function ()
        local result = self.text({
            GetName = function ()
                return self:GetName()
            end,
            IsCompleted = function ()
                return self:IsCompleted()
            end,
            IsFlaggedCompleted = function ()
                return self:IsFlaggedCompleted()
            end,
        }, self:GetCharacter(), self.states, Internal.L)

        if self:IsCompleted() then
            return string.format(SUCCESS_TEXT_WRAPPER, result or "")
        else
            return result or ""
        end
    end, geterrorhandler())
    if success then
        return result
    else
        return ""
    end
end
function StateDriverMixin:SupportsTooltip()
    return self.tooltip ~= nil
end
function StateDriverMixin:UpdateTooltip(tooltip)
    local success, result = xpcall(function ()
        return self.tooltip({
            GetName = function ()
                return self:GetName()
            end,
            IsCompleted = function ()
                return self:IsCompleted()
            end,
            IsFlaggedCompleted = function ()
                return self:IsFlaggedCompleted()
            end,
        }, self:GetCharacter(), self.states, Internal.L, tooltip)
    end, geterrorhandler())
    if success then
        return result
    else
        return false
    end
end
function StateDriverMixin:SupportsClick()
    return self.click ~= nil
end
function StateDriverMixin:Click(button)
    xpcall(function ()
        self.click({
            GetName = function ()
                return self:GetName()
            end,
            IsCompleted = function ()
                return self:IsCompleted()
            end,
            SetFlaggedCompleted = function (_, ...)
                return self:SetFlaggedCompleted(...)
            end,
            IsFlaggedCompleted = function ()
                return self:IsFlaggedCompleted()
            end,
        }, self:GetCharacter(), self.states, button)
    end, geterrorhandler())
end
function StateDriverMixin:OnEvent(...)
    self:RunScript("OnEvent", ...)
end
function StateDriverMixin:RegisterEvents(...)
    for i=1,select('#', ...) do
        Internal.RegisterEvent(self, (select(i, ...)))
    end
end
function StateDriverMixin:ClearEvents()
    Internal.UnregisterEventsFor(self)
end
function StateDriverMixin:RegisterEventsFor(target, isPlayer)
    for _,state in ipairs(self.states) do
        state:RegisterEventsFor(target, isPlayer)
    end
end

function Internal.CreateStateDriver(id, name, states, completed, text, click, tooltip)
    local buildStates = {}
    for index, source in ipairs(states) do
        local state
        if source.values then
            state = Internal.CreateState(source.type, source.id, unpack(source.values))
        else
            state = Internal.CreateState(source.type, source.id)
        end
        local key = state:GetUniqueKey()

        buildStates[index] = state
        if key and not buildStates[key] then
            buildStates[key] = state
        end
    end

    return CreateAndInitFromMixin(StateDriverMixin, id, name, buildStates, completed, text, click, tooltip), buildStates
end
