local Boot = dofile("_NonRelease/VaultForever/Smoke.lua")
local checks = 0
local function Check(value, label) checks = checks + 1; assert(value, label) end

-- MoP errors must preserve each container's last committed snapshot.
local bank = { failSlot = false, failSize = false, quantity = 5 }
local e, core, v, event, flush, data = Boot(nil, nil, function(env)
    local slots = env.C_Container.GetContainerNumSlots
    local items = env.C_Container.GetContainerItemInfo
    local free = env.C_Container.GetContainerNumFreeSlots
    env.C_Container.GetContainerNumSlots = function(id)
        if id == -1 then
            if bank.failSize then error("bank-size-failed") end
            return 2
        end
        if id >= 5 then return 0 end
        return slots(id)
    end
    env.C_Container.GetContainerItemInfo = function(id, slot)
        if id == -1 then
            if bank.failSlot and slot == 2 then error("bank-slot-failed") end
            if slot == 1 then return { itemID = 42, stackCount = bank.quantity, hyperlink = "item:42" } end
            return nil
        end
        return items(id, slot)
    end
    env.C_Container.GetContainerNumFreeSlots = function(id)
        if id == -1 then return 1, 0 end
        if id >= 5 then return 0, 0 end
        return free(id)
    end
end, false)
event("PLAYER_ENTERING_WORLD"); flush()
local function Quantity(source, options)
    options = options or {}; options.sources = { source }; options.itemID = 42
    return assert(v.Items:Query(options)).totals.totalQuantity
end
Check(Quantity("bags") == 3, "MoP bag baseline")
data.fail = true
Check(not v:ScanBag(0), "MoP bag read failure reported")
Check(Quantity("bags") == 3, "MoP bag error retains successful snapshot")
local state = v:GetCharacterCoverage(e.TEST_GUID, "bags")["0"]
Check(state.status == "error" and state.completedScan, "MoP bag error preserves completed marker")
Check(Quantity("bags", { includeStale = false }) == 0, "failed MoP bag excluded from fresh records")
local revision = v.Items:GetRevision()
v:ScanBag(0)
Check(v.Items:GetRevision() == revision, "identical MoP failure does not repeat notifications")
data.fail = false
Check(v:ScanBag(0) and Quantity("bags", { includeStale = false }) == 3, "MoP bag recovery restores freshness")

event("BANKFRAME_OPENED"); flush()
Check(Quantity("bank") == 5, "MoP bank baseline")
bank.quantity, bank.failSlot = 99, true
Check(not v:ScanBankContainer(-1), "MoP bank slot failure reported")
Check(Quantity("bank") == 5, "partial MoP bank read cannot overwrite old container")
state = v:GetCharacterCoverage(e.TEST_GUID, "bank")["-1"]
Check(state.status == "error" and state.completedScan and state.capacity.totalSlots == 2,
    "MoP bank error retains coverage and capacity")
Check(Quantity("bank", { includeStale = false }) == 0, "failed MoP bank excluded from fresh records")
bank.failSlot, bank.failSize = false, true
Check(not v:ScanBankContainer(-1) and Quantity("bank") == 5, "MoP bank size failure also preserves cache")
bank.failSize = false
Check(v:ScanBankContainer(-1) and Quantity("bank", { includeStale = false }) == 99,
    "MoP bank recovery commits complete replacement")
event("BANKFRAME_CLOSED")
local saved, coreSaved = v.Copy(v.db), core.Defaults:Copy(core.Database:GetDB())
local _, _, restored = Boot(saved, coreSaved, nil, false)
Check(restored.Items:Query({ sources = { "bank" }, itemID = 42 }).totals.totalQuantity == 99,
    "MoP successful bank snapshot survives simulated next session")

for _, capability in ipairs({ "localization", "business-services", "character-name-format", "basic-input",
    "item-resolver", "character-identity", "account-entry" }) do
    local blockedEnv, blockedCore, blocked = Boot(nil, nil, function(_, c)
        local has = c.HasCapability
        c.HasCapability = function(self, name, minimum)
            if name == capability then return false end
            return has(self, name, minimum)
        end
    end, false)
    Check(not blocked.initialized and #blockedEnv.TEST_MESSAGES > 0, "missing capability stops and prompts: " .. capability)
    Check(not blockedCore.Contracts:Resolve("vault.items", { major = 1 }), "blocked Vault exposes no service: " .. capability)
end
local oldEnv, oldCore, oldVault = Boot(nil, nil, function(_, c)
    c.CheckAPIVersion = function() return false end
end, false)
Check(not oldVault.initialized and #oldEnv.TEST_MESSAGES > 0, "insufficient MoP Core API stops and prompts")
Check(not oldCore.Contracts:Resolve("vault.items", { major = 1 }), "insufficient Core API cannot publish Vault service")
-- Release fix 2026-11-22: refused Core (API13) and wrong client leave a real Mists store byte-identical
-- (no default structure, no known->stale normalization before the Core check).
local function Serialize(value)
    if type(value) == "string" then return string.format("%q", value) end
    if type(value) ~= "table" then return tostring(value) end
    local keys, parts = {}, { "{" }
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, key in ipairs(keys) do parts[#parts + 1] = "[" .. Serialize(key) .. "]=" .. Serialize(value[key]) .. "," end
    return table.concat(parts) .. "}"
end
local function Deserialize(text) local chunk = assert(loadstring("return " .. text)); setfenv(chunk, {}); return chunk() end
local storeText = Serialize(v.db)
Check(storeText:find('"known"', 1, true), "fixture store has known coverage that pre-Core normalization would rewrite")
for _, case in ipairs({
    { "API13 Core", function(_, c) c.CheckAPIVersion = function(_, version) return version <= 13 end end },
    { "Core without pixel-line", function(_, c)
        local has = c.HasCapability
        c.HasCapability = function(self, name, minimum) if name == "pixel-line" then return false end; return has(self, name, minimum) end
    end },
    { "wrong client", function(env) env.WOW_PROJECT_ID = 18; env.WOW_PROJECT_CAMELOT = 18 end },
}) do
    local store = Deserialize(storeText)
    local refusedEnv, refusedCore, refused = Boot(store, coreSaved, case[2], false)
    Check(not refused.initialized and not refused.db, case[1] .. ": Mists Vault refused")
    Check(refusedEnv.YiboVaultDB == store and Serialize(store) == storeText, case[1] .. ": Mists store byte-identical")
    Check(#refusedEnv.TEST_MESSAGES == 1, case[1] .. ": one refusal message: " .. table.concat(refusedEnv.TEST_MESSAGES, " | "))
    Check(not refusedCore.Registry:Get("YiboVault"), case[1] .. ": not registered with Core")
end
local missingEnv = Boot(nil, nil, function(_, c) c.CheckAPIVersion = function(_, version) return version <= 13 end end, false)
Check(missingEnv.YiboVaultDB == nil, "API13 Core: missing Mists store is not created")
print("Vault MistsReleaseSpec passed: " .. checks .. " checks")
