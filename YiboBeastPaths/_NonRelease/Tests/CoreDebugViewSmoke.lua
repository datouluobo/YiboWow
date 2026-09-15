-- Headless construction/refresh smoke test for the Core-hosted page.
local objects = {}
local function widget(parent)
    local object = { parent = parent, width = 760, height = 30, shown = true }
    setmetatable(object, { __index = function(self, key)
        if key == "preset" or key == "settingKey" or key == "exportKey" then return nil end
        if key == "GetParent" then return function() return rawget(self, "parent") end end
        if key == "GetWidth" then return function() return self.width end end
        if key == "GetHeight" then return function() return self.height end end
        if key == "IsShown" then return function() return self.shown end end
        if key == "SetShown" then return function(_, value) self.shown = value end end
        if key == "SetWidth" then return function(_, value) self.width = value end end
        if key == "SetHeight" then return function(_, value) self.height = value end end
        if key == "SetSize" then return function(_, width, height) self.width, self.height = width, height end end
        if key == "SetScript" then return function(_, event, fn) self[event] = fn end end
        if key == "SetText" then return function(_, value) self.text = value end end
        if key == "SetTexture" then return function(_, value) self.texture = value end end
        if key == "SetPoint" then return function(_, ...) self.point = { ... } end end
        if key == "ClearAllPoints" then return function() self.point = nil end end
        if key == "CreateFontString" then return function() return widget(self) end end
        if key == "CreateTexture" then return function() return widget(self) end end
        return function() end
    end })
    objects[#objects + 1] = object
    return object
end
CreateFrame = function(_, _, parent) return widget(parent) end

local theme = {
    Font = { section = 16, assist = 14 },
    Colors = { panel = { .1, .1, .1, 1 }, lineSoft = { .2, .2, .2, 1 },
        text = { 1, 1, 1, 1 }, muted = { .5, .5, .5, 1 }, row = { .1, .1, .1, 1 },
        bg = { 0, 0, 0, 1 } },
}
function theme:CreateText(parent) return widget(parent) end
function theme:CreateButton(parent, _, label)
    local button = widget(parent)
    button.text = label
    function button:SetText(value) self.text = value end
    function button:SetState(value) self.state = value end
    function button:SetEnabled(value) self.enabled = value end
    return button
end

_G.YiboCore = { UITheme = theme }
local selected, mapID = nil, nil
_G.YiboBeastPathsDebugDB = { ui = { activeTab = "calibrate", stepMove = .005,
    stepScale = .01, footprintListOffset = 0, exportView = "current" } }
local ybp = {}
_G.YiboBeastPaths = ybp
function ybp:GetActiveDebugTab() return _G.YiboBeastPathsDebugDB.ui.activeTab end
function ybp:SetActiveDebugTab(value) _G.YiboBeastPathsDebugDB.ui.activeTab = value; self:RefreshDebugPanel() end
function ybp:GetDebugPetIDsForCurrentMap() return mapID and { 376 } or {} end
function ybp:GetSelectedDebugPetID() return selected end
function ybp:GetCurrentWorldMapID() return mapID end
function ybp:GetPetIndexInCurrentMap() return 1 end
function ybp:GetResolvedTransform() return { offsetX = 0, offsetY = 0, scale = 1, opacity = 1 } end
function ybp:GetDebugRouteThickness() return 1.5 end
function ybp:GetDebugExportView() return _G.YiboBeastPathsDebugDB.ui.exportView end
function ybp:GetDebugExportText() return "export-text" end
function ybp:GetDebugMinimapTransform() return nil end
function ybp:GetFootprintStore() return { points = {} } end
function ybp:GetRouteDisplaySettings() return { showResolved = true } end
local ns = { pets = { [376] = { name = "测试宠物", zone = "测试地图" } },
    routeNodeTooltips = { [376] = { imageTexture = "test-pet-texture" } } }
local chunk = assert(loadfile("YiboBeastPaths/Maintenance/CoreDebugView.lua"))
chunk("YiboBeastPaths", ns)
local page = widget()
page:SetWidth(792)
local scroll = widget(page)
local parent = widget(scroll)
local panel = assert(ybp:CreateCoreDebugPanel(parent))
assert(panel:GetHeight() > 360)
assert(#panel.tabs.calibrate.groups == 5)
assert(panel.tabs.calibrate.groups[1].title.text == "调节步进")
assert(panel.tabs.calibrate.groups[2].title.text == "大地图路线")
assert(#panel.tabs.fusion.groups == 5)
assert(#panel.tabs.footprints.rows == 6)
assert(panel.tabs.export.box)
assert(not panel.petIconFrame:IsShown())
local actionCount = 0
for _, tab in pairs(panel.tabs) do
    for _, group in ipairs(tab.groups) do
        for _, button in ipairs(group.buttons) do
            assert(type(button.OnClick) == "function", button.text or "button")
            actionCount = actionCount + 1
        end
    end
end
for _, button in pairs(panel.tabButtons) do assert(type(button.OnClick) == "function"); actionCount = actionCount + 1 end
for _, row in ipairs(panel.tabs.footprints.rows) do
    assert(row.toggle and row.delete)
    actionCount = actionCount + 2
end
assert(actionCount >= 90, actionCount)
for _, width in ipairs({ 760, 620, 600 }) do
    panel:SetWidth(width)
    ybp:RefreshDebugPanel()
    for _, tab in pairs(panel.tabs) do
        assert(tab.frame:GetWidth() == width - 24)
        for _, group in ipairs(tab.groups) do
            for _, button in ipairs(group.buttons) do
                assert(button:GetWidth() >= 80 and button:GetWidth() <= 176)
                assert(button.point[2] + button:GetWidth() <= group.frame:GetWidth() - 12)
            end
        end
    end
    local firstRow = panel.tabs.calibrate.groups[2].buttons
    assert(firstRow[1].point[3] == firstRow[6].point[3], width)
    assert(firstRow[6].point[2] + firstRow[6]:GetWidth() == width - 52, width)
    local lastTab = panel.tabButtons.export
    local card = panel.tabs.export.groups[1].frame
    assert(math.abs((lastTab.point[2] + lastTab:GetWidth()) - (16 + card:GetWidth())) < .001, width)
end
panel:SetWidth(760)
ybp:RefreshDebugPanel()
local fixedTabWidth = panel.tabButtons.calibrate:GetWidth()
panel:SetWidth(776) -- Core's 16px gutter is released on a short page.
ybp:RefreshDebugPanel()
for _, button in pairs(panel.tabButtons) do assert(button:GetWidth() == fixedTabWidth) end
panel:SetWidth(760)
ybp:RefreshDebugPanel()
local mapButtons = panel.tabs.calibrate.groups[2].buttons
assert(mapButtons[1].point[3] == mapButtons[6].point[3])
assert(mapButtons[7].point[3] ~= mapButtons[6].point[3])
for _, tab in ipairs({ "calibrate", "fusion", "footprints", "export" }) do
    ybp:SetActiveDebugTab(tab)
    assert(panel.tabs[tab].frame:IsShown())
    assert(panel:GetHeight() > 360)
    assert(parent:GetHeight() == panel:GetHeight())
end
mapID, selected = 376, 376
ybp:RefreshDebugPanel()
assert(panel.summary.text and panel.summary.text:find("测试宠物"))
assert(panel.petIconFrame:IsShown())
assert(panel.petIcon.texture == "test-pet-texture")
for _, width in ipairs({ 900, 760, 600 }) do
    panel:SetWidth(width)
    ybp:RefreshDebugPanel()
    local previous, nextButton, count = panel.previous, panel.next, panel.routeCount
    assert(previous.point[2] == nextButton.point[2] and nextButton.point[2] == count.point[2])
    assert(previous.point[3] < 0 and nextButton.point[3] < previous.point[3]
        and count.point[3] < nextButton.point[3])
    assert(previous:GetWidth() == nextButton:GetWidth() and count:GetWidth() == previous:GetWidth())
    assert(panel.petIconFrame.point[2] == panel.tabButtons.calibrate.point[2]
        and panel.petIconFrame.point[3] == -8)
    assert(count.point[2] + count:GetWidth() == width - 24)
    assert(panel.summary.point[2] + panel.summary:GetWidth() <= previous.point[2] - 12)
    assert(panel.petIconFrame.point[3] == previous.point[3])
    assert(panel.petIconFrame:GetHeight() == panel.summary:GetHeight())
    assert(-count.point[3] + count:GetHeight()
        == -panel.petIconFrame.point[3] + panel.petIconFrame:GetHeight())
    assert(panel.summary.point[3] == previous.point[3])
    assert(-panel.tabButtons.calibrate.point[3]
        - (-count.point[3] + count:GetHeight()) == 12)
end
print("CoreDebugView smoke: 4 tabs, " .. actionCount .. " actions, empty context and selected pet OK")
