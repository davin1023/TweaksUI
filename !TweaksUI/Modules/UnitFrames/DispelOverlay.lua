-- ============================================================================
-- TweaksUI Dispel Overlay Module
-- Shows colored border/glow when unit has dispellable debuff
-- 
-- Uses Midnight-compatible APIs:
-- - C_UnitAuras.GetAuraDispelTypeColor with curves
-- - StatusBars for secret-safe color application
-- ============================================================================

local addonName, TweaksUI = ...

local DispelOverlay = {}
TweaksUI.DispelOverlay = DispelOverlay

-- ============================================================================
-- DISPEL TYPE ENUM VALUES (WoW 12.0+)
-- From wago.tools/db2/SpellDispelType
-- ============================================================================

local DISPEL_TYPE = {
    None = 0,
    Magic = 1,
    Curse = 2,
    Disease = 3,
    Poison = 4,
    Enrage = 9,
    Bleed = 11,
}

-- All dispel type enum values for curve building
local ALL_DISPEL_ENUMS = {0, 1, 2, 3, 4, 9, 11}

-- Default dispel colors (more vibrant)
local DEFAULT_COLORS = {
    [1] = { r = 0.3, g = 0.7, b = 1.0 },   -- Magic (Blue) - more vibrant
    [2] = { r = 0.7, g = 0.2, b = 1.0 },   -- Curse (Purple) - more vibrant
    [3] = { r = 0.8, g = 0.5, b = 0.1 },   -- Disease (Brown/Orange) - more vibrant
    [4] = { r = 0.2, g = 0.8, b = 0.2 },   -- Poison (Green) - more vibrant
    [9] = { r = 1.0, g = 0.2, b = 0.2 },   -- Enrage (Red)
    [11] = { r = 1.0, g = 0.2, b = 0.2 },  -- Bleed (Red)
}

-- Dispel type names for display
local DISPEL_NAMES = {
    [1] = "Magic",
    [2] = "Curse",
    [3] = "Disease",
    [4] = "Poison",
    [9] = "Enrage",
    [11] = "Bleed",
}

-- ============================================================================
-- API DETECTION
-- ============================================================================

-- Check for Midnight curve APIs
local HAS_CURVE_API = (C_CurveUtil and C_CurveUtil.CreateColorCurve) and true or false
local HAS_DISPEL_COLOR_API = (C_UnitAuras and C_UnitAuras.GetAuraDispelTypeColor) and true or false

-- ============================================================================
-- CURVE CACHE
-- ============================================================================

local borderCurve = nil

-- Invalidate curve cache when settings change
function DispelOverlay:InvalidateCurves()
    borderCurve = nil
end

-- Build a color curve for dispel types
local function BuildDispelCurve(alpha, colors)
    if not HAS_CURVE_API then return nil end
    
    local curve = C_CurveUtil.CreateColorCurve()
    curve:SetType(Enum.LuaCurveType.Step)
    
    -- None = invisible (alpha 0)
    curve:AddPoint(0, CreateColor(0, 0, 0, 0))
    
    -- Add each dispel type with its color and the specified alpha
    for _, enumVal in ipairs(ALL_DISPEL_ENUMS) do
        if enumVal ~= 0 then
            local c = colors[enumVal] or DEFAULT_COLORS[enumVal]
            if c then
                curve:AddPoint(enumVal, CreateColor(c.r, c.g, c.b, alpha))
            end
        end
    end
    
    return curve
end

-- Get border curve (cached)
local function GetBorderCurve(settings)
    if borderCurve then
        return borderCurve
    end
    
    local alpha = settings.borderAlpha or 0.8
    local colors = settings.colors or DEFAULT_COLORS
    borderCurve = BuildDispelCurve(alpha, colors)
    return borderCurve
end

-- ============================================================================
-- OVERLAY CREATION
-- Uses StatusBars because they can handle secret colors
-- Changed from border-only to full-frame alpha overlay
-- ============================================================================

function DispelOverlay:CreateOverlay(frame)
    if frame.dispelOverlay then
        return frame.dispelOverlay
    end
    
    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetAllPoints(frame)
    overlay:SetFrameLevel(frame:GetFrameLevel() + 10)
    
    -- Create StatusBar helper function
    local function CreateOverlayBar(parent)
        local bar = CreateFrame("StatusBar", nil, parent)
        bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(1)
        bar:GetStatusBarTexture():SetBlendMode("BLEND")
        return bar
    end
    
    -- Full-frame fill overlay (semi-transparent color wash)
    overlay.fill = CreateOverlayBar(overlay)
    overlay.fill:SetAllPoints(overlay)
    overlay.fill:SetFrameLevel(overlay:GetFrameLevel())
    
    -- Glow texture extending beyond frame (additive blend for glow effect)
    overlay.glow = CreateFrame("StatusBar", nil, overlay)
    overlay.glow:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    overlay.glow:SetMinMaxValues(0, 1)
    overlay.glow:SetValue(1)
    overlay.glow:GetStatusBarTexture():SetBlendMode("ADD")
    overlay.glow:SetFrameLevel(overlay:GetFrameLevel() - 1)
    
    -- Keep border bars for optional border mode (legacy support)
    overlay.borderTop = CreateOverlayBar(overlay)
    overlay.borderBottom = CreateOverlayBar(overlay)
    overlay.borderLeft = CreateOverlayBar(overlay)
    overlay.borderRight = CreateOverlayBar(overlay)
    
    -- Pulse animation
    overlay.pulseAnim = overlay:CreateAnimationGroup()
    overlay.pulseAnim:SetLooping("REPEAT")
    
    local fadeOut = overlay.pulseAnim:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0.4)
    fadeOut:SetDuration(0.5)
    fadeOut:SetOrder(1)
    fadeOut:SetSmoothing("IN_OUT")
    
    local fadeIn = overlay.pulseAnim:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0.4)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(0.5)
    fadeIn:SetOrder(2)
    fadeIn:SetSmoothing("IN_OUT")
    
    overlay:Hide()
    frame.dispelOverlay = overlay
    
    return overlay
end

-- ============================================================================
-- OVERLAY LAYOUT
-- ============================================================================

local function ApplyLayout(overlay, settings)
    if not overlay then return end
    
    local showGlow = settings.showGlow ~= false
    local glowSize = settings.glowSize or 4
    local borderSize = settings.borderSize or 2
    local useBorderMode = settings.useBorderMode  -- Optional: fall back to border-only mode
    
    -- Full fill overlay covers the entire frame
    overlay.fill:ClearAllPoints()
    overlay.fill:SetAllPoints(overlay)
    
    -- Glow now covers the whole frame (inner glow, not extending beyond)
    if showGlow then
        overlay.glow:ClearAllPoints()
        overlay.glow:SetAllPoints(overlay)  -- Same size as frame
        overlay.glow:SetAlpha(settings.glowAlpha or 0.3)
    end
    
    -- Position borders (for legacy border-only mode)
    if useBorderMode then
        overlay.borderTop:SetPoint("TOPLEFT", 0, 0)
        overlay.borderTop:SetPoint("TOPRIGHT", 0, 0)
        overlay.borderTop:SetHeight(borderSize)
        
        overlay.borderBottom:SetPoint("BOTTOMLEFT", 0, 0)
        overlay.borderBottom:SetPoint("BOTTOMRIGHT", 0, 0)
        overlay.borderBottom:SetHeight(borderSize)
        
        overlay.borderLeft:SetPoint("TOPLEFT", 0, -borderSize)
        overlay.borderLeft:SetPoint("BOTTOMLEFT", 0, borderSize)
        overlay.borderLeft:SetWidth(borderSize)
        
        overlay.borderRight:SetPoint("TOPRIGHT", 0, -borderSize)
        overlay.borderRight:SetPoint("BOTTOMRIGHT", 0, borderSize)
        overlay.borderRight:SetWidth(borderSize)
    end
end

-- ============================================================================
-- SHOW/HIDE OVERLAY
-- ============================================================================

-- Show overlay with secret color (Midnight-compatible)
local function ShowOverlayWithSecretColor(overlay, settings, unit, auraInstanceID)
    if not overlay or not unit or not auraInstanceID then return end
    if not HAS_DISPEL_COLOR_API then return end
    
    local showGlow = settings.showGlow ~= false
    local showPulse = settings.showPulse ~= false
    local useBorderMode = settings.useBorderMode  -- Optional border-only mode
    local fillAlpha = settings.fillAlpha or 0.5  -- Semi-transparent fill
    
    ApplyLayout(overlay, settings)
    
    -- Get color from curve
    local curve = GetBorderCurve(settings)
    if curve then
        local color = C_UnitAuras.GetAuraDispelTypeColor(unit, auraInstanceID, curve)
        if color then
            local r, g, b, a = color:GetRGBA()
            
            -- Apply to fill overlay (main visible element)
            if not useBorderMode then
                overlay.fill:GetStatusBarTexture():SetVertexColor(r, g, b, fillAlpha)
                overlay.fill:Show()
                -- Hide borders in fill mode
                overlay.borderTop:Hide()
                overlay.borderBottom:Hide()
                overlay.borderLeft:Hide()
                overlay.borderRight:Hide()
            else
                -- Border-only mode (legacy)
                overlay.fill:Hide()
                overlay.borderTop:GetStatusBarTexture():SetVertexColor(r, g, b, a)
                overlay.borderTop:Show()
                overlay.borderBottom:GetStatusBarTexture():SetVertexColor(r, g, b, a)
                overlay.borderBottom:Show()
                overlay.borderLeft:GetStatusBarTexture():SetVertexColor(r, g, b, a)
                overlay.borderLeft:Show()
                overlay.borderRight:GetStatusBarTexture():SetVertexColor(r, g, b, a)
                overlay.borderRight:Show()
            end
            
            -- Apply to glow (extends beyond frame)
            if showGlow then
                overlay.glow:GetStatusBarTexture():SetVertexColor(r, g, b, a)
                overlay.glow:Show()
            else
                overlay.glow:Hide()
            end
        end
    end
    
    -- Start pulse animation
    if showPulse then
        overlay.pulseAnim:Play()
    else
        overlay.pulseAnim:Stop()
        overlay:SetAlpha(1)
    end
    
    overlay:Show()
end

-- Show overlay with RGB color (fallback for non-secret situations)
local function ShowOverlayWithRGB(overlay, settings, r, g, b)
    if not overlay then return end
    
    local showGlow = settings.showGlow ~= false
    local showPulse = settings.showPulse ~= false
    local useBorderMode = settings.useBorderMode  -- Optional border-only mode
    local fillAlpha = settings.fillAlpha or 0.5  -- Semi-transparent fill
    local borderAlpha = settings.borderAlpha or 0.8
    
    ApplyLayout(overlay, settings)
    
    -- Apply to fill overlay (main visible element)
    if not useBorderMode then
        overlay.fill:GetStatusBarTexture():SetVertexColor(r, g, b, fillAlpha)
        overlay.fill:Show()
        -- Hide borders in fill mode
        overlay.borderTop:Hide()
        overlay.borderBottom:Hide()
        overlay.borderLeft:Hide()
        overlay.borderRight:Hide()
    else
        -- Border-only mode (legacy)
        overlay.fill:Hide()
        overlay.borderTop:GetStatusBarTexture():SetVertexColor(r, g, b, borderAlpha)
        overlay.borderTop:Show()
        overlay.borderBottom:GetStatusBarTexture():SetVertexColor(r, g, b, borderAlpha)
        overlay.borderBottom:Show()
        overlay.borderLeft:GetStatusBarTexture():SetVertexColor(r, g, b, borderAlpha)
        overlay.borderLeft:Show()
        overlay.borderRight:GetStatusBarTexture():SetVertexColor(r, g, b, borderAlpha)
        overlay.borderRight:Show()
    end
    
    -- Apply to glow
    if showGlow then
        local glowAlpha = settings.glowAlpha or 0.3
        overlay.glow:GetStatusBarTexture():SetVertexColor(r, g, b, glowAlpha)
        overlay.glow:Show()
    else
        overlay.glow:Hide()
    end
    
    -- Start pulse animation
    if showPulse then
        overlay.pulseAnim:Play()
    else
        overlay.pulseAnim:Stop()
        overlay:SetAlpha(1)
    end
    
    overlay:Show()
end

-- Hide overlay
local function HideOverlay(overlay)
    if not overlay then return end
    
    overlay:Hide()
    overlay.pulseAnim:Stop()
    overlay:SetAlpha(1)
    
    -- Hide all overlay elements
    if overlay.fill then overlay.fill:Hide() end
    overlay.borderTop:Hide()
    overlay.borderBottom:Hide()
    overlay.borderLeft:Hide()
    overlay.borderRight:Hide()
    overlay.glow:Hide()
end

-- ============================================================================
-- BLIZZARD AURA CACHE (DandersFrames approach)
-- Hooks Blizzard's raid frames to capture which debuffs they decided are dispellable
-- This avoids all secret value comparisons during combat
-- ============================================================================

local BlizzardDispelCache = {}
local BlizzardHooksSetup = false

-- Capture dispellable debuffs from a Blizzard CompactUnitFrame
local function CaptureDispelsFromBlizzardFrame(frame)
    if not frame or not frame.unit then return end
    
    local unit = frame.unit
    if unit:find("nameplate") then return end
    
    -- Initialize cache for this unit
    if not BlizzardDispelCache[unit] then
        BlizzardDispelCache[unit] = {}
    end
    wipe(BlizzardDispelCache[unit])
    
    -- Capture player-dispellable debuffs from Blizzard's dispelDebuffFrames
    -- These are debuffs that Blizzard determined the current player can dispel
    if frame.dispelDebuffFrames then
        for i, debuffFrame in ipairs(frame.dispelDebuffFrames) do
            if debuffFrame:IsShown() and debuffFrame.auraInstanceID then
                BlizzardDispelCache[unit][debuffFrame.auraInstanceID] = true
            end
        end
    end
end

-- Hook Blizzard's aura update functions
local function SetupBlizzardHooks()
    if BlizzardHooksSetup then return end
    
    -- CRITICAL: All hooks use C_Timer.After(0) to break taint chain
    -- This prevents our addon code from tainting Blizzard's secure execution path
    if CompactUnitFrame_UpdateAuras then
        hooksecurefunc("CompactUnitFrame_UpdateAuras", function(frame)
            C_Timer.After(0, function()
                CaptureDispelsFromBlizzardFrame(frame)
            end)
        end)
    end
    if CompactUnitFrame_UpdateDebuffs then
        hooksecurefunc("CompactUnitFrame_UpdateDebuffs", function(frame)
            C_Timer.After(0, function()
                CaptureDispelsFromBlizzardFrame(frame)
            end)
        end)
    end
    
    BlizzardHooksSetup = true
end

-- Scan all Blizzard frames to populate cache
local function ScanAllBlizzardFrames()
    for i = 1, 5 do
        local frame = _G["CompactPartyFrameMember" .. i]
        if frame then CaptureDispelsFromBlizzardFrame(frame) end
    end
    for i = 1, 40 do
        local frame = _G["CompactRaidFrame" .. i]
        if frame then CaptureDispelsFromBlizzardFrame(frame) end
    end
    for group = 1, 8 do
        for member = 1, 5 do
            local frame = _G["CompactRaidGroup" .. group .. "Member" .. member]
            if frame then CaptureDispelsFromBlizzardFrame(frame) end
        end
    end
end

-- Check if an aura is in Blizzard's dispel cache
local function IsInBlizzardDispelCache(unit, auraInstanceID)
    local cache = BlizzardDispelCache[unit]
    if not cache then return false end
    return cache[auraInstanceID] == true
end

-- Export for debugging
DispelOverlay.BlizzardDispelCache = BlizzardDispelCache

-- ============================================================================
-- FIND DISPELLABLE DEBUFF
-- ============================================================================

-- Check if player can dispel a given type (fallback for out of combat)
local playerDispelTypes = {}

function DispelOverlay:UpdatePlayerDispelTypes()
    wipe(playerDispelTypes)
    
    local _, playerClass = UnitClass("player")
    
    if playerClass == "PRIEST" then
        playerDispelTypes.Magic = true
        playerDispelTypes.Disease = true
    elseif playerClass == "PALADIN" then
        playerDispelTypes.Magic = true
        playerDispelTypes.Poison = true
        playerDispelTypes.Disease = true
    elseif playerClass == "SHAMAN" then
        playerDispelTypes.Magic = true
        playerDispelTypes.Curse = true
    elseif playerClass == "DRUID" then
        playerDispelTypes.Magic = true
        playerDispelTypes.Curse = true
        playerDispelTypes.Poison = true
    elseif playerClass == "MAGE" then
        playerDispelTypes.Curse = true
    elseif playerClass == "MONK" then
        playerDispelTypes.Magic = true
        playerDispelTypes.Poison = true
        playerDispelTypes.Disease = true
    elseif playerClass == "EVOKER" then
        playerDispelTypes.Magic = true
        playerDispelTypes.Poison = true
    elseif playerClass == "WARLOCK" then
        playerDispelTypes.Magic = true
    end
end

-- Find first dispellable debuff on unit
-- Uses pcall for comparisons since dispelName/dispelType may be secret on some units
function DispelOverlay:FindDispellableDebuff(unit, settings)
    if not unit or not UnitExists(unit) then return nil, nil, nil end
    if not C_UnitAuras or not C_UnitAuras.GetUnitAuras then return nil, nil, nil end
    
    local onlyPlayerDispellable = settings.onlyPlayerDispellable ~= false
    local showBleed = settings.showBleed == true
    local showEnrage = settings.showEnrage == true
    
    -- Get all harmful auras sorted by expiration (most recent last)
    local sortRule = Enum.UnitAuraSortRule and Enum.UnitAuraSortRule.Expiration or nil
    local auras = C_UnitAuras.GetUnitAuras(unit, "HARMFUL", nil, sortRule)
    
    if not auras or #auras == 0 then return nil, nil, nil end
    
    local foundID = nil
    local foundType = nil
    local foundName = nil
    
    for _, aura in ipairs(auras) do
        local auraInstanceID = aura.auraInstanceID
        local shouldShow = false
        local dispelName = nil
        local dispelType = nil
        
        -- Extract values inside pcall since they may be secret
        pcall(function()
            dispelName = aura.dispelName
            dispelType = aura.dispelType
            
            -- Check for bleeds (dispelType == 11) and enrages (dispelType == 9)
            if showBleed and dispelType == DISPEL_TYPE.Bleed then
                shouldShow = true
            elseif showEnrage and dispelType == DISPEL_TYPE.Enrage then
                shouldShow = true
            elseif dispelName ~= nil then
                -- This debuff is dispellable by someone
                if onlyPlayerDispellable then
                    -- Check Blizzard's cache to see if player can dispel it
                    local isInCache = IsInBlizzardDispelCache(unit, auraInstanceID)
                    if isInCache then
                        shouldShow = true
                    else
                        -- Fallback: check our player dispel types list
                        if playerDispelTypes[dispelName] then
                            shouldShow = true
                        end
                    end
                else
                    -- Show any dispellable debuff
                    shouldShow = true
                end
            end
        end)
        
        if shouldShow then
            foundID = auraInstanceID
            foundType = dispelType
            foundName = dispelName
            -- Keep iterating - last one found is most recent (sorted by expiration)
        end
    end
    
    return foundID, foundType, foundName
end

-- ============================================================================
-- UPDATE OVERLAY FOR FRAME
-- ============================================================================

function DispelOverlay:UpdateOverlay(frame, settings)
    if not frame or not frame.unit then return end
    
    -- Check if enabled
    if not settings or not settings.enabled then
        if frame.dispelOverlay then
            HideOverlay(frame.dispelOverlay)
            frame.tuiLastDispelState = nil
        end
        return
    end
    
    local unit = frame.unit
    
    -- Check if unit exists
    if not UnitExists(unit) then
        if frame.dispelOverlay then
            HideOverlay(frame.dispelOverlay)
            frame.tuiLastDispelState = nil
        end
        return
    end
    
    -- Find dispellable debuff
    local auraInstanceID, dispelType, dispelName = self:FindDispellableDebuff(unit, settings)
    
    -- PERFORMANCE OPTIMIZATION: Cache dispel state to skip redundant updates
    -- Create a simple state key: auraInstanceID or 0
    local stateKey = auraInstanceID or 0
    if frame.tuiLastDispelState == stateKey then
        return  -- Same state, skip update
    end
    frame.tuiLastDispelState = stateKey
    
    if not auraInstanceID then
        if frame.dispelOverlay then
            HideOverlay(frame.dispelOverlay)
        end
        return
    end
    
    -- Ensure overlay exists
    local overlay = self:CreateOverlay(frame)
    
    -- Check if dispelType is secret
    local isDispelTypeSecret = issecretvalue and issecretvalue(dispelType)
    
    -- Try Midnight API first (secret-safe)
    -- Use curve-based color if dispelType is secret OR if it's a standard dispel type
    if HAS_DISPEL_COLOR_API then
        if isDispelTypeSecret then
            -- Dispel type is secret - use curve API (this is the Midnight-safe path)
            ShowOverlayWithSecretColor(overlay, settings, unit, auraInstanceID)
        else
            -- Dispel type is not secret - check if it's bleed/enrage (needs RGB fallback)
            if dispelType ~= DISPEL_TYPE.Bleed and dispelType ~= DISPEL_TYPE.Enrage then
                ShowOverlayWithSecretColor(overlay, settings, unit, auraInstanceID)
            else
                -- Fallback to RGB for bleeds/enrages
                local colors = settings.colors or DEFAULT_COLORS
                local color = colors[dispelType] or DEFAULT_COLORS[dispelType] or { r = 0.5, g = 0.5, b = 1.0 }
                ShowOverlayWithRGB(overlay, settings, color.r, color.g, color.b)
            end
        end
    else
        -- No curve API - use RGB fallback
        local colors = settings.colors or DEFAULT_COLORS
        local color = colors[dispelType] or DEFAULT_COLORS[dispelType] or { r = 0.5, g = 0.5, b = 1.0 }
        ShowOverlayWithRGB(overlay, settings, color.r, color.g, color.b)
    end
end

-- ============================================================================
-- BATCH UPDATE FUNCTIONS
-- ============================================================================

function DispelOverlay:UpdatePartyOverlays(partyFrames, settings)
    if not partyFrames then return end
    
    for _, frame in ipairs(partyFrames) do
        if frame and frame:IsShown() then
            self:UpdateOverlay(frame, settings)
        end
    end
end

function DispelOverlay:UpdateRaidOverlays(raidFrames, settings)
    if not raidFrames then return end
    
    for _, frame in ipairs(raidFrames) do
        if frame and frame:IsShown() then
            self:UpdateOverlay(frame, settings)
        end
    end
end

function DispelOverlay:HideAll(frames)
    if not frames then return end
    
    for _, frame in ipairs(frames) do
        if frame and frame.dispelOverlay then
            HideOverlay(frame.dispelOverlay)
        end
    end
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

function DispelOverlay:GetDispelTypeColor(dispelType)
    return DEFAULT_COLORS[dispelType]
end

function DispelOverlay:GetDispelTypeName(dispelType)
    return DISPEL_NAMES[dispelType]
end

function DispelOverlay:GetAllDispelTypes()
    return DISPEL_TYPE
end

-- ============================================================================
-- EVENT HANDLING
-- ============================================================================

local eventFrame = CreateFrame("Frame")

local function UpdateUnitDispel(unit)
    local UnitFrames = TweaksUI.UnitFrames
    if not UnitFrames then return end
    
    -- Update party frames
    local partyFrames = UnitFrames:GetPartyMemberFrames()
    local partySettings = UnitFrames:GetPartySettings()
    
    if partyFrames and partySettings and partySettings.dispelOverlay and partySettings.dispelOverlay.enabled then
        for _, frame in ipairs(partyFrames) do
            if frame and frame.unit then
                local isSameUnit = false
                pcall(function()
                    isSameUnit = UnitIsUnit(frame.unit, unit)
                end)
                
                if isSameUnit then
                    DispelOverlay:UpdateOverlay(frame, partySettings.dispelOverlay)
                    return
                end
            end
        end
    end
    
    -- Update raid frames
    local raidFrames = UnitFrames:GetRaidMemberFrames()
    local raidSettings = UnitFrames:GetCurrentRaidSettings()
    
    if raidFrames and raidSettings and raidSettings.dispelOverlay and raidSettings.dispelOverlay.enabled then
        for _, frame in ipairs(raidFrames) do
            if frame and frame.unit then
                local isSameUnit = false
                pcall(function()
                    isSameUnit = UnitIsUnit(frame.unit, unit)
                end)
                
                if isSameUnit then
                    DispelOverlay:UpdateOverlay(frame, raidSettings.dispelOverlay)
                    return
                end
            end
        end
    end
end

eventFrame:SetScript("OnEvent", function(self, event, unit, ...)
    if event == "UNIT_AURA" then
        if unit == "player" or unit:match("^party%d") or unit:match("^raid%d+") then
            -- Scan Blizzard frame for this unit to get updated dispel info
            -- This is needed because Blizzard's dispelDebuffFrames have JUST been updated
            for i = 1, 5 do
                local frame = _G["CompactPartyFrameMember" .. i]
                if frame and frame.unit == unit then
                    CaptureDispelsFromBlizzardFrame(frame)
                    break
                end
            end
            for i = 1, 40 do
                local frame = _G["CompactRaidFrame" .. i]
                if frame and frame.unit == unit then
                    CaptureDispelsFromBlizzardFrame(frame)
                    break
                end
            end
            for group = 1, 8 do
                for member = 1, 5 do
                    local frame = _G["CompactRaidGroup" .. group .. "Member" .. member]
                    if frame and frame.unit == unit then
                        CaptureDispelsFromBlizzardFrame(frame)
                        break
                    end
                end
            end
            
            UpdateUnitDispel(unit)
        end
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        -- Update player dispel types
        DispelOverlay:UpdatePlayerDispelTypes()
        
        -- Scan Blizzard frames to populate cache
        C_Timer.After(0.1, ScanAllBlizzardFrames)
        C_Timer.After(0.5, ScanAllBlizzardFrames)
        C_Timer.After(1.5, ScanAllBlizzardFrames)
        
        -- Update all frames
        C_Timer.After(0.2, function()
            local UnitFrames = TweaksUI.UnitFrames
            if not UnitFrames then return end
            
            local partyFrames = UnitFrames:GetPartyMemberFrames()
            local partySettings = UnitFrames:GetPartySettings()
            if partyFrames and partySettings and partySettings.dispelOverlay then
                DispelOverlay:UpdatePartyOverlays(partyFrames, partySettings.dispelOverlay)
            end
            
            local raidFrames = UnitFrames:GetRaidMemberFrames()
            local raidSettings = UnitFrames:GetCurrentRaidSettings()
            if raidFrames and raidSettings and raidSettings.dispelOverlay then
                DispelOverlay:UpdateRaidOverlays(raidFrames, raidSettings.dispelOverlay)
            end
        end)
    elseif event == "PLAYER_TALENT_UPDATE" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
        -- Refresh dispel types when talents change
        DispelOverlay:UpdatePlayerDispelTypes()
    end
end)

function DispelOverlay:Start()
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
    eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    
    -- Setup Blizzard hooks and scan existing frames
    SetupBlizzardHooks()
    ScanAllBlizzardFrames()
end

function DispelOverlay:Stop()
    eventFrame:UnregisterEvent("UNIT_AURA")
    eventFrame:UnregisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:UnregisterEvent("PLAYER_TALENT_UPDATE")
    eventFrame:UnregisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
end

-- Auto-start
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:HookScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        DispelOverlay:UpdatePlayerDispelTypes()
        SetupBlizzardHooks()
        -- Delayed scans to let Blizzard frames initialize
        C_Timer.After(0.5, ScanAllBlizzardFrames)
        C_Timer.After(1.5, ScanAllBlizzardFrames)
        DispelOverlay:Start()
    end
end)

-- ============================================================================
-- DEBUG SLASH COMMAND
-- ============================================================================

SLASH_TUIDISPELDEBUG1 = "/tuidispel"
SlashCmdList["TUIDISPELDEBUG"] = function(msg)
    local unit = msg ~= "" and msg or "target"
    
    print("|cff00ff00TweaksUI Dispel Debug:|r Checking unit: " .. unit)
    
    -- Check if unit exists
    if not UnitExists(unit) then
        print("  |cffff0000Unit does not exist!|r")
        return
    end
    
    print("  Unit name: " .. (UnitName(unit) or "Unknown"))
    
    -- Check player dispel types
    print("")
    print("  |cffffcc00Player can dispel:|r")
    local _, playerClass = UnitClass("player")
    print("    Class: " .. playerClass)
    local hasDispels = false
    for dispelType, _ in pairs(playerDispelTypes) do
        print("    - " .. dispelType)
        hasDispels = true
    end
    if not hasDispels then
        print("    |cffaaaaaa(none)|r")
    end
    
    -- Check Blizzard dispel cache
    print("")
    print("  |cffffcc00Blizzard Dispel Cache:|r")
    local cache = BlizzardDispelCache[unit]
    if cache then
        local count = 0
        for id, _ in pairs(cache) do
            count = count + 1
        end
        print("    Cache has " .. count .. " entries")
    else
        print("    |cffff0000No cache for this unit|r")
    end
    
    -- Check API availability
    print("")
    print("  |cffffcc00API Check:|r")
    print("    C_UnitAuras: " .. tostring(C_UnitAuras ~= nil))
    print("    GetUnitAuras: " .. tostring(C_UnitAuras and C_UnitAuras.GetUnitAuras ~= nil))
    print("    GetAuraDispelTypeColor: " .. tostring(HAS_DISPEL_COLOR_API))
    print("    C_CurveUtil: " .. tostring(HAS_CURVE_API))
    
    -- Get all harmful auras
    print("")
    print("  |cffffcc00Harmful Auras:|r")
    
    local sortRule = Enum.UnitAuraSortRule and Enum.UnitAuraSortRule.Expiration or nil
    local auras = C_UnitAuras.GetUnitAuras(unit, "HARMFUL", nil, sortRule)
    
    if not auras or #auras == 0 then
        print("    |cffaaaaaa(no harmful auras)|r")
        return
    end
    
    for i, aura in ipairs(auras) do
        local dispelName = aura.dispelName
        local dispelType = aura.dispelType
        local name = aura.name or "Unknown"
        local auraID = aura.auraInstanceID
        
        local dispelStr = ""
        if dispelName then
            dispelStr = string.format(" |cff00ff00[Dispellable: %s, type=%s]|r", tostring(dispelName), tostring(dispelType))
        elseif dispelType and dispelType > 0 then
            dispelStr = string.format(" |cffffaa00[dispelType=%s but no dispelName]|r", tostring(dispelType))
        end
        
        local canDispel = ""
        if dispelName and playerDispelTypes[dispelName] then
            canDispel = " |cff00ffff<YOU CAN DISPEL>|r"
        end
        
        local inCache = ""
        if auraID and cache and cache[auraID] then
            inCache = " |cff00ff00<IN CACHE>|r"
        end
        
        print(string.format("    [%d] %s%s%s%s", i, name, dispelStr, canDispel, inCache))
    end
    
    -- Try to find a dispellable debuff
    print("")
    print("  |cffffcc00FindDispellableDebuff result:|r")
    local settings = { enabled = true, onlyPlayerDispellable = true, showBleed = false, showEnrage = false }
    local auraID, dType, dName = DispelOverlay:FindDispellableDebuff(unit, settings)
    if auraID then
        print(string.format("    Found! auraInstanceID=%s, type=%s, name=%s", tostring(auraID), tostring(dType), tostring(dName)))
    else
        print("    |cffff0000No dispellable debuff found|r")
        
        -- Try again with onlyPlayerDispellable = false
        settings.onlyPlayerDispellable = false
        auraID, dType, dName = DispelOverlay:FindDispellableDebuff(unit, settings)
        if auraID then
            print(string.format("    With onlyPlayerDispellable=false: auraInstanceID=%s, type=%s, name=%s", tostring(auraID), tostring(dType), tostring(dName)))
        end
    end
end

return DispelOverlay
