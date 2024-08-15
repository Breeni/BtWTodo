local ADDON_NAME, Internal = ...

-- Localization table
local L = setmetatable({}, {
    __index = function (self, key)
        -- print("[" .. ADDON_NAME .. "] [warn]: Missing translation for \"" .. key .. "\"")
        if type(_G[key]) == "string" then
            self[key] = _G[key]
            return _G[key]
        else
            self[key] = key
            return key
        end
    end,
})
Internal.L = L;

-- Used for storing data used by state providers, for example, if quests are daily/weekly
Internal.data = {}

-- External api table
local External = {}
_G[ADDON_NAME] = External

-- /dump BtWTodo.CreateTodo({name = "Test", states = {{type = "quest", id = 64101}}, completed = "return states[1]:IsCompleted()", text = "return \"Test\""})
function External.CreateTodo(tbl)
    return Internal.CreateStateDriver(nil, tbl.name, tbl.states, tbl.completed, tbl.text, tbl.click, tbl.tooltip)
end

-- Mixin for custom script handling
local ScriptHandlerMixin = {}
function ScriptHandlerMixin:OnLoad()
    self.scriptHandlers = {}
    self.supportedHandlers = {}
end
function ScriptHandlerMixin:RegisterSupportedScriptHandlers(...)
    for i=1,select('#', ...) do
        self.supportedHandlers[(select(i,...))] = true
    end
end
function ScriptHandlerMixin:RunScript(scriptType, ...)
    local handler
    if self.supportedHandlers[scriptType] then
        handler = self.scriptHandlers[scriptType]
    else
        handler = self:GetScript(scriptType)
    end
    if handler then
        handler(self, ...)
    end
end
function ScriptHandlerMixin:SetScript(scriptType, handler)
    if self.supportedHandlers[scriptType] then
        self.scriptHandlers[scriptType] = handler
    else
        getmetatable(self).__index.SetScript(self, scriptType, handler)
    end
end
Internal.ScriptHandlerMixin = ScriptHandlerMixin

local INTERFACE_NUMBER = select(4, GetBuildInfo());
local function IsInterface(interface)
    return INTERFACE_NUMBER == interface
end
local function IsAtleastInterface(interface)
    return INTERFACE_NUMBER >= interface
end

local function IsExpansion(expansion)
    return expansion == GetExpansionLevel()
end

local seasons = {
    [1] = {
        [9] = 1670943600,
        [10] = 1683644400,
        [11] = 1699974000,
        [12] = 1713884400,
        [13] = 1725980400,
    },
    [2] = {
        [9] = 1671058800,
        [10] = 1683759600,
        [11] = 1700089200,
        [12] = 1713999600,
        [13] = 1726095600,
    },
    [3] = {
        [9] = 1670990400,
        [10] = 1683691200,
        [11] = 1700020800,
        [12] = 1713931200,
        [13] = 1726027200,
    },
    [4] = {
        [9] = 1671058800,
        [10] = 1683759600,
        [11] = 1700089200,
        [12] = 1713999600,
        [13] = 1726095600,
    },
    [5] = {
        [9] = 1671058800,
        [10] = 1683759600,
        [11] = 1700089200,
        [12] = 1713999600,
        [13] = 1726095600,
    },
    [72] = {
        [9] = 1671058800,
        [10] = 1683759600,
        [11] = 1700089200,
        [12] = 1713999600,
        [13] = 1726095600,
    },
};
local GetCurrentSeason = C_MythicPlus and C_MythicPlus.GetCurrentSeason or function ()
    return 0
end
local function IsSeason(season)
    -- C_MythicPlus.GetCurrentSeason isnt always available during first login so we fallback to date checking.
    -- In the future it might be worth using something else or delaying season checks
    local current = GetCurrentSeason()
    if current > 0 then
        return season == current
    end

    local time = GetServerTime()
    local region = seasons[GetCurrentRegion()]
    local prev = region[season]
    if not prev or time < prev then
        return false
    end
    if region[season+1] then
        local next = region[season+1]
        if time > next then
            return false
        end
    end
    return true
end

Internal.Is90100 = IsInterface(90100)
Internal.Is90200 = IsInterface(90200)
Internal.Is100000 = IsInterface(100000)
Internal.Is100002 = IsInterface(100002)
Internal.Is100005 = IsInterface(100005)
Internal.Is100007 = IsInterface(100007)
Internal.Is100100 = IsInterface(100100)
Internal.Is100105 = IsInterface(100105)
Internal.Is100200 = IsInterface(100105)
Internal.Is90200OrBeyond = IsAtleastInterface(90200)
Internal.Is100000OrBeyond = IsAtleastInterface(100000)

Internal.IsBattleForAzeroth = IsExpansion(LE_EXPANSION_BATTLE_FOR_AZEROTH or 7)
Internal.IsShadowlands = IsExpansion(LE_EXPANSION_SHADOWLANDS or 8)
Internal.IsDragonflight = IsExpansion(LE_EXPANSION_DRAGONFLIGHT or 9)
Internal.IsTheWarWithin = IsExpansion(LE_EXPANSION_11_0 or 10)

Internal.IsBattleForAzerothSeason1 = Internal.IsBattleForAzeroth and IsSeason(4)
Internal.IsShadowlandsSeason1 = Internal.IsShadowlands and IsSeason(5)
Internal.IsShadowlandsSeason2 = Internal.IsShadowlands and IsSeason(6)
Internal.IsShadowlandsSeason3 = Internal.IsShadowlands and IsSeason(7)
Internal.IsShadowlandsSeason4 = Internal.IsShadowlands and IsSeason(8)
Internal.IsDragonflightSeason1 = Internal.IsDragonflight and IsSeason(9)
Internal.IsDragonflightSeason2 = Internal.IsDragonflight and IsSeason(10)
Internal.IsDragonflightSeason3 = Internal.IsDragonflight and IsSeason(11)
Internal.IsDragonflightSeason4 = Internal.IsDragonflight and IsSeason(12)
Internal.IsTheWarWithinSeason1 = Internal.IsTheWarWithin -- and IsSeason(13)
