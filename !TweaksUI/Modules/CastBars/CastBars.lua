-- ============================================================================
-- TweaksUI: CastBars Module
-- Standalone cast bars for player, target, and focus
-- ============================================================================

local ADDON_NAME, TweaksUI = ...

-- Create the module
local CastBars = TweaksUI.ModuleManager:NewModule(
    TweaksUI.MODULE_IDS.CAST_BARS,
    "Cast Bars",
    "Standalone cast bars for player, target, and focus"
)

-- ============================================================================
-- MIDNIGHT API DETECTION (v1.2.5)
-- ============================================================================

-- Safe value function for Midnight secret values
-- Secret values can be PRINTED but NOT used for arithmetic
-- This function returns the value only if arithmetic is possible
local function SafeValue(value)
    if value == nil then return nil end
    
    -- Test if we can do arithmetic on this value
    local ok, result = pcall(function()
        return value + 0
    end)
    
    if ok then
        return result
    else
        return nil
    end
end

-- ============================================================================
-- MIDNIGHT API DETECTION (v2.1.0 - Deferred detection for reliability)
-- Per PTR 2 notes: Player casts are NEVER secret. Duration Objects optional.
-- ============================================================================

-- API availability flags - set to nil initially, detected on first use
local API_DETECTED = false
local HAS_CAST_DURATION, HAS_CHANNEL_DURATION, HAS_EMPOWER_DURATION
local HAS_EMPOWER_STAGE_PERCENTAGES, HAS_EMPOWER_STAGE_DURATIONS
local HAS_SMOOTH_BARS, BAR_INTERPOLATION
local HAS_TIMER_BARS
local HAS_SECRETS_API

-- Deferred API detection - runs on first cast, not at load time
local function EnsureAPIDetection()
    if API_DETECTED then return end
    API_DETECTED = true
    
    -- Duration Object APIs (Midnight Beta 4+)
    HAS_CAST_DURATION = (UnitCastingDuration ~= nil)
    HAS_CHANNEL_DURATION = (UnitChannelDuration ~= nil)
    HAS_EMPOWER_DURATION = (UnitEmpoweredChannelDuration ~= nil)
    
    -- Empowered Stage APIs (Midnight PTR 2+) - for dynamic stage counts
    HAS_EMPOWER_STAGE_PERCENTAGES = (UnitEmpoweredStagePercentages ~= nil)
    HAS_EMPOWER_STAGE_DURATIONS = (UnitEmpoweredStageDurations ~= nil)
    
    -- Smooth status bar interpolation (Midnight native)
    HAS_SMOOTH_BARS = (Enum and Enum.StatusBarInterpolation ~= nil)
    BAR_INTERPOLATION = HAS_SMOOTH_BARS and Enum.StatusBarInterpolation.ExponentialEaseOut or nil
    
    -- Timer bars (Midnight Beta 4+) - check on actual StatusBar
    HAS_TIMER_BARS = false
    local ok, result = pcall(function()
        local testBar = CreateFrame("StatusBar")
        local hasMethod = (testBar.SetTimerDuration ~= nil)
        testBar:Hide()
        return hasMethod
    end)
    if ok then HAS_TIMER_BARS = result end
    
    -- Secrets API (Beta 4+)
    HAS_SECRETS_API = (C_Secrets and C_Secrets.ShouldUnitSpellCastBeSecret ~= nil)
    
    -- Color curve API for secret booleans (PTR 1+)
    HAS_COLOR_FROM_BOOLEAN = (C_CurveUtil and C_CurveUtil.EvaluateColorFromBoolean ~= nil)
    
    -- Debug output
    if TweaksUI and TweaksUI.debugMode then
        print("[TUI CastBars] API Detection (deferred):")
        print("  HAS_CAST_DURATION=", tostring(HAS_CAST_DURATION))
        print("  HAS_CHANNEL_DURATION=", tostring(HAS_CHANNEL_DURATION))
        print("  HAS_EMPOWER_DURATION=", tostring(HAS_EMPOWER_DURATION))
        print("  HAS_TIMER_BARS=", tostring(HAS_TIMER_BARS))
        print("  HAS_SMOOTH_BARS=", tostring(HAS_SMOOTH_BARS))
        print("  BAR_INTERPOLATION=", tostring(BAR_INTERPOLATION))
        print("  HAS_SECRETS_API=", tostring(HAS_SECRETS_API))
        print("  HAS_COLOR_FROM_BOOLEAN=", tostring(HAS_COLOR_FROM_BOOLEAN))
    end
end

-- Color curves for notInterruptible handling (created on demand)
local uninterruptibleColorCurve = nil
local function GetUninterruptibleColorCurve()
    if uninterruptibleColorCurve then return uninterruptibleColorCurve end
    
    -- Create a color curve: true = grey (uninterruptible), false = white (apply base color)
    -- The curve maps 0->false color, 1->true color
    -- Midnight uses C_CurveUtil.CreateColorCurve(), not a global CreateColorCurve
    if C_CurveUtil and C_CurveUtil.CreateColorCurve then
        local ok, curve = pcall(C_CurveUtil.CreateColorCurve)
        if ok and curve then
            uninterruptibleColorCurve = curve
            -- AddPoint takes (position, ColorMixin)
            -- 0.0 (false) = white (1,1,1) - means "use normal color"
            -- 1.0 (true) = grey (0.7,0.7,0.7) - uninterruptible
            pcall(function()
                uninterruptibleColorCurve:AddPoint(0, CreateColor(1, 1, 1, 1))
                uninterruptibleColorCurve:AddPoint(1, CreateColor(0.7, 0.7, 0.7, 1))
            end)
            if TweaksUI and TweaksUI.debugMode then
                print("[TUI CastBars] Created uninterruptible color curve successfully")
            end
        else
            if TweaksUI and TweaksUI.debugMode then
                print("[TUI CastBars] Failed to create color curve:", tostring(curve))
            end
        end
    else
        if TweaksUI and TweaksUI.debugMode then
            print("[TUI CastBars] C_CurveUtil.CreateColorCurve not available")
        end
    end
    return uninterruptibleColorCurve
end

-- Apply cast bar color with proper notInterruptible handling
-- Works with both readable and secret boolean values
-- Uses SetVertexColorFromBoolean for secret values (Midnight API)
local function ApplyCastBarColor(statusBar, notInterruptible, baseColor, isPlayerUnit)
    -- For player casts, notInterruptible is never secret - use direct approach
    if isPlayerUnit then
        local isUninterruptible = false
        pcall(function()
            if notInterruptible then
                isUninterruptible = true
            end
        end)
        
        if isUninterruptible then
            statusBar:SetStatusBarColor(0.7, 0.7, 0.7, 1)  -- Grey
        else
            statusBar:SetStatusBarColor(baseColor[1], baseColor[2], baseColor[3], baseColor[4] or 1)
        end
        return isUninterruptible
    end
    
    -- For non-player units, notInterruptible might be secret in Midnight
    -- Check if it's a secret value first
    local isSecret = false
    if issecretvalue then
        local ok, result = pcall(issecretvalue, notInterruptible)
        if ok then
            isSecret = result
        end
    end
    
    -- If it's a secret value, use SetVertexColorFromBoolean (Midnight API)
    if isSecret then
        local tex = statusBar:GetStatusBarTexture()
        if tex and tex.SetVertexColorFromBoolean then
            local normalColor = CreateColor(baseColor[1], baseColor[2], baseColor[3], baseColor[4] or 1)
            local greyColor = CreateColor(0.7, 0.7, 0.7, 1)
            -- notInterruptible = true means use grey, false means use normal color
            tex:SetVertexColorFromBoolean(notInterruptible, greyColor, normalColor)
            if TweaksUI and TweaksUI.debugMode then
                print("[TUI CastBars] Used SetVertexColorFromBoolean for secret notInterruptible")
            end
            -- We can't know for sure what color was applied, but return false as default
            return false
        else
            -- Fallback - just use base color since we can't determine
            statusBar:SetStatusBarColor(baseColor[1], baseColor[2], baseColor[3], baseColor[4] or 1)
            if TweaksUI and TweaksUI.debugMode then
                print("[TUI CastBars] SetVertexColorFromBoolean not available, using base color")
            end
            return false
        end
    end
    
    -- Not a secret value - try direct read
    local isUninterruptible = false
    local couldRead = pcall(function()
        if notInterruptible then
            isUninterruptible = true
        end
    end)
    
    if couldRead then
        -- Value was readable
        if isUninterruptible then
            if TweaksUI and TweaksUI.debugMode then
                print("[TUI CastBars] Setting GREY color for non-interruptible (direct read)")
            end
            statusBar:SetStatusBarColor(0.7, 0.7, 0.7, 1)
        else
            statusBar:SetStatusBarColor(baseColor[1], baseColor[2], baseColor[3], baseColor[4] or 1)
        end
        return isUninterruptible
    end
    
    -- Fallback: can't determine, use base color
    statusBar:SetStatusBarColor(baseColor[1], baseColor[2], baseColor[3], baseColor[4] or 1)
    return false
end

-- ============================================================================
-- LOCAL VARIABLES
-- ============================================================================

local settings = nil
local castBarsHub = nil
local settingsPanels = {}
local customCastBars = {}
local layoutWrappers = {}  -- TUIFrame wrappers for Layout system
local currentOpenPanel = nil

-- LibEditMode is now managed by TweaksUI.EditMode (Core/EditModeManager.lua)

-- Cast bar unit types
local CAST_BAR_UNITS = {"player", "target", "focus"}

-- Maximum number of empower stages supported (handles talent variations)
local MAX_EMPOWER_STAGES = 6

-- Standard fonts
local STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"

-- Panel dimensions
local HUB_WIDTH = 200
local HUB_HEIGHT = 320
local PANEL_WIDTH = 360
local PANEL_HEIGHT = 520

-- ============================================================================
-- DEFAULT SETTINGS
-- ============================================================================

local DEFAULT_SETTINGS = {
    player = {
        enabled = true,  -- Enable by default when module is enabled
        hideBlizzard = true,
        width = 250,
        height = 24,
        anchor = "CENTER",
        x = 0,
        y = -200,
        scale = 1.0,
        -- Colors
        castingColor = {1.0, 0.7, 0.0, 1.0},      -- Orange for casting
        channelingColor = {0.0, 1.0, 0.0, 1.0},   -- Green for channeling
        nonInterruptibleColor = {0.7, 0.7, 0.7, 1.0}, -- Gray for non-interruptible
        importantCastColor = {1.0, 0.0, 0.5, 1.0},    -- Magenta/pink for important casts
        importantChannelColor = {0.5, 0.0, 1.0, 1.0}, -- Purple for important channels
        failedColor = {1.0, 0.0, 0.0, 1.0},       -- Red for failed/interrupted
        backgroundColor = {0.1, 0.1, 0.1, 0.8},
        -- Empowered spell settings (up to 6 stages for talent variations)
        empoweredStageColors = {
            {0.5, 0.5, 1.0, 1.0},   -- Stage 1: Light blue
            {0.3, 0.7, 1.0, 1.0},   -- Stage 2: Cyan
            {0.0, 1.0, 0.5, 1.0},   -- Stage 3: Green-cyan
            {1.0, 0.84, 0.0, 1.0},  -- Stage 4: Gold
            {1.0, 0.5, 0.0, 1.0},   -- Stage 5: Orange
            {1.0, 0.2, 0.2, 1.0},   -- Stage 6/Max: Red-orange
        },
        showEmpowerStages = true,
        empowerDividerColor = {1.0, 1.0, 1.0, 0.8},
        empowerDividerWidth = 2,
        showEmpowerStageText = true,
        -- Border
        showBorder = true,
        borderColor = {0.0, 0.0, 0.0, 1.0},
        borderSize = 1,
        -- Shape/Masking
        maskShape = "none",
        -- Icon
        showIcon = true,
        iconPosition = "LEFT",  -- LEFT or RIGHT
        iconSize = 24,
        -- Timer
        showTimer = true,
        timerFormat = "remaining",  -- remaining, total, both
        timerFontSize = 12,
        timerPosition = "RIGHT",
        -- Spell Name
        showSpellName = true,
        spellNameFontSize = 12,
        spellNamePosition = "LEFT",
        -- Font (LSM font name)
        font = "Friz Quadrata TT",
        -- Spark
        showSpark = true,
        -- Texture (LSM texture name)
        texture = "Blizzard",
    },
    target = {
        enabled = true,  -- Enable by default when module is enabled
        hideBlizzard = true,
        width = 250,
        height = 24,
        anchor = "CENTER",
        x = 0,
        y = -240,
        scale = 1.0,
        castingColor = {1.0, 0.7, 0.0, 1.0},
        channelingColor = {0.0, 1.0, 0.0, 1.0},
        nonInterruptibleColor = {0.7, 0.7, 0.7, 1.0},
        importantCastColor = {1.0, 0.0, 0.5, 1.0},
        importantChannelColor = {0.5, 0.0, 1.0, 1.0},
        failedColor = {1.0, 0.0, 0.0, 1.0},
        backgroundColor = {0.1, 0.1, 0.1, 0.8},
        -- Empowered spell settings (up to 6 stages for talent variations)
        empoweredStageColors = {
            {0.5, 0.5, 1.0, 1.0},
            {0.3, 0.7, 1.0, 1.0},
            {0.0, 1.0, 0.5, 1.0},
            {1.0, 0.84, 0.0, 1.0},
            {1.0, 0.5, 0.0, 1.0},
            {1.0, 0.2, 0.2, 1.0},
        },
        showEmpowerStages = true,
        empowerDividerColor = {1.0, 1.0, 1.0, 0.8},
        empowerDividerWidth = 2,
        showEmpowerStageText = true,
        showBorder = true,
        borderColor = {0.0, 0.0, 0.0, 1.0},
        borderSize = 1,
        maskShape = "none",
        showIcon = true,
        iconPosition = "LEFT",
        iconSize = 24,
        showTimer = true,
        timerFormat = "remaining",
        timerFontSize = 12,
        timerPosition = "RIGHT",
        showSpellName = true,
        spellNameFontSize = 12,
        spellNamePosition = "LEFT",
        font = "Friz Quadrata TT",
        showSpark = true,
        texture = "Blizzard",
    },
    focus = {
        enabled = false,
        hideBlizzard = true,
        width = 200,
        height = 20,
        anchor = "CENTER",
        x = 0,
        y = -280,
        scale = 1.0,
        castingColor = {1.0, 0.7, 0.0, 1.0},
        channelingColor = {0.0, 1.0, 0.0, 1.0},
        nonInterruptibleColor = {0.7, 0.7, 0.7, 1.0},
        importantCastColor = {1.0, 0.0, 0.5, 1.0},
        importantChannelColor = {0.5, 0.0, 1.0, 1.0},
        failedColor = {1.0, 0.0, 0.0, 1.0},
        backgroundColor = {0.1, 0.1, 0.1, 0.8},
        -- Empowered spell settings (up to 6 stages for talent variations)
        empoweredStageColors = {
            {0.5, 0.5, 1.0, 1.0},
            {0.3, 0.7, 1.0, 1.0},
            {0.0, 1.0, 0.5, 1.0},
            {1.0, 0.84, 0.0, 1.0},
            {1.0, 0.5, 0.0, 1.0},
            {1.0, 0.2, 0.2, 1.0},
        },
        showEmpowerStages = true,
        empowerDividerColor = {1.0, 1.0, 1.0, 0.8},
        empowerDividerWidth = 2,
        showEmpowerStageText = true,
        showBorder = true,
        borderColor = {0.0, 0.0, 0.0, 1.0},
        borderSize = 1,
        maskShape = "none",
        showIcon = true,
        iconPosition = "LEFT",
        iconSize = 20,
        showTimer = true,
        timerFormat = "remaining",
        timerFontSize = 11,
        timerPosition = "RIGHT",
        showSpellName = true,
        spellNameFontSize = 11,
        spellNamePosition = "LEFT",
        font = "Friz Quadrata TT",
        showSpark = true,
        texture = "Blizzard",
    },
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function DeepCopy(orig)
    local copy
    if type(orig) == "table" then
        copy = {}
        for k, v in pairs(orig) do
            copy[k] = DeepCopy(v)
        end
    else
        copy = orig
    end
    return copy
end

local function EnsureDefaults(tbl, defaults)
    if type(defaults) ~= "table" then return end
    if type(tbl) ~= "table" then return end
    for k, v in pairs(defaults) do
        if tbl[k] == nil then
            tbl[k] = DeepCopy(v)
        elseif type(v) == "table" and type(tbl[k]) == "table" then
            EnsureDefaults(tbl[k], v)
        end
    end
end

-- Public function to get all settings (used by Export All)
function CastBars:GetSettings()
    -- If settings not loaded yet, load from profile database
    if not settings then
        if TweaksUI and TweaksUI.Database then
            settings = TweaksUI.Database:GetModuleSettings(TweaksUI.MODULE_IDS.CAST_BARS)
            if not settings or not next(settings) then
                -- Initialize with defaults
                settings = DeepCopy(DEFAULT_SETTINGS)
                TweaksUI.Database:SetModuleSettings(TweaksUI.MODULE_IDS.CAST_BARS, settings)
            end
        else
            -- Return defaults if database not ready
            return DeepCopy(DEFAULT_SETTINGS)
        end
    end
    
    return settings
end

-- Get spell texture safely (handles API changes)
local function GetSpellTextureByID(spellID)
    if not spellID then return nil end
    
    -- Use C_Spell.GetSpellTexture (Midnight API)
    if C_Spell and C_Spell.GetSpellTexture then
        return C_Spell.GetSpellTexture(spellID)
    end
    
    return nil
end

-- ============================================================================
-- SERIALIZATION
-- ============================================================================

local function serializeValue(val)
    local t = type(val)
    if t == "string" then
        return "\"" .. val:gsub("\\", "\\\\"):gsub("\"", "\\\""):gsub("\n", "\\n") .. "\""
    elseif t == "number" then
        return tostring(val)
    elseif t == "boolean" then
        return val and "true" or "false"
    elseif t == "table" then
        local parts = {}
        local isArray = true
        local maxIndex = 0
        for k, v in pairs(val) do
            if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
                isArray = false
                break
            end
            maxIndex = math.max(maxIndex, k)
        end
        
        if isArray and maxIndex > 0 then
            for i = 1, maxIndex do
                table.insert(parts, serializeValue(val[i]))
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            for k, v in pairs(val) do
                table.insert(parts, serializeValue(tostring(k)) .. ":" .. serializeValue(v))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end
    return "null"
end

local function deserializeValue(str, pos)
    pos = pos or 1
    while pos <= #str and str:sub(pos, pos):match("%s") do
        pos = pos + 1
    end
    
    if pos > #str then return nil, pos end
    
    local char = str:sub(pos, pos)
    
    -- String
    if char == '"' then
        local endPos = pos + 1
        local result = ""
        while endPos <= #str do
            local c = str:sub(endPos, endPos)
            if c == "\\" and endPos < #str then
                local next = str:sub(endPos + 1, endPos + 1)
                if next == "\\" or next == '"' then
                    result = result .. next
                    endPos = endPos + 2
                elseif next == "n" then
                    result = result .. "\n"
                    endPos = endPos + 2
                else
                    endPos = endPos + 1
                end
            elseif c == '"' then
                return result, endPos + 1
            else
                result = result .. c
                endPos = endPos + 1
            end
        end
        return nil, pos
    end
    
    -- Number
    if char:match("[%-0-9]") then
        local numStr = str:match("^%-?[0-9]+%.?[0-9]*", pos)
        if numStr then
            return tonumber(numStr), pos + #numStr
        end
    end
    
    -- Boolean/null
    if str:sub(pos, pos + 3) == "true" then
        return true, pos + 4
    elseif str:sub(pos, pos + 4) == "false" then
        return false, pos + 5
    elseif str:sub(pos, pos + 3) == "null" then
        return nil, pos + 4
    end
    
    -- Array
    if char == "[" then
        local arr = {}
        pos = pos + 1
        while pos <= #str do
            while pos <= #str and str:sub(pos, pos):match("%s") do
                pos = pos + 1
            end
            if str:sub(pos, pos) == "]" then
                return arr, pos + 1
            end
            local val
            val, pos = deserializeValue(str, pos)
            table.insert(arr, val)
            while pos <= #str and str:sub(pos, pos):match("[%s,]") do
                pos = pos + 1
            end
        end
        return arr, pos
    end
    
    -- Object
    if char == "{" then
        local obj = {}
        pos = pos + 1
        while pos <= #str do
            while pos <= #str and str:sub(pos, pos):match("%s") do
                pos = pos + 1
            end
            if str:sub(pos, pos) == "}" then
                return obj, pos + 1
            end
            local key
            key, pos = deserializeValue(str, pos)
            while pos <= #str and str:sub(pos, pos):match("[%s:]") do
                pos = pos + 1
            end
            local val
            val, pos = deserializeValue(str, pos)
            if key then
                local numKey = tonumber(key)
                if numKey then
                    obj[numKey] = val
                else
                    obj[key] = val
                end
            end
            while pos <= #str and str:sub(pos, pos):match("[%s,]") do
                pos = pos + 1
            end
        end
        return obj, pos
    end
    
    return nil, pos + 1
end

-- ============================================================================
-- CAST BAR CREATION
-- ============================================================================

local function CreateCastBar(unit)
    local unitSettings = settings[unit]
    if not unitSettings then return nil end
    
    local frame = CreateFrame("Frame", "TweaksUI_CastBar_" .. unit, UIParent, "BackdropTemplate")
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(100)
    frame.unit = unit
    frame.casting = false
    frame.channeling = false
    frame.holdTime = 0
    frame.fadeOut = false
    
    -- Status bar (use Media helper to resolve texture name to path)
    frame.statusBar = CreateFrame("StatusBar", nil, frame)
    frame.statusBar:SetStatusBarTexture(TweaksUI.Media:GetTextureWithGlobal(unitSettings.texture))
    frame.statusBar:SetMinMaxValues(0, 1)
    frame.statusBar:SetValue(0)
    
    -- Background
    frame.background = frame:CreateTexture(nil, "BACKGROUND")
    frame.background:SetAllPoints(frame)
    
    -- Spark
    frame.spark = frame.statusBar:CreateTexture(nil, "OVERLAY")
    frame.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    frame.spark:SetSize(32, 32)
    frame.spark:SetBlendMode("ADD")
    frame.spark:SetPoint("CENTER", frame.statusBar:GetStatusBarTexture(), "RIGHT", 0, 0)
    
    -- Icon frame (background for icon)
    frame.iconFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.iconFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame.iconFrame:SetBackdropColor(0, 0, 0, 0.8)
    frame.iconFrame:SetBackdropBorderColor(0, 0, 0, 1)
    
    -- Icon
    frame.icon = frame.iconFrame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetPoint("TOPLEFT", 1, -1)
    frame.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    
    -- Spell name text
    frame.spellName = frame.statusBar:CreateFontString(nil, "OVERLAY")
    frame.spellName:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    frame.spellName:SetTextColor(1, 1, 1, 1)
    
    -- Timer text
    frame.timer = frame.statusBar:CreateFontString(nil, "OVERLAY")
    frame.timer:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    frame.timer:SetTextColor(1, 1, 1, 1)
    
    -- NOTE: Shield texture removed in v2.0.0 - non-interruptible is now indicated by color only
    -- This avoids visual artifacts from Blizzard's shield texture
    frame.shield = nil  -- Keep reference nil to avoid errors in existing code
    
    -- Empowered spell stage dividers (up to MAX_EMPOWER_STAGES to handle talent variations)
    frame.stageDividers = {}
    for i = 1, MAX_EMPOWER_STAGES do
        local divider = frame.statusBar:CreateTexture(nil, "OVERLAY", nil, 2)
        divider:SetColorTexture(1, 1, 1, 0.8)
        divider:SetSize(2, 1)  -- Width will be set by settings, height by bar height
        divider:Hide()
        frame.stageDividers[i] = divider
    end
    
    -- Empowered stage text (shows current stage like "Stage 2")
    frame.stageText = frame.statusBar:CreateFontString(nil, "OVERLAY")
    frame.stageText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    frame.stageText:SetTextColor(1, 1, 1, 1)
    frame.stageText:SetPoint("TOP", frame.statusBar, "BOTTOM", 0, -2)
    frame.stageText:Hide()
    
    -- Track current empower stage for color changes
    frame.currentEmpowerStage = 0
    
    -- Make movable via Edit Mode integration
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    
    frame:Hide()
    return frame
end

local function UpdateCastBarLayout(unit)
    local frame = customCastBars[unit]
    if not frame then return end
    
    local us = settings[unit]
    if not us then return end
    
    local width = us.width
    local height = us.height
    local iconSize = us.iconSize
    local showIcon = us.showIcon
    
    -- Calculate bar width (accounting for icon if shown)
    local barWidth = width
    local barX = 0
    
    if showIcon then
        barWidth = width - iconSize - 2
        if us.iconPosition == "LEFT" then
            barX = iconSize + 2
        end
    end
    
    -- Position and size frame
    -- Only set position if NOT parented to a Layout wrapper
    if not layoutWrappers[unit] then
        frame:ClearAllPoints()
        frame:SetPoint(us.anchor, UIParent, us.anchor, us.x, us.y)
    else
        -- Update wrapper size to match bar
        layoutWrappers[unit]:SetSize(width * us.scale, height * us.scale)
    end
    frame:SetSize(width, height)
    frame:SetScale(us.scale)
    
    -- Background and border
    if us.showBorder then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = us.borderSize,
        })
        frame:SetBackdropColor(us.backgroundColor[1], us.backgroundColor[2], us.backgroundColor[3], us.backgroundColor[4])
        frame:SetBackdropBorderColor(us.borderColor[1], us.borderColor[2], us.borderColor[3], us.borderColor[4])
    else
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
        })
        frame:SetBackdropColor(us.backgroundColor[1], us.backgroundColor[2], us.backgroundColor[3], us.backgroundColor[4])
    end
    
    -- Status bar positioning
    frame.statusBar:ClearAllPoints()
    if showIcon then
        if us.iconPosition == "LEFT" then
            frame.statusBar:SetPoint("TOPLEFT", frame, "TOPLEFT", iconSize + 2, -1)
            frame.statusBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
        else
            frame.statusBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
            frame.statusBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(iconSize + 2), 1)
        end
    else
        frame.statusBar:SetPoint("TOPLEFT", 1, -1)
        frame.statusBar:SetPoint("BOTTOMRIGHT", -1, 1)
    end
    frame.statusBar:SetStatusBarTexture(TweaksUI.Media:GetTextureWithGlobal(us.texture))
    
    -- Apply bar masking
    if TweaksUI.BarMasking and us.maskShape then
        TweaksUI.BarMasking:ApplyToStatusBar(frame.statusBar, us.maskShape)
    end
    
    -- Icon positioning
    if showIcon then
        frame.iconFrame:Show()
        frame.iconFrame:SetSize(iconSize, iconSize)
        frame.iconFrame:ClearAllPoints()
        if us.iconPosition == "LEFT" then
            frame.iconFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        else
            frame.iconFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        end
    else
        frame.iconFrame:Hide()
    end
    
    -- Spell name positioning
    local fontPath = TweaksUI.Media:GetFontWithGlobal(us.font)
    local fontOutline = TweaksUI.Media:GetOutlineWithGlobal(us.fontOutline)
    frame.spellName:SetFont(fontPath, us.spellNameFontSize, fontOutline)
    frame.spellName:ClearAllPoints()
    if us.showSpellName then
        if us.spellNamePosition == "LEFT" then
            frame.spellName:SetPoint("LEFT", frame.statusBar, "LEFT", 4, 0)
            frame.spellName:SetJustifyH("LEFT")
        elseif us.spellNamePosition == "CENTER" then
            frame.spellName:SetPoint("CENTER", frame.statusBar, "CENTER", 0, 0)
            frame.spellName:SetJustifyH("CENTER")
        else
            frame.spellName:SetPoint("RIGHT", frame.statusBar, "RIGHT", -4, 0)
            frame.spellName:SetJustifyH("RIGHT")
        end
        frame.spellName:Show()
    else
        frame.spellName:Hide()
    end
    
    -- Timer positioning
    frame.timer:SetFont(fontPath, us.timerFontSize, fontOutline)
    frame.timer:ClearAllPoints()
    if us.showTimer then
        if us.timerPosition == "LEFT" then
            frame.timer:SetPoint("LEFT", frame.statusBar, "LEFT", 4, 0)
            frame.timer:SetJustifyH("LEFT")
        elseif us.timerPosition == "CENTER" then
            frame.timer:SetPoint("CENTER", frame.statusBar, "CENTER", 0, 0)
            frame.timer:SetJustifyH("CENTER")
        else
            frame.timer:SetPoint("RIGHT", frame.statusBar, "RIGHT", -4, 0)
            frame.timer:SetJustifyH("RIGHT")
        end
        frame.timer:Show()
    else
        frame.timer:Hide()
    end
    
    -- Spark visibility
    if us.showSpark then
        frame.spark:Show()
    else
        frame.spark:Hide()
    end
end

-- ============================================================================
-- EMPOWERED SPELL HELPERS
-- ============================================================================

-- Get the number of empower stages from UnitChannelInfo (Midnight: non-secret)
-- Returns numStages (always returns a valid number 2-6)
local function GetEmpowerNumStages(unit, spellID)
    local numStages = 3  -- Default fallback
    
    -- Method 1: Try to get from UnitChannelInfo return values
    -- UnitChannelInfo returns: name, text, texture, startTimeMS, endTimeMS, isTradeSkill, notInterruptible, spellID, isEmpowered, numStages
    local success, results = pcall(function()
        return {UnitChannelInfo(unit)}
    end)
    
    if success and results and #results >= 10 then
        local apiStages = results[10]
        if apiStages then
            local safeStages = SafeValue(apiStages)
            if safeStages and type(safeStages) == "number" and safeStages >= 2 and safeStages <= MAX_EMPOWER_STAGES then
                numStages = safeStages
            end
        end
    end
    
    -- Method 2: Try UnitEmpoweredStagePercentages if available
    if numStages == 3 and HAS_EMPOWER_STAGE_PERCENTAGES then
        local success2, percentages = pcall(function()
            return UnitEmpoweredStagePercentages(unit, true)  -- include hold-at-max
        end)
        
        if success2 and percentages and type(percentages) == "table" and #percentages > 1 then
            -- Count minus 1 (for hold-at-max) gives number of stages
            local count = #percentages - 1
            if count >= 2 and count <= MAX_EMPOWER_STAGES then
                numStages = count
            end
        end
    end
    
    return numStages
end

-- Get stage percentages for empowered spells (cumulative positions 0-1)
-- Uses UnitEmpoweredStagePercentages API (non-secret in Midnight PTR 2+) or hardcoded fallback
-- Returns: table of cumulative percentages where each stage ENDS (divider positions)
local function GetEmpowerStagePositions(numStages, unit)
    -- Method 1: Use UnitEmpoweredStagePercentages API if available (Midnight PTR 2+)
    -- This API returns NON-SECRET percentages describing how much time each stage takes
    if HAS_EMPOWER_STAGE_PERCENTAGES and unit then
        local success, percentages = pcall(function()
            -- MUST include hold-at-max to get positions relative to the FULL bar
            -- Otherwise positions are scaled to just the stage portions
            return UnitEmpoweredStagePercentages(unit, true)  -- include hold-at-max for correct bar positions
        end)
        
        if success and percentages and type(percentages) == "table" and #percentages >= numStages then
            -- Convert individual stage percentages to cumulative positions
            -- percentages[i] = how much of TOTAL time (including hold) stage i takes
            -- We want cumulative positions where each stage ENDS (divider = completion of stage)
            local positions = {}
            local cumulative = 0
            for i = 1, numStages do
                cumulative = cumulative + (percentages[i] or 0)
                positions[i] = cumulative
            end
            return positions
        end
    end
    
    -- Method 2: Hardcoded fallback positions (when API unavailable)
    -- These are the points where each stage ENDS (completion = can release at that level)
    -- Positions account for ~35% hold-at-max time at the end of the bar
    -- Example for 3 stages: stages take ~65% of bar, hold takes ~35%
    if numStages == 6 then
        return {0.10, 0.22, 0.34, 0.46, 0.58, 0.70}
    elseif numStages == 5 then
        return {0.12, 0.26, 0.40, 0.54, 0.68}
    elseif numStages == 4 then
        return {0.15, 0.32, 0.49, 0.66}
    elseif numStages == 3 then
        -- Fire Breath: sparks at ~20%, ~40%, ~60%
        return {0.20, 0.40, 0.60}
    elseif numStages == 2 then
        return {0.30, 0.60}
    else
        -- Fallback: distribute in first 70% of bar (30% for hold-at-max)
        local positions = {}
        local usableRange = 0.70
        for i = 1, numStages do
            positions[i] = (i / numStages) * usableRange
        end
        return positions
    end
end

-- Calculate current empower stage based on progress
-- Returns: 0 = charging (before first divider), 1-N = completed that stage (can release at that level)
-- The dividers mark COMPLETION of stages (when you can release at that level)
local function GetCurrentEmpowerStage(progress, stagePositions, numStages)
    if not progress or not stagePositions or not numStages then return 0 end
    if progress <= 0 then return 0 end  -- Not started yet
    if progress >= 1 then return numStages end  -- Completed/max stage
    
    -- Find which stage we've COMPLETED (passed the divider for)
    -- stagePositions[i] is the cumulative point where stage i ENDS (completion)
    -- Before positions[1]: Stage 0 (charging, can only cancel)
    -- After positions[1]: Stage 1 completed (can release at level 1)
    -- After positions[2]: Stage 2 completed (can release at level 2), etc.
    
    -- Check if we haven't completed the first stage yet
    if progress < stagePositions[1] then
        return 0  -- Still charging, not completed any stage yet
    end
    
    -- Find the highest stage we've completed
    local currentStage = 1
    for i = 2, #stagePositions do
        if progress >= stagePositions[i] then
            currentStage = i
        else
            break
        end
    end
    
    return currentStage
end

-- Setup empowered stage dividers on the cast bar
local function SetupEmpowerDividers(frame, unit, numStages, totalDuration)
    local us = settings[unit]
    if not us then return end
    
    -- Hide all dividers first
    for i = 1, MAX_EMPOWER_STAGES do
        if frame.stageDividers and frame.stageDividers[i] then
            frame.stageDividers[i]:Hide()
        end
    end
    
    -- Hide stage text initially
    if frame.stageText then
        frame.stageText:Hide()
    end
    
    if not us.showEmpowerStages or not numStages or numStages <= 1 then
        frame.stagePositions = nil
        return
    end
    
    -- Get stage positions (uses API if available, otherwise hardcoded)
    local positions = GetEmpowerStagePositions(numStages, unit)
    if not positions or #positions == 0 then
        frame.stagePositions = nil
        return
    end
    
    frame.stagePositions = positions
    frame.currentEmpowerStage = 0  -- Start at stage 0 (charging, before first divider)
    
    -- Get bar dimensions - use settings as fallback if bar isn't sized yet
    local barWidth = frame.statusBar:GetWidth()
    local barHeight = frame.statusBar:GetHeight()
    
    -- Fallback to settings if bar reports 0 size
    if barWidth <= 0 then
        barWidth = us.width or 250
    end
    if barHeight <= 0 then
        barHeight = us.height or 24
    end
    
    local dividerWidth = us.empowerDividerWidth or 2
    local dividerColor = us.empowerDividerColor or {1, 1, 1, 0.8}
    
    -- Position dividers at stage completion points (numStages dividers)
    -- Each divider marks where you complete that stage and can release
    for i = 1, numStages do
        local divider = frame.stageDividers and frame.stageDividers[i]
        if divider and positions[i] then
            local xPos = positions[i] * barWidth
            divider:ClearAllPoints()
            divider:SetPoint("CENTER", frame.statusBar, "LEFT", xPos, 0)
            divider:SetSize(dividerWidth, barHeight)
            divider:SetColorTexture(dividerColor[1], dividerColor[2], dividerColor[3], dividerColor[4] or 0.8)
            divider:SetDrawLayer("OVERLAY", 7)  -- Ensure dividers are on top
            divider:Show()
        end
    end
    
    -- Show stage text if enabled
    if us.showEmpowerStageText and frame.stageText then
        frame.stageText:SetText("Charging...")
        frame.stageText:Show()
    end
end

-- Update empowered bar color based on current stage
local function UpdateEmpowerStageColor(frame, unit, currentStage)
    local us = settings[unit]
    if not us or not us.empoweredStageColors then return end
    
    local stageColors = us.empoweredStageColors
    local color
    
    if currentStage <= 0 then
        -- Stage 0: Charging, not in any stage yet - use first stage color but dimmed
        -- Or use channeling color to indicate "not ready yet"
        color = us.channelingColor or stageColors[1] or {0.5, 0.5, 1.0, 1.0}
    elseif currentStage > #stageColors then
        -- Past defined colors, use last one (max stage)
        color = stageColors[#stageColors] or {1.0, 0.84, 0.0, 1.0}
    else
        color = stageColors[currentStage]
    end
    
    if color then
        frame.statusBar:SetStatusBarColor(color[1], color[2], color[3], color[4] or 1)
    end
    
    -- Update stage text
    if us.showEmpowerStageText and frame.stageText then
        if currentStage > 0 then
            frame.stageText:SetText("Stage " .. currentStage)
        else
            frame.stageText:SetText("Charging...")  -- Or empty string: ""
        end
    end
end

-- ============================================================================
-- CAST BAR UPDATE LOGIC
-- ============================================================================

local function StartCast(frame, unit, isChannel, eventCastGUID, eventSpellID)
    -- Check if module is enabled first
    if not CastBars.enabled then return end
    
    local us = settings[unit]
    if not us or not us.enabled then return end
    
    -- Ensure API detection has run (deferred to first cast for reliability)
    EnsureAPIDetection()
    
    local name, text, texture, startTimeMS, endTimeMS, isTradeSkill, castID, notInterruptible, spellID
    local isEmpowered, numEmpowerStages  -- Midnight empowered spell support
    
    -- Check for empowered spell using event spellID
    -- In Midnight:
    --   - UnitCastingInfo returns nil for empowered spells
    --   - C_Spell.GetSpellEmpowerInfo doesn't exist
    --   - UnitChannelInfo provides timing data and numEmpowerStages (non-secret in Midnight)
    --   - We detect empowered by: isChannel=true AND we have a valid eventSpellID from EMPOWER event
    
    -- If we got here via EMPOWER_START event, we know it's empowered
    if eventSpellID and isChannel then
        isEmpowered = true
        spellID = eventSpellID
        
        -- Get spell name and icon from C_Spell.GetSpellInfo
        if C_Spell and C_Spell.GetSpellInfo then
            local spellSuccess, spellInfo = pcall(function() return C_Spell.GetSpellInfo(eventSpellID) end)
            if spellSuccess and spellInfo then
                name = spellInfo.name
                texture = spellInfo.iconID
            end
        end
        
        -- Get timing AND numEmpowerStages from UnitChannelInfo (empowered spells report as channels)
        -- Return values: name, text, texture, startTimeMS, endTimeMS, isTradeSkill, notInterruptible, spellID, isEmpowered, numStages
        local channelResults = {UnitChannelInfo(unit)}
        
        if channelResults[4] and channelResults[5] then
            startTimeMS = channelResults[4]
            endTimeMS = channelResults[5]
            -- Get texture from channel info if we don't have it
            if not texture and channelResults[3] then
                texture = channelResults[3]
            end
            if not name and channelResults[1] then
                name = channelResults[1]
            end
            -- Get notInterruptible from index 7 (empowered spells can also be non-interruptible)
            notInterruptible = channelResults[7]
        end
        
        -- Get numEmpowerStages from return value 10 (if available)
        -- This is the authoritative source for stage count - handles talent variations
        local apiStages = channelResults[10]
        if apiStages then
            local safeStages = SafeValue(apiStages)
            if safeStages and type(safeStages) == "number" and safeStages >= 1 and safeStages <= MAX_EMPOWER_STAGES then
                numEmpowerStages = safeStages
            end
        end
        
        -- Fallback: try GetEmpowerNumStages helper if UnitChannelInfo didn't give us stages
        if not numEmpowerStages then
            numEmpowerStages = GetEmpowerNumStages(unit, eventSpellID)
        end
        
        -- Empowered spells fill like casts, not drain like channels
        isChannel = false
    end
    
    -- If not empowered, use normal detection
    if not isEmpowered then
        if isChannel then
            -- Regular channel
            name, text, texture, startTimeMS, endTimeMS, isTradeSkill, notInterruptible, spellID = UnitChannelInfo(unit)
            -- DEBUG
            if TweaksUI and TweaksUI.debugMode then
                print("[TUI CastBars] UnitChannelInfo(", unit, "):")
                print("  name=", name, "startTimeMS=", startTimeMS, "endTimeMS=", endTimeMS)
                print("  notInterruptible=", tostring(notInterruptible), "type=", type(notInterruptible))
            end
        else
            -- Regular cast
            name, text, texture, startTimeMS, endTimeMS, isTradeSkill, castID, notInterruptible, spellID = UnitCastingInfo(unit)
            -- DEBUG
            if TweaksUI and TweaksUI.debugMode then
                print("[TUI CastBars] UnitCastingInfo(", unit, "):")
                print("  name=", name, "startTimeMS=", startTimeMS, "endTimeMS=", endTimeMS)
                print("  notInterruptible=", tostring(notInterruptible), "type=", type(notInterruptible))
            end
        end
    end
    
    -- Fallback defaults for empowered spells if data is incomplete
    if isEmpowered then
        if not name then
            name = "Empowered Cast"
        end
        if not texture then
            texture = 136243  -- Default spell icon
        end
        if not startTimeMS or not endTimeMS then
            local now = GetTime()
            startTimeMS = now * 1000
            endTimeMS = (now + 3) * 1000  -- Default 3 second duration
        end
    end
    
    if not name then
        frame:Hide()
        return
    end
    
    frame.casting = not isChannel
    frame.channeling = isChannel
    frame.isEmpowered = isEmpowered  -- Track empowered state
    frame.numEmpowerStages = numEmpowerStages
    frame.fadeOut = false
    frame.holdTime = 0
    frame.durationObject = nil  -- Will store Duration Object if available
    
    -- Store castID to verify events are for THIS cast (fixes issue where pressing
    -- another key during a cast would stop the bar due to UNIT_SPELLCAST_FAILED
    -- being fired for the new failed cast attempt, not the current cast)
    -- For channels, UnitChannelInfo doesn't return castID, so use the event's castGUID
    frame.castID = castID or eventCastGUID
    
    -- =========================================================================
    -- TIMING DATA (v2.1.3 - SetTimerDuration for secrets, traditional for player)
    -- SetTimerDuration lets the bar render from Duration Object directly,
    -- handling secret timing internally. Traditional works for player casts.
    -- =========================================================================
    local startTime, endTime
    local useTimerBar = false
    frame.durationObject = nil
    
    local isPlayerCast = (unit == "player" or unit == "pet" or unit == "vehicle")
    
    -- Try Duration Object first
    local durationObj = nil
    if isEmpowered and HAS_EMPOWER_DURATION then
        local success, obj = pcall(function() return UnitEmpoweredChannelDuration(unit, true) end)
        if success and obj then durationObj = obj end
    elseif isChannel and HAS_CHANNEL_DURATION then
        local success, obj = pcall(function() return UnitChannelDuration(unit) end)
        if success and obj then durationObj = obj end
    elseif not isChannel and not isEmpowered and HAS_CAST_DURATION then
        local success, obj = pcall(function() return UnitCastingDuration(unit) end)
        if success and obj then durationObj = obj end
    end
    
    if durationObj then
        frame.durationObject = durationObj
        
        -- For non-player casts, try SetTimerDuration (handles secrets)
        if not isPlayerCast and HAS_TIMER_BARS then
            -- Set min/max BEFORE SetTimerDuration
            frame.statusBar:SetMinMaxValues(0, 1)
            
            -- Don't pass direction - it was causing "bad argument #4" error
            -- SetTimerDuration(duration [, interpolation, direction]) - direction is optional
            local ok, err = pcall(function()
                frame.statusBar:SetTimerDuration(durationObj, BAR_INTERPOLATION)
            end)
            
            if ok then
                useTimerBar = true
                if TweaksUI and TweaksUI.debugMode then
                    print("[TUI CastBars]", unit, "- Using SetTimerDuration (self-updating)")
                end
            else
                if TweaksUI and TweaksUI.debugMode then
                    print("[TUI CastBars] SetTimerDuration FAILED for", unit, "err:", err)
                end
            end
        end
        
        -- If timer bar didn't work, extract timing from Duration Object
        if not useTimerBar then
            startTime = GetTime()
            local safeElapsed, safeRemaining = 0, 2
            
            if durationObj.GetElapsedDuration then
                pcall(function()
                    local elapsed = durationObj:GetElapsedDuration()
                    safeElapsed = SafeValue(elapsed) or 0
                end)
            end
            if durationObj.GetRemainingDuration then
                pcall(function()
                    local remaining = durationObj:GetRemainingDuration()
                    safeRemaining = SafeValue(remaining) or 2
                end)
            end
            
            startTime = GetTime() - safeElapsed
            endTime = GetTime() + safeRemaining
            
            if TweaksUI and TweaksUI.debugMode then
                print("[TUI CastBars]", unit, "Duration Object fallback: elapsed=", safeElapsed, "remaining=", safeRemaining)
            end
        end
    end
    
    -- Traditional timing fallback (works for player casts where values aren't secret)
    if not useTimerBar and not durationObj then
        local ok = pcall(function()
            startTime = startTimeMS / 1000
            endTime = endTimeMS / 1000
        end)
        
        if not ok or not startTime or not endTime then
            -- Shouldn't happen for player casts
            startTime = GetTime()
            endTime = startTime + 2
        end
        
        if TweaksUI and TweaksUI.debugMode then
            print("[TUI CastBars]", unit, "- Using traditional timing, duration=", endTime - startTime)
        end
    end
    
    frame.useTimerBar = useTimerBar
    
    -- Protect against secret values for notInterruptible and spellID
    local safeNotInterruptible = false
    local safeSpellID = nil
    pcall(function()
        if notInterruptible then
            safeNotInterruptible = true
        end
        if spellID then
            safeSpellID = spellID
        end
    end)
    
    frame.notInterruptible = safeNotInterruptible
    frame.spellID = safeSpellID
    
    -- Store timing data (may be nil for timer bars)
    frame.startTime = startTime
    frame.endTime = endTime
    frame.maxValue = (startTime and endTime) and (endTime - startTime) or 1
    
    -- Timer bars: already set up with SetTimerDuration, min/max is 0-1
    -- Traditional bars: use 0-maxValue scale with manual updates
    if not useTimerBar then
        frame.statusBar:SetMinMaxValues(0, frame.maxValue)
        
        -- Empowered spells fill up (like casts), regular channels drain down
        if isChannel and not isEmpowered then
            frame.statusBar:SetValue(frame.maxValue)  -- Regular channel: start full, drain
        else
            frame.statusBar:SetValue(0)  -- Cast or Empowered: start empty, fill
        end
    end
    
    -- Set spell name
    if us.showSpellName then
        frame.spellName:SetText(name)
    end
    
    -- Set icon (protect against secret texture/spellID)
    pcall(function()
        if us.showIcon and texture then
            frame.icon:SetTexture(texture)
        elseif us.showIcon and safeSpellID then
            local spellTexture = GetSpellTextureByID(safeSpellID)
            if spellTexture then
                frame.icon:SetTexture(spellTexture)
            end
        end
    end)
    
    -- Setup empowered stage dividers if this is an empowered spell
    if isEmpowered and numEmpowerStages and numEmpowerStages > 1 then
        -- IMMEDIATELY set up stage positions so UpdateCastBar can calculate stages
        -- This is critical for stage progression to work from the start
        local positions = GetEmpowerStagePositions(numEmpowerStages, unit)
        frame.stagePositions = positions
        frame.currentEmpowerStage = 0  -- Start at stage 0 (charging, before first divider)
        
        -- Set initial empowered color (stage 0 = charging)
        UpdateEmpowerStageColor(frame, unit, 0)
        
        -- Delay divider visual setup slightly to ensure bar is properly sized
        -- But stage logic is already working from the positions set above
        C_Timer.After(0.05, function()
            if frame.isEmpowered and frame.numEmpowerStages and frame.numEmpowerStages > 1 then
                SetupEmpowerDividers(frame, unit, numEmpowerStages, frame.maxValue)
            end
        end)
    else
        -- Hide any existing dividers
        for i = 1, MAX_EMPOWER_STAGES do
            if frame.stageDividers and frame.stageDividers[i] then
                frame.stageDividers[i]:Hide()
            end
        end
        if frame.stageText then
            frame.stageText:Hide()
        end
        frame.stagePositions = nil
        
        -- Set color based on cast type (non-empowered)
        -- Priority: non-interruptible > important > normal
        local baseColor
        local isImportant = false
        local isPlayerUnit = (unit == "player" or unit == "pet" or unit == "vehicle")
        
        -- Check if spell is important (using SpellAPI if available)
        if TweaksUI.SpellAPI and safeSpellID then
            isImportant = TweaksUI.SpellAPI:IsImportant(safeSpellID)
        end
        
        -- Determine base color (before notInterruptible override)
        if isImportant then
            if isChannel then
                baseColor = us.importantChannelColor or us.channelingColor
            else
                baseColor = us.importantCastColor or us.castingColor
            end
        else
            if isChannel then
                baseColor = us.channelingColor
            else
                baseColor = us.castingColor
            end
        end
        
        -- Apply color with proper notInterruptible handling (works with secret values)
        -- This will override to grey if uninterruptible, otherwise use baseColor
        local wasUninterruptible = ApplyCastBarColor(frame.statusBar, notInterruptible, baseColor, isPlayerUnit)
        frame.notInterruptible = wasUninterruptible
    end
    
    frame:SetAlpha(1)
    frame:Show()
end

local function StopCast(frame, unit, failed)
    local us = settings[unit]
    if not us then return end
    
    if failed then
        frame.statusBar:SetStatusBarColor(us.failedColor[1], us.failedColor[2], us.failedColor[3], us.failedColor[4])
    end
    
    frame.casting = false
    frame.channeling = false
    frame.isEmpowered = false
    frame.numEmpowerStages = nil
    frame.stagePositions = nil
    frame.currentEmpowerStage = 0
    frame.fadeOut = true
    frame.holdTime = GetTime() + 0.0
    frame.castID = nil  -- Clear castID so we're ready for next cast
    
    -- Hide empowered stage dividers
    for i = 1, MAX_EMPOWER_STAGES do
        if frame.stageDividers and frame.stageDividers[i] then
            frame.stageDividers[i]:Hide()
        end
    end
    if frame.stageText then
        frame.stageText:Hide()
    end
end

local function UpdateCastBar(frame, elapsed)
    if frame.fadeOut then
        if GetTime() >= frame.holdTime then
            local alpha = frame:GetAlpha() - elapsed * 2
            if alpha <= 0 then
                frame:Hide()
                frame.fadeOut = false
                frame.durationObject = nil
                frame.useTimerBar = false
            else
                frame:SetAlpha(alpha)
            end
        end
        return
    end
    
    if not frame.casting and not frame.channeling then
        return
    end
    
    local us = settings[frame.unit]
    if not us then return end
    
    local currentTime = GetTime()
    local value, progress, remaining
    
    -- =========================================================================
    -- PROGRESS CALCULATION (v2.1.3 - Timer bars vs Traditional)
    -- =========================================================================
    
    if frame.useTimerBar then
        -- Timer bar mode: bar updates itself, we just track progress for completion/extras
        local isComplete = false
        if frame.durationObject and frame.durationObject.EvaluateElapsedProgress then
            local success, progressResult = pcall(function()
                return frame.durationObject:EvaluateElapsedProgress()
            end)
            if success and progressResult then
                progress = progressResult
                -- Check completion (wrap comparison in pcall for secrets)
                pcall(function()
                    if progress >= 1 then
                        isComplete = true
                    end
                end)
            end
        end
        
        if isComplete then
            StopCast(frame, frame.unit, false)
            return
        end
        
        -- Get remaining from Duration Object for timer text
        -- Note: Values are secret - we can display them but NOT do arithmetic
        local safeRemaining = nil
        if frame.durationObject and frame.durationObject.GetRemainingDuration then
            local ok, r = pcall(frame.durationObject.GetRemainingDuration, frame.durationObject)
            if ok and r then safeRemaining = r end
        end
        
        -- Update timer text (can only show remaining, not total - arithmetic on secrets fails)
        if us.showTimer then
            if safeRemaining then
                -- Use string.format which can handle secret values
                local ok, text = pcall(string.format, "%.1f", safeRemaining)
                if ok and text then
                    frame.timer:SetText(text)
                else
                    frame.timer:SetText("")
                end
            else
                frame.timer:SetText("")
            end
        end
        
        -- Update spark position using progress (wrap in pcall for secret values)
        if us.showSpark and progress then
            local sparkPosition
            local ok = pcall(function()
                if frame.channeling and not frame.isEmpowered then
                    sparkPosition = (1 - progress) * frame.statusBar:GetWidth()
                else
                    sparkPosition = progress * frame.statusBar:GetWidth()
                end
            end)
            if ok and sparkPosition then
                frame.spark:SetPoint("CENTER", frame.statusBar, "LEFT", sparkPosition, 0)
            end
        end
        
        -- Update empowered stages using progress (wrap in pcall)
        if frame.isEmpowered and frame.stagePositions and frame.numEmpowerStages and progress then
            pcall(function()
                local newStage = GetCurrentEmpowerStage(progress, frame.stagePositions, frame.numEmpowerStages)
                if newStage ~= frame.currentEmpowerStage then
                    frame.currentEmpowerStage = newStage
                    UpdateEmpowerStageColor(frame, frame.unit, newStage)
                end
            end)
        end
        
    else
        -- Traditional mode: manual SetValue updates
        
        -- Try Duration Object for progress (may provide better accuracy)
        if frame.durationObject and frame.durationObject.EvaluateElapsedProgress then
            local success, progressResult = pcall(function()
                return frame.durationObject:EvaluateElapsedProgress()
            end)
            if success and progressResult then
                local safeProgress = SafeValue(progressResult)
                if safeProgress then
                    progress = safeProgress
                    value = safeProgress * frame.maxValue
                    remaining = frame.maxValue - value
                    
                    if safeProgress >= 1 then
                        StopCast(frame, frame.unit, false)
                        return
                    end
                end
            end
        end
        
        -- Time-based calculation (fallback or primary for player casts)
        if not progress then
            if frame.casting then
                value = currentTime - frame.startTime
                remaining = frame.maxValue - value
                progress = value / frame.maxValue
            elseif frame.channeling then
                value = frame.endTime - currentTime
                remaining = value
                progress = 1 - (value / frame.maxValue)
            end
        end
        
        -- Update status bar
        if frame.casting then
            if value >= frame.maxValue then
                StopCast(frame, frame.unit, false)
                return
            end
            frame.statusBar:SetValue(value)
            
            -- Update empowered stage color and text
            if frame.isEmpowered and frame.stagePositions and frame.numEmpowerStages then
                local safeValue = tonumber(value) or 0
                local safeMax = tonumber(frame.maxValue) or 1
                if safeMax <= 0 then safeMax = 1 end
                
                local progressForStage = safeValue / safeMax
                local newStage = GetCurrentEmpowerStage(progressForStage, frame.stagePositions, frame.numEmpowerStages)
                
                if newStage ~= frame.currentEmpowerStage then
                    frame.currentEmpowerStage = newStage
                    UpdateEmpowerStageColor(frame, frame.unit, newStage)
                end
            end
            
            -- Update timer
            if us.showTimer then
                if us.timerFormat == "remaining" then
                    frame.timer:SetText(string.format("%.1f", remaining))
                elseif us.timerFormat == "total" then
                    frame.timer:SetText(string.format("%.1f", frame.maxValue))
                else
                    frame.timer:SetText(string.format("%.1f / %.1f", remaining, frame.maxValue))
                end
            end
            
            -- Update spark position
            if us.showSpark then
                local sparkPosition = (value / frame.maxValue) * frame.statusBar:GetWidth()
                frame.spark:SetPoint("CENTER", frame.statusBar, "LEFT", sparkPosition, 0)
            end
            
        elseif frame.channeling then
            local displayValue = value or (frame.endTime - currentTime)
            remaining = displayValue
            
            if displayValue <= 0 then
                StopCast(frame, frame.unit, false)
                return
            end
            
            frame.statusBar:SetValue(displayValue)
            
            -- Update timer
            if us.showTimer then
                if us.timerFormat == "remaining" then
                    frame.timer:SetText(string.format("%.1f", remaining))
                elseif us.timerFormat == "total" then
                    frame.timer:SetText(string.format("%.1f", frame.maxValue))
                else
                    frame.timer:SetText(string.format("%.1f / %.1f", remaining, frame.maxValue))
                end
            end
            
            -- Update spark position
            if us.showSpark then
                local sparkPosition = (displayValue / frame.maxValue) * frame.statusBar:GetWidth()
                frame.spark:SetPoint("CENTER", frame.statusBar, "LEFT", sparkPosition, 0)
            end
        end
    end
end

-- ============================================================================
-- SIMULATION / PREVIEW
-- ============================================================================

local function ShowSimulation(unit)
    local frame = customCastBars[unit]
    if not frame then return end
    
    local us = settings[unit]
    if not us then return end
    
    -- Mark as simulating - this prevents OnUpdate from processing
    frame.simulating = true
    frame.casting = false
    frame.channeling = false
    frame.fadeOut = false
    frame.holdTime = 0
    frame.notInterruptible = false
    
    -- Static display at 50% progress
    frame.statusBar:SetMinMaxValues(0, 1)
    frame.statusBar:SetValue(0.5)
    
    -- Set color
    local color = us.castingColor
    frame.statusBar:SetStatusBarColor(color[1], color[2], color[3], color[4])
    
    -- Set spell name
    if us.showSpellName then
        frame.spellName:SetText("Simulated Cast")
    end
    
    -- Set icon
    if us.showIcon then
        frame.icon:SetTexture("Interface\\Icons\\Spell_Nature_Heal")
    end
    
    -- Set timer
    if us.showTimer then
        frame.timer:SetText("1.5")
    end
    
    -- Position spark at 50%
    if us.showSpark then
        local sparkPosition = 0.5 * frame.statusBar:GetWidth()
        frame.spark:SetPoint("CENTER", frame.statusBar, "LEFT", sparkPosition, 0)
    end
    
    -- NOTE: Shield texture removed in v2.0.0
    frame:SetAlpha(1)
    frame:Show()
end

local function HideSimulation(unit)
    local frame = customCastBars[unit]
    if not frame then return end
    
    frame.simulating = false
    frame.casting = false
    frame.channeling = false
    frame.fadeOut = false
    
    -- Only hide if no real cast is happening
    local name = UnitCastingInfo(unit) or UnitChannelInfo(unit)
    
    if not name then
        frame:Hide()
    end
end

-- ============================================================================
-- BLIZZARD CAST BAR HIDING
-- ============================================================================

-- Helper to hide a spell bar with hooks
local function HideSpellBarWithHooks(spellBar, settingsKey)
    if not spellBar then return end
    
    spellBar:SetAlpha(0)
    spellBar:SetScale(0.001)
    
    if not spellBar._tweaksHooked then
        -- Helper function for hiding
        local function HideBar(self)
            if CastBars.enabled and settings[settingsKey] and settings[settingsKey].enabled and settings[settingsKey].hideBlizzard then
                self:SetAlpha(0)
                self:SetScale(0.001)
            end
        end
        
        hooksecurefunc(spellBar, "Show", HideBar)
        spellBar:HookScript("OnShow", HideBar)
        
        -- Hook SetShown (different code path than Show)
        if spellBar.SetShown then
            hooksecurefunc(spellBar, "SetShown", function(self, shown)
                if shown then HideBar(self) end
            end)
        end
        
        -- Hook SetStatusBarColor (used for interrupt visual feedback)
        if spellBar.SetStatusBarColor then
            hooksecurefunc(spellBar, "SetStatusBarColor", HideBar)
        end
        
        -- Hook Flash (interrupt/failed cast flash animation) - check it's actually a function
        if spellBar.Flash and type(spellBar.Flash) == "function" then
            hooksecurefunc(spellBar, "Flash", HideBar)
        end
        
        -- OnUpdate fallback
        spellBar:HookScript("OnUpdate", function(self)
            if CastBars.enabled and settings[settingsKey] and settings[settingsKey].enabled and settings[settingsKey].hideBlizzard then
                if self:GetAlpha() > 0 or self:GetScale() > 0.01 then
                    self:SetAlpha(0)
                    self:SetScale(0.001)
                end
            end
        end)
        
        spellBar._tweaksHooked = true
    end
end

-- Helper to restore a spell bar
local function RestoreSpellBar(spellBar)
    if not spellBar then return end
    spellBar:SetAlpha(1)
    spellBar:SetScale(1)
end

-- Helper to check if the CastBars MODULE is enabled (not just individual unit settings)
local function IsModuleEnabled()
    return CastBars.enabled
end

local function HideBlizzardCastBars()
    -- Player cast bar
    if IsModuleEnabled() and settings.player and settings.player.enabled and settings.player.hideBlizzard then
        if PlayerCastingBarFrame then
            -- Use alpha and scale to hide without reparenting (reparenting breaks Blizzard positioning code)
            PlayerCastingBarFrame:SetAlpha(0)
            PlayerCastingBarFrame:SetScale(0.001)
            -- Hook Show to keep it hidden
            if not PlayerCastingBarFrame._tweaksHooked then
                -- Helper function for hiding
                local function HidePlayerCastBar(self)
                    if IsModuleEnabled() and settings.player and settings.player.enabled and settings.player.hideBlizzard then
                        self:SetAlpha(0)
                        self:SetScale(0.001)
                    end
                end
                
                hooksecurefunc(PlayerCastingBarFrame, "Show", HidePlayerCastBar)
                
                -- Also hook OnShow event
                PlayerCastingBarFrame:HookScript("OnShow", HidePlayerCastBar)
                
                -- Hook SetShown (different code path than Show)
                if PlayerCastingBarFrame.SetShown then
                    hooksecurefunc(PlayerCastingBarFrame, "SetShown", function(self, shown)
                        if shown then HidePlayerCastBar(self) end
                    end)
                end
                
                -- Hook SetStatusBarColor (used for interrupt visual feedback)
                if PlayerCastingBarFrame.SetStatusBarColor then
                    hooksecurefunc(PlayerCastingBarFrame, "SetStatusBarColor", HidePlayerCastBar)
                end
                
                -- Hook Flash (interrupt/failed cast flash animation) - check it's actually a function
                if PlayerCastingBarFrame.Flash and type(PlayerCastingBarFrame.Flash) == "function" then
                    hooksecurefunc(PlayerCastingBarFrame, "Flash", HidePlayerCastBar)
                end
                
                -- Hook PlayInterruptAnims if it exists (Midnight+)
                if PlayerCastingBarFrame.PlayInterruptAnims and type(PlayerCastingBarFrame.PlayInterruptAnims) == "function" then
                    hooksecurefunc(PlayerCastingBarFrame, "PlayInterruptAnims", HidePlayerCastBar)
                end
                
                -- Add OnUpdate to continuously enforce hiding (catches zone transition issues)
                PlayerCastingBarFrame:HookScript("OnUpdate", function(self)
                    if IsModuleEnabled() and settings.player and settings.player.enabled and settings.player.hideBlizzard then
                        if self:GetAlpha() > 0 or self:GetScale() > 0.01 then
                            self:SetAlpha(0)
                            self:SetScale(0.001)
                        end
                    end
                end)
                PlayerCastingBarFrame._tweaksHooked = true
            end
        end
    elseif PlayerCastingBarFrame then
        -- Restore if our module is disabled or hideBlizzard is false
        PlayerCastingBarFrame:SetAlpha(1)
        PlayerCastingBarFrame:SetScale(1)
    end
    
    -- Target cast bar
    if IsModuleEnabled() and settings.target and settings.target.enabled and settings.target.hideBlizzard then
        if TargetFrameSpellBar then
            TargetFrameSpellBar:SetAlpha(0)
            TargetFrameSpellBar:SetScale(0.001)
            if not TargetFrameSpellBar._tweaksHooked then
                -- Helper function for hiding - hide bar AND all children
                local function HideTargetCastBar(self)
                    if IsModuleEnabled() and settings.target and settings.target.enabled and settings.target.hideBlizzard then
                        self:SetAlpha(0)
                        self:SetScale(0.001)
                        -- Hide all children too (Text, Icon, Flash, Border, etc.)
                        for _, child in pairs({self:GetChildren()}) do
                            if child.SetAlpha then child:SetAlpha(0) end
                            if child.Hide then pcall(child.Hide, child) end
                        end
                        for _, region in pairs({self:GetRegions()}) do
                            if region.SetAlpha then region:SetAlpha(0) end
                            if region.Hide then pcall(region.Hide, region) end
                        end
                    end
                end
                
                hooksecurefunc(TargetFrameSpellBar, "Show", HideTargetCastBar)
                TargetFrameSpellBar:HookScript("OnShow", HideTargetCastBar)
                
                -- Hook SetShown
                if TargetFrameSpellBar.SetShown then
                    hooksecurefunc(TargetFrameSpellBar, "SetShown", function(self, shown)
                        if shown then HideTargetCastBar(self) end
                    end)
                end
                
                -- Hook SetStatusBarColor (used for interrupt visual feedback)
                if TargetFrameSpellBar.SetStatusBarColor then
                    hooksecurefunc(TargetFrameSpellBar, "SetStatusBarColor", HideTargetCastBar)
                end
                
                -- Hook Flash (if it's a function method)
                if TargetFrameSpellBar.Flash and type(TargetFrameSpellBar.Flash) == "function" then
                    hooksecurefunc(TargetFrameSpellBar, "Flash", HideTargetCastBar)
                end
                
                -- Hide Flash child frame/texture (interrupt animation visual)
                if TargetFrameSpellBar.Flash and type(TargetFrameSpellBar.Flash) ~= "function" then
                    local flash = TargetFrameSpellBar.Flash
                    if flash.Hide then
                        flash:Hide()
                        flash:SetAlpha(0)
                        if flash.HookScript then
                            flash:HookScript("OnShow", function(self)
                                if IsModuleEnabled() and settings.target and settings.target.enabled and settings.target.hideBlizzard then
                                    self:Hide()
                                    self:SetAlpha(0)
                                end
                            end)
                        end
                    end
                end
                
                -- Hide Text element (shows "Interrupted" text)
                if TargetFrameSpellBar.Text then
                    TargetFrameSpellBar.Text:SetAlpha(0)
                    hooksecurefunc(TargetFrameSpellBar.Text, "SetText", function(self)
                        if IsModuleEnabled() and settings.target and settings.target.enabled and settings.target.hideBlizzard then
                            self:SetAlpha(0)
                        end
                    end)
                end
                
                -- OnUpdate fallback - aggressively hide everything
                TargetFrameSpellBar:HookScript("OnUpdate", function(self)
                    if IsModuleEnabled() and settings.target and settings.target.enabled and settings.target.hideBlizzard then
                        if self:GetAlpha() > 0 or self:GetScale() > 0.01 then
                            HideTargetCastBar(self)
                        end
                    end
                end)
                
                TargetFrameSpellBar._tweaksHooked = true
            end
        end
        
        -- Also hide Target-of-Target spell bar (prevents overlap with custom target cast bar)
        local totSpellBar = TargetFrameToT and TargetFrameToT.SpellBar
        if totSpellBar then
            HideSpellBarWithHooks(totSpellBar, "target")
        end
        -- Alternative frame name in some versions
        if TargetFrameToTSpellBar then
            HideSpellBarWithHooks(TargetFrameToTSpellBar, "target")
        end
    elseif TargetFrameSpellBar then
        TargetFrameSpellBar:SetAlpha(1)
        TargetFrameSpellBar:SetScale(1)
        -- Restore ToT spell bar
        local totSpellBar = TargetFrameToT and TargetFrameToT.SpellBar
        RestoreSpellBar(totSpellBar)
        RestoreSpellBar(TargetFrameToTSpellBar)
    end
    
    -- Focus cast bar
    if IsModuleEnabled() and settings.focus and settings.focus.enabled and settings.focus.hideBlizzard then
        if FocusFrameSpellBar then
            FocusFrameSpellBar:SetAlpha(0)
            FocusFrameSpellBar:SetScale(0.001)
            if not FocusFrameSpellBar._tweaksHooked then
                -- Helper function for hiding
                local function HideFocusCastBar(self)
                    if IsModuleEnabled() and settings.focus and settings.focus.enabled and settings.focus.hideBlizzard then
                        self:SetAlpha(0)
                        self:SetScale(0.001)
                    end
                end
                
                hooksecurefunc(FocusFrameSpellBar, "Show", HideFocusCastBar)
                FocusFrameSpellBar:HookScript("OnShow", HideFocusCastBar)
                
                -- Hook SetShown
                if FocusFrameSpellBar.SetShown then
                    hooksecurefunc(FocusFrameSpellBar, "SetShown", function(self, shown)
                        if shown then HideFocusCastBar(self) end
                    end)
                end
                
                -- Hook SetStatusBarColor (used for interrupt visual feedback)
                if FocusFrameSpellBar.SetStatusBarColor then
                    hooksecurefunc(FocusFrameSpellBar, "SetStatusBarColor", HideFocusCastBar)
                end
                
                -- Hook Flash (if it's a function method)
                if FocusFrameSpellBar.Flash and type(FocusFrameSpellBar.Flash) == "function" then
                    hooksecurefunc(FocusFrameSpellBar, "Flash", HideFocusCastBar)
                end
                
                -- Hide Flash child frame/texture (interrupt animation visual)
                if FocusFrameSpellBar.Flash and type(FocusFrameSpellBar.Flash) ~= "function" then
                    local flash = FocusFrameSpellBar.Flash
                    if flash.Hide then
                        flash:Hide()
                        flash:SetAlpha(0)
                        if flash.HookScript then
                            flash:HookScript("OnShow", function(self)
                                if IsModuleEnabled() and settings.focus and settings.focus.enabled and settings.focus.hideBlizzard then
                                    self:Hide()
                                    self:SetAlpha(0)
                                end
                            end)
                        end
                    end
                end
                
                -- OnUpdate fallback
                FocusFrameSpellBar:HookScript("OnUpdate", function(self)
                    if IsModuleEnabled() and settings.focus and settings.focus.enabled and settings.focus.hideBlizzard then
                        if self:GetAlpha() > 0 or self:GetScale() > 0.01 then
                            self:SetAlpha(0)
                            self:SetScale(0.001)
                        end
                    end
                end)
                
                FocusFrameSpellBar._tweaksHooked = true
            end
        end
        
        -- Also hide Focus-of-Target spell bar
        local fotSpellBar = FocusFrameToT and FocusFrameToT.SpellBar
        if fotSpellBar then
            HideSpellBarWithHooks(fotSpellBar, "focus")
        end
        if FocusFrameToTSpellBar then
            HideSpellBarWithHooks(FocusFrameToTSpellBar, "focus")
        end
    elseif FocusFrameSpellBar then
        FocusFrameSpellBar:SetAlpha(1)
        FocusFrameSpellBar:SetScale(1)
        -- Restore FoT spell bar
        local fotSpellBar = FocusFrameToT and FocusFrameToT.SpellBar
        RestoreSpellBar(fotSpellBar)
        RestoreSpellBar(FocusFrameToTSpellBar)
    end
end

local function RestoreBlizzardCastBars()
    -- Restore player cast bar
    if PlayerCastingBarFrame then
        PlayerCastingBarFrame:SetAlpha(1)
        PlayerCastingBarFrame:SetScale(1)
    end
    
    if TargetFrameSpellBar then
        TargetFrameSpellBar:SetAlpha(1)
        TargetFrameSpellBar:SetScale(1)
    end
    
    -- Restore ToT spell bar
    local totSpellBar = TargetFrameToT and TargetFrameToT.SpellBar
    RestoreSpellBar(totSpellBar)
    RestoreSpellBar(TargetFrameToTSpellBar)
    
    if FocusFrameSpellBar then
        FocusFrameSpellBar:SetAlpha(1)
        FocusFrameSpellBar:SetScale(1)
    end
    
    -- Restore FoT spell bar
    local fotSpellBar = FocusFrameToT and FocusFrameToT.SpellBar
    RestoreSpellBar(fotSpellBar)
    RestoreSpellBar(FocusFrameToTSpellBar)
end

-- ============================================================================
-- EDIT MODE INTEGRATION (must be before UI code that uses it)
-- ============================================================================

local function RegisterWithEditMode(unit)
    local frame = customCastBars[unit]
    if not frame then return end
    
    -- Use centralized EditModeManager
    if not TweaksUI.EditMode then return end
    
    local unitSettings = settings[unit]
    if not unitSettings then return end
    
    -- Check if already registered
    if frame._editModeRegistered then return end
    
    local function OnPositionChanged(movedFrame, point, x, y)
        unitSettings.anchor = point
        unitSettings.x = x
        unitSettings.y = y
        TweaksUI:PrintDebug("CastBar " .. unit .. " moved to " .. x .. ", " .. y)
    end
    
    TweaksUI.EditMode:RegisterFrame(frame, {
        name = "TweaksUI: " .. unit .. " Cast Bar",
        onPositionChanged = OnPositionChanged,
        default = {
            point = unitSettings.anchor or "CENTER",
            x = unitSettings.x or 0,
            y = unitSettings.y or 0,
        },
    })
    
    frame._editModeRegistered = true
    TweaksUI:PrintDebug("CastBar " .. unit .. " registered with EditModeManager")
end

-- ============================================================================
-- EVENT HANDLING
-- ============================================================================

local eventFrame = CreateFrame("Frame")

local function OnEvent(self, event, ...)
    local args = {...}
    local unit, castGUID, spellID
    
    -- Midnight changed event args for EMPOWER events:
    -- EMPOWER events: unit, castGUID(nil), castBarID, spellID
    -- Regular events: unit, castGUID, spellID
    if event:find("EMPOWER") then
        unit = args[1]
        castGUID = args[2]
        spellID = args[4]  -- spellID is at position 4 for EMPOWER events
    else
        unit = args[1]
        castGUID = args[2]
        spellID = args[3]
    end
    
    if event == "PLAYER_ENTERING_WORLD" then
        -- Check for any active casts on login/reload
        for _, castUnit in ipairs(CAST_BAR_UNITS) do
            if customCastBars[castUnit] and settings[castUnit] and settings[castUnit].enabled then
                local name = UnitCastingInfo(castUnit)
                if name then
                    StartCast(customCastBars[castUnit], castUnit, false)
                else
                    name = UnitChannelInfo(castUnit)
                    if name then
                        StartCast(customCastBars[castUnit], castUnit, true)
                    end
                end
            end
        end
        HideBlizzardCastBars()
        -- Also hide after delays to catch Blizzard showing them after zone loads
        C_Timer.After(0.5, HideBlizzardCastBars)
        C_Timer.After(1.0, HideBlizzardCastBars)
        C_Timer.After(2.0, HideBlizzardCastBars)
        return
    end
    
    -- Handle target/focus changed - check for ongoing casts or clear cast bar
    if event == "PLAYER_TARGET_CHANGED" then
        local targetUnit = "target"
        local frame = customCastBars[targetUnit]
        if frame and settings[targetUnit] and settings[targetUnit].enabled then
            -- Don't process while panel is open (simulation mode)
            if currentOpenPanel ~= targetUnit then
                -- First, always stop any existing cast display
                if frame.casting or frame.channeling then
                    StopCast(frame, targetUnit, false)
                end
                
                -- Then check if new target exists and is casting
                if UnitExists(targetUnit) then
                    local name = UnitCastingInfo(targetUnit)
                    if name then
                        StartCast(frame, targetUnit, false)
                    else
                        name = UnitChannelInfo(targetUnit)
                        if name then
                            StartCast(frame, targetUnit, true)
                        end
                    end
                end
            end
        end
        return
    end
    
    if event == "PLAYER_FOCUS_CHANGED" then
        local focusUnit = "focus"
        local frame = customCastBars[focusUnit]
        if frame and settings[focusUnit] and settings[focusUnit].enabled then
            -- Don't process while panel is open (simulation mode)
            if currentOpenPanel ~= focusUnit then
                -- First, always stop any existing cast display
                if frame.casting or frame.channeling then
                    StopCast(frame, focusUnit, false)
                end
                
                -- Then check if new focus exists and is casting
                if UnitExists(focusUnit) then
                    local name = UnitCastingInfo(focusUnit)
                    if name then
                        StartCast(frame, focusUnit, false)
                    else
                        name = UnitChannelInfo(focusUnit)
                        if name then
                            StartCast(frame, focusUnit, true)
                        end
                    end
                end
            end
        end
        return
    end
    
    -- Filter to our tracked units
    local isTrackedUnit = false
    for _, castUnit in ipairs(CAST_BAR_UNITS) do
        if unit == castUnit then
            isTrackedUnit = true
            break
        end
    end
    if not isTrackedUnit then return end
    
    local frame = customCastBars[unit]
    if not frame then return end
    
    local us = settings[unit]
    if not us or not us.enabled then return end
    
    -- Don't process events while panel is open (simulation mode)
    if currentOpenPanel == unit then return end
    
    if event == "UNIT_SPELLCAST_START" then
        StartCast(frame, unit, false, castGUID)
        
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        StartCast(frame, unit, true, castGUID)
        
    elseif event == "UNIT_SPELLCAST_EMPOWER_START" then
        -- Empowered spells are a type of channel (but fill up like casts)
        StartCast(frame, unit, true, castGUID, spellID)
        
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_EMPOWER_STOP" then
        -- Only stop if this event is for our current cast
        -- (castGUID may be nil or a secret value in Midnight)
        if frame.casting or frame.channeling then
            -- Use pcall to safely compare castID/castGUID (may be secret values in Midnight)
            local shouldStop = false
            if not frame.castID or not castGUID then
                shouldStop = true
            else
                local ok, matches = pcall(function() return frame.castID == castGUID end)
                if ok and matches then
                    shouldStop = true
                elseif not ok then
                    -- If comparison failed (secret value), assume it's our cast
                    shouldStop = true
                end
            end
            if shouldStop then
                StopCast(frame, unit, false)
            end
        end
        
    elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        -- CRITICAL: Only stop if this event is for our current cast!
        -- When you press another key during a cast, UNIT_SPELLCAST_FAILED fires for
        -- the NEW spell that failed to start, not for the current cast.
        -- We must verify the castGUID matches before stopping.
        if frame.casting then
            local shouldStop = false
            if frame.castID and castGUID then
                -- Use pcall to safely compare (may be secret values in Midnight)
                local ok, matches = pcall(function() return frame.castID == castGUID end)
                if ok and matches then
                    shouldStop = true
                end
                -- If comparison failed or didn't match, don't stop
            elseif not frame.castID and not castGUID then
                -- Fallback for edge cases where neither has an ID
                shouldStop = true
            end
            if shouldStop then
                StopCast(frame, unit, true)
            end
            -- If castGUIDs don't match, ignore this event - it's for a different spell
        end
        
    elseif event == "UNIT_SPELLCAST_DELAYED" then
        if frame.casting and not frame.useTimerBar then
            -- Only needed for non-timer bars - timer bars update automatically
            local name, text, texture, startTimeMS, endTimeMS = UnitCastingInfo(unit)
            if name then
                -- Protect against "secret value" in Midnight Beta
                local startTime, endTime
                local ok = pcall(function()
                    startTime = startTimeMS / 1000
                    endTime = endTimeMS / 1000
                end)
                if ok and startTime and endTime then
                    frame.startTime = startTime
                    frame.endTime = endTime
                    frame.maxValue = endTime - startTime
                    frame.statusBar:SetMinMaxValues(0, frame.maxValue)
                end
            end
        end
        
    elseif event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        if frame.channeling and not frame.useTimerBar then
            -- Only needed for non-timer bars - timer bars update automatically
            local name, text, texture, startTimeMS, endTimeMS = UnitChannelInfo(unit)
            if name then
                -- Protect against "secret value" in Midnight Beta
                local startTime, endTime
                local ok = pcall(function()
                    startTime = startTimeMS / 1000
                    endTime = endTimeMS / 1000
                end)
                if ok and startTime and endTime then
                    frame.startTime = startTime
                    frame.endTime = endTime
                    frame.maxValue = endTime - startTime
                    frame.statusBar:SetMinMaxValues(0, frame.maxValue)
                end
            end
        end
        
    elseif event == "UNIT_SPELLCAST_EMPOWER_UPDATE" then
        -- Empowered spells use duration objects for accurate timing
        if frame.channeling and frame.isEmpowered then
            if frame.useTimerBar and HAS_EMPOWER_DURATION then
                -- Timer bar: just update the duration object, bar updates itself
                local success, durationObj = pcall(function() return UnitEmpoweredChannelDuration(unit, true) end)
                if success and durationObj then
                    frame.durationObject = durationObj
                    -- Re-apply to timer bar
                    pcall(function()
                        frame.statusBar:SetTimerDuration(durationObj, BAR_INTERPOLATION, false)
                    end)
                end
            elseif HAS_EMPOWER_DURATION then
                -- Non-timer bar with Duration Object - extract values
                local success, durationObj = pcall(function() return UnitEmpoweredChannelDuration(unit, true) end)
                if success and durationObj then
                    frame.durationObject = durationObj
                    -- For non-timer bars, we need timing values for manual SetValue
                    local safeElapsed, safeRemaining = 0, 2
                    if durationObj.GetElapsedDuration then
                        pcall(function()
                            local elapsed = durationObj:GetElapsedDuration()
                            safeElapsed = SafeValue(elapsed) or 0
                        end)
                    end
                    if durationObj.GetRemainingDuration then
                        pcall(function()
                            local remaining = durationObj:GetRemainingDuration()
                            safeRemaining = SafeValue(remaining) or 2
                        end)
                    end
                    frame.startTime = GetTime() - safeElapsed
                    frame.endTime = GetTime() + safeRemaining
                    frame.maxValue = safeElapsed + safeRemaining
                    frame.statusBar:SetMinMaxValues(0, frame.maxValue)
                end
            else
                -- Fallback for non-Midnight: use standard channel update logic
                local name, text, texture, startTimeMS, endTimeMS = UnitChannelInfo(unit)
                if name then
                    local startTime, endTime
                    local ok = pcall(function()
                        startTime = startTimeMS / 1000
                        endTime = endTimeMS / 1000
                    end)
                    if ok and startTime and endTime then
                        frame.startTime = startTime
                        frame.endTime = endTime
                        frame.maxValue = endTime - startTime
                        frame.statusBar:SetMinMaxValues(0, frame.maxValue)
                    end
                end
            end
        end
        
    elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" or event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
        local notInterruptible = (event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
        frame.notInterruptible = notInterruptible
        
        -- Determine color based on interruptibility, importance, and cast type
        local color
        local isImportant = false
        
        -- Check if spell is important (using SpellAPI if available)
        if TweaksUI.SpellAPI and frame.spellID then
            isImportant = TweaksUI.SpellAPI:IsImportant(frame.spellID)
        end
        
        if notInterruptible then
            -- Non-interruptible always uses grey color
            color = us.nonInterruptibleColor
        elseif isImportant then
            -- Important spell uses special color
            if frame.channeling then
                color = us.importantChannelColor or us.channelingColor
            else
                color = us.importantCastColor or us.castingColor
            end
        else
            -- Normal spell
            if frame.channeling then
                color = us.channelingColor
            else
                color = us.castingColor
            end
        end
        frame.statusBar:SetStatusBarColor(color[1], color[2], color[3], color[4])
    end
end

local function OnUpdate(self, elapsed)
    -- Skip all processing if module is disabled
    if not CastBars.enabled then return end
    
    for _, unit in ipairs(CAST_BAR_UNITS) do
        local frame = customCastBars[unit]
        if frame and frame:IsShown() then
            -- Skip OnUpdate processing during simulation or panel open
            if not frame.simulating and currentOpenPanel ~= unit then
                UpdateCastBar(frame, elapsed)
            end
        end
    end
end

-- ============================================================================
-- SETTINGS UI
-- ============================================================================

-- Dark backdrop template (matching UnitFrames)
local darkBackdrop = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
}

local BUTTON_HEIGHT = 28
local BUTTON_SPACING = 4

function CastBars:ShowHub(parentPanel)
    if castBarsHub then
        castBarsHub:ClearAllPoints()
        castBarsHub:SetPoint("TOPLEFT", parentPanel, "TOPRIGHT", 0, 0)
        castBarsHub:Show()
        return
    end
    
    -- Create hub
    local hub = CreateFrame("Frame", "TweaksUI_CastBars_Hub", UIParent, "BackdropTemplate")
    hub:SetSize(HUB_WIDTH, 350)  -- Increased height for preset dropdown
    hub:SetPoint("TOPLEFT", parentPanel, "TOPRIGHT", 0, 0)
    hub:SetBackdrop(darkBackdrop)
    hub:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    hub:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    hub:SetFrameStrata("DIALOG")
    hub:SetMovable(true)
    hub:EnableMouse(true)
    hub:SetClampedToScreen(true)
    
    castBarsHub = hub
    
    -- Title
    local title = hub:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("Cast Bars")
    title:SetTextColor(1, 0.82, 0)
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, hub, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -3, -3)
    closeBtn:SetScript("OnClick", function()
        self:HideAllPanels()
    end)
    
    -- Make draggable
    hub:RegisterForDrag("LeftButton")
    hub:SetScript("OnDragStart", hub.StartMoving)
    hub:SetScript("OnDragStop", hub.StopMovingOrSizing)
    
    -- Close all panels when hub is hidden
    hub:SetScript("OnHide", function()
        self:HideAllPanels()
    end)
    
    local yOffset = -38
    
    -- Add Preset Dropdown
    if TweaksUI.PresetDropdown then
        local presetContainer, nextY = TweaksUI.PresetDropdown:Create(
            hub,
            "castBars",
            "Cast Bars",
            yOffset,
            {
                width = 140,
                showSaveButton = true,
                showDeleteButton = true,
            }
        )
        yOffset = nextY - 8
    end
    
    local buttonWidth = HUB_WIDTH - 20
    
    -- Section label
    local sectionLabel = hub:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sectionLabel:SetPoint("TOP", 0, yOffset)
    sectionLabel:SetText("|cff888888Standalone Cast Bars|r")
    yOffset = yOffset - 16
    
    -- Unit buttons
    local displayNames = {
        player = "Player Cast Bar",
        target = "Target Cast Bar",
        focus = "Focus Cast Bar",
    }
    
    for _, unit in ipairs(CAST_BAR_UNITS) do
        local btn = CreateFrame("Button", nil, hub, "UIPanelButtonTemplate")
        btn:SetSize(buttonWidth, BUTTON_HEIGHT)
        btn:SetPoint("TOP", 0, yOffset)
        btn:SetText(displayNames[unit])
        btn:SetScript("OnClick", function()
            self:TogglePanel(unit)
        end)
        
        yOffset = yOffset - BUTTON_HEIGHT - BUTTON_SPACING
    end
    
    -- Separator
    yOffset = yOffset - 8
    local sep = hub:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOP", 0, yOffset)
    sep:SetSize(buttonWidth, 1)
    sep:SetColorTexture(0.4, 0.4, 0.4, 0.6)
    yOffset = yOffset - 12
    
    -- Import/Export section
    local ieLabel = hub:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ieLabel:SetPoint("TOP", 0, yOffset)
    ieLabel:SetText("|cff888888Import / Export|r")
    yOffset = yOffset - 20
    
    -- Export button
    local exportBtn = CreateFrame("Button", nil, hub, "UIPanelButtonTemplate")
    exportBtn:SetSize(buttonWidth, BUTTON_HEIGHT)
    exportBtn:SetPoint("TOP", 0, yOffset)
    exportBtn:SetText("Export All")
    exportBtn:SetScript("OnClick", function()
        self:ShowExportDialog()
    end)
    yOffset = yOffset - BUTTON_HEIGHT - BUTTON_SPACING
    
    -- Import button
    local importBtn = CreateFrame("Button", nil, hub, "UIPanelButtonTemplate")
    importBtn:SetSize(buttonWidth, BUTTON_HEIGHT)
    importBtn:SetPoint("TOP", 0, yOffset)
    importBtn:SetText("Import")
    importBtn:SetScript("OnClick", function()
        self:ShowImportDialog()
    end)
    
    hub:Show()
end

function CastBars:HideAllPanels()
    if castBarsHub then
        castBarsHub:Hide()
    end
    for _, panel in pairs(settingsPanels) do
        if panel and panel.Hide then
            panel:Hide()
        end
    end
    
    -- Clear preview state
    if currentOpenPanel then
        local prevPanel = currentOpenPanel
        currentOpenPanel = nil
        HideSimulation(prevPanel)
    end
end

function CastBars:TogglePanel(unit)
    -- Hide other panels
    for name, panel in pairs(settingsPanels) do
        if panel and name ~= unit then
            panel:Hide()
            if currentOpenPanel == name then
                currentOpenPanel = nil
                HideSimulation(name)
            end
        end
    end
    
    if settingsPanels[unit] then
        if settingsPanels[unit]:IsShown() then
            settingsPanels[unit]:Hide()
            if currentOpenPanel == unit then
                currentOpenPanel = nil
                HideSimulation(unit)
            end
        else
            settingsPanels[unit]:Show()
            currentOpenPanel = unit
            self:ShowPanelPreview(unit)
        end
    else
        self:CreateUnitPanel(unit)
        if settingsPanels[unit] then
            settingsPanels[unit]:Show()
            currentOpenPanel = unit
            self:ShowPanelPreview(unit)
        end
    end
end

function CastBars:ShowPanelPreview(unit)
    -- Create cast bar if needed
    if not customCastBars[unit] then
        customCastBars[unit] = CreateCastBar(unit)
    end
    
    local frame = customCastBars[unit]
    if frame then
        UpdateCastBarLayout(unit)
        ShowSimulation(unit)
    end
end

function CastBars:CreateUnitPanel(unit)
    local displayNames = {
        player = "Player Cast Bar",
        target = "Target Cast Bar",
        focus = "Focus Cast Bar",
    }
    
    local us = settings[unit]
    if not us then return end
    
    -- Callback for refreshing (shared across all tabs)
    local function RefreshCastBar()
        if customCastBars[unit] then
            UpdateCastBarLayout(unit)
            if currentOpenPanel == unit then
                ShowSimulation(unit)
            end
            RegisterWithEditMode(unit)
        end
        HideBlizzardCastBars()
    end
    
    -- =========================================================================
    -- TAB BUILDERS
    -- =========================================================================
    
    -- LAYOUT TAB
    local function BuildLayoutTab(scrollChild, panel)
        local y = -10
        local TP = TweaksUI.TabbedPanel
        
        -- Enable checkbox
        y = TP:CreateCheckbox(scrollChild, y, {
            label = "Enable " .. displayNames[unit],
            get = function() return us.enabled end,
            set = function(value)
                us.enabled = value
                CastBars:SaveSettings()
                if us.enabled then
                    if not customCastBars[unit] then
                        customCastBars[unit] = CreateCastBar(unit)
                    end
                    RefreshCastBar()
                    RegisterWithEditMode(unit)
                else
                    if customCastBars[unit] then
                        customCastBars[unit]:Hide()
                    end
                end
                HideBlizzardCastBars()
            end,
        })
        
        -- Hide Blizzard checkbox
        y = TP:CreateCheckbox(scrollChild, y, {
            label = "Hide Blizzard Cast Bar",
            get = function() return us.hideBlizzard end,
            set = function(value)
                us.hideBlizzard = value
                CastBars:SaveSettings()
                HideBlizzardCastBars()
            end,
        })
        
        y = y - 10
        y = TP:CreateHeader(scrollChild, y, "Size")
        
        -- Width slider
        y = TP:CreateSlider(scrollChild, y, {
            label = "Width:",
            min = 100, max = 500, step = 5,
            get = function() return us.width end,
            set = function(value) us.width = value; RefreshCastBar() end,
            labelWidth = 80, width = 150, valueWidth = 45,
        })
        
        -- Height slider
        y = TP:CreateSlider(scrollChild, y, {
            label = "Height:",
            min = 12, max = 60, step = 1,
            get = function() return us.height end,
            set = function(value) us.height = value; RefreshCastBar() end,
            labelWidth = 80, width = 150, valueWidth = 45,
        })
        
        -- Scale slider
        y = TP:CreateSlider(scrollChild, y, {
            label = "Scale:",
            min = 0.5, max = 2.0, step = 0.1,
            isFloat = true, decimals = 1,
            get = function() return us.scale end,
            set = function(value) us.scale = value; RefreshCastBar() end,
            labelWidth = 80, width = 150, valueWidth = 45,
        })
        
        y = y - 10
        y = TP:CreateHeader(scrollChild, y, "Position")
        
        -- X Position slider
        y = TP:CreateSlider(scrollChild, y, {
            label = "X Offset:",
            min = -600, max = 600, step = 1,
            get = function() return us.x end,
            set = function(value) us.x = value; RefreshCastBar() end,
            labelWidth = 80, width = 150, valueWidth = 50,
        })
        
        -- Y Position slider
        y = TP:CreateSlider(scrollChild, y, {
            label = "Y Offset:",
            min = -500, max = 500, step = 1,
            get = function() return us.y end,
            set = function(value) us.y = value; RefreshCastBar() end,
            labelWidth = 80, width = 150, valueWidth = 50,
        })
        
        y = y - 15
        y = TP:CreateHint(scrollChild, y, "Tip: Use Layout Mode (/tui layout) to drag cast bars to position them visually.")
    end
    
    -- APPEARANCE TAB
    local function BuildAppearanceTab(scrollChild, panel)
        local y = -10
        local TP = TweaksUI.TabbedPanel
        
        y = TP:CreateHeader(scrollChild, y, "Bar Style")
        
        -- Bar Texture dropdown
        y = TP:CreateTextureDropdown(scrollChild, y, {
            label = "Bar Texture",
            width = 160,
            get = function() return us.texture or "Blizzard" end,
            set = function(value)
                us.texture = value
                CastBars:SaveSettings()
                RefreshCastBar()
            end,
            showPreview = true,
        })
        
        -- Bar Shape dropdown
        local shapeLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        shapeLabel:SetPoint("TOPLEFT", 10, y)
        shapeLabel:SetText("Bar Shape")
        
        local shapeDropdown = CreateFrame("Frame", "TweaksUICastBars" .. unit .. "ShapeDropdown", scrollChild, "UIDropDownMenuTemplate")
        shapeDropdown:SetPoint("TOPLEFT", -6, y - 18)
        UIDropDownMenu_SetWidth(shapeDropdown, 160)
        local currentShapeName = TweaksUI.BarMasking and TweaksUI.BarMasking:GetShapeName(us.maskShape or "none") or "Square (None)"
        UIDropDownMenu_SetText(shapeDropdown, currentShapeName)
        
        UIDropDownMenu_Initialize(shapeDropdown, function(self, level)
            if not TweaksUI.BarMasking then return end
            for _, shape in ipairs(TweaksUI.BarMasking:GetShapeList()) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = TweaksUI.BarMasking:GetShapeName(shape)
                info.checked = ((us.maskShape or "none") == shape)
                info.func = function()
                    us.maskShape = shape
                    UIDropDownMenu_SetText(shapeDropdown, TweaksUI.BarMasking:GetShapeName(shape))
                    CastBars:SaveSettings()
                    RefreshCastBar()
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
        y = y - 50
        
        y = y - 10
        y = TP:CreateHeader(scrollChild, y, "Elements")
        
        -- Show Border checkbox
        y = TP:CreateCheckbox(scrollChild, y, {
            label = "Show Border",
            get = function() return us.showBorder end,
            set = function(value)
                us.showBorder = value
                CastBars:SaveSettings()
                RefreshCastBar()
            end,
        })
        
        -- Show Spark checkbox
        y = TP:CreateCheckbox(scrollChild, y, {
            label = "Show Spark",
            get = function() return us.showSpark end,
            set = function(value)
                us.showSpark = value
                CastBars:SaveSettings()
                RefreshCastBar()
            end,
        })
        
        y = y - 10
        y = TP:CreateHeader(scrollChild, y, "Empowered Spells")
        
        y = TP:CreateHint(scrollChild, y, "Settings for Evoker empowered spells (Fire Breath, etc.)")
        
        -- Show Stage Dividers checkbox
        y = TP:CreateCheckbox(scrollChild, y, {
            label = "Show Stage Dividers",
            get = function() return us.showEmpowerStages ~= false end,
            set = function(value)
                us.showEmpowerStages = value
                CastBars:SaveSettings()
                RefreshCastBar()
            end,
        })
        
        -- Show Stage Text checkbox
        y = TP:CreateCheckbox(scrollChild, y, {
            label = "Show Stage Text (Stage 1, 2, 3)",
            get = function() return us.showEmpowerStageText ~= false end,
            set = function(value)
                us.showEmpowerStageText = value
                CastBars:SaveSettings()
                RefreshCastBar()
            end,
        })
        
        y = y - 10
        y = TP:CreateHeader(scrollChild, y, "Bar Colors")
        
        -- Helper function to create color picker with swatch
        local function CreateColorRow(label, colorKey, yPos)
            local rowContainer = CreateFrame("Frame", nil, scrollChild)
            rowContainer:SetPoint("TOPLEFT", 10, yPos)
            rowContainer:SetSize(280, 24)
            
            local rowLabel = rowContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            rowLabel:SetPoint("LEFT", 0, 0)
            rowLabel:SetText(label)
            rowLabel:SetWidth(140)
            rowLabel:SetJustifyH("LEFT")
            
            -- Ensure color exists with defaults
            if not us[colorKey] or type(us[colorKey]) ~= "table" then
                us[colorKey] = {1, 1, 1, 1}  -- Default white
            end
            
            local swatch = CreateFrame("Button", nil, rowContainer)
            swatch:SetPoint("LEFT", 145, 0)
            swatch:SetSize(24, 24)
            
            -- Border texture (behind)
            local swatchBorder = swatch:CreateTexture(nil, "BACKGROUND")
            swatchBorder:SetPoint("TOPLEFT", -2, 2)
            swatchBorder:SetPoint("BOTTOMRIGHT", 2, -2)
            swatchBorder:SetColorTexture(0.4, 0.4, 0.4, 1)
            
            -- Color texture (front)
            local swatchColor = swatch:CreateTexture(nil, "OVERLAY")
            swatchColor:SetAllPoints()
            local c = us[colorKey]
            swatchColor:SetColorTexture(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
            
            swatch:SetScript("OnClick", function()
                local currentColor = us[colorKey] or {1, 1, 1, 1}
                local prev = { r = currentColor[1] or 1, g = currentColor[2] or 1, b = currentColor[3] or 1, a = currentColor[4] or 1 }
                
                ColorPickerFrame:SetupColorPickerAndShow({
                    r = prev.r, g = prev.g, b = prev.b, opacity = prev.a,
                    hasOpacity = true,
                    swatchFunc = function()
                        local r, g, b = ColorPickerFrame:GetColorRGB()
                        local a = ColorPickerFrame:GetColorAlpha()
                        us[colorKey] = { r, g, b, a }
                        swatchColor:SetColorTexture(r, g, b, a)
                        CastBars:SaveSettings()
                        RefreshCastBar()
                    end,
                    cancelFunc = function()
                        us[colorKey] = { prev.r, prev.g, prev.b, prev.a }
                        swatchColor:SetColorTexture(prev.r, prev.g, prev.b, prev.a)
                        CastBars:SaveSettings()
                        RefreshCastBar()
                    end,
                })
            end)
            
            swatch:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Click to change color")
                GameTooltip:Show()
            end)
            swatch:SetScript("OnLeave", function() GameTooltip:Hide() end)
            
            return yPos - 28
        end
        
        y = CreateColorRow("Casting Color", "castingColor", y)
        y = CreateColorRow("Channeling Color", "channelingColor", y)
        y = CreateColorRow("Non-Interruptible Color", "nonInterruptibleColor", y)
        y = CreateColorRow("Failed Cast Color", "failedColor", y)
        y = CreateColorRow("Background Color", "backgroundColor", y)
    end
    
    -- TEXT TAB
    local function BuildTextTab(scrollChild, panel)
        local y = -10
        local TP = TweaksUI.TabbedPanel
        
        y = TP:CreateHeader(scrollChild, y, "Timer")
        
        -- Show Timer checkbox
        y = TP:CreateCheckbox(scrollChild, y, {
            label = "Show Timer",
            get = function() return us.showTimer end,
            set = function(value)
                us.showTimer = value
                CastBars:SaveSettings()
                RefreshCastBar()
            end,
        })
        
        -- Timer Format dropdown
        y = TP:CreateDropdown(scrollChild, y, {
            label = "Timer Format",
            width = 140,
            items = {
                { value = "remaining", text = "Remaining" },
                { value = "total", text = "Total" },
                { value = "both", text = "Both" },
            },
            get = function() return us.timerFormat end,
            set = function(value)
                us.timerFormat = value
                CastBars:SaveSettings()
                RefreshCastBar()
            end,
        })
        
        -- Timer Position dropdown
        y = TP:CreateDropdown(scrollChild, y, {
            label = "Timer Position",
            width = 140,
            items = {
                { value = "LEFT", text = "Left" },
                { value = "CENTER", text = "Center" },
                { value = "RIGHT", text = "Right" },
            },
            get = function() return us.timerPosition end,
            set = function(value)
                us.timerPosition = value
                CastBars:SaveSettings()
                RefreshCastBar()
            end,
        })
        
        -- Timer Font Size slider
        y = TP:CreateSlider(scrollChild, y, {
            label = "Timer Size:",
            min = 8, max = 20, step = 1,
            get = function() return us.timerFontSize end,
            set = function(value) us.timerFontSize = value; CastBars:SaveSettings(); RefreshCastBar() end,
            labelWidth = 90, width = 120, valueWidth = 40,
        })
        
        y = y - 15
        y = TP:CreateHeader(scrollChild, y, "Spell Name")
        
        -- Show Spell Name checkbox
        y = TP:CreateCheckbox(scrollChild, y, {
            label = "Show Spell Name",
            get = function() return us.showSpellName end,
            set = function(value)
                us.showSpellName = value
                CastBars:SaveSettings()
                RefreshCastBar()
            end,
        })
        
        -- Spell Name Position dropdown
        y = TP:CreateDropdown(scrollChild, y, {
            label = "Name Position",
            width = 140,
            items = {
                { value = "LEFT", text = "Left" },
                { value = "CENTER", text = "Center" },
                { value = "RIGHT", text = "Right" },
            },
            get = function() return us.spellNamePosition end,
            set = function(value)
                us.spellNamePosition = value
                CastBars:SaveSettings()
                RefreshCastBar()
            end,
        })
        
        -- Spell Name Font Size slider
        y = TP:CreateSlider(scrollChild, y, {
            label = "Name Size:",
            min = 8, max = 20, step = 1,
            get = function() return us.spellNameFontSize end,
            set = function(value) us.spellNameFontSize = value; CastBars:SaveSettings(); RefreshCastBar() end,
            labelWidth = 90, width = 120, valueWidth = 40,
        })
        
        y = y - 15
        y = TP:CreateHeader(scrollChild, y, "Font")
        
        -- Font dropdown
        y = TP:CreateFontDropdown(scrollChild, y, {
            label = "Font",
            width = 160,
            get = function() return us.font or "Friz Quadrata TT" end,
            set = function(value)
                us.font = value
                CastBars:SaveSettings()
                RefreshCastBar()
            end,
            showPreview = true,
        })
    end
    
    -- ICON TAB
    local function BuildIconTab(scrollChild, panel)
        local y = -10
        local TP = TweaksUI.TabbedPanel
        
        y = TP:CreateHeader(scrollChild, y, "Spell Icon")
        
        -- Show Icon checkbox
        y = TP:CreateCheckbox(scrollChild, y, {
            label = "Show Spell Icon",
            get = function() return us.showIcon end,
            set = function(value)
                us.showIcon = value
                CastBars:SaveSettings()
                RefreshCastBar()
            end,
        })
        
        -- Icon Position dropdown
        y = TP:CreateDropdown(scrollChild, y, {
            label = "Icon Position",
            width = 120,
            items = {
                { value = "LEFT", text = "Left" },
                { value = "RIGHT", text = "Right" },
            },
            get = function() return us.iconPosition end,
            set = function(value)
                us.iconPosition = value
                CastBars:SaveSettings()
                RefreshCastBar()
            end,
        })
        
        -- Icon Size slider
        y = TP:CreateSlider(scrollChild, y, {
            label = "Icon Size:",
            min = 12, max = 48, step = 1,
            get = function() return us.iconSize end,
            set = function(value) us.iconSize = value; CastBars:SaveSettings(); RefreshCastBar() end,
            labelWidth = 80, width = 140, valueWidth = 40,
        })
        
        y = y - 20
        y = TP:CreateHint(scrollChild, y, "The spell icon displays next to the cast bar showing what spell is being cast.")
    end
    
    -- =========================================================================
    -- CREATE TABBED PANEL
    -- =========================================================================
    
    local panel = TweaksUI.TabbedPanel:Create({
        name = "CastBars_" .. unit .. "_Panel",
        title = displayNames[unit],
        width = PANEL_WIDTH,
        height = PANEL_HEIGHT,
        scrollChildHeight = 600,
        tabs = {
            { key = "layout", label = "Layout", builder = BuildLayoutTab },
            { key = "appearance", label = "Appearance", builder = BuildAppearanceTab },
            { key = "text", label = "Text", builder = BuildTextTab },
            { key = "icon", label = "Icon", builder = BuildIconTab },
        },
        onShow = function(self)
            -- Position next to hub when shown
            if castBarsHub then
                self:ClearAllPoints()
                self:SetPoint("TOPLEFT", castBarsHub, "TOPRIGHT", 0, 0)
            end
        end,
    })
    
    -- Position next to hub initially
    if castBarsHub then
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", castBarsHub, "TOPRIGHT", 0, 0)
    end
    
    settingsPanels[unit] = panel
    panel:Hide()
end

-- ============================================================================
-- IMPORT/EXPORT
-- ============================================================================

function CastBars:ShowExportDialog()
    local exportData = {
        version = 1,
        player = settings.player and DeepCopy(settings.player) or nil,
        target = settings.target and DeepCopy(settings.target) or nil,
        focus = settings.focus and DeepCopy(settings.focus) or nil,
    }
    
    -- Serialize
    local json = serializeValue(exportData)
    local serialized = "TUI_CB1:" .. json
    
    -- Create dialog
    local dialog = CreateFrame("Frame", "TweaksUI_CastBars_ExportDialog", UIParent, "BackdropTemplate")
    dialog:SetSize(500, 250)
    dialog:SetPoint("CENTER")
    dialog:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    dialog:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    dialog:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    dialog:SetFrameStrata("DIALOG")
    dialog:EnableMouse(true)
    dialog:SetMovable(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
    
    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("Export Cast Bars Settings")
    
    local instructions = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    instructions:SetPoint("TOP", 0, -40)
    instructions:SetText("Copy this string to share your settings (Ctrl+C):")
    
    local scrollFrame = CreateFrame("ScrollFrame", nil, dialog, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 15, -60)
    scrollFrame:SetPoint("BOTTOMRIGHT", -35, 50)
    
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetWidth(scrollFrame:GetWidth() - 10)
    editBox:SetAutoFocus(true)
    editBox:SetText(serialized)
    scrollFrame:SetScrollChild(editBox)
    
    -- Auto-select all text
    C_Timer.After(0.1, function()
        editBox:HighlightText()
    end)
    
    local selectBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    selectBtn:SetSize(100, 24)
    selectBtn:SetPoint("BOTTOMLEFT", 15, 15)
    selectBtn:SetText("Select All")
    selectBtn:SetScript("OnClick", function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)
    
    local closeBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    closeBtn:SetSize(80, 24)
    closeBtn:SetPoint("BOTTOMRIGHT", -15, 15)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() dialog:Hide() end)
    
    editBox:SetScript("OnEscapePressed", function() dialog:Hide() end)
    
    dialog:Show()
end

function CastBars:ShowImportDialog()
    local dialog = CreateFrame("Frame", "TweaksUI_CastBars_ImportDialog", UIParent, "BackdropTemplate")
    dialog:SetSize(500, 250)
    dialog:SetPoint("CENTER")
    dialog:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    dialog:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    dialog:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    dialog:SetFrameStrata("DIALOG")
    dialog:EnableMouse(true)
    dialog:SetMovable(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
    
    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("Import Cast Bars Settings")
    
    local instructions = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    instructions:SetPoint("TOP", 0, -40)
    instructions:SetText("Paste your exported settings below (Ctrl+V):")
    
    local scrollFrame = CreateFrame("ScrollFrame", nil, dialog, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 15, -60)
    scrollFrame:SetPoint("BOTTOMRIGHT", -35, 80)
    
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetWidth(scrollFrame:GetWidth() - 10)
    editBox:SetAutoFocus(true)
    scrollFrame:SetScrollChild(editBox)
    
    local statusText = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("BOTTOM", 0, 55)
    statusText:SetText("")
    
    local importBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    importBtn:SetSize(80, 24)
    importBtn:SetPoint("BOTTOMLEFT", dialog, "BOTTOM", -50, 15)
    importBtn:SetText("Import")
    
    local closeBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    closeBtn:SetSize(80, 24)
    closeBtn:SetPoint("BOTTOMRIGHT", dialog, "BOTTOM", 50, 15)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() dialog:Hide() end)
    
    importBtn:SetScript("OnClick", function()
        local text = editBox:GetText()
        if text:match("^TUI_CB1:") then
            local dataStr = text:gsub("^TUI_CB1:", "")
            local success, importData = pcall(function()
                local result, _ = deserializeValue(dataStr, 1)
                return result
            end)
            
            if success and importData and importData.version then
                -- Apply imported settings
                local imported = {}
                for _, unit in ipairs(CAST_BAR_UNITS) do
                    if importData[unit] then
                        for k, v in pairs(importData[unit]) do
                            settings[unit][k] = DeepCopy(v)
                        end
                        table.insert(imported, unit)
                    end
                end
                
                -- Refresh all cast bars
                for _, unit in ipairs(CAST_BAR_UNITS) do
                    if customCastBars[unit] then
                        UpdateCastBarLayout(unit)
                    end
                end
                
                statusText:SetText("|cFF00FF00Import successful! Imported: " .. table.concat(imported, ", ") .. "|r")
                statusText:SetTextColor(0, 1, 0)
            else
                statusText:SetText("|cFFFF0000Invalid import data|r")
                statusText:SetTextColor(1, 0, 0)
            end
        else
            statusText:SetText("|cFFFF0000Invalid format (expected TUI_CB1:...)|r")
            statusText:SetTextColor(1, 0, 0)
        end
    end)
    
    editBox:SetScript("OnEscapePressed", function() dialog:Hide() end)
    
    dialog:Show()
end

-- ============================================================================
-- MODULE INITIALIZATION
-- ============================================================================

-- ============================================================================
-- EDIT MODE HOOKS
-- ============================================================================

-- Show cast bars during Edit Mode for positioning
local function ShowCastBarsForEditMode()
    if InCombatLockdown() then return end
    
    TweaksUI:PrintDebug("CastBars: ShowCastBarsForEditMode called")
    
    -- Show all enabled cast bars with simulation
    for _, unit in ipairs(CAST_BAR_UNITS) do
        if settings[unit] and settings[unit].enabled then
            if not customCastBars[unit] then
                customCastBars[unit] = CreateCastBar(unit)
            end
            UpdateCastBarLayout(unit)
            ShowSimulation(unit)
            RegisterWithEditMode(unit)
        end
    end
end

-- Hide cast bar simulations after Edit Mode
local function HideCastBarsAfterEditMode()
    if InCombatLockdown() then return end
    
    TweaksUI:PrintDebug("CastBars: HideCastBarsAfterEditMode called")
    
    -- Hide simulations but keep frames if enabled
    for _, unit in ipairs(CAST_BAR_UNITS) do
        if customCastBars[unit] then
            HideSimulation(unit)
        end
    end
end

-- Setup Edit Mode callbacks via centralized EditModeManager
local function SetupEditModeCallbacks()
    if not TweaksUI.EditMode then
        TweaksUI:PrintDebug("CastBars: EditModeManager not available")
        return
    end
    
    TweaksUI:PrintDebug("CastBars: Registering Edit Mode callbacks")
    
    -- Register for Edit Mode enter
    TweaksUI.EditMode:RegisterCallback("enter", function()
        TweaksUI:PrintDebug("CastBars: Edit Mode entered (via EditModeManager)")
        ShowCastBarsForEditMode()
    end)
    
    -- Register for Edit Mode exit
    TweaksUI.EditMode:RegisterCallback("exit", function()
        TweaksUI:PrintDebug("CastBars: Edit Mode exited (via EditModeManager)")
        HideCastBarsAfterEditMode()
    end)
end

-- ============================================================================
-- MODULE LIFECYCLE
-- ============================================================================

function CastBars:OnInitialize()
    TweaksUI:PrintDebug("CastBars:OnInitialize")
    
    -- Get settings from profile database
    settings = TweaksUI.Database:GetModuleSettings(TweaksUI.MODULE_IDS.CAST_BARS)
    
    -- Check if we need to migrate from old TweaksUI_DB.CastBars storage
    if (not settings or not next(settings)) and TweaksUI_DB and TweaksUI_DB.CastBars then
        TweaksUI:PrintDebug("CastBars: Migrating settings from TweaksUI_DB.CastBars to profile")
        settings = DeepCopy(TweaksUI_DB.CastBars)
        TweaksUI.Database:SetModuleSettings(TweaksUI.MODULE_IDS.CAST_BARS, settings)
        -- Clear old storage after migration
        TweaksUI_DB.CastBars = nil
    end
    
    -- Initialize with defaults if still empty
    if not settings or not next(settings) then
        settings = DeepCopy(DEFAULT_SETTINGS)
        TweaksUI.Database:SetModuleSettings(TweaksUI.MODULE_IDS.CAST_BARS, settings)
    end
    
    -- Ensure defaults exist
    EnsureDefaults(settings, DEFAULT_SETTINGS)
    
    -- Setup Edit Mode callbacks via centralized manager
    SetupEditModeCallbacks()
    
    -- Register events
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_DELAYED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
    -- Empowered spell events (Midnight)
    eventFrame:RegisterEvent("UNIT_SPELLCAST_EMPOWER_START")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_EMPOWER_UPDATE")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_EMPOWER_STOP")
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    
    eventFrame:SetScript("OnEvent", OnEvent)
    eventFrame:SetScript("OnUpdate", OnUpdate)
    
    -- Create enabled cast bars
    for _, unit in ipairs(CAST_BAR_UNITS) do
        if settings[unit] and settings[unit].enabled then
            customCastBars[unit] = CreateCastBar(unit)
            UpdateCastBarLayout(unit)
            RegisterWithEditMode(unit)
        end
    end
    
    -- Hide Blizzard cast bars as needed
    HideBlizzardCastBars()
    
    TweaksUI:PrintDebug("CastBars module initialized")
end

function CastBars:OnEnable()
    TweaksUI:PrintDebug("CastBars:OnEnable")
    self:Refresh()
    
    -- Delayed refresh to pick up global media settings after all modules have initialized
    C_Timer.After(0.5, function()
        if TweaksUI.Media and (TweaksUI.Media:IsUsingGlobalTexture() or TweaksUI.Media:IsUsingGlobalFont()) then
            self:Refresh()
        end
    end)
    
    -- Register with EditModeManager to hide during Edit Mode
    if TweaksUI.EditMode then
        TweaksUI.EditMode:RegisterReskinHandler("CastBars",
            function()  -- Hide
                -- Hide our custom cast bars
                for _, unit in ipairs(CAST_BAR_UNITS) do
                    if customCastBars[unit] then
                        customCastBars[unit]:Hide()
                    end
                end
                -- Restore Blizzard cast bars temporarily
                RestoreBlizzardCastBars()
            end,
            function()  -- Show
                -- Restore our customizations
                CastBars:Refresh()
            end
        )
    end
end

function CastBars:OnDisable()
    TweaksUI:PrintDebug("CastBars:OnDisable")
    -- Hide all custom cast bars
    for _, unit in ipairs(CAST_BAR_UNITS) do
        if customCastBars[unit] then
            customCastBars[unit]:Hide()
        end
    end
    -- Restore Blizzard cast bars
    RestoreBlizzardCastBars()
end

-- Handle profile changes
function CastBars:OnProfileChanged(profileName)
    TweaksUI:PrintDebug("CastBars OnProfileChanged:", profileName)
    
    -- Invalidate settings cache
    settings = nil
    
    -- Reload settings from new profile
    settings = TweaksUI.Database:GetModuleSettings(TweaksUI.MODULE_IDS.CAST_BARS)
    
    -- Initialize with defaults if empty
    if not settings or not next(settings) then
        settings = DeepCopy(DEFAULT_SETTINGS)
        TweaksUI.Database:SetModuleSettings(TweaksUI.MODULE_IDS.CAST_BARS, settings)
    else
        -- Ensure defaults are applied
        EnsureDefaults(settings, DEFAULT_SETTINGS)
    end
    
    -- If module is enabled, refresh everything
    if self.enabled then
        self:Refresh()
    end
end

function CastBars:Refresh()
    for _, unit in ipairs(CAST_BAR_UNITS) do
        if settings[unit] and settings[unit].enabled then
            if not customCastBars[unit] then
                customCastBars[unit] = CreateCastBar(unit)
            end
            UpdateCastBarLayout(unit)
            RegisterWithEditMode(unit)
            -- Also register with Layout system if available
            if TweaksUI.Layout and layoutWrappers then
                self:RegisterCastBarWithLayout(unit)
            end
        elseif customCastBars[unit] then
            customCastBars[unit]:Hide()
        end
    end
    HideBlizzardCastBars()
end

-- Alias for consistent API
function CastBars:RefreshAllCastBars()
    self:Refresh()
end

-- ============================================================================
-- LAYOUT INTEGRATION
-- ============================================================================

local function RegisterCastBarWithLayout(unit, frame)
    local Layout = TweaksUI.Layout
    local TUIFrame = TweaksUI.TUIFrame
    
    if not Layout or not TUIFrame then return nil end
    if not frame then return nil end
    
    local unitSettings = settings[unit]
    if not unitSettings then return nil end
    
    -- If wrapper already exists (created during Layout mode), just parent the frame to it
    if layoutWrappers[unit] then
        local wrapper = layoutWrappers[unit]
        frame:SetParent(wrapper.frame)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", wrapper.frame, "TOPLEFT", 0, 0)
        frame:SetPoint("BOTTOMRIGHT", wrapper.frame, "BOTTOMRIGHT", 0, 0)
        return wrapper
    end
    
    local width = unitSettings.width or 250
    local height = unitSettings.height or 24
    
    local displayName = unit:gsub("^%l", string.upper) .. " Cast Bar"
    
    -- Create TUIFrame wrapper
    local wrapper = TUIFrame:New("castbar_" .. unit, {
        width = width,
        height = height,
        name = displayName,
    })
    
    if not wrapper then return nil end
    
    -- Get Layout saved position and apply it properly
    local layoutSettings = Layout:GetSettings()
    local savedPos = layoutSettings and layoutSettings.elements and layoutSettings.elements["castbar_" .. unit]
    
    if savedPos and savedPos.x ~= nil and savedPos.y ~= nil then
        -- Use Layout saved position (handles CENTER coords properly and fades in)
        wrapper:LoadSaveData(savedPos)
    else
        -- Fall back to settings position
        local point = unitSettings.anchor or "CENTER"
        local posX = unitSettings.x or 0
        local posY = unitSettings.y or 0
        wrapper:SetPosition(point, UIParent, point, posX, posY)
    end
    
    -- Parent cast bar frame to wrapper (fill entire wrapper)
    frame:SetParent(wrapper.frame)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", wrapper.frame, "TOPLEFT", 0, 0)
    frame:SetPoint("BOTTOMRIGHT", wrapper.frame, "BOTTOMRIGHT", 0, 0)
    
    -- Register with Layout module
    Layout:RegisterElement("castbar_" .. unit, {
        name = displayName,
        category = Layout.CATEGORIES.CAST_BARS,
        tuiFrame = wrapper,
        defaultPosition = { point = unitSettings.anchor or "CENTER", x = unitSettings.x or 0, y = unitSettings.y or 0 },
        onPositionChanged = function(id, saveData)
            if saveData and settings[unit] then
                settings[unit].x = saveData.x
                settings[unit].y = saveData.y
                settings[unit].anchor = saveData.point or "CENTER"
            end
        end,
        -- NEW: Handle size changes from Layout size matching
        onSizeChanged = function(id, newWidth, newHeight)
            if settings[unit] then
                settings[unit].width = newWidth
                settings[unit].height = newHeight
                
                if TweaksUI.PrintDebug then
                    TweaksUI:PrintDebug(string.format("CastBars: Saved matched size for %s: %.0fx%.0f", 
                        unit, newWidth, newHeight))
                end
            end
        end,
    })
    
    layoutWrappers[unit] = wrapper
    return wrapper
end

local function UpdateCastBarWrapperSize(unit)
    local wrapper = layoutWrappers[unit]
    if not wrapper then return end
    
    local unitSettings = settings[unit]
    if not unitSettings then return end
    
    local width = unitSettings.width or 250
    local height = unitSettings.height or 24
    wrapper:SetSize(width, height)
end

local function RegisterAllCastBarsWithLayout()
    local Layout = TweaksUI.Layout
    local TUIFrame = TweaksUI.TUIFrame
    
    if not Layout or not TUIFrame then
        C_Timer.After(1, RegisterAllCastBarsWithLayout)
        return
    end
    
    -- Register each cast bar that exists (if frame was already created)
    for _, unit in ipairs(CAST_BAR_UNITS) do
        if customCastBars[unit] and settings[unit] then
            RegisterCastBarWithLayout(unit, customCastBars[unit])
        end
    end
    
    -- Register Layout mode callbacks
    Layout:RegisterCallback("OnLayoutModeEnter", function()
        local registered = false
        
        -- Create wrappers for ALL cast bars (not just enabled) so user can position them
        for _, unit in ipairs(CAST_BAR_UNITS) do
            if settings[unit] then
                -- Register with Layout if not already done (creates wrapper from settings)
                if not layoutWrappers[unit] then
                    -- Create wrapper even without the actual frame - use settings for size
                    local unitSettings = settings[unit]
                    local width = unitSettings.width or 250
                    local height = unitSettings.height or 24
                    
                    local displayName = unit:gsub("^%l", string.upper) .. " Cast Bar"
                    
                    -- Check for saved Layout position first
                    local x, y
                    local layoutSettings = Layout:GetSettings()
                    local savedPos = layoutSettings and layoutSettings.elements and layoutSettings.elements["castbar_" .. unit]
                    
                    if savedPos and savedPos.x and savedPos.y then
                        x = savedPos.x
                        y = savedPos.y
                    else
                        -- Convert from settings anchor to BOTTOMLEFT
                        local point = unitSettings.anchor or "CENTER"
                        local sx = unitSettings.x or 0
                        local sy = unitSettings.y or 0
                        
                        if point == "CENTER" then
                            local screenW, screenH = UIParent:GetWidth(), UIParent:GetHeight()
                            x = (screenW / 2) + sx - (width / 2)
                            y = (screenH / 2) + sy - (height / 2)
                        elseif point == "BOTTOMLEFT" then
                            x = sx
                            y = sy
                        else
                            -- For other anchors, use settings as-is (might need adjustment)
                            x = sx
                            y = sy
                        end
                    end
                    
                    local wrapper = TUIFrame:New("castbar_" .. unit, {
                        width = width,
                        height = height,
                        name = displayName,
                    })
                    
                    if wrapper then
                        wrapper.frame:ClearAllPoints()
                        wrapper.frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
                        
                        Layout:RegisterElement("castbar_" .. unit, {
                            name = displayName,
                            category = Layout.CATEGORIES.CAST_BARS,
                            tuiFrame = wrapper,
                            defaultPosition = { point = "BOTTOMLEFT", x = x, y = y },
                            onPositionChanged = function(id, saveData)
                                if saveData and settings[unit] then
                                    settings[unit].x = saveData.x
                                    settings[unit].y = saveData.y
                                    settings[unit].anchor = saveData.point or "BOTTOMLEFT"
                                end
                            end,
                            -- NEW: Handle size changes from Layout size matching
                            onSizeChanged = function(id, newWidth, newHeight)
                                if settings[unit] then
                                    settings[unit].width = newWidth
                                    settings[unit].height = newHeight
                                    
                                    if TweaksUI.PrintDebug then
                                        TweaksUI:PrintDebug(string.format("CastBars: Saved matched size for %s: %.0fx%.0f", 
                                            unit, newWidth, newHeight))
                                    end
                                end
                            end,
                        })
                        
                        layoutWrappers[unit] = wrapper
                        registered = true
                    end
                end
                
                -- Show wrapper in layout mode
                if layoutWrappers[unit] then
                    layoutWrappers[unit].frame:Show()
                end
            end
        end
        
        -- If we registered new elements, force Layout to recreate overlays
        if registered then
            C_Timer.After(0.1, function()
                if Layout.CreateAllOverlays then
                    Layout:CreateAllOverlays()
                end
            end)
        end
    end)
    
    Layout:RegisterCallback("OnLayoutModeExit", function()
        -- Nothing to do - cast bars show/hide based on casting state
    end)
end

-- Expose for external use
function CastBars:GetLayoutWrapper(unit)
    return layoutWrappers[unit]
end

-- Called when a cast bar is enabled or created
function CastBars:RegisterCastBarWithLayout(unit)
    if customCastBars[unit] then
        RegisterCastBarWithLayout(unit, customCastBars[unit])
    end
end

-- Called when cast bar size changes
function CastBars:UpdateCastBarWrapperSize(unit)
    UpdateCastBarWrapperSize(unit)
end

-- Save settings to database
function CastBars:SaveSettings()
    if settings then
        TweaksUI.Database:SetModuleSettings(TweaksUI.MODULE_IDS.CAST_BARS, settings)
    end
end

-- Export module
TweaksUI.CastBars = CastBars

-- Register with Layout after module loads (only if enabled)
C_Timer.After(4, function()
    if TweaksUI.Database and TweaksUI.Database:IsModuleEnabled(TweaksUI.MODULE_IDS.CAST_BARS) then
        RegisterAllCastBarsWithLayout()
    end
end)
