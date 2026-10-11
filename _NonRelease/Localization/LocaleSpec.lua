-- Run from the repository root with Lua 5.1.
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    assert(actual == expected, (label or "value") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local client, saved = "enUS", nil
local callbacks = {}
function CreateFrame()
    local frame = { SetScript = function(self, event, callback) self[event] = callback end }
    for _, method in ipairs({ "RegisterEvent", "SetSize", "SetFrameStrata", "RegisterForClicks", "SetMovable", "EnableMouse", "RegisterForDrag", "SetTexture", "SetAllPoints", "SetPoint", "ClearAllPoints", "SetShown", "StartMoving", "StopMovingOrSizing" }) do
        frame[method] = function() end
    end
    frame.CreateTexture = function() return CreateFrame() end
    return frame
end
GetLocale = function() return client end
GetServerTime = function() return 1000 end
StaticPopupDialogs = {}
SlashCmdList = {}
local function Load(clientLocale, preference)
    client = clientLocale
    _G.YiboCore, _G.YiboCoreDB = nil, nil
    StaticPopupDialogs = {}
    for line in io.lines("YiboCore/YiboCore.toc") do
        local path = line:match("^([^#].*%.lua)%s*$")
        if path then dofile("YiboCore/" .. path:gsub("\\", "/")) end
    end
    -- WoW restores SavedVariables before ADDON_LOADED, after file execution.
    _G.YiboCoreDB = saved or { settings = { language = preference } }
    local core = YiboCore
    core.Characters.RefreshCurrent = function() return true end
    local initialized = false
    core.Events:Register("CORE_READY", "test", function()
        initialized = true
        Equal(core.Locale.initialized, true, "locale ready before consumers")
    end)
    assert(core:Initialize())
    Equal(initialized, true, "ready event")
    return core
end
for _, test in ipairs({
    { "zhCN", nil, "zh" }, { "zhTW", "auto", "zh" },
    { "enUS", "auto", "en" }, { "enGB", "auto", "en" },
    { "deDE", "auto", "en" }, { "koKR", "auto", "en" },
    { "zhCN", "en", "en" }, { "enUS", "zh", "zh" },
    { "zhTW", "invalid", "zh" }, { "enUS", false, "en" },
}) do
    local core = Load(test[1], test[2])
    local english = test[3] == "en"
    Equal(core.Locale:GetLanguage(), test[3], "effective language")
    Equal(core:HasCapability("localization", 1), true)
    Equal(core:HasCapability("localization", 2), false)
    Equal(core.AccountView._pages.settings.title, english and "Settings" or "设置", "static page metadata")
    Equal(core.Fields._definitions["character.level"].title, english and "Level" or "等级", "field metadata")
    Equal(core.Resources:Get("money").title, english and "Gold" or "金币", "resource metadata")
    Equal(core.AddonCatalog[1].title, english and "Boss Tracker" or "首领追踪", "catalog")
    Equal(core.UITheme.StatusText.error, english and "Error" or "错误", "status labels")
    Equal(core.AccountView._internal.SORT_LABELS.name, english and "Character name" or "角色名称", "captured label table")
    Equal(StaticPopupDialogs.YIBOCORE_DELETE_CHARACTER_CACHE.button2, english and "Cancel" or "取消", "confirmation metadata")
    Equal(#core.Locale:GetMissingEnglish(), 0, "complete Core resources")
    Equal(core.Locale:IsReloadPending(), false)
end

local core = Load("zhCN", "auto")
local catalog, labels = core.AddonCatalog, core.AccountView._internal.SORT_LABELS
Equal(core.Locale:SetPreference("en"), true)
Equal(core.Locale:GetPreference(), "en", "saved mode")
Equal(core.Locale:GetLanguage(), "zh", "session stays unchanged")
Equal(core.AccountView._pages.settings.title, "设置", "metadata stays unchanged")
Equal(core.Locale:IsReloadPending(), true)
Equal(core.Locale:SetPreference("auto"), true)
Equal(core.Locale:IsReloadPending(), false, "reverting choice clears pending")
Equal(core.Locale:SetPreference("garbage"), false)
Equal(core.Locale:GetPreference(), "auto", "invalid input preserves preference")
core.Locale:SetPreference("en")
saved = core.db
saved.characters.byID.custom = { name = "玩家短名", profile = { zone = "历史地点" } }
core = Load("zhCN", "auto")
Equal(core.Locale:GetLanguage(), "en", "reload applies saved mode across characters")
Equal(core.db.characters.byID.custom.profile.zone, "历史地点", "historical display data unchanged")
Equal(core.db.characters.byID.custom.name, "玩家短名", "custom text unchanged")
Equal(core.Locale:IsReloadPending(), false)
saved = nil

core.Locale:Register("Test", "zh", { FALLBACK = "中文回退", FORMAT = "数量：%d", BROKEN = "数量：%d" })
core.Locale:Register("Test", "en", { FORMAT = "Count: %d", BROKEN = "Count: %q %q" })
Equal(core.Locale:Get("Test", "FALLBACK"), "中文回退", "missing English fallback")
Equal(core.Locale:Get("Test", "FORMAT", 42), "Count: 42", "format interpolation")
Equal(core.Locale:Get("Test", "BROKEN", 42), "数量：42", "bad English formatting fallback")
Equal(core.Locale:Get("Test", "MISSING"), "[Test:MISSING]", "unknown keys are diagnosable")
Equal(#core.Locale:GetMissingEnglish("Test"), 2, "missing report")
core.Locale:Register("Test", "en", { FALLBACK = "Fallback" })
Equal(core.Locale:Get("Test", "FALLBACK"), "Fallback", "late registration")
Equal(#core.Locale:GetMissingEnglish("Test"), 1, "late translation clears missing report")
local ok = pcall(function() core.Locale:Register("Test", "en", { FORMAT = "Conflicting" }) end)
Equal(ok, false, "conflicting registration rejected")

-- Native profession matching must ignore the plugin language override.
local names = { "Alchemy", "锻造", "附魔" }
GetNumSkillLines = function() return #names end
GetSkillLineInfo = function(i) return names[i], false, nil, 525, nil, nil, 600 end
GetProfessions = function() return nil, nil end
GetProfessionInfo = function() end
local data, state = core.DataDomains._definitions.professions.Collect()
Equal(state, "known")
Equal(data.primaryProfessions[1].id, 171, "stable profession identity")
Equal(data.primaryProfessions[1].name, "Alchemy", "API name retained")
Equal(data.primaryProfessions[2].id, 164, "native alias retained")

-- Probe overrides are isolated from the account preference and end on reset.
local preference, formalLanguage = core.Locale:GetPreference(), core.Locale:GetLanguage()
local originalShow = core.AccountView.ShowPage
core.AccountView.ShowPage = function() return true end
dofile("_NonRelease/YiboLocaleProbe/Probe.lua")
Equal(SLASH_YIBOLOCALEPROBE1, "/ylp", "unique three-letter probe command")
SlashCmdList.YIBOLOCALEPROBE("zh")
Equal(core.Locale:GetLanguage(), "zh", "probe overrides formal language")
Equal(core.Locale:GetPreference(), preference, "probe does not save preference")
SlashCmdList.YIBOLOCALEPROBE("en")
Equal(core.Locale:GetLanguage(), "en")
SlashCmdList.YIBOLOCALEPROBE("reset")
Equal(core.Locale:GetLanguage(), formalLanguage, "probe reset restores formal session")
Equal(core.Locale:GetPreference(), preference)
core.AccountView.ShowPage = originalShow

print("LocaleSpec passed: " .. checks .. " checks")
