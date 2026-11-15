local _, addon = ...

local function GetZoneMapName(mapID)
    local seen = {}
    while mapID and mapID > 0 and not seen[mapID] do
        seen[mapID] = true
        local map = C_Map.GetMapInfo(mapID)
        if not map then
            return
        end
        if map.mapType == Enum.UIMapType.Zone then
            if map.name ~= "" then
                return map.name
            end
            return
        end
        -- A quest POI may be on a dungeon or smaller map inside a zone.
        mapID = map.parentMapID
    end
end

local function GetGroup(questID)
    local index = C_QuestLog.GetHeaderIndexForQuest(questID)
    local header = index and C_QuestLog.GetInfo(index)
    if header and header.isHeader and header.title and header.title ~= "" then
        return "zone:" .. header.title, header.title
    end

    -- Ask for the quest's map without using its changing waypoint map.
    local zone = GetZoneMapName(GetQuestUiMapID(questID, true))
    if not zone then
        zone = GetZoneMapName(C_TaskQuest.GetQuestZoneID(questID))
    end
    if zone then
        return "zone:" .. zone, zone
    end
    return "other", OTHER or "Other"
end

function addon.GetQuestItem(questID)
    local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
    if not logIndex then
        return
    end

    local link, icon, _, showWhenComplete = GetQuestLogSpecialItemInfo(logIndex)
    if not link or not icon or (not showWhenComplete and C_QuestLog.IsComplete(questID)) then
        return
    end

    local itemID = C_Item.GetItemInfoInstant(link)
    if itemID and itemID > 0 then
        return { id = itemID, link = link, icon = icon }
    end
end

local function ReadQuest(questID, money)
    local ready = C_QuestLog.ReadyForTurnIn(questID)
    if ready == nil then
        ready = C_QuestLog.IsComplete(questID)
    end

    local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
    local info = logIndex and C_QuestLog.GetInfo(logIndex)
    local title = info and info.title
    if not title or title == "" then
        title = C_QuestLog.GetTitleForQuestID(questID)
    end
    if not title or title == "" then
        title = RETRIEVING_DATA or "Loading..."
    end

    local moneyText
    local requiredMoney = C_QuestLog.GetRequiredMoney(questID)
    if requiredMoney and requiredMoney > money and not ready then
        moneyText = GetMoneyString(money) .. " / " .. GetMoneyString(requiredMoney)
    end

    return {
        id = questID,
        title = title,
        level = info and info.level,
        ready = ready,
        objectives = C_QuestLog.GetQuestObjectives(questID) or {},
        item = addon.GetQuestItem(questID),
        moneyText = moneyText,
    }
end

function addon.GetGroups()
    local groups, groupsByKey, seen = {}, {}, {}
    local money = GetMoney()

    for i = 1, C_QuestLog.GetNumQuestWatches() do
        local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
        if questID and not seen[questID] and not C_QuestLog.IsQuestTask(questID)
            and not C_QuestLog.IsQuestBounty(questID) and not C_QuestLog.IsQuestDisabledForSession(questID) then
            seen[questID] = true
            local key, name = GetGroup(questID)
            local group = groupsByKey[key]
            if not group then
                group = { key = key, name = name, quests = {} }
                groupsByKey[key] = group
                groups[#groups + 1] = group
            end
            group.quests[#group.quests + 1] = ReadQuest(questID, money)
        end
    end

    table.sort(groups, function(a, b)
        if a.key == "other" or b.key == "other" then
            return b.key == "other" and a.key ~= "other"
        end
        return a.name < b.name
    end)
    return groups
end
