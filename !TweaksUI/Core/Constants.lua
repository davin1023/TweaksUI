-- TweaksUI Constants
-- Core constants and configuration values
-- Version 2.0.0 - Midnight-Only Release

local ADDON_NAME, TweaksUI = ...

-- Version info
TweaksUI.VERSION = "2.0.8"
TweaksUI.ADDON_NAME = ADDON_NAME

-- Build info - Midnight-only (12.0.0+)
TweaksUI.BUILD_VERSION = select(4, GetBuildInfo())
TweaksUI.MIN_WOW_VERSION = 120000
TweaksUI.EXPANSION = "Midnight"

-- Midnight is always true in 2.0+ (we require it)
-- Kept for backwards compatibility with any code that checks this
TweaksUI.IS_MIDNIGHT = true

-- Module identifiers
TweaksUI.MODULE_IDS = {
    COOLDOWNS = "cooldowns",
    CHAT = "chat",
    ACTION_BARS = "actionBars",
    UNIT_FRAMES = "unitFrames",
    PERSONAL_RESOURCES = "personalResources",
    CAST_BARS = "castBars",
    NAMEPLATES = "nameplates",
    GENERAL = "general",  -- Not a standard module, always active
    -- Legacy alias for migration
    RESOURCE_BARS = "personalResources",
}

-- Module display names (for UI)
TweaksUI.MODULE_NAMES = {
    [TweaksUI.MODULE_IDS.COOLDOWNS] = "Cooldown Trackers",
    [TweaksUI.MODULE_IDS.CHAT] = "Chat",
    [TweaksUI.MODULE_IDS.ACTION_BARS] = "Action Bars",
    [TweaksUI.MODULE_IDS.UNIT_FRAMES] = "Unit Frames",
    [TweaksUI.MODULE_IDS.PERSONAL_RESOURCES] = "Personal Resources",
    [TweaksUI.MODULE_IDS.CAST_BARS] = "Cast Bars",
    [TweaksUI.MODULE_IDS.NAMEPLATES] = "Nameplates",
    [TweaksUI.MODULE_IDS.GENERAL] = "General",
}

-- Module load order (alphabetical by display name)
TweaksUI.MODULE_LOAD_ORDER = {
    TweaksUI.MODULE_IDS.ACTION_BARS,
    TweaksUI.MODULE_IDS.CAST_BARS,
    TweaksUI.MODULE_IDS.CHAT,
    TweaksUI.MODULE_IDS.COOLDOWNS,
    TweaksUI.MODULE_IDS.NAMEPLATES,
    TweaksUI.MODULE_IDS.PERSONAL_RESOURCES,
    TweaksUI.MODULE_IDS.UNIT_FRAMES,
}

-- Events
TweaksUI.EVENTS = {
    MODULE_ENABLED = "TweaksUI_ModuleEnabled",
    MODULE_DISABLED = "TweaksUI_ModuleDisabled",
    SETTINGS_CHANGED = "TweaksUI_SettingsChanged",
    PROFILE_CHANGED = "TweaksUI_ProfileChanged",
    -- Profile system events (1.5.0+)
    PROFILE_SAVED = "TweaksUI_ProfileSaved",
    PROFILE_LOADED = "TweaksUI_ProfileLoaded",
    PROFILE_DELETED = "TweaksUI_ProfileDeleted",
    PROFILE_DIRTY = "TweaksUI_ProfileDirty",
    PROFILE_NEEDS_RELOAD = "TweaksUI_ProfileNeedsReload",
    PROFILE_SPEC_SWITCH_BLOCKED = "TweaksUI_ProfileSpecSwitchBlocked",
    PRESET_APPLIED = "TweaksUI_PresetApplied",
    PRESET_SAVED = "TweaksUI_PresetSaved",
    -- Midnight restriction events (2.0.0+)
    RESTRICTION_CHANGED = "TweaksUI_RestrictionChanged",
    SECRETS_ACTIVE = "TweaksUI_SecretsActive",
    SECRETS_INACTIVE = "TweaksUI_SecretsInactive",
}

-- Default colors
TweaksUI.COLORS = {
    PRIMARY = { r = 0, g = 1, b = 0 },       -- Green (TweaksUI brand)
    SECONDARY = { r = 0.5, g = 0.5, b = 0.5 },
    WARNING = { r = 1, g = 0.8, b = 0 },
    ERROR = { r = 1, g = 0.2, b = 0.2 },
    SUCCESS = { r = 0, g = 1, b = 0 },
}

-- Chat prefix for messages
TweaksUI.CHAT_PREFIX = "|cff00ff00TweaksUI:|r "

-- Slash commands
TweaksUI.SLASH_COMMANDS = {
    "/tweaksui",
    "/tui",
}

-- Modules that require a reload to fully disable
-- (these hook into Blizzard frames in ways that can't be cleanly undone)
TweaksUI.MODULES_REQUIRE_RELOAD = {
    [TweaksUI.MODULE_IDS.COOLDOWNS] = true,
    [TweaksUI.MODULE_IDS.ACTION_BARS] = true,
    [TweaksUI.MODULE_IDS.UNIT_FRAMES] = true,
    [TweaksUI.MODULE_IDS.PERSONAL_RESOURCES] = true,
    [TweaksUI.MODULE_IDS.CAST_BARS] = true,
    [TweaksUI.MODULE_IDS.NAMEPLATES] = true,
    [TweaksUI.MODULE_IDS.CHAT] = true,
}

-- ============================================================================
-- UI STANDARDS (Settings Panel Consistency)
-- ============================================================================

-- Standard panel dimensions
TweaksUI.UI = {
    -- Hub Panel
    HUB_WIDTH = 220,
    HUB_HEIGHT = 400,
    
    -- Settings Panel (docked to hub)
    PANEL_WIDTH = 420,
    PANEL_HEIGHT = 600,
    
    -- Button dimensions
    BUTTON_HEIGHT = 28,
    BUTTON_SPACING = 6,
    
    -- Tab dimensions
    TAB_HEIGHT = 24,
    TAB_SPACING = 4,
    TAB_BAR_Y = -40,           -- Y offset from panel top
    TAB_CONTENT_Y = -72,       -- Y offset for content below tabs
    
    -- Control spacing
    CONTROL_SPACING = 26,      -- Vertical space between controls
    SLIDER_SPACING = 30,       -- Vertical space for sliders
    SECTION_SPACING = 16,      -- Space between sections
    CHECKBOX_SPACING = 26,     -- Vertical space for checkboxes
    DROPDOWN_SPACING = 50,     -- Vertical space for dropdowns
    
    -- Scroll content height (default)
    SCROLL_CHILD_HEIGHT = 800,
    
    -- Indentation
    INDENT = 20,               -- Indentation for sub-options
}

-- Standard colors
TweaksUI.UI.COLORS = {
    -- Tab colors
    TAB_ACTIVE = { r = 1, g = 0.82, b = 0 },       -- Gold
    TAB_INACTIVE = { r = 0.6, g = 0.6, b = 0.6 },  -- Grey
    TAB_HOVER = { r = 0.8, g = 0.8, b = 0.8 },     -- Light grey
    
    -- Tab backgrounds
    TAB_BG_ACTIVE = { r = 0.2, g = 0.2, b = 0.2, a = 0.8 },
    TAB_BG_INACTIVE = { r = 0.1, g = 0.1, b = 0.1, a = 0.5 },
    TAB_BG_HOVER = { r = 0.15, g = 0.15, b = 0.15, a = 0.7 },
    
    -- Headers
    HEADER = { r = 1, g = 0.82, b = 0 },           -- Gold (|cffffcc00)
    SECTION_LABEL = { r = 0.67, g = 0.67, b = 0.67 },  -- Grey (|cffaaaaaa)
    MUTED = { r = 0.53, g = 0.53, b = 0.53 },      -- Dark grey (|cff888888)
    
    -- Status
    ENABLED = { r = 0, g = 1, b = 0 },             -- Green
    DISABLED = { r = 1, g = 0.2, b = 0.2 },        -- Red
    WARNING = { r = 1, g = 0.8, b = 0 },           -- Yellow
}

-- Standard backdrop (used by ALL settings panels)
TweaksUI.UI.DARK_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 },
}

-- Backdrop colors
TweaksUI.UI.BACKDROP_COLOR = { r = 0.08, g = 0.08, b = 0.08, a = 0.95 }
TweaksUI.UI.BACKDROP_BORDER_COLOR = { r = 0.4, g = 0.4, b = 0.4, a = 1 }

-- ============================================================================
-- STANDARD TAB NAMES (use these for consistency)
-- ============================================================================

TweaksUI.UI.TABS = {
    -- Common tabs (in display order)
    LAYOUT = "Layout",
    APPEARANCE = "Appearance", 
    TEXT = "Text",
    VISIBILITY = "Visibility",
    
    -- Module-specific tabs
    PER_ICON = "Per-Icon",
    ENTRIES = "Entries",
    COLORS = "Colors",
    ABSORBS = "Absorbs",
    GRID = "Grid",
    CUSTOM = "Custom",
    SORTING = "Sorting",
    FADE = "Fade",
    
    -- Resource bar tabs
    SIZE = "Size",
    BAR_COLOR = "Color",
    
    -- Chat tabs
    GENERAL = "General",
    CHANNELS = "Channels",
    ALERTS = "Alerts",
    BEHAVIOR = "Behavior",
}

-- ============================================================================
-- STANDARD SECTION HEADERS (use these for consistency)
-- ============================================================================

TweaksUI.UI.HEADERS = {
    -- Layout sections
    SIZE = "Size",
    GRID_LAYOUT = "Grid Layout",
    GROWTH_DIRECTION = "Growth Direction",
    POSITION = "Position",
    
    -- Appearance sections
    COLORS = "Colors",
    BORDER = "Border",
    BACKGROUND = "Background",
    TEXTURES = "Textures",
    
    -- Text sections
    TEXT_SETTINGS = "Text Settings",
    FONT = "Font",
    COOLDOWN_TEXT = "Cooldown Text",
    COUNT_TEXT = "Count Text",
    
    -- Visibility sections
    VISIBILITY_CONDITIONS = "Visibility Conditions",
    FADE_SETTINGS = "Fade Settings",
    
    -- Other common sections
    BEHAVIOR = "Behavior",
    INTERACTION = "Interaction",
}
