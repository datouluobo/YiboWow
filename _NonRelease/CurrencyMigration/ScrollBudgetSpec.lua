-- Actual Core window/preview sizing, independent of currency business rules.
dofile("YiboCurrency/_NonRelease/Tests/API13Spec.lua")
dofile("YiboCore/Util/LevelFilter.lua")
local Core, view, checks = YiboCore, YiboCore.AccountView, 0
Core.Client.IsInCombat = function() return false end
Core.Client.RegisterCombatDriver = function() return false end
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
local context = view:BuildContext(page)
view:ApplyPageSize(page, context)
Check(Core:HasCapability("account-surface-budget", 2), "Core declares scroll budget v2")
Check(frame:GetWidth() == 800 and frame:GetHeight() == 544, "normal window keeps the shared size")
local available = context.surfaceAvailableWidth
local parent = CreateFrame("Frame"); parent:SetSize(1000, 340)
Check(view:GetScrollSurfaceWidth({ surfaceAvailableWidth = 1000 }, parent, 800, 40) == 984, "renderer consumes exactly one shared gutter")
Check(view:GetScrollSurfaceWidth({ surfaceAvailableWidth = 1000 }, parent, 300, 40) == 1000, "exact fit has no phantom gutter")
body, naturalWidth = 0, 300
view:ApplyPageSize(page, context)
Check(context.surfaceAvailableWidth == available and frame:GetWidth() == 800, "normal surface budget is independent of the page's scroll track")
body, naturalWidth = 800, 1000.25
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
