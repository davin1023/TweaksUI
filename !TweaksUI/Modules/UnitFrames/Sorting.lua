-- TweaksUI Unit Frames - Sorting System
-- Sorts party/raid frames by role, class, and name

local ADDON_NAME, TweaksUI = ...

-- Module reference (will be set during init)
local UnitFrames = nil

-- ============================================================================
-- SORTING MODULE
-- ============================================================================

local Sorting = {
    -- Cache for unit info (cleared on group changes)
    unitCache = {},
    
    -- Last sort order (for comparison)
    lastSortOrder = {},
    
    -- Reusable caches for sorting (PERFORMANCE - avoids table allocations)
    _otherEntriesCache = {},
    _sortedListCache = {},
    _frameListCache = {},
    _orderCache = {},
    _sortedUnitsCache = {},
}

-- Export to TweaksUI namespace
TweaksUI.UnitFramesSorting = Sorting

-- ============================================================================
-- SPEC TO ROLE MAPPING
-- ============================================================================

-- Melee specs (all others are ranged)
local MELEE_SPECS = {
    -- Death Knight (all melee)
    [250] = true, -- Blood
    [251] = true, -- Frost
    [252] = true, -- Unholy
    
    -- Demon Hunter (all melee)
    [577] = true, -- Havoc
    [581] = true, -- Vengeance
    
    -- Druid (Feral, Guardian)
    [103] = true, -- Feral
    [104] = true, -- Guardian
    
    -- Evoker (Augmentation is considered melee-range)
    [1473] = true, -- Augmentation
    
    -- Hunter (Survival only)
    [255] = true, -- Survival
    
    -- Monk (Brewmaster, Windwalker)
    [268] = true, -- Brewmaster
    [269] = true, -- Windwalker
    
    -- Paladin (Protection, Retribution)
    [66] = true,  -- Protection
    [70] = true,  -- Retribution
    
    -- Rogue (all melee)
    [259] = true, -- Assassination
    [260] = true, -- Outlaw
    [261] = true, -- Subtlety
    
    -- Shaman (Enhancement only)
    [263] = true, -- Enhancement
    
    -- Warrior (all melee)
    [71] = true,  -- Arms
    [72] = true,  -- Fury
    [73] = true,  -- Protection
}

-- Class-based melee/ranged guess (for when spec isn't available)
local CLASS_MELEE_DEFAULT = {
    WARRIOR = true,
    ROGUE = true,
    DEATHKNIGHT = true,
    DEMONHUNTER = true,
    -- Mixed classes default to ranged (safer for positioning)
    PALADIN = false,  -- Could be Holy
    HUNTER = false,   -- Mostly ranged
    DRUID = false,    -- Could be Balance/Resto
    SHAMAN = false,   -- Could be Ele/Resto
    MONK = false,     -- Could be MW
    EVOKER = false,   -- Mostly ranged
    -- Pure ranged
    MAGE = false,
    WARLOCK = false,
    PRIEST = false,
}

-- ============================================================================
-- DEFAULT SETTINGS
-- ============================================================================

Sorting.DEFAULTS = {
    enabled = true,
    
    -- Role sorting
    sortByRole = true,
    roleOrder = { "TANK", "HEALER", "MELEE", "RANGED" },
    separateMeleeRanged = true,
    
    -- Group sorting (for raids - sort by raid group first)
    sortByGroup = false,  -- Disabled by default for party, enabled for raids
    
    -- Class sorting (within roles)
    sortByClass = true,
    classOrder = {
        "DEATHKNIGHT", "DEMONHUNTER", "DRUID", "EVOKER",
        "HUNTER", "MAGE", "MONK", "PALADIN", "PRIEST",
        "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR"
    },
    
    -- Alphabetical sorting (within class)
    sortAlphabetically = true,
    
    -- Self (player) position override
    selfPosition = "NORMAL",  -- "NORMAL", "FIRST", "LAST", or 1-5
}

-- ============================================================================
-- ROLE DETECTION
-- ============================================================================

-- Get the detailed role for a unit
-- Returns: "TANK", "HEALER", "MELEE", "RANGED", or "DAMAGER"
function Sorting:GetUnitRole(unit, settings)
    if not unit then return "DAMAGER" end
    
    -- Check if we're in test mode
    local TestMode = TweaksUI.UnitFramesTestMode
    if TestMode and TestMode:IsActive() then
        local testData = TestMode:GetDataByUnit(unit)
        if testData then
            return testData.detailedRole or testData.role or "DAMAGER"
        end
    end
    
    -- Check for real unit
    if not UnitExists(unit) then return "DAMAGER" end
    
    -- Check cache first
    local guid = UnitGUID(unit)
    if guid and self.unitCache[guid] then
        return self.unitCache[guid].role
    end
    
    -- Get assigned role from group
    local assignedRole = UnitGroupRolesAssigned(unit)
    
    -- If TANK or HEALER, we're done
    if assignedRole == "TANK" or assignedRole == "HEALER" then
        if guid then
            self.unitCache[guid] = self.unitCache[guid] or {}
            self.unitCache[guid].role = assignedRole
        end
        return assignedRole
    end
    
    -- For NPCs (followers, etc.), try to determine role from other sources
    -- UnitGroupRolesAssigned doesn't work for NPCs
    if not UnitIsPlayer(unit) then
        -- Check if they have a role displayed in the UI (from UnitGroupRolesAssigned texture)
        -- For NPCs without assigned roles, try to guess based on class/name
        local _, class = UnitClass(unit)
        local name = UnitName(unit) or ""
        
        -- Common NPC tank indicators
        local tankClasses = { WARRIOR = true, PALADIN = true, DEATHKNIGHT = true }
        local tankNamePatterns = { "Captain", "Guard", "Protector", "Defender", "Knight", "Tank" }
        
        -- Check name patterns
        for _, pattern in ipairs(tankNamePatterns) do
            if name:find(pattern) then
                if guid then
                    self.unitCache[guid] = self.unitCache[guid] or {}
                    self.unitCache[guid].role = "TANK"
                end
                return "TANK"
            end
        end
        
        -- Check if NPC is first party member (often the tank in follower scenarios)
        if unit == "party1" and (class == "WARRIOR" or class == "PALADIN") then
            if guid then
                self.unitCache[guid] = self.unitCache[guid] or {}
                self.unitCache[guid].role = "TANK"
            end
            return "TANK"
        end
        
        -- For NPCs, just return DAMAGER if we can't determine
        return "DAMAGER"
    end
    
    -- For DPS, determine if melee or ranged
    local role = "DAMAGER"
    
    if settings and settings.separateMeleeRanged then
        local specID = nil
        
        -- For player, we can get spec directly
        if UnitIsUnit(unit, "player") then
            local currentSpec = GetSpecialization()
            if currentSpec then
                specID = GetSpecializationInfo(currentSpec)
            end
        else
            -- For other players, try inspection cache
            -- Note: Full implementation would use INSPECT_READY
            -- For now, use class-based guessing
        end
        
        -- Check spec if we have it
        if specID then
            role = MELEE_SPECS[specID] and "MELEE" or "RANGED"
        else
            -- Fallback to class-based guess
            local _, class = UnitClass(unit)
            if class then
                role = CLASS_MELEE_DEFAULT[class] and "MELEE" or "RANGED"
            end
        end
    end
    
    -- Cache the result
    if guid then
        self.unitCache[guid] = self.unitCache[guid] or {}
        self.unitCache[guid].role = role
    end
    
    return role
end

-- Get sort priority for a role
function Sorting:GetRolePriority(role, settings)
    local roleOrder = settings.roleOrder or self.DEFAULTS.roleOrder
    
    for i, r in ipairs(roleOrder) do
        if r == role then
            return i
        end
        -- Handle DAMAGER matching MELEE or RANGED when not separating
        if role == "DAMAGER" and (r == "MELEE" or r == "RANGED") then
            return i
        end
    end
    
    return 100  -- Unknown role goes last
end

-- ============================================================================
-- CLASS SORTING
-- ============================================================================

-- Get sort priority for a class
function Sorting:GetClassPriority(class, settings)
    if not class then return 100 end
    
    local classOrder = settings.classOrder or self.DEFAULTS.classOrder
    
    for i, c in ipairs(classOrder) do
        if c == class then
            return i
        end
    end
    
    return 100  -- Unknown class goes last
end

-- ============================================================================
-- COMPARISON FUNCTIONS
-- ============================================================================

-- Compare two units for sorting
-- Returns true if unitA should come before unitB
function Sorting:CompareUnits(unitA, unitB, settings)
    if not settings then
        settings = self.DEFAULTS
    end
    
    -- First sort by group if enabled (for raids)
    if settings.sortByGroup and IsInRaid() then
        local indexA = UnitInRaid(unitA)
        local indexB = UnitInRaid(unitB)
        
        if indexA and indexB then
            -- GetRaidRosterInfo returns: name, rank, subgroup, level, class, ...
            local _, _, groupA = GetRaidRosterInfo(indexA + 1)  -- 1-indexed
            local _, _, groupB = GetRaidRosterInfo(indexB + 1)
            
            if groupA and groupB and groupA ~= groupB then
                return groupA < groupB
            end
        end
    end
    
    -- Get roles
    local roleA = self:GetUnitRole(unitA, settings)
    local roleB = self:GetUnitRole(unitB, settings)
    
    -- Then sort by role priority
    if settings.sortByRole then
        local prioA = self:GetRolePriority(roleA, settings)
        local prioB = self:GetRolePriority(roleB, settings)
        
        if prioA ~= prioB then
            return prioA < prioB
        end
    end
    
    -- Then sort by class if enabled
    if settings.sortByClass then
        local _, classA = UnitClass(unitA)
        local _, classB = UnitClass(unitB)
        
        local classPrioA = self:GetClassPriority(classA, settings)
        local classPrioB = self:GetClassPriority(classB, settings)
        
        if classPrioA ~= classPrioB then
            return classPrioA < classPrioB
        end
    end
    
    -- Then sort alphabetically if enabled
    if settings.sortAlphabetically then
        local nameA = UnitName(unitA) or ""
        local nameB = UnitName(unitB) or ""
        return nameA < nameB
    end
    
    return false
end

-- Compare two test data entries for sorting
function Sorting:CompareTestData(dataA, dataB, settings)
    if not settings then
        settings = self.DEFAULTS
    end
    
    -- Get roles from test data
    local roleA = dataA.detailedRole or dataA.role or "DAMAGER"
    local roleB = dataB.detailedRole or dataB.role or "DAMAGER"
    
    -- First sort by role priority
    if settings.sortByRole then
        local prioA = self:GetRolePriority(roleA, settings)
        local prioB = self:GetRolePriority(roleB, settings)
        
        if prioA ~= prioB then
            return prioA < prioB
        end
    end
    
    -- Then sort by class if enabled
    if settings.sortByClass then
        local classPrioA = self:GetClassPriority(dataA.class, settings)
        local classPrioB = self:GetClassPriority(dataB.class, settings)
        
        if classPrioA ~= classPrioB then
            return classPrioA < classPrioB
        end
    end
    
    -- Then sort alphabetically if enabled
    if settings.sortAlphabetically then
        local nameA = dataA.name or ""
        local nameB = dataB.name or ""
        return nameA < nameB
    end
    
    return false
end

-- ============================================================================
-- MAIN SORTING FUNCTION
-- ============================================================================

-- Sort a list of frame entries
-- Each entry should be: { index = n, unit = "party1", isPlayer = bool, testData = optional }
-- Returns the sorted list
function Sorting:SortFrameList(frameList, settings, isTestMode)
    if not settings or not settings.enabled then
        return frameList
    end
    
    -- Separate player from others - use cached tables
    local playerEntry = nil
    wipe(self._otherEntriesCache)
    local otherEntries = self._otherEntriesCache
    
    for _, entry in ipairs(frameList) do
        if entry.isPlayer then
            playerEntry = entry
        else
            table.insert(otherEntries, entry)
        end
    end
    
    -- Sort non-player entries
    if isTestMode then
        -- Use test data for sorting
        table.sort(otherEntries, function(a, b)
            local dataA = a.testData or {}
            local dataB = b.testData or {}
            return self:CompareTestData(dataA, dataB, settings)
        end)
    else
        -- Use real unit data
        table.sort(otherEntries, function(a, b)
            return self:CompareUnits(a.unit, b.unit, settings)
        end)
    end
    
    -- Build final list based on self position setting - use cached table
    wipe(self._sortedListCache)
    local sortedList = self._sortedListCache
    local selfPos = settings.selfPosition or "NORMAL"
    
    -- Check if selfPos is a numeric position (1-5)
    local numericPos = tonumber(selfPos)
    
    if numericPos and playerEntry then
        -- Insert player at specific position
        local inserted = false
        for i, entry in ipairs(otherEntries) do
            if i == numericPos and not inserted then
                table.insert(sortedList, playerEntry)
                inserted = true
            end
            table.insert(sortedList, entry)
        end
        -- If we haven't inserted yet (position beyond list), add at end
        if not inserted then
            table.insert(sortedList, playerEntry)
        end
        
    elseif selfPos == "FIRST" and playerEntry then
        table.insert(sortedList, playerEntry)
        for _, entry in ipairs(otherEntries) do
            table.insert(sortedList, entry)
        end
        
    elseif selfPos == "LAST" and playerEntry then
        for _, entry in ipairs(otherEntries) do
            table.insert(sortedList, entry)
        end
        table.insert(sortedList, playerEntry)
        
    else
        -- NORMAL - sort player with everyone else based on role/class/name
        if playerEntry then
            local inserted = false
            
            for i, entry in ipairs(otherEntries) do
                local playerFirst
                if isTestMode then
                    local playerData = playerEntry.testData or {}
                    local entryData = entry.testData or {}
                    playerFirst = self:CompareTestData(playerData, entryData, settings)
                else
                    playerFirst = self:CompareUnits("player", entry.unit, settings)
                end
                
                if playerFirst and not inserted then
                    table.insert(sortedList, playerEntry)
                    inserted = true
                end
                table.insert(sortedList, entry)
            end
            
            if not inserted then
                table.insert(sortedList, playerEntry)
            end
        else
            sortedList = otherEntries
        end
    end
    
    return sortedList
end

-- ============================================================================
-- GET SORTED INDICES
-- ============================================================================

-- Get the sorted order for party frames
-- Returns a table mapping display position -> original index
-- e.g., { [1] = 2, [2] = 1, [3] = 4, [4] = 3, [5] = 5 }
-- means: display position 1 shows original frame 2, etc.
function Sorting:GetSortedPartyOrder(settings, partyData, isTestMode)
    if not settings or not settings.enabled then
        -- Return identity mapping (no sorting)
        return { 1, 2, 3, 4, 5 }
    end
    
    -- Build frame list
    local frameList = {}
    local memberCount = 5
    
    if partyData then
        memberCount = #partyData
    end
    
    for i = 1, memberCount do
        local unit = i == 1 and "player" or ("party" .. (i - 1))
        local testData = partyData and partyData[i] or nil
        
        table.insert(frameList, {
            index = i,
            unit = unit,
            isPlayer = (i == 1),
            testData = testData,
        })
    end
    
    -- Sort the list
    local sortedList = self:SortFrameList(frameList, settings, isTestMode)
    
    -- Build the mapping
    local order = {}
    for displayPos, entry in ipairs(sortedList) do
        order[displayPos] = entry.index
    end
    
    return order
end

-- Get a list of unit IDs in sorted order
-- This is what UnitFrames.lua calls to get sorted units
-- @param unitList - Array of unit IDs (e.g., {"player", "party1", "party2", ...})
-- @param settings - Sorting settings table
-- @return Array of unit IDs in sorted order
function Sorting:GetSortedUnitList(unitList, settings)
    if not unitList or #unitList == 0 then
        return unitList
    end
    
    if not settings or not settings.enabled then
        return unitList
    end
    
    -- Check for test mode
    local TestMode = TweaksUI.UnitFramesTestMode
    local isTestMode = TestMode and TestMode:IsActive()
    local partyData = isTestMode and TestMode.partyData or nil
    
    -- Build frame list with unit info
    local frameList = {}
    for i, unit in ipairs(unitList) do
        local testData = partyData and partyData[i] or nil
        table.insert(frameList, {
            index = i,
            unit = unit,
            isPlayer = UnitIsUnit(unit, "player"),
            testData = testData,
        })
    end
    
    -- Sort the list
    local sortedList = self:SortFrameList(frameList, settings, isTestMode)
    
    -- Build the sorted unit list
    local sortedUnits = {}
    for _, entry in ipairs(sortedList) do
        table.insert(sortedUnits, entry.unit)
    end
    
    return sortedUnits
end

-- Check if sort order has changed
function Sorting:HasOrderChanged(newOrder)
    if #newOrder ~= #self.lastSortOrder then
        return true
    end
    
    for i, v in ipairs(newOrder) do
        if self.lastSortOrder[i] ~= v then
            return true
        end
    end
    
    return false
end

-- Store the current sort order
function Sorting:SaveSortOrder(order)
    self.lastSortOrder = {}
    for i, v in ipairs(order) do
        self.lastSortOrder[i] = v
    end
end

-- ============================================================================
-- CACHE MANAGEMENT
-- ============================================================================

function Sorting:ClearCache()
    wipe(self.unitCache)
end

function Sorting:InvalidateUnit(guid)
    if guid and self.unitCache[guid] then
        self.unitCache[guid] = nil
    end
end

-- ============================================================================
-- EVENT HANDLING
-- ============================================================================

local eventFrame = CreateFrame("Frame")
local eventsRegistered = false

local function OnEvent(self, event, ...)
    -- Clear cache on group changes
    Sorting:ClearCache()
    
    -- Trigger resort after a short delay
    C_Timer.After(0.1, function()
        if UnitFrames and UnitFrames.UpdatePartyFrames then
            UnitFrames:UpdatePartyFrames()
        end
    end)
end

function Sorting:RegisterEvents()
    if eventsRegistered then return end
    
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    eventFrame:RegisterEvent("ROLE_CHANGED_INFORM")
    eventFrame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
    eventFrame:SetScript("OnEvent", OnEvent)
    
    eventsRegistered = true
end

function Sorting:UnregisterEvents()
    if not eventsRegistered then return end
    
    eventFrame:UnregisterAllEvents()
    eventFrame:SetScript("OnEvent", nil)
    
    eventsRegistered = false
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function Sorting:Init(unitFramesModule)
    UnitFrames = unitFramesModule
    self:RegisterEvents()
    TweaksUI:PrintDebug("UnitFrames Sorting initialized")
end

-- ============================================================================
-- DEBUG COMMAND
-- ============================================================================

SLASH_TUISORT1 = "/tuisort"
SlashCmdList["TUISORT"] = function(msg)
    print("|cff00ccffTweaksUI Sorting Debug:|r")
    
    -- Show current settings (if available)
    local settings = Sorting.DEFAULTS
    print("  Enabled: " .. tostring(settings.enabled))
    print("  Sort by role: " .. tostring(settings.sortByRole))
    print("  Separate melee/ranged: " .. tostring(settings.separateMeleeRanged))
    print("  Sort by class: " .. tostring(settings.sortByClass))
    print("  Sort alphabetically: " .. tostring(settings.sortAlphabetically))
    print("  Self position: " .. tostring(settings.selfPosition))
    print("  Role order: " .. table.concat(settings.roleOrder, " > "))
    
    -- Show detected roles for current party
    print("  Current party:")
    local _, playerClass = UnitClass("player")
    print("    player: " .. Sorting:GetUnitRole("player", settings) .. " - " .. (playerClass or "?") .. " - " .. (UnitName("player") or "?"))
    
    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) then
            local _, unitClass = UnitClass(unit)
            print("    " .. unit .. ": " .. Sorting:GetUnitRole(unit, settings) .. " - " .. (unitClass or "?") .. " - " .. (UnitName(unit) or "?"))
        end
    end
    
    -- Show cached data
    local cacheCount = 0
    for _ in pairs(Sorting.unitCache) do
        cacheCount = cacheCount + 1
    end
    print("  Cache entries: " .. cacheCount)
end

return Sorting
