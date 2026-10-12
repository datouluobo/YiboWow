-- Run from the repository root using Lua 5.1. Searches may inspect cached
-- metadata, but must not request the thousands of missing catalog products.
local probes, lookups, requests = 0, 0, 0
YiboCore = { UITheme = { Colors = {}, Table = { rowHeight = 30 } },
    ItemResolver = { Request = function() requests = requests + 1 end } }
YiboCrafting = { Store = { GetRecipeState = function() return "learned" end } }
dofile("YiboCrafting/Tests/LoadLocale.lua")
YiboCore.ItemResolver.GetInfo = function(_, id) return {name=GetItemInfo(id)} end
C_Item = { IsItemDataCachedByID = function(id) probes = probes + 1; return id == 6001 end }
GetItemInfo = function(id)
    lookups = lookups + 1
    assert(id == 6001, "search must not load uncached item data")
    return "Cached lantern"
end
dofile("YiboCrafting/AccountPage.lua")
local entries = {}
for i = 1, 6000 do
    entries[i] = { id = i, professionID = 333, name = i == 1 and "魔法灯笼" or "Other recipe",
        outputItemIDs = { i }, directoryStatus = "provisional" }
end
entries[6001] = { id = 7001, professionID = 333, name = "Other recipe", outputItemIDs = {6001} }
local Page = YiboCrafting.AccountPage
assert(#Page:Filtered(entries, {}, {search="灯"}) == 1)
assert(requests == 0 and lookups == 1)
local firstProbes = probes
local started = os.clock()
for i = 1, 30 do
    assert(#Page:Filtered(entries, {}, {search="灯"}) == 1)
end
assert(probes == firstProbes and lookups == 1 and requests == 0, "repeated search must reuse item name cache")
assert(#Page:Filtered(entries, {}, {search="lantern"}) == 1, "cached product names remain searchable")
assert(#Page:Filtered(entries, {}, {search="6000"}) == 1, "item IDs remain searchable without data loading")
print(string.format("SearchPerformance OK: 6001 recipes, 30 repeats %.3fs, %d native item reads, %d requests", os.clock()-started, lookups, requests))
-- Replay item events through the actual page callback. Unrelated events must
-- not restart filtering; a burst of newly matching names schedules one paint.
local function Frame()
    return setmetatable({scripts={}}, {__index=function(_, key)
        if key == "SetScript" then return function(self, event, fn) self.scripts[event]=fn end end
        if key == "GetScript" then return function(self, event) return self.scripts[event] end end
        if key == "IsShown" then return function() return true end end
        if key == "CreateTexture" or key == "CreateFontString" then return Frame end
        return function() end
    end})
end
CreateFrame = Frame
local theme=YiboCore.UITheme
theme.Font={}; theme.Colors.panel={0,0,0,1}; theme.Colors.matrixLine={0,0,0,1}
for _, key in ipairs({"CreateText","CreateInput","CreateDropdown","CreateButton","CreateScrollFrame"}) do theme[key]=Frame end
theme.AttachClearButton=function() end
local timers, paints, eventReads = {}, 0, 0
C_Timer={After=function(_, fn) timers[#timers+1]=fn end}
local parent=Frame(); Page:Create(parent)
Page.RenderResults=function() paints=paints+1 end
Page.catalogItemIDs={[7002]=true,[7003]=true,[7004]=true}
parent.crafting.state.search="灯"
GetItemInfo=function(id) eventReads=eventReads+1; return id==7004 and "Unrelated name" or "魔法灯笼" end
local event=parent.crafting.itemEvents.scripts.OnEvent
for i=1,100 do event(nil,"GET_ITEM_INFO_RECEIVED",8000+i,true) end
assert(eventReads==0 and #timers==0, "other addons' item events must not repaint")
event(nil,"GET_ITEM_INFO_RECEIVED",7004,true)
assert(#timers==0, "nonmatching name must not repaint")
event(nil,"GET_ITEM_INFO_RECEIVED",7002,true)
event(nil,"GET_ITEM_INFO_RECEIVED",7003,true)
assert(#timers==1, "matching event burst is coalesced")
timers[1](); assert(paints==1)
for i=1,100 do event(nil,"GET_ITEM_INFO_RECEIVED",7002,true) end
assert(eventReads==3 and #timers==1 and paints==1, "repeated cached events cannot create a refresh loop")
print("Search item events OK: unrelated events ignored, one coalesced repaint, no cached-event loop")
