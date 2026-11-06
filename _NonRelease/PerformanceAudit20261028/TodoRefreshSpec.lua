dofile('YiboTaskHub/_NonRelease/Tests/ActionIntegrationSpec.lua')
local todo = YiboTodo
local now, queue, notices = 1000, {}, 0
GetServerTime = function() return now end
C_Timer = {}
C_Timer.After = function(delay, fn) queue[#queue + 1] = { fn = fn, delay = delay } end
C_Timer.NewTimer = function(delay, fn)
    local timer = { fn = fn, delay = delay }
    function timer:Cancel() self.cancelled = true end
    queue[#queue + 1] = timer
    return timer
end
local snapshot = todo.Snapshot
snapshot.transitionAt, snapshot.transitionPending, snapshot.transitionTimer = nil, nil, nil
for i = 1, 200 do snapshot:ScheduleTransitionRefresh(2000) end
assert(#queue == 1, 'same transition creates one timer')
snapshot:ScheduleTransitionRefresh(1500)
assert(#queue == 2 and queue[1].cancelled, 'changed transition cancels old timer')
snapshot:ScheduleTransitionRefresh(nil)
assert(queue[2].cancelled, 'removing transition cancels timer')
queue = {}
todo.Core.AccountView.frame = { preview = true }
todo.Core.AccountView.previewPageID = 'todo'
todo.Core.AccountView.NotifyPageChanged = function() notices = notices + 1 end
for i = 1, 200 do todo:NotifyChanged() end
assert(#queue == 1, 'burst creates one pending preview timer')
queue[1].fn()
assert(#queue == 2 and notices == 0, 'burst extends quiet period with one timer')
queue[2].fn()
assert(notices == 1, 'settled burst refreshes once')
todo:NotifyChanged(); todo:NotifyChanged(true)
assert(notices == 2, 'immediate notification refreshes')
queue[3].fn()
assert(notices == 2, 'immediate notification cancels queued refresh')
print('PASS: transition timer deduplication and cancellation; 200 preview notifications coalesced')
local theme = YiboCore.UITheme
local function dummy(parent) return CreateFrame('Frame', nil, parent) end
theme.CreateScrollFrame = function(_, parent) return dummy(parent) end
theme.CreateMatrixHeader = function(_, parent) local f = dummy(parent); f.label = dummy(f); return f end
theme.CreateCurrentCharacterOutline = function(_, parent) return dummy(parent) end
theme.CreateText = function(_, parent) return dummy(parent) end
theme.ApplyDataColumnTints = function() end
theme.SetMatrixHeader = function() end
theme.SetCurrentCharacterOutline = function() end
theme.GetCharacterRowHeaderWidth = function() return 120 end
theme.GetMatrixInsets = function() return { left=0, right=0, top=0, bottom=0 } end
theme.GetDataRowColor = function() return { 0,0,0,1 } end
theme.GetTableCellContentWidth = function(_, w) return w end
theme.MeasureText = function(_, _, text) return #text * 5 end
theme.BindTooltip = function() end
YiboTodo.Settings.IsMonitoringGroupEnabled = function(_, id) return id == 'profession-cooldown' end
local project = { state='cooldown', label='test', iconKind='texture', icon='test' }
local data = { professionProjects={project}, monitoringProjects={} }
YiboTodo.Snapshot.Build = function() return { characters = { C=data } } end
YiboTodo.Core.BusinessItemActions = nil
YiboTodo.Actions = { Describe = function() return nil end }
dofile('YiboTodo/AccountPage.lua')
local page, frame = YiboTodo.AccountPage, CreateFrame('Frame')
page.Create(frame)
local context = { characters = { { id='C', name='C' } } }
page.Refresh(frame, context)
local row, cell = frame.rows[1], frame.rows[1].cells[1]
local icon = cell.icons[1]
local hides = 0
for _, f in ipairs({row, cell, icon}) do
    local original = f.Hide
    f.Hide = function(self) hides = hides + 1; original(self) end
end
page.Refresh(frame, context)
assert(hides == 0, 'visible row, cell and icon remain visible during refresh')
data.professionProjects = {}
page.Refresh(frame, context)
assert(not icon.shown, 'unused icon is hidden')
context.characters = {}
page.Refresh(frame, context)
assert(not row.shown, 'unused row is hidden')
print('PASS: active row, cell and icon stay visible; unused controls are hidden')

