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

function Items:Add(info)
    local id, name = info.itemID, info.name
    if not Addon.Store:ItemID(id) or type(name) ~= "string" or name == "" then return false end
    local settings = Addon.Store.db.settings
    settings.customItems = settings.customItems or {}
    if settings.customItems[id] then return false end
    settings.customItems[id] = name
    Addon.Scanner:Request(false, true)
    Addon:NotifyChanged()
    return true
end

function Items:Remove(id)
    local settings = Addon.Store.db.settings
    if not Addon.Store:Items()[id] then return false end
    settings.customItems[id] = nil
    settings.previewColumns["item:" .. id] = nil
    Addon.Store:ClearItemSession(id)
    Addon:NotifyChanged()
    return true
end

function Items:CreateSettingsPanel(parent, context)
    if not parent.currencyCustomItems then
        local core = Addon.Core
        local heading = core.UITheme:CreateText(parent, core.UITheme.Font.section, core.UITheme.Colors.text)
        heading:SetPoint("TOPLEFT"); heading:SetPoint("TOPRIGHT"); heading:SetHeight(24)
        heading:SetText(Addon:T("UI.CATALOG_MANAGE"))
        local catalog = core.UITheme:CreateDropdown(parent, 240)
        catalog:SetPoint("TOPLEFT", 0, -28)
        catalog:SetMenuPageSize(8)
        parent.currencyCatalog = catalog
        local function Missing(info)
            if Addon.Store:Items()[info.itemID] then return false, Addon:T("FOREVER.CUSTOM_DUPLICATE") end
            return true
        end
        local function Present(info)
            return Addon.Store:Items()[info.itemID] ~= nil, Addon:T("FOREVER.CUSTOM_NOT_FOUND")
        end
        parent.currencyCustomItems = core:CreateItemPicker(parent, {
            placeholder = Addon:T("FOREVER.CUSTOM_ID"), candidateDropdown = false,
            resolve = { allowID = true, allowLink = false, allowName = false },
            add = {
                label = Addon:T("UI.CATALOG_ADD"), Validate = Missing,
                Confirm = function(info)
                    return Addon:T("CURRENCY.ADD_S_ITEMID_S_TO_THE_CUSTOM_CURRENCY_CATALOG_A3D0C3", info.name, tostring(info.itemID))
                end,
                Execute = function(info)
                    if not Items:Add(info) then return false, Addon:T("FOREVER.CUSTOM_DUPLICATE") end
                    return true, Addon:T("UI.CUSTOM_ADDED", info.name)
                end,
            },
            remove = {
                label = Addon:T("UI.CATALOG_REMOVE"), Validate = Present,
                Confirm = function(info)
                    return Addon:T("FOREVER.CUSTOM_REMOVE_CONFIRM", info.name, tostring(info.itemID))
                end,
                Execute = function(info)
                    if not Items:Remove(info.itemID) then return false, Addon:T("FOREVER.CUSTOM_NOT_FOUND") end
                    return true, Addon:T("UI.CUSTOM_REMOVED", info.name)
                end,
            },
        })
        catalog:SetOnValueChanged(function(id)
            if Addon.Store:Items()[id] then parent.currencyCustomItems:SetValue(tostring(id)) end
        end)
    end
    local catalog = parent.currencyCatalog
    local picker = parent.currencyCustomItems
    local options = {}
    for id, name in pairs(Addon.Store:Items()) do
        options[#options + 1] = { value = id, label = Addon:T("FOREVER.CUSTOM_ITEM_LABEL", name, tostring(id)) }
    end
    table.sort(options, function(a, b) return a.value < b.value end)
    local hasItems = #options > 0
    catalog:SetWidth(math.max(1, math.min(360, parent:GetWidth())))
    catalog:SetOptions(options)
    local selected = tonumber(picker.input:GetText())
    if selected and Addon.Store:Items()[selected] then
        catalog:SetValue(selected)
    else
        catalog:SetValue(nil)
        catalog:SetText(Addon:T(hasItems and "FOREVER.CUSTOM_CHOOSE" or "FOREVER.CUSTOM_EMPTY"))
    end
    catalog:SetEnabled(hasItems)
    catalog:SetState(hasItems and "default" or "disabled")
    picker:ClearAllPoints(); picker:SetPoint("TOPLEFT", catalog, "BOTTOMLEFT", 0, -8); picker:Show()
    picker.config.OnLayoutChanged = nil
    local height = picker:Layout(parent:GetWidth())
    picker.config.OnLayoutChanged = context.refreshPanel
    picker.config.OnSuccess = context.refreshPanel
    return height + 36 + catalog:GetHeight()
end
