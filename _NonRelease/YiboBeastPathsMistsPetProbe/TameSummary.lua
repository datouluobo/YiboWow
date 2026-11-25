local env = {}
local chunk = assert(loadfile(assert(arg[1])))
setfenv(chunk, env); chunk()
local db = env.YiboBeastPathsMistsPetProbeDB or {}
for _, record in pairs(db.characters or {}) do
    for _, sample in ipairs(record.tameSamples or {}) do
        print("sample=" .. tostring(sample.at) .. " events=" .. tostring(#(sample.events or {})))
        local original = sample.events and sample.events[1] and sample.events[1].target
        local seenPet, nameMatch = false, false
        for _, e in ipairs(sample.events or {}) do
            local function kind(unit) return unit and type(unit.guid) == "string" and unit.guid:match("^[^-]+") or "none" end
            print(tostring(e.event) .. " target=" .. tostring(kind(e.target)) .. " pet=" .. tostring(kind(e.pet))
                .. " map=" .. tostring(e.position and e.position.mapID or "none"))
            if kind(e.pet) == "Pet" then
                seenPet = true
                if original and original.name and e.pet.name == original.name then nameMatch = true end
            end
        end
        print("petAppeared=" .. tostring(seenPet) .. " targetPetNameMatched=" .. tostring(nameMatch))
        local first = sample.events and sample.events[1]
        if first and first.target then print("targetName=" .. tostring(first.target.name) .. " targetGUID=" .. tostring(first.target.guid)) end
        for _, e in ipairs(sample.events or {}) do
            if e.pet and e.pet.guid then print("petName=" .. tostring(e.pet.name) .. " petGUID=" .. tostring(e.pet.guid)); break end
        end
    end
    for i, s in ipairs(record.samples or {}) do
        print("snapshot=" .. i .. " at=" .. tostring(s.at) .. " active=" .. tostring(s.counts and s.counts.active)
            .. " stable=" .. tostring(s.counts and s.counts.stable))
        if record.tameSamples and s.slots then
            for _, slot in ipairs(s.slots) do
                if slot.occupied and slot.family == "山羊" then
                    print("goat at=" .. tostring(s.at) .. " slot=" .. tostring(slot.index)
                        .. " name=" .. tostring(slot.name) .. " display=" .. tostring(slot.displayID)
                        .. " level=" .. tostring(slot.level) .. " icon=" .. tostring(slot.icon))
                end
            end
        end
    end
    local latest = record.latest
    if record.tameSamples and latest and latest.slots then
        local sample = record.tameSamples[#record.tameSamples]
        local petName
        for _, event in ipairs(sample.events or {}) do if event.pet and event.pet.guid then petName = event.pet.name; break end end
        for _, slot in ipairs(latest.slots) do
            if slot.occupied and slot.name == petName then
                print("matchingSlot=" .. tostring(slot.index) .. " display=" .. tostring(slot.displayID)
                    .. " family=" .. tostring(slot.family))
            end
        end
        for _, slot in ipairs(latest.slots) do
            if slot.occupied and slot.info and slot.info.values then
                local v = slot.info.values
                print("slotReturnCount=" .. tostring(v.n))
                for i = 1, v.n do print("slotValue" .. i .. "=" .. tostring(v[i])) end
                break
            end
        end
    end
end
