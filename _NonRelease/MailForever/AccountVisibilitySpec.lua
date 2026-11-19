local Boot = dofile("_NonRelease/MailForever/Harness.lua")
local e, core, mail, fire, flush, box = Boot()
local visible = false
e.MailFrame = { IsShown = function() return visible end }
fire("PLAYER_ENTERING_WORLD"); flush()
box.open = true
fire("MAIL_SHOW")
fire("MAIL_INBOX_UPDATE")
assert(mail.Scanner.updated and box.reads == 0, "retain update before inbox frame becomes visible")
visible = true; flush()
assert(mail.Items:GetState(e.TEST_GUID).status == "known", "visible inbox commits update observed before frame appeared")
local observed = mail.db.byCharacter[e.TEST_GUID].coverage.observedAt
visible = false
fire("MAIL_INBOX_UPDATE"); flush()
assert(box.reads > 0 and mail.db.byCharacter[e.TEST_GUID].coverage.observedAt == observed,
    "hidden inbox never commits an observation")
local reads = box.reads
fire("MAIL_CLOSED"); flush()
visible = true; flush()
assert(box.reads == reads and not mail.Scanner.open, "close cancels any delayed inbox read")
print("Forever account visibility: 3 checks passed")
