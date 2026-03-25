local addonName, QB = ...

QB = QB or _G.QuestBuddy or {}
_G.QuestBuddy = QB
QB.State = QB.State or {}

local State = QB.State

State.session = State.session or nil

function State:Initialize(options)
    self.session = {
        localSnapshot = nil,
        localSignature = nil,
        localRevision = 0,
        peers = {},
        focusedBuddy = options and options.lastFocusedBuddy or nil,
    }
end

function State:GetSession()
    return self.session
end

function State:RefreshLocalSnapshot(now)
    local session = self:GetSession()
    local snapshot = QB.QuestApi:BuildLocalSnapshot(now)
    local signature = QB.Snapshot:BuildSignature(snapshot)

    if signature == session.localSignature then
        return false, session.localSnapshot
    end

    session.localSignature = signature
    session.localRevision = session.localRevision + 1
    snapshot.revision = session.localRevision
    snapshot.createdAt = now
    session.localSnapshot = snapshot

    return true, snapshot
end

function State:GetLocalSnapshot()
    local session = self:GetSession()
    return session and session.localSnapshot or nil
end

function State:GetPeer(name)
    local session = self:GetSession()
    return session and session.peers[name] or nil
end

function State:GetPeers()
    local session = self:GetSession()
    return session and session.peers or {}
end

function State:EnsurePeer(name)
    local session = self:GetSession()
    if not session.peers[name] then
        session.peers[name] = {
            name = name,
            online = true,
            updating = false,
            lastSeen = 0,
            lastUpdate = 0,
            revision = 0,
            snapshot = nil,
        }
    end
    return session.peers[name]
end

function State:MarkPeerHello(name, revision, now)
    local peer = self:EnsurePeer(name)
    peer.online = true
    peer.lastSeen = now
    peer.helloRevision = tonumber(revision) or 0
    if not peer.snapshot then
        peer.updating = true
    end
    return peer
end

function State:ApplyPeerSnapshot(name, snapshot, now)
    local peer = self:EnsurePeer(name)
    peer.online = true
    peer.updating = false
    peer.lastSeen = now
    peer.lastUpdate = now
    peer.revision = snapshot.revision or peer.revision or 0
    peer.snapshot = snapshot
    return peer
end

function State:SetPeerUpdating(name, updating)
    local peer = self:EnsurePeer(name)
    peer.updating = updating and true or false
    return peer
end

function State:MarkPeerOffline(name, now)
    local peer = self:EnsurePeer(name)
    peer.online = false
    peer.updating = false
    peer.lastSeen = now or peer.lastSeen
    return peer
end

function State:PrunePeers(activePeerSet, now)
    for name, peer in pairs(self:GetPeers()) do
        if not activePeerSet[name] then
            self:MarkPeerOffline(name, now)
        else
            peer.online = true
        end
    end
end

function State:GetPeerStatus(peer, now, staleTimeout)
    if not peer then
        return "Offline"
    end

    if not peer.online then
        return "Offline"
    end

    if peer.updating or not peer.snapshot then
        return "Updating"
    end

    if (now - (peer.lastUpdate or 0)) > staleTimeout then
        return "Stale"
    end

    return "Live"
end

function State:GetOrderedPeerNames(activeOnly)
    local names = {}
    for name, peer in pairs(self:GetPeers()) do
        if not activeOnly or peer.online then
            table.insert(names, name)
        end
    end
    table.sort(names)
    return names
end

function State.SelectFocusedBuddy(peerNames, currentFocus, lastFocusedBuddy, autoFocusSingle)
    local available = {}
    for _, name in ipairs(peerNames or {}) do
        available[name] = true
    end

    if currentFocus and available[currentFocus] then
        return currentFocus
    end

    if lastFocusedBuddy and available[lastFocusedBuddy] then
        return lastFocusedBuddy
    end

    if autoFocusSingle and #peerNames == 1 then
        return peerNames[1]
    end

    if #peerNames > 0 then
        return peerNames[1]
    end

    return nil
end

function State:ReevaluateFocus(options)
    local session = self:GetSession()
    local peerNames = self:GetOrderedPeerNames(true)
    session.focusedBuddy = State.SelectFocusedBuddy(
        peerNames,
        session.focusedBuddy,
        options and options.lastFocusedBuddy or nil,
        options and options.autoFocusSingleBuddy
    )
    return session.focusedBuddy
end

function State:SetFocusedBuddy(name)
    self:GetSession().focusedBuddy = name
end

function State:GetFocusedBuddy()
    return self:GetSession().focusedBuddy
end

function State.BuildQuestRows(localSnapshot, peerSnapshot, showOnlyShared)
    local rows = {
        shared = {},
        mineOnly = {},
        buddyOnly = {},
    }

    local localMap = QB.Snapshot:IndexByKey(localSnapshot)
    local peerMap = QB.Snapshot:IndexByKey(peerSnapshot)

    for _, localQuest in ipairs((localSnapshot and localSnapshot.quests) or {}) do
        local buddyQuest = peerMap[localQuest.questKey]
        if buddyQuest then
            table.insert(rows.shared, {
                questKey = localQuest.questKey,
                title = localQuest.title,
                level = localQuest.level,
                mine = localQuest,
                buddy = buddyQuest,
                watched = localQuest.watched,
            })
        elseif not showOnlyShared then
            table.insert(rows.mineOnly, {
                questKey = localQuest.questKey,
                title = localQuest.title,
                level = localQuest.level,
                mine = localQuest,
                buddy = nil,
                watched = localQuest.watched,
            })
        end
    end

    if not showOnlyShared then
        for _, buddyQuest in ipairs((peerSnapshot and peerSnapshot.quests) or {}) do
            if not localMap[buddyQuest.questKey] then
                table.insert(rows.buddyOnly, {
                    questKey = buddyQuest.questKey,
                    title = buddyQuest.title,
                    level = buddyQuest.level,
                    mine = nil,
                    buddy = buddyQuest,
                    watched = false,
                })
            end
        end
    end

    local function sortRows(left, right)
        if left.watched ~= right.watched then
            return left.watched
        end
        if left.level ~= right.level then
            return left.level < right.level
        end
        return string.lower(left.title or "") < string.lower(right.title or "")
    end

    table.sort(rows.shared, sortRows)
    table.sort(rows.mineOnly, sortRows)
    table.sort(rows.buddyOnly, sortRows)

    return rows
end