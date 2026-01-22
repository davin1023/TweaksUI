-- ============================================================================
-- TweaksUI: Nameplates Module - Simulation
-- Interactive preview frames for settings panels
-- ============================================================================

local ADDON_NAME, TweaksUI = ...
local Nameplates = TweaksUI.Nameplates

-- ============================================================================
-- SIMULATION STATE
-- ============================================================================

Nameplates.SimState = {
    isTarget = false,
    isFocus = false,
    healthPercent = 75,
    threatStatus = 0,  -- 0=none, 1=high threat, 2=tanking insecure, 3=tanking secure
    threatPercent = 50,
    -- Cast bar simulation
    isCasting = false,
    isChanneling = false,
    isImportant = false,
    notInterruptible = false,
    castProgress = 50,  -- 0-100
}

-- ============================================================================
-- SIMULATION FRAME CREATION
-- ============================================================================

function Nameplates:CreateSimulationFrame(parent, configKey)
    local isEnemy = (configKey == "enemy")
    local frameKey = configKey .. "SimFrame"
    
    -- Create container (taller for cast bar controls)
    local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    container:SetSize(340, 210)
    container:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    container:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    container:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    
    -- Title
    local title = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -8)
    title:SetText("Preview")
    
    -- ========== NAMEPLATE PREVIEW ==========
    local previewFrame = CreateFrame("Frame", nil, container)
    previewFrame:SetSize(200, 60)
    previewFrame:SetPoint("TOP", 0, -30)
    
    -- Health bar
    local healthBar = CreateFrame("StatusBar", nil, previewFrame)
    healthBar:SetSize(140, 12)
    healthBar:SetPoint("CENTER", 0, 10)
    healthBar:SetMinMaxValues(0, 100)
    healthBar:SetValue(self.SimState.healthPercent)
    healthBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    healthBar:SetStatusBarColor(1, 0, 0)
    
    -- Health bar background
    local healthBg = healthBar:CreateTexture(nil, "BACKGROUND")
    healthBg:SetAllPoints()
    healthBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    healthBg:SetVertexColor(0.1, 0.1, 0.1, 0.8)
    
    -- Health bar border frame
    local borderFrame = CreateFrame("Frame", nil, healthBar, "BackdropTemplate")
    borderFrame:SetPoint("TOPLEFT", -1, 1)
    borderFrame:SetPoint("BOTTOMRIGHT", 1, -1)
    borderFrame:SetFrameLevel(healthBar:GetFrameLevel() + 1)
    
    -- Name text
    local nameText = healthBar:CreateFontString(nil, "OVERLAY")
    nameText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    nameText:SetPoint("BOTTOM", healthBar, "TOP", 0, 2)
    nameText:SetText(isEnemy and "Enemy Target" or "Friendly Player")
    nameText:SetTextColor(1, 0.2, 0.2)
    
    -- Health text
    local healthText = healthBar:CreateFontString(nil, "OVERLAY")
    healthText:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    healthText:SetPoint("CENTER", healthBar, "CENTER", 0, 0)
    healthText:SetText("75%")
    healthText:SetTextColor(1, 1, 1)
    
    -- Threat text
    local threatText = healthBar:CreateFontString(nil, "OVERLAY")
    threatText:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    threatText:SetPoint("RIGHT", healthBar, "LEFT", -4, 0)
    threatText:SetText("")
    threatText:SetTextColor(1, 0.5, 0)
    
    -- Target highlight - create edge textures on the healthBar itself at BACKGROUND layer
    local targetGlow = { edges = {} }
    for i = 1, 4 do
        local edge = healthBar:CreateTexture(nil, "BACKGROUND", nil, -1)
        edge:SetTexture("Interface\\Buttons\\WHITE8x8")
        edge:SetBlendMode("ADD")
        edge:Hide()
        targetGlow.edges[i] = edge
    end
    
    -- Focus highlight - same approach
    local focusGlow = { edges = {} }
    for i = 1, 4 do
        local edge = healthBar:CreateTexture(nil, "BACKGROUND", nil, -1)
        edge:SetTexture("Interface\\Buttons\\WHITE8x8")
        edge:SetBlendMode("ADD")
        edge:Hide()
        focusGlow.edges[i] = edge
    end
    
    previewFrame.healthBar = healthBar
    previewFrame.healthBg = healthBg
    previewFrame.borderFrame = borderFrame
    previewFrame.nameText = nameText
    previewFrame.healthText = healthText
    previewFrame.threatText = threatText
    previewFrame.targetGlow = targetGlow
    previewFrame.focusGlow = focusGlow
    
    -- ========== CAST BAR PREVIEW ==========
    local castBarFrame = CreateFrame("Frame", nil, previewFrame)
    castBarFrame:SetSize(140, 10)
    castBarFrame:SetPoint("TOP", healthBar, "BOTTOM", 0, -2)
    castBarFrame:Hide()
    
    -- Cast bar status bar
    local castBar = CreateFrame("StatusBar", nil, castBarFrame)
    castBar:SetAllPoints()
    castBar:SetMinMaxValues(0, 100)
    castBar:SetValue(50)
    castBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    castBar:SetStatusBarColor(1, 0.7, 0)
    
    -- Cast bar background
    local castBg = castBarFrame:CreateTexture(nil, "BACKGROUND")
    castBg:SetAllPoints()
    castBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    castBg:SetVertexColor(0.1, 0.1, 0.1, 0.8)
    
    -- Cast bar border edges
    castBarFrame.borderEdges = {}
    for i = 1, 4 do
        local edge = castBarFrame:CreateTexture(nil, "BORDER")
        edge:SetTexture("Interface\\Buttons\\WHITE8X8")
        edge:SetVertexColor(0, 0, 0, 1)
        castBarFrame.borderEdges[i] = edge
    end
    
    -- Cast bar icon
    local castIcon = castBarFrame:CreateTexture(nil, "ARTWORK")
    castIcon:SetSize(10, 10)
    castIcon:SetPoint("RIGHT", castBarFrame, "LEFT", -2, 0)
    castIcon:SetTexture("Interface\\Icons\\Spell_Fire_FelFlameRing")
    castIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    
    -- Cast bar icon border
    local castIconBorder = castBarFrame:CreateTexture(nil, "OVERLAY")
    castIconBorder:SetPoint("TOPLEFT", castIcon, "TOPLEFT", -1, 1)
    castIconBorder:SetPoint("BOTTOMRIGHT", castIcon, "BOTTOMRIGHT", 1, -1)
    castIconBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
    castIconBorder:SetVertexColor(0, 0, 0, 1)
    castIconBorder:SetDrawLayer("OVERLAY", -1)
    
    -- Cast bar spell name
    local castSpellName = castBarFrame:CreateFontString(nil, "OVERLAY")
    castSpellName:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    castSpellName:SetPoint("LEFT", castBarFrame, "LEFT", 2, 0)
    castSpellName:SetText("Fireball")
    
    -- Cast bar timer
    local castTimer = castBarFrame:CreateFontString(nil, "OVERLAY")
    castTimer:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    castTimer:SetPoint("RIGHT", castBarFrame, "RIGHT", -2, 0)
    castTimer:SetText("1.5")
    
    -- Cast bar spark
    local castSpark = castBar:CreateTexture(nil, "OVERLAY")
    castSpark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    castSpark:SetBlendMode("ADD")
    castSpark:SetSize(10, 20)
    castSpark:SetPoint("CENTER", castBar:GetStatusBarTexture(), "RIGHT", 0, 0)
    
    previewFrame.castBarFrame = castBarFrame
    previewFrame.castBar = castBar
    previewFrame.castBg = castBg
    previewFrame.castIcon = castIcon
    previewFrame.castIconBorder = castIconBorder
    previewFrame.castSpellName = castSpellName
    previewFrame.castTimer = castTimer
    previewFrame.castSpark = castSpark
    
    -- ========== AURA PREVIEW ICONS ==========
    -- Debuff container (below health bar)
    local debuffContainer = CreateFrame("Frame", nil, previewFrame)
    debuffContainer:SetSize(100, 20)
    debuffContainer:SetPoint("TOP", healthBar, "BOTTOM", 0, -2)
    debuffContainer.icons = {}
    
    -- Create 4 sample debuff icons
    for i = 1, 4 do
        local icon = CreateFrame("Frame", nil, debuffContainer)
        icon:SetSize(20, 20)
        icon:SetPoint("LEFT", debuffContainer, "LEFT", (i-1) * 22, 0)
        
        icon.texture = icon:CreateTexture(nil, "ARTWORK")
        icon.texture:SetAllPoints()
        icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        -- Sample debuff textures (common DoT icons)
        local textures = {
            "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
            "Interface\\Icons\\Spell_Shadow_Requiem",
            "Interface\\Icons\\Spell_Fire_Immolation",
            "Interface\\Icons\\Ability_Druid_Disembowel",
        }
        icon.texture:SetTexture(textures[i])
        
        -- Border
        icon.border = icon:CreateTexture(nil, "BORDER")
        icon.border:SetPoint("TOPLEFT", -1, 1)
        icon.border:SetPoint("BOTTOMRIGHT", 1, -1)
        icon.border:SetTexture("Interface\\Buttons\\WHITE8x8")
        icon.border:SetVertexColor(0, 0, 0, 1)
        icon.border:SetDrawLayer("BORDER", -1)
        
        -- Stack text
        icon.stackText = icon:CreateFontString(nil, "OVERLAY")
        icon.stackText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        icon.stackText:SetPoint("BOTTOMRIGHT", 2, -2)
        if i == 2 then
            icon.stackText:SetText("3")
        else
            icon.stackText:Hide()
        end
        
        debuffContainer.icons[i] = icon
        icon:Hide()  -- Start hidden, show based on settings
    end
    previewFrame.debuffContainer = debuffContainer
    
    -- Buff container (above health bar)
    local buffContainer = CreateFrame("Frame", nil, previewFrame)
    buffContainer:SetSize(80, 18)
    buffContainer:SetPoint("BOTTOM", healthBar, "TOP", 0, 14)
    buffContainer.icons = {}
    
    -- Create 3 sample buff icons
    for i = 1, 3 do
        local icon = CreateFrame("Frame", nil, buffContainer)
        icon:SetSize(18, 18)
        icon:SetPoint("LEFT", buffContainer, "LEFT", (i-1) * 20, 0)
        
        icon.texture = icon:CreateTexture(nil, "ARTWORK")
        icon.texture:SetAllPoints()
        icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        -- Sample buff textures (dispellable buffs)
        local textures = {
            "Interface\\Icons\\Spell_Holy_PowerWordShield",
            "Interface\\Icons\\Spell_Nature_Regeneration",
            "Interface\\Icons\\Spell_Holy_GreaterHeal",
        }
        icon.texture:SetTexture(textures[i])
        
        -- Border (blue for magic)
        icon.border = icon:CreateTexture(nil, "BORDER")
        icon.border:SetPoint("TOPLEFT", -1, 1)
        icon.border:SetPoint("BOTTOMRIGHT", 1, -1)
        icon.border:SetTexture("Interface\\Buttons\\WHITE8x8")
        icon.border:SetVertexColor(0.2, 0.6, 1.0, 1)  -- Blue for magic
        icon.border:SetDrawLayer("BORDER", -1)
        
        buffContainer.icons[i] = icon
        icon:Hide()  -- Start hidden, show based on settings
    end
    previewFrame.buffContainer = buffContainer
    
    container.preview = previewFrame
    
    -- ========== CONTROLS ==========
    local controlsY = -100
    
    -- Target checkbox
    local targetCb = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate")
    targetCb:SetPoint("TOPLEFT", 15, controlsY)
    targetCb:SetSize(22, 22)
    targetCb:SetChecked(self.SimState.isTarget)
    
    local targetLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    targetLabel:SetPoint("LEFT", targetCb, "RIGHT", 2, 0)
    targetLabel:SetText("Target")
    
    targetCb:SetScript("OnClick", function(self)
        Nameplates.SimState.isTarget = self:GetChecked()
        Nameplates:UpdateSimulationPreview(container, configKey)
    end)
    
    -- Focus checkbox
    local focusCb = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate")
    focusCb:SetPoint("LEFT", targetLabel, "RIGHT", 15, 0)
    focusCb:SetSize(22, 22)
    focusCb:SetChecked(self.SimState.isFocus)
    
    local focusLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    focusLabel:SetPoint("LEFT", focusCb, "RIGHT", 2, 0)
    focusLabel:SetText("Focus")
    
    focusCb:SetScript("OnClick", function(self)
        Nameplates.SimState.isFocus = self:GetChecked()
        Nameplates:UpdateSimulationPreview(container, configKey)
    end)
    
    -- Health slider
    local healthLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    healthLabel:SetPoint("TOPLEFT", 15, controlsY - 28)
    healthLabel:SetText("Health:")
    
    local healthValText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    healthValText:SetPoint("TOPLEFT", 280, controlsY - 28)
    healthValText:SetText(self.SimState.healthPercent .. "%")
    
    local healthSlider = CreateFrame("Slider", nil, container, "OptionsSliderTemplate")
    healthSlider:SetPoint("TOPLEFT", 60, controlsY - 26)
    healthSlider:SetSize(210, 17)
    healthSlider:SetMinMaxValues(0, 100)
    healthSlider:SetValueStep(1)
    healthSlider:SetObeyStepOnDrag(true)
    healthSlider:SetValue(self.SimState.healthPercent)
    healthSlider.Low:SetText("0%")
    healthSlider.High:SetText("100%")
    healthSlider.Text:SetText("")
    
    healthSlider:SetScript("OnValueChanged", function(self, value)
        Nameplates.SimState.healthPercent = math.floor(value)
        healthValText:SetText(Nameplates.SimState.healthPercent .. "%")
        Nameplates:UpdateSimulationPreview(container, configKey)
    end)
    
    -- Threat slider (enemy only)
    if isEnemy then
        local threatLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        threatLabel:SetPoint("TOPLEFT", 15, controlsY - 58)
        threatLabel:SetText("Threat:")
        
        local threatValText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        threatValText:SetPoint("TOPLEFT", 280, controlsY - 58)
        threatValText:SetText(self.SimState.threatPercent .. "%")
        
        local threatSlider = CreateFrame("Slider", nil, container, "OptionsSliderTemplate")
        threatSlider:SetPoint("TOPLEFT", 60, controlsY - 56)
        threatSlider:SetSize(210, 17)
        threatSlider:SetMinMaxValues(0, 200)
        threatSlider:SetValueStep(1)
        threatSlider:SetObeyStepOnDrag(true)
        threatSlider:SetValue(self.SimState.threatPercent)
        threatSlider.Low:SetText("0%")
        threatSlider.High:SetText("200%")
        threatSlider.Text:SetText("")
        
        threatSlider:SetScript("OnValueChanged", function(self, value)
            Nameplates.SimState.threatPercent = math.floor(value)
            threatValText:SetText(Nameplates.SimState.threatPercent .. "%")
            -- Determine threat status based on percent
            if value >= 100 then
                Nameplates.SimState.threatStatus = 3  -- Tanking
            elseif value >= 80 then
                Nameplates.SimState.threatStatus = 2  -- High threat
            elseif value >= 50 then
                Nameplates.SimState.threatStatus = 1  -- Medium threat
            else
                Nameplates.SimState.threatStatus = 0  -- Low threat
            end
            Nameplates:UpdateSimulationPreview(container, configKey)
        end)
        
        container.threatSlider = threatSlider
        container.threatValText = threatValText
    end
    
    -- ========== CAST BAR CONTROLS ==========
    local castControlsY = isEnemy and (controlsY - 88) or (controlsY - 58)
    
    -- Casting checkbox
    local castCb = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate")
    castCb:SetPoint("TOPLEFT", 10, castControlsY)
    castCb:SetSize(22, 22)
    castCb:SetChecked(self.SimState.isCasting)
    
    local castLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    castLabel:SetPoint("LEFT", castCb, "RIGHT", 2, 0)
    castLabel:SetText("Casting")
    
    castCb:SetScript("OnClick", function(self)
        Nameplates.SimState.isCasting = self:GetChecked()
        Nameplates:UpdateSimulationPreview(container, configKey)
    end)
    
    -- Important checkbox
    local importantCb = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate")
    importantCb:SetPoint("LEFT", castLabel, "RIGHT", 15, 0)
    importantCb:SetSize(22, 22)
    importantCb:SetChecked(self.SimState.isImportant)
    
    local importantLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    importantLabel:SetPoint("LEFT", importantCb, "RIGHT", 2, 0)
    importantLabel:SetText("Important")
    
    importantCb:SetScript("OnClick", function(self)
        Nameplates.SimState.isImportant = self:GetChecked()
        Nameplates:UpdateSimulationPreview(container, configKey)
    end)
    
    -- Non-interruptible checkbox (enemy only)
    if isEnemy then
        local shieldCb = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate")
        shieldCb:SetPoint("LEFT", importantLabel, "RIGHT", 15, 0)
        shieldCb:SetSize(22, 22)
        shieldCb:SetChecked(self.SimState.notInterruptible)
        
        local shieldLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        shieldLabel:SetPoint("LEFT", shieldCb, "RIGHT", 2, 0)
        shieldLabel:SetText("Uninterruptible")
        
        shieldCb:SetScript("OnClick", function(self)
            Nameplates.SimState.notInterruptible = self:GetChecked()
            Nameplates:UpdateSimulationPreview(container, configKey)
        end)
        
        container.shieldCb = shieldCb
    end
    
    container.castCb = castCb
    container.importantCb = importantCb
    
    container.targetCb = targetCb
    container.focusCb = focusCb
    container.healthSlider = healthSlider
    container.healthValText = healthValText
    container.configKey = configKey
    
    -- Initial update
    self:UpdateSimulationPreview(container, configKey)
    
    return container
end

-- ============================================================================
-- UPDATE SIMULATION PREVIEW
-- ============================================================================

-- Helper function to get threat color with inversion support for simulation
local function GetSimThreatColor(threatStatus, invertColors)
    local r, g, b
    if invertColors then
        -- Tank mode: tanking = safe (grey/green), no threat = bad (red)
        if threatStatus == 3 then
            r, g, b = 0.5, 0.8, 0.5  -- Green-ish - tanking (safe)
        elseif threatStatus == 0 then
            r, g, b = 1, 0.2, 0.2  -- Red - no threat (need to taunt!)
        elseif threatStatus == 1 then
            r, g, b = 1, 0.5, 0  -- Orange - losing aggro
        else
            r, g, b = 1, 1, 0  -- Yellow - high threat but not tanking
        end
    else
        -- Normal mode: tanking = red, no threat = grey
        if threatStatus == 3 then
            r, g, b = 1, 0, 0  -- Red - tanking
        elseif threatStatus == 2 then
            r, g, b = 1, 0.5, 0  -- Orange - high threat
        elseif threatStatus == 1 then
            r, g, b = 1, 1, 0  -- Yellow - medium threat
        else
            r, g, b = 0.5, 0.5, 0.5  -- Grey - low threat
        end
    end
    return r, g, b
end

function Nameplates:UpdateSimulationPreview(container, configKey)
    if not container or not container.preview then return end
    
    local settings = self.State.settings
    if not settings or not settings[configKey] then return end
    
    local preview = container.preview
    local healthBar = preview.healthBar
    local healthBg = preview.healthBg
    local borderFrame = preview.borderFrame
    local nameText = preview.nameText
    local healthText = preview.healthText
    local threatText = preview.threatText
    local targetGlow = preview.targetGlow
    local focusGlow = preview.focusGlow
    
    local isEnemy = (configKey == "enemy")
    local healthConfig = settings[configKey].healthBar
    local nameConfig = settings[configKey].nameText
    local healthTextConfig = settings[configKey].healthText
    local threatTextConfig = settings[configKey].threatText
    
    local isTarget = self.SimState.isTarget
    local isFocus = self.SimState.isFocus
    local healthPct = self.SimState.healthPercent
    local threatStatus = self.SimState.threatStatus
    local threatPct = self.SimState.threatPercent
    
    -- ========== HEALTH BAR ==========
    if healthConfig then
        -- Size (use target size if target) - apply scale for this type
        local baseWidth = isTarget and (healthConfig.targetWidth or healthConfig.width) or healthConfig.width
        local baseHeight = isTarget and (healthConfig.targetHeight or healthConfig.height) or healthConfig.height
        local width = self:ApplyScale(baseWidth or 140, configKey)
        local height = self:ApplyScale(baseHeight or 12, configKey)
        
        -- Apply threat-based scaling if enabled
        if healthConfig.threatScaleEnabled then
            local minScale = (healthConfig.threatScaleMin or 80) / 100
            local maxScale = (healthConfig.threatScaleMax or 120) / 100
            local t = (threatStatus or 0) / 3  -- 0 to 1
            -- If inverted, swap the scale direction
            if healthConfig.invertThreatColors then
                t = 1 - t  -- Tanking = small, no threat = large
            end
            local threatScale = minScale + (maxScale - minScale) * t
            width = width * threatScale
            height = height * threatScale
        end
        
        healthBar:SetSize(width, height)
        
        -- Texture
        local texturePath = self:GetTexturePath(healthConfig.texture)
        healthBar:SetStatusBarTexture(texturePath)
        
        -- Health value
        healthBar:SetValue(healthPct)
        
        -- Color based on mode
        local r, g, b = 1, 0, 0
        if healthConfig.colorMode == "reaction" then
            r, g, b = isEnemy and 1 or 0, isEnemy and 0 or 1, 0
        elseif healthConfig.colorMode == "class" then
            -- Simulate a warrior (brown) for friendlies, reaction for enemies
            if isEnemy then
                r, g, b = 1, 0, 0
            else
                r, g, b = 0.78, 0.61, 0.43
            end
        elseif healthConfig.colorMode == "health" then
            -- Health gradient
            local pct = healthPct / 100
            if pct > 0.5 then
                r, g, b = (1 - pct) * 2, 1, 0
            else
                r, g, b = 1, pct * 2, 0
            end
        elseif healthConfig.colorMode == "threat" then
            -- Threat color - use helper with inversion
            r, g, b = GetSimThreatColor(threatStatus, healthConfig.invertThreatColors)
        elseif healthConfig.colorMode == "custom" then
            local c = healthConfig.customColor
            r, g, b = c[1], c[2], c[3]
        end
        healthBar:SetStatusBarColor(r, g, b)
        
        -- Alpha
        local alpha = isTarget and (healthConfig.targetAlpha or 1) or (healthConfig.alpha or 1)
        healthBar:SetAlpha(alpha)
        
        -- Background
        if healthConfig.bgEnabled then
            local bgc = healthConfig.bgColor
            healthBg:SetVertexColor(bgc[1], bgc[2], bgc[3], bgc[4] or 0.8)
            healthBg:Show()
        else
            healthBg:Hide()
        end
        
        -- Border
        if healthConfig.borderEnabled then
            local size = healthConfig.borderSize or 1
            borderFrame:ClearAllPoints()
            borderFrame:SetPoint("TOPLEFT", -size, size)
            borderFrame:SetPoint("BOTTOMRIGHT", size, -size)
            borderFrame:SetBackdrop({
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = size,
            })
            local bc = healthConfig.borderColor
            borderFrame:SetBackdropBorderColor(bc[1], bc[2], bc[3], bc[4] or 1)
            borderFrame:Show()
        else
            borderFrame:SetBackdrop(nil)
            borderFrame:Hide()
        end
    end
    
    -- ========== NAME TEXT ==========
    if nameConfig then
        if nameConfig.enabled then
            nameText:Show()
            
            -- Font - apply scale for this type
            local fontPath = self:GetFontPath(nameConfig.font)
            local fontSize = self:ApplyScale(nameConfig.fontSize or 10, configKey)
            nameText:SetFont(fontPath, fontSize, nameConfig.outline == "THICK" and "THICKOUTLINE" or (nameConfig.outline == "NONE" and "" or "OUTLINE"))
            
            -- Position - scale offsets
            nameText:ClearAllPoints()
            local offsetX = self:ApplyScale(nameConfig.offsetX or 0, configKey)
            local offsetY = self:ApplyScale(nameConfig.offsetY or 2, configKey)
            nameText:SetPoint(nameConfig.relativePoint or "TOP", healthBar, nameConfig.anchor or "BOTTOM", offsetX, offsetY)
            
            -- Color
            local r, g, b = 1, 1, 1
            if nameConfig.colorMode == "reaction" then
                r, g, b = isEnemy and 1 or 0, isEnemy and 0 or 1, 0
            elseif nameConfig.colorMode == "class" then
                if isEnemy then
                    r, g, b = 1, 0.2, 0.2
                else
                    r, g, b = 0.78, 0.61, 0.43
                end
            elseif nameConfig.colorMode == "threat" then
                -- Use helper with inversion from health config
                r, g, b = GetSimThreatColor(threatStatus, healthConfig and healthConfig.invertThreatColors)
            elseif nameConfig.colorMode == "custom" then
                local c = nameConfig.customColor
                r, g, b = c[1], c[2], c[3]
            end
            nameText:SetTextColor(r, g, b)
            
            -- Shadow
            if nameConfig.shadow then
                nameText:SetShadowOffset(1, -1)
                nameText:SetShadowColor(0, 0, 0, 0.8)
            else
                nameText:SetShadowOffset(0, 0)
            end
        else
            nameText:Hide()
        end
    end
    
    -- ========== HEALTH TEXT ==========
    if healthTextConfig then
        if healthTextConfig.enabled then
            healthText:Show()
            
            -- Font - apply scale for this type
            local fontPath = self:GetFontPath(healthTextConfig.font)
            local fontSize = self:ApplyScale(healthTextConfig.fontSize or 9, configKey)
            healthText:SetFont(fontPath, fontSize, healthTextConfig.outline == "THICK" and "THICKOUTLINE" or (healthTextConfig.outline == "NONE" and "" or "OUTLINE"))
            
            -- Position - scale offsets
            healthText:ClearAllPoints()
            local offsetX = self:ApplyScale(healthTextConfig.offsetX or 0, configKey)
            local offsetY = self:ApplyScale(healthTextConfig.offsetY or 0, configKey)
            healthText:SetPoint(healthTextConfig.relativePoint or "CENTER", healthBar, healthTextConfig.anchor or "CENTER", offsetX, offsetY)
            
            -- Format text
            local text = ""
            if healthTextConfig.format == "PERCENT" then
                text = string.format("%.0f%%", healthPct)
            elseif healthTextConfig.format == "CURRENT" then
                text = string.format("%.0fK", healthPct * 10)  -- Simulate 1M max health
            elseif healthTextConfig.format == "BOTH" then
                text = string.format("%.0fK (%.0f%%)", healthPct * 10, healthPct)
            elseif healthTextConfig.format == "DEFICIT" then
                if healthPct < 100 then
                    text = string.format("-%.0fK", (100 - healthPct) * 10)
                else
                    text = ""
                end
            elseif healthTextConfig.format == "CURRENT_MAX" then
                text = string.format("%.0fK / 1M", healthPct * 10)
            end
            healthText:SetText(text)
            
            -- Color
            local r, g, b = 1, 1, 1
            if healthTextConfig.colorMode == "class" then
                r, g, b = isEnemy and 1 or 0.78, isEnemy and 0.2 or 0.61, isEnemy and 0.2 or 0.43
            elseif healthTextConfig.colorMode == "reaction" then
                r, g, b = isEnemy and 1 or 0, isEnemy and 0 or 1, 0
            elseif healthTextConfig.colorMode == "threat" then
                r, g, b = GetSimThreatColor(threatStatus, healthConfig and healthConfig.invertThreatColors)
            elseif healthTextConfig.colorMode == "custom" then
                local c = healthTextConfig.customColor
                r, g, b = c[1], c[2], c[3]
            end
            healthText:SetTextColor(r, g, b)
        else
            healthText:Hide()
        end
    end
    
    -- ========== THREAT TEXT ==========
    if threatTextConfig and isEnemy then
        if threatTextConfig.enabled then
            threatText:Show()
            
            -- Font - apply scale for this type
            local fontPath = self:GetFontPath(threatTextConfig.font)
            local fontSize = self:ApplyScale(threatTextConfig.fontSize or 9, configKey)
            threatText:SetFont(fontPath, fontSize, threatTextConfig.outline == "THICK" and "THICKOUTLINE" or (threatTextConfig.outline == "NONE" and "" or "OUTLINE"))
            
            -- Position - scale offsets
            threatText:ClearAllPoints()
            local offsetX = self:ApplyScale(threatTextConfig.offsetX or -4, configKey)
            local offsetY = self:ApplyScale(threatTextConfig.offsetY or 0, configKey)
            threatText:SetPoint(threatTextConfig.relativePoint or "CENTER", healthBar, threatTextConfig.anchor or "LEFT", offsetX, offsetY)
            
            -- Text
            if threatTextConfig.showPercent then
                threatText:SetText(string.format("%.0f%%", threatPct))
            else
                threatText:SetText(string.format("%.0f", threatPct))
            end
            
            -- Color
            local r, g, b = 1, 0.5, 0
            if threatTextConfig.colorMode == "threat" then
                r, g, b = GetSimThreatColor(threatStatus, healthConfig and healthConfig.invertThreatColors)
            elseif threatTextConfig.colorMode == "custom" then
                local c = threatTextConfig.customColor
                r, g, b = c[1], c[2], c[3]
            end
            threatText:SetTextColor(r, g, b)
        else
            threatText:Hide()
        end
    else
        threatText:Hide()
    end
    
    -- ========== HIGHLIGHTS ==========
    local targetHighlight = settings.targetHighlight
    local focusHighlight = settings.focusHighlight
    
    -- Helper to apply edge highlight
    local function ApplyEdgeHighlight(glow, frame, color, thickness)
        local r, g, b, a = color[1], color[2], color[3], color[4] or 0.6
        local edges = glow.edges
        
        -- Top edge
        edges[1]:ClearAllPoints()
        edges[1]:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", -thickness, 0)
        edges[1]:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", thickness, 0)
        edges[1]:SetHeight(thickness)
        edges[1]:SetVertexColor(r, g, b, a)
        edges[1]:Show()
        
        -- Bottom edge
        edges[2]:ClearAllPoints()
        edges[2]:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -thickness, 0)
        edges[2]:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", thickness, 0)
        edges[2]:SetHeight(thickness)
        edges[2]:SetVertexColor(r, g, b, a)
        edges[2]:Show()
        
        -- Left edge
        edges[3]:ClearAllPoints()
        edges[3]:SetPoint("TOPRIGHT", frame, "TOPLEFT", 0, 0)
        edges[3]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 0, 0)
        edges[3]:SetWidth(thickness)
        edges[3]:SetVertexColor(r, g, b, a)
        edges[3]:Show()
        
        -- Right edge
        edges[4]:ClearAllPoints()
        edges[4]:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, 0)
        edges[4]:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 0, 0)
        edges[4]:SetWidth(thickness)
        edges[4]:SetVertexColor(r, g, b, a)
        edges[4]:Show()
    end
    
    local function HideEdgeHighlight(glow)
        if glow and glow.edges then
            for i = 1, 4 do
                glow.edges[i]:Hide()
            end
        end
    end
    
    -- Target glow - apply scale for this type
    if isTarget and targetHighlight and targetHighlight.enabled then
        local thickness = self:ApplyScale(targetHighlight.thickness or 3, configKey)
        ApplyEdgeHighlight(targetGlow, healthBar, targetHighlight.color, thickness)
    else
        HideEdgeHighlight(targetGlow)
    end
    
    -- Focus glow - apply scale for this type
    if isFocus and focusHighlight and focusHighlight.enabled and not isTarget then
        local thickness = self:ApplyScale(focusHighlight.thickness or 3, configKey)
        ApplyEdgeHighlight(focusGlow, healthBar, focusHighlight.color, thickness)
    else
        HideEdgeHighlight(focusGlow)
    end
    
    -- ========== CAST BAR PREVIEW ==========
    local castBarFrame = preview.castBarFrame
    local castBar = preview.castBar
    local castConfig = settings[configKey] and settings[configKey].castBar
    local isCasting = self.SimState.isCasting
    local isImportant = self.SimState.isImportant
    local notInterruptible = self.SimState.notInterruptible
    
    if castBarFrame and castConfig then
        if isCasting and castConfig.enabled then
            castBarFrame:Show()
            
            -- Size & Position - apply scale
            local castWidth = castConfig.width
            if castWidth == 0 then
                -- Match health bar width - calculate it directly
                local healthBarWidth = healthConfig and healthConfig.width or 140
                if isTarget and healthConfig and healthConfig.targetWidth then
                    healthBarWidth = healthConfig.targetWidth
                end
                castWidth = healthBarWidth
            end
            castWidth = self:ApplyScale(castWidth, configKey)
            local castHeight = self:ApplyScale(castConfig.height or 10, configKey)
            
            castBarFrame:SetSize(castWidth, castHeight)
            castBarFrame:ClearAllPoints()
            local castYOffset = self:ApplyScale(castConfig.yOffset or -2, configKey)
            local castXOffset = self:ApplyScale(castConfig.xOffset or 0, configKey)
            castBarFrame:SetPoint("TOP", healthBar, "BOTTOM", castXOffset, castYOffset)
            
            -- Progress
            castBar:SetMinMaxValues(0, 100)
            castBar:SetValue(self.SimState.castProgress or 50)
            
            -- Texture
            local texturePath = self:GetTexturePath(castConfig.texture)
            castBar:SetStatusBarTexture(texturePath)
            
            -- Color based on state
            local r, g, b, a
            if notInterruptible then
                local c = castConfig.nonInterruptibleColor or {0.5, 0.5, 0.5, 1}
                r, g, b, a = c[1], c[2], c[3], c[4] or 1
            elseif isImportant then
                local c = castConfig.importantCastColor or {1, 0, 0.5, 1}
                r, g, b, a = c[1], c[2], c[3], c[4] or 1
            else
                local c = castConfig.castingColor or {1, 0.7, 0, 1}
                r, g, b, a = c[1], c[2], c[3], c[4] or 1
            end
            castBar:SetStatusBarColor(r, g, b, a)
            
            -- Background
            if castConfig.bgEnabled and preview.castBg then
                local bgc = castConfig.bgColor or {0.1, 0.1, 0.1, 0.8}
                preview.castBg:SetVertexColor(bgc[1], bgc[2], bgc[3], bgc[4] or 0.8)
                preview.castBg:Show()
            elseif preview.castBg then
                preview.castBg:Hide()
            end
            
            -- Border
            if castConfig.borderEnabled and castBarFrame.borderEdges then
                local borderSize = castConfig.borderSize or 1
                local bc = castConfig.borderColor or {0, 0, 0, 1}
                local edges = castBarFrame.borderEdges
                
                -- Top
                edges[1]:ClearAllPoints()
                edges[1]:SetPoint("BOTTOMLEFT", castBarFrame, "TOPLEFT", -borderSize, 0)
                edges[1]:SetPoint("BOTTOMRIGHT", castBarFrame, "TOPRIGHT", borderSize, 0)
                edges[1]:SetHeight(borderSize)
                edges[1]:SetVertexColor(bc[1], bc[2], bc[3], bc[4] or 1)
                edges[1]:Show()
                
                -- Bottom
                edges[2]:ClearAllPoints()
                edges[2]:SetPoint("TOPLEFT", castBarFrame, "BOTTOMLEFT", -borderSize, 0)
                edges[2]:SetPoint("TOPRIGHT", castBarFrame, "BOTTOMRIGHT", borderSize, 0)
                edges[2]:SetHeight(borderSize)
                edges[2]:SetVertexColor(bc[1], bc[2], bc[3], bc[4] or 1)
                edges[2]:Show()
                
                -- Left
                edges[3]:ClearAllPoints()
                edges[3]:SetPoint("TOPRIGHT", castBarFrame, "TOPLEFT", 0, 0)
                edges[3]:SetPoint("BOTTOMRIGHT", castBarFrame, "BOTTOMLEFT", 0, 0)
                edges[3]:SetWidth(borderSize)
                edges[3]:SetVertexColor(bc[1], bc[2], bc[3], bc[4] or 1)
                edges[3]:Show()
                
                -- Right
                edges[4]:ClearAllPoints()
                edges[4]:SetPoint("TOPLEFT", castBarFrame, "TOPRIGHT", 0, 0)
                edges[4]:SetPoint("BOTTOMLEFT", castBarFrame, "BOTTOMRIGHT", 0, 0)
                edges[4]:SetWidth(borderSize)
                edges[4]:SetVertexColor(bc[1], bc[2], bc[3], bc[4] or 1)
                edges[4]:Show()
            elseif castBarFrame.borderEdges then
                for i = 1, 4 do
                    castBarFrame.borderEdges[i]:Hide()
                end
            end
            
            -- Icon
            if castConfig.iconEnabled and preview.castIcon then
                local iconSize = castConfig.iconSize
                if iconSize == 0 then
                    iconSize = castHeight
                end
                iconSize = self:ApplyScale(iconSize, configKey)
                preview.castIcon:SetSize(iconSize, iconSize)
                preview.castIcon:ClearAllPoints()
                local iconOffset = self:ApplyScale(castConfig.iconOffset or -2, configKey)
                if castConfig.iconPosition == "LEFT" then
                    preview.castIcon:SetPoint("RIGHT", castBarFrame, "LEFT", iconOffset, 0)
                else
                    preview.castIcon:SetPoint("LEFT", castBarFrame, "RIGHT", -iconOffset, 0)
                end
                preview.castIcon:Show()
                
                -- Icon border
                if castConfig.iconBorderEnabled and preview.castIconBorder then
                    preview.castIconBorder:Show()
                elseif preview.castIconBorder then
                    preview.castIconBorder:Hide()
                end
            elseif preview.castIcon then
                preview.castIcon:Hide()
                if preview.castIconBorder then preview.castIconBorder:Hide() end
            end
            
            -- Spell name
            if castConfig.spellNameEnabled and preview.castSpellName then
                local fontPath = self:GetFontPath(castConfig.spellNameFont)
                local fontSize = self:ApplyScale(castConfig.spellNameFontSize or 8, configKey)
                preview.castSpellName:SetFont(fontPath, fontSize, castConfig.spellNameOutline or "OUTLINE")
                local c = castConfig.spellNameColor or {1, 1, 1, 1}
                preview.castSpellName:SetTextColor(c[1], c[2], c[3], c[4] or 1)
                preview.castSpellName:SetText(isImportant and "Pyroblast" or "Fireball")
                preview.castSpellName:Show()
            elseif preview.castSpellName then
                preview.castSpellName:Hide()
            end
            
            -- Timer
            if castConfig.timerEnabled and preview.castTimer then
                local fontPath = self:GetFontPath(castConfig.timerFont)
                local fontSize = self:ApplyScale(castConfig.timerFontSize or 8, configKey)
                preview.castTimer:SetFont(fontPath, fontSize, castConfig.timerOutline or "OUTLINE")
                local c = castConfig.timerColor or {1, 1, 1, 1}
                preview.castTimer:SetTextColor(c[1], c[2], c[3], c[4] or 1)
                preview.castTimer:SetText(castConfig.timerShowDecimals and "1.5" or "2")
                preview.castTimer:Show()
            elseif preview.castTimer then
                preview.castTimer:Hide()
            end
            
            -- Spark
            if castConfig.sparkEnabled and preview.castSpark then
                local sparkWidth = self:ApplyScale(castConfig.sparkWidth or 10, configKey)
                preview.castSpark:SetSize(sparkWidth, castHeight * 2)
                local sc = castConfig.sparkColor or {1, 1, 1, 0.8}
                preview.castSpark:SetVertexColor(sc[1], sc[2], sc[3], sc[4] or 0.8)
                preview.castSpark:Show()
            elseif preview.castSpark then
                preview.castSpark:Hide()
            end
        else
            castBarFrame:Hide()
        end
    elseif castBarFrame then
        castBarFrame:Hide()
    end
    
    -- ========== AURA PREVIEW ==========
    local auraSettings = settings[configKey] and settings[configKey].auras
    
    -- Debuff container
    if preview.debuffContainer then
        local debuffContainer = preview.debuffContainer
        if auraSettings and auraSettings.enabled and auraSettings.debuffs and auraSettings.debuffs.enabled then
            local debuffConfig = auraSettings.debuffs
            local iconSize = self:ApplyScale(debuffConfig.iconSize or 20, configKey)
            local spacing = self:ApplyScale(debuffConfig.spacing or 2, configKey)
            local maxIcons = debuffConfig.maxIcons or 6
            local offsetX = self:ApplyScale(debuffConfig.offsetX or 0, configKey)
            local offsetY = self:ApplyScale(debuffConfig.offsetY or -2, configKey)
            
            -- Position container based on position setting (matching Auras.lua)
            debuffContainer:ClearAllPoints()
            local position = debuffConfig.position or "BOTTOM"
            local justify = debuffConfig.justify or "CENTER"
            
            if position == "BOTTOM" then
                if justify == "LEFT" then
                    debuffContainer:SetPoint("TOPLEFT", healthBar, "BOTTOMLEFT", offsetX, offsetY)
                elseif justify == "RIGHT" then
                    debuffContainer:SetPoint("TOPRIGHT", healthBar, "BOTTOMRIGHT", offsetX, offsetY)
                else -- CENTER
                    debuffContainer:SetPoint("TOP", healthBar, "BOTTOM", offsetX, offsetY)
                end
            elseif position == "TOP" then
                if justify == "LEFT" then
                    debuffContainer:SetPoint("BOTTOMLEFT", healthBar, "TOPLEFT", offsetX, offsetY)
                elseif justify == "RIGHT" then
                    debuffContainer:SetPoint("BOTTOMRIGHT", healthBar, "TOPRIGHT", offsetX, offsetY)
                else -- CENTER
                    debuffContainer:SetPoint("BOTTOM", healthBar, "TOP", offsetX, offsetY)
                end
            elseif position == "LEFT" then
                debuffContainer:SetPoint("RIGHT", healthBar, "LEFT", offsetX, offsetY)
            elseif position == "RIGHT" then
                debuffContainer:SetPoint("LEFT", healthBar, "RIGHT", offsetX, offsetY)
            end
            
            -- Update icons
            local showCount = math.min(4, maxIcons)
            for i, icon in ipairs(debuffContainer.icons) do
                if i <= showCount then
                    icon:SetSize(iconSize, iconSize)
                    icon:ClearAllPoints()
                    local iconOffset = (i - 1) * (iconSize + spacing)
                    if debuffConfig.growDirection == "LEFT" then
                        icon:SetPoint("RIGHT", debuffContainer, "RIGHT", -iconOffset, 0)
                    else
                        icon:SetPoint("LEFT", debuffContainer, "LEFT", iconOffset, 0)
                    end
                    
                    -- Border visibility and color
                    if debuffConfig.showBorder and icon.border then
                        icon.border:Show()
                        if debuffConfig.colorByDispelType then
                            -- Alternate dispel colors for preview
                            local colors = {
                                {0.6, 0, 1, 1},    -- Magic (purple)
                                {0, 0.6, 0, 1},    -- Poison (green)
                                {0.8, 0, 0, 1},    -- Physical (red)
                                {0.6, 0.4, 0, 1},  -- Disease (brown)
                            }
                            local c = colors[i] or {0, 0, 0, 1}
                            icon.border:SetVertexColor(c[1], c[2], c[3], c[4])
                        else
                            icon.border:SetVertexColor(0, 0, 0, 1)
                        end
                    elseif icon.border then
                        icon.border:Hide()
                    end
                    
                    icon:Show()
                else
                    icon:Hide()
                end
            end
            
            local containerWidth = (iconSize * showCount) + (spacing * (showCount - 1))
            debuffContainer:SetSize(containerWidth, iconSize)
            debuffContainer:Show()
        else
            debuffContainer:Hide()
        end
    end
    
    -- Buff container
    if preview.buffContainer then
        local buffContainer = preview.buffContainer
        if auraSettings and auraSettings.enabled and auraSettings.buffs and auraSettings.buffs.enabled then
            local buffConfig = auraSettings.buffs
            local iconSize = self:ApplyScale(buffConfig.iconSize or 18, configKey)
            local spacing = self:ApplyScale(buffConfig.spacing or 2, configKey)
            local maxIcons = buffConfig.maxIcons or 4
            local offsetX = self:ApplyScale(buffConfig.offsetX or 0, configKey)
            local offsetY = self:ApplyScale(buffConfig.offsetY or 2, configKey)
            
            -- Position container based on position setting (matching Auras.lua)
            buffContainer:ClearAllPoints()
            local position = buffConfig.position or "TOP"
            local justify = buffConfig.justify or "CENTER"
            
            if position == "TOP" then
                if justify == "LEFT" then
                    buffContainer:SetPoint("BOTTOMLEFT", healthBar, "TOPLEFT", offsetX, offsetY)
                elseif justify == "RIGHT" then
                    buffContainer:SetPoint("BOTTOMRIGHT", healthBar, "TOPRIGHT", offsetX, offsetY)
                else -- CENTER
                    buffContainer:SetPoint("BOTTOM", healthBar, "TOP", offsetX, offsetY)
                end
            elseif position == "BOTTOM" then
                if justify == "LEFT" then
                    buffContainer:SetPoint("TOPLEFT", healthBar, "BOTTOMLEFT", offsetX, offsetY)
                elseif justify == "RIGHT" then
                    buffContainer:SetPoint("TOPRIGHT", healthBar, "BOTTOMRIGHT", offsetX, offsetY)
                else -- CENTER
                    buffContainer:SetPoint("TOP", healthBar, "BOTTOM", offsetX, offsetY)
                end
            elseif position == "LEFT" then
                buffContainer:SetPoint("RIGHT", healthBar, "LEFT", offsetX, offsetY)
            elseif position == "RIGHT" then
                buffContainer:SetPoint("LEFT", healthBar, "RIGHT", offsetX, offsetY)
            end
            
            -- Update icons
            local showCount = math.min(3, maxIcons)
            for i, icon in ipairs(buffContainer.icons) do
                if i <= showCount then
                    icon:SetSize(iconSize, iconSize)
                    icon:ClearAllPoints()
                    local iconOffset = (i - 1) * (iconSize + spacing)
                    if buffConfig.growDirection == "LEFT" then
                        icon:SetPoint("RIGHT", buffContainer, "RIGHT", -iconOffset, 0)
                    else
                        icon:SetPoint("LEFT", buffContainer, "LEFT", iconOffset, 0)
                    end
                    
                    -- Border visibility and color
                    if buffConfig.showBorder and icon.border then
                        icon.border:Show()
                        if buffConfig.colorByDispelType then
                            icon.border:SetVertexColor(0.2, 0.6, 1.0, 1)  -- Blue for magic
                        else
                            icon.border:SetVertexColor(0, 0, 0, 1)
                        end
                    elseif icon.border then
                        icon.border:Hide()
                    end
                    
                    icon:Show()
                else
                    icon:Hide()
                end
            end
            
            local containerWidth = (iconSize * showCount) + (spacing * (showCount - 1))
            buffContainer:SetSize(containerWidth, iconSize)
            buffContainer:Show()
        else
            buffContainer:Hide()
        end
    end
end

-- ============================================================================
-- REFRESH ALL SIMULATIONS
-- ============================================================================

function Nameplates:RefreshAllSimulations()
    -- Update enemy simulation if it exists
    if self.State.enemySimFrame then
        self:UpdateSimulationPreview(self.State.enemySimFrame, "enemy")
    end
    
    -- Update friendly simulation if it exists
    if self.State.friendlySimFrame then
        self:UpdateSimulationPreview(self.State.friendlySimFrame, "friendly")
    end
end

-- ============================================================================
-- FONT PATH HELPER
-- ============================================================================

function Nameplates:GetFontPath(fontName)
    if not fontName then return "Fonts\\FRIZQT__.TTF" end
    
    -- Try LibSharedMedia
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local path = LSM:Fetch("font", fontName)
        if path then return path end
    end
    
    -- Default fonts
    local defaults = {
        ["Friz Quadrata TT"] = "Fonts\\FRIZQT__.TTF",
        ["Arial Narrow"] = "Fonts\\ARIALN.TTF",
        ["Morpheus"] = "Fonts\\MORPHEUS.TTF",
        ["Skurri"] = "Fonts\\SKURRI.TTF",
    }
    
    return defaults[fontName] or "Fonts\\FRIZQT__.TTF"
end
