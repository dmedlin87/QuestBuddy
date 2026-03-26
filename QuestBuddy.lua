local addonName, QB = ...

QB = QB or _G.QuestBuddy or {}
_G.QuestBuddy = QB

QB.defaults = {
    options = {
        enableTrackerOverlay = true,
        showOnlySharedQuests = false,
        autoFocusSingleBuddy = true,
        staleTimeoutSeconds = 90,
        lockWindow = false,
    },
    window = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
        width = 420,
        height = 380,
    },
    lastFocusedBuddy = nil,
}

QB.frame = QB.frame or nil
QB.initialized = QB.initialized or false

local function ensureSavedVariables()
    QuestBuddyDB = QuestBuddyDB or {}
    QB.db = QB.Compat:MergeDefaults(QuestBuddyDB, QB.defaults)
end

function QB:GetOption(key)
    return self.db and self.db.options and self.db.options[key]
end

function QB:SetOption(key, value)
    self.db.options[key] = value
end

function QB:GetWindowState()
    return self.db.window
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

    SLASH_QUESTBUDDY1 = "/qb"
    SlashCmdList.QUESTBUDDY = function(message)
        message = string.lower(string.gsub(message or "", "^%s+", ""))
        if message == "refresh" then
            QB:ManualRefresh()
        elseif message == "options" then
            QB:OpenOptions()
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
