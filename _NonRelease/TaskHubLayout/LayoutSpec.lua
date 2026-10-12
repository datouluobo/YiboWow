-- Run from repository root with Lua 5.1.
dofile("YiboTaskHub/_NonRelease/Tests/OverviewSpec.lua")
local Hub, checked = YiboTaskHub, 0
local function Equal(actual, expected, label)
    checked = checked + 1
    assert(actual == expected, label .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local h, header = Hub.Core.UITheme.Table.rowHeight, Hub.Core.UITheme.Table.headerHeight
local function CheckPages(rows, height)
    local first, last, _, pages = Hub.AccountPage:Slice(rows, 1, height)
    local expected = 1
    for page = 1, pages do
        first, last = Hub.AccountPage:Slice(rows, page, height)
        Equal(first, expected, "page starts immediately after prior page")
        local bars, previous = page == 1 and rows[first].section == "others" and 1 or 0, nil
        for i = first, last do
            if rows[i].section ~= previous then bars, previous = bars + 1, rows[i].section end
        end
        local bottom = h + 8 + header + (last - first + 1 + bars) * h
        Equal(bottom <= height - h - 8, true, "rows and section bars stay above footer")
        if last < #rows then
            local nextCost = h * (rows[last + 1].section == previous and 1 or 2)
            Equal(bottom + nextCost > height - h - 8, true, "next row cannot fit in unused space")
        end
        expected = last + 1
    end
    Equal(expected, #rows + 1, "all work appears exactly once across pages")
    local a, b, clamped = Hub.AccountPage:Slice(rows, pages + 20, height)
    Equal(clamped, pages, "stale page index clamps after resize")
    Equal(b, #rows, "final page reaches the last work item")
end
for _, height in ipairs({ 240, 420, 650 }) do
    local rows = {}
    for i = 1, 71 do rows[i] = { section = i <= 23 and "current" or "others" } end
    CheckPages(rows, height)
    for _, row in ipairs(rows) do row.section = "others" end
    CheckPages(rows, height)
end
local rows = {}; for i = 1, 40 do rows[i] = { section = "current" } end
local first, last = Hub.AccountPage:Slice(rows, 1, 420)
Equal(last - first + 1, 10, "single-section page uses previously reserved second heading slot")
local a, b, page, pages = Hub.AccountPage:Slice({}, 99, 420)
Equal(a, 1, "empty start"); Equal(b, 0, "empty end"); Equal(page, 1, "empty page"); Equal(pages, 1, "empty total")
print("TaskHubLayout: " .. checked .. " checks passed")
