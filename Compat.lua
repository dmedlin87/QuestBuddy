---@diagnostic disable: undefined-global, undefined-field
local addonName, QB = ...

QB = QB or _G.QuestBuddy or {}
_G.QuestBuddy = QB
QB.Compat = QB.Compat or {}

local Compat = QB.Compat
local unpack = table.unpack or unpack
local GetTime = _G.GetTime
local time = _G.time
local C_ChatInfo = _G.C_ChatInfo
local IsInGroup = _G.IsInGroup
local IsInRaid = _G.IsInRaid
local GetNumSubgroupMembers = _G.GetNumSubgroupMembers
local GetNumPartyMembers = _G.GetNumPartyMembers
local GetNumRaidMembers = _G.GetNumRaidMembers
local SendAddonMessage = _G.SendAddonMessage
local RegisterAddonMessagePrefix = _G.RegisterAddonMessagePrefix
local UnitExists = _G.UnitExists
local UnitName = _G.UnitName
local UNKNOWN = _G.UNKNOWN

Compat.timerFrame = Compat.timerFrame or nil
Compat.timers = Compat.timers or {}
Compat.nextTimerId = Compat.nextTimerId or 0

local function ensureTimerFrame()
    if Compat.timerFrame or not CreateFrame then
        return
    end

    Compat.timerFrame = CreateFrame("Frame")
    Compat.timerFrame:SetScript("OnUpdate", function(_, elapsed)
        local now = Compat:GetTime()

        for timerId, timer in pairs(Compat.timers) do
            timer.remaining = timer.remaining - elapsed
            if timer.remaining <= 0 then
                Compat.timers[timerId] = nil
                timer.callback(unpack(timer.args))
            end
        end

        if not next(Compat.timers) then
            Compat.timerFrame:Hide()
        end
    end)
    Compat.timerFrame:Hide()
end

function Compat:GetTime()
    if GetTime then
        return GetTime()
    end
    return 0
end

function Compat:GetWallClock()
    if time then
        return time()
    end
    return 0
end

function Compat:After(delaySeconds, callback, ...)
    if type(callback) ~= "function" then
        return nil
    end

    ensureTimerFrame()
    if not Compat.timerFrame then
        callback(...)
        return nil
    end

    Compat.nextTimerId = Compat.nextTimerId + 1
    local timerId = Compat.nextTimerId

    Compat.timers[timerId] = {
        remaining = delaySeconds or 0,
        callback = callback,
        args = { ... },
    }

    Compat.timerFrame:Show()
    return timerId
end

function Compat:CancelTimer(timerId)
    if not timerId then
        return
    end
    Compat.timers[timerId] = nil
    if Compat.timerFrame and not next(Compat.timers) then
        Compat.timerFrame:Hide()
    end
end

function Compat:IsInParty()
    if IsInGroup and IsInRaid then
        return IsInGroup() and not IsInRaid()
    end

    local partyCount = GetNumPartyMembers and GetNumPartyMembers() or 0
    local raidCount = GetNumRaidMembers and GetNumRaidMembers() or 0
    return partyCount > 0 and raidCount == 0
end

function Compat:GetPartyMemberCount()
    if GetNumSubgroupMembers then
        return GetNumSubgroupMembers()
    end
    if GetNumPartyMembers then
        return GetNumPartyMembers()
    end
    return 0
end

function Compat:SafeUnitName(unit)
    if not unit or not UnitExists or not UnitExists(unit) then
        return nil
    end

    local name, realm = UnitName(unit)
    if not name or name == UNKNOWN then
        return nil
    end

    if realm and realm ~= "" then
        return string.format("%s-%s", name, realm)
    end

    return name
end

function Compat:CopyTable(source)
    if type(source) ~= "table" then
        return source
    end

    local clone = {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            clone[key] = self:CopyTable(value)
        else
            clone[key] = value
        end
    end
    return clone
end

function Compat:MergeDefaults(target, defaults)
    target = target or {}

    for key, value in pairs(defaults or {}) do
        if type(value) == "table" then
            target[key] = self:MergeDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end

    return target
end

function Compat:RegisterAddonPrefix(prefix)
    if not prefix or prefix == "" then
        return false
    end

    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        return C_ChatInfo.RegisterAddonMessagePrefix(prefix) and true or false
    end
    if RegisterAddonMessagePrefix then
        return RegisterAddonMessagePrefix(prefix) and true or false
    end

    return false
end

function Compat:SendAddonMessage(prefix, payload, distribution, target)
    if not prefix or not payload or payload == "" then
        return false
    end

    if distribution == "WHISPER" then
        if not target or target == "" then
            return false
        end
    elseif distribution == "PARTY" then
        if not self:IsInParty() then
            return false
        end
    else
        return false
    end

    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        C_ChatInfo.SendAddonMessage(prefix, payload, distribution, target)
        return true
    end
    if not SendAddonMessage then
        return false
    end

    SendAddonMessage(prefix, payload, distribution, target)
    return true
end

function Compat:Colorize(text, color)
    if not color or type(color) ~= "table" then
        return text
    end

    local red = math.floor((color.r or 1) * 255)
    local green = math.floor((color.g or 1) * 255)
    local blue = math.floor((color.b or 1) * 255)
    return string.format("|cff%02x%02x%02x%s|r", red, green, blue, tostring(text or ""))
end

function Compat:Clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    end
    if value > maximum then
        return maximum
    end
    return value
end

function Compat:SortedKeys(map)
    local keys = {}
    for key in pairs(map or {}) do
        table.insert(keys, key)
    end
    table.sort(keys)
    return keys
end

function Compat:Printf(formatString, ...)
    if DEFAULT_CHAT_FRAME and formatString then
        DEFAULT_CHAT_FRAME:AddMessage(string.format(formatString, ...))
    end
end
