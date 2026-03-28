---@diagnostic disable: undefined-global, undefined-field
local _, QB = ...

QB = QB or _G.QuestBuddy or {}
_G.QuestBuddy = QB
QB.Tracker = QB.Tracker or {}

local Tracker = QB.Tracker
local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent
local BackdropTemplate = _G.BackdropTemplateMixin and "BackdropTemplate" or nil

Tracker.frame = Tracker.frame or nil
Tracker.rows = Tracker.rows or {}

local STATUS_COLORS = {
    Live = { r = 0.47, g = 0.82, b = 0.47 },
    Updating = { r = 0.96, g = 0.82, b = 0.36 },
    Stale = { r = 0.95, g = 0.56, b = 0.24 },
    Offline = { r = 0.62, g = 0.62, b = 0.62 },
}
local TOOLTIP_HEADER_PREFIX = "QuestBuddy: "

local function getStatusColor(status)
    return STATUS_COLORS[status] or STATUS_COLORS.Offline
end

local function normalizeTooltipText(text)
    text = tostring(text or "")
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    text = string.gsub(text, "^[-*]+%s*", "")
    text = string.gsub(text, "%s+", " ")
    return string.lower(text)
end

local function getTooltipLineCount(tooltip)
    if tooltip and tooltip.NumLines then
        return tooltip:NumLines() or 0
    end

    return tooltip and tooltip.leftLines and #tooltip.leftLines or 0
end

local function getTooltipLineText(tooltip, index)
    if not tooltip or not index then
        return nil
    end

    if tooltip.leftLines and tooltip.leftLines[index] then
        return tooltip.leftLines[index]
    end

    local tooltipName = tooltip.GetName and tooltip:GetName()
    if not tooltipName then
        return nil
    end

    local line = _G[tooltipName .. "TextLeft" .. index]
    return line and line.GetText and line:GetText() or nil
end

local function tooltipContainsLine(tooltip, text)
    local normalizedTarget = normalizeTooltipText(text)

    for index = 1, getTooltipLineCount(tooltip) do
        if normalizeTooltipText(getTooltipLineText(tooltip, index)) == normalizedTarget then
            return true
        end
    end

    return false
end

local function collectTooltipQuestMatches(localSnapshot, tooltip)
    local normalizedLines = {}
    local matches = {}

    for index = 1, getTooltipLineCount(tooltip) do
        local normalizedText = normalizeTooltipText(getTooltipLineText(tooltip, index))
        if normalizedText ~= "" then
            normalizedLines[normalizedText] = true
        end
    end

    for _, quest in ipairs((localSnapshot and localSnapshot.quests) or {}) do
        local match = {
            quest = quest,
            objectiveIndices = {},
            matchedByTitle = normalizedLines[normalizeTooltipText(quest.title)] and true or false,
        }

        for objectiveIndex, objective in ipairs(quest.objectives or {}) do
            if objective.text and objective.text ~= "" and normalizedLines[normalizeTooltipText(objective.text)] then
                table.insert(match.objectiveIndices, objectiveIndex)
            end
        end

        if match.matchedByTitle or #match.objectiveIndices > 0 then
            table.insert(matches, match)
        end
    end

    return matches
end

local function trimText(text)
    text = tostring(text or "")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

local function stripObjectiveProgress(text)
    text = trimText(text)
    text = string.gsub(text, "%s*%(%s*%d+%s*/%s*%d+%s*%)%s*$", "")
    text = string.gsub(text, "%s*[:%-]?%s*%d+%s*/%s*%d+%s*$", "")
    return trimText(text)
end

local function summarizeObjective(localObjective, buddyObjective)
    local labelSource = (localObjective and localObjective.text) or (buddyObjective and buddyObjective.text) or ""
    local label = stripObjectiveProgress(labelSource)

    if buddyObjective and buddyObjective.current ~= nil and buddyObjective.required ~= nil then
        local progress = string.format("%d/%d", buddyObjective.current, buddyObjective.required)
        if label ~= "" then
            return string.format("%s: %s", label, progress)
        end
        return progress
    end

    if buddyObjective and buddyObjective.done then
        if label ~= "" then
            return string.format("%s: Done", label)
        end
        return "Done"
    end

    if buddyObjective and buddyObjective.text and buddyObjective.text ~= "" then
        return buddyObjective.text
    end

    if localObjective and localObjective.text and localObjective.text ~= "" then
        return localObjective.text
    end

    return "In progress"
end

local function applyBackdrop(frame)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.03, 0.03, 0.05, 0.9)
    frame:SetBackdropBorderColor(0.3, 0.33, 0.38, 1)
end

function Tracker.BuildRows(localSnapshot, peer, status)
    local rows = {}
    local peerSnapshot = peer and peer.snapshot or nil
    local peerMap = QB.Snapshot:IndexByKey(peerSnapshot)

    for _, quest in ipairs((localSnapshot and localSnapshot.quests) or {}) do
        if quest.watched then
            local buddyQuest = peerMap[quest.questKey]
            local buddyText

            if status == "Stale" then
                buddyText = "Stale"
            elseif status == "Updating" then
                buddyText = "Updating..."
            elseif status == "Offline" then
                buddyText = "Offline"
            elseif buddyQuest then
                buddyText = QB.Snapshot:SummarizeQuest(buddyQuest)
            else
                buddyText = "Buddy missing"
            end

            table.insert(rows, {
                title = quest.title,
                buddyText = buddyText,
                hasBuddyQuest = buddyQuest ~= nil,
            })
        end
    end

    return rows
end

function Tracker.BuildTooltipLines(localSnapshot, peer, status, tooltip)
    local matches = collectTooltipQuestMatches(localSnapshot, tooltip)
    local peerMap = QB.Snapshot:IndexByKey(peer and peer.snapshot or nil)
    local lines = {}

    for _, match in ipairs(matches) do
        local quest = match.quest
        local buddyQuest = peerMap[quest.questKey]
        local buddyText

        if status == "Stale" then
            buddyText = "Stale"
        elseif status == "Updating" then
            buddyText = "Updating..."
        elseif status == "Offline" then
            buddyText = "Offline"
        elseif not buddyQuest then
            buddyText = "Buddy missing"
        elseif #match.objectiveIndices > 0 then
            for _, objectiveIndex in ipairs(match.objectiveIndices) do
                local objectiveText = summarizeObjective(
                    quest.objectives and quest.objectives[objectiveIndex] or nil,
                    buddyQuest.objectives and buddyQuest.objectives[objectiveIndex] or nil
                )
                table.insert(lines, string.format("%s: %s", quest.title, objectiveText))
            end
            buddyText = nil
        else
            buddyText = QB.Snapshot:SummarizeQuest(buddyQuest)
        end

        if buddyText then
            table.insert(lines, string.format("%s: %s", quest.title, buddyText))
        end
    end

    return lines
end

function Tracker:AppendTooltipProgress(tooltip)
    if not tooltip or not tooltip.AddLine then
        return
    end

    local focusedBuddy = QB.State:GetFocusedBuddy()
    if not focusedBuddy then
        return
    end

    local localSnapshot = QB.State:GetLocalSnapshot()
    local peer = QB.State:GetPeer(focusedBuddy)
    local status = QB.State:GetPeerStatus(peer, QB.Compat:GetTime(), QB:GetOption("staleTimeoutSeconds"))
    local headerText = TOOLTIP_HEADER_PREFIX .. focusedBuddy

    if not localSnapshot or tooltipContainsLine(tooltip, headerText) then
        return
    end

    local lines = Tracker.BuildTooltipLines(localSnapshot, peer, status, tooltip)
    if #lines == 0 then
        return
    end

    local statusColor = getStatusColor(status)
    tooltip:AddLine(" ")
    tooltip:AddLine(headerText, statusColor.r, statusColor.g, statusColor.b)

    for _, line in ipairs(lines) do
        tooltip:AddLine(line, 0.82, 0.82, 0.82, true)
    end

    if tooltip.Show then
        tooltip:Show()
    end
end

function Tracker:InitializeTooltip()
    local tooltip = _G.GameTooltip
    if not tooltip or tooltip.questBuddyHooked or not tooltip.HookScript then
        return
    end

    tooltip:HookScript("OnTooltipSetUnit", function(frame)
        Tracker:AppendTooltipProgress(frame)
    end)
    tooltip.questBuddyHooked = true
end

function Tracker:Initialize()
    self:InitializeTooltip()

    if self.frame or not CreateFrame then
        return
    end

    self.frame = CreateFrame("Frame", "QuestBuddyTrackerOverlay", UIParent, BackdropTemplate)
    self.frame:SetWidth(280)
    self.frame:SetHeight(24)
    applyBackdrop(self.frame)

    local watchFrame = _G.WatchFrame
    if watchFrame then
        self.frame:SetPoint("TOPLEFT", watchFrame, "BOTTOMLEFT", 0, -8)
    else
        self.frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -60, -220)
    end

    self.frame.header = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.frame.header:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, -8)
    self.frame.header:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -10, -8)
    self.frame.header:SetJustifyH("LEFT")

    self.frame:Hide()
end

function Tracker:AcquireRow(index)
    if self.rows[index] then
        return self.rows[index]
    end

    local row = CreateFrame("Frame", nil, self.frame)
    row:SetWidth(260)
    row:SetHeight(28)

    row.title = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.title:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    row.title:SetJustifyH("LEFT")

    row.detail = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.detail:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -2)
    row.detail:SetPoint("TOPRIGHT", row.title, "BOTTOMRIGHT", 0, -2)
    row.detail:SetJustifyH("LEFT")

    self.rows[index] = row
    return row
end

function Tracker:Refresh()
    if not self.frame then
        return
    end

    if not QB:GetOption("enableTrackerOverlay") then
        self.frame:Hide()
        return
    end

    local focusedBuddy = QB.State:GetFocusedBuddy()
    local localSnapshot = QB.State:GetLocalSnapshot()
    local peer = focusedBuddy and QB.State:GetPeer(focusedBuddy) or nil
    local status = QB.State:GetPeerStatus(peer, QB.Compat:GetTime(), QB:GetOption("staleTimeoutSeconds"))
    local rows = Tracker.BuildRows(localSnapshot, peer, status)

    if not focusedBuddy or #rows == 0 then
        self.frame:Hide()
        return
    end

    local statusColor = getStatusColor(status)
    self.frame.header:SetText(QB.Compat:Colorize(string.format("%s  %s", focusedBuddy, status), statusColor))

    local previousRow = nil
    for index, rowData in ipairs(rows) do
        local row = self:AcquireRow(index)
        row:ClearAllPoints()
        if previousRow then
            row:SetPoint("TOPLEFT", previousRow, "BOTTOMLEFT", 0, -10)
        else
            row:SetPoint("TOPLEFT", self.frame.header, "BOTTOMLEFT", 0, -6)
        end
        row.title:SetText(rowData.title)
        row.detail:SetText(rowData.buddyText)
        row:Show()
        previousRow = row
    end

    for index = #rows + 1, #self.rows do
        self.rows[index]:Hide()
    end

    self.frame:SetHeight(28 + (#rows * 34))
    self.frame:Show()
end
