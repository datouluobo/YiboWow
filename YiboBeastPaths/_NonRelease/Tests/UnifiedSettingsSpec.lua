local Boot = dofile("_NonRelease/CoreRetailR2/Harness.lua")
for _, target in ipairs({ "Retail", "Mists" }) do
    local env, core, fire, flush = Boot(target)
    env.WOW_PROJECT_MISTS_CLASSIC = 19
    fire("ADDON_LOADED"); fire("PLAYER_LOGIN"); flush()
    local ns = { YBP_TARGET_OK = true, IS_RETAIL = target == "Retail", IS_MISTS = target == "Mists" }
    env.YiboBeastPathsDebugDB = { ui = { activeTab = "calibrate", stepMove = .005, stepScale = .01,
        footprintListOffset = 0, exportView = "current" } }
    local ybp = { RefreshWorldMapButton = function() end, InitDebugDB = function() end }
    env.YiboBeastPaths = ybp
    function ybp:GetActiveDebugTab() return env.YiboBeastPathsDebugDB.ui.activeTab end
    function ybp:SetActiveDebugTab(tab) env.YiboBeastPathsDebugDB.ui.activeTab = tab; self:RefreshDebugPanel() end
    function ybp:GetDebugPetIDsForCurrentMap() return {} end
    function ybp:GetSelectedDebugPetID() end
    function ybp:GetCurrentWorldMapID() end
    function ybp:GetDebugExportView() return "current" end
    function ybp:GetDebugExportText() return "fixture" end
    function ybp:GetRouteDisplaySettings() return {} end
    for _, file in ipairs({ "Locale.lua", "Maintenance/CoreDebugView.lua" }) do
        local chunk = assert(loadfile("YiboBeastPaths/" .. file))
        setfenv(chunk, env); chunk("YiboBeastPaths", ns)
    end
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
    -- Exercise the actual business settings host, including its scroll-height
    -- accounting when a short tab replaces a long one and vice versa.
    assert(core.AccountView:ShowSettings("yibo-beastpaths-offline-pets"))
    local parent = env.CreateFrame("Frame")
    parent:SetWidth(600)
    local refreshes, host = 0, {}
    host.createSection = function(row) return env.CreateFrame("Frame", nil, row) end
    host.refreshPanel = function()
        refreshes = refreshes + 1
        assert(refreshes < 30, "settings layout must not recurse")
        parent:SetHeight(ns.CreateMaintenanceSettingsPanel(parent, host))
    end
    local height = ns.CreateMaintenanceSettingsPanel(parent, host)
    parent:SetHeight(height)
    local section = parent.yiboBeastPathsSettings
    local panel = section.debugPanel
    assert(section.content and not section.scroll)
    assert(panel.hostedSettings and panel:GetWidth() == 600)
    for _, tab in ipairs({ "fusion", "footprints", "export", "calibrate" }) do
        ybp:SetActiveDebugTab(tab)
        assert(panel.tabs[tab].frame:IsShown())
            assert(parent:GetHeight() == panel:GetHeight() + 8)
    end
    assert(refreshes > 0)
    ns.CreateMaintenanceSettingsPanel(parent, host)
    assert(parent.yiboBeastPathsSettings == section and section.debugPanel == panel)
    local cleared = 0
    ybp.CancelCoreDebugInteraction = function() cleared = cleared + 1 end
    section:Hide()
    assert(cleared == 1)
    assert(core.AccountView._pages["yibo-beastpaths-route-maintenance"] == nil)
end
print("UnifiedSettingsSpec: hosted maintenance, tab heights, reuse and one settings source on both targets")
