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
    for _, listener in ipairs(listeners) do
        if listener.owner == owner and listener.callback == callback then return end
    end
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

function Events:HasListeners(eventName)
    return self._listeners[eventName] ~= nil and #self._listeners[eventName] > 0
end

function Events:FireIsolated(eventName, ...)
    local listeners, args = {}, { n = select("#", ...), ... }
    for index, listener in ipairs(self._listeners[eventName] or {}) do listeners[index] = listener end
    for _, listener in ipairs(listeners) do
        local values = Core.Defaults:Copy(args)
        local ok, err = pcall(listener.callback, listener.owner, unpack(values, 1, values.n))
        if not ok then Core:Print("事件回调失败：" .. tostring(err)) end
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
