-- ============================================================================
-- TweaksUI UI Frame Containers
-- Reparents various Blizzard UI elements into movable containers
-- This breaks the Edit Mode connection and allows free positioning
-- Only active when Safe Mode is enabled
-- ============================================================================

local ADDON_NAME, TweaksUI = ...

-- ============================================================================
-- MODULE SETUP
-- ============================================================================

local UIFrameContainers = {}
TweaksUI.UIFrameContainers = UIFrameContainers

-- State
local initialized = false
local enabled = false

-- Our container frames
local containers = {}  -- [frameKey] = containerFrame

-- Original frame data for restoration
local originalFrameData = {}  -- [frameKey] = { parent, points, strata, level }

-- UI frame references (only Blizzard frames NOT managed by TweaksUI modules)
local UI_FRAMES = {
    -- NOTE: ObjectiveTracker is now handled by ObjectiveTrackerFrame.lua with proper Blizzard hook handling
    
    -- Bags (only in Midnight+, retail BagsBar has issues)
    BagBar = TweaksUI.IS_MIDNIGHT and "BagsBar" or nil,
    
    -- Micro Menu
    MicroMenu = "MicroMenu",
    
    -- Buffs/Debuffs
    BuffFrame = "BuffFrame",
    DebuffFrame = "DebuffFrame",
    
    -- Experience/Rep Bar
    StatusTrackingBar = "StatusTrackingBarManager",
    
    -- Talking Head
    TalkingHead = "TalkingHeadFrame",
    
    -- Durability
    Durability = "DurabilityFrame",
    
    -- Vehicle Seat
    VehicleSeat = "VehicleSeatIndicator",
    
    -- Zone Text
    ZoneText = "ZoneTextFrame",
    
    -- Totem Bar (Shaman)
    TotemBar = "TotemFrame",
    
    -- Game Menu Button / Quick Join
    QuickJoin = "QuickJoinToastButton",
    
    -- Queue Status
    QueueStatus = "QueueStatusButton",
    
    -- NOTE: These are managed by TweaksUI modules and should NOT be here:
    -- ChatFrame - managed by TweaksUI.Chat
    -- PlayerFrame, TargetFrame, FocusFrame, PartyFrame - managed by TweaksUI.UnitFrames
    -- CastBars - managed by TweaksUI.CastBars
    -- ActionBars, StanceBar, PetBar - managed by ActionBarContainers
    -- Cooldown Trackers - managed by CooldownClones
    -- Minimap - managed by TweaksUI.General (MinimapFrame)
    -- BossFrame - managed by TweaksUI.UnitFrames
}

-- Display names for debugging/tooltips
local UI_FRAME_NAMES = {
    -- ObjectiveTracker removed
    BagBar = "Bag Bar",
    MicroMenu = "Micro Menu",
    BuffFrame = "Buff Frame",
    DebuffFrame = "Debuff Frame",
    StatusTrackingBar = "XP/Rep Bar",
    TalkingHead = "Talking Head",
    Durability = "Durability",
    VehicleSeat = "Vehicle Seat",
    ZoneText = "Zone Text",
    TotemBar = "Totem Bar",
    QuickJoin = "Quick Join",
    QueueStatus = "Queue Status",
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
-- CONTAINER FRAME CREATION
-- ============================================================================

local function CreateContainer(frameKey)
    if containers[frameKey] then return containers[frameKey] end
    
    local displayName = UI_FRAME_NAMES[frameKey] or frameKey
    
    local container = CreateFrame("Frame", "TweaksUI_UIContainer_" .. frameKey, UIParent)
    container:SetSize(200, 200)  -- Will match frame size
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
    
    -- Default position
    container:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    
    container.frameKey = frameKey
    container.displayName = displayName
    containers[frameKey] = container
    
    TweaksUI:PrintDebug("UIFrameContainers: Created container for " .. frameKey)
    return container
end

-- ============================================================================
-- POSITION SAVE/RESTORE
-- ============================================================================

function UIFrameContainers:SavePosition(frameKey)
    local container = containers[frameKey]
    if not container then return end
    
    local point, _, relPoint, x, y = container:GetPoint(1)
    
    -- Store in TweaksUI_CharDB (per-character) for profile system integration
    if TweaksUI_CharDB then
        TweaksUI_CharDB.uiFrameContainerPositions = TweaksUI_CharDB.uiFrameContainerPositions or {}
        TweaksUI_CharDB.uiFrameContainerPositions[frameKey] = {
            point = point,
            relPoint = relPoint,
            x = x,
            y = y
        }
    end
    
    TweaksUI:PrintDebug("UIFrameContainers: Saved position for " .. frameKey)
end

-- Save all container positions (called before export)
function UIFrameContainers:SaveAllPositions()
    for frameKey, container in pairs(containers) do
        if container and container:IsShown() then
            self:SavePosition(frameKey)
        end
    end
end

function UIFrameContainers:RestorePosition(frameKey)
    local container = containers[frameKey]
    if not container then return end
    
    local pos = nil
    
    -- Check TweaksUI_CharDB first (new location, per-character)
    if TweaksUI_CharDB and TweaksUI_CharDB.uiFrameContainerPositions then
        pos = TweaksUI_CharDB.uiFrameContainerPositions[frameKey]
    end
    
    -- Migrate from old TweaksUI_DB location if needed
    if not pos and TweaksUI_DB and TweaksUI_DB.uiFrameContainerPositions then
        pos = TweaksUI_DB.uiFrameContainerPositions[frameKey]
        if pos then
            -- Migrate to new location
            TweaksUI_CharDB = TweaksUI_CharDB or {}
            TweaksUI_CharDB.uiFrameContainerPositions = TweaksUI_CharDB.uiFrameContainerPositions or {}
            TweaksUI_CharDB.uiFrameContainerPositions[frameKey] = pos
            TweaksUI:PrintDebug("UIFrameContainers: Migrated position for " .. frameKey .. " to per-character storage")
        end
    end
    
    if pos and pos.point then
        container:ClearAllPoints()
        container:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
        TweaksUI:PrintDebug("UIFrameContainers: Restored position for " .. frameKey)
        return true
    end
    return false
end

-- ============================================================================
-- REPARENT FRAME TO CONTAINER
-- ============================================================================

local function ReparentFrameToContainer(frameKey)
    local container = containers[frameKey]
    if not container then return false end
    
    local frameName = UI_FRAMES[frameKey]
    local frame = frameName and _G[frameName]
    if not frame then 
        TweaksUI:PrintDebug("UIFrameContainers: Frame not found - " .. (frameName or "nil"))
        return false 
    end
    
    -- Store original data for restoration (only once)
    if not originalFrameData[frameKey] then
        originalFrameData[frameKey] = {
            parent = frame:GetParent(),
            points = {},
            strata = frame:GetFrameStrata(),
            level = frame:GetFrameLevel(),
            originalSetPoint = frame.SetPoint,
            originalClearAllPoints = frame.ClearAllPoints,
        }
        for i = 1, frame:GetNumPoints() do
            local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint(i)
            table.insert(originalFrameData[frameKey].points, {
                point = point,
                relativeTo = relativeTo,
                relativePoint = relativePoint,
                x = xOfs,
                y = yOfs
            })
        end
        TweaksUI:PrintDebug("UIFrameContainers: Stored original data for " .. frameKey)
    end
    
    -- If no saved position, use frame's current position for container
    if not UIFrameContainers:RestorePosition(frameKey) then
        local point, _, relPoint, x, y = frame:GetPoint(1)
        if point then
            container:ClearAllPoints()
            container:SetPoint(point, UIParent, relPoint or point, x or 0, y or 0)
        end
    end
    
    -- Reparent frame to our container
    frame:SetParent(container)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    
    -- Override SetPoint and ClearAllPoints to prevent Edit Mode changes
    frame._TUI_Container = container
    frame._TUI_Controlled = true
    
    local origSetPoint = originalFrameData[frameKey].originalSetPoint
    frame.SetPoint = function(self, ...)
        if self._TUI_Controlled then
            return  -- Ignore Edit Mode repositioning
        end
        return origSetPoint(self, ...)
    end
    
    local origClearAllPoints = originalFrameData[frameKey].originalClearAllPoints
    frame.ClearAllPoints = function(self, ...)
        if self._TUI_Controlled then
            return
        end
        return origClearAllPoints(self, ...)
    end
    
    -- Set up OnUpdate-based drag detection (parent to UIParent so always runs)
    if not container._TUI_DragCheckHooked then
        local dragCheckFrame = CreateFrame("Frame", nil, UIParent)
        dragCheckFrame.container = container
        dragCheckFrame.frameKey = frameKey
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
                UIFrameContainers:SavePosition(self.frameKey)
            end
        end)
        container._TUI_DragCheckHooked = true
        container._TUI_DragCheckFrame = dragCheckFrame
    end
    
    -- Match container size to frame
    C_Timer.After(0.2, function()
        local width, height = frame:GetSize()
        if width and height and width > 0 and height > 0 then
            container:SetSize(width, height)
        end
    end)
    
    container:SetAlpha(1)
    container:Show()
    
    TweaksUI:PrintDebug(string.format("UIFrameContainers: Reparented %s to container", frameName))
    return true
end

-- ============================================================================
-- RESTORE FRAME TO ORIGINAL PARENT
-- ============================================================================

local function RestoreFrameToOriginal(frameKey)
    local frameName = UI_FRAMES[frameKey]
    local frame = frameName and _G[frameName]
    if not frame then return end
    
    local data = originalFrameData[frameKey]
    if not data then return end
    
    -- Clear control flag
    frame._TUI_Controlled = false
    
    -- Restore original methods
    if data.originalSetPoint then
        frame.SetPoint = data.originalSetPoint
    end
    if data.originalClearAllPoints then
        frame.ClearAllPoints = data.originalClearAllPoints
    end
    
    -- Restore parent
    frame:SetParent(data.parent)
    
    -- Restore frame strata and level
    if data.strata then
        pcall(function() frame:SetFrameStrata(data.strata) end)
    end
    if data.level then
        pcall(function() frame:SetFrameLevel(data.level) end)
    end
    
    -- Restore position
    frame:ClearAllPoints()
    for _, pointData in ipairs(data.points) do
        frame:SetPoint(pointData.point, pointData.relativeTo, pointData.relativePoint, pointData.x, pointData.y)
    end
    
    TweaksUI:PrintDebug("UIFrameContainers: Restored " .. frameName .. " to original parent")
end

-- ============================================================================
-- ENABLE / DISABLE
-- ============================================================================

function UIFrameContainers:Enable()
    if enabled then return end
    
    TweaksUI:PrintDebug("UIFrameContainers: Enabling (Safe Mode)")
    
    -- Create containers and reparent frames
    for frameKey, frameName in pairs(UI_FRAMES) do
        if _G[frameName] then
            CreateContainer(frameKey)
            ReparentFrameToContainer(frameKey)
        else
            TweaksUI:PrintDebug("UIFrameContainers: Skipping " .. frameKey .. " (frame not found)")
        end
    end
    
    enabled = true
end

function UIFrameContainers:Disable()
    if not enabled then return end
    
    TweaksUI:PrintDebug("UIFrameContainers: Disabling")
    
    -- Restore frames to original parents
    for frameKey, container in pairs(containers) do
        RestoreFrameToOriginal(frameKey)
        container:Hide()
    end
    
    enabled = false
end

function UIFrameContainers:IsEnabled()
    return enabled
end

function UIFrameContainers:Toggle()
    if enabled then
        self:Disable()
    else
        self:Enable()
    end
end

function UIFrameContainers:Initialize()
    if initialized then return end
    initialized = true
    
    -- Check if safe mode is enabled and auto-enable
    if IsSafeMode() then
        TweaksUI:PrintDebug("UIFrameContainers: Safe Mode detected, enabling containers")
        C_Timer.After(2.5, function()
            self:Enable()
        end)
    end
    
    TweaksUI:PrintDebug("UIFrameContainers: Initialized")
end

function UIFrameContainers:GetContainer(frameKey)
    return containers[frameKey]
end

-- ============================================================================
-- SLASH COMMAND
-- ============================================================================

SLASH_TUIUIFRAMES1 = "/tuiui"
SlashCmdList["TUIUIFRAMES"] = function(msg)
    if not initialized then
        UIFrameContainers:Initialize()
    end
    
    if msg == "on" then
        UIFrameContainers:Enable()
        TweaksUI:Print("UI Frame Containers |cff00ff00enabled|r - Shift+Ctrl+Drag to move")
    elseif msg == "off" then
        UIFrameContainers:Disable()
        TweaksUI:Print("UI Frame Containers |cffff0000disabled|r")
    elseif msg == "list" then
        TweaksUI:Print("UI Frame Containers - Available frames:")
        for frameKey, frameName in pairs(UI_FRAMES) do
            local exists = _G[frameName] and "exists" or "not found"
            TweaksUI:Print("  " .. frameKey .. " (" .. frameName .. ") - " .. exists)
        end
    else
        UIFrameContainers:Toggle()
        if enabled then
            TweaksUI:Print("UI Frame Containers |cff00ff00enabled|r - Shift+Ctrl+Drag to move")
        else
            TweaksUI:Print("UI Frame Containers |cffff0000disabled|r")
        end
    end
end

-- ============================================================================
-- AUTO-INITIALIZE
-- ============================================================================

C_Timer.After(3.5, function()
    UIFrameContainers:Initialize()
end)

return UIFrameContainers
