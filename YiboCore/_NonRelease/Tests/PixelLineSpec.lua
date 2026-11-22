-- Offline contract for API 14 / pixel-line:1.  Run from the repository root:
--   lua YiboCore/_NonRelease/Tests/PixelLineSpec.lua
local checks = 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
local function Near(a, b) return type(a) == "number" and math.abs(a - b) < 1e-9 end

-- Minimal region model: records the calls the pixel-line contract relies on.
local uiScale, physical = 1, { 1920, 1080 }
local Methods = {}
-- Unknown widget methods (capitalised) are no-ops; unknown fields stay nil.
local RegionMT = { __index = function(_, key)
    if Methods[key] then return Methods[key] end
    if type(key) == "string" and key:match("^%u") then return function() end end
end }
local function NewRegion(kind, parent)
    return setmetatable({ kind = kind, parent = parent, points = {}, textures = {}, shown = true }, RegionMT)
end
function Methods:CreateTexture() local texture = NewRegion("Texture", self); self.textures[#self.textures + 1] = texture; return texture end
function Methods:CreateFontString() return NewRegion("FontString", self) end
function Methods:SetHeight(value) self.height = value end
function Methods:SetWidth(value) self.width = value end
function Methods:SetPoint(...) self.points[#self.points + 1] = { ... } end
function Methods:ClearAllPoints() self.points = {} end
function Methods:SetColorTexture(...) self.color = { ... } end
function Methods:SetShown(shown) self.shown = shown and true or false end
function Methods:Show() self.shown = true end
function Methods:Hide() self.shown = false end
function Methods:IsShown() return self.shown end
function Methods:GetFrameLevel() return 1 end
function Methods:GetEffectiveScale() return uiScale end
function Methods:SetBackdrop(info) self.backdrop = info; self.backdropCount = (self.backdropCount or 0) + 1; self.fill, self.border = { 1, 1, 1, 1 }, { 1, 1, 1, 1 } end
function Methods:SetBackdropColor(...) self.fill = { ... } end
function Methods:GetBackdropColor() return unpack(self.fill) end
function Methods:SetBackdropBorderColor(...) self.border = { ... } end
function Methods:GetBackdropBorderColor() return unpack(self.border) end
local function Point(region, name)
    for _, point in ipairs(region.points) do if point[1] == name then return point end end
end

_G.CreateFrame = function(kind, _, parent) return NewRegion(kind, parent) end
_G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
_G.GetPhysicalScreenSize = function() return physical[1], physical[2] end
local timers = {}
_G.C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
_G.WOW_PROJECT_ID, _G.WOW_PROJECT_MISTS_CLASSIC = 19, 19

_G.YiboCore = {}
dofile("YiboCore/Bootstrap.lua")
local Core = _G.YiboCore
dofile("YiboCore/Mists/Target.lua")
dofile("YiboCore/Runtime/Capabilities.lua")
dofile("YiboCore/Runtime/Events.lua")
dofile("YiboCore/Runtime/Client.lua")
dofile("YiboCore/Common/ClientSurface.lua")
dofile("YiboCore/Mists/Surface.lua")
Core.Locale = { Bind = function(_, factory) return setmetatable({}, { __index = function(_, key) return factory()[key] end }) end }
Core.Text = function(_, key) return key end
dofile("YiboCore/UI/Theme.lua")
local Theme = Core.UITheme

-- Version and capability.
Check(Core:CheckAPIVersion(14) == true, "Core publishes API 14")
Check(Core:HasCapability("pixel-line", 1), "pixel-line:1 is registered")

-- Conversion: N pixels = N x 768 / physical height / effective scale.
local frame = CreateFrame("Frame")
local cases = {
    { 1280, 720, 1.00 }, { 1920, 1080, 1.00 }, { 1920, 1080, 0.80 }, { 1920, 1080, 0.64 },
    { 2560, 1440, 1.00 }, { 2560, 1440, 0.71 }, { 2560, 1440, 1.15 },
}
for _, case in ipairs(cases) do
    physical, uiScale = { case[1], case[2] }, case[3]
    Theme:RefreshPixelLines()
    local expected = 768 / case[2] / case[3]
    Check(Near(Theme:GetPixelSize(frame), expected), "1 px at " .. case[2] .. "p scale " .. case[3])
    Check(Near(Theme:GetPixelSize(frame, 2), expected * 2), "2 px is exactly twice 1 px")
    local snapped = Theme:SnapToPixel(frame, 28.37)
    local pixels = snapped * case[2] / 768 * case[3]
    Check(math.abs(pixels - math.floor(pixels + 0.5)) < 1e-6, "snapped value lies on the pixel grid")
end
Check(Theme:GetPixelMetricsState() == "known", "valid physical size is known")

-- Unknown and malformed physical sizes keep the former 1 UI unit.
for _, bad in ipairs({ { nil, nil }, { 1920, 0 }, { 1920, 1080.5 }, { "1920", "1080" } }) do
    physical = bad
    Theme:RefreshPixelLines()
    Check(Theme:GetPixelSize(frame) == 1, "unreadable size falls back to 1 UI unit")
    Check(Theme:GetPixelSize(frame, 2) == 2, "fallback keeps the requested pixel count")
    Check(Theme:SnapToPixel(frame, 28.37) == 28.37, "fallback does not move layout")
    Check(Theme:GetPixelMetricsState() == "unknown", "fallback is reported as unknown")
end
_G.GetPhysicalScreenSize = function() error("not ready") end
Theme:RefreshPixelLines()
Check(Theme:GetPixelSize(frame) == 1, "API error falls back without raising")
_G.GetPhysicalScreenSize = function() return physical[1], physical[2] end

-- Pixel backdrop: edge size follows the scale; colours survive a refresh.
physical, uiScale = { 1920, 1080 }, 1
Theme:RefreshPixelLines()
local box = CreateFrame("Frame")
Theme:ApplyPixelBackdrop(box)
Check(Near(box.backdrop.edgeSize, 768 / 1080) and box.backdrop.bgFile ~= nil, "backdrop edge is one physical pixel")
box:SetBackdropColor(0.1, 0.2, 0.3, 0.4); box:SetBackdropBorderColor(0.5, 0.6, 0.7, 0.8)
Theme:RefreshPixelLines()
Check(box.backdropCount == 1, "unchanged pixel size does not rebuild the backdrop")
physical = { 2560, 1440 }
Theme:RefreshPixelLines()
Check(Near(box.backdrop.edgeSize, 768 / 1440) and box.backdropCount == 2, "resolution change rebuilds the edge")
Check(box.fill[1] == 0.1 and box.fill[4] == 0.4 and box.border[3] == 0.7, "fill and border colours are restored")
local edgeOnly = CreateFrame("Frame")
Theme:ApplyPixelBackdrop(edgeOnly, { background = false })
Check(edgeOnly.backdrop.bgFile == nil and edgeOnly.backdrop.edgeFile ~= nil, "edge-only backdrop has no fill")

-- Side-selectable border: only requested edges, no duplicates, no corner overlap.
physical, uiScale = { 1920, 1080 }, 1
Theme:RefreshPixelLines()
local px = 768 / 1080
local row = CreateFrame("Button")
local border = Theme:CreatePixelBorder(row, { sides = { right = true, bottom = true, left = true } })
Check(#row.textures == 3 and border.edges.top == nil, "only requested edges are created")
Check(Near(border.edges.bottom.height, px) and Near(border.edges.left.width, px), "edges are one pixel thick")
Check(Point(border.edges.left, "TOPLEFT")[3] == 0 and Near(Point(border.edges.left, "BOTTOMLEFT")[3], px), "vertical edge stops above the bottom edge")
Theme:CreatePixelBorder(row, { sides = { top = true, right = true, bottom = true, left = true } })
Check(#row.textures == 4, "repeated call adds only the newly requested edge")
Check(Near(-Point(border.edges.right, "TOPRIGHT")[3], px), "vertical edge starts below a drawn top edge")
Theme:CreatePixelBorder(row, { sides = { bottom = true } })
Check(#row.textures == 4 and border.edges.top.shown == false and border.edges.bottom.shown == true, "dropped sides are hidden, not recreated")
border:SetColor(Theme.Colors.accent)
Check(border.edges.bottom.color[2] == Theme.Colors.accent[2] and border.edges.bottom.color[4] == 1, "border colour accepts a theme colour")
border:SetShown(false)
Check(border.edges.bottom.shown == false, "border hides as one unit")

-- Rules and refresh: scale events coalesce into one refresh.
local rule = Theme:CreatePixelRule(CreateFrame("Frame"), "vertical", { pixels = 2 })
Check(Near(rule.width, px * 2), "rule thickness uses the requested pixel count")
uiScale = 0.8
Core.Events:Fire("UI_SCALE_CHANGED"); Core.Events:Fire("DISPLAY_SIZE_CHANGED"); Core.Events:Fire("UI_SCALE_CHANGED")
Check(#timers == 1, "several scale events schedule a single refresh")
Check(Near(rule.width, px * 2), "refresh waits for the scheduled pass")
table.remove(timers, 1)()
Check(Near(rule.width, px * 2 / 0.8), "scheduled pass updates every tracked line")
Core.Events:Fire("UI_SCALE_CHANGED")
Check(#timers == 1, "a later event schedules a new pass")
table.remove(timers, 1)()

-- Shared header and current-character outline consume the pixel size.
uiScale = 1
Theme:RefreshPixelLines()
local header = Theme:CreateMatrixHeader(CreateFrame("Frame"))
Check(Near(header.bottomRule.height, px) and Near(header.rightRule.width, px), "header rules are one pixel")
Check(Near(Point(header.rightRule, "BOTTOMRIGHT")[3], px), "header right rule does not overlap the bottom rule")
local outlineRow = CreateFrame("Frame")
Theme:UpdateCurrentCharacterRowOutline(outlineRow, true)
local outline = outlineRow.__yiboCurrentCharacterOutline
Check(Near(outline.backdrop.edgeSize, px) and Point(outline, "TOPLEFT")[5] == 0 and Point(outline, "BOTTOMRIGHT")[5] == 0,
    "row outline is one pixel and lies on the row's own boundary")
-- A Core-ruled row without its own top edge: the accent covers the previous row's bottom rule.
local ruledRow = CreateFrame("Frame")
Theme:CreatePixelBorder(ruledRow, { sides = { right = true, bottom = true, left = true } })
Theme:UpdateCurrentCharacterRowOutline(ruledRow, true)
local ruledOutline = ruledRow.__yiboCurrentCharacterOutline
Check(Near(Point(ruledOutline, "TOPLEFT")[5], px), "row outline top covers the shared rule above")
local firstRow = CreateFrame("Frame")
Theme:CreatePixelBorder(firstRow, { sides = { top = true, right = true, bottom = true, left = true } })
Theme:UpdateCurrentCharacterRowOutline(firstRow, true)
Check(Point(firstRow.__yiboCurrentCharacterOutline, "TOPLEFT")[5] == 0, "first row outline covers its own top edge")
uiScale = 0.5
Theme:RefreshPixelLines()
Check(Near(Point(ruledOutline, "TOPLEFT")[5], px * 2), "outline is re-anchored after a scale change")
Theme:HideCurrentCharacterOutline(ruledRow)
Theme:RefreshPixelLines()
Check(#ruledOutline.points == 0, "hidden outline is not re-anchored")

-- Column outline: on the grid lines, and bounded by the visible content.
uiScale = 1
Theme:RefreshPixelLines()
local scripts = {}
local viewport = CreateFrame("ScrollFrame")
viewport.contentHeight, viewport.viewHeight, viewport.offset = 112, 400, 0
function viewport:GetHeight() return self.viewHeight end
function viewport:GetVerticalScroll() return self.offset end
function viewport:HasScript() return true end
function viewport:HookScript(name, fn) scripts[name] = (scripts[name] or 0) + 1; self["on" .. name] = fn end
local columnOwner, columnHeader = CreateFrame("Frame"), CreateFrame("Frame")
Theme:UpdateCurrentCharacterColumnOutline(columnOwner, columnHeader, viewport, 200, 60, true)
local column = columnOwner.__yiboCurrentCharacterOutline
Check(Near(Point(column, "TOPLEFT")[4], 200 - px) and Point(column, "TOPRIGHT")[4] == 260 and Point(column, "TOPLEFT")[5] == 0,
    "column outline covers the left neighbour's rule and its own right rule")
local bottom = Point(column, "BOTTOMLEFT")
Check(bottom[3] == "TOPLEFT" and bottom[5] == -112, "short content: outline ends at the last row, not the viewport bottom")
viewport.offset = 40; viewport.onOnVerticalScroll(viewport)
Check(Point(column, "BOTTOMLEFT")[5] == -72, "scrolling re-anchors the outline to the visible content")
viewport.contentHeight = 900; Theme.ReanchorViewportOutline(viewport)
local tall = Point(column, "BOTTOMLEFT")
Check(tall[3] == "BOTTOMLEFT" and tall[5] == 0, "overflowing content: outline ends at the viewport bottom")
Theme:UpdateCurrentCharacterColumnOutline(columnOwner, columnHeader, viewport, 200, 60, true)
Check(scripts.OnVerticalScroll == 1 and scripts.OnSizeChanged == 1, "viewport hooks are installed once")
local legacy = Theme:CreateCurrentCharacterOutline(CreateFrame("Frame"))
viewport.contentHeight = 112; viewport.offset = 0
Theme:UpdateCurrentCharacterColumnOutline(legacy, columnHeader, viewport, 200, 60, true)
Check(Near(Point(legacy, "TOPLEFT")[4], 200 - px) and Point(legacy, "BOTTOMLEFT")[5] == -112, "legacy outline handle uses the same geometry")
Check(viewport.__yiboCurrentOutline == legacy, "viewport follows its latest outline")
Theme:UpdateCurrentCharacterColumnOutline(legacy, columnHeader, viewport, 200, 60, false)
Check(legacy.shown == false, "hidden column outline")
-- A plain Frame viewport (e.g. a preview row) has no OnVerticalScroll.
local plain, hooked = CreateFrame("Frame"), {}
function plain:HasScript(name) return name ~= "OnVerticalScroll" end
function plain:HookScript(name) if name == "OnVerticalScroll" then error("Doesn't have a OnVerticalScroll script") end; hooked[name] = true end
Theme:UpdateCurrentCharacterColumnOutline(CreateFrame("Frame"), columnHeader, plain, 0, 60, true, 200)
Check(hooked.OnSizeChanged and not hooked.OnVerticalScroll, "plain frame viewport is watched without unsupported scripts")
-- The outline always starts at the header's top, also for legacy handles.
local legacyTop = Theme:CreateCurrentCharacterOutline(CreateFrame("Frame"))
Theme:UpdateCurrentCharacterColumnOutline(legacyTop, columnHeader, viewport, 0, 60, true, 200)
Check(Point(legacyTop, "TOPLEFT")[5] == 0 and Near(Point(legacyTop, "BOTTOMLEFT")[4], 200 - px), "legacy outline includes the header and uses viewportX")

-- Double-line character header: name and realm are one vertically centred group.
uiScale, physical = 1, { 1920, 1080 }
Theme:RefreshPixelLines()
local twoLine = Theme:CreateMatrixHeader(CreateFrame("Frame"))
Theme:SetMatrixHeader(twoLine, "Name", { height = 34, secondary = "Realm" })
local topGap = -Point(twoLine.label, "TOPLEFT")[3]
local group = twoLine.label.height + 1 + twoLine.secondary.height
local bottomGap = 34 - topGap - group
Check(math.abs(topGap - bottomGap) <= 768 / 1080 * 2 + 1e-9, "two-line header group is vertically centred within one pixel")
Check(Point(twoLine.secondary, "TOPLEFT")[2] == twoLine.label, "realm line follows the name line")
Theme:SetMatrixHeader(twoLine, "Left", { justify = "LEFT" })
Check(Point(twoLine.label, "TOPLEFT")[2] == Theme.Table.cellPadding, "left-aligned header shares the body content edge")
Theme:SetMatrixHeader(twoLine, "Centre")
Check(Point(twoLine.label, "TOPLEFT")[2] == Theme.Table.cellInset, "centred header keeps the measured cell inset")

-- Public re-anchor hook: runs now and after every pixel-size change.
uiScale, physical = 1, { 1920, 1080 }
Theme:RefreshPixelLines()
local icon, runs = CreateFrame("Frame"), 0
Theme:SetPixelAnchor(icon, function() runs = runs + 1; icon.inset = Theme:GetPixelSize(icon, 1) end)
Check(runs == 1 and Near(icon.inset, 768 / 1080), "SetPixelAnchor runs immediately with the current pixel size")
uiScale = 0.5; Theme:RefreshPixelLines()
Check(runs == 2 and Near(icon.inset, 768 / 1080 / 0.5), "SetPixelAnchor re-runs after a scale change")
Theme:SetPixelAnchor(icon, function() runs = runs + 10 end)
Check(runs == 12, "a second anchor replaces the first")
Theme:SetPixelAnchor(icon, nil); Theme:RefreshPixelLines()
Check(runs == 12, "a removed anchor no longer runs")
local ruled, ruleRuns = CreateFrame("Frame"):CreateTexture(), 0
Theme:ApplyPixelRule(ruled, "horizontal")
Theme:SetPixelAnchor(ruled, function() ruleRuns = ruleRuns + 1 end)
Theme:RefreshPixelLines()
Check(ruleRuns == 2 and Near(ruled.height, 768 / 1080 / 0.5), "anchor on a pixel rule keeps the rule's own thickness refresh")

print("PixelLineSpec: " .. checks .. " checks passed")
