dofile("_NonRelease/TaskGoalIntegration/BossGoalEditorSpec.lua")
local Hub, Core, Catalog = YiboTaskHub, YiboCore, YAB.TargetCatalog
local checks = 0
local function Equal(a, b, label)
    checks = checks + 1; assert(a == b, label .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end
-- Model the real edit box lifecycle that a permissive Frame mock would miss.
local createInput = Core.UITheme.CreateInput
Core.UITheme.CreateInput = function(self, ...)
    local input = createInput(self, ...)
    local hide, show, text = input.Hide, input.Show, input.SetText
    input.focused, input.hideCount = false, 0
    function input:SetFocus() self.focused = true end
    function input:ClearFocus() self.focused = false end
    function input:HasFocus() return self.focused end
    function input:Hide()
        if self.shown then
            self.hideCount = self.hideCount + 1
            if self.scripts.OnHide then self.scripts.OnHide(self) end
        end
        hide(self)
    end
    function input:SetShown(value) if value then show(self) else self:Hide() end end
    function input:SetText(value)
        text(self, value)
        if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end
    end
    return input
end
local frame = CreateFrame("Frame")
Hub.TargetsPage.Create(frame)
local context = { characters = Core.Characters:GetAll() }
Hub.TargetsPage.Refresh(frame, context)
local search = frame.search
search:SetFocus()
local hides = search.hideCount
for _, value in ipairs({ "S", "SW", "SWP" }) do
    search:SetText(value); search.scripts.OnTextChanged(search, true)
    Equal(frame.query, value, "each keystroke filters")
    Equal(search:HasFocus(), true, "typing retains focus")
    Equal(search.hideCount, hides, "filter refresh never hides input")
end
local composing = true
search.IsInIMECompositionMode = function() return composing end
search:SetText("太阳"); search.scripts.OnTextChanged(search, true)
Equal(frame.query, "SWP", "IME composition waits for commit")
Hub.TargetsPage.Refresh(frame, context)
Equal(search.imePending ~= nil, true, "refresh preserves pending IME text")
Equal(search:HasFocus(), true, "IME refresh retains focus")
composing = false; search.scripts.OnUpdate(search)
Equal(frame.query, "太阳", "IME commit filters complete text")
search.clearButton.scripts.OnClick()
Equal(frame.query, "", "clear button filters empty text")
Equal(search:HasFocus(), true, "clear button keeps typing ready")
frame.copyTo.scripts.OnClick()
Equal(search:HasFocus(), false, "leaving search intentionally releases focus")
Equal(search.imePending, nil, "leaving search clears pending composition")

local sw = Catalog:Get("instance:580")
Equal(sw.difficulties[1].id, 176, "directory uses native Mists Sunwell difficulty")
Equal(Catalog:CanonicalDifficulty(sw.id, 4), 176, "previous directory ID resolves through owner")
Equal(Catalog:CanonicalDifficulty("instance:631", 4), 4, "other raids retain exact normal difficulty")
Equal(Catalog:CanonicalDifficulty(sw.id, 6), 6, "heroic difficulty never merges with normal")
local function Intent(difficulty)
    return { providerID = "YiboAltoBoss:targets", objectID = sw.id, targetType = "boss", repeatPolicy = "recurring",
        scope = { mode = "character", characterID = "C" }, conditions = { catalogID = sw.id, difficultyID = difficulty,
            scope = "boss", encounterIDs = { "raid:580:kil" } } }
end
local created = assert(Hub.Goals:Add(Intent(4)))
local stored = Hub.db.goals.byID[created.id]
-- Persisted state from the preceding implementation, with history retained.
stored.intent.conditions.difficultyID = 4
stored.identity = stored.identity:gsub("instance:580:176:", "instance:580:4:")
stored.history[1] = { state = "fixture", at = GetServerTime() }
Hub.Goals:Changed("YiboAltoBoss:targets")
local count = #Hub.Goals:List()
local demands = Core.Contracts:Resolve("action.demands", { major = 1 })
local added = assert(Core.Contracts:Call("YiboAltoBoss", demands, "Add", { intent = Intent(176) }))
Equal(added.id, created.id, "AltoBoss public add finds existing Hub goal")
Equal(added.existing, true, "native and prior identities are the same goal")
Equal(#Hub.Goals:List(), count, "cross-entry add does not create another goal")
Equal(assert(Hub.Goals:Lookup(Intent(4))).id, created.id, "prior intent looks up canonical goal")
assert(Hub.BossTargets:Put("C", Intent(176).conditions))
Equal(#Hub.Goals:List(), count, "Hub add reuses same public source identity")
Equal(#Hub.db.goals.byID[created.id].history, 1, "identity normalization preserves history")
local canonical
for _, target in ipairs(Hub.BossTargets:List("C")) do if target.catalogID == sw.id then canonical = target end end
Equal(canonical.difficultyID, 176, "public Boss target view uses native identity")
local columns = YAB.GetLockoutColumns({ preview = true, characters = Core.Characters:GetAll() })
local swCount = 0
for _, column in ipairs(columns) do if column.mapID == 580 then
    swCount = swCount + 1; Equal(column.plannedDifficultyID, 176, "AltoBoss uses same native difficulty")
end end
Equal(swCount, 1, "account preview contains one Sunwell column")
-- The journal and maintained directory resolve to the same client identity,
-- even when an API exposes both legacy and current identifiers.
local list, info, encounters, valid = YAB.GetInstanceCatalog, EJ_GetInstanceInfo, EJ_GetEncounterInfoByIndex, EJ_IsValidInstanceDifficulty
YAB.GetInstanceCatalog = function() return { sw = { key = "ej:123", mapID = 580, name = sw.name, isRaid = true } } end
EJ_GetInstanceInfo = function() return sw.name, nil, nil, nil, nil, nil, nil, nil, true, 580 end
EJ_IsValidInstanceDifficulty = function(id) return id == 4 or id == 176 end
EJ_GetEncounterInfoByIndex = function(index)
    local boss = sw.difficulties[1].encounters[index]
    if boss then return boss.name, nil, 10000 + index, nil, nil, 123, 723 + index end
end
Catalog:Invalidate()
local journal = Catalog:Get("journal:123")
Equal(#journal.difficulties, 1, "journal difficulty aliases appear once")
Equal(journal.difficulties[1].id, 176, "journal agrees with native lockout and static directory")
Equal(journal.difficulties[1].finalEncounterID, 729, "journal keeps exact declared final encounter")
YAB.GetInstanceCatalog, EJ_GetInstanceInfo, EJ_GetEncounterInfoByIndex, EJ_IsValidInstanceDifficulty = list, info, encounters, valid
Catalog:Invalidate()
print("BossSearchIdentitySpec: " .. checks .. " checks passed")
