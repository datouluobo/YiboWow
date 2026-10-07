-- Run from workspace root: lua YiboCore/_NonRelease/Tests/CharacterNamesSpec.lua
local checked = 0
local function Equal(actual, expected, label)
    checked = checked + 1
    assert(actual == expected, (label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

function CreateFrame()
    return { RegisterEvent = function() end, SetScript = function() end }
end
dofile("YiboCore/Bootstrap.lua")
dofile("YiboCore/Runtime/Capabilities.lua")
dofile("YiboCore/Runtime/Events.lua")
dofile("YiboCore/Util/Defaults.lua")
local Core = YiboCore
local db
Core.Database = { GetDB = function() return db end }
dofile("YiboCore/Data/Characters.lua")
local Names = Core.Characters
local character = { id = "Player-1", name = "天堂猎手", realm = "Silver Moon", class = "HUNTER" }
local contact = { name = "外部联系人", realm = "SilverMoon" }

Equal(Core:CheckAPIVersion(5), true, "old API remains compatible")
Equal(Core:CheckAPIVersion(7), true, "API v7 remains compatible")
Equal(Core:CheckAPIVersion(8), true, "new API available")
Equal(Core:CheckAPIVersion(9), false, "future API rejected")
Equal(Core:HasCapability("character-name-format", 1), true, "format capability")
Equal(Core:HasCapability("character-name-format", 2), false, "future contract rejected")
Equal(Names:FormatName(character, { nameMode = "short" }), character.name, "before DB initialization")
Equal(db, nil, "no DB created")
db = { characters = { byID = { [character.id] = character } } }
Equal(Names:FormatName(character, { nameMode = "short" }), character.name, "missing preference store")
Equal(db.characterDisplay, nil, "read does not create preferences")
db.characterDisplay = { [character.id] = { shortName = "猎手" } }

local cases = {
    { nil, "天堂猎手" },
    { { nameMode = "short" }, "猎手" },
    { { realmMode = "full" }, "天堂猎手-Silver Moon" },
    { { nameMode = "short", realmMode = "full" }, "猎手-Silver Moon" },
    { { realmMode = "sameRealm", referenceRealm = " silvermoon " }, "天堂猎手" },
    { { nameMode = "short", realmMode = "sameRealm", referenceRealm = "OtherRealm" }, "猎手-Silver Moon" },
}
for index, case in ipairs(cases) do Equal(Names:FormatName(character, case[1]), case[2], "format " .. index) end
Equal(Names:FormatName(contact, { nameMode = "short" }), contact.name, "contact short fallback")
Equal(Names:FormatName(contact, { realmMode = "sameRealm", referenceRealm = "Silver Moon" }), contact.name, "contact same realm")
Equal(Names:FormatName(contact, { realmMode = "full" }), "外部联系人-SilverMoon", "contact full identity")
Equal(Names:FormatName({ name = "未采集服务器" }), "未采集服务器", "name only")
Equal(Names:FormatName({ name = "未采集服务器" }, { realmMode = "sameRealm", referenceRealm = "Other" }), "未采集服务器", "unknown realm is not invented")
Equal(Names:GetDisplayName(character, "full"), character.name, "legacy full is original name")
Equal(Names:GetDisplayName(character, "short"), "猎手", "legacy short unchanged")
Equal(Names:GetDisplayName(character, "other"), character.name, "legacy unknown mode unchanged")
Equal(Names:GetDisplayName(contact, "short"), contact.name, "legacy contact")

local invalid = {
    { false, nil, "invalid-identity" },
    { character, false, "invalid-options" },
    { character, { nameMode = "full" }, "invalid-name-mode" },
    { character, { nameMode = false }, "invalid-name-mode" },
    { character, { realmMode = "other" }, "invalid-realm-mode" },
    { character, { realmMode = false }, "invalid-realm-mode" },
    { { name = "" }, nil, "missing-name" },
    { { name = 123 }, nil, "missing-name" },
    { { name = "Contact", realm = false }, nil, "invalid-realm" },
    { { name = "Contact" }, { realmMode = "full" }, "missing-realm" },
    { character, { realmMode = "sameRealm" }, "missing-reference-realm" },
    { character, { realmMode = "sameRealm", referenceRealm = " " }, "missing-reference-realm" },
}
for index, case in ipairs(invalid) do
    local value, reason = Names:FormatName(case[1], case[2])
    Equal(value, nil, "invalid result " .. index)
    Equal(reason, case[3], "invalid reason " .. index)
end
local options = { nameMode = "short", realmMode = "sameRealm", referenceRealm = "Other" }
Names:FormatName(character, options)
Equal(character.name, "天堂猎手", "original name preserved")
Equal(character.realm, "Silver Moon", "realm spelling preserved")
Equal(options.referenceRealm, "Other", "options preserved")
Equal(next(db.characters.byID), character.id, "contacts do not enter directory")

local notifications = 0
Core.Events:Register("CHARACTER_DISPLAY_UPDATED", function() notifications = notifications + 1 end)
Equal(Names:SetShortName(character.id, " 新短名 "), "新短名", "existing setter")
Equal(Names:FormatName(character, { nameMode = "short" }), "新短名", "updated preference is immediate")
Equal(Names:SetShortName(character.id, ""), "", "clear short name")
Equal(Names:FormatName(character, { nameMode = "short" }), character.name, "clear falls back to original")
Equal(notifications, 2, "existing update event retained")
db.characterDisplay[character.id] = { shortName = "猎手" }

-- Integration: preserve the shared header contract used by old business addons.
dofile("YiboCore/UI/Theme.lua")
local Theme = Core.UITheme
local capture = {}
function Theme:SetMatrixHeader(_, text, settings) capture.name, capture.secondary, capture.height = text, settings.secondary, settings.height end
function Theme:BindTooltip(_, title, lines) capture.title, capture.lines = title, lines end
function Theme:MeasureText(_, value) return #tostring(value) * 2 end
Theme:SetCharacterHeader({}, character, { scope = "all" })
Equal(capture.name, "猎手", "default header still uses short name")
Equal(capture.secondary, character.realm, "realm remains a separate subtitle")
Equal(capture.title, "天堂猎手-Silver Moon", "tooltip uses real full identity")
Equal(capture.lines[1].value, "猎手", "short name tooltip retained")
Equal(capture.height, Theme.Table.characterHeaderHeight, "all-realm header height")
Theme:SetCharacterHeader({}, character, { scope = "realm:Other" }, { nameMode = "full" })
Equal(capture.name, character.name, "legacy full header mode")
Equal(capture.secondary, nil, "single selected realm omits subtitle")
Equal(capture.height, Theme.Table.headerHeight, "single-realm header height")
Theme:SetCharacterHeader({}, character, { scope = "all" }, { name = "显式名称", realm = "指定服务器", state = "unsynced" })
Equal(capture.name, "显式名称", "explicit business name override")
Equal(capture.secondary, "指定服务器", "explicit realm override")
Equal(capture.title, "天堂猎手-指定服务器", "override tooltip still uses original character name")
Equal(#capture.lines, 3, "short name and recovery lines retained")
local fullWidth = Theme:MeasureText(Theme.Font.body, "天堂猎手-Silver Moon") + Theme.Table.cellPadding * 2
Equal(Theme:GetCharacterRowHeaderWidth(false, { scope = "all" }, { character }), math.ceil(fullWidth), "complete row identity measured")
Equal(Theme:GetCharacterRowHeaderWidth(true, { scope = "all" }, { character }), math.ceil(fullWidth + 16 + Theme.Table.iconTextGap), "profession icon spacing")
local matrixWidth = Theme:GetCharacterMatrixColumnWidth({ scope = "all" }, { character })
assert(matrixWidth > 0, "matrix measurement remains usable")

local fields = {}
Core.Fields = { Register = function(_, _, definition) fields[definition.id] = definition end }
dofile("YiboCore/Data/Fields/CharacterArchive.lua")
Equal(fields["character.identity"].Format(character), "天堂猎手-Silver Moon", "archive identity remains original/full")
Equal(fields["character.identity"].Format(nil), "—", "empty archive value")
Equal(fields["character.identity"].Format({}), "未知角色-未知服务器", "archive placeholder preserved")

print("CharacterNamesSpec passed: " .. checked .. " checks")
