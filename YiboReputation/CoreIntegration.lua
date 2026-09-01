local Addon, Core = _G.YiboReputation, _G.YiboCore
local Integration={}; Addon.CoreIntegration=Integration
local PAGE_ID="reputation"
local function HasSnapshot(character)
 local snapshot=Core.DataDomains:Get(character.id,"reputation")
 return snapshot~=nil and snapshot.state~="unavailable"
end
local function Eligible(characters)
 local output={}
 for _,character in ipairs(characters or {}) do if HasSnapshot(character) then output[#output+1]=character end end
 return output
end
function Addon:NotifyChanged() if Core.AccountView then Core.AccountView:NotifyPageChanged(PAGE_ID) end end
function Addon:CreatePage(parent) self:CreateMatrixView(parent); self:CreatePreviewViews(parent) end
function Addon:RefreshPage(parent,context)
 parent.matrixToolbar:SetShown(not context.preview);parent.matrixHeader:SetShown(not context.preview);parent.matrixScroll:SetShown(not context.preview)
 if context.preview then
  self:RefreshPreview(parent,context)
 else
  -- The page instance is shared by the main account window and Core's hover
  -- shell. Explicitly hide both preview layouts before rendering the matrix;
  -- otherwise a prior hover tree remains visible underneath the new matrix.
 parent.currentPreviewScroll:Hide()
  parent.currentPreviewHeading:Hide()
  parent.currentPreviewNameHeader:Hide()
  parent.currentPreviewValueHeader:Hide()
  parent.previewModeButton:Hide()
  for _, row in ipairs(parent.monitoredRows or {}) do row:Hide() end
  for _, header in ipairs(parent.monitoredHeaders or {}) do header:Hide() end
  -- The hover preview owns a current-character column outline.  Its frame is
  -- shared with the main page, so hide it explicitly before the matrix draws;
  -- otherwise its partial-height box leaks over the matrix header and rows.
  if parent.monitoredCurrentOutline then
   parent.monitoredCurrentOutline:ClearAllPoints()
   parent.monitoredCurrentOutline:Hide()
  end
  parent.monitoredDetail:Hide()
  self:RefreshMatrixView(parent,context)
 end
end
function Integration:Initialize()
 if self.initialized then return true end
 if not Core or not Core.AccountView then return nil,"YiboCore 不可用。" end
 local compatible=Core:CheckAPIVersion(5);if not compatible then return nil,"需要 YiboCore API v5。" end
 Addon:EnsureDB();Core:RegisterAddon("YiboReputation",{version=Addon.VERSION,requiredAPI=5})
local function GetSurfaceMetrics(context)
 if context and context.preview then return Addon:GetPreviewSurfaceMetrics(context) end
 local inset = Core.UITheme:GetMatrixInsets(false)
 local characters = (context and context.characters) or {}
 local layout = Addon.MatrixColumnLayout or { nameWidth = 200, characterWidth = Core.UITheme.Table.characterColumnWidth }
 -- The preferred width represents the complete account comparison.  Core
 -- clamps it to the screen's safe width; only that hard boundary may cause
 -- the renderer below to paginate characters.
 local matrixWidth = layout.nameWidth + #characters * layout.characterWidth
 local rows = Addon:GetMatrixSurfaceRowCount(characters)
 local scrollbarWidth = rows > 20 and Core.UITheme.Geometry.scrollbarGutter or 0
 return {
  minContentWidth=layout.nameWidth+layout.characterWidth+inset.left+inset.right,
  -- Reserve the shared vertical track only when this capped matrix actually
  -- overflows.  Otherwise the track appears correctly but trims the final
  -- character column by its 14px lane.
  naturalContentWidth=matrixWidth+inset.left+inset.right+scrollbarWidth,
  minContentHeight=inset.top+Core.UITheme.Size.standard+Core.UITheme.Space.sm+Core.UITheme:GetCharacterHeaderHeight(context)+Core.UITheme.Space.xxs+Core.UITheme.Table.rowHeight+inset.bottom,
  naturalContentHeight=inset.top+Core.UITheme.Size.standard+Core.UITheme.Space.sm+Core.UITheme:GetCharacterHeaderHeight(context)+Core.UITheme.Space.xxs+math.max(1,math.min(rows,20))*Core.UITheme.Table.rowHeight+inset.bottom,
  fixedLeftWidth=layout.nameWidth,fixedTopHeight=Core.UITheme.Size.standard+Core.UITheme:GetCharacterHeaderHeight(context),horizontalOverflow="paginate",verticalOverflow="content"
 }
end
local page,err=Core.AccountView:RegisterPage("YiboReputation",{id=PAGE_ID,title="声望总览",icon="Interface\\AddOns\\YiboReputation\\Media\\YiboReputationIcon-v1",order=40,previewEnabled=true,defaultEnabled=true,fields={},scope={mode="realms"},characterFilter={defaultExpression="",GetExpression=function()return Addon:GetSettings().matrixLevelExpr or "" end,SetExpression=function(expression)local valid,normalized,bad=Core.LevelFilter:Validate(expression or "");if not valid then return false,bad end;Addon:GetSettings().matrixLevelExpr=normalized;Addon:NotifyChanged();return true,normalized end},HasCharacterSnapshot=HasSnapshot,GetEligibleCharacters=Eligible,header={characterNameMode="short"},ShowScopeBar=function()return true end,settings={title="声望总览",description="页面、入口、角色范围和排序由 Core 统一管理；声望快照归 YiboCore。",CreateSettingsPanel=function(parent,ctx)return Addon:CreateSettingsPanel(parent,ctx)end},Create=function(parent)Addon:CreatePage(parent)end,Refresh=function(parent,ctx)Addon:RefreshPage(parent,ctx)end,GetSurfaceMetrics=GetSurfaceMetrics})
 if not page then return nil,err end
 local entry,entryErr=Core.Entry:RegisterBusinessEntry("YiboReputation",{id="yrp",brokerName="YiboReputation",pageID=PAGE_ID,text="[Yibo] 声望总览",icon="Interface\\AddOns\\YiboReputation\\Media\\YiboReputationIcon-v1",defaultMode="none"});if not entry then return nil,entryErr end
 Core.Events:Register("DATA_DOMAIN_UPDATED",Addon,function(_,payload)if payload.domainID=="reputation" then Addon._matrixDataRevision=(Addon._matrixDataRevision or 0)+1;Addon._matrixSnapshotCache=nil;Addon._matrixNodeCaches=nil;Addon:NotifyChanged()end end);self.initialized=true;return true
end
