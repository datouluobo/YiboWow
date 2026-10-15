local Setup = dofile("YiboBuilds/_NonRelease/Tests/Core13Host.lua")
local checks = 0
local function Check(value, message) checks = checks + 1; assert(value, message) end
for _, lang in ipairs({ "zh", "en" }) do
    local host = Setup(lang)
    dofile("YiboBuilds/Snapshot.lua")
    dofile("YiboBuilds/AccountPage.lua")
    dofile("YiboBuilds/CoreIntegration.lua")
    local addon, core = YiboBuilds, YiboCore
    dofile("YiboBuilds/Data/EnchantCatalog.lua")
    dofile("YiboBuilds/Data/ProfessionCatalog.lua")
    dofile("YiboBuilds/Data/SocketEffectCatalog.lua")
    dofile("YiboBuilds/GoalTargets.lua")
    core.Characters.Get = function(_, id) return id == "Player:1" and {id=id} end
    for _, failure in ipairs({ "localization", "character-name-format", "character-identity", "account-view", "account-entry", "character-cleanup", "business-providers", "business-item-actions", "characters" }) do
        host.missing = failure
        local ok, err = addon.CoreIntegration:Initialize()
        Check(not ok and err:find("API13", 1, true), "missing capability must show upgrade prompt: " .. failure)
        Check(host.pages == 0 and host.ownerRegistrations == 0, "missing capability must stop before writes")
    end
    host.missing, host.api = nil, 12
    Check(not addon.CoreIntegration:Initialize() and host.pages == 0, "old API must stop")
    host.api, host.ready = 13, false
    Check(not addon.CoreIntegration:Initialize() and host.pages == 0, "unready Core must stop")
    host.ready = true
    Check(addon.CoreIntegration:Initialize(), "current Core must initialize")
    Check(addon.CoreIntegration:Initialize() and host.pages == 1 and host.entries == 1 and host.ownerRegistrations == 1, "initialization must be idempotent")
    Check(host.page.title == (lang == "en" and "Character builds" or "角色构筑"), "page title language")
    Check(#core.Locale:GetMissingEnglish("YiboBuilds") == 0, "English resources complete")
    local zh, en = core.Locale.resources.YiboBuilds.zh, core.Locale.resources.YiboBuilds.en
    for key, text in pairs(zh) do
        Check(en[key] ~= nil, "missing English: " .. key)
        local function Formats(value)
            local items = {}; for item in value:gmatch("%%[-+ #0-9.]*[cdiouxXeEfgGqs]") do items[#items + 1] = item end
            return table.concat(items, ",")
        end
        Check(Formats(text) == Formats(en[key]), "format mismatch: " .. key)
    end
    Check(host.page.GetSummary({{}, {}}):find("2", 1, true), "summary formatting")
    local _, normalizeError = addon.GoalTargets:Normalize({intent={}})
    Check(normalizeError == addon:T("UI.SELECT_AN_EQUIPMENT_ENHANCEMENT_CANDIDATE"), "provider error language")
    local normalized = addon.GoalTargets:Normalize({intent={scope={characterID="Player:1"},conditions={slotID=1,itemID=123,buildSlot="primary",enhancementID=456,kind="gem",socketIndex=1}}})
    Check(normalized and normalized.intent.scope.characterID == "Player:1", "provider preserves Core identity")
    local result = addon.GoalTargets:Evaluate({goals={{id="goal:1",intent=normalized.intent}}})
    Check(result.evaluations["goal:1"].task.freshness.state == "partial" and result.evaluations["goal:1"].task.state == "active", "missing observation is unknown, not completed")
    local fields = host.page.GetPreviewFields(); fields.equipment_head = false
    Check(addon:GetSettings().previewColumns.equipment_head == true, "preview fields must be a copy")
    Check(host.page.SetPreviewFieldVisible("equipment_head", false), "valid preview field accepted")
    Check(not host.page.SetPreviewFieldVisible("injected-key", true) and addon:GetSettings().previewColumns['injected-key'] == nil, "invalid field rejected")
    Check(addon.Snapshot:GetDisplayName({nameKey="UI.NOT_SELECTED"}) == (lang == "en" and "Not selected" or "未选择"), "semantic snapshot label")
    local old = { name = "未知天赋" }
    Check(addon.Snapshot:GetDisplayName(old) == (lang == "en" and "Unknown talent" or "未知天赋") and old.name == "未知天赋", "legacy label rendered without mutation")
    Check(addon.Snapshot:GetDisplayName({name="Native API Name"}) == "Native API Name", "native name preserved")
    local function Find(fn, target, seen)
        seen = seen or {}; if seen[fn] then return end; seen[fn] = true
        for i=1,100 do local name, value = debug.getupvalue(fn,i); if not name then break end
            if name == target then return value end
            if type(value) == "function" then local found = Find(value,target,seen); if found then return found end end
        end
    end
    local label = assert(Find(addon.AccountPage.Refresh,"CharacterLabel"))
    Check(label({ name="Player",realm="Realm" },{scope="all"}) == "Player-Realm" and host.nameOptions.nameMode == "short", "all-realm formatting")
    Check(label({ name="Player",realm="Realm" },{scope="realm"}) == "Player" and host.nameOptions.realmMode == "omit", "single-realm formatting")
    local db = addon:EnsureDB()
    db.characters.old = {slots={primary={updatedAt=20}}}; db.characters.alias = {slots={}}
    Check(host.owner.Delete({id="old"},{alias=true},{deletedAt=100,replay=true}) and not db.characters.old and not db.characters.alias, "old snapshots and aliases cleared")
    db.characters.fresh = {slots={primary={updatedAt=200,observedEquipment={capturedAt=200},confirmedEquipment={capturedAt=50}},secondary={updatedAt=30}}}
    host.owner.Delete({id="fresh"},{},{deletedAt=100,replay=true})
    Check(db.characters.fresh and not db.characters.fresh.slots.secondary and not db.characters.fresh.slots.primary.confirmedEquipment and db.characters.fresh.slots.primary.observedEquipment, "replay keeps fresh data and clears stale equipment")
    host.owner.Delete({id="fresh"},{},{deletedAt=100,replay=false})
    Check(not db.characters.fresh, "explicit delete clears even newer data")
    db.characters.future={slots={primary={updatedAt=2000}}}; host.owner.Delete({id="future"},{},{deletedAt=100,replay=true})
    Check(not db.characters.future, "future timestamp cannot bypass deletion")
end
-- Check TOC-order loading stops before localized UI evaluation on old Core.
local host = Setup("en"); host.api = 12
YiboBuilds.AccountPage = nil; dofile("YiboBuilds/AccountPage.lua")
Check(YiboBuilds.AccountPage == nil, "old Core must not build module metadata")
print("Core13Spec passed: " .. checks .. " checks")
