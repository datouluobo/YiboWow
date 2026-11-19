local Boot = dofile("_NonRelease/MailForever/Harness.lua")
for _, forever in ipairs({ true, false }) do
    local attached = {}
    local e, core, mail, fire, flush, box = Boot(nil, function(e)
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
        e.GetMoney = function() return 10000 end
        e.MoneyInputFrame_GetCopper = function() return 0 end
        e.GetSendMailItem = function(slot)
            local item = attached[slot]
            if item then return item.name, item.id, 123, 1 end
        end
        e.GetSendMailItemLink = function(slot) if attached[slot] then return "item:" .. attached[slot].id end end
        e.CheckInbox = function() end
        e.MailFrameTab_OnClick = function() e.SendMailFrame:Show() end
        e.SendMailFrame_Update = function() end
        methods.ClearFocus = function() end
    end, forever)
    fire("PLAYER_ENTERING_WORLD")
    box.open = true; e.MailFrame:Show(); e.SendMailFrame:Show(); fire("MAIL_SHOW"); flush()
    local current = core.Characters:GetCurrent()
    local name = forever and "Beta Second" or "Beta"
    local address = name .. "-" .. current.realm
    assert(mail.Recipients:SetShortcut(1, address))
    local stored = mail.db.quickRecipients[1].address
    assert(mail.NativeUI:SetMailRecipient(stored))
    assert(e.SendMailNameEditBox:GetText() == (forever and name or address), "selected recipient uses the native target address")
    assert(mail.db.quickRecipients[1].address == stored, "native formatting does not rewrite saved identity")
    mail.Compose:WriteDraftFields({ recipient = address })
    assert(e.SendMailNameEditBox:GetText() == (forever and name or address), "rule packets use the same native address")
    mail.Compose.draft = { recipient = address, subject = "Manual", body = "Body", copper = 0, cod = false }
    assert(mail.Compose:ApplyDraft())
    assert(e.SendMailNameEditBox:GetText() == (forever and name or address))
    assert(e.SendMailSubjectEditBox:GetText() == "Manual" and e.SendMailBodyEditBox:GetText() == "Body")
    e.SendMailSubjectEditBox:SetText("")
    attached[1] = { name = "Shield", id = 7001 }
    fire("MAIL_SEND_INFO_UPDATE")
    assert(e.SendMailSubjectEditBox:GetText() == "Shield", "ordinary attachment updates fill an empty subject")
    e.SendMailSubjectEditBox:SetText("My subject")
    attached[2] = { name = "Ore", id = 7002 }; fire("MAIL_SEND_INFO_UPDATE")
    assert(e.SendMailSubjectEditBox:GetText() == "My subject", "attachment changes never overwrite a nonempty subject")
    e.SendMailSubjectEditBox:SetText("  "); fire("MAIL_SEND_INFO_UPDATE")
    assert(e.SendMailSubjectEditBox:GetText() == mail.Compose:SubjectForAttachments(mail.Compose:GetAttachments()), "multiple kinds reuse the existing localized subject")
    e.SendMailSubjectEditBox:SetText(""); attached = {}; fire("MAIL_SEND_INFO_UPDATE")
    assert(e.SendMailSubjectEditBox:GetText() == "", "empty envelope stays empty")
    attached[1] = { name = "Shield", id = 7001 }; e.SendMailFrame:Hide(); fire("MAIL_SEND_INFO_UPDATE")
    assert(e.SendMailSubjectEditBox:GetText() == "", "hidden compose is not edited")
    e.SendMailFrame:Show(); box.open = false; fire("MAIL_CLOSED"); fire("MAIL_SEND_INFO_UPDATE")
    assert(e.SendMailSubjectEditBox:GetText() == "", "closed mailbox is not edited")
end
print("PASS: native recipient formatting for both targets, preserved saved identity, ordinary attachment subject events and manual/visibility gates")
