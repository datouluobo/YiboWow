
dofile('YiboMail/_NonRelease/Tests/WorkspaceSpec.lua')
local C=YiboCore
dofile("YiboCore/Util/CharacterSort.lua"); dofile("YiboCore/UI/AccountView.lua")
local V=C.AccountView
C.Print=function(_,message) error(message) end
local database={characters={byID={}},settings={accountView={hiddenCharacters={Hidden=true},selectedRealmScope='all'}}}
for index,id in ipairs({'A','B','Hidden'}) do
    local row={id=id,name=id,realm=index==1 and 'One' or 'Two',class='MAGE',level=80,seenOrder=index,lastSeenAt=index,domains={large={}}}
    for n=1,10000 do row.domains.large[n]={value=n} end
    database.characters.byID[id]=row
end
C.Database={GetDB=function() return database end}
dofile('YiboCore/Data/Characters.lua')
C.Characters.GetCurrentID=function() return 'A' end
local page={id='identity-test',title='Identity',fields={},scope={mode='realms'},GetEligibleCharacters=function(rows)
    local result={}; for _,r in ipairs(rows) do if r.level>=60 then result[#result+1]=r end end; return result
end,HasCharacterSnapshot=function() return true end}
V._pages[page.id]=page
local function Measure(options)
    collectgarbage('collect'); collectgarbage('stop'); local before=collectgarbage('count')
    local context=V:BuildContext(page,options)
    local allocated=collectgarbage('count')-before
    collectgarbage('restart'); return context,allocated
end
local light,lightKB=Measure({identityOnly=true})
assert(#light.characters==2 and C.Characters._allSnapshot==nil,'Light context must not warm full account/domain snapshots through sorting or scope')
for _,r in ipairs(light.characters) do assert(r.domains==nil) end
local full,fullKB=Measure({})
assert(full.characters[1].domains and #full.characters==#light.characters)
for i,r in ipairs(full.characters) do assert(r.id==light.characters[i].id) end
assert(fullKB>lightKB*100)
C.Characters:InvalidateAllCache()
database.settings.accountView.selectedRealmScope='realm:Two'
assert(#V:BuildContext(page,{identityOnly=true}).characters==1)
assert(C.Characters._allSnapshot==nil)
print(string.format('PASS: real Core context, default domains preserved; hidden/admission/scope/sort match; full %.2f MB vs identity %.2f KB; no full cache warmed',fullKB/1024,lightKB))
