-- ============================================================================
-- TweaksUI Action Bar Containers
-- Reparents Blizzard's action bars into our own container frames
-- This breaks the Edit Mode connection and allows free positioning
-- Only active when Safe Mode is enabled
-- ============================================================================

local ADDON_NAME, TweaksUI = ...

-- ============================================================================
-- MODULE SETUP
-- ============================================================================

local ActionBarContainers = {}
TweaksUI.ActionBarContainers = ActionBarContainers

-- State
local initialized = false
local enabled = false
local earlyHideApplied = false

-- Our container frames
local containers = {}  -- [barKey] = containerFrame

-- Original bar data for restoration
local originalBarData = {}  -- [barKey] = { parent, points, strata, level }

-- Bars we hid early (to restore if needed)
local earlyHiddenBars = {}

-- Action bar frame references
local BAR_FRAMES = {
    ActionBar1 = "MainActionBar",
    ActionBar2 = "MultiBarBottomLeft",
    ActionBar3 = "MultiBarBottomRight",
    ActionBar4 = "MultiBarRight",
    ActionBar5 = "MultiBarLeft",
    ActionBar6 = "MultiBar5",
    ActionBar7 = "MultiBar6",
    ActionBar8 = "MultiBar7",
    StanceBar = "StanceBar",
    PetBar = "PetActionBar",
}

-- Bars that should NOT be reparented (managed by UIParentPanelManager)
-- Reparenting these breaks Blizzard's bottom bar layout calculations
local SKIP_REPARENT = {
    StanceBar = true,
    PetBar = true,
    ActionBar1 = true,  -- MainActionBar is also managed by UIParentPanelManager
}

-- Display names for tooltips
local BAR_DISPLAY_NAMES = {
    ActionBar1 = "Main Action Bar",
    ActionBar2 = "Action Bar 2",
    ActionBar3 = "Action Bar 3",
    ActionBar4 = "Action Bar 4 (Right)",
    ActionBar5 = "Action Bar 5 (Left)",
    ActionBar6 = "Action Bar 6",
    ActionBar7 = "Action Bar 7",
    ActionBar8 = "Action Bar 8",
    StanceBar = "Stance Bar",
    PetBar = "Pet Action Bar",
}

-- CVar names that control bar visibility (nil = always visible)
local BAR_VISIBILITY_CVARS = {
    ActionBar1 = nil,  -- Main bar is always visible
    ActionBar2 = "MultiBarBottomLeftVisibility",
    ActionBar3 = "MultiBarBottomRightVisibility",
    ActionBar4 = "MultiBarRightVisibility",
    ActionBar5 = "MultiBarLeftVisibility",
    ActionBar6 = "MultiBar5Visibility",
    ActionBar7 = "MultiBar6Visibility",
    ActionBar8 = "MultiBar7Visibility",
    StanceBar = nil,  -- Stance bar visibility is class-dependent
    PetBar = nil,  -- Pet bar visibility is class-dependent
}

-- Button prefixes for each bar (for disabling mouse on individual buttons)
local BAR_BUTTON_PREFIXES = {
    ActionBar1 = "ActionButton",
    ActionBar2 = "MultiBarBottomLeftButton",
    ActionBar3 = "MultiBarBottomRightButton",
    ActionBar4 = "MultiBarRightButton",
    ActionBar5 = "MultiBarLeftButton",
    ActionBar6 = "MultiBar5Button",
    ActionBar7 = "MultiBar6Button",
    ActionBar8 = "MultiBar7Button",
    StanceBar = "StanceButton",
    PetBar = "PetActionButton",
}

-- ============================================================================
-- SAFE MODE CHECK
-- ============================================================================

local function IsSafeMode()
    if TweaksUI.EditMode and TweaksUI.EditMode.IsSafeMode then
        return TweaksUI.EditMode:IsSafeMode()
    end
    if TweaksUI.Database and TweaksUI.Database.db and TweaksUI.Database.db.global then
        return TweaksUI.Database.db.global.editModeSafeMode or false
    end
    return false
end

-- ============================================================================
-- BAR ENABLED CHECK (for alpha/clickable state)
-- ============================================================================

local function IsBarEnabledByCVar(barKey)
    local cvar = BAR_VISIBILITY_CVARS[barKey]
    
    -- No CVar means always enabled
    if not cvar then
        return true
    end
    
    -- Check the CVar - value > 0 means enabled
    local value = C_CVar.GetCVar(cvar)
    if value then
        local numValue = tonumber(value)
        return numValue and numValue > 0
    end
    
    return false
end

-- ============================================================================
-- EARLY HIDE DISABLED BARS (runs immediately to prevent blink)
-- ============================================================================

local function EarlyHideDisabledBars()
    if earlyHideApplied then return end
    
    -- Only do this if Safe Mode is enabled
    if not IsSafeMode() then return end
    
    for barKey, frameName in pairs(BAR_FRAMES) do
        local bar = _G[frameName]
        if bar and not IsBarEnabledByCVar(barKey) then
            -- Hide the bar immediately
            bar:SetAlpha(0)
            earlyHiddenBars[barKey] = true
        end
    end
    
    earlyHideApplied = true
end

-- Run early hide as soon as possible (only if module is enabled)
-- DISABLED: Safe Mode feature was removed in 1.4.0
--[[
local earlyHideFrame = CreateFrame("Frame")
earlyHideFrame:RegisterEvent("PLAYER_LOGIN")
earlyHideFrame:SetScript("OnEvent", function(self, event)
    -- Only run if ActionBars module is enabled
    if TweaksUI.Database and TweaksUI.Database:IsModuleEnabled(TweaksUI.MODULE_IDS.ACTION_BARS) then
        -- Small delay to let CVars be readable
        C_Timer.After(0.1, EarlyHideDisabledBars)
    end
    self:UnregisterAllEvents()
end)
--]]

-- ============================================================================
-- CONTAINER FRAME CREATION
-- ============================================================================

local function CreateContainer(barKey)
    if containers[barKey] then return containers[barKey] end
    
    local displayName = BAR_DISPLAY_NAMES[barKey] or barKey
    
    local container = CreateFrame("Frame", "TweaksUI_ABContainer_" .. barKey, UIParent)
    container:SetSize(500, 50)  -- Will match bar size
    container:SetFrameStrata("LOW")
    container:SetFrameLevel(1)
    container:SetClampedToScreen(true)
    container:SetMovable(true)
    container:EnableMouse(false)  -- Don't block mouse - use OnUpdate for drag
    container:RegisterForDrag("LeftButton")
    
    -- START HIDDEN: Prevent visible position jumps during initialization
    -- Will be revealed by TUIFrame.RevealAllFrames after all positioning is complete
    container:SetAlpha(0)
    if TweaksUI.TUIFrame and TweaksUI.TUIFrame.RegisterPendingFrame then
        TweaksUI.TUIFrame.RegisterPendingFrame(container)
    end
    
    -- Default position - will be overwritten by bar's actual position
    container:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    
    container.barKey = barKey
    container.displayName = displayName
    containers[barKey] = container
    
    TweaksUI:PrintDebug("ActionBarContainers: Created container for " .. barKey)
    return container
end

-- ============================================================================
-- POSITION SAVE/RESTORE
-- ============================================================================

function ActionBarContainers:SavePosition(barKey)
    local container = containers[barKey]
    if not container then return end
    
    local point, _, relPoint, x, y = container:GetPoint(1)
    
    -- Store in TweaksUI_CharDB (per-character) for profile system integration
    if TweaksUI_CharDB then
        TweaksUI_CharDB.actionBarContainerPositions = TweaksUI_CharDB.actionBarContainerPositions or {}
        TweaksUI_CharDB.actionBarContainerPositions[barKey] = {
            point = point,
            relPoint = relPoint,
            x = x,
            y = y
        }
    end
    
    TweaksUI:PrintDebug("ActionBarContainers: Saved position for " .. barKey)
end

-- Save all container positions (called before export)
function ActionBarContainers:SaveAllPositions()
    for barKey, container in pairs(containers) do
        if container and container:IsShown() then
            self:SavePosition(barKey)
        end
    end
end

function ActionBarContainers:RestorePosition(barKey)
    local container = containers[barKey]
    if not container then return end
    
    local pos = nil
    
    -- Check TweaksUI_CharDB first (new location, per-character)
    if TweaksUI_CharDB and TweaksUI_CharDB.actionBarContainerPositions then
        pos = TweaksUI_CharDB.actionBarContainerPositions[barKey]
    end
    
    -- Migrate from old TweaksUI_DB location if needed
    if not pos and TweaksUI_DB and TweaksUI_DB.actionBarContainerPositions then
        pos = TweaksUI_DB.actionBarContainerPositions[barKey]
        if pos then
            -- Migrate to new location
            TweaksUI_CharDB = TweaksUI_CharDB or {}
            TweaksUI_CharDB.actionBarContainerPositions = TweaksUI_CharDB.actionBarContainerPositions or {}
            TweaksUI_CharDB.actionBarContainerPositions[barKey] = pos
            TweaksUI:PrintDebug("ActionBarContainers: Migrated position for " .. barKey .. " to per-character storage")
        end
    end
    
    if pos and pos.point then
        container:ClearAllPoints()
        container:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
        TweaksUI:PrintDebug("ActionBarContainers: Restored position for " .. barKey)
        return true
    end
    return false
end

-- ============================================================================
-- REPARENT BAR TO CONTAINER
-- ============================================================================

local function ReparentBarToContainer(barKey)
    local container = containers[barKey]
    if not container then return false end
    
    local frameName = BAR_FRAMES[barKey]
    local bar = frameName and _G[frameName]
    if not bar then 
        TweaksUI:PrintDebug("ActionBarContainers: Bar not found - " .. (frameName or "nil"))
        return false 
    end
    
    -- Store original data for restoration (only once)
    if not originalBarData[barKey] then
        originalBarData[barKey] = {
            parent = bar:GetParent(),
            points = {},
            strata = bar:GetFrameStrata(),
            level = bar:GetFrameLevel(),
            originalSetPoint = bar.SetPoint,
            originalClearAllPoints = bar.ClearAllPoints,
            wasShown = bar:IsShown(),  -- Store original visibility
        }
        for i = 1, bar:GetNumPoints() do
            local point, relativeTo, relativePoint, xOfs, yOfs = bar:GetPoint(i)
            table.insert(originalBarData[barKey].points, {
                point = point,
                relativeTo = relativeTo,
                relativePoint = relativePoint,
                x = xOfs,
                y = yOfs
            })
        end
        TweaksUI:PrintDebug("ActionBarContainers: Stored original data for " .. barKey .. " (visible: " .. tostring(originalBarData[barKey].wasShown) .. ")")
    end
    
    -- If no saved position, use bar's current position for container
    if not ActionBarContainers:RestorePosition(barKey) then
        local point, _, relPoint, x, y = bar:GetPoint(1)
        if point then
            container:ClearAllPoints()
            container:SetPoint(point, UIParent, relPoint or point, x or 0, y or 0)
        end
    end
    
    -- Reparent bar to our container
    bar:SetParent(container)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    
    -- Override SetPoint and ClearAllPoints to prevent Edit Mode changes
    bar._TUI_Container = container
    bar._TUI_Controlled = true
    
    local origSetPoint = originalBarData[barKey].originalSetPoint
    bar.SetPoint = function(self, ...)
        if self._TUI_Controlled then
            return  -- Ignore Edit Mode repositioning
        end
        return origSetPoint(self, ...)
    end
    
    local origClearAllPoints = originalBarData[barKey].originalClearAllPoints
    bar.ClearAllPoints = function(self, ...)
        if self._TUI_Controlled then
            return
        end
        return origClearAllPoints(self, ...)
    end
    
    -- Set up OnUpdate-based drag detection (doesn't block mouse)
    -- Parent to UIParent so it always runs even if container is hidden
    if not container._TUI_DragCheckHooked then
        local dragCheckFrame = CreateFrame("Frame", nil, UIParent)
        dragCheckFrame.container = container
        dragCheckFrame.barKey = barKey
        dragCheckFrame:SetScript("OnUpdate", function(self, elapsed)
            local cont = self.container
            if not cont or not cont:IsShown() then return end
            
            if IsShiftKeyDown() and IsControlKeyDown() and IsMouseButtonDown("LeftButton") then
                if not cont.isMoving and MouseIsOver(cont) then
                    cont:StartMoving()
                    cont.isMoving = true
                end
            elseif cont.isMoving and not IsMouseButtonDown("LeftButton") then
                cont:StopMovingOrSizing()
                cont.isMoving = false
                ActionBarContainers:SavePosition(self.barKey)
            end
        end)
        container._TUI_DragCheckHooked = true
        container._TUI_DragCheckFrame = dragCheckFrame
    end
    
    -- Match container size to bar
    C_Timer.After(0.2, function()
        local width, height = bar:GetSize()
        if width and height and width > 0 and height > 0 then
            container:SetSize(width, height)
        end
    end)
    
    -- Always show container - the bar inside controls its own visibility
    container:Show()
    
    TweaksUI:PrintDebug(string.format("ActionBarContainers: Reparented %s to container", frameName))
    return true
end

-- ============================================================================
-- RESTORE BAR TO ORIGINAL PARENT
-- ============================================================================

local function RestoreBarToOriginal(barKey)
    local frameName = BAR_FRAMES[barKey]
    local bar = frameName and _G[frameName]
    if not bar then return end
    
    local data = originalBarData[barKey]
    if not data then return end
    
    -- Clear control flag
    bar._TUI_Controlled = false
    
    -- Restore original methods
    if data.originalSetPoint then
        bar.SetPoint = data.originalSetPoint
    end
    if data.originalClearAllPoints then
        bar.ClearAllPoints = data.originalClearAllPoints
    end
    
    -- Restore parent
    bar:SetParent(data.parent)
    
    -- Restore frame strata and level
    if data.strata then
        pcall(function() bar:SetFrameStrata(data.strata) end)
    end
    if data.level then
        pcall(function() bar:SetFrameLevel(data.level) end)
    end
    
    -- Restore position
    bar:ClearAllPoints()
    for _, pointData in ipairs(data.points) do
        bar:SetPoint(pointData.point, pointData.relativeTo, pointData.relativePoint, pointData.x, pointData.y)
    end
    
    TweaksUI:PrintDebug("ActionBarContainers: Restored " .. frameName .. " to original parent")
end

-- ============================================================================
-- ENABLE / DISABLE
-- ============================================================================

function ActionBarContainers:Enable()
    if enabled then return end
    
    TweaksUI:PrintDebug("ActionBarContainers: Enabling (Safe Mode)")
    
    -- Create containers and reparent bars (except system bars)
    for barKey, frameName in pairs(BAR_FRAMES) do
        -- Skip bars that are managed by UIParentPanelManager
        if SKIP_REPARENT[barKey] then
            TweaksUI:PrintDebug("ActionBarContainers: Skipping " .. barKey .. " (managed by UIParentPanelManager)")
        elseif _G[frameName] then
            CreateContainer(barKey)
            ReparentBarToContainer(barKey)
            
            local container = containers[barKey]
            if container then
                container:SetAlpha(1)
                container:EnableMouse(false)  -- Let clicks pass through to bar
                container:Show()
            end
            
            TweaksUI:PrintDebug("ActionBarContainers: Processed " .. barKey)
        end
    end
    
    enabled = true
end

function ActionBarContainers:Disable()
    if not enabled then return end
    
    TweaksUI:PrintDebug("ActionBarContainers: Disabling")
    
    -- Restore bars to original parents
    for barKey, container in pairs(containers) do
        RestoreBarToOriginal(barKey)
        container:Hide()
    end
    
    enabled = false
end

function ActionBarContainers:IsEnabled()
    return enabled
end

function ActionBarContainers:Toggle()
    if enabled then
        self:Disable()
    else
        self:Enable()
    end
end

function ActionBarContainers:Initialize()
    if initialized then return end
    initialized = true
    
    -- Check if safe mode is enabled and auto-enable
    if IsSafeMode() then
        TweaksUI:PrintDebug("ActionBarContainers: Safe Mode detected, enabling containers")
        C_Timer.After(2, function()
            self:Enable()
        end)
    end
    
    TweaksUI:PrintDebug("ActionBarContainers: Initialized")
end

function ActionBarContainers:GetContainer(barKey)
    return containers[barKey]
end

-- ============================================================================
-- SLASH COMMAND (for manual testing/override)
-- ============================================================================

SLASH_TUIACTIONBARS1 = "/tuiab"
SlashCmdList["TUIACTIONBARS"] = function(msg)
    if not initialized then
        ActionBarContainers:Initialize()
    end
    
    if msg == "on" then
        ActionBarContainers:Enable()
        TweaksUI:Print("Action Bar Containers |cff00ff00enabled|r - Shift+Ctrl+Drag to move")
    elseif msg == "off" then
        ActionBarContainers:Disable()
        TweaksUI:Print("Action Bar Containers |cffff0000disabled|r")
    else
        ActionBarContainers:Toggle()
        if enabled then
            TweaksUI:Print("Action Bar Containers |cff00ff00enabled|r - Shift+Ctrl+Drag to move")
        else
            TweaksUI:Print("Action Bar Containers |cffff0000disabled|r")
        end
    end
end

-- ============================================================================
-- AUTO-INITIALIZE
-- ============================================================================

-- ActionBarContainers is disabled - Safe Mode feature was removed in 1.4.0
-- The container reparenting conflicts with Blizzard's UIParentPanelManager
-- and causes crashes when bars like StanceBar are reparented.
-- This code is kept for potential future use but won't run automatically.

--[[
C_Timer.After(3, function()
    -- Only initialize if ActionBars module is enabled
    if TweaksUI.Database and TweaksUI.Database:IsModuleEnabled(TweaksUI.MODULE_IDS.ACTION_BARS) then
        ActionBarContainers:Initialize()
    end
end)
--]]

return ActionBarContainers
