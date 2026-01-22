-- TweaksUI General Module
-- Provides UI visibility toggles and AFK Mode functionality
-- This is NOT a standard enable/disable module - it's always active

local ADDON_NAME, TweaksUI = ...

local General = {}
TweaksUI.General = General

-- ============================================================================
-- UTILITIES
-- ============================================================================

-- Deep copy utility
local function DeepCopy(orig)
    local copy
    if type(orig) == 'table' then
        copy = {}
        for k, v in pairs(orig) do
            copy[DeepCopy(k)] = DeepCopy(v)
        end
        setmetatable(copy, DeepCopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local HUB_WIDTH = 180
local HUB_HEIGHT = 215
local PANEL_WIDTH = 420
local PANEL_HEIGHT = 600
local BUTTON_HEIGHT = 28
local BUTTON_SPACING = 6
local TAB_HEIGHT = 26
local CHECKBOX_SPACING = 28

local darkBackdrop = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
}

-- ============================================================================
-- FRAME VISIBILITY CONFIGURATION
-- ============================================================================

-- Frame definitions with categories
local VISIBILITY_FRAMES = {
    -- Combat category
    buffs = {
        frames = {"BuffFrame"},
        label = "Buffs",
        category = "combat",
        description = "Player buff icons",
    },
    debuffs = {
        frames = {"DebuffFrame"},
        label = "Debuffs",
        category = "combat",
        description = "Player debuff icons",
    },
    -- extraAction removed - causes issues with hiding/centering
    -- questTracker removed - Blizzard's frame reacts to UI events and moves unexpectedly
    -- Information category
    zoneText = {
        frames = {"ZoneTextFrame", "SubZoneTextFrame"},
        label = "Zone Text",
        category = "information",
        description = "Zone name display on area change",
    },
    -- Navigation category
    minimap = {
        frames = {"MinimapCluster"},
        label = "Minimap",
        category = "navigation",
        description = "Minimap and surrounding elements",
    },
    -- Note: Bags Bar, Menu Bar, Stance Bar, Pet Bar moved to Action Bars module
    -- Indicators category
    durability = {
        frames = {"DurabilityFrame"},
        label = "Durability",
        category = "indicators",
        description = "Armor damage indicator",
    },
    vehicleSeat = {
        frames = {"VehicleSeatIndicator"},
        label = "Vehicle Seat",
        category = "indicators",
        description = "Vehicle seat switcher",
    },
    orderHall = {
        frames = {"OrderHallCommandBar"},
        label = "Order Hall",
        category = "indicators",
        description = "Legion class hall command bar",
    },
    statusBars = {
        frames = {"StatusTrackingBarManager"},
        label = "XP/Rep Bars",
        category = "indicators",
        description = "Experience, reputation, and honor bars",
    },
    -- Popups category
    alerts = {
        frames = {"AlertFrame"},
        label = "Alerts",
        category = "popups",
        description = "Achievement and loot alert popups",
    },
    -- talkingHead removed - causes click-blocking issues
    tutorials = {
        frames = {"TutorialFrame", "HelpPlate", "HelpPlateTooltip"},
        label = "Tutorials",
        category = "popups",
        description = "Tutorial hints and highlights",
    },
}

-- Category display order
local CATEGORIES = {
    { key = "combat", label = "Combat" },
    { key = "information", label = "Information" },
    { key = "navigation", label = "Navigation" },
    { key = "indicators", label = "Indicators" },
    { key = "popups", label = "Popups" },
}

-- Default visibility settings for each frame
local function GetDefaultVisibilitySettings()
    return {
        hide = false,                -- Master hide toggle
        visibilityEnabled = false,   -- Use visibility conditions
        inCombat = true,
        outOfCombat = true,
        hasTarget = true,
        noTarget = true,
        solo = true,
        inParty = true,
        inRaid = true,
        inInstance = true,
        onMouseover = false,         -- Show on mouseover (always interactable)
        -- Fade settings
        fadeEnabled = false,
        fadeDelay = 3,
        fadeAlpha = 0.5,
    }
end

-- ============================================================================
-- DEFAULT SETTINGS
-- ============================================================================

local DEFAULTS = {
    -- General Settings (QoL)
    autoRepair = false,
    autoRepairGuild = false,  -- Use guild funds first when available
    autoSellJunk = false,
    hideMinimapButton = false,
    
    -- Character Panel Enhancements
    characterPanelEnabled = false,
    
    -- Hide Blizzard Buff/Debuff Frames
    hideBlizzardBuffs = false,
    hideBlizzardDebuffs = false,
    
    -- Global Media Settings
    mediaSettings = {
        globalFont = "Friz Quadrata TT",  -- Default font for all modules
        useGlobalFont = false,  -- Whether to override module-specific fonts
        globalFontOutline = "OUTLINE",  -- Default outline: "", "OUTLINE", "THICKOUTLINE"
        globalTexture = "Blizzard",  -- Default texture for all modules
        useGlobalTexture = false,  -- Whether to override module-specific textures
        globalIconEdgeStyle = "sharp",  -- Default icon edge style: "sharp", "rounded", "square"
        useGlobalIconEdgeStyle = false,  -- Whether to override module-specific icon edge styles
    },
    
    -- Visibility settings per frame (populated dynamically)
    visibility = {},
    
    -- AFK Mode
    afkModeEnabled = false,
    afkFadeAnimation = true,
    afkFadeDuration = 0.5,
    afkKeepMinimap = false,
    afkKeepChat = false,
    afkCameraSpin = false,
    afkCameraSpinSpeed = 0.05,
    afkHideNameplates = true,
    
    -- Minimap Customization
    minimapSettings = {
        useCustomFrame = false,  -- NEW: Use TweaksUI's custom minimap container
        squareShape = false,
        scale = 1.0,
        showCoords = false,      -- NEW: Show coordinates
        showZoneText = true,     -- NEW: Show zone text
        customPosition = nil,    -- NEW: Saved position { point, x, y }
        -- Custom border for square minimap
        customBorder = {
            color = { r = 0.4, g = 0.4, b = 0.4 },  -- Grey default
            width = 2,
        },
        -- Button collector
        buttonCollector = {
            enabled = false,
            drawerPosition = "left",  -- "left", "right", "top", "bottom"
        },
        hide = {
            zoomButtons = false,
            border = false,
            calendar = false,
            tracking = false,
            mail = false,
            craftingOrder = false,
            instanceDifficulty = false,
            clock = false,
            expansionButton = false,
            zoneText = false,
            zoneTextBackground = false,
            addonCompartment = false,
        },
    },
}

-- Initialize default visibility settings for each frame
for key, _ in pairs(VISIBILITY_FRAMES) do
    DEFAULTS.visibility[key] = GetDefaultVisibilitySettings()
end

-- ============================================================================
-- STATE
-- ============================================================================

local settings = nil
local generalHub = nil
local generalPanel = nil
local visibilityPanel = nil
local visibilityCategoryPanels = {}  -- Store category panels (combat, information, interface)
local afkPanel = nil
local minimapPanel = nil  -- Minimap customization panel
local mediaPanel = nil  -- Global media settings panel
local settingsScalePanel = nil  -- Settings panel scaling
local currentVisibilityItemPanel = nil
local minimapButton = nil
local isInAFKMode = false
local isTestingAFK = false
local storedFrameStates = {}
local storedModuleFrameStates = {}  -- Track module-managed frames separately
local pendingVisibilityChanges = {}
local storedNameplateStates = {}
local storedActionBarStates = {}
local visibilityUpdateFrame = nil
local fadeTimers = {}
local storedOnShowScripts = {}  -- Store original OnShow scripts during AFK

-- Track which frames WE have hidden and their current visibility state
local hiddenByUs = {}
local currentVisibilityState = {}  -- true = visible, false = hidden

-- Mouseover detection
local mouseoverHitFrames = {}      -- Hit test frames for mouseover detection
local mouseoverState = {}          -- Track which frames are currently moused over

-- Leatrix Plus conflict tracking
local leatrixConflicts = nil

-- Custom minimap border frame
local customMinimapBorder = nil

-- Button collector state
local buttonDrawer = nil
local collectedButtons = {}
local originalButtonPositions = {}

-- ============================================================================
-- LEATRIX PLUS DETECTION
-- ============================================================================

-- Check if Leatrix Plus is loaded
local function IsLeatrixPlusLoaded()
    return C_AddOns.IsAddOnLoaded("Leatrix_Plus")
end

-- Check for Leatrix Plus feature conflicts
function General:CheckLeatrixConflicts()
    leatrixConflicts = nil
    
    if not IsLeatrixPlusLoaded() then
        return nil
    end
    
    local db = LeaPlusDB
    if not db then return nil end
    
    local conflicts = {}
    
    -- QoL features
    if db["AutoRepairGear"] == "On" then
        conflicts.autoRepair = true
    end
    if db["AutoSellJunk"] == "On" then
        conflicts.autoSellJunk = true
    end
    
    -- Minimap features
    if db["SquareMinimap"] == "On" then
        conflicts.squareMinimap = true
    end
    if db["MinimapModder"] == "On" then
        conflicts.minimapModder = true  -- General minimap modifications
        conflicts.decorations = true     -- Decorations are part of MinimapModder
    end
    if db["HideMiniAddonMenu"] == "On" then
        conflicts.buttonCollector = true
    end
    if db["MinimapNoScale"] == "On" then
        conflicts.minimapScale = true
    end
    
    -- Only store if we found conflicts
    if next(conflicts) then
        leatrixConflicts = conflicts
        TweaksUI:PrintDebug("General: Leatrix Plus conflicts detected:", conflicts)
    end
    
    return conflicts
end

-- Check if Leatrix is managing a specific feature
function General:IsLeatrixManaging(feature)
    if not leatrixConflicts then return false end
    return leatrixConflicts[feature] == true
end

-- Get all current Leatrix conflicts (for UI display)
function General:GetLeatrixConflicts()
    return leatrixConflicts
end

-- Check if Leatrix Plus is loaded (public accessor)
function General:IsLeatrixPlusLoaded()
    return IsLeatrixPlusLoaded()
end

-- ============================================================================
-- SETTINGS ACCESS
-- ============================================================================

function General:GetSettings()
    return settings
end

function General:GetDefaults()
    return DEFAULTS
end

function General:GetSetting(key)
    if settings and settings[key] ~= nil then
        return settings[key]
    end
    return DEFAULTS[key]
end

function General:SetSetting(key, value)
    if settings then
        settings[key] = value
        General:SaveSettings()
end
end

function General:GetVisibilitySetting(frameKey, settingKey)
    if settings and settings.visibility and settings.visibility[frameKey] then
        local val = settings.visibility[frameKey][settingKey]
        if val ~= nil then return val end
    end
    if DEFAULTS.visibility[frameKey] then
        return DEFAULTS.visibility[frameKey][settingKey]
    end
    return nil
end

function General:SetVisibilitySetting(frameKey, settingKey, value)
    if settings then
        settings.visibility = settings.visibility or {}
        settings.visibility[frameKey] = settings.visibility[frameKey] or GetDefaultVisibilitySettings()
        settings.visibility[frameKey][settingKey] = value
        General:SaveSettings()
    end
end

-- ============================================================================
-- VISIBILITY CONDITION CHECKER
-- ============================================================================

local function ShouldFrameBeVisible(frameKey)
    -- Force all visible mode bypasses all visibility conditions
    if TweaksUI.forceAllVisible then return true end
    
    local vs = settings and settings.visibility and settings.visibility[frameKey]
    if not vs then return true end  -- No settings = visible
    
    -- Master hide toggle
    if vs.hide then return false end
    
    -- If visibility conditions not enabled, frame is visible
    if not vs.visibilityEnabled then return true end
    
    -- Check if currently moused over (always show if mouseover enabled and hovering)
    if vs.onMouseover and mouseoverState[frameKey] then
        return true
    end
    
    -- Check all conditions (OR logic - any true condition shows the frame)
    local shouldShow = false
    
    -- Combat conditions
    local inCombat = UnitAffectingCombat("player")
    if vs.inCombat and inCombat then shouldShow = true end
    if vs.outOfCombat and not inCombat then shouldShow = true end
    
    -- Target conditions
    local hasTarget = UnitExists("target")
    if vs.hasTarget and hasTarget then shouldShow = true end
    if vs.noTarget and not hasTarget then shouldShow = true end
    
    -- Group conditions
    local inGroup = IsInGroup()
    local inRaid = IsInRaid()
    local inInstance, instanceType = IsInInstance()
    local inDungeon = inInstance and (instanceType == "party" or instanceType == "raid")
    
    if vs.solo and not inGroup then shouldShow = true end
    if vs.inParty and inGroup and not inRaid then shouldShow = true end
    if vs.inRaid and inRaid then shouldShow = true end
    if vs.inInstance and inDungeon then shouldShow = true end
    
    return shouldShow
end

-- ============================================================================
-- FRAME HIDING/SHOWING METHODS
-- ============================================================================

local function SafeHideFrame(frame)
    if not frame then return false end
    
    -- Check if it's actually a frame with required methods
    if type(frame.IsProtected) ~= "function" then return false end
    
    local success = pcall(function()
        if frame:IsProtected() and InCombatLockdown() then
            pendingVisibilityChanges[frame] = "hide"
            return
        end
        frame:Hide()
        -- Disable mouse interaction to prevent invisible click blocking
        if frame.EnableMouse then
            frame:EnableMouse(false)
        end
    end)
    
    if not success then
        pcall(function()
            frame:SetAlpha(0)
            -- Also disable mouse when using alpha fallback
            if frame.EnableMouse then
                frame:EnableMouse(false)
            end
        end)
    end
    
    return success
end

-- Frames that should never be shown by us (Blizzard bugs or managed internally)
local SHOW_BLACKLIST = {
    ["TutorialFrame"] = true,
    ["HelpPlate"] = true,
    ["HelpPlateTooltip"] = true,
    ["ZoneTextFrame"] = true,      -- Has own fade system
    ["SubZoneTextFrame"] = true,   -- Has own fade system
}

local function SafeShowFrame(frame)
    if not frame then return false end
    
    -- Check if it's actually a frame with GetName method
    if type(frame.GetName) ~= "function" then return false end
    
    -- Check blacklist
    local frameName = frame:GetName()
    if frameName and SHOW_BLACKLIST[frameName] then
        return false  -- Never show these frames
    end
    
    local success = pcall(function()
        if frame:IsProtected() and InCombatLockdown() then
            pendingVisibilityChanges[frame] = "show"
            return
        end
        frame:Show()
        frame:SetAlpha(1)
        -- Re-enable mouse interaction when showing
        if frame.EnableMouse then
            frame:EnableMouse(true)
        end
    end)
    
    return success
end

local function SetFrameAlpha(frame, alpha)
    if not frame then return end
    pcall(function()
        frame:SetAlpha(alpha)
    end)
end

-- ============================================================================
-- VISIBILITY CONTROL
-- ============================================================================

function General:ApplyFrameVisibility(frameKey, instant)
    -- Don't apply visibility during AFK mode - AFK overrides everything
    if isInAFKMode then return end
    
    local info = VISIBILITY_FRAMES[frameKey]
    if not info then return end
    
    local shouldShow = ShouldFrameBeVisible(frameKey)
    local vs = settings and settings.visibility and settings.visibility[frameKey]
    
    -- Track state change
    local wasVisible = currentVisibilityState[frameKey]
    currentVisibilityState[frameKey] = shouldShow
    
    -- Special handling for minimap - need to target the right frame
    if frameKey == "minimap" then
        local useCustomFrame = self:GetMinimapSetting("useCustomFrame")
        local targetFrame
        
        if useCustomFrame and _G["TweaksUI_MinimapContainer"] then
            -- Custom frame mode - control our container
            targetFrame = _G["TweaksUI_MinimapContainer"]
        else
            -- Default mode - control MinimapCluster
            targetFrame = MinimapCluster
        end
        
        if targetFrame then
            if shouldShow then
                if fadeTimers[frameKey] then
                    fadeTimers[frameKey]:Cancel()
                    fadeTimers[frameKey] = nil
                end
                SafeShowFrame(targetFrame)
                hiddenByUs["minimap_target"] = nil
            else
                SafeHideFrame(targetFrame)
                hiddenByUs["minimap_target"] = true
            end
        end
        
        -- Handle fade if enabled and frame is visible
        if shouldShow and vs and vs.fadeEnabled and vs.fadeDelay and vs.fadeAlpha then
            self:StartFadeTimer(frameKey, vs.fadeDelay, vs.fadeAlpha)
        end
        return
    end
    
    -- Standard handling for all other frames
    for _, frameName in ipairs(info.frames) do
        local frame = _G[frameName]
        if frame then
            if shouldShow then
                -- Cancel any pending fade
                if fadeTimers[frameKey] then
                    fadeTimers[frameKey]:Cancel()
                    fadeTimers[frameKey] = nil
                end
                
                SafeShowFrame(frame)
                hiddenByUs[frameName] = nil
            else
                SafeHideFrame(frame)
                hiddenByUs[frameName] = true
            end
        end
    end
    
    -- Handle fade if enabled and frame is visible
    if shouldShow and vs and vs.fadeEnabled and vs.fadeDelay and vs.fadeAlpha then
        self:StartFadeTimer(frameKey, vs.fadeDelay, vs.fadeAlpha)
    end
end

function General:StartFadeTimer(frameKey, delay, targetAlpha)
    -- Cancel existing timer
    if fadeTimers[frameKey] then
        fadeTimers[frameKey]:Cancel()
    end
    
    local info = VISIBILITY_FRAMES[frameKey]
    if not info then return end
    
    fadeTimers[frameKey] = C_Timer.NewTimer(delay, function()
        if isInAFKMode then return end  -- Don't fade during AFK
        
        -- Special handling for minimap
        if frameKey == "minimap" then
            local useCustomFrame = General:GetMinimapSetting("useCustomFrame")
            local targetFrame
            
            if useCustomFrame and _G["TweaksUI_MinimapContainer"] then
                targetFrame = _G["TweaksUI_MinimapContainer"]
            else
                targetFrame = MinimapCluster
            end
            
            if targetFrame and targetFrame:IsShown() then
                SetFrameAlpha(targetFrame, targetAlpha)
            end
        else
            -- Standard handling
            for _, frameName in ipairs(info.frames) do
                local frame = _G[frameName]
                if frame and frame:IsShown() then
                    SetFrameAlpha(frame, targetAlpha)
                end
            end
        end
        fadeTimers[frameKey] = nil
    end)
end

function General:ResetFade(frameKey)
    -- Cancel timer and restore alpha
    if fadeTimers[frameKey] then
        fadeTimers[frameKey]:Cancel()
        fadeTimers[frameKey] = nil
    end
    
    local info = VISIBILITY_FRAMES[frameKey]
    if not info then return end
    
    -- Special handling for minimap
    if frameKey == "minimap" then
        local useCustomFrame = self:GetMinimapSetting("useCustomFrame")
        local targetFrame
        
        if useCustomFrame and _G["TweaksUI_MinimapContainer"] then
            targetFrame = _G["TweaksUI_MinimapContainer"]
        else
            targetFrame = MinimapCluster
        end
        
        if targetFrame then
            SetFrameAlpha(targetFrame, 1)
        end
        return
    end
    
    -- Standard handling
    for _, frameName in ipairs(info.frames) do
        local frame = _G[frameName]
        if frame then
            SetFrameAlpha(frame, 1)
        end
    end
end

function General:ApplyAllVisibility()
    if isInAFKMode then return end
    
    for frameKey, _ in pairs(VISIBILITY_FRAMES) do
        self:ApplyFrameVisibility(frameKey, false)
    end
end

-- ============================================================================
-- HIDE BLIZZARD BUFF/DEBUFF FRAMES
-- ============================================================================

function General:ApplyBlizzardBuffVisibility()
    local hide = self:GetSetting("hideBlizzardBuffs")
    local frame = BuffFrame
    
    if not frame then return end
    
    if hide then
        -- Hide by setting alpha to 0 and disabling mouse
        frame:SetAlpha(0)
        frame:EnableMouse(false)
        -- Also disable mouse on all children
        for _, child in ipairs({frame:GetChildren()}) do
            if child.EnableMouse then
                child:EnableMouse(false)
            end
        end
    else
        -- Restore visibility
        frame:SetAlpha(1)
        frame:EnableMouse(true)
        for _, child in ipairs({frame:GetChildren()}) do
            if child.EnableMouse then
                child:EnableMouse(true)
            end
        end
    end
end

function General:ApplyBlizzardDebuffVisibility()
    local hide = self:GetSetting("hideBlizzardDebuffs")
    local frame = DebuffFrame
    
    if not frame then return end
    
    if hide then
        -- Hide by setting alpha to 0 and disabling mouse
        frame:SetAlpha(0)
        frame:EnableMouse(false)
        -- Also disable mouse on all children
        for _, child in ipairs({frame:GetChildren()}) do
            if child.EnableMouse then
                child:EnableMouse(false)
            end
        end
    else
        -- Restore visibility
        frame:SetAlpha(1)
        frame:EnableMouse(true)
        for _, child in ipairs({frame:GetChildren()}) do
            if child.EnableMouse then
                child:EnableMouse(true)
            end
        end
    end
end

function General:ApplyBlizzardBuffDebuffVisibility()
    self:ApplyBlizzardBuffVisibility()
    self:ApplyBlizzardDebuffVisibility()
end

function General:ProcessPendingChanges()
    if InCombatLockdown() then return end
    
    for frame, action in pairs(pendingVisibilityChanges) do
        if action == "hide" then
            SafeHideFrame(frame)
        else
            SafeShowFrame(frame)
        end
    end
    
    pendingVisibilityChanges = {}
end

-- ============================================================================
-- MOUSEOVER HIT FRAME SYSTEM
-- ============================================================================

-- Check if mouse is over a frame or any of its children (recursive)
local function IsMouseOverFrameOrChildren(frame)
    if not frame then return false end
    
    -- Check the frame itself
    if frame:IsMouseOver() then return true end
    
    -- Check all children recursively
    local children = {frame:GetChildren()}
    for _, child in ipairs(children) do
        if child:IsVisible() and IsMouseOverFrameOrChildren(child) then
            return true
        end
    end
    
    return false
end

-- Check if mouse is over any of the frames for a given frameKey
local function IsMouseOverAnyFrame(frameKey)
    local info = VISIBILITY_FRAMES[frameKey]
    if not info then return false end
    
    for _, frameName in ipairs(info.frames) do
        local frame = _G[frameName]
        if frame and frame:IsVisible() and IsMouseOverFrameOrChildren(frame) then
            return true
        end
    end
    
    return false
end

-- Create a transparent hit frame for mouseover detection
local function CreateMouseoverHitFrame(frameKey)
    if mouseoverHitFrames[frameKey] then return end
    
    local info = VISIBILITY_FRAMES[frameKey]
    if not info or not info.frames or #info.frames == 0 then return end
    
    -- Get the first EXISTING frame as the anchor
    local targetFrame = nil
    for _, frameName in ipairs(info.frames) do
        local frame = _G[frameName]
        if frame then
            targetFrame = frame
            break
        end
    end
    if not targetFrame then return end
    
    local hitFrame = CreateFrame("Frame", "TweaksUI_MouseoverHit_" .. frameKey, UIParent)
    hitFrame:SetFrameStrata("BACKGROUND")
    hitFrame:SetFrameLevel(0)
    hitFrame.frameKey = frameKey
    hitFrame.isMouseOverTarget = false  -- Track if mouse is over the actual target
    
    -- Update position to match target frame
    -- For mouseover visibility, hitFrame must stay active even when target is hidden
    local function UpdateHitFramePosition()
        -- Get target frame's position (even if hidden, it still has a position)
        if not targetFrame then return end
        
        -- Match the target frame's position and size
        hitFrame:ClearAllPoints()
        hitFrame:SetPoint("TOPLEFT", targetFrame, "TOPLEFT", 0, 0)
        hitFrame:SetPoint("BOTTOMRIGHT", targetFrame, "BOTTOMRIGHT", 0, 0)
        
        local width, height = targetFrame:GetSize()
        if width < 1 then width = 100 end
        if height < 1 then height = 50 end
        hitFrame:SetSize(width, height)
    end
    
    -- Update position and check for mouseover state using polling only
    -- We don't use OnEnter/OnLeave because EnableMouse can block clicks in some WoW versions
    hitFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed > 0.05 then  -- Check every 50ms
            self.elapsed = 0
            UpdateHitFramePosition()
            
            -- Check if mouse is over the hitFrame bounds (without EnableMouse)
            local isOverHitFrame = self:IsMouseOver()
            -- Also check actual target frame(s) if visible
            local isOverTarget = IsMouseOverAnyFrame(frameKey)
            local wasOver = mouseoverState[frameKey]
            
            if isOverTarget or isOverHitFrame then
                -- Mouse is over target or hit frame area - keep visible
                if not wasOver then
                    mouseoverState[frameKey] = true
                    General:ApplyFrameVisibility(frameKey, true)
                    General:ResetFade(frameKey)
                end
            else
                -- Mouse has left both target and hit frame - trigger hide
                if wasOver then
                    mouseoverState[frameKey] = false
                    General:ApplyFrameVisibility(frameKey, true)
                end
            end
        end
    end)
    
    -- Don't use OnEnter/OnLeave - they require EnableMouse which blocks clicks
    -- IsMouseOver() works without EnableMouse for polling
    hitFrame:EnableMouse(false)
    hitFrame:Show()  -- Always show for mouseover detection
    
    mouseoverHitFrames[frameKey] = hitFrame
    
    -- Hook the actual frame(s) for immediate response when entering them directly
    for _, frameName in ipairs(info.frames) do
        local frame = _G[frameName]
        if frame and not frame.tweaksMouseoverHooked then
            frame:HookScript("OnEnter", function()
                mouseoverState[frameKey] = true
            end)
            -- OnLeave handled by OnUpdate polling
            frame.tweaksMouseoverHooked = true
        end
    end
end

-- Remove hit frame
local function RemoveMouseoverHitFrame(frameKey)
    if mouseoverHitFrames[frameKey] then
        mouseoverHitFrames[frameKey]:Hide()
        mouseoverHitFrames[frameKey]:SetScript("OnUpdate", nil)
        mouseoverHitFrames[frameKey] = nil
    end
    mouseoverState[frameKey] = nil
end

-- Update mouseover hit frames based on settings
function General:UpdateMouseoverHitFrames()
    for frameKey, info in pairs(VISIBILITY_FRAMES) do
        -- Skip frames that don't support mouseover
        if info.noMouseover then
            RemoveMouseoverHitFrame(frameKey)
        else
            local vs = settings and settings.visibility and settings.visibility[frameKey]
            if vs and vs.visibilityEnabled and vs.onMouseover then
                CreateMouseoverHitFrame(frameKey)
            else
                RemoveMouseoverHitFrame(frameKey)
            end
        end
    end
end

-- ============================================================================
-- VISIBILITY UPDATE LOOP
-- ============================================================================

function General:SetupVisibilityUpdater()
    if visibilityUpdateFrame then return end
    
    visibilityUpdateFrame = CreateFrame("Frame")
    visibilityUpdateFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    visibilityUpdateFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    visibilityUpdateFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    visibilityUpdateFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    visibilityUpdateFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    visibilityUpdateFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    
    visibilityUpdateFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_ENABLED" then
            General:ProcessPendingChanges()
        end
        -- Update all visibility on relevant events
        C_Timer.After(0.1, function()
            General:ApplyAllVisibility()
        end)
        -- Some frames like TalkingHeadFrame load late - check again after delays
        if event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(1.0, function()
                General:ApplyAllVisibility()
            end)
            C_Timer.After(3.0, function()
                General:ApplyAllVisibility()
            end)
        end
    end)
end

-- ============================================================================
-- AFK MODE
-- ============================================================================

local AFK_SAFE_FRAMES = {
    "Boss1TargetFrame", "Boss2TargetFrame", "Boss3TargetFrame",
    "Boss4TargetFrame", "Boss5TargetFrame",
    "BuffFrame", "DebuffFrame",
    "ExtraActionBarFrame", "ZoneAbilityFrame",
    "StatusTrackingBarManager", "UIErrorsFrame", "DurabilityFrame",
    "MicroMenuContainer", "BagsBar",
    -- Note: Cooldown viewers are module-managed, not listed here
    -- Note: ObjectiveTrackerFrame is handled by ObjectiveTrackerFrame.lua
}

local AFK_OPTIONAL_FRAMES = {
    minimap = {"MinimapCluster", "Minimap"},
    chat = {"TweaksUIChatFrame"},
}

local function StoreActionBarStates()
    storedActionBarStates = {}
    
    local barFrames = {
        "MainMenuBar", "MainActionBar",  -- Both old and new names
        "MultiBarBottomLeft", "MultiBarBottomRight",
        "MultiBarRight", "MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7",
        "StanceBar", "PossessActionBar", "PetActionBar",
    }
    
    for _, frameName in ipairs(barFrames) do
        local frame = _G[frameName]
        if frame then
            storedActionBarStates[frameName] = {
                shown = frame:IsShown(),
                alpha = frame:GetAlpha(),
            }
        end
    end
end

local function RestoreActionBarStates()
    for frameName, state in pairs(storedActionBarStates) do
        local frame = _G[frameName]
        if frame and state.shown then
            pcall(function()
                frame:Show()
                frame:SetAlpha(state.alpha or 1)
                -- Re-enable mouse interaction
                if frame.EnableMouse then
                    frame:EnableMouse(true)
                end
            end)
        end
    end
    
    -- Also ensure individual action buttons have mouse enabled
    local buttonPrefixes = {"ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", 
                           "MultiBarRightButton", "MultiBarLeftButton", "MultiBar5Button", 
                           "MultiBar6Button", "MultiBar7Button"}
    for _, prefix in ipairs(buttonPrefixes) do
        for i = 1, 12 do
            local button = _G[prefix .. i]
            if button and button.EnableMouse then
                pcall(function() button:EnableMouse(true) end)
            end
        end
    end
    
    local actionBars = TweaksUI.ModuleManager and TweaksUI.ModuleManager:GetModule(TweaksUI.MODULE_IDS.ACTION_BARS)
    if actionBars and actionBars.enabled and actionBars.Refresh then
        pcall(function() actionBars:Refresh() end)
    end
    
    storedActionBarStates = {}
end

function General:EnterAFKMode(isTest)
    if isInAFKMode then return end
    if not isTest and not self:GetSetting("afkModeEnabled") then return end
    
    isInAFKMode = true
    isTestingAFK = isTest or false
    storedFrameStates = {}
    storedModuleFrameStates = {}
    
    -- Cancel all fade timers
    for frameKey, timer in pairs(fadeTimers) do
        timer:Cancel()
        fadeTimers[frameKey] = nil
    end
    
    local fadeDuration = self:GetSetting("afkFadeAnimation") and self:GetSetting("afkFadeDuration") or 0
    
    StoreActionBarStates()
    
    -- Frames managed by modules - store separately, restore only if they were visible
    local MODULE_MANAGED_FRAMES = {
        -- Cooldowns
        ["EssentialCooldownViewer"] = true,
        ["UtilityCooldownViewer"] = true,
        ["BuffIconCooldownViewer"] = true,
        -- ResourceBars
        ["TweaksUI_ResourceBars_PowerBar"] = true,
        ["TweaksUI_ResourceBars_ClassPower"] = true,
        ["TweaksUI_ResourceBars_SoulFragments"] = true,
        -- TweaksUI Unit Frames (actual display frames, not settings panels)
        ["TweaksUI_UF_player"] = true,
        ["TweaksUI_UF_target"] = true,
        ["TweaksUI_UF_focus"] = true,
        ["TweaksUI_UF_pet"] = true,
        ["TweaksUI_UF_targettarget"] = true,
        ["TweaksUI_PartyContainer"] = true,
        ["TweaksUI_TankContainer"] = true,
        ["TweaksUI_BossContainer"] = true,
    }
    
    local function HideFrameForAFK(frame, shouldStore)
        if not frame then return end
        
        -- Check if it's actually a frame
        if type(frame.GetName) ~= "function" then return end
        
        local frameName = frame:GetName()
        
        -- Check if frame is ACTUALLY visible (shown AND has alpha)
        local wasShown = false
        local currentAlpha = 0
        pcall(function()
            currentAlpha = frame:GetAlpha() or 0
            wasShown = frame:IsShown() and (currentAlpha > 0.01)
        end)
        
        -- Store module-managed frames separately
        local isModuleManaged = frameName and MODULE_MANAGED_FRAMES[frameName]
        
        if isModuleManaged and wasShown then
            -- Store in separate table - we'll restore these based on their pre-AFK state
            storedModuleFrameStates[frameName] = {
                shown = true,
                alpha = currentAlpha,
            }
        elseif shouldStore and frameName and wasShown then
            storedFrameStates[frameName] = {
                shown = true,
                alpha = currentAlpha,
            }
        end
        
        -- Skip frames that aren't actually visible
        if not wasShown then return end
        
        -- Skip fade animation for blacklisted frames (UIFrameFadeOut calls Show() internally)
        local skipFade = frameName and SHOW_BLACKLIST[frameName]
        
        if fadeDuration > 0 and not skipFade then
            UIFrameFadeOut(frame, fadeDuration, currentAlpha, 0)
            C_Timer.After(fadeDuration, function()
                if isInAFKMode and frame then
                    pcall(function() frame:Hide() end)
                end
            end)
        else
            pcall(function() frame:Hide() end)
        end
    end
    
    -- Hide all visibility-controlled frames (even if they have "has target" etc.)
    for frameKey, info in pairs(VISIBILITY_FRAMES) do
        for _, frameName in ipairs(info.frames) do
            local frame = _G[frameName]
            if frame then
                HideFrameForAFK(frame, true)
            end
        end
    end
    
    -- Hide safe frames
    for _, frameName in ipairs(AFK_SAFE_FRAMES) do
        local frame = _G[frameName]
        if frame then HideFrameForAFK(frame, true) end
    end
    
    -- Frames that need OnShow hooks to prevent auto-showing during AFK
    -- (These modules have update functions that call Show())
    local hookFrameNames = {
        "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer",
        "TweaksUI_ResourceBars_PowerBar", "TweaksUI_ResourceBars_ClassPower", 
        "TweaksUI_ResourceBars_SoulFragments",
    }
    
    for _, frameName in ipairs(hookFrameNames) do
        local frame = _G[frameName]
        if frame then
            -- Store if visible before hiding
            local wasShown = false
            pcall(function()
                wasShown = frame:IsShown() and (frame:GetAlpha() > 0.01)
            end)
            if wasShown then
                storedModuleFrameStates[frameName] = { shown = true, alpha = frame:GetAlpha() or 1 }
            end
            
            -- Store original OnShow script and hook to prevent showing
            storedOnShowScripts[frameName] = frame:GetScript("OnShow")
            frame:SetScript("OnShow", function(self)
                if isInAFKMode then
                    self:Hide()
                elseif storedOnShowScripts[frameName] then
                    storedOnShowScripts[frameName](self)
                end
            end)
            
            -- Now hide the frame
            HideFrameForAFK(frame, false)
        end
    end
    
    -- TweaksUI Unit Frames use state drivers - we need to override them
    local unitFrameNames = {
        "TweaksUI_UF_player", "TweaksUI_UF_target",
        "TweaksUI_UF_focus", "TweaksUI_UF_pet", "TweaksUI_UF_targettarget",
    }
    for _, frameName in ipairs(unitFrameNames) do
        local frame = _G[frameName]
        if frame then
            -- Store if visible
            local wasShown = false
            pcall(function()
                wasShown = frame:IsShown() and (frame:GetAlpha() > 0.01)
            end)
            if wasShown then
                storedModuleFrameStates[frameName] = { shown = true, alpha = frame:GetAlpha() or 1 }
            end
            -- Override state driver to force hide
            pcall(function()
                RegisterStateDriver(frame, "visibility", "hide")
            end)
        end
    end
    
    -- Group containers don't have state drivers, just hide them
    local groupContainers = { "TweaksUI_PartyContainer", "TweaksUI_TankContainer", "TweaksUI_BossContainer" }
    for _, frameName in ipairs(groupContainers) do
        local frame = _G[frameName]
        if frame then HideFrameForAFK(frame, false) end
    end
    
    -- Always hide Blizzard unit frames during AFK (they may still show through)
    local blizzardUnitFrames = {
        "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame",
        "TargetFrameToT", "FocusFrameToT",
    }
    for _, frameName in ipairs(blizzardUnitFrames) do
        local frame = _G[frameName]
        if frame then HideFrameForAFK(frame, true) end
    end
    
    -- Hide action bars (include both old and new frame names for compatibility)
    local actionBarFrames = {
        "MainMenuBar", "MainActionBar",  -- Action Bar 1 (both old and new names)
        "MultiBarBottomLeft", "MultiBarBottomRight",
        "MultiBarRight", "MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7",
        "StanceBar", "PossessActionBar", "PetActionBar",
    }
    for _, frameName in ipairs(actionBarFrames) do
        local frame = _G[frameName]
        if frame then HideFrameForAFK(frame, false) end
    end
    
    -- Hide Blizzard chat frames and edit box
    local chatFrames = {"ChatFrame1", "ChatFrame2", "ChatFrame3", "GeneralDockManager", "ChatFrame1EditBox"}
    for _, frameName in ipairs(chatFrames) do
        local frame = _G[frameName]
        if frame then HideFrameForAFK(frame, false) end
    end
    
    -- Optional frames
    if not self:GetSetting("afkKeepMinimap") then
        for _, frameName in ipairs(AFK_OPTIONAL_FRAMES.minimap) do
            local frame = _G[frameName]
            if frame then HideFrameForAFK(frame, true) end
        end
    end
    
    if not self:GetSetting("afkKeepChat") then
        for _, frameName in ipairs(AFK_OPTIONAL_FRAMES.chat) do
            local frame = _G[frameName]
            if frame then HideFrameForAFK(frame, true) end  -- Store state for proper restoration
        end
    end
    
    -- Camera spin
    if self:GetSetting("afkCameraSpin") then
        local spinSpeed = self:GetSetting("afkCameraSpinSpeed") or 0.05
        MoveViewRightStart(spinSpeed)
    end
    
    -- Hide nameplates
    if self:GetSetting("afkHideNameplates") then
        storedNameplateStates = {
            nameplateShowAll = GetCVar("nameplateShowAll"),
            nameplateShowEnemies = GetCVar("nameplateShowEnemies"),
            nameplateShowFriends = GetCVar("nameplateShowFriends"),
            nameplateShowFriendlyNPCs = GetCVar("nameplateShowFriendlyNPCs"),
        }
        SetCVar("nameplateShowAll", 0)
        SetCVar("nameplateShowEnemies", 0)
        SetCVar("nameplateShowFriends", 0)
        SetCVar("nameplateShowFriendlyNPCs", 0)
    end
    
    TweaksUI:PrintDebug("General: Entered AFK mode" .. (isTest and " (test)" or ""))
end

function General:ExitAFKMode()
    if not isInAFKMode then return end
    
    isInAFKMode = false
    local wasTest = isTestingAFK
    isTestingAFK = false
    
    local fadeDuration = self:GetSetting("afkFadeAnimation") and self:GetSetting("afkFadeDuration") or 0
    
    -- Restore OnShow scripts first (isInAFKMode is now false so hook will pass through)
    for frameName, originalScript in pairs(storedOnShowScripts) do
        local frame = _G[frameName]
        if frame then
            pcall(function()
                frame:SetScript("OnShow", originalScript)
            end)
        end
    end
    storedOnShowScripts = {}
    
    -- Stop camera spin
    MoveViewRightStop()
    MoveViewLeftStop()
    
    -- Restore nameplates
    if storedNameplateStates and next(storedNameplateStates) then
        for cvar, value in pairs(storedNameplateStates) do
            pcall(function() SetCVar(cvar, value) end)
        end
        storedNameplateStates = {}
    end
    
    -- Check if Chat module is enabled (to skip Blizzard chat frame restoration)
    local chatModuleEnabled = false
    local chatModule = TweaksUI.ModuleManager and TweaksUI.ModuleManager:GetModule(TweaksUI.MODULE_IDS.CHAT)
    if chatModule and chatModule.enabled then
        chatModuleEnabled = true
    end
    
    -- Restore stored frames (skip blacklisted frames and Blizzard chat if Chat module is enabled)
    for frameName, state in pairs(storedFrameStates) do
        if state.shown and not SHOW_BLACKLIST[frameName] then
            -- Skip Blizzard chat frames if Chat module is enabled
            local isBlizzardChat = frameName and (frameName:match("^ChatFrame%d") or frameName == "GeneralDockManager")
            if not (chatModuleEnabled and isBlizzardChat) then
                local frame = _G[frameName]
                if frame then
                    pcall(function()
                        frame:Show()
                        if fadeDuration > 0 then
                            frame:SetAlpha(0)
                            UIFrameFadeIn(frame, fadeDuration, 0, state.alpha or 1)
                        else
                            frame:SetAlpha(state.alpha or 1)
                        end
                    end)
                end
            end
        end
    end
    
    storedFrameStates = {}
    
    -- Re-apply visibility conditions (this will hide/show based on current conditions)
    C_Timer.After(0.1, function()
        General:ApplyAllVisibility()
    end)
    
    -- Restore TweaksUI UnitFrames state drivers and refresh
    C_Timer.After(0.15, function()
        local unitFrames = TweaksUI.ModuleManager and TweaksUI.ModuleManager:GetModule(TweaksUI.MODULE_IDS.UNIT_FRAMES)
        if unitFrames and unitFrames.enabled then
            -- Re-register state drivers with proper conditions
            local unitStateConditions = {
                ["TweaksUI_UF_player"] = "show",
                ["TweaksUI_UF_target"] = "[@target,exists] show; hide",
                ["TweaksUI_UF_focus"] = "[@focus,exists] show; hide", 
                ["TweaksUI_UF_pet"] = "[@pet,exists] show; hide",
                ["TweaksUI_UF_targettarget"] = "[@target,exists] show; hide",
            }
            for frameName, condition in pairs(unitStateConditions) do
                local frame = _G[frameName]
                if frame then
                    pcall(function()
                        RegisterStateDriver(frame, "visibility", condition)
                    end)
                end
            end
            
            -- Refresh frame data
            if unitFrames.RefreshFrame then
                pcall(function() unitFrames:RefreshFrame("player") end)
                pcall(function() unitFrames:RefreshFrame("target") end)
                pcall(function() unitFrames:RefreshFrame("focus") end)
                pcall(function() unitFrames:RefreshFrame("pet") end)
                pcall(function() unitFrames:RefreshFrame("targettarget") end)
            end
        end
    end)
    
    -- Restore action bars
    C_Timer.After(0.2, function()
        RestoreActionBarStates()
    end)
    
    -- Restore chat - only TweaksUI chat frame (Blizzard frames should stay hidden when Chat module is enabled)
    C_Timer.After(0.25, function()
        local chat = TweaksUI.ModuleManager and TweaksUI.ModuleManager:GetModule(TweaksUI.MODULE_IDS.CHAT)
        if chat and chat.enabled then
            -- Restore TweaksUI chat frame
            if TweaksUIChatFrame then
                pcall(function() 
                    TweaksUIChatFrame:Show()
                    TweaksUIChatFrame:SetAlpha(1)
                end)
            end
            -- Refresh the chat module to restore proper state
            if chat.Refresh then
                pcall(function() chat:Refresh() end)
            end
        end
    end)
    
    -- Notify Cooldowns module to update visibility based on current conditions
    -- Don't force-show module frames - let their visibility systems decide
    C_Timer.After(0.3, function()
        -- Tell Cooldowns module to refresh visibility
        local cooldowns = TweaksUI.ModuleManager and TweaksUI.ModuleManager:GetModule(TweaksUI.MODULE_IDS.COOLDOWNS)
        if cooldowns and cooldowns.UpdateAllVisibility then
            pcall(function() cooldowns:UpdateAllVisibility() end)
        end
        
        storedModuleFrameStates = {}
    end)
    
    -- Re-apply minimap settings (square shape auto-hides border, etc.)
    C_Timer.After(0.35, function()
        General:ApplyAllMinimapSettings()
    end)
    
    TweaksUI:PrintDebug("General: Exited AFK mode" .. (wasTest and " (test)" or ""))
end

function General:IsInAFKMode()
    return isInAFKMode
end

function General:IsTestingAFK()
    return isTestingAFK
end

function General:SetupAFKMode()
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_FLAGS_CHANGED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    
    eventFrame:SetScript("OnEvent", function(self, event, unit)
        if event == "PLAYER_FLAGS_CHANGED" then
            if unit == "player" or unit == nil then
                if UnitIsAFK("player") then
                    General:EnterAFKMode(false)
                else
                    if not isTestingAFK then
                        General:ExitAFKMode()
                    end
                end
            end
        elseif event == "PLAYER_REGEN_ENABLED" then
            General:ProcessPendingChanges()
        end
    end)
end

-- ============================================================================
-- AUTO REPAIR & AUTO SELL JUNK
-- ============================================================================

-- Perform auto repair
function General:DoAutoRepair()
    -- Check if merchant can repair
    if not CanMerchantRepair() then return end
    
    -- Get repair cost
    local repairCost, canRepair = GetRepairAllCost()
    if not canRepair or repairCost <= 0 then return end
    
    -- Check for guild repair option
    local useGuild = self:GetSetting("autoRepairGuild") and IsInGuild() and CanGuildBankRepair()
    
    if useGuild then
        local guildMoney = GetGuildBankWithdrawMoney()
        -- guildMoney == -1 means unlimited withdrawal
        if guildMoney == -1 or guildMoney >= repairCost then
            RepairAllItems(true)  -- true = use guild funds
            TweaksUI:Print(string.format("|cff00ff00Repaired|r (Guild): %s", GetCoinTextureString(repairCost)))
            return
        end
    end
    
    -- Use personal funds
    if GetMoney() >= repairCost then
        RepairAllItems(false)
        TweaksUI:Print(string.format("|cff00ff00Repaired|r: %s", GetCoinTextureString(repairCost)))
    else
        TweaksUI:Print("|cffff6666Not enough gold to repair!|r")
    end
end

-- Perform auto sell junk
function General:DoAutoSellJunk()
    local totalValue = 0
    local itemsSold = 0
    
    for bag = 0, NUM_BAG_SLOTS do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.quality == Enum.ItemQuality.Poor and not info.isLocked then
                -- Get vendor price
                local itemInfo = {GetItemInfo(info.itemID)}
                local vendorPrice = itemInfo[11] or 0
                
                if vendorPrice > 0 then
                    totalValue = totalValue + (vendorPrice * info.stackCount)
                    itemsSold = itemsSold + 1
                    C_Container.UseContainerItem(bag, slot)
                end
            end
        end
    end
    
    if itemsSold > 0 then
        TweaksUI:Print(string.format("|cff00ff00Sold %d junk item(s)|r: %s", itemsSold, GetCoinTextureString(totalValue)))
    end
end

-- Setup merchant event handler
function General:SetupMerchantHandler()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("MERCHANT_SHOW")
    frame:SetScript("OnEvent", function()
        -- Auto repair first (if enabled and not managed by Leatrix)
        if General:GetSetting("autoRepair") and not General:IsLeatrixManaging("autoRepair") then
            General:DoAutoRepair()
        end
        
        -- Then sell junk with small delay (if enabled and not managed by Leatrix)
        if General:GetSetting("autoSellJunk") and not General:IsLeatrixManaging("autoSellJunk") then
            C_Timer.After(0.3, function()
                General:DoAutoSellJunk()
            end)
        end
    end)
    
    TweaksUI:PrintDebug("General: Merchant handler initialized")
end

-- ============================================================================
-- MINIMAP CUSTOMIZATION
-- ============================================================================

-- Get minimap setting with defaults
function General:GetMinimapSetting(key)
    if settings and settings.minimapSettings and settings.minimapSettings[key] ~= nil then
        return settings.minimapSettings[key]
    end
    return DEFAULTS.minimapSettings[key]
end

-- Get minimap hide setting
function General:GetMinimapHideSetting(key)
    if settings and settings.minimapSettings and settings.minimapSettings.hide and settings.minimapSettings.hide[key] ~= nil then
        return settings.minimapSettings.hide[key]
    end
    return DEFAULTS.minimapSettings.hide[key]
end

-- Set minimap setting
function General:SetMinimapSetting(key, value)
    if settings then
        settings.minimapSettings = settings.minimapSettings or {}
        settings.minimapSettings[key] = value
        General:SaveSettings()
end
end

-- Set minimap hide setting
function General:SetMinimapHideSetting(key, value)
    if settings then
        settings.minimapSettings = settings.minimapSettings or {}
        settings.minimapSettings.hide = settings.minimapSettings.hide or {}
        settings.minimapSettings.hide[key] = value
    end
end

-- Get custom border setting
function General:GetCustomBorderSetting(key)
    if settings and settings.minimapSettings and settings.minimapSettings.customBorder then
        return settings.minimapSettings.customBorder[key]
    end
    return DEFAULTS.minimapSettings.customBorder[key]
end

-- Set custom border setting
function General:SetCustomBorderSetting(key, value)
    if settings then
        settings.minimapSettings = settings.minimapSettings or {}
        settings.minimapSettings.customBorder = settings.minimapSettings.customBorder or {}
        settings.minimapSettings.customBorder[key] = value
    end
end

-- Reset all minimap settings to defaults
function General:ResetMinimapSettings()
    if settings then
        -- Deep copy the defaults
        settings.minimapSettings = TweaksUI.Utilities:DeepCopy(DEFAULTS.minimapSettings)
        TweaksUI:Print("Minimap settings reset to defaults. Reload UI to apply.")
    end
end

-- Create or update custom square minimap border
function General:CreateCustomMinimapBorder()
    if not customMinimapBorder then
        customMinimapBorder = CreateFrame("Frame", "TweaksUI_MinimapBorder", Minimap, "BackdropTemplate")
        customMinimapBorder:SetFrameStrata("BACKGROUND")
        customMinimapBorder:SetFrameLevel(Minimap:GetFrameLevel() + 1)
    end
    
    local width = self:GetCustomBorderSetting("width") or 2
    local color = self:GetCustomBorderSetting("color") or { r = 0.4, g = 0.4, b = 0.4 }
    
    -- Position around minimap
    customMinimapBorder:ClearAllPoints()
    customMinimapBorder:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -width, width)
    customMinimapBorder:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", width, -width)
    
    -- Set up border backdrop
    customMinimapBorder:SetBackdrop({
        edgeFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeSize = width,
    })
    customMinimapBorder:SetBackdropBorderColor(color.r, color.g, color.b, 1)
    
    return customMinimapBorder
end

-- Update custom border appearance
function General:UpdateCustomMinimapBorder()
    if not customMinimapBorder then return end
    
    local width = self:GetCustomBorderSetting("width") or 2
    local color = self:GetCustomBorderSetting("color") or { r = 0.4, g = 0.4, b = 0.4 }
    
    -- Reposition for new width
    customMinimapBorder:ClearAllPoints()
    customMinimapBorder:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -width, width)
    customMinimapBorder:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", width, -width)
    
    -- Update backdrop
    customMinimapBorder:SetBackdrop({
        edgeFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeSize = width,
    })
    customMinimapBorder:SetBackdropBorderColor(color.r, color.g, color.b, 1)
end

-- Apply square minimap shape
function General:ApplyMinimapShape()
    -- Only apply minimap modifications if useCustomFrame is enabled
    -- When OFF, leave Blizzard's minimap completely alone
    if not self:GetMinimapSetting("useCustomFrame") then
        return
    end
    
    -- If custom frame is handling it, let it do the work
    if TweaksUI.MinimapFrame and TweaksUI.MinimapFrame:IsEnabled() then
        return
    end
    
    if self:IsLeatrixManaging("squareMinimap") then return end
    
    local isSquare = self:GetMinimapSetting("squareShape")
    local isRotating = GetCVar("rotateMinimap") == "1"
    
    -- Border frames to hide with square minimap
    local borderFrames = {"MinimapBorder", "MinimapBorderTop", "MinimapCompassTexture"}
    
    if isSquare then
        if isRotating then
            -- Square minimap is incompatible with rotation - warn user once
            if not self.rotationWarningShown then
                print("|cff00ff00TweaksUI:|r Square minimap is incompatible with 'Rotate Minimap'. Disable rotation in Edit Mode for square minimap.")
                self.rotationWarningShown = true
            end
            -- Keep circular when rotating
            Minimap:SetMaskTexture("Interface\\Minimap\\UI-Minimap-Background")
            
            -- Hide custom border since we're circular
            if customMinimapBorder then
                customMinimapBorder:Hide()
            end
            
            -- Keep Blizzard border hidden if user has that setting
            if self:GetMinimapHideSetting("border") then
                for _, frameName in ipairs(borderFrames) do
                    local frame = _G[frameName]
                    if frame then
                        pcall(function()
                            frame:Hide()
                            frame:SetAlpha(0)
                        end)
                    end
                end
            end
        else
            -- NO ROTATION: Square mask works fine
            Minimap:SetMaskTexture("Interface\\BUTTONS\\WHITE8X8")
            self.rotationWarningShown = nil  -- Reset warning flag
            
            -- Auto-hide Blizzard border when using square shape
            for _, frameName in ipairs(borderFrames) do
                local frame = _G[frameName]
                if frame then
                    pcall(function()
                        frame:Hide()
                        frame:SetAlpha(0)
                    end)
                end
            end
            
            -- Show custom border if user hasn't hidden border option
            if not self:GetMinimapHideSetting("border") then
                self:CreateCustomMinimapBorder()
                customMinimapBorder:Show()
            else
                if customMinimapBorder then
                    customMinimapBorder:Hide()
                end
            end
        end
    else
        -- CIRCULAR MODE
        Minimap:SetMaskTexture("Interface\\Minimap\\UI-Minimap-Background")
        self.rotationWarningShown = nil  -- Reset warning flag
        
        -- Hide custom border when circular
        if customMinimapBorder then
            customMinimapBorder:Hide()
        end
        
        -- Only restore Blizzard border if user hasn't manually hidden it
        if not self:GetMinimapHideSetting("border") then
            for _, frameName in ipairs(borderFrames) do
                local frame = _G[frameName]
                if frame then
                    pcall(function()
                        frame:SetAlpha(1)
                        frame:Show()
                    end)
                end
            end
        end
    end
end

-- Monitor for rotation setting changes
function General:SetupRotationMonitor()
    local rotationFrame = CreateFrame("Frame")
    rotationFrame:RegisterEvent("CVAR_UPDATE")
    rotationFrame:SetScript("OnEvent", function(self, event, cvar)
        if cvar == "rotateMinimap" then
            -- Re-apply minimap shape when rotation setting changes
            C_Timer.After(0.1, function()
                General:ApplyMinimapShape()
            end)
        end
    end)
end

-- Apply minimap scale
function General:ApplyMinimapScale()
    -- Only apply minimap modifications if useCustomFrame is enabled
    -- When OFF, leave Blizzard's minimap completely alone
    if not self:GetMinimapSetting("useCustomFrame") then
        return
    end
    
    -- If custom frame is handling it, let it do the work
    if TweaksUI.MinimapFrame and TweaksUI.MinimapFrame:IsEnabled() then
        return
    end
    
    if self:IsLeatrixManaging("minimapScale") then return end
    
    local scale = self:GetMinimapSetting("scale") or 1.0
    
    if MinimapCluster then
        MinimapCluster:SetScale(scale)
    end
end

-- Frame references for minimap decorations (supports both old and new WoW versions)
-- NOTE: mail and tracking have special handlers in ApplyDecorationSetting
-- Frame names from MinimapCluster children: BorderTop, InstanceDifficulty, Selection, 
-- MinimapContainer, IndicatorFrame, ZoneTextButton, Tracking
local MINIMAP_DECORATION_FRAMES = {
    zoomButtons = {"MinimapZoomIn", "MinimapZoomOut", "Minimap.ZoomIn", "Minimap.ZoomOut"},
    border = {"MinimapBorder", "MinimapBorderTop", "MinimapCompassTexture"},
    calendar = {"GameTimeFrame"},
    tracking = {},  -- Handled by ApplyTrackingSetting (MinimapCluster.Tracking)
    mail = {},  -- Handled by ApplyMailSetting  
    craftingOrder = {"MiniMapCraftingOrderFrame"},
    instanceDifficulty = {"MiniMapInstanceDifficulty", "GuildInstanceDifficulty"},
    clock = {"TimeManagerClockButton"},
    expansionButton = {"ExpansionLandingPageMinimapButton"},
    zoneText = {},  -- Handled by ApplyZoneTextSetting (MinimapCluster.ZoneTextButton)
    zoneTextBackground = {},  -- Handled by ApplyZoneTextBackgroundSetting (MinimapCluster.BorderTop)
    addonCompartment = {"AddonCompartmentFrame"},
}

-- Store original states for decorations
local storedDecorationStates = {}

-- Get frame by name, supporting dot notation for nested frames and Background textures
local function GetMinimapFrame(frameName)
    -- Try direct global lookup first
    local frame = _G[frameName]
    if frame then return frame end
    
    -- Try dot notation (e.g., "MinimapCluster.TrackingFrame" or "MinimapCluster.ZoneTextButton.Background")
    if frameName:find("%.") then
        local parts = {strsplit(".", frameName)}
        frame = _G[parts[1]]
        for i = 2, #parts do
            if frame then
                -- Try as a key first (for child frames/tables)
                local child = frame[parts[i]]
                if child then
                    frame = child
                else
                    -- Try GetChildren for frames
                    if frame.GetChildren then
                        local children = {frame:GetChildren()}
                        for _, c in ipairs(children) do
                            if c.GetName and c:GetName() and c:GetName():find(parts[i]) then
                                frame = c
                                child = c
                                break
                            end
                        end
                    end
                    -- Also check regions (textures, fontstrings) for "Background"
                    if not child and frame.GetRegions then
                        local regions = {frame:GetRegions()}
                        for _, r in ipairs(regions) do
                            local rname = r.GetName and r:GetName()
                            if rname and rname:find(parts[i]) then
                                frame = r
                                break
                            end
                            -- Check for "Background" texture specifically
                            if parts[i] == "Background" and r.GetObjectType and r:GetObjectType() == "Texture" then
                                local drawLayer = r.GetDrawLayer and r:GetDrawLayer()
                                if drawLayer == "BACKGROUND" then
                                    frame = r
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    return frame
end

-- Hide a minimap decoration element safely (works for frames and textures)
local function HideMinimapDecoration(frameName)
    local element = GetMinimapFrame(frameName)
    if not element then return end
    
    -- Store original state if not already stored
    if storedDecorationStates[frameName] == nil then
        pcall(function()
            storedDecorationStates[frameName] = {
                shown = element.IsShown and element:IsShown() or true,
                alpha = element.GetAlpha and element:GetAlpha() or 1,
            }
        end)
    end
    
    -- Hide using both Hide() and SetAlpha(0) for best compatibility
    pcall(function()
        if element.Hide then element:Hide() end
        if element.SetAlpha then element:SetAlpha(0) end
        
        -- Hook OnShow to keep it hidden (only for frames that support it)
        if element.HookScript and not element.tweaksHideHooked then
            element:HookScript("OnShow", function(self)
                local key = General:GetDecorationKeyForFrame(frameName)
                if key and General:GetMinimapHideSetting(key) then
                    if self.Hide then self:Hide() end
                    if self.SetAlpha then self:SetAlpha(0) end
                end
            end)
            element.tweaksHideHooked = true
        end
    end)
end

-- Show a minimap decoration element
local function ShowMinimapDecoration(frameName)
    local element = GetMinimapFrame(frameName)
    if not element then return end
    
    pcall(function()
        if element.SetAlpha then element:SetAlpha(1) end
        if element.Show then element:Show() end
    end)
end

-- Get decoration key for a frame name
function General:GetDecorationKeyForFrame(frameName)
    for key, frames in pairs(MINIMAP_DECORATION_FRAMES) do
        for _, name in ipairs(frames) do
            if name == frameName then
                return key
            end
        end
    end
    return nil
end

-- Special handler for mail icon - finds and hides the mail indicator specifically
-- When using custom minimap frame, MinimapFrame handles its own custom mail indicator
local function ApplyMailSetting(shouldHide)
    -- If custom minimap frame is enabled, MinimapFrame.lua handles mail indicator
    if TweaksUI.General and TweaksUI.General:GetMinimapSetting("useCustomFrame") then
        if TweaksUI.MinimapFrame and TweaksUI.MinimapFrame.UpdateMailIndicator then
            TweaksUI.MinimapFrame:UpdateMailIndicator()
        end
        return
    end
    
    -- For default Blizzard minimap, control Blizzard's mail frames
    -- Try legacy mail frame references first
    local mailFrames = {
        _G["MiniMapMailFrame"],
        _G["MiniMapMailIcon"],
        _G["MiniMapMailBorder"],
    }
    
    -- Also search MinimapCluster.IndicatorFrame children for mail-related frames
    local indicatorFrame = MinimapCluster and MinimapCluster.IndicatorFrame
    if indicatorFrame and indicatorFrame.GetChildren then
        local children = {indicatorFrame:GetChildren()}
        for _, child in ipairs(children) do
            local name = child.GetName and child:GetName()
            if name and (name:find("Mail") or name:find("mail")) then
                table.insert(mailFrames, child)
            end
        end
        -- Also check for MailFrame key directly
        if indicatorFrame.MailFrame then
            table.insert(mailFrames, indicatorFrame.MailFrame)
        end
    end
    
    for _, frame in ipairs(mailFrames) do
        if frame then
            pcall(function()
                if shouldHide then
                    frame:SetAlpha(0)
                    -- Hook OnShow to keep it hidden
                    if frame.HookScript and not frame.tweaksMailHooked then
                        frame:HookScript("OnShow", function(self)
                            if General:GetMinimapHideSetting("mail") then
                                self:SetAlpha(0)
                            end
                        end)
                        frame.tweaksMailHooked = true
                    end
                else
                    frame:SetAlpha(1)
                end
            end)
        end
    end
end

-- Special handler for tracking button - finds and hides the tracking indicator specifically
local function ApplyTrackingSetting(shouldHide)
    -- Use MinimapCluster.Tracking which is the correct frame from user's WoW client
    local trackingFrame = MinimapCluster and MinimapCluster.Tracking
    
    if trackingFrame then
        pcall(function()
            if shouldHide then
                trackingFrame:SetAlpha(0)
                -- Hook OnShow to keep it hidden
                if trackingFrame.HookScript and not trackingFrame.tweaksTrackingHooked then
                    trackingFrame:HookScript("OnShow", function(self)
                        if General:GetMinimapHideSetting("tracking") then
                            self:SetAlpha(0)
                        end
                    end)
                    trackingFrame.tweaksTrackingHooked = true
                end
            else
                trackingFrame:SetAlpha(1)
            end
        end)
    end
    
    -- Also try legacy frame names
    local legacyFrames = {
        _G["MiniMapTrackingFrame"],
        _G["MiniMapTrackingButton"],
    }
    
    for _, frame in ipairs(legacyFrames) do
        if frame then
            pcall(function()
                if shouldHide then
                    frame:SetAlpha(0)
                else
                    frame:SetAlpha(1)
                end
            end)
        end
    end
end

-- Special handler for zoom buttons (children of Minimap)
-- When using custom minimap frame, MinimapFrame handles its own custom zoom buttons
-- This function is only used when useCustomFrame is OFF
local function ApplyZoomButtonsSetting(shouldHide)
    -- If custom minimap frame is enabled, MinimapFrame.lua handles zoom buttons
    if TweaksUI.General and TweaksUI.General:GetMinimapSetting("useCustomFrame") then
        if TweaksUI.MinimapFrame and TweaksUI.MinimapFrame.UpdateZoomButtonsVisibility then
            TweaksUI.MinimapFrame:UpdateZoomButtonsVisibility()
        end
        return
    end
    
    -- For default Blizzard minimap, control Blizzard's zoom buttons
    local zoomIn = Minimap and Minimap.ZoomIn
    local zoomOut = Minimap and Minimap.ZoomOut
    
    if zoomIn then
        pcall(function()
            zoomIn:SetAlpha(shouldHide and 0 or 1)
        end)
    end
    
    if zoomOut then
        pcall(function()
            zoomOut:SetAlpha(shouldHide and 0 or 1)
        end)
    end
    
    -- Also try legacy frame names
    local legacyZoomIn = _G["MinimapZoomIn"]
    local legacyZoomOut = _G["MinimapZoomOut"]
    
    if legacyZoomIn then
        pcall(function()
            legacyZoomIn:SetAlpha(shouldHide and 0 or 1)
        end)
    end
    
    if legacyZoomOut then
        pcall(function()
            legacyZoomOut:SetAlpha(shouldHide and 0 or 1)
        end)
    end
end

-- Special handler for zone text button
local function ApplyZoneTextSetting(shouldHide)
    -- Use MinimapCluster.ZoneTextButton which is the correct frame
    local zoneTextFrame = MinimapCluster and MinimapCluster.ZoneTextButton
    
    if zoneTextFrame then
        pcall(function()
            if shouldHide then
                zoneTextFrame:SetAlpha(0)
                if zoneTextFrame.HookScript and not zoneTextFrame.tweaksZoneTextHooked then
                    zoneTextFrame:HookScript("OnShow", function(self)
                        if General:GetMinimapHideSetting("zoneText") then
                            self:SetAlpha(0)
                        end
                    end)
                    zoneTextFrame.tweaksZoneTextHooked = true
                end
            else
                zoneTextFrame:SetAlpha(1)
            end
        end)
    end
    
    -- Also try legacy frame name
    local legacyFrame = _G["MinimapZoneTextButton"]
    if legacyFrame then
        pcall(function()
            if shouldHide then
                legacyFrame:SetAlpha(0)
            else
                legacyFrame:SetAlpha(1)
            end
        end)
    end
end

-- Special handler for zone text background (BorderTop)
local function ApplyZoneTextBackgroundSetting(shouldHide)
    -- Use MinimapCluster.BorderTop which is the correct frame
    local borderTopFrame = MinimapCluster and MinimapCluster.BorderTop
    
    if borderTopFrame then
        pcall(function()
            if shouldHide then
                borderTopFrame:SetAlpha(0)
                if borderTopFrame.HookScript and not borderTopFrame.tweaksBorderTopHooked then
                    borderTopFrame:HookScript("OnShow", function(self)
                        if General:GetMinimapHideSetting("zoneTextBackground") then
                            self:SetAlpha(0)
                        end
                    end)
                    borderTopFrame.tweaksBorderTopHooked = true
                end
            else
                borderTopFrame:SetAlpha(1)
            end
        end)
    end
end

-- Special handler for expansion landing page button
local function ApplyExpansionButtonSetting(shouldHide)
    local expansionButton = ExpansionLandingPageMinimapButton
    
    if expansionButton then
        pcall(function()
            if shouldHide then
                expansionButton:SetAlpha(0)
                -- Disable mouse to prevent invisible clicking
                if expansionButton.EnableMouse then
                    expansionButton:EnableMouse(false)
                end
                if expansionButton.HookScript and not expansionButton.tweaksExpansionHooked then
                    expansionButton:HookScript("OnShow", function(self)
                        if General:GetMinimapHideSetting("expansionButton") then
                            self:SetAlpha(0)
                            if self.EnableMouse then
                                self:EnableMouse(false)
                            end
                        end
                    end)
                    expansionButton.tweaksExpansionHooked = true
                end
            else
                -- Force show and restore
                if not expansionButton:IsShown() then
                    expansionButton:Show()
                end
                expansionButton:SetAlpha(1)
                if expansionButton.EnableMouse then
                    expansionButton:EnableMouse(true)
                end
            end
        end)
    end
end

-- Apply a single decoration hide setting
function General:ApplyDecorationSetting(key)
    -- Note: decoration visibility settings work regardless of useCustomFrame
    -- This allows users to hide/show mail, zoom buttons, etc. even with Blizzard's default minimap
    
    if self:IsLeatrixManaging("decorations") then return end
    
    local shouldHide = self:GetMinimapHideSetting(key)
    
    -- Special handlers for problematic frames
    if key == "mail" then
        ApplyMailSetting(shouldHide)
        return
    elseif key == "tracking" then
        ApplyTrackingSetting(shouldHide)
        return
    elseif key == "zoomButtons" then
        ApplyZoomButtonsSetting(shouldHide)
        return
    elseif key == "zoneText" then
        ApplyZoneTextSetting(shouldHide)
        return
    elseif key == "zoneTextBackground" then
        ApplyZoneTextBackgroundSetting(shouldHide)
        return
    elseif key == "expansionButton" then
        ApplyExpansionButtonSetting(shouldHide)
        return
    elseif key == "border" then
        -- Border only works with custom frame
        if not self:GetMinimapSetting("useCustomFrame") then
            return
        end
        -- Special handling for border - always hide Blizzard border if square minimap
        local isSquare = self:GetMinimapSetting("squareShape")
        local borderFrames = {"MinimapBorder", "MinimapBorderTop", "MinimapCompassTexture"}
        
        if isSquare then
            -- ALWAYS hide Blizzard border when square
            for _, frameName in ipairs(borderFrames) do
                HideMinimapDecoration(frameName)
            end
            -- Show/hide custom border based on setting
            if shouldHide then
                if customMinimapBorder then
                    customMinimapBorder:Hide()
                end
            else
                self:CreateCustomMinimapBorder()
                customMinimapBorder:Show()
            end
        else
            -- Circular - hide custom border, show/hide Blizzard based on setting
            if customMinimapBorder then
                customMinimapBorder:Hide()
            end
            for _, frameName in ipairs(borderFrames) do
                if shouldHide then
                    HideMinimapDecoration(frameName)
                else
                    ShowMinimapDecoration(frameName)
                end
            end
        end
        return
    end
    
    -- For other decorations, only apply if using custom frame
    if not self:GetMinimapSetting("useCustomFrame") then
        return
    end
    
    local frames = MINIMAP_DECORATION_FRAMES[key]
    if not frames then return end
    
    for _, frameName in ipairs(frames) do
        if shouldHide then
            HideMinimapDecoration(frameName)
        else
            ShowMinimapDecoration(frameName)
        end
    end
end

-- Apply all minimap settings
function General:ApplyAllMinimapSettings()
    -- Only apply minimap modifications if useCustomFrame is enabled
    -- When OFF, leave Blizzard's minimap completely alone
    if not self:GetMinimapSetting("useCustomFrame") then
        return
    end
    
    -- If custom frame is active, refresh it instead
    if TweaksUI.MinimapFrame and TweaksUI.MinimapFrame:IsEnabled() then
        TweaksUI.MinimapFrame:Refresh()
        return
    end
    
    -- Shape
    self:ApplyMinimapShape()
    
    -- Scale
    self:ApplyMinimapScale()
    
    -- Decorations (skip if Leatrix is managing)
    if not self:IsLeatrixManaging("decorations") then
        for key, _ in pairs(MINIMAP_DECORATION_FRAMES) do
            self:ApplyDecorationSetting(key)
        end
    end
    
    TweaksUI:PrintDebug("General: Minimap settings applied")
end

-- Apply only the special decoration settings that work regardless of useCustomFrame
-- These are: mail, tracking, zoomButtons, zoneText, zoneTextBackground
function General:ApplySpecialDecorationSettings()
    if self:IsLeatrixManaging("decorations") then return end
    
    local specialKeys = {"mail", "tracking", "zoomButtons", "zoneText", "zoneTextBackground", "expansionButton"}
    for _, key in ipairs(specialKeys) do
        self:ApplyDecorationSetting(key)
    end
    
    TweaksUI:PrintDebug("General: Special decoration settings applied")
end

-- ============================================================================
-- MINIMAP BUTTON COLLECTOR
-- ============================================================================

-- Buttons to ignore (Blizzard default buttons - not addon buttons)
-- Blizzard frames to always ignore (these are NOT addon buttons)
local IGNORE_BUTTONS = {
    -- Blizzard minimap elements
    ["MinimapBackdrop"] = true,
    ["MinimapBorder"] = true,
    ["MinimapBorderTop"] = true,
    ["MinimapZoomIn"] = true,
    ["MinimapZoomOut"] = true,
    ["MinimapZoneTextButton"] = true,
    ["MiniMapWorldMapButton"] = true,
    ["GameTimeFrame"] = true,
    ["TimeManagerClockButton"] = true,
    ["MiniMapMailFrame"] = true,
    ["MiniMapMailBorder"] = true,
    ["MiniMapMailIcon"] = true,
    ["MiniMapTracking"] = true,
    ["MiniMapTrackingButton"] = true,
    ["MiniMapTrackingFrame"] = true,
    ["MiniMapInstanceDifficulty"] = true,
    ["GuildInstanceDifficulty"] = true,
    ["MiniMapChallengeMode"] = true,
    ["MinimapCompassTexture"] = true,
    ["QueueStatusMinimapButton"] = true,
    ["GarrisonLandingPageMinimapButton"] = true,
    ["ExpansionLandingPageMinimapButton"] = true,
    ["MiniMapCraftingOrderFrame"] = true,
    ["Minimap"] = true,
    ["MinimapCluster"] = true,
    -- TweaksUI frames that are NOT buttons
    ["TweaksUI_ButtonDrawer"] = true,
    ["TweaksUI_Minimap_Panel"] = true,
    ["TweaksUI_Minimap_Panel_ScrollFrame"] = true,
    ["TweaksUI_MinimapBorder"] = true,
    ["TweaksUI_General_Hub"] = true,
    ["TweaksUI_DrawerPosDropdown"] = true,
}

-- Check if a frame is a valid addon minimap button
local function IsAddonMinimapButton(frame)
    if not frame then return false end
    
    local name = frame:GetName()
    if not name then return false end
    
    -- Always ignore specific frames
    if IGNORE_BUTTONS[name] then return false end
    
    -- Must be a Button type (addon minimap buttons are always Buttons)
    local frameType = frame:GetObjectType()
    if frameType ~= "Button" then return false end
    
    -- Check parent - must be parented to minimap-related frames
    local parent = frame:GetParent()
    local validParent = parent == Minimap or parent == MinimapCluster or parent == MinimapBackdrop
    if not validParent then return false end
    
    -- Ignore Blizzard UI patterns by name
    local lowerName = name:lower()
    if lowerName:find("instancedifficulty") or 
       lowerName:find("indicatorframe") or
       lowerName:find("difficulty") or
       lowerName:find("challengemode") or
       lowerName:find("tracking") or
       lowerName:find("garrison") or
       lowerName:find("expansion") or
       lowerName:find("queue") or
       lowerName:find("mail") or
       lowerName:find("zoom") then
        return false
    end
    
    -- Check if it has an icon (addon buttons have icons)
    local hasIcon = frame.icon or 
                   (frame.GetNormalTexture and frame:GetNormalTexture()) or
                   (frame.Icon and type(frame.Icon) == "table")
    
    -- Check for textures if no icon property
    if not hasIcon and frame.GetRegions then
        local regions = {frame:GetRegions()}
        for _, region in ipairs(regions) do
            if region:GetObjectType() == "Texture" and region:GetTexture() then
                hasIcon = true
                break
            end
        end
    end
    
    if not hasIcon then return false end
    
    -- Size check - addon buttons are typically 24-40 pixels
    local width = frame:GetWidth()
    local height = frame:GetHeight()
    if width and height then
        if width < 20 or width > 50 or height < 20 or height > 50 then
            return false
        end
    end
    
    return true
end

-- Find all addon minimap buttons
function General:FindMinimapButtons()
    local buttons = {}
    
    -- Method 1: Check LibDBIcon library directly (most reliable for LibDBIcon users)
    local LibDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
    if LibDBIcon and LibDBIcon.objects then
        for addonName, button in pairs(LibDBIcon.objects) do
            if button and button:GetName() and button:IsObjectType("Button") then
                local name = button:GetName()
                if not IGNORE_BUTTONS[name] then
                    buttons[name] = button
                end
            end
        end
    end
    
    -- Method 2: Check children of Minimap (catches non-LibDBIcon buttons like ours)
    if Minimap and Minimap.GetChildren then
        local children = {Minimap:GetChildren()}
        for _, child in ipairs(children) do
            if IsAddonMinimapButton(child) then
                local name = child:GetName()
                if name and not buttons[name] then
                    buttons[name] = child
                end
            end
        end
    end
    
    -- Method 3: Check children of MinimapBackdrop
    if MinimapBackdrop and MinimapBackdrop.GetChildren then
        local children = {MinimapBackdrop:GetChildren()}
        for _, child in ipairs(children) do
            if IsAddonMinimapButton(child) then
                local name = child:GetName()
                if name and not buttons[name] then
                    buttons[name] = child
                end
            end
        end
    end
    
    return buttons
end

-- Create the button popup frame
function General:CreateButtonDrawer()
    if buttonDrawer then return buttonDrawer end
    
    buttonDrawer = CreateFrame("Frame", "TweaksUI_ButtonDrawer", Minimap, "BackdropTemplate")
    buttonDrawer:SetFrameStrata("DIALOG")
    buttonDrawer:SetFrameLevel(100)
    buttonDrawer:SetClampedToScreen(true)
    
    buttonDrawer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    buttonDrawer:SetBackdropColor(0.05, 0.05, 0.05, 0.92)
    buttonDrawer:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    
    -- Right-click to close - BUT only if clicking the drawer background, not a button
    buttonDrawer:EnableMouse(true)
    buttonDrawer:SetScript("OnMouseUp", function(self, btn)
        if btn == "RightButton" then
            -- Check if mouse is over the drawer itself, not a child button
            -- Use GetMouseFoci (Midnight) or GetMouseFocus (legacy)
            local focus
            if GetMouseFoci then
                local foci = GetMouseFoci()
                focus = foci and foci[1]
            end
            -- Only close if clicking the drawer background directly
            -- If focus is a button inside, let the button handle the click
            -- Also close if we can't determine focus (safest behavior)
            if focus == nil or focus == buttonDrawer then
                buttonDrawer:Hide()
            end
        end
    end)
    
    -- Hide buttons when drawer hides
    buttonDrawer:SetScript("OnHide", function()
        for name, button in pairs(collectedButtons) do
            if button then
                pcall(function() button:Hide() end)
            end
        end
    end)
    
    -- Create empty text (shown when no buttons)
    buttonDrawer.emptyText = buttonDrawer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    buttonDrawer.emptyText:SetPoint("CENTER", buttonDrawer, "CENTER", 0, 0)
    buttonDrawer.emptyText:SetText("No addon buttons")
    buttonDrawer.emptyText:SetTextColor(0.5, 0.5, 0.5)
    buttonDrawer.emptyText:Hide()
    
    buttonDrawer:Hide()
    
    return buttonDrawer
end

-- Position buttons in the popup and resize to fit
function General:LayoutDrawerButtons()
    if not buttonDrawer then return end
    
    local buttonSize = 32  -- Standard minimap button size
    local padding = 4
    local margin = 6
    
    -- Count buttons
    local count = 0
    for name, button in pairs(collectedButtons) do
        if button then
            count = count + 1
        end
    end
    
    -- Handle empty state
    if count == 0 then
        buttonDrawer:SetSize(120, 40)
        buttonDrawer.emptyText:Show()
        return
    else
        buttonDrawer.emptyText:Hide()
    end
    
    -- Calculate grid: aim for roughly square, max 6 per row
    local buttonsPerRow = math.min(count, 6)
    if count > 6 then
        buttonsPerRow = math.ceil(math.sqrt(count))
        if buttonsPerRow > 6 then buttonsPerRow = 6 end
    end
    local rows = math.ceil(count / buttonsPerRow)
    
    -- Calculate popup size
    local popupWidth = (buttonsPerRow * buttonSize) + ((buttonsPerRow - 1) * padding) + (margin * 2)
    local popupHeight = (rows * buttonSize) + ((rows - 1) * padding) + (margin * 2)
    buttonDrawer:SetSize(popupWidth, popupHeight)
    
    -- Position buttons in grid
    local i = 0
    for name, button in pairs(collectedButtons) do
        if button then
            local row = math.floor(i / buttonsPerRow)
            local col = i % buttonsPerRow
            
            local x = margin + (col * (buttonSize + padding)) + (buttonSize / 2)
            local y = -margin - (row * (buttonSize + padding)) - (buttonSize / 2)
            
            -- Reparent to UIParent to escape minimap mask, then anchor to drawer
            button:SetParent(UIParent)
            button:ClearAllPoints()
            button:SetPoint("CENTER", buttonDrawer, "TOPLEFT", x, y)
            button:SetFrameStrata("TOOLTIP")
            button:SetAlpha(1)
            button:EnableMouse(true)
            button:Show()
            
            -- Force show all regions (textures, fontstrings)
            pcall(function()
                for _, region in pairs({button:GetRegions()}) do
                    region:SetAlpha(1)
                    region:Show()
                end
            end)
            
            -- Force show all child frames
            pcall(function()
                for _, child in pairs({button:GetChildren()}) do
                    child:SetAlpha(1)
                    child:Show()
                    -- And their regions
                    for _, region in pairs({child:GetRegions()}) do
                        region:SetAlpha(1)
                        region:Show()
                    end
                end
            end)
            
            -- NOTE: We intentionally do NOT hook right-click to close the drawer
            -- This allows addon buttons to have their own right-click menus (DBM, Details, etc.)
            -- Users can right-click the drawer background to close it
            
            i = i + 1
        end
    end
end

-- Collect buttons into drawer
function General:CollectMinimapButtons()
    if self:IsLeatrixManaging("buttonCollector") then return end
    
    local buttons = self:FindMinimapButtons()
    local newButtonsFound = false
    
    for name, button in pairs(buttons) do
        if not collectedButtons[name] then
            -- Store original position
            if not originalButtonPositions[name] then
                local point, relativeTo, relativePoint, x, y = button:GetPoint(1)
                originalButtonPositions[name] = {
                    point = point,
                    relativeTo = relativeTo,
                    relativePoint = relativePoint,
                    x = x,
                    y = y,
                    parent = button:GetParent(),
                    width = button:GetWidth(),
                    height = button:GetHeight(),
                    strata = button:GetFrameStrata(),
                    level = button:GetFrameLevel(),
                }
            end
            
            collectedButtons[name] = button
            button:Hide()  -- Hide from minimap immediately
            newButtonsFound = true
        end
    end
    
    -- Only layout if drawer is visible and we found new buttons
    if newButtonsFound and buttonDrawer and buttonDrawer:IsShown() then
        self:LayoutDrawerButtons()
    end
end

-- Restore buttons to original positions
function General:RestoreMinimapButtons()
    for name, button in pairs(collectedButtons) do
        local original = originalButtonPositions[name]
        if original and button then
            pcall(function()
                button:SetParent(original.parent or Minimap)
                button:ClearAllPoints()
                button:SetPoint(original.point or "TOPLEFT", original.relativeTo or Minimap, original.relativePoint or "TOPLEFT", original.x or 0, original.y or 0)
                if original.strata then
                    button:SetFrameStrata(original.strata)
                end
                if original.level then
                    button:SetFrameLevel(original.level)
                end
                button:Show()
            end)
        end
    end
    
    collectedButtons = {}
    originalButtonPositions = {}
    
    if buttonDrawer then
        buttonDrawer:Hide()
    end
end

-- Toggle drawer visibility
function General:ToggleButtonDrawer()
    if not buttonDrawer then
        self:CreateButtonDrawer()
    end
    
    if buttonDrawer:IsShown() then
        buttonDrawer:Hide()
    else
        -- Refresh buttons and layout first (to calculate size)
        self:CollectMinimapButtons()
        self:LayoutDrawerButtons()
        
        -- Get position setting (default to left)
        local position = self:GetButtonCollectorSetting("drawerPosition") or "left"
        
        -- Position popup based on setting
        buttonDrawer:ClearAllPoints()
        if position == "top" then
            buttonDrawer:SetPoint("BOTTOM", Minimap, "TOP", 0, 4)
        elseif position == "bottom" then
            buttonDrawer:SetPoint("TOP", Minimap, "BOTTOM", 0, -4)
        elseif position == "right" then
            buttonDrawer:SetPoint("LEFT", Minimap, "RIGHT", 4, 0)
        else  -- "left" (default)
            buttonDrawer:SetPoint("RIGHT", Minimap, "LEFT", -4, 0)
        end
        
        buttonDrawer:Show()
    end
end

-- Get button collector setting
function General:GetButtonCollectorSetting(key)
    if settings and settings.minimapSettings and settings.minimapSettings.buttonCollector then
        return settings.minimapSettings.buttonCollector[key]
    end
    return DEFAULTS.minimapSettings.buttonCollector[key]
end

-- Set button collector setting
function General:SetButtonCollectorSetting(key, value)
    if settings then
        settings.minimapSettings = settings.minimapSettings or {}
        settings.minimapSettings.buttonCollector = settings.minimapSettings.buttonCollector or {}
        settings.minimapSettings.buttonCollector[key] = value
    end
end

-- Setup minimap right-click handler
function General:SetupButtonCollector()
    if self:IsLeatrixManaging("buttonCollector") then return end
    
    -- Hook minimap right-click
    if not Minimap.tweaksRightClickHooked then
        Minimap:SetScript("OnMouseUp", function(self, button)
            if button == "RightButton" then
                if General:GetButtonCollectorSetting("enabled") and not General:IsLeatrixManaging("buttonCollector") then
                    General:ToggleButtonDrawer()
                else
                    -- Default behavior - show tracking menu
                    if MinimapCluster and MinimapCluster.Tracking and MinimapCluster.Tracking.Button then
                        MinimapCluster.Tracking.Button:Click()
                    elseif MiniMapTrackingButton then
                        MiniMapTrackingButton:Click()
                    end
                end
            end
        end)
        Minimap.tweaksRightClickHooked = true
    end
end

-- Apply button collector settings
function General:ApplyButtonCollector()
    -- Only apply minimap modifications if useCustomFrame is enabled
    -- When OFF, leave Blizzard's minimap completely alone
    if not self:GetMinimapSetting("useCustomFrame") then
        return
    end
    
    if self:IsLeatrixManaging("buttonCollector") then 
        -- Restore buttons if Leatrix takes over
        self:RestoreMinimapButtons()
        self:StopButtonScanning()
        return 
    end
    
    local enabled = self:GetButtonCollectorSetting("enabled")
    
    if enabled then
        -- Immediately collect any existing buttons
        self:CollectMinimapButtons()
        
        -- Start aggressive scanning for new buttons during load
        self:StartButtonScanning()
    else
        self:RestoreMinimapButtons()
        self:StopButtonScanning()
    end
end

-- Scanning frame for catching buttons as they're created
local buttonScanFrame = nil
local scanEndTime = 0
local scanThrottle = 0

function General:StartButtonScanning()
    if not buttonScanFrame then
        buttonScanFrame = CreateFrame("Frame")
    end
    
    -- Scan for 3 seconds after enable
    scanEndTime = GetTime() + 3
    scanThrottle = 0
    
    buttonScanFrame:SetScript("OnUpdate", function(self, elapsed)
        if GetTime() > scanEndTime then
            General:StopButtonScanning()
            return
        end
        
        -- Throttle to every 0.05 seconds (20 times per second)
        scanThrottle = scanThrottle + elapsed
        if scanThrottle >= 0.05 then
            scanThrottle = 0
            General:CollectMinimapButtons()
        end
    end)
end

function General:StopButtonScanning()
    if buttonScanFrame then
        buttonScanFrame:SetScript("OnUpdate", nil)
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function General:Initialize()
    -- Get settings from profile database
    settings = TweaksUI.Database:GetModuleSettings(TweaksUI.MODULE_IDS.GENERAL)
    
    -- Check if we need to migrate from old TweaksUI_DB.general storage
    if (not settings or not next(settings)) and TweaksUI_DB and TweaksUI_DB.general and next(TweaksUI_DB.general) then
        TweaksUI:PrintDebug("General: Migrating settings from TweaksUI_DB.general to profile")
        -- Deep copy old settings
        settings = {}
        for key, value in pairs(TweaksUI_DB.general) do
            if type(value) == "table" then
                settings[key] = DeepCopy(value)
            else
                settings[key] = value
            end
        end
        TweaksUI.Database:SetModuleSettings(TweaksUI.MODULE_IDS.GENERAL, settings)
        -- Clear old storage after migration
        TweaksUI_DB.general = nil
    end
    
    -- Initialize with empty table if still nil
    if not settings then
        settings = {}
        TweaksUI.Database:SetModuleSettings(TweaksUI.MODULE_IDS.GENERAL, settings)
    end
    
    -- Ensure visibility table exists
    settings.visibility = settings.visibility or {}
    
    -- Initialize defaults for each frame
    for frameKey, _ in pairs(VISIBILITY_FRAMES) do
        if not settings.visibility[frameKey] then
            settings.visibility[frameKey] = GetDefaultVisibilitySettings()
        else
            -- Ensure all keys exist
            local defaults = GetDefaultVisibilitySettings()
            for key, value in pairs(defaults) do
                if settings.visibility[frameKey][key] == nil then
                    settings.visibility[frameKey][key] = value
                end
            end
        end
    end
    
    -- Initialize other defaults
    for key, value in pairs(DEFAULTS) do
        if key ~= "visibility" and key ~= "minimapSettings" and key ~= "mediaSettings" and settings[key] == nil then
            settings[key] = value
        end
    end
    
    -- Initialize mediaSettings with deep copy of defaults
    settings.mediaSettings = settings.mediaSettings or {}
    for key, value in pairs(DEFAULTS.mediaSettings) do
        if settings.mediaSettings[key] == nil then
            settings.mediaSettings[key] = value
        end
    end
    
    -- Initialize minimapSettings with deep copy of defaults
    settings.minimapSettings = settings.minimapSettings or {}
    settings.minimapSettings.hide = settings.minimapSettings.hide or {}
    settings.minimapSettings.customBorder = settings.minimapSettings.customBorder or {}
    settings.minimapSettings.buttonCollector = settings.minimapSettings.buttonCollector or {}
    
    for key, value in pairs(DEFAULTS.minimapSettings) do
        if key == "hide" then
            for hideKey, hideValue in pairs(value) do
                if settings.minimapSettings.hide[hideKey] == nil then
                    settings.minimapSettings.hide[hideKey] = hideValue
                end
            end
        elseif key == "customBorder" then
            -- Deep copy customBorder defaults
            for borderKey, borderValue in pairs(value) do
                if settings.minimapSettings.customBorder[borderKey] == nil then
                    if type(borderValue) == "table" then
                        settings.minimapSettings.customBorder[borderKey] = {}
                        for k, v in pairs(borderValue) do
                            settings.minimapSettings.customBorder[borderKey][k] = v
                        end
                    else
                        settings.minimapSettings.customBorder[borderKey] = borderValue
                    end
                end
            end
        elseif key == "buttonCollector" then
            -- Deep copy buttonCollector defaults
            for bcKey, bcValue in pairs(value) do
                if settings.minimapSettings.buttonCollector[bcKey] == nil then
                    settings.minimapSettings.buttonCollector[bcKey] = bcValue
                end
            end
        elseif settings.minimapSettings[key] == nil then
            settings.minimapSettings[key] = value
        end
    end
    
    -- Check for Leatrix Plus conflicts
    self:CheckLeatrixConflicts()
    
    C_Timer.After(0.5, function()
        self:ApplyAllVisibility()
        self:UpdateMouseoverHitFrames()
    end)
    
    -- Minimap handling: ONLY touch minimap if useCustomFrame is enabled
    if self:GetMinimapSetting("useCustomFrame") then
        if TweaksUI.MinimapFrame then
            TweaksUI.MinimapFrame:Initialize()
            C_Timer.After(0.5, function()
                TweaksUI.MinimapFrame:Enable()
                -- Apply special decoration settings AFTER minimap frame is enabled
                -- This ensures zoom buttons etc. are properly shown after reparenting
                C_Timer.After(0.1, function()
                    self:ApplySpecialDecorationSettings()
                end)
            end)
        end
        
        -- Setup button collector (only when custom frame is enabled)
        self:SetupButtonCollector()
        self:ApplyButtonCollector()
    else
        -- When useCustomFrame is OFF, apply special decoration settings directly
        -- These work on Blizzard's default minimap
        C_Timer.After(0.3, function()
            self:ApplySpecialDecorationSettings()
        end)
    end
    
    -- Objective Tracker positioning DISABLED - let Blizzard Edit Mode handle it
    -- The Initialize function now returns early without doing anything
    if TweaksUI.ObjectiveTrackerFrame then
        C_Timer.After(1.0, function()
            TweaksUI.ObjectiveTrackerFrame:Initialize()
        end)
    end
    
    self:SetupVisibilityUpdater()
    
    -- Apply Blizzard buff/debuff hiding (with delay to ensure frames exist)
    C_Timer.After(0.5, function()
        self:ApplyBlizzardBuffDebuffVisibility()
    end)
    
    -- Initialize Character Panel enhancements
    if TweaksUI.CharacterPanel then
        TweaksUI.CharacterPanel:Initialize()
        if self:GetSetting("characterPanelEnabled") then
            C_Timer.After(0.5, function()
                TweaksUI.CharacterPanel:Enable()
            end)
        else
            -- Feature is OFF - ensure any stale elements are cleaned up
            C_Timer.After(0.5, function()
                if TweaksUI.CharacterPanel.ForceCleanup then
                    TweaksUI.CharacterPanel:ForceCleanup()
                end
            end)
        end
    end
    
    -- AFK Mode disabled due to mouse interaction bugs after exiting AFK
    -- self:SetupAFKMode()
    self:SetupMerchantHandler()
    self:SetupRotationMonitor()
    self:SetupSlashCommands()
    self:CreateMinimapButton()
    self:SetupLeatrixWatcher()
    
    TweaksUI:PrintDebug("General module initialized")
end

-- ============================================================================
-- LEATRIX PLUS LATE-LOAD WATCHER
-- ============================================================================

-- Watch for Leatrix Plus loading after TweaksUI
-- This handles the case where Leatrix loads later due to alphabetical order
function General:SetupLeatrixWatcher()
    -- If Leatrix is already loaded, we've already checked in Initialize
    if IsLeatrixPlusLoaded() then
        return
    end
    
    -- Create watcher frame for ADDON_LOADED
    local watcherFrame = CreateFrame("Frame")
    watcherFrame:RegisterEvent("ADDON_LOADED")
    watcherFrame:SetScript("OnEvent", function(self, event, addonName)
        if addonName == "Leatrix_Plus" then
            TweaksUI:PrintDebug("General: Leatrix Plus loaded after TweaksUI, rechecking conflicts...")
            
            -- Small delay to let Leatrix initialize its database
            C_Timer.After(0.5, function()
                -- Recheck conflicts
                General:CheckLeatrixConflicts()
                
                -- Disable any features Leatrix now manages
                General:DisableLeatrixConflictingFeatures()
                
                -- Notify user
                local conflicts = General:GetLeatrixConflicts()
                if conflicts and next(conflicts) then
                    local features = {}
                    if conflicts.autoRepair then table.insert(features, "Auto Repair") end
                    if conflicts.autoSellJunk then table.insert(features, "Auto Sell Junk") end
                    if conflicts.squareMinimap then table.insert(features, "Square Minimap") end
                    if conflicts.minimapScale then table.insert(features, "Minimap Scale") end
                    if conflicts.decorations then table.insert(features, "Minimap Decorations") end
                    if conflicts.buttonCollector then table.insert(features, "Button Collector") end
                    
                    if #features > 0 then
                        TweaksUI:Print("|cffff9900Leatrix Plus detected.|r Disabled TweaksUI features: " .. table.concat(features, ", "))
                    end
                end
            end)
            
            -- Unregister - we only need to catch this once
            self:UnregisterEvent("ADDON_LOADED")
        end
    end)
end

-- Disable features that Leatrix is now managing
function General:DisableLeatrixConflictingFeatures()
    local conflicts = self:GetLeatrixConflicts()
    if not conflicts then return end
    
    -- Square Minimap - restore to round if Leatrix took over
    if conflicts.squareMinimap then
        -- Don't apply our shape anymore
        if Minimap then
            Minimap:SetMaskTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        end
        if customMinimapBorder then
            customMinimapBorder:Hide()
        end
    end
    
    -- Minimap Scale - let Leatrix handle it
    if conflicts.minimapScale then
        -- Restore default scale
        if Minimap then
            Minimap:SetScale(1)
        end
    end
    
    -- Decorations - show them all, let Leatrix manage
    if conflicts.decorations then
        for key, _ in pairs(MINIMAP_DECORATION_FRAMES) do
            ShowMinimapDecoration(key)
        end
    end
    
    -- Button Collector - restore buttons if we collected them
    if conflicts.buttonCollector then
        self:RestoreMinimapButtons()
    end
    
    TweaksUI:PrintDebug("General: Disabled conflicting features for Leatrix Plus")
end

-- ============================================================================
-- SLASH COMMANDS
-- ============================================================================

function General:SetupSlashCommands()
    -- /rl - Reload UI
    SLASH_TWEAKSUI_RL1 = "/rl"
    SlashCmdList["TWEAKSUI_RL"] = function()
        ReloadUI()
    end
    
    -- /em - Edit Mode helper
    -- NOTE: In Midnight, programmatically showing EditModeManagerFrame from addon code
    -- causes taint that blocks protected functions like FocusUnit(). The only safe way
    -- to open Edit Mode is through Blizzard's own UI (ESC menu or keybind).
    SLASH_TWEAKSUI_EM1 = "/em"
    SlashCmdList["TWEAKSUI_EM"] = function()
        print("|cff00ff00TweaksUI:|r To open Edit Mode:")
        print("  |cffffd100Option 1:|r Press |cff00ccffESC|r > Click |cff00ccffEdit Mode|r")
        print("  |cffffd100Option 2:|r Set a keybind in |cff00ccffOptions > Keybindings > Miscellaneous|r")
        print("|cff888888(Direct addon access causes taint issues in Midnight)|r")
    end
    
    -- /cdm - Open Blizzard Cooldown Manager Settings
    SLASH_TWEAKSUI_CDM1 = "/cdm"
    SlashCmdList["TWEAKSUI_CDM"] = function()
        -- CooldownViewerSettings is Blizzard's Cooldown Settings frame
        local cooldownFrame = CooldownViewerSettings or _G["CooldownViewerSettings"]
        
        if cooldownFrame then
            if cooldownFrame:IsShown() then
                cooldownFrame:Hide()
            else
                cooldownFrame:Show()
            end
        else
            print("|cff00ff00TweaksUI:|r Cooldown Settings not available.")
        end
    end
    
    -- /tuiresetminimap - Reset minimap settings to defaults
    SLASH_TWEAKSUI_RESETMINIMAP1 = "/tuiresetminimap"
    SlashCmdList["TWEAKSUI_RESETMINIMAP"] = function()
        General:ResetMinimapSettings()
    end
    
    -- /tuiresetdecorations - Reset minimap decoration positions
    SLASH_TWEAKSUI_RESETDECORATIONS1 = "/tuiresetdecorations"
    SlashCmdList["TWEAKSUI_RESETDECORATIONS"] = function()
        if TweaksUI.MinimapFrame then
            TweaksUI.MinimapFrame:ResetDecorationPositions()
        end
    end
    
    -- /tuiresetbuffs - Reset buff tracker visibility settings
    SLASH_TWEAKSUI_RESETBUFFS1 = "/tuiresetbuffs"
    SlashCmdList["TWEAKSUI_RESETBUFFS"] = function()
        -- Reset PersonalResources buff visibility
        if TweaksUIDB and TweaksUIDB.profiles then
            local profile = TweaksUIDB.profiles[TweaksUIDB.currentProfile or "Default"]
            if profile and profile.PersonalResources then
                if profile.PersonalResources.buffs then
                    profile.PersonalResources.buffs.visibilityEnabled = false
                    print("|cff00ff00TweaksUI:|r Reset Personal Resources buff visibility to OFF")
                end
                if profile.PersonalResources.debuffs then
                    profile.PersonalResources.debuffs.visibilityEnabled = false
                    print("|cff00ff00TweaksUI:|r Reset Personal Resources debuff visibility to OFF")
                end
            end
        end
        print("|cff00ff00TweaksUI:|r Use /rl to reload and apply changes")
    end
    
    -- /tuiresetpr - Reset all PersonalResources visibility settings
    SLASH_TWEAKSUI_RESETPR1 = "/tuiresetpr"
    SlashCmdList["TWEAKSUI_RESETPR"] = function()
        if TweaksUIDB and TweaksUIDB.profiles then
            local profile = TweaksUIDB.profiles[TweaksUIDB.currentProfile or "Default"]
            if profile and profile.PersonalResources then
                -- Reset all visibility settings
                local elements = {"health", "power", "class", "soul", "stagger", "buffs", "debuffs"}
                for _, element in ipairs(elements) do
                    if profile.PersonalResources[element] then
                        profile.PersonalResources[element].visibilityEnabled = false
                    end
                end
                print("|cff00ff00TweaksUI:|r Reset all Personal Resources visibility settings to OFF")
                print("|cff00ff00TweaksUI:|r Use /rl to reload and apply changes")
            else
                print("|cff00ff00TweaksUI:|r No PersonalResources settings found")
            end
        end
    end
end

-- ============================================================================
-- MINIMAP BUTTON (LibDBIcon)
-- ============================================================================

function General:CreateMinimapButton()
    -- Check if button already exists (reload safety)
    if _G["TweaksUI_MinimapButton"] then
        minimapButton = _G["TweaksUI_MinimapButton"]
        -- Re-hook the click handler on reload
        minimapButton:SetScript("OnClick", function(self, btn)
            if TweaksUI and TweaksUI.ToggleSettings then
                TweaksUI:ToggleSettings()
            end
        end)
        return
    end
    
    -- Ensure minimap settings exist
    settings.minimap = settings.minimap or {}
    local savedPos = settings.minimap.minimapPos or 225
    
    -- Create the button
    local button = CreateFrame("Button", "TweaksUI_MinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("AnyUp")
    button:RegisterForDrag("LeftButton")
    
    -- Position function
    local function UpdatePosition(pos)
        local radian = math.rad(pos)
        local radius = (Minimap:GetWidth() / 2) + 5
        local x = math.cos(radian) * radius
        local y = math.sin(radian) * radius
        button:ClearAllPoints()
        button:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end
    UpdatePosition(savedPos)
    
    -- Create textures matching other minimap buttons
    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT", 0, 0)
    
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetPoint("TOPLEFT", 7, -5)
    
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetTexture("Interface\\AddOns\\!TweaksUI\\Media\\Textures\\TweaksUI_Icon.tga")
    icon:SetPoint("TOPLEFT", 7, -6)
    button.icon = icon
    
    -- No highlight texture - keeps button stable on hover
    
    -- Click handler
    button:SetScript("OnClick", function(self, btn)
        if TweaksUI and TweaksUI.ToggleSettings then
            TweaksUI:ToggleSettings()
        end
    end)
    
    -- Tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("TweaksUI", 1, 0.82, 0)
        GameTooltip:AddLine("|cffffffffClick:|r Open Settings", 1, 1, 1)
        GameTooltip:AddLine("|cffffffffDrag:|r Move Button", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    
    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    -- Dragging
    button:SetScript("OnDragStart", function(self)
        self.isDragging = true
    end)
    
    button:SetScript("OnDragStop", function(self)
        self.isDragging = false
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        px, py = px / scale, py / scale
        local pos = math.deg(math.atan2(py - my, px - mx)) % 360
        settings.minimap.minimapPos = pos
        UpdatePosition(pos)
    end)
    
    button:SetScript("OnUpdate", function(self)
        if self.isDragging then
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            px, py = px / scale, py / scale
            local pos = math.deg(math.atan2(py - my, px - mx)) % 360
            UpdatePosition(pos)
        end
    end)
    
    minimapButton = button
    
    -- Apply visibility setting
    if settings.hideMinimapButton then
        button:Hide()
    end
    
    TweaksUI:PrintDebug("General: Custom minimap button created")
end

function General:UpdateMinimapButtonPosition(button, angle)
    -- Handled internally by the button
end

function General:SetMinimapButtonVisible(visible)
    if minimapButton then
        if visible then
            minimapButton:Show()
        else
            minimapButton:Hide()
        end
    end
end

-- ============================================================================
-- HUB PANEL
-- ============================================================================

function General:CreateHub(parent)
    if generalHub then return generalHub end
    
    local hub = CreateFrame("Frame", "TweaksUI_General_Hub", parent or UIParent, "BackdropTemplate")
    hub:SetSize(HUB_WIDTH, HUB_HEIGHT)  -- Standard height (AFK button removed)
    hub:SetBackdrop(darkBackdrop)
    hub:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    hub:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    hub:SetFrameStrata("DIALOG")
    hub:Hide()
    
    local title = hub:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("General")
    title:SetTextColor(1, 0.82, 0)
    
    local closeBtn = CreateFrame("Button", nil, hub, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function()
        if isTestingAFK then
            General:ExitAFKMode()
        end
        hub:Hide()
        self:HideAllPanels()
    end)
    
    -- Close all panels when hub is hidden
    hub:SetScript("OnHide", function()
        if isTestingAFK then
            General:ExitAFKMode()
        end
        self:HideAllPanels()
    end)
    
    local yOffset = -42
    
    local generalBtn = CreateFrame("Button", nil, hub, "UIPanelButtonTemplate")
    generalBtn:SetSize(HUB_WIDTH - 30, BUTTON_HEIGHT)
    generalBtn:SetPoint("TOP", 0, yOffset)
    generalBtn:SetText("General")
    generalBtn:SetScript("OnClick", function()
        self:TogglePanel("general")
    end)
    yOffset = yOffset - BUTTON_HEIGHT - BUTTON_SPACING
    
    local visBtn = CreateFrame("Button", nil, hub, "UIPanelButtonTemplate")
    visBtn:SetSize(HUB_WIDTH - 30, BUTTON_HEIGHT)
    visBtn:SetPoint("TOP", 0, yOffset)
    visBtn:SetText("Visibility")
    visBtn:SetScript("OnClick", function()
        self:TogglePanel("visibility")
    end)
    yOffset = yOffset - BUTTON_HEIGHT - BUTTON_SPACING
    
    local minimapBtn = CreateFrame("Button", nil, hub, "UIPanelButtonTemplate")
    minimapBtn:SetSize(HUB_WIDTH - 30, BUTTON_HEIGHT)
    minimapBtn:SetPoint("TOP", 0, yOffset)
    minimapBtn:SetText("Minimap")
    minimapBtn:SetScript("OnClick", function()
        self:TogglePanel("minimap")
    end)
    yOffset = yOffset - BUTTON_HEIGHT - BUTTON_SPACING
    
    local mediaBtn = CreateFrame("Button", nil, hub, "UIPanelButtonTemplate")
    mediaBtn:SetSize(HUB_WIDTH - 30, BUTTON_HEIGHT)
    mediaBtn:SetPoint("TOP", 0, yOffset)
    mediaBtn:SetText("Media")
    mediaBtn:SetScript("OnClick", function()
        self:TogglePanel("media")
    end)
    yOffset = yOffset - BUTTON_HEIGHT - BUTTON_SPACING
    
    -- Scale section header
    local scaleHeader = hub:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    scaleHeader:SetPoint("TOP", 0, yOffset)
    scaleHeader:SetText("|cffaaaaaa— Scale —|r")
    yOffset = yOffset - 18
    
    -- Settings Scale button
    local settingsScaleBtn = CreateFrame("Button", nil, hub, "UIPanelButtonTemplate")
    settingsScaleBtn:SetSize(HUB_WIDTH - 30, BUTTON_HEIGHT)
    settingsScaleBtn:SetPoint("TOP", 0, yOffset)
    settingsScaleBtn:SetScript("OnClick", function()
        self:HideAllPanels()
        self:TogglePanel("settingsScale")
    end)
    
    -- Update button text with current scale
    local function UpdateSettingsScaleBtnText()
        local scale = TweaksUI.GlobalScale and TweaksUI.GlobalScale:GetSettingsScale() or 1.0
        settingsScaleBtn:SetText(string.format("Settings Scale: %.0f%%", scale * 100))
    end
    UpdateSettingsScaleBtnText()
    hub.UpdateSettingsScaleBtnText = UpdateSettingsScaleBtnText
    yOffset = yOffset - BUTTON_HEIGHT - BUTTON_SPACING
    
    -- Adjust hub height for new button
    hub:SetHeight(math.abs(yOffset) + 20)
    
    -- Register with GlobalScale for settings scaling
    if TweaksUI.GlobalScale then
        TweaksUI.GlobalScale:RegisterSettingsPanel(hub, 1.0)
    end
    
    generalHub = hub
    return hub
end

function General:ShowHub(parent)
    if not generalHub then
        self:CreateHub(parent)
    end
    
    if parent then
        generalHub:ClearAllPoints()
        generalHub:SetPoint("TOPLEFT", parent, "TOPRIGHT", 0, 0)
    end
    
    generalHub:Show()
end

function General:HideHub()
    if generalHub then
        if isTestingAFK then
            General:ExitAFKMode()
        end
        generalHub:Hide()
    end
    self:HideAllPanels()
end

function General:HideAllPanels()
    if generalPanel then generalPanel:Hide() end
    if visibilityPanel then
        visibilityPanel:Hide()
        self:HideVisibilityCategoryPanels()
    end
    if afkPanel then
        if isTestingAFK then
            General:ExitAFKMode()
        end
        afkPanel:Hide()
    end
    if minimapPanel then minimapPanel:Hide() end
    if mediaPanel then mediaPanel:Hide() end
    if settingsScalePanel then settingsScalePanel:Hide() end
    if currentVisibilityItemPanel then
        currentVisibilityItemPanel:Hide()
    end
end

function General:TogglePanel(panelName)
    if panelName == "general" then
        self:HideAllPanels()
        if not generalPanel then
            self:CreateGeneralPanel()
        end
        generalPanel:ClearAllPoints()
        generalPanel:SetPoint("TOPLEFT", generalHub, "TOPRIGHT", 0, 0)
        generalPanel:Show()
        
    elseif panelName == "visibility" then
        self:HideAllPanels()
        if not visibilityPanel then
            self:CreateVisibilityPanel()
        end
        visibilityPanel:ClearAllPoints()
        visibilityPanel:SetPoint("TOPLEFT", generalHub, "TOPRIGHT", 0, 0)
        visibilityPanel:Show()
        
    elseif panelName == "afk" then
        -- AFK Mode disabled due to mouse interaction bugs
        return
        
    elseif panelName == "minimap" then
        self:HideAllPanels()
        if not minimapPanel then
            self:CreateMinimapPanel()
        end
        minimapPanel:ClearAllPoints()
        minimapPanel:SetPoint("TOPLEFT", generalHub, "TOPRIGHT", 0, 0)
        -- Update controls to reflect current settings before showing
        if minimapPanel.UpdateSwatchColor then
            minimapPanel:UpdateSwatchColor()
        end
        if minimapPanel.UpdateWidthDisplay then
            minimapPanel.UpdateWidthDisplay()
        end
        minimapPanel:Show()
        
    elseif panelName == "media" then
        self:HideAllPanels()
        if not mediaPanel then
            self:CreateMediaPanel()
        end
        mediaPanel:ClearAllPoints()
        mediaPanel:SetPoint("TOPLEFT", generalHub, "TOPRIGHT", 0, 0)
        mediaPanel:Show()
        
    elseif panelName == "settingsScale" then
        self:HideAllPanels()
        if not settingsScalePanel then
            self:CreateSettingsScalePanel()
        end
        settingsScalePanel:ClearAllPoints()
        settingsScalePanel:SetPoint("TOPLEFT", generalHub, "TOPRIGHT", 0, 0)
        -- Update slider to current value
        if settingsScalePanel.slider then
            local currentScale = TweaksUI.GlobalScale and TweaksUI.GlobalScale:GetSettingsScale() or 1.0
            settingsScalePanel.slider:SetValue(currentScale)
        end
        settingsScalePanel:Show()
    end
end

-- ============================================================================
-- GENERAL SETTINGS PANEL
-- ============================================================================

-- Helper to create a Leatrix warning for a specific feature set
local function CreateLeatrixQoLWarning(parent, y)
    local conflicts = General:GetLeatrixConflicts()
    if not conflicts then return y end
    
    -- Check if any QoL conflicts exist
    local hasQoLConflicts = conflicts.autoRepair or conflicts.autoSellJunk
    if not hasQoLConflicts then return y end
    
    local warning = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    warning:SetPoint("TOPLEFT", 15, y)
    warning:SetWidth(PANEL_WIDTH - 40)
    warning:SetJustifyH("LEFT")
    warning:SetText("|cffff9900⚠ Leatrix Plus|r is managing some features.\nThose options are disabled below.")
    warning:SetTextColor(1, 0.8, 0.3)
    
    return y - 45  -- More space after warning
end

function General:CreateGeneralPanel()
    if generalPanel then return generalPanel end
    
    local panel = CreateFrame("Frame", "TweaksUI_General_Settings", UIParent, "BackdropTemplate")
    panel:SetSize(PANEL_WIDTH, 455)  -- Taller for buff/debuff and character panel options
    panel:SetBackdrop(darkBackdrop)
    panel:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    panel:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    panel:SetFrameStrata("DIALOG")
    panel:Hide()
    
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("General Settings")
    title:SetTextColor(1, 0.82, 0)
    
    local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() panel:Hide() end)
    
    local y = -50  -- More space from title
    
    -- Leatrix warning (if applicable)
    y = CreateLeatrixQoLWarning(panel, y)
    
    -- ========== Convenience Section ==========
    local convLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    convLabel:SetPoint("TOPLEFT", 15, y)
    convLabel:SetText("Convenience")
    convLabel:SetTextColor(0.8, 0.8, 0.8)
    
    y = y - 25
    
    -- Auto Repair
    local autoRepairCb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    autoRepairCb:SetPoint("TOPLEFT", 20, y)
    autoRepairCb:SetSize(24, 24)
    autoRepairCb:SetChecked(self:GetSetting("autoRepair"))
    autoRepairCb.text:SetText("Auto Repair at Merchants")
    autoRepairCb.text:SetFontObject("GameFontNormal")
    
    -- Check Leatrix conflict
    if self:IsLeatrixManaging("autoRepair") then
        autoRepairCb:Disable()
        autoRepairCb:SetAlpha(0.5)
        autoRepairCb.text:SetTextColor(0.5, 0.5, 0.5)
        autoRepairCb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Managed by Leatrix Plus", 1, 0.8, 0.3)
            GameTooltip:AddLine("Disable in Leatrix Plus to use TweaksUI's version.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        autoRepairCb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    else
        autoRepairCb:SetScript("OnClick", function(cb)
            General:SetSetting("autoRepair", cb:GetChecked())
        end)
    end
    
    y = y - 28
    
    -- Use Guild Funds (indented, depends on Auto Repair)
    local guildFundsCb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    guildFundsCb:SetPoint("TOPLEFT", 40, y)  -- Indented
    guildFundsCb:SetSize(24, 24)
    guildFundsCb:SetChecked(self:GetSetting("autoRepairGuild"))
    guildFundsCb.text:SetText("Use Guild Funds First")
    guildFundsCb.text:SetFontObject("GameFontNormal")
    
    if self:IsLeatrixManaging("autoRepair") then
        guildFundsCb:Disable()
        guildFundsCb:SetAlpha(0.5)
        guildFundsCb.text:SetTextColor(0.5, 0.5, 0.5)
    else
        guildFundsCb:SetScript("OnClick", function(cb)
            General:SetSetting("autoRepairGuild", cb:GetChecked())
        end)
    end
    
    y = y - 28
    
    -- Auto Sell Junk
    local autoSellCb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    autoSellCb:SetPoint("TOPLEFT", 20, y)
    autoSellCb:SetSize(24, 24)
    autoSellCb:SetChecked(self:GetSetting("autoSellJunk"))
    autoSellCb.text:SetText("Auto Sell Junk (Grey Items)")
    autoSellCb.text:SetFontObject("GameFontNormal")
    
    if self:IsLeatrixManaging("autoSellJunk") then
        autoSellCb:Disable()
        autoSellCb:SetAlpha(0.5)
        autoSellCb.text:SetTextColor(0.5, 0.5, 0.5)
        autoSellCb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Managed by Leatrix Plus", 1, 0.8, 0.3)
            GameTooltip:AddLine("Disable in Leatrix Plus to use TweaksUI's version.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        autoSellCb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    else
        autoSellCb:SetScript("OnClick", function(cb)
            General:SetSetting("autoSellJunk", cb:GetChecked())
        end)
    end
    
    y = y - 35
    
    -- ========== Interface Section ==========
    local interfaceLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    interfaceLabel:SetPoint("TOPLEFT", 15, y)
    interfaceLabel:SetText("Interface")
    interfaceLabel:SetTextColor(0.8, 0.8, 0.8)
    
    y = y - 25
    
    -- Hide Minimap Button
    local minimapBtnCb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    minimapBtnCb:SetPoint("TOPLEFT", 20, y)
    minimapBtnCb:SetSize(24, 24)
    minimapBtnCb:SetChecked(self:GetSetting("hideMinimapButton"))
    minimapBtnCb.text:SetText("Hide Minimap Button")
    minimapBtnCb.text:SetFontObject("GameFontNormal")
    minimapBtnCb:SetScript("OnClick", function(cb)
        General:SetSetting("hideMinimapButton", cb:GetChecked())
        General:SetMinimapButtonVisible(not cb:GetChecked())
    end)
    
    y = y - 28
    
    -- Hide Blizzard Buff Frame
    local hideBuffsCb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    hideBuffsCb:SetPoint("TOPLEFT", 20, y)
    hideBuffsCb:SetSize(24, 24)
    hideBuffsCb:SetChecked(self:GetSetting("hideBlizzardBuffs"))
    hideBuffsCb.text:SetText("Hide Blizzard Buff Frame")
    hideBuffsCb.text:SetFontObject("GameFontNormal")
    hideBuffsCb:SetScript("OnClick", function(cb)
        General:SetSetting("hideBlizzardBuffs", cb:GetChecked())
        General:ApplyBlizzardBuffVisibility()
    end)
    hideBuffsCb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Hide Blizzard Buff Frame", 1, 0.82, 0)
        GameTooltip:AddLine("Makes Blizzard's buff icons invisible and non-clickable.", 1, 1, 1, true)
        GameTooltip:AddLine("Use with TweaksUI's Personal Resources module for custom buff display.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    hideBuffsCb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    y = y - 28
    
    -- Hide Blizzard Debuff Frame
    local hideDebuffsCb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    hideDebuffsCb:SetPoint("TOPLEFT", 20, y)
    hideDebuffsCb:SetSize(24, 24)
    hideDebuffsCb:SetChecked(self:GetSetting("hideBlizzardDebuffs"))
    hideDebuffsCb.text:SetText("Hide Blizzard Debuff Frame")
    hideDebuffsCb.text:SetFontObject("GameFontNormal")
    hideDebuffsCb:SetScript("OnClick", function(cb)
        General:SetSetting("hideBlizzardDebuffs", cb:GetChecked())
        General:ApplyBlizzardDebuffVisibility()
    end)
    hideDebuffsCb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Hide Blizzard Debuff Frame", 1, 0.82, 0)
        GameTooltip:AddLine("Makes Blizzard's debuff icons invisible and non-clickable.", 1, 1, 1, true)
        GameTooltip:AddLine("Use with TweaksUI's Personal Resources module for custom debuff display.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    hideDebuffsCb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    y = y - 28
    
    -- Character Panel Enhancements
    local charPanelCb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    charPanelCb:SetPoint("TOPLEFT", 20, y)
    charPanelCb:SetSize(24, 24)
    charPanelCb:SetChecked(self:GetSetting("characterPanelEnabled"))
    charPanelCb.text:SetText("Character Panel Enhancements")
    charPanelCb.text:SetFontObject("GameFontNormal")
    charPanelCb:SetScript("OnClick", function(cb)
        General:SetSetting("characterPanelEnabled", cb:GetChecked())
        if cb:GetChecked() then
            if TweaksUI.CharacterPanel then
                TweaksUI.CharacterPanel:Enable()
            end
        else
            if TweaksUI.CharacterPanel then
                TweaksUI.CharacterPanel:Disable()
                -- Also force cleanup to ensure no stale elements
                if TweaksUI.CharacterPanel.ForceCleanup then
                    TweaksUI.CharacterPanel:ForceCleanup()
                end
            end
        end
    end)
    charPanelCb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Character Panel Enhancements", 1, 0.82, 0)
        GameTooltip:AddLine("Shows precise item level (2 decimal places)", 1, 1, 1, true)
        GameTooltip:AddLine("Displays item level on each gear slot (colored by quality)", 1, 1, 1, true)
        GameTooltip:AddLine("Shows indicators for missing enchants (E) and gems (G)", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    charPanelCb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    y = y - 35
    
    -- ========== Slash Commands Section ==========
    local cmdLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cmdLabel:SetPoint("TOPLEFT", 15, y)
    cmdLabel:SetText("Slash Commands")
    cmdLabel:SetTextColor(0.8, 0.8, 0.8)
    
    y = y - 20
    
    local cmdInfo = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cmdInfo:SetPoint("TOPLEFT", 20, y)
    cmdInfo:SetText("|cff00ff00/rl|r - Reload UI\n|cff00ff00/tuil|r - Toggle Layout Mode\n|cff00ff00/cdm|r - Cooldown Manager Settings")
    cmdInfo:SetJustifyH("LEFT")
    
    -- Register with GlobalScale for settings scaling
    if TweaksUI.GlobalScale then
        TweaksUI.GlobalScale:RegisterSettingsPanel(panel, 1.0)
    end
    
    generalPanel = panel
    return panel
end

-- ============================================================================
-- VISIBILITY PANEL
-- ============================================================================

function General:CreateVisibilityPanel()
    if visibilityPanel then return visibilityPanel end
    
    -- Wider panel to accommodate all item tabs (10 items)
    local VIS_PANEL_WIDTH = 620
    
    local panel = CreateFrame("Frame", "TweaksUI_Visibility_Panel", UIParent, "BackdropTemplate")
    panel:SetSize(VIS_PANEL_WIDTH, PANEL_HEIGHT)
    panel:SetBackdrop(darkBackdrop)
    panel:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    panel:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    panel:SetFrameStrata("DIALOG")
    panel:Hide()
    
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("Visibility")
    title:SetTextColor(1, 0.82, 0)
    
    local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function()
        panel:Hide()
    end)
    
    -- Tab container for items
    local tabContainer = CreateFrame("Frame", nil, panel)
    tabContainer:SetPoint("TOPLEFT", 10, -40)
    tabContainer:SetPoint("TOPRIGHT", -10, -40)
    tabContainer:SetHeight(TAB_HEIGHT)
    
    -- Content area below tabs
    local contentArea = CreateFrame("Frame", nil, panel)
    contentArea:SetPoint("TOPLEFT", 15, -70)
    contentArea:SetPoint("BOTTOMRIGHT", -15, 15)
    
    -- Gather ALL items and sort by category then label
    local allItems = {}
    for key, info in pairs(VISIBILITY_FRAMES) do
        table.insert(allItems, { key = key, info = info })
    end
    
    -- Sort by category order, then alphabetically within category
    local categoryOrder = { combat = 1, information = 2, navigation = 3, indicators = 4, popups = 5 }
    table.sort(allItems, function(a, b)
        local catA = categoryOrder[a.info.category] or 99
        local catB = categoryOrder[b.info.category] or 99
        if catA ~= catB then
            return catA < catB
        end
        return a.info.label < b.info.label
    end)
    
    -- Create tab content frames for each item
    local tabContents = {}
    local tabs = {}
    
    for _, item in ipairs(allItems) do
        -- Create scroll frame for this item
        local scrollFrame = CreateFrame("ScrollFrame", nil, contentArea, "UIPanelScrollFrameTemplate")
        scrollFrame:SetAllPoints()
        scrollFrame:Hide()
        
        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetWidth(VIS_PANEL_WIDTH - 70)
        scrollChild:SetHeight(500)
        scrollFrame:SetScrollChild(scrollChild)
        
        -- Populate this item's settings
        self:PopulateVisibilityItemContent(scrollChild, item.key, item.info)
        
        tabContents[item.key] = scrollFrame
    end
    
    -- Tab selection function
    local function SelectTab(itemKey)
        for _, item in ipairs(allItems) do
            local tab = tabs[item.key]
            local content = tabContents[item.key]
            if item.key == itemKey then
                tab:SetNormalFontObject("GameFontHighlight")
                tab.bg:SetColorTexture(0.3, 0.3, 0.3, 0.8)
                content:Show()
            else
                tab:SetNormalFontObject("GameFontNormal")
                tab.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
                content:Hide()
            end
        end
    end
    
    -- Create item tab buttons
    local numTabs = #allItems
    local tabSpacing = 2
    local totalSpacing = (numTabs - 1) * tabSpacing
    local tabWidth = (VIS_PANEL_WIDTH - 38 - totalSpacing) / numTabs
    
    local prevTab = nil
    for i, item in ipairs(allItems) do
        local btn = CreateFrame("Button", nil, tabContainer)
        if prevTab then
            btn:SetPoint("TOPLEFT", prevTab, "TOPRIGHT", tabSpacing, 0)
        else
            btn:SetPoint("TOPLEFT", 0, 0)
        end
        btn:SetSize(tabWidth, TAB_HEIGHT)
        btn:SetNormalFontObject(i == 1 and "GameFontHighlight" or "GameFontNormal")
        btn:SetText(item.info.label)
        btn:GetFontString():SetPoint("CENTER")
        btn:GetFontString():SetWidth(tabWidth - 4)
        btn:GetFontString():SetWordWrap(false)
        btn:SetScript("OnClick", function() SelectTab(item.key) end)
        
        -- Background texture
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(i == 1 and 0.3 or 0.2, i == 1 and 0.3 or 0.2, i == 1 and 0.3 or 0.2, 0.8)
        btn.bg = bg
        
        -- Tooltip for full name
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(item.info.label, 1, 1, 1)
            GameTooltip:AddLine(item.info.description, 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        
        tabs[item.key] = btn
        prevTab = btn
    end
    
    -- Select first tab by default
    if #allItems > 0 then
        SelectTab(allItems[1].key)
    end
    
    -- Register with GlobalScale for settings scaling
    if TweaksUI.GlobalScale then
        TweaksUI.GlobalScale:RegisterSettingsPanel(panel, 1.0)
    end
    
    visibilityPanel = panel
    return panel
end

-- Legacy functions kept for compatibility but simplified
function General:HideVisibilityCategoryPanels()
    -- No longer needed - category panels removed
    for _, catPanel in pairs(visibilityCategoryPanels) do
        if catPanel then catPanel:Hide() end
    end
    if currentVisibilityItemPanel then
        currentVisibilityItemPanel:Hide()
    end
end

function General:ShowVisibilityCategoryPanel(categoryKey)
    -- No longer used - categories are now tabs within main panel
end

function General:CreateVisibilityCategoryPanel(categoryKey)
    -- No longer used - categories are now tabs within main panel
    return nil
end

function General:PopulateVisibilityItemContent(parent, frameKey, info)
    local y = 0
    
    -- Section header
    local headerLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerLabel:SetPoint("TOPLEFT", 5, y)
    headerLabel:SetText(info.label .. " Visibility")
    headerLabel:SetTextColor(0.8, 0.8, 0.8)
    
    y = y - 25
    
    -- Master hide toggle
    local hideCb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    hideCb:SetPoint("TOPLEFT", 10, y)
    hideCb:SetSize(24, 24)
    hideCb:SetChecked(self:GetVisibilitySetting(frameKey, "hide"))
    hideCb.text:SetText("Always Hide")
    hideCb.text:SetFontObject("GameFontNormal")
    hideCb:SetScript("OnClick", function(self)
        General:SetVisibilitySetting(frameKey, "hide", self:GetChecked())
        General:ApplyFrameVisibility(frameKey, true)
    end)
    
    y = y - 35
    
    -- Enable visibility conditions
    local enableCb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    enableCb:SetPoint("TOPLEFT", 10, y)
    enableCb:SetSize(24, 24)
    enableCb:SetChecked(self:GetVisibilitySetting(frameKey, "visibilityEnabled"))
    enableCb.text:SetText("Enable Visibility Conditions")
    enableCb.text:SetFontObject("GameFontNormal")
    enableCb:SetScript("OnClick", function(self)
        General:SetVisibilitySetting(frameKey, "visibilityEnabled", self:GetChecked())
        General:UpdateMouseoverHitFrames()
        General:ApplyFrameVisibility(frameKey, true)
    end)
    
    y = y - CHECKBOX_SPACING
    
    -- On Mouseover (only show if frame supports it)
    if not info.noMouseover then
        local mouseoverCb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        mouseoverCb:SetPoint("TOPLEFT", 10, y)
        mouseoverCb:SetSize(24, 24)
        mouseoverCb:SetChecked(self:GetVisibilitySetting(frameKey, "onMouseover"))
        mouseoverCb.text:SetText("On Mouseover")
        mouseoverCb.text:SetFontObject("GameFontNormal")
        mouseoverCb:SetScript("OnClick", function(self)
            General:SetVisibilitySetting(frameKey, "onMouseover", self:GetChecked())
            General:UpdateMouseoverHitFrames()
            General:ApplyFrameVisibility(frameKey, true)
        end)
        
        y = y - CHECKBOX_SPACING
    end
    
    -- Combat conditions
    local combatCb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    combatCb:SetPoint("TOPLEFT", 10, y)
    combatCb:SetSize(24, 24)
    combatCb:SetChecked(self:GetVisibilitySetting(frameKey, "inCombat"))
    combatCb.text:SetText("In Combat")
    combatCb.text:SetFontObject("GameFontNormal")
    combatCb:SetScript("OnClick", function(self)
        General:SetVisibilitySetting(frameKey, "inCombat", self:GetChecked())
        General:ApplyFrameVisibility(frameKey, true)
    end)
    
    y = y - CHECKBOX_SPACING
    
    local outCombatCb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    outCombatCb:SetPoint("TOPLEFT", 10, y)
    outCombatCb:SetSize(24, 24)
    outCombatCb:SetChecked(self:GetVisibilitySetting(frameKey, "outOfCombat"))
    outCombatCb.text:SetText("Out of Combat")
    outCombatCb.text:SetFontObject("GameFontNormal")
    outCombatCb:SetScript("OnClick", function(self)
        General:SetVisibilitySetting(frameKey, "outOfCombat", self:GetChecked())
        General:ApplyFrameVisibility(frameKey, true)
    end)
    
    y = y - CHECKBOX_SPACING
    
    -- Target conditions
    local hasTargetCb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    hasTargetCb:SetPoint("TOPLEFT", 10, y)
    hasTargetCb:SetSize(24, 24)
    hasTargetCb:SetChecked(self:GetVisibilitySetting(frameKey, "hasTarget"))
    hasTargetCb.text:SetText("Has Target")
    hasTargetCb.text:SetFontObject("GameFontNormal")
    hasTargetCb:SetScript("OnClick", function(self)
        General:SetVisibilitySetting(frameKey, "hasTarget", self:GetChecked())
        General:ApplyFrameVisibility(frameKey, true)
    end)
    
    y = y - CHECKBOX_SPACING
    
    local noTargetCb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    noTargetCb:SetPoint("TOPLEFT", 10, y)
    noTargetCb:SetSize(24, 24)
    noTargetCb:SetChecked(self:GetVisibilitySetting(frameKey, "noTarget"))
    noTargetCb.text:SetText("No Target")
    noTargetCb.text:SetFontObject("GameFontNormal")
    noTargetCb:SetScript("OnClick", function(self)
        General:SetVisibilitySetting(frameKey, "noTarget", self:GetChecked())
        General:ApplyFrameVisibility(frameKey, true)
    end)
    
    y = y - CHECKBOX_SPACING
    
    -- Group conditions
    local soloCb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    soloCb:SetPoint("TOPLEFT", 10, y)
    soloCb:SetSize(24, 24)
    soloCb:SetChecked(self:GetVisibilitySetting(frameKey, "solo"))
    soloCb.text:SetText("Solo")
    soloCb.text:SetFontObject("GameFontNormal")
    soloCb:SetScript("OnClick", function(self)
        General:SetVisibilitySetting(frameKey, "solo", self:GetChecked())
        General:ApplyFrameVisibility(frameKey, true)
    end)
    
    y = y - CHECKBOX_SPACING
    
    local partyCb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    partyCb:SetPoint("TOPLEFT", 10, y)
    partyCb:SetSize(24, 24)
    partyCb:SetChecked(self:GetVisibilitySetting(frameKey, "inParty"))
    partyCb.text:SetText("In Party")
    partyCb.text:SetFontObject("GameFontNormal")
    partyCb:SetScript("OnClick", function(self)
        General:SetVisibilitySetting(frameKey, "inParty", self:GetChecked())
        General:ApplyFrameVisibility(frameKey, true)
    end)
    
    y = y - CHECKBOX_SPACING
    
    local raidCb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    raidCb:SetPoint("TOPLEFT", 10, y)
    raidCb:SetSize(24, 24)
    raidCb:SetChecked(self:GetVisibilitySetting(frameKey, "inRaid"))
    raidCb.text:SetText("In Raid")
    raidCb.text:SetFontObject("GameFontNormal")
    raidCb:SetScript("OnClick", function(self)
        General:SetVisibilitySetting(frameKey, "inRaid", self:GetChecked())
        General:ApplyFrameVisibility(frameKey, true)
    end)
    
    y = y - CHECKBOX_SPACING
    
    local instanceCb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    instanceCb:SetPoint("TOPLEFT", 10, y)
    instanceCb:SetSize(24, 24)
    instanceCb:SetChecked(self:GetVisibilitySetting(frameKey, "inInstance"))
    instanceCb.text:SetText("In Instance")
    instanceCb.text:SetFontObject("GameFontNormal")
    instanceCb:SetScript("OnClick", function(self)
        General:SetVisibilitySetting(frameKey, "inInstance", self:GetChecked())
        General:ApplyFrameVisibility(frameKey, true)
    end)
    
    y = y - 35
    
    -- Fade section
    local fadeLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fadeLabel:SetPoint("TOPLEFT", 5, y)
    fadeLabel:SetText(info.label .. " Fade")
    fadeLabel:SetTextColor(0.8, 0.8, 0.8)
    
    y = y - 25
    
    local fadeCb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    fadeCb:SetPoint("TOPLEFT", 10, y)
    fadeCb:SetSize(24, 24)
    fadeCb:SetChecked(self:GetVisibilitySetting(frameKey, "fadeEnabled"))
    fadeCb.text:SetText("Enable Fade")
    fadeCb.text:SetFontObject("GameFontNormal")
    fadeCb:SetScript("OnClick", function(self)
        General:SetVisibilitySetting(frameKey, "fadeEnabled", self:GetChecked())
        if not self:GetChecked() then
            General:ResetFade(frameKey)
        end
        General:ApplyFrameVisibility(frameKey, true)
    end)
    
    y = y - 35
    
    -- Fade delay slider with numeric input
    local delayContainer = TweaksUI.Utilities:CreateSliderWithInput(parent, {
        label = "Fade Delay (sec):",
        min = 0,
        max = 10,
        step = 1,
        value = self:GetVisibilitySetting(frameKey, "fadeDelay") or 3,
        isFloat = false,
        width = 140,
        labelWidth = 120,
        valueWidth = 40,
        onValueChanged = function(value)
            General:SetVisibilitySetting(frameKey, "fadeDelay", value)
        end,
    })
    delayContainer:SetPoint("TOPLEFT", 10, y)
    
    y = y - 30
    
    -- Fade alpha slider with numeric input
    local alphaContainer = TweaksUI.Utilities:CreateSliderWithInput(parent, {
        label = "Fade Alpha:",
        min = 0,
        max = 1,
        step = 0.1,
        value = self:GetVisibilitySetting(frameKey, "fadeAlpha") or 0.5,
        isFloat = true,
        decimals = 1,
        width = 140,
        labelWidth = 120,
        valueWidth = 40,
        onValueChanged = function(value)
            General:SetVisibilitySetting(frameKey, "fadeAlpha", value)
        end,
    })
    alphaContainer:SetPoint("TOPLEFT", 10, y)
end

-- ============================================================================
-- AFK MODE PANEL
-- ============================================================================

function General:CreateAFKPanel()
    if afkPanel then return afkPanel end
    
    local panel = CreateFrame("Frame", "TweaksUI_AFK_Panel", UIParent, "BackdropTemplate")
    panel:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    panel:SetBackdrop(darkBackdrop)
    panel:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    panel:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    panel:SetFrameStrata("DIALOG")
    panel:Hide()
    
    panel:SetScript("OnHide", function()
        if isTestingAFK then
            General:ExitAFKMode()
        end
    end)
    
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("AFK Mode")
    title:SetTextColor(1, 0.82, 0)
    
    local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() panel:Hide() end)
    
    local y = -50
    
    local enableCb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    enableCb:SetPoint("TOPLEFT", 20, y)
    enableCb:SetSize(24, 24)
    enableCb:SetChecked(self:GetSetting("afkModeEnabled"))
    enableCb.text:SetText("Enable AFK Mode")
    enableCb.text:SetFontObject("GameFontNormal")
    enableCb:SetScript("OnClick", function(self)
        General:SetSetting("afkModeEnabled", self:GetChecked())
    end)
    
    y = y - 35
    
    local desc = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    desc:SetPoint("TOPLEFT", 20, y)
    desc:SetWidth(PANEL_WIDTH - 60)
    desc:SetText("|cff888888Automatically hides all UI elements when you go AFK.\nMove or press any key to restore the UI.|r")
    desc:SetJustifyH("LEFT")
    
    y = y - 50
    
    local optionsLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    optionsLabel:SetPoint("TOPLEFT", 10, y)
    optionsLabel:SetText("|cffaaaaaa— Options —|r")
    
    y = y - 25
    
    local fadeCb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    fadeCb:SetPoint("TOPLEFT", 20, y)
    fadeCb:SetSize(24, 24)
    fadeCb:SetChecked(self:GetSetting("afkFadeAnimation"))
    fadeCb.text:SetText("Fade Animation")
    fadeCb.text:SetFontObject("GameFontNormal")
    fadeCb:SetScript("OnClick", function(self)
        General:SetSetting("afkFadeAnimation", self:GetChecked())
    end)
    
    y = y - 35
    
    -- Fade duration slider with numeric input
    local fadeDurationContainer = TweaksUI.Utilities:CreateSliderWithInput(panel, {
        label = "Fade Duration:",
        min = 0.1,
        max = 2.0,
        step = 0.1,
        value = self:GetSetting("afkFadeDuration"),
        isFloat = true,
        decimals = 1,
        width = 140,
        labelWidth = 100,
        valueWidth = 40,
        onValueChanged = function(value)
            General:SetSetting("afkFadeDuration", value)
        end,
    })
    fadeDurationContainer:SetPoint("TOPLEFT", 20, y)
    
    y = y - 35
    
    local spinCb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    spinCb:SetPoint("TOPLEFT", 20, y)
    spinCb:SetSize(24, 24)
    spinCb:SetChecked(self:GetSetting("afkCameraSpin"))
    spinCb.text:SetText("Slowly Spin Camera")
    spinCb.text:SetFontObject("GameFontNormal")
    spinCb:SetScript("OnClick", function(self)
        General:SetSetting("afkCameraSpin", self:GetChecked())
    end)
    
    y = y - 35
    
    -- Spin speed slider with numeric input
    local spinSpeedContainer = TweaksUI.Utilities:CreateSliderWithInput(panel, {
        label = "Spin Speed:",
        min = 0.01,
        max = 0.2,
        step = 0.01,
        value = self:GetSetting("afkCameraSpinSpeed") or 0.05,
        isFloat = true,
        decimals = 2,
        width = 140,
        labelWidth = 100,
        valueWidth = 45,
        onValueChanged = function(value)
            General:SetSetting("afkCameraSpinSpeed", value)
        end,
    })
    spinSpeedContainer:SetPoint("TOPLEFT", 20, y)
    
    y = y - 35
    
    local nameplateCb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    nameplateCb:SetPoint("TOPLEFT", 20, y)
    nameplateCb:SetSize(24, 24)
    nameplateCb:SetChecked(self:GetSetting("afkHideNameplates"))
    nameplateCb.text:SetText("Hide Nameplates")
    nameplateCb.text:SetFontObject("GameFontNormal")
    nameplateCb:SetScript("OnClick", function(self)
        General:SetSetting("afkHideNameplates", self:GetChecked())
    end)
    
    y = y - 40
    
    local keepLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    keepLabel:SetPoint("TOPLEFT", 10, y)
    keepLabel:SetText("|cffaaaaaa— Keep Visible —|r")
    
    y = y - 25
    
    local minimapCb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    minimapCb:SetPoint("TOPLEFT", 20, y)
    minimapCb:SetSize(24, 24)
    minimapCb:SetChecked(self:GetSetting("afkKeepMinimap"))
    minimapCb.text:SetText("Keep Minimap")
    minimapCb.text:SetFontObject("GameFontNormal")
    minimapCb:SetScript("OnClick", function(self)
        General:SetSetting("afkKeepMinimap", self:GetChecked())
    end)
    
    y = y - CHECKBOX_SPACING
    
    local chatCb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    chatCb:SetPoint("TOPLEFT", 20, y)
    chatCb:SetSize(24, 24)
    chatCb:SetChecked(self:GetSetting("afkKeepChat"))
    chatCb.text:SetText("Keep Chat")
    chatCb.text:SetFontObject("GameFontNormal")
    chatCb:SetScript("OnClick", function(self)
        General:SetSetting("afkKeepChat", self:GetChecked())
    end)
    
    y = y - 40
    
    local testBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    testBtn:SetPoint("TOPLEFT", 20, y)
    testBtn:SetSize(150, 26)
    testBtn:SetText("Test AFK Mode")
    testBtn:SetScript("OnClick", function()
        if General:IsInAFKMode() then
            General:ExitAFKMode()
        else
            General:EnterAFKMode(true)
        end
    end)
    
    afkPanel = panel
    return panel
end

-- ============================================================================
-- MINIMAP SETTINGS PANEL
-- ============================================================================

-- Helper to create a Leatrix warning for minimap features
local function CreateLeatrixMinimapWarning(parent, y)
    local conflicts = General:GetLeatrixConflicts()
    if not conflicts then return y end
    
    -- Check if any minimap conflicts exist
    local hasMinimapConflicts = conflicts.squareMinimap or conflicts.minimapModder or 
                                 conflicts.decorations or conflicts.minimapScale or 
                                 conflicts.buttonCollector
    if not hasMinimapConflicts then return y end
    
    local warning = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    warning:SetPoint("TOPLEFT", 15, y)
    warning:SetWidth(PANEL_WIDTH - 40)
    warning:SetJustifyH("LEFT")
    warning:SetText("|cffff9900⚠ Leatrix Plus|r is managing some minimap features.\nThose options are disabled below.")
    warning:SetTextColor(1, 0.8, 0.3)
    
    return y - 45
end

function General:CreateMinimapPanel()
    if minimapPanel then return minimapPanel end
    
    local panel = CreateFrame("Frame", "TweaksUI_Minimap_Panel", UIParent, "BackdropTemplate")
    panel:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    panel:SetBackdrop(darkBackdrop)
    panel:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    panel:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    panel:SetFrameStrata("DIALOG")
    panel:Hide()
    
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("Minimap Settings")
    title:SetTextColor(1, 0.82, 0)
    
    local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() panel:Hide() end)
    
    -- Create scroll frame for content (using basic scroll frame to avoid Midnight Beta API issues)
    local scrollFrame = CreateFrame("ScrollFrame", "TweaksUI_Minimap_Panel_ScrollFrame", panel)
    scrollFrame:SetPoint("TOPLEFT", 10, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    scrollFrame:EnableMouseWheel(true)
    
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(PANEL_WIDTH - 50, 900)  -- Height will expand as needed
    scrollFrame:SetScrollChild(content)
    
    -- Create a simple scrollbar
    local scrollBar = CreateFrame("Slider", nil, scrollFrame, "BackdropTemplate")
    scrollBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -45)
    scrollBar:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 15)
    scrollBar:SetWidth(16)
    scrollBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    scrollBar:SetOrientation("VERTICAL")
    scrollBar:SetMinMaxValues(0, 1)
    scrollBar:SetValue(0)
    scrollBar:SetValueStep(0.1)
    
    local thumbTexture = scrollBar:CreateTexture(nil, "OVERLAY")
    thumbTexture:SetTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    thumbTexture:SetSize(18, 24)
    scrollBar:SetThumbTexture(thumbTexture)
    
    -- Update scroll range when content changes
    local function UpdateScrollRange()
        local contentHeight = content:GetHeight() or 900
        local frameHeight = scrollFrame:GetHeight() or 400
        local maxScroll = math.max(0, contentHeight - frameHeight)
        scrollBar:SetMinMaxValues(0, maxScroll)
    end
    
    scrollBar:SetScript("OnValueChanged", function(self, value)
        scrollFrame:SetVerticalScroll(value)
    end)
    
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = scrollBar:GetValue()
        local min, max = scrollBar:GetMinMaxValues()
        local step = 30
        local newValue = math.max(min, math.min(max, current - (delta * step)))
        scrollBar:SetValue(newValue)
    end)
    
    -- Initial scroll range update
    C_Timer.After(0.1, UpdateScrollRange)
    
    local y = -5
    
    -- ========== Custom Minimap Frame Toggle (NEW) ==========
    local customFrameLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    customFrameLabel:SetPoint("TOPLEFT", 5, y)
    customFrameLabel:SetText("Custom Minimap Frame")
    customFrameLabel:SetTextColor(1, 0.82, 0)
    y = y - 18
    
    local customFrameCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    customFrameCheck:SetPoint("TOPLEFT", 5, y)
    customFrameCheck:SetSize(24, 24)
    customFrameCheck:SetChecked(self:GetMinimapSetting("useCustomFrame"))
    
    local customFrameCheckLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    customFrameCheckLabel:SetPoint("LEFT", customFrameCheck, "RIGHT", 4, 0)
    customFrameCheckLabel:SetText("Use TweaksUI Custom Frame")
    
    local customFrameDesc = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    customFrameDesc:SetPoint("TOPLEFT", 5, y - 22)
    customFrameDesc:SetWidth(PANEL_WIDTH - 70)
    customFrameDesc:SetJustifyH("LEFT")
    customFrameDesc:SetText("|cffaaaaaaShift+Ctrl+Drag to move minimap. Alt+Shift+Drag to move decorations. Requires UI reload to enable/disable.|r")
    customFrameDesc:SetTextColor(0.6, 0.6, 0.6)
    
    customFrameCheck:SetScript("OnClick", function(self)
        General:SetMinimapSetting("useCustomFrame", self:GetChecked())
        -- Show reload prompt
        StaticPopup_Show("TWEAKSUI_RELOAD_PROMPT")
    end)
    
    y = y - 55
    
    -- Separator
    local customFrameSep = content:CreateTexture(nil, "ARTWORK")
    customFrameSep:SetPoint("TOPLEFT", 5, y)
    customFrameSep:SetSize(PANEL_WIDTH - 60, 1)
    customFrameSep:SetColorTexture(0.3, 0.3, 0.3, 1)
    y = y - 15
    
    -- ========== Coordinates Toggle (NEW - only when custom frame enabled) ==========
    local coordsCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    coordsCheck:SetPoint("TOPLEFT", 5, y)
    coordsCheck:SetSize(24, 24)
    coordsCheck:SetChecked(self:GetMinimapSetting("showCoords"))
    
    local coordsCheckLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    coordsCheckLabel:SetPoint("LEFT", coordsCheck, "RIGHT", 4, 0)
    coordsCheckLabel:SetText("Show Coordinates")
    
    coordsCheck:SetScript("OnClick", function(self)
        General:SetMinimapSetting("showCoords", self:GetChecked())
        if TweaksUI.MinimapFrame and TweaksUI.MinimapFrame:IsEnabled() then
            TweaksUI.MinimapFrame:Refresh()
        end
    end)
    
    -- Enable/disable based on custom frame setting
    local function UpdateCoordsState()
        local enabled = General:GetMinimapSetting("useCustomFrame")
        coordsCheck:SetEnabled(enabled)
        if enabled then
            coordsCheckLabel:SetTextColor(1, 1, 1)
        else
            coordsCheckLabel:SetTextColor(0.5, 0.5, 0.5)
        end
    end
    UpdateCoordsState()
    
    y = y - 28
    
    -- Leatrix warning (if applicable)
    y = CreateLeatrixMinimapWarning(content, y)
    
    -- ========== Button Collector Section (at top) ==========
    local collectorLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    collectorLabel:SetPoint("TOPLEFT", 5, y)
    collectorLabel:SetText("Button Collector")
    collectorLabel:SetTextColor(0.8, 0.8, 0.8)
    
    y = y - 25
    
    -- Enable Button Collector
    local collectorCb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    collectorCb:SetPoint("TOPLEFT", 10, y)
    collectorCb:SetSize(24, 24)
    collectorCb:SetChecked(self:GetButtonCollectorSetting("enabled"))
    collectorCb.text:SetText("Collect Addon Buttons")
    collectorCb.text:SetFontObject("GameFontNormal")
    
    if self:IsLeatrixManaging("buttonCollector") then
        collectorCb:Disable()
        collectorCb:SetAlpha(0.5)
        collectorCb.text:SetTextColor(0.5, 0.5, 0.5)
        collectorCb:SetScript("OnEnter", function(cb)
            GameTooltip:SetOwner(cb, "ANCHOR_RIGHT")
            GameTooltip:SetText("Managed by Leatrix Plus", 1, 0.8, 0.3)
            GameTooltip:AddLine("Disable 'Hide addon buttons' in Leatrix Plus to use TweaksUI's version.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        collectorCb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    else
        collectorCb:SetScript("OnClick", function(cb)
            General:SetButtonCollectorSetting("enabled", cb:GetChecked())
            General:ApplyButtonCollector()
        end)
    end
    
    y = y - 20
    
    -- Description text
    local collectorDesc = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    collectorDesc:SetPoint("TOPLEFT", 30, y)
    collectorDesc:SetWidth(PANEL_WIDTH - 80)
    collectorDesc:SetJustifyH("LEFT")
    collectorDesc:SetText("Right-click the minimap to open/close the button drawer.")
    collectorDesc:SetTextColor(0.6, 0.6, 0.6)
    
    y = y - 25
    
    -- Drawer Position dropdown
    local posLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    posLabel:SetPoint("TOPLEFT", 30, y)
    posLabel:SetText("Drawer Position:")
    
    local posDropdown = CreateFrame("Frame", "TweaksUI_DrawerPosDropdown", content, "UIDropDownMenuTemplate")
    posDropdown:SetPoint("LEFT", posLabel, "RIGHT", -5, -2)
    UIDropDownMenu_SetWidth(posDropdown, 100)
    
    -- Ensure dropdown menu appears above the panel
    posDropdown:SetFrameStrata("TOOLTIP")
    
    local DRAWER_POSITIONS = {
        { id = "left", name = "Left" },
        { id = "right", name = "Right" },
        { id = "top", name = "Top" },
        { id = "bottom", name = "Bottom" },
    }
    
    local function GetPositionName(id)
        for _, pos in ipairs(DRAWER_POSITIONS) do
            if pos.id == id then return pos.name end
        end
        return "Left"
    end
    
    local currentPos = self:GetButtonCollectorSetting("drawerPosition") or "left"
    UIDropDownMenu_SetText(posDropdown, GetPositionName(currentPos))
    
    UIDropDownMenu_Initialize(posDropdown, function(frame, level, menuList)
        -- Ensure dropdown list appears at proper strata
        local listFrame = _G["DropDownList1"]
        if listFrame then
            listFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        end
        
        for _, pos in ipairs(DRAWER_POSITIONS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = pos.name
            info.value = pos.id
            info.checked = (General:GetButtonCollectorSetting("drawerPosition") or "left") == pos.id
            info.func = function()
                General:SetButtonCollectorSetting("drawerPosition", pos.id)
                UIDropDownMenu_SetText(posDropdown, pos.name)
                -- If drawer is open, reposition it
                if buttonDrawer and buttonDrawer:IsShown() then
                    buttonDrawer:Hide()
                    General:ToggleButtonDrawer()
                end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    
    y = y - 30
    
    -- ========== Shape Section ==========
    local shapeLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    shapeLabel:SetPoint("TOPLEFT", 5, y)
    shapeLabel:SetText("Shape")
    shapeLabel:SetTextColor(0.8, 0.8, 0.8)
    
    y = y - 25
    
    -- Square Minimap
    local squareCb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    squareCb:SetPoint("TOPLEFT", 10, y)
    squareCb:SetSize(24, 24)
    squareCb:SetChecked(self:GetMinimapSetting("squareShape"))
    squareCb.text:SetText("Square Minimap")
    squareCb.text:SetFontObject("GameFontNormal")
    
    if self:IsLeatrixManaging("squareMinimap") then
        squareCb:Disable()
        squareCb:SetAlpha(0.5)
        squareCb.text:SetTextColor(0.5, 0.5, 0.5)
        squareCb:SetScript("OnEnter", function(cb)
            GameTooltip:SetOwner(cb, "ANCHOR_RIGHT")
            GameTooltip:SetText("Managed by Leatrix Plus", 1, 0.8, 0.3)
            GameTooltip:AddLine("Disable in Leatrix Plus to use TweaksUI's version.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        squareCb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    else
        squareCb:SetScript("OnClick", function(cb)
            General:SetMinimapSetting("squareShape", cb:GetChecked())
            -- Refresh the appropriate minimap system
            if TweaksUI.MinimapFrame and TweaksUI.MinimapFrame:IsEnabled() then
                TweaksUI.MinimapFrame:Refresh()
            else
                General:ApplyMinimapShape()
            end
        end)
        squareCb:SetScript("OnEnter", function(cb)
            GameTooltip:SetOwner(cb, "ANCHOR_RIGHT")
            GameTooltip:SetText("Square Minimap")
            GameTooltip:AddLine("Changes the minimap shape from circular to square.", 1, 1, 1, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Note: Incompatible with 'Rotate Minimap' setting in Edit Mode.", 1, 0.5, 0.5, true)
            GameTooltip:Show()
        end)
        squareCb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    
    y = y - 35
    
    -- ========== Scale Section ==========
    local scaleLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    scaleLabel:SetPoint("TOPLEFT", 5, y)
    scaleLabel:SetText("Scale")
    scaleLabel:SetTextColor(0.8, 0.8, 0.8)
    
    y = y - 25
    
    local scaleManaged = self:IsLeatrixManaging("minimapScale")
    
    -- Minimap scale slider with numeric input
    local scaleContainer = TweaksUI.Utilities:CreateSliderWithInput(content, {
        label = "Minimap Scale:",
        min = 0.5,
        max = 2.0,
        step = 0.1,
        value = self:GetMinimapSetting("scale") or 1.0,
        isFloat = true,
        decimals = 1,
        width = 140,
        labelWidth = 100,
        valueWidth = 40,
        onValueChanged = function(value)
            if not scaleManaged then
                General:SetMinimapSetting("scale", value)
                -- Refresh the appropriate minimap system
                if TweaksUI.MinimapFrame and TweaksUI.MinimapFrame:IsEnabled() then
                    TweaksUI.MinimapFrame:Refresh()
                else
                    General:ApplyMinimapScale()
                end
            end
        end,
    })
    scaleContainer:SetPoint("TOPLEFT", 10, y)
    
    if scaleManaged then
        scaleContainer:SetEnabled(false)
    end
    
    y = y - 35
    
    -- ========== Hide Elements Section ==========
    local hideLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hideLabel:SetPoint("TOPLEFT", 5, y)
    hideLabel:SetText("Hide Elements")
    hideLabel:SetTextColor(0.8, 0.8, 0.8)
    
    y = y - 25
    
    local decorationsManaged = self:IsLeatrixManaging("decorations")
    
    -- Decoration checkboxes
    local decorationOptions = {
        { key = "zoomButtons", label = "Zoom Buttons" },
        { key = "border", label = "Border" },
        { key = "zoneText", label = "Zone Text" },
        { key = "zoneTextBackground", label = "Zone Text Background" },
        { key = "calendar", label = "Calendar Button" },
        { key = "tracking", label = "Tracking Button" },
        { key = "mail", label = "Mail Icon" },
        { key = "craftingOrder", label = "Crafting Order Icon" },
        { key = "instanceDifficulty", label = "Instance Difficulty" },
        { key = "clock", label = "Clock" },
        { key = "expansionButton", label = "Expansion Button" },
        { key = "addonCompartment", label = "Addon Compartment" },
    }
    
    for _, opt in ipairs(decorationOptions) do
        local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 10, y)
        cb:SetSize(24, 24)
        cb:SetChecked(self:GetMinimapHideSetting(opt.key))
        cb.text:SetText(opt.label)
        cb.text:SetFontObject("GameFontNormal")
        
        if decorationsManaged then
            cb:Disable()
            cb:SetAlpha(0.5)
            cb.text:SetTextColor(0.5, 0.5, 0.5)
        else
            cb:SetScript("OnClick", function(checkbox)
                General:SetMinimapHideSetting(opt.key, checkbox:GetChecked())
                
                -- Special decorations that work regardless of custom frame
                local specialKeys = {mail = true, tracking = true, zoomButtons = true, zoneText = true, zoneTextBackground = true, expansionButton = true}
                
                if specialKeys[opt.key] then
                    -- Always apply special decorations directly
                    General:ApplyDecorationSetting(opt.key)
                elseif TweaksUI.MinimapFrame and TweaksUI.MinimapFrame:IsEnabled() then
                    -- Refresh the custom minimap system for other decorations
                    TweaksUI.MinimapFrame:Refresh()
                else
                    General:ApplyDecorationSetting(opt.key)
                    -- Also update custom border if this is the border option
                    if opt.key == "border" then
                        General:ApplyMinimapShape()
                    end
                end
            end)
        end
        
        y = y - 26
    end
    
    if decorationsManaged then
        local managedNote = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        managedNote:SetPoint("TOPLEFT", 10, y)
        managedNote:SetText("|cff888888Managed by Leatrix Plus|r")
        y = y - 20
    end
    
    y = y - 15
    
    -- ========== Custom Border Section (for square minimap) ==========
    local borderSectionLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    borderSectionLabel:SetPoint("TOPLEFT", 5, y)
    borderSectionLabel:SetText("Square Border Style")
    borderSectionLabel:SetTextColor(0.8, 0.8, 0.8)
    
    y = y - 25
    
    -- Border Width slider with numeric input
    local borderWidthContainer = TweaksUI.Utilities:CreateSliderWithInput(content, {
        label = "Border Width:",
        min = 0,
        max = 6,
        step = 1,
        value = self:GetCustomBorderSetting("width") or 2,
        isFloat = false,
        width = 140,
        labelWidth = 90,
        valueWidth = 35,
        onValueChanged = function(value)
            General:SetCustomBorderSetting("width", value)
            -- Refresh the appropriate minimap system
            if TweaksUI.MinimapFrame and TweaksUI.MinimapFrame:IsEnabled() then
                TweaksUI.MinimapFrame:Refresh()
            else
                General:UpdateCustomMinimapBorder()
            end
        end,
    })
    borderWidthContainer:SetPoint("TOPLEFT", 10, y)
    
    -- Store reference for updates
    panel.borderWidthContainer = borderWidthContainer
    
    -- Function to update width display from settings
    local function UpdateWidthDisplay()
        local width = General:GetCustomBorderSetting("width") or 2
        borderWidthContainer:SetValue(width)
    end
    panel.UpdateWidthDisplay = UpdateWidthDisplay
    
    y = y - 35
    
    -- Border Color
    local borderColorLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    borderColorLabel:SetPoint("TOPLEFT", 10, y)
    borderColorLabel:SetText("Border Color:")
    
    local colorSwatch = CreateFrame("Button", nil, content)
    colorSwatch:SetPoint("LEFT", borderColorLabel, "RIGHT", 10, 0)
    colorSwatch:SetSize(24, 24)
    
    -- Border first (BORDER layer - behind)
    local swatchBorder = colorSwatch:CreateTexture(nil, "BORDER")
    swatchBorder:SetPoint("TOPLEFT", -1, 1)
    swatchBorder:SetPoint("BOTTOMRIGHT", 1, -1)
    swatchBorder:SetColorTexture(0.3, 0.3, 0.3, 1)
    
    -- Color on top (OVERLAY layer - in front)
    local swatchColor = colorSwatch:CreateTexture(nil, "OVERLAY")
    swatchColor:SetAllPoints()
    
    -- Get current color from settings
    local color = self:GetCustomBorderSetting("color")
    if not color or type(color) ~= "table" then
        color = { r = 0.4, g = 0.4, b = 0.4 }
    end
    swatchColor:SetColorTexture(color.r or 0.4, color.g or 0.4, color.b or 0.4, 1)
    
    -- Store reference on panel
    panel.swatchColor = swatchColor
    
    -- Function to update swatch color from settings
    function panel:UpdateSwatchColor()
        local c = General:GetCustomBorderSetting("color")
        if not c or type(c) ~= "table" then
            c = { r = 0.4, g = 0.4, b = 0.4 }
        end
        if self.swatchColor then
            self.swatchColor:SetColorTexture(c.r or 0.4, c.g or 0.4, c.b or 0.4, 1)
        end
    end
    
    -- Update color when panel shows (combined with width update)
    panel:SetScript("OnShow", function(self)
        if self.UpdateSwatchColor then self:UpdateSwatchColor() end
        if self.UpdateWidthDisplay then self.UpdateWidthDisplay() end
    end)
    
    colorSwatch:SetScript("OnClick", function()
        local currentColor = General:GetCustomBorderSetting("color")
        if not currentColor or type(currentColor) ~= "table" then
            currentColor = { r = 0.4, g = 0.4, b = 0.4 }
        end
        local prev = { r = currentColor.r or 0.4, g = currentColor.g or 0.4, b = currentColor.b or 0.4 }
        ColorPickerFrame:SetupColorPickerAndShow({
            r = prev.r, g = prev.g, b = prev.b,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                General:SetCustomBorderSetting("color", { r = r, g = g, b = b })
                swatchColor:SetColorTexture(r, g, b, 1)
                -- Refresh the appropriate minimap system
                if TweaksUI.MinimapFrame and TweaksUI.MinimapFrame:IsEnabled() then
                    TweaksUI.MinimapFrame:Refresh()
                else
                    General:UpdateCustomMinimapBorder()
                end
            end,
            cancelFunc = function()
                General:SetCustomBorderSetting("color", { r = prev.r, g = prev.g, b = prev.b })
                swatchColor:SetColorTexture(prev.r, prev.g, prev.b, 1)
                -- Refresh the appropriate minimap system
                if TweaksUI.MinimapFrame and TweaksUI.MinimapFrame:IsEnabled() then
                    TweaksUI.MinimapFrame:Refresh()
                else
                    General:UpdateCustomMinimapBorder()
                end
            end,
        })
    end)
    
    colorSwatch:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetText("Click to choose border color")
        GameTooltip:Show()
    end)
    colorSwatch:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    y = y - 30
    
    -- Update content height
    content:SetHeight(math.abs(y) + 20)
    
    -- Register with GlobalScale for settings scaling
    if TweaksUI.GlobalScale then
        TweaksUI.GlobalScale:RegisterSettingsPanel(panel, 1.0)
    end
    
    minimapPanel = panel
    return panel
end

-- ============================================================================
-- MEDIA SETTINGS PANEL
-- ============================================================================

function General:CreateMediaPanel()
    local settings = self:GetSettings()
    if not settings.mediaSettings then
        settings.mediaSettings = {
            globalFont = "Friz Quadrata TT",
            useGlobalFont = false,
            globalFontOutline = "OUTLINE",
            globalTexture = "Blizzard",
            useGlobalTexture = false,
        }
    end
    -- Ensure all settings exist for older profiles
    if settings.mediaSettings.globalTexture == nil then
        settings.mediaSettings.globalTexture = "Blizzard"
    end
    if settings.mediaSettings.useGlobalTexture == nil then
        settings.mediaSettings.useGlobalTexture = false
    end
    if settings.mediaSettings.useGlobalFont == nil then
        settings.mediaSettings.useGlobalFont = false
    end
    if settings.mediaSettings.globalFont == nil then
        settings.mediaSettings.globalFont = "Friz Quadrata TT"
    end
    if settings.mediaSettings.globalFontOutline == nil then
        settings.mediaSettings.globalFontOutline = "OUTLINE"
    end
    if settings.mediaSettings.globalIconEdgeStyle == nil then
        settings.mediaSettings.globalIconEdgeStyle = "sharp"
    end
    if settings.mediaSettings.useGlobalIconEdgeStyle == nil then
        settings.mediaSettings.useGlobalIconEdgeStyle = false
    end
    local ms = settings.mediaSettings
    
    local panel = CreateFrame("Frame", "TweaksUI_General_MediaPanel", UIParent, "BackdropTemplate")
    panel:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    panel:SetBackdrop(darkBackdrop)
    panel:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(50)
    
    -- Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("Global Media Settings")
    title:SetTextColor(1, 0.82, 0)
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() panel:Hide() end)
    
    -- Scrollable content (using basic scroll frame to avoid Midnight Beta API issues)
    local scrollFrame = CreateFrame("ScrollFrame", "TweaksUI_Media_Panel_ScrollFrame", panel)
    scrollFrame:SetPoint("TOPLEFT", 10, -45)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    scrollFrame:EnableMouseWheel(true)
    
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(PANEL_WIDTH - 50, 700)
    scrollFrame:SetScrollChild(content)
    
    -- Create a simple scrollbar
    local scrollBar = CreateFrame("Slider", nil, scrollFrame, "BackdropTemplate")
    scrollBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -50)
    scrollBar:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 15)
    scrollBar:SetWidth(16)
    scrollBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    scrollBar:SetOrientation("VERTICAL")
    scrollBar:SetMinMaxValues(0, 1)
    scrollBar:SetValue(0)
    scrollBar:SetValueStep(0.1)
    
    local thumbTexture = scrollBar:CreateTexture(nil, "OVERLAY")
    thumbTexture:SetTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    thumbTexture:SetSize(18, 24)
    scrollBar:SetThumbTexture(thumbTexture)
    
    -- Update scroll range when content changes
    local function UpdateScrollRange()
        local contentHeight = content:GetHeight() or 700
        local frameHeight = scrollFrame:GetHeight() or 400
        local maxScroll = math.max(0, contentHeight - frameHeight)
        scrollBar:SetMinMaxValues(0, maxScroll)
    end
    
    scrollBar:SetScript("OnValueChanged", function(self, value)
        scrollFrame:SetVerticalScroll(value)
    end)
    
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = scrollBar:GetValue()
        local min, max = scrollBar:GetMinMaxValues()
        local step = 30
        local newValue = math.max(min, math.min(max, current - (delta * step)))
        scrollBar:SetValue(newValue)
    end)
    
    -- Initial scroll range update
    C_Timer.After(0.1, UpdateScrollRange)
    
    local y = 0
    
    -- ================================================================
    -- FONT SECTION
    -- ================================================================
    local fontHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fontHeader:SetPoint("TOPLEFT", 0, y)
    fontHeader:SetText("|cffffd100Global Font|r")
    y = y - 20
    
    -- Description
    local fontDesc = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fontDesc:SetPoint("TOPLEFT", 0, y)
    fontDesc:SetWidth(PANEL_WIDTH - 60)
    fontDesc:SetJustifyH("LEFT")
    fontDesc:SetText("|cff888888Set a font that applies to all TweaksUI modules.|r")
    y = y - 25
    
    -- Enable Global Font checkbox
    local enableFontCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    enableFontCheck:SetPoint("TOPLEFT", 0, y)
    enableFontCheck:SetSize(24, 24)
    enableFontCheck:SetChecked(ms.useGlobalFont)
    
    local enableFontLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    enableFontLabel:SetPoint("LEFT", enableFontCheck, "RIGHT", 4, 0)
    enableFontLabel:SetText("Enable Global Font Override")
    
    y = y - 35
    
    -- Global Font dropdown
    local fontLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fontLabel:SetPoint("TOPLEFT", 0, y)
    fontLabel:SetText("Global Font:")
    y = y - 20
    
    local fontDropdown = CreateFrame("Frame", "TweaksUIGlobalFontDropdown", content, "UIDropDownMenuTemplate")
    fontDropdown:SetPoint("TOPLEFT", -16, y)
    UIDropDownMenu_SetWidth(fontDropdown, 200)
    UIDropDownMenu_SetText(fontDropdown, ms.globalFont or "Friz Quadrata TT")
    
    UIDropDownMenu_Initialize(fontDropdown, function(self, level)
        local fontList = TweaksUI.Media:GetFontList()
        for _, fontName in ipairs(fontList) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = fontName
            info.checked = (ms.globalFont == fontName)
            info.func = function()
                ms.globalFont = fontName
                UIDropDownMenu_SetText(fontDropdown, fontName)
                -- Update preview with current outline
                if panel.fontPreviewText then
                    local outlineFlag = ms.globalFontOutline or "OUTLINE"
                    panel.fontPreviewText:SetFont(TweaksUI.Media:GetFont(fontName), 14, outlineFlag)
                end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    y = y - 45
    
    -- Font Outline dropdown
    local outlineLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    outlineLabel:SetPoint("TOPLEFT", 0, y)
    outlineLabel:SetText("Font Outline:")
    y = y - 20
    
    local outlineOptions = {
        { id = "", name = "None" },
        { id = "OUTLINE", name = "Thin" },
        { id = "THICKOUTLINE", name = "Thick" },
    }
    
    local function GetOutlineName(id)
        for _, opt in ipairs(outlineOptions) do
            if opt.id == id then return opt.name end
        end
        return "Thin"
    end
    
    local outlineDropdown = CreateFrame("Frame", "TweaksUIGlobalFontOutlineDropdown", content, "UIDropDownMenuTemplate")
    outlineDropdown:SetPoint("TOPLEFT", -16, y)
    UIDropDownMenu_SetWidth(outlineDropdown, 200)
    UIDropDownMenu_SetText(outlineDropdown, GetOutlineName(ms.globalFontOutline or "OUTLINE"))
    
    UIDropDownMenu_Initialize(outlineDropdown, function(self, level)
        for _, opt in ipairs(outlineOptions) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = opt.name
            info.checked = (ms.globalFontOutline == opt.id)
            info.func = function()
                ms.globalFontOutline = opt.id
                UIDropDownMenu_SetText(outlineDropdown, opt.name)
                -- Update preview
                if panel.fontPreviewText then
                    local outlineFlag = ms.globalFontOutline or ""
                    panel.fontPreviewText:SetFont(TweaksUI.Media:GetFont(ms.globalFont), 14, outlineFlag)
                end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    y = y - 45
    
    -- Font Preview
    local fontPreviewLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fontPreviewLabel:SetPoint("TOPLEFT", 0, y)
    fontPreviewLabel:SetText("Preview:")
    
    local fontPreviewBg = content:CreateTexture(nil, "BACKGROUND")
    fontPreviewBg:SetPoint("TOPLEFT", 60, y + 5)
    fontPreviewBg:SetSize(280, 30)
    fontPreviewBg:SetColorTexture(0.05, 0.05, 0.05, 0.8)
    
    local fontPreviewText = content:CreateFontString(nil, "OVERLAY")
    fontPreviewText:SetPoint("LEFT", fontPreviewBg, "LEFT", 10, 0)
    local initialOutline = ms.globalFontOutline or "OUTLINE"
    fontPreviewText:SetFont(TweaksUI.Media:GetFont(ms.globalFont), 14, initialOutline)
    fontPreviewText:SetText("The quick brown fox jumps")
    fontPreviewText:SetTextColor(1, 1, 1)
    panel.fontPreviewText = fontPreviewText
    
    y = y - 45
    
    -- Apply Font button
    local applyFontBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    applyFontBtn:SetPoint("TOPLEFT", 0, y)
    applyFontBtn:SetSize(180, 26)
    applyFontBtn:SetText("Apply Font to All")
    applyFontBtn:SetScript("OnClick", function()
        if ms.useGlobalFont and ms.globalFont then
            TweaksUI:Print("Applying global font '" .. ms.globalFont .. "'...")
            local MM = TweaksUI.ModuleManager
            
            local castBars = MM:GetModule(TweaksUI.MODULE_IDS.CAST_BARS)
            if castBars and castBars.RefreshAllCastBars then castBars:RefreshAllCastBars() end
            
            local resourceBars = MM:GetModule(TweaksUI.MODULE_IDS.RESOURCE_BARS)
            if resourceBars and resourceBars.RefreshAllBars then resourceBars:RefreshAllBars() end
            
            local chat = MM:GetModule(TweaksUI.MODULE_IDS.CHAT)
            if chat and chat.ApplyFontSettings then chat:ApplyFontSettings() end
            
            local unitFrames = MM:GetModule(TweaksUI.MODULE_IDS.UNIT_FRAMES)
            if unitFrames and unitFrames.RefreshAllFrames then unitFrames:RefreshAllFrames() end
            
            TweaksUI:Print("Global font applied!")
        else
            TweaksUI:Print("Enable 'Global Font Override' first.")
        end
    end)
    
    enableFontCheck:SetScript("OnClick", function(self)
        ms.useGlobalFont = self:GetChecked()
        General:SaveSettings()
    end)
    
    y = y - 45
    
    -- ================================================================
    -- SEPARATOR
    -- ================================================================
    local sep1 = content:CreateTexture(nil, "ARTWORK")
    sep1:SetPoint("TOPLEFT", 0, y)
    sep1:SetSize(PANEL_WIDTH - 60, 1)
    sep1:SetColorTexture(0.4, 0.4, 0.4, 0.5)
    y = y - 20
    
    -- ================================================================
    -- TEXTURE SECTION
    -- ================================================================
    local textureHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    textureHeader:SetPoint("TOPLEFT", 0, y)
    textureHeader:SetText("|cffffd100Global Texture|r")
    y = y - 20
    
    -- Description
    local textureDesc = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    textureDesc:SetPoint("TOPLEFT", 0, y)
    textureDesc:SetWidth(PANEL_WIDTH - 60)
    textureDesc:SetJustifyH("LEFT")
    textureDesc:SetText("|cff888888Set a texture that applies to all status bars.|r")
    y = y - 25
    
    -- Enable Global Texture checkbox
    local enableTextureCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    enableTextureCheck:SetPoint("TOPLEFT", 0, y)
    enableTextureCheck:SetSize(24, 24)
    enableTextureCheck:SetChecked(ms.useGlobalTexture)
    
    local enableTextureLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    enableTextureLabel:SetPoint("LEFT", enableTextureCheck, "RIGHT", 4, 0)
    enableTextureLabel:SetText("Enable Global Texture Override")
    
    y = y - 35
    
    -- Global Texture dropdown
    local textureLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    textureLabel:SetPoint("TOPLEFT", 0, y)
    textureLabel:SetText("Global Texture:")
    y = y - 20
    
    local textureDropdown = CreateFrame("Frame", "TweaksUIGlobalTextureDropdown", content, "UIDropDownMenuTemplate")
    textureDropdown:SetPoint("TOPLEFT", -16, y)
    UIDropDownMenu_SetWidth(textureDropdown, 200)
    UIDropDownMenu_SetText(textureDropdown, ms.globalTexture or "Blizzard")
    
    -- Texture Preview bar
    local texturePreviewBar = CreateFrame("StatusBar", nil, content)
    texturePreviewBar:SetPoint("LEFT", textureDropdown, "RIGHT", 10, 2)
    texturePreviewBar:SetSize(120, 18)
    texturePreviewBar:SetMinMaxValues(0, 1)
    texturePreviewBar:SetValue(0.7)
    texturePreviewBar:SetStatusBarTexture(TweaksUI.Media:GetStatusBarTexture(ms.globalTexture))
    texturePreviewBar:SetStatusBarColor(0.2, 0.8, 0.2, 1)
    
    local texturePreviewBg = texturePreviewBar:CreateTexture(nil, "BACKGROUND")
    texturePreviewBg:SetAllPoints()
    texturePreviewBg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    
    panel.texturePreviewBar = texturePreviewBar
    
    UIDropDownMenu_Initialize(textureDropdown, function(self, level)
        local textureList = TweaksUI.Media:GetStatusBarList()
        for _, textureName in ipairs(textureList) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = textureName
            info.checked = (ms.globalTexture == textureName)
            info.func = function()
                ms.globalTexture = textureName
                UIDropDownMenu_SetText(textureDropdown, textureName)
                -- Update preview
                if panel.texturePreviewBar then
                    panel.texturePreviewBar:SetStatusBarTexture(TweaksUI.Media:GetStatusBarTexture(textureName))
                end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    y = y - 45
    
    -- Apply Texture button
    local applyTextureBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    applyTextureBtn:SetPoint("TOPLEFT", 0, y)
    applyTextureBtn:SetSize(180, 26)
    applyTextureBtn:SetText("Apply Texture to All")
    applyTextureBtn:SetScript("OnClick", function()
        if ms.useGlobalTexture and ms.globalTexture then
            TweaksUI:Print("Applying global texture '" .. ms.globalTexture .. "'...")
            
            local MM = TweaksUI.ModuleManager
            
            local castBars = MM:GetModule(TweaksUI.MODULE_IDS.CAST_BARS)
            if castBars and castBars.RefreshAllCastBars then 
                castBars:RefreshAllCastBars() 
                TweaksUI:Print("  - Cast Bars updated")
            end
            
            local resourceBars = MM:GetModule(TweaksUI.MODULE_IDS.RESOURCE_BARS)
            if resourceBars and resourceBars.RefreshAllBars then 
                resourceBars:RefreshAllBars() 
                TweaksUI:Print("  - Resource Bars updated")
            end
            
            local unitFrames = MM:GetModule(TweaksUI.MODULE_IDS.UNIT_FRAMES)
            if unitFrames and unitFrames.RefreshAllFrames then 
                unitFrames:RefreshAllFrames() 
                TweaksUI:Print("  - Unit Frames updated")
            end
            
            TweaksUI:Print("Done! Some elements may need /reload.")
        else
            TweaksUI:Print("Enable 'Global Texture Override' first.")
        end
    end)
    
    enableTextureCheck:SetScript("OnClick", function(self)
        ms.useGlobalTexture = self:GetChecked()
        General:SaveSettings()
    end)
    
    y = y - 45
    
    -- ================================================================
    -- GLOBAL ICON EDGE STYLE SECTION
    -- ================================================================
    local edgeHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    edgeHeader:SetPoint("TOPLEFT", 0, y)
    edgeHeader:SetText("|cffffd100Global Icon Edge Style|r")
    y = y - 20
    
    local edgeDesc = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    edgeDesc:SetPoint("TOPLEFT", 0, y)
    edgeDesc:SetWidth(PANEL_WIDTH - 60)
    edgeDesc:SetJustifyH("LEFT")
    edgeDesc:SetText("|cff888888Force all cooldown tracker and action bar icons to use the same edge style.|r")
    y = y - 25
    
    -- Enable Global Icon Edge Style checkbox
    local enableEdgeCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    enableEdgeCheck:SetPoint("TOPLEFT", 0, y)
    enableEdgeCheck:SetSize(24, 24)
    enableEdgeCheck:SetChecked(ms.useGlobalIconEdgeStyle or false)
    
    local enableEdgeLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    enableEdgeLabel:SetPoint("LEFT", enableEdgeCheck, "RIGHT", 5, 0)
    enableEdgeLabel:SetText("Enable Global Icon Edge Style Override")
    y = y - 30
    
    -- Icon Edge Style dropdown
    local edgeLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    edgeLabel:SetPoint("TOPLEFT", 10, y)
    edgeLabel:SetText("Icon Edge Style:")
    
    local edgeDropdown = CreateFrame("Frame", "TweaksUI_Global_IconEdgeStyle", content, "UIDropDownMenuTemplate")
    edgeDropdown:SetPoint("TOPLEFT", 100, y + 5)
    UIDropDownMenu_SetWidth(edgeDropdown, 150)
    
    local edgeStyles = {
        {value = "sharp", label = "Sharp (Zoomed)"},
        {value = "rounded", label = "Rounded Corners"},
        {value = "square", label = "Square (Full)"},
    }
    
    -- Set initial text
    local currentEdge = ms.globalIconEdgeStyle or "sharp"
    for _, opt in ipairs(edgeStyles) do
        if opt.value == currentEdge then
            UIDropDownMenu_SetText(edgeDropdown, opt.label)
            break
        end
    end
    
    UIDropDownMenu_Initialize(edgeDropdown, function(self, level)
        for _, opt in ipairs(edgeStyles) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = opt.label
            info.value = opt.value
            info.checked = (ms.globalIconEdgeStyle or "sharp") == opt.value
            info.func = function()
                ms.globalIconEdgeStyle = opt.value
                UIDropDownMenu_SetText(edgeDropdown, opt.label)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    y = y - 35
    
    -- Apply Icon Edge Style button
    local applyEdgeBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    applyEdgeBtn:SetPoint("TOPLEFT", 0, y)
    applyEdgeBtn:SetSize(180, 26)
    applyEdgeBtn:SetText("Apply Edge Style to All")
    applyEdgeBtn:SetScript("OnClick", function()
        if ms.useGlobalIconEdgeStyle and ms.globalIconEdgeStyle then
            TweaksUI:Print("Applying global icon edge style '" .. ms.globalIconEdgeStyle .. "'...")
            
            local MM = TweaksUI.ModuleManager
            
            -- Apply to Cooldowns module
            local cooldowns = MM:GetModule(TweaksUI.MODULE_IDS.COOLDOWNS)
            if cooldowns then
                -- Fire layout refresh for all trackers
                local trackerKeys = {"essential", "utility", "buffs", "customTrackers"}
                for _, key in ipairs(trackerKeys) do
                    local viewer = _G[key == "essential" and "EssentialCooldownViewer" or 
                                      key == "utility" and "UtilityCooldownViewer" or 
                                      key == "buffs" and "BuffIconCooldownViewer" or nil]
                    if viewer and viewer:IsShown() then
                        TweaksUI:Print("  - " .. key .. " tracker updated")
                    end
                end
                -- Request full refresh
                TweaksUI.Events:Fire(TweaksUI.EVENTS.SETTINGS_CHANGED, TweaksUI.MODULE_IDS.COOLDOWNS, "globalIconEdgeStyle", ms.globalIconEdgeStyle)
            end
            
            -- Apply to Action Bars module
            local actionBars = MM:GetModule(TweaksUI.MODULE_IDS.ACTION_BARS)
            if actionBars and actionBars.ApplyAllIconEdgeStyles then
                actionBars:ApplyAllIconEdgeStyles()
                TweaksUI:Print("  - Action Bars updated")
            end
            
            TweaksUI:Print("Done! Some elements may need /reload.")
        else
            TweaksUI:Print("Enable 'Global Icon Edge Style Override' first.")
        end
    end)
    
    enableEdgeCheck:SetScript("OnClick", function(self)
        ms.useGlobalIconEdgeStyle = self:GetChecked()
        General:SaveSettings()
    end)
    
    y = y - 45
    
    -- ================================================================
    -- GLOBAL MASQUE SETTINGS
    -- ================================================================
    local Masque = LibStub and LibStub("Masque", true)
    if Masque then
        local masqueHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        masqueHeader:SetPoint("TOPLEFT", 0, y)
        masqueHeader:SetText("|cffffd100Global Masque Skinning|r")
        y = y - 20
        
        local masqueDesc = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        masqueDesc:SetPoint("TOPLEFT", 0, y)
        masqueDesc:SetWidth(PANEL_WIDTH - 60)
        masqueDesc:SetJustifyH("LEFT")
        masqueDesc:SetText("Enable Masque skinning for all cooldown trackers and action bars. Masque will handle icon borders and backgrounds.")
        y = y - 35
        
        local enableMasqueBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        enableMasqueBtn:SetPoint("TOPLEFT", 0, y)
        enableMasqueBtn:SetSize(180, 26)
        enableMasqueBtn:SetText("Enable Masque for All")
        enableMasqueBtn:SetScript("OnClick", function()
            TweaksUI:Print("Enabling Masque skinning for all modules...")
            
            local MM = TweaksUI.ModuleManager
            
            -- Enable for Cooldowns module
            local cooldowns = MM:GetModule(TweaksUI.MODULE_IDS.COOLDOWNS)
            if cooldowns then
                local cdSettings = TweaksUI.Database:GetModuleSettings(TweaksUI.MODULE_IDS.COOLDOWNS)
                if cdSettings then
                    local trackerKeys = {"essential", "utility", "buffs", "customTrackers"}
                    for _, key in ipairs(trackerKeys) do
                        if cdSettings[key] then
                            cdSettings[key].useMasque = true
                        end
                    end
                    TweaksUI.Database:SetModuleSettings(TweaksUI.MODULE_IDS.COOLDOWNS, cdSettings)
                    TweaksUI:Print("  - Cooldown Trackers: Masque enabled")
                    
                    -- Refresh trackers
                    if cooldowns.RefreshFromDatabase then
                        cooldowns:RefreshFromDatabase()
                    end
                end
            end
            
            -- Enable for Action Bars module
            local actionBars = MM:GetModule(TweaksUI.MODULE_IDS.ACTION_BARS)
            if actionBars then
                local abSettings = TweaksUI.Database:GetModuleSettings(TweaksUI.MODULE_IDS.ACTION_BARS)
                if abSettings and abSettings.bars then
                    for barId, barSettings in pairs(abSettings.bars) do
                        barSettings.useMasque = true
                    end
                    TweaksUI.Database:SetModuleSettings(TweaksUI.MODULE_IDS.ACTION_BARS, abSettings)
                    TweaksUI:Print("  - Action Bars: Masque enabled")
                    
                    -- Refresh action bars
                    if actionBars.RefreshFromDatabase then
                        actionBars:RefreshFromDatabase()
                    end
                end
            end
            
            TweaksUI:Print("Done! Masque is now enabled for all modules.")
            TweaksUI:Print("Open Masque settings to choose your skin.")
        end)
        
        y = y - 35
        
        local disableMasqueBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        disableMasqueBtn:SetPoint("TOPLEFT", 190, y + 35)
        disableMasqueBtn:SetSize(180, 26)
        disableMasqueBtn:SetText("Disable Masque for All")
        disableMasqueBtn:SetScript("OnClick", function()
            TweaksUI:Print("Disabling Masque skinning for all modules...")
            
            local MM = TweaksUI.ModuleManager
            
            -- Disable for Cooldowns module
            local cooldowns = MM:GetModule(TweaksUI.MODULE_IDS.COOLDOWNS)
            if cooldowns then
                local cdSettings = TweaksUI.Database:GetModuleSettings(TweaksUI.MODULE_IDS.COOLDOWNS)
                if cdSettings then
                    local trackerKeys = {"essential", "utility", "buffs", "customTrackers"}
                    for _, key in ipairs(trackerKeys) do
                        if cdSettings[key] then
                            cdSettings[key].useMasque = false
                        end
                    end
                    TweaksUI.Database:SetModuleSettings(TweaksUI.MODULE_IDS.COOLDOWNS, cdSettings)
                    TweaksUI:Print("  - Cooldown Trackers: Masque disabled")
                    
                    if cooldowns.RefreshFromDatabase then
                        cooldowns:RefreshFromDatabase()
                    end
                end
            end
            
            -- Disable for Action Bars module
            local actionBars = MM:GetModule(TweaksUI.MODULE_IDS.ACTION_BARS)
            if actionBars then
                local abSettings = TweaksUI.Database:GetModuleSettings(TweaksUI.MODULE_IDS.ACTION_BARS)
                if abSettings and abSettings.bars then
                    for barId, barSettings in pairs(abSettings.bars) do
                        barSettings.useMasque = false
                    end
                    TweaksUI.Database:SetModuleSettings(TweaksUI.MODULE_IDS.ACTION_BARS, abSettings)
                    TweaksUI:Print("  - Action Bars: Masque disabled")
                    
                    if actionBars.RefreshFromDatabase then
                        actionBars:RefreshFromDatabase()
                    end
                end
            end
            
            TweaksUI:Print("Done! Masque disabled. /reload recommended.")
        end)
        
        y = y - 15
    end
    
    -- ================================================================
    -- SEPARATOR
    -- ================================================================
    local sep2 = content:CreateTexture(nil, "ARTWORK")
    sep2:SetPoint("TOPLEFT", 0, y)
    sep2:SetSize(PANEL_WIDTH - 60, 1)
    sep2:SetColorTexture(0.4, 0.4, 0.4, 0.5)
    y = y - 20
    
    -- ================================================================
    -- INFO SECTION
    -- ================================================================
    local infoText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    infoText:SetPoint("TOPLEFT", 0, y)
    infoText:SetWidth(PANEL_WIDTH - 60)
    infoText:SetJustifyH("LEFT")
    infoText:SetText("|cff888888Note: Some elements may require /reload. Modules can still use their own settings when global override is disabled.|r")
    y = y - 50
    
    -- Available Media Info
    local mediaInfoHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mediaInfoHeader:SetPoint("TOPLEFT", 0, y)
    mediaInfoHeader:SetText("|cffffd100Available Media|r")
    y = y - 20
    
    local mediaInfo = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mediaInfo:SetPoint("TOPLEFT", 0, y)
    mediaInfo:SetWidth(PANEL_WIDTH - 60)
    mediaInfo:SetJustifyH("LEFT")
    
    -- Count available media
    local textureCount = TweaksUI.Media:GetStatusBarList() and #TweaksUI.Media:GetStatusBarList() or 0
    local fontCount = TweaksUI.Media:GetFontList() and #TweaksUI.Media:GetFontList() or 0
    local soundCount = TweaksUI.Media:GetSoundList() and #TweaksUI.Media:GetSoundList() or 0
    
    mediaInfo:SetText(string.format(
        "Textures: %d  |  Fonts: %d  |  Sounds: %d\n\n|cff888888Install SharedMedia packs to add more.\nUse /tui textures, /tui fonts, /tui sounds to list.|r",
        textureCount, fontCount, soundCount
    ))
    
    -- Update content height
    content:SetHeight(math.abs(y) + 100)
    
    -- Register with GlobalScale for settings scaling
    if TweaksUI.GlobalScale then
        TweaksUI.GlobalScale:RegisterSettingsPanel(panel, 1.0)
    end
    
    mediaPanel = panel
    return panel
end

-- ============================================================================
-- SETTINGS SCALE PANEL
-- ============================================================================

function General:CreateSettingsScalePanel()
    local panel = CreateFrame("Frame", "TweaksUI_General_SettingsScalePanel", UIParent, "BackdropTemplate")
    panel:SetSize(PANEL_WIDTH, 280)
    panel:SetBackdrop(darkBackdrop)
    panel:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    panel:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    panel:SetFrameStrata("DIALOG")
    panel:Hide()
    
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("Settings Scale")
    title:SetTextColor(1, 0.82, 0)
    
    local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function()
        panel:Hide()
    end)
    
    local content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT", 15, -40)
    content:SetPoint("BOTTOMRIGHT", -15, 15)
    
    -- Description
    local desc = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    desc:SetPoint("TOPLEFT", 0, 0)
    desc:SetWidth(PANEL_WIDTH - 40)
    desc:SetJustifyH("LEFT")
    desc:SetText("|cffffffffSettings Scale|r adjusts the size of all TweaksUI settings panels.\n\nUseful for high-DPI displays or if you prefer larger/smaller UI elements.")
    desc:SetTextColor(0.8, 0.8, 0.8)
    
    local yPos = -desc:GetStringHeight() - 30
    
    -- Current scale display
    local scaleLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    scaleLabel:SetPoint("TOPLEFT", 0, yPos)
    scaleLabel:SetText("Current Scale:")
    
    local scaleValue = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    scaleValue:SetPoint("LEFT", scaleLabel, "RIGHT", 10, 0)
    panel.scaleValue = scaleValue
    
    yPos = yPos - 40
    
    -- Slider
    local slider = CreateFrame("Slider", "TweaksUI_SettingsScaleSlider", content, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 10, yPos)
    slider:SetWidth(PANEL_WIDTH - 120)
    slider:SetMinMaxValues(0.5, 2.0)
    slider:SetValueStep(0.05)
    slider:SetObeyStepOnDrag(true)
    slider.Low:SetText("50%")
    slider.High:SetText("200%")
    slider.Text:SetText("")
    panel.slider = slider
    
    -- Edit box
    local editBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    editBox:SetSize(50, 20)
    editBox:SetPoint("LEFT", slider, "RIGHT", 15, 0)
    editBox:SetAutoFocus(false)
    panel.editBox = editBox
    
    local percentLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    percentLabel:SetPoint("LEFT", editBox, "RIGHT", 2, 0)
    percentLabel:SetText("%")
    
    -- Update function (display only, doesn't apply)
    local function UpdateDisplay(value)
        local colorCode = "|cffffd100"
        if value < 1.0 then
            colorCode = "|cffffff88"  -- Yellow-ish for decrease
        elseif value > 1.0 then
            colorCode = "|cff88ff88"  -- Green-ish for increase
        end
        scaleValue:SetText(string.format("%s%.0f%%|r", colorCode, value * 100))
        editBox:SetText(string.format("%.0f", value * 100))
    end
    
    -- Apply function (actually changes the scale)
    local function ApplyScale(value)
        if TweaksUI.GlobalScale then
            TweaksUI.GlobalScale:SetSettingsScale(value)
        end
        -- Update the hub button text
        if generalHub and generalHub.UpdateSettingsScaleBtnText then
            generalHub.UpdateSettingsScaleBtnText()
        end
    end
    
    -- Initialize with current value
    local currentScale = TweaksUI.GlobalScale and TweaksUI.GlobalScale:GetSettingsScale() or 1.0
    slider:SetValue(currentScale)
    UpdateDisplay(currentScale)
    
    -- While dragging, only update display (don't apply scale)
    slider:SetScript("OnValueChanged", function(self, value)
        UpdateDisplay(value)
    end)
    
    -- Apply scale only when mouse is released
    slider:SetScript("OnMouseUp", function(self)
        ApplyScale(self:GetValue())
    end)
    
    editBox:SetScript("OnEnterPressed", function(self)
        local value = tonumber(self:GetText())
        if value then
            value = value / 100
            value = math.max(0.5, math.min(2.0, value))
            slider:SetValue(value)
            ApplyScale(value)  -- Apply immediately for manual entry
        end
        self:ClearFocus()
    end)
    
    editBox:SetScript("OnEscapePressed", function(self)
        self:SetText(string.format("%.0f", slider:GetValue() * 100))
        self:ClearFocus()
    end)
    
    yPos = yPos - 50
    
    -- Reset to 100% button
    local resetBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    resetBtn:SetPoint("TOP", 0, yPos)
    resetBtn:SetSize(120, 25)
    resetBtn:SetText("Reset to 100%")
    resetBtn:SetScript("OnClick", function()
        slider:SetValue(1.0)
        ApplyScale(1.0)  -- Apply immediately for button click
    end)
    
    -- Register with GlobalScale for scaling (this panel gets scaled too!)
    if TweaksUI.GlobalScale then
        TweaksUI.GlobalScale:RegisterSettingsPanel(panel, 1.0)
    end
    
    settingsScalePanel = panel
    return panel
end

-- ============================================================================
-- LEGACY SUPPORT
-- ============================================================================

function General:ShowSettingsPanel(parentPanel)
    self:ShowHub(parentPanel)
end

function General:HideSettingsPanel()
    self:HideHub()
end

-- ============================================================================
-- PROFILE CHANGED HANDLER
-- ============================================================================

function General:OnProfileChanged(profileName)
    TweaksUI:PrintDebug("General OnProfileChanged:", profileName)
    
    -- Invalidate settings cache
    settings = nil
    
    -- Reload settings from new profile
    settings = TweaksUI.Database:GetModuleSettings(TweaksUI.MODULE_IDS.GENERAL)
    
    -- Initialize with defaults if empty
    if not settings or not next(settings) then
        settings = {}
        TweaksUI.Database:SetModuleSettings(TweaksUI.MODULE_IDS.GENERAL, settings)
    end
    
    -- Re-initialize defaults
    self:Initialize()
    
    -- Explicitly apply buff/debuff visibility from new profile
    C_Timer.After(0.2, function()
        self:ApplyBlizzardBuffDebuffVisibility()
    end)
    
    -- Refresh visibility controls if they exist
    if TweaksUI.Media then
        -- Refresh any frames using global media settings
        C_Timer.After(0.1, function()
            if TweaksUI.Media:IsUsingGlobalTexture() or TweaksUI.Media:IsUsingGlobalFont() then
                -- Fire event to refresh all modules
                TweaksUI.Events:Fire(TweaksUI.EVENTS.SETTINGS_CHANGED, TweaksUI.MODULE_IDS.GENERAL, "mediaSettings", settings.mediaSettings)
            end
        end)
    end
end

-- Save settings to database
function General:SaveSettings()
    if settings then
        TweaksUI.Database:SetModuleSettings(TweaksUI.MODULE_IDS.GENERAL, settings)
    end
end

return General
