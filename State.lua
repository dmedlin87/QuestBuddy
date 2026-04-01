local _, QB = ...

QB = QB or _G.QuestBuddy or {}
_G.QuestBuddy = QB
QB.State = QB.State or {}

local State = QB.State
local SIMULATED_BUDDY_NAME = "Simulated Buddy"

State.session = State.session or nil

local function clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    end
    if value > maximum then
        return maximum
    end
    return value
end

local function buildSimulatedObjective(objective, questIndex, objectiveIndex, forceReady)
    local simulated = QB.Compat:CopyTable(objective)
    local current = tonumber(simulated.current)
    local required = tonumber(simulated.required)

    if forceReady then
        if required and required > 0 then
            simulated.current = required
            simulated.required = required
        elseif current ~= nil then
            simulated.current = current
        end
        simulated.done = true
        return simulated
    end

    if required and required > 0 then
        local baseCurrent = current or 0
        local offset = ((questIndex * 2) + objectiveIndex) % 3
        local direction = ((questIndex + objectiveIndex) % 2 == 0) and 1 or -1
        local fakeCurrent = clamp(baseCurrent + (offset * direction), 0, required)

        if fakeCurrent == baseCurrent and required > 0 then
            fakeCurrent = clamp(baseCurrent + (direction > 0 and 1 or -1), 0, required)
        end

        simulated.current = fakeCurrent
        simulated.required = required
        simulated.done = fakeCurrent >= required
        return simulated
    end

    simulated.done = ((questIndex + objectiveIndex) % 3) == 0
    return simulated
end

local function buildSimulatedQuest(quest, questIndex, now)
    local simulated = QB.Compat:CopyTable(quest)
    local forceReady = (questIndex % 4) == 0

    simulated.updated = now or quest.updated or 0
    simulated.status = forceReady and "ready" or "active"
    simulated.objectives = simulated.objectives or {}

    for objectiveIndex, objective in ipairs(simulated.objectives) do
        simulated.objectives[objectiveIndex] = buildSimulatedObjective(objective, questIndex, objectiveIndex, forceReady)
    end

    return simulated
end

local function buildSimulatedSnapshot(localSnapshot, now)
    local snapshot = {
        player = SIMULATED_BUDDY_NAME,
        revision = ((localSnapshot and localSnapshot.revision) or 0) + 1,
        createdAt = now or 0,
        quests = {},
    }

    for questIndex, quest in ipairs((localSnapshot and localSnapshot.quests) or {}) do
        table.insert(snapshot.quests, buildSimulatedQuest(quest, questIndex, now))
    end

    return snapshot
end

function State:Initialize(options)
    self.session = {
        localSnapshot = nil,
        localSignature = nil,
        localRevision = 0,
        peers = {},
        focusedBuddy = options and options.lastFocusedBuddy or nil,
        simulatedPeerName = nil,
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

function State:GetSimulatedPeerName()
    local session = self:GetSession()
    return session and session.simulatedPeerName or nil
end

function State:IsSimulatedPeer(name)
    return name ~= nil and name == self:GetSimulatedPeerName()
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
    local helloRevision = tonumber(revision) or 0
    peer.online = true
    peer.lastSeen = now
    peer.helloRevision = helloRevision
    if not peer.snapshot or helloRevision > (peer.revision or 0) then
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
    peer.helloRevision = peer.revision
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
        if self:IsSimulatedPeer(name) then
            peer.online = true
        elseif not activePeerSet[name] then
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

function State:GetPeerSummaryRows(now, staleTimeout)
    local rows = {}
    local localMap = QB.Snapshot:IndexByKey(self:GetLocalSnapshot())
    local timeout = staleTimeout or 90
    local timestamp = now or QB.Compat:GetTime()

    for _, name in ipairs(self:GetOrderedPeerNames(false)) do
        local peer = self:GetPeer(name)
        local status = self:GetPeerStatus(peer, timestamp, timeout)
        local sharedCount = 0
        local readyCount = 0

        for _, quest in ipairs((peer and peer.snapshot and peer.snapshot.quests) or {}) do
            if localMap[quest.questKey] then
                sharedCount = sharedCount + 1
            end
            if quest.status == "ready" then
                readyCount = readyCount + 1
            end
        end

        table.insert(rows, {
            name = name,
            status = status,
            sharedCount = sharedCount,
            readyCount = readyCount,
        })
    end

    return rows
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

function State:CreateSimulatedPeer(now)
    local session = self:GetSession()
    local snapshot = buildSimulatedSnapshot(session.localSnapshot, now)
    local peer = self:EnsurePeer(SIMULATED_BUDDY_NAME)

    peer.online = true
    peer.updating = false
    peer.lastSeen = now or 0
    peer.lastUpdate = now or 0
    peer.revision = snapshot.revision or 0
    peer.helloRevision = peer.revision
    peer.snapshot = snapshot

    session.simulatedPeerName = SIMULATED_BUDDY_NAME
    session.focusedBuddy = SIMULATED_BUDDY_NAME

    return peer
end

function State:ClearSimulatedPeer()
    local session = self:GetSession()
    local simulatedPeerName = session.simulatedPeerName

    if not simulatedPeerName then
        return false
    end

    session.peers[simulatedPeerName] = nil
    session.simulatedPeerName = nil

    if session.focusedBuddy == simulatedPeerName then
        session.focusedBuddy = nil
    end

    return true
end

function State:ToggleSimulatedPeer(now)
    if self:GetSimulatedPeerName() then
        self:ClearSimulatedPeer()
        return false
    end

    self:CreateSimulatedPeer(now)
    return true
end

local function buildObjectiveComparison(mineQuest, buddyQuest)
    local comparisons = {}
    local mineObjectives = (mineQuest and mineQuest.objectives) or {}
    local buddyObjectives = (buddyQuest and buddyQuest.objectives) or {}
    local objectiveCount = math.max(#mineObjectives, #buddyObjectives)
    local totalDelta = 0

    for index = 1, objectiveCount do
        local myObjective = mineObjectives[index] or {}
        local buddyObjective = buddyObjectives[index] or {}
        local myCount = tonumber(myObjective.current)
        local buddyCount = tonumber(buddyObjective.current)
        local delta = 0
        local aheadSide = "even"

        if myCount and buddyCount then
            delta = buddyCount - myCount
            if delta > 0 then
                aheadSide = "buddy"
            elseif delta < 0 then
                aheadSide = "me"
            end
        elseif buddyCount then
            delta = buddyCount
            aheadSide = buddyCount ~= 0 and "buddy" or "even"
        elseif myCount then
            delta = -myCount
            aheadSide = myCount ~= 0 and "me" or "even"
        end

        totalDelta = totalDelta + delta
        comparisons[index] = {
            index = index,
            my_count = myCount or 0,
            buddy_count = buddyCount or 0,
            delta = delta,
            ahead_side = aheadSide,
        }
    end

    local aheadSide = "even"
    if totalDelta > 0 then
        aheadSide = "buddy"
    elseif totalDelta < 0 then
        aheadSide = "me"
    end

    return comparisons, totalDelta, aheadSide
end

function State.BuildQuestRows(localSnapshot, peerSnapshot, showOnlyShared, sortSharedByLargestDelta)
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
            local objectiveComparison, totalDelta, aheadSide = buildObjectiveComparison(localQuest, buddyQuest)
            table.insert(rows.shared, {
                questKey = localQuest.questKey,
                title = localQuest.title,
                level = localQuest.level,
                mine = localQuest,
                buddy = buddyQuest,
                watched = localQuest.watched,
                objectiveComparison = objectiveComparison,
                delta = totalDelta,
                ahead_side = aheadSide,
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

    if sortSharedByLargestDelta then
        table.sort(rows.shared, function(left, right)
            local leftDelta = math.abs(left.delta or 0)
            local rightDelta = math.abs(right.delta or 0)
            if leftDelta ~= rightDelta then
                return leftDelta > rightDelta
            end
            return sortRows(left, right)
        end)
    else
        table.sort(rows.shared, sortRows)
    end
    table.sort(rows.mineOnly, sortRows)
    table.sort(rows.buddyOnly, sortRows)

    return rows
end
