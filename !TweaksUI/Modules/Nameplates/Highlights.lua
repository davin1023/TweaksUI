-- ============================================================================
-- TweaksUI: Nameplates Module - Highlights
-- Target and Focus highlight system
-- ============================================================================

local ADDON_NAME, TweaksUI = ...
local Nameplates = TweaksUI.Nameplates

-- ============================================================================
-- LOCALIZED GLOBALS (Performance Optimization v1.9.0)
-- ============================================================================

-- Lua
local pairs = pairs

-- WoW API
local CreateFrame = CreateFrame
local C_Timer = C_Timer
local UnitIsUnit = UnitIsUnit
local UnitExists = UnitExists
local C_NamePlate = C_NamePlate

-- ============================================================================
-- HIGHLIGHT FRAME CREATION
-- ============================================================================

function Nameplates:CreateHighlightFrame(nameplate)
    local highlight = CreateFrame("Frame", nil, nameplate)
    highlight:SetAllPoints()
    highlight:SetFrameLevel(nameplate:GetFrameLevel() + 10)
    
    -- Make completely mouse-transparent
    highlight:EnableMouse(false)
    -- Set hit rect to have no area (insets larger than frame size)
    highlight:SetHitRectInsets(10000, 10000, 10000, 10000)
    
    -- Create 4 edge textures (top, bottom, left, right)
    highlight.edges = {}
    for i = 1, 4 do
        highlight.edges[i] = highlight:CreateTexture(nil, "OVERLAY")
        highlight.edges[i]:SetTexture("Interface\\Buttons\\WHITE8x8")
        highlight.edges[i]:Hide()
    end
    
    return highlight
end

-- ============================================================================
-- HIGHLIGHT APPLICATION
-- ============================================================================

function Nameplates:ApplyHighlight(highlight, frame, color, thickness, isGlow)
    local r, g, b, a = color[1], color[2], color[3], color[4] or 0.6
    local edges = highlight.edges
    
    -- Set blend mode for glow effect
    for i = 1, 4 do
        edges[i]:SetBlendMode(isGlow and "ADD" or "BLEND")
    end
    
    -- Top edge
    edges[1]:ClearAllPoints()
    edges[1]:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", -thickness, 0)
    edges[1]:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", thickness, 0)
    edges[1]:SetHeight(thickness)
    edges[1]:SetColorTexture(r, g, b, a)
    edges[1]:Show()
    
    -- Bottom edge
    edges[2]:ClearAllPoints()
    edges[2]:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -thickness, 0)
    edges[2]:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", thickness, 0)
    edges[2]:SetHeight(thickness)
    edges[2]:SetColorTexture(r, g, b, a)
    edges[2]:Show()
    
    -- Left edge
    edges[3]:ClearAllPoints()
    edges[3]:SetPoint("TOPRIGHT", frame, "TOPLEFT", 0, 0)
    edges[3]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 0, 0)
    edges[3]:SetWidth(thickness)
    edges[3]:SetColorTexture(r, g, b, a)
    edges[3]:Show()
    
    -- Right edge
    edges[4]:ClearAllPoints()
    edges[4]:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, 0)
    edges[4]:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 0, 0)
    edges[4]:SetWidth(thickness)
    edges[4]:SetColorTexture(r, g, b, a)
    edges[4]:Show()
end

function Nameplates:HideHighlight(highlight)
    if highlight and highlight.edges then
        for i = 1, 4 do
            highlight.edges[i]:Hide()
        end
    end
end

-- ============================================================================
-- UPDATE HIGHLIGHTS
-- ============================================================================

-- Track current mouseover nameplate
local currentMouseoverNameplate = nil

function Nameplates:UpdateHighlights(nameplate, unit)
    local unitFrame = nameplate.UnitFrame
    if not unitFrame then return end
    
    local data = self.State.enhancedNameplates[nameplate]
    if not data or not data.highlight then return end
    
    -- Hide existing highlight first
    self:HideHighlight(data.highlight)
    
    -- Use our overlay if available, otherwise fall back to Blizzard's bar
    local targetFrame = data.overlayHealthBar or self:GetHealthBar(unitFrame)
    if not targetFrame then return end
    
    local settings = self.State.settings
    local isTarget = UnitIsUnit(unit, "target")
    local isFocus = UnitIsUnit(unit, "focus")
    local isMouseover = (nameplate == currentMouseoverNameplate)
    
    -- Determine configKey for scaling
    local configKey = UnitIsFriend("player", unit) and "friendly" or "enemy"
    
    -- Priority: Target > Focus > Mouseover
    if isTarget and settings.targetHighlight.enabled then
        local h = settings.targetHighlight
        local scaledThickness = self:ApplyScale(h.thickness, configKey)
        self:ApplyHighlight(data.highlight, targetFrame, h.color, scaledThickness, h.style == "glow")
    elseif isFocus and settings.focusHighlight.enabled then
        local h = settings.focusHighlight
        local scaledThickness = self:ApplyScale(h.thickness, configKey)
        self:ApplyHighlight(data.highlight, targetFrame, h.color, scaledThickness, h.style == "glow")
    elseif isMouseover and settings.mouseoverHighlight and settings.mouseoverHighlight.enabled then
        local h = settings.mouseoverHighlight
        local scaledThickness = self:ApplyScale(h.thickness, configKey)
        self:ApplyHighlight(data.highlight, targetFrame, h.color, scaledThickness, h.style == "glow")
    end
end

-- ============================================================================
-- REFRESH ALL HIGHLIGHTS
-- ============================================================================

function Nameplates:RefreshAllHighlights()
    for nameplate, data in pairs(self.State.enhancedNameplates) do
        if data.unit then
            self:UpdateHighlights(nameplate, data.unit)
        end
    end
end

-- ============================================================================
-- MOUSE ENTER/LEAVE HANDLERS
-- ============================================================================

function Nameplates:OnNameplateEnter(nameplate)
    local data = self.State.enhancedNameplates[nameplate]
    if not data or not data.unit then return end
    
    currentMouseoverNameplate = nameplate
    
    -- Refresh this nameplate's highlight
    self:UpdateHighlights(nameplate, data.unit)
    
    -- Refresh health bar for mouseover scale
    if self.RefreshAllHealthBars then self:RefreshAllHealthBars() end
    if self.RefreshAllCastBars then self:RefreshAllCastBars() end
    if self.RefreshAllTexts then self:RefreshAllTexts() end
    if self.RefreshAllIcons then self:RefreshAllIcons() end
end

function Nameplates:OnNameplateLeave(nameplate)
    local data = self.State.enhancedNameplates[nameplate]
    if not data then return end
    
    -- Only clear if this is the current mouseover
    if currentMouseoverNameplate == nameplate then
        currentMouseoverNameplate = nil
        
        -- Update this nameplate's highlight (will clear mouseover, may show target/focus)
        if data.unit then
            self:UpdateHighlights(nameplate, data.unit)
        elseif data.highlight then
            self:HideHighlight(data.highlight)
        end
        
        -- Refresh health bar to remove mouseover scale
        if self.RefreshAllHealthBars then self:RefreshAllHealthBars() end
        if self.RefreshAllCastBars then self:RefreshAllCastBars() end
        if self.RefreshAllTexts then self:RefreshAllTexts() end
        if self.RefreshAllIcons then self:RefreshAllIcons() end
    end
end

-- Expose current mouseover for other modules
function Nameplates:GetCurrentMouseoverNameplate()
    return currentMouseoverNameplate
end

-- Set mouseover from UPDATE_MOUSEOVER_UNIT event (for 3D model mouseover)
function Nameplates:SetMouseoverFromUnit(unit)
    -- Find the nameplate for this unit
    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if nameplate and self.State.enhancedNameplates[nameplate] then
        if currentMouseoverNameplate ~= nameplate then
            -- Clear old mouseover first
            if currentMouseoverNameplate then
                self:OnNameplateLeave(currentMouseoverNameplate)
            end
            -- Set new mouseover
            self:OnNameplateEnter(nameplate)
        end
    end
end

-- Clear mouseover when nothing is moused over (polling check for 3D model mouseoff)
function Nameplates:ClearMouseoverIfNone()
    if currentMouseoverNameplate and not UnitExists("mouseover") then
        self:OnNameplateLeave(currentMouseoverNameplate)
    end
end

-- PERFORMANCE OPTIMIZATION v1.9.0:
-- Replaced throttled OnUpdate with C_Timer.NewTicker
-- OnUpdate runs every frame (~60/sec) even with manual throttle
-- NewTicker only fires at the specified interval, reducing CPU overhead
local mouseoverPollTicker = C_Timer.NewTicker(0.1, function()
    Nameplates:ClearMouseoverIfNone()
end)
