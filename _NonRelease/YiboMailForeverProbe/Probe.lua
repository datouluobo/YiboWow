-- Observes native user operations. Never calls a mailbox mutation or reads body text.
local frame, active, db = CreateFrame("Frame"), false
local initialized, observedButtons = false, {}
local function Stamp() return GetServerTime and GetServerTime() or time() end
local function Hash(value)
    local hash = 0
    for index = 1, #tostring(value or "") do hash = (hash * 31 + tostring(value):byte(index)) % 2147483647 end
    return hash
end
local function Record(kind, data)
    if not active or not db then return end
    if #db.entries >= 1000 then active = false; return end
    db.entries[#db.entries + 1] = {time=Stamp(), kind=kind, data=data}
end
local function Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
end
local function Scalar(value)
    if type(issecretvalue)=="function" and issecretvalue(value) then return "restricted" end
    if value==nil or type(value)=="boolean" or type(value)=="number" then return value end
    return type(value)
end
local controls = {"MailFrame", "InboxFrame", "SendMailFrame", "SendMailNameEditBox",
    "SendMailSubjectEditBox", "MailEditBox", "SendMailBodyEditBox", "SendMailMoney",
    "SendMailCODButton", "SendMailMailButton", "SendMailSendButton", "SendMailFrameLockSendMail"}
local function Sample(reason)
    if not active then return end
    local data = {reason=reason, controls={}}
    for _, name in ipairs(controls) do
        local control = _G[name]
        data.controls[name] = control and {shown=Read(control.IsShown, control),
            editBox=type(control.GetEditBox)=="function", click=type(control.Click)=="function"} or false
    end
    local open = MailFrame and Read(MailFrame.IsShown, MailFrame)
    data.open = open == true
    data.pending = C_Mail and Read(C_Mail.IsCommandPending)
    data.receiveSlots, data.sendSlots = ATTACHMENTS_MAX_RECEIVE, ATTACHMENTS_MAX_SEND
    data.character = Hash(UnitGUID and UnitGUID("player"))
    if open and SendMailFrame and Read(SendMailFrame.IsShown, SendMailFrame) then
        local recipient=SendMailNameEditBox and Read(SendMailNameEditBox.GetText,SendMailNameEditBox)
        local subject=SendMailSubjectEditBox and Read(SendMailSubjectEditBox.GetText,SendMailSubjectEditBox)
        data.send={recipientHash=Hash(recipient),subjectHash=Hash(subject),
            copper=SendMailMoney and Read(MoneyInputFrame_GetCopper,SendMailMoney),
            cod=SendMailCODButton and Read(SendMailCODButton.GetChecked,SendMailCODButton),items={}}
        for slot=1,math.min(tonumber(ATTACHMENTS_MAX_SEND) or 0,32) do
            local ok,name,id,_,quantity=pcall(GetSendMailItem,slot)
            if not ok then data.send.itemError=true; break end
            if name then
                local link=Read(GetSendMailItemLink,slot)
                data.send.items[#data.send.items+1]={slot=slot,id=id,quantity=quantity,linkHash=Hash(link)}
            end
        end
    end
    for _,name in ipairs({"SendMailMailButton","SendMailSendButton"}) do
        local button=_G[name]
        if button and type(button.HookScript)=="function" and not observedButtons[button] then
            observedButtons[button]=true
            button:HookScript("OnMouseDown",function() Sample("send-mouse-down") end)
        end
    end
    if open then
        data.loaded, data.total = Read(GetInboxNumItems)
        data.headers = {}
        for index = 1, math.min(tonumber(data.loaded) or 0, 100) do
            local ok, _, _, sender, subject, money, cod, days, count, wasRead, returned, _, canReply, isGM = pcall(GetInboxHeaderInfo, index)
            local header = {ok=ok, sender=ok and Hash(sender), subject=ok and Hash(subject),
                money=ok and money, cod=ok and cod, days=ok and days, count=ok and count,
                wasRead=ok and wasRead, returned=ok and returned, canReply=ok and Scalar(canReply), isGM=ok and Scalar(isGM),
                canDelete=Scalar(Read(InboxItemCanDelete,index)), items={}}
            for slot=1, math.min(tonumber(ATTACHMENTS_MAX_RECEIVE) or 0, 32) do
                local success, name, id, _, quantity, _, _, currency = pcall(GetInboxItem, index, slot)
                if not success then header.itemError=true; break end
                if name then header.items[#header.items+1]={slot=slot, id=id, quantity=quantity, currency=currency} end
            end
            data.headers[#data.headers+1]=header
        end
    end
    Record("sample", data)
end
local function Initialize()
    if initialized then return end
    if WOW_PROJECT_ID ~= WOW_PROJECT_CAMELOT or type(WOW_PROJECT_CAMELOT) ~= "number" then return end
    YiboMailForeverProbeDB = YiboMailForeverProbeDB or {schema=1, entries={}}
    db = YiboMailForeverProbeDB
    if db.schema ~= 1 or type(db.entries) ~= "table" then return end
    initialized = true
    db.build = {GetBuildInfo()}; db.project = WOW_PROJECT_ID
    db.hooks, db.events = {}, {}
    for _, event in ipairs({"MAIL_SHOW", "MAIL_CLOSED", "MAIL_INBOX_UPDATE", "MAIL_SUCCESS", "MAIL_FAILED",
        "MAIL_SEND_SUCCESS", "MAIL_SEND_INFO_UPDATE", "UI_ERROR_MESSAGE", "ADDON_ACTION_BLOCKED"}) do
        db.events[event] = pcall(frame.RegisterEvent, frame, event)
    end
    for _, name in ipairs({"TakeInboxItem", "TakeInboxMoney", "ReturnInboxItem", "DeleteInboxItem", "SendMail", "ClickSendMailItemButton"}) do
        local action = name
        if type(_G[action]) == "function" and hooksecurefunc then
            db.hooks[action] = pcall(hooksecurefunc, action, function(a,b)
                -- Never record SendMail arguments (addresses, subjects or body).
                Record("action", {name=action, index=action~="SendMail" and tonumber(a) or nil,
                    slot=action=="TakeInboxItem" and tonumber(b) or nil})
            end)
        else db.hooks[action] = false end
    end
    SLASH_YIBOMAILFOREVERPROBE1 = "/ymf"
    SlashCmdList.YIBOMAILFOREVERPROBE = function(message)
        if message == "on" then active=true; Sample("start")
        elseif message == "off" then Sample("stop"); active=false
        elseif message == "sample" then Sample("manual") end
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("YiboMailForeverProbe: " .. tostring(active) .. " / " .. #db.entries) end
    end
end
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, name)
    if event=="ADDON_LOADED" then if name=="YiboMailForeverProbe" then Initialize() end; return end
    Record("event", {name=event})
    if event=="MAIL_SHOW" or event=="MAIL_CLOSED" or event=="MAIL_INBOX_UPDATE" or event=="MAIL_SEND_INFO_UPDATE" then Sample(event) end
end)
