-- Real Core account shell across the shipping targets and both session languages.
local Boot = dofile('_NonRelease/CoreRetailR2/Harness.lua')
local checks = 0
local function Check(value, label)
    checks = checks + 1
    assert(value, label)
end

for _, target in ipairs({ 'Forever', 'Mists', 'Retail' }) do
    for _, language in ipairs({ 'zhCN', 'enUS' }) do
        local cursorX, cursorY = 0, 0
        local function Configure(e)
            e.GetLocale = function() return language end
            e.GetCursorPosition = function() return cursorX, cursorY end
            e.UIParent:SetSize(1280, 720)
            local frame = getmetatable(e.UIParent).__index
            frame.GetRegions = function() end
        end
        local env, core, event, flush = Boot(target, nil, nil, Configure, nil, target == 'Forever' and arg and arg[1] or nil,
            target == 'Forever' and arg and arg[1] and 'YiboCore.toc' or nil)
        event('ADDON_LOADED'); event('PLAYER_LOGIN'); flush()
        local view, theme = core.AccountView, core.UITheme
        local function Paint(parent, context)
            parent.surfaceWidth, parent.surfaceHeight = context.surfaceAvailableWidth, context.surfaceAvailableHeight
        end
        local columnCount = 8
        for n = 1, 16 do
            local owner = 'LayoutFixture' .. n
            Check(core:RegisterAddon(owner, { requiredAPI = 13 }), 'fixture owner')
            Check(view:RegisterPage(owner, {
                id = 'layout.' .. n, title = 'Layout ' .. n,
                columnPager = n == 2,
                Create = function() end, Refresh = n == 2 and function(parent, context)
                    Paint(parent, context)
                    local columns = {}
                    for index = 1, columnCount do columns[index] = index end
                    local width = context.surfaceAvailableHeight >= 480 and 4 or 3
                    local _, info = view:GetColumnPage('layout.2', 'fields', columns, width, 0, 1, 1)
                    view:UpdateColumnPager(parent, 'layout.2', 'fields', info, parent)
                end or n == 3 and function(parent, context)
                    parent.columns, parent.slice = view:GetColumnPageByWidth('layout.3', 'fields',
                        { 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h' }, context.surfaceAvailableWidth, 100,
                        function() return 100 end)
                end or Paint,
                GetSurfaceMetrics = n == 1 and function()
                    return { minContentWidth = 880, minContentHeight = 560, naturalContentWidth = 1200 }
                end or function() return { minContentWidth = 120, minContentHeight = 120 } end,
            }), 'fixture page')
        end

        local settings = view:GetSettings()
        settings.width, settings.height = 1190, 690
        settings.pageSizes['characters:default'] = { width = 960, height = 350 }
        settings.pageSizes['layout.1:default'] = { width = 1100, height = 650 }
        view:Toggle('characters'); flush()
        local frame = view.frame
        local function Fixed(label)
            Check(frame:GetWidth() == 800 and frame:GetHeight() == 544, label)
        end
        Fixed('archive uses the common shell')
        local archive = frame.instances.characters
        local budget = frame:GetWidth() - frame.nav:GetWidth() - 3
        Check(not archive.listHeader:IsShown() or archive.listHeader:GetWidth() <= budget, 'archive fields fit their paginated viewport')
        local navWidth = frame.nav:GetWidth()
        local count = 0
        for _, button in ipairs(frame.navButtons) do if button:IsShown() then count = count + 1 end end
        Check(count == 21, 'main navigation retains every route')
        Check(frame.navScroll.contentHeight > frame:GetHeight() - theme.Geometry.titleBar, 'navigation can scroll past one screen')
        Check(frame.navButtons[count].pageID == 'about', 'about remains last navigation item')

        local setSize, writes = frame.SetSize, 0
        frame.SetSize = function(self, ...)
            writes = writes + 1
            return setSize(self, ...)
        end

        view:ShowPage('layout.1'); flush()
        Fixed('wide business page uses the same shell')
        local instance = frame.instances['layout.1']
        Check(frame.pageViewport.instance == instance and frame.pageViewport.horizontal:IsShown(), 'wide controls get a horizontal viewport')
        Check(instance.surfaceWidth == 880 and instance.surfaceHeight == 560, 'business page still receives its declared minimum content size')
        frame.pageViewport.horizontal:SetValue(120)
        local _, _, _, offset = instance:GetPoint(1)
        Check(offset == -120, 'slider exposes the right side of the page')
        view:RefreshPage()
        Check(frame.pageViewport.offset == 120, 'ordinary refresh keeps horizontal reading position')
        view:ShowPage('layout.2')
        Fixed('regular business page uses the same shell')
        Check(not frame.pageViewport:IsShown() and instance:GetParent() == frame.content, 'overflow viewport detaches cleanly')
        Check(frame.instances['layout.2'].surfaceWidth == budget, 'regular business page receives the actual pane width')
        local paged = frame.instances['layout.2']
        local _, _, _, _, bottomInset = paged:GetPoint(2)
        Check(frame.columnPagerFooter:IsShown() and paged.yiboColumnPager.next:GetParent() == frame.columnPagerFooter,
            'column pager lives in the Core footer')
        Check(bottomInset == theme.Size.compact + theme.Space.xs, 'page content stops above the pager')
        local pagedHeight = paged.surfaceHeight
        paged.yiboColumnPager.next:GetScript('OnClick')()
        Check(settings.columnPages['layout.2'].fields == 2,
            'next keeps the selected page when the footer changes the column count')
        columnCount = 4
        view:RefreshPage()
        local _, _, _, _, singleInset = paged:GetPoint(2)
        Check(not frame.columnPagerFooter:IsShown() and singleInset == 0
            and paged.surfaceHeight == pagedHeight + bottomInset, 'single page gets the entire pager height back')
        columnCount = 8
        view:RefreshPage()
        Check(frame.columnPagerFooter:IsShown() and paged.surfaceHeight == pagedHeight,
            'bringing back the pager restores the previous data height')

        for _, section in ipairs({ 'general', 'core', 'sorting', 'bar', 'display' }) do
            view:ShowSettings(section)
            view:ShowPage('settings'); flush()
            Fixed('settings share the same shell')
            Check(not frame.columnPagerFooter:IsShown(), 'settings hide the previous page pager')
            local page = frame.instances.settings
            Check(page.content:GetWidth() < budget and page.settingsContentHeight > 0, 'settings fit and measure the actual content pane')
            local _, _, _, _, top = page.scroll:GetPoint(1)
            Check(top == -42, 'settings viewport follows the single heading row')
            Check(frame.nav:GetWidth() == navWidth, 'switching navigation groups keeps the left divider fixed')
        end
        view:ShowPage('about'); flush()
        view:ShowPage('help'); flush()
        view:ShowPage('overview'); flush()
        Fixed('built-in pages share the same shell')
        Check(writes == 0, 'normal page, settings and refresh routes never resize the shell')
        Check(settings.width == 1190 and settings.height == 690 and settings.pageSizes['layout.1:default'].width == 1100,
            'older saved sizes are kept for rollback')

        local padding = theme.Geometry.compactColumnInset * 2 + theme.Geometry.compactColumnTolerance
        local textWidth = theme:MeasureText(theme.Font.body, 'Sample')
        Check(theme:GetCompactColumnWidth('', { 'Sample', '?' }) == textWidth + padding, 'status columns measure only displayed values')
        Check(theme:GetCompactColumnWidth('', { 'Sample' }, 16) == textWidth + 16 + theme.Table.iconTextGap + padding,
            'icon-text columns reserve one icon and one gap')

        local function SizeIs(width, height)
            return frame:GetWidth() == width and frame:GetHeight() == height
        end
        local _, _, _, anchorX, anchorY = frame:GetPoint(1)
        local function SameAnchor()
            local point, _, relative, x, y = frame:GetPoint(1)
            return point == 'TOPLEFT' and relative == 'TOPLEFT' and x == anchorX and y == anchorY
        end
        view:ShowSettings('core')
        local widthInput = frame.instances.settings.rows[1].input
        widthInput:SetFocus()
        widthInput:InputText('960')
        view:RefreshPage()
        Check(widthInput:GetText() == '960' and SizeIs(800, 544), 'refresh preserves a draft without applying it')
        widthInput:Fire('OnEnterPressed')
        Check(SizeIs(960, 544) and SameAnchor(), 'Enter applies width only from the same top-left')
        Check(view:SetWindowDimension('height', '600') and SizeIs(960, 600) and SameAnchor(), 'height applies independently')
        Check(not view:SetWindowDimension('width', '5000') and SizeIs(960, 600), 'invalid sizes are rejected')
        view:ShowPage('layout.1')
        view:ShowSettings('display')
        view:ShowSettings('core')
        view:RefreshPage()
        Check(SizeIs(960, 600) and SameAnchor() and frame.nav:GetWidth() == navWidth,
            'page and settings refreshes keep size, anchor, and navigation width')
        settings.entry.showPreviewWhileMainWindowOpen = true
        Check(view:ShowPreview('overview') and not frame.resizeGrip:IsShown(), 'preview owns its own geometry and omits the grip')
        view:HidePreview()
        Check(SizeIs(960, 600) and SameAnchor() and frame.resizeGrip:IsShown(), 'return from preview restores the custom size')

        view:SetWindowAspectLocked(true)
        Check(SizeIs(960, 600) and SameAnchor(), 'enabling the ratio does not resize')
        Check(view:SetWindowDimension('width', '880') and SizeIs(880, 550) and SameAnchor(), 'locked width changes height')
        Check(view:SetWindowDimension('width', '887') and SizeIs(887, 554), 'rounding the locked height does not shrink the edited width')
        view:RefreshPage()
        Check(SizeIs(887, 554) and SameAnchor(), 'locked sizes do not drift after refresh')
        Check(view:SetWindowDimension('height', '600') and SizeIs(960, 600) and SameAnchor(), 'locked height changes width')
        view:SetWindowAspectLocked(false)
        view:ResetWindowSize()
        Check(SizeIs(800, 544) and SameAnchor(), 'restoring only the size preserves the anchor')

        view:ShowPage('layout.3')
        view:SetColumnPage('layout.3', 'fields', 2, 2)
        local matrix = frame.instances['layout.3']
        local firstVisible = matrix.columns[1]
        Check(matrix.slice.page == 2 and firstVisible ~= 'a', 'matrix starts on its manually selected page')
        Check(view:SetWindowDimension('width', '960'), 'matrix width updates')
        local found
        for _, column in ipairs(matrix.columns) do if column == firstVisible then found = true end end
        Check(found and matrix.slice.page == 1, 'resized column pages keep the previous leading column visible')
        view:ResetWindowSize()

        local grip = frame.resizeGrip
        grip:Fire('OnDragStart')
        cursorX, cursorY = 160, -40
        frame:Fire('OnUpdate', 0.06)
        Check(SizeIs(960, 584) and SameAnchor() and grip.readout:IsShown(), 'drag updates geometry live from the same top-left')
        view:RefreshPage()
        Check(SizeIs(960, 584) and settings.windowSize.width == nil, 'refresh does not replace or commit the active drag')
        grip:Fire('OnDragStop')
        Check(SizeIs(960, 584) and settings.windowSize.width == 960 and settings.windowSize.height == 584
            and not grip.readout:IsShown(), 'drag release commits one shared size')

        settings.x, settings.y = 32, -92
        view:RefreshWindowLayout()
        view:ResetWindowLayout()
        Check(SizeIs(960, 584) and SameAnchor(), 'resetting position preserves the saved size')
        view:Toggle()
        view:Toggle('overview')
        Check(SizeIs(960, 584) and SameAnchor(), 'close and reopen preserve the custom size')

        env.UIParent:SetSize(700, 500)
        event('DISPLAY_SIZE_CHANGED'); flush()
        Check(frame:GetWidth() < 800 and frame:GetHeight() < 544, 'small screens cap the common outer dimensions')
        Check(settings.windowSize.width == 960 and settings.windowSize.height == 584, 'screen clamping leaves the custom preference intact')
        env.UIParent:SetSize(1280, 720)
        event('DISPLAY_SIZE_CHANGED'); flush()
        Check(SizeIs(960, 584) and SameAnchor(), 'available space restores the preferred size')

        local _, reloaded, reloadEvent, reloadFlush = Boot(target, core.Database:GetDB(), nil, Configure)
        reloadEvent('ADDON_LOADED'); reloadEvent('PLAYER_LOGIN'); reloadFlush()
        reloaded.AccountView:Toggle('overview')
        Check(reloaded.AccountView.frame:GetWidth() == 960 and reloaded.AccountView.frame:GetHeight() == 584,
            'loading existing SavedVariables restores the last committed size')
    end
end

print('PASS unified account shell: ' .. checks .. ' checks across three targets and two languages')
