-- ============================================================================
-- TweaksUI: Nameplates Module v1.4.0
-- Core module definition, lifecycle, and shared state
-- Split into multiple files for maintainability
-- ============================================================================

local ADDON_NAME, TweaksUI = ...

-- ============================================================================
-- LOCALIZED GLOBALS (Performance Optimization v1.9.0)
-- ============================================================================

-- Lua
local pairs = pairs
local ipairs = ipairs
local type = type
local select = select
local pcall = pcall
local wipe = wipe

-- WoW API
local GetTime = GetTime
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local UnitExists = UnitExists
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitIsFriend = UnitIsFriend
local UnitCanAttack = UnitCanAttack
local C_NamePlate = C_NamePlate

-- ============================================================================
-- MODULE REGISTRATION
-- ============================================================================

local Nameplates = TweaksUI.ModuleManager:NewModule(
    TweaksUI.MODULE_IDS.NAMEPLATES,
    "Nameplates",
    "CVar controls, highlights, and health bar customization"
)

TweaksUI.Nameplates = Nameplates

-- ============================================================================
-- SHARED STATE (accessible by all Nameplates files)
-- ============================================================================

Nameplates.State = {
    settings = nil,
    nameplatesHub = nil,
    settingsPanels = {},
    currentOpenPanel = nil,
    enhancedNameplates = {},
    originalCVars = {},
    infoTooltip = nil,
    simulationFrame = nil,
    moduleDisabledByAddon = false,
    hubButtons = {},
    platynatorButton = nil,
    platerButton = nil,
}

-- ============================================================================
-- CONSTANTS
-- ============================================================================

Nameplates.Constants = {
    HUB_WIDTH = 220,
    PANEL_WIDTH = 420,
    BUTTON_HEIGHT = 28,
    BUTTON_SPACING = 6,
    IS_MIDNIGHT = true,  -- v2.0.0 is Midnight-only
    
    darkBackdrop = {
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    },
}

-- ============================================================================
-- DEFAULT SETTINGS
-- ============================================================================

Nameplates.Defaults = {}

Nameplates.Defaults.HEALTH_BAR = {
    enabled = true,
    texture = "Blizzard",
    colorMode = "reaction",  -- "class", "reaction", "health", "threat", "custom"
    customColor = { 1, 0, 0, 1 },
    bgEnabled = true,
    bgColor = { 0.1, 0.1, 0.1, 0.8 },
    borderEnabled = false,
    borderColor = { 0, 0, 0, 1 },
    borderSize = 1,
    -- Size settings (matching UnitFrames pattern)
    width = 140,
    height = 12,
    -- Scale settings (percentage, 100 = no change)
    targetScale = 110,      -- Scale when targeted (110 = 10% larger)
    mouseoverScale = 100,   -- Scale when moused over (100 = no change)
    -- Alpha settings
    alpha = 1.0,
    targetAlpha = 1.0,
    -- Threat settings
    invertThreatColors = false,  -- When true, swap aggro/no-aggro colors (tank mode)
    threatScaleEnabled = false,  -- Scale bar based on threat
    threatScaleMin = 80,         -- Min scale % when no threat
    threatScaleMax = 120,        -- Max scale % when tanking
}

Nameplates.Defaults.FRIENDLY_HEALTH_BAR = {
    enabled = true,
    texture = "Blizzard",
    colorMode = "class",  -- "class", "reaction", "health", "threat", "custom"
    customColor = { 0, 1, 0, 1 },
    bgEnabled = true,
    bgColor = { 0.1, 0.1, 0.1, 0.8 },
    borderEnabled = false,
    borderColor = { 0, 0, 0, 1 },
    borderSize = 1,
    -- Size settings
    width = 140,
    height = 12,
    -- Scale settings (percentage, 100 = no change)
    targetScale = 110,      -- Scale when targeted (110 = 10% larger)
    mouseoverScale = 100,   -- Scale when moused over (100 = no change)
    -- Alpha settings  
    alpha = 1.0,
    targetAlpha = 1.0,
    -- Threat settings (less relevant for friendlies but included for consistency)
    invertThreatColors = false,
    threatScaleEnabled = false,
    threatScaleMin = 80,
    threatScaleMax = 120,
}

-- Icons defaults (elite dragon, raid markers, etc.)
Nameplates.Defaults.ICONS = {
    -- Classification icon (elite dragon, rare star, boss skull)
    classificationEnabled = true,
    classificationSize = 16,
    classificationPosition = "LEFT",  -- "LEFT", "RIGHT", "TOP", "BOTTOM"
    classificationOffsetX = -2,
    classificationOffsetY = 0,
    
    -- Raid target icon (skull, X, square, etc.)
    raidMarkerEnabled = true,
    raidMarkerSize = 20,
    raidMarkerPosition = "TOP",  -- "LEFT", "RIGHT", "TOP", "BOTTOM"
    raidMarkerOffsetX = 0,
    raidMarkerOffsetY = 4,
    
    -- Quest indicator
    questEnabled = true,
    questSize = 16,
    questPosition = "RIGHT",
    questOffsetX = 2,
    questOffsetY = 0,
    
    -- Level text
    levelEnabled = false,
    levelFont = "Friz Quadrata TT",
    levelFontSize = 10,
    levelOutline = "OUTLINE",
    levelPosition = "LEFT",
    levelOffsetX = -4,
    levelOffsetY = 0,
    levelColor = { 1, 1, 1, 1 },
    levelUseDifficultyColor = true,
    
    -- PvP marker (flag carrier, orb carrier, bounty)
    pvpMarkerEnabled = true,
    pvpMarkerSize = 20,
    pvpMarkerPosition = "RIGHT",
    pvpMarkerOffsetX = 2,
    pvpMarkerOffsetY = 0,
}

Nameplates.Defaults.SETTINGS = {
    enabled = true,
    overrideGlobalTexture = false,  -- When true, use per-bar textures instead of global
    cvars = {},
    targetHighlight = { enabled = true, style = "glow", color = { 1, 1, 1, 0.6 }, thickness = 3 },
    focusHighlight = { enabled = false, style = "glow", color = { 0.5, 0, 1, 0.6 }, thickness = 3 },
    mouseoverHighlight = { enabled = false, style = "glow", color = { 0.3, 1, 0.3, 0.5 }, thickness = 2 },
    enemy = { 
        healthBar = nil,
        nameText = nil,
        healthText = nil,
        threatText = nil,
        icons = nil,
        scale = 100,  -- Scale for enemy nameplates (50-200)
    },
    friendly = { 
        healthBar = nil,
        nameText = nil,
        healthText = nil,
        threatText = nil,
        icons = nil,
        scale = 100,  -- Scale for friendly nameplates (50-200)
    },
}

-- Text element defaults
Nameplates.Defaults.NAME_TEXT = {
    enabled = true,
    font = "Friz Quadrata TT",
    fontSize = 10,
    colorMode = "reaction",
    customColor = { 1, 1, 1, 1 },
    outline = "THIN",
    anchor = "BOTTOM",
    relativePoint = "TOP",
    offsetX = 0,
    offsetY = 2,
    shadow = true,
    showServerName = false,
}

Nameplates.Defaults.HEALTH_TEXT = {
    enabled = false,
    font = "Friz Quadrata TT",
    fontSize = 9,
    colorMode = "white",
    customColor = { 1, 1, 1, 1 },
    outline = "THIN",
    anchor = "CENTER",
    relativePoint = "CENTER",
    offsetX = 0,
    offsetY = 0,
    shadow = true,
    format = "PERCENT",
}

Nameplates.Defaults.THREAT_TEXT = {
    enabled = false,
    font = "Friz Quadrata TT",
    fontSize = 9,
    colorMode = "threat",
    customColor = { 1, 1, 1, 1 },
    outline = "THIN",
    anchor = "RIGHT",
    relativePoint = "LEFT",
    offsetX = -4,
    offsetY = 0,
    shadow = true,
    showPercent = true,
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

function Nameplates:DeepCopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do copy[k] = self:DeepCopy(v) end
    return copy
end

function Nameplates:DeepMerge(dest, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(dest[key]) == "table" then
                self:DeepMerge(dest[key], value)
            else
                dest[key] = self:DeepCopy(value)
            end
        else
            dest[key] = value
        end
    end
end

-- Apply scale to a dimension value based on unit type
-- configKey is "enemy" or "friendly"
function Nameplates:ApplyScale(value, configKey)
    if not value or type(value) ~= "number" then return value end
    local scalePct = 100
    if self.State.settings and configKey then
        local typeConfig = self.State.settings[configKey]
        if typeConfig and typeConfig.scale then
            scalePct = typeConfig.scale
        end
    end
    
    -- Handle secret values - can't do math on them
    if issecretvalue and issecretvalue(value) then
        -- Return a safe default - this shouldn't happen for config values
        -- but can happen if someone passes frame dimensions
        return 10  -- Safe fallback
    end
    
    -- Handle nil values
    if value == nil then
        return 0
    end
    
    return value * (scalePct / 100)
end

-- Get scaled dimension for a config value
function Nameplates:GetScaledValue(configValue, defaultValue, configKey)
    local value = configValue or defaultValue or 0
    return self:ApplyScale(value, configKey)
end

function Nameplates:SaveSettings()
    TweaksUI.Database:SetModuleSettings(TweaksUI.MODULE_IDS.NAMEPLATES, self.State.settings)
    
    -- Refresh simulation previews when settings change
    if self.RefreshAllSimulations then
        self:RefreshAllSimulations()
    end
end

function Nameplates:EnsureSettings()
    if not self.State.settings then
        self.State.settings = self:DeepCopy(self.Defaults.SETTINGS)
        self.State.settings.enemy.healthBar = self:DeepCopy(self.Defaults.HEALTH_BAR)
        self.State.settings.friendly.healthBar = self:DeepCopy(self.Defaults.FRIENDLY_HEALTH_BAR)
        
        -- Merge saved settings
        local dbSettings = TweaksUI.Database:GetModuleSettings(TweaksUI.MODULE_IDS.NAMEPLATES)
        if dbSettings and next(dbSettings) then
            self:DeepMerge(self.State.settings, dbSettings)
        end
        
        -- Ensure health bar settings exist
        if not self.State.settings.enemy then self.State.settings.enemy = {} end
        if not self.State.settings.enemy.healthBar then 
            self.State.settings.enemy.healthBar = self:DeepCopy(self.Defaults.HEALTH_BAR) 
        end
        if not self.State.settings.friendly then self.State.settings.friendly = {} end
        if not self.State.settings.friendly.healthBar then 
            self.State.settings.friendly.healthBar = self:DeepCopy(self.Defaults.FRIENDLY_HEALTH_BAR) 
        end
        
        -- Ensure scale settings exist
        if not self.State.settings.enemy.scale then
            self.State.settings.enemy.scale = 100
        end
        if not self.State.settings.friendly.scale then
            self.State.settings.friendly.scale = 100
        end
        
        -- Ensure text settings exist
        if not self.State.settings.enemy.nameText then
            self.State.settings.enemy.nameText = self:DeepCopy(self.Defaults.NAME_TEXT)
        end
        if not self.State.settings.enemy.healthText then
            self.State.settings.enemy.healthText = self:DeepCopy(self.Defaults.HEALTH_TEXT)
        end
        if not self.State.settings.enemy.threatText then
            self.State.settings.enemy.threatText = self:DeepCopy(self.Defaults.THREAT_TEXT)
        end
        if not self.State.settings.friendly.nameText then
            self.State.settings.friendly.nameText = self:DeepCopy(self.Defaults.NAME_TEXT)
            self.State.settings.friendly.nameText.colorMode = "class"  -- Default to class for friendlies
        end
        if not self.State.settings.friendly.healthText then
            self.State.settings.friendly.healthText = self:DeepCopy(self.Defaults.HEALTH_TEXT)
        end
        if not self.State.settings.friendly.threatText then
            self.State.settings.friendly.threatText = self:DeepCopy(self.Defaults.THREAT_TEXT)
            self.State.settings.friendly.threatText.enabled = false  -- Threat not relevant for friendlies
        end
        
        -- Ensure cast bar settings exist
        if not self.State.settings.enemy.castBar then
            self.State.settings.enemy.castBar = self:DeepCopy(self.Defaults.CAST_BAR)
        end
        if not self.State.settings.friendly.castBar then
            self.State.settings.friendly.castBar = self:DeepCopy(self.Defaults.FRIENDLY_CAST_BAR)
        end
        
        -- Ensure icons settings exist
        if not self.State.settings.enemy.icons then
            self.State.settings.enemy.icons = self:DeepCopy(self.Defaults.ICONS)
        end
        if not self.State.settings.friendly.icons then
            self.State.settings.friendly.icons = self:DeepCopy(self.Defaults.ICONS)
        end
        
        -- Ensure aura settings exist
        if not self.State.settings.enemy.auras then
            if self.GetDefaultAuraSettings then
                self.State.settings.enemy.auras = self:GetDefaultAuraSettings()
            else
                self.State.settings.enemy.auras = {enabled = false}
            end
        end
        if not self.State.settings.friendly.auras then
            -- Friendly nameplates typically don't need auras, default to disabled
            local friendlyAuras
            if self.GetDefaultAuraSettings then
                friendlyAuras = self:GetDefaultAuraSettings()
            else
                friendlyAuras = {enabled = false}
            end
            friendlyAuras.enabled = false
            self.State.settings.friendly.auras = friendlyAuras
        end
        
        self:SaveSettings()
    end
end

-- ============================================================================
-- ADDON DETECTION
-- ============================================================================

-- Check if an addon will actually load (installed, enabled, and loadable)
local function WillAddonLoad(addonName)
    -- First check if the addon exists
    if not C_AddOns.DoesAddOnExist(addonName) then
        return false
    end
    
    -- Check if the addon is already loaded
    if C_AddOns.IsAddOnLoaded(addonName) then
        return true
    end
    
    -- Check if the addon is enabled for this character
    -- GetAddOnEnableState returns: 0 = disabled, 1 = enabled for some, 2 = enabled for all
    local enableState = C_AddOns.GetAddOnEnableState(addonName)
    if enableState == 0 then
        return false  -- Addon is disabled
    end
    
    -- Check if the addon is loadable (enabled and dependencies met)
    local loadable = C_AddOns.IsAddOnLoadable(addonName)
    return loadable
end

function Nameplates:IsPlatynatorInstalled() return C_AddOns.DoesAddOnExist("Platynator") end
function Nameplates:IsPlatynatorEnabled() return WillAddonLoad("Platynator") end
function Nameplates:IsPlaterInstalled() return C_AddOns.DoesAddOnExist("Plater") end
function Nameplates:IsPlaterEnabled() return WillAddonLoad("Plater") end

-- Extended nameplate addon detection (v2.0.0)
-- Only includes addons CONFIRMED to work with Midnight 12.0
function Nameplates:IsMidnightNameplatesEnabled() return WillAddonLoad("MidnightNameplates") end

function Nameplates:IsNameplateAddonActive() 
    return self:IsPlatynatorEnabled() 
        or self:IsPlaterEnabled() 
        or self:IsMidnightNameplatesEnabled()
end

-- Get list of active nameplate addons (for warning messages)
function Nameplates:GetActiveNameplateAddons()
    local addons = {}
    if self:IsPlatynatorEnabled() then table.insert(addons, "Platynator") end
    if self:IsPlaterEnabled() then table.insert(addons, "Plater") end
    if self:IsMidnightNameplatesEnabled() then table.insert(addons, "MidnightNameplates") end
    return addons
end

-- ============================================================================
-- TEXTURE UTILITIES
-- ============================================================================

local LibSharedMedia = nil

function Nameplates:GetLSM()
    if not LibSharedMedia and LibStub then
        LibSharedMedia = LibStub("LibSharedMedia-3.0", true)
    end
    return LibSharedMedia
end

function Nameplates:GetTexturePath(textureName)
    -- Check if we should use global texture (unless override is enabled)
    local useGlobal = TweaksUI.Media and TweaksUI.Media:IsUsingGlobalTexture()
    local overrideGlobal = self.State.settings and self.State.settings.overrideGlobalTexture
    
    if useGlobal and not overrideGlobal then
        local globalTexture = TweaksUI.Media:GetGlobalTextureName()
        if globalTexture then return TweaksUI.Media:GetStatusBarTexture(globalTexture) end
    end
    
    local name = textureName or "Blizzard"
    if TweaksUI.Media then return TweaksUI.Media:GetStatusBarTexture(name) end
    local lsm = self:GetLSM()
    if lsm and lsm:IsValid("statusbar", name) then return lsm:Fetch("statusbar", name) end
    return "Interface\\TargetingFrame\\UI-StatusBar"
end

function Nameplates:GetTextureList()
    local list = {}
    local lsm = self:GetLSM()
    if lsm then
        local textures = lsm:List("statusbar")
        if textures then
            for _, name in ipairs(textures) do table.insert(list, name) end
        end
    end
    local hasBlizzard = false
    for _, name in ipairs(list) do
        if name == "Blizzard" then hasBlizzard = true break end
    end
    if not hasBlizzard then table.insert(list, 1, "Blizzard") end
    return list
end

-- ============================================================================
-- HEALTH BAR UTILITIES
-- ============================================================================

function Nameplates:GetHealthBar(unitFrame)
    if not unitFrame then return nil end
    -- Midnight (12.0+) structure
    if unitFrame.HealthBarsContainer and unitFrame.HealthBarsContainer.healthBar then
        return unitFrame.HealthBarsContainer.healthBar
    end
    -- Fallback to direct healthBar reference
    return unitFrame.healthBar
end

-- ============================================================================
-- MODULE LIFECYCLE
-- ============================================================================

local function ModifyMainHubButton()
    if not Nameplates:IsNameplateAddonActive() then return end
    local hubPanel = _G["TweaksUI_HubPanel"]
    if not hubPanel or not hubPanel.moduleRows then return end
    local ourRow = hubPanel.moduleRows[TweaksUI.MODULE_IDS.NAMEPLATES] or hubPanel.moduleRows["Nameplates"]
    if not ourRow then return end
    if ourRow.checkbox then ourRow.checkbox:Hide() end
    if ourRow.button then
        ourRow.button:Enable()
        ourRow.button:SetAlpha(1)
        ourRow.button:SetScript("OnClick", function()
            if TweaksUI.Settings and TweaksUI.Settings.OpenModuleSettings then
                TweaksUI.Settings:OpenModuleSettings(TweaksUI.MODULE_IDS.NAMEPLATES)
            end
        end)
    end
end

local function HookSettingsToggle()
    if not TweaksUI.Settings then return end
    if TweaksUI.Settings.Toggle then
        local originalToggle = TweaksUI.Settings.Toggle
        TweaksUI.Settings.Toggle = function(self, ...)
            originalToggle(self, ...)
            if Nameplates:IsNameplateAddonActive() then C_Timer.After(0.01, ModifyMainHubButton) end
        end
    end
    if TweaksUI.Settings.Show then
        local originalShow = TweaksUI.Settings.Show
        TweaksUI.Settings.Show = function(self, ...)
            originalShow(self, ...)
            if Nameplates:IsNameplateAddonActive() then C_Timer.After(0.01, ModifyMainHubButton) end
        end
    end
end

function Nameplates:OnInitialize()
    self:EnsureSettings()
    
    -- Initialize CVars defaults (from CVars.lua)
    if self.InitializeCVarDefaults then
        self:InitializeCVarDefaults()
    end
    
    if self:IsNameplateAddonActive() then
        self.State.moduleDisabledByAddon = true
        local addons = self:GetActiveNameplateAddons()
        local addonList = table.concat(addons, ", ")
        C_Timer.After(3, function()
            TweaksUI:Print("|cffff9900Nameplates module:|r " .. addonList .. " detected.")
            TweaksUI:Print("TweaksUI Nameplates settings are disabled to avoid conflicts.")
        end)
        C_Timer.After(0.1, HookSettingsToggle)
    end
end

function Nameplates:OnEnable()
    self:EnsureSettings()
    
    if not self.State.moduleDisabledByAddon then
        -- Apply CVars (from CVars.lua)
        if self.ApplyCVars then self:ApplyCVars() end
        
        -- Register events (from Events section below)
        self:RegisterEvents()
        
        -- Process existing nameplates
        for i = 1, 40 do
            local unit = "nameplate" .. i
            if UnitExists(unit) then
                local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
                if nameplate then self:EnhanceNameplate(nameplate, unit) end
            end
        end
    end
end

function Nameplates:OnDisable()
    if self.RestoreCVars then self:RestoreCVars() end
    self:UnregisterEvents()
    for nameplate in pairs(self.State.enhancedNameplates) do
        self:CleanupNameplate(nameplate)
    end
end

function Nameplates:OnProfileChanged(profileName)
    TweaksUI:PrintDebug("Nameplates OnProfileChanged:", profileName)
    self.State.settings = nil
    self:EnsureSettings()
    if self.enabled then
        if self.RefreshAllHealthBars then self:RefreshAllHealthBars() end
        if self.RefreshAllHighlights then self:RefreshAllHighlights() end
    end
end

function Nameplates:GetSettings() return self.State.settings end
function Nameplates:GetDefaults() return self.Defaults.SETTINGS end

-- ============================================================================
-- EVENT HANDLING
-- ============================================================================

local eventFrame = CreateFrame("Frame")

function Nameplates:RegisterEvents()
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    eventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    eventFrame:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
    eventFrame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
    eventFrame:RegisterEvent("UNIT_HEALTH")
end

function Nameplates:UnregisterEvents()
    eventFrame:UnregisterAllEvents()
end

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if Nameplates.State.moduleDisabledByAddon then return end
    
    if event == "NAME_PLATE_UNIT_ADDED" then
        local unit = ...
        local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
        if nameplate and Nameplates.State.settings and Nameplates.State.settings.enabled then
            Nameplates:EnhanceNameplate(nameplate, unit)
        end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local unit = ...
        local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
        if nameplate then Nameplates:CleanupNameplate(nameplate) end
    elseif event == "UNIT_HEALTH" then
        -- Update health text and health bar color (if using health gradient)
        local unit = ...
        if unit and unit:match("^nameplate") then
            local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
            if nameplate then
                local data = Nameplates.State.enhancedNameplates[nameplate]
                if data and data.unit then
                    -- Update health text
                    if Nameplates.UpdateHealthText then
                        Nameplates:UpdateHealthText(data, data.unit)
                    end
                    -- Update health bar color if using health gradient mode
                    if data.overlayHealthBar then
                        local config = Nameplates:GetHealthBarConfig(data.unit)
                        if config and config.colorMode == "health" then
                            local r, g, b = Nameplates:GetHealthBarColor(data.unit, config)
                            data.overlayHealthBar:SetStatusBarColor(r, g, b)
                        end
                    end
                end
            end
        end
    elseif event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
        -- Refresh all health bars to update target/non-target sizes and alphas
        if Nameplates.RefreshAllHealthBars then Nameplates:RefreshAllHealthBars() end
        -- Refresh cast bars to match new health bar sizes
        if Nameplates.RefreshAllCastBars then Nameplates:RefreshAllCastBars() end
        -- Refresh highlights
        if Nameplates.RefreshAllHighlights then Nameplates:RefreshAllHighlights() end
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        -- Handle mouseover from 3D model (not just nameplate frame)
        if UnitExists("mouseover") then
            local unit = "mouseover"
            if Nameplates.SetMouseoverFromUnit then
                Nameplates:SetMouseoverFromUnit(unit)
            end
        end
        -- Note: Clearing is handled by the polling frame in Highlights.lua
    elseif event == "UNIT_THREAT_LIST_UPDATE" or event == "UNIT_THREAT_SITUATION_UPDATE" then
        -- Refresh health bar colors and threat text when threat changes
        local unit = ...
        if unit and unit:match("^nameplate") then
            local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
            if nameplate then
                local data = Nameplates.State.enhancedNameplates[nameplate]
                if data and data.unit then
                    -- Update health bar color if using threat mode
                    if data.overlayHealthBar then
                        local config = Nameplates:GetHealthBarConfig(data.unit)
                        if config and config.colorMode == "threat" then
                            local r, g, b = Nameplates:GetHealthBarColor(data.unit, config)
                            data.overlayHealthBar:SetStatusBarColor(r, g, b)
                        end
                    end
                    -- Update threat text
                    if Nameplates.OnThreatUpdate then
                        Nameplates:OnThreatUpdate(data, data.unit)
                    end
                end
            end
        else
            -- No specific unit, refresh all nameplates with threat coloring
            for np, data in pairs(Nameplates.State.enhancedNameplates) do
                if data.unit then
                    -- Update health bar color if using threat mode
                    if data.overlayHealthBar then
                        local config = Nameplates:GetHealthBarConfig(data.unit)
                        if config and config.colorMode == "threat" then
                            local r, g, b = Nameplates:GetHealthBarColor(data.unit, config)
                            data.overlayHealthBar:SetStatusBarColor(r, g, b)
                        end
                    end
                    -- Update threat text
                    if Nameplates.OnThreatUpdate then
                        Nameplates:OnThreatUpdate(data, data.unit)
                    end
                end
            end
        end
    end
end)

-- ============================================================================
-- NAMEPLATE ENHANCEMENT (orchestrates all enhancements)
-- ============================================================================

function Nameplates:EnhanceNameplate(nameplate, unit)
    if not nameplate or not nameplate.UnitFrame then return end
    
    local data = self.State.enhancedNameplates[nameplate]
    if not data then
        data = {}
        -- Create highlight frame if Highlights module is loaded
        if self.CreateHighlightFrame then
            data.highlight = self:CreateHighlightFrame(nameplate)
        end
        data.nameplate = nameplate
        self.State.enhancedNameplates[nameplate] = data
        
        -- Mouse handling: We make our overlay frames completely mouse-transparent
        -- (SetHitRectInsets + EnableMouse(false)) so Blizzard's UnitFrame receives
        -- all clicks and hover events. We track mouseover via UPDATE_MOUSEOVER_UNIT
        -- event which fires when the player mouses over any unit.
    end
    data.unit = unit
    
    -- Apply health bar enhancements (from HealthBars.lua)
    if self.EnhanceHealthBar then
        self:EnhanceHealthBar(nameplate, unit, data)
    end
    
    -- Apply text elements (from TextElements.lua)
    if self.UpdateAllTexts then
        self:UpdateAllTexts(data, unit)
    end
    
    -- Apply highlights (from Highlights.lua)
    if self.UpdateHighlights then
        self:UpdateHighlights(nameplate, unit)
    end
    
    -- Apply cast bar (from CastBars.lua)
    if self.CreateCastBar and data.overlayHealthBar then
        local configKey = UnitIsFriend("player", unit) and "friendly" or "enemy"
        local config = self.State.settings[configKey] and self.State.settings[configKey].castBar
        
        if config and config.enabled then
            if not data.castBar then
                data.castBar = self:CreateCastBar(nameplate, data)
            end
            self:PositionCastBar(data.castBar, data.overlayHealthBar, config, configKey)
            self:SetupCastBarEvents(data, unit)
            -- Hide Blizzard's cast bar
            if self.HideBlizzardCastBar then
                self:HideBlizzardCastBar(nameplate, data)
            end
            -- Check if currently casting
            self:UpdateCastBar(data.castBar, unit, config, configKey)
        elseif data.castBar then
            data.castBar:Hide()
            self:ClearCastBarEvents(data)
            -- Show Blizzard's cast bar again if we disabled ours
            if self.ShowBlizzardCastBar then
                self:ShowBlizzardCastBar(nameplate, data)
            end
        end
    end
    
    -- Apply icons (from Icons.lua)
    if self.UpdateNameplateIcons then
        self:UpdateNameplateIcons(nameplate, data, unit)
    end
    
    -- Apply auras (from Auras.lua)
    if self.UpdateAuras then
        self:UpdateAuras(nameplate, unit, data)
    end
end

function Nameplates:CleanupNameplate(nameplate)
    local data = self.State.enhancedNameplates[nameplate]
    if data then
        -- Hide highlight
        if self.HideHighlight and data.highlight then
            self:HideHighlight(data.highlight)
        end
        -- Clean up cast bar and restore Blizzard's
        if self.ClearCastBarEvents and data.castBar then
            self:ClearCastBarEvents(data)
        end
        if self.ShowBlizzardCastBar and data.blizzCastBarHidden then
            self:ShowBlizzardCastBar(nameplate, data)
        end
        -- Clean up icons
        if self.CleanupNameplateIcons then
            self:CleanupNameplateIcons(data)
        end
        -- Clean up health bar overlay
        if self.CleanupHealthBar then
            self:CleanupHealthBar(data)
        end
        -- Legacy cleanup for old approach
        if data.healthBarBg then data.healthBarBg:Hide() end
        if data.healthBarBorder then data.healthBarBorder:Hide() end
    end
end

-- ============================================================================
-- REFRESH HELPERS
-- ============================================================================

function Nameplates:RefreshAllNameplates()
    if not self.State or not self.State.enhancedNameplates then return end
    
    for nameplate, data in pairs(self.State.enhancedNameplates) do
        if data.unit then
            self:EnhanceNameplate(nameplate, data.unit)
        end
    end
    
    -- Also refresh simulations so preview matches settings
    self:RefreshAllSimulations()
end
