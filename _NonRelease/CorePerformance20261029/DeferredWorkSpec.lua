-- Real target runtimes: idle input work and cancelled resolver references.
local baseline = arg and arg[1] == 'baseline'
local Boot = dofile('_NonRelease/CoreRetailR2/Harness.lua')
for _, target in ipairs({ 'Mists', 'Retail', 'Forever' }) do
    local env, core, fire, flush = Boot(target)
    fire('ADDON_LOADED'); fire('PLAYER_LOGIN'); flush()
    assert(core:IsInitialized())
    local inputs, updates = {}, 0
    for i = 1, 100 do inputs[i] = core.UITheme:CreateInput(env.UIParent, {}) end
    for tick = 1, 600 do
        for _, input in ipairs(inputs) do
            local callback = input:GetScript('OnUpdate')
            if callback then callback(input, 1 / 60); updates = updates + 1 end
        end
    end
    print(target .. ': 100 idle inputs/600 frames, callbacks=' .. updates)
    if not baseline then assert(updates == 0) end
    local changes, lastUser = 0, nil
    local input = core.UITheme:CreateInput(env.UIParent, { OnChanged = function(_, user)
        changes = changes + 1; lastUser = user
    end })
    input.composing = true; input:InputText('input')
    assert(input.imePending and changes == 0)
    input:Fire('OnUpdate', .01); assert(changes == 0)
    input.composing = false; input:Fire('OnUpdate', .01)
    assert(changes == 1 and lastUser and not input.imePending)
    if not baseline then assert(not input:GetScript('OnUpdate')) end
    input:InputText('normal'); assert(changes == 2)
    input.composing = true; input:SetValue(input:GetText(), true)
    assert(input.imePending)
    input.composing = false; input:Fire('OnUpdate', .01)
    assert(changes == 3 and lastUser == false)
    input.composing = true; input:InputText('discard')
    input:SetValue('silent'); assert(not input.imePending and changes == 3)
    if not baseline then assert(not input:GetScript('OnUpdate')) end
    input.composing = true; input:InputText('hidden'); input:Hide()
    assert(not input.imePending)
    if not baseline then assert(not input:GetScript('OnUpdate')) end
    input:Show(); input:InputText('after show'); assert(changes == 4)
    -- Keep cancellation handles alive to prove that callbacks are detached.
    local resolver, reads, requests, completion = core.ItemResolver, 0, 0, 0
    core.Client.ReadItemInfo = function() reads = reads + 1; return nil, 'not-yet-scanned' end
    core.Client.RequestItemData = function() requests = requests + 1; return true end
    local handles, tokens = {}, setmetatable({}, { __mode = 'k' })
    for i = 1, 1000 do
        local token = {}; tokens[token] = true
        local handle = resolver:Request(100001, function() if token then error('cancelled callback') end end)
        handle:Cancel(); handle:Cancel(); handles[i] = handle
    end
    collectgarbage('collect'); collectgarbage('collect')
    local retained = 0; for _ in pairs(tokens) do retained = retained + 1 end
    print(target .. ': 1000 cancellations, retained callback tokens=' .. retained .. ', waiters=' .. #resolver.pending[100001].waiters)
    assert(requests == 1, 'cancel must not restart the native item request')
    if not baseline then assert(retained == 0 and #resolver.pending[100001].waiters == 0) end
    -- Joining the same pending ID retains its original timeout/coalescing.
    local a, b, c
    a = resolver:Request(100001, function() completion = completion + 1; b:Cancel() end)
    b = resolver:Request(100001, function() error('cancelled during completion') end)
    c = resolver:Request(100001, function() completion = completion + 1 end)
    resolver:Finish(100001, false)
    assert(completion == 2 and requests == 1 and not resolver.pending[100001])
    local failed = 0
    resolver:Request(100001, function(_, message) assert(message); failed = failed + 1 end)
    assert(failed == 1 and requests == 1, 'failed request still requires explicit retry')
    resolver:Request(100001, function() end, { retry = true }):Cancel()
    assert(requests == 2)
    -- A cancelled request still settles normally, keeping event/timeout semantics.
    resolver:Finish(100001, false)
    local timeout = resolver:Request(100002, function() error('cancelled timeout callback') end, { timeout = .2 })
    timeout:Cancel()
    local resolverFrame
    for _, frame in ipairs(env.TEST_FRAMES) do
        if frame.events and frame.events.GET_ITEM_INFO_RECEIVED and frame:GetScript('OnUpdate') then resolverFrame = frame end
    end
    assert(resolverFrame)
    resolverFrame:Fire('OnUpdate', .3)
    assert(not resolver.pending[100002] and resolver.failed[100002] and not resolverFrame:GetScript('OnUpdate'))
    -- A menu-free binding must not keep the 20Hz mouse-focus watcher alive.
    local actions = core.BusinessItemActions
    local first = env.CreateFrame('Button', nil, env.UIParent)
    local second = env.CreateFrame('Button', nil, env.UIParent)
    local function Options(menu) return { owner = core.NAME, GetIntent = function() return {} end, menu = menu } end
    actions:Bind(first, Options()); actions:Bind(second, Options(false))
    assert(actions.hoverFrame:IsShown())
    actions:Unbind(first)
    print(target .. ': watcher shown with only menu=false binding=' .. tostring(actions.hoverFrame:IsShown()))
    if not baseline then assert(not actions.hoverFrame:IsShown()) end
    actions:Bind(second, Options()); assert(actions.hoverFrame:IsShown())
    actions:Bind(second, Options(false))
    if not baseline then assert(not actions.hoverFrame:IsShown()) end
    actions:Bind(first, Options()); actions:Bind(second, Options())
    actions:Bind(second, Options()) -- Rebinding does not count the same control twice.
    actions:Unbind(first); assert(actions.hoverFrame:IsShown())
    actions:Unbind(second); assert(not actions.hoverFrame:IsShown())
end
print('PASS: idle/IME/silent/hide input lifecycle; cancelled callback release, coalescing, timeout/retry; menu watcher stop/rebind lifecycle')
