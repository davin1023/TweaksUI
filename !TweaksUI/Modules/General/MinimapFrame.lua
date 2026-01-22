-- TweaksUI Custom Minimap Frame
-- Reparents Blizzard's Minimap and decorations to our own container
-- Handles ALL minimap settings from General module

local ADDON_NAME, TweaksUI = ...

-- ============================================================================
-- MODULE SETUP
-- ============================================================================

local MinimapFrame = {}
TweaksUI.MinimapFrame = MinimapFrame

-- State
local initialized = false
local enabled = false

-- Frame references
local containerFrame = nil
local borderFrame = nil
local coordsFrame = nil
local layoutWrapper = nil  -- TUIFrame wrapper for Layout integration

-- Original state for restoration
local originalMinimapParent = nil
local originalMinimapPoints = {}
local originalMinimapScale = nil
local originalDecorationData = {}

-- Decoration position overrides (saved per-decoration)
local decorationPositions = {}

-- Settings reference
local function GetSettings()
    if TweaksUI.General and TweaksUI.General.GetMinimapSetting then
        return TweaksUI.General
    end
    return nil
end

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local MINIMAP_SIZE = 140
local DEFAULT_BORDER_WIDTH = 2
local DEFAULT_BORDER_COLOR = { r = 0.3, g = 0.3, b = 0.3 }

-- Blizzard decoration frames to reparent
-- Format: { key, frame path, anchor, relTo, relPoint, x, y }
-- NOTE: Zoom buttons (Minimap.ZoomIn, Minimap.ZoomOut) are children of Minimap
-- and come along automatically when Minimap is reparented - don't reparent them separately
local DECORATION_CONFIG = {
    { key = "calendar",           frame = "GameTimeFrame",              anchor = "TOPRIGHT",    relTo = "Minimap", relPoint = "TOPRIGHT",    x = 2,   y = 2 },
    { key = "tracking",           frame = "MinimapCluster.Tracking", anchor = "TOPLEFT",   relTo = "Minimap", relPoint = "TOPLEFT",     x = -2,  y = 2 },
    { key = "instanceDifficulty", frame = "MinimapCluster.InstanceDifficulty", anchor = "TOPLEFT", relTo = "Minimap", relPoint = "TOPLEFT", x = -10, y = 10 },
    { key = "clock",              frame = "TimeManagerClockButton",     anchor = "BOTTOM",      relTo = "Minimap", relPoint = "BOTTOM",      x = 0,   y = -2 },
    -- Zoom buttons removed - they're children of Minimap and reparent automatically
    { key = "mail",               frame = "MinimapCluster.IndicatorFrame.MailFrame", anchor = "BOTTOMLEFT", relTo = "Minimap", relPoint = "BOTTOMLEFT", x = 0, y = 0 },
    { key = "craftingOrder",      frame = "MinimapCluster.IndicatorFrame.CraftingOrderFrame", anchor = "BOTTOMLEFT", relTo = "Minimap", relPoint = "BOTTOMLEFT", x = 20, y = 0 },
    { key = "addonCompartment",   frame = "AddonCompartmentFrame",      anchor = "TOPRIGHT",    relTo = "Minimap", relPoint = "TOPRIGHT",    x = -30, y = 2 },
    -- ExpansionLandingPageMinimapButton excluded - reparenting breaks Blizzard's tooltip code
    -- { key = "expansionButton",    frame = "ExpansionLandingPageMinimapButton", anchor = "BOTTOMLEFT", relTo = "Minimap", relPoint = "BOTTOMLEFT", x = -5, y = -5 },
    { key = "zoneText",           frame = "MinimapCluster.ZoneTextButton", anchor = "TOP", relTo = "Minimap", relPoint = "TOP", x = 0, y = 15 },
}

-- Blizzard border frames
local BLIZZARD_BORDER_FRAMES = {
    "MinimapBorder",
    "MinimapBorderTop", 
    "MinimapCompassTexture",
}

-- Zone text background frame
local ZONE_TEXT_BG_FRAME = "MinimapCluster.BorderTop"

-- ============================================================================
-- HELPER: Get frame by path
-- ============================================================================

local function GetFrameByPath(path)
    if not path then return nil end
    
    local parts = { strsplit(".", path) }
    local frame = _G[parts[1]]
    
    for i = 2, #parts do
        if frame then
            frame = frame[parts[i]]
        else
            return nil
        end
    end
    
    return frame
end

-- ============================================================================
-- DRAG FUNCTIONALITY (Shift+Ctrl for minimap, Alt+Shift for decorations)
-- ============================================================================

local function StartDragging()
    if containerFrame and IsShiftKeyDown() and IsControlKeyDown() then
        containerFrame:StartMoving()
        containerFrame.isMoving = true
    end
end

local function StopDragging()
    if containerFrame and containerFrame.isMoving then
        containerFrame:StopMovingOrSizing()
        containerFrame.isMoving = false
        MinimapFrame:SavePosition()
    end
end

-- Decoration drag handlers
local function StartDecorationDrag(frame, framePath)
    if IsAltKeyDown() and IsShiftKeyDown() then
        frame:StartMoving()
        frame.isMovingDecoration = true
        frame.decorationPath = framePath
    end
end

local function StopDecorationDrag(frame)
    if frame.isMovingDecoration then
        frame:StopMovingOrSizing()
        frame.isMovingDecoration = false
        
        -- Calculate position relative to Minimap center
        local frameCenter_x, frameCenter_y = frame:GetCenter()
        local minimapCenter_x, minimapCenter_y = Minimap:GetCenter()
        
        if frameCenter_x and minimapCenter_x then
            local scale = frame:GetEffectiveScale() / Minimap:GetEffectiveScale()
            local x = (frameCenter_x - minimapCenter_x) / scale
            local y = (frameCenter_y - minimapCenter_y) / scale
            
            -- Re-anchor to Minimap CENTER with calculated offset
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", Minimap, "CENTER", x, y)
            
            -- Save the position
            MinimapFrame:SaveDecorationPosition(frame.decorationPath, "CENTER", "CENTER", x, y)
        end
    end
end

-- ============================================================================
-- DECORATION POSITION SAVING
-- ============================================================================

function MinimapFrame:SaveDecorationPosition(framePath, point, relPoint, x, y)
    local general = GetSettings()
    if not general then return end
    
    local positions = general:GetMinimapSetting("decorationPositions") or {}
    positions[framePath] = { point = point, relPoint = relPoint, x = x, y = y }
    general:SetMinimapSetting("decorationPositions", positions)
    
    TweaksUI:PrintDebug("MinimapFrame: Saved position for " .. framePath)
end

function MinimapFrame:GetDecorationPosition(framePath)
    local general = GetSettings()
    if not general then return nil end
    
    local positions = general:GetMinimapSetting("decorationPositions")
    if positions and positions[framePath] then
        return positions[framePath]
    end
    
    return nil
end

function MinimapFrame:ResetDecorationPositions()
    local general = GetSettings()
    if general then
        general:SetMinimapSetting("decorationPositions", {})
        TweaksUI:Print("Decoration positions reset. Reload to apply defaults.")
    end
end

-- ============================================================================
-- CONTAINER FRAME
-- ============================================================================

function MinimapFrame:CreateContainer()
    if containerFrame then return containerFrame end
    
    -- Get actual minimap size
    local mapWidth = Minimap and Minimap:GetWidth() or MINIMAP_SIZE
    local mapHeight = Minimap and Minimap:GetHeight() or MINIMAP_SIZE
    
    containerFrame = CreateFrame("Frame", "TweaksUI_MinimapContainer", UIParent)
    containerFrame:SetSize(mapWidth, mapHeight)
    containerFrame:SetFrameStrata("LOW")
    containerFrame:SetFrameLevel(10)
    containerFrame:SetClampedToScreen(true)
    containerFrame:SetMovable(true)
    -- DON'T enable mouse on container - let clicks pass through to Minimap and its children (zoom buttons)
    -- Dragging is handled by Minimap itself
    containerFrame:EnableMouse(false)
    
    -- START HIDDEN: Prevent visible position jumps during initialization
    -- Will be revealed by TUIFrame.RevealAllFrames after all positioning is complete
    containerFrame:SetAlpha(0)
    if TweaksUI.TUIFrame and TweaksUI.TUIFrame.RegisterPendingFrame then
        TweaksUI.TUIFrame.RegisterPendingFrame(containerFrame)
    end
    
    -- Position at Minimap's current screen location (to align with Blizzard's frame on first enable)
    -- GetCenter returns coordinates relative to UIParent's bottom-left
    if Minimap then
        local centerX, centerY = Minimap:GetCenter()
        if centerX and centerY then
            containerFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", centerX, centerY)
            TweaksUI:PrintDebug("MinimapFrame: Container positioned at center " .. math.floor(centerX) .. ", " .. math.floor(centerY))
        else
            containerFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -10, -10)
        end
    else
        containerFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -10, -10)
    end
    
    -- Add Layout method to prevent errors when Blizzard code calls it on reparented children
    containerFrame.Layout = function() end
    
    -- No mouse handlers on container - dragging is handled by Minimap via modifier keys
    
    TweaksUI:PrintDebug("MinimapFrame: Container created")
    return containerFrame
end

-- ============================================================================
-- POSITION SAVE/RESTORE
-- ============================================================================

function MinimapFrame:SavePosition()
    if not containerFrame then return end
    local point, _, relPoint, x, y = containerFrame:GetPoint(1)
    local general = GetSettings()
    if general then
        general:SetMinimapSetting("customPosition", { point = point, relPoint = relPoint, x = x, y = y })
    end
end

function MinimapFrame:RestorePosition()
    if not containerFrame then return end
    
    -- If Layout module exists, don't restore here - Layout will handle positioning
    -- This check must happen BEFORE layoutWrapper is set because RestorePosition
    -- runs before RegisterWithLayout in the initialization sequence
    if TweaksUI.Layout then
        TweaksUI:PrintDebug("MinimapFrame: Deferring to Layout module for positioning")
        return
    end
    
    local general = GetSettings()
    if not general then return end
    
    local pos = general:GetMinimapSetting("customPosition")
    if pos and pos.point then
        containerFrame:ClearAllPoints()
        containerFrame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    end
end

-- ============================================================================
-- BORDER FRAME
-- ============================================================================

function MinimapFrame:CreateBorder()
    if borderFrame then return borderFrame end
    if not containerFrame then return nil end
    
    borderFrame = CreateFrame("Frame", "TweaksUI_MinimapBorder", containerFrame, "BackdropTemplate")
    borderFrame:SetFrameLevel(containerFrame:GetFrameLevel() + 20)
    -- Disable mouse so clicks pass through to Minimap and zoom buttons
    borderFrame:EnableMouse(false)
    
    return borderFrame
end

function MinimapFrame:UpdateBorder()
    if not borderFrame then return end
    
    local general = GetSettings()
    local width = DEFAULT_BORDER_WIDTH
    local color = DEFAULT_BORDER_COLOR
    local hideBorder = false
    local isSquare = false
    
    if general then
        width = general:GetCustomBorderSetting("width") or DEFAULT_BORDER_WIDTH
        local savedColor = general:GetCustomBorderSetting("color")
        if savedColor then color = savedColor end
        hideBorder = general:GetMinimapHideSetting("border")
        isSquare = general:GetMinimapSetting("squareShape")
    end
    
    -- Position border to match Minimap
    borderFrame:ClearAllPoints()
    borderFrame:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -width, width)
    borderFrame:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", width, -width)
    
    -- Square mode: show our custom border (unless hidden)
    if isSquare and not hideBorder then
        borderFrame:SetBackdrop({
            edgeFile = "Interface\\BUTTONS\\WHITE8X8",
            edgeSize = width,
        })
        borderFrame:SetBackdropBorderColor(color.r or 0.3, color.g or 0.3, color.b or 0.3, 1)
        borderFrame:Show()
    else
        borderFrame:SetBackdrop(nil)
        borderFrame:Hide()
    end
    
    -- Control Blizzard border visibility
    self:UpdateBlizzardBorderVisibility()
end

function MinimapFrame:UpdateBlizzardBorderVisibility()
    local general = GetSettings()
    local hideBorder = general and general:GetMinimapHideSetting("border") or false
    local isSquare = general and general:GetMinimapSetting("squareShape") or false
    
    for _, frameName in ipairs(BLIZZARD_BORDER_FRAMES) do
        local frame = _G[frameName]
        if frame then
            if isSquare or hideBorder then
                frame:SetAlpha(0)
                frame:Hide()
            else
                frame:SetAlpha(1)
                frame:Show()
            end
        end
    end
end

-- ============================================================================
-- ZONE TEXT BACKGROUND
-- ============================================================================

function MinimapFrame:UpdateZoneTextBackground()
    local general = GetSettings()
    local hideZoneBg = general and general:GetMinimapHideSetting("zoneTextBackground") or false
    
    local bgFrame = GetFrameByPath(ZONE_TEXT_BG_FRAME)
    if bgFrame then
        if hideZoneBg then
            bgFrame:SetAlpha(0)
        else
            bgFrame:SetAlpha(1)
        end
    end
end

-- ============================================================================
-- COORDINATES DISPLAY
-- ============================================================================

function MinimapFrame:CreateCoordsDisplay()
    if coordsFrame then return coordsFrame end
    if not containerFrame then return nil end
    
    coordsFrame = CreateFrame("Frame", "TweaksUI_MinimapCoords", containerFrame)
    coordsFrame:SetSize(80, 14)
    coordsFrame:SetFrameLevel(containerFrame:GetFrameLevel() + 25)
    -- Disable mouse so clicks pass through to Minimap and zoom buttons
    coordsFrame:EnableMouse(false)
    
    -- Restore saved position or use default
    local savedPos = self:GetDecorationPosition("TweaksUI_MinimapCoords")
    if savedPos then
        coordsFrame:SetPoint(savedPos.point, Minimap, savedPos.relPoint, savedPos.x, savedPos.y)
    else
        coordsFrame:SetPoint("BOTTOM", Minimap, "BOTTOM", 0, 4)
    end
    
    local bg = coordsFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.5)
    
    local text = coordsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetAllPoints()
    text:SetTextColor(1, 1, 1, 1)
    coordsFrame.text = text
    
    local elapsed = 0
    coordsFrame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed < 0.1 then return end
        elapsed = 0
        
        local mapID = C_Map.GetBestMapForUnit("player")
        if mapID then
            local pos = C_Map.GetPlayerMapPosition(mapID, "player")
            if pos then
                self.text:SetText(string.format("%.1f, %.1f", pos.x * 100, pos.y * 100))
                return
            end
        end
        self.text:SetText("")
    end)
    
    coordsFrame:Hide()
    
    -- Make coords draggable (true = our own frame)
    self:MakeDecorationDraggable(coordsFrame, "TweaksUI_MinimapCoords", true)
    
    return coordsFrame
end

-- ============================================================================
-- CUSTOM ZOOM BUTTONS (replaces Blizzard's non-functional ones after reparent)
-- ============================================================================

local zoomInButton = nil
local zoomOutButton = nil

function MinimapFrame:CreateZoomButtons()
    if zoomInButton then return end
    if not containerFrame then return end
    
    local buttonSize = 18
    
    -- Zoom In button
    zoomInButton = CreateFrame("Button", "TweaksUI_MinimapZoomIn", containerFrame)
    zoomInButton:SetSize(buttonSize, buttonSize)
    zoomInButton:SetFrameStrata("HIGH")
    zoomInButton:SetFrameLevel(100)
    zoomInButton:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", -2, 20)
    
    local zoomInBg = zoomInButton:CreateTexture(nil, "BACKGROUND")
    zoomInBg:SetAllPoints()
    zoomInBg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    
    local zoomInText = zoomInButton:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    zoomInText:SetPoint("CENTER", 0, 1)
    zoomInText:SetText("+")
    zoomInText:SetTextColor(1, 1, 1, 1)
    zoomInButton.text = zoomInText
    
    zoomInButton:SetScript("OnClick", function()
        Minimap_ZoomIn()
    end)
    
    zoomInButton:SetScript("OnEnter", function(self)
        self:SetAlpha(1)
        zoomInBg:SetColorTexture(0.2, 0.2, 0.2, 0.9)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Zoom In")
        GameTooltip:Show()
    end)
    
    zoomInButton:SetScript("OnLeave", function(self)
        zoomInBg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
        GameTooltip:Hide()
    end)
    
    -- Zoom Out button
    zoomOutButton = CreateFrame("Button", "TweaksUI_MinimapZoomOut", containerFrame)
    zoomOutButton:SetSize(buttonSize, buttonSize)
    zoomOutButton:SetFrameStrata("HIGH")
    zoomOutButton:SetFrameLevel(100)
    zoomOutButton:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", -2, 2)
    
    local zoomOutBg = zoomOutButton:CreateTexture(nil, "BACKGROUND")
    zoomOutBg:SetAllPoints()
    zoomOutBg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    
    local zoomOutText = zoomOutButton:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    zoomOutText:SetPoint("CENTER", 0, 1)
    zoomOutText:SetText("-")
    zoomOutText:SetTextColor(1, 1, 1, 1)
    zoomOutButton.text = zoomOutText
    
    zoomOutButton:SetScript("OnClick", function()
        Minimap_ZoomOut()
    end)
    
    zoomOutButton:SetScript("OnEnter", function(self)
        self:SetAlpha(1)
        zoomOutBg:SetColorTexture(0.2, 0.2, 0.2, 0.9)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Zoom Out")
        GameTooltip:Show()
    end)
    
    zoomOutButton:SetScript("OnLeave", function(self)
        zoomOutBg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
        GameTooltip:Hide()
    end)
    
    -- Initially hidden - shown on minimap hover (matching Blizzard behavior)
    zoomInButton:Hide()
    zoomOutButton:Hide()
    
    TweaksUI:PrintDebug("MinimapFrame: Custom zoom buttons created")
end

function MinimapFrame:UpdateZoomButtonsVisibility()
    local general = GetSettings()
    local shouldHide = general and general:GetMinimapHideSetting("zoomButtons") or false
    
    if shouldHide then
        if zoomInButton then zoomInButton:Hide() end
        if zoomOutButton then zoomOutButton:Hide() end
    else
        -- Will be shown/hidden by hover handler
    end
end

-- ============================================================================
-- CUSTOM MAIL INDICATOR (replaces Blizzard's which doesn't work after reparent)
-- ============================================================================

local mailFrame = nil

function MinimapFrame:CreateMailIndicator()
    if mailFrame then return end
    if not containerFrame then return end
    
    mailFrame = CreateFrame("Button", "TweaksUI_MinimapMail", containerFrame)
    mailFrame:SetSize(28, 28)
    mailFrame:SetFrameStrata("HIGH")
    mailFrame:SetFrameLevel(100)
    mailFrame:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", 2, 2)
    
    local icon = mailFrame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\MINIMAP\\TRACKING\\Mailbox")
    mailFrame.icon = icon
    
    -- Glow/highlight on hover
    local highlight = mailFrame:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetTexture("Interface\\MINIMAP\\TRACKING\\Mailbox")
    highlight:SetBlendMode("ADD")
    highlight:SetAlpha(0.3)
    
    mailFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("New Mail")
        
        -- Try to get mail sender info
        local sender1, sender2, sender3 = GetLatestThreeSenders()
        if sender1 then
            GameTooltip:AddLine(sender1, 1, 1, 1)
        end
        if sender2 then
            GameTooltip:AddLine(sender2, 1, 1, 1)
        end
        if sender3 then
            GameTooltip:AddLine(sender3, 1, 1, 1)
        end
        
        GameTooltip:Show()
    end)
    
    mailFrame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    mailFrame:SetScript("OnClick", function()
        -- If we have a mail minimap button reference, trigger its click
        -- Otherwise just show the tooltip
        if MiniMapMailFrame and MiniMapMailFrame:GetScript("OnClick") then
            MiniMapMailFrame:GetScript("OnClick")(MiniMapMailFrame, "LeftButton")
        end
    end)
    
    mailFrame:Hide()
    
    TweaksUI:PrintDebug("MinimapFrame: Custom mail indicator created")
end

function MinimapFrame:UpdateMailIndicator()
    if not mailFrame then return end
    
    local general = GetSettings()
    local shouldHide = general and general:GetMinimapHideSetting("mail") or false
    
    if shouldHide then
        mailFrame:Hide()
        return
    end
    
    -- Check if player has new mail
    if HasNewMail() then
        mailFrame:Show()
    else
        mailFrame:Hide()
    end
end

-- Register for mail events to update indicator
local mailEventFrame = CreateFrame("Frame")
mailEventFrame:RegisterEvent("UPDATE_PENDING_MAIL")
mailEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
mailEventFrame:SetScript("OnEvent", function()
    if MinimapFrame.UpdateMailIndicator then
        MinimapFrame:UpdateMailIndicator()
    end
end)

-- ============================================================================
-- REPARENT BLIZZARD DECORATIONS
-- ============================================================================

function MinimapFrame:MakeDecorationDraggable(frame, framePath, isOwnFrame)
    if not frame then return end
    
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    
    if isOwnFrame then
        -- For our own frames, use SetScript directly
        frame:SetScript("OnDragStart", function(self)
            StartDecorationDrag(self, framePath)
        end)
        
        frame:SetScript("OnDragStop", function(self)
            StopDecorationDrag(self)
        end)
        
        frame:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" and IsAltKeyDown() and IsShiftKeyDown() then
                StartDecorationDrag(self, framePath)
            end
        end)
        
        frame:SetScript("OnMouseUp", function(self, button)
            StopDecorationDrag(self)
        end)
        
        frame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Coordinates", 1, 0.82, 0)
            GameTooltip:AddLine("Alt+Shift+Drag to reposition", 0.5, 0.8, 1)
            GameTooltip:Show()
        end)
        
        frame:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
    else
        -- For Blizzard frames, try to hook but fall back to SetScript if needed
        local hasOnDragStart = frame:GetScript("OnDragStart") ~= nil
        local hasOnMouseDown = frame:GetScript("OnMouseDown") ~= nil
        
        if hasOnDragStart then
            frame:HookScript("OnDragStart", function(self)
                StartDecorationDrag(self, framePath)
            end)
        else
            frame:SetScript("OnDragStart", function(self)
                StartDecorationDrag(self, framePath)
            end)
        end
        
        if frame:GetScript("OnDragStop") then
            frame:HookScript("OnDragStop", function(self)
                StopDecorationDrag(self)
            end)
        else
            frame:SetScript("OnDragStop", function(self)
                StopDecorationDrag(self)
            end)
        end
        
        if hasOnMouseDown then
            frame:HookScript("OnMouseDown", function(self, button)
                if button == "LeftButton" and IsAltKeyDown() and IsShiftKeyDown() then
                    StartDecorationDrag(self, framePath)
                end
            end)
        else
            frame:SetScript("OnMouseDown", function(self, button)
                if button == "LeftButton" and IsAltKeyDown() and IsShiftKeyDown() then
                    StartDecorationDrag(self, framePath)
                end
            end)
        end
        
        if frame:GetScript("OnMouseUp") then
            frame:HookScript("OnMouseUp", function(self, button)
                StopDecorationDrag(self)
            end)
        else
            frame:SetScript("OnMouseUp", function(self, button)
                StopDecorationDrag(self)
            end)
        end
        
        -- Try to add tooltip hint
        if frame:GetScript("OnEnter") then
            frame:HookScript("OnEnter", function(self)
                C_Timer.After(0.1, function()
                    if GameTooltip:IsShown() and GameTooltip:GetOwner() == self then
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine("Alt+Shift+Drag to reposition", 0.5, 0.8, 1)
                        GameTooltip:Show()
                    end
                end)
            end)
        end
    end
end

function MinimapFrame:ReparentDecorations()
    for _, config in ipairs(DECORATION_CONFIG) do
        local frame = GetFrameByPath(config.frame)
        
        if frame then
            -- Store original data for restoration
            if not originalDecorationData[config.frame] then
                originalDecorationData[config.frame] = {
                    parent = frame:GetParent(),
                    points = {},
                    shown = frame:IsShown(),
                }
                for i = 1, frame:GetNumPoints() do
                    local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint(i)
                    table.insert(originalDecorationData[config.frame].points, {
                        point = point,
                        relativeTo = relativeTo,
                        relativePoint = relativePoint,
                        x = xOfs,
                        y = yOfs
                    })
                end
            end
            
            -- Reparent to our container
            frame:SetParent(containerFrame)
            frame:ClearAllPoints()
            
            -- Check for saved custom position
            local savedPos = self:GetDecorationPosition(config.frame)
            if savedPos then
                local relFrame = Minimap
                frame:SetPoint(savedPos.point, relFrame, savedPos.relPoint, savedPos.x, savedPos.y)
            else
                local relFrame = (config.relTo == "Minimap") and Minimap or containerFrame
                frame:SetPoint(config.anchor, relFrame, config.relPoint, config.x, config.y)
            end
            
            frame:SetFrameLevel(containerFrame:GetFrameLevel() + 15)
            
            -- Make draggable with Alt+Shift (false = Blizzard frame)
            self:MakeDecorationDraggable(frame, config.frame, false)
            
            TweaksUI:PrintDebug("MinimapFrame: Reparented " .. config.frame)
        end
    end
    
    -- Also reparent zone text background
    local bgFrame = GetFrameByPath(ZONE_TEXT_BG_FRAME)
    if bgFrame then
        if not originalDecorationData[ZONE_TEXT_BG_FRAME] then
            originalDecorationData[ZONE_TEXT_BG_FRAME] = {
                parent = bgFrame:GetParent(),
                points = {},
            }
            for i = 1, bgFrame:GetNumPoints() do
                local point, relativeTo, relativePoint, xOfs, yOfs = bgFrame:GetPoint(i)
                table.insert(originalDecorationData[ZONE_TEXT_BG_FRAME].points, {
                    point = point, relativeTo = relativeTo, relativePoint = relativePoint, x = xOfs, y = yOfs
                })
            end
        end
        
        bgFrame:SetParent(containerFrame)
        bgFrame:ClearAllPoints()
        
        -- Check for saved position
        local savedPos = self:GetDecorationPosition(ZONE_TEXT_BG_FRAME)
        if savedPos then
            bgFrame:SetPoint(savedPos.point, Minimap, savedPos.relPoint, savedPos.x, savedPos.y)
        else
            bgFrame:SetPoint("BOTTOM", Minimap, "TOP", 0, -5)
        end
        
        bgFrame:SetFrameLevel(containerFrame:GetFrameLevel() + 14)
        
        -- Make draggable (false = Blizzard frame)
        self:MakeDecorationDraggable(bgFrame, ZONE_TEXT_BG_FRAME, false)
    end
end

function MinimapFrame:RestoreDecorations()
    for framePath, data in pairs(originalDecorationData) do
        local frame = GetFrameByPath(framePath)
        
        if frame and data.parent then
            frame:SetParent(data.parent)
            frame:ClearAllPoints()
            
            for _, pt in ipairs(data.points) do
                frame:SetPoint(pt.point, pt.relativeTo, pt.relativePoint, pt.x, pt.y)
            end
            
            frame:SetAlpha(1)
        end
    end
    
    originalDecorationData = {}
end

function MinimapFrame:ApplyDecorationVisibility()
    local general = GetSettings()
    if not general then return end
    
    for _, config in ipairs(DECORATION_CONFIG) do
        local frame = GetFrameByPath(config.frame)
        
        if frame then
            -- For mail, always hide Blizzard's - we use our own custom indicator
            if config.key == "mail" then
                frame:SetAlpha(0)
                frame:Hide()
            else
                local shouldHide = general:GetMinimapHideSetting(config.key)
                
                if shouldHide then
                    frame:Hide()
                else
                    frame:Show()
                end
            end
        end
    end
    
    -- Always hide Blizzard's zoom buttons - we use our own custom ones
    local zoomIn = Minimap and Minimap.ZoomIn
    local zoomOut = Minimap and Minimap.ZoomOut
    
    if zoomIn then
        zoomIn:SetAlpha(0)
        zoomIn:EnableMouse(false)
        zoomIn:Hide()
    end
    if zoomOut then
        zoomOut:SetAlpha(0)
        zoomOut:EnableMouse(false)
        zoomOut:Hide()
    end
    
    -- Update our custom zoom buttons visibility
    self:UpdateZoomButtonsVisibility()
    
    -- Update our custom mail indicator
    self:UpdateMailIndicator()
    
    -- Zone text background
    self:UpdateZoneTextBackground()
end

-- ============================================================================
-- REPARENT BLIZZARD MINIMAP
-- ============================================================================

function MinimapFrame:ReparentMinimap()
    if not containerFrame or not Minimap then return false end
    
    -- Store original state
    originalMinimapParent = Minimap:GetParent()
    originalMinimapScale = Minimap:GetScale()
    originalMinimapPoints = {}
    for i = 1, Minimap:GetNumPoints() do
        local point, relativeTo, relativePoint, xOfs, yOfs = Minimap:GetPoint(i)
        table.insert(originalMinimapPoints, { point = point, relativeTo = relativeTo, relativePoint = relativePoint, x = xOfs, y = yOfs })
    end
    
    -- Reparent minimap to our container
    Minimap:SetParent(containerFrame)
    Minimap:ClearAllPoints()
    Minimap:SetPoint("CENTER", containerFrame, "CENTER", 0, 0)
    Minimap:SetScale(1)
    Minimap:Show()
    
    -- Hook minimap for drag with modifier keys
    -- Minimap already has EnableMouse for pinging - don't change that
    Minimap:SetMovable(true)
    Minimap:RegisterForDrag("LeftButton")
    Minimap:HookScript("OnDragStart", function(self)
        if IsShiftKeyDown() and IsControlKeyDown() then
            StartDragging()
        end
    end)
    Minimap:HookScript("OnDragStop", StopDragging)
    
    -- Permanently hide Blizzard's zoom buttons - they don't work after reparent
    local blizzZoomIn = Minimap.ZoomIn
    local blizzZoomOut = Minimap.ZoomOut
    
    if blizzZoomIn then
        pcall(function()
            blizzZoomIn:SetAlpha(0)
            blizzZoomIn:EnableMouse(false)
            blizzZoomIn:Hide()
        end)
    end
    
    if blizzZoomOut then
        pcall(function()
            blizzZoomOut:SetAlpha(0)
            blizzZoomOut:EnableMouse(false)
            blizzZoomOut:Hide()
        end)
    end
    
    -- Create our custom zoom buttons and mail indicator
    self:CreateZoomButtons()
    self:CreateMailIndicator()
    
    -- Add hover handlers to show/hide zoom buttons (mimics Blizzard behavior)
    local function ShowZoomButtons()
        local general = GetSettings()
        local shouldHide = general and general:GetMinimapHideSetting("zoomButtons") or false
        if not shouldHide then
            if zoomInButton then zoomInButton:Show() end
            if zoomOutButton then zoomOutButton:Show() end
        end
    end
    
    local function HideZoomButtons()
        -- Only hide if mouse isn't over the buttons themselves
        C_Timer.After(0.1, function()
            -- Use IsMouseOver() which is reliable in Midnight (GetMouseFocus was removed)
            local mouseOverMinimap = Minimap and Minimap:IsMouseOver()
            local mouseOverZoomIn = zoomInButton and zoomInButton:IsMouseOver()
            local mouseOverZoomOut = zoomOutButton and zoomOutButton:IsMouseOver()
            local mouseOverContainer = containerFrame and containerFrame:IsMouseOver()
            
            -- Only hide if mouse isn't over any of these frames
            if not mouseOverMinimap and not mouseOverZoomIn and not mouseOverZoomOut and not mouseOverContainer then
                if zoomInButton then zoomInButton:Hide() end
                if zoomOutButton then zoomOutButton:Hide() end
            end
        end)
    end
    
    Minimap:HookScript("OnEnter", ShowZoomButtons)
    Minimap:HookScript("OnLeave", HideZoomButtons)
    
    -- Reparent Blizzard decorations
    self:ReparentDecorations()
    
    TweaksUI:PrintDebug("MinimapFrame: Minimap reparented with custom zoom buttons")
    return true
end

function MinimapFrame:RestoreMinimap()
    if not Minimap or not originalMinimapParent then return end
    
    -- Restore decorations first
    self:RestoreDecorations()
    
    -- Restore minimap
    Minimap:SetParent(originalMinimapParent)
    Minimap:ClearAllPoints()
    
    if #originalMinimapPoints > 0 then
        for _, pt in ipairs(originalMinimapPoints) do
            Minimap:SetPoint(pt.point, pt.relativeTo, pt.relativePoint, pt.x, pt.y)
        end
    else
        Minimap:SetPoint("CENTER", MinimapCluster, "CENTER", 0, 0)
    end
    
    if originalMinimapScale then Minimap:SetScale(originalMinimapScale) end
    
    -- Restore Blizzard border visibility
    for _, frameName in ipairs(BLIZZARD_BORDER_FRAMES) do
        local frame = _G[frameName]
        if frame then
            frame:SetAlpha(1)
            frame:Show()
        end
    end
end

-- ============================================================================
-- BLIZZARD CLUSTER MANAGEMENT
-- ============================================================================

function MinimapFrame:HideBlizzardCluster()
    if MinimapCluster then
        MinimapCluster:ClearAllPoints()
        MinimapCluster:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10000, 10000)
        MinimapCluster:SetAlpha(0)
        -- CRITICAL: Disable mouse input to prevent click blocking
        -- Without this, DialogueUI's UIParent hide/show can cause MinimapCluster
        -- to capture mouse clicks even though it's positioned off-screen
        MinimapCluster:EnableMouse(false)
        -- Also hide it properly to prevent any residual interaction
        MinimapCluster:Hide()
    end
end

function MinimapFrame:ShowBlizzardCluster()
    if MinimapCluster then
        MinimapCluster:Show()
        MinimapCluster:ClearAllPoints()
        MinimapCluster:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
        MinimapCluster:SetAlpha(1)
        MinimapCluster:EnableMouse(true)
    end
end

-- ============================================================================
-- APPLY SETTINGS
-- ============================================================================

function MinimapFrame:ApplyShape()
    if not Minimap then return end
    
    local general = GetSettings()
    local isSquare = general and general:GetMinimapSetting("squareShape") or false
    local isRotating = GetCVar("rotateMinimap") == "1"
    
    if isSquare and not isRotating then
        Minimap:SetMaskTexture("Interface\\BUTTONS\\WHITE8X8")
    else
        Minimap:SetMaskTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    end
    
    self:UpdateBorder()
end

function MinimapFrame:ApplyScale()
    if not containerFrame then return end
    local general = GetSettings()
    local scale = general and general:GetMinimapSetting("scale") or 1.0
    
    -- If Layout is managing, apply scale to wrapper (container is 1.0 relative to wrapper)
    if layoutWrapper then
        layoutWrapper.frame:SetScale(scale)
    else
        containerFrame:SetScale(scale)
    end
end

function MinimapFrame:ApplyCoords()
    if not coordsFrame then return end
    local general = GetSettings()
    local showCoords = general and general:GetMinimapSetting("showCoords") or false
    coordsFrame:SetShown(showCoords)
    -- Position is handled separately - only set once at creation or when dragged
end

function MinimapFrame:ApplyAllSettings()
    self:ApplyShape()
    self:ApplyScale()
    self:RestorePosition()
    self:UpdateBorder()
    self:ApplyCoords()
    self:ApplyDecorationVisibility()
    
    TweaksUI:PrintDebug("MinimapFrame: All settings applied")
end

-- ============================================================================
-- ENABLE / DISABLE
-- ============================================================================

function MinimapFrame:Enable()
    if enabled then return end
    
    TweaksUI:PrintDebug("MinimapFrame: Enabling")
    
    -- Create our frames
    self:CreateContainer()
    self:CreateBorder()
    self:CreateCoordsDisplay()
    
    -- Hide Blizzard cluster
    self:HideBlizzardCluster()
    
    -- CRITICAL: Hook MinimapCluster to prevent it from being shown by other addons
    -- DialogueUI hides/shows UIParent which can cause MinimapCluster to reappear
    -- and start blocking mouse input even though it's supposed to be hidden
    if MinimapCluster and not MinimapCluster._tweaksUIOnShowHooked then
        MinimapCluster:HookScript("OnShow", function(self)
            if enabled then
                -- Force re-hide MinimapCluster
                self:Hide()
                self:EnableMouse(false)
                TweaksUI:PrintDebug("MinimapFrame: Re-hid MinimapCluster (something tried to show it)")
            end
        end)
        MinimapCluster._tweaksUIOnShowHooked = true
    end
    
    -- Reparent minimap and decorations
    self:ReparentMinimap()
    
    -- Apply all settings
    self:ApplyAllSettings()
    
    -- Register for Edit Mode hide/show (legacy, may not be used anymore)
    if TweaksUI.EditMode then
        TweaksUI.EditMode:RegisterReskinHandler("MinimapFrame",
            function()  -- Hide during Edit Mode
                if containerFrame then containerFrame:Hide() end
                self:RestoreMinimap()
                self:ShowBlizzardCluster()
            end,
            function()  -- Show after Edit Mode
                self:HideBlizzardCluster()
                self:ReparentMinimap()
                if containerFrame then containerFrame:Show() end
                self:ApplyAllSettings()
            end
        )
    end
    
    containerFrame:Show()
    enabled = true
    TweaksUI:PrintDebug("MinimapFrame: Custom Minimap enabled")
    
    -- Register with Layout system (delayed to ensure Layout is ready)
    C_Timer.After(0.5, function()
        self:RegisterWithLayout()
    end)
end

function MinimapFrame:Disable()
    if not enabled then return end
    
    if TweaksUI.EditMode then
        TweaksUI.EditMode:UnregisterReskinHandler("MinimapFrame")
    end
    
    self:RestoreMinimap()
    self:ShowBlizzardCluster()
    
    if containerFrame then containerFrame:Hide() end
    
    enabled = false
    TweaksUI:PrintDebug("MinimapFrame: Custom Minimap disabled")
end

function MinimapFrame:IsEnabled()
    return enabled
end

function MinimapFrame:Refresh()
    if not enabled then return end
    self:ApplyAllSettings()
end

-- ============================================================================
-- AFK MODE HANDLING
-- ============================================================================

local afkFrame = nil
local wasAFK = false

-- ============================================================================
-- AFK HANDLING (DEPRECATED - Disabled due to unwanted minimap hiding)
-- These functions remain for reference but are no longer called
-- ============================================================================

function MinimapFrame:SetupAFKHandling()
    -- DISABLED: This was causing the minimap to hide when going AFK
    -- If AFK mode is re-enabled in the future, this can be uncommented
    --[[
    if afkFrame then return end
    
    afkFrame = CreateFrame("Frame")
    afkFrame:RegisterEvent("PLAYER_FLAGS_CHANGED")
    afkFrame:RegisterEvent("PLAYER_LEAVING_WORLD")
    afkFrame:SetScript("OnEvent", function(self, event, unit)
        if event == "PLAYER_FLAGS_CHANGED" and unit == "player" then
            MinimapFrame:HandleAFKChange()
        elseif event == "PLAYER_LEAVING_WORLD" then
            -- Ensure we restore if logging out while AFK
            if wasAFK then
                MinimapFrame:ShowFromAFK()
            end
        end
    end)
    --]]
end

function MinimapFrame:HandleAFKChange()
    -- DISABLED
    --[[
    if not enabled then return end
    
    local isAFK = UnitIsAFK("player")
    
    if isAFK and not wasAFK then
        -- Just went AFK - hide everything
        self:HideForAFK()
        wasAFK = true
    elseif not isAFK and wasAFK then
        -- Returned from AFK - restore
        self:ShowFromAFK()
        wasAFK = false
    end
    --]]
end

function MinimapFrame:HideForAFK()
    -- DISABLED
    --[[
    if not containerFrame then return end
    
    TweaksUI:PrintDebug("MinimapFrame: Hiding for AFK mode")
    containerFrame:Hide()
    --]]
end

function MinimapFrame:ShowFromAFK()
    -- DISABLED
    --[[
    if not containerFrame or not enabled then return end
    
    TweaksUI:PrintDebug("MinimapFrame: Restoring from AFK mode")
    containerFrame:Show()
    
    -- Re-apply visibility settings (some decorations may need to stay hidden)
    self:ApplyDecorationVisibility()
    self:ApplyCoords()
    --]]
end

-- ============================================================================
-- LAYOUT INTEGRATION
-- ============================================================================

function MinimapFrame:RegisterWithLayout()
    if not containerFrame then return end
    if layoutWrapper then return end  -- Already registered
    
    local Layout = TweaksUI.Layout
    local TUIFrame = TweaksUI.TUIFrame
    
    if not Layout or not TUIFrame then
        TweaksUI:PrintDebug("MinimapFrame: Layout or TUIFrame not available")
        return
    end
    
    -- Get current size and scale
    local baseWidth = containerFrame:GetWidth() or 140
    local baseHeight = containerFrame:GetHeight() or 140
    local scale = containerFrame:GetScale() or 1.0
    
    -- Get current position from container (as fallback default)
    local point, _, relPoint, x, y = containerFrame:GetPoint(1)
    point = point or "TOPRIGHT"
    x = x or -10
    y = y or -10
    
    -- Check for Layout saved position
    local layoutSettings = Layout:GetSettings()
    local savedPos = layoutSettings and layoutSettings.elements and layoutSettings.elements["minimap"]
    
    -- Create TUIFrame wrapper with BASE size (same as container)
    layoutWrapper = TUIFrame:New("minimap", {
        width = baseWidth,
        height = baseHeight,
        name = "Minimap",
    })
    
    if not layoutWrapper then
        return
    end
    
    -- Apply same scale to wrapper so overlay matches visual size
    layoutWrapper.frame:SetScale(scale)
    
    -- Position wrapper using Layout saved position or current container position
    if savedPos and savedPos.x ~= nil and savedPos.y ~= nil then
        layoutWrapper:LoadSaveData(savedPos)
    else
        layoutWrapper:SetPosition(point, UIParent, point, x, y)
    end
    
    -- Parent the container to the wrapper (container scale stays at current value)
    -- DON'T reset container scale - let it keep its own scale relative to wrapper
    containerFrame:SetParent(layoutWrapper.frame)
    containerFrame:ClearAllPoints()
    containerFrame:SetPoint("CENTER", layoutWrapper.frame, "CENTER", 0, 0)
    containerFrame:SetScale(1.0)  -- Container is now 1.0 relative to scaled wrapper
    
    -- Disable container's drag handlers - Layout handles positioning now
    containerFrame:SetScript("OnDragStart", nil)
    containerFrame:SetScript("OnDragStop", nil)
    containerFrame:SetScript("OnMouseDown", nil)
    containerFrame:SetScript("OnMouseUp", nil)
    
    -- Register with Layout module
    Layout:RegisterElement("minimap", {
        name = "Minimap",
        category = Layout.CATEGORIES.MINIMAP,
        tuiFrame = layoutWrapper,
        defaultPosition = { point = point, x = x, y = y },
        onPositionChanged = function(id, saveData)
            -- Save position to our settings
            if saveData then
                local general = GetSettings()
                if general then
                    general:SetMinimapSetting("customPosition", {
                        point = saveData.point or "TOPRIGHT",
                        relPoint = saveData.point or "TOPRIGHT",
                        x = saveData.x,
                        y = saveData.y,
                    })
                end
            end
        end,
    })
end

-- ============================================================================
-- INITIALIZE
-- ============================================================================

function MinimapFrame:Initialize()
    if initialized then return end
    initialized = true
    
    -- AFK Mode handling disabled - was causing minimap to hide unexpectedly
    -- self:SetupAFKHandling()
    
    TweaksUI:PrintDebug("MinimapFrame: Initialized")
end

function MinimapFrame:GetContainer()
    return containerFrame
end

return MinimapFrame
