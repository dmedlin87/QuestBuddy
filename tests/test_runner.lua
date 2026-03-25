---@diagnostic disable: undefined-global, undefined-field
_G = _G or _ENV
_G.QuestBuddy = {}

local function loadModule(path)
    local chunk, loadError = loadfile(path)
    if not chunk then
        error(loadError)
    end
    return chunk()
end

loadModule("Compat.lua")
loadModule("PartyApi.lua")
loadModule("QuestApi.lua")
loadModule("Snapshot.lua")
loadModule("Protocol.lua")
loadModule("State.lua")
loadModule("Tracker.lua")
loadModule("UI.lua")

local QB = _G.QuestBuddy

local failures = 0
local total = 0

local function fail(message)
    failures = failures + 1
    io.stderr:write(message .. "\n")
end

local function expectEquals(actual, expected, message)
    total = total + 1
    if actual ~= expected then
        fail(string.format("FAIL: %s | expected=%s actual=%s", message, tostring(expected), tostring(actual)))
    end
end

local function expectTrue(value, message)
    total = total + 1
    if not value then
        fail("FAIL: " .. message)
    end
end

local function makeSnapshot(player, revision, quests)
    return {
        player = player,
        revision = revision,
        createdAt = revision * 10,
        quests = quests,
    }
end

local function makeQuest(key, title, level, watched, status, objectives)
    return {
        questKey = key,
        questId = 0,
        title = title,
        level = level,
        watched = watched,
        status = status or "active",
        updated = 1,
        objectives = objectives or {},
    }
end

local function testProtocolRoundTrip()
    local encoded = QB.Protocol:EncodeHello(7, 3)
    local decoded = QB.Protocol:Decode(encoded)
    expectEquals(decoded.type, "HELLO", "protocol decode type")
    expectEquals(decoded.fields[1], "7", "protocol revision field")
    expectEquals(decoded.fields[2], "3", "protocol quest count field")
end

local function testMalformedMessageRejected()
    local decoded, errorMessage = QB.Protocol:Decode("1|HELLO|x:abc")
    expectEquals(decoded, nil, "malformed protocol rejected")
    expectTrue(errorMessage ~= nil, "malformed protocol returns error")
end

local function testSnapshotSerializeChunkRoundTrip()
    local snapshot = makeSnapshot("Alice", 4, {
        makeQuest("q:1", "Collect Things", 10, true, "active", {
            { text = "Widgets: 2/8", current = 2, required = 8, done = false },
            { text = "Return to camp", current = 0, required = 1, done = false },
        }),
        makeQuest("q:2", "Turn It In", 11, false, "ready", {}),
    })

    local serialized = QB.Snapshot:Serialize(snapshot, true)
    local chunks = QB.Snapshot:ChunkString(serialized, 18)
    local joined = QB.Snapshot:JoinChunks(chunks)
    local decoded = assert(QB.Snapshot:Deserialize(joined))

    expectEquals(joined, serialized, "snapshot chunk join matches source")
    expectEquals(decoded.player, "Alice", "snapshot player roundtrip")
    expectEquals(#decoded.quests, 2, "snapshot quest count roundtrip")
    expectEquals(decoded.quests[1].objectives[1].current, 2, "snapshot objective roundtrip")
end

local function testStalePeerHandling()
    QB.State:Initialize({})
    QB.State:MarkPeerHello("Buddy", 2, 100)
    expectEquals(QB.State:GetPeerStatus(QB.State:GetPeer("Buddy"), 100, 90), "Updating", "hello without snapshot is updating")

    QB.State:ApplyPeerSnapshot("Buddy", makeSnapshot("Buddy", 2, {}), 120)
    expectEquals(QB.State:GetPeerStatus(QB.State:GetPeer("Buddy"), 150, 90), "Live", "fresh peer is live")
    expectEquals(QB.State:GetPeerStatus(QB.State:GetPeer("Buddy"), 220, 90), "Stale", "old peer becomes stale")

    QB.State:MarkPeerOffline("Buddy", 221)
    expectEquals(QB.State:GetPeerStatus(QB.State:GetPeer("Buddy"), 221, 90), "Offline", "offline peer status")
end

local function testFocusedBuddySelection()
    expectEquals(QB.State.SelectFocusedBuddy({ "Mira" }, nil, nil, true), "Mira", "single buddy auto focus")
    expectEquals(QB.State.SelectFocusedBuddy({ "Mira", "Tao" }, "Tao", nil, true), "Tao", "keep current focus")
    expectEquals(QB.State.SelectFocusedBuddy({ "Mira", "Tao" }, nil, "Mira", true), "Mira", "restore last focused buddy")
end

local function testTrackerRenderingDecisions()
    local localSnapshot = makeSnapshot("Me", 1, {
        makeQuest("a", "Shared Quest", 5, true, "active", { { text = "Boars: 1/5", current = 1, required = 5, done = false } }),
        makeQuest("b", "Missing Quest", 6, true, "active", { { text = "Wolves: 0/3", current = 0, required = 3, done = false } }),
    })

    local peer = {
        snapshot = makeSnapshot("Buddy", 2, {
            makeQuest("a", "Shared Quest", 5, true, "active", { { text = "Boars: 4/5", current = 4, required = 5, done = false } }),
        }),
    }

    local liveRows = QB.Tracker.BuildRows(localSnapshot, peer, "Live")
    expectEquals(#liveRows, 2, "tracker builds watched quest rows")
    expectEquals(liveRows[1].buddyText, "4/5", "tracker shows buddy objective summary")
    expectEquals(liveRows[2].buddyText, "Buddy missing", "tracker shows missing buddy quest")

    local staleRows = QB.Tracker.BuildRows(localSnapshot, peer, "Stale")
    expectEquals(staleRows[1].buddyText, "Stale", "tracker marks stale data")
end

local function testMainWindowRowBuilding()
    local localSnapshot = makeSnapshot("Me", 1, {
        makeQuest("shared", "Shared Quest", 10, true, "active", { { text = "Apples: 2/6", current = 2, required = 6, done = false } }),
        makeQuest("mine", "Mine Quest", 11, false, "ready", {}),
    })
    local peer = {
        snapshot = makeSnapshot("Buddy", 1, {
            makeQuest("shared", "Shared Quest", 10, true, "active", { { text = "Apples: 5/6", current = 5, required = 6, done = false } }),
            makeQuest("buddy", "Buddy Quest", 12, false, "active", { { text = "Dust: 1/4", current = 1, required = 4, done = false } }),
        }),
    }

    local rows, buckets = QB.UI.BuildDisplayRows(localSnapshot, peer, false)
    expectEquals(#buckets.shared, 1, "main window shared bucket")
    expectEquals(#buckets.mineOnly, 1, "main window mine bucket")
    expectEquals(#buckets.buddyOnly, 1, "main window buddy bucket")
    expectEquals(rows[1].text, "Shared Quests", "main window first section header")
    expectTrue(string.find(rows[2].buddyText, "5/6", 1, true) ~= nil, "main window buddy summary text")
end

local function testPartyJoinLeaveBehavior()
    QB.State:Initialize({ autoFocusSingleBuddy = true })
    QB.State:ApplyPeerSnapshot("Alice", makeSnapshot("Alice", 1, {}), 10)
    QB.State:ApplyPeerSnapshot("Bryn", makeSnapshot("Bryn", 1, {}), 10)
    QB.State:SetFocusedBuddy("Bryn")

    QB.State:PrunePeers({ Alice = true }, 12)
    QB.State:ReevaluateFocus({ autoFocusSingleBuddy = true, lastFocusedBuddy = nil })

    expectEquals(QB.State:GetPeer("Bryn").online, false, "missing party member marked offline")
    expectEquals(QB.State:GetFocusedBuddy(), "Alice", "focus falls back to active peer")
end

local tests = {
    testProtocolRoundTrip,
    testMalformedMessageRejected,
    testSnapshotSerializeChunkRoundTrip,
    testStalePeerHandling,
    testFocusedBuddySelection,
    testTrackerRenderingDecisions,
    testMainWindowRowBuilding,
    testPartyJoinLeaveBehavior,
}

for _, test in ipairs(tests) do
    test()
end

if failures > 0 then
    io.stderr:write(string.format("%d/%d tests failed\n", failures, total))
    os.exit(1)
end

print(string.format("%d tests passed", total))