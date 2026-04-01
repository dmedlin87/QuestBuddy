local addonName, QB = ...

QB = QB or _G.QuestBuddy or {}
_G.QuestBuddy = QB

local CreateFrame = _G.CreateFrame
local SlashCmdList = _G.SlashCmdList

QB.defaults = {
    options = {
        enableTrackerOverlay = true,
        unlockTrackerOverlay = false,
        enablePartyBoard = true,
        showOnlySharedQuests = false,
        sortSharedByLargestDelta = false,
        rowDisplayPreset = {
            watchedOnly = false,
            readyToTurnIn = false,
            showStaleOfflineEmphasis = false,
            sortSharedByLargestDelta = false,
        },
        autoFocusSingleBuddy = true,
        staleTimeoutSeconds = 90,
        lockWindow = false,
        enableRecoveryPrompts = true,
        recoveryPromptSilent = false,
    },
    window = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
        width = 420,
        height = 380,
    },
    trackerOverlay = {
        point = "TOPRIGHT",
        relativePoint = "TOPRIGHT",
        x = -60,
        y = -220,
        scale = 1,
        width = nil,
        height = nil,
    },
    lastFocusedBuddy = nil,
}

QB.frame = QB.frame or nil
QB.initialized = QB.initialized or false

local function ensureSavedVariables()
    _G.QuestBuddyDB = _G.QuestBuddyDB or {}
    QB.db = QB.Compat:MergeDefaults(_G.QuestBuddyDB, QB.defaults)
end

function QB:GetOption(key)
    return self.db and self.db.options and self.db.options[key]
end

function QB:SetOption(key, value)
    self.db.options[key] = value
end

function QB:GetRowDisplayPreset()
    local options = self.db and self.db.options or {}
    local defaults = self.defaults and self.defaults.options and self.defaults.options.rowDisplayPreset or {}
    local preset = QB.Compat:MergeDefaults(options.rowDisplayPreset or {}, defaults)

    preset.sortSharedByLargestDelta = (preset.sortSharedByLargestDelta or false) or (options.sortSharedByLargestDelta or false)
    options.rowDisplayPreset = preset

    return preset
end

function QB:SetRowDisplayPreset(preset)
    local current = self:GetRowDisplayPreset()
    for key, value in pairs(preset or {}) do
        current[key] = value and true or false
    end
    self.db.options.rowDisplayPreset = current
    self.db.options.sortSharedByLargestDelta = current.sortSharedByLargestDelta and true or false
end

function QB:ResetRowDisplayPreset()
    local defaults = self.defaults and self.defaults.options and self.defaults.options.rowDisplayPreset or {}
    self.db.options.rowDisplayPreset = QB.Compat:CopyTable(defaults)
    self.db.options.sortSharedByLargestDelta = defaults.sortSharedByLargestDelta and true or false
end

function QB:GetWindowState()
    return self.db.window
end

function QB:GetTrackerOverlayState()
    return self.db.trackerOverlay
end

function QB:SetTrackerOverlayAnchor(point, relativePoint, x, y)
    local overlay = self:GetTrackerOverlayState()
    overlay.point = point or overlay.point
    overlay.relativePoint = relativePoint or overlay.relativePoint
    overlay.x = tonumber(x) or overlay.x
    overlay.y = tonumber(y) or overlay.y
end

function QB:SetTrackerOverlayScale(scale)
    local overlay = self:GetTrackerOverlayState()
    overlay.scale = self.Compat:Clamp(tonumber(scale) or 1, 0.7, 1.6)
end

function QB:ResetTrackerOverlayPosition()
    local overlay = self:GetTrackerOverlayState()
    local defaults = self.defaults and self.defaults.trackerOverlay or {}
    overlay.point = defaults.point or "TOPRIGHT"
    overlay.relativePoint = defaults.relativePoint or "TOPRIGHT"
    overlay.x = defaults.x or -60
    overlay.y = defaults.y or -220
end

function QB:RefreshViews(reason)
    if self.State and self.db then
        local focusedBuddy = self.State:GetFocusedBuddy()
        if focusedBuddy and not self.State:IsSimulatedPeer(focusedBuddy) then
            self.db.lastFocusedBuddy = focusedBuddy
        end
    end
    if self.Tracker and self.Tracker.Refresh then
        self.Tracker:Refresh(reason)
    end
    if self.UI and self.UI.Refresh then
        self.UI:Refresh(reason)
    end
end

function QB:HandleQuestLogChange(reason)
    local currentTime = self.Compat:GetTime()

    if self.QuestApi and self.QuestApi.ShouldIgnoreQuestLogUpdate and self.QuestApi:ShouldIgnoreQuestLogUpdate(currentTime) then
        return
    end

    local changed = self.State:RefreshLocalSnapshot(currentTime)
    self.State:ReevaluateFocus(self.db)
    self:RefreshViews(reason)

    if changed then
        self.Comms:QueueSnapshotBroadcast(reason)
        self.Comms:BroadcastHello()
    end
end

function QB:HandlePartyRosterChange(reason)
    local peerSet = self.PartyApi:GetPeerSet()
    self.State:PrunePeers(peerSet, self.Compat:GetTime())
    self.State:ReevaluateFocus(self.db)
    self:RefreshViews(reason)

    if self.Compat:IsInParty() then
        self.Comms:BroadcastHello()
    end
end

function QB:ToggleMainWindow()
    if self.UI and self.UI.Toggle then
        self.UI:Toggle()
    end
end

function QB:OpenOptions()
    if self.Options and self.Options.Open then
        self.Options:Open()
    end
end

function QB:ManualRefresh()
    self.Comms:BroadcastHello()
    self.Comms:RequestSnapshots("manual")
    self.Comms:QueueSnapshotBroadcast("manual")
    self:RefreshViews("manual-refresh")
end

function QB:ToggleSimulationBuddy()
    local currentTime = self.Compat:GetTime()

    if not self.State:GetSimulatedPeerName() then
        self.State:RefreshLocalSnapshot(currentTime)
    end

    local enabled = self.State:ToggleSimulatedPeer(currentTime)
    if not enabled then
        self.State:ReevaluateFocus(self.db)
    end
    self:RefreshViews(enabled and "simulate-on" or "simulate-off")
end

function QB:DumpDebugInfo()
    local p = function(msg) self.Compat:Printf(msg) end
    p("--- QuestBuddy Debug ---")

    if _G.GetNumQuestLogEntries then
        local e, q = _G.GetNumQuestLogEntries()
        p("Legacy entries: " .. tostring(e) .. ", quests: " .. tostring(q))
    end

    local snapshot = self.State:GetLocalSnapshot()
    p("Snapshot quests: " .. tostring(snapshot and #snapshot.quests or "nil"))

    if _G.GetQuestLogTitle then
        p("-- First 6 GetQuestLogTitle entries --")
        for i = 1, 6 do
            local r1, r2, r3, r4, r5, r6, r7, r8, r9, r10 = _G.GetQuestLogTitle(i)
            local values = {
                tostring(r1),
                tostring(r2),
                tostring(r3),
                tostring(r4),
                tostring(r5),
                tostring(r6),
                tostring(r7),
                tostring(r8),
                tostring(r9),
                tostring(r10),
            }
            p(string.format("%d: %s", i, table.concat(values, " | ")))
        end
    end

    p("--- End Debug ---")
end

function QB:Initialize()
    if self.initialized then
        return
    end

    ensureSavedVariables()
    self.State:Initialize(self.db)
    self.State:RefreshLocalSnapshot(self.Compat:GetTime())
    self.State:ReevaluateFocus(self.db)

    self.Tracker:Initialize()
    self.UI:Initialize()
    self.Options:Initialize()
    self.Comms:Initialize()
    if not self.Compat:RegisterAddonPrefix(self.Protocol.PREFIX) then
        self.Compat:Printf("QuestBuddy: failed to register addon message prefix '%s'.", self.Protocol.PREFIX)
    end

    _G.SLASH_QUESTBUDDY1 = "/qb"
    SlashCmdList.QUESTBUDDY = function(message)
        message = string.lower(string.gsub(message or "", "^%s+", ""))
        if message == "refresh" then
            QB:ManualRefresh()
        elseif message == "options" then
            QB:OpenOptions()
        elseif message == "debug" then
            QB:DumpDebugInfo()
        else
            QB:ToggleMainWindow()
        end
    end

    self.frame:RegisterEvent("CHAT_MSG_ADDON")
    self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    self.frame:RegisterEvent("QUEST_LOG_UPDATE")
    self.frame:RegisterEvent("QUEST_WATCH_UPDATE")
    self.frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self.frame:RegisterEvent("PLAYER_LOGOUT")

    self.initialized = true
    self:RefreshViews("initialize")
    self:HandlePartyRosterChange("initialize")
end

function QB:OnEvent(event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            self.frame:UnregisterEvent("ADDON_LOADED")
            self:Initialize()
        end
    elseif event == "CHAT_MSG_ADDON" then
        self.Comms:OnAddonMessage(...)
    elseif event == "PLAYER_ENTERING_WORLD" then
        self:HandleQuestLogChange("enter-world")
        self:HandlePartyRosterChange("enter-world")
    elseif event == "PARTY_MEMBERS_CHANGED" or event == "GROUP_ROSTER_UPDATE" then
        self:HandlePartyRosterChange("party-changed")
    elseif event == "QUEST_LOG_UPDATE" then
        self:HandleQuestLogChange("quest-log")
    elseif event == "QUEST_WATCH_UPDATE" then
        self:HandleQuestLogChange("watch-update")
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        self:HandlePartyRosterChange("zone-change")
    elseif event == "PLAYER_LOGOUT" then
        self.Comms:SendGoodbye()
    end
end

if CreateFrame then
    QB.frame = QB.frame or CreateFrame("Frame")
    QB.frame:RegisterEvent("ADDON_LOADED")
    QB.frame:SetScript("OnEvent", function(_, event, ...)
        QB:OnEvent(event, ...)
    end)
end
