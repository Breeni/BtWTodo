--[[
    Manage events for all state drivers
]]

local ADDON_NAME, Internal = ...
local External = _G[ADDON_NAME]

local EventHandler = CreateFrame("Frame")
_G[ADDON_NAME .. 'EventHandler'] = EventHandler
EventHandler.targets = {}
local _RegisterEvent = EventHandler.RegisterEvent
local _UnregisterEvent = EventHandler.UnregisterEvent
function EventHandler:RegisterEvent(target, event, callback, prio)
    if not self.targets[event] then
        self.targets[event] = setmetatable({}, {__mode="k"})
    end

    if next(self.targets[event]) == nil then
        pcall(function ()
            _RegisterEvent(self, event)
        end)
    end

    if not self.targets[event][target] then
        self.targets[event][target] = {}
    end
    self.targets[event][target][callback or "OnEvent"] = prio or 0
end
function EventHandler:UnregisterEvent(target, event, callback)
    if not self.targets[event] then
        return
    end
    if not self.targets[event][target] then
        return
    end

    if callback == nil then
        self.targets[event][target] = nil
    else
        self.targets[event][target][callback or "OnEvent"] = nil

        if next(self.targets[event][target]) == nil then
            self.targets[event][target] = nil
        end
    end
    if next(self.targets[event]) == nil then
        pcall(function ()
            _UnregisterEvent(self, event)
        end)
        self.targets[event] = nil
    end
end
function EventHandler:UnregisterEventsFor(target)
    for event in pairs(self.targets) do
        self:UnregisterEvent(target, event)
    end
end
function EventHandler:OnEvent(event, ...)
    if self.targets[event] then
        local sorted = {}
        for target,callbacks in pairs(self.targets[event]) do
            for callback,prio in pairs(callbacks) do
                if type(callback) == "string" then
                    callback = target[callback]
                end
                sorted[#sorted+1] = {target = target, func = callback, prio = prio}
            end
        end
        table.sort(sorted, function (a, b)
            return a.prio < b.prio
        end)
        for _,callback in ipairs(sorted) do
            if callback.target == Internal then
                callback.func(event, ...)
            else
                callback.func(callback.target, event, ...)
            end
        end
    end
end
EventHandler:SetScript("OnEvent", EventHandler.OnEvent)

function External.TriggerEvent(event, ...)
    EventHandler:OnEvent(event, ...)
end
function Internal.RegisterEvent(target, event, callback, prio)
    if target == nil then
        target = Internal
    end

    if type(target) == "string" then -- Optional target arguement
        target, event, callback, prio = Internal, target, event, callback
    end
    assert(target ~= Internal or callback ~= nil, "callback required with no target set")

    EventHandler:RegisterEvent(target, event, callback, prio)
end
function Internal.UnregisterEvent(target, event, callback)
    if type(target) == "string" then -- Optional target arguement
        target, event, callback = Internal, target, event
    end
    assert(target ~= Internal or callback ~= nil, "callback required with no target set")

    EventHandler:UnregisterEvent(target, event, callback)
end
function Internal.UnregisterEventsFor(target)
    assert(target ~= Internal, "cannot clear all events for Internal")
    EventHandler:UnregisterEventsFor(target)
end
