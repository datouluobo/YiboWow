local checks = 0
local function check(value) checks = checks + 1; assert(value) end
local function loadTarget(project, ready)
    YiboAutoOpen = nil
    WOW_PROJECT_CAMELOT, WOW_PROJECT_ID = 99, project
    IsLoggedIn = function() return false end
    YiboCore = ready and {
        IsInitialized = function() return true end, CheckAPIVersion = function(_, v) return v <= 13 end,
        HasCapability = function(_, n, v) return v == 1 end,
        ItemResolver = { Parse = function() end, GetInfo = function() end, Request = function() end },
        Locale = { Register = function() end, Get = function(_, _, key) return key end },
        RegisterSettingsPanel = function() end, RegisterAddon = function() end, UITheme = { CreateInput = function() end },
    } or nil
    for _, file in ipairs({ "Bootstrap.lua", "Forever/Target.lua", "Locale.lua", "Defaults.lua", "Database.lua", "Catalog.lua" }) do
        dofile("YiboAutoOpen/" .. file)
    end
    return YiboAutoOpen
end
YiboAutoOpenForeverDB = nil
YiboAutoOpenDB = { sentinel = true }
local a = loadTarget(1, true)
check(not a:Initialize()); check(YiboAutoOpenForeverDB == nil)
a = loadTarget(99, false)
check(not a:Initialize()); check(YiboAutoOpenForeverDB == nil)
a = loadTarget(99, true)
check(a:Initialize()); check(#a.db.catalog.order == 0)
check(next(a.Catalog.manualOnly) == nil); check(YiboAutoOpenDB.sentinel)
local db = a.db
check(a:Initialize()); check(a.db == db)
check(a.Database:AddItem(12345)); check(a.db.catalog.entries[12345])
check(not a.Database:AddItem(12345)); check(#a.db.catalog.order == 1)
a = loadTarget(99, true); check(a:Initialize()); check(a.db.catalog.entries[12345])
check(a.Database:RemoveItem(12345)); check(#a.db.catalog.order == 0)
a = loadTarget(99, true); check(a:Initialize()); check(#a.db.catalog.order == 0)
YiboCore.CheckAPIVersion = function() return false end
a.runtime.initialized = false
check(not a:Initialize())
print("Forever target spec passed: " .. checks .. " assertions")
