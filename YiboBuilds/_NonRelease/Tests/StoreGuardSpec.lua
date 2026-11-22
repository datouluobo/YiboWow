-- Run from repository root: lua YiboBuilds/_NonRelease/Tests/StoreGuardSpec.lua
-- Release fix 2026-11-22 (Mists 1.6.0): YiboBuildsDB must stay byte-identical when the
-- Mists manifest is refused (API13 Core, or installed on Forever); defaults are filled
-- only after Core passed. Loads the real YiboBuilds_Mists.toc in order with the addon name.
local Setup = dofile("YiboBuilds/_NonRelease/Tests/Core13Host.lua")
local checks = 0
local function Check(value, message) checks = checks + 1; assert(value, message) end
local function Serialize(value)
    if type(value) == "string" then return string.format("%q", value) end
    if type(value) ~= "table" then return tostring(value) end
    local keys, parts = {}, { "{" }
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, key in ipairs(keys) do parts[#parts + 1] = "[" .. Serialize(key) .. "]=" .. Serialize(value[key]) .. "," end
    return table.concat(parts) .. "}"
end
local function Existing()
    return { schemaVersion = 1, marker = "keep", characters = { ["Player-1"] = { lastActiveSlot = "primary", slots = {} } },
        settings = { appearanceMode = "prototype", previewColumns = { spec = false } } }
end
local messages
local function LoadManifest()
    local files = 0
    for line in io.lines("YiboBuilds/YiboBuilds_Mists.toc") do
        local path = line:gsub("\r", ""):match("^([^#].-%.lua)%s*$")
        if path then assert(loadfile("YiboBuilds/" .. path:gsub("\\", "/")))("YiboBuilds"); files = files + 1 end
    end
    return files
end
local function Globals()
    messages = {}
    DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) messages[#messages + 1] = text end }
    GetLocale = function() return "enUS" end
    C_Timer = { After = function() end }
    SlashCmdList = {}
end

-- 1. API13 Core: ADDON_LOADED and PLAYER_LOGIN refuse; existing and missing stores untouched.
for _, existing in ipairs({ Existing(), false }) do
    Globals()
    local host = Setup("en"); host.api = 13
    YiboBuildsDB = existing or nil
    local before = Serialize(YiboBuildsDB)
    Check(LoadManifest() > 0, "Mists manifest loaded")
    host.onEvent(nil, "ADDON_LOADED", "YiboBuilds")
    host.onEvent(nil, "PLAYER_LOGIN")
    Check(not YiboBuilds.CoreIntegration.initialized and host.addonRegistrations == 0 and host.pages == 0, "API13 Core refused before registration")
    Check(Serialize(YiboBuildsDB) == before and (existing == false and YiboBuildsDB == nil or YiboBuildsDB == existing),
        "API13 Core leaves YiboBuildsDB byte-identical (" .. (existing and "existing" or "missing") .. " store)")
    Check(#messages == 1 and messages[1]:find("API14", 1, true), "API13 upgrade message: " .. tostring(messages[1]))
end

-- 2. Compatible Core: ADDON_LOADED still does not write; PLAYER_LOGIN initializes once and fills defaults.
do
    Globals()
    local host = Setup("en")
    local existing = Existing()
    YiboBuildsDB = existing
    local before = Serialize(existing)
    LoadManifest()
    host.onEvent(nil, "ADDON_LOADED", "YiboBuilds")
    Check(Serialize(existing) == before, "ADDON_LOADED alone does not write the store")
    host.onEvent(nil, "PLAYER_LOGIN")
    Check(YiboBuilds.CoreIntegration.initialized and host.addonRegistrations == 1 and host.pages == 1 and host.entries == 1, "API14 Core initializes once")
    Check(YiboBuildsDB == existing and existing.marker == "keep" and existing.settings.appearanceMode == "prototype"
        and existing.settings.previewColumns.spec == false and existing.settings.previewColumns.talent1 == true
        and existing.characters["Player-1"] ~= nil, "defaults filled after Core check, existing data kept")
    host.onEvent(nil, "ADDON_LOADED", "YiboBuilds"); host.onEvent(nil, "PLAYER_LOGIN")
    Check(host.addonRegistrations == 1 and host.pages == 1 and host.entries == 1 and #messages == 0, "repeat events do not re-register")
end

-- 3. Mists package on the Forever client: one install notice, no frame, no Core query, store untouched.
for _, locale in ipairs({ "enUS", "zhCN" }) do
    Globals()
    GetLocale = function() return locale end
    WOW_PROJECT_CAMELOT, WOW_PROJECT_ID = 99, 99
    YiboBuilds = nil
    local existing = Existing()
    YiboBuildsDB = existing
    local before = Serialize(existing)
    YiboCore = setmetatable({}, { __index = function() error("Mists queried Core on Forever") end })
    local createFrame = CreateFrame
    CreateFrame = function() error("Mists registered a frame on Forever") end
    Check(LoadManifest() > 0, "Mists manifest loaded on Forever")
    Check(YiboBuildsDB == existing and Serialize(existing) == before, "wrong target leaves YiboBuildsDB byte-identical (" .. locale .. ")")
    Check(not YiboBuilds.Snapshot and not YiboBuilds.AccountPage and not YiboBuilds.Gems
        and not (YiboBuilds.CoreIntegration and YiboBuilds.CoreIntegration.initialized), "wrong target loads no business modules")
    Check(#messages == 1 and messages[1]:find("YiboBuilds", 1, true)
        and (locale == "zhCN" and messages[1]:find("熊猫人之谜", 1, true) or locale ~= "zhCN" and messages[1]:find("Install the YiboBuilds package", 1, true)),
        "wrong target prints one install notice: " .. tostring(messages[1]))
    CreateFrame = createFrame
    WOW_PROJECT_CAMELOT, WOW_PROJECT_ID = nil, nil
end
print("YiboBuilds StoreGuardSpec passed: " .. checks .. " checks")
