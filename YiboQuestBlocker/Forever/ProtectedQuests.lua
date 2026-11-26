local YQB = _G.YQB
local dialog = "YIBO_QUEST_BLOCKER_PROTECTED_RULE"

-- The client data identifies the final Alliance attunement quest as 6502.
local reasons = { [6502] = "FOREVER.PROTECT_ONYXIA" }

function YQB.GetQuestProtection(id)
    local key = reasons[id]
    return key and YQB.T(key) or nil
end

function YQB.ConfirmProtectedRule(id, title, apply)
    local reason = YQB.GetQuestProtection(id)
    if not reason then return false end
    StaticPopupDialogs[dialog] = StaticPopupDialogs[dialog] or {
        text = "%s",
        button1 = YQB.T("FOREVER.PROTECT_ADD"),
        button2 = CANCEL,
        OnAccept = function(_, callback) callback() end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    title = title or YQB.GetQuestName(id) or YQB.ReadQuestTitle(id) or tostring(id)
    StaticPopup_Show(dialog, YQB.T("FOREVER.PROTECT_CONFIRM", title, reason), nil, apply)
    return true
end
