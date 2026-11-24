local addonName, addon = ...

local events = CreateFrame("Frame")
local section, collapsedZones
local enteredWorld, refreshQueued, progressQueued, disabled
local QueueRefresh, RedrawCachedGroups
local clickedMapQuestID
-- Combat title clicks select this quest in the addon's own circles. Native
-- super-tracking, and the map location if the map is still open, follow after
-- combat, so Blizzard's map and quest log update on their own secure paths.
local pendingFocusQuestID
local PLACEMENT_INTERVAL = 0.10
local FOCUS_BUTTON_SIZE = 22
local SCROLL_LEFT_GUTTER = 24
local ZONE_QUEST_PADDING = 14
local QUEST_ITEM_INSET = addon.QuestItemSize + 6
local progressEvents = {
    QUEST_DATA_LOAD_RESULT = true,
    QUEST_LOG_UPDATE = true,
    QUEST_LOG_CRITERIA_UPDATE = true,
    QUEST_WATCH_UPDATE = true,
    PLAYER_MONEY = true,
}

local function IsInQuestLog(questID)
    if not questID then
        return false
    end
    local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
    return logIndex ~= nil and logIndex > 0
end

local function IsCurrentQuestRow(row, questID)
    return row.questID == questID and row:IsVisible() and IsInQuestLog(questID)
end

local function FocusQuest(questID)
    if C_SuperTrack.GetSuperTrackedQuestID() ~= questID then
        C_SuperTrack.SetSuperTrackedQuestID(questID)
    end
end

local function OpenQuestMenu(row, questID)
    MenuUtil.CreateContextMenu(row, function(_, rootDescription)
        local watched = C_QuestLog.GetQuestWatchType(questID) ~= nil

        local function CanAct()
            return not InCombatLockdown() and IsCurrentQuestRow(row, questID)
        end

        local function CanChangeWatch()
            if (C_QuestLog.GetQuestWatchType(questID) ~= nil) ~= watched then
                return false
            end
            if watched then
                return QuestUtil.CanRemoveQuestWatch()
            end
            return C_QuestLog.GetNumQuestWatches() < Constants.QuestWatchConsts.MAX_QUEST_WATCHES
        end

        local function CanShare()
            return IsInGroup() and C_QuestLog.IsPushableQuest(questID)
        end

        local function CanAbandon()
            return C_QuestLog.CanAbandonQuest(questID)
        end

        local function AddAction(label, isEligible, action)
            local button = rootDescription:CreateButton(label, function()
                if CanAct() and isEligible() then
                    action(questID)
                end
            end)
            button:SetEnabled(CanAct() and isEligible())
        end

        AddAction(watched and "Untrack" or "Track", CanChangeWatch, QuestMapQuestOptions_TrackQuest)
        AddAction("Share", CanShare, QuestUtil.ShareQuest)
        AddAction("Abandon", CanAbandon, QuestMapQuestOptions_AbandonQuest)
    end)
end

local function OnRowClick(row, mouseButton)
    if row.zoneKey then
        if mouseButton == "LeftButton" then
            local key = row.zoneKey
            collapsedZones[key] = not collapsedZones[key] or nil
            if InCombatLockdown() then
                RedrawCachedGroups()
            else
                QueueRefresh()
            end
        end
        return
    end

    local questID = row.questID
    if not IsCurrentQuestRow(row, questID) then
        return
    end
    if mouseButton == "RightButton" then
        OpenQuestMenu(row, questID)
    elseif mouseButton == "LeftButton" and C_QuestLog.GetQuestWatchType(questID) then
        if InCombatLockdown() then
            -- The secure delegate opens a closed map natively. Leave Blizzard's
            -- map, quest log, and super-tracking untouched until combat ends.
            clickedMapQuestID = nil
            pendingFocusQuestID = questID
            RedrawCachedGroups()
            return
        end
        pendingFocusQuestID = nil
        clickedMapQuestID = questID
        FocusQuest(questID)
        if addon.IsQuestMapShown() or not section.mapClicker then
            addon.OpenQuestLocation(questID)
            clickedMapQuestID = nil
        end
    end
end

-- Same native tooltip Blizzard's tracker shows on quest headers while grouped,
-- plus progress shared by party members who run this addon.
local hoverOwner, hoverRow
local function ShowPartyProgress(owner, row)
    local questID = row.questID
    if not IsInGroup() or not IsCurrentQuestRow(row, questID) then
        return
    end
    hoverOwner, hoverRow = owner, row
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("TOPRIGHT", owner, "TOPLEFT", 0, 0)
    GameTooltip:SetOwner(owner, "ANCHOR_PRESERVE")
    GameTooltip:SetQuestPartyProgress(questID)
    addon.AddPartyProgress(GameTooltip, questID)
    addon.RequestPartyProgress(questID)
end

-- Redraw the open tooltip when a party member's answer arrives.
function addon.OnPartyProgress(questID)
    if hoverRow and hoverRow.questID == questID and GameTooltip:IsOwned(hoverOwner) then
        ShowPartyProgress(hoverOwner, hoverRow)
    end
end

local function HidePartyProgress(owner)
    if GameTooltip:IsOwned(owner) then
        GameTooltip:Hide()
    end
end

local function CreateFocusButton(row)
    local button = CreateFrame("Button", nil, row, "POIButtonTemplate")
    button:SetSize(FOCUS_BUTTON_SIZE, FOCUS_BUTTON_SIZE)
    button:SetFrameLevel(row:GetFrameLevel() + 2)
    button:SetPoint("TOPLEFT", row, "TOPLEFT", 5, 0)
    button:RegisterForClicks("LeftButtonUp")
    -- The section already refreshes focus on SUPER_TRACKING_CHANGED.
    button:SetScript("OnShow", nil)
    button:SetScript("OnHide", nil)
    function button:GetQuestClassification()
        return C_QuestInfoSystem.GetQuestClassification(self:GetQuestID())
    end
    button:SetScript("OnClick", function(self)
        local questID = self:GetParent().questID
        if questID and not InCombatLockdown() and C_QuestLog.GetQuestWatchType(questID) then
            local focused = C_SuperTrack.GetSuperTrackedQuestID() == questID
            C_SuperTrack.SetSuperTrackedQuestID(focused and 0 or questID)
        end
    end)

    row.focusButton = button
    return button
end

local function UpdateFocusButton(row, quest, focusedQuestID)
    if not quest then
        if row.focusButton then
            row.focusButton:Hide()
        end
        return
    end

    local button = row.focusButton or CreateFocusButton(row)
    local style = POIButtonUtil.Style
    button:SetQuestID(quest.id)
    button:SetStyle(quest.ready and style.QuestComplete or style.QuestInProgress)
    button:SetSelected(quest.id == focusedQuestID)
    button:UpdateButtonStyle()
    button:Show()
end

local function CreateRow(parent)
    local row = CreateFrame("Button", nil, parent, "InsecureMouseClicksPropagatorTemplate")
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", OnRowClick)
    row:SetScript("OnEnter", function(self)
        ShowPartyProgress(self, self)
    end)
    row:SetScript("OnLeave", HidePartyProgress)

    -- The blocker covers the row while the map is open, so it takes the hover too.
    local blocker = CreateFrame("Button", nil, row)
    blocker:SetAllPoints()
    blocker:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    blocker:SetScript("OnClick", function(_, button)
        OnRowClick(row, button)
    end)
    blocker:SetScript("OnEnter", function(self)
        ShowPartyProgress(self, row)
    end)
    blocker:SetScript("OnLeave", HidePartyProgress)
    row.mouseBlocker = blocker

    row.background = row:CreateTexture(nil, "BACKGROUND")
    row.background:SetAllPoints()
    row.background:SetColorTexture(0.19, 0.14, 0.08, 0.82)

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 0.82, 0.35, 0.13)
    row:SetHighlightTexture(highlight)

    row.text = row:CreateFontString(nil, "ARTWORK")
    row.text:SetJustifyH("LEFT")
    row.text:SetJustifyV("TOP")
    row.text:SetWordWrap(true)
    return row
end

local function Render(module, groups)
    local child, rows = module.child, module.rows
    local width = module:GetWidth() - 8
    local index, y = 0, 0
    local showFocusButtons = GetCVarBool("questPOI")
    local focusedQuestID = showFocusButtons and (pendingFocusQuestID or C_SuperTrack.GetSuperTrackedQuestID())
    local titleIndent = showFocusButtons and 30 or 12
    local objectiveIndent = showFocusButtons and 40 or 25
    local gapIndex = 0

    local function AddGap(height)
        gapIndex = gapIndex + 1
        local gap = module.gaps[gapIndex]
        if not gap then
            gap = CreateFrame("Frame", nil, child)
            gap:EnableMouse(true)
            module.gaps[gapIndex] = gap
        end
        gap:ClearAllPoints()
        gap:SetPoint("TOPLEFT", child, "TOPLEFT", SCROLL_LEFT_GUTTER, -y)
        gap:SetSize(width, height)
        gap:Show()
        y = y + height
    end

    local function AddRow(text, indent, zoneKey, quest, complete, itemQuest)
        index = index + 1
        local row = rows[index]
        if not row then
            row = CreateRow(child)
            rows[index] = row
        end

        row.zoneKey, row.questID = zoneKey, quest and quest.id
        addon.UpdateQuestClickMask(row)
        row.background:SetShown(zoneKey ~= nil)
        row:EnableMouse(true)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", child, "TOPLEFT", SCROLL_LEFT_GUTTER, -y)
        row:SetWidth(width)

        local focusQuest = showFocusButtons and quest
        UpdateFocusButton(row, focusQuest, focusedQuestID)
        addon.UpdateItemButton(module, row, itemQuest, SCROLL_LEFT_GUTTER + width, y)

        local label = row.text
        label:SetFontObject(zoneKey and "ObjectiveTrackerHeaderFont" or "ObjectiveTrackerLineFont")
        label:ClearAllPoints()
        label:SetPoint("TOPLEFT", row, "TOPLEFT", indent, -3)
        local rightInset = itemQuest and QUEST_ITEM_INSET or 4
        label:SetWidth(width - indent - rightInset)
        label:SetText(text)
        if zoneKey or quest then
            label:SetTextColor(1, 0.82, 0.32)
        elseif complete then
            label:SetTextColor(0.52, 0.89, 0.49)
        else
            label:SetTextColor(0.91, 0.91, 0.91)
        end

        local height = math.ceil(label:GetStringHeight()) + 6
        local minHeight = zoneKey and 24 or 18
        if focusQuest then
            minHeight = FOCUS_BUTTON_SIZE
        end
        row:SetHeight(math.max(height, minHeight))
        row:Show()
        y = y + row:GetHeight()
    end

    for _, group in ipairs(groups) do
        local collapsed = collapsedZones[group.key]
        local ready = 0
        for _, quest in ipairs(group.quests) do
            if quest.ready then
                ready = ready + 1
            end
        end
        local count = tostring(#group.quests)
        if ready > 0 then
            count = ("%d, %d ready"):format(#group.quests, ready)
        end
        local label = ("%s  %s (%s)"):format(collapsed and "+" or "-", group.name, count)
        AddRow(label, 6, group.key)
        if not collapsed then
            -- The selected marker's glow extends above its button.
            if showFocusButtons then
                AddGap(ZONE_QUEST_PADDING)
            end
            for _, quest in ipairs(group.quests) do
                local title = quest.title
                if quest.level and quest.level > 0 then
                    title = ("%s [%d]"):format(title, quest.level)
                end
                AddRow(title, titleIndent, nil, quest)

                local itemQuest = quest.item and quest
                local function AddDescription(text, complete)
                    AddRow(text, objectiveIndent, nil, nil, complete, itemQuest)
                    itemQuest = nil
                end
                if quest.ready then
                    -- A completed quest shows only its turn-in status.
                    -- Size 0 scales Blizzard's ready-check icon to the line's font height.
                    AddDescription("|TInterface\\RaidFrame\\ReadyCheck-Ready:0|t "
                        .. (QUEST_WATCH_QUEST_READY or "Ready for turn-in"), true)
                else
                    for _, objective in ipairs(quest.objectives) do
                        if objective.text and objective.text ~= "" then
                            AddDescription(objective.text, objective.finished)
                        end
                    end
                    if quest.moneyText then
                        AddDescription(quest.moneyText)
                    end
                end
                if itemQuest then
                    AddDescription("")
                end
            end
        end
        AddGap(4)
    end

    for i = index + 1, #rows do
        addon.UpdateItemButton(module, rows[i])
        rows[i]:Hide()
    end
    for i = gapIndex + 1, #module.gaps do
        module.gaps[i]:Hide()
    end
    module.fullHeight = y
    module.placementElapsed = PLACEMENT_INTERVAL
    module.viewportDirty = true
    child:SetSize(math.max(width, 1) + SCROLL_LEFT_GUTTER, math.max(y, 1))
end

local function UpdateScroll(module, offset)
    local view, thumb = module.view, module.thumb
    local range = math.max(0, module.fullHeight - module.contentsHeight)
    offset = math.max(0, math.min(offset, range))
    view:SetVerticalScroll(offset)
    thumb:SetShown(range > 0)
    if range > 0 then
        local size = math.max(8, module.contentsHeight ^ 2 / module.fullHeight)
        thumb:SetHeight(math.min(size, module.contentsHeight))
        thumb:SetPoint("TOPRIGHT", module, "TOPRIGHT", -1,
            -(module.contentsHeight - thumb:GetHeight()) * offset / range)
    end
end

local function SyncViewport(module)
    local view = module.view
    if not module.viewportDirty or not view:IsVisible() or not view:GetTop()
        or math.abs(view:GetHeight() - module.contentsHeight) > 0.5 then
        return
    end

    -- Rebuild the scroll rectangle once the viewport adopts the new size.
    local offset = view:GetVerticalScroll()
    view:UpdateScrollChildRect()
    UpdateScroll(module, offset)
    module.viewportDirty = false
end

local function CreateSection(container, stock)
    -- Keep addon frames and layout callbacks out of Blizzard's module list.
    local module = CreateFrame("Frame", nil, UIParent)
    module:Hide()
    module:SetSize(stock:GetWidth(), 1)
    module:SetFrameStrata("MEDIUM")
    module:SetFrameLevel(10)
    module.container = container
    module.stockQuests = { [stock] = { stock = stock } }
    local campaign = CampaignQuestObjectiveTracker
    if campaign then
        module.stockQuests[campaign] = { stock = campaign }
    end
    module.rows, module.gaps = {}, {}
    module.placementElapsed = 0
    module.itemButtons, module.itemElapsed = {}, 0
    module.contentsHeight, module.fullHeight = 0, 0

    local view = CreateFrame("ScrollFrame", nil, module)
    -- Extend the clip area for the marker glow. The row inset keeps the text in place.
    view:SetPoint("TOPLEFT", module, "TOPLEFT", -SCROLL_LEFT_GUTTER, 0)
    view:SetPoint("BOTTOMRIGHT", module, "BOTTOMRIGHT", 0, 0)
    local function InvalidateViewport()
        module.viewportDirty = true
    end
    view:SetScript("OnShow", InvalidateViewport)
    view:SetScript("OnSizeChanged", InvalidateViewport)
    view:EnableMouseWheel(true)
    view:SetScript("OnMouseWheel", function(self, delta)
        UpdateScroll(module, self:GetVerticalScroll() - delta * 38)
        if InCombatLockdown() and #module.itemButtons > 0 then
            addon.UpdateItemButtons(module, 0)
        end
    end)
    module.view = view
    module.child = CreateFrame("Frame", nil, view)
    module.child:SetSize(1, 1)
    view:SetScrollChild(module.child)
    module.thumb = module:CreateTexture(nil, "OVERLAY")
    module.thumb:SetColorTexture(0.88, 0.71, 0.4, 0.8)
    module.thumb:SetWidth(2)
    module.thumb:Hide()

    addon.CreateMapClicker(module, function()
        local questID = clickedMapQuestID
        clickedMapQuestID = nil
        if IsInQuestLog(questID) and C_QuestLog.GetQuestWatchType(questID) then
            addon.OpenQuestLocation(questID)
        end
    end)

    return module
end

local function Refresh()
    if not section then
        section = CreateSection(ObjectiveTrackerFrame, QuestObjectiveTracker)
    end
    local groups = addon.GetGroups()
    Render(section, groups)
    section.groups = groups
end

local function DisableTracker(message)
    disabled = true
    if section then
        addon.HideTracker(section)
    end
    geterrorhandler()(addonName .. ": " .. tostring(message))
end

RedrawCachedGroups = function(updateProgress)
    if disabled or not section or not section.groups then
        return
    end

    local ok, message = pcall(function()
        if updateProgress and not addon.RefreshQuestProgress(section.groups) then
            return
        end
        Render(section, section.groups)
        addon.PlaceTracker(section)
        SyncViewport(section)
        if #section.itemButtons > 0 then
            addon.UpdateItemButtons(section, 0)
        end
    end)
    if not ok then
        DisableTracker(message)
    end
end

QueueRefresh = function(updateProgress)
    if disabled or not enteredWorld or not collapsedZones or (InCombatLockdown() and not updateProgress) then
        return
    end
    progressQueued = progressQueued or updateProgress
    if refreshQueued then
        return
    end

    refreshQueued = true
    C_Timer.After(0, function()
        local refreshProgress = progressQueued
        refreshQueued, progressQueued = false, nil
        if disabled then
            return
        end
        if InCombatLockdown() then
            if refreshProgress then
                RedrawCachedGroups(true)
            end
        else
            local ok, message = pcall(Refresh)
            if not ok then
                DisableTracker(message)
            end
        end
    end)
end

events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name ~= addonName then
            return
        end
        if type(ZoneQuestTrackerDB) ~= "table" then
            ZoneQuestTrackerDB = {}
        end
        if type(ZoneQuestTrackerDB.collapsed) ~= "table" then
            ZoneQuestTrackerDB.collapsed = {}
        end
        collapsedZones = ZoneQuestTrackerDB.collapsed
        events:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_ENTERING_WORLD" then
        enteredWorld = true
    elseif event == "SUPER_TRACKING_CHANGED" and InCombatLockdown() then
        -- A native focus change during combat replaces a pending title selection.
        if pendingFocusQuestID then
            pendingFocusQuestID = nil
            RedrawCachedGroups()
        end
        return
    elseif event == "PLAYER_REGEN_ENABLED" and section then
        clickedMapQuestID = nil
        local questID = pendingFocusQuestID
        pendingFocusQuestID = nil
        if questID and IsInQuestLog(questID) and C_QuestLog.GetQuestWatchType(questID) then
            if addon.IsQuestMapShown() then
                -- Show the last quest clicked in combat on the map that is still open.
                addon.OpenQuestLocation(questID)
            else
                FocusQuest(questID)
            end
        end
        if disabled then
            -- Restore a native module whose opacity could not be restored during combat.
            addon.HideTracker(section)
            return
        end
        section.placementElapsed = PLACEMENT_INTERVAL
    elseif event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" or event == "EDIT_MODE_LAYOUTS_UPDATED" then
        if section then
            section.placementElapsed = PLACEMENT_INTERVAL
            section.viewportDirty = true
        end
        return
    elseif event == "CVAR_UPDATE" and name:lower() ~= "questpoi" then
        return
    end
    QueueRefresh(progressEvents[event])
end)

events:SetScript("OnUpdate", function(_, elapsed)
    if not section then
        return
    end
    if not disabled then
        section.placementElapsed = section.placementElapsed + elapsed
        if section.placementElapsed >= PLACEMENT_INTERVAL then
            section.placementElapsed = 0
            local ok, message = pcall(addon.PlaceTracker, section)
            if not ok then
                DisableTracker(message)
            end
        end
        SyncViewport(section)
    end
    if #section.itemButtons > 0 then
        addon.UpdateItemButtons(section, elapsed)
    end
end)

for _, event in ipairs({
    "ADDON_LOADED", "VARIABLES_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
    "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED", "EDIT_MODE_LAYOUTS_UPDATED",
    "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN", "QUEST_DATA_LOAD_RESULT",
    "QUEST_LOG_UPDATE", "QUEST_LOG_CRITERIA_UPDATE", "QUEST_WATCH_LIST_CHANGED", "QUEST_WATCH_UPDATE",
    "QUEST_POI_UPDATE", "SUPER_TRACKING_CHANGED", "CVAR_UPDATE", "PLAYER_MONEY", "BAG_UPDATE_DELAYED",
}) do
    events:RegisterEvent(event)
end
