-- Shared clean/overlay/API13/wrong-target replay for one Mists-only business addon.
-- Usage (from repo root): see each _NonRelease/<Addon>Release-20261122/PackagedReplay.lua
local H = dofile("_NonRelease/BusinessReleaseHarness-20261122/Harness.lua")

return function(cfg)
    local C = H.Checker(cfg.addon .. " packaged replay")
    local sections = {}
    local function Check(value, name)
        local root = tostring(name):match("^([^/:]+)") or "?"
        local section = name:find("/API13/") and "api13" or name:find("/wrong%-") and "wrong-target"
            or name:find("/reload") and "reload" or "install"
        local key = root .. "/" .. section
        sections[key] = sections[key] or { 0, 0 }
        if value then sections[key][1] = sections[key][1] + 1 else sections[key][2] = sections[key][2] + 1 end
        return C.Check(value, name)
    end
    local dir = cfg.dir
    local roots = cfg.roots or {
        { "clean", dir .. "/Clean-Mists/" .. cfg.addon },
        { "overlay", dir .. "/Overlay-Mists/" .. cfg.addon },
    }
    local cores = {
        Mists = dir .. "/Core-Mists/YiboCore", Forever = dir .. "/Core-Forever/YiboCore",
        Retail = dir .. "/Core-Retail/YiboCore", API13 = dir .. "/Core-Mists-API13/YiboCore",
    }
    local stats = { boots = 0 }
    local function Boot(opts)
        stats.boots = stats.boots + 1
        local ok, result = pcall(H.Boot, opts)
        if not ok then
            Check(false, (opts.tag or "?") .. ": boot raised " .. tostring(result))
            return nil
        end
        return result
    end
    local function NoErrors(r, tag)
        Check(#r.env.TEST_ERRORS == 0, tag .. "no handler errors " .. table.concat(r.env.TEST_ERRORS, " | "))
    end
    local function SVSnapshot(env)
        local out = {}
        for _, sv in ipairs(cfg.savedVariables) do out[sv] = H.Serialize(env[sv]) end
        return out
    end

    for _, root in ipairs(roots) do
        local kind, addonRoot = root[1], root[2]
        local _, meta = H.ReadToc(addonRoot .. "/" .. cfg.addon .. ".toc")
        Check(cfg.wrongOnly or meta.Version == cfg.version, kind .. ": TOC version " .. tostring(meta.Version))
        Check(meta.Interface == "50504", kind .. ": Interface " .. tostring(meta.Interface))

        -- 1. Fresh install and previous-version store, two client languages.
        for _, case in ipairs(cfg.wrongOnly and {} or { { "fresh", "zhCN" }, { "previous", "zhCN" }, { "previous", "enUS" } }) do
            local tag = kind .. "/" .. case[1] .. "/" .. case[2] .. ": "
            local saved = case[1] == "previous" and cfg.previousStore() or nil
            local r = Boot({ tag = tag, client = "Mists", coreRoot = cores.Mists, addonRoot = addonRoot, addon = cfg.addon, saved = saved, locale = case[2] })
            if r then
                local env, Core = r.env, r.Core
                Check(Core and Core:IsInitialized() and Core.VERSION == "1.13.0" and Core.API_VERSION == 14, tag .. "Core 1.13.0/API14 ready")
                Check(cfg.initialized(env), tag .. "addon initialized")
                Check(r.counts.RegisterAddon == 1, tag .. "RegisterAddon once (" .. r.counts.RegisterAddon .. ")")
                Check(r.counts.RegisterPage == 1, tag .. "RegisterPage once (" .. r.counts.RegisterPage .. ")")
                Check(r.counts.RegisterBusinessEntry == 1, tag .. "RegisterBusinessEntry once (" .. r.counts.RegisterBusinessEntry .. ")")
                local registered = Core.Registry and Core.Registry:Get(cfg.addon)
                Check(type(registered) == "table" and registered.version == cfg.version, tag .. "Core registry version " .. tostring(type(registered) == "table" and registered.version))
                -- Repeat lifecycle events and a direct initialize: no new registrations.
                local before = H.Serialize(r.counts)
                r.Event("ADDON_LOADED", cfg.addon); r.Event("PLAYER_LOGIN"); r.Event("PLAYER_ENTERING_WORLD", false, true); r.Flush()
                pcall(cfg.reinitialize, env)
                r.Flush()
                Check(H.Serialize(r.counts) == before and cfg.initialized(env), tag .. "repeat init does not re-register " .. H.Serialize(r.counts))
                if cfg.pageID then
                    local ok, err = pcall(function() Core.AccountView:ShowPage(cfg.pageID) end)
                    r.Flush()
                    local page = Core.AccountView._pages and Core.AccountView._pages[cfg.pageID]
                    Check(ok and not (page and page.lastError), tag .. "account page renders " .. tostring(err or (page and page.lastError)))
                end
                if case[1] == "previous" then
                    Check(cfg.preserved(env), tag .. "previous-version store preserved")
                    -- Reload: the saved tables written by this session boot again.
                    local copy = {}
                    for _, sv in ipairs(cfg.savedVariables) do copy[sv] = H.Copy(env[sv]) end
                    local coreCopy = H.Copy(env.YiboCoreDB)
                    local rr = Boot({ tag = tag .. "reload", client = "Mists", coreRoot = cores.Mists, addonRoot = addonRoot, addon = cfg.addon, saved = copy, coreSaved = coreCopy, locale = case[2] })
                    if rr then
                        Check(cfg.initialized(rr.env) and rr.counts.RegisterAddon == 1, tag .. "reload initializes once")
                        Check(cfg.preserved(rr.env), tag .. "store preserved after reload")
                        NoErrors(rr, tag .. "reload ")
                    end
                else
                    for _, sv in ipairs(cfg.createdOnFresh or {}) do Check(type(env[sv]) == "table", tag .. "fresh store created " .. sv) end
                end
                NoErrors(r, tag)
                Check(not H.HasMessage(env, cfg.upgradePatterns), tag .. "no upgrade message with API14 Core")
            end
        end

        -- 2. API13 Core (published Mists 1.12.14 package) is refused.
        for _, locale in ipairs(cfg.wrongOnly and {} or { "zhCN", "enUS" }) do
            local tag = kind .. "/API13/" .. locale .. ": "
            local saved = cfg.previousStore()
            local r = Boot({ tag = tag, client = "Mists", coreRoot = cores.API13, addonRoot = addonRoot, addon = cfg.addon, saved = saved, locale = locale })
            if r then
                Check(r.Core:IsInitialized() and r.Core.API_VERSION == 13, tag .. "API13 Core itself ready")
                Check(not cfg.initialized(r.env), tag .. "addon refused")
                Check(r.counts.RegisterAddon == 0 and r.counts.RegisterPage == 0 and r.counts.RegisterBusinessEntry == 0, tag .. "no registrations " .. H.Serialize(r.counts))
                local found, message = H.HasMessage(r.env, cfg.upgradePatterns)
                Check(found, tag .. "upgrade message shown")
                if found and locale == "enUS" then Check(not tostring(message):find("[\228-\233]"), tag .. "English upgrade text") end
                Check(cfg.preserved(r.env), tag .. "store kept when refused")
                NoErrors(r, tag)
            end
        end

        -- 3. Wrong client: Mists package installed on Forever/Retail with that
        --    client's Core, and on Forever with the Mists Core package.
        for _, wrong in ipairs({ { "Forever", cores.Forever }, { "Retail", cores.Retail }, { "Forever", cores.Mists, "mists-core" } }) do
            for _, storeKind in ipairs({ "none", "previous" }) do
                local tag = kind .. "/wrong-" .. wrong[1] .. (wrong[3] and ("/" .. wrong[3]) or "") .. "/" .. storeKind .. ": "
                local saved = storeKind == "previous" and cfg.previousStore() or nil
                local expected = H.Serialize(saved and H.Copy(saved) or {})
                local wrongLocale = cfg.wrongTargetPatterns and storeKind == "previous" and "enUS" or nil
                local r = Boot({ tag = tag, client = wrong[1], coreRoot = wrong[2], addonRoot = addonRoot, addon = cfg.addon, saved = saved, locale = wrongLocale })
                if r then
                    local after = {}
                    for _, sv in ipairs(cfg.savedVariables) do after[sv] = r.env[sv] end
                    local unchanged = true
                    for _, sv in ipairs(cfg.savedVariables) do
                        if H.Serialize(after[sv]) ~= H.Serialize((saved or {})[sv]) then unchanged = false end
                    end
                    Check(not cfg.initialized(r.env), tag .. "addon not initialized")
                    Check(r.counts.RegisterAddon == 0, tag .. "no Core registration " .. H.Serialize(r.counts))
                    Check(unchanged, tag .. "saved variables untouched")
                    NoErrors(r, tag)
                    -- Opt-in (2026-11-22 wrong-target fix): explicit stop message,
                    -- no page/entry/cleanup registration, and repeated lifecycle
                    -- events plus a direct Initialize still change nothing.
                    if cfg.wrongTargetPatterns then
                        Check(H.HasMessage(r.env, cfg.wrongTargetPatterns), tag .. "wrong-target message shown")
                        if wrongLocale == "enUS" then
                            local found, message = H.HasMessage(r.env, cfg.wrongTargetPatterns)
                            Check(found and not tostring(message):find("[\228-\233]"), tag .. "English wrong-target text")
                        end
                        Check(not H.HasMessage(r.env, cfg.upgradePatterns), tag .. "no misleading Core upgrade message")
                        local zero = r.counts.RegisterAddon == 0 and r.counts.RegisterPage == 0
                            and r.counts.RegisterBusinessEntry == 0 and r.counts.CleanupOwner == 0
                        Check(zero, tag .. "no page/entry/cleanup registration " .. H.Serialize(r.counts))
                        local messages = #r.env.TEST_MESSAGES
                        r.Event("ADDON_LOADED", cfg.addon); r.Event("PLAYER_LOGIN"); r.Event("PLAYER_ENTERING_WORLD", false, true); r.Flush()
                        local okInit, initResult = pcall(cfg.reinitialize, r.env)
                        r.Flush()
                        local still = true
                        for _, sv in ipairs(cfg.savedVariables) do
                            if H.Serialize(r.env[sv]) ~= H.Serialize((saved or {})[sv]) then still = false end
                        end
                        local none = r.counts.RegisterAddon == 0 and r.counts.RegisterPage == 0
                            and r.counts.RegisterBusinessEntry == 0 and r.counts.CleanupOwner == 0
                        Check(okInit and not initResult and still and none and not cfg.initialized(r.env),
                            tag .. "repeat events + direct Initialize refused " .. tostring(initResult) .. " " .. H.Serialize(r.counts))
                        Check(#r.env.TEST_MESSAGES == messages, tag .. "repeat events print no extra message")
                        NoErrors(r, tag .. "after repeat ")
                    end
                    stats.wrongDetail = stats.wrongDetail or {}
                end
            end
        end
    end
    print(string.format("%s: %d boots", cfg.addon, stats.boots))
    local keys = {}
    for key in pairs(sections) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do print(string.format("  section %-28s %d passed, %d failed", key, sections[key][1], sections[key][2])) end
    local ok = C.Report()
    return ok, C
end
