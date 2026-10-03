local path = assert(arg and arg[1], "usage: lua AnalyzeSavedVariables.lua <YiboMailStage0Probe.lua>")
dofile(path)
local db = assert(YiboMailStage0ProbeDB, "YiboMailStage0ProbeDB not found")

print("schema=" .. tostring(db.schemaVersion) .. " sessions=" .. tostring(#(db.sessions or {})))
for sessionIndex, session in ipairs(db.sessions or {}) do
    local client = session.client or {}
    print(string.format("SESSION %d addon=%s client=%s build=%s interface=%s samples=%d events=%d",
        sessionIndex, tostring(session.addonVersion), tostring(client.version), tostring(client.build),
        tostring(client.interface), #(session.samples or {}), #(session.events or {})))
    for sampleIndex, sample in ipairs(session.samples or {}) do
        local payload = sample.payload or {}
        if sample.kind == "mail.inbox" then
            print(string.format("  SAMPLE %d at=%s reason=%s frame=%s coverage=%s current=%s total=%s unscanned=%s duplicates=%s readErrors=%s error=%s",
                sampleIndex, tostring(sample.observedAt), tostring(payload.reason), tostring(payload.frameShown),
                tostring(payload.coverage), tostring(payload.currentCount), tostring(payload.totalCount),
                tostring(payload.unscannedCount), tostring(payload.duplicateGroups), tostring(payload.readErrors),
                tostring(payload.error)))
            if payload.comparison then
                local change = payload.comparison
                print(string.format("    CHANGE previous=%s/%s added=%s missing=%s ambiguous=%s",
                    tostring(change.previousCurrentCount), tostring(change.previousTotalCount),
                    tostring(change.addedSignatures), tostring(change.missingSignatures),
                    tostring(change.identityAmbiguous)))
            end
        elseif sample.kind == "mail.player-action" then
            print(string.format("  SAMPLE %d at=%s action=%s index=%s slot=%s previous=%s outcome=%s",
                sampleIndex, tostring(sample.observedAt), tostring(payload.api), tostring(payload.mailIndex),
                tostring(payload.attachmentIndex), tostring(payload.previousFingerprint), tostring(payload.outcome)))
        end
    end
    for _, event in ipairs(session.events or {}) do
        print(string.format("  EVENT at=%s name=%s", tostring(event.observedAt), tostring(event.event)))
    end
end
