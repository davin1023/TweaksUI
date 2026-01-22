-- ============================================================================
-- TweaksUI: Nameplates Module - Health Bars
-- Phase 1: Health bar texture, color, background, border customization
-- Uses overlay approach similar to UnitFrames module for consistency
-- ============================================================================

local ADDON_NAME, TweaksUI = ...
local Nameplates = TweaksUI.Nameplates

-- ============================================================================
-- LOCALIZED GLOBALS (Performance Optimization v1.9.0)
-- ============================================================================

-- Lua
local pairs = pairs
local type = type
local pcall = pcall
local select = select

-- WoW API
local GetTime = GetTime
local CreateFrame = CreateFrame
local C_Timer = C_Timer
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitHealthPercent = UnitHealthPercent
local UnitCanAttack = UnitCanAttack
local UnitIsPlayer = UnitIsPlayer
local UnitClass = UnitClass
local UnitReaction = UnitReaction
local UnitThreatSituation = UnitThreatSituation
local UnitIsFriend = UnitIsFriend
local issecretvalue = issecretvalue
local CurveConstants = CurveConstants
local C_NamePlate = C_NamePlate
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local hooksecurefunc = hooksecurefunc

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local HEALTH_BAR_HEIGHT = 12  -- Default nameplate health bar height

-- ============================================================================
-- HEALTH BAR CONFIG
-- ============================================================================

function Nameplates:GetHealthBarConfig(unit)
    local settings = self.State.settings
    if not unit then return settings.enemy.healthBar end
    local isFriendly = not UnitCanAttack("player", unit)
    return isFriendly and settings.friendly.healthBar or settings.enemy.healthBar
end

-- ============================================================================
-- COLOR UTILITIES (matching UnitFrames patterns)
-- ============================================================================

function Nameplates:GetClassColor(unit)
    if not unit or not UnitIsPlayer(unit) then return nil end
    
    -- UnitClass may return secret values in Midnight
    local success, _, class = pcall(function() return UnitClass(unit) end)
    
    if not success then return nil end
    
    -- Can't index RAID_CLASS_COLORS with secret values
    if issecretvalue and issecretvalue(class) then return nil end
    
    if class and RAID_CLASS_COLORS[class] then
        local c = RAID_CLASS_COLORS[class]
        return c.r, c.g, c.b
    end
    return nil
end

function Nameplates:GetReactionColor(unit)
    if not unit then return 1, 0, 0 end
    
    -- Use pcall to handle Midnight Beta secret values
    local success, reaction = pcall(function() return UnitReaction(unit, "player") end)
    
    if not success or not reaction or type(reaction) ~= "number" then
        -- Fallback based on attackability
        if UnitCanAttack("player", unit) then
            return 1, 0, 0  -- Red for hostile
        else
            return 0, 1, 0  -- Green for friendly
        end
    end
    
    if reaction <= 2 then return 1, 0, 0           -- Hostile (red)
    elseif reaction == 3 then return 1, 0.5, 0     -- Unfriendly (orange)
    elseif reaction == 4 then return 1, 1, 0       -- Neutral (yellow)
    else return 0, 1, 0 end                        -- Friendly (green)
end

function Nameplates:GetThreatColor(unit, invertColors)
    if not unit then return 0.5, 0.5, 0.5 end  -- Default grey
    
    -- Get threat status using UnitThreatSituation
    -- First arg is "player", second is the nameplate unit
    local status = UnitThreatSituation("player", unit)
    
    -- If no threat status, try without the second arg to get general threat status
    if status == nil then
        status = UnitThreatSituation("player")
    end
    
    -- Default to 0 (no threat) if still nil
    if status == nil then
        status = 0
    end
    
    -- If inverting colors (tank mode), use inverted color scheme
    if invertColors then
        -- Status: 0 = no threat, 1 = low, 2 = high (not tanking), 3 = tanking
        -- Tank wants: tanking = grey/green (safe), no threat = red (bad)
        if status == 3 then
            -- Tanking: show grey/green instead of red
            return 0.5, 0.8, 0.5
        elseif status == 0 then
            -- No threat: show red instead of grey
            return 1, 0.2, 0.2
        elseif status == 1 then
            -- Low threat: show orange (losing aggro warning)
            return 1, 0.5, 0
        else
            -- High threat but not tanking: show yellow
            return 1, 1, 0
        end
    else
        -- Normal mode: use Blizzard's colors or our own
        if status == 3 then
            return 1, 0, 0  -- Red - tanking
        elseif status == 2 then
            return 1, 0.5, 0  -- Orange - high threat
        elseif status == 1 then
            return 1, 1, 0  -- Yellow - medium threat
        else
            return 0.5, 0.5, 0.5  -- Grey - no threat
        end
    end
end

-- Get threat-based scale multiplier
-- Returns a scale factor based on threat status (0-3)
function Nameplates:GetThreatScale(unit, config)
    if not config or not config.threatScaleEnabled then return 1.0 end
    if not unit then return 1.0 end
    
    local minScale = (config.threatScaleMin or 80) / 100
    local maxScale = (config.threatScaleMax or 120) / 100
    
    -- Get threat status
    local status = UnitThreatSituation("player", unit)
    if status == nil then
        status = UnitThreatSituation("player")
    end
    
    -- Map status 0-3 to scale range
    -- 0 = no threat, 1 = low, 2 = high (not tanking), 3 = tanking
    if status and status >= 0 then
        local t = status / 3  -- 0 to 1
        -- If inverted, swap the scale direction
        if config.invertThreatColors then
            t = 1 - t  -- Tanking = small, no threat = large
        end
        return minScale + (maxScale - minScale) * t
    end
    
    return 1.0  -- Default scale
end

function Nameplates:GetHealthGradientColor(unit)
    if not unit then return 0, 1, 0 end
    
    -- Use the decoder which handles secret values
    local pct = self:DecodeHealthPercent(unit)
    
    -- Final fallback
    if not pct then
        return 0, 1, 0  -- Default to green
    end
    
    -- Red at low health, yellow at mid, green at full
    -- pct is already 0-1 from decoder
    local success, r, g, b = pcall(function()
        if pct > 0.5 then
            return (1 - pct) * 2, 1, 0
        else
            return 1, pct * 2, 0
        end
    end)
    
    if success then
        return r, g, b
    end
    
    return 0, 1, 0  -- Default to green on error
end

-- Get health percentage using the new Midnight API with curves
function Nameplates:DecodeHealthPercent(unit)
    if not unit then return nil end
    
    -- Use UnitHealthPercent with ScaleTo100 curve if available (Midnight Beta)
    if UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
        local success, pct = pcall(function()
            -- This returns a secret value scaled 0-100, we need to pass it to a StatusBar
            return UnitHealthPercent(unit, CurveConstants.ScaleTo100)
        end)
        
        if success and pct then
            -- pct is a secret value, we need to use StatusBar to decode it
            return self:DecodeSecretPercent(pct)
        end
    end
    
    -- Fallback for live servers: calculate from health/maxHealth
    if UnitHealth and UnitHealthMax then
        local success, result = pcall(function()
            local cur = UnitHealth(unit)
            local max = UnitHealthMax(unit)
            if cur and max and max > 0 then
                return cur / max  -- Returns 0-1 for consistency with DecodeSecretPercent
            end
            return nil
        end)
        if success and result then
            return result
        end
    end
    
    -- Fallback: Try to read from Blizzard's nameplate health bar directly
    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if not nameplate or not nameplate.UnitFrame then return nil end
    
    local healthBar = self:GetHealthBar(nameplate.UnitFrame)
    if not healthBar then return nil end
    
    -- Try to get the value from the status bar
    local success, percent = pcall(function()
        local min, max = healthBar:GetMinMaxValues()
        local val = healthBar:GetValue()
        -- These might be secret, so test arithmetic
        local testMin = min + 0
        local testMax = max + 0
        local testVal = val + 0
        if testMax > testMin then
            return (testVal - testMin) / (testMax - testMin)
        end
        return nil
    end)
    
    if success and percent then
        return percent
    end
    
    -- Last resort
    return 1.0
end

-- Decode a secret percentage value using a hidden StatusBar
local percentDecoder = nil
function Nameplates:DecodeSecretPercent(secretPct)
    if not secretPct then return nil end
    
    -- Create a hidden StatusBar to decode the secret value
    if not percentDecoder then
        percentDecoder = CreateFrame("StatusBar", nil, UIParent)
        percentDecoder:SetSize(100, 10)
        percentDecoder:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -500, -500)
        percentDecoder:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        percentDecoder:SetMinMaxValues(0, 100)
        percentDecoder:SetAlpha(0)
        percentDecoder:Show()
    end
    
    -- Set the secret value
    local success = pcall(function()
        percentDecoder:SetValue(secretPct)
    end)
    
    if not success then return nil end
    
    -- Force layout update
    percentDecoder:GetWidth()
    
    -- Read back from the texture width ratio
    local success2, percent = pcall(function()
        local texture = percentDecoder:GetStatusBarTexture()
        if texture then
            local barWidth = percentDecoder:GetWidth()
            local texWidth = texture:GetWidth()
            -- Test arithmetic
            local testBar = barWidth + 0
            local testTex = texWidth + 0
            if testBar > 0 and testTex >= 0 then
                return testTex / testBar
            end
        end
        return nil
    end)
    
    if success2 and percent then
        return percent
    end
    
    return nil
end

function Nameplates:GetHealthBarColor(unit, config)
    local r, g, b
    
    -- colorMode: "class", "reaction", "health", "threat", "custom"
    local colorMode = config.colorMode or "reaction"
    
    if colorMode == "class" then
        if UnitIsPlayer(unit) then
            r, g, b = self:GetClassColor(unit)
        end
        -- Fall back to reaction if not a player
        if not r then
            r, g, b = self:GetReactionColor(unit)
        end
    elseif colorMode == "reaction" then
        r, g, b = self:GetReactionColor(unit)
    elseif colorMode == "health" then
        r, g, b = self:GetHealthGradientColor(unit)
    elseif colorMode == "threat" then
        -- Get threat color, pass invert flag, fall back to reaction if not on threat table
        r, g, b = self:GetThreatColor(unit, config.invertThreatColors)
        if not r then
            r, g, b = self:GetReactionColor(unit)
        end
    elseif colorMode == "custom" then
        if config.customColor then
            r, g, b = config.customColor[1], config.customColor[2], config.customColor[3]
        end
    end
    
    -- Final fallback to reaction color
    if not r then
        r, g, b = self:GetReactionColor(unit)
    end
    
    return r or 1, g or 0, b or 0
end

-- ============================================================================
-- OVERLAY HEALTH BAR CREATION
-- ============================================================================

function Nameplates:CreateOverlayHealthBar(nameplate, data)
    if data.overlayHealthBar then return data.overlayHealthBar end
    
    local blizzHealthBar = self:GetHealthBar(nameplate.UnitFrame)
    if not blizzHealthBar then return nil end
    
    -- Create our overlay StatusBar
    local overlay = CreateFrame("StatusBar", nil, nameplate)
    overlay:SetFrameLevel(blizzHealthBar:GetFrameLevel() + 1)
    overlay:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    overlay:SetMinMaxValues(0, 1)
    overlay:SetValue(1)
    
    -- Make completely mouse-transparent
    overlay:EnableMouse(false)
    -- Set hit rect to have no area
    overlay:SetHitRectInsets(10000, 10000, 10000, 10000)
    
    -- Background
    overlay.bg = overlay:CreateTexture(nil, "BACKGROUND")
    overlay.bg:SetAllPoints()
    overlay.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    overlay.bg:SetVertexColor(0.1, 0.1, 0.1, 0.8)
    
    -- Border using simple edge textures (avoids BackdropTemplate secret value issues)
    overlay.borderEdges = {}
    for i = 1, 4 do
        local edge = overlay:CreateTexture(nil, "BORDER")
        edge:SetTexture("Interface\\Buttons\\WHITE8X8")
        edge:SetVertexColor(0, 0, 0, 1)
        edge:Hide()
        overlay.borderEdges[i] = edge
    end
    
    data.overlayHealthBar = overlay
    return overlay
end

-- ============================================================================
-- POSITION AND SIZE
-- ============================================================================

function Nameplates:UpdateOverlayPosition(nameplate, data)
    local overlay = data.overlayHealthBar
    if not overlay then return end
    
    local blizzHealthBar = data.blizzHealthBar or self:GetHealthBar(nameplate.UnitFrame)
    if not blizzHealthBar then return end
    
    -- Center our overlay on Blizzard's health bar position
    overlay:ClearAllPoints()
    overlay:SetPoint("CENTER", blizzHealthBar, "CENTER", 0, 0)
end

-- ============================================================================
-- RESTORE BLIZZARD ELEMENTS (when our customization is disabled)
-- ============================================================================

function Nameplates:RestoreBlizzardElements(nameplate, data)
    if not nameplate or not nameplate.UnitFrame then return end
    
    local uf = nameplate.UnitFrame
    
    -- Restore health bar
    if data.blizzHealthBar then
        data.blizzHealthBar:SetAlpha(1)
    end
    
    -- Restore health bar container (Midnight Beta)
    if uf.HealthBarsContainer then
        uf.HealthBarsContainer:SetAlpha(1)
    end
    
    -- Restore name text - all possible locations
    if uf.name then
        uf.name:SetAlpha(1)
        uf.name:Show()
    end
    if uf.Name then
        uf.Name:SetAlpha(1)
        uf.Name:Show()
    end
    if uf.NameText then
        uf.NameText:SetAlpha(1)
        uf.NameText:Show()
    end
    if uf.nameText then
        uf.nameText:SetAlpha(1)
        uf.nameText:Show()
    end
    -- Also check nameplate itself
    if nameplate.name then
        nameplate.name:SetAlpha(1)
        nameplate.name:Show()
    end
    if nameplate.Name then
        nameplate.Name:SetAlpha(1)
        nameplate.Name:Show()
    end
    
    -- Restore cast bar
    if uf.CastBar then
        uf.CastBar:SetAlpha(1)
    end
    if uf.castBar then
        uf.castBar:SetAlpha(1)
    end
    
    -- Restore buff/debuff frame
    if uf.BuffFrame then
        uf.BuffFrame:SetAlpha(1)
    end
    
    -- Restore classification indicators
    if uf.ClassificationIndicator then
        uf.ClassificationIndicator:SetAlpha(1)
    end
    if uf.classificationIndicator then
        uf.classificationIndicator:SetAlpha(1)
    end
    if uf.ClassificationFrame then
        uf.ClassificationFrame:SetAlpha(1)
    end
    if uf.classificationFrame then
        uf.classificationFrame:SetAlpha(1)
    end
    if uf.EliteIcon then
        uf.EliteIcon:SetAlpha(1)
    end
    if uf.eliteIcon then
        uf.eliteIcon:SetAlpha(1)
    end
    if uf.BossIcon then
        uf.BossIcon:SetAlpha(1)
    end
    if uf.bossIcon then
        uf.bossIcon:SetAlpha(1)
    end
    
    -- Restore raid target icon
    if uf.RaidTargetFrame then
        uf.RaidTargetFrame:SetAlpha(1)
    end
    if uf.raidTargetFrame then
        uf.raidTargetFrame:SetAlpha(1)
    end
    if uf.RaidTargetIcon then
        uf.RaidTargetIcon:SetAlpha(1)
    end
    
    -- Restore selection highlight
    if uf.selectionHighlight then
        uf.selectionHighlight:SetAlpha(1)
    end
    if uf.SelectionHighlight then
        uf.SelectionHighlight:SetAlpha(1)
    end
    
    -- Restore aggro highlight
    if uf.aggroHighlight then
        uf.aggroHighlight:SetAlpha(1)
    end
    if uf.AggroHighlight then
        uf.AggroHighlight:SetAlpha(1)
    end
    
    -- Restore level frame
    if uf.LevelFrame then
        uf.LevelFrame:SetAlpha(1)
    end
    if uf.levelFrame then
        uf.levelFrame:SetAlpha(1)
    end
    
    -- Restore background
    if uf.background then
        uf.background:SetAlpha(1)
    end
    if uf.Background then
        uf.Background:SetAlpha(1)
    end
end

-- ============================================================================
-- APPLY SETTINGS TO OVERLAY
-- ============================================================================

function Nameplates:ApplyHealthBarSettings(overlay, unit, config, data)
    if not overlay or not config then return end
    
    -- Hide ALL of Blizzard's nameplate UnitFrame elements
    if data and data.nameplate and data.nameplate.UnitFrame then
        local uf = data.nameplate.UnitFrame
        
        -- Hide the entire UnitFrame's children by setting their alpha to 0
        -- This hides health bar, name, cast bar, icons, etc.
        
        -- Health bar container (Midnight Beta structure)
        if uf.HealthBarsContainer then
            uf.HealthBarsContainer:SetAlpha(0)
        end
        
        -- Individual health bar
        if data.blizzHealthBar then
            data.blizzHealthBar:SetAlpha(0)
        end
        
        -- Name text - check ALL possible name field locations (Live vs PTR/Beta differ!)
        if uf.name then
            uf.name:SetAlpha(0)
            uf.name:Hide()
        end
        if uf.Name then
            uf.Name:SetAlpha(0)
            uf.Name:Hide()
        end
        if uf.NameText then
            uf.NameText:SetAlpha(0)
            uf.NameText:Hide()
        end
        if uf.nameText then
            uf.nameText:SetAlpha(0)
            uf.nameText:Hide()
        end
        
        -- Also check the nameplate itself (not just UnitFrame)
        local np = data.nameplate
        if np.name and np.name ~= uf.name then
            np.name:SetAlpha(0)
            np.name:Hide()
        end
        if np.Name and np.Name ~= uf.Name then
            np.Name:SetAlpha(0)
            np.Name:Hide()
        end
        
        -- Cast bar
        if uf.CastBar then
            uf.CastBar:SetAlpha(0)
        end
        if uf.castBar then
            uf.castBar:SetAlpha(0)
        end
        
        -- Buff/debuff frame
        if uf.BuffFrame then
            uf.BuffFrame:SetAlpha(0)
        end
        
        -- Classification indicator (elite dragon, rare star, etc) - multiple possible names
        if uf.ClassificationIndicator then
            uf.ClassificationIndicator:SetAlpha(0)
        end
        if uf.classificationIndicator then
            uf.classificationIndicator:SetAlpha(0)
        end
        if uf.ClassificationFrame then
            uf.ClassificationFrame:SetAlpha(0)
        end
        if uf.classificationFrame then
            uf.classificationFrame:SetAlpha(0)
        end
        if uf.EliteIcon then
            uf.EliteIcon:SetAlpha(0)
        end
        if uf.eliteIcon then
            uf.eliteIcon:SetAlpha(0)
        end
        if uf.BossIcon then
            uf.BossIcon:SetAlpha(0)
        end
        if uf.bossIcon then
            uf.bossIcon:SetAlpha(0)
        end
        
        -- Raid target icon (skull, X, etc)
        if uf.RaidTargetFrame then
            uf.RaidTargetFrame:SetAlpha(0)
        end
        if uf.raidTargetFrame then
            uf.raidTargetFrame:SetAlpha(0)
        end
        if uf.RaidTargetIcon then
            uf.RaidTargetIcon:SetAlpha(0)
        end
        
        -- Selection highlight
        if uf.selectionHighlight then
            uf.selectionHighlight:SetAlpha(0)
        end
        if uf.SelectionHighlight then
            uf.SelectionHighlight:SetAlpha(0)
        end
        
        -- Aggro highlight
        if uf.aggroHighlight then
            uf.aggroHighlight:SetAlpha(0)
        end
        if uf.AggroHighlight then
            uf.AggroHighlight:SetAlpha(0)
        end
        
        -- Level frame
        if uf.LevelFrame then
            uf.LevelFrame:SetAlpha(0)
        end
        if uf.levelFrame then
            uf.levelFrame:SetAlpha(0)
        end
        
        -- Quest icon
        if uf.questIcon then
            uf.questIcon:SetAlpha(0)
        end
        if uf.QuestIcon then
            uf.QuestIcon:SetAlpha(0)
        end
        
        -- Threat indicator
        if uf.threatIndicator then
            uf.threatIndicator:SetAlpha(0)
        end
        if uf.ThreatIndicator then
            uf.ThreatIndicator:SetAlpha(0)
        end
        
        -- Any border/background on the UnitFrame itself
        if uf.border then
            uf.border:SetAlpha(0)
        end
        if uf.Border then
            uf.Border:SetAlpha(0)
        end
        if uf.background then
            uf.background:SetAlpha(0)
        end
        if uf.Background then
            uf.Background:SetAlpha(0)
        end
        
        -- Nuclear option: iterate all children and hide them
        -- This catches anything we might have missed
        for i = 1, uf:GetNumChildren() do
            local child = select(i, uf:GetChildren())
            -- Don't hide our own overlay or its border frame
            if child and child ~= data.overlayHealthBar then
                -- Use pcall in case child doesn't support SetAlpha
                pcall(function() 
                    child:SetAlpha(0)
                    child:Hide()
                end)
            end
        end
        
        -- Also hide any regions (textures, fontstrings)
        -- Use Hide() as well as SetAlpha(0) for Live compatibility
        for i = 1, uf:GetNumRegions() do
            local region = select(i, uf:GetRegions())
            if region then
                pcall(function() 
                    region:SetAlpha(0)
                    -- FontStrings need Hide() on Live
                    if region.Hide then
                        region:Hide()
                    end
                end)
            end
        end
        
        -- Also check the nameplate frame itself for regions (Live structure differs)
        local np = data.nameplate
        if np then
            for i = 1, np:GetNumRegions() do
                local region = select(i, np:GetRegions())
                if region and region:GetObjectType() == "FontString" then
                    pcall(function()
                        region:SetAlpha(0)
                        region:Hide()
                    end)
                end
            end
        end
    end
    
    -- Texture
    local texturePath = self:GetTexturePath(config.texture)
    overlay:SetStatusBarTexture(texturePath)
    
    -- Color
    local r, g, b = self:GetHealthBarColor(unit, config)
    overlay:SetStatusBarColor(r, g, b)
    
    -- Determine config key for scaling
    local configKey = UnitIsFriend("player", unit) and "friendly" or "enemy"
    
    -- Size - use target size if this is our target, and apply scale
    -- Use pcall because UnitIsUnit can return secrets in Midnight Beta
    -- Note: Secret values are truthy but fail == true comparison, so check for truthiness
    local isTarget = false
    local isMouseover = false
    if unit then
        local success, result = pcall(function() return UnitIsUnit(unit, "target") end)
        if success and result then  -- result is truthy (handles secret values)
            isTarget = true
        end
        -- Check mouseover using our tracking (more reliable than UnitIsUnit)
        if self.GetCurrentMouseoverNameplate then
            local currentMouseover = self:GetCurrentMouseoverNameplate()
            if currentMouseover and self.State.enhancedNameplates[currentMouseover] then
                local mouseoverData = self.State.enhancedNameplates[currentMouseover]
                if mouseoverData and mouseoverData.unit == unit then
                    isMouseover = true
                end
            end
        end
        -- Fallback to UnitIsUnit if tracking not available
        if not isMouseover then
            local success2, result2 = pcall(function() return UnitIsUnit(unit, "mouseover") end)
            if success2 and result2 then  -- result2 is truthy (handles secret values)
                isMouseover = true
            end
        end
    end
    
    -- Base size from config
    local baseWidth = config.width or 140
    local baseHeight = config.height or 12
    
    -- Apply global scale first
    local width = self:ApplyScale(baseWidth, configKey)
    local height = self:ApplyScale(baseHeight, configKey)
    
    -- Calculate scale multiplier for target or mouseover (for other modules to use)
    local scaleMultiplier = 1
    
    if isTarget then
        -- Apply target scale
        local targetScale = config.targetScale or 110  -- Default 110%
        if targetScale ~= 100 then
            scaleMultiplier = targetScale / 100
            width = width * scaleMultiplier
            height = height * scaleMultiplier
        end
    elseif isMouseover then
        -- Apply mouseover scale (only if not target)
        local mouseoverScale = config.mouseoverScale or 100
        if mouseoverScale ~= 100 then
            scaleMultiplier = mouseoverScale / 100
            width = width * scaleMultiplier
            height = height * scaleMultiplier
        end
    end
    
    -- Note: Threat-based scaling removed due to Midnight Beta secret value restrictions
    
    overlay:SetSize(width, height)
    
    -- Store current size and scale info in data for other modules to use
    data.currentWidth = width
    data.currentHeight = height
    data.configKey = configKey
    data.isMouseover = isMouseover
    data.isTarget = isTarget
    data.scaleMultiplier = scaleMultiplier  -- For icons, text, cast bars, auras to use
    -- Store effective alpha for other modules (cast bars, auras) to use
    data.effectiveAlpha = isTarget and (config.targetAlpha or 1.0) or (config.alpha or 1.0)
    
    -- Background
    if config.bgEnabled then
        local bgColor = config.bgColor or {0.1, 0.1, 0.1, 0.8}
        overlay.bg:SetVertexColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 0.8)
        overlay.bg:Show()
    else
        overlay.bg:Hide()
    end
    
    -- Border using edge textures (no BackdropTemplate to avoid secret value issues)
    if config.borderEnabled and overlay.borderEdges then
        local borderSize = config.borderSize or 1
        local borderColor = config.borderColor or {0, 0, 0, 1}
        local r, g, b, a = borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1
        local edges = overlay.borderEdges
        
        -- Top edge
        edges[1]:ClearAllPoints()
        edges[1]:SetPoint("BOTTOMLEFT", overlay, "TOPLEFT", -borderSize, 0)
        edges[1]:SetPoint("BOTTOMRIGHT", overlay, "TOPRIGHT", borderSize, 0)
        edges[1]:SetHeight(borderSize)
        edges[1]:SetVertexColor(r, g, b, a)
        edges[1]:Show()
        
        -- Bottom edge
        edges[2]:ClearAllPoints()
        edges[2]:SetPoint("TOPLEFT", overlay, "BOTTOMLEFT", -borderSize, 0)
        edges[2]:SetPoint("TOPRIGHT", overlay, "BOTTOMRIGHT", borderSize, 0)
        edges[2]:SetHeight(borderSize)
        edges[2]:SetVertexColor(r, g, b, a)
        edges[2]:Show()
        
        -- Left edge
        edges[3]:ClearAllPoints()
        edges[3]:SetPoint("TOPRIGHT", overlay, "TOPLEFT", 0, 0)
        edges[3]:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMLEFT", 0, 0)
        edges[3]:SetWidth(borderSize)
        edges[3]:SetVertexColor(r, g, b, a)
        edges[3]:Show()
        
        -- Right edge
        edges[4]:ClearAllPoints()
        edges[4]:SetPoint("TOPLEFT", overlay, "TOPRIGHT", 0, 0)
        edges[4]:SetPoint("BOTTOMLEFT", overlay, "BOTTOMRIGHT", 0, 0)
        edges[4]:SetWidth(borderSize)
        edges[4]:SetVertexColor(r, g, b, a)
        edges[4]:Show()
    elseif overlay.borderEdges then
        -- Hide all border edges
        for i = 1, 4 do
            overlay.borderEdges[i]:Hide()
        end
    end
    
    -- Base alpha from config (will be multiplied by Blizzard's alpha in the hook)
    overlay.baseAlpha = isTarget and (config.targetAlpha or 1.0) or (config.alpha or 1.0)
    
    -- Apply alpha immediately using stored intended alpha from nameplate
    local intendedAlpha = 1.0
    if data and data.nameplate and data.nameplate.TweaksUI_IntendedAlpha then
        intendedAlpha = data.nameplate.TweaksUI_IntendedAlpha
    end
    overlay:SetAlpha(intendedAlpha * overlay.baseAlpha)
end

-- ============================================================================
-- UPDATE HEALTH VALUE
-- ============================================================================

function Nameplates:UpdateOverlayHealth(overlay, unit)
    if not overlay or not unit then return end
    
    -- In Midnight Beta, UnitHealth and UnitHealthMax return secret values
    -- We can't do arithmetic on them, but StatusBar:SetMinMaxValues and SetValue
    -- can accept secret values directly
    
    local success = pcall(function()
        local health = UnitHealth(unit)
        local maxHealth = UnitHealthMax(unit)
        
        -- StatusBar accepts secret values directly - no comparison needed
        overlay:SetMinMaxValues(0, maxHealth)
        overlay:SetValue(health)
    end)
    
    -- If that fails, try percentage-based approach
    if not success then
        pcall(function()
            overlay:SetMinMaxValues(0, 1)
            if UnitHealthPercent then
                local pct = UnitHealthPercent(unit)
                overlay:SetValue(pct)
            elseif UnitHealth and UnitHealthMax then
                -- Fallback for live servers
                local cur = UnitHealth(unit)
                local max = UnitHealthMax(unit)
                if cur and max and max > 0 then
                    overlay:SetValue(cur / max)
                else
                    overlay:SetValue(1)
                end
            else
                overlay:SetValue(1)
            end
        end)
    end
end

-- ============================================================================
-- MAIN ENHANCEMENT FUNCTION
-- ============================================================================

function Nameplates:EnhanceHealthBar(nameplate, unit, data)
    if not nameplate or not nameplate.UnitFrame then return end
    
    -- Store nameplate reference
    data.nameplate = nameplate
    
    -- Get and store reference to Blizzard's health bar
    local blizzHealthBar = self:GetHealthBar(nameplate.UnitFrame)
    if not blizzHealthBar then return end
    data.blizzHealthBar = blizzHealthBar
    
    local config = self:GetHealthBarConfig(unit)
    if not config or not config.enabled then
        -- Hide overlay and restore Blizzard bar if disabled
        if data.overlayHealthBar then
            data.overlayHealthBar:Hide()
        end
        -- Restore all Blizzard elements
        self:RestoreBlizzardElements(nameplate, data)
        return
    end
    
    -- Create overlay if needed
    local overlay = self:CreateOverlayHealthBar(nameplate, data)
    if not overlay then return end
    
    -- Position overlay centered on Blizzard health bar
    self:UpdateOverlayPosition(nameplate, data)
    
    -- Apply visual settings (this also hides Blizzard's elements)
    self:ApplyHealthBarSettings(overlay, unit, config, data)
    
    -- Update health value
    self:UpdateOverlayHealth(overlay, unit)
    
    -- Show our overlay
    overlay:Show()
    
    -- Hook health updates if not already hooked
    self:HookHealthUpdates(nameplate, data)
end

-- ============================================================================
-- HEALTH UPDATE HOOKS
-- ============================================================================

local hookedNameplates = {}

-- Helper function to hide Blizzard name text (Live vs PTR/Beta compatibility)
local function HideBlizzardNameText(nameplate, data)
    if not nameplate then return end
    
    local uf = nameplate.UnitFrame
    if uf then
        if uf.name then pcall(function() uf.name:SetAlpha(0); uf.name:Hide() end) end
        if uf.Name then pcall(function() uf.Name:SetAlpha(0); uf.Name:Hide() end) end
        if uf.nameText then pcall(function() uf.nameText:SetAlpha(0); uf.nameText:Hide() end) end
        if uf.NameText then pcall(function() uf.NameText:SetAlpha(0); uf.NameText:Hide() end) end
    end
    -- Also check nameplate itself (Live)
    if nameplate.name then pcall(function() nameplate.name:SetAlpha(0); nameplate.name:Hide() end) end
    if nameplate.Name then pcall(function() nameplate.Name:SetAlpha(0); nameplate.Name:Hide() end) end
end

function Nameplates:HookHealthUpdates(nameplate, data)
    if hookedNameplates[nameplate] then return end
    
    local blizzHealthBar = self:GetHealthBar(nameplate.UnitFrame)
    if not blizzHealthBar then return end
    
    -- Hook OnValueChanged to sync our overlay health
    local originalOnValueChanged = blizzHealthBar:GetScript("OnValueChanged")
    blizzHealthBar:SetScript("OnValueChanged", function(self, value, ...)
        -- Call original safely
        if originalOnValueChanged then
            pcall(originalOnValueChanged, self, value, ...)
        end
        
        -- LIVE FIX: Continuously hide Blizzard's name text during updates
        -- On Live, Blizzard may re-show the name text during health updates
        HideBlizzardNameText(nameplate, data)
        
        -- Update our overlay
        if data.overlayHealthBar and data.unit then
            local config = Nameplates:GetHealthBarConfig(data.unit)
            if config and config.enabled then
                Nameplates:UpdateOverlayHealth(data.overlayHealthBar, data.unit)
                -- Also update color in case health-based coloring
                if config.colorMode == "health" then
                    local r, g, b = Nameplates:GetHealthBarColor(data.unit, config)
                    data.overlayHealthBar:SetStatusBarColor(r, g, b)
                end
            end
        end
    end)
    
    -- Hook the nameplate's SetAlpha to capture intended alpha while forcing to 0
    if not nameplate.TweaksUI_AlphaHook then
        nameplate.TweaksUI_AlphaHook = true
        nameplate.TweaksUI_IntendedAlpha = 1.0
        
        -- Store original SetAlpha
        local originalSetAlpha = nameplate.SetAlpha
        
        -- Override SetAlpha to capture intended value
        nameplate.SetAlpha = function(self, alpha)
            -- Store what Blizzard wants the alpha to be
            self.TweaksUI_IntendedAlpha = alpha
            
            -- Force nameplate to 0 so Blizzard's bar is invisible
            originalSetAlpha(self, 0)
            
            -- Update our overlay with the intended alpha
            if data.overlayHealthBar then
                local baseAlpha = data.overlayHealthBar.baseAlpha or 1.0
                data.overlayHealthBar:SetAlpha(alpha * baseAlpha)
            end
        end
        
        -- Also hook Show/Hide to handle visibility
        local originalShow = nameplate.Show
        nameplate.Show = function(self)
            originalShow(self)
            -- LIVE FIX: Hide Blizzard name immediately when nameplate is shown
            HideBlizzardNameText(self, data)
            if data.overlayHealthBar then
                data.overlayHealthBar:Show()
            end
        end
        
        local originalHide = nameplate.Hide
        nameplate.Hide = function(self)
            originalHide(self)
            if data.overlayHealthBar then
                data.overlayHealthBar:Hide()
            end
        end
        
        -- LIVE FIX: Hook the name text's Show method to prevent it from ever showing
        local uf = nameplate.UnitFrame
        if uf then
            -- Hook uf.name
            if uf.name and not uf.name._TUI_ShowHooked then
                uf.name._TUI_ShowHooked = true
                hooksecurefunc(uf.name, "Show", function(self)
                    self:Hide()
                    self:SetAlpha(0)
                end)
                hooksecurefunc(uf.name, "SetAlpha", function(self, alpha)
                    if alpha > 0 then
                        C_Timer.After(0, function()
                            if self:GetAlpha() > 0 then
                                self:SetAlpha(0)
                            end
                        end)
                    end
                end)
            end
            -- Hook uf.Name
            if uf.Name and not uf.Name._TUI_ShowHooked then
                uf.Name._TUI_ShowHooked = true
                hooksecurefunc(uf.Name, "Show", function(self)
                    self:Hide()
                    self:SetAlpha(0)
                end)
                hooksecurefunc(uf.Name, "SetAlpha", function(self, alpha)
                    if alpha > 0 then
                        C_Timer.After(0, function()
                            if self:GetAlpha() > 0 then
                                self:SetAlpha(0)
                            end
                        end)
                    end
                end)
            end
        end
    end
    
    hookedNameplates[nameplate] = true
end

-- ============================================================================
-- REFRESH ALL NAMEPLATES
-- ============================================================================

function Nameplates:RefreshAllHealthBars()
    for nameplate, data in pairs(self.State.enhancedNameplates) do
        if data.unit then
            self:EnhanceHealthBar(nameplate, data.unit, data)
        end
    end
end

-- ============================================================================
-- CLEANUP
-- ============================================================================

function Nameplates:CleanupHealthBar(data)
    if data.overlayHealthBar then
        data.overlayHealthBar:Hide()
    end
end
