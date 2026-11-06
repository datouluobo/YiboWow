dofile('YiboMail/_NonRelease/Tests/NativeInboxSpec.lua')
local A,N=YiboMail,YiboMail.NativeUI
local timers,refreshes={},0
C_Timer={After=function(_,fn) timers[#timers+1]=fn end}
A.Scanner.IsOpen=function() return true end
N.inbox:Show()
N.RefreshInbox=function() refreshes=refreshes+1 end
N.pendingItemInfo={}
for i=1,100 do N.pendingItemInfo[i]=true end
for i=1,100 do N:OnEvent('GET_ITEM_INFO_RECEIVED',i,true) end
assert(refreshes==0 and #timers==1,'One frame of item arrivals schedules one inbox presentation')
table.remove(timers,1)();assert(refreshes==1 and not N.itemRefreshTicket)
N:OnEvent('GET_ITEM_INFO_RECEIVED',10000,true);assert(#timers==0)
N.pendingItemInfo={[201]=true};N:OnEvent('GET_ITEM_INFO_RECEIVED',201,false)
assert(#timers==0 and not N.pendingItemInfo[201])
N.pendingItemInfo={[202]=true};N:OnEvent('GET_ITEM_INFO_RECEIVED',202,true)
local old=table.remove(timers,1)
N:ReleaseInboxPresentation();assert(not N.itemRefreshTicket)
N.pendingItemInfo={[203]=true};N:OnEvent('GET_ITEM_INFO_RECEIVED',203,true)
old();assert(refreshes==1,'Old session callback must not draw into a new pending request')
table.remove(timers,1)();assert(refreshes==2)
local relinks,hidden=0,0
local tile={mailGroup={quantity=2,sources={{entry={character={id='A'},key='m1',mail={signature='sig',cod=0}},item={attachmentIndex=1,variantKey='item:1',quantity=2}}}},eligibleCount=1,count={SetText=function() end}}
function tile:GetScript() return function() relinks=relinks+1 end end
N.inbox.tiles={tile};N.inbox.mode='items';N.inbox.keepTilesDuringQueue=true;N.inbox.selection={a=true}
GameTooltip.GetOwner=function() return tile end
GameTooltip.Hide=function() hidden=hidden+1 end
N:OnCollected('a',{characterID='A',mailKey='m1',signature='sig',slot=1,item={attachmentIndex=1,variantKey='item:1',quantity=2}})
assert(hidden==1 and relinks==0 and #tile.mailGroup.sources==0 and tile.mailGroup.quantity==0,'Confirmed removal dismisses stale tooltip without re-entering native item hook chains')
print('PASS: 100 item events coalesce once; unrelated/failed events, cancelled sessions and new tickets; collected hover never programmatically reopens native hyperlink')
