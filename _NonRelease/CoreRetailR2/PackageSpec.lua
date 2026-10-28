local Boot = dofile("_NonRelease/CoreRetailR2/Harness.lua")
local root = assert(arg[1], "extracted player-package root required")
local checks = 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
for _, project in ipairs({1,19,18}) do
    local e,c,fire,flush = Boot("Retail", nil, project, nil, false, root, "YiboCore.toc")
    local ready = 0; c.Events:Register("CORE_READY", "package", function() ready = ready + 1 end)
    fire("ADDON_LOADED"); fire("PLAYER_LOGIN"); flush()
    if project == 1 then
        Check(c:IsInitialized() and c:GetVersion() == "0.1.0" and c.API_VERSION == 13, "actual player-package default TOC starts Retail")
        Check(e.YiboCoreRetailDB.clientScope.target == "Retail" and e.YiboCoreDB.sentinel == "mists", "actual package keeps stores isolated")
        Check(c.PackagedAddonVersions.YiboBeastPaths == "1.8", "generated target version index actually loaded")
        Check(c.Characters:GetCurrent().domains.identity.state == "known" and #c.Fields:GetByConsumer("character-archive") == 2, "actual package identity/fields")
        Check(ready == 1 and c:Initialize() and ready == 1, "actual package ready once")
        for _, page in ipairs({"overview","characters","settings","help","about"}) do
            c.AccountView:ShowPage(page); flush()
            Check(not c.AccountView._pages[page].lastError, "actual package page: " .. page)
        end
    else
        Check(not c:IsInitialized() and ready == 0 and e.YiboCoreRetailDB == nil, "actual player package misinstalled on other target stops writes")
    end
end
print("CoreRetailR2 PackageSpec passed: " .. checks .. " checks (actual extracted default-TOC package, UI and wrong-product protection)")
