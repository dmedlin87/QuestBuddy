---@diagnostic disable: undefined-global, undefined-field
local addonName, QB = ...

QB = QB or _G.QuestBuddy or {}
_G.QuestBuddy = QB
QB.PartyApi = QB.PartyApi or {}

local PartyApi = QB.PartyApi

function PartyApi:GetPlayerName()
    if QB.Compat and QB.Compat.SafeUnitName then
        return QB.Compat:SafeUnitName("player") or "Unknown"
    end
    return "Unknown"
end

function PartyApi:GetPeerNames()
    local peers = {}
    if not QB.Compat or not QB.Compat.IsInParty or not QB.Compat:IsInParty() then
        return peers
    end

    local count = QB.Compat:GetPartyMemberCount()
    for index = 1, count do
        local name = QB.Compat:SafeUnitName("party" .. index)
        if name then
            table.insert(peers, name)
        end
    end

    table.sort(peers)
    return peers
end

function PartyApi:GetPeerSet()
    local peerSet = {}
    for _, name in ipairs(self:GetPeerNames()) do
        peerSet[name] = true
    end
    return peerSet
end

function PartyApi:IsPeerInParty(name)
    if not name then
        return false
    end
    return self:GetPeerSet()[name] == true
end
