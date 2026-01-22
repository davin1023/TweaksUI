-- ============================================================================
-- TweaksUI Nameplates Auras Module
-- Displays buffs and debuffs on nameplates
-- ============================================================================

local addonName, TweaksUI = ...
local Nameplates = TweaksUI.Nameplates
if not Nameplates then 
    return 
end

-- ============================================================================
-- MIDNIGHT API WRAPPERS (v2.0.0)
-- ============================================================================

local AuraAPI = TweaksUI.AuraAPI
local DurationAPI = TweaksUI.DurationAPI
local CurveAPI = TweaksUI.CurveAPI

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local MAX_AURA_ICONS = 12  -- Maximum icons per container

-- Dispel type colors (fallback for color curve creation)
local DISPEL_TYPE_COLORS = {
    Magic = {0.2, 0.6, 1.0, 1},      -- Blue
    Curse = {0.6, 0.0, 1.0, 1},      -- Purple
    Disease = {0.6, 0.4, 0.0, 1},    -- Brown
    Poison = {0.0, 0.6, 0.0, 1},     -- Green
    none = {0.8, 0.0, 0.0, 1},       -- Red (physical/bleed)
}

-- ============================================================================
-- LOCAL REFERENCES
-- ============================================================================

local CreateFrame = CreateFrame
local GetTime = GetTime
local UnitIsEnemy = UnitIsEnemy
local UnitIsFriend = UnitIsFriend
local pairs = pairs
local ipairs = ipairs
local tinsert = table.insert
local wipe = wipe

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Get aura settings for a unit type
local function GetAuraSettings(unit)
    if not Nameplates or not Nameplates.State or not Nameplates.State.settings then 
        return nil 
    end
    local settings = Nameplates.State.settings
    
    local isFriendly = unit and UnitIsFriend("player", unit)
    local unitSettings = isFriendly and settings.friendly or settings.enemy
    
    return unitSettings and unitSettings.auras
end

-- Get dispel color for a dispel type (uses AuraAPI)
local function GetDispelColor(dispelName)
    if not dispelName then return DISPEL_TYPE_COLORS.none end
    
    -- Use AuraAPI with dispel color curve
    if AuraAPI then
        local dispelTypeID = AuraAPI:GetDispelTypeID(dispelName)
        if dispelTypeID then
            local colorCurve = CurveAPI and CurveAPI:GetDispelTypeColorCurve()
            if colorCurve then
                local color = AuraAPI:GetDispelTypeColor(dispelTypeID, colorCurve)
                if color then
                    return {color.r, color.g, color.b, 1}
                end
            end
        end
    end
    
    -- Fallback to static table
    return DISPEL_TYPE_COLORS[dispelName] or DISPEL_TYPE_COLORS.none
end

-- ============================================================================
-- AURA ICON CREATION
-- ============================================================================

local function CreateAuraIcon(container, index)
    local icon = CreateFrame("Frame", nil, container)
    icon:SetSize(20, 20)
    
    -- Make completely mouse-transparent
    icon:EnableMouse(false)
    icon:SetHitRectInsets(10000, 10000, 10000, 10000)
    
    -- Icon texture
    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints()
    icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    
    -- Border using edge textures
    icon.borderEdges = {}
    for i = 1, 4 do
        local edge = icon:CreateTexture(nil, "BORDER")
        edge:SetTexture("Interface\\Buttons\\WHITE8X8")
        edge:SetVertexColor(0, 0, 0, 1)
        icon.borderEdges[i] = edge
    end
    
    -- Top edge
    icon.borderEdges[1]:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
    icon.borderEdges[1]:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 1, 1)
    icon.borderEdges[1]:SetHeight(1)
    
    -- Bottom edge
    icon.borderEdges[2]:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", -1, -1)
    icon.borderEdges[2]:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
    icon.borderEdges[2]:SetHeight(1)
    
    -- Left edge
    icon.borderEdges[3]:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 0)
    icon.borderEdges[3]:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", -1, 0)
    icon.borderEdges[3]:SetWidth(1)
    
    -- Right edge
    icon.borderEdges[4]:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 1, 0)
    icon.borderEdges[4]:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, 0)
    icon.borderEdges[4]:SetWidth(1)
    
    -- Cooldown frame
    icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.cooldown:SetAllPoints()
    icon.cooldown:SetHideCountdownNumbers(false)  -- Use Blizzard's built-in text (works with secret values)
    icon.cooldown:EnableMouse(false)
    icon.cooldown:SetDrawEdge(false)
    icon.cooldown:SetSwipeColor(0, 0, 0, 0.6)
    if icon.cooldown.SetDrawBling then
        icon.cooldown:SetDrawBling(false)
    end
    
    -- Text overlay frame - sits above the cooldown spiral
    icon.textOverlay = CreateFrame("Frame", nil, icon)
    icon.textOverlay:SetAllPoints()
    icon.textOverlay:SetFrameLevel(icon.cooldown:GetFrameLevel() + 2)
    
    -- Stack count text (on overlay, bottom right)
    icon.stackText = icon.textOverlay:CreateFontString(nil, "OVERLAY")
    icon.stackText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    icon.stackText:SetPoint("BOTTOMRIGHT", 2, -2)
    icon.stackText:SetTextColor(1, 1, 1, 1)
    icon.stackText:Hide()
    
    -- Duration text (on overlay, center - above spiral)
    icon.durationText = icon.textOverlay:CreateFontString(nil, "OVERLAY")
    icon.durationText:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    icon.durationText:SetPoint("CENTER", 0, 0)
    icon.durationText:SetTextColor(1, 1, 1, 1)
    icon.durationText:Hide()
    
    -- Store references
    icon.index = index
    icon.auraInstanceID = nil
    
    icon:Hide()
    return icon
end

-- Set border color on an icon
local function SetIconBorderColor(icon, color)
    if not icon or not icon.borderEdges then return end
    
    local r, g, b, a = color[1] or 0, color[2] or 0, color[3] or 0, color[4] or 1
    for i = 1, 4 do
        if icon.borderEdges[i] then
            icon.borderEdges[i]:SetVertexColor(r, g, b, a)
        end
    end
end

-- Show/hide icon border
local function SetIconBorderVisible(icon, visible)
    if not icon or not icon.borderEdges then return end
    
    for i = 1, 4 do
        if icon.borderEdges[i] then
            if visible then
                icon.borderEdges[i]:Show()
            else
                icon.borderEdges[i]:Hide()
            end
        end
    end
end

-- ============================================================================
-- AURA CONTAINER CREATION
-- ============================================================================

function Nameplates:CreateAuraContainer(nameplate, data, containerType)
    -- Find best parent frame - prefer our overlay, fall back to Blizzard's health bar, then nameplate
    local parent = nil
    if data.overlayHealthBar and data.overlayHealthBar:IsShown() then
        parent = data.overlayHealthBar
    elseif data.blizzHealthBar then
        parent = data.blizzHealthBar
    elseif nameplate and nameplate.UnitFrame and nameplate.UnitFrame.healthBar then
        parent = nameplate.UnitFrame.healthBar
    else
        parent = nameplate
    end
    
    if not parent then return nil end
    
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(100, 20)
    
    -- Set frame level above parent
    container:SetFrameLevel(parent:GetFrameLevel() + 10)
    
    -- Make container mouse-transparent
    container:EnableMouse(false)
    container:SetHitRectInsets(10000, 10000, 10000, 10000)
    
    -- Store type
    container.containerType = containerType  -- "debuffs" or "buffs"
    container.icons = {}
    
    -- Pre-create icon pool
    for i = 1, MAX_AURA_ICONS do
        local icon = CreateAuraIcon(container, i)
        container.icons[i] = icon
    end
    
    return container
end

-- ============================================================================
-- AURA ICON POSITIONING
-- ============================================================================

-- Position an aura icon within its container
local function PositionAuraIcon(icon, index, config, container, scaleMultiplier)
    if not icon then return end
    
    scaleMultiplier = scaleMultiplier or 1
    local size = (config.iconSize or 20) * scaleMultiplier
    local spacing = (config.spacing or 2) * scaleMultiplier
    local growDirection = config.growDirection or "RIGHT"
    
    icon:ClearAllPoints()
    
    local offset = (index - 1) * (size + spacing)
    
    if growDirection == "RIGHT" then
        icon:SetPoint("LEFT", container, "LEFT", offset, 0)
    elseif growDirection == "LEFT" then
        icon:SetPoint("RIGHT", container, "RIGHT", -offset, 0)
    end
end

-- Update container size based on visible icons
local function UpdateContainerSize(container, visibleCount, config, scaleMultiplier)
    if not container or visibleCount <= 0 then
        container:SetSize(1, 1)
        return
    end
    
    scaleMultiplier = scaleMultiplier or 1
    local size = (config.iconSize or 20) * scaleMultiplier
    local spacing = (config.spacing or 2) * scaleMultiplier
    
    local width = (size * visibleCount) + (spacing * (visibleCount - 1))
    container:SetSize(width, size)
end

-- ============================================================================
-- AURA CONTAINER UPDATING (Beta 4+ Duration Object API)
-- ============================================================================

local function UpdateAuraContainer(nameplate, unit, container, auraType, config, data)
    if not container or not unit or not config or not config.enabled then
        -- Hide all icons
        if container then
            for i = 1, MAX_AURA_ICONS do
                if container.icons[i] then
                    container.icons[i]:Hide()
                end
            end
        end
        return
    end
    
    -- Get scale multiplier from data (includes target or mouseover scale)
    local scaleMultiplier = (data and data.scaleMultiplier) or 1
    
    local maxIcons = config.maxIcons or 6
    
    -- Build filter string
    local filter = auraType == "debuffs" and "HARMFUL" or "HELPFUL"
    if auraType == "debuffs" and config.onlyMine then
        filter = filter .. "|PLAYER"
    end
    
    -- Collect aura instance IDs using AuraAPI wrapper
    local auraInstanceIDs = {}
    
    if AuraAPI then
        -- Use AuraAPI wrapper for consistent behavior
        local sortRule = Enum.UnitAuraSortRule.Default
        local sortDir = Enum.UnitAuraSortDirection.Normal
        auraInstanceIDs = AuraAPI:GetAuraInstanceIDs(unit, filter, maxIcons, sortRule, sortDir) or {}
    end
    
    -- Fallback to ForEachAura if no results
    if #auraInstanceIDs == 0 and AuraUtil and AuraUtil.ForEachAura then
        pcall(function()
            AuraUtil.ForEachAura(unit, filter, maxIcons, function(aura)
                if aura and aura.auraInstanceID then
                    tinsert(auraInstanceIDs, aura.auraInstanceID)
                end
                if #auraInstanceIDs >= maxIcons then
                    return true
                end
                return false
            end, true)
        end)
    end
    
    -- Update icons using aura instance IDs
    local iconIndex = 1
    for _, auraID in ipairs(auraInstanceIDs) do
        if iconIndex > maxIcons then break end
        
        local icon = container.icons[iconIndex]
        if icon then
            local showIcon = false
            local skipDueToHidePermanent = false
            
            -- Get aura data via AuraAPI
            local auraData = AuraAPI and AuraAPI:GetAuraDataByInstanceID(unit, auraID)
            
            if auraData then
                -- Check hidePermanent option using AuraAPI
                if config.hidePermanent and AuraAPI then
                    local hasExpiration = AuraAPI:HasExpirationTime(unit, auraID)
                    -- SetAlphaFromBoolean handles secret booleans
                    if icon.SetAlphaFromBoolean then
                        icon:SetAlphaFromBoolean(hasExpiration, 1.0, 0.0)
                    elseif hasExpiration == false then
                        skipDueToHidePermanent = true
                    end
                else
                    icon:SetAlpha(1.0)
                end
                
                if not skipDueToHidePermanent then
                    -- Set texture - passing secret icon value to SetTexture is allowed
                    pcall(function()
                        local auraIcon = auraData.icon
                        if auraIcon then
                            icon.texture:SetTexture(auraIcon)
                            icon.texture:Show()
                            showIcon = true
                        end
                    end)
                    
                    -- Set size with scale multiplier
                    local iconSize = (config.iconSize or 20) * scaleMultiplier
                    icon:SetSize(iconSize, iconSize)
                    
                    -- Set cooldown sweep using DurationAPI
                    if icon.cooldown and DurationAPI then
                        DurationAPI:ApplyAuraDurationToFrame(icon.cooldown, unit, auraID, true)
                        icon.cooldown:Show()
                        -- Apply duration font size to Blizzard's countdown text
                        local durationFontSize = config.durationFontSize or 10
                        pcall(function()
                            local cdText = icon.cooldown.Text or icon.cooldown.text
                            if not cdText then
                                for i = 1, icon.cooldown:GetNumRegions() do
                                    local region = select(i, icon.cooldown:GetRegions())
                                    if region and region:GetObjectType() == "FontString" then
                                        cdText = region
                                        icon.cooldown.Text = cdText
                                        break
                                    end
                                end
                            end
                            if cdText and cdText.SetFont then
                                local fontPath, _, fontFlags = cdText:GetFont()
                                if fontPath then
                                    cdText:SetFont(fontPath, durationFontSize, fontFlags or "OUTLINE")
                                end
                            end
                        end)
                    elseif icon.cooldown then
                        -- Fallback: try direct values from aura data
                        local exp = auraData.expirationTime
                        local dur = auraData.duration
                        local cooldownSet = false
                        if exp and dur and dur > 0 then
                            icon.cooldown:SetCooldown(exp - dur, dur)
                            cooldownSet = true
                        end
                        
                        if cooldownSet then
                            icon.cooldown:Show()
                            -- Apply duration font size to Blizzard's countdown text
                            local durationFontSize = config.durationFontSize or 10
                            pcall(function()
                                local cdText = icon.cooldown.Text or icon.cooldown.text
                                if not cdText then
                                    for i = 1, icon.cooldown:GetNumRegions() do
                                        local region = select(i, icon.cooldown:GetRegions())
                                        if region and region:GetObjectType() == "FontString" then
                                            cdText = region
                                            icon.cooldown.Text = cdText
                                            break
                                        end
                                    end
                                end
                                if cdText and cdText.SetFont then
                                    local fontPath, _, fontFlags = cdText:GetFont()
                                    if fontPath then
                                        cdText:SetFont(fontPath, durationFontSize, fontFlags or "OUTLINE")
                                    end
                                end
                            end)
                        else
                            icon.cooldown:Hide()
                        end
                    end
                    
                    -- Duration text: Blizzard's CooldownFrameTemplate handles this automatically
                    -- when SetHideCountdownNumbers(false) - works with secret values and abbreviates times
                    -- Hide our custom durationText since it's no longer needed
                    if icon.durationText then
                        icon.durationText:Hide()
                    end
                    
                    -- Stack count
                    if config.showStacks and icon.stackText then
                        local stackShown = false
                        local stackFontSize = config.stackFontSize or 10
                        icon.stackText:SetFont("Fonts\\FRIZQT__.TTF", stackFontSize, "OUTLINE")
                        
                        -- Use AuraAPI:GetApplicationDisplayCount with minBound=2
                        if AuraAPI then
                            local countText = AuraAPI:GetApplicationDisplayCount(unit, auraID, 2)
                            if countText then
                                icon.stackText:SetText(countText)
                                icon.stackText:Show()
                                stackShown = true
                            end
                        end
                        
                        -- Fallback to direct stacks (wrapped in pcall for secret comparison)
                        if not stackShown then
                            pcall(function()
                                local stacks = auraData.applications
                                if stacks and stacks > 1 then
                                    icon.stackText:SetText(tostring(stacks))
                                    icon.stackText:Show()
                                    stackShown = true
                                end
                            end)
                        end
                        
                        if not stackShown then
                            icon.stackText:Hide()
                        end
                    else
                        if icon.stackText then icon.stackText:Hide() end
                    end
                    
                    -- Border
                    if config.showBorder then
                        SetIconBorderVisible(icon, true)
                        SetIconBorderColor(icon, {0, 0, 0, 1})
                    else
                        SetIconBorderVisible(icon, false)
                    end
                end
            end
            
            if showIcon then
                PositionAuraIcon(icon, iconIndex, config, container, scaleMultiplier)
                icon:Show()
                iconIndex = iconIndex + 1
            else
                icon:Hide()
            end
        end
    end
    
    -- Hide unused icons
    for i = iconIndex, MAX_AURA_ICONS do
        if container.icons[i] then
            container.icons[i]:Hide()
        end
    end
    
    -- Update container size
    UpdateContainerSize(container, iconIndex - 1, config, scaleMultiplier)
end

-- ============================================================================
-- MAIN AURA UPDATE FUNCTION
-- ============================================================================

function Nameplates:UpdateAuras(nameplate, unit, data)
    if not nameplate or not unit or not data then 
        return 
    end
    
    local auraSettings = GetAuraSettings(unit)
    if not auraSettings then
        return
    end
    if not auraSettings.enabled then
        -- Hide all aura containers
        if data.debuffContainer then
            for i = 1, MAX_AURA_ICONS do
                if data.debuffContainer.icons[i] then
                    data.debuffContainer.icons[i]:Hide()
                end
            end
        end
        if data.buffContainer then
            for i = 1, MAX_AURA_ICONS do
                if data.buffContainer.icons[i] then
                    data.buffContainer.icons[i]:Hide()
                end
            end
        end
        return
    end
    
    -- Debug: Print that we're updating auras
    -- print("TweaksUI Auras: Updating for", unit, "debuffs enabled:", auraSettings.debuffs and auraSettings.debuffs.enabled)
    
    -- Update debuffs
    if auraSettings.debuffs and auraSettings.debuffs.enabled then
        if not data.debuffContainer then
            data.debuffContainer = self:CreateAuraContainer(nameplate, data, "debuffs")
        end
        if data.debuffContainer then
            UpdateAuraContainer(nameplate, unit, data.debuffContainer, "debuffs", auraSettings.debuffs, data)
            self:PositionAuraContainer(data.debuffContainer, data, "debuffs", auraSettings.debuffs)
            data.debuffContainer:Show()
        end
    elseif data.debuffContainer then
        data.debuffContainer:Hide()
    end
    
    -- Update buffs
    if auraSettings.buffs and auraSettings.buffs.enabled then
        if not data.buffContainer then
            data.buffContainer = self:CreateAuraContainer(nameplate, data, "buffs")
        end
        if data.buffContainer then
            UpdateAuraContainer(nameplate, unit, data.buffContainer, "buffs", auraSettings.buffs, data)
            self:PositionAuraContainer(data.buffContainer, data, "buffs", auraSettings.buffs)
            data.buffContainer:Show()
        end
    elseif data.buffContainer then
        data.buffContainer:Hide()
    end
end

-- Position aura container relative to nameplate/health bar
function Nameplates:PositionAuraContainer(container, data, containerType, config)
    if not container or not data then return end
    
    container:ClearAllPoints()
    
    -- Anchor to our overlay health bar if it exists and visible, 
    -- otherwise try Blizzard's health bar, finally fall back to nameplate
    local anchor = nil
    if data.overlayHealthBar and data.overlayHealthBar:IsShown() then
        anchor = data.overlayHealthBar
    elseif data.blizzHealthBar then
        anchor = data.blizzHealthBar
    elseif data.nameplate and data.nameplate.UnitFrame then
        anchor = data.nameplate.UnitFrame.healthBar or data.nameplate
    else
        anchor = data.nameplate
    end
    
    if not anchor then return end
    
    local position = config.position or "BOTTOM"
    local justify = config.justify or "CENTER"
    local offsetX = config.offsetX or 0
    local offsetY = config.offsetY or (position == "BOTTOM" and -2 or 2)
    
    -- Determine anchor points based on position and justify
    if position == "BOTTOM" then
        if justify == "LEFT" then
            container:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", offsetX, offsetY)
        elseif justify == "RIGHT" then
            container:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", offsetX, offsetY)
        else -- CENTER
            container:SetPoint("TOP", anchor, "BOTTOM", offsetX, offsetY)
        end
    elseif position == "TOP" then
        if justify == "LEFT" then
            container:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", offsetX, offsetY)
        elseif justify == "RIGHT" then
            container:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", offsetX, offsetY)
        else -- CENTER
            container:SetPoint("BOTTOM", anchor, "TOP", offsetX, offsetY)
        end
    elseif position == "LEFT" then
        container:SetPoint("RIGHT", anchor, "LEFT", offsetX, offsetY)
    elseif position == "RIGHT" then
        container:SetPoint("LEFT", anchor, "RIGHT", offsetX, offsetY)
    end
    
    -- Apply effective alpha from health bar settings (target vs non-target)
    if data.effectiveAlpha then
        container:SetAlpha(data.effectiveAlpha)
    else
        container:SetAlpha(1.0)
    end
end

-- ============================================================================
-- EVENT HANDLING
-- ============================================================================

local auraEventFrame = CreateFrame("Frame")
auraEventFrame:RegisterEvent("UNIT_AURA")
auraEventFrame:SetScript("OnEvent", function(self, event, unit, updateInfo)
    if not Nameplates or not Nameplates.State then return end
    
    -- Check if this is a nameplate unit
    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if not nameplate then return end
    
    local data = Nameplates.State.enhancedNameplates[nameplate]
    if not data then return end
    
    -- Update auras
    Nameplates:UpdateAuras(nameplate, unit, data)
end)

-- ============================================================================
-- DEFAULT SETTINGS
-- ============================================================================

function Nameplates:GetDefaultAuraSettings()
    return {
        enabled = true,
        
        debuffs = {
            enabled = true,
            maxIcons = 6,
            iconSize = 20,
            spacing = 2,
            growDirection = "RIGHT",
            position = "BOTTOM",
            justify = "CENTER",  -- LEFT, CENTER, RIGHT - relative to health bar
            offsetX = 0,
            offsetY = -2,
            
            onlyMine = true,
            onlyNameplateRelevant = true,
            hidePermanent = false,  -- Hide auras with no duration
            
            showDuration = true,        -- Show cooldown sweep
            showDurationText = true,    -- Show duration countdown number
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
            justify = "CENTER",  -- LEFT, CENTER, RIGHT - relative to health bar
            offsetX = 0,
            offsetY = 2,
            
            onlyDispellable = true,
            onlyStealable = false,
            showEnrage = true,
            hidePermanent = false,  -- Hide auras with no duration
            
            showDuration = true,        -- Show cooldown sweep
            showDurationText = true,    -- Show duration countdown number
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

-- ============================================================================
-- API STATUS
-- ============================================================================

function Nameplates:GetAuraAPIStatus()
    local status = {}
    
    tinsert(status, HAS_DURATION_OBJECT and "|cff00ff00✓ Duration Objects|r" or "|cffff8800○ Duration Objects|r")
    tinsert(status, HAS_AURA_SORTING and "|cff00ff00✓ Aura Sorting|r" or "|cffff8800○ Aura Sorting|r")
    tinsert(status, HAS_AURA_INSTANCE_IDS and "|cff00ff00✓ Aura Instance IDs|r" or "|cffff8800○ Aura Instance IDs|r")
    tinsert(status, HAS_DISPLAY_COUNT and "|cff00ff00✓ Display Count|r" or "|cffff8800○ Display Count|r")
    tinsert(status, HAS_DISPEL_COLOR_API and "|cff00ff00✓ Dispel Color API|r" or "|cffff8800○ Dispel Color API|r")
    tinsert(status, HAS_DURATION_REMAINING and "|cff00ff00✓ Duration Remaining|r" or "|cffff8800○ Duration Remaining|r")
    
    return status
end
