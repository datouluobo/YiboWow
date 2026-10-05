local Addon = _G.YiboMail
local State = {}; Addon.WorkspaceState = State
-- This object belongs to the Lua session, never to SavedVariables or a host frame.
function State:Get()
    if not self.current then
        self.current = {
            tab = "inbox",
            inbox = { scroll = 0, mode = "mail", scope = "latest", search = "", kind = "all", risk = "all", sort = "expiry" },
            overview = { page = 1 },
            history = { scroll = 0, search = "", days = 30, kind = "all", result = "all" },
        }
    end
    return self.current
end
function State:Search(value)
    local inbox = self:Get().inbox
    local wasSearching = (inbox.search or ""):find("%S") ~= nil
    local searching = (value or ""):find("%S") ~= nil
    if searching and not wasSearching then
        inbox.beforeSearch = { character = inbox.character, scroll = inbox.scroll, anchor = inbox.anchor, anchorOffset = inbox.anchorOffset, focusedID = inbox.focusedID }
    end
    inbox.search, inbox.detail, inbox.detailReturn, inbox.detailPage = value or "", nil, nil, 1
    inbox.focusedID = nil
    if not searching and wasSearching then
        local previous = inbox.beforeSearch or {}
        inbox.character, inbox.scroll, inbox.anchor, inbox.anchorOffset = previous.character, previous.scroll or 0, previous.anchor, previous.anchorOffset
        inbox.focusedID = previous.focusedID
        inbox.beforeSearch = nil
    else inbox.scroll, inbox.anchor, inbox.anchorOffset = 0, nil, nil end
end
function State:SelectCharacter(id, characters, entries)
    local inbox = self:Get().inbox
    if (inbox.search or ""):find("%S") then
        for index, entry in ipairs(entries or {}) do
            local character = entry.character or (entry.sources and entry.sources[1] and entry.sources[1].entry.character)
            local match = character and character.id == id
            if entry.characters then match = entry.characters[id] == true end
            if not id or match then inbox.anchor, inbox.focusedID, inbox.anchorOffset = entry.id, entry.id, 0; break end
        end
    else inbox.character, inbox.scroll, inbox.anchor, inbox.focusedID, inbox.anchorOffset = id, 0, nil, nil, nil end
    inbox.detail, inbox.detailReturn = nil, nil
end
function State:ValidateCharacters(characters)
    local inbox, exists = self:Get().inbox, {}
    for _, character in ipairs(characters) do exists[character.id] = true end
    if not inbox.initialized or (inbox.character and not exists[inbox.character]) then
        local current = Addon.Core.Characters:GetCurrent()
        inbox.character = current and exists[current.id] and current.id or (characters[1] and characters[1].id)
        inbox.scroll, inbox.anchor, inbox.anchorOffset = 0, nil, nil; inbox.initialized = true
    end
    local history = self:Get().history
    -- History has its own eligibility set; it is validated by its renderer.
    return inbox, history
end
function State:Locate(characterID, risk)
    local workspace = self:Get()
    workspace.returnTo = { tab = workspace.tab, inbox = Addon.Copy(workspace.inbox) }
    workspace.tab = "inbox"
    local inbox = workspace.inbox
    inbox.search, inbox.character, inbox.risk, inbox.kind, inbox.scope = "", characterID, risk or "all", "all", "latest"
    inbox.mode, inbox.scroll, inbox.detail, inbox.detailReturn, inbox.anchor, inbox.beforeSearch, inbox.anchorOffset = "mail", 0, nil, nil, nil, nil, nil
    inbox.initialized = true
    inbox.focusedID, inbox.detailScroll, inbox.detailReturnScroll = nil, 0, nil
end
function State:Return()
    local workspace = self:Get()
    if workspace.returnTo then
        workspace.tab, workspace.inbox = workspace.returnTo.tab, workspace.returnTo.inbox
        workspace.returnTo = nil
    end
end
