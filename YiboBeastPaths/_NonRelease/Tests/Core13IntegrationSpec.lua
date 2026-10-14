-- Optional Core contract: standalone, old/missing capabilities, late readiness,
-- idempotent registration, rollback, safe surface height, and owner resources.
local prints, frames = {}, {}
print = function(message) prints[#prints + 1] = message end
GetLocale = function() return "zhCN" end
CreateFrame = function()
    local frame = { RegisterEvent = function() end }
    function frame:SetScript(event, callback) self[event] = callback end
    frames[#frames + 1] = frame
    return frame
end
local checks = 0
local function check(value, message) checks = checks + 1; assert(value, message) end
local function scenario(options)
    options = options or {}
    local ns, pages, settings, callbacks = { IS_MISTS = options.mists ~= false }, {}, {}, {}
    local counts = { addons = 0, panels = 0, pages = 0, shown = 0, removed = 0 }
    local ybp = { enabled = false }
    _G.YiboBeastPaths = ybp
    function ybp:IsDebugEnabled() return self.enabled end
    function ybp:SetDebugEnabled(enabled) self.enabled = enabled end
    function ybp:RefreshWorldMapButton() end
    local core
    if not options.absent then
        core = { ready = options.ready ~= false, api = options.api or 13,
            Registry = {}, SettingsRegistry = {}, UITheme = {}, AccountView = {}, Events = {},
            Capabilities = { Register = function() end } }
        function core:CheckAPIVersion(version) return self.api >= version end
        function core:IsInitialized() return self.ready end
        function core:HasCapability(name) return name ~= options.missing end
        for _, key in ipairs({ "CreateInput", "CreateScrollFrame", "CreateButton", "CreateText" }) do
            core.UITheme[key] = function() end
        end
        function core:RegisterAddon(_, metadata)
            check(metadata.requiredAPI == 13)
            counts.addons = counts.addons + 1; return {}
        end
        function core:RegisterSettingsPanel(_, definition)
            counts.panels = counts.panels + 1; settings[definition.id] = definition; return definition
        end
        function core.AccountView:RegisterPage(_, definition)
            counts.pages = counts.pages + 1
            if options.rejectPage then return nil, "page-rejected" end
            pages[definition.id] = definition; return definition
        end
        function core.AccountView:UnregisterPage(id)
            counts.removed = counts.removed + 1; pages[id] = nil
        end
        function core.AccountView:ShowPage() counts.shown = counts.shown + 1 end
        function core.AccountView:ShowSettings() counts.shown = counts.shown + 1 end
        function core.AccountView:RefreshPage() end
        function core.AccountView:NotifyPageChanged() end
        function core.Events:Register(event, owner, callback) callbacks[event] = callback end
        function core.Events:Unregister(event) callbacks[event] = nil end
    end
    _G.YiboCore = core
    if core then
        assert(loadfile("YiboCore/Runtime/Locale.lua"))()
        core.Locale.language = "en" -- manual English on a Chinese client
    end
    assert(loadfile("YiboBeastPaths/Locale.lua"))("YiboBeastPaths", ns)
    assert(loadfile("YiboBeastPaths/Maintenance/CoreDebugAdapter.lua"))("YiboBeastPaths", ns)
    local init = frames[#frames]
    init.OnEvent(init, "ADDON_LOADED", "YiboBeastPaths")
    return ybp, core, ns, counts, settings, pages, callbacks, init
end
for _, options in ipairs({ { absent = true }, { api = 6 }, { missing = "basic-input" },
    { missing = "account-view" }, { missing = "localization" }, { missing = "account-surface-budget" },
    { mists = false } }) do
    local ybp, _, ns, counts = scenario(options)
    check(not ybp:OpenCoreRouteMaintenance())
    check(counts.addons == 0 and counts.panels == 0 and counts.pages == 0)
    check(type(ns.Text("TITLE")) == "string")
end
local ybp, core, ns, counts, settings, pages, callbacks, init = scenario({ ready = false })
check(counts.addons == 0)
check(callbacks.CORE_READY ~= nil)
core.ready = true
callbacks.CORE_READY()
check(callbacks.CORE_READY == nil)
check(counts.addons == 1 and counts.panels == 1 and counts.pages == 0)
check(ns.Text("TITLE") == "Beast Paths", "Core session language must win over client locale")
check(ybp:OpenCoreRouteMaintenance())
for i = 1, 3 do init.OnEvent(init, "PLAYER_LOGIN") end
check(counts.addons == 1 and counts.panels == 1)
-- Use settings callbacks to exercise enable/disable, exactly as the player does.
local buttons = {}
core.UITheme.Font, core.UITheme.Colors = { assist = 12 }, { muted = {} }
local widget = { SetPoint = function() end, SetWordWrap = function() end, SetText = function() end }
function core.UITheme:CreateText() return widget end
function core.UITheme:CreateButton()
    local button = { SetPoint = function() end, SetEnabled = function() end }
    function button:SetScript(_, callback) self.click = callback end
    buttons[#buttons + 1] = button
    return button
end
local row = { GetWidth = function() return 560 end, SetHeight = function() end }
local host = { createSection = function() return widget end }
settings['yibo-beastpaths'].CreateSettingsPanel(row, host)
buttons[1].click()
check(ybp.enabled and counts.pages == 1)
local page = pages['yibo-beastpaths-route-maintenance']
check(page.title == "Beast Paths")
check(page.GetSurfaceMetrics({ surfaceAvailableHeight = 280 }).naturalContentHeight == 280)
check(page.GetSurfaceMetrics({ surfaceAvailableHeight = 900 }).naturalContentHeight == 720)
check(ybp:OpenCoreRouteMaintenance() and counts.pages == 1)
buttons[1].click()
check(not ybp.enabled and counts.removed == 1)
buttons[1].click()
check(ybp.enabled and counts.pages == 2)
-- Registration failure must restore the safe disabled state.
ybp, core, ns, counts, settings = scenario({ rejectPage = true })
buttons = {}
core.UITheme.Font, core.UITheme.Colors = { assist = 12 }, { muted = {} }
function core.UITheme:CreateText() return widget end
function core.UITheme:CreateButton()
    local button = { SetPoint = function() end, SetEnabled = function() end }
    function button:SetScript(_, callback) self.click = callback end
    buttons[#buttons + 1] = button; return button
end
settings['yibo-beastpaths'].CreateSettingsPanel({ GetWidth = row.GetWidth, SetHeight = row.SetHeight }, host)
buttons[1].click()
check(not ybp.enabled and counts.shown == 0)
-- All catalog keys have matching formats and no missing English resources.
local function formats(text)
    local result = {}; for value in text:gmatch('%%[-+ #0%d%.]*[cdiouxXeEfgGqs]') do result[#result + 1] = value end
    return table.concat(result, ',')
end
for key, value in pairs(ns.LocaleResources.zh) do
    check(key:match('^[A-Z0-9_]+$'))
    check(ns.LocaleResources.en[key] ~= nil)
    check(formats(value) == formats(ns.LocaleResources.en[key]), key)
end
io.write('Core13IntegrationSpec: ', checks, ' checks passed\n')
