local BootCore = dofile("_NonRelease/CoreForever/Harness.lua")
local checks = 0
local function Check(ok, label) checks = checks + 1; assert(ok, label) end
local function Boot(saved, coreSaved, configure, forever)
    if forever == nil then forever = true end
    local env, core, event, _, load = BootCore(forever, coreSaved)
    env.TEST_GUID = "Player-Test-1"
    local clock = 100
    env.GetTime = function() return clock end
    event("ADDON_LOADED"); event("PLAYER_LOGIN")
    env.YiboVaultDB = forever and { sentinel = "mists" } or saved
    env.YiboVaultForeverDB = forever and saved or { sentinel = "forever" }
    env.Enum = { BagIndex = { ReagentBag = 5 } }
    local data = { bags = { [0] = { [1] = { itemID = 6948, stackCount = 1 }, [2] = { itemID = 42, stackCount = 3 } },
        [1] = { [1] = { itemID = 43, stackCount = 1 } } }, equipment = { [7] = 271666, [16] = 3661 }, reads = 0 }
    env.C_Container = {
        GetContainerNumSlots = function(bag)
            Check(bag >= 0 and bag <= 5, "no bank container scanned")
            if data.fail then error("simulated container error") end
            return bag == 0 and 3 or (bag == 1 and 1 or 0)
        end,
        GetContainerItemInfo = function(bag, slot)
            data.reads = data.reads + 1
            return data.bags[bag] and data.bags[bag][slot]
        end,
        GetContainerNumFreeSlots = function(bag)
            local count = bag == 0 and 3 or (bag == 1 and 1 or 0)
            for _ in pairs(data.bags[bag] or {}) do count = count - 1 end
            return count
        end,
    }
    env.GetInventoryItemID = function(unit, slot)
        Check(unit == "player" and slot >= 1 and slot <= 19, "equipment scope bounded")
        return data.equipment[slot]
    end
    env.GetInventoryItemLink = function(_, slot) local id = data.equipment[slot]; return id and ("item:" .. id) end
    env.C_Item.GetItemInfo = function(id) return "NativeItem" .. id, "item:" .. id end
    local function Flush()
        local guard = 0
        while #env.TEST_TIMERS > 0 do
            guard = guard + 1; assert(guard < 30, "unbounded timer loop")
            local pending = env.TEST_TIMERS; env.TEST_TIMERS = {}
            table.sort(pending, function(a, b) return a[1] < b[1] end)
            for _, timer in ipairs(pending) do clock = clock + timer[1]; timer[2]() end
        end
    end
    if configure then configure(env, core) end
    for line in io.lines("YiboVault/" .. (forever and "YiboVault_Forever.toc" or "YiboVault.toc")) do
        line = line:gsub("\r", "")
        if line:match("%.lua$") then load("YiboVault/" .. line:gsub("\\", "/"), "YiboVault") end
    end
    event("ADDON_LOADED", "YiboVault")
    return env, core, env.YiboVault, event, Flush, data
end
local env, core, vault, event, flush, data = Boot()
Check(vault.initialized and vault.VERSION == "0.6.0-api1", "Vault initialized on actual Core")
Check(env.YiboVaultDB.sentinel == "mists" and not env.YiboVaultDB.byCharacter, "MoP saved table untouched")
Check(vault.Items:HasCapability("source.bags", 1) and vault.Items:HasCapability("source.bank", 1), "honest source capabilities")
Check(not vault.GuildBank and not vault.MailItems and not vault.AuctionHouse, "unsupported modules not loaded")
Check(vault.Frame.events.BANKFRAME_OPENED and vault.Frame.events.MAIL_SHOW, "bank and mail context events registered")
event("PLAYER_ENTERING_WORLD")
Check(not next(vault.db.byCharacter), "no immediate entry-time snapshot")
env.SlashCmdList.YIBOVAULT("scan")
Check(not next(vault.db.byCharacter), "early manual scan cannot establish empty baseline")
-- Suppress all object data until after the first deferred scan.
local bags, equipment = data.bags, data.equipment
data.bags, data.equipment = {}, {}
flush()
Check(not next(vault.db.byCharacter), "unready all-empty entry result remains unknown")
data.bags, data.equipment = bags, equipment
event("BAG_UPDATE_DELAYED"); event("UNIT_INVENTORY_CHANGED", "player"); flush()
local query = assert(vault.Items:Query({ sources = { "bags", "equipment" } }))
Check(#query.records == 5 and query.totals.totalQuantity == 7, "all bags and equipment collected")
Check(vault:GetCharacterCoverage(env.TEST_GUID, "bags")["5"].completedScan, "native reagent bag included")
query.records[1].quantity = 999
Check(vault.Items:Query({ sources = { "bags", "equipment" } }).totals.totalQuantity == 7, "query cannot mutate inventory authority")
local unsupported, why = vault.Items:Query({ scope = { mode = "account" } })
Check(not unsupported and why == "scope-not-supported", "account query unavailable")
unsupported, why = vault.Items:Query({ scope = { mode = "characters", characterIDs = { "OtherGUID" } } })
Check(not unsupported and why == "scope-not-supported", "other-character query unavailable")
Check(vault.AccountPage:Status("bank", env.TEST_GUID) == "bank_pending", "unvisited bank has no completed coverage")
Check(not vault.Items:HasCapability("items.personal-counts", 1) and not vault.Items:GetPersonalCounts({}), "unimplemented count contract not claimed")
core:RegisterAddon("VaultTestConsumer", { requiredAPI = 13 })
local descriptor = assert(core.Contracts:Resolve("vault.items", { major = 1, minMinor = 1 }))
local fromService = assert(core.Contracts:Call("VaultTestConsumer", descriptor, "Query", { sources = { "equipment" } }))
Check(#fromService.records == 2, "cross-plugin query routed through Core")
env.SlashCmdList.YIBOVAULT("open"); flush()
Check(core.AccountView.activePageID == "vault-items", "window opens through Core")
local page = core.AccountView.frame.instances["vault-items"]
Check(#page.renderedRecords == 3 and page.renderedStatus == "known", "bag rows visible")
Check(page.tabs.bags.label:GetText() == vault:T("FOREVER.bags"), "bag button renders localized label rather than height")
Check(page.tabs.equipment.label:GetText() == vault:T("FOREVER.equipment"), "equipment button renders localized label rather than height")
Check(page.refresh.label:GetText() == vault:T("FOREVER.REFRESH"), "refresh button renders localized action")
page.tabs.equipment.scripts.OnClick(); flush()
Check(page.tabs.equipment.state == "selected" and page.tabs.bags.state == "default", "selected source tab follows displayed snapshot")
Check(#page.renderedRecords == 2, "equipment tab renders same query snapshot")
Check(page.rows[1].labels.item:GetText():match("NativeItem"), "metadata rendered through Core resolver")
local mainSourceID = page.renderedRecords[1].sourceID
core.AccountView.frame:Hide()
Check(core.AccountView:ShowPreview("vault-items", env.Minimap), "Core owns preview window")
Check(page.renderedRecords[1].sourceID == mainSourceID and not page.refresh:IsShown(), "preview uses same snapshot and hides refresh action")
core.AccountView:HidePreview()
core.AccountView:ShowPage("vault-items")
local actualCreateCount = #vault.Items.Events._listeners
vault:Initialize()
Check(#vault.Items.Events._listeners == actualCreateCount, "reinitialization does not duplicate subscribers")
local reads = data.reads
for i = 1, 30 do event("BAG_UPDATE_DELAYED") end
flush()
Check(data.reads - reads == 4, "burst updates coalesce to one bag sweep")
data.bags[0][2].stackCount = 6
event("BAG_UPDATE_DELAYED"); flush()
Check(vault.Items:Query({ sources = { "bags" }, itemID = 42 }).totals.totalQuantity == 6, "stack change persisted")
data.equipment[16] = 257282
event("PLAYER_EQUIPMENT_CHANGED", 16); flush()
Check(vault.Items:Query({ sources = { "equipment" }, itemID = 257282 }).totals.totalQuantity == 1, "equipment replacement persisted")
data.fail = true
event("BAG_UPDATE_DELAYED"); flush()
Check(vault.AccountPage:Status("bags", env.TEST_GUID) == "error", "read failure reported")
Check(vault.Items:Query({ sources = { "bags" }, itemID = 42 }).totals.totalQuantity == 6, "read failure retains last data")
Check(#vault.Items:Query({ sources = { "bags" }, includeStale = false }).records == 0, "failed source is not presented as fresh")
data.fail = false; event("BAG_UPDATE_DELAYED"); flush()
Check(vault.AccountPage:Status("bags", env.TEST_GUID) == "known", "recovery clears source error")
local saved, coreSaved = vault.Copy(vault.db), core.Defaults:Copy(core.Database:GetDB())
local nextEnv, nextCore, nextVault, nextEvent, nextFlush = Boot(saved, coreSaved)
Check(nextVault.db.byCharacter[nextEnv.TEST_GUID] ~= nil and nextVault.AccountPage:Status("bags", nextEnv.TEST_GUID) == "stale", "saved snapshot restored as stale")
nextEvent("PLAYER_ENTERING_WORLD"); nextFlush()
Check(nextVault.AccountPage:Status("equipment", nextEnv.TEST_GUID) == "known", "next session recollects")
data.bags, data.equipment = {}, {}
env.SlashCmdList.YIBOVAULT("scan"); flush()
Check(vault.Items:Query({ sources = { "bags", "equipment" } }).totals.totalQuantity == 0, "manual confirmed complete empty scan clears removed items")
Check(vault:GetCharacterCoverage(env.TEST_GUID, "equipment").equipment.status == "known-empty", "real empty distinguished from pending")
event("PLAYER_LEAVING_WORLD"); event("BAG_UPDATE_DELAYED"); flush()
Check(not vault._inWorld and not vault._scanQueued, "no collection outside world")

local badSave = { schemaVersion = 999, sentinel = true }
local _, _, bad = Boot(badSave)
Check(not bad.initialized and badSave.sentinel and not badSave.byCharacter, "future schema preserved and stopped")
local _, _, missing = Boot(nil, nil, function(_, c) c.CheckAPIVersion = function() return false end end)
Check(not missing.initialized and not missing.db, "old Core stops before database initialization")
local _, _, mismatch = Boot(nil, nil, function(e) e.WOW_PROJECT_ID = 19 end)
Check(not mismatch.initialized and not mismatch.db, "wrong target stopped")
Check(#env.TEST_MESSAGES == 1, "only intentional early-scan feedback; no hidden Core callback errors: " .. table.concat(env.TEST_MESSAGES, " | "))
do
    local mop, mopCore, mopVault, mopEvent, mopFlush = Boot(nil, nil, nil, false)
    Check(mopVault.initialized and mopVault.VERSION == "1.2.4-api1", "real Mists Vault manifest initializes")
    mopEvent("PLAYER_LOGIN"); mopEvent("PLAYER_ENTERING_WORLD"); mopFlush()
    Check(mopVault.Items:HasCapability("source.bank", 1) and mopVault.Items:HasCapability("source.mail", 1), "Mists source capabilities retained")
    Check(mopVault.GuildBank and mopVault.MailItems and mopVault.AuctionHouse, "Mists modules retained")
    Check(mop.YiboVaultForeverDB.sentinel == "forever" and not mop.YiboVaultForeverDB.byCharacter, "Mists leaves Forever saved table untouched")
    Check(mopVault.Items:Query({ sources = { "bags", "equipment" } }).totals.totalQuantity == 7, "Mists bag/equipment collection retained")
    Check(mopVault.Items:Query({ scope = { mode = "account" }, sources = { "bags" } }) ~= nil, "Mists account scopes retained")
    Check(not mopVault.IsMailboxReadable, "Mists does not load Forever mail collector")
    mop.ATTACHMENTS_MAX_RECEIVE = 16
    mop.MailFrame = { IsShown = function() return true end }
    mop.GetInboxNumItems = function() return 1, 1 end
    mop.GetInboxHeaderInfo = function() return nil, nil, "Sender", "Mail", 0, 0, 30, 1 end
    mop.GetInboxItem = function(_, slot) if slot == 1 then return "Item", 8001, 1, 5 end end
    mop.GetInboxItemLink = function(_, slot) if slot == 1 then return "item:8001" end end
    Check(mopVault.MailItems:Scan("regression"), "Mists native mail collector still scans")
    Check(mopVault.Items:Query({ scope = { mode = "account" }, sources = { "mail" } }).totals.externalQuantity == 5, "Mists original mail source and account query retained")
    Check(not mopVault.ScanAuctions, "Mists does not load Forever auction collector")
    mop.C_AuctionHouse = {
        QueryOwnedAuctions = function() end, GetNumOwnedAuctions = function() return 1 end,
        GetOwnedAuctionInfo = function() return { auctionID = 900, itemKey = { itemID = 8002 }, quantity = 3, status = 0 } end,
    }
    mopVault.AuctionHouse.open = true
    Check(mopVault.AuctionHouse:Start("regression"), "Mists original own-auction request starts")
    mopVault.AuctionHouse:OnEvent("OWNED_AUCTIONS_UPDATED"); mopFlush()
    Check(mopVault.Items:Query({ scope = { mode = "account" }, sources = { "auction" } }).totals.listedQuantity == 3, "Mists original auction capture and account query retained")
    Check(not mopVault.CurrentGuildBankIdentity, "Mists does not load Forever observer guild policy")
    mop.GetGuildInfo = function() return "MistsGuild" end
    mop.GetNumGuildBankTabs = function() return 1 end
    mop.GetCurrentGuildBankTab = function() return 1 end
    mop.GetGuildBankTabInfo = function() return "Tab", 1, true end
    mop.QueryGuildBankTab = function() end
    mop.GetGuildBankItemInfo = function(_, slot) if slot == 1 then return 1, 2 end end
    mop.GetGuildBankItemLink = function(_, slot) if slot == 1 then return "item:8003" end end
    mopVault.GuildBank.open = true
    Check(mopVault.GuildBank:Start(), "Mists original guild collector starts")
    mopVault.GuildBank:OnEvent("GUILDBANKBAGSLOTS_CHANGED"); mopFlush()
    Check(mopVault.Items:Query({ scope = { mode = "account" }, sources = { "guild-bank" } }).totals.physicalQuantity == 2, "Mists guild collection and account query retained")
    mop.SlashCmdList.YIBOVAULT("open"); mopFlush()
    Check(mopCore.AccountView.activePageID == "vault-items", "Mists storage page opens through actual Core")
    Check(#mop.TEST_MESSAGES == 0, "Mists has no hidden startup/page errors: " .. table.concat(mop.TEST_MESSAGES, " | "))
end
do
    local wrong, _, wrongVault = Boot(nil, nil, function(e) e.WOW_PROJECT_ID = 18; e.WOW_PROJECT_CAMELOT = 18 end, false)
    Check(not wrongVault.initialized and not wrong.YiboVaultDB, "forced default manifest cannot write on Forever")
end
do
    local bank = { open = false, tabs = { { ID = 101, bankType = 73 }, { ID = 102, bankType = 73 } },
        items = { [101] = { [1] = { itemID = 9001, stackCount = 8 } }, [102] = { [2] = { itemID = 9002, stackCount = 2 } } }, reads = 0 }
    local function Configure(e)
        e.Enum.BankType = { Character = 73, Account = 99 }
        e.Enum.BagIndex.CharacterBankTab_1, e.Enum.BagIndex.CharacterBankTab_2 = 101, 102
        e.Enum.BagIndex.AccountBankTab_1 = 201
        e.C_Bank = {
            CanViewBank = function(kind) Check(kind == 73, "only Character bank access queried"); return bank.open end,
            FetchPurchasedBankTabData = function(kind) Check(kind == 73, "only Character bank tabs enumerated"); return bank.tabs end,
            FetchNumPurchasedBankTabs = function(kind) Check(kind == 73, "only Character bank count queried"); return #bank.tabs end,
        }
        local slots, item, free = e.C_Container.GetContainerNumSlots, e.C_Container.GetContainerItemInfo, e.C_Container.GetContainerNumFreeSlots
        e.C_Container.GetContainerNumSlots = function(id)
            if id < 100 then return slots(id) end
            Check(bank.open and (id == 101 or id == 102), "bank containers limited to open Character bank")
            bank.reads = bank.reads + 1
            if bank.fail and id == 102 then error("second tab unavailable") end
            return bank.zeroCapacity and 0 or 2
        end
        e.C_Container.GetContainerItemInfo = function(id, slot)
            if id < 100 then return item(id, slot) end
            if bank.incomplete then return nil end
            return bank.items[id] and bank.items[id][slot]
        end
        e.C_Container.GetContainerNumFreeSlots = function(id)
            if id < 100 then return free(id) end
            local n = 2; for _ in pairs(bank.items[id] or {}) do n = n - 1 end; return n
        end
    end
    local e, c, v, fire, drain = Boot(nil, nil, Configure)
    Check(v.initialized and v._unsupportedEvents.PLAYERBANKSLOTS_CHANGED, "unsupported optional bank event does not break startup")
    fire("PLAYER_ENTERING_WORLD"); drain()
    Check(bank.reads == 0 and not next(v:GetCharacterCoverage(e.TEST_GUID, "bank")), "never visited bank stays uncollected")
    e.SlashCmdList.YIBOVAULT("open"); drain()
    local panel = c.AccountView.frame.instances["vault-items"]
    panel.tabs.bank.scripts.OnClick(); drain()
    Check(panel.tabs.bank.label:GetText() == v:T("FOREVER.bank") and panel.tabs.bank.state == "selected", "bank tab localized and selected")
    Check(panel.renderedStatus == "bank_pending" and #panel.renderedRecords == 0, "bank page does not claim empty before visit")
    Check(panel.refresh.state == "disabled", "refresh unavailable while bank closed")
    bank.open = true; fire("BANKFRAME_OPENED"); drain()
    local q = v.Items:Query({ sources = { "bank" } })
    Check(q.totals.totalQuantity == 10 and #q.records == 2, "all purchased Character bank containers persisted")
    Check(panel.renderedStatus == "known" and #panel.renderedRecords == 2 and panel.refresh.state == "default", "bank source displayed through actual Core page")
    Check(panel.rows[1].labels.location:GetText():match("101"), "bank location uses actual container ID")
    c.AccountView.frame:Hide(); Check(c.AccountView:ShowPreview("vault-items", e.Minimap), "Core bank preview opens")
    Check(#panel.renderedRecords == 2 and panel.renderedStatus == "known" and not panel.refresh:IsShown(), "bank preview shares page snapshot")
    c.AccountView:HidePreview(); c.AccountView:Toggle("vault-items")
    local before = bank.reads
    bank.items[101][1].stackCount = 11
    for i = 1, 20 do fire("BAG_UPDATE_DELAYED") end
    drain()
    Check(bank.reads - before == 2 and v.Items:Query({ sources = { "bank" } }).totals.totalQuantity == 13, "bank changes coalesce and replace quantities")
    bank.items[101][1].stackCount = 99; bank.fail = true
    fire("BAG_CONTAINER_UPDATE"); drain()
    Check(v.Items:Query({ sources = { "bank" } }).totals.totalQuantity == 13, "failure in second bank container commits none of first")
    Check(v.AccountPage:Status("bank", e.TEST_GUID) == "error" and #v.Items:Query({ sources = { "bank" }, includeStale = false }).records == 0, "bank read failure reported and stale records excluded")
    bank.fail = false; bank.items[101][1].stackCount = 11
    fire("BANK_TABS_CHANGED", 73); drain()
    Check(v.AccountPage:Status("bank", e.TEST_GUID) == "known", "bank recovers after complete read")
    bank.incomplete = true; fire("BAG_UPDATE_DELAYED"); drain()
    Check(v.AccountPage:Status("bank", e.TEST_GUID) == "error" and v.Items:Query({ sources = { "bank" } }).totals.totalQuantity == 13, "incomplete bank slots cannot erase inventory")
    bank.incomplete = false
    local originalTabs = bank.tabs
    for _, invalid in ipairs({ { { ID = 201, bankType = 99 } }, { { ID = 201, bankType = 73 } }, { { ID = 101, bankType = 73 }, { ID = 101, bankType = 73 } } }) do
        bank.tabs = invalid; fire("BANK_TABS_CHANGED", 73); drain()
        Check(v.AccountPage:Status("bank", e.TEST_GUID) == "error" and v.Items:Query({ sources = { "bank" } }).totals.totalQuantity == 13, "account or duplicated tab rejected before commit")
    end
    bank.tabs = {}; fire("BANK_TABS_CHANGED", 73); drain()
    Check(v.Items:Query({ sources = { "bank" } }).totals.totalQuantity == 13, "empty tab metadata is not empty bank")
    bank.tabs = originalTabs; bank.zeroCapacity = true; fire("BAG_UPDATE_DELAYED"); drain()
    Check(v.Items:Query({ sources = { "bank" } }).totals.totalQuantity == 13, "unready primary container capacity cannot erase bank")
    bank.zeroCapacity = false; fire("BAG_UPDATE_DELAYED"); drain()
    local savedBank, savedCore = v.Copy(v.db), c.Defaults:Copy(c.Database:GetDB())
    bank.open = false; fire("BANKFRAME_CLOSED"); drain()
    Check(panel.renderedStatus == "stale" and #panel.renderedRecords == 2, "closed bank keeps previous snapshot with stale status")
    before = bank.reads; panel.refresh.scripts.OnClick(); e.SlashCmdList.YIBOVAULT("scan"); drain()
    Check(bank.reads == before and v.Items:Query({ sources = { "bank" } }).totals.totalQuantity == 13, "closed bank refresh never queries containers or clears records")
    bank.open = true; fire("BANKFRAME_OPENED"); bank.open = false; fire("BANKFRAME_CLOSED"); drain()
    Check(bank.reads == before, "closing before deferred bank read cancels bank access")
    local se, sc, sv, sf, sd = Boot(savedBank, savedCore, Configure)
    sf("PLAYER_ENTERING_WORLD"); sd()
    Check(sv.Items:Query({ sources = { "bank" } }).totals.totalQuantity == 13 and sv.AccountPage:Status("bank", se.TEST_GUID) == "stale", "bank saved snapshot restored without opening bank")
    Check(sv.db.settings.foreverSource == "bank", "bank tab selection persists")
    bank.items = {}; bank.open = true; sf("BANKFRAME_OPENED"); sd()
    Check(sv.Items:Query({ sources = { "bank" } }).totals.totalQuantity == 13, "empty response immediately after bank open cannot erase previous snapshot")
    se.SlashCmdList.YIBOVAULT("scan"); sd()
    Check(sv.Items:Query({ sources = { "bank" } }).totals.totalQuantity == 0 and sv.AccountPage:Status("bank", se.TEST_GUID) == "empty", "accessible fully scanned empty bank clears old records")
    Check(sv:GetCharacterCoverage(se.TEST_GUID, "bank")["101"].status == "known-empty", "successful empty bank persists explicit coverage")
    bank.open = false; sf("PLAYER_LEAVING_WORLD"); before = bank.reads; sf("BANKFRAME_OPENED"); sd()
    Check(bank.reads == before and not sv._bankOpen, "bank event outside world does not read")
    Check(#e.TEST_MESSAGES == 0 and #se.TEST_MESSAGES == 0, "bank paths have no hidden Core callback errors")
end
do
    local inbox = { open = false, loaded = 2, total = 2, countReads = 0,
        headers = { [1] = { sender = "Sender", subject = "Two items", count = 2 }, [2] = { sender = "Sender2", subject = "Text only" } },
        items = { [1] = { [1] = { id = 7001, qty = 4 }, [16] = { id = 7002, qty = 2 } } } }
    local function Configure(e)
        e.ATTACHMENTS_MAX_RECEIVE = 16
        e.MailFrame = { IsShown = function() return inbox.open end }
        e.C_Mail = { IsCommandPending = function() return inbox.commandPending == true end }
        e.GetInboxNumItems = function()
            Check(inbox.open, "mail count only read at open mailbox")
            inbox.countReads = inbox.countReads + 1
            return inbox.loaded, inbox.total
        end
        e.GetInboxHeaderInfo = function(index)
            if inbox.failHeader then error("mail header unavailable") end
            local h = inbox.headers[index]
            if not h then return end
            local subject = inbox.headerChanged and inbox.countReads % 2 == 0 and "Changed" or h.subject
            return nil, nil, h.sender, subject, 0, 0, 30, h.count
        end
        e.GetInboxItem = function(mail, attachment)
            Check(mail >= 1 and mail <= inbox.loaded and attachment >= 1 and attachment <= 16, "mail indexes bounded to visible inbox")
            local item = inbox.items[mail] and inbox.items[mail][attachment]
            if not item then return end
            local quantity = item.qty
            if inbox.missingQuantity then quantity = nil end
            return "Item", item.id, 1, quantity, 1, true, inbox.currency
        end
        e.GetInboxItemLink = function(mail, attachment)
            if inbox.failLink then error("mail attachment link unavailable") end
            local item = inbox.items[mail] and inbox.items[mail][attachment]
            return item and ("item:" .. (inbox.badLink and 999 or item.id))
        end
        -- Any accidental mail action must fail this integration run.
        for _, name in ipairs({ "TakeInboxItem", "AutoLootMailItem", "TakeInboxMoney", "DeleteInboxItem", "ReturnInboxItem", "SendMail", "CheckInbox" }) do
            e[name] = function() error("unexpected mail action: " .. name) end
        end
    end
    local e, c, v, fire, drain = Boot(nil, nil, Configure)
    Check(v.initialized and v.Items:HasCapability("source.mail", 1), "mail source advertised without loading Mists mail provider")
    fire("PLAYER_ENTERING_WORLD"); drain()
    Check(inbox.countReads == 0 and v.AccountPage:Status("mail", e.TEST_GUID) == "mail_pending", "unvisited mailbox remains unknown")
    e.SlashCmdList.YIBOVAULT("open"); drain()
    local panel = c.AccountView.frame.instances["vault-items"]
    panel.tabs.mail.scripts.OnClick(); drain()
    Check(panel.tabs.mail.label:GetText() == v:T("FOREVER.mail") and panel.tabs.mail.state == "selected", "mail tab localized and selected")
    Check(panel.renderedStatus == "mail_pending" and panel.refresh.state == "disabled", "unvisited mailbox page shows pending and disables refresh")
    inbox.open = true; fire("MAIL_SHOW"); drain()
    local q = v.Items:Query({ sources = { "mail" } })
    Check(#q.records == 2 and q.totals.externalQuantity == 6 and q.totals.physicalQuantity == 0, "mail attachments use external source and exact quantities")
    Check(q.records[1].sourceID ~= q.records[2].sourceID and q.records[2].location.attachmentIndex == 16, "multiple attachments keep distinct stable slot identities")
    Check(panel.renderedStatus == "known" and #panel.renderedRecords == 2 and panel.refresh.state == "default", "mail attachments displayed in Core page")
    Check(panel.rows[1].labels.location:GetText():match("1"), "mail attachment location rendered")
    q.records[1].quantity = 999
    Check(v.Items:Query({ sources = { "mail" } }).totals.totalQuantity == 6, "mail query returns detached snapshot")
    local coverage = v:GetCharacterCoverage(e.TEST_GUID, "mail").inbox
    Check(coverage.currentCount == 2 and coverage.totalCount == 2 and coverage.unscannedCount == 0, "full inbox coverage persisted")
    c.AccountView.frame:Hide(); Check(c.AccountView:ShowPreview("vault-items", e.Minimap), "Core mail preview opens")
    Check(#panel.renderedRecords == 2 and not panel.refresh:IsShown(), "mail preview shares attachment snapshot")
    c.AccountView:HidePreview(); c.AccountView:Toggle("vault-items")
    inbox.items[1][1].qty = 7
    local before = inbox.countReads
    for i = 1, 20 do fire("MAIL_INBOX_UPDATE") end
    drain()
    Check(inbox.countReads - before == 2 and v.Items:Query({ sources = { "mail" } }).totals.totalQuantity == 9, "mail events coalesce into one validated scan")
    inbox.total = 3; fire("MAIL_INBOX_UPDATE"); drain()
    Check(panel.renderedStatus == "mail_incomplete" and v.Items:Query({ sources = { "mail" } }).totals.totalQuantity == 9, "partial inbox keeps previous complete snapshot")
    Check(#v.Items:Query({ sources = { "mail" }, includeStale = false }).records == 0, "partial inbox does not advertise old records as fresh")
    inbox.total = 2
    for _, flag in ipairs({ "failHeader", "failLink", "badLink", "currency", "headerChanged", "missingQuantity" }) do
        inbox[flag] = true; fire("MAIL_INBOX_UPDATE"); drain()
        Check(v.AccountPage:Status("mail", e.TEST_GUID) == "error" and v.Items:Query({ sources = { "mail" } }).totals.totalQuantity == 9, "mail read failure preserves complete prior snapshot: " .. flag)
        inbox[flag] = false
        fire("MAIL_INBOX_UPDATE"); drain()
        Check(v.AccountPage:Status("mail", e.TEST_GUID) == "known", "mail recovery clears error: " .. flag)
    end
    inbox.headers[1].count = 3; fire("MAIL_INBOX_UPDATE"); drain()
    Check(v.AccountPage:Status("mail", e.TEST_GUID) == "error" and v.Items:Query({ sources = { "mail" } }).totals.totalQuantity == 9, "missing attachment cannot commit partial mail")
    inbox.headers[1].count = 2; inbox.commandPending = true; fire("MAIL_INBOX_UPDATE"); drain()
    Check(panel.renderedStatus == "mail_incomplete" and v.Items:Query({ sources = { "mail" } }).totals.totalQuantity == 9, "native pending mail operation defers scan")
    inbox.commandPending = false; fire("MAIL_INBOX_UPDATE"); drain()
    local savedMail, savedCore = v.Copy(v.db), c.Defaults:Copy(c.Database:GetDB())
    inbox.open = false; fire("MAIL_CLOSED"); drain()
    Check(panel.renderedStatus == "stale" and panel.refresh.state == "disabled" and #panel.renderedRecords == 2, "closed mailbox keeps stale snapshot")
    before = inbox.countReads; panel.refresh.scripts.OnClick(); e.SlashCmdList.YIBOVAULT("scan"); drain()
    Check(inbox.countReads == before, "closed mailbox manual refresh does not read or clear mail")
    inbox.open = true; fire("MAIL_SHOW"); inbox.open = false; fire("MAIL_CLOSED"); drain()
    Check(inbox.countReads == before, "closing before deferred mail scan cancels mail read")
    local se, sc, sv, sf, sd = Boot(savedMail, savedCore, Configure)
    sf("PLAYER_ENTERING_WORLD"); sd()
    Check(sv.AccountPage:Status("mail", se.TEST_GUID) == "stale" and sv.Items:Query({ sources = { "mail" } }).totals.totalQuantity == 9, "mail save restores stale without opening mailbox")
    Check(sv.db.settings.foreverSource == "mail", "mail tab selection persists")
    inbox.loaded, inbox.total, inbox.items = 0, 0, {}
    inbox.open = true; sf("MAIL_SHOW"); sd()
    Check(sv.Items:Query({ sources = { "mail" } }).totals.totalQuantity == 9, "initial empty inbox response cannot erase stored attachments")
    sf("BAG_UPDATE_DELAYED"); sd()
    Check(sv.Items:Query({ sources = { "mail" } }).totals.totalQuantity == 9, "bag event does not establish empty mailbox readiness")
    sf("MAIL_INBOX_UPDATE"); sd()
    Check(sv.AccountPage:Status("mail", se.TEST_GUID) == "empty" and sv.Items:Query({ sources = { "mail" } }).totals.totalQuantity == 0, "ready empty mailbox clears removed attachments")
    Check(sv:GetCharacterCoverage(se.TEST_GUID, "mail").inbox.status == "known-empty", "empty inbox explicit coverage persisted")
    -- Text-only mail: nil item count is valid when its header is loaded.
    inbox.loaded, inbox.total = 1, 1; inbox.headers[1] = { sender = "Sender", subject = "Text", count = nil }
    sf("MAIL_INBOX_UPDATE"); sd()
    Check(sv.AccountPage:Status("mail", se.TEST_GUID) == "empty", "text-only mail is not mistaken for unloaded header")
    sf("PLAYER_LEAVING_WORLD"); before = inbox.countReads; sf("MAIL_SHOW"); sd()
    Check(not sv._mailOpen and inbox.countReads == before, "mail outside world is ignored")
    Check(#e.TEST_MESSAGES == 0 and #se.TEST_MESSAGES == 0, "mail operations have no hidden Core callback errors")
end
do
    local market = { open = false, full = true, queryReady = true, queries = 0, countCalls = 0,
        entries = { { auctionID = 501, status = 31, itemKey = { itemID = 6001 }, quantity = 4, itemLink = "item:6001" },
            { auctionID = 502, status = 31, itemKey = { itemID = 6002 }, quantity = 2 }, { auctionID = 503, status = 37 } } }
    local function Configure(e)
        e.Enum.AuctionStatus = { Active = 31, Sold = 37 }
        e.AuctionHouseFrame = { IsShown = function() return market.open end }
        e.C_AuctionHouse = {
            IsThrottledMessageSystemReady = function() return market.queryReady end,
            QueryOwnedAuctions = function(sorts)
                Check(market.open and type(sorts) == "table", "only own-auction query issued at open auction house")
                if market.failQuery then error("query unavailable") end
                market.queries = market.queries + 1
            end,
            HasFullOwnedAuctionResults = function() return market.full end,
            GetNumOwnedAuctions = function() Check(market.open, "owned-auction count read only in auction context"); market.countCalls = market.countCalls + 1; return #market.entries end,
            GetOwnedAuctionInfo = function(index)
                Check(index >= 1 and index <= #market.entries, "owned-auction index bounded")
                if market.failRead and index == 2 then return nil end
                local item = {}
                for k, value in pairs(market.entries[index]) do item[k] = value end
                if market.changing and market.countCalls % 2 == 0 and index == 1 then item.quantity = item.quantity + 1 end
                return item
            end,
        }
        for _, name in ipairs({ "CancelAuction", "PostItem", "PostCommodity", "PlaceBid", "SendBrowseQuery", "StartCommoditiesPurchase" }) do
            e.C_AuctionHouse[name] = function() error("unexpected auction operation: " .. name) end
        end
    end
    local e, c, v, fire, drain = Boot(nil, nil, Configure)
    fire("PLAYER_ENTERING_WORLD"); drain()
    Check(market.queries == 0 and market.countCalls == 0 and v.AccountPage:Status("auction", e.TEST_GUID) == "auction_pending", "unvisited auction house stays unknown without network query")
    Check(v.Items:HasCapability("source.auction", 1) and not v.AuctionHouse, "Forever uses isolated own-auction source")
    e.SlashCmdList.YIBOVAULT("open"); drain()
    local panel = c.AccountView.frame.instances["vault-items"]
    panel.tabs.auction.scripts.OnClick(); drain()
    Check(panel.tabs.auction.label:GetText() == v:T("FOREVER.auction") and panel.tabs.auction.state == "selected", "auction tab localized and selected")
    Check(panel.renderedStatus == "auction_pending" and panel.refresh.state == "disabled", "unvisited auction page pending with unavailable refresh")
    fire("AUCTION_HOUSE_SHOW")
    Check(market.queries == 0, "auction show defers own query until native frame can be displayed")
    market.open = true; drain()
    Check(market.queries == 1 and market.countCalls == 0 and not next(v:GetCharacterCoverage(e.TEST_GUID, "auction")), "opening requests own listings but never accepts pre-event cached data")
    fire("OWNED_AUCTIONS_UPDATED"); drain()
    local q = v.Items:Query({ sources = { "auction" } })
    Check(#q.records == 2 and q.totals.listedQuantity == 6 and q.totals.physicalQuantity == 0, "active own auctions collected as listed quantities; sold excluded")
    Check(q.records[1].auctionID == 501 and q.records[1].sourceID:match(":501$"), "auction ID persists as snapshot identity")
    Check(panel.renderedStatus == "known" and #panel.renderedRecords == 2 and panel.rows[1].labels.location:GetText():match("501"), "auction page renders same active snapshot and auction ID")
    q.records[1].quantity = 999
    Check(v.Items:Query({ sources = { "auction" } }).totals.totalQuantity == 6, "auction query detached from saved authority")
    c.AccountView.frame:Hide(); Check(c.AccountView:ShowPreview("vault-items", e.Minimap), "auction Core preview opens")
    Check(#panel.renderedRecords == 2 and not panel.refresh:IsShown(), "auction preview shares page snapshot")
    c.AccountView:HidePreview(); c.AccountView:Toggle("vault-items")
    market.entries[1].quantity = 7
    local before = market.countCalls
    for i = 1, 20 do fire("OWNED_AUCTIONS_UPDATED") end
    drain()
    Check(market.countCalls - before == 2 and market.queries == 1 and v.Items:Query({ sources = { "auction" } }).totals.totalQuantity == 9, "owned updates coalesce and do not repeatedly query server")
    market.full = false; fire("OWNED_AUCTIONS_UPDATED"); drain()
    Check(panel.renderedStatus == "auction_incomplete" and v.Items:Query({ sources = { "auction" } }).totals.totalQuantity == 9, "partial auction results keep complete prior snapshot")
    Check(#v.Items:Query({ sources = { "auction" }, includeStale = false }).records == 0, "partial results cannot advertise old listings as fresh")
    market.full = true; market.failRead = true; fire("OWNED_AUCTIONS_UPDATED"); drain()
    Check(v.AccountPage:Status("auction", e.TEST_GUID) == "error" and v.Items:Query({ sources = { "auction" } }).totals.totalQuantity == 9, "second listing failure never partially overwrites first listing")
    market.failRead = false
    local original = market.entries[2]
    for _, invalid in ipairs({ { auctionID = 501, status = 31, itemKey = { itemID = 6002 }, quantity = 2 },
        { auctionID = 502, status = 31, itemKey = { itemID = 6002 }, quantity = 0 },
        { auctionID = 502, status = 99 }, { auctionID = 502, status = 31, itemKey = { itemID = 6002 }, quantity = 2, itemLink = "item:999" } }) do
        market.entries[2] = invalid; fire("OWNED_AUCTIONS_UPDATED"); drain()
        Check(v.AccountPage:Status("auction", e.TEST_GUID) == "error" and v.Items:Query({ sources = { "auction" } }).totals.totalQuantity == 9, "duplicate ID, invalid quantity/status or mismatched link preserves snapshot")
    end
    market.entries[2], market.countCalls, market.changing = original, 0, true
    fire("OWNED_AUCTIONS_UPDATED"); drain()
    Check(v.AccountPage:Status("auction", e.TEST_GUID) == "error" and v.Items:Query({ sources = { "auction" } }).totals.totalQuantity == 9, "same-count content mutation rejected by two-pass check")
    market.changing = false; fire("OWNED_AUCTIONS_UPDATED"); drain()
    Check(v.AccountPage:Status("auction", e.TEST_GUID) == "known", "complete auction recovery clears source error")
    market.queryReady = false; e.SlashCmdList.YIBOVAULT("scan"); drain()
    Check(market.queries == 1 and panel.renderedStatus == "auction_incomplete", "throttled own-auction refresh defers query and keeps snapshot")
    market.queryReady = true; fire("AUCTION_HOUSE_THROTTLED_SYSTEM_READY"); drain()
    Check(market.queries == 2 and panel.renderedStatus == "auction_incomplete", "query resumes on native throttle readiness and still awaits result event")
    fire("OWNED_AUCTIONS_UPDATED"); drain()
    market.failQuery = true; v:RequestOwnedAuctions(); fire("BAG_UPDATE_DELAYED"); drain()
    Check(v.AccountPage:Status("auction", e.TEST_GUID) == "error", "failed request is not masked as waiting by bag refresh")
    market.failQuery = false; v:RequestOwnedAuctions(); fire("OWNED_AUCTIONS_UPDATED"); drain()
    local savedAuction, savedCore = v.Copy(v.db), c.Defaults:Copy(c.Database:GetDB())
    market.open = false; fire("AUCTION_HOUSE_CLOSED"); drain()
    Check(panel.renderedStatus == "stale" and panel.refresh.state == "disabled" and #panel.renderedRecords == 2, "closed auction house preserves stale active listings")
    before = market.countCalls; local queryBefore = market.queries
    panel.refresh.scripts.OnClick(); e.SlashCmdList.YIBOVAULT("scan"); drain()
    Check(market.countCalls == before and market.queries == queryBefore, "closed auction house performs no query or read")
    market.open = true; fire("AUCTION_HOUSE_SHOW"); fire("OWNED_AUCTIONS_UPDATED"); market.open = false; fire("AUCTION_HOUSE_CLOSED"); drain()
    Check(market.countCalls == before, "closing before deferred capture cancels auction read")
    local se, sc, sv, sf, sd = Boot(savedAuction, savedCore, Configure)
    sf("PLAYER_ENTERING_WORLD"); sd()
    Check(sv.AccountPage:Status("auction", se.TEST_GUID) == "stale" and sv.Items:Query({ sources = { "auction" } }).totals.totalQuantity == 9, "saved own listings restore stale before next auction visit")
    Check(sv.db.settings.foreverSource == "auction", "auction tab choice persists")
    market.entries = {}; market.open = true; sf("AUCTION_HOUSE_SHOW"); sd()
    Check(sv.Items:Query({ sources = { "auction" } }).totals.totalQuantity == 9, "pre-event zero listing count cannot erase saved auctions")
    sf("OWNED_AUCTIONS_UPDATED"); sd()
    Check(sv.AccountPage:Status("auction", se.TEST_GUID) == "empty" and sv.Items:Query({ sources = { "auction" } }).totals.totalQuantity == 0, "complete ready zero results remove inactive old listings")
    Check(sv:GetCharacterCoverage(se.TEST_GUID, "auction").auction.status == "known-empty", "known empty owned listings explicitly saved")
    market.entries = { { auctionID = 700, status = 37 } }; sf("OWNED_AUCTIONS_UPDATED"); sd()
    Check(sv.AccountPage:Status("auction", se.TEST_GUID) == "empty", "sold-only results are not current listed inventory")
    sf("PLAYER_LEAVING_WORLD"); queryBefore = market.queries; sf("AUCTION_HOUSE_SHOW"); sd()
    Check(not sv._auctionOpen and market.queries == queryBefore, "auction show outside world cannot query")
    Check(#e.TEST_MESSAGES == 1 and #se.TEST_MESSAGES == 0, "only expected throttled-scan feedback; no hidden auction callback errors")
end
do
    local bank = { open = false, member = true, club = "9001", name = "Same Guild", current = 1, reads = 0, queries = 0,
        tabs = { [1] = { name = "First", view = true }, [2] = { name = "Private", view = false }, [3] = { name = "Third", view = true } },
        items = { [1] = { [1] = { id = 4001, qty = 5 } }, [2] = { [1] = { id = 9999, qty = 99 } }, [3] = { [98] = { id = 4002, qty = 2 } } } }
    local function Configure(e)
        e.IsInGuild = function() return bank.member end
        e.C_Club = { GetGuildClubId = function() return bank.club end }
        e.GetGuildInfo = function() return bank.name end
        e.GuildBankFrame = { IsShown = function() return bank.open end }
        e.GetNumGuildBankTabs = function() return 3 end
        e.GetCurrentGuildBankTab = function() return bank.current end
        e.GetGuildBankTabInfo = function(tab) local value = bank.tabs[tab]; return value.name, 1, value.view end
        e.QueryGuildBankTab = function(tab)
            assert(bank.open and bank.tabs[tab].view and tab == bank.current, "only selected viewable tab can be queried")
            bank.queries = bank.queries + 1
        end
        e.GetGuildBankItemInfo = function(tab, slot)
            assert(bank.open and bank.tabs[tab].view and tab == bank.current and slot >= 1 and slot <= 98, "guild reads constrained to selected authorized tab")
            bank.reads = bank.reads + 1
            if bank.fail and slot == 98 then error("guild slot read failed") end
            local item = bank.items[tab] and bank.items[tab][slot]
            return item and 1 or nil, item and item.qty or 0
        end
        e.GetGuildBankItemLink = function(tab, slot)
            local item = bank.items[tab] and bank.items[tab][slot]
            if item and not bank.missingLink then return "item:" .. item.id end
        end
        for _, name in ipairs({ "PickupGuildBankItem", "AutoStoreGuildBankItem", "DepositGuildBankMoney", "WithdrawGuildBankMoney", "SetCurrentGuildBankTab", "BuyGuildBankTab" }) do
            e[name] = function() error("unexpected guild operation: " .. name) end
        end
    end
    local e, c, v, fire, drain = Boot(nil, nil, Configure)
    fire("PLAYER_ENTERING_WORLD"); drain()
    Check(v.Items:HasCapability("source.guild-bank", 1) and bank.queries == 0 and bank.reads == 0, "guild capability does not read or request a closed bank")
    e.SlashCmdList.YIBOVAULT("open"); drain()
    local panel = c.AccountView.frame.instances["vault-items"]
    panel.tabs["guild-bank"].scripts.OnClick(); drain()
    Check(panel.tabs["guild-bank"].label:GetText() == v:T("FOREVER.guild_bank") and panel.renderedStatus == "guild_pending" and panel.refresh.state == "disabled", "guild page localized with unvisited state")
    bank.open = true; fire("GUILDBANKFRAME_OPENED"); drain()
    Check(bank.queries == 1 and bank.reads == 0, "guild open requests only native selected tab and awaits update")
    fire("GUILDBANKBAGSLOTS_CHANGED"); drain()
    local identity = v:CurrentGuildBankIdentity()
    local key = identity.key
    local q = v.Items:Query({ sources = { "guild-bank" } })
    Check(#q.records == 1 and q.totals.totalQuantity == 5 and q.records[1].visitorCharacterID == e.TEST_GUID, "guild first tab saved with observer identity")
    Check(panel.renderedStatus == "guild_partial" and #panel.renderedRecords == 1, "unvisited accessible tab keeps overall guild view partial")
    Check(not v.db.byGuild[key].tabs["2"], "unviewable guild tab never scanned or invented empty")
    Check(not v.Items:Query({ sources = { "guild-bank" }, guildKey = "other-guild" }), "explicit foreign guild key rejected")
    q.records[1].quantity = 999
    Check(v.Items:Query({ sources = { "guild-bank" } }).totals.totalQuantity == 5, "guild public query detached from authoritative storage")
    bank.current = 3; fire("GUILDBANKBAGSLOTS_CHANGED"); drain()
    Check(bank.queries == 2 and v.Items:Query({ sources = { "guild-bank" } }).totals.totalQuantity == 5, "native tab change requests matching tab before reading event")
    fire("GUILDBANKBAGSLOTS_CHANGED"); drain()
    Check(v.Items:Query({ sources = { "guild-bank" } }).totals.totalQuantity == 7 and panel.renderedStatus == "known", "all viewable guild tabs collected without reading forbidden tab")
    Check(panel.rows[2].labels.location:GetText():match("98"), "guild final slot and tab location rendered")
    c.AccountView.frame:Hide(); Check(c.AccountView:ShowPreview("vault-items", e.Minimap), "guild preview owned by Core")
    Check(#panel.renderedRecords == 2 and not panel.refresh:IsShown(), "guild preview shares authorized snapshot")
    c.AccountView:HidePreview(); c.AccountView:Toggle("vault-items")
    local before = bank.reads
    bank.items[3][98].qty = 4
    for i = 1, 20 do fire("GUILDBANKBAGSLOTS_CHANGED") end
    drain()
    Check(bank.reads - before == 196 and v.Items:Query({ sources = { "guild-bank" } }).totals.totalQuantity == 9, "guild bursts coalesce into two-pass selected-tab scan")
    bank.items[3][98].qty = 12; bank.fail = true; fire("GUILDBANKBAGSLOTS_CHANGED"); drain()
    Check(v.Items:Query({ sources = { "guild-bank" } }).totals.totalQuantity == 9 and panel.renderedStatus == "error", "guild read failure retains complete prior tab")
    Check(#v.Items:Query({ sources = { "guild-bank" }, includeStale = false }).records == 1, "only failed tab excluded from fresh guild records")
    bank.fail = false; bank.items[3][98].qty = 4; fire("GUILDBANKBAGSLOTS_CHANGED"); drain()
    bank.missingLink = true; fire("GUILDBANKBAGSLOTS_CHANGED"); drain()
    Check(panel.renderedStatus == "error" and v.Items:Query({ sources = { "guild-bank" } }).totals.totalQuantity == 9, "occupied guild slot missing link cannot erase old record")
    bank.missingLink = false; fire("GUILDBANKBAGSLOTS_CHANGED"); drain()
    local queryBefore = bank.queries
    fire("GUILDBANK_UPDATE_TABS"); drain()
    Check(bank.queries == queryBefore, "same-tab metadata event does not loop read requests")
    bank.tabs[1].view = false; fire("GUILDBANK_UPDATE_TABS"); drain()
    Check(v.Items:Query({ sources = { "guild-bank" }, includeHiddenGuilds = true }).totals.totalQuantity == 4 and not v:GetGuildCoverage(key)["1"], "revoked permission hides cached records even with hidden-guild override")
    Check(v.db.byGuild[key].tabs["1"][1].quantity == 5, "revoked cache retained as inaccessible archive")
    local saved, savedCore = v.Copy(v.db), c.Defaults:Copy(c.Database:GetDB())
    bank.open = false; fire("GUILDBANKFRAME_CLOSED"); drain()
    Check(panel.renderedStatus == "stale" and panel.refresh.state == "disabled", "guild close keeps stale authorized snapshot")
    before, queryBefore = bank.reads, bank.queries
    panel.refresh.scripts.OnClick(); drain()
    Check(bank.reads == before and bank.queries == queryBefore, "closed guild refresh performs no calls")
    local se, sc, sv, sf, sd = Boot(saved, savedCore, Configure)
    sf("PLAYER_ENTERING_WORLD"); sd()
    Check(sv:GuildBankViewStatus() == "stale" and sv.Items:Query({ sources = { "guild-bank" } }).totals.totalQuantity == 4, "guild snapshot and permission scope restore stale")
    Check(sv.db.settings.foreverSource == "guild-bank", "guild tab choice persists")
    bank.club = "9002"
    Check(sv.Items:Query({ sources = { "guild-bank" } }).totals.totalQuantity == 0 and sv:GuildBankViewStatus() == "guild_pending", "same-name different guild never reuses old guild snapshot")
    bank.club = nil
    Check(sv:GuildBankViewStatus() == "guild_identity" and #sv.Items:Query({ sources = { "guild-bank" } }).records == 0, "missing stable guild ID has no name fallback")
    bank.club, bank.member = "9001", false
    sf("PLAYER_GUILD_UPDATE", "player"); sd()
    Check(sv:GuildBankViewStatus() == "guild_none" and #sv.Items:Query({ sources = { "guild-bank" } }).records == 0, "leaving guild hides all former guild data")
    bank.member, bank.open, bank.items[3] = true, true, {}
    sf("GUILDBANKFRAME_OPENED"); sd(); sf("GUILDBANKBAGSLOTS_CHANGED"); sd()
    Check(sv.Items:Query({ sources = { "guild-bank" } }).totals.totalQuantity == 4, "uncorrelated all-empty guild event cannot erase old cache")
    se.SlashCmdList.YIBOVAULT("scan"); sf("GUILDBANKBAGSLOTS_CHANGED"); sd()
    Check(sv.Items:Query({ sources = { "guild-bank" } }).totals.totalQuantity == 0 and sv:GetGuildCoverage(key)["3"].status == "known-empty", "manual confirmation plus native update persists known empty selected tab")
    sf("GUILDBANKFRAME_CLOSED"); before, queryBefore = bank.reads, bank.queries
    sf("GUILDBANKFRAME_OPENED"); sf("GUILDBANKFRAME_CLOSED"); sd()
    Check(bank.reads == before and bank.queries == queryBefore, "closing before deferred query cancels guild access")
    saved.byGuild["foreign"] = { viewerCharacterID = "Other", tabs = {}, coverage = {} }
    Check(sv:InspectCharacter({ id = se.TEST_GUID }).hasData, "cleanup owner reports guild observer cache")
    Check(sv:DeleteCharacter({ id = se.TEST_GUID }) and not sv.db.byGuild[key] and sv.db.byGuild.foreign, "character cleanup removes only its own guild observer snapshots")
    Check(#e.TEST_MESSAGES == 0 and #se.TEST_MESSAGES == 1, "only expected manual-wait feedback; no hidden guild callback errors")
end
print("VaultForever Smoke passed: " .. checks .. " checks (actual Core/Vault manifests, simulated client)")
return Boot
