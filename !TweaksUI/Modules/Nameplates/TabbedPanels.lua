-- ============================================================================
-- TweaksUI: Nameplates Module - Tabbed Panels
-- Full settings panels with tabs for Enemy/Friendly nameplates
-- Matches UnitFrames module pattern
-- ============================================================================

local ADDON_NAME, TweaksUI = ...
local Nameplates = TweaksUI.Nameplates

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local PANEL_WIDTH = 440
local PANEL_HEIGHT = 520
local TAB_HEIGHT = 22

-- Tab categories for enemy nameplates
local ENEMY_TABS = {
    { id = "health", name = "Health" },
    { id = "name", name = "Name" },
    { id = "text", name = "Text" },
    { id = "cast", name = "Cast" },
    { id = "icons", name = "Icons" },
    { id = "auras", name = "Auras" },
    { id = "size", name = "Size" },
    { id = "opacity", name = "Opacity" },
    { id = "visibility", name = "Visibility" },
}

-- Tab categories for friendly nameplates
local FRIENDLY_TABS = {
    { id = "health", name = "Health" },
    { id = "name", name = "Name" },
    { id = "text", name = "Text" },
    { id = "cast", name = "Cast" },
    { id = "icons", name = "Icons" },
    { id = "auras", name = "Auras" },
    { id = "size", name = "Size" },
    { id = "opacity", name = "Opacity" },
    { id = "visibility", name = "Visibility" },
}

-- ============================================================================
-- CREATE TABBED PANEL
-- ============================================================================

function Nameplates:CreateTabbedPanel(panelKey, title, configKey, tabs)
    local darkBackdrop = self.Constants.darkBackdrop
    local settings = self.State.settings
    local config = settings[configKey]
    local disabled = self:IsNameplateAddonActive()
    local self_ref = self
    
    -- Create container (taller to fit simulation)
    local container = CreateFrame("Frame", "TweaksUI_NP_" .. panelKey, UIParent, "BackdropTemplate")
    container:SetSize(PANEL_WIDTH, PANEL_HEIGHT + 200)  -- Extra height for simulation
    container:SetBackdrop(darkBackdrop)
    container:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    container:SetBackdropBorderColor(0, 0, 0, 1)
    container:SetFrameStrata("DIALOG")
    container:SetMovable(true)
    container:EnableMouse(true)
    container:SetClampedToScreen(true)
    
    -- Position relative to hub
    if self.State.nameplatesHub then
        container:SetPoint("TOPLEFT", self.State.nameplatesHub, "TOPRIGHT", 0, 0)
    else
        container:SetPoint("CENTER")
    end
    
    -- Title
    local titleText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("TOP", 0, -8)
    titleText:SetText(title)
    titleText:SetTextColor(1, 0.82, 0)
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, container, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function()
        container:Hide()
        self_ref.State.currentOpenPanel = nil
    end)
    
    -- Drag
    container:RegisterForDrag("LeftButton")
    container:SetScript("OnDragStart", container.StartMoving)
    container:SetScript("OnDragStop", container.StopMovingOrSizing)
    
    -- ========== SIMULATION PREVIEW ==========
    local simFrame = self:CreateSimulationFrame(container, configKey)
    simFrame:SetPoint("TOP", 0, -32)
    
    -- Store reference for updates
    self.State[configKey .. "SimFrame"] = simFrame
    container.simFrame = simFrame
    
    -- Disabled warning
    local warningText = nil
    local contentStartY = -250  -- Below simulation (taller with cast controls)
    
    if disabled then
        warningText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        warningText:SetPoint("TOP", simFrame, "BOTTOM", 0, -5)
        warningText:SetWidth(PANEL_WIDTH - 20)
        warningText:SetText("|cffff6600Settings disabled:|r Platynator or Plater is active")
        warningText:SetTextColor(1, 0.6, 0)
        contentStartY = -265
    end
    
    -- Tab system
    local tabContainer = CreateFrame("Frame", nil, container)
    tabContainer:SetPoint("TOPLEFT", 5, contentStartY)
    tabContainer:SetPoint("TOPRIGHT", -5, contentStartY)
    tabContainer:SetHeight(TAB_HEIGHT)
    
    local categoryPanels = {}
    local tabButtons = {}
    local activeCategory = nil
    
    -- Helper to create scrollable content frame
    local function CreateCategoryContent(categoryId)
        local contentFrame = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
        contentFrame:SetPoint("TOPLEFT", 10, contentStartY - TAB_HEIGHT - 8)
        contentFrame:SetPoint("BOTTOMRIGHT", -28, 10)
        
        local content = CreateFrame("Frame", nil, contentFrame)
        content:SetSize(PANEL_WIDTH - 50, 800)
        contentFrame:SetScrollChild(content)
        
        contentFrame.content = content
        contentFrame.categoryId = categoryId
        contentFrame:Hide()
        
        return contentFrame
    end
    
    -- Show tab function
    local function ShowTab(categoryId)
        for id, contentFrame in pairs(categoryPanels) do
            contentFrame:Hide()
        end
        for i, btn in ipairs(tabButtons) do
            if btn.categoryId == categoryId then
                btn.bg:SetColorTexture(0.25, 0.25, 0.4, 1)
                btn.text:SetTextColor(1, 1, 1)
            else
                btn.bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
                btn.text:SetTextColor(0.7, 0.7, 0.7)
            end
        end
        if categoryPanels[categoryId] then
            categoryPanels[categoryId]:Show()
            activeCategory = categoryId
        end
    end
    
    -- Create tabs
    local tabWidth = (PANEL_WIDTH - 14) / #tabs
    
    for i, tab in ipairs(tabs) do
        local tabBtn = CreateFrame("Button", nil, tabContainer)
        tabBtn:SetSize(tabWidth - 1, TAB_HEIGHT - 2)
        tabBtn:SetPoint("LEFT", (i - 1) * tabWidth, 0)
        
        tabBtn.bg = tabBtn:CreateTexture(nil, "BACKGROUND")
        tabBtn.bg:SetAllPoints()
        tabBtn.bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
        
        tabBtn.text = tabBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tabBtn.text:SetPoint("CENTER")
        tabBtn.text:SetText(tab.name)
        tabBtn.text:SetTextColor(0.7, 0.7, 0.7)
        
        tabBtn.categoryId = tab.id
        
        tabBtn:SetScript("OnClick", function() ShowTab(tab.id) end)
        
        tabBtn:SetScript("OnEnter", function(self)
            if activeCategory ~= tab.id then
                self.bg:SetColorTexture(0.2, 0.2, 0.3, 0.95)
            end
        end)
        
        tabBtn:SetScript("OnLeave", function(self)
            if activeCategory ~= tab.id then
                self.bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
            end
        end)
        
        tabButtons[i] = tabBtn
        
        -- Create content for this tab (wrap in pcall to prevent errors from stopping other tabs)
        local contentFrame = CreateCategoryContent(tab.id)
        local success, err = pcall(function()
            self:BuildTabContent(contentFrame.content, tab.id, configKey, disabled)
        end)
        if not success then
            -- Show error message in the tab content
            local errorText = contentFrame.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            errorText:SetPoint("TOPLEFT", 10, -10)
            errorText:SetWidth(300)
            errorText:SetText("|cffff0000Error loading tab:|r\n" .. tostring(err))
            errorText:SetJustifyH("LEFT")
            errorText:SetWordWrap(true)
        end
        categoryPanels[tab.id] = contentFrame
    end
    
    -- Show first tab
    ShowTab(tabs[1].id)
    
    container:Hide()
    self.State.settingsPanels[panelKey] = container
    return container
end

-- ============================================================================
-- BUILD TAB CONTENT
-- ============================================================================

function Nameplates:BuildTabContent(content, tabId, configKey, disabled)
    if tabId == "health" then
        self:BuildHealthTab(content, configKey, disabled)
    elseif tabId == "name" then
        self:BuildNameTab(content, configKey, disabled)
    elseif tabId == "text" then
        self:BuildTextTab(content, configKey, disabled)
    elseif tabId == "cast" then
        self:BuildCastTab(content, configKey, disabled)
    elseif tabId == "icons" then
        self:BuildIconsTab(content, configKey, disabled)
    elseif tabId == "auras" then
        self:BuildAurasTab(content, configKey, disabled)
    elseif tabId == "size" then
        self:BuildScaleTab(content, configKey, disabled)
    elseif tabId == "opacity" then
        self:BuildAlphaTab(content, configKey, disabled)
    elseif tabId == "visibility" then
        self:BuildVisibilityTab(content, configKey, disabled)
    end
end

-- ============================================================================
-- HEALTH TAB
-- ============================================================================

function Nameplates:BuildHealthTab(content, configKey, disabled)
    local settings = self.State.settings
    local config = settings[configKey].healthBar
    local typeConfig = settings[configKey]  -- For scale
    local self_ref = self
    local yOffset = -5
    
    -- Enable checkbox
    yOffset = self:CreateHeader(content, yOffset, "General")
    
    local enableCb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    enableCb:SetPoint("TOPLEFT", 10, yOffset)
    enableCb:SetSize(22, 22)
    enableCb:SetChecked(config.enabled)
    
    local enableLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    enableLabel:SetPoint("LEFT", enableCb, "RIGHT", 4, 0)
    enableLabel:SetText("Enable Health Bar Customization")
    
    -- Add tooltip explaining behavior
    enableCb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Enable Health Bar Customization")
        GameTooltip:AddLine("When enabled, uses TweaksUI custom health bar.", 1, 1, 1, true)
        GameTooltip:AddLine("When disabled, shows Blizzard's default health bar.", 1, 1, 1, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("To show/hide nameplates entirely, use the Visibility tab.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    enableCb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    if disabled then
        enableCb:Disable()
        enableLabel:SetTextColor(0.5, 0.5, 0.5)
    else
        enableLabel:SetTextColor(0.9, 0.9, 0.9)
        enableCb:SetScript("OnClick", function(self)
            config.enabled = self:GetChecked()
            self_ref:SaveSettings()
            self_ref:RefreshAllHealthBars()
        end)
    end
    yOffset = yOffset - 26
    
    -- ===== GLOBAL SCALE SLIDER =====
    local scaleContainer = TweaksUI.Utilities:CreateSliderWithInput(content, {
        label = "Overall Scale:",
        min = 50,
        max = 200,
        step = 5,
        value = typeConfig.scale or 100,
        isFloat = false,
        width = 160,
        labelWidth = 100,
        valueWidth = 45,
        onValueChanged = function(value)
            typeConfig.scale = value
            self_ref:SaveSettings()
            self_ref:RefreshAllHealthBars()
            self_ref:RefreshAllTexts()
            self_ref:RefreshAllHighlights()
        end,
    })
    scaleContainer:SetPoint("TOPLEFT", 10, yOffset)
    
    if disabled then
        scaleContainer:SetEnabled(false)
    end
    yOffset = yOffset - 32
    
    -- Texture section
    yOffset = self:CreateHeader(content, yOffset, "Texture")
    
    -- Override global texture checkbox
    local globalEnabled = TweaksUI.Media and TweaksUI.Media:IsUsingGlobalTexture()
    if globalEnabled then
        local overrideCb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        overrideCb:SetPoint("TOPLEFT", 10, yOffset)
        overrideCb:SetSize(22, 22)
        overrideCb:SetChecked(settings.overrideGlobalTexture)
        
        local overrideLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        overrideLabel:SetPoint("LEFT", overrideCb, "RIGHT", 4, 0)
        overrideLabel:SetText("Override Global Texture")
        
        if disabled then
            overrideCb:Disable()
            overrideLabel:SetTextColor(0.5, 0.5, 0.5)
        else
            overrideLabel:SetTextColor(0.9, 0.9, 0.9)
            overrideCb:SetScript("OnClick", function(self)
                settings.overrideGlobalTexture = self:GetChecked()
                self_ref:SaveSettings()
                self_ref:RefreshAllHealthBars()
            end)
        end
        yOffset = yOffset - 26
    end
    
    -- Texture dropdown
    yOffset = self:CreateTextureDropdown(content, yOffset, config, disabled)
    
    -- Color section
    yOffset = self:CreateHeader(content, yOffset - 10, "Color")
    yOffset = self:CreateColorModeDropdown(content, yOffset, config, disabled)
    yOffset = self:CreateCustomColorPicker(content, yOffset, config, "customColor", "Custom Color:", disabled)
    
    -- Threat section (only for enemy nameplates)
    if configKey == "enemy" then
        yOffset = self:CreateHeader(content, yOffset - 10, "Threat Options")
        yOffset = self:CreateThreatToggle(content, yOffset, config, "invertThreatColors", "Invert Threat Colors (Tank Mode)", disabled)
        -- Note: Threat-based scaling removed due to Midnight Beta secret value restrictions
    end
    
    -- Background section
    yOffset = self:CreateHeader(content, yOffset - 10, "Background")
    yOffset = self:CreateToggleWithColor(content, yOffset, config, "bgEnabled", "bgColor", "Show Background", disabled)
    
    -- Border section
    yOffset = self:CreateHeader(content, yOffset - 10, "Border")
    yOffset = self:CreateToggleWithColor(content, yOffset, config, "borderEnabled", "borderColor", "Show Border", disabled)
    yOffset = self:CreateBorderSizeSlider(content, yOffset, config, disabled)
end

-- Helper for threat toggles (refreshes health bars)
function Nameplates:CreateThreatToggle(content, yOffset, config, key, labelText, disabled)
    local self_ref = self
    
    local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 10, yOffset)
    cb:SetSize(22, 22)
    cb:SetChecked(config[key])
    
    local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    label:SetText(labelText)
    label:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
    
    if disabled then
        cb:Disable()
    else
        cb:SetScript("OnClick", function(self)
            config[key] = self:GetChecked()
            self_ref:SaveSettings()
            self_ref:RefreshAllHealthBars()
            self_ref:RefreshAllTexts()  -- Also refresh texts for color inversion
        end)
    end
    
    return yOffset - 24
end

-- ============================================================================
-- NAME TAB
-- ============================================================================

function Nameplates:BuildNameTab(content, configKey, disabled)
    local settings = self.State.settings
    local config = settings[configKey].nameText
    local self_ref = self
    local yOffset = -5
    
    -- Enable checkbox
    yOffset = self:CreateHeader(content, yOffset, "Name Text")
    
    local enableCb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    enableCb:SetPoint("TOPLEFT", 10, yOffset)
    enableCb:SetSize(22, 22)
    enableCb:SetChecked(config.enabled)
    
    local enableLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    enableLabel:SetPoint("LEFT", enableCb, "RIGHT", 4, 0)
    enableLabel:SetText("Enable Name Text")
    enableLabel:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
    
    if not disabled then
        enableCb:SetScript("OnClick", function(self)
            config.enabled = self:GetChecked()
            self_ref:SaveSettings()
            self_ref:RefreshAllTexts()
        end)
    else
        enableCb:Disable()
    end
    yOffset = yOffset - 26
    
    -- Font section
    yOffset = self:CreateHeader(content, yOffset - 10, "Font")
    yOffset = self:CreateFontDropdown(content, yOffset, config, "font", disabled)
    yOffset = self:CreateSliderControl(content, yOffset, config, "fontSize", "Size:", 6, 24, 1, disabled)
    yOffset = self:CreateOutlineDropdown(content, yOffset, config, disabled)
    
    -- Color section
    yOffset = self:CreateHeader(content, yOffset - 10, "Color")
    yOffset = self:CreateTextColorModeDropdown(content, yOffset, config, disabled)
    yOffset = self:CreateCustomColorPicker(content, yOffset, config, "customColor", "Custom Color:", disabled)
    
    -- Position section
    yOffset = self:CreateHeader(content, yOffset - 10, "Position")
    yOffset = self:CreateAnchorDropdown(content, yOffset, config, "anchor", "Attach To:", disabled)
    yOffset = self:CreateSliderControl(content, yOffset, config, "offsetX", "X Offset:", -100, 100, 1, disabled)
    yOffset = self:CreateSliderControl(content, yOffset, config, "offsetY", "Y Offset:", -50, 50, 1, disabled)
    
    -- Options
    yOffset = self:CreateHeader(content, yOffset - 10, "Options")
    yOffset = self:CreateToggle(content, yOffset, config, "shadow", "Show Shadow", disabled)
    yOffset = self:CreateToggle(content, yOffset, config, "showServerName", "Show Server Name", disabled)
end

-- ============================================================================
-- HELPER: Create Font Dropdown
-- ============================================================================

function Nameplates:CreateFontDropdown(content, yOffset, config, key, disabled)
    local self_ref = self
    
    local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 10, yOffset)
    label:SetText("Font:")
    label:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
    
    local dropdown = CreateFrame("Frame", nil, content, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", 50, yOffset + 5)
    UIDropDownMenu_SetWidth(dropdown, 180)
    UIDropDownMenu_SetText(dropdown, config[key] or "Friz Quadrata TT")
    
    if disabled then
        UIDropDownMenu_DisableDropDown(dropdown)
    else
        UIDropDownMenu_Initialize(dropdown, function()
            local fonts = self_ref:GetFontList()
            for _, name in ipairs(fonts) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = name
                info.checked = config[key] == name
                info.func = function()
                    config[key] = name
                    UIDropDownMenu_SetText(dropdown, name)
                    self_ref:SaveSettings()
                    self_ref:RefreshAllTexts()
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
    end
    
    return yOffset - 32
end

function Nameplates:GetFontList()
    local fonts = { "Friz Quadrata TT", "Arial Narrow", "Morpheus", "Skurri" }
    
    -- Add fonts from LibSharedMedia
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local lsmFonts = LSM:HashTable("font")
        if lsmFonts then
            for name in pairs(lsmFonts) do
                local found = false
                for _, f in ipairs(fonts) do
                    if f == name then found = true; break end
                end
                if not found then
                    table.insert(fonts, name)
                end
            end
        end
    end
    
    table.sort(fonts)
    return fonts
end

-- ============================================================================
-- HELPER: Create Outline Dropdown
-- ============================================================================

function Nameplates:CreateOutlineDropdown(content, yOffset, config, disabled)
    local self_ref = self
    local OUTLINES = {
        { value = "NONE", text = "None" },
        { value = "THIN", text = "Thin" },
        { value = "THICK", text = "Thick" },
    }
    
    local function GetOutlineText(val)
        for _, opt in ipairs(OUTLINES) do
            if opt.value == val then return opt.text end
        end
        return "Thin"
    end
    
    local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 10, yOffset)
    label:SetText("Outline:")
    label:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
    
    local dropdown = CreateFrame("Frame", nil, content, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", 60, yOffset + 5)
    UIDropDownMenu_SetWidth(dropdown, 120)
    UIDropDownMenu_SetText(dropdown, GetOutlineText(config.outline))
    
    if disabled then
        UIDropDownMenu_DisableDropDown(dropdown)
    else
        UIDropDownMenu_Initialize(dropdown, function()
            for _, opt in ipairs(OUTLINES) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = opt.text
                info.checked = config.outline == opt.value
                info.func = function()
                    config.outline = opt.value
                    UIDropDownMenu_SetText(dropdown, opt.text)
                    self_ref:SaveSettings()
                    self_ref:RefreshAllTexts()
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
    end
    
    return yOffset - 32
end

-- ============================================================================
-- HELPER: Create Text Color Mode Dropdown
-- ============================================================================

function Nameplates:CreateTextColorModeDropdown(content, yOffset, config, disabled)
    local self_ref = self
    local COLOR_MODES = {
        { value = "class", text = "Class Color" },
        { value = "reaction", text = "Reaction Color" },
        { value = "threat", text = "Threat Color" },
        { value = "white", text = "White" },
        { value = "custom", text = "Custom Color" },
    }
    
    local function GetColorModeText(mode)
        for _, opt in ipairs(COLOR_MODES) do
            if opt.value == mode then return opt.text end
        end
        return "Reaction Color"
    end
    
    local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 10, yOffset)
    label:SetText("Color Mode:")
    label:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
    
    local dropdown = CreateFrame("Frame", nil, content, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", 80, yOffset + 5)
    UIDropDownMenu_SetWidth(dropdown, 140)
    UIDropDownMenu_SetText(dropdown, GetColorModeText(config.colorMode))
    
    if disabled then
        UIDropDownMenu_DisableDropDown(dropdown)
    else
        UIDropDownMenu_Initialize(dropdown, function()
            for _, opt in ipairs(COLOR_MODES) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = opt.text
                info.checked = config.colorMode == opt.value
                info.func = function()
                    config.colorMode = opt.value
                    UIDropDownMenu_SetText(dropdown, opt.text)
                    self_ref:SaveSettings()
                    self_ref:RefreshAllTexts()
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
    end
    
    return yOffset - 32
end

-- ============================================================================
-- HELPER: Create Anchor Dropdown
-- ============================================================================

function Nameplates:CreateAnchorDropdown(content, yOffset, config, key, labelText, disabled)
    local self_ref = self
    local ANCHORS = {
        "TOPLEFT", "TOP", "TOPRIGHT",
        "LEFT", "CENTER", "RIGHT",
        "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT",
    }
    
    local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 10, yOffset)
    label:SetText(labelText)
    label:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
    
    local dropdown = CreateFrame("Frame", nil, content, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", 80, yOffset + 5)
    UIDropDownMenu_SetWidth(dropdown, 120)
    UIDropDownMenu_SetText(dropdown, config[key] or "BOTTOM")
    
    if disabled then
        UIDropDownMenu_DisableDropDown(dropdown)
    else
        UIDropDownMenu_Initialize(dropdown, function()
            for _, anchor in ipairs(ANCHORS) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = anchor
                info.checked = config[key] == anchor
                info.func = function()
                    config[key] = anchor
                    UIDropDownMenu_SetText(dropdown, anchor)
                    self_ref:SaveSettings()
                    self_ref:RefreshAllTexts()
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
    end
    
    return yOffset - 32
end

-- ============================================================================
-- HELPER: Create Slider Control
-- ============================================================================

function Nameplates:CreateSliderControl(content, yOffset, config, key, labelText, minVal, maxVal, step, disabled)
    local self_ref = self
    local isFloat = step < 1
    
    -- Use centralized slider with input
    local container = TweaksUI.Utilities:CreateSliderWithInput(content, {
        label = labelText,
        min = minVal,
        max = maxVal,
        step = step,
        value = config[key] or minVal,
        isFloat = isFloat,
        decimals = isFloat and 2 or 0,
        width = 160,
        labelWidth = 80,
        valueWidth = 45,
        onValueChanged = function(value)
            config[key] = value
            self_ref:SaveSettings()
            self_ref:RefreshAllTexts()
        end,
    })
    container:SetPoint("TOPLEFT", 10, yOffset)
    
    if disabled then
        container:SetEnabled(false)
    end
    
    return yOffset - 28
end

-- ============================================================================
-- HELPER: Create Toggle
-- ============================================================================

function Nameplates:CreateToggle(content, yOffset, config, key, labelText, disabled)
    local self_ref = self
    
    local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 10, yOffset)
    cb:SetSize(22, 22)
    cb:SetChecked(config[key])
    
    local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    label:SetText(labelText)
    label:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
    
    if disabled then
        cb:Disable()
    else
        cb:SetScript("OnClick", function(self)
            config[key] = self:GetChecked()
            self_ref:SaveSettings()
            self_ref:RefreshAllTexts()
        end)
    end
    
    return yOffset - 26
end

-- ============================================================================
-- TEXT TAB (Health Text & Threat Text)
-- ============================================================================

function Nameplates:BuildTextTab(content, configKey, disabled)
    local settings = self.State.settings
    local healthConfig = settings[configKey].healthText
    local threatConfig = settings[configKey].threatText
    local self_ref = self
    local yOffset = -5
    
    -- ===== HEALTH TEXT SECTION =====
    yOffset = self:CreateHeader(content, yOffset, "Health Text")
    
    local healthEnableCb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    healthEnableCb:SetPoint("TOPLEFT", 10, yOffset)
    healthEnableCb:SetSize(22, 22)
    healthEnableCb:SetChecked(healthConfig.enabled)
    
    local healthEnableLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    healthEnableLabel:SetPoint("LEFT", healthEnableCb, "RIGHT", 4, 0)
    healthEnableLabel:SetText("Enable Health Text")
    healthEnableLabel:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
    
    if not disabled then
        healthEnableCb:SetScript("OnClick", function(self)
            healthConfig.enabled = self:GetChecked()
            self_ref:SaveSettings()
            self_ref:RefreshAllTexts()
        end)
    else
        healthEnableCb:Disable()
    end
    yOffset = yOffset - 26
    
    -- Health format dropdown
    yOffset = self:CreateHealthFormatDropdown(content, yOffset, healthConfig, disabled)
    
    -- Health text font/size
    yOffset = self:CreateFontDropdown(content, yOffset, healthConfig, "font", disabled)
    yOffset = self:CreateSliderControl(content, yOffset, healthConfig, "fontSize", "Size:", 6, 24, 1, disabled)
    
    -- Health text color
    yOffset = self:CreateTextColorModeDropdown(content, yOffset, healthConfig, disabled)
    
    -- Health text position
    yOffset = self:CreateAnchorDropdown(content, yOffset, healthConfig, "anchor", "Attach To:", disabled)
    yOffset = self:CreateSliderControl(content, yOffset, healthConfig, "offsetX", "X Offset:", -100, 100, 1, disabled)
    yOffset = self:CreateSliderControl(content, yOffset, healthConfig, "offsetY", "Y Offset:", -50, 50, 1, disabled)
    
    -- ===== THREAT TEXT SECTION =====
    yOffset = self:CreateHeader(content, yOffset - 15, "Threat Text")
    
    local threatEnableCb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    threatEnableCb:SetPoint("TOPLEFT", 10, yOffset)
    threatEnableCb:SetSize(22, 22)
    threatEnableCb:SetChecked(threatConfig.enabled)
    
    local threatEnableLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    threatEnableLabel:SetPoint("LEFT", threatEnableCb, "RIGHT", 4, 0)
    threatEnableLabel:SetText("Enable Threat Text")
    threatEnableLabel:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
    
    if not disabled then
        threatEnableCb:SetScript("OnClick", function(self)
            threatConfig.enabled = self:GetChecked()
            self_ref:SaveSettings()
            self_ref:RefreshAllTexts()
        end)
    else
        threatEnableCb:Disable()
    end
    yOffset = yOffset - 26
    
    -- Threat text font/size
    yOffset = self:CreateFontDropdown(content, yOffset, threatConfig, "font", disabled)
    yOffset = self:CreateSliderControl(content, yOffset, threatConfig, "fontSize", "Size:", 6, 24, 1, disabled)
    
    -- Threat text color
    yOffset = self:CreateTextColorModeDropdown(content, yOffset, threatConfig, disabled)
    
    -- Threat text position
    yOffset = self:CreateAnchorDropdown(content, yOffset, threatConfig, "anchor", "Attach To:", disabled)
    yOffset = self:CreateSliderControl(content, yOffset, threatConfig, "offsetX", "X Offset:", -100, 100, 1, disabled)
    yOffset = self:CreateSliderControl(content, yOffset, threatConfig, "offsetY", "Y Offset:", -50, 50, 1, disabled)
    
    -- Show percent toggle
    yOffset = self:CreateToggle(content, yOffset, threatConfig, "showPercent", "Show % Symbol", disabled)
end

-- ============================================================================
-- HELPER: Create Health Format Dropdown
-- ============================================================================

function Nameplates:CreateHealthFormatDropdown(content, yOffset, config, disabled)
    local self_ref = self
    local FORMATS = {
        { value = "PERCENT", text = "Percentage (75%)" },
        { value = "CURRENT", text = "Current (150K)" },
        { value = "BOTH", text = "Both (150K - 75%)" },
        { value = "DEFICIT", text = "Deficit (-50K)" },
        { value = "CURRENT_MAX", text = "Current / Max" },
    }
    
    local function GetFormatText(val)
        for _, opt in ipairs(FORMATS) do
            if opt.value == val then return opt.text end
        end
        return "Percentage"
    end
    
    local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 10, yOffset)
    label:SetText("Format:")
    label:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
    
    local dropdown = CreateFrame("Frame", nil, content, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", 60, yOffset + 5)
    UIDropDownMenu_SetWidth(dropdown, 160)
    UIDropDownMenu_SetText(dropdown, GetFormatText(config.format))
    
    if disabled then
        UIDropDownMenu_DisableDropDown(dropdown)
    else
        UIDropDownMenu_Initialize(dropdown, function()
            for _, opt in ipairs(FORMATS) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = opt.text
                info.checked = config.format == opt.value
                info.func = function()
                    config.format = opt.value
                    UIDropDownMenu_SetText(dropdown, opt.text)
                    self_ref:SaveSettings()
                    self_ref:RefreshAllTexts()
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
    end
    
    return yOffset - 32
end

-- ============================================================================
-- CAST TAB
-- ============================================================================

function Nameplates:BuildCastTab(content, configKey, disabled)
    local settings = self.State.settings
    local self_ref = self
    local yOffset = -5
    
    -- Inline defaults in case CastBars.lua hasn't loaded yet
    local defaultCastBar = {
        enabled = true,
        width = 0,
        height = 10,
        yOffset = -2,
        xOffset = 0,
        texture = "Blizzard",
        iconEnabled = true,
        iconSize = 0,
        iconPosition = "LEFT",
        iconOffset = -2,
        iconBorderEnabled = true,
        iconBorderColor = { 0, 0, 0, 1 },
        spellNameEnabled = true,
        spellNameFont = "Friz Quadrata TT",
        spellNameFontSize = 9,
        spellNameOutline = "OUTLINE",
        spellNamePosition = "LEFT",
        spellNameOffsetX = 2,
        spellNameOffsetY = 0,
        spellNameColor = { 1, 1, 1, 1 },
        castTargetEnabled = false,
        castTargetFont = "Friz Quadrata TT",
        castTargetFontSize = 8,
        castTargetOutline = "OUTLINE",
        castTargetPosition = "BOTTOM",
        castTargetOffsetX = 0,
        castTargetOffsetY = -2,
        castTargetColor = { 1, 0.8, 0.8, 1 },
        castTargetUseClassColor = true,
        timerEnabled = true,
        timerFont = "Friz Quadrata TT",
        timerFontSize = 9,
        timerOutline = "OUTLINE",
        timerPosition = "RIGHT",
        timerOffsetX = -2,
        timerOffsetY = 0,
        timerColor = { 1, 1, 1, 1 },
        timerShowDecimals = true,
        castingColor = { 1, 0.7, 0, 1 },
        channelingColor = { 0, 0.7, 1, 1 },
        nonInterruptibleColor = { 0.5, 0.5, 0.5, 1 },
        interruptedColor = { 1, 0, 0, 1 },
        importantCastColor = { 1, 0, 0.5, 1 },
        importantChannelColor = { 0.5, 0, 1, 1 },
        bgEnabled = true,
        bgColor = { 0.1, 0.1, 0.1, 0.8 },
        borderEnabled = true,
        borderColor = { 0, 0, 0, 1 },
        borderSize = 1,
        sparkEnabled = true,
        sparkWidth = 12,
        sparkColor = { 1, 1, 1, 0.8 },
    }
    
    -- Ensure castBar settings exist before accessing
    if not settings[configKey].castBar then
        -- Use module defaults if available, otherwise use inline defaults
        local defaults = (self.Defaults and self.Defaults.CAST_BAR) or defaultCastBar
        if configKey == "friendly" then
            defaults = (self.Defaults and self.Defaults.FRIENDLY_CAST_BAR) or defaultCastBar
            -- Friendly defaults: disabled by default
            if defaults == defaultCastBar then
                defaults = self:DeepCopy(defaultCastBar)
                defaults.enabled = false
            end
        end
        settings[configKey].castBar = self:DeepCopy(defaults)
        self:SaveSettings()
    end
    
    local config = settings[configKey].castBar
    
    -- Safety check - if still nil, use inline defaults directly
    if not config then
        config = self:DeepCopy(defaultCastBar)
        settings[configKey].castBar = config
        self:SaveSettings()
    end
    
    -- Enable checkbox
    yOffset = self:CreateHeader(content, yOffset, "Cast Bar")
    
    local enableCb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    enableCb:SetPoint("TOPLEFT", 10, yOffset)
    enableCb:SetSize(22, 22)
    enableCb:SetChecked(config.enabled)
    
    local enableLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    enableLabel:SetPoint("LEFT", enableCb, "RIGHT", 4, 0)
    enableLabel:SetText("Enable Cast Bar")
    enableLabel:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
    
    if not disabled then
        enableCb:SetScript("OnClick", function(self)
            config.enabled = self:GetChecked()
            self_ref:SaveSettings()
            if self_ref.RefreshAllCastBars then
                self_ref:RefreshAllCastBars()
            end
        end)
    else
        enableCb:Disable()
    end
    yOffset = yOffset - 26
    
    -- Size & Position section
    yOffset = self:CreateHeader(content, yOffset - 10, "Size & Position")
    yOffset = self:CreateCastBarSlider(content, yOffset, config, "width", "Width (0=match health):", 0, 200, 5, disabled)
    yOffset = self:CreateCastBarSlider(content, yOffset, config, "height", "Height:", 4, 30, 1, disabled)
    yOffset = self:CreateCastBarSlider(content, yOffset, config, "yOffset", "Y Offset:", -30, 30, 1, disabled)
    yOffset = self:CreateCastBarSlider(content, yOffset, config, "xOffset", "X Offset:", -50, 50, 1, disabled)
    
    -- Texture section
    yOffset = self:CreateHeader(content, yOffset - 10, "Texture")
    yOffset = self:CreateCastBarTextureDropdown(content, yOffset, config, disabled)
    
    -- Icon section
    yOffset = self:CreateHeader(content, yOffset - 10, "Icon")
    yOffset = self:CreateCastBarToggle(content, yOffset, config, "iconEnabled", "Show Icon", disabled)
    yOffset = self:CreateCastBarSlider(content, yOffset, config, "iconSize", "Icon Size (0=match height):", 0, 40, 1, disabled)
    yOffset = self:CreateCastBarPositionDropdown(content, yOffset, config, "iconPosition", "Icon Position:", {"LEFT", "RIGHT"}, disabled)
    yOffset = self:CreateCastBarToggle(content, yOffset, config, "iconBorderEnabled", "Show Icon Border", disabled)
    
    -- Spell Name section
    yOffset = self:CreateHeader(content, yOffset - 10, "Spell Name")
    yOffset = self:CreateCastBarToggle(content, yOffset, config, "spellNameEnabled", "Show Spell Name", disabled)
    yOffset = self:CreateFontDropdown(content, yOffset, config, "spellNameFont", disabled)
    yOffset = self:CreateCastBarSlider(content, yOffset, config, "spellNameFontSize", "Font Size:", 6, 18, 1, disabled)
    yOffset = self:CreateCastBarPositionDropdown(content, yOffset, config, "spellNamePosition", "Position:", {"TOP", "LEFT", "CENTER", "RIGHT"}, disabled)
    
    -- Timer section
    yOffset = self:CreateHeader(content, yOffset - 10, "Timer")
    yOffset = self:CreateCastBarToggle(content, yOffset, config, "timerEnabled", "Show Timer", disabled)
    yOffset = self:CreateCastBarSlider(content, yOffset, config, "timerFontSize", "Font Size:", 6, 18, 1, disabled)
    yOffset = self:CreateCastBarToggle(content, yOffset, config, "timerShowDecimals", "Show Decimals", disabled)
    yOffset = self:CreateCastBarPositionDropdown(content, yOffset, config, "timerPosition", "Position:", {"LEFT", "CENTER", "RIGHT"}, disabled)
    
    -- Cast Target section (who the spell is targeting)
    yOffset = self:CreateHeader(content, yOffset - 10, "Cast Target")
    yOffset = self:CreateCastBarToggle(content, yOffset, config, "castTargetEnabled", "Show Target Name", disabled)
    yOffset = self:CreateCastBarSlider(content, yOffset, config, "castTargetFontSize", "Font Size:", 6, 14, 1, disabled)
    yOffset = self:CreateCastBarPositionDropdown(content, yOffset, config, "castTargetPosition", "Position:", {"TOP", "BOTTOM", "LEFT", "RIGHT"}, disabled)
    yOffset = self:CreateCastBarToggle(content, yOffset, config, "castTargetUseClassColor", "Use Class Colors", disabled)
    
    -- Colors section
    yOffset = self:CreateHeader(content, yOffset - 10, "Colors")
    yOffset = self:CreateCastBarColorPicker(content, yOffset, config, "castingColor", "Normal Cast:", disabled)
    yOffset = self:CreateCastBarColorPicker(content, yOffset, config, "channelingColor", "Channeling:", disabled)
    yOffset = self:CreateCastBarColorPicker(content, yOffset, config, "importantCastColor", "Important Cast:", disabled)
    yOffset = self:CreateCastBarColorPicker(content, yOffset, config, "importantChannelColor", "Important Channel:", disabled)
    yOffset = self:CreateCastBarColorPicker(content, yOffset, config, "nonInterruptibleColor", "Non-Interruptible:", disabled)
    yOffset = self:CreateCastBarColorPicker(content, yOffset, config, "interruptedColor", "Interrupted:", disabled)
    
    -- Background & Border section
    yOffset = self:CreateHeader(content, yOffset - 10, "Background & Border")
    yOffset = self:CreateToggleWithColor(content, yOffset, config, "bgEnabled", "bgColor", "Show Background", disabled)
    yOffset = self:CreateToggleWithColor(content, yOffset, config, "borderEnabled", "borderColor", "Show Border", disabled)
    yOffset = self:CreateCastBarSlider(content, yOffset, config, "borderSize", "Border Size:", 1, 4, 1, disabled)
    
    -- Spark section
    yOffset = self:CreateHeader(content, yOffset - 10, "Spark")
    yOffset = self:CreateCastBarToggle(content, yOffset, config, "sparkEnabled", "Show Spark", disabled)
    yOffset = self:CreateCastBarSlider(content, yOffset, config, "sparkWidth", "Spark Width:", 4, 24, 1, disabled)
end

-- Helper: Create slider WITH numeric input for cast bar settings
function Nameplates:CreateCastBarSlider(content, yOffset, config, key, labelText, minVal, maxVal, step, disabled)
    local self_ref = self
    
    local container = TweaksUI.Utilities:CreateSliderWithInput(content, {
        label = labelText,
        min = minVal,
        max = maxVal,
        step = step,
        value = config[key] or minVal,
        isFloat = false,
        width = 180,
        labelWidth = 140,
        valueWidth = 45,
        onValueChanged = function(value)
            config[key] = value
            self_ref:SaveSettings()
            if self_ref.RefreshAllCastBars then self_ref:RefreshAllCastBars() end
        end,
    })
    container:SetPoint("TOPLEFT", 10, yOffset)
    
    if disabled then
        container:SetEnabled(false)
    end
    
    return yOffset - 28
end

-- Helper: Create toggle for cast bar settings
function Nameplates:CreateCastBarToggle(content, yOffset, config, key, labelText, disabled)
    local self_ref = self
    
    local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 10, yOffset)
    cb:SetSize(22, 22)
    cb:SetChecked(config[key])
    
    local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    label:SetText(labelText)
    label:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
    
    if disabled then
        cb:Disable()
    else
        cb:SetScript("OnClick", function(self)
            config[key] = self:GetChecked()
            self_ref:SaveSettings()
            if self_ref.RefreshAllCastBars then self_ref:RefreshAllCastBars() end
        end)
    end
    
    return yOffset - 24
end

-- Helper: Create position dropdown for cast bar
function Nameplates:CreateCastBarPositionDropdown(content, yOffset, config, key, labelText, options, disabled)
    local self_ref = self
    
    local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 10, yOffset)
    label:SetText(labelText)
    label:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
    
    local dropdown = CreateFrame("Frame", nil, content, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", 100, yOffset + 5)
    UIDropDownMenu_SetWidth(dropdown, 100)
    UIDropDownMenu_SetText(dropdown, config[key] or options[1])
    
    if disabled then
        UIDropDownMenu_DisableDropDown(dropdown)
    else
        UIDropDownMenu_Initialize(dropdown, function()
            for _, opt in ipairs(options) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = opt
                info.checked = config[key] == opt
                info.func = function()
                    config[key] = opt
                    UIDropDownMenu_SetText(dropdown, opt)
                    self_ref:SaveSettings()
                    if self_ref.RefreshAllCastBars then self_ref:RefreshAllCastBars() end
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
    end
    
    return yOffset - 32
end

-- Helper: Create color picker for cast bar
function Nameplates:CreateCastBarColorPicker(content, yOffset, config, key, labelText, disabled)
    local self_ref = self
    
    local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 10, yOffset)
    label:SetText(labelText)
    label:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
    
    local colorSwatch = CreateFrame("Button", nil, content)
    colorSwatch:SetPoint("LEFT", label, "RIGHT", 10, 0)
    colorSwatch:SetSize(20, 20)
    
    local colorTex = colorSwatch:CreateTexture(nil, "BACKGROUND")
    colorTex:SetAllPoints()
    local c = config[key] or {1, 1, 1, 1}
    colorTex:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
    
    local border = colorSwatch:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0, 0, 0, 1)
    
    if not disabled then
        colorSwatch:SetScript("OnClick", function()
            local currentColor = config[key] or {1, 1, 1, 1}
            ColorPickerFrame:SetupColorPickerAndShow({
                r = currentColor[1],
                g = currentColor[2],
                b = currentColor[3],
                opacity = currentColor[4] or 1,
                hasOpacity = true,
                swatchFunc = function()
                    local r, g, b = ColorPickerFrame:GetColorRGB()
                    local a = ColorPickerFrame:GetColorAlpha()
                    config[key] = {r, g, b, a}
                    colorTex:SetColorTexture(r, g, b, a)
                    self_ref:SaveSettings()
                    if self_ref.RefreshAllCastBars then self_ref:RefreshAllCastBars() end
                end,
                cancelFunc = function(prev)
                    config[key] = {prev.r, prev.g, prev.b, prev.opacity}
                    colorTex:SetColorTexture(prev.r, prev.g, prev.b, prev.opacity)
                    self_ref:SaveSettings()
                    if self_ref.RefreshAllCastBars then self_ref:RefreshAllCastBars() end
                end,
            })
        end)
    end
    
    return yOffset - 24
end

-- ============================================================================
-- ICONS TAB
-- ============================================================================

function Nameplates:BuildIconsTab(content, configKey, disabled)
    local settings = self.State.settings
    local config = settings[configKey] and settings[configKey].icons
    local self_ref = self
    
    -- Initialize icons config if needed
    if not config then
        settings[configKey].icons = self:DeepCopy(self.Defaults.ICONS)
        config = settings[configKey].icons
    end
    
    local yOffset = -5
    
    -- Classification Icon section (elite dragon, rare, boss)
    yOffset = self:CreateHeader(content, yOffset, "Classification Icon")
    
    -- Info text
    local infoText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoText:SetPoint("TOPLEFT", 10, yOffset)
    infoText:SetText("Elite dragon, rare star, boss skull indicators")
    infoText:SetTextColor(0.7, 0.7, 0.7)
    yOffset = yOffset - 18
    
    yOffset = self:CreateIconToggle(content, yOffset, config, "classificationEnabled", "Show Classification Icon", disabled)
    yOffset = self:CreateIconSlider(content, yOffset, config, "classificationSize", "Size:", 8, 32, 1, disabled)
    yOffset = self:CreateIconPositionDropdown(content, yOffset, config, "classificationPosition", "Position:", disabled)
    yOffset = self:CreateIconSlider(content, yOffset, config, "classificationOffsetX", "X Offset:", -50, 50, 1, disabled)
    yOffset = self:CreateIconSlider(content, yOffset, config, "classificationOffsetY", "Y Offset:", -50, 50, 1, disabled)
    
    -- Raid Marker section
    yOffset = self:CreateHeader(content, yOffset - 10, "Raid Target Marker")
    
    yOffset = self:CreateIconToggle(content, yOffset, config, "raidMarkerEnabled", "Show Raid Marker", disabled)
    yOffset = self:CreateIconSlider(content, yOffset, config, "raidMarkerSize", "Size:", 10, 40, 1, disabled)
    yOffset = self:CreateIconPositionDropdown(content, yOffset, config, "raidMarkerPosition", "Position:", disabled)
    yOffset = self:CreateIconSlider(content, yOffset, config, "raidMarkerOffsetX", "X Offset:", -50, 50, 1, disabled)
    yOffset = self:CreateIconSlider(content, yOffset, config, "raidMarkerOffsetY", "Y Offset:", -50, 50, 1, disabled)
    
    -- Quest Icon section
    yOffset = self:CreateHeader(content, yOffset - 10, "Quest Indicator")
    
    yOffset = self:CreateIconToggle(content, yOffset, config, "questEnabled", "Show Quest Icon", disabled)
    yOffset = self:CreateIconSlider(content, yOffset, config, "questSize", "Size:", 8, 32, 1, disabled)
    yOffset = self:CreateIconPositionDropdown(content, yOffset, config, "questPosition", "Position:", disabled)
    yOffset = self:CreateIconSlider(content, yOffset, config, "questOffsetX", "X Offset:", -50, 50, 1, disabled)
    yOffset = self:CreateIconSlider(content, yOffset, config, "questOffsetY", "Y Offset:", -50, 50, 1, disabled)
    
    -- Level Text section
    yOffset = self:CreateHeader(content, yOffset - 10, "Level Text")
    
    yOffset = self:CreateIconToggle(content, yOffset, config, "levelEnabled", "Show Level", disabled)
    yOffset = self:CreateIconSlider(content, yOffset, config, "levelFontSize", "Font Size:", 6, 18, 1, disabled)
    yOffset = self:CreateIconPositionDropdown(content, yOffset, config, "levelPosition", "Position:", disabled)
    yOffset = self:CreateIconSlider(content, yOffset, config, "levelOffsetX", "X Offset:", -50, 50, 1, disabled)
    yOffset = self:CreateIconSlider(content, yOffset, config, "levelOffsetY", "Y Offset:", -50, 50, 1, disabled)
    yOffset = self:CreateIconToggle(content, yOffset, config, "levelUseDifficultyColor", "Use Difficulty Color", disabled)
    
    -- PvP Marker section
    yOffset = self:CreateHeader(content, yOffset - 10, "PvP Marker")
    
    local pvpInfo = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pvpInfo:SetPoint("TOPLEFT", 10, yOffset)
    pvpInfo:SetText("Flag carrier, orb carrier, bounty icons")
    pvpInfo:SetTextColor(0.7, 0.7, 0.7)
    yOffset = yOffset - 18
    
    yOffset = self:CreateIconToggle(content, yOffset, config, "pvpMarkerEnabled", "Show PvP Marker", disabled)
    yOffset = self:CreateIconSlider(content, yOffset, config, "pvpMarkerSize", "Size:", 10, 40, 1, disabled)
    yOffset = self:CreateIconPositionDropdown(content, yOffset, config, "pvpMarkerPosition", "Position:", disabled)
    yOffset = self:CreateIconSlider(content, yOffset, config, "pvpMarkerOffsetX", "X Offset:", -50, 50, 1, disabled)
    yOffset = self:CreateIconSlider(content, yOffset, config, "pvpMarkerOffsetY", "Y Offset:", -50, 50, 1, disabled)
    
    return yOffset
end

-- Icon Tab helper functions
function Nameplates:CreateIconToggle(content, yOffset, config, key, label, disabled)
    local self_ref = self
    
    local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 10, yOffset)
    cb:SetSize(24, 24)
    cb:SetChecked(config[key])
    cb:SetEnabled(not disabled)
    
    local cbLabel = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cbLabel:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    cbLabel:SetText(label)
    cbLabel:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
    
    cb:SetScript("OnClick", function(self)
        config[key] = self:GetChecked()
        self_ref:SaveSettings()
        self_ref:RefreshAllIcons()
    end)
    
    return yOffset - 26
end

function Nameplates:CreateIconSlider(content, yOffset, config, key, label, minVal, maxVal, step, disabled)
    local self_ref = self
    
    local sliderLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sliderLabel:SetPoint("TOPLEFT", 10, yOffset)
    sliderLabel:SetText(label)
    sliderLabel:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
    
    local valueText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    valueText:SetPoint("TOPRIGHT", -10, yOffset)
    valueText:SetText(tostring(config[key] or minVal))
    valueText:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
    
    local slider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 10, yOffset - 18)
    slider:SetPoint("TOPRIGHT", -10, yOffset - 18)
    slider:SetHeight(16)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(config[key] or minVal)
    slider:SetEnabled(not disabled)
    
    slider.Low:SetText(tostring(minVal))
    slider.High:SetText(tostring(maxVal))
    slider.Text:SetText("")
    
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        config[key] = value
        valueText:SetText(tostring(value))
        self_ref:SaveSettings()
        self_ref:RefreshAllIcons()
    end)
    
    return yOffset - 44
end

function Nameplates:CreateIconPositionDropdown(content, yOffset, config, key, label, disabled)
    local self_ref = self
    local positions = {"LEFT", "RIGHT", "TOP", "BOTTOM"}
    
    local ddLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ddLabel:SetPoint("TOPLEFT", 10, yOffset)
    ddLabel:SetText(label)
    ddLabel:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
    
    local dropdown = CreateFrame("Frame", nil, content, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", 60, yOffset + 5)
    UIDropDownMenu_SetWidth(dropdown, 120)
    UIDropDownMenu_SetText(dropdown, config[key] or "LEFT")
    
    if disabled then
        UIDropDownMenu_DisableDropDown(dropdown)
    else
        UIDropDownMenu_Initialize(dropdown, function()
            for _, pos in ipairs(positions) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = pos
                info.checked = config[key] == pos
                info.func = function()
                    config[key] = pos
                    UIDropDownMenu_SetText(dropdown, pos)
                    self_ref:SaveSettings()
                    self_ref:RefreshAllIcons()
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
    end
    
    return yOffset - 32
end

-- Refresh all nameplate icons
function Nameplates:RefreshAllIcons()
    if not self.State.enhancedNameplates then return end
    
    for nameplate, data in pairs(self.State.enhancedNameplates) do
        if data.unit then
            self:UpdateNameplateIcons(nameplate, data, data.unit)
        end
    end
end

-- ============================================================================
-- AURAS TAB (Placeholder for 1.3.5)
-- ============================================================================

function Nameplates:BuildAurasTab(content, configKey, disabled)
    local settings = self.State.settings
    local self_ref = self
    local yOffset = -5
    
    -- Ensure aura settings exist with defaults
    if not settings[configKey].auras then
        settings[configKey].auras = {
            enabled = (configKey == "enemy"),  -- Default enabled for enemy, disabled for friendly
            debuffs = {
                enabled = true,
                maxIcons = 6,
                iconSize = 20,
                spacing = 2,
                growDirection = "RIGHT",
                position = "BOTTOM",
                offsetX = 0,
                offsetY = -2,
                onlyMine = true,
                onlyNameplateRelevant = true,
                showDuration = true,
                showDurationText = false,
                durationFontSize = 10,
                showStacks = true,
                stackFontSize = 10,
                showBorder = true,
                colorByDispelType = true,
                sortRule = "Expiration",
                sortDirection = "Normal",
            },
            buffs = {
                enabled = true,
                maxIcons = 4,
                iconSize = 18,
                spacing = 2,
                growDirection = "RIGHT",
                position = "TOP",
                offsetX = 0,
                offsetY = 2,
                onlyDispellable = true,
                onlyStealable = false,
                showEnrage = true,
                showDuration = true,
                showDurationText = false,
                durationFontSize = 10,
                showStacks = true,
                stackFontSize = 10,
                showBorder = true,
                colorByDispelType = true,
                sortRule = "Expiration",
                sortDirection = "Normal",
            },
        }
    end
    local config = settings[configKey].auras
    
    -- Ensure sub-tables exist
    if not config.debuffs then
        config.debuffs = {
            enabled = true, maxIcons = 6, iconSize = 20, spacing = 2,
            growDirection = "RIGHT", position = "BOTTOM", offsetX = 0, offsetY = -2,
            onlyMine = true, onlyNameplateRelevant = true, showDuration = true,
            showDurationText = true, durationFontSize = 10,
            showStacks = true, stackFontSize = 10, showBorder = true, colorByDispelType = true,
        }
    end
    if not config.buffs then
        config.buffs = {
            enabled = true, maxIcons = 4, iconSize = 18, spacing = 2,
            growDirection = "RIGHT", position = "TOP", offsetX = 0, offsetY = 2,
            onlyDispellable = true, onlyStealable = false, showEnrage = true,
            showDuration = true, showDurationText = true, durationFontSize = 10,
            showStacks = true, stackFontSize = 10, showBorder = true, colorByDispelType = true,
        }
    end
    
    local debuffConfig = config.debuffs
    local buffConfig = config.buffs
    
    -- ========================================
    -- Master Enable
    -- ========================================
    yOffset = self:CreateHeader(content, yOffset, "Aura Display")
    
    local enabledCb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    enabledCb:SetPoint("TOPLEFT", 10, yOffset)
    enabledCb:SetSize(22, 22)
    enabledCb:SetChecked(config.enabled)
    local enabledLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    enabledLabel:SetPoint("LEFT", enabledCb, "RIGHT", 4, 0)
    enabledLabel:SetText("Enable Aura Display")
    if disabled then
        enabledCb:Disable()
        enabledLabel:SetTextColor(0.5, 0.5, 0.5)
    else
        enabledLabel:SetTextColor(0.9, 0.9, 0.9)
        enabledCb:SetScript("OnClick", function(self)
            config.enabled = self:GetChecked()
            self_ref:SaveSettings()
            self_ref:RefreshAllNameplates()
        end)
    end
    yOffset = yOffset - 28
    
    -- ========================================
    -- DEBUFFS Section
    -- ========================================
    yOffset = self:CreateHeader(content, yOffset, "Debuffs (Your DoTs)")
    
    -- Enable debuffs
    yOffset = self:CreateAuraCheckbox(content, yOffset, "Show Debuffs", debuffConfig, "enabled", disabled)
    yOffset = self:CreateAuraCheckbox(content, yOffset, "Only My Debuffs", debuffConfig, "onlyMine", disabled)
    
    -- Size options
    yOffset = self:CreateAuraSlider(content, yOffset, "Max Icons:", debuffConfig, "maxIcons", 1, 12, 1, disabled)
    yOffset = self:CreateAuraSlider(content, yOffset, "Icon Size:", debuffConfig, "iconSize", 12, 120, 1, disabled)
    yOffset = self:CreateAuraSlider(content, yOffset, "Spacing:", debuffConfig, "spacing", 0, 10, 1, disabled)
    
    -- Position dropdown
    yOffset = self:CreateAuraPositionDropdown(content, yOffset, "Position:", debuffConfig, disabled)
    yOffset = self:CreateAuraJustifyDropdown(content, yOffset, "Justify:", debuffConfig, disabled)
    yOffset = self:CreateAuraGrowDropdown(content, yOffset, "Grow:", debuffConfig, disabled)
    
    -- Position offsets
    yOffset = self:CreateAuraSlider(content, yOffset, "Offset X:", debuffConfig, "offsetX", -50, 50, 1, disabled)
    yOffset = self:CreateAuraSlider(content, yOffset, "Offset Y:", debuffConfig, "offsetY", -50, 50, 1, disabled)
    
    -- Display options
    yOffset = self:CreateAuraCheckbox(content, yOffset, "Show Duration Text", debuffConfig, "showDurationText", disabled)
    yOffset = self:CreateAuraSlider(content, yOffset, "Duration Font Size:", debuffConfig, "durationFontSize", 6, 16, 1, disabled)
    yOffset = self:CreateAuraCheckbox(content, yOffset, "Show Stack Counts", debuffConfig, "showStacks", disabled)
    yOffset = self:CreateAuraSlider(content, yOffset, "Stack Font Size:", debuffConfig, "stackFontSize", 6, 16, 1, disabled)
    yOffset = self:CreateAuraCheckbox(content, yOffset, "Show Border", debuffConfig, "showBorder", disabled)
    yOffset = self:CreateAuraCheckbox(content, yOffset, "Color Border by Type", debuffConfig, "colorByDispelType", disabled)
    yOffset = self:CreateAuraCheckbox(content, yOffset, "Hide Permanent (No Duration)", debuffConfig, "hidePermanent", disabled)
    
    yOffset = yOffset - 10
    
    -- ========================================
    -- BUFFS Section
    -- ========================================
    yOffset = self:CreateHeader(content, yOffset, "Buffs (Dispellable/Stealable)")
    
    -- Enable buffs
    yOffset = self:CreateAuraCheckbox(content, yOffset, "Show Dispellable Buffs", buffConfig, "enabled", disabled)
    yOffset = self:CreateAuraCheckbox(content, yOffset, "Only Dispellable (Magic)", buffConfig, "onlyDispellable", disabled)
    yOffset = self:CreateAuraCheckbox(content, yOffset, "Only Stealable", buffConfig, "onlyStealable", disabled)
    yOffset = self:CreateAuraCheckbox(content, yOffset, "Show Enrage Effects", buffConfig, "showEnrage", disabled)
    
    -- Size options
    yOffset = self:CreateAuraSlider(content, yOffset, "Max Icons:", buffConfig, "maxIcons", 1, 8, 1, disabled)
    yOffset = self:CreateAuraSlider(content, yOffset, "Icon Size:", buffConfig, "iconSize", 12, 120, 1, disabled)
    yOffset = self:CreateAuraSlider(content, yOffset, "Spacing:", buffConfig, "spacing", 0, 10, 1, disabled)
    
    -- Position dropdown
    yOffset = self:CreateAuraPositionDropdown(content, yOffset, "Position:", buffConfig, disabled)
    yOffset = self:CreateAuraJustifyDropdown(content, yOffset, "Justify:", buffConfig, disabled)
    yOffset = self:CreateAuraGrowDropdown(content, yOffset, "Grow:", buffConfig, disabled)
    
    -- Position offsets
    yOffset = self:CreateAuraSlider(content, yOffset, "Offset X:", buffConfig, "offsetX", -50, 50, 1, disabled)
    yOffset = self:CreateAuraSlider(content, yOffset, "Offset Y:", buffConfig, "offsetY", -50, 50, 1, disabled)
    
    -- Display options
    yOffset = self:CreateAuraCheckbox(content, yOffset, "Show Duration Text", buffConfig, "showDurationText", disabled)
    yOffset = self:CreateAuraSlider(content, yOffset, "Duration Font Size:", buffConfig, "durationFontSize", 6, 16, 1, disabled)
    yOffset = self:CreateAuraCheckbox(content, yOffset, "Show Stack Counts", buffConfig, "showStacks", disabled)
    yOffset = self:CreateAuraSlider(content, yOffset, "Stack Font Size:", buffConfig, "stackFontSize", 6, 16, 1, disabled)
    yOffset = self:CreateAuraCheckbox(content, yOffset, "Show Border", buffConfig, "showBorder", disabled)
    yOffset = self:CreateAuraCheckbox(content, yOffset, "Color Border by Type", buffConfig, "colorByDispelType", disabled)
    yOffset = self:CreateAuraCheckbox(content, yOffset, "Hide Permanent (No Duration)", buffConfig, "hidePermanent", disabled)
end

-- Helper for position dropdown
function Nameplates:CreateAuraPositionDropdown(content, yOffset, labelText, config, disabled)
    local self_ref = self
    local positions = {
        { value = "BOTTOM", text = "Bottom" },
        { value = "TOP", text = "Top" },
        { value = "LEFT", text = "Left" },
        { value = "RIGHT", text = "Right" },
    }
    
    local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 10, yOffset)
    label:SetText(labelText)
    label:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
    
    local dropdown = CreateFrame("Frame", nil, content, "UIDropDownMenuTemplate")
    dropdown:SetPoint("LEFT", label, "RIGHT", -10, -2)
    UIDropDownMenu_SetWidth(dropdown, 80)
    
    local function GetPositionText(value)
        for _, p in ipairs(positions) do
            if p.value == value then return p.text end
        end
        return "Bottom"
    end
    
    UIDropDownMenu_SetText(dropdown, GetPositionText(config.position or "BOTTOM"))
    
    if not disabled then
        UIDropDownMenu_Initialize(dropdown, function(self, level)
            for _, pos in ipairs(positions) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = pos.text
                info.value = pos.value
                info.checked = (config.position == pos.value)
                info.func = function()
                    config.position = pos.value
                    UIDropDownMenu_SetText(dropdown, pos.text)
                    self_ref:SaveSettings()
                    self_ref:RefreshAllNameplates()
                    self_ref:RefreshAllSimulations()
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
    else
        UIDropDownMenu_DisableDropDown(dropdown)
    end
    
    return yOffset - 28
end

-- Helper for grow direction dropdown
function Nameplates:CreateAuraGrowDropdown(content, yOffset, labelText, config, disabled)
    local self_ref = self
    local directions = {
        { value = "RIGHT", text = "Right" },
        { value = "LEFT", text = "Left" },
    }
    
    local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 10, yOffset)
    label:SetText(labelText)
    label:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
    
    local dropdown = CreateFrame("Frame", nil, content, "UIDropDownMenuTemplate")
    dropdown:SetPoint("LEFT", label, "RIGHT", -10, -2)
    UIDropDownMenu_SetWidth(dropdown, 80)
    
    local function GetDirectionText(value)
        for _, d in ipairs(directions) do
            if d.value == value then return d.text end
        end
        return "Right"
    end
    
    UIDropDownMenu_SetText(dropdown, GetDirectionText(config.growDirection or "RIGHT"))
    
    if not disabled then
        UIDropDownMenu_Initialize(dropdown, function(self, level)
            for _, dir in ipairs(directions) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = dir.text
                info.value = dir.value
                info.checked = (config.growDirection == dir.value)
                info.func = function()
                    config.growDirection = dir.value
                    UIDropDownMenu_SetText(dropdown, dir.text)
                    self_ref:SaveSettings()
                    self_ref:RefreshAllNameplates()
                    self_ref:RefreshAllSimulations()
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
    else
        UIDropDownMenu_DisableDropDown(dropdown)
    end
    
    return yOffset - 28
end

-- Helper for justify dropdown
function Nameplates:CreateAuraJustifyDropdown(content, yOffset, labelText, config, disabled)
    local self_ref = self
    local justifications = {
        { value = "LEFT", text = "Left" },
        { value = "CENTER", text = "Center" },
        { value = "RIGHT", text = "Right" },
    }
    
    local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 10, yOffset)
    label:SetText(labelText)
    label:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
    
    local dropdown = CreateFrame("Frame", nil, content, "UIDropDownMenuTemplate")
    dropdown:SetPoint("LEFT", label, "RIGHT", -10, -2)
    UIDropDownMenu_SetWidth(dropdown, 80)
    
    local function GetJustifyText(value)
        for _, j in ipairs(justifications) do
            if j.value == value then return j.text end
        end
        return "Center"
    end
    
    UIDropDownMenu_SetText(dropdown, GetJustifyText(config.justify or "CENTER"))
    
    if not disabled then
        UIDropDownMenu_Initialize(dropdown, function(self, level)
            for _, just in ipairs(justifications) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = just.text
                info.value = just.value
                info.checked = (config.justify == just.value)
                info.func = function()
                    config.justify = just.value
                    UIDropDownMenu_SetText(dropdown, just.text)
                    self_ref:SaveSettings()
                    self_ref:RefreshAllNameplates()
                    self_ref:RefreshAllSimulations()
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
    else
        UIDropDownMenu_DisableDropDown(dropdown)
    end
    
    return yOffset - 28
end

-- Helper for aura checkboxes
function Nameplates:CreateAuraCheckbox(content, yOffset, labelText, config, key, disabled)
    local self_ref = self
    
    local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 10, yOffset)
    cb:SetSize(22, 22)
    cb:SetChecked(config[key])
    
    local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    label:SetText(labelText)
    
    if disabled then
        cb:Disable()
        label:SetTextColor(0.5, 0.5, 0.5)
    else
        label:SetTextColor(0.9, 0.9, 0.9)
        cb:SetScript("OnClick", function(self)
            config[key] = self:GetChecked()
            self_ref:SaveSettings()
            self_ref:RefreshAllNameplates()
        end)
    end
    
    return yOffset - 24
end

-- Helper for aura sliders with manual entry
function Nameplates:CreateAuraSlider(content, yOffset, labelText, config, key, minVal, maxVal, step, disabled)
    local self_ref = self
    
    local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 10, yOffset)
    label:SetText(labelText)
    label:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
    
    local slider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
    slider:SetPoint("LEFT", label, "RIGHT", 10, 0)
    slider:SetWidth(100)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(config[key] or minVal)
    slider.Low:SetText("")
    slider.High:SetText("")
    slider.Text:SetText("")  -- Hide default text, we use editbox
    
    -- Manual entry editbox
    local editBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    editBox:SetPoint("LEFT", slider, "RIGHT", 8, 0)
    editBox:SetSize(40, 18)
    editBox:SetAutoFocus(false)
    editBox:SetNumeric(false)  -- Allow negative numbers
    editBox:SetText(tostring(config[key] or minVal))
    editBox:SetJustifyH("CENTER")
    
    if disabled then
        slider:Disable()
        editBox:Disable()
        editBox:SetTextColor(0.5, 0.5, 0.5)
    else
        editBox:SetTextColor(1, 1, 1)
        
        -- Slider updates editbox
        slider:SetScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            config[key] = value
            if not editBox:HasFocus() then
                editBox:SetText(tostring(value))
            end
            self_ref:SaveSettings()
            self_ref:RefreshAllNameplates()
            self_ref:RefreshAllSimulations()
        end)
        
        -- Editbox updates slider
        editBox:SetScript("OnEnterPressed", function(self)
            local value = tonumber(self:GetText())
            if value then
                value = math.max(minVal, math.min(maxVal, value))
                value = math.floor(value / step + 0.5) * step
                config[key] = value
                slider:SetValue(value)
                self:SetText(tostring(value))
                self_ref:SaveSettings()
                self_ref:RefreshAllNameplates()
                self_ref:RefreshAllSimulations()
            else
                self:SetText(tostring(config[key] or minVal))
            end
            self:ClearFocus()
        end)
        
        editBox:SetScript("OnEscapePressed", function(self)
            self:SetText(tostring(config[key] or minVal))
            self:ClearFocus()
        end)
    end
    
    return yOffset - 28
end

-- ============================================================================
-- VISIBILITY TAB
-- ============================================================================

function Nameplates:BuildVisibilityTab(content, configKey, disabled)
    local yOffset = -5
    local isEnemy = (configKey == "enemy")
    
    yOffset = self:CreateHeader(content, yOffset, "General")
    yOffset = self:CreateCVarCheckbox(content, "Always Show Nameplates", yOffset, "nameplateShowAll", disabled)
    yOffset = self:CreateCVarCheckbox(content, "Keep Target On Screen", yOffset, "clampTargetNameplateToScreen", disabled)
    
    if isEnemy then
        yOffset = self:CreateHeader(content, yOffset - 10, "Enemy Units")
        yOffset = self:CreateCVarCheckbox(content, "Show Enemy Players", yOffset, "nameplateShowEnemies", disabled)
        yOffset = self:CreateCVarCheckbox(content, "Show Minions", yOffset, "nameplateShowEnemyMinions", disabled)
        yOffset = self:CreateCVarCheckbox(content, "Show Guardians", yOffset, "nameplateShowEnemyGuardians", disabled)
        yOffset = self:CreateCVarCheckbox(content, "Show Minor Enemies", yOffset, "nameplateShowEnemyMinus", disabled)
        yOffset = self:CreateCVarCheckbox(content, "Show Pets", yOffset, "nameplateShowEnemyPets", disabled)
        yOffset = self:CreateCVarCheckbox(content, "Show Totems", yOffset, "nameplateShowEnemyTotems", disabled)
    else
        yOffset = self:CreateHeader(content, yOffset - 10, "Friendly Units")
        yOffset = self:CreateCVarCheckbox(content, "Show Friendly Players", yOffset, "nameplateShowFriends", disabled)
        yOffset = self:CreateCVarCheckbox(content, "Show Friendly NPCs", yOffset, "nameplateShowFriendlyNPCs", disabled)
        yOffset = self:CreateCVarCheckbox(content, "Show Debuffs", yOffset, "nameplateShowDebuffsOnFriendly", disabled)
    end
end

-- ============================================================================
-- SCALE TAB
-- ============================================================================

function Nameplates:BuildScaleTab(content, configKey, disabled)
    local settings = self.State.settings
    local config = settings[configKey].healthBar
    local self_ref = self
    local yOffset = -5
    
    yOffset = self:CreateHeader(content, yOffset, "Health Bar Size")
    yOffset = self:CreateHealthBarSlider(content, yOffset, config, "width", "Width:", 60, 250, 2, disabled)
    yOffset = self:CreateHealthBarSlider(content, yOffset, config, "height", "Height:", 4, 40, 1, disabled)
    
    -- Target scale section (replaces target width/height with a scale %)
    yOffset = self:CreateHeader(content, yOffset - 10, "Target Scale (when targeted)")
    
    local targetInfoText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    targetInfoText:SetPoint("TOPLEFT", 10, yOffset)
    targetInfoText:SetText("Scale multiplier when targeted (100 = no change)")
    targetInfoText:SetTextColor(0.7, 0.7, 0.7)
    yOffset = yOffset - 16
    
    yOffset = self:CreateHealthBarSliderWithInput(content, yOffset, config, "targetScale", "Scale %:", 100, 150, 5, disabled)
    
    -- Mouseover scale section
    yOffset = self:CreateHeader(content, yOffset - 10, "Mouseover Scale")
    
    local infoText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoText:SetPoint("TOPLEFT", 10, yOffset)
    infoText:SetText("Scale multiplier when moused over (100 = no change)")
    infoText:SetTextColor(0.7, 0.7, 0.7)
    yOffset = yOffset - 16
    
    yOffset = self:CreateHealthBarSliderWithInput(content, yOffset, config, "mouseoverScale", "Scale %:", 100, 150, 5, disabled)
    
    -- Stacking settings (these ARE CVars)
    yOffset = self:CreateHeader(content, yOffset - 10, "Stacking Behavior")
    yOffset = self:CreateCVarDropdown(content, "Mode:", yOffset, "nameplateMotion", disabled)
    yOffset = self:CreateCVarSlider(content, "Stacking Speed", yOffset, "nameplateMotionSpeed", disabled)
    
    -- Distance (this IS a CVar)
    yOffset = self:CreateHeader(content, yOffset - 10, "Distance")
    yOffset = self:CreateCVarSlider(content, "Maximum Distance", yOffset, "nameplateMaxDistance", disabled)
end

-- Helper for health bar sliders WITH numeric input that call RefreshAllHealthBars
function Nameplates:CreateHealthBarSlider(content, yOffset, config, key, labelText, minVal, maxVal, step, disabled)
    local self_ref = self
    
    local container = TweaksUI.Utilities:CreateSliderWithInput(content, {
        label = labelText,
        min = minVal,
        max = maxVal,
        step = step,
        value = config[key] or minVal,
        isFloat = false,
        width = 200,
        labelWidth = 55,
        valueWidth = 50,
        onValueChanged = function(value)
            config[key] = value
            self_ref:SaveSettings()
            self_ref:RefreshAllHealthBars()
        end,
    })
    container:SetPoint("TOPLEFT", 10, yOffset)
    
    if disabled then
        container:SetEnabled(false)
    end
    
    return yOffset - 28
end

-- Helper for health bar sliders WITH manual input that call RefreshAllHealthBars
function Nameplates:CreateHealthBarSliderWithInput(content, yOffset, config, key, labelText, minVal, maxVal, step, disabled)
    local self_ref = self
    
    local container = TweaksUI.Utilities:CreateSliderWithInput(content, {
        label = labelText,
        min = minVal,
        max = maxVal,
        step = step,
        value = config[key] or minVal,
        isFloat = false,
        width = 200,
        labelWidth = 60,
        valueWidth = 45,
        formatStr = "%d%%",
        onValueChanged = function(value)
            config[key] = value
            self_ref:SaveSettings()
            self_ref:RefreshAllHealthBars()
        end,
    })
    container:SetPoint("TOPLEFT", 10, yOffset)
    
    if disabled then
        container:SetEnabled(false)
    end
    
    return yOffset - 32
end

-- ============================================================================
-- ALPHA TAB
-- ============================================================================

function Nameplates:BuildAlphaTab(content, configKey, disabled)
    local settings = self.State.settings
    local config = settings[configKey].healthBar
    local self_ref = self
    local yOffset = -5
    
    yOffset = self:CreateHeader(content, yOffset, "Health Bar Opacity")
    yOffset = self:CreateAlphaSlider(content, yOffset, config, "alpha", "Base Opacity:", 0.1, 1.0, disabled)
    yOffset = self:CreateAlphaSlider(content, yOffset, config, "targetAlpha", "Target Opacity:", 0.1, 1.0, disabled)
    yOffset = self:CreateAlphaSlider(content, yOffset, config, "occludedAlpha", "Behind Walls:", 0, 1.0, disabled)
end

-- Helper for alpha/opacity sliders WITH numeric input (displays as percentage)
function Nameplates:CreateAlphaSlider(content, yOffset, config, key, labelText, minVal, maxVal, disabled)
    local self_ref = self
    
    -- Convert 0-1 to 0-100% for display
    local container = TweaksUI.Utilities:CreateSliderWithInput(content, {
        label = labelText,
        min = math.floor(minVal * 100),
        max = math.floor(maxVal * 100),
        step = 5,
        value = math.floor((config[key] or 1) * 100),
        isFloat = false,
        width = 180,
        labelWidth = 100,
        valueWidth = 45,
        formatStr = "%d%%",
        onValueChanged = function(value)
            config[key] = value / 100  -- Convert back to 0-1
            self_ref:SaveSettings()
            self_ref:RefreshAllHealthBars()
        end,
    })
    container:SetPoint("TOPLEFT", 10, yOffset)
    
    if disabled then
        container:SetEnabled(false)
    end
    
    return yOffset - 28
end

-- ============================================================================
-- UI HELPERS FOR TABS
-- ============================================================================

function Nameplates:CreateTextureDropdown(content, yOffset, config, disabled)
    local self_ref = self
    
    local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 10, yOffset)
    label:SetText("Texture:")
    label:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
    
    local dropdown = CreateFrame("Frame", nil, content, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", 60, yOffset + 5)
    UIDropDownMenu_SetWidth(dropdown, 180)
    UIDropDownMenu_SetText(dropdown, config.texture or "Blizzard")
    
    if disabled then
        UIDropDownMenu_DisableDropDown(dropdown)
    else
        UIDropDownMenu_Initialize(dropdown, function()
            local textures = self_ref:GetTextureList()
            for _, name in ipairs(textures) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = name
                info.checked = config.texture == name
                info.func = function()
                    config.texture = name
                    UIDropDownMenu_SetText(dropdown, name)
                    self_ref:SaveSettings()
                    self_ref:RefreshAllHealthBars()
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
    end
    
    return yOffset - 32
end

-- Cast bar specific texture dropdown
function Nameplates:CreateCastBarTextureDropdown(content, yOffset, config, disabled)
    local self_ref = self
    
    local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 10, yOffset)
    label:SetText("Texture:")
    label:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
    
    local dropdown = CreateFrame("Frame", nil, content, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", 60, yOffset + 5)
    UIDropDownMenu_SetWidth(dropdown, 180)
    UIDropDownMenu_SetText(dropdown, config.texture or "Blizzard")
    
    if disabled then
        UIDropDownMenu_DisableDropDown(dropdown)
    else
        UIDropDownMenu_Initialize(dropdown, function()
            local textures = self_ref:GetTextureList()
            for _, name in ipairs(textures) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = name
                info.checked = config.texture == name
                info.func = function()
                    config.texture = name
                    UIDropDownMenu_SetText(dropdown, name)
                    self_ref:SaveSettings()
                    self_ref:RefreshAllCastBars()
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
    end
    
    return yOffset - 32
end

function Nameplates:CreateColorModeDropdown(content, yOffset, config, disabled)
    local self_ref = self
    local COLOR_MODES = {
        { value = "class", text = "Class Color" },
        { value = "reaction", text = "Reaction Color" },
        { value = "health", text = "Health Gradient" },
        { value = "threat", text = "Threat Color" },
        { value = "custom", text = "Custom Color" },
    }
    
    local function GetColorModeText(mode)
        for _, opt in ipairs(COLOR_MODES) do
            if opt.value == mode then return opt.text end
        end
        return "Reaction Color"
    end
    
    local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 10, yOffset)
    label:SetText("Color Mode:")
    label:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
    
    local dropdown = CreateFrame("Frame", nil, content, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", 80, yOffset + 5)
    UIDropDownMenu_SetWidth(dropdown, 140)
    UIDropDownMenu_SetText(dropdown, GetColorModeText(config.colorMode))
    
    if disabled then
        UIDropDownMenu_DisableDropDown(dropdown)
    else
        UIDropDownMenu_Initialize(dropdown, function()
            for _, opt in ipairs(COLOR_MODES) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = opt.text
                info.checked = config.colorMode == opt.value
                info.func = function()
                    config.colorMode = opt.value
                    UIDropDownMenu_SetText(dropdown, opt.text)
                    self_ref:SaveSettings()
                    self_ref:RefreshAllHealthBars()
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
    end
    
    return yOffset - 32
end

function Nameplates:CreateCustomColorPicker(content, yOffset, config, colorKey, labelText, disabled)
    local self_ref = self
    local c = config[colorKey] or {1, 1, 1, 1}
    
    local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 10, yOffset)
    label:SetText(labelText)
    label:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
    
    local btn = CreateFrame("Button", nil, content)
    btn:SetSize(24, 24)
    btn:SetPoint("TOPLEFT", 100, yOffset + 4)
    
    local border = btn:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0.3, 0.3, 0.3, 1)
    
    local swatch = btn:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("TOPLEFT", 2, -2)
    swatch:SetPoint("BOTTOMRIGHT", -2, 2)
    swatch:SetColorTexture(c[1], c[2], c[3], 1)
    
    if disabled then
        btn:Disable()
        btn:SetAlpha(0.5)
    else
        btn:SetScript("OnClick", function()
            ColorPickerFrame:SetupColorPickerAndShow({
                r = c[1], g = c[2], b = c[3],
                hasOpacity = true,
                opacity = c[4] or 1,
                swatchFunc = function()
                    local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                    config[colorKey][1], config[colorKey][2], config[colorKey][3] = nr, ng, nb
                    swatch:SetColorTexture(nr, ng, nb, 1)
                    self_ref:SaveSettings()
                    self_ref:RefreshAllHealthBars()
                end,
                opacityFunc = function()
                    config[colorKey][4] = ColorPickerFrame:GetColorAlpha()
                    self_ref:SaveSettings()
                    self_ref:RefreshAllHealthBars()
                end,
                cancelFunc = function(prev)
                    config[colorKey][1], config[colorKey][2], config[colorKey][3], config[colorKey][4] = prev.r, prev.g, prev.b, prev.opacity
                    swatch:SetColorTexture(prev.r, prev.g, prev.b, 1)
                    self_ref:SaveSettings()
                    self_ref:RefreshAllHealthBars()
                end,
            })
        end)
    end
    
    return yOffset - 30
end

function Nameplates:CreateToggleWithColor(content, yOffset, config, toggleKey, colorKey, labelText, disabled)
    local self_ref = self
    local c = config[colorKey] or {0.1, 0.1, 0.1, 0.8}
    
    local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 10, yOffset)
    cb:SetSize(22, 22)
    cb:SetChecked(config[toggleKey])
    
    local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    label:SetText(labelText)
    
    local btn = CreateFrame("Button", nil, content)
    btn:SetSize(24, 24)
    btn:SetPoint("TOPLEFT", 180, yOffset + 1)
    
    local border = btn:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0.3, 0.3, 0.3, 1)
    
    local swatch = btn:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("TOPLEFT", 2, -2)
    swatch:SetPoint("BOTTOMRIGHT", -2, 2)
    swatch:SetColorTexture(c[1], c[2], c[3], 1)
    
    if disabled then
        cb:Disable()
        btn:Disable()
        label:SetTextColor(0.5, 0.5, 0.5)
        btn:SetAlpha(0.5)
    else
        label:SetTextColor(0.9, 0.9, 0.9)
        cb:SetScript("OnClick", function(self)
            config[toggleKey] = self:GetChecked()
            self_ref:SaveSettings()
            self_ref:RefreshAllHealthBars()
        end)
        btn:SetScript("OnClick", function()
            ColorPickerFrame:SetupColorPickerAndShow({
                r = c[1], g = c[2], b = c[3],
                hasOpacity = true,
                opacity = c[4] or 0.8,
                swatchFunc = function()
                    local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                    config[colorKey][1], config[colorKey][2], config[colorKey][3] = nr, ng, nb
                    swatch:SetColorTexture(nr, ng, nb, 1)
                    self_ref:SaveSettings()
                    self_ref:RefreshAllHealthBars()
                end,
                opacityFunc = function()
                    config[colorKey][4] = ColorPickerFrame:GetColorAlpha()
                    self_ref:SaveSettings()
                    self_ref:RefreshAllHealthBars()
                end,
                cancelFunc = function(prev)
                    config[colorKey][1], config[colorKey][2], config[colorKey][3], config[colorKey][4] = prev.r, prev.g, prev.b, prev.opacity
                    swatch:SetColorTexture(prev.r, prev.g, prev.b, 1)
                    self_ref:SaveSettings()
                    self_ref:RefreshAllHealthBars()
                end,
            })
        end)
    end
    
    return yOffset - 26
end

function Nameplates:CreateBorderSizeSlider(content, yOffset, config, disabled)
    local self_ref = self
    
    local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 10, yOffset)
    label:SetText("Border Size:")
    label:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
    
    local valText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    valText:SetPoint("TOPLEFT", 280, yOffset)
    valText:SetText(tostring(config.borderSize or 1))
    valText:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
    
    local slider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 10, yOffset - 18)
    slider:SetSize(260, 17)
    slider:SetMinMaxValues(1, 5)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(config.borderSize or 1)
    slider.Low:SetText("1")
    slider.High:SetText("5")
    slider.Text:SetText("")
    
    if disabled then
        slider:Disable()
        slider:SetAlpha(0.5)
    else
        slider:SetScript("OnValueChanged", function(self, value)
            config.borderSize = math.floor(value)
            valText:SetText(tostring(config.borderSize))
            self_ref:SaveSettings()
            self_ref:RefreshAllHealthBars()
        end)
    end
    
    return yOffset - 40
end

-- ============================================================================
-- PANEL CREATION ENTRY POINTS
-- ============================================================================

function Nameplates:CreateEnemyPanel()
    return self:CreateTabbedPanel("EnemyNameplates", "Enemy Nameplates", "enemy", ENEMY_TABS)
end

function Nameplates:CreateFriendlyPanel()
    return self:CreateTabbedPanel("FriendlyNameplates", "Friendly Nameplates", "friendly", FRIENDLY_TABS)
end
