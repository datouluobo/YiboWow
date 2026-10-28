-- Read-only source tests; all saved variables below are synthetic in-memory values.
local Boot = dofile("_NonRelease/CoreForever/Harness.lua")
local checks = 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
local function Equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k,v in pairs(a) do if not Equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
local function Observe(core)
    local count = { ready = 0 }
    core.Events:Register("CORE_READY", count, function(owner)
        Check(core:IsInitialized() and core.Database:GetDB() ~= nil and core.Database._prepared==nil, "ready observes committed startup")
        owner.ready = owner.ready + 1
        Check(core:Initialize(), "ready callback can safely call Initialize")
    end)
    return count
end

for _, forever in ipairs({false,true}) do
    local name = forever and "YiboCoreForeverDB" or "YiboCoreDB"
    local target = forever and "Forever" or "Mists"
    for _, schema in ipairs({0,4,11}) do
        local saved = { schemaVersion = schema, marker = { custom = "keep" },
            settings = { language = "en", accountView = { characterSort = schema < 5 and "seen" or {},
                customCharacterOrder = { "Offline" }, hiddenCharacters = { Offline = true } } },
            characters = { byID = { Offline = { id = "Offline", name = "Offline", realm = "OtherRealm", class = "HUNTER" } } } }
        local e,c,event,flush,load = Boot(forever,saved)
        local seen = Observe(c)
        event("ADDON_LOADED"); event("ADDON_LOADED"); event("PLAYER_LOGIN"); flush()
        Check(c:IsInitialized() and seen.ready == 1, "startup publishes once")
        Check(e[name] == saved and c.db == saved, "original root table identity preserved")
        Check(saved.schemaVersion == 11 and saved.marker.custom == "keep", "migrate and preserve extension data")
        Check(saved.characters.byID.Offline.name == "Offline" and saved.settings.accountView.hiddenCharacters.Offline, "offline roster and settings preserved")
        Check(saved.clientScope.target == target and saved.clientScope.projectID == (forever and 18 or 19), "target stamp")
        local pending = #e.TEST_TIMERS
        local frame = c._private.lifecycleFrame
        load("YiboCore/Runtime/Lifecycle.lua")
        Check(c._private.lifecycleFrame == frame, "lifecycle repeat load reuses frame")
        load("YiboCore/Bootstrap.lua")
        Check(c:IsInitialized() and c.VERSION==(forever and "0.2.0" or "1.12.9"),"bootstrap repeat load preserves readiness and target version")
        for i=1,5 do Check(c:Initialize(), "direct initialization is idempotent") end
        Check(seen.ready == 1 and #e.TEST_TIMERS == pending, "no duplicate notification or work")
        Check(c._private.eventRegistration.BANKFRAME_OPENED == (not forever and true or nil), "target owns bank subscriptions")
        local copy = c.Defaults:Copy(saved)
        local restored,nextCore,nextEvent = Boot(forever,copy)
        nextEvent("ADDON_LOADED")
        Check(nextCore:IsInitialized() and nextCore.Locale:GetLanguage()=="en", "next session and language restore")
        Check(restored[name].characters.byID.Offline.realm=="OtherRealm", "offline other realm retained")
    end

    local corrupt = {
        function(s) s.characters = false end,
        function(s) s.characters = {byID = "bad"} end,
        function(s) s.characters = {byID = { broken = 1 }} end,
        function(s) s.characters = {byID = { broken = {domains = false} }} end,
        function(s) s.characters = {byID = { broken = {domains = {identity = {data=false}}} }} end,
        function(s) s.characters = {aliases = {bad = 4}} end,
        function(s) s.characters = {byID = {broken = {profile = {professions = "bad"}}}} end,
        function(s) s.settings = true end,
        function(s) s.settings = {accountView = 7} end,
        function(s) s.settings = {accountView = {entry = {minimap = false}}} end,
        function(s) s.settings = {accountView = {pageSizes = {broken = 10}}} end,
        function(s) s.settings = {accountView = {columnPages = {broken = false}}} end,
        function(s) s.settings = {accountView = {entry = {pagePositions = {broken = {}}}}} end,
        function(s) s.characterDisplay = {broken = "bad"} end,
        function(s) s.characterDeletionHistory = {broken = {failures = false}} end,
        function(s) s.schemaVersion = "bad" end,
        function(s) s.schemaVersion = -1 end,
        function(s) s.schemaVersion = 1.5 end,
        function(s) s.schemaVersion = 999 end,
        function(s) s.clientScope = {target = "Retail",projectID=1} end,
        function(s) s.clientScope = false end,
    }
    for _,damage in ipairs(corrupt) do
        local saved={marker={value="untouched"}}
        damage(saved)
        local e,c,event=Boot(forever,saved)
        local before=c.Defaults:Copy(saved)
        local seen=Observe(c)
        event("ADDON_LOADED")
        Check(not c:IsInitialized() and c.db==nil and c.Database:GetDB()==nil, "invalid store stops")
        Check(e[name]==saved and Equal(saved,before), "invalid store preserved exactly")
        Check(not c.Registry:Get(c.NAME) and seen.ready==0 and not c._private.initializing, "failure leaves no successful readiness")
    end
    for _,kind in ipairs({"cycle","function","root","missing-constant","wrong-project"}) do
        local saved={marker="keep"}
        if kind=="cycle" then saved.self=saved end
        if kind=="function" then saved.callback=function() end end
        if kind=="root" then saved="not-a-table" end
        local e,c,event=Boot(forever,saved,nil,function(env)
            if kind=="missing-constant" then env[forever and "WOW_PROJECT_CAMELOT" or "WOW_PROJECT_MISTS_CLASSIC"]=false end
            if kind=="wrong-project" then env.WOW_PROJECT_ID=1 end
        end)
        event("ADDON_LOADED")
        Check(not c:IsInitialized() and e[name]==saved, kind.." stops without replacing data")
        if kind=="cycle" then Check(saved.self==saved and saved.characters==nil,"cycle preserved") end
        if kind=="missing-constant" or kind=="wrong-project" then
            Check(c._private.eventRegistration.PLAYER_LOGIN==nil,"wrong target has no business lifecycle subscriptions")
        end
    end

    for _,failure in ipairs({"migration-throw","migration-false","registry","locale","character"}) do
        local saved={marker={value="keep"}}
        local e,c,event=Boot(forever,saved)
        local before=c.Defaults:Copy(saved)
        local seen=Observe(c)
        local owner,method
        if failure:find("migration",1,true) then owner,method=c.Migrations,"Run"
        elseif failure=="registry" then owner,method=c,"RegisterAddon"
        elseif failure=="locale" then owner,method=c.Locale,"Initialize"
        else owner,method=c.Characters,"RefreshCurrent" end
        local original=owner[method]
        owner[method]=function(_,candidate)
            if failure=="migration-throw" then candidate.injected=true; error("injected migration") end
            if failure=="migration-false" then candidate.injected=true; return false,"injected migration rejection" end
            if failure=="registry" then return nil,"injected registration failure" end
            error("injected initialization failure")
        end
        event("ADDON_LOADED")
        Check(not c:IsInitialized() and seen.ready==0 and not c.Registry:Get(c.NAME), "injected failure cannot publish readiness")
        Check(Equal(saved,before) and e[name]==saved and c.db==nil, "injected failure rolls back candidate")
        owner[method]=original
        Check(c:Initialize() and seen.ready==1,"same session retry succeeds once")
        Check(c:Initialize() and seen.ready==1,"retry is idempotent")
    end

    local e,c,event=Boot(forever)
    local seen=Observe(c)
    local initialize=c.Locale.Initialize
    c.Locale.Initialize=function(owner)
        local ok=c:Initialize()
        Check(ok==false and not c:IsInitialized(),"reentrant initialization is blocked before readiness")
        return initialize(owner)
    end
    c.Events:Register("CORE_READY",{},function() error("consumer failure") end)
    local later=0
    c.Events:Register("CORE_READY",{},function() later=later+1 end)
    event("ADDON_LOADED")
    Check(c:IsInitialized() and seen.ready==1 and later==1,"consumer failure isolated after committed readiness")
    Check(c:Initialize() and seen.ready==1,"consumer failure cannot cause reinitialization")

    local saved={marker="preexisting"}
    local e2,c2=Boot(forever,saved)
    Check(c2.Database:Initialize(),"standalone database initialization remains supported")
    local before=c2.Defaults:Copy(saved)
    local original=c2.Characters.RefreshCurrent
    c2.Characters.RefreshCurrent=function() error("failure after preinitialized database") end
    Check(not c2:Initialize() and Equal(saved,before) and c2.Database:GetDB()==saved,"preinitialized database also stages writes on Core startup")
    c2.Characters.RefreshCurrent=original
    Check(c2:Initialize(),"retry with preinitialized database")

    local e3,c3=Boot(forever,{schemaVersion=4,marker="keep"})
    local step=c3.Migrations._steps[5]
    c3.Migrations._steps[5]=nil
    Check(not c3:Initialize() and e3[name].schemaVersion==4 and e3[name].characters==nil,"missing migration preserves original")
    c3.Migrations._steps[5]=step
    Check(c3:Initialize(),"missing migration recovery")

    for _, eventFailure in ipairs({"throw", "false"}) do
    local e4,c4,event4=Boot(forever,nil,nil,function(env)
        local create=env.CreateFrame
        env.CreateFrame=function(...)
            local frame=create(...)
            local register=frame.RegisterEvent
            frame.RegisterEvent=function(self,name)
                if name=="PLAYER_LOGIN" then
                    if eventFailure=="false" then return false end
                    error("injected required-event failure")
                end
                return register(self,name)
            end
            return frame
        end
    end)
    event4("ADDON_LOADED")
    Check(not c4:IsInitialized() and c4.db==nil and c4._private.lifecycleError,"required event failure cannot publish readiness")
    end
end
print("CoreStartupR1 passed: "..checks.." checks (Mists/Forever synthetic stores and real manifests)")
