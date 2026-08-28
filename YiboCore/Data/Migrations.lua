local Core = _G.YiboCore

local Migrations = {}
Core.Migrations = Migrations

Migrations.CURRENT_SCHEMA = 8
Migrations._steps = Migrations._steps or {}

function Migrations:Register(version, callback)
    version = tonumber(version)
    if not version or version < 1 or type(callback) ~= "function" then
        error("YiboCore.Migrations:Register requires a positive version and callback.")
    end
    self._steps[version] = callback
end

function Migrations:Run(db)
    local current = tonumber(db.schemaVersion) or 0
    if current > self.CURRENT_SCHEMA then
        return false, "YiboCore 数据版本高于当前插件版本。"
    end

    for version = current + 1, self.CURRENT_SCHEMA do
        local step = self._steps[version]
        if not step then
            return false, "缺少数据库迁移步骤 v" .. version .. "。"
        end
        step(db)
        db.schemaVersion = version
        db.migrationHistory = db.migrationHistory or {}
        db.migrationHistory[version] = (GetServerTime and GetServerTime()) or time()
    end
    return true
end

Migrations:Register(1, function(db)
    db.characters = db.characters or {}
    db.characters.byID = db.characters.byID or {}
    db.characters.aliases = db.characters.aliases or {}
    db.characters.seenOrder = db.characters.seenOrder or {}
    db.settings = db.settings or {}
end)

Migrations:Register(2, function(db)
    db.settings = db.settings or {}
    db.settings.accountView = db.settings.accountView or {}
    db.settings.accountView.pages = db.settings.accountView.pages or {}
    db.settings.accountView.fields = db.settings.accountView.fields or {}
    db.settings.accountView.hiddenCharacters = db.settings.accountView.hiddenCharacters or {}
end)

Migrations:Register(3, function(db)
    db.settings = db.settings or {}
    db.settings.accountView = db.settings.accountView or {}
    local view = db.settings.accountView
    view.width = tonumber(view.width) or 1120
    view.height = tonumber(view.height) or 650
    view.entry = view.entry or {}
    view.entry.minimap = view.entry.minimap or { show = true, angle = 225 }
    view.entry.broker = view.entry.broker or { show = true }
    view.entry.pageModes = view.entry.pageModes or {}
    view.characterSort = view.characterSort or "seen"
end)

Migrations:Register(4, function(db)
    db.settings = db.settings or {}
    db.settings.accountView = db.settings.accountView or {}
    local entry = db.settings.accountView.entry or {}
    db.settings.accountView.entry = entry
    entry.pageModes = entry.pageModes or {}
    entry.pagePositions = entry.pagePositions or {}
end)

Migrations:Register(5, function(db)
    db.settings = db.settings or {}
    db.settings.accountView = db.settings.accountView or {}
    local view = db.settings.accountView
    local previous = view.characterSort

    view.pageCharacterSorts = type(view.pageCharacterSorts) == "table" and view.pageCharacterSorts or {}
    view.customCharacterOrder = type(view.customCharacterOrder) == "table" and view.customCharacterOrder or {}

    if type(previous) == "string" then
        if previous == "seen" then
            local characters = {}
            for _, character in pairs(db.characters and db.characters.byID or {}) do
                characters[#characters + 1] = character
            end
            table.sort(characters, function(left, right)
                local leftOrder, rightOrder = tonumber(left.seenOrder), tonumber(right.seenOrder)
                if leftOrder ~= rightOrder then
                    if leftOrder == nil then return false end
                    if rightOrder == nil then return true end
                    return leftOrder < rightOrder
                end
                return tostring(left.id or "") < tostring(right.id or "")
            end)
            local seen = {}
            for _, character in ipairs(characters) do
                if type(character.id) == "string" and character.id ~= "" and not seen[character.id] then
                    seen[character.id] = true
                    view.customCharacterOrder[#view.customCharacterOrder + 1] = character.id
                end
            end
            view.characterSort = { mode = "custom", direction = "desc", pinCurrent = false }
        elseif previous == "name" then
            view.characterSort = { mode = "name", direction = "asc", pinCurrent = false }
        elseif previous == "level" then
            view.characterSort = { mode = "level", direction = "desc", pinCurrent = false }
        else
            view.characterSort = { mode = "recent", direction = "desc", pinCurrent = false }
        end
    elseif type(previous) ~= "table" then
        view.characterSort = { mode = "recent", direction = "desc", pinCurrent = false }
    end
end)

Migrations:Register(6, function(db)
    db.characterDeletionHistory = type(db.characterDeletionHistory) == "table" and db.characterDeletionHistory or {}
end)

Migrations:Register(7, function(db)
    db.characters = db.characters or {}
    db.characters.byID = db.characters.byID or {}
    for _, character in pairs(db.characters.byID) do
        character.domains = type(character.domains) == "table" and character.domains or {}
    end
end)

Migrations:Register(8, function(db)
    -- Display preferences are deliberately separate from identity records:
    -- a player nickname must never become a cache key or an imported fact.
    db.characterDisplay = type(db.characterDisplay) == "table" and db.characterDisplay or {}
end)

Core.Capabilities:Register("migrations", 1)
