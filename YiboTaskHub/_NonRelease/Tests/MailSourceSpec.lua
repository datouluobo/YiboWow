-- Actual Core contracts, Todo sources, TaskHub surfaces and Mail business modules.
dofile("YiboTaskHub/_NonRelease/Tests/SurfacesSpec.lua")
local Hub, Core, Todo = YiboTaskHub, YiboCore, YiboTodo
local checks, now, timers, notices = 0, 2000000, {}, {}
local function Equal(a, b, label)
    checks = checks + 1; assert(a == b, (label or "value") .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end
GetServerTime = function() return now end
GetTime = GetServerTime
C_Timer = { After = function(delay, callback) timers[#timers + 1] = { at = now + delay, callback = callback } end }
local function Flush()
    for iteration = 1, 30 do
        local found
        for i, timer in ipairs(timers) do if timer.at <= now then found = i; break end end
        if not found then return end
        table.remove(timers, found).callback()
    end
    error("timer feedback loop")
end
Hub.Print = function(_, message) notices[#notices + 1] = message end
assert(Hub.Contracts:Initialize())
assert(Todo.ActionContracts:Initialize())
local characters = Core.Characters:GetAllCached()
local current = Core.Characters:GetCurrent()
local offlineID = current.id == "D" and "C" or "D"
Equal(Hub.Snapshot:Build(characters).providerCount, 2, "two existing Todo sources")

for _, file in ipairs({ "Namespace", "Store", "Items", "Scanner", "ViewModel", "ActionTodo" }) do dofile("YiboMail/" .. file .. ".lua") end
local Mail = YiboMail; Mail.Core = Core
Mail:InitializeDatabase()
assert(Core:RegisterAddon(Mail.NAME, { version = Mail.VERSION, requiredAPI = 9 }))
assert(Mail.Items:RegisterService())
local shown, inbox, total = true, {}, 0
MailFrame = { IsShown = function() return shown end }
GetInboxNumItems = function() return #inbox, total end
GetInboxHeaderInfo = function(index)
    local mail = inbox[index]
    return nil, nil, "Sender", mail.subject, mail.money or 0, mail.cod or 0, mail.days or 2, #mail.items, mail.read == true, false
end
GetInboxItem = function(index, slot)
    local item = inbox[index].items[slot]
    if item then return "Item", item.id, "icon", item.quantity end
end
GetInboxItemLink = function(index, slot)
    local item = inbox[index].items[slot]
    if item then return "|Hitem:" .. item.id .. "|h[Item]|h" end
end
local function Scan(mails, count)
    inbox, total = mails, count or #mails
    shown, Mail.Scanner.open, Mail.Scanner.updated = true, true, true
    assert(Mail.Scanner:Scan()); Flush()
end
local request = { scope = { characterIDs = { current.id, offlineID, "U", current.id } } }
local function Rows()
    local value, rows = Hub.Snapshot:Build(characters), {}
    for _, row in ipairs(value.current) do if row.task.providerID == Mail.ActionTodo.PROVIDER then rows[#rows + 1] = row end end
    return rows, value
end
assert(Mail.ActionTodo:Initialize())
local epoch = Mail.db.actionTodo.sourceEpoch
Equal(Hub.Snapshot:Build(characters).providerCount, 3, "new business late registration discovered")
assert(Mail.ActionTodo:Initialize())
Equal(#Core.Contracts:List("action.todo", { major = 1 }), 3, "idempotent registration")
Equal(#Mail.Items.Events.listeners, 1, "idempotent source subscription")
Equal(Mail.ActionTodo:Query({ scope = { characterIDs = {} } }).data.tasks[1], nil, "empty scope")
Equal(Mail.ActionTodo:Query({ scope = { characterIDs = { [2] = current.id } } }), nil, "sparse scope rejected")
Equal(Mail.ActionTodo:Query(request).coverage.U.state, "not-yet-scanned", "missing mailbox is unknown")

local notifications = 0
Core.Events:Register("BUSINESS_CONTRACT_CHANGED", "mail-source-audit", function(_, descriptor)
    if descriptor.providerID == Mail.ActionTodo.PROVIDER then notifications = notifications + 1 end
end)
local item = { id = 100, quantity = 2 }
Scan({ { subject = "同主题|信", items = { item } }, { subject = "同主题|信", items = { item } },
    { subject = "金币", items = {}, money = 500 }, { subject = "文本", items = {} },
    { subject = "付款", items = { item }, cod = 100 } }, 7)
Equal(notifications, 1, "scan emits one provider invalidation")
local result = Mail.ActionTodo:Query(request)
Equal(#result.data.tasks, 1, "one new-mail notice per mailbox, not one task per attachment")
Equal(result.data.tasks[1].title, "新邮件 · 5 封", "text and COD are view notices, never collection commands")
Equal(result.coverage[current.id].state, "partial", "partial inbox coverage preserved")
Equal(result.data.tasks[1].readiness, "actionable", "observed partial-page mail remains collectible")
Equal(result.data.tasks[1].summary:find("||", 1, true) ~= nil, true, "subject markup escaped")
local storedKeys = Mail.db.byCharacter[current.id].visibleKeys
Equal(storedKeys[1] ~= storedKeys[2], true, "duplicate subjects retain distinct mail identities in owner")
Equal(result.data.tasks[1].nextAction.pageID, "mail-inbox")
Equal(result.data.tasks[1].icon, "Interface\\Icons\\INV_Letter_15", "notice uses mail icon rather than implying a required attachment")
local mailRows, all = Rows()
Equal(#mailRows, 1, "generic center consumes third source")
Equal(#all.errors, 0, "no consumer-specific adapter needed")
local stable = mailRows[1].task.identity
local oldNotifications = notifications
result.data.tasks[1].title = "mutated"
Equal(Mail.ActionTodo:Query(request).data.tasks[1].title ~= "mutated", true, "query returns value snapshot")
Equal(notifications, oldNotifications, "queries never broadcast")
Equal(Mail.db.actionTodo.sourceEpoch, epoch, "stable persistent epoch")
Hub.db.settings.sourceFilter = Mail.ActionTodo.PROVIDER
local context = Core.AccountView:BuildContext(Hub.CoreIntegration.page)
local preview = Hub.Preview:Build(Core.AccountView:BuildContext(Hub.CoreIntegration.page, { preview = true }))
Equal(Hub.AccountPage:Stats(preview.rows), 1, "hover uses generic source filter")
Hub.db.settings.hudEnabled, Hub.db.settings.reminderMode = true, "summary"
Hub.Displays:Initialize(); now = now + 1; Flush()
local projected, counts = Hub.Presentation:Current()
Equal(counts.actionable >= 1, true, "HUD and reminder current projection includes mail")
Equal(#notices, 1, "login summary remains once with third provider")

Mail.Scanner:Close(); Flush()
mailRows = Rows()
Equal(mailRows[1].task.readiness, "unknown", "closed mailbox invalidates positive action")
Equal(Hub.AccountPage:Status(mailRows[1].task):find("需复核", 1, true) ~= nil, true, "closed snapshot not labeled expired")
Equal(mailRows[1].task.identity, stable, "close does not recreate work")
Equal(#notices, 1, "closing mailbox does not resend summary")
Scan({ { subject = "剩余", items = { item } } })
mailRows = Rows()
Equal(#mailRows, 1, "new observed mailbox removes former collection work")
Equal(mailRows[1].task.readiness, "actionable")
local pendingIdentity = mailRows[1].task.identity
local _, beforeRescanCounts = Hub.Presentation:Current()
Mail.Scanner:Schedule(); Flush()
mailRows = Rows()
Equal(mailRows[1].task.readiness, "unknown", "pending rescan invalidates collection readiness")
local invalidRevision = Mail.Items:GetRevision()
Mail.Scanner:Schedule(); Mail.Scanner:Schedule(); Flush()
Equal(Mail.Items:GetRevision(), invalidRevision, "repeated pending invalidation coalesces")
now = now + 0.3; Flush()
mailRows = Rows()
Equal(mailRows[1].task.readiness, "actionable", "unchanged successful rescan restores center readiness")
Equal(mailRows[1].task.identity, pendingIdentity, "rescan preserves work identity")
local _, recoveredCounts = Hub.Presentation:Current()
Equal(recoveredCounts.actionable, 1, "HUD recovers the same actionable mail")
Equal(recoveredCounts.unknown, beforeRescanCounts.unknown, "HUD drops pending unknown count after rescan")
Equal(#notices, 1, "rescan recovery does not resend login summary")
local offline = Mail.Copy(Mail.db.byCharacter[current.id].records[Mail.db.byCharacter[current.id].visibleKeys[1]])
Mail:CommitScan(Core.Characters:Get(offlineID), { offline }, { status = "known", currentCount = 1, totalCount = 1, observedAt = now }); Flush()
result = Mail.ActionTodo:Query(request)
local offlineTask
for _, task in ipairs(result.data.tasks) do if task.execution.characterID == offlineID then offlineTask = task end end
Equal(offlineTask.readiness, "unknown", "offline mailbox not advertised as collectible")
Equal(result.coverage[offlineID].state, "stale")
local opened = Mail.ViewModel:GetMails({ characters = { current } })[1]
assert(Mail:MarkMailOpened(opened)); Flush()
Equal(#Rows(), 0, "viewed but uncollected letter is handled")
Equal(#opened.mail.attachments, 1, "acknowledgement does not collect stored attachment")
Scan({ { subject = "剩余", items = { item } } })
Equal(#Rows(), 0, "rescan never recreates handled notice")
Mail:InitializeDatabase(); Mail.ActionTodo:Shutdown(); assert(Mail.ActionTodo:Initialize()); Hub.Contracts:Invalidate()
Equal(#Rows(), 0, "acknowledgement survives database and provider reload")
Mail.Scanner:Close(); Flush()
Equal(#Rows(), 0, "closing mailbox does not recreate a viewed notice")
Scan({ { subject = "剩余", items = { item } }, { subject = "新到", items = { item } } })
mailRows = Rows()
Equal(mailRows[1].task.title, "新邮件 · 1 封", "only actual later arrival generates a notice")
Mail.Scanner.lastError = "read failed"; Mail.Scanner:PublishStatus(current.id); Flush()
mailRows = Rows()
Equal(mailRows[1].task.readiness, "unknown", "scan failure removes positive readiness")
Scan({ { subject = "到期", items = { item }, days = 1 / 86400 } })
now = now + 2; Flush()
mailRows = Rows()
Equal(mailRows[1].task.readiness, "unknown", "expiry timer requests revalidation instead of completing work")
Equal(Hub.AccountPage:Status(mailRows[1].task):find("已过期", 1, true) ~= nil, true, "source expiry boundary distinguishes expiration from closed snapshots")
Scan({})
mailRows = Rows()
Equal(#mailRows, 0, "confirmed empty inbox removes current work")
Equal(Mail.ActionTodo:Query(request).coverage[current.id].state, "known-empty")
Mail:DeleteCharacter({ id = offlineID }); Flush()
Equal(Mail.ActionTodo:Query(request).coverage[offlineID].state, "not-yet-scanned", "deleted character data is unknown")

-- Existing cached stock establishes a baseline without changing read styling.
Scan({ { subject = "旧库存", items = { item } } })
local stock = Mail.ViewModel:GetMails({ characters = { current } })[1]
Mail.db.mailNoticeVersion = nil
Mail:InitializeDatabase(); Mail.ActionTodo:Changed(); Flush()
Equal(#Rows(), 0, "old cached stock is not imported as new work")
Equal(stock.mail.openedByUser, nil, "baseline does not falsely mark stock as user-read")
Equal(Mail.db.byCharacter[current.id].records[stock.key].noticeHandled, true)
Scan({ { subject = "旧库存", items = { item } }, { subject = "客户端已读", items = { item }, read = true } })
Equal(#Rows(), 0, "initial client-read letter does not generate new work")
Scan({ { subject = "新来未看", items = { item } } })
local unread = Mail.ViewModel:GetMails({ characters = { current } })[1]
local unreadIdentity = Rows()[1].task.identity
Scan({ { subject = "新来未看", items = { item }, read = true } })
Equal(#Rows(), 1, "later background read-flag changes are not user acknowledgement")
Equal(Rows()[1].task.identity, unreadIdentity, "background rescan keeps notice batch")
assert(Mail:MarkMailOpened(Mail.ViewModel:GetMails({ characters = { current } })[1])); Flush()
Equal(#Rows(), 0)

-- A verified queue remainder inherits handling instead of becoming new mail.
Mail.Queue = { pending = { action = { characterID = current.id, original = unread.mail }, targetIndex = 1 } }
local remainder = Mail.Copy(unread.mail)
remainder.attachments[1].quantity = 1; remainder.signature = Mail.Scanner:Signature(remainder)
Mail.Queue.pending.expected = { signature = remainder.signature }
Mail:CommitScan(current, { remainder }, { status = "known", currentCount = 1, totalCount = 1, observedAt = now }); Flush()
Equal(#Rows(), 0, "partial collection remainder does not regenerate a notice")
Mail.Queue = nil
Scan({ { subject = "相同邮件", items = { item } }, { subject = "相同邮件", items = { item } } })
Equal(Rows()[1].task.title, "新邮件 · 2 封")
for _, entry in ipairs(Mail.ViewModel:GetMails({ characters = { current } })) do assert(Mail:MarkMailOpened(entry)) end
Flush()
Scan({ { subject = "相同邮件", items = { item } } })
Equal(#Rows(), 0, "ambiguous duplicate survival does not recreate handled stock")

-- Native arrival facts work outside the mailbox, without inferring contents.
Scan({}); Mail.Scanner:Close(); Flush()
local hasNew = false; HasNewMail = function() return hasNew end
Mail.Scanner:OnEvent("PLAYER_LOGIN"); Flush()
hasNew = true; Mail.Scanner:OnEvent("UPDATE_PENDING_MAIL"); Flush()
mailRows = Rows()
Equal(#mailRows, 1, "arrival signal creates one notice before opening mailbox")
Equal(mailRows[1].task.readiness, "actionable", "current native new-mail fact can prompt viewing")
Equal(mailRows[1].task.title, "新邮件 · 待查看", "pending arrival never invents attachment or mail counts")
local arrivalIdentity, arrivalRevision = mailRows[1].task.identity, Mail.Items:GetRevision()
Mail.Scanner:OnEvent("UPDATE_PENDING_MAIL"); Flush()
Equal(Mail.Items:GetRevision(), arrivalRevision, "unchanged native signal does not broadcast repeatedly")
Scan({ { subject = "信号到货", items = {} } })
Equal(Rows()[1].task.identity, arrivalIdentity, "scan refines same notice batch")
assert(Mail:MarkMailOpened(Mail.ViewModel:GetMails({ characters = { current } })[1])); Flush()
Mail.Scanner:OnEvent("UPDATE_PENDING_MAIL"); Flush()
Equal(#Rows(), 0, "sticky native signal never recreates a handled notice")
hasNew = false; Mail.Scanner:OnEvent("UPDATE_PENDING_MAIL"); Flush()
hasNew = true; Mail.Scanner:OnEvent("UPDATE_PENDING_MAIL"); Flush()
Equal(Rows()[1].task.identity ~= arrivalIdentity, true, "a later actual arrival gets a new notice batch")
hasNew = false; Mail.Scanner:OnEvent("UPDATE_PENDING_MAIL"); Flush()
Scan({}); HasNewMail = nil

Mail:Publish(current.id, {}, {}, "scan")
local beforeShutdown = notifications
Mail.ActionTodo:Shutdown(); Flush()
Equal(notifications, beforeShutdown, "retired callback cannot notify")
Equal(#Mail.Items.Events.listeners, 0, "source subscription cleaned")
Equal(Hub.Snapshot:Build(characters).providerCount, 2, "unregistration leaves other business healthy")
local checkAPI = Core.CheckAPIVersion
Core.CheckAPIVersion = function(_, minimum) return minimum <= 9 end
local ok, err = Mail.ActionTodo:Initialize()
Equal(ok, nil, "API9 stops optional integration")
Equal(err:find("升级", 1, true) ~= nil, true, "upgrade error explicit")
Equal(Mail.Items:GetState(current.id).status, "known-empty", "base Mail still works on API9")
Core.CheckAPIVersion = checkAPI
local hasCapability = Core.HasCapability
Core.HasCapability = function(self, name, minimum)
    if name == "business-providers" then return false end
    return hasCapability(self, name, minimum)
end
Equal(Mail.ActionTodo:Initialize(), nil, "missing Provider capability stops optional integration")
Core.HasCapability = hasCapability
local incompatible = assert(Core.Contracts:Register(Mail.NAME, { name = "action.todo", kind = "provider", providerID = Mail.ActionTodo.PROVIDER,
    version = { major = 2, minor = 0 }, methods = { Query = function() error("incompatible source must not be called") end } }))
Equal(Hub.Snapshot:Build(characters).providerCount, 2, "incompatible Mail source excluded without hurting Todo")
assert(Core.Contracts:Unregister(Mail.NAME, incompatible))
local conflict = assert(Core.Contracts:Register(Mail.NAME, { name = "action.todo", kind = "provider", providerID = Mail.ActionTodo.PROVIDER,
    version = { major = 1, minor = 0 }, methods = { Query = function() return nil, "conflict-fixture" end } }))
Equal(Mail.ActionTodo:Initialize(), nil, "registration conflict explicit")
Equal(#Mail.Items.Events.listeners, 0, "failed registration cleans its subscription")
assert(Core.Contracts:Unregister(Mail.NAME, conflict))
assert(Mail.ActionTodo:Initialize())
Equal(Mail.db.actionTodo.sourceEpoch, epoch, "re-registration retains source epoch")
Equal(#Core.Contracts:List("action.todo", { major = 1 }), 3)
Mail.ActionTodo:Shutdown(); Hub.Displays:Shutdown(); Todo.ActionContracts:Shutdown(); Hub.Contracts:Shutdown()
print("MailSourceSpec: " .. checks .. " checks passed")
