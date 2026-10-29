local Addon=_G.YiboCrafting
local Store={}; Addon.Store=Store
function Store:Plain(value) return type(issecretvalue)~="function" or not issecretvalue(value) end
function Store:Integer(value,min,max) return self:Plain(value) and type(value)=="number" and value>=min and value<=max and value%1==0 end
function Store:ValidRecipe(id,row)
    return self:Integer(id,1,2147483647) and type(row)=="table" and row.recipeID==id and type(row.name)=="string" and row.name~=""
        and type(row.learned)=="boolean" and self:Integer(row.observedAt,0,9007199254740991)
end
function Store:Initialize()
    local db=_G.YiboCraftingForeverDB
    if db~=nil then
        if type(db)~="table" or db.schema~=1 or type(db.clientScope)~="table" or db.clientScope.target~="Forever"
            or db.clientScope.projectID~=WOW_PROJECT_ID or db.clientScope.scope~="current-character" or type(db.characters)~="table"
            or type(db.settings)~="table" or type(db.settings.previewColumns)~="table" then return false end
        for id,character in pairs(db.characters) do
            if type(id)~="string" or type(character)~="table" or type(character.professions)~="table" then return false end
            for professionID,profession in pairs(character.professions) do
                if not self:Integer(professionID,1,2147483647) or type(profession)~="table" or type(profession.recipes)~="table"
                    or not self:Integer(profession.observedAt,0,9007199254740991) then return false end
                for recipeID,row in pairs(profession.recipes) do if not self:ValidRecipe(recipeID,row) then return false end end
            end
        end
    else
        db={schema=1,clientScope={target="Forever",projectID=WOW_PROJECT_ID,scope="current-character",rulesetState="unknown"},characters={},
            settings={previewColumns={profession=true,recipe=true,learned=true,state=true}}}
    end
    self.db=db; _G.YiboCraftingForeverDB=db; return true
end
function Store:Get(id)
    if not id or id~=Addon.Core.Characters:GetCurrentID() then return nil,"unsupported-scope" end
    local character=self.db.characters[id]
    return character and Addon.Core.Defaults:Copy(character) or nil
end
function Store:Commit(id,professionID,recipes,stamp)
    if id~=Addon.Core.Characters:GetCurrentID() or not Addon:OwnsProfession(professionID) or not self:Integer(stamp,0,9007199254740991) then return false end
    for key,row in pairs(recipes) do if not self:ValidRecipe(key,row) then return false end end
    local character=self.db.characters[id] or {professions={}}
    local previous=character.professions[professionID]
    local snapshot=previous and Addon.Core.Defaults:Copy(previous) or {recipes={}}
    for key,row in pairs(recipes) do snapshot.recipes[key]=Addon.Core.Defaults:Copy(row) end
    snapshot.observedAt=stamp; character.professions[professionID]=snapshot; self.db.characters[id]=character
    self.freshRecipes=Addon.Core.Defaults:Copy(recipes); self.freshID=id; self.freshProfessionID=professionID
    Addon.Scanner.state="partial"; Addon:NotifyChanged(); return true
end
function Store:IsFresh(id,professionID,recipeID)
    return Addon.Scanner.inWorld and Addon.Scanner.open and Addon.Scanner.state=="partial" and self.freshID==id
        and self.freshProfessionID==professionID and self.freshRecipes and self.freshRecipes[recipeID]~=nil and Addon:OwnsProfession(professionID)
end
function Store:Delete(character,context)
    local record=self.db.characters[character.id]
    if context and context.replay and record and self:Integer(context.deletedAt,0,9007199254740991) then
        local now=GetServerTime()
        for pid,profession in pairs(record.professions) do
            for rid,row in pairs(profession.recipes) do if row.observedAt<=context.deletedAt or row.observedAt>now then profession.recipes[rid]=nil end end
            if not next(profession.recipes) then record.professions[pid]=nil end
        end
        if next(record.professions) then Addon:NotifyChanged(); return true end
    end
    self.db.characters[character.id]=nil
    if character.id==Addon.Core.Characters:GetCurrentID() then Addon.Scanner:Cancel(); self.freshID=nil; Addon.Scanner.state="unknown" end
    Addon:NotifyChanged(); return true
end
