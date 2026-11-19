local Boot = dofile("_NonRelease/MailForever/Harness.lua")
for _, cleanup in ipairs({ false, true }) do
    for _, refill in ipairs({ false, true }) do
        local calls = 0
        local e, core, mail, fire, flush, box = Boot(nil, function(e, _, box)
            box.total = 5
            box.headers[2].canReply = true
            e.InboxItemCanDelete = function() return cleanup end
            e.GetInboxText = function() return "" end
        end)
        local function Remove(index)
            assert(index == 2)
            calls = calls + 1
            e.C_Timer.After(0.04, function()
                table.remove(box.headers, index)
                box.count, box.total = box.count - 1, box.total - 1
                if refill then
                    box.headers[2] = { sender = "Other", subject = "Newly loaded", money = 0, cod = 0 }
                    box.count = 2
                end
                fire("MAIL_SUCCESS"); fire("MAIL_INBOX_UPDATE")
            end)
        end
        e.DeleteInboxItem, e.ReturnInboxItem = Remove, Remove
        fire("PLAYER_ENTERING_WORLD"); box.open = true; fire("MAIL_SHOW"); flush()
        local current = core.Characters:GetCurrent()
        local context = { characters = { current } }
        local plan
        if cleanup then plan = assert(mail.Returns:PrepareEmptyDeletion())
        else
            local selected = {}
            for _, entry in ipairs(mail.ViewModel:GetMails(context, {})) do
                if entry.mail.inboxIndex == 2 then selected[mail.Returns:MailID(entry)] = true end
            end
            plan = assert(mail.Returns:Prepare(selected, context))
        end
        assert(#plan.actions == 1 and mail.Queue:StartReturn(plan)); flush()
        assert(calls == 1 and mail.Queue.completed == 1 and mail.Queue.state == "complete",
            "partial inbox disposition must settle without waiting for a full 100-mail window")
        local state = mail.Items:GetState(current.id)
        assert(state.status == "partial" and state.totalCount == 4 and state.currentCount == (refill and 2 or 1))
        local count = 0
        for _, entry in ipairs(mail.db.byCharacter[current.id].history or {}) do
            if entry.state == "returned-archived" then count = count + 1 end
        end
        assert(count == (cleanup and 0 or 1), "only confirmed returns create return history")
    end
end
local e, core, mail, fire, flush, box = Boot(nil, function(e, _, box)
    box.total = 5; box.headers[2].canReply = true
    e.InboxItemCanDelete = function() return false end
    e.ReturnInboxItem = function() end
end)
fire("PLAYER_ENTERING_WORLD"); box.open = true; fire("MAIL_SHOW"); flush()
local current = core.Characters:GetCurrent()
local context, selected = { characters = { current } }, {}
for _, entry in ipairs(mail.ViewModel:GetMails(context, {})) do
    if entry.mail.inboxIndex == 2 then selected[mail.Returns:MailID(entry)] = true end
end
assert(mail.Queue:StartReturn(assert(mail.Returns:Prepare(selected, context))))
box.headers[2] = nil; box.count, box.total = 1, 4
local observed, visible, total = mail.Scanner:ReadVisible()
mail.Queue.pending.updated = true
assert(not mail.Queue:OnReturnScan(observed, visible, total, false), "disappearance requires native success")
mail.Queue.pending.success = true
assert(not mail.Queue:OnReturnScan(observed, visible, 5, false), "total count must prove removal")
box.headers[1].sender = "Changed sender"
observed, visible, total = mail.Scanner:ReadVisible()
assert(not mail.Queue:OnReturnScan(observed, visible, total, false), "retained partial prefix must match")
assert(mail.Queue.completed == 0)
fire("MAIL_CLOSED"); box.open = false; flush()
for _, entry in ipairs(mail.db.byCharacter[current.id].history or {}) do
    assert(entry.state ~= "returned-archived", "ambiguous disappearance is never confirmed return history")
end
print("PASS: Forever partial inbox return/cleanup, with and without refill, confirmed history and account coverage")
