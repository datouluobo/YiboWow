-- Real navigation and settings APIs, synthetic focus-loss propagation on hide.
local baseline = arg and arg[1] == 'baseline'
local Boot = dofile('_NonRelease/CoreRetailR2/Harness.lua')
for _, target in ipairs({ 'Mists', 'Retail', 'Forever' }) do
    local env, core, fire, flush = Boot(target, nil, nil, function(e)
        local methods = getmetatable(e.UIParent).__index
        local hide = methods.Hide
        methods.ClearFocus = function(control)
            local focused = control.focused
            control.focused, control.composing = false, false
            if focused then control:Fire('OnEditFocusLost') end
        end
        methods.Hide = function(control)
            hide(control)
            for _, candidate in ipairs(e.TEST_FRAMES) do
                if candidate.focused then
                    local parent = candidate
                    while parent and parent ~= control do parent = parent:GetParent() end
                    if parent then candidate:ClearFocus() end
                end
            end
        end
    end)
    fire('ADDON_LOADED'); fire('PLAYER_LOGIN'); flush()
    local view, refreshes, creates, metrics, contexts = core.AccountView, {}, {}, {}, 0
    assert(core:RegisterAddon('SwitchFixture', { requiredAPI = 13 }))
    for _, id in ipairs({ 'switch.a', 'switch.b' }) do
        local pageID = id
        assert(view:RegisterPage('SwitchFixture', { id = pageID, title = pageID, fields = {},
            Create = function() creates[pageID] = (creates[pageID] or 0) + 1 end,
            Refresh = function() refreshes[pageID] = (refreshes[pageID] or 0) + 1 end,
            GetSurfaceMetrics = function()
                metrics[pageID] = (metrics[pageID] or 0) + 1
                return { minContentWidth = 600, naturalContentWidth = 800, minContentHeight = 300, naturalContentHeight = 500 }
            end }))
    end
    local settings = view._pages.settings
    local settingsRefresh = settings.Refresh
    settings.Refresh = function(...) refreshes.settings = (refreshes.settings or 0) + 1; return settingsRefresh(...) end
    local buildContext = view.BuildContext
    view.BuildContext = function(self, ...) contexts = contexts + 1; return buildContext(self, ...) end
    local function Nav(pageID, settingsID)
        for _, button in ipairs(view.frame.navButtons) do
            if button:IsShown() and (settingsID and button.settingsTargetID == settingsID or not settingsID and button.pageID == pageID) then
                button:Fire('OnClick'); return
            end
        end
        error('missing navigation target')
    end
    view:Toggle('switch.a'); Nav('switch.b'); Nav('switch.a')
    assert(creates['switch.a'] == 1 and creates['switch.b'] == 1)
    local pointWrites = 0
    for _, button in ipairs(view.frame.navButtons) do
        for _, control in ipairs({ button, button.label }) do
            local setPoint = control.SetPoint
            control.SetPoint = function(self, ...) pointWrites = pointWrites + 1; return setPoint(self, ...) end
        end
    end
    local a, b = refreshes['switch.a'], refreshes['switch.b']
    local ma, mb = metrics['switch.a'], metrics['switch.b']
    contexts = 0
    for i = 1, 20 do Nav('switch.b'); Nav('switch.a') end
    print(target .. ': 40 main switches, contexts=' .. contexts .. ', nav anchor writes=' .. pointWrites)
    assert(contexts == 40 and refreshes['switch.a'] - a == 20 and refreshes['switch.b'] - b == 20)
    assert(metrics['switch.a'] - ma == 20 and metrics['switch.b'] - mb == 20)
    if not baseline then assert(pointWrites == 0) end
    view:ShowSettings('general')
    local previous = refreshes.settings; contexts = 0
    view:ShowSettings('display')
    print(target .. ': explicit settings switch, refreshes=' .. (refreshes.settings - previous) .. ', contexts=' .. contexts)
    if not baseline then assert(refreshes.settings - previous == 1 and contexts == 1) end
    local host = view.frame.instances.settings
    host.showShortNames = true
    view:SelectSettingsTarget('sorting')
    local shortInput, filterInput, archiveInput
    for _, row in ipairs(host.rows) do
        if row:IsShown() and row.controlType == 'short-name' then shortInput = row.input end
        if row:IsShown() and row.controlType == 'input' then
            if row.label:GetText() == 'switch.a' then filterInput = row.input
            elseif row.label:GetText() == core:Text('CORE.TABLE_LEVEL_FILTER') then archiveInput = row.input end
        end
    end
    assert(shortInput and filterInput and archiveInput)
    local setters, shortSetter = 0, core.Characters.SetShortName
    core.Characters.SetShortName = function(self, ...) setters = setters + 1; return shortSetter(self, ...) end
    previous = refreshes.settings
    shortInput:SetFocus(); shortInput:ClearFocus()
    filterInput:SetFocus(); filterInput:ClearFocus()
    archiveInput:SetFocus(); archiveInput:ClearFocus()
    print(target .. ': 3 unchanged focus losses, refreshes=' .. (refreshes.settings - previous) .. ', short-name writes=' .. setters)
    if not baseline then assert(refreshes.settings == previous and setters == 0) end
    -- A real edit still commits on leaving settings; it must not redraw the old page.
    view:SelectSettingsTarget('sorting')
    for _, row in ipairs(host.rows) do if row:IsShown() and row.controlType == 'short-name' then shortInput = row.input; break end end
    shortInput:SetFocus(); shortInput:InputText('Nickname')
    previous = refreshes.settings
    view:ShowPage('switch.a')
    assert(core.Characters:GetDisplayName(core.Characters:GetCurrent({ identityOnly = true }), 'short') == 'Nickname')
    assert(view.activePageID == 'switch.a')
    print(target .. ': leave edited settings, obsolete settings refreshes=' .. (refreshes.settings - previous))
    if not baseline then assert(refreshes.settings == previous) end
    -- Public invalid-target fallback and combat deferral remain intact.
    local combat = false
    core.Client.IsInCombat = function() return combat end
    combat = true
    assert(view:ShowSettings('general') == false and view.activePageID == 'switch.a')
    combat = false
    view:ShowSettings('missing-target')
    assert(view.activePageID == 'settings' and view.settingsTargetPageID == 'switch.a')
    assert(creates['switch.a'] == 1 and creates['switch.b'] == 1)
    -- A committed edit renders once; unchanged, invalid and escaped edits do not save again.
    view:SelectSettingsTarget('sorting')
    for _, row in ipairs(host.rows) do
        if row:IsShown() and row.controlType == 'input' and row.label:GetText() == 'switch.a' then filterInput = row.input end
    end
    previous = refreshes.settings
    filterInput:SetFocus(); filterInput:InputText('>= 20'); filterInput:Fire('OnEnterPressed')
    assert(view._pages['switch.a'].characterFilter.GetExpression() == '>=20')
    if not baseline then assert(refreshes.settings - previous == 1) end
    previous = refreshes.settings
    filterInput:SetFocus(); filterInput:InputText('not-a-filter'); filterInput:Fire('OnEnterPressed')
    assert(view._pages['switch.a'].characterFilter.GetExpression() == '>=20')
    if not baseline then assert(refreshes.settings == previous) end
    filterInput:SetFocus(); filterInput:InputText('<30'); filterInput:Fire('OnEscapePressed')
    assert(view._pages['switch.a'].characterFilter.GetExpression() == '>=20')
    -- Changed edits commit during settings-to-settings navigation, without nested rendering.
    filterInput:SetFocus(); filterInput:InputText('>=30')
    previous = refreshes.settings
    view:SelectSettingsTarget('general')
    assert(view._pages['switch.a'].characterFilter.GetExpression() == '>=30')
    if not baseline then assert(refreshes.settings - previous == 1) end
    -- Standalone hosted settings retain their own child controls and refresh once.
    local hosted = 0
    assert(core:RegisterSettingsPanel('SwitchFixture', { id = 'switch-only', title = 'Standalone',
        CreateSettingsPanel = function(parent)
            hosted = hosted + 1
            parent.fixturePanel = parent.fixturePanel or env.CreateFrame('Frame', nil, parent)
            parent.fixturePanel:Show(); return 100
        end }))
    local beforeHosted = hosted
    view:ShowSettings('addon-settings:switch-only')
    if not baseline then assert(hosted - beforeHosted == 1) end
    local reused
    for _, row in ipairs(host.rows) do if row.controlType == 'addon-panel' then reused = row.fixturePanel end end
    view:SelectSettingsTarget('general'); view:ShowSettings('addon-settings:switch-only')
    local found
    for _, row in ipairs(host.rows) do if row.controlType == 'addon-panel' and row:IsShown() then found = row.fixturePanel end end
    assert(found == reused)
    -- Navigation metadata stays live even when geometry is reused.
    view:ShowPage('switch.a')
    view._pages['switch.a'].title = 'Updated page title'
    view:RefreshNavigation()
    local updated
    for _, button in ipairs(view.frame.navButtons) do
        if button:IsShown() and button.pageID == 'switch.a' then updated = button.label:GetText() end
    end
    assert(updated == 'Updated page title')
    view:GetSettings().pages['switch.b'] = false; view:RefreshNavigation()
    for _, button in ipairs(view.frame.navButtons) do assert(not (button:IsShown() and button.pageID == 'switch.b')) end
    view:GetSettings().pages['switch.b'] = true; view:RefreshNavigation(); Nav('switch.b')
    assert(view.activePageID == 'switch.b')
end
print('PASS: main/settings navigation work, unchanged/edited focus loss, instance reuse and public entry guards')
