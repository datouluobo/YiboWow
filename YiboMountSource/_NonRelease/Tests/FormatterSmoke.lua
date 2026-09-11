local _, NS = ...

local function Expect(actual, expected, label)
    if actual ~= expected then
        error((label or "assertion") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local record = NS.Catalog:GetBySpellID(40192)
local primary, secondary = NS.SourceFormatter:Format(record)
Expect(primary ~= nil, true, "boss source formats a primary line")
Expect(secondary, nil, "boss source has no condition line")

local southwindRecord = NS.Catalog:GetBySpellID(88744)
local southwindPrimary = NS.SourceFormatter:Format(southwindRecord)
Expect(southwindPrimary, "Drop > 风神王座 > Al'Akir", "instance source omits redundant zone and unrestricted group sizes")

local invincibleRecord = NS.Catalog:GetBySpellID(72286)
local invinciblePrimary = NS.SourceFormatter:Format(invincibleRecord)
Expect(invinciblePrimary, "Drop > 冰冠堡垒25H > 巫妖王", "instance size and difficulty are appended")

local mimironRecord = NS.Catalog:GetBySpellID(63796)
local mimironPrimary, mimironCondition = NS.SourceFormatter:Format(mimironRecord)
Expect(mimironPrimary, "Drop > 奥杜尔25人（0守护者） > 尤格-萨隆", "raid size and encounter gate are appended")
Expect(mimironCondition, nil, "encounter gate does not create a sparse condition line")

local skyGolemRecord = NS.Catalog:GetBySpellID(134359)
local skyGolemPrimary = NS.SourceFormatter:Format(skyGolemRecord)
Expect(skyGolemPrimary, "Crafted > Engineering", "sky golem source formats")

local retiredRecord = NS.Catalog:GetBySpellID(60002)
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
Expect(eventPrimary, "Event > Treasure Event", "event source keeps only its clear activity name")
Expect(eventSecondary, "No longer obtainable", "event source omits catalogue-detail notes")

local holidayRecord = NS.Catalog:GetBySpellID(71342)
local holidayPrimary = NS.SourceFormatter:Format(holidayRecord)
Expect(holidayPrimary, "Holiday > Love is in the Air > Apothecary Hummel", "holiday source uses its event and NPC fields")

local fireHawkRecord = NS.Catalog:GetBySpellID(97493)
local fireHawkPrimary = NS.SourceFormatter:Format(fireHawkRecord)
Expect(fireHawkPrimary, "Drop > 火焰之地H > 拉格纳罗斯", "heroic-only raid paths omit unrestricted group sizes")

local heraldRecord = NS.Catalog:GetBySpellID(107844)
local heraldPrimary = NS.SourceFormatter:Format(heraldRecord)
Expect(heraldPrimary, "Drop > 巨龙之魂H > 死亡之翼的疯狂", "all heroic-only 10/25 paths retain only the difficulty")
