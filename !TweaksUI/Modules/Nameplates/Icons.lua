-- ============================================================================
-- TweaksUI Nameplates: Icons Module
-- Handles classification icons (elite, rare, boss), raid markers, quest icons
-- ============================================================================

local addonName, TweaksUI = ...
local Nameplates = TweaksUI.Nameplates

-- ============================================================================
-- ICON CREATION
-- ============================================================================

function Nameplates:CreateNameplateIcons(nameplate, data, parent)
    if data.iconsCreated then return end
    
    -- Need a parent to anchor to
    if not parent then return end
    
    -- Create container frame for all icons
    -- Parent to our health bar overlay (parent), NOT Blizzard's nameplate which gets hidden
    local iconContainer = CreateFrame("Frame", nil, parent)
    iconContainer:SetAllPoints(parent)
    iconContainer:SetFrameLevel(parent:GetFrameLevel() + 25)
    
    -- Make completely mouse-transparent
    iconContainer:EnableMouse(false)
    iconContainer:SetHitRectInsets(10000, 10000, 10000, 10000)
    
    data.iconContainer = iconContainer
    
    -- Classification icon (elite dragon, rare star, boss skull)
    local classIcon = iconContainer:CreateTexture(nil, "OVERLAY")
    classIcon:SetSize(16, 16)
    classIcon:Hide()
    data.classificationIcon = classIcon
    
    -- Raid target marker - set base texture like UnitFrames does
    local raidMarker = iconContainer:CreateTexture(nil, "OVERLAY")
    raidMarker:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    raidMarker:SetSize(20, 20)
    raidMarker:Hide()
    data.raidMarkerIcon = raidMarker
    
    -- Quest icon
    local questIcon = iconContainer:CreateTexture(nil, "OVERLAY")
    questIcon:SetSize(16, 16)
    questIcon:SetTexture("Interface\\Tracker\\WorldQuest")
    questIcon:Hide()
    data.questIcon = questIcon
    
    -- Level text
    local levelText = iconContainer:CreateFontString(nil, "OVERLAY")
    levelText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    levelText:Hide()
    data.levelText = levelText
    
    -- PvP marker (flag carrier, orb carrier, etc.)
    local pvpMarker = iconContainer:CreateTexture(nil, "OVERLAY")
    pvpMarker:SetSize(20, 20)
    pvpMarker:Hide()
    data.pvpMarker = pvpMarker
    
    data.iconsCreated = true
end

-- ============================================================================
-- ICON POSITIONING
-- ============================================================================

local function GetAnchorPoints(position, parent)
    if position == "LEFT" then
        return "RIGHT", parent, "LEFT"
    elseif position == "RIGHT" then
        return "LEFT", parent, "RIGHT"
    elseif position == "TOP" then
        return "BOTTOM", parent, "TOP"
    elseif position == "BOTTOM" then
        return "TOP", parent, "BOTTOM"
    end
    return "RIGHT", parent, "LEFT"  -- Default to LEFT
end

function Nameplates:PositionIcon(icon, parent, position, offsetX, offsetY, size)
    if not icon or not parent then return end
    
    -- Wrap in pcall to protect against restricted region measurement errors
    local success, err = pcall(function()
        icon:ClearAllPoints()
        local point, relativeTo, relativePoint = GetAnchorPoints(position, parent)
        icon:SetPoint(point, relativeTo, relativePoint, offsetX or 0, offsetY or 0)
        
        if size and size > 0 then
            icon:SetSize(size, size)
        end
    end)
    
    if not success then
        -- Silently fail - icon will remain hidden or use previous position
        -- This handles "Can't measure restricted regions" errors in Midnight
    end
end

-- ============================================================================
-- ICON UPDATES
-- ============================================================================

function Nameplates:UpdateNameplateIcons(nameplate, data, unit)
    if not nameplate or not data or not unit then 
        return 
    end
    
    local configKey = UnitIsFriend("player", unit) and "friendly" or "enemy"
    
    -- Calculate scale multiplier directly (don't rely on stale data.scaleMultiplier)
    local scaleMultiplier = 1
    local healthConfig = self.State.settings[configKey] and self.State.settings[configKey].healthBar
    
    if healthConfig then
        -- Check if this is target (priority over mouseover)
        -- Use data.isTarget/isMouseover which are set by HealthBars with proper secret handling
        local isTarget = data.isTarget or false
        local isMouseover = data.isMouseover or false
        
        if isTarget then
            local targetScale = healthConfig.targetScale or 110
            if targetScale ~= 100 then
                scaleMultiplier = targetScale / 100
            end
        elseif isMouseover then
            local mouseoverScale = healthConfig.mouseoverScale or 100
            if mouseoverScale ~= 100 then
                scaleMultiplier = mouseoverScale / 100
            end
        end
    end
    
    -- Get a parent for icons - prefer our overlay, fall back to Blizzard's health bar
    local parent = data.overlayHealthBar
    if not parent then
        -- Try to get Blizzard's health bar as fallback
        if nameplate.UnitFrame then
            parent = nameplate.UnitFrame.healthBar or nameplate.UnitFrame.HealthBar
        end
    end
    
    if not parent then
        return
    end
    
    -- Create icons if needed (pass parent for creation)
    if not data.iconsCreated then
        self:CreateNameplateIcons(nameplate, data, parent)
    end
    
    if not data.iconsCreated then
        return
    end
    
    -- Get config
    local config = self.State.settings[configKey] and self.State.settings[configKey].icons
    
    if not config then
        config = self:DeepCopy(self.Defaults.ICONS)
        self.State.settings[configKey].icons = config
    end
    
    -- Update classification icon
    self:UpdateClassificationIcon(data, unit, config, parent, scaleMultiplier, configKey)
    
    -- Update raid marker
    self:UpdateRaidMarkerIcon(data, unit, config, parent, scaleMultiplier, configKey)
    
    -- Update quest icon
    self:UpdateQuestIcon(data, unit, config, parent, scaleMultiplier, configKey)
    
    -- Update level text
    self:UpdateLevelText(data, unit, config, parent, scaleMultiplier, configKey)
    
    -- Update PvP marker
    self:UpdatePvPMarker(data, unit, config, parent, scaleMultiplier, configKey)
end

-- ============================================================================
-- CLASSIFICATION ICON (Elite, Rare, Boss)
-- ============================================================================

-- Use SetRaidTargetIconTexture which handles the texcoords properly
local CLASSIFICATION_INFO = {
    elite = { atlas = "nameplates-icon-elite-gold" },
    rare = { atlas = "nameplates-icon-elite-silver" },
    rareelite = { atlas = "nameplates-icon-elite-silver" },
    worldboss = { atlas = "nameplates-icon-skull" },
    boss = { atlas = "nameplates-icon-skull" },
}

-- Fallback textures with proper sizing
local CLASSIFICATION_TEXTURES_FALLBACK = {
    elite = "Interface\\TargetingFrame\\Nameplates",
    rare = "Interface\\TargetingFrame\\Nameplates",
    rareelite = "Interface\\TargetingFrame\\Nameplates",
    worldboss = "Interface\\TargetingFrame\\Nameplates",
    boss = "Interface\\TargetingFrame\\Nameplates",
}

function Nameplates:UpdateClassificationIcon(data, unit, config, parent, mouseoverScale, configKey)
    local icon = data.classificationIcon
    if not icon then return end
    
    mouseoverScale = mouseoverScale or 1
    
    if not config.classificationEnabled then
        icon:Hide()
        return
    end
    
    -- Get unit classification - may return secret value in Midnight
    local classification = UnitClassification(unit)
    
    -- Can't compare secret values with strings
    if issecretvalue and issecretvalue(classification) then
        icon:Hide()
        return
    end
    
    if classification and classification ~= "normal" and classification ~= "trivial" and classification ~= "minus" then
        local info = CLASSIFICATION_INFO[classification]
        
        if info then
            -- Try to use atlas first (better quality)
            local success = pcall(function()
                icon:SetAtlas(info.atlas, true)  -- true = use atlas size
            end)
            
            if not success then
                -- Fallback to basic texture
                icon:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Elite")
                icon:SetTexCoord(0, 1, 0, 1)
            end
            
            -- Position - use width/height ratio for dragon (roughly 1:1.5)
            -- Apply global scale then mouseover scale
            local baseSize = config.classificationSize or 16
            local size = self:ApplyScale(baseSize, configKey) * mouseoverScale
            local width = size
            local height = size * 1.2  -- Slightly taller for dragon shape
            
            icon:ClearAllPoints()
            local point, relativeTo, relativePoint = GetAnchorPoints(config.classificationPosition, parent)
            local offsetX = self:ApplyScale(config.classificationOffsetX or 0, configKey) * mouseoverScale
            local offsetY = self:ApplyScale(config.classificationOffsetY or 0, configKey) * mouseoverScale
            icon:SetPoint(point, relativeTo, relativePoint, offsetX, offsetY)
            icon:SetSize(width, height)
            
            icon:Show()
        else
            icon:Hide()
        end
    else
        icon:Hide()
    end
end

-- ============================================================================
-- RAID MARKER ICON
-- ============================================================================

function Nameplates:UpdateRaidMarkerIcon(data, unit, config, parent, mouseoverScale, configKey)
    local icon = data.raidMarkerIcon
    if not icon or not parent then return end
    
    mouseoverScale = mouseoverScale or 1
    
    if not config.raidMarkerEnabled then
        icon:Hide()
        return
    end
    
    -- GetRaidTargetIndex may return secret values in Midnight
    local index = GetRaidTargetIndex(unit)
    local indexIsSecret = issecretvalue and issecretvalue(index)
    
    -- Show icon if we have a valid index (secret values are valid for SetRaidTargetIconTexture)
    if index ~= nil or indexIsSecret then
        -- Wrap SetRaidTargetIconTexture in pcall - secret handling may vary
        local success = pcall(SetRaidTargetIconTexture, icon, index)
        if not success then
            icon:Hide()
            return
        end
        
        -- Position with global scale and mouseoverScale
        -- Wrap positioning in pcall to handle restricted region issues
        local baseSize = config.raidMarkerSize or 20
        local size = self:ApplyScale(baseSize, configKey) * mouseoverScale
        local offsetX = self:ApplyScale(config.raidMarkerOffsetX or 0, configKey) * mouseoverScale
        local offsetY = self:ApplyScale(config.raidMarkerOffsetY or 0, configKey) * mouseoverScale
        
        local posSuccess = pcall(function()
            self:PositionIcon(icon, parent, config.raidMarkerPosition, offsetX, offsetY, size)
        end)
        
        if posSuccess then
            icon:Show()
        else
            icon:Hide()
        end
    else
        icon:Hide()
    end
end

-- ============================================================================
-- QUEST ICON
-- ============================================================================

function Nameplates:UpdateQuestIcon(data, unit, config, parent, mouseoverScale, configKey)
    local icon = data.questIcon
    if not icon then return end
    
    mouseoverScale = mouseoverScale or 1
    
    if not config.questEnabled then
        icon:Hide()
        return
    end
    
    -- Check if unit is a quest objective
    local isQuestBoss = UnitIsQuestBoss and UnitIsQuestBoss(unit)
    
    -- Alternative: check widget info for quest progress
    local hasQuestIndicator = false
    if nameplate and nameplate.UnitFrame then
        local uf = nameplate.UnitFrame
        if uf.SoftTargetFrame and uf.SoftTargetFrame:IsShown() then
            hasQuestIndicator = true
        end
    end
    
    if isQuestBoss or hasQuestIndicator then
        icon:SetTexture("Interface\\Tracker\\WorldQuest")
        
        -- Position with global scale and mouseoverScale
        local baseSize = config.questSize or 16
        local size = self:ApplyScale(baseSize, configKey) * mouseoverScale
        local offsetX = self:ApplyScale(config.questOffsetX or 0, configKey) * mouseoverScale
        local offsetY = self:ApplyScale(config.questOffsetY or 0, configKey) * mouseoverScale
        self:PositionIcon(icon, parent, config.questPosition, offsetX, offsetY, size)
        
        icon:Show()
    else
        icon:Hide()
    end
end

-- ============================================================================
-- LEVEL TEXT
-- ============================================================================

function Nameplates:UpdateLevelText(data, unit, config, parent, mouseoverScale, configKey)
    local levelText = data.levelText
    if not levelText or not parent then return end
    
    mouseoverScale = mouseoverScale or 1
    
    if not config.levelEnabled then
        levelText:Hide()
        return
    end
    
    local level = UnitLevel(unit)
    local levelIsSecret = issecretvalue and issecretvalue(level)
    
    -- Handle ?? level (boss/skull)
    -- Can only compare if not a secret value
    if not levelIsSecret and level == -1 then
        levelText:SetText("??")
    elseif level ~= nil or levelIsSecret then
        -- SetText can accept secret values
        levelText:SetText(level or "")
    else
        levelText:Hide()
        return
    end
    
    -- Apply font settings with global scale and mouseoverScale
    local fontPath = self:GetFontPath(config.levelFont or "Friz Quadrata TT")
    local baseFontSize = config.levelFontSize or 10
    local fontSize = self:ApplyScale(baseFontSize, configKey) * mouseoverScale
    levelText:SetFont(fontPath, fontSize, config.levelOutline or "OUTLINE")
    
    -- Color - can use difficulty color or custom
    -- Can't call GetCreatureDifficultyColor with secret values
    if config.levelUseDifficultyColor and not levelIsSecret and level and level ~= -1 then
        local color = GetCreatureDifficultyColor(level)
        if color then
            levelText:SetTextColor(color.r, color.g, color.b)
        else
            local c = config.levelColor or {1, 1, 1, 1}
            levelText:SetTextColor(c[1], c[2], c[3], c[4] or 1)
        end
    else
        local c = config.levelColor or {1, 1, 1, 1}
        levelText:SetTextColor(c[1], c[2], c[3], c[4] or 1)
    end
    
    -- Position with global scale and mouseoverScale
    levelText:ClearAllPoints()
    local point, relativeTo, relativePoint = "RIGHT", parent, "LEFT"
    if config.levelPosition == "RIGHT" then
        point, relativeTo, relativePoint = "LEFT", parent, "RIGHT"
    elseif config.levelPosition == "TOP" then
        point, relativeTo, relativePoint = "BOTTOM", parent, "TOP"
    elseif config.levelPosition == "BOTTOM" then
        point, relativeTo, relativePoint = "TOP", parent, "BOTTOM"
    end
    local offsetX = self:ApplyScale(config.levelOffsetX or 0, configKey) * mouseoverScale
    local offsetY = self:ApplyScale(config.levelOffsetY or 0, configKey) * mouseoverScale
    levelText:SetPoint(point, relativeTo, relativePoint, offsetX, offsetY)
    
    levelText:Show()
end

-- ============================================================================
-- PVP MARKER (Flag carrier, orb carrier, bounty, etc.)
-- ============================================================================

-- Atlas mapping for PvP classifications
local PVP_CLASSIFICATION_ATLAS = Enum.PvPUnitClassification and {
    [Enum.PvPUnitClassification.FlagCarrierHorde] = "nameplates-icon-flag-horde",
    [Enum.PvPUnitClassification.FlagCarrierAlliance] = "nameplates-icon-flag-alliance",
    [Enum.PvPUnitClassification.FlagCarrierNeutral] = "nameplates-icon-flag-neutral",
    [Enum.PvPUnitClassification.CartRunnerHorde] = "nameplates-icon-cart-horde",
    [Enum.PvPUnitClassification.CartRunnerAlliance] = "nameplates-icon-cart-alliance",
    [Enum.PvPUnitClassification.AssassinHorde] = "nameplates-icon-bounty-horde",
    [Enum.PvPUnitClassification.AssassinAlliance] = "nameplates-icon-bounty-alliance",
    [Enum.PvPUnitClassification.OrbCarrierBlue] = "nameplates-icon-orb-blue",
    [Enum.PvPUnitClassification.OrbCarrierGreen] = "nameplates-icon-orb-green",
    [Enum.PvPUnitClassification.OrbCarrierOrange] = "nameplates-icon-orb-orange",
    [Enum.PvPUnitClassification.OrbCarrierPurple] = "nameplates-icon-orb-purple",
} or {}

function Nameplates:UpdatePvPMarker(data, unit, config, parent, mouseoverScale, configKey)
    local marker = data.pvpMarker
    if not marker or not parent then return end
    
    mouseoverScale = mouseoverScale or 1
    
    if not config.pvpMarkerEnabled then
        marker:Hide()
        return
    end
    
    -- Only show in PvP areas
    local isPvPMap = C_PvP and C_PvP.IsPVPMap and C_PvP.IsPVPMap()
    if not isPvPMap then
        marker:Hide()
        return
    end
    
    -- Get PvP classification
    local pvpClassification = UnitPvpClassification and UnitPvpClassification(unit)
    local atlas = pvpClassification and PVP_CLASSIFICATION_ATLAS[pvpClassification]
    
    if atlas then
        marker:SetAtlas(atlas)
        
        -- Position with global scale and mouseoverScale
        local baseSize = config.pvpMarkerSize or 20
        local size = self:ApplyScale(baseSize, configKey) * mouseoverScale
        local offsetX = self:ApplyScale(config.pvpMarkerOffsetX or 0, configKey) * mouseoverScale
        local offsetY = self:ApplyScale(config.pvpMarkerOffsetY or 0, configKey) * mouseoverScale
        self:PositionIcon(marker, parent, config.pvpMarkerPosition, offsetX, offsetY, size)
        
        marker:Show()
    else
        marker:Hide()
    end
end

-- ============================================================================
-- CLEANUP INTEGRATION
-- ============================================================================

-- Icons cleanup is called from CleanupNameplate in Nameplates.lua
function Nameplates:CleanupNameplateIcons(data)
    if data then
        if data.classificationIcon then data.classificationIcon:Hide() end
        if data.raidMarkerIcon then data.raidMarkerIcon:Hide() end
        if data.questIcon then data.questIcon:Hide() end
        if data.levelText then data.levelText:Hide() end
        if data.pvpMarker then data.pvpMarker:Hide() end
    end
end

-- ============================================================================
-- EVENT HANDLING FOR RAID MARKERS
-- ============================================================================

local iconEventFrame = CreateFrame("Frame")
iconEventFrame:RegisterEvent("RAID_TARGET_UPDATE")
iconEventFrame:SetScript("OnEvent", function(self, event)
    if event == "RAID_TARGET_UPDATE" then
        -- Refresh all raid marker icons
        if Nameplates.State.enhancedNameplates then
            for nameplate, data in pairs(Nameplates.State.enhancedNameplates) do
                if data.unit and data.overlayHealthBar then
                    -- Wrap in pcall for safety with secret values
                    pcall(function()
                        local isFriendly = UnitIsFriend("player", data.unit)
                        local configKey = isFriendly and "friendly" or "enemy"
                        local config = Nameplates.State.settings[configKey] and Nameplates.State.settings[configKey].icons
                        if config then
                            Nameplates:UpdateRaidMarkerIcon(data, data.unit, config, data.overlayHealthBar)
                        end
                    end)
                end
            end
        end
    end
end)
