-- Read-only replay against saved snapshots; no game globals or SavedVariables are written.
-- Usage: lua Inspect.lua <SavedVariables-directory> [itemID] [snapshot-time]
local folder = assert(arg[1], 'SavedVariables directory required')
local itemID, now = tonumber(arg[2]) or 72095, tonumber(arg[3]) or os.time()
local function loadSaved(name)
    local chunk = assert(loadfile(folder .. '/' .. name .. '.lua'))
    local env = {}; setfenv(chunk, env); assert(pcall(chunk)); return env[name .. 'DB']
end
local db, coreDB = loadSaved('YiboMail'), loadSaved('YiboCore')
local characters = {}
for _, character in pairs(coreDB.characters.byID) do characters[#characters + 1] = character end
CreateFrame = function() return {} end
GetServerTime = function() return now end
dofile('YiboMail/Namespace.lua')
YiboMail.db = db
YiboMail.Core = { Characters = {
    GetAllCached = function() return characters end,
    FormatName = function(_, character) return character.name end,
} }
dofile('YiboMail/Recipients.lua'); dofile('YiboMail/Items.lua'); dofile('YiboMail/HistoryModel.lua')
if arg[4] == 'migrate' then
    dofile('YiboMail/Store.lua'); dofile('YiboMail/Mists/TransferMigration.lua')
    assert(YiboMail.Items:MigrateLegacyTransfers())
end
local visible = {}
for _, entry in ipairs(YiboMail.HistoryModel:Query({ characters = characters }, { days = 30, search = tostring(itemID) })) do
    if entry.record.eventID then visible[entry.record.eventID] = true end
    if entry.record.transferReview then
        print('REVIEW', entry.record.eventID, entry.character.name, entry.counterpart, entry.state)
    end
end
local total = 0
for _, character in ipairs(characters) do
    for _, record in ipairs(YiboMail.Items:GetTransfers(character.id).records) do
        if record.itemID == itemID then
            total = total + record.quantity
            local eventID = record.sourceID:match(':(h%d+):%d+$')
            print('TRANSFER', record.sourceID, 'quantity=' .. record.quantity,
                'sender=' .. tostring(record.senderName), 'recipient=' .. character.name .. '-' .. character.realm,
                'sentUTC=' .. os.date('!%Y-%m-%d %H:%M:%S', record.observedAt),
                'visibleIn30DayHistory=' .. tostring(visible[eventID] == true))
        end
    end
end
print('TOTAL', itemID, total, 'revision=' .. tostring(db.revision))
