-- Internal account page for documenting quick operations across Yibo plugins.
local Core = _G.YiboCore
local AccountView = Core.AccountView
local Theme = Core.UITheme
local COLORS = Theme.Colors
local AddText = AccountView._internal.AddText

local OPERATIONS = {
    { "YiboCore · 账号总览", "Broker／小地图入口：左键打开或收起账号视图，右键打开对应设置；悬停查看多角色预览。拖动小地图入口可调整位置。拖动窗口标题栏可移动窗口。点击“排序”切换角色顺序，按住 Shift 点击可切换排序方向。Core 物品选择器出现拖放区时，可将背包物品拖入选取。" },
    { "YiboAltoBoss · Boss 与副本进度", "账号页中点击角色与目标交叉处的状态格，可切换该角色的击杀记录；节日首领的状态格也可点击切换手动记录。等级筛选框按 Enter 应用，按 Escape 恢复已保存条件。" },
    { "YiboLegendary · 传说之路", "点击目标列或角色进度格可打开对应路线。允许手动确认的进度行：左键标记已获得；对已有手动记录右键可撤销确认。" },
    { "YiboQuestBlocker · 任务屏蔽", "点击任务行的展开图标可展开或折叠任务组。点击全局或角色状态格，可切换该任务的屏蔽状态。修改等级条件后按 Enter 应用。" },
    { "YiboTodo · 每日行动", "点击当前角色可执行的行动图标会触发图标对应操作（例如使用物品、打开专业或制造）。有第二操作的图标可右键执行；具体动作以悬停提示和图标状态为准。" },
    { "YiboMail · 邮件", "发规则寄页：把背包物品拖到快捷联系人图标，确认后建立或更新该物品的寄送规则。发件箱页：把背包物品拖到快捷联系人图标，会填入联系人与主题并尝试直接寄出；若客户端未确认发送，会保留已填邮件供你检查并手动发送。按住 Ctrl 点击背包物品，可把背包中同种物品一并加入附件。快捷联系人图标：右键编辑；左键拖到其它格可移动／交换，拖出联系人栏可移除。收件箱信件：左键展开／收起附件，右键打开／关闭原生信件，中键直接收取本封邮件附件；附件分组 Alt+左键只收最早到期邮件中的一个附件。" },
    { "YiboCurrency · 货币总览", "右键点击货币行，可将该货币加入或移出悬停监控；自定义货币右键会先要求确认删除。悬停货币行可查看明细。" },
    { "YiboVault · 账号仓库", "点击左侧角色或公会可切换物品来源，点击上方区域标签切换背包、银行等区域。悬停物品可查看物品提示与来源信息。" },
    { "YiboCrafting · 专业配方", "点击配方行、配方名称或物品图标可选中配方并查看详情；使用筛选和搜索缩小配方列表。搜索框按 Enter 提交当前搜索，按 Escape 仅结束输入。" },
    { "YiboReputation · 声望总览", "点击声望名称可展开／折叠分类；点击星标可加入或移出监控。点击具体声望条目可将其设为当前关注项。" },
    { "YiboBuilds · 配装与外观", "装备模型预览：拖动模型可旋转，滚动鼠标滚轮可缩放。将背包中的可用附魔或宝石拖到角色装备栏对应部位，可在确认后进入游戏原生施加流程。其他装备、构筑与外观操作请使用页面上的按钮；覆盖装备前会显示确认框。" },
    { "YiboAutoOpen · 自动开包", "在设置页把背包物品拖到“拖放背包物品到这里”，可将该物品加入自动开包目录。" },
    { "YiboBeastPaths · 隐兽寻踪", "点击世界地图上的插件按钮，可开关地图路线显示。" },
    { "YiboMounts · 坐骑图鉴", "在设置中点击“已收集”或“未收集”复选框，可切换对应坐骑是否显示。" },
}

local USAGE_NOTES = {
    { "账号概览", "从左侧选择业务页，比较角色的下一步行动。" },
    { "角色构筑", "拖动旋转 · 滚轮缩放。" },
    { "账号待办设置", "每个开关控制账号矩阵的一列；包含多个项目的列可单独选择项目。" },
    { "声望监控设置", "星标可在主矩阵中快速添加；此处按当前顺序显示并可移除。" },
}

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
    parent.intro:SetText("按插件查看鼠标与键盘操作。仅列出有特殊行为的手势；未特别说明的按钮使用常规左键操作。")
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
    notesHeading:SetText("界面说明")
    parent.notesHeading = notesHeading
    parent.notes = {}
    for index, note in ipairs(USAGE_NOTES) do
        local line = AddText(parent.content, "GameFontNormalSmall", Theme.Font.assist, COLORS.muted)
        line:SetWordWrap(true)
        line:SetText(note[1] .. "：" .. note[2])
        parent.notes[index] = line
    end

    local function Layout(scroll)
        local width = math.max(1, scroll:GetWidth() or 1)
        parent.content:SetWidth(width)
        local previous, contentHeight = parent.intro, 82
        for _, card in ipairs(parent.cards) do
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, previous == parent.intro and -20 or -8)
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

AccountView._pages.help = {
    id = "help", title = "帮助", order = 990, internal = true,
    Create = CreateHelp, Refresh = RefreshHelp,
    GetSurfaceMetrics = function()
        return { minContentWidth = 582, naturalContentWidth = 764, minContentHeight = 150, naturalContentHeight = 180, verticalOverflow = "content" }
    end,
}
