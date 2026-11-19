-- Real Core target manifests, no player files or native mutations.
local Boot = dofile("_NonRelease/CoreRetailR2/Harness.lua")
local checks = 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
for _, target in ipairs({"Retail", "Mists", "Forever"}) do
    local mode = "known"
    local secret = {}
    local env, core, event = Boot(target,nil,nil,function(e)
        e.issecretvalue = function(value) return value == secret end
        e.GetItemInfo = function(id)
            if mode=="throw" then error("unavailable") end
            if mode=="unloaded" then return nil end
            if mode=="sparse" then return "Item", "item:"..id end
            if mode=="secret" then return "Item", "item:"..id, secret end
            if mode=="invalid" then return "Item", "item:"..id, "epic", nil,nil,nil,nil,nil,nil,123,nil,-1,0/0 end
            return "Item", "item:"..id, 4, nil,nil,nil,nil,nil,nil,123,nil,7,0
        end
        e.C_Item.GetItemInfo = e.GetItemInfo
    end)
    event("ADDON_LOADED"); event("PLAYER_LOGIN")
    Check(core:IsInitialized() and core:HasCapability("item-resolver",2),"metadata capability")
    Check(core:HasCapability("item-resolver",1),"v1 capability compatibility")
    local info=core.ItemResolver:GetInfo(100)
    Check(info.state=="ready" and info.quality==4 and info.classID==7 and info.subclassID==0,"native positions and valid zero subclass")
    local delivered
    core.ItemResolver:Request(100,function(result) delivered=result end)
    Check(delivered and delivered.quality==4 and delivered.classID==7,"request callback shares metadata contract")
    info.quality,info.classID=0,0
    Check(core.ItemResolver:GetInfo(100).quality==4 and core.ItemResolver:GetInfo(100).classID==7,"detached metadata")
    mode="sparse"; info=core.ItemResolver:GetInfo(100)
    Check(info.state=="ready" and info.quality==nil and info.classID==nil and info.subclassID==nil,"legacy sparse metadata remains unknown")
    mode="invalid"; info=core.ItemResolver:GetInfo(100)
    Check(info.state=="ready" and info.name=="Item" and info.quality==nil and info.classID==nil and info.subclassID==nil,"invalid metadata preserves v1 fields")
    mode="unloaded"; info=core.ItemResolver:GetInfo(100)
    Check(info.state=="unloaded" and info.quality==nil and info.classID==nil,"unloaded never fabricates class")
    mode="throw"; info=core.ItemResolver:GetInfo(100)
    Check(info.state=="unloaded" and info.availability=="error" and info.quality==nil,"read failure preserves availability contract")
    Check(core.ItemResolver:GetInfo(-1)==nil,"invalid item input rejected")
    mode="secret"; info=core.ItemResolver:GetInfo(100)
    Check(info.availability=="unavailable" and info.name==nil and info.quality==nil,"restricted metadata not exposed")
end
print("PASS: item metadata "..checks.." checks (Retail/Mists/Forever actual manifests)")
