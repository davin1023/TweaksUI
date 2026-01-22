-- ============================================================================
-- TweaksUI: Character Panel Enhancements
-- Adds precise item level, per-slot ilvl display, and missing enchant/gem indicators
-- ============================================================================

local ADDON_NAME, TweaksUI = ...

TweaksUI.CharacterPanel = {}
local CharacterPanel = TweaksUI.CharacterPanel

-- ============================================================================
-- CONSTANTS
-- ============================================================================

-- Equipment slot IDs (matches INVSLOT_* constants)
local EQUIPMENT_SLOTS = {
    INVSLOT_HEAD = 1,
    INVSLOT_NECK = 2,
    INVSLOT_SHOULDER = 3,
    INVSLOT_BACK = 15,
    INVSLOT_CHEST = 5,
    INVSLOT_WRIST = 9,
    INVSLOT_HAND = 10,
    INVSLOT_WAIST = 6,
    INVSLOT_LEGS = 7,
    INVSLOT_FEET = 8,
    INVSLOT_FINGER1 = 11,
    INVSLOT_FINGER2 = 12,
    INVSLOT_TRINKET1 = 13,
    INVSLOT_TRINKET2 = 14,
    INVSLOT_MAINHAND = 16,
    INVSLOT_OFFHAND = 17,
}

-- Map slot IDs to frame names
local SLOT_FRAME_NAMES = {
    [1] = "CharacterHeadSlot",
    [2] = "CharacterNeckSlot",
    [3] = "CharacterShoulderSlot",
    [5] = "CharacterChestSlot",
    [6] = "CharacterWaistSlot",
    [7] = "CharacterLegsSlot",
    [8] = "CharacterFeetSlot",
    [9] = "CharacterWristSlot",
    [10] = "CharacterHandsSlot",
    [11] = "CharacterFinger0Slot",
    [12] = "CharacterFinger1Slot",
    [13] = "CharacterTrinket0Slot",
    [14] = "CharacterTrinket1Slot",
    [15] = "CharacterBackSlot",
    [16] = "CharacterMainHandSlot",
    [17] = "CharacterSecondaryHandSlot",
}

-- Slots that can be enchanted in Midnight
-- Note: Legs use spellthreads/armor kits from Tailoring/Leatherworking
local ENCHANTABLE_SLOTS = {
    [5] = true,   -- Chest
    [7] = true,   -- Legs (spellthread/armor kit)
    [8] = true,   -- Feet
    [9] = true,   -- Wrist
    [11] = true,  -- Ring 1
    [12] = true,  -- Ring 2
    [15] = true,  -- Back (Cloak)
    [16] = true,  -- Main Hand
    [17] = true,  -- Off Hand (if weapon)
}

-- Item classes that indicate special items (from Enum.ItemClass)
local ITEM_CLASS_WEAPON = 2
local ITEM_CLASS_ARMOR = 4

-- Quality colors (built-in WoW table)
local QUALITY_COLORS = ITEM_QUALITY_COLORS

-- ============================================================================
-- STATE
-- ============================================================================

local isInitialized = false
local isEnabled = false
local slotOverlays = {}  -- Store our overlay frames
local preciseIlvlText = nil  -- Our precise ilvl display

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Safe wrapper for potentially secret values (Midnight)
local function SafeValue(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

-- Safe pcall wrapper that returns nil on error
local function SafeCall(func, ...)
    if not func then return nil end
    local success, result = pcall(func, ...)
    if success then
        return result
    end
    return nil
end

-- C_Item API wrappers (Midnight uses C_Item namespace for many item APIs)
local function GetItemInfoSafe(itemLink)
    if not itemLink then return nil end
    
    -- Try C_Item first (preferred in Midnight)
    if C_Item and C_Item.GetItemInfo then
        local success, result = pcall(C_Item.GetItemInfo, itemLink)
        if success and result then return result end
    end
    
    -- Fallback to global function
    if GetItemInfo then
        local success, result = pcall(GetItemInfo, itemLink)
        if success then return result end
    end
    
    return nil
end

local function GetDetailedItemLevelInfoSafe(itemLink)
    if not itemLink then return nil end
    
    -- Midnight path - need pcall for secret values
    if C_Item and C_Item.GetDetailedItemLevelInfo then
        local success, result = pcall(C_Item.GetDetailedItemLevelInfo, itemLink)
        if success and result then return result end
    end
    
    if GetDetailedItemLevelInfo then
        local success, result = pcall(GetDetailedItemLevelInfo, itemLink)
        if success and result then return result end
    end
    
    -- Ultimate fallback: try to get item level from GetItemInfo
    if GetItemInfo then
        local _, _, _, itemLevel = GetItemInfo(itemLink)
        return itemLevel
    end
    
    return nil
end

local function GetItemQuality(itemLink)
    if not itemLink then return nil end
    
    -- Midnight path - use C_Item API
    if C_Item and C_Item.GetItemQualityByID then
        local itemID = GetItemInfoInstant and GetItemInfoInstant(itemLink)
        if itemID then
            local success, result = pcall(C_Item.GetItemQualityByID, itemID)
            if success and result then return result end
        end
    end
    
    -- Fallback: get quality from GetItemInfo
    if GetItemInfo then
        local _, _, quality = GetItemInfo(itemLink)
        return quality
    end
    
    return nil
end

-- Parse item link to extract enchant ID
-- Item link format: |cff...|Hitem:itemID:enchantID:gem1:gem2:gem3:gem4:...|h[Name]|h|r
local function GetEnchantIDFromLink(itemLink)
    if not itemLink then return nil end
    
    local linkType, itemString = itemLink:match("|H([^:]+):([^|]+)|h")
    if linkType ~= "item" then return nil end
    
    local parts = {strsplit(":", itemString)}
    local enchantID = tonumber(parts[2]) or 0
    
    return enchantID > 0 and enchantID or nil
end

-- Check if an item has empty gem sockets
-- Returns: hasEmptySockets, totalSockets, filledSockets
local function CheckItemSockets(itemLink, slotID)
    if not itemLink then return false, 0, 0 end
    
    -- Wrap in pcall to handle any API differences between WoW versions
    local success, hasEmpty, total, filled = pcall(function()
        local totalSockets = 0
        local filledSockets = 0
        
        -- For equipped items, we need to use tooltip scanning
        -- This is the most reliable method as it catches all socket types
        local tooltipName = "TweaksUICharPanelTooltip"
        local tooltip = _G[tooltipName]
        if not tooltip then
            tooltip = CreateFrame("GameTooltip", tooltipName, nil, "GameTooltipTemplate")
            tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
        end
        
        tooltip:ClearLines()
        tooltip:SetInventoryItem("player", slotID)
        
        -- Scan tooltip for socket indicators
        local numLines = tooltip:NumLines()
        for i = 1, numLines do
            local leftText = _G[tooltipName.."TextLeft"..i]
            if leftText then
                local text = leftText:GetText()
                if text then
                    -- Check for empty socket text patterns
                    -- These textures indicate empty sockets
                    if text:find("Interface\\ItemSocketingFrame\\UI%-EmptySocket") then
                        totalSockets = totalSockets + 1
                    end
                end
            end
        end
        
        -- Use GetItemGem to count filled sockets
        if GetItemGem then
            for i = 1, 4 do
                local gemName, gemLink = GetItemGem(itemLink, i)
                if gemLink then
                    filledSockets = filledSockets + 1
                    -- If we find a gem but didn't count empty sockets, there's at least one socket
                    if totalSockets < filledSockets then
                        totalSockets = filledSockets
                    end
                end
            end
        end
        
        -- Fallback: Parse the item stats for socket info if tooltip didn't work
        if totalSockets == 0 then
            local GetItemStatsFunc = (C_Item and C_Item.GetItemStats) or GetItemStats
            local stats = GetItemStatsFunc and GetItemStatsFunc(itemLink)
            if stats then
                local socketCount = 0
                local socketTypes = {
                    "EMPTY_SOCKET_RED", "EMPTY_SOCKET_YELLOW", "EMPTY_SOCKET_BLUE",
                    "EMPTY_SOCKET_PRISMATIC", "EMPTY_SOCKET_META", "EMPTY_SOCKET_COGWHEEL",
                    "EMPTY_SOCKET_HYDRAULIC", "EMPTY_SOCKET_NO_COLOR", "EMPTY_SOCKET_DOMINATION",
                    "EMPTY_SOCKET_CYPHER", "EMPTY_SOCKET_TINKER", "EMPTY_SOCKET_PRIMORDIAL"
                }
                for _, socketType in ipairs(socketTypes) do
                    if stats[socketType] then
                        socketCount = socketCount + stats[socketType]
                    end
                end
                
                if socketCount > 0 then
                    totalSockets = socketCount
                end
            end
        end
        
        local hasEmptySockets = totalSockets > filledSockets
        return hasEmptySockets, totalSockets, filledSockets
    end)
    
    if success then
        return hasEmpty, total, filled
    end
    return false, 0, 0
end

-- Get special item type (Heirloom, Artifact, etc.)
local function GetSpecialItemType(itemLink, slotID)
    if not itemLink then return nil end
    
    local quality = GetItemQuality(itemLink)
    
    -- Also get classID for special checks
    local _, _, _, _, _, _, _, _, _, _, _, classID = GetItemInfo(itemLink)
    
    -- Handle potentially secret values (Midnight)
    quality = SafeValue(quality)
    classID = SafeValue(classID)
    
    -- Check for Heirloom quality
    if quality == 7 then  -- LE_ITEM_QUALITY_HEIRLOOM / Enum.ItemQuality.Heirloom
        return "Heirloom"
    end
    
    -- Check for Artifact quality
    if quality == 6 then  -- LE_ITEM_QUALITY_ARTIFACT / Enum.ItemQuality.Artifact
        return "Artifact"
    end
    
    -- Check for WoW Token or similar special items
    if quality == 5 and classID == 15 then  -- Legendary + Misc
        return "Special"
    end
    
    return nil
end

-- Check if a slot can have an enchant (considering item type)
local function CanSlotBeEnchanted(slotID, itemLink)
    if not ENCHANTABLE_SLOTS[slotID] then
        return false
    end
    
    if not itemLink then
        return false
    end
    
    -- Off-hand slot: only weapons can be enchanted (not shields/off-hands for most)
    if slotID == 17 then
        local _, _, _, _, _, _, _, _, _, _, _, classID = GetItemInfo(itemLink)
        classID = SafeValue(classID)
        -- Only weapons (not held in off-hand items or shields typically)
        -- Weapon enchants work on off-hand weapons
        if classID == ITEM_CLASS_WEAPON then
            return true
        end
        return false
    end
    
    -- Check for special items that can't be enchanted
    local specialType = GetSpecialItemType(itemLink, slotID)
    if specialType == "Artifact" then
        -- Legion artifacts have their own system
        return false
    end
    
    return true
end

-- ============================================================================
-- OVERLAY CREATION
-- ============================================================================

local function CreateSlotOverlay(slotFrame, slotID)
    if not slotFrame then return nil end
    
    local overlay = CreateFrame("Frame", nil, slotFrame)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(slotFrame:GetFrameLevel() + 10)
    overlay:Hide()  -- Start hidden until Enable() is called
    
    -- Item level text (bottom right of slot) with dark background
    local ilvlBg = overlay:CreateTexture(nil, "BACKGROUND")
    ilvlBg:SetColorTexture(0, 0, 0, 0.7)
    ilvlBg:SetPoint("BOTTOMRIGHT", -1, 1)
    ilvlBg:SetSize(32, 18)
    ilvlBg:Hide()  -- Start hidden until UpdateSlotOverlay shows it
    overlay.ilvlBg = ilvlBg
    
    local ilvlText = overlay:CreateFontString(nil, "OVERLAY")
    ilvlText:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    ilvlText:SetPoint("BOTTOMRIGHT", -2, 2)
    ilvlText:SetJustifyH("RIGHT")
    overlay.ilvlText = ilvlText
    
    -- Missing indicator text (top left - shows "E" for enchant, "G" for gem)
    local missingBg = overlay:CreateTexture(nil, "BACKGROUND")
    missingBg:SetColorTexture(0.3, 0, 0, 0.8)
    missingBg:SetPoint("TOPLEFT", 1, -1)
    missingBg:SetSize(20, 16)
    missingBg:Hide()
    overlay.missingBg = missingBg
    
    local missingText = overlay:CreateFontString(nil, "OVERLAY")
    missingText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    missingText:SetPoint("TOPLEFT", 2, -2)
    missingText:SetJustifyH("LEFT")
    missingText:SetTextColor(1, 0.3, 0.3)  -- Bright red for missing
    overlay.missingText = missingText
    
    -- Special type text (top center, for Heirloom/Artifact)
    local specialText = overlay:CreateFontString(nil, "OVERLAY")
    specialText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    specialText:SetPoint("TOP", 0, -2)
    specialText:SetJustifyH("CENTER")
    specialText:SetTextColor(0.9, 0.8, 0.5)  -- Gold-ish
    overlay.specialText = specialText
    
    overlay.slotID = slotID
    
    return overlay
end

-- ============================================================================
-- UPDATE FUNCTIONS
-- ============================================================================

local function UpdateSlotOverlay(overlay)
    if not overlay or not isEnabled then return end
    
    local slotID = overlay.slotID
    local itemLink = GetInventoryItemLink("player", slotID)
    
    -- Clear all text first
    overlay.ilvlText:SetText("")
    overlay.missingText:SetText("")
    overlay.specialText:SetText("")
    overlay.ilvlBg:Hide()
    overlay.missingBg:Hide()
    
    if not itemLink then return end
    
    -- Get item level with quality color
    local effectiveIlvl = GetDetailedItemLevelInfoSafe(itemLink)
    local quality = GetItemQuality(itemLink)
    
    -- Handle potentially secret values (Midnight)
    effectiveIlvl = SafeValue(effectiveIlvl)
    quality = SafeValue(quality)
    
    if effectiveIlvl and type(effectiveIlvl) == "number" and quality then
        local color = QUALITY_COLORS and QUALITY_COLORS[quality]
        if color then
            overlay.ilvlText:SetTextColor(color.r, color.g, color.b)
        else
            overlay.ilvlText:SetTextColor(1, 1, 1)
        end
        overlay.ilvlText:SetText(tostring(math.floor(effectiveIlvl)))
        overlay.ilvlBg:Show()
    end
    
    -- Check for special item types
    local specialType = GetSpecialItemType(itemLink, slotID)
    if specialType then
        overlay.specialText:SetText(specialType)
        -- Don't show missing enchant/gem for special items
        return
    end
    
    -- Build missing indicators
    local missingParts = {}
    
    -- Check for missing enchant
    if CanSlotBeEnchanted(slotID, itemLink) then
        local enchantID = GetEnchantIDFromLink(itemLink)
        if not enchantID then
            table.insert(missingParts, "E")
        end
    end
    
    -- Check for empty gem sockets
    local hasEmptySockets = CheckItemSockets(itemLink, slotID)
    if hasEmptySockets then
        table.insert(missingParts, "G")
    end
    
    if #missingParts > 0 then
        overlay.missingText:SetText(table.concat(missingParts, " "))
        overlay.missingBg:Show()
        -- Adjust background width based on content
        local textWidth = overlay.missingText:GetStringWidth()
        overlay.missingBg:SetWidth(textWidth + 6)
    end
end

local function UpdatePreciseItemLevel()
    if not preciseIlvlText or not isEnabled then return end
    
    -- Get average item level
    local overall, equipped = GetAverageItemLevel()
    
    -- Handle potentially secret values (Midnight)
    equipped = SafeValue(equipped)
    
    if equipped and type(equipped) == "number" then
        -- Format to 2 decimal places
        preciseIlvlText:SetText(string.format("%.2f", equipped))
    else
        preciseIlvlText:SetText("---")
    end
end

local function UpdateAllSlots()
    for slotID, overlay in pairs(slotOverlays) do
        UpdateSlotOverlay(overlay)
    end
    UpdatePreciseItemLevel()
end

-- ============================================================================
-- HOOKS AND EVENTS
-- ============================================================================

local eventFrame = CreateFrame("Frame")
eventFrame:Hide()

local function OnEvent(self, event, ...)
    if event == "PLAYER_EQUIPMENT_CHANGED" then
        local slotID = ...
        if slotOverlays[slotID] then
            UpdateSlotOverlay(slotOverlays[slotID])
        end
        UpdatePreciseItemLevel()
    elseif event == "PLAYER_AVG_ITEM_LEVEL_UPDATE" then
        UpdatePreciseItemLevel()
    end
end

eventFrame:SetScript("OnEvent", OnEvent)

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local blizzardIlvlText = nil  -- Reference to Blizzard's ilvl text
local blizzardIlvlHiddenElements = {}  -- All elements we hide from Blizzard's UI

local function FindBlizzardItemLevelText()
    -- Try multiple paths to find Blizzard's item level display
    -- Structure varies between WoW versions
    
    -- Modern retail path (Midnight)
    if PaperDollFrame then
        -- Check for ItemLevelFrame.Value
        if PaperDollFrame.ItemLevelFrame and PaperDollFrame.ItemLevelFrame.Value then
            return PaperDollFrame.ItemLevelFrame.Value
        end
        
        -- Check children of ItemLevelFrame
        if PaperDollFrame.ItemLevelFrame then
            for i = 1, PaperDollFrame.ItemLevelFrame:GetNumRegions() do
                local region = select(i, PaperDollFrame.ItemLevelFrame:GetRegions())
                if region and region:GetObjectType() == "FontString" then
                    local text = region:GetText()
                    if text and tonumber(text) then
                        return region
                    end
                end
            end
        end
    end
    
    -- Try CharacterStatsPane
    if CharacterStatsPane and CharacterStatsPane.ItemLevelFrame then
        if CharacterStatsPane.ItemLevelFrame.Value then
            return CharacterStatsPane.ItemLevelFrame.Value
        end
    end
    
    return nil
end

-- Find ALL font strings in ItemLevelFrame to hide them
local function FindAllBlizzardIlvlElements()
    blizzardIlvlHiddenElements = {}
    
    if not PaperDollFrame or not PaperDollFrame.ItemLevelFrame then
        return
    end
    
    local frame = PaperDollFrame.ItemLevelFrame
    
    -- Get all regions (textures, fontstrings, etc)
    for i = 1, frame:GetNumRegions() do
        local region = select(i, frame:GetRegions())
        if region and region:GetObjectType() == "FontString" then
            table.insert(blizzardIlvlHiddenElements, region)
        end
    end
    
    -- Also check common child keys
    if frame.Value then
        table.insert(blizzardIlvlHiddenElements, frame.Value)
    end
    if frame.Label then
        table.insert(blizzardIlvlHiddenElements, frame.Label)
    end
    
    -- Check child frames
    for _, child in pairs({frame:GetChildren()}) do
        if child then
            for i = 1, child:GetNumRegions() do
                local region = select(i, child:GetRegions())
                if region and region:GetObjectType() == "FontString" then
                    table.insert(blizzardIlvlHiddenElements, region)
                end
            end
        end
    end
end

function CharacterPanel:Initialize()
    if isInitialized then return end
    
    -- Wait for PaperDollFrame to exist
    if not PaperDollFrame then
        C_Timer.After(0.5, function() self:Initialize() end)
        return
    end
    
    -- Create overlays for each equipment slot
    for slotID, frameName in pairs(SLOT_FRAME_NAMES) do
        local slotFrame = _G[frameName]
        if slotFrame then
            slotOverlays[slotID] = CreateSlotOverlay(slotFrame, slotID)
        end
    end
    
    -- Find Blizzard's item level text
    blizzardIlvlText = FindBlizzardItemLevelText()
    
    -- Find ALL Blizzard item level elements to hide
    FindAllBlizzardIlvlElements()
    
    -- Create a frame to hold our precise item level text
    -- Check if frame already exists (from previous session/reload)
    local ilvlFrame = _G["TweaksUI_PreciseIlvlFrame"]
    local existingFrame = ilvlFrame ~= nil
    
    if not ilvlFrame then
        ilvlFrame = CreateFrame("Frame", "TweaksUI_PreciseIlvlFrame", PaperDollFrame)
    end
    
    ilvlFrame:SetFrameStrata("HIGH")
    ilvlFrame:SetSize(100, 30)
    ilvlFrame:ClearAllPoints()  -- Clear any existing points
    
    -- Use absolute positioning relative to PaperDollFrame
    -- Move UP to be in the Item Level box area (more negative Y = lower, less negative = higher)
    ilvlFrame:SetPoint("TOPRIGHT", PaperDollFrame, "TOPRIGHT", -60, -105)
    
    -- Only create font string if frame is new (avoid duplicates on reload)
    if not existingFrame then
        preciseIlvlText = ilvlFrame:CreateFontString(nil, "OVERLAY")
        preciseIlvlText:SetFont(STANDARD_TEXT_FONT, 18, "OUTLINE")
        preciseIlvlText:SetTextColor(1, 0.82, 0)  -- Gold color
        preciseIlvlText:SetPoint("CENTER", ilvlFrame, "CENTER", 0, 0)
        preciseIlvlText:SetText("")  -- Empty by default
        preciseIlvlText:Hide()  -- Explicitly hide
    else
        -- Find existing font string and hide it
        for i = 1, ilvlFrame:GetNumRegions() do
            local region = select(i, ilvlFrame:GetRegions())
            if region and region:GetObjectType() == "FontString" then
                preciseIlvlText = region
                preciseIlvlText:SetText("")  -- Clear any stale text
                preciseIlvlText:Hide()  -- Explicitly hide
                break
            end
        end
    end
    
    ilvlFrame:Hide()  -- Start hidden
    ilvlFrame:SetAlpha(0)  -- Double ensure invisibility
    CharacterPanel.ilvlFrame = ilvlFrame
    
    -- Ensure all overlays start hidden (handles reload case where frames persist)
    for slotID, overlay in pairs(slotOverlays) do
        overlay:Hide()
    end
    
    -- Hook into PaperDollFrame updates
    if PaperDollFrame then
        PaperDollFrame:HookScript("OnShow", function()
            if isEnabled then
                UpdateAllSlots()
            end
        end)
    end
    
    isInitialized = true
end

function CharacterPanel:Enable()
    if isEnabled then return end
    
    if not isInitialized then
        self:Initialize()
    end
    
    isEnabled = true
    
    -- Show all overlays
    for slotID, overlay in pairs(slotOverlays) do
        overlay:Show()
    end
    
    -- Show our precise ilvl frame and text
    if CharacterPanel.ilvlFrame then
        CharacterPanel.ilvlFrame:SetAlpha(1)  -- Restore alpha
        CharacterPanel.ilvlFrame:Show()
    end
    if preciseIlvlText then
        preciseIlvlText:Show()
        -- Force an update immediately
        local _, equipped = GetAverageItemLevel()
        equipped = SafeValue(equipped)
        if equipped and type(equipped) == "number" then
            preciseIlvlText:SetText(string.format("%.2f", equipped))
        else
            preciseIlvlText:SetText("---")
        end
    end
    
    -- Hide Blizzard's text if we found it
    if blizzardIlvlText then
        blizzardIlvlText:SetAlpha(0)
    end
    
    -- Hide ALL Blizzard item level elements
    for _, element in ipairs(blizzardIlvlHiddenElements) do
        if element and element.SetAlpha then
            element:SetAlpha(0)
        end
    end
    
    -- Register events
    eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    eventFrame:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
    eventFrame:Show()
    
    -- Update if character panel is already shown
    if PaperDollFrame and PaperDollFrame:IsShown() then
        UpdateAllSlots()
    end
end

function CharacterPanel:Disable()
    if not isEnabled then return end
    
    isEnabled = false
    
    -- Hide all overlays
    for slotID, overlay in pairs(slotOverlays) do
        overlay:Hide()
    end
    
    -- Hide our precise ilvl frame
    if CharacterPanel.ilvlFrame then
        CharacterPanel.ilvlFrame:Hide()
        CharacterPanel.ilvlFrame:SetAlpha(0)
    end
    if preciseIlvlText then
        preciseIlvlText:Hide()
        preciseIlvlText:SetText("")  -- Clear text
    end
    
    -- Restore Blizzard's text
    if blizzardIlvlText then
        blizzardIlvlText:SetAlpha(1)
    end
    
    -- Restore ALL Blizzard item level elements
    for _, element in ipairs(blizzardIlvlHiddenElements) do
        if element and element.SetAlpha then
            element:SetAlpha(1)
        end
    end
    
    -- Unregister events
    eventFrame:UnregisterAllEvents()
    eventFrame:Hide()
end

function CharacterPanel:IsEnabled()
    return isEnabled
end

function CharacterPanel:Refresh()
    if isEnabled then
        UpdateAllSlots()
    end
end

-- Force cleanup of any visible elements (called when feature is disabled)
function CharacterPanel:ForceCleanup()
    -- Hide global frame if it exists
    local frame = _G["TweaksUI_PreciseIlvlFrame"]
    if frame then
        frame:Hide()
        frame:SetAlpha(0)
        -- Hide all fontstrings in it
        for i = 1, frame:GetNumRegions() do
            local region = select(i, frame:GetRegions())
            if region then
                if region.Hide then region:Hide() end
                if region.SetText then region:SetText("") end
                if region.SetAlpha then region:SetAlpha(0) end
            end
        end
    end
    
    -- Hide all slot overlays
    for slotID, overlay in pairs(slotOverlays) do
        if overlay then
            overlay:Hide()
        end
    end
end
