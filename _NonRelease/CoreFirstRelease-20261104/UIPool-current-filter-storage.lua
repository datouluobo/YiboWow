-- Actual target manifests and settings/archive renderers; simulated native UI.
local baseline = arg and arg[1] == 'baseline'
local Boot = dofile('_NonRelease/CoreRetailR2/Harness.lua')
for _, target in ipairs({ 'Mists', 'Retail', 'Forever' }) do
    for _, locale in ipairs({ 'zhCN', 'enUS' }) do
        local env, core, fire, flush = Boot(target, nil, nil, function(e)
            e.GetLocale = function() return locale end
        end)
        fire('ADDON_LOADED'); fire('PLAYER_LOGIN'); flush()
        assert(core:IsInitialized())
        local view = core.AccountView
        local host = env.CreateFrame('Frame', nil, env.UIParent); host:SetSize(900, 650)
        local settings = view._pages.settings
        settings.Create(host); host.scroll:SetSize(880, 550)
        local targets = { 'general', 'core', 'bar', 'display', 'sorting' }
        local function Cycle()
            for _, id in ipairs(targets) do
                view.settingsTargetPageID = id
                settings.Refresh(host); flush()
            end
        end
        Cycle()
        local warmed = #env.TEST_FRAMES
        for i = 1, 20 do Cycle() end
        local ending = #env.TEST_FRAMES
        print(target .. '/' .. locale .. ': settings frames ' .. warmed .. ' -> ' .. ending)
        if not baseline then assert(ending == warmed, 'repeated settings switches must reuse controls') end
        -- Switching kind hides previous controls; reused callbacks retain the current page.
        view.settingsTargetPageID = 'general'; settings.Refresh(host)
        local generalRow = host.rows[1]
        view.settingsTargetPageID = 'display'; settings.Refresh(host)
        if host.rows[1] ~= generalRow then assert(not generalRow:IsShown()) end
        view.settingsTargetPageID = 'general'; settings.Refresh(host)
        if not baseline then assert(host.rows[1] == generalRow) end
        local checked
        for _, row in ipairs(host.rows) do
            if row.controlType == 'check' and row:IsShown() then checked = row; break end
        end
        assert(checked)
        local before = view:GetSettings().entry.showPreviewWhileMainWindowOpen
        -- Callback invokes RefreshPage; hidden shared window leaves this fixture intact.
        checked:GetScript('OnClick')(checked)
        assert(view:GetSettings().entry.showPreviewWhileMainWindowOpen ~= before)
        -- Archive metadata is read per filter pass, not once for every character.
        local characters = {}
        for i = 1, 30 do characters[i] = { id = 'Offline-' .. i, name = 'Role' .. i, realm = 'Realm', level = i } end
        local context = { characters = characters }
        local archiveSettings = view._internal.ArchiveSettings()
        local original, calls = core.Fields.GetByConsumer, 0
        core.Fields.GetByConsumer = function(self, consumer)
            calls = calls + 1; return original(self, consumer)
        end
        local archive = view._pages.characters
        for _, profile in ipairs({ 'all', 'profiled', 'missing' }) do
            archiveSettings.filters.page.profile = profile
            calls = 0
            archive.GetSurfaceMetrics(context)
            print(target .. '/' .. locale .. ': archive filter ' .. profile .. ', metadata reads=' .. calls)
            if not baseline then assert(calls <= 2, 'archive metadata must be resolved once per pass') end
        end
        -- Check filter results, not just reduced calls, with mixed profile data.
        local field = { id = 'fixture.profile', title = 'Profile', width = 80, order = 1,
            defaultVisible = true, Read = function(character) return character.profileValue end }
        core.Fields.GetByConsumer = function() return { field } end
        for i, character in ipairs(characters) do if i % 2 == 0 then character.profileValue = i end end
        local archiveHost = env.CreateFrame('Frame', nil, env.UIParent); archiveHost:SetSize(900, 650)
        archive.Create(archiveHost)
        for _, profile in ipairs({ 'all', 'profiled', 'missing' }) do
            archiveSettings.filters.page.profile = profile
            archive.Refresh(archiveHost, context); flush()
            local visible = 0
            for _, row in ipairs(archiveHost.rows) do if row:IsShown() then visible = visible + 1 end end
            assert(visible == (profile == 'all' and 30 or 15), 'profile filtering must retain the same admission semantics')
        end
        archiveSettings.filters.page.profile = 'all'
        assert(view._internal.SetArchiveLevelFilter('page', '>=20'))
        archiveSettings.filters.page.includeHidden = false
        view:GetSettings().hiddenCharacters['Offline-20'] = true
        archive.Refresh(archiveHost, context); flush()
        local visible = 0
        for _, row in ipairs(archiveHost.rows) do if row:IsShown() then visible = visible + 1 end end
        assert(visible == 10, 'level and hidden-character filters remain effective')
    end
end
print('PASS: settings pool bounds, active callbacks and archive metadata fanout across 3 targets/2 languages')
