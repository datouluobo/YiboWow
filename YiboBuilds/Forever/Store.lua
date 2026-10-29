local Addon=_G.YiboBuilds
local Store={}; Addon.Store=Store
function Store:Plain(value) return not (type(issecretvalue)=="function" and issecretvalue(value)) end
function Store:Integer(value,min,max) return self:Plain(value) and type(value)=="number" and value>=min and value<=max and value%1==0 end
function Store:Valid(row)
    if type(row)~="table" or not self:Integer(row.observedAt,0,9007199254740991) or type(row.slots)~="table" then return false end
    local count=0
    for slot,item in pairs(row.slots) do
        if not self:Integer(slot,1,19) or type(item)~="table" or not self:Integer(item.itemID,0,2147483647)
            or not self:Plain(item.itemLink) or (item.itemLink~=nil and (type(item.itemLink)~="string" or item.itemLink=="" or item.itemID==0)) then return false end
        count=count+1
    end
    return count==19
end
function Store:Initialize()
    local db=_G.YiboBuildsForeverDB
    if db~=nil then
        if type(db)~="table" or db.schema~=1 or type(db.clientScope)~="table" or db.clientScope.target~="Forever"
            or db.clientScope.projectID~=WOW_PROJECT_ID or db.clientScope.scope~="current-character" or type(db.characters)~="table"
            or type(db.settings)~="table" or type(db.settings.previewColumns)~="table" then return false end
        for id,row in pairs(db.characters) do if type(id)~="string" or not self:Valid(row) then return false end end
    else
        db={schema=1,clientScope={target="Forever",projectID=WOW_PROJECT_ID,scope="current-character",rulesetState="unknown"},characters={},
            settings={previewColumns={slot=true,item=true}}}
    end
    self.db=db; _G.YiboBuildsForeverDB=db; return true
end
function Store:Get(id)
    if id~=Addon.Core.Characters:GetCurrentID() then return nil,"unsupported-scope" end
    local row=self.db and self.db.characters[id]
    local state=self.error and "error" or (row and (self.freshID==id and Addon.Scanner.inWorld and "known" or "stale") or "unknown")
    return row and Addon.Core.Defaults:Copy(row) or nil,state
end
function Store:Commit(id,row)
    if id~=Addon.Core.Characters:GetCurrentID() or not self:Valid(row) then return false end
    self.db.characters[id]=Addon.Core.Defaults:Copy(row); self.freshID,self.error=id,nil; Addon:NotifyChanged(); return true
end
function Store:Delete(character,context)
    local row=self.db.characters[character.id]
    local now=GetServerTime and GetServerTime()
    if context and context.replay and row and self:Integer(context.deletedAt,0,9007199254740991) and self:Integer(now,0,9007199254740991) and row.observedAt>context.deletedAt and row.observedAt<=now then return true end
    self.db.characters[character.id]=nil
    if character.id==Addon.Core.Characters:GetCurrentID() then Addon.Scanner:Cancel(); self.freshID,self.error=nil,nil end
    Addon:NotifyChanged(); return true
end
