local _, addon = ...

local function ReadBounds(frame, parentScale)
    if not frame:IsVisible() then
        return
    end

    local left, bottom, width, height = frame:GetRect()
    local scale = frame:GetEffectiveScale()
    if not canaccessallvalues(left, bottom, width, height, scale) or not left or not bottom
        or not width or width <= 0 or not height or height <= 0 or not scale or scale <= 0 then
        return
    end
    scale = scale / parentScale
    return {
        left = left * scale,
        bottom = bottom * scale,
        top = (bottom + height) * scale,
        width = width * scale,
        height = height * scale,
        scale = scale,
    }
end

local function Position(frame, left, top, width, height, scale)
    if frame.placedLeft == left and frame.placedTop == top and frame.placedWidth == width
        and frame.placedHeight == height and frame.placedScale == scale then
        return false
    end

    frame:SetScale(scale)
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / scale, top / scale)
    frame:SetSize(width, height)
    frame.placedLeft, frame.placedTop = left, top
    frame.placedWidth, frame.placedHeight, frame.placedScale = width, height, scale
    return true
end

local function RestoreStock(entry, inCombat)
    if entry.shield then
        entry.shield:Hide()
    end
    if entry.alpha ~= nil and not inCombat then
        local alpha = entry.stock:GetAlpha()
        if not issecretvalue(alpha) then
            if alpha == 0 then
                entry.stock:SetAlpha(entry.alpha)
            end
            entry.alpha = nil
        end
    end
end

function addon.HideTracker(section)
    section:Hide()
    local inCombat = InCombatLockdown()
    for _, entry in pairs(section.stockQuests) do
        RestoreStock(entry, inCombat)
    end
end

local function SuppressStock(entry, bounds, rootLeft, rootBottom, inCombat)
    -- The quest module can become protected when it displays a usable item.
    if not inCombat and entry.stockAlpha ~= 0 then
        entry.alpha = entry.stockAlpha
        entry.stock:SetAlpha(0)
    end

    if entry.alpha ~= nil then
        if not entry.shield then
            local shield = CreateFrame("Frame", nil, UIParent)
            shield:SetFrameStrata("MEDIUM")
            shield:SetFrameLevel(5)
            shield:EnableMouse(true)
            entry.shield = shield
        end
        Position(entry.shield, bounds.left - rootLeft, bounds.top - rootBottom,
            bounds.width, bounds.height, 1)
        entry.shield:Show()
    end
end

function addon.PlaceTracker(section)
    local tracker = section.container
    local inCombat = InCombatLockdown()
    if section.fullHeight <= 0 or tracker:IsCollapsed()
        or (EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()) then
        addon.HideTracker(section)
        return
    end

    local rootScale = UIParent:GetEffectiveScale()
    local rootLeft, rootBottom = UIParent:GetLeft(), UIParent:GetBottom()
    local alpha = tracker:GetEffectiveAlpha()
    if not canaccessallvalues(rootScale, rootLeft, rootBottom, alpha) or not rootScale or rootScale <= 0
        or not rootLeft or not rootBottom or alpha == 0 then
        addon.HideTracker(section)
        return
    end
    local trackerBounds = ReadBounds(tracker, rootScale)
    if not trackerBounds then
        addon.HideTracker(section)
        return
    end

    local first
    for stock, entry in pairs(section.stockQuests) do
        local bounds = tracker:HasModule(stock) and ReadBounds(stock, rootScale)
        local alpha = stock:GetAlpha()
        if bounds and not issecretvalue(alpha) and (alpha ~= 0 or entry.alpha ~= nil) then
            -- If Blizzard restores its quest rows during combat, leave them visible until regen.
            if inCombat and alpha ~= 0 then
                addon.HideTracker(section)
                return
            end
            entry.stockAlpha = alpha
            entry.bounds = bounds
            if not first or bounds.top > first.top then
                first = bounds
            end
        else
            entry.bounds = nil
        end
    end
    if not first then
        addon.HideTracker(section)
        return
    end

    -- Use the native quest area without changing the space Blizzard reserves
    -- for its modules. Stop above the next visible nonquest section.
    local bottom = math.max(trackerBounds.bottom, rootBottom)
    tracker:ForEachModule(function(module)
        if not section.stockQuests[module] then
            local bounds = ReadBounds(module, rootScale)
            if bounds and bounds.top < first.top then
                bottom = math.max(bottom, bounds.top + 6 * trackerBounds.scale)
            end
        end
    end)
    local height = math.min(section.fullHeight, (first.top - bottom) / first.scale)
    if height <= 0 then
        addon.HideTracker(section)
        return
    end

    section.contentsHeight = height
    if Position(section, first.left - rootLeft, first.top - rootBottom, section:GetWidth(), height, first.scale) then
        section.viewportDirty = true
    end
    section:Show()
    for _, entry in pairs(section.stockQuests) do
        if entry.bounds then
            SuppressStock(entry, entry.bounds, rootLeft, rootBottom, inCombat)
        else
            RestoreStock(entry, inCombat)
        end
    end
end
