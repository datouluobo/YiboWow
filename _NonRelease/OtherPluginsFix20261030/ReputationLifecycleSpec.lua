local Boot=dofile('_NonRelease/CoreForever/Harness.lua')
local e,c,fire,flush,load=Boot(false)
e.TEST_GUID='Player-Rep-1';e.IsLoggedIn=function() return true end
e.GetNumFactions=function() return 1 end
e.GetFactionInfo=function() return 'Faction',nil,5,3000,9000,4321,false,false,false,false,true,false,false,1272 end
e.GetFactionInfoByID=function(id) if id==1272 then return e.GetFactionInfo() end end
fire('ADDON_LOADED');fire('PLAYER_LOGIN');flush()
for line in io.lines('YiboReputation/YiboReputation_Mists.toc') do
    local path=line:match('^([^#].-%.lua)%s*$')
    if path then load('YiboReputation/'..path:gsub('\\','/'),'YiboReputation') end
end
fire('ADDON_LOADED','YiboReputation');flush()
local a=e.YiboReputation
assert(a.CoreIntegration.initialized)
a:ScanCurrent('test')
a:GetSettings().monitoredFactionIDs={1272}
local previousGetFactionInfo = e.GetFactionInfo
e.GetFactionInfo = function() return 'Faction',nil,5,3000,9000,8999,false,false,false,false,true,false,false,1272 end
assert(a:ScanCurrent('standing-boundary'))
a:GetSettings().matrixSearch='1272'
local identity=c.Characters:GetCurrent({identityOnly=true})
local context={preview=true,characters={identity},surfaceAvailableWidth=800,scope='all'}
local parent=e.CreateFrame('Frame',nil,e.UIParent);parent:SetSize(800,600)
a:CreateMatrixView(parent);a:RefreshMatrixView(parent,context)
local row=assert(parent.matrixRows[1]); assert(row.displays[1].text=='5999' and row.displays[1].details[1]==a:T('STANDING.5') and row.progressBars[2].gain:IsShown(),'hover keeps the real nonterminal standing at its boundary');assert(row.scripts.OnUpdate==nil,'idle preview has no frame callback')
e.GetCursorPosition=function() return row:GetLeft()+parent.matrixView.columns[1].width+10,0 end
row:Fire('OnEnter');assert(type(row.scripts.OnUpdate)=='function')
row:Fire('OnUpdate',.016);row:Fire('OnLeave');assert(not row.scripts.OnUpdate)
row:Fire('OnEnter');row:Hide();assert(not row.scripts.OnUpdate and not row.tooltipTracking,'hidden preview removes callback')
a:RefreshMatrixView(parent,context);assert(not row.scripts.OnUpdate,'reused row is idle')
local matrix=e.CreateFrame('Frame',nil,e.UIParent);matrix:SetSize(800,600)
context.preview=false
a:CreateMatrixView(matrix);a:RefreshMatrixView(matrix,context)
local hovered
for _,r in ipairs(matrix.matrixRows) do
    assert(not r.scripts.OnUpdate,'idle matrix has no row callbacks')
    if r.tooltipNode and r.tooltipNode.kind=='faction' then hovered=r end
end
assert(hovered,'matrix contains a real faction row')
assert(hovered.displays[1].text=='5999' and hovered.displays[1].details[1]==a:T('STANDING.5') and hovered.displays[1].delta=='+4678','main keeps the real nonterminal standing at its boundary')
e.GetFactionInfo = function() return 'Faction',nil,8,42000,43000,42998,false,false,false,false,true,false,false,1272 end
assert(a:ScanCurrent('exalted-before-cap'))
a:RefreshMatrixView(matrix,context)
local mainExalted=hovered.displays[1]
context.preview=true
a:RefreshMatrixView(parent,context)
local previewExalted=parent.matrixRows[1].displays[1]
assert(mainExalted.text=='998' and mainExalted.gainColor and mainExalted.fraction==0.998
    and previewExalted.text==mainExalted.text and previewExalted.gainColor==mainExalted.gainColor,
    'main and hover share the Exalted gain color and progress before the cap')
context.preview=false
e.GetFactionInfo = previousGetFactionInfo
assert(a:ScanCurrent('restore-fixture'))
hovered:Fire('OnEnter');assert(type(hovered.scripts.OnUpdate)=='function')
hovered:Fire('OnUpdate',.016);hovered:Fire('OnLeave');assert(not hovered.scripts.OnUpdate)
hovered:Fire('OnEnter');hovered:Hide();assert(not hovered.scripts.OnUpdate and not hovered.tooltipTracking)
assert(a:GetSnapshot(identity.id).data.factions[1272].value==4321,'business snapshot is unchanged')
local roster = {{id=identity.id, name='Rep', realm=identity.realm}}
for i = 2, 13 do roster[i] = {id='Offline-'..i, name='Alt'..i, realm=identity.realm} end
local wide = {characters=roster,surfaceAvailableWidth=760,scope='all'}
matrix:SetSize(760,600)
a:RefreshMatrixView(matrix,wide)
local view = matrix.matrixView
local friendshipSnapshot = c.Defaults:Copy(a:GetSnapshot(identity.id))
local friendship = {rank=6,maxRank=6,reaction=42000,reactionThreshold=42000,reactionName='Best Friend'}
friendshipSnapshot.data.factions[1358] = {factionID=1358,name='Nat Pagle',friendship=friendship}
local friendshipNode = {factionID=1358}
local bestFriend = a.Display:ForCell(a:GetMatrixCell(friendshipSnapshot,friendshipNode,identity),view.fields)
assert(bestFriend.text==a:T('FRIENDSHIP.FALLBACK_6') and bestFriend.fraction==1 and bestFriend.textColor,
    'complete friendship uses the localized Best Friend label and completed palette')
friendship.rank,friendship.reaction,friendship.reactionThreshold,friendship.nextThreshold,friendship.reactionName=2,9000,8400,16800,'Buddy'
local buddy = a.Display:ForCell(a:GetMatrixCell(friendshipSnapshot,friendshipNode,identity),view.fields)
assert(buddy.text=='600' and buddy.details[1]=='Buddy' and not buddy.textColor,
    'incomplete friendship keeps its numerical progress and actual rank in the tooltip')
assert(#view.characters > 4 and #view.characters < #roster,'compact width admits more columns before Core paginates')
assert(view.columns[2].width==view.columns[3].width and matrix.matrixHeaders[2]:GetWidth()==view.columns[2].width,
    'header and rows share one fitted column width')
assert(select(5,matrix.matrixToolbar.refresh:GetPoint(1))==0,'refresh stays on the first row with a regular viewport')
local unavailable = a:GetMatrixCell(a:GetSnapshot(identity.id), {factionID=1168, guildName='Other Guild'}, identity)
local compact = a.Display:ForCell(unavailable, view.fields)
assert(compact.muted and compact.text ~= a:T('STATE.UNAVAILABLE') and compact.details[1] == a:T('STATE.UNAVAILABLE'),
    'an unavailable MoP cell uses a quiet marker and keeps its reason in the tooltip')
local firstRole = view.characters[1].id
matrix.yiboColumnPager.next:Fire('OnClick')
a:RefreshMatrixView(matrix,wide)
assert(matrix.matrixView.characters[1].id ~= firstRole, 'main pager advances to a different role slice')
assert(#matrix.matrixView.rows == #view.rows, 'paging preserves matrix rows')
for index, entry in ipairs(view.rows) do
    assert(matrix.matrixView.rows[index].node.key == entry.node.key, 'paging preserves matrix row order')
end
local hover = {preview=true,characters=roster,surfaceAvailableWidth=900,scope='all'}
local size = c.AccountView._pages.reputation.GetSurfaceMetrics(hover)
assert(size.naturalContentWidth <= 900*0.72 and size.naturalContentWidth >= size.minContentWidth,'hover caps its width before Core pagination')
hover.surfaceAvailableWidth = size.naturalContentWidth
parent:SetSize(size.naturalContentWidth,600)
a:RefreshMatrixView(parent,hover)
assert(#parent.matrixView.characters < #roster,'wide hover uses the same Core column pager')
assert(parent.matrixPreviewFooter:IsShown() and parent.yiboColumnPager.next:IsShown(), 'paged hover reserves a visible footer')
assert(select(2,parent.yiboColumnPager.next:GetPoint(1))==parent.matrixPreviewFooter, 'pager anchors to footer instead of character header')
local bottomInset = c.UITheme:GetMatrixInsets(true).bottom
assert(select(5,parent.matrixScroll:GetPoint(2)) > bottomInset + parent.matrixPreviewFooter:GetHeight(),
    'scroll viewport ends above the footer')
hover.characters = {identity}
a:RefreshMatrixView(parent,hover)
assert(not parent.matrixPreviewFooter:IsShown() and not parent.yiboColumnPager.next:IsShown(), 'single-page hover releases footer space')
assert(select(5,parent.matrixScroll:GetPoint(2)) == bottomInset, 'single-page hover uses the full viewport')
print('PASS: real reputation renderers attach only hovered callbacks and remove on leave/hide/reuse; snapshot retained')
