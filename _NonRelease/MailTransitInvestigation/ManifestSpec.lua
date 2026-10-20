local manifests = { "YiboMail.toc" }
local optional = io.open("YiboMail/YiboMail_Forever.toc", "r")
if optional then optional:close(); manifests[#manifests + 1] = "YiboMail_Forever.toc" end
for _, toc in ipairs(manifests) do
    local files, migration = {}, 0
    for line in io.lines("YiboMail/" .. toc) do
        local file = line:match("^%s*([^#%s].-)%s*$")
        if file then
            local key = file:gsub("\\", "/"):lower()
            assert(not files[key], "Duplicate load: " .. file); files[key] = true
            assert(loadfile("YiboMail/" .. file))
            if key == "mists/transfermigration.lua" then migration = migration + 1 end
        end
    end
    assert(migration == (toc == "YiboMail.toc" and 1 or 0), "Target migration load boundary")
end
print("PASS: available target manifests; all loaded Lua syntax; no duplicate references; migration only on Mists")
