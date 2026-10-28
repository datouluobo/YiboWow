local Boot = dofile("_NonRelease/CoreRetailR2/Harness.lua")
local checks = 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
local function Count(values) local n = 0; for _ in pairs(values) do n = n + 1 end; return n end
local function Start(saved, configure, alias)
    local e, c, fire, flush, load = Boot("Retail", saved, nil, configure, alias)
    fire("ADDON_LOADED"); fire("PLAYER_LOGIN"); flush()
    return e, c, fire, flush, load
end
for _, alias in ipairs({ false, true }) do
    for _, language in ipairs({ "zhCN", "enUS" }) do
        local e,c,fire,flush = Start(nil, function(env)
            env.GetLocale = function() return language end
            env.UnitClass = function() return "Hunter", "HUNTER", 3 end
            env.UnitRace = function() error("not part of directory collection") end
            env.IsInGuild = env.UnitRace; env.GetZoneText = env.UnitRace
            env.GetNumSkillLines = env.UnitRace; env.GetAverageItemLevel = env.UnitRace
        end, alias)
        Check(c:IsInitialized() and c:GetVersion() == "0.1.0" and c.API_VERSION == 13, "Retail starts via source/native alias")
        Check(e.YiboCoreRetailDB == c.Database:GetDB() and e.YiboCoreDB.sentinel == "mists" and e.YiboCoreForeverDB.sentinel == "forever", "independent store, other targets untouched")
        Check(e.YiboCoreRetailDB.clientScope.target == "Retail" and e.YiboCoreRetailDB.clientScope.projectID == 1, "Retail scope stamped")
        Check(Count(c.Capabilities._items) == 32 and not c:HasCapability("profession-profile") and not c:HasCapability("calendar-day-query"), "only implemented infrastructure declared")
        Check(#c.DataDomains:GetDefinitions() == 1 and c.DataDomains._definitions.identity ~= nil, "directory identity is the only Core domain")
        local row = c.Characters:GetCurrent()
        Check(row.id == e.TEST_GUID and row.class == "HUNTER" and row.domains.identity.state == "known", "real native GUID and class retained")
        Check(row.domains.identity.data.race == nil and row.domains.identity.data.guild == nil and row.domains.location == nil, "no optional or retired collectors fabricated")
        e.UnitLevel = function() return 66 end; fire("PLAYER_LEVEL_UP"); flush()
        Check(c.Characters:GetCurrent().level == 66 and c.Characters:GetCurrent().domains.identity.data.level == 66, "Retail level event refreshes directory before projection")
        local fields = c.Fields:GetByConsumer("character-archive")
        Check(#fields == 2 and fields[1].id == "character.identity" and fields[2].id == "character.level", "Retail only registers applicable fields")
        Check(#c.AddonCatalog == 1 and c.AddonCatalog[1].name == "YiboBeastPaths" and next(c.CharacterCleanup.EXPECTED_OWNERS) == nil, "existing routes only, no future pet owner")
        Check(c.Characters:ImportLegacyCharacter("YiboBeastPaths", "ProbeCharacter-ProbeRealm", { name = "ProbeCharacter", realm = "ProbeRealm" }) == nil, "Retail cannot import legacy identity")
        local ready = 0; c.Events:Register("CORE_READY", "repeat", function() ready = ready + 1 end)
        local db = c.Database:GetDB(); Check(c:Initialize() and c:Initialize() and ready == 0 and c.Database:GetDB() == db, "repeat init retains committed store and ready count")
        for _, page in ipairs({ "overview", "characters", "settings", "help", "about" }) do
            c.AccountView:ShowPage(page); flush()
            Check(c.AccountView.activePageID == page and not c.AccountView._pages[page].lastError, "Retail shared page renders: " .. page)
        end
        local id = e.TEST_GUID
        e.TEST_GUID = "Player-R2-2"; e.GetRealmName = function() return "OtherRealm" end; fire("PLAYER_ENTERING_WORLD"); flush()
        Check(#c.Characters:GetAll() == 2 and c.Characters:Get(id).realm == "ProbeRealm", "same name cross-realm remains separate GUIDs")
        e.UnitGUID = function() return nil end; fire("PLAYER_ENTERING_WORLD")
        Check(c.Characters:GetCurrentID() == nil and #c.Characters:GetAll() == 2, "temporary GUID loss creates no name fallback")
        local old = c.Characters:Get("Player-R2-2").domains.identity
        Check(old.data.name == "ProbeCharacter", "temporary native failure retains prior identity data")
    end
end
for _, target in ipairs({ "Retail", "Mists", "Forever" }) do
    for _, project in ipairs({ 1, 19, 18, 999 }) do
        local expected = ({ Retail=1, Mists=19, Forever=18 })[target]
        local e,c,fire = Boot(target,nil,project)
        fire("ADDON_LOADED")
        Check(c:IsInitialized() == (project == expected), "actual product identity gates each manifest")
        if project ~= expected then Check(c.Database:GetDB() == nil and not c.Registry:Get("YiboCore"), "wrong product stops before store and registration") end
    end
end
for _, saved in ipairs({
    { schemaVersion = 11, settings = {} },
    { schemaVersion = 11, clientScope = { target = "Mists", projectID = 19 } },
    { schemaVersion = 11, clientScope = { target = "Retail", projectID = 19 } },
    { schemaVersion = 999, clientScope = { target = "Retail", projectID = 1 } },
    { schemaVersion = 11, clientScope = { target = "Retail", projectID = 1 }, characters = "bad" },
}) do
    local e,c = Start(saved)
    Check(not c:IsInitialized() and e.YiboCoreRetailDB == saved, "ambiguous, mismatched, future or malformed save preserved")
    Check(c.Database:GetDB() == nil and not c.Registry:Get("YiboCore"), "failed preflight never commits or registers")
end
do
    local saved = { schemaVersion = 11, clientScope = { target = "Retail", projectID = 1 }, settings = { language = "en" },
        characters = { byID = { Old = { id = "Old", name = "Old", realm = "Elsewhere" } }, aliases = {}, seenOrder = {} } }
    local e,c = Start(saved)
    Check(c:IsInitialized() and e.YiboCoreRetailDB == saved and c.Characters:Get("Old") ~= nil and c.Locale:GetLanguage() == "en", "stamped compatible Retail data restores in place")
end
do
    local e,c,fire,flush = Start(nil, function(env) env.TEST_GUID = nil end)
    Check(c:IsInitialized() and c.Characters:GetCurrentID() == nil and #c.Characters:GetAll() == 0, "pending GUID permits infrastructure without invented character")
    e.TEST_GUID = "Player-R2-Late"; fire("PLAYER_ENTERING_WORLD"); flush()
    Check(c.Characters:GetCurrent().id == e.TEST_GUID and c.Characters:GetCurrent().domains.identity.state == "known", "late GUID collects directory identity once ready")
end
do
    local e,c = Start({}, function(env) env.WOW_PROJECT_MAINLINE = nil end)
    Check(not c:IsInitialized() and next(e.YiboCoreRetailDB) == nil, "missing real product constant stops write")
end
print("CoreRetailR2 Spec passed: " .. checks .. " checks (real three-target manifests; Retail directory/store/UI and wrong-product guards)")
