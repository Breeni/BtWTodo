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
local function IsAtleastInterfaceClosure(interface)
    return (INTERFACE_NUMBER >= interface) and function () return true end or function () return false end
end
Internal.IsDragonflight = IsAtleastInterfaceClosure(100000)
Internal.IsDragonflightFull = IsAtleastInterfaceClosure(100002)
Internal.IsEternitysEnd = IsAtleastInterfaceClosure(90200)
Internal.IsChainsOfDomination = IsAtleastInterfaceClosure(90100)
Internal.IsShadowlands = IsAtleastInterfaceClosure(90000)

Internal.IsDragonflightExpansion = function ()
    return GetExpansionLevel() == LE_EXPANSION_DRAGONFLIGHT
end
