-- TweaksUI Preset Data
-- Built-in preset definitions for all modules (1.5.0+)
-- These match the actual module settings structures

local ADDON_NAME, TweaksUI = ...

-- Built-in presets storage
TweaksUI.BuiltInPresets = TweaksUI.BuiltInPresets or {}

-- ============================================================================
-- MODULE SCALABLE KEYS
-- Define which settings should scale with screen resolution
-- ============================================================================

TweaksUI.ModuleScalableKeys = {
    -- Cooldowns
    cooldowns = {
        "iconSize", "iconWidth", "iconHeight",
        "spacingH", "spacingV",
    },
    
    -- CastBars
    castBars = {
        "width", "height",
        "iconSize",
        "timerFontSize", "spellNameFontSize",
    },
    
    -- Chat
    chat = {
        "frameWidth", "frameHeight",
        "buttonSize", "buttonSpacing",
        "fontSize", "editBoxFontSize",
        "headerHeight",
        "whisperFrameWidth", "whisperFrameHeight",
    },
    
    -- Nameplates
    nameplates = {
        "width", "height",
        "fontSize", "classificationSize", "raidMarkerSize",
        "questSize", "levelFontSize", "pvpMarkerSize",
    },
    
    -- UnitFrames
    unitFrames = {
        "width", "height",
        "fontSize", "iconSize",
    },
    
    -- ActionBars
    actionBars = {
        "buttonSize", "buttonSpacing",
    },
    
    -- PersonalResources
    personalResources = {
        "width", "height",
        "fontSize",
    },
}

-- ============================================================================
-- COOLDOWNS PRESETS
-- ============================================================================

TweaksUI.BuiltInPresets.cooldowns = {
    -- ========================================
    -- BASIC PRESET - Clean starting point
    -- ========================================
    
    ["Basic"] = {
        -- Author's recommended starting setup
        essential = {
            enabled = true,
            iconSize = 36,
            aspectRatio = "1:1",
            columns = 7,
            rows = 0,
            spacingH = 0,
            spacingV = 0,
            growDirection = "RIGHT",
            growSecondary = "DOWN",
            alignment = "CENTER",
            zoom = 0.08,
            borderAlpha = 0.5,
            iconOpacity = 1,
            cooldownTextScale = 1.3,
            countTextScale = 1.2,
            iconEdgeStyle = "sharp",
            visibilityEnabled = false,
            useMasque = false,
            rangeIndicatorEnabled = false,
        },
        utility = {
            enabled = true,
            iconSize = 36,
            aspectRatio = "16:9",
            columns = 7,
            rows = 4,
            spacingH = 0,
            spacingV = 0,
            growDirection = "RIGHT",
            growSecondary = "RIGHT",
            alignment = "CENTER",
            zoom = 0.08,
            borderAlpha = 1,
            iconOpacity = 1,
            cooldownTextScale = 1,
            countTextScale = 1.5,
            iconEdgeStyle = "sharp",
            visibilityEnabled = false,
            useMasque = false,
            rangeIndicatorEnabled = false,
        },
        buffs = {
            enabled = true,
            iconSize = 36,
            aspectRatio = "3:4",
            columns = 5,
            rows = 0,
            spacingH = 0,
            spacingV = 0,
            growDirection = "RIGHT",
            growSecondary = "DOWN",
            alignment = "CENTER",
            zoom = 0.08,
            borderAlpha = 1,
            iconOpacity = 1,
            cooldownTextScale = 1,
            countTextScale = 1,
            iconEdgeStyle = "sharp",
            greyscaleInactive = true,
            inactiveAlpha = 0.45,
            visibilityEnabled = false,
            useMasque = false,
        },
        customTrackers = {
            enabled = true,
            iconSize = 36,
            aspectRatio = "4:3",
            columns = 2,
            rows = 0,
            spacingH = 2,
            spacingV = 2,
            growDirection = "RIGHT",
            growSecondary = "DOWN",
            alignment = "CENTER",
            zoom = 0.07,
            borderAlpha = 1,
            iconOpacity = 1,
            cooldownTextScale = 1,
            countTextScale = 1.4,
            iconEdgeStyle = "sharp",
            customLayout = "2,1",
            visibilityEnabled = false,
            useMasque = false,
            trackEquipped = true,
        },
        global = {
            debugMode = false,
        },
    },
    
    -- ========================================
    -- GENERAL PRESETS
    -- ========================================
    
    ["Modern"] = {
        -- Clean, balanced design - everything visible but not overwhelming
        -- 6 columns keeps it readable, square icons look polished
        essential = {
            enabled = true,
            iconSize = 38,
            aspectRatio = "1:1",
            columns = 6,
            rows = 0,
            spacingH = 3,
            spacingV = 3,
            growDirection = "RIGHT",
            growSecondary = "DOWN",
            alignment = "LEFT",
            zoom = 0.08,
            borderAlpha = 1.0,
            iconOpacity = 1.0,
            cooldownTextScale = 1.0,
            countTextScale = 1.0,
            visibilityEnabled = false,
        },
        utility = {
            enabled = true,
            iconSize = 34,
            aspectRatio = "1:1",
            columns = 6,
            spacingH = 3,
            spacingV = 3,
            growDirection = "RIGHT",
            growSecondary = "DOWN",
            zoom = 0.08,
            visibilityEnabled = false,
        },
        defensive = {
            enabled = true,
            iconSize = 36,
            aspectRatio = "1:1",
            columns = 4,
            spacingH = 3,
            spacingV = 3,
            growDirection = "RIGHT",
            growSecondary = "DOWN",
            zoom = 0.08,
            visibilityEnabled = false,
        },
        buffs = {
            enabled = true,
            iconSize = 32,
            aspectRatio = "1:1",
            columns = 8,
            spacingH = 2,
            spacingV = 2,
            growDirection = "RIGHT",
            growSecondary = "DOWN",
            greyscaleInactive = true,
            inactiveAlpha = 0.5,
        },
        customTrackers = {
            enabled = false,
        },
    },
    
    ["Minimal"] = {
        -- Smaller footprint with fewer trackers
        -- Grows UP to tuck under action bars, combat-only visibility
        essential = {
            enabled = true,
            iconSize = 28,
            aspectRatio = "1:1",
            columns = 5,
            spacingH = 2,
            spacingV = 2,
            growDirection = "RIGHT",
            growSecondary = "UP",
            alignment = "CENTER",
            zoom = 0.08,
            borderAlpha = 1.0,
            iconOpacity = 1.0,
            cooldownTextScale = 1.0,
            visibilityEnabled = false,
        },
        utility = {
            enabled = true,
            iconSize = 24,
            aspectRatio = "1:1",
            columns = 5,
            spacingH = 2,
            spacingV = 2,
            growDirection = "RIGHT",
            growSecondary = "UP",
            zoom = 0.08,
            visibilityEnabled = false,
        },
        defensive = {
            enabled = false,
        },
        buffs = {
            enabled = true,
            iconSize = 24,
            aspectRatio = "1:1",
            columns = 6,
            spacingH = 2,
            spacingV = 2,
            growDirection = "RIGHT",
            growSecondary = "UP",
            greyscaleInactive = true,
            inactiveAlpha = 0.5,
        },
        customTrackers = {
            enabled = false,
        },
    },
    
    ["Large Icons"] = {
        -- Maximum visibility, accessibility focused
        -- Few columns, big icons, generous spacing
        essential = {
            enabled = true,
            iconSize = 52,
            aspectRatio = "1:1",
            columns = 4,
            spacingH = 5,
            spacingV = 5,
            growDirection = "RIGHT",
            growSecondary = "DOWN",
            alignment = "LEFT",
            zoom = 0.05,
            cooldownTextScale = 1.3,
            countTextScale = 1.2,
            visibilityEnabled = false,
        },
        utility = {
            enabled = true,
            iconSize = 46,
            aspectRatio = "1:1",
            columns = 4,
            spacingH = 5,
            spacingV = 5,
            growDirection = "RIGHT",
            growSecondary = "DOWN",
            zoom = 0.05,
            visibilityEnabled = false,
        },
        defensive = {
            enabled = true,
            iconSize = 48,
            aspectRatio = "1:1",
            columns = 3,
            spacingH = 5,
            spacingV = 5,
            growDirection = "RIGHT",
            growSecondary = "DOWN",
            zoom = 0.05,
            visibilityEnabled = false,
        },
        buffs = {
            enabled = true,
            iconSize = 44,
            aspectRatio = "1:1",
            columns = 6,
            spacingH = 4,
            spacingV = 4,
            growDirection = "RIGHT",
            growSecondary = "DOWN",
            greyscaleInactive = true,
            inactiveAlpha = 0.5,
        },
        customTrackers = {
            enabled = false,
        },
    },
    
    ["Disabled"] = {
        essential = { enabled = false },
        utility = { enabled = false },
        defensive = { enabled = false },
        buffs = { enabled = false },
        customTrackers = { enabled = false },
    },
    
    -- ========================================
    -- ROLE-BASED PRESETS
    -- ========================================
    
    ["Tank"] = {
        -- Defensive CDs front and center
        -- Large essential tracker for defensive cooldowns
        -- Buffs for tracking active defensives
        essential = {
            enabled = true,
            iconSize = 44,
            aspectRatio = "1:1",
            columns = 5,
            spacingH = 4,
            spacingV = 4,
            growDirection = "RIGHT",
            growSecondary = "DOWN",
            alignment = "LEFT",
            zoom = 0.06,
            cooldownTextScale = 1.2,
            countTextScale = 1.1,
            visibilityEnabled = false,
        },
        utility = {
            enabled = true,
            iconSize = 36,
            aspectRatio = "1:1",
            columns = 6,
            spacingH = 3,
            spacingV = 3,
            growDirection = "RIGHT",
            growSecondary = "DOWN",
            visibilityEnabled = false,
        },
        defensive = {
            enabled = true,
            iconSize = 42,
            aspectRatio = "1:1",
            columns = 4,
            spacingH = 4,
            spacingV = 4,
            growDirection = "RIGHT",
            growSecondary = "DOWN",
            zoom = 0.06,
            visibilityEnabled = false,
        },
        buffs = {
            enabled = true,
            iconSize = 38,
            aspectRatio = "1:1",
            columns = 6,
            spacingH = 3,
            spacingV = 3,
            greyscaleInactive = true,
            inactiveAlpha = 0.5,
        },
        customTrackers = {
            enabled = false,
        },
    },
    
    ["Healer"] = {
        -- Healing cooldowns prominent
        -- Large essential for major healing CDs
        -- Buffs prominent for tracking HoTs on self
        essential = {
            enabled = true,
            iconSize = 46,
            aspectRatio = "1:1",
            columns = 5,
            spacingH = 4,
            spacingV = 4,
            growDirection = "RIGHT",
            growSecondary = "DOWN",
            alignment = "LEFT",
            zoom = 0.06,
            cooldownTextScale = 1.2,
            visibilityEnabled = false,
        },
        utility = {
            enabled = true,
            iconSize = 38,
            aspectRatio = "1:1",
            columns = 5,
            spacingH = 3,
            spacingV = 3,
            growDirection = "RIGHT",
            growSecondary = "DOWN",
            visibilityEnabled = false,
        },
        defensive = {
            enabled = true,
            iconSize = 40,
            aspectRatio = "1:1",
            columns = 4,
            spacingH = 4,
            spacingV = 4,
            growDirection = "RIGHT",
            growSecondary = "DOWN",
            visibilityEnabled = false,
        },
        buffs = {
            enabled = true,
            iconSize = 40,
            aspectRatio = "1:1",
            columns = 6,
            spacingH = 3,
            spacingV = 3,
            greyscaleInactive = true,
            inactiveAlpha = 0.6,
        },
        customTrackers = {
            enabled = false,
        },
    },
    
    ["Melee DPS"] = {
        -- Many rotational abilities to track
        -- Compact layout, more columns for ability density
        -- Wider aspect ratio packs more in horizontally
        essential = {
            enabled = true,
            iconSize = 32,
            aspectRatio = "4:3",
            columns = 6,
            spacingH = 2,
            spacingV = 2,
            growDirection = "RIGHT",
            growSecondary = "UP",
            alignment = "CENTER",
            zoom = 0.08,
            cooldownTextScale = 0.95,
            visibilityEnabled = false,
        },
        utility = {
            enabled = true,
            iconSize = 28,
            aspectRatio = "4:3",
            columns = 6,
            spacingH = 2,
            spacingV = 2,
            growDirection = "RIGHT",
            growSecondary = "UP",
            visibilityEnabled = false,
        },
        defensive = {
            enabled = true,
            iconSize = 30,
            aspectRatio = "1:1",
            columns = 4,
            spacingH = 3,
            spacingV = 3,
            growDirection = "RIGHT",
            growSecondary = "UP",
            visibilityEnabled = false,
        },
        buffs = {
            enabled = true,
            iconSize = 26,
            aspectRatio = "4:3",
            columns = 8,
            spacingH = 2,
            spacingV = 2,
            greyscaleInactive = true,
            inactiveAlpha = 0.4,
        },
        customTrackers = {
            enabled = false,
        },
    },
    
    ["Ranged DPS"] = {
        -- More screen real estate available
        -- Balanced layout, standard columns
        -- Square icons for clean look
        essential = {
            enabled = true,
            iconSize = 36,
            aspectRatio = "1:1",
            columns = 6,
            spacingH = 3,
            spacingV = 3,
            growDirection = "RIGHT",
            growSecondary = "DOWN",
            alignment = "LEFT",
            zoom = 0.08,
            cooldownTextScale = 1.0,
            visibilityEnabled = false,
        },
        utility = {
            enabled = true,
            iconSize = 32,
            aspectRatio = "1:1",
            columns = 6,
            spacingH = 3,
            spacingV = 3,
            growDirection = "RIGHT",
            growSecondary = "DOWN",
            visibilityEnabled = false,
        },
        defensive = {
            enabled = true,
            iconSize = 34,
            aspectRatio = "1:1",
            columns = 4,
            spacingH = 3,
            spacingV = 3,
            growDirection = "RIGHT",
            growSecondary = "DOWN",
            visibilityEnabled = false,
        },
        buffs = {
            enabled = true,
            iconSize = 30,
            aspectRatio = "1:1",
            columns = 8,
            spacingH = 2,
            spacingV = 2,
            greyscaleInactive = true,
            inactiveAlpha = 0.5,
        },
        customTrackers = {
            enabled = false,
        },
    },
}

-- ============================================================================
-- CAST BARS PRESETS
-- ============================================================================

TweaksUI.BuiltInPresets.castBars = {
    -- ========================================
    -- BASIC PRESET - Clean starting point
    -- ========================================
    
    ["Basic"] = {
        player = {
            enabled = true,
            width = 250,
            height = 24,
            showIcon = true,
            iconSize = 24,
            iconPosition = "LEFT",
            showTimer = true,
            timerFormat = "remaining",
            timerFontSize = 12,
            timerPosition = "RIGHT",
            showSpellName = true,
            spellNameFontSize = 12,
            spellNamePosition = "LEFT",
            showSpark = true,
            showBorder = true,
            borderSize = 1,
            borderColor = {0, 0, 0, 1},
            backgroundColor = {0.1, 0.1, 0.1, 0.8},
            castingColor = {1.0, 0.7, 0.0, 1.0},
            channelingColor = {0.0, 1.0, 0.0, 1.0},
            nonInterruptibleColor = {0.7, 0.7, 0.7, 1.0},
            failedColor = {1.0, 0.0, 0.0, 1.0},
            hideBlizzard = true,
            maskShape = "none",
        },
        target = {
            enabled = true,
            width = 250,
            height = 24,
            showIcon = true,
            iconSize = 24,
            iconPosition = "LEFT",
            showTimer = true,
            timerFormat = "remaining",
            timerFontSize = 12,
            timerPosition = "RIGHT",
            showSpellName = true,
            spellNameFontSize = 12,
            spellNamePosition = "LEFT",
            showSpark = true,
            showBorder = true,
            borderSize = 1,
            borderColor = {0, 0, 0, 1},
            backgroundColor = {0.1, 0.1, 0.1, 0.8},
            castingColor = {1.0, 0.7, 0.0, 1.0},
            channelingColor = {0.0, 1.0, 0.0, 1.0},
            nonInterruptibleColor = {0.7, 0.7, 0.7, 1.0},
            failedColor = {1.0, 0.0, 0.0, 1.0},
            hideBlizzard = true,
            maskShape = "none",
        },
        focus = {
            enabled = true,
            width = 200,
            height = 20,
            showIcon = true,
            iconSize = 20,
            iconPosition = "LEFT",
            showTimer = true,
            timerFormat = "remaining",
            timerFontSize = 11,
            timerPosition = "RIGHT",
            showSpellName = true,
            spellNameFontSize = 11,
            spellNamePosition = "LEFT",
            showSpark = true,
            showBorder = true,
            borderSize = 1,
            borderColor = {0, 0, 0, 1},
            backgroundColor = {0.1, 0.1, 0.1, 0.8},
            castingColor = {1.0, 0.7, 0.0, 1.0},
            channelingColor = {0.0, 1.0, 0.0, 1.0},
            nonInterruptibleColor = {0.7, 0.7, 0.7, 1.0},
            failedColor = {1.0, 0.0, 0.0, 1.0},
            hideBlizzard = true,
            maskShape = "none",
        },
    },
    
    -- ========================================
    -- GENERAL PRESETS
    -- ========================================
    
    ["Modern"] = {
        -- Clean, balanced - all cast bars visible and functional
        player = {
            enabled = true,
            width = 260,
            height = 22,
            showIcon = true,
            iconSize = 22,
            iconPosition = "LEFT",
            showTimer = true,
            timerFormat = "remaining",
            timerFontSize = 11,
            timerPosition = "RIGHT",
            showSpellName = true,
            spellNameFontSize = 11,
            spellNamePosition = "LEFT",
            showSpark = true,
            showBorder = true,
            borderSize = 1,
            castingColor = {1.0, 0.7, 0.0, 1.0},
            channelingColor = {0.0, 0.8, 1.0, 1.0},
        },
        target = {
            enabled = true,
            width = 260,
            height = 22,
            showIcon = true,
            iconSize = 22,
            iconPosition = "LEFT",
            showTimer = true,
            timerFormat = "remaining",
            timerFontSize = 11,
            timerPosition = "RIGHT",
            showSpellName = true,
            spellNameFontSize = 11,
            spellNamePosition = "LEFT",
            showSpark = true,
            showBorder = true,
        },
        focus = {
            enabled = true,
            width = 200,
            height = 18,
            showIcon = true,
            iconSize = 18,
            showTimer = true,
            timerFontSize = 10,
            showSpellName = true,
            spellNameFontSize = 10,
            showSpark = true,
        },
    },
    
    ["Minimal"] = {
        -- Smaller bars, less decoration
        player = {
            enabled = true,
            width = 180,
            height = 14,
            showIcon = true,
            iconSize = 14,
            showTimer = true,
            timerFontSize = 10,
            showSpellName = false,
            showSpark = true,
            showBorder = false,
        },
        target = {
            enabled = true,
            width = 180,
            height = 14,
            showIcon = true,
            iconSize = 14,
            showTimer = true,
            timerFontSize = 10,
            showSpellName = false,
            showSpark = true,
            showBorder = false,
        },
        focus = {
            enabled = false,
        },
    },
    
    ["Large"] = {
        -- Maximum visibility, accessibility focused
        player = {
            enabled = true,
            width = 340,
            height = 32,
            showIcon = true,
            iconSize = 36,
            iconPosition = "LEFT",
            showTimer = true,
            timerFormat = "remaining",
            timerFontSize = 16,
            timerPosition = "RIGHT",
            showSpellName = true,
            spellNameFontSize = 16,
            spellNamePosition = "LEFT",
            showSpark = true,
            showBorder = true,
            borderSize = 2,
        },
        target = {
            enabled = true,
            width = 340,
            height = 32,
            showIcon = true,
            iconSize = 36,
            iconPosition = "LEFT",
            showTimer = true,
            timerFormat = "remaining",
            timerFontSize = 16,
            timerPosition = "RIGHT",
            showSpellName = true,
            spellNameFontSize = 16,
            showSpark = true,
            showBorder = true,
            borderSize = 2,
        },
        focus = {
            enabled = true,
            width = 280,
            height = 26,
            showIcon = true,
            iconSize = 30,
            showTimer = true,
            timerFontSize = 14,
            showSpellName = true,
            spellNameFontSize = 14,
            showSpark = true,
            showBorder = true,
        },
    },
    
    ["Disabled"] = {
        player = { enabled = false },
        target = { enabled = false },
        focus = { enabled = false },
    },
    
    -- ========================================
    -- ROLE-BASED PRESETS
    -- ========================================
    
    ["Tank"] = {
        -- TARGET cast bar is king - need to see enemy casts for interrupts/defensives
        -- Player cast bar smaller, focus enabled for add tracking
        player = {
            enabled = true,
            width = 180,
            height = 16,
            showIcon = true,
            iconSize = 16,
            showTimer = true,
            timerFontSize = 10,
            showSpellName = false,
            showSpark = true,
            showBorder = false,
        },
        target = {
            enabled = true,
            width = 300,
            height = 28,
            showIcon = true,
            iconSize = 32,
            iconPosition = "LEFT",
            showTimer = true,
            timerFormat = "remaining",
            timerFontSize = 14,
            timerPosition = "RIGHT",
            showSpellName = true,
            spellNameFontSize = 14,
            spellNamePosition = "LEFT",
            showSpark = true,
            showBorder = true,
            borderSize = 2,
            castingColor = {1.0, 0.5, 0.0, 1.0},
            nonInterruptibleColor = {0.5, 0.5, 0.5, 1.0},
        },
        focus = {
            enabled = true,
            width = 240,
            height = 22,
            showIcon = true,
            iconSize = 26,
            showTimer = true,
            timerFontSize = 12,
            showSpellName = true,
            spellNameFontSize = 11,
            showSpark = true,
            showBorder = true,
        },
    },
    
    ["Healer"] = {
        -- PLAYER cast bar is king - watching your own heals
        -- Target/focus smaller but still visible
        player = {
            enabled = true,
            width = 300,
            height = 28,
            showIcon = true,
            iconSize = 28,
            iconPosition = "LEFT",
            showTimer = true,
            timerFormat = "remaining",
            timerFontSize = 14,
            timerPosition = "RIGHT",
            showSpellName = true,
            spellNameFontSize = 14,
            spellNamePosition = "LEFT",
            showSpark = true,
            showBorder = true,
            borderSize = 1,
            castingColor = {0.2, 0.8, 0.2, 1.0},
            channelingColor = {0.0, 0.7, 1.0, 1.0},
        },
        target = {
            enabled = true,
            width = 200,
            height = 16,
            showIcon = true,
            iconSize = 16,
            showTimer = true,
            timerFontSize = 10,
            showSpellName = false,
            showSpark = true,
            showBorder = false,
        },
        focus = {
            enabled = true,
            width = 180,
            height = 14,
            showIcon = true,
            iconSize = 14,
            showTimer = true,
            timerFontSize = 9,
            showSpellName = false,
            showSpark = true,
        },
    },
    
    ["Melee DPS"] = {
        -- TARGET cast bar prominent for kicks
        -- Player compact, focus for CC/add tracking
        player = {
            enabled = true,
            width = 180,
            height = 16,
            showIcon = true,
            iconSize = 16,
            showTimer = true,
            timerFontSize = 10,
            showSpellName = true,
            spellNameFontSize = 9,
            showSpark = true,
            showBorder = false,
        },
        target = {
            enabled = true,
            width = 280,
            height = 26,
            showIcon = true,
            iconSize = 30,
            iconPosition = "LEFT",
            showTimer = true,
            timerFormat = "remaining",
            timerFontSize = 13,
            timerPosition = "RIGHT",
            showSpellName = true,
            spellNameFontSize = 12,
            spellNamePosition = "LEFT",
            showSpark = true,
            showBorder = true,
            borderSize = 2,
        },
        focus = {
            enabled = true,
            width = 220,
            height = 20,
            showIcon = true,
            iconSize = 22,
            showTimer = true,
            timerFontSize = 11,
            showSpellName = true,
            spellNameFontSize = 10,
            showSpark = true,
        },
    },
    
    ["Ranged DPS"] = {
        -- Balanced - both player and target matter
        -- Focus enabled for multi-dotting/CC
        player = {
            enabled = true,
            width = 240,
            height = 20,
            showIcon = true,
            iconSize = 20,
            showTimer = true,
            timerFontSize = 11,
            showSpellName = true,
            spellNameFontSize = 11,
            showSpark = true,
            showBorder = true,
        },
        target = {
            enabled = true,
            width = 260,
            height = 22,
            showIcon = true,
            iconSize = 24,
            iconPosition = "LEFT",
            showTimer = true,
            timerFormat = "remaining",
            timerFontSize = 12,
            timerPosition = "RIGHT",
            showSpellName = true,
            spellNameFontSize = 12,
            spellNamePosition = "LEFT",
            showSpark = true,
            showBorder = true,
        },
        focus = {
            enabled = true,
            width = 200,
            height = 18,
            showIcon = true,
            iconSize = 20,
            showTimer = true,
            timerFontSize = 10,
            showSpellName = true,
            spellNameFontSize = 10,
            showSpark = true,
        },
    },
}

-- ============================================================================
-- CHAT PRESETS
-- ============================================================================

TweaksUI.BuiltInPresets.chat = {
    -- ========================================
    -- BASIC PRESET - Clean starting point
    -- ========================================
    
    ["Basic"] = {
        frameWidth = 464,
        frameHeight = 232,
        fontSize = 14,
        showButtonBar = true,
        buttonBarVertical = true,
        buttonSize = 16,
        buttonSpacing = 2,
        fadeButtons = false,
        enableWindowFade = false,
        showBackground = true,
        showBorder = false,
        enableFading = false,
        enableShortChannels = true,
        enableClassColors = true,
        enableURLs = true,
        enableHistory = true,
        enableStickyChat = true,
        enableStickyTab = true,
        showTimestamps = true,
        autoHideEditBox = true,
        editBoxPosition = "TOP",
        editBoxBackground = true,
        headerHeight = 26,
        filterGoldSellers = true,
        enableMentionAlerts = true,
        enableWhisperTabs = true,
        whisperWindowMode = "separate",
        hideVoiceTab = true,
        persistHistory = false,
    },
    
    -- ========================================
    -- GENERAL PRESETS
    -- ========================================
    
    ["Modern"] = {
        -- Clean, balanced - everything functional
        frameWidth = 400,
        frameHeight = 180,
        fontSize = 13,
        showButtonBar = true,
        fadeButtons = false,
        enableWindowFade = false,
        showBackground = true,
        showBorder = true,
        enableFading = false,
        enableShortChannels = true,
        enableClassColors = true,
    },
    
    ["Minimal"] = {
        -- Smaller footprint but still visible
        frameWidth = 320,
        frameHeight = 140,
        fontSize = 11,
        showButtonBar = false,
        fadeButtons = false,
        enableWindowFade = false,
        showBackground = true,
        showBorder = false,
        enableFading = false,
        enableShortChannels = true,
    },
    
    ["Large"] = {
        -- Maximum visibility
        frameWidth = 500,
        frameHeight = 250,
        fontSize = 15,
        showButtonBar = true,
        fadeButtons = false,
        enableWindowFade = false,
        showBackground = true,
        showBorder = true,
        enableFading = false,
        enableShortChannels = true,
        enableClassColors = true,
        enableURLs = true,
    },
    
    -- ========================================
    -- ROLE-BASED PRESETS
    -- ========================================
    
    ["Raid Leader"] = {
        -- For tanks/healers leading groups
        -- Mentions and alerts enabled
        frameWidth = 420,
        frameHeight = 200,
        fontSize = 13,
        showButtonBar = true,
        fadeButtons = false,
        enableWindowFade = false,
        showBackground = true,
        showBorder = true,
        enableFading = false,
        enableShortChannels = true,
        enableMentionAlerts = true,
        mentionSound = true,
        mentionFlash = true,
        enableGuildAlerts = true,
        guildAlertSound = true,
    },
    
    ["Combat Focus"] = {
        -- For DPS focused on combat
        -- Smaller but still visible
        frameWidth = 320,
        frameHeight = 130,
        fontSize = 12,
        showButtonBar = false,
        fadeButtons = false,
        enableWindowFade = false,
        showBackground = true,
        showBorder = false,
        enableFading = false,
        enableShortChannels = true,
    },
}

-- ============================================================================
-- RESOURCE BARS PRESETS
-- ============================================================================

TweaksUI.BuiltInPresets.personalResources = {
    -- ========================================
    -- BASIC PRESET - Clean starting point
    -- ========================================
    
    ["Basic"] = {
        enabled = true,
        powerBar = {
            enabled = true,
            width = 250,
            height = 20,
            showBorder = true,
            borderSize = 1,
            borderColor = {0, 0, 0, 1},
            backgroundColor = {0.1, 0.1, 0.1, 0.8},
            useResourceColor = true,
            useClassColor = false,
            showText = true,
            textFormat = "current",
            textFontSize = 17,
            textFontOutline = "OUTLINE",
            textColor = {1, 1, 1, 1},
            fadeEnabled = false,
            visibilityEnabled = false,
            showSolo = true,
            showInParty = true,
            showInRaid = true,
            showInInstance = true,
            showInCombat = false,
            showOutOfCombat = false,
            showHasTarget = true,
            showNoTarget = true,
            maskShape = "none",
        },
        classPower = {
            enabled = false,
            width = 200,
            height = 12,
            spacing = 3,
            showBorder = true,
            borderSize = 1,
            useResourceColor = true,
            useClassColor = false,
            usePerPointColors = false,
            showText = false,
            textFormat = "current",
            textFontSize = 12,
            textFontOutline = "OUTLINE",
            fadeEnabled = false,
            visibilityEnabled = false,
        },
        soulFragments = {
            enabled = false,
            style = "fel",
            scale = 0.25,
            countFontSize = 28,
            countFontOutline = "OUTLINE",
            showLabel = true,
            labelFontSize = 10,
            labelFontOutline = "OUTLINE",
            visibilityEnabled = false,
        },
        healthBar = {
            enabled = false,
        },
        buffs = {
            enabled = false,
        },
        debuffs = {
            enabled = false,
        },
        global = {
            scale = 1.0,
            hideBlizzardBars = true,
        },
    },
    
    -- ========================================
    -- GENERAL PRESETS
    -- ========================================
    
    ["Modern"] = {
        enabled = true,
        powerBar = {
            enabled = true,
            width = 220,
            height = 18,
            showBorder = true,
            borderSize = 1,
            useResourceColor = true,
            showText = true,
            textFormat = "current_max",
            textFontSize = 11,
            fadeEnabled = false,
            visibilityEnabled = false,
        },
        classPower = {
            enabled = true,
            width = 220,
            height = 14,
            spacing = 3,
            showBorder = true,
            useResourceColor = true,
            usePerPointColors = false,
            showText = false,
            fadeEnabled = false,
            visibilityEnabled = false,
        },
        soulFragments = {
            enabled = true,
            style = "fel",
            scale = 0.28,
            countFontSize = 30,
            showLabel = true,
            labelFontSize = 10,
        },
        global = {
            scale = 1.0,
            hideBlizzardBars = true,
        },
    },
    
    ["Minimal"] = {
        enabled = true,
        powerBar = {
            enabled = true,
            width = 180,
            height = 12,
            showBorder = false,
            useResourceColor = true,
            showText = true,
            textFormat = "percent",
            textFontSize = 10,
            fadeEnabled = false,
            visibilityEnabled = false,
        },
        classPower = {
            enabled = true,
            width = 180,
            height = 10,
            spacing = 2,
            showBorder = false,
            useResourceColor = true,
            showText = false,
            fadeEnabled = false,
            visibilityEnabled = false,
        },
        soulFragments = {
            enabled = true,
            style = "fel",
            scale = 0.22,
            countFontSize = 26,
            showLabel = false,
        },
        global = {
            scale = 1.0,
            hideBlizzardBars = true,
        },
    },
    
    ["Large"] = {
        enabled = true,
        powerBar = {
            enabled = true,
            width = 280,
            height = 24,
            showBorder = true,
            borderSize = 2,
            useResourceColor = true,
            showText = true,
            textFormat = "current_max",
            textFontSize = 14,
            fadeEnabled = false,
            visibilityEnabled = false,
        },
        classPower = {
            enabled = true,
            width = 280,
            height = 18,
            spacing = 4,
            showBorder = true,
            useResourceColor = true,
            showText = true,
            textFormat = "current",
            textFontSize = 12,
            visibilityEnabled = false,
        },
        soulFragments = {
            enabled = true,
            style = "fel",
            scale = 0.35,
            countFontSize = 36,
            showLabel = true,
            labelFontSize = 12,
        },
        global = {
            scale = 1.1,
            hideBlizzardBars = true,
        },
    },
    
    ["Disabled"] = {
        enabled = false,
        powerBar = { enabled = false },
        classPower = { enabled = false },
        soulFragments = { enabled = false },
        global = { hideBlizzardBars = false },
    },
    
    -- ========================================
    -- ROLE-BASED PRESETS
    -- ========================================
    
    ["Tank"] = {
        enabled = true,
        powerBar = {
            enabled = true,
            width = 240,
            height = 20,
            showBorder = true,
            borderSize = 1,
            useResourceColor = true,
            showText = true,
            textFormat = "current_max",
            textFontSize = 12,
            fadeEnabled = false,
            -- Always visible for tanks (resource management is critical)
            visibilityEnabled = false,
        },
        classPower = {
            enabled = true,
            width = 240,
            height = 16,
            spacing = 3,
            showBorder = true,
            useResourceColor = true,
            showText = true,
            textFontSize = 11,
            visibilityEnabled = false,
        },
        soulFragments = {
            enabled = true,
            style = "fel",
            scale = 0.30,
            countFontSize = 32,
            showLabel = true,
        },
        stagger = {
            useDynamicColor = true,
            textFormat = "percent",
        },
        global = {
            scale = 1.0,
            hideBlizzardBars = true,
        },
    },
    
    ["Healer"] = {
        enabled = true,
        powerBar = {
            enabled = true,
            width = 260,
            height = 22,
            showBorder = true,
            useResourceColor = true,
            showText = true,
            textFormat = "current_max",
            textFontSize = 13,
            fadeEnabled = false,
            -- Always visible for healers (mana management)
            visibilityEnabled = false,
        },
        classPower = {
            enabled = true,
            width = 260,
            height = 16,
            spacing = 3,
            showBorder = true,
            useResourceColor = true,
            showText = false,
            visibilityEnabled = false,
        },
        soulFragments = {
            enabled = false,
        },
        global = {
            scale = 1.0,
            hideBlizzardBars = true,
        },
    },
    
    ["DPS"] = {
        enabled = true,
        powerBar = {
            enabled = true,
            width = 200,
            height = 16,
            showBorder = true,
            useResourceColor = true,
            showText = true,
            textFormat = "current",
            textFontSize = 11,
            fadeEnabled = false,
            -- Combat visibility for DPS (resource not as critical out of combat)
            visibilityEnabled = false,
        },
        classPower = {
            enabled = true,
            width = 200,
            height = 14,
            spacing = 3,
            showBorder = true,
            useResourceColor = true,
            usePerPointColors = true,
            showText = false,
            visibilityEnabled = false,
        },
        soulFragments = {
            enabled = true,
            style = "fel",
            scale = 0.25,
            countFontSize = 28,
            showLabel = false,
        },
        global = {
            scale = 1.0,
            hideBlizzardBars = true,
        },
    },
}

-- ============================================================================
-- NAMEPLATES PRESETS
-- These use the actual nested structure from Nameplates module
-- ============================================================================

TweaksUI.BuiltInPresets.nameplates = {
    -- ========================================
    -- BASIC PRESET - Clean starting point
    -- ========================================
    
    ["Basic"] = {
        enabled = true,
        globalScale = 100,
        enemy = {
            scale = 95,
            healthBar = {
                enabled = true,
                width = 118,
                height = 10,
                colorMode = "threat",
                targetScale = 150,
                targetWidth = 208,
                targetHeight = 15,
                mouseoverScale = 140,
                alpha = 0.6,
                targetAlpha = 1,
                occludedAlpha = 0.05,
                bgEnabled = true,
                bgColor = {0, 0, 0, 0.75},
                borderEnabled = true,
                borderSize = 1,
                borderColor = {0, 0, 0, 1},
                threatScaleEnabled = true,
                invertThreatColors = true,
            },
            nameText = {
                enabled = true,
                fontSize = 12,
                colorMode = "threat",
                outline = "THIN",
                shadow = false,
            },
            healthText = {
                enabled = true,
                fontSize = 9,
                format = "PERCENT",
                colorMode = "threat",
                outline = "THIN",
                shadow = true,
            },
            threatText = {
                enabled = true,
                fontSize = 9,
                colorMode = "threat",
                showPercent = true,
                outline = "THIN",
                shadow = true,
            },
            icons = {
                raidMarkerEnabled = true,
                raidMarkerSize = 40,
                classificationEnabled = true,
                classificationSize = 18,
                levelEnabled = true,
                questEnabled = true,
                questSize = 16,
                pvpMarkerEnabled = false,
            },
            castBar = {
                enabled = true,
                height = 14,
                iconEnabled = true,
                iconSize = 0,
                spellNameEnabled = true,
                spellNameFontSize = 9,
                timerEnabled = true,
                timerFontSize = 9,
                borderEnabled = true,
                showInterruptShield = true,
                castingColor = {1, 0.7, 0, 1},
                channelingColor = {0, 0.7, 1, 1},
                nonInterruptibleColor = {0.5, 0.5, 0.5, 1},
                importantCastColor = {1, 0, 0.5, 1},
                importantChannelColor = {0.5, 0, 1, 1},
                castTargetEnabled = true,
            },
            auras = {
                enabled = true,
                buffs = {
                    enabled = true,
                    iconSize = 18,
                    maxIcons = 4,
                    showDuration = true,
                    onlyDispellable = true,
                    onlyStealable = true,
                    showEnrage = true,
                },
                debuffs = {
                    enabled = true,
                    iconSize = 25,
                    maxIcons = 10,
                    showDuration = true,
                    showDurationText = true,
                    onlyMine = true,
                    onlyNameplateRelevant = true,
                    hidePermanent = true,
                },
            },
        },
        friendly = {
            scale = 100,
            healthBar = {
                enabled = true,
                width = 140,
                height = 12,
                colorMode = "class",
                targetScale = 110,
                targetAlpha = 1,
                alpha = 0.4,
                occludedAlpha = 0.05,
            },
            nameText = {
                enabled = true,
                fontSize = 12,
                colorMode = "white",
                outline = "THIN",
                shadow = true,
            },
            healthText = {
                enabled = false,
            },
            threatText = {
                enabled = false,
            },
            icons = {
                raidMarkerEnabled = true,
                raidMarkerSize = 20,
                classificationEnabled = true,
                classificationSize = 16,
                questEnabled = true,
            },
            castBar = {
                enabled = true,
                height = 10,
                iconEnabled = true,
                spellNameEnabled = true,
                timerEnabled = true,
                borderEnabled = true,
                castTargetEnabled = true,
            },
            auras = {
                enabled = false,
            },
        },
        targetHighlight = { enabled = true, style = "glow", color = {1, 0.94, 0.27, 0.6}, thickness = 1 },
        focusHighlight = { enabled = false, style = "glow", color = {0.5, 0, 1, 0.6}, thickness = 3 },
        mouseoverHighlight = { enabled = true, style = "glow", color = {0.3, 1, 0.3, 0.5}, thickness = 2 },
    },
    
    -- ========================================
    -- GENERAL PRESETS
    -- ========================================
    
    ["Modern"] = {
        -- Clean, polished look with all features
        enemy = {
            scale = 100,
            healthBar = {
                enabled = true,
                width = 130,
                height = 12,
                colorMode = "reaction",
                targetScale = 115,
                mouseoverScale = 108,
                bgEnabled = true,
                borderEnabled = true,
                borderSize = 1,
            },
            nameText = {
                enabled = true,
                fontSize = 10,
                colorMode = "reaction",
                outline = "OUTLINE",
                shadow = true,
            },
            healthText = {
                enabled = true,
                fontSize = 9,
                format = "PERCENT",
                outline = "OUTLINE",
            },
            threatText = {
                enabled = false,
            },
            icons = {
                raidMarkerEnabled = true,
                raidMarkerSize = 22,
                classificationEnabled = true,
                classificationSize = 16,
                levelEnabled = false,
                questEnabled = true,
            },
            castBar = {
                enabled = true,
                height = 10,
                iconEnabled = true,
                spellNameEnabled = true,
                timerEnabled = true,
            },
        },
        friendly = {
            scale = 95,
            healthBar = {
                enabled = true,
                width = 110,
                height = 8,
                colorMode = "class",
                targetScale = 110,
                mouseoverScale = 105,
            },
            nameText = {
                enabled = true,
                fontSize = 9,
                colorMode = "class",
            },
            healthText = {
                enabled = false,
            },
            icons = {
                raidMarkerEnabled = true,
            },
        },
        targetHighlight = { enabled = true, style = "glow", color = { 1, 1, 1, 0.7 }, thickness = 3 },
        focusHighlight = { enabled = true, style = "glow", color = { 0.5, 0, 1, 0.6 }, thickness = 3 },
        mouseoverHighlight = { enabled = true, style = "glow", color = { 0.3, 1, 0.3, 0.4 }, thickness = 2 },
    },
    
    ["Minimal"] = {
        -- Stripped down, just essential info
        enemy = {
            scale = 85,
            healthBar = {
                enabled = true,
                width = 90,
                height = 6,
                colorMode = "reaction",
                targetScale = 110,
                mouseoverScale = 100,
                bgEnabled = true,
                borderEnabled = false,
            },
            nameText = {
                enabled = true,
                fontSize = 8,
            },
            healthText = {
                enabled = false,
            },
            threatText = {
                enabled = false,
            },
            icons = {
                raidMarkerEnabled = true,
                raidMarkerSize = 16,
                classificationEnabled = false,
                levelEnabled = false,
                questEnabled = false,
            },
            castBar = {
                enabled = true,
                height = 6,
                iconEnabled = true,
                spellNameEnabled = false,
                timerEnabled = false,
            },
        },
        friendly = {
            scale = 80,
            healthBar = {
                enabled = true,
                width = 70,
                height = 4,
                colorMode = "class",
            },
            nameText = {
                enabled = true,
                fontSize = 8,
            },
            healthText = {
                enabled = false,
            },
        },
        targetHighlight = { enabled = true, style = "glow" },
        focusHighlight = { enabled = false },
        mouseoverHighlight = { enabled = false },
    },
    
    ["Disabled"] = {
        enemy = {
            scale = 100,
            healthBar = { enabled = false },
            nameText = { enabled = false },
            healthText = { enabled = false },
            castBar = { enabled = false },
        },
        friendly = {
            scale = 100,
            healthBar = { enabled = false },
            nameText = { enabled = false },
            healthText = { enabled = false },
        },
    },
    
    -- ========================================
    -- ROLE-BASED PRESETS
    -- ========================================
    
    ["Tank"] = {
        -- Inverted threat colors (green = have threat, red = lost threat)
        -- Larger target/mouseover scale for easy identification
        -- Threat percentage text for monitoring
        enemy = {
            scale = 100,
            healthBar = {
                enabled = true,
                width = 120,
                height = 10,
                colorMode = "threat",
                -- CRITICAL: Invert threat colors for tanks
                -- Green = you have aggro (good!)
                -- Red = you lost aggro (bad!)
                invertThreatColors = true,
                -- Make targeted/moused-over enemies much larger
                targetScale = 130,       -- 30% larger when targeted
                mouseoverScale = 120,    -- 20% larger on mouseover
                -- Scale based on threat level
                threatScaleEnabled = true,
                threatScaleMin = 90,
                threatScaleMax = 115,
                bgEnabled = true,
                borderEnabled = true,
                borderSize = 1,
            },
            nameText = {
                enabled = true,
                fontSize = 10,
                colorMode = "reaction",
            },
            healthText = {
                enabled = true,
                fontSize = 9,
                format = "CURRENT",  -- Show actual health for gauging damage
            },
            threatText = {
                enabled = true,
                fontSize = 9,
                colorMode = "threat",
                showPercent = true,
            },
            icons = {
                raidMarkerEnabled = true,
                raidMarkerSize = 24,
                classificationEnabled = true,
                classificationSize = 18,
                levelEnabled = false,
                questEnabled = true,
            },
            castBar = {
                enabled = true,
                height = 12,
                iconEnabled = true,
                iconSize = 14,
                spellNameEnabled = true,
                spellNameFontSize = 10,
                timerEnabled = true,
                timerFontSize = 10,
                -- Make important/dangerous casts stand out
                importantCastColor = { 1, 0, 0.3, 1 },
            },
        },
        friendly = {
            scale = 85,
            healthBar = {
                enabled = true,
                width = 80,
                height = 5,
                colorMode = "class",
                targetScale = 110,
                mouseoverScale = 105,
            },
            nameText = {
                enabled = true,
                fontSize = 8,
                colorMode = "class",
            },
            healthText = {
                enabled = false,
            },
        },
        targetHighlight = { enabled = true, style = "glow", color = { 1, 0.8, 0, 0.8 }, thickness = 4 },
        focusHighlight = { enabled = true, style = "glow", color = { 0.5, 0, 1, 0.7 }, thickness = 3 },
        mouseoverHighlight = { enabled = true, style = "glow", color = { 1, 1, 1, 0.5 }, thickness = 2 },
    },
    
    ["Healer"] = {
        -- Focus on friendly nameplates for healing
        -- Enemy nameplates smaller/less prominent
        -- Health deficit display for triage
        friendly = {
            scale = 100,
            healthBar = {
                enabled = true,
                width = 100,
                height = 8,
                colorMode = "health",  -- Color by health % for quick triage
                targetScale = 115,
                mouseoverScale = 110,
                bgEnabled = true,
                borderEnabled = true,
            },
            nameText = {
                enabled = true,
                fontSize = 10,
                colorMode = "class",
            },
            healthText = {
                enabled = true,
                fontSize = 9,
                format = "DEFICIT",  -- Show health missing
                colorMode = "white",
            },
            icons = {
                raidMarkerEnabled = true,
                raidMarkerSize = 20,
            },
            castBar = {
                enabled = true,
                height = 8,
            },
        },
        enemy = {
            scale = 80,
            healthBar = {
                enabled = true,
                width = 80,
                height = 6,
                colorMode = "reaction",
                targetScale = 110,
                mouseoverScale = 100,
            },
            nameText = {
                enabled = true,
                fontSize = 8,
            },
            healthText = {
                enabled = false,
            },
            icons = {
                raidMarkerEnabled = true,
                classificationEnabled = false,
            },
            castBar = {
                enabled = true,
                height = 6,
            },
        },
        targetHighlight = { enabled = true, style = "glow", color = { 0.2, 1, 0.2, 0.7 }, thickness = 3 },
        focusHighlight = { enabled = true, style = "glow", color = { 1, 0.5, 0, 0.6 }, thickness = 3 },
        mouseoverHighlight = { enabled = true, style = "glow", color = { 0.5, 1, 0.5, 0.4 }, thickness = 2 },
    },
    
    ["Melee DPS"] = {
        -- Enemy focus with prominent cast bars for kicks
        -- Clear threat display (want to avoid pulling)
        enemy = {
            scale = 105,
            healthBar = {
                enabled = true,
                width = 125,
                height = 12,
                colorMode = "threat",  -- Shows if you're pulling aggro
                targetScale = 120,
                mouseoverScale = 110,
                bgEnabled = true,
                borderEnabled = true,
                borderSize = 1,
            },
            nameText = {
                enabled = true,
                fontSize = 10,
                colorMode = "reaction",
            },
            healthText = {
                enabled = true,
                fontSize = 9,
                format = "PERCENT",
            },
            threatText = {
                enabled = false,
            },
            icons = {
                raidMarkerEnabled = true,
                raidMarkerSize = 22,
                classificationEnabled = true,
                classificationSize = 16,
                levelEnabled = false,
            },
            castBar = {
                enabled = true,
                height = 12,
                iconEnabled = true,
                iconSize = 14,
                spellNameEnabled = true,
                spellNameFontSize = 10,
                timerEnabled = true,
                timerFontSize = 10,
                timerShowDecimals = true,
            },
        },
        friendly = {
            scale = 85,
            healthBar = {
                enabled = true,
                width = 70,
                height = 4,
                colorMode = "class",
            },
            nameText = {
                enabled = true,
                fontSize = 8,
            },
            healthText = {
                enabled = false,
            },
        },
        targetHighlight = { enabled = true, style = "glow", color = { 1, 0.3, 0.3, 0.7 }, thickness = 3 },
        focusHighlight = { enabled = true, style = "glow", color = { 1, 0.5, 0, 0.7 }, thickness = 3 },
        mouseoverHighlight = { enabled = true, style = "glow", color = { 1, 1, 1, 0.4 }, thickness = 2 },
    },
    
    ["Ranged DPS"] = {
        -- Similar to melee but slightly smaller scale
        -- Still prominent cast bars for interrupts
        enemy = {
            scale = 100,
            healthBar = {
                enabled = true,
                width = 120,
                height = 11,
                colorMode = "threat",
                targetScale = 115,
                mouseoverScale = 108,
                bgEnabled = true,
                borderEnabled = true,
            },
            nameText = {
                enabled = true,
                fontSize = 10,
                colorMode = "reaction",
            },
            healthText = {
                enabled = true,
                fontSize = 9,
                format = "PERCENT",
            },
            icons = {
                raidMarkerEnabled = true,
                raidMarkerSize = 20,
                classificationEnabled = true,
                levelEnabled = false,
            },
            castBar = {
                enabled = true,
                height = 11,
                iconEnabled = true,
                spellNameEnabled = true,
                timerEnabled = true,
                timerShowDecimals = true,
            },
        },
        friendly = {
            scale = 85,
            healthBar = {
                enabled = true,
                width = 75,
                height = 5,
                colorMode = "class",
            },
            nameText = {
                enabled = true,
                fontSize = 8,
            },
            healthText = {
                enabled = false,
            },
        },
        targetHighlight = { enabled = true, style = "glow", color = { 1, 0.5, 0, 0.7 }, thickness = 3 },
        focusHighlight = { enabled = true, style = "glow", color = { 0.5, 0, 1, 0.7 }, thickness = 3 },
        mouseoverHighlight = { enabled = true, style = "glow", color = { 1, 1, 1, 0.4 }, thickness = 2 },
    },
    
    -- ========================================
    -- CONTENT-SPECIFIC PRESETS
    -- ========================================
    
    ["M+ Dungeon"] = {
        enemy = {
            scale = 105,
            healthBar = {
                enabled = true,
                width = 125,
                height = 12,
                colorMode = "threat",
                targetScale = 125,
                mouseoverScale = 115,
                bgEnabled = true,
                borderEnabled = true,
            },
            nameText = {
                enabled = true,
                fontSize = 10,
            },
            healthText = {
                enabled = true,
                fontSize = 9,
                format = "PERCENT",
            },
            icons = {
                raidMarkerEnabled = true,
                raidMarkerSize = 24,
                classificationEnabled = true,
                questEnabled = true,
            },
            castBar = {
                enabled = true,
                height = 12,
                iconEnabled = true,
                spellNameEnabled = true,
                timerEnabled = true,
            },
        },
        friendly = {
            scale = 90,
            healthBar = {
                enabled = true,
                width = 85,
                height = 6,
                colorMode = "class",
            },
            nameText = {
                enabled = true,
                fontSize = 9,
            },
        },
        targetHighlight = { enabled = true, style = "glow", thickness = 4 },
        focusHighlight = { enabled = true, style = "glow", thickness = 3 },
        mouseoverHighlight = { enabled = true, style = "glow", thickness = 2 },
    },
    
    ["Raid Boss"] = {
        -- Minimal nameplates, focus on boss frames instead
        enemy = {
            scale = 90,
            healthBar = {
                enabled = true,
                width = 100,
                height = 8,
                colorMode = "reaction",
                targetScale = 110,
                mouseoverScale = 100,
            },
            nameText = {
                enabled = true,
                fontSize = 9,
            },
            healthText = {
                enabled = false,
            },
            icons = {
                raidMarkerEnabled = true,
                classificationEnabled = false,
            },
            castBar = {
                enabled = true,
                height = 8,
            },
        },
        friendly = {
            scale = 85,
            healthBar = {
                enabled = true,
                width = 80,
                height = 5,
                colorMode = "class",
            },
            nameText = {
                enabled = true,
                fontSize = 8,
                colorMode = "class",
            },
        },
        targetHighlight = { enabled = true, style = "glow" },
        focusHighlight = { enabled = false },
        mouseoverHighlight = { enabled = false },
    },
    
    ["PvP"] = {
        -- Enemy player focus, class colors
        enemy = {
            scale = 105,
            healthBar = {
                enabled = true,
                width = 120,
                height = 12,
                colorMode = "class",  -- Class colors for enemy players
                targetScale = 125,
                mouseoverScale = 115,
            },
            nameText = {
                enabled = true,
                fontSize = 10,
                colorMode = "class",
            },
            healthText = {
                enabled = true,
                fontSize = 9,
                format = "PERCENT",
            },
            icons = {
                raidMarkerEnabled = true,
                pvpMarkerEnabled = true,
                pvpMarkerSize = 22,
            },
            castBar = {
                enabled = true,
                height = 12,
                iconEnabled = true,
                spellNameEnabled = true,
                timerEnabled = true,
            },
        },
        friendly = {
            scale = 90,
            healthBar = {
                enabled = true,
                width = 90,
                height = 8,
                colorMode = "class",
            },
            nameText = {
                enabled = true,
                fontSize = 9,
                colorMode = "class",
            },
            healthText = {
                enabled = true,
                fontSize = 8,
                format = "PERCENT",
            },
        },
        targetHighlight = { enabled = true, style = "glow", color = { 1, 0, 0, 0.8 }, thickness = 4 },
        focusHighlight = { enabled = true, style = "glow", color = { 1, 0.5, 0, 0.8 }, thickness = 3 },
        mouseoverHighlight = { enabled = true, style = "glow" },
    },
}

-- ============================================================================
-- ACTION BARS PRESETS
-- ============================================================================

TweaksUI.BuiltInPresets.actionBars = {
    -- ========================================
    -- BASIC PRESET - Clean starting point
    -- ========================================
    
    ["Basic"] = {
        enabled = true,
        bars = {
            ActionBar1 = {
                enabled = true,
                buttonsShown = 12,
                columns = 12,
                orientation = "horizontal",
                buttonSize = 38,
                horizontalSpacing = 0,
                verticalSpacing = 0,
                visibilityEnabled = false,
                barAlpha = 1.0,
                buttonAlpha = 1.0,
                buttonFrameAlpha = 1.0,
                keybindAlpha = 0,
                countAlpha = 1.0,
                macroNameAlpha = 0.45,
                pageArrowsAlpha = 0,
                hideGryphons = false,
                cooldownSwipeAlpha = 0.6,
                cooldownNumbersEnabled = true,
                iconZoom = 0.08,
                iconEdgeStyle = "default",
                rangeIndicatorEnabled = true,
                rangeIndicatorColor = {1, 0.1, 0.1, 0.4},
                useMasque = false,
            },
            ActionBar2 = {
                enabled = true,
                buttonsShown = 12,
                columns = 12,
                orientation = "vertical",
                buttonSize = 38,
                horizontalSpacing = 0,
                verticalSpacing = 0,
                visibilityEnabled = false,
                barAlpha = 1.0,
                buttonAlpha = 1.0,
                buttonFrameAlpha = 1.0,
                keybindAlpha = 0,
                countAlpha = 0,
                macroNameAlpha = 0,
                cooldownSwipeAlpha = 0.6,
                cooldownNumbersEnabled = true,
                iconZoom = 0.08,
                iconEdgeStyle = "default",
                rangeIndicatorEnabled = true,
            },
            ActionBar3 = {
                enabled = true,
                buttonsShown = 12,
                columns = 1,
                orientation = "vertical",
                buttonSize = 35,
                horizontalSpacing = 0,
                verticalSpacing = 0,
                visibilityEnabled = false,
                barAlpha = 1.0,
                buttonAlpha = 1.0,
                buttonFrameAlpha = 1.0,
                keybindAlpha = 0,
                countAlpha = 0,
                macroNameAlpha = 0,
                cooldownSwipeAlpha = 0.6,
                cooldownNumbersEnabled = true,
                iconZoom = 0.08,
                iconEdgeStyle = "default",
            },
            ActionBar4 = {
                enabled = true,
                buttonsShown = 12,
                columns = 1,
                orientation = "vertical",
                buttonSize = 35,
                horizontalSpacing = 0,
                verticalSpacing = 0,
                visibilityEnabled = false,
                barAlpha = 1.0,
                buttonAlpha = 1.0,
                buttonFrameAlpha = 1.0,
                keybindAlpha = 0,
                countAlpha = 1.0,
                macroNameAlpha = 0,
                cooldownSwipeAlpha = 0.6,
                cooldownNumbersEnabled = true,
                iconZoom = 0.08,
                iconEdgeStyle = "default",
            },
            ActionBar5 = {
                enabled = true,
                buttonsShown = 12,
                columns = 6,
                orientation = "horizontal",
                buttonSize = 38,
                horizontalSpacing = 0,
                verticalSpacing = 0,
                visibilityEnabled = false,
                barAlpha = 1.0,
                buttonAlpha = 1.0,
                buttonFrameAlpha = 0,
                keybindAlpha = 0,
                countAlpha = 0,
                macroNameAlpha = 0,
                cooldownSwipeAlpha = 0.6,
                cooldownNumbersEnabled = true,
                iconZoom = 0.08,
                iconEdgeStyle = "default",
            },
            ActionBar6 = { enabled = false },
            ActionBar7 = { enabled = false },
            ActionBar8 = { enabled = false },
        },
        systemBars = {
            StanceBar = {
                enabled = true,
                visibilityEnabled = false,
                showOnMouseover = false,
                barAlpha = 1.0,
            },
            PetBar = {
                enabled = true,
                visibilityEnabled = false,
                showOnMouseover = false,
                barAlpha = 1.0,
            },
            BagsBar = {
                enabled = true,
                visibilityEnabled = false,
                showOnMouseover = true,
                barAlpha = 1.0,
            },
            MicroMenu = {
                enabled = true,
                visibilityEnabled = false,
                showOnMouseover = true,
                barAlpha = 1.0,
            },
        },
        stanceBar = {
            enabled = true,
            hideBlizzard = true,
            buttonSize = 36,
            spacing = 2,
            columns = 10,
            orientation = "horizontal",
            iconZoom = 0,
            iconEdgeStyle = "default",
            visibilityEnabled = false,
            showOnMouseover = false,
            barAlpha = 1.0,
            useMasque = false,
        },
    },
    
    -- ========================================
    -- GENERAL PRESETS
    -- ========================================
    
    ["Modern"] = {
        -- Clean layout, all bars visible, standard sizes
        bars = {
            bar1 = {
                enabled = true,
                buttonsShown = 12,
                columns = 12,
                orientation = "horizontal",
                buttonSize = 45,
                horizontalSpacing = 6,
                verticalSpacing = 6,
                visibilityEnabled = false,
                barAlpha = 1.0,
                buttonFrameAlpha = 1.0,
                keybindAlpha = 1.0,
                countAlpha = 1.0,
                macroNameAlpha = 0.0,
                hideGryphons = true,
                cooldownSwipeAlpha = 0.6,
                cooldownNumbersEnabled = true,
            },
            bar2 = {
                enabled = true,
                buttonsShown = 12,
                columns = 12,
                orientation = "horizontal",
                buttonSize = 40,
                horizontalSpacing = 4,
                verticalSpacing = 4,
                visibilityEnabled = false,
                barAlpha = 1.0,
            },
            bar3 = {
                enabled = true,
                buttonsShown = 12,
                columns = 12,
                orientation = "horizontal",
                buttonSize = 40,
                horizontalSpacing = 4,
                verticalSpacing = 4,
                visibilityEnabled = false,
                barAlpha = 1.0,
            },
            bar4 = {
                enabled = true,
                buttonsShown = 12,
                columns = 1,
                orientation = "vertical",
                buttonSize = 36,
                horizontalSpacing = 4,
                verticalSpacing = 4,
                visibilityEnabled = false,
                barAlpha = 1.0,
            },
            bar5 = {
                enabled = true,
                buttonsShown = 12,
                columns = 1,
                orientation = "vertical",
                buttonSize = 36,
                horizontalSpacing = 4,
                verticalSpacing = 4,
                visibilityEnabled = false,
                barAlpha = 1.0,
            },
            bar6 = { enabled = false },
            bar7 = { enabled = false },
            bar8 = { enabled = false },
        },
        systemBars = {
            stanceBar = { enabled = false },
            petBar = { enabled = false },
            possessBar = { enabled = false },
        },
    },
    
    ["Minimal"] = {
        -- Only main bar and one extra, compact layout
        bars = {
            bar1 = {
                enabled = true,
                buttonsShown = 12,
                columns = 12,
                orientation = "horizontal",
                buttonSize = 40,
                horizontalSpacing = 4,
                verticalSpacing = 4,
                visibilityEnabled = false,
                barAlpha = 1.0,
                buttonFrameAlpha = 0.8,
                keybindAlpha = 0.8,
                countAlpha = 1.0,
                macroNameAlpha = 0.0,
                hideGryphons = true,
            },
            bar2 = {
                enabled = true,
                buttonsShown = 12,
                columns = 12,
                orientation = "horizontal",
                buttonSize = 36,
                horizontalSpacing = 3,
                verticalSpacing = 3,
                visibilityEnabled = false,
                barAlpha = 0.9,
            },
            bar3 = { enabled = false },
            bar4 = { enabled = false },
            bar5 = { enabled = false },
            bar6 = { enabled = false },
            bar7 = { enabled = false },
            bar8 = { enabled = false },
        },
        systemBars = {
            stanceBar = { enabled = false },
            petBar = { enabled = false },
            possessBar = { enabled = false },
        },
    },
    
    ["Large"] = {
        -- Bigger buttons for accessibility
        bars = {
            bar1 = {
                enabled = true,
                buttonsShown = 12,
                columns = 12,
                orientation = "horizontal",
                buttonSize = 56,
                horizontalSpacing = 8,
                verticalSpacing = 8,
                visibilityEnabled = false,
                barAlpha = 1.0,
                buttonFrameAlpha = 1.0,
                keybindAlpha = 1.0,
                countAlpha = 1.0,
                macroNameAlpha = 0.0,
                hideGryphons = true,
                cooldownSwipeAlpha = 0.7,
                cooldownNumbersEnabled = true,
            },
            bar2 = {
                enabled = true,
                buttonsShown = 12,
                columns = 12,
                orientation = "horizontal",
                buttonSize = 48,
                horizontalSpacing = 6,
                verticalSpacing = 6,
                visibilityEnabled = false,
                barAlpha = 1.0,
            },
            bar3 = {
                enabled = true,
                buttonsShown = 12,
                columns = 12,
                orientation = "horizontal",
                buttonSize = 48,
                horizontalSpacing = 6,
                verticalSpacing = 6,
                visibilityEnabled = false,
                barAlpha = 1.0,
            },
            bar4 = {
                enabled = true,
                buttonsShown = 12,
                columns = 1,
                orientation = "vertical",
                buttonSize = 44,
                horizontalSpacing = 6,
                verticalSpacing = 6,
                visibilityEnabled = false,
                barAlpha = 1.0,
            },
            bar5 = {
                enabled = true,
                buttonsShown = 12,
                columns = 1,
                orientation = "vertical",
                buttonSize = 44,
                horizontalSpacing = 6,
                verticalSpacing = 6,
                visibilityEnabled = false,
                barAlpha = 1.0,
            },
            bar6 = { enabled = false },
            bar7 = { enabled = false },
            bar8 = { enabled = false },
        },
        systemBars = {
            stanceBar = { enabled = true, barAlpha = 1.0 },
            petBar = { enabled = true, barAlpha = 1.0 },
            possessBar = { enabled = false },
        },
    },
    
    ["Disabled"] = {
        -- All customizations off
        bars = {
            bar1 = { enabled = false },
            bar2 = { enabled = false },
            bar3 = { enabled = false },
            bar4 = { enabled = false },
            bar5 = { enabled = false },
            bar6 = { enabled = false },
            bar7 = { enabled = false },
            bar8 = { enabled = false },
        },
        systemBars = {
            stanceBar = { enabled = false },
            petBar = { enabled = false },
            possessBar = { enabled = false },
        },
    },
    
    -- ========================================
    -- ROLE PRESETS
    -- ========================================
    
    ["Tank"] = {
        -- Extra bars for defensives, always visible
        bars = {
            bar1 = {
                enabled = true,
                buttonsShown = 12,
                columns = 12,
                orientation = "horizontal",
                buttonSize = 48,
                horizontalSpacing = 5,
                verticalSpacing = 5,
                visibilityEnabled = false,
                barAlpha = 1.0,
                buttonFrameAlpha = 1.0,
                keybindAlpha = 1.0,
                hideGryphons = true,
            },
            bar2 = {
                enabled = true,
                buttonsShown = 12,
                columns = 12,
                orientation = "horizontal",
                buttonSize = 42,
                horizontalSpacing = 4,
                verticalSpacing = 4,
                visibilityEnabled = false,
                barAlpha = 1.0,
            },
            bar3 = {
                enabled = true,
                buttonsShown = 12,
                columns = 12,
                orientation = "horizontal",
                buttonSize = 42,
                horizontalSpacing = 4,
                verticalSpacing = 4,
                visibilityEnabled = false,
                barAlpha = 1.0,
            },
            bar4 = {
                enabled = true,
                buttonsShown = 12,
                columns = 1,
                orientation = "vertical",
                buttonSize = 38,
                horizontalSpacing = 4,
                verticalSpacing = 4,
                visibilityEnabled = false,
                barAlpha = 1.0,
            },
            bar5 = {
                enabled = true,
                buttonsShown = 12,
                columns = 1,
                orientation = "vertical",
                buttonSize = 38,
                horizontalSpacing = 4,
                verticalSpacing = 4,
                visibilityEnabled = false,
                barAlpha = 1.0,
            },
            bar6 = { enabled = false },
            bar7 = { enabled = false },
            bar8 = { enabled = false },
        },
        systemBars = {
            stanceBar = { enabled = true, barAlpha = 1.0 },
            petBar = { enabled = false },
            possessBar = { enabled = false },
        },
    },
    
    ["Healer"] = {
        -- Clean layout for healing
        bars = {
            bar1 = {
                enabled = true,
                buttonsShown = 12,
                columns = 12,
                orientation = "horizontal",
                buttonSize = 44,
                horizontalSpacing = 5,
                verticalSpacing = 5,
                visibilityEnabled = false,
                barAlpha = 1.0,
                buttonFrameAlpha = 1.0,
                keybindAlpha = 1.0,
                hideGryphons = true,
            },
            bar2 = {
                enabled = true,
                buttonsShown = 12,
                columns = 12,
                orientation = "horizontal",
                buttonSize = 38,
                horizontalSpacing = 4,
                verticalSpacing = 4,
                visibilityEnabled = false,
                barAlpha = 1.0,
            },
            bar3 = {
                enabled = true,
                buttonsShown = 12,
                columns = 12,
                orientation = "horizontal",
                buttonSize = 38,
                horizontalSpacing = 4,
                verticalSpacing = 4,
                visibilityEnabled = false,
                barAlpha = 0.9,
            },
            bar4 = {
                enabled = true,
                buttonsShown = 12,
                columns = 1,
                orientation = "vertical",
                buttonSize = 34,
                horizontalSpacing = 3,
                verticalSpacing = 3,
                visibilityEnabled = false,
                barAlpha = 0.9,
            },
            bar5 = { enabled = false },
            bar6 = { enabled = false },
            bar7 = { enabled = false },
            bar8 = { enabled = false },
        },
        systemBars = {
            stanceBar = { enabled = false },
            petBar = { enabled = false },
            possessBar = { enabled = false },
        },
    },
    
    ["DPS"] = {
        -- Compact, combat-focused
        bars = {
            bar1 = {
                enabled = true,
                buttonsShown = 12,
                columns = 12,
                orientation = "horizontal",
                buttonSize = 44,
                horizontalSpacing = 4,
                verticalSpacing = 4,
                visibilityEnabled = false,
                barAlpha = 1.0,
                buttonFrameAlpha = 1.0,
                keybindAlpha = 1.0,
                hideGryphons = true,
            },
            bar2 = {
                enabled = true,
                buttonsShown = 12,
                columns = 12,
                orientation = "horizontal",
                buttonSize = 38,
                horizontalSpacing = 3,
                verticalSpacing = 3,
                visibilityEnabled = false,
                barAlpha = 1.0,
            },
            bar3 = {
                enabled = true,
                buttonsShown = 12,
                columns = 12,
                orientation = "horizontal",
                buttonSize = 36,
                horizontalSpacing = 3,
                verticalSpacing = 3,
                visibilityEnabled = false,
                barAlpha = 0.9,
            },
            bar4 = {
                enabled = true,
                buttonsShown = 12,
                columns = 1,
                orientation = "vertical",
                buttonSize = 34,
                horizontalSpacing = 3,
                verticalSpacing = 3,
                visibilityEnabled = false,
                barAlpha = 0.9,
            },
            bar5 = { enabled = false },
            bar6 = { enabled = false },
            bar7 = { enabled = false },
            bar8 = { enabled = false },
        },
        systemBars = {
            stanceBar = { enabled = false },
            petBar = { enabled = false },
            possessBar = { enabled = false },
        },
    },
}

-- ============================================================================
-- UNIT FRAMES PRESETS
-- ============================================================================

TweaksUI.BuiltInPresets.unitFrames = {
    -- ========================================
    -- BASIC PRESET - Clean starting point
    -- ========================================
    
    ["Basic"] = {
        -- Module disabled by default in Basic - uses Blizzard frames
        enabled = false,
        general = {
            smoothBars = true,
            dispelColors = true,
            auraDurationColors = true,
            font = "2002",
            mouseoverHighlight = {
                enabled = true,
                style = "overlay",
                color = {1, 1, 1, 0.2},
            },
        },
        player = {
            enabled = true,
            frame = {
                width = 220,
                height = 38,
                scale = 1.0,
                showBackground = true,
                bgColor = {0.08, 0.08, 0.1, 0.88},
                showBorder = true,
                borderColor = {0.15, 0.15, 0.2, 1},
                borderSize = 1,
                padding = 1,
                barSpacing = 1,
                autoSize = true,
            },
            healthBar = {
                enabled = true,
                height = 28,
                texture = "Blizzard Raid Bar",
                colorMode = "class",
                bgColor = {0.12, 0.12, 0.15, 0.85},
                borderEnabled = true,
                borderColor = {0.44, 0.44, 0.44, 1},
            },
            powerBar = {
                enabled = true,
                height = 6,
                texture = "Blizzard Raid Bar",
                colorMode = "power",
                bgColor = {0.1, 0.1, 0.12, 0.8},
            },
            healthText = {
                enabled = true,
                format = "percent",
                fontSize = 11,
                fontOutline = "OUTLINE",
                hAlign = "RIGHT",
                colorByHealth = false,
            },
            nameText = {
                enabled = true,
                fontSize = 11,
                fontOutline = "OUTLINE",
                colorMode = "class",
                hAlign = "LEFT",
                anchorToHealthBar = true,
            },
            portrait = { enabled = false },
            buffs = {
                enabled = true,
                size = 20,
                maxAuras = 7,
                spacing = 2,
                hidePermanent = true,
                maxDuration = 59,
                showDurationText = true,
            },
            debuffs = { enabled = false },
            debuffIndicators = {
                enabled = true,
                style = "squares",
                size = 14,
                position = "BOTTOMRIGHT",
            },
            statusIndicators = {
                enabled = true,
                showCombat = true,
                showResting = true,
                size = 24,
            },
            healPrediction = { enabled = true },
            raidTarget = { enabled = true, size = 20 },
            roleIcon = { enabled = true, size = 16 },
            castBar = { enabled = false },
            classPower = { enabled = false },
        },
        target = {
            enabled = true,
            frame = {
                width = 220,
                height = 38,
                scale = 1.0,
                showBackground = true,
                bgColor = {0.08, 0.08, 0.1, 0.88},
                showBorder = true,
                borderColor = {0.15, 0.15, 0.2, 1},
                borderSize = 1,
                padding = 1,
                barSpacing = 1,
                autoSize = true,
            },
            healthBar = {
                enabled = true,
                height = 28,
                texture = "Blizzard Raid Bar",
                colorMode = "class",
                bgColor = {0.12, 0.12, 0.15, 0.85},
            },
            powerBar = {
                enabled = true,
                height = 6,
                texture = "Blizzard Raid Bar",
                colorMode = "power",
                bgColor = {0.1, 0.1, 0.12, 0.8},
            },
            healthText = {
                enabled = true,
                format = "percent",
                fontSize = 11,
                fontOutline = "OUTLINE",
                hAlign = "RIGHT",
                colorByHealth = false,
            },
            nameText = {
                enabled = true,
                fontSize = 11,
                fontOutline = "OUTLINE",
                colorMode = "class",
                hAlign = "LEFT",
                anchorToHealthBar = true,
            },
            portrait = { enabled = false },
            buffs = {
                enabled = true,
                size = 20,
                maxAuras = 8,
                spacing = 2,
                hidePermanent = true,
            },
            debuffs = {
                enabled = true,
                size = 22,
                maxAuras = 8,
                spacing = 2,
                hidePermanent = true,
                filter = "HARMFUL|PLAYER",
            },
            debuffIndicators = { enabled = true, size = 14 },
            healPrediction = { enabled = true },
            raidTarget = { enabled = true, size = 20 },
            castBar = { enabled = false },
        },
        focus = {
            enabled = true,
            frame = {
                width = 180,
                height = 24,
                scale = 0.95,
                showBackground = false,
                showBorder = false,
                autoSize = true,
            },
            healthBar = {
                enabled = true,
                height = 18,
                texture = "Blizzard Character Skills Bar",
                colorMode = "class",
                bgColor = {0.15, 0.15, 0.15, 0.6},
            },
            powerBar = {
                enabled = true,
                height = 9,
                colorMode = "power",
            },
            healthText = {
                enabled = true,
                format = "percent",
                fontSize = 10,
                colorByHealth = true,
            },
            nameText = {
                enabled = true,
                fontSize = 10,
                colorMode = "white",
            },
            portrait = { enabled = false },
            debuffIndicators = { enabled = true, size = 14 },
            healPrediction = { enabled = true },
            raidTarget = { enabled = true, size = 18 },
            castBar = { enabled = true, height = 12 },
        },
        pet = {
            enabled = true,
            frame = {
                width = 180,
                height = 24,
                scale = 1.05,
                showBackground = false,
                showBorder = false,
                autoSize = true,
            },
            healthBar = {
                enabled = true,
                height = 18,
                texture = "Blizzard Character Skills Bar",
                colorMode = "class",
            },
            powerBar = {
                enabled = true,
                height = 9,
            },
            healthText = {
                enabled = true,
                format = "percent",
                fontSize = 10,
                colorByHealth = true,
            },
            nameText = {
                enabled = true,
                fontSize = 10,
                colorMode = "white",
            },
            portrait = { enabled = false },
            debuffIndicators = { enabled = true, size = 14 },
            healPrediction = { enabled = true },
            castBar = { enabled = true, height = 8 },
        },
        targettarget = {
            enabled = true,
            frame = {
                width = 180,
                height = 24,
                scale = 0.95,
                showBackground = false,
                showBorder = false,
                autoSize = true,
            },
            healthBar = {
                enabled = true,
                height = 18,
                texture = "Blizzard Character Skills Bar",
                colorMode = "class",
            },
            powerBar = {
                enabled = true,
                height = 9,
            },
            healthText = {
                enabled = true,
                format = "percent",
                fontSize = 10,
                colorByHealth = true,
            },
            nameText = {
                enabled = true,
                fontSize = 10,
                colorMode = "white",
            },
            portrait = { enabled = false },
            debuffIndicators = { enabled = true, size = 14 },
            healPrediction = { enabled = true },
            raidTarget = { enabled = true, size = 18 },
            castBar = { enabled = true, height = 8 },
        },
        party = {
            enabled = true,
            hideInRaid = true,
            container = {
                scale = 1.5,
                spacing = 7,
                growthDirection = "DOWN",
            },
            frame = {
                width = 183,
                height = 24,
                showBackground = false,
                showBorder = false,
                autoSize = true,
            },
            healthBar = {
                enabled = true,
                height = 18,
                texture = "Blizzard Character Skills Bar",
                colorMode = "class",
            },
            powerBar = {
                enabled = true,
                height = 9,
            },
            healthText = {
                enabled = true,
                format = "percent",
                fontSize = 10,
                colorByHealth = true,
            },
            nameText = {
                enabled = true,
                fontSize = 10,
                colorMode = "white",
            },
            debuffIndicators = {
                enabled = true,
                style = "both",
                size = 24,
                position = "CENTER",
            },
            defensiveIcon = {
                enabled = true,
                size = 28,
                showDuration = true,
            },
            dispelOverlay = {
                enabled = true,
                showBorder = true,
                showPulse = true,
            },
            healPrediction = { enabled = true },
            rangeFade = { enabled = true, outOfRangeAlpha = 0.4 },
            roleIcon = { enabled = true, size = 16 },
            targetHighlight = { enabled = true, style = "border", thickness = 2 },
            sorting = {
                enabled = true,
                sortByRole = true,
                sortAlphabetically = true,
            },
        },
        raid = {
            enabled = true,
            sizeThreshold = 20,
            small = {
                container = { scale = 1.05 },
                frame = {
                    width = 95,
                    height = 31,
                    showBackground = false,
                    showBorder = true,
                    borderSize = 2,
                },
                healthBar = {
                    height = 26,
                    colorMode = "class",
                },
                powerBar = { enabled = false },
                healthText = { enabled = false },
                nameText = {
                    enabled = true,
                    fontSize = 14,
                    colorMode = "white",
                    maxLength = 8,
                },
                layout = {
                    mode = "GROUP_COLUMNS",
                    groupsPerRow = 1,
                    groupsPerColumn = 4,
                    groupGrowthDirection = "DOWN",
                    memberGrowth = "DOWN",
                    spacing = 2,
                },
                debuffIndicators = {
                    enabled = true,
                    style = "icons",
                    size = 10,
                },
                defensiveIcon = {
                    enabled = true,
                    size = 20,
                },
                dispelOverlay = { enabled = true },
                healPrediction = { enabled = true },
                rangeFade = { enabled = true, outOfRangeAlpha = 0.4 },
                roleIcon = { enabled = true, size = 12 },
                raidTarget = { enabled = true, size = 14 },
                sorting = { enabled = true, sortByRole = true, sortByGroup = true },
            },
            large = {
                container = { scale = 0.9 },
                frame = {
                    width = 76,
                    height = 30,
                    showBackground = true,
                    showBorder = true,
                    borderSize = 1,
                },
                healthBar = {
                    height = 20,
                    colorMode = "class",
                },
                powerBar = { enabled = true, height = 4 },
                healthText = { enabled = false },
                nameText = {
                    enabled = true,
                    fontSize = 9,
                    colorMode = "class",
                    maxLength = 6,
                },
                layout = {
                    mode = "GRID",
                    membersPerRow = 5,
                    groupsPerRow = 1,
                    groupsPerColumn = 3,
                    groupGrowthDirection = "RIGHT",
                    growthDirection = "DOWN",
                    groupSpacing = 4,
                    spacing = 1,
                },
                debuffIndicators = {
                    enabled = true,
                    style = "icons",
                    size = 18,
                },
                defensiveIcon = {
                    enabled = true,
                    size = 18,
                },
                dispelOverlay = { enabled = true },
                healPrediction = { enabled = true },
                rangeFade = { enabled = true, outOfRangeAlpha = 0.4 },
                roleIcon = { enabled = true, size = 10 },
                raidTarget = { enabled = true, size = 12 },
                sorting = { enabled = true, sortByRole = true, sortByGroup = true },
            },
        },
        boss = {
            enabled = true,
            maxBosses = 5,
            container = { scale = 1.0 },
            layout = { direction = "DOWN", spacing = 2 },
            frame = {
                width = 180,
                height = 50,
                showBackground = true,
                showBorder = true,
                borderColor = {0.5, 0.1, 0.1, 1},
            },
            healthBar = {
                height = 36,
                colorMode = "custom",
                customColor = {0.8, 0.2, 0.2, 1},
            },
            powerBar = { enabled = true, height = 8 },
            healthText = { enabled = true, format = "percent", fontSize = 11 },
            nameText = { enabled = true, fontSize = 12, colorMode = "custom", customColor = {1, 0.8, 0.2, 1} },
            raidTarget = { enabled = true, size = 20, position = "LEFT" },
            castBar = { enabled = true, height = 10 },
        },
        tanks = {
            enabled = false,
        },
    },
    
    -- ========================================
    -- GENERAL PRESETS
    -- ========================================
    
    ["Modern"] = {
        -- Clean, balanced design for all frames
        general = {
            smoothBars = true,
            dispelColors = true,
            font = "Friz Quadrata TT",
        },
        player = {
            enabled = true,
            frame = {
                width = 220,
                height = 44,
                scale = 1.0,
                showBackground = true,
                bgColor = { 0.05, 0.05, 0.05, 0.9 },
                showBorder = true,
                borderColor = { 0, 0, 0, 1 },
                borderSize = 1,
                padding = 2,
                barSpacing = 2,
            },
            healthBar = {
                enabled = true,
                height = 26,
                texture = "Blizzard",
                colorMode = "class",
            },
            powerBar = {
                enabled = true,
                height = 10,
                texture = "Blizzard",
                colorMode = "power",
            },
            healthText = {
                enabled = true,
                format = "percent",
                fontSize = 11,
                fontOutline = "OUTLINE",
                hAlign = "RIGHT",
            },
            nameText = {
                enabled = true,
                fontSize = 11,
                fontOutline = "OUTLINE",
                colorMode = "class",
                hAlign = "LEFT",
            },
            portrait = {
                enabled = false,
            },
        },
        target = {
            enabled = true,
            frame = {
                width = 220,
                height = 44,
                scale = 1.0,
                showBackground = true,
                bgColor = { 0.05, 0.05, 0.05, 0.9 },
                showBorder = true,
                borderColor = { 0, 0, 0, 1 },
                borderSize = 1,
                padding = 2,
                barSpacing = 2,
            },
            healthBar = {
                enabled = true,
                height = 26,
                texture = "Blizzard",
                colorMode = "class",
            },
            powerBar = {
                enabled = true,
                height = 10,
                texture = "Blizzard",
                colorMode = "power",
            },
            healthText = {
                enabled = true,
                format = "percent",
                fontSize = 11,
                fontOutline = "OUTLINE",
                hAlign = "RIGHT",
            },
            nameText = {
                enabled = true,
                fontSize = 11,
                fontOutline = "OUTLINE",
                colorMode = "class",
                hAlign = "LEFT",
            },
        },
        focus = {
            enabled = true,
            frame = {
                width = 180,
                height = 36,
                scale = 1.0,
            },
            healthBar = {
                enabled = true,
                height = 22,
                colorMode = "class",
            },
            powerBar = {
                enabled = true,
                height = 8,
            },
        },
        targettarget = {
            enabled = true,
            frame = {
                width = 120,
                height = 28,
                scale = 1.0,
            },
            healthBar = {
                enabled = true,
                height = 18,
            },
            powerBar = {
                enabled = false,
            },
        },
        pet = {
            enabled = true,
            frame = {
                width = 120,
                height = 28,
                scale = 1.0,
            },
            healthBar = {
                enabled = true,
                height = 18,
            },
            powerBar = {
                enabled = true,
                height = 6,
            },
        },
        party = {
            enabled = false,  -- Opt-in for group frames
        },
        raid = {
            enabled = false,
        },
    },
    
    ["Minimal"] = {
        -- Compact frames, essentials only
        general = {
            smoothBars = true,
            dispelColors = true,
        },
        player = {
            enabled = true,
            frame = {
                width = 160,
                height = 32,
                scale = 1.0,
                showBackground = true,
                bgColor = { 0.05, 0.05, 0.05, 0.85 },
                showBorder = false,
                padding = 1,
                barSpacing = 1,
            },
            healthBar = {
                enabled = true,
                height = 20,
                texture = "Blizzard",
                colorMode = "class",
            },
            powerBar = {
                enabled = true,
                height = 6,
            },
            healthText = {
                enabled = true,
                format = "percent",
                fontSize = 10,
            },
            nameText = {
                enabled = false,
            },
            portrait = {
                enabled = false,
            },
        },
        target = {
            enabled = true,
            frame = {
                width = 160,
                height = 32,
                scale = 1.0,
                showBackground = true,
                showBorder = false,
            },
            healthBar = {
                enabled = true,
                height = 20,
                colorMode = "class",
            },
            powerBar = {
                enabled = true,
                height = 6,
            },
            healthText = {
                enabled = true,
                format = "percent",
                fontSize = 10,
            },
            nameText = {
                enabled = true,
                fontSize = 10,
            },
        },
        focus = {
            enabled = false,
        },
        targettarget = {
            enabled = false,
        },
        pet = {
            enabled = true,
            frame = {
                width = 100,
                height = 20,
            },
            healthBar = {
                enabled = true,
                height = 14,
            },
            powerBar = {
                enabled = false,
            },
        },
        party = {
            enabled = false,
        },
        raid = {
            enabled = false,
        },
    },
    
    ["Large"] = {
        -- Maximum visibility and readability
        general = {
            smoothBars = true,
            dispelColors = true,
        },
        player = {
            enabled = true,
            frame = {
                width = 300,
                height = 60,
                scale = 1.0,
                showBackground = true,
                bgColor = { 0.03, 0.03, 0.03, 0.95 },
                showBorder = true,
                borderSize = 2,
                padding = 3,
                barSpacing = 3,
            },
            healthBar = {
                enabled = true,
                height = 36,
                texture = "Blizzard Raid Bar",
                colorMode = "class",
            },
            powerBar = {
                enabled = true,
                height = 14,
            },
            healthText = {
                enabled = true,
                format = "current_percent",
                fontSize = 14,
                fontOutline = "OUTLINE",
            },
            nameText = {
                enabled = true,
                fontSize = 14,
                colorMode = "class",
            },
            portrait = {
                enabled = true,
                mode = "2d",
                size = 60,
                position = "left",
                outside = true,
            },
        },
        target = {
            enabled = true,
            frame = {
                width = 300,
                height = 60,
                scale = 1.0,
                showBackground = true,
                showBorder = true,
                borderSize = 2,
            },
            healthBar = {
                enabled = true,
                height = 36,
                colorMode = "class",
            },
            powerBar = {
                enabled = true,
                height = 14,
            },
            healthText = {
                enabled = true,
                format = "current_percent",
                fontSize = 14,
            },
            nameText = {
                enabled = true,
                fontSize = 14,
            },
            portrait = {
                enabled = true,
                mode = "2d",
                size = 60,
                position = "left",
                outside = true,
            },
        },
        focus = {
            enabled = true,
            frame = {
                width = 240,
                height = 48,
            },
            healthBar = {
                enabled = true,
                height = 28,
            },
            powerBar = {
                enabled = true,
                height = 12,
            },
            healthText = {
                enabled = true,
                fontSize = 12,
            },
            nameText = {
                enabled = true,
                fontSize = 12,
            },
        },
        targettarget = {
            enabled = true,
            frame = {
                width = 160,
                height = 36,
            },
        },
        pet = {
            enabled = true,
            frame = {
                width = 160,
                height = 36,
            },
        },
        party = {
            enabled = false,
        },
        raid = {
            enabled = false,
        },
    },
    
    ["Disabled"] = {
        -- All frames disabled
        player = { enabled = false },
        target = { enabled = false },
        focus = { enabled = false },
        targettarget = { enabled = false },
        pet = { enabled = false },
        party = { enabled = false },
        raid = { enabled = false },
        boss = { enabled = false },
        tanks = { enabled = false },
    },
    
    -- ========================================
    -- ROLE PRESETS
    -- ========================================
    
    ["Tank"] = {
        -- Emphasis on self health, threat awareness
        general = {
            smoothBars = true,
            dispelColors = true,
        },
        player = {
            enabled = true,
            frame = {
                width = 260,
                height = 50,
                scale = 1.0,
                showBackground = true,
                bgColor = { 0.03, 0.03, 0.03, 0.95 },
                showBorder = true,
                borderSize = 2,
            },
            healthBar = {
                enabled = true,
                height = 32,
                colorMode = "class",
            },
            powerBar = {
                enabled = true,
                height = 10,
            },
            healthText = {
                enabled = true,
                format = "current_percent",
                fontSize = 13,
                colorByHealth = true,
            },
            nameText = {
                enabled = true,
                fontSize = 11,
            },
        },
        target = {
            enabled = true,
            frame = {
                width = 240,
                height = 44,
            },
            healthBar = {
                enabled = true,
                height = 28,
                colorMode = "reaction",
            },
            healthText = {
                enabled = true,
                format = "percent",
                fontSize = 12,
            },
            nameText = {
                enabled = true,
                fontSize = 11,
            },
        },
        focus = {
            enabled = true,
            frame = {
                width = 180,
                height = 36,
            },
        },
        targettarget = {
            enabled = true,  -- Important for tanks to see who boss is targeting
            frame = {
                width = 140,
                height = 32,
            },
        },
        party = {
            enabled = true,  -- Tanks need to see party health
            frame = {
                width = 160,
                height = 36,
            },
            healthBar = {
                enabled = true,
                height = 24,
                colorMode = "class",
            },
        },
    },
    
    ["Healer"] = {
        -- Health deficit focus, larger group frames
        general = {
            smoothBars = true,
            dispelColors = true,
        },
        player = {
            enabled = true,
            frame = {
                width = 200,
                height = 40,
            },
            healthBar = {
                enabled = true,
                height = 24,
                colorMode = "class",
            },
            powerBar = {
                enabled = true,
                height = 10,
            },
            healthText = {
                enabled = true,
                format = "current",
                fontSize = 11,
            },
        },
        target = {
            enabled = true,
            frame = {
                width = 200,
                height = 40,
            },
            healthBar = {
                enabled = true,
                height = 24,
                colorMode = "class",
            },
            healthText = {
                enabled = true,
                format = "deficit",  -- Show missing health
                fontSize = 11,
            },
        },
        focus = {
            enabled = true,  -- Healers often focus heal targets
            frame = {
                width = 180,
                height = 36,
            },
        },
        targettarget = {
            enabled = false,  -- Less important for healers
        },
        party = {
            enabled = true,
            container = {
                growDirection = "DOWN",
                spacing = 2,
            },
            frame = {
                width = 180,
                height = 44,
            },
            healthBar = {
                enabled = true,
                height = 28,
                colorMode = "class",
            },
            healthText = {
                enabled = true,
                format = "deficit",
                fontSize = 11,
            },
        },
        raid = {
            enabled = true,
        },
    },
    
    ["DPS"] = {
        -- Target-focused, streamlined self info
        general = {
            smoothBars = true,
            dispelColors = true,
        },
        player = {
            enabled = true,
            frame = {
                width = 180,
                height = 36,
            },
            healthBar = {
                enabled = true,
                height = 22,
                colorMode = "class",
            },
            powerBar = {
                enabled = true,
                height = 8,
            },
            healthText = {
                enabled = true,
                format = "percent",
                fontSize = 10,
            },
            nameText = {
                enabled = false,  -- DPS knows their own name
            },
        },
        target = {
            enabled = true,
            frame = {
                width = 240,
                height = 48,
                scale = 1.0,
            },
            healthBar = {
                enabled = true,
                height = 30,
                colorMode = "class",
            },
            powerBar = {
                enabled = true,
                height = 10,
            },
            healthText = {
                enabled = true,
                format = "current_percent",
                fontSize = 12,
            },
            nameText = {
                enabled = true,
                fontSize = 12,
            },
        },
        focus = {
            enabled = true,
            frame = {
                width = 160,
                height = 32,
            },
        },
        targettarget = {
            enabled = true,
            frame = {
                width = 120,
                height = 28,
            },
        },
        party = {
            enabled = false,  -- DPS typically don't need party frames
        },
        raid = {
            enabled = false,
        },
    },
}

-- ============================================================================
-- MASTER PRESETS (UI THEMES)
-- Complete UI configurations: module presets + positions + enable states
-- These provide one-click transformation of the entire UI
--
-- NOTE: Role-based presets are "Coming Soon" - community profiles being collected
-- Style-based presets are functional placeholders
-- ============================================================================

TweaksUI.MasterPresets = {
    -- ========================================
    -- ROLE-BASED MASTER PRESETS (Coming Soon)
    -- Community profiles being collected via Discord
    -- ========================================
    
    ["Tank"] = {
        description = "Coming Soon - Submit your profile on Discord!",
        icon = "Interface\\Icons\\Ability_Defend",  -- Shield icon
        comingSoon = true,
        modulePresets = {},
        moduleEnabled = {},
        layout = {
            elements = {},
            attachments = {},
        },
    },
    
    ["Healer"] = {
        description = "Coming Soon - Submit your profile on Discord!",
        icon = "Interface\\Icons\\Spell_Holy_GreaterHeal",  -- Healing icon
        comingSoon = true,
        modulePresets = {},
        moduleEnabled = {},
        layout = {
            elements = {},
            attachments = {},
        },
    },
    
    ["Melee DPS"] = {
        description = "Coming Soon - Submit your profile on Discord!",
        icon = "Interface\\Icons\\Ability_DualWield",  -- Dual swords icon
        comingSoon = true,
        modulePresets = {},
        moduleEnabled = {},
        layout = {
            elements = {},
            attachments = {},
        },
    },
    
    ["Ranged DPS"] = {
        description = "Coming Soon - Submit your profile on Discord!",
        icon = "Interface\\Icons\\Spell_Fire_Fireball02",  -- Fireball icon
        comingSoon = true,
        modulePresets = {},
        moduleEnabled = {},
        layout = {
            elements = {},
            attachments = {},
        },
    },
    
    -- ========================================
    -- STYLE-BASED MASTER PRESETS (Coming Soon)
    -- ========================================
    
    ["Modern"] = {
        description = "Coming Soon - Clean, balanced UI for all roles",
        icon = "Interface\\Icons\\INV_Gizmo_02",  -- Modern gear icon
        comingSoon = true,
        modulePresets = {},
        moduleEnabled = {},
        layout = {
            elements = {},
            attachments = {},
        },
    },
    
    ["Minimal"] = {
        description = "Coming Soon - Maximum screen space, essentials only",
        icon = "Interface\\Icons\\Spell_Nature_Invisibilty",  -- Invisibility icon
        comingSoon = true,
        modulePresets = {},
        moduleEnabled = {},
        layout = {
            elements = {},
            attachments = {},
        },
    },
    
    ["Large"] = {
        description = "Coming Soon - Accessibility focused, larger elements",
        icon = "Interface\\Icons\\INV_Misc_Eye_02",  -- Eye icon
        comingSoon = true,
        modulePresets = {},
        moduleEnabled = {},
        layout = {
            elements = {},
            attachments = {},
        },
    },
    
    -- ========================================
    -- BASIC MASTER PRESET (Author's recommended)
    -- ========================================
    
    ["Basic"] = {
        description = "Coming Soon - Author's recommended starting setup",
        icon = "Interface\\Icons\\INV_Misc_Gear_01",  -- Gear icon
        comingSoon = true,
        modulePresets = {},
        moduleEnabled = {},
        layout = {
            elements = {},
            attachments = {},
        },
    },
    
    ["Disabled"] = {
        description = "Disable all TweaksUI customizations",
        icon = "Interface\\Icons\\Spell_ChargeNegative",  -- X icon
        modulePresets = {
            cooldowns = "Disabled",
            castBars = "Disabled",
            nameplates = "Disabled",
            unitFrames = "Disabled",
            personalResources = "Disabled",
            actionBars = "Disabled",
        },
        moduleEnabled = {
            cooldowns = false,
            castBars = false,
            chat = false,
            nameplates = false,
            unitFrames = false,
            personalResources = false,
            actionBars = false,
        },
        layout = {
            elements = {},
            attachments = {},
        },
    },
}

-- ============================================================================
-- MASTER PRESET APPLICATION
-- ============================================================================

-- Reference resolution for presets (presets are designed for this resolution)
local PRESET_REFERENCE_WIDTH = 1920
local PRESET_REFERENCE_HEIGHT = 1080
local PRESET_REFERENCE_UISCALE = 1.0

-- Calculate scale adjustment for preset application
local function CalculatePresetScaleAdjustment()
    local targetWidth, targetHeight = GetPhysicalScreenSize()
    local targetUIScale = UIParent:GetEffectiveScale()
    
    -- Use height as the primary scaling reference
    local sourceEffective = PRESET_REFERENCE_HEIGHT / PRESET_REFERENCE_UISCALE
    local targetEffective = targetHeight / targetUIScale
    
    -- Scale factor: how much bigger/smaller the target screen is
    local scaleAdjustment = targetEffective / sourceEffective
    
    -- Clamp to reasonable range (0.5x to 2x)
    scaleAdjustment = math.max(0.5, math.min(2.0, scaleAdjustment))
    
    -- Only adjust if difference is significant (more than 10%)
    if math.abs(scaleAdjustment - 1.0) < 0.1 then
        return 1.0
    end
    
    return scaleAdjustment
end

function TweaksUI:ApplyMasterPreset(presetName)
    local preset = self.MasterPresets[presetName]
    if not preset then
        self:PrintError("Master preset not found: " .. tostring(presetName))
        return false
    end
    
    self:Print("Applying UI preset: " .. presetName)
    
    -- Calculate scale adjustment for current resolution vs preset reference
    local scaleAdjustment = CalculatePresetScaleAdjustment()
    if scaleAdjustment ~= 1.0 then
        self:Print(string.format("Adjusting scales by %.0f%% for your resolution", (scaleAdjustment - 1) * 100))
    end
    
    -- 1. Apply module enable/disable states
    if preset.moduleEnabled and TweaksUI_CharDB and TweaksUI_CharDB.modules then
        for moduleId, enabled in pairs(preset.moduleEnabled) do
            TweaksUI_CharDB.modules[moduleId] = enabled
        end
    end
    
    -- 2. Apply per-module presets with FULL RESET
    -- fullReset = true means reset to defaults first, then apply preset
    -- This ensures the preset is a complete configuration, not a partial merge
    if preset.modulePresets and self.Presets then
        for moduleId, presetNameInner in pairs(preset.modulePresets) do
            -- Check if preset exists for this module
            local modulePresets = self.BuiltInPresets[moduleId]
            if modulePresets and modulePresets[presetNameInner] then
                local success = self.Presets:ApplyPreset(moduleId, presetNameInner, { 
                    skipReload = true,
                    fullReset = true,  -- Reset to defaults before applying
                    scaleAdjustment = scaleAdjustment,  -- Pass scale adjustment
                })
                if success then
                    self:PrintDebug("  Applied " .. moduleId .. " preset: " .. presetNameInner)
                end
            end
        end
    end
    
    -- 3. Apply layout positions (preset uses center-relative, storage uses BOTTOMLEFT)
    if preset.layout and preset.layout.elements then
        if not TweaksUI_CharDB.settings then
            TweaksUI_CharDB.settings = {}
        end
        if not TweaksUI_CharDB.settings.layout then
            TweaksUI_CharDB.settings.layout = {}
        end
        
        -- Convert center-relative positions to BOTTOMLEFT absolute
        -- IMPORTANT: Clear existing positions first
        TweaksUI_CharDB.settings.layout.elements = {}
        
        local CenterToScreen = TweaksUI.CenterToScreen
        local count = 0
        
        for elementId, pos in pairs(preset.layout.elements) do
            if CenterToScreen and pos.x and pos.y then
                -- Convert center-relative to screen absolute
                local absX, absY = CenterToScreen(pos.x, pos.y)
                
                -- Adjust for frame size to get bottom-left corner
                local halfWidth, halfHeight = 50, 25  -- Default estimate
                local element = TweaksUI.Layout and TweaksUI.Layout:GetElement(elementId)
                if element and element.tuiFrame and element.tuiFrame.frame then
                    local frame = element.tuiFrame.frame
                    halfWidth = (frame:GetWidth() or 100) / 2
                    halfHeight = (frame:GetHeight() or 50) / 2
                end
                
                -- Apply scale from preset with resolution adjustment
                local adjustedScale = (pos.scale or 1.0) * scaleAdjustment
                
                -- Store as BOTTOMLEFT absolute
                TweaksUI_CharDB.settings.layout.elements[elementId] = {
                    point = "BOTTOMLEFT",
                    x = absX - halfWidth,
                    y = absY - halfHeight,
                    scale = adjustedScale,
                }
            else
                -- Fallback: assume it's already in the correct format
                TweaksUI_CharDB.settings.layout.elements[elementId] = {
                    point = pos.point or "BOTTOMLEFT",
                    x = pos.x or 0,
                    y = pos.y or 0,
                    scale = (pos.scale or 1.0) * scaleAdjustment,
                }
            end
            count = count + 1
            -- Debug: Print each position being saved
            self:PrintDebug("  Layout: " .. elementId .. " -> x=" .. tostring(pos.x) .. ", y=" .. tostring(pos.y))
        end
        
        self:Print("Saved " .. count .. " element positions")
        
        -- Store attachments (snap/lock relationships)
        TweaksUI_CharDB.settings.layout.attachments = preset.layout.attachments or {}
    end
    
    -- 4. Mark that we need a reload
    self:Print("|cff00ff00UI preset applied!|r Reload required for changes to take effect.")
    StaticPopup_Show("TWEAKSUI_RELOAD_PROMPT")
    
    return true
end

-- Get list of master presets for UI
function TweaksUI:GetMasterPresetList()
    local list = {}
    for name, data in pairs(self.MasterPresets) do
        table.insert(list, {
            name = name,
            description = data.description,
            icon = data.icon,
            iconCoords = data.iconCoords,
            comingSoon = data.comingSoon,
        })
    end
    -- Sort: roles first (Tank, Healer, DPS), then Basic, then other styles, Disabled last
    table.sort(list, function(a, b)
        local roleOrder = { 
            ["Tank"] = 1, ["Healer"] = 2, ["Melee DPS"] = 3, ["Ranged DPS"] = 4,
            ["Basic"] = 5,  -- First style preset
            ["Disabled"] = 100,  -- Always last
        }
        local aOrder = roleOrder[a.name] or 10
        local bOrder = roleOrder[b.name] or 10
        if aOrder ~= bOrder then
            return aOrder < bOrder
        end
        return a.name < b.name
    end)
    return list
end

-- ============================================================================
-- ROLE TEMPLATES (Legacy - kept for compatibility)
-- Maps role -> per-module preset names
-- ============================================================================

TweaksUI.RoleTemplates = {
    tank = {
        cooldowns = "Tank",
        castBars = "Tank",
        chat = "Raid Leader",  -- Tanks often lead groups
        nameplates = "Tank",
        unitFrames = "Tank",
        personalResources = "Tank",
    },
    healer = {
        cooldowns = "Healer",
        castBars = "Healer",
        chat = "Raid Leader",  -- Healers need to see callouts
        nameplates = "Healer",
        unitFrames = "Healer",
        personalResources = "Healer",
    },
    melee = {
        cooldowns = "Melee DPS",
        castBars = "Melee DPS",
        chat = "Combat Focus",  -- DPS focused on combat, not chat
        nameplates = "Melee DPS",
        unitFrames = "DPS",
        personalResources = "DPS",
    },
    ranged = {
        cooldowns = "Ranged DPS",
        castBars = "Ranged DPS",
        chat = "Combat Focus",  -- DPS focused on combat, not chat
        nameplates = "Ranged DPS",
        unitFrames = "DPS",
        personalResources = "DPS",
    },
}

-- ============================================================================
-- MODULE DEFAULTS REGISTRY
-- Store references to each module's defaults for delta encoding
-- These get populated when modules register with the Presets system
-- ============================================================================

TweaksUI.ModuleDefaults = TweaksUI.ModuleDefaults or {}

-- ============================================================================
-- INITIALIZATION
-- Called after all modules are loaded to register them with the preset system
-- ============================================================================

function TweaksUI:RegisterModulePresets()
    local Presets = self.Presets
    if not Presets then return end
    
    -- Cooldowns
    if TweaksUI.MODULE_IDS and TweaksUI.MODULE_IDS.COOLDOWNS then
        -- Get defaults from the Cooldowns module if available
        local cooldownsModule = self.ModuleManager and self.ModuleManager:GetModule(TweaksUI.MODULE_IDS.COOLDOWNS)
        local defaults = {}
        if cooldownsModule and cooldownsModule.GetDefaults then
            defaults = cooldownsModule:GetDefaults()
            -- Debug: verify defaults were retrieved
            if TweaksUI.debugMode then
                local count = 0
                for _ in pairs(defaults) do count = count + 1 end
                TweaksUI:PrintDebug("RegisterModulePresets: cooldowns got " .. count .. " default keys")
                if defaults.essential then
                    TweaksUI:PrintDebug("  essential.columns=" .. tostring(defaults.essential.columns))
                end
            end
        else
            if TweaksUI.debugMode then
                TweaksUI:PrintDebug("RegisterModulePresets: cooldowns module not available or no GetDefaults")
            end
        end
        
        Presets:RegisterModule("cooldowns", {
            defaults = defaults,
            scalableKeys = TweaksUI.ModuleScalableKeys.cooldowns,
            canHotApply = true,  -- Can hot-apply with refresh function
            refreshFunc = function()
                local module = TweaksUI.ModuleManager and TweaksUI.ModuleManager:GetModule(TweaksUI.MODULE_IDS.COOLDOWNS)
                if module and module.RefreshFromDatabase then
                    return module:RefreshFromDatabase()
                end
                return false
            end,
        })
    end
    
    -- Cast Bars
    if TweaksUI.MODULE_IDS and TweaksUI.MODULE_IDS.CAST_BARS then
        Presets:RegisterModule("castBars", {
            defaults = {},  -- Will be populated from module
            scalableKeys = TweaksUI.ModuleScalableKeys.castBars,
            canHotApply = true,
            refreshFunc = function()
                local module = TweaksUI.ModuleManager and TweaksUI.ModuleManager:GetModule(TweaksUI.MODULE_IDS.CAST_BARS)
                if module and module.RefreshAllCastBars then
                    module:RefreshAllCastBars()
                end
            end,
        })
    end
    
    -- Chat
    if TweaksUI.MODULE_IDS and TweaksUI.MODULE_IDS.CHAT then
        Presets:RegisterModule("chat", {
            defaults = {},
            scalableKeys = TweaksUI.ModuleScalableKeys.chat,
            canHotApply = false,  -- Chat needs reload for many settings
        })
    end
    
    -- Nameplates
    if TweaksUI.MODULE_IDS and TweaksUI.MODULE_IDS.NAMEPLATES then
        local nameplatesModule = TweaksUI.Nameplates
        local defaults = {}
        if nameplatesModule and nameplatesModule.Defaults then
            defaults = nameplatesModule.Defaults.SETTINGS or {}
        end
        
        Presets:RegisterModule("nameplates", {
            defaults = defaults,
            scalableKeys = TweaksUI.ModuleScalableKeys.nameplates,
            canHotApply = true,
            refreshFunc = function()
                if TweaksUI.Nameplates and TweaksUI.Nameplates.RefreshAllNameplates then
                    TweaksUI.Nameplates:RefreshAllNameplates()
                end
            end,
        })
    end
    
    -- Personal Resources (formerly Resource Bars)
    if TweaksUI.MODULE_IDS and TweaksUI.MODULE_IDS.PERSONAL_RESOURCES then
        Presets:RegisterModule("personalResources", {
            defaults = {},
            scalableKeys = TweaksUI.ModuleScalableKeys.personalResources,
            canHotApply = true,
            refreshFunc = function()
                local module = TweaksUI.ModuleManager and TweaksUI.ModuleManager:GetModule(TweaksUI.MODULE_IDS.PERSONAL_RESOURCES)
                if module and module.RefreshFromDatabase then
                    return module:RefreshFromDatabase()
                end
                return false
            end,
        })
    end
    
    -- Unit Frames
    if TweaksUI.MODULE_IDS and TweaksUI.MODULE_IDS.UNIT_FRAMES then
        Presets:RegisterModule("unitFrames", {
            defaults = {},
            scalableKeys = TweaksUI.ModuleScalableKeys.unitFrames,
            canHotApply = false,  -- UnitFrames needs reload for most settings
        })
    end
    
    -- Action Bars
    if TweaksUI.MODULE_IDS and TweaksUI.MODULE_IDS.ACTION_BARS then
        local ActionBars = TweaksUI.ModuleManager and TweaksUI.ModuleManager:GetModule("ActionBars")
        Presets:RegisterModule("actionBars", {
            defaults = {},
            scalableKeys = TweaksUI.ModuleScalableKeys.actionBars,
            canHotApply = true,
            refreshFunc = function()
                if ActionBars and ActionBars.RefreshFromDatabase then
                    ActionBars:RefreshFromDatabase()
                end
            end,
        })
    end
    
    TweaksUI:PrintDebug("Module presets registered")
end
