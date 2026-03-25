---@diagnostic disable: undefined-global, undefined-field
local addonName, QB = ...

QB = QB or _G.QuestBuddy or {}
_G.QuestBuddy = QB
QB.Options = QB.Options or {}

local Options = QB.Options
local CreateFrame = _G.CreateFrame
local InterfaceOptionsFramePanelContainer = _G.InterfaceOptionsFramePanelContainer
local InterfaceOptions_AddCategory = _G.InterfaceOptions_AddCategory
local InterfaceOptionsFrame_OpenToCategory = _G.InterfaceOptionsFrame_OpenToCategory

Options.panel = Options.panel or nil

local function createCheckbox(parent, label, description, x, y, getter, setter)
    local checkbox = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    checkbox.Text:SetText(label)
    checkbox.tooltipText = description
    checkbox:SetScript("OnClick", function(self)
        setter(self:GetChecked() and true or false)
    end)
    checkbox.Refresh = function()
        checkbox:SetChecked(getter())
    end
    return checkbox
end

function Options:Initialize()
    if self.panel or not CreateFrame then
        return
    end

    self.panel = CreateFrame("Frame", "QuestBuddyOptionsPanel", InterfaceOptionsFramePanelContainer)
    self.panel.name = "QuestBuddy"

    self.panel.title = self.panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.panel.title:SetPoint("TOPLEFT", self.panel, "TOPLEFT", 16, -16)
    self.panel.title:SetText("QuestBuddy")

    self.panel.subtitle = self.panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.panel.subtitle:SetPoint("TOPLEFT", self.panel.title, "BOTTOMLEFT", 0, -8)
    self.panel.subtitle:SetWidth(560)
    self.panel.subtitle:SetJustifyH("LEFT")
    self.panel.subtitle:SetText("Small party quest progress visibility with a focused buddy tracker.")

    self.panel.overlay = createCheckbox(
        self.panel,
        "Enable tracker overlay",
        "Show focused buddy quest progress beneath the quest watch area.",
        16,
        -70,
        function() return QB:GetOption("enableTrackerOverlay") end,
        function(value) QB:SetOption("enableTrackerOverlay", value); QB:RefreshViews("options") end
    )

    self.panel.sharedOnly = createCheckbox(
        self.panel,
        "Show only shared quests in window",
        "Hide buddy-only and mine-only sections in the compact window.",
        16,
        -100,
        function() return QB:GetOption("showOnlySharedQuests") end,
        function(value) QB:SetOption("showOnlySharedQuests", value); QB:RefreshViews("options") end
    )

    self.panel.autoFocus = createCheckbox(
        self.panel,
        "Auto-focus a single buddy",
        "When exactly one QuestBuddy peer is in party, focus them automatically.",
        16,
        -130,
        function() return QB:GetOption("autoFocusSingleBuddy") end,
        function(value) QB:SetOption("autoFocusSingleBuddy", value); QB.State:ReevaluateFocus(QB.db); QB:RefreshViews("options") end
    )

    self.panel.lockWindow = createCheckbox(
        self.panel,
        "Lock main window",
        "Prevent dragging the main QuestBuddy window.",
        16,
        -160,
        function() return QB:GetOption("lockWindow") end,
        function(value) QB:SetOption("lockWindow", value) end
    )

    self.panel.timeoutLabel = self.panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.panel.timeoutLabel:SetPoint("TOPLEFT", self.panel, "TOPLEFT", 16, -210)
    self.panel.timeoutLabel:SetText("Stale timeout (seconds)")

    self.panel.timeoutBox = CreateFrame("EditBox", nil, self.panel, "InputBoxTemplate")
    self.panel.timeoutBox:SetWidth(60)
    self.panel.timeoutBox:SetHeight(20)
    self.panel.timeoutBox:SetPoint("TOPLEFT", self.panel.timeoutLabel, "BOTTOMLEFT", 0, -6)
    self.panel.timeoutBox:SetAutoFocus(false)
    self.panel.timeoutBox:SetNumeric(true)
    self.panel.timeoutBox:SetScript("OnEnterPressed", function(editBox)
        local value = tonumber(editBox:GetText()) or 90
        value = QB.Compat:Clamp(value, 15, 600)
        QB:SetOption("staleTimeoutSeconds", value)
        editBox:SetText(tostring(value))
        QB:RefreshViews("options")
        editBox:ClearFocus()
    end)
    self.panel.timeoutBox:SetScript("OnEscapePressed", function(editBox)
        editBox:ClearFocus()
    end)

    self.panel:SetScript("OnShow", function(panel)
        panel.overlay:Refresh()
        panel.sharedOnly:Refresh()
        panel.autoFocus:Refresh()
        panel.lockWindow:Refresh()
        panel.timeoutBox:SetText(tostring(QB:GetOption("staleTimeoutSeconds") or 90))
    end)

    InterfaceOptions_AddCategory(self.panel)
end

function Options:Open()
    if not self.panel then
        return
    end
    InterfaceOptionsFrame_OpenToCategory(self.panel)
    InterfaceOptionsFrame_OpenToCategory(self.panel)
end