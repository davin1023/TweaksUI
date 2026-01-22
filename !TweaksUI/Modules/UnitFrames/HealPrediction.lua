-- TweaksUI Unit Frames - Heal Prediction System
-- Shows incoming heals as an overlay on health bars
-- Uses Midnight Beta APIs (UnitHealPredictionCalculator, Duration Objects)

local ADDON_NAME, TweaksUI = ...

-- Module reference (will be set during init)
local UnitFrames = nil

-- ============================================================================
-- MIDNIGHT API FLAGS (v2.0.0)
-- ============================================================================

-- All these APIs are available in Midnight 12.0+
local HAS_HEAL_PREDICTION_CALCULATOR = true
local HAS_UNIT_HEALTH_PERCENT = true
local HAS_ISSECRETVALUE = true

-- Debug flag - set to true to see what's happening
local DEBUG_HEAL_PREDICTION = false

local function DebugPrint(...)
    if DEBUG_HEAL_PREDICTION and TweaksUI.debugMode then
        print("|cFF00FF00[TUI HealPred]|r", ...)
    end
end

-- ============================================================================
-- HEAL PREDICTION MODULE
-- ============================================================================

local HealPrediction = {
    -- Frames we've added prediction bars to
    trackedFrames = {},
    
    -- Update ticker
    ticker = nil,
    
    -- Is the system active
    active = false,
    
    -- Shared calculator for Midnight API (reused to avoid garbage)
    calculator = nil,
}

-- Export to TweaksUI namespace
TweaksUI.UnitFramesHealPrediction = HealPrediction

-- ============================================================================
-- DEFAULT SETTINGS
-- ============================================================================

HealPrediction.DEFAULTS = {
    enabled = true,
    
    -- Visual settings
    myHealsColor = { 0.0, 0.8, 0.2, 0.5 },      -- Green for your heals
    otherHealsColor = { 0.0, 0.6, 0.8, 0.5 },   -- Cyan for others' heals
    allHealsColor = { 0.0, 0.7, 0.4, 0.5 },     -- Teal for combined
    
    -- What to show
    showMyHeals = true,
    showOtherHeals = true,
    separateColors = false,  -- Use different colors for my heals vs others
    
    -- Absorbs (bonus feature)
    showAbsorbs = true,
    absorbColor = { 0.8, 0.8, 0.2, 0.6 },       -- Yellow for absorbs
    absorbOverlay = true,    -- Show as overlay texture vs solid bar
    
    -- Update frequency
    updateInterval = 0.05,  -- 50ms for smooth updates
    
    -- Overflow handling
    maxOverflow = 1.0,      -- Don't show more than 100% of max health
}

-- ============================================================================
-- FRAME CREATION - MIDNIGHT SECRET VALUE COMPATIBLE
-- ============================================================================

-- In Midnight, heal prediction values are SECRET VALUES.
-- We CANNOT do any arithmetic or comparison on them.
-- We MUST pass them directly to StatusBar:SetValue() which accepts secrets.
-- This requires using StatusBar frames instead of textures with calculated widths.

-- Create the heal prediction bar for a frame
function HealPrediction:CreatePredictionBar(frame)
    -- Disabled in retail pre-Midnight
    if IS_RETAIL_PRE_MIDNIGHT then return nil end
    
    if not frame or not frame.healthBar then return nil end
    
    local healthBar = frame.healthBar
    local healthBarTexture = healthBar:GetStatusBarTexture()
    if not healthBarTexture then return nil end
    
    -- Create container for prediction elements
    -- Stay in SAME strata as health bar to maintain positioning!
    -- Use higher frame level + draw layers for visibility
    local container = CreateFrame("Frame", nil, healthBar)
    container:SetAllPoints(healthBar)
    container:SetFrameLevel(healthBar:GetFrameLevel() + 5)
    container:SetClipsChildren(true)  -- IMPORTANT: Clip children to prevent overflow outside health bar
    
    -- Get the texture to use for bars
    local barTexture = healthBarTexture:GetTexture() or "Interface\\TargetingFrame\\UI-StatusBar"
    
    -- MY HEALS BAR - StatusBar that accepts secret values directly
    -- Anchored to start where current health ends
    local myHealBar = CreateFrame("StatusBar", nil, container)
    myHealBar:SetStatusBarTexture(barTexture)
    myHealBar:SetStatusBarColor(0.0, 0.8, 0.2, 0.5)
    myHealBar:SetPoint("TOPLEFT", healthBarTexture, "TOPRIGHT", 0, 0)
    myHealBar:SetPoint("BOTTOMLEFT", healthBarTexture, "BOTTOMRIGHT", 0, 0)
    myHealBar:SetWidth(healthBar:GetWidth()) -- Will be constrained by SetMinMaxValues
    myHealBar:SetMinMaxValues(0, 1)
    myHealBar:SetValue(0)
    myHealBar:SetFrameLevel(container:GetFrameLevel() + 1)
    -- Set texture draw layer explicitly for visibility
    local myHealTexture = myHealBar:GetStatusBarTexture()
    if myHealTexture then
        myHealTexture:SetDrawLayer("ARTWORK", 7)
    end
    myHealBar:Hide()
    
    -- OTHER HEALS BAR - StatusBar for heals from other players
    local otherHealBar = CreateFrame("StatusBar", nil, container)
    otherHealBar:SetStatusBarTexture(barTexture)
    otherHealBar:SetStatusBarColor(0.0, 0.6, 0.8, 0.5)
    otherHealBar:SetPoint("TOPLEFT", myHealBar:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
    otherHealBar:SetPoint("BOTTOMLEFT", myHealBar:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
    otherHealBar:SetWidth(healthBar:GetWidth())
    otherHealBar:SetMinMaxValues(0, 1)
    otherHealBar:SetValue(0)
    otherHealBar:SetFrameLevel(container:GetFrameLevel() + 2)
    local otherHealTexture = otherHealBar:GetStatusBarTexture()
    if otherHealTexture then
        otherHealTexture:SetDrawLayer("ARTWORK", 7)
    end
    otherHealBar:Hide()
    
    -- ABSORB BAR - StatusBar for absorb shields
    local absorbBar = CreateFrame("StatusBar", nil, container)
    absorbBar:SetStatusBarTexture("Interface\\RaidFrame\\Shield-Fill")
    absorbBar:SetStatusBarColor(0.8, 0.8, 0.2, 0.6)
    absorbBar:SetPoint("TOPLEFT", otherHealBar:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
    absorbBar:SetPoint("BOTTOMLEFT", otherHealBar:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
    absorbBar:SetWidth(healthBar:GetWidth())
    absorbBar:SetMinMaxValues(0, 1)
    absorbBar:SetValue(0)
    absorbBar:SetFrameLevel(container:GetFrameLevel() + 3)
    local absorbTexture = absorbBar:GetStatusBarTexture()
    if absorbTexture then
        absorbTexture:SetDrawLayer("ARTWORK", 7)
    end
    absorbBar:Hide()
    
    -- Absorb overlay texture (striped effect on current health)
    local absorbOverlay = container:CreateTexture(nil, "ARTWORK", nil, 6)
    absorbOverlay:SetTexture("Interface\\RaidFrame\\Shield-Overlay", "REPEAT", "REPEAT")
    absorbOverlay:SetHorizTile(true)
    absorbOverlay:SetVertTile(true)
    absorbOverlay:SetPoint("TOPLEFT", healthBarTexture, "TOPLEFT", 0, 0)
    absorbOverlay:SetPoint("BOTTOMRIGHT", healthBarTexture, "BOTTOMRIGHT", 0, 0)
    absorbOverlay:SetAlpha(0.5)
    absorbOverlay:Hide()
    
    -- Store references
    local prediction = {
        container = container,
        myHealBar = myHealBar,
        otherHealBar = otherHealBar,
        absorbBar = absorbBar,
        absorbOverlay = absorbOverlay,
    }
    
    frame.tuiHealPrediction = prediction
    
    return prediction
end

-- ============================================================================
-- UPDATE LOGIC - MIDNIGHT API SUPPORT
-- ============================================================================

-- Safe number conversion that handles Midnight secret values
-- In Midnight, secret values can't be compared, used in arithmetic, or converted with tonumber
local function SafeNumber(value, default)
    default = default or 0
    if value == nil then return default end
    
    -- Check if this is a secret value (Midnight API)
    if HAS_ISSECRETVALUE and issecretvalue(value) then
        DebugPrint("SafeNumber: value is secret, returning default", default)
        return default
    end
    
    -- For non-Midnight or non-secret values, try tonumber
    -- Wrap in pcall in case it's a secret that issecretvalue doesn't catch
    local success, result = pcall(function()
        return tonumber(value)
    end)
    
    if success and result then 
        return result 
    end
    
    DebugPrint("SafeNumber: conversion failed, returning default", default)
    return default
end

-- Initialize the shared calculator for Midnight API
local function EnsureCalculator()
    if HAS_HEAL_PREDICTION_CALCULATOR and not HealPrediction.calculator then
        local success, calc = pcall(CreateUnitHealPredictionCalculator)
        if success and calc then
            HealPrediction.calculator = calc
            DebugPrint("Created HealPredictionCalculator successfully")
        else
            DebugPrint("Failed to create HealPredictionCalculator")
        end
    end
    return HealPrediction.calculator
end

-- Update prediction bars for a single frame
-- MIDNIGHT COMPATIBLE: Passes secret values directly to StatusBar:SetValue()
-- No comparisons or arithmetic on secret values!
function HealPrediction:UpdateFrame(frame, settings)
    if not frame or not frame.unit then return end
    if not frame.healthBar then 
        if DEBUG_HEAL_PREDICTION then
            print("|cFFFF0000[HealPred]|r Frame", frame.unit, "has no healthBar!")
        end
        return 
    end
    
    -- Get or create prediction elements
    local prediction = frame.tuiHealPrediction
    if not prediction then
        prediction = self:CreatePredictionBar(frame)
        if not prediction then return end
    end
    
    settings = settings or self.DEFAULTS
    
    -- Hide everything if disabled
    if not settings.enabled then
        prediction.myHealBar:Hide()
        prediction.otherHealBar:Hide()
        prediction.absorbBar:Hide()
        prediction.absorbOverlay:Hide()
        return
    end
    
    local unit = frame.unit
    
    -- Check test mode first (test mode values are NOT secrets)
    local TestMode = TweaksUI.UnitFramesTestMode
    if TestMode and TestMode:IsActive() then
        local testData = TestMode:GetDataByUnit(unit)
        if testData then
            self:UpdateFrameWithTestData(frame, settings, testData)
            return
        end
    end
    
    -- =========================================================================
    -- MIDNIGHT SECRET VALUE PATH
    -- We pass values directly to StatusBar:SetValue() without any comparison
    -- =========================================================================
    
    if HAS_HEAL_PREDICTION_CALCULATOR then
        self:UpdateFrameMidnight(frame, settings, unit, prediction)
    else
        -- Legacy path for non-Midnight clients
        self:UpdateFrameLegacy(frame, settings, unit, prediction)
    end
end

-- Midnight-specific update: passes secrets directly to StatusBars
function HealPrediction:UpdateFrameMidnight(frame, settings, unit, prediction)
    local calculator = EnsureCalculator()
    if not calculator then
        -- Hide bars if no calculator
        prediction.myHealBar:Hide()
        prediction.otherHealBar:Hide()
        prediction.absorbBar:Hide()
        prediction.absorbOverlay:Hide()
        return
    end
    
    -- Get maxHealth - this is NON-SECRET for player units (per Alpha 6)
    -- For other units it may be secret, but we need it for SetMinMaxValues
    local maxHealth = UnitHealthMax(unit)
    
    -- If maxHealth is secret or nil, we can't show prediction
    -- Use pcall to safely check if we can use it
    local maxHealthNum
    local success = pcall(function()
        maxHealthNum = maxHealth + 0  -- This will error if secret
    end)
    
    if not success or not maxHealthNum or maxHealthNum <= 0 then
        -- maxHealth is secret or invalid, hide bars
        prediction.myHealBar:Hide()
        prediction.otherHealBar:Hide()
        prediction.absorbBar:Hide()
        prediction.absorbOverlay:Hide()
        return
    end
    
    -- Populate calculator with heal data
    -- Second parameter is the healer unit - "player" for our heals
    local calcSuccess = pcall(function()
        UnitGetDetailedHealPrediction(unit, "player", calculator)
    end)
    
    if not calcSuccess then
        prediction.myHealBar:Hide()
        prediction.otherHealBar:Hide()
        prediction.absorbBar:Hide()
        prediction.absorbOverlay:Hide()
        return
    end
    
    -- GetIncomingHeals returns: total, fromHealer, fromOthers, clamped
    -- These are SECRET VALUES - pass them DIRECTLY to SetValue!
    local total, fromPlayer, fromOthers, clamped
    pcall(function()
        total, fromPlayer, fromOthers, clamped = calculator:GetIncomingHeals()
    end)
    
    -- Get absorbs from calculator
    local absorbs
    pcall(function()
        absorbs = calculator:GetAbsorb()
    end)
    
    if DEBUG_HEAL_PREDICTION then
        print("|cFFFFFF00[HealPred Midnight]|r", unit, "maxHP:", maxHealthNum, 
              "- passing secrets to StatusBars")
        -- Check if bars exist (avoid printing secret values!)
        print("  myHealBar exists:", prediction.myHealBar and "YES" or "NO")
        print("  myHealBar parent:", prediction.myHealBar:GetParent() and prediction.myHealBar:GetParent():GetName() or "unnamed")
        print("  myHealBar width:", prediction.myHealBar:GetWidth())
        print("  settings.showMyHeals:", settings.showMyHeals and "YES" or "NO")
        -- Don't print fromPlayer - it's a secret!
        print("  fromPlayer exists:", fromPlayer ~= nil and "YES" or "NO")
    end
    
    -- Apply colors (these are NOT secret dependent)
    local myColor = settings.separateColors and settings.myHealsColor or settings.allHealsColor
    local otherColor = settings.otherHealsColor
    local absorbColor = settings.absorbColor
    
    -- MY HEALS BAR
    -- Using TOTAL heals for better visibility (my + others combined)
    prediction.myHealBar:SetMinMaxValues(0, maxHealthNum)
    prediction.myHealBar:SetStatusBarColor(myColor[1], myColor[2], myColor[3], myColor[4])
    if settings.showMyHeals and total then
        prediction.myHealBar:SetValue(total)  -- SECRET VALUE passed directly! Using TOTAL for visibility
        prediction.myHealBar:Show()
        if DEBUG_HEAL_PREDICTION then
            print("  myHealBar: SetValue(total) called, Show() called")
        end
    else
        prediction.myHealBar:SetValue(0)
        prediction.myHealBar:Hide()
    end
    
    -- OTHER HEALS BAR
    prediction.otherHealBar:SetMinMaxValues(0, maxHealthNum)
    prediction.otherHealBar:SetStatusBarColor(otherColor[1], otherColor[2], otherColor[3], otherColor[4])
    if settings.showOtherHeals and settings.separateColors and fromOthers then
        prediction.otherHealBar:SetValue(fromOthers)  -- SECRET VALUE passed directly!
        prediction.otherHealBar:Show()
    else
        prediction.otherHealBar:SetValue(0)
        prediction.otherHealBar:Hide()
    end
    
    -- ABSORB BAR
    prediction.absorbBar:SetMinMaxValues(0, maxHealthNum)
    prediction.absorbBar:SetStatusBarColor(absorbColor[1], absorbColor[2], absorbColor[3], absorbColor[4])
    if settings.showAbsorbs and absorbs then
        prediction.absorbBar:SetValue(absorbs)  -- SECRET VALUE passed directly!
        prediction.absorbBar:Show()
        
        -- Show overlay on current health
        if settings.absorbOverlay then
            prediction.absorbOverlay:Show()
        else
            prediction.absorbOverlay:Hide()
        end
    else
        prediction.absorbBar:SetValue(0)
        prediction.absorbBar:Hide()
        prediction.absorbOverlay:Hide()
    end
end

-- Legacy update path for non-Midnight clients
function HealPrediction:UpdateFrameLegacy(frame, settings, unit, prediction)
    -- Get health data
    local health = UnitHealth(unit)
    local maxHealth = UnitHealthMax(unit)
    
    local healthNum = SafeNumber(health, 0)
    local maxHealthNum = SafeNumber(maxHealth, 1)
    if maxHealthNum <= 0 then maxHealthNum = 1 end
    
    -- Get incoming heals
    local totalHeals = UnitGetIncomingHeals and UnitGetIncomingHeals(unit)
    local playerHeals = UnitGetIncomingHeals and UnitGetIncomingHeals(unit, "player")
    
    local totalNum = SafeNumber(totalHeals, 0)
    local playerNum = SafeNumber(playerHeals, 0)
    local otherNum = totalNum - playerNum
    if otherNum < 0 then otherNum = 0 end
    
    -- Get absorbs
    local absorbRaw = UnitGetTotalAbsorbs and UnitGetTotalAbsorbs(unit)
    local absorbNum = SafeNumber(absorbRaw, 0)
    
    -- Apply colors
    local myColor = settings.separateColors and settings.myHealsColor or settings.allHealsColor
    local otherColor = settings.otherHealsColor
    local absorbColor = settings.absorbColor
    
    -- MY HEALS BAR
    if settings.showMyHeals and playerNum > 0 then
        prediction.myHealBar:SetMinMaxValues(0, maxHealthNum)
        prediction.myHealBar:SetStatusBarColor(myColor[1], myColor[2], myColor[3], myColor[4])
        prediction.myHealBar:SetValue(playerNum)
        prediction.myHealBar:Show()
    else
        prediction.myHealBar:SetValue(0)
        prediction.myHealBar:Hide()
    end
    
    -- OTHER HEALS BAR
    if settings.showOtherHeals and settings.separateColors and otherNum > 0 then
        prediction.otherHealBar:SetMinMaxValues(0, maxHealthNum)
        prediction.otherHealBar:SetStatusBarColor(otherColor[1], otherColor[2], otherColor[3], otherColor[4])
        prediction.otherHealBar:SetValue(otherNum)
        prediction.otherHealBar:Show()
    else
        prediction.otherHealBar:SetValue(0)
        prediction.otherHealBar:Hide()
    end
    
    -- ABSORB BAR
    if settings.showAbsorbs and absorbNum > 0 then
        prediction.absorbBar:SetMinMaxValues(0, maxHealthNum)
        prediction.absorbBar:SetStatusBarColor(absorbColor[1], absorbColor[2], absorbColor[3], absorbColor[4])
        prediction.absorbBar:SetValue(absorbNum)
        prediction.absorbBar:Show()
        
        if settings.absorbOverlay then
            prediction.absorbOverlay:Show()
        else
            prediction.absorbOverlay:Hide()
        end
    else
        prediction.absorbBar:SetValue(0)
        prediction.absorbBar:Hide()
        prediction.absorbOverlay:Hide()
    end
end

-- Update frame with test mode data (non-secret values)
function HealPrediction:UpdateFrameWithTestData(frame, settings, testData)
    local prediction = frame.tuiHealPrediction
    if not prediction then return end
    
    local maxHealth = testData.maxHealth or 1
    local myHeals = testData.incomingHeal or 0
    local otherHeals = testData.incomingHealOthers or 0
    local absorbs = testData.absorb or 0
    
    local myColor = settings.separateColors and settings.myHealsColor or settings.allHealsColor
    local otherColor = settings.otherHealsColor
    local absorbColor = settings.absorbColor
    
    -- MY HEALS
    if settings.showMyHeals and myHeals > 0 then
        prediction.myHealBar:SetMinMaxValues(0, maxHealth)
        prediction.myHealBar:SetStatusBarColor(myColor[1], myColor[2], myColor[3], myColor[4])
        prediction.myHealBar:SetValue(myHeals)
        prediction.myHealBar:Show()
    else
        prediction.myHealBar:SetValue(0)
        prediction.myHealBar:Hide()
    end
    
    -- OTHER HEALS
    if settings.showOtherHeals and settings.separateColors and otherHeals > 0 then
        prediction.otherHealBar:SetMinMaxValues(0, maxHealth)
        prediction.otherHealBar:SetStatusBarColor(otherColor[1], otherColor[2], otherColor[3], otherColor[4])
        prediction.otherHealBar:SetValue(otherHeals)
        prediction.otherHealBar:Show()
    else
        prediction.otherHealBar:SetValue(0)
        prediction.otherHealBar:Hide()
    end
    
    -- ABSORBS
    if settings.showAbsorbs and absorbs > 0 then
        prediction.absorbBar:SetMinMaxValues(0, maxHealth)
        prediction.absorbBar:SetStatusBarColor(absorbColor[1], absorbColor[2], absorbColor[3], absorbColor[4])
        prediction.absorbBar:SetValue(absorbs)
        prediction.absorbBar:Show()
        
        if settings.absorbOverlay then
            prediction.absorbOverlay:Show()
        else
            prediction.absorbOverlay:Hide()
        end
    else
        prediction.absorbBar:SetValue(0)
        prediction.absorbBar:Hide()
        prediction.absorbOverlay:Hide()
    end
end

-- Update all tracked frames
function HealPrediction:UpdateAllFrames(settings)
    -- Disabled in retail pre-Midnight
    if IS_RETAIL_PRE_MIDNIGHT then return end
    
    if not UnitFrames then return end
    
    -- Get settings from Database module (correct path!)
    local db = TweaksUI.Database and TweaksUI.Database:GetModuleSettings(TweaksUI.MODULE_IDS.UNIT_FRAMES)
    
    -- Update player frame
    local playerFrame = UnitFrames:GetPlayerFrame()
    if playerFrame and playerFrame:IsShown() then
        local playerSettings = db and db.player and db.player.healPrediction
        playerSettings = playerSettings or self.DEFAULTS
        if playerSettings.enabled then
            self:UpdateFrame(playerFrame, playerSettings)
        end
    end
    
    -- Update target frame
    local targetFrame = UnitFrames:GetTargetFrame()
    if targetFrame and targetFrame:IsShown() then
        local targetSettings = db and db.target and db.target.healPrediction
        targetSettings = targetSettings or self.DEFAULTS
        if targetSettings.enabled then
            self:UpdateFrame(targetFrame, targetSettings)
        end
    end
    
    -- Update focus frame
    local focusFrame = UnitFrames:GetFocusFrame()
    if focusFrame and focusFrame:IsShown() then
        local focusSettings = db and db.focus and db.focus.healPrediction
        focusSettings = focusSettings or self.DEFAULTS
        if focusSettings.enabled then
            self:UpdateFrame(focusFrame, focusSettings)
        end
    end
    
    -- Update party frames
    local partyFrames = UnitFrames:GetPartyMemberFrames() or {}
    local partySettings = settings
    if not partySettings and db and db.party then
        partySettings = db.party.healPrediction
    end
    partySettings = partySettings or self.DEFAULTS
    
    for _, frame in pairs(partyFrames) do
        self:UpdateFrame(frame, partySettings)
    end
    
    -- Update raid frames if in raid
    if IsInRaid() then
        local raidFrames = UnitFrames:GetRaidMemberFrames() or {}
        
        -- Get appropriate raid settings (small or large)
        local raidSettings = nil
        if db and db.raid then
            local raidSize = GetNumGroupMembers()
            local threshold = db.raid.sizeThreshold or 20
            if raidSize <= threshold then
                raidSettings = db.raid.small and db.raid.small.healPrediction
            else
                raidSettings = db.raid.large and db.raid.large.healPrediction
            end
        end
        raidSettings = raidSettings or self.DEFAULTS
        
        for _, frame in pairs(raidFrames) do
            self:UpdateFrame(frame, raidSettings)
        end
    end
end

-- ============================================================================
-- TICKER SYSTEM
-- ============================================================================

function HealPrediction:Start(interval)
    -- Disabled in retail pre-Midnight
    if IS_RETAIL_PRE_MIDNIGHT then
        TweaksUI:PrintDebug("HealPrediction disabled in retail (pre-Midnight)")
        return
    end
    
    if self.ticker then
        self.ticker:Cancel()
    end
    
    interval = interval or 0.05
    self.active = true
    self.raidTickCounter = 0  -- For raid throttling
    
    self.ticker = C_Timer.NewTicker(interval, function()
        if not self.active then return end
        
        -- In raids, run at 1/6 frequency (0.3s instead of 0.05s) - PERFORMANCE
        -- Heal prediction doesn't need to be as responsive in large raids
        if IsInRaid() then
            self.raidTickCounter = (self.raidTickCounter or 0) + 1
            if self.raidTickCounter < 6 then
                return  -- Skip this tick for raids
            end
            self.raidTickCounter = 0
        end
        
        self:UpdateAllFrames()  -- Settings fetched inside
    end)
    
    TweaksUI:PrintDebug("HealPrediction ticker started (interval: " .. interval .. "s)")
end

function HealPrediction:Stop()
    self.active = false
    
    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end
    
    TweaksUI:PrintDebug("HealPrediction ticker stopped")
end

-- ============================================================================
-- CLEANUP
-- ============================================================================

function HealPrediction:ResetFrame(frame)
    if not frame then return end
    
    local prediction = frame.tuiHealPrediction
    if prediction then
        -- For StatusBars, also reset values to 0
        prediction.myHealBar:SetValue(0)
        prediction.myHealBar:Hide()
        prediction.otherHealBar:SetValue(0)
        prediction.otherHealBar:Hide()
        prediction.absorbBar:SetValue(0)
        prediction.absorbBar:Hide()
        prediction.absorbOverlay:Hide()
    end
end

function HealPrediction:ResetAllFrames(frames)
    -- If specific frames provided, reset those
    if frames then
        for _, frame in pairs(frames) do
            self:ResetFrame(frame)
        end
        return
    end
    
    -- Otherwise reset all frames
    if UnitFrames then
        -- Individual unit frames
        local playerFrame = UnitFrames:GetPlayerFrame()
        if playerFrame then self:ResetFrame(playerFrame) end
        
        local targetFrame = UnitFrames:GetTargetFrame()
        if targetFrame then self:ResetFrame(targetFrame) end
        
        local focusFrame = UnitFrames:GetFocusFrame()
        if focusFrame then self:ResetFrame(focusFrame) end
        
        -- Party frames
        local partyFrames = UnitFrames:GetPartyMemberFrames() or {}
        for _, frame in pairs(partyFrames) do
            self:ResetFrame(frame)
        end
        
        -- Raid frames
        local raidFrames = UnitFrames:GetRaidMemberFrames() or {}
        for _, frame in pairs(raidFrames) do
            self:ResetFrame(frame)
        end
    end
end

-- ============================================================================
-- EVENT HANDLING
-- ============================================================================

local eventFrame = CreateFrame("Frame")
local eventsRegistered = false

local function OnEvent(self, event, ...)
    if not HealPrediction.active then return end
    
    local unit = ...
    
    -- Only care about party/player units
    if unit and (unit == "player" or unit:match("^party%d$")) then
        local frames = UnitFrames and UnitFrames:GetPartyMemberFrames() or {}
        for _, frame in pairs(frames) do
            if frame.unit and UnitIsUnit(frame.unit, unit) then
                local settings = nil
                -- Use UnitFrames helper to get proper settings
                local ps = UnitFrames and UnitFrames:GetPartySettings()
                if ps then
                    settings = ps.healPrediction
                end
                HealPrediction:UpdateFrame(frame, settings)
                break
            end
        end
    end
end

function HealPrediction:RegisterEvents()
    if eventsRegistered then return end
    
    eventFrame:RegisterEvent("UNIT_HEAL_PREDICTION")
    eventFrame:RegisterEvent("UNIT_HEALTH")
    eventFrame:RegisterEvent("UNIT_MAXHEALTH")
    eventFrame:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")
    eventFrame:SetScript("OnEvent", OnEvent)
    
    eventsRegistered = true
    TweaksUI:PrintDebug("HealPrediction events registered")
end

function HealPrediction:UnregisterEvents()
    if not eventsRegistered then return end
    
    eventFrame:UnregisterAllEvents()
    eventFrame:SetScript("OnEvent", nil)
    
    eventsRegistered = false
    TweaksUI:PrintDebug("HealPrediction events unregistered")
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function HealPrediction:Init(unitFramesModule)
    UnitFrames = unitFramesModule
    TweaksUI:PrintDebug("HealPrediction module initialized")
end

-- ============================================================================
-- SLASH COMMAND (for testing)
-- ============================================================================

SLASH_TUIHEAL1 = "/tuiheal"
SlashCmdList["TUIHEAL"] = function(msg)
    local args = {}
    for word in msg:gmatch("%S+") do
        table.insert(args, word:lower())
    end
    
    local cmd = args[1] or "status"
    
    if cmd == "on" or cmd == "enable" then
        HealPrediction:RegisterEvents()
        HealPrediction:Start(0.05)
        print("|cff00ff00TweaksUI:|r Heal Prediction enabled")
        
    elseif cmd == "off" or cmd == "disable" then
        HealPrediction:Stop()
        HealPrediction:UnregisterEvents()
        HealPrediction:ResetAllFrames()
        print("|cff00ff00TweaksUI:|r Heal Prediction disabled")
        
    elseif cmd == "status" then
        print("|cff00ff00TweaksUI Heal Prediction Status:|r")
        print("  Active: " .. (HealPrediction.active and "Yes" or "No"))
        print("  Events: " .. (eventsRegistered and "Registered" or "Not registered"))
        print("  Calculator: " .. (HealPrediction.calculator and "Created" or "None"))
        
    elseif cmd == "api" then
        print("|cff00ff00TweaksUI Heal Prediction API Status:|r")
        print("  CreateUnitHealPredictionCalculator: " .. (HAS_HEAL_PREDICTION_CALCULATOR and "|cff00ff00YES|r" or "|cffff0000NO|r"))
        print("  UnitHealthPercent: " .. (HAS_UNIT_HEALTH_PERCENT and "|cff00ff00YES|r" or "|cffff0000NO|r"))
        print("  issecretvalue: " .. (HAS_ISSECRETVALUE and "|cff00ff00YES|r" or "|cffff0000NO|r"))
        print("  UnitGetIncomingHeals: " .. (UnitGetIncomingHeals and "|cff00ff00YES|r" or "|cffff0000NO|r"))
        print("  UnitGetTotalAbsorbs: " .. (UnitGetTotalAbsorbs and "|cff00ff00YES|r" or "|cffff0000NO|r"))
        
    elseif cmd == "debug" then
        DEBUG_HEAL_PREDICTION = not DEBUG_HEAL_PREDICTION
        print("|cff00ff00TweaksUI:|r Heal Prediction debug: " .. (DEBUG_HEAL_PREDICTION and "ON" or "OFF"))
        
    elseif cmd == "test" then
        -- Force update for testing
        print("|cff00ff00TweaksUI:|r Testing heal prediction on player frame...")
        
        -- Test raw APIs first
        print("|cffFFFF00Raw API Test:|r")
        
        -- Legacy API test
        if UnitGetIncomingHeals then
            local rawTotal = UnitGetIncomingHeals("player")
            local rawPlayer = UnitGetIncomingHeals("player", "player")
            print("  UnitGetIncomingHeals('player'):", tostring(rawTotal))
            print("  UnitGetIncomingHeals('player', 'player'):", tostring(rawPlayer))
            if rawTotal then
                print("    Type:", type(rawTotal))
                if HAS_ISSECRETVALUE then
                    print("    Is secret:", issecretvalue(rawTotal) and "YES" or "NO")
                end
            end
        end
        
        -- Midnight calculator test
        if HAS_HEAL_PREDICTION_CALCULATOR then
            print("|cffFFFF00Midnight Calculator Test:|r")
            local calc = CreateUnitHealPredictionCalculator()
            local success, err = pcall(function()
                UnitGetDetailedHealPrediction("player", "player", calc)
            end)
            if success then
                print("  UnitGetDetailedHealPrediction: SUCCESS")
                local t, p, o, c = calc:GetIncomingHeals()
                print("  GetIncomingHeals() returned:")
                print("    total:", tostring(t), "type:", type(t))
                print("    fromPlayer:", tostring(p), "type:", type(p))
                print("    fromOthers:", tostring(o), "type:", type(o))
                print("    clamped:", tostring(c), "type:", type(c))
                if t and HAS_ISSECRETVALUE then
                    print("    total is secret:", issecretvalue(t) and "YES" or "NO")
                end
            else
                print("  UnitGetDetailedHealPrediction: FAILED -", err)
            end
        end
        
        -- Get player frame
        print("|cffFFFF00Frame Test:|r")
        if UnitFrames then
            local playerFrame = UnitFrames:GetPlayerFrame()
            if playerFrame then
                print("  Player frame found: " .. tostring(playerFrame:GetName() or "unnamed"))
                print("  Health bar: " .. (playerFrame.healthBar and "exists" or "MISSING"))
                
                if playerFrame.healthBar then
                    local statusBarTexture = playerFrame.healthBar:GetStatusBarTexture()
                    print("  StatusBarTexture: " .. (statusBarTexture and "exists" or "MISSING"))
                end
                
                -- Check for existing prediction elements
                if playerFrame.tuiHealPrediction then
                    print("  TUI prediction elements: CREATED")
                    print("    myHealBar shown:", playerFrame.tuiHealPrediction.myHealBar:IsShown() and "YES" or "NO")
                else
                    print("  TUI prediction elements: NOT YET CREATED")
                end
                
                -- Check settings (use proper UnitFrames helper)
                local ufModule = TweaksUI.UnitFrames
                local ps = ufModule and ufModule:GetPartySettings()
                if ps then
                    local settings = ps.healPrediction
                    if settings then
                        print("  Settings found:")
                        print("    enabled:", settings.enabled and "YES" or "NO")
                        print("    showMyHeals:", settings.showMyHeals and "YES" or "NO")
                        print("    showOtherHeals:", settings.showOtherHeals and "YES" or "NO")
                    else
                        print("  Settings: NOT FOUND (will use defaults)")
                    end
                else
                    print("  Party Settings: NOT LOADED")
                end
                
                -- Force an update
                HealPrediction:UpdateFrame(playerFrame)
                print("  Frame updated - check if bar appeared")
            else
                print("  Player frame: NOT FOUND")
            end
        else
            print("  UnitFrames module: NOT LOADED")
        end
    
    elseif cmd == "fakeheal" then
        -- Force show fake heal prediction at a specific percentage on party frames
        local percent = tonumber(args[2]) or 25  -- Default 25%
        print("|cff00ff00TweaksUI:|r Forcing " .. percent .. "% fake heal on all party frames...")
        
        -- Stop ticker so it doesn't overwrite
        HealPrediction:Stop()
        
        local partyFrames = UnitFrames and UnitFrames:GetPartyMemberFrames()
        if not partyFrames then
            print("|cffff0000ERROR:|r No party frames found")
            return
        end
        
        local count = 0
        for i, frame in pairs(partyFrames) do
            if frame and frame.healthBar then
                local prediction = frame.tuiHealPrediction
                if not prediction then
                    prediction = HealPrediction:CreatePredictionBar(frame)
                end
                
                if prediction then
                    -- Use a fake max health value we CAN see
                    local fakeMax = 100000
                    local fakeHeal = fakeMax * (percent / 100)
                    
                    prediction.myHealBar:SetMinMaxValues(0, fakeMax)
                    prediction.myHealBar:SetStatusBarColor(0, 1, 0, 0.8)  -- Bright green
                    prediction.myHealBar:SetValue(fakeHeal)
                    prediction.myHealBar:Show()
                    
                    count = count + 1
                    print(string.format("  Frame %s (%s): bar width=%d, value=%d/%d", 
                        tostring(i), frame.unit or "?", 
                        prediction.myHealBar:GetWidth(),
                        fakeHeal, fakeMax))
                end
            end
        end
        
        print("  Updated " .. count .. " frames with " .. percent .. "% fake heal")
        print("  Use '/tuiheal on' to restore normal behavior")
    
    elseif cmd == "forceshow" then
        -- Force bars to show with fake data to test rendering
        print("|cff00ff00TweaksUI:|r Forcing heal prediction bars to show...")
        
        -- STOP the ticker first so it doesn't overwrite our test!
        HealPrediction:Stop()
        HealPrediction:UnregisterEvents()
        print("  Stopped update ticker and unregistered events")
        
        if not UnitFrames then
            print("|cffff0000ERROR:|r UnitFrames module not loaded")
            return
        end
        
        local playerFrame = UnitFrames:GetPlayerFrame()
        if not playerFrame then
            print("|cffff0000ERROR:|r Player frame not found")
            return
        end
        print("  Player frame:", playerFrame:GetName() or "unnamed")
        
        if not playerFrame.healthBar then
            print("|cffff0000ERROR:|r Player frame has no healthBar")
            return
        end
        print("  healthBar:", playerFrame.healthBar:GetName() or "unnamed")
        print("  healthBar width:", playerFrame.healthBar:GetWidth())
        print("  healthBar height:", playerFrame.healthBar:GetHeight())
        print("  healthBar visible:", playerFrame.healthBar:IsVisible() and "YES" or "NO")
        
        local healthBarTexture = playerFrame.healthBar:GetStatusBarTexture()
        if not healthBarTexture then
            print("|cffff0000ERROR:|r healthBar has no StatusBarTexture")
            return
        end
        print("  healthBar texture:", healthBarTexture:GetTexture())
        
        -- Create a BRAND NEW test bar, not using our prediction system
        print("  Creating fresh test StatusBar...")
        
        -- Remove old test bar if exists
        if TUIHealPredTestBar then
            TUIHealPredTestBar:Hide()
            TUIHealPredTestBar = nil
        end
        
        local testBar = CreateFrame("StatusBar", "TUIHealPredTestBar", playerFrame.healthBar)
        testBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        testBar:SetStatusBarColor(0, 1, 0, 1)  -- Bright green, full opacity
        testBar:SetMinMaxValues(0, 100)
        testBar:SetValue(100)  -- Full fill
        testBar:SetSize(50, playerFrame.healthBar:GetHeight())  -- Fixed 50px width
        -- Anchor to CENTER of health bar so we definitely see it
        testBar:ClearAllPoints()
        testBar:SetPoint("CENTER", playerFrame.healthBar, "CENTER", 0, 0)
        
        -- Use same strata as health bar, just higher frame level
        testBar:SetFrameLevel(playerFrame.healthBar:GetFrameLevel() + 10)
        testBar:Show()
        testBar:SetAlpha(1)
        
        -- Set the StatusBar texture's draw layer explicitly
        local sbTexture = testBar:GetStatusBarTexture()
        if sbTexture then
            sbTexture:SetDrawLayer("ARTWORK", 7)
            print("  Set StatusBarTexture to ARTWORK layer 7")
        end
        
        print("  Frame level:", testBar:GetFrameLevel())
        
        print("  Test bar created:")
        print("    IsShown:", testBar:IsShown() and "YES" or "NO")
        print("    IsVisible:", testBar:IsVisible() and "YES" or "NO")
        print("    Width:", testBar:GetWidth())
        print("    Height:", testBar:GetHeight())
        print("    FrameLevel:", testBar:GetFrameLevel())
        print("    Alpha:", testBar:GetAlpha())
        
        local parent = testBar:GetParent()
        print("    Parent:", parent and (parent:GetName() or "unnamed") or "NONE")
        print("    Parent visible:", parent and parent:IsVisible() and "YES" or "NO")
        
        -- Also create a simple texture as backup test
        if not playerFrame.healthBar.tuiTestTexture then
            local tex = playerFrame.healthBar:CreateTexture(nil, "ARTWORK", nil, 7)  -- ARTWORK layer, sublevel 7
            tex:SetColorTexture(1, 0, 0, 1)  -- BRIGHT RED
            tex:SetSize(30, 30)
            tex:SetPoint("CENTER", playerFrame.healthBar, "CENTER", 0, 0)
            playerFrame.healthBar.tuiTestTexture = tex
            print("  Also created a RED SQUARE texture (ARTWORK layer 7)")
        else
            playerFrame.healthBar.tuiTestTexture:Show()
            print("  Showing existing RED SQUARE texture")
        end
        
        print("")
        print("  |cffFFFF00DO YOU SEE:|r")
        print("    1. A GREEN BAR (50px wide) in center of health bar?")
        print("    2. A RED SQUARE (30x30) in center of health bar?")
        print("")
        print("  If you see NEITHER, the healthBar itself may be the issue.")
        print("  Run '/tuiheal hidebar' to remove, '/tuiheal on' to restart")
        
    elseif cmd == "hidebar" then
        -- Hide the test bar and texture
        if TUIHealPredTestBar then
            TUIHealPredTestBar:Hide()
            TUIHealPredTestBar:SetParent(nil)
            TUIHealPredTestBar = nil
            print("|cff00ff00TweaksUI:|r Test bar removed")
        end
        
        -- Also hide test texture
        if UnitFrames then
            local playerFrame = UnitFrames:GetPlayerFrame()
            if playerFrame and playerFrame.healthBar and playerFrame.healthBar.tuiTestTexture then
                playerFrame.healthBar.tuiTestTexture:Hide()
                print("|cff00ff00TweaksUI:|r Test texture hidden")
            end
        end
        
        if not TUIHealPredTestBar then
            print("|cff00ff00TweaksUI:|r No test elements to remove")
        end
        
    elseif cmd == "testdata" then
        -- Force test mode data to have incoming heals for testing
        local TestMode = TweaksUI.UnitFramesTestMode
        if not TestMode then
            print("|cffff0000TweaksUI:|r TestMode module not loaded")
            return
        end
        
        if not TestMode:IsActive() then
            print("|cffFFFF00TweaksUI:|r Test mode not active. Run '/tuitest on 5' first!")
            return
        end
        
        -- Modify all test members to have incoming heals
        print("|cff00ff00TweaksUI:|r Forcing heal prediction test data...")
        local count = 0
        for _, member in ipairs(TestMode.partyData) do
            if member.maxHealth and member.maxHealth > 0 then
                -- Force health to 60% so there's room for heals
                member.health = math.floor(member.maxHealth * 0.6)
                member.healthPercent = 0.6
                member.targetHealth = member.health
                
                local missingHealth = member.maxHealth - member.health
                -- Force significant incoming heals
                member.incomingHeal = math.floor(missingHealth * 0.4)  -- 40% of missing health
                member.incomingHealOthers = math.floor(missingHealth * 0.25)  -- 25% of missing health
                member.absorb = math.floor(member.maxHealth * 0.15)  -- 15% of max as absorb
                
                count = count + 1
                print(string.format("  %s: HP=%d/%d, myHeal=%d, otherHeal=%d, absorb=%d",
                    member.name or member.unit,
                    member.health, member.maxHealth,
                    member.incomingHeal, member.incomingHealOthers, member.absorb))
            end
        end
        
        print("|cff00ff00TweaksUI:|r Updated " .. count .. " test members with heal data")
        print("  Run '/tuitest refresh' to update frames")
        
    elseif cmd == "party" then
        -- Diagnostic: Check party frames for heal prediction
        print("|cff00ff00TweaksUI Heal Prediction - Party Frame Diagnostics:|r")
        
        if not UnitFrames then
            print("|cffff0000ERROR:|r UnitFrames module not loaded")
            return
        end
        
        local partyFrames = UnitFrames:GetPartyMemberFrames()
        if not partyFrames then
            print("|cffff0000ERROR:|r No party frames table found")
            print("  Party frames may not be created yet.")
            return
        end
        
        -- Count frames
        local frameCount = 0
        for _ in pairs(partyFrames) do frameCount = frameCount + 1 end
        
        if frameCount == 0 then
            print("|cffFFFF00WARNING:|r Party frames table is empty")
            print("  Are you in a group? Are party frames enabled in TweaksUI?")
            return
        end
        
        print("  Found " .. frameCount .. " party frames")
        
        for i, frame in pairs(partyFrames) do
            if frame then
                local unit = frame.unit or "unknown"
                local shown = frame:IsShown() and "YES" or "NO"
                local hasHealthBar = frame.healthBar and "YES" or "NO"
                local hasPrediction = frame.tuiHealPrediction and "YES" or "NO"
                
                print(string.format("  Frame %d: unit=%s, shown=%s, healthBar=%s, prediction=%s",
                    i, unit, shown, hasHealthBar, hasPrediction))
                
                if frame.tuiHealPrediction then
                    local pred = frame.tuiHealPrediction
                    print(string.format("    myHealBar: shown=%s, width=%d",
                        pred.myHealBar:IsShown() and "YES" or "NO",
                        pred.myHealBar:GetWidth() or 0))
                end
            end
        end
        
        -- Check settings (use correct Database path!)
        local db = TweaksUI.Database and TweaksUI.Database:GetModuleSettings(TweaksUI.MODULE_IDS.UNIT_FRAMES)
        if db and db.party and db.party.healPrediction then
            local hp = db.party.healPrediction
            print("  Settings: enabled=" .. tostring(hp.enabled) .. 
                  ", showMyHeals=" .. tostring(hp.showMyHeals) ..
                  ", showAbsorbs=" .. tostring(hp.showAbsorbs))
        else
            print("  |cffFFFF00WARNING:|r No party heal prediction settings found!")
            print("    db exists: " .. tostring(db ~= nil))
            print("    db.party exists: " .. tostring(db and db.party ~= nil))
            if db and db.party then
                print("    db.party.healPrediction exists: " .. tostring(db.party.healPrediction ~= nil))
            end
        end
        
    else
        print("|cff00ff00TweaksUI Heal Prediction Commands:|r")
        print("  /tuiheal on - Enable heal prediction")
        print("  /tuiheal off - Disable heal prediction")
        print("  /tuiheal status - Show current status")
        print("  /tuiheal api - Show API availability")
        print("  /tuiheal debug - Toggle debug output")
        print("  /tuiheal test - Test on player frame")
        print("  /tuiheal fakeheal [%] - Force fake heal % on party frames")
        print("  /tuiheal forceshow - Force bars visible with fake data")
        print("  /tuiheal hidebar - Remove test bar")
        print("  /tuiheal testdata - Force test mode to have heal data")
        print("  /tuiheal party - Diagnose party frame heal prediction")
    end
end

TweaksUI:PrintDebug("HealPrediction.lua loaded")
