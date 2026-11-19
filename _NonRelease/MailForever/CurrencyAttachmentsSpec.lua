local Boot = dofile("_NonRelease/MailForever/Harness.lua")
local events, takes = {}, 0
local e, core, mail, fire, flush, box, load
e, core, mail, fire, flush, box, load = Boot(nil, function(e, _, box)
    local methods = getmetatable(e.UIParent).__index
    methods.GetRegions = function() return end
    methods.SetParent = function(self, parent) self.parent = parent end
    e.MailFrame = e.CreateFrame("Frame", nil, e.UIParent); e.MailFrame:Hide()
    e.InboxFrame = e.CreateFrame("Frame", nil, e.MailFrame)
    e.SendMailFrame = e.CreateFrame("Frame", nil, e.MailFrame); e.SendMailFrame:Hide()
    for _, name in ipairs({ "SendMailNameEditBox", "SendMailSubjectEditBox", "SendMailBodyEditBox",
        "SendMailCancelButton", "SendMailMailButton", "SendMailMoney", "SendMailCODButton" }) do
        e[name] = e.CreateFrame("Button", nil, e.SendMailFrame)
    end
    e.SendMailMailButton:SetScript("OnClick", function() error("no sending in this test") end)
    e.GetMoney = function() return 10000 end
    e.GetSendMailItem = function() return end
    e.MoneyInputFrame_GetCopper = function() return 0 end
    e.GetInboxText = function() return "" end
    e.InboxItemCanDelete = function() return true end
    box.total = 3
    box.headers[2].count = 1
    box.items[1][16] = { id = 7001, quantity = 25, currency = true }
    box.items[2] = { [1] = { id = 9002, quantity = 11, currency = true } }
    e.GetInboxItem = function(index, slot)
        local item = box.items[index] and box.items[index][slot]
        if item then return item.currency and (not item.noName and "Token" .. item.id or nil) or "NativeItem" .. item.id,
            item.id, 654, item.quantity, 1, true, item.currency end
    end
    e.GetInboxItemLink = function(index, slot)
        local item = box.items[index] and box.items[index][slot]
        if not item then return end
        if item.currency then return item.id == 9002 and "|cffffffff|Hcurrency:9002:0|h[Token]|h|r" or nil end
        return "item:" .. item.id
    end
    e.C_Container.GetContainerNumFreeSlots = function() error("currency collection must not require bag space") end
    e.TakeInboxItem = function(index, slot)
        assert(slot == 16 and index == 1, "only the explicitly selected currency slot is taken")
        takes = takes + 1
        e.C_Timer.After(0.04, function()
            box.items[index][slot] = nil; box.headers[index].count = box.headers[index].count - 1
            fire("MAIL_SUCCESS"); fire("MAIL_INBOX_UPDATE")
        end)
    end
end)
mail.Items.Events:Register({}, function(_, payload) events[#events + 1] = payload end)
local resolver = core.ItemResolver.GetInfo
core.ItemResolver.GetInfo = function(self, id)
    assert(id ~= nil and id ~= 9002, "currency must not enter the item resolver")
    return resolver(self, id)
end
fire("PLAYER_ENTERING_WORLD"); box.open = true; e.MailFrame:Show(); fire("MAIL_SHOW"); flush()
local current = core.Characters:GetCurrent()
local context = { characters = { current } }
local alt = { id = "Player-CurrencySender", name = "Sender", realm = current.realm, faction = current.faction }
core.Characters.GetAllCached = function() return { current, alt } end
mail:AddHistory(alt.id, { state = "in-transit", recipient = current.name .. "-" .. current.realm,
    subject = "Letter", observedAt = mail:Now(), senderFaction = current.faction,
    attachments = { { itemID = 9002, quantity = 11, itemKey = "item:9002", variantKey = "item:9002" } } })
assert(#mail.Items:GetTransfers(current.id).records == 1,
    "a currency receipt cannot consume a pending item transfer with the same ID and quantity")
assert(mail.Items:GetState(current.id).status == "partial" and mail.AccountPage:GetSummary(current).count == "2/3")
local entries = mail.CacheModel:GetMails(context, { kind = "currency" })
assert(#entries == 2 and mail.AccountPage:GetSummary(current).attachments == "3")
local groups = mail.CacheModel:GetGroups(entries)
assert(#groups == 3, "item and currency with the same ID remain distinct groups")
local currency, entry
for _, value in ipairs(mail.ViewModel:GetMails(context, { kind = "currency" })) do
    if value.mail.inboxIndex == 1 then entry = value; currency = value.mail.attachments[2] end
end
assert(currency.currencyID == 7001 and not currency.itemID and not currency.itemKey and currency.variantKey == "currency:7001")
assert(mail.Items:GetByCharacter(current.id).quantity == 3 and mail.Items:GetByCharacter(current.id, { itemID = 7001 }).quantity == 3,
    "public item API cannot include currency quantity")
local invalid, reason = mail.Items:GetByCharacter(current.id, { variantKey = "currency:7001" })
assert(not invalid and reason == "invalid-variant-key", "currency keys do not become item API keys")
for _, event in ipairs(events) do for _, id in ipairs(event.changedItemIDs) do assert(id ~= 9002) end end
assert(#mail.CacheModel:GetMails(context, { search = "Token9002" }) == 1)
assert(#mail.CacheModel:GetMails(context, { search = "9002" }) == 1)
assert(not mail.CollectionRuntime:CanDeleteEmpty(assert(mail.Scanner:ReadTarget(2))), "currency-only mail is not empty")
e.SlashCmdList.YIBOMAIL(""); flush()
local workspace = core.AccountView.frame.instances["mail-inbox"].mailWorkspace
workspace.kind.onValueChanged("currency"); flush()
assert(#workspace.data == 2, "account currency filter renders the two currency-bearing mails")
workspace.items:GetScript("OnClick")(); flush()
assert(#workspace.data == 3, "account attachment summary keeps item/currency namespaces distinct")
assert(mail.NativeUI.inbox.used > 0, "native inbox renders typed currency attachments")
mail.NativeUI.inbox.filter.onValueChanged("currency"); flush()
assert(mail.NativeUI.inbox.options.kind == "currency")
local ui = mail.CacheUI
local positions = ui:ItemLayout({ itemList = { currency } }, 300)
assert(#positions == 1)
local tooltip = ui:AttachmentTooltip({ item = currency, quantity = 25, mailCount = 1, normalQuantity = 25,
    codQuantity = 0, sources = { { entry = entry, item = currency } } })
assert(tooltip[1]:find("Token7001", 1, true))
assert(mail.ViewModel:AttachmentLink(currency) == "currency:7001")
for _, language in ipairs({ "zh", "en" }) do
    core.Locale.language = language
    local unknown = { currencyID = 9002, quantity = 11, variantKey = "currency:9002" }
    assert(mail.CacheModel:ItemName(unknown):find("9002", 1, true))
    local _, pending = mail.ViewModel:ItemBorder(unknown); assert(not pending)
end
local selected = { [mail.ViewModel:ActionID(current.id, entry.key, 16)] = true }
assert(mail.Queue:Start(assert(mail.Queue:Prepare(selected, context)))); flush()
assert(takes == 1 and mail.Queue.completed == 1 and mail.Queue.state == "complete")
assert(mail.Items:GetByCharacter(current.id).quantity == 3, "currency collection leaves the colliding item untouched")
local rows = mail.HistoryModel:Query(context, { content = "currency" })
assert(#rows == 1 and rows[1].items[1].currencyID == 7001 and rows[1].items[1].quantity == 25)
assert(#mail.HistoryModel:Query(context, { content = "text" }) == 0)
assert(mail.HistoryModel:Content(rows[1]):find("Token7001", 1, true))
for _, event in ipairs(events) do for _, id in ipairs(event.changedItemIDs) do assert(id ~= 9002) end end
e.C_Container.GetContainerNumSlots = function() return 0 end
e.C_Container.GetContainerItemInfo = function() return end
e.C_Container.GetContainerNumFreeSlots = function() return 0, 0 end
e.GetInventoryItemID = function() return end
for line in io.lines("YiboVault/YiboVault_Forever.toc") do
    line = line:gsub("\r", "")
    if line:match("%.lua$") then load("YiboVault/" .. line:gsub("\\", "/"), "YiboVault") end
end
fire("ADDON_LOADED", "YiboVault")
assert(e.YiboVault.Items:Query({ sources = { "mail" } }).totals.totalQuantity == 3,
    "Vault reads only ordinary items through the unchanged public contract")
local ordinary = box.items[1][1]
box.items[1][1] = nil; box.headers[1].count = 0; fire("MAIL_INBOX_UPDATE"); flush()
assert(e.YiboVault.Items:Query({ sources = { "mail" } }).totals.totalQuantity == 0,
    "a currency-only source does not fall back to interpreting currency as an item")
box.items[1][1] = ordinary; box.headers[1].count = 1; fire("MAIL_INBOX_UPDATE"); flush()
local saved = mail.Copy(mail.db)
local _, core2, mail2, _, _, box2 = Boot(saved)
local context2 = { characters = { core2.Characters:GetCurrent() } }
assert(box2.reads == 0 and #mail2.CacheModel:GetMails(context2, { kind = "currency" }) == 1)
assert(#mail2.HistoryModel:Query(context2, { content = "currency" }) == 1)
assert(mail2.Items:GetByCharacter(e.TEST_GUID, { includeStale = true }).quantity == 3)
mail2.db.settings.unverifiedDays = 1
local live = mail2.db.byCharacter[e.TEST_GUID]
live.records.legacyCurrency = mail2.Copy(live.records[live.visibleKeys[2]])
live.records.legacyCurrency.state, live.records.legacyCurrency.stateEnteredAt = "unverified", -1000000
mail2:PruneHistory()
assert(not live.records.legacyCurrency, "retention cleanup handles currency records")
assert(mail2:DeleteCharacter(core2.Characters:GetCurrent()), "typed attachment cleanup does not index nil item IDs")
print("PASS: Forever currency scan/namespace, mixed summaries, UI, selection/collection/history, persistence and item/Vault isolation")
