local Boot = dofile("_NonRelease/MailForever/Harness.lua")
for _, language in ipairs({ "zhCN", "enUS" }) do
    local buyer, invoice, metadata = "Buyer-Realm", "seller", false
    local templates = language == "zhCN" and {
        "拍卖成功：%s", "拍卖到期：%s", "拍卖取消：%s", "竞拍成功：%s", "竞价被超过：%s", "拍卖发票：%s",
    } or { "Sold: %s", "Expired: %s", "Cancelled: %s", "Won: %s", "Outbid: %s", "Invoice: %s" }
    local keys = { "AUCTION_SOLD_MAIL_SUBJECT", "AUCTION_EXPIRED_MAIL_SUBJECT", "AUCTION_REMOVED_MAIL_SUBJECT",
        "AUCTION_WON_MAIL_SUBJECT", "AUCTION_OUTBID_MAIL_SUBJECT", "AUCTION_INVOICE_MAIL_SUBJECT" }
    local e, core, mail, fire, flush, box = Boot(nil, function(e, core, box)
        for i, key in ipairs(keys) do e[key] = templates[i] end
        core.Locale.language = language == "zhCN" and "en" or "zh"
        box.headers[1].subject = string.format(templates[1], "Item [A]+(B)%")
        box.headers[1].canReply, box.headers[2].canReply = true, true
        e.InboxItemCanDelete = function() return false end
        e.GetInboxInvoiceInfo = function(index) if index == 1 then return invoice, "Item", buyer end end
        local original = e.GetInboxItem
        e.GetInboxItem = function(index, slot)
            local name, id, _, quantity = original(index, slot)
            if name then return metadata and ("ObservedItem" .. id) or nil, id, metadata and (90000 + id) or nil, quantity end
        end
    end)
    fire("PLAYER_ENTERING_WORLD"); box.open = true; fire("MAIL_SHOW"); flush()
    local current = core.Characters:GetCurrent()
    local context = { characters = { current } }
    local snapshot = mail.db.byCharacter[current.id]
    local key = snapshot.visibleKeys[1]
    assert(snapshot.records[key].auctionPlayer == buyer and snapshot.records[key].auctionMail)
    local revision = mail.Items:GetRevision()
    local historyCount = #snapshot.history
    metadata = true
    fire("MAIL_INBOX_UPDATE"); flush()
    assert(snapshot.visibleKeys[1] == key and #snapshot.history == historyCount, "metadata cannot fabricate a new letter")
    assert(mail.Items:GetRevision() > revision, "late native metadata invalidates public snapshots")
    local item = snapshot.records[key].attachments[1]
    assert(item.name == "ObservedItem7001" and item.texture == 97001)
    assert(mail.Items:GetByCharacter(current.id).records[1].name, "public mail records retain native names")
    assert(#mail.CacheModel:GetMails(context, { search = "ObservedItem7001" }) == 1)
    local groups = mail.CacheModel:GetGroups(mail.CacheModel:GetMails(context, {}))
    assert(#groups == 2 and groups[1].item.texture and groups[1].item.name)
    for i, template in ipairs(templates) do
        box.headers[2].subject = string.format(template, "Item [A]+(B)%")
        fire("MAIL_INBOX_UPDATE"); flush()
        local observed = assert(mail.Scanner:ReadTarget(2))
        assert(observed.auctionMail and not mail.Returns:CanReturn(observed), "invoice-free auction letters cannot be returned")
        assert(#mail.CacheModel:GetMails(context, { source = "auction" }) == 2)
        assert(#mail.CacheModel:GetMails(context, { source = "player" }) == 0)
    end
    box.headers[2].subject = "Ordinary player letter"
    fire("MAIL_INBOX_UPDATE"); flush()
    assert(not mail.Scanner:ReadTarget(2).auctionMail and #mail.CacheModel:GetMails(context, { source = "player" }) == 1)
    for _, kind in ipairs({ "seller", "seller_temp_invoice", "buyer" }) do
        invoice = kind; buyer = "ChangedBuyer-Realm"
        revision = mail.Items:GetRevision()
        fire("MAIL_INBOX_UPDATE"); flush()
        local observed = snapshot.records[key]
        assert(observed.auctionPlayer == (kind ~= "buyer" and buyer or nil))
        if kind == "seller" then assert(mail.Items:GetRevision() > revision, "late invoice identity invalidates account data") end
    end
    invoice = "seller"; buyer = "Buyer-Realm"; fire("MAIL_INBOX_UPDATE"); flush()
    e.C_Container.GetContainerNumFreeSlots = function() return 10, 0 end
    e.TakeInboxItem = function(index, slot)
        e.C_Timer.After(0.04, function()
            box.items[index][slot] = nil; box.headers[index].count = box.headers[index].count - 1
            fire("MAIL_SUCCESS"); fire("MAIL_INBOX_UPDATE")
        end)
    end
    local entry
    for _, value in ipairs(mail.ViewModel:GetMails(context, {})) do if value.mail.inboxIndex == 1 then entry = value end end
    local selected = { [mail.ViewModel:ActionID(current.id, entry.key, 1)] = true }
    assert(mail.Queue:Start(assert(mail.Queue:Prepare(selected, context)))); flush()
    assert(mail.Queue.completed == 1 and mail.Queue.state == "complete")
    local rows = mail.HistoryModel:Query(context, { kind = "auction", result = "auction-success" })
    assert(#rows == 1 and rows[1].mail.auctionPlayer == buyer)
    assert(rows[1].items[1].name == "ObservedItem7001" and rows[1].items[1].texture == 97001)
    local saved = mail.Copy(mail.db)
    local restored, core2, mail2, _, _, box2 = Boot(saved)
    local context2 = { characters = { core2.Characters:GetCurrent() } }
    assert(box2.reads == 0, "offline browsing must not scan")
    assert(#mail2.CacheModel:GetMails(context2, { search = "ObservedItem7002" }) == 1)
    rows = mail2.HistoryModel:Query(context2, { kind = "auction" })
    assert(#rows == 1 and rows[1].mail.auctionPlayer == buyer and rows[1].items[1].texture == 97001)
end
local _, core, mail, fire, flush, box = Boot(nil, function(_, _, box) box.headers[1].sender = nil end)
fire("PLAYER_ENTERING_WORLD"); box.open = true; fire("MAIL_SHOW"); flush()
local current = core.Characters:GetCurrent()
assert(#mail.ViewModel:GetMails({ characters = { current } }, { search = "Parcel" }) == 1,
    "a temporarily unknown sender cannot break the ordinary inbox search")
print("PASS: Forever native auction templates/invoices, late metadata publication, item search/groups, confirmed history and offline restoration")
