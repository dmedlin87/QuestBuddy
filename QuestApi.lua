---@diagnostic disable: undefined-global, undefined-field
local addonName, QB = ...

QB = QB or _G.QuestBuddy or {}
_G.QuestBuddy = QB
QB.QuestApi = QB.QuestApi or {}

local QuestApi = QB.QuestApi
local GetNumQuestLogEntries = _G.GetNumQuestLogEntries
local GetQuestLogTitle = _G.GetQuestLogTitle
local GetNumQuestLeaderBoards = _G.GetNumQuestLeaderBoards
local GetQuestLogLeaderBoard = _G.GetQuestLogLeaderBoard
local IsQuestWatched = _G.IsQuestWatched

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

function QuestApi:BuildObjectives(questIndex)
    local objectives = {}
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

    local entries = GetNumQuestLogEntries and GetNumQuestLogEntries() or 0
    for questIndex = 1, entries do
        local title, level, _, isHeader, _, isComplete, _, questId = GetQuestLogTitle(questIndex)
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