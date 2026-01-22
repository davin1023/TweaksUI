-- TweaksUI Unit Frames - Range Fade System
-- Fades party frame elements when units are out of range

local ADDON_NAME, TweaksUI = ...

-- Module reference (will be set during init)
local UnitFrames = nil

-- ============================================================================
-- RANGE FADE MODULE
-- ============================================================================

local RangeFade = {
    -- Update ticker
    ticker = nil,
    
    -- Is the system active
    active = false,
}

-- Export to TweaksUI namespace
TweaksUI.UnitFramesRangeFade = RangeFade

-- ============================================================================
-- DEFAULT SETTINGS
-- ============================================================================

RangeFade.DEFAULTS = {
    enabled = true,
    checkInterval = 0.2,  -- Update frequency in seconds
    
    -- Overall fade when out of range (if perElementFade is false)
    outOfRangeAlpha = 0.4,
    
    -- Per-element alpha control
    perElementFade = true,
    elementAlphas = {
        healthBar = 0.2,
        powerBar = 0.2,
        background = 0.1,
        nameText = 1.0,      -- Keep names visible!
        healthText = 0.25,
        auras = 0.2,
        icons = 0.5,         -- Role, leader, raid target
        dispelIndicator = 0.2,
        defensiveIcon = 0.5,
        absorbBar = 0.2,
    },
}

-- ============================================================================
-- HELPER: SAFE ALPHA APPLICATION
-- ============================================================================

-- Apply alpha using SetAlphaFromBoolean if available (Midnight secret value compatible)
-- Falls back to simple SetAlpha if not
local function ApplyAlpha(element, inRange, inRangeAlpha, outOfRangeAlpha)
    if not element then return end
    
    -- SetAlphaFromBoolean is a native widget method that handles secret values
    if element.SetAlphaFromBoolean then
        element:SetAlphaFromBoolean(inRange, inRangeAlpha, outOfRangeAlpha)
    else
        -- Fallback for elements without the method
        -- Note: inRange might be a secret value, so we need pcall
        local success, result = pcall(function()
            if inRange then
                return inRangeAlpha
            else
                return outOfRangeAlpha
            end
        end)
        
        if success then
            element:SetAlpha(result)
        else
            -- If inRange is a secret, try to use it as a boolean
            -- This is a last resort and may not work perfectly
            element:SetAlpha(outOfRangeAlpha)
        end
    end
end

-- ============================================================================
-- RANGE CHECK
-- ============================================================================

-- Check if Edit Mode is currently active (to prevent taint issues)
local function IsEditModeActive()
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
        return true
    end
    if EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive() then
        return true
    end
    return false
end

-- Check if a unit is in range
-- Returns true if in range, false if out of range
-- NEVER returns secret values - always converts to boolean
local function IsUnitInRange(unit)
    if not unit then return true end
    
    -- Skip range checks during Edit Mode to prevent taint
    if IsEditModeActive() then
        return true
    end
    
    -- Check test mode first
    local TestMode = TweaksUI.UnitFramesTestMode
    if TestMode and TestMode:IsActive() then
        local testData = TestMode:GetDataByUnit(unit)
        if testData then
            return testData.inRange ~= false  -- Default to true if not set
        end
    end
    
    -- Real unit checks
    if not UnitExists(unit) then return true end
    
    -- Player is always in range of themselves
    if UnitIsUnit(unit, "player") then return true end
    
    -- Must be in a group to check range
    if not (IsInGroup() or IsInRaid()) then return true end
    
    -- Try UnitInRange first (most accurate for friendly players)
    -- In Midnight instances during combat, may return a secret value
    local inRange = UnitInRange(unit)
    
    -- Check if we got an explicit true
    local successTrue, _ = pcall(function()
        if inRange == true then return true end
        error("not true")
    end)
    if successTrue then
        return true
    end
    
    -- Check if we got an explicit false
    local successFalse, _ = pcall(function()
        if inRange == false then return true end
        error("not false")
    end)
    if successFalse then
        return false
    end
    
    -- UnitInRange returned nil or a secret value
    -- For FRIENDLY units (party/raid members), the fallback methods don't work:
    -- - CheckInteractDistance is for hostile/neutral units
    -- - IsItemInRange requires having the specific item
    -- So for friendly units, default to in-range when we can't determine
    if UnitIsFriend("player", unit) then
        return true
    end
    
    -- For non-friendly units, try fallback methods
    local interactDist = CheckInteractDistance(unit, 4) -- 28 yards
    
    -- Check explicit true
    local distTrue, _ = pcall(function()
        if interactDist == true then return true end
        error("not true")
    end)
    if distTrue then
        return true
    end
    
    -- Check explicit false
    local distFalse, _ = pcall(function()
        if interactDist == false then return true end
        error("not false")
    end)
    if distFalse then
        return false
    end
    
    -- Try IsItemInRange with a ranged item as another fallback (35 yards)
    local inItemRange = IsItemInRange(34471, unit) -- Vial of the Sunwell
    
    -- Check explicit true
    local itemTrue, _ = pcall(function()
        if inItemRange == true then return true end
        error("not true")
    end)
    if itemTrue then
        return true
    end
    
    -- Check explicit false
    local itemFalse, _ = pcall(function()
        if inItemRange == false then return true end
        error("not false")
    end)
    if itemFalse then
        return false
    end
    
    -- Can't determine range at all - assume in range
    return true
end

-- ============================================================================
-- APPLY RANGE FADE TO A FRAME
-- ============================================================================

function RangeFade:UpdateFrameRange(frame, settings)
    if not frame or not frame.unit then return end
    
    -- Get settings
    settings = settings or self.DEFAULTS
    
    -- Skip if disabled
    if not settings.enabled then
        -- Reset to full alpha only if not already reset
        if frame.tuiRangeFadeApplied then
            ApplyAlpha(frame, true, 1.0, 1.0)
            frame.tuiRangeFadeApplied = false
            frame.tuiLastRangeState = nil
        end
        return
    end
    
    local unit = frame.unit
    
    -- Skip if dead fade is active (dead fade takes priority)
    if frame.tuiDeadFadeApplied then
        return
    end
    
    -- Player is always in range of themselves
    if UnitIsUnit(unit, "player") then
        if not frame.tuiRangeFadeApplied or frame.tuiLastRangeState ~= true then
            ApplyAlpha(frame, true, 1.0, 1.0)
            frame.tuiLastRangeState = true
            frame.tuiInRange = true
            frame.tuiRangeFadeApplied = true
        end
        return
    end
    
    -- Check test mode first
    local TestMode = TweaksUI.UnitFramesTestMode
    if TestMode and TestMode:IsActive() then
        local testData = TestMode:GetDataByUnit(unit)
        if testData then
            local testInRange = testData.inRange ~= false
            if frame.tuiLastRangeState ~= testInRange then
                ApplyAlpha(frame, testInRange, 1.0, settings.outOfRangeAlpha or 0.4)
                frame.tuiLastRangeState = testInRange
                frame.tuiInRange = testInRange
            end
            frame.tuiRangeFadeApplied = true
            return
        end
    end
    
    -- Skip if unit doesn't exist
    if not UnitExists(unit) then
        if frame.tuiLastRangeState ~= true then
            ApplyAlpha(frame, true, 1.0, 1.0)
            frame.tuiLastRangeState = true
            frame.tuiInRange = true
        end
        return
    end
    
    -- Must be in a group to check range
    if not (IsInGroup() or IsInRaid()) then
        if frame.tuiLastRangeState ~= true then
            ApplyAlpha(frame, true, 1.0, 1.0)
            frame.tuiLastRangeState = true
            frame.tuiInRange = true
        end
        return
    end
    
    -- Get the raw UnitInRange result (may be true, false, nil, or secret)
    -- CRITICAL: Pass this directly to SetAlphaFromBoolean - do NOT try to compare it
    local inRange = UnitInRange(unit)
    
    -- SetAlphaFromBoolean can handle secret values natively
    -- We mark that we've applied range fade
    frame.tuiRangeFadeApplied = true
    
    -- Get alpha settings
    local inRangeAlpha = 1.0
    local outOfRangeAlpha = settings.outOfRangeAlpha or 0.4
    
    -- Handle nil from UnitInRange (can't determine = assume in range)
    -- Note: nil is NOT a secret value, it's a real nil
    if inRange == nil then
        inRange = true
    end
    
    -- Apply alpha using SetAlphaFromBoolean (handles secrets)
    if settings.perElementFade then
        -- Per-element alpha mode
        local elementAlphas = settings.elementAlphas or self.DEFAULTS.elementAlphas
        
        -- Frame itself stays full alpha
        ApplyAlpha(frame, true, 1.0, 1.0)
        
        -- Health bar
        local healthAlpha = elementAlphas.healthBar or 0.2
        ApplyAlpha(frame.healthBar, inRange, 1.0, healthAlpha)
        
        -- Health bar background (if separate)
        if frame.healthBar and frame.healthBar.bg then
            ApplyAlpha(frame.healthBar.bg, inRange, 1.0, healthAlpha)
        end
        
        -- Power bar
        local powerAlpha = elementAlphas.powerBar or 0.2
        ApplyAlpha(frame.powerBar, inRange, 1.0, powerAlpha)
        
        -- Background
        local bgAlpha = elementAlphas.background or 0.1
        if frame.background then
            ApplyAlpha(frame.background, inRange, 1.0, bgAlpha)
        end
        -- For BackdropTemplate frames
        if frame.SetBackdropColor then
            -- Can't easily fade backdrop with SetAlphaFromBoolean
            -- Use the frame reference stored during creation
            if frame.backdropFrame then
                ApplyAlpha(frame.backdropFrame, inRange, 1.0, bgAlpha)
            end
        end
        
        -- Name text
        local nameAlpha = elementAlphas.nameText or 1.0
        ApplyAlpha(frame.nameText, inRange, 1.0, nameAlpha)
        
        -- Health text
        local healthTextAlpha = elementAlphas.healthText or 0.25
        ApplyAlpha(frame.healthText, inRange, 1.0, healthTextAlpha)
        
        -- Auras (buffs and debuffs)
        local auraAlpha = elementAlphas.auras or 0.2
        if frame.buffIcons then
            for _, icon in ipairs(frame.buffIcons) do
                ApplyAlpha(icon, inRange, 1.0, auraAlpha)
            end
        end
        if frame.debuffIcons then
            for _, icon in ipairs(frame.debuffIcons) do
                ApplyAlpha(icon, inRange, 1.0, auraAlpha)
            end
        end
        
        -- Icons (role, leader, raid target, ready check)
        local iconAlpha = elementAlphas.icons or 0.5
        ApplyAlpha(frame.roleIcon, inRange, 1.0, iconAlpha)
        ApplyAlpha(frame.leaderIcon, inRange, 1.0, iconAlpha)
        ApplyAlpha(frame.raidTargetIcon, inRange, 1.0, iconAlpha)
        ApplyAlpha(frame.readyCheckIcon, inRange, 1.0, iconAlpha)
        ApplyAlpha(frame.summonIcon, inRange, 1.0, iconAlpha)
        
        -- Dispel indicator
        local dispelAlpha = elementAlphas.dispelIndicator or 0.2
        ApplyAlpha(frame.dispelIndicator, inRange, 1.0, dispelAlpha)
        if frame.dispelOverlay then
            ApplyAlpha(frame.dispelOverlay, inRange, 1.0, dispelAlpha)
        end
        
        -- Defensive icon (future feature)
        local defAlpha = elementAlphas.defensiveIcon or 0.5
        ApplyAlpha(frame.defensiveIcon, inRange, 1.0, defAlpha)
        
        -- Absorb bar
        local absorbAlpha = elementAlphas.absorbBar or 0.2
        ApplyAlpha(frame.absorbBar, inRange, 1.0, absorbAlpha)
        
    else
        -- Simple frame-level alpha mode
        -- Reset all elements to full alpha first
        ApplyAlpha(frame.healthBar, true, 1.0, 1.0)
        ApplyAlpha(frame.powerBar, true, 1.0, 1.0)
        ApplyAlpha(frame.nameText, true, 1.0, 1.0)
        ApplyAlpha(frame.healthText, true, 1.0, 1.0)
        ApplyAlpha(frame.roleIcon, true, 1.0, 1.0)
        
        -- Apply frame-level alpha
        ApplyAlpha(frame, inRange, inRangeAlpha, outOfRangeAlpha)
    end
end

-- ============================================================================
-- UPDATE ALL PARTY FRAMES
-- ============================================================================

function RangeFade:UpdateAllFrames(frames, settings)
    if not frames then return end
    
    for i, frame in pairs(frames) do
        if frame and frame:IsShown() then
            self:UpdateFrameRange(frame, settings)
        end
    end
end

-- ============================================================================
-- RANGE UPDATE TICKER
-- ============================================================================

local function OnRangeTick()
    -- Get party frames from UnitFrames module
    if not UnitFrames then 
        if RangeFade.debugMode then print("[RangeFade] UnitFrames module not found") end
        return 
    end
    
    -- CRITICAL: Skip range updates during Edit Mode to prevent taint
    -- Edit Mode refreshes Blizzard's CompactUnitFrames and any taint can cause errors
    if IsEditModeActive() then
        return
    end
    
    -- Also skip if TUI Layout Mode is active
    if TweaksUI.Layout and TweaksUI.Layout:IsActive() then
        return
    end
    
    -- In raids, we use a counter to reduce frequency (performance optimization)
    -- Raids check every other tick (effectively 0.4s instead of 0.2s)
    if IsInRaid() then
        RangeFade.raidTickCounter = (RangeFade.raidTickCounter or 0) + 1
        if RangeFade.raidTickCounter < 2 then
            return  -- Skip this tick for raids
        end
        RangeFade.raidTickCounter = 0
    end
    
    -- Update party frames (only when not in raid)
    if not IsInRaid() then
        local partyMemberFrames = UnitFrames:GetPartyMemberFrames()
        if partyMemberFrames then
            -- Use UnitFrames helper to get proper settings
            local partySettings = nil
            local ps = UnitFrames:GetPartySettings()
            if ps then
                partySettings = ps.rangeFade
            end
            
            -- Debug output
            if RangeFade.debugMode then
                local frameCount = 0
                for _ in pairs(partyMemberFrames) do frameCount = frameCount + 1 end
                print("[RangeFade] Party frames: " .. frameCount .. ", Settings enabled: " .. tostring(partySettings and partySettings.enabled))
            end
            
            partySettings = partySettings or RangeFade.DEFAULTS
            RangeFade:UpdateAllFrames(partyMemberFrames, partySettings)
        elseif RangeFade.debugMode then
            print("[RangeFade] No party frames returned")
        end
    end
    
    -- Update raid frames if in raid
    if IsInRaid() then
        local raidFrames = UnitFrames:GetRaidMemberFrames()
        if raidFrames then
            -- Use UnitFrames helper to get proper raid settings
            local raidSettings = nil
            local rs = UnitFrames:GetCurrentRaidSettings()
            if rs then
                raidSettings = rs.rangeFade
            end
            
            -- Debug output
            if RangeFade.debugMode then
                local frameCount = 0
                for _ in pairs(raidFrames) do frameCount = frameCount + 1 end
                print("[RangeFade] Raid frames: " .. frameCount .. ", Settings enabled: " .. tostring(raidSettings and raidSettings.enabled))
            end
            
            raidSettings = raidSettings or RangeFade.DEFAULTS
            RangeFade:UpdateAllFrames(raidFrames, raidSettings)
        elseif RangeFade.debugMode then
            print("[RangeFade] No raid frames returned")
        end
    end
end

function RangeFade:Start(interval)
    if self.ticker then
        self.ticker:Cancel()
    end
    
    interval = interval or self.DEFAULTS.checkInterval
    self.ticker = C_Timer.NewTicker(interval, OnRangeTick)
    self.active = true
    
    TweaksUI:PrintDebug("RangeFade ticker started (" .. interval .. "s interval)")
end

function RangeFade:Stop()
    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end
    self.active = false
    
    TweaksUI:PrintDebug("RangeFade ticker stopped")
end

function RangeFade:Restart(interval)
    self:Stop()
    self:Start(interval)
end

function RangeFade:IsActive()
    return self.active
end

-- ============================================================================
-- RESET FRAME ALPHAS
-- ============================================================================

-- Reset all elements to full alpha (for when disabled or destroyed)
function RangeFade:ResetFrame(frame)
    if not frame then return end
    
    frame.tuiInRange = true
    
    ApplyAlpha(frame, true, 1.0, 1.0)
    ApplyAlpha(frame.healthBar, true, 1.0, 1.0)
    ApplyAlpha(frame.powerBar, true, 1.0, 1.0)
    ApplyAlpha(frame.nameText, true, 1.0, 1.0)
    ApplyAlpha(frame.healthText, true, 1.0, 1.0)
    ApplyAlpha(frame.roleIcon, true, 1.0, 1.0)
    ApplyAlpha(frame.leaderIcon, true, 1.0, 1.0)
    ApplyAlpha(frame.raidTargetIcon, true, 1.0, 1.0)
    
    if frame.buffIcons then
        for _, icon in ipairs(frame.buffIcons) do
            ApplyAlpha(icon, true, 1.0, 1.0)
        end
    end
    if frame.debuffIcons then
        for _, icon in ipairs(frame.debuffIcons) do
            ApplyAlpha(icon, true, 1.0, 1.0)
        end
    end
end

function RangeFade:ResetAllFrames(frames)
    -- If specific frames provided, reset those
    if frames then
        for i, frame in pairs(frames) do
            if frame then
                self:ResetFrame(frame)
            end
        end
        return
    end
    
    -- Otherwise reset all party and raid frames
    if UnitFrames then
        local partyFrames = UnitFrames:GetPartyMemberFrames() or {}
        for _, frame in pairs(partyFrames) do
            if frame then
                self:ResetFrame(frame)
            end
        end
        
        local raidFrames = UnitFrames:GetRaidMemberFrames() or {}
        for _, frame in pairs(raidFrames) do
            if frame then
                self:ResetFrame(frame)
            end
        end
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function RangeFade:Init(unitFramesModule)
    UnitFrames = unitFramesModule
    
    -- Add methods to UnitFrames for integration
    if UnitFrames then
        -- Method to get party frames (will be implemented in main module)
        if not UnitFrames.GetPartyMemberFrames then
            UnitFrames.GetPartyMemberFrames = function(self)
                return nil  -- Will be overridden
            end
        end
        
        -- Method to get range fade settings
        if not UnitFrames.GetRangeFadeSettings then
            UnitFrames.GetRangeFadeSettings = function(self)
                return RangeFade.DEFAULTS
            end
        end
    end
    
    TweaksUI:PrintDebug("UnitFrames RangeFade initialized")
end

-- ============================================================================
-- DEBUG COMMAND
-- ============================================================================

SLASH_TUIRANGE1 = "/tuirange"
SlashCmdList["TUIRANGE"] = function(msg)
    local args = {}
    for arg in msg:gmatch("%S+") do
        table.insert(args, arg:lower())
    end
    
    local cmd = args[1] or "status"
    
    if cmd == "on" or cmd == "start" then
        RangeFade:Start()
        print("|cff00ff00TweaksUI:|r Range fade started")
        
    elseif cmd == "off" or cmd == "stop" then
        RangeFade:Stop()
        print("|cff00ff00TweaksUI:|r Range fade stopped")
        
    elseif cmd == "reset" then
        if UnitFrames then
            local frames = UnitFrames:GetPartyMemberFrames()
            RangeFade:ResetAllFrames(frames)
        end
        print("|cff00ff00TweaksUI:|r Frame alphas reset")
        
    elseif cmd == "debug" then
        RangeFade.debugMode = not RangeFade.debugMode
        print("|cff00ff00TweaksUI:|r Range fade debug mode: " .. (RangeFade.debugMode and "ON" or "OFF"))
        
    elseif cmd == "status" then
        print("|cff00ccffTweaksUI Range Fade Status:|r")
        print("  Active: " .. tostring(RangeFade.active))
        print("  Ticker: " .. tostring(RangeFade.ticker ~= nil))
        print("  Debug Mode: " .. tostring(RangeFade.debugMode))
        
        -- Check settings access
        if UnitFrames then
            local ps = UnitFrames:GetPartySettings()
            if ps then
                print("  Party Settings: FOUND")
                print("    party.enabled: " .. tostring(ps.enabled))
                if ps.rangeFade then
                    print("    rangeFade.enabled: " .. tostring(ps.rangeFade.enabled))
                else
                    print("    rangeFade: NIL")
                end
            else
                print("  Party Settings: NIL")
            end
            
            local rs = UnitFrames:GetCurrentRaidSettings()
            if rs then
                print("  Raid Settings: FOUND")
                if rs.rangeFade then
                    print("    rangeFade.enabled: " .. tostring(rs.rangeFade.enabled))
                else
                    print("    rangeFade: NIL")
                end
            else
                print("  Raid Settings: NIL (not in raid or not configured)")
            end
        end
        
        -- Show range status for party members
        if UnitFrames then
            local frames = UnitFrames:GetPartyMemberFrames()
            if frames then
                local count = 0
                for _ in pairs(frames) do count = count + 1 end
                print("  Party Frames: " .. count)
                if count == 0 then
                    print("    |cffff8800(No TUI party frames - are they enabled?)|r")
                end
                for i, frame in pairs(frames) do
                    if frame and frame.unit then
                        local inRange = frame.tuiInRange
                        local shown = frame:IsShown() and "shown" or "hidden"
                        local status = "unknown"
                        if inRange == true then
                            status = "|cff00ff00IN RANGE|r"
                        elseif inRange == false then
                            status = "|cffff0000OUT OF RANGE|r"
                        end
                        print("    " .. frame.unit .. ": " .. status .. " (" .. shown .. ")")
                    end
                end
            else
                print("  Party Frames: nil (table not initialized)")
            end
        end
        
    else
        print("|cff00ff00TweaksUI Range Fade Commands:|r")
        print("  /tuirange [status] - Show status")
        print("  /tuirange on - Start range checking")
        print("  /tuirange off - Stop range checking")
        print("  /tuirange reset - Reset all alphas")
        print("  /tuirange debug - Toggle debug output")
    end
end

return RangeFade
