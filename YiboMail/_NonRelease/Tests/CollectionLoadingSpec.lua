-- Load the actual manifest both cleanly and with legacy source paths retained.
local function Manifest(path)
    local entries, seen = {}, {}
    for line in io.lines(path) do
        local file = line:match("^%s*([^#%s].-)%s*$")
        if file then
            file = file:gsub("\\", "/")
            assert(not seen[file], "Duplicate load: " .. file)
            seen[file] = true; entries[#entries + 1] = file
            assert(loadfile("YiboMail/" .. file), "Missing or invalid source: " .. file)
        end
    end
    return entries, seen
end
local _, mists = Manifest("YiboMail/YiboMail.toc")
local foreverFile = io.open("YiboMail/YiboMail_Forever.toc", "r")
local forever
if foreverFile then
    foreverFile:close()
    _, forever = Manifest("YiboMail/YiboMail_Forever.toc")
end
assert(mists["Mists/Scanner.lua"] and mists["Mists/Queue.lua"])
assert(not mists["Scanner.lua"] and not mists["Queue.lua"])
if forever then
    assert(forever["Forever/Scanner.lua"] and not forever["Mists/Scanner.lua"] and not forever["Mists/Queue.lua"])
end
local realDofile, oldLoads = dofile, 0
for _, overlay in ipairs({ false, true }) do
    -- Each simulated installation starts with the startup harness's unloaded
    -- Blizzard UI; the previous run leaves a minimal IsShown-only mailbox.
    MailFrame, InboxFrame, OpenMailFrame = nil, nil, nil
    function dofile(path)
        if overlay and (path == "YiboMail/Scanner.lua" or path == "YiboMail/Queue.lua") then
            oldLoads = oldLoads + 1
            error("Legacy residual file executed: " .. path)
        end
        return realDofile(path)
    end
    dofile("YiboMail/_NonRelease/Tests/InboxReleaseSpec.lua")
end
dofile = realDofile
assert(oldLoads == 0)
print("PASS: actual Mists TOC clean/retained-old-file startup is idempotent; saved settings preserved; available target manifests isolated")
