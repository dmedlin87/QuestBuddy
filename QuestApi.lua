---@diagnostic disable: undefined-global, undefined-field
local _, QB = ...

QB = QB or _G.QuestBuddy or {}
_G.QuestBuddy = QB
QB.QuestApi = QB.QuestApi or {}

local QuestApi = QB.QuestApi
local C_QuestLog = _G.C_QuestLog
local GetNumQuestLogEntries = _G.GetNumQuestLogEntries
local GetQuestLogTitle = _G.GetQuestLogTitle
local GetNumQuestLeaderBoards = _G.GetNumQuestLeaderBoards
local GetQuestLogLeaderBoard = _G.GetQuestLogLeaderBoard
local IsQuestWatched = _G.IsQuestWatched
local ExpandQuestHeader = _G.ExpandQuestHeader
local CollapseQuestHeader = _G.CollapseQuestHeader
local SelectQuestLogEntry = _G.SelectQuestLogEntry
local GetQuestLogSelection = _G.GetQuestLogSelection

QuestApi.questLogMutationDepth = QuestApi.questLogMutationDepth or 0
QuestApi.suppressQuestLogUpdatesUntil = QuestApi.suppressQuestLogUpdatesUntil or 0
QuestApi.titleFieldOffset = QuestApi.titleFieldOffset or nil

--- Detect whether GetQuestLogTitle returns an extra field before isHeader.
--- Standard WotLK: title, level, suggestedGroup, isHeader(4), isCollapsed, isComplete, frequency, questID
--- Ascension WoW:  title, level, suggestedGroup, extra(4), isHeader(5), isCollapsed, isComplete, frequency, questID
local function detectTitleFieldOffset()
    if QuestApi.titleFieldOffset ~= nil then
        return
    end

    if not GetQuestLogTitle or not GetNumQuestLogEntries then
        QuestApi.titleFieldOffset = 0
        return
    end

    local entries = GetNumQuestLogEntries()
    for i = 1, entries or 0 do
        local _, _, _, r4, r5 = GetQuestLogTitle(i)
        if r4 == 1 or r4 == true then
            QuestApi.titleFieldOffset = 0
            return
        end
        if r5 == 1 or r5 == true then
            QuestApi.titleFieldOffset = 1
            return
        end
    end

    QuestApi.titleFieldOffset = 0
end

--- Parse GetQuestLogTitle return values, handling Ascension's shifted layout.
local function parseQuestLogTitle(questIndex)
    if not GetQuestLogTitle then
        return nil, nil, nil, nil, nil, nil
    end

    detectTitleFieldOffset()

    local title, level, _, r4, r5, r6, r7, r8, r9 = GetQuestLogTitle(questIndex)
    if QuestApi.titleFieldOffset == 1 then
        -- Ascension: extra field at r4, real fields shifted by 1
        return title, level, (r5 == 1 or r5 == true), (r6 == 1 or r6 == true), r7, r9
    end

    -- Standard WotLK layout
    return title, level, (r4 == 1 or r4 == true), (r5 == 1 or r5 == true), r6, r8
end

function QuestApi:BeginQuestLogMutation()
    self.questLogMutationDepth = (self.questLogMutationDepth or 0) + 1
end

function QuestApi:EndQuestLogMutation(now)
    self.questLogMutationDepth = math.max((self.questLogMutationDepth or 0) - 1, 0)
    self.suppressQuestLogUpdatesUntil = math.max(self.suppressQuestLogUpdatesUntil or 0, (now or 0) + 0.1)
end

function QuestApi:ShouldIgnoreQuestLogUpdate(now)
    if (self.questLogMutationDepth or 0) > 0 then
        return true
    end

    return (now or 0) <= (self.suppressQuestLogUpdatesUntil or 0)
end

local function getQuestLogCounts()
    local retailEntries = nil

    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
        retailEntries = C_QuestLog.GetNumQuestLogEntries()
        if retailEntries and retailEntries > 0 then
            return retailEntries, retailEntries
        end
    end

    if GetNumQuestLogEntries then
        local legacyEntries, legacyQuestCount = GetNumQuestLogEntries()
        legacyEntries = legacyEntries or 0
        legacyQuestCount = legacyQuestCount or legacyEntries

        if legacyEntries > 0 or legacyQuestCount > 0 then
            return legacyEntries, legacyQuestCount
        end
    end

    return retailEntries or 0, retailEntries or 0
end

local function captureCollapsedHeaders(entryCount)
    local collapsedTitles = {}

    if not GetQuestLogTitle then
        return collapsedTitles
    end

    for questIndex = 1, entryCount do
        local title, _, isHeader, isCollapsed = parseQuestLogTitle(questIndex)
        if isHeader and isCollapsed and title then
            table.insert(collapsedTitles, title)
        end
    end

    return collapsedTitles
end

local function restoreCollapsedHeaders(collapsedTitles)
    if not CollapseQuestHeader or not GetQuestLogTitle then
        return
    end

    if #collapsedTitles == 0 then
        return
    end

    local needsCollapse = {}
    for _, title in ipairs(collapsedTitles) do
        needsCollapse[title] = true
    end

    local entryCount = getQuestLogCounts()
    local indicesToCollapse = {}
    for questIndex = 1, entryCount do
        local title, _, isHeader = parseQuestLogTitle(questIndex)
        if isHeader and title and needsCollapse[title] then
            table.insert(indicesToCollapse, questIndex)
        end
    end

    for i = #indicesToCollapse, 1, -1 do
        CollapseQuestHeader(indicesToCollapse[i])
    end
end

local function withExpandedLegacyHeaders(callback)
    if not GetNumQuestLogEntries or not GetQuestLogTitle or not ExpandQuestHeader then
        return callback()
    end

    local entryCount, questCount = getQuestLogCounts()
    if questCount <= 0 or entryCount <= 0 then
        return callback()
    end

    local collapsedHeaders = captureCollapsedHeaders(entryCount)
    if #collapsedHeaders == 0 then
        return callback()
    end

    QuestApi:BeginQuestLogMutation()
    ExpandQuestHeader(0)

    local ok, result = pcall(callback)

    restoreCollapsedHeaders(collapsedHeaders)
    QuestApi:EndQuestLogMutation(QB.Compat and QB.Compat:GetTime() or 0)

    if not ok then
        error(result)
    end

    return result
end

local function normalizeTitle(title)
    title = string.lower(title or "")
    title = string.gsub(title, "^%s+", "")
    title = string.gsub(title, "%s+$", "")
    title = string.gsub(title, "%s+", " ")
    return title
end

function QuestApi:MakeQuestKey(title, level, questId)
    if questId and tonumber(questId) and tonumber(questId) > 0 then
        return "id:" .. tostring(questId)
    end

    return string.format("title:%s|%s", normalizeTitle(title), tostring(level or 0))
end

function QuestApi:ParseObjectiveProgress(text, isComplete)
    local current, required = string.match(text or "", "(%d+)%s*/%s*(%d+)")
    if current and required then
        return tonumber(current), tonumber(required), isComplete and true or false
    end

    if isComplete then
        return 1, 1, true
    end

    return nil, nil, false
end

function QuestApi:NormalizeStatus(isComplete)
    if isComplete == 1 or isComplete == true then
        return "ready"
    end
    if isComplete == -1 then
        return "failed"
    end
    return "active"
end

local function getQuestInfo(questIndex)
    if C_QuestLog and C_QuestLog.GetInfo then
        local info = C_QuestLog.GetInfo(questIndex)
        if info and info.title then
            return info.title, info.level, info.isHeader, info.isComplete, info.questID
        end
    end

    local title, level, isHeader, _, isComplete, questId = parseQuestLogTitle(questIndex)
    return title, level, isHeader, isComplete, questId
end

function QuestApi:BuildObjectives(questIndex)
    local objectives = {}
    local title, _, isHeader, _, questId = getQuestInfo(questIndex)

    if title and not isHeader and questId and questId > 0 and C_QuestLog and C_QuestLog.GetQuestObjectives then
        local questObjectives = C_QuestLog.GetQuestObjectives(questId) or {}
        for _, objective in ipairs(questObjectives) do
            local text = objective.text or objective.description or ""
            ---@type number|nil
            local current = objective.numFulfilled
            ---@type number|nil
            local required = objective.numRequired
            local done = objective.finished and true or false

            if current == nil or required == nil then
                local parsedCurrent, parsedRequired, parsedDone = self:ParseObjectiveProgress(text, done)
                current = parsedCurrent
                required = parsedRequired
                done = parsedDone
            end

            table.insert(objectives, {
                text = text,
                current = current,
                required = required,
                done = done,
                objectiveType = objective.type,
            })
        end

        if #objectives > 0 then
            return objectives
        end
    end

    if SelectQuestLogEntry then
        SelectQuestLogEntry(questIndex)
    end

    local objectiveCount = GetNumQuestLeaderBoards and GetNumQuestLeaderBoards(questIndex) or 0

    for objectiveIndex = 1, objectiveCount do
        local text, objectiveType, isComplete = GetQuestLogLeaderBoard(objectiveIndex, questIndex)
        if text then
            local current, required, done = self:ParseObjectiveProgress(text, isComplete)
            table.insert(objectives, {
                text = text,
                current = current,
                required = required,
                done = done,
                objectiveType = objectiveType,
            })
        end
    end

    return objectives
end

function QuestApi:BuildLocalSnapshot(now)
    local snapshot = {
        player = QB.PartyApi and QB.PartyApi:GetPlayerName() or "Unknown",
        createdAt = now or 0,
        revision = 0,
        quests = {},
    }

    local originalSelection = GetQuestLogSelection and GetQuestLogSelection() or nil

    withExpandedLegacyHeaders(function()
        local entries = getQuestLogCounts()

        for questIndex = 1, entries do
            local title, level, isHeader, isComplete, questId = getQuestInfo(questIndex)
            if title and not isHeader then
                local questRecord = {
                    questKey = self:MakeQuestKey(title, level, questId),
                    questId = tonumber(questId) or 0,
                    title = title,
                    level = tonumber(level) or 0,
                    status = self:NormalizeStatus(isComplete),
                    watched = IsQuestWatched and IsQuestWatched(questIndex) and true or false,
                    updated = now or 0,
                    objectives = self:BuildObjectives(questIndex),
                }
                table.insert(snapshot.quests, questRecord)
            end
        end
    end)

    if SelectQuestLogEntry and originalSelection then
        SelectQuestLogEntry(originalSelection)
    end

    table.sort(snapshot.quests, function(left, right)
        if left.watched ~= right.watched then
            return left.watched
        end
        if left.level ~= right.level then
            return left.level < right.level
        end
        return string.lower(left.title or "") < string.lower(right.title or "")
    end)

    return snapshot
end
