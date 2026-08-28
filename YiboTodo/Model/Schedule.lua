local Addon = _G.YiboTodo
Addon.Model.Schedule = {
    ReadyAt = function(_, observedAt, remaining) return (tonumber(observedAt) or 0) + math.max(0, tonumber(remaining) or 0) end,
}
