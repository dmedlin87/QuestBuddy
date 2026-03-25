local addonName, QB = ...

QB = QB or _G.QuestBuddy or {}
_G.QuestBuddy = QB
QB.Snapshot = QB.Snapshot or {}

local Snapshot = QB.Snapshot

local function escapeField(value)
    value = tostring(value or "")
    value = string.gsub(value, "\\", "\\\\")
    value = string.gsub(value, "\t", "\\t")
    value = string.gsub(value, "\n", "\\n")
    value = string.gsub(value, "\r", "\\r")
    return value
end

local function unescapeField(value)
    local buffer = {}
    local index = 1

    while index <= string.len(value or "") do
        local character = string.sub(value, index, index)
        if character == "\\" then
            local token = string.sub(value, index + 1, index + 1)
            if token == "t" then
                table.insert(buffer, "\t")
            elseif token == "n" then
                table.insert(buffer, "\n")
            elseif token == "r" then
                table.insert(buffer, "\r")
            else
                table.insert(buffer, token)
            end
            index = index + 2
        else
            table.insert(buffer, character)
            index = index + 1
        end
    end

    return table.concat(buffer)
end

local function splitEscapedFields(line)
    local fields = {}
    local current = {}
    local escaping = false

    for index = 1, string.len(line or "") do
        local character = string.sub(line, index, index)
        if escaping then
            table.insert(current, "\\")
            table.insert(current, character)
            escaping = false
        elseif character == "\\" then
            escaping = true
        elseif character == "\t" then
            table.insert(fields, unescapeField(table.concat(current)))
            current = {}
        else
            table.insert(current, character)
        end
    end

    if escaping then
        table.insert(current, "\\")
    end

    table.insert(fields, unescapeField(table.concat(current)))
    return fields
end

local function serializeObjective(objective)
    return table.concat({
        "O",
        escapeField(objective.text),
        escapeField(objective.current),
        escapeField(objective.required),
        objective.done and "1" or "0",
    }, "\t")
end

local function serializeQuest(quest)
    local lines = {}
    table.insert(lines, table.concat({
        "Q",
        escapeField(quest.questKey),
        escapeField(quest.questId),
        escapeField(quest.title),
        escapeField(quest.level),
        escapeField(quest.status),
        quest.watched and "1" or "0",
        escapeField(quest.updated),
        tostring(#(quest.objectives or {})),
    }, "\t"))

    for _, objective in ipairs(quest.objectives or {}) do
        table.insert(lines, serializeObjective(objective))
    end

    return lines
end

function Snapshot:Serialize(snapshot, includeMetadata)
    local lines = {}
    local revision = includeMetadata == false and 0 or (snapshot.revision or 0)
    local createdAt = includeMetadata == false and 0 or (snapshot.createdAt or 0)

    table.insert(lines, table.concat({
        "S",
        "1",
        escapeField(snapshot.player),
        tostring(revision),
        tostring(createdAt),
        tostring(#(snapshot.quests or {})),
    }, "\t"))

    for _, quest in ipairs(snapshot.quests or {}) do
        local questLines = serializeQuest(quest)
        for _, line in ipairs(questLines) do
            table.insert(lines, line)
        end
    end

    return table.concat(lines, "\n")
end

function Snapshot:Deserialize(serialized)
    if type(serialized) ~= "string" or serialized == "" then
        return nil, "empty snapshot"
    end

    local snapshot = {
        quests = {},
    }

    local currentQuest = nil
    local expectedObjectives = 0
    local questCount = 0

    for line in string.gmatch(serialized, "([^\n]+)") do
        local fields = splitEscapedFields(line)
        local recordType = fields[1]

        if recordType == "S" then
            if snapshot.player then
                return nil, "duplicate snapshot header"
            end
            snapshot.player = fields[3] or "Unknown"
            snapshot.revision = tonumber(fields[4]) or 0
            snapshot.createdAt = tonumber(fields[5]) or 0
            questCount = tonumber(fields[6]) or 0
        elseif recordType == "Q" then
            if currentQuest and expectedObjectives > 0 then
                return nil, "objective count mismatch"
            end

            currentQuest = {
                questKey = fields[2],
                questId = tonumber(fields[3]) or 0,
                title = fields[4] or "",
                level = tonumber(fields[5]) or 0,
                status = fields[6] or "active",
                watched = fields[7] == "1",
                updated = tonumber(fields[8]) or 0,
                objectives = {},
            }
            expectedObjectives = tonumber(fields[9]) or 0
            table.insert(snapshot.quests, currentQuest)
        elseif recordType == "O" then
            if not currentQuest or expectedObjectives <= 0 then
                return nil, "orphan objective"
            end

            table.insert(currentQuest.objectives, {
                text = fields[2] or "",
                current = fields[3] ~= "" and tonumber(fields[3]) or nil,
                required = fields[4] ~= "" and tonumber(fields[4]) or nil,
                done = fields[5] == "1",
            })
            expectedObjectives = expectedObjectives - 1
        else
            return nil, "unknown snapshot record"
        end
    end

    if not snapshot.player then
        return nil, "missing snapshot header"
    end

    if currentQuest and expectedObjectives > 0 then
        return nil, "truncated objectives"
    end

    if #snapshot.quests ~= questCount then
        return nil, "quest count mismatch"
    end

    return snapshot
end

function Snapshot:BuildSignature(snapshot)
    return self:Serialize(snapshot, false)
end

function Snapshot:ChunkString(serialized, maxChunkSize)
    local chunks = {}
    local chunkSize = maxChunkSize or 220
    local length = string.len(serialized or "")
    local index = 1

    while index <= length do
        table.insert(chunks, string.sub(serialized, index, index + chunkSize - 1))
        index = index + chunkSize
    end

    if #chunks == 0 then
        table.insert(chunks, "")
    end

    return chunks
end

function Snapshot:JoinChunks(chunks)
    return table.concat(chunks or {}, "")
end

function Snapshot:Checksum(serialized)
    local checksum = 0
    for index = 1, string.len(serialized or "") do
        checksum = (checksum * 33 + string.byte(serialized, index)) % 2147483647
    end
    return checksum
end

function Snapshot:IndexByKey(snapshot)
    local indexed = {}
    for _, quest in ipairs((snapshot and snapshot.quests) or {}) do
        indexed[quest.questKey] = quest
    end
    return indexed
end

function Snapshot:SummarizeQuest(quest)
    if not quest then
        return "Missing"
    end

    if quest.status == "ready" then
        return "Ready to turn in"
    end

    local parts = {}
    for _, objective in ipairs(quest.objectives or {}) do
        if objective.current ~= nil and objective.required ~= nil then
            table.insert(parts, string.format("%d/%d", objective.current, objective.required))
        elseif objective.done then
            table.insert(parts, "Done")
        elseif objective.text and objective.text ~= "" then
            table.insert(parts, objective.text)
        end
    end

    if #parts == 0 then
        return quest.status == "failed" and "Failed" or "In progress"
    end

    return table.concat(parts, ", ")
end