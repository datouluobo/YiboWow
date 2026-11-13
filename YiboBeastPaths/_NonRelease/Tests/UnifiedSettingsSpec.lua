local Boot = dofile("_NonRelease/CoreRetailR2/Harness.lua")
for _, target in ipairs({ "Retail", "Mists" }) do
    local env, core, fire, flush = Boot(target)
    env.WOW_PROJECT_MISTS_CLASSIC = 19
    fire("ADDON_LOADED"); fire("PLAYER_LOGIN"); flush()
    local ns = { YBP_TARGET_OK = true, IS_RETAIL = target == "Retail", IS_MISTS = target == "Mists" }
    ns.Text = function(key) return key end
    ns.RegisterLocale = function() return true end
    env.YiboBeastPaths = { RefreshWorldMapButton = function() end, InitDebugDB = function() end }
    for _, name in ipairs({ "OfflinePetSnapshot", "OfflinePetCoreGate", "OfflinePetPage" }) do
        local chunk = assert(loadfile("YiboBeastPaths/Common/" .. name .. ".lua"))
        setfenv(chunk, env); chunk("YiboBeastPaths", ns)
    end
    local adapter = assert(loadfile("YiboBeastPaths/Maintenance/CoreDebugAdapter.lua"))
    setfenv(adapter, env); adapter("YiboBeastPaths", ns)
    fire("ADDON_LOADED", "YiboBeastPaths")
    local page = ns.OfflinePetPage.New(core, {}, target, {
        Create = function() end, Refresh = function() end, GetSurfaceMetrics = function() return {} end,
    }, ns.Text)
    assert(page:Start() and page:Start())
    local pageCount, panelCount = 0, 0
    for _, entry in ipairs(core.AccountView:GetRegisteredPages()) do
        if entry.addonName == "YiboBeastPaths" then
            pageCount = pageCount + 1
            assert(entry.settings and entry.settings.CreateSettingsPanel == ns.CreateMaintenanceSettingsPanel)
        end
    end
    for _, entry in ipairs(core:GetRegisteredSettingsPanels()) do
        if entry.addonName == "YiboBeastPaths" then panelCount = panelCount + 1 end
    end
    assert(pageCount == 1 and panelCount == 0)
end
print("UnifiedSettingsSpec: one YBP settings navigation source on both targets")
