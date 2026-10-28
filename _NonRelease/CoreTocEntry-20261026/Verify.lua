-- Exercise only the new formal Core entry candidate and its store boundaries.
local root = (arg and arg[1] or "_NonRelease/CoreTocEntry-20261026/Candidate/YiboCore/"):gsub("\\","/"):gsub("/*$", "/")
local checks = 0
local function Check(value, label) checks=checks+1; assert(value,label) end
local function Boot(manifest, forever, language)
    local e=setmetatable({TEST_FOREVER=forever, TEST_MESSAGES={}, TEST_TIMERS={},
        WOW_PROJECT_ID=forever and 18 or 19, WOW_PROJECT_CAMELOT=forever and 18 or nil,
        YiboCoreDB={sentinel="mists"}, YiboCoreForeverDB={sentinel="forever"}}, {__index=_G})
    e._G=e
    local counts={}
    local function Load(path)
        local f=assert(loadfile(path)); setfenv(f,e); f("YiboCore",{})
    end
    Load("_NonRelease/CoreForever/FrameFixture.lua")
    e.TEST_GUID="Player-CoreEntry-1"; e.GetLocale=function() return language or "zhCN" end
    for line in io.lines(root..manifest) do
        line=line:gsub("\r","")
        if line:match("%.lua$") then
            counts[line]=(counts[line] or 0)+1
            Load(root..line:gsub("\\","/"))
        end
    end
    local initializations=0
    if e.YiboCore then
        local original=e.YiboCore.Initialize
        e.YiboCore.Initialize=function(self,...) initializations=initializations+1; return original(self,...) end
    end
    local function Event(name,...)
        for _,f in ipairs(e.TEST_FRAMES) do
            if f.events and f.events[name] and f.scripts.OnEvent then f.scripts.OnEvent(f,name,...) end
        end
    end
    Event("ADDON_LOADED","YiboCore"); Event("ADDON_LOADED","YiboCore"); Event("PLAYER_LOGIN")
    return e,e.YiboCore,initializations,counts
end
for _,target in ipairs({{"YiboCore_Mists.toc",false,"1.12.9"},{"YiboCore_Forever.toc",true,"0.2.0"}}) do
    local e,c,n,counts=Boot(target[1],target[2])
    Check(c:IsInitialized() and c.VERSION==target[3],"target starts unchanged runtime")
    Check(n==1,"repeat addon-loaded notification does not reinitialize")
    for _,count in pairs(counts) do Check(count==1,"runtime file loaded once") end
    Check(not counts["Common\\TocHint.lua"],"target manifest excludes Hint")
    if target[2] then
        Check(e.YiboCoreDB.sentinel=="mists" and not e.YiboCoreDB.characters,"Forever does not touch Mists store")
        Check(c.Database:GetDB()==e.YiboCoreForeverDB,"Forever store identity unchanged")
    else
        Check(e.YiboCoreForeverDB.sentinel=="forever" and not e.YiboCoreForeverDB.characters,"Mists does not touch Forever store")
        Check(c.Database:GetDB()==e.YiboCoreDB,"Mists store identity unchanged")
    end
    Check(#e.TEST_MESSAGES==0,"no callback errors")
end
for _,forever in ipairs({true,false}) do
    local e,c=Boot(forever and "YiboCore_Mists.toc" or "YiboCore_Forever.toc",forever)
    Check(not c:IsInitialized(),"opposite target manifest stops")
    Check(not e.YiboCoreDB.characters and not e.YiboCoreForeverDB.characters,"opposite target does not initialize either store")
end
for _,language in ipairs({"zhCN","zhTW","enUS","deDE"}) do
    local e,c,n=Boot("YiboCore.toc",true,language)
    Check(not c and n==0,"Hint does not expose Core API or initialize")
    Check(not e.YiboCoreDB.characters and not e.YiboCoreForeverDB.characters,"Hint does not touch either store")
    Check(#e.TEST_MESSAGES==1,"Hint emits one localized diagnostic")
end
print("Core TOC candidate passed: "..checks.." checks; client TOC selection remains a live test")
