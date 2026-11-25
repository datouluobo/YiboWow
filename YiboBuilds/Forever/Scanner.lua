local Addon=_G.YiboBuilds
local Scanner={generation=0}; Addon.Scanner=Scanner
local function Read(fn,...)
    if type(fn)~="function" then return false end
    local ok,value=pcall(fn,...)
    if not ok or not Addon.Store:Plain(value) then return false end
    return true,value
end
function Scanner:Pass()
    local slots,count={},0
    for slot=1,19 do
        local ok,id=Read(GetInventoryItemID,"player",slot)
        local linked,link=Read(GetInventoryItemLink,"player",slot)
        if not ok or not linked or (id~=nil and not Addon.Store:Integer(id,1,2147483647))
            or (link~=nil and (type(link)~="string" or link=="" or id==nil)) then return nil end
        if link then
            local parsed,items=pcall(Addon.Core.ItemResolver.Parse,Addon.Core.ItemResolver,link,{allowName=false,allowID=false})
            if not parsed or type(items)~="table" or not items[1] or items[1].itemID~=id then return nil end
        end
        slots[slot]={itemID=id or 0,itemLink=link}; if id then count=count+1 end
    end
    return slots,count
end
function Scanner:Fail() Addon.Store.freshID,Addon.Store.error=nil,true; Addon:NotifyChanged(); return false end
function Scanner:Scan(confirmEmpty)
    if not Addon.initialized or not self.inWorld then return false end
    local logged,inGame=Read(IsLoggedIn); if not logged or inGame~=true then return false end
    local id=Addon.Core.Characters:GetCurrentID(); if not id then return false end
    local timed,stamp=Read(GetServerTime)
    if not timed or not Addon.Store:Integer(stamp,0,9007199254740991) then return self:Fail() end
    local first,count=self:Pass(); if not first then return self:Fail() end
    local second,otherCount=self:Pass(); if not second then return self:Fail() end
    for slot=1,19 do if first[slot].itemID~=second[slot].itemID or first[slot].itemLink~=second[slot].itemLink then return self:Fail() end end
    if not self.inWorld or id~=Addon.Core.Characters:GetCurrentID() or count~=otherCount then return self:Fail() end
    if count==0 and not confirmEmpty then Addon.Store.freshID,Addon.Store.error=nil,nil; Addon:NotifyChanged(); return false end
    return Addon.Store:Commit(id,{slots=second,observedAt=stamp})
end
function Scanner:Cancel() self.generation=self.generation+1; self.queued,self.confirmEmpty=false,nil end
function Scanner:Request(confirmEmpty)
    self.confirmEmpty=self.confirmEmpty or confirmEmpty
    if self.queued or not self.inWorld then return end
    self.queued=true; local generation=self.generation
    local function Run()
        if generation~=self.generation then return end
        self.queued=false; local confirmed=self.confirmEmpty; self.confirmEmpty=nil; self:Scan(confirmed)
    end
    if C_Timer and type(C_Timer.After)=="function" then C_Timer.After(0.3,Run) else Run() end
end
function Scanner:OnEvent(event,unit)
    if event=="PLAYER_ENTERING_WORLD" then self:Cancel(); self.inWorld=true; self:Request(false)
    elseif event=="PLAYER_LEAVING_WORLD" or event=="PLAYER_LOGOUT" then self:Cancel(); self.inWorld=false; Addon.Store.freshID=nil; Addon:NotifyChanged()
    elseif event=="PLAYER_EQUIPMENT_CHANGED" or (event=="UNIT_INVENTORY_CHANGED" and unit=="player") then self:Request(true)
    elseif event=="BAG_UPDATE_DELAYED" then self:Request(false)
    elseif event=="GET_ITEM_INFO_RECEIVED" then Addon:NotifyChanged() end
end
