local Addon, Core = _G.YiboReputation, _G.YiboCore
local Integration={}; Addon.CoreIntegration=Integration
local PAGE_ID="reputation"
local REQUIRED_CORE_API=14
local function HasCoreRequirements()
 return Core and Core.CheckAPIVersion and Core:CheckAPIVersion(REQUIRED_CORE_API)
  and Core.HasCapability and Core:HasCapability("localization",1)
  and Core:HasCapability("pixel-line",1)
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
  and type(Core.AccountView.FitRepeatedColumnWidth)=="function"
  and type(Core.AccountView.GetScrollSurfaceWidth)=="function"
  and type(Core.AccountView.UpdateColumnPager)=="function"
  and type(Core.AccountView.NotifyPageChanged)=="function"
  and type(Core.AccountView.Toggle)=="function"
  and Core.Entry and type(Core.Entry.RegisterBusinessEntry)=="function"
  and Core.UITheme and type(Core.UITheme.CreateInput)=="function"
  and type(Core.UITheme.ApplyPixelBackdrop)=="function" and type(Core.UITheme.CreatePixelBorder)=="function"
  and Core.Characters and type(Core.Characters.FormatName)=="function"
  and type(Core.Characters.Get)=="function" and type(Core.Characters.GetAll)=="function"
  and type(Core.Characters.GetCurrent)=="function"
  and type(Core.Characters.GetAliases)=="function" and type(Core.Characters.ResolveLegacyKey)=="function"
end
function Addon:NotifyChanged() if self.GoalTargets and self.GoalTargets.ref then Core.Contracts:NotifyChanged("YiboReputation", self.GoalTargets.ref, { reason = "reputation-changed" }) end; if Core.AccountView then Core.AccountView:NotifyPageChanged(PAGE_ID) end end
function Integration:Initialize()
 if self.initialized then return true end
 if Addon.CLIENT_SUPPORTED == false then return nil,Addon:T("MISTS.WRONG_CLIENT") end
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
 local page, pageError = Addon:RegisterMatrixPage({
    firstUseTip = { title = Addon:T("PAGE.TIP_TITLE"), lines = { Addon:T("PAGE.TIP_BODY") } },
    characterFilter = {
        defaultExpression = "",
        GetExpression = function() return Addon:GetSettings().matrixLevelExpr or "" end,
        SetExpression = function(expression)
            local valid, normalized, bad = Core.LevelFilter:Validate(expression or "")
            if not valid then return false, bad end
            Addon:GetSettings().matrixLevelExpr = normalized
            Addon:NotifyChanged()
            return true, normalized
        end,
    },
    ShowScopeBar = function() return true end,
    settings = {
        title = Addon:T("PAGE.TITLE"),
        description = Addon:T("PAGE.DESCRIPTION"),
        CreateSettingsPanel = function(parent, context) return Addon:CreateSettingsPanel(parent, context) end,
    },
 })
 if not page then return nil, pageError end
 self.pageRegistered = true
 if Addon.GoalTargets then Addon.GoalTargets:Initialize() end
 self.initialized=true
 Addon.Scanner:Initialize()
 return true
end
