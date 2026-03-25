local addonName, QB = ...

QB = QB or _G.QuestBuddy or {}
_G.QuestBuddy = QB
QB.UI = QB.UI or {}

local UI = QB.UI
local CreateFrame = _G.CreateFrame
local BackdropTemplate = _G.BackdropTemplateMixin and "BackdropTemplate" or nil

UI.frame = UI.frame or nil
UI.rows = UI.rows or {}

local STATUS_COLORS = {
    Live = { r = 0.47, g = 0.82, b = 0.47 },
    Updating = { r = 0.96, g = 0.82, b = 0.36 },
    Stale = { r = 0.95, g = 0.56, b = 0.24 },
    Offline = { r = 0.62, g = 0.62, b = 0.62 },
}

local function applyBackdrop(frame)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.04, 0.05, 0.07, 0.96)
    frame:SetBackdropBorderColor(0.34, 0.37, 0.42, 1)
end

local function formatQuestTitle(row)
    if row.level and row.level > 0 then
        return string.format("[%d] %s", row.level, row.title)
    end
    return row.title
end

local function buildDropdownMenu(_, level)
    local peers = QB.State:GetOrderedPeerNames(true)
    if #peers == 0 then
        local info = UIDropDownMenu_CreateInfo()
        info.text = "No buddies"
        info.checked = false
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)
        return
    end

    for _, name in ipairs(peers) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = name
        info.checked = name == QB.State:GetFocusedBuddy()
        info.func = function()
            QB.State:SetFocusedBuddy(name)
            QB.db.lastFocusedBuddy = name
            QB:RefreshViews("focus-changed")
        end
        UIDropDownMenu_AddButton(info, level)
    end
end

function UI.BuildDisplayRows(localSnapshot, peer, showOnlyShared)
    local buckets = QB.State.BuildQuestRows(localSnapshot, peer and peer.snapshot or nil, showOnlyShared)
    local rows = {}

    local function appendSection(sectionTitle, sectionRows)
        if #sectionRows == 0 then
            return
        end

        table.insert(rows, {
            kind = "header",
            text = sectionTitle,
        })

        for _, row in ipairs(sectionRows) do
            table.insert(rows, {
                kind = "quest",
                title = formatQuestTitle(row),
                myText = row.mine and ("Me: " .. QB.Snapshot:SummarizeQuest(row.mine)) or "Me: Missing",
                buddyText = row.buddy and ("Buddy: " .. QB.Snapshot:SummarizeQuest(row.buddy)) or "Buddy: Missing",
            })
        end
    end

    appendSection("Shared Quests", buckets.shared)
    appendSection("Buddy Only", buckets.buddyOnly)
    appendSection("Mine Only", buckets.mineOnly)

    return rows, buckets
end

function UI:Initialize()
    if self.frame or not CreateFrame then
        return
    end

    local windowState = QB:GetWindowState()

    self.frame = CreateFrame("Frame", "QuestBuddyMainWindow", UIParent, BackdropTemplate)
    self.frame:SetWidth(windowState.width or 420)
    self.frame:SetHeight(windowState.height or 380)
    self.frame:SetPoint(windowState.point or "CENTER", UIParent, windowState.relativePoint or "CENTER", windowState.x or 0, windowState.y or 0)
    self.frame:SetMovable(true)
    self.frame:EnableMouse(true)
    self.frame:RegisterForDrag("LeftButton")
    self.frame:SetClampedToScreen(true)
    self.frame:SetScript("OnDragStart", function(frame)
        if QB:GetOption("lockWindow") then
            return
        end
        frame:StartMoving()
    end)
    self.frame:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        local point, _, relativePoint, xOfs, yOfs = frame:GetPoint(1)
        local window = QB:GetWindowState()
        window.point = point
        window.relativePoint = relativePoint
        window.x = xOfs
        window.y = yOfs
    end)
    applyBackdrop(self.frame)

    self.frame.title = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.frame.title:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 14, -14)
    self.frame.title:SetText("QuestBuddy")

    self.frame.close = CreateFrame("Button", nil, self.frame, "UIPanelCloseButton")
    self.frame.close:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -4, -4)

    self.frame.focusLabel = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.frame.focusLabel:SetPoint("TOPLEFT", self.frame.title, "BOTTOMLEFT", 0, -14)
    self.frame.focusLabel:SetText("Focused buddy")

    self.frame.dropdown = CreateFrame("Frame", "QuestBuddyBuddyDropdown", self.frame, "UIDropDownMenuTemplate")
    self.frame.dropdown:SetPoint("TOPLEFT", self.frame.focusLabel, "BOTTOMLEFT", -16, -2)
    UIDropDownMenu_SetWidth(self.frame.dropdown, 160)

    self.frame.statusText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.frame.statusText:SetPoint("TOPLEFT", self.frame.dropdown, "BOTTOMLEFT", 20, -8)
    self.frame.statusText:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -14, -8)
    self.frame.statusText:SetJustifyH("LEFT")

    self.frame.countsText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    self.frame.countsText:SetPoint("TOPLEFT", self.frame.statusText, "BOTTOMLEFT", 0, -4)
    self.frame.countsText:SetPoint("TOPRIGHT", self.frame.statusText, "TOPRIGHT", 0, -4)
    self.frame.countsText:SetJustifyH("LEFT")

    self.frame.refreshButton = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    self.frame.refreshButton:SetWidth(70)
    self.frame.refreshButton:SetHeight(20)
    self.frame.refreshButton:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -16, -44)
    self.frame.refreshButton:SetText("Refresh")
    self.frame.refreshButton:SetScript("OnClick", function()
        QB:ManualRefresh()
    end)

    self.frame.scroll = CreateFrame("ScrollFrame", "QuestBuddyMainScroll", self.frame, "UIPanelScrollFrameTemplate")
    self.frame.scroll:SetPoint("TOPLEFT", self.frame.countsText, "BOTTOMLEFT", 0, -12)
    self.frame.scroll:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -30, 16)

    self.frame.content = CreateFrame("Frame", nil, self.frame.scroll)
    self.frame.content:SetWidth((windowState.width or 420) - 56)
    self.frame.content:SetHeight(1)
    self.frame.scroll:SetScrollChild(self.frame.content)

    UIDropDownMenu_Initialize(self.frame.dropdown, buildDropdownMenu)

    self.frame:Hide()
end

function UI:AcquireRow(index)
    if self.rows[index] then
        return self.rows[index]
    end

    local row = CreateFrame("Frame", nil, self.frame.content)
    row:SetWidth(self.frame.content:GetWidth())
    row:SetHeight(42)

    row.header = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.header:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.header:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    row.header:SetJustifyH("LEFT")

    row.subA = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.subA:SetPoint("TOPLEFT", row.header, "BOTTOMLEFT", 0, -3)
    row.subA:SetPoint("TOPRIGHT", row.header, "BOTTOMRIGHT", 0, -3)
    row.subA:SetJustifyH("LEFT")

    row.subB = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.subB:SetPoint("TOPLEFT", row.subA, "BOTTOMLEFT", 0, -2)
    row.subB:SetPoint("TOPRIGHT", row.subA, "BOTTOMRIGHT", 0, -2)
    row.subB:SetJustifyH("LEFT")

    self.rows[index] = row
    return row
end

function UI:RenderRows(rows)
    local totalHeight = 0
    local previous = nil

    for index, rowData in ipairs(rows) do
        local row = self:AcquireRow(index)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", previous or self.frame.content, previous and "BOTTOMLEFT" or "TOPLEFT", 0, previous and -8 or 0)
        row:SetWidth(self.frame.content:GetWidth())

        if rowData.kind == "header" then
            row:SetHeight(18)
            row.header:SetText(rowData.text)
            row.subA:SetText("")
            row.subB:SetText("")
        else
            row:SetHeight(44)
            row.header:SetText(rowData.title)
            row.subA:SetText(rowData.myText)
            row.subB:SetText(rowData.buddyText)
        end

        row:Show()
        previous = row
        totalHeight = totalHeight + row:GetHeight() + (index == 1 and 0 or 8)
    end

    for index = #rows + 1, #self.rows do
        self.rows[index]:Hide()
    end

    self.frame.content:SetHeight(math.max(totalHeight, 1))
end

function UI:Refresh(reason)
    if not self.frame then
        return
    end

    local focusedBuddy = QB.State:GetFocusedBuddy()
    local peer = focusedBuddy and QB.State:GetPeer(focusedBuddy) or nil
    local status = QB.State:GetPeerStatus(peer, QB.Compat:GetTime(), QB:GetOption("staleTimeoutSeconds"))
    local rows, buckets = UI.BuildDisplayRows(QB.State:GetLocalSnapshot(), peer, QB:GetOption("showOnlySharedQuests"))
    local statusColor = STATUS_COLORS[status] or STATUS_COLORS.Offline

    UIDropDownMenu_Initialize(self.frame.dropdown, buildDropdownMenu)

    UIDropDownMenu_SetText(self.frame.dropdown, focusedBuddy or "No buddy")

    if focusedBuddy then
        self.frame.statusText:SetText(QB.Compat:Colorize(string.format("%s  %s", focusedBuddy, status), statusColor))
    else
        self.frame.statusText:SetText("No active QuestBuddy peers")
    end

    self.frame.countsText:SetText(string.format(
        "Shared %d   Buddy %d   Mine %d",
        #(buckets.shared or {}),
        #(buckets.buddyOnly or {}),
        #(buckets.mineOnly or {})
    ))

    if #rows == 0 then
        rows = {
            {
                kind = "header",
                text = focusedBuddy and "No quest rows yet" or "Join a party with another QuestBuddy user",
            },
        }
    end

    self:RenderRows(rows)
end

function UI:Toggle()
    if not self.frame then
        return
    end

    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self:Refresh("toggle")
        self.frame:Show()
    end
end
