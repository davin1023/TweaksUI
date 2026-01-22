-- ============================================================================
-- TweaksUI Threat Overlay Module
-- Shows red border/glow when unit has threat/aggro
-- 
-- Threat Status Levels (from UnitThreatSituation):
-- 0 = No threat / Not on threat list
-- 1 = High threat (not tanking, but on threat list)
-- 2 = Highest threat (about to pull aggro)
-- 3 = Tanking / Has aggro
-- ============================================================================

local addonName, TweaksUI = ...

local ThreatOverlay = {}
TweaksUI.ThreatOverlay = ThreatOverlay

-- ============================================================================
-- THREAT COLOR (solid red for all threat levels)
-- ============================================================================

local THREAT_COLOR = { r = 1.0, g = 0.0, b = 0.0 }

-- ============================================================================
-- OVERLAY CREATION
-- ============================================================================

function ThreatOverlay:CreateOverlay(frame)
    if frame.threatOverlay then
        return frame.threatOverlay
    end
    
    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetAllPoints(frame)
    overlay:SetFrameLevel(frame:GetFrameLevel() + 9)  -- Below dispel overlay (10)
    
    -- Create border bars
    local function CreateBorderBar(parent)
        local bar = CreateFrame("StatusBar", nil, parent)
        bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(1)
        bar:GetStatusBarTexture():SetBlendMode("BLEND")
        return bar
    end
    
    overlay.borderTop = CreateBorderBar(overlay)
    overlay.borderBottom = CreateBorderBar(overlay)
    overlay.borderLeft = CreateBorderBar(overlay)
    overlay.borderRight = CreateBorderBar(overlay)
    
    -- Glow texture (additive blend for glow effect)
    overlay.glow = CreateFrame("StatusBar", nil, overlay)
    overlay.glow:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    overlay.glow:SetMinMaxValues(0, 1)
    overlay.glow:SetValue(1)
    overlay.glow:GetStatusBarTexture():SetBlendMode("ADD")
    overlay.glow:SetFrameLevel(overlay:GetFrameLevel() - 1)
    
    -- Pulse animation (fast pulse for threat - urgent feel)
    overlay.pulseAnim = overlay:CreateAnimationGroup()
    overlay.pulseAnim:SetLooping("REPEAT")
    
    local fadeOut = overlay.pulseAnim:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0.5)
    fadeOut:SetDuration(0.3)
    fadeOut:SetOrder(1)
    fadeOut:SetSmoothing("IN_OUT")
    
    local fadeIn = overlay.pulseAnim:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0.5)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(0.3)
    fadeIn:SetOrder(2)
    fadeIn:SetSmoothing("IN_OUT")
    
    overlay:Hide()
    frame.threatOverlay = overlay
    
    return overlay
end

-- ============================================================================
-- OVERLAY LAYOUT
-- ============================================================================

local function ApplyLayout(overlay, settings)
    if not overlay then return end
    
    local borderSize = settings.borderSize or 2
    local showGlow = settings.showGlow ~= false
    local glowSize = settings.glowSize or 4
    
    -- Position borders
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
    
    -- Position glow (slightly larger than frame)
    if showGlow then
        overlay.glow:ClearAllPoints()
        overlay.glow:SetPoint("TOPLEFT", -glowSize, glowSize)
        overlay.glow:SetPoint("BOTTOMRIGHT", glowSize, -glowSize)
        overlay.glow:SetAlpha(settings.glowAlpha or 0.3)
    end
end

-- ============================================================================
-- SHOW/HIDE OVERLAY
-- ============================================================================

local function ShowOverlay(overlay, settings)
    if not overlay then return end
    
    local showBorder = settings.showBorder ~= false
    local showGlow = settings.showGlow ~= false
    local showPulse = settings.showPulse ~= false
    local alpha = settings.borderAlpha or 0.9
    
    -- Always use red
    local r, g, b = THREAT_COLOR.r, THREAT_COLOR.g, THREAT_COLOR.b
    
    ApplyLayout(overlay, settings)
    
    -- Apply to borders
    if showBorder then
        overlay.borderTop:GetStatusBarTexture():SetVertexColor(r, g, b, alpha)
        overlay.borderTop:Show()
        
        overlay.borderBottom:GetStatusBarTexture():SetVertexColor(r, g, b, alpha)
        overlay.borderBottom:Show()
        
        overlay.borderLeft:GetStatusBarTexture():SetVertexColor(r, g, b, alpha)
        overlay.borderLeft:Show()
        
        overlay.borderRight:GetStatusBarTexture():SetVertexColor(r, g, b, alpha)
        overlay.borderRight:Show()
    else
        overlay.borderTop:Hide()
        overlay.borderBottom:Hide()
        overlay.borderLeft:Hide()
        overlay.borderRight:Hide()
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

local function HideOverlay(overlay)
    if not overlay then return end
    
    overlay:Hide()
    overlay.pulseAnim:Stop()
    overlay:SetAlpha(1)
    
    overlay.borderTop:Hide()
    overlay.borderBottom:Hide()
    overlay.borderLeft:Hide()
    overlay.borderRight:Hide()
    overlay.glow:Hide()
end

-- ============================================================================
-- GET THREAT STATUS
-- ============================================================================

function ThreatOverlay:GetThreatStatus(unit)
    if not unit or not UnitExists(unit) then return 0 end
    
    -- UnitThreatSituation returns:
    -- nil = Unit not on threat list
    -- 0 = Not tanking, lower threat than tank
    -- 1 = Not tanking, higher threat than tank
    -- 2 = Not tanking, about to pull aggro
    -- 3 = Tanking, has aggro
    local status = UnitThreatSituation(unit)
    return status or 0
end

-- ============================================================================
-- UPDATE OVERLAY FOR FRAME
-- ============================================================================

function ThreatOverlay:UpdateOverlay(frame, settings)
    if not frame or not frame.unit then return end
    
    -- Check if enabled
    if not settings or not settings.enabled then
        if frame.threatOverlay then
            HideOverlay(frame.threatOverlay)
            frame.tuiLastThreatState = nil
        end
        return
    end
    
    local unit = frame.unit
    
    -- Check if unit exists
    if not UnitExists(unit) then
        if frame.threatOverlay then
            HideOverlay(frame.threatOverlay)
            frame.tuiLastThreatState = nil
        end
        return
    end
    
    -- Get threat status
    local threatStatus = self:GetThreatStatus(unit)
    
    -- PERFORMANCE OPTIMIZATION: Cache threat state to skip redundant updates
    if frame.tuiLastThreatState == threatStatus then
        return  -- Same state, skip update
    end
    frame.tuiLastThreatState = threatStatus
    
    -- No threat = hide
    if threatStatus == 0 then
        if frame.threatOverlay then
            HideOverlay(frame.threatOverlay)
        end
        return
    end
    
    -- Check "only tanking" setting (only show status 3)
    if settings.onlyTanking and threatStatus < 3 then
        if frame.threatOverlay then
            HideOverlay(frame.threatOverlay)
        end
        return
    end
    
    -- Ensure overlay exists
    local overlay = self:CreateOverlay(frame)
    
    -- Show red overlay
    ShowOverlay(overlay, settings)
end

-- ============================================================================
-- BATCH UPDATE FUNCTIONS
-- ============================================================================

function ThreatOverlay:UpdatePartyOverlays(partyFrames, settings)
    if not partyFrames then return end
    
    for _, frame in ipairs(partyFrames) do
        if frame and frame:IsShown() then
            self:UpdateOverlay(frame, settings)
        end
    end
end

function ThreatOverlay:UpdateRaidOverlays(raidFrames, settings)
    if not raidFrames then return end
    
    for _, frame in ipairs(raidFrames) do
        if frame and frame:IsShown() then
            self:UpdateOverlay(frame, settings)
        end
    end
end

function ThreatOverlay:HideAll(frames)
    if not frames then return end
    
    for _, frame in ipairs(frames) do
        if frame and frame.threatOverlay then
            HideOverlay(frame.threatOverlay)
        end
    end
end

-- ============================================================================
-- EVENT HANDLING
-- ============================================================================

local eventFrame = CreateFrame("Frame")
local updateThrottle = 0.1
local lastUpdate = 0

local function UpdateUnitThreat(unit)
    local UnitFrames = TweaksUI.UnitFrames
    if not UnitFrames then return end
    
    -- Update party frames
    local partyFrames = UnitFrames:GetPartyMemberFrames()
    local partySettings = UnitFrames:GetPartySettings()
    
    if partyFrames and partySettings and partySettings.threatOverlay and partySettings.threatOverlay.enabled then
        for _, frame in ipairs(partyFrames) do
            if frame and frame.unit then
                local isSameUnit = false
                pcall(function()
                    isSameUnit = UnitIsUnit(frame.unit, unit)
                end)
                
                if isSameUnit then
                    ThreatOverlay:UpdateOverlay(frame, partySettings.threatOverlay)
                    return
                end
            end
        end
    end
    
    -- Update raid frames
    local raidFrames = UnitFrames:GetRaidMemberFrames()
    local raidSettings = UnitFrames:GetCurrentRaidSettings()
    
    if raidFrames and raidSettings and raidSettings.threatOverlay and raidSettings.threatOverlay.enabled then
        for _, frame in ipairs(raidFrames) do
            if frame and frame.unit then
                local isSameUnit = false
                pcall(function()
                    isSameUnit = UnitIsUnit(frame.unit, unit)
                end)
                
                if isSameUnit then
                    ThreatOverlay:UpdateOverlay(frame, raidSettings.threatOverlay)
                    return
                end
            end
        end
    end
end

local function UpdateAllThreat()
    local UnitFrames = TweaksUI.UnitFrames
    if not UnitFrames then return end
    
    local partyFrames = UnitFrames:GetPartyMemberFrames()
    local partySettings = UnitFrames:GetPartySettings()
    if partyFrames and partySettings and partySettings.threatOverlay then
        ThreatOverlay:UpdatePartyOverlays(partyFrames, partySettings.threatOverlay)
    end
    
    local raidFrames = UnitFrames:GetRaidMemberFrames()
    local raidSettings = UnitFrames:GetCurrentRaidSettings()
    if raidFrames and raidSettings and raidSettings.threatOverlay then
        ThreatOverlay:UpdateRaidOverlays(raidFrames, raidSettings.threatOverlay)
    end
end

eventFrame:SetScript("OnEvent", function(self, event, unit, ...)
    if event == "UNIT_THREAT_SITUATION_UPDATE" then
        if unit then
            UpdateUnitThreat(unit)
        else
            -- No specific unit, update all
            UpdateAllThreat()
        end
    elseif event == "UNIT_THREAT_LIST_UPDATE" then
        -- Throttle full updates
        local now = GetTime()
        if now - lastUpdate > updateThrottle then
            lastUpdate = now
            UpdateAllThreat()
        end
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.1, UpdateAllThreat)
    elseif event == "PLAYER_TARGET_CHANGED" then
        -- Target changed can affect threat display
        UpdateAllThreat()
    end
end)

function ThreatOverlay:Start()
    eventFrame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
    eventFrame:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
end

function ThreatOverlay:Stop()
    eventFrame:UnregisterEvent("UNIT_THREAT_SITUATION_UPDATE")
    eventFrame:UnregisterEvent("UNIT_THREAT_LIST_UPDATE")
    eventFrame:UnregisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:UnregisterEvent("PLAYER_TARGET_CHANGED")
end

-- Auto-start
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:HookScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        ThreatOverlay:Start()
    end
end)

return ThreatOverlay
