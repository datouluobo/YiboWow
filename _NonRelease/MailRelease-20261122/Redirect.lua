-- Redirect source-tree manifest reads to extracted player-package roots.
-- Source target manifests (<Addon>_<Target>.toc) map to the package default <Addon>.toc of the configured root;
-- subsequent "<Addon>/<file>" loads come from the root selected by the last manifest opened for that addon.
-- The default hint manifest (<Addon>.toc) and unconfigured addons stay on the source tree.
local R = { roots = {}, active = {}, loads = {}, realLines = io.lines, realLoadfile = loadfile }
local function Split(path)
    local addon, rest = path:match("^(Yibo%w+)/(.+)$")
    return addon, rest
end
function R.Install()
    io.lines = function(path, ...)
        local addon, rest = Split(path or "")
        local roots = addon and R.roots[addon]
        if roots then
            local target = rest:match("^" .. addon .. "_(%w+)%.toc$")
            if target and roots[target] then
                R.active[addon] = roots[target]
                return R.realLines(roots[target] .. "/" .. addon .. ".toc")
            elseif rest == addon .. ".toc" then
                R.active[addon] = nil
            end
        end
        return R.realLines(path, ...)
    end
    loadfile = function(path, ...)
        local addon, rest = Split(path or "")
        local root = addon and R.active[addon]
        if root then
            local key = root .. "/" .. rest
            R.loads[key] = (R.loads[key] or 0) + 1
            return R.realLoadfile(key, ...)
        end
        return R.realLoadfile(path, ...)
    end
end
function R.Uninstall() io.lines, loadfile = R.realLines, R.realLoadfile end
function R.ResetLoads() R.loads = {} end
function R.LoadCounts(prefix)
    local files, duplicates = 0, {}
    for key, count in pairs(R.loads) do
        if key:sub(1, #prefix) == prefix then
            files = files + 1
            if count ~= 1 then duplicates[#duplicates + 1] = key .. "=" .. count end
        end
    end
    return files, duplicates
end
return R
