# TweaksUI Dynamic Docks - Testing Protocol
## Phases 1-9 Complete Testing Guide

**Version:** 1.0  
**Date:** January 17, 2026  
**Files Modified:**
- `Docks.lua` (1,398 lines) - Core dock system
- `DocksUI.lua` (1,501 lines) - Settings UI panels
- `Cooldowns.lua` (11,436 lines) - Module integration
- `CooldownHighlights.lua` (2,551 lines) - Essential/Utility/Custom per-icon
- `BuffHighlights.lua` (2,121 lines) - Buff Tracker per-icon
- `ProfileImportExport.lua` (942 lines) - Profile export/import
- `Profiles.lua` (1,010 lines) - Profile save/load

---

## File Installation

Copy files to these locations in your TweaksUI addon folder:

```
!TweaksUI/
├── Modules/
│   └── Cooldowns/
│       ├── Docks.lua          ← REPLACE
│       ├── DocksUI.lua        ← REPLACE
│       ├── Cooldowns.lua      ← REPLACE
│       ├── CooldownHighlights.lua  ← REPLACE
│       └── BuffHighlights.lua      ← REPLACE
└── Core/
    ├── ProfileImportExport.lua     ← REPLACE
    └── Profiles.lua                ← REPLACE
```

---

## Pre-Test Setup

### 1. Enable Required Features
```
/tui → Cooldowns → Enable module
```

### 2. Enable Per-Icon Settings
- Go to **Essential Tracker** → **Per-Icon** tab → Enable at least 2-3 icons
- Go to **Utility Tracker** → **Per-Icon** tab → Enable at least 2-3 icons  
- Go to **Buff Tracker** → **Per-Icon** tab → Enable at least 2-3 buffs

### 3. Enable Blizzard Cooldown Manager
```
/cdm or ESC → Edit Mode → Cooldown Manager
```
Ensure Essential and Utility trackers have spells assigned.

### 4. Enable Debug Mode (Optional)
```
/tui debug on
```
This shows detailed console output for troubleshooting.

---

## Phase 1-3: Docks Foundation

### Test 1.1: Docks Button in Hub
- [ ] Open TweaksUI settings (`/tui`)
- [ ] Verify "Docks" button appears in Cooldowns section
- [ ] Click "Docks" button
- [ ] Verify Docks settings panel opens to the right of hub

### Test 1.2: Dock Enable/Disable
- [ ] In Docks panel, enable "Dock 1"
- [ ] Verify dock frame appears on screen (may be empty)
- [ ] Disable "Dock 1"
- [ ] Verify dock frame disappears

### Test 1.3: Dock Naming
- [ ] Enable Dock 1
- [ ] Enter custom name "My Cooldowns"
- [ ] Verify name appears on dock label (in Layout Mode)
- [ ] `/reload` and verify name persists

### Test 1.4: Dock Orientation
- [ ] Set Dock 1 to **Horizontal**
- [ ] Assign icons (see Phase 4 tests)
- [ ] Verify icons arrange left-to-right
- [ ] Change to **Vertical**
- [ ] Verify icons arrange top-to-bottom

### Test 1.5: Dock Alignment/Justify
For Horizontal docks:
- [ ] Set justify to **Left** → icons align to left edge
- [ ] Set justify to **Center** → icons centered
- [ ] Set justify to **Right** → icons align to right edge

For Vertical docks:
- [ ] Set justify to **Top** → icons align to top
- [ ] Set justify to **Middle** → icons centered vertically
- [ ] Set justify to **Bottom** → icons align to bottom

### Test 1.6: Dock Appearance
- [ ] Enable "Show Background" → verify dark background appears
- [ ] Adjust background color → verify color changes
- [ ] Enable "Show Border" → verify border appears
- [ ] Adjust border color → verify color changes
- [ ] Adjust "Dock Alpha" slider → verify transparency changes

### Test 1.7: Dock Spacing
- [ ] Set spacing to 0 → icons touch each other
- [ ] Set spacing to 10 → visible gap between icons
- [ ] Set spacing to 20 → larger gap

---

## Phase 4: Dock Assignment Dropdowns

### Test 4.1: Essential Tracker Dock Assignment
- [ ] Go to **Essential Tracker** → **Per-Icon** tab
- [ ] Select an enabled icon (e.g., slot 1)
- [ ] Find "Assign to Dock" dropdown
- [ ] Select "Dock 1"
- [ ] Verify icon moves from Essential tracker to Dock 1
- [ ] Verify icon displays correctly in dock

### Test 4.2: Utility Tracker Dock Assignment
- [ ] Go to **Utility Tracker** → **Per-Icon** tab
- [ ] Select an enabled icon
- [ ] Assign to "Dock 2"
- [ ] Verify icon appears in Dock 2

### Test 4.3: Buff Tracker Dock Assignment
- [ ] Go to **Buff Tracker** → **Per-Icon** tab
- [ ] Select an enabled buff
- [ ] Assign to "Dock 1"
- [ ] Verify buff icon appears in Dock 1

### Test 4.4: Mixed Tracker Docking
- [ ] Assign 1 Essential icon to Dock 1
- [ ] Assign 1 Utility icon to Dock 1
- [ ] Assign 1 Buff to Dock 1
- [ ] Verify all 3 icons appear in Dock 1 together

### Test 4.5: Undocking
- [ ] Select a docked icon
- [ ] Change dropdown to "None (Standalone)"
- [ ] Verify icon returns to its original tracker position

### Test 4.6: Dock Assignment Persistence
- [ ] Assign several icons to docks
- [ ] `/reload`
- [ ] Verify all dock assignments restored correctly

---

## Phase 5: Mounted Visibility (Pre-existing)

### Test 5.1: Mounted Show/Hide
- [ ] Mount up on a ground mount
- [ ] Check "Hide While Mounted" in Visibility settings
- [ ] Verify trackers/docks hide
- [ ] Dismount
- [ ] Verify trackers/docks reappear

### Test 5.2: Dragonriding Exception
- [ ] Enable "Show During Skyriding"
- [ ] Mount a Dragonriding mount
- [ ] Verify trackers/docks remain visible during Skyriding
- [ ] Land and dismount

---

## Phase 6: Proc Glow Per-Icon Toggle

### Test 6.1: Essential/Utility Proc Glow Toggle
- [ ] Go to **Essential Tracker** → **Per-Icon** tab
- [ ] Select an icon for a proc ability (e.g., something that glows when usable)
- [ ] Find "Show Proc Glow" checkbox
- [ ] Uncheck it
- [ ] Trigger the proc in-game
- [ ] Verify NO glow appears on that icon
- [ ] Re-check the option
- [ ] Trigger proc again
- [ ] Verify glow NOW appears

### Test 6.2: Buff Tracker Proc Glow Toggle
- [ ] Go to **Buff Tracker** → **Per-Icon** tab
- [ ] Select a buff icon
- [ ] Toggle "Show Proc Glow" off/on
- [ ] Verify behavior matches expectation

### Test 6.3: Proc Glow Persistence
- [ ] Set several icons to have proc glow disabled
- [ ] `/reload`
- [ ] Verify settings persisted

---

## Phase 7: Visual Override APIs

### Test 7.1: Sweep Animation Toggle
*Note: These are internal APIs used by docks. Test via Docks Visual Override panel if available, or verify no errors in combat.*

- [ ] Dock an icon
- [ ] Put ability on cooldown
- [ ] Verify sweep animation shows (default)
- [ ] If Visual Override UI exists, disable sweep
- [ ] Verify sweep hides on cooldown

### Test 7.2: Countdown Text Toggle
- [ ] Dock an icon
- [ ] Put ability on cooldown  
- [ ] Verify countdown numbers show (default)
- [ ] If Visual Override UI exists, disable countdown text
- [ ] Verify numbers hide

### Test 7.3: Text Anchor Positioning
- [ ] Change cooldown text anchor (CENTER, TOPLEFT, etc.)
- [ ] Verify text position changes accordingly
- [ ] Change count text anchor (BOTTOMRIGHT, TOPRIGHT, etc.)
- [ ] Verify count position changes

### Test 7.4: No Lua Errors
- [ ] Enter combat with docked icons
- [ ] Use abilities, trigger cooldowns
- [ ] Check for Lua errors (`/console scriptErrors 1`)
- [ ] Verify no errors related to visual overrides

---

## Phase 8: Profile Integration

### Test 8.1: Profile Save with Docks
- [ ] Configure several docks with icons
- [ ] Go to **Profiles** panel
- [ ] Save current settings as new profile "DockTest"
- [ ] Verify save succeeds

### Test 8.2: Profile Load with Docks
- [ ] Change dock configuration (move icons, disable docks)
- [ ] Load profile "DockTest"
- [ ] Verify dock settings restored:
  - [ ] Dock enabled states
  - [ ] Dock positions
  - [ ] Dock names
  - [ ] Icon assignments

### Test 8.3: Profile Export
- [ ] Export profile to string
- [ ] Verify export completes without error
- [ ] Check export string is generated

### Test 8.4: Profile Import
- [ ] Copy an exported profile string
- [ ] Import as new profile
- [ ] Load the imported profile
- [ ] Verify dock settings are included

### Test 8.5: Profile Copy/Duplicate
- [ ] Duplicate a profile with dock settings
- [ ] Load the duplicated profile
- [ ] Verify dock settings copied correctly

---

## Phase 9: Layout Mode Integration

### Test 9.1: Layout Mode Shows All Docks
- [ ] Enable Layout Mode (`/tui layout` or button)
- [ ] Verify ALL 4 docks appear (even disabled ones)
- [ ] Disabled docks should show "(Disabled)" label
- [ ] Enabled but empty docks show dock name

### Test 9.2: Dock Dragging in Layout Mode
- [ ] Enter Layout Mode
- [ ] Click and drag a dock frame
- [ ] Verify dock moves smoothly
- [ ] Release mouse
- [ ] Exit Layout Mode
- [ ] Verify dock stays in new position

### Test 9.3: Dock Position Persistence
- [ ] Move docks to specific positions in Layout Mode
- [ ] Exit Layout Mode
- [ ] `/reload`
- [ ] Enter Layout Mode again
- [ ] Verify docks are in saved positions

### Test 9.4: Layout Mode Element List
- [ ] Open Layout Mode element list (if available)
- [ ] Verify docks appear under "Cooldowns" category
- [ ] Names should be "Dock 1", "Dock 2", etc. (or custom names)

### Test 9.5: Snap to Other Elements
- [ ] In Layout Mode, drag a dock near another TweaksUI element
- [ ] Verify snap indicator appears (if enabled)
- [ ] Release to snap
- [ ] Verify dock snapped to element edge

### Test 9.6: Layout Mode Exit Cleanup
- [ ] Enter Layout Mode
- [ ] Exit Layout Mode
- [ ] Verify docks return to normal visibility rules
- [ ] Disabled docks should hide
- [ ] Empty enabled docks should hide (not in combat)

---

## Combat Testing

### Test C.1: Combat Entry/Exit
- [ ] Configure docks with cooldown icons
- [ ] Enter combat (attack a training dummy)
- [ ] Verify docks show correctly
- [ ] Verify icons update on ability use
- [ ] Exit combat
- [ ] Verify no Lua errors

### Test C.2: Cooldown Tracking in Docks
- [ ] Dock several cooldown abilities
- [ ] Use each ability
- [ ] Verify:
  - [ ] Cooldown sweep animation plays
  - [ ] Countdown text updates
  - [ ] Icon desaturates when on cooldown
  - [ ] Icon re-saturates when ready

### Test C.3: Buff Tracking in Docks
- [ ] Dock several buff icons
- [ ] Apply/receive the buffs
- [ ] Verify:
  - [ ] Buff icons show when active
  - [ ] Duration countdown works
  - [ ] Icons hide when buff expires (if configured)

### Test C.4: Proc/Glow in Combat
- [ ] Dock a proc ability
- [ ] Trigger the proc condition
- [ ] Verify proc glow appears (if enabled)
- [ ] Use the ability
- [ ] Verify glow disappears

---

## Edge Cases

### Test E.1: Empty Docks
- [ ] Enable a dock with no icons assigned
- [ ] Verify dock hides outside Layout Mode
- [ ] Enter Layout Mode
- [ ] Verify empty dock shows with "Empty" text

### Test E.2: All Icons Removed
- [ ] Dock several icons to Dock 1
- [ ] Remove all icons (set to "None")
- [ ] Verify Dock 1 hides (not in Layout Mode)

### Test E.3: Rapid Dock Switching
- [ ] Quickly change dock assignments back and forth
- [ ] Verify no Lua errors
- [ ] Verify icons end up in correct final dock

### Test E.4: Disable Dock with Icons
- [ ] Assign icons to Dock 1
- [ ] Disable Dock 1
- [ ] Verify icons return to original tracker positions
- [ ] Re-enable Dock 1
- [ ] Verify icons return to Dock 1

### Test E.5: Spec Change
- [ ] Configure docks for current spec
- [ ] Switch specs
- [ ] Verify dock behavior appropriate for new spec
- [ ] Switch back
- [ ] Verify original configuration restored

---

## Performance Testing

### Test P.1: Many Docked Icons
- [ ] Dock 10+ icons across multiple docks
- [ ] Enter combat
- [ ] Monitor FPS/performance
- [ ] Verify no significant performance impact

### Test P.2: Rapid Combat Events
- [ ] In busy combat (dungeon/raid)
- [ ] Verify docks update smoothly
- [ ] No visual lag or stutter

### Test P.3: Memory Usage
- [ ] Note addon memory before enabling docks
- [ ] Enable all features
- [ ] Note memory after
- [ ] Verify reasonable memory increase

---

## Error Checking

### Test ERR.1: Lua Error Monitoring
```
/console scriptErrors 1
```
- [ ] Perform all above tests
- [ ] Check for ANY Lua errors mentioning:
  - `Docks`
  - `DocksUI`
  - `CooldownHighlights`
  - `BuffHighlights`
  - `secret` (Midnight API)
  - `taint`

### Test ERR.2: Saved Variables Integrity
- [ ] After extensive testing, `/reload`
- [ ] Check `WTF/Account/.../SavedVariables/TweaksUI.lua`
- [ ] Verify `docks` table exists in character DB
- [ ] Verify no corrupted data

---

## Checklist Summary

| Phase | Feature | Status |
|-------|---------|--------|
| 1-3 | Docks Foundation | ☐ |
| 1-3 | Docks UI Panel | ☐ |
| 4 | Essential Dock Assignment | ☐ |
| 4 | Utility Dock Assignment | ☐ |
| 4 | Buff Dock Assignment | ☐ |
| 5 | Mounted Visibility | ☐ |
| 6 | Proc Glow Toggle (CooldownHighlights) | ☐ |
| 6 | Proc Glow Toggle (BuffHighlights) | ☐ |
| 7 | Visual Override APIs | ☐ |
| 8 | Profile Save/Load | ☐ |
| 8 | Profile Export/Import | ☐ |
| 9 | Layout Mode Registration | ☐ |
| 9 | Dock Dragging | ☐ |
| 9 | Position Persistence | ☐ |
| - | Combat Testing | ☐ |
| - | No Lua Errors | ☐ |

---

## Known Limitations

1. **Docks auto-size** - Cannot manually resize docks; they size based on content
2. **Visual Override UI** - Not all Phase 7 settings have UI controls yet (internal APIs ready)
3. **Custom Tracker** - Dock assignment for Custom Tracker icons follows same pattern as Essential/Utility

---

## Reporting Issues

When reporting bugs, include:
1. Exact steps to reproduce
2. Expected behavior
3. Actual behavior
4. Any Lua error text
5. `/tui debug on` console output if available
6. Screenshot if visual issue

---

*Testing Protocol v1.0 - Phases 1-9*
