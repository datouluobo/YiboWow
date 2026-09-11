local root = assert(arg[1], "pass the YiboMounts directory as the first argument")

function GetLocale()
    return "enUS"
end

local namespace = {}

local function Load(relativePath)
    local chunk = assert(loadfile(root .. "/" .. relativePath))
    chunk("YiboMounts", namespace)
end

Load("Namespace.lua")
Load("Locale/enUS.lua")
Load("Locale/zhCN.lua")
Load("Data/MountCatalog.generated.lua")
Load("Catalog.lua")
Load("SourceFormatter.lua")
Load("Probe.lua")
Load("InventoryProbe.lua")
Load("Tooltip.lua")
Load("_NonRelease/Tests/FormatterSmoke.lua")
Load("_NonRelease/Tests/TooltipStateSmoke.lua")
Load("_NonRelease/Tests/InventoryProbeSmoke.lua")

print("Lua smoke tests passed")
