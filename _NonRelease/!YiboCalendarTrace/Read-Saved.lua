-- Usage: lua .../Read-Saved.lua <absolute SavedVariables/YiboCalendarTrace.lua>
local loader = assert(loadfile(assert(arg[1], "saved-variable path required")))
local env = {}
setfenv(loader, env)
loader()
local db = assert(env.YiboCalendarTraceDB, "trace database missing")
for index, session in ipairs(db.sessions or {}) do
    print(string.format("SESSION %d started=%s last=%s", index, tostring(session.startedAt), tostring(session.lastSeq)))
    for _, key in ipairs({ "initial", "firstAbnormalObservation", "firstAbnormalCall", "firstObservedCrossing", "firstRepairCall" }) do
        local row = session[key]
        if row then print(string.format("PIN %s seq=%s after=%s | %s", key, tostring(row.seq), tostring(row.after), tostring(row.origin))) end
    end
    for name, loaded in pairs(session.loadedBeforeHooks or {}) do
        if loaded then print("LOADED_BEFORE_HOOK " .. name) end
    end
    for _, row in ipairs(session.rows or {}) do
        print(string.format("%s %s(%s,%s) %s -> %s realm=%s offset=%s | %s",
            tostring(row.seq), tostring(row.kind), tostring(row.arg1), tostring(row.arg2),
            tostring(row.previousObserved), tostring(row.after), tostring(row.realm or row.realmRaw), tostring(row.offset), tostring(row.origin)))
    end
end
