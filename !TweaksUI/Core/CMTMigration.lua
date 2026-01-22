-- ============================================================================
-- TweaksUI CMT Migration Module
-- Migrates settings from Cooldown Manager Tweaks (CMT) to TweaksUI
-- ============================================================================

local ADDON_NAME, TweaksUI = ...

TweaksUI.CMTMigration = {}
local Migration = TweaksUI.CMTMigration

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local MIGRATION_VERSION = 1  -- Increment if migration logic changes

-- Tracker key mapping (CMT key -> TUI key)
local TRACKER_MAPPING = {
    essential = "essential",
    utility = "utility",
    buffs = "buffs",
    items = "customTrackers",  -- CMT's items tracker maps to TUI's custom trackers
}

-- Check if aspect ratio is custom pixel format (must be defined before SETTING_MAPPING)
local function IsCustomAspectRatio(aspectRatio)
    if not aspectRatio then return false end
    return aspectRatio:match("^%d+x%d+$") ~= nil
end

-- Setting mapping: CMT setting name -> TUI setting name (or function to transform)
-- nil value means skip (not applicable to TUI)
local SETTING_MAPPING = {
    -- Layout settings
    alignment = "alignment",
    hSpacing = "spacingH",
    vSpacing = "spacingV",
    reverseOrder = "reverseOrder",
    
    -- Row pattern needs conversion from array to string
    rowPattern = function(value)
        if type(value) == "table" then
            return "customLayout", table.concat(value, ",")
        end
        return "customLayout", ""
    end,
    
    -- Layout direction needs conversion
    layoutDirection = function(value)
        if value == "ROWS" then
            return "growDirection", "RIGHT"  -- TUI uses RIGHT for horizontal-first
        else
            return "growDirection", "DOWN"   -- TUI uses DOWN for vertical-first
        end
    end,
    
    -- Icon settings
    iconSize = "iconSize",
    iconOpacity = "iconOpacity",
    borderAlpha = "borderAlpha",
    
    -- Zoom: CMT uses 1.0-3.0 (1=no zoom, 3=max zoom into center)
    -- TUI uses 0-0.5 (0=no inset, higher=more inset/zoom)
    zoom = function(value)
        if type(value) ~= "number" then return "zoom", 0.08 end
        -- Convert CMT zoom (1.0-3.0) to TUI zoom (0-0.5)
        -- CMT 1.0 = TUI 0, CMT 3.0 = TUI 0.5
        local tuiZoom = (value - 1) * 0.25
        tuiZoom = math.max(0, math.min(0.5, tuiZoom))
        return "zoom", tuiZoom
    end,
    
    -- Aspect ratio
    aspectRatio = function(value, settings)
        if value == "custom" or (settings.customAspectW and settings.customAspectH) then
            -- For custom, we'll set iconWidth/iconHeight instead
            return nil, nil
        end
        return "aspectRatio", value
    end,
    customAspectW = function(value, settings)
        if settings.aspectRatio == "custom" or IsCustomAspectRatio(settings.aspectRatio) then
            return "iconWidth", value
        end
        return nil, nil
    end,
    customAspectH = function(value, settings)
        if settings.aspectRatio == "custom" or IsCustomAspectRatio(settings.aspectRatio) then
            return "iconHeight", value
        end
        return nil, nil
    end,
    
    -- Text scaling
    cooldownTextScale = "cooldownTextScale",
    countTextScale = "countTextScale",
    
    -- Buff-specific (persistent display)
    persistentDisplay = nil,  -- TUI doesn't have this toggle - always shows buffs
    greyscaleInactive = "greyscaleInactive",
    inactiveAlpha = "inactiveAlpha",
    
    -- Visibility settings
    visibilityEnabled = "visibilityEnabled",
    visibilityCombat = function(value)
        -- CMT: visibilityCombat = true means show IN combat
        return "showInCombat", value
    end,
    visibilityMouseover = nil,  -- TUI uses fade system instead
    visibilityTarget = function(value)
        return "showHasTarget", value
    end,
    visibilityGroup = function(value)
        -- CMT has single toggle, TUI has separate party/raid
        return "showInParty", value  -- We'll also set showInRaid
    end,
    visibilityInstance = function(value)
        return "showInInstance", value
    end,
    visibilityInstanceTypes = nil,  -- TUI doesn't have granular instance types
    visibilityFadeAlpha = function(value)
        -- CMT uses 0-100, TUI uses 0-1
        if type(value) ~= "number" then return "fadeAlpha", 0.3 end
        return "fadeAlpha", value / 100
    end,
    
    -- Settings we skip (no TUI equivalent)
    compactMode = nil,
    compactOffset = nil,
    borderScale = nil,
    barIconSide = nil,  -- Bar type not in TUI yet
    barSpacing = nil,
    barIconGap = nil,
    visibilityOverrideEMT = nil,
    masqueDisabled = nil,
    masqueSavedAspect = nil,
    masqueSavedZoom = nil,
    masqueSavedBorderAlpha = nil,
}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Deep copy a table
local function DeepCopy(orig)
    local copy
    if type(orig) == 'table' then
        copy = {}
        for k, v in pairs(orig) do
            copy[DeepCopy(k)] = DeepCopy(v)
        end
    else
        copy = orig
    end
    return copy
end

-- Print migration message
local function MigrationPrint(msg)
    print("|cff00ccff[TweaksUI Migration]|r " .. msg)
end

-- ============================================================================
-- SETTING CONVERSION
-- ============================================================================

-- Convert a single CMT tracker's settings to TUI format
local function ConvertTrackerSettings(cmtSettings, trackerKey)
    if not cmtSettings then return {} end
    
    local tuiSettings = {}
    
    -- Process each CMT setting
    for cmtKey, cmtValue in pairs(cmtSettings) do
        -- Skip iconOverrides - we'll handle separately
        if cmtKey == "iconOverrides" then
            -- TUI doesn't support per-icon overrides yet, skip
        else
            local mapping = SETTING_MAPPING[cmtKey]
            
            if mapping == nil then
                -- Skip this setting (no TUI equivalent)
            elseif type(mapping) == "string" then
                -- Direct mapping
                tuiSettings[mapping] = cmtValue
            elseif type(mapping) == "function" then
                -- Transform function
                local tuiKey, tuiValue = mapping(cmtValue, cmtSettings)
                if tuiKey then
                    tuiSettings[tuiKey] = tuiValue
                end
            end
        end
    end
    
    -- Handle visibilityGroup -> both showInParty and showInRaid
    if cmtSettings.visibilityGroup ~= nil then
        tuiSettings.showInParty = cmtSettings.visibilityGroup
        tuiSettings.showInRaid = cmtSettings.visibilityGroup
    end
    
    -- Set enabled based on whether there are actual settings
    tuiSettings.enabled = true
    
    return tuiSettings
end

-- Convert an entire CMT profile to TUI cooldowns format
local function ConvertProfile(cmtProfile)
    local cooldownsSettings = {}
    
    for cmtKey, tuiKey in pairs(TRACKER_MAPPING) do
        if cmtProfile[cmtKey] then
            cooldownsSettings[tuiKey] = ConvertTrackerSettings(cmtProfile[cmtKey], tuiKey)
        end
    end
    
    -- Add global settings
    cooldownsSettings.global = {
        debugMode = false,
    }
    
    return cooldownsSettings
end

-- ============================================================================
-- CUSTOM ENTRIES MIGRATION
-- ============================================================================

-- Migrate custom tracker entries from CMT to TUI
local function MigrateCustomEntries()
    if not CMT_CharDB then return false end
    
    -- CMT stores in customEntriesBySpec[specID] = { {type="item", id=123}, {type="spell", id=456} }
    -- TUI stores in TweaksUI_CharDB.cooldowns.customEntries[specID] = same format
    
    local cmtEntries = CMT_CharDB.customEntriesBySpec
    if not cmtEntries then return false end
    
    -- Ensure TUI structure exists
    TweaksUI_CharDB = TweaksUI_CharDB or {}
    TweaksUI_CharDB.cooldowns = TweaksUI_CharDB.cooldowns or {}
    TweaksUI_CharDB.cooldowns.customEntries = TweaksUI_CharDB.cooldowns.customEntries or {}
    
    local entriesMigrated = 0
    
    for specID, entries in pairs(cmtEntries) do
        if type(entries) == "table" and #entries > 0 then
            -- Only migrate if TUI doesn't already have entries for this spec
            if not TweaksUI_CharDB.cooldowns.customEntries[specID] or 
               #TweaksUI_CharDB.cooldowns.customEntries[specID] == 0 then
                TweaksUI_CharDB.cooldowns.customEntries[specID] = DeepCopy(entries)
                entriesMigrated = entriesMigrated + #entries
            end
        end
    end
    
    return entriesMigrated
end

-- ============================================================================
-- MAIN MIGRATION LOGIC
-- ============================================================================

-- Check if CMT is loaded
function Migration:IsCMTLoaded()
    return _G.CMT_DB ~= nil and _G.CMT_CharDB ~= nil
end

-- Check if migration has already been performed
function Migration:HasMigrated()
    if not TweaksUI_CharDB then return false end
    return TweaksUI_CharDB.cmtMigrationVersion and 
           TweaksUI_CharDB.cmtMigrationVersion >= MIGRATION_VERSION
end

-- Mark migration as complete
function Migration:SetMigrated()
    TweaksUI_CharDB = TweaksUI_CharDB or {}
    TweaksUI_CharDB.cmtMigrationVersion = MIGRATION_VERSION
    TweaksUI_CharDB.cmtMigrationDate = date("%Y-%m-%d %H:%M:%S")
end

-- Get list of CMT profiles
function Migration:GetCMTProfiles()
    if not CMT_DB or not CMT_DB.profiles then return {} end
    
    local profiles = {}
    for name in pairs(CMT_DB.profiles) do
        table.insert(profiles, name)
    end
    table.sort(profiles)
    return profiles
end

-- Get current CMT profile for this character
function Migration:GetCurrentCMTProfile()
    if not CMT_CharDB then return "Default" end
    return CMT_CharDB.currentProfile or "Default"
end

-- Perform the migration
function Migration:DoMigration()
    if not self:IsCMTLoaded() then
        return false, "CMT not loaded"
    end
    
    -- Ensure TUI database structure
    TweaksUI_DB = TweaksUI_DB or {}
    TweaksUI_DB.profiles = TweaksUI_DB.profiles or {}
    TweaksUI_DB.profileAssignments = TweaksUI_DB.profileAssignments or {}
    TweaksUI_CharDB = TweaksUI_CharDB or {}
    
    local profilesMigrated = 0
    local entriesMigrated = 0
    
    -- Get character info for unique naming
    local charName = UnitName("player")
    local charKey = charName .. "-" .. GetRealmName()
    
    -- Get current CMT profile name for this character
    local currentCMTProfile = self:GetCurrentCMTProfile()
    local currentCMTSettings = CMT_DB.profiles[currentCMTProfile]
    
    -- Create character-specific profile from current CMT profile
    -- Format: CMT_CharacterName_ProfileName
    local tuiProfileName = "CMT_" .. charName .. "_" .. currentCMTProfile
    
    if currentCMTSettings then
        -- Only create if doesn't already exist
        if not TweaksUI_DB.profiles[tuiProfileName] then
            local convertedSettings = ConvertProfile(currentCMTSettings)
            
            TweaksUI_DB.profiles[tuiProfileName] = {
                cooldowns = convertedSettings
            }
            profilesMigrated = profilesMigrated + 1
            MigrationPrint("Created profile: " .. tuiProfileName)
        else
            MigrationPrint("Profile already exists: " .. tuiProfileName)
        end
        
        -- Assign this profile to the current character
        TweaksUI_DB.profileAssignments[charKey] = tuiProfileName
        MigrationPrint("Assigned profile '" .. tuiProfileName .. "' to " .. charKey)
        
        -- If TUI's Database is already initialized, update the active profile
        if TweaksUI.Database and TweaksUI.Database.SetProfile then
            TweaksUI.Database:SetProfile(tuiProfileName)
        end
    end
    
    -- Also migrate other CMT profiles (for characters that might use them)
    for profileName, cmtProfile in pairs(CMT_DB.profiles) do
        if profileName ~= currentCMTProfile then
            local backupProfileName = "CMT_" .. charName .. "_" .. profileName
            
            if not TweaksUI_DB.profiles[backupProfileName] then
                TweaksUI_DB.profiles[backupProfileName] = {
                    cooldowns = ConvertProfile(cmtProfile)
                }
                profilesMigrated = profilesMigrated + 1
            end
        end
    end
    
    -- Migrate custom tracker entries
    entriesMigrated = MigrateCustomEntries() or 0
    
    -- Mark migration complete
    self:SetMigrated()
    
    return true, profilesMigrated, entriesMigrated
end

-- ============================================================================
-- WARNING DIALOG
-- ============================================================================

local function ShowCMTWarningDialog()
    -- Create static popup if it doesn't exist
    if not StaticPopupDialogs["TWEAKSUI_CMT_MIGRATION"] then
        StaticPopupDialogs["TWEAKSUI_CMT_MIGRATION"] = {
            text = "|cff00ccffTweaksUI|r has detected |cffff9900Cooldown Manager Tweaks|r is also loaded.\n\n" ..
                   "Your CMT settings have been imported into TweaksUI profiles (prefixed with 'CMT Import').\n\n" ..
                   "|cffff3333Important:|r To use TweaksUI, you must |cffffff00disable CMT|r first, " ..
                   "as both addons cannot hook the same frames.\n\n" ..
                   "You can safely uninstall CMT after verifying your settings imported correctly.",
            button1 = "OK, I'll Disable CMT",
            button2 = "Remind Me Later",
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
            OnAccept = function()
                -- Just close, they said they'll disable it
            end,
            OnCancel = function()
                -- Clear the migration flag so we show again next time
                if TweaksUI_CharDB then
                    TweaksUI_CharDB.cmtMigrationVersion = nil
                end
            end,
        }
    end
    
    StaticPopup_Show("TWEAKSUI_CMT_MIGRATION")
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

-- Run migration check on addon load
local migrationFrame = CreateFrame("Frame")
migrationFrame:RegisterEvent("ADDON_LOADED")
migrationFrame:RegisterEvent("PLAYER_LOGIN")

local addonLoaded = false
local playerLoggedIn = false

local function TryMigration()
    if not addonLoaded or not playerLoggedIn then return end
    
    -- Only run once
    migrationFrame:UnregisterAllEvents()
    
    -- Check if CMT is loaded
    if not Migration:IsCMTLoaded() then
        return  -- CMT not present, nothing to do
    end
    
    -- Check if we've already migrated
    if Migration:HasMigrated() then
        -- Still show warning if CMT is loaded (user hasn't disabled it yet)
        C_Timer.After(3, function()
            ShowCMTWarningDialog()
        end)
        return
    end
    
    -- Perform migration
    local success, profilesOrError, entries = Migration:DoMigration()
    
    if success then
        MigrationPrint("Migration complete!")
        
        -- Show warning after a short delay to ensure UI is ready
        C_Timer.After(3, function()
            ShowCMTWarningDialog()
        end)
    else
        MigrationPrint("Migration failed: " .. tostring(profilesOrError))
    end
end

migrationFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            addonLoaded = true
            TryMigration()
        end
    elseif event == "PLAYER_LOGIN" then
        playerLoggedIn = true
        TryMigration()
    end
end)

-- ============================================================================
-- MANUAL MIGRATION COMMAND
-- ============================================================================

SLASH_TUICMTMIGRATE1 = "/tuicmtmigrate"
SlashCmdList["TUICMTMIGRATE"] = function(msg)
    msg = (msg or ""):lower():trim()
    
    if msg == "status" then
        MigrationPrint("CMT Loaded: " .. tostring(Migration:IsCMTLoaded()))
        MigrationPrint("Already Migrated: " .. tostring(Migration:HasMigrated()))
        if Migration:IsCMTLoaded() then
            MigrationPrint("Current CMT Profile: " .. Migration:GetCurrentCMTProfile())
        end
        local charKey = UnitName("player") .. "-" .. GetRealmName()
        local assigned = TweaksUI_DB and TweaksUI_DB.profileAssignments and TweaksUI_DB.profileAssignments[charKey]
        MigrationPrint("TUI Profile: " .. tostring(assigned or "Default"))
        
    elseif msg == "force" then
        -- Clear migration flag and re-run
        if TweaksUI_CharDB then
            TweaksUI_CharDB.cmtMigrationVersion = nil
        end
        
        if Migration:IsCMTLoaded() then
            local success, profilesOrError, entries = Migration:DoMigration()
            if success then
                MigrationPrint("Forced migration complete!")
            else
                MigrationPrint("Migration failed: " .. tostring(profilesOrError))
            end
        else
            MigrationPrint("CMT is not loaded. Enable CMT and TweaksUI together, then run this command.")
        end
        
    elseif msg == "reset" then
        -- Clear migration flag
        if TweaksUI_CharDB then
            TweaksUI_CharDB.cmtMigrationVersion = nil
            TweaksUI_CharDB.cmtMigrationDate = nil
        end
        MigrationPrint("Migration flag cleared. Will re-migrate on next login with CMT enabled.")
        
    else
        MigrationPrint("CMT Migration Commands:")
        print("  /tuicmtmigrate status - Show migration status")
        print("  /tuicmtmigrate force  - Force re-migration (requires CMT loaded)")
        print("  /tuicmtmigrate reset  - Clear migration flag")
    end
end
