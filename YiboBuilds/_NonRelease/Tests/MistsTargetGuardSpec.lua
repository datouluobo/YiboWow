-- Run from repository root: lua YiboBuilds/_NonRelease/Tests/MistsTargetGuardSpec.lua
WOW_PROJECT_CAMELOT, WOW_PROJECT_ID = 99, 99
local saved = { retained = true }
YiboBuildsDB = saved
YiboCore = setmetatable({}, {__index = function() error("Mists queried Core on Forever") end})
CreateFrame = function() error("Mists registered a frame on Forever") end
local files = 0
for line in io.lines("YiboBuilds/YiboBuilds.toc") do
    local path = line:match("^([^#].-%.lua)%s*$")
    if path then
        dofile("YiboBuilds/" .. path:gsub("\\", "/"))
        files = files + 1
    end
end
assert(files > 0 and YiboBuilds.VERSION == "1.5.1")
assert(YiboBuildsDB == saved and saved.retained and next(saved, "retained") == nil)
assert(not YiboBuilds.Snapshot and not YiboBuilds.AccountPage and not YiboBuilds.Gems and not YiboBuilds.SocketReader)
print("MistsTargetGuardSpec passed: " .. files .. " TOC files, no frames/Core queries/SavedVariables writes")
