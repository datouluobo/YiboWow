local Boot = dofile("_NonRelease/CoreRetailR2/Harness.lua")
local target, root = assert(arg[1]), assert(arg[2])
local projects = { Retail=1, Mists=19, Forever=18 }
local versions = { Retail="0.1.0", Mists="1.12.9", Forever="0.2.0" }
local checks = 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
local function Start(project, saved, probeSaved, language)
    local e,c,fire,flush = Boot(target, saved, project, function(env)
        env.print = function(line) env.TEST_MESSAGES[#env.TEST_MESSAGES + 1] = line end
        env.GetLocale = function() return language or "enUS" end
        env.GetBuildInfo = function() return "synthetic", "0", "offline", ({Retail=120105,Mists=50504,Forever=16001})[target] end
    end, false, root, "YiboCore.toc")
    local ready = 0; c.Events:Register("CORE_READY", "R4Package", function() ready = ready + 1 end)
    fire("ADDON_LOADED"); fire("PLAYER_LOGIN"); flush()
    local name = "YiboCore" .. target .. "R4"
    local function Load(file)
        local chunk = assert(loadfile("_NonRelease/" .. name .. "/" .. file)); setfenv(chunk, e); chunk(name)
    end
    e[name .. "DB"] = probeSaved
    Load("Target.lua"); Load("Probe.lua")
    return e,c,fire,flush,ready,name
end
for _, language in ipairs({ "zhCN", "enUS" }) do
    local e,c,fire,flush,ready,name = Start(projects[target], nil, nil, language)
    Check(c:IsInitialized() and c:GetVersion() == versions[target] and c.API_VERSION == 13, "actual selected package initializes")
    Check(ready == 1 and c:Initialize(), "initial ready once")
    Check(type(c.PackagedAddonVersions) == "table", "generated package index actually loaded")
    for _, pageID in ipairs({"overview","characters","settings","help","about"}) do
        c.AccountView:ShowPage(pageID); flush()
        Check(not c.AccountView._pages[pageID].lastError, "actual package Core page renders")
    end
    local slash = e.SlashCmdList[name:upper()]
    Check(type(slash) == "function", "correct target probe registers command")
    slash(""); Check(e.TEST_MESSAGES[#e.TEST_MESSAGES]:find("marker=unset",1,true), "unmarked diagnostic is read-only")
    slash("mark"); Check(e.TEST_MESSAGES[#e.TEST_MESSAGES]:find("marker=true",1,true), "public settings marker written")
    local originalStore = c.Database:GetDB()
    local saved, probe = c.Defaults:Copy(originalStore), c.Defaults:Copy(e[name .. "DB"])
    Check(probe.expectedSort and probe.originalSort and e.TEST_MESSAGES[#e.TEST_MESSAGES-1]:find("repeatedReady=0",1,true), "probe persists expected marker; report does not reinitialize")
    local re,rc,_,reflush,_,rname = Start(projects[target], saved, probe, language)
    re.SlashCmdList[rname:upper()]("")
    Check(re.TEST_MESSAGES[#re.TEST_MESSAGES]:find("marker=true",1,true) and rc.Database:GetDB() ~= originalStore,
        "synthetic fresh-boot recovery from copied Core and probe stores")
    Check(rc.Characters:GetCurrent({identityOnly=true}) ~= nil, "recovered package directory available")
end
for _, project in ipairs({1,19,18,999}) do
    if project ~= projects[target] then
        local saved = { sentinel = "untouched" }
        local e,c,_,_,_,name = Start(project, saved)
        Check(not c:IsInitialized() and saved.sentinel == "untouched" and next(saved,"sentinel") == nil, "wrong product preserves original store")
        Check(e.SlashCmdList[name:upper()] == nil and e[name .. "DB"] == nil, "wrong product probe neither registers nor writes")
    end
end
print("R4 actual-package simulation passed: " .. checks .. " checks; " .. target)
