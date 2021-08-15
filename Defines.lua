local ADDON_NAME, Internal = ...

-- Localization table
local L = setmetatable({}, {
    __index = function (self, key)
        -- print("[" .. ADDON_NAME .. "] [warn]: Missing translation for \"" .. key .. "\"")
        self[key] = key
        return key
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
