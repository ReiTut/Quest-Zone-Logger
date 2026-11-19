local _, addon = ...

function addon.IsQuestMapShown()
    return WorldMapFrame and WorldMapFrame:IsShown()
end

-- Changing the map from addon code makes Blizzard rebuild its quest log on the
-- addon's execution path. During combat that rebuild fails Blizzard's secure
-- SmartNavigation check ("Interface action failed because of an AddOn") and
-- leaves addon taint in the pooled quest-log buttons. Only navigate outside combat.
function addon.OpenQuestLocation(questID)
    if InCombatLockdown() then
        return false
    end

    if C_SuperTrack.GetSuperTrackedQuestID() ~= questID then
        C_SuperTrack.SetSuperTrackedQuestID(questID)
    end

    local mapID = GetQuestUiMapID(questID)
    C_Map.OpenWorldMap(mapID and mapID > 0 and mapID or nil)

    if addon.IsQuestMapShown() then
        EventRegistry:TriggerEvent("MapCanvas.PingQuestID", questID)
        return true
    end
    return false
end

function addon.UpdateQuestClickMask(row)
    row.mouseBlocker:SetShown(not row.questID or addon.IsQuestMapShown())
end

function addon.CreateMapClicker(section, onClick)
    local source = QuestLogMicroButton
    if not source or source:HasAccessConstraints()
        or source:HasAnyForbiddenAspects(Enum.ForbiddenAspect.ScriptedInput) then
        return
    end

    -- A propagated hardware click opens the stock map in secure execution.
    -- Keep this protected frame independent of the changing tracker rows.
    local action = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    action:Hide()
    action:RegisterForClicks("LeftButtonUp")
    action:SetAttribute("useOnKeyDown", false)
    action:SetAttribute("type1", "click")
    action:SetAttribute("clickbutton1", source)
    action:SetFrameStrata(section:GetFrameStrata())
    action:SetFrameLevel(section:GetFrameLevel() - 1)
    action:SetScript("PostClick", onClick)

    local blocker = CreateFrame("Frame", nil, UIParent)
    blocker:SetAllPoints(action)
    blocker:SetFrameStrata(action:GetFrameStrata())
    blocker:SetFrameLevel(action:GetFrameLevel() + 1)
    blocker:EnableMouse(true)
    blocker:Hide()

    local footer = CreateFrame("Frame", nil, UIParent)
    footer:SetFrameStrata(action:GetFrameStrata())
    footer:SetFrameLevel(action:GetFrameLevel() + 1)
    footer:EnableMouse(true)
    footer:Hide()
    section.mapClicker = { action = action, blocker = blocker, footer = footer }

    local function UpdateMasks()
        for _, row in ipairs(section.rows) do
            addon.UpdateQuestClickMask(row)
        end
    end
    WorldMapFrame:HookScript("OnShow", UpdateMasks)
    WorldMapFrame:HookScript("OnHide", UpdateMasks)
end

function addon.HideMapClicker(section)
    local clicker = section.mapClicker
    if not clicker then
        return
    end
    clicker.footer:Hide()
    if InCombatLockdown() then
        clicker.blocker:SetShown(clicker.action:IsShown())
    else
        clicker.action:Hide()
        clicker.blocker:Hide()
    end
end

function addon.PlaceMapClicker(section, left, top, width, height, scale)
    local clicker = section.mapClicker
    if not clicker then
        return
    end

    local action = clicker.action
    local aligned = action:IsShown() and clicker.left == left and clicker.top == top
        and clicker.width == width and clicker.height == height and clicker.scale == scale
    if not InCombatLockdown() and not aligned then
        action:SetScale(scale)
        action:ClearAllPoints()
        action:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / scale, top / scale)
        action:SetSize(width, height)
        action:Show()
        clicker.left, clicker.top = left, top
        clicker.width, clicker.height, clicker.scale = width, height, scale
        aligned = true
    end
    clicker.blocker:SetShown(action:IsShown() and not aligned)

    local remainingHeight = height - section.contentsHeight
    clicker.footer:SetShown(aligned and remainingHeight > 0)
    if aligned and remainingHeight > 0 then
        local footer = clicker.footer
        footer:SetScale(scale)
        footer:ClearAllPoints()
        footer:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / scale,
            top / scale - section.contentsHeight)
        footer:SetSize(width, remainingHeight)
    end
end
