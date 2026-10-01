local function Widget()
    local widget = { width = 600, scripts = {}, checked = false }
    setmetatable(widget, { __index = function(_, key)
        if key:match("^[a-z]") then return nil end
        if key == "GetWidth" then return function(self) return self.width or 600 end end
        if key == "GetChecked" then return function(self) return self.checked end end
        if key == "SetChecked" then return function(self, value) self.checked = value end end
        if key == "SetScript" then return function(self, event, callback)
            self.scripts = self.scripts or {}; self.scripts[event] = callback
        end end
        if key == "SetText" then return function(self, value) self.text = value end end
        if key == "SetState" then return function(self, value) self.state = value end end
        if key == "SetWidth" then return function(self, value) self.width = value end end
        if key == "SetHeight" then return function(self, value) self.height = value end end
        return function() end
    end })
    return widget
end

CreateFrame = function() return Widget() end
StaticPopupDialogs = {}
StaticPopup_Show = function(name, message, _, data)
    _G.lastPopup = { name = name, message = message, data = data }
end
local theme = { Font = { assist = 13 }, Colors = { text = {}, muted = {} } }
function theme:CreateDropdown()
    local dropdown = Widget()
    dropdown.SetOptions = function(self, options) self.options = options end
    dropdown.SetValue = function(self, value) self.value = value end
    dropdown.SetOnValueChanged = function(self, callback) self.onValueChanged = callback end
    return dropdown
end
local shownPage
YiboCore = { UITheme = theme, AccountView = {
    ShowPage = function(_, pageID) shownPage = pageID end,
} }
YiboVault = { db = { settings = { tooltipRealmScope = "current", tooltipEnabled = true },
    byGuild = { shared = { guildName = "Shared", realm = "Realm", tabs = {} },
        later = { guildName = "Zed", realm = "Realm", tabs = {} } } },
    Tooltip = { Invalidate = function() end },
    StoragePage = { OpenGuild = function(_, key) _G.openedGuild = key end },
    SetGuildHidden = function(self, key, hidden) self.db.byGuild[key].hidden = hidden; return true end,
    DeleteGuild = function(self, key) self.db.byGuild[key] = nil; return true end,
    Print = function() end,
}
dofile("YiboVault/AccountPage.lua")
local host = Widget()
local context = {
    createSection = function() return Widget() end,
    createText = function() return Widget() end,
    createCheckbox = function() return Widget() end,
    createButton = function(_, _, _, kind)
        local button = Widget(); button.kind = kind; return button
    end,
}
context.refreshPanel = function() YiboVault.AccountPage:CreateSettingsPanel(host, context) end
local height = YiboVault.AccountPage:CreateSettingsPanel(host, context)
local panel = host.yiboVaultSettings
assert(height == 370 and panel.data.height == 194 and panel.enabled.checked,
    "settings height must fit the visible guild rows")
local narrowHost = Widget()
narrowHost.width = 480
assert(YiboVault.AccountPage:CreateSettingsPanel(narrowHost, context) == 420
    and narrowHost.yiboVaultSettings.guildRows[1].height == 54,
    "a narrow settings area must stack each guild name above its actions")
panel.enabled.scripts.OnClick(panel.enabled)
assert(YiboVault.db.settings.tooltipEnabled == false, "the tooltip switch must persist its value")
panel.guildRows[1].view.scripts.OnClick()
assert(openedGuild == "shared", "a saved guild must open from the cache list")
panel.guildRows[1].toggle.scripts.OnClick()
assert(YiboVault.db.byGuild.shared.hidden, "hiding a guild must persist without deleting its cache")
assert(panel.guildRows[1].delete.kind == "danger", "guild deletion needs a distinct danger action")
panel.guildRows[1].delete.scripts.OnClick()
assert(lastPopup and lastPopup.message:find("Shared%-Realm"), "guild deletion must request confirmation")
assert(YiboVault.db.byGuild.shared, "the cache must remain until confirmation")
StaticPopupDialogs[lastPopup.name].OnAccept(nil, lastPopup.data)
assert(YiboVault.db.byGuild.shared == nil, "confirmation must delete the selected guild cache")
assert(YiboVault.db.byGuild.later, "deleting one row must preserve other guild caches")
assert(shownPage == nil, "settings actions must not unexpectedly navigate away")
print("AccountPageSettingsSpec: OK")
