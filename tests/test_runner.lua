---@diagnostic disable: undefined-global, undefined-field
_G = _G or _ENV
_G.QuestBuddy = {}

local unpackCompat = rawget(table, "unpack") or unpack

local function makeFontString()
    return {
        text = "",
        shown = true,
        SetPoint = function() end,
        ClearAllPoints = function() end,
        SetWidth = function() end,
        SetText = function(self, text)
            self.text = text
        end,
        SetJustifyH = function() end,
        Show = function(self)
            self.shown = true
        end,
        Hide = function(self)
            self.shown = false
        end,
    }
end

local frameMethods = {}

function frameMethods:SetScript(name, callback)
    self.scripts[name] = callback
end

function frameMethods:HookScript(name, callback)
    local existing = self.scripts[name]
    if not existing then
        self.scripts[name] = callback
        return
    end

    self.scripts[name] = function(...)
        existing(...)
        callback(...)
    end
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

function frameMethods:GetName()
    return self.name
end

function frameMethods:NumLines()
    return #(self.leftLines or {})
end

function frameMethods:AddLine(text)
    self.leftLines = self.leftLines or {}
    table.insert(self.leftLines, text)
end

function frameMethods:SetChecked(value)
    self.checked = value and true or false
end

function frameMethods:GetChecked()
    return self.checked
end

local selectedQuestLogIndex = nil

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
    selectedQuestLogIndex = nil
    _G.GameTooltip = newFrame("GameTooltip", "GameTooltip", nil, nil)
    _G.GameTooltip.leftLines = {}
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
_G.UIDropDownMenu_AddButton = function(info, level)
    return info, level
end
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
    local quests = 0

    for _, quest in ipairs(_G.__questLog or {}) do
        if not quest.isHeader then
            quests = quests + 1
        end
    end

    local visibleEntries = 0
    for _, quest in ipairs(_G.__questLog or {}) do
        if quest.isHeader then
            visibleEntries = visibleEntries + 1
        elseif not quest.headerIndex or not (_G.__questLog[quest.headerIndex] and _G.__questLog[quest.headerIndex].isCollapsed) then
            visibleEntries = visibleEntries + 1
        end
    end

    return visibleEntries, quests
end

_G.GetQuestLogTitle = function(index)
    local visibleIndex = 0

    for _, quest in ipairs(_G.__questLog or {}) do
        local hiddenByHeader = quest.headerIndex and (_G.__questLog[quest.headerIndex] and _G.__questLog[quest.headerIndex].isCollapsed)
        if quest.isHeader or not hiddenByHeader then
            visibleIndex = visibleIndex + 1
            if visibleIndex == index then
                return quest.title, quest.level, nil, quest.isHeader, quest.isCollapsed, quest.isComplete, nil, quest.questID, nil, nil, nil, nil, nil, nil, nil, quest.isHidden
            end
        end
    end

    return nil
end

_G.GetNumQuestLeaderBoards = function(index)
    local quest = (_G.__questLog or {})[selectedQuestLogIndex or index]
    return #(quest and quest.objectives or {})
end

_G.GetQuestLogLeaderBoard = function(objectiveIndex, questIndex)
    local quest = (_G.__questLog or {})[selectedQuestLogIndex or questIndex]
    local objective = quest and quest.objectives and quest.objectives[objectiveIndex] or nil
    if not objective then
        return nil
    end

    return objective.text, objective.type, objective.finished
end

_G.IsQuestWatched = function(index)
    local visibleIndex = 0

    for _, quest in ipairs(_G.__questLog or {}) do
        local hiddenByHeader = quest.headerIndex and (_G.__questLog[quest.headerIndex] and _G.__questLog[quest.headerIndex].isCollapsed)
        if quest.isHeader or not hiddenByHeader then
            visibleIndex = visibleIndex + 1
            if visibleIndex == index then
                return quest and quest.watched or false
            end
        end
    end

    return false
end

_G.SelectQuestLogEntry = function(index)
    selectedQuestLogIndex = index
end

_G.GetQuestLogSelection = function()
    return selectedQuestLogIndex
end

_G.ExpandQuestHeader = function(index)
    if index == 0 then
        for _, quest in ipairs(_G.__questLog or {}) do
            if quest.isHeader then
                quest.isCollapsed = false
            end
        end
        return
    end

    local quest = (_G.__questLog or {})[index]
    if quest and quest.isHeader then
        quest.isCollapsed = false
    end
end

_G.CollapseQuestHeader = function(index)
    local visibleIndex = 0
    for _, quest in ipairs(_G.__questLog or {}) do
        local hiddenByHeader = quest.headerIndex and (_G.__questLog[quest.headerIndex] and _G.__questLog[quest.headerIndex].isCollapsed)
        if quest.isHeader or not hiddenByHeader then
            visibleIndex = visibleIndex + 1
            if visibleIndex == index then
                if quest.isHeader then
                    quest.isCollapsed = true
                end
                return
            end
        end
    end
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

local function setTooltipLines(tooltip, lines)
    tooltip.leftLines = {}

    for _, line in ipairs(lines or {}) do
        table.insert(tooltip.leftLines, line)
    end
end

local function readFile(path)
    local handle, openError = io.open(path, "rb")
    if not handle then
        error(openError)
    end

    local contents = handle:read("*a")
    handle:close()
    return contents
end

local function resetAddonState()
    resetTestEnvironment()
    QB.initialized = false
    QB.db = nil
    QuestBuddyDB = nil
    QB.QuestApi.titleFieldOffset = nil
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

local function testStateFreshestLivePeerSelectors()
    QB.State:Initialize({})
    QB.State:ApplyPeerSnapshot("Stale-Realm", makeSnapshot("Stale-Realm", 1, {}), 10)
    QB.State:ApplyPeerSnapshot("Fresh-Realm", makeSnapshot("Fresh-Realm", 1, {}), 50)
    QB.State:MarkPeerOffline("Offline-Realm", 50)

    local selectedName = QB.State:GetFreshestLivePeer(80, 40)
    expectEquals(selectedName, "Fresh-Realm", "freshest live selector prefers the lowest live age")

    local staleDuration = QB.State:GetStaleDuration(QB.State:GetPeer("Stale-Realm"), 80, 40)
    expectEquals(staleDuration, 30, "stale duration selector subtracts stale timeout from peer age")

    local thresholds = QB.State:GetStaleThresholds(40)
    expectEquals(thresholds.staleAtSeconds, 40, "stale thresholds expose configured stale-at value")
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

local function testPeerSummaryRowsIncludeSharedAndReadyCounts()
    QB.State:Initialize({})
    QB.State:GetSession().localSnapshot = makeSnapshot("Me", 1, {
        makeQuest("shared", "Shared Quest", 10, true, "active", {}),
        makeQuest("mine-only", "Mine Only", 11, false, "active", {}),
    })

    QB.State:ApplyPeerSnapshot("Buddy-Realm", makeSnapshot("Buddy-Realm", 2, {
        makeQuest("shared", "Shared Quest", 10, true, "ready", {}),
        makeQuest("buddy-only", "Buddy Only", 12, false, "ready", {}),
    }), 25)
    QB.State:MarkPeerOffline("Offline-Realm", 26)

    local summaryRows = QB.State:GetPeerSummaryRows(30, 90)
    expectEquals(#summaryRows, 2, "peer summary returns one row per known peer")
    expectEquals(summaryRows[1].name, "Buddy-Realm", "peer summary rows are sorted by peer name")
    expectEquals(summaryRows[1].status, "Live", "peer summary exposes peer status")
    expectEquals(summaryRows[1].sharedCount, 1, "peer summary counts quests shared with local snapshot")
    expectEquals(summaryRows[1].readyCount, 2, "peer summary counts ready-to-turn-in quests")
    expectEquals(summaryRows[2].status, "Offline", "peer summary includes offline peers")
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

local function testSimulatedBuddyUsesLocalQuests()
    QB.State:Initialize({ lastFocusedBuddy = "Alice" })
    QB.State:GetSession().localSnapshot = makeSnapshot("Me", 3, {
        makeQuest("shared", "Shared Quest", 10, true, "active", {
            { text = "Apples: 2/6", current = 2, required = 6, done = false },
        }, 30),
        makeQuest("ready", "Ready Quest", 11, false, "ready", {
            { text = "Speak with the scout", current = nil, required = nil, done = true },
        }, 30),
    })

    local enabled = QB.State:ToggleSimulatedPeer(45)
    local simulatedName = QB.State:GetSimulatedPeerName()
    local simulatedPeer = QB.State:GetPeer(simulatedName)

    expectEquals(enabled, true, "simulation toggles on")
    expectEquals(simulatedName, "Simulated Buddy", "simulation uses the expected peer name")
    expectTrue(simulatedPeer ~= nil, "simulation creates a peer")
    expectEquals(QB.State:GetFocusedBuddy(), simulatedName, "simulation becomes focused buddy")
    expectEquals(#simulatedPeer.snapshot.quests, 2, "simulation reuses the local quest list")
    expectEquals(simulatedPeer.snapshot.quests[1].questKey, "shared", "simulation preserves quest identity")
    expectTrue(simulatedPeer.snapshot.quests[1].objectives[1].current ~= 2 or simulatedPeer.snapshot.quests[1].status ~= "active", "simulation changes quest progress details")

    QB.State:PrunePeers({}, 50)
    expectEquals(QB.State:GetPeer(simulatedName).online, true, "simulation peer survives party pruning")

    local disabled = QB.State:ToggleSimulatedPeer(51)
    expectEquals(disabled, false, "simulation toggles off")
    expectEquals(QB.State:GetPeer(simulatedName), nil, "simulation peer is removed when cleared")
end

local function testRefreshViewsDoesNotPersistSimulatedFocus()
    resetAddonState()
    QB.State:Initialize({ lastFocusedBuddy = "Alice" })
    QB.db = QB.Compat:MergeDefaults({ lastFocusedBuddy = "Alice" }, QB.defaults)
    QB.State:GetSession().localSnapshot = makeSnapshot("Me", 1, {
        makeQuest("id:1", "Quest", 10, true, "active", {}, 1),
    })

    QB.State:ToggleSimulatedPeer(10)
    QB:RefreshViews("test-simulated-focus")

    expectEquals(QB.db.lastFocusedBuddy, "Alice", "simulated focus does not overwrite persisted buddy selection")
end

local function testMainWindowSimulationButtonToggles()
    resetAddonState()
    QB:OnEvent("ADDON_LOADED", "QuestBuddy")

    expectEquals(QB.UI.frame.simulateButton:GetText(), "Simulate", "main window starts with simulate button label")

    QB.UI.frame.simulateButton:GetScript("OnClick")()
    expectEquals(QB.State:GetSimulatedPeerName(), "Simulated Buddy", "simulate button creates the simulated peer")
    expectEquals(QB.UI.frame.simulateButton:GetText(), "Clear Sim", "simulate button updates label after enabling")

    QB.UI.frame.simulateButton:GetScript("OnClick")()
    expectEquals(QB.State:GetSimulatedPeerName(), nil, "simulate button clears the simulated peer")
    expectEquals(QB.UI.frame.simulateButton:GetText(), "Simulate", "simulate button restores label after clearing")
end

local function testSimulationRefreshesLocalSnapshotBeforeBuildingPeer()
    resetAddonState()
    QB.State:Initialize({})
    QB.db = QB.Compat:MergeDefaults({}, QB.defaults)

    local refreshCalls = 0
    local originalRefreshLocalSnapshot = QB.State.RefreshLocalSnapshot

    QB.State.RefreshLocalSnapshot = function(state, now)
        refreshCalls = refreshCalls + 1
        state:GetSession().localSnapshot = makeSnapshot("Me", 7, {
            makeQuest("id:77", "Fresh Quest", 12, true, "active", {
                { text = "Items: 1/3", current = 1, required = 3, done = false },
            }, now),
        })
        return true, state:GetSession().localSnapshot
    end

    QB:ToggleSimulationBuddy()

    QB.State.RefreshLocalSnapshot = originalRefreshLocalSnapshot

    expectEquals(refreshCalls, 1, "simulation refreshes the local snapshot before building the peer")
    expectEquals(QB.State:GetPeer("Simulated Buddy").snapshot.quests[1].questKey, "id:77", "simulation uses refreshed local quest data")
end

local function testSimulatedEmptyStateExplainsMissingLocalQuests()
    resetAddonState()
    QB:OnEvent("ADDON_LOADED", "QuestBuddy")
    QB.State:GetSession().localSnapshot = makeSnapshot("Me", 1, {})

    QB.State:CreateSimulatedPeer(10)
    QB.UI:Refresh("test-empty-sim")

    expectEquals(QB.UI.rows[1].header.text, "No local quests found to simulate", "simulated empty state explains missing local quest data")
end

local function testTooltipShowsSimulatedBuddyQuestProgressForUnitTooltip()
    resetAddonState()
    QB:OnEvent("ADDON_LOADED", "QuestBuddy")

    QB.State:GetSession().localSnapshot = makeSnapshot("Me", 1, {
        makeQuest("shared", "Shared Quest", 10, true, "active", {
            { text = "Apples: 1/6", current = 1, required = 6, done = false },
        }, 1),
    })
    QB.State:CreateSimulatedPeer(10)

    setTooltipLines(_G.GameTooltip, {
        "Hungry Wolf",
        "Dead",
        "Apples: 1/6",
    })

    _G.GameTooltip:GetScript("OnTooltipSetUnit")(_G.GameTooltip)

    expectEquals(_G.GameTooltip.leftLines[4], " ", "tooltip inserts a spacer before QuestBuddy lines")
    expectEquals(_G.GameTooltip.leftLines[5], "QuestBuddy: Simulated Buddy", "tooltip adds a QuestBuddy header for the focused simulated buddy")
    expectEquals(_G.GameTooltip.leftLines[6], "Shared Quest: Apples: 2/6", "tooltip shows simulated buddy progress for the matched tooltip objective")
end

local function testTooltipLimitsQuestProgressToMatchedObjective()
    resetAddonState()
    QB:OnEvent("ADDON_LOADED", "QuestBuddy")

    QB.State:GetSession().localSnapshot = makeSnapshot("Me", 1, {
        makeQuest("shared", "Pacify the Centaur", 10, true, "active", {
            { text = "Galak Scout slain: 1/12", current = 1, required = 12, done = false },
            { text = "Galak Wrangler slain: 3/10", current = 3, required = 10, done = false },
            { text = "Galak Windchaser slain: 6/6", current = 6, required = 6, done = true },
        }, 1),
    })
    QB.State:CreateSimulatedPeer(10)

    setTooltipLines(_G.GameTooltip, {
        "Galak Scout",
        "Dead",
        "Pacify the Centaur",
        "- Galak Scout slain: 1/12",
    })

    _G.GameTooltip:GetScript("OnTooltipSetUnit")(_G.GameTooltip)

    expectEquals(_G.GameTooltip.leftLines[7], "Pacify the Centaur: Galak Scout slain: 2/12", "tooltip prefers the bullet objective match over the quest title summary")
    expectEquals(_G.GameTooltip.leftLines[8], nil, "tooltip does not append unrelated objectives from the same quest")
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

local function testSnapshotRequestHonorsTargetName()
    QB.State:Initialize({})
    QB.Comms:Initialize()
    QB.State:GetSession().localSnapshot = makeSnapshot("Me-Realm", 1, {
        makeQuest("id:1", "Quest", 10, true, "active", {}),
    })

    _G.__sentMessages = {}
    QB.Comms:HandleSnapshotRequest("Buddy-Realm", { "Someone-Else", "manual" })
    expectEquals(#_G.__sentMessages, 0, "snapshot request for a different target is ignored")

    QB.Comms:HandleSnapshotRequest("Buddy-Realm", { "Me-Realm", "manual" })
    expectTrue(#_G.__sentMessages > 0, "snapshot request targeting this player sends a snapshot")
    expectEquals(_G.__sentMessages[1].distribution, "WHISPER", "targeted snapshot request replies with whisper")
    expectEquals(_G.__sentMessages[1].target, "Buddy-Realm", "targeted snapshot request replies to sender")
end

local function testRefreshRequestThrottlesRepeatedRequests()
    QB.State:Initialize({})
    QB.Comms:Initialize()

    _G.__sentMessages = {}
    _G.__time = 100
    local firstSent = QB.Comms:RequestPeerRefresh("Buddy-Realm", "manual")
    local secondSent = QB.Comms:RequestPeerRefresh("Buddy-Realm", "manual")

    expectEquals(firstSent, true, "first refresh request is sent")
    expectEquals(secondSent, false, "repeat refresh request inside throttle window is skipped")
    expectEquals(#_G.__sentMessages, 1, "throttled refresh request does not enqueue extra addon messages")

    _G.__time = 109
    local thirdSent = QB.Comms:RequestPeerRefresh("Buddy-Realm", "manual")
    expectEquals(thirdSent, true, "refresh request is allowed again after throttle window")
    expectEquals(#_G.__sentMessages, 2, "post-throttle refresh request sends a second addon message")
end

local function testAddonMessageIgnoresNonPartyAndSelfMessages()
    QB.State:Initialize({})
    QB.Comms:Initialize()
    QB.State:GetSession().localSnapshot = makeSnapshot("Me-Realm", 1, {})

    _G.__partyMembers = { "Buddy-Realm" }
    _G.__sentMessages = {}
    QB.Comms:OnAddonMessage(QB.Protocol.PREFIX, QB.Protocol:EncodeHello(2, 0), "PARTY", "Me-Realm")
    expectEquals(#_G.__sentMessages, 0, "messages sent by self are ignored")

    QB.Comms:OnAddonMessage(QB.Protocol.PREFIX, QB.Protocol:EncodeHello(2, 0), "PARTY", "Stranger-Realm")
    expectEquals(#_G.__sentMessages, 0, "messages from non-party senders are ignored")
end

local function testQueueSnapshotBroadcastReschedulesDuringCooldown()
    QB.State:Initialize({})
    QB.Comms:Initialize()

    local originalAfter = QB.Compat.After
    local originalCancelTimer = QB.Compat.CancelTimer
    local originalIsInParty = QB.Compat.IsInParty
    local originalSendSnapshot = QB.Comms.SendSnapshot
    local timers = {}
    local sendCount = 0
    local cancelCount = 0

    QB.Compat.After = function(_, seconds, callback)
        table.insert(timers, { seconds = seconds, callback = callback })
        return #timers
    end
    QB.Compat.CancelTimer = function(_, timerId)
        if timerId then
            cancelCount = cancelCount + 1
        end
    end
    QB.Compat.IsInParty = function()
        return true
    end
    QB.Comms.SendSnapshot = function()
        sendCount = sendCount + 1
        return true
    end

    QB.Comms.lastSnapshotSentAt = 10
    _G.__time = 12
    QB.Comms:QueueSnapshotBroadcast("quest-update")

    expectEquals(#timers, 1, "queue snapshot schedules an initial timer")

    timers[1].callback()
    expectEquals(#timers, 2, "queue snapshot reschedules while inside cooldown window")
    expectEquals(sendCount, 0, "queue snapshot does not send while still throttled")

    _G.__time = 15
    timers[2].callback()
    expectEquals(sendCount, 1, "queue snapshot sends once cooldown has elapsed")
    expectEquals(cancelCount, 1, "queue snapshot cancels prior timer before scheduling a replacement")
    expectEquals(QB.Comms.pendingSnapshotTimer, nil, "queue snapshot clears pending timer after send")

    QB.Compat.After = originalAfter
    QB.Compat.CancelTimer = originalCancelTimer
    QB.Compat.IsInParty = originalIsInParty
    QB.Comms.SendSnapshot = originalSendSnapshot
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

    scheduledCallback(unpackCompat(scheduledArgs))

    QB.Compat.After = originalAfter
    QB.Compat.CancelTimer = originalCancelTimer

    expectEquals(QB.State:GetPeer("Buddy-Realm").updating, false, "timed out snapshot clears updating state")
    expectEquals(QB.Comms.incomingTransfers["Buddy-Realm"], nil, "timed out transfer is discarded")
end

local function testSnapshotEndRejectsChecksumMismatch()
    QB.State:Initialize({})
    QB.Comms:Initialize()

    local snapshot = makeSnapshot("Buddy-Realm", 3, {
        makeQuest("id:1", "Quest", 10, true, "active", {
            { text = "Widgets: 2/4", current = 2, required = 4, done = false },
        }),
    })
    local serialized = QB.Snapshot:Serialize(snapshot, true)
    local transferId = "transfer-bad-checksum"

    QB.Comms:HandleSnapshotStart("Buddy-Realm", {
        transferId,
        tostring(snapshot.revision),
        "1",
        tostring(QB.Snapshot:Checksum(serialized)),
        tostring(string.len(serialized)),
    })
    QB.Comms:HandleSnapshotChunk("Buddy-Realm", { transferId, "1", serialized })
    QB.Comms:HandleSnapshotEnd("Buddy-Realm", {
        transferId,
        tostring(snapshot.revision),
        tostring(QB.Snapshot:Checksum(serialized) + 1),
    })

    expectEquals(QB.State:GetPeer("Buddy-Realm").updating, false, "checksum mismatch clears peer updating flag")
    expectEquals(QB.State:GetPeer("Buddy-Realm").snapshot, nil, "checksum mismatch does not apply snapshot")
    expectEquals(QB.Comms.incomingTransfers["Buddy-Realm"], nil, "checksum mismatch clears incoming transfer state")
end

local function testSnapshotEndAppliesValidSnapshot()
    QB.State:Initialize({})
    QB.Comms:Initialize()

    local snapshot = makeSnapshot("Buddy-Realm", 4, {
        makeQuest("id:2", "Quest Two", 12, true, "active", {
            { text = "Dust: 1/2", current = 1, required = 2, done = false },
        }),
    })
    local serialized = QB.Snapshot:Serialize(snapshot, true)
    local checksum = QB.Snapshot:Checksum(serialized)
    local transferId = "transfer-good"

    QB.Comms:HandleSnapshotStart("Buddy-Realm", {
        transferId,
        tostring(snapshot.revision),
        "1",
        tostring(checksum),
        tostring(string.len(serialized)),
    })
    QB.Comms:HandleSnapshotChunk("Buddy-Realm", { transferId, "1", serialized })
    QB.Comms:HandleSnapshotEnd("Buddy-Realm", {
        transferId,
        tostring(snapshot.revision),
        tostring(checksum),
    })

    local peer = QB.State:GetPeer("Buddy-Realm")
    expectEquals(peer.updating, false, "valid snapshot clears peer updating flag")
    expectEquals(peer.snapshot.revision, 4, "valid snapshot is applied to peer state")
    expectEquals(peer.snapshot.quests[1].questKey, "id:2", "valid snapshot preserves quest records")
end

local function testQuestApiBuildsRetailSnapshot()
    local snapshot = QB.QuestApi:BuildLocalSnapshot(33)

    expectEquals(snapshot.player, "Me-Realm", "retail snapshot uses fully qualified player name")
    expectEquals(snapshot.quests[1].questId, 101, "retail snapshot reads quest id")
    expectEquals(snapshot.quests[1].objectives[1].current, 1, "retail snapshot reads current objective progress")
    expectEquals(snapshot.quests[1].objectives[1].required, 4, "retail snapshot reads required objective progress")
end

local function testQuestApiFallsBackWhenRetailQuestLogIsEmpty()
    local originalRetailQuestLog = _G.C_QuestLog

    _G.C_QuestLog = {
        GetNumQuestLogEntries = function()
            return 0
        end,
        GetInfo = function()
            return nil
        end,
        GetQuestObjectives = function()
            return {}
        end,
    }

    QB.QuestApi.titleFieldOffset = nil
    loadModule("QuestApi.lua")

    local snapshot = QB.QuestApi:BuildLocalSnapshot(44)

    expectEquals(#snapshot.quests, 1, "quest api falls back to legacy entry count when retail returns zero")
    expectEquals(snapshot.quests[1].title, "Training Day", "quest api falls back to legacy quest info when retail returns nil")

    _G.C_QuestLog = originalRetailQuestLog
    loadModule("QuestApi.lua")
end

local function testQuestApiExpandsCollapsedLegacyHeaders()
    local originalRetailQuestLog = _G.C_QuestLog

    _G.C_QuestLog = nil
    QB.QuestApi.titleFieldOffset = nil
    loadModule("QuestApi.lua")

    _G.__questLog = {
        {
            title = "Elwynn Forest",
            level = 0,
            questID = 0,
            isHeader = true,
            isCollapsed = true,
            objectives = {},
        },
        {
            title = "Hidden Quest",
            level = 9,
            questID = 205,
            isHeader = false,
            isComplete = false,
            watched = true,
            headerIndex = 1,
            objectives = {
                {
                    text = "Bandanas: 2/8",
                    numFulfilled = 2,
                    numRequired = 8,
                    finished = false,
                    type = "item",
                },
            },
        },
    }

    local snapshot = QB.QuestApi:BuildLocalSnapshot(55)

    expectEquals(#snapshot.quests, 1, "quest api expands collapsed legacy headers to find hidden quests")
    expectEquals(snapshot.quests[1].title, "Hidden Quest", "quest api captures quests under collapsed headers")
    expectEquals(_G.__questLog[1].isCollapsed, true, "quest api restores collapsed header state after reading")

    _G.C_QuestLog = originalRetailQuestLog
    loadModule("QuestApi.lua")
end

local function testQuestApiRestoresMultipleCollapsedHeaders()
    local originalRetailQuestLog = _G.C_QuestLog

    _G.C_QuestLog = nil
    QB.QuestApi.titleFieldOffset = nil
    loadModule("QuestApi.lua")

    -- Two consecutive collapsed zone headers, each with hidden quests.
    -- Before the fix, restoreCollapsedHeaders used pre-expansion visible indices,
    -- which shifted after ExpandQuestHeader(0), causing the second header to stay expanded.
    _G.__questLog = {
        {
            title = "Elwynn Forest",
            level = 0, questID = 0,
            isHeader = true, isCollapsed = false,
        },
        {
            title = "Quest A",
            level = 5, questID = 101,
            isHeader = false, isComplete = false, watched = false,
            headerIndex = 1,
            objectives = {},
        },
        {
            title = "Westfall",
            level = 0, questID = 0,
            isHeader = true, isCollapsed = true,
        },
        {
            title = "Quest B",
            level = 10, questID = 102,
            isHeader = false, isComplete = false, watched = false,
            headerIndex = 3,
            objectives = {},
        },
        {
            title = "Redridge Mountains",
            level = 0, questID = 0,
            isHeader = true, isCollapsed = true,
        },
        {
            title = "Quest C",
            level = 15, questID = 103,
            isHeader = false, isComplete = false, watched = false,
            headerIndex = 5,
            objectives = {},
        },
    }

    QB.QuestApi:BuildLocalSnapshot(66)

    expectEquals(_G.__questLog[3].isCollapsed, true, "first consecutive collapsed header is restored after snapshot build")
    expectEquals(_G.__questLog[5].isCollapsed, true, "second consecutive collapsed header is restored after snapshot build")

    _G.C_QuestLog = originalRetailQuestLog
    QB.QuestApi.titleFieldOffset = nil
    loadModule("QuestApi.lua")
end

local function testQuestApiDetectsAscensionShiftedLayout()
    local originalRetailQuestLog = _G.C_QuestLog
    local originalGetQuestLogTitle = _G.GetQuestLogTitle

    _G.C_QuestLog = nil
    QB.QuestApi.titleFieldOffset = nil

    -- Simulate Ascension's GetQuestLogTitle with an extra field at position 4
    -- Standard: title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID
    -- Ascension: title, level, suggestedGroup, extra, isHeader, isCollapsed, isComplete, frequency, questID
    _G.GetQuestLogTitle = function(index)
        local entries = {
            { "Arathi Highlands", 0, nil, 0, 1, nil, nil, nil, 0 },     -- zone header (expanded)
            { "Call to Arms",     35, nil, 0, nil, nil, nil, nil, 301 }, -- quest
            { "Foul Magics",     36, nil, 0, nil, nil, nil, nil, 302 }, -- quest
        }
        local entry = entries[index]
        if not entry then return nil end
        return entry[1], entry[2], entry[3], entry[4], entry[5], entry[6], entry[7], entry[8], entry[9]
    end

    loadModule("QuestApi.lua")

    local snapshot = QB.QuestApi:BuildLocalSnapshot(77)

    expectEquals(QB.QuestApi.titleFieldOffset, 1, "quest api detects Ascension shifted layout")
    expectEquals(#snapshot.quests, 2, "quest api finds quests with Ascension shifted layout")
    expectEquals(snapshot.quests[1].title, "Call to Arms", "quest api reads correct title with Ascension layout")
    expectEquals(snapshot.quests[1].questId, 301, "quest api reads correct questId with Ascension layout")

    _G.GetQuestLogTitle = originalGetQuestLogTitle
    _G.C_QuestLog = originalRetailQuestLog
    QB.QuestApi.titleFieldOffset = nil
    loadModule("QuestApi.lua")
end

local function testAddonInitializesRetailRuntime()
    resetAddonState()
    QB:OnEvent("ADDON_LOADED", "QuestBuddy")

    expectTrue(QB.initialized, "addon initializes on ADDON_LOADED")
    expectTrue(_G.__registeredPrefixes[QB.Protocol.PREFIX], "addon registers its addon chat prefix")
    expectTrue(QB.frame.events["GROUP_ROSTER_UPDATE"] == true, "addon listens for retail group roster updates")
    expectTrue(QB.Options.category ~= nil, "addon registers a retail settings category")
    expectEquals(_G.__sentMessages[1].distribution, "PARTY", "initial roster sync still broadcasts to the party")
    expectEquals(QB:GetOption("enablePartyBoard"), true, "addon initializes enablePartyBoard option to its default")
end

local function testOptionsInitializeWithoutTemplateTextRegion()
    resetAddonState()

    local originalCreateFrame = _G.CreateFrame
    _G.CreateFrame = function(frameType, name, parent, template)
        local frame = newFrame(frameType, name, parent, template)
        if frameType == "CheckButton" and template == "InterfaceOptionsCheckButtonTemplate" then
            frame.Text = nil
        end
        return frame
    end

    loadModule("Options.lua")
    QB.Options:Initialize()

    expectTrue(QB.Options.panel ~= nil, "options panel initializes when checkbox template omits Text")
    expectTrue(QB.Options.panel.overlay ~= nil, "overlay checkbox is created without template text region")
    expectEquals(QB.Options.panel.overlay.Text.text, "Enable tracker overlay", "options checkbox creates a fallback label region")

    _G.CreateFrame = originalCreateFrame
    loadModule("Options.lua")
end

local function testTocUsesSingleRetailInterfaceValue()
    local toc = readFile("QuestBuddy.toc")
    local interfaceLine = string.match(toc, "([^\r\n]+)")

    expectEquals(interfaceLine, "## Interface: 120001, 110207", "toc declares supported retail interface versions")
    expectTrue(string.find(toc, "## Interface: 120001, 110207", 1, true) ~= nil, "toc uses the comma-separated interface header WoW accepts")
end

local function testBuildQuestRowsRespectsSharedFilterAndSortOrder()
    local localSnapshot = makeSnapshot("Me", 1, {
        makeQuest("id:3", "Gamma", 20, false, "active", {}),
        makeQuest("id:1", "Alpha", 10, true, "active", {}),
        makeQuest("id:2", "Beta", 10, true, "active", {}),
    })
    local peerSnapshot = makeSnapshot("Buddy", 1, {
        makeQuest("id:2", "Beta", 10, true, "active", {}),
        makeQuest("id:4", "Delta", 15, false, "active", {}),
    })

    local allRows = QB.State.BuildQuestRows(localSnapshot, peerSnapshot, false)
    expectEquals(#allRows.shared, 1, "row builder includes shared quests when filter is disabled")
    expectEquals(#allRows.mineOnly, 2, "row builder includes local-only quests when filter is disabled")
    expectEquals(#allRows.buddyOnly, 1, "row builder includes buddy-only quests when filter is disabled")
    expectEquals(allRows.mineOnly[1].title, "Alpha", "row builder sorts watched quests alphabetically at equal level")
    expectEquals(allRows.mineOnly[2].title, "Gamma", "row builder sorts unwatched quests after watched quests")

    local sharedOnlyRows = QB.State.BuildQuestRows(localSnapshot, peerSnapshot, true)
    expectEquals(#sharedOnlyRows.shared, 1, "row builder keeps shared quests when shared-only mode is enabled")
    expectEquals(#sharedOnlyRows.mineOnly, 0, "row builder hides local-only quests in shared-only mode")
    expectEquals(#sharedOnlyRows.buddyOnly, 0, "row builder hides buddy-only quests in shared-only mode")
end

local function testBuildQuestRowsIncludesObjectiveComparisonMetadata()
    local localSnapshot = makeSnapshot("Me", 10, {
        makeQuest("id:shared", "Shared Quest", 10, true, "active", {
            { text = "Apples", current = 2, required = 6, done = false },
            { text = "Dust", current = 4, required = 10, done = false },
        }),
    })
    local peerSnapshot = makeSnapshot("Buddy", 11, {
        makeQuest("id:shared", "Shared Quest", 10, true, "active", {
            { text = "Apples", current = 5, required = 6, done = false },
            { text = "Dust", current = 1, required = 10, done = false },
        }),
    })

    local rows = QB.State.BuildQuestRows(localSnapshot, peerSnapshot, true)
    expectEquals(#rows.shared, 1, "shared row exists for objective comparison metadata")
    expectEquals(#rows.shared[1].objectiveComparison, 2, "shared row includes objective-level comparison metadata")
    expectEquals(rows.shared[1].objectiveComparison[1].my_count, 2, "comparison metadata includes my count")
    expectEquals(rows.shared[1].objectiveComparison[1].buddy_count, 5, "comparison metadata includes buddy count")
    expectEquals(rows.shared[1].objectiveComparison[1].delta, 3, "comparison metadata includes objective delta")
    expectEquals(rows.shared[1].objectiveComparison[1].ahead_side, "buddy", "comparison metadata includes objective leader")
    expectEquals(rows.shared[1].objectiveComparison[2].ahead_side, "me", "comparison metadata marks me when I lead objective progress")
    expectEquals(rows.shared[1].delta, 0, "quest delta aggregates objective-level deltas")
    expectEquals(rows.shared[1].ahead_side, "even", "quest leader is even when aggregate delta is zero")
end

local function testBuildQuestRowsOptionalSharedDeltaSort()
    local localSnapshot = makeSnapshot("Me", 3, {
        makeQuest("id:a", "Quest A", 20, true, "active", {
            { text = "A", current = 3, required = 10, done = false },
        }),
        makeQuest("id:b", "Quest B", 10, true, "active", {
            { text = "B", current = 2, required = 10, done = false },
        }),
    })
    local peerSnapshot = makeSnapshot("Buddy", 4, {
        makeQuest("id:a", "Quest A", 20, true, "active", {
            { text = "A", current = 9, required = 10, done = false },
        }),
        makeQuest("id:b", "Quest B", 10, true, "active", {
            { text = "B", current = 3, required = 10, done = false },
        }),
    })

    local defaultRows = QB.State.BuildQuestRows(localSnapshot, peerSnapshot, true, false)
    expectEquals(defaultRows.shared[1].title, "Quest B", "default shared ordering remains existing watched/level/title ordering")

    local deltaSortedRows = QB.State.BuildQuestRows(localSnapshot, peerSnapshot, true, true)
    expectEquals(deltaSortedRows.shared[1].title, "Quest A", "delta sort prioritizes largest objective delta when enabled")
end

local tests = {
    testProtocolRoundTrip,
    testMalformedMessageRejected,
    testSnapshotSerializeChunkRoundTrip,
    testSignatureIgnoresUpdatedTimestamp,
    testStalePeerHandling,
    testNewerHelloMarksPeerUpdating,
    testStateFreshestLivePeerSelectors,
    testFocusedBuddySelection,
    testTrackerRenderingDecisions,
    testMainWindowRowBuilding,
    testPeerSummaryRowsIncludeSharedAndReadyCounts,
    testPartyJoinLeaveBehavior,
    testSimulatedBuddyUsesLocalQuests,
    testRefreshViewsDoesNotPersistSimulatedFocus,
    testMainWindowSimulationButtonToggles,
    testSimulationRefreshesLocalSnapshotBeforeBuildingPeer,
    testSimulatedEmptyStateExplainsMissingLocalQuests,
    testTooltipShowsSimulatedBuddyQuestProgressForUnitTooltip,
    testTooltipLimitsQuestProgressToMatchedObjective,
    testRefreshLocalSnapshotIgnoresUpdatedOnlyChanges,
    testSendSnapshotUsesWhisperAndBoundedChunks,
    testHelloRequestUsesWhisper,
    testSnapshotRequestHonorsTargetName,
    testRefreshRequestThrottlesRepeatedRequests,
    testAddonMessageIgnoresNonPartyAndSelfMessages,
    testQueueSnapshotBroadcastReschedulesDuringCooldown,
    testSnapshotTransferTimeoutClearsUpdatingState,
    testSnapshotEndRejectsChecksumMismatch,
    testSnapshotEndAppliesValidSnapshot,
    testQuestApiBuildsRetailSnapshot,
    testQuestApiFallsBackWhenRetailQuestLogIsEmpty,
    testQuestApiExpandsCollapsedLegacyHeaders,
    testQuestApiRestoresMultipleCollapsedHeaders,
    testQuestApiDetectsAscensionShiftedLayout,
    testBuildQuestRowsRespectsSharedFilterAndSortOrder,
    testBuildQuestRowsIncludesObjectiveComparisonMetadata,
    testBuildQuestRowsOptionalSharedDeltaSort,
    testAddonInitializesRetailRuntime,
    testOptionsInitializeWithoutTemplateTextRegion,
    testTocUsesSingleRetailInterfaceValue,
}

for _, test in ipairs(tests) do
    test()
end

if failures > 0 then
    io.stderr:write(string.format("%d/%d tests failed\n", failures, total))
    os.exit(1)
end

print(string.format("%d tests passed", total))
