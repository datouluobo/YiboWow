local Addon = _G.YiboCurrency
local Items = {}
Addon.CustomItems = Items

local function VaultSource(result, source, id)
    local coverage = result.coverage[source]
    local row = type(coverage)=="table" and coverage[id]
    local locations = type(row)=="table" and row.locations
    if type(locations)~="table" or not next(locations) then return end
    local stale = false
    for _, location in pairs(locations) do
        if type(location)~="table" or location.completedScan~=true then return end
        if location.status=="stale" then stale=true
        elseif location.status~="known" and location.status~="known-empty" then return end
    end
    local count = result.totals.bySource[source]
    if count==nil then count=0 end
    if Addon.Store:Count(count) then return count,not stale end
end

function Items:GetVaultDetails(id, itemID)
    if not id or id~=Addon.Core.Characters:GetCurrentID() or not Addon.Store:Items()[itemID] then return end
    local core=Addon.Core
    local contracts=core.Contracts
    if not core:HasCapability("business-services",1) or not contracts
        or type(contracts.Resolve)~="function" or type(contracts.Call)~="function" then return end
    local descriptor=contracts:Resolve("vault.items",{major=1,minMinor=1})
    if not descriptor then return end
    local function Supports(name)
        return contracts:Call(Addon.NAME,descriptor,"HasCapability",{name=name,minimumVersion=1})==true
    end
    if not Supports("items.query") or not Supports("items.state") then return end
    local sources={}
    for _, source in ipairs({"equipment","bank"}) do
        if Supports("source."..source) then sources[#sources+1]=source end
    end
    if #sources==0 then return end
    local result=contracts:Call(Addon.NAME,descriptor,"Query",{
        scope={mode="characters",characterIDs={id}},itemID=itemID,identityMode="item-id",sources=sources,includeStale=true,
    })
    if type(result)~="table" or type(result.coverage)~="table" or type(result.totals)~="table"
        or type(result.totals.bySource)~="table" then return end
    local detail={}
    for _, source in ipairs(sources) do
        local count,fresh=VaultSource(result,source,id)
        detail[#detail+1]={source=source,count=count,fresh=fresh}
    end
    return detail
end

Addon.CatalogPickerOptions = {
    placeholderKey = "FOREVER.CUSTOM_ID",
    helpKey = "FOREVER.CATALOG_MANAGE_HINT",
    hoverHintKey = "FOREVER.CATALOG_HOVER_HINT",
    resolve = { allowID = true, allowLink = false, allowName = false },
    candidateDropdown = false,
}
Addon.showTransposeAboveCatalog = true
Addon.bindNativeGoalsInSettings = true

function Addon:GetSettings()
    return self.Store.db.settings
end

function Addon:GetCustomItem(id)
    local name = self.Store:Items()[id]
    if name then return { id = "item:" .. id, itemID = id, title = name } end
end

function Addon:AddCatalogItem(info)
    local id, name = info.itemID, info.name
    if not self.Store:ItemID(id) or type(name) ~= "string" or name == "" then
        return nil, self:T("CURRENCY.ENTER_A_VALID_ITEMID_0CEB2F")
    end
    if self:GetCustomItem(id) then return nil, self:T("FOREVER.CUSTOM_DUPLICATE") end
    local settings = self:GetSettings()
    settings.customItems = settings.customItems or {}
    settings.customItems[id] = name
    self.Scanner:Request(false, true)
    return self:GetCustomItem(id)
end

function Addon:RemoveCustomItem(id)
    local entry = self:GetCustomItem(id)
    if not entry then return nil, self:T("FOREVER.CUSTOM_NOT_FOUND") end
    local settings = self:GetSettings()
    settings.customItems[id] = nil
    settings.previewColumns[entry.id] = nil
    self.Store:ClearItemSession(id)
    _G.YiboCore.AccountView:SetFieldVisible(self.PAGE_ID, entry.id, true)
    return entry
end
