-- ============================================================================
-- TweaksUI: Setup Wizard
-- 3-step new user setup: Enable CDM -> Import Edit Mode -> Choose Profile
-- ============================================================================

local ADDON_NAME, TweaksUI = ...

TweaksUI.SetupWizard = {}
local SetupWizard = TweaksUI.SetupWizard

local wizardFrame = nil
local currentStep = 1

-- ============================================================================
-- EDIT MODE IMPORT STRING
-- ============================================================================

local EDIT_MODE_IMPORT_STRING = [[2 50 0 0 1 7 7 UIParent 0.0 45.0 -1 ##$$%/&('%)#+#,$ 0 1 1 7 7 UIParent 0.0 45.0 -1 ##$$%/&('%(#,$ 0 2 1 7 7 UIParent 0.0 45.0 -1 ##$$%/&('%(#,$ 0 3 1 5 5 UIParent -5.0 -77.0 -1 #$$$%/&('%(#,$ 0 4 1 5 5 UIParent -5.0 -77.0 -1 #$$$%/&('%(#,$ 0 5 1 1 4 UIParent 0.0 0.0 -1 ##$$%/&('%(#,$ 0 6 1 1 4 UIParent 0.0 -50.0 -1 ##$$%/&('%(#,$ 0 7 1 1 4 UIParent 0.0 -100.0 -1 ##$$%/&('%(#,$ 0 10 1 7 7 UIParent 0.0 45.0 -1 ##$$&('% 0 11 1 7 7 UIParent 0.0 45.0 -1 ##$$&('%,# 0 12 1 7 7 UIParent 0.0 45.0 -1 ##$$&('% 1 -1 1 4 4 UIParent 0.0 0.0 -1 ##$#%# 2 -1 1 2 2 UIParent 0.0 0.0 -1 ##$#%( 3 0 1 8 7 UIParent -300.0 250.0 -1 $#3# 3 1 1 6 7 UIParent 300.0 250.0 -1 %#3# 3 2 1 6 7 UIParent 520.0 265.0 -1 %#&#3# 3 3 1 0 2 CompactRaidFrameManager 0.0 -7.0 -1 '$(#)#-5.)/#1$3#5#6(7-7$ 3 4 1 0 2 CompactRaidFrameManager 0.0 -5.0 -1 ,#-5.)/#0#1#2(5#6(7-7$ 3 5 1 5 5 UIParent 0.0 0.0 -1 &#*$3# 3 6 1 5 5 UIParent 0.0 0.0 -1 -5.)/#4$5#6(7-7$ 3 7 1 4 4 UIParent 0.0 0.0 -1 3# 4 -1 1 7 7 UIParent 0.0 45.0 -1 # 5 -1 1 7 7 UIParent 0.0 45.0 -1 # 6 0 1 2 2 UIParent -255.0 -10.0 -1 ##$#%#&.(()( 6 1 1 2 2 UIParent -270.0 -155.0 -1 ##$#%#'+(()(-$ 6 2 1 1 1 UIParent 0.0 -25.0 -1 ##$#%$&.(()(+#,-,$ 7 -1 1 7 7 UIParent 0.0 45.0 -1 # 8 -1 1 6 6 UIParent 35.0 50.0 -1 #'$A%$&i 9 -1 1 7 7 UIParent 0.0 45.0 -1 # 10 -1 1 0 0 UIParent 16.0 -116.0 -1 # 11 -1 1 8 8 UIParent -9.0 85.0 -1 # 12 -1 1 2 2 UIParent -110.0 -275.0 -1 #K$#%# 13 -1 1 8 8 MicroButtonAndBagsBar 0.0 0.0 -1 ##$#%)&- 14 -1 1 2 2 MicroButtonAndBagsBar 0.0 10.0 -1 ##$#%( 15 0 1 7 7 StatusTrackingBarManager 0.0 0.0 -1 # 15 1 1 7 7 StatusTrackingBarManager 0.0 17.0 -1 # 16 -1 1 5 5 UIParent 0.0 0.0 -1 #( 17 -1 1 1 1 UIParent 0.0 -100.0 -1 ## 18 -1 1 5 5 UIParent 0.0 0.0 -1 #- 19 -1 1 7 7 UIParent 0.0 0.0 -1 ## 20 0 1 7 7 UIParent 0.0 310.0 -1 ##$/%$&('%(-($)#+$,$-$ 20 1 1 7 7 UIParent 0.0 240.0 -1 ##$*%$&('%(-($)#+$,$-$ 20 2 1 7 7 UIParent 0.0 370.0 -1 ##$$%$&('((-($)#+#,$-$ 20 3 1 7 7 UIParent 420.0 430.0 -1 #$$$%#&('((-($)%*#+$,$-$.-.$ 21 -1 1 7 7 UIParent -410.0 380.0 -1 ##$# 22 0 1 8 7 UIParent -457.0 336.0 -1 #$$$%#&('((#)U*$+$,$ 22 1 1 1 1 UIParent 0.0 -40.0 -1 &('()U*#+$ 22 2 1 1 1 UIParent 0.0 -90.0 -1 &('()U*#+$ 22 3 1 1 1 UIParent 0.0 -130.0 -1 &('()U*#+$ 23 -1 1 0 0 UIParent 0.0 0.0 -1 ##$#%$&-&$'7(%)U+$,$-$.(/U]]

-- ============================================================================
-- PROFILE SELECTION
-- ============================================================================

local selectedProfile = "Basic 1440"  -- Default to built-in Basic 1440 profile

-- ============================================================================
-- UI CONSTANTS
-- ============================================================================

local WIZARD_WIDTH = 500
local WIZARD_HEIGHT = 400
local STEP_TITLES = {
    [1] = "Step 1: Enable Cooldown Manager",
    [2] = "Step 2: Import Edit Mode Layout",
    [3] = "Step 3: Choose Your Profile",
}

-- ============================================================================
-- UI HELPERS
-- ============================================================================

local function CreateDarkBackdrop()
    return {
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    }
end

-- ============================================================================
-- STEP CONTENT BUILDERS
-- ============================================================================

local function BuildStep1(container)
    -- Instructions
    local instructions = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    instructions:SetPoint("TOP", 0, -20)
    instructions:SetWidth(WIZARD_WIDTH - 60)
    instructions:SetJustifyH("CENTER")
    instructions:SetText("TweaksUI enhances Blizzard's Cooldown Manager.\nFirst, make sure it's enabled in your game settings.")
    
    -- How to enable
    local howTo = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    howTo:SetPoint("TOP", instructions, "BOTTOM", 0, -25)
    howTo:SetWidth(WIZARD_WIDTH - 60)
    howTo:SetJustifyH("LEFT")
    howTo:SetText(
        "|cffffd100To enable:|r\n\n" ..
        "1. Press |cff00ff00ESC|r > |cff00ff00Options|r > |cff00ff00Gameplay Enhancements|r\n\n" ..
        "2. Find |cff00ff00\"Cooldown Manager\"|r section\n\n" ..
        "3. Check |cff00ff00\"Enable Cooldown Manager\"|r\n\n" ..
        "4. Close the settings window"
    )
    
    -- Open Settings button
    local openBtn = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
    openBtn:SetSize(160, 28)
    openBtn:SetPoint("BOTTOM", 0, 40)
    openBtn:SetText("Open Settings")
    openBtn:SetScript("OnClick", function()
        C_Timer.After(0.1, function()
            if SettingsPanel and SettingsPanel.Open then
                SettingsPanel:Open()
            elseif SettingsPanel and SettingsPanel.Show then
                SettingsPanel:Show()
            elseif GameMenuButtonOptions then
                GameMenuButtonOptions:Click()
            end
            C_Timer.After(0.1, function()
                if wizardFrame then
                    wizardFrame:Show()
                end
            end)
        end)
    end)
end

local function BuildStep2(container)
    -- Instructions
    local instructions = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    instructions:SetPoint("TOP", 0, -10)
    instructions:SetWidth(WIZARD_WIDTH - 60)
    instructions:SetJustifyH("CENTER")
    instructions:SetText("Import TweaksUI's Edit Mode layout for optimal positioning.\nThis configures Blizzard's UI elements to work well with TUI.")
    
    -- Import string label
    local stringLabel = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    stringLabel:SetPoint("TOP", instructions, "BOTTOM", 0, -12)
    stringLabel:SetText("|cffffd100Copy this string:|r")
    
    -- Editbox for import string (copyable)
    local editBoxBg = CreateFrame("Frame", nil, container, "BackdropTemplate")
    editBoxBg:SetSize(WIZARD_WIDTH - 80, 60)
    editBoxBg:SetPoint("TOP", stringLabel, "BOTTOM", 0, -6)
    editBoxBg:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    editBoxBg:SetBackdropColor(0, 0, 0, 0.8)
    editBoxBg:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    
    local scrollFrame = CreateFrame("ScrollFrame", nil, editBoxBg, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)
    
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject("GameFontHighlightSmall")
    editBox:SetWidth(WIZARD_WIDTH - 120)
    editBox:SetAutoFocus(false)
    editBox:SetText(EDIT_MODE_IMPORT_STRING)
    editBox:SetCursorPosition(0)
    scrollFrame:SetScrollChild(editBox)
    
    editBox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)
    
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    
    -- Buttons row
    local selectBtn = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
    selectBtn:SetSize(100, 24)
    selectBtn:SetPoint("TOP", editBoxBg, "BOTTOM", -60, -6)
    selectBtn:SetText("Select All")
    selectBtn:SetScript("OnClick", function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)
    
    local emBtn = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
    emBtn:SetSize(140, 24)
    emBtn:SetPoint("LEFT", selectBtn, "RIGHT", 10, 0)
    emBtn:SetText("Edit Mode Info")
    emBtn:SetScript("OnClick", function()
        -- In Midnight, programmatically showing Edit Mode causes taint
        -- Just provide instructions instead
        print("|cff00ff00TweaksUI:|r To open Edit Mode:")
        print("  |cffffd100Option 1:|r Press |cff00ccffESC|r > Click |cff00ccffEdit Mode|r")
        print("  |cffffd100Option 2:|r Set a keybind in |cff00ccffOptions > Keybindings|r")
    end)
    emBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Edit Mode", 1, 1, 1)
        GameTooltip:AddLine("Press ESC and click 'Edit Mode' to open.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("(Direct access causes taint in Midnight)", 0.5, 0.5, 0.5, true)
        GameTooltip:Show()
    end)
    emBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    -- How to import
    local howTo = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    howTo:SetPoint("TOP", selectBtn, "BOTTOM", 60, -10)
    howTo:SetWidth(WIZARD_WIDTH - 50)
    howTo:SetJustifyH("CENTER")
    howTo:SetTextColor(0.8, 0.8, 0.8)
    howTo:SetText("|cffffd100To import:|r  Click |cff00ff00Layouts|r dropdown > |cff00ff00Import|r > Paste > |cff00ff00Accept|r")
    
    -- Save instruction
    local saveNote = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    saveNote:SetPoint("TOP", howTo, "BOTTOM", 0, -8)
    saveNote:SetWidth(WIZARD_WIDTH - 50)
    saveNote:SetJustifyH("CENTER")
    saveNote:SetTextColor(1, 0.82, 0)
    saveNote:SetText("|cffffd100Important:|r Save your layout as |cff00ff00\"TUI\"|r so you can reuse it!")
    
    -- Already done hint
    local hint = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("BOTTOM", 0, 15)
    hint:SetWidth(WIZARD_WIDTH - 50)
    hint:SetTextColor(0.5, 0.5, 0.5)
    hint:SetText("Already imported on another character? Just select the |cff00ff00TUI|r layout from the dropdown.")
end

local function BuildStep3(container)
    -- Instructions
    local instructions = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    instructions:SetPoint("TOP", 0, -20)
    instructions:SetWidth(WIZARD_WIDTH - 60)
    instructions:SetJustifyH("CENTER")
    instructions:SetText("Choose a TweaksUI profile to start with.\nYou can customize everything later via |cff00ff00/tui|r.")
    
    -- Profile selection label
    local profileLabel = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    profileLabel:SetPoint("TOP", instructions, "BOTTOM", 0, -30)
    profileLabel:SetText("|cffffd100Select Profile:|r")
    
    -- Dropdown for profiles
    local dropdownFrame = CreateFrame("Frame", "TweaksUI_SetupWizard_ProfileDropdown", container, "UIDropDownMenuTemplate")
    dropdownFrame:SetPoint("TOP", profileLabel, "BOTTOM", 0, -5)
    UIDropDownMenu_SetWidth(dropdownFrame, 280)
    UIDropDownMenu_SetText(dropdownFrame, "Basic 1440 (Built-in)")
    
    UIDropDownMenu_Initialize(dropdownFrame, function(self, level)
        -- Get all built-in profiles from DefaultProfiles
        local builtInProfiles = {}
        if TweaksUI.DefaultProfiles then
            builtInProfiles = TweaksUI.DefaultProfiles:GetProfileList() or {}
        end
        
        -- Add built-in profiles first
        if #builtInProfiles > 0 then
            for _, profile in ipairs(builtInProfiles) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = profile.name .. " (Built-in)"
                info.value = profile.name
                info.checked = (selectedProfile == profile.name)
                info.func = function()
                    selectedProfile = profile.name
                    UIDropDownMenu_SetText(dropdownFrame, profile.name .. " (Built-in)")
                end
                UIDropDownMenu_AddButton(info, level)
            end
        else
            -- Fallback if DefaultProfiles not loaded yet
            local basicInfo = UIDropDownMenu_CreateInfo()
            basicInfo.text = "Basic 1440 (Built-in)"
            basicInfo.value = "Basic 1440"
            basicInfo.checked = (selectedProfile == "Basic 1440")
            basicInfo.func = function()
                selectedProfile = "Basic 1440"
                UIDropDownMenu_SetText(dropdownFrame, "Basic 1440 (Built-in)")
            end
            UIDropDownMenu_AddButton(basicInfo, level)
        end
        
        -- Separator if we have user profiles
        local userProfileNames = {}
        if TweaksUI_DB and TweaksUI_DB.profiles then
            for profileName, _ in pairs(TweaksUI_DB.profiles) do
                table.insert(userProfileNames, profileName)
            end
            table.sort(userProfileNames)
        end
        
        if #userProfileNames > 0 then
            -- Add separator
            local sepInfo = UIDropDownMenu_CreateInfo()
            sepInfo.text = ""
            sepInfo.disabled = true
            sepInfo.notCheckable = true
            UIDropDownMenu_AddButton(sepInfo, level)
            
            -- Header for saved profiles
            local headerInfo = UIDropDownMenu_CreateInfo()
            headerInfo.text = "|cff888888-- Saved Profiles --|r"
            headerInfo.disabled = true
            headerInfo.notCheckable = true
            UIDropDownMenu_AddButton(headerInfo, level)
            
            -- User profiles
            for _, profileName in ipairs(userProfileNames) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = profileName
                info.value = profileName
                info.checked = (selectedProfile == profileName)
                info.func = function()
                    selectedProfile = profileName
                    UIDropDownMenu_SetText(dropdownFrame, profileName)
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end
    end)
    
    -- Description of what happens
    local desc = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    desc:SetPoint("TOP", dropdownFrame, "BOTTOM", 0, -20)
    desc:SetWidth(WIZARD_WIDTH - 60)
    desc:SetJustifyH("CENTER")
    desc:SetTextColor(0.7, 0.7, 0.7)
    desc:SetText("Built-in profiles are optimized for different screen resolutions.\nSaved profiles from other characters appear in the dropdown.")
    
    -- Don't show again checkbox
    local dontShowCheck = CreateFrame("CheckButton", nil, container, "InterfaceOptionsCheckButtonTemplate")
    dontShowCheck:SetPoint("BOTTOM", 0, 50)
    dontShowCheck.Text:SetText("Don't show this wizard again")
    dontShowCheck.Text:SetTextColor(0.7, 0.7, 0.7)
    dontShowCheck:SetChecked(TweaksUI_DB and TweaksUI_DB.dontShowSetupWizard or false)
    dontShowCheck:SetScript("OnClick", function(self)
        if TweaksUI_DB then
            TweaksUI_DB.dontShowSetupWizard = self:GetChecked()
        end
    end)
    
    -- Note about reload
    local reloadNote = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    reloadNote:SetPoint("BOTTOM", 0, 20)
    reloadNote:SetTextColor(0.6, 0.6, 0.6)
    reloadNote:SetText("|cff00ff00Finish|r will apply the selected profile and reload your UI")
end

-- ============================================================================
-- STEP DISPLAY
-- ============================================================================

local stepContainers = {}

local function CreateWizardFrame()
    if wizardFrame then return wizardFrame end
    
    local f = CreateFrame("Frame", "TweaksUI_SetupWizard", UIParent, "BackdropTemplate")
    f:SetSize(WIZARD_WIDTH, WIZARD_HEIGHT)
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 50, -100)
    f:SetBackdrop(CreateDarkBackdrop())
    f:SetBackdropColor(0.08, 0.08, 0.08, 0.98)
    f:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(100)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    
    -- Don't register with UISpecialFrames - we don't want ESC or other panels to close us
    
    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("|cffffd100TweaksUI Setup|r")
    
    -- Step indicator
    local stepText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    stepText:SetPoint("TOP", title, "BOTTOM", 0, -8)
    f.stepText = stepText
    
    -- Divider line
    local divider = f:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", 20, -58)
    divider:SetPoint("TOPRIGHT", -20, -58)
    divider:SetColorTexture(0.4, 0.4, 0.4, 0.8)
    
    -- Content container
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", 20, -65)
    content:SetPoint("BOTTOMRIGHT", -20, 50)
    f.content = content
    
    -- Close button (X)
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function()
        f:Hide()
    end)
    
    -- Navigation buttons at bottom
    local backBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    backBtn:SetSize(80, 24)
    backBtn:SetPoint("BOTTOMLEFT", 20, 15)
    backBtn:SetText("< Back")
    backBtn:SetScript("OnClick", function()
        if currentStep > 1 then
            SetupWizard:ShowStep(currentStep - 1)
        end
    end)
    f.backBtn = backBtn
    
    local skipBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    skipBtn:SetSize(80, 24)
    skipBtn:SetPoint("BOTTOM", 0, 15)
    skipBtn:SetText("Skip")
    skipBtn:SetScript("OnClick", function()
        SetupWizard:Skip()
    end)
    f.skipBtn = skipBtn
    
    local nextBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    nextBtn:SetSize(80, 24)
    nextBtn:SetPoint("BOTTOMRIGHT", -20, 15)
    nextBtn:SetText("Next >")
    nextBtn:SetScript("OnClick", function()
        if currentStep < 3 then
            SetupWizard:ShowStep(currentStep + 1)
        else
            SetupWizard:Finish()
        end
    end)
    f.nextBtn = nextBtn
    
    wizardFrame = f
    return f
end

function SetupWizard:ShowStep(step)
    currentStep = step
    
    local f = CreateWizardFrame()
    
    -- Update step text
    f.stepText:SetText(STEP_TITLES[step] or ("Step " .. step))
    
    -- Hide all step containers
    for _, container in pairs(stepContainers) do
        container:Hide()
    end
    
    -- Create or show the container for this step
    if not stepContainers[step] then
        local container = CreateFrame("Frame", nil, f.content)
        container:SetAllPoints()
        
        if step == 1 then
            BuildStep1(container)
        elseif step == 2 then
            BuildStep2(container)
        elseif step == 3 then
            BuildStep3(container)
        end
        
        stepContainers[step] = container
    end
    
    stepContainers[step]:Show()
    
    -- Update navigation buttons
    f.backBtn:SetShown(step > 1)
    
    if step == 3 then
        f.nextBtn:SetText("Finish")
    else
        f.nextBtn:SetText("Next >")
    end
    
    f:Show()
end

-- ============================================================================
-- FINISH / SKIP
-- ============================================================================

function SetupWizard:Finish()
    -- Mark setup as complete
    if TweaksUI_DB then
        TweaksUI_DB.setupComplete = true
        TweaksUI_DB.setupVersion = 2
    end
    
    -- Mark profile as loaded for this character
    if TweaksUI_CharDB then
        TweaksUI_CharDB.profileLoaded = selectedProfile
    end
    
    -- Store selected profile to load after reload
    if TweaksUI_DB then
        TweaksUI_DB.pendingProfile = selectedProfile
    end
    
    -- Hide wizard
    if wizardFrame then
        wizardFrame:Hide()
    end
    
    -- Fire event for other modules
    if TweaksUI.Events and TweaksUI.Events.Fire then
        TweaksUI.Events:Fire("TWEAKSUI_SETUP_COMPLETE")
    end
    
    -- Show reload dialog (can't call ReloadUI directly from addon code)
    SetupWizard:ShowReloadDialog()
end

function SetupWizard:ShowReloadDialog()
    -- Create simple reload dialog
    local dialog = CreateFrame("Frame", "TweaksUI_ReloadDialog", UIParent, "BackdropTemplate")
    dialog:SetSize(300, 120)
    dialog:SetPoint("CENTER")
    dialog:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    dialog:SetBackdropColor(0.08, 0.08, 0.08, 0.98)
    dialog:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    dialog:SetFrameStrata("DIALOG")
    dialog:SetFrameLevel(200)
    
    -- Title
    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("|cffffd100TweaksUI Setup Complete|r")
    
    -- Message
    local msg = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    msg:SetPoint("TOP", title, "BOTTOM", 0, -10)
    msg:SetWidth(260)
    msg:SetText("Profile '" .. selectedProfile .. "' will be applied.\nClick below to reload your UI.")
    
    -- Reload button
    local reloadBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    reloadBtn:SetSize(120, 28)
    reloadBtn:SetPoint("BOTTOM", 0, 15)
    reloadBtn:SetText("Reload Now")
    reloadBtn:SetScript("OnClick", function()
        ReloadUI()
    end)
    
    dialog:Show()
end

function SetupWizard:ShowSkipWarning()
    -- Create warning dialog
    local warning = CreateFrame("Frame", "TweaksUI_SkipWarning", UIParent, "BackdropTemplate")
    warning:SetSize(500, 480)
    warning:SetPoint("CENTER")
    warning:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    warning:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    warning:SetFrameStrata("DIALOG")
    warning:SetFrameLevel(200)
    
    -- Title
    local title = warning:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("|cffff6600Important Setup Warning|r")
    
    -- Warning text
    local text = warning:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOP", title, "BOTTOM", 0, -15)
    text:SetWidth(460)
    text:SetJustifyH("LEFT")
    text:SetSpacing(3)
    text:SetText(
        "|cffffffffTweaksUI requires specific Blizzard settings to function correctly.|r\n\n" ..
        "|cffff8888Without proper configuration, features may not work or will display incorrectly.|r\n\n" ..
        "|cffffd100Required Settings:|r"
    )
    
    -- Requirements list
    local requirements = warning:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    requirements:SetPoint("TOP", text, "BOTTOM", 0, -10)
    requirements:SetWidth(440)
    requirements:SetJustifyH("LEFT")
    requirements:SetSpacing(4)
    requirements:SetText(
        "|cff00ff00>|r |cffffffffCooldown Manager|r must be |cff00ff00enabled|r\n" ..
        "    |cff888888(ESC > Options > Gameplay Enhancements)|r\n\n" ..
        "|cff00ff00>|r In |cffffffffEdit Mode|r, set visibility for:\n" ..
        "    - Essential Cooldowns: |cff00ff00Always|r\n" ..
        "    - Utility Cooldowns: |cff00ff00Always|r\n" ..
        "    - Buffs: |cff00ff00Always|r\n\n" ..
        "|cff00ff00>|r Buff Tracker: |cffff8888Uncheck|r \"Hide When Inactive\"\n\n" ..
        "|cff00ff00>|r If using TUI Party Frames:\n" ..
        "    - Check |cff00ff00\"Use Raid-Style Party Frames\"|r in Edit Mode"
    )
    
    -- Recommendation
    local recommend = warning:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    recommend:SetPoint("BOTTOM", 0, 80)
    recommend:SetWidth(420)
    recommend:SetJustifyH("CENTER")
    recommend:SetTextColor(0.7, 0.7, 0.7)
    recommend:SetText("We strongly recommend completing the Setup Wizard.\nIt will configure these settings automatically.")
    
    -- Back to Wizard button (emphasized)
    local backBtn = CreateFrame("Button", nil, warning, "UIPanelButtonTemplate")
    backBtn:SetSize(160, 28)
    backBtn:SetPoint("BOTTOMLEFT", 50, 30)
    backBtn:SetText("< Back to Wizard")
    backBtn:SetScript("OnClick", function()
        warning:Hide()
        -- Show wizard again if hidden
        if wizardFrame then
            wizardFrame:Show()
        end
    end)
    
    -- Skip Anyway button (de-emphasized)
    local skipBtn = CreateFrame("Button", nil, warning, "UIPanelButtonTemplate")
    skipBtn:SetSize(140, 28)
    skipBtn:SetPoint("BOTTOMRIGHT", -50, 30)
    skipBtn:SetText("Skip Anyway")
    skipBtn:GetFontString():SetTextColor(0.7, 0.7, 0.7)
    skipBtn:SetScript("OnClick", function()
        warning:Hide()
        SetupWizard:ConfirmSkip()
    end)
    
    -- Hide wizard while showing warning
    if wizardFrame then
        wizardFrame:Hide()
    end
    
    warning:Show()
end

function SetupWizard:ConfirmSkip()
    -- Mark as skipped but don't apply profile
    if TweaksUI_DB then
        TweaksUI_DB.setupComplete = true
        TweaksUI_DB.setupVersion = 2
    end
    
    -- Still mark something was loaded (just defaults)
    if TweaksUI_CharDB then
        TweaksUI_CharDB.profileLoaded = "skipped"
    end
    
    if wizardFrame then
        wizardFrame:Hide()
    end
    
    print("|cff00ff00TweaksUI:|r Setup skipped. Type |cffffd100/tui|r to open settings, |cffffd100/tui setup|r to reopen wizard.")
end

function SetupWizard:Skip()
    -- Show warning dialog instead of immediately skipping
    SetupWizard:ShowSkipWarning()
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function SetupWizard:Show()
    self:ShowStep(1)
end

function SetupWizard:Hide()
    if wizardFrame then
        wizardFrame:Hide()
    end
end

function SetupWizard:IsComplete()
    return TweaksUI_DB and TweaksUI_DB.setupComplete
end

function SetupWizard:ShouldShow()
    if not TweaksUI_DB then return true end
    
    -- Don't show if user checked "don't show again"
    if TweaksUI_DB.dontShowSetupWizard then return false end
    
    -- Show if setup hasn't been completed
    if not TweaksUI_DB.setupComplete then return true end
    
    -- Show if no profile has been loaded for this character
    if not TweaksUI_CharDB then return true end
    if not TweaksUI_CharDB.profileLoaded then return true end
    
    return false
end

function SetupWizard:Reset()
    if TweaksUI_DB then
        TweaksUI_DB.setupComplete = false
        TweaksUI_DB.setupVersion = nil
        TweaksUI_DB.dontShowSetupWizard = false
    end
    if TweaksUI_CharDB then
        TweaksUI_CharDB.profileLoaded = nil
    end
    print("|cff00ff00TweaksUI:|r Setup wizard reset. Will show on next login.")
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function SetupWizard:Initialize()
    -- Check if we should auto-show
    C_Timer.After(2, function()
        if SetupWizard:ShouldShow() then
            SetupWizard:Show()
        end
    end)
end

return SetupWizard
