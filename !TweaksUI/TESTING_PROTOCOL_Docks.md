# TweaksUI Dynamic Docks - Complete Testing Protocol

**Version:** 2.0.0-Docks  
**Date:** January 17, 2026  
**Tester:** _______________

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Basic Dock Creation & Enable](#2-basic-dock-creation--enable)
3. [Icon Assignment](#3-icon-assignment)
4. [Dock Layout Settings](#4-dock-layout-settings)
5. [Dock Appearance Settings](#5-dock-appearance-settings)
6. [Visibility Conditions](#6-visibility-conditions)
7. [Layout Mode Integration](#7-layout-mode-integration)
8. [Per-Icon Visual Overrides](#8-per-icon-visual-overrides)
9. [Aspect Ratio (Zoom Test)](#9-aspect-ratio-zoom-test)
10. [Multi-Dock Scenarios](#10-multi-dock-scenarios)
11. [Profile Integration](#11-profile-integration)
12. [Performance & Responsiveness](#12-performance--responsiveness)
13. [Edge Cases & Error Handling](#13-edge-cases--error-handling)
14. [Regression Testing](#14-regression-testing)

---

## 1. Prerequisites

### 1.1 Initial Setup
- [ ] Fresh install of TweaksUI 2.0.0-Docks
- [ ] Delete `TweaksUI_DB` and `TweaksUI_CharDB` from SavedVariables (optional for clean test)
- [ ] `/reload` after installation

### 1.2 Required Game State
- [ ] Character at max level (or high enough to have cooldowns)
- [ ] Multiple abilities with cooldowns available
- [ ] Access to a target dummy or safe combat area

### 1.3 Enable Debug Mode (Optional)
```
/tui debug
```
Watch for debug messages in chat during testing.

### 1.4 Verify Addon Loaded
- [ ] Type `/tui` - Settings hub should appear
- [ ] Click "Cooldowns" button - Cooldowns panel should appear
- [ ] Verify "Docks" button is visible in the Cooldowns panel

**Result:** ☐ Pass ☐ Fail  
**Notes:** _________________________________

---

## 2. Basic Dock Creation & Enable

### 2.1 Open Docks Panel
1. `/tui` → Cooldowns → Click "Docks" button
2. [ ] Docks settings panel appears to the right of hub

### 2.2 Enable Dock 1
1. Check "Enable Dock 1" checkbox
2. [ ] Dock 1 section expands to show settings
3. [ ] A dock container frame should appear on screen (may be empty)

### 2.3 Dock Name
1. Change dock name from "Dock 1" to "Main CDs"
2. [ ] Name field accepts text input
3. [ ] Name persists after `/reload`

### 2.4 Disable Dock
1. Uncheck "Enable Dock 1"
2. [ ] Dock container disappears from screen
3. [ ] Settings section collapses

### 2.5 Re-enable Dock
1. Check "Enable Dock 1" again
2. [ ] Dock reappears at previous position
3. [ ] Previous name "Main CDs" is retained

**Result:** ☐ Pass ☐ Fail  
**Notes:** _________________________________

---

## 3. Icon Assignment

### 3.1 Setup Per-Icon Highlights
1. Go to Essential Tracker → Per-Icon Settings tab
2. Enable at least 3 icons (slots 1, 2, 3)
3. [ ] Icons appear on screen as highlight frames

### 3.2 Assign Icon to Dock via Dropdown
1. For Slot 1, find "Dock Assignment" dropdown
2. Select "Dock 1" (or "Main CDs" if renamed)
3. [ ] Icon immediately moves into the dock container
4. [ ] Icon is no longer at its original position

### 3.3 Assign Multiple Icons
1. Assign Slot 2 to Dock 1
2. Assign Slot 3 to Dock 1
3. [ ] All three icons appear in dock, arranged in order
4. [ ] Dock container resizes to fit all icons

### 3.4 Unassign Icon from Dock
1. For Slot 2, change dropdown to "None"
2. [ ] Slot 2 icon returns to its original position
3. [ ] Remaining icons in dock re-layout (no gap)

### 3.5 Reassign to Different Dock
1. Enable Dock 2
2. Change Slot 1 assignment from Dock 1 to Dock 2
3. [ ] Icon moves from Dock 1 to Dock 2
4. [ ] Dock 1 re-layouts remaining icons

### 3.6 Assignment Persistence
1. `/reload`
2. [ ] All dock assignments restored correctly
3. [ ] Icons appear in correct docks

**Result:** ☐ Pass ☐ Fail  
**Notes:** _________________________________

---

## 4. Dock Layout Settings

### 4.1 Orientation
1. With 3+ icons in Dock 1
2. Change Orientation to "Horizontal"
3. [ ] Icons arrange left-to-right in a single row
4. Change Orientation to "Vertical"
5. [ ] Icons arrange top-to-bottom in a single column

### 4.2 Spacing
1. Set Spacing to 0
2. [ ] Icons touch with no gap
3. Set Spacing to 10
4. [ ] Visible gap between icons
5. Set Spacing to 20
6. [ ] Larger gap between icons

### 4.3 Icon Size Override
1. In Visual Override section, adjust Icon Size slider
2. Set size to 48
3. [ ] All icons in dock resize to 48x48
4. Set size to 24
5. [ ] All icons shrink to 24x24
6. Set size to 36 (default)
7. [ ] Icons return to normal size

### 4.4 Alignment/Justify (Horizontal Mode)
1. Set Orientation to "Horizontal"
2. With 2 icons in dock
3. Set Alignment to "Left"
4. [ ] Icons align to left of dock container
5. Set Alignment to "Center"
6. [ ] Icons centered horizontally
7. Set Alignment to "Right"
8. [ ] Icons align to right of dock container

### 4.5 Alignment/Justify (Vertical Mode)
1. Set Orientation to "Vertical"
2. With 2 icons in dock
3. Set Alignment to "Top"
4. [ ] Icons align to top of dock container
5. Set Alignment to "Middle"
6. [ ] Icons centered vertically
7. Set Alignment to "Bottom"
8. [ ] Icons align to bottom of dock container

### 4.6 Layout Persistence
1. Configure orientation, spacing, alignment
2. `/reload`
3. [ ] All layout settings preserved

**Result:** ☐ Pass ☐ Fail  
**Notes:** _________________________________

---

## 5. Dock Appearance Settings

### 5.1 Background
1. Enable "Show Background"
2. [ ] Dark background appears behind icons
3. Adjust Background Opacity slider
4. [ ] Background transparency changes in real-time
5. Click Background Color swatch
6. [ ] Color picker opens
7. Select a color (e.g., dark blue)
8. [ ] Background color changes

### 5.2 Border
1. Enable "Show Border"
2. [ ] Border appears around dock
3. Adjust Border Opacity
4. [ ] Border transparency changes
5. Click Border Color swatch
6. [ ] Border color can be changed
7. Adjust Border Size (if available)
8. [ ] Border thickness changes

### 5.3 Disable Appearance
1. Disable "Show Background"
2. [ ] Background disappears, icons float
3. Disable "Show Border"
4. [ ] Border disappears

### 5.4 Appearance Persistence
1. Configure custom background/border
2. `/reload`
3. [ ] Appearance settings restored

**Result:** ☐ Pass ☐ Fail  
**Notes:** _________________________________

---

## 6. Visibility Conditions

### 6.1 Always Show
1. Check "Always Show"
2. [ ] Dock visible regardless of other conditions
3. Uncheck "Always Show"
4. [ ] Dock visibility now depends on other conditions

### 6.2 Combat Visibility
1. Uncheck all conditions except "Show in Combat"
2. Out of combat:
3. [ ] Dock is hidden
4. Enter combat (attack dummy):
5. [ ] Dock appears
6. Leave combat:
7. [ ] Dock hides after combat ends

### 6.3 Out of Combat
1. Check only "Show Out of Combat"
2. Out of combat:
3. [ ] Dock is visible
4. Enter combat:
5. [ ] Dock hides
6. Leave combat:
7. [ ] Dock reappears

### 6.4 Group Visibility
1. Check only "Show in Party"
2. Solo (no group):
3. [ ] Dock hidden
4. Join a party (or use LFG):
5. [ ] Dock appears
6. Leave party:
7. [ ] Dock hides

### 6.5 Instance Visibility
1. Check only "Show in Dungeon"
2. Outside dungeon:
3. [ ] Dock hidden
4. Enter a dungeon:
5. [ ] Dock appears
6. Exit dungeon:
7. [ ] Dock hides

### 6.6 Target Visibility
1. Check only "Show Has Target"
2. No target:
3. [ ] Dock hidden
4. Target something:
5. [ ] Dock appears
6. Clear target:
7. [ ] Dock hides

### 6.7 Mounted Visibility
1. Check only "Show Mounted"
2. Unmounted:
3. [ ] Dock hidden
4. Mount up:
5. [ ] Dock appears
6. Dismount:
7. [ ] Dock hides

### 6.8 Multiple Conditions (OR Logic)
1. Check "Show in Combat" AND "Show Has Target"
2. Out of combat, no target:
3. [ ] Dock hidden
4. Target something (still out of combat):
5. [ ] Dock appears (target condition met)
6. Clear target, enter combat:
7. [ ] Dock appears (combat condition met)

**Result:** ☐ Pass ☐ Fail  
**Notes:** _________________________________

---

## 7. Layout Mode Integration

### 7.1 Enter Layout Mode
1. `/tui layout` or click Layout Mode button
2. [ ] Layout overlay appears
3. [ ] All enabled docks become visible (even if visibility conditions aren't met)
4. [ ] Docks show placeholder appearance

### 7.2 Drag Dock Position
1. In Layout Mode, click and drag Dock 1
2. [ ] Dock moves with mouse
3. Release mouse button
4. [ ] Dock stays at new position
5. [ ] Position saved (verify after reload)

### 7.3 Dock Label in Layout Mode
1. In Layout Mode:
2. [ ] Dock shows its name label below/above the container
3. Exit Layout Mode:
4. [ ] Label hides (or based on setting)

### 7.4 Empty Dock Placeholder
1. Remove all icons from Dock 1
2. Enter Layout Mode:
3. [ ] Empty dock still visible with placeholder text
4. [ ] Can still drag empty dock to position it

### 7.5 Exit Layout Mode
1. Click "Lock" or exit Layout Mode
2. [ ] Layout overlay closes
3. [ ] Docks return to normal visibility rules
4. [ ] Positions are saved

### 7.6 Position Persistence
1. Position docks in Layout Mode
2. `/reload`
3. [ ] All docks at saved positions

**Result:** ☐ Pass ☐ Fail  
**Notes:** _________________________________

---

## 8. Per-Icon Visual Overrides

### 8.1 Access Visual Override
1. In Docks panel, expand an icon's settings
2. Find "Visual Override" section
3. [ ] Override options are available

### 8.2 Size Override
1. Enable size override for one icon
2. Set custom size (e.g., 50)
3. [ ] That specific icon is larger than others in dock
4. [ ] Other icons unaffected

### 8.3 Opacity Override
1. Enable opacity override
2. Set to 50%
3. [ ] Icon appears semi-transparent
4. [ ] Other icons at full opacity

### 8.4 Saturation Override
1. Enable saturation override
2. Disable saturation (desaturate)
3. [ ] Icon appears grayscale
4. [ ] Other icons remain colored

### 8.5 Aspect Ratio Override
1. Enable aspect ratio override
2. Set to 16:9 (wide)
3. [ ] Icon frame becomes wide rectangle
4. [ ] Texture zooms/crops (not stretched)
5. Set to 9:16 (tall)
6. [ ] Icon frame becomes tall rectangle
7. [ ] Texture zooms/crops correctly

### 8.6 Override for Active vs Inactive
1. Set different overrides for "Active" state
2. Set different overrides for "Inactive" state
3. Trigger cooldown:
4. [ ] Active state: shows active overrides
5. [ ] On cooldown (inactive): shows inactive overrides
6. [ ] Cooldown ends: returns to active overrides

**Result:** ☐ Pass ☐ Fail  
**Notes:** _________________________________

---

## 9. Aspect Ratio (Zoom Test)

### 9.1 Wide Aspect Ratio
1. Set aspect ratio to 2:1
2. [ ] Frame is twice as wide as tall
3. [ ] Icon texture zooms to fill (crops top/bottom)
4. [ ] No stretching/squishing of icon image

### 9.2 Tall Aspect Ratio
1. Set aspect ratio to 1:2
2. [ ] Frame is twice as tall as wide
3. [ ] Icon texture zooms to fill (crops left/right)
4. [ ] No stretching/squishing of icon image

### 9.3 Standard Ratios
Test each preset:
- [ ] 1:1 (Square) - Normal icon appearance
- [ ] 4:3 - Slight crop top/bottom
- [ ] 3:4 - Slight crop left/right
- [ ] 16:9 - Significant crop top/bottom
- [ ] 9:16 - Significant crop left/right

### 9.4 Custom Aspect Ratio
1. Select "Custom" aspect ratio
2. Enter custom values (e.g., 3:1)
3. [ ] Frame adjusts to custom ratio
4. [ ] Texture zooms correctly

### 9.5 Aspect Ratio in Dock
1. Assign icons with different aspect ratios to same dock
2. [ ] Each icon maintains its individual aspect ratio
3. [ ] Dock layout accommodates different sizes

**Result:** ☐ Pass ☐ Fail  
**Notes:** _________________________________

---

## 10. Multi-Dock Scenarios

### 10.1 Enable All 5 Docks
1. Enable Docks 1-5
2. [ ] All 5 docks appear on screen
3. [ ] Each can be independently configured

### 10.2 Different Layouts Per Dock
1. Dock 1: Horizontal, 4 columns
2. Dock 2: Vertical, 2 rows
3. Dock 3: Horizontal, 1 column (vertical stack)
4. [ ] Each dock maintains its layout setting

### 10.3 Move Icons Between Docks
1. Assign icon to Dock 1
2. Change assignment to Dock 3
3. [ ] Icon moves smoothly
4. [ ] Both docks re-layout correctly

### 10.4 Different Visibility Per Dock
1. Dock 1: Always show
2. Dock 2: Combat only
3. Dock 3: Has target only
4. Test various states:
5. [ ] Each dock follows its own visibility rules

### 10.5 Mixed Tracker Types
1. Assign Essential icons to Dock 1
2. Assign Utility icons to Dock 2
3. Assign Buff icons to Dock 3
4. [ ] All tracker types work with docks
5. [ ] Updates work correctly for each type

**Result:** ☐ Pass ☐ Fail  
**Notes:** _________________________________

---

## 11. Profile Integration

### 11.1 Save Profile with Docks
1. Configure docks with various settings
2. Go to Profiles panel
3. Save as "Dock Test Profile"
4. [ ] Profile saves successfully

### 11.2 Load Profile
1. Change dock settings significantly
2. Load "Dock Test Profile"
3. [ ] All dock settings restored
4. [ ] Dock positions restored
5. [ ] Icon assignments restored

### 11.3 Export/Import Profile
1. Export profile to string
2. [ ] Export includes dock data
3. Reset all settings
4. Import profile from string
5. [ ] Dock settings restored from import

### 11.4 Profile Switch
1. Create two profiles with different dock configs
2. Switch between profiles
3. [ ] Dock settings update immediately
4. [ ] No errors during switch

**Result:** ☐ Pass ☐ Fail  
**Notes:** _________________________________

---

## 12. Performance & Responsiveness

### 12.1 Cooldown Transition Speed
1. Assign 5+ icons to a dock
2. Use abilities to trigger cooldowns
3. [ ] Icons show/hide immediately when cooldown state changes
4. [ ] No noticeable delay (should match TUI:CD speed)

### 12.2 Combat Performance
1. Enter combat with active docks
2. Use abilities rapidly
3. [ ] No FPS drop
4. [ ] No lag in icon updates
5. [ ] No Lua errors in combat

### 12.3 Rapid State Changes
1. Toggle target on/off rapidly
2. [ ] Dock visibility responds quickly
3. [ ] No flickering or stuck states

### 12.4 Many Icons Test
1. Enable 10+ icons across multiple docks
2. [ ] All icons update correctly
3. [ ] Performance remains acceptable

### 12.5 Memory/CPU Check
1. Open Performance panel or use `/tui perf`
2. [ ] No memory leaks over time
3. [ ] CPU usage reasonable

**Result:** ☐ Pass ☐ Fail  
**Notes:** _________________________________

---

## 13. Edge Cases & Error Handling

### 13.1 Assign Before Dock Enabled
1. Disable all docks
2. In Per-Icon settings, try to assign to Dock 1
3. [ ] Either prevented, or dock auto-enables, or clear error handling

### 13.2 Delete Assignment Source
1. Assign icon to dock
2. Disable that icon's highlight
3. [ ] Icon removed from dock gracefully
4. [ ] No errors

### 13.3 Rapid Enable/Disable
1. Rapidly toggle dock enable checkbox
2. [ ] No Lua errors
3. [ ] Final state is correct

### 13.4 Invalid Saved Data
1. Manually corrupt TweaksUI_CharDB.docks (advanced)
2. `/reload`
3. [ ] Addon handles gracefully with defaults

### 13.5 Combat Lockdown
1. Enter combat
2. Try to change dock settings
3. [ ] Changes either queue for after combat or are blocked gracefully
4. [ ] No taint errors

### 13.6 Spec Change
1. Configure docks for one spec
2. Change to different spec
3. [ ] Docks adapt to new spec's abilities
4. [ ] No errors

### 13.7 Zone Change
1. Configure docks
2. Enter/exit instance
3. [ ] Visibility conditions update
4. [ ] No errors during loading screen

**Result:** ☐ Pass ☐ Fail  
**Notes:** _________________________________

---

## 14. Regression Testing

Verify existing functionality still works:

### 14.1 Non-Docked Icons
1. Enable icons but don't assign to any dock
2. [ ] Icons work normally at their positions
3. [ ] Per-icon settings still apply

### 14.2 Essential Tracker (Blizzard Integration)
1. Without docks, verify Essential Tracker still hooks Blizzard's viewer
2. [ ] Icons appear and update correctly

### 14.3 Utility Tracker
1. Verify Utility Tracker works without docks
2. [ ] All functionality intact

### 14.4 Buff Tracker
1. Verify Buff Tracker works without docks
2. [ ] Buff monitoring works
3. [ ] Active/Inactive states work

### 14.5 Custom Tracker
1. Verify Custom Tracker still allows adding spells/items
2. [ ] Custom entries work

### 14.6 Layout Mode (Non-Dock Elements)
1. Verify other TweaksUI elements still work in Layout Mode
2. [ ] Trackers, containers, etc. still draggable

### 14.7 Masque Integration
1. If Masque is installed, enable Masque skinning
2. [ ] Docked icons receive Masque skins
3. [ ] Non-docked icons also skinned

**Result:** ☐ Pass ☐ Fail  
**Notes:** _________________________________

---

## Test Summary

| Section | Result | Critical Issues |
|---------|--------|-----------------|
| 1. Prerequisites | ☐ Pass ☐ Fail | |
| 2. Basic Dock Creation | ☐ Pass ☐ Fail | |
| 3. Icon Assignment | ☐ Pass ☐ Fail | |
| 4. Dock Layout | ☐ Pass ☐ Fail | |
| 5. Dock Appearance | ☐ Pass ☐ Fail | |
| 6. Visibility Conditions | ☐ Pass ☐ Fail | |
| 7. Layout Mode | ☐ Pass ☐ Fail | |
| 8. Visual Overrides | ☐ Pass ☐ Fail | |
| 9. Aspect Ratio | ☐ Pass ☐ Fail | |
| 10. Multi-Dock | ☐ Pass ☐ Fail | |
| 11. Profile Integration | ☐ Pass ☐ Fail | |
| 12. Performance | ☐ Pass ☐ Fail | |
| 13. Edge Cases | ☐ Pass ☐ Fail | |
| 14. Regression | ☐ Pass ☐ Fail | |

**Overall Result:** ☐ Ready for Release ☐ Needs Fixes

**Critical Bugs Found:**
1. _________________________________
2. _________________________________
3. _________________________________

**Minor Issues:**
1. _________________________________
2. _________________________________
3. _________________________________

**Tester Signature:** _______________ **Date:** _______________
