local Addon = _G.YiboVault

function Addon:CheckCoreRequirements()
    local core = _G.YiboCore
    if not (core and type(core.CheckAPIVersion) == "function" and core:CheckAPIVersion(self.REQUIRED_CORE_API)
        and type(core.HasCapability) == "function" and core:HasCapability("localization", 1)
        and type(core.IsInitialized) == "function" and core:IsInitialized()
        and core.Locale and type(core.Locale.Get) == "function"
        and type(core.RegisterAddon) == "function" and core.Contracts
        and type(core.Contracts.Register) == "function" and type(core.Contracts.NotifyChanged) == "function"
        and core.AccountView and type(core.AccountView.RegisterPage) == "function"
        and type(core.AccountView.GetRegisteredPages) == "function"
        and type(core.AccountView.BuildContext) == "function"
        and type(core.AccountView.GetEffectiveCharacterSort) == "function"
        and type(core.AccountView.GetCustomCharacterOrder) == "function"
        and type(core.AccountView.NotifyPageChanged) == "function"
        and type(core.AccountView.ShowPage) == "function" and type(core.AccountView.Toggle) == "function"
        and core.Entry and type(core.Entry.RegisterBusinessEntry) == "function"
        and core:HasCapability("business-services", 1)
        and core:HasCapability("character-name-format", 1)
        and core:HasCapability("basic-input", 1)
        and core:HasCapability("item-resolver", 1)
        and core:HasCapability("character-identity", 1)
        and core:HasCapability("account-entry", 2)
        and core.Characters and type(core.Characters.GetCurrent) == "function"
        and type(core.Characters.GetCurrentID) == "function"
        and type(core.Characters.GetAllCached) == "function"
        and type(core.Characters.GetAll) == "function" and type(core.Characters.Get) == "function"
        and type(core.Characters.FormatName) == "function"
        and core.CharacterSort and type(core.CharacterSort.Sort) == "function"
        and core.UITheme and type(core.UITheme.CreateInput) == "function"
        and core.ItemResolver and type(core.ItemResolver.Parse) == "function"
        and type(core.ItemResolver.GetInfo) == "function"
        and type(core.ItemResolver.Request) == "function") then
        if core and core.Locale and type(core.Locale.Get) == "function" then
            Addon:PrintBootstrap(Addon:T("BOOT.CORE_REQUIRED"))
        else
            Addon:PrintBootstrap("Requires a matching YiboCore build with API 13 and localization:1. Please upgrade Core.")
        end
        return nil
    end
    return core
end

function Addon:RegisterWithCore()
    local core = self:CheckCoreRequirements()
    if not core then return false end
    self.Core = core
    local registered, registerError = core:RegisterAddon(self.NAME, { version = self.VERSION, requiredAPI = self.REQUIRED_CORE_API })
    if not registered then self:Print(registerError or self:T("ERROR.CORE_REGISTER")); return false end
    if core.CharacterCleanup and type(core.CharacterCleanup.RegisterOwner) == "function" then
        local cleanup, cleanupError = core.CharacterCleanup:RegisterOwner(self.NAME, {
            Inspect = function(character) return Addon:InspectCharacter(character) end,
            Delete = function(character) return Addon:DeleteCharacter(character) end,
        })
        if not cleanup then self:Print(cleanupError or self:T("ERROR.CLEANUP_REGISTER")); return false end
    end
    local page, pageError = self.AccountPage:Register()
    if not page then self:Print(pageError or self:T("ERROR.PAGE_REGISTER")); return false end
    if self.GoalTargets then self.GoalTargets:Initialize() end
    local service, serviceError = self.Items:RegisterService()
    if not service then self:Print(serviceError); return false end
    return true
end
