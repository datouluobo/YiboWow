-- Run from repository root with Lua 5.1.
function CreateFrame() return {} end
local now = 1000
function GetServerTime() return now end
date = os.date
dofile("YiboMail/Namespace.lua")
local A = YiboMail
local current = { id = "a", name = "A", realm = "Realm-With-Hyphen" }
local other = { id = "b", name = "B", realm = "Other Realm" }
local third = { id = "c", name = "C", realm = "Other Realm" }
local roster = { current, other, third }
local events = {}
A.Core = { Characters = { GetCurrent = function() return current end, GetAllCached = function() return roster end },
    Events = { Register = function(_, event, owner, callback) events[event] = function(...) callback(owner, ...) end end },
    AccountView = { GetVisibleCharacters = function() return { current, other } end } }
A.db = { contacts = { { address = "Alpha", label = "First" }, { address = "alpha-Realm-With-Hyphen" }, { address = "|bad" }, { address = "Beta-Other Realm" } } }
dofile("YiboMail/Recipients.lua")
local R = A.Recipients; R:Initialize()
assert(A.db.recipientSchemaVersion == 1 and #A.db.contacts == 4 and #A.db.quickRecipients == 2)
assert(R.migrationSkipped == 1 and A.db.quickRecipients[1] ~= A.db.contacts[1])
assert(R:Normalize(" Bob ") == "Bob-Realm-With-Hyphen")
assert(R:Normalize("Bob-OtherRealm") == "Bob-Other Realm")
assert(not R:Normalize("Bob-") and not R:Normalize("B ob") and not R:Normalize("Bob\nEvil"))
assert(R:Label({ address = "Bob-Realm-With-Hyphen" }) == "Bob")
assert(R:Label({ address = "Bob-Other Realm" }) == "Bob-Other Realm")
assert(R:Label({ address = "Bob-Other Realm", label = "|cff00ff00 label" }):find("||", 1, true))
R:ClearShortcut(1); R:Initialize(); assert(A.db.quickRecipients[1] == nil and A.db.quickRecipients[2])
assert(R:SetShortcut(16, "Zulu")); assert(R:SetShortcut(3, "Zulu"))
assert(not R:SetShortcut(73, "Zulu")); assert(not R:SetShortcut(3, "Bad|Name"))
assert(R:SetShortcut(72, "Last"))
A.db.settings = { shortcutRows = 1, shortcutColumns = 1, recipientGroups = { contacts = false } }
local rows, columns = A:GetShortcutLayout(); assert(rows == 1 and columns == 1)
assert(A.db.quickRecipients[72] and not A:IsRecipientSourceVisible("contacts"))
assert(#R:Candidates("contacts") > 0)
A.db.settings.shortcutRows = 8; A.db.settings.shortcutColumns = 4
assert(A.db.quickRecipients[72].address == "Last-Realm-With-Hyphen")
assert(R:SaveContact("Zulu")); R:RemoveContact("Zulu")
assert(A.db.quickRecipients[16].address == "Zulu-Realm-With-Hyphen")
for i = 1, 40 do assert(R:SaveContact("User" .. i)) end
assert(#R:Candidates("contacts") > 16 and R:Query("contacts", "User40")[1])
assert(R.sources[1].id == "contacts" and R.sources[2].id == "characters" and R.sources[3].id == "recent")
assert(#R:Candidates("characters") == 1)
assert(R:CommitFriends(current, { "Same-OtherRealm", "Mine" }, true))
assert(R:CommitFriends(other, { "Same-OtherRealm", "One" }, true))
assert(R:CommitFriends(third, { "Same-OtherRealm", "Two" }, true))
assert(#R:Candidates("friends") == 2 and #R:AccountFriends() == 2)
local union = R:AccountFriends(); local revision = R.friendRevision
now = now + 5
R:CommitFriends(other, { "One", "Same-OtherRealm" }, true)
assert(R.friendRevision == revision and R:AccountFriends() == union)
assert(#R:FriendOwners("Same-Other Realm") == 2)
R:CommitFriends(other, { "One" }, true); assert(#R:AccountFriends() == 2)
R:CommitFriends(third, { "Two" }, true); assert(#R:AccountFriends() == 2)
assert(#R:Candidates("friends") == 2)
local prior = A.db.friendsByCharacter.b
assert(not R:CommitFriends(other, {}, false) and A.db.friendsByCharacter.b == prior)
assert(not R:CommitFriends(other, { "Bad|Name" }, true) and A.db.friendsByCharacter.b == prior)
assert(R:CommitFriends(other, {}, true) and #R:AccountFriends() == 1)
-- Hidden account roles are excluded from both friend sources, using raw snapshots.
R:CommitFriends(current, { "A", "B-OtherRealm", "C-Other Realm", "Shared-OtherRealm", "Local" }, true)
R:CommitFriends(other, { "A-Realm-With-Hyphen", "C-OtherRealm", "Shared-OtherRealm", "Unique", "Local-Other Realm" }, true)
assert(#R:Candidates("characters") == 1) -- C is hidden in the visible roster mock.
assert(#R:Candidates("friends") == 2)
assert(#R:AccountFriends() == 3) -- Unique, Local on another realm, and Two.
assert(#R:Query("friends", "C-OtherRealm") == 0)
assert(#R:Query("accountFriends", "Shared") == 0)
assert(A.db.friendsByCharacter.a.addresses[R:Key("C-Other Realm")])
assert(A.db.friendsByCharacter.b.addresses[R:Key("Shared-Other Realm")])
R:CommitFriends(current, { "Local" }, true)
assert(#R:AccountFriends() == 4) -- Shared becomes available from B again.
local promoted = { id = "newRole", name = "Unique", realm = "Other Realm" }
roster[#roster + 1] = promoted; events.CHARACTER_IMPORTED()
assert(#R:AccountFriends() == 3 and #R:Query("accountFriends", "Unique") == 0)
roster[#roster] = nil; events.CHARACTER_CACHE_DELETED()
assert(#R:AccountFriends() == 4)
R:CommitFriends(current, { "Same-OtherRealm", "Mine" }, true)
R:CommitFriends(other, {}, true)
local oldCurrent = current; current = other
assert(#R:AccountFriends() == 3) -- A now contributes its two entries, C contributes one.
current = oldCurrent
A.db.friendsByCharacter.old = { addresses = { ["old-otherrealm"] = "Old-Other Realm" }, updatedAt = 1 }
A.db.friendsByCharacter.new = { addresses = {}, updatedAt = 2 }
events.CHARACTER_ID_CHANGED("old", "new")
assert(not A.db.friendsByCharacter.old and next(A.db.friendsByCharacter.new.addresses) == nil)
A.db.friendsByCharacter.alias = { addresses = {}, updatedAt = 3 }
assert(R:HasCharacter({ id = "none" }, { alias = true }))
R:DeleteCharacter({ id = "none" }, { alias = true }); assert(not A.db.friendsByCharacter.alias)
for i = 1, 30 do R:RecordRecent("Recent" .. i) end
assert(#A.db.recentRecipients == 20 and A.db.recentRecipients[1].address == "Recent30-Realm-With-Hyphen")
R:RecordRecent("Recent15"); assert(#A.db.recentRecipients == 20 and A.db.recentRecipients[1].address == "Recent15-Realm-With-Hyphen")
-- Unready/partial reads preserve snapshots; a ready event can establish empty.
local scheduled = {}; C_Timer = { After = function(_, callback) scheduled[#scheduled + 1] = callback end }
local apiCount, apiReads = 1, 0
C_FriendList = { GetNumFriends = function() return apiCount end, GetFriendInfoByIndex = function() apiReads = apiReads + 1; return { name = "Friend" } end }
R:OnEvent("FRIENDLIST_UPDATE"); R:OnEvent("FRIENDLIST_UPDATE"); R:OnEvent("FRIENDLIST_UPDATE")
assert(#scheduled == 1); scheduled[1](); assert(apiReads == 1)
apiCount = 0; R:ReadFriends(false); assert(next(A.db.friendsByCharacter.a.addresses))
R:ReadFriends(true); assert(next(A.db.friendsByCharacter.a.addresses) == nil)
apiCount = 2; C_FriendList.GetFriendInfoByIndex = function(index) if index == 1 then return { name = "Friend" } end end
R:ReadFriends(true); assert(next(A.db.friendsByCharacter.a.addresses) == nil)
C_FriendList.GetNumFriends = function() error('unready') end
local preserved = A.db.friendsByCharacter.a
R:ReadFriends(true); assert(A.db.friendsByCharacter.a == preserved)
IsInGuild = function() return true end; GetNumGuildMembers = function(includeOffline) assert(includeOffline); return 3 end
GetGuildRosterInfo = function(index) return ({ "GuildOne", "GuildTwo-OtherRealm", "GuildOne" })[index] end
R:ReadGuild(); R:Changed(); assert(#R:Candidates("guild") == 2)
print("PASS: address/realm/labels; independent fixed slots and one-time migration; >16 contacts; six sources; dedup/delete/cache; snapshot readiness/coalescing; identity/alias cleanup; recent cap; offline guild roster")
-- Standalone Lua resource samples: these are not measurements from the game.
for _, size in ipairs({ 3000, 10000 }) do
    A.db.friendsByCharacter = {}; collectgarbage("collect"); local base = collectgarbage("count")
    for role = 1, size / 100 do
        local entries = {}; for i = 1, 100 do entries[i] = "Friend" .. (role * 50 + i) .. "-Other Realm" end
        R:CommitFriends({ id = "bench" .. role, realm = "Other Realm" }, entries, true)
    end
    collectgarbage("collect"); local snapshotsKB = collectgarbage("count") - base
    local started = os.clock(); local result = R:AccountFriends(); local duration = (os.clock() - started) * 1000
    local queryStarted = os.clock(); R:Query("accountFriends", "Friend100"); local queryMS = (os.clock() - queryStarted) * 1000
    assert(R:AccountFriends() == result)
    print(string.format("SAMPLE: %d memberships, %d union entries, snapshots %.1f KiB, union %.3f ms, search %.3f ms (standalone Lua 5.1)", size, #result, snapshotsKB, duration, queryMS))
end

-- Moving/swapping only changes slot ownership; cancelled/stale operations leave data intact.
local original = A.db.quickRecipients[72]
R:ClearShortcut(71); assert(R:MoveShortcut(72, 71, original))
assert(not A.db.quickRecipients[72] and A.db.quickRecipients[71] == original)
assert(R:SetShortcut(72, "Swap", "Remark")); local otherSlot = A.db.quickRecipients[72]
assert(R:MoveShortcut(71, 72, original))
assert(A.db.quickRecipients[71] == otherSlot and A.db.quickRecipients[72] == original)
assert(not R:MoveShortcut(71, 72, original))
assert(not R:MoveShortcut(0, 72) and not R:MoveShortcut(72, 73))
assert(R:MoveShortcut(72, 72, original) and A.db.quickRecipients[72] == original)
