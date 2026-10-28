local Core = _G.YiboCore
local function Plain(value) return type(issecretvalue) ~= "function" or not issecretvalue(value) end
local function Integer(value,minimum,maximum) return Plain(value) and type(value)=="number" and value>=minimum and value<=maximum and value%1==0 end
local function Read(callback,...)
    if type(callback)~="function" then return nil end
    local values={pcall(callback,...)}
    if not values[1] then return nil end
    for i=2,12 do if not Plain(values[i]) then return nil end end
    return values
end
local function Pass()
    if type(GetProfessions)~="function" or type(GetProfessionInfo)~="function" then return nil,"unavailable" end
    local indices=Read(GetProfessions); if not indices then return nil,"unavailable" end
    local data,seen={professions={},primaryProfessions={},skillLineIDsAuthoritative=true},{}
    if indices[9]~=nil then return nil,"error" end
    -- Camelot's native profession page consumes two primary and five secondary slots.
    for slot=1,7 do
        local index=indices[slot+1]
        if index~=nil then
            if not Integer(index,1,10000) then return nil,"error" end
            local info=Read(GetProfessionInfo,index)
            if not info or type(info[2])~="string" or info[2]=="" or not Integer(info[8],1,2147483647)
                or not Integer(info[4],0,1000000) or not Integer(info[5],1,1000000) or info[4]>info[5] then return nil,"error" end
            local id=info[8]; if seen[id] then return nil,"error" end; seen[id]=true
            local icon=info[3]
            if icon~=nil and type(icon)~="number" and type(icon)~="string" then return nil,"error" end
            local row={id=id,slot=slot,name=info[2],icon=icon,skillLevel=info[4],maxSkillLevel=info[5]}
            data.professions[#data.professions+1]=row
            if slot<=2 then data.primaryProfessions[slot]=Core.Defaults:Copy(row) end
        end
    end
    return data
end
local function Equal(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not Equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
Core._private.RegisterProfessionDomain(
    {PLAYER_ENTERING_WORLD=true,SKILL_LINES_CHANGED=true,BAG_UPDATE_DELAYED=true},
    function(context)
        local function Keep(state) return nil,state end
        if IsLoggedIn then local ok,value=pcall(IsLoggedIn); if not ok or value~=true then return Keep("not-yet-scanned") end end
        local first,state=Pass(); if not first then return Keep(state) end
        local second,otherState=Pass(); if not second then return Keep(otherState) end
        if not Equal(first,second) then return Keep("error") end
        if #second.professions==0 and context.reason~="SKILL_LINES_CHANGED" then return Keep("not-yet-scanned") end
        local timestamp=Read(GetServerTime)
        if not timestamp or not Integer(timestamp[2],0,9007199254740991) then return Keep("error") end
        second.observedAt=timestamp[2]
        return second,"known"
    end)
Core.Capabilities:Register("profession-profile",1)
