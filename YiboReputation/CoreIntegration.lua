local Addon, Core = _G.YiboReputation, _G.YiboCore
local Integration={}; Addon.CoreIntegration=Integration
local PAGE_ID="reputation"
local REQUIRED_CORE_API=13
local function HasCoreRequirements()
 return Core and Core.CheckAPIVersion and Core:CheckAPIVersion(REQUIRED_CORE_API)
  and Core.HasCapability and Core:HasCapability("localization",1)
  and Core:HasCapability("account-view",2)
  and Core:HasCapability("account-surface-budget",2)
  and Core:HasCapability("data-domains",1)
  and Core:HasCapability("events",1)
  and Core:HasCapability("basic-input",1)
  and Core:HasCapability("character-name-format",1)
  and Core:HasCapability("character-identity",1)
  and Core:HasCapability("character-cleanup",1)
  and Core.Locale and type(Core.Locale.Get)=="function"
  and type(Core.IsInitialized)=="function"
  and type(Core.GetVersion)=="function"
  and type(Core.RegisterAddon)=="function"
  and Core.Events and type(Core.Events.Register)=="function"
  and type(Core.Events.Unregister)=="function" and type(Core.Events.FireIsolated)=="function"
  and Core.DataDomains and type(Core.DataDomains.Get)=="function"
  and type(Core.DataDomains.GetDefinitions)=="function"
  and Core.CharacterCleanup and type(Core.CharacterCleanup.RegisterOwner)=="function"
  and type(Core.CharacterCleanup.IsLegacyImportBlocked)=="function"
  and Core.Defaults and type(Core.Defaults.Copy)=="function"
  and C_Timer and type(C_Timer.After)=="function"
  and Core.LevelFilter and type(Core.LevelFilter.Validate)=="function"
  and Core.AccountView and type(Core.AccountView.RegisterPage)=="function"
  and type(Core.AccountView.GetColumnPage)=="function"
  and type(Core.AccountView.GetScrollSurfaceWidth)=="function"
  and type(Core.AccountView.UpdateColumnPager)=="function"
  and type(Core.AccountView.NotifyPageChanged)=="function"
  and Core.Entry and type(Core.Entry.RegisterBusinessEntry)=="function"
  and Core.UITheme and type(Core.UITheme.CreateInput)=="function"
  and Core.Characters and type(Core.Characters.FormatName)=="function"
  and type(Core.Characters.Get)=="function" and type(Core.Characters.GetAll)=="function"
  and type(Core.Characters.GetCurrent)=="function"
  and type(Core.Characters.GetAliases)=="function" and type(Core.Characters.ResolveLegacyKey)=="function"
end
local function HasSnapshot(character)
 local snapshot=Addon:GetSnapshot(character.id)
 return snapshot~=nil and snapshot.state~="unavailable" and snapshot.data
  and type(snapshot.data.factions)=="table" and next(snapshot.data.factions)~=nil
end
local function Eligible(characters)
 local output={}
 for _,character in ipairs(characters or {}) do if HasSnapshot(character) then output[#output+1]=character end end
 return output
end
function Addon:NotifyChanged() if self.GoalTargets and self.GoalTargets.ref then Core.Contracts:NotifyChanged("YiboReputation", self.GoalTargets.ref, { reason = "reputation-changed" }) end; if Core.AccountView then Core.AccountView:NotifyPageChanged(PAGE_ID) end end
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
 if Addon.CLIENT_SUPPORTED == false then return nil,Addon:T("FOREVER.WRONG_MANIFEST") end
 if not HasCoreRequirements() then return nil,Addon:T("ERROR.CORE_REQUIRED") end
 if not Core:IsInitialized() then return nil,Addon:T("ERROR.CORE_NOT_READY") end
 local handedOff, handoffError=Addon.Migration:CheckCoreHandoff()
 if not handedOff then return nil,handoffError end
 Addon:EnsureDB()
 local registered, registerError=Core:RegisterAddon("YiboReputation",{version=Addon.VERSION,requiredAPI=REQUIRED_CORE_API})
 if not registered then return nil,registerError end
 local stored, storeError=Addon.Store:Initialize()
 if not stored then return nil,storeError end
 local lifecycle, lifecycleError=Addon.Store:RegisterLifecycle()
 if not lifecycle then return nil,lifecycleError end
 Addon.Store:ReconcileLegacyIDs()
 Addon:InitializeFactionRegistry()
 local imported, importError=Addon:ImportLegacySnapshots()
 if imported==nil then return nil,importError end
local function GetSurfaceMetrics(context)
 if context and context.preview then return Addon:GetPreviewSurfaceMetrics(context) end
 local inset = Core.UITheme:GetMatrixInsets(false)
 local characters = (context and context.characters) or {}
 local layout = Addon.MatrixColumnLayout or { nameWidth = 200, characterWidth = Core.UITheme:GetCharacterMatrixColumnWidth(context) }
 local characterWidth = type(Addon.GetMatrixCharacterColumnWidth) == "function"
  and Addon:GetMatrixCharacterColumnWidth(context)
  or layout.characterWidth
 characterWidth = math.max(1, tonumber(characterWidth) or Core.UITheme:GetCharacterMatrixColumnWidth(context))
 -- The preferred width represents the complete account comparison.  Core
 -- clamps it to the screen's safe width; only that hard boundary may cause
 -- the renderer below to paginate characters.
 local matrixWidth = layout.nameWidth + #characters * characterWidth
 -- Row discovery consults every snapshot and may be temporarily unavailable
 -- while Core is rebuilding its character cache.  It must never make this
 -- page fall back to Core's 942px default width: that fallback is what made
 -- a single-realm matrix visibly wider than the all-realm matrix.
 local rows = 21
 local rowsOK, measuredRows = xpcall(function()
  return Addon:GetMatrixSurfaceRowCount(characters)
 end, function() return nil end)
 if rowsOK and type(measuredRows) == "number" then rows = math.max(0, measuredRows) end
 local scrollFixedHeight=inset.top+Core.UITheme.Size.compact+Core.UITheme.Space.xs+Core.UITheme:GetCharacterHeaderHeight(context)+inset.bottom
 return {
  minContentWidth=layout.nameWidth+characterWidth+inset.left+inset.right,
  naturalContentWidth=matrixWidth+inset.left+inset.right,
  scrollContentHeight=rows*Core.UITheme.Table.rowHeight,scrollFixedHeight=scrollFixedHeight,
  minContentHeight=scrollFixedHeight+Core.UITheme.Table.rowHeight,
  naturalContentHeight=scrollFixedHeight+math.max(1,math.min(rows,20))*Core.UITheme.Table.rowHeight,
  fixedLeftWidth=layout.nameWidth,fixedTopHeight=Core.UITheme.Size.standard+Core.UITheme:GetCharacterHeaderHeight(context),horizontalOverflow="paginate",verticalOverflow="content"
 }
end
local page,err=Core.AccountView:RegisterPage("YiboReputation",{id=PAGE_ID,title=Addon:T("PAGE.TITLE"),icon="Interface\\AddOns\\YiboReputation\\Media\\YiboReputationIcon",order=40,previewEnabled=true,defaultEnabled=true,firstUseTip={title=Addon:T("PAGE.TIP_TITLE"),lines={Addon:T("PAGE.TIP_BODY")}},fields={},scope={mode="realms"},characterFilter={defaultExpression="",GetExpression=function()return Addon:GetSettings().matrixLevelExpr or "" end,SetExpression=function(expression)local valid,normalized,bad=Core.LevelFilter:Validate(expression or "");if not valid then return false,bad end;Addon:GetSettings().matrixLevelExpr=normalized;Addon:NotifyChanged();return true,normalized end},HasCharacterSnapshot=HasSnapshot,GetEligibleCharacters=Eligible,header={characterNameMode="short"},ShowScopeBar=function()return true end,settings={title=Addon:T("PAGE.TITLE"),description=Addon:T("PAGE.DESCRIPTION"),CreateSettingsPanel=function(parent,ctx)return Addon:CreateSettingsPanel(parent,ctx)end},Create=function(parent)Addon:CreatePage(parent)end,Refresh=function(parent,ctx)Addon:RefreshPage(parent,ctx)end,GetSurfaceMetrics=GetSurfaceMetrics})
 if not page then return nil,Addon:T("ERROR.PAGE_REGISTER",tostring(err)) end
 self.pageRegistered=true
 local entry,entryErr=Core.Entry:RegisterBusinessEntry("YiboReputation",{id="yrp",brokerName="YiboReputation",pageID=PAGE_ID,text=Addon:T("PAGE.ENTRY"),icon="Interface\\AddOns\\YiboReputation\\Media\\YiboReputationIcon",defaultMode="none"});if not entry then return nil,Addon:T("ERROR.ENTRY_REGISTER",tostring(entryErr)) end
 if Addon.GoalTargets then Addon.GoalTargets:Initialize() end
 self.initialized=true
 Addon.Scanner:Initialize()
 return true
end
