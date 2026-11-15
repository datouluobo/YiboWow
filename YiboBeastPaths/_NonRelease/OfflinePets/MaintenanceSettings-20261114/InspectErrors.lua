-- Sanitized inspection only: do not print account, character or saved locals.
local env = {}
local chunk = assert(loadfile(assert(arg[1])))
setfenv(chunk, env); chunk()
local db = assert(env.BugGrabberDB)
local current, related, external = 0, 0, 0
for _, entry in ipairs(db.errors or {}) do
    if entry.session == db.session then
        current = current + 1
        local details = (entry.message or "") .. (entry.stack or "")
        if details:find("Interface/AddOns/YiboBeastPaths/", 1, true)
            or details:find("Interface\\AddOns\\YiboBeastPaths\\", 1, true) then
            related = related + 1
        else
            external = external + 1
        end
    end
end
print("session=" .. tostring(db.session) .. " current=" .. current .. " YBP=" .. related .. " other=" .. external)
