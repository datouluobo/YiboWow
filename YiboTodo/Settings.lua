local Addon = _G.YiboTodo
local Settings = {}
Addon.Settings = Settings

function Settings:GetMode(kind, id, fallback)
    local overrides = Addon.db.settings.modeOverrides[kind] or {}
    return overrides[id] or fallback or "required"
end

function Settings:SetMode(kind, id, mode)
    local overrides = Addon.db.settings.modeOverrides[kind]
    if mode == nil then overrides[id] = nil else overrides[id] = mode end
    Addon:NotifyChanged()
end

function Settings:CreatePanel(parent, context)
    local panel = parent.todoSettingsPanel
    if not panel then
        panel = CreateFrame("Frame", nil, parent); parent.todoSettingsPanel = panel
        panel:SetPoint("TOPLEFT"); panel:SetPoint("TOPRIGHT"); panel.title = context.createText(panel, 12, _G.YiboCore.UITheme.Colors.text, "LEFT")
        panel.title:SetPoint("TOPLEFT", 12, -12); panel.body = context.createText(panel, 11, _G.YiboCore.UITheme.Colors.muted, "LEFT"); panel.body:SetPoint("TOPLEFT", 12, -40); panel.body:SetPoint("TOPRIGHT", -12, -40)
    end
    panel.title:SetText("业务设置")
    panel.body:SetText("打开自己的商业技能面板后，插件会自动读取已支持的制造冷却。链接、他人和公会专业窗口始终不会写入当前角色。")
    panel:SetHeight(92); return 92
end
