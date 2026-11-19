-- Shared Mail models must consume Core metadata without a parallel native read.
GetItemInfo = function() error("Mail must not read native item info") end
CreateFrame = function() return {} end
dofile("YiboMail/Namespace.lua")
local addon = YiboMail
addon.T = function(_, key) return key end
local calls = 0
local metadata = {itemID=100, name="Item", link="item:100", icon=123, quality=4, classID=7, subclassID=0, state="ready"}
addon.Core = {ItemResolver={GetInfo=function(_,id) assert(id==100); calls=calls+1; return metadata end}}
ITEM_QUALITY_COLORS = {[4]={r=0.6,g=0.2,b=0.9}}
dofile("YiboMail/ViewModel.lua"); dofile("YiboMail/SendRules.lua"); dofile("YiboMail/Common/RuleCategories.lua")
local item=addon.SendRules:GetItem(100)
assert(item.ready and item.classID==7 and item.subclassID==0 and item.icon==123)
local color,pending=addon.ViewModel:ItemBorder({itemID=100})
assert(color[1]==0.6 and not pending and calls==2)
metadata={itemID=100,name="Item",state="ready"}
item=addon.SendRules:GetItem(100)
assert(item.ready and item.classID==nil and item.subclassID==nil,"missing class is unknown")
color,pending=addon.ViewModel:ItemBorder({itemID=100,itemLink="|cff0070dd|Hitem:100|h[Item]|h|r"})
assert(color[1]==0 and color[2]==112/255 and not pending,"saved-link fallback uses same metadata readiness")
metadata={itemID=100,state="unloaded"}
item=addon.SendRules:GetItem(100); assert(not item.ready and item.classID==nil)
color,pending=addon.ViewModel:ItemBorder({itemID=100}); assert(pending and color[1]==0.55)
assert(addon.SendRules:GetItem(0)==nil)
print("PASS: Core-only metadata reads, valid zero subclass, unknown/unloaded fields, quality/link borders")
