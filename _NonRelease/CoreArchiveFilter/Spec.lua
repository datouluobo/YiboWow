-- Exercise the actual settings controls and selected manifests, then reboot
-- with a detached SavedVariables snapshot (synthetic client persistence).
local Boot = dofile('_NonRelease/CoreRetailR2/Harness.lua')
for _, target in ipairs({ 'Mists', 'Forever', 'Retail' }) do
    for _, language in ipairs({ 'zhCN', 'enUS' }) do
        local env, core, fire, flush = Boot(target, nil, nil, function(e)
            e.GetLocale = function() return language end
            e.UnitLevel = function() return 9 end
        end)
        fire('ADDON_LOADED'); fire('PLAYER_LOGIN'); flush()
        local view = core.AccountView
        local helpers = view._internal
        local function Open()
            view:ShowSettings('sorting'); flush()
            assert(not view._pages.settings.lastError)
        end
        local function Input(key)
            for _, row in ipairs(view.frame.instances.settings.rows) do
                if row.controlType == 'input' and row.label:GetText() == core:Text(key) then return row.input end
            end
            error('missing input: ' .. key)
        end
        local function Expect(page, preview)
            local filters = helpers.ArchiveSettings().filters
            assert(filters.page.levelExpr == page, 'page expression lost')
            assert(filters.preview.levelExpr == preview, 'preview expression lost')
        end
        Open()
        Input('CORE.TABLE_LEVEL_FILTER'):SetText(' >= 85 ')
        Input('CORE.TABLE_LEVEL_FILTER'):Fire('OnEnterPressed')
        Input('CORE.HOVER_LEVEL_FILTER'):SetText('1-20,90')
        Input('CORE.HOVER_LEVEL_FILTER'):Fire('OnEditFocusLost')
        Expect('>=85', '1-20,90')
        view:ShowSettings('general'); flush()
        assert(view:GoBack()); flush()
        Expect('>=85', '1-20,90')
        assert(Input('CORE.TABLE_LEVEL_FILTER'):GetText() == '>=85')
        Input('CORE.TABLE_LEVEL_FILTER'):SetText('invalid')
        Input('CORE.TABLE_LEVEL_FILTER'):Fire('OnEnterPressed')
        Expect('>=85', '1-20,90')
        Input('CORE.HOVER_LEVEL_FILTER'):SetText('80')
        Input('CORE.HOVER_LEVEL_FILTER'):Fire('OnEscapePressed')
        Expect('>=85', '1-20,90')
        view.frame:Hide()
        Open()
        Expect('>=85', '1-20,90')
        local saved = core.Defaults:Copy(core.Database:GetDB())
        local _, reboot, event, tick = Boot(target, saved)
        event('ADDON_LOADED'); event('PLAYER_LOGIN'); tick()
        local restored = reboot.AccountView._internal.ArchiveSettings().filters
        assert(restored.page.levelExpr == '>=85' and restored.preview.levelExpr == '1-20,90')
        -- Clearing either input is a durable edit, independent of the other.
        Input('CORE.TABLE_LEVEL_FILTER'):SetText('')
        Input('CORE.TABLE_LEVEL_FILTER'):Fire('OnEditFocusLost')
        view.frame:Hide(); Open(); Expect('', '1-20,90')
        Input('CORE.HOVER_LEVEL_FILTER'):SetText('0')
        Input('CORE.HOVER_LEVEL_FILTER'):Fire('OnEnterPressed')
        view.frame:Hide(); Open(); Expect('', '0')
        assert(helpers.SetArchiveLevelFilter('preview', '>=60'))
        view.frame:Hide()
        assert(view:ShowPreview('characters', env.Minimap))
        local archive = view.frame.instances.characters
        local settingsLabel = core:Text('CORE.CHARACTERS_SORTING')
        assert(archive.emptyMessage:IsShown() and not archive.listHeader:IsShown() and not archive.scroll:IsShown())
        assert(archive.emptyMessage:GetText() == core:Text('CORE.ARCHIVE_EMPTY_LEVEL',
            core:Text('CORE.HOVER_LEVEL_FILTER'), '>=60', settingsLabel))
        Expect('', '>=60')
        view:HidePreview()
        view:Toggle('characters')
        assert(not view._pages.characters.lastError, view._pages.characters.lastError)
        assert(not archive.emptyMessage:IsShown() and archive.listHeader:IsShown() and archive.rows[1]:IsShown())
        assert(helpers.SetArchiveLevelFilter('page', '>=60'))
        view:RefreshPage(); flush()
        assert(archive.emptyMessage:GetText() == core:Text('CORE.ARCHIVE_EMPTY_LEVEL',
            core:Text('CORE.TABLE_LEVEL_FILTER'), '>=60', settingsLabel))
        assert(not archive.rows[1]:IsShown())
        assert(helpers.SetArchiveLevelFilter('preview', ''))
        view.frame:Hide()
        assert(view:ShowPreview('characters', env.Minimap))
        assert(not archive.emptyMessage:IsShown() and archive.scroll:IsShown() and archive.rows[1]:IsShown())
        helpers.Settings().hiddenCharacters[env.TEST_GUID] = true
        assert(view:ShowPreview('characters', env.Minimap, true))
        assert(archive.emptyMessage:GetText() == core:Text('CORE.ARCHIVE_EMPTY_FILTERED', settingsLabel))
        view._pages.characters.Refresh(archive, { characters = {}, preview = true })
        assert(archive.emptyMessage:GetText() == core:Text('CORE.ARCHIVE_EMPTY_NO_DATA'))
        print('PASS archive level settings: ' .. target .. '/' .. language)
    end
end
