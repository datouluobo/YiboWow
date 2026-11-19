local Boot = dofile("_NonRelease/MailForever/Harness.lua")
for _, target in ipairs({ "Forever", "Mists" }) do
    for _, language in ipairs({ "zh", "en" }) do
        local e, core, mail, fire, flush, box = Boot(nil, function(e, _, box)
            e.CheckInbox = function() end
            e.MailFrame = { IsShown = function() return box.open end, HookScript = function() end }
        end, target == "Forever")
        core.Locale.language = language
        local function Command(expected)
            e.SlashCmdList.YIBOMAIL("scan")
            assert(e.TEST_MESSAGES[#e.TEST_MESSAGES] == mail:T("APP.PREFIX") .. mail:T(expected),
                target .. "/" .. language .. "/" .. expected .. ": " .. tostring(e.TEST_MESSAGES[#e.TEST_MESSAGES]))
        end
        Command("UI.TEXT_0520")
        fire("PLAYER_ENTERING_WORLD"); box.open = true; fire("MAIL_SHOW"); flush()
        Command("UI.TEXT_0604")
        local before = mail.db.byCharacter[e.TEST_GUID]
        if target == "Forever" then box.pending = true; Command("FOREVER.PENDING"); box.pending = false end
        box.fail = true; Command("FOREVER.ERROR")
        assert(mail.db.byCharacter[e.TEST_GUID] == before and mail.Items:GetByCharacter(e.TEST_GUID).quantity == 5,
            "failed command preserves the previous snapshot")
        assert(mail.Scanner.lastError, "diagnostic detail remains in scanner state")
        box.fail = false; Command("UI.TEXT_0604")
        local getCurrent = core.Characters.GetCurrent
        core.Characters.GetCurrent = function() return nil end
        Command("UI.TEXT_0505")
        core.Characters.GetCurrent = getCurrent
        Command("UI.TEXT_0604")
    end
end
print("PASS: actual target scan commands use localized open/pending/error/success messages and preserve snapshots")
