-- Real target manifests: retain validation without reconstructing valid channels.
local baseline = arg and arg[1] == 'baseline'
local Boot = dofile('_NonRelease/CoreRetailR2/Harness.lua')
local function Equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return a == b end
    for k, v in pairs(a) do if not Equal(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
for _, target in ipairs({ 'Mists', 'Retail', 'Forever' }) do
    local env, core, fire, flush = Boot(target)
    fire('ADDON_LOADED'); fire('PLAYER_LOGIN'); flush()
    local view, config = core.AccountView, core.EntryConfig
    local entry = view:GetSettings().entry
    for i = 1, 20 do entry.businessChannels['Fixture' .. i] = { minimap = false, broker = true, builtinBar = false } end
    local before = core.Defaults:Copy(entry)
    local channels = entry.businessChannels.Fixture1
    local replacements = 0
    collectgarbage('collect'); collectgarbage('stop')
    local memory = collectgarbage('count')
    for i = 1, 1000 do
        local nextEntry = view:GetSettings().entry
        if nextEntry.businessChannels.Fixture1 ~= channels then replacements = replacements + 1 end
        channels = nextEntry.businessChannels.Fixture1
    end
    local allocated = collectgarbage('count') - memory
    collectgarbage('restart')
    print(string.format('%s: 1000 settings reads/20 channels, allocation=%.1f KB, channel replacements=%d', target, allocated, replacements))
    assert(Equal(entry, before), 'normalization must preserve all saved values')
    if not baseline then assert(replacements == 0) end
    -- Valid configs may still be directly edited. Every read must validate again.
    entry.businessChannels.Fixture1.broker = 'yes'
    entry.businessChannels.Fixture1.extra = true
    local repaired = view:GetSettings().entry.businessChannels.Fixture1
    assert(repaired.broker == false and repaired.extra == nil and repaired.minimap == false)
    entry.businessChannels.Fixture2 = false
    assert(Equal(view:GetSettings().entry.businessChannels.Fixture2, { minimap = false, broker = false, builtinBar = false }))
    local inherited = setmetatable({}, { __index = { minimap = true, broker = false, builtinBar = false } })
    local plain = config:Normalize({ coreChannels = inherited }).coreChannels
    assert(getmetatable(plain) == nil and plain.minimap, 'normalization still produces plain channel data')
    for bits = 0, 7 do
        local expected = { minimap = bits % 2 == 1, broker = math.floor(bits / 2) % 2 == 1, builtinBar = bits >= 4 }
        local result = config:Normalize({ coreChannels = expected }).coreChannels
        assert(Equal(result, expected))
    end
    -- Mode templates and public getters must remain detached mutable snapshots.
    for _, mode in ipairs({ 'none', 'broker', 'minimap', 'both' }) do
        local first, second = config:FromMode(mode), config:FromMode(mode)
        assert(first ~= second and Equal(first, second))
        first.broker = not first.broker
        assert(Equal(config:FromMode(mode), second))
    end
    local public = core.Entry:GetEntryChannels('Fixture3')
    public.broker = false
    assert(core.Entry:GetEntryChannels('Fixture3').broker == true)
    -- Unknown keys, legacy modes, normalization limits and direct edits retain old behavior.
    local legacy = config:Normalize({ coreMode = 'both', pageModes = { Old = 'minimap' },
        bar = { iconSize = 100, spacing = -10, order = { 'A', 'A', '', 'B' }, point = 'bad' } })
    assert(legacy.coreChannels.broker and legacy.coreChannels.minimap)
    assert(legacy.businessChannels.Old.minimap and not legacy.businessChannels.Old.broker)
    assert(legacy.bar.iconSize == 48 and legacy.bar.spacing == 0 and legacy.bar.point == 'TOP')
    assert(#legacy.bar.order == 2 and legacy.bar.order[1] == 'A' and legacy.bar.order[2] == 'B')
end
print('PASS: normalization allocation, direct-edit revalidation, all channel combinations, snapshot isolation and legacy limits')
