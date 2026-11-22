local BootCore = dofile("_NonRelease/CoreForever/Harness.lua")
local checks = 0
local function Check(value, label)
    checks = checks + 1
    assert(value, label)
end

local function Boot(forever, manifest, configure, saved)
    local e, core, fire, flush, load = BootCore(forever)
    getmetatable(e.UIParent).__index.GetRegions = function() end
    e.TEST_GUID = "Player-Test-1"
    e.GetServerTime = function() return 200000 end
    e.WOW_PROJECT_MISTS_CLASSIC = 19
    if not forever then
        e.GetInstanceInfo = function() return nil, "none" end
        getmetatable(e.UIParent).__index.UnregisterAllEvents = function(frame) frame.events = {} end
    end
    e.YiboAltoBossForeverDB = saved
    e.YiboAltoBossDB = { sentinel = "mists" }
    fire("ADDON_LOADED")
    if configure then configure(e, core) end
    local packageRoot = manifest == "YiboAltoBoss_Mists" and arg[1] or manifest == "YiboAltoBoss_Forever" and arg[2]
    local root = packageRoot and (packageRoot .. "/") or "YiboAltoBoss/"
    if packageRoot then manifest = "YiboAltoBoss" end
    for line in io.lines(root .. manifest .. ".toc") do
        if line:match("%.lua$") then load(root .. line:gsub("\\", "/"), "YiboAltoBoss") end
    end
    fire("ADDON_LOADED", "YiboAltoBoss")
    fire("PLAYER_LOGIN")
    flush()
    return e, core, fire, flush
end

local e, core, fire, flush = Boot(true, "YiboAltoBoss_Forever", function(env)
    env.GetNumSavedInstances = function() error("unexpected instance acquisition") end
    env.CombatLogGetCurrentEventInfo = function() error("unexpected combat acquisition") end
end)
local addon = e.YAB
Check(addon.initialized and addon.Version == "0.2.0", "Forever initializes through its actual TOC")
Check(e.YiboAltoBossDB.sentinel == "mists" and not e.YiboAltoBossDB.settings, "old Mists store is untouched")
Check(core.AccountView._pages["alto-custom"] and core.AccountView._pages["alto-lockouts"]
    and not core.AccountView._pages["alto-boss"], "only enabled business pages are registered")
Check(next(addon.Store.db.instances) == nil and next(addon.Store.db.instanceSnapshots) == nil, "starts with unknown instance coverage")
local entry = core.Entry.businessEntries.yab
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD")
fire("UPDATE_INSTANCE_INFO")
fire("COMBAT_LOG_EVENT_UNFILTERED")
Check(entry and core.Entry.businessEntries.yab == entry, "duplicate login and native events do not register or scan")

e.SlashCmdList.YIBOALTOBOSS("")
flush()
local view = core.AccountView
local panel = view.frame.instances["alto-custom"]
Check(panel and panel.empty:GetText() == addon.Text("FOREVER.ADD_TARGETS"), "custom page displays empty directory state")
view:ShowSettings("alto-custom")
flush()
local editor
for _, frame in ipairs(e.TEST_FRAMES) do
    if frame.yabSettingsPanel then editor = frame.yabSettingsPanel; break end
end
Check(editor and editor.npcInput, "Core settings opens shared target editor")
editor.npcInput:SetValue("123")
for _, button in ipairs(e.TEST_FRAMES) do
    if button:GetParent() == editor.custom and button.label and button.label:GetText() == addon.Text("UI.ADD") then
        button.scripts.OnClick(button)
        break
    end
end
Check(addon.Store.db.customTargets["123"].key == "custom:123", "editing stores a stable target key")
view:ShowPage("alto-custom")
flush()
local cell = panel.rows[1].cells[1]
Check(cell.text:GetText() == addon.Text("FOREVER.NOT_MARKED"), "never observed is shown as unmarked")
cell.scripts.OnClick(cell)
flush()
local id = core.Characters:GetCurrentID()
Check(addon.Store:Mark(id, "custom:123").source == "manual", "click records the current Core character")
Check(cell.text:GetText() == addon.Text("FOREVER.MANUAL_MARK"), "record renders immediately")
view.frame:Hide()
Check(view:ShowPreview("alto-custom", e.Minimap), "Core preview opens")
local preview = view.frame.instances["alto-custom"].rows[1].cells[1]
Check(preview.text:GetText() == cell.text:GetText() and preview.scripts.OnClick == nil, "preview uses the same record and has no write action")
view:HidePreview()
local saved = core.Defaults:Copy(e.YiboAltoBossForeverDB)
view:ShowPage("alto-custom")
cell = view.frame.instances["alto-custom"].rows[1].cells[1]
cell.scripts.OnClick(cell)
Check(not addon.Store:Mark(id, "custom:123"), "second click revokes the mark")
view:ShowPage("alto-lockouts")
flush()
local instances = view.frame.instances["alto-lockouts"]
Check(instances and instances.empty:GetText() == addon.Text("FOREVER.NO_INSTANCE_DATA"), "instance page distinguishes uncollected state")

local lockout = { key = "41:2", bossCount = 2, bosses = { { killed = true }, {} }, resetAt = 200001 }
Check(addon.InstanceProgress:Status({ lockouts = {} }, lockout, 200000) == "unknown", "partial coverage does not imply open")
Check(addon.InstanceProgress:Status({ lockouts = {}, coverage = "complete" }, lockout, 200000) == "open", "confirmed coverage can show open")
local snapshot = { lockouts = { [lockout.key] = lockout }, coverage = "complete" }
Check(addon.InstanceProgress:Status(snapshot, lockout, 200000) == "locked", "normalized lockout renders")
Check(addon.InstanceProgress:Status(snapshot, lockout, 200002) == "unknown", "expired lockout is not shown as current")
local observedRun = { lockouts = {}, runs = { [lockout.key] = { bossCount = 2, bosses = { { killed = true } } } } }
Check(addon.InstanceProgress:Status(observedRun, lockout, 200000) == "progress", "unlocked current run is separate from saved lockouts")

local restored, restoredCore = Boot(true, "YiboAltoBoss_Forever", nil, saved)
local restoredID = restoredCore.Characters:GetCurrentID()
Check(restored.YAB.Store:Mark(restoredID, "custom:123").updatedAt == 200000, "saved mark restores")
Check(restored.YAB.Store:RemoveTarget(123) and not restored.YAB.Store:Mark(restoredID, "custom:123"), "target removal clears its marks")
for _, manifest in ipairs({ "YiboAltoBoss_Mists", "YiboAltoBoss" }) do
    local wrong = Boot(true, manifest)
    Check(not wrong.YiboAltoBossDB.settings and not wrong.YiboAltoBossForeverDB
        and not wrong.SlashCmdList.YIBOALTOBOSS, "wrong target or hint cannot initialize business")
end
local wrongForever = Boot(false, "YiboAltoBoss_Forever")
Check(not wrongForever.YiboAltoBossForeverDB and not wrongForever.SlashCmdList.YIBOALTOBOSS, "wrong Forever target stops before write")
local mists, mistsCore, mistsFire = Boot(false, "YiboAltoBoss_Mists", function(env)
    env.YiboAltoBossDB.settings = { normalInstanceLimit = 7, accountPage = "lockouts" }
    env.YiboAltoBossDB.customTargets = { ["456"] = { id = 456, name = "Existing target" } }
end)
Check(mists.YAB.CoreIntegration.initialized and mistsCore.AccountView._pages["alto-boss"]
    and mistsCore.AccountView._pages["alto-lockouts"], "Mists initializes its existing pages through the new TOC")
Check(mists.YiboAltoBossDB.settings.normalInstanceLimit == 7 and mists.YiboAltoBossDB.settings.accountPage == "lockouts"
    and mists.YiboAltoBossDB.customTargets["456"].name == "Existing target" and not mists.YiboAltoBossForeverDB,
    "existing Mists settings and custom targets survive the new manifest")
local mistsEntry = mistsCore.Entry.businessEntries.yab
mistsFire("ADDON_LOADED", "YiboAltoBoss")
mistsFire("PLAYER_LOGIN")
Check(mistsEntry and mistsCore.Entry.businessEntries.yab == mistsEntry, "Mists does not register twice")
local noCore = Boot(true, "YiboAltoBoss_Forever", function(_, core)
    core.IsInitialized = function() return false end
end)
Check(not noCore.YiboAltoBossForeverDB and not noCore.SlashCmdList.YIBOALTOBOSS, "unready Core stops before write")
local oldCore = Boot(true, "YiboAltoBoss_Forever", function(_, core)
    local hasCapability = core.HasCapability
    core.HasCapability = function(self, name, version)
        return name ~= "account-surface-budget" and hasCapability(self, name, version)
    end
end)
Check(not oldCore.YiboAltoBossForeverDB and not oldCore.SlashCmdList.YIBOALTOBOSS, "missing capability stops before write")
local api13Core = Boot(true, "YiboAltoBoss_Forever", function(_, core)
    core.CheckAPIVersion = function(_, minimum) return minimum <= 13 end
end)
Check(not api13Core.YiboAltoBossForeverDB and not api13Core.SlashCmdList.YIBOALTOBOSS, "API13 Core is refused by Forever before write")
print("MultiTargetSpec: " .. checks .. " checks passed")
