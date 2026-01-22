-- TweaksUI Presets
-- Preset registry, apply logic, resolution scaling, and backup system (1.5.0+)

local ADDON_NAME, TweaksUI = ...

TweaksUI.Presets = {}
local Presets = TweaksUI.Presets

-- ============================================================================
-- CONSTANTS
-- ============================================================================

-- Reference resolution for preset scaling (1080p)
local REFERENCE_HEIGHT = 1080

-- Maximum backups per module
local DEFAULT_MAX_BACKUPS = 3

-- ============================================================================
-- PRESET REGISTRY
-- ============================================================================

-- Module preset configurations
-- Format: moduleId -> { defaults, scalableKeys, builtIn }
local MODULE_REGISTRY = {}

-- Built-in presets are defined in PresetData.lua (loaded separately)
-- This table will be populated by that file
TweaksUI.BuiltInPresets = TweaksUI.BuiltInPresets or {}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Deep copy a table
local function DeepCopy(orig)
    if type(orig) ~= "table" then
        return orig
    end
    local copy = {}
    for k, v in pairs(orig) do
        copy[DeepCopy(k)] = DeepCopy(v)
    end
    return copy
end

-- Get current screen scale factor relative to reference resolution
function Presets:GetScreenScaleFactor()
    local screenHeight = GetScreenHeight()
    if not screenHeight or screenHeight <= 0 then
        screenHeight = REFERENCE_HEIGHT
    end
    return screenHeight / REFERENCE_HEIGHT
end

-- Check if a key is in the scalable list
local function IsScalableKey(key, scalableKeys)
    if not scalableKeys then return false end
    
    for _, scalableKey in ipairs(scalableKeys) do
        if key == scalableKey then
            return true
        end
        -- Support nested key patterns like "healthBar.width"
        if scalableKey:find(".", 1, true) then
            local parts = {strsplit(".", scalableKey)}
            if parts[#parts] == key then
                return true
            end
        end
    end
    return false
end

-- Recursively scale values in a preset table
local function ScalePresetValues(data, scalableKeys, scaleFactor, keyPath)
    if type(data) ~= "table" then
        return data
    end
    
    keyPath = keyPath or ""
    local scaled = {}
    
    for k, v in pairs(data) do
        local fullKey = keyPath == "" and k or (keyPath .. "." .. k)
        
        if type(v) == "table" then
            -- Recurse into nested tables
            scaled[k] = ScalePresetValues(v, scalableKeys, scaleFactor, fullKey)
        elseif type(v) == "number" and IsScalableKey(k, scalableKeys) then
            -- Scale this numeric value
            scaled[k] = math.floor(v * scaleFactor + 0.5)  -- Round to nearest integer
        else
            scaled[k] = v
        end
    end
    
    return scaled
end

-- ============================================================================
-- MODULE REGISTRATION
-- ============================================================================

-- Register a module for preset support
-- config = {
--     defaults = {},           -- Default settings table
--     scalableKeys = {},       -- Keys that should scale with resolution (e.g., "iconSize", "width", "height", "fontSize")
--     getSettings = function,  -- Optional: custom function to get current module settings
--     applySettings = function,-- Optional: custom function to apply settings
--     canHotApply = boolean,   -- Can this module hot-apply preset changes?
--     refreshFunc = function,  -- Function to call after hot-apply
-- }
function Presets:RegisterModule(moduleId, config)
    if not moduleId or not config then
        return false, "Module ID and config required"
    end
    
    MODULE_REGISTRY[moduleId] = {
        defaults = config.defaults or {},
        scalableKeys = config.scalableKeys or {},
        getSettings = config.getSettings,
        applySettings = config.applySettings,
        canHotApply = config.canHotApply or false,
        refreshFunc = config.refreshFunc,
    }
    
    -- Also register with Profiles for hot-apply tracking
    if TweaksUI.Profiles then
        TweaksUI.Profiles:RegisterHotApply(moduleId, {
            canHotApply = config.canHotApply or false,
            refreshFunc = config.refreshFunc,
        })
    end
    
    return true
end

-- Get registered module info
function Presets:GetModuleConfig(moduleId)
    return MODULE_REGISTRY[moduleId]
end

-- Get list of registered modules
function Presets:GetRegisteredModules()
    local modules = {}
    for moduleId in pairs(MODULE_REGISTRY) do
        table.insert(modules, moduleId)
    end
    table.sort(modules)
    return modules
end

-- ============================================================================
-- PRESET RETRIEVAL
-- ============================================================================

-- Get built-in presets for a module
function Presets:GetBuiltInPresets(moduleId)
    return TweaksUI.BuiltInPresets[moduleId] or {}
end

-- Get user presets for a module
function Presets:GetUserPresets(moduleId)
    if not TweaksUI_DB or not TweaksUI_DB.userPresets then
        return {}
    end
    return TweaksUI_DB.userPresets[moduleId] or {}
end

-- Get all presets for a module (built-in + user)
function Presets:GetAllPresets(moduleId)
    local all = {}
    
    -- Built-in first
    local builtIn = self:GetBuiltInPresets(moduleId)
    for name, data in pairs(builtIn) do
        all[name] = {
            data = data,
            isBuiltIn = true,
            name = name,
        }
    end
    
    -- Then user presets
    local user = self:GetUserPresets(moduleId)
    for name, presetInfo in pairs(user) do
        all[name] = {
            data = presetInfo.data,
            isBuiltIn = false,
            name = name,
            created = presetInfo.created,
        }
    end
    
    return all
end

-- Get preset list formatted for dropdown
function Presets:GetPresetDropdownList(moduleId)
    local list = {
        builtIn = {},
        user = {},
        backups = {},
    }
    
    -- Built-in presets
    local builtIn = self:GetBuiltInPresets(moduleId)
    for name in pairs(builtIn) do
        table.insert(list.builtIn, name)
    end
    table.sort(list.builtIn)
    
    -- User presets
    local user = self:GetUserPresets(moduleId)
    for name in pairs(user) do
        table.insert(list.user, name)
    end
    table.sort(list.user)
    
    -- Backups
    local backups = self:GetBackups(moduleId)
    for i, backup in ipairs(backups) do
        table.insert(list.backups, {
            index = i,
            timestamp = backup.timestamp,
            label = backup.label or ("Backup " .. i),
        })
    end
    
    return list
end

-- ============================================================================
-- PRESET APPLICATION
-- ============================================================================

-- Apply a preset to a module
-- Options:
--   scaleToResolution = true/false (default true)
--   createBackup = true/false (default: use global setting)
--   skipReload = true/false
function Presets:ApplyPreset(moduleId, presetName, options)
    options = options or {}
    
    local config = MODULE_REGISTRY[moduleId]
    if not config then
        return false, "Module not registered for presets: " .. moduleId
    end
    
    -- Find the preset
    local presetData
    local builtIn = self:GetBuiltInPresets(moduleId)
    if builtIn[presetName] then
        presetData = builtIn[presetName]
    else
        local user = self:GetUserPresets(moduleId)
        if user[presetName] then
            presetData = user[presetName].data
        end
    end
    
    if not presetData then
        return false, "Preset not found: " .. presetName
    end
    
    -- Create backup first (if enabled)
    local shouldBackup = options.createBackup
    if shouldBackup == nil then
        shouldBackup = self:IsAutoBackupEnabled()
    end
    
    if shouldBackup then
        self:CreateBackup(moduleId, "Pre-Preset: " .. presetName)
    end
    
    -- Scale to resolution if requested
    local scaledData = DeepCopy(presetData)
    if options.scaleToResolution ~= false then
        -- Use passed scaleAdjustment if provided (from master preset), otherwise calculate
        local scaleFactor = options.scaleAdjustment or self:GetScreenScaleFactor()
        if scaleFactor ~= 1 then
            scaledData = ScalePresetValues(scaledData, config.scalableKeys, scaleFactor)
        end
    end
    
    -- Apply the preset (pass resetFirst option)
    local applyOptions = {
        resetFirst = options.resetFirst or options.fullReset,
    }
    local success, needsReload = self:ApplyPresetData(moduleId, scaledData, applyOptions)
    if not success then
        return false, needsReload  -- needsReload is error message
    end
    
    -- Mark dirty
    if TweaksUI.Profiles then
        TweaksUI.Profiles:MarkDirty()
    end
    
    TweaksUI:Print("Applied preset |cffffd700" .. presetName .. "|r to " .. (TweaksUI.MODULE_NAMES[moduleId] or moduleId))
    
    if needsReload and not options.skipReload then
        return true, "NEEDS_RELOAD"
    end
    
    return true
end

-- Apply raw preset data to a module
function Presets:ApplyPresetData(moduleId, data, options)
    options = options or {}
    local config = MODULE_REGISTRY[moduleId]
    if not config then
        return false, "Module not registered"
    end
    
    -- Use custom apply function if provided
    if config.applySettings then
        local success, err = pcall(config.applySettings, data)
        if not success then
            return false, "Apply failed: " .. tostring(err)
        end
        
        -- Try hot-apply
        if config.canHotApply and config.refreshFunc then
            local refreshSuccess = pcall(config.refreshFunc)
            return true, not refreshSuccess
        end
        return true, not config.canHotApply
    end
    
    -- Get current settings reference
    local currentSettings = TweaksUI.Database:GetModuleSettings(moduleId)
    
    -- If resetFirst is true, start from defaults instead of merging
    if options.resetFirst then
        -- Try to get module defaults
        local moduleRef = TweaksUI.ModuleManager and TweaksUI.ModuleManager:GetModule(moduleId)
        local defaults = nil
        
        if moduleRef and moduleRef.GetDefaults then
            defaults = moduleRef:GetDefaults()
        elseif config.defaults and next(config.defaults) then
            defaults = config.defaults
        end
        
        if defaults then
            -- Clear current settings and start fresh from defaults
            for k in pairs(currentSettings) do
                currentSettings[k] = nil
            end
            -- Deep copy defaults into current settings
            local function DeepCopyInto(target, source)
                for k, v in pairs(source) do
                    if type(v) == "table" then
                        target[k] = {}
                        DeepCopyInto(target[k], v)
                    else
                        target[k] = v
                    end
                end
            end
            DeepCopyInto(currentSettings, defaults)
        end
    end
    
    -- Deep merge preset data into settings (either fresh defaults or existing)
    local function DeepMerge(target, source)
        for k, v in pairs(source) do
            if type(v) == "table" and type(target[k]) == "table" then
                DeepMerge(target[k], v)
            else
                target[k] = DeepCopy(v)
            end
        end
    end
    
    DeepMerge(currentSettings, data)
    
    -- Fire settings changed event
    if TweaksUI.Events then
        TweaksUI.Events:Fire(TweaksUI.EVENTS.SETTINGS_CHANGED, moduleId, nil, nil)
    end
    
    -- Try hot-apply
    if config.canHotApply and config.refreshFunc then
        local refreshSuccess = pcall(config.refreshFunc)
        return true, not refreshSuccess
    end
    
    return true, not config.canHotApply
end

-- ============================================================================
-- USER PRESET MANAGEMENT
-- ============================================================================

-- Save current module settings as a user preset
function Presets:SaveCurrentAsPreset(moduleId, presetName)
    if not presetName or presetName == "" then
        return false, "Preset name is required"
    end
    
    local config = MODULE_REGISTRY[moduleId]
    if not config then
        return false, "Module not registered for presets"
    end
    
    -- Check for built-in preset name collision
    local builtIn = self:GetBuiltInPresets(moduleId)
    if builtIn[presetName] then
        return false, "Cannot use a built-in preset name"
    end
    
    -- Get current settings
    local currentSettings
    if config.getSettings then
        currentSettings = config.getSettings()
    else
        currentSettings = TweaksUI.Database:GetModuleSettings(moduleId)
    end
    
    if not currentSettings then
        return false, "Could not get current settings"
    end
    
    -- Ensure storage exists
    if not TweaksUI_DB then TweaksUI_DB = {} end
    if not TweaksUI_DB.userPresets then TweaksUI_DB.userPresets = {} end
    if not TweaksUI_DB.userPresets[moduleId] then TweaksUI_DB.userPresets[moduleId] = {} end
    
    -- Save the preset
    TweaksUI_DB.userPresets[moduleId][presetName] = {
        created = time(),
        data = DeepCopy(currentSettings),
    }
    
    TweaksUI:Print("Saved preset: |cff00ff00" .. presetName .. "|r")
    return true
end

-- Delete a user preset
function Presets:DeleteUserPreset(moduleId, presetName)
    if not TweaksUI_DB or not TweaksUI_DB.userPresets then
        return false, "No user presets exist"
    end
    
    local modulePresets = TweaksUI_DB.userPresets[moduleId]
    if not modulePresets or not modulePresets[presetName] then
        return false, "Preset not found"
    end
    
    modulePresets[presetName] = nil
    TweaksUI:Print("Deleted preset: |cffff8800" .. presetName .. "|r")
    return true
end

-- Rename a user preset
function Presets:RenameUserPreset(moduleId, oldName, newName)
    if not TweaksUI_DB or not TweaksUI_DB.userPresets then
        return false, "No user presets exist"
    end
    
    local modulePresets = TweaksUI_DB.userPresets[moduleId]
    if not modulePresets or not modulePresets[oldName] then
        return false, "Preset not found"
    end
    
    if modulePresets[newName] then
        return false, "A preset with that name already exists"
    end
    
    -- Check for built-in name collision
    local builtIn = self:GetBuiltInPresets(moduleId)
    if builtIn[newName] then
        return false, "Cannot use a built-in preset name"
    end
    
    modulePresets[newName] = modulePresets[oldName]
    modulePresets[oldName] = nil
    
    TweaksUI:Print("Renamed preset to: |cff00ff00" .. newName .. "|r")
    return true
end

-- ============================================================================
-- BACKUP SYSTEM
-- ============================================================================

-- Create a backup of current module settings
function Presets:CreateBackup(moduleId, label)
    local config = MODULE_REGISTRY[moduleId]
    if not config then
        return false, "Module not registered"
    end
    
    -- Get current settings
    local currentSettings
    if config.getSettings then
        currentSettings = config.getSettings()
    else
        currentSettings = TweaksUI.Database:GetModuleSettings(moduleId)
    end
    
    if not currentSettings then
        return false, "Could not get current settings"
    end
    
    -- Ensure storage exists
    if not TweaksUI_DB then TweaksUI_DB = {} end
    if not TweaksUI_DB.presetBackups then TweaksUI_DB.presetBackups = {} end
    if not TweaksUI_DB.presetBackups[moduleId] then TweaksUI_DB.presetBackups[moduleId] = {} end
    
    local backups = TweaksUI_DB.presetBackups[moduleId]
    
    -- Add new backup at position 1
    table.insert(backups, 1, {
        timestamp = time(),
        label = label or "Backup",
        data = DeepCopy(currentSettings),
    })
    
    -- Trim to max backups
    local maxBackups = self:GetMaxBackupsPerModule()
    while #backups > maxBackups do
        table.remove(backups)
    end
    
    return true
end

-- Get backups for a module
function Presets:GetBackups(moduleId)
    if not TweaksUI_DB or not TweaksUI_DB.presetBackups then
        return {}
    end
    return TweaksUI_DB.presetBackups[moduleId] or {}
end

-- Restore a backup
function Presets:RestoreBackup(moduleId, backupIndex)
    local backups = self:GetBackups(moduleId)
    local backup = backups[backupIndex]
    
    if not backup then
        return false, "Backup not found"
    end
    
    -- Create a new backup before restoring (so we don't lose current state)
    self:CreateBackup(moduleId, "Pre-Restore")
    
    -- Apply the backup data
    local success, needsReload = self:ApplyPresetData(moduleId, backup.data)
    if not success then
        return false, needsReload
    end
    
    -- Mark dirty
    if TweaksUI.Profiles then
        TweaksUI.Profiles:MarkDirty()
    end
    
    TweaksUI:Print("Restored backup from " .. date("%b %d, %I:%M%p", backup.timestamp))
    
    if needsReload then
        return true, "NEEDS_RELOAD"
    end
    
    return true
end

-- Delete a backup
function Presets:DeleteBackup(moduleId, backupIndex)
    if not TweaksUI_DB or not TweaksUI_DB.presetBackups then
        return false, "No backups exist"
    end
    
    local backups = TweaksUI_DB.presetBackups[moduleId]
    if not backups or not backups[backupIndex] then
        return false, "Backup not found"
    end
    
    table.remove(backups, backupIndex)
    return true
end

-- ============================================================================
-- GLOBAL SETTINGS
-- ============================================================================

function Presets:IsAutoBackupEnabled()
    if not TweaksUI_DB or not TweaksUI_DB.global or not TweaksUI_DB.global.presetSettings then
        return true  -- Default to enabled
    end
    return TweaksUI_DB.global.presetSettings.autoBackup ~= false
end

function Presets:SetAutoBackupEnabled(enabled)
    if not TweaksUI_DB then TweaksUI_DB = {} end
    if not TweaksUI_DB.global then TweaksUI_DB.global = {} end
    if not TweaksUI_DB.global.presetSettings then TweaksUI_DB.global.presetSettings = {} end
    TweaksUI_DB.global.presetSettings.autoBackup = enabled
end

function Presets:GetMaxBackupsPerModule()
    if not TweaksUI_DB or not TweaksUI_DB.global or not TweaksUI_DB.global.presetSettings then
        return DEFAULT_MAX_BACKUPS
    end
    return TweaksUI_DB.global.presetSettings.maxBackupsPerModule or DEFAULT_MAX_BACKUPS
end

function Presets:SetMaxBackupsPerModule(count)
    if not TweaksUI_DB then TweaksUI_DB = {} end
    if not TweaksUI_DB.global then TweaksUI_DB.global = {} end
    if not TweaksUI_DB.global.presetSettings then TweaksUI_DB.global.presetSettings = {} end
    TweaksUI_DB.global.presetSettings.maxBackupsPerModule = math.max(1, math.min(10, count))
end

-- ============================================================================
-- COMMON SCALABLE KEYS
-- ============================================================================

-- Predefined lists of commonly scalable settings
Presets.COMMON_SCALABLE_KEYS = {
    -- Size-related
    "width", "height", "size",
    "iconSize", "iconWidth", "iconHeight",
    "barWidth", "barHeight",
    "buttonSize",
    "scale",  -- Note: scale is a multiplier, may need special handling
    
    -- Spacing
    "spacing", "spacingH", "spacingV",
    "gap", "padding", "margin",
    "offsetX", "offsetY",
    "positionX", "positionY",
    
    -- Text
    "fontSize", "textSize",
}

-- ============================================================================
-- PRESET LIST FOR DROPDOWNS
-- ============================================================================

-- Get list of presets formatted for dropdown menus
-- Returns { builtIn = {"name1", "name2", ...}, user = {"name1", "name2", ...} }
function Presets:GetPresetDropdownList(moduleId)
    local result = { builtIn = {}, user = {} }
    
    -- Built-in presets
    local builtIn = self:GetBuiltInPresets(moduleId) or {}
    for name, _ in pairs(builtIn) do
        table.insert(result.builtIn, name)
    end
    table.sort(result.builtIn)
    
    -- User presets
    local userPresets = self:GetUserPresets(moduleId) or {}
    for name, _ in pairs(userPresets) do
        table.insert(result.user, name)
    end
    table.sort(result.user)
    
    return result
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function Presets:Initialize()
    -- Load built-in preset data (defined in PresetData.lua)
    -- That file will populate TweaksUI.BuiltInPresets
    
    TweaksUI:PrintDebug("Presets system initialized")
end
