-- Actual Core window/preview sizing, independent of currency business rules.
dofile("YiboCurrency/_NonRelease/Tests/API13Spec.lua")
dofile("YiboCore/Util/LevelFilter.lua")
local Core, view, checks = YiboCore, YiboCore.AccountView, 0
local function Check(value, message) checks = checks + 1; assert(value, message) end
local function Near(a, b) return math.abs(a - b) < 0.01 end
local frame = CreateFrame("Frame", nil, UIParent); frame:SetSize(760, 500); frame:Hide()
for _, key in ipairs({ "nav", "sortButton", "settingsButton", "close", "content", "pageIcon", "title", "titleBar", "version", "subtitle", "controls" }) do
    frame[key] = CreateFrame("Frame", nil, frame)
end
view.CreateFrame = function() return frame end
view.frame = frame
view.TrackPreviewControls = function() end
view.ShowPage = function() end
local body, naturalWidth, fixed, preferredHeight = 800, 1000.25, 40, 340
local page = assert(view:RegisterPage("YiboCurrency", { id = "scroll-budget-test", title = "Budget", previewEnabled = true, defaultEnabled = true, Create = function() end, Refresh = function() end,
    GetSurfaceMetrics = function() return { minContentWidth = 300, naturalContentWidth = naturalWidth,
        minContentHeight = 100, naturalContentHeight = preferredHeight, scrollContentHeight = body, scrollFixedHeight = fixed } end }))
local shellWidth = Core.UITheme:GetNavigationWidth() + Core.UITheme.Geometry.shellBorder * 2 + 1
local context = view:BuildContext(page)
view:ApplyPageSize(page, context)
Check(Core:HasCapability("account-surface-budget", 2), "Core declares scroll budget v2")
Check(Near(frame:GetWidth(), math.ceil(naturalWidth) + shellWidth + 16), "Core expands natural width for the actual vertical track")
local parent = CreateFrame("Frame"); parent:SetSize(1000, 340)
Check(view:GetScrollSurfaceWidth({ surfaceAvailableWidth = 1000 }, parent, 800, 40) == 984, "renderer consumes exactly one shared gutter")
Check(view:GetScrollSurfaceWidth({ surfaceAvailableWidth = 1000 }, parent, 300, 40) == 1000, "exact fit has no phantom gutter")
body, naturalWidth = 0, 300
view:ApplyPageSize(page, context) -- Save a narrower user window.
body, naturalWidth = 800, 1000.25
view:ApplyPageSize(page, context)
Check(Near(frame:GetWidth(), math.ceil(naturalWidth) + shellWidth + 16), "a saved narrow width cannot trigger premature pagination")
-- A saved tall window can eliminate a track even when preferred height is short.
local db = Core.Database:GetDB()
for key, size in pairs(db.settings.accountView.pageSizes) do if key:find(page.id, 1, true) then size.height = 950; size.width = math.ceil(naturalWidth) + shellWidth end end
view:ApplyPageSize(page, context)
Check(Near(frame:GetWidth(), math.ceil(naturalWidth) + shellWidth), "saved tall height releases the gutter instead of using preferred height")
-- Preview sizing uses final anchored height, not only full-screen estimates.
frame:Hide(); frame.preview = false
local anchor = CreateFrame("Frame")
anchor.GetLeft = function() return 500 end; anchor.GetRight = function() return 530 end
anchor.GetTop = function() return 400 end; anchor.GetBottom = function() return 380 end
assert(view:ShowPreview(page.id, anchor, true))
Check(Near(frame:GetWidth(), math.ceil(naturalWidth + 2 + 16)), "anchored preview budgets its track before positioning")
body = 0; frame:Hide(); frame.preview = false
assert(view:ShowPreview(page.id, anchor, true))
Check(Near(frame:GetWidth(), math.ceil(naturalWidth + 2)), "short preview releases the gutter")
page.GetHoverMetrics = function() return { minWidth = 302, preferredWidth = naturalWidth + 2,
    minHeight = 100, preferredHeight = preferredHeight + 48, scrollContentHeight = 800, scrollFixedHeight = fixed } end
frame:Hide(); frame.preview = false
assert(view:ShowPreview(page.id, anchor, true))
Check(Near(frame:GetWidth(), math.ceil(naturalWidth + 2) + 16), "explicit hover metrics share the same scroll budget")
page.GetHoverMetrics = nil
body, naturalWidth = 800, 10000; frame:Hide(); frame.preview = false
assert(view:ShowPreview(page.id, anchor, true))
Check(frame:GetWidth() <= UIParent:GetWidth() - 32, "screen boundary remains the final ceiling")
print("ScrollBudgetSpec: " .. checks .. " checks passed")
