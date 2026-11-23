local Boot = dofile("_NonRelease/MailForever/Harness.lua")
local DAY = 86400
local checks = 0
local function Check(result, message)
    checks = checks + 1
    assert(result, message)
end

for _, forever in ipairs({ false, true }) do
    local now, auctions, full, marketOpen, reads, queries = 100 * DAY, {}, true, false, 0, 0
    local e, core, mail, fire, flush, box, load = Boot(nil, function(env)
        env.GetServerTime = function() return now end
        env.MailFrame = env.CreateFrame("Frame", nil, env.UIParent)
        env.CheckInbox = function() end
        env.GetInboxInvoiceInfo = function() end
        env.AUCTION_EXPIRED_MAIL_SUBJECT = "Auction expired: %s"
        env.Enum = { BagIndex = { ReagentBag = 5 }, AuctionStatus = { Active = 0, Sold = 1 } }
        env.C_Container.GetContainerNumSlots = function() return 0 end
        env.C_Container.GetContainerItemInfo = function() return end
        env.C_Container.GetContainerNumFreeSlots = function() return 10, 0 end
        env.GetInventoryItemID = function() return end
        env.AuctionHouseFrame = { IsShown = function() return marketOpen end }
        env.C_AuctionHouse = {
            QueryOwnedAuctions = function() queries = queries + 1 end,
            GetNumOwnedAuctions = function() assert(marketOpen); reads = reads + 1; return #auctions end,
            GetOwnedAuctionInfo = function(index) return auctions[index] end,
            HasFullOwnedAuctionResults = function() return full end,
        }
    end, forever)
    local recipient = core.Characters:GetCurrent()
    local sender = { id = "Player-ExpirySender", name = forever and "Expiry Sender" or "Expirysender", realm = recipient.realm }
    local unscanned = { id = "Player-ExpiryUnscanned", name = "Unscanned", realm = recipient.realm }
    local active = sender
    local originalGet = core.Characters.Get
    core.Characters.Get = function(self, id, options)
        if id == sender.id then return sender end
        if id == unscanned.id then return unscanned end
        return originalGet(self, id, options)
    end
    core.Characters.GetCurrent = function() return active end
    core.Characters.GetCurrentID = function() return active.id end
    core.Characters.GetAllCached = function() return { sender, recipient, unscanned } end
    local context = { characters = { recipient } }
    local function Send(subject, amount, cod, attachments, succeeded, receiver)
        mail.Compose.pendingSend = { characterID = sender.id, recipient = (receiver or recipient).name, subject = subject, copper = amount,
            cod = cod, attachments = attachments, observedAt = now, state = "unverified" }
        fire(succeeded == false and "MAIL_FAILED" or "MAIL_SEND_SUCCESS")
    end
    local function Scan(headers, items, total)
        box.headers, box.items, box.count, box.total = headers, items or {}, #headers, total or #headers
        mail.Scanner.updated = true
        Check(mail.Scanner:Scan(true), "target scanner commits native headers")
        return mail.CacheModel:GetMails(context, { sort = "expiry" })
    end
    local function Coins(days)
        return { sender = sender.name, subject = "Coins", money = 88, cod = 0, days = days }
    end
    local function AuctionMail(days)
        return { sender = "Auction House", subject = "Auction expired: Item", money = 0, cod = 0, days = days, count = 1 }
    end
    local function Preview()
        local result = mail.Expiry:ReadAuctionTimings(context.characters)
        return mail.Expiry:GetPreview(recipient.id, result and result[recipient.id], now)
    end
    local function Times() return Preview().times end
    local function GoldLabel(copper) return mail:T("EXPIRY.PREVIEW_TRANSIT_MONEY", mail.ViewModel:Money(copper)) end
    local function MatchesPreview(text)
        local view = core.AccountView
        if view.frame and not view.frame.preview then view.frame:Hide() end
        assert(view:ShowPreview("mail-inbox", e.Minimap, true))
        local preview = view.frame.instances["mail-inbox"].mailPreview
        for _, row in ipairs(preview.mailRows) do
            if row:IsShown() then
                for _, cell in ipairs(row.cells) do
                    if cell:IsShown() and cell:GetText():find(text, 1, true) then return true end
                end
            end
        end
        return false
    end

    e.SendMail = function() end
    e.SendMailMoney = { copper = 88 }
    e.MoneyInputFrame_GetCopper = function(input) return input.copper end
    e.hooksecurefunc = function(name, callback)
        local native = e[name]
        e[name] = function(...) native(...); callback(...) end
    end
    mail.Compose:Install()
    e.hooksecurefunc = nil
    e.SendMail(recipient.name, "Coins")
    fire("MAIL_SEND_SUCCESS")
    Check(Preview().transitCopper == 88 and MatchesPreview(GoldLabel(88)), "native gold-only send appears in the hover")
    Send("COD", 125, true, { { itemID = 7003, quantity = 2 } })
    Send("Coins", 88, false, {})
    Send("Mixed", 110, false, { { itemID = 7004, quantity = 1 } })
    Send("Failed", 1, false, {}, false)
    Check(Times().send == 3 * DAY and not Times().listing and MatchesPreview(mail:T("EXPIRY.PREVIEW_TRANSIT", "~3.0d")), "Mail-only hover shows own sender countdown")
    Check(Preview().transitCopper == 286 and MatchesPreview(GoldLabel(286)), "gold-only and mixed sends add, excluding COD and failures")
    mail.db.settings.previewColumns.expires = false
    Check(MatchesPreview(GoldLabel(286)) and not MatchesPreview(mail:T("EXPIRY.PREVIEW_TRANSIT", "~3.0d")), "gold-only hover remains visible with the expiry column hidden")
    mail.db.settings.previewColumns.money = false
    Check(not MatchesPreview(GoldLabel(286)), "transit gold respects the existing money field setting")
    mail.db.settings.previewColumns.money = true
    mail.db.settings.previewColumns.expires = true
    Check(not mail.AccountPage:GetSummary(recipient) and #mail.CacheModel:GetMails(context) == 0,
        "unscanned recipient forecasts stay out of the normal account page and list")
    Check(#assert(mail.Items:GetByCharacter(recipient.id)).records == 0, "forecasts stay out of public inbox inventory")
    Check(not mail.Frame.events.OWNED_AUCTIONS_UPDATED and not mail.Frame.events.AUCTION_HOUSE_AUCTIONS_EXPIRED, "Mail registers no native auction events")
    marketOpen = true; fire("AUCTION_HOUSE_SHOW"); fire("OWNED_AUCTIONS_UPDATED")
    marketOpen = false; fire("AUCTION_HOUSE_CLOSED")
    Check(reads == 0 and queries == 0, "Mail never invokes native auction APIs")

    assert(core:RegisterAddon("LegacyVault", { version = "1.0", requiredAPI = 14 }))
    local oldRef = assert(core.Contracts:Register("LegacyVault", {
        name = "vault.items", kind = "service", providerID = "LegacyVault:inventory", version = { major = 1, minor = 1 },
        methods = { GetAuctionTimings = function() error("incompatible provider invoked") end },
    }))
    Check(not mail.Expiry:ReadAuctionTimings(context.characters) and Times().send == 3 * DAY, "legacy Vault skipped, own countdown retained")
    assert(core.Contracts:Unregister("LegacyVault", oldRef))

    active = recipient
    fire("PLAYER_ENTERING_WORLD"); flush()
    box.headers, box.items, box.count, box.total, box.open = {}, {}, 0, 1, true
    fire("MAIL_SHOW"); flush()
    now = now + 2 * 3600
    local entries = Scan({ Coins(29) }, {}, 4)
    Check(#entries == 1 and entries[1].mail.expiresAtEstimate == now + 29 * DAY and Times().send == 3 * DAY - 7200,
        "native scan uses its own deadline and reconciles the first matching envelope")
    Check(Preview().transitCopper == 198 and MatchesPreview(mail.ViewModel:Money(88) .. " · " .. GoldLabel(198))
        and mail.AccountPage:GetSummary(recipient).money == mail.ViewModel:Money(88),
        "one scanned letter moves from transit into available gold without double counting")
    local snapshot = mail.db.byCharacter[recipient.id]
    local function PendingSends()
        local count = 0
        for _, entry in pairs(snapshot.expiryEntries or {}) do if entry.expirySource == "send" then count = count + 1 end end
        return count
    end
    Check(PendingSends() == 3, "one of two identical gold forecasts consumed")
    Scan({ Coins(29) }, {}, 4)
    Check(PendingSends() == 3 and Preview().transitCopper == 198, "repeat partial scan does not consume the second identical forecast")
    local cod = { sender = sender.name, subject = "COD", money = 0, cod = 125, days = 2, count = 1 }
    local mixed = { sender = sender.name, subject = "Mixed", money = 110, cod = 0, days = 29, count = 1 }
    entries = Scan({ Coins(29), Coins(29), cod, mixed }, { [3] = { { id = 7003, quantity = 2 } }, [4] = { { id = 7004, quantity = 1 } } })
    Check(#entries == 4 and not Times().send and Preview().transitCopper == 0 and not MatchesPreview(GoldLabel(198)),
        "complete scan settles both identical sends, a mixed send and COD")
    local nativeExpiry = now + 2 * DAY
    now = nativeExpiry + 3600
    entries = Scan({ Coins(27), Coins(27) })
    Check(#entries == 2 and Times().missing == -3600 and MatchesPreview(mail:T("EXPIRY.PREVIEW_UNVERIFIED", "-1.0h")), "vanished native mail is signed in the hover")
    Check(mail.AccountPage:GetSummary(recipient)._counts.expired == 0 and not mail.AccountPage:GetSummary(recipient).expires:find("-", 1, true),
        "normal account and login summary remain scoped to the current inbox snapshot")
    fire("PLAYER_LOGIN"); flush()
    Check(not mail.db.settings.loginReminderState, "hover-only overdue mail does not trigger login reminders")

    box.open = false; fire("MAIL_CLOSED")
    for line in io.lines("YiboVault/YiboVault_" .. (forever and "Forever" or "Mists") .. ".toc") do
        if line:match("%.lua%s*$") then load("YiboVault/" .. line:gsub("[\r\n]", ""):gsub("\\", "/"), "YiboVault") end
    end
    fire("ADDON_LOADED", "YiboVault")
    local vault = e.YiboVault
    Check(vault.initialized and mail.Expiry:ReadAuctionTimings(context.characters)[recipient.id].status == "not-yet-scanned",
        "late Vault registration supplies the compatible empty coverage")
    fire("PLAYER_ENTERING_WORLD"); flush()

    local function VaultMail(character)
        local view = core.AccountView
        view:HidePreview()
        view:ShowPage("vault-items")
        view.frame:Show()
        local host = view.frame.instances["vault-items"]
        Check(view.activePageID == "vault-items" and host, "open the real Vault page")
        local page = forever and host or host.yiboVaultStoragePage
        if forever then
            vault.db.settings.foreverSource, page.selectedCharacter = "mail", character.id
        else
            page.area, page.selectedOwner = "mail", character.id
        end
        view:RefreshPage()
        flush()
        return page
    end
    local scope = { mode = "characters", characterIDs = { recipient.id } }
    local function Inventory()
        return assert(vault.Items:Query({ scope = scope, sources = { "mail" } }))
    end
    local function VaultGold(copper) return vault:T("MAIL.TRANSIT_MONEY", copper / 10000) end
    Send("Gold to unscanned role", 500, false, {}, true, unscanned)
    local otherPage = VaultMail(unscanned)
    Check(otherPage.transitMoney:IsShown() and otherPage.transitMoney:GetText() == VaultGold(500),
        "Vault admits a recipient with gold and no observed warehouse or mailbox")
    local page = VaultMail(recipient)
    Check(not page.transitMoney:IsShown(), "another recipient's gold is excluded")
    Send("Vault gold only", 20001, false, {})
    flush()
    local inventory = Inventory()
    Check(page.transitMoney:IsShown() and page.transitMoney:GetText() == VaultGold(20001),
        "gold-only change refreshes the open Vault mail view")
    Check(#inventory.records == 0 and #inventory.transitRecords == 0 and inventory.totals.totalQuantity == 0
        and inventory.totals.inTransitQuantity == 0, "gold-only transfer adds no item record or inventory quantity")
    Send("Vault mixed", 125, false, { { itemID = 7020, quantity = 2 } })
    Send("Vault COD", 999, true, { { itemID = 7021, quantity = 1 } })
    flush()
    inventory = Inventory()
    Check(page.transitMoney:GetText() == VaultGold(20126) and #inventory.transitRecords == 2 and inventory.totals.inTransitQuantity == 3
        and inventory.totals.totalQuantity == 0 and inventory.totals.externalQuantity == 0,
        "mixed parcels add only their real item quantities and COD does not increase the amount")
    box.open = true; fire("MAIL_SHOW")
    local gold = { sender = sender.name, subject = "Vault gold only", money = 20001, cod = 0, days = 29 }
    local parcel = { sender = sender.name, subject = "Vault mixed", money = 125, cod = 0, days = 29, count = 1 }
    local vaultCOD = { sender = sender.name, subject = "Vault COD", money = 0, cod = 999, days = 2, count = 1 }
    Scan({ gold, parcel, vaultCOD }, { [2] = { { id = 7020, quantity = 2 } }, [3] = { { id = 7021, quantity = 1 } } })
    flush()
    inventory = Inventory()
    Check(not page.transitMoney:IsShown() and #inventory.transitRecords == 0 and #inventory.records == 2
        and inventory.totals.totalQuantity == 3 and inventory.totals.externalQuantity == 3,
        "scanning removes the separate gold total while only the actual item enters inventory")
    Scan({}); flush()
    Send("Vault missing gold", 411, false, {})
    flush()
    Check(page.transitMoney:GetText() == VaultGold(411), "an empty inbox does not prevent a later gold transfer from displaying")
    now = now + 3601
    Scan({}); flush()
    Check(not page.transitMoney:IsShown(), "an unchanged complete inbox still publishes the removal of an unobserved gold estimate")
    box.open = false; fire("MAIL_CLOSED")
    local function Auction(id, seconds, status, bid, itemID)
        return { auctionID = id, status = status or 0, timeLeftSeconds = seconds, itemKey = { itemID = itemID or 7000 + id }, quantity = 2, bidAmount = bid }
    end
    local function Timings()
        return mail.Expiry:ReadAuctionTimings(context.characters)[recipient.id]
    end
    auctions = { Auction(1, 240), Auction(2, nil), Auction(3, 120, 0, 10), Auction(4, 90), Auction(5, 150), Auction(6, 260, nil, nil, 7001) }
    marketOpen = true; fire("AUCTION_HOUSE_SHOW"); flush()
    fire("OWNED_AUCTIONS_UPDATED"); flush()
    Check(queries == 1 and #Timings().records == 4 and Times().listing == 90 + 30 * DAY and MatchesPreview(mail:T("EXPIRY.PREVIEW_IF_UNSOLD", "~30.0d")),
        "Vault uses one real collection path and publishes timestamped no-bid listings")
    local records = Timings().records
    records[1].quantity = 999
    for _, record in ipairs(Timings().records) do Check(record.quantity == 2, "Core returns an isolated timing snapshot") end
    local readsBeforePreview = reads
    Check(MatchesPreview(mail:T("EXPIRY.PREVIEW_IF_UNSOLD", "")) and reads == readsBeforePreview, "hover only reads the Vault contract")
    auctions[4] = Auction(4, nil, 1)
    full = false; fire("OWNED_AUCTIONS_UPDATED"); flush()
    Check(#Timings().records == 4, "incomplete owned list does not erase timing facts")
    full = true; fire("OWNED_AUCTIONS_UPDATED"); flush()
    fire("AUCTION_CANCELED", 5); flush()
    Check(#Timings().records == 2 and Times().listing == 240 + 30 * DAY, "Vault withdraws sold and cancelled listings")
    auctions = {}
    now = now + 240
    fire("OWNED_AUCTIONS_UPDATED"); flush()
    Check(#Timings().records == 0 and not Times().auction, "missing listing alone never confirms expiry")
    marketOpen = false; fire("AUCTION_HOUSE_CLOSED"); flush()
    fire("AUCTION_HOUSE_AUCTIONS_EXPIRED", 1); fire("AUCTION_HOUSE_AUCTIONS_EXPIRED", 2)
    fire("AUCTION_HOUSE_AUCTIONS_EXPIRED", 6); fire("AUCTION_HOUSE_AUCTIONS_EXPIRED", 999)
    flush()
    Check(#Timings().records == 3 and Times().auction == 30 * DAY and MatchesPreview(mail:T("EXPIRY.PREVIEW_AUCTION_RETURN", "~30.0d")),
        "confirmed native expiry publishes after inventory removal, including a previously band-only lot")
    for _, entry in pairs(snapshot.expiryEntries) do Check(entry.expirySource ~= "auction", "Mail never stores a Vault forecast as a mail record") end

    box.open = true; fire("MAIL_SHOW")
    local actualItems = { { { id = 7001, quantity = 2 } }, { { id = 7001, quantity = 2 } } }
    entries = Scan({ AuctionMail(28) }, actualItems)
    Check(#entries == 1 and entries[1].mail.expiresAtEstimate == now + 28 * DAY and Times().auction == 30 * DAY,
        "one real auction letter uses native time and consumes only one forecast")
    entries = Scan({ AuctionMail(28), AuctionMail(28), AuctionMail(28) },
        { actualItems[1], actualItems[2], { { id = 7002, quantity = 2 } } })
    Check(#entries == 3 and not Times().auction and not MatchesPreview(mail:T("EXPIRY.PREVIEW_AUCTION_RETURN", "")), "all scanned auction forecasts disappear from hover")
    Check(MatchesPreview("~28.0d"), "hover uses the actual native time after reconciliation")
    Scan({})
    Check(not Times().auction, "already scanned auction mail does not return as a ghost estimate")

    local saved = mail.Copy(mail.db)
    saved.byCharacter[recipient.id].expiryEntries["auction:legacy"] = { expirySource = "auction", expiresAtEstimate = now + DAY }
    local _, _, restarted = Boot(saved, function(env) env.GetServerTime = function() return now end end, forever)
    Check(not restarted.db.byCharacter[recipient.id].expiryEntries["auction:legacy"]
        and restarted.db.byCharacter[recipient.id].auctionExpiryReceipts[mail.Encode({7001, 2})][1].count == 2,
        "old Mail auction cache removed, native mail multiplicity survives restart")

    box.open = false; fire("MAIL_CLOSED")
    marketOpen = true; auctions = { Auction(7, 60) }
    fire("AUCTION_HOUSE_SHOW"); flush(); fire("OWNED_AUCTIONS_UPDATED"); flush()
    marketOpen = false; fire("AUCTION_HOUSE_CLOSED"); flush()
    now = now + 60
    fire("AUCTION_HOUSE_AUCTIONS_EXPIRED", 7)
    active = sender
    Send("Never seen", 1, false, {})
    active = recipient
    now = now + 31 * DAY
    box.open = true; fire("MAIL_SHOW")
    Scan({})
    Check(Times().send == -DAY and MatchesPreview(mail:T("EXPIRY.PREVIEW_UNVERIFIED", mail:T("EXPIRY.PREVIEW_TRANSIT", "-1.0d"))), "unseen in-transit deadline survives a late empty scan")
    Check(Preview().transitCopper == 0 and not MatchesPreview(GoldLabel(1)), "overdue money is not displayed as still in transit")
    Check(Times().auction == -DAY and MatchesPreview(mail:T("EXPIRY.PREVIEW_UNVERIFIED", mail:T("EXPIRY.PREVIEW_AUCTION_RETURN", "-1.0d"))),
        "unseen confirmed auction return is signed and remains unverified after the deadline")
    Check(core.Contracts:Unregister(vault.NAME, vault.Items.serviceRef) and not mail.Expiry:ReadAuctionTimings(context.characters)
        and Times().send == -DAY, "Vault removal leaves local hover data available")
    VaultMail(unscanned)
    Check(core.Contracts:Unregister(mail.NAME, mail.Items.serviceRef), "Mail service can be removed")
    flush()
    Check(not page.transitMoney:IsShown(), "Vault drops the separate amount when Mail is removed")
    local methods = {}
    for key, method in pairs(mail.Items.serviceDefinition.methods) do if key ~= "GetTransitMoney" then methods[key] = method end end
    assert(core.Contracts:Register(mail.NAME, { name = "mail.items", kind = "service", providerID = "YiboMail:inbox",
        version = { major = 1, minor = 1 }, methods = methods }))
    Check(not next(vault.Items:GetMailTransitMoney(scope)) and Inventory().totals.totalQuantity == 0,
        "older Mail supplies item data and leaves gold unavailable")
end
print(string.format("Mail and Vault transit/expiry: %d checks across Mists and Forever", checks))
