local Boot = dofile("_NonRelease/MailForever/Harness.lua")
local e, core, mail, fire, flush, box = Boot()
local permitted, calls, body, invoice, locale, complaint = true, 0, "", nil, "zhCN", false
e.InboxItemCanDelete = function() return permitted end
e.GetInboxText = function() return body, nil, nil, nil, invoice end
e.GetLocale = function() return locale end
e.CanComplainInboxItem = function() return complaint end
e.DeleteInboxItem = function(index)
    assert(index == 2, "only the empty player letter is deleted")
    calls = calls + 1
    e.C_Timer.After(0.04, function()
        table.remove(box.headers, index)
        box.items[index] = nil
        box.count, box.total = box.count - 1, box.total - 1
        fire("MAIL_SUCCESS"); fire("MAIL_INBOX_UPDATE")
    end)
end
box.headers[2].canReply = true
fire("PLAYER_ENTERING_WORLD"); box.open = true; fire("MAIL_SHOW"); flush()
local function Candidate() return assert(mail.Scanner:ReadTarget(2)) end
local runtime = mail.CollectionRuntime
assert(runtime:CanDeleteEmpty(Candidate()), "a player letter with an empty body is eligible")
body = "Keep this player letter"
assert(not runtime:CanDeleteEmpty(Candidate()), "retained player text is preserved")
body = " "; assert(not runtime:CanDeleteEmpty(Candidate()))
body = nil; assert(not runtime:CanDeleteEmpty(Candidate()))
body = "System message"; box.headers[2].canReply = false
assert(runtime:CanDeleteEmpty(Candidate()), "zhCN system-body policy matches MoP")
locale = "enUS"; assert(not runtime:CanDeleteEmpty(Candidate())); locale = "zhCN"
complaint = true; assert(not runtime:CanDeleteEmpty(Candidate()))
complaint = nil; assert(not runtime:CanDeleteEmpty(Candidate())); complaint = false
box.headers[2].returned = true; assert(not runtime:CanDeleteEmpty(Candidate()))
box.headers[2].returned = false
box.headers[2].canReply = nil; assert(not runtime:CanDeleteEmpty(Candidate()))
box.headers[2].canReply = true; body = ""
invoice = true; assert(not runtime:CanDeleteEmpty(Candidate())); invoice = nil
local readText = e.GetInboxText
e.GetInboxText = function() error("unavailable") end
assert(not runtime:CanDeleteEmpty(Candidate())); e.GetInboxText = readText
for _, value in ipairs({ false, 0, "true" }) do
    permitted = value
    assert(not runtime:CanDeleteEmpty(Candidate()), "native deletion permission is required")
end
permitted = nil; assert(not runtime:CanDeleteEmpty(Candidate()))
permitted = 1; assert(runtime:CanDeleteEmpty(Candidate()))
permitted = true
for _, field in ipairs({ "money", "cod" }) do
    box.headers[2][field] = 1
    assert(not runtime:CanDeleteEmpty(Candidate()), "remaining value is preserved")
    box.headers[2][field] = 0
end
box.headers[2].isGM = true; assert(not runtime:CanDeleteEmpty(Candidate()))
box.headers[2].isGM = false
for _, kind in ipairs({ "seller", "buyer", "seller_temp_invoice" }) do
    e.GetInboxInvoiceInfo = function() return kind end
    assert(not runtime:CanDeleteEmpty(Candidate()), "auction mail is excluded")
end
e.GetInboxInvoiceInfo = nil
assert(not runtime:CanDeleteEmpty(assert(mail.Scanner:ReadTarget(1))), "remaining items are preserved")
local plan = assert(mail.Returns:PrepareEmptyDeletion())
assert(#plan.actions == 1 and plan.actions[1].original.inboxIndex == 2)
permitted = false
assert(not mail.Queue:StartReturn(plan) and calls == 0, "acceptance rechecks native permission")
permitted = true
plan = assert(mail.Returns:PrepareEmptyDeletion())
assert(mail.Queue:StartReturn(plan)); flush()
assert(calls == 1 and box.count == 1 and mail.Queue.completed == 1 and mail.Queue.state == "complete")
local current = core.Characters:GetCurrent()
assert(#mail.db.byCharacter[current.id].visibleKeys == 1, "confirmed cleanup updates the account snapshot")
assert(mail:T("EMPTY_MAIL.CONFIRM", 1):find("1", 1, true))
print("PASS: Forever matches MoP empty/body-bearing system policy; player text and unknown bodies preserved; native/value/GM/auction guards and snapshot update")
