-- TweaksUI Settings
-- Main settings hub UI - dockable panels for module configuration

local ADDON_NAME, TweaksUI = ...

TweaksUI.Settings = {}
local Settings = TweaksUI.Settings

-- ============================================================
-- CONSTANTS
-- ============================================================
local HUB_WIDTH = 240
local HUB_HEIGHT = 390
local BUTTON_WIDTH = 200
local BUTTON_HEIGHT = 28
local BUTTON_SPACING = 6
local SECTION_SPACING = 16

local PANEL_WIDTH = 480
local PANEL_HEIGHT = 600

-- ============================================================
-- DARK BACKDROP TEMPLATE
-- ============================================================
local darkBackdrop = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
}

-- Panel references
local hubPanel = nil
local allPanels = {}
local moduleSettingsPanels = {}

-- Static popup for reload prompt
StaticPopupDialogs["TWEAKSUI_RELOAD_PROMPT"] = {
    text = "Settings changed. Reload UI to apply?",
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

-- ============================================================
-- HELPER: Create a dockable panel
-- ============================================================
local function CreateDockedPanel(name, width, height, headerText)
    local p = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    p:SetSize(width, height)
    p:SetBackdrop(darkBackdrop)
    p:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    p:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    p:SetFrameStrata("HIGH")
    p:Hide()
    
    local header = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOP", 0, -12)
    header:SetText(headerText)
    header:SetTextColor(1, 0.82, 0)  -- Gold color
    p.header = header
    
    local closeBtn = CreateFrame("Button", nil, p, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() p:Hide() end)
    
    table.insert(allPanels, p)
    return p
end

-- ============================================================
-- HELPER: Position panel next to hub
-- ============================================================
local function PositionPanelNextToHub(targetPanel)
    if not hubPanel then return end
    targetPanel:ClearAllPoints()
    targetPanel:SetPoint("TOPLEFT", hubPanel, "TOPRIGHT", 0, 0)
end

-- ============================================================
-- HELPER: Hide all docked panels
-- ============================================================
local function HideAllPanels()
    for _, p in ipairs(allPanels) do
        p:Hide()
    end
end

-- ============================================================
-- HELPER: Open a panel (hide others, dock to hub)
-- ============================================================
local function OpenPanel(targetPanel)
    HideAllPanels()
    PositionPanelNextToHub(targetPanel)
    targetPanel:Show()
end

-- ============================================================
-- Create a module row (checkbox + settings button)
-- ============================================================
local function CreateModuleRow(parent, moduleId, moduleName, yOffset, onSettingsClick)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", 20, yOffset)
    row:SetPoint("TOPRIGHT", -20, yOffset)
    row:SetHeight(BUTTON_HEIGHT)
    
    -- Checkbox to enable/disable module (make it smaller and contained)
    local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    cb:SetPoint("LEFT", 0, 0)
    cb:SetSize(24, 24)
    cb:SetChecked(TweaksUI.Database:IsModuleEnabled(moduleId))
    cb:SetHitRectInsets(0, 0, 0, 0)  -- Keep hit rect exactly on the checkbox
    row.checkbox = cb
    
    -- Settings button - opens the module's settings panel
    local btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    btn:SetPoint("LEFT", cb, "RIGHT", 8, 0)
    btn:SetPoint("RIGHT", -5, 0)
    btn:SetHeight(BUTTON_HEIGHT)
    btn:SetText(moduleName)
    row.button = btn
    
    -- Function to update button state based on module enabled status
    local function UpdateButtonState()
        local enabled = TweaksUI.Database:IsModuleEnabled(moduleId)
        cb:SetChecked(enabled)
        btn:SetEnabled(enabled)
        if enabled then
            btn:SetAlpha(1)
        else
            btn:SetAlpha(0.5)
        end
    end
    
    -- Checkbox toggles module enable/disable
    cb:SetScript("OnClick", function(self)
        local wantEnabled = self:GetChecked()
        
        if TweaksUI.MODULES_REQUIRE_RELOAD and TweaksUI.MODULES_REQUIRE_RELOAD[moduleId] then
            -- Save the setting immediately but skip events (don't trigger anything until reload)
            TweaksUI.Database:SetModuleEnabled(moduleId, wantEnabled, true)  -- skipEvents = true
            UpdateButtonState()
            
            -- Only show popup if one isn't already showing
            if not StaticPopup_Visible("TWEAKSUI_RELOAD_MODULE") then
                StaticPopupDialogs["TWEAKSUI_RELOAD_MODULE"] = {
                    text = "Module changes require a UI reload to take effect.\n\nReload now or continue making changes?",
                    button1 = "Reload Now",
                    button2 = "Later",
                    OnAccept = function()
                        ReloadUI()
                    end,
                    OnCancel = function()
                        -- Just close, settings are already saved
                    end,
                    timeout = 0,
                    whileDead = true,
                    hideOnEscape = true,
                    preferredIndex = 3,
                }
                StaticPopup_Show("TWEAKSUI_RELOAD_MODULE")
            end
        else
            -- Module doesn't require reload, just toggle normally
            TweaksUI.Database:SetModuleEnabled(moduleId, wantEnabled)
            if wantEnabled then
                TweaksUI.ModuleManager:EnableModule(moduleId)
            else
                TweaksUI.ModuleManager:DisableModule(moduleId)
            end
            UpdateButtonState()
        end
    end)
    
    -- Button opens settings (only if module is enabled)
    btn:SetScript("OnClick", function(self)
        if TweaksUI.Database:IsModuleEnabled(moduleId) and onSettingsClick then
            onSettingsClick()
        end
    end)
    
    UpdateButtonState()
    
    row.UpdateButtonState = UpdateButtonState
    return row
end

-- ============================================================
-- CREATE THE HUB PANEL
-- ============================================================
function Settings:CreatePanel()
    if hubPanel then return hubPanel end
    
    -- Main hub panel
    hubPanel = CreateFrame("Frame", "TweaksUI_HubPanel", UIParent, "BackdropTemplate")
    hubPanel:SetSize(HUB_WIDTH, HUB_HEIGHT)
    
    -- Restore saved position or use default
    if TweaksUI_DB and TweaksUI_DB.hubPosition then
        hubPanel:SetPoint(
            TweaksUI_DB.hubPosition.point, 
            UIParent, 
            TweaksUI_DB.hubPosition.relPoint, 
            TweaksUI_DB.hubPosition.x, 
            TweaksUI_DB.hubPosition.y
        )
    else
        hubPanel:SetPoint("CENTER", -400, 0)
    end
    
    hubPanel:SetBackdrop(darkBackdrop)
    hubPanel:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    hubPanel:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    hubPanel:SetMovable(true)
    hubPanel:EnableMouse(true)
    hubPanel:RegisterForDrag("LeftButton")
    hubPanel:SetScript("OnDragStart", function(self) self:StartMoving() end)
    hubPanel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        TweaksUI_DB = TweaksUI_DB or {}
        TweaksUI_DB.hubPosition = { point = point, relPoint = relPoint, x = x, y = y }
    end)
    hubPanel:Hide()
    hubPanel:SetFrameStrata("HIGH")
    
    tinsert(UISpecialFrames, "TweaksUI_HubPanel")
    
    -- Close all module panels when hub is hidden (including via Escape key)
    hubPanel:SetScript("OnHide", function()
        Settings:CloseAllModules()
    end)
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, hubPanel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function()
        HideAllPanels()
        hubPanel:Hide()
    end)
    
    -- Title
    local title = hubPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("TweaksUI")
    title:SetTextColor(0, 1, 0.5)  -- Teal/green for TweaksUI branding
    
    local ver = hubPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ver:SetPoint("TOP", title, "BOTTOM", 0, -2)
    ver:SetText("v" .. (TweaksUI.VERSION or "0.0.1"))
    ver:SetTextColor(0.6, 0.6, 0.6)
    
    -- Section: Modules
    local modulesHeader = hubPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    modulesHeader:SetPoint("TOPLEFT", 15, -50)
    modulesHeader:SetText("Modules")
    modulesHeader:SetTextColor(1, 0.82, 0)
    
    -- Divider line
    local divider = hubPanel:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", modulesHeader, "BOTTOMLEFT", 0, -4)
    divider:SetPoint("TOPRIGHT", hubPanel, "TOPRIGHT", -15, 0)
    divider:SetColorTexture(0.4, 0.4, 0.4, 0.8)
    
    -- Create module rows
    local yOffset = -75
    local moduleRows = {}
    
    for _, moduleId in ipairs(TweaksUI.MODULE_LOAD_ORDER) do
        local moduleName = TweaksUI.MODULE_NAMES[moduleId]
        if moduleName then
            local row = CreateModuleRow(hubPanel, moduleId, moduleName, yOffset, function()
                self:OpenModuleSettings(moduleId)
            end)
            moduleRows[moduleId] = row
            yOffset = yOffset - (BUTTON_HEIGHT + BUTTON_SPACING)
        end
    end
    
    hubPanel.moduleRows = moduleRows
    
    -- Section: General
    local generalHeader = hubPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    generalHeader:SetPoint("TOPLEFT", 15, yOffset - SECTION_SPACING)
    generalHeader:SetText("General")
    generalHeader:SetTextColor(1, 0.82, 0)
    
    local divider2 = hubPanel:CreateTexture(nil, "ARTWORK")
    divider2:SetHeight(1)
    divider2:SetPoint("TOPLEFT", generalHeader, "BOTTOMLEFT", 0, -4)
    divider2:SetPoint("TOPRIGHT", hubPanel, "TOPRIGHT", -15, 0)
    divider2:SetColorTexture(0.4, 0.4, 0.4, 0.8)
    
    yOffset = yOffset - SECTION_SPACING - 30
    
    -- General Settings button (UI visibility, AFK mode, etc.)
    local generalSettingsBtn = CreateFrame("Button", nil, hubPanel, "UIPanelButtonTemplate")
    generalSettingsBtn:SetPoint("TOPLEFT", 20, yOffset)
    generalSettingsBtn:SetPoint("TOPRIGHT", -20, yOffset)
    generalSettingsBtn:SetHeight(BUTTON_HEIGHT)
    generalSettingsBtn:SetText("Settings")
    generalSettingsBtn:SetScript("OnClick", function()
        -- Close any open module hubs first
        self:CloseAllModules()
        if TweaksUI.General then
            TweaksUI.General:ShowSettingsPanel(hubPanel)
        end
    end)
    
    yOffset = yOffset - (BUTTON_HEIGHT + BUTTON_SPACING)
    
    -- Profiles button (actual profile management)
    local profilesBtn = CreateFrame("Button", nil, hubPanel, "UIPanelButtonTemplate")
    profilesBtn:SetPoint("TOPLEFT", 20, yOffset)
    profilesBtn:SetPoint("TOPRIGHT", -20, yOffset)
    profilesBtn:SetHeight(BUTTON_HEIGHT)
    profilesBtn:SetText("Profiles")
    profilesBtn:SetScript("OnClick", function()
        -- Close any open module hubs first
        self:CloseAllModules()
        self:OpenProfilesPanel()
    end)
    
    yOffset = yOffset - (BUTTON_HEIGHT + BUTTON_SPACING)
    
    -- About button
    local aboutBtn = CreateFrame("Button", nil, hubPanel, "UIPanelButtonTemplate")
    aboutBtn:SetPoint("TOPLEFT", 20, yOffset)
    aboutBtn:SetPoint("TOPRIGHT", -20, yOffset)
    aboutBtn:SetHeight(BUTTON_HEIGHT)
    aboutBtn:SetText("About")
    aboutBtn:SetScript("OnClick", function()
        -- Close any open module hubs first
        self:CloseAllModules()
        self:OpenAboutPanel()
    end)
    
    yOffset = yOffset - (BUTTON_HEIGHT + BUTTON_SPACING)
    
    -- Patch Notes button
    local patchNotesBtn = CreateFrame("Button", nil, hubPanel, "UIPanelButtonTemplate")
    patchNotesBtn:SetPoint("TOPLEFT", 20, yOffset)
    patchNotesBtn:SetPoint("TOPRIGHT", -20, yOffset)
    patchNotesBtn:SetHeight(BUTTON_HEIGHT)
    patchNotesBtn:SetText("Patch Notes")
    patchNotesBtn:SetScript("OnClick", function()
        TweaksUI:ShowPatchNotes(true)
    end)
    
    yOffset = yOffset - (BUTTON_HEIGHT + BUTTON_SPACING)
    
    -- Layout button (opens Layout mode for positioning UI elements)
    local layoutBtn = CreateFrame("Button", nil, hubPanel, "UIPanelButtonTemplate")
    layoutBtn:SetPoint("TOPLEFT", 20, yOffset)
    layoutBtn:SetPoint("TOPRIGHT", -20, yOffset)
    layoutBtn:SetHeight(BUTTON_HEIGHT)
    layoutBtn:SetText("Layout Mode")
    layoutBtn:SetScript("OnClick", function()
        -- Close the hub and enter Layout mode
        hubPanel:Hide()
        if TweaksUI.Layout then
            TweaksUI.Layout:Enter()
        else
            TweaksUI:PrintError("Layout module not available")
        end
    end)
    
    -- Adjust hub height based on content
    local totalHeight = math.abs(yOffset) + 50
    hubPanel:SetHeight(math.max(HUB_HEIGHT, totalHeight))
    
    -- Register with GlobalScale for settings scaling
    if TweaksUI.GlobalScale then
        TweaksUI.GlobalScale:RegisterSettingsPanel(hubPanel, 1.0)
    end
    
    return hubPanel
end

-- ============================================================
-- OPEN MODULE SETTINGS
-- ============================================================
function Settings:OpenModuleSettings(moduleId)
    -- First, close ALL module hubs and panels
    self:CloseAllModules()
    
    -- Now open the requested module
    if moduleId == TweaksUI.MODULE_IDS.COOLDOWNS then
        local cooldownsModule = TweaksUI.ModuleManager:GetModule(TweaksUI.MODULE_IDS.COOLDOWNS)
        if cooldownsModule and cooldownsModule.ShowHub then
            cooldownsModule:ShowHub(hubPanel)
        end
    elseif moduleId == TweaksUI.MODULE_IDS.CHAT then
        local chatModule = TweaksUI.ModuleManager:GetModule(TweaksUI.MODULE_IDS.CHAT)
        if chatModule and chatModule.OpenChatHubDocked then
            chatModule:OpenChatHubDocked(hubPanel)
        end
    elseif moduleId == TweaksUI.MODULE_IDS.UNIT_FRAMES then
        local unitFramesModule = TweaksUI.ModuleManager:GetModule(TweaksUI.MODULE_IDS.UNIT_FRAMES)
        if unitFramesModule and unitFramesModule.OpenUnitFramesHubDocked then
            unitFramesModule:OpenUnitFramesHubDocked(hubPanel)
        end
    elseif moduleId == TweaksUI.MODULE_IDS.CAST_BARS then
        local castBarsModule = TweaksUI.ModuleManager:GetModule(TweaksUI.MODULE_IDS.CAST_BARS)
        if castBarsModule and castBarsModule.ShowHub then
            castBarsModule:ShowHub(hubPanel)
        end
    elseif moduleId == TweaksUI.MODULE_IDS.NAMEPLATES then
        local nameplatesModule = TweaksUI.ModuleManager:GetModule(TweaksUI.MODULE_IDS.NAMEPLATES)
        if nameplatesModule and nameplatesModule.ShowHub then
            nameplatesModule:ShowHub(hubPanel)
        end
    elseif moduleId == TweaksUI.MODULE_IDS.PERSONAL_RESOURCES then
        local personalResourcesModule = TweaksUI.ModuleManager:GetModule(TweaksUI.MODULE_IDS.PERSONAL_RESOURCES)
        if personalResourcesModule and personalResourcesModule.ShowHub then
            personalResourcesModule:ShowHub(hubPanel)
        end
    elseif moduleId == TweaksUI.MODULE_IDS.ACTION_BARS then
        local actionBarsModule = TweaksUI.ModuleManager:GetModule(TweaksUI.MODULE_IDS.ACTION_BARS)
        if actionBarsModule and actionBarsModule.ShowHub then
            actionBarsModule:ShowHub(hubPanel)
        end
    else
        self:OpenComingSoonPanel(moduleId)
    end
end

-- Close all modules' hubs and panels
function Settings:CloseAllModules()
    -- Close any docked panels from Settings
    HideAllPanels()
    
    -- List of all modules that have hubs/panels
    local moduleHubNames = {
        "TweaksUI_ChatHub",
        "TweaksUI_Cooldowns_Hub",
        "TweaksUI_UnitFramesHub",
        "TweaksUI_CastBars_Hub",
        "TweaksUI_Nameplates_Hub",
        "TweaksUI_PersonalResources_Hub",
        "TweaksUI_ActionBars_Hub",
        "TweaksUI_General_Hub",
        -- General module panels
        "TweaksUI_General_Settings",
        "TweaksUI_General_MediaPanel",
        "TweaksUI_Minimap_Panel",
        -- Unit Frames settings containers
        "TweaksUI_UF_player_Container",
        "TweaksUI_UF_target_Container",
        "TweaksUI_UF_focus_Container",
        "TweaksUI_UF_targettarget_Container",
        "TweaksUI_UF_pet_Container",
        "TweaksUI_UF_party_Container",
        "TweaksUI_UF_raid_small_Container",
        "TweaksUI_UF_raid_large_Container",
        "TweaksUI_UF_tanks_Container",
        "TweaksUI_UF_boss_Container",
    }
    
    -- Hide all hub frames
    for _, hubName in ipairs(moduleHubNames) do
        local hub = _G[hubName]
        if hub then
            hub:Hide()
        end
    end
    
    -- Call HideAllPanels on each module
    local moduleIds = {
        TweaksUI.MODULE_IDS.CHAT,
        TweaksUI.MODULE_IDS.COOLDOWNS,
        TweaksUI.MODULE_IDS.UNIT_FRAMES,
        TweaksUI.MODULE_IDS.CAST_BARS,
        TweaksUI.MODULE_IDS.NAMEPLATES,
        TweaksUI.MODULE_IDS.PERSONAL_RESOURCES,
        TweaksUI.MODULE_IDS.ACTION_BARS,
    }
    
    for _, modId in ipairs(moduleIds) do
        local mod = TweaksUI.ModuleManager:GetModule(modId)
        if mod and mod.HideAllPanels then
            mod:HideAllPanels()
        end
    end
    
    -- General module is not registered with ModuleManager, call directly
    if TweaksUI.General and TweaksUI.General.HideAllPanels then
        TweaksUI.General:HideAllPanels()
    end
end

-- ============================================================
-- CREATE CHAT SETTINGS PANEL
-- ============================================================
function Settings:OpenChatPanel()
    if not moduleSettingsPanels.chat then
        local panel = CreateDockedPanel("TweaksUI_ChatPanel", PANEL_WIDTH, 500, "Chat Settings")
        
        local content = CreateFrame("Frame", nil, panel)
        content:SetPoint("TOPLEFT", 15, -40)
        content:SetPoint("BOTTOMRIGHT", -15, 15)
        
        local yOffset = 0
        
        -- Add Preset Dropdown at the top
        if TweaksUI.PresetDropdown then
            local presetContainer, nextY = TweaksUI.PresetDropdown:Create(
                content,
                "chat",
                "Chat",
                yOffset,
                {
                    width = 160,
                    showSaveButton = true,
                    showDeleteButton = true,
                }
            )
            yOffset = nextY - 10
        end
        
        -- Module content container (offset by preset dropdown)
        local moduleContent = CreateFrame("Frame", nil, content)
        moduleContent:SetPoint("TOPLEFT", 0, yOffset)
        moduleContent:SetPoint("BOTTOMRIGHT", 0, 0)
        
        -- Get the Chat module and let it create the settings content
        local chatModule = TweaksUI.ModuleManager:GetModule(TweaksUI.MODULE_IDS.CHAT)
        if chatModule and chatModule.CreateSettingsContent then
            chatModule:CreateSettingsContent(moduleContent)
        else
            -- Fallback if module not loaded
            local desc = moduleContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            desc:SetPoint("TOPLEFT", 0, 0)
            desc:SetWidth(PANEL_WIDTH - 50)
            desc:SetText("Chat module settings.\n\nEnable the Chat module to configure settings.")
            desc:SetTextColor(0.8, 0.8, 0.8)
            desc:SetJustifyH("LEFT")
        end
        
        moduleSettingsPanels.chat = panel
    end
    
    OpenPanel(moduleSettingsPanels.chat)
end

-- ============================================================
-- CREATE PROFILES PANEL (1.5.0: Opens ProfilesUI panel)
-- ============================================================

function Settings:OpenProfilesPanel()
    -- Use new ProfilesUI system (1.5.0+)
    if TweaksUI.ProfilesUI then
        TweaksUI.ProfilesUI:ShowProfilesPanel(hubPanel)
    else
        TweaksUI:PrintError("ProfilesUI not available")
    end
end

-- ============================================================
-- CREATE ABOUT PANEL
-- ============================================================
function Settings:OpenAboutPanel()
    if not moduleSettingsPanels.about then
        local panel = CreateDockedPanel("TweaksUI_AboutPanel", PANEL_WIDTH, 480, "About TweaksUI")
        
        -- Create scroll frame for content
        local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 15, -40)
        scrollFrame:SetPoint("BOTTOMRIGHT", -35, 15)
        
        local content = CreateFrame("Frame", nil, scrollFrame)
        content:SetSize(PANEL_WIDTH - 60, 500)
        scrollFrame:SetScrollChild(content)
        
        local yPos = 0
        
        -- Header info
        local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        header:SetPoint("TOPLEFT", 0, yPos)
        header:SetText("|cff00ff80TweaksUI|r v" .. (TweaksUI.VERSION or "1.5.0"))
        yPos = yPos - 25
        
        local desc = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        desc:SetPoint("TOPLEFT", 0, yPos)
        desc:SetWidth(PANEL_WIDTH - 60)
        desc:SetJustifyH("LEFT")
        desc:SetText("A modular UI enhancement suite for World of Warcraft.")
        yPos = yPos - 25
        
        local author = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        author:SetPoint("TOPLEFT", 0, yPos)
        author:SetText("|cffffffffAuthor:|r Meltheran")
        author:SetTextColor(0.7, 0.7, 0.7)
        yPos = yPos - 20
        
        local website = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        website:SetPoint("TOPLEFT", 0, yPos)
        website:SetText("|cffffffffCurseForge:|r curseforge.com/wow/addons/tweaksui")
        website:SetTextColor(0.7, 0.7, 0.7)
        yPos = yPos - 35
        
        -- Why This Addon Exists Section
        local whyTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        whyTitle:SetPoint("TOPLEFT", 0, yPos)
        whyTitle:SetText("|cff00ff80Why This Addon Exists|r")
        yPos = yPos - 22
        
        local whyText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        whyText:SetPoint("TOPLEFT", 0, yPos)
        whyText:SetWidth(PANEL_WIDTH - 60)
        whyText:SetJustifyH("LEFT")
        whyText:SetSpacing(2)
        whyText:SetText("TweaksUI started as a personal project in preparation for the upcoming Midnight API changes. At the time, several larger UI addons had announced that they would not be continuing development into Midnight, and I didn't want to rebuild my UI around tools that might not be maintained long-term.\n\nRather than wait or scramble later, I decided to build something modular that covered the parts of the UI I actually interact with day to day, while staying close to Blizzard's default frames and APIs.\n\nSome of those larger addons have since decided to continue into Midnight, which is a good thing. TweaksUI isn't meant to replace or compete with them. It exists because it fits my own setup and preferences, and I've continued developing it because other players found it useful as well.")
        whyText:SetTextColor(0.8, 0.8, 0.8)
        yPos = yPos - whyText:GetStringHeight() - 20
        
        -- Discord Section
        local discordTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        discordTitle:SetPoint("TOPLEFT", 0, yPos)
        discordTitle:SetText("|cff5865F2Join the Community!|r")
        yPos = yPos - 22
        
        local discordLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        discordLabel:SetPoint("TOPLEFT", 0, yPos)
        discordLabel:SetText("|cff5865F2Discord:|r")
        
        -- Copyable Discord link EditBox
        local discordEditBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
        discordEditBox:SetPoint("TOPLEFT", 55, yPos + 3)
        discordEditBox:SetSize(220, 20)
        discordEditBox:SetAutoFocus(false)
        discordEditBox:SetText("https://discord.gg/mYuggs3zwT")
        discordEditBox:SetCursorPosition(0)
        discordEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        discordEditBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        discordEditBox:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0) end)
        -- Prevent editing - just allow selection/copy
        discordEditBox:SetScript("OnTextChanged", function(self)
            self:SetText("https://discord.gg/mYuggs3zwT")
        end)
        yPos = yPos - 24
        
        local copyHint = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        copyHint:SetPoint("TOPLEFT", 0, yPos)
        copyHint:SetText("|cff888888(Click to select, Ctrl+C to copy)|r")
        yPos = yPos - 20
        
        local shareText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        shareText:SetPoint("TOPLEFT", 0, yPos)
        shareText:SetWidth(PANEL_WIDTH - 60)
        shareText:SetJustifyH("LEFT")
        shareText:SetText("Share your profiles and presets for a chance to have them included as built-in presets! We want your Cooldown setups, Cast Bar configs, Nameplate styles, Unit Frame layouts, and more!")
        shareText:SetTextColor(0.8, 0.8, 0.8)
        yPos = yPos - 55
        
        moduleSettingsPanels.about = panel
    end
    
    OpenPanel(moduleSettingsPanels.about)
end

-- ============================================================
-- CREATE COMING SOON PANEL
-- ============================================================
function Settings:OpenComingSoonPanel(moduleId)
    local moduleName = TweaksUI.MODULE_NAMES[moduleId] or moduleId
    local panelKey = "comingsoon_" .. moduleId
    
    if not moduleSettingsPanels[panelKey] then
        local panel = CreateDockedPanel("TweaksUI_" .. moduleId .. "Panel", PANEL_WIDTH, 300, moduleName)
        
        local content = CreateFrame("Frame", nil, panel)
        content:SetPoint("TOPLEFT", 15, -40)
        content:SetPoint("BOTTOMRIGHT", -15, 15)
        
        local msg = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        msg:SetPoint("CENTER")
        msg:SetText("|cff888888Coming Soon|r\n\n|cff666666This module is planned for a future update.|r")
        
        moduleSettingsPanels[panelKey] = panel
    end
    
    OpenPanel(moduleSettingsPanels[panelKey])
end

-- ============================================================
-- TOGGLE / SHOW / HIDE
-- ============================================================
function Settings:Toggle()
    if not hubPanel then
        self:CreatePanel()
    end
    
    if hubPanel:IsShown() then
        HideAllPanels()
        hubPanel:Hide()
    else
        hubPanel:Show()
    end
end

function Settings:Show()
    if not hubPanel then
        self:CreatePanel()
    end
    hubPanel:Show()
end

function Settings:Hide()
    if hubPanel then
        HideAllPanels()
        hubPanel:Hide()
    end
end
