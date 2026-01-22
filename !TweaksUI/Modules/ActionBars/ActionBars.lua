-- ============================================================================
-- TweaksUI: Action Bars Module
-- Enhances Blizzard's action bars with layout and visibility options
-- ============================================================================

local ADDON_NAME, TweaksUI = ...

-- Create the module
local ActionBars = TweaksUI.ModuleManager:NewModule(
    TweaksUI.MODULE_IDS.ACTION_BARS,
    "Action Bars",
    "Customize action bar layouts and visibility"
)

-- ============================================================================
-- LOCAL VARIABLES
-- ============================================================================

local settings = nil
local actionBarsHub = nil
local settingsPanels = {}
local stanceBarPanel = nil  -- Stance bar settings panel
local currentOpenPanel = nil
local eventFrame = nil
local pendingUpdates = {}
local originalButtonPositions = {}
local hookedBars = {}
local highlightFrames = {}  -- For highlighting selected bar in settings
local barWrappers = {}  -- TUIFrame wrappers for each bar

-- Masque support
local Masque = nil  -- Deferred lookup - set in InitializeActionBarsMasque
local MasqueGroups = {}  -- [barId] = MasqueGroup

-- TUIFrame and Layout references (set after modules load)
local TUIFrame = nil
local Layout = nil

-- Panel dimensions
local HUB_WIDTH = 200
local HUB_HEIGHT = 660
local PANEL_WIDTH = 500
local PANEL_HEIGHT = 520
local BUTTON_HEIGHT = 28
local BUTTON_SPACING = 4

-- Dark backdrop for panels
local darkBackdrop = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
}

-- ============================================================================
-- BAR CONFIGURATION
-- ============================================================================

local BAR_INFO = {
    ActionBar1 = {
        displayName = "Action Bar 1",
        buttonPrefix = "ActionButton",
        buttonCount = 12,
        frame = "MainActionBarButtonContainer1",
        selectionFrame = "MainActionBar",  -- Edit Mode selection is on this frame
        visibilityFrame = "MainActionBar",  -- Frame to fade for visibility
        visibilitySetting = nil,  -- Always visible
        order = 1,
    },
    ActionBar2 = {
        displayName = "Action Bar 2",
        buttonPrefix = "MultiBarBottomLeftButton",
        buttonCount = 12,
        frame = "MultiBarBottomLeft",
        selectionFrame = "MultiBarBottomLeft",
        visibilitySetting = "MultiBarBottomLeftVisibility",
        order = 2,
    },
    ActionBar3 = {
        displayName = "Action Bar 3",
        buttonPrefix = "MultiBarBottomRightButton",
        buttonCount = 12,
        frame = "MultiBarBottomRight",
        selectionFrame = "MultiBarBottomRight",
        visibilitySetting = "MultiBarBottomRightVisibility",
        order = 3,
    },
    ActionBar4 = {
        displayName = "Action Bar 4",
        buttonPrefix = "MultiBarRightButton",
        buttonCount = 12,
        frame = "MultiBarRight",
        selectionFrame = "MultiBarRight",
        visibilitySetting = "MultiBarRightVisibility",
        order = 4,
    },
    ActionBar5 = {
        displayName = "Action Bar 5",
        buttonPrefix = "MultiBarLeftButton",
        buttonCount = 12,
        frame = "MultiBarLeft",
        selectionFrame = "MultiBarLeft",
        visibilitySetting = "MultiBarLeftVisibility",
        order = 5,
    },
    ActionBar6 = {
        displayName = "Action Bar 6",
        buttonPrefix = "MultiBar5Button",
        buttonCount = 12,
        frame = "MultiBar5",
        selectionFrame = "MultiBar5",
        visibilitySetting = "MultiBar5Visibility",
        order = 6,
    },
    ActionBar7 = {
        displayName = "Action Bar 7",
        buttonPrefix = "MultiBar6Button",
        buttonCount = 12,
        frame = "MultiBar6",
        selectionFrame = "MultiBar6",
        visibilitySetting = "MultiBar6Visibility",
        order = 7,
    },
    ActionBar8 = {
        displayName = "Action Bar 8",
        buttonPrefix = "MultiBar7Button",
        buttonCount = 12,
        frame = "MultiBar7",
        selectionFrame = "MultiBar7",
        visibilitySetting = "MultiBar7Visibility",
        order = 8,
    },
}

local BAR_ORDER = {
    "ActionBar1",
    "ActionBar2",
    "ActionBar3",
    "ActionBar4",
    "ActionBar5",
    "ActionBar6",
    "ActionBar7",
    "ActionBar8",
}

-- ============================================================================
-- SYSTEM BAR CONFIGURATION (Micro Menu, Bags, Stance, Pet)
-- These bars don't have customizable button layouts, just positioning/visibility
-- ============================================================================

local SYSTEM_BAR_INFO = {
    MicroMenu = {
        displayName = "Micro Menu",
        frame = "MicroMenuContainer",
        fallbackFrames = {"MicroMenu", "MicroButtonAndBagsBar"},
        description = "Character, spellbook, talents, and other menu buttons",
        order = 1,
    },
    BagsBar = {
        displayName = "Bags Bar",
        frame = "BagsBar",
        fallbackFrames = {"MicroButtonAndBagsBar"},
        description = "Bag slot buttons",
        order = 2,
    },
    -- StanceBar removed - we create our own custom stance bar now
    PetBar = {
        displayName = "Pet Bar",
        frame = "PetActionBar",
        fallbackFrames = {},
        description = "Pet action buttons",
        order = 3,
    },
}

local SYSTEM_BAR_ORDER = {
    "MicroMenu",
    "BagsBar",
    "PetBar",
}

-- Default positions for system bars
local SYSTEM_BAR_DEFAULT_POSITIONS = {
    MicroMenu = { point = "BOTTOMRIGHT", x = -250, y = 5 },
    BagsBar = { point = "BOTTOMRIGHT", x = -5, y = 5 },
    PetBar = { point = "BOTTOM", x = 0, y = 150 },
}

-- Track system bar wrappers separately
local systemBarWrappers = {}

-- ============================================================================
-- DEBUG HELPER (defined early so it's available for all functions)
-- ============================================================================

local function DebugPrint(...)
    if TweaksUI and TweaksUI.PrintDebug then
        TweaksUI:PrintDebug("[ActionBars]", ...)
    end
end

-- Default positions for bars (when using TUIFrame wrappers)
local BAR_DEFAULT_POSITIONS = {
    ActionBar1 = { point = "BOTTOM", x = 0, y = 45 },
    ActionBar2 = { point = "BOTTOM", x = -260, y = 45 },
    ActionBar3 = { point = "BOTTOM", x = 260, y = 45 },
    ActionBar4 = { point = "RIGHT", x = -5, y = 0 },
    ActionBar5 = { point = "RIGHT", x = -55, y = 0 },
    ActionBar6 = { point = "BOTTOM", x = 0, y = 100 },
    ActionBar7 = { point = "BOTTOM", x = 0, y = 155 },
    ActionBar8 = { point = "BOTTOM", x = 0, y = 210 },
}

-- ============================================================================
-- TUIFRAME WRAPPER MANAGEMENT
-- ============================================================================

local function GetOrCreateBarWrapper(barId)
    -- Return existing wrapper if available
    if barWrappers[barId] then
        return barWrappers[barId]
    end
    
    -- Ensure TUIFrame is available
    if not TUIFrame then
        TUIFrame = TweaksUI.TUIFrame
    end
    if not TUIFrame then
        DebugPrint("TUIFrame not available yet")
        return nil
    end
    
    local info = BAR_INFO[barId]
    if not info then return nil end
    
    local barSettings = settings and settings.bars and settings.bars[barId]
    if not barSettings then return nil end
    
    -- Calculate wrapper size from settings
    local buttonsShown = barSettings.buttonsShown or 12
    local cols = barSettings.columns or 12
    local size = barSettings.buttonSize or 45
    local hSpacing = barSettings.horizontalSpacing or 6
    local vSpacing = barSettings.verticalSpacing or 6
    
    local rows = math.ceil(buttonsShown / cols)
    local actualCols = math.min(cols, buttonsShown)
    local width = actualCols * size + (actualCols - 1) * hSpacing
    local height = rows * size + (rows - 1) * vSpacing
    
    -- Get default position
    local defaultPos = BAR_DEFAULT_POSITIONS[barId] or { point = "CENTER", x = 0, y = 0 }
    
    -- Create the wrapper using TUIFrame
    local wrapper = TUIFrame:New("actionbar_" .. barId:lower():gsub("actionbar", ""), {
        name = info.displayName,
        category = "Action Bars",
        width = width,
        height = height,
        defaultPoint = defaultPos.point,
        defaultX = defaultPos.x,
        defaultY = defaultPos.y,
    })
    
    if wrapper then
        -- Store reference to buttons
        wrapper.buttons = {}
        wrapper.barId = barId
        barWrappers[barId] = wrapper
        
        DebugPrint("Created TUIFrame wrapper for", barId, "size:", width, "x", height)
    end
    
    return wrapper
end

local function UpdateBarWrapperSize(barId)
    local wrapper = barWrappers[barId]
    if not wrapper then return end
    
    local barSettings = settings and settings.bars and settings.bars[barId]
    if not barSettings then return end
    
    -- Calculate new size from settings
    local buttonsShown = barSettings.buttonsShown or 12
    local cols = barSettings.columns or 12
    local size = barSettings.buttonSize or 45
    local hSpacing = barSettings.horizontalSpacing or 6
    local vSpacing = barSettings.verticalSpacing or 6
    
    local rows = math.ceil(buttonsShown / cols)
    local actualCols = math.min(cols, buttonsShown)
    local width = actualCols * size + (actualCols - 1) * hSpacing
    local height = rows * size + (rows - 1) * vSpacing
    
    wrapper:SetSize(width, height)
end

local function RegisterBarWithLayout(barId)
    -- Ensure Layout module is available
    if not Layout then
        Layout = TweaksUI.Layout
    end
    if not Layout then return end
    
    local wrapper = barWrappers[barId]
    if not wrapper then return end
    
    local info = BAR_INFO[barId]
    if not info then return end
    
    local defaultPos = BAR_DEFAULT_POSITIONS[barId] or { point = "CENTER", x = 0, y = 0 }
    
    -- Register with Layout module
    Layout:RegisterElement("actionbar_" .. barId:lower():gsub("actionbar", ""), {
        name = info.displayName,
        category = Layout.CATEGORIES.ACTION_BARS,
        tuiFrame = wrapper,
        defaultPosition = defaultPos,
    })
    
    DebugPrint("Registered", barId, "with Layout module")
end

local function HideBlizzardBar(barId)
    local info = BAR_INFO[barId]
    if not info then return end
    
    local blizzBar = _G[info.frame]
    if blizzBar then
        -- Don't actually hide it - just make it invisible and non-interactive
        -- This preserves Blizzard's internal state
        blizzBar:SetAlpha(0)
        blizzBar:EnableMouse(false)
        
        -- Also disable mouse on all children that might be blocking
        local children = {blizzBar:GetChildren()}
        for _, child in ipairs(children) do
            if child.EnableMouse then
                child:EnableMouse(false)
            end
        end
    end
    
    -- Also handle visibility frame if different
    if info.visibilityFrame and info.visibilityFrame ~= info.frame then
        local visFrame = _G[info.visibilityFrame]
        if visFrame then
            visFrame:SetAlpha(0)
            visFrame:EnableMouse(false)
        end
    end
    
    -- Also handle selection frame if different
    if info.selectionFrame and info.selectionFrame ~= info.frame then
        local selFrame = _G[info.selectionFrame]
        if selFrame then
            selFrame:EnableMouse(false)
            -- Check for Selection child frame (Edit Mode)
            if selFrame.Selection then
                selFrame.Selection:EnableMouse(false)
                selFrame.Selection:Hide()
            end
        end
    end
    
    -- Handle the MainActionBar specifically for ActionBar1
    if barId == "ActionBar1" then
        local mainBar = _G["MainActionBar"]
        if mainBar then
            mainBar:SetAlpha(0)
            mainBar:EnableMouse(false)
            -- Disable all button containers
            for i = 1, 12 do
                local container = _G["MainActionBarButtonContainer" .. i]
                if container then
                    container:SetAlpha(0)
                    container:EnableMouse(false)
                end
            end
        end
        
        -- Also hide the art frame (gryphons, page arrows, etc)
        local artFrame = _G["MainMenuBarArtFrame"]
        if artFrame then
            artFrame:SetAlpha(0)
        end
    end
end

local function ShowBlizzardBar(barId)
    local info = BAR_INFO[barId]
    if not info then return end
    
    local blizzBar = _G[info.frame]
    if blizzBar then
        blizzBar:SetAlpha(1)
        blizzBar:EnableMouse(true)
        
        -- Re-enable mouse on children
        local children = {blizzBar:GetChildren()}
        for _, child in ipairs(children) do
            if child.EnableMouse then
                child:EnableMouse(true)
            end
        end
    end
    
    -- Also restore visibility frame if different
    if info.visibilityFrame and info.visibilityFrame ~= info.frame then
        local visFrame = _G[info.visibilityFrame]
        if visFrame then
            visFrame:SetAlpha(1)
            visFrame:EnableMouse(true)
        end
    end
    
    -- Also handle selection frame if different
    if info.selectionFrame and info.selectionFrame ~= info.frame then
        local selFrame = _G[info.selectionFrame]
        if selFrame then
            selFrame:SetAlpha(1)
            selFrame:EnableMouse(true)
            -- Show the Selection child if it exists
            if selFrame.Selection then
                -- Don't force show Selection - Edit Mode manages this
            end
        end
    end
    
    -- Handle the MainActionBar specifically for ActionBar1
    if barId == "ActionBar1" then
        local mainBar = _G["MainActionBar"]
        if mainBar then
            mainBar:SetAlpha(1)
            mainBar:EnableMouse(true)
            -- Also restore all button containers
            for i = 1, 12 do
                local container = _G["MainActionBarButtonContainer" .. i]
                if container then
                    container:SetAlpha(1)
                    container:EnableMouse(true)
                end
            end
        end
        
        -- Also show the art frame
        local artFrame = _G["MainMenuBarArtFrame"]
        if artFrame then
            artFrame:SetAlpha(1)
        end
    end
end

local function ReparentButtonsToWrapper(barId)
    local wrapper = barWrappers[barId]
    local info = BAR_INFO[barId]
    if not wrapper or not info then return end
    
    if InCombatLockdown() then
        QueueUpdate(barId)
        return
    end
    
    wrapper.buttons = wrapper.buttons or {}
    
    for i = 1, info.buttonCount do
        local button = _G[info.buttonPrefix .. i]
        if button then
            -- Store original parent if not already stored
            if not button._tuiOriginalParent then
                button._tuiOriginalParent = button:GetParent()
            end
            
            -- Reparent to our wrapper
            button:SetParent(wrapper.frame)
            wrapper.buttons[i] = button
        end
    end
    
    DebugPrint("Reparented buttons for", barId, "to TUIFrame wrapper")
end

local function RestoreButtonsToBlizzard(barId)
    local wrapper = barWrappers[barId]
    local info = BAR_INFO[barId]
    if not info then return end
    
    if InCombatLockdown() then
        QueueUpdate(barId)
        return
    end
    
    for i = 1, info.buttonCount do
        local button = _G[info.buttonPrefix .. i]
        if button and button._tuiOriginalParent then
            button:SetParent(button._tuiOriginalParent)
            button._tuiOriginalParent = nil
        end
    end
    
    -- Show Blizzard's bar again
    ShowBlizzardBar(barId)
    
    -- Hide our wrapper
    if wrapper then
        wrapper:Hide()
    end
    
    DebugPrint("Restored buttons for", barId, "to Blizzard")
end

-- ============================================================================
-- SYSTEM BAR WRAPPER MANAGEMENT (Micro Menu, Bags, Stance, Pet)
-- ============================================================================

local function GetSystemBarFrame(barId)
    local info = SYSTEM_BAR_INFO[barId]
    if not info then return nil end
    
    -- Try primary frame first
    local frame = _G[info.frame]
    if frame then return frame end
    
    -- Try fallback frames
    for _, frameName in ipairs(info.fallbackFrames or {}) do
        frame = _G[frameName]
        if frame then return frame end
    end
    
    return nil
end

local function GetOrCreateSystemBarWrapper(barId)
    -- Return existing wrapper if available
    if systemBarWrappers[barId] then
        return systemBarWrappers[barId]
    end
    
    -- Ensure TUIFrame is available
    if not TUIFrame then
        TUIFrame = TweaksUI.TUIFrame
    end
    if not TUIFrame then
        DebugPrint("TUIFrame not available yet for system bar")
        return nil
    end
    
    local info = SYSTEM_BAR_INFO[barId]
    if not info then return nil end
    
    local blizzFrame = GetSystemBarFrame(barId)
    if not blizzFrame then
        DebugPrint("System bar frame not found:", barId)
        return nil
    end
    
    -- Get frame dimensions
    local width = blizzFrame:GetWidth()
    local height = blizzFrame:GetHeight()
    
    -- Ensure minimum size
    if width < 10 then width = 200 end
    if height < 10 then height = 40 end
    
    -- Check for saved Layout position first
    local elementId = "systembar_" .. barId:lower()
    local savedPos = nil
    if TweaksUI.Layout then
        local layoutSettings = TweaksUI.Layout:GetSettings()
        if layoutSettings and layoutSettings.elements and layoutSettings.elements[elementId] then
            savedPos = layoutSettings.elements[elementId]
            DebugPrint("Found saved Layout position for", barId, "x:", savedPos.x, "y:", savedPos.y)
        end
    end
    
    -- Get default position (fallback)
    local defaultPos = SYSTEM_BAR_DEFAULT_POSITIONS[barId] or { point = "CENTER", x = 0, y = 0 }
    
    -- Use saved position or default
    local initX = savedPos and savedPos.x or defaultPos.x
    local initY = savedPos and savedPos.y or defaultPos.y
    local initPoint = savedPos and (savedPos.point or "BOTTOMLEFT") or defaultPos.point
    
    -- Create the wrapper using TUIFrame
    local wrapper = TUIFrame:New(elementId, {
        name = info.displayName,
        category = "System Bars",
        width = width,
        height = height,
        defaultPoint = initPoint,
        defaultX = initX,
        defaultY = initY,
    })
    
    if wrapper then
        wrapper.barId = barId
        wrapper.isSystemBar = true
        systemBarWrappers[barId] = wrapper
        
        -- Apply position using wrapper methods (handles CENTER coords and fade-in)
        if savedPos then
            wrapper:LoadSaveData(savedPos)
        else
            wrapper:SetPosition(initPoint, UIParent, initPoint, initX, initY)
        end
        
        DebugPrint("Created TUIFrame wrapper for system bar", barId, "size:", width, "x", height, "pos:", initX, initY)
    end
    
    return wrapper
end

local function RegisterSystemBarWithLayout(barId)
    -- Ensure Layout module is available
    if not Layout then
        Layout = TweaksUI.Layout
    end
    if not Layout then return end
    
    local wrapper = systemBarWrappers[barId]
    if not wrapper then return end
    
    local info = SYSTEM_BAR_INFO[barId]
    if not info then return end
    
    local elementId = "systembar_" .. barId:lower()
    
    -- Check if already registered - don't re-register to avoid position resets
    if Layout:GetElement(elementId) then
        DebugPrint("System bar", barId, "already registered with Layout")
        return
    end
    
    local defaultPos = SYSTEM_BAR_DEFAULT_POSITIONS[barId] or { point = "CENTER", x = 0, y = 0 }
    
    -- Check if there's already a saved position
    local layoutSettings = Layout:GetSettings()
    local savedPos = layoutSettings and layoutSettings.elements and layoutSettings.elements[elementId]
    if savedPos then
        TweaksUI:PrintDebug("ActionBars: Found saved position for " .. elementId .. ": x=" .. (savedPos.x or "nil") .. ", y=" .. (savedPos.y or "nil"))
    else
        TweaksUI:PrintDebug("ActionBars: No saved position for " .. elementId .. ", using default")
    end
    
    -- Register with Layout module under System Bars category
    Layout:RegisterElement(elementId, {
        name = info.displayName,
        category = "System Bars",
        tuiFrame = wrapper,
        defaultPosition = defaultPos,
    })
    
    DebugPrint("Registered system bar", barId, "with Layout module as", elementId)
end

local function ReparentSystemBarToWrapper(barId)
    local wrapper = systemBarWrappers[barId]
    local info = SYSTEM_BAR_INFO[barId]
    if not wrapper or not info then return end
    
    if InCombatLockdown() then
        DebugPrint("Cannot reparent system bar in combat:", barId)
        return
    end
    
    local blizzFrame = GetSystemBarFrame(barId)
    if not blizzFrame then return end
    
    -- Store original parent
    if not blizzFrame._tuiOriginalParent then
        blizzFrame._tuiOriginalParent = blizzFrame:GetParent()
    end
    
    -- Reparent to our wrapper
    blizzFrame:SetParent(wrapper.frame)
    blizzFrame:ClearAllPoints()
    blizzFrame:SetPoint("CENTER", wrapper.frame, "CENTER", 0, 0)
    
    -- Update wrapper size to match content
    local width = blizzFrame:GetWidth()
    local height = blizzFrame:GetHeight()
    if width > 10 and height > 10 then
        wrapper:SetSize(width, height)
    end
    
    DebugPrint("Reparented system bar", barId, "to TUIFrame wrapper")
end

local function RestoreSystemBarToBlizzard(barId)
    local wrapper = systemBarWrappers[barId]
    local info = SYSTEM_BAR_INFO[barId]
    if not info then return end
    
    if InCombatLockdown() then
        DebugPrint("Cannot restore system bar in combat:", barId)
        return
    end
    
    local blizzFrame = GetSystemBarFrame(barId)
    if not blizzFrame then return end
    
    -- Only restore if we actually modified this bar (has our marker)
    if not blizzFrame._tuiOriginalParent then
        -- We never touched this bar, don't modify it
        return
    end
    
    -- Restore to original parent
    blizzFrame:SetParent(blizzFrame._tuiOriginalParent)
    blizzFrame._tuiOriginalParent = nil
    
    -- DON'T clear points - let Blizzard's Edit Mode handle positioning
    -- Clearing points without setting new ones causes UIParentPanelManager to crash
    -- with "offset = nil" errors
    
    -- Hide our wrapper
    if wrapper then
        wrapper:Hide()
    end
    
    DebugPrint("Restored system bar", barId, "to Blizzard")
end

local function UpdateSystemBarVisibility(barId)
    local barSettings = settings and settings.systemBars and settings.systemBars[barId]
    if not barSettings then return end
    
    local wrapper = systemBarWrappers[barId]
    local blizzFrame = GetSystemBarFrame(barId)
    local frame = wrapper and wrapper.frame or blizzFrame
    if not frame then return end
    
    -- Helper to set alpha on both wrapper and content
    local function SetBarAlpha(alpha)
        if wrapper and wrapper.frame then
            wrapper.frame:SetAlpha(alpha)
        end
        if blizzFrame then
            blizzFrame:SetAlpha(alpha)
        end
    end
    
    -- Cleanup existing mouseover detection
    local function CleanupMouseover()
        if frame._tuiMouseoverFrame then
            frame._tuiMouseoverFrame:SetScript("OnUpdate", nil)
            frame._tuiMouseoverFrame:Hide()
            frame._tuiMouseoverFrame:SetParent(nil)
            frame._tuiMouseoverFrame = nil
        end
        frame._tuiMouseoverEnabled = nil
    end
    
    -- Force all visible mode bypasses all visibility conditions
    if TweaksUI.forceAllVisible then
        SetBarAlpha(barSettings.barAlpha or 1)
        CleanupMouseover()
        return
    end
    
    -- Always show in Layout mode for positioning
    local Layout = TweaksUI.Layout
    if Layout and Layout:IsActive() then
        SetBarAlpha(barSettings.barAlpha or 1)
        CleanupMouseover()
        return
    end
    
    -- If visibility not enabled, just use bar alpha
    if not barSettings.visibilityEnabled then
        SetBarAlpha(barSettings.barAlpha or 1)
        CleanupMouseover()
        return
    end
    
    -- Check visibility conditions
    local shouldShow = false
    local inCombat = InCombatLockdown()
    local hasTarget = UnitExists("target")
    local inGroup = IsInGroup()
    local inRaid = IsInRaid()
    local inInstance = IsInInstance()
    local isMounted = IsMounted()
    
    if barSettings.showInCombat and inCombat then shouldShow = true end
    if barSettings.showOutOfCombat and not inCombat then shouldShow = true end
    if barSettings.showWithTarget and hasTarget then shouldShow = true end
    if barSettings.showSolo and not inGroup then shouldShow = true end
    if barSettings.showInParty and inGroup and not inRaid then shouldShow = true end
    if barSettings.showInRaid and inRaid then shouldShow = true end
    if barSettings.showInInstance and inInstance then shouldShow = true end
    if barSettings.showMounted and isMounted then shouldShow = true end
    
    -- Apply visibility
    if shouldShow then
        SetBarAlpha(barSettings.barAlpha or 1)
        CleanupMouseover()
    else
        if barSettings.showOnMouseover then
            -- Create mouseover detection using OnUpdate (doesn't block clicks)
            if not frame._tuiMouseoverFrame then
                local detectFrame = CreateFrame("Frame", nil, frame)
                detectFrame:SetAllPoints(frame)
                
                -- Also cover the blizz frame area if different
                if blizzFrame and blizzFrame ~= frame then
                    detectFrame:SetPoint("TOPLEFT", blizzFrame, "TOPLEFT", -5, 5)
                    detectFrame:SetPoint("BOTTOMRIGHT", blizzFrame, "BOTTOMRIGHT", 5, -5)
                end
                
                -- Don't enable mouse - we just check position via OnUpdate
                detectFrame:EnableMouse(false)
                
                -- Track current visibility state - start as hidden (false)
                local isShowing = false
                detectFrame:SetScript("OnUpdate", function(self, elapsed)
                    -- Check if mouse is over the detection area or any child of blizzFrame
                    local mouseOver = self:IsMouseOver() or (blizzFrame and blizzFrame:IsMouseOver())
                    
                    if not mouseOver and blizzFrame then
                        -- Check children too
                        local children = {blizzFrame:GetChildren()}
                        for _, child in ipairs(children) do
                            if child:IsMouseOver() then
                                mouseOver = true
                                break
                            end
                        end
                    end
                    
                    -- Handle state transitions
                    if mouseOver and not isShowing then
                        -- Mouse entered - show bar
                        isShowing = true
                        SetBarAlpha(barSettings.barAlpha or 1)
                    elseif not mouseOver and isShowing then
                        -- Mouse left - hide bar
                        isShowing = false
                        SetBarAlpha(0)
                    end
                    -- Note: if mouseOver is false and isShowing is false, bar stays hidden
                    -- The initial SetBarAlpha(0) call below handles the first frame
                end)
                
                frame._tuiMouseoverFrame = detectFrame
                frame._tuiMouseoverEnabled = true
            end
            
            -- CRITICAL: Start hidden immediately - must happen AFTER OnUpdate is set up
            -- and every time this function is called to ensure bar stays hidden
            SetBarAlpha(0)
        else
            SetBarAlpha(0)
            CleanupMouseover()
        end
    end
end

local function ApplySystemBarLayout(barId)
    local barSettings = settings and settings.systemBars and settings.systemBars[barId]
    local info = SYSTEM_BAR_INFO[barId]
    if not barSettings or not info then return end
    
    -- If not enabled, restore to Blizzard
    if not barSettings.enabled then
        RestoreSystemBarToBlizzard(barId)
        return
    end
    
    -- Get or create wrapper
    local wrapper = GetOrCreateSystemBarWrapper(barId)
    if not wrapper then
        DebugPrint("Could not create wrapper for system bar", barId)
        return
    end
    
    -- Reparent Blizzard bar to our wrapper
    ReparentSystemBarToWrapper(barId)
    
    -- Show wrapper
    wrapper:Show()
    
    -- Register with Layout module
    RegisterSystemBarWithLayout(barId)
    
    -- Apply visibility settings
    UpdateSystemBarVisibility(barId)
    
    -- Start a sync ticker to keep Blizzard frame parented to wrapper
    -- This counteracts Blizzard code that tries to reposition system bars
    if not wrapper._syncTicker then
        wrapper._syncTicker = C_Timer.NewTicker(0.5, function()
            if InCombatLockdown() then return end
            
            local blizzFrame = GetSystemBarFrame(barId)
            if not blizzFrame then return end
            
            local barSettings = settings and settings.systemBars and settings.systemBars[barId]
            if not barSettings or not barSettings.enabled then
                -- Bar disabled, cancel ticker
                if wrapper._syncTicker then
                    wrapper._syncTicker:Cancel()
                    wrapper._syncTicker = nil
                end
                return
            end
            
            -- Ensure Blizzard frame is still parented to wrapper
            if blizzFrame:GetParent() ~= wrapper.frame then
                blizzFrame:SetParent(wrapper.frame)
                blizzFrame:ClearAllPoints()
                blizzFrame:SetPoint("CENTER", wrapper.frame, "CENTER", 0, 0)
            end
        end)
    end
    
    DebugPrint("Applied layout to system bar", barId)
end

local function ApplyAllSystemBarLayouts()
    for _, barId in ipairs(SYSTEM_BAR_ORDER) do
        ApplySystemBarLayout(barId)
    end
end

-- Apply visibility settings to all system bars (even if layout tweaks not enabled)
local function ApplyAllSystemBarVisibility()
    for _, barId in ipairs(SYSTEM_BAR_ORDER) do
        UpdateSystemBarVisibility(barId)
    end
end

-- ============================================================================
-- DEFAULT SETTINGS
-- ============================================================================

local function GetDefaultBarSettings()
    return {
        enabled = false,
        -- Layout
        buttonsShown = 12,    -- How many buttons to show (1-12)
        columns = 12,         -- Buttons per row (horizontal) or per column (vertical)
        orientation = "horizontal",  -- "horizontal" or "vertical"
        buttonSize = 45,
        horizontalSpacing = 6,
        verticalSpacing = 6,
        -- Visibility
        visibilityEnabled = false,
        showOnMouseover = false,
        showInCombat = true,
        showOutOfCombat = true,
        showWithTarget = true,
        showSolo = true,
        showInParty = true,
        showInRaid = true,
        showInInstance = true,
        showMounted = true,
        showInVehicle = true,
        showDragonriding = true,
        barAlpha = 1.0,         -- Overall action bar opacity
        buttonFrameAlpha = 1.0, -- Button frame/border opacity (0-1)
        -- Text/Overlay settings
        keybindAlpha = 1.0,     -- Keybind text opacity
        countAlpha = 1.0,       -- Stack count text opacity
        macroNameAlpha = 1.0,   -- Macro name text opacity
        pageArrowsAlpha = 1.0,  -- Page up/down arrows opacity (Bar 1 only)
        hideGryphons = false,   -- Hide gryphon art (Bar 1 only)
        -- Cooldown settings
        cooldownSwipeAlpha = 0.6,    -- Cooldown sweep/swipe opacity (0-1)
        cooldownNumbersEnabled = true, -- Show cooldown countdown numbers
        -- Range indicator settings
        rangeIndicatorEnabled = true,  -- Enable out-of-range indicator
        rangeIndicatorColor = {1, 0.1, 0.1, 0.4},  -- Red overlay color (r, g, b, a)
        -- Icon appearance
        iconEdgeStyle = "default",    -- "default" (Blizzard), "sharp" (zoomed), "rounded" (masked)
        iconZoom = 0.08,              -- Zoom amount for sharp style
        useMasque = false,            -- Use Masque skinning (requires Masque addon)
    }
end

local function GetDefaultSystemBarSettings()
    return {
        enabled = false,
        -- Visibility
        visibilityEnabled = false,
        showOnMouseover = false,
        showInCombat = true,
        showOutOfCombat = true,
        showWithTarget = true,
        showSolo = true,
        showInParty = true,
        showInRaid = true,
        showInInstance = true,
        showMounted = true,
        barAlpha = 1.0,
    }
end

local DEFAULT_SETTINGS = {
    enabled = false,
    bars = {},
    systemBars = {},
}

for barId, _ in pairs(BAR_INFO) do
    DEFAULT_SETTINGS.bars[barId] = GetDefaultBarSettings()
end

for barId, _ in pairs(SYSTEM_BAR_INFO) do
    DEFAULT_SETTINGS.systemBars[barId] = GetDefaultSystemBarSettings()
end

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

-- ============================================================================
-- COMBAT LOCKDOWN HANDLING
-- ============================================================================

local function IsInCombat()
    return InCombatLockdown()
end

local function QueueUpdate(barId)
    pendingUpdates[barId] = true
    if eventFrame then
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    end
end

local function ProcessPendingUpdates()
    if IsInCombat() then return end
    for barId, _ in pairs(pendingUpdates) do
        ActionBars:ApplyBarLayout(barId)
    end
    pendingUpdates = {}
end

-- ============================================================================
-- BUTTON POSITION STORAGE
-- ============================================================================

local function StoreOriginalPositions(barId)
    local info = BAR_INFO[barId]
    if not info then return end
    if originalButtonPositions[barId] then return end
    
    originalButtonPositions[barId] = {}
    
    for i = 1, info.buttonCount do
        local button = _G[info.buttonPrefix .. i]
        if button and button:GetNumPoints() > 0 then
            local point, relativeTo, relativePoint, x, y = button:GetPoint(1)
            local scale = button:GetScale()
            
            -- Get the true intrinsic size at scale 1
            local origScale = button:GetScale()
            button:SetScale(1)
            local baseWidth = button:GetWidth()
            local baseHeight = button:GetHeight()
            button:SetScale(origScale)
            
            -- Store icon anchor info
            local iconPoint, iconRelativeTo, iconRelativePoint, iconX, iconY
            local icon = button.icon or button.Icon
            if icon and icon:GetNumPoints() > 0 then
                iconPoint, iconRelativeTo, iconRelativePoint, iconX, iconY = icon:GetPoint(1)
            end
            
            originalButtonPositions[barId][i] = {
                point = point,
                relativeTo = relativeTo,
                relativePoint = relativePoint,
                x = x,
                y = y,
                scale = scale,
                baseWidth = baseWidth,
                baseHeight = baseHeight,
                iconPoint = iconPoint,
                iconRelativeTo = iconRelativeTo,
                iconRelativePoint = iconRelativePoint,
                iconX = iconX,
                iconY = iconY,
            }
        end
    end
    DebugPrint("Stored original positions for", barId)
end

local function RestoreOriginalPositions(barId)
    local info = BAR_INFO[barId]
    if not info then return end
    
    local positions = originalButtonPositions[barId]
    if not positions then return end
    
    if IsInCombat() then
        QueueUpdate(barId)
        return
    end
    
    for i = 1, info.buttonCount do
        local button = _G[info.buttonPrefix .. i]
        local pos = positions[i]
        if button and pos and pos.relativeTo then
            -- Reset scale, restore position, restore original scale
            button:SetScale(1)
            button:ClearAllPoints()
            button:SetPoint(pos.point or "CENTER", pos.relativeTo, pos.relativePoint or "CENTER", pos.x or 0, pos.y or 0)
            button:SetScale(pos.scale or 1)
            
            -- Restore icon anchor
            local icon = button.icon or button.Icon
            if icon and pos.iconPoint then
                icon:ClearAllPoints()
                icon:SetPoint(pos.iconPoint, pos.iconRelativeTo or button, pos.iconRelativePoint or pos.iconPoint, pos.iconX or 0, pos.iconY or 0)
            end
            
            -- Restore button frame alpha
            local normalTex = button.NormalTexture or button:GetNormalTexture()
            if normalTex then
                normalTex:SetAlpha(1)
            end
            if button.FloatingBG then
                button.FloatingBG:SetAlpha(1)
            end
            if button.Border then
                button.Border:SetAlpha(1)
            end
            if button.SlotArt then
                button.SlotArt:SetAlpha(1)
            end
            if button.SlotBackground then
                button.SlotBackground:SetAlpha(1)
            end
            
            button:SetAlpha(1)
        end
    end
    DebugPrint("Restored original positions for", barId)
end

-- ============================================================================
-- LAYOUT SYSTEM (TUIFrame-based)
-- ============================================================================

function ActionBars:ApplyBarLayout(barId)
    if IsInCombat() then
        QueueUpdate(barId)
        DebugPrint("Layout queued for", barId, "(in combat)")
        return
    end
    
    local barSettings = settings and settings.bars and settings.bars[barId]
    local info = BAR_INFO[barId]
    
    if not barSettings or not info then
        DebugPrint("No settings or info for", barId)
        return
    end
    
    -- If not enabled, restore buttons to Blizzard and return
    if not barSettings.enabled then
        RestoreButtonsToBlizzard(barId)
        RestoreOriginalPositions(barId)
        return
    end
    
    -- Store original positions before modifying
    StoreOriginalPositions(barId)
    
    -- Get or create TUIFrame wrapper
    local wrapper = GetOrCreateBarWrapper(barId)
    
    if not wrapper then
        DebugPrint("Could not create wrapper for", barId)
        -- Fall back to positioning within Blizzard bar
        local bar = _G[info.frame]
        if not bar then return end
        self:ApplyBarLayoutLegacy(barId)
        return
    end
    
    -- Reparent buttons to our wrapper
    ReparentButtonsToWrapper(barId)
    
    -- Hide Blizzard's bar container
    HideBlizzardBar(barId)
    
    -- Show our wrapper
    wrapper:Show()
    
    -- CRITICAL: If visibility settings are enabled, start hidden immediately
    -- This prevents the bar from flashing visible before visibility conditions are checked
    if barSettings.visibilityEnabled then
        -- Start with alpha 0 - the visibility updater will show it when conditions are met
        if wrapper.frame then
            wrapper.frame:SetAlpha(0)
        end
        -- Initialize the target alpha tracking so we don't re-fade on first update
        if wrapper.frame then
            wrapper.frame.tweaksTargetAlpha = 0
        end
    end
    
    -- Get layout settings
    local buttonsShown = barSettings.buttonsShown or 12
    local cols = barSettings.columns or 12
    local size = barSettings.buttonSize or 45
    local hSpacing = barSettings.horizontalSpacing or 6
    local vSpacing = barSettings.verticalSpacing or 6
    local orientation = barSettings.orientation or "horizontal"
    
    DebugPrint("Applying layout to", barId, "- size:", size, "scale:", size/45)
    
    -- Calculate rows from buttons and columns
    local rows = math.ceil(buttonsShown / cols)
    
    -- Base size is always 45 for WoW action buttons
    local baseSize = 45
    local scale = size / baseSize
    
    -- Get button frame alpha setting
    local buttonFrameAlpha = barSettings.buttonFrameAlpha or 1.0
    
    DebugPrint("Applying layout to", barId, "- size:", size, "scale:", scale)
    
    -- Position each button within our wrapper
    for i = 1, info.buttonCount do
        local button = _G[info.buttonPrefix .. i]
        if button then
            local row, col
            if orientation == "vertical" then
                col = math.floor((i - 1) / rows)
                row = (rows - 1) - ((i - 1) % rows)
            else
                row = math.floor((i - 1) / cols)
                col = (i - 1) % cols
            end
            
            -- Calculate screen-space position
            local xOffset = col * (size + hSpacing)
            local yOffset = row * (size + vSpacing)
            
            -- Reset and set scale
            button:SetScale(1)
            button:ClearAllPoints()
            button:SetScale(scale)
            
            -- Position within wrapper (divide by scale for scaled space)
            button:SetPoint("BOTTOMLEFT", wrapper.frame, "BOTTOMLEFT", xOffset / scale, yOffset / scale)
            
            -- Ensure icon fills button frame
            local icon = button.icon or button.Icon
            if icon then
                icon:ClearAllPoints()
                icon:SetAllPoints(button)
            end
            
            -- Apply button frame alpha
            local normalTex = button.NormalTexture or button:GetNormalTexture()
            if normalTex then normalTex:SetAlpha(buttonFrameAlpha) end
            if button.FloatingBG then button.FloatingBG:SetAlpha(buttonFrameAlpha) end
            if button.Border then button.Border:SetAlpha(buttonFrameAlpha) end
            if button.SlotArt then button.SlotArt:SetAlpha(buttonFrameAlpha) end
            if button.SlotBackground then button.SlotBackground:SetAlpha(buttonFrameAlpha) end
            
            -- Show/hide based on buttonsShown
            button:SetAlpha(i <= buttonsShown and 1 or 0)
            
            -- Apply cooldown settings
            local cooldown = button.cooldown or button.Cooldown or _G[button:GetName() .. "Cooldown"]
            if cooldown then
                local swipeAlpha = barSettings.cooldownSwipeAlpha or 0.6
                cooldown:SetSwipeColor(0, 0, 0, swipeAlpha)
                local showNumbers = barSettings.cooldownNumbersEnabled
                if showNumbers == nil then showNumbers = true end
                cooldown:SetHideCountdownNumbers(not showNumbers)
            end
        end
    end
    
    -- Update wrapper size
    UpdateBarWrapperSize(barId)
    
    -- Register with Layout module if not already
    RegisterBarWithLayout(barId)
    
    DebugPrint("Layout complete for", barId, "(TUIFrame wrapper)")
end

-- Legacy layout function (fallback if TUIFrame not available)
function ActionBars:ApplyBarLayoutLegacy(barId)
    local barSettings = settings and settings.bars and settings.bars[barId]
    local info = BAR_INFO[barId]
    if not barSettings or not info then return end
    
    local bar = _G[info.frame]
    if not bar then return end
    
    local buttonsShown = barSettings.buttonsShown or 12
    local cols = barSettings.columns or 12
    local size = barSettings.buttonSize or 45
    local hSpacing = barSettings.horizontalSpacing or 6
    local vSpacing = barSettings.verticalSpacing or 6
    local orientation = barSettings.orientation or "horizontal"
    local rows = math.ceil(buttonsShown / cols)
    local baseSize = 45
    local scale = size / baseSize
    local buttonFrameAlpha = barSettings.buttonFrameAlpha or 1.0
    
    for i = 1, info.buttonCount do
        local button = _G[info.buttonPrefix .. i]
        if button then
            local row, col
            if orientation == "vertical" then
                col = math.floor((i - 1) / rows)
                row = (rows - 1) - ((i - 1) % rows)
            else
                row = math.floor((i - 1) / cols)
                col = (i - 1) % cols
            end
            
            local xOffset = col * (size + hSpacing)
            local yOffset = row * (size + vSpacing)
            
            button:SetScale(1)
            button:ClearAllPoints()
            button:SetScale(scale)
            button:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", xOffset / scale, yOffset / scale)
            
            local icon = button.icon or button.Icon
            if icon then
                icon:ClearAllPoints()
                icon:SetAllPoints(button)
            end
            
            local normalTex = button.NormalTexture or button:GetNormalTexture()
            if normalTex then normalTex:SetAlpha(buttonFrameAlpha) end
            if button.FloatingBG then button.FloatingBG:SetAlpha(buttonFrameAlpha) end
            if button.Border then button.Border:SetAlpha(buttonFrameAlpha) end
            if button.SlotArt then button.SlotArt:SetAlpha(buttonFrameAlpha) end
            if button.SlotBackground then button.SlotBackground:SetAlpha(buttonFrameAlpha) end
            
            button:SetAlpha(i <= buttonsShown and 1 or 0)
            
            local cooldown = button.cooldown or button.Cooldown or _G[button:GetName() .. "Cooldown"]
            if cooldown then
                local swipeAlpha = barSettings.cooldownSwipeAlpha or 0.6
                cooldown:SetSwipeColor(0, 0, 0, swipeAlpha)
                local showNumbers = barSettings.cooldownNumbersEnabled
                if showNumbers == nil then showNumbers = true end
                cooldown:SetHideCountdownNumbers(not showNumbers)
            end
        end
    end
end

-- Update Edit Mode selection frame for a specific bar
function ActionBars:UpdateEditModeFrame(barId, width, height)
    -- DISABLED: Resizing the frame causes position jumping on zone transitions
    -- The Edit Mode selection box won't match our custom layout, but position will be stable
    return
end

-- Debug function to find Edit Mode frame structure
function ActionBars:DebugEditModeFrames(barId)
    local info = BAR_INFO[barId or "ActionBar1"]
    if not info then 
        print("No bar info found")
        return 
    end
    
    local bar = _G[info.frame]
    if not bar then 
        print("Bar frame not found:", info.frame)
        return 
    end
    
    local barSettings = settings and settings.bars and settings.bars[barId]
    
    print("=== Edit Mode Debug for", barId or "ActionBar1", "===")
    
    -- Show our settings
    print("--- Our Settings ---")
    if barSettings then
        print("  enabled:", barSettings.enabled and "yes" or "no")
        print("  buttonsShown:", barSettings.buttonsShown or "nil")
        print("  columns:", barSettings.columns or "nil")
        print("  buttonSize:", barSettings.buttonSize or "nil")
        print("  hSpacing:", barSettings.horizontalSpacing or "nil")
        print("  vSpacing:", barSettings.verticalSpacing or "nil")
        print("  orientation:", barSettings.orientation or "nil")
        
        -- Calculate what size SHOULD be
        local buttonsShown = barSettings.buttonsShown or 12
        local cols = barSettings.columns or 12
        local size = barSettings.buttonSize or 45
        local hSpacing = barSettings.horizontalSpacing or 6
        local vSpacing = barSettings.verticalSpacing or 6
        local orientation = barSettings.orientation or "horizontal"
        local rows = math.ceil(buttonsShown / cols)
        local actualCols = math.min(cols, buttonsShown)
        
        -- Width is always based on columns, height on rows
        -- Orientation only changes how buttons are laid out, not the frame dimensions
        local calcWidth = actualCols * size + (actualCols - 1) * hSpacing
        local calcHeight = rows * size + (rows - 1) * vSpacing
        print("  Calculated size should be:", calcWidth, "x", calcHeight)
    else
        print("  No settings found!")
    end
    
    print("--- Frame Info ---")
    print("Button container:", info.frame)
    print("  Size:", string.format("%.1f x %.1f", bar:GetWidth(), bar:GetHeight()))
    print("  tweaksCustomWidth:", bar.tweaksCustomWidth or "nil")
    print("  tweaksCustomHeight:", bar.tweaksCustomHeight or "nil")
    
    -- Check the selection parent frame
    local selectionParentName = info.selectionFrame or info.frame
    print("Selection parent:", selectionParentName)
    
    local selectionParent = _G[selectionParentName]
    if selectionParent then
        print("  Size:", string.format("%.1f x %.1f", selectionParent:GetWidth(), selectionParent:GetHeight()))
        
        if selectionParent.Selection then
            local sel = selectionParent.Selection
            print("  Selection exists, size:", string.format("%.1f x %.1f", sel:GetWidth(), sel:GetHeight()))
            print("  Selection shown:", sel:IsShown() and "yes" or "no")
            
            -- Check anchoring
            local numPoints = sel:GetNumPoints()
            print("  Selection anchors:", numPoints)
            for i = 1, numPoints do
                local point, relativeTo, relativePoint, x, y = sel:GetPoint(i)
                local relName = relativeTo and (relativeTo:GetName() or "unnamed") or "nil"
                print(string.format("    %d: %s -> %s:%s (%.1f, %.1f)", i, point, relName, relativePoint or "?", x or 0, y or 0))
            end
        else
            print("  Selection: nil")
        end
    else
        print("  Selection parent not found!")
    end
    
    print("Edit Mode active:", EditModeManagerFrame and EditModeManagerFrame.editModeActive and "yes" or "no")
    print("=== End Debug ===")
end

-- Update all Edit Mode frames
function ActionBars:UpdateAllEditModeFrames()
    for _, barId in ipairs(BAR_ORDER) do
        local barSettings = settings and settings.bars and settings.bars[barId]
        if barSettings and barSettings.enabled then
            local info = BAR_INFO[barId]
            if info then
                local bar = _G[info.frame]
                if bar then
                    local width, height
                    
                    -- Use stored custom size if available
                    if bar.tweaksCustomWidth and bar.tweaksCustomHeight then
                        width = bar.tweaksCustomWidth
                        height = bar.tweaksCustomHeight
                    else
                        -- Calculate from settings
                        local buttonsShown = barSettings.buttonsShown or 12
                        local cols = barSettings.columns or 12
                        local size = barSettings.buttonSize or 45
                        local hSpacing = barSettings.horizontalSpacing or 6
                        local vSpacing = barSettings.verticalSpacing or 6
                        local orientation = barSettings.orientation or "horizontal"
                        
                        local rows = math.ceil(buttonsShown / cols)
                        local actualCols = math.min(cols, buttonsShown)
                        
                        -- Width is always based on columns, height on rows
                        width = actualCols * size + (actualCols - 1) * hSpacing
                        height = rows * size + (rows - 1) * vSpacing
                        
                        -- Store for future use
                        bar.tweaksCustomWidth = width
                        bar.tweaksCustomHeight = height
                    end
                    
                    self:UpdateEditModeFrame(barId, width, height)
                end
            end
        end
    end
end

function ActionBars:ApplyAllLayouts()
    for _, barId in ipairs(BAR_ORDER) do
        self:ApplyBarLayout(barId)
    end
end

-- Refresh all bars from database settings (used when presets are applied)
function ActionBars:RefreshFromDatabase()
    -- Clear cached settings
    settings = nil
    
    -- Re-load settings from database
    settings = TweaksUI.Database:GetModuleSettings(TweaksUI.MODULE_IDS.ACTION_BARS)
    
    if not settings or not next(settings) then
        -- Create defaults and save to database so both point to same object
        local defaults = DeepCopy(DEFAULT_SETTINGS)
        TweaksUI.Database:SetModuleSettings(TweaksUI.MODULE_IDS.ACTION_BARS, defaults)
        settings = TweaksUI.Database:GetModuleSettings(TweaksUI.MODULE_IDS.ACTION_BARS)
    end
    EnsureDefaults(settings, DEFAULT_SETTINGS)
    
    -- Apply all settings
    if not InCombatLockdown() then
        self:ApplyAllLayouts()
        ApplyAllSystemBarLayouts()
        self:ApplyAllVisibility()
        ApplyAllSystemBarVisibility()
        self:ApplyAllTextSettings()
        self:ApplyAllCooldownSettings()
        self:ApplyAllRangeIndicators()
        self:ApplyAllIconEdgeStyles()
        self:ApplyGryphonVisibility()
    end
    
    if TweaksUI.PrintDebug then
        TweaksUI:PrintDebug("ActionBars: Refreshed from database")
    end
    
    return true
end

function ActionBars:RestoreAllLayouts()
    for _, barId in ipairs(BAR_ORDER) do
        RestoreOriginalPositions(barId)
    end
end

-- ============================================================================
-- VISIBILITY SYSTEM (OR logic - show if ANY condition is met)
-- ============================================================================

local visibilityFrames = {}  -- Track visibility state per bar

local function GetVisibilityFrame(barId)
    -- Prefer our TUIFrame wrapper if available
    local wrapper = barWrappers[barId]
    if wrapper and wrapper.frame then
        return wrapper.frame
    end
    
    -- Fall back to Blizzard frame
    local info = BAR_INFO[barId]
    if not info then return nil end
    
    local visibilityFrameName = info.visibilityFrame or info.frame
    return _G[visibilityFrameName]
end

local function UpdateBarVisibility(barId)
    local barSettings = settings and settings.bars and settings.bars[barId]
    local info = BAR_INFO[barId]
    
    if not barSettings or not info then return end
    
    -- Get the frame to control visibility on (prefer wrapper)
    local bar = GetVisibilityFrame(barId)
    if not bar then return end
    
    -- Store original alpha if needed
    if not bar.tweaksOriginalAlpha then
        local currentAlpha = bar:GetAlpha()
        bar.tweaksOriginalAlpha = (currentAlpha > 0) and currentAlpha or 1
    end
    
    local barAlpha = barSettings.barAlpha or 1.0
    
    -- If tweaks not enabled, restore original alpha
    if not barSettings.enabled then
        bar:SetAlpha(bar.tweaksOriginalAlpha or 1)
        return
    end
    
    -- Force all visible mode bypasses all visibility conditions
    if TweaksUI.forceAllVisible then
        bar:SetAlpha(barAlpha)
        return
    end
    
    -- Always show in Layout mode for positioning
    local Layout = TweaksUI.Layout
    if Layout and Layout:IsActive() then
        bar:SetAlpha(barAlpha)
        return
    end
    
    -- If visibility rules not enabled, just apply bar alpha
    if not barSettings.visibilityEnabled then
        bar:SetAlpha(barAlpha)
        return
    end
    
    -- Check all conditions (OR logic)
    local shouldShow = false
    
    -- Mouseover check
    if barSettings.showOnMouseover and bar.tweaksIsMouseOver then
        shouldShow = true
    end
    
    -- Combat check
    if barSettings.showInCombat and UnitAffectingCombat("player") then
        shouldShow = true
    end
    
    -- Out of combat check
    if barSettings.showOutOfCombat and not UnitAffectingCombat("player") then
        shouldShow = true
    end
    
    -- Target check
    if barSettings.showWithTarget and UnitExists("target") then
        shouldShow = true
    end
    
    -- Group checks
    if barSettings.showSolo and not IsInGroup() then
        shouldShow = true
    end
    if barSettings.showInParty and IsInGroup() and not IsInRaid() then
        shouldShow = true
    end
    if barSettings.showInRaid and IsInRaid() then
        shouldShow = true
    end
    
    -- Instance check
    if barSettings.showInInstance then
        local inInstance, instanceType = IsInInstance()
        if inInstance and (instanceType == "party" or instanceType == "raid") then
            shouldShow = true
        end
    end
    
    -- Mounted check
    if barSettings.showMounted and IsMounted() then
        shouldShow = true
    end
    
    -- Dragonriding/Skyriding check
    if barSettings.showDragonriding then
        local isDragonriding = false
        
        -- When dragonriding/skyriding, player is mounted and has the override bar active
        if IsMounted() then
            -- Check if we have the dragonriding action bar active
            -- HasBonusActionBar or HasOverrideActionBar indicates special mount bar
            if HasBonusActionBar and HasBonusActionBar() then
                isDragonriding = true
            elseif HasOverrideActionBar and HasOverrideActionBar() then
                isDragonriding = true
            end
            
            -- Alternative: check for Vigor power (power type 26 in some versions)
            if not isDragonriding then
                -- Check alternate power while mounted
                local maxVigor = UnitPowerMax("player", Enum.PowerType.Alternate or 10)
                if maxVigor and maxVigor > 0 then
                    isDragonriding = true
                end
            end
        end
        
        if isDragonriding then
            shouldShow = true
        end
    end
    
    -- Vehicle check
    if barSettings.showInVehicle and UnitInVehicle("player") then
        shouldShow = true
    end
    
    -- Apply visibility - use bar alpha when visible, 0 when hidden
    local targetAlpha = shouldShow and barAlpha or 0
    
    -- On initial setup (first time setting target), snap immediately instead of fading
    -- This prevents bars from being visible on first load when they should be hidden
    local isInitialSetup = bar.tweaksTargetAlpha == nil
    
    -- Smooth fade
    if bar.tweaksTargetAlpha ~= targetAlpha then
        bar.tweaksTargetAlpha = targetAlpha
        
        if isInitialSetup then
            -- Snap immediately on first setup to prevent flash on load
            bar:SetAlpha(targetAlpha)
            bar.tweaksFading = false
        else
            bar.tweaksFading = true
        end
    end
end

local function SetupVisibilityUpdater(barId)
    local info = BAR_INFO[barId]
    if not info then return end
    
    -- Get the frame to control visibility on (prefer wrapper)
    local bar = GetVisibilityFrame(barId)
    if not bar then return end
    
    -- Don't setup twice
    if bar.tweaksVisibilityUpdater then return end
    
    local detector = CreateFrame("Frame", nil, bar)
    detector:SetAllPoints(bar)
    detector:EnableMouse(false)
    detector:SetMouseClickEnabled(false)
    
    -- Initialize mouseover state to false (not over until proven otherwise)
    bar.tweaksIsMouseOver = false
    
    detector.throttle = 0
    detector:SetScript("OnUpdate", function(self, elapsed)
        self.throttle = self.throttle + elapsed
        
        -- Check mouseover every frame for responsiveness
        local mouseOver = bar:IsMouseOver()
        
        -- Also check children (buttons) if not over the main frame
        if not mouseOver then
            local children = {bar:GetChildren()}
            for _, child in ipairs(children) do
                if child:IsMouseOver() then
                    mouseOver = true
                    break
                end
            end
        end
        
        -- Also check the wrapper's buttons specifically
        local wrapper = barWrappers[barId]
        if not mouseOver and wrapper and wrapper.buttons then
            for _, button in pairs(wrapper.buttons) do
                if button and button:IsMouseOver() then
                    mouseOver = true
                    break
                end
            end
        end
        
        -- Check original Blizzard buttons by name
        if not mouseOver and info.buttonPrefix then
            for i = 1, (info.buttonCount or 12) do
                local button = _G[info.buttonPrefix .. i]
                if button and button:IsMouseOver() then
                    mouseOver = true
                    break
                end
            end
        end
        
        if mouseOver ~= bar.tweaksIsMouseOver then
            bar.tweaksIsMouseOver = mouseOver
            UpdateBarVisibility(barId)
        end
        
        -- Check other conditions less frequently
        if self.throttle >= 0.1 then
            self.throttle = 0
            UpdateBarVisibility(barId)
        end
        
        -- Handle fading
        if bar.tweaksFading then
            local current = bar:GetAlpha()
            local target = bar.tweaksTargetAlpha or 1
            local step = elapsed * 5  -- Fade speed
            
            if current < target then
                bar:SetAlpha(math.min(current + step, target))
            elseif current > target then
                bar:SetAlpha(math.max(current - step, target))
            end
            
            if math.abs(current - target) < 0.01 then
                bar:SetAlpha(target)
                bar.tweaksFading = false
            end
        end
    end)
    
    bar.tweaksVisibilityUpdater = detector
    visibilityFrames[barId] = detector
    
    -- Apply initial visibility state immediately (handles mouseover starting hidden)
    UpdateBarVisibility(barId)
end

local function TeardownVisibilityUpdater(barId)
    local info = BAR_INFO[barId]
    if not info then return end
    
    -- Get the frame to control visibility on (prefer wrapper)
    local bar = GetVisibilityFrame(barId)
    if not bar then return end
    
    if bar.tweaksVisibilityUpdater then
        bar.tweaksVisibilityUpdater:SetScript("OnUpdate", nil)
        bar.tweaksVisibilityUpdater:Hide()
        bar.tweaksVisibilityUpdater = nil
    end
    
    -- Reset state
    bar.tweaksIsMouseOver = nil
    bar.tweaksFading = nil
    bar.tweaksTargetAlpha = nil
    
    -- Restore alpha
    if bar.tweaksOriginalAlpha then
        bar:SetAlpha(bar.tweaksOriginalAlpha)
    else
        bar:SetAlpha(1)
    end
    
    visibilityFrames[barId] = nil
end

function ActionBars:ApplyVisibility(barId)
    local barSettings = settings and settings.bars and settings.bars[barId]
    
    if not barSettings then return end
    
    if barSettings.enabled and barSettings.visibilityEnabled then
        SetupVisibilityUpdater(barId)
        UpdateBarVisibility(barId)
    else
        TeardownVisibilityUpdater(barId)
        -- Still apply alpha even when visibility rules are off
        UpdateBarVisibility(barId)
    end
end

function ActionBars:ApplyAllVisibility()
    for _, barId in ipairs(BAR_ORDER) do
        self:ApplyVisibility(barId)
    end
end

-- ============================================================================
-- TEXT OVERLAY SETTINGS
-- ============================================================================

function ActionBars:ApplyTextSettings(barId)
    local barSettings = settings and settings.bars and settings.bars[barId]
    local info = BAR_INFO[barId]
    
    if not barSettings or not info then return end
    if not barSettings.enabled then return end
    
    local keybindAlpha = barSettings.keybindAlpha or 1
    local countAlpha = barSettings.countAlpha or 1
    local macroNameAlpha = barSettings.macroNameAlpha or 1
    
    -- Apply to each button
    for i = 1, info.buttonCount do
        local button = _G[info.buttonPrefix .. i]
        if button then
            -- Keybind/Hotkey text
            local hotKey = button.HotKey or _G[button:GetName() .. "HotKey"]
            if hotKey then
                hotKey:SetAlpha(keybindAlpha)
            end
            
            -- Stack count text
            local count = button.Count or _G[button:GetName() .. "Count"]
            if count then
                count:SetAlpha(countAlpha)
            end
            
            -- Macro name text
            local name = button.Name or _G[button:GetName() .. "Name"]
            if name then
                name:SetAlpha(macroNameAlpha)
            end
        end
    end
    
    -- Page arrows for Action Bar 1 only
    if barId == "ActionBar1" then
        local pageArrowsAlpha = barSettings.pageArrowsAlpha or 1
        
        -- The page number container and its children
        if MainActionBar and MainActionBar.ActionBarPageNumber then
            local pageNumber = MainActionBar.ActionBarPageNumber
            
            -- Set alpha on the whole container
            pageNumber:SetAlpha(pageArrowsAlpha)
            
            -- Also explicitly set on children in case they have separate alpha
            if pageNumber.UpButton then
                pageNumber.UpButton:SetAlpha(pageArrowsAlpha)
            end
            if pageNumber.DownButton then
                pageNumber.DownButton:SetAlpha(pageArrowsAlpha)
            end
            if pageNumber.Text then
                pageNumber.Text:SetAlpha(pageArrowsAlpha)
            end
        end
    end
    
    DebugPrint("Applied text settings for", barId)
end

function ActionBars:ApplyAllTextSettings()
    for _, barId in ipairs(BAR_ORDER) do
        self:ApplyTextSettings(barId)
    end
end

-- Apply cooldown settings to a specific bar (works regardless of layout enabled state)
function ActionBars:ApplyCooldownSettings(barId)
    local barSettings = settings and settings.bars and settings.bars[barId]
    local info = BAR_INFO[barId]
    
    if not barSettings or not info then return end
    
    local swipeAlpha = barSettings.cooldownSwipeAlpha
    if swipeAlpha == nil then swipeAlpha = 0.6 end
    
    local showNumbers = barSettings.cooldownNumbersEnabled
    if showNumbers == nil then showNumbers = true end
    
    -- Apply to each button
    for i = 1, info.buttonCount do
        local button = _G[info.buttonPrefix .. i]
        if button then
            local cooldown = button.cooldown or button.Cooldown or _G[button:GetName() .. "Cooldown"]
            if cooldown then
                cooldown:SetSwipeColor(0, 0, 0, swipeAlpha)
                cooldown:SetHideCountdownNumbers(not showNumbers)
            end
        end
    end
    
    DebugPrint("Applied cooldown settings for", barId)
end

function ActionBars:ApplyAllCooldownSettings()
    for _, barId in ipairs(BAR_ORDER) do
        self:ApplyCooldownSettings(barId)
    end
end

-- ============================================================================
-- RANGE INDICATOR SYSTEM
-- Applies a red overlay to action buttons when the spell is out of range
-- ============================================================================

local rangeIndicatorOverlays = {}  -- [buttonName] = overlayTexture
local rangeCheckFrame = nil
local RANGE_CHECK_INTERVAL = 0.1  -- Check range every 100ms

-- Create or get range indicator overlay for a button
local function GetOrCreateRangeOverlay(button)
    local name = button:GetName()
    if not name then return nil end
    
    if rangeIndicatorOverlays[name] then
        return rangeIndicatorOverlays[name]
    end
    
    local overlay = button:CreateTexture(nil, "OVERLAY", nil, 7)
    overlay:SetAllPoints(button.icon or button.Icon or button)
    overlay:SetColorTexture(1, 0.1, 0.1, 0.4)
    overlay:Hide()
    
    rangeIndicatorOverlays[name] = overlay
    return overlay
end

-- Update range indicator for a single button
local function UpdateButtonRangeIndicator(button, overlay, color)
    if not button or not overlay then return end
    
    local action = button.action or (button.GetAction and button:GetAction())
    if not action then
        overlay:Hide()
        return
    end
    
    -- Check if action is valid and has a usable spell
    local isUsable, notEnoughMana = IsUsableAction(action)
    local inRange = IsActionInRange(action)
    
    -- Only show out of range indicator for usable spells that are out of range
    -- inRange returns nil if not applicable, false if out of range, true if in range
    if isUsable and inRange == false then
        if color and type(color) == "table" then
            overlay:SetColorTexture(color[1] or 1, color[2] or 0.1, color[3] or 0.1, color[4] or 0.4)
        end
        overlay:Show()
    else
        overlay:Hide()
    end
end

-- Apply range indicator settings to a specific bar
function ActionBars:ApplyRangeIndicator(barId)
    local barSettings = settings and settings.bars and settings.bars[barId]
    local info = BAR_INFO[barId]
    
    if not barSettings or not info then return end
    
    local enabled = barSettings.rangeIndicatorEnabled
    local color = barSettings.rangeIndicatorColor or {1, 0.1, 0.1, 0.4}
    
    -- Apply to each button
    for i = 1, info.buttonCount do
        local button = _G[info.buttonPrefix .. i]
        if button then
            local overlay = GetOrCreateRangeOverlay(button)
            if overlay then
                if enabled then
                    -- Store settings on overlay for OnUpdate handler
                    overlay._TUI_rangeEnabled = true
                    overlay._TUI_rangeColor = color
                else
                    overlay._TUI_rangeEnabled = false
                    overlay:Hide()
                end
            end
        end
    end
    
    -- Ensure range check frame is running if any bar has range indicator enabled
    self:UpdateRangeCheckFrame()
end

function ActionBars:ApplyAllRangeIndicators()
    for _, barId in ipairs(BAR_ORDER) do
        self:ApplyRangeIndicator(barId)
    end
end

-- Check if any bar has range indicator enabled
local function AnyRangeIndicatorEnabled()
    if not settings or not settings.bars then return false end
    
    for _, barId in ipairs(BAR_ORDER) do
        local barSettings = settings.bars[barId]
        if barSettings and barSettings.rangeIndicatorEnabled then
            return true
        end
    end
    return false
end

-- Create/manage the range check OnUpdate frame
function ActionBars:UpdateRangeCheckFrame()
    if AnyRangeIndicatorEnabled() then
        -- Create frame if needed
        if not rangeCheckFrame then
            rangeCheckFrame = CreateFrame("Frame")
            rangeCheckFrame.elapsed = 0
            rangeCheckFrame:SetScript("OnUpdate", function(self, elapsed)
                self.elapsed = self.elapsed + elapsed
                if self.elapsed >= RANGE_CHECK_INTERVAL then
                    self.elapsed = 0
                    
                    -- Update all buttons with range indicator enabled
                    for buttonName, overlay in pairs(rangeIndicatorOverlays) do
                        if overlay._TUI_rangeEnabled then
                            local button = _G[buttonName]
                            if button and button:IsVisible() then
                                UpdateButtonRangeIndicator(button, overlay, overlay._TUI_rangeColor)
                            else
                                overlay:Hide()
                            end
                        end
                    end
                end
            end)
        end
        rangeCheckFrame:Show()
    else
        -- Hide frame if no range indicators are enabled
        if rangeCheckFrame then
            rangeCheckFrame:Hide()
        end
    end
end

-- ============================================================================
-- ICON EDGE STYLE SYSTEM
-- Applies different edge treatments (sharp, rounded, default) to action button icons
-- ============================================================================

local buttonIconMasks = {}  -- [buttonName] = maskTexture

-- Get or create mask texture for a button's icon
local function GetOrCreateIconMask(button)
    local name = button:GetName()
    if not name then return nil end
    
    if buttonIconMasks[name] then
        return buttonIconMasks[name]
    end
    
    local icon = button.icon or button.Icon
    if not icon then return nil end
    
    local mask = button:CreateMaskTexture()
    mask:SetAllPoints(icon)
    mask:SetTexture("Interface\\AddOns\\!TweaksUI\\Media\\Textures\\Masks\\Mask_Rounded", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    
    buttonIconMasks[name] = mask
    return mask
end

-- Apply edge style to a specific bar
function ActionBars:ApplyIconEdgeStyle(barId)
    local barSettings = settings and settings.bars and settings.bars[barId]
    local info = BAR_INFO[barId]
    
    if not barSettings or not info then return end
    
    -- Skip if Masque is handling this bar
    if barSettings.useMasque and Masque then
        return
    end
    
    -- Check for global icon edge style override first
    local edgeStyle
    if TweaksUI.Media and TweaksUI.Media:IsUsingGlobalIconEdgeStyle() then
        local globalStyle = TweaksUI.Media:GetGlobalIconEdgeStyle() or "sharp"
        -- Map global style to action bar style
        -- Global "square" maps to action bar "default" (no zoom)
        if globalStyle == "square" then
            edgeStyle = "default"
        else
            edgeStyle = globalStyle
        end
    else
        edgeStyle = barSettings.iconEdgeStyle or "default"
    end
    local zoom = barSettings.iconZoom or 0.08
    
    for i = 1, info.buttonCount do
        local button = _G[info.buttonPrefix .. i]
        if button then
            local icon = button.icon or button.Icon
            if icon then
                local mask = GetOrCreateIconMask(button)
                
                -- Remove existing mask first
                if mask then
                    icon:RemoveMaskTexture(mask)
                end
                
                if edgeStyle == "rounded" then
                    icon:SetTexCoord(0, 1, 0, 1)  -- Full texture for mask
                    if mask then
                        icon:AddMaskTexture(mask)
                    end
                elseif edgeStyle == "sharp" then
                    icon:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
                else  -- "default" - restore Blizzard's default
                    icon:SetTexCoord(0, 1, 0, 1)
                end
            end
        end
    end
end

function ActionBars:ApplyAllIconEdgeStyles()
    for _, barId in ipairs(BAR_ORDER) do
        self:ApplyIconEdgeStyle(barId)
    end
end

-- Apply gryphon art visibility
function ActionBars:ApplyGryphonVisibility()
    if not settings or not settings.bars or not settings.bars.ActionBar1 then
        return
    end
    
    local hideGryphons = settings.bars.ActionBar1.hideGryphons
    local foundLeft, foundRight = false, false
    
    -- =========================================================================
    -- HIDE GRYPHON/ENDCAP ART
    -- =========================================================================
    
    -- Method 1: Try MainMenuBarArtFrame and its children (modern structure)
    local artFrame = _G["MainMenuBarArtFrame"]
    if artFrame then
        -- Try artFrame.Background first (TWW/Midnight structure)
        if artFrame.Background then
            -- EndCaps might be direct children of Background
            if artFrame.Background.LeftEndCap then
                artFrame.Background.LeftEndCap:SetShown(not hideGryphons)
                foundLeft = true
            end
            if artFrame.Background.RightEndCap then
                artFrame.Background.RightEndCap:SetShown(not hideGryphons)
                foundRight = true
            end
            
            -- Also check for unnamed textures in Background
            if artFrame.Background.GetRegions then
                local regions = {artFrame.Background:GetRegions()}
                for _, region in ipairs(regions) do
                    if region.GetTexture and region:IsShown() then
                        local texture = region:GetTexture()
                        if texture then
                            local texStr = tostring(texture):lower()
                            if texStr:find("endcap") or texStr:find("gryphon") or texStr:find("ui%-mainmenubar") then
                                region:SetShown(not hideGryphons)
                            end
                        end
                    end
                end
            end
        end
        
        -- Try direct children of artFrame
        if artFrame.LeftEndCap then
            artFrame.LeftEndCap:SetShown(not hideGryphons)
            foundLeft = true
        end
        if artFrame.RightEndCap then
            artFrame.RightEndCap:SetShown(not hideGryphons)
            foundRight = true
        end
        
        -- Search all children by name pattern
        local children = {artFrame:GetChildren()}
        for _, child in ipairs(children) do
            local name = child:GetName() or ""
            local nameLower = name:lower()
            if nameLower:find("endcap") or nameLower:find("gryphon") then
                child:SetShown(not hideGryphons)
                if nameLower:find("left") then foundLeft = true end
                if nameLower:find("right") then foundRight = true end
            end
            
            -- Check grandchildren too
            if child.GetChildren then
                local grandchildren = {child:GetChildren()}
                for _, gc in ipairs(grandchildren) do
                    local gcName = (gc:GetName() or ""):lower()
                    if gcName:find("endcap") or gcName:find("gryphon") then
                        gc:SetShown(not hideGryphons)
                        if gcName:find("left") then foundLeft = true end
                        if gcName:find("right") then foundRight = true end
                    end
                end
            end
            
            -- Also check child's regions (textures)
            if child.GetRegions then
                local childRegions = {child:GetRegions()}
                for _, region in ipairs(childRegions) do
                    if region.GetTexture then
                        local texture = region:GetTexture()
                        if texture then
                            local texStr = tostring(texture):lower()
                            if texStr:find("endcap") or texStr:find("gryphon") then
                                region:SetShown(not hideGryphons)
                            end
                        end
                    end
                end
            end
        end
        
        -- Search artFrame's own regions (textures)
        local regions = {artFrame:GetRegions()}
        for _, region in ipairs(regions) do
            if region.GetTexture then
                local texture = region:GetTexture()
                if texture then
                    local texStr = tostring(texture):lower()
                    if texStr:find("endcap") or texStr:find("gryphon") or texStr:find("ui%-mainmenubar%-endcap") then
                        region:SetShown(not hideGryphons)
                    end
                end
            end
        end
    end
    
    -- Method 2: Try global frame names as fallback
    local testNames = {
        "MainMenuBarLeftEndCap",
        "MainMenuBarRightEndCap", 
        "MainMenuBarArtFrameLeftEndCap",
        "MainMenuBarArtFrameRightEndCap",
        "MainMenuBarArtFrameBackground.LeftEndCap",
        "MainMenuBarArtFrameBackground.RightEndCap",
    }
    
    for _, name in ipairs(testNames) do
        local frame = _G[name]
        if frame then
            frame:SetShown(not hideGryphons)
            if name:find("Left") then foundLeft = true end
            if name:find("Right") then foundRight = true end
        end
    end
    
    -- =========================================================================
    -- HIDE EMPTY BUTTON SLOT BACKGROUND ART (the stone/grey texture inside empty slots)
    -- =========================================================================
    
    -- When hiding gryphons, hide the fancy SlotArt but show a simple grey background
    for i = 1, 12 do
        local button = _G["ActionButton" .. i]
        if button then
            local hasAction = HasAction(button.action or ActionButton_CalculateAction(button) or i)
            
            -- SlotArt is the fancy stone/gryphon-style background
            if button.SlotArt then
                if hideGryphons and not hasAction then
                    button.SlotArt:SetAlpha(0)
                else
                    button.SlotArt:SetAlpha(1)
                end
            end
            
            -- SlotBackground can be used as a simple grey background
            -- When hiding gryphon art, show SlotBackground with a grey tint
            if button.SlotBackground then
                if hideGryphons and not hasAction then
                    -- Show a subtle grey background instead of nothing
                    button.SlotBackground:SetShown(true)
                    button.SlotBackground:SetAlpha(1)
                    -- Try to set it to a grey color if possible
                    if button.SlotBackground.SetVertexColor then
                        button.SlotBackground:SetVertexColor(0.15, 0.15, 0.15, 0.8)
                    end
                else
                    -- Restore default behavior
                    button.SlotBackground:SetShown(false)
                end
            else
                -- Create a simple grey background if SlotBackground doesn't exist
                if hideGryphons and not hasAction then
                    if not button.TUI_EmptyBG then
                        local bg = button:CreateTexture(nil, "BACKGROUND", nil, -8)
                        bg:SetAllPoints()
                        bg:SetColorTexture(0.12, 0.12, 0.12, 0.9)
                        button.TUI_EmptyBG = bg
                    end
                    button.TUI_EmptyBG:Show()
                elseif button.TUI_EmptyBG then
                    button.TUI_EmptyBG:Hide()
                end
            end
            
            -- Hide icon on empty slots (it might show a default texture)
            if button.icon and not hasAction then
                if hideGryphons then
                    button.icon:SetAlpha(0)
                else
                    button.icon:SetAlpha(1)
                end
            end
            
            -- DON'T hide NormalTexture - that's the border which we want to keep
            local normalTexture = button:GetNormalTexture() or button.NormalTexture
            if normalTexture then
                normalTexture:SetAlpha(1)
            end
        end
    end
    
    TweaksUI:PrintDebug("ActionBars: Gryphon visibility set to " .. tostring(not hideGryphons) .. 
        " (found left: " .. tostring(foundLeft) .. ", right: " .. tostring(foundRight) .. ")")
end

-- Hook action button updates to maintain empty slot hiding
local function HookActionButtonUpdates()
    -- Hook ActionButton_Update to re-apply empty slot hiding when buttons change
    if not ActionBars._buttonUpdateHooked then
        -- Check which function exists (Midnight removed ActionButton_Update)
        local updateFunc = ActionButton_Update or ActionButton_UpdateState or ActionButton_UpdateAction
        local updateFuncName = ActionButton_Update and "ActionButton_Update" 
            or ActionButton_UpdateState and "ActionButton_UpdateState"
            or ActionButton_UpdateAction and "ActionButton_UpdateAction"
        
        if updateFunc and updateFuncName then
            hooksecurefunc(updateFuncName, function(button)
                if not settings or not settings.bars or not settings.bars.ActionBar1 then return end
                local hideGryphons = settings.bars.ActionBar1.hideGryphons
                if not hideGryphons then return end
                
                -- Check if this is an ActionBar1 button
                local buttonName = button:GetName() or ""
                if not buttonName:find("^ActionButton%d+$") then return end
                
                local hasAction = HasAction(button.action or 0)
                
                -- Hide SlotArt (fancy stone texture) on empty slots
                if button.SlotArt then
                    button.SlotArt:SetAlpha(hasAction and 1 or 0)
                end
                
                -- Show grey background on empty slots
                if button.SlotBackground then
                    if not hasAction then
                        button.SlotBackground:SetShown(true)
                        button.SlotBackground:SetAlpha(1)
                        if button.SlotBackground.SetVertexColor then
                            button.SlotBackground:SetVertexColor(0.15, 0.15, 0.15, 0.8)
                        end
                    else
                        button.SlotBackground:SetShown(false)
                    end
                elseif button.TUI_EmptyBG then
                    button.TUI_EmptyBG:SetShown(not hasAction)
                end
                
                -- Hide icon on empty slots
                if button.icon and not hasAction then
                    button.icon:SetAlpha(0)
                end
            end)
        end
        ActionBars._buttonUpdateHooked = true
    end
end

-- ============================================================================
-- EVENT HANDLING
-- ============================================================================

local initialLayoutApplied = false

local function OnEvent(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        local isInitialLogin, isReloadingUi = ...
        -- Apply layouts on initial login or UI reload
        if isInitialLogin or isReloadingUi or not initialLayoutApplied then
            initialLayoutApplied = true
            -- Short delay to ensure frames are ready
            C_Timer.After(0.5, function()
                ActionBars:ApplyAllLayouts()
                ActionBars:ApplyAllVisibility()
                ActionBars:ApplyAllTextSettings()
                ActionBars:ApplyAllCooldownSettings()
                ActionBars:ApplyGryphonVisibility()
                HookActionButtonUpdates()  -- Hook button updates for empty slot hiding
            end)
        else
            -- On zone changes, only re-apply visibility
            C_Timer.After(0.5, function()
                ActionBars:ApplyAllVisibility()
            end)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        ProcessPendingUpdates()
        -- Re-apply layouts after combat ends
        C_Timer.After(0.1, function()
            ActionBars:ApplyAllLayouts()
        end)
    elseif event == "ACTIONBAR_PAGE_CHANGED" or event == "UPDATE_BONUS_ACTIONBAR" then
        if not IsInCombat() then
            C_Timer.After(0.1, function()
                ActionBars:ApplyBarLayout("ActionBar1")
            end)
        end
    elseif event == "ACTIONBAR_SLOT_CHANGED" then
        -- Re-apply empty slot hiding when actions change
        if settings and settings.bars and settings.bars.ActionBar1 and settings.bars.ActionBar1.hideGryphons then
            C_Timer.After(0.1, function()
                ActionBars:ApplyGryphonVisibility()
            end)
        end
    end
end

local function SetupEvents()
    if not eventFrame then
        eventFrame = CreateFrame("Frame")
    end
    eventFrame:SetScript("OnEvent", OnEvent)
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
    eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")  -- For empty slot hiding updates
    eventFrame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
    -- Note: EDIT_MODE_LAYOUTS_UPDATED removed - we use our own Layout system now
end

local function TeardownEvents()
    if eventFrame then
        eventFrame:UnregisterAllEvents()
    end
end

-- ============================================================================
-- SETTINGS UI - HELPERS
-- ============================================================================

local function CreateSlider(parent, x, y, label, minVal, maxVal, step, getValue, setValue, formatStr)
    local isFloat = step < 1
    local decimals = 0
    if isFloat then
        -- Count decimals in step
        local stepStr = tostring(step)
        local _, decPart = stepStr:match("(%d+)%.?(%d*)")
        decimals = decPart and #decPart or 2
    end
    
    -- Use centralized slider with input
    local container = TweaksUI.Utilities:CreateSliderWithInput(parent, {
        label = label,
        min = minVal,
        max = maxVal,
        step = step,
        value = getValue(),
        isFloat = isFloat,
        decimals = decimals,
        width = 200,  -- Shorter slider to fit input box in panel
        labelWidth = 120,
        valueWidth = 50,
        onValueChanged = function(value)
            setValue(value)
        end,
    })
    container:SetPoint("TOPLEFT", x, y)
    
    return y - 30
end

local function CreateCheckbox(parent, x, y, label, getValue, setValue)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb:SetSize(24, 24)
    cb:SetChecked(getValue())
    cb.text:SetText(label)
    cb.text:SetFontObject("GameFontNormal")
    
    cb:SetScript("OnClick", function(self)
        setValue(self:GetChecked())
    end)
    
    return y - 28
end

local function CreateSeparator(parent, y)
    local sep = parent:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", 10, y)
    sep:SetSize(PANEL_WIDTH - 70, 1)
    sep:SetColorTexture(0.4, 0.4, 0.4, 0.6)
    return y - 10
end

-- ============================================================================
-- SETTINGS UI - BAR SETTINGS PANEL
-- ============================================================================

function ActionBars:CreateBarSettingsPanel(barId)
    local info = BAR_INFO[barId]
    if not info then return end
    
    local panelName = "TweaksUI_ActionBars_" .. barId .. "_Panel"
    
    local panel = CreateFrame("Frame", panelName, UIParent, "BackdropTemplate")
    panel:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    panel:SetBackdrop(darkBackdrop)
    panel:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    panel:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    panel:SetFrameStrata("DIALOG")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:SetClampedToScreen(true)
    panel:Hide()
    
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText(info.displayName)
    title:SetTextColor(1, 0.82, 0)
    
    local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -3, -3)
    closeBtn:SetScript("OnClick", function()
        panel:Hide()
        ActionBars:HideBarHighlight(barId)
        currentOpenPanel = nil
    end)
    
    -- Hide highlight when panel is hidden (escape key, etc)
    panel:SetScript("OnHide", function()
        ActionBars:HideBarHighlight(barId)
        currentOpenPanel = nil
    end)
    
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    
    -- Enable checkbox at top
    local function getBarSettings()
        if not settings then return GetDefaultBarSettings() end
        if not settings.bars then settings.bars = {} end
        if not settings.bars[barId] then
            settings.bars[barId] = GetDefaultBarSettings()
        end
        return settings.bars[barId]
    end
    
    local function setBarSetting(key, value)
        if not settings then return end
        if not settings.bars then settings.bars = {} end
        if not settings.bars[barId] then
            settings.bars[barId] = GetDefaultBarSettings()
        end
        
        settings.bars[barId][key] = value
        
        -- Explicitly save to database to ensure persistence
        ActionBars:SaveSettings()
        
        if key == "enabled" and value == true then
            C_Timer.After(0.1, function()
                ActionBars:ApplyBarLayout(barId)
                ActionBars:ApplyVisibility(barId)
                ActionBars:ApplyTextSettings(barId)
                ActionBars:ApplyCooldownSettings(barId)
            end)
        elseif key == "enabled" then
            ActionBars:ApplyBarLayout(barId)
            ActionBars:ApplyVisibility(barId)
            ActionBars:ApplyTextSettings(barId)
            ActionBars:ApplyCooldownSettings(barId)
        elseif key == "buttonsShown" or key == "columns" or key == "orientation" or
               key == "buttonSize" or key == "horizontalSpacing" or key == "verticalSpacing" or
               key == "buttonFrameAlpha" then
            ActionBars:ApplyBarLayout(barId)
        elseif key:match("^show") or key == "visibilityEnabled" or key == "barAlpha" then
            ActionBars:ApplyVisibility(barId)
        elseif key == "keybindAlpha" or key == "countAlpha" or key == "macroNameAlpha" or key == "pageArrowsAlpha" then
            ActionBars:ApplyTextSettings(barId)
        elseif key == "cooldownSwipeAlpha" or key == "cooldownNumbersEnabled" then
            ActionBars:ApplyCooldownSettings(barId)
        elseif key == "rangeIndicatorEnabled" or key == "rangeIndicatorColor" then
            ActionBars:ApplyRangeIndicator(barId)
        elseif key == "iconEdgeStyle" or key == "iconZoom" then
            ActionBars:ApplyIconEdgeStyle(barId)
        elseif key == "useMasque" then
            ApplyMasqueToBar(barId)
        end
    end
    
    local enableCb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    enableCb:SetPoint("TOPLEFT", 15, -35)
    enableCb:SetSize(24, 24)
    enableCb:SetChecked(getBarSettings().enabled)
    enableCb.text:SetText("Enable " .. info.displayName .. " Tweaks")
    enableCb.text:SetFontObject("GameFontNormal")
    enableCb:SetScript("OnClick", function(self)
        local newState = self:GetChecked()
        setBarSetting("enabled", newState)
        
        -- Show reload prompt only when DISABLING - enabling works fine
        if not newState and not StaticPopup_Visible("TWEAKSUI_RELOAD_BAR") then
            StaticPopupDialogs["TWEAKSUI_RELOAD_BAR"] = {
                text = "Disabling action bar tweaks requires a UI reload to restore Blizzard's bar.\n\nReload now?",
                button1 = "Reload Now",
                button2 = "Later",
                OnAccept = function()
                    ReloadUI()
                end,
                OnCancel = function()
                    -- Settings already saved
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
            }
            StaticPopup_Show("TWEAKSUI_RELOAD_BAR")
        end
    end)
    
    -- Warning frame for hidden bars
    local warningFrame = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    warningFrame:SetPoint("TOPLEFT", 10, -58)
    warningFrame:SetPoint("TOPRIGHT", -10, -58)
    warningFrame:SetHeight(40)
    warningFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    warningFrame:SetBackdropColor(0.3, 0.1, 0.1, 0.9)
    warningFrame:SetBackdropBorderColor(0.8, 0.2, 0.2, 1)
    warningFrame:Hide()
    
    local warningIcon = warningFrame:CreateTexture(nil, "ARTWORK")
    warningIcon:SetPoint("LEFT", 8, 0)
    warningIcon:SetSize(18, 18)
    warningIcon:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")
    
    local warningText = warningFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    warningText:SetPoint("TOPLEFT", warningIcon, "TOPRIGHT", 6, 2)
    warningText:SetPoint("RIGHT", -70, 0)
    warningText:SetJustifyH("LEFT")
    warningText:SetText("|cffff8888This bar is hidden.|r Enable it in Game Menu > Options > Action Bars.")
    warningText:SetWordWrap(true)
    
    local openOptionsBtn = CreateFrame("Button", nil, warningFrame, "UIPanelButtonTemplate")
    openOptionsBtn:SetPoint("RIGHT", -5, 0)
    openOptionsBtn:SetSize(60, 22)
    openOptionsBtn:SetText("Open")
    openOptionsBtn:SetScript("OnClick", function()
        -- Close our panels first so user can see Options
        ActionBars:HideAllPanels()
        
        -- Open to the Action Bars category in Settings
        if Settings and Settings.OpenToCategory then
            -- Use Blizzard's ACTION_BAR_CATEGORY_ID constant
            local categoryId = Settings.ACTION_BAR_CATEGORY_ID or 13
            Settings.OpenToCategory(categoryId)
        elseif SettingsPanel then
            SettingsPanel:Show()
        else
            ToggleGameMenu()
        end
    end)
    
    panel.warningFrame = warningFrame
    
    -- Function to check if bar is visible
    local function IsBarVisible()
        local bar = _G[info.frame]
        if not bar then return false end
        
        -- Check if the bar or its parent is shown
        if bar:IsShown() then return true end
        
        -- For bars with parent containers, check parent too
        local parent = bar:GetParent()
        if parent and not parent:IsShown() then return false end
        
        return bar:IsShown()
    end
    
    -- Function to update warning visibility
    local function UpdateWarningVisibility()
        if barId == "ActionBar1" then
            -- Action Bar 1 is always visible
            warningFrame:Hide()
            return
        end
        
        if IsBarVisible() then
            warningFrame:Hide()
        else
            warningFrame:Show()
        end
    end
    
    -- Check on show
    panel:HookScript("OnShow", function()
        UpdateWarningVisibility()
    end)
    
    -- Periodically check while panel is shown (in case user enables bar in Edit Mode)
    local updateTimer = 0
    panel:HookScript("OnUpdate", function(self, elapsed)
        updateTimer = updateTimer + elapsed
        if updateTimer >= 1.0 then
            updateTimer = 0
            UpdateWarningVisibility()
        end
    end)
    
    -- Store the update function for external calls
    panel.UpdateWarningVisibility = UpdateWarningVisibility
    
    -- Tab buttons (positioned below warning area)
    local TAB_HEIGHT = 24
    local tabContainer = CreateFrame("Frame", nil, panel)
    tabContainer:SetPoint("TOPLEFT", 10, -103)
    tabContainer:SetPoint("TOPRIGHT", -10, -103)
    tabContainer:SetHeight(TAB_HEIGHT)
    
    -- Content frames for each tab
    local layoutContent = CreateFrame("Frame", nil, panel)
    layoutContent:SetPoint("TOPLEFT", 10, -133)
    layoutContent:SetPoint("BOTTOMRIGHT", -30, 10)
    
    local visibilityContent = CreateFrame("Frame", nil, panel)
    visibilityContent:SetPoint("TOPLEFT", 10, -133)
    visibilityContent:SetPoint("BOTTOMRIGHT", -30, 10)
    visibilityContent:Hide()
    
    local textContent = CreateFrame("Frame", nil, panel)
    textContent:SetPoint("TOPLEFT", 10, -133)
    textContent:SetPoint("BOTTOMRIGHT", -30, 10)
    textContent:Hide()
    
    local function SelectTab(tabName)
        if tabName == "layout" then
            layoutContent:Show()
            visibilityContent:Hide()
            textContent:Hide()
            panel.layoutTab:SetNormalFontObject("GameFontHighlight")
            panel.visibilityTab:SetNormalFontObject("GameFontNormal")
            panel.textTab:SetNormalFontObject("GameFontNormal")
        elseif tabName == "visibility" then
            layoutContent:Hide()
            visibilityContent:Show()
            textContent:Hide()
            panel.layoutTab:SetNormalFontObject("GameFontNormal")
            panel.visibilityTab:SetNormalFontObject("GameFontHighlight")
            panel.textTab:SetNormalFontObject("GameFontNormal")
        else
            layoutContent:Hide()
            visibilityContent:Hide()
            textContent:Show()
            panel.layoutTab:SetNormalFontObject("GameFontNormal")
            panel.visibilityTab:SetNormalFontObject("GameFontNormal")
            panel.textTab:SetNormalFontObject("GameFontHighlight")
        end
    end
    
    local TAB_WIDTH = (PANEL_WIDTH - 38) / 3
    
    local layoutTab = CreateFrame("Button", nil, tabContainer)
    layoutTab:SetSize(TAB_WIDTH, TAB_HEIGHT)
    layoutTab:SetPoint("TOPLEFT", 0, 0)
    layoutTab:SetNormalFontObject("GameFontHighlight")
    layoutTab:SetText("Layout")
    layoutTab:GetFontString():SetPoint("CENTER")
    layoutTab:SetScript("OnClick", function() SelectTab("layout") end)
    
    local layoutTabBg = layoutTab:CreateTexture(nil, "BACKGROUND")
    layoutTabBg:SetAllPoints()
    layoutTabBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
    
    panel.layoutTab = layoutTab
    
    local visibilityTab = CreateFrame("Button", nil, tabContainer)
    visibilityTab:SetSize(TAB_WIDTH, TAB_HEIGHT)
    visibilityTab:SetPoint("TOPLEFT", layoutTab, "TOPRIGHT", 4, 0)
    visibilityTab:SetNormalFontObject("GameFontNormal")
    visibilityTab:SetText("Visibility")
    visibilityTab:GetFontString():SetPoint("CENTER")
    visibilityTab:SetScript("OnClick", function() SelectTab("visibility") end)
    
    local visibilityTabBg = visibilityTab:CreateTexture(nil, "BACKGROUND")
    visibilityTabBg:SetAllPoints()
    visibilityTabBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
    
    panel.visibilityTab = visibilityTab
    
    local textTab = CreateFrame("Button", nil, tabContainer)
    textTab:SetSize(TAB_WIDTH, TAB_HEIGHT)
    textTab:SetPoint("TOPLEFT", visibilityTab, "TOPRIGHT", 4, 0)
    textTab:SetNormalFontObject("GameFontNormal")
    textTab:SetText("Text")
    textTab:GetFontString():SetPoint("CENTER")
    textTab:SetScript("OnClick", function() SelectTab("text") end)
    
    local textTabBg = textTab:CreateTexture(nil, "BACKGROUND")
    textTabBg:SetAllPoints()
    textTabBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
    
    panel.textTab = textTab
    
    -- ========== LAYOUT TAB CONTENT ==========
    local layoutScroll = CreateFrame("ScrollFrame", nil, layoutContent, "UIPanelScrollFrameTemplate")
    layoutScroll:SetAllPoints()
    
    local layoutScrollChild = CreateFrame("Frame", nil, layoutScroll)
    layoutScrollChild:SetSize(PANEL_WIDTH - 60, 400)
    layoutScroll:SetScrollChild(layoutScrollChild)
    
    local y = -5
    
    y = CreateSlider(layoutScrollChild, 5, y, "Buttons Shown", 1, 12, 1,
        function() return getBarSettings().buttonsShown end,
        function(v) setBarSetting("buttonsShown", v) end)
    
    y = CreateCheckbox(layoutScrollChild, 5, y, "Vertical Orientation",
        function() return getBarSettings().orientation == "vertical" end,
        function(v) setBarSetting("orientation", v and "vertical" or "horizontal") end)
    
    y = CreateSlider(layoutScrollChild, 5, y, "Columns", 1, 12, 1,
        function() return getBarSettings().columns end,
        function(v) setBarSetting("columns", v) end)
    
    y = CreateSlider(layoutScrollChild, 5, y, "Button Size", 24, 72, 1,
        function() return getBarSettings().buttonSize end,
        function(v) setBarSetting("buttonSize", v) end)
    
    y = CreateSlider(layoutScrollChild, 5, y, "Horizontal Spacing", -20, 16, 1,
        function() return getBarSettings().horizontalSpacing end,
        function(v) setBarSetting("horizontalSpacing", v) end)
    
    y = CreateSlider(layoutScrollChild, 5, y, "Vertical Spacing", -20, 16, 1,
        function() return getBarSettings().verticalSpacing end,
        function(v) setBarSetting("verticalSpacing", v) end)
    
    -- Range indicator section
    local rangeLabel = layoutScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rangeLabel:SetPoint("TOPLEFT", 5, y - 10)
    rangeLabel:SetText("|cffaaaaaa— Range Indicator —|r")
    y = y - 30
    
    -- Range indicator enable checkbox
    local rangeCheck = CreateFrame("CheckButton", nil, layoutScrollChild, "UICheckButtonTemplate")
    rangeCheck:SetPoint("TOPLEFT", 5, y - 5)
    rangeCheck:SetSize(26, 26)
    rangeCheck:SetChecked(getBarSettings().rangeIndicatorEnabled ~= false)
    rangeCheck:SetScript("OnClick", function(self)
        setBarSetting("rangeIndicatorEnabled", self:GetChecked())
    end)
    
    local rangeCheckLabel = layoutScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rangeCheckLabel:SetPoint("LEFT", rangeCheck, "RIGHT", 5, 0)
    rangeCheckLabel:SetText("Show Out-of-Range Indicator")
    y = y - 30
    
    -- Range indicator color picker
    local rangeColorLabel = layoutScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rangeColorLabel:SetPoint("TOPLEFT", 34, y + 4)
    rangeColorLabel:SetText("Indicator Color")
    
    local rangeColor = getBarSettings().rangeIndicatorColor or {1, 0.1, 0.1, 0.4}
    
    local rangeColorBtn = CreateFrame("Button", nil, layoutScrollChild, "BackdropTemplate")
    rangeColorBtn:SetPoint("TOPLEFT", 10, y)
    rangeColorBtn:SetSize(20, 20)
    rangeColorBtn:SetBackdrop({ 
        bgFile = "Interface\\BUTTONS\\WHITE8X8", 
        edgeFile = "Interface\\BUTTONS\\WHITE8X8", 
        edgeSize = 1 
    })
    rangeColorBtn:SetBackdropColor(rangeColor[1] or 1, rangeColor[2] or 0.1, rangeColor[3] or 0.1, rangeColor[4] or 0.4)
    rangeColorBtn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    
    rangeColorBtn:SetScript("OnClick", function()
        local r, g, b, a = rangeColor[1] or 1, rangeColor[2] or 0.1, rangeColor[3] or 0.1, rangeColor[4] or 0.4
        
        local info = {
            swatchFunc = function()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                local na = ColorPickerFrame:GetColorAlpha() or 1
                rangeColor[1], rangeColor[2], rangeColor[3], rangeColor[4] = nr, ng, nb, na
                rangeColorBtn:SetBackdropColor(nr, ng, nb, na)
                setBarSetting("rangeIndicatorColor", rangeColor)
            end,
            opacityFunc = function()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                local na = ColorPickerFrame:GetColorAlpha() or 1
                rangeColor[1], rangeColor[2], rangeColor[3], rangeColor[4] = nr, ng, nb, na
                rangeColorBtn:SetBackdropColor(nr, ng, nb, na)
                setBarSetting("rangeIndicatorColor", rangeColor)
            end,
            cancelFunc = function(prev)
                rangeColor[1], rangeColor[2], rangeColor[3], rangeColor[4] = prev.r, prev.g, prev.b, prev.a or 1
                rangeColorBtn:SetBackdropColor(prev.r, prev.g, prev.b, prev.a or 1)
                setBarSetting("rangeIndicatorColor", rangeColor)
            end,
            hasOpacity = true,
            opacity = a,
            r = r,
            g = g,
            b = b,
        }
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)
    y = y - 30
    
    -- Icon Edge Style section
    local edgeLabel = layoutScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    edgeLabel:SetPoint("TOPLEFT", 5, y - 10)
    edgeLabel:SetText("|cffaaaaaa— Icon Appearance —|r")
    y = y - 30
    
    local edgeStyleLabel = layoutScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    edgeStyleLabel:SetPoint("TOPLEFT", 10, y - 5)
    edgeStyleLabel:SetText("Icon Edge Style")
    y = y - 20
    
    local edgeStyles = {
        {value = "default", label = "Default (Blizzard)"},
        {value = "sharp", label = "Sharp (Zoomed)"},
        {value = "rounded", label = "Rounded Corners"},
    }
    
    local edgeDropdown = CreateFrame("Frame", "TweaksUI_ActionBar_EdgeStyle_" .. barId, layoutScrollChild, "UIDropDownMenuTemplate")
    edgeDropdown:SetPoint("TOPLEFT", 0, y)
    UIDropDownMenu_SetWidth(edgeDropdown, 150)
    
    local currentEdge = getBarSettings().iconEdgeStyle or "default"
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
            info.func = function(self)
                setBarSetting("iconEdgeStyle", self.value)
                UIDropDownMenu_SetText(edgeDropdown, self:GetText())
            end
            info.checked = (getBarSettings().iconEdgeStyle or "default") == opt.value
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    y = y - 35
    
    -- Icon Zoom slider (only applies to sharp style)
    y = CreateSlider(layoutScrollChild, 5, y, "Icon Zoom", 0, 15, 1,
        function() return (getBarSettings().iconZoom or 0.08) * 100 end,
        function(v) setBarSetting("iconZoom", v / 100) end,
        "%d%%")
    
    -- Masque checkbox (only show if Masque is available)
    if Masque then
        y = y - 5
        local masqueCheck = CreateFrame("CheckButton", nil, layoutScrollChild, "UICheckButtonTemplate")
        masqueCheck:SetPoint("TOPLEFT", 5, y)
        masqueCheck:SetSize(24, 24)
        masqueCheck:SetChecked(getBarSettings().useMasque or false)
        
        local masqueLabel = layoutScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        masqueLabel:SetPoint("LEFT", masqueCheck, "RIGHT", 5, 0)
        masqueLabel:SetText("Use Masque Skinning")
        
        masqueCheck:SetScript("OnClick", function(self)
            local checked = self:GetChecked()
            setBarSetting("useMasque", checked)
            ApplyMasqueToBar(barId)
        end)
        y = y - 28
    end
    
    -- ========== VISIBILITY TAB CONTENT ==========
    local visibilityScroll = CreateFrame("ScrollFrame", nil, visibilityContent, "UIPanelScrollFrameTemplate")
    visibilityScroll:SetAllPoints()
    
    local visibilityScrollChild = CreateFrame("Frame", nil, visibilityScroll)
    visibilityScrollChild:SetSize(PANEL_WIDTH - 60, 600)
    visibilityScroll:SetScrollChild(visibilityScrollChild)
    
    y = -5
    
    -- Helper function to create alpha slider with numeric input
    local function CreateAlphaSlider(parent, x, yPos, label, getSetting, setSetting, minVal)
        minVal = minVal or 0.1
        
        -- Use centralized slider with input
        local container = TweaksUI.Utilities:CreateSliderWithInput(parent, {
            label = label,
            min = minVal,
            max = 1.0,
            step = 0.05,
            value = getSetting() or 1.0,
            isFloat = true,
            decimals = 2,
            width = 140,
            labelWidth = 140,
            valueWidth = 45,
            onValueChanged = function(value)
                setSetting(value)
            end,
        })
        container:SetPoint("TOPLEFT", x, yPos)
        
        return yPos - 30
    end
    
    -- Opacity section header
    local opacityLabel = visibilityScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    opacityLabel:SetPoint("TOPLEFT", 5, y - 5)
    opacityLabel:SetText("|cffaaaaaa— Opacity —|r")
    y = y - 20
    
    -- Action Bar Opacity slider
    y = CreateAlphaSlider(visibilityScrollChild, 5, y, "Action Bar Opacity",
        function() return getBarSettings().barAlpha end,
        function(v) setBarSetting("barAlpha", v) end,
        0.1)
    
    -- Button Frame Opacity slider (can go to 0)
    y = CreateAlphaSlider(visibilityScrollChild, 5, y, "Button Frame Opacity",
        function() return getBarSettings().buttonFrameAlpha end,
        function(v) setBarSetting("buttonFrameAlpha", v) end,
        0)
    
    y = CreateSeparator(visibilityScrollChild, y - 5)
    
    -- Visibility Rules section
    local visRulesLabel = visibilityScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    visRulesLabel:SetPoint("TOPLEFT", 5, y - 5)
    visRulesLabel:SetText("|cffaaaaaa— Visibility Rules —|r")
    y = y - 20
    
    y = CreateCheckbox(visibilityScrollChild, 5, y, "Enable Visibility Rules",
        function() return getBarSettings().visibilityEnabled end,
        function(v) setBarSetting("visibilityEnabled", v) end)
    
    local infoText = visibilityScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoText:SetPoint("TOPLEFT", 25, y - 5)
    infoText:SetText("|cff888888Bar shows if ANY checked condition is true|r")
    y = y - 20
    
    local mouseoverLabel = visibilityScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mouseoverLabel:SetPoint("TOPLEFT", 5, y - 5)
    mouseoverLabel:SetText("|cffaaaaaa— Mouseover —|r")
    y = y - 20
    
    y = CreateCheckbox(visibilityScrollChild, 20, y, "Show On Mouseover",
        function() return getBarSettings().showOnMouseover end,
        function(v) setBarSetting("showOnMouseover", v) end)
    
    local combatLabel = visibilityScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    combatLabel:SetPoint("TOPLEFT", 5, y - 5)
    combatLabel:SetText("|cffaaaaaa— Combat —|r")
    y = y - 20
    
    y = CreateCheckbox(visibilityScrollChild, 20, y, "Show In Combat",
        function() return getBarSettings().showInCombat end,
        function(v) setBarSetting("showInCombat", v) end)
    
    y = CreateCheckbox(visibilityScrollChild, 20, y, "Show Out of Combat",
        function() return getBarSettings().showOutOfCombat end,
        function(v) setBarSetting("showOutOfCombat", v) end)
    
    local targetLabel = visibilityScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    targetLabel:SetPoint("TOPLEFT", 5, y - 5)
    targetLabel:SetText("|cffaaaaaa— Target —|r")
    y = y - 20
    
    y = CreateCheckbox(visibilityScrollChild, 20, y, "Show With Target",
        function() return getBarSettings().showWithTarget end,
        function(v) setBarSetting("showWithTarget", v) end)
    
    local groupLabel = visibilityScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    groupLabel:SetPoint("TOPLEFT", 5, y - 5)
    groupLabel:SetText("|cffaaaaaa— Group —|r")
    y = y - 20
    
    y = CreateCheckbox(visibilityScrollChild, 20, y, "Show Solo",
        function() return getBarSettings().showSolo end,
        function(v) setBarSetting("showSolo", v) end)
    
    y = CreateCheckbox(visibilityScrollChild, 20, y, "Show In Party",
        function() return getBarSettings().showInParty end,
        function(v) setBarSetting("showInParty", v) end)
    
    y = CreateCheckbox(visibilityScrollChild, 20, y, "Show In Raid",
        function() return getBarSettings().showInRaid end,
        function(v) setBarSetting("showInRaid", v) end)
    
    y = CreateCheckbox(visibilityScrollChild, 20, y, "Show In Instance",
        function() return getBarSettings().showInInstance end,
        function(v) setBarSetting("showInInstance", v) end)
    
    local specialLabel = visibilityScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    specialLabel:SetPoint("TOPLEFT", 5, y - 5)
    specialLabel:SetText("|cffaaaaaa— Special —|r")
    y = y - 20
    
    y = CreateCheckbox(visibilityScrollChild, 20, y, "Show When Mounted",
        function() return getBarSettings().showMounted end,
        function(v) setBarSetting("showMounted", v) end)
    
    y = CreateCheckbox(visibilityScrollChild, 20, y, "Show In Vehicle",
        function() return getBarSettings().showInVehicle end,
        function(v) setBarSetting("showInVehicle", v) end)
    
    y = CreateCheckbox(visibilityScrollChild, 20, y, "Show When Dragonriding",
        function() return getBarSettings().showDragonriding end,
        function(v) setBarSetting("showDragonriding", v) end)
    
    -- ========== TEXT TAB CONTENT ==========
    local textScroll = CreateFrame("ScrollFrame", nil, textContent, "UIPanelScrollFrameTemplate")
    textScroll:SetAllPoints()
    
    local textScrollChild = CreateFrame("Frame", nil, textScroll)
    textScrollChild:SetSize(PANEL_WIDTH - 60, 300)
    textScroll:SetScrollChild(textScrollChild)
    
    y = -5
    
    local textLabel = textScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    textLabel:SetPoint("TOPLEFT", 5, y)
    textLabel:SetText("|cffaaaaaa— Text Overlay Alpha —|r")
    y = y - 20
    
    y = CreateSlider(textScrollChild, 5, y, "Keybind Text", 0, 100, 1,
        function() return (getBarSettings().keybindAlpha or 1) * 100 end,
        function(v) setBarSetting("keybindAlpha", v / 100) end,
        "%d%%")
    
    y = CreateSlider(textScrollChild, 5, y, "Stack Count", 0, 100, 1,
        function() return (getBarSettings().countAlpha or 1) * 100 end,
        function(v) setBarSetting("countAlpha", v / 100) end,
        "%d%%")
    
    y = CreateSlider(textScrollChild, 5, y, "Macro Name", 0, 100, 1,
        function() return (getBarSettings().macroNameAlpha or 1) * 100 end,
        function(v) setBarSetting("macroNameAlpha", v / 100) end,
        "%d%%")
    
    -- Cooldown settings section
    local cooldownLabel = textScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cooldownLabel:SetPoint("TOPLEFT", 5, y - 10)
    cooldownLabel:SetText("|cffaaaaaa— Cooldown Settings —|r")
    y = y - 30
    
    y = CreateSlider(textScrollChild, 5, y, "Cooldown Sweep", 0, 100, 1,
        function() return (getBarSettings().cooldownSwipeAlpha or 0.6) * 100 end,
        function(v) setBarSetting("cooldownSwipeAlpha", v / 100) end,
        "%d%%")
    
    -- Cooldown numbers toggle
    local numbersCheck = CreateFrame("CheckButton", nil, textScrollChild, "UICheckButtonTemplate")
    numbersCheck:SetPoint("TOPLEFT", 5, y - 5)
    numbersCheck:SetSize(26, 26)
    numbersCheck:SetChecked(getBarSettings().cooldownNumbersEnabled ~= false)
    numbersCheck:SetScript("OnClick", function(self)
        setBarSetting("cooldownNumbersEnabled", self:GetChecked())
    end)
    
    local numbersLabel = textScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    numbersLabel:SetPoint("LEFT", numbersCheck, "RIGHT", 5, 0)
    numbersLabel:SetText("Show Cooldown Numbers")
    y = y - 30
    
    -- Page arrows only for Action Bar 1
    if barId == "ActionBar1" then
        local arrowsLabel = textScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        arrowsLabel:SetPoint("TOPLEFT", 5, y - 10)
        arrowsLabel:SetText("|cffaaaaaa— Action Bar 1 Special —|r")
        y = y - 30
        
        y = CreateSlider(textScrollChild, 5, y, "Page Arrows", 0, 100, 1,
            function() return (getBarSettings().pageArrowsAlpha or 1) * 100 end,
            function(v) setBarSetting("pageArrowsAlpha", v / 100) end,
            "%d%%")
        
        -- Hide Gryphon Art checkbox
        local gryphonCheck = CreateFrame("CheckButton", nil, textScrollChild, "UICheckButtonTemplate")
        gryphonCheck:SetPoint("TOPLEFT", 5, y - 10)
        gryphonCheck:SetSize(24, 24)
        gryphonCheck:SetChecked(getBarSettings().hideGryphons or false)
        gryphonCheck:SetScript("OnClick", function(self)
            setBarSetting("hideGryphons", self:GetChecked())
            ActionBars:ApplyGryphonVisibility()
        end)
        
        local gryphonLabel = textScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        gryphonLabel:SetPoint("LEFT", gryphonCheck, "RIGHT", 5, 0)
        gryphonLabel:SetText("Hide Gryphon Art")
        y = y - 30
    end
    
    settingsPanels[barId] = panel
    return panel
end

-- ============================================================================
-- SETTINGS UI - HUB PANEL
-- ============================================================================

function ActionBars:ShowHub(parentPanel)
    if actionBarsHub then
        actionBarsHub:ClearAllPoints()
        actionBarsHub:SetPoint("TOPLEFT", parentPanel, "TOPRIGHT", 0, 0)
        actionBarsHub:Show()
        return
    end
    
    local hub = CreateFrame("Frame", "TweaksUI_ActionBars_Hub", UIParent, "BackdropTemplate")
    hub:SetSize(HUB_WIDTH, HUB_HEIGHT + 50)  -- Increased height for preset dropdown
    hub:SetPoint("TOPLEFT", parentPanel, "TOPRIGHT", 0, 0)
    hub:SetBackdrop(darkBackdrop)
    hub:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    hub:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    hub:SetFrameStrata("DIALOG")
    hub:SetMovable(true)
    hub:EnableMouse(true)
    hub:SetClampedToScreen(true)
    
    actionBarsHub = hub
    
    local title = hub:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("Action Bars")
    title:SetTextColor(1, 0.82, 0)
    
    local closeBtn = CreateFrame("Button", nil, hub, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -3, -3)
    closeBtn:SetScript("OnClick", function()
        self:HideAllPanels()
    end)
    
    hub:RegisterForDrag("LeftButton")
    hub:SetScript("OnDragStart", hub.StartMoving)
    hub:SetScript("OnDragStop", hub.StopMovingOrSizing)
    hub:SetScript("OnHide", function()
        self:HideAllHighlights()
        self:HideAllPanels()
    end)
    
    local yOffset = -38
    local buttonWidth = HUB_WIDTH - 20
    
    local sectionLabel = hub:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sectionLabel:SetPoint("TOP", 0, yOffset)
    sectionLabel:SetText("|cff888888Action Bar Settings|r")
    yOffset = yOffset - 18
    
    for _, barId in ipairs(BAR_ORDER) do
        local info = BAR_INFO[barId]
        if info then
            local btn = CreateFrame("Button", nil, hub, "UIPanelButtonTemplate")
            btn:SetSize(buttonWidth, BUTTON_HEIGHT)
            btn:SetPoint("TOP", 0, yOffset)
            btn:SetText(info.displayName)
            btn:SetScript("OnClick", function()
                self:ToggleBarPanel(barId)
            end)
            yOffset = yOffset - BUTTON_HEIGHT - BUTTON_SPACING
        end
    end
    
    -- System Bars section
    yOffset = yOffset - 8
    local systemSep = hub:CreateTexture(nil, "ARTWORK")
    systemSep:SetPoint("TOP", 0, yOffset)
    systemSep:SetSize(buttonWidth, 1)
    systemSep:SetColorTexture(0.4, 0.4, 0.4, 0.6)
    yOffset = yOffset - 12
    
    local systemLabel = hub:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    systemLabel:SetPoint("TOP", 0, yOffset)
    systemLabel:SetText("|cff888888System Bars|r")
    yOffset = yOffset - 18
    
    for _, barId in ipairs(SYSTEM_BAR_ORDER) do
        local info = SYSTEM_BAR_INFO[barId]
        if info then
            local btn = CreateFrame("Button", nil, hub, "UIPanelButtonTemplate")
            btn:SetSize(buttonWidth, BUTTON_HEIGHT)
            btn:SetPoint("TOP", 0, yOffset)
            btn:SetText(info.displayName)
            btn:SetScript("OnClick", function()
                self:ToggleSystemBarPanel(barId)
            end)
            yOffset = yOffset - BUTTON_HEIGHT - BUTTON_SPACING
        end
    end
    
    -- Stance Bar (our custom implementation)
    local stanceBtn = CreateFrame("Button", nil, hub, "UIPanelButtonTemplate")
    stanceBtn:SetSize(buttonWidth, BUTTON_HEIGHT)
    stanceBtn:SetPoint("TOP", 0, yOffset)
    stanceBtn:SetText("Stance Bar")
    stanceBtn:SetScript("OnClick", function()
        self:ToggleStanceBarPanel()
    end)
    yOffset = yOffset - BUTTON_HEIGHT - BUTTON_SPACING
    
    yOffset = yOffset - 8
    local sep = hub:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOP", 0, yOffset)
    sep:SetSize(buttonWidth, 1)
    sep:SetColorTexture(0.4, 0.4, 0.4, 0.6)
    yOffset = yOffset - 12
    
    local quickLabel = hub:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    quickLabel:SetPoint("TOP", 0, yOffset)
    quickLabel:SetText("|cff888888Quick Actions|r")
    yOffset = yOffset - 20
    
    local keybindBtn = CreateFrame("Button", nil, hub, "UIPanelButtonTemplate")
    keybindBtn:SetSize(buttonWidth, BUTTON_HEIGHT)
    keybindBtn:SetPoint("TOP", 0, yOffset)
    keybindBtn:SetText("Quick Keybind Mode")
    keybindBtn:SetScript("OnClick", function()
        self:HideAllPanels()
        self:ToggleKeybindMode()
    end)
    yOffset = yOffset - BUTTON_HEIGHT - BUTTON_SPACING
    
    local applyBtn = CreateFrame("Button", nil, hub, "UIPanelButtonTemplate")
    applyBtn:SetSize(buttonWidth, BUTTON_HEIGHT)
    applyBtn:SetPoint("TOP", 0, yOffset)
    applyBtn:SetText("Apply All Changes")
    applyBtn:SetScript("OnClick", function()
        self:ApplyAllLayouts()
        self:ApplyAllVisibility()
        TweaksUI:Print("Action Bars: All changes applied")
    end)
    yOffset = yOffset - BUTTON_HEIGHT - BUTTON_SPACING
    
    local resetBtn = CreateFrame("Button", nil, hub, "UIPanelButtonTemplate")
    resetBtn:SetSize(buttonWidth, BUTTON_HEIGHT)
    resetBtn:SetPoint("TOP", 0, yOffset)
    resetBtn:SetText("Reset to Default")
    resetBtn:SetScript("OnClick", function()
        StaticPopup_Show("TWEAKSUI_ACTIONBARS_RESET")
    end)
    
    StaticPopupDialogs["TWEAKSUI_ACTIONBARS_RESET"] = {
        text = "Reset all Action Bar settings to default?",
        button1 = "Reset",
        button2 = "Cancel",
        OnAccept = function()
            settings.bars = DeepCopy(DEFAULT_SETTINGS.bars)
            ActionBars:RestoreAllLayouts()
            TweaksUI:Print("Action Bars: Reset to default")
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    
    hub:Show()
end

function ActionBars:ToggleBarPanel(barId)
    -- Hide all other panels and their highlights
    for name, panel in pairs(settingsPanels) do
        if panel and name ~= barId then
            panel:Hide()
            self:HideBarHighlight(name)
        end
    end
    
    if settingsPanels[barId] then
        if settingsPanels[barId]:IsShown() then
            settingsPanels[barId]:Hide()
            self:HideBarHighlight(barId)
            currentOpenPanel = nil
        else
            settingsPanels[barId]:ClearAllPoints()
            settingsPanels[barId]:SetPoint("TOPLEFT", actionBarsHub, "TOPRIGHT", 0, 0)
            settingsPanels[barId]:Show()
            self:ShowBarHighlight(barId)
            currentOpenPanel = barId
        end
    else
        self:CreateBarSettingsPanel(barId)
        if settingsPanels[barId] then
            settingsPanels[barId]:ClearAllPoints()
            settingsPanels[barId]:SetPoint("TOPLEFT", actionBarsHub, "TOPRIGHT", 0, 0)
            settingsPanels[barId]:Show()
            self:ShowBarHighlight(barId)
            currentOpenPanel = barId
        end
    end
end

-- Create and show highlight around the selected action bar
function ActionBars:ShowBarHighlight(barId)
    local info = BAR_INFO[barId]
    if not info then return end
    
    local bar = _G[info.frame]
    if not bar then return end
    
    -- Create highlight frame if it doesn't exist
    if not highlightFrames[barId] then
        local highlight = CreateFrame("Frame", nil, bar, "BackdropTemplate")
        highlight:SetFrameStrata("HIGH")
        
        -- Inner glow
        local innerGlow = highlight:CreateTexture(nil, "BACKGROUND")
        innerGlow:SetTexture("Interface\\Buttons\\WHITE8x8")
        innerGlow:SetAllPoints()
        innerGlow:SetVertexColor(0, 0.8, 1, 0.3)
        highlight.innerGlow = innerGlow
        
        -- Create multiple border layers for thickness
        for i = 1, 3 do
            local border = highlight:CreateTexture(nil, "BORDER")
            border:SetTexture("Interface\\Buttons\\WHITE8x8")
            border:SetVertexColor(0, 0.8, 1, 1)
            highlight["border" .. i] = border
        end
        
        -- Top border
        highlight.border1:SetPoint("TOPLEFT", highlight, "TOPLEFT", 0, 0)
        highlight.border1:SetPoint("TOPRIGHT", highlight, "TOPRIGHT", 0, 0)
        highlight.border1:SetHeight(3)
        
        -- Bottom border
        highlight.border2:SetPoint("BOTTOMLEFT", highlight, "BOTTOMLEFT", 0, 0)
        highlight.border2:SetPoint("BOTTOMRIGHT", highlight, "BOTTOMRIGHT", 0, 0)
        highlight.border2:SetHeight(3)
        
        -- Left border
        highlight.border3:SetPoint("TOPLEFT", highlight, "TOPLEFT", 0, 0)
        highlight.border3:SetPoint("BOTTOMLEFT", highlight, "BOTTOMLEFT", 0, 0)
        highlight.border3:SetWidth(3)
        
        -- Right border (need a 4th)
        local border4 = highlight:CreateTexture(nil, "BORDER")
        border4:SetTexture("Interface\\Buttons\\WHITE8x8")
        border4:SetVertexColor(0, 0.8, 1, 1)
        border4:SetPoint("TOPRIGHT", highlight, "TOPRIGHT", 0, 0)
        border4:SetPoint("BOTTOMRIGHT", highlight, "BOTTOMRIGHT", 0, 0)
        border4:SetWidth(3)
        highlight.border4 = border4
        
        -- Outer glow effect using a larger frame behind
        local outerGlow = CreateFrame("Frame", nil, highlight)
        outerGlow:SetPoint("TOPLEFT", -6, 6)
        outerGlow:SetPoint("BOTTOMRIGHT", 6, -6)
        outerGlow:SetFrameLevel(highlight:GetFrameLevel() - 1)
        
        local outerGlowTex = outerGlow:CreateTexture(nil, "BACKGROUND")
        outerGlowTex:SetTexture("Interface\\Buttons\\WHITE8x8")
        outerGlowTex:SetAllPoints()
        outerGlowTex:SetVertexColor(0, 0.6, 1, 0.4)
        highlight.outerGlow = outerGlow
        highlight.outerGlowTex = outerGlowTex
        
        -- Pulsing animation - faster and more dramatic
        local ag = highlight:CreateAnimationGroup()
        ag:SetLooping("REPEAT")
        
        local fadeOut = ag:CreateAnimation("Alpha")
        fadeOut:SetFromAlpha(1)
        fadeOut:SetToAlpha(0.3)
        fadeOut:SetDuration(0.4)
        fadeOut:SetOrder(1)
        
        local fadeIn = ag:CreateAnimation("Alpha")
        fadeIn:SetFromAlpha(0.3)
        fadeIn:SetToAlpha(1)
        fadeIn:SetDuration(0.4)
        fadeIn:SetOrder(2)
        
        highlight.pulseAnim = ag
        highlightFrames[barId] = highlight
    end
    
    local highlight = highlightFrames[barId]
    highlight:SetParent(bar)
    highlight:ClearAllPoints()
    highlight:SetPoint("TOPLEFT", bar, "TOPLEFT", -6, 6)
    highlight:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 6, -6)
    highlight:Show()
    highlight.outerGlow:Show()
    highlight.pulseAnim:Play()
end

-- Hide highlight for a bar
function ActionBars:HideBarHighlight(barId)
    if highlightFrames[barId] then
        highlightFrames[barId].pulseAnim:Stop()
        highlightFrames[barId]:Hide()
        if highlightFrames[barId].outerGlow then
            highlightFrames[barId].outerGlow:Hide()
        end
    end
end

-- Hide all highlights
function ActionBars:HideAllHighlights()
    for barId, _ in pairs(highlightFrames) do
        self:HideBarHighlight(barId)
    end
end

function ActionBars:HideAllPanels()
    if actionBarsHub then
        actionBarsHub:Hide()
    end
    for _, panel in pairs(settingsPanels) do
        if panel and panel.Hide then
            panel:Hide()
        end
    end
    -- Also hide stance bar panel
    if stanceBarPanel then
        stanceBarPanel:Hide()
    end
    self:HideAllHighlights()
    currentOpenPanel = nil
end

-- ============================================================================
-- SYSTEM BAR SETTINGS PANEL
-- ============================================================================

function ActionBars:ToggleSystemBarPanel(barId)
    -- Hide all other panels and their highlights
    for name, panel in pairs(settingsPanels) do
        if panel and name ~= barId then
            panel:Hide()
            self:HideBarHighlight(name)
        end
    end
    
    if settingsPanels[barId] then
        if settingsPanels[barId]:IsShown() then
            settingsPanels[barId]:Hide()
            currentOpenPanel = nil
        else
            settingsPanels[barId]:ClearAllPoints()
            settingsPanels[barId]:SetPoint("TOPLEFT", actionBarsHub, "TOPRIGHT", 0, 0)
            settingsPanels[barId]:Show()
            currentOpenPanel = barId
        end
    else
        self:CreateSystemBarSettingsPanel(barId)
        if settingsPanels[barId] then
            settingsPanels[barId]:ClearAllPoints()
            settingsPanels[barId]:SetPoint("TOPLEFT", actionBarsHub, "TOPRIGHT", 0, 0)
            settingsPanels[barId]:Show()
            currentOpenPanel = barId
        end
    end
end

function ActionBars:CreateSystemBarSettingsPanel(barId)
    local info = SYSTEM_BAR_INFO[barId]
    if not info then return end
    
    -- Create getter/setter functions that always reference current settings
    local function getBarSettings()
        if not settings then return GetDefaultSystemBarSettings() end
        if not settings.systemBars then settings.systemBars = {} end
        if not settings.systemBars[barId] then
            settings.systemBars[barId] = GetDefaultSystemBarSettings()
        end
        return settings.systemBars[barId]
    end
    
    local function setBarSetting(key, value)
        if not settings then return end
        if not settings.systemBars then settings.systemBars = {} end
        if not settings.systemBars[barId] then
            settings.systemBars[barId] = GetDefaultSystemBarSettings()
        end
        settings.systemBars[barId][key] = value
        -- Explicitly save to database to ensure persistence
        ActionBars:SaveSettings()
    end
    
    local panel = CreateFrame("Frame", "TweaksUI_SystemBar_" .. barId .. "_Panel", UIParent, "BackdropTemplate")
    panel:SetSize(PANEL_WIDTH, 400)
    panel:SetBackdrop(darkBackdrop)
    panel:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    panel:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    panel:SetFrameStrata("DIALOG")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:SetClampedToScreen(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    
    settingsPanels[barId] = panel
    
    -- Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText(info.displayName)
    title:SetTextColor(1, 0.82, 0)
    
    -- Description
    local desc = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    desc:SetPoint("TOP", title, "BOTTOM", 0, -4)
    desc:SetText("|cff888888" .. (info.description or "") .. "|r")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -3, -3)
    closeBtn:SetScript("OnClick", function()
        panel:Hide()
        currentOpenPanel = nil
    end)
    
    -- Scroll frame for content
    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -55)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 10)
    
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(PANEL_WIDTH - 45, 400)
    scrollFrame:SetScrollChild(content)
    
    local yOffset = -10
    
    -- Enable checkbox
    local enableCb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    enableCb:SetPoint("TOPLEFT", 0, yOffset)
    enableCb:SetSize(24, 24)
    enableCb:SetChecked(getBarSettings().enabled)
    enableCb.text:SetText("Enable TUI Layout")
    enableCb.text:SetFontObject("GameFontNormal")
    enableCb:SetScript("OnClick", function(self)
        setBarSetting("enabled", self:GetChecked())
        ApplySystemBarLayout(barId)
    end)
    yOffset = yOffset - 30
    
    -- Description text
    local enableDesc = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    enableDesc:SetPoint("TOPLEFT", 30, yOffset)
    enableDesc:SetWidth(PANEL_WIDTH - 80)
    enableDesc:SetJustifyH("LEFT")
    enableDesc:SetText("|cff888888When enabled, this bar uses TUI's Layout system for positioning. Use /tuil to move.|r")
    yOffset = yOffset - 35
    
    -- Separator
    local sep1 = content:CreateTexture(nil, "ARTWORK")
    sep1:SetPoint("TOPLEFT", 0, yOffset)
    sep1:SetSize(PANEL_WIDTH - 50, 1)
    sep1:SetColorTexture(0.4, 0.4, 0.4, 0.6)
    yOffset = yOffset - 15
    
    -- Alpha slider
    local alphaLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    alphaLabel:SetPoint("TOPLEFT", 0, yOffset)
    alphaLabel:SetText("Opacity")
    yOffset = yOffset - 25
    
    local alphaSlider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
    alphaSlider:SetPoint("TOPLEFT", 5, yOffset)
    alphaSlider:SetWidth(PANEL_WIDTH - 60)
    alphaSlider:SetMinMaxValues(0, 100)
    alphaSlider:SetValueStep(5)
    alphaSlider:SetObeyStepOnDrag(true)
    alphaSlider:SetValue((getBarSettings().barAlpha or 1) * 100)
    alphaSlider.Low:SetText("0%")
    alphaSlider.High:SetText("100%")
    alphaSlider.Text:SetText(math.floor((getBarSettings().barAlpha or 1) * 100) .. "%")
    alphaSlider:SetScript("OnValueChanged", function(self, value)
        setBarSetting("barAlpha", value / 100)
        self.Text:SetText(math.floor(value) .. "%")
        UpdateSystemBarVisibility(barId)
    end)
    yOffset = yOffset - 45
    
    -- Visibility section
    local visLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    visLabel:SetPoint("TOPLEFT", 0, yOffset)
    visLabel:SetText("Visibility")
    yOffset = yOffset - 25
    
    -- Enable visibility conditions
    local visCb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    visCb:SetPoint("TOPLEFT", 0, yOffset)
    visCb:SetSize(24, 24)
    visCb:SetChecked(getBarSettings().visibilityEnabled)
    visCb.text:SetText("Use Visibility Conditions")
    visCb.text:SetFontObject("GameFontNormal")
    visCb:SetScript("OnClick", function(self)
        setBarSetting("visibilityEnabled", self:GetChecked())
        UpdateSystemBarVisibility(barId)
    end)
    yOffset = yOffset - 30
    
    -- Visibility condition checkboxes
    local visibilityOptions = {
        { key = "showInCombat", label = "In Combat" },
        { key = "showOutOfCombat", label = "Out of Combat" },
        { key = "showWithTarget", label = "Has Target" },
        { key = "showSolo", label = "Solo" },
        { key = "showInParty", label = "In Party" },
        { key = "showInRaid", label = "In Raid" },
        { key = "showInInstance", label = "In Instance" },
        { key = "showMounted", label = "Mounted" },
        { key = "showOnMouseover", label = "On Mouseover" },
    }
    
    for _, opt in ipairs(visibilityOptions) do
        local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 20, yOffset)
        cb:SetSize(24, 24)
        cb:SetChecked(getBarSettings()[opt.key])
        cb.text:SetText(opt.label)
        cb.text:SetFontObject("GameFontHighlightSmall")
        cb:SetScript("OnClick", function(self)
            setBarSetting(opt.key, self:GetChecked())
            UpdateSystemBarVisibility(barId)
        end)
        yOffset = yOffset - 22
    end
    
    -- Update content height
    content:SetHeight(math.abs(yOffset) + 20)
    
    panel:Hide()
end

-- ============================================================================
-- STANCE BAR SETTINGS PANEL
-- ============================================================================

-- Stance bar defaults and helper (needed by settings panel)
local stanceBarContainer = nil
local stanceButtons = {}
local stanceUpdatePending = false  -- Flag for deferred stance updates
local STANCE_BAR_DEFAULTS = {
    enabled = false,
    hideBlizzard = true,
    buttonSize = 36,
    spacing = 2,
    orientation = "horizontal",
    columns = 10,
    barAlpha = 1.0,
    iconZoom = 0,
    iconEdgeStyle = "default",
    useMasque = false,
    visibilityEnabled = false,
    showOnMouseover = false,
    showInCombat = true,
    showOutOfCombat = true,
    showWithTarget = false,
    showSolo = true,
    showInParty = true,
    showInRaid = true,
    showInInstance = true,
}

local function GetStanceBarSettings()
    if not settings then return STANCE_BAR_DEFAULTS end
    if not settings.stanceBar then
        settings.stanceBar = CopyTable(STANCE_BAR_DEFAULTS)
    end
    for k, v in pairs(STANCE_BAR_DEFAULTS) do
        if settings.stanceBar[k] == nil then
            settings.stanceBar[k] = v
        end
    end
    return settings.stanceBar
end

function ActionBars:ToggleStanceBarPanel()
    -- Hide all other panels
    for name, panel in pairs(settingsPanels) do
        if panel then
            panel:Hide()
            self:HideBarHighlight(name)
        end
    end
    
    if stanceBarPanel then
        if stanceBarPanel:IsShown() then
            stanceBarPanel:Hide()
            currentOpenPanel = nil
        else
            stanceBarPanel:ClearAllPoints()
            stanceBarPanel:SetPoint("TOPLEFT", actionBarsHub, "TOPRIGHT", 0, 0)
            stanceBarPanel:Show()
            currentOpenPanel = "stanceBar"
        end
    else
        self:CreateStanceBarSettingsPanel()
        stanceBarPanel:ClearAllPoints()
        stanceBarPanel:SetPoint("TOPLEFT", actionBarsHub, "TOPRIGHT", 0, 0)
        stanceBarPanel:Show()
        currentOpenPanel = "stanceBar"
    end
end

function ActionBars:CreateStanceBarSettingsPanel()
    local PANEL_WIDTH = 280
    
    local function getSettings()
        return GetStanceBarSettings()
    end
    
    local function setSetting(key, value)
        local ss = GetStanceBarSettings()
        ss[key] = value
        ActionBars:SaveSettings()
        ActionBars:RefreshStanceBar()
    end
    
    local panel = CreateFrame("Frame", "TweaksUI_StanceBar_Panel", UIParent, "BackdropTemplate")
    panel:SetSize(PANEL_WIDTH, 500)
    panel:SetBackdrop(darkBackdrop)
    panel:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    panel:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    panel:SetFrameStrata("DIALOG")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:SetClampedToScreen(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    
    -- Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("Stance Bar")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() panel:Hide() currentOpenPanel = nil end)
    
    -- Scrollframe
    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 10)
    
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(PANEL_WIDTH - 40, 600)
    scrollFrame:SetScrollChild(content)
    
    local yOffset = -10
    
    -- Check if class has stances
    local numForms = GetNumShapeshiftForms()
    
    if numForms == 0 then
        local noStanceText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        noStanceText:SetPoint("TOPLEFT", 0, yOffset)
        noStanceText:SetWidth(PANEL_WIDTH - 50)
        noStanceText:SetText("|cffff9900Your class does not have stances.|r\n\nThis panel is for classes with stances:\n• Warrior (Battle, Defensive)\n• Rogue (Stealth)\n• Druid (Forms)\n• Priest (Shadowform)")
        noStanceText:SetJustifyH("LEFT")
        yOffset = yOffset - 120
    end
    
    -- Enable checkbox
    local enableCb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    enableCb:SetPoint("TOPLEFT", 0, yOffset)
    enableCb:SetSize(24, 24)
    enableCb:SetChecked(getSettings().enabled)
    enableCb.text:SetText("Enable Custom Stance Bar")
    enableCb.text:SetFontObject("GameFontNormal")
    enableCb:SetScript("OnClick", function(self)
        setSetting("enabled", self:GetChecked())
    end)
    yOffset = yOffset - 28
    
    -- Description
    local desc = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    desc:SetPoint("TOPLEFT", 25, yOffset)
    desc:SetWidth(PANEL_WIDTH - 60)
    desc:SetText("|cff888888Replaces Blizzard's stance bar with our customizable version.|r")
    desc:SetJustifyH("LEFT")
    yOffset = yOffset - 28
    
    -- Hide Blizzard checkbox
    local hideCb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    hideCb:SetPoint("TOPLEFT", 0, yOffset)
    hideCb:SetSize(24, 24)
    hideCb:SetChecked(getSettings().hideBlizzard)
    hideCb.text:SetText("Hide Blizzard Stance Bar")
    hideCb.text:SetFontObject("GameFontHighlight")
    hideCb:SetScript("OnClick", function(self)
        setSetting("hideBlizzard", self:GetChecked())
    end)
    yOffset = yOffset - 28
    
    local hideDesc = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hideDesc:SetPoint("TOPLEFT", 25, yOffset)
    hideDesc:SetWidth(PANEL_WIDTH - 60)
    hideDesc:SetText("|cff888888When disabled, both bars may show.|r")
    hideDesc:SetJustifyH("LEFT")
    yOffset = yOffset - 32
    
    -- Separator
    local sep1 = content:CreateTexture(nil, "ARTWORK")
    sep1:SetPoint("TOPLEFT", 0, yOffset)
    sep1:SetSize(PANEL_WIDTH - 50, 1)
    sep1:SetColorTexture(0.4, 0.4, 0.4, 0.6)
    yOffset = yOffset - 15
    
    -- Layout section
    local layoutLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    layoutLabel:SetPoint("TOPLEFT", 0, yOffset)
    layoutLabel:SetText("Layout")
    layoutLabel:SetTextColor(1, 0.82, 0)
    yOffset = yOffset - 22
    
    -- Button Size slider
    local sizeLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    sizeLabel:SetPoint("TOPLEFT", 0, yOffset)
    sizeLabel:SetText("Button Size: " .. (getSettings().buttonSize or 36))
    yOffset = yOffset - 18
    
    local sizeSlider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
    sizeSlider:SetPoint("TOPLEFT", 0, yOffset)
    sizeSlider:SetWidth(PANEL_WIDTH - 60)
    sizeSlider:SetMinMaxValues(20, 64)
    sizeSlider:SetValueStep(1)
    sizeSlider:SetObeyStepOnDrag(true)
    sizeSlider:SetValue(getSettings().buttonSize or 36)
    sizeSlider.Low:SetText("20")
    sizeSlider.High:SetText("64")
    sizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        sizeLabel:SetText("Button Size: " .. value)
        setSetting("buttonSize", value)
    end)
    yOffset = yOffset - 30
    
    -- Spacing slider
    local spacingLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    spacingLabel:SetPoint("TOPLEFT", 0, yOffset)
    spacingLabel:SetText("Spacing: " .. (getSettings().spacing or 2))
    yOffset = yOffset - 18
    
    local spacingSlider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
    spacingSlider:SetPoint("TOPLEFT", 0, yOffset)
    spacingSlider:SetWidth(PANEL_WIDTH - 60)
    spacingSlider:SetMinMaxValues(0, 20)
    spacingSlider:SetValueStep(1)
    spacingSlider:SetObeyStepOnDrag(true)
    spacingSlider:SetValue(getSettings().spacing or 2)
    spacingSlider.Low:SetText("0")
    spacingSlider.High:SetText("20")
    spacingSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        spacingLabel:SetText("Spacing: " .. value)
        setSetting("spacing", value)
    end)
    yOffset = yOffset - 30
    
    -- Orientation checkbox
    local vertCb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    vertCb:SetPoint("TOPLEFT", 0, yOffset)
    vertCb:SetSize(24, 24)
    vertCb:SetChecked(getSettings().orientation == "vertical")
    vertCb.text:SetText("Vertical Layout")
    vertCb.text:SetFontObject("GameFontHighlight")
    vertCb:SetScript("OnClick", function(self)
        setSetting("orientation", self:GetChecked() and "vertical" or "horizontal")
    end)
    yOffset = yOffset - 28
    
    -- Alpha slider
    local alphaLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    alphaLabel:SetPoint("TOPLEFT", 0, yOffset)
    alphaLabel:SetText("Opacity: " .. math.floor((getSettings().barAlpha or 1) * 100) .. "%")
    yOffset = yOffset - 18
    
    local alphaSlider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
    alphaSlider:SetPoint("TOPLEFT", 0, yOffset)
    alphaSlider:SetWidth(PANEL_WIDTH - 60)
    alphaSlider:SetMinMaxValues(0, 100)
    alphaSlider:SetValueStep(5)
    alphaSlider:SetObeyStepOnDrag(true)
    alphaSlider:SetValue((getSettings().barAlpha or 1) * 100)
    alphaSlider.Low:SetText("0%")
    alphaSlider.High:SetText("100%")
    alphaSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        alphaLabel:SetText("Opacity: " .. value .. "%")
        setSetting("barAlpha", value / 100)
    end)
    yOffset = yOffset - 30
    
    -- Icon Zoom slider
    local zoomLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    zoomLabel:SetPoint("TOPLEFT", 0, yOffset)
    zoomLabel:SetText("Icon Zoom: " .. math.floor((getSettings().iconZoom or 0) * 100) .. "%")
    yOffset = yOffset - 18
    
    local zoomSlider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
    zoomSlider:SetPoint("TOPLEFT", 0, yOffset)
    zoomSlider:SetWidth(PANEL_WIDTH - 60)
    zoomSlider:SetMinMaxValues(0, 20)
    zoomSlider:SetValueStep(1)
    zoomSlider:SetObeyStepOnDrag(true)
    zoomSlider:SetValue((getSettings().iconZoom or 0) * 100)
    zoomSlider.Low:SetText("0%")
    zoomSlider.High:SetText("20%")
    zoomSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        zoomLabel:SetText("Icon Zoom: " .. value .. "%")
        setSetting("iconZoom", value / 100)
    end)
    yOffset = yOffset - 35
    
    -- Separator
    local sep2 = content:CreateTexture(nil, "ARTWORK")
    sep2:SetPoint("TOPLEFT", 0, yOffset)
    sep2:SetSize(PANEL_WIDTH - 50, 1)
    sep2:SetColorTexture(0.4, 0.4, 0.4, 0.6)
    yOffset = yOffset - 15
    
    -- Visibility section
    local visLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    visLabel:SetPoint("TOPLEFT", 0, yOffset)
    visLabel:SetText("Visibility")
    visLabel:SetTextColor(1, 0.82, 0)
    yOffset = yOffset - 22
    
    local visOptions = {
        { key = "visibilityEnabled", label = "Enable Visibility Controls" },
        { key = "showOnMouseover", label = "Show on Mouseover" },
        { key = "showInCombat", label = "Show in Combat" },
        { key = "showOutOfCombat", label = "Show out of Combat" },
        { key = "showWithTarget", label = "Show with Target" },
        { key = "showSolo", label = "Show Solo" },
        { key = "showInParty", label = "Show in Party" },
        { key = "showInRaid", label = "Show in Raid" },
        { key = "showInInstance", label = "Show in Instance" },
    }
    
    for _, opt in ipairs(visOptions) do
        local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 0, yOffset)
        cb:SetSize(22, 22)
        cb:SetChecked(getSettings()[opt.key])
        cb.text:SetText(opt.label)
        cb.text:SetFontObject("GameFontHighlightSmall")
        cb:SetScript("OnClick", function(self)
            setSetting(opt.key, self:GetChecked())
        end)
        yOffset = yOffset - 22
    end
    
    -- Update content height
    content:SetHeight(math.abs(yOffset) + 20)
    
    panel:Hide()
    stanceBarPanel = panel
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function ActionBars:GetSettings()
    return settings
end

function ActionBars:SaveSettings()
    if settings then
        TweaksUI.Database:SetModuleSettings(self.id, settings)
    end
end

function ActionBars:Refresh()
    self:ApplyAllLayouts()
    ApplyAllSystemBarLayouts()
    self:ApplyAllVisibility()
    ApplyAllSystemBarVisibility()
    self:ApplyAllCooldownSettings()
    self:ApplyAllRangeIndicators()
    self:ApplyAllIconEdgeStyles()
end

function ActionBars:GetBarWrapper(barId)
    return barWrappers[barId]
end

function ActionBars:GetAllWrappers()
    return barWrappers
end

function ActionBars:GetSystemBarWrapper(barId)
    return systemBarWrappers[barId]
end

function ActionBars:GetAllSystemBarWrappers()
    return systemBarWrappers
end

-- ============================================================================
-- CUSTOM STANCE BAR FUNCTIONS
-- ============================================================================

local function HideBlizzardStanceBar()
    local blizzStanceBar = _G["StanceBar"]
    if blizzStanceBar then
        blizzStanceBar:SetAlpha(0)
        blizzStanceBar:EnableMouse(false)
        -- Hide individual buttons too
        for i = 1, 10 do
            local btn = _G["StanceButton" .. i]
            if btn then
                btn:SetAlpha(0)
                btn:EnableMouse(false)
            end
        end
    end
end

local function ShowBlizzardStanceBar()
    local blizzStanceBar = _G["StanceBar"]
    if blizzStanceBar then
        blizzStanceBar:SetAlpha(1)
        blizzStanceBar:EnableMouse(true)
        for i = 1, 10 do
            local btn = _G["StanceButton" .. i]
            if btn then
                btn:SetAlpha(1)
                btn:EnableMouse(true)
            end
        end
    end
end

local function UpdateStanceButton(button, index)
    local numForms = GetNumShapeshiftForms()
    if index > numForms then
        -- Only hide if not in combat (secure frame restriction)
        if not InCombatLockdown() then
            button:Hide()
        else
            stanceUpdatePending = true
        end
        return
    end
    
    local icon, isActive, isCastable, spellID = GetShapeshiftFormInfo(index)
    
    -- Set icon
    if button.icon then
        button.icon:SetTexture(icon)
        
        -- Apply icon zoom
        local ss = GetStanceBarSettings()
        local zoom = ss.iconZoom or 0
        if zoom > 0 then
            local inset = zoom * 0.5
            button.icon:SetTexCoord(inset, 1 - inset, inset, 1 - inset)
        else
            button.icon:SetTexCoord(0, 1, 0, 1)
        end
        
        -- Desaturate if not castable
        button.icon:SetDesaturated(not isCastable)
    end
    
    -- Show checked texture if active
    if button.checkedTexture then
        button.checkedTexture:SetShown(isActive)
    end
    
    -- Update cooldown (Midnight Duration Object API)
    if button.cooldown and spellID then
        local duration = C_Spell.GetSpellCooldownDuration(spellID)
        if duration then
            button.cooldown:SetCooldownFromDurationObject(duration, true)
        else
            button.cooldown:Clear()
        end
    end
    
    button.stanceIndex = index
    -- Only show if not in combat (secure frame restriction)
    if not InCombatLockdown() then
        button:Show()
    else
        stanceUpdatePending = true
    end
end

local function UpdateAllStanceButtons()
    if not stanceBarContainer then return end
    
    local numForms = GetNumShapeshiftForms()
    for i, button in ipairs(stanceButtons) do
        UpdateStanceButton(button, i)
    end
    
    -- Update container visibility (only if not in combat)
    if not InCombatLockdown() then
        local ss = GetStanceBarSettings()
        if ss.enabled and numForms > 0 then
            stanceBarContainer:Show()
        else
            stanceBarContainer:Hide()
        end
    else
        stanceUpdatePending = true
    end
end

-- Register stance bar with Layout module (defined early so it can be called from ApplyStanceBarLayout)
local stanceBarRegistered = false
local function RegisterStanceBarWithLayout()
    if not stanceBarContainer then return end
    if stanceBarRegistered then return end
    
    -- Use TweaksUI.Layout directly (same as other bar registrations)
    local LayoutModule = TweaksUI.Layout
    if not LayoutModule then return end
    
    LayoutModule:RegisterElement("stanceBar", {
        name = "Stance Bar",
        category = LayoutModule.CATEGORIES.ACTION_BARS,
        tuiFrame = stanceBarContainer,
        defaultPosition = { point = "BOTTOMLEFT", x = 5, y = 100 },
        onPositionChanged = function(id, saveData)
            -- Position saved by TUIFrame automatically
        end,
    })
    
    stanceBarRegistered = true
end

local function CreateStanceButton(index)
    local ss = GetStanceBarSettings()
    local size = ss.buttonSize or 36
    
    local button = CreateFrame("CheckButton", "TweaksUI_StanceButton" .. index, stanceBarContainer.frame, "SecureActionButtonTemplate")
    button:SetSize(size, size)
    button:RegisterForClicks("AnyUp", "AnyDown")
    
    -- Set up secure click handler
    button:SetAttribute("type", "spell")
    button:SetScript("PreClick", function(self, mouseButton, down)
        if self.stanceIndex then
            local _, _, _, spellID = GetShapeshiftFormInfo(self.stanceIndex)
            if spellID then
                self:SetAttribute("spell", spellID)
            end
        end
    end)
    
    -- Background/border (black edge around icon)
    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()
    button.bg:SetColorTexture(0, 0, 0, 1)
    
    -- Icon (inset from edge to show border)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 1, -1)
    button.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    
    -- Checked texture (gold glow when stance is active)
    button.checkedTexture = button:CreateTexture(nil, "OVERLAY")
    button.checkedTexture:SetAllPoints()
    button.checkedTexture:SetAtlas("UI-HUD-ActionBar-IconFrame-Glow")
    button.checkedTexture:SetBlendMode("ADD")
    button.checkedTexture:Hide()
    
    -- Highlight (on mouseover) - use built-in method
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(button.icon)
    highlight:SetColorTexture(1, 1, 1, 0.3)
    
    -- Pushed texture
    button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    
    -- Cooldown
    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints(button.icon)
    button.cooldown:SetDrawEdge(true)
    button.cooldown:SetDrawSwipe(true)
    
    button.stanceIndex = index
    
    return button
end

-- Forward declaration for visibility function (defined later, but needed by CreateStanceBarContainer)
local ApplyStanceBarVisibility

local function CreateStanceBarContainer()
    if stanceBarContainer then return stanceBarContainer end
    
    -- Create TUI wrapper for Layout integration
    stanceBarContainer = TweaksUI.TUIFrame:New("TweaksUI_StanceBar", {
        defaultPosition = { point = "BOTTOMLEFT", x = 5, y = 100 },
    })
    stanceBarContainer:SetSize(200, 40)
    
    -- Create buttons (max 10 for any class)
    for i = 1, 10 do
        local button = CreateStanceButton(i)
        stanceButtons[i] = button
    end
    
    -- Register events on the actual frame
    stanceBarContainer.frame:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
    stanceBarContainer.frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    stanceBarContainer.frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    stanceBarContainer.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    stanceBarContainer.frame:RegisterEvent("UPDATE_SHAPESHIFT_USABLE")
    stanceBarContainer.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    stanceBarContainer.frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    stanceBarContainer.frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    stanceBarContainer.frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    
    stanceBarContainer.frame:SetScript("OnEvent", function(self, event)
        if event == "UPDATE_SHAPESHIFT_FORMS" or event == "UPDATE_SHAPESHIFT_FORM" 
           or event == "SPELL_UPDATE_COOLDOWN" or event == "UPDATE_SHAPESHIFT_USABLE" 
           or event == "PLAYER_ENTERING_WORLD" then
            UpdateAllStanceButtons()
        elseif event == "PLAYER_REGEN_ENABLED" and stanceUpdatePending then
            -- Combat ended, process any deferred visibility updates
            stanceUpdatePending = false
            UpdateAllStanceButtons()
        end
        -- Visibility events
        ApplyStanceBarVisibility()
    end)
    
    -- Mouseover detection for visibility
    local visibilityUpdater = CreateFrame("Frame", nil, stanceBarContainer.frame)
    visibilityUpdater:SetAllPoints()
    visibilityUpdater:EnableMouse(false)
    visibilityUpdater.throttle = 0
    visibilityUpdater.isMouseOver = false
    
    visibilityUpdater:SetScript("OnUpdate", function(self, elapsed)
        self.throttle = self.throttle + elapsed
        if self.throttle < 0.05 then return end
        self.throttle = 0
        
        -- Check if mouse is over container or any stance button
        local mouseOver = stanceBarContainer.frame:IsMouseOver()
        if not mouseOver then
            for _, button in ipairs(stanceButtons) do
                if button and button:IsShown() and button:IsMouseOver() then
                    mouseOver = true
                    break
                end
            end
        end
        
        -- Update visibility if mouseover state changed
        if mouseOver ~= self.isMouseOver then
            self.isMouseOver = mouseOver
            stanceBarContainer.tweaksIsMouseOver = mouseOver
            ApplyStanceBarVisibility()
        end
    end)
    
    return stanceBarContainer
end

local function ApplyStanceBarLayout()
    local ss = GetStanceBarSettings()
    
    -- Handle Blizzard's stance bar
    if ss.hideBlizzard then
        HideBlizzardStanceBar()
    else
        ShowBlizzardStanceBar()
    end
    
    -- If not enabled, hide our bar and optionally show Blizzard's
    if not ss.enabled then
        if stanceBarContainer then
            stanceBarContainer:Hide()
        end
        if not ss.hideBlizzard then
            ShowBlizzardStanceBar()
        end
        return
    end
    
    -- Create container if needed
    if not stanceBarContainer then
        CreateStanceBarContainer()
        RegisterStanceBarWithLayout()
    end
    
    local numForms = GetNumShapeshiftForms()
    if numForms == 0 then
        stanceBarContainer:Hide()
        return
    end
    
    local size = ss.buttonSize or 36
    local spacing = ss.spacing or 2
    local isVertical = ss.orientation == "vertical"
    local columns = ss.columns or 10
    
    -- Position buttons
    local col, row = 0, 0
    for i = 1, numForms do
        local button = stanceButtons[i]
        if button then
            button:SetSize(size, size)
            
            local xOffset, yOffset
            if isVertical then
                xOffset = row * (size + spacing)
                yOffset = -col * (size + spacing)
                col = col + 1
                if col >= columns then
                    col = 0
                    row = row + 1
                end
            else
                xOffset = col * (size + spacing)
                yOffset = -row * (size + spacing)
                col = col + 1
                if col >= columns then
                    col = 0
                    row = row + 1
                end
            end
            
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", stanceBarContainer.frame, "TOPLEFT", xOffset, yOffset)
            
            UpdateStanceButton(button, i)
        end
    end
    
    -- Hide unused buttons
    for i = numForms + 1, 10 do
        if stanceButtons[i] then
            stanceButtons[i]:Hide()
        end
    end
    
    -- Size container to fit buttons
    local totalCols = math.min(numForms, columns)
    local totalRows = math.ceil(numForms / columns)
    
    local containerWidth, containerHeight
    if isVertical then
        containerWidth = totalRows * (size + spacing) - spacing
        containerHeight = totalCols * (size + spacing) - spacing
    else
        containerWidth = totalCols * (size + spacing) - spacing
        containerHeight = totalRows * (size + spacing) - spacing
    end
    
    stanceBarContainer:SetSize(math.max(containerWidth, size), math.max(containerHeight, size))
    
    -- Initialize mouseover state if not set
    if stanceBarContainer.tweaksIsMouseOver == nil then
        stanceBarContainer.tweaksIsMouseOver = false
    end
    
    -- Always show the container, visibility will control alpha
    stanceBarContainer:Show()
    UpdateAllStanceButtons()
    
    -- Apply visibility settings (handles mouseover, combat, etc.)
    -- This will set the correct alpha based on conditions
    ApplyStanceBarVisibility()
end

ApplyStanceBarVisibility = function()
    if not stanceBarContainer then return end
    
    -- Skip visibility changes during combat (secure frame children)
    if InCombatLockdown() then
        stanceUpdatePending = true
        return
    end
    
    local ss = GetStanceBarSettings()
    if not ss.enabled then
        stanceBarContainer:Hide()
        return
    end
    
    -- Check if we have stances
    local numForms = GetNumShapeshiftForms()
    if numForms == 0 then
        stanceBarContainer:Hide()
        return
    end
    
    -- Force all visible mode
    if TweaksUI.forceAllVisible then
        stanceBarContainer:Show()
        stanceBarContainer:SetAlpha(ss.barAlpha or 1)
        return
    end
    
    -- Layout mode
    local Layout = TweaksUI.Layout
    if Layout and Layout:IsActive() then
        stanceBarContainer:Show()
        stanceBarContainer:SetAlpha(ss.barAlpha or 1)
        return
    end
    
    -- Check visibility conditions
    if not ss.visibilityEnabled then
        stanceBarContainer:Show()
        stanceBarContainer:SetAlpha(ss.barAlpha or 1)
        return
    end
    
    local shouldShow = false
    
    -- Mouseover check - use cached state from OnUpdate polling
    if ss.showOnMouseover and stanceBarContainer.tweaksIsMouseOver then
        shouldShow = true
    end
    
    -- Combat check
    local inCombat = UnitAffectingCombat("player")
    if ss.showInCombat and inCombat then shouldShow = true end
    if ss.showOutOfCombat and not inCombat then shouldShow = true end
    
    -- Target check
    if ss.showWithTarget and UnitExists("target") then shouldShow = true end
    
    -- Group check
    local inParty = IsInGroup() and not IsInRaid()
    local inRaid = IsInRaid()
    local solo = not IsInGroup()
    
    if ss.showSolo and solo then shouldShow = true end
    if ss.showInParty and inParty then shouldShow = true end
    if ss.showInRaid and inRaid then shouldShow = true end
    
    -- Instance check
    local _, instanceType = IsInInstance()
    if ss.showInInstance and instanceType ~= "none" then shouldShow = true end
    
    if shouldShow then
        stanceBarContainer:Show()
        stanceBarContainer:SetAlpha(ss.barAlpha or 1)
    else
        stanceBarContainer:SetAlpha(0)
    end
end

function ActionBars:GetStanceBarContainer()
    return stanceBarContainer
end

function ActionBars:RefreshStanceBar()
    ApplyStanceBarLayout()
    ApplyStanceBarVisibility()
end

-- ============================================================================
-- QUICK KEYBIND MODE
-- ============================================================================

local isKeybindModeActive = false
local keybindOverlays = {}
local savedVisibilityStates = {}
local keybindModeFrame = nil

local function GetActionButtonCommand(button)
    local name = button:GetName()
    if not name then return nil end
    
    -- Map button names to binding commands
    if name:match("^ActionButton(%d+)$") then
        local num = tonumber(name:match("^ActionButton(%d+)$"))
        return "ACTIONBUTTON" .. num
    elseif name:match("^MultiBarBottomLeftButton(%d+)$") then
        local num = tonumber(name:match("^MultiBarBottomLeftButton(%d+)$"))
        return "MULTIACTIONBAR1BUTTON" .. num
    elseif name:match("^MultiBarBottomRightButton(%d+)$") then
        local num = tonumber(name:match("^MultiBarBottomRightButton(%d+)$"))
        return "MULTIACTIONBAR2BUTTON" .. num
    elseif name:match("^MultiBarRightButton(%d+)$") then
        local num = tonumber(name:match("^MultiBarRightButton(%d+)$"))
        return "MULTIACTIONBAR3BUTTON" .. num
    elseif name:match("^MultiBarLeftButton(%d+)$") then
        local num = tonumber(name:match("^MultiBarLeftButton(%d+)$"))
        return "MULTIACTIONBAR4BUTTON" .. num
    elseif name:match("^MultiBar5Button(%d+)$") then
        local num = tonumber(name:match("^MultiBar5Button(%d+)$"))
        return "MULTIACTIONBAR5BUTTON" .. num
    elseif name:match("^MultiBar6Button(%d+)$") then
        local num = tonumber(name:match("^MultiBar6Button(%d+)$"))
        return "MULTIACTIONBAR6BUTTON" .. num
    elseif name:match("^MultiBar7Button(%d+)$") then
        local num = tonumber(name:match("^MultiBar7Button(%d+)$"))
        return "MULTIACTIONBAR7BUTTON" .. num
    elseif name:match("^StanceButton(%d+)$") then
        local num = tonumber(name:match("^StanceButton(%d+)$"))
        return "SHAPESHIFTBUTTON" .. num
    end
    
    return nil
end

local function GetKeyText(key)
    if not key or key == "" then return "" end
    
    -- Format modifier keys nicely
    local text = key
    text = text:gsub("ALT%-", "Alt+")
    text = text:gsub("CTRL%-", "Ctrl+")
    text = text:gsub("SHIFT%-", "Shift+")
    text = text:gsub("META%-", "Meta+")
    
    return text
end

local function CreateKeybindOverlay(button)
    local name = button:GetName()
    if not name then return nil end
    if keybindOverlays[name] then return keybindOverlays[name] end
    
    local overlay = CreateFrame("Button", nil, button)
    overlay:SetAllPoints()
    overlay:SetFrameStrata("TOOLTIP")
    overlay:EnableMouse(true)
    
    -- Background
    local bg = overlay:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.7)
    overlay.bg = bg
    
    -- Highlight
    local highlight = overlay:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0, 0.5, 1, 0.3)
    
    -- Current keybind text
    local text = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER", 0, 0)
    text:SetTextColor(1, 1, 0)
    overlay.text = text
    
    -- Instruction text (shown on hover)
    local instruction = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    instruction:SetPoint("TOP", overlay, "BOTTOM", 0, -2)
    instruction:SetText("|cff888888Press key to bind|r")
    instruction:Hide()
    overlay.instruction = instruction
    
    overlay.button = button
    overlay.command = GetActionButtonCommand(button)
    
    overlay:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0, 0.3, 0.6, 0.8)
        self.instruction:Show()
        -- Set this as the active button for key capture
        if keybindModeFrame then
            keybindModeFrame.activeButton = self
        end
    end)
    
    overlay:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0, 0, 0, 0.7)
        self.instruction:Hide()
        if keybindModeFrame and keybindModeFrame.activeButton == self then
            keybindModeFrame.activeButton = nil
        end
    end)
    
    -- Click to clear binding
    overlay:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" and self.command then
            -- Clear the binding
            local key1, key2 = GetBindingKey(self.command)
            if key1 then SetBinding(key1) end
            if key2 then SetBinding(key2) end
            SaveBindings(GetCurrentBindingSet())
            ActionBars:UpdateKeybindOverlays()
            TweaksUI:Print("Cleared keybind for " .. (self.command or "button"))
        end
    end)
    overlay:RegisterForClicks("RightButtonUp")
    
    keybindOverlays[name] = overlay
    return overlay
end

local function UpdateOverlayText(overlay)
    if not overlay or not overlay.command then return end
    
    local key1, key2 = GetBindingKey(overlay.command)
    local keyText = GetKeyText(key1)
    if key2 then
        keyText = keyText .. "\n" .. GetKeyText(key2)
    end
    
    if keyText == "" then
        overlay.text:SetText("|cff666666Unbound|r")
    else
        overlay.text:SetText(keyText)
    end
end

function ActionBars:UpdateKeybindOverlays()
    for _, overlay in pairs(keybindOverlays) do
        UpdateOverlayText(overlay)
    end
end

function ActionBars:EnterKeybindMode()
    if isKeybindModeActive then return end
    if InCombatLockdown() then
        TweaksUI:Print("Cannot enter keybind mode during combat")
        return
    end
    
    -- Clean up any leftover overlays from previous failed attempts
    for _, overlay in pairs(keybindOverlays) do
        overlay:Hide()
    end
    
    isKeybindModeActive = true
    savedVisibilityStates = {}
    
    -- Save current visibility states and force show all bars
    for barId, info in pairs(BAR_INFO) do
        local barSettings = settings and settings.bars and settings.bars[barId]
        if barSettings then
            savedVisibilityStates[barId] = {
                enabled = barSettings.enabled,
                visibilityEnabled = barSettings.visibilityEnabled,
            }
            -- Force visibility
            local wrapper = barWrappers[barId]
            if wrapper and wrapper.frame then
                wrapper.frame:SetAlpha(1)
            end
            local visFrame = GetVisibilityFrame(barId)
            if visFrame then
                visFrame:SetAlpha(1)
            end
        end
    end
    
    -- Also show stance bar
    local stanceBar = _G["StanceBar"]
    if stanceBar then
        savedVisibilityStates["StanceBar"] = { alpha = stanceBar:GetAlpha() }
        stanceBar:SetAlpha(1)
    end
    
    -- Create overlays for all action buttons
    for barId, info in pairs(BAR_INFO) do
        for i = 1, info.buttonCount do
            local button = _G[info.buttonPrefix .. i]
            if button then
                local overlay = CreateKeybindOverlay(button)
                if overlay then
                    overlay:Show()
                    UpdateOverlayText(overlay)
                end
            end
        end
    end
    
    -- Create overlays for stance buttons
    for i = 1, 10 do
        local button = _G["StanceButton" .. i]
        if button and button:IsShown() then
            local overlay = CreateKeybindOverlay(button)
            if overlay then
                overlay:Show()
                UpdateOverlayText(overlay)
            end
        end
    end
    
    -- Create key capture frame
    if not keybindModeFrame then
        keybindModeFrame = CreateFrame("Frame", "TweaksUI_KeybindModeFrame", UIParent)
        keybindModeFrame:SetFrameStrata("TOOLTIP")
        keybindModeFrame:SetAllPoints()
        keybindModeFrame:EnableMouse(false)  -- CRITICAL: Prevent mouse blocking
        keybindModeFrame:EnableKeyboard(true)
        keybindModeFrame:SetPropagateKeyboardInput(false)
        
        -- CRITICAL: Hook OnShow/OnHide to handle addon conflicts (e.g., DialogueUI)
        keybindModeFrame:HookScript("OnShow", function(self)
            -- Only allow showing when keybind mode is actually active
            if not isKeybindModeActive then
                self:EnableMouse(false)
                self:Hide()
            end
        end)
        
        keybindModeFrame:HookScript("OnHide", function(self)
            -- Always ensure mouse is disabled when hidden
            self:EnableMouse(false)
        end)
        
        keybindModeFrame:SetScript("OnKeyDown", function(self, key)
            -- Escape exits keybind mode
            if key == "ESCAPE" then
                ActionBars:ExitKeybindMode()
                return
            end
            
            -- Ignore modifier keys alone
            if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" 
               or key == "LALT" or key == "RALT" or key == "LMETA" or key == "RMETA" then
                return
            end
            
            if not self.activeButton or not self.activeButton.command then return end
            
            -- Build the key combination
            local combo = ""
            if IsAltKeyDown() then combo = combo .. "ALT-" end
            if IsControlKeyDown() then combo = combo .. "CTRL-" end
            if IsShiftKeyDown() then combo = combo .. "SHIFT-" end
            combo = combo .. key
            
            -- Check if this key is already bound to something else
            local existingAction = GetBindingAction(combo)
            if existingAction and existingAction ~= "" and existingAction ~= self.activeButton.command then
                -- Clear existing binding first
                SetBinding(combo)
            end
            
            -- Set the new binding
            local success = SetBinding(combo, self.activeButton.command)
            if success then
                SaveBindings(GetCurrentBindingSet())
                ActionBars:UpdateKeybindOverlays()
                TweaksUI:Print("Bound |cff00ff00" .. GetKeyText(combo) .. "|r to |cff00ffff" .. self.activeButton.command .. "|r")
            else
                TweaksUI:Print("|cffff0000Failed to set keybind|r")
            end
        end)
    end
    
    keybindModeFrame:Show()
    
    -- Show instruction banner
    if not keybindModeFrame.banner then
        local banner = CreateFrame("Frame", nil, keybindModeFrame, "BackdropTemplate")
        banner:SetSize(400, 60)
        banner:SetPoint("TOP", UIParent, "TOP", 0, -100)
        banner:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 2,
        })
        banner:SetBackdropColor(0, 0, 0, 0.9)
        banner:SetBackdropBorderColor(0, 0.5, 1, 1)
        
        local title = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -10)
        title:SetText("|cff00ccffQuick Keybind Mode|r")
        
        local info = banner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        info:SetPoint("TOP", title, "BOTTOM", 0, -5)
        info:SetText("Hover button + press key to bind | Right-click to clear | ESC to exit")
        info:SetTextColor(0.8, 0.8, 0.8)
        
        keybindModeFrame.banner = banner
    end
    keybindModeFrame.banner:Show()
    
    TweaksUI:Print("Entered |cff00ccffQuick Keybind Mode|r - Hover over buttons and press keys to bind")
end

function ActionBars:ExitKeybindMode()
    if not isKeybindModeActive then return end
    
    isKeybindModeActive = false
    
    -- Hide all overlays
    for _, overlay in pairs(keybindOverlays) do
        overlay:Hide()
    end
    
    -- Hide capture frame
    if keybindModeFrame then
        keybindModeFrame:Hide()
        if keybindModeFrame.banner then
            keybindModeFrame.banner:Hide()
        end
    end
    
    -- Restore visibility states
    for barId, saved in pairs(savedVisibilityStates) do
        if barId == "StanceBar" then
            local stanceBar = _G["StanceBar"]
            if stanceBar and saved.alpha then
                stanceBar:SetAlpha(saved.alpha)
            end
        else
            -- Reapply visibility for action bars
            UpdateBarVisibility(barId)
        end
    end
    savedVisibilityStates = {}
    
    TweaksUI:Print("Exited |cff00ccffQuick Keybind Mode|r")
end

function ActionBars:ToggleKeybindMode()
    if isKeybindModeActive then
        self:ExitKeybindMode()
    else
        self:EnterKeybindMode()
    end
end

function ActionBars:IsKeybindModeActive()
    return isKeybindModeActive
end

-- ============================================================================
-- MODULE LIFECYCLE
-- ============================================================================

-- ============================================================================
-- MASQUE SUPPORT
-- ============================================================================

local function InitializeActionBarsMasque()
    -- Deferred lookup - Masque may not be loaded at file parse time
    if not Masque then
        Masque = LibStub and LibStub("Masque", true)
    end
    
    if not Masque then 
        DebugPrint("Masque not found")
        return false 
    end
    
    -- Create Masque group for each action bar
    for barId, info in pairs(BAR_INFO) do
        if not MasqueGroups[barId] then
            MasqueGroups[barId] = Masque:Group("TweaksUI", info.displayName)
            DebugPrint(string.format("Masque: Created group for %s", info.displayName))
        end
    end
    
    -- Register callback for skin changes
    if Masque.RegisterCallback then
        Masque:RegisterCallback("TweaksUI_ActionBars", function(_, group, skinID)
            DebugPrint(string.format("Masque: Skin changed to %s", skinID or "default"))
        end)
    end
    
    DebugPrint("Masque: Initialized successfully")
    return true
end

local function AddButtonToMasque(barId, button)
    if not Masque then return end
    if not settings or not settings.bars or not settings.bars[barId] then return end
    if not settings.bars[barId].useMasque then return end
    
    local group = MasqueGroups[barId]
    if not group then return end
    
    -- Build button data for Masque
    local data = {
        Icon = button.icon or button.Icon,
        Cooldown = button.cooldown or button.Cooldown,
        Normal = button:GetNormalTexture(),
        Pushed = button:GetPushedTexture(),
        Highlight = button:GetHighlightTexture(),
        Border = button.Border or button.IconBorder,
        Count = button.Count,
        HotKey = button.HotKey,
        Name = button.Name,
        FloatingBG = button.FloatingBG,
    }
    
    -- Add to group
    group:AddButton(button, data)
    button._TUI_MasqueGroup = barId
    
    DebugPrint(string.format("Masque: Added button to %s group", barId))
end

local function RemoveButtonFromMasque(button)
    if not Masque then return end
    if not button._TUI_MasqueGroup then return end
    
    local group = MasqueGroups[button._TUI_MasqueGroup]
    if group then
        group:RemoveButton(button)
        DebugPrint(string.format("Masque: Removed button from %s group", button._TUI_MasqueGroup))
    end
    button._TUI_MasqueGroup = nil
end

local function RefreshMasqueForBar(barId)
    if not Masque then return end
    local group = MasqueGroups[barId]
    if group then
        group:ReSkin()
        DebugPrint(string.format("Masque: Reskinned %s group", barId))
    end
end

local function ApplyMasqueToBar(barId)
    if not Masque then return end
    if not settings or not settings.bars or not settings.bars[barId] then return end
    
    local info = BAR_INFO[barId]
    if not info then return end
    
    local useMasque = settings.bars[barId].useMasque
    
    for i = 1, info.buttonCount do
        local button = _G[info.buttonPrefix .. i]
        if button then
            if useMasque and not button._TUI_MasqueGroup then
                AddButtonToMasque(barId, button)
            elseif not useMasque and button._TUI_MasqueGroup then
                RemoveButtonFromMasque(button)
            end
        end
    end
    
    if useMasque then
        RefreshMasqueForBar(barId)
    end
end

-- Public Masque interface
function ActionBars:IsMasqueAvailable()
    return Masque ~= nil
end

function ActionBars:GetMasqueGroup(barId)
    return MasqueGroups[barId]
end

function ActionBars:RefreshMasqueGroup(barId)
    if MasqueGroups[barId] then
        MasqueGroups[barId]:ReSkin()
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function ActionBars:OnInitialize()
    DebugPrint("OnInitialize")
    
    local db = TweaksUI.Database:GetModuleSettings(self.id)
    
    -- Initialize with defaults if empty
    if not db or not next(db) then
        db = DeepCopy(DEFAULT_SETTINGS)
        TweaksUI.Database:SetModuleSettings(self.id, db)
    end
    
    -- Ensure bars table exists
    if not db.bars then
        db.bars = {}
    end
    
    -- Ensure all bars have settings (handles partial profiles)
    local needsSave = false
    for barId, _ in pairs(BAR_INFO) do
        if not db.bars[barId] then
            db.bars[barId] = GetDefaultBarSettings()
            needsSave = true
        else
            -- Ensure all default keys exist for this bar
            local defaults = GetDefaultBarSettings()
            for key, value in pairs(defaults) do
                if db.bars[barId][key] == nil then
                    db.bars[barId][key] = value
                    needsSave = true
                end
            end
        end
    end
    
    -- Ensure system bars table exists
    if not db.systemBars then
        db.systemBars = {}
    end
    
    -- Ensure all system bars have settings
    for barId, _ in pairs(SYSTEM_BAR_INFO) do
        if not db.systemBars[barId] then
            db.systemBars[barId] = GetDefaultSystemBarSettings()
            needsSave = true
        else
            -- Ensure all default keys exist for this system bar
            local defaults = GetDefaultSystemBarSettings()
            for key, value in pairs(defaults) do
                if db.systemBars[barId][key] == nil then
                    db.systemBars[barId][key] = value
                    needsSave = true
                end
            end
        end
    end
    
    -- Ensure top-level defaults
    EnsureDefaults(db, DEFAULT_SETTINGS)
    
    settings = db
    
    -- Save if we added any missing bars or settings
    if needsSave then
        TweaksUI.Database:SetModuleSettings(self.id, settings)
    end
    
    -- Initialize Masque support
    InitializeActionBarsMasque()
    
    DebugPrint("Settings loaded")
end

function ActionBars:OnEnable()
    DebugPrint("OnEnable")
    
    if not settings then return end
    
    -- Clean up any leftover keybind overlays from previous sessions
    for _, overlay in pairs(keybindOverlays) do
        overlay:Hide()
    end
    isKeybindModeActive = false
    
    -- Initialize TUIFrame and Layout references
    TUIFrame = TweaksUI.TUIFrame
    Layout = TweaksUI.Layout
    
    -- Clear stored positions to get fresh measurements from Blizzard's defaults
    originalButtonPositions = {}
    
    settings.enabled = true
    SetupEvents()
    
    -- Apply layouts after a short delay to ensure frames are ready
    C_Timer.After(0.5, function()
        self:ApplyAllLayouts()
        ApplyAllSystemBarLayouts()
        
        -- Always create stance bar container so it can be registered with Layout
        -- (will be hidden if disabled or class has no stances)
        local numForms = GetNumShapeshiftForms()
        if numForms > 0 and not stanceBarContainer then
            CreateStanceBarContainer()
        end
        if stanceBarContainer then
            RegisterStanceBarWithLayout()  -- Register with Layout module
        end
        ApplyStanceBarLayout()  -- Apply settings (show/hide based on enabled state)
        
        self:ApplyAllVisibility()
        ApplyAllSystemBarVisibility()  -- Apply system bar visibility (even if layout tweaks disabled)
        self:ApplyAllTextSettings()
        self:ApplyAllCooldownSettings()
        self:ApplyAllRangeIndicators()
        self:ApplyAllIconEdgeStyles()
        self:ApplyGryphonVisibility()
        HookActionButtonUpdates()  -- Hook button updates for empty slot hiding
    end)
    
    TweaksUI:PrintDebug("Action Bars enabled (using TUIFrame wrappers)")
end

function ActionBars:OnDisable()
    DebugPrint("OnDisable")
    
    if not settings then return end
    
    -- Exit keybind mode if active
    if isKeybindModeActive then
        self:ExitKeybindMode()
    end
    
    -- Hide all keybind overlays
    for _, overlay in pairs(keybindOverlays) do
        overlay:Hide()
    end
    
    settings.enabled = false
    TeardownEvents()
    
    -- Restore all buttons to Blizzard's bars
    for _, barId in ipairs(BAR_ORDER) do
        RestoreButtonsToBlizzard(barId)
        TeardownVisibilityUpdater(barId)
    end
    
    -- Restore system bars to Blizzard
    for _, barId in ipairs(SYSTEM_BAR_ORDER) do
        RestoreSystemBarToBlizzard(barId)
    end
    
    self:RestoreAllLayouts()
    
    TweaksUI:Print("Action Bars |cffff0000disabled|r")
end

function ActionBars:OnProfileChanged(profileName)
    DebugPrint("OnProfileChanged:", profileName)
    
    -- Get settings from the new profile
    local db = TweaksUI.Database:GetModuleSettings(self.id)
    
    -- Initialize with defaults if empty
    if not db or not next(db) then
        db = DeepCopy(DEFAULT_SETTINGS)
        TweaksUI.Database:SetModuleSettings(self.id, db)
    end
    
    -- Ensure bars table exists
    if not db.bars then
        db.bars = {}
    end
    
    -- Ensure all bars have settings (handles partial profiles)
    local needsSave = false
    for barId, _ in pairs(BAR_INFO) do
        if not db.bars[barId] then
            db.bars[barId] = GetDefaultBarSettings()
            needsSave = true
        else
            -- Ensure all default keys exist for this bar
            local defaults = GetDefaultBarSettings()
            for key, value in pairs(defaults) do
                if db.bars[barId][key] == nil then
                    db.bars[barId][key] = value
                    needsSave = true
                end
            end
        end
    end
    
    -- Ensure top-level defaults
    EnsureDefaults(db, DEFAULT_SETTINGS)
    
    -- Update local settings reference
    settings = db
    
    -- Save if we added any missing bars or settings
    if needsSave then
        TweaksUI.Database:SetModuleSettings(self.id, settings)
    end
    
    if self.enabled then
        self:Refresh()
    end
end

-- Debug command to find gryphon frames
SLASH_TUIGRYPHONS1 = "/tuigryphons"
SlashCmdList["TUIGRYPHONS"] = function()
    print("=== TweaksUI Gryphon Frame Debug ===")
    
    local artFrame = _G["MainMenuBarArtFrame"]
    if artFrame then
        print("|cff00ff00MainMenuBarArtFrame exists|r")
        
        -- Check Background child
        if artFrame.Background then
            print("  |cff00ff00artFrame.Background exists|r")
            if artFrame.Background.LeftEndCap then 
                print("    |cff00ff00Background.LeftEndCap exists|r - shown: " .. tostring(artFrame.Background.LeftEndCap:IsShown()))
            end
            if artFrame.Background.RightEndCap then 
                print("    |cff00ff00Background.RightEndCap exists|r - shown: " .. tostring(artFrame.Background.RightEndCap:IsShown()))
            end
            
            -- Check Background's regions
            if artFrame.Background.GetRegions then
                local bgRegions = {artFrame.Background:GetRegions()}
                print("    Background regions: " .. #bgRegions)
                for i, region in ipairs(bgRegions) do
                    if region.GetTexture then
                        local tex = region:GetTexture() or "nil"
                        local texStr = tostring(tex)
                        if texStr:lower():find("endcap") or texStr:lower():find("gryphon") then
                            print("      |cffff8800Region " .. i .. ": " .. texStr .. "|r")
                        end
                    end
                end
            end
        end
        
        -- Check direct properties
        if artFrame.LeftEndCap then 
            print("  |cff00ff00artFrame.LeftEndCap exists|r - shown: " .. tostring(artFrame.LeftEndCap:IsShown()))
        end
        if artFrame.RightEndCap then 
            print("  |cff00ff00artFrame.RightEndCap exists|r - shown: " .. tostring(artFrame.RightEndCap:IsShown()))
        end
        
        -- List children
        local children = {artFrame:GetChildren()}
        print("  Children: " .. #children)
        for i, child in ipairs(children) do
            local name = child:GetName() or "unnamed"
            local ctype = child:GetObjectType()
            local nameLower = name:lower()
            if nameLower:find("endcap") or nameLower:find("gryphon") or nameLower:find("background") then
                print("    |cffff8800" .. i .. ": " .. name .. " (" .. ctype .. ")|r - shown: " .. tostring(child:IsShown()))
            end
            
            -- Check grandchildren with EndCap in name
            if child.GetChildren then
                local grandchildren = {child:GetChildren()}
                for j, gc in ipairs(grandchildren) do
                    local gcName = gc:GetName() or "unnamed"
                    local gcType = gc:GetObjectType()
                    local gcNameLower = gcName:lower()
                    if gcNameLower:find("endcap") or gcNameLower:find("gryphon") then
                        print("      |cffff8800Found: " .. gcName .. " (" .. gcType .. ")|r - shown: " .. tostring(gc:IsShown()))
                    end
                end
            end
        end
        
        -- Check regions (textures)
        local regions = {artFrame:GetRegions()}
        print("  Regions (textures): " .. #regions)
        for i, region in ipairs(regions) do
            if region.GetTexture then
                local tex = region:GetTexture() or "nil"
                local texStr = tostring(tex)
                if texStr:lower():find("endcap") or texStr:lower():find("gryphon") or texStr:lower():find("ui%-mainmenubar") then
                    print("    |cffff8800Region " .. i .. ": " .. texStr .. "|r - shown: " .. tostring(region:IsShown()))
                end
            end
        end
    else
        print("|cffff0000MainMenuBarArtFrame NOT found|r")
    end
    
    -- Check global names
    local testNames = {
        "MainMenuBarLeftEndCap",
        "MainMenuBarRightEndCap", 
        "MainMenuBarArtFrameLeftEndCap",
        "MainMenuBarArtFrameRightEndCap",
        "MicroButtonAndBagsBarMovable",
    }
    print("Global frame test:")
    for _, name in ipairs(testNames) do
        if _G[name] then
            print("  |cff00ff00" .. name .. " EXISTS|r - shown: " .. tostring(_G[name]:IsShown()))
        end
    end
    
    -- Show current setting
    if settings and settings.bars and settings.bars.ActionBar1 then
        print("hideGryphons setting: " .. tostring(settings.bars.ActionBar1.hideGryphons))
    end
end

-- Debug command to inspect action button textures
SLASH_TUIBUTTONS1 = "/tuibuttons"
SlashCmdList["TUIBUTTONS"] = function()
    print("=== TweaksUI Action Button Debug ===")
    
    -- Look at first action button as example
    local button = _G["ActionButton1"]
    if not button then
        print("|cffff0000ActionButton1 NOT found|r")
        return
    end
    
    print("|cff00ff00ActionButton1 found|r")
    
    -- Check common named textures
    local namedTextures = {
        "icon", "Icon",
        "NormalTexture", "normalTexture",
        "SlotBackground", "slotBackground",
        "SlotArt", "slotArt", 
        "EmptySlot", "emptySlot",
        "FloatingBG", "floatingBG",
        "Border", "border",
        "Background", "background",
        "Mask", "mask",
        "IconMask", "iconMask",
    }
    
    print("Named textures/children:")
    for _, name in ipairs(namedTextures) do
        if button[name] then
            local obj = button[name]
            local objType = type(obj) == "table" and obj.GetObjectType and obj:GetObjectType() or type(obj)
            local shown = type(obj) == "table" and obj.IsShown and tostring(obj:IsShown()) or "N/A"
            local alpha = type(obj) == "table" and obj.GetAlpha and tostring(obj:GetAlpha()) or "N/A"
            print("  |cff00ff00" .. name .. "|r: " .. objType .. " - shown: " .. shown .. ", alpha: " .. alpha)
        end
    end
    
    -- Check all children
    print("Children frames:")
    local children = {button:GetChildren()}
    for i, child in ipairs(children) do
        local name = child:GetName() or "unnamed"
        local ctype = child:GetObjectType()
        print("  " .. i .. ": " .. name .. " (" .. ctype .. ")")
    end
    
    -- Check all regions (textures, fontstrings, etc)
    print("Regions (textures/fontstrings):")
    local regions = {button:GetRegions()}
    for i, region in ipairs(regions) do
        local rtype = region:GetObjectType()
        local name = region:GetName() or "unnamed"
        local drawLayer = region.GetDrawLayer and region:GetDrawLayer() or "N/A"
        local shown = region:IsShown()
        local alpha = region:GetAlpha()
        
        local texInfo = ""
        if region.GetTexture then
            local tex = region:GetTexture()
            if tex then
                texInfo = " tex=" .. tostring(tex)
            end
        end
        
        print("  " .. i .. ": " .. name .. " (" .. rtype .. ") layer=" .. drawLayer .. 
              " shown=" .. tostring(shown) .. " alpha=" .. string.format("%.2f", alpha) .. texInfo)
    end
    
    -- Check if there's an action
    local hasAction = HasAction(button.action or 1)
    print("Has action: " .. tostring(hasAction))
    
    -- Check the button's normal texture specifically
    local normalTex = button:GetNormalTexture()
    if normalTex then
        print("GetNormalTexture(): exists - " .. tostring(normalTex:GetTexture()))
    end
    
    -- Check pushed texture
    local pushedTex = button:GetPushedTexture()
    if pushedTex then
        print("GetPushedTexture(): exists - " .. tostring(pushedTex:GetTexture()))
    end
end

-- ============================================================================
-- LAYOUT MODE CALLBACKS FOR SYSTEM BARS
-- ============================================================================

local function InitLayoutCallbacks()
    local Layout = TweaksUI.Layout
    if not Layout then return end
    
    Layout:RegisterCallback("OnLayoutModeEnter", function()
        TweaksUI:PrintDebug("ActionBars: Layout Mode entered - checking system bars")
        
        if InCombatLockdown() then return end
        
        -- Ensure stance bar is registered if it exists
        if stanceBarContainer and not stanceBarRegistered then
            RegisterStanceBarWithLayout()
        end
        
        local registered = false
        
        -- Ensure all system bars are available in Layout mode (even if not enabled)
        for _, barId in ipairs(SYSTEM_BAR_ORDER) do
            local barSettings = settings and settings.systemBars and settings.systemBars[barId]
            local blizzFrame = GetSystemBarFrame(barId)
            
            -- Skip if Blizzard frame doesn't exist
            if not blizzFrame then
                TweaksUI:PrintDebug("ActionBars: No Blizzard frame for " .. barId)
            else
                local wrapper = systemBarWrappers[barId]
                
                -- If bar is enabled, ensure wrapper exists and is properly set up
                if barSettings and barSettings.enabled then
                    -- If we have a Blizzard frame but no wrapper, create one
                    if not wrapper then
                        TweaksUI:PrintDebug("ActionBars: Creating wrapper for " .. barId .. " on Layout enter")
                        ApplySystemBarLayout(barId)
                        registered = true
                        wrapper = systemBarWrappers[barId]
                    end
                    
                    if wrapper then
                        -- Ensure Blizzard frame is still properly parented
                        if blizzFrame:GetParent() ~= wrapper.frame then
                            TweaksUI:PrintDebug("ActionBars: Re-parenting " .. barId .. " to wrapper")
                            blizzFrame:SetParent(wrapper.frame)
                            blizzFrame:ClearAllPoints()
                            blizzFrame:SetPoint("CENTER", wrapper.frame, "CENTER", 0, 0)
                        end
                        
                        -- Make sure wrapper is shown
                        wrapper.frame:Show()
                        
                        -- Force blizzard frame visible during layout mode
                        blizzFrame:Show()
                        blizzFrame:SetAlpha(1)
                        
                        -- Force load saved position from Layout settings using wrapper method
                        local elementId = "systembar_" .. barId:lower()
                        local layoutSettings = Layout:GetSettings()
                        local savedPos = layoutSettings and layoutSettings.elements and layoutSettings.elements[elementId]
                        if savedPos and savedPos.x ~= nil and savedPos.y ~= nil then
                            wrapper:LoadSaveData(savedPos)
                            TweaksUI:PrintDebug("ActionBars: Applied saved position to " .. barId .. ": " .. savedPos.x .. ", " .. savedPos.y)
                        end
                    end
                else
                    -- Bar not enabled - still show Blizzard frame at its normal position during Layout
                    -- so user can see where it is
                    blizzFrame:Show()
                    blizzFrame:SetAlpha(0.5)  -- Dimmed to indicate it's not being managed
                end
            end
        end
        
        -- If we registered new elements, force Layout to recreate overlays
        if registered then
            C_Timer.After(0.1, function()
                if TweaksUI.LayoutUI and TweaksUI.LayoutUI.ShowOverlays then
                    TweaksUI.LayoutUI:ShowOverlays()
                end
            end)
        end
    end)
    
    Layout:RegisterCallback("OnLayoutModeExit", function()
        TweaksUI:PrintDebug("ActionBars: Layout Mode exited")
        
        -- Ensure Blizzard frames are still properly parented to wrappers after Layout mode
        -- and apply saved positions
        if not InCombatLockdown() then
            -- Reset visibility state for all bars first
            -- During Layout Mode, bars were shown at full alpha without updating tweaksTargetAlpha
            -- This reset forces a fresh evaluation of visibility conditions
            for barId, _ in pairs(BAR_INFO) do
                local bar = GetVisibilityFrame(barId)
                if bar then
                    bar.tweaksTargetAlpha = nil  -- Force fresh visibility calculation
                end
            end
            
            -- Update regular action bars visibility FIRST
            for barId, _ in pairs(BAR_INFO) do
                UpdateBarVisibility(barId)
            end
            
            -- Update stance bar if it exists
            if stanceBarContainer then
                ActionBars:RefreshStanceBar()
            end
            
            -- Then update system bars
            for _, barId in ipairs(SYSTEM_BAR_ORDER) do
                local barSettings = settings and settings.systemBars and settings.systemBars[barId]
                local wrapper = systemBarWrappers[barId]
                local blizzFrame = GetSystemBarFrame(barId)
                
                if wrapper and blizzFrame then
                    -- Re-parent if needed
                    if blizzFrame:GetParent() ~= wrapper.frame then
                        TweaksUI:PrintDebug("ActionBars: Re-parenting " .. barId .. " after Layout mode")
                        blizzFrame:SetParent(wrapper.frame)
                        blizzFrame:ClearAllPoints()
                        blizzFrame:SetPoint("CENTER", wrapper.frame, "CENTER", 0, 0)
                    end
                    
                    -- Apply saved position to wrapper using wrapper method
                    local elementId = "systembar_" .. barId:lower()
                    local layoutSettings = Layout:GetSettings()
                    local savedPos = layoutSettings and layoutSettings.elements and layoutSettings.elements[elementId]
                    if savedPos and savedPos.x ~= nil and savedPos.y ~= nil then
                        wrapper:LoadSaveData(savedPos)
                    end
                    
                    -- Reset visibility state for system bars too
                    if wrapper.frame then
                        wrapper.frame.tweaksTargetAlpha = nil
                    end
                    
                    -- Cleanup existing mouseover detection to force fresh state
                    -- The OnUpdate handler only handles transitions, not state enforcement
                    local frame = wrapper.frame
                    if frame and frame._tuiMouseoverFrame then
                        frame._tuiMouseoverFrame:SetScript("OnUpdate", nil)
                        frame._tuiMouseoverFrame:Hide()
                        frame._tuiMouseoverFrame:SetParent(nil)
                        frame._tuiMouseoverFrame = nil
                        frame._tuiMouseoverEnabled = nil
                    end
                    
                    -- Restore proper visibility (will recreate mouseover detection if needed)
                    UpdateSystemBarVisibility(barId)
                elseif blizzFrame and (not barSettings or not barSettings.enabled) then
                    -- Bar was shown dimmed during Layout mode but isn't managed by us
                    -- Let Blizzard control it again (it will hide if no stances/forms)
                    -- Don't force hide - just let the game's normal visibility logic take over
                    blizzFrame:SetAlpha(1)
                end
            end
        end
    end)
end

-- Initialize Layout callbacks when Layout module is available
C_Timer.After(1.0, InitLayoutCallbacks)

-- Public method to refresh all bar visibility (used by /tui showall)
function ActionBars:RefreshAllVisibility()
    -- Update regular bars
    for barId, _ in pairs(BAR_INFO) do
        UpdateBarVisibility(barId)
    end
    -- Update system bars
    for _, barId in ipairs(SYSTEM_BAR_ORDER) do
        UpdateSystemBarVisibility(barId)
    end
    -- Update stance bar if it exists
    if stanceBarContainer then
        self:RefreshStanceBar()
    end
end

TweaksUI.ActionBars = ActionBars
