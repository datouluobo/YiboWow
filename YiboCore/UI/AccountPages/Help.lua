-- Internal account page for documenting quick operations across Yibo plugins.
local Core = _G.YiboCore
local AccountView = Core.AccountView
local Theme = Core.UITheme
local COLORS = Theme.Colors
local AddText = AccountView._internal.AddText

local function CreateHelp(parent)
    parent.scroll = Theme:CreateScrollFrame(parent)
    parent.scroll:SetPoint("TOPLEFT", 0, 0)
    parent.scroll:SetPoint("BOTTOMRIGHT", 0, 0)

    parent.content = CreateFrame("Frame", nil, parent.scroll)
    parent.scroll:SetScrollChild(parent.content)
    parent.title = AddText(parent.content, "GameFontNormalLarge", Theme.Font.title, COLORS.text)
    parent.title:SetPoint("TOPLEFT", 20, -18)
    parent.title:SetText("快捷操作")

    parent.intro = AddText(parent.content, "GameFontNormalSmall", Theme.Font.assist, COLORS.muted)
    parent.intro:SetPoint("TOPLEFT", parent.title, "BOTTOMLEFT", 0, -9)
    parent.intro:SetText("这里汇总 Yibo 插件中的快捷操作。各插件新增操作后会逐步补充。")

    parent.section = AddText(parent.content, "GameFontNormal", Theme.Font.section, COLORS.accent)
    parent.section:SetPoint("TOPLEFT", parent.intro, "BOTTOMLEFT", 0, -24)
    parent.section:SetText("YiboMail · 发件箱")

    parent.tip = CreateFrame("Frame", nil, parent.content, "BackdropTemplate")
    parent.tip:SetHeight(76)
    parent.tip:SetPoint("TOPLEFT", parent.section, "BOTTOMLEFT", 0, -12)
    parent.tip:SetPoint("RIGHT", parent.content, "RIGHT", -20, 0)
    parent.tip:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    parent.tip:SetBackdropColor(COLORS.panel[1], COLORS.panel[2], COLORS.panel[3], 0.72)
    parent.tip:SetBackdropBorderColor(COLORS.line[1], COLORS.line[2], COLORS.line[3], 0.58)

    parent.tip.title = AddText(parent.tip, "GameFontNormal", Theme.Font.body, COLORS.text)
    parent.tip.title:SetPoint("TOPLEFT", 14, -12)
    parent.tip.title:SetText("Ctrl 点击背包物品")
    parent.tip.description = AddText(parent.tip, "GameFontNormalSmall", Theme.Font.assist, COLORS.muted)
    parent.tip.description:SetPoint("TOPLEFT", parent.tip.title, "BOTTOMLEFT", 0, -7)
    parent.tip.description:SetPoint("RIGHT", -14, 0)
    parent.tip.description:SetText("打开原生发件箱的写信界面后，按住 Ctrl 点击背包物品，可将背包中同种物品一并放入邮件附件。")

    parent.content:SetSize(math.max(1, parent.scroll:GetWidth() or 1), 180)
    parent.scroll:SetContentHeight(180)
    parent.scroll:RefreshScrollbar()
    parent.scroll:SetScript("OnSizeChanged", function(scroll)
        parent.content:SetWidth(math.max(1, scroll:GetWidth() or 1))
        parent.tip:SetPoint("RIGHT", parent.content, "RIGHT", -20, 0)
        scroll:SetContentHeight(180)
        scroll:RefreshScrollbar()
    end)
end

local function RefreshHelp(parent)
    if parent.scroll then parent.scroll:RefreshScrollbar() end
end

AccountView._pages.help = {
    id = "help", title = "帮助", order = 990, internal = true,
    Create = CreateHelp, Refresh = RefreshHelp,
    GetSurfaceMetrics = function()
        return { minContentWidth = 582, naturalContentWidth = 764, minContentHeight = 150, naturalContentHeight = 180, verticalOverflow = "content" }
    end,
}
