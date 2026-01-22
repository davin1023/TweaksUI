-- TweaksUI Defensive Icons Submodule
-- Shows prominent icon when a unit has a major defensive cooldown active
-- Midnight-compatible using Duration Objects and secret-safe APIs

local ADDON_NAME, TweaksUI = ...

local DefensiveIcons = {}
TweaksUI.DefensiveIcons = DefensiveIcons

-- ============================================================================
-- MIDNIGHT API WRAPPERS (v2.0.0)
-- ============================================================================

local AuraAPI = TweaksUI.AuraAPI
local DurationAPI = TweaksUI.DurationAPI

-- ============================================================================
-- MAJOR DEFENSIVE SPELL DATABASE
-- These are spells that warrant a prominent display when active
-- ============================================================================

-- Tank personal defensives
local TANK_DEFENSIVES = {
    -- Death Knight
    [48707] = true,   -- Anti-Magic Shell
    [48792] = true,   -- Icebound Fortitude
    [49028] = true,   -- Dancing Rune Weapon
    [55233] = true,   -- Vampiric Blood
    [194679] = true,  -- Rune Tap
    [219809] = true,  -- Tombstone
    [194844] = true,  -- Bonestorm
    
    -- Demon Hunter
    [187827] = true,  -- Metamorphosis (Vengeance)
    [203720] = true,  -- Demon Spikes
    [204021] = true,  -- Fiery Brand
    [263648] = true,  -- Soul Barrier
    
    -- Druid
    [22812] = true,   -- Barkskin
    [61336] = true,   -- Survival Instincts
    [102558] = true,  -- Incarnation: Guardian of Ursoc
    [200851] = true,  -- Rage of the Sleeper
    [203975] = true,  -- Earthwarden (buff)
    [192081] = true,  -- Ironfur
    
    -- Monk
    [115176] = true,  -- Zen Meditation
    [115203] = true,  -- Fortifying Brew
    [122278] = true,  -- Dampen Harm
    [122783] = true,  -- Diffuse Magic
    [132578] = true,  -- Invoke Niuzao
    [322507] = true,  -- Celestial Brew
    
    -- Paladin
    [31850] = true,   -- Ardent Defender
    [86659] = true,   -- Guardian of Ancient Kings
    [132403] = true,  -- Shield of the Righteous
    [204018] = true,  -- Blessing of Spellwarding
    [642] = true,     -- Divine Shield
    [498] = true,     -- Divine Protection
    
    -- Warrior
    [871] = true,     -- Shield Wall
    [12975] = true,   -- Last Stand
    [23920] = true,   -- Spell Reflection
    [184364] = true,  -- Enraged Regeneration
    [190456] = true,  -- Ignore Pain
    [132404] = true,  -- Shield Block
    [97462] = true,   -- Rallying Cry (raid-wide)
    [118038] = true,  -- Die by the Sword (Arms)
}

-- External defensives (cast on others)
local EXTERNAL_DEFENSIVES = {
    -- Priest
    [33206] = true,   -- Pain Suppression
    [47788] = true,   -- Guardian Spirit
    [62618] = true,   -- Power Word: Barrier (standing in it)
    [271466] = true,  -- Luminous Barrier
    
    -- Paladin
    [1022] = true,    -- Blessing of Protection
    [6940] = true,    -- Blessing of Sacrifice
    [204018] = true,  -- Blessing of Spellwarding
    [31821] = true,   -- Aura Mastery
    
    -- Druid
    [102342] = true,  -- Ironbark
    
    -- Monk
    [116849] = true,  -- Life Cocoon
    
    -- Shaman
    [98008] = true,   -- Spirit Link Totem (standing in it)
    [108271] = true,  -- Astral Shift
    
    -- Evoker
    [357170] = true,  -- Time Dilation
    [363534] = true,  -- Rewind
    [374227] = true,  -- Zephyr
    
    -- Death Knight
    [51052] = true,   -- Anti-Magic Zone
}

-- DPS personals that are significant enough to show
local DPS_DEFENSIVES = {
    -- Mage
    [45438] = true,   -- Ice Block
    [414658] = true,  -- Ice Cold (Ice Block variant)
    [110960] = true,  -- Greater Invisibility
    
    -- Hunter
    [186265] = true,  -- Aspect of the Turtle
    [264735] = true,  -- Survival of the Fittest
    
    -- Rogue
    [31224] = true,   -- Cloak of Shadows
    [5277] = true,    -- Evasion
    [1966] = true,    -- Feint
    
    -- Warlock
    [104773] = true,  -- Unending Resolve
    [108416] = true,  -- Dark Pact
    
    -- General
    [6262] = true,    -- Healthstone (not really a defensive but...)
}

-- Build combined lookup table
local ALL_DEFENSIVES = {}
for spellID in pairs(TANK_DEFENSIVES) do ALL_DEFENSIVES[spellID] = "TANK" end
for spellID in pairs(EXTERNAL_DEFENSIVES) do ALL_DEFENSIVES[spellID] = "EXTERNAL" end
for spellID in pairs(DPS_DEFENSIVES) do ALL_DEFENSIVES[spellID] = "DPS" end

-- Priority order (externals shown first, then tank, then DPS)
local PRIORITY_ORDER = { EXTERNAL = 1, TANK = 2, DPS = 3 }

-- ============================================================================
-- DEFENSIVE ICON CREATION
-- ============================================================================

-- Create defensive icon element on a frame
function DefensiveIcons:CreateDefensiveIcon(frame)
    if not frame then return nil end
    if frame.defensiveIcon then return frame.defensiveIcon end
    
    local iconSize = 28
    local borderSize = 2
    
    -- Use content overlay if available (higher strata), otherwise create one
    local iconParent = frame.contentOverlay or frame
    
    -- If no content overlay exists, we'll use high frame level
    local baseLevel = iconParent:GetFrameLevel()
    
    -- Create container frame at HIGH strata for visibility
    local icon = CreateFrame("Frame", nil, iconParent)
    icon:SetFrameStrata("HIGH")
    icon:SetSize(iconSize, iconSize)
    icon:SetPoint("CENTER", frame, "CENTER", 0, 0)
    icon:SetFrameLevel(baseLevel + 50)  -- Very high to be on top
    icon:Hide()
    
    -- Border textures (green by default for defensives)
    icon.borderLeft = icon:CreateTexture(nil, "BACKGROUND")
    icon.borderLeft:SetPoint("TOPLEFT", 0, 0)
    icon.borderLeft:SetPoint("BOTTOMLEFT", 0, 0)
    icon.borderLeft:SetWidth(borderSize)
    icon.borderLeft:SetColorTexture(0, 0.8, 0, 1)
    
    icon.borderRight = icon:CreateTexture(nil, "BACKGROUND")
    icon.borderRight:SetPoint("TOPRIGHT", 0, 0)
    icon.borderRight:SetPoint("BOTTOMRIGHT", 0, 0)
    icon.borderRight:SetWidth(borderSize)
    icon.borderRight:SetColorTexture(0, 0.8, 0, 1)
    
    icon.borderTop = icon:CreateTexture(nil, "BACKGROUND")
    icon.borderTop:SetPoint("TOPLEFT", borderSize, 0)
    icon.borderTop:SetPoint("TOPRIGHT", -borderSize, 0)
    icon.borderTop:SetHeight(borderSize)
    icon.borderTop:SetColorTexture(0, 0.8, 0, 1)
    
    icon.borderBottom = icon:CreateTexture(nil, "BACKGROUND")
    icon.borderBottom:SetPoint("BOTTOMLEFT", borderSize, 0)
    icon.borderBottom:SetPoint("BOTTOMRIGHT", -borderSize, 0)
    icon.borderBottom:SetHeight(borderSize)
    icon.borderBottom:SetColorTexture(0, 0.8, 0, 1)
    
    -- Icon texture
    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetPoint("TOPLEFT", borderSize, -borderSize)
    icon.texture:SetPoint("BOTTOMRIGHT", -borderSize, borderSize)
    icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    
    -- Cooldown frame for duration display
    icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.cooldown:SetAllPoints(icon.texture)
    icon.cooldown:SetDrawEdge(false)
    icon.cooldown:SetDrawSwipe(true)
    icon.cooldown:SetReverse(true)
    icon.cooldown:SetHideCountdownNumbers(false)
    
    -- Stack count text
    icon.count = icon:CreateFontString(nil, "OVERLAY")
    icon.count:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    icon.count:SetPoint("BOTTOMRIGHT", -1, 1)
    icon.count:SetTextColor(1, 1, 1, 1)
    
    -- Duration text (countdown numbers)
    icon.durationText = icon:CreateFontString(nil, "OVERLAY")
    icon.durationText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    icon.durationText:SetPoint("CENTER", icon, "CENTER", 0, 0)
    icon.durationText:SetTextColor(1, 1, 0.6, 1)
    icon.durationText:Hide()
    
    -- Enable mouse for tooltips
    icon:EnableMouse(true)
    icon.unitFrame = frame
    
    -- Tooltip on hover
    icon:SetScript("OnEnter", function(self)
        -- Skip tooltips in combat to avoid secret value issues
        if InCombatLockdown() then return end
        
        if not self:IsShown() or not self.auraData then return end
        
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        if self.auraData.auraInstanceID and self.unitFrame and self.unitFrame.unit then
            local success = false
            -- Use AuraAPI for consistent tooltip handling
            if AuraAPI then
                success = AuraAPI:SetTooltipBuff(GameTooltip, self.unitFrame.unit, self.auraData.auraInstanceID)
            elseif GameTooltip.SetUnitBuffByAuraInstanceID then
                success = pcall(GameTooltip.SetUnitBuffByAuraInstanceID, GameTooltip, self.unitFrame.unit, self.auraData.auraInstanceID)
            end
        end
        GameTooltip:Show()
    end)
    
    icon:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    frame.defensiveIcon = icon
    return icon
end

-- ============================================================================
-- BLIZZARD DEFENSIVE CACHE
-- Uses Blizzard's CenterDefensiveBuff frame to know which aura to display
-- This is Midnight-compatible because we're not scanning spellIds ourselves
-- ============================================================================

local blizzardDefensiveCache = {}  -- unit -> auraInstanceID

-- Capture defensive from Blizzard's CompactUnitFrame
local function CaptureDefensiveFromBlizzardFrame(frame, triggerUpdate)
    if not frame or not frame.unit then return end
    
    -- Skip nameplates, preview frames, and settings frames
    local frameName = nil
    if frame.GetName and type(frame.GetName) == "function" then
        local ok, name = pcall(frame.GetName, frame)
        if ok then frameName = name end
    end
    
    if not frameName then
        -- Anonymous frame - skip if it looks like a nameplate
        if frame.unit and type(frame.unit) == "string" and frame.unit:find("nameplate") then
            return
        end
    else
        -- Has a name - skip preview/settings frames
        if frameName:find("Preview") or frameName:find("Settings") or frameName:find("NamePlate") then
            return
        end
    end
    
    local unit = frame.unit
    
    -- Clear existing cache for this unit
    blizzardDefensiveCache[unit] = nil
    
    -- Check CenterDefensiveBuff (this is what Blizzard shows for big defensives)
    if frame.CenterDefensiveBuff then
        local defFrame = frame.CenterDefensiveBuff
        if defFrame:IsShown() and defFrame.auraInstanceID then
            blizzardDefensiveCache[unit] = defFrame.auraInstanceID
        end
    end
    
    -- Trigger update on our frames if requested
    if triggerUpdate then
        C_Timer.After(0, function()
            local UnitFrames = TweaksUI.UnitFrames
            if not UnitFrames then return end
            
            -- Update party frames
            local partyFrames = UnitFrames:GetPartyMemberFrames()
            local partySettings = UnitFrames:GetPartySettings()
            if partyFrames and partySettings and partySettings.defensiveIcon and partySettings.defensiveIcon.enabled then
                for _, ourFrame in ipairs(partyFrames) do
                    if ourFrame and ourFrame.unit then
                        local isSameUnit = false
                        pcall(function()
                            isSameUnit = UnitIsUnit(ourFrame.unit, unit)
                        end)
                        if isSameUnit then
                            DefensiveIcons:UpdateDefensiveIcon(ourFrame, partySettings.defensiveIcon)
                            break
                        end
                    end
                end
            end
            
            -- Update raid frames
            local raidFrames = UnitFrames:GetRaidMemberFrames()
            local raidSettings = UnitFrames:GetCurrentRaidSettings()
            if raidFrames and raidSettings and raidSettings.defensiveIcon and raidSettings.defensiveIcon.enabled then
                for _, ourFrame in ipairs(raidFrames) do
                    if ourFrame and ourFrame.unit then
                        local isSameUnit = false
                        pcall(function()
                            isSameUnit = UnitIsUnit(ourFrame.unit, unit)
                        end)
                        if isSameUnit then
                            DefensiveIcons:UpdateDefensiveIcon(ourFrame, raidSettings.defensiveIcon)
                            break
                        end
                    end
                end
            end
        end)
    end
end

-- Scan ALL Blizzard compact frames to build cache (like Danders)
local function ScanAllBlizzardFrames()
    -- Scan party frames
    for i = 1, 5 do
        local frame = _G["CompactPartyFrameMember" .. i]
        if frame then
            CaptureDefensiveFromBlizzardFrame(frame, true)
        end
    end
    
    -- Scan raid frames (direct)
    for i = 1, 40 do
        local frame = _G["CompactRaidFrame" .. i]
        if frame then
            CaptureDefensiveFromBlizzardFrame(frame, true)
        end
    end
    
    -- Scan raid group frames
    for group = 1, 8 do
        for member = 1, 5 do
            local frame = _G["CompactRaidGroup" .. group .. "Member" .. member]
            if frame then
                CaptureDefensiveFromBlizzardFrame(frame, true)
            end
        end
    end
end

-- Hook Blizzard's CompactUnitFrame aura update
local blizzardHooked = false
local function SetupBlizzardHooks()
    if blizzardHooked then return end
    
    -- Hook CompactUnitFrame_UpdateAuras if it exists
    if CompactUnitFrame_UpdateAuras then
        hooksecurefunc("CompactUnitFrame_UpdateAuras", function(frame)
            -- CRITICAL: Use C_Timer.After(0) to break taint chain
            -- This prevents our addon code from tainting Blizzard's secure execution path
            C_Timer.After(0, function()
                CaptureDefensiveFromBlizzardFrame(frame, true)
            end)
        end)
        blizzardHooked = true
    end
    
    -- Also do an initial scan after a short delay
    C_Timer.After(0.5, ScanAllBlizzardFrames)
end

-- Force rescan of all Blizzard frames (can be called manually)
function DefensiveIcons:ForceScanBlizzardFrames()
    ScanAllBlizzardFrames()
end

-- Get cached defensive auraInstanceID for a unit
function DefensiveIcons:GetCachedDefensiveID(unit)
    if not unit then return nil end
    
    -- Direct lookup
    if blizzardDefensiveCache[unit] then
        return blizzardDefensiveCache[unit]
    end
    
    -- Try to find matching unit (in case of party1 vs raid5 for same player)
    for cachedUnit, auraInstanceID in pairs(blizzardDefensiveCache) do
        local isSame = false
        pcall(function()
            isSame = UnitIsUnit(cachedUnit, unit)
        end)
        if isSame then
            return auraInstanceID
        end
    end
    
    return nil
end

-- ============================================================================
-- FALLBACK: DIRECT AURA SCANNING (for when Blizzard frames aren't available)
-- This is used as a fallback when CenterDefensiveBuff isn't providing data
-- Updated for Midnight to use GetUnitAuraInstanceIDs and avoid secret comparisons
-- ============================================================================

-- Direct scan for defensive aura (fallback method)
local function ScanForDefensiveAura(unit)
    local bestAura = nil
    local bestAuraInstanceID = nil
    local bestPriority = 999
    
    -- Use AuraAPI to get aura instance IDs
    local auraIDs = AuraAPI and AuraAPI:GetAuraInstanceIDs(unit, "HELPFUL")
    
    if auraIDs and #auraIDs > 0 then
        -- Iterate through aura IDs
        for _, auraInstanceID in ipairs(auraIDs) do
            local auraData = AuraAPI:GetAuraDataByInstanceID(unit, auraInstanceID)
            
            if auraData then
                local spellID = auraData.spellId
                
                -- Check if spellId is secret
                local isSecret = issecretvalue and issecretvalue(spellID)
                
                if spellID and not isSecret and ALL_DEFENSIVES[spellID] then
                    local category = ALL_DEFENSIVES[spellID]
                    local priority = PRIORITY_ORDER[category] or 999
                    
                    -- Prefer higher priority (lower number)
                    -- During secret restrictions, we can't compare expiration times
                    -- so just take the first/best priority match
                    if priority < bestPriority then
                        bestAura = auraData
                        bestAuraInstanceID = auraInstanceID
                        bestPriority = priority
                        
                        -- If we found EXTERNAL (highest priority), we can stop
                        if priority == 1 then
                            break
                        end
                    end
                end
            end
        end
    else
        -- Fallback: use AuraAPI:GetAuraDataByIndex
        local i = 1
        while true do
            local auraData = AuraAPI and AuraAPI:GetAuraDataByIndex(unit, i, "HELPFUL")
            
            if not auraData then break end
            
            local spellID = auraData.spellId
            
            -- In Midnight, spellId can be a secret value that can't be used as a table index
            -- Check if it's secret first, and skip if so
            local isSecret = issecretvalue and issecretvalue(spellID)
            
            if spellID and not isSecret and ALL_DEFENSIVES[spellID] then
                local category = ALL_DEFENSIVES[spellID]
                local priority = PRIORITY_ORDER[category] or 999
                
                -- Check if expiration is secret - if so, skip the duration comparison
                local expiration = auraData.expirationTime
                local isExpirationSecret = issecretvalue and expiration and issecretvalue(expiration)
                
                -- Prefer higher priority (lower number)
                -- If not in secret mode, also prefer longer remaining duration
                local isBetter = false
                if priority < bestPriority then
                    isBetter = true
                elseif priority == bestPriority and not isExpirationSecret then
                    -- Can safely compare expiration times
                    local bestExpiration = bestAura and bestAura.expirationTime or 0
                    if expiration and expiration > bestExpiration then
                        isBetter = true
                    end
                end
                
                if isBetter then
                    bestAura = auraData
                    bestAuraInstanceID = auraData.auraInstanceID
                    bestPriority = priority
                end
            end
            
            i = i + 1
            if i > 40 then break end  -- Safety limit
        end
    end
    
    return bestAura, bestAuraInstanceID
end

-- Find the best defensive aura on a unit
-- Uses Midnight's BigDefensive sortRule when available (cleanest approach)
-- Falls back to Blizzard's CenterDefensiveBuff cache, then our own database scan
-- Returns auraData and auraInstanceID
function DefensiveIcons:FindDefensiveAura(unit)
    if not unit or not UnitExists(unit) then return nil, nil end
    
    -- Method 1: Use Blizzard's CenterDefensiveBuff cache (works in all scenarios)
    local cachedAuraID = self:GetCachedDefensiveID(unit)
    if cachedAuraID then
        local auraData = AuraAPI and AuraAPI:GetAuraDataByInstanceID(unit, cachedAuraID)
        if auraData then
            return auraData, cachedAuraID
        end
        -- Aura expired but cache is stale - clear it
        blizzardDefensiveCache[unit] = nil
    end
    
    -- Method 2: Scan our database - only works when spellIDs aren't secret
    if AuraAPI then
        -- Use BigDefensive sort to get defensives first, then validate against our list
        local auras = AuraAPI:GetUnitAuras(unit, "HELPFUL", Enum.UnitAuraSortRule.BigDefensive)
        if auras then
            for _, auraData in ipairs(auras) do
                if auraData then
                    local spellID = auraData.spellId
                    
                    -- Check if spellID is secret
                    local isSecret = issecretvalue and spellID and issecretvalue(spellID)
                    
                    if isSecret then
                        -- In combat with secrets: we can't validate, skip this method
                        -- We already tried CenterDefensiveBuff above, so nothing more we can do
                        break
                    elseif spellID and ALL_DEFENSIVES[spellID] then
                        -- Out of combat: we can validate against our list
                        return auraData, auraData.auraInstanceID
                    end
                end
            end
        end
    end
    
    return nil, nil
end

-- Update defensive icon for a single frame
function DefensiveIcons:UpdateDefensiveIcon(frame, settings)
    if not frame or not frame.unit then return end
    
    local icon = frame.defensiveIcon
    if not icon then
        icon = self:CreateDefensiveIcon(frame)
    end
    
    -- Safety check - if icon still doesn't exist, bail
    if not icon then return end
    
    -- Check if feature is enabled
    if not settings or not settings.enabled then
        icon:Hide()
        frame.tuiLastDefensiveState = nil
        return
    end
    
    local unit = frame.unit
    
    -- Check if unit exists
    if not UnitExists(unit) then
        icon:Hide()
        frame.tuiLastDefensiveState = nil
        return
    end
    
    -- Find defensive aura
    local auraData, auraInstanceID = self:FindDefensiveAura(unit)
    
    -- If no defensive found, hide and clear cache
    if not auraData then
        icon:Hide()
        frame.tuiLastDefensiveState = nil
        return
    end
    
    -- PERFORMANCE OPTIMIZATION: Cache defensive state to skip redundant updates
    local stateKey = auraInstanceID or 0
    if frame.tuiLastDefensiveState == stateKey then
        return  -- Same aura, skip update
    end
    frame.tuiLastDefensiveState = stateKey
    
    -- Store aura data for tooltip
    icon.auraData = auraData
    icon.auraData.auraInstanceID = auraInstanceID
    
    -- Apply settings
    local iconSize = settings.size or 28
    local borderSize = settings.borderSize or 2
    local borderColor = settings.borderColor or {r = 0, g = 0.8, b = 0, a = 1}
    local anchor = settings.anchor or "CENTER"
    local x = settings.offsetX or 0
    local y = settings.offsetY or 0
    local scale = settings.scale or 1.0
    local showBorder = settings.showBorder ~= false
    local showCooldown = settings.showCooldown ~= false
    local showSwipe = settings.showSwipe ~= false
    local showDuration = settings.showDuration ~= false
    
    -- Set icon texture (use pcall for safety with secret values)
    -- Don't check if auraData.icon exists - just try to set it
    -- In Midnight, the icon value might be "secret" but SetTexture can handle it
    local textureSet = false
    pcall(function()
        icon.texture:SetTexture(auraData.icon)
        textureSet = true
    end)
    
    -- If texture couldn't be set, hide and return
    if not textureSet then
        icon:Hide()
        return
    end
    
    -- Set cooldown using TweaksUI.API compatibility layer (Midnight-safe)
    if showCooldown and auraInstanceID then
        local cooldownSet = false
        
        -- Use DurationAPI for aura duration (cleanest approach)
        if DurationAPI and auraInstanceID then
            cooldownSet = DurationAPI:ApplyAuraDurationToFrame(icon.cooldown, unit, auraInstanceID, true)
        end
        
        -- Fallback: Try SetCooldownFromExpirationTime
        if not cooldownSet and icon.cooldown.SetCooldownFromExpirationTime then
            pcall(function()
                local expTime = auraData.expirationTime
                local dur = auraData.duration
                
                -- SetCooldownFromExpirationTime can accept secret values directly
                if expTime and dur then
                    icon.cooldown:SetCooldownFromExpirationTime(expTime, dur)
                    cooldownSet = true
                end
            end)
        end
        
        -- Final fallback for older clients - only works with non-secret values
        if not cooldownSet then
            pcall(function()
                local expTime = auraData.expirationTime
                local dur = auraData.duration
                local isExpSecret = issecretvalue and expTime and issecretvalue(expTime)
                local isDurSecret = issecretvalue and dur and issecretvalue(dur)
                
                -- Only use this path if values are not secret (requires arithmetic)
                if expTime and dur and not isExpSecret and not isDurSecret and dur > 0 then
                    local startTime = expTime - dur
                    icon.cooldown:SetCooldown(startTime, dur)
                    cooldownSet = true
                end
            end)
        end
        
        -- Show/hide cooldown based on whether aura has expiration (Midnight-safe)
        if AuraAPI then
            local hasExpiration = AuraAPI:HasExpirationTime(unit, auraInstanceID)
            
            -- Check if hasExpiration is a secret value
            local isSecret = issecretvalue and hasExpiration ~= nil and issecretvalue(hasExpiration)
            
            if isSecret and icon.cooldown.SetAlphaFromBoolean then
                -- Midnight-safe: use SetAlphaFromBoolean to show/hide based on secret boolean
                -- Alpha 1 if has expiration (show cooldown), alpha 0 if not
                if cooldownSet then
                    icon.cooldown:Show()
                    icon.cooldown:SetAlphaFromBoolean(hasExpiration, 1, 0)
                else
                    icon.cooldown:Hide()
                end
            elseif not isSecret then
                -- Non-secret path: hasExpiration is a normal boolean we can test
                if hasExpiration and cooldownSet then
                    icon.cooldown:Show()
                else
                    icon.cooldown:Hide()
                end
            else
                -- Fallback: can't determine, just show if cooldown was set
                if cooldownSet then
                    icon.cooldown:Show()
                else
                    icon.cooldown:Hide()
                end
            end
        elseif cooldownSet then
            icon.cooldown:Show()
        else
            icon.cooldown:Hide()
        end
    else
        icon.cooldown:Hide()
    end
    
    icon.cooldown:SetDrawSwipe(showSwipe)
    icon.cooldown:SetHideCountdownNumbers(not showDuration)
    
    -- Stack count - use GetAuraApplicationDisplayCount if available
    local stackText = ""
    local applications = auraData.applications
    local isAppSecret = issecretvalue and applications and issecretvalue(applications)
    
    -- Only try to show stacks if applications is not secret
    if applications and not isAppSecret and applications > 1 then
        if AuraAPI and auraInstanceID then
            stackText = AuraAPI:GetApplicationDisplayCount(unit, auraInstanceID, 2) or ""
        end
        -- Fallback
        if stackText == "" then
            stackText = tostring(applications)
        end
    end
    icon.count:SetText(stackText)
    
    -- Border visibility and color
    if showBorder then
        icon.borderLeft:SetColorTexture(borderColor.r, borderColor.g, borderColor.b, borderColor.a or 1)
        icon.borderRight:SetColorTexture(borderColor.r, borderColor.g, borderColor.b, borderColor.a or 1)
        icon.borderTop:SetColorTexture(borderColor.r, borderColor.g, borderColor.b, borderColor.a or 1)
        icon.borderBottom:SetColorTexture(borderColor.r, borderColor.g, borderColor.b, borderColor.a or 1)
        
        icon.borderLeft:SetWidth(borderSize)
        icon.borderRight:SetWidth(borderSize)
        icon.borderTop:SetHeight(borderSize)
        icon.borderBottom:SetHeight(borderSize)
        
        icon.borderTop:ClearAllPoints()
        icon.borderTop:SetPoint("TOPLEFT", borderSize, 0)
        icon.borderTop:SetPoint("TOPRIGHT", -borderSize, 0)
        
        icon.borderBottom:ClearAllPoints()
        icon.borderBottom:SetPoint("BOTTOMLEFT", borderSize, 0)
        icon.borderBottom:SetPoint("BOTTOMRIGHT", -borderSize, 0)
        
        icon.borderLeft:Show()
        icon.borderRight:Show()
        icon.borderTop:Show()
        icon.borderBottom:Show()
        
        icon.texture:ClearAllPoints()
        icon.texture:SetPoint("TOPLEFT", borderSize, -borderSize)
        icon.texture:SetPoint("BOTTOMRIGHT", -borderSize, borderSize)
    else
        icon.borderLeft:Hide()
        icon.borderRight:Hide()
        icon.borderTop:Hide()
        icon.borderBottom:Hide()
        
        icon.texture:ClearAllPoints()
        icon.texture:SetAllPoints(icon)
    end
    
    -- Size and position
    icon:SetSize(iconSize, iconSize)
    icon:SetScale(scale)
    icon:ClearAllPoints()
    icon:SetPoint(anchor, frame, anchor, x, y)
    
    -- Duration text is now handled by Blizzard's CooldownFrameTemplate
    -- with SetHideCountdownNumbers(not showDuration) above - works with secret values
    if icon.durationText then
        icon.durationText:Hide()
    end
    
    -- Show the icon
    icon:Show()
end

-- ============================================================================
-- BATCH UPDATE FUNCTIONS
-- ============================================================================

-- Update all party frame defensive icons
function DefensiveIcons:UpdatePartyDefensives(partyFrames, settings)
    if not partyFrames or not settings then return end
    
    for i, frame in ipairs(partyFrames) do
        if frame and frame:IsShown() then
            self:UpdateDefensiveIcon(frame, settings)
        elseif frame and frame.defensiveIcon then
            frame.defensiveIcon:Hide()
        end
    end
end

-- Update all raid frame defensive icons
function DefensiveIcons:UpdateRaidDefensives(raidFrames, settings)
    if not raidFrames or not settings then return end
    
    for i, frame in ipairs(raidFrames) do
        if frame and frame:IsShown() then
            self:UpdateDefensiveIcon(frame, settings)
        elseif frame and frame.defensiveIcon then
            frame.defensiveIcon:Hide()
        end
    end
end

-- Hide all defensive icons
function DefensiveIcons:HideAll(frames)
    if not frames then return end
    
    for _, frame in ipairs(frames) do
        if frame and frame.defensiveIcon then
            frame.defensiveIcon:Hide()
        end
    end
end

-- ============================================================================
-- SPELL DATABASE ACCESS
-- ============================================================================

-- Check if a spell ID is a defensive
function DefensiveIcons:IsDefensive(spellID)
    return ALL_DEFENSIVES[spellID] ~= nil
end

-- Get defensive category
function DefensiveIcons:GetDefensiveCategory(spellID)
    return ALL_DEFENSIVES[spellID]
end

-- Add a custom defensive spell
function DefensiveIcons:AddDefensiveSpell(spellID, category)
    if spellID and category then
        ALL_DEFENSIVES[spellID] = category
        if category == "TANK" then
            TANK_DEFENSIVES[spellID] = true
        elseif category == "EXTERNAL" then
            EXTERNAL_DEFENSIVES[spellID] = true
        elseif category == "DPS" then
            DPS_DEFENSIVES[spellID] = true
        end
    end
end

-- Remove a defensive spell
function DefensiveIcons:RemoveDefensiveSpell(spellID)
    if spellID then
        ALL_DEFENSIVES[spellID] = nil
        TANK_DEFENSIVES[spellID] = nil
        EXTERNAL_DEFENSIVES[spellID] = nil
        DPS_DEFENSIVES[spellID] = nil
    end
end

-- Get all defensive spell IDs
function DefensiveIcons:GetAllDefensiveSpells()
    return ALL_DEFENSIVES
end

-- ============================================================================
-- EVENT HANDLING
-- ============================================================================

local eventFrame = CreateFrame("Frame")

-- Update defensive icon for a specific unit
local function UpdateUnitDefensive(unit)
    local UnitFrames = TweaksUI.UnitFrames
    if not UnitFrames then return end
    
    -- Check party frames
    local partyFrames = UnitFrames:GetPartyMemberFrames()
    local partySettings = UnitFrames:GetPartySettings()
    
    if partyFrames and partySettings and partySettings.defensiveIcon and partySettings.defensiveIcon.enabled then
        for _, frame in ipairs(partyFrames) do
            if frame and frame.unit then
                -- Use pcall because UnitIsUnit might fail with secret values
                local isSameUnit = false
                pcall(function()
                    isSameUnit = UnitIsUnit(frame.unit, unit)
                end)
                
                if isSameUnit then
                    DefensiveIcons:UpdateDefensiveIcon(frame, partySettings.defensiveIcon)
                    return
                end
            end
        end
    end
    
    -- Check raid frames
    local raidFrames = UnitFrames:GetRaidMemberFrames()
    local raidSettings = UnitFrames:GetCurrentRaidSettings()
    
    if raidFrames and raidSettings and raidSettings.defensiveIcon and raidSettings.defensiveIcon.enabled then
        for _, frame in ipairs(raidFrames) do
            if frame and frame.unit then
                local isSameUnit = false
                pcall(function()
                    isSameUnit = UnitIsUnit(frame.unit, unit)
                end)
                
                if isSameUnit then
                    DefensiveIcons:UpdateDefensiveIcon(frame, raidSettings.defensiveIcon)
                    return
                end
            end
        end
    end
end

-- Handle events
eventFrame:SetScript("OnEvent", function(self, event, unit, ...)
    if event == "UNIT_AURA" then
        -- Process party/raid units and player
        if unit == "player" or unit:match("^party%d") or unit:match("^raid%d+") then
            UpdateUnitDefensive(unit)
        end
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        -- Update all frames when group changes
        C_Timer.After(0.1, function()
            local UnitFrames = TweaksUI.UnitFrames
            if not UnitFrames then return end
            
            local partyFrames = UnitFrames:GetPartyMemberFrames()
            local partySettings = UnitFrames:GetPartySettings()
            if partyFrames and partySettings and partySettings.defensiveIcon then
                for _, frame in ipairs(partyFrames) do
                    if frame and frame:IsShown() then
                        DefensiveIcons:UpdateDefensiveIcon(frame, partySettings.defensiveIcon)
                    end
                end
            end
            
            local raidFrames = UnitFrames:GetRaidMemberFrames()
            local raidSettings = UnitFrames:GetCurrentRaidSettings()
            if raidFrames and raidSettings and raidSettings.defensiveIcon then
                for _, frame in ipairs(raidFrames) do
                    if frame and frame:IsShown() then
                        DefensiveIcons:UpdateDefensiveIcon(frame, raidSettings.defensiveIcon)
                    end
                end
            end
        end)
    end
end)

-- Start listening for events
function DefensiveIcons:Start()
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
end

-- Stop listening
function DefensiveIcons:Stop()
    eventFrame:UnregisterEvent("UNIT_AURA")
    eventFrame:UnregisterEvent("GROUP_ROSTER_UPDATE")
end

-- Auto-start when addon loads
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:HookScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        -- Set up hooks into Blizzard's CompactUnitFrames
        -- This lets us use their CenterDefensiveBuff (Midnight-compatible)
        SetupBlizzardHooks()
        
        -- Start our event listening
        DefensiveIcons:Start()
    end
end)

return DefensiveIcons
