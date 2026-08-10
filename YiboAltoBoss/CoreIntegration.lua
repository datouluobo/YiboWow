local Core = _G.YiboCore
local YAB = _G.YAB

-- 2.0 只接管生命周期、账号入口和设置归属。原有网格窗口仍是过渡期
-- 的业务呈现层；2.1 再将其渲染器拆入 Core 页面。
local Integration = {}
YAB.CoreIntegration = Integration

local PAGE_ID = "alto-boss"

local function AddText(parent, template, color)
    local text = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    if color then
        text:SetTextColor(color[1], color[2], color[3])
    end
    return text
end

local function CreateButton(parent, label)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(152, 25)
    button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    button:SetBackdropColor(0.16, 0.16, 0.18, 0.98)
    button:SetBackdropBorderColor(0.70, 0.50, 0.16, 0.92)
    button.label = AddText(button, "GameFontNormalSmall", { 0.95, 0.95, 0.95 })
    button.label:SetPoint("CENTER")
    button.label:SetText(label)
    button:SetScript("OnEnter", function(self) self:SetBackdropColor(0.28, 0.16, 0.06, 0.98) end)
    button:SetScript("OnLeave", function(self) self:SetBackdropColor(0.16, 0.16, 0.18, 0.98) end)
    return button
end

local function ImportKnownCharacters()
    if not (Core and Core.Characters and Core.Characters.ImportLegacyCharacter) then
        return
    end
    for legacyKey, info in pairs(YiboAltoBossDB.knownChars or {}) do
        local name = info.name or legacyKey:match("^(.-)-") or legacyKey
        local realm = info.realm or legacyKey:match("-(.+)$") or "Unknown"
        Core.Characters:ImportLegacyCharacter("YiboAltoBoss", legacyKey, {
            name = name,
            realm = realm,
            class = info.class,
            level = info.level,
            lastSeenAt = info.lastSeenAt,
            seenOrder = info.seenOrder,
        })
    end
end

local function CreatePage(parent)
    parent.heading = AddText(parent, "GameFontNormalLarge", { 1, 0.86, 0.28 })
    parent.heading:SetPoint("TOPLEFT", 20, -18)
    parent.heading:SetText("Boss 击杀与位面观察")

    parent.summary = AddText(parent, "GameFontNormal", { 0.90, 0.96, 0.97 })
    parent.summary:SetPoint("TOPLEFT", 20, -56)
    parent.summary:SetPoint("TOPRIGHT", -20, -56)

    parent.notice = AddText(parent, "GameFontNormalSmall", { 0.53, 0.70, 0.73 })
    parent.notice:SetPoint("TOPLEFT", 20, -92)
    parent.notice:SetPoint("TOPRIGHT", -20, -92)
    parent.notice:SetWordWrap(true)
    parent.notice:SetText("AltoBoss 2.0 已接入 Core 的账号入口、角色目录和设置导航。完整 Boss 网格暂继续使用既有业务窗口；该网格将在 2.1 迁入此页面。")

    parent.openLegacy = CreateButton(parent, "打开 Boss 总览")
    parent.openLegacy:SetPoint("TOPLEFT", 20, -154)
    parent.openLegacy:SetScript("OnClick", function()
        if YAB.ToggleCurrentServerView then
            YAB.ToggleCurrentServerView()
        end
    end)

    parent.hint = AddText(parent, "GameFontNormalSmall", { 0.53, 0.70, 0.73 })
    parent.hint:SetPoint("TOPLEFT", parent.openLegacy, "BOTTOMLEFT", 0, -12)
    parent.hint:SetText("插件专属配置请在 Core 设置中的“YiboAltoBoss”项打开。")
end

local function RefreshPage(parent)
    ImportKnownCharacters()
    local killed, total = YAB.GetBossSummary("all")
    local activeKills, tracked = YAB.GetBossPhaseSummary("all")
    local characters = #YAB.GetCharacterKeys("all")
    parent.summary:SetText(string.format("已记录角色 %d 名 · Boss 击杀 %d/%d · 位面观测 %d（击杀计时 %d）", characters, killed, total, tracked, activeKills))
end

local function GetSummary()
    local killed, total = YAB.GetBossSummary("all")
    return string.format("Boss 击杀 %d/%d", killed, total)
end

function Integration:Initialize()
    if self.initialized then
        return true
    end
    if not (Core and Core.CheckAPIVersion and Core.AccountView) then
        return nil, "YiboCore 不可用。"
    end
    local compatible = Core:CheckAPIVersion(2)
    if not compatible then
        return nil, "需要 YiboCore API v2。"
    end

    Core:RegisterAddon("YiboAltoBoss", { version = "2.0.0", requiredAPI = 2 })
    ImportKnownCharacters()
    local page, errorMessage = Core.AccountView:RegisterPage("YiboAltoBoss", {
        id = PAGE_ID,
        title = "YiboAltoBoss",
        order = 30,
        defaultEnabled = true,
        settings = {
            title = "YiboAltoBoss",
            description = "Boss 击杀、位面观测、刷新样本和自定义目标由 AltoBoss 自行保存。",
            openLabel = "打开 AltoBoss 业务设置",
            OpenAddonSettings = function()
                if YAB.ToggleSettingsWindow then
                    YAB.ToggleSettingsWindow()
                end
            end,
        },
        Create = CreatePage,
        Refresh = RefreshPage,
        GetSummary = GetSummary,
    })
    if not page and errorMessage then
        return nil, errorMessage
    end
    self.initialized = true
    return true
end

function YAB.NotifyCorePageChanged()
    if Core and Core.AccountView then
        Core.AccountView:NotifyPageChanged(PAGE_ID)
    end
end
