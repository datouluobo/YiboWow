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
    if not (Core.Registry and Core.Registry:Get(addonName)) then return nil, "设置面板所属插件尚未注册。" end
    if type(definition) ~= "table" or type(definition.id) ~= "string" or definition.id == "" then return nil, "设置面板必须提供 id。" end
    if type(definition.title) ~= "string" or definition.title == "" then return nil, "设置面板必须提供 title。" end
    if type(definition.CreateSettingsPanel) ~= "function" then return nil, "设置面板必须提供 CreateSettingsPanel。" end
    if definition.description ~= nil and type(definition.description) ~= "string" then return nil, "设置面板 description 必须是 string。" end
    if definition.icon ~= nil and type(definition.icon) ~= "string" then return nil, "设置面板 icon 必须是 string。" end
    local existing = self._panels[definition.id]
    if existing then
        if existing.addonName == addonName then return existing end
        return nil, "设置面板 ID 已被插件 " .. tostring(existing.addonName) .. " 占用。"
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
    if addonName and panel.addonName ~= addonName then return false, "设置面板不属于此插件。" end
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
