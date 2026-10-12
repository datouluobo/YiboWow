-- Real Core action/settings implementation with controlled input and Frames.
dofile("_NonRelease/TaskGoalIntegration/GoalSourcesSpec.lua")
local Core, Hub, Todo, checks = YiboCore, YiboTaskHub, YiboTodo, 0
local function Equal(a, b, label) checks = checks + 1; assert(a == b, (label or "check") .. ": " .. tostring(a) .. " ~= " .. tostring(b)) end
local actions, control = Core.BusinessItemActions, CreateFrame("Button")
local intent = Todo.GoalTargets:Intent({ groupID = "mop.farm.operation-observed" }, "C")
local ctrlType, configurations
configurations = 0
actions:Bind(control, { owner = Todo.NAME, GetIntent = function() return intent end,
    reservedButtons = { LeftButton = true }, ConfigureCtrlLeft = function(enabled)
        ctrlType = enabled and "" or nil; configurations = configurations + 1; return true
    end })
assert(actions:SetOptions({ mode = "menu" }))
Equal(actions:Matches("MiddleButton"), false, "button-only mode disables middle")
actions:ShowMenu(control); Equal(control.yiboItemMenu.shown, true, "button-only mode shows menu")
assert(actions:SetOptions({ mode = "middle" }))
actions:ShowMenu(control); Equal(control.yiboItemMenu.shown, false, "middle mode hides right-top menu")
Equal(actions:Matches("MiddleButton"), true, "middle mode enables middle")
Equal(actions:Matches("LeftButton"), false, "middle mode disables Ctrl-left")
assert(actions:SetOptions({ mode = "ctrlLeft" }))
IsControlKeyDown = function() return true end
Equal(ctrlType, "", "source disables protected Ctrl-left fallback before dispatch")
Equal(actions:Matches("MiddleButton"), false, "Ctrl-left mode disables middle")
Equal(actions:Matches("LeftButton"), true, "Ctrl-left mode enables exact chord")
Equal(actions:Handle(control, "LeftButton"), true, "explicit safe chord consumes original action")
Equal(actions:GetGesture().ctrl, true, "public gesture reports selected chord")
Equal(Hub.Goals:Lookup(intent) ~= nil, true, "Ctrl-left adds goal")
Equal(actions:Handle(control, "LeftButton"), true, "second Ctrl-left handled")
Equal(Hub.Goals:Lookup(intent), nil, "second Ctrl-left cancels exact goal")
IsAltKeyDown = function() return true end
Equal(actions:Matches("LeftButton"), false, "extra modifier preserves original behavior")
IsAltKeyDown = function() return false end
local unsafe = CreateFrame("Button")
actions:Bind(unsafe, { owner = Todo.NAME, GetIntent = function() return intent end, reservedButtons = { LeftButton = true } })
Equal(actions:Handle(unsafe, "LeftButton"), false, "undeclared protected chord stays reserved")
assert(actions:SetOptions({ mode = "middle" }))
Equal(ctrlType, nil, "other mode restores original Ctrl-left attributes")
Equal(configurations > 2, true, "live bindings reconfigure on mode change")
IsControlKeyDown = function() return false end
control.yiboGoalMarkerH.SetColorTexture = function(self, ...) self.color = { ... } end
actions:SetMarker(control, { count = 1, active = 1, paused = 0, completed = 0 })
assert(actions:SetOptions({ markerStyle = "dot" }))
Equal(control.yiboGoalMarkerH.width, 6, "dot uses compact round footprint")
Equal(control.yiboGoalMarkerV.height, 6, "dot shares round footprint")
Equal(control.yiboGoalMarkerH.color[2], Core.UITheme.Colors.accent[2], "dot uses teal")
Equal(control.yiboGoalMarkerH.shown, true, "style switch preserves membership")
assert(actions:SetOptions({ markerStyle = "corner" }))
Equal(control.yiboGoalMarkerH.width, 8, "corner retains original shape")
Equal(control.yiboGoalMarkerH.color[1], Core.UITheme.Colors.goalAdded[1], "corner uses gold")
actions:SetMarker(control, nil); Equal(control.yiboGoalMarkerH.shown, false, "removed membership hides either style")
InCombatLockdown = function() return true end
Equal(actions:SetOptions({ mode = "ctrlLeft" }), nil, "combat rejects protected reconfiguration")
Equal(actions:GetOptions().mode, "middle", "combat rejection preserves saved mode")
InCombatLockdown = function() return false end
Equal(actions:SetOptions({ mode = "invalid" }), nil, "invalid mode rejected")
Equal(actions:SetOptions({ markerStyle = "invalid" }), nil, "invalid marker style rejected")
Core.Database:GetDB().settings.businessItemActions = nil
Core.Database:GetDB().settings.businessItemGesture = { button = "Button4", ctrl = false, alt = false, shift = false }
Equal(actions:GetOptions().mode, "custom", "existing custom gesture is preserved during migration")
Equal(actions:GetOptions().markerStyle, "corner", "migration retains gold corner default")
print("ItemActionSettingsSpec: " .. checks .. " checks passed")
