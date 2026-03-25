---@diagnostic disable: undefined-global, undefined-field
_G = _G or _ENV
_G.QuestBuddy = {}

local function makeFontString()
    return {
        text = "",
        SetPoint = function() end,
        SetWidth = function() end,
        SetText = function(self, text)
            self.text = text
        end,
        SetJustifyH = function() end,
    }
end

local frameMethods = {}

function frameMethods:SetScript(name, callback)
    self.scripts[name] = callback
end

function frameMethods:GetScript(name)
    return self.scripts[name]
end

function frameMethods:RegisterEvent(name)
    self.events[name] = true
end

function frameMethods:UnregisterEvent(name)
    self.events[name] = nil
end

function frameMethods:SetPoint(...)
    self.point = { ... }
end

function frameMethods:GetPoint()
    if not self.point then
        return nil, nil, nil, 0, 0
    end

    return self.point[1], self.point[2], self.point[3], self.point[4], self.point[5]
end

function frameMethods:ClearAllPoints()
    self.point = nil
end

function frameMethods:SetWidth(width)
    self.width = width
end

function frameMethods:GetWidth()
    return self.width or 0
end

function frameMethods:SetHeight(height)
    self.height = height
end

function frameMethods:GetHeight()
    return self.height or 0
end

function frameMethods:SetMovable() end
function frameMethods:EnableMouse() end
function frameMethods:RegisterForDrag() end
function frameMethods:SetClampedToScreen() end
function frameMethods:SetBackdrop() end
function frameMethods:SetBackdropColor() end
function frameMethods:SetBackdropBorderColor() end
function frameMethods:RegisterForClicks() end
function frameMethods:SetAutoFocus() end
function frameMethods:SetNumeric() end
function frameMethods:ClearFocus() end
function frameMethods:SetJustifyH() end
function frameMethods:SetScrollChild(child)
    self.scrollChild = child
end

function frameMethods:StartMoving()
    self.isMoving = true
end

function frameMethods:StopMovingOrSizing()
    self.isMoving = false
end

function frameMethods:Show()
    self.shown = true
end

function frameMethods:Hide()
    self.shown = false
end

function frameMethods:IsShown()
    return self.shown == true
end

function frameMethods:CreateFontString()
    return makeFontString()
end

function frameMethods:SetText(text)
    self.text = text
end

function frameMethods:GetText()
    return self.text or ""
end

function frameMethods:SetChecked(value)
    self.checked = value and true or false
end

function frameMethods:GetChecked()
    return self.checked
end

local function newFrame(frameType, name, parent, template)
    local frame = {
        frameType = frameType,
        name = name,
        parent = parent,
        template = template,
        scripts = {},
        events = {},
        shown = true,
        width = 0,
        height = 0,
        checked = false,
        Text = makeFontString(),
    }

    return setmetatable(frame, { __index = frameMethods })
end

local function resetTestEnvironment()
    _G.__time = 0
    _G.__playerName = "Me"
    _G.__playerRealm = "Realm"
    _G.__partyMembers = { "Buddy-Realm" }
    _G.__inGroup = true
    _G.__inRaid = false
    _G.__sentMessages = {}
    _G.__registeredPrefixes = {}
    _G.__openedSettingsCategory = nil
    _G.__legacyOptionsOpen = nil
    _G.__legacyOptionsCategory = nil
    _G.__questLog = {
        {
            title = "Training Day",
            level = 10,
            questID = 101,
            isHeader = false,
            isComplete = false,
            watched = true,
            objectives = {
                {
                    text = "Widgets: 1/4",
                    numFulfilled = 1,
                    numRequired = 4,
                    finished = false,
                    type = "monster",
                },
            },
        },
    }
end

resetTestEnvironment()

_G.BackdropTemplateMixin = {}
_G.UIParent = newFrame("Frame", "UIParent", nil, nil)
_G.InterfaceOptionsFramePanelContainer = newFrame("Frame", "InterfaceOptionsFramePanelContainer", nil, nil)
_G.DEFAULT_CHAT_FRAME = {
    messages = {},
    AddMessage = function(self, message)
        table.insert(self.messages, message)
    end,
}
_G.UNKNOWN = "Unknown"
_G.SlashCmdList = {}

_G.CreateFrame = function(frameType, name, parent, template)
    return newFrame(frameType, name, parent, template)
end

_G.UIDropDownMenu_SetWidth = function(frame, width)
    frame.width = width
end
_G.UIDropDownMenu_Initialize = function(frame, initializer)
    frame.dropdownInitializer = initializer
end
_G.UIDropDownMenu_CreateInfo = function()
    return {}
end
_G.UIDropDownMenu_AddButton = function() end
_G.UIDropDownMenu_SetText = function(frame, text)
    frame.currentText = text
end

_G.Settings = {
    RegisterCanvasLayoutCategory = function(panel, name)
        return {
            ID = name,
            panel = panel,
        }
    end,
    RegisterAddOnCategory = function(category)
        _G.__settingsCategory = category
    end,
    OpenToCategory = function(categoryId)
        _G.__openedSettingsCategory = categoryId
    end,
}

_G.InterfaceOptions_AddCategory = function(panel)
    _G.__legacyOptionsCategory = panel
end
_G.InterfaceOptionsFrame_OpenToCategory = function(panel)
    _G.__legacyOptionsOpen = panel
end

local function recordAddonMessage(prefix, payload, distribution, target)
    table.insert(_G.__sentMessages, {
        prefix = prefix,
        payload = payload,
        distribution = distribution,
        target = target,
    })
    return true
end

_G.C_ChatInfo = {
    RegisterAddonMessagePrefix = function(prefix)
        _G.__registeredPrefixes[prefix] = true
        return true
    end,
    SendAddonMessage = recordAddonMessage,
}
_G.RegisterAddonMessagePrefix = function(prefix)
    _G.__registeredPrefixes[prefix] = true
    return true
end
_G.SendAddonMessage = recordAddonMessage

_G.GetTime = function()
    return _G.__time or 0
end
_G.time = function()
    return 0
end
_G.IsInGroup = function()
    return _G.__inGroup ~= false
end
_G.IsInRaid = function()
    return _G.__inRaid == true
end
_G.GetNumSubgroupMembers = function()
    return #(_G.__partyMembers or {})
end
_G.GetNumPartyMembers = function()
    return #(_G.__partyMembers or {})
end
_G.GetNumRaidMembers = function()
    return _G.__inRaid and (#(_G.__partyMembers or {}) + 1) or 0
end

_G.UnitExists = function(unit)
    if unit == "player" then
        return true
    end

    local index = unit and tonumber(string.match(unit, "^party(%d+)$"))
    return index ~= nil and _G.__partyMembers[index] ~= nil
end

_G.UnitName = function(unit)
    if unit == "player" then
        return _G.__playerName, _G.__playerRealm
    end

    local index = unit and tonumber(string.match(unit, "^party(%d+)$"))
    local name = index and _G.__partyMembers[index] or nil
    if not name then
        return nil
    end

    local baseName, realm = string.match(name, "^([^%-]+)%-(.+)$")
    if baseName then
        return baseName, realm
    end

    return name, _G.__playerRealm
end

_G.C_QuestLog = {
    GetNumQuestLogEntries = function()
        return #(_G.__questLog or {})
    end,
    GetInfo = function(index)
        local quest = (_G.__questLog or {})[index]
        if not quest then
            return nil
        end

        return {
            title = quest.title,
            level = quest.level,
            isHeader = quest.isHeader,
            isComplete = quest.isComplete,
            questID = quest.questID,
        }
    end,
    GetQuestObjectives = function(questId)
        for _, quest in ipairs(_G.__questLog or {}) do
            if quest.questID == questId then
                return quest.objectives
            end
        end
        return {}
    end,
}

_G.GetNumQuestLogEntries = function()
    return #(_G.__questLog or {})
end

_G.GetQuestLogTitle = function(index)
    local quest = (_G.__questLog or {})[index]
    if not quest then
        return nil
    end

    return quest.title, quest.level, nil, quest.isHeader, nil, quest.isComplete, nil, quest.questID
end

_G.GetNumQuestLeaderBoards = function(index)
    local quest = (_G.__questLog or {})[index]
    return #(quest and quest.objectives or {})
end

_G.GetQuestLogLeaderBoard = function(objectiveIndex, questIndex)
    local quest = (_G.__questLog or {})[questIndex]
    local objective = quest and quest.objectives and quest.objectives[objectiveIndex] or nil
    if not objective then
        return nil
    end

    return objective.text, objective.type, objective.finished
end

_G.IsQuestWatched = function(index)
    local quest = (_G.__questLog or {})[index]
    return quest and quest.watched or false
end

local function loadModule(path)
    local chunk, loadError = loadfile(path)
    if not chunk then
        error(loadError)
    end
    return chunk("QuestBuddy", _G.QuestBuddy)
end

loadModule("Compat.lua")
loadModule("PartyApi.lua")
loadModule("QuestApi.lua")
loadModule("Snapshot.lua")
loadModule("Protocol.lua")
loadModule("State.lua")
loadModule("Tracker.lua")
loadModule("UI.lua")
loadModule("Options.lua")
loadModule("Comms.lua")
loadModule("QuestBuddy.lua")

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

local function makeQuest(key, title, level, watched, status, objectives, updated)
    return {
        questKey = key,
        questId = 0,
        title = title,
        level = level,
        watched = watched,
        status = status or "active",
        updated = updated or 1,
        objectives = objectives or {},
    }
end

local function resetAddonState()
    resetTestEnvironment()
    QB.initialized = false
    QB.db = nil
    QuestBuddyDB = nil
    QB.State.session = nil
    QB.Tracker.frame = nil
    QB.Tracker.rows = {}
    QB.UI.frame = nil
    QB.UI.rows = {}
    QB.Options.panel = nil
    QB.Options.category = nil
    QB.Comms.incomingTransfers = {}
    QB.Comms.pendingSnapshotTimer = nil
    QB.Comms.lastSnapshotSentAt = 0
    QB.frame = newFrame("Frame", "QuestBuddyFrame", nil, nil)
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

local function testSignatureIgnoresUpdatedTimestamp()
    local left = makeSnapshot("Me-Realm", 1, {
        makeQuest("id:1", "Stable Quest", 10, true, "active", {}, 100),
    })
    local right = makeSnapshot("Me-Realm", 1, {
        makeQuest("id:1", "Stable Quest", 10, true, "active", {}, 101),
    })

    expectEquals(QB.Snapshot:BuildSignature(left), QB.Snapshot:BuildSignature(right), "signature ignores per-quest updated timestamps")
end

local function testStalePeerHandling()
    QB.State:Initialize({})
    QB.State:MarkPeerHello("Buddy-Realm", 2, 100)
    expectEquals(QB.State:GetPeerStatus(QB.State:GetPeer("Buddy-Realm"), 100, 90), "Updating", "hello without snapshot is updating")

    QB.State:ApplyPeerSnapshot("Buddy-Realm", makeSnapshot("Buddy-Realm", 2, {}), 120)
    expectEquals(QB.State:GetPeerStatus(QB.State:GetPeer("Buddy-Realm"), 150, 90), "Live", "fresh peer is live")
    expectEquals(QB.State:GetPeerStatus(QB.State:GetPeer("Buddy-Realm"), 220, 90), "Stale", "old peer becomes stale")

    QB.State:MarkPeerOffline("Buddy-Realm", 221)
    expectEquals(QB.State:GetPeerStatus(QB.State:GetPeer("Buddy-Realm"), 221, 90), "Offline", "offline peer status")
end

local function testNewerHelloMarksPeerUpdating()
    QB.State:Initialize({})
    QB.State:ApplyPeerSnapshot("Buddy-Realm", makeSnapshot("Buddy-Realm", 1, {}), 10)
    QB.State:MarkPeerHello("Buddy-Realm", 2, 11)
    expectEquals(QB.State:GetPeerStatus(QB.State:GetPeer("Buddy-Realm"), 11, 90), "Updating", "newer hello revision marks peer updating")
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
    expectEquals(liveRows[1].title, "Shared Quest", "tracker preserves watched quest title")
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

local function testRefreshLocalSnapshotIgnoresUpdatedOnlyChanges()
    QB.State:Initialize({})
    local originalBuildLocalSnapshot = QB.QuestApi.BuildLocalSnapshot

    QB.QuestApi.BuildLocalSnapshot = function(_, now)
        return {
            player = "Me-Realm",
            createdAt = now,
            revision = 0,
            quests = {
                makeQuest("id:1", "Stable Quest", 10, true, "active", {}, now),
            },
        }
    end

    local firstChanged = select(1, QB.State:RefreshLocalSnapshot(100))
    local secondChanged = select(1, QB.State:RefreshLocalSnapshot(101))

    QB.QuestApi.BuildLocalSnapshot = originalBuildLocalSnapshot

    expectTrue(firstChanged, "first local snapshot refresh records a change")
    expectEquals(secondChanged, false, "timestamp-only local snapshot changes do not bump revision")
end

local function testSendSnapshotUsesWhisperAndBoundedChunks()
    QB.State:Initialize({})
    QB.Comms:Initialize()

    QB.State:GetSession().localSnapshot = makeSnapshot("Me-Realm", 5, {
        makeQuest("id:1", "Verbose Quest", 10, true, "active", {
            {
                text = string.rep("A very long objective description ", 12),
                current = 12,
                required = 20,
                done = false,
            },
        }),
    })

    _G.__sentMessages = {}
    local sent = QB.Comms:SendSnapshot("Buddy-Realm")

    expectTrue(sent, "snapshot send succeeds")
    expectTrue(#_G.__sentMessages > 3, "snapshot send uses chunk messages")
    expectEquals(_G.__sentMessages[1].distribution, "WHISPER", "targeted snapshot uses whisper distribution")
    expectEquals(_G.__sentMessages[1].target, "Buddy-Realm", "targeted snapshot uses sender as whisper target")

    for _, message in ipairs(_G.__sentMessages) do
        expectTrue(string.len(message.payload) <= QB.Protocol.MAX_MESSAGE_SIZE, "encoded addon payload stays within the message budget")
    end
end

local function testHelloRequestUsesWhisper()
    QB.State:Initialize({})
    QB.Comms:Initialize()
    QB.State:ApplyPeerSnapshot("Buddy-Realm", makeSnapshot("Buddy-Realm", 1, {}), 5)

    _G.__sentMessages = {}
    QB.Comms:OnAddonMessage(QB.Protocol.PREFIX, QB.Protocol:EncodeHello(2, 0), "PARTY", "Buddy-Realm")

    expectEquals(_G.__sentMessages[1].distribution, "WHISPER", "hello snapshot request uses whisper distribution")
    expectEquals(_G.__sentMessages[1].target, "Buddy-Realm", "hello snapshot request targets the announcing peer")
end

local function testSnapshotTransferTimeoutClearsUpdatingState()
    QB.State:Initialize({})
    QB.Comms:Initialize()

    local originalAfter = QB.Compat.After
    local originalCancelTimer = QB.Compat.CancelTimer
    local scheduledCallback
    local scheduledArgs

    QB.Compat.After = function(_, _, callback, ...)
        scheduledCallback = callback
        scheduledArgs = { ... }
        return 99
    end
    QB.Compat.CancelTimer = function() end

    QB.Comms:HandleSnapshotStart("Buddy-Realm", { "transfer-1", "2", "1", "100", "10" })
    expectEquals(QB.State:GetPeer("Buddy-Realm").updating, true, "snapshot start marks peer updating")

    scheduledCallback(table.unpack(scheduledArgs))

    QB.Compat.After = originalAfter
    QB.Compat.CancelTimer = originalCancelTimer

    expectEquals(QB.State:GetPeer("Buddy-Realm").updating, false, "timed out snapshot clears updating state")
    expectEquals(QB.Comms.incomingTransfers["Buddy-Realm"], nil, "timed out transfer is discarded")
end

local function testQuestApiBuildsRetailSnapshot()
    local snapshot = QB.QuestApi:BuildLocalSnapshot(33)

    expectEquals(snapshot.player, "Me-Realm", "retail snapshot uses fully qualified player name")
    expectEquals(snapshot.quests[1].questId, 101, "retail snapshot reads quest id")
    expectEquals(snapshot.quests[1].objectives[1].current, 1, "retail snapshot reads current objective progress")
    expectEquals(snapshot.quests[1].objectives[1].required, 4, "retail snapshot reads required objective progress")
end

local function testAddonInitializesRetailRuntime()
    resetAddonState()
    QB:OnEvent("ADDON_LOADED", "QuestBuddy")

    expectTrue(QB.initialized, "addon initializes on ADDON_LOADED")
    expectTrue(_G.__registeredPrefixes[QB.Protocol.PREFIX], "addon registers its addon chat prefix")
    expectTrue(QB.frame.events["GROUP_ROSTER_UPDATE"] == true, "addon listens for retail group roster updates")
    expectTrue(QB.Options.category ~= nil, "addon registers a retail settings category")
    expectEquals(_G.__sentMessages[1].distribution, "PARTY", "initial roster sync still broadcasts to the party")
end

local tests = {
    testProtocolRoundTrip,
    testMalformedMessageRejected,
    testSnapshotSerializeChunkRoundTrip,
    testSignatureIgnoresUpdatedTimestamp,
    testStalePeerHandling,
    testNewerHelloMarksPeerUpdating,
    testFocusedBuddySelection,
    testTrackerRenderingDecisions,
    testMainWindowRowBuilding,
    testPartyJoinLeaveBehavior,
    testRefreshLocalSnapshotIgnoresUpdatedOnlyChanges,
    testSendSnapshotUsesWhisperAndBoundedChunks,
    testHelloRequestUsesWhisper,
    testSnapshotTransferTimeoutClearsUpdatingState,
    testQuestApiBuildsRetailSnapshot,
    testAddonInitializesRetailRuntime,
}

for _, test in ipairs(tests) do
    test()
end

if failures > 0 then
    io.stderr:write(string.format("%d/%d tests failed\n", failures, total))
    os.exit(1)
end

print(string.format("%d tests passed", total))
