local addonName, P = ...
P.events, P.registration = {}, {}
local frame, reportWindow = CreateFrame("Frame")
local function ValidDB(db)
    if db == nil then return true end
    if type(db) ~= "table" or db.schema ~= 1 or type(db.samples) ~= "table"
        or not P.Integer(db.nextSample, 0, 2147483647) or not P.Integer(db.sessions, 0, 2147483647)
        or #db.samples > P.MAX_SAMPLES then return false end
    for _, sample in ipairs(db.samples) do
        if type(sample) ~= "table" or not P.Integer(sample.id, 1, db.nextSample) then return false end
    end
    return true
end
local events = { "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_LOGOUT",
    "TRAIT_CONFIG_UPDATED", "TRAIT_NODE_CHANGED", "TRAIT_TREE_CURRENCY_INFO_UPDATED", "PLAYER_TALENT_UPDATE",
    "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_SPECIALIZATION_CHANGED", "CHARACTER_POINTS_CHANGED",
    "BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED", "LOOT_OPENED", "LOOT_CLOSED", "LOOT_BIND_CONFIRM",
    "USE_BIND_CONFIRM", "SPELL_CONFIRMATION_PROMPT", "ADDON_ACTION_FORBIDDEN", "ADDON_ACTION_BLOCKED" }
for _, event in ipairs(events) do
    local ok, err = pcall(frame.RegisterEvent, frame, event)
    P.registration[event] = ok and "registered" or P.Safe(err)
end
frame:SetScript("OnEvent", function(_, event, arg)
    if event == "ADDON_LOADED" then
        if arg ~= addonName or P.db then return end
        if not P.Target() then P.Say("blocked", "target_mismatch"); frame:UnregisterAllEvents(); return end
        if not ValidDB(YiboBuildsForeverProbeDB) then P.Say("blocked", "unknown_or_invalid_schema"); return end
        YiboBuildsForeverProbeDB = YiboBuildsForeverProbeDB or { schema = 1, samples = {}, nextSample = 0, sessions = 0 }
        P.db = YiboBuildsForeverProbeDB
        P.db.sessions = P.db.sessions + 1
        P.Say("ready")
    end
    if not P.db then return end
    P.events[event] = (P.events[event] or 0) + 1
    if event == "PLAYER_ENTERING_WORLD" then P.inWorld = true end
    if event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then P.inWorld = false end
    -- Counters only. Never retain event payloads or trigger automatic scans.
end)
local function Report()
    local text = P.ReportText()
    if not text then P.Say("no_sample"); return end
    if not reportWindow then
        local window = CreateFrame("Frame", nil, UIParent)
        window:SetSize(720, 500); window:SetPoint("CENTER"); window:SetFrameStrata("DIALOG"); window:EnableMouse(true)
        local background = window:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints(); background:SetColorTexture(0.04, 0.04, 0.04, 0.98)
        local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -14); title:SetText(P.text.title)
        local close = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
        close:SetSize(90, 24); close:SetPoint("BOTTOM", 0, 10); close:SetText(P.text.close)
        close:SetScript("OnClick", function() window:Hide() end)
        local scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 16, -40); scroll:SetPoint("BOTTOMRIGHT", -34, 44)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true); edit:SetAutoFocus(false); edit:SetFontObject(ChatFontNormal)
        edit:SetWidth(650); edit:SetMaxLetters(0)
        edit:SetScript("OnEscapePressed", function() window:Hide() end)
        scroll:SetScrollChild(edit); window.edit = edit; reportWindow = window
    end
    reportWindow:Show(); reportWindow.edit:SetText(text); reportWindow.edit:SetFocus(); reportWindow.edit:HighlightText()
end
SLASH_YIBOBUILDSFOREVERPROBE1 = "/ybf"
SlashCmdList.YIBOBUILDSFOREVERPROBE = function(message)
    message = type(message) == "string" and message:lower():match("^%s*(.-)%s*$") or ""
    if message == "scan" then P.ScanTalents()
    elseif message == "bags" then P.ScanBags()
    elseif message == "report" then
        local ok, err = pcall(Report)
        if not ok then P.Say("report_error", tostring(P.Safe(err))) end
    elseif message:match("^item") then
        local bag, slot = message:match("^item%s+(%d+)%s+(%d+)$")
        P.ScanItem(tonumber(bag), tonumber(slot))
    else P.Say("ready") end
end
