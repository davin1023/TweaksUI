-- ============================================================================
-- TweaksUI: ObjectiveTrackerFrame
-- Allows moving the Objective/Quest Tracker via Layout mode
-- Hooks Blizzard's positioning to prevent automatic repositioning
-- ============================================================================

local ADDON_NAME, TweaksUI = ...

local ObjectiveTrackerFrame_TUI = {}
TweaksUI.ObjectiveTrackerFrame = ObjectiveTrackerFrame_TUI

-- ============================================================================
-- LOCAL REFERENCES
-- ============================================================================

local Layout
local TUIFrame
local layoutWrapper
local containerFrame
local isPositionLocked = false
local savedPosition = nil

-- Default position (Blizzard's default is TOPRIGHT with offset)
local DEFAULT_POSITION = {
    point = "TOPRIGHT",
    x = -60,
    y = -220,
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function GetSettings()
    return TweaksUI.Settings and TweaksUI.Settings:GetModuleSettings("general")
end

local function dprint(...)
    if TweaksUI.debugMode then
        print("|cff00ff00TweaksUI ObjectiveTracker:|r", ...)
    end
end

-- ============================================================================
-- POSITION MANAGEMENT
-- ============================================================================

-- Override Blizzard's positioning
local function LockPosition()
    if not containerFrame then return end
    if isPositionLocked then return end
    
    local tracker = ObjectiveTrackerFrame
    if not tracker then return end
    
    isPositionLocked = true
    
    -- Store original SetPoint if not already stored
    if not tracker._TUI_OriginalSetPoint then
        tracker._TUI_OriginalSetPoint = tracker.SetPoint
    end
    
    -- Hook SetPoint to prevent Blizzard from moving it
    tracker.SetPoint = function(self, ...)
        -- Only allow if we're in layout mode or explicitly setting
        if TweaksUI._allowTrackerSetPoint then
            tracker._TUI_OriginalSetPoint(self, ...)
        else
            dprint("Blocked Blizzard SetPoint call")
        end
    end
    
    -- Also hook ClearAllPoints
    if not tracker._TUI_OriginalClearAllPoints then
        tracker._TUI_OriginalClearAllPoints = tracker.ClearAllPoints
    end
    
    tracker.ClearAllPoints = function(self, ...)
        if TweaksUI._allowTrackerSetPoint then
            tracker._TUI_OriginalClearAllPoints(self, ...)
        else
            dprint("Blocked Blizzard ClearAllPoints call")
        end
    end
    
    dprint("Position locked")
end

-- Apply our saved position
local function ApplyPosition()
    if not containerFrame then return end
    
    local tracker = ObjectiveTrackerFrame
    if not tracker then return end
    
    -- Temporarily allow SetPoint
    TweaksUI._allowTrackerSetPoint = true
    
    -- Position the container (which the tracker is parented to)
    -- The wrapper frame is what Layout moves, container follows
    if layoutWrapper and layoutWrapper.frame then
        -- Container is already parented to wrapper, position is managed by Layout
        dprint("Position managed by Layout wrapper")
    else
        -- Fallback: position container directly
        local pos = savedPosition or DEFAULT_POSITION
        containerFrame:ClearAllPoints()
        containerFrame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
        dprint("Applied fallback position")
    end
    
    TweaksUI._allowTrackerSetPoint = false
end

-- ============================================================================
-- CONTAINER CREATION
-- ============================================================================

function ObjectiveTrackerFrame_TUI:CreateContainer()
    if containerFrame then return containerFrame end
    
    local tracker = ObjectiveTrackerFrame
    if not tracker then
        dprint("ObjectiveTrackerFrame not found")
        return nil
    end
    
    -- Create container frame
    containerFrame = CreateFrame("Frame", "TweaksUI_ObjectiveTrackerContainer", UIParent)
    
    -- Get tracker dimensions
    local width = tracker:GetWidth() or 248
    local height = tracker:GetHeight() or 500
    
    containerFrame:SetSize(width, height)
    containerFrame:SetFrameStrata("MEDIUM")
    containerFrame:SetFrameLevel(1)
    
    -- Get current tracker position for initial placement
    local point, relativeTo, relPoint, x, y = tracker:GetPoint(1)
    if point then
        containerFrame:SetPoint(point, UIParent, relPoint or point, x or -60, y or -220)
    else
        containerFrame:SetPoint(DEFAULT_POSITION.point, UIParent, DEFAULT_POSITION.point, DEFAULT_POSITION.x, DEFAULT_POSITION.y)
    end
    
    -- Reparent the tracker to our container
    TweaksUI._allowTrackerSetPoint = true
    tracker:SetParent(containerFrame)
    tracker:ClearAllPoints()
    tracker:SetPoint("TOPRIGHT", containerFrame, "TOPRIGHT", 0, 0)
    TweaksUI._allowTrackerSetPoint = false
    
    -- Lock position to prevent Blizzard from moving it
    LockPosition()
    
    dprint("Container created")
    
    return containerFrame
end

-- ============================================================================
-- LAYOUT INTEGRATION
-- ============================================================================

function ObjectiveTrackerFrame_TUI:RegisterWithLayout()
    if not containerFrame then
        self:CreateContainer()
    end
    if not containerFrame then return end
    if layoutWrapper then return end  -- Already registered
    
    Layout = TweaksUI.Layout
    TUIFrame = TweaksUI.TUIFrame
    
    if not Layout or not TUIFrame then
        dprint("Layout or TUIFrame not available")
        return
    end
    
    -- Get container dimensions
    local width = containerFrame:GetWidth() or 248
    local height = containerFrame:GetHeight() or 500
    
    -- Get current position
    local point, _, relPoint, x, y = containerFrame:GetPoint(1)
    point = point or "TOPRIGHT"
    x = x or -60
    y = y or -220
    
    -- Check for Layout saved position
    local layoutSettings = Layout:GetSettings()
    local savedPos = layoutSettings and layoutSettings.elements and layoutSettings.elements["objectiveTracker"]
    
    -- Create TUIFrame wrapper
    layoutWrapper = TUIFrame:New("objectiveTracker", {
        width = width,
        height = height,
        name = "Objective Tracker",
    })
    
    if not layoutWrapper then
        dprint("Failed to create TUIFrame wrapper")
        return
    end
    
    -- Position wrapper using Layout saved position or current container position
    if savedPos and savedPos.x ~= nil and savedPos.y ~= nil then
        layoutWrapper:LoadSaveData(savedPos)
        dprint("Loaded saved position")
    else
        layoutWrapper:SetPosition(point, UIParent, point, x, y)
        dprint("Using current position")
    end
    
    -- Parent the container to the wrapper
    containerFrame:SetParent(layoutWrapper.frame)
    containerFrame:ClearAllPoints()
    containerFrame:SetPoint("TOPRIGHT", layoutWrapper.frame, "TOPRIGHT", 0, 0)
    
    -- Register with Layout system
    Layout:RegisterElement("objectiveTracker", {
        name = "Objective Tracker",
        category = "Misc",
        tuiFrame = layoutWrapper,
        defaultPosition = {
            point = DEFAULT_POSITION.point,
            x = DEFAULT_POSITION.x,
            y = DEFAULT_POSITION.y,
        },
        onPositionChanged = function(id, data)
            dprint("Position changed via Layout")
        end,
    })
    
    dprint("Registered with Layout")
end

-- ============================================================================
-- UPDATE SIZE (called when tracker content changes)
-- ============================================================================

function ObjectiveTrackerFrame_TUI:UpdateSize()
    if not containerFrame then return end
    
    local tracker = ObjectiveTrackerFrame
    if not tracker then return end
    
    -- Update container size to match tracker
    local width = tracker:GetWidth() or 248
    local height = tracker:GetHeight() or 500
    
    containerFrame:SetSize(width, height)
    
    -- Update wrapper size if exists
    if layoutWrapper and layoutWrapper.frame then
        layoutWrapper.frame:SetSize(width, height)
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function ObjectiveTrackerFrame_TUI:Initialize()
    -- DISABLED: Objective Tracker positioning is now handled by Blizzard's Edit Mode
    -- This module was causing conflicts with Edit Mode functionality
    -- Simply return without doing anything
    return
end

-- ============================================================================
-- GET WRAPPER (for external access)
-- ============================================================================

function ObjectiveTrackerFrame_TUI:GetWrapper()
    return layoutWrapper
end

function ObjectiveTrackerFrame_TUI:GetContainer()
    return containerFrame
end
