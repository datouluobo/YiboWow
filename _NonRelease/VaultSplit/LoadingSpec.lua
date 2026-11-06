local Boot = dofile("_NonRelease/VaultForever/Smoke.lua")
local checks = 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
local function TrackFrames(env)
    local create = env.CreateFrame
    env.CreateFrame = function(...)
        local frame = create(...)
        local register = frame.RegisterEvent
        frame.registrationCounts = {}
        frame.RegisterEvent = function(self, event)
            self.registrationCounts[event] = (self.registrationCounts[event] or 0) + 1
            return register(self, event)
        end
        return frame
    end
end
for _, forever in ipairs({ false, true }) do
    local env, core, vault, event, flush, data = Boot(nil, nil, TrackFrames, forever)
    Check(vault.initialized, "target initialized")
    Check(type(vault.BuildItemRecord) == "function" and type(vault.MarkLocationError) == "function", "common collector support")
    Check((type(vault.ScanBag) == "function") == not forever, "MoP single-bag reader only exists on MoP")
    Check((type(vault.ScanBankContainer) == "function") == not forever, "MoP bank reader only exists on MoP")
    local saved = forever and env.YiboVaultForeverDB or env.YiboVaultDB
    local foreign = forever and env.YiboVaultDB or env.YiboVaultForeverDB
    Check(vault.db == saved and foreign.sentinel == (forever and "mists" or "forever"), "unchanged save ownership")
    local counts = {}
    for name, count in pairs(vault.Frame.registrationCounts) do counts[name] = count; Check(count == 1, "event registered once: " .. name) end
    event("ADDON_LOADED", "YiboVault")
    core.Events:Fire("CORE_READY")
    for name, count in pairs(vault.Frame.registrationCounts) do Check(count == counts[name], "reinitialization does not register events again") end
    if not forever then
        local parse = core.ItemResolver.Parse
        local parsed = 0
        core.ItemResolver.Parse = function(self, input, options)
            parsed = parsed + 1
            return parse(self, input, options)
        end
        data.bags[0][1] = { stackCount = 2, hyperlink = "item:6948" }
        local ok = vault:ScanBag(0)
        Check(ok and parsed == 1, "legacy native link without itemID uses Core parser")
        local records = vault:GetCharacterRecords(env.TEST_GUID, "bags", 6948)
        Check(#records == 1 and records[1].quantity == 2, "legacy link keeps record identity and quantity")
        local errorEnv, _, blocked = Boot(nil, nil, function(e, c)
            TrackFrames(e)
            c.ItemResolver.Parse = nil
        end, false)
        Check(not blocked.initialized, "missing Core parser stops dependent initialization")
        Check(#errorEnv.TEST_MESSAGES > 0, "missing Core parser reports upgrade requirement")
    end
    event("PLAYER_ENTERING_WORLD"); flush()
    saved.settings.splitRetained = "keep"
    local nextEnv, _, restored, nextEvent, nextFlush = Boot(saved, forever and env.YiboCoreForeverDB or env.YiboCoreDB, nil, forever)
    Check(restored.db == saved and restored.db.settings.splitRetained == "keep", "next simulated session preserves settings")
    nextEvent("PLAYER_ENTERING_WORLD"); nextFlush()
    Check(restored.db.byCharacter[nextEnv.TEST_GUID] ~= nil, "next simulated session retains character snapshot")
end
print("VaultSplit LoadingSpec passed: " .. checks .. " checks (simulated sessions)")
