for _, target in ipairs({ "Retail", "Mists" }) do
    WOW_PROJECT_MAINLINE, WOW_PROJECT_MISTS_CLASSIC = 1, 19
    WOW_PROJECT_ID = target == "Retail" and 19 or 1
    YiboBeastPaths, YiboBeastPathsDB, YiboBeastPathsDebugDB = nil, nil, nil
    local frames, ns = 0, {}
    CreateFrame = function() frames = frames + 1; error("wrong target created frame") end
    SlashCmdList = {}
    local path = target == "Retail" and "YiboBeastPaths/YiboBeastPaths_Mainline.toc"
        or "YiboBeastPaths/YiboBeastPaths_Mists.toc"
    for line in io.lines(path) do
        line = line:match("^%s*(.-)%s*$")
        if line:match("%.lua$") and not line:match("^Libs\\") then
            local source = "YiboBeastPaths/" .. line:gsub("\\", "/")
            assert(loadfile(source))("YiboBeastPaths", ns)
        end
    end
    assert(ns.YBP_TARGET_OK == false and frames == 0)
    assert(ns.ReadOfflinePets == nil)
    assert(YiboBeastPaths == nil and YiboBeastPathsDB == nil and YiboBeastPathsDebugDB == nil)
    assert(next(SlashCmdList) == nil)
end
-- A retained pre-1.9 target TOC can load the new shared files without loading
-- Target.lua. Simulate that missing marker on each supported client.
for _, project in ipairs({ 1, 19 }) do
    WOW_PROJECT_MAINLINE, WOW_PROJECT_MISTS_CLASSIC, WOW_PROJECT_ID = 1, 19, project
    YiboBeastPaths, YiboBeastPathsDB, YiboBeastPathsDebugDB = nil, nil, nil
    local ns, frames = {}, 0
    CreateFrame = function() frames = frames + 1; error("legacy chain created frame") end
    SlashCmdList = {}
    for line in io.lines("YiboBeastPaths/YiboBeastPaths_Mainline.toc") do
        line = line:match("^%s*(.-)%s*$")
        if line:match("%.lua$") and not line:match("^Libs\\")
            and not line:match("^Retail\\") and not line:match("^Common\\") then
            assert(loadfile("YiboBeastPaths/" .. line:gsub("\\", "/")))("YiboBeastPaths", ns)
        end
    end
    assert(frames == 0 and YiboBeastPaths == nil and YiboBeastPathsDB == nil and YiboBeastPathsDebugDB == nil)
    assert(next(SlashCmdList) == nil)
end
print("OfflinePetWrongTargetSpec: both targets stopped before business registration or writes")
