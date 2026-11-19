local addon={NativeUI={},db={settings={}},ViewModel={Money=function(_,value) return tostring(value) end}}
YiboMail=addon
addon.T=function(_,key) return key end
local messages=0
addon.Print=function() messages=messages+1 end
local open, enabled, sends, hidden, failPopup=true,true,0,0,false
local fields={recipient="Alt-Realm",subject="Gold",body="Draft",copper=100,cod=false}
local attachments={{slot=1,itemLink="item:42",quantity=2}}
addon.Compose={ReadDraftFields=function() return fields end,GetAttachments=function() return attachments end}
addon.Scanner={IsOpen=function() return open end}
StaticPopupDialogs={}
local popupKey
YiboCore={Client={ShowPopup=function(_,key) popupKey=key; return not failPopup and {} or nil end,
    HidePopup=function() hidden=hidden+1 end}}
dofile("YiboCore/UI/ItemConfirmation.lua")
addon.Core=YiboCore
dofile("YiboMail/Common/MoneySendConfirmation.lua")
local native=addon.NativeUI
local button={IsEnabled=function() return enabled end}
local function Send(_,mouse) assert(mouse=="LeftButton"); sends=sends+1 end
local function Confirm() native:ConfirmMoneySend(button,Send,{"LeftButton"}) end
local function Accept()
    local data=YiboCore.ItemConfirmation.active
    assert(data); StaticPopupDialogs[popupKey].OnAccept(nil,data)
    StaticPopupDialogs[popupKey].OnAccept(nil,data)
end
Confirm(); Confirm(); assert(sends==0 and native.moneyConfirmPending)
Accept(); assert(sends==1 and not native.moneyConfirmPending)
for _,key in ipairs({"recipient","subject","body","copper","cod"}) do
    local previous=fields[key]; Confirm()
    fields[key]=type(previous)=="number" and previous+1 or type(previous)=="boolean" and not previous or previous.." changed"
    Accept(); assert(sends==1 and not native.moneyConfirmPending,"Changed "..key.." must reject")
    fields[key]=previous
end
Confirm(); attachments[1].quantity=3; Accept(); assert(sends==1); attachments[1].quantity=2
Confirm(); open=false; Accept(); assert(sends==1); open=true
Confirm(); enabled=false; Accept(); assert(sends==1); enabled=true
Confirm(); native:CancelMoneySendConfirmation(); assert(not native.moneyConfirmPending and hidden==1)
Confirm(); YiboCore.ItemConfirmation.active:Cancel(); assert(not native.moneyConfirmPending)
failPopup=true; Confirm(); assert(not native.moneyConfirmPending and not YiboCore.ItemConfirmation.active and sends==1)
failPopup=false; addon.db.settings.confirmGoldSend=false; Confirm(); assert(sends==2)
assert(not StaticPopupDialogs.YIBOMAIL_CONFIRM_GOLD_SEND,"No parallel Mail confirmation popup")
assert(messages>0)
print("PASS: real Core confirmation; exact draft/attachment recheck; single send; close/disable/cancel/failure; user setting")
