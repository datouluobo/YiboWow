local _, NS = ...

local function Expect(actual, expected, label)
    if actual ~= expected then
        error((label or "assertion") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function ContainsPrimary(entries, expected)
    for _, entry in ipairs(entries) do
        if entry.primary == expected then return true end
    end
    return false
end

local record = NS.Catalog:GetBySpellID(40192)
local primary, secondary = NS.SourceFormatter:Format(record)
Expect(primary ~= nil, true, "boss source formats a primary line")
Expect(secondary, nil, "boss source has no condition line")

local southwindRecord = NS.Catalog:GetBySpellID(88744)
local southwindPrimary = NS.SourceFormatter:Format(southwindRecord)
Expect(southwindPrimary, "Drop: 风神王座 > 奥拉基尔", "instance source omits redundant zone and unrestricted group sizes")

local invincibleRecord = NS.Catalog:GetBySpellID(72286)
local invinciblePrimary = NS.SourceFormatter:Format(invincibleRecord)
Expect(invinciblePrimary, "Drop: 冰冠堡垒25H > 巫妖王", "instance size and difficulty are appended")

local mimironRecord = NS.Catalog:GetBySpellID(63796)
local mimironPrimary, mimironCondition = NS.SourceFormatter:Format(mimironRecord)
Expect(mimironPrimary, "Drop: 奥杜尔25人（0守护者） > 尤格-萨隆", "raid size and encounter gate are appended")
Expect(mimironCondition, nil, "encounter gate does not create a sparse condition line")

local skyGolemRecord = NS.Catalog:GetBySpellID(134359)
local skyGolemPrimary = NS.SourceFormatter:Format(skyGolemRecord)
Expect(skyGolemPrimary, "Crafted: Engineering", "sky golem source formats")

local astralRecord = NS.Catalog:GetBySpellID(127170)
local astralSources = NS.SourceFormatter:FormatAll(astralRecord)
Expect(#astralSources, 2, "multi-source mounts format every active acquisition channel")
Expect(astralSources[1].primary, "Drop: 魔古山宝库 > 伊拉贡", "primary source stays first")
Expect(astralSources[2].primary, "Container: Celestial Fortune Bag", "alternative container source follows independently")

local blackMarketRecord = NS.Catalog:GetBySpellID(127158)
local blackMarketSources = NS.SourceFormatter:FormatAll(blackMarketRecord)
Expect(#blackMarketSources, 3, "bag and black-market alternatives format as independent channels")
Expect(blackMarketSources[1].primary, "Drop: 昆莱山 > 怒之煞", "world boss source remains primary")
Expect(ContainsPrimary(blackMarketSources, "Auction House: 黑市拍卖行"), true, "auction channel uses its own concise label")
Expect(ContainsPrimary(blackMarketSources, "Container: Celestial Fortune Bag"), true, "bag channel stays independent from the black-market channel")

local dinosaurEggRecord = NS.Catalog:GetBySpellID(138641)
local dinosaurEggSources = NS.SourceFormatter:FormatAll(dinosaurEggRecord)
Expect(#dinosaurEggSources, 2, "nested bag rewards retain the direct boss source")
Expect(dinosaurEggSources[2].primary, "Container: Celestial Fortune Bag > Primal Dinosaur Egg", "nested container path remains explicit")

local retiredRecord = NS.Catalog:GetBySpellID(107516)
local retiredPrimary, retiredSecondary = NS.SourceFormatter:Format(retiredRecord)
Expect(retiredPrimary ~= nil, true, "retired source formats a primary line")
Expect(retiredSecondary ~= nil, true, "retired source formats an availability line")

local eventRecord = {
    primarySourceID = "event-source",
    sources = {
        {
            sourceID = "event-source",
            type = "event",
            availability = "unavailable",
            path = {
                { kind = "event", labels = { enUS = "Treasure Event", zhCN = "秘宝活动" } },
            },
            requirements = {
                notes = { enUS = "Long delivery and availability details.", zhCN = "冗长的版本、投递与公告说明。" },
            },
        },
    },
}
local eventPrimary, eventSecondary = NS.SourceFormatter:Format(eventRecord)
Expect(eventPrimary, "Event: Treasure Event", "event source keeps only its clear activity name")
Expect(eventSecondary, "No longer obtainable", "event source omits catalogue-detail notes")

local holidayRecord = NS.Catalog:GetBySpellID(71342)
local holidayPrimary = NS.SourceFormatter:Format(holidayRecord)
Expect(holidayPrimary, "Holiday: Love is in the Air > Apothecary Hummel", "holiday source uses its event and NPC fields")

local fireHawkRecord = NS.Catalog:GetBySpellID(97493)
local fireHawkPrimary = NS.SourceFormatter:Format(fireHawkRecord)
Expect(fireHawkPrimary, "Drop: 火焰之地H > 拉格纳罗斯", "heroic-only raid paths omit unrestricted group sizes")

local heraldRecord = NS.Catalog:GetBySpellID(107844)
local heraldPrimary = NS.SourceFormatter:Format(heraldRecord)
Expect(heraldPrimary, "Drop: 巨龙之魂H > 死亡之翼的疯狂", "all heroic-only 10/25 paths retain only the difficulty")

local conciseRecord = {
    status = "verified",
    primarySourceID = "concise-source",
    sources = {
        {
            sourceID = "concise-source",
            type = "promotion",
            availability = "unavailable",
            path = {
                { kind = "promotion", labels = { enUS = "Annual Pass", zhCN = "年度通行证" } },
            },
            requirements = {
                notes = { enUS = "Long maintenance evidence must stay out of the tooltip.", zhCN = "这是一段只供维护者核验的长说明。" },
                tooltipNote = { enUS = "Account reward", zhCN = "账号奖励" },
            },
        },
    },
}
local concisePrimary, conciseSecondary = NS.SourceFormatter:Format(conciseRecord)
Expect(concisePrimary, "Promotion: Annual Pass", "source type is a label rather than a path node")
Expect(conciseSecondary, "Account reward · No longer obtainable", "only curated tooltip notes and normalized states are shown")

local researchRecord = {
    status = "candidate",
    primarySourceID = "research-source",
    sources = {
        {
            sourceID = "research-source",
            type = "research",
            availability = "unknown",
            path = {
                { kind = "custom", labels = { enUS = "Source pending", zhCN = "来源待补全" } },
            },
            requirements = {
                notes = { enUS = "Internal research detail.", zhCN = "内部研究说明。" },
            },
        },
    },
}
local researchPrimary, researchSecondary = NS.SourceFormatter:Format(researchRecord)
Expect(researchPrimary, nil, "research-only records stay out of player tooltips")
Expect(researchSecondary, nil, "research notes never create a tooltip line")
