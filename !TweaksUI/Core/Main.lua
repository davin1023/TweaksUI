-- TweaksUI Main
-- Core addon initialization and slash commands

local ADDON_NAME, TweaksUI = ...

-- Make TweaksUI accessible globally
_G.TweaksUI = TweaksUI

-- Print helper
function TweaksUI:Print(message)
    print(TweaksUI.CHAT_PREFIX .. message)
end

function TweaksUI:PrintError(message)
    print(TweaksUI.CHAT_PREFIX .. "|cffff0000" .. message .. "|r")
end

function TweaksUI:PrintDebug(message)
    if self.debugMode then
        print(TweaksUI.CHAT_PREFIX .. "|cff888888[DEBUG]|r " .. message)
    end
end

-- Central helper to toggle the main TweaksUI settings hub
function TweaksUI:ToggleSettings()
    if self.Settings and self.Settings.Toggle then
        self.Settings:Toggle()
    else
        self:PrintError("Settings UI not ready yet. Try again in a moment.")
    end
end

-- Debug mode
TweaksUI.debugMode = false

-- Force all visibility conditions to be bypassed (everything visible)
-- Load from database if previously set
TweaksUI.forceAllVisible = false  -- Will be loaded from DB after init

function TweaksUI:SetDebugMode(enabled)
    self.debugMode = enabled
    self:Print("Debug mode " .. (enabled and "enabled" or "disabled"))
end

-- Toggle force-all-visible mode (bypasses all visibility conditions)
function TweaksUI:SetForceAllVisible(enabled, silent)
    self.forceAllVisible = enabled
    
    -- Save to database so it persists across reloads
    if self.Database then
        self.Database:SetGlobal("forceAllVisible", enabled)
    end
    
    if not silent then
        if enabled then
            self:Print("|cff00ff00All visibility conditions BYPASSED|r - everything is now visible")
            self:Print("Use |cffffff00/tui showall|r again to restore normal visibility")
        else
            self:Print("|cffff9900Visibility conditions RESTORED|r - normal visibility rules apply")
        end
    end
    
    -- Trigger visibility updates in all modules that have visibility systems
    
    -- UnitFrames
    local UnitFrames = self.ModuleManager and self.ModuleManager:GetModule("UnitFrames")
    if UnitFrames and UnitFrames.RefreshAllVisibility then
        UnitFrames:RefreshAllVisibility()
    end
    
    -- Cooldowns
    local Cooldowns = self.ModuleManager and self.ModuleManager:GetModule("Cooldowns")
    if Cooldowns and Cooldowns.UpdateAllTrackerVisibility then
        Cooldowns:UpdateAllTrackerVisibility()
    end
    
    -- ActionBars
    local ActionBars = self.ModuleManager and self.ModuleManager:GetModule("ActionBars")
    if ActionBars and ActionBars.RefreshAllVisibility then
        ActionBars:RefreshAllVisibility()
    end
    
    -- PersonalResources
    local PersonalResources = self.ModuleManager and self.ModuleManager:GetModule("PersonalResources")
    if PersonalResources and PersonalResources.RefreshAllBars then
        PersonalResources:RefreshAllBars()
    end
    
    -- General (UI frame visibility)
    local General = self.ModuleManager and self.ModuleManager:GetModule("General")
    if General and General.ApplyAllVisibility then
        General:ApplyAllVisibility()
    end
end

-- Load forceAllVisible state from database (called after DB is ready)
function TweaksUI:LoadForceAllVisibleState()
    if self.Database then
        local saved = self.Database:GetGlobal("forceAllVisible")
        if saved then
            self.forceAllVisible = true
            -- Apply after a short delay to let modules initialize
            C_Timer.After(2, function()
                self:SetForceAllVisible(true, true)  -- silent=true, don't print messages on load
                self:Print("|cff00ff00Show All mode is ACTIVE|r - use /tui showall to disable")
            end)
        end
    end
end

-- ============================================================================
-- WELCOME SCREEN
-- ============================================================================

local welcomeFrame = nil

function TweaksUI:ShowWelcomeScreen(forceShow)
    -- Check if we should skip showing (only on auto-show, not manual)
    local welcomeShown = self.Database:GetGlobal("welcomeShown")
    if not forceShow and welcomeShown then
        return
    end
    
    -- Don't create multiple frames
    if welcomeFrame and welcomeFrame:IsShown() then
        return
    end
    
    -- Create the frame
    local frame = CreateFrame("Frame", "TweaksUI_WelcomeFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(550, 580)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    
    -- Allow ESC to close
    tinsert(UISpecialFrames, "TweaksUI_WelcomeFrame")
    
    -- Title
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOP", 0, -5)
    frame.title:SetText("Welcome to TweaksUI!")
    
    -- Version
    local versionText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    versionText:SetPoint("TOP", 0, -28)
    versionText:SetText("|cff00ff00Version " .. TweaksUI.VERSION .. "|r")
    
    -- Scroll frame for content
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 12, -50)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 55)
    
    -- Enable mouse wheel scrolling
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        local step = 60
        if delta > 0 then
            self:SetVerticalScroll(math.max(0, current - step))
        else
            self:SetVerticalScroll(math.min(maxScroll, current + step))
        end
    end)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(490, 800)
    scrollFrame:SetScrollChild(scrollChild)
    
    -- Content
    local content = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    content:SetPoint("TOPLEFT", 5, -5)
    content:SetWidth(480)
    content:SetJustifyH("LEFT")
    content:SetSpacing(3)
    
    local welcomeText = [[
|cffFFD700What is TweaksUI?|r

TweaksUI enhances Blizzard's default UI without replacing it. Unlike total conversion addons, TweaksUI works |cffFFFFFFwith|r Blizzard's frames - giving you customization options while keeping the native look and feel.

Each module can be enabled or disabled independently, so you only use what you need.


|cffFFD700Getting Started|r

  |cff00FF00-|r Type |cffFFFFFF/tui|r to open the settings hub
  |cff00FF00-|r Enable modules using the checkboxes
  |cff00FF00-|r Click module names to open their settings


|cffFFD700Tips & Tricks|r

|cff87CEEB>|r |cffFFFFFFProfiles:|r Create different setups for different characters or specs. Access via the Profiles button in the hub.

|cff87CEEB>|r |cffFFFFFFImport/Export:|r Share your settings between characters or with friends. Find it in the Import/Export panel.

|cff87CEEB>|r |cffFFFFFFEdit Mode Integration:|r Many TweaksUI frames work with WoW's Edit Mode for positioning.

|cff87CEEB>|r |cffFFFFFFVisibility Controls:|r Most modules let you show/hide elements based on combat, group, or mouseover.


|cffFFD700Module Overview|r

|cffFFFFFFAction Bars|r - Customize button size, spacing, rows/columns, and visibility per bar.

|cffFFFFFFCast Bars|r - Style player, target, and focus cast bars with consistent visuals.

|cffFFFFFFChat|r - Custom chat frames, button fading, timestamps, and more.

|cffFFFFFFCooldown Trackers|r - Enhanced layouts and visibility for Blizzard's cooldown trackers.

|cffFFFFFFNameplates|r - |cffFF8800See recommendation below.|r

|cffFFFFFFResource Bars|r - Customize class resource displays (combo points, soul shards, etc).

|cffFFFFFFUnit Frames|r - Style player, target, focus, pet, party, raid, tank, and boss frames.


|cffFFD700About Nameplates|r

While TweaksUI includes a Nameplates module, we recommend using |cff00FF00Plater|r or |cff00FF00Platynator|r for nameplates instead.

|cff888888Why? Nameplate addons like Plater offer threat coloring, cast bar customization, debuff tracking, and extensive scripting that would take significant development to replicate. Our module provides basic enhancements, but dedicated nameplate addons are more mature and feature-complete.|r


|cffFFD700Helpful Commands|r

  |cffFFFFFF/tui|r - Open settings
  |cffFFFFFF/tui welcome|r - Show this screen again
  |cffFFFFFF/tui help|r - List all commands
  |cffFFFFFF/rl|r - Reload UI
  |cffFFFFFF/tuil|r - Toggle Layout Mode
  |cffFFFFFF/cdm|r - Open Blizzard's Cooldown Settings


|cffFFD700Feedback & Support|r

TweaksUI is actively developed. If you encounter issues or have suggestions, please reach out via CurseForge.

|cff888888Thank you for trying TweaksUI!|r
]]
    
    content:SetText(welcomeText)
    
    -- Adjust scroll child height based on content
    local textHeight = content:GetStringHeight()
    scrollChild:SetHeight(math.max(500, textHeight + 20))
    
    -- Scroll hint
    local scrollHint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scrollHint:SetPoint("BOTTOM", 0, 38)
    scrollHint:SetText("|cff888888Scroll down to read more|r")
    
    -- Buttons
    local openSettingsBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    openSettingsBtn:SetSize(120, 25)
    openSettingsBtn:SetPoint("BOTTOMLEFT", 15, 12)
    openSettingsBtn:SetText("Open Settings")
    openSettingsBtn:SetScript("OnClick", function()
        TweaksUI.Database:SetGlobal("welcomeShown", true)
        frame:Hide()
        TweaksUI:ToggleSettings()
    end)
    
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeBtn:SetSize(100, 25)
    closeBtn:SetPoint("BOTTOMRIGHT", -15, 12)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function()
        TweaksUI.Database:SetGlobal("welcomeShown", true)
        frame:Hide()
        TweaksUI:Print("Type |cffFFFFFF/tui|r anytime to open settings, or |cffFFFFFF/tui welcome|r to see this again.")
    end)
    
    frame.CloseButton:SetScript("OnClick", function()
        TweaksUI.Database:SetGlobal("welcomeShown", true)
        frame:Hide()
    end)
    
    welcomeFrame = frame
    frame:Show()
end

-- ============================================================================
-- PATCH NOTES DISPLAY
-- ============================================================================

local patchNotesFrame

function TweaksUI:ShowPatchNotes(forceShow)
    -- Don't create multiple frames
    if patchNotesFrame and patchNotesFrame:IsShown() then
        return
    end
    
    -- Create the frame
    local frame = CreateFrame("Frame", "TweaksUI_PatchNotesFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(550, 550)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    
    -- Allow ESC to close
    tinsert(UISpecialFrames, "TweaksUI_PatchNotesFrame")
    
    -- Title
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOP", 0, -5)
    frame.title:SetText("TweaksUI - What's New")
    
    -- Version
    local versionText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    versionText:SetPoint("TOP", 0, -28)
    versionText:SetText("|cff00ff00Version " .. TweaksUI.VERSION .. "|r")
    
    -- Scroll frame for content
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 12, -50)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 55)
    
    -- Enable mouse wheel scrolling
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        local step = 60
        if delta > 0 then
            self:SetVerticalScroll(math.max(0, current - step))
        else
            self:SetVerticalScroll(math.min(maxScroll, current + step))
        end
    end)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(490, 1200)
    scrollFrame:SetScrollChild(scrollChild)
    
    -- Content
    local content = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    content:SetPoint("TOPLEFT", 5, -5)
    content:SetWidth(480)
    content:SetJustifyH("LEFT")
    content:SetSpacing(3)
    
    local patchNotesText = [[
|cffFFD700Version 2.0.0 - Midnight Native|r

|cffFF6B6BIMPORTANT:|r This version requires Midnight (12.0.0+).
For The War Within, use TweaksUI 1.9.x from CurseForge.


|cff00FF00Duration Objects|r

  |cff87CEEB-|r All cooldowns use Midnight's native Duration Object system
  |cff87CEEB-|r More accurate tracking and smoother visual updates
  |cff87CEEB-|r Cast bars use timer status bars with auto-updates


|cff00FF00Smooth Status Bars|r

  |cff87CEEB-|r Health, power, and cast bars animate smoothly
  |cff87CEEB-|r Native StatusBar interpolation (ExponentialEaseOut)
  |cff87CEEB-|r Reduced CPU usage from animation code


|cff00FF00Secret Value Support|r

  |cff87CEEB-|r Full compatibility with Midnight's addon restrictions
  |cff87CEEB-|r Graceful handling during M+, raids, and PvP
  |cff87CEEB-|r No more "attempt to compare secret value" errors


|cff00FF00Aura System Improvements|r

  |cff87CEEB-|r Native sorting by expiration, name, or index
  |cff87CEEB-|r Efficient iteration via GetUnitAuraInstanceIDs()
  |cff87CEEB-|r Improved dispel type detection and coloring


|cff00FF00Curve System|r

  |cff87CEEB-|r Color curves for health bars (red to green gradient)
  |cff87CEEB-|r Cooldown color coding based on remaining time
  |cff87CEEB-|r Pre-built curves for common use cases


|cff00FF00Restriction Monitoring|r

  |cff87CEEB-|r Track when addon restrictions are active
  |cff87CEEB-|r Combat, Encounter, M+, PvP awareness
  |cff87CEEB-|r UI responds appropriately to state changes


|cff00FF00New API Wrapper System|r

  |cff87CEEB-|r SpellAPI - Duration Object support for cooldowns
  |cff87CEEB-|r AuraAPI - Sorting and instance ID iteration
  |cff87CEEB-|r UnitAPI - Health, power, unit comparison
  |cff87CEEB-|r StatusBarAPI - Smooth bars and timers
  |cff87CEEB-|r CurveAPI - Color curve creation


|cff00FF00Debug Commands|r

  |cff87CEEB-|r /tuiapi - Print API availability status
  |cff87CEEB-|r /tuirestrict - Print restriction states


|cffFF6B6BRemoved|r

  |cff87CEEB-|r All TWW/legacy fallback code
  |cff87CEEB-|r Feature detection flags (HAS_* variables)
  |cff87CEEB-|r Legacy GetSpellInfo/UnitAura patterns


|cff00FF00Migrating from 1.9.x|r

  |cff87CEEB-|r Settings preserved automatically
  |cff87CEEB-|r Profile data is compatible
  |cff87CEEB-|r No manual steps required


|cff888888/tui patchnotes - Show this again|r
]]
    
    content:SetText(patchNotesText)
    
    -- Adjust scroll child height based on content
    local textHeight = content:GetStringHeight()
    scrollChild:SetHeight(math.max(500, textHeight + 20))
    
    -- Scroll hint
    local scrollHint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scrollHint:SetPoint("BOTTOM", 0, 38)
    scrollHint:SetText("|cff888888Scroll down to read more|r")
    
    -- Buttons
    local openSettingsBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    openSettingsBtn:SetSize(120, 25)
    openSettingsBtn:SetPoint("BOTTOMLEFT", 15, 12)
    openSettingsBtn:SetText("Open Settings")
    openSettingsBtn:SetScript("OnClick", function()
        frame:Hide()
        TweaksUI:ToggleSettings()
    end)
    
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeBtn:SetSize(100, 25)
    closeBtn:SetPoint("BOTTOMRIGHT", -15, 12)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
    end)
    
    frame.CloseButton:SetScript("OnClick", function()
        frame:Hide()
    end)
    
    patchNotesFrame = frame
    frame:Show()
end

-- Helper function to load Basic profile and reload
function TweaksUI:LoadBasicProfile()
    if TweaksUI.DefaultProfiles then
        local basicProfile = TweaksUI.DefaultProfiles:GetProfile("Basic 1440")
        if basicProfile and TweaksUI.Profiles then
            TweaksUI:Print("Loading Basic profile...")
            local success = TweaksUI.Profiles:ApplySettings(basicProfile, true)
            if success then
                -- Save as "Basic - CharacterName" so user has their own copy
                local charName = UnitName("player") or "Unknown"
                local profileName = "Basic - " .. charName
                local currentSettings = TweaksUI.Profiles:GetCurrentSettings()
                TweaksUI.Profiles:SaveProfile(profileName, currentSettings)
                TweaksUI:Print("Saved as profile: " .. profileName)
                
                -- Prompt for reload
                StaticPopupDialogs["TWEAKSUI_BASIC_RELOAD_PROMPT"] = {
                    text = "Basic profile loaded and saved as '" .. profileName .. "'!\n\nReload UI now to apply all changes?",
                    button1 = "Reload Now",
                    button2 = "Later",
                    OnAccept = function()
                        ReloadUI()
                    end,
                    timeout = 0,
                    whileDead = true,
                    hideOnEscape = true,
                    preferredIndex = 3,
                }
                StaticPopup_Show("TWEAKSUI_BASIC_RELOAD_PROMPT")
            else
                TweaksUI:PrintError("Failed to load Basic profile")
            end
        else
            TweaksUI:PrintError("Basic profile not available")
        end
    end
end

-- Simple popup for new characters after Basic profile auto-load
function TweaksUI:ShowBasicProfileReloadPopup()
    StaticPopupDialogs["TWEAKSUI_BASIC_RELOAD"] = {
        text = "|cffFFD100TweaksUI|r\n\nThe Basic profile has been loaded for your new character!\n\nReload your UI to apply it.\n\n|cff888888You can disable any modules you don't want in the settings after reloading.|r",
        button1 = "Reload Now",
        button2 = "Later",
        OnAccept = function()
            ReloadUI()
        end,
        OnCancel = function()
            TweaksUI:Print("Remember to /reload when you're ready to apply the Basic profile!")
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("TWEAKSUI_BASIC_RELOAD")
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")

local addonLoaded = false
local playerLoggedIn = false

local function Initialize()
    if not addonLoaded or not playerLoggedIn then
        return
    end
    
    TweaksUI:PrintDebug("Initializing v" .. TweaksUI.VERSION)
    
    -- Initialize database
    TweaksUI.Database:Initialize()
    
    -- Initialize GlobalScale for settings panel scaling (2.0.0+)
    if TweaksUI.GlobalScale then
        TweaksUI.GlobalScale:Initialize()
    end
    
    -- Initialize Profiles system (1.5.0+)
    if TweaksUI.Profiles then
        TweaksUI.Profiles:Initialize()
        -- Run migration from 1.4.0 to 1.5.0 profile system
        TweaksUI.Profiles:MigrateFrom_1_4_0()
    end
    
    -- Initialize Presets system (1.5.0+)
    if TweaksUI.Presets then
        TweaksUI.Presets:Initialize()
    end
    
    -- Initialize ProfileImportExport system (1.5.0+)
    if TweaksUI.ProfileImportExport then
        TweaksUI.ProfileImportExport:Initialize()
    end
    
    -- Initialize DefaultProfiles system (1.7.3+) - must be after PIE
    if TweaksUI.DefaultProfiles then
        TweaksUI.DefaultProfiles:Initialize()
    end
    
    -- ========================================================================
    -- SETUP VALIDATION (2.0.0+)
    -- Must run BEFORE any profiles are applied or modules loaded
    -- ========================================================================
    
    -- Check if coming from setup reload (legacy flow)
    local applyProfileFromSetup = TweaksUI_CharDB and TweaksUI_CharDB.applyProfileOnReload
    
    -- Function to apply a profile and continue loading
    local function ApplyProfileAndContinue(profileName)
        local profile = nil
        local isBuiltIn = false
        
        -- First check built-in profiles
        if TweaksUI.DefaultProfiles then
            profile = TweaksUI.DefaultProfiles:GetProfile(profileName)
            if profile then
                isBuiltIn = true
            end
        end
        
        -- If not built-in, check user-saved profiles
        if not profile and TweaksUI_DB and TweaksUI_DB.profiles then
            profile = TweaksUI_DB.profiles[profileName]
        end
        
        if profile then
            TweaksUI:Print("Applying " .. profileName .. " profile" .. (isBuiltIn and " (built-in)" or "") .. "...")
            
            -- Apply module settings
            if profile.modules then
                TweaksUI_CharDB.settings = TweaksUI_CharDB.settings or {}
                for moduleId, moduleSettings in pairs(profile.modules) do
                    TweaksUI_CharDB.settings[moduleId] = moduleSettings
                end
            end
            
            -- Apply enabled states
            if profile.enabled then
                TweaksUI_CharDB.modules = TweaksUI_CharDB.modules or {}
                for moduleId, enabled in pairs(profile.enabled) do
                    TweaksUI_CharDB.modules[moduleId] = enabled
                end
            end
            
            -- Apply container positions
            if profile.uiFrameContainerPositions then
                TweaksUI_CharDB.uiFrameContainerPositions = profile.uiFrameContainerPositions
            end
            if profile.actionBarContainerPositions then
                TweaksUI_CharDB.actionBarContainerPositions = profile.actionBarContainerPositions
            end
            
            -- Mark that a TUI profile has been applied
            TweaksUI_CharDB.tuiProfileApplied = true
        else
            TweaksUI:Print("Could not find profile: " .. profileName .. ", using Basic 1440...")
            -- Fallback to Basic 1440
            if TweaksUI.DefaultProfiles then
                profile = TweaksUI.DefaultProfiles:GetProfile("Basic 1440")
                if profile then
                    TweaksUI_CharDB.settings = TweaksUI_CharDB.settings or {}
                    if profile.modules then
                        for moduleId, moduleSettings in pairs(profile.modules) do
                            TweaksUI_CharDB.settings[moduleId] = moduleSettings
                        end
                    end
                    if profile.enabled then
                        TweaksUI_CharDB.modules = TweaksUI_CharDB.modules or {}
                        for moduleId, enabled in pairs(profile.enabled) do
                            TweaksUI_CharDB.modules[moduleId] = enabled
                        end
                    end
                    TweaksUI_CharDB.tuiProfileApplied = true
                end
            end
        end
    end
    
    -- Function to continue with full module loading
    local function ContinueModuleLoading()
        -- Mark firstRun complete
        if TweaksUI_CharDB then
            TweaksUI_CharDB.firstRun = false
        end
        
        -- Initialize media
        TweaksUI.Media:Initialize()
        
        -- Initialize SnapLocking system (1.5.1+)
        if TweaksUI.SnapLocking then
            TweaksUI.SnapLocking:Initialize()
        end
        
        -- Initialize General module FIRST (not a standard module, always active)
        if TweaksUI.General then
            TweaksUI.General:Initialize()
        end
        
        -- Initialize all modules
        TweaksUI.ModuleManager:InitializeAll()
        
        -- Enable modules that should be enabled
        TweaksUI.ModuleManager:EnableAll()
        
        -- Apply all saved attachments now that all frames are created (1.5.1+)
        if TweaksUI.SnapLocking then
            C_Timer.After(2, function()
                TweaksUI.SnapLocking:ApplyAllAttachments()
            end)
            C_Timer.After(5, function()
                TweaksUI.SnapLocking:ApplyAllAttachments()
            end)
        end
        
        -- Register module presets after all modules are loaded (1.5.0+)
        if TweaksUI.RegisterModulePresets then
            TweaksUI:RegisterModulePresets()
        end
        
        TweaksUI:PrintDebug("Module loading complete")
    end
    
    -- ========================================================================
    -- MODULE LOADING & SETUP WIZARD
    -- ========================================================================
    
    -- Handle profile from setup reload (legacy flow)
    if applyProfileFromSetup then
        TweaksUI:PrintDebug("Applying profile from setup reload: " .. tostring(applyProfileFromSetup))
        local profileToApply = applyProfileFromSetup
        TweaksUI_CharDB.applyProfileOnReload = nil
        ApplyProfileAndContinue(profileToApply)
    end
    
    -- Handle pending profile from setup wizard (2.0.0+)
    if TweaksUI_DB and TweaksUI_DB.pendingProfile then
        local profileToApply = TweaksUI_DB.pendingProfile
        TweaksUI_DB.pendingProfile = nil  -- Clear so it doesn't apply again
        TweaksUI:PrintDebug("Applying pending profile from setup wizard: " .. tostring(profileToApply))
        ApplyProfileAndContinue(profileToApply)
        
        -- Mark profile as loaded for this character
        if TweaksUI_CharDB then
            TweaksUI_CharDB.profileLoaded = profileToApply
        end
    end
    
    -- Always load modules
    ContinueModuleLoading()
    
    -- Initialize setup wizard (shows on first run)
    if TweaksUI.SetupWizard then
        TweaksUI.SetupWizard:Initialize()
    end
    
    -- Check if this is a new version or first install
    local lastSeen = TweaksUI.Database:GetGlobal("lastSeenVersion")
    
    if lastSeen ~= TweaksUI.VERSION then
        TweaksUI.Database:SetGlobal("lastSeenVersion", TweaksUI.VERSION)
        
        -- Only show welcome/patch notes if wizard won't show
        if not (TweaksUI.SetupWizard and TweaksUI.SetupWizard:ShouldShow()) then
            if not lastSeen then
                -- First install - show welcome screen after a short delay
                C_Timer.After(2, function()
                    TweaksUI:ShowWelcomeScreen()
                end)
            else
                -- Updated from previous version - show patch notes
                C_Timer.After(2, function()
                    TweaksUI:ShowPatchNotes()
                end)
            end
        end
    end
    
    -- Load forceAllVisible state from database (1.7.2+)
    TweaksUI:LoadForceAllVisibleState()
    
    TweaksUI:Print("Loaded - Type |cffFFFFFF/tui|r to open settings")
end

initFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        addonLoaded = true
        Initialize()
    elseif event == "PLAYER_LOGIN" then
        playerLoggedIn = true
        Initialize()
    end
end)

-- Spec change handling for profile switching
local specFrame = CreateFrame("Frame")
specFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
specFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
specFrame:SetScript("OnEvent", function(self, event, unit)
    -- Only handle player spec changes
    if event == "PLAYER_SPECIALIZATION_CHANGED" and unit ~= "player" then
        return
    end
    
    -- Use new Profiles system for spec switching (1.5.0+)
    if TweaksUI.Profiles and TweaksUI.Profiles.OnSpecChanged then
        TweaksUI.Profiles:OnSpecChanged()
    end
end)

-- ============================================================================
-- PLAYER_LOGOUT CLEANUP
-- Restore all Blizzard frames to their original parents/positions before logout
-- This prevents "Couldn't find region" errors if user removes addon
-- ============================================================================

local logoutFrame = CreateFrame("Frame")
logoutFrame:RegisterEvent("PLAYER_LOGOUT")
logoutFrame:SetScript("OnEvent", function()
    TweaksUI:PrintDebug("PLAYER_LOGOUT: Restoring Blizzard frames...")
    
    -- Restore Action Bar buttons and system bars
    if TweaksUI.ActionBars and TweaksUI.ActionBars.OnDisable then
        pcall(function()
            TweaksUI.ActionBars:OnDisable()
        end)
    end
    
    -- Restore Minimap to Blizzard's control
    if TweaksUI.MinimapFrame and TweaksUI.MinimapFrame.Disable then
        pcall(function()
            TweaksUI.MinimapFrame:Disable()
        end)
    end
    
    -- Restore Chat frames to Blizzard's control (Chat uses ModuleManager pattern)
    local chatModule = TweaksUI.ModuleManager and TweaksUI.ModuleManager:GetModule(TweaksUI.MODULE_IDS.CHAT)
    if chatModule and chatModule.ShowBlizzardChat then
        pcall(function()
            chatModule:ShowBlizzardChat()
        end)
    end
    
    -- Restore all docked icons to their original positions
    if TweaksUI.Docks and TweaksUI.Docks.RestoreAllDockedIcons then
        pcall(function()
            TweaksUI.Docks:RestoreAllDockedIcons()
        end)
    end
    
    -- Restore Personal Resources frames
    if TweaksUI.PersonalResources and TweaksUI.PersonalResources.OnDisable then
        pcall(function()
            TweaksUI.PersonalResources:OnDisable()
        end)
    end
    
    TweaksUI:PrintDebug("PLAYER_LOGOUT: Blizzard frames restored")
end)

-- ============================================================================
-- DIALOGUEUI COMPATIBILITY FIX
-- DialogueUI can leave invisible frames that still capture mouse input
-- This cleans them up when quest/gossip interactions end
-- ============================================================================

-- Monitor UIParent visibility changes to detect DialogueUI interaction
local uiParentWatcher = CreateFrame("Frame")
uiParentWatcher.lastShown = UIParent:IsShown()
uiParentWatcher.lastAlpha = UIParent:GetAlpha()

-- Hook UIParent:Show and UIParent:Hide to catch DialogueUI toggling
hooksecurefunc(UIParent, "Show", function()
    if not uiParentWatcher.lastShown then
        TweaksUI:PrintDebug("UIParent:Show() called - DialogueUI likely closing")
        -- Schedule cleanup after UIParent is restored
        C_Timer.After(0.2, function()
            if TweaksUI.CleanupInvisibleMouseBlockers then
                local cleaned = TweaksUI.CleanupInvisibleMouseBlockers()
                if cleaned > 0 then
                    TweaksUI:PrintDebug("Post-UIParent cleanup: fixed " .. cleaned .. " frames")
                end
            end
        end)
    end
    uiParentWatcher.lastShown = true
end)

hooksecurefunc(UIParent, "Hide", function()
    TweaksUI:PrintDebug("UIParent:Hide() called - DialogueUI likely opening")
    uiParentWatcher.lastShown = false
end)

-- Also hook SetShown which DialogueUI uses
hooksecurefunc(UIParent, "SetShown", function(self, shown)
    if shown and not uiParentWatcher.lastShown then
        TweaksUI:PrintDebug("UIParent:SetShown(true) called")
        C_Timer.After(0.2, function()
            if TweaksUI.CleanupInvisibleMouseBlockers then
                TweaksUI.CleanupInvisibleMouseBlockers()
            end
            -- Also reset TweaksUI mouseover frames
            if TweaksUI.UnitFramesVisibilityManager and TweaksUI.UnitFramesVisibilityManager.ResetAllMouseoverFrames then
                TweaksUI.UnitFramesVisibilityManager:ResetAllMouseoverFrames()
                TweaksUI:PrintDebug("Reset TweaksUI mouseover frames after UIParent restore")
            end
        end)
    elseif not shown then
        TweaksUI:PrintDebug("UIParent:SetShown(false) called")
    end
    uiParentWatcher.lastShown = shown
end)

-- Watch for frames that might be getting stuck after UIParent toggles
-- This runs a thorough check for any frames with corrupted mouse state
local function DeepMouseStateCleanup()
    local fixed = 0
    
    -- Check all UIParent children for frames that are:
    -- 1. Visible
    -- 2. Have mouse enabled
    -- 3. Are at BACKGROUND strata (shouldn't be blocking)
    -- 4. Are large enough to block significant screen area
    local children = {UIParent:GetChildren()}
    for _, child in ipairs(children) do
        pcall(function()
            if child:IsVisible() and child:IsMouseEnabled() then
                local strata = child:GetFrameStrata()
                local width = child:GetWidth()
                local height = child:GetHeight()
                local name = child:GetName() or ""
                
                -- BACKGROUND strata frames with mouse enabled are suspicious
                if strata == "BACKGROUND" and width > 100 and height > 100 then
                    -- Don't touch WorldFrame or essential Blizzard frames
                    if name ~= "WorldFrame" and not name:find("^Blizzard") then
                        child:EnableMouse(false)
                        fixed = fixed + 1
                        TweaksUI:PrintDebug("DeepCleanup: Disabled mouse on " .. name .. " [" .. strata .. "]")
                    end
                end
            end
        end)
    end
    
    return fixed
end

TweaksUI.DeepMouseStateCleanup = DeepMouseStateCleanup

local function CleanupInvisibleMouseBlockers()
    local cleaned = 0
    
    -- Don't run during combat - protected frames will block
    if InCombatLockdown() then
        return 0
    end
    
    -- Known protected Blizzard frames that we must never touch
    local protectedFrames = {
        PlayerFrame = true,
        TargetFrame = true,
        FocusFrame = true,
        PetFrame = true,
        PartyMemberFrame1 = true,
        PartyMemberFrame2 = true,
        PartyMemberFrame3 = true,
        PartyMemberFrame4 = true,
        CompactRaidFrameContainer = true,
        CompactRaidFrameManager = true,
        MainMenuBar = true,
        MultiBarBottomLeft = true,
        MultiBarBottomRight = true,
        MultiBarRight = true,
        MultiBarLeft = true,
        StanceBar = true,
        PossessBar = true,
        PetActionBar = true,
        MinimapCluster = true,
        Minimap = true,
        BuffFrame = true,
        DebuffFrame = true,
    }
    
    -- Helper to check if a frame is protected/secure
    local function IsFrameProtected(frame)
        if not frame then return true end
        -- Safely get name - some frames may not support GetName properly
        local ok, name = pcall(function() return frame:GetName() end)
        if ok and name and protectedFrames[name] then return true end
        -- Check if frame has IsProtected method and is protected
        if frame.IsProtected then
            local protOk, isProtected = pcall(function() return frame:IsProtected() end)
            if protOk and isProtected then return true end
        end
        return false
    end
    
    -- Method 1: Check current mouse focus for invisible blockers
    -- Midnight API: GetMouseFoci() returns table, GetMouseFocus() was removed
    local focus = nil
    if GetMouseFoci then
        local foci = GetMouseFoci()
        focus = foci and foci[1]
    end
    -- Note: GetMouseFocus() was removed in Midnight - no fallback needed
    
    if focus and focus ~= WorldFrame and focus ~= UIParent and not IsFrameProtected(focus) then
        local isShown = pcall(function() return focus:IsShown() end) and focus:IsShown()
        local mouseEnabled = pcall(function() return focus:IsMouseEnabled() end) and focus:IsMouseEnabled()
        local alpha = pcall(function() return focus:GetAlpha() end) and focus:GetAlpha() or 1
        local name = pcall(function() return focus:GetName() end) and focus:GetName() or "[unnamed]"
        
        TweaksUI:PrintDebug("Mouse focus: " .. name .. " shown=" .. tostring(isShown) .. " mouse=" .. tostring(mouseEnabled) .. " alpha=" .. tostring(alpha))
        
        -- If focus is on a frame that's mouse-enabled but invisible (alpha 0 or not shown)
        if mouseEnabled and (not isShown or alpha == 0) then
            pcall(function() focus:EnableMouse(false) end)
            TweaksUI:PrintDebug("DialogueUI fix: Disabled mouse on invisible blocking frame: " .. name)
            cleaned = cleaned + 1
        end
    end
    
    -- Method 2: Scan for known DialogueUI patterns - frames that are mouse-enabled but alpha 0 or not shown
    for k, v in pairs(_G) do
        if type(k) == "string" and (k:find("^DUI") or k:find("^Dialogue")) and type(v) == "table" then
            if v.IsMouseEnabled and v.GetAlpha and v.EnableMouse and v.IsShown then
                local ok, result = pcall(function()
                    local mouseEnabled = v:IsMouseEnabled()
                    local alpha = v:GetAlpha()
                    local shown = v:IsShown()
                    if mouseEnabled and (alpha == 0 or not shown) then
                        v:EnableMouse(false)
                        return true
                    end
                    return false
                end)
                if ok and result then
                    TweaksUI:PrintDebug("DialogueUI fix: Disabled mouse on " .. k)
                    cleaned = cleaned + 1
                end
            end
        end
    end
    
    -- Method 3: Scan UIParent children for any invisible mouse-enabled frames at high strata
    local dangerousStrata = {DIALOG = true, FULLSCREEN = true, FULLSCREEN_DIALOG = true, HIGH = true}
    local children = {UIParent:GetChildren()}
    for _, child in ipairs(children) do
        -- Skip protected frames
        if not IsFrameProtected(child) then
            pcall(function()
                local mouseEnabled = child:IsMouseEnabled()
                local alpha = child:GetAlpha()
                local shown = child:IsShown()
                local strata = child:GetFrameStrata()
                
                -- If it's at a high strata, mouse-enabled, but invisible
                if mouseEnabled and dangerousStrata[strata] and (alpha == 0 or not shown) then
                    child:EnableMouse(false)
                    local name = child:GetName() or "[unnamed]"
                    TweaksUI:PrintDebug("DialogueUI fix: Disabled mouse on " .. name .. " at " .. strata)
                    cleaned = cleaned + 1
                end
            end)
        end
    end
    
    -- Method 4: Look for frames that are SHOWN but have 0 alpha (the sneaky ones)
    for _, child in ipairs(children) do
        -- Skip protected frames
        if not IsFrameProtected(child) then
            pcall(function()
                local mouseEnabled = child:IsMouseEnabled()
                local alpha = child:GetAlpha()
                local shown = child:IsShown()
                local width = child:GetWidth()
                local height = child:GetHeight()
                
                -- Large frame, shown, mouse-enabled, but alpha 0
                if shown and mouseEnabled and alpha == 0 and width > 100 and height > 100 then
                    child:EnableMouse(false)
                    local name = child:GetName() or "[unnamed]"
                    TweaksUI:PrintDebug("DialogueUI fix: Disabled mouse on large invisible frame: " .. name .. " (" .. math.floor(width) .. "x" .. math.floor(height) .. ")")
                    cleaned = cleaned + 1
                end
            end)
        end
    end
    
    return cleaned
end

-- Store for slash command access
TweaksUI.CleanupInvisibleMouseBlockers = CleanupInvisibleMouseBlockers

local dialogueUICleanupFrame = CreateFrame("Frame")
dialogueUICleanupFrame:RegisterEvent("GOSSIP_CLOSED")
dialogueUICleanupFrame:RegisterEvent("QUEST_FINISHED")
dialogueUICleanupFrame:RegisterEvent("QUEST_ACCEPTED")
dialogueUICleanupFrame:RegisterEvent("GOSSIP_SHOW")  -- Also clean when opening new dialogue
dialogueUICleanupFrame:RegisterEvent("QUEST_DETAIL")

dialogueUICleanupFrame:SetScript("OnEvent", function(self, event)
    TweaksUI:PrintDebug("DialogueUI cleanup triggered by: " .. event)
    -- Small delay to let DialogueUI finish its cleanup first
    C_Timer.After(0.15, function()
        local cleaned = CleanupInvisibleMouseBlockers()
        if cleaned > 0 then
            TweaksUI:PrintDebug("DialogueUI cleanup: fixed " .. cleaned .. " frames")
        end
    end)
end)

-- ============================================================================
-- LIVE STATS WINDOW
-- ============================================================================
local statsWindow = nil
local STATS_UPDATE_INTERVAL = 0.5  -- 2 updates per second

local function GetColorForValue(value, greenThreshold, yellowThreshold, inverse)
    if inverse then
        -- Lower is better (like latency)
        if value < greenThreshold then return 0, 1, 0 end
        if value < yellowThreshold then return 1, 1, 0 end
        return 1, 0, 0
    else
        -- Higher is better (like FPS)
        if value >= greenThreshold then return 0, 1, 0 end
        if value >= yellowThreshold then return 1, 1, 0 end
        return 1, 0, 0
    end
end

local function CreateStatsWindow()
    local frame = CreateFrame("Frame", "TweaksUI_StatsWindow", UIParent, "BackdropTemplate")
    frame:SetSize(220, 195)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("|cffffd100TweaksUI Stats|r")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    -- Stats labels (left side)
    local yOffset = -35
    local labelWidth = 90
    local valueWidth = 100
    
    local function CreateStatRow(labelText)
        local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", 12, yOffset)
        label:SetWidth(labelWidth)
        label:SetJustifyH("LEFT")
        label:SetText(labelText)
        
        local value = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        value:SetPoint("TOPLEFT", 12 + labelWidth, yOffset)
        value:SetWidth(valueWidth)
        value:SetJustifyH("LEFT")
        
        yOffset = yOffset - 18
        return value
    end
    
    frame.fpsValue = CreateStatRow("FPS:")
    frame.latencyValue = CreateStatRow("Latency:")
    frame.memoryValue = CreateStatRow("TUI Memory:")
    frame.memGrowthValue = CreateStatRow("Mem Growth:")
    frame.cpuValue = CreateStatRow("TUI CPU:")
    frame.luaMemValue = CreateStatRow("Lua Memory:")
    
    -- Memory tracking for growth rate
    frame.lastMemKB = 0
    frame.memGrowthHistory = {}
    frame.maxHistorySize = 10  -- Track last 10 samples (5 seconds)
    
    -- CPU hint (shown when profiling disabled)
    frame.cpuHint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.cpuHint:SetPoint("BOTTOMLEFT", 12, 8)
    frame.cpuHint:SetPoint("BOTTOMRIGHT", -12, 8)
    frame.cpuHint:SetJustifyH("LEFT")
    frame.cpuHint:SetText("|cff888888/console scriptProfile 1|r")
    frame.cpuHint:SetTextColor(0.5, 0.5, 0.5)
    
    -- Update timer
    frame.elapsed = 0
    frame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed < STATS_UPDATE_INTERVAL then return end
        self.elapsed = 0
        
        -- FPS
        local fps = GetFramerate()
        local r, g, b = GetColorForValue(fps, 60, 30, false)
        self.fpsValue:SetText(string.format("%.1f", fps))
        self.fpsValue:SetTextColor(r, g, b)
        
        -- Latency
        local _, _, latencyHome, latencyWorld = GetNetStats()
        local r2, g2, b2 = GetColorForValue(latencyWorld, 100, 200, true)
        self.latencyValue:SetText(string.format("%dms / %dms", latencyHome, latencyWorld))
        self.latencyValue:SetTextColor(r2, g2, b2)
        
        -- TweaksUI Memory
        UpdateAddOnMemoryUsage()
        local memKB = GetAddOnMemoryUsage("!TweaksUI") or 0
        local r3, g3, b3 = GetColorForValue(memKB, 10000, 30000, true)
        if memKB >= 1024 then
            self.memoryValue:SetText(string.format("%.2f MB", memKB / 1024))
        else
            self.memoryValue:SetText(string.format("%.0f KB", memKB))
        end
        self.memoryValue:SetTextColor(r3, g3, b3)
        
        -- Memory growth rate
        local memDelta = memKB - self.lastMemKB
        table.insert(self.memGrowthHistory, memDelta)
        if #self.memGrowthHistory > self.maxHistorySize then
            table.remove(self.memGrowthHistory, 1)
        end
        self.lastMemKB = memKB
        
        -- Calculate average growth per second
        local totalGrowth = 0
        for _, delta in ipairs(self.memGrowthHistory) do
            totalGrowth = totalGrowth + delta
        end
        local avgGrowth = totalGrowth / #self.memGrowthHistory / STATS_UPDATE_INTERVAL
        
        if avgGrowth > 100 then
            self.memGrowthValue:SetText(string.format("|cffff0000+%.1f KB/s|r", avgGrowth))
        elseif avgGrowth > 10 then
            self.memGrowthValue:SetText(string.format("|cffffff00+%.1f KB/s|r", avgGrowth))
        elseif avgGrowth < -10 then
            self.memGrowthValue:SetText(string.format("|cff00ff00%.1f KB/s|r", avgGrowth))
        else
            self.memGrowthValue:SetText(string.format("%.1f KB/s", avgGrowth))
            self.memGrowthValue:SetTextColor(0.6, 0.6, 0.6)
        end
        
        -- CPU (if profiling enabled)
        local cpuEnabled = GetCVarBool("scriptProfile")
        if cpuEnabled then
            UpdateAddOnCPUUsage()
            local cpuTime = GetAddOnCPUUsage("!TweaksUI") or 0
            local totalCPU = 0
            -- Midnight moved GetNumAddOns to C_AddOns namespace
            local numAddOns = C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetNumAddOns() or GetNumAddOns and GetNumAddOns() or 0
            for i = 1, numAddOns do
                totalCPU = totalCPU + (GetAddOnCPUUsage(i) or 0)
            end
            local cpuPercent = totalCPU > 0 and (cpuTime / totalCPU * 100) or 0
            local r4, g4, b4 = GetColorForValue(cpuPercent, 5, 15, true)
            self.cpuValue:SetText(string.format("%.1f%% (%.0fms)", cpuPercent, cpuTime))
            self.cpuValue:SetTextColor(r4, g4, b4)
            self.cpuHint:Hide()
        else
            self.cpuValue:SetText("|cff888888Disabled|r")
            self.cpuValue:SetTextColor(0.5, 0.5, 0.5)
            self.cpuHint:Show()
        end
        
        -- Total Lua memory
        local gcKB = collectgarbage("count")
        self.luaMemValue:SetText(string.format("%.1f MB", gcKB / 1024))
        self.luaMemValue:SetTextColor(1, 1, 0.6)
    end)
    
    -- Register for ESC to close
    tinsert(UISpecialFrames, "TweaksUI_StatsWindow")
    
    return frame
end

function TweaksUI:ToggleStatsWindow()
    if not statsWindow then
        statsWindow = CreateStatsWindow()
    end
    
    if statsWindow:IsShown() then
        statsWindow:Hide()
    else
        statsWindow:Show()
        statsWindow.elapsed = STATS_UPDATE_INTERVAL  -- Force immediate update
    end
end

-- Slash commands
local function HandleSlashCommand(msg)
    msg = msg:lower():trim()
    local args = {}
    for word in msg:gmatch("%S+") do
        table.insert(args, word)
    end
    local cmd = args[1] or ""
    
    if cmd == "" or cmd == "config" or cmd == "settings" then
        -- Open settings
        TweaksUI:ToggleSettings()
        
    
    elseif cmd == "help" then
        TweaksUI:Print("Commands:")
        print("  /tui - Open settings panel")
        print("  /tui setup - Open first-time setup wizard")
        print("  /tui modules - List all modules")
        print("  /tui enable <module> - Enable a module")
        print("  /tui disable <module> - Disable a module")
        print("  /tui keybind - Toggle quick keybind mode")
        print("  /tui profile <name> - Switch profile")
        print("  /tui profiles - List saved profiles")
        print("  /tui quicksetup - Open Quick Setup wizard")
        print("  /tui loadbasic - Load the Basic built-in profile")
        print("  /tui dumpdb - Dump database state (debug)")
        print("  /tui import - Open import dialog")
        print("  /tui export - Open export dialog")
        print("  /tui textures - List available textures")
        print("  /tui fonts - List available fonts")
        print("  /tui sounds - List available sounds")
        print("  /tui patchnotes - Show patch notes")
        print("  /tui resetrange - Reset range indicators to defaults")
        print("  /tui resetvisibility - NUCLEAR: Reset ALL visibility conditions (cooldowns, frames, bars, etc)")
        print("  /tui showall - Force all frames visible (bypass visibility conditions)")
        print("  /tui showminimap - Force show minimap (emergency recovery)")
        print("  /tui mousefix - Emergency fix for mouse input blocking")
        print("  /tui mousediag - Quick check of common blocking frames")
        print("  /tui mousescan - Deep scan of all frames for blocking issues")
        print("  /tui mouseblock - AGGRESSIVE scan of ALL frames at blocking strata")
        print("  /tui mousekill - NUCLEAR option: disable mouse on all blocking frames")
        print("  /tui mouseinfo - Deep diagnostic: check mouse focus and frame states")
        print("  /tui mouseworldkill - Kill mouse on WorldFrame children")
        print("  /tui mouserestore - Aggressive restoration of normal mouse behavior")
        print("  /tui mouseclean - Manual DialogueUI cleanup + scan for top-screen blockers")
        print("  /tui layoutclean - Force cleanup of Layout mode overlays")
        print("  /tui mousedeep - DEEP recursive scan of ALL frames in upper screen")
        print("  /tui mousetop - NUCLEAR: Kill mouse on ALL upper-screen frames")
        print("  /tui mousestate - Check game states that might affect mouse input")
        print("  /tui mouseunstick - Try various methods to unstick mouse input")
        print("  /tui mouselow - Kill mouse on ALL BACKGROUND/LOW strata frames")
        print("  /tui mouseworld - Find what's blocking clicks at a test point")
        print("  /tui mouseover - Check TweaksUI mouseover detection frame status")
        print("  /tui tuiscan - Scan for TweaksUI frames with mouse enabled")
        print("  /tui tuireset - Force reset TweaksUI mouseover detection frames")
        print("  /tui deepclean - Deep cleanup of mouse states after DialogueUI")
        print("  /tui safemode - Toggle aggressive DialogueUI compatibility mode")
        print("  /tui debug - Toggle debug mode")
        print("  /tui stats - Show FPS, memory, CPU usage stats")
        print("  /tui version - Show version")
        print("  /tui welcome - Show welcome screen")
        
    elseif cmd == "welcome" then
        TweaksUI:ShowWelcomeScreen(true)  -- forceShow=true
    
    elseif cmd == "setup" then
        -- Open setup wizard
        if TweaksUI.SetupWizard and TweaksUI.SetupWizard.Show then
            TweaksUI.SetupWizard:Show()
        else
            TweaksUI:Print("Setup wizard not available")
        end
        
    elseif cmd == "modules" then
        TweaksUI:Print("Modules:")
        for moduleId, moduleName in pairs(TweaksUI.MODULE_NAMES) do
            local module = TweaksUI.ModuleManager:GetModule(moduleId)
            local status = ""
            if module then
                if module.enabled then
                    status = "|cff00ff00[Enabled]|r"
                elseif module.loaded then
                    status = "|cffff0000[Disabled]|r"
                else
                    status = "|cff888888[Not Loaded]|r"
                end
            else
                status = "|cff888888[Not Registered]|r"
            end
            print("  " .. moduleId .. " - " .. moduleName .. " " .. status)
        end
        
    elseif cmd == "enable" then
        local moduleId = args[2]
        if moduleId then
            TweaksUI.ModuleManager:EnableModule(moduleId)
        else
            TweaksUI:Print("Usage: /tui enable <module>")
        end
        
    elseif cmd == "disable" then
        local moduleId = args[2]
        if moduleId then
            TweaksUI.ModuleManager:DisableModule(moduleId)
        else
            TweaksUI:Print("Usage: /tui disable <module>")
        end
        
    elseif cmd == "profile" then
        -- Open profiles panel (1.5.0+)
        if TweaksUI.ProfilesUI then
            TweaksUI.ProfilesUI:ShowProfilesPanel()
        else
            TweaksUI:PrintError("ProfilesUI not available")
        end
        
    elseif cmd == "profiles" then
        -- List saved profiles (1.5.0+)
        if TweaksUI.Profiles then
            local profiles = TweaksUI.Profiles:GetProfileList()
            local current = TweaksUI.Profiles:GetLoadedProfileName()
            TweaksUI:Print("Saved Profiles:")
            for _, profile in ipairs(profiles) do
                if profile.name == current then
                    print("  |cff00ff00★ " .. profile.name .. " (active)|r")
                else
                    print("  " .. profile.name)
                end
            end
            if #profiles == 0 then
                print("  (no profiles saved yet)")
            end
        else
            TweaksUI:PrintError("Profiles system not available")
        end
        
    elseif cmd == "quicksetup" then
        -- Open Quick Setup wizard (1.5.0+)
        if TweaksUI.ProfilesUI then
            TweaksUI.ProfilesUI:ShowQuickSetupPanel()
        else
            TweaksUI:PrintError("ProfilesUI not available")
        end
        
    elseif cmd == "loadbasic" then
        -- Force load the Basic built-in profile
        if TweaksUI.DefaultProfiles then
            local basicProfile = TweaksUI.DefaultProfiles:GetProfile("Basic 1440")
            if basicProfile then
                -- Ask about saving current profile first
                StaticPopupDialogs["TWEAKSUI_LOADBASIC_CONFIRM"] = {
                    text = "Load the Basic built-in profile?\n\nWould you like to save your current settings first?",
                    button1 = "Save & Load",
                    button2 = "Just Load",
                    button3 = "Cancel",
                    OnAccept = function()
                        -- Save current profile first
                        local backupName = UnitName("player") .. " - Backup"
                        if TweaksUI.Profiles then
                            local currentSettings = TweaksUI.Profiles:GetCurrentSettings()
                            TweaksUI.Profiles:SaveProfile(backupName, currentSettings)
                            TweaksUI:Print("Saved backup profile: " .. backupName)
                        end
                        -- Then load Basic
                        TweaksUI:LoadBasicProfile()
                    end,
                    OnCancel = function()
                        -- Just load without saving
                        TweaksUI:LoadBasicProfile()
                    end,
                    timeout = 0,
                    whileDead = true,
                    hideOnEscape = true,
                    preferredIndex = 3,
                }
                StaticPopup_Show("TWEAKSUI_LOADBASIC_CONFIRM")
            else
                TweaksUI:PrintError("Basic profile not found or failed to decode")
            end
        else
            TweaksUI:PrintError("DefaultProfiles system not available")
        end
        
    elseif cmd == "dumpdb" then
        -- Dump current database state
        print("|cff00ff00=== TweaksUI_CharDB Dump ===|r")
        print("|cffFFFF00Module Enabled States (TweaksUI_CharDB.modules):|r")
        if TweaksUI_CharDB and TweaksUI_CharDB.modules then
            for moduleId, enabled in pairs(TweaksUI_CharDB.modules) do
                print("  " .. moduleId .. " = " .. tostring(enabled))
            end
        else
            print("  (empty or nil)")
        end
        print("|cffFFFF00Module Settings (TweaksUI_CharDB.settings):|r")
        if TweaksUI_CharDB and TweaksUI_CharDB.settings then
            for moduleId, settings in pairs(TweaksUI_CharDB.settings) do
                local count = 0
                if type(settings) == "table" then
                    for _ in pairs(settings) do count = count + 1 end
                end
                print("  " .. moduleId .. ": " .. count .. " keys")
            end
        else
            print("  (empty or nil)")
        end
        print("|cff00ff00=== End Dump ===|r")
        
    elseif cmd == "debug" then
        TweaksUI:SetDebugMode(not TweaksUI.debugMode)
        
    elseif cmd == "showall" then
        -- Toggle force-all-visible mode
        TweaksUI:SetForceAllVisible(not TweaksUI.forceAllVisible)
    
    elseif cmd == "resetvisibility" or cmd == "resetvis" then
        -- Nuclear reset of ALL visibility settings across the entire addon
        -- This fixes bugged profiles from old versions
        
        -- Second popup - shown after reset completes, requires click to reload
        StaticPopupDialogs["TWEAKSUI_RESET_VISIBILITY_RELOAD"] = {
            text = "|cff00ff00Visibility reset complete!|r\n\nClick Reload to apply changes.",
            button1 = "Reload UI",
            button2 = "Later",
            OnAccept = function()
                ReloadUI()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        
        -- First popup - confirmation
        StaticPopupDialogs["TWEAKSUI_RESET_VISIBILITY_CONFIRM"] = {
            text = "|cffff0000Reset All Visibility Settings|r\n\nThis will reset:\n• Per-icon highlights (positions, sizes, show/hide)\n• Cooldown tracker visibility\n• Personal Resources visibility\n• General UI frame visibility\n• Unit Frames visibility\n• Action Bars visibility\n• Stale data from old builds\n\nContinue?",
            button1 = "Reset",
            button2 = "Cancel",
            OnAccept = function()
                TweaksUI:Print("Resetting ALL visibility settings...")
                local resetCount = 0
                
                -- ================================================================
                -- 1. RESET PER-ICON HIGHLIGHT DATABASES
                -- Instead of wiping (which may not save nil properly), explicitly reset values
                -- ================================================================
                local highlightDBs = {
                    "buffHighlights",
                    "essentialHighlights", 
                    "utilityHighlights",
                    "customHighlights"
                }
                
                for _, dbKey in ipairs(highlightDBs) do
                    if TweaksUI_CharDB[dbKey] then
                        local db = TweaksUI_CharDB[dbKey]
                        TweaksUI:Print("  Resetting " .. dbKey)
                        
                        -- Explicitly set hideTracker to false (not nil)
                        db.hideTracker = false
                        
                        -- Clear per-icon arrays
                        db.enabled = {}
                        db.positions = {}
                        db.hidden = {}
                        db.labelEnabled = {}
                        db.labelText = {}
                        db.labelFontSize = {}
                        db.labelColor = {}
                        db.labelOffsetX = {}
                        db.labelOffsetY = {}
                        
                        -- Reset active/inactive state tables
                        if db.active then
                            db.active.size = {}
                            db.active.opacity = {}
                            db.active.saturation = {}
                            db.active.aspectRatio = {}
                            db.active.customAspectW = {}
                            db.active.customAspectH = {}
                            db.active.show = {}
                        end
                        if db.inactive then
                            db.inactive.size = {}
                            db.inactive.opacity = {}
                            db.inactive.saturation = {}
                            db.inactive.aspectRatio = {}
                            db.inactive.customAspectW = {}
                            db.inactive.customAspectH = {}
                            db.inactive.show = {}
                        end
                        
                        resetCount = resetCount + 1
                    end
                end
                
                -- Stop any running hide enforcement tickers and show trackers
                local CooldownHighlights = TweaksUI.CooldownHighlights
                local BuffHighlights = TweaksUI.BuffHighlights
                
                if CooldownHighlights then
                    for _, trackerKey in ipairs({"essential", "utility", "custom"}) do
                        -- Apply visibility will stop enforcement and show tracker since hideTracker is now false
                        if CooldownHighlights.ApplyTrackerVisibility then
                            pcall(CooldownHighlights.ApplyTrackerVisibility, CooldownHighlights, trackerKey)
                        end
                    end
                end
                
                if BuffHighlights and BuffHighlights.ApplyTrackerVisibility then
                    pcall(BuffHighlights.ApplyTrackerVisibility, BuffHighlights)
                end
                
                -- ================================================================
                -- 2. RESET COOLDOWNS TRACKER VISIBILITY
                -- ================================================================
                if TweaksUI_CharDB.settings and TweaksUI_CharDB.settings.cooldowns then
                    local cdSettings = TweaksUI_CharDB.settings.cooldowns
                    for _, trackerKey in ipairs({"essential", "utility", "buffs", "customTrackers"}) do
                        if cdSettings[trackerKey] then
                            if cdSettings[trackerKey].visibilityEnabled then
                                TweaksUI:Print("  Disabling visibility for cooldowns." .. trackerKey)
                                cdSettings[trackerKey].visibilityEnabled = false
                                resetCount = resetCount + 1
                            end
                            -- Clear any stale fields
                            if cdSettings[trackerKey].hideTracker ~= nil then
                                cdSettings[trackerKey].hideTracker = nil
                                resetCount = resetCount + 1
                            end
                            if cdSettings[trackerKey].hidden then
                                cdSettings[trackerKey].hidden = nil
                                resetCount = resetCount + 1
                            end
                        end
                    end
                end
                
                -- ================================================================
                -- 3. RESET PERSONAL RESOURCES VISIBILITY
                -- ================================================================
                if TweaksUI_CharDB.settings and TweaksUI_CharDB.settings.personalResources then
                    local prSettings = TweaksUI_CharDB.settings.personalResources
                    local prElements = {"buffs", "debuffs", "healthBar", "powerBar", "classPower", 
                                       "soulFragments", "stagger", "runes", "global"}
                    for _, key in ipairs(prElements) do
                        if prSettings[key] and type(prSettings[key]) == "table" then
                            if prSettings[key].visibilityEnabled then
                                TweaksUI:Print("  Disabling visibility for personalResources." .. key)
                                prSettings[key].visibilityEnabled = false
                                prSettings[key].fadeEnabled = false
                                resetCount = resetCount + 1
                            end
                        end
                    end
                end
                
                -- ================================================================
                -- 4. RESET GENERAL MODULE VISIBILITY (UI frames)
                -- ================================================================
                if TweaksUI_CharDB.settings and TweaksUI_CharDB.settings.general then
                    local genSettings = TweaksUI_CharDB.settings.general
                    if genSettings.visibility and type(genSettings.visibility) == "table" then
                        for frameKey, visCfg in pairs(genSettings.visibility) do
                            if type(visCfg) == "table" and visCfg.visibilityEnabled then
                                TweaksUI:Print("  Disabling visibility for general." .. frameKey)
                                visCfg.visibilityEnabled = false
                                visCfg.fadeEnabled = false
                                visCfg.hide = false
                                resetCount = resetCount + 1
                            end
                        end
                    end
                end
                
                -- ================================================================
                -- 5. RESET UNIT FRAMES VISIBILITY
                -- ================================================================
                if TweaksUI_CharDB.settings and TweaksUI_CharDB.settings.unitFrames then
                    local ufSettings = TweaksUI_CharDB.settings.unitFrames
                    for frameKey, frameCfg in pairs(ufSettings) do
                        if type(frameCfg) == "table" and frameCfg.visibility then
                            if frameCfg.visibility.enabled then
                                TweaksUI:Print("  Disabling visibility for unitFrames." .. frameKey)
                                frameCfg.visibility.enabled = false
                                resetCount = resetCount + 1
                            end
                        end
                    end
                end
                
                -- ================================================================
                -- 6. RESET ACTION BARS VISIBILITY
                -- ================================================================
                if TweaksUI_CharDB.settings and TweaksUI_CharDB.settings.actionBars then
                    local abSettings = TweaksUI_CharDB.settings.actionBars
                    for barKey, barCfg in pairs(abSettings) do
                        if type(barCfg) == "table" and barCfg.visibility then
                            if barCfg.visibility.enabled then
                                TweaksUI:Print("  Disabling visibility for actionBars." .. barKey)
                                barCfg.visibility.enabled = false
                                resetCount = resetCount + 1
                            end
                        end
                    end
                end
                
                -- ================================================================
                -- 7. CLEAN UP ANY OTHER STALE TOP-LEVEL VISIBILITY DATA
                -- ================================================================
                local staleKeys = {
                    "trackerVisibility",  -- Old key from early versions
                    "frameVisibility",    -- Old key
                    "visibilityStates",   -- Old key
                }
                for _, key in ipairs(staleKeys) do
                    if TweaksUI_CharDB[key] then
                        TweaksUI:Print("  Removing stale key: " .. key)
                        TweaksUI_CharDB[key] = nil
                        resetCount = resetCount + 1
                    end
                end
                
                -- ================================================================
                -- 8. RESET FORCE ALL VISIBLE FLAG
                -- ================================================================
                if TweaksUI_DB and TweaksUI_DB.global then
                    if TweaksUI_DB.global.forceAllVisible then
                        TweaksUI:Print("  Clearing forceAllVisible flag")
                        TweaksUI_DB.global.forceAllVisible = false
                        resetCount = resetCount + 1
                    end
                end
                
                TweaksUI:Print("|cff00ff00Reset complete! (" .. resetCount .. " items reset)|r")
                
                -- Show reload popup
                StaticPopup_Show("TWEAKSUI_RESET_VISIBILITY_RELOAD")
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("TWEAKSUI_RESET_VISIBILITY_CONFIRM")
        
    elseif cmd == "showminimap" then
        -- Force show the minimap (emergency recovery)
        if MinimapCluster then
            MinimapCluster:ClearAllPoints()
            MinimapCluster:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
            MinimapCluster:SetAlpha(1)
            MinimapCluster:Show()
        end
        if Minimap then
            Minimap:Show()
            Minimap:SetAlpha(1)
        end
        TweaksUI:Print("Minimap forced visible. Use settings to configure properly.")
        
    elseif cmd == "keybind" or cmd == "kb" then
        -- Toggle quick keybind mode
        local ActionBars = TweaksUI.ModuleManager:GetModule("ActionBars")
        if ActionBars and ActionBars.ToggleKeybindMode then
            ActionBars:ToggleKeybindMode()
        else
            TweaksUI:PrintError("Action Bars module not available")
        end
        
    elseif cmd == "import" then
        -- Open import dialog (1.5.0+)
        if TweaksUI.ProfilesUI then
            TweaksUI.ProfilesUI:ShowImportPanel()
        elseif TweaksUI.Import then
            TweaksUI.Import:ShowImportDialog()
        else
            TweaksUI:PrintError("Import system not available")
        end
        
    elseif cmd == "export" then
        -- Open export dialog (1.5.0+)
        if TweaksUI.ProfilesUI then
            TweaksUI.ProfilesUI:ShowExportPanel()
        elseif TweaksUI.Import then
            TweaksUI.Import:ShowExportDialog()
        else
            TweaksUI:PrintError("Export system not available")
        end
    
    elseif cmd == "exportraw" then
        -- Export uncompressed profile (for development/debugging)
        if TweaksUI.Import and TweaksUI.Import.ExportProfileRaw then
            local exportString = TweaksUI.Import:ExportProfileRaw()
            if exportString then
                -- Create a simple edit box to show the string
                local frame = CreateFrame("Frame", "TweaksUI_RawExportFrame", UIParent, "BasicFrameTemplateWithInset")
                frame:SetSize(600, 400)
                frame:SetPoint("CENTER")
                frame:SetFrameStrata("DIALOG")
                frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                frame.title:SetPoint("TOP", 0, -5)
                frame.title:SetText("Raw Profile Export (Uncompressed)")
                
                local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
                scrollFrame:SetPoint("TOPLEFT", 10, -30)
                scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
                
                local editBox = CreateFrame("EditBox", nil, scrollFrame)
                editBox:SetMultiLine(true)
                editBox:SetFontObject(GameFontHighlightSmall)
                editBox:SetWidth(540)
                editBox:SetAutoFocus(false)
                editBox:SetText(exportString)
                editBox:HighlightText()
                scrollFrame:SetScrollChild(editBox)
                
                editBox:SetScript("OnEscapePressed", function() frame:Hide() end)
                frame:SetScript("OnHide", function(self) self:SetParent(nil) end)
                
                TweaksUI:Print("Raw export generated. Copy the text (Ctrl+C) - it starts with TUIRAW:")
            end
        else
            TweaksUI:PrintError("Raw export not available")
        end
        
    elseif cmd == "version" then
        TweaksUI:Print("Version " .. TweaksUI.VERSION)
        TweaksUI:Print("Build: " .. TweaksUI.BUILD_VERSION)
        TweaksUI:Print("Midnight compatible: " .. (TweaksUI.IS_MIDNIGHT and "Yes" or "No"))
    
    elseif cmd == "npdebug" then
        -- Toggle nameplate debug mode
        if TweaksUI.Nameplates and TweaksUI.Nameplates.ToggleDebug then
            TweaksUI.Nameplates:ToggleDebug()
        else
            TweaksUI:PrintError("Nameplates module not loaded")
        end
        
    elseif cmd == "systembars" or cmd == "sbdebug" then
        -- Debug system bars (Micro Menu, Bags, Pet) and our custom Stance Bar
        TweaksUI:Print("System Bar Status:")
        local systemBars = {"MicroMenu", "BagsBar", "PetActionBar"}
        
        -- Get ActionBars module for wrapper info
        local ActionBars = TweaksUI.ModuleManager and TweaksUI.ModuleManager:GetModule("ActionBars")
        local abSettings = ActionBars and ActionBars.GetSettings and ActionBars:GetSettings()
        
        for _, barId in ipairs(systemBars) do
            local frame = _G[barId]
            local exists = frame ~= nil
            local shown = frame and frame:IsShown()
            local alpha = frame and frame:GetAlpha() or 0
            
            local status = exists and (shown and "|cff00ff00VISIBLE|r" or "|cffff0000HIDDEN|r") or "|cff888888NIL|r"
            local extra = ""
            if exists then
                extra = extra .. " Alpha: " .. string.format("%.1f", alpha)
            end
            
            -- Check TweaksUI settings
            local barSettings = abSettings and abSettings.systemBars and abSettings.systemBars[barId]
            local tuiEnabled = barSettings and barSettings.enabled
            extra = extra .. " | TUI: " .. (tuiEnabled and "|cff00ff00ON|r" or "|cffff9900OFF|r")
            
            -- Check wrapper status
            local wrapper = ActionBars and ActionBars.GetSystemBarWrapper and ActionBars:GetSystemBarWrapper(barId)
            if wrapper then
                local wrapperShown = wrapper.frame and wrapper.frame:IsShown()
                local hasTicker = wrapper._syncTicker ~= nil
                extra = extra .. " | Wrapper: " .. (wrapperShown and "|cff00ff00SHOWN|r" or "|cffff0000HIDDEN|r")
                extra = extra .. " Ticker: " .. (hasTicker and "|cff00ff00YES|r" or "|cffff9900NO|r")
            else
                extra = extra .. " | Wrapper: |cff888888NONE|r"
            end
            
            print("  " .. barId .. ": " .. status .. extra)
        end
        
        -- Our custom Stance Bar
        print("")
        TweaksUI:Print("Custom Stance Bar:")
        local numForms = GetNumShapeshiftForms()
        local stanceSettings = abSettings and abSettings.stanceBar
        local stanceEnabled = stanceSettings and stanceSettings.enabled
        local hideBlizz = stanceSettings and stanceSettings.hideBlizzard
        
        print("  Forms: " .. numForms)
        print("  TUI Enabled: " .. (stanceEnabled and "|cff00ff00YES|r" or "|cffff9900NO|r"))
        print("  Hide Blizzard: " .. (hideBlizz and "|cff00ff00YES|r" or "|cffff9900NO|r"))
        
        local stanceContainer = ActionBars and ActionBars.GetStanceBarContainer and ActionBars:GetStanceBarContainer()
        if stanceContainer then
            local shown = stanceContainer:IsShown()
            local alpha = stanceContainer:GetAlpha()
            print("  Container: " .. (shown and "|cff00ff00SHOWN|r" or "|cffff0000HIDDEN|r") .. " Alpha: " .. string.format("%.1f", alpha))
        else
            print("  Container: |cff888888NOT CREATED|r")
        end
        
        -- Blizzard's stance bar status
        local blizzStance = _G["StanceBar"]
        if blizzStance then
            local blizzShown = blizzStance:IsShown()
            local blizzAlpha = blizzStance:GetAlpha()
            print("  Blizzard StanceBar: " .. (blizzShown and "|cff00ff00VISIBLE|r" or "|cffff0000HIDDEN|r") .. " Alpha: " .. string.format("%.1f", blizzAlpha))
        else
            print("  Blizzard StanceBar: |cff888888NIL|r")
        end
        
    elseif cmd == "media" then
        -- Show media counts
        if TweaksUI.Media and TweaksUI.Media.PrintMediaList then
            local mediaType = args or "statusbar"
            TweaksUI.Media:PrintMediaList(mediaType)
        else
            TweaksUI:PrintError("Media system not available")
        end
        
    elseif cmd == "textures" then
        if TweaksUI.Media then
            TweaksUI.Media:PrintMediaList("statusbar")
        end
        
    elseif cmd == "fonts" then
        if TweaksUI.Media then
            TweaksUI.Media:PrintMediaList("font")
        end
        
    elseif cmd == "sounds" then
        if TweaksUI.Media then
            TweaksUI.Media:PrintMediaList("sound")
        end
        
    elseif cmd == "testfont" then
        -- Debug command to test font path retrieval
        local fontName = args ~= "" and args or "Friz Quadrata TT"
        TweaksUI:Print("Testing font: '" .. fontName .. "'")
        
        if TweaksUI.Media then
            local path = TweaksUI.Media:GetFont(fontName)
            TweaksUI:Print("  GetFont() returned: " .. tostring(path))
            
            local isValid = TweaksUI.Media:IsValidFont(fontName)
            TweaksUI:Print("  IsValidFont(): " .. tostring(isValid))
            
            local globalPath = TweaksUI.Media:GetFontWithGlobal(fontName)
            TweaksUI:Print("  GetFontWithGlobal() returned: " .. tostring(globalPath))
            
            local globalEnabled = TweaksUI.Media:IsUsingGlobalFont()
            TweaksUI:Print("  Global font enabled: " .. tostring(globalEnabled))
            
            if globalEnabled then
                local globalName = TweaksUI.Media:GetGlobalFontName()
                TweaksUI:Print("  Global font name: " .. tostring(globalName))
            end
            
            -- Try to actually set a test font string
            local testFrame = CreateFrame("Frame")
            local testText = testFrame:CreateFontString(nil, "OVERLAY")
            local success, err = pcall(function()
                testText:SetFont(path, 12, "")
            end)
            if success then
                TweaksUI:Print("  SetFont() call: SUCCESS")
            else
                TweaksUI:Print("  SetFont() call: FAILED - " .. tostring(err))
            end
        end
        
    elseif cmd == "patchnotes" or cmd == "changelog" then
        -- Show patch notes
        TweaksUI:ShowPatchNotes(true)
        
    elseif cmd == "resetpatchnotes" then
        -- Reset patch notes so they show on next login
        TweaksUI.Database:SetGlobal("lastSeenVersion", nil)
        TweaksUI:Print("Patch notes reset. They will show on next login or /reload.")
    
    elseif cmd == "exportlayout" then
        -- Export current on-screen frame positions to a string
        if TweaksUI.Layout then
            TweaksUI.Layout:ExportPositions()
        else
            TweaksUI:PrintError("Layout module not available")
        end
        
    elseif cmd == "clearlayout" then
        -- Wipe ALL position-related saved variables
        if TweaksUI.Layout then
            TweaksUI.Layout:WipeAllPositionData()
        else
            TweaksUI:PrintError("Layout module not available")
        end
        
    elseif cmd == "importlayout" then
        -- Import positions from string
        if args and args ~= "" then
            if TweaksUI.Layout then
                TweaksUI.Layout:ImportPositions(args)
            else
                TweaksUI:PrintError("Layout module not available")
            end
        else
            TweaksUI:Print("Usage: /tui importlayout <string>")
            TweaksUI:Print("Paste the export string after the command")
        end
        
    elseif cmd == "debuglayout" then
        -- Show what's in saved variables for debugging
        if TweaksUI.Layout then
            TweaksUI.Layout:DebugSavedPositions()
        else
            TweaksUI:PrintError("Layout module not available")
        end
        
    elseif cmd == "resetrange" then
        -- Reset range indicator settings to defaults
        local db = TweaksUI.Database
        if db then
            -- Reset Action Bars range indicators
            local actionBarsSettings = db:GetModuleSettings("ActionBars")
            if actionBarsSettings and actionBarsSettings.bars then
                local defaultColor = {1, 0.1, 0.1, 0.4}
                for barId, barSettings in pairs(actionBarsSettings.bars) do
                    barSettings.rangeIndicatorEnabled = true
                    barSettings.rangeIndicatorColor = {defaultColor[1], defaultColor[2], defaultColor[3], defaultColor[4]}
                end
                TweaksUI:Print("Action Bars range indicators reset to defaults (enabled, red overlay)")
            end
            
            -- Reset Cooldowns range indicators
            local cooldownsSettings = db:GetModuleSettings("Cooldowns")
            if cooldownsSettings and cooldownsSettings.customTrackers then
                cooldownsSettings.customTrackers.rangeIndicatorEnabled = false
                cooldownsSettings.customTrackers.rangeIndicatorColor = {1, 0.1, 0.1, 0.4}
                TweaksUI:Print("Custom Trackers range indicators reset to defaults (disabled, red overlay)")
            end
            
            -- Apply changes
            local ActionBars = TweaksUI.ModuleManager:GetModule("ActionBars")
            if ActionBars and ActionBars.ApplyAllRangeIndicators then
                ActionBars:ApplyAllRangeIndicators()
            end
            
            local Cooldowns = TweaksUI.ModuleManager:GetModule("Cooldowns")
            if Cooldowns then
                -- Trigger refresh through visibility update
                if Cooldowns.UpdateAllVisibility then
                    Cooldowns:UpdateAllVisibility()
                end
            end
            
            TweaksUI:Print("Range indicator settings reset. /reload to ensure all changes apply.")
        else
            TweaksUI:PrintError("Database not available")
        end
        
    elseif cmd == "mousefix" then
        -- Emergency fix: disable mouse on ALL potentially blocking frames
        TweaksUI:Print("|cffFFFF00Emergency Mouse Fix|r - Scanning for blocking frames...")
        local framesFixed = 0
        
        -- Fix known TweaksUI frames
        local tweaksFrames = {"TweaksUI_LayoutContainer", "TweaksUI_KeybindModeFrame", "TweaksUI_LayoutGrid", "TweaksUI_LayoutKeyboard", "TweaksUI_SnapIndicator"}
        for _, name in ipairs(tweaksFrames) do
            local frame = _G[name]
            if frame then
                frame:EnableMouse(false)
                frame:Hide()
                framesFixed = framesFixed + 1
                TweaksUI:Print("  - " .. name .. ": fixed")
            end
        end
        
        -- Fix known DialogueUI frames that might block
        local duiFrames = {"DUIQuestFrame", "DUIQuestItemDisplay", "DUIBookUIFrame", "DUIDialogSettings"}
        for _, name in ipairs(duiFrames) do
            local frame = _G[name]
            if frame and frame:IsShown() then
                frame:Hide()
                framesFixed = framesFixed + 1
                TweaksUI:Print("  - " .. name .. ": hidden")
            end
        end
        
        -- Comprehensive scan: Find ALL visible frames with mouse enabled at problematic strata
        local screenWidth, screenHeight = GetScreenWidth(), GetScreenHeight()
        local minBlockingSize = screenWidth * 0.3  -- Large enough to block significant UI
        
        local dangerousStrata = {
            BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, 
            DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8
        }
        
        local function IsLargeFrame(frame)
            local widthOK, width = pcall(function() return frame:GetWidth() end)
            local heightOK, height = pcall(function() return frame:GetHeight() end)
            width = (widthOK and width) or 0
            height = (heightOK and height) or 0
            return width > minBlockingSize or height > minBlockingSize
        end
        
        local function ScanAndFix(parent, depth, path)
            if depth > 5 then return end
            local childrenOK, children = pcall(function() return {parent:GetChildren()} end)
            if not childrenOK or not children then return end
            
            for _, child in ipairs(children) do
                local success = pcall(function()
                    local shownOK, shown = pcall(function() return child:IsShown() end)
                    local mouseOK, mouseEnabled = pcall(function() return child:IsMouseEnabled() end)
                    
                    if (shownOK and shown) and (mouseOK and mouseEnabled) then
                        local strataOK, strata = pcall(function() return child:GetFrameStrata() end)
                        strata = (strataOK and strata) or "UNKNOWN"
                        
                        if dangerousStrata[strata] and dangerousStrata[strata] >= 3 and IsLargeFrame(child) then
                            local nameOK, name = pcall(function() return child:GetName() end)
                            name = (nameOK and name) or (path .. "/[unnamed]")
                            -- Skip frames we already handled
                            if not name:find("^TweaksUI") and not name:find("^DUI") then
                                TweaksUI:Print("  |cffFF0000BLOCKING:|r " .. name .. " (" .. strata .. ")")
                                pcall(function() child:EnableMouse(false) end)
                                framesFixed = framesFixed + 1
                            end
                        end
                    end
                    
                    local childNameOK, childName = pcall(function() return child:GetName() end)
                    ScanAndFix(child, depth + 1, path .. "/" .. ((childNameOK and childName) or "?"))
                end)
            end
        end
        
        -- Scan from UIParent
        if UIParent then
            ScanAndFix(UIParent, 0, "UIParent")
        end
        
        -- Also check WorldFrame children (DialogueUI uses WorldFrame for some frames)
        if WorldFrame then
            local childrenOK, children = pcall(function() return {WorldFrame:GetChildren()} end)
            if childrenOK and children then
                for _, child in ipairs(children) do
                    pcall(function()
                        local shownOK, shown = pcall(function() return child:IsShown() end)
                        local mouseOK, mouseEnabled = pcall(function() return child:IsMouseEnabled() end)
                        if (shownOK and shown) and (mouseOK and mouseEnabled) and IsLargeFrame(child) then
                            local nameOK, name = pcall(function() return child:GetName() end)
                            name = (nameOK and name) or "WorldFrame/[unnamed]"
                            TweaksUI:Print("  |cffFF0000BLOCKING (WorldFrame):|r " .. name)
                            pcall(function() child:EnableMouse(false) end)
                            framesFixed = framesFixed + 1
                        end
                    end)
                end
            end
        end
        
        if framesFixed > 0 then
            TweaksUI:Print("|cff00FF00Fixed " .. framesFixed .. " frame(s)|r - Try clicking now")
        else
            TweaksUI:Print("|cffFFFF00No blocking frames found|r - Issue may be elsewhere")
            TweaksUI:Print("Try: /tui mousescan for detailed frame analysis")
        end
        
    elseif cmd == "nopcheck" then
        -- Check NOP_ frames that might be blocking
        TweaksUI:Print("|cffFF00FFNOP Frame Check|r")
        
        local nopFrames = {}
        for k, v in pairs(_G) do
            if type(k) == "string" and k:find("^NOP_") and type(v) == "table" then
                pcall(function()
                    if v.IsShown and v.IsMouseEnabled then
                        local shown = v:IsShown()
                        local visible = v:IsVisible()
                        local mouseEnabled = v:IsMouseEnabled()
                        local strata = v:GetFrameStrata()
                        local width = v:GetWidth()
                        local height = v:GetHeight()
                        local alpha = v:GetAlpha()
                        
                        table.insert(nopFrames, {
                            name = k,
                            shown = shown,
                            visible = visible,
                            mouseEnabled = mouseEnabled,
                            strata = strata,
                            width = math.floor(width or 0),
                            height = math.floor(height or 0),
                            alpha = alpha,
                            frame = v
                        })
                    end
                end)
            end
        end
        
        if #nopFrames == 0 then
            TweaksUI:Print("No NOP_ frames found in _G")
        else
            TweaksUI:Print("Found " .. #nopFrames .. " NOP_ frames:")
            for _, f in ipairs(nopFrames) do
                local color = "|cffFFFFFF"
                if f.mouseEnabled then color = "|cffFF0000" end
                if not f.visible then color = "|cff888888" end
                TweaksUI:Print(string.format("  %s%s|r [%s] %dx%d shown=%s visible=%s mouse=%s alpha=%.1f",
                    color, f.name, f.strata, f.width, f.height, 
                    tostring(f.shown), tostring(f.visible), tostring(f.mouseEnabled), f.alpha))
            end
        end
        
    elseif cmd == "nopkill" then
        -- Disable mouse on all NOP_ frames
        TweaksUI:Print("|cffFF0000Killing mouse on NOP_ frames|r")
        local killed = 0
        
        for k, v in pairs(_G) do
            if type(k) == "string" and k:find("^NOP_") and type(v) == "table" then
                pcall(function()
                    if v.IsMouseEnabled and v:IsMouseEnabled() then
                        v:EnableMouse(false)
                        killed = killed + 1
                        TweaksUI:Print("  Killed: " .. k)
                    end
                end)
            end
        end
        
        TweaksUI:Print("Killed " .. killed .. " NOP_ frames - try clicking now!")

    elseif cmd == "safemode" then
        -- Toggle safe mode for DialogueUI compatibility
        TweaksUI.dialogueSafeMode = not TweaksUI.dialogueSafeMode
        if TweaksUI.dialogueSafeMode then
            TweaksUI:Print("|cff00FF00Dialogue Safe Mode ENABLED|r")
            TweaksUI:Print("TweaksUI will aggressively cleanup after DialogueUI interactions")
        else
            TweaksUI:Print("|cffFF0000Dialogue Safe Mode DISABLED|r")
        end
        
    elseif cmd == "deepclean" then
        -- Run deep mouse state cleanup
        TweaksUI:Print("|cffFF00FFDeep Mouse State Cleanup|r")
        
        local fixed = 0
        
        -- Reset TweaksUI mouseover frames
        if TweaksUI.UnitFramesVisibilityManager and TweaksUI.UnitFramesVisibilityManager.ResetAllMouseoverFrames then
            TweaksUI.UnitFramesVisibilityManager:ResetAllMouseoverFrames()
            TweaksUI:Print("  Reset UnitFrames mouseover frames")
            fixed = fixed + 1
        end
        
        -- Run deep cleanup
        if TweaksUI.DeepMouseStateCleanup then
            local deepFixed = TweaksUI.DeepMouseStateCleanup()
            fixed = fixed + deepFixed
        end
        
        -- Also cleanup invisible mouse blockers
        if TweaksUI.CleanupInvisibleMouseBlockers then
            local invisFixed = TweaksUI.CleanupInvisibleMouseBlockers()
            fixed = fixed + invisFixed
        end
        
        -- Force disable mouse on ALL TweaksUI-created frames at low strata
        local tuiFixed = 0
        for k, v in pairs(_G) do
            if type(k) == "string" and k:find("^TweaksUI") and type(v) == "table" then
                pcall(function()
                    if v.IsMouseEnabled and v:IsMouseEnabled() and v.GetFrameStrata then
                        local strata = v:GetFrameStrata()
                        if strata == "BACKGROUND" or strata == "LOW" then
                            v:EnableMouse(false)
                            tuiFixed = tuiFixed + 1
                            TweaksUI:Print("  Disabled: " .. k .. " [" .. strata .. "]")
                        end
                    end
                end)
            end
        end
        fixed = fixed + tuiFixed
        
        TweaksUI:Print("|cff00FF00Deep cleanup complete: " .. fixed .. " fixes|r - try clicking now!")

    elseif cmd == "mouseover" then
        -- Check state of TweaksUI mouseover detection frames
        TweaksUI:Print("|cffFF00FFTweaksUI Mouseover Frame Status|r")
        
        if TweaksUI.UnitFramesVisibilityManager then
            local vm = TweaksUI.UnitFramesVisibilityManager
            TweaksUI:Print("")
            TweaksUI:Print("|cff00CCFFUnitFrames VisibilityManager:|r")
            
            if vm.mouseoverFrames then
                local count = 0
                for unitType, mf in pairs(vm.mouseoverFrames) do
                    count = count + 1
                    local shown = mf:IsShown()
                    local mouseEnabled = mf:IsMouseEnabled()
                    local strata = mf:GetFrameStrata()
                    local width = mf:GetWidth()
                    local height = mf:GetHeight()
                    local left = mf:GetLeft() or 0
                    local bottom = mf:GetBottom() or 0
                    
                    local color = "|cffFFFFFF"
                    if mouseEnabled then color = "|cffFF0000" end  -- Red if mouse enabled
                    if not shown then color = "|cff888888" end  -- Gray if hidden
                    
                    TweaksUI:Print(string.format("  %s%s|r: shown=%s, mouse=%s, [%s] %dx%d at (%.0f,%.0f)",
                        color, unitType, tostring(shown), tostring(mouseEnabled), strata,
                        math.floor(width or 0), math.floor(height or 0), left, bottom))
                end
                
                if count == 0 then
                    TweaksUI:Print("  (no mouseover frames created)")
                end
            else
                TweaksUI:Print("  mouseoverFrames table not found")
            end
        else
            TweaksUI:Print("UnitFramesVisibilityManager not found")
        end
        
        -- Also check General module mouseover frames
        TweaksUI:Print("")
        TweaksUI:Print("|cff00CCFFSearching for other mouseover/detection frames:|r")
        local found = 0
        local function SearchForMouseover(frame, depth, path)
            if depth > 6 then return end
            pcall(function()
                local name = frame:GetName() or ""
                if name:lower():find("mouseover") or name:lower():find("hitframe") or name:lower():find("detector") then
                    local shown = frame:IsShown()
                    local mouseEnabled = frame:IsMouseEnabled()
                    local strata = frame:GetFrameStrata()
                    if shown then
                        found = found + 1
                        local color = mouseEnabled and "|cffFF0000" or "|cff00FF00"
                        TweaksUI:Print(string.format("  %s%s|r [%s] mouse=%s", color, name, strata, tostring(mouseEnabled)))
                    end
                end
                local children = {frame:GetChildren()}
                for _, child in ipairs(children) do
                    SearchForMouseover(child, depth + 1, path)
                end
            end)
        end
        SearchForMouseover(UIParent, 0, "UIParent")
        if found == 0 then
            TweaksUI:Print("  (none found)")
        end

    elseif cmd == "mouseworld" then
        -- Find what's blocking clicks from reaching WorldFrame
        TweaksUI:Print("|cffFF00FFWorld Click Blocker Finder|r")
        
        local screenWidth = UIParent:GetWidth()
        local screenHeight = UIParent:GetHeight()
        local testX = screenWidth / 2  -- Center of screen
        local testY = screenHeight * 0.7  -- Upper portion where blocking happens
        
        TweaksUI:Print(string.format("Testing at screen position: %.0f, %.0f", testX, testY))
        TweaksUI:Print("")
        
        -- Find all frames that contain this point and have mouse enabled
        local blockers = {}
        
        local function CheckFrame(frame, depth, path)
            if depth > 12 then return end
            
            pcall(function()
                local visible = frame:IsVisible()
                local mouseEnabled = frame:IsMouseEnabled()
                
                if visible then
                    -- Check if frame contains our test point
                    local left = frame:GetLeft()
                    local right = frame:GetRight()
                    local top = frame:GetTop()
                    local bottom = frame:GetBottom()
                    
                    if left and right and top and bottom then
                        -- Convert screen coords - test point is from bottom-left
                        if testX >= left and testX <= right and testY >= bottom and testY <= top then
                            local name = frame:GetName()
                            local strata = frame:GetFrameStrata()
                            local level = frame:GetFrameLevel()
                            local alpha = frame:GetAlpha()
                            local width = right - left
                            local height = top - bottom
                            
                            table.insert(blockers, {
                                name = name or path,
                                strata = strata,
                                level = level,
                                alpha = alpha,
                                mouseEnabled = mouseEnabled,
                                width = math.floor(width),
                                height = math.floor(height),
                                frame = frame
                            })
                        end
                    end
                end
                
                local children = {frame:GetChildren()}
                for i, child in ipairs(children) do
                    local childName = pcall(function() return child:GetName() end) and child:GetName()
                    CheckFrame(child, depth + 1, path .. "/" .. (childName or "[" .. i .. "]"))
                end
            end)
        end
        
        CheckFrame(UIParent, 0, "UIParent")
        
        -- Sort by strata then level (highest first = most likely blocker)
        local strataRank = {BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8}
        table.sort(blockers, function(a, b)
            local sa = strataRank[a.strata] or 0
            local sb = strataRank[b.strata] or 0
            if sa ~= sb then return sa > sb end
            return (a.level or 0) > (b.level or 0)
        end)
        
        TweaksUI:Print("Frames containing test point (" .. #blockers .. " total):")
        local mouseEnabledCount = 0
        for i, f in ipairs(blockers) do
            if f.mouseEnabled then
                mouseEnabledCount = mouseEnabledCount + 1
                local color = "|cffFF0000"  -- Red for mouse-enabled
                TweaksUI:Print(string.format("  %s[%s:%d] MOUSE|r %s (%dx%d, a=%.1f)", 
                    color, f.strata, f.level or 0, f.name, f.width, f.height, f.alpha))
            end
        end
        
        if mouseEnabledCount == 0 then
            TweaksUI:Print("  |cffFFFF00No frames with EnableMouse(true) at test point!|r")
            TweaksUI:Print("")
            TweaksUI:Print("Showing all frames at test point (first 15):")
            for i, f in ipairs(blockers) do
                if i <= 15 then
                    TweaksUI:Print(string.format("  [%s:%d] %s (a=%.1f)", f.strata, f.level or 0, f.name, f.alpha))
                end
            end
        end
        
        TweaksUI:Print("")
        TweaksUI:Print("|cffFFAA00If no mouse-enabled frames found, issue may be:|r")
        TweaksUI:Print("  - A frame using SetPropagateMouseClicks(false)")
        TweaksUI:Print("  - A secure frame blocking in protected mode")
        TweaksUI:Print("  - Input being captured at engine level")
        
    elseif cmd == "mouselow" then
        -- Kill mouse on ALL BACKGROUND and LOW strata frames
        TweaksUI:Print("|cffFF0000Killing mouse on ALL low-strata frames|r")
        
        local killed = 0
        local whitelist = {
            ["Minimap"] = true,
            ["MinimapCluster"] = true,
            ["MinimapBackdrop"] = true,
        }
        
        local function KillLowStrata(frame, depth, path)
            if depth > 10 then return end
            
            pcall(function()
                local visible = frame:IsVisible()
                local mouseEnabled = frame:IsMouseEnabled()
                local strata = frame:GetFrameStrata()
                local name = frame:GetName()
                
                if visible and mouseEnabled and (strata == "BACKGROUND" or strata == "LOW") then
                    if not (name and whitelist[name]) then
                        frame:EnableMouse(false)
                        killed = killed + 1
                        if killed <= 20 then
                            TweaksUI:Print("  Killed: " .. (name or path) .. " [" .. strata .. "]")
                        end
                    end
                end
                
                local children = {frame:GetChildren()}
                for i, child in ipairs(children) do
                    local childName = pcall(function() return child:GetName() end) and child:GetName()
                    KillLowStrata(child, depth + 1, path .. "/" .. (childName or "[" .. i .. "]"))
                end
            end)
        end
        
        KillLowStrata(UIParent, 0, "UIParent")
        
        if killed > 20 then
            TweaksUI:Print("  ... and " .. (killed - 20) .. " more")
        end
        TweaksUI:Print("|cff00FF00Killed " .. killed .. " low-strata frames|r - try clicking in 3D world!")

    elseif cmd == "tuiscan" then
        -- Scan specifically for TweaksUI frames that might be blocking
        TweaksUI:Print("|cffFF00FFTUI Frame Scan|r - Finding TweaksUI frames with mouse enabled...")
        
        local screenHeight = UIParent:GetHeight()
        local midpoint = screenHeight / 2
        local found = {}
        
        -- Scan for frames with "TweaksUI" or "Tweaks" in name
        local function ScanForTUI(frame, depth, path)
            if depth > 8 then return end
            
            pcall(function()
                local name = frame:GetName()
                local visible = frame:IsVisible()
                local mouseEnabled = frame:IsMouseEnabled()
                
                -- Check if it's a TweaksUI frame or has tweaks in the path
                local isTUI = (name and (name:find("TweaksUI") or name:find("Tweaks"))) or path:find("TweaksUI") or path:find("Tweaks")
                
                if visible and mouseEnabled then
                    local _, y = frame:GetCenter()
                    local height = frame:GetHeight() or 0
                    local width = frame:GetWidth() or 0
                    local top = y and (y + height/2) or 0
                    local alpha = frame:GetAlpha()
                    local strata = frame:GetFrameStrata()
                    
                    -- Frame is in upper half OR is a TUI frame
                    if (top > midpoint and width > 30 and height > 30) or isTUI then
                        table.insert(found, {
                            name = name or path,
                            strata = strata,
                            alpha = alpha,
                            width = math.floor(width),
                            height = math.floor(height),
                            top = math.floor(top or 0),
                            isTUI = isTUI,
                            frame = frame
                        })
                    end
                end
                
                local children = {frame:GetChildren()}
                for i, child in ipairs(children) do
                    local childName = pcall(function() return child:GetName() end) and child:GetName()
                    ScanForTUI(child, depth + 1, path .. "/" .. (childName or "[" .. i .. "]"))
                end
            end)
        end
        
        ScanForTUI(UIParent, 0, "UIParent")
        
        -- Sort - TUI frames first, then by strata
        local strataRank = {BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8}
        table.sort(found, function(a, b)
            if a.isTUI and not b.isTUI then return true end
            if not a.isTUI and b.isTUI then return false end
            return (strataRank[a.strata] or 0) < (strataRank[b.strata] or 0)
        end)
        
        local tuiCount = 0
        local otherCount = 0
        for _, f in ipairs(found) do
            if f.isTUI then tuiCount = tuiCount + 1 else otherCount = otherCount + 1 end
        end
        
        TweaksUI:Print("Found " .. tuiCount .. " TweaksUI frames, " .. otherCount .. " other frames")
        TweaksUI:Print("")
        TweaksUI:Print("|cff00FF00TweaksUI frames:|r")
        local shown = 0
        for _, f in ipairs(found) do
            if f.isTUI and shown < 20 then
                shown = shown + 1
                local color = "|cffFFFFFF"
                if f.strata == "BACKGROUND" then color = "|cffFF0000"
                elseif f.strata == "LOW" then color = "|cffFFAA00"
                end
                TweaksUI:Print(string.format("  %s[%s]|r %s (%dx%d)", color, f.strata, f.name, f.width, f.height))
            end
        end
        
        TweaksUI:Print("")
        TweaksUI:Print("|cffFFFF00Low strata non-TUI frames in upper screen:|r")
        shown = 0
        for _, f in ipairs(found) do
            if not f.isTUI and (f.strata == "BACKGROUND" or f.strata == "LOW" or f.strata == "MEDIUM") and shown < 10 then
                shown = shown + 1
                TweaksUI:Print(string.format("  [%s] %s (%dx%d, top=%d)", f.strata, f.name, f.width, f.height, f.top))
            end
        end
        
    elseif cmd == "tuireset" then
        -- Force reset mouse on all TweaksUI frames that shouldn't have it
        TweaksUI:Print("|cffFF0000Force Reset TweaksUI Mouse States|r")
        
        local reset = 0
        
        -- Reset VisibilityManager mouseover frames specifically
        if TweaksUI.UnitFramesVisibilityManager then
            TweaksUI:Print("Resetting UnitFrames VisibilityManager mouseover frames...")
            TweaksUI.UnitFramesVisibilityManager:ResetAllMouseoverFrames()
            reset = reset + 1
        end
        
        -- Find and reset any frame with "mouseover" or "detection" in name/path
        local function ResetDetectionFrames(frame, depth, path)
            if depth > 6 then return end
            
            pcall(function()
                local name = frame:GetName() or ""
                local nameLower = name:lower()
                local pathLower = path:lower()
                
                -- Reset frames that look like detection/mouseover frames
                if frame:IsMouseEnabled() and (
                    nameLower:find("mouseover") or 
                    nameLower:find("detector") or
                    nameLower:find("hitframe") or
                    pathLower:find("mouseover")
                ) then
                    frame:EnableMouse(false)
                    TweaksUI:Print("  Reset: " .. (name ~= "" and name or path))
                    reset = reset + 1
                end
                
                local children = {frame:GetChildren()}
                for i, child in ipairs(children) do
                    local childName = pcall(function() return child:GetName() end) and child:GetName()
                    ResetDetectionFrames(child, depth + 1, path .. "/" .. (childName or "[" .. i .. "]"))
                end
            end)
        end
        
        ResetDetectionFrames(UIParent, 0, "UIParent")
        
        -- Also explicitly disable mouse on BACKGROUND strata TweaksUI frames
        local function DisableBgMouse(frame, depth, path)
            if depth > 6 then return end
            
            pcall(function()
                local name = frame:GetName() or ""
                local strata = frame:GetFrameStrata()
                local visible = frame:IsVisible()
                local mouseEnabled = frame:IsMouseEnabled()
                
                -- TweaksUI BACKGROUND frames shouldn't have mouse enabled
                if visible and mouseEnabled and strata == "BACKGROUND" and name:find("TweaksUI") then
                    frame:EnableMouse(false)
                    TweaksUI:Print("  Disabled BACKGROUND: " .. name)
                    reset = reset + 1
                end
                
                local children = {frame:GetChildren()}
                for i, child in ipairs(children) do
                    local childName = pcall(function() return child:GetName() end) and child:GetName()
                    DisableBgMouse(child, depth + 1, path .. "/" .. (childName or "[" .. i .. "]"))
                end
            end)
        end
        
        DisableBgMouse(UIParent, 0, "UIParent")
        
        TweaksUI:Print("Reset " .. reset .. " frames - try clicking now!")
        
    elseif cmd == "mousestate" then
        -- Check various game states that might affect mouse input
        TweaksUI:Print("|cffFFFF00Mouse Input State Check|r")
        
        -- Check UIParent state
        TweaksUI:Print("|cff00CCFFUIParent:|r")
        TweaksUI:Print("  Shown: " .. tostring(UIParent:IsShown()))
        TweaksUI:Print("  Alpha: " .. tostring(UIParent:GetAlpha()))
        TweaksUI:Print("  Visible: " .. tostring(UIParent:IsVisible()))
        TweaksUI:Print("  MouseEnabled: " .. tostring(UIParent:IsMouseEnabled()))
        
        -- Check if we're in some kind of interaction mode
        TweaksUI:Print("|cff00CCFFGame State:|r")
        if UnitExists("npc") then
            TweaksUI:Print("  NPC Target: " .. (UnitName("npc") or "unknown"))
        else
            TweaksUI:Print("  NPC Target: none")
        end
        
        if SpellIsTargeting and SpellIsTargeting() then
            TweaksUI:Print("  SpellIsTargeting: YES")
        end
        
        if InCinematic and InCinematic() then
            TweaksUI:Print("  InCinematic: YES")
        end
        
        if IsMouselooking and IsMouselooking() then
            TweaksUI:Print("  IsMouselooking: YES")
        end
        
        -- Check cursor mode
        if GetCursorInfo then
            local cursorType = GetCursorInfo()
            TweaksUI:Print("  CursorInfo: " .. tostring(cursorType or "nil"))
        end
        
        -- Check for modal frames
        TweaksUI:Print("|cff00CCFFModal Check:|r")
        local modalFrames = {"StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4"}
        for _, name in ipairs(modalFrames) do
            local frame = _G[name]
            if frame and frame:IsShown() then
                TweaksUI:Print("  " .. name .. " is SHOWN")
            end
        end
        
        -- Check for soft target
        if C_SoftTarget then
            local softTarget = C_SoftTarget.GetSoftTarget and C_SoftTarget.GetSoftTarget()
            TweaksUI:Print("  SoftTarget: " .. tostring(softTarget))
        end
        
    elseif cmd == "mouseunstick" then
        -- Try various methods to unstick mouse input
        TweaksUI:Print("|cff00FF00Attempting to unstick mouse input...|r")
        
        -- Clear any cursor item
        if ClearCursor then
            ClearCursor()
            TweaksUI:Print("  Cleared cursor")
        end
        
        -- Cancel spell targeting
        if SpellStopTargeting then
            SpellStopTargeting()
            TweaksUI:Print("  Stopped spell targeting")
        end
        
        -- Clear soft target
        if C_SoftTarget and C_SoftTarget.ClearSoftTarget then
            C_SoftTarget.ClearSoftTarget()
            TweaksUI:Print("  Cleared soft target")
        end
        
        -- Force UIParent refresh
        UIParent:Show()
        UIParent:SetAlpha(1)
        TweaksUI:Print("  Refreshed UIParent")
        
        -- Try closing any open panels
        if CloseAllWindows then
            pcall(CloseAllWindows)
            TweaksUI:Print("  Closed all windows")
        end
        
        -- Cancel any cinematics
        if StopCinematic then
            pcall(StopCinematic)
        end
        
        -- Try to force a UI refresh
        if UpdateMicroButtons then
            pcall(UpdateMicroButtons)
        end
        
        TweaksUI:Print("|cff00FF00Done|r - try clicking now!")

    elseif cmd == "mousetop" then
        -- NUCLEAR: Disable mouse on ALL frames in upper half of screen
        TweaksUI:Print("|cffFF0000NUCLEAR: Killing mouse on ALL upper-screen frames|r")
        
        local screenHeight = UIParent:GetHeight()
        local midpoint = screenHeight / 2
        local killed = 0
        
        local whitelist = {
            ["MinimapCluster"] = true,
            ["Minimap"] = true,
            ["GameTooltip"] = true,
        }
        
        local function KillUpper(frame, depth, path)
            if depth > 10 then return end
            
            pcall(function()
                local visible = frame:IsVisible()
                local mouseEnabled = frame:IsMouseEnabled()
                local name = frame:GetName()
                
                if visible and mouseEnabled and not (name and whitelist[name]) then
                    local _, y = frame:GetCenter()
                    local height = frame:GetHeight() or 0
                    local top = y and (y + height/2) or 0
                    
                    -- Frame is in upper half
                    if top > midpoint then
                        pcall(function() frame:EnableMouse(false) end)
                        pcall(function() 
                            if frame.EnableMouseClicks then frame:EnableMouseClicks(false) end 
                        end)
                        killed = killed + 1
                        if killed <= 15 then
                            TweaksUI:Print("  Killed: " .. (name or path))
                        end
                    end
                end
                
                -- Recurse
                local children = {frame:GetChildren()}
                for i, child in ipairs(children) do
                    local childName = pcall(function() return child:GetName() end) and child:GetName()
                    KillUpper(child, depth + 1, path .. "/" .. (childName or "[" .. i .. "]"))
                end
            end)
        end
        
        KillUpper(UIParent, 0, "UIParent")
        
        if killed > 15 then
            TweaksUI:Print("  ... and " .. (killed - 15) .. " more")
        end
        TweaksUI:Print("|cff00FF00Killed mouse on " .. killed .. " frames|r - try clicking now!")

    elseif cmd == "mousedeep" then
        -- DEEP scan: Check EVERY frame recursively, including WorldFrame
        TweaksUI:Print("|cffFF00FFDEEP Mouse Block Scan|r")
        TweaksUI:Print("Scanning ALL frames for potential blockers...")
        
        local screenHeight = UIParent:GetHeight()
        local midpoint = screenHeight / 2
        local found = {}
        
        local function ScanFrame(frame, depth, path)
            if depth > 10 then return end
            
            pcall(function()
                local shown = frame:IsShown()
                local visible = frame:IsVisible()
                local mouseEnabled = frame:IsMouseEnabled()
                
                -- Also check for MouseClickEnabled if available
                local clickEnabled = true
                if frame.IsMouseClickEnabled then
                    clickEnabled = frame:IsMouseClickEnabled()
                end
                
                if visible and (mouseEnabled or not clickEnabled) then
                    local _, y = frame:GetCenter()
                    local height = frame:GetHeight() or 0
                    local width = frame:GetWidth() or 0
                    local top = y and (y + height/2) or 0
                    local alpha = frame:GetAlpha()
                    local strata = frame:GetFrameStrata()
                    local name = frame:GetName()
                    
                    -- Frame is in upper half and reasonably sized
                    if top > midpoint and width > 50 and height > 50 then
                        table.insert(found, {
                            name = name or path,
                            strata = strata,
                            alpha = alpha,
                            width = math.floor(width),
                            height = math.floor(height),
                            top = math.floor(top),
                            mouseEnabled = mouseEnabled,
                            clickEnabled = clickEnabled,
                            frame = frame
                        })
                    end
                end
                
                -- Recurse into children
                local children = {frame:GetChildren()}
                for i, child in ipairs(children) do
                    local childName = pcall(function() return child:GetName() end) and child:GetName()
                    ScanFrame(child, depth + 1, path .. "/" .. (childName or "[" .. i .. "]"))
                end
            end)
        end
        
        -- Scan UIParent hierarchy
        ScanFrame(UIParent, 0, "UIParent")
        
        -- Also scan WorldFrame hierarchy
        pcall(function()
            ScanFrame(WorldFrame, 0, "WorldFrame")
        end)
        
        -- Sort by strata priority
        local strataRank = {BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8}
        table.sort(found, function(a, b)
            return (strataRank[a.strata] or 0) > (strataRank[b.strata] or 0)
        end)
        
        TweaksUI:Print("Found " .. #found .. " frames in upper screen:")
        for i, f in ipairs(found) do
            if i <= 20 then
                local color = "|cffFFFFFF"
                if f.alpha == 0 then color = "|cffFF0000" 
                elseif not f.clickEnabled then color = "|cffFF00FF"
                elseif f.strata == "DIALOG" or f.strata == "FULLSCREEN" then color = "|cffFFAA00"
                elseif f.strata == "HIGH" then color = "|cffFFFF00"
                end
                local clickStr = f.clickEnabled and "" or " CLICK=OFF"
                TweaksUI:Print(string.format("  %s[%s]|r %s (%dx%d, a=%.1f%s)", 
                    color, f.strata, f.name, f.width, f.height, f.alpha, clickStr))
            end
        end
        if #found > 20 then
            TweaksUI:Print("  ... and " .. (#found - 20) .. " more")
        end
        
        -- Also check for any frame with OnMouseDown that might be swallowing clicks
        TweaksUI:Print("")
        TweaksUI:Print("|cffFFFF00Checking for frames swallowing mouse events...|r")
        local swallowers = 0
        for i, f in ipairs(found) do
            if f.frame then
                local hasMouseDown = f.frame:GetScript("OnMouseDown")
                local hasClick = f.frame:GetScript("OnClick")
                if hasMouseDown or hasClick then
                    swallowers = swallowers + 1
                    if swallowers <= 10 then
                        TweaksUI:Print("  " .. f.name .. " has " .. (hasMouseDown and "OnMouseDown " or "") .. (hasClick and "OnClick" or ""))
                    end
                end
            end
        end
        if swallowers > 10 then
            TweaksUI:Print("  ... and " .. (swallowers - 10) .. " more with handlers")
        end

    elseif cmd == "layoutclean" then
        -- Force cleanup of Layout mode overlays
        TweaksUI:Print("|cffFF0000Force Layout Mode Cleanup|r")
        
        -- Exit layout mode if active
        if TweaksUI.Layout and TweaksUI.Layout.ExitLayoutMode then
            TweaksUI.Layout:ExitLayoutMode()
            TweaksUI:Print("  Called ExitLayoutMode()")
        end
        
        -- Hide all Layout UI elements
        if TweaksUI.LayoutUI then
            if TweaksUI.LayoutUI.HideOverlays then
                TweaksUI.LayoutUI:HideOverlays()
                TweaksUI:Print("  Called HideOverlays()")
            end
            if TweaksUI.LayoutUI.HideCoordPanel then
                TweaksUI.LayoutUI:HideCoordPanel()
                TweaksUI:Print("  Called HideCoordPanel()")
            end
        end
        
        -- Look for any TweaksUI_Layout frames and hide them
        local layoutFrames = {}
        for k, v in pairs(_G) do
            if type(k) == "string" and k:find("TweaksUI_Layout") and type(v) == "table" then
                if v.Hide and v.EnableMouse then
                    pcall(function() 
                        v:Hide()
                        v:EnableMouse(false)
                    end)
                    table.insert(layoutFrames, k)
                end
            end
        end
        
        if #layoutFrames > 0 then
            TweaksUI:Print("  Hidden frames: " .. table.concat(layoutFrames, ", "))
        end
        
        -- Also clean up the container frame
        local container = _G["TweaksUI_LayoutContainer"]
        if container then
            container:Hide()
            container:EnableMouse(false)
            TweaksUI:Print("  Hidden TweaksUI_LayoutContainer")
        end
        
        TweaksUI:Print("|cff00FF00Done|r - try clicking now")
        
    elseif cmd == "mouseclean" then
        -- Manual trigger of DialogueUI cleanup
        TweaksUI:Print("|cff00FF00Manual DialogueUI Cleanup|r")
        local cleaned = TweaksUI.CleanupInvisibleMouseBlockers()
        TweaksUI:Print("Cleaned " .. cleaned .. " frames")
        
        -- Also scan for frames blocking the top half specifically
        TweaksUI:Print("")
        TweaksUI:Print("|cffFFFF00Scanning for TOP-anchored blocking frames...|r")
        local screenHeight = UIParent:GetHeight()
        local midpoint = screenHeight / 2
        
        local topBlockers = {}
        local children = {UIParent:GetChildren()}
        for _, child in ipairs(children) do
            pcall(function()
                if child:IsShown() and child:IsMouseEnabled() then
                    local _, y = child:GetCenter()
                    local height = child:GetHeight()
                    local top = y and (y + height/2) or 0
                    local bottom = y and (y - height/2) or 0
                    
                    -- Frame is in upper half and extends significantly
                    if top > midpoint and height > 50 then
                        local name = child:GetName() or "[unnamed]"
                        local strata = child:GetFrameStrata()
                        local alpha = child:GetAlpha()
                        table.insert(topBlockers, {
                            name = name,
                            strata = strata,
                            alpha = alpha,
                            top = math.floor(top),
                            bottom = math.floor(bottom),
                            height = math.floor(height),
                            frame = child
                        })
                    end
                end
            end)
        end
        
        -- Sort by strata
        local strataRank = {BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8}
        table.sort(topBlockers, function(a, b)
            return (strataRank[a.strata] or 0) > (strataRank[b.strata] or 0)
        end)
        
        TweaksUI:Print("Found " .. #topBlockers .. " mouse-enabled frames in upper screen:")
        for i, f in ipairs(topBlockers) do
            if i <= 15 then
                local color = "|cffFFFFFF"
                if f.alpha == 0 then color = "|cffFF0000" end
                if f.strata == "DIALOG" or f.strata == "FULLSCREEN" then color = "|cffFFAA00" end
                TweaksUI:Print(string.format("  %s[%s]|r %s (alpha=%.1f, y=%d-%d)", 
                    color, f.strata, f.name, f.alpha, f.bottom, f.top))
            end
        end
        
    elseif cmd == "mouserestore" then
        -- Aggressive mouse restoration
        TweaksUI:Print("|cff00FF00Aggressive Mouse Restore|r")
        
        -- 1. Ensure UIParent is in a good state
        UIParent:Show()
        UIParent:SetAlpha(1)
        TweaksUI:Print("  UIParent: shown, alpha=1")
        
        -- 2. Clear any soft targeting
        if ClearTarget then
            pcall(ClearTarget)
        end
        
        -- 3. Force WorldFrame to not intercept
        pcall(function() WorldFrame:EnableMouse(false) end)
        TweaksUI:Print("  WorldFrame: mouse disabled")
        
        -- 4. Check for any TweaksUI frames that might be blocking
        local tweaksFrames = {
            "TweaksUI_LayoutContainer", "TweaksUI_KeybindModeFrame", 
            "TweaksUI_LayoutGrid", "TweaksUI_LayoutKeyboard", 
            "TweaksUI_SnapIndicator"
        }
        for _, name in ipairs(tweaksFrames) do
            local frame = _G[name]
            if frame then
                frame:EnableMouse(false)
                pcall(function() frame:EnableMouseMotion(false) end)
                pcall(function() frame:EnableMouseClicks(false) end)
                frame:Hide()
            end
        end
        TweaksUI:Print("  TweaksUI frames: all hidden, mouse disabled")
        
        -- 5. Check for UIFrameContainers that might be blocking
        local containers = {
            "TweaksUI_UIContainer_TalkingHead",
            "TweaksUI_UIContainer_BuffFrame",
            "TweaksUI_UIContainer_DebuffFrame",
        }
        for _, name in ipairs(containers) do
            local frame = _G[name]
            if frame then
                pcall(function() frame:EnableMouse(false) end)
                pcall(function() frame:EnableMouseMotion(false) end)
                TweaksUI:Print("  " .. name .. ": mouse disabled")
            end
        end
        
        -- 6. Try to trigger UIParent layout update
        pcall(function() UIParent:GetScript("OnSizeChanged")(UIParent) end)
        
        TweaksUI:Print("|cff00FF00Done|r - try clicking now")
        
    elseif cmd == "mouseinfo" then
        -- Deep diagnostic: Check what's actually capturing mouse
        TweaksUI:Print("|cffFF00FFMouse Input Deep Diagnostic|r")
        
        -- Midnight API: GetMouseFoci() returns table, GetMouseFocus() was removed
        local focus = nil
        if GetMouseFoci then
            local foci = GetMouseFoci()
            focus = foci and foci[1]
        end
        -- Note: GetMouseFocus() was removed in Midnight
        
        if focus then
            local nameOK, name = pcall(function() return focus:GetName() end)
            local strataOK, strata = pcall(function() return focus:GetFrameStrata() end)
            local mouseOK, mouseEnabled = pcall(function() return focus:IsMouseEnabled() end)
            local parentOK, parent = pcall(function() return focus:GetParent() and focus:GetParent():GetName() end)
            TweaksUI:Print("MouseFocus: " .. ((nameOK and name) or "[unnamed]"))
            TweaksUI:Print("  Strata: " .. ((strataOK and strata) or "unknown"))
            TweaksUI:Print("  Mouse: " .. tostring((mouseOK and mouseEnabled) or "unknown"))
            TweaksUI:Print("  Parent: " .. ((parentOK and parent) or "[unnamed/none]"))
        else
            TweaksUI:Print("MouseFocus: nil (no frame under cursor)")
        end
        
        -- Check UIParent state
        TweaksUI:Print("")
        TweaksUI:Print("|cff00CCFFUIParent State:|r")
        TweaksUI:Print("  Shown: " .. tostring(UIParent:IsShown()))
        TweaksUI:Print("  Alpha: " .. tostring(UIParent:GetAlpha()))
        TweaksUI:Print("  Mouse: " .. tostring(UIParent:IsMouseEnabled()))
        TweaksUI:Print("  Visible: " .. tostring(UIParent:IsVisible()))
        
        -- Check WorldFrame children
        TweaksUI:Print("")
        TweaksUI:Print("|cff00CCFFWorldFrame Children (mouse-enabled):|r")
        local worldChildren = {WorldFrame:GetChildren()}
        local worldMouseEnabled = 0
        for _, child in ipairs(worldChildren) do
            pcall(function()
                if child:IsShown() and child:IsMouseEnabled() then
                    local name = child:GetName() or "[anon]"
                    local width, height = child:GetWidth(), child:GetHeight()
                    TweaksUI:Print("  " .. name .. " (" .. math.floor(width) .. "x" .. math.floor(height) .. ")")
                    worldMouseEnabled = worldMouseEnabled + 1
                end
            end)
        end
        if worldMouseEnabled == 0 then
            TweaksUI:Print("  (none)")
        end
        
        -- Check for frames with SetHitRectInsets that might be blocking
        TweaksUI:Print("")
        TweaksUI:Print("|cff00CCFFDialogueUI Frames:|r")
        local duiFrames = {"DUIQuestFrame", "DUIQuestItemDisplay", "DUIDialogSettings", "DUIBookUIFrame"}
        for _, name in ipairs(duiFrames) do
            local frame = _G[name]
            if frame then
                local shown = frame:IsShown()
                local mouse = pcall(function() return frame:IsMouseEnabled() end) and frame:IsMouseEnabled()
                local strata = frame:GetFrameStrata()
                local parent = frame:GetParent() and frame:GetParent():GetName() or "[none]"
                TweaksUI:Print("  " .. name .. ": shown=" .. tostring(shown) .. ", mouse=" .. tostring(mouse) .. ", strata=" .. strata .. ", parent=" .. parent)
            end
        end
        
        -- Check DialogueUI addon table if available
        TweaksUI:Print("")
        if _G["DialogueUI"] then
            TweaksUI:Print("|cffFFAA00DialogueUI global found|r")
        end
        
        -- Check if DialogueUI addon is loaded using C_AddOns (modern API)
        if C_AddOns and C_AddOns.IsAddOnLoaded then
            if C_AddOns.IsAddOnLoaded("DialogueUI") then
                TweaksUI:Print("DialogueUI addon is loaded")
            end
        elseif IsAddOnLoaded then
            if IsAddOnLoaded("DialogueUI") then
                TweaksUI:Print("DialogueUI addon is loaded")
            end
        end
        
    elseif cmd == "mouseblock" then
        -- AGGRESSIVE scan: Find ALL frames at blocking strata, regardless of size
        TweaksUI:Print("|cffFF0000AGGRESSIVE Mouse Block Scan|r")
        TweaksUI:Print("Looking for ANY frame at HIGH/DIALOG/FULLSCREEN strata...")
        
        local targetStrata = {HIGH = true, DIALOG = true, FULLSCREEN = true, FULLSCREEN_DIALOG = true, TOOLTIP = true}
        local found = {}
        
        local function ScanAll(frame, depth, path)
            if depth > 8 then return end
            
            pcall(function()
                local shownOK, shown = pcall(function() return frame:IsShown() end)
                local mouseOK, mouseEnabled = pcall(function() return frame:IsMouseEnabled() end)
                local strataOK, strata = pcall(function() return frame:GetFrameStrata() end)
                local nameOK, name = pcall(function() return frame:GetName() end)
                local widthOK, width = pcall(function() return frame:GetWidth() end)
                local heightOK, height = pcall(function() return frame:GetHeight() end)
                
                strata = (strataOK and strata) or "UNKNOWN"
                name = (nameOK and name) or nil
                width = (widthOK and width) or 0
                height = (heightOK and height) or 0
                
                -- Log ALL visible, mouse-enabled frames at target strata
                if (shownOK and shown) and (mouseOK and mouseEnabled) and targetStrata[strata] then
                    local displayName = name or path
                    table.insert(found, {
                        name = displayName,
                        strata = strata,
                        width = math.floor(width),
                        height = math.floor(height),
                        frame = frame
                    })
                end
                
                local childrenOK, children = pcall(function() return {frame:GetChildren()} end)
                if childrenOK and children then
                    for _, child in ipairs(children) do
                        local childNameOK, childName = pcall(function() return child:GetName() end)
                        ScanAll(child, depth + 1, path .. "/" .. ((childNameOK and childName) or "[anon]"))
                    end
                end
            end)
        end
        
        if UIParent then
            ScanAll(UIParent, 0, "UIParent")
        end
        
        -- Sort by strata priority
        local strataRank = {MEDIUM = 1, HIGH = 2, DIALOG = 3, FULLSCREEN = 4, FULLSCREEN_DIALOG = 5, TOOLTIP = 6}
        table.sort(found, function(a, b)
            return (strataRank[a.strata] or 0) > (strataRank[b.strata] or 0)
        end)
        
        TweaksUI:Print("Found " .. #found .. " mouse-enabled frames at blocking strata:")
        for i, r in ipairs(found) do
            if i <= 25 then
                local color = "|cffFFFF00"
                if r.strata == "TOOLTIP" then color = "|cffFF0000"
                elseif r.strata == "FULLSCREEN_DIALOG" then color = "|cffFF4400"
                elseif r.strata == "FULLSCREEN" or r.strata == "DIALOG" then color = "|cffFFAA00"
                end
                TweaksUI:Print(string.format("  %s[%s]|r %s (%dx%d)", color, r.strata, r.name, r.width, r.height))
            end
        end
        if #found > 25 then
            TweaksUI:Print("  ... and " .. (#found - 25) .. " more")
        end
        TweaksUI:Print("")
        TweaksUI:Print("Use |cff00CCFF/tui mousekill|r to disable mouse on ALL these frames")
        
    elseif cmd == "mouseworldkill" then
        -- Kill mouse on WorldFrame children
        TweaksUI:Print("|cffFF0000Killing mouse on WorldFrame children...|r")
        local killed = 0
        
        local worldChildren = {WorldFrame:GetChildren()}
        for _, child in ipairs(worldChildren) do
            pcall(function()
                if child:IsShown() then
                    local name = child:GetName() or "[anon]"
                    pcall(function() child:EnableMouse(false) end)
                    pcall(function() child:EnableMouseMotion(false) end)
                    TweaksUI:Print("  Killed: " .. name)
                    killed = killed + 1
                end
            end)
        end
        
        -- Also try to disable mouse on WorldFrame itself
        pcall(function() WorldFrame:EnableMouse(false) end)
        
        TweaksUI:Print("Killed " .. killed .. " WorldFrame children")
        
    elseif cmd == "mousekill" then
        -- NUCLEAR option: disable mouse on ALL frames at blocking strata
        TweaksUI:Print("|cffFF0000NUCLEAR Mouse Kill|r - Disabling mouse on ALL blocking strata frames...")
        
        local targetStrata = {HIGH = true, DIALOG = true, FULLSCREEN = true, FULLSCREEN_DIALOG = true}
        local killed = 0
        
        -- Whitelist frames that SHOULD have mouse enabled
        local whitelist = {
            ["ChatFrame1EditBox"] = true,
            ["GameMenuFrame"] = true,
            ["SettingsPanel"] = true,
            ["InterfaceOptionsFrame"] = true,
        }
        
        local function KillMouse(frame, depth, path)
            if depth > 8 then return end
            
            pcall(function()
                local shownOK, shown = pcall(function() return frame:IsShown() end)
                local mouseOK, mouseEnabled = pcall(function() return frame:IsMouseEnabled() end)
                local strataOK, strata = pcall(function() return frame:GetFrameStrata() end)
                local nameOK, name = pcall(function() return frame:GetName() end)
                
                strata = (strataOK and strata) or "UNKNOWN"
                name = (nameOK and name) or nil
                
                if (shownOK and shown) and (mouseOK and mouseEnabled) and targetStrata[strata] then
                    -- Skip whitelisted frames
                    if not (name and whitelist[name]) then
                        pcall(function() frame:EnableMouse(false) end)
                        local displayName = name or path
                        TweaksUI:Print("  Killed: " .. displayName .. " [" .. strata .. "]")
                        killed = killed + 1
                    end
                end
                
                local childrenOK, children = pcall(function() return {frame:GetChildren()} end)
                if childrenOK and children then
                    for _, child in ipairs(children) do
                        local childNameOK, childName = pcall(function() return child:GetName() end)
                        KillMouse(child, depth + 1, path .. "/" .. ((childNameOK and childName) or "[anon]"))
                    end
                end
            end)
        end
        
        if UIParent then
            KillMouse(UIParent, 0, "UIParent")
        end
        
        if killed > 0 then
            TweaksUI:Print("|cff00FF00Killed mouse on " .. killed .. " frames|r - Try clicking now!")
        else
            TweaksUI:Print("No frames to kill")
        end
        
    elseif cmd == "mousescan" then
        -- Deep scan: Report ALL frames that could potentially block mouse input
        TweaksUI:Print("|cffFFFF00Deep Mouse Scan|r - Analyzing frame hierarchy...")
        
        local screenWidth = GetScreenWidth()
        local minSize = screenWidth * 0.2  -- 20% of screen width
        local results = {}
        
        local strataOrder = {"BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP"}
        
        local function ScanFrame(frame, depth, path)
            if depth > 6 then return end
            
            -- Wrap everything in pcall to handle any frame that doesn't behave as expected
            local success, err = pcall(function()
                local nameOK, name = pcall(function() return frame:GetName() end)
                local displayPath = (nameOK and name) or path
                
                -- Check this frame
                local shownOK, shown = pcall(function() return frame:IsShown() end)
                if shownOK and shown then
                    local widthOK, width = pcall(function() return frame:GetWidth() end)
                    local heightOK, height = pcall(function() return frame:GetHeight() end)
                    width = (widthOK and width) or 0
                    height = (heightOK and height) or 0
                    
                    local mouseOK, mouseEnabled = pcall(function() return frame:IsMouseEnabled() end)
                    mouseEnabled = mouseOK and mouseEnabled
                    
                    local strataOK, strata = pcall(function() return frame:GetFrameStrata() end)
                    strata = (strataOK and strata) or "UNKNOWN"
                    
                    if mouseEnabled and (width > minSize or height > minSize) then
                        table.insert(results, {
                            name = displayPath,
                            strata = strata,
                            width = math.floor(width),
                            height = math.floor(height),
                            mouseEnabled = mouseEnabled
                        })
                    end
                end
                
                -- Scan children
                local childrenOK, children = pcall(function() return {frame:GetChildren()} end)
                if childrenOK and children then
                    for _, child in ipairs(children) do
                        local childNameOK, childName = pcall(function() return child:GetName() end)
                        local childPath = path .. "/" .. ((childNameOK and childName) or "[anon]")
                        ScanFrame(child, depth + 1, childPath)
                    end
                end
            end)
        end
        
        if UIParent then
            ScanFrame(UIParent, 0, "UIParent")
        end
        
        -- Sort by strata (highest first)
        local strataRank = {}
        for i, s in ipairs(strataOrder) do strataRank[s] = i end
        table.sort(results, function(a, b)
            return (strataRank[a.strata] or 0) > (strataRank[b.strata] or 0)
        end)
        
        TweaksUI:Print("Found " .. #results .. " large, visible, mouse-enabled frames:")
        for i, r in ipairs(results) do
            if i <= 15 then  -- Limit output
                local color = (r.strata == "TOOLTIP" or r.strata == "FULLSCREEN_DIALOG") and "|cffFF0000" or 
                              (r.strata == "DIALOG" or r.strata == "FULLSCREEN") and "|cffFFAA00" or "|cffFFFF00"
                TweaksUI:Print(string.format("  %s[%s]|r %s (%dx%d)", color, r.strata, r.name, r.width, r.height))
            end
        end
        if #results > 15 then
            TweaksUI:Print("  ... and " .. (#results - 15) .. " more")
        end
        TweaksUI:Print("")
        TweaksUI:Print("Red = highest priority to check, Orange = medium, Yellow = lower")
        TweaksUI:Print("Use |cff00CCFF/tui mousefix|r to disable mouse on blocking frames")
        
    elseif cmd == "mousediag" then
        -- Quick diagnostic for common issues
        TweaksUI:Print("|cffFFFF00Mouse Blocking Quick Check|r")
        
        local function CheckFrame(name, source)
            local frame = _G[name]
            if not frame then return end
            
            local shown = frame:IsShown()
            local mouseOK, mouse = pcall(function() return frame:IsMouseEnabled() end)
            mouse = mouseOK and mouse or false
            local strata = frame:GetFrameStrata()
            local width, height = frame:GetWidth() or 0, frame:GetHeight() or 0
            
            local status
            if shown and mouse then
                status = "|cffFF0000BLOCKING|r"
            elseif shown then
                status = "|cff00FF00shown (mouse off)|r"
            else
                status = "|cff888888hidden|r"
            end
            
            TweaksUI:Print(string.format("  %s: %s [%s, %dx%d]", name, status, strata, math.floor(width), math.floor(height)))
        end
        
        TweaksUI:Print("|cff00CCFFTweaksUI Fullscreen Frames:|r")
        CheckFrame("TweaksUI_LayoutContainer", "TweaksUI")
        CheckFrame("TweaksUI_KeybindModeFrame", "TweaksUI")
        CheckFrame("TweaksUI_LayoutGrid", "TweaksUI")
        CheckFrame("TweaksUI_LayoutKeyboard", "TweaksUI")
        
        TweaksUI:Print("|cff00CCFFDialogueUI Frames:|r")
        CheckFrame("DUIQuestFrame", "DialogueUI")
        CheckFrame("DUIQuestItemDisplay", "DialogueUI")
        CheckFrame("DUIDialogSettings", "DialogueUI")
        CheckFrame("DUIBookUIFrame", "DialogueUI")
        
        TweaksUI:Print("")
        TweaksUI:Print("Commands: |cff00CCFF/tui mousefix|r (quick fix) | |cff00CCFF/tui mousescan|r (deep scan)")
        
    elseif cmd == "stats" then
        -- Toggle stats window
        TweaksUI:ToggleStatsWindow()
        
    else
        TweaksUI:Print("Unknown command: " .. cmd)
        TweaksUI:Print("Type /tui help for commands")
    end
end

-- Register slash commands
for _, cmd in ipairs(TweaksUI.SLASH_COMMANDS) do
    local cmdName = cmd:upper():gsub("/", "")
    _G["SLASH_" .. cmdName .. "1"] = cmd
    SlashCmdList[cmdName] = HandleSlashCommand
end

-- Standalone /tuistats command for quick access
SLASH_TUISTATS1 = "/tuistats"
SlashCmdList["TUISTATS"] = function()
    HandleSlashCommand("stats")
end
