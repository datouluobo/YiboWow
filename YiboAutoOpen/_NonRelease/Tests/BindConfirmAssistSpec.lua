local scheduled = {}
local staticPopupShowHook
local staticPopupPositionHook
local popupSetPointHook
local popupResizeHook
local popup = {
    which = "LOOT_BIND", shown = true, width = 300, height = 100,
    point = { "TOP", "UIParent", "TOP", 0, -120 },
}
function popup:IsShown() return self.shown end
function popup:GetPoint() return unpack(self.point) end
function popup:ClearAllPoints() self.point = {} end
function popup:SetPoint(...)
    self.point = { ... }
    if popupSetPointHook then popupSetPointHook(self) end
end
function popup:GetWidth() return self.width end
function popup:GetHeight() return self.height end
function popup:GetCenter()
    if self.reportedCenter then return unpack(self.reportedCenter) end
    return self.point[4] or 0, self.point[5] or 0
end
function popup:HookScript(name, callback) self[name] = callback end
local button1, button2 = {}, {}
function button1:HookScript(_, callback) self.callback = callback end
function button2:HookScript(_, callback) self.callback = callback end
function button1:GetCenter() local x, y = popup:GetCenter(); return x + (self.offsetX or -50), y + (self.offsetY or -15) end
function popup:Resize()
    if self.nextLayout then
        self.width, self.height = self.nextLayout.width, self.nextLayout.height
        button1.offsetX, button1.offsetY = self.nextLayout.buttonX, self.nextLayout.buttonY
        self.nextLayout = nil
    end
    if popupResizeHook then popupResizeHook(self) end
end

_G.StaticPopup1 = popup
function popup:GetName() return "StaticPopup1" end
_G.StaticPopup1Button1 = button1
_G.StaticPopup1Button2 = button2
UIParent = { GetEffectiveScale = function() return 1 end, GetWidth = function() return 1000 end, GetHeight = function() return 700 end }
GetCursorPosition = function() return 500, 350 end
GetScreenWidth = function() return 1000 end
GetScreenHeight = function() return 700 end
C_Timer = { After = function(delay, callback) scheduled[#scheduled + 1] = { delay = delay, callback = callback } end }
StaticPopup_SetUpPosition = function() end
hooksecurefunc = function(target, method, callback)
    if target == "StaticPopup_Show" then
        staticPopupShowHook = method
    elseif target == "StaticPopup_SetUpPosition" then
        staticPopupPositionHook = method
    elseif target == popup and method == "SetPoint" then
        popupSetPointHook = callback
    elseif target == popup and method == "Resize" then
        popupResizeHook = callback
    end
end

YiboAutoOpen = {
    runtime = { pending = nil, quarantined = {}, warned = {} },
    NotifyIssue = function() end,
    Queue = { RequestScan = function() end },
}
_G.YiboAutoOpen = YiboAutoOpen

dofile("YiboAutoOpen/BindConfirmAssist.lua")
local pending = { itemID = 90735 }
YiboAutoOpen.runtime.pending = pending
YiboAutoOpen.BindConfirmAssist:Arm(pending)
YiboAutoOpen.runtime.pending = nil
YiboAutoOpen.BindConfirmAssist:AwaitPossibleBind(pending)
staticPopupShowHook("LOOT_BIND")
assert(pending.awaitingBindConfirmation, "the bind prompt should hold the pending operation")
assert(popup.point[1] == "CENTER" and popup.point[4] == 550 and popup.point[5] == 365, "the confirm button should move to the cursor")
assert(YiboAutoOpen.runtime.lastBindPlacement.cursorSource == "api-ui-parent-scale", "the cursor API should not depend on the loot frame")

-- A point change can precede the engine's center-coordinate update. Reading
-- that old center must not suppress the replacement of the new default anchor.
popup.reportedCenter = { 550, 365 }
popup:SetPoint("TOP", "UIParent", "TOP", 0, -120)
assert(popup.point[1] == "CENTER" and popup.point[4] == 550 and popup.point[5] == 365, "a stale center must not leave the native default anchor in place")
popup.reportedCenter = nil

popup:SetPoint("TOP", "UIParent", "TOP", 0, -120)
assert(popup.point[1] == "CENTER" and popup.point[4] == 550 and popup.point[5] == 365, "a layout reset must be repaired before any next-frame callback")
for index = #scheduled, 1, -1 do
    if scheduled[index].delay == 0 then table.remove(scheduled, index).callback(); break end
end
assert(popup.point[1] == "CENTER" and popup.point[4] == 550 and popup.point[5] == 365, "a later layout owner's anchor must be corrected once")

popup.shown = false
popup.OnHide(popup)
popup.shown = true
for index = #scheduled, 1, -1 do
    if scheduled[index].delay == 0 then table.remove(scheduled, index).callback(); break end
end
assert(popup.point[1] == "CENTER" and popup.yiboAutoOpenBindPending == pending, "a transient hide during layout must not restore or cancel the popup")

button2.callback()
assert(YiboAutoOpen.runtime.pending == nil, "cancelling should clear the pending operation")
assert(YiboAutoOpen.runtime.bindConfirmCandidate == nil, "cancelling should clear the completed operation's bind context")
popup.shown = false
popup.OnHide(popup)
for index = #scheduled, 1, -1 do
    if scheduled[index].delay == 0 then table.remove(scheduled, index).callback(); break end
end
assert(popup.point[1] == "TOP", "the original popup position should be restored")
popup.shown = true
popup.point = { "TOP", "UIParent", "TOP", 0, -120 }
YiboAutoOpen.db = { bindConfirmFollowCursor = false }
local disabledPending = { itemID = 90735 }
YiboAutoOpen.BindConfirmAssist:Arm(disabledPending)
staticPopupShowHook("LOOT_BIND")
assert(popup.point[1] == "TOP", "disabled cursor placement must retain the game's native popup position")

-- The native sequence is Init -> SetUpPosition -> Show -> Resize. A fast-loot
-- handler may enter it before our LOOT_OPENED / LOOT_BIND_CONFIRM handlers.
YiboAutoOpen.db.bindConfirmFollowCursor = true
YiboAutoOpen.Database = { IsConfirmSourceEnabled = function(_, key) return key == "object:210565" end }
YiboAutoOpen.Catalog = { GetGameObjectID = function(_, guid) if guid == "soil-guid" then return 210565 end end }
GetNumLootItems = function() return 1 end
GetLootSourceInfo = function() return "soil-guid", "潘达利亚泥土" end
popup.shown = false
popup.dialogInfo = {}
popup.nextLayout = { width = 320, height = 160, buttonX = -65, buttonY = -50 }
scheduled = {}
staticPopupPositionHook(popup)
local soilPending = popup.yiboAutoOpenBindPending
assert(soilPending and soilPending.source == "object:210565", "the pre-show hook must identify soil before our loot event handlers run")
assert(not popup:IsShown() and popup.point[1] == "CENTER" and popup.point[4] == 565 and popup.point[5] == 400, "the hidden popup must finish resizing and position its confirm button at the cursor before Show")
popup.shown = true
popup.OnShow(popup)
popup:Resize()
staticPopupShowHook("LOOT_BIND")
assert(popup.point[1] == "CENTER" and popup.point[4] == 565 and popup.point[5] == 400, "Show and the native final Resize must retain the initial placement")
YiboAutoOpen.BindConfirmAssist:HandleLootBindConfirm()
assert(popup.yiboAutoOpenBindPending == soilPending and YiboAutoOpen.runtime.bindConfirmCandidate == nil, "the later confirmation event must not create a second pending operation")
GetCursorPosition = function() return 800, 500 end
for _, timer in ipairs(scheduled) do if timer.delay == 0 then timer.callback() end end
assert(popup.point[4] == 565 and popup.point[5] == 400, "layout confirmation must retain the cursor position captured when the dialog appeared")
popup.nextLayout = { width = 320, height = 180, buttonX = -65, buttonY = -60 }
popup:Resize()
assert(popup.point[4] == 565 and popup.point[5] == 410, "a later native Resize must repair button alignment in the same call")
popup:SetPoint("TOP", "UIParent", "TOP", 0, -120)
assert(popup.point[1] == "CENTER" and popup.point[4] == 565 and popup.point[5] == 410, "a third-party anchor must be repaired synchronously for soil confirmations")
popup.shown = false
popup.OnHide(popup)
popup.which = "UNRELATED_DIALOG"
popup.yiboAutoOpenBindPending = nil
popup.point = { "TOP", "UIParent", "TOP", 0, -120 }
popup.shown = true
for _, timer in ipairs(scheduled) do if timer.delay == 0 then timer.callback() end end
assert(popup.point[1] == "TOP", "stale layout callbacks must not move a reused popup")
_G.StaticPopup1Button1 = nil
_G.StaticPopup1Button2 = nil
StaticPopup_SetUpPosition = nil
GetNumLootItems, GetLootSourceInfo = nil, nil
print("Bind confirm assist spec passed")
