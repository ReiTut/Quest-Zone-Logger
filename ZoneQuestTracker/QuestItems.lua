local _, addon = ...

local ITEM_SIZE = 18
local STATE_INTERVAL = 0.15
local PHANTASMAL_BLADE = 271992
addon.QuestItemSize = ITEM_SIZE

local function IsCurrentItem(button)
    local questID = button.questID
    if button.item and questID and C_QuestLog.GetQuestWatchType(questID) then
        local current = addon.GetQuestItem(questID)
        return current ~= nil and current.id == button.item.id
    end
    return false
end

local function IsUsable(itemID, inCombat)
    if not C_Item.IsUsableItem(itemID) or C_Item.GetItemCount(itemID) == 0 or UnitIsDeadOrGhost("player") then
        return false
    end

    local start, duration = C_Item.GetItemCooldown(itemID)
    if start and duration and duration > 0 and start + duration > GetTime() then
        return false
    end

    local targetExists = UnitExists("target")
    if issecretvalue(targetExists) then
        return true
    end
    if not targetExists then
        return itemID ~= PHANTASMAL_BLADE
    end

    local hostile = UnitCanAttack("player", "target")
    if issecretvalue(hostile) then
        return true
    end
    if itemID == PHANTASMAL_BLADE and (not hostile or UnitIsDeadOrGhost("target")) then
        return false
    end
    -- The client restricts range checks against friendly targets in combat.
    return (inCombat and not hostile) or C_Item.IsItemInRange(itemID, "target") ~= false
end

local function HideTooltip(action)
    if GameTooltip:IsOwned(action) then
        GameTooltip:Hide()
    end
end

local function CreateItemButton(section, row)
    local marker = CreateFrame("Frame", nil, row)
    marker:SetSize(ITEM_SIZE, ITEM_SIZE)
    marker:SetPoint("TOPRIGHT", row, "TOPRIGHT", -2, 0)
    local border = marker:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0.69, 0.50, 0.21, 0.9)
    local icon = marker:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)

    local button = { marker = marker, icon = icon }
    row.itemButton = button
    section.itemButtons[#section.itemButtons + 1] = button
    return button
end

local function CreateItemAction(button)
    -- Keep both the parent and anchor of the protected action off the tracker.
    local action = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    action:Hide()
    action:RegisterForClicks("LeftButtonUp")
    action:SetAttribute("useOnKeyDown", false)
    action:SetAttribute("type1", "item")
    action:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    -- Swallow clicks at the old position if the tracker moves during lockdown.
    local blocker = CreateFrame("Frame", nil, action)
    blocker:SetAllPoints()
    blocker:EnableMouse(true)
    blocker:Hide()

    button.action, button.blocker = action, blocker
    action:SetScript("OnEnter", function(self)
        if button.item then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetHyperlink(button.item.link)
            GameTooltip:Show()
        end
    end)
    action:SetScript("OnLeave", HideTooltip)
    action:SetScript("OnHide", HideTooltip)
    action:SetScript("PreClick", function(self)
        if not InCombatLockdown() and (not IsCurrentItem(button) or button.boundID ~= button.item.id
            or button.boundQuestID ~= button.questID) then
            self:SetAttribute("item1", nil)
            button.boundID, button.boundQuestID = nil, nil
        end
    end)
    return action
end

function addon.UpdateItemButton(section, row, quest, right, y)
    local button = row.itemButton
    if not quest then
        if button and button.item then
            button.item, button.questID, button.current = nil, nil, nil
            button.marker:Hide()
        end
        return
    end

    local item = quest.item
    button = button or CreateItemButton(section, row)
    if not button.item or button.item.id ~= item.id or button.questID ~= quest.id then
        button.current = nil
        if button.action then
            HideTooltip(button.action)
        end
    end
    button.item, button.questID = item, quest.id
    button.right, button.y = right, y
    button.icon:SetTexture(item.icon)
    button.marker:Show()
end

function addon.UpdateItemButtons(section, elapsed)
    section.itemElapsed = section.itemElapsed + elapsed
    local updateState = section.itemElapsed >= STATE_INTERVAL
    if updateState then
        section.itemElapsed = 0
    end

    local inCombat = InCombatLockdown()
    local view = section.view
    local scale = view:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local parentLeft, parentBottom = UIParent:GetLeft(), UIParent:GetBottom()
    local showActions = parentLeft and parentBottom and section:IsVisible() and section:GetEffectiveAlpha() > 0
        and not section.container:IsCollapsed()
    local viewLeft, viewTop, viewHeight, scroll
    if showActions then
        viewLeft, viewTop, viewHeight, scroll = view:GetLeft(), view:GetTop(), view:GetHeight(), view:GetVerticalScroll()
    end
    local size = ITEM_SIZE * scale
    for _, button in ipairs(section.itemButtons) do
        local action, marker = button.action, button.marker
        local left, top
        if button.item and viewLeft and viewTop and marker:IsVisible() then
            local offset = button.y - scroll
            if offset >= 0 and offset + ITEM_SIZE <= viewHeight then
                left = (viewLeft + button.right - ITEM_SIZE - 2) * scale - parentLeft
                top = (viewTop - offset) * scale - parentBottom
            end
        end
        local aligned = left and action and action:IsShown() and button.left == left and button.top == top
            and button.size == size and button.boundID == button.item.id and button.boundQuestID == button.questID

        if button.item and (updateState or button.current == nil) then
            button.current = IsCurrentItem(button)
            button.usable = button.current and IsUsable(button.item.id, inCombat)
        end

        if inCombat then
            if action then
                local block = action:IsShown() and not (aligned and button.current)
                button.blocker:SetShown(block)
                if block then
                    HideTooltip(action)
                end
            end
        elseif left and button.current then
            if not aligned then
                action = action or CreateItemAction(button)
                action:ClearAllPoints()
                action:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
                action:SetSize(size, size)
                action:SetFrameStrata(marker:GetFrameStrata())
                action:SetFrameLevel(marker:GetFrameLevel() + 2)
                button.blocker:SetFrameLevel(action:GetFrameLevel() + 1)
                action:SetAttribute("item1", "item:" .. button.item.id)
                button.left, button.top, button.size = left, top, size
                button.boundID, button.boundQuestID = button.item.id, button.questID
                action:Show()
                aligned = true
            end
            button.blocker:Hide()
        elseif action then
            action:Hide()
            button.blocker:Hide()
            aligned = false
        end

        if button.item then
            local gray = not (aligned and button.usable)
            if button.gray ~= gray then
                button.gray = gray
                button.icon:SetDesaturated(gray)
                local tint = gray and 0.60 or 1
                button.icon:SetVertexColor(tint, tint, tint)
            end
        end
    end
end
