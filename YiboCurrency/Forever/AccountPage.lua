local Addon, Core = _G.YiboCurrency, _G.YiboCore or {}
local Page, Theme = {}, Core.UITheme; Addon.AccountPage = Page
function Page:Fields() return { { id = "money", title = Addon:T("FOREVER.BALANCE"), defaultVisible = true } } end
function Page:Status()
    local id = Core.Characters:GetCurrentID()
    local _, state = Addon.Store:Get(id)
    local keys = { known = "FOREVER.KNOWN", stale = "FOREVER.STALE", error = "FOREVER.ERROR", unknown = "FOREVER.UNKNOWN" }
    return Addon:T(keys[state] or "FOREVER.UNKNOWN")
end
function Page:Format(copper)
    return Addon:T("FOREVER.AMOUNT", string.format("%.0f", math.floor(copper / 10000)),
        string.format("%.0f", math.floor(copper / 100) % 100), string.format("%.0f", copper % 100))
end
local function FormatCoinIcons(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor(copper / 100) % 100
    return string.format("%.0f |TInterface\\MoneyFrame\\UI-GoldIcon:14:14|t    %02d |TInterface\\MoneyFrame\\UI-SilverIcon:14:14|t    %02d |TInterface\\MoneyFrame\\UI-CopperIcon:14:14|t",
        gold, silver, copper % 100)
end
function Page:Create(parent)
    parent.heading = Theme:CreateText(parent, Theme.Font.section, Theme.Colors.text)
    parent.heading:SetPoint("TOPLEFT", 12, -12); parent.heading:SetPoint("RIGHT", -130, 0); parent.heading:SetHeight(30)
    parent.refresh = Theme:CreateButton(parent, 100, Addon:T("FOREVER.REFRESH"))
    parent.refresh:SetPoint("TOPRIGHT", -12, -10)
    parent.refresh:SetScript("OnClick", function() Addon.Scanner:Scan(true) end)
    parent.status = Theme:CreateText(parent, Theme.Font.assist, Theme.Colors.muted)
    parent.status:SetPoint("TOPLEFT", 12, -52); parent.status:SetPoint("RIGHT", -12, 0); parent.status:SetHeight(36)
    parent.balanceTitle = Theme:CreateText(parent, Theme.Font.assist, Theme.Colors.muted)
    parent.balanceTitle:SetPoint("TOPLEFT", 12, -100); parent.balanceTitle:SetPoint("RIGHT", -12, 0); parent.balanceTitle:SetHeight(26)
    parent.balance = Theme:CreateText(parent, Theme.Font.section, Theme.Colors.text)
    parent.balance:SetPoint("TOPLEFT", 12, -132); parent.balance:SetPoint("RIGHT", -12, 0); parent.balance:SetHeight(32)
end
function Page:Refresh(parent, context)
    local id = Core.Characters:GetCurrentID()
    local character = context.characters and context.characters[1]
    if character and character.id ~= id then character = nil end
    local snapshot = character and Addon.Store:Get(id)
    parent.heading:SetText(character and Core.Characters:FormatName(character, { realmMode = "full" }) or Addon:T("FOREVER.CURRENT"))
    parent.status:SetText(self:Status())
    parent.refresh:SetShown(not context.preview)
    parent.refresh:SetState(Addon.Scanner.inWorld and id and "default" or "disabled")
    local show = false
    for _, field in ipairs(context.fields or self:Fields()) do if field.id == "money" then show = true end end
    parent.balanceTitle:SetText(Addon:T("FOREVER.BALANCE")); parent.balanceTitle:SetShown(show)
    local balance = Addon:T("FOREVER.NO_BALANCE")
    if snapshot then
        balance = context.preview and self:Format(snapshot.moneyCopper) or FormatCoinIcons(snapshot.moneyCopper)
    end
    parent.balance:SetText(balance); parent.balance:SetShown(show)
    parent.renderedSnapshot = snapshot
end
function Page:Register()
    local ok, err = Core.AccountView:RegisterPage(Addon.NAME, { id = Addon.PAGE_ID,
        title = Addon:T("FOREVER.TITLE"), fields = self:Fields(), defaultEnabled = true, previewEnabled = true,
        GetPreviewFields = function() return Core.Defaults:Copy(Addon.Store.db.settings.previewColumns) end,
        SetPreviewFieldVisible = function(id, visible)
            if id ~= "money" then return false end
            Addon.Store.db.settings.previewColumns.money = visible == true; Addon:NotifyChanged(); return true
        end,
        HasCharacterSnapshot = function(character)
            return character.id == Core.Characters:GetCurrentID() and Addon.Store.db.characters[character.id] ~= nil
        end,
        GetEligibleCharacters = function(characters)
            local result = {}
            for _, character in ipairs(characters or {}) do
                if character.id == Core.Characters:GetCurrentID() and Addon.Store.db.characters[character.id] then result[#result + 1] = character end
            end
            return result
        end,
        GetSurfaceMetrics = function() return { minContentWidth = 420, naturalContentWidth = 640,
            minContentHeight = 180, naturalContentHeight = 220 } end,
        Create = function(parent) Page:Create(parent) end,
        Refresh = function(parent, context) Page:Refresh(parent, context) end })
    if not ok then return nil, err end
    return Core.Entry:RegisterBusinessEntry(Addon.NAME, { id = "ycu", brokerName = "YiboCurrency", pageID = Addon.PAGE_ID,
        text = Addon:T("FOREVER.TITLE"), icon = "Interface\\AddOns\\YiboCurrency\\Media\\YiboCurrencyIcon",
        defaultChannels = { minimap = false, broker = false, builtinBar = false } })
end
