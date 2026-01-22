-- ============================================================================
-- TweaksUI: Nameplates Module - UI Helpers
-- Common UI creation functions for panels
-- ============================================================================

local ADDON_NAME, TweaksUI = ...
local Nameplates = TweaksUI.Nameplates

-- ============================================================================
-- INFO TOOLTIP
-- ============================================================================

function Nameplates:CreateInfoTooltip()
    if self.State.infoTooltip then return end
    
    local tooltip = CreateFrame("Frame", "TweaksUI_Nameplates_InfoTooltip", UIParent, "BackdropTemplate")
    tooltip:SetSize(220, 80)
    tooltip:SetFrameStrata("TOOLTIP")
    tooltip:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    tooltip:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    tooltip:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    tooltip:Hide()
    
    local text = tooltip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("TOPLEFT", 8, -8)
    text:SetPoint("BOTTOMRIGHT", -8, 8)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetWordWrap(true)
    tooltip.text = text
    
    self.State.infoTooltip = tooltip
end

function Nameplates:ShowInfoTooltip(anchor, desc)
    self:CreateInfoTooltip()
    self.State.infoTooltip.text:SetText(desc)
    local height = math.max(50, self.State.infoTooltip.text:GetStringHeight() + 16)
    self.State.infoTooltip:SetHeight(height)
    self.State.infoTooltip:ClearAllPoints()
    self.State.infoTooltip:SetPoint("LEFT", anchor, "RIGHT", 8, 0)
    self.State.infoTooltip:Show()
end

function Nameplates:HideInfoTooltip()
    if self.State.infoTooltip then self.State.infoTooltip:Hide() end
end

-- ============================================================================
-- HEADER CREATION
-- ============================================================================

function Nameplates:CreateHeader(parent, yOffset, text)
    yOffset = yOffset - 8
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 5, yOffset)
    header:SetText(text)
    header:SetTextColor(1, 0.82, 0)
    return yOffset - 20
end

-- ============================================================================
-- INFO BUTTON
-- ============================================================================

function Nameplates:CreateInfoButton(parent, cvar, xOffset, yOffset)
    local info = self.CVarInfo[cvar]
    if not info or not info.desc then return end
    
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(16, 16)
    btn:SetPoint("TOPLEFT", xOffset, yOffset + 3)
    
    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER")
    text:SetText("?")
    text:SetTextColor(0.6, 0.6, 0.6)
    btn.text = text
    
    local self_ref = self
    btn:SetScript("OnEnter", function(self)
        self.text:SetTextColor(1, 0.82, 0)
        self_ref:ShowInfoTooltip(self, info.desc)
    end)
    btn:SetScript("OnLeave", function(self)
        self.text:SetTextColor(0.6, 0.6, 0.6)
        self_ref:HideInfoTooltip()
    end)
end

-- ============================================================================
-- CVAR CHECKBOX
-- ============================================================================

function Nameplates:CreateCVarCheckbox(parent, label, yOffset, cvar, disabled)
    local PANEL_WIDTH = self.Constants.PANEL_WIDTH
    local settings = self.State.settings
    
    -- Check if CVar exists - if not, skip entirely (don't take up space)
    local currentValue = GetCVar(cvar)
    if currentValue == nil then
        return yOffset  -- Return same yOffset, don't advance
    end
    
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 10, yOffset)
    cb:SetSize(22, 22)
    
    -- Read current value from WoW's CVar
    local isChecked = currentValue == "1" or currentValue == 1 or currentValue == true
    cb:SetChecked(isChecked)
    
    local labelText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    labelText:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    labelText:SetText(label)
    
    if disabled then
        cb:Disable()
        labelText:SetTextColor(0.5, 0.5, 0.5)
    else
        labelText:SetTextColor(0.9, 0.9, 0.9)
        local self_ref = self
        cb:SetScript("OnClick", function(self)
            local checked = self:GetChecked()
            -- Apply directly to WoW's CVar
            SetCVar(cvar, checked and "1" or "0")
            -- Also save to our settings
            if settings.cvars then
                settings.cvars[cvar] = checked
            end
            self_ref:SaveSettings()
        end)
    end
    
    self:CreateInfoButton(parent, cvar, PANEL_WIDTH - 55, yOffset)
    return yOffset - 24
end

-- ============================================================================
-- CVAR SLIDER
-- ============================================================================

function Nameplates:CreateCVarSlider(parent, label, yOffset, cvar, disabled)
    local PANEL_WIDTH = self.Constants.PANEL_WIDTH
    local settings = self.State.settings
    local info = self.CVarInfo[cvar]
    local formatStr = info.format or "%.2f"
    local isFloat = info.step < 1
    
    local labelText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    labelText:SetPoint("TOPLEFT", 10, yOffset)
    labelText:SetText(label)
    labelText:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
    
    self:CreateInfoButton(parent, cvar, PANEL_WIDTH - 55, yOffset)
    yOffset = yOffset - 16
    
    -- Use the centralized slider with input helper
    local container = TweaksUI.Utilities:CreateSliderWithInput(parent, {
        min = info.min,
        max = info.max,
        step = info.step,
        value = settings.cvars[cvar] or info.default,
        isFloat = isFloat,
        decimals = 2,
        width = PANEL_WIDTH - 130,
        valueWidth = 50,
        onValueChanged = function(value)
            if not disabled then
                self:SetCVarValue(cvar, value)
            end
        end,
    })
    container:SetPoint("TOPLEFT", 10, yOffset)
    
    if disabled then
        container:SetEnabled(false)
    end
    
    return yOffset - 28
end

-- ============================================================================
-- CVAR DROPDOWN
-- ============================================================================

function Nameplates:CreateCVarDropdown(parent, label, yOffset, cvar, disabled)
    local PANEL_WIDTH = self.Constants.PANEL_WIDTH
    local settings = self.State.settings
    local info = self.CVarInfo[cvar]
    
    local labelText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    labelText:SetPoint("TOPLEFT", 10, yOffset)
    labelText:SetText(label)
    labelText:SetTextColor(disabled and 0.5 or 0.9, disabled and 0.5 or 0.9, disabled and 0.5 or 0.9)
    
    self:CreateInfoButton(parent, cvar, PANEL_WIDTH - 55, yOffset)
    
    local dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", 100, yOffset + 5)
    UIDropDownMenu_SetWidth(dropdown, 130)
    
    local function GetDisplayText()
        local val = settings.cvars[cvar]
        for _, opt in ipairs(info.options) do
            if opt.value == val then return opt.text end
        end
        return "Unknown"
    end
    
    UIDropDownMenu_SetText(dropdown, GetDisplayText())
    
    if disabled then
        UIDropDownMenu_DisableDropDown(dropdown)
    else
        local self_ref = self
        UIDropDownMenu_Initialize(dropdown, function()
            for _, opt in ipairs(info.options) do
                local menuInfo = UIDropDownMenu_CreateInfo()
                menuInfo.text = opt.text
                menuInfo.checked = settings.cvars[cvar] == opt.value
                menuInfo.func = function()
                    self_ref:SetCVarValue(cvar, opt.value)
                    UIDropDownMenu_SetText(dropdown, opt.text)
                end
                UIDropDownMenu_AddButton(menuInfo)
            end
        end)
    end
    
    return yOffset - 32
end

-- ============================================================================
-- PANEL FRAME CREATION
-- ============================================================================

function Nameplates:CreatePanelFrame(panelKey, displayName, height)
    local darkBackdrop = self.Constants.darkBackdrop
    local PANEL_WIDTH = self.Constants.PANEL_WIDTH
    
    local panel = CreateFrame("Frame", "TweaksUI_Nameplates_" .. panelKey .. "_Panel", UIParent, "BackdropTemplate")
    panel:SetSize(PANEL_WIDTH, height)
    panel:SetPoint("TOPLEFT", self.State.nameplatesHub, "TOPRIGHT", 0, 0)
    panel:SetBackdrop(darkBackdrop)
    panel:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    panel:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    panel:SetFrameStrata("DIALOG")
    
    self.State.settingsPanels[panelKey] = panel
    
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText(displayName)
    title:SetTextColor(1, 0.82, 0)
    
    local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function()
        panel:Hide()
        self.State.currentOpenPanel = nil
    end)
    
    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 10)
    
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(PANEL_WIDTH - 50, 800)
    scrollFrame:SetScrollChild(content)
    
    panel:Hide()
    return panel, content
end
