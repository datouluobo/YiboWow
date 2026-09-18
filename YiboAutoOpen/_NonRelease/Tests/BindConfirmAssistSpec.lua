local scheduled = {}
local staticPopupShowHook
local popupSetPointHook
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
function popup:GetCenter() return self.point[4] or 0, self.point[5] or 0 end
function popup:HookScript(name, callback) self[name] = callback end
local button1, button2 = {}, {}
function button1:HookScript(_, callback) self.callback = callback end
function button2:HookScript(_, callback) self.callback = callback end
function button1:GetCenter() local x, y = popup:GetCenter(); return x - 50, y - 15 end

_G.StaticPopup1 = popup
function popup:GetName() return "StaticPopup1" end
_G.StaticPopup1Button1 = button1
_G.StaticPopup1Button2 = button2
UIParent = { GetEffectiveScale = function() return 1 end, GetWidth = function() return 1000 end, GetHeight = function() return 700 end }
GetCursorPosition = function() return 500, 350 end
GetScreenWidth = function() return 1000 end
GetScreenHeight = function() return 700 end
C_Timer = { After = function(delay, callback) scheduled[#scheduled + 1] = { delay = delay, callback = callback } end }
hooksecurefunc = function(target, method, callback)
    if type(target) == "string" then
        staticPopupShowHook = method
    elseif target == popup and method == "SetPoint" then
        popupSetPointHook = callback
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

popup.point = { "TOP", "UIParent", "TOP", 0, -120 }
for index = #scheduled, 1, -1 do
    if scheduled[index].delay == 0 then table.remove(scheduled, index).callback(); break end
end
assert(popup.point[1] == "CENTER" and popup.point[4] == 550 and popup.point[5] == 365, "a late layout reset must be corrected")

popup:SetPoint("TOP", "UIParent", "TOP", 0, -120)
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
_G.StaticPopup1Button1 = nil
_G.StaticPopup1Button2 = nil
print("Bind confirm assist spec passed")
