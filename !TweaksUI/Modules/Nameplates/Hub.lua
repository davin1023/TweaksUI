-- ============================================================================
-- TweaksUI: Nameplates Module - Hub
-- Main hub panel matching UnitFrames module pattern
-- ============================================================================

local ADDON_NAME, TweaksUI = ...
local Nameplates = TweaksUI.Nameplates

-- ============================================================================
-- HUB CREATION
-- ============================================================================

function Nameplates:ShowHub(parentPanel)
    self:EnsureSettings()
    
    local HUB_WIDTH = self.Constants.HUB_WIDTH
    local BUTTON_HEIGHT = self.Constants.BUTTON_HEIGHT
    local BUTTON_SPACING = self.Constants.BUTTON_SPACING
    local darkBackdrop = self.Constants.darkBackdrop
    
    if self.State.nameplatesHub then
        self.State.nameplatesHub:ClearAllPoints()
        self.State.nameplatesHub:SetPoint("TOPLEFT", parentPanel, "TOPRIGHT", 0, 0)
        self.State.nameplatesHub:Show()
        self:UpdateAddonWarning()
        return
    end
    
    local hub = CreateFrame("Frame", "TweaksUI_Nameplates_Hub", UIParent, "BackdropTemplate")
    hub:SetSize(HUB_WIDTH, 450)  -- Increased height for preset dropdown
    hub:SetPoint("TOPLEFT", parentPanel, "TOPRIGHT", 0, 0)
    hub:SetBackdrop(darkBackdrop)
    hub:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    hub:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    hub:SetFrameStrata("DIALOG")
    
    self.State.nameplatesHub = hub
    
    local title = hub:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("Nameplates")
    title:SetTextColor(1, 0.82, 0)
    
    local closeBtn = CreateFrame("Button", nil, hub, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() self:HideAllPanels() end)
    
    hub:SetScript("OnHide", function() self:HideAllPanels() end)
    
    local yOffset = -38
    local buttonWidth = HUB_WIDTH - 20
    
    -- Add Preset Dropdown
    if TweaksUI.PresetDropdown then
        local presetContainer, nextY = TweaksUI.PresetDropdown:Create(
            hub,
            "nameplates",
            "Nameplates",
            yOffset,
            {
                width = 140,
                showSaveButton = true,
                showDeleteButton = true,
            }
        )
        yOffset = nextY - 8
    end
    
    -- Store the yOffset after preset for UpdateHubLayout to use
    hub.postPresetYOffset = yOffset
    
    -- ===== ADDON WARNING (shown if Plater/Platynator active) =====
    local warningText = hub:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    warningText:SetPoint("TOP", 0, yOffset)
    warningText:SetWidth(HUB_WIDTH - 20)
    warningText:SetJustifyH("CENTER")
    warningText:SetWordWrap(true)
    warningText:Hide()
    hub.warningText = warningText
    
    local warningSep = hub:CreateTexture(nil, "ARTWORK")
    warningSep:SetPoint("TOP", warningText, "BOTTOM", 0, -6)
    warningSep:SetSize(buttonWidth, 1)
    warningSep:SetColorTexture(0.4, 0.4, 0.4, 0.6)
    warningSep:Hide()
    hub.warningSep = warningSep
    
    -- Track warning height for dynamic layout
    hub.warningHeight = 0
    
    -- ===== NAMEPLATES SECTION =====
    local nameplatesLabel = hub:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameplatesLabel:SetPoint("TOP", 0, yOffset)
    nameplatesLabel:SetText("|cff888888Nameplates|r")
    hub.nameplatesLabel = nameplatesLabel
    yOffset = yOffset - 16
    
    local enemyBtn = CreateFrame("Button", nil, hub, "UIPanelButtonTemplate")
    enemyBtn:SetPoint("TOP", 0, yOffset)
    enemyBtn:SetSize(buttonWidth, BUTTON_HEIGHT)
    enemyBtn:SetText("Enemy Nameplates")
    enemyBtn:SetScript("OnClick", function() self:TogglePanel("EnemyNameplates") end)
    hub.enemyBtn = enemyBtn
    yOffset = yOffset - BUTTON_HEIGHT - BUTTON_SPACING
    
    local friendlyBtn = CreateFrame("Button", nil, hub, "UIPanelButtonTemplate")
    friendlyBtn:SetPoint("TOP", 0, yOffset)
    friendlyBtn:SetSize(buttonWidth, BUTTON_HEIGHT)
    friendlyBtn:SetText("Friendly Nameplates")
    friendlyBtn:SetScript("OnClick", function() self:TogglePanel("FriendlyNameplates") end)
    hub.friendlyBtn = friendlyBtn
    yOffset = yOffset - BUTTON_HEIGHT - BUTTON_SPACING * 2
    
    -- ===== SEPARATOR =====
    local sep1 = hub:CreateTexture(nil, "ARTWORK")
    sep1:SetPoint("TOP", 0, yOffset)
    sep1:SetSize(buttonWidth, 1)
    sep1:SetColorTexture(0.4, 0.4, 0.4, 0.6)
    hub.sep1 = sep1
    yOffset = yOffset - 8
    
    -- ===== EXTRAS SECTION =====
    local extrasLabel = hub:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    extrasLabel:SetPoint("TOP", 0, yOffset)
    extrasLabel:SetText("|cff888888Extras|r")
    hub.extrasLabel = extrasLabel
    yOffset = yOffset - 16
    
    local highlightsBtn = CreateFrame("Button", nil, hub, "UIPanelButtonTemplate")
    highlightsBtn:SetPoint("TOP", 0, yOffset)
    highlightsBtn:SetSize(buttonWidth, BUTTON_HEIGHT)
    highlightsBtn:SetText("Target/Focus Highlights")
    highlightsBtn:SetScript("OnClick", function() self:TogglePanel("Highlights") end)
    hub.highlightsBtn = highlightsBtn
    yOffset = yOffset - BUTTON_HEIGHT - BUTTON_SPACING
    
    -- Set final hub height
    hub:SetHeight(-yOffset + 10)
    
    self:UpdateAddonWarning()
    hub:Show()
end

-- ============================================================================
-- ADDON WARNING UPDATE
-- ============================================================================

function Nameplates:UpdateAddonWarning()
    local hub = self.State.nameplatesHub
    if not hub then return end
    
    local anyAddonActive = self:IsNameplateAddonActive()
    
    if anyAddonActive then
        local addons = self:GetActiveNameplateAddons()
        local addonList = table.concat(addons, ", ")
        
        hub.warningText:SetText("|cffff6600⚠ " .. addonList .. " detected|r\nTweaksUI nameplate customization is disabled to avoid conflicts.")
        hub.warningText:Show()
        hub.warningSep:Show()
        hub.warningHeight = hub.warningText:GetStringHeight() + 16
    else
        hub.warningText:Hide()
        hub.warningSep:Hide()
        hub.warningHeight = 0
    end
    
    self:UpdateHubLayout()
end

-- ============================================================================
-- HUB LAYOUT UPDATE
-- ============================================================================

function Nameplates:UpdateHubLayout()
    local hub = self.State.nameplatesHub
    if not hub then return end
    
    local HUB_WIDTH = self.Constants.HUB_WIDTH
    local BUTTON_HEIGHT = self.Constants.BUTTON_HEIGHT
    local BUTTON_SPACING = self.Constants.BUTTON_SPACING
    local buttonWidth = HUB_WIDTH - 20
    
    -- Start after the preset dropdown
    local yOffset = hub.postPresetYOffset or -38
    
    -- Warning (if visible)
    if hub.warningText:IsShown() then
        hub.warningText:SetPoint("TOP", 0, yOffset)
        yOffset = yOffset - hub.warningText:GetStringHeight() - 6
        hub.warningSep:SetPoint("TOP", hub.warningText, "BOTTOM", 0, -6)
        yOffset = yOffset - 10
    end
    
    -- Nameplates section
    hub.nameplatesLabel:SetPoint("TOP", 0, yOffset)
    yOffset = yOffset - 16
    
    hub.enemyBtn:SetPoint("TOP", 0, yOffset)
    yOffset = yOffset - BUTTON_HEIGHT - BUTTON_SPACING
    
    hub.friendlyBtn:SetPoint("TOP", 0, yOffset)
    yOffset = yOffset - BUTTON_HEIGHT - BUTTON_SPACING * 2
    
    -- Separator
    hub.sep1:SetPoint("TOP", 0, yOffset)
    yOffset = yOffset - 8
    
    -- Extras section
    hub.extrasLabel:SetPoint("TOP", 0, yOffset)
    yOffset = yOffset - 16
    
    hub.highlightsBtn:SetPoint("TOP", 0, yOffset)
    yOffset = yOffset - BUTTON_HEIGHT - BUTTON_SPACING
    
    -- Update hub height
    hub:SetHeight(-yOffset + 10)
end

-- ============================================================================
-- PANEL MANAGEMENT
-- ============================================================================

function Nameplates:HideAllPanels()
    if self.State.nameplatesHub then self.State.nameplatesHub:Hide() end
    for _, panel in pairs(self.State.settingsPanels) do
        if panel then panel:Hide() end
    end
    self.State.currentOpenPanel = nil
    self:HideInfoTooltip()
end

function Nameplates:TogglePanel(panelKey)
    -- Hide other panels
    for key, panel in pairs(self.State.settingsPanels) do
        if panel and key ~= panelKey then panel:Hide() end
    end
    
    -- Toggle requested panel
    if self.State.settingsPanels[panelKey] and self.State.settingsPanels[panelKey]:IsShown() then
        self.State.settingsPanels[panelKey]:Hide()
        self.State.currentOpenPanel = nil
        return
    end
    
    -- Destroy and recreate panel (for fresh state)
    if self.State.settingsPanels[panelKey] then
        self.State.settingsPanels[panelKey]:Hide()
        self.State.settingsPanels[panelKey]:SetParent(nil)
        self.State.settingsPanels[panelKey] = nil
    end
    
    -- Create the panel
    self:CreatePanel(panelKey)
    
    if self.State.settingsPanels[panelKey] then
        self.State.settingsPanels[panelKey]:Show()
        self.State.currentOpenPanel = panelKey
    end
end
