local Core = _G.YiboCore

local Events = {}
Core.Events = Events
Events._listeners = Events._listeners or {}

function Events:Register(eventName, owner, callback)
    if callback == nil and type(owner) == "function" then
        callback = owner
        owner = nil
    end

    if type(eventName) ~= "string" or type(callback) ~= "function" then
        error("YiboCore.Events:Register requires an event name and callback.")
    end

    local listeners = self._listeners[eventName] or {}
    self._listeners[eventName] = listeners
    listeners[#listeners + 1] = {
        owner = owner,
        callback = callback,
    }
end

function Events:Unregister(eventName, owner, callback)
    local listeners = self._listeners[eventName]
    if not listeners then
        return
    end

    for index = #listeners, 1, -1 do
        local listener = listeners[index]
        if listener.owner == owner and (callback == nil or listener.callback == callback) then
            table.remove(listeners, index)
        end
    end
end

function Events:Fire(eventName, ...)
    local listeners = self._listeners[eventName]
    if not listeners then
        return
    end

    for _, listener in ipairs(listeners) do
        listener.callback(listener.owner, ...)
    end
end

Core.Capabilities:Register("events", 1)
