local Addon = _G.YiboMail
local Runtime = {}; Addon.RecipientRuntime = Runtime

function Runtime:ReadFriends(readyEvent)
    local api = _G.C_FriendList
    local countFn = api and api.GetNumFriends or _G.GetNumFriends
    local infoFn = api and api.GetFriendInfoByIndex or _G.GetFriendInfo
    if type(countFn) ~= "function" or type(infoFn) ~= "function" then return nil, "UI.TEXT_0221" end
    local ok, count = pcall(countFn)
    if not ok or type(count) ~= "number" or (count == 0 and not readyEvent) then return nil, "UI.TEXT_0215" end
    local entries = {}
    for index = 1, count do
        local success, info = pcall(infoFn, index)
        local name = type(info) == "table" and info.name or info
        if not success or type(name) ~= "string" or name == "" then return nil, "UI.TEXT_0216" end
        entries[#entries + 1] = name
    end
    local success, afterCount = pcall(countFn)
    if not success or afterCount ~= count then return nil, "UI.TEXT_0216" end
    return entries
end

function Runtime:RequestFriends()
    local show = _G.C_FriendList and C_FriendList.ShowFriends or _G.ShowFriends
    if type(show) == "function" then show() end
end

function Runtime:RequestGuild()
    if _G.C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster()
    elseif _G.GuildRoster then GuildRoster() end
end

function Runtime:ReadGuild()
    if not _G.IsInGuild or not IsInGuild() then return {} end
    if not _G.GetNumGuildMembers or not _G.GetGuildRosterInfo then return {}, "UI.TEXT_0141" end
    local count = GetNumGuildMembers(true)
    if type(count) ~= "number" or count == 0 then return {}, "UI.TEXT_0140" end
    local names = {}
    for index = 1, count do names[#names + 1] = GetGuildRosterInfo(index) end
    return names
end
