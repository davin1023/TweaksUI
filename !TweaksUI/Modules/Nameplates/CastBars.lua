-- ============================================================================
-- TweaksUI Nameplates: Cast Bars Module
-- Handles cast bar display on nameplates with Midnight API support
-- ============================================================================

local addonName, TweaksUI = ...
local Nameplates = TweaksUI.Nameplates

-- ============================================================================
-- MIDNIGHT API WRAPPERS (v2.0.0)
-- ============================================================================

local SpellAPI = TweaksUI.SpellAPI
local DurationAPI = TweaksUI.DurationAPI
local StatusBarAPI = TweaksUI.StatusBarAPI

-- ============================================================================
-- LOCALIZED GLOBALS (Performance Optimization v1.9.0)
-- ============================================================================

-- Lua
local pairs = pairs
local ipairs = ipairs
local type = type
local select = select
local pcall = pcall

-- WoW API
local GetTime = GetTime
local CreateFrame = CreateFrame
local C_Timer = C_Timer
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
local UnitIsFriend = UnitIsFriend
local UnitExists = UnitExists
local C_NamePlate = C_NamePlate
local hooksecurefunc = hooksecurefunc

-- ============================================================================
-- EMPOWERED CAST BAR HELPERS
-- ============================================================================

local MAX_EMPOWER_STAGES = 6
local HAS_EMPOWER_STAGE_PERCENTAGES = (UnitEmpoweredStagePercentages ~= nil)

-- Safe number extraction for Midnight secret values
local function SafeNumber(value)
    if value == nil then return nil end
    if type(value) == "number" then return value end
    local ok, num = pcall(function() return tonumber(value) end)
    if ok and num then return num end
    return nil
end

-- Check if a unit is currently casting an empowered spell
local function IsEmpoweredCast(unit)
    if not unit then return false end
    
    -- Method 1: Check UnitEmpoweredStagePercentages - if it returns data, it's empowered
    if HAS_EMPOWER_STAGE_PERCENTAGES then
        local success, percentages = pcall(function()
            return UnitEmpoweredStagePercentages(unit, true)
        end)
        if success and percentages and type(percentages) == "table" and #percentages > 1 then
            return true
        end
    end
    
    -- Method 2: Check UnitChannelInfo isEmpowered flag (position 9)
    local success, results = pcall(function()
        return {UnitChannelInfo(unit)}
    end)
    if success and results then
        local isEmpoweredFlag = results[9]
        if isEmpoweredFlag then
            local ok, val = pcall(function() return isEmpoweredFlag and true or false end)
            if ok and val then
                return true
            end
        end
    end
    
    return false
end

-- Get the number of empower stages
local function GetEmpowerNumStages(unit)
    if not unit then return nil end
    
    local numStages = nil
    
    -- Method 1: Try UnitEmpoweredStagePercentages first (most reliable)
    if HAS_EMPOWER_STAGE_PERCENTAGES then
        local success, percentages = pcall(function()
            return UnitEmpoweredStagePercentages(unit, true)
        end)
        
        if success and percentages and type(percentages) == "table" and #percentages > 1 then
            local count = #percentages - 1
            if count >= 2 and count <= MAX_EMPOWER_STAGES then
                numStages = count
            end
        end
    end
    
    -- Method 2: Try to get from UnitChannelInfo (position 10)
    if not numStages then
        local success, results = pcall(function()
            return {UnitChannelInfo(unit)}
        end)
        
        if success and results and #results >= 10 then
            local apiStages = results[10]
            if apiStages then
                local safeStages = SafeNumber(apiStages)
                if safeStages and type(safeStages) == "number" and safeStages >= 2 and safeStages <= MAX_EMPOWER_STAGES then
                    numStages = safeStages
                end
            end
        end
    end
    
    return numStages
end

-- Get stage percentages for empowered spells (cumulative positions 0-1)
local function GetEmpowerStagePositions(numStages, unit)
    if HAS_EMPOWER_STAGE_PERCENTAGES and unit then
        local success, percentages = pcall(function()
            return UnitEmpoweredStagePercentages(unit, true)
        end)
        
        if success and percentages and type(percentages) == "table" and #percentages >= numStages then
            local positions = {}
            local cumulative = 0
            for i = 1, numStages do
                cumulative = cumulative + (percentages[i] or 0)
                positions[i] = cumulative
            end
            return positions
        end
    end
    
    -- Hardcoded fallback positions
    if numStages == 6 then
        return {0.10, 0.22, 0.34, 0.46, 0.58, 0.70}
    elseif numStages == 5 then
        return {0.12, 0.26, 0.40, 0.54, 0.68}
    elseif numStages == 4 then
        return {0.15, 0.32, 0.49, 0.66}
    elseif numStages == 3 then
        return {0.20, 0.40, 0.60}
    elseif numStages == 2 then
        return {0.30, 0.60}
    else
        local positions = {}
        local usableRange = 0.70
        for i = 1, numStages do
            positions[i] = (i / numStages) * usableRange
        end
        return positions
    end
end

-- Setup empowered stage dividers on a nameplate cast bar
local function SetupEmpowerDividers(castBar, unit, numStages)
    if not castBar or not numStages or numStages <= 1 then
        if castBar and castBar.stageDividers then
            for i = 1, MAX_EMPOWER_STAGES do
                if castBar.stageDividers[i] then
                    castBar.stageDividers[i]:Hide()
                end
            end
        end
        return
    end
    
    -- Create dividers if needed
    local statusBar = castBar.statusBar or castBar
    if not castBar.stageDividers then
        castBar.stageDividers = {}
        for i = 1, MAX_EMPOWER_STAGES do
            local divider = statusBar:CreateTexture(nil, "OVERLAY", nil, 7)
            divider:SetColorTexture(1, 1, 1, 0.8)
            divider:Hide()
            castBar.stageDividers[i] = divider
        end
    end
    
    -- Hide all dividers first
    for i = 1, MAX_EMPOWER_STAGES do
        if castBar.stageDividers[i] then
            castBar.stageDividers[i]:Hide()
        end
    end
    
    local positions = GetEmpowerStagePositions(numStages, unit)
    if not positions or #positions == 0 then return end
    
    local barWidth = statusBar:GetWidth()
    local barHeight = statusBar:GetHeight()
    if barWidth <= 0 then barWidth = 100 end
    if barHeight <= 0 then barHeight = 10 end
    
    for i = 1, numStages do
        local divider = castBar.stageDividers[i]
        if divider and positions[i] then
            local xPos = positions[i] * barWidth
            divider:ClearAllPoints()
            divider:SetPoint("CENTER", statusBar, "LEFT", xPos, 0)
            divider:SetSize(2, barHeight)
            divider:SetColorTexture(1, 1, 1, 0.8)
            divider:Show()
        end
    end
end

-- Hide empowered dividers
local function HideEmpowerDividers(castBar)
    if castBar and castBar.stageDividers then
        for i = 1, MAX_EMPOWER_STAGES do
            if castBar.stageDividers[i] then
                castBar.stageDividers[i]:Hide()
            end
        end
    end
end

-- ============================================================================
-- DEFAULTS
-- ============================================================================

Nameplates.Defaults.CAST_BAR = {
    enabled = true,
    
    -- Size & Position
    width = 0,  -- 0 = match health bar width
    height = 10,
    yOffset = -2,
    xOffset = 0,
    
    -- Textures
    texture = "Blizzard",
    
    -- Icon
    iconEnabled = true,
    iconSize = 0,  -- 0 = match cast bar height
    iconPosition = "LEFT",  -- "LEFT", "RIGHT"
    iconOffset = -2,
    iconBorderEnabled = true,
    iconBorderColor = { 0, 0, 0, 1 },
    
    -- Spell Name Text
    spellNameEnabled = true,
    spellNameFont = "Friz Quadrata TT",
    spellNameFontSize = 9,
    spellNameOutline = "OUTLINE",
    spellNamePosition = "TOP",  -- "TOP", "LEFT", "CENTER", "RIGHT"
    spellNameOffsetX = 0,
    spellNameOffsetY = 2,
    spellNameColor = { 1, 1, 1, 1 },
    
    -- Cast Target Text (who the spell is targeting)
    castTargetEnabled = false,
    castTargetFont = "Friz Quadrata TT",
    castTargetFontSize = 8,
    castTargetOutline = "OUTLINE",
    castTargetPosition = "BOTTOM",
    castTargetOffsetX = 0,
    castTargetOffsetY = -2,
    castTargetColor = { 1, 0.8, 0.8, 1 },
    castTargetUseClassColor = true,
    
    -- Timer Text
    timerEnabled = true,
    timerFont = "Friz Quadrata TT",
    timerFontSize = 9,
    timerOutline = "OUTLINE",
    timerPosition = "RIGHT",
    timerOffsetX = -2,
    timerOffsetY = 0,
    timerColor = { 1, 1, 1, 1 },
    timerShowDecimals = true,
    
    -- Colors
    castingColor = { 1, 0.7, 0, 1 },          -- Normal cast (orange/yellow)
    channelingColor = { 0, 0.7, 1, 1 },       -- Channeled spell (blue)
    nonInterruptibleColor = { 0.5, 0.5, 0.5, 1 },  -- Cannot interrupt (grey)
    interruptedColor = { 1, 0, 0, 1 },        -- Was interrupted (red)
    importantCastColor = { 1, 0, 0.5, 1 },    -- Important cast (magenta/pink)
    importantChannelColor = { 0.5, 0, 1, 1 }, -- Important channel (purple)
    
    -- Background & Border
    bgEnabled = true,
    bgColor = { 0.1, 0.1, 0.1, 0.8 },
    borderEnabled = true,
    borderColor = { 0, 0, 0, 1 },
    borderSize = 1,
    
    -- Spark/edge marker
    sparkEnabled = true,
    sparkWidth = 12,
    sparkColor = { 1, 1, 1, 0.8 },
}

Nameplates.Defaults.FRIENDLY_CAST_BAR = {
    enabled = false,  -- Disabled by default for friendlies
    
    -- Copy all settings from enemy cast bar
    width = 0,
    height = 10,
    yOffset = -2,
    xOffset = 0,
    texture = "Blizzard",
    iconEnabled = true,
    iconSize = 0,
    iconPosition = "LEFT",
    iconOffset = -2,
    iconBorderEnabled = true,
    iconBorderColor = { 0, 0, 0, 1 },
    spellNameEnabled = true,
    spellNameFont = "Friz Quadrata TT",
    spellNameFontSize = 9,
    spellNameOutline = "OUTLINE",
    spellNamePosition = "TOP",
    spellNameOffsetX = 0,
    spellNameOffsetY = 2,
    spellNameColor = { 1, 1, 1, 1 },
    castTargetEnabled = false,
    castTargetFont = "Friz Quadrata TT",
    castTargetFontSize = 8,
    castTargetOutline = "OUTLINE",
    castTargetPosition = "BOTTOM",
    castTargetOffsetX = 0,
    castTargetOffsetY = -2,
    castTargetColor = { 1, 0.8, 0.8, 1 },
    castTargetUseClassColor = true,
    timerEnabled = true,
    timerFont = "Friz Quadrata TT",
    timerFontSize = 9,
    timerOutline = "OUTLINE",
    timerPosition = "RIGHT",
    timerOffsetX = -2,
    timerOffsetY = 0,
    timerColor = { 1, 1, 1, 1 },
    timerShowDecimals = true,
    castingColor = { 0, 0.8, 0, 1 },          -- Green for friendly casts
    channelingColor = { 0, 0.7, 1, 1 },
    nonInterruptibleColor = { 0.5, 0.5, 0.5, 1 },
    interruptedColor = { 1, 0, 0, 1 },
    importantCastColor = { 0, 1, 0.5, 1 },
    importantChannelColor = { 0, 0.5, 1, 1 },
    bgEnabled = true,
    bgColor = { 0.1, 0.1, 0.1, 0.8 },
    borderEnabled = true,
    borderColor = { 0, 0, 0, 1 },
    borderSize = 1,
    sparkEnabled = true,
    sparkWidth = 12,
    sparkColor = { 1, 1, 1, 0.8 },
}

-- ============================================================================
-- CAST BAR CREATION
-- ============================================================================

function Nameplates:CreateCastBar(nameplate, data)
    if data.castBar then return data.castBar end
    
    -- Create main cast bar frame
    local castBar = CreateFrame("Frame", nil, nameplate)
    castBar:SetFrameLevel(10)
    
    -- Make completely mouse-transparent
    castBar:EnableMouse(false)
    castBar:SetHitRectInsets(10000, 10000, 10000, 10000)
    
    -- Store references for event handling
    castBar.nameplate = nameplate
    castBar.data = data
    
    -- Status bar for the cast progress
    local statusBar = CreateFrame("StatusBar", nil, castBar)
    statusBar:SetAllPoints()
    statusBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    statusBar:SetMinMaxValues(0, 1)
    statusBar:SetValue(0)
    statusBar:EnableMouse(false)
    statusBar:SetHitRectInsets(10000, 10000, 10000, 10000)
    castBar.statusBar = statusBar
    
    -- Background
    local bg = castBar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetVertexColor(0.1, 0.1, 0.1, 0.8)
    castBar.bg = bg
    
    -- Border using edge textures (same pattern as health bar)
    castBar.borderEdges = {}
    for i = 1, 4 do
        local edge = castBar:CreateTexture(nil, "BORDER")
        edge:SetTexture("Interface\\Buttons\\WHITE8X8")
        edge:SetVertexColor(0, 0, 0, 1)
        edge:Hide()
        castBar.borderEdges[i] = edge
    end
    
    -- Spark/marker
    local spark = statusBar:CreateTexture(nil, "OVERLAY")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    spark:SetBlendMode("ADD")
    spark:SetSize(12, 24)
    spark:SetPoint("CENTER", statusBar:GetStatusBarTexture(), "RIGHT", 0, 0)
    castBar.spark = spark
    
    -- Icon frame
    local iconFrame = CreateFrame("Frame", nil, castBar)
    iconFrame:SetSize(16, 16)
    iconFrame:EnableMouse(false)
    iconFrame:SetHitRectInsets(10000, 10000, 10000, 10000)
    castBar.iconFrame = iconFrame
    
    local iconTexture = iconFrame:CreateTexture(nil, "ARTWORK")
    iconTexture:SetAllPoints()
    iconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    castBar.iconTexture = iconTexture
    
    -- Icon border (simple edge textures)
    iconFrame.borderEdges = {}
    for i = 1, 4 do
        local edge = iconFrame:CreateTexture(nil, "OVERLAY")
        edge:SetTexture("Interface\\Buttons\\WHITE8X8")
        edge:SetVertexColor(0, 0, 0, 1)
        iconFrame.borderEdges[i] = edge
    end
    
    -- Spell name text - create on statusBar with high sublayer to be above the bar texture
    local spellName = statusBar:CreateFontString(nil, "OVERLAY", nil, 7)
    spellName:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    castBar.spellName = spellName
    
    -- Timer text - also on statusBar with high sublayer
    local timer = statusBar:CreateFontString(nil, "OVERLAY", nil, 7)
    timer:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    castBar.timer = timer
    
    -- Cast target text (who the spell is targeting) - on separate high frame for visibility
    local castTargetFrame = CreateFrame("Frame", nil, castBar)
    castTargetFrame:SetAllPoints(castBar)
    castTargetFrame:SetFrameStrata("TOOLTIP")  -- Very high strata
    castTargetFrame:SetFrameLevel(100)
    castTargetFrame:EnableMouse(false)
    castTargetFrame:SetHitRectInsets(10000, 10000, 10000, 10000)
    local castTarget = castTargetFrame:CreateFontString(nil, "OVERLAY", nil, 7)
    castTarget:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    castBar.castTargetFrame = castTargetFrame
    castBar.castTarget = castTarget
    
    -- State tracking
    castBar.isCasting = false
    castBar.isChanneling = false
    castBar.isInterrupted = false
    castBar.notInterruptible = false
    castBar.unit = nil
    
    -- Hide by default
    castBar:Hide()
    
    data.castBar = castBar
    return castBar
end

-- ============================================================================
-- CAST BAR POSITIONING
-- ============================================================================

function Nameplates:PositionCastBar(castBar, healthBar, config, configKey)
    if not castBar or not healthBar or not config then return end
    
    -- Store configKey on castBar for later use
    castBar.configKey = configKey
    
    -- Get data reference for currentWidth and scale state
    local data = castBar.data
    
    -- Get scale multiplier from data (set by health bar module - includes target or mouseover scale)
    local scaleMultiplier = (data and data.scaleMultiplier) or 1
    
    -- Determine size
    local width = config.width
    if not width or width == 0 then
        -- Match health bar width - try multiple sources in order of preference
        local foundWidth = nil
        
        -- Source 1: data.currentWidth (set by health bar module, already scaled, includes target/mouseover sizing)
        if data and data.currentWidth and data.currentWidth > 0 then
            foundWidth = data.currentWidth
        end
        
        -- Source 2: Get width from the overlayHealthBar directly (this IS our health bar)
        if not foundWidth and data and data.overlayHealthBar then
            local success, overlayWidth = pcall(function() return data.overlayHealthBar:GetWidth() end)
            if success and overlayWidth and type(overlayWidth) == "number" and overlayWidth > 0 then
                foundWidth = overlayWidth
            end
        end
        
        -- Source 3: Get width from the passed healthBar parameter
        if not foundWidth and healthBar and healthBar.GetWidth then
            local success, barWidth = pcall(function() return healthBar:GetWidth() end)
            if success and barWidth and type(barWidth) == "number" and barWidth > 0 then
                foundWidth = barWidth
            end
        end
        
        -- Source 4: Calculate from config with scaling
        if not foundWidth then
            local healthConfig = self.State.settings[configKey] and self.State.settings[configKey].healthBar
            if healthConfig then
                local baseWidth = healthConfig.width or 140
                foundWidth = self:ApplyScale(baseWidth, configKey) * scaleMultiplier
            else
                foundWidth = self:ApplyScale(140, configKey) * scaleMultiplier
            end
        end
        
        width = foundWidth
    else
        -- User specified width, apply scale
        width = self:ApplyScale(width, configKey) * scaleMultiplier
    end
    
    -- Sanity check - ensure we have a reasonable width
    if not width or width <= 0 then
        width = self:ApplyScale(140, configKey) * scaleMultiplier
    end
    
    -- Height also gets scale multiplier
    local height = self:ApplyScale(config.height or 10, configKey) * scaleMultiplier
    
    -- Position relative to health bar
    local xOffset = self:ApplyScale(config.xOffset or 0, configKey) * scaleMultiplier
    local yOffset = self:ApplyScale(config.yOffset or -2, configKey) * scaleMultiplier
    
    castBar:ClearAllPoints()
    castBar:SetPoint("TOP", healthBar, "BOTTOM", xOffset, yOffset)
    castBar:SetSize(width, height)
    
    -- Position icon
    if config.iconEnabled then
        local iconSize = config.iconSize
        if not iconSize or iconSize == 0 then
            -- Match cast bar height - use unscaled config value
            iconSize = config.height or 10
        end
        iconSize = self:ApplyScale(iconSize, configKey) * scaleMultiplier
        
        castBar.iconFrame:SetSize(iconSize, iconSize)
        castBar.iconFrame:ClearAllPoints()
        
        local iconOffset = self:ApplyScale(config.iconOffset or -2, configKey) * scaleMultiplier
        if config.iconPosition == "LEFT" then
            castBar.iconFrame:SetPoint("RIGHT", castBar, "LEFT", iconOffset, 0)
        else
            castBar.iconFrame:SetPoint("LEFT", castBar, "RIGHT", -iconOffset, 0)
        end
        
        -- Icon border
        if config.iconBorderEnabled then
            local borderSize = 1
            local bc = config.iconBorderColor or {0, 0, 0, 1}
            local edges = castBar.iconFrame.borderEdges
            
            -- Top
            edges[1]:ClearAllPoints()
            edges[1]:SetPoint("BOTTOMLEFT", castBar.iconFrame, "TOPLEFT", -borderSize, 0)
            edges[1]:SetPoint("BOTTOMRIGHT", castBar.iconFrame, "TOPRIGHT", borderSize, 0)
            edges[1]:SetHeight(borderSize)
            edges[1]:SetVertexColor(bc[1], bc[2], bc[3], bc[4] or 1)
            edges[1]:Show()
            
            -- Bottom
            edges[2]:ClearAllPoints()
            edges[2]:SetPoint("TOPLEFT", castBar.iconFrame, "BOTTOMLEFT", -borderSize, 0)
            edges[2]:SetPoint("TOPRIGHT", castBar.iconFrame, "BOTTOMRIGHT", borderSize, 0)
            edges[2]:SetHeight(borderSize)
            edges[2]:SetVertexColor(bc[1], bc[2], bc[3], bc[4] or 1)
            edges[2]:Show()
            
            -- Left
            edges[3]:ClearAllPoints()
            edges[3]:SetPoint("TOPRIGHT", castBar.iconFrame, "TOPLEFT", 0, 0)
            edges[3]:SetPoint("BOTTOMRIGHT", castBar.iconFrame, "BOTTOMLEFT", 0, 0)
            edges[3]:SetWidth(borderSize)
            edges[3]:SetVertexColor(bc[1], bc[2], bc[3], bc[4] or 1)
            edges[3]:Show()
            
            -- Right
            edges[4]:ClearAllPoints()
            edges[4]:SetPoint("TOPLEFT", castBar.iconFrame, "TOPRIGHT", 0, 0)
            edges[4]:SetPoint("BOTTOMLEFT", castBar.iconFrame, "BOTTOMRIGHT", 0, 0)
            edges[4]:SetWidth(borderSize)
            edges[4]:SetVertexColor(bc[1], bc[2], bc[3], bc[4] or 1)
            edges[4]:Show()
        else
            for i = 1, 4 do
                castBar.iconFrame.borderEdges[i]:Hide()
            end
        end
        
        castBar.iconFrame:Show()
    else
        castBar.iconFrame:Hide()
    end
    
    -- Position spell name
    if config.spellNameEnabled then
        local fontPath = self:GetFontPath(config.spellNameFont)
        local fontSize = self:ApplyScale(config.spellNameFontSize or 9, configKey)
        local outline = config.spellNameOutline == "THICK" and "THICKOUTLINE" or 
                        (config.spellNameOutline == "NONE" and "" or "OUTLINE")
        castBar.spellName:SetFont(fontPath, fontSize, outline)
        
        local c = config.spellNameColor or {1, 1, 1, 1}
        castBar.spellName:SetTextColor(c[1], c[2], c[3], c[4] or 1)
        
        castBar.spellName:ClearAllPoints()
        local offsetX = self:ApplyScale(config.spellNameOffsetX or 0, configKey)
        local offsetY = self:ApplyScale(config.spellNameOffsetY or 2, configKey)
        
        if config.spellNamePosition == "TOP" then
            castBar.spellName:SetPoint("BOTTOM", castBar, "TOP", offsetX, offsetY)
            castBar.spellName:SetJustifyH("CENTER")
        elseif config.spellNamePosition == "LEFT" then
            castBar.spellName:SetPoint("LEFT", castBar, "LEFT", offsetX, offsetY)
            castBar.spellName:SetJustifyH("LEFT")
        elseif config.spellNamePosition == "RIGHT" then
            castBar.spellName:SetPoint("RIGHT", castBar, "RIGHT", -offsetX, offsetY)
            castBar.spellName:SetJustifyH("RIGHT")
        else
            castBar.spellName:SetPoint("CENTER", castBar, "CENTER", offsetX, offsetY)
            castBar.spellName:SetJustifyH("CENTER")
        end
        
        castBar.spellName:Show()
    else
        castBar.spellName:Hide()
    end
    
    -- Position timer
    if config.timerEnabled then
        local fontPath = self:GetFontPath(config.timerFont)
        local fontSize = self:ApplyScale(config.timerFontSize or 9, configKey)
        local outline = config.timerOutline == "THICK" and "THICKOUTLINE" or 
                        (config.timerOutline == "NONE" and "" or "OUTLINE")
        castBar.timer:SetFont(fontPath, fontSize, outline)
        
        local c = config.timerColor or {1, 1, 1, 1}
        castBar.timer:SetTextColor(c[1], c[2], c[3], c[4] or 1)
        
        castBar.timer:ClearAllPoints()
        local offsetX = self:ApplyScale(config.timerOffsetX or -2, configKey)
        local offsetY = self:ApplyScale(config.timerOffsetY or 0, configKey)
        
        if config.timerPosition == "LEFT" then
            castBar.timer:SetPoint("LEFT", castBar, "LEFT", -offsetX, offsetY)
            castBar.timer:SetJustifyH("LEFT")
        elseif config.timerPosition == "RIGHT" then
            castBar.timer:SetPoint("RIGHT", castBar, "RIGHT", offsetX, offsetY)
            castBar.timer:SetJustifyH("RIGHT")
        else
            castBar.timer:SetPoint("CENTER", castBar, "CENTER", offsetX, offsetY)
            castBar.timer:SetJustifyH("CENTER")
        end
        
        castBar.timer:Show()
    else
        castBar.timer:Hide()
    end
    
    -- Cast Target Text (who the spell is targeting)
    if config.castTargetEnabled and castBar.castTarget then
        local fontPath = self:GetFontPath(config.castTargetFont)
        local fontSize = self:ApplyScale(config.castTargetFontSize or 8, configKey)
        castBar.castTarget:SetFont(fontPath, fontSize, config.castTargetOutline or "OUTLINE")
        
        local tc = config.castTargetColor or {1, 0.8, 0.8, 1}
        castBar.castTarget:SetTextColor(tc[1], tc[2], tc[3], tc[4] or 1)
        
        castBar.castTarget:ClearAllPoints()
        local offsetX = self:ApplyScale(config.castTargetOffsetX or 0, configKey)
        local offsetY = self:ApplyScale(config.castTargetOffsetY or -2, configKey)
        
        if config.castTargetPosition == "TOP" then
            castBar.castTarget:SetPoint("BOTTOM", castBar, "TOP", offsetX, offsetY)
        elseif config.castTargetPosition == "BOTTOM" then
            castBar.castTarget:SetPoint("TOP", castBar, "BOTTOM", offsetX, offsetY)
        elseif config.castTargetPosition == "LEFT" then
            castBar.castTarget:SetPoint("RIGHT", castBar, "LEFT", offsetX, offsetY)
        elseif config.castTargetPosition == "RIGHT" then
            castBar.castTarget:SetPoint("LEFT", castBar, "RIGHT", offsetX, offsetY)
        else
            castBar.castTarget:SetPoint("TOP", castBar, "BOTTOM", offsetX, offsetY)
        end
        
        castBar.castTarget:SetJustifyH("CENTER")
        -- Store config for class color option
        castBar.castTargetUseClassColor = config.castTargetUseClassColor
        castBar.castTargetDefaultColor = tc
        
        -- Show the frame container
        if castBar.castTargetFrame then
            castBar.castTargetFrame:Show()
        end
        castBar.castTarget:Show()
    else
        if castBar.castTarget then
            castBar.castTarget:Hide()
        end
        if castBar.castTargetFrame then
            castBar.castTargetFrame:Hide()
        end
    end
    
    -- Spark
    if config.sparkEnabled then
        local sparkWidth = self:ApplyScale(config.sparkWidth or 12, configKey)
        castBar.spark:SetSize(sparkWidth, height * 2.4)
        local sc = config.sparkColor or {1, 1, 1, 0.8}
        castBar.spark:SetVertexColor(sc[1], sc[2], sc[3], sc[4] or 0.8)
        castBar.spark:Show()
    else
        castBar.spark:Hide()
    end
    
    -- Background
    if config.bgEnabled then
        local bgc = config.bgColor or {0.1, 0.1, 0.1, 0.8}
        castBar.bg:SetVertexColor(bgc[1], bgc[2], bgc[3], bgc[4] or 0.8)
        castBar.bg:Show()
    else
        castBar.bg:Hide()
    end
    
    -- Border
    if config.borderEnabled then
        local borderSize = config.borderSize or 1
        local bc = config.borderColor or {0, 0, 0, 1}
        local edges = castBar.borderEdges
        
        -- Top
        edges[1]:ClearAllPoints()
        edges[1]:SetPoint("BOTTOMLEFT", castBar, "TOPLEFT", -borderSize, 0)
        edges[1]:SetPoint("BOTTOMRIGHT", castBar, "TOPRIGHT", borderSize, 0)
        edges[1]:SetHeight(borderSize)
        edges[1]:SetVertexColor(bc[1], bc[2], bc[3], bc[4] or 1)
        edges[1]:Show()
        
        -- Bottom
        edges[2]:ClearAllPoints()
        edges[2]:SetPoint("TOPLEFT", castBar, "BOTTOMLEFT", -borderSize, 0)
        edges[2]:SetPoint("TOPRIGHT", castBar, "BOTTOMRIGHT", borderSize, 0)
        edges[2]:SetHeight(borderSize)
        edges[2]:SetVertexColor(bc[1], bc[2], bc[3], bc[4] or 1)
        edges[2]:Show()
        
        -- Left
        edges[3]:ClearAllPoints()
        edges[3]:SetPoint("TOPRIGHT", castBar, "TOPLEFT", 0, 0)
        edges[3]:SetPoint("BOTTOMRIGHT", castBar, "BOTTOMLEFT", 0, 0)
        edges[3]:SetWidth(borderSize)
        edges[3]:SetVertexColor(bc[1], bc[2], bc[3], bc[4] or 1)
        edges[3]:Show()
        
        -- Right
        edges[4]:ClearAllPoints()
        edges[4]:SetPoint("TOPLEFT", castBar, "TOPRIGHT", 0, 0)
        edges[4]:SetPoint("BOTTOMLEFT", castBar, "BOTTOMRIGHT", 0, 0)
        edges[4]:SetWidth(borderSize)
        edges[4]:SetVertexColor(bc[1], bc[2], bc[3], bc[4] or 1)
        edges[4]:Show()
    else
        for i = 1, 4 do
            castBar.borderEdges[i]:Hide()
        end
    end
    
    -- Texture
    local texturePath = self:GetTexturePath(config.texture)
    castBar.statusBar:SetStatusBarTexture(texturePath)
    
    -- Apply effective alpha from health bar settings (target vs non-target)
    if data and data.effectiveAlpha then
        castBar:SetAlpha(data.effectiveAlpha)
    else
        castBar:SetAlpha(1.0)
    end
end

-- ============================================================================
-- CAST BAR COLORS
-- ============================================================================

-- Apply color - non-secret version (for simulation preview and fallback)
function Nameplates:ApplyCastBarColor(castBar, config, isChanneling, isImportant, notInterruptible)
    local r, g, b, a
    
    -- Determine base color - notInterruptible here is guaranteed to be a boolean, not secret
    if notInterruptible == true then
        -- Non-interruptible always uses the non-interruptible color
        local c = config.nonInterruptibleColor or {0.5, 0.5, 0.5, 1}
        r, g, b, a = c[1], c[2], c[3], c[4] or 1
    elseif isImportant == true then
        -- Important spell
        if isChanneling then
            local c = config.importantChannelColor or {0.5, 0, 1, 1}
            r, g, b, a = c[1], c[2], c[3], c[4] or 1
        else
            local c = config.importantCastColor or {1, 0, 0.5, 1}
            r, g, b, a = c[1], c[2], c[3], c[4] or 1
        end
    else
        -- Normal spell
        if isChanneling then
            local c = config.channelingColor or {0, 0.7, 1, 1}
            r, g, b, a = c[1], c[2], c[3], c[4] or 1
        else
            local c = config.castingColor or {1, 0.7, 0, 1}
            r, g, b, a = c[1], c[2], c[3], c[4] or 1
        end
    end
    
    castBar.statusBar:SetStatusBarColor(r, g, b, a)
end

-- Apply color using secret-safe API for Midnight Beta
function Nameplates:ApplyCastBarColorWithSecrets(castBar, config, isChanneling, spellID, notInterruptible)
    -- Check if we're dealing with secret values
    local isSecretNotInterruptible = issecretvalue and issecretvalue(notInterruptible)
    
    if isSecretNotInterruptible then
        -- Midnight Beta path - use secret-safe color APIs
        -- We need to use SetStatusBarColorFromBoolean or SetVertexColorFromBoolean
        
        local normalColor, nonInterruptColor
        
        if isChanneling then
            normalColor = CreateColor(unpack(config.channelingColor or {0, 0.7, 1, 1}))
        else
            normalColor = CreateColor(unpack(config.castingColor or {1, 0.7, 0, 1}))
        end
        nonInterruptColor = CreateColor(unpack(config.nonInterruptibleColor or {0.5, 0.5, 0.5, 1}))
        
        -- Use secret-safe color switching based on notInterruptible
        local tex = castBar.statusBar:GetStatusBarTexture()
        if tex and tex.SetVertexColorFromBoolean then
            -- notInterruptible = true means use nonInterruptColor
            tex:SetVertexColorFromBoolean(notInterruptible, nonInterruptColor, normalColor)
        else
            -- Fallback - just use normal color since we can't determine
            castBar.statusBar:SetStatusBarColor(normalColor:GetRGBA())
        end
    else
        -- Non-secret path - we can do normal boolean tests
        local isImportant = false
        if SpellAPI and spellID then
            isImportant = SpellAPI:IsImportant(spellID)
        end
        
        -- Convert notInterruptible to safe boolean
        local safeNotInterruptible = (notInterruptible == true)
        
        self:ApplyCastBarColor(castBar, config, isChanneling, isImportant, safeNotInterruptible)
    end
end

-- ============================================================================
-- CAST BAR UPDATE
-- ============================================================================

function Nameplates:UpdateCastBar(castBar, unit, config, configKey)
    if not castBar or not unit or not config then return end
    if not config.enabled then
        castBar:Hide()
        return
    end
    
    -- Get cast info
    local name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible, spellID = UnitCastingInfo(unit)
    local isChanneling = false
    local isEmpowered = false
    local numEmpowerStages = nil
    
    if not name then
        -- Midnight API: UnitChannelInfo returns isEmpowered and numEmpowerStages as additional fields
        name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID, _, _, _, isEmpowered, numEmpowerStages = UnitChannelInfo(unit)
        isChanneling = true
    end
    
    if not name then
        -- Not casting anything
        if not castBar.isInterrupted then
            castBar:Hide()
        end
        castBar.isCasting = false
        castBar.isChanneling = false
        castBar.isEmpowered = false
        HideEmpowerDividers(castBar)  -- Hide stage dividers when cast ends
        return
    end
    
    -- Clear interrupted state
    castBar.isInterrupted = false
    castBar.isCasting = not isChanneling
    castBar.isChanneling = isChanneling
    castBar.isEmpowered = isEmpowered
    castBar.notInterruptible = notInterruptible
    
    -- Setup empowered stage dividers if this is an empowered cast
    if isEmpowered and numEmpowerStages then
        local safeStages = numEmpowerStages
        if issecretvalue and issecretvalue(numEmpowerStages) then
            safeStages = 3  -- Default fallback for secret value
        end
        if type(safeStages) == "number" and safeStages > 1 then
            SetupEmpowerDividers(castBar, unit, safeStages)
        else
            HideEmpowerDividers(castBar)
        end
    else
        HideEmpowerDividers(castBar)
    end
    
    -- Show cast bar
    castBar:Show()
    
    -- Set icon
    if config.iconEnabled and texture then
        -- Handle secret texture values
        if issecretvalue and issecretvalue(texture) then
            castBar.iconTexture:SetTexture(texture)
        else
            castBar.iconTexture:SetTexture(texture)
        end
        castBar.iconFrame:Show()
    else
        castBar.iconFrame:Hide()
    end
    
    -- Set spell name
    if config.spellNameEnabled then
        -- Name might be secret in Midnight
        castBar.spellName:SetText(name or "")
    end
    
    -- Set cast target (who the spell is targeting)
    if config.castTargetEnabled and castBar.castTarget then
        local targetName, targetClass
        local targetIsSecret = false
        local classIsSecret = false
        
        -- Try new Midnight API first (UnitSpellTargetName)
        if UnitSpellTargetName then
            targetName = UnitSpellTargetName(unit)
            targetClass = UnitSpellTargetClass and UnitSpellTargetClass(unit)
            -- Check if values are secret (Midnight beta protection)
            targetIsSecret = issecretvalue and issecretvalue(targetName)
            classIsSecret = issecretvalue and issecretvalue(targetClass)
        end
        
        -- Fallback: check if the casting unit has a target
        -- Only fallback if targetName is actually nil (not a secret value)
        if targetName == nil and not targetIsSecret then
            -- For nameplate units, we can check their target
            local unitTarget = unit .. "target"
            if UnitExists(unitTarget) then
                targetName = UnitName(unitTarget)
                targetClass = UnitClassBase(unitTarget)
                -- These could also be secret in Midnight
                targetIsSecret = issecretvalue and issecretvalue(targetName)
                classIsSecret = issecretvalue and issecretvalue(targetClass)
            end
        end
        
        -- Show cast target if we have a name (secret or not)
        -- SetText can accept secret values - Blizzard handles the display
        if targetName ~= nil or targetIsSecret then
            castBar.castTarget:SetText(targetName or "")
            
            -- Apply class color if enabled
            -- Can't index RAID_CLASS_COLORS with a secret value, so skip coloring for secrets
            if castBar.castTargetUseClassColor and targetClass and not classIsSecret then
                local classColor = C_ClassColor and C_ClassColor.GetClassColor(targetClass)
                if classColor then
                    castBar.castTarget:SetTextColor(classColor:GetRGB())
                elseif RAID_CLASS_COLORS and RAID_CLASS_COLORS[targetClass] then
                    castBar.castTarget:SetTextColor(RAID_CLASS_COLORS[targetClass]:GetRGB())
                else
                    local dc = castBar.castTargetDefaultColor or {1, 0.8, 0.8, 1}
                    castBar.castTarget:SetTextColor(dc[1], dc[2], dc[3], dc[4] or 1)
                end
            else
                local dc = castBar.castTargetDefaultColor or {1, 0.8, 0.8, 1}
                castBar.castTarget:SetTextColor(dc[1], dc[2], dc[3], dc[4] or 1)
            end
            castBar.castTarget:Show()
        else
            castBar.castTarget:SetText("")
            castBar.castTarget:Hide()
        end
    end
    
    -- Set up status bar progress
    -- Check if we should use Duration Object API (Midnight)
    local useDurationObject = false
    if issecretvalue and issecretvalue(startTime) then
        useDurationObject = true
    end
    
    if useDurationObject then
        -- Use DurationAPI wrapper for Midnight Duration Objects
        local duration
        if isChanneling then
            -- For empowered spells, use UnitEmpoweredChannelDuration (includes hold-at-max time)
            if isEmpowered and DurationAPI and DurationAPI.GetEmpoweredDuration then
                duration = DurationAPI:GetEmpoweredDuration(unit, true)
            else
                duration = DurationAPI and DurationAPI:GetChannelDuration(unit)
            end
        else
            duration = DurationAPI and DurationAPI:GetCastingDuration(unit)
        end
        
        if duration and castBar.statusBar.SetTimerDuration then
            -- Set fill direction for channels
            if isChanneling then
                StatusBarAPI:SetFillStyle(castBar.statusBar, "REVERSE")
            else
                StatusBarAPI:SetFillStyle(castBar.statusBar, "STANDARD")
            end
            
            -- Use duration object for automatic updates
            castBar.statusBar:SetTimerDuration(duration)
            
            -- Timer text will need special handling with secrets
            if config.timerEnabled then
                -- Use the duration object's remaining time if available
                if duration.GetRemainingDuration then
                    local remaining = duration:GetRemainingDuration()
                    -- remaining might be a secret value - just set it directly
                    -- The FontString can handle secret values
                    if issecretvalue and issecretvalue(remaining) then
                        -- Use secret-safe formatting if available
                        if string.format then
                            -- Try to format - if it errors, leave blank
                            local success, formatted = pcall(function()
                                if config.timerShowDecimals then
                                    return string.format("%.1f", remaining)
                                else
                                    return string.format("%.0f", remaining)
                                end
                            end)
                            if success then
                                castBar.timer:SetText(formatted)
                            else
                                -- Can't format secrets - hide timer or show placeholder
                                castBar.timer:SetText("")
                            end
                        end
                    else
                        if config.timerShowDecimals then
                            castBar.timer:SetText(string.format("%.1f", remaining))
                        else
                            castBar.timer:SetText(string.format("%.0f", remaining))
                        end
                    end
                end
            end
        end
        
        -- Clear OnUpdate since duration object handles it
        castBar:SetScript("OnUpdate", nil)
    else
        -- Non-secret path - manual updates (used when values are accessible)
        local duration = (endTime - startTime) / 1000
        castBar.statusBar:SetMinMaxValues(0, duration)
        
        -- Set fill direction
        if isChanneling then
            if castBar.statusBar.SetFillStyle then
                castBar.statusBar:SetFillStyle(Enum.StatusBarFillStyle and Enum.StatusBarFillStyle.Reverse or "REVERSE")
            elseif castBar.statusBar.SetReverseFill then
                castBar.statusBar:SetReverseFill(true)
            end
        else
            if castBar.statusBar.SetFillStyle then
                castBar.statusBar:SetFillStyle(Enum.StatusBarFillStyle and Enum.StatusBarFillStyle.Standard or "STANDARD")
            elseif castBar.statusBar.SetReverseFill then
                castBar.statusBar:SetReverseFill(false)
            end
        end
        
        -- Store for OnUpdate
        castBar.castStartTime = startTime / 1000
        castBar.castEndTime = endTime / 1000
        castBar.castDuration = duration
        castBar.showDecimals = config.timerShowDecimals
        castBar.timerEnabled = config.timerEnabled
        
        -- Set up OnUpdate for progress
        castBar:SetScript("OnUpdate", function(self, elapsed)
            local currentTime = GetTime()
            local progress
            
            if self.isChanneling then
                progress = self.castEndTime - currentTime
            else
                progress = currentTime - self.castStartTime
            end
            
            self.statusBar:SetValue(progress)
            
            -- Update timer text
            if self.timerEnabled then
                local remaining = self.castEndTime - currentTime
                if remaining < 0 then remaining = 0 end
                
                if self.showDecimals then
                    self.timer:SetText(string.format("%.1f", remaining))
                else
                    self.timer:SetText(string.format("%.0f", remaining))
                end
            end
        end)
        
        -- Initial value
        local progress
        if isChanneling then
            progress = endTime / 1000 - GetTime()
        else
            progress = GetTime() - startTime / 1000
        end
        castBar.statusBar:SetValue(progress)
    end
    
    -- Apply color based on spell importance and interruptibility
    self:ApplyCastBarColorWithSecrets(castBar, config, isChanneling, spellID, notInterruptible)
    
    -- Update spark position for channels
    if config.sparkEnabled then
        if isChanneling then
            -- For channels, spark should be on the left side of remaining bar
            castBar.spark:ClearAllPoints()
            castBar.spark:SetPoint("CENTER", castBar.statusBar:GetStatusBarTexture(), "LEFT", 0, 0)
        else
            castBar.spark:ClearAllPoints()
            castBar.spark:SetPoint("CENTER", castBar.statusBar:GetStatusBarTexture(), "RIGHT", 0, 0)
        end
    end
end

-- ============================================================================
-- CAST INTERRUPTED HANDLER
-- ============================================================================

function Nameplates:OnCastInterrupted(castBar, config, nameplate, data)
    if not castBar or not config then return end
    
    castBar.isInterrupted = true
    castBar.isCasting = false
    castBar.isChanneling = false
    
    -- Show interrupted state
    castBar:Show()
    castBar.statusBar:SetMinMaxValues(0, 1)
    castBar.statusBar:SetValue(1)
    
    -- Apply interrupted color
    local c = config.interruptedColor or {1, 0, 0, 1}
    castBar.statusBar:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)
    
    -- Show "INTERRUPTED" text
    if castBar.spellName then
        castBar.spellName:SetText("INTERRUPTED")
    end
    
    -- Hide Blizzard's cast bar during interrupt display
    if nameplate and data then
        self:HideBlizzardCastBar(nameplate, data)
    end
    
    -- Clear OnUpdate
    castBar:SetScript("OnUpdate", nil)
    
    -- Hide after a short delay
    C_Timer.After(0.8, function()
        if castBar.isInterrupted then
            castBar.isInterrupted = false
            castBar:Hide()
        end
    end)
end

-- ============================================================================
-- CAST BAR EVENT SETUP
-- ============================================================================

function Nameplates:SetupCastBarEvents(data, unit)
    if not data.castBar then return end
    
    local castBar = data.castBar
    castBar.unit = unit
    
    -- Register for cast events
    castBar:RegisterUnitEvent("UNIT_SPELLCAST_START", unit)
    castBar:RegisterUnitEvent("UNIT_SPELLCAST_STOP", unit)
    castBar:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", unit)
    castBar:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", unit)
    castBar:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", unit)
    castBar:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", unit)
    castBar:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", unit)
    castBar:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", unit)
    castBar:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", unit)
    castBar:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", unit)
    
    -- Set up event handler
    local self_ref = self
    castBar:SetScript("OnEvent", function(self, event, ...)
        local configKey = UnitIsFriend("player", self.unit) and "friendly" or "enemy"
        local settings = self_ref.State.settings
        local config = settings[configKey] and settings[configKey].castBar
        
        if not config or not config.enabled then
            self:Hide()
            return
        end
        
        if event == "UNIT_SPELLCAST_INTERRUPTED" then
            -- IMMEDIATELY hide Blizzard's cast bar to prevent their flash from showing
            if self.nameplate and self.data then
                self_ref:HideBlizzardCastBar(self.nameplate, self.data)
            end
            self_ref:OnCastInterrupted(self, config, self.nameplate, self.data)
        elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_FAILED" then
            if not self.isInterrupted then
                self:Hide()
            end
            self.isCasting = false
            self.isChanneling = false
        else
            -- Update cast bar
            self_ref:UpdateCastBar(self, self.unit, config, configKey)
        end
    end)
end

function Nameplates:ClearCastBarEvents(data)
    if not data.castBar then return end
    
    data.castBar:UnregisterAllEvents()
    data.castBar:SetScript("OnEvent", nil)
    data.castBar:SetScript("OnUpdate", nil)
    data.castBar:Hide()
    data.castBar.unit = nil
end

-- ============================================================================
-- REFRESH ALL CAST BARS
-- ============================================================================

function Nameplates:RefreshAllCastBars()
    if not self.State.enhancedNameplates then return end
    
    for nameplate, data in pairs(self.State.enhancedNameplates) do
        if data.castBar and data.unit then
            local configKey = UnitIsFriend("player", data.unit) and "friendly" or "enemy"
            local config = self.State.settings[configKey] and self.State.settings[configKey].castBar
            
            if config and config.enabled and data.overlayHealthBar then
                self:PositionCastBar(data.castBar, data.overlayHealthBar, config, configKey)
                self:UpdateCastBar(data.castBar, data.unit, config, configKey)
            else
                data.castBar:Hide()
            end
        end
    end
end

-- ============================================================================
-- HIDE BLIZZARD CAST BAR
-- ============================================================================

-- PERFORMANCE OPTIMIZATION v1.9.0:
-- Replaced per-nameplate OnUpdate frames with:
-- 1. hooksecurefunc on SetAlpha to intercept Blizzard showing the cast bar
-- 2. Single consolidated ticker for any edge cases (runs at 100ms, not every frame)
-- This reduces 20+ OnUpdate calls per frame down to 1 ticker call every ~6 frames

-- Track all hidden cast bars for the consolidated ticker
local hiddenBlizzardCastBars = {}

-- Single consolidated ticker for edge case alpha enforcement (100ms interval)
local castBarHiderTicker = nil
local CAST_BAR_HIDER_INTERVAL = 0.03  -- 30ms, runs ~33x/second for catching flash animations

-- Helper to hide all cast bar components (MUST be defined before ticker)
local function HideCastBarComponents(castBar)
    local components = {
        castBar.Icon, castBar.icon,
        castBar.Text, castBar.text,
        castBar.BorderShield, castBar.borderShield, castBar.Shield, castBar.shield,
        castBar.Spark, castBar.spark,
        castBar.Border, castBar.border,
        castBar.Background, castBar.background, castBar.bg,
        castBar.Flash, castBar.flash,
        castBar.InterruptedSpell, castBar.interruptedSpell,
        castBar.TextString, castBar.textString,
        castBar.Overlay, castBar.overlay,
        castBar.FailedAnim, castBar.failedAnim,
        castBar.InterruptAnim, castBar.interruptAnim,
    }
    
    for _, component in ipairs(components) do
        if component then
            if component.SetAlpha then
                pcall(function() component:SetAlpha(0) end)
            end
            if component.Hide then
                pcall(function() component:Hide() end)
            end
            -- Stop any animations
            if component.Stop then
                pcall(function() component:Stop() end)
            end
        end
    end
    
    -- Also hide any children we might have missed
    if castBar.GetChildren then
        for _, child in pairs({castBar:GetChildren()}) do
            if child and child ~= castBar then
                if child.SetAlpha then pcall(function() child:SetAlpha(0) end) end
                if child.Hide then pcall(function() child:Hide() end) end
            end
        end
    end
    
    -- Hide all regions (textures, fontstrings)
    if castBar.GetRegions then
        for _, region in pairs({castBar:GetRegions()}) do
            if region then
                if region.SetAlpha then pcall(function() region:SetAlpha(0) end) end
                if region.Hide then pcall(function() region:Hide() end) end
            end
        end
    end
end

-- Helper to show all cast bar components
local function ShowCastBarComponents(castBar)
    local components = {
        castBar.Icon, castBar.icon,
        castBar.Text, castBar.text,
        castBar.BorderShield, castBar.borderShield, castBar.Shield, castBar.shield,
        castBar.Spark, castBar.spark,
        castBar.Border, castBar.border,
        castBar.Background, castBar.background, castBar.bg,
        castBar.Flash, castBar.flash,
    }
    
    for _, component in ipairs(components) do
        if component and component.SetAlpha then
            pcall(function() component:SetAlpha(1) end)
        end
    end
end

local function StartCastBarHiderTicker()
    if castBarHiderTicker then return end
    
    castBarHiderTicker = C_Timer.NewTicker(CAST_BAR_HIDER_INTERVAL, function()
        -- Only process cast bars that are actively hidden
        for castBar, shouldHide in pairs(hiddenBlizzardCastBars) do
            if shouldHide then
                -- Force hide the cast bar and all components
                if castBar:GetAlpha() > 0 then
                    castBar:SetAlpha(0)
                end
                -- Also ensure all components are hidden
                HideCastBarComponents(castBar)
            end
        end
    end)
end

local function StopCastBarHiderTicker()
    -- Check if any cast bars are still hidden
    for _, shouldHide in pairs(hiddenBlizzardCastBars) do
        if shouldHide then return end  -- Still have hidden cast bars, keep ticker running
    end
    
    -- No hidden cast bars, stop ticker
    if castBarHiderTicker then
        castBarHiderTicker:Cancel()
        castBarHiderTicker = nil
    end
end

function Nameplates:HideBlizzardCastBar(nameplate, data)
    if not nameplate then return end
    
    -- Get the unit frame from the nameplate
    local unitFrame = nameplate.UnitFrame
    if not unitFrame then return end
    
    -- Hide Blizzard's cast bar and all its components
    local castBar = unitFrame.CastBar or unitFrame.castBar
    if castBar then
        -- Set alpha to 0
        castBar:SetAlpha(0)
        
        -- Hook SetAlpha once to intercept Blizzard showing the cast bar
        -- This is more efficient than OnUpdate - only runs when SetAlpha is actually called
        if not castBar.TweaksUIHooked then
            castBar.TweaksUIHooked = true
            
            -- Store original SetAlpha
            castBar.TweaksUIOrigSetAlpha = castBar.SetAlpha
            
            -- Hook SetAlpha to intercept Blizzard showing the bar
            hooksecurefunc(castBar, "SetAlpha", function(self, alpha)
                -- If we should be hidden and Blizzard is trying to show us, force to 0
                if hiddenBlizzardCastBars[self] and alpha > 0 then
                    -- Use C_Timer.After to avoid infinite recursion
                    C_Timer.After(0, function()
                        if hiddenBlizzardCastBars[self] and self:GetAlpha() > 0 then
                            self:SetAlpha(0)
                            HideCastBarComponents(self)
                        end
                    end)
                end
            end)
            
            -- Also hook Show to catch that method
            hooksecurefunc(castBar, "Show", function(self)
                if hiddenBlizzardCastBars[self] then
                    self:SetAlpha(0)
                    HideCastBarComponents(self)
                end
            end)
            
            -- Hook Flash element specifically (interrupt animation)
            local flash = castBar.Flash or castBar.flash
            if flash then
                if flash.Hide then flash:Hide() end
                if flash.SetAlpha then flash:SetAlpha(0) end
                
                -- Hook Flash:Show
                if flash.Show and not flash.TweaksUIHooked then
                    flash.TweaksUIHooked = true
                    hooksecurefunc(flash, "Show", function(self)
                        if hiddenBlizzardCastBars[castBar] then
                            self:Hide()
                            self:SetAlpha(0)
                        end
                    end)
                end
                
                -- Hook Flash:SetAlpha
                if flash.SetAlpha and not flash.TweaksUIAlphaHooked then
                    flash.TweaksUIAlphaHooked = true
                    hooksecurefunc(flash, "SetAlpha", function(self, alpha)
                        if hiddenBlizzardCastBars[castBar] and alpha > 0 then
                            C_Timer.After(0, function()
                                if hiddenBlizzardCastBars[castBar] then
                                    self:SetAlpha(0)
                                    self:Hide()
                                end
                            end)
                        end
                    end)
                end
                
                -- Hook Flash animation play if it exists
                if flash.Play and not flash.TweaksUIPlayHooked then
                    flash.TweaksUIPlayHooked = true
                    hooksecurefunc(flash, "Play", function(self)
                        if hiddenBlizzardCastBars[castBar] then
                            if self.Stop then self:Stop() end
                            self:Hide()
                            self:SetAlpha(0)
                        end
                    end)
                end
            end
            
            -- Hook InterruptedSpell/Text elements
            local interruptText = castBar.InterruptedSpell or castBar.interruptedSpell or castBar.Text or castBar.text
            if interruptText and interruptText.SetText and not interruptText.TweaksUIHooked then
                interruptText.TweaksUIHooked = true
                hooksecurefunc(interruptText, "SetText", function(self)
                    if hiddenBlizzardCastBars[castBar] then
                        self:SetAlpha(0)
                    end
                end)
            end
        end
        
        -- Register this cast bar as hidden
        hiddenBlizzardCastBars[castBar] = true
        
        -- Hide individual components
        HideCastBarComponents(castBar)
        
        -- Start the backup ticker (handles any edge cases)
        StartCastBarHiderTicker()
        
        -- Store reference so we can restore later if needed
        data.blizzCastBarHidden = true
    end
end

function Nameplates:ShowBlizzardCastBar(nameplate, data)
    if not nameplate then return end
    
    local unitFrame = nameplate.UnitFrame
    if not unitFrame then return end
    
    local castBar = unitFrame.CastBar or unitFrame.castBar
    if not castBar then return end
    
    -- Clear our hidden flag first so hooks don't interfere
    data.blizzCastBarHidden = false
    
    -- Unregister this cast bar from hidden tracking
    hiddenBlizzardCastBars[castBar] = nil
    
    -- Check if we can stop the ticker
    StopCastBarHiderTicker()
    
    -- Restore Blizzard's cast bar
    castBar:SetAlpha(1)
    
    -- Restore components
    ShowCastBarComponents(castBar)
end

-- ============================================================================
-- GLOBAL INTERRUPT HANDLER
-- Catches UNIT_SPELLCAST_INTERRUPTED globally to immediately hide Blizzard's
-- cast bar interrupt flash before it can display
-- ============================================================================

local interruptEventFrame = CreateFrame("Frame")
interruptEventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
interruptEventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
interruptEventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
interruptEventFrame:SetScript("OnEvent", function(self, event, unit)
    if not unit or not unit:match("^nameplate") then return end
    
    -- Immediately force all hidden Blizzard cast bars to stay hidden
    for castBar, shouldHide in pairs(hiddenBlizzardCastBars) do
        if shouldHide then
            castBar:SetAlpha(0)
            HideCastBarComponents(castBar)
        end
    end
    
    -- Also try to hide the specific nameplate's cast bar
    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if nameplate and nameplate.UnitFrame then
        local castBar = nameplate.UnitFrame.CastBar or nameplate.UnitFrame.castBar
        if castBar and hiddenBlizzardCastBars[castBar] then
            castBar:SetAlpha(0)
            HideCastBarComponents(castBar)
        end
    end
end)
