local _, QB = ...

QB = QB or _G.QuestBuddy or {}
_G.QuestBuddy = QB
QB.Comms = QB.Comms or {}

local Comms = QB.Comms

Comms.incomingTransfers = Comms.incomingTransfers or {}
Comms.pendingSnapshotTimer = Comms.pendingSnapshotTimer or nil
Comms.lastSnapshotSentAt = Comms.lastSnapshotSentAt or 0
Comms.transferSequence = Comms.transferSequence or 0
Comms.TRANSFER_TIMEOUT_SECONDS = 8

local function now()
    return QB.Compat:GetTime()
end

function Comms:Initialize()
    QB.Compat:CancelTimer(self.pendingSnapshotTimer)
    for _, transfer in pairs(self.incomingTransfers or {}) do
        QB.Compat:CancelTimer(transfer.timeoutTimer)
    end
    self.incomingTransfers = {}
    self.pendingSnapshotTimer = nil
    self.lastSnapshotSentAt = 0
end

function Comms:SendRaw(payload, distribution, target)
    return QB.Compat:SendAddonMessage(QB.Protocol.PREFIX, payload, distribution or "PARTY", target)
end

function Comms:BroadcastHello()
    local snapshot = QB.State:GetLocalSnapshot()
    local revision = snapshot and snapshot.revision or 0
    local questCount = snapshot and #snapshot.quests or 0
    self:SendRaw(QB.Protocol:EncodeHello(revision, questCount), "PARTY")
end

function Comms:RequestSnapshots(reason)
    self:SendRaw(QB.Protocol:EncodeSnapshotRequest("", reason or "manual"), "PARTY")
end

function Comms:SendSnapshot(targetName)
    local snapshot = QB.State:GetLocalSnapshot()
    if not snapshot then
        return false
    end

    self.transferSequence = self.transferSequence + 1
    local transferId = string.format("%s-%d-%d", QB.PartyApi:GetPlayerName(), snapshot.revision or 0, self.transferSequence)
    local serialized = QB.Snapshot:Serialize(snapshot, true)
    local checksum = QB.Snapshot:Checksum(serialized)
    local chunkSize = QB.Protocol:GetMaxChunkDataSize(transferId, 1)
    local chunks = QB.Snapshot:ChunkString(serialized, chunkSize)

    while true do
        local nextChunkSize = QB.Protocol:GetMaxChunkDataSize(transferId, #chunks)
        if nextChunkSize == chunkSize then
            break
        end
        chunkSize = nextChunkSize
        chunks = QB.Snapshot:ChunkString(serialized, chunkSize)
    end

    local distribution = targetName and "WHISPER" or "PARTY"
    local target = targetName or nil

    self:SendRaw(QB.Protocol:EncodeSnapshotStart(transferId, snapshot.revision, #chunks, checksum, string.len(serialized)), distribution, target)
    for index, chunk in ipairs(chunks) do
        self:SendRaw(QB.Protocol:EncodeSnapshotChunk(transferId, index, chunk), distribution, target)
    end
    self:SendRaw(QB.Protocol:EncodeSnapshotEnd(transferId, snapshot.revision, checksum), distribution, target)

    self.lastSnapshotSentAt = now()
    return true
end

function Comms:QueueSnapshotBroadcast(reason)
    QB.Compat:CancelTimer(self.pendingSnapshotTimer)

    self.pendingSnapshotTimer = QB.Compat:After(1.5, function()
        local elapsed = now() - (self.lastSnapshotSentAt or 0)
        if elapsed < 4 then
            self:QueueSnapshotBroadcast(reason)
            return
        end
        if QB.Compat:IsInParty() then
            self:SendSnapshot()
        end
        self.pendingSnapshotTimer = nil
    end)
end

function Comms:SendGoodbye()
    self:SendRaw(QB.Protocol:EncodeGoodbye(), "PARTY")
end

function Comms:HandleSnapshotRequest(sender, fields)
    local targetName = fields[1]
    if targetName ~= "" and targetName ~= QB.PartyApi:GetPlayerName() then
        return
    end
    self:SendSnapshot(sender)
end

function Comms:HandleSnapshotStart(sender, fields)
    local transferId = fields[1]
    local revision = tonumber(fields[2]) or 0
    local chunkCount = tonumber(fields[3]) or 0
    local checksum = tonumber(fields[4]) or 0
    local byteCount = tonumber(fields[5]) or 0

    if transferId == "" or chunkCount < 0 or chunkCount > 128 then
        return
    end

    local activeTransfer = self.incomingTransfers[sender]
    if activeTransfer then
        QB.Compat:CancelTimer(activeTransfer.timeoutTimer)
    end

    self.incomingTransfers[sender] = {
        transferId = transferId,
        revision = revision,
        chunkCount = chunkCount,
        checksum = checksum,
        byteCount = byteCount,
        chunks = {},
        received = 0,
        startedAt = now(),
    }
    self.incomingTransfers[sender].timeoutTimer = QB.Compat:After(self.TRANSFER_TIMEOUT_SECONDS, function(expectedSender, expectedTransferId)
        local timedOutTransfer = self.incomingTransfers[expectedSender]
        if timedOutTransfer and timedOutTransfer.transferId == expectedTransferId then
            self.incomingTransfers[expectedSender] = nil
            QB.State:SetPeerUpdating(expectedSender, false)
            if QB and QB.RefreshViews then
                QB:RefreshViews("peer-timeout")
            end
        end
    end, sender, transferId)
    QB.State:SetPeerUpdating(sender, true)
end

function Comms:HandleSnapshotChunk(sender, fields)
    local transfer = self.incomingTransfers[sender]
    if not transfer or fields[1] ~= transfer.transferId then
        return
    end

    local chunkIndex = tonumber(fields[2]) or 0
    local chunkData = fields[3] or ""
    if chunkIndex < 1 or chunkIndex > transfer.chunkCount then
        return
    end
    if not transfer.chunks[chunkIndex] then
        transfer.received = transfer.received + 1
    end
    transfer.chunks[chunkIndex] = chunkData
end

function Comms:HandleSnapshotEnd(sender, fields)
    local transfer = self.incomingTransfers[sender]
    if not transfer or fields[1] ~= transfer.transferId then
        return
    end

    QB.Compat:CancelTimer(transfer.timeoutTimer)

    local revision = tonumber(fields[2]) or 0
    local checksum = tonumber(fields[3]) or 0
    if revision ~= transfer.revision or checksum ~= transfer.checksum or transfer.received ~= transfer.chunkCount then
        self.incomingTransfers[sender] = nil
        QB.State:SetPeerUpdating(sender, false)
        return
    end

    local serialized = QB.Snapshot:JoinChunks(transfer.chunks)
    if string.len(serialized) ~= transfer.byteCount or QB.Snapshot:Checksum(serialized) ~= transfer.checksum then
        self.incomingTransfers[sender] = nil
        QB.State:SetPeerUpdating(sender, false)
        return
    end

    local snapshot = QB.Snapshot:Deserialize(serialized)
    self.incomingTransfers[sender] = nil
    if not snapshot then
        QB.State:SetPeerUpdating(sender, false)
        return
    end

    QB.State:ApplyPeerSnapshot(sender, snapshot, now())
    if QB and QB.RefreshViews then
        QB:RefreshViews("peer-snapshot")
    end
end

function Comms:OnAddonMessage(prefix, payload, channel, sender)
    if prefix ~= QB.Protocol.PREFIX or not sender or sender == QB.PartyApi:GetPlayerName() then
        return
    end

    local peerSet = QB.PartyApi:GetPeerSet()
    if not peerSet[sender] then
        return
    end

    local decoded = QB.Protocol:Decode(payload)
    if not decoded then
        return
    end

    local currentTime = now()

    if decoded.type == "HELLO" then
        QB.State:MarkPeerHello(sender, decoded.fields[1], currentTime)
        if not QB.State:GetPeer(sender).snapshot or tonumber(decoded.fields[1]) ~= (QB.State:GetPeer(sender).revision or 0) then
            self:SendRaw(QB.Protocol:EncodeSnapshotRequest(sender, "hello"), "WHISPER", sender)
        end
    elseif decoded.type == "SNAPSHOT_REQUEST" then
        self:HandleSnapshotRequest(sender, decoded.fields)
    elseif decoded.type == "SNAPSHOT_START" then
        self:HandleSnapshotStart(sender, decoded.fields)
    elseif decoded.type == "SNAPSHOT_CHUNK" then
        self:HandleSnapshotChunk(sender, decoded.fields)
    elseif decoded.type == "SNAPSHOT_END" then
        self:HandleSnapshotEnd(sender, decoded.fields)
    elseif decoded.type == "GOODBYE" then
        QB.State:MarkPeerOffline(sender, currentTime)
    end

    if QB and QB.RefreshViews then
        QB:RefreshViews("addon-message")
    end
end
