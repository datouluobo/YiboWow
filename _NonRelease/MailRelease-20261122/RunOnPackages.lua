-- Usage: lua RunOnPackages.lua <spec.lua> <Addon>:<Target>=<root> ...
-- Runs an existing real-manifest spec with Core/addon manifests redirected to extracted package roots.
local R = dofile("_NonRelease/MailRelease-20261122/Redirect.lua")
local spec = assert(arg[1], "spec path required")
local mapping, specArgs = {}, nil
for i = 2, #arg do
    if specArgs then specArgs[#specArgs + 1] = arg[i]
    elseif arg[i] == "--" then specArgs = {}
    else
        local addon, target, root = arg[i]:match("^(Yibo%w+):(%w+)=(.+)$")
        assert(addon, "bad mapping " .. arg[i])
        R.roots[addon] = R.roots[addon] or {}
        R.roots[addon][target] = root
        mapping[#mapping + 1] = root
    end
end
if specArgs then specArgs[0] = spec; arg = specArgs end
R.Install()
dofile(spec)
R.Uninstall()
local usedByAddon = {}
for addon, roots in pairs(R.roots) do
    for target, root in pairs(roots) do
        local files = R.LoadCounts(root .. "/")
        usedByAddon[addon] = (usedByAddon[addon] or 0) + files
        print(("  package root %s:%s %s (%d distinct files)"):format(addon, target, root, files))
    end
end
for addon in pairs(R.roots) do assert(usedByAddon[addon] > 0, "no package root used for " .. addon) end
print("REDIRECTED-PASS: " .. spec)
