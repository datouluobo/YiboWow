
dofile('YiboMail/_NonRelease/Tests/NativeInboxSpec.lua')
local A=YiboMail; local N=A.NativeUI; local panel=N.inbox
A.Queue:Discard(); A.Queue.pending=nil
local function Populate()
    local item={itemID=9912,attachmentIndex=1,variantKey='item:9912',quantity=1,name='Reference item'}
    local second={itemID=9913,attachmentIndex=2,variantKey='item:9913',quantity=2,name='Second item'}
    local mail={inboxIndex=1,sender='Sender',subject='Reference mail',cod=0,money=0,attachments={item,second}}
    local entry={character={id='char'},mail=mail,key='lifetime',actionable=true}
    local group={id='lifetime',item=item,quantity=1,sources={{entry=entry,item=item}}}
    panel.used,panel.top,panel.available,panel.width=0,0,{},340
    N:Row({title='Reference mail',itemList=mail.attachments,mailEntryKey=entry.key,
        actions={{id='lifetime',actionable=true,entry=entry}},onClick=function() return entry end})
    N:ItemTile(group,1,7,42)
    panel.expanded={lifetime=true}; N.pendingItemInfo={[9912]=true}
    return setmetatable({entry,group,item,second},{__mode='v'})
end
for cycle=1,20 do
    local weak=Populate()
    assert(panel.rows[1]:GetScript('OnClick') and panel.tiles[1].mailGroup)
    local rowCount,tileCount=#panel.rows,#panel.tiles
    N:OnEvent('MAIL_CLOSED'); N:OnEvent('MAIL_CLOSED')
    collectgarbage('collect')
    for i=1,4 do assert(weak[i]==nil,'Hidden widgets must release business data, including child attachment tooltip closures') end
    assert(#panel.available==0 and next(panel.expanded)==nil and next(panel.selection)==nil and N.pendingItemInfo==nil)
    assert(#panel.rows==rowCount and #panel.tiles==tileCount,'Release preserves reusable widget pools')
    assert(not panel.rows[1]:GetScript('OnClick') and not panel.rows[1].check:GetScript('OnClick'))
    assert(panel.tiles[1].mailGroup==nil and not panel.tiles[1]:GetScript('OnEnter'))
    for _,button in ipairs(panel.rows[1].attachments.itemButtons) do assert(not button:GetScript('OnEnter')) end
end
print('PASS: 20 close/rebind cycles release row/tile/attachment callback graphs while reusing the widget pools')
