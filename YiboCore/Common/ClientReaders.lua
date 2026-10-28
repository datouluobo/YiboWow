local Core = _G.YiboCore
local function Pack(...) return { n = select("#", ...), ... } end
local function Text(value) return type(value) == "string" and value ~= "" end
local function Number(value) return type(value) == "number" and value == value and math.abs(value) < math.huge end

-- Shared value validation; native functions are supplied by the target binding.
function Core._private.CreateClientReader(resolve, options)
    local function Read(key, ...)
        local callback = resolve(key)
        if type(callback) ~= "function" then return nil, "unavailable" end
        local result = Pack(pcall(callback, ...))
        if not result[1] then return nil, "error" end
        local secret = resolve("IsSecret")
        if type(secret) == "function" then
            for index = 2, result.n do
                local ok, hidden = pcall(secret, result[index])
                if not ok or hidden then return nil, "unavailable" end
            end
        end
        return result
    end
    local reader = {}
    function reader.ReadGUID()
        local result, state = Read("GUID", "player")
        if not result then return nil, state end
        if result[2] == nil or result[2] == "" then return nil, "not-yet-scanned" end
        if not Text(result[2]) then return nil, "error" end
        return result[2], "known"
    end
    function reader.ReadNameRealm()
        local name, state = Read("Name", "player")
        if not name then return nil, state end
        local realm, other = Read("Realm")
        if not realm then return nil, other end
        if not Text(name[2]) or not Text(realm[2]) then return nil, "not-yet-scanned" end
        return { name = name[2], realm = realm[2] }, "known"
    end
    function reader.ReadCharacter()
        local guid, guidState = reader.ReadGUID()
        if not guid and guidState ~= "not-yet-scanned" then return nil, guidState end
        local row, state = reader.ReadNameRealm()
        if not row then return nil, state end
        local class, classState = Read("Class", "player")
        local level, levelState = Read("Level", "player")
        local now, timeState = Read("Time")
        if not class then return nil, classState end
        if not level then return nil, levelState end
        if not now then return nil, timeState end
        if not Text(class[3]) or not Number(level[2]) or level[2] < 1 then return nil, "not-yet-scanned" end
        if not Number(now[2]) then return nil, "error" end
        row.guid, row.class, row.level, row.observedAt = guid, class[3], level[2], now[2]
        return row, "known"
    end
    function reader.ReadIdentity(context)
        if Core._private.characterPending then return nil, "not-yet-scanned" end
        if options and options.directoryOnly then
            local row = context.character or {}
            if not Text(context.characterID) or not Text(row.name) or not Text(row.realm)
                or not Text(row.class) or not Number(row.level) or row.level < 1 then return nil, "not-yet-scanned" end
            return { id = context.characterID, name = row.name, realm = row.realm, class = row.class, level = row.level }, "known"
        end
        local race, raceState = Read("Race", "player")
        local faction, factionState = Read("Faction", "player")
        local sex, sexState = Read("Sex", "player")
        if not race then return nil, raceState end
        if not faction then return nil, factionState end
        if not sex then return nil, sexState end
        if not Text(race[2]) or not Text(faction[2]) or not Number(sex[2]) then return nil, "not-yet-scanned" end
        local guild, guildState = Read("Guild", "player")
        local membership, memberState = Read("InGuild")
        if guildState == "error" or memberState == "error" then return nil, "error" end
        if not membership then return nil, memberState end
        if type(membership[2]) ~= "boolean" then return nil, "not-yet-scanned" end
        local guildName = guild and guild[2]
        if guildName ~= nil and not Text(guildName) then return nil, "error" end
        if membership[2] == false then guildName = nil
        elseif not guildName then return nil, guildState or "not-yet-scanned" end
        local row = context.character or {}
        -- Preserve v1 race/faction representation (the native first result).
        -- Class uses the native second result above; no boolean expression truncates returns.
        return { id = context.characterID, name = row.name, realm = row.realm, class = row.class,
            level = row.level, race = race[2], faction = faction[2], sex = sex[2], guild = guildName }, "known"
    end
    function reader.ReadLocation()
        local zone, zoneState = Read("Zone")
        local subZone, subState = Read("SubZone")
        local map, mapState = Read("Map", "player")
        if not zone then return nil, zoneState end
        if not subZone then return nil, subState end
        if not map then return nil, mapState end
        if not Text(zone[2]) or type(subZone[2]) ~= "string" or not Number(map[2]) or map[2] <= 0 then
            return nil, "not-yet-scanned"
        end
        return { zone = zone[2], subZone = subZone[2], mapID = map[2] }, "known"
    end
    return reader
end
