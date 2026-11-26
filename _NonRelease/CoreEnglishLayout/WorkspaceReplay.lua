local Harness = dofile("_NonRelease/BusinessReleaseHarness-20261122/Harness.lua")
local dual = { "YiboAltoBoss", "YiboAutoOpen", "YiboBuilds", "YiboCrafting", "YiboCurrency", "YiboMail", "YiboQuestBlocker", "YiboReputation", "YiboVault" }
local mists = { "YiboMounts", "YiboLegendary", "YiboTaskHub", "YiboTodo" }

local function Configure(env)
    env.Enum = env.Enum or {}
    env.Enum.QuestFrequency = { Default = 0, Daily = 1, Weekly = 2, ResetByScheduler = 3 }
    env.C_QuestLog.GetInfo = function() end
    env.C_QuestLog.IsComplete = function() return false end
    env.C_QuestLog.IsRepeatableQuest = function() return false end
    env.C_QuestLog.IsOnQuest = function() return false end
    env.C_QuestLog.GetTitleForQuestID = function() end
    env.GetQuestID = function() end
    env.GetTitleText = function() end
    env.UIParent:SetSize(1280, 720)
    env.UnitLevel = function() return 90 end
    local methods = getmetatable(env.UIParent).__index
    methods.SetInventoryItem = function() return false end
    methods.HasFocus = function(self) return self.focused == true end
    methods.Disable = function(self) self:SetEnabled(false) end
    methods.Enable = function(self) self:SetEnabled(true) end
    function methods:IsEnabled() return self.enabled ~= false end
    local create = env.CreateFrame
    function env.CreateFrame(...)
        local frame = create(...)
        frame.enabled = nil
        return frame
    end
    local texture, fontString = methods.CreateTexture, methods.CreateFontString
    local function Region(createRegion, self, ...)
        local region = createRegion(self, ...)
        self.regions = self.regions or {}
        self.regions[#self.regions + 1] = region
        return region
    end
    function methods:CreateTexture(...) return Region(texture, self, ...) end
    function methods:CreateFontString(...) return Region(fontString, self, ...) end
    function methods:GetRegions() return unpack(self.regions or {}) end
    env.C_Map.GetMapChildrenInfo = function() return {} end
    env.C_Map.GetMapInfo = function() return nil end
    env.CreateVector2D = function(x, y)
        return { x = x, y = y, GetXY = function(self) return self.x, self.y end,
            SetXY = function(self, newX, newY) self.x, self.y = newX, newY end }
    end
end

local function Run(target, language)
    local addons = {}
    if target ~= "Retail" then
        for _, name in ipairs(dual) do
            addons[#addons + 1] = { root = name, name = name, manifest = name .. "_" .. target .. ".toc" }
        end
    end
    if target == "Mists" then
        for _, name in ipairs(mists) do addons[#addons + 1] = { root = name, name = name } end
    end
    local session = Harness.Boot({
        client = target, coreRoot = "YiboCore", addons = addons, locale = language, configure = Configure,
        coreManifest = "YiboCore_" .. (target == "Retail" and "Mainline" or target) .. ".toc",
    })
    local core, env = session.Core, session.env
    if target ~= "Forever" then
        local namespace = { YBP_TARGET_OK = true }
        -- Load the offline page directly. The universal bundle also has a game-only tracker.
        for _, name in ipairs({ "OfflinePetSnapshot", "OfflinePetCoreGate", "OfflinePetPage", "OfflinePetRenderer" }) do
            local chunk = assert(loadfile("YiboBeastPaths/Common/" .. name .. ".lua"))
            setfenv(chunk, env)
            chunk("YiboBeastPaths", namespace)
        end
        assert(core:RegisterAddon("YiboBeastPaths", { requiredAPI = 13 }))
        local function Text(key) return key end
        assert(namespace.OfflinePetPage.New(core, {}, target, namespace.CreateOfflinePetRenderer(core, Text), Text):Start())
    end

    local view = core.AccountView
    view:Toggle("overview")
    local frame = view.frame
    local pages = {}
    for id in pairs(view._pages) do if id ~= "settings" then pages[#pages + 1] = id end end
    table.sort(pages)
    local expectedWidth, expectedHeight = 800, 544
    local function CheckVisit(route, id, notices)
        local label = string.format("%s %s %d×%d %s", target, language, expectedWidth, expectedHeight, route)
        assert(view.activePageID == id, label .. " route")
        assert(frame:GetWidth() == expectedWidth and frame:GetHeight() == expectedHeight, label .. " window size")
        local host = frame.pageViewport
        if host and host:IsShown() then
            assert(expectedWidth < 800 and host.instance == frame.instances[id] and not host.horizontal:IsShown(),
                label .. " overflow")
        end
        assert(#env.TEST_MESSAGES == notices, label .. " " .. tostring(env.TEST_MESSAGES[notices + 1]))
    end
    local function VisitPage(id)
        local notices = #env.TEST_MESSAGES
        view:ShowPage(id)
        CheckVisit(id, id, notices)
    end
    for _, id in ipairs(pages) do VisitPage(id) end

    local settings = { "general", "core", "sorting", "bar", "display" }
    for _, page in ipairs(view:GetRegisteredPages()) do
        if not page.internal then settings[#settings + 1] = page.id end
    end
    for _, panel in ipairs(core:GetRegisteredSettingsPanels()) do
        settings[#settings + 1] = "addon-settings:" .. panel.id
    end
    for _, id in ipairs(settings) do
        local notices = #env.TEST_MESSAGES
        view:ShowSettings(id)
        CheckVisit("settings/" .. id, "settings", notices)
    end

    if target == "Mists" then
        local builds, taskHub, mail = env.YiboBuilds, env.YiboTaskHub, env.YiboMail
        local snapshot, calls = taskHub.Snapshot.Build, 0
        taskHub.Snapshot.Build = function(...)
            calls = calls + 1
            return snapshot(...)
        end
        VisitPage("taskhub")
        assert(calls == 2, "TaskHub batches scope admission and shares the rendered snapshot with measurement")
        taskHub.Snapshot.Build = snapshot
        local hasCapability = core.HasCapability
        core.HasCapability = function(self, name, minimum)
            if name == "account-surface-realm-scope" then return minimum <= 1 end
            return hasCapability(self, name, minimum)
        end
        assert(not taskHub.CoreIntegration:CheckCore(), "TaskHub requires the batch realm-scope contract")
        core.HasCapability = hasCapability
        for _, id in ipairs({ "legendary", "addon-settings:mounts" }) do
            view:ShowSettings(id)
            local objects = #env.TEST_FRAMES
            for _ = 1, 20 do view:RefreshPage() end
            assert(#env.TEST_FRAMES == objects, id .. " settings reuse controls on refresh")
        end
        VisitPage("alto-lockouts")
        local lockouts = frame.instances["alto-lockouts"]
        local filters = lockouts.lockoutFilters
        local _, _, _, _, filterY = filters:GetPoint(1)
        local tabHeight = env.YAB.GetBusinessTabHeight()
        local expectedFilterY = language == "zhCN" and -(tabHeight - core.UITheme.Size.standard) / 2
            or -tabHeight - core.UITheme.Space.xxs
        assert(filters:IsShown() and filterY == expectedFilterY,
            "lockout filters share the tabs when they fit and move together to a second row otherwise")
        for index, count in ipairs({ 6, 9, 9 }) do
            local notices = #env.TEST_MESSAGES
            local button = assert(filters.kind.menu.buttons[index + 1])
            button:GetScript("OnClick")(button)
            CheckVisit("lockouts/" .. button.option.value, "alto-lockouts", notices)
            local shown, pager = 0, lockouts.yiboColumnPager
            repeat
                for column = 2, #lockouts.headers do
                    if lockouts.headers[column]:IsShown() then shown = shown + 1 end
                end
                assert(shown <= count, "dungeon pages do not overrun the category")
                if not pager.next:IsShown() or pager.next.state == "disabled" then break end
                pager.next:GetScript("OnClick")(pager.next)
                CheckVisit("lockouts next", "alto-lockouts", notices)
            until shown == count
            assert(shown == count,
                string.format("%s Pandaria difficulty %s displays %d of %d dungeon columns",
                    language, button.option.value, shown, count))
        end
        local header = lockouts.headers[1]
        VisitPage("alto-lockouts")
        assert(lockouts.headers[1] == header, "lockout refresh reuses rendered headers")
        local current = assert(core.Characters:GetCurrent({ identityOnly = true }))
        local record = builds.Snapshot:EnsureCharacter(current)
        record.lastActiveSlot = "primary"
        local slot = record.slots.primary
        slot.observedEquipment = { slots = {
            [tostring(env.INVSLOT_HEAD or 1)] = { gems = { { socketType = "red" } }, enchant = { state = "uninstalled" } },
        } }
        VisitPage(builds.PAGE_ID)
        local instance = frame.instances[builds.PAGE_ID]
        assert(instance.buildsCompact and instance.buildsEquipment:IsShown() and not instance.buildsBuild:IsShown())
        local equipment = instance.buildsEquipment
        local head, wrist = equipment.items[env.INVSLOT_HEAD or 1], equipment.items[env.INVSLOT_WRIST or 9]
        local weapon = equipment.items[env.INVSLOT_MAINHAND or 16]
        local _, _, _, _, wristY = wrist:GetPoint(1)
        local _, _, _, _, weaponY = weapon:GetPoint(1)
        assert(equipment.layoutHeight + wristY - wrist:GetHeight() > weaponY + weapon:GetHeight(),
            "last side slot has clearance above the weapons")
        assert(head.gems[1]:IsShown() and head.enchant:IsShown()
            and head.gems[1]:GetHeight() + head.enchant:GetHeight() < head:GetHeight(),
            "the socket and enhancement tracks fit the equipment slot height")
        local _, saveAnchor = instance.buildsConfirm:GetPoint(1)
        assert(instance.buildsConfirm:IsShown() and saveAnchor == instance.buildsToolbar,
            "pending equipment exposes a toolbar action")
        slot.confirmedEquipment = slot.observedEquipment
        local previousHeight = equipment.layoutHeight
        VisitPage(builds.PAGE_ID)
        assert(not instance.buildsConfirm:IsShown() and equipment.layoutHeight == previousHeight,
            "equipment height stays stable when the save action is no longer needed")
        local toggle = instance.buildsToolbar.buildToggle
        for _, pane in ipairs({ "build", "equipment" }) do
            local notices = #env.TEST_MESSAGES
            toggle:GetScript("OnClick")(toggle)
            CheckVisit("builds/" .. pane, builds.PAGE_ID, notices)
            assert(instance.buildsEquipment:IsShown() == (pane == "equipment"))
            assert(instance.buildsBuild:IsShown() == (pane == "build"))
        end
        local settings = builds:GetSettings()
        settings.previewMatrixMode, settings.previewEquipmentMode, settings.previewSpecMode = "equipment", false, "backup"
        frame:Hide()
        assert(view:ShowPreview(builds.PAGE_ID), "Builds hover opens")
        local modes = instance.buildsPreviewToggle.buttons
        assert(modes[1].state == "selected" and settings.previewSpecMode == "backup",
            "legacy equipment settings do not inherit the backup specialization")
        modes[2]:GetScript("OnClick")(modes[2])
        assert(modes[2].state == "selected", "explicit backup equipment mode remains available")
        modes[4]:GetScript("OnClick")(modes[4])
        assert(modes[4].state == "selected" and settings.previewEquipmentMode == "backup",
            "specialization mode keeps the independent equipment preference")
        view:Toggle(builds.PAGE_ID)
        for _, tab in ipairs({ "goals", "targets", "overview" }) do
            taskHub.AccountPage.activeTab = tab
            VisitPage(taskHub.PAGE_ID)
        end
        for _, tab in ipairs({ "overview", "history", "inbox" }) do
            mail.WorkspaceState:Get().tab = tab
            VisitPage(mail.AccountPage.ID)
        end
        local todo = env.YiboTodo
        for _, group in ipairs({ "farm", "nomi", "jewelcrafting-daily", "cooking-daily",
            "fishing-daily", "nat-pagle", "brilltron-4000" }) do
            todo.Settings:SetMonitoringGroupEnabled(group, true, true)
        end
        VisitPage("todo")
        local taskTable = frame.instances.todo
        local row = assert(taskTable.rows[1], "Todo displays the current role")
        local visibleHeaders = 0
        for index, header in ipairs(taskTable.headers) do
            if header:IsShown() then
                visibleHeaders = visibleHeaders + 1
                if index > 1 then
                    assert(row.cells[index - 1]:IsShown(), "Todo project cell matches the shown header")
                    assert(row.cells[index - 1]:GetWidth() == header:GetWidth(), "Todo project cell and header share width")
                end
            end
        end
        assert(visibleHeaders > 1, "Todo displays project columns")
    end
    local navWidth = frame.nav:GetWidth()
    for _, size in ipairs({ { 960, 544 }, { 960, 600 }, { 736, 544 } }) do
        expectedWidth, expectedHeight = size[1], size[2]
        assert(view:SetWindowDimension("width", expectedWidth) and view:SetWindowDimension("height", expectedHeight))
        for _, id in ipairs(pages) do VisitPage(id) end
        for _, id in ipairs(settings) do
            local notices = #env.TEST_MESSAGES
            view:ShowSettings(id)
            CheckVisit("settings/" .. id, "settings", notices)
        end
        assert(frame.nav:GetWidth() == navWidth, "resizing keeps the navigation divider fixed")
    end
    print(string.format("%s %s: %d main routes, %d settings routes%s",
        target, language, #pages, #settings, target == "Mists" and ", Builds/TaskHub/Mail/Todo subviews" or ""))
end

for _, target in ipairs({ "Mists", "Forever", "Retail" }) do
    for _, language in ipairs({ "zhCN", "enUS" }) do Run(target, language) end
end
