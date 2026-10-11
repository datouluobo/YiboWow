local Core = _G.YiboCore

local SettingsRegistry = {}
Core.SettingsRegistry = SettingsRegistry
SettingsRegistry._panels = SettingsRegistry._panels or {}

local function CopyDefinition(definition)
    return {
        id = definition.id,
        title = definition.title,
        description = definition.description,
        icon = definition.icon,
        CreateSettingsPanel = definition.CreateSettingsPanel,
    }
end

function SettingsRegistry:Register(addonName, definition)
    if not (Core.Registry and Core.Registry:Get(addonName)) then return nil, Core:Text("CORE.SETTINGS_PANEL_S_ADDON_IS_NOT_REGISTERED") end
    if type(definition) ~= "table" or type(definition.id) ~= "string" or definition.id == "" then return nil, Core:Text("CORE.SETTINGS_PANELS_REQUIRE_ID") end
    if type(definition.title) ~= "string" or definition.title == "" then return nil, Core:Text("CORE.SETTINGS_PANELS_REQUIRE_TITLE") end
    if type(definition.CreateSettingsPanel) ~= "function" then return nil, Core:Text("CORE.SETTINGS_PANELS_REQUIRE_CREATESETTINGSPANEL") end
    if definition.description ~= nil and type(definition.description) ~= "string" then return nil, Core:Text("CORE.SETTINGS_PANEL_DESCRIPTION_MUST_BE_A_STRING") end
    if definition.icon ~= nil and type(definition.icon) ~= "string" then return nil, Core:Text("CORE.SETTINGS_PANEL_ICON_MUST_BE_A_STRING") end
    local existing = self._panels[definition.id]
    if existing then
        if existing.addonName == addonName then return existing end
        return nil, Core:Text("CORE.SETTINGS_PANEL_ID_IS_ALREADY_OWNED_BY") .. tostring(existing.addonName) .. Core:Text("CORE.PUNCTUATION_120")
    end
    local claimed, errorMessage = Core:ClaimResource("settings", definition.id, addonName)
    if not claimed then return nil, errorMessage end
    local panel = CopyDefinition(definition)
    panel.addonName = addonName
    self._panels[panel.id] = panel
    return panel
end

function SettingsRegistry:Unregister(id, addonName)
    local panel = self._panels[id]
    if not panel then return false end
    if addonName and panel.addonName ~= addonName then return false, Core:Text("CORE.SETTINGS_PANEL_DOES_NOT_BELONG_TO_THIS") end
    self._panels[id] = nil
    Core.Registry:ReleaseResource("settings", id, addonName)
    return true
end

function SettingsRegistry:GetAll()
    local panels = {}
    for _, panel in pairs(self._panels) do panels[#panels + 1] = panel end
    table.sort(panels, function(left, right)
        if left.addonName == right.addonName then return left.id < right.id end
        return left.addonName < right.addonName
    end)
    return panels
end

function Core:RegisterSettingsPanel(addonName, definition)
    return self.SettingsRegistry:Register(addonName, definition)
end

function Core:UnregisterSettingsPanel(id, addonName)
    return self.SettingsRegistry:Unregister(id, addonName)
end

function Core:GetRegisteredSettingsPanels()
    return self.SettingsRegistry:GetAll()
end
