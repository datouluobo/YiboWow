-- Isolated actual hover renderer check; does not depend on other addons' tests.
local reads, draws, cursor, invalid = 0, 0, 160, false
YiboCore = { UITheme={Colors={text={1,1,1}}} }
YiboReputation = {
    GetSnapshot=function() reads=reads+1; error("hover reread its snapshot") end,
    FormatState=function() return invalid and "error" or nil end,
    GetFactionData=function(_, snapshot) return snapshot end,
    FormatCompact=function() return "1K" end,
    FormatReputation=function(_, data) return data.detail end,
}
dofile("YiboReputation/MonitoredPreview.lua")
local showTooltip
for i=1,30 do
    local name,value=debug.getupvalue(YiboReputation.RefreshMonitoredPreview,i)
    if name=="ShowMonitoredTooltip" then showTooltip=value;break end
end
assert(showTooltip)
GetCursorPosition=function() return cursor end
GameTooltip={shown=false,Hide=function(self) self.shown=false end,IsShown=function(self) return self.shown end,
    SetOwner=function() end,ClearLines=function() draws=draws+1 end,AddLine=function() end,
    Show=function(self) self.shown=true end}
local row={GetLeft=function() return 0 end,monitoredTooltip={nameWidth=150,cellWidth=80,factionID=1272,
    characters={{id="A"},{id="B"}},snapshots={A={detail="1000/3000"},B={detail="2000/3000"}}}}
for i=1,100 do showTooltip(row) end
assert(draws==1 and reads==0,"stationary tooltip rebuild")
cursor=240;showTooltip(row);assert(draws==2 and reads==0,"column switch")
row.monitoredTooltipColumn=nil;showTooltip(row);assert(draws==3,"rerender")
invalid=true;row.monitoredTooltipColumn=nil;showTooltip(row);assert(not GameTooltip.shown,"error data tooltip")
invalid=false;cursor=10;showTooltip(row);assert(not GameTooltip.shown,"outside data columns")
print("PASS: stationary hover, column switch, rerender and error-state disclosure; zero snapshot rereads")
