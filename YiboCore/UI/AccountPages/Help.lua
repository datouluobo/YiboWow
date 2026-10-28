-- Internal account page for documenting quick operations across Yibo plugins.
local Core = _G.YiboCore
local AccountView = Core.AccountView
local Theme = Core.UITheme
local COLORS = Theme.Colors
local AddText = AccountView._internal.AddText

local function HelpRows(kind, coreTitle, coreBody)
    local rows = { { Core:Text(coreTitle), Core:Text(coreBody), addonName = Core.NAME } }
    local target = Core._private and Core._private.target
    local policies = target and target.addons or {}
    local names = {}
    for name in pairs(policies) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        local keys = policies[name][kind]
        if keys then rows[#rows + 1] = { Core:Text(keys[1]), Core:Text(keys[2]), addonName = name } end
    end
    return rows
end
local OPERATIONS = Core.Locale:Bind(function()
    return HelpRows("operation", "CORE.YIBOCORE_ACCOUNT_OVERVIEW", "CORE.BROKER_MINIMAP_LEFT_CLICK_TO_TOGGLE_THE")
end)
local USAGE_NOTES = Core.Locale:Bind(function()
    return HelpRows("note", "CORE.ACCOUNT_OVERVIEW_355", "CORE.CHOOSE_A_BUSINESS_PAGE_ON_THE_LEFT")
end)

local function CreateHelp(parent)
    parent.scroll = Theme:CreateScrollFrame(parent)
    parent.scroll:SetPoint("TOPLEFT", 0, 0)
    parent.scroll:SetPoint("BOTTOMRIGHT", 0, 0)

    parent.content = CreateFrame("Frame", nil, parent.scroll)
    parent.scroll:SetScrollChild(parent.content)
    parent.title = AddText(parent.content, "GameFontNormalLarge", Theme.Font.title, COLORS.text)
    parent.title:SetPoint("TOPLEFT", 20, -18)
    parent.title:SetText(Core:Text("CORE.QUICK_CONTROLS"))

    parent.intro = AddText(parent.content, "GameFontNormalSmall", Theme.Font.assist, COLORS.muted)
    parent.intro:SetPoint("TOPLEFT", parent.title, "BOTTOMLEFT", 0, -9)
    parent.intro:SetPoint("RIGHT", -20, 0); parent.intro:SetWordWrap(true)
    parent.intro:SetText("");parent.intro:Hide()
    parent.cards = {}

    for index, operation in ipairs(OPERATIONS) do
        local card = CreateFrame("Frame", nil, parent.content, "BackdropTemplate")
        card:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        card:SetBackdropColor(COLORS.panel[1], COLORS.panel[2], COLORS.panel[3], 0.72)
        card:SetBackdropBorderColor(COLORS.line[1], COLORS.line[2], COLORS.line[3], 0.58)

        card.addonName = operation.addonName
        card.title = AddText(card, "GameFontNormal", Theme.Font.body, COLORS.text)
        card.title:SetPoint("TOPLEFT", 14, -11)
        card.title:SetText(operation[1])
        card.description = AddText(card, "GameFontNormalSmall", Theme.Font.assist, COLORS.muted)
        card.description:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -6)
        card.description:SetPoint("RIGHT", card, "RIGHT", -14, 0)
        card.description:SetWordWrap(true)
        card.description:SetText(operation[2])
        parent.cards[index] = card
    end
    local notesHeading = AddText(parent.content, "GameFontNormal", Theme.Font.section, COLORS.accent)
    notesHeading:SetText(Core:Text("CORE.INTERFACE_GUIDE"))
    parent.notesHeading = notesHeading
    parent.notes = {}
    for index, note in ipairs(USAGE_NOTES) do
        local line = AddText(parent.content, "GameFontNormalSmall", Theme.Font.assist, COLORS.muted)
        line:SetWordWrap(true)
        line:SetText(note[1] .. Core:Text("FORMAT.COLON") .. note[2])
        parent.notes[index] = line
    end

    local function Layout(scroll)
        local width = math.max(1, scroll:GetWidth() or 1)
        parent.content:SetWidth(width)
        local previous, contentHeight = parent.title, 40
        for _, card in ipairs(parent.cards) do
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, previous == parent.title and -12 or -8)
            card:SetWidth(math.max(1, width - 40))
            card.description:SetWidth(math.max(1, card:GetWidth() - 28))
            local height = math.max(68, card.description:GetStringHeight() + 42)
            card:SetHeight(height)
            previous = card
            contentHeight = contentHeight + height + 8
        end
        parent.notesHeading:ClearAllPoints()
        parent.notesHeading:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -18)
        previous = parent.notesHeading
        contentHeight = contentHeight + 32
        for _, line in ipairs(parent.notes) do
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -6)
            line:SetWidth(math.max(1, width - 40))
            previous = line
            contentHeight = contentHeight + math.max(18, line:GetStringHeight()) + 6
        end
        parent.content:SetHeight(contentHeight)
        scroll:SetContentHeight(contentHeight)
        scroll:RefreshScrollbar()
    end
    Layout(parent.scroll)
    parent.scroll:SetScript("OnSizeChanged", Layout)
end

local function RefreshHelp(parent)
    if parent.scroll then parent.scroll:RefreshScrollbar() end
end

AccountView._pages.help = Core.Locale:Bind(function() return {
    id = "help", title = Core:Text("CORE.HELP"), order = 990, internal = true,
    Create = CreateHelp, Refresh = RefreshHelp,
    GetSurfaceMetrics = AccountView._internal.GetAboutSurfaceMetrics,
} end)
