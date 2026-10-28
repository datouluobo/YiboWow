-- Lua 5.1: load the actual manifests, migrations, entry and all Core pages.
local checks = 0
local function Check(condition, label) checks = checks + 1; assert(condition, label) end
local Boot = dofile("_NonRelease/CoreForever/Harness.lua")

for _, forever in ipairs({ false, true }) do
    local env, core, event, flush = Boot(forever)
    event("ADDON_LOADED")
    Check(core:IsInitialized(), "initialized from real ADDON_LOADED")
    if forever then
        Check(not core.Characters:GetCurrentID() and #core.Characters:GetAll() == 0, "wait for GUID; no guessed identity")
        Check(env.YiboCoreDB.sentinel == "mists" and not env.YiboCoreDB.characters, "Mists storage untouched")
        Check(core._private.eventRegistration.PLAYERBANKSLOTS_CHANGED ~= true, "removed event recorded without abort")
        Check(core.DataDomains._definitions.professions and core:HasCapability("profession-profile",1), "Forever profession profile domain available")
    else
        Check(core.Characters:GetCurrentID():match("^legacy:"), "Mists fallback preserved")
        Check(core._private.eventRegistration.PLAYERBANKSLOTS_CHANGED == true, "Mists event registration preserved")
        Check(core.DataDomains._definitions.professions ~= nil, "Mists domains preserved")
    end
    if forever then
        event("PLAYER_LOGIN"); event("PLAYER_ENTERING_WORLD")
        Check(#core.Characters:GetAll() == 0, "GUID can remain absent through world entry")
    end
    env.TEST_GUID = "Player-Test-1"
    if forever then
        event("BAG_UPDATE_DELAYED")
        Check(core.Characters:GetCurrent() ~= nil, "late GUID recovered on next native event")
    end
    event("PLAYER_LOGIN"); event("PLAYER_ENTERING_WORLD"); flush()
    Check(#core.Characters:GetAll() == 1 and core.Characters:GetCurrent().id == env.TEST_GUID, "one GUID row after login")
    local snapshot = core.Characters:GetCurrent(); snapshot.name = "tampered"
    Check(core.Characters:GetCurrent().name == "ProbeCharacter", "public snapshots stay detached")
    Check(core.DomainStore:GetState(env.TEST_GUID, "identity") == "known", "identity collection dispatched")
    if forever then
        Check(next(core.Database:GetDB().characters.aliases) == nil, "no name aliases")
        Check(not core.Characters:ImportLegacyCharacter("Other", "name-realm", { name = "Other" }), "unverified legacy import stopped")
        local scope = core.Database:GetDB().clientScope
        Check(scope.target == "Forever" and scope.projectID == 18 and scope.rulesetState == "unknown", "explicit client isolation and unknown ruleset")
    end
    env.SlashCmdList.YIBOCORE(""); flush()
    Check(core.AccountView.frame:IsShown() and core.AccountView.activePageID == "overview", "real /yco opens overview")
    core.AccountView:ShowPage("characters"); flush()
    Check(core.AccountView.activePageID == "characters", "roster page rendered")
    env.SlashCmdList.YIBOCORE("settings"); flush()
    Check(core.AccountView.activePageID == "settings", "settings workbench rendered")
    core.AccountView:ShowPage("about"); flush()
    local about = core.AccountView.frame.instances.about
    Check(about ~= nil, "About page rendered")
    if forever then
        Check(#core.AddonCatalog == 6 and core.AddonCatalog[1].name == "YiboBuilds" and core.AddonCatalog[2].name == "YiboCrafting" and core.AddonCatalog[3].name == "YiboCurrency" and core.AddonCatalog[4].name == "YiboMail" and core.AddonCatalog[5].name == "YiboReputation" and core.AddonCatalog[6].name == "YiboVault" and #about.addonRows == 6, "adapted business catalog shown on Forever")
        Check(about.childHeading:IsShown() and not about.optionalHeading:IsShown() and not about.otherHeading:IsShown(), "only applicable catalog group shown")
        Check(core.AddonCatalog[1].description == core:Text("CORE.BUILDS_CURRENT_EQUIPMENT") and core.AddonCatalog[2].description == core:Text("CORE.CRAFTING_CURRENT_OBSERVED") and core.AddonCatalog[3].description == core:Text("CORE.CURRENCY_CURRENT_MONEY") and core.AddonCatalog[4].description == core:Text("CORE.MAIL_CURRENT_INBOX") and core.AddonCatalog[5].description == core:Text("CORE.REPUTATION_CURRENT_OBSERVED") and core.AddonCatalog[6].description == core:Text("CORE.VAULT_CURRENT_BAGS_EQUIPMENT"), "target catalog describes current-character scope")
    else
        Check(#core.AddonCatalog == 14 and #about.addonRows == 14, "Mists catalog retained and TaskHub metadata included")
        Check(about.childHeading:IsShown() and about.optionalHeading:IsShown(), "applicable groups visible")
        for i = 2, #core.AddonCatalog do
            Check(core.AddonCatalog[i - 1].name < core.AddonCatalog[i].name, "catalog sorted by addon technical name")
        end
    end
    core.AccountView.frame.close.scripts.OnClick(core.AccountView.frame.close)
    Check(not core.AccountView.frame:IsShown(), "close action hides window")
    if forever then
        env.TEST_GUID = "Player-Test-2"
        core.Characters:RefreshCurrent()
        Check(#core.Characters:GetAll() == 2, "same display name cannot merge different GUIDs")
        env.TEST_GUID = "Player-Test-1"
    end
    core.Characters:SetShortName(env.TEST_GUID, "TestAlias")
    core.Database:GetDB().settings.language = "en"
    core.AccountView:GetSettings().customCharacterOrder = { env.TEST_GUID }
    local saved = core.Defaults:Copy(core.Database:GetDB())
    local restored, nextCore, nextEvent = Boot(forever, saved)
    restored.TEST_GUID = env.TEST_GUID
    nextEvent("ADDON_LOADED"); nextEvent("PLAYER_LOGIN")
    Check(nextCore:IsInitialized() and #nextCore.Characters:GetAll() == (forever and 2 or 1), "saved directory survives next session")
    Check(nextCore.Characters:GetCurrent().id == env.TEST_GUID, "identity preserved across sessions")
    Check(nextCore.Characters:GetDisplayName(nextCore.Characters:GetCurrent(), "short") == "TestAlias", "short name persisted")
    Check(nextCore.Locale:GetLanguage() == "en", "language preference persisted")
    Check(nextCore.AccountView:GetSettings().customCharacterOrder[1] == env.TEST_GUID, "ordering persisted")
    Check(#env.TEST_MESSAGES == 0 and #restored.TEST_MESSAGES == 0,
        "no swallowed runtime or callback errors: " .. table.concat(env.TEST_MESSAGES, " | ") .. table.concat(restored.TEST_MESSAGES, " | "))
end

do
    local env, core, event = Boot(false, nil, 18)
    env.WOW_PROJECT_CAMELOT = 18
    event("ADDON_LOADED")
    Check(not core:IsInitialized() and not env.YiboCoreDB.characters, "default Mists manifest cannot write on Forever")
end

for _, scenario in ipairs({ "wrong-client", "wrong-store", "future-schema" }) do
    local saved = scenario == "wrong-store" and { clientScope = { target = "Mists", projectID = 19 }, sentinel = true }
        or scenario == "future-schema" and { schemaVersion = 999, sentinel = true } or nil
    local env, core, event = Boot(true, saved, scenario == "wrong-client" and 19 or 18)
    event("ADDON_LOADED")
    Check(not core:IsInitialized() and not core.Database:GetDB(), scenario .. " stops before activation")
    if saved then Check(saved.sentinel and not saved.characters, scenario .. " data preserved") end
    env.SlashCmdList.YIBOCORE("")
    Check(not core.AccountView.frame, scenario .. " window does not open")
end
print("CoreForever Smoke passed: " .. checks .. " checks (real Forever/Mists manifests; simulated client/UI)")
