local Core = _G.YiboCore
local Config = {}
Core.EntryConfig = Config
local modes = { none = {}, broker = {broker=true}, minimap = {minimap=true}, both = {broker=true,minimap=true} }
local function Channels(value, fallback)
    value = type(value) == "table" and value or fallback or {}
    return { minimap=value.minimap == true, broker=value.broker == true, builtinBar=value.builtinBar == true }
end
function Config:FromMode(mode) return Channels(modes[mode]) end
function Config:Normalize(entry)
    entry = type(entry) == "table" and entry or {}
    entry.minimap = type(entry.minimap) == "table" and entry.minimap or {show=true,angle=225}
    entry.broker = type(entry.broker) == "table" and entry.broker or {show=true}
    entry.pageModes = type(entry.pageModes) == "table" and entry.pageModes or {}
    entry.pagePositions = type(entry.pagePositions) == "table" and entry.pagePositions or {}
    if type(entry.coreChannels) ~= "table" then
        entry.coreChannels = modes[entry.coreMode] and self:FromMode(entry.coreMode) or Channels({minimap=entry.minimap.show ~= false,broker=entry.broker.show ~= false})
    end
    entry.coreChannels = Channels(entry.coreChannels)
    entry.businessChannels = type(entry.businessChannels) == "table" and entry.businessChannels or {}
    for id, mode in pairs(entry.pageModes) do
        if entry.businessChannels[id] == nil then entry.businessChannels[id] = self:FromMode(mode) end
    end
    for id, value in pairs(entry.businessChannels) do entry.businessChannels[id] = Channels(value) end
    local bar = type(entry.bar) == "table" and entry.bar or {}
    entry.bar = bar
    bar.enabled = bar.enabled == true
    bar.locked = bar.locked ~= false
    bar.showNames = bar.showNames == true
    bar.showBorder = bar.showBorder ~= false
    local backgrounds = {theme=true,black=true,charcoal=true,navy=true,forest=true}
    bar.background = backgrounds[bar.background] and bar.background or "theme"
    local order,seen = {},{}
    for _,id in ipairs(type(bar.order) == "table" and bar.order or {}) do
        if type(id) == "string" and id ~= "" and not seen[id] then order[#order+1]=id;seen[id]=true end
    end
    bar.order = order
    local function Number(value, default, low, high)
        value = tonumber(value)
        if not value or value ~= value then value = default end
        return math.max(low, math.min(high, value))
    end
    bar.backgroundAlpha = Number(bar.backgroundAlpha,0.95,0,1)
    bar.iconSize = Number(bar.iconSize,24,16,48)
    bar.spacing = Number(bar.spacing,6,0,20)
    local points = {TOP=true,TOPLEFT=true,TOPRIGHT=true,CENTER=true,LEFT=true,RIGHT=true,BOTTOM=true,BOTTOMLEFT=true,BOTTOMRIGHT=true}
    bar.point = points[bar.point] and bar.point or "TOP"
    bar.relativePoint = points[bar.relativePoint] and bar.relativePoint or "TOP"
    bar.x = Number(bar.x,0,-10000,10000); bar.y = Number(bar.y,-16,-10000,10000)
    entry.previewPageID = type(entry.previewPageID) == "string" and entry.previewPageID or "overview"
    entry.showPreviewWhileMainWindowOpen = entry.showPreviewWhileMainWindowOpen == true
    entry.channelsVersion = 1
    return entry
end
