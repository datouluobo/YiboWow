local catalogPath = assert(arg[1], "usage: lua CompareCandidateCatalog.lua <catalog source> <anonymized sample> [sample...]")
local professionIDs = {
    ["急救"] = 1, ["锻造"] = 2, ["制皮"] = 3, ["炼金术"] = 4,
    ["烹饪"] = 6, ["采矿"] = 7, ["裁缝"] = 8, ["工程学"] = 9,
    ["附魔"] = 10, ["珠宝加工"] = 15, ["铭文"] = 16,
}

local catalog = {}
local inside = false
for line in io.lines(catalogPath) do
    if line:find("^local T_Recipe_Data = {%s*$") then inside = true
    elseif inside and line:find("^};%s*$") then break
    elseif inside then
        local id, expansion, phase, professionID = line:match("^%s*%[(%d+)%]%s*=%s*{%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)")
        if id then
            professionID = tonumber(professionID)
            catalog[professionID] = catalog[professionID] or {}
            catalog[professionID][tonumber(id)] = { expansion = tonumber(expansion), phase = tonumber(phase) }
        end
    end
end

local function Count(values)
    local count = 0
    for _ in pairs(values or {}) do count = count + 1 end
    return count
end

for sampleIndex = 2, #arg do
    local chunk = assert(loadfile(arg[sampleIndex]))
    local isolated = {}
    setfenv(chunk, isolated)
    local ok, samples = pcall(chunk)
    assert(ok and type(samples) == "table", "invalid anonymized sample")
    for _, sample in ipairs(samples) do
        local pid = professionIDs[sample.profession]
        if pid then
            local candidate = catalog[pid] or {}
            local outside, examples = 0, {}
            for _, id in ipairs(sample.recipeIDs or {}) do
                if not candidate[id] then
                    outside = outside + 1
                    if #examples < 8 then examples[#examples + 1] = id end
                end
            end
            print(string.format("session=%s profession=%s observed=%d candidate=%d observedOutsideCandidate=%d examples=%s",
                tostring(sample.session), sample.profession, #(sample.recipeIDs or {}), Count(candidate),
                outside, table.concat(examples, ",")))
        end
    end
end
