_G.YiboTodo = nil
dofile("YiboTodo/Namespace.lua")
local Addon = _G.YiboTodo
Addon.db = { settings = { modeOverrides = {}, monitoringGroups = {} } }

dofile("YiboTodo/Catalog/MonitoringGroupCatalog.lua")
Addon.Catalog.groups["test.cooldown.one"] = { id = "test.cooldown.one", label = "测试冷却一", order = 1, active = true }
Addon.Catalog.groups["test.cooldown.two"] = { id = "test.cooldown.two", label = "测试冷却二", order = 2, active = true }
dofile("YiboTodo/Settings.lua")

local Settings = Addon.Settings
assert(Settings:GetMonitoringGroupState("profession-cooldown") == "enabled", "verified members inherit an enabled parent by default")

Settings:SetMonitoringItemEnabled("profession-cooldown", "test.cooldown.one", false)
assert(Settings:GetMonitoringGroupState("profession-cooldown") == "partial", "one disabled child makes the parent partial")
assert(not Settings:IsMonitoringItemEnabled("profession-cooldown", "test.cooldown.one"), "explicit child override is disabled")
Settings:SetMonitoringGroupEnabled("profession-cooldown", true, true)
assert(Settings:GetMonitoringGroupState("profession-cooldown") == "enabled", "a partial parent action selects every child")
Settings:SetMonitoringItemEnabled("profession-cooldown", "test.cooldown.one", true)
assert(Settings:IsMonitoringItemEnabled("profession-cooldown", "test.cooldown.one"), "a child can be re-enabled without recreating the group")
Settings:SetMonitoringItemEnabled("profession-cooldown", "test.cooldown.one", false)

Settings:SetMonitoringGroupEnabled("profession-cooldown", false)
assert(Settings:GetMonitoringGroupState("profession-cooldown") == "hidden", "parent close hides the column")
Settings:SetMonitoringGroupEnabled("profession-cooldown", true)
assert(Settings:GetMonitoringGroupState("profession-cooldown") == "partial", "parent reopen preserves child overrides")

Settings:SetMonitoringItemEnabled("profession-cooldown", "test.cooldown.two", false)
assert(Settings:GetMonitoringGroupState("profession-cooldown") == "hidden", "all disabled children hide the column")
Settings:SetMonitoringGroupEnabled("profession-cooldown", true)
assert(Settings:GetMonitoringGroupState("profession-cooldown") == "enabled", "reopening an empty group restores inherited child defaults")

print("YiboTodo monitoring settings smoke passed")
