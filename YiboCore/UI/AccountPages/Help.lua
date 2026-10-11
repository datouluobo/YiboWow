-- Internal account page for documenting quick operations across Yibo plugins.
local Core = _G.YiboCore
local AccountView = Core.AccountView
local Theme = Core.UITheme
local COLORS = Theme.Colors
local AddText = AccountView._internal.AddText

local OPERATIONS = Core.Locale:Bind(function() return {
    { Core:Text("CORE.YIBOCORE_ACCOUNT_OVERVIEW"), Core:Text("CORE.BROKER_MINIMAP_LEFT_CLICK_TO_TOGGLE_THE") },
    { Core:Text("CORE.YIBOALTOBOSS_BOSSES_LOCKOUTS"), Core:Text("CORE.CLICK_A_CHARACTER_TARGET_STATUS_CELL_TO") },
    { Core:Text("CORE.YIBOLEGENDARY_LEGENDARY_PATHS"), Core:Text("CORE.CLICK_A_TARGET_COLUMN_OR_CHARACTER_PROGRESS") },
    { Core:Text("CORE.YIBOQUESTBLOCKER_QUEST_BLOCKER"), Core:Text("CORE.CLICK_A_QUEST_ROW_S_EXPAND_ICON") },
    { Core:Text("CORE.YIBOTODO_DAILY_ACTIONS"), Core:Text("CORE.CLICK_AN_AVAILABLE_ACTION_ICON_FOR_THE") },
    { Core:Text("CORE.YIBOMAIL_MAIL"), Core:Text("CORE.RULE_BASED_MAIL_DROP_A_BAG_ITEM") },
    { Core:Text("CORE.YIBOCURRENCY_CURRENCY_OVERVIEW"), Core:Text("CORE.RIGHT_CLICK_A_CURRENCY_ROW_TO_TOGGLE") },
    { Core:Text("CORE.YIBOVAULT_ACCOUNT_STORAGE"), Core:Text("CORE.SELECT_A_CHARACTER_OR_GUILD_ON_THE") },
    { Core:Text("CORE.YIBOCRAFTING_PROFESSION_RECIPES"), Core:Text("CORE.CLICK_A_RECIPE_ROW_NAME_OR_ITEM") },
    { Core:Text("CORE.YIBOREPUTATION_REPUTATION_OVERVIEW"), Core:Text("CORE.CLICK_A_REPUTATION_NAME_TO_EXPAND_OR") },
    { Core:Text("CORE.YIBOBUILDS_EQUIPMENT_APPEARANCE"), Core:Text("CORE.MODEL_PREVIEW_DRAG_TO_ROTATE_AND_USE") },
    { Core:Text("CORE.YIBOAUTOOPEN_AUTO_OPEN"), Core:Text("CORE.IN_SETTINGS_DROP_A_BAG_ITEM_INTO") },
    { Core:Text("CORE.YIBOBEASTPATHS_BEAST_PATHS"), Core:Text("CORE.CLICK_THE_ADDON_BUTTON_ON_THE_WORLD") },
    { Core:Text("CORE.YIBOMOUNTS_MOUNT_JOURNAL"), Core:Text("CORE.USE_THE_COLLECTED_AND_NOT_COLLECTED_CHECKBOXES") },
} end)

local USAGE_NOTES = Core.Locale:Bind(function() return {
    { Core:Text("CORE.ACCOUNT_OVERVIEW_355"), Core:Text("CORE.CHOOSE_A_BUSINESS_PAGE_ON_THE_LEFT") },
    { Core:Text("CORE.CHARACTER_BUILDS"), Core:Text("CORE.DRAG_TO_ROTATE_MOUSE_WHEEL_TO_ZOOM") },
    { Core:Text("CORE.ACCOUNT_TO_DO_SETTINGS"), Core:Text("CORE.EACH_SWITCH_CONTROLS_A_COLUMN_IN_THE") },
    { Core:Text("CORE.REPUTATION_MONITORING_SETTINGS"), Core:Text("CORE.ADD_STARS_QUICKLY_IN_THE_MAIN_MATRIX") },
} end)

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
