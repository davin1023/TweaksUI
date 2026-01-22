-- ============================================================================
-- TweaksUI: Nameplates Module - Panels
-- Settings panels with user-friendly labels (no CVar terminology)
-- ============================================================================

local ADDON_NAME, TweaksUI = ...
local Nameplates = TweaksUI.Nameplates

-- ============================================================================
-- MAIN PANEL ROUTER
-- ============================================================================

function Nameplates:CreatePanel(panelName)
    local disabled = self:IsNameplateAddonActive()
    
    if panelName == "EnemyNameplates" then
        self:CreateEnemyPanel()
    elseif panelName == "FriendlyNameplates" then
        self:CreateFriendlyPanel()
    elseif panelName == "Highlights" then
        self:CreateHighlightsPanel(disabled)
    -- Legacy panel names (redirect to new tabbed panels)
    elseif panelName == "EnemyHealthBar" then
        self:CreateEnemyPanel()
    elseif panelName == "FriendlyHealthBar" then
        self:CreateFriendlyPanel()
    end
end

-- ============================================================================
-- DISABLED NOTICE HELPER
-- ============================================================================

local function CreateDisabledNotice(content, yOffset, PANEL_WIDTH)
    local notice = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    notice:SetPoint("TOPLEFT", 10, yOffset)
    notice:SetWidth(PANEL_WIDTH - 70)
    notice:SetJustifyH("LEFT")
    notice:SetText("|cffff6600These settings are disabled|r because Platynator or Plater is managing your nameplates.")
    notice:SetWordWrap(true)
    notice:SetTextColor(1, 0.6, 0)
    return yOffset - notice:GetStringHeight() - 10
end

-- ============================================================================
-- VISIBILITY PANEL
-- ============================================================================

function Nameplates:CreateVisibilityPanel(disabled)
    local PANEL_WIDTH = self.Constants.PANEL_WIDTH
    local panel, content = self:CreatePanelFrame("Visibility", "Visibility", 480)
    local yOffset = -5
    
    if disabled then
        yOffset = CreateDisabledNotice(content, yOffset, PANEL_WIDTH)
    end
    
    -- General
    yOffset = self:CreateHeader(content, yOffset, "General")
    yOffset = self:CreateCVarCheckbox(content, "Always Show Nameplates", yOffset, "nameplateShowAll", disabled)
    yOffset = self:CreateCVarCheckbox(content, "Keep Target Nameplate On Screen", yOffset, "clampTargetNameplateToScreen", disabled)
    
    -- Friendly Units
    yOffset = self:CreateHeader(content, yOffset - 10, "Friendly Units")
    yOffset = self:CreateCVarCheckbox(content, "Show Friendly Players", yOffset, "nameplateShowFriends", disabled)
    yOffset = self:CreateCVarCheckbox(content, "Show Friendly NPCs", yOffset, "nameplateShowFriendlyNPCs", disabled)
    yOffset = self:CreateCVarCheckbox(content, "Show Debuffs on Friendly", yOffset, "nameplateShowDebuffsOnFriendly", disabled)
    
    -- Enemy Units
    yOffset = self:CreateHeader(content, yOffset - 10, "Enemy Units")
    yOffset = self:CreateCVarCheckbox(content, "Show Enemy Players", yOffset, "nameplateShowEnemies", disabled)
    yOffset = self:CreateCVarCheckbox(content, "Show Enemy Minions", yOffset, "nameplateShowEnemyMinions", disabled)
    yOffset = self:CreateCVarCheckbox(content, "Show Enemy Guardians", yOffset, "nameplateShowEnemyGuardians", disabled)
    yOffset = self:CreateCVarCheckbox(content, "Show Minor Enemies", yOffset, "nameplateShowEnemyMinus", disabled)
    yOffset = self:CreateCVarCheckbox(content, "Show Enemy Pets", yOffset, "nameplateShowEnemyPets", disabled)
    yOffset = self:CreateCVarCheckbox(content, "Show Enemy Totems", yOffset, "nameplateShowEnemyTotems", disabled)
end

-- ============================================================================
-- STACKING PANEL
-- ============================================================================

function Nameplates:CreateStackingPanel(disabled)
    local PANEL_WIDTH = self.Constants.PANEL_WIDTH
    local panel, content = self:CreatePanelFrame("Stacking", "Stacking & Distance", 380)
    local yOffset = -5
    
    if disabled then
        yOffset = CreateDisabledNotice(content, yOffset, PANEL_WIDTH)
    end
    
    -- Stacking Behavior
    yOffset = self:CreateHeader(content, yOffset, "Stacking Behavior")
    yOffset = self:CreateCVarDropdown(content, "Mode:", yOffset, "nameplateMotion", disabled)
    yOffset = self:CreateCVarSlider(content, "Stacking Speed", yOffset, "nameplateMotionSpeed", disabled)
    yOffset = self:CreateCVarSlider(content, "Horizontal Spacing", yOffset, "nameplateOverlapH", disabled)
    yOffset = self:CreateCVarSlider(content, "Vertical Spacing", yOffset, "nameplateOverlapV", disabled)
    
    -- Distance
    yOffset = self:CreateHeader(content, yOffset - 10, "Distance")
    yOffset = self:CreateCVarSlider(content, "Maximum Distance", yOffset, "nameplateMaxDistance", disabled)
    yOffset = self:CreateCVarSlider(content, "Target Behind Distance", yOffset, "nameplateTargetBehindMaxDistance", disabled)
end

-- ============================================================================
-- SCALE PANEL
-- ============================================================================

function Nameplates:CreateScalePanel(disabled)
    local PANEL_WIDTH = self.Constants.PANEL_WIDTH
    local panel, content = self:CreatePanelFrame("Scale", "Scale", 520)
    local yOffset = -5
    
    if disabled then
        yOffset = CreateDisabledNotice(content, yOffset, PANEL_WIDTH)
    end
    
    -- Global Scale
    yOffset = self:CreateHeader(content, yOffset, "Global Scale")
    yOffset = self:CreateCVarSlider(content, "Overall Scale", yOffset, "nameplateGlobalScale", disabled)
    yOffset = self:CreateCVarSlider(content, "Width Scale", yOffset, "NamePlateHorizontalScale", disabled)
    yOffset = self:CreateCVarSlider(content, "Height Scale", yOffset, "NamePlateVerticalScale", disabled)
    
    -- Distance-Based Scale
    yOffset = self:CreateHeader(content, yOffset - 10, "Distance-Based Scale")
    yOffset = self:CreateCVarSlider(content, "Min Scale (Far Away)", yOffset, "nameplateMinScale", disabled)
    yOffset = self:CreateCVarSlider(content, "Max Scale (Close Up)", yOffset, "nameplateMaxScale", disabled)
    yOffset = self:CreateCVarSlider(content, "Far Distance", yOffset, "nameplateMinScaleDistance", disabled)
    yOffset = self:CreateCVarSlider(content, "Close Distance", yOffset, "nameplateMaxScaleDistance", disabled)
    
    -- Special Scale
    yOffset = self:CreateHeader(content, yOffset - 10, "Special Scale")
    yOffset = self:CreateCVarSlider(content, "Target Scale", yOffset, "nameplateSelectedScale", disabled)
    yOffset = self:CreateCVarSlider(content, "Boss Scale", yOffset, "nameplateLargerScale", disabled)
end

-- ============================================================================
-- ALPHA PANEL
-- ============================================================================

function Nameplates:CreateAlphaPanel(disabled)
    local PANEL_WIDTH = self.Constants.PANEL_WIDTH
    local panel, content = self:CreatePanelFrame("Alpha", "Transparency", 400)
    local yOffset = -5
    
    if disabled then
        yOffset = CreateDisabledNotice(content, yOffset, PANEL_WIDTH)
    end
    
    -- Distance-Based Transparency
    yOffset = self:CreateHeader(content, yOffset, "Distance-Based Transparency")
    yOffset = self:CreateCVarSlider(content, "Min Opacity (Far Away)", yOffset, "nameplateMinAlpha", disabled)
    yOffset = self:CreateCVarSlider(content, "Max Opacity (Close Up)", yOffset, "nameplateMaxAlpha", disabled)
    yOffset = self:CreateCVarSlider(content, "Far Distance", yOffset, "nameplateMinAlphaDistance", disabled)
    yOffset = self:CreateCVarSlider(content, "Close Distance", yOffset, "nameplateMaxAlphaDistance", disabled)
    
    -- Special Transparency
    yOffset = self:CreateHeader(content, yOffset - 10, "Special Transparency")
    yOffset = self:CreateCVarSlider(content, "Target Opacity", yOffset, "nameplateSelectedAlpha", disabled)
    yOffset = self:CreateCVarSlider(content, "Behind Walls Opacity", yOffset, "nameplateOccludedAlphaMult", disabled)
end

-- ============================================================================
-- HIGHLIGHTS PANEL
-- ============================================================================

function Nameplates:CreateHighlightsPanel(disabled)
    local PANEL_WIDTH = self.Constants.PANEL_WIDTH
    local settings = self.State.settings
    local panel, content = self:CreatePanelFrame("Highlights", "Target/Focus Highlights", 420)
    local yOffset = -5
    
    if disabled then
        yOffset = CreateDisabledNotice(content, yOffset, PANEL_WIDTH)
    end
    
    local self_ref = self
    
    local function CreateHighlightSection(title, hs)
        yOffset = self_ref:CreateHeader(content, yOffset, title)
        
        -- Enable checkbox
        local enableCb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        enableCb:SetPoint("TOPLEFT", 10, yOffset)
        enableCb:SetSize(22, 22)
        enableCb:SetChecked(hs.enabled)
        
        local enableLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        enableLabel:SetPoint("LEFT", enableCb, "RIGHT", 4, 0)
        enableLabel:SetText("Enable")
        
        if disabled then
            enableCb:Disable()
            enableLabel:SetTextColor(0.5, 0.5, 0.5)
        else
            enableLabel:SetTextColor(0.9, 0.9, 0.9)
            enableCb:SetScript("OnClick", function(self)
                hs.enabled = self:GetChecked()
                self_ref:SaveSettings()
                self_ref:RefreshAllHighlights()
            end)
        end
        yOffset = yOffset - 26
        
        -- Style dropdown
        local styleLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        styleLabel:SetPoint("TOPLEFT", 10, yOffset)
        styleLabel:SetText("Style:")
        styleLabel:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
        
        local styleDropdown = CreateFrame("Frame", nil, content, "UIDropDownMenuTemplate")
        styleDropdown:SetPoint("TOPLEFT", 50, yOffset + 5)
        UIDropDownMenu_SetWidth(styleDropdown, 100)
        UIDropDownMenu_SetText(styleDropdown, hs.style == "glow" and "Glow" or "Border")
        
        if disabled then
            UIDropDownMenu_DisableDropDown(styleDropdown)
        else
            UIDropDownMenu_Initialize(styleDropdown, function()
                local styles = { {text = "Glow", value = "glow"}, {text = "Border", value = "border"} }
                for _, opt in ipairs(styles) do
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = opt.text
                    info.checked = hs.style == opt.value
                    info.func = function()
                        hs.style = opt.value
                        UIDropDownMenu_SetText(styleDropdown, opt.text)
                        self_ref:SaveSettings()
                        self_ref:RefreshAllHighlights()
                    end
                    UIDropDownMenu_AddButton(info)
                end
            end)
        end
        yOffset = yOffset - 28
        
        -- Color picker
        local colorLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        colorLabel:SetPoint("TOPLEFT", 10, yOffset)
        colorLabel:SetText("Color:")
        colorLabel:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
        
        local colorBtn = CreateFrame("Button", nil, content)
        colorBtn:SetSize(24, 24)
        colorBtn:SetPoint("TOPLEFT", 50, yOffset + 4)
        
        local colorBorder = colorBtn:CreateTexture(nil, "BACKGROUND")
        colorBorder:SetAllPoints()
        colorBorder:SetColorTexture(0.3, 0.3, 0.3, 1)
        
        local colorSwatch = colorBtn:CreateTexture(nil, "ARTWORK")
        colorSwatch:SetPoint("TOPLEFT", 2, -2)
        colorSwatch:SetPoint("BOTTOMRIGHT", -2, 2)
        colorSwatch:SetColorTexture(hs.color[1], hs.color[2], hs.color[3], 1)
        
        if disabled then
            colorBtn:Disable()
            colorBtn:SetAlpha(0.5)
        else
            colorBtn:SetScript("OnClick", function()
                ColorPickerFrame:SetupColorPickerAndShow({
                    r = hs.color[1], g = hs.color[2], b = hs.color[3],
                    hasOpacity = true,
                    opacity = hs.color[4] or 0.6,
                    swatchFunc = function()
                        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                        hs.color[1], hs.color[2], hs.color[3] = nr, ng, nb
                        colorSwatch:SetColorTexture(nr, ng, nb, 1)
                        self_ref:SaveSettings()
                        self_ref:RefreshAllHighlights()
                    end,
                    opacityFunc = function()
                        hs.color[4] = ColorPickerFrame:GetColorAlpha()
                        self_ref:SaveSettings()
                        self_ref:RefreshAllHighlights()
                    end,
                    cancelFunc = function(prev)
                        hs.color[1], hs.color[2], hs.color[3], hs.color[4] = prev.r, prev.g, prev.b, prev.opacity
                        colorSwatch:SetColorTexture(prev.r, prev.g, prev.b, 1)
                        self_ref:SaveSettings()
                        self_ref:RefreshAllHighlights()
                    end,
                })
            end)
        end
        yOffset = yOffset - 28
        
        -- Thickness slider with numeric input
        local thickContainer = TweaksUI.Utilities:CreateSliderWithInput(content, {
            label = "Thickness:",
            min = 1,
            max = 10,
            step = 1,
            value = hs.thickness,
            isFloat = false,
            width = 140,
            labelWidth = 80,
            valueWidth = 35,
            onValueChanged = function(value)
                hs.thickness = value
                self_ref:SaveSettings()
                self_ref:RefreshAllHighlights()
            end,
        })
        thickContainer:SetPoint("TOPLEFT", 10, yOffset)
        
        if disabled then
            thickContainer:SetEnabled(false)
        end
        yOffset = yOffset - 35
    end
    
    CreateHighlightSection("Target Highlight", settings.targetHighlight)
    CreateHighlightSection("Focus Highlight", settings.focusHighlight)
    
    -- Initialize mouseover highlight settings if needed
    if not settings.mouseoverHighlight then
        settings.mouseoverHighlight = { enabled = false, style = "glow", color = { 0.3, 1, 0.3, 0.5 }, thickness = 2 }
    end
    CreateHighlightSection("Mouseover Highlight", settings.mouseoverHighlight)
end
