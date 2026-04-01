---@diagnostic disable: undefined-global, undefined-field
local _, QB = ...

QB = QB or _G.QuestBuddy or {}
_G.QuestBuddy = QB
QB.Options = QB.Options or {}

local Options = QB.Options
local CreateFrame = _G.CreateFrame
local Settings = _G.Settings
local InterfaceOptionsFramePanelContainer = _G.InterfaceOptionsFramePanelContainer
local InterfaceOptions_AddCategory = _G.InterfaceOptions_AddCategory
local InterfaceOptionsFrame_OpenToCategory = _G.InterfaceOptionsFrame_OpenToCategory
local math = math

Options.panel = Options.panel or nil

local function getCheckboxLabelRegion(checkbox)
    if checkbox.Text then
        return checkbox.Text
    end

    local checkboxName = checkbox.GetName and checkbox:GetName() or checkbox.name
    if checkboxName and _G[checkboxName .. "Text"] then
        checkbox.Text = _G[checkboxName .. "Text"]
        return checkbox.Text
    end

    if checkbox.CreateFontString then
        local textRegion = checkbox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        textRegion:SetPoint("LEFT", checkbox, "RIGHT", 0, 1)
        checkbox.Text = textRegion
        return textRegion
    end

    return nil
end

local function createCheckbox(parent, label, description, x, y, getter, setter)
    local checkbox = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    local textRegion = getCheckboxLabelRegion(checkbox)
    if textRegion and textRegion.SetText then
        textRegion:SetText(label)
    end
    checkbox.tooltipText = description
    checkbox:SetScript("OnClick", function(self)
        setter(self:GetChecked() and true or false)
    end)
    checkbox.Refresh = function()
        checkbox:SetChecked(getter())
    end
    return checkbox
end

local function createSlider(parent, name, label, lowText, highText, x, y, minValue, maxValue, valueStep, getter, setter)
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(valueStep)
    slider:SetObeyStepOnDrag(true)
    slider:SetWidth(220)

    local text = _G[slider:GetName() .. "Text"]
    if text and text.SetText then
        text:SetText(label)
    end

    local low = _G[slider:GetName() .. "Low"]
    if low and low.SetText then
        low:SetText(lowText)
    end

    local high = _G[slider:GetName() .. "High"]
    if high and high.SetText then
        high:SetText(highText)
    end

    slider.valueText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    slider.valueText:SetPoint("LEFT", slider, "RIGHT", 8, 0)

    slider.isRefreshing = false
    slider:SetScript("OnValueChanged", function(self, value)
        local rounded = math.floor((value * 100) + 0.5) / 100
        if not self.isRefreshing then
            setter(rounded)
        end
        if self.valueText then
            self.valueText:SetText(string.format("%.2fx", rounded))
        end
    end)

    slider.Refresh = function()
        local currentValue = getter()
        slider.isRefreshing = true
        slider:SetValue(currentValue)
        slider.isRefreshing = false
        if slider.valueText then
            slider.valueText:SetText(string.format("%.2fx", currentValue))
        end
    end

    return slider
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

    self.panel.unlockOverlay = createCheckbox(
        self.panel,
        "Unlock overlay",
        "Allow dragging the tracker overlay and scaling with mouse-wheel while unlocked.",
        16,
        -100,
        function() return QB:GetOption("unlockTrackerOverlay") end,
        function(value) QB:SetOption("unlockTrackerOverlay", value); QB:RefreshViews("options") end
    )

    self.panel.resetOverlayButton = CreateFrame("Button", nil, self.panel, "UIPanelButtonTemplate")
    self.panel.resetOverlayButton:SetWidth(190)
    self.panel.resetOverlayButton:SetHeight(22)
    self.panel.resetOverlayButton:SetPoint("TOPLEFT", self.panel.unlockOverlay, "BOTTOMLEFT", 0, -8)
    self.panel.resetOverlayButton:SetText("Reset Overlay Position")
    self.panel.resetOverlayButton:SetScript("OnClick", function()
        QB:ResetTrackerOverlayPosition()
        QB:RefreshViews("options")
    end)

    self.panel.overlayScale = createSlider(
        self.panel,
        "QuestBuddyOverlayScaleSlider",
        "Overlay Scale",
        "0.70x",
        "1.60x",
        16,
        -166,
        0.7,
        1.6,
        0.01,
        function() return (QB:GetTrackerOverlayState() and QB:GetTrackerOverlayState().scale) or 1 end,
        function(value) QB:SetTrackerOverlayScale(value); QB:RefreshViews("options") end
    )

    self.panel.sharedOnly = createCheckbox(
        self.panel,
        "Show only shared quests in window",
        "Hide buddy-only and mine-only sections in the compact window.",
        16,
        -210,
        function() return QB:GetOption("showOnlySharedQuests") end,
        function(value) QB:SetOption("showOnlySharedQuests", value); QB:RefreshViews("options") end
    )

    self.panel.partyBoard = createCheckbox(
        self.panel,
        "Enable party scan board",
        "Show a compact multi-buddy summary panel at the top of the main window.",
        16,
        -240,
        function() return QB:GetOption("enablePartyBoard") end,
        function(value) QB:SetOption("enablePartyBoard", value); QB:RefreshViews("options") end
    )

    self.panel.autoFocus = createCheckbox(
        self.panel,
        "Auto-focus a single buddy",
        "When exactly one QuestBuddy peer is in party, focus them automatically.",
        16,
        -270,
        function() return QB:GetOption("autoFocusSingleBuddy") end,
        function(value) QB:SetOption("autoFocusSingleBuddy", value); QB.State:ReevaluateFocus(QB.db); QB:RefreshViews("options") end
    )

    self.panel.sortSharedDelta = createCheckbox(
        self.panel,
        "Sort shared by largest delta",
        "Prioritize shared quests where one side is furthest ahead in objective progress.",
        16,
        -300,
        function() return QB:GetRowDisplayPreset().sortSharedByLargestDelta end,
        function(value)
            local preset = QB:GetRowDisplayPreset()
            preset.sortSharedByLargestDelta = value and true or false
            QB:SetRowDisplayPreset(preset)
            QB:RefreshViews("options")
        end
    )

    self.panel.resetFiltersButton = CreateFrame("Button", nil, self.panel, "UIPanelButtonTemplate")
    self.panel.resetFiltersButton:SetWidth(190)
    self.panel.resetFiltersButton:SetHeight(22)
    self.panel.resetFiltersButton:SetPoint("TOPLEFT", self.panel.sortSharedDelta, "BOTTOMLEFT", 0, -8)
    self.panel.resetFiltersButton:SetText("Reset Filters/Sort Preset")
    self.panel.resetFiltersButton:SetScript("OnClick", function()
        QB:ResetRowDisplayPreset()
        self.panel.sortSharedDelta:Refresh()
        QB:RefreshViews("options")
    end)

    self.panel.lockWindow = createCheckbox(
        self.panel,
        "Lock main window",
        "Prevent dragging the main QuestBuddy window.",
        16,
        -360,
        function() return QB:GetOption("lockWindow") end,
        function(value) QB:SetOption("lockWindow", value) end
    )

    self.panel.recoveryPrompts = createCheckbox(
        self.panel,
        "Enable stale/offline action prompts",
        "Show inline recovery chips when the focused buddy is stale or offline.",
        16,
        -390,
        function() return QB:GetOption("enableRecoveryPrompts") end,
        function(value) QB:SetOption("enableRecoveryPrompts", value); QB:RefreshViews("options") end
    )

    self.panel.recoverySilent = createCheckbox(
        self.panel,
        "Silent recovery prompts",
        "Suppress chat feedback when using stale/offline recovery actions.",
        16,
        -420,
        function() return QB:GetOption("recoveryPromptSilent") end,
        function(value) QB:SetOption("recoveryPromptSilent", value); QB:RefreshViews("options") end
    )

    self.panel.timeoutLabel = self.panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.panel.timeoutLabel:SetPoint("TOPLEFT", self.panel, "TOPLEFT", 16, -460)
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
        panel.unlockOverlay:Refresh()
        panel.overlayScale:Refresh()
        panel.sharedOnly:Refresh()
        panel.partyBoard:Refresh()
        panel.autoFocus:Refresh()
        panel.sortSharedDelta:Refresh()
        panel.lockWindow:Refresh()
        panel.recoveryPrompts:Refresh()
        panel.recoverySilent:Refresh()
        panel.timeoutBox:SetText(tostring(QB:GetOption("staleTimeoutSeconds") or 90))
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        self.category = Settings.RegisterCanvasLayoutCategory(self.panel, "QuestBuddy")
        Settings.RegisterAddOnCategory(self.category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(self.panel)
    end
end

function Options:Open()
    if not self.panel then
        return
    end

    if Settings and Settings.OpenToCategory and self.category and self.category.ID then
        Settings.OpenToCategory(self.category.ID)
        return
    end

    if InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(self.panel)
        InterfaceOptionsFrame_OpenToCategory(self.panel)
    end
end
