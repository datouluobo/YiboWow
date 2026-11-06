local Boot=dofile('_NonRelease/CoreForever/Harness.lua')
local e,c,fire,flush,load=Boot(false)
e.TEST_GUID='Player-Rep-1';e.IsLoggedIn=function() return true end
e.GetNumFactions=function() return 1 end
e.GetFactionInfo=function() return 'Faction',nil,5,3000,9000,4321,false,false,false,false,true,false,false,1272 end
e.GetFactionInfoByID=function(id) if id==1272 then return e.GetFactionInfo() end end
fire('ADDON_LOADED');fire('PLAYER_LOGIN');flush()
for line in io.lines('YiboReputation/YiboReputation.toc') do
    local path=line:match('^([^#].-%.lua)%s*$')
    if path then load('YiboReputation/'..path:gsub('\\','/'),'YiboReputation') end
end
fire('ADDON_LOADED','YiboReputation');flush()
local a=e.YiboReputation
assert(a.CoreIntegration.initialized)
a:ScanCurrent('test')
a:GetSettings().monitoredFactionIDs={1272}
local identity=c.Characters:GetCurrent({identityOnly=true})
local context={characters={identity},surfaceAvailableWidth=800,scope='all'}
local parent=e.CreateFrame('Frame',nil,e.UIParent);parent:SetSize(800,600)
a:CreateMonitoredPreview(parent);a:RefreshMonitoredPreview(parent,context)
local row=assert(parent.monitoredRows[1]);assert(row.scripts.OnUpdate==nil,'idle preview has no frame callback')
e.GetCursorPosition=function() return row:GetLeft()+200,0 end
row:Fire('OnEnter');assert(type(row.scripts.OnUpdate)=='function')
row:Fire('OnUpdate',.016);row:Fire('OnLeave');assert(not row.scripts.OnUpdate)
row:Fire('OnEnter');row:Hide();assert(not row.scripts.OnUpdate and not row.monitoredTooltipTracking,'hidden preview removes callback')
a:RefreshMonitoredPreview(parent,context);assert(not row.scripts.OnUpdate,'reused row is idle')
local matrix=e.CreateFrame('Frame',nil,e.UIParent);matrix:SetSize(800,600)
a:CreateMatrixView(matrix);a:RefreshMatrixView(matrix,context)
local hovered
for _,r in ipairs(matrix.matrixRows) do
    assert(not r.scripts.OnUpdate,'idle matrix has no row callbacks')
    if r.tooltipNode and r.tooltipNode.kind=='faction' then hovered=r end
end
assert(hovered,'matrix contains a real faction row')
hovered:Fire('OnEnter');assert(type(hovered.scripts.OnUpdate)=='function')
hovered:Fire('OnUpdate',.016);hovered:Fire('OnLeave');assert(not hovered.scripts.OnUpdate)
hovered:Fire('OnEnter');hovered:Hide();assert(not hovered.scripts.OnUpdate and not hovered.tooltipTracking)
assert(a:GetSnapshot(identity.id).data.factions[1272].value==4321,'business snapshot is unchanged')
print('PASS: real reputation renderers attach only hovered callbacks and remove on leave/hide/reuse; snapshot retained')
