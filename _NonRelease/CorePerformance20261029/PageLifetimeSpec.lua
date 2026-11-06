-- Real settings host callbacks and preview -> main/settings transitions.
local baseline = arg and arg[1] == 'baseline'
local Boot = dofile('_NonRelease/CoreRetailR2/Harness.lua')
for _, target in ipairs({ 'Mists', 'Retail', 'Forever' }) do
    local env, core, fire, flush = Boot(target)
    fire('ADDON_LOADED'); fire('PLAYER_LOGIN'); flush()
    local view, renders, panels, contexts = core.AccountView, {}, {}, {}
    assert(core:RegisterAddon('LifetimeFixture', { requiredAPI = 13 }))
    for _, id in ipairs({ 'life.a', 'life.b' }) do
        local pageID = id
        assert(view:RegisterPage('LifetimeFixture', { id = pageID, title = pageID, fields = {}, previewEnabled = true,
            Create = function() end,
            Refresh = function(_, context)
                if not context.preview then renders[pageID] = (renders[pageID] or 0) + 1 end
            end,
            GetHoverMetrics = function() return { minWidth = 200, preferredWidth = 400, minHeight = 150, preferredHeight = 250 } end,
            settings = { CreateSettingsPanel = function(parent, context)
                panels[pageID] = (panels[pageID] or 0) + 1
                contexts[pageID] = context
                parent[pageID] = parent[pageID] or env.CreateFrame('Frame', nil, parent)
                parent[pageID]:Show()
                return 100 + panels[pageID]
            end } }))
    end
    view:Toggle('life.a'); view:ShowSettings('life.a')
    local old = contexts['life.a']
    local before = panels['life.a']; old.refreshPanel(); assert(panels['life.a'] == before + 1)
    view:SelectSettingsTarget('life.b')
    local a, b = panels['life.a'], panels['life.b']
    local host = view.frame.instances.settings
    local height = host.settingsContentHeight
    old.refreshPanel(); old.refreshPage()
    print(target .. ': departed host callbacks, old/current renders=' .. (panels['life.a'] - a) .. '/' .. (panels['life.b'] - b))
    if not baseline then assert(panels['life.a'] == a and panels['life.b'] == b and host.settingsContentHeight == height) end
    -- Business invalidation notification remains callable while the settings UI is hidden.
    local notifications, notify = 0, view.NotifyPageChanged
    view.NotifyPageChanged = function(self, id) if id == 'life.a' then notifications = notifications + 1 end; return notify(self, id) end
    old.notifyPageChanged(); assert(notifications == 1)
    local hidden = contexts['life.b']; b = panels['life.b']
    view.frame:Hide(); hidden.refreshPanel()
    print(target .. ': hidden host callback renders=' .. (panels['life.b'] - b))
    if not baseline then assert(panels['life.b'] == b) end
    view:ShowSettings('life.a'); a = panels['life.a']
    old.refreshPanel(); assert(panels['life.a'] == a + 1, 'retained widget callback works when its original owner is visible again')
    local standaloneCalls, standalone = 0, nil
    assert(core:RegisterSettingsPanel('LifetimeFixture', { id = 'life.only', title = 'Only settings',
        CreateSettingsPanel = function(_, context)
            standaloneCalls = standaloneCalls + 1; standalone = standalone or context; return 70
        end }))
    view:ShowSettings('addon-settings:life.only')
    local count = standaloneCalls; standalone.refreshPanel(); assert(standaloneCalls == count + 1)
    view:SelectSettingsTarget('general'); count = standaloneCalls; standalone.refreshPanel()
    if not baseline then assert(standaloneCalls == count) end
    view:ShowSettings('addon-settings:life.only'); count = standaloneCalls
    assert(core:UnregisterSettingsPanel('life.only', 'LifetimeFixture'))
    standalone.refreshPanel()
    if not baseline then assert(standaloneCalls == count, 'unregistered providers cannot render through retained callbacks') end
    local anchor = env.CreateFrame('Frame', nil, env.UIParent)
    view:GetSettings().entry.showPreviewWhileMainWindowOpen = true
    view:ShowPage('life.a'); view.frame:Show()
    assert(view:ShowPreview('life.b', anchor))
    a, b = renders['life.a'], renders['life.b'] or 0
    view:Toggle('life.b')
    print(target .. ': preview navigation, previous/target page renders=' .. (renders['life.a'] - a) .. '/' .. (renders['life.b'] - b))
    assert(view.activePageID == 'life.b' and view.frame:IsShown() and not view.frame.preview)
    if not baseline then assert(renders['life.a'] == a and renders['life.b'] == b + 1) end
    view:ShowPage('life.a'); assert(view:ShowPreview('life.b', anchor))
    a = renders['life.a']
    core.Entry:HandleEntryClick('YiboCore', 'RightButton')
    print(target .. ': preview -> settings shortcut, previous page renders=' .. (renders['life.a'] - a))
    assert(view.activePageID == 'settings' and view.settingsTargetPageID == 'display')
    if not baseline then assert(renders['life.a'] == a) end
    -- Public close restores the normal page, and shell restoration happens once.
    view:ShowPage('life.a'); assert(view:ShowPreview('life.b', anchor))
    local layouts, apply = 0, view.ApplyNormalLayout
    view.ApplyNormalLayout = function(self, ...) layouts = layouts + 1; return apply(self, ...) end
    a = renders['life.a']; view:HidePreview()
    assert(view.frame:IsShown() and view.activePageID == 'life.a' and renders['life.a'] == a + 1)
    print(target .. ': close preview, normal shell layouts=' .. layouts)
    if not baseline then assert(layouts == 1) end
    -- Repeated Broker calls must not lose the main-window restoration state.
    assert(view:ShowPreview('life.b', anchor)); assert(view:ShowPreview('life.b', anchor))
    view:HidePreview()
    print(target .. ': repeated hover restores main=' .. tostring(view.frame:IsShown()))
    if not baseline then assert(view.frame:IsShown()) end
    view.frame:Show(); view:ShowPage('life.a'); assert(view:ShowPreview('life.b', anchor))
    core.Entry:HandleEntryClick('YiboCore', 'LeftButton')
    assert(not view.frame:IsShown(), 'Core toggle preserves its existing open-main behavior')
    assert(view:ShowPreview('life.b', anchor)); view:Toggle('life.a')
    assert(view.frame:IsShown() and not view.frame.preview and view.activePageID == 'life.a')
    -- A Broker retry scheduled before direct API navigation must not reopen hover.
    core.Entry.lastPreviewRenderAt = nil
    assert(core.Entry:ShowEntryPreview('YiboCore', anchor, 'broker'))
    assert(view.frame.preview)
    view:Toggle('life.b'); flush()
    if not baseline then assert(not view.frame.preview and view.activePageID == 'life.b' and not core.Entry.previewWatchActive) end
end
print('PASS: hosted callback lifetime, retained owner callbacks, preview navigation, public restoration and Core toggle')
