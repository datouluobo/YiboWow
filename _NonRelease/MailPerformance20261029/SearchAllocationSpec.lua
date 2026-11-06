dofile('_NonRelease/MailPerformance20261029/OpenPeakSpec.lua')
local A=YiboMail
local current=A.ViewModel
local role=A.Core.Characters:GetCurrent({identityOnly=true})
local context={characters={role}}
dofile('_NonRelease/MailPerformance20261029/PeakR4-before-ViewModel.lua')
local previous=A.ViewModel;A.ViewModel=current
for _,search in ipairs({'','open1','item101','sender','alpha','99','not found'}) do
    for _,kind in ipairs({'all','items','money','cod','urgent'}) do
        for _,sort in ipairs({'inbox','expiry'}) do
            local options={search=search,kind=kind,sort=sort}
            local before=previous:GetMails(context,options)
            local after=current:GetMails(context,options)
            assert(#before==#after,'Search/filter admission unchanged')
            for i,entry in ipairs(before) do
                assert(entry.key==after[i].key and entry.mail==after[i].mail and entry.actionable==after[i].actionable and entry.restriction==after[i].restriction)
            end
        end
    end
end
local concat=table.concat;local calls=0
table.concat=function(...) calls=calls+1;return concat(...) end
current:GetMails(context,{search=''})
table.concat=concat
assert(calls==0,'Empty search must not assemble per-letter attachment search strings')
A.Scanner.validAt=nil
local entries=current:GetMails(context,{search=''})
for _,entry in ipairs(entries) do assert(not entry.actionable,'Fresh live readiness is required on every projection') end
print('PASS: 70 search/filter/sort combinations preserve entries and restrictions; empty searches allocate no search strings; live readiness remains checked')
