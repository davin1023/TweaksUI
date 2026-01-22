-- ============================================================================
-- TweaksUI: Nameplates Module - Health Bar Panels
-- Phase 1: Settings panels for enemy/friendly health bar customization
-- Uses colorMode dropdown matching UnitFrames module for consistency
-- ============================================================================

local ADDON_NAME, TweaksUI = ...
local Nameplates = TweaksUI.Nameplates

-- Color mode options (matching UnitFrames)
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

-- ============================================================================
-- HEALTH BAR PANEL CREATION
-- ============================================================================

function Nameplates:CreateHealthBarPanel(panelKey, displayName, configKey, disabled)
    local PANEL_WIDTH = self.Constants.PANEL_WIDTH
    local settings = self.State.settings
    local panel, content = self:CreatePanelFrame(panelKey, displayName, 480)
    local yOffset = -5
    local config = settings[configKey].healthBar
    local self_ref = self
    
    -- Disabled notice
    if disabled then
        local notice = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        notice:SetPoint("TOPLEFT", 10, yOffset)
        notice:SetWidth(PANEL_WIDTH - 70)
        notice:SetJustifyH("LEFT")
        notice:SetText("|cffff6600Settings disabled:|r Platynator or Plater is managing nameplates.")
        notice:SetWordWrap(true)
        notice:SetTextColor(1, 0.6, 0)
        yOffset = yOffset - notice:GetStringHeight() - 10
    end
    
    -- Preview section
    yOffset = self:CreateHeader(content, yOffset, "Preview")
    local simFrame = self:CreateSimulationFrame(content)
    simFrame:ClearAllPoints()
    simFrame:SetPoint("TOP", content, "TOP", 0, yOffset - 10)
    simFrame:SetSize(200, 80)
    simFrame:Show()
    self:UpdateSimulation()
    yOffset = yOffset - 90
    
    -- ========================================
    -- General section
    -- ========================================
    yOffset = self:CreateHeader(content, yOffset, "General")
    
    local enabledCb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    enabledCb:SetPoint("TOPLEFT", 10, yOffset)
    enabledCb:SetSize(22, 22)
    enabledCb:SetChecked(config.enabled)
    local enabledLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    enabledLabel:SetPoint("LEFT", enabledCb, "RIGHT", 4, 0)
    enabledLabel:SetText("Enable Health Bar Customization")
    if disabled then
        enabledCb:Disable()
        enabledLabel:SetTextColor(0.5, 0.5, 0.5)
    else
        enabledLabel:SetTextColor(0.9, 0.9, 0.9)
        enabledCb:SetScript("OnClick", function(self)
            config.enabled = self:GetChecked()
            self_ref:SaveSettings()
            self_ref:RefreshAllHealthBars()
            self_ref:UpdateSimulation()
        end)
    end
    yOffset = yOffset - 26
    
    -- ========================================
    -- Texture section
    -- ========================================
    yOffset = self:CreateHeader(content, yOffset, "Texture")
    
    -- Override global texture checkbox (only show if global texture is enabled)
    local globalEnabled = TweaksUI.Media and TweaksUI.Media:IsUsingGlobalTexture()
    if globalEnabled then
        local overrideCb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        overrideCb:SetPoint("TOPLEFT", 10, yOffset)
        overrideCb:SetSize(22, 22)
        overrideCb:SetChecked(settings.overrideGlobalTexture)
        local overrideLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        overrideLabel:SetPoint("LEFT", overrideCb, "RIGHT", 4, 0)
        overrideLabel:SetText("Use Custom Texture (Override Global)")
        
        if disabled then
            overrideCb:Disable()
            overrideLabel:SetTextColor(0.5, 0.5, 0.5)
        else
            overrideLabel:SetTextColor(0.9, 0.9, 0.9)
            overrideCb:SetScript("OnClick", function(self)
                settings.overrideGlobalTexture = self:GetChecked()
                self_ref:SaveSettings()
                self_ref:RefreshAllHealthBars()
                self_ref:UpdateSimulation()
            end)
        end
        yOffset = yOffset - 26
    end
    
    local textureLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    textureLabel:SetPoint("TOPLEFT", 10, yOffset)
    textureLabel:SetText("Bar Texture:")
    textureLabel:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
    
    local textureDropdown = CreateFrame("Frame", nil, content, "UIDropDownMenuTemplate")
    textureDropdown:SetPoint("TOPLEFT", 80, yOffset + 5)
    UIDropDownMenu_SetWidth(textureDropdown, 180)
    UIDropDownMenu_SetText(textureDropdown, config.texture or "Blizzard")
    
    if disabled then
        UIDropDownMenu_DisableDropDown(textureDropdown)
    else
        UIDropDownMenu_Initialize(textureDropdown, function()
            local textures = self_ref:GetTextureList()
            for _, name in ipairs(textures) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = name
                info.checked = config.texture == name
                info.func = function()
                    config.texture = name
                    UIDropDownMenu_SetText(textureDropdown, name)
                    self_ref:SaveSettings()
                    self_ref:RefreshAllHealthBars()
                    self_ref:UpdateSimulation()
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
    end
    yOffset = yOffset - 32
    
    -- ========================================
    -- Color section (using colorMode dropdown)
    -- ========================================
    yOffset = self:CreateHeader(content, yOffset, "Color")
    
    local colorModeLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colorModeLabel:SetPoint("TOPLEFT", 10, yOffset)
    colorModeLabel:SetText("Color Mode:")
    colorModeLabel:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
    
    local colorModeDropdown = CreateFrame("Frame", nil, content, "UIDropDownMenuTemplate")
    colorModeDropdown:SetPoint("TOPLEFT", 80, yOffset + 5)
    UIDropDownMenu_SetWidth(colorModeDropdown, 140)
    UIDropDownMenu_SetText(colorModeDropdown, GetColorModeText(config.colorMode))
    
    if disabled then
        UIDropDownMenu_DisableDropDown(colorModeDropdown)
    else
        UIDropDownMenu_Initialize(colorModeDropdown, function()
            for _, opt in ipairs(COLOR_MODES) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = opt.text
                info.checked = config.colorMode == opt.value
                info.func = function()
                    config.colorMode = opt.value
                    UIDropDownMenu_SetText(colorModeDropdown, opt.text)
                    self_ref:SaveSettings()
                    self_ref:RefreshAllHealthBars()
                    self_ref:UpdateSimulation()
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
    end
    yOffset = yOffset - 32
    
    -- Custom color picker (only used when colorMode == "custom")
    local customColorLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    customColorLabel:SetPoint("TOPLEFT", 10, yOffset)
    customColorLabel:SetText("Custom Color:")
    customColorLabel:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
    
    local colorBtn = CreateFrame("Button", nil, content)
    colorBtn:SetSize(24, 24)
    colorBtn:SetPoint("TOPLEFT", 100, yOffset + 4)
    
    local colorBorder = colorBtn:CreateTexture(nil, "BACKGROUND")
    colorBorder:SetAllPoints()
    colorBorder:SetColorTexture(0.3, 0.3, 0.3, 1)
    
    local colorSwatch = colorBtn:CreateTexture(nil, "ARTWORK")
    colorSwatch:SetPoint("TOPLEFT", 2, -2)
    colorSwatch:SetPoint("BOTTOMRIGHT", -2, 2)
    local c = config.customColor
    colorSwatch:SetColorTexture(c[1], c[2], c[3], 1)
    
    if disabled then
        colorBtn:Disable()
        colorBtn:SetAlpha(0.5)
    else
        colorBtn:SetScript("OnClick", function()
            ColorPickerFrame:SetupColorPickerAndShow({
                r = c[1], g = c[2], b = c[3],
                hasOpacity = true,
                opacity = c[4] or 1,
                swatchFunc = function()
                    local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                    config.customColor[1], config.customColor[2], config.customColor[3] = nr, ng, nb
                    colorSwatch:SetColorTexture(nr, ng, nb, 1)
                    self_ref:SaveSettings()
                    self_ref:RefreshAllHealthBars()
                    self_ref:UpdateSimulation()
                end,
                opacityFunc = function()
                    config.customColor[4] = ColorPickerFrame:GetColorAlpha()
                    self_ref:SaveSettings()
                    self_ref:RefreshAllHealthBars()
                    self_ref:UpdateSimulation()
                end,
                cancelFunc = function(prev)
                    config.customColor[1], config.customColor[2], config.customColor[3], config.customColor[4] = prev.r, prev.g, prev.b, prev.opacity
                    colorSwatch:SetColorTexture(prev.r, prev.g, prev.b, 1)
                    self_ref:SaveSettings()
                    self_ref:RefreshAllHealthBars()
                    self_ref:UpdateSimulation()
                end,
            })
        end)
    end
    yOffset = yOffset - 30
    
    -- ========================================
    -- Background section
    -- ========================================
    yOffset = self:CreateHeader(content, yOffset, "Background")
    
    local showBgCb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    showBgCb:SetPoint("TOPLEFT", 10, yOffset)
    showBgCb:SetSize(22, 22)
    showBgCb:SetChecked(config.bgEnabled)
    local showBgLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    showBgLabel:SetPoint("LEFT", showBgCb, "RIGHT", 4, 0)
    showBgLabel:SetText("Show Background")
    
    if disabled then
        showBgCb:Disable()
        showBgLabel:SetTextColor(0.5, 0.5, 0.5)
    else
        showBgLabel:SetTextColor(0.9, 0.9, 0.9)
        showBgCb:SetScript("OnClick", function(self)
            config.bgEnabled = self:GetChecked()
            self_ref:SaveSettings()
            self_ref:RefreshAllHealthBars()
            self_ref:UpdateSimulation()
        end)
    end
    yOffset = yOffset - 24
    
    -- Background color
    local bgColorLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bgColorLabel:SetPoint("TOPLEFT", 10, yOffset)
    bgColorLabel:SetText("Background Color:")
    bgColorLabel:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
    
    local bgColorBtn = CreateFrame("Button", nil, content)
    bgColorBtn:SetSize(24, 24)
    bgColorBtn:SetPoint("TOPLEFT", 120, yOffset + 4)
    
    local bgBorder = bgColorBtn:CreateTexture(nil, "BACKGROUND")
    bgBorder:SetAllPoints()
    bgBorder:SetColorTexture(0.3, 0.3, 0.3, 1)
    
    local bgSwatch = bgColorBtn:CreateTexture(nil, "ARTWORK")
    bgSwatch:SetPoint("TOPLEFT", 2, -2)
    bgSwatch:SetPoint("BOTTOMRIGHT", -2, 2)
    local bgc = config.bgColor
    bgSwatch:SetColorTexture(bgc[1], bgc[2], bgc[3], 1)
    
    if disabled then
        bgColorBtn:Disable()
        bgColorBtn:SetAlpha(0.5)
    else
        bgColorBtn:SetScript("OnClick", function()
            ColorPickerFrame:SetupColorPickerAndShow({
                r = bgc[1], g = bgc[2], b = bgc[3],
                hasOpacity = true,
                opacity = bgc[4] or 0.8,
                swatchFunc = function()
                    local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                    config.bgColor[1], config.bgColor[2], config.bgColor[3] = nr, ng, nb
                    bgSwatch:SetColorTexture(nr, ng, nb, 1)
                    self_ref:SaveSettings()
                    self_ref:RefreshAllHealthBars()
                    self_ref:UpdateSimulation()
                end,
                opacityFunc = function()
                    config.bgColor[4] = ColorPickerFrame:GetColorAlpha()
                    self_ref:SaveSettings()
                    self_ref:RefreshAllHealthBars()
                    self_ref:UpdateSimulation()
                end,
                cancelFunc = function(prev)
                    config.bgColor[1], config.bgColor[2], config.bgColor[3], config.bgColor[4] = prev.r, prev.g, prev.b, prev.opacity
                    bgSwatch:SetColorTexture(prev.r, prev.g, prev.b, 1)
                    self_ref:SaveSettings()
                    self_ref:RefreshAllHealthBars()
                    self_ref:UpdateSimulation()
                end,
            })
        end)
    end
    yOffset = yOffset - 30
    
    -- ========================================
    -- Border section
    -- ========================================
    yOffset = self:CreateHeader(content, yOffset, "Border")
    
    local showBorderCb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    showBorderCb:SetPoint("TOPLEFT", 10, yOffset)
    showBorderCb:SetSize(22, 22)
    showBorderCb:SetChecked(config.borderEnabled)
    local showBorderLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    showBorderLabel:SetPoint("LEFT", showBorderCb, "RIGHT", 4, 0)
    showBorderLabel:SetText("Show Border")
    
    if disabled then
        showBorderCb:Disable()
        showBorderLabel:SetTextColor(0.5, 0.5, 0.5)
    else
        showBorderLabel:SetTextColor(0.9, 0.9, 0.9)
        showBorderCb:SetScript("OnClick", function(self)
            config.borderEnabled = self:GetChecked()
            self_ref:SaveSettings()
            self_ref:RefreshAllHealthBars()
            self_ref:UpdateSimulation()
        end)
    end
    yOffset = yOffset - 24
    
    -- Border size slider with numeric input
    local borderContainer = TweaksUI.Utilities:CreateSliderWithInput(content, {
        label = "Border Size:",
        min = 1,
        max = 5,
        step = 1,
        value = config.borderSize or 1,
        isFloat = false,
        width = 140,
        labelWidth = 90,
        valueWidth = 35,
        onValueChanged = function(value)
            config.borderSize = value
            self_ref:SaveSettings()
            self_ref:RefreshAllHealthBars()
            self_ref:UpdateSimulation()
        end,
    })
    borderContainer:SetPoint("TOPLEFT", 10, yOffset)
    
    if disabled then
        borderContainer:SetEnabled(false)
    end
    yOffset = yOffset - 32
    
    -- Border color
    local borderColorLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    borderColorLabel:SetPoint("TOPLEFT", 10, yOffset)
    borderColorLabel:SetText("Border Color:")
    borderColorLabel:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
    
    local borderColorBtn = CreateFrame("Button", nil, content)
    borderColorBtn:SetSize(24, 24)
    borderColorBtn:SetPoint("TOPLEFT", 100, yOffset + 4)
    
    local borderBorder = borderColorBtn:CreateTexture(nil, "BACKGROUND")
    borderBorder:SetAllPoints()
    borderBorder:SetColorTexture(0.3, 0.3, 0.3, 1)
    
    local borderSwatch = borderColorBtn:CreateTexture(nil, "ARTWORK")
    borderSwatch:SetPoint("TOPLEFT", 2, -2)
    borderSwatch:SetPoint("BOTTOMRIGHT", -2, 2)
    local bc = config.borderColor
    borderSwatch:SetColorTexture(bc[1], bc[2], bc[3], 1)
    
    if disabled then
        borderColorBtn:Disable()
        borderColorBtn:SetAlpha(0.5)
    else
        borderColorBtn:SetScript("OnClick", function()
            ColorPickerFrame:SetupColorPickerAndShow({
                r = bc[1], g = bc[2], b = bc[3],
                hasOpacity = true,
                opacity = bc[4] or 1,
                swatchFunc = function()
                    local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                    config.borderColor[1], config.borderColor[2], config.borderColor[3] = nr, ng, nb
                    borderSwatch:SetColorTexture(nr, ng, nb, 1)
                    self_ref:SaveSettings()
                    self_ref:RefreshAllHealthBars()
                    self_ref:UpdateSimulation()
                end,
                opacityFunc = function()
                    config.borderColor[4] = ColorPickerFrame:GetColorAlpha()
                    self_ref:SaveSettings()
                    self_ref:RefreshAllHealthBars()
                    self_ref:UpdateSimulation()
                end,
                cancelFunc = function(prev)
                    config.borderColor[1], config.borderColor[2], config.borderColor[3], config.borderColor[4] = prev.r, prev.g, prev.b, prev.opacity
                    borderSwatch:SetColorTexture(prev.r, prev.g, prev.b, 1)
                    self_ref:SaveSettings()
                    self_ref:RefreshAllHealthBars()
                    self_ref:UpdateSimulation()
                end,
            })
        end)
    end
    yOffset = yOffset - 35
    
    -- ========================================
    -- Size section
    -- ========================================
    yOffset = self:CreateHeader(content, yOffset, "Size")
    
    -- Width slider with numeric input
    local widthContainer = TweaksUI.Utilities:CreateSliderWithInput(content, {
        label = "Width:",
        min = 60,
        max = 300,
        step = 5,
        value = config.width or 140,
        isFloat = false,
        width = 180,
        labelWidth = 50,
        valueWidth = 45,
        onValueChanged = function(value)
            config.width = value
            self_ref:SaveSettings()
            self_ref:RefreshAllHealthBars()
            self_ref:UpdateSimulation()
        end,
    })
    widthContainer:SetPoint("TOPLEFT", 10, yOffset)
    if disabled then widthContainer:SetEnabled(false) end
    yOffset = yOffset - 28
    
    -- Height slider with numeric input
    local heightContainer = TweaksUI.Utilities:CreateSliderWithInput(content, {
        label = "Height:",
        min = 4,
        max = 30,
        step = 1,
        value = config.height or 12,
        isFloat = false,
        width = 180,
        labelWidth = 50,
        valueWidth = 45,
        onValueChanged = function(value)
            config.height = value
            self_ref:SaveSettings()
            self_ref:RefreshAllHealthBars()
            self_ref:UpdateSimulation()
        end,
    })
    heightContainer:SetPoint("TOPLEFT", 10, yOffset)
    if disabled then heightContainer:SetEnabled(false) end
    yOffset = yOffset - 35
    
    -- Target Size section
    yOffset = self:CreateHeader(content, yOffset, "Target Size Increase")
    
    -- Target scale % slider
    local targetScaleContainer = TweaksUI.Utilities:CreateSliderWithInput(content, {
        label = "Scale Increase:",
        min = 0,
        max = 50,
        step = 5,
        value = config.targetScaleIncrease or 10,
        isFloat = false,
        width = 180,
        labelWidth = 95,
        valueWidth = 45,
        formatStr = "%d%%",
        onValueChanged = function(value)
            config.targetScaleIncrease = value
            self_ref:SaveSettings()
            self_ref:RefreshAllHealthBars()
            self_ref:UpdateSimulation()
        end,
    })
    targetScaleContainer:SetPoint("TOPLEFT", 10, yOffset)
    if disabled then targetScaleContainer:SetEnabled(false) end
    
    return panel, content
end
