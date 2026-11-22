-- Probe: does the full BeastPaths package TOC load in the synthetic client?
local Boot = dofile('_NonRelease/YiboBeastPathsRelease-20261122/PackagedHarness.lua')
local DIR = '_NonRelease/YiboBeastPathsRelease-20261122/'
local target = arg[1] or 'Mists'
local toc = target == 'Retail' and 'YiboBeastPaths_Mainline.toc' or 'YiboBeastPaths_Mists.toc'
local Native = dofile(DIR .. 'Native.lua')
local r = Boot({ client = target, coreRoot = DIR .. 'Core-' .. target, addonName = 'YiboBeastPaths', addonRoot = DIR .. 'Clean-Universal',
  toc = toc, beforeAddon = Native.Setup, afterFile = Native.AfterFile })
r.fire('PLAYER_ENTERING_WORLD'); r.flush()
print('loaded', #r.loaded, r.env.YiboBeastPaths and 'ybp' or 'no-ybp', r.registrations.YiboBeastPaths, table.concat(r.env.TEST_MESSAGES, ' | '))
