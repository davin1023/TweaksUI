-- ============================================================================
-- TweaksUI: Performance Monitor v1.9.0
-- Tracks FPS, memory, and addon performance metrics
-- Usage: /tuistats to toggle the display
-- ============================================================================

local ADDON_NAME, TweaksUI = ...

-- ============================================================================
-- LOCALIZED GLOBALS
-- ============================================================================

local floor = math.floor
local max = math.max
local min = math.min
local format = string.format
local GetTime = GetTime
local GetFramerate = GetFramerate
local GetNetStats = GetNetStats
local collectgarbage = collectgarbage
local InCombatLockdown = InCombatLockdown
local IsInInstance = IsInInstance
local GetNumGroupMembers = GetNumGroupMembers
local IsInRaid = IsInRaid
local C_Timer = C_Timer
local CreateFrame = CreateFrame

-- ============================================================================
-- PERFORMANCE MONITOR
-- ============================================================================

TweaksUI.Performance = {}
local Performance = TweaksUI.Performance

-- Stats tracking
local stats = {
    fps = {
        current = 0,
        min = 999,
        max = 0,
        samples = {},
        sampleCount = 0,
        maxSamples = 60,  -- 60 second rolling average
    },
    memory = {
        current = 0,
        baseline = 0,
        peak = 0,
    },
    latency = {
        home = 0,
        world = 0,
    },
    combat = {
        inCombat = false,
        combatStart = 0,
        combatDuration = 0,
    },
    updateCounts = {
        nameplateUpdates = 0,
        nameplateSkips = 0,
        castBarUpdates = 0,
        auraUpdates = 0,
    },
}

-- Display frame
local displayFrame = nil
local displayText = nil
local isVisible = false

-- Update interval
local UPDATE_INTERVAL = 1.0  -- Update every second
local updateTicker = nil

-- ============================================================================
-- STATS COLLECTION
-- ============================================================================

local function UpdateStats()
    -- FPS
    local fps = GetFramerate()
    stats.fps.current = fps
    stats.fps.min = min(stats.fps.min, fps)
    stats.fps.max = max(stats.fps.max, fps)
    
    -- Rolling average
    stats.fps.sampleCount = stats.fps.sampleCount + 1
    local idx = ((stats.fps.sampleCount - 1) % stats.fps.maxSamples) + 1
    stats.fps.samples[idx] = fps
    
    -- Memory
    stats.memory.current = collectgarbage("count")
    if stats.memory.baseline == 0 then
        stats.memory.baseline = stats.memory.current
    end
    stats.memory.peak = max(stats.memory.peak, stats.memory.current)
    
    -- Latency
    local _, _, latencyHome, latencyWorld = GetNetStats()
    stats.latency.home = latencyHome
    stats.latency.world = latencyWorld
    
    -- Combat state
    local wasInCombat = stats.combat.inCombat
    stats.combat.inCombat = InCombatLockdown()
    
    if stats.combat.inCombat and not wasInCombat then
        stats.combat.combatStart = GetTime()
    elseif not stats.combat.inCombat and wasInCombat then
        stats.combat.combatDuration = GetTime() - stats.combat.combatStart
    end
end

local function GetAverageFPS()
    local total = 0
    local count = min(stats.fps.sampleCount, stats.fps.maxSamples)
    
    if count == 0 then return 0 end
    
    for i = 1, count do
        total = total + (stats.fps.samples[i] or 0)
    end
    
    return total / count
end

local function GetScenario()
    local inInstance, instanceType = IsInInstance()
    local numMembers = GetNumGroupMembers()
    
    if not inInstance then
        if numMembers > 0 then
            return IsInRaid() and "Raid (Open World)" or "Party (Open World)"
        end
        return "Solo (Open World)"
    end
    
    if instanceType == "raid" then
        return format("Raid (%d)", numMembers)
    elseif instanceType == "party" then
        return format("M+/Dungeon (%d)", numMembers)
    elseif instanceType == "arena" then
        return "Arena"
    elseif instanceType == "pvp" then
        return "Battleground"
    end
    
    return "Instance"
end

-- ============================================================================
-- DISPLAY
-- ============================================================================

local function CreateDisplayFrame()
    if displayFrame then return displayFrame end
    
    displayFrame = CreateFrame("Frame", "TweaksUI_PerformanceFrame", UIParent, "BackdropTemplate")
    displayFrame:SetSize(280, 180)
    displayFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -200)
    displayFrame:SetFrameStrata("HIGH")
    displayFrame:SetMovable(true)
    displayFrame:EnableMouse(true)
    displayFrame:RegisterForDrag("LeftButton")
    displayFrame:SetScript("OnDragStart", displayFrame.StartMoving)
    displayFrame:SetScript("OnDragStop", displayFrame.StopMovingOrSizing)
    displayFrame:SetClampedToScreen(true)
    
    displayFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    displayFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    displayFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    
    -- Title
    local title = displayFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -8)
    title:SetText("|cffffd100TweaksUI|r Performance")
    
    -- Stats text
    displayText = displayFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    displayText:SetPoint("TOPLEFT", 12, -30)
    displayText:SetPoint("BOTTOMRIGHT", -12, 8)
    displayText:SetJustifyH("LEFT")
    displayText:SetJustifyV("TOP")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, displayFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function()
        Performance:Hide()
    end)
    
    displayFrame:Hide()
    return displayFrame
end

local function UpdateDisplay()
    if not displayText then return end
    
    local avgFPS = GetAverageFPS()
    local memDiff = stats.memory.current - stats.memory.baseline
    local memSign = memDiff >= 0 and "+" or ""
    
    -- Color coding for FPS
    local fpsColor = "|cff00ff00"  -- Green
    if stats.fps.current < 30 then
        fpsColor = "|cffff0000"  -- Red
    elseif stats.fps.current < 50 then
        fpsColor = "|cffffff00"  -- Yellow
    end
    
    -- Combat indicator
    local combatStr = stats.combat.inCombat and "|cffff0000[COMBAT]|r" or "|cff00ff00[Safe]|r"
    
    local text = format([[
%s %s

|cffffd100FPS:|r %s%.0f|r (avg: %.0f, min: %.0f, max: %.0f)
|cffffd100Memory:|r %.1f MB (%s%.1f MB)
|cffffd100Peak:|r %.1f MB
|cffffd100Latency:|r %dms home / %dms world

|cffffd100Scenario:|r %s

|cff888888Drag to move, /tuistats to toggle|r
]],
        combatStr,
        GetScenario(),
        fpsColor,
        stats.fps.current,
        avgFPS,
        stats.fps.min,
        stats.fps.max,
        stats.memory.current / 1024,
        memSign,
        memDiff / 1024,
        stats.memory.peak / 1024,
        stats.latency.home,
        stats.latency.world,
        GetScenario()
    )
    
    displayText:SetText(text)
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function Performance:Show()
    CreateDisplayFrame()
    displayFrame:Show()
    isVisible = true
    
    -- Start update ticker if not running
    if not updateTicker then
        updateTicker = C_Timer.NewTicker(UPDATE_INTERVAL, function()
            UpdateStats()
            if isVisible then
                UpdateDisplay()
            end
        end)
    end
    
    TweaksUI:Print("Performance monitor shown. Type /tuistats to hide.")
end

function Performance:Hide()
    if displayFrame then
        displayFrame:Hide()
    end
    isVisible = false
    
    -- Note: We keep the ticker running to continue collecting stats
    -- This allows /tuistats report to show accurate data even when hidden
end

function Performance:Toggle()
    if isVisible then
        self:Hide()
    else
        self:Show()
    end
end

function Performance:GetStats()
    return stats
end

function Performance:ResetStats()
    stats.fps.min = 999
    stats.fps.max = 0
    stats.fps.samples = {}
    stats.fps.sampleCount = 0
    stats.memory.baseline = stats.memory.current
    stats.memory.peak = stats.memory.current
    stats.updateCounts = {
        nameplateUpdates = 0,
        nameplateSkips = 0,
        castBarUpdates = 0,
        auraUpdates = 0,
    }
    TweaksUI:Print("Performance stats reset.")
end

function Performance:PrintReport()
    local avgFPS = GetAverageFPS()
    local memDiff = stats.memory.current - stats.memory.baseline
    
    print("|cffffd100=== TweaksUI Performance Report ===|r")
    print(format("  FPS: %.0f (avg: %.0f, range: %.0f-%.0f)", 
        stats.fps.current, avgFPS, stats.fps.min, stats.fps.max))
    print(format("  Memory: %.1f MB (delta: %+.1f MB, peak: %.1f MB)",
        stats.memory.current / 1024, memDiff / 1024, stats.memory.peak / 1024))
    print(format("  Latency: %dms / %dms", stats.latency.home, stats.latency.world))
    print(format("  Scenario: %s", GetScenario()))
    
    if stats.combat.combatDuration > 0 then
        print(format("  Last combat: %.1f seconds", stats.combat.combatDuration))
    end
end

-- Track update counts for optimization metrics
function Performance:IncrementUpdateCount(updateType)
    if stats.updateCounts[updateType] then
        stats.updateCounts[updateType] = stats.updateCounts[updateType] + 1
    end
end

-- ============================================================================
-- SLASH COMMAND
-- ============================================================================

SLASH_TUISTATS1 = "/tuistats"
SlashCmdList["TUISTATS"] = function(msg)
    local cmd = msg:lower():trim()
    
    if cmd == "report" then
        Performance:PrintReport()
    elseif cmd == "reset" then
        Performance:ResetStats()
    elseif cmd == "hide" then
        Performance:Hide()
    else
        Performance:Toggle()
    end
end

-- Start collecting stats immediately (but don't show display)
C_Timer.After(1, function()
    updateTicker = C_Timer.NewTicker(UPDATE_INTERVAL, function()
        UpdateStats()
        if isVisible then
            UpdateDisplay()
        end
    end)
end)
