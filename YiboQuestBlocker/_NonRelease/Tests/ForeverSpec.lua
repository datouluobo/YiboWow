local Harness = dofile("_NonRelease/BusinessReleaseHarness-20261122/Harness.lua")
local checker = Harness.Checker("QuestBlocker Forever")
local check = checker.Check

local daily = { questID = 21, title = "Daily", frequency = 1 }
local weekly = { questID = 22, title = "Weekly", frequency = 2 }
local unknown = { questID = 23, title = "Unknown" }
local normal = { questID = 24, title = "Ordinary", frequency = 0 }
local rows = { { isHeader = true }, daily, weekly, unknown, normal }
local currentID, currentTitle = 6502, "Drakefire Amulet"
local accepted = {}
local packageRoot, corePackageRoot, mistsPackageRoot, mistsCorePackageRoot = arg[1], arg[2], arg[3], arg[4]
local function Configure(env)
    getmetatable(env.UIParent).__index.GetRegions = function() return end
    env.Enum = env.Enum or {}
    env.Enum.QuestFrequency = { Default = 0, Daily = 1, Weekly = 2, ResetByScheduler = 3 }
    env.GetQuestID = function() return currentID end
    env.GetTitleText = function() return currentTitle end
    env.StaticPopupDialogs = {}
    env.StaticPopup_Show = function(key, text, _, data)
        env.TEST_PROTECTED_POPUP = { key = key, text = text, data = data }
    end
    env.C_GossipInfo.GetAvailableQuests = function()
        return env.TEST_AVAILABLE or { { questID = 6502, title = "Drakefire Amulet" }, { questID = 31, title = "Optional" },
            { questID = daily.questID, title = daily.title } }
    end
    env.C_GossipInfo.SelectAvailableQuest = function(id) env.TEST_PICKED = id end
    env.GetNumAvailableQuests = function() return #(env.TEST_AVAILABLE or {}) end
    env.GetAvailableQuestInfo = function(index)
        local offer = env.TEST_AVAILABLE and env.TEST_AVAILABLE[index]
        return false, nil, false, false, offer and offer.questID
    end
    env.GetAvailableTitle = function(index) return env.TEST_AVAILABLE[index].title end
    env.SelectAvailableQuest = function(index) env.TEST_PICKED = env.TEST_AVAILABLE[index].questID end
    env.C_GossipInfo.SelectActiveQuest = function(id) env.TEST_TURN_IN_CANDIDATE = id end
    env.GetQuestReward = function() env.TEST_TURNED_IN = env.TEST_TURN_IN_CANDIDATE end
    env.AcceptQuest = function() accepted[currentID] = true end
    env.ConfirmAcceptQuest = function() env.TEST_SHARE_ACCEPTS = (env.TEST_SHARE_ACCEPTS or 0) + 1 end
    env.C_QuestLog.GetNumQuestLogEntries = function() return #rows end
    env.C_QuestLog.GetInfo = function(index) return rows[index] end
    env.C_QuestLog.IsComplete = function(id) return id == weekly.questID end
    env.C_QuestLog.IsRepeatableQuest = function() return false end
    env.C_QuestLog.IsOnQuest = function(id)
        if accepted[id] then return true end
        for _, row in ipairs(rows) do if row.questID == id then return true end end
        return false
    end
    env.C_QuestLog.GetTitleForQuestID = function(id)
        for _, row in ipairs(rows) do if row.questID == id then return row.title end end
    end
    local selected, abandonID = 42
    env.C_QuestLog.GetSelectedQuest = function() return selected end
    env.C_QuestLog.SetSelectedQuest = function(id) selected = id end
    env.C_QuestLog.SetAbandonQuest = function() abandonID = selected end
    env.C_QuestLog.GetAbandonQuest = function() return abandonID end
    env.C_QuestLog.GetAbandonQuestItems = function() return abandonID == 92742 and { 99 } or nil end
    env.C_QuestLog.CanAbandonQuest = function(id) return id ~= 46 end
    env.C_QuestLog.AbandonQuest = function()
        if abandonID == 92742 then env.TEST_WELL_KIT = nil end
        accepted[abandonID] = nil
    end
    env.QuestMapQuestOptions_AbandonQuest = function(id) env.TEST_NATIVE_CONFIRM = id end
    env.StaticPopup_FindVisible = function(key)
        return key == "ABANDON_QUEST_WITH_ITEMS" and env.TEST_NATIVE_CONFIRM or nil
    end
    env.GossipFrame = { IsShown = function() return env.TEST_GOSSIP_OPEN end }
end

local function Boot(client, locale, saved)
    return Harness.Boot({
        client = client, locale = locale, coreRoot = client == "Forever" and corePackageRoot or "YiboCore",
        coreManifest = (client ~= "Forever" or not corePackageRoot) and ("YiboCore_" .. client .. ".toc") or nil,
        configure = Configure,
        addon = "YiboQuestBlocker", addonRoot = packageRoot or "YiboQuestBlocker",
        addonManifest = not packageRoot and "YiboQuestBlocker_Forever.toc" or nil, saved = saved,
    })
end

local function CheckPreviewPause(result)
    local view, yqb = result.Core.AccountView, result.env.YQB
    yqb.SetProcessingOption("autoReject", true)
    yqb.SetProcessingOption("autoAbandon", true)
    yqb.SetProcessingOption("paused", false)
    if view.frame then view.frame:Hide() end
    assert(view:ShowPreview("quest-blocker"))
    local button = assert(view.frame.pageTitleControl, tostring(view._pages["quest-blocker"].lastError))
    local texture
    button.icon.SetTexture = function(_, path) texture = path end
    view:RefreshPage()
    check(button:GetParent() == view.frame.titleBar and button:IsShown() and button.label:GetText() == ""
        and texture == "Interface\\TimeManager\\PauseButton", "hover title shows icon-only pause")
    button:GetScript("OnClick")(button)
    result.Flush()
    local runtime = yqb.GetRuntimeSettings()
    check(runtime.paused and runtime.autoReject and runtime.autoAbandon
        and not yqb.IsAutoRejectEnabled() and not yqb.IsAutoAbandonEnabled()
        and texture == "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up", "pause preserves choices and shows resume icon")
    button:GetScript("OnClick")(button)
    result.Flush()
    check(yqb.IsAutoRejectEnabled() and yqb.IsAutoAbandonEnabled()
        and texture == "Interface\\TimeManager\\PauseButton", "resume restores both enabled actions")
    view:HidePreview()
    view:ShowPage("quest-blocker")
    result.Flush()
    check(not button:IsShown() and not view.frame.pageTitleControl
        and not view.frame.instances["quest-blocker"].processingChecks[3]:GetChecked(), "main toolbar reflects resume and has no duplicate title action")
end

for _, locale in ipairs({ "zhCN", "enUS" }) do
    local result = Boot("Forever", locale, { YiboQuestBlockerDB = { marker = "mists" } })
    local env, yqb = result.env, result.env.YQB
    check(yqb.initialized and result.counts.RegisterPage == 1 and result.counts.RegisterBusinessEntry == 1, "single startup " .. locale)
    check(env.YiboQuestBlockerDB.marker == "mists" and yqb.GetDatabase() == env.YiboQuestBlockerForeverDB, "isolated store")
    check(yqb.GetProcessMode() == "notify" and yqb.GetLevelFilterExpr() == "", "Forever defaults")
    check(yqb.Initialize() and result.counts.RegisterPage == 1, "repeat init")
    local log = yqb.ReadQuestLog()
    check(#log == 4 and log[1].isDaily and log[2].isWeekly and log[2].isComplete, "native log projection")
    check(log[3].isRecurring == nil and log[4].isRecurring == false, "unknown differs from ordinary")
    check(#yqb.GetCurrentQuestList() == 3, "hide ready-to-turn-in")
    yqb.GetDatabase().filters.showNormal = false
    check(#yqb.GetCurrentQuestList() == 1, "recurring-only filter excludes unknown frequency")
    yqb.GetDatabase().filters.showNormal = true
    rows[1].isCollapsed = true
    local _, hasCollapsed = yqb.GetCurrentQuestList()
    check(hasCollapsed, "collapsed native log is identified")
    rows[1].isCollapsed = nil
    result.Event("GOSSIP_SHOW")
    check(#yqb.GetQuestOffers() == 2, "offers exclude current log")
    yqb.AddBlock(6502, "global", "Drakefire Amulet")
    local popup = env.TEST_PROTECTED_POPUP
    check(popup and not yqb.GetBlockScope(6502), "protected rules require confirmation before saving")
    env.StaticPopupDialogs[popup.key].OnAccept(nil, popup.data)
    check(yqb.GetBlockScope(6502) == "global" and yqb.GetQuestProtection(6502), "protected rule stored and identified")
    check(yqb.GetQuestName(6502) == "Drakefire Amulet", "unaccepted title retained")
    yqb.SetProcessMode("paused")
    check(yqb.IsProcessingPaused(), "pause mode selected")
    yqb.SetProcessMode("notify")
    result.Event("QUEST_DETAIL")
    result.Event("GOSSIP_CLOSED")
    check(#yqb.GetQuestOffers() == 1, "single quest survives gossip-to-detail transition")
    result.Event("QUEST_FINISHED")
    check(#yqb.GetQuestOffers() == 0, "close clears session")
    result.Event("QUEST_ACCEPT_CONFIRM", "Party member", "Shared", 41)
    check(yqb.GetQuestOffers()[1].id == 41, "share uses event ID")
    accepted[41] = true
    result.Event("QUEST_ACCEPTED", 41)
    check(#yqb.GetQuestOffers() == 0, "accepted no longer offered")
    accepted[41] = nil
    result.Core.AccountView:ShowPage("quest-blocker")
    result.Flush()
    check(not result.Core.AccountView._pages["quest-blocker"].lastError and #env.TEST_ERRORS == 0, "account window renders")
    local nextSession = Boot("Forever", locale, { YiboQuestBlockerForeverDB = Harness.Copy(yqb.GetDatabase()) })
    check(nextSession.env.YQB.GetBlockScope(6502) == "global", "rule survives reload")

    yqb.AddBlock(45, "global", "Ordinary offer")
    yqb.AddBlock(46, "global", "Locked offer")
    yqb.AddBlock(92742, "char", "Testing the Wells")
    yqb.SetProcessMode("abandon")
    env.TEST_GOSSIP_OPEN = true
    accepted[45] = true
    result.Event("QUEST_ACCEPTED", 45)
    result.Flush()
    check(accepted[45], "auto-accepted quest stays during NPC interaction")
    env.TEST_GOSSIP_OPEN = false
    result.Event("GOSSIP_CLOSED")
    result.Flush()
    check(not accepted[45] and yqb.GetQuestHandlingStatus(45) == "FOREVER.ABANDON_DONE"
        and env.C_QuestLog.GetSelectedQuest() == 42, "ordinary auto-accepted quest removed, selection restored")
    accepted[92742] = true
    env.TEST_WELL_KIT = true
    result.Event("QUEST_ACCEPTED", 92742)
    result.Flush()
    check(not accepted[92742] and not env.TEST_WELL_KIT and not env.TEST_NATIVE_CONFIRM
        and yqb.GetQuestHandlingStatus(92742) == "FOREVER.ABANDON_DONE"
        and env.C_QuestLog.GetSelectedQuest() == 42, "Testing the Wells uses direct abandonment without opening confirmation")
    accepted[46] = true
    result.Event("QUEST_ACCEPTED", 46)
    result.Flush()
    check(accepted[46] and yqb.GetQuestHandlingStatus(46) == "FOREVER.ABANDON_MANUAL", "locked quest reports manual handling")
    accepted[46] = nil
    accepted[45] = true
    result.Event("QUEST_ACCEPTED", 45)
    accepted[45] = nil
    result.Event("QUEST_TURNED_IN", 45)
    result.Flush()
    check(not yqb.GetQuestHandlingStatus(45) and yqb.IsQuestBlocked(45), "normal turn-in preserves rule without claiming abandonment")
    accepted[45] = true
    result.Event("QUEST_ACCEPTED", 45)
    yqb.SetProcessMode("paused")
    result.Flush()
    check(accepted[45], "pause cancels queued abandonment")
    accepted[45] = nil

    env.TEST_AVAILABLE = {
        { questID = 92742, title = "Testing the Wells" },
        { questID = 92744, title = "The Coast Isn't Clear" },
        { questID = 92745, title = "Another unblocked offer" },
    }
    local nativeGossip = env.C_GossipInfo.GetAvailableQuests
    local nativeSelect = env.SelectAvailableQuest
    yqb.SetProcessMode("direct")
    result.Event("GOSSIP_SHOW")
    local ordered = env.C_GossipInfo.GetAvailableQuests()
    check(#ordered == 3 and ordered[1].questID == 92744 and ordered[2].questID == 92745
        and ordered[3].questID == 92742 and env.TEST_AVAILABLE[1].questID == 92742,
        "first-choice automation can continue, order of allowed offers preserved and native data untouched")
    check(yqb.GetQuestOffers()[1].id == 92742, "YQB still sees blocked candidate")
    env.C_GossipInfo.SelectActiveQuest(22)
    env.GetQuestReward()
    check(env.TEST_TURNED_IN == 22, "same NPC active quest turns in normally")
    env.C_GossipInfo.SelectAvailableQuest(92742)
    check(not env.TEST_PICKED, "blocked ID never reaches native gossip selection")
    env.C_GossipInfo.SelectAvailableQuest(ordered[1].questID)
    currentID = env.TEST_PICKED
    env.AcceptQuest()
    check(currentID == 92744 and accepted[92744], "unblocked first eligible offer accepted")
    currentID = 92742
    env.AcceptQuest()
    check(not accepted[92742], "direct quest detail accept denied")
    currentID = 6502
    env.AcceptQuest()
    check(accepted[6502], "known protected quest still passes through")
    accepted[6502] = nil
    result.Event("QUEST_ACCEPT_CONFIRM", "Party member", "Testing the Wells", 92742)
    env.ConfirmAcceptQuest()
    result.Event("QUEST_ACCEPT_CONFIRM", "Party member", "Another quest", 92745)
    env.ConfirmAcceptQuest()
    check(env.TEST_SHARE_ACCEPTS == 1, "only verified matching share ID denied")
    local _, _, _, _, greetingID = env.GetAvailableQuestInfo(1)
    check(greetingID == 92744 and env.GetAvailableTitle(1) == env.TEST_AVAILABLE[2].title,
        "indexed greeting title and quest ID align for the first eligible offer")
    env.TEST_PICKED = nil
    env.SelectAvailableQuest(3)
    check(not env.TEST_PICKED, "indexed greeting blocks Testing the Wells")
    env.SelectAvailableQuest(1)
    check(env.TEST_PICKED == 92744, "indexed greeting selects the same ID that was displayed")
    yqb.SetProcessMode("paused")
    env.SelectAvailableQuest(1)
    check(env.TEST_PICKED == 92744, "mode switch preserves rendered greeting indexes until close")
    result.Event("QUEST_FINISHED")
    check(env.C_GossipInfo.GetAvailableQuests == nativeGossip and env.SelectAvailableQuest == nativeSelect,
        "leaving direct mode restores native APIs")
    accepted[92744] = nil
    local view = result.Core.AccountView
    local mainChecks = view.frame.instances["quest-blocker"].processingChecks
    view:ShowSettings("quest-blocker")
    result.Flush()
    local checks
    for _, row in ipairs(view.frame.instances.settings.rows) do
        if row.yqbSettings and row.yqbSettings:IsShown() then checks = row.yqbSettings.processingChecks end
    end
    check(checks and #checks == 3 and #mainChecks == 3, "both Core surfaces render the three shared checkboxes")
    checks = assert(checks, tostring(view._pages.settings.lastError))
    local function Click(index) checks[index]:GetScript("OnClick")(checks[index]) end
    Click(3)
    Click(2)
    check(checks[1]:GetChecked() and checks[2]:GetChecked() and not checks[3]:GetChecked()
        and yqb.IsAutoRejectEnabled() and yqb.IsAutoAbandonEnabled(), "both automation checkboxes apply independently")
    currentID = 92742
    env.AcceptQuest()
    check(not accepted[92742], "reject works with abandonment enabled")
    accepted[45] = true
    result.Event("QUEST_ACCEPTED", 45)
    result.Flush()
    check(not accepted[45], "abandonment works with rejection enabled")
    Click(3)
    local runtime = yqb.GetRuntimeSettings()
    check(runtime.autoReject and runtime.autoAbandon and runtime.paused
        and not yqb.IsAutoRejectEnabled() and not yqb.IsAutoAbandonEnabled(), "pause preserves both choices")
    view:ShowPage("quest-blocker")
    result.Flush()
    check(mainChecks[1]:GetChecked() and mainChecks[2]:GetChecked() and mainChecks[3]:GetChecked(),
        "settings changes appear in the main toolbar")
    local resumed = Boot("Forever", locale, { YiboQuestBlockerForeverDB = Harness.Copy(yqb.GetDatabase()) }).env.YQB
    resumed.SetProcessingOption("paused", false)
    check(resumed.IsAutoRejectEnabled() and resumed.IsAutoAbandonEnabled(), "both choices resume after reload and unpause")
    CheckPreviewPause(result)
    currentID = 6502
end

CheckPreviewPause(Harness.Boot({
    client = "Mists", locale = "zhCN", coreRoot = mistsCorePackageRoot or "YiboCore",
    coreManifest = not mistsCorePackageRoot and "YiboCore_Mists.toc" or nil,
    addon = "YiboQuestBlocker", addonRoot = mistsPackageRoot or "YiboQuestBlocker",
    addonManifest = not mistsPackageRoot and "YiboQuestBlocker_Mists.toc" or nil,
}))

local wrong = Boot("Mists", "enUS", { YiboQuestBlockerForeverDB = { marker = "forever" } })
check(not wrong.env.YQB.initialized and wrong.env.YiboQuestBlockerForeverDB.marker == "forever"
    and wrong.counts.RegisterPage == 0, "wrong client does not initialize")

for _, savedMode in ipairs({ "paused", "notify", "abandon", "direct" }) do
    local oldSave = { schemaVersion = 1, settings = { runtime = { processMode = savedMode } },
        globalBlocked = { [92742] = true } }
    local upgraded = Boot("Forever", "zhCN", { YiboQuestBlockerForeverDB = oldSave })
    check(upgraded.env.YQB.GetProcessMode() == savedMode and upgraded.env.YQB.IsQuestBlocked(92742),
        "previous rule and selected mode survive upgrade: " .. savedMode)
    if savedMode == "direct" then
        check(not upgraded.env.YQB.IsAutoAbandonEnabled(), "Forever legacy direct did not imply abandonment")
    end
end

os.exit(checker.Report() and 0 or 1)
