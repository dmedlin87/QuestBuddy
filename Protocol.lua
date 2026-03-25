local addonName, QB = ...

QB = QB or _G.QuestBuddy or {}
_G.QuestBuddy = QB
QB.Protocol = QB.Protocol or {}

local Protocol = QB.Protocol

Protocol.PREFIX = "QuestBuddy"
Protocol.VERSION = "1"
Protocol.MAX_MESSAGE_SIZE = 255

local function encodeNetField(value)
    value = tostring(value or "")
    return tostring(string.len(value)) .. ":" .. value
end

local function decodeNetFields(payload)
    local fields = {}
    local index = 1

    while index <= string.len(payload or "") do
        local colonAt = string.find(payload, ":", index, true)
        if not colonAt then
            return nil, "missing field length separator"
        end

        local length = tonumber(string.sub(payload, index, colonAt - 1))
        if not length then
            return nil, "invalid field length"
        end

        local valueStart = colonAt + 1
        local valueEnd = valueStart + length - 1
        if valueEnd > string.len(payload) then
            return nil, "truncated field"
        end

        table.insert(fields, string.sub(payload, valueStart, valueEnd))
        index = valueEnd + 1
    end

    return fields
end

function Protocol:Encode(messageType, fields)
    local encodedFields = {}
    if fields then
        for _, field in ipairs(fields) do
            table.insert(encodedFields, encodeNetField(field))
        end
    end

    return table.concat({ self.VERSION, messageType, table.concat(encodedFields, "") }, "|")
end

function Protocol:GetEncodedLength(messageType, fields)
    return string.len(self:Encode(messageType, fields))
end

function Protocol:Decode(message)
    if type(message) ~= "string" or message == "" then
        return nil, "empty message"
    end

    local versionEnd = string.find(message, "|", 1, true)
    if not versionEnd then
        return nil, "missing version separator"
    end

    local typeEnd = string.find(message, "|", versionEnd + 1, true)
    if not typeEnd then
        return nil, "missing type separator"
    end

    local version = string.sub(message, 1, versionEnd - 1)
    local messageType = string.sub(message, versionEnd + 1, typeEnd - 1)
    if version ~= self.VERSION then
        return nil, "unsupported protocol version"
    end

    local fields, errorMessage = decodeNetFields(string.sub(message, typeEnd + 1))
    if not fields then
        return nil, errorMessage
    end

    return {
        version = version,
        type = messageType,
        fields = fields,
    }
end

function Protocol:EncodeHello(revision, questCount)
    return self:Encode("HELLO", { revision or 0, questCount or 0 })
end

function Protocol:EncodeSnapshotRequest(targetName, reason)
    return self:Encode("SNAPSHOT_REQUEST", { targetName or "", reason or "manual" })
end

function Protocol:EncodeSnapshotStart(transferId, revision, chunkCount, checksum, byteCount)
    return self:Encode("SNAPSHOT_START", { transferId, revision, chunkCount, checksum, byteCount })
end

function Protocol:EncodeSnapshotChunk(transferId, chunkIndex, chunkData)
    return self:Encode("SNAPSHOT_CHUNK", { transferId, chunkIndex, chunkData or "" })
end

function Protocol:EncodeSnapshotEnd(transferId, revision, checksum)
    return self:Encode("SNAPSHOT_END", { transferId, revision, checksum })
end

function Protocol:EncodeGoodbye()
    return self:Encode("GOODBYE", {})
end

function Protocol:GetMaxChunkDataSize(transferId, chunkCountHint)
    local digits = string.len(tostring(chunkCountHint or 1))
    local chunkIndex = string.rep("9", math.max(1, digits))
    local low = 1
    local high = self.MAX_MESSAGE_SIZE
    local best = 1

    while low <= high do
        local mid = math.floor((low + high) / 2)
        local encodedLength = self:GetEncodedLength("SNAPSHOT_CHUNK", { transferId or "", chunkIndex, string.rep("x", mid) })

        if encodedLength <= self.MAX_MESSAGE_SIZE then
            best = mid
            low = mid + 1
        else
            high = mid - 1
        end
    end

    return best
end
