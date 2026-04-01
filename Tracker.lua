---@diagnostic disable: undefined-global, undefined-field
local _, QB = ...

QB = QB or _G.QuestBuddy or {}
_G.QuestBuddy = QB
QB.Tracker = QB.Tracker or {}

local Tracker = QB.Tracker
local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent
local BackdropTemplate = _G.BackdropTemplateMixin and "BackdropTemplate" or nil
local math = math

Tracker.frame = Tracker.frame or nil
Tracker.rows = Tracker.rows or {}

local TOOLTIP_HEADER_PREFIX = "QuestBuddy: "
local TRACKER_REASON_LABELS = {
    stale = "Stale",
    updating = "Updating",
    offline = "Offline",
    not_on_quest = "Buddy missing",
}
local TRACKER_FRAME_WIDTH_PADDING = 20
local TRACKER_ROW_SPACING = 10
local TRACKER_DETAIL_GAP = 2
local TRACKER_ROW_BOTTOM_PADDING = 2
local TRACKER_FALLBACK_LINE_HEIGHT = 12

local function getStatusColor(status)
    return QB.State:GetStatusColor(status)
end

local function getTrackerReasonLabel(reason)
    return TRACKER_REASON_LABELS[reason] or TRACKER_REASON_LABELS.not_on_quest
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

local function getOverlaySize(state)
    local scale = tonumber(state and state.scale) or 1
    local fixedWidth = tonumber(state and state.width)
    local fixedHeight = tonumber(state and state.height)

    if fixedWidth and fixedWidth > 0 and fixedHeight and fixedHeight > 0 then
        return fixedWidth, fixedHeight, scale
    end

    return 280 * scale, 24 * scale, scale
end

local function getRowWidth(frame)
    local width = frame and frame.GetWidth and frame:GetWidth() or 280
    return math.max(120, width - TRACKER_FRAME_WIDTH_PADDING)
end

local function estimateWrappedLineCount(text, width)
    local charsPerLine = math.max(1, math.floor((tonumber(width) or 0) / 7))
    local lineCount = 0

    text = tostring(text or "")
    if text == "" then
        return 1
    end

    for rawLine in string.gmatch(text .. "\n", "([^\n]*)\n") do
        if rawLine == "" then
            lineCount = lineCount + 1
        else
            lineCount = lineCount + math.max(1, math.ceil(string.len(rawLine) / charsPerLine))
        end
    end

    return math.max(1, lineCount)
end

local function measureTextHeight(fontString, text, width)
    if fontString and fontString.SetWidth then
        fontString:SetWidth(width)
    end
    if fontString and fontString.SetText then
        fontString:SetText(text or "")
    end

    local stringHeight = fontString and fontString.GetStringHeight and fontString:GetStringHeight()
    if stringHeight and stringHeight > 0 then
        return stringHeight
    end

    return estimateWrappedLineCount(text, width) * TRACKER_FALLBACK_LINE_HEIGHT
end

local function configureRowText(row, width)
    if row.title.SetWidth then
        row.title:SetWidth(width)
    end
    if row.detail.SetWidth then
        row.detail:SetWidth(width)
    end
    if row.title.SetWordWrap then
        row.title:SetWordWrap(true)
    end
    if row.detail.SetWordWrap then
        row.detail:SetWordWrap(true)
    end
end

function Tracker:ApplyOverlayState()
    if not self.frame then
        return
    end

    local state = QB:GetTrackerOverlayState() or {}
    local width, height = getOverlaySize(state)
    self.frame:ClearAllPoints()
    self.frame:SetPoint(
        state.point or "TOPRIGHT",
        UIParent,
        state.relativePoint or "TOPRIGHT",
        tonumber(state.x) or -60,
        tonumber(state.y) or -220
    )
    self.frame:SetWidth(width)
    self.frame:SetHeight(height)
end

function Tracker:SaveOverlayAnchor()
    if not self.frame then
        return
    end

    local point, _, relativePoint, xOfs, yOfs = self.frame:GetPoint(1)
    QB:SetTrackerOverlayAnchor(point, relativePoint, xOfs, yOfs)
end

function Tracker.BuildRows(localSnapshot, peer, status)
    local rows = {}
    local peerSnapshot = peer and peer.snapshot or nil
    local peerMap = QB.Snapshot:IndexByKey(peerSnapshot)
    local watchedCount = 0

    for _, quest in ipairs((localSnapshot and localSnapshot.quests) or {}) do
        if quest.watched then
            watchedCount = watchedCount + 1
            local buddyQuest = peerMap[quest.questKey]
            local buddyText

            if status == "Stale" then
                buddyText = getTrackerReasonLabel("stale")
            elseif status == "Updating" then
                buddyText = getTrackerReasonLabel("updating")
            elseif status == "Offline" then
                buddyText = getTrackerReasonLabel("offline")
            elseif buddyQuest then
                buddyText = QB.Snapshot:SummarizeQuest(buddyQuest)
            else
                buddyText = getTrackerReasonLabel("not_on_quest")
            end

            table.insert(rows, {
                title = quest.title,
                buddyText = buddyText,
                hasBuddyQuest = buddyQuest ~= nil,
            })
        end
    end

    if watchedCount == 0 and localSnapshot then
        table.insert(rows, {
            title = "No tracked quests",
            buddyText = getTrackerReasonLabel("not_on_quest"),
            hasBuddyQuest = false,
        })
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
            buddyText = QB.State:GetReasonMessage("stale")
        elseif status == "Updating" then
            buddyText = QB.State:GetReasonMessage("updating")
        elseif status == "Offline" then
            buddyText = QB.State:GetReasonMessage("offline")
        elseif not buddyQuest then
            buddyText = QB.State:GetReasonMessage("not_on_quest")
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

    if #lines == 0 then
        return lines, "not_on_quest"
    end

    return lines, nil
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

    local lines, noProgressReason = Tracker.BuildTooltipLines(localSnapshot, peer, status, tooltip)

    local statusColor = getStatusColor(status)
    tooltip:AddLine(" ")
    tooltip:AddLine(headerText, statusColor.r, statusColor.g, statusColor.b)

    if #lines == 0 then
        tooltip:AddLine(QB.State:GetReasonMessage(noProgressReason or "not_on_quest"), 0.82, 0.82, 0.82, true)
    else
        for _, line in ipairs(lines) do
            tooltip:AddLine(line, 0.82, 0.82, 0.82, true)
        end
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
    self.frame:SetMovable(true)
    self.frame:SetClampedToScreen(true)
    self.frame:EnableMouse(true)
    self.frame:RegisterForDrag("LeftButton")
    self.frame:EnableMouseWheel(true)
    self.frame:SetScript("OnDragStart", function(frame)
        if not QB:GetOption("unlockTrackerOverlay") then
            return
        end
        frame:StartMoving()
    end)
    self.frame:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        self:SaveOverlayAnchor()
    end)
    self.frame:SetScript("OnMouseWheel", function(_, delta)
        if not QB:GetOption("unlockTrackerOverlay") then
            return
        end

        local state = QB:GetTrackerOverlayState()
        local nextScale = (tonumber(state.scale) or 1) + ((delta > 0 and 1 or -1) * 0.05)
        QB:SetTrackerOverlayScale(nextScale)
        self:ApplyOverlayState()
        self:Refresh("overlay-scale-wheel")
    end)
    applyBackdrop(self.frame)
    self:ApplyOverlayState()

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
    row:SetWidth(getRowWidth(self.frame))
    row:SetHeight(28)

    row.title = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.title:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    row.title:SetJustifyH("LEFT")

    row.detail = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.detail:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -2)
    row.detail:SetPoint("TOPRIGHT", row.title, "BOTTOMRIGHT", 0, -2)
    row.detail:SetJustifyH("LEFT")
    configureRowText(row, row:GetWidth())

    self.rows[index] = row
    return row
end

function Tracker:Refresh(_)
    if not self.frame then
        return
    end

    if not QB:GetOption("enableTrackerOverlay") then
        self.frame:Hide()
        return
    end

    self:ApplyOverlayState()

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
    self.frame.header:SetText(QB.Compat:Colorize(string.format("%s  %s", focusedBuddy, QB.State:GetStatusLabel(status)), statusColor))

    local rowWidth = getRowWidth(self.frame)
    local totalRowsHeight = 0
    local previousRow = nil
    for index, rowData in ipairs(rows) do
        local row = self:AcquireRow(index)
        row:ClearAllPoints()
        if previousRow then
            row:SetPoint("TOPLEFT", previousRow, "BOTTOMLEFT", 0, -TRACKER_ROW_SPACING)
        else
            row:SetPoint("TOPLEFT", self.frame.header, "BOTTOMLEFT", 0, -6)
        end
        row:SetWidth(rowWidth)
        configureRowText(row, rowWidth)
        local titleHeight = measureTextHeight(row.title, rowData.title, rowWidth)
        local detailHeight = measureTextHeight(row.detail, rowData.buddyText, rowWidth)
        row:SetHeight(titleHeight + TRACKER_DETAIL_GAP + detailHeight + TRACKER_ROW_BOTTOM_PADDING)
        row:Show()
        previousRow = row
        totalRowsHeight = totalRowsHeight + row:GetHeight() + (index > 1 and TRACKER_ROW_SPACING or 0)
    end

    for index = #rows + 1, #self.rows do
        self.rows[index]:Hide()
    end

    local state = QB:GetTrackerOverlayState() or {}
    local _, minHeight = getOverlaySize(state)
    self.frame:SetHeight(math.max(minHeight, 28 + totalRowsHeight))
    self.frame:Show()
end
