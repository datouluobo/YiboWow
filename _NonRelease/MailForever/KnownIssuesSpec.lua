local Boot = dofile("_NonRelease/MailForever/Harness.lua")
for _, language in ipairs({"zh", "en"}) do
    local e, core, mail, fire, flush, box = Boot(nil, function(_, c) c.Locale.sessionLanguage=language end)
    assert(mail.ViewModel:Money(1):find("0.0001",1,true), "one copper remains visible")
    assert(mail.ViewModel:Money(10001):find("1.0001",1,true), "gold plus copper remains exact")
    assert(mail.ViewModel:Money(100):find("0.01",1,true), "silver retains compact formatting")
    fire("PLAYER_ENTERING_WORLD"); box.open=true; box.headers[1].money=1; box.headers[2].money=0
    fire("MAIL_SHOW"); flush()
    assert(mail.AccountPage:GetSummary(core.Characters:GetCurrent()).money==mail.ViewModel:Money(1), "summary shares precise amount")
end
local BootCore = dofile("_NonRelease/CoreForever/Harness.lua")
for _, available in ipairs({true, false}) do
    local env, core = BootCore(true, nil, nil, function(e)
        e.GetAverageItemLevel=nil; e.C_PaperDollInfo=nil; e.GetItemInfo=nil
        e.GetInventoryItemLink=function(_, slot) if slot==16 then return "item:100" end end
        e.C_Item.GetItemInfo=available and function() return "Item", "item:100", 1, 7 end or nil
    end)
    local result,state=core.DataDomains._definitions.equipment.Collect()
    assert(available and state=="known" and result.itemLevel==7 or not available and result==nil and state=="unavailable",
        "equipment supports namespaced item API and reports missing data")
end
print("PASS: exact copper in both languages and summary; Forever equipment without legacy API")
