-- Run from workspace root: lua YiboCore/_NonRelease/Tests/ForeverItemLevelAndMoneySpec.lua
local checked = 0
local function Equal(actual, expected, label)
    checked = checked + 1
    assert(actual == expected, (label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

function CreateFrame()
    return { RegisterEvent = function() end, SetScript = function() end }
end

dofile("YiboCore/Bootstrap.lua")
dofile("YiboCore/Util/Defaults.lua")
dofile("YiboCore/Runtime/Capabilities.lua")
GetLocale = function() return "zhCN" end

dofile("YiboCore/Runtime/Locale.lua")
dofile("YiboCore/Locales/zhCN.lua")
dofile("YiboCore/Locales/enUS.lua")
dofile("YiboCore/Runtime/Events.lua")
dofile("YiboCore/Runtime/Registry.lua")
dofile("YiboCore/Runtime/Contracts.lua")
dofile("YiboCore/Runtime/DataDomains.lua")
dofile("YiboCore/Runtime/ArchiveFields.lua")
dofile("YiboCore/Forever/Target.lua")
dofile("YiboCore/Forever/Equipment.lua")
dofile("YiboCore/Forever/Fields.lua")
dofile("YiboCore/Runtime/Fields.lua")
dofile("YiboCore/Data/Fields/CharacterArchive.lua")

local Core = YiboCore
local Archive = Core.ArchiveFields

-- ==========================================
-- 1. Money / Sub-Gold Formatting Tests (zhCN)
-- ==========================================
Core.Locale.previewLanguage = "zh"
local mockChar = { id = "Player-1" }
local mockField = { archiveProvider = { registrationRef = "ref1" }, id = "character.money" }

local function MakeSnapshot(value, state)
    return {
        ref1 = {
            ["Player-1"] = {
                fields = {
                    ["character.money"] = { value = value, state = state or "known" }
                }
            }
        }
    }
end

Equal(Archive:FormatValue(mockChar, mockField, MakeSnapshot(0)), "0金", "0 copper is 0金")
Equal(Archive:FormatValue(mockChar, mockField, MakeSnapshot(3535)), "35银35铜", "3535 copper is 35银35铜")
Equal(Archive:FormatValue(mockChar, mockField, MakeSnapshot(5000)), "50银", "5000 copper is 50银")
Equal(Archive:FormatValue(mockChar, mockField, MakeSnapshot(45)), "45铜", "45 copper is 45铜")
Equal(Archive:FormatValue(mockChar, mockField, MakeSnapshot(10000)), "1金", "10000 copper is 1金")
Equal(Archive:FormatValue(mockChar, mockField, MakeSnapshot(15000)), "1金", "15000 copper is 1金 (floored whole gold)")
Equal(Archive:FormatValue(mockChar, mockField, MakeSnapshot(2500000)), "250金", "2500000 copper is 250金")
Equal(Archive:FormatValue(mockChar, mockField, MakeSnapshot(3535, "stale")), "35银35铜~", "stale sub-gold has ~ indicator")
Equal(Archive:FormatValue(mockChar, mockField, MakeSnapshot(10000, "stale")), "1金~", "stale gold has ~ indicator")

-- ==========================================
-- 2. Money / Sub-Gold Formatting Tests (enUS)
-- ==========================================
Core.Locale.previewLanguage = "en"
Equal(Archive:FormatValue(mockChar, mockField, MakeSnapshot(0)), "0g", "enUS: 0 copper is 0g")
Equal(Archive:FormatValue(mockChar, mockField, MakeSnapshot(3535)), "35s35c", "enUS: 3535 copper is 35s35c")
Equal(Archive:FormatValue(mockChar, mockField, MakeSnapshot(5000)), "50s", "enUS: 5000 copper is 50s")
Equal(Archive:FormatValue(mockChar, mockField, MakeSnapshot(45)), "45c", "enUS: 45 copper is 45c")
Equal(Archive:FormatValue(mockChar, mockField, MakeSnapshot(10000)), "1g", "enUS: 10000 copper is 1g")
Equal(Archive:FormatValue(mockChar, mockField, MakeSnapshot(3535, "stale")), "35s35c~", "enUS: stale sub-gold has ~")

-- Switch back to zh
Core.Locale.previewLanguage = "zh"

-- ==========================================
-- 3. Forever Equipment Domain Tests
-- ==========================================
local eqDomain = Core.DataDomains._definitions["equipment"]
Equal(eqDomain ~= nil, true, "equipment domain is registered")
Equal(eqDomain.id, "equipment", "domain id is equipment")
Equal(eqDomain.version, 1, "domain version is 1")
Equal(eqDomain.events.PLAYER_EQUIPMENT_CHANGED, true, "subscribes to equipment changed")

-- Test 3A: C_PaperDollInfo.GetAverageItemLevel API
_G.C_PaperDollInfo = {
    GetAverageItemLevel = function() return 25.5, 24.8 end
}
local data, state = eqDomain.Collect()
Equal(state, "known", "GetAverageItemLevel known state")
Equal(data.itemLevel, 24.8, "reads equipped ilvl from C_PaperDollInfo")
_G.C_PaperDollInfo = nil

-- Test 3B: Global GetAverageItemLevel API
_G.GetAverageItemLevel = function() return 30.0, 28.5 end
data, state = eqDomain.Collect()
Equal(state, "known", "global GetAverageItemLevel known state")
Equal(data.itemLevel, 28.5, "reads equipped ilvl from GetAverageItemLevel")
_G.GetAverageItemLevel = nil

-- Test 3C: Fallback to equipped slot links
local mockItems = {
    [1] = "item:1001", -- ilvl 10
    [5] = "item:1002", -- ilvl 20
}
_G.GetInventoryItemLink = function(unit, slot)
    Equal(unit, "player", "unit is player")
    return mockItems[slot]
end
_G.GetItemInfo = function(link)
    if link == "item:1001" then return "Head", link, 1, 10
    elseif link == "item:1002" then return "Chest", link, 1, 20
    end
end

data, state = eqDomain.Collect()
Equal(state, "known", "slot fallback known state")
Equal(data.itemLevel, 15, "averages 10 and 20 to 15")

-- Test 3D: No equipment and no API -> unavailable
mockItems = {}
data, state = eqDomain.Collect()
Equal(state, "unavailable", "empty equipment returns unavailable")
Equal(data, nil, "empty data on unavailable")

-- Test 3E: ProjectLegacy
local record = {}
eqDomain.ProjectLegacy(record, { itemLevel = 15 }, { state = "known", updatedAt = 12345 })
Equal(record.profile.itemLevel, 15, "projects itemLevel to record.profile")
Equal(record.observedAt.itemLevel, 12345, "projects observedAt")
Equal(record.availability.itemLevel, "known", "projects availability")

-- ==========================================
-- 4. CharacterArchive Field (character.item-level)
-- ==========================================
local ilvlField = Core.Fields._definitions["character.item-level"]
Equal(ilvlField ~= nil, true, "character.item-level is registered in Fields")
Equal(ilvlField.consumer, "character-archive", "field consumer is character-archive")
Equal(ilvlField.domain, "equipment", "field domain is equipment")
Equal(ilvlField.title, "装等", "field title is 装等")

Equal(ilvlField.Format(15), "15", "formats integer ilvl")
Equal(ilvlField.Format(24.8), "25", "rounds float ilvl")
Equal(ilvlField.Format(0), "—", "0 ilvl formats as dash")
Equal(ilvlField.Format(nil), "—", "nil ilvl formats as dash")
Equal(ilvlField.Format(-1), "—", "negative ilvl formats as dash")

print(string.format("ForeverItemLevelAndMoneySpec passed: %d checks", checked))
