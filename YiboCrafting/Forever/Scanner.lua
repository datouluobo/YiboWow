local Addon=_G.YiboCrafting
local Scanner={generation=0,state="unknown"}; Addon.Scanner=Scanner
-- Bounded, session-only technical evidence. Never serialize restricted values.
local function Describe(value,depth)
    if not Addon.Store:Plain(value) then return "<restricted>" end
    local kind=type(value)
    if kind=="string" then return string.format("%q",value:sub(1,160)) end
    if kind=="number" or kind=="boolean" or kind=="nil" then return tostring(value) end
    if kind~="table" or depth==0 then return "<"..kind..">" end
    local parts,count,included={},0,{}
    for _,key in ipairs({"recipeID","name","learned","isDummyRecipe","professionID","parentProfessionID","sourceCounter"}) do
        local field=value[key]
        if not Addon.Store:Plain(field) or field~=nil then
            parts[#parts+1]=Describe(key,0).."="..Describe(field,depth-1); included[key]=true
        end
    end
    for key,item in pairs(value) do
        count=count+1
        if #parts<12 and Addon.Store:Plain(key) and not included[key] then parts[#parts+1]=Describe(key,0).."="..Describe(item,depth-1) end
    end
    table.sort(parts)
    return "{"..table.concat(parts,",").."} count="..count
end
local function Trace(name,detail)
    local trace=Scanner.trace or {}; Scanner.trace=trace
    if #trace>=24 then table.remove(trace,1) end
    trace[#trace+1]=name..": "..detail
end
local function Read(callback,...)
    local name="missing API"
    for key,fn in pairs(C_TradeSkillUI or {}) do if type(fn)=="function" and fn==callback then name=key; break end end
    if callback==GetServerTime then name="GetServerTime" end
    if type(callback)~="function" then Trace(name,"unavailable"); return false end
    local ok,value=pcall(callback,...)
    local arguments={...}; local parts={}
    for index=1,select("#",...) do parts[#parts+1]=Describe(arguments[index],0) end
    Trace(name,"arg="..table.concat(parts,",").." ok="..tostring(ok).." value="..Describe(value,1))
    if not ok or not Addon.Store:Plain(value) then return false end
    return true,value
end
function Scanner:Context()
    self.detail="context"
    if not self.inWorld or not self.open or not ProfessionsFrame or type(ProfessionsFrame.IsShown)~="function" or not ProfessionsFrame:IsShown() then return nil,"closed" end
    local api=C_TradeSkillUI; if type(api)~="table" then return nil,"unavailable" end
    local ok,ready=Read(api.IsTradeSkillReady); if not ok or ready~=true then return nil,"pending" end
    for _,name in ipairs({"IsTradeSkillLinked","IsTradeSkillGuild","IsTradeSkillGuildMember","IsNPCCrafting"}) do
        local success,external=Read(api[name]); if not success or external~=false then return nil,"external" end
    end
    local success,info=Read(api.GetBaseProfessionInfo)
    if not success or type(info)~="table" then return nil,"pending" end
    for _,key in ipairs({"professionID","parentProfessionID","sourceCounter"}) do if not Addon.Store:Plain(info[key]) then return nil,"error" end end
    local id=info.parentProfessionID or info.professionID
    if not Addon.Store:Integer(id,1,2147483647) or not Addon.Store:Integer(info.professionID,1,2147483647)
        or not Addon.Store:Integer(info.sourceCounter,0,9007199254740991) or not Addon:OwnsProfession(id) then return nil,"profile" end
    return {id=id,childID=info.professionID,sourceCounter=info.sourceCounter}
end
function Scanner:Pass(context,stamp)
    local api=C_TradeSkillUI
    self.detail="recipe_ids"
    local ok,ids=Read(api.GetAllRecipeIDs)
    if not ok or type(ids)~="table" then return nil,"unavailable" end
    local length,seen,recipes=0,{},{}
    for key,id in pairs(ids) do
        if not Addon.Store:Integer(key,1,20000) or not Addon.Store:Integer(id,1,2147483647) or seen[id] then return nil,"error" end
        length=length+1; seen[id]=true
    end
    if length~=#ids then return nil,"error" end
    for _,id in ipairs(ids) do
        self.detail="recipe_info:"..id
        local success,info=Read(api.GetRecipeInfo,id)
        if not success or type(info)~="table" then return nil,"pending" end
        for _,key in ipairs({"recipeID","name","learned","isDummyRecipe"}) do if not Addon.Store:Plain(info[key]) then return nil,"error" end end
        if info.recipeID~=id or type(info.name)~="string" or info.name=="" or type(info.learned)~="boolean" then self.detail="recipe_fields:"..id; return nil,"error" end
        if info.isDummyRecipe~=nil and type(info.isDummyRecipe)~="boolean" then self.detail="dummy_field:"..id; return nil,"error" end
        self.detail="recipe_profession:"..id.." expected="..context.id
        local matched,profession=Read(api.GetProfessionInfoByRecipeID,id)
        if not matched or type(profession)~="table" or not Addon.Store:Plain(profession.parentProfessionID) or not Addon.Store:Plain(profession.professionID)
            or not Addon.Store:Integer(profession.parentProfessionID or profession.professionID,1,2147483647) then return nil,"error" end
        local belongs=(profession.parentProfessionID or profession.professionID)==context.id
        if not belongs then
            -- A recipe ID can resolve to another profession. Check membership in
            -- the open skill line before accepting a shared recipe or excluding it.
            self.detail="recipe_membership:"..id.." skillLine="..context.childID
            local checked,inLine=Read(api.IsRecipeInSkillLine,id,context.childID)
            if not checked or type(inLine)~="boolean" then return nil,"error" end
            if not inLine and context.childID~=context.id then
                self.detail="recipe_membership:"..id.." skillLine="..context.id
                checked,inLine=Read(api.IsRecipeInSkillLine,id,context.id)
                if not checked or type(inLine)~="boolean" then return nil,"error" end
            end
            belongs=inLine
            Trace("recipe_membership", "recipe="..id.." owner="..context.id.." included="..tostring(belongs))
        end
        if belongs and info.isDummyRecipe~=true then recipes[id]={recipeID=id,name=info.name,learned=info.learned,observedAt=stamp} end
    end
    return recipes
end
local function Equal(a,b)
    for id,row in pairs(a) do local other=b[id]; if not other or other.name~=row.name or other.learned~=row.learned then return false end end
    for id in pairs(b) do if not a[id] then return false end end
    return true
end
function Scanner:Fail(state) self.state=state; Addon:NotifyChanged(); return false end
function Scanner:Scan()
    if not Addon.initialized then return false end
    self.trace={}; self.detail=nil
    local context,state=self:Context(); if not context then return self:Fail(state) end
    local id=Addon.Core.Characters:GetCurrentID(); if not id then return self:Fail("profile") end
    local ok,stamp=Read(GetServerTime); if not ok or not Addon.Store:Integer(stamp,0,9007199254740991) then return self:Fail("error") end
    local first,reason=self:Pass(context,stamp); if not first then return self:Fail(reason) end
    local second,otherReason=self:Pass(context,stamp); if not second then return self:Fail(otherReason) end
    local after=self:Context()
    if not after or after.id~=context.id or after.childID~=context.childID or after.sourceCounter~=context.sourceCounter
        or id~=Addon.Core.Characters:GetCurrentID() or not Equal(first,second) then self.detail="source_or_rows_changed"; return self:Fail("error") end
    if not next(second) then return self:Fail("pending") end
    self.detail="commit"
    return Addon.Store:Commit(id,context.id,second,stamp)
end
function Scanner:ReportText()
    local inventory={}
    for _,name in ipairs({"GetAllRecipeIDs","GetRecipeInfo","GetProfessionInfoByRecipeID","GetBaseProfessionInfo","IsRecipeInSkillLine"}) do
        inventory[#inventory+1]=name.."="..type((C_TradeSkillUI or {})[name])
    end
    return table.concat({"YiboCrafting Forever "..Addon.VERSION,"state="..tostring(self.state),
        "detail="..tostring(self.detail),"inWorld="..tostring(self.inWorld).." open="..tostring(self.open),
        table.concat(inventory,"\n"),
        table.concat(self.trace or {},"\n")},"\n")
end
function Scanner:Report()
    -- Explicit slash-only diagnostic, separate from the account view and settings.
    if not self.reportWindow then
        local f=CreateFrame("Frame",nil,UIParent); f:SetSize(720,500); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:EnableMouse(true)
        local bg=f:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.04,0.04,0.04,0.98)
        local title=f:CreateFontString(nil,"OVERLAY","GameFontNormal"); title:SetPoint("TOP",0,-14); title:SetText(Addon:T("FOREVER.REPORT_TITLE"))
        local close=Addon.Core.UITheme:CreateButton(f,90,Addon:T("FOREVER.REPORT_CLOSE")); close:SetPoint("BOTTOM",0,10); close:SetScript("OnClick",function() f:Hide() end)
        local scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate"); scroll:SetPoint("TOPLEFT",16,-40); scroll:SetPoint("BOTTOMRIGHT",-34,44)
        local edit=CreateFrame("EditBox",nil,scroll); edit:SetMultiLine(true); edit:SetAutoFocus(false); edit:SetFontObject(ChatFontNormal); edit:SetWidth(650); edit:SetMaxLetters(0)
        edit:SetScript("OnEscapePressed",function() f:Hide() end); scroll:SetScrollChild(edit); f.edit=edit; self.reportWindow=f
    end
    self.reportWindow:Show(); local edit=self.reportWindow.edit; edit:SetText(self:ReportText()); edit:SetFocus(); edit:HighlightText()
end
function Scanner:Cancel() self.generation=self.generation+1; self.queued=false end
function Scanner:Request()
    if self.queued or not self.inWorld then return end
    self.queued=true; local generation=self.generation
    local function Run() if generation~=self.generation then return end; self.queued=false; self:Scan() end
    if C_Timer and type(C_Timer.After)=="function" then C_Timer.After(0.25,Run) else Run() end
end
function Scanner:OnEvent(event)
    if event=="PLAYER_ENTERING_WORLD" then self:Cancel(); self.inWorld=true; self.state="unknown"
    elseif event=="PLAYER_LEAVING_WORLD" or event=="PLAYER_LOGOUT" then self:Cancel(); self.inWorld,self.open=false,false; self.state="closed"; Addon:NotifyChanged(); return
    elseif event=="TRADE_SKILL_SHOW" then self:Cancel(); self.open=true
    elseif event=="TRADE_SKILL_CLOSE" then self:Cancel(); self.open=false; self.state="closed"; Addon:NotifyChanged(); return
    elseif event=="TRADE_SKILL_DATA_SOURCE_CHANGED" then self:Cancel(); self.state="pending" end
    self:Request()
end
