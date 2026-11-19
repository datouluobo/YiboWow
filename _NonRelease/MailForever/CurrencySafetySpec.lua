local Boot = dofile("_NonRelease/MailForever/Harness.lua")
local value = { flag = true, id = 7001, quantity = 25, name = "Tokens" }
local e, core, mail, fire, flush, box = Boot(nil, function(e)
    local original, originalLink = e.GetInboxItem, e.GetInboxItemLink
    e.GetInboxItem = function(index, slot)
        if index == 1 and slot == 1 then return value.name, value.id, 654, value.quantity, 1, true, value.flag end
        return original(index, slot)
    end
    e.GetInboxItemLink = function(index, slot)
        if index == 1 and slot == 1 then return value.link end
        return originalLink(index, slot)
    end
end)
fire("PLAYER_ENTERING_WORLD"); box.open = true; fire("MAIL_SHOW"); flush()
local current = core.Characters:GetCurrent()
local function Scan() fire("MAIL_INBOX_UPDATE"); flush() end
local snapshot = mail.db.byCharacter[current.id]
local key = snapshot.visibleKeys[1]
assert(mail.Items:GetState(current.id).status == "known" and mail.Items:GetByCharacter(current.id).quantity == 2)
value.flag = 1; value.link = "currency:7001:99"; Scan()
assert(snapshot.visibleKeys[1] == key and mail.Scanner:ReadTarget(1).attachments[1].variantKey == "currency:7001",
    "numeric native true and link suffixes do not change currency identity")
value.flag = true; value.link = nil
value.name = nil; Scan()
assert(mail.Items:GetState(current.id).status == "known"
    and mail.CacheModel:ItemName(assert(mail.Scanner:ReadTarget(1)).attachments[1]):find("7001", 1, true),
    "an unnamed native currency has a stable localized ID label")
value.name = "Tokens"; Scan()
for _, invalid in ipairs({ { "link", "item:7001" }, { "link", "currency:9999" }, { "link", 7001 },
    { "flag", "currency" }, { "id", 0 }, { "id", "7001" }, { "quantity", 0 }, { "quantity", -1 },
    { "quantity", 1.5 }, { "name", {} } }) do
    local field, prior = invalid[1], value[invalid[1]]
    value[field] = invalid[2]; Scan()
    assert(mail.Items:GetState(current.id).status == "error" and snapshot.visibleKeys[1] == key
        and mail.Items:GetByCharacter(current.id).quantity == 2, "bad native currency input preserves the last snapshot")
    value[field] = prior; Scan(); assert(mail.Items:GetState(current.id).status == "known")
end
value.flag = 0; value.link = "item:7001"; Scan()
assert(mail.Items:GetByCharacter(current.id).quantity == 27, "numeric false remains an ordinary item")
value.flag = true; value.link = nil; Scan()
box.items[1][16] = nil; box.headers[1].count = 1; Scan()
assert(mail.Items:GetByCharacter(current.id).quantity == 0 and mail.Items:GetState(current.id).status == "known",
    "a currency-only inbox is known without inventing item records or claiming an empty mailbox")
local changed
mail.Items.Events:Register({}, function(_, payload) changed = payload end)
value.quantity = 26; Scan()
assert(changed and #changed.changedItemIDs == 0 and #changed.changedMailKeys > 0,
    "currency-only changes publish mail invalidation without fake item IDs")
value.quantity = 25; Scan()
local entry
for _, row in ipairs(mail.ViewModel:GetMails({ characters = { current } }, {})) do if row.mail.inboxIndex == 1 then entry = row end end
e.TakeInboxItem = function() fire("MAIL_FAILED") end
local selected = { [mail.ViewModel:ActionID(current.id, entry.key, 1)] = true }
local actions = assert(mail.Queue:Prepare(selected, { characters = { current } }))
value.flag = 0; value.link = "item:7001"
assert(not mail.Queue:Start(actions), "a currency plan cannot act on a same-ID item that replaced its slot")
value.flag = true; value.link = nil
assert(mail.Queue:Start(actions))
assert(mail.Queue.state == "paused" and mail.Queue.completed == 0, "native failure never becomes confirmed currency receipt")
fire("MAIL_CLOSED"); box.open = false; flush()
local history = mail.HistoryModel:Query({ characters = { current } }, { result = "unverified", content = "currency" })
assert(#history == 1 and history[1].items[1].currencyID == 7001 and history[1].items[1].quantity == 25)
assert(#mail.HistoryModel:Query({ characters = { current } }, { content = "currency" }) == 0,
    "default history does not present an uncertain result as collected")
box.open = true; fire("MAIL_SHOW"); flush()
assert(mail.Scanner:ReadTarget(1).attachments[1].quantity == 25, "failed currency remains in the live mailbox")
box.headers[1].isGM = true; Scan()
assert(not mail.Queue:Prepare(selected, { characters = { current } }), "GM mail stays manual")
box.headers[1].isGM = false; box.headers[1].cod = 1; Scan()
assert(not mail.Queue:Prepare(selected, { characters = { current } }), "COD cannot be collected without native confirmation")
print("PASS: currency native flags/link namespace/quantities, snapshot preservation, failure review and GM/COD guards")
