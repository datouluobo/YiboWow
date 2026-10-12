-- Actual provider, goal lookup and secure-button binding with controlled Frames.
dofile("_NonRelease/TaskGoalIntegration/GoalSourcesSpec.lua")
dofile("YiboTodo/Actions.lua")
dofile("YiboTaskHub/TaskActions.lua")
local Todo, Hub, Core = YiboTodo, YiboTaskHub, YiboCore
local checks = 0
local function Equal(a, b, label) checks = checks + 1; assert(a == b, (label or "check") .. ": " .. tostring(a) .. " ~= " .. tostring(b)) end
local itemProject = { action = { actionMode = "use-item", itemID = 86425, interactName = "诺米" } }
local item = Todo.Actions:Describe(itemProject, true)
Equal(item.attributes.type1, "item", "Nomi uses secure item")
Equal(item.attributes.item1, "item:86425", "uncached item uses stable ID")
Equal(item.attributes.macrotext2, "/targetexact 诺米", "right click selects only")
Equal(Todo.Actions:Describe(itemProject, false), nil, "remote source icon cannot execute")
local intent = Todo.GoalTargets:Intent({ groupID = Todo.ActionTodo.GROUP }, "C")
local descriptor = assert(Todo.GoalTargets:GetClickAction(intent))
Equal(descriptor.attributes.type1, "macro", "profession click is protected")
Equal(descriptor.attributes.macrotext1:find("DoTradeSkill", 1, true) ~= nil, true, "same direct craft macro")
Equal(descriptor.attributes.macrotext2:find("CastSpellByName", 1, true) ~= nil, true, "right opens profession")
intent.scope.characterID = "D"
Equal(Todo.GoalTargets:GetClickAction(intent), nil, "remote target cannot execute")
intent.scope.characterID = "C"
local goal = assert(Hub.Goals:Add(intent))
local band, workOffset = CreateFrame("Frame"), 6
local originalCreate = CreateFrame
CreateFrame = function(...)
    local frame = originalCreate(...); frame.attributes = {}
    function frame:SetAttribute(key, value) self.attributes[key] = value end
    local template = select(4, ...)
    local protected = type(template) == "string" and template:find("SecureActionButtonTemplate", 1, true)
    local originalPoint = frame.SetPoint
    function frame:SetPoint(point, target, ...)
        assert(not protected or type(target) ~= "table" or not target.isRegion, "Cannot anchor protected frames to regions")
        return originalPoint(self, point, target, ...)
    end
    local originalFontString = frame.CreateFontString
    function frame:CreateFontString(...) local region = originalFontString(self, ...); region.isRegion = true; return region end
    return frame
end
Hub.TaskActions:Bind(band, workOffset, { goalID = goal.id, title = "神纹布" })
Equal(band.executeIcon.shown, true, "Task displays executable icon")
Equal(band.executeIcon.attributes.type1, "macro", "Task copies source secure attributes")
Equal(band.executeIcon.scripts.OnClick, nil, "secure template OnClick preserved")
Equal(band.executeIcon.attributes.type3, "", "middle button cannot craft")
local scans = 0; Todo.QueueProfessionCooldownRefresh = function() scans = scans + 1 end
band.executeIcon.scripts.PostClick(band.executeIcon, "LeftButton")
Equal(scans, 1, "post click requests source verification")
band.executeIcon.scripts.PostClick(band.executeIcon, "MiddleButton")
Equal(scans, 1, "non-business click does not request craft scan")
InCombatLockdown = function() return true end
Hub.TaskActions:Bind(band, nil, nil)
Equal(band.executeIcon.shown, true, "no protected mutation in combat")
InCombatLockdown = function() return false end
Hub.TaskActions:Bind(band, nil, nil)
Equal(band.executeIcon.shown, false, "row reuse hides action")
Equal(band.executeIcon.attributes.type1, nil, "row reuse clears stale attributes")
dofile("YiboTaskHub/Presentation.lua")
local nomiSnapshot = Todo.Snapshot:BuildTarget("C", "mop.nomi")
local nomiTask = assert(Todo.ActionNomi:Project("C", nomiSnapshot, Todo:Now(), "test", "mop.nomi", true))
Equal(nomiTask.item.itemID, 86425, "Nomi task preserves Todo item icon identity")
local oldItemIcon = GetItemIcon
GetItemIcon = function(id) return id == 86425 and "nomi-item-icon" or nil end
Equal(Hub.Presentation:Icon(nomiTask), "nomi-item-icon", "uncached full item details do not hide available texture")
Equal(Hub.Presentation:WorkText(nomiTask):find("nomi-item-icon", 1, true) ~= nil, true, "Task work cell renders Nomi item texture")
GetItemIcon = oldItemIcon
dofile("YiboTaskHub/Preview.lua")
dofile("YiboTaskHub/AccountPage.lua")
Hub.Reminders = { Acknowledge = function() end }
Hub.Displays = { ScheduleRefresh = function() end }
Hub.db.goals.byID[goal.id].lastCompletedCycle = nil
local profession = Todo.Database:GetProvider("C", "profession-cooldown", false)
profession.observations[Todo.ActionTodo.GROUP].recipes[143011].readyAt = 0
Hub.Contracts:Invalidate()
local host = CreateFrame("Frame")
Hub.AccountPage.Create(host)
local context = { characters = Core.Characters:GetAll(), surfaceAvailableWidth = 1040 }
Hub.AccountPage.Refresh(host, context)
local mainBound = false
for _, row in ipairs(host.rows) do if row.executeIcon and row.executeIcon.shown then
    mainBound = true
    Equal(row.executeIcon.point[2], row, "main secure action anchors to row Frame")
    Equal(row.executeIcon.point[4], row.workOffset, "main secure action uses work column offset")
end end
Equal(mainBound, true, "main work icon uses shared execution binding")
context.preview = true
Hub.AccountPage.Refresh(host, context)
local previewBound = false
for _, row in ipairs(host.taskPreview.rows) do if row.executeIcon and row.executeIcon.shown then
    previewBound = true
    Equal(row.executeIcon.point[2], row, "preview secure action anchors to row Frame")
    Equal(row.executeIcon.point[4], row.workOffset, "preview secure action uses work column offset")
end end
Equal(previewBound, true, "hover work icon uses shared execution binding")
local previewRow
for _, row in ipairs(host.taskPreview.rows) do if row.executeIcon and row.executeIcon.shown then previewRow = row; break end end
Equal(previewRow.workIcon.width, 24, "visible work icon has fixed bordered size")
Equal(previewRow.workIcon.point[4], previewRow.executeIcon.point[4], "visible and clickable icons share exact position")
Equal(previewRow.cells[1].point[2], previewRow.workOffset + 28, "work label clears bordered icon")
Equal(previewRow.cells[1].text:find("|T", 1, true), nil, "work label no longer embeds baseline-shifted inline icon")
local currentRow
for _, pair in ipairs(host.taskPreview.view.rows) do if pair.row.task.goalID == goal.id then currentRow = pair.row; break end end
local unknownOne = Core.Defaults:Copy(currentRow); unknownOne.task.readiness = "unknown"
local unknownTwo = Core.Defaults:Copy(unknownOne); unknownTwo.task.goalID = "second-visible-goal"
local organized = Hub.AccountPage:Organize({ { row = unknownOne, section = "current" }, { row = unknownTwo, section = "current" } }, {})
Equal(#organized, 2, "current unknown goals remain individually visible")
Equal(organized[1].members, nil, "current profession is not hidden in unknown summary")
profession.observations[Todo.ActionTodo.GROUP].recipes[143011].readyAt = Todo:Now() + 600
Hub.Contracts:Invalidate()
Hub.AccountPage.Refresh(host, context)
local retained
for _, pair in ipairs(host.taskPreview.view.rows) do if pair.row.task.goalID == goal.id then retained = pair.row.task; break end end
Equal(retained and retained.retainedInView, true, "completed icon survives refresh in current opening")
Equal(retained.state, "completed", "retained icon reports actual completion")
Equal(Hub.TaskActions:Resolve(retained) ~= nil, true, "retained completed icon still supports repeated hardware clicks")
Equal(Hub.Presentation:Counts({ { task = retained } }).completed, 1, "completed retained icon is not counted as waiting")
host.taskPreview.scripts.OnHide(host.taskPreview)
Hub.AccountPage.Refresh(host, context)
local reopened = false
for _, pair in ipairs(host.taskPreview.view.rows) do if pair.row.task.goalID == goal.id then reopened = true end end
Equal(reopened, false, "completed row disappears on next opening")
-- Main window retention uses the same helper and remains display-only.
local retainedFrame = {}
Hub.AccountPage:Retain({ { row = currentRow, section = "current" } }, retainedFrame, context)
Equal(#Hub.AccountPage:Retain({}, retainedFrame, context), 1, "main view retains completed row")
local saved = Hub.db.goals.byID[goal.id]; local oldState = saved.state; saved.state = "removed"
Equal(#Hub.AccountPage:Retain({}, retainedFrame, context), 0, "explicit removal is never retained")
saved.state = oldState
local oldDomainGet = Core.DataDomains.Get
Core.DataDomains.Get = function() return nil end
local unverified = Todo.GoalTargets:Evaluate({ goals = { { id = goal.id, intent = intent } } }).evaluations[goal.id]
Equal(unverified.task, nil, "missing profession domain remains unverified")
Equal(type(unverified.display.item.itemID), "number", "unverified profession still supplies catalog item icon")
Hub.Contracts:Invalidate()
local unknownTask
for _, row in ipairs(Hub.Snapshot:Build(context.characters).current) do if row.task.goalID == goal.id then unknownTask = row.task end end
Equal(unknownTask.item.itemID, unverified.display.item.itemID, "Task preserves source icon on unknown goal")
Core.DataDomains.Get = oldDomainGet; Hub.Contracts:Invalidate()
local ref
for _, entry in ipairs(Core.Contracts:List("action.targets", { major = 1, minMinor = 2 })) do if entry.providerID == Todo.GoalTargets.PROVIDER then ref = entry end end
assert(Core.Contracts:Unregister(Todo.NAME, ref.registrationRef))
Hub.TaskActions:Bind(band, workOffset, { goalID = goal.id, title = "神纹布" })
Equal(band.executeIcon.shown, false, "missing provider leaves base view functional")
local lateRef = assert(Core.Contracts:Register(Todo.NAME, Todo.GoalTargets.definition))
Hub.TaskActions:Bind(band, workOffset, { goalID = goal.id, title = "神纹布" })
Equal(band.executeIcon.shown, true, "late registration restores direct action")
assert(Core.Contracts:Unregister(Todo.NAME, lateRef))
local oldDefinition = Core.Defaults:Copy(Todo.GoalTargets.definition)
oldDefinition.version.minor = 1
assert(Core.Contracts:Register(Todo.NAME, oldDefinition))
Hub.TaskActions:Bind(band, workOffset, { goalID = goal.id, title = "神纹布" })
Equal(band.executeIcon.shown, false, "old provider leaves navigation available")
CreateFrame = originalCreate
print("ClickActionsSpec: " .. checks .. " checks passed")
