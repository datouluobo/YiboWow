-- Actual target manifests, synthetic client locales and in-memory preferences; no player data.
local Boot = dofile("_NonRelease/CoreForever/Harness.lua")
local checks = 0
local resourcesAudited = false
local function Check(value, label) checks = checks + 1; assert(value, label) end
local cases = {
    { "zhCN", "auto", "zh" }, { "zhTW", "auto", "zh" }, { "enUS", "auto", "en" },
    { "frFR", "auto", "en" }, { "zhCN", "en", "en" }, { "enUS", "zh", "zh" },
}
for _, forever in ipairs({ false, true }) do
    for _, case in ipairs(cases) do
        local nativeLocale, preference, language = unpack(case)
        local statusMode = "installed"
        local e, c, fire, flush = Boot(forever, { schemaVersion = 11, settings = { language = preference } }, nil, function(env)
            env.GetLocale = function() return nativeLocale end
            env.GetItemInfo = function() return "原文 Item", "item:1", nil, nil, nil, nil, nil, nil, nil, 123 end
            env.C_Container.GetContainerNumSlots = function() error("temporarily unavailable") end
            env.C_AddOns.GetAddOnInfo = function(name)
                if name == "YiboBuilds" then
                    if statusMode == "unavailable" then error("native query unavailable") end
                    if statusMode == "missing" then return nil end
                end
                return name
            end
            env.C_AddOns.GetAddOnMetadata = function(name)
                if name == "YiboBuilds" and statusMode == "version-missing" then return nil end
                return "2.3"
            end
            env.C_AddOns.GetAddOnEnableState = function() return 2 end
        end)
        local nativeLanguage = (nativeLocale == "zhCN" or nativeLocale == "zhTW") and "zh" or "en"
        Check(c.Locale:GetLanguage() == nativeLanguage and not c:IsInitialized(), "preflight text uses native language before trusted settings")
        local ready = 0
        c.Events:Register("CORE_READY", "Fixture", function(_, version)
            Check(c:IsInitialized() and version == c:GetVersion(), "ready payload is target version after commit")
            ready = ready + 1
        end)
        fire("ADDON_LOADED"); fire("PLAYER_LOGIN"); flush()
        Check(c:IsInitialized() and ready == 1 and c.Locale:GetLanguage() == language, "session language selected after preflight")
        Check(e.GetLocale() == nativeLocale and c.Locale:GetPreference() == preference, "native locale and saved preference independent")
        local catalog, bindings = c.AddonCatalog, #c.Locale.bindings
        c.Locale:Initialize(); Check(c:Initialize(), "repeat Core initialize succeeds")
        c.Locale:RefreshBindings()
        Check(c.AddonCatalog == catalog and #c.Locale.bindings == bindings and ready == 1, "locale binding identity and startup remain idempotent")
        local resources = c.Locale.resources.YiboCore
        if not resourcesAudited then
            for key in pairs(resources.zh) do
                Check(not key:find("[^ -~]") and type(resources.en[key]) == "string", "stable ASCII keys have English resources")
            end
            resourcesAudited = true
        end
        local technical = "fixture-domain"
        local message = c:Text("CORE.DOMAIN_INVALID_DATA", technical)
        Check(message:find(technical, 1, true) and not message:find("%%s"), "domain failure interpolates one complete sentence")
        local details = "native-error:42"
        Check(c:Text("CORE.INITIALIZATION_FAILED", details):find(details, 1, true), "startup detail retained without translation")
        Check(c.ItemResolver:GetInfo(1).name == "原文 Item", "dynamic native item name unchanged by plugin language")
        local values, failure = c.ItemResolver:Parse("原文 Item", { allowName = true, includeBags = true, candidates = { 1 } })
        Check(values == nil and failure == c:Text("CORE.ITEM_BAG_SEARCH_UNAVAILABLE"), "bag scope failure has specific localized message")
        c.PackagedAddonVersions = { YiboBuilds = "9.8" }
        local function About()
            c.AccountView:ShowPage("about"); flush()
            return c.AccountView.frame.instances.about.addonRowsByName.YiboBuilds
        end
        local row = About()
        Check(row.version:GetText() == c:Text("CORE.ADDON_INSTALLED_VERSION", "v2.3") .. " · " .. c:Text("CORE.ADDON_PACKAGED_VERSION", "v9.8"), "complete localized version labels")
        statusMode = "version-missing"; row = About()
        Check(row.version:GetText():find(c:Text("CORE.ADDON_VERSION_UNAVAILABLE"), 1, true) == 1, "known installation with unknown version not called missing")
        statusMode = "unavailable"; row = About()
        Check(row.version:GetText():find(c:Text("CORE.ADDON_STATUS_UNAVAILABLE"), 1, true) == 1
            and row.description:GetText():find(c:Text("CORE.ADDON_STATUS_UNAVAILABLE"), 1, true) == 1, "native query error not called uninstalled")
        statusMode = "missing"; row = About()
        Check(row.version:GetText():find(c:Text("CORE.NOT_INSTALLED_LOCALLY"), 1, true) == 1, "confirmed missing status retained")
        statusMode = "installed"; c:RegisterAddon("YiboBuilds", { requiredAPI = 13 }); row = About()
        Check(row.description:GetText():find(c:Text("CORE.ADDON_REGISTERED"), 1, true) == 1, "connected means registered with Core")
        Check(#c.Locale:GetMissingEnglish("YiboCore") == 0, "rendered Core paths have no missing resource")
        local otherLanguage = language == "zh" and "en" or "zh"
        Check(c.Locale:SetPreference(otherLanguage) and c.Locale:IsReloadPending(), "language preference waits for reload")
        c.Locale:Initialize()
        Check(c.Locale:GetLanguage() == language and e.GetLocale() == nativeLocale, "repeat locale init does not change live session")
        local reloadedEnv, reloaded, reloadFire = Boot(forever, c.Defaults:Copy(c.Database:GetDB()), nil, function(env)
            env.GetLocale = function() return nativeLocale end
        end)
        reloadFire("ADDON_LOADED")
        Check(reloaded:IsInitialized() and reloaded.Locale:GetLanguage() == otherLanguage and not reloaded.Locale:IsReloadPending()
            and reloadedEnv.GetLocale() == nativeLocale, "fresh simulated reload applies saved preference")
    end
end
print("CoreLocaleContractsR1 passed: " .. checks .. " checks (real Mists/Forever manifests, automatic/manual language and localized failure paths)")
