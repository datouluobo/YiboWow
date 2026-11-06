local timers = {}
securecallfunction = function(callback, ...) return callback(...) end
C_Timer = { After = function(_, callback) timers[#timers+1] = callback end }
SlashCmdList = {}
CreateFrame = function() return {RegisterEvent=function() end, SetScript=function() end} end
dofile('YiboCore/Libs/LibStub/LibStub.lua')
dofile('YiboCore/Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua')
dofile('YiboCore/Libs/LibDataBroker-1.1/LibDataBroker-1.1.lua')
YiboCore = {CheckAPIVersion=function() return true end, HasCapability=function() return true end, Print=function() end,
    Locale={Register=function() end, Get=function(_,_,key) return key end}}
local ldb = LibStub:GetLibrary('LibDataBroker-1.1')
local core = ldb:NewDataObject('YiboCore', {icon='old-core', yiboCoreEntryID='YiboCore'})
local other = ldb:NewDataObject('OtherAddon', {icon='other'})
assert(loadfile('_NonRelease/YiboIconBrokerProbe/Probe.lua'))('YiboIconBrokerProbe')
assert(core.icon=='old-core', 'formal addon assets remain active by default')
SlashCmdList.YIBOICONBROKERPROBE('on')
assert(core.icon:find('YiboCoreIcon%-64$'))
assert(other.icon=='other')
local late = ldb:NewDataObject('YiboMail', {icon='old-mail', yiboCoreEntryID='YiboMail'})
assert(late.icon:find('YiboMailIcon%-64$'))
core.icon='refreshed-core'
for _, callback in ipairs(timers) do callback() end
assert(core.icon:find('YiboCoreIcon%-64$'))
SlashCmdList.YIBOICONBROKERPROBE('32')
assert(core.icon:find('YiboCoreIcon%-32$'))
SlashCmdList.YIBOICONBROKERPROBE('off')
assert(core.icon=='refreshed-core' and late.icon=='old-mail')
SlashCmdList.YIBOICONBROKERPROBE('on')
assert(core.icon:find('YiboCoreIcon%-32$'))
print('PASS: existing / late Broker; refresh callback; size switch; restore; unrelated Broker unchanged')
