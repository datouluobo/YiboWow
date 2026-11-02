local character = { id = "A", name = "A" }
local mail = { signature = "empty", attachments = {}, money = 0, cod = 0,
    expiresAtEstimate = 999999, state = "observed", inboxIndex = 1, sender = "Sender", subject = "Letter", mailType = "normal" }
YiboMail = { db = { byCharacter = { A = { records = { letter = mail }, visibleKeys = { "letter" },
    coverage = { status = "known", currentCount = 1, totalCount = 1, observedAt = 1 } } },
    collectedMailMarkers = { A = { { signature = "empty", expiresAtEstimate = 999999 } } } },
    Core = { Characters = { GetCurrent = function() return character end } },
    Items = { GetState = function() return { status = "known" } end },
    Encode = function() return "key" end,
    T = function(_, key) return key end, Now = function() return 100 end }
dofile("YiboMail/ViewModel.lua")
dofile("YiboMail/CacheModel.lua")
local context = { characters = { character } }
assert(#YiboMail.ViewModel:GetMails(context, {}) == 1, "Native inbox must show retained collected letters")
assert(#YiboMail.CacheModel:GetMails(context, {}) == 1, "Account inbox must show retained collected letters")
assert(#YiboMail.CacheModel:GetMails(context, { kind = "empty" }) == 1)
mail.attachments = { { itemID = 1, quantity = 1 } }
assert(#YiboMail.ViewModel:GetMails(context, {}) == 1, "A marker cannot hide a nonempty letter")
print("PASS: retained empty letter with legacy saved marker stays visible in native/account inbox; empty filter and nonempty letter remain correct")
