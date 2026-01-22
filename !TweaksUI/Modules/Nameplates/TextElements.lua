-- ============================================================================
-- TweaksUI: Nameplates Module - Text Elements
-- Name, Health, and Threat text display
-- ============================================================================

local ADDON_NAME, TweaksUI = ...
local Nameplates = TweaksUI.Nameplates

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local OUTLINE_OPTIONS = {
    ["NONE"] = "",
    ["THIN"] = "OUTLINE",
    ["THICK"] = "THICKOUTLINE",
}

local ANCHOR_POINTS = {
    "TOPLEFT", "TOP", "TOPRIGHT",
    "LEFT", "CENTER", "RIGHT",
    "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT",
}

local HEALTH_FORMATS = {
    ["CURRENT"] = "Current",
    ["PERCENT"] = "Percentage",
    ["BOTH"] = "Both",
    ["DEFICIT"] = "Deficit",
    ["CURRENT_MAX"] = "Current / Max",
}

-- ============================================================================
-- DEFAULTS
-- ============================================================================

Nameplates.Defaults.TEXT_ELEMENT = {
    enabled = true,
    font = "Friz Quadrata TT",
    fontSize = 10,
    colorMode = "reaction",  -- "class", "reaction", "threat", "custom", "white"
    customColor = { 1, 1, 1, 1 },
    outline = "THIN",  -- "NONE", "THIN", "THICK"
    anchor = "BOTTOM",  -- Anchor point on health bar
    relativePoint = "TOP",  -- Point on text to anchor
    offsetX = 0,
    offsetY = 2,
    shadow = true,
}

Nameplates.Defaults.NAME_TEXT = {
    enabled = true,
    font = "Friz Quadrata TT",
    fontSize = 10,
    colorMode = "reaction",
    customColor = { 1, 1, 1, 1 },
    outline = "THIN",
    anchor = "BOTTOM",
    relativePoint = "TOP",
    offsetX = 0,
    offsetY = 2,
    shadow = true,
    showServerName = false,
}

Nameplates.Defaults.HEALTH_TEXT = {
    enabled = false,
    font = "Friz Quadrata TT",
    fontSize = 9,
    colorMode = "white",
    customColor = { 1, 1, 1, 1 },
    outline = "THIN",
    anchor = "CENTER",
    relativePoint = "CENTER",
    offsetX = 0,
    offsetY = 0,
    shadow = true,
    format = "PERCENT",  -- "CURRENT", "PERCENT", "BOTH", "DEFICIT", "CURRENT_MAX"
    showMaxHealth = false,
}

Nameplates.Defaults.THREAT_TEXT = {
    enabled = false,
    font = "Friz Quadrata TT",
    fontSize = 9,
    colorMode = "threat",
    customColor = { 1, 1, 1, 1 },
    outline = "THIN",
    anchor = "RIGHT",
    relativePoint = "LEFT",
    offsetX = -4,
    offsetY = 0,
    shadow = true,
    showPercent = true,
}

-- ============================================================================
-- TEXT CREATION
-- ============================================================================

function Nameplates:CreateTextElement(parent, name)
    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetDrawLayer("OVERLAY", 7)
    text.elementName = name
    return text
end

function Nameplates:CreateNameplateTexts(data)
    if not data.overlayHealthBar then return end
    
    local parent = data.overlayHealthBar
    
    -- Create name text
    if not data.nameText then
        data.nameText = self:CreateTextElement(parent, "name")
    end
    
    -- Create health text
    if not data.healthText then
        data.healthText = self:CreateTextElement(parent, "health")
    end
    
    -- Create threat text
    if not data.threatText then
        data.threatText = self:CreateTextElement(parent, "threat")
    end
end

-- ============================================================================
-- FONT HELPERS
-- ============================================================================

function Nameplates:GetFontPath(fontName)
    -- Try LibSharedMedia first
    if TweaksUI.Media and TweaksUI.Media.GetFont then
        local path = TweaksUI.Media:GetFont(fontName)
        if path then return path end
    end
    
    -- Try LSM directly
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local path = LSM:Fetch("font", fontName)
        if path then return path end
    end
    
    -- Fallback to default
    return "Fonts\\FRIZQT__.TTF"
end

function Nameplates:ApplyFontSettings(fontString, config, configKey, mouseoverScale)
    if not fontString or not config then return end
    
    local fontPath = self:GetFontPath(config.font or "Friz Quadrata TT")
    local baseFontSize = config.fontSize or 10
    local fontSize = self:ApplyScale(baseFontSize, configKey)
    
    -- Apply mouseover scale if provided
    if mouseoverScale and mouseoverScale ~= 1 then
        fontSize = fontSize * mouseoverScale
    end
    
    local outline = OUTLINE_OPTIONS[config.outline or "THIN"] or "OUTLINE"
    
    fontString:SetFont(fontPath, fontSize, outline)
    
    -- Shadow
    if config.shadow then
        fontString:SetShadowOffset(1, -1)
        fontString:SetShadowColor(0, 0, 0, 0.8)
    else
        fontString:SetShadowOffset(0, 0)
    end
end

-- ============================================================================
-- COLOR HELPERS
-- ============================================================================

function Nameplates:GetTextColor(unit, colorMode, customColor, invertThreatColors)
    local r, g, b = 1, 1, 1
    
    if colorMode == "class" then
        if UnitIsPlayer(unit) then
            r, g, b = self:GetClassColor(unit)
        else
            r, g, b = self:GetReactionColor(unit)
        end
    elseif colorMode == "reaction" then
        r, g, b = self:GetReactionColor(unit)
    elseif colorMode == "threat" then
        r, g, b = self:GetThreatColor(unit, invertThreatColors)
    elseif colorMode == "custom" then
        if customColor then
            r, g, b = customColor[1], customColor[2], customColor[3]
        end
    elseif colorMode == "white" then
        r, g, b = 1, 1, 1
    end
    
    return r or 1, g or 1, b or 1
end

-- ============================================================================
-- POSITIONING
-- ============================================================================

function Nameplates:PositionTextElement(textElement, parent, config, mouseoverScale)
    if not textElement or not parent or not config then return end
    
    mouseoverScale = mouseoverScale or 1
    
    textElement:ClearAllPoints()
    textElement:SetPoint(
        config.relativePoint or "TOP",
        parent,
        config.anchor or "BOTTOM",
        (config.offsetX or 0) * mouseoverScale,
        (config.offsetY or 2) * mouseoverScale
    )
end

-- ============================================================================
-- TEXT FORMATTING
-- ============================================================================

-- Safe health percent function matching UnitFrames pattern
function Nameplates:SafeUnitHealthPercent(unit)
    local ok, pct
    
    -- Try UnitHealthPercent if available (Midnight Beta)
    if type(UnitHealthPercent) == "function" then
        -- Try with CurveConstants.ScaleTo100 first (correct Midnight API)
        -- Signature: UnitHealthPercent(unit, usePredicted, curve)
        if CurveConstants and CurveConstants.ScaleTo100 then
            ok, pct = pcall(UnitHealthPercent, unit, false, CurveConstants.ScaleTo100)
            if ok and pct ~= nil then
                return pct  -- Returns 0-100
            end
        end
        
        -- Fallback: try with true for scaleTo100 (older API)
        ok, pct = pcall(UnitHealthPercent, unit, false, true)
        if ok and pct ~= nil then
            return pct
        end
        
        -- Try bare call (returns 0-1, need to scale)
        ok, pct = pcall(UnitHealthPercent, unit)
        if ok and pct ~= nil then
            local scaleOk, scaled = pcall(function() return pct * 100 end)
            if scaleOk then
                return scaled
            end
        end
    end
    
    -- Fallback for live servers: calculate from health/maxHealth
    if UnitHealth and UnitHealthMax then
        local cur = UnitHealth(unit)
        local max = UnitHealthMax(unit)
        local success, result = pcall(function()
            if cur and max and max > 0 then
                return (cur / max) * 100
            end
            return 0
        end)
        if success then return result end
    end
    
    return nil
end

function Nameplates:FormatHealthText(unit, format)
    if not unit then return "" end
    
    -- Key insight from Midnight API docs:
    -- string.format can accept secret values and returns a secret string
    -- FontStrings can display secret strings correctly
    -- We must NOT compare secret strings to anything
    
    if format == "PERCENT" then
        local pct = self:SafeUnitHealthPercent(unit)
        if pct then
            local success, result = pcall(function()
                return string.format("%.0f%%", pct)
            end)
            if success then
                return result or ""
            end
        end
        return ""
        
    elseif format == "CURRENT" then
        -- AbbreviateNumbers now accepts secrets (moved to C++ in Beta)
        if UnitHealth and AbbreviateNumbers then
            local success, result = pcall(function()
                local health = UnitHealth(unit)
                return AbbreviateNumbers(health)
            end)
            if success then
                return result or ""
            end
        end
        return ""
        
    elseif format == "BOTH" then
        -- Combine abbreviated health with percentage
        local pct = self:SafeUnitHealthPercent(unit)
        if UnitHealth and AbbreviateNumbers and pct then
            local success, result = pcall(function()
                local health = UnitHealth(unit)
                local healthStr = AbbreviateNumbers(health)
                return healthStr .. " (" .. string.format("%.0f%%", pct) .. ")"
            end)
            if success then
                return result or ""
            end
        end
        -- Fallback to just percentage
        if pct then
            local success, result = pcall(function()
                return string.format("%.0f%%", pct)
            end)
            if success then
                return result or ""
            end
        end
        return ""
        
    elseif format == "DEFICIT" then
        -- UnitHealthMissing returns missing health
        if UnitHealthMissing and AbbreviateNumbers then
            local success, result = pcall(function()
                local missing = UnitHealthMissing(unit)
                -- Concatenate - the result will be secret if missing is secret
                return "-" .. AbbreviateNumbers(missing)
            end)
            if success then
                return result or ""
            end
        end
        return ""
        
    elseif format == "CURRENT_MAX" then
        -- Show current / max using AbbreviateNumbers
        if UnitHealth and UnitHealthMax and AbbreviateNumbers then
            local success, result = pcall(function()
                local health = UnitHealth(unit)
                local maxHealth = UnitHealthMax(unit)
                return AbbreviateNumbers(health) .. " / " .. AbbreviateNumbers(maxHealth)
            end)
            if success then
                return result or ""
            end
        end
        return ""
    end
    
    return ""
end

function Nameplates:FormatNumber(num)
    if not num then return "0" end
    
    -- Wrap in pcall to handle secret values
    local success, result = pcall(function()
        if type(num) ~= "number" then return "0" end
        
        -- Test arithmetic to make sure it's a real number
        local test = num + 0
        
        if num >= 1000000000 then
            return string.format("%.1fB", num / 1000000000)
        elseif num >= 1000000 then
            return string.format("%.1fM", num / 1000000)
        elseif num >= 1000 then
            return string.format("%.1fK", num / 1000)
        end
        
        return tostring(math.floor(num))
    end)
    
    if success then
        return result
    end
    return "?"
end

function Nameplates:FormatThreatText(unit, config)
    if not unit then return "" end
    
    -- Get detailed threat info - wrap in pcall for secret values
    local success, result = pcall(function()
        local isTanking, status, threatPct, rawThreatPct, threatValue = UnitDetailedThreatSituation("player", unit)
        
        if threatPct then
            -- Test if threatPct is usable
            local testPct = threatPct + 0
            if config.showPercent then
                return string.format("%.0f%%", threatPct)
            else
                return string.format("%.0f", threatPct)
            end
        end
        return ""
    end)
    
    if success then
        return result
    end
    
    return ""
end

-- ============================================================================
-- UPDATE TEXT ELEMENTS
-- ============================================================================

function Nameplates:UpdateNameText(data, unit)
    if not data.nameText then return end
    
    local settings = self.State.settings
    local configKey = UnitIsFriend("player", unit) and "friendly" or "enemy"
    local config = settings[configKey] and settings[configKey].nameText
    local healthConfig = settings[configKey] and settings[configKey].healthBar
    
    if not config or not config.enabled then
        data.nameText:Hide()
        return
    end
    
    -- Get unit name
    local name = UnitName(unit)
    if not name then
        data.nameText:Hide()
        return
    end
    
    -- Apply font settings with configKey for scaling (include mouseover scale from data)
    local mouseoverScale = data.scaleMultiplier or 1
    self:ApplyFontSettings(data.nameText, config, configKey, mouseoverScale)
    
    -- Position with mouseover scale
    self:PositionTextElement(data.nameText, data.overlayHealthBar, config, mouseoverScale)
    
    -- Color (pass invert flag from health config)
    local invertThreat = healthConfig and healthConfig.invertThreatColors
    local r, g, b = self:GetTextColor(unit, config.colorMode, config.customColor, invertThreat)
    data.nameText:SetTextColor(r, g, b)
    
    -- Set text - handle secret values in Midnight
    -- Secret values return "string" from type() but can't be manipulated with gsub
    local displayName = name
    if not config.showServerName then
        -- pcall because secret values can't be manipulated with gsub
        local success, result = pcall(function() return name:gsub("%-.*", "") end)
        if success then displayName = result end
    end
    data.nameText:SetFormattedText("%s", displayName)
    data.nameText:Show()
end

function Nameplates:UpdateHealthText(data, unit)
    if not data.healthText then return end
    
    local settings = self.State.settings
    local configKey = UnitIsFriend("player", unit) and "friendly" or "enemy"
    local config = settings[configKey] and settings[configKey].healthText
    local healthConfig = settings[configKey] and settings[configKey].healthBar
    
    if not config or not config.enabled then
        data.healthText:Hide()
        return
    end
    
    -- Apply font settings with configKey for scaling (include mouseover scale from data)
    local mouseoverScale = data.scaleMultiplier or 1
    self:ApplyFontSettings(data.healthText, config, configKey, mouseoverScale)
    
    -- Position with mouseover scale
    self:PositionTextElement(data.healthText, data.overlayHealthBar, config, mouseoverScale)
    
    -- Color (pass invert flag from health config)
    local invertThreat = healthConfig and healthConfig.invertThreatColors
    local r, g, b = self:GetTextColor(unit, config.colorMode, config.customColor, invertThreat)
    data.healthText:SetTextColor(r, g, b)
    
    -- Format and set text - text may be a secret string, so don't compare it
    local text = self:FormatHealthText(unit, config.format)
    data.healthText:SetText(text or "")
    
    -- Always show - the text handles its own visibility via secret strings
    -- (empty secret strings will just show nothing)
    data.healthText:Show()
end

function Nameplates:UpdateThreatText(data, unit)
    if not data.threatText then return end
    
    local settings = self.State.settings
    local configKey = UnitIsFriend("player", unit) and "friendly" or "enemy"
    local config = settings[configKey] and settings[configKey].threatText
    local healthConfig = settings[configKey] and settings[configKey].healthBar
    
    if not config or not config.enabled then
        data.threatText:Hide()
        return
    end
    
    -- Apply font settings with configKey for scaling (include mouseover scale from data)
    local mouseoverScale = data.scaleMultiplier or 1
    self:ApplyFontSettings(data.threatText, config, configKey, mouseoverScale)
    
    -- Position with mouseover scale
    self:PositionTextElement(data.threatText, data.overlayHealthBar, config, mouseoverScale)
    
    -- Color (pass invert flag from health config)
    local invertThreat = healthConfig and healthConfig.invertThreatColors
    local r, g, b = self:GetTextColor(unit, config.colorMode, config.customColor, invertThreat)
    data.threatText:SetTextColor(r, g, b)
    
    -- Format and set text - text may be a secret string, so don't compare it
    local text = self:FormatThreatText(unit, config)
    data.threatText:SetText(text or "")
    
    -- Always show - empty secret strings will just display nothing
    data.threatText:Show()
end

-- ============================================================================
-- MAIN UPDATE FUNCTION
-- ============================================================================

function Nameplates:UpdateAllTexts(data, unit)
    if not data or not unit then return end
    
    -- Create text elements if needed
    self:CreateNameplateTexts(data)
    
    -- Update each text element
    self:UpdateNameText(data, unit)
    self:UpdateHealthText(data, unit)
    self:UpdateThreatText(data, unit)
end

-- ============================================================================
-- REFRESH ALL TEXT ELEMENTS
-- ============================================================================

function Nameplates:RefreshAllTexts()
    for nameplate, data in pairs(self.State.enhancedNameplates) do
        if data.unit then
            self:UpdateAllTexts(data, data.unit)
        end
    end
end

-- ============================================================================
-- HOOK INTO HEALTH UPDATES FOR TEXT REFRESH
-- ============================================================================

-- This will be called from HealthBars.lua when health changes
function Nameplates:OnHealthUpdate(data, unit)
    -- Update health text when health changes
    if data.healthText and self.State.settings then
        local configKey = UnitIsFriend("player", unit) and "friendly" or "enemy"
        local config = self.State.settings[configKey] and self.State.settings[configKey].healthText
        if config and config.enabled then
            local text = self:FormatHealthText(unit, config.format)
            data.healthText:SetText(text)
        end
    end
end

-- This will be called from Nameplates.lua when threat changes
function Nameplates:OnThreatUpdate(data, unit)
    if not self.State.settings then return end
    
    local configKey = UnitIsFriend("player", unit) and "friendly" or "enemy"
    local settings = self.State.settings[configKey]
    if not settings then return end
    
    local healthConfig = settings.healthBar
    local invertThreat = healthConfig and healthConfig.invertThreatColors
    
    -- Update name text if using threat color mode
    if data.nameText then
        local config = settings.nameText
        if config and config.enabled and config.colorMode == "threat" then
            local r, g, b = self:GetTextColor(unit, "threat", nil, invertThreat)
            data.nameText:SetTextColor(r, g, b)
        end
    end
    
    -- Update health text if using threat color mode
    if data.healthText then
        local config = settings.healthText
        if config and config.enabled and config.colorMode == "threat" then
            local r, g, b = self:GetTextColor(unit, "threat", nil, invertThreat)
            data.healthText:SetTextColor(r, g, b)
        end
    end
    
    -- Update threat text (always update text, and color if using threat mode)
    if data.threatText then
        local config = settings.threatText
        if config and config.enabled then
            -- Ensure font is set before calling SetText
            local fontPath, fontSize = data.threatText:GetFont()
            if not fontPath then
                -- Font not set yet, apply font settings first
                local mouseoverScale = data.scaleMultiplier or 1
                self:ApplyFontSettings(data.threatText, config, configKey, mouseoverScale)
            end
            
            local text = self:FormatThreatText(unit, config)
            data.threatText:SetText(text)
            if config.colorMode == "threat" then
                local r, g, b = self:GetTextColor(unit, "threat", nil, invertThreat)
                data.threatText:SetTextColor(r, g, b)
            end
        end
    end
end
