-- TweaksUI UnitFrames Auras Submodule
-- Shows buffs and debuffs on party and raid frames
-- Midnight-compatible: Mirrors Blizzard's aura decisions to avoid secret value issues
--
-- APPROACH: Hook Blizzard's CompactUnitFrames and capture which auraInstanceIDs
-- they decide to show. Then only show those same auras on our frames.
-- This is 100% combat-safe because we only compare integer IDs, not secret values.

local ADDON_NAME, TweaksUI = ...

local Auras = {}
TweaksUI.UnitFrameAuras = Auras

-- ============================================================================
-- MIDNIGHT API WRAPPERS (v2.0.0)
-- ============================================================================

local AuraAPI = TweaksUI.AuraAPI
local DurationAPI = TweaksUI.DurationAPI

-- ============================================================================
-- BLIZZARD AURA CACHE (DandersFrames approach)
-- Hooks Blizzard's raid frames to capture which auras they decided to show
-- This is the ONLY combat-safe way to filter auras
-- ============================================================================

local BlizzardAuraCache = {}
local BlizzardHooksSetup = false

-- Reusable cache for aura collection (PERFORMANCE - avoids table allocations)
local auraCollectionCache = {}

-- Capture auras from a Blizzard CompactUnitFrame
local function CaptureAurasFromBlizzardFrame(frame)
    if not frame or not frame.unit then return end
    
    local unit = frame.unit
    
    -- Skip nameplates and preview frames
    if unit:find("nameplate") then return end
    local frameName = frame:GetName()
    if frameName and (frameName:find("Preview") or frameName:find("Settings")) then return end
    
    -- Initialize cache for this unit
    if not BlizzardAuraCache[unit] then
        BlizzardAuraCache[unit] = { buffs = {}, debuffs = {}, playerDispellable = {} }
    end
    
    local cache = BlizzardAuraCache[unit]
    wipe(cache.buffs)
    wipe(cache.debuffs)
    wipe(cache.playerDispellable)
    
    -- Capture buffs from Blizzard's buff frames
    if frame.buffFrames then
        for i, buffFrame in ipairs(frame.buffFrames) do
            if buffFrame:IsShown() and buffFrame.auraInstanceID then
                cache.buffs[buffFrame.auraInstanceID] = true
            end
        end
    end
    
    -- Capture debuffs from Blizzard's debuff frames
    if frame.debuffFrames then
        for i, debuffFrame in ipairs(frame.debuffFrames) do
            if debuffFrame:IsShown() and debuffFrame.auraInstanceID then
                cache.debuffs[debuffFrame.auraInstanceID] = true
            end
        end
    end
    
    -- Capture player-dispellable debuffs (these are in dispelDebuffFrames)
    if frame.dispelDebuffFrames then
        for i, debuffFrame in ipairs(frame.dispelDebuffFrames) do
            if debuffFrame:IsShown() and debuffFrame.auraInstanceID then
                cache.debuffs[debuffFrame.auraInstanceID] = true
                cache.playerDispellable[debuffFrame.auraInstanceID] = true
            end
        end
    end
    
    -- Trigger update of our corresponding frame
    C_Timer.After(0, function()
        local UnitFrames = TweaksUI.UnitFrames
        if not UnitFrames then return end
        
        -- Find matching TweaksUI frame
        local partyFrames = UnitFrames:GetPartyMemberFrames()
        local partySettings = UnitFrames:GetPartySettings()
        if partyFrames and partySettings then
            for _, tuiFrame in ipairs(partyFrames) do
                if tuiFrame and tuiFrame.unit == unit then
                    local auraSettings = { buffs = partySettings.buffs, debuffs = partySettings.debuffs }
                    Auras:UpdateFrame(tuiFrame, unit, auraSettings)
                    return
                end
            end
        end
        
        local raidFrames = UnitFrames:GetRaidMemberFrames()
        local raidSettings = UnitFrames:GetCurrentRaidSettings()
        if raidFrames and raidSettings then
            for _, tuiFrame in ipairs(raidFrames) do
                if tuiFrame and tuiFrame.unit == unit then
                    local auraSettings = { buffs = raidSettings.buffs, debuffs = raidSettings.debuffs }
                    Auras:UpdateFrame(tuiFrame, unit, auraSettings)
                    return
                end
            end
        end
    end)
end

-- Hook Blizzard's aura update functions
local function SetupBlizzardHooks()
    if BlizzardHooksSetup then return end
    
    -- CRITICAL: All hooks use C_Timer.After(0) to break taint chain
    -- This prevents our addon code from tainting Blizzard's secure execution path
    if CompactUnitFrame_UpdateAuras then
        hooksecurefunc("CompactUnitFrame_UpdateAuras", function(frame)
            C_Timer.After(0, function()
                CaptureAurasFromBlizzardFrame(frame)
            end)
        end)
    end
    if CompactUnitFrame_UpdateBuffs then
        hooksecurefunc("CompactUnitFrame_UpdateBuffs", function(frame)
            C_Timer.After(0, function()
                CaptureAurasFromBlizzardFrame(frame)
            end)
        end)
    end
    if CompactUnitFrame_UpdateDebuffs then
        hooksecurefunc("CompactUnitFrame_UpdateDebuffs", function(frame)
            C_Timer.After(0, function()
                CaptureAurasFromBlizzardFrame(frame)
            end)
        end)
    end
    
    BlizzardHooksSetup = true
end

-- Scan all Blizzard frames to populate cache
local function ScanAllBlizzardFrames()
    for i = 1, 5 do
        local frame = _G["CompactPartyFrameMember" .. i]
        if frame then CaptureAurasFromBlizzardFrame(frame) end
    end
    for i = 1, 40 do
        local frame = _G["CompactRaidFrame" .. i]
        if frame then CaptureAurasFromBlizzardFrame(frame) end
    end
    for group = 1, 8 do
        for member = 1, 5 do
            local frame = _G["CompactRaidGroup" .. group .. "Member" .. member]
            if frame then CaptureAurasFromBlizzardFrame(frame) end
        end
    end
end

-- Export for debugging
Auras.BlizzardAuraCache = BlizzardAuraCache

-- Debug flag (disabled by default, enable with /tuiauras combat)
local auraDebugEnabled = false

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local MAX_AURA_ICONS = 8
local DEFAULT_ICON_SIZE = 16
local DEFAULT_ICON_SPACING = 2

-- ============================================================================
-- AURA ICON CREATION
-- ============================================================================

local function CreateAuraIcon(container, index)
    -- Use Button for right-click cancel support
    local icon = CreateFrame("Button", nil, container, "BackdropTemplate")
    icon:SetSize(DEFAULT_ICON_SIZE, DEFAULT_ICON_SIZE)
    icon:EnableMouse(true)
    icon:RegisterForClicks("AnyUp")
    
    icon:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    icon:SetBackdropBorderColor(0, 0, 0, 1)
    
    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetPoint("TOPLEFT", 1, -1)
    icon.texture:SetPoint("BOTTOMRIGHT", -1, 1)
    icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    
    icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.cooldown:SetAllPoints(icon.texture)
    icon.cooldown:SetHideCountdownNumbers(false)  -- Use Blizzard's built-in text (works with secret values)
    icon.cooldown:SetDrawEdge(false)
    icon.cooldown:SetSwipeColor(0, 0, 0, 0.6)
    icon.cooldown:SetDrawSwipe(true)
    icon.cooldown:SetReverse(true)
    if icon.cooldown.SetDrawBling then
        icon.cooldown:SetDrawBling(false)
    end
    -- Prevent cooldown from intercepting clicks
    icon.cooldown:EnableMouse(false)
    
    icon.textOverlay = CreateFrame("Frame", nil, icon)
    icon.textOverlay:SetAllPoints()
    icon.textOverlay:SetFrameLevel(icon.cooldown:GetFrameLevel() + 2)
    icon.textOverlay:EnableMouse(false)
    
    icon.stackText = icon.textOverlay:CreateFontString(nil, "OVERLAY")
    icon.stackText:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    icon.stackText:SetPoint("BOTTOMRIGHT", 1, -1)
    icon.stackText:SetTextColor(1, 1, 1, 1)
    icon.stackText:Hide()
    
    icon.durationText = icon.textOverlay:CreateFontString(nil, "OVERLAY")
    icon.durationText:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    icon.durationText:SetPoint("TOP", 0, -1)
    icon.durationText:SetTextColor(1, 1, 0.6, 1)
    icon.durationText:Hide()  -- Blizzard's CooldownFrameTemplate handles duration text now
    
    -- Duration text is now handled by Blizzard's CooldownFrameTemplate
    -- with SetHideCountdownNumbers(false) - works with secret values and abbreviates times
    -- No OnUpdate needed for duration text
    
    -- Right-click handler for buff cancellation (player buffs only)
    icon:SetScript("OnClick", function(self, button)
        print("|cff00ff00[TweaksUI Debug]|r Aura click - button:", button, "unit:", self.unit, "type:", self.auraType, "spellName:", self.spellName)
        if button == "RightButton" and self.auraType == "BUFF" and not InCombatLockdown() then
            -- Only cancel if this is the player's buff (unit could be "player", "party1", "raid5", etc)
            local isPlayer = self.unit and UnitIsUnit(self.unit, "player")
            print("|cff00ff00[TweaksUI Debug]|r isPlayer:", isPlayer)
            if isPlayer then
                pcall(function()
                    if self.spellName and CancelSpellByName then
                        CancelSpellByName(self.spellName)
                        print("|cff00ff00[TweaksUI Debug]|r CancelSpellByName:", self.spellName)
                    else
                        print("|cffff0000[TweaksUI Debug]|r No spellName or CancelSpellByName")
                    end
                end)
            end
        end
    end)
    
    icon:SetScript("OnEnter", function(self)
        if self.auraInstanceID and self.unit then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            -- Use AuraAPI for consistent tooltip handling
            local success = false
            if AuraAPI then
                if self.auraType == "BUFF" then
                    success = AuraAPI:SetTooltipBuff(GameTooltip, self.unit, self.auraInstanceID)
                else
                    success = AuraAPI:SetTooltipDebuff(GameTooltip, self.unit, self.auraInstanceID)
                end
            else
                -- Direct API fallback
                if self.auraType == "BUFF" and GameTooltip.SetUnitBuffByAuraInstanceID then
                    success = pcall(GameTooltip.SetUnitBuffByAuraInstanceID, GameTooltip, self.unit, self.auraInstanceID)
                elseif self.auraType == "DEBUFF" and GameTooltip.SetUnitDebuffByAuraInstanceID then
                    success = pcall(GameTooltip.SetUnitDebuffByAuraInstanceID, GameTooltip, self.unit, self.auraInstanceID)
                end
            end
            if success then
                GameTooltip:Show()
            else
                GameTooltip:Hide()
            end
        end
    end)
    
    icon:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    icon.index = index
    icon.auraInstanceID = nil
    icon.unit = nil
    icon.spellName = nil
    
    icon:Hide()
    return icon
end

-- ============================================================================
-- AURA CONTAINER CREATION
-- ============================================================================

function Auras:CreateAuraContainer(parent, containerType)
    if not parent then return nil end
    
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(100, DEFAULT_ICON_SIZE)
    container:SetFrameLevel(parent:GetFrameLevel() + 15)
    
    container.containerType = containerType
    container.icons = {}
    
    for i = 1, MAX_AURA_ICONS do
        local icon = CreateAuraIcon(container, i)
        container.icons[i] = icon
    end
    
    container:Hide()
    return container
end

-- ============================================================================
-- AURA ICON UPDATE (uses Midnight-safe APIs)
-- ============================================================================

local function UpdateAuraIcon(icon, unit, auraInstanceID, auraData, settings)
    if not icon or not auraData then return false end
    
    icon.auraInstanceID = auraInstanceID
    icon.unit = unit
    
    -- Set texture - try to set directly without checking value (secrets are handled by API)
    -- DandersFrames approach: if pcall succeeds, the texture was set
    local ok = pcall(function()
        icon.texture:SetTexture(auraData.icon)
        icon.texture:Show()
    end)
    
    if not ok then return false end
    
    local iconSize = settings.iconSize or DEFAULT_ICON_SIZE
    icon:SetSize(iconSize, iconSize)
    
    -- Set cooldown using DurationAPI
    if icon.cooldown then
        local cooldownSet = false
        
        if DurationAPI then
            cooldownSet = DurationAPI:ApplyAuraDurationToFrame(icon.cooldown, unit, auraInstanceID, true)
        end
        
        if not cooldownSet and icon.cooldown.SetCooldownFromExpirationTime then
            pcall(function()
                icon.cooldown:SetCooldownFromExpirationTime(auraData.expirationTime, auraData.duration)
                cooldownSet = true
            end)
        end
        
        -- Show/hide cooldown based on whether aura has expiration
        if AuraAPI and icon.cooldown.SetShownFromBoolean then
            local hasExp = AuraAPI:HasExpirationTime(unit, auraInstanceID)
            icon.cooldown:SetShownFromBoolean(hasExp, settings.showSwipe ~= false, false)
        elseif cooldownSet and settings.showSwipe ~= false then
            icon.cooldown:Show()
        else
            icon.cooldown:Hide()
        end
    end
    
    -- Stack count using AuraAPI:GetApplicationDisplayCount
    if settings.showStacks and icon.stackText and AuraAPI then
        local stackText = AuraAPI:GetApplicationDisplayCount(unit, auraInstanceID, 2)
        if stackText then
            icon.stackText:SetText(stackText)
            icon.stackText:Show()
        else
            icon.stackText:Hide()
        end
    else
        icon.stackText:Hide()
    end
    
    -- Duration text is now handled by Blizzard's CooldownFrameTemplate
    -- with SetHideCountdownNumbers(false) - works with secret values and abbreviates times
    if icon.durationText then
        icon.durationText:Hide()
    end
    
    -- Border color by dispel type
    if settings.colorByDispelType then
        local dispelColors = {
            Magic = {0.2, 0.6, 1.0},
            Curse = {0.6, 0.0, 1.0},
            Disease = {0.6, 0.4, 0.0},
            Poison = {0.0, 0.6, 0.0},
        }
        pcall(function()
            local color = dispelColors[auraData.dispelName]
            if color then
                icon:SetBackdropBorderColor(color[1], color[2], color[3], 1)
            else
                icon:SetBackdropBorderColor(0, 0, 0, 1)
            end
        end)
    else
        icon:SetBackdropBorderColor(0, 0, 0, 1)
    end
    
    icon:Show()
    return true
end

-- ============================================================================
-- CONTAINER UPDATE - DandersFrames-style approach
-- ============================================================================

function Auras:UpdateAuraContainer(container, unit, settings)
    if not container or not unit or not UnitExists(unit) then
        if container then container:Hide() end
        return
    end
    
    if not settings or not settings.enabled then
        container:Hide()
        return
    end
    
    container:Show()
    
    local auraType = container.containerType
    local maxIcons = settings.maxAuras or MAX_AURA_ICONS
    local hidePermanent = settings.hidePermanent == true
    local onlyShowMine = settings.onlyShowMine == true
    local iconSize = settings.size or DEFAULT_ICON_SIZE
    local spacing = settings.spacing or DEFAULT_ICON_SPACING
    local growDirection = settings.growDirection or "RIGHT"
    
    -- Build filter string
    local filter = auraType == "debuffs" and "HARMFUL" or "HELPFUL"
    if onlyShowMine then
        filter = filter .. "|PLAYER"
    end
    
    -- Hide all icons first
    for _, icon in ipairs(container.icons) do
        icon:Hide()
        icon.auraInstanceID = nil
        icon.unit = nil
        icon.spellName = nil
    end
    
    -- Collect auras using AuraAPI wrapper
    -- Use cached table to avoid allocations
    wipe(auraCollectionCache)
    local auras = auraCollectionCache
    
    -- Try AuraAPI:GetAuraInstanceIDs with sorting
    if AuraAPI then
        local sortRule = Enum.UnitAuraSortRule.Default
        local sortDirection = Enum.UnitAuraSortDirection.Normal
        
        local auraIDs = AuraAPI:GetAuraInstanceIDs(unit, filter, maxIcons * 2, sortRule, sortDirection)
        
        if auraIDs then
            for _, auraID in ipairs(auraIDs) do
                local auraData = AuraAPI:GetAuraDataByInstanceID(unit, auraID)
                if auraData then
                    table.insert(auras, auraData)
                end
            end
        end
    end
    
    -- Fallback: use AuraUtil.ForEachAura
    if #auras == 0 and AuraUtil and AuraUtil.ForEachAura then
        pcall(function()
            AuraUtil.ForEachAura(unit, filter, maxIcons * 2, function(aura)
                if aura then
                    table.insert(auras, aura)
                end
                return #auras >= maxIcons * 2
            end, true)
        end)
    end
    
    -- Fallback: use AuraAPI:GetAuraDataByIndex
    if #auras == 0 and AuraAPI then
        for i = 1, maxIcons * 2 do
            local aura = AuraAPI:GetAuraDataByIndex(unit, i, filter)
            if aura then
                table.insert(auras, aura)
            else
                break
            end
        end
    end
    
    -- Update icons with aura data (same approach as target frame)
    local displayedCount = 0
    
    for _, auraData in ipairs(auras) do
        if displayedCount >= maxIcons then break end
        
        local icon = container.icons[displayedCount + 1]
        if not icon then break end
        
        -- Key insight from DandersFrames/target frame: try to set texture first
        -- If pcall succeeds, the aura can be displayed
        local textureSet = false
        pcall(function()
            icon.texture:SetTexture(auraData.icon)
            icon.texture:SetVertexColor(1, 1, 1, 1)
            textureSet = true
        end)
        
        if not textureSet then
            -- Skip this aura, can't display it
        else
            -- Get auraInstanceID
            local auraInstanceID = nil
            pcall(function() auraInstanceID = auraData.auraInstanceID end)
            
            -- Filter out permanent buffs if setting enabled
            local shouldDisplay = true
            if hidePermanent and AuraAPI and auraInstanceID then
                local hasExpiration = AuraAPI:HasExpirationTime(unit, auraInstanceID)
                if not hasExpiration then
                    shouldDisplay = false
                end
            end
            
            if shouldDisplay then
                displayedCount = displayedCount + 1
                
                -- Store data for tooltip and right-click cancel
                icon.auraInstanceID = auraInstanceID
                icon.unit = unit
                icon.auraType = auraType == "debuffs" and "DEBUFF" or "BUFF"
                
                -- Store spell name for right-click cancel (only works for player buffs)
                pcall(function()
                    icon.spellName = auraData.name
                end)
                
                -- Show texture
                icon.texture:Show()
                
                -- Set icon size
                icon:SetSize(iconSize, iconSize)
                
                -- Set cooldown using DurationAPI or fallback
                if icon.cooldown then
                    local cooldownSet = false
                    if DurationAPI and auraInstanceID then
                        cooldownSet = DurationAPI:ApplyAuraDurationToFrame(icon.cooldown, unit, auraInstanceID, true)
                    end
                    
                    if not cooldownSet then
                        pcall(function()
                            if icon.cooldown.SetCooldownFromExpirationTime then
                                icon.cooldown:SetCooldownFromExpirationTime(auraData.expirationTime, auraData.duration)
                            end
                        end)
                    end
                    
                    -- Show/hide cooldown based on whether aura has expiration
                    if AuraAPI and auraInstanceID and icon.cooldown.SetShownFromBoolean then
                        local hasExp = AuraAPI:HasExpirationTime(unit, auraInstanceID)
                        icon.cooldown:SetShownFromBoolean(hasExp, settings.showDuration ~= false, false)
                    elseif settings.showDuration ~= false then
                        icon.cooldown:Show()
                    else
                        icon.cooldown:Hide()
                    end
                end
                
                -- Set stack count using AuraAPI
                if icon.stackText then
                    -- Apply font size from settings
                    local stackFontSize = settings.stackFontSize or 9
                    icon.stackText:SetFont("Fonts\\FRIZQT__.TTF", stackFontSize, "OUTLINE")
                    
                    icon.stackText:SetText("")
                    if settings.showStacks and auraInstanceID and AuraAPI then
                        local stackText = AuraAPI:GetApplicationDisplayCount(unit, auraInstanceID, 2)
                        if stackText then
                            icon.stackText:SetText(stackText)
                            icon.stackText:Show()
                        else
                            icon.stackText:Hide()
                        end
                    else
                        icon.stackText:Hide()
                    end
                end
                
                -- Duration text - handled by Blizzard's CooldownFrameTemplate now
                if icon.durationText then
                    icon.durationText:Hide()
                end
                
                -- Border color by dispel type
                if settings.colorByDispelType then
                    local dispelColors = {
                        Magic = {0.2, 0.6, 1.0},
                        Curse = {0.6, 0.0, 1.0},
                        Disease = {0.6, 0.4, 0.0},
                        Poison = {0.0, 0.6, 0.0},
                    }
                    pcall(function()
                        local color = dispelColors[auraData.dispelName]
                        if color then
                            icon:SetBackdropBorderColor(color[1], color[2], color[3], 1)
                        else
                            icon:SetBackdropBorderColor(0, 0, 0, 1)
                        end
                    end)
                else
                    icon:SetBackdropBorderColor(0, 0, 0, 1)
                end
                
                -- Position icon
                icon:ClearAllPoints()
                local xOffset = (displayedCount - 1) * (iconSize + spacing)
                local yOffset = (displayedCount - 1) * (iconSize + spacing)
                
                if growDirection == "RIGHT" then
                    icon:SetPoint("LEFT", container, "LEFT", xOffset, 0)
                elseif growDirection == "LEFT" then
                    icon:SetPoint("RIGHT", container, "RIGHT", -xOffset, 0)
                elseif growDirection == "DOWN" then
                    icon:SetPoint("TOP", container, "TOP", 0, -yOffset)
                elseif growDirection == "UP" then
                    icon:SetPoint("BOTTOM", container, "BOTTOM", 0, yOffset)
                end
                
                icon:Show()
            end
        end
    end
    
    -- DEBUG
    if auraDebugEnabled then
        print(string.format("|cffff9900TUI Auras:|r %s %s: displayed %d icons", unit, auraType, displayedCount))
    end
    
    -- Resize and show/hide container
    if displayedCount > 0 then
        if growDirection == "RIGHT" or growDirection == "LEFT" then
            container:SetSize(displayedCount * (iconSize + spacing) - spacing, iconSize)
        else
            container:SetSize(iconSize, displayedCount * (iconSize + spacing) - spacing)
        end
        container:Show()
    else
        container:Hide()
    end
end

-- ============================================================================
-- FRAME INTEGRATION
-- ============================================================================

function Auras:SetupFrame(frame, settings)
    if not frame then return end
    
    if settings.buffs and settings.buffs.enabled then
        if not frame.buffContainer then
            frame.buffContainer = self:CreateAuraContainer(frame, "buffs")
        end
        
        local anchor = settings.buffs.anchor or "BOTTOMLEFT"
        local frameAnchor = settings.buffs.frameAnchor or "TOPLEFT"
        local xOff = settings.buffs.offsetX or 0
        local yOff = settings.buffs.offsetY or 2
        
        frame.buffContainer:ClearAllPoints()
        frame.buffContainer:SetPoint(anchor, frame, frameAnchor, xOff, yOff)
    end
    
    if settings.debuffs and settings.debuffs.enabled then
        if not frame.auraDebuffContainer then
            frame.auraDebuffContainer = self:CreateAuraContainer(frame, "debuffs")
        end
        
        local anchor = settings.debuffs.anchor or "TOPLEFT"
        local frameAnchor = settings.debuffs.frameAnchor or "BOTTOMLEFT"
        local xOff = settings.debuffs.offsetX or 0
        local yOff = settings.debuffs.offsetY or -2
        
        frame.auraDebuffContainer:ClearAllPoints()
        frame.auraDebuffContainer:SetPoint(anchor, frame, frameAnchor, xOff, yOff)
    end
end

function Auras:UpdateFrame(frame, unit, settings)
    if not frame or not unit then return end
    
    if frame.buffContainer and settings.buffs then
        self:UpdateAuraContainer(frame.buffContainer, unit, settings.buffs)
    end
    
    if frame.auraDebuffContainer and settings.debuffs then
        self:UpdateAuraContainer(frame.auraDebuffContainer, unit, settings.debuffs)
    end
end

function Auras:HideAll(frame)
    if not frame then return end
    
    if frame.buffContainer then
        frame.buffContainer:Hide()
    end
    if frame.auraDebuffContainer then
        frame.auraDebuffContainer:Hide()
    end
end

-- ============================================================================
-- DEBUG FUNCTIONS
-- ============================================================================

function Auras:DebugCache()
    print("|cff00ff00TweaksUI Auras Debug:|r")
    print("  Blizzard hooks setup:", BlizzardHooksSetup and "Yes" or "No")
    print("  CompactUnitFrame_UpdateAuras exists:", CompactUnitFrame_UpdateAuras and "Yes" or "No")
    print("  CompactUnitFrame_UpdateBuffs exists:", CompactUnitFrame_UpdateBuffs and "Yes" or "No")
    print("  CompactPartyFrame exists:", CompactPartyFrame and "Yes" or "No")
    print("  CompactRaidFrameContainer exists:", CompactRaidFrameContainer and "Yes" or "No")
    
    local cacheCount = 0
    for unit, cache in pairs(BlizzardAuraCache) do
        cacheCount = cacheCount + 1
        local buffCount = 0
        local debuffCount = 0
        for _ in pairs(cache.buffs or {}) do buffCount = buffCount + 1 end
        for _ in pairs(cache.debuffs or {}) do debuffCount = debuffCount + 1 end
        print(string.format("  Cache[%s]: %d buffs, %d debuffs", unit, buffCount, debuffCount))
    end
    
    if cacheCount == 0 then
        print("  |cffff0000No units in cache!|r")
        print("  This usually means CompactUnitFrames aren't updating.")
        print("  Try enabling 'Use Raid-Style Party Frames' in Interface > Edit Mode")
    end
end

function Auras:DebugBlizzardFrames()
    print("|cff00ff00TweaksUI Auras - Blizzard Frame Debug:|r")
    
    -- Check CompactPartyFrame members
    for i = 1, 5 do
        local frame = _G["CompactPartyFrameMember" .. i]
        if frame then
            print(string.format("  CompactPartyFrameMember%d:", i))
            print("    unit:", frame.unit or "nil")
            print("    buffFrames:", frame.buffFrames and #frame.buffFrames or "nil")
            print("    debuffFrames:", frame.debuffFrames and #frame.debuffFrames or "nil")
            
            if frame.buffFrames and frame.buffFrames[1] then
                local bf = frame.buffFrames[1]
                print("    buffFrames[1]:IsShown():", bf:IsShown())
                print("    buffFrames[1].auraInstanceID:", bf.auraInstanceID or "nil")
                -- Check for alternative field names
                for k, v in pairs(bf) do
                    if type(k) == "string" and k:lower():find("aura") then
                        print("    buffFrames[1]." .. k .. ":", tostring(v))
                    end
                end
            end
        end
    end
    
    -- Check first CompactRaidFrame
    local raidFrame = _G["CompactRaidFrame1"]
    if raidFrame then
        print("  CompactRaidFrame1:")
        print("    unit:", raidFrame.unit or "nil")
        print("    buffFrames:", raidFrame.buffFrames and #raidFrame.buffFrames or "nil")
        
        if raidFrame.buffFrames and raidFrame.buffFrames[1] then
            local bf = raidFrame.buffFrames[1]
            print("    buffFrames[1]:IsShown():", bf:IsShown())
            print("    buffFrames[1].auraInstanceID:", bf.auraInstanceID or "nil")
        end
    end
end

-- Slash command for debug
SLASH_TUIAURAS1 = "/tuiauras"
SlashCmdList["TUIAURAS"] = function(msg)
    if msg == "debug" then
        Auras:DebugCache()
    elseif msg == "frames" then
        Auras:DebugBlizzardFrames()
    elseif msg == "scan" then
        ScanAllBlizzardFrames()
        print("|cff00ff00TweaksUI:|r Scanned Blizzard frames")
        Auras:DebugCache()
    elseif msg == "combat" then
        auraDebugEnabled = not auraDebugEnabled
        print("|cff00ff00TweaksUI:|r Combat aura debug " .. (auraDebugEnabled and "ENABLED" or "DISABLED"))
    elseif msg == "test" then
        -- Test aura collection on party1
        local unit = "party1"
        if not UnitExists(unit) then
            unit = "player"
        end
        print("|cff00ff00TweaksUI Auras Test:|r Testing on " .. unit)
        print("  InCombatLockdown:", InCombatLockdown() and "Yes" or "No")
        
        local filter = "HELPFUL"
        local slot = 1
        local count = 0
        
        while slot <= 10 do
            local auraData = AuraAPI and AuraAPI:GetAuraDataByIndex(unit, slot, filter)
            if not auraData then 
                print("  Slot " .. slot .. ": nil auraData")
                break 
            end
            
            local auraID = nil
            pcall(function() auraID = auraData.auraInstanceID end)
            
            local iconOK = false
            pcall(function()
                -- Just test if we can access the icon at all
                local _ = auraData.icon
                iconOK = true
            end)
            
            print(string.format("  Slot %d: auraID=%s, iconAccessible=%s", 
                slot, 
                tostring(auraID), 
                iconOK and "Yes" or "No"))
            
            count = count + 1
            slot = slot + 1
        end
        
        print("  Total auras found: " .. count)
    else
        print("|cff00ff00TweaksUI Auras:|r /tuiauras debug - Show cache status")
        print("|cff00ff00TweaksUI Auras:|r /tuiauras frames - Debug Blizzard frame structure")
        print("|cff00ff00TweaksUI Auras:|r /tuiauras scan - Force scan Blizzard frames")
        print("|cff00ff00TweaksUI Auras:|r /tuiauras test - Test aura collection")
        print("|cff00ff00TweaksUI Auras:|r /tuiauras combat - Toggle combat debug spam")
    end
end

-- ============================================================================
-- BATCH UPDATE FUNCTIONS
-- ============================================================================

function Auras:UpdatePartyFrames(partyFrames, settings)
    if not partyFrames or not settings then return end
    
    for i, frame in ipairs(partyFrames) do
        if frame and frame:IsShown() and frame.unit then
            self:UpdateFrame(frame, frame.unit, settings)
        elseif frame then
            self:HideAll(frame)
        end
    end
end

function Auras:UpdateRaidFrames(raidFrames, settings)
    if not raidFrames or not settings then return end
    
    for i, frame in ipairs(raidFrames) do
        if frame and frame:IsShown() and frame.unit then
            self:UpdateFrame(frame, frame.unit, settings)
        elseif frame then
            self:HideAll(frame)
        end
    end
end

-- ============================================================================
-- EVENT HANDLING
-- ============================================================================

local eventFrame = CreateFrame("Frame")

local function OnEvent(self, event, unit, ...)
    if event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
        -- Setup hooks and scan frames
        SetupBlizzardHooks()
        C_Timer.After(0.1, ScanAllBlizzardFrames)
        C_Timer.After(0.5, ScanAllBlizzardFrames)
        C_Timer.After(1.5, ScanAllBlizzardFrames)
    end
end

eventFrame:SetScript("OnEvent", OnEvent)

function Auras:Start()
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    SetupBlizzardHooks()
    ScanAllBlizzardFrames()
end

function Auras:Stop()
    eventFrame:UnregisterEvent("GROUP_ROSTER_UPDATE")
end

function Auras:ForceScan()
    ScanAllBlizzardFrames()
end

-- Auto-start
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:HookScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        Auras:Start()
    end
end)

return Auras
