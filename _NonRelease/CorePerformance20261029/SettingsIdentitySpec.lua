-- Real manifests: settings metadata must not clone unrelated domain payloads.
local baseline = arg and arg[1] == 'baseline'
local Boot = dofile('_NonRelease/CoreRetailR2/Harness.lua')
for _, target in ipairs({ 'Mists', 'Retail', 'Forever' }) do
    local env, core, fire, flush = Boot(target)
    fire('ADDON_LOADED'); fire('PLAYER_LOGIN'); flush()
    local db, records = core.Database:GetDB(), {}
    for i = 1, 20 do
        local id = 'Offline-' .. i
        local data = {}
        for k = 1, 500 do data[k] = { id = k, count = k } end
        local record = { id = id, name = 'Role' .. i, realm = 'Realm', level = i,
            seenOrder = i, domains = { fixture = { state = 'known', data = data } } }
        db.characters.byID[id] = record; db.characters.seenOrder[id] = i; records[record] = true
    end
    core.Characters:InvalidateAllCache()
    local copies, original = 0, core.Defaults.Copy
    core.Defaults.Copy = function(self, value)
        if records[value] then copies = copies + 1 end
        return original(self, value)
    end
    local function Measure(label, callback, expected)
        collectgarbage('collect'); collectgarbage('stop')
        copies = 0
        local before = collectgarbage('count')
        callback()
        local allocation = collectgarbage('count') - before
        collectgarbage('restart')
        print(string.format('%s %s: full copies=%d, allocation=%.1f KB', target, label, copies, allocation))
        if not baseline then assert(copies == expected, label .. ' copies unrelated domains') end
    end
    Measure('100 duplicate checks/no duplicates', function()
        for i = 1, 100 do assert(next(core.Characters:GetShortNameDuplicates()) == nil) end
    end, 0)
    local view = core.AccountView
    Measure('cold settings context', function()
        core.Characters:InvalidateAllCache()
        local context = view:BuildContext(view._pages.settings)
        assert(#context.characters == 21)
    end, 0)
    Measure('all settings pages', function()
        core.Characters:InvalidateAllCache()
        for _, id in ipairs({ 'general', 'core', 'bar', 'display', 'sorting' }) do
            view.settingsTargetPageID = id; view:ShowPage('settings'); flush()
            assert(not view._pages.settings.lastError)
        end
        view:RebuildCustomCharacterOrder('recent')
        view:RebuildCustomCharacterOrder('seen')
    end, 0)
    Measure('expanded short-name/order editors', function()
        core.Characters:InvalidateAllCache()
        local host = view.frame.instances.settings
        host.showShortNames, host.showCharacterOrder = true, true
        view.frame:Show()
        view.settingsTargetPageID = 'sorting'; view:ShowPage('settings'); flush()
        local shortNames, orderRows = 0, 0
        for _, row in ipairs(host.rows) do
            if row:IsShown() and row.controlType == 'short-name' then shortNames = shortNames + 1 end
            if row:IsShown() and row.controlType == 'character-order' then orderRows = orderRows + 1 end
        end
        assert(shortNames > 0 and orderRows > 0)
        if not baseline then assert(core.Characters._allSnapshot == nil, 'settings must not retain a complete roster cache') end
    end, 0)
    -- Public duplicate results remain full, detached and ordered by registration.
    db.characterDisplay = { ['Offline-2'] = { shortName = 'same' }, ['Offline-11'] = { shortName = 'same' },
        ['Offline-3'] = { shortName = 'unique' } }
    Measure('actual duplicate group', function()
        local duplicate = core.Characters:GetShortNameDuplicates().same
        assert(#duplicate == 2 and duplicate[1].id == 'Offline-2' and duplicate[2].id == 'Offline-11')
        assert(duplicate[1].domains.fixture.data[500].id == 500)
        duplicate[1].domains.fixture.data[500].id = -1
        assert(db.characters.byID['Offline-2'].domains.fixture.data[500].id == 500)
    end, 2)
    db.characterDisplay = {}
    local full = core.Characters:GetAll()
    local found
    for _, character in ipairs(full) do if character.id == 'Offline-2' then found = character end end
    assert(found.domains.fixture.data[500].id == 500)
    -- Business page contexts retain the default complete-character contract.
    local business = { id = 'fixture.business', fields = {} }
    local context = view:BuildContext(business)
    local found
    for _, character in ipairs(context.characters) do if character.id == 'Offline-2' then found = character end end
    assert(found and found.domains.fixture.data[500].id == 500)
end
print('PASS: settings identity-only reads; full detached duplicate groups and public/business context compatibility')
