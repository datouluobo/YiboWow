local root, tests = assert(arg[1]), assert(arg[2])
function GetLocale() return "enUS" end
local ns = {}
for line in io.lines(root .. "/YiboMounts.toc") do
    local path = line:match("^%s*(.-%.lua)%s*$")
    if path and path ~= "Bootstrap.lua" then
        path = path:gsub("\\", "/")
        assert(loadfile(root .. "/" .. path))("YiboMounts", ns)
    end
end
for _, name in ipairs({"FormatterSmoke", "TooltipStateSmoke", "AuraTooltipSmoke", "InventoryProbeSmoke"}) do
    assert(loadfile(tests .. "/" .. name .. ".lua"))("YiboMounts", ns)
end
print("Packaged Lua regression passed: " .. root)
