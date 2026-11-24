local _, addon = ...

-- The Forever server sends no party quest progress, so Blizzard's party tooltip
-- lists only the player. Party members running this addon answer on request.
local PREFIX = "ZQTParty"
local REQUEST_INTERVAL = 3
local progress = {} -- [member name] = { [questID] = { ready = bool, "n/r/f", ... } }
local lastRequest = {}

C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)

local function Channel()
    -- shortcut: home party or raid only, instance groups (LFG) get no reply; add INSTANCE_CHAT if needed.
    if IsInRaid() then
        return "RAID"
    end
    return IsInGroup() and "PARTY" or nil
end

local function IsGroupMember(name)
    return UnitInParty(name) or UnitInRaid(name)
end

function addon.RequestPartyProgress(questID)
    local channel = Channel()
    local now = GetTime()
    if channel and now - (lastRequest[questID] or -REQUEST_INTERVAL) >= REQUEST_INTERVAL then
        lastRequest[questID] = now
        C_ChatInfo.SendAddonMessage(PREFIX, "?," .. questID, channel)
    end
end

local function Reply(questID, channel)
    local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
    if not logIndex or logIndex < 1 then
        return
    end
    local parts = { "=", questID, addon.IsQuestReady(questID) and 1 or 0 }
    for _, objective in ipairs(C_QuestLog.GetQuestObjectives(questID) or {}) do
        parts[#parts + 1] = ("%d/%d/%d"):format(objective.numFulfilled or 0,
            objective.numRequired or 0, objective.finished and 1 or 0)
    end
    C_ChatInfo.SendAddonMessage(PREFIX, table.concat(parts, ","), channel)
end

-- Adds party members' lines below Blizzard's tooltip, using this client's objective text.
-- shortcut: no check against names Blizzard already lists; dedupe if a server ever sends party progress.
function addon.AddPartyProgress(tooltip, questID)
    local objectives = C_QuestLog.GetQuestObjectives(questID) or {}
    local added = false
    for name, quests in pairs(progress) do
        local data = quests[questID]
        if data and IsGroupMember(name) then
            tooltip:AddLine(name, 1, 0.82, 0)
            if data.ready then
                tooltip:AddLine("  " .. (QUEST_WATCH_QUEST_READY or "Ready for turn-in"), 0.52, 0.89, 0.49)
            else
                for index, objective in ipairs(objectives) do
                    local count = data[index]
                    local fulfilled, required, finished = (count or ""):match("^(%d+)/(%d+)/(%d)$")
                    local text = objective.text or ""
                    if fulfilled and tonumber(required) > 0 then
                        text = text:gsub("^%d+/%d+", fulfilled .. "/" .. required, 1)
                    end
                    if finished == "1" then
                        tooltip:AddLine("  " .. text, 0.52, 0.89, 0.49)
                    else
                        tooltip:AddLine("  " .. text, 0.8, 0.8, 0.8)
                    end
                end
            end
            added = true
        end
    end
    if added then
        tooltip:Show()
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("CHAT_MSG_ADDON")
events:SetScript("OnEvent", function(_, _, prefix, message, channel, sender)
    if prefix ~= PREFIX or type(message) ~= "string" then
        return
    end
    local name = Ambiguate(sender or "", "none")
    if name == UnitName("player") or not IsGroupMember(name) then
        return
    end

    local kind, questID, rest = message:match("^([?=]),(%d+),?(.*)$")
    questID = tonumber(questID)
    if not questID then
        return
    end
    if kind == "?" then
        Reply(questID, Channel() or channel)
        return
    end

    local ready, counts = rest:match("^([01]),?(.*)$")
    if not ready then
        return
    end
    local data = { ready = ready == "1" }
    for count in counts:gmatch("[^,]+") do
        data[#data + 1] = count
    end
    progress[name] = progress[name] or {}
    progress[name][questID] = data
    if addon.OnPartyProgress then
        addon.OnPartyProgress(questID)
    end
end)
