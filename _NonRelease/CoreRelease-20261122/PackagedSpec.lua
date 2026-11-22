-- Core 1.13.0 / 0.3.0 / 0.2.0 (API14) release replay from the actual CurseForge zips.
-- Run from repository root: lua _NonRelease/CoreRelease-20261122/PackagedSpec.lua
local Boot = dofile('_NonRelease/CoreRetailR2/Harness.lua')
local checks = 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
local versions = { Mists = '1.13.0', Forever = '0.3.0', Retail = '0.2.0' }
local stores = { Mists = 'YiboCoreDB', Forever = 'YiboCoreForeverDB', Retail = 'YiboCoreRetailDB' }
local roots = {}
for _, target in ipairs({ 'Mists', 'Forever', 'Retail' }) do
  roots[#roots + 1] = { target, '_NonRelease/CoreRelease-20261122/Clean-' .. target .. '/YiboCore', 'clean' }
  if target ~= 'Retail' then roots[#roots + 1] = { target, '_NonRelease/CoreRelease-20261122/Overlay-' .. target .. '/YiboCore', 'overlay' } end
end
for _, item in ipairs(roots) do
  local target, root, kind = item[1], item[2], item[3]
  for _, mode in ipairs({ { 'zhCN', 'auto', 'zh' }, { 'enUS', 'auto', 'en' }, { 'zhCN', 'en', 'en' } }) do
    -- An existing store from the previous release of the same target: stamped
    -- with its client scope (Retail refuses unstamped foreign stores by design).
    local projects = { Mists = 19, Forever = 18, Retail = 1 }
    local saved = { marker = 'keep', settings = { language = mode[2] }, schemaVersion = 11,
      clientScope = { target = target, projectID = projects[target], rulesetState = 'unknown' }, characters = { byID = {} } }
    local e, c, fire, flush = Boot(target, saved, nil, function(env) env.GetLocale = function() return mode[1] end end, nil, root, 'YiboCore.toc')
    local ready = 0; c.Events:Register('CORE_READY', {}, function() ready = ready + 1 end)
    fire('ADDON_LOADED'); fire('ADDON_LOADED'); fire('PLAYER_LOGIN'); flush()
    local tag = target .. '/' .. kind .. '/' .. mode[1] .. '/' .. mode[2] .. ': '
    Check(c:IsInitialized(), tag .. 'package ready')
    Check(c.VERSION == versions[target], tag .. 'target version ' .. tostring(c.VERSION))
    Check(c.API_VERSION == 14 and c:HasCapability('pixel-line', 1) and c:HasCapability('localization', 1), tag .. 'API14 capabilities')
    Check(type(c.UITheme.SetPixelAnchor) == 'function' and type(c.UITheme.CreatePixelBorder) == 'function', tag .. 'public pixel API')
    Check(c.Database:GetDB() == e[stores[target]] and saved.marker == 'keep', tag .. 'own store preserved')
    for other, name in pairs(stores) do
      if other ~= target then Check(e[name].sentinel ~= nil and e[name].characters == nil, tag .. 'other store untouched ' .. name) end
    end
    Check(ready == 1, tag .. 'one ready notification')
    Check(c:Initialize() and ready == 1, tag .. 'repeat initialization')
    Check(c.Locale:GetLanguage() == mode[3], tag .. 'language mode')
    c.AccountView:ShowPage('characters'); flush(); Check(not c.AccountView._pages.characters.lastError, tag .. 'archive rendering')
    c.AccountView:ShowSettings('sorting'); flush(); Check(not c.AccountView._pages.settings.lastError, tag .. 'settings rendering')
    c.UITheme:RefreshPixelLines(); flush()
    local copy = c.Defaults:Copy(c.Database:GetDB())
    local re, rc, rf, rt = Boot(target, copy, nil, function(env) env.GetLocale = function() return mode[1] end end, nil, root, 'YiboCore.toc')
    rf('ADDON_LOADED'); rf('PLAYER_LOGIN'); rt()
    Check(rc:IsInitialized() and rc.Locale:GetLanguage() == mode[3] and copy.marker == 'keep', tag .. 'snapshot restore')
    Check(#e.TEST_MESSAGES == 0 and #re.TEST_MESSAGES == 0, tag .. 'no callback failures')
  end
  for wrong in pairs(versions) do
    if wrong ~= target then
      local e, c, fire = Boot(wrong, nil, nil, nil, nil, root, 'YiboCore.toc'); fire('ADDON_LOADED')
      Check(not c:IsInitialized() and not c.Database:GetDB(), target .. '/' .. kind .. ' installed on ' .. wrong .. ' stops before store')
    end
  end
end
print('PASS Core API14 packaged clean/overlay: ' .. checks .. ' checks')
