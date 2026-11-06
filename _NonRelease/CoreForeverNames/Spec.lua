-- Real manifests and collectors, synthetic native names; no player saves touched.
local SourceBoot = dofile('_NonRelease/CoreRetailR2/Harness.lua')
local function Boot(target, saved, project, configure)
    return SourceBoot(target, saved, project, configure, nil,
        target == 'Forever' and arg and arg[1] or nil,
        target == 'Forever' and arg and arg[1] and 'YiboCore.toc' or nil)
end
local checks = 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
for _, language in ipairs({ 'zhCN', 'enUS' }) do
    local e, core, fire, flush = Boot('Forever', nil, nil, function(env)
        env.UnitName = function() return '天堂暴风', '乘风归' end
        env.GetRealmName = function() return 'CN1 Realm 8 PvE' end
        env.GetLocale = function() return language end
    end)
    fire('ADDON_LOADED'); fire('PLAYER_LOGIN'); flush()
    Check(core:IsInitialized(), 'Core ready')
    local character = core.Characters:GetCurrent()
    local id = character.id
    Check(character.name == '天堂暴风 乘风归', 'native complete name collected')
    Check(character.realm == 'CN1 Realm 8 PvE', 'native realm retained as metadata')
    Check(core.Characters:FormatName(character, { realmMode = 'full' }) == character.name, 'complete identity display')
    Check(core.Characters:FormatName(character, { realmMode = 'sameRealm', referenceRealm = 'Elsewhere' }) == character.name, 'regional display policy')
    Check(core.Characters:SetShortName(id, '小德') == '小德', 'short name preference')
    Check(core.Characters:FormatName(character, { nameMode = 'short', realmMode = 'full' }) == '小德', 'short display uses GUID preference')
    Check(core.Characters:FormatName(character, { realmMode = 'full' }) == '天堂暴风 乘风归', 'exact identity retains both names')
    local field = core.Fields._definitions['character.identity']
    Check(field.Format(character) == '天堂暴风 乘风归', 'archive public name formatter')
    core.AccountView:ShowPage('characters'); flush()
    Check(not core.AccountView._pages.characters.lastError, 'real archive renderer')
    local theme = core.UITheme
    local capture = {}
    theme.SetMatrixHeader = function(_, _, name, options) capture.name, capture.secondary = name, options.secondary end
    theme.BindTooltip = function(_, _, title) capture.title = title end
    theme:SetCharacterHeader({}, character, { scope = 'all' })
    Check(capture.name == '小德' and capture.secondary == nil, 'shared header omits technical realm')
    Check(capture.title == '天堂暴风 乘风归', 'shared tooltip complete identity')
    Check(theme:GetCharacterHeaderHeight({ scope = 'all' }) == theme.Table.headerHeight, 'header has no empty realm line')
    e.Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR = '·'
    core.Characters:RefreshCurrent()
    Check(core.Characters:GetCurrent().name == '天堂暴风·乘风归', 'native separator respected')
    Check(core.Characters:GetCurrentID() == id and #core.Characters:GetAll() == 1, 'same GUID updates existing record')
    e.UnitName = function() return 'Already Complete' end
    core.Characters:RefreshCurrent()
    Check(core.Characters:GetCurrent().name == 'Already Complete', 'native single-result full name preserved')
    e.NameUtil = nil
    Check(core.Characters:RefreshCurrent() == nil, 'missing native utility does not fabricate a name')
    Check(core.Characters:GetCurrent().name == 'Already Complete', 'unavailable name preserves saved observation')
    local saved = core.Defaults:Copy(core.Database:GetDB())
    local _, restored, event = Boot('Forever', saved, nil, function(env)
        env.UnitName = function() return '天堂暴风', '乘风归' end
        env.GetRealmName = function() return 'CN1 Realm 8 PvE' end
    end)
    event('ADDON_LOADED')
    Check(restored.Characters:GetCurrentID() == id and #restored.Characters:GetAll() == 1, 'synthetic restart keeps GUID identity')
    Check(restored.Characters:FormatName(restored.Characters:GetCurrent(), { nameMode = 'short' }) == '小德', 'short preference survives refresh and restart')
end
do
    local e, core, event = Boot('Forever', nil, nil, function(env)
        env.UnitName = function() return 'Same', 'First' end
    end)
    event('ADDON_LOADED')
    local firstID = core.Characters:GetCurrentID()
    e.TEST_GUID = 'Player-Second-Name'
    e.UnitName = function() return 'Same', 'Second' end
    core.Characters:RefreshCurrent()
    Check(#core.Characters:GetAll() == 2, 'same first name does not merge different GUIDs')
    Check(core.Characters:Get(firstID).name == 'Same First', 'first surname snapshot retained')
    Check(core.Characters:GetCurrent().name == 'Same Second', 'second surname collected independently')
    e.UnitName = function() error('native unavailable') end
    Check(core.Characters:RefreshCurrent() == nil, 'native name error stops update')
    Check(core.Characters:GetCurrent().name == 'Same Second', 'native name error preserves observation')
end
for _, target in ipairs({ 'Mists', 'Retail' }) do
    local _, core, event = Boot(target)
    event('ADDON_LOADED')
    local character = core.Characters:GetCurrent()
    Check(core.Characters:FormatName(character, { realmMode = 'full' }) == 'ProbeCharacter-ProbeRealm', target .. ' realm display preserved')
    Check(core.UITheme:GetCharacterHeaderHeight({ scope = 'all' }) == core.UITheme.Table.characterHeaderHeight, target .. ' realm header preserved')
end
print('PASS Forever native full names: ' .. checks .. ' checks; actual surname API/rendering pending reload')
