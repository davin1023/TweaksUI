-- TweaksUI Unit Frames - Test Mode System
-- Provides comprehensive testing for party frame features without requiring a real group

local ADDON_NAME, TweaksUI = ...

-- Module reference (will be set during init)
local UnitFrames = nil

-- ============================================================================
-- TEST MODE STATE
-- ============================================================================

local TestMode = {
    enabled = false,
    
    -- Test data for party frames (5 members: player + 4 party)
    partyData = {},
    
    -- Animation state
    animationTicker = nil,
    
    -- Feature toggles (controlled by settings)
    features = {
        animateHealth = false,
        showAbsorbs = true,
        showHealPrediction = true,
        showAggro = true,
        showSelection = true,
        showDispelGlow = true,
        showDefensiveIcon = false,
        showMissingBuff = false,
        showOutOfRange = true,
        showDead = true,
        showOffline = false,
    },
    
    -- Current selection/aggro state for animation
    selectedIndex = 1,
    aggroIndex = 2,
}

-- Export to TweaksUI namespace
TweaksUI.UnitFramesTestMode = TestMode

-- ============================================================================
-- TEST DATA GENERATION
-- ============================================================================

-- All playable classes
local ALL_CLASSES = {
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
    "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "MONK",
    "DRUID", "DEMONHUNTER", "EVOKER"
}

-- Spec IDs for melee vs ranged detection
local MELEE_SPECS = {
    -- Death Knight (all melee)
    [250] = true, [251] = true, [252] = true,
    -- Demon Hunter (all melee)
    [577] = true, [581] = true,
    -- Druid (Feral, Guardian)
    [103] = true, [104] = true,
    -- Evoker (Augmentation)
    [1473] = true,
    -- Hunter (Survival)
    [255] = true,
    -- Monk (Brewmaster, Windwalker)
    [268] = true, [269] = true,
    -- Paladin (Protection, Retribution)
    [66] = true, [70] = true,
    -- Rogue (all melee)
    [259] = true, [260] = true, [261] = true,
    -- Shaman (Enhancement)
    [263] = true,
    -- Warrior (all melee)
    [71] = true, [72] = true, [73] = true,
}

-- Class to typical spec mapping for role guessing
local CLASS_ROLES = {
    WARRIOR = { "TANK", "DAMAGER", "DAMAGER" },
    PALADIN = { "TANK", "HEALER", "DAMAGER" },
    HUNTER = { "DAMAGER", "DAMAGER", "DAMAGER" },
    ROGUE = { "DAMAGER", "DAMAGER", "DAMAGER" },
    PRIEST = { "HEALER", "HEALER", "DAMAGER" },
    DEATHKNIGHT = { "TANK", "DAMAGER", "DAMAGER" },
    SHAMAN = { "HEALER", "DAMAGER", "DAMAGER" },
    MAGE = { "DAMAGER", "DAMAGER", "DAMAGER" },
    WARLOCK = { "DAMAGER", "DAMAGER", "DAMAGER" },
    MONK = { "TANK", "HEALER", "DAMAGER" },
    DRUID = { "TANK", "HEALER", "DAMAGER", "DAMAGER" },
    DEMONHUNTER = { "TANK", "DAMAGER" },
    EVOKER = { "HEALER", "DAMAGER", "DAMAGER" },
}

-- Class to melee/ranged mapping (for DPS role)
local CLASS_IS_MELEE = {
    WARRIOR = true,
    PALADIN = true,  -- Ret is melee
    HUNTER = false,  -- Mostly ranged (Survival is melee but rare)
    ROGUE = true,
    PRIEST = false,
    DEATHKNIGHT = true,
    SHAMAN = false,  -- Mostly ranged (Enh is melee)
    MAGE = false,
    WARLOCK = false,
    MONK = true,     -- WW is melee
    DRUID = false,   -- Balance/Resto are ranged, Feral is melee
    DEMONHUNTER = true,
    EVOKER = false,  -- Devastation/Pres are ranged, Aug is "melee"
}

-- Names for test characters
local TEST_NAMES = {
    "Tankenstein",
    "Healzalot",
    "Stabsworth",
    "Pyromancer",
    "Shadowweave",
    "Arrowstorm",
    "Frostbane",
    "Lightbringer",
    "Earthshaker",
    "Voidwalker",
}

-- Debuff types for testing dispel overlay
local DEBUFF_TYPES = { nil, "Magic", "Curse", "Disease", "Poison", "Bleed" }

-- Generate a single test party member
local function GenerateTestMember(index, forceRole, forceClass)
    local class = forceClass or ALL_CLASSES[math.random(1, #ALL_CLASSES)]
    local classRoles = CLASS_ROLES[class] or { "DAMAGER" }
    local role = forceRole or classRoles[math.random(1, #classRoles)]
    
    -- Determine if melee or ranged for DPS
    local isMelee = CLASS_IS_MELEE[class]
    local detailedRole = role
    if role == "DAMAGER" then
        detailedRole = isMelee and "MELEE" or "RANGED"
    end
    
    -- Health values based on role
    local baseHealth = 100000
    if role == "TANK" then
        baseHealth = 150000
    elseif role == "HEALER" then
        baseHealth = 90000
    end
    local maxHealth = baseHealth + math.random(-10000, 20000)
    local healthPercent = math.random(30, 100) / 100
    local health = math.floor(maxHealth * healthPercent)
    
    -- Power values
    local powerType = 0  -- Mana default
    local maxPower = 80000
    if class == "ROGUE" or class == "DRUID" then
        powerType = 3  -- Energy
        maxPower = 100
    elseif class == "WARRIOR" then
        powerType = 1  -- Rage
        maxPower = 100
    elseif class == "DEATHKNIGHT" then
        powerType = 6  -- Runic Power
        maxPower = 100
    elseif class == "DEMONHUNTER" then
        powerType = 17  -- Fury
        maxPower = 100
    elseif class == "MONK" and role ~= "HEALER" then
        powerType = 3  -- Energy for non-MW
        maxPower = 100
    end
    local power = math.floor(maxPower * (math.random(20, 100) / 100))
    
    -- Absorb shields (more likely on tanks/healers)
    local absorb = 0
    if role == "TANK" then
        absorb = math.random(0, 1) == 1 and math.random(10000, 40000) or 0
    elseif role == "HEALER" then
        absorb = math.random(0, 2) == 1 and math.random(5000, 20000) or 0
    else
        absorb = math.random(0, 4) == 1 and math.random(2000, 10000) or 0
    end
    
    -- Debuff type (for dispel testing)
    local debuffType = nil
    if math.random(1, 3) == 1 then  -- 33% chance of debuff
        debuffType = DEBUFF_TYPES[math.random(2, #DEBUFF_TYPES)]
    end
    
    -- Heal prediction (incoming heals)
    local incomingHeal = 0
    local incomingHealOthers = 0
    if healthPercent < 0.95 then
        local missingHealth = maxHealth - health
        -- 50% chance of incoming heal if damaged
        if math.random(1, 2) == 1 then
            incomingHeal = math.floor(missingHealth * (math.random(20, 60) / 100))
        end
        -- 30% chance of heal from others if damaged
        if math.random(1, 3) == 1 then
            incomingHealOthers = math.floor(missingHealth * (math.random(10, 40) / 100))
        end
    end
    
    -- Defensive cooldown active
    local hasDefensive = false
    local defensiveSpellID = nil
    local defensiveExpires = 0
    if math.random(1, 5) == 1 then  -- 20% chance
        hasDefensive = true
        -- Some example defensive spell IDs
        local defensives = {
            33206,  -- Pain Suppression
            102342, -- Ironbark
            6940,   -- Blessing of Sacrifice
            47788,  -- Guardian Spirit
            116849, -- Life Cocoon
        }
        defensiveSpellID = defensives[math.random(1, #defensives)]
        defensiveExpires = GetTime() + math.random(5, 12)
    end
    
    -- Out of range state
    local inRange = true
    if TestMode.features.showOutOfRange and math.random(1, 5) == 1 then
        inRange = false
    end
    
    -- Dead state
    local isDead = false
    if TestMode.features.showDead and math.random(1, 8) == 1 then
        isDead = true
        health = 0
    end
    
    -- Offline state
    local isOnline = true
    if TestMode.features.showOffline and math.random(1, 10) == 1 then
        isOnline = false
    end
    
    return {
        -- Basic info
        index = index,
        unit = index == 1 and "player" or ("party" .. (index - 1)),
        name = TEST_NAMES[index] or ("Member" .. index),
        class = class,
        role = role,
        detailedRole = detailedRole,
        isMelee = isMelee,
        
        -- Health
        health = health,
        maxHealth = maxHealth,
        healthPercent = isDead and 0 or healthPercent,
        
        -- Power
        power = power,
        maxPower = maxPower,
        powerType = powerType,
        
        -- Absorbs
        absorb = absorb,
        healAbsorb = 0,  -- Negative absorbs (healing reduction)
        
        -- Heal prediction
        incomingHeal = incomingHeal,
        incomingHealOthers = incomingHealOthers,
        
        -- Debuffs/Dispels
        debuffType = debuffType,
        
        -- Defensive cooldowns
        hasDefensive = hasDefensive,
        defensiveSpellID = defensiveSpellID,
        defensiveExpires = defensiveExpires,
        
        -- Missing buffs
        missingBuff = math.random(1, 4) == 1,  -- 25% chance
        missingBuffType = "Stamina",
        
        -- State flags
        inRange = inRange,
        isDead = isDead,
        isOnline = isOnline,
        isGhost = false,
        
        -- Threat/Selection (set separately)
        threatStatus = 0,
        isSelected = false,
        
        -- Animation targets (for health animation)
        targetHealth = health,
        animationSpeed = math.random(5, 15) / 10,
    }
end

-- Generate a full test party with proper composition
function TestMode:GeneratePartyData(frameCount)
    frameCount = frameCount or 5
    self.partyData = {}
    
    -- Standard M+ composition: 1 Tank, 1 Healer, 3 DPS
    local composition = {
        { role = "TANK", class = "WARRIOR" },
        { role = "HEALER", class = "PRIEST" },
        { role = "DAMAGER", class = "ROGUE" },
        { role = "DAMAGER", class = "MAGE" },
        { role = "DAMAGER", class = "HUNTER" },
    }
    
    for i = 1, frameCount do
        local comp = composition[i] or {}
        local member = GenerateTestMember(i, comp.role, comp.class)
        
        -- Set selection/aggro based on current state
        member.isSelected = (i == self.selectedIndex)
        member.threatStatus = (i == self.aggroIndex) and 3 or 0
        
        self.partyData[i] = member
    end
    
    return self.partyData
end

-- Regenerate party data with randomized values
function TestMode:RandomizeParty(frameCount)
    frameCount = frameCount or 5
    self.partyData = {}
    
    -- First slot is always tank
    self.partyData[1] = GenerateTestMember(1, "TANK")
    
    -- Second slot is always healer
    if frameCount >= 2 then
        self.partyData[2] = GenerateTestMember(2, "HEALER")
    end
    
    -- Rest are random DPS
    for i = 3, frameCount do
        self.partyData[i] = GenerateTestMember(i, "DAMAGER")
    end
    
    -- Apply selection/aggro
    for i, member in ipairs(self.partyData) do
        member.isSelected = (i == self.selectedIndex)
        member.threatStatus = (i == self.aggroIndex) and 3 or 0
    end
    
    return self.partyData
end

-- ============================================================================
-- TEST DATA ACCESSORS
-- ============================================================================

-- Get test data for a specific index
function TestMode:GetMemberData(index)
    return self.partyData[index]
end

-- Get test data by unit ID
function TestMode:GetDataByUnit(unit)
    for _, data in ipairs(self.partyData) do
        if data.unit == unit then
            return data
        end
    end
    return nil
end

-- Check if test mode is active
function TestMode:IsActive()
    return self.enabled
end

-- ============================================================================
-- HEALTH ANIMATION
-- ============================================================================

local function AnimateHealth()
    if not TestMode.enabled or not TestMode.features.animateHealth then
        return
    end
    
    local now = GetTime()
    local changed = false
    
    for _, member in ipairs(TestMode.partyData) do
        if member.isDead or not member.isOnline then
            -- Dead/offline - no animation
        else
            -- Randomly change target health
            if math.random(1, 60) == 1 then  -- ~1.7% chance per frame
                local newPercent = math.random(15, 100) / 100
                member.targetHealth = math.floor(member.maxHealth * newPercent)
            end
            
            -- Animate toward target
            local diff = member.targetHealth - member.health
            if math.abs(diff) > 100 then
                local step = diff * 0.1 * member.animationSpeed
                member.health = math.floor(member.health + step)
                member.healthPercent = member.health / member.maxHealth
                changed = true
            end
        end
    end
    
    -- Trigger frame update if health changed
    if changed and UnitFrames and UnitFrames.UpdatePartyFrames then
        UnitFrames:UpdatePartyFrames()
    end
end

-- ============================================================================
-- TEST MODE CONTROLS
-- ============================================================================

function TestMode:Enable(frameCount)
    if self.enabled then return end
    
    self.enabled = true
    frameCount = frameCount or 5
    
    -- Generate initial party data
    self:GeneratePartyData(frameCount)
    
    -- Start animation ticker if health animation is enabled
    if self.features.animateHealth then
        self.animationTicker = C_Timer.NewTicker(0.05, AnimateHealth)
    end
    
    -- Ensure party container exists (create if needed for test mode)
    if UnitFrames then
        -- Force party container creation if it doesn't exist
        if UnitFrames.CreatePartyContainer then
            UnitFrames:CreatePartyContainer()
        end
        
        -- Trigger party frame update
        if UnitFrames.UpdatePartyFrames then
            UnitFrames:UpdatePartyFrames()
        end
    end
    
    TweaksUI:PrintDebug("UnitFrames Test Mode enabled with " .. frameCount .. " frames")
end

function TestMode:Disable()
    if not self.enabled then return end
    
    self.enabled = false
    self.partyData = {}
    
    -- Stop animation ticker
    if self.animationTicker then
        self.animationTicker:Cancel()
        self.animationTicker = nil
    end
    
    -- Trigger party frame update
    if UnitFrames and UnitFrames.UpdatePartyFrames then
        UnitFrames:UpdatePartyFrames()
    end
    
    TweaksUI:PrintDebug("UnitFrames Test Mode disabled")
end

function TestMode:Toggle(frameCount)
    if self.enabled then
        self:Disable()
    else
        self:Enable(frameCount)
    end
end

-- Set which frame is "selected" (targeted)
function TestMode:SetSelectedIndex(index)
    self.selectedIndex = index
    for i, member in ipairs(self.partyData) do
        member.isSelected = (i == index)
    end
end

-- Set which frame has "aggro"
function TestMode:SetAggroIndex(index, status)
    self.aggroIndex = index
    for i, member in ipairs(self.partyData) do
        member.threatStatus = (i == index) and (status or 3) or 0
    end
end

-- Cycle selection to next frame
function TestMode:CycleSelection()
    local count = #self.partyData
    if count == 0 then return end
    
    self.selectedIndex = (self.selectedIndex % count) + 1
    self:SetSelectedIndex(self.selectedIndex)
    
    if UnitFrames and UnitFrames.UpdatePartyFrames then
        UnitFrames:UpdatePartyFrames()
    end
end

-- Cycle aggro to next frame
function TestMode:CycleAggro()
    local count = #self.partyData
    if count == 0 then return end
    
    self.aggroIndex = (self.aggroIndex % count) + 1
    self:SetAggroIndex(self.aggroIndex)
    
    if UnitFrames and UnitFrames.UpdatePartyFrames then
        UnitFrames:UpdatePartyFrames()
    end
end

-- Update a specific feature toggle
function TestMode:SetFeature(feature, enabled)
    if self.features[feature] == nil then return end
    
    self.features[feature] = enabled
    
    -- Special handling for animation feature
    if feature == "animateHealth" then
        if enabled and self.enabled and not self.animationTicker then
            self.animationTicker = C_Timer.NewTicker(0.05, AnimateHealth)
        elseif not enabled and self.animationTicker then
            self.animationTicker:Cancel()
            self.animationTicker = nil
        end
    end
    
    -- Regenerate party data to apply new feature state
    if self.enabled then
        local count = #self.partyData
        self:GeneratePartyData(count > 0 and count or 5)
        
        if UnitFrames and UnitFrames.UpdatePartyFrames then
            UnitFrames:UpdatePartyFrames()
        end
    end
end

-- Get current feature state
function TestMode:GetFeature(feature)
    return self.features[feature]
end

-- Load features from settings
function TestMode:LoadFeaturesFromSettings(testSettings)
    if not testSettings then return end
    
    for feature, defaultValue in pairs(self.features) do
        if testSettings[feature] ~= nil then
            self.features[feature] = testSettings[feature]
        end
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function TestMode:Init(unitFramesModule)
    UnitFrames = unitFramesModule
    TweaksUI:PrintDebug("UnitFrames TestMode initialized")
end

-- ============================================================================
-- GLOBAL TEST MODE (Shows ALL enabled frames with simulated data)
-- ============================================================================

local globalTestModeActive = false

-- Simulated aura data for test mode displays
-- Note: remainingTime is used to calculate expirationTime dynamically
local SIMULATED_AURA_TEMPLATES = {
    buffs = {
        { spellId = 21562, name = "Power Word: Fortitude", icon = 135987, count = 0, duration = 3600, remainingTime = 3200, isHelpful = true },
        { spellId = 1459, name = "Arcane Intellect", icon = 135932, count = 0, duration = 3600, remainingTime = 2800, isHelpful = true },
        { spellId = 6673, name = "Battle Shout", icon = 132333, count = 0, duration = 3600, remainingTime = 3100, isHelpful = true },
        { spellId = 2825, name = "Bloodlust", icon = 136012, count = 0, duration = 40, remainingTime = 25, isHelpful = true },
        { spellId = 1126, name = "Mark of the Wild", icon = 136078, count = 0, duration = 3600, remainingTime = 2500, isHelpful = true },
    },
    debuffs = {
        { spellId = 113746, name = "Mystic Touch", icon = 134339, count = 0, duration = 3600, remainingTime = 3200, isHarmful = true },
        { spellId = 702, name = "Curse of Weakness", icon = 136138, count = 0, duration = 120, remainingTime = 90, dispelType = "Curse", isHarmful = true },
        { spellId = 589, name = "Shadow Word: Pain", icon = 136207, count = 0, duration = 16, remainingTime = 12, dispelType = "Magic", isHarmful = true },
        { spellId = 853, name = "Hammer of Justice", icon = 135963, count = 0, duration = 6, remainingTime = 4, dispelType = "Magic", isHarmful = true },
    },
    -- Party/raid specific auras (dispellable debuffs)
    partyDebuffs = {
        { spellId = 702, name = "Curse of Weakness", icon = 136138, count = 0, duration = 120, remainingTime = 90, dispelType = "Curse", isHarmful = true },
        { spellId = 589, name = "Shadow Word: Pain", icon = 136207, count = 0, duration = 16, remainingTime = 8, dispelType = "Magic", isHarmful = true },
        { spellId = 3355, name = "Freezing Trap", icon = 135834, count = 0, duration = 60, remainingTime = 45, dispelType = nil, isHarmful = true },
    },
}

-- Helper to build aura data with current expiration times
local function BuildSimulatedAuras(templates, startID)
    local auras = {}
    local now = GetTime()
    for i, template in ipairs(templates) do
        auras[i] = {
            spellId = template.spellId,
            name = template.name,
            icon = template.icon,
            applications = template.count or 0,
            duration = template.duration,
            expirationTime = now + template.remainingTime,
            dispelName = template.dispelType,
            isHelpful = template.isHelpful,
            isHarmful = template.isHarmful,
            auraInstanceID = startID + i,  -- Fake aura instance ID for test mode
        }
    end
    return auras
end

-- Get simulated auras for a unit type
function TestMode:GetSimulatedAuras(unitType, auraType)
    if auraType == "HELPFUL" or auraType == "buffs" then
        return BuildSimulatedAuras(SIMULATED_AURA_TEMPLATES.buffs, 3000)
    elseif auraType == "HARMFUL" or auraType == "debuffs" then
        if unitType == "party" or unitType == "raid" then
            return BuildSimulatedAuras(SIMULATED_AURA_TEMPLATES.partyDebuffs, 4000)
        end
        return BuildSimulatedAuras(SIMULATED_AURA_TEMPLATES.debuffs, 5000)
    end
    return {}
end

-- Check if global test mode is active
function TestMode:IsGlobalTestMode()
    return globalTestModeActive
end

-- Enable global test mode - shows ALL enabled frames with simulated data
function TestMode:EnableGlobalTestMode()
    if globalTestModeActive then return end
    
    globalTestModeActive = true
    
    -- Enable party test mode
    self:Enable(5)
    
    -- Enable individual frame previews through UnitFrames module
    if UnitFrames then
        -- These are the preview flags in UnitFrames.lua
        -- We need to set them and trigger updates
        UnitFrames:EnableAllPreviews()
    end
    
    TweaksUI:Print("Global Test Mode |cff00ff00ENABLED|r - All frames shown with simulated data")
end

-- Disable global test mode
function TestMode:DisableGlobalTestMode()
    if not globalTestModeActive then return end
    
    globalTestModeActive = false
    
    -- Disable party test mode
    self:Disable()
    
    -- Disable individual frame previews
    if UnitFrames then
        UnitFrames:DisableAllPreviews()
    end
    
    TweaksUI:Print("Global Test Mode |cffff0000DISABLED|r")
end

-- Toggle global test mode
function TestMode:ToggleGlobalTestMode()
    if globalTestModeActive then
        self:DisableGlobalTestMode()
    else
        self:EnableGlobalTestMode()
    end
end

-- ============================================================================
-- SLASH COMMANDS FOR TESTING
-- ============================================================================

SLASH_TUITEST1 = "/tuitest"
SlashCmdList["TUITEST"] = function(msg)
    local args = {}
    for arg in msg:gmatch("%S+") do
        table.insert(args, arg:lower())
    end
    
    local cmd = args[1] or "toggle"
    
    -- Global test mode (default toggle behavior)
    if cmd == "toggle" or cmd == "all" then
        TestMode:ToggleGlobalTestMode()
        
    elseif cmd == "on" or cmd == "enable" then
        local count = tonumber(args[2]) or 5
        if args[2] == "all" or not args[2] then
            TestMode:EnableGlobalTestMode()
        else
            TestMode:Enable(count)
            print("|cff00ff00TweaksUI:|r Party test mode enabled with " .. count .. " frames")
        end
        
    elseif cmd == "off" or cmd == "disable" then
        TestMode:DisableGlobalTestMode()
        
    -- Party-specific commands
    elseif cmd == "party" then
        local subCmd = args[2] or "toggle"
        if subCmd == "on" then
            local count = tonumber(args[3]) or 5
            TestMode:Enable(count)
            print("|cff00ff00TweaksUI:|r Party test mode enabled with " .. count .. " frames")
        elseif subCmd == "off" then
            TestMode:Disable()
            print("|cff00ff00TweaksUI:|r Party test mode disabled")
        else
            TestMode:Toggle()
            print("|cff00ff00TweaksUI:|r Party test mode " .. (TestMode.enabled and "enabled" or "disabled"))
        end
        
    elseif cmd == "random" or cmd == "randomize" then
        TestMode:RandomizeParty()
        print("|cff00ff00TweaksUI:|r Randomized test party")
        if UnitFrames and UnitFrames.UpdatePartyFrames then
            UnitFrames:UpdatePartyFrames()
        end
        
    elseif cmd == "select" then
        local index = tonumber(args[2]) or 1
        TestMode:SetSelectedIndex(index)
        print("|cff00ff00TweaksUI:|r Selected frame " .. index)
        if UnitFrames and UnitFrames.UpdatePartyFrames then
            UnitFrames:UpdatePartyFrames()
        end
        
    elseif cmd == "aggro" then
        local index = tonumber(args[2]) or 2
        local status = tonumber(args[3]) or 3
        TestMode:SetAggroIndex(index, status)
        print("|cff00ff00TweaksUI:|r Aggro on frame " .. index .. " (status " .. status .. ")")
        if UnitFrames and UnitFrames.UpdatePartyFrames then
            UnitFrames:UpdatePartyFrames()
        end
        
    elseif cmd == "animate" then
        local enabled = args[2] ~= "off"
        TestMode:SetFeature("animateHealth", enabled)
        print("|cff00ff00TweaksUI:|r Health animation " .. (enabled and "enabled" or "disabled"))
        
    elseif cmd == "feature" then
        local feature = args[2]
        local enabled = args[3] ~= "off"
        if feature and TestMode.features[feature] ~= nil then
            TestMode:SetFeature(feature, enabled)
            print("|cff00ff00TweaksUI:|r Feature '" .. feature .. "' " .. (enabled and "enabled" or "disabled"))
        else
            print("|cff00ff00TweaksUI:|r Available features:")
            for f, v in pairs(TestMode.features) do
                print("  - " .. f .. ": " .. (v and "on" or "off"))
            end
        end
        
    else
        print("|cff00ff00TweaksUI Test Mode Commands:|r")
        print("  /tuitest - Toggle global test mode (all frames)")
        print("  /tuitest on - Enable global test mode")
        print("  /tuitest off - Disable global test mode")
        print("  /tuitest party [on/off/count] - Party frames only")
        print("  /tuitest random - Randomize party data")
        print("  /tuitest select [1-5] - Set selected frame")
        print("  /tuitest aggro [1-5] [1-3] - Set aggro frame and status")
        print("  /tuitest animate [on/off] - Toggle health animation")
        print("  /tuitest feature [name] [on/off] - Toggle feature")
    end
end

return TestMode
