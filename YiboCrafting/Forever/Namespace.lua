local Addon={NAME="YiboCrafting",VERSION="0.1.2",PAGE_ID="crafting"}
_G.YiboCrafting=Addon
Addon.Frame=CreateFrame("Frame")
function Addon:T(key,...) return _G.YiboCore.Locale:Get(self.NAME,key,...) end
function Addon:Print(message) if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff20e070[Yibo] YiboCrafting:|r "..tostring(message)) end end
function Addon:NotifyChanged() if self.Core then self.Core.AccountView:NotifyPageChanged(self.PAGE_ID) end end
function Addon:GetProfessionProfile()
    local id=self.Core and self.Core.Characters:GetCurrentID()
    return id and self.Core.DataDomains:Get(id,"professions")
end
function Addon:OwnsProfession(id)
    local profile=self:GetProfessionProfile()
    if not profile or profile.state~="known" then return false end
    for _,row in ipairs(profile.data.professions or {}) do if row.id==id then return true end end
    return false
end
