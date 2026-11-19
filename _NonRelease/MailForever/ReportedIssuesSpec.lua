local Boot = dofile("_NonRelease/MailForever/Harness.lua")
for _, forever in ipairs({ true, false }) do
    local _, core, mail = Boot(nil, nil, forever)
    local current = core.Characters:GetCurrent()
    current.name, current.realm, current.faction = forever and "Alpha First" or "Alpha", "Realm", "Alliance"
    local alt = { id = "Player-Other", name = forever and "Beta Second" or "Beta", realm = "Realm", faction = "Alliance" }
    core.Characters.GetCurrent = function() return current end
    core.Characters.GetAllCached = function() return { current, alt } end
    local candidates = mail.Recipients:Candidates("characters")
    assert(#candidates == 1 and candidates[1].address == alt.name .. "-Realm", "known account roles must survive native name validation")
    assert(mail.Recipients:SetShortcut(1, candidates[1].address))
    assert(mail.db.quickRecipients[1].address == alt.name .. "-Realm")
    assert(mail.Recipients:CanRuleSend(candidates[1].address), "complete account names retain Core faction evidence")
    assert(not mail.Recipients:Normalize("Bad\nName") and not mail.Recipients:Normalize("Bad|Name"))
    if not forever then assert(not mail.Recipients:Normalize("Beta Second"), "MoP still rejects spaces") end
end
local BootCore = dofile("_NonRelease/CoreForever/Harness.lua")
for _, forever in ipairs({ true, false }) do
    for _, language in ipairs({ "zh", "en" }) do
        local e, core, fire, flush = BootCore(forever)
        e.TEST_GUID = "Player-MoneyTest"
        fire("ADDON_LOADED"); fire("PLAYER_LOGIN"); flush()
        core.Locale.language = language
        assert(core:RegisterAddon("MoneyFixture", { requiredAPI = 13 }))
        assert(core.Contracts:Register("MoneyFixture", { name = "character-archive.fields", kind = "provider", providerID = "MoneyFixture:money",
            version = { major = 1, minor = 0 }, methods = {
                GetFields = function() return { { id = "character.money", title = "Gold", width = 72, order = 110,
                    formatKind = "money", defaultVisible = true, defaultPreviewVisible = true } } end,
                Read = function(request)
                    local rows = {}
                    for _, id in ipairs(request.characterIDs) do rows[id] = { fields = { ["character.money"] = { value = 4214, state = "stale" } } } end
                    return { sourceID = "MoneyFixture:money", characters = rows }
                end,
            } }))
        core.AccountView:ShowPage("characters"); flush()
        local frame = core.AccountView.frame.instances.characters
        local fields = core.AccountView._internal.GetArchiveFields(false)
        local index
        for i, field in ipairs(fields) do if field.id == "character.money" then index = i end end
        local cell = assert(frame.rows[1].dynamicCells[index])
        assert(cell:GetWidth() >= core.UITheme:MeasureText(core.UITheme.Font.body, cell:GetText()) + 12,
            "archive money column must fit the complete formatted silver/copper and stale suffix")
        assert(frame.listHeader.dynamicCells[index]:GetWidth() == cell:GetWidth(), "money header and rows share one width")
    end
end
print("PASS: Forever complete account mail names, MoP validation, archive money width in both targets/languages")
