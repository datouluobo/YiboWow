-- Exercise only the new formal Core entry candidate and its store boundaries.
local root
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

local function Pristine(t,label) Check(t.sentinel==label and next(t,"sentinel")==nil,"wrong target retains whole saved store") end
root="E:/Development/YiboWow/_NonRelease/CoreFinalPackages-20261026/Run-67f2ed2d/Clean-Mists/YiboCore/"
do local e,c,n,counts=Boot("YiboCore.toc",false,"enUS"); Check(c:IsInitialized() and c.VERSION=="1.12.9","packaged target boots"); Check(n==1,"single successful initialization"); Check(c.PackagedAddonVersions~=nil,"packaged catalog loaded"); for _,n in pairs(counts) do Check(n==1,"single file load") end; Check(#e.TEST_MESSAGES==0,"no callback errors"); end
root="E:/Development/YiboWow/_NonRelease/CoreFinalPackages-20261026/Run-67f2ed2d/Clean-Mists/YiboCore/"
do local e,c,n,counts=Boot("YiboCore.toc",false,"zhCN"); Check(c:IsInitialized() and c.VERSION=="1.12.9","packaged target boots"); Check(n==1,"single successful initialization"); Check(c.PackagedAddonVersions~=nil,"packaged catalog loaded"); for _,n in pairs(counts) do Check(n==1,"single file load") end; Check(#e.TEST_MESSAGES==0,"no callback errors"); end
root="E:/Development/YiboWow/_NonRelease/CoreFinalPackages-20261026/Run-67f2ed2d/Clean-Forever/YiboCore/"
do local e,c,n,counts=Boot("YiboCore.toc",true,"enUS"); Check(c:IsInitialized() and c.VERSION=="0.2.0","packaged target boots"); Check(n==1,"single successful initialization"); Check(c.PackagedAddonVersions~=nil,"packaged catalog loaded"); for _,n in pairs(counts) do Check(n==1,"single file load") end; Check(#e.TEST_MESSAGES==0,"no callback errors"); end
root="E:/Development/YiboWow/_NonRelease/CoreFinalPackages-20261026/Run-67f2ed2d/Clean-Forever/YiboCore/"
do local e,c,n,counts=Boot("YiboCore.toc",true,"zhCN"); Check(c:IsInitialized() and c.VERSION=="0.2.0","packaged target boots"); Check(n==1,"single successful initialization"); Check(c.PackagedAddonVersions~=nil,"packaged catalog loaded"); for _,n in pairs(counts) do Check(n==1,"single file load") end; Check(#e.TEST_MESSAGES==0,"no callback errors"); end
root="E:/Development/YiboWow/_NonRelease/CoreFinalPackages-20261026/Run-67f2ed2d/Overlay-Mists-0/YiboCore/"
do local e,c,n,counts=Boot("YiboCore.toc",false,"enUS"); Check(c:IsInitialized() and c.VERSION=="1.12.9","packaged target boots"); Check(n==1,"single successful initialization"); Check(c.PackagedAddonVersions~=nil,"packaged catalog loaded"); for _,n in pairs(counts) do Check(n==1,"single file load") end; Check(#e.TEST_MESSAGES==0,"no callback errors"); end
root="E:/Development/YiboWow/_NonRelease/CoreFinalPackages-20261026/Run-67f2ed2d/Overlay-Mists-0/YiboCore/"
do local e,c,n,counts=Boot("YiboCore.toc",false,"zhCN"); Check(c:IsInitialized() and c.VERSION=="1.12.9","packaged target boots"); Check(n==1,"single successful initialization"); Check(c.PackagedAddonVersions~=nil,"packaged catalog loaded"); for _,n in pairs(counts) do Check(n==1,"single file load") end; Check(#e.TEST_MESSAGES==0,"no callback errors"); end
root="E:/Development/YiboWow/_NonRelease/CoreFinalPackages-20261026/Run-67f2ed2d/Overlay-Mists-1/YiboCore/"
do local e,c,n,counts=Boot("YiboCore.toc",false,"enUS"); Check(c:IsInitialized() and c.VERSION=="1.12.9","packaged target boots"); Check(n==1,"single successful initialization"); Check(c.PackagedAddonVersions~=nil,"packaged catalog loaded"); for _,n in pairs(counts) do Check(n==1,"single file load") end; Check(#e.TEST_MESSAGES==0,"no callback errors"); end
root="E:/Development/YiboWow/_NonRelease/CoreFinalPackages-20261026/Run-67f2ed2d/Overlay-Mists-1/YiboCore/"
do local e,c,n,counts=Boot("YiboCore.toc",false,"zhCN"); Check(c:IsInitialized() and c.VERSION=="1.12.9","packaged target boots"); Check(n==1,"single successful initialization"); Check(c.PackagedAddonVersions~=nil,"packaged catalog loaded"); for _,n in pairs(counts) do Check(n==1,"single file load") end; Check(#e.TEST_MESSAGES==0,"no callback errors"); end
root="E:/Development/YiboWow/_NonRelease/CoreFinalPackages-20261026/Run-67f2ed2d/Cross-Mists-Forever/YiboCore/"
do local e,c,n,counts=Boot("YiboCore.toc",true,"enUS"); Check(c:IsInitialized() and c.VERSION=="0.2.0","packaged target boots"); Check(n==1,"single successful initialization"); Check(c.PackagedAddonVersions~=nil,"packaged catalog loaded"); for _,n in pairs(counts) do Check(n==1,"single file load") end; Check(#e.TEST_MESSAGES==0,"no callback errors"); end
root="E:/Development/YiboWow/_NonRelease/CoreFinalPackages-20261026/Run-67f2ed2d/Cross-Mists-Forever/YiboCore/"
do local e,c,n,counts=Boot("YiboCore.toc",true,"zhCN"); Check(c:IsInitialized() and c.VERSION=="0.2.0","packaged target boots"); Check(n==1,"single successful initialization"); Check(c.PackagedAddonVersions~=nil,"packaged catalog loaded"); for _,n in pairs(counts) do Check(n==1,"single file load") end; Check(#e.TEST_MESSAGES==0,"no callback errors"); end
root="E:/Development/YiboWow/_NonRelease/CoreFinalPackages-20261026/Run-67f2ed2d/Cross-Forever-Mists/YiboCore/"
do local e,c,n,counts=Boot("YiboCore.toc",false,"enUS"); Check(c:IsInitialized() and c.VERSION=="1.12.9","packaged target boots"); Check(n==1,"single successful initialization"); Check(c.PackagedAddonVersions~=nil,"packaged catalog loaded"); for _,n in pairs(counts) do Check(n==1,"single file load") end; Check(#e.TEST_MESSAGES==0,"no callback errors"); end
root="E:/Development/YiboWow/_NonRelease/CoreFinalPackages-20261026/Run-67f2ed2d/Cross-Forever-Mists/YiboCore/"
do local e,c,n,counts=Boot("YiboCore.toc",false,"zhCN"); Check(c:IsInitialized() and c.VERSION=="1.12.9","packaged target boots"); Check(n==1,"single successful initialization"); Check(c.PackagedAddonVersions~=nil,"packaged catalog loaded"); for _,n in pairs(counts) do Check(n==1,"single file load") end; Check(#e.TEST_MESSAGES==0,"no callback errors"); end
root="E:/Development/YiboWow/_NonRelease/CoreFinalPackages-20261026/Run-67f2ed2d/Clean-Mists/YiboCore/"
do local e,c=Boot("YiboCore.toc",true,"enUS"); Check(not c:IsInitialized(),"wrong-client install stops"); Pristine(e.YiboCoreDB,"mists"); Pristine(e.YiboCoreForeverDB,"forever"); end
root="E:/Development/YiboWow/_NonRelease/CoreFinalPackages-20261026/Run-67f2ed2d/Clean-Forever/YiboCore/"
do local e,c=Boot("YiboCore.toc",false,"enUS"); Check(not c:IsInitialized(),"wrong-client install stops"); Pristine(e.YiboCoreDB,"mists"); Pristine(e.YiboCoreForeverDB,"forever"); end
root="E:/Development/YiboWow/_NonRelease/CoreFinalPackages-20261026/Run-67f2ed2d/Cross-Mists-Forever/YiboCore/"
do local e,c=Boot("YiboCore.toc",false,"enUS"); Check(not c:IsInitialized(),"wrong-client install stops"); Pristine(e.YiboCoreDB,"mists"); Pristine(e.YiboCoreForeverDB,"forever"); end
root="E:/Development/YiboWow/_NonRelease/CoreFinalPackages-20261026/Run-67f2ed2d/Cross-Forever-Mists/YiboCore/"
do local e,c=Boot("YiboCore.toc",true,"enUS"); Check(not c:IsInitialized(),"wrong-client install stops"); Pristine(e.YiboCoreDB,"mists"); Pristine(e.YiboCoreForeverDB,"forever"); end
print("Actual package simulations passed: "..checks.." checks")
