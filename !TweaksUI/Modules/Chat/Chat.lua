-- TweaksUI Chat Module
-- Custom chat frame system with full control over positioning and appearance

local ADDON_NAME, TweaksUI = ...

-- Create the module
local Chat = TweaksUI.ModuleManager:NewModule(
    TweaksUI.MODULE_IDS.CHAT,
    "Chat",
    "Custom chat frame with full control over appearance and positioning"
)

-- Default settings
local DEFAULTS = {
    -- General
    showButtonBar = true,
    buttonSize = 22,
    buttonSpacing = 2,
    fadeButtons = true,
    fadeAlpha = 0.3,
    
    -- Window Fade (entire chat frame fades when inactive)
    enableWindowFade = false,
    windowFadeDelay = 10,  -- seconds before window starts fading
    windowFadeAlpha = 0.25,  -- minimum alpha when faded
    
    -- Button bar position
    buttonBarPosition = "LEFT",  -- LEFT, RIGHT, TOP, INDEPENDENT
    buttonBarVertical = true,    -- For INDEPENDENT: true = vertical, false = horizontal
    buttonBarX = nil,
    buttonBarY = nil,
    
    -- Edit box position
    editBoxPosition = "BOTTOM",  -- TOP, BOTTOM, INDEPENDENT
    editBoxX = nil,
    editBoxY = nil,
    editBoxWidth = nil,
    
    -- Frame appearance
    backgroundColor = { r = 0, g = 0, b = 0, a = 0.5 },
    borderColor = { r = 0.3, g = 0.3, b = 0.3, a = 1 },
    showBackground = true,
    showBorder = false,
    
    -- Frame position/size (saved per character)
    frameX = nil,
    frameY = nil,
    frameWidth = 430,
    frameHeight = 200,
    
    -- Text appearance
    fontSize = 14,
    fontOutline = "",  -- "", OUTLINE, THICKOUTLINE
    
    -- Copy
    copyLines = 500,
    
    -- Layout
    headerHeight = 26,
    
    -- Custom tabs (user-created filtered tabs)
    customTabs = {},  -- Array of {name = "TabName", channels = {"SAY", "GUILD", etc}, color = {r,g,b}}
    
    -- ========== NEW FEATURES ==========
    
    -- Message Fading
    enableFading = true,
    fadeTime = 120,  -- seconds before messages start fading
    fadeDuration = 10,  -- seconds for fade animation
    
    -- URL/Link Handling
    enableURLs = true,
    urlColor = { r = 0.5, g = 0.7, b = 1.0 },
    
    -- Class Colors
    enableClassColors = true,
    
    -- Short Channel Names
    enableShortChannels = true,
    
    -- Sticky Chat
    enableStickyTab = true,  -- Remember which tab was selected
    enableStickyChat = true,  -- Remember chat channel type
    lastChatType = "SAY",
    lastSelectedTab = 1,  -- Remember which tab was selected
    
    -- Click Actions
    enableAltInvite = true,
    enableShiftCopy = true,
    
    -- Mention Alerts
    enableMentionAlerts = true,
    mentionSound = true,
    mentionSoundSource = "blizzard",  -- "blizzard" or "custom" (LSM)
    mentionSoundId = "TELL_MESSAGE",  -- Blizzard SOUNDKIT key
    mentionSoundLSM = "None",  -- LSM sound name
    mentionFlash = true,
    mentionWords = {},  -- Additional words to trigger alerts
    
    -- Guild Message Alerts
    enableGuildAlerts = false,
    guildAlertSound = true,
    guildAlertSoundSource = "blizzard",  -- "blizzard" or "custom" (LSM)
    guildAlertSoundId = "TELL_MESSAGE",
    guildAlertSoundLSM = "None",  -- LSM sound name
    guildAlertFlash = false,
    
    -- Chat Filters
    filterSpam = false,
    filterProfanity = false,
    filterGoldSellers = true,
    customFilters = {},  -- User-defined filter patterns
    
    -- Edit Box Customization
    editBoxFont = nil,  -- nil = use default
    editBoxFontSize = 14,
    editBoxBackground = true,
    editBoxBackgroundColor = { r = 0, g = 0, b = 0, a = 0.7 },
    autoHideEditBox = false,  -- Hide edit box until typing
    
    -- Whisper Tabs/Windows
    enableWhisperTabs = false,
    whisperTabTimeout = 300,  -- seconds before whisper tab auto-closes
    whisperWindowMode = "tab",  -- "tab" = in main chat, "separate" = separate frame
    hideWhispersInGeneral = false,  -- Hide whispers from General tab when whisper tabs enabled
    whisperFrameX = nil,
    whisperFrameY = nil,
    whisperFrameWidth = 350,
    whisperFrameHeight = 200,
    
    -- Social Features
    showFriendStatus = true,
    showGuildStatus = true,
    
    -- Voice Tab
    hideVoiceTab = false,
}

-- ============================================================================
-- MODULE STATE
-- ============================================================================

local customChatFrame = nil  -- Our custom chat frame
local whisperFrame = nil  -- Separate whisper frame (if enabled)
local whisperTabs = {}  -- { [senderName] = { tab = tabButton, messageFrame = frame, lastActivity = time } }
local mainChatWhisperTabs = {}  -- Track whisper tabs in main chat: { [shortName] = frameIndex }
local blizzardHidden = false  -- Track if we've hidden Blizzard's frames
local hiddenFrame = nil  -- Hidden parent for Blizzard frames
local copyFrame = nil
local chatHub = nil
local chatPanels = {}
local customTabFrames = {}  -- Message frames for custom filtered tabs
local moduleDisabledByAddon = false  -- Track if disabled due to another chat addon
-- LibEditMode is now managed by TweaksUI.EditMode (Core/EditModeManager.lua)

-- Panel constants (matching CMT style)
local HUB_WIDTH = 220
local PANEL_WIDTH = 400
local BUTTON_HEIGHT = 28
local BUTTON_SPACING = 4

-- Dark backdrop (CMT style)
local darkBackdrop = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
}

-- ============================================================================
-- HIDDEN FRAME FOR BLIZZARD UI
-- ============================================================================

local function CreateHiddenFrame()
    if not hiddenFrame then
        hiddenFrame = CreateFrame("Frame")
        hiddenFrame:Hide()
    end
    return hiddenFrame
end

-- ============================================================================
-- CHAT ADDON DETECTION
-- ============================================================================

-- Helper to check if an addon will load (exists and is enabled)
local function WillAddonLoad(addonName)
    if not C_AddOns.DoesAddOnExist(addonName) then
        return false
    end
    local loadable, reason = C_AddOns.IsAddOnLoadable(addonName)
    return loadable
end

-- Chat addon detection functions
-- Only includes addons that may work with Midnight 12.0
-- Note: No chat addons are fully confirmed for Midnight yet
function Chat:IsChattynatorInstalled() return C_AddOns.DoesAddOnExist("Chattynator") end
function Chat:IsChattynatorEnabled() return WillAddonLoad("Chattynator") end
function Chat:IsPratInstalled() return C_AddOns.DoesAddOnExist("Prat-3.0") end
function Chat:IsPratEnabled() return WillAddonLoad("Prat-3.0") end

function Chat:IsChatAddonActive() 
    return self:IsChattynatorEnabled() or self:IsPratEnabled()
end

-- Get list of active chat addons (for warning message)
function Chat:GetActiveChatAddons()
    local addons = {}
    if self:IsChattynatorEnabled() then table.insert(addons, "Chattynator") end
    if self:IsPratEnabled() then table.insert(addons, "Prat-3.0") end
    return addons
end

-- Modify hub button when chat addon is detected (grey out and disable)
local function ModifyMainHubButton()
    if not Chat:IsChatAddonActive() then return end
    local hubPanel = _G["TweaksUI_HubPanel"]
    if not hubPanel or not hubPanel.moduleRows then return end
    local ourRow = hubPanel.moduleRows[TweaksUI.MODULE_IDS.CHAT] or hubPanel.moduleRows["Chat"]
    if not ourRow then return end
    
    -- Hide the checkbox
    if ourRow.checkbox then ourRow.checkbox:Hide() end
    
    -- Grey out and disable the button
    if ourRow.button then
        ourRow.button:Disable()
        ourRow.button:SetAlpha(0.5)
        
        -- Add tooltip explaining why it's disabled
        ourRow.button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Chat Module Disabled", 1, 0.82, 0)
            local addons = Chat:GetActiveChatAddons()
            local addonList = table.concat(addons, ", ")
            GameTooltip:AddLine(addonList .. " detected.", 1, 0.5, 0.5, true)
            GameTooltip:AddLine("Disable the conflicting addon and reload to use TweaksUI Chat.", 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end)
        ourRow.button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end
end

local function HookSettingsToggle()
    if not TweaksUI.Settings then return end
    if TweaksUI.Settings.Toggle then
        local originalToggle = TweaksUI.Settings.Toggle
        TweaksUI.Settings.Toggle = function(self, ...)
            originalToggle(self, ...)
            if Chat:IsChatAddonActive() then C_Timer.After(0.01, ModifyMainHubButton) end
        end
    end
    if TweaksUI.Settings.Show then
        local originalShow = TweaksUI.Settings.Show
        TweaksUI.Settings.Show = function(self, ...)
            originalShow(self, ...)
            if Chat:IsChatAddonActive() then C_Timer.After(0.01, ModifyMainHubButton) end
        end
    end
end

-- ============================================================================
-- MODULE LIFECYCLE
-- ============================================================================

function Chat:OnInitialize()
    TweaksUI:PrintDebug("Chat module initializing...")
    
    local settings = self:GetSettings()
    for k, v in pairs(DEFAULTS) do
        if settings[k] == nil then
            settings[k] = type(v) == "table" and CopyTable(v) or v
        end
    end
    
    -- Check for other chat addons
    if self:IsChatAddonActive() then
        moduleDisabledByAddon = true
        local addons = self:GetActiveChatAddons()
        local addonList = table.concat(addons, " and ")
        C_Timer.After(3, function()
            TweaksUI:Print("|cffff9900Chat module:|r " .. addonList .. " detected.")
            TweaksUI:Print("TweaksUI Chat is disabled to avoid conflicts.")
        end)
        C_Timer.After(0.1, HookSettingsToggle)
    end
    
    -- Hook ChatConfigFrame to protect against Blizzard bug with chat frames > 10
    -- Blizzard's code assumes all chat frame tabs exist, but FCF_OpenNewWindow creates
    -- frames beyond NUM_CHAT_WINDOWS (10) without proper tab setup
    if ChatConfigFrame then
        -- Hook when ChatConfigFrame loads
        ChatConfigFrame:HookScript("OnShow", function()
            self:ProtectChatConfig()
        end)
    else
        -- ChatConfigFrame is load-on-demand, hook when it loads
        local hookFrame = CreateFrame("Frame")
        hookFrame:RegisterEvent("ADDON_LOADED")
        hookFrame:SetScript("OnEvent", function(self, event, addonName)
            if addonName == "Blizzard_ChatFrame" or addonName == "Blizzard_ChatFrameUI" then
                if ChatConfigFrame then
                    ChatConfigFrame:HookScript("OnShow", function()
                        Chat:ProtectChatConfig()
                    end)
                end
                self:UnregisterEvent("ADDON_LOADED")
            end
        end)
    end
end

-- Protect ChatConfigFrame from nil chatTab errors
function Chat:ProtectChatConfig()
    -- Ensure all chat frames up to 20 have valid tabs (or create dummy ones)
    for i = 11, 20 do
        local chatFrame = _G["ChatFrame" .. i]
        local chatTab = _G["ChatFrame" .. i .. "Tab"]
        
        -- If chat frame exists but tab doesn't, the frame was created improperly
        -- Close it to prevent ChatConfig errors
        if chatFrame and not chatTab then
            if FCF_Close then
                pcall(function() FCF_Close(chatFrame) end)
            end
        end
    end
end

function Chat:OnEnable()
    TweaksUI:PrintDebug("Chat module enabling...")
    
    -- Skip enabling if another chat addon is active
    if moduleDisabledByAddon then
        TweaksUI:PrintDebug("Chat module skipped - another chat addon is active")
        return
    end
    
    -- Debug: Show loaded mention words
    local settings = self:GetSettings()
    if settings.mentionWords and #settings.mentionWords > 0 then
        TweaksUI:PrintDebug("Chat: Loaded mention words: " .. table.concat(settings.mentionWords, ", "))
    else
        TweaksUI:PrintDebug("Chat: No custom mention words loaded")
    end
    TweaksUI:PrintDebug("Chat: enableMentionAlerts = " .. tostring(settings.enableMentionAlerts))
    
    -- Create our custom chat frame (or show existing one)
    if customChatFrame then
        -- Frame already exists, just show it
        customChatFrame:Show()
    else
        -- Create new frame
        self:CreateCustomChatFrame()
    end
    
    -- Hide Blizzard's chat frames
    self:HideBlizzardChat()
    
    -- Create copy frame (but don't show)
    self:CreateCopyFrame()
    
    -- Hook message system to capture messages
    -- Delay slightly to ensure chat frames are fully initialized
    C_Timer.After(0.2, function()
        self:HookMessageSystem()
    end)
    
    -- Apply voice tab visibility setting
    C_Timer.After(0.3, function()
        self:ApplyVoiceTabVisibility()
    end)
    
    -- Initialize new features
    C_Timer.After(0.4, function()
        self:ApplyAllNewFeatures()
    end)
    
    -- Register with Layout system (delayed to ensure Layout is ready)
    C_Timer.After(0.5, function()
        self:RegisterWithLayout()
    end)
    
    -- Delayed refresh to pick up global media settings
    C_Timer.After(0.6, function()
        if TweaksUI.Media and TweaksUI.Media:IsUsingGlobalFont() then
            self:ApplyFontSettings()
        end
    end)
    
    -- Register for chat window change events
    self:RegisterChatEvents()
    
    TweaksUI:PrintDebug("Chat module enabled - Custom chat frame active")
end

function Chat:OnDisable()
    TweaksUI:PrintDebug("Chat module disabling...")
    
    -- Show Blizzard's chat frames again
    self:ShowBlizzardChat()
    
    -- Unregister chat events
    self:UnregisterChatEvents()
    
    -- Hide our custom frame
    if customChatFrame then
        customChatFrame:Hide()
    end
    
    -- Hide copy frame
    if copyFrame then
        copyFrame:Hide()
    end
    
    -- Close any open panels
    if chatHub then chatHub:Hide() end
    for _, panel in pairs(chatPanels) do
        if panel and panel.Hide then panel:Hide() end
    end
    
    TweaksUI:Print("Chat module disabled")
end

-- Handle profile changes
function Chat:OnProfileChanged(profileName)
    TweaksUI:PrintDebug("Chat OnProfileChanged:", profileName)
    
    -- If module is enabled, refresh the frame layout
    if self.enabled and customChatFrame then
        local settings = self:GetSettings()
        if settings then
            -- Update frame appearance
            self:UpdateFrameAppearance()
            -- Update button bar
            self:UpdateButtonBar()
            -- Re-apply positions if we have them stored
            if settings.frameX and settings.frameY then
                customChatFrame:ClearAllPoints()
                customChatFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", settings.frameX, settings.frameY)
            end
            if settings.frameWidth then
                customChatFrame:SetWidth(settings.frameWidth)
            end
            if settings.frameHeight then
                customChatFrame:SetHeight(settings.frameHeight)
            end
        end
    end
end

-- ============================================================================
-- HIDE/SHOW BLIZZARD CHAT
-- ============================================================================

function Chat:HideBlizzardChat()
    if blizzardHidden then return end
    
    local hidden = CreateHiddenFrame()
    
    -- Disable FloatingChatFrameManager (like Chattynator does)
    if FloatingChatFrameManager then
        FloatingChatFrameManager:UnregisterAllEvents()
    end
    
    -- Hide all Blizzard chat frames visually but keep them functional
    for i = 1, NUM_CHAT_WINDOWS do
        local chatFrame = _G["ChatFrame" .. i]
        local chatTab = _G["ChatFrame" .. i .. "Tab"]
        
        if chatFrame then
            -- Store original values for restoration
            if not chatFrame._tweaksOriginalAlpha then
                chatFrame._tweaksOriginalAlpha = chatFrame:GetAlpha()
            end
            
            -- Make invisible but keep processing messages
            -- Using a tiny alpha instead of 0 to avoid optimization issues
            chatFrame:SetAlpha(0.001)
            chatFrame:EnableMouse(false)
            
            -- Don't move off-screen - that can cause issues with message processing
            -- Instead, just make sure it's behind our frame
            chatFrame:SetFrameStrata("BACKGROUND")
            
            -- Hide the Edit Mode selection frame
            if chatFrame.Selection then
                chatFrame.Selection:SetParent(hidden)
            end
            
            -- Hide backgrounds and chrome
            if chatFrame.Background then
                chatFrame.Background:Hide()
            end
            if chatFrame.buttonFrame then
                chatFrame.buttonFrame:Hide()
            end
        end
        
        if chatTab then
            chatTab:SetParent(hidden)
        end
    end
    
    -- Hide the dock manager
    if GeneralDockManager then
        GeneralDockManager:SetParent(hidden)
    end
    
    -- Hide chat buttons
    local buttonsToHide = {
        "ChatFrameMenuButton",
        "ChatFrameChannelButton", 
        "ChatFrameToggleVoiceDeafenButton",
        "ChatFrameToggleVoiceMuteButton",
        "QuickJoinToastButton",
    }
    
    for _, buttonName in ipairs(buttonsToHide) do
        local button = _G[buttonName]
        if button then
            button:SetParent(hidden)
        end
    end
    
    -- Edit Mode hooks are now handled by centralized EditModeManager
    -- Our OnEditModeEnter callback will hide chat frames from Edit Mode
    
    blizzardHidden = true
end

function Chat:HideChatFromEditMode()
    local hidden = CreateHiddenFrame()
    
    -- Hide all chat frame selections in Edit Mode
    for i = 1, NUM_CHAT_WINDOWS do
        local chatFrame = _G["ChatFrame" .. i]
        if chatFrame then
            -- Hide the selection overlay
            if chatFrame.Selection and type(chatFrame.Selection) == "table" and chatFrame.Selection.Hide then
                chatFrame.Selection:Hide()
                chatFrame.Selection:SetParent(hidden)
            end
        end
    end
    
    -- Try to hide from EditModeManagerFrame's active systems
    if EditModeManagerFrame and EditModeManagerFrame.registeredSystemFrames then
        for _, frame in ipairs(EditModeManagerFrame.registeredSystemFrames) do
            if frame and type(frame) == "table" and frame.system == Enum.EditModeSystem.ChatFrame then
                if frame.Selection and type(frame.Selection) == "table" and frame.Selection.Hide then
                    frame.Selection:Hide()
                    frame.Selection:SetParent(hidden)
                end
                if frame.Hide then
                    frame:Hide()
                end
            end
        end
    end
end

function Chat:ShowBlizzardChat()
    if not blizzardHidden then return end
    
    -- Restore Combat Log embedding first
    self:RestoreCombatLog()
    
    -- Re-enable FloatingChatFrameManager
    if FloatingChatFrameManager then
        FloatingChatFrameManager:RegisterEvent("UPDATE_CHAT_WINDOWS")
        FloatingChatFrameManager:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS")
    end
    
    -- Restore all Blizzard chat frames
    for i = 1, NUM_CHAT_WINDOWS do
        local chatFrame = _G["ChatFrame" .. i]
        local chatTab = _G["ChatFrame" .. i .. "Tab"]
        
        if chatFrame then
            -- Restore alpha
            local origAlpha = chatFrame._tweaksOriginalAlpha or 1
            chatFrame:SetAlpha(origAlpha)
            chatFrame:EnableMouse(true)
            chatFrame:SetFrameStrata("LOW")
            chatFrame._tweaksOriginalAlpha = nil
            
            -- Show backgrounds and chrome
            if chatFrame.Background then
                chatFrame.Background:Show()
            end
            if chatFrame.buttonFrame then
                chatFrame.buttonFrame:Show()
            end
        end
        
        if chatTab then
            chatTab:SetParent(GeneralDockManager or UIParent)
        end
    end
    
    -- Restore dock manager
    if GeneralDockManager then
        GeneralDockManager:SetParent(UIParent)
    end
    
    -- Restore chat buttons
    local buttonsToRestore = {
        "ChatFrameMenuButton",
        "ChatFrameChannelButton",
        "ChatFrameToggleVoiceDeafenButton",
        "ChatFrameToggleVoiceMuteButton",
        "QuickJoinToastButton",
    }
    
    for _, buttonName in ipairs(buttonsToRestore) do
        local button = _G[buttonName]
        if button then
            button:SetParent(UIParent)
        end
    end
    
    -- Force Blizzard to update chat positions
    if FCF_DockUpdate then
        FCF_DockUpdate()
    end
    
    blizzardHidden = false
end

-- ============================================================================
-- CUSTOM CHAT FRAME
-- ============================================================================

-- Layout constants
local TAB_HEIGHT = 22
local EDIT_BOX_HEIGHT = 32

function Chat:CreateCustomChatFrame()
    if customChatFrame then return customChatFrame end
    
    local settings = self:GetSettings()
    
    -- Debug: print current settings
    TweaksUI:PrintDebug("Chat loading position - frameX: " .. tostring(settings.frameX) .. " frameY: " .. tostring(settings.frameY))
    TweaksUI:PrintDebug("Chat loading position - framePoint: " .. tostring(settings.framePoint) .. " frameRelativePoint: " .. tostring(settings.frameRelativePoint))
    
    -- Main container frame
    local frame = CreateFrame("Frame", "TweaksUIChatFrame", UIParent, "BackdropTemplate")
    frame:SetSize(settings.frameWidth or 430, settings.frameHeight or 200)
    
    -- Restore position - use saved point/relativePoint if available
    local point = settings.framePoint or "BOTTOMLEFT"
    local relativePoint = settings.frameRelativePoint or "BOTTOMLEFT"
    local x = settings.frameX or 20
    local y = settings.frameY or 20
    
    frame:SetPoint(point, UIParent, relativePoint, x, y)
    
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(250, 120, 800, 600)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    
    -- Background frame (will be positioned by button bar logic)
    local bgFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    bgFrame:SetAllPoints()
    
    if settings.showBackground then
        bgFrame:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = settings.showBorder and "Interface\\Tooltips\\UI-Tooltip-Border" or nil,
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        local bg = settings.backgroundColor
        bgFrame:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)
        if settings.showBorder then
            local border = settings.borderColor
            bgFrame:SetBackdropBorderColor(border.r, border.g, border.b, border.a)
        end
    end
    frame.bgFrame = bgFrame
    
    -- Create channel tabs at the top
    self:CreateChannelTabs(frame)
    
    -- Scrolling message frame for chat text (will be positioned by button bar logic)
    local messageFrame = CreateFrame("ScrollingMessageFrame", "TweaksUIChatMessages", frame)
    messageFrame:SetPoint("TOPLEFT", 5, -TAB_HEIGHT - 2)
    messageFrame:SetPoint("BOTTOMRIGHT", -5, EDIT_BOX_HEIGHT + 2)
    messageFrame:SetFading(true)
    messageFrame:SetFadeDuration(3)
    messageFrame:SetTimeVisible(120)
    messageFrame:SetMaxLines(2000)
    messageFrame:SetFontObject(ChatFontNormal)
    messageFrame:SetJustifyH("LEFT")
    messageFrame:SetHyperlinksEnabled(true)
    
    -- Custom hyperlink click handler
    messageFrame:SetScript("OnHyperlinkClick", function(self, link, text, button)
        local linkType, linkData = link:match("^([^:]+):(.+)")
        
        if linkType == "player" then
            local name = linkData:match("([^:]+)")
            local settings = Chat:GetSettings()
            
            -- Alt-click to invite
            if settings.enableAltInvite and IsAltKeyDown() then
                C_PartyInfo.InviteUnit(name)
                return
            end
            
            -- Shift-click to copy/insert name
            if settings.enableShiftCopy and IsShiftKeyDown() then
                local editBox = ChatFrame1EditBox
                if editBox:IsShown() then
                    editBox:Insert(name)
                else
                    Chat:ShowCopyNamePopup(name)
                end
                return
            end
            
            -- Regular left click - start whisper
            if button == "LeftButton" then
                ChatFrame_SendTell(name, ChatFrame1)
                return
            end
            
            -- Right click - show player menu
            if button == "RightButton" then
                -- Use default handler for right click menu
                SetItemRef(link, text, button, self)
                return
            end
        elseif linkType == "url" then
            -- Custom URL link
            local url = linkData
            Chat:HandleURLClick(url)
            return
        end
        
        -- Default handler for other link types (items, spells, etc.)
        SetItemRef(link, text, button, self)
    end)
    
    messageFrame:SetScript("OnHyperlinkEnter", function(self, link, text)
        local linkType = link:match("^([^:]+)")
        if linkType == "url" then
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            GameTooltip:SetText("Click to copy URL")
            GameTooltip:Show()
        else
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            GameTooltip:SetHyperlink(link)
            GameTooltip:Show()
        end
    end)
    messageFrame:SetScript("OnHyperlinkLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Mouse wheel scrolling
    messageFrame:EnableMouseWheel(true)
    messageFrame:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            if IsShiftKeyDown() then
                self:ScrollToTop()
            else
                self:ScrollUp()
                self:ScrollUp()
                self:ScrollUp()
            end
        else
            if IsShiftKeyDown() then
                self:ScrollToBottom()
            else
                self:ScrollDown()
                self:ScrollDown()
                self:ScrollDown()
            end
        end
    end)
    
    frame.messageFrame = messageFrame
    
    -- Create button bar (this will also adjust message frame position)
    self:CreateButtonBar(frame)
    
    -- Move the Blizzard edit box to our frame
    self:AttachEditBox(frame)
    
    -- Resize handle
    local resizeButton = CreateFrame("Button", nil, frame)
    resizeButton:SetSize(16, 16)
    resizeButton:SetPoint("BOTTOMRIGHT", -2, 2)
    resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeButton:SetScript("OnMouseDown", function()
        frame:StartSizing("BOTTOMRIGHT")
    end)
    resizeButton:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        self:SaveFramePosition()
        -- Re-adjust button bar on resize
        if frame.buttonBar then
            self:PositionButtonBar(frame.buttonBar, frame)
        end
    end)
    
    frame.resizeButton = resizeButton
    
    -- Register with Edit Mode via LibEditMode
    self:RegisterWithEditMode(frame)
    
    frame:Show()
    customChatFrame = frame
    
    -- ========== WINDOW FADE SYSTEM ==========
    -- Fades the entire chat window when mouse is not over it
    local fadeTimer = nil
    local isFaded = false
    
    local function IsEditBoxFocused()
        local editBox = ChatFrame1EditBox
        return editBox and editBox:HasFocus()
    end
    
    local function FadeWindowIn()
        if fadeTimer then
            fadeTimer:Cancel()
            fadeTimer = nil
        end
        isFaded = false
        UIFrameFadeIn(frame, 0.2, frame:GetAlpha(), 1)
    end
    
    local function FadeWindowOut()
        local settings = Chat:GetSettings()
        if not settings.enableWindowFade then return end
        -- Don't fade if user is typing
        if IsEditBoxFocused() then
            return
        end
        isFaded = true
        UIFrameFadeOut(frame, 0.5, frame:GetAlpha(), settings.windowFadeAlpha)
    end
    
    local function StartFadeTimer()
        local settings = Chat:GetSettings()
        if not settings.enableWindowFade then return end
        -- Don't start timer if user is typing
        if IsEditBoxFocused() then return end
        
        if fadeTimer then
            fadeTimer:Cancel()
        end
        fadeTimer = C_Timer.NewTimer(settings.windowFadeDelay, FadeWindowOut)
    end
    
    -- Track mouse over the entire frame area
    frame:HookScript("OnEnter", function()
        local settings = Chat:GetSettings()
        if settings.enableWindowFade then
            FadeWindowIn()
        end
    end)
    
    frame:HookScript("OnLeave", function()
        local settings = Chat:GetSettings()
        if settings.enableWindowFade and not frame:IsMouseOver() then
            StartFadeTimer()
        end
    end)
    
    -- Also track mouse on child frames (tabs, message area, etc.)
    local updateThrottle = 0
    frame:SetScript("OnUpdate", function(self, elapsed)
        updateThrottle = updateThrottle + elapsed
        if updateThrottle < 0.1 then return end
        updateThrottle = 0
        
        local settings = Chat:GetSettings()
        if not settings.enableWindowFade then 
            if isFaded then
                FadeWindowIn()
            end
            return 
        end
        
        -- Don't fade if user is typing
        if IsEditBoxFocused() then
            if isFaded then
                FadeWindowIn()
            end
            return
        end
        
        local isOver = self:IsMouseOver()
        if isOver and isFaded then
            FadeWindowIn()
        elseif not isOver and not isFaded and not fadeTimer then
            StartFadeTimer()
        end
    end)
    
    -- Store fade functions for external use
    frame.FadeWindowIn = FadeWindowIn
    frame.FadeWindowOut = FadeWindowOut
    frame.StartFadeTimer = StartFadeTimer
    -- ========================================
    
    -- Apply saved settings after frame is ready
    C_Timer.After(0.1, function()
        Chat:ApplyBackgroundSettings()
        Chat:ApplyFontSettings()
        Chat:ApplyChannelColors()
        Chat:ApplyTabColors()
        Chat:ApplyFadingSettings()
        
        -- Start fade timer if window fade is enabled
        local settings = Chat:GetSettings()
        if settings.enableWindowFade then
            StartFadeTimer()
        end
    end)
    
    return frame
end

-- ============================================================================
-- CHANNEL TABS
-- ============================================================================

function Chat:CreateChannelTabs(parentFrame)
    local settings = self:GetSettings()
    
    -- Tab container - will be repositioned when button bar is created
    local tabBar = CreateFrame("Frame", nil, parentFrame)
    tabBar:SetPoint("TOPLEFT", 3, 0)   -- Small padding from frame edge
    tabBar:SetPoint("TOPRIGHT", -3, 0) -- Small padding from frame edge
    tabBar:SetHeight(TAB_HEIGHT)
    
    -- Dark background for tab bar
    local tabBarBg = tabBar:CreateTexture(nil, "BACKGROUND")
    tabBarBg:SetAllPoints()
    tabBarBg:SetColorTexture(0.1, 0.1, 0.1, 0.9)
    tabBar.bg = tabBarBg
    
    -- Store tabs for later reference
    tabBar.tabs = {}
    parentFrame.tabBar = tabBar
    parentFrame.activeChatFrameIndex = 1
    
    -- Build tabs directly here (not via RefreshChannelTabs since customChatFrame isn't set yet)
    local xOffset = 5
    
    for i = 1, NUM_CHAT_WINDOWS do
        local chatFrame = _G["ChatFrame" .. i]
        local chatTab = _G["ChatFrame" .. i .. "Tab"]
        
        if chatFrame and chatTab then
            local tabName = chatTab:GetText()
            if not tabName or tabName == "" then
                tabName = "Chat " .. i
            end
            
            -- Show tab if: frame 1, OR tab visible, OR frame is shown/docked
            local shouldShow = (i == 1) or 
                               (chatTab:IsShown()) or 
                               (chatFrame.isDocked) or
                               (i == 2)  -- Always show Combat Log
            
            if shouldShow then
                local tab = self:CreateSingleTab(tabBar, i, tabName, xOffset)
                table.insert(tabBar.tabs, tab)
                xOffset = xOffset + tab:GetWidth() + 2
            end
        end
    end
    
    -- Restore last selected tab or default to first tab
    local lastTab = (settings.enableStickyTab ~= false and settings.lastSelectedTab) or 1
    -- Delay slightly to ensure custom tabs are also created
    C_Timer.After(0.5, function()
        self:SelectChatFrame(lastTab)
    end)
end

function Chat:RefreshChannelTabs()
    if not customChatFrame or not customChatFrame.tabBar then 
        return 
    end
    
    local tabBar = customChatFrame.tabBar
    local settings = self:GetSettings()
    
    -- Clear existing tabs
    for _, tab in ipairs(tabBar.tabs or {}) do
        tab:Hide()
        tab:SetParent(nil)
    end
    tabBar.tabs = {}
    
    -- Clear custom tab message frames
    for _, frame in pairs(customTabFrames) do
        frame:Hide()
        frame:SetParent(nil)
    end
    customTabFrames = {}
    
    local xOffset = 5
    
    -- Check all chat frames (1-10) for visible/active windows
    for i = 1, NUM_CHAT_WINDOWS do
        local chatFrame = _G["ChatFrame" .. i]
        local chatTab = _G["ChatFrame" .. i .. "Tab"]
        
        if chatFrame and chatTab then
            -- Get tab name - use Blizzard's tab text or default
            local tabName = chatTab:GetText()
            if not tabName or tabName == "" then
                tabName = "Chat " .. i
            end
            
            -- Check if this is a voice chat tab that should be hidden
            local isVoiceTab = self:IsVoiceChatTab(chatFrame, tabName)
            if isVoiceTab and settings.hideVoiceTab then
                -- Skip this tab
            else
                -- Determine if this chat frame should have a tab
                -- Show if: it's frame 1, OR the tab is shown, OR the frame is docked, OR frame is visible
                local shouldShow = (i == 1) or 
                                   (chatTab:IsShown()) or 
                                   (chatFrame.isDocked) or
                                   (chatFrame:IsShown()) or
                                   (FCF_GetNumActiveChatFrames and i <= FCF_GetNumActiveChatFrames())
                
                -- Also check if this is a temporary window (whisper tabs)
                if not shouldShow and chatFrame.isTemporary then
                    shouldShow = true
                end
                
                -- Check if this is a tracked whisper tab
                for name, frameIndex in pairs(mainChatWhisperTabs) do
                    if frameIndex == i then
                        shouldShow = true
                        break
                    end
                end
                
                if shouldShow then
                    local tab = self:CreateSingleTab(tabBar, i, tabName, xOffset)
                    table.insert(tabBar.tabs, tab)
                    xOffset = xOffset + tab:GetWidth() + 2
                end
            end
        end
    end
    
    -- Add custom tabs
    settings.customTabs = settings.customTabs or {}
    for i, customTabData in ipairs(settings.customTabs) do
        local customIndex = 100 + i  -- Use 100+ for custom tab indices
        local tab = self:CreateCustomTab(tabBar, customIndex, customTabData, xOffset)
        table.insert(tabBar.tabs, tab)
        xOffset = xOffset + tab:GetWidth() + 2
        
        -- Create message frame for this custom tab
        self:CreateCustomTabMessageFrame(customIndex, customTabData)
    end
    
    -- Update selection visual if current selection is still valid
    if customChatFrame.activeChatFrameIndex then
        self:UpdateTabVisuals(customChatFrame.activeChatFrameIndex)
    end
end

function Chat:IsVoiceChatTab(chatFrame, tabName)
    -- Check if this is a voice chat tab
    -- Voice chat tabs are typically temporary and have specific characteristics
    if not chatFrame then return false end
    
    -- Check by name - voice tabs often have "Voice" in the name or are community voice
    local lowerName = tabName and tabName:lower() or ""
    if lowerName:find("voice") then
        return true
    end
    
    -- Check if it's a temporary frame with voice chat type
    if chatFrame.isTemporary then
        local chatType = chatFrame.chatType
        if chatType and (chatType == "VOICE" or chatType == "COMMUNITIES_CHANNEL") then
            return true
        end
    end
    
    -- Check if it's registered for voice-related events
    if chatFrame.messageTypeList then
        for _, msgType in ipairs(chatFrame.messageTypeList) do
            if msgType == "VOICE_TEXT" or msgType == "COMMUNITIES_CHANNEL" then
                return true
            end
        end
    end
    
    return false
end

function Chat:ApplyVoiceTabVisibility()
    local settings = self:GetSettings()
    
    -- Find and hide/show any voice chat tabs in Blizzard's system
    for i = 3, NUM_CHAT_WINDOWS do  -- Start at 3 to skip General and Combat Log
        local chatFrame = _G["ChatFrame" .. i]
        local chatTab = _G["ChatFrame" .. i .. "Tab"]
        
        if chatFrame and chatTab then
            local tabName = chatTab:GetText() or ""
            if self:IsVoiceChatTab(chatFrame, tabName) then
                if settings.hideVoiceTab then
                    -- Close the voice chat frame
                    if FCF_Close then
                        FCF_Close(chatFrame)
                    end
                end
            end
        end
    end
end

function Chat:CreateCustomTab(tabBar, customIndex, customTabData, xOffset)
    local settings = self:GetSettings()
    
    local tab = CreateFrame("Button", "TweaksUIChatCustomTab" .. customIndex, tabBar)
    tab:SetHeight(TAB_HEIGHT - 4)
    tab:SetPoint("BOTTOMLEFT", xOffset, 2)
    
    -- Tab text
    local text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER", 0, 0)
    text:SetText(customTabData.name or "Custom")
    text:SetTextColor(0.9, 0.9, 0.9)
    tab.text = text
    
    local textWidth = text:GetStringWidth()
    tab:SetWidth(math.max(textWidth + 16, 50))
    
    -- Tab background with custom color
    local bgColor = customTabData.color or {r = 0.2, g = 0.3, b = 0.4}
    local bg = tab:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(bgColor.r or 0.2, bgColor.g or 0.3, bgColor.b or 0.4, 0.9)
    tab.bg = bg
    tab.customColor = bgColor
    
    -- Left edge accent
    local leftEdge = tab:CreateTexture(nil, "BORDER")
    leftEdge:SetPoint("TOPLEFT", 0, 0)
    leftEdge:SetPoint("BOTTOMLEFT", 0, 0)
    leftEdge:SetWidth(1)
    leftEdge:SetColorTexture(0.3, 0.3, 0.3, 1)
    tab.leftEdge = leftEdge
    
    -- Right edge accent
    local rightEdge = tab:CreateTexture(nil, "BORDER")
    rightEdge:SetPoint("TOPRIGHT", 0, 0)
    rightEdge:SetPoint("BOTTOMRIGHT", 0, 0)
    rightEdge:SetWidth(1)
    rightEdge:SetColorTexture(0.3, 0.3, 0.3, 1)
    tab.rightEdge = rightEdge
    
    -- Highlight on hover
    local highlight = tab:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.4, 0.4, 0.4, 0.3)
    
    -- Selected indicator (bottom line)
    local selected = tab:CreateTexture(nil, "ARTWORK")
    selected:SetPoint("BOTTOMLEFT", 1, 0)
    selected:SetPoint("BOTTOMRIGHT", -1, 0)
    selected:SetHeight(2)
    selected:SetColorTexture(0.9, 0.7, 0.0, 1)
    selected:Hide()
    tab.selected = selected
    
    -- Top highlight when selected
    local topHighlight = tab:CreateTexture(nil, "ARTWORK")
    topHighlight:SetPoint("TOPLEFT", 1, 0)
    topHighlight:SetPoint("TOPRIGHT", -1, 0)
    topHighlight:SetHeight(1)
    topHighlight:SetColorTexture(0.5, 0.5, 0.5, 0.5)
    topHighlight:Hide()
    tab.topHighlight = topHighlight
    
    -- Store references
    tab.chatFrameIndex = customIndex
    tab.isCustomTab = true
    tab.customTabData = customTabData
    tab.tabName = customTabData.name
    
    -- Click to select
    tab:SetScript("OnClick", function()
        self:SelectChatFrame(customIndex)
    end)
    
    -- Tooltip on hover
    tab:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(customTabData.name or "Custom Tab")
        local channels = table.concat(customTabData.channels or {}, ", ")
        GameTooltip:AddLine("Channels: " .. channels, 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    return tab
end

function Chat:CreateCustomTabMessageFrame(customIndex, customTabData)
    -- Create a ScrollingMessageFrame for this custom tab
    local msgFrame = CreateFrame("ScrollingMessageFrame", "TweaksUICustomTabMsgFrame" .. customIndex, customChatFrame)
    msgFrame:SetPoint("TOPLEFT", customChatFrame.messageFrame, "TOPLEFT")
    msgFrame:SetPoint("BOTTOMRIGHT", customChatFrame.messageFrame, "BOTTOMRIGHT")
    msgFrame:SetFont(customChatFrame.messageFrame:GetFont())
    msgFrame:SetJustifyH("LEFT")
    msgFrame:SetFading(true)
    msgFrame:SetFadeDuration(3)
    msgFrame:SetTimeVisible(120)
    msgFrame:SetMaxLines(500)
    msgFrame:SetHyperlinksEnabled(true)
    msgFrame:EnableMouseWheel(true)
    msgFrame:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            self:ScrollUp()
        else
            self:ScrollDown()
        end
    end)
    msgFrame:SetScript("OnHyperlinkClick", function(self, link, text, button)
        SetItemRef(link, text, button, self)
    end)
    msgFrame:Hide()
    
    msgFrame.customIndex = customIndex
    msgFrame.customTabData = customTabData
    msgFrame.channels = customTabData.channels or {}
    
    -- Build event to channel mapping for quick lookup
    msgFrame.eventFilter = {}
    for _, channelKey in ipairs(customTabData.channels) do
        for _, channelInfo in ipairs(CHANNEL_TYPES) do
            if channelInfo.key == channelKey then
                for _, event in ipairs(channelInfo.events) do
                    msgFrame.eventFilter[event] = true
                end
            end
        end
    end
    
    customTabFrames[customIndex] = msgFrame
end

function Chat:CreateSingleTab(tabBar, chatFrameIndex, tabName, xOffset)
    local settings = self:GetSettings()
    local chatFrame = _G["ChatFrame" .. chatFrameIndex]
    
    local tab = CreateFrame("Button", "TweaksUIChatTab" .. chatFrameIndex, tabBar)
    tab:SetHeight(TAB_HEIGHT - 4)
    tab:SetPoint("BOTTOMLEFT", xOffset, 2)
    
    -- Check if this is a temporary/whisper tab that can be closed
    -- Check both Blizzard's isTemporary flag AND our whisper tracking
    local isCloseable = false
    if chatFrame and chatFrame.isTemporary then
        isCloseable = true
    end
    -- Also check if it's in our whisper tabs tracking
    for name, frameIndex in pairs(mainChatWhisperTabs) do
        if frameIndex == chatFrameIndex then
            isCloseable = true
            break
        end
    end
    -- Don't allow closing General or Combat Log
    if chatFrameIndex <= 2 then
        isCloseable = false
    end
    
    -- Tab text
    local text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetText(tabName)
    text:SetTextColor(0.8, 0.8, 0.8)
    tab.text = text
    
    -- Size to fit text with padding (extra space for close button if needed)
    local textWidth = text:GetStringWidth()
    local tabWidth = math.max(textWidth + 16, 50)
    if isCloseable then
        tabWidth = tabWidth + 14  -- Extra space for close button
        text:SetPoint("LEFT", 5, 0)
    else
        text:SetPoint("CENTER", 0, 0)
    end
    tab:SetWidth(tabWidth)
    
    -- Tab background - rounded look via 9-slice or solid color
    local bg = tab:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
    tab.bg = bg
    
    -- Left edge accent
    local leftEdge = tab:CreateTexture(nil, "BORDER")
    leftEdge:SetPoint("TOPLEFT", 0, 0)
    leftEdge:SetPoint("BOTTOMLEFT", 0, 0)
    leftEdge:SetWidth(1)
    leftEdge:SetColorTexture(0.3, 0.3, 0.3, 1)
    tab.leftEdge = leftEdge
    
    -- Right edge accent
    local rightEdge = tab:CreateTexture(nil, "BORDER")
    rightEdge:SetPoint("TOPRIGHT", 0, 0)
    rightEdge:SetPoint("BOTTOMRIGHT", 0, 0)
    rightEdge:SetWidth(1)
    rightEdge:SetColorTexture(0.3, 0.3, 0.3, 1)
    tab.rightEdge = rightEdge
    
    -- Close button for temporary/whisper tabs
    if isCloseable then
        local closeBtn = CreateFrame("Button", nil, tab)
        closeBtn:SetSize(12, 12)
        closeBtn:SetPoint("RIGHT", -3, 0)
        closeBtn:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
        closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-StopButton")
        closeBtn:GetHighlightTexture():SetVertexColor(1, 0.3, 0.3)
        closeBtn:SetScript("OnClick", function(self, button)
            -- Remove from our tracking
            for name, frameIndex in pairs(mainChatWhisperTabs) do
                if frameIndex == chatFrameIndex then
                    mainChatWhisperTabs[name] = nil
                    break
                end
            end
            -- Close this chat frame
            if chatFrame and FCF_Close then
                FCF_Close(chatFrame)
                Chat:RefreshChannelTabs()
            end
        end)
        closeBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Close Tab")
            GameTooltip:Show()
        end)
        closeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        tab.closeBtn = closeBtn
    end
    
    -- Highlight on hover
    local highlight = tab:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.4, 0.4, 0.4, 0.3)
    
    -- Selected indicator (bottom line)
    local selected = tab:CreateTexture(nil, "ARTWORK")
    selected:SetPoint("BOTTOMLEFT", 1, 0)
    selected:SetPoint("BOTTOMRIGHT", -1, 0)
    selected:SetHeight(2)
    selected:SetColorTexture(0.9, 0.7, 0.0, 1)  -- Gold accent
    selected:Hide()
    tab.selected = selected
    
    -- Top highlight when selected
    local topHighlight = tab:CreateTexture(nil, "ARTWORK")
    topHighlight:SetPoint("TOPLEFT", 1, 0)
    topHighlight:SetPoint("TOPRIGHT", -1, 0)
    topHighlight:SetHeight(1)
    topHighlight:SetColorTexture(0.5, 0.5, 0.5, 0.5)
    topHighlight:Hide()
    tab.topHighlight = topHighlight
    
    -- Store references
    tab.chatFrameIndex = chatFrameIndex
    tab.chatFrame = chatFrame
    tab.tabName = tabName
    tab.isCloseable = isCloseable
    
    -- Register for both mouse buttons
    tab:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    -- Click handling - left to select, right for settings dialog
    tab:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            -- Show our tab settings dialog
            Chat:ShowTabSettingsDialog(chatFrameIndex)
        else
            -- Left click to select tab
            Chat:SelectChatFrame(chatFrameIndex)
        end
    end)
    
    -- Tooltip on hover
    tab:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(tabName)
        GameTooltip:AddLine("Left-click to switch", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Right-click for options", 0.7, 0.7, 0.7)
        if isCloseable then
            GameTooltip:AddLine("Click X to close", 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    -- Ensure tab is visible
    tab:Show()
    
    return tab
end

function Chat:UpdateTabVisuals(selectedIndex)
    if not customChatFrame or not customChatFrame.tabBar then return end
    
    customChatFrame.activeChatFrameIndex = selectedIndex
    local settings = self:GetSettings()
    local tabs = customChatFrame.tabBar.tabs
    
    -- Default colors
    local defaultUnsel = settings.defaultTabColor or {r = 0.15, g = 0.15, b = 0.15}
    local defaultSel = settings.selectedTabColor or {r = 0.25, g = 0.25, b = 0.25}
    
    for _, tab in ipairs(tabs) do
        local tabIndex = tab.chatFrameIndex
        local isSelected = (tabIndex == selectedIndex)
        local bgColor
        
        -- Check if this is a custom tab
        if tab.isCustomTab and tab.customColor then
            -- Use custom tab's own color
            local c = tab.customColor
            if isSelected then
                bgColor = {r = math.min(1, (c.r or 0.2) + 0.15), g = math.min(1, (c.g or 0.2) + 0.15), b = math.min(1, (c.b or 0.2) + 0.15)}
            else
                bgColor = c
            end
        else
            -- Blizzard tab - check for per-tab custom color
            local tabSetting = settings.tabSettings and settings.tabSettings[tabIndex]
            if tabSetting and tabSetting.useCustomColor and tabSetting.customColor then
                local c = tabSetting.customColor
                if type(c) == "table" then
                    if isSelected then
                        bgColor = {r = math.min(1, (c.r or 0.2) + 0.1), g = math.min(1, (c.g or 0.2) + 0.1), b = math.min(1, (c.b or 0.2) + 0.1)}
                    else
                        bgColor = c
                    end
                else
                    bgColor = isSelected and defaultSel or defaultUnsel
                end
            else
                bgColor = isSelected and defaultSel or defaultUnsel
            end
        end
        
        -- Apply colors
        if tab.bg then
            tab.bg:SetColorTexture(bgColor.r or 0.15, bgColor.g or 0.15, bgColor.b or 0.15, 0.95)
        end
        
        if isSelected then
            tab.selected:Show()
            tab.topHighlight:Show()
            tab.text:SetTextColor(1, 1, 1)
            tab.leftEdge:SetColorTexture(0.5, 0.5, 0.5, 1)
            tab.rightEdge:SetColorTexture(0.5, 0.5, 0.5, 1)
        else
            tab.selected:Hide()
            tab.topHighlight:Hide()
            tab.text:SetTextColor(0.7, 0.7, 0.7)
            tab.leftEdge:SetColorTexture(0.3, 0.3, 0.3, 1)
            tab.rightEdge:SetColorTexture(0.3, 0.3, 0.3, 1)
        end
    end
end

function Chat:SelectChatFrame(index)
    if not customChatFrame or not customChatFrame.tabBar then return end
    
    -- Update visual state of tabs
    self:UpdateTabVisuals(index)
    
    customChatFrame.activeChatFrameIndex = index
    
    -- Save the selected tab for persistence across reloads
    local settings = self:GetSettings()
    settings.lastSelectedTab = index
    
    -- Get the container for chat content
    local messageFrame = customChatFrame.messageFrame
    
    -- Hide all custom tab message frames first
    for _, frame in pairs(customTabFrames) do
        frame:Hide()
    end
    
    -- Check if this is a custom tab (index >= 100)
    if index >= 100 then
        -- Custom tab selected
        
        -- Hide the embedded combat log if it was showing
        self:HideEmbeddedCombatLog()
        
        -- Hide our main message frame
        if messageFrame then
            messageFrame:Hide()
        end
        
        -- Restore background opacity
        if customChatFrame.bgFrame then
            local bgColor = settings.bgColor
            if type(bgColor) ~= "table" then bgColor = {r = 0, g = 0, b = 0} end
            local alpha = settings.bgAlpha or 0.7
            customChatFrame.bgFrame:SetBackdropColor(bgColor.r or 0, bgColor.g or 0, bgColor.b or 0, alpha)
        end
        
        -- Show the custom tab's message frame
        local customMsgFrame = customTabFrames[index]
        if customMsgFrame then
            customMsgFrame:Show()
        end
        
        return
    end
    
    -- Combat Log (ChatFrame2) needs special handling - embed the actual frame
    if index == 2 then
        -- Hide our message frame
        if messageFrame then
            messageFrame:Hide()
        end
        
        -- Reduce background opacity for Combat Log visibility
        -- Combat Log uses Blizzard's frame which doesn't respect our background
        if customChatFrame.bgFrame then
            customChatFrame.bgFrame:SetBackdropColor(0, 0, 0, 0.5)  -- Semi-transparent for Combat Log
        end
        
        -- Embed ChatFrame2 (Combat Log) directly
        self:EmbedCombatLog(customChatFrame)
    else
        -- Restore background opacity for normal chat
        if customChatFrame.bgFrame then
            local bgColor = settings.bgColor
            if type(bgColor) ~= "table" then bgColor = {r = 0, g = 0, b = 0} end
            local alpha = settings.bgAlpha or 0.7
            customChatFrame.bgFrame:SetBackdropColor(bgColor.r or 0, bgColor.g or 0, bgColor.b or 0, alpha)
        end
        
        -- Show our message frame for non-combat-log tabs
        if messageFrame then
            messageFrame:Show()
        end
        
        -- Hide the embedded combat log if it was showing
        self:HideEmbeddedCombatLog()
        
        -- Clear our message frame and copy messages from the selected Blizzard chat frame
        if messageFrame then
            messageFrame:Clear()
            
            local chatFrame = _G["ChatFrame" .. index]
            if chatFrame and chatFrame.GetNumMessages then
                local numMessages = chatFrame:GetNumMessages()
                for i = 1, numMessages do
                    local text, r, g, b = chatFrame:GetMessageInfo(i)
                    if text then
                        messageFrame:AddMessage(text, r or 1, g or 1, b or 1)
                    end
                end
            end
            
            -- Scroll to bottom
            messageFrame:ScrollToBottom()
        end
    end
    
    -- Update the edit box to use this chat frame
    local editBox = ChatFrame1EditBox
    if editBox then
        editBox.chatFrame = _G["ChatFrame" .. index]
    end
end

function Chat:EmbedCombatLog(parentFrame)
    local chatFrame = ChatFrame2
    if not chatFrame then return end
    
    -- Store original parent if not already stored
    if not parentFrame._combatLogOriginalParent then
        parentFrame._combatLogOriginalParent = chatFrame:GetParent()
    end
    
    -- Get the content area (same as message frame position)
    local messageFrame = parentFrame.messageFrame
    if not messageFrame then return end
    
    -- Reparent ChatFrame2 to our frame
    chatFrame:SetParent(parentFrame)
    chatFrame:ClearAllPoints()
    
    -- Position it exactly where our message frame would be
    chatFrame:SetPoint("TOPLEFT", messageFrame, "TOPLEFT", 0, 0)
    chatFrame:SetPoint("BOTTOMRIGHT", messageFrame, "BOTTOMRIGHT", -15, 0)  -- -15 for scrollbar space
    
    -- Make visible
    chatFrame:SetAlpha(1)
    chatFrame:EnableMouse(true)
    chatFrame:Show()
    
    -- Hide background elements - like Chattynator does
    if ChatFrame2Background then ChatFrame2Background:Hide() end
    if ChatFrame2BottomRightTexture then ChatFrame2BottomRightTexture:Hide() end
    if ChatFrame2BottomLeftTexture then ChatFrame2BottomLeftTexture:Hide() end
    if ChatFrame2BottomTexture then ChatFrame2BottomTexture:Hide() end
    if ChatFrame2TopLeftTexture then ChatFrame2TopLeftTexture:Hide() end
    if ChatFrame2TopRightTexture then ChatFrame2TopRightTexture:Hide() end
    if ChatFrame2TopTexture then ChatFrame2TopTexture:Hide() end
    if ChatFrame2RightTexture then ChatFrame2RightTexture:Hide() end
    if ChatFrame2LeftTexture then ChatFrame2LeftTexture:Hide() end
    if ChatFrame2ResizeButton then ChatFrame2ResizeButton:Hide() end
    if ChatFrame2ButtonFrameLeftTexture then ChatFrame2ButtonFrameLeftTexture:Hide() end
    if ChatFrame2ButtonFrameBackground then ChatFrame2ButtonFrameBackground:Hide() end
    if ChatFrame2ButtonFrameRightTexture then ChatFrame2ButtonFrameRightTexture:Hide() end
    if ChatFrame2ButtonFrameUpButton then ChatFrame2ButtonFrameUpButton:Hide() end
    if ChatFrame2ButtonFrameDownButton then ChatFrame2ButtonFrameDownButton:Hide() end
    
    -- Also handle the CombatLogQuickButtonFrame_Custom if it exists
    if CombatLogQuickButtonFrame_Custom then
        CombatLogQuickButtonFrame_Custom:SetParent(chatFrame)
        CombatLogQuickButtonFrame_Custom:ClearAllPoints()
        CombatLogQuickButtonFrame_Custom:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 5, -TAB_HEIGHT)
        CombatLogQuickButtonFrame_Custom:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", -5, -TAB_HEIGHT)
    end
    
    parentFrame._combatLogEmbedded = true
end

function Chat:HideEmbeddedCombatLog()
    if not customChatFrame or not customChatFrame._combatLogEmbedded then return end
    
    local chatFrame = ChatFrame2
    if not chatFrame then return end
    
    -- Hide but keep parented to us (will show again when tab selected)
    chatFrame:Hide()
    
    -- Hide the quick button frame too
    if CombatLogQuickButtonFrame_Custom then
        CombatLogQuickButtonFrame_Custom:Hide()
    end
end

function Chat:RestoreCombatLog()
    if not customChatFrame or not customChatFrame._combatLogOriginalParent then return end
    
    local chatFrame = ChatFrame2
    if not chatFrame then return end
    
    -- Restore to original parent
    chatFrame:SetParent(customChatFrame._combatLogOriginalParent)
    chatFrame:ClearAllPoints()
    
    -- Show background elements again
    if ChatFrame2Background then ChatFrame2Background:Show() end
    if ChatFrame2ResizeButton then ChatFrame2ResizeButton:Show() end
    
    -- Let Blizzard reposition
    if CombatLogQuickButtonFrame_Custom then
        CombatLogQuickButtonFrame_Custom:SetParent(chatFrame)
    end
    
    customChatFrame._combatLogOriginalParent = nil
    customChatFrame._combatLogEmbedded = nil
end

function Chat:SelectTab(index)
    -- Redirect to SelectChatFrame for backwards compatibility
    self:SelectChatFrame(index)
end

function Chat:ApplyMessageFilter(filter)
    -- No longer used - we switch entire chat frames now
end

-- ============================================================================
-- EDIT MODE INTEGRATION
-- ============================================================================

function Chat:RegisterWithEditMode(frame)
    -- Use centralized EditModeManager
    if not TweaksUI.EditMode then return end
    
    local settings = self:GetSettings()
    
    -- Callback when position changes in Edit Mode
    local function OnPositionChanged(movedFrame, point, x, y)
        if point then
            settings.framePoint = point
            settings.frameX = x
            settings.frameY = y
            if movedFrame and movedFrame.GetWidth then
                settings.frameWidth = movedFrame:GetWidth()
                settings.frameHeight = movedFrame:GetHeight()
            end
            TweaksUI:PrintDebug("Chat position saved: " .. tostring(point) .. " " .. tostring(x) .. "," .. tostring(y))
        end
    end
    
    -- Register the frame with centralized manager
    TweaksUI.EditMode:RegisterFrame(frame, {
        name = "TweaksUI: Chat Frame",
        onPositionChanged = OnPositionChanged,
        default = {
            point = "BOTTOMLEFT",
            x = 20,
            y = 20,
        },
    })
    
    -- Register callbacks for Edit Mode enter/exit
    local chatModule = self
    TweaksUI.EditMode:RegisterCallback("enter", function()
        chatModule:OnEditModeEnter()
    end)
    
    TweaksUI.EditMode:RegisterCallback("exit", function()
        chatModule:OnEditModeExit()
    end)
end

function Chat:OnEditModeEnter()
    -- Hide Blizzard's chat frame selection in Edit Mode so user only sees ours
    self:HideChatFromEditMode()
    
    -- Show whisper frame if mode is separate so it can be positioned
    local settings = self:GetSettings()
    if settings.whisperWindowMode == "separate" then
        -- Create the frame if it doesn't exist
        if not whisperFrame then
            self:CreateWhisperFrame()
        end
        
        if whisperFrame then
            whisperFrame._wasHiddenBeforeEditMode = not whisperFrame:IsShown()
            whisperFrame:Show()
        end
    end
end

function Chat:OnEditModeExit()
    -- Hide whisper frame if it was hidden before Edit Mode
    if whisperFrame and whisperFrame._wasHiddenBeforeEditMode then
        -- Only hide if there are no active whisper tabs
        local hasActiveTabs = false
        for _ in pairs(whisperTabs) do
            hasActiveTabs = true
            break
        end
        if not hasActiveTabs then
            whisperFrame:Hide()
        end
        whisperFrame._wasHiddenBeforeEditMode = nil
    end
end

function Chat:AttachEditBox(parentFrame)
    local settings = self:GetSettings()
    local editBox = ChatFrame1EditBox
    
    if not editBox then return end
    
    -- Calculate button bar offset based on position
    local leftOffset = 5
    local rightOffset = -5
    
    if settings.buttonBarPosition == "LEFT" and settings.showButtonBar then
        local btnSize = settings.buttonSize or 22
        leftOffset = btnSize + 11
    elseif settings.buttonBarPosition == "RIGHT" and settings.showButtonBar then
        local btnSize = settings.buttonSize or 22
        rightOffset = -(btnSize + 11)
    end
    
    -- Store original width
    if not settings.editBoxWidth then
        settings.editBoxWidth = parentFrame:GetWidth() - leftOffset + rightOffset
    end
    
    editBox:ClearAllPoints()
    
    if settings.editBoxPosition == "TOP" then
        -- Position above the chat frame
        editBox:SetPoint("BOTTOMLEFT", parentFrame, "TOPLEFT", leftOffset, 5)
        editBox:SetPoint("BOTTOMRIGHT", parentFrame, "TOPRIGHT", rightOffset, 5)
    elseif settings.editBoxPosition == "INDEPENDENT" then
        editBox:SetMovable(true)
        editBox:EnableMouse(true)
        editBox:SetClampedToScreen(true)
        editBox:SetWidth(settings.editBoxWidth or 400)
        
        if settings.editBoxX and settings.editBoxY then
            editBox:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", settings.editBoxX, settings.editBoxY)
        else
            editBox:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 30)
        end
        
        -- Setup shift+drag
        editBox:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" and IsShiftKeyDown() then
                self:StartMoving()
                self._isMoving = true
            end
        end)
        
        editBox:SetScript("OnMouseUp", function(self, button)
            if self._isMoving then
                self:StopMovingOrSizing()
                self._isMoving = false
                settings.editBoxX = self:GetLeft()
                settings.editBoxY = self:GetBottom()
            end
        end)
    else  -- BOTTOM (default)
        -- Position at the bottom of the chat frame, inside the frame
        editBox:SetPoint("BOTTOMLEFT", parentFrame, "BOTTOMLEFT", leftOffset, 5)
        editBox:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", rightOffset, 5)
    end
    
    -- Auto-hide edit box when not typing (hooks always active, check setting dynamically)
    if not editBox._tweaksUIHooked then
        editBox._tweaksUIHooked = true
        
        local hideTimer = nil
        
        -- Function to show edit box temporarily
        local function ShowEditBoxTemporarily(duration)
            local settings = Chat:GetSettings()
            if not settings.autoHideEditBox then return end
            
            editBox:SetAlpha(1)
            
            -- Cancel existing timer
            if hideTimer then
                hideTimer:Cancel()
                hideTimer = nil
            end
            
            -- Set timer to hide again (unless focused)
            if duration and duration > 0 then
                hideTimer = C_Timer.NewTimer(duration, function()
                    local settings = Chat:GetSettings()
                    if settings.autoHideEditBox and not editBox:HasFocus() then
                        editBox:SetAlpha(0)
                    end
                    hideTimer = nil
                end)
            end
        end
        
        -- Store function for external access
        editBox.ShowEditBoxTemporarily = ShowEditBoxTemporarily
        
        -- Hook to show when focused
        editBox:HookScript("OnEditFocusGained", function(self)
            if hideTimer then
                hideTimer:Cancel()
                hideTimer = nil
            end
            self:SetAlpha(1)
        end)
        
        -- Hook to hide when focus lost (if setting enabled)
        editBox:HookScript("OnEditFocusLost", function(self)
            local settings = Chat:GetSettings()
            if settings.autoHideEditBox then
                self:SetAlpha(0)
            end
        end)
        
        -- Register for chat events to show edit box on new messages
        local eventFrame = CreateFrame("Frame")
        eventFrame:RegisterEvent("CHAT_MSG_WHISPER")
        eventFrame:RegisterEvent("CHAT_MSG_BN_WHISPER")
        eventFrame:RegisterEvent("CHAT_MSG_SAY")
        eventFrame:RegisterEvent("CHAT_MSG_YELL")
        eventFrame:RegisterEvent("CHAT_MSG_PARTY")
        eventFrame:RegisterEvent("CHAT_MSG_PARTY_LEADER")
        eventFrame:RegisterEvent("CHAT_MSG_RAID")
        eventFrame:RegisterEvent("CHAT_MSG_RAID_LEADER")
        eventFrame:RegisterEvent("CHAT_MSG_RAID_WARNING")
        eventFrame:RegisterEvent("CHAT_MSG_INSTANCE_CHAT")
        eventFrame:RegisterEvent("CHAT_MSG_INSTANCE_CHAT_LEADER")
        eventFrame:RegisterEvent("CHAT_MSG_GUILD")
        eventFrame:RegisterEvent("CHAT_MSG_OFFICER")
        eventFrame:RegisterEvent("CHAT_MSG_CHANNEL")
        eventFrame:SetScript("OnEvent", function(self, event, ...)
            local settings = Chat:GetSettings()
            if not settings.autoHideEditBox then return end
            
            -- Show for longer on whispers
            if event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER" then
                ShowEditBoxTemporarily(8)  -- 8 seconds for whispers
            else
                ShowEditBoxTemporarily(5)  -- 5 seconds for other messages
            end
        end)
    end
    
    -- Apply initial state based on setting
    if settings.autoHideEditBox and not editBox:HasFocus() then
        editBox:SetAlpha(0)
    else
        editBox:SetAlpha(1)
    end
end

function Chat:CreateButtonBar(parentFrame)
    local settings = self:GetSettings()
    
    if not settings.showButtonBar then return end
    
    local buttonBar = CreateFrame("Frame", "TweaksUIChatButtonBar", parentFrame)
    buttonBar:SetMovable(true)
    buttonBar:SetClampedToScreen(true)
    buttonBar:EnableMouse(true)  -- Enable mouse from the start
    
    -- Optional background for button bar
    local barBg = buttonBar:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints()
    barBg:SetColorTexture(0.1, 0.1, 0.1, 0.5)
    buttonBar.bg = barBg
    
    local buttons = {}
    local buttonConfigs = {
        { icon = "Interface\\ChatFrame\\UI-ChatIcon-Chat-Up", tooltip = "Chat Menu", onClick = function() self:OpenChatMenu() end },
        { icon = "Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon", tooltip = "Social", onClick = function() ToggleFriendsFrame(1) end },
        { icon = "Interface\\GossipFrame\\ChatBubbleGossipIcon", tooltip = "Channels", onClick = function() ToggleChannelFrame() end },
        { icon = "Interface\\Buttons\\UI-GuildButton-PublicNote-Up", tooltip = "Copy Chat", onClick = function() self:ShowCopyFrame() end },
        { icon = "Interface\\PaperDollInfoFrame\\Character-Plus", tooltip = "New Tab", onClick = function() self:ShowCreateCustomTabDialog() end },
        { icon = "Interface\\GossipFrame\\BinderGossipIcon", tooltip = "Settings", onClick = function() self:ToggleChatHub() end },
    }
    
    for i, config in ipairs(buttonConfigs) do
        local btn = CreateFrame("Button", nil, buttonBar)
        btn.config = config
        btn.index = i
        
        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetTexture(config.icon)
        btn.icon = tex
        
        btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        
        -- Only fire onClick if NOT shift-dragging
        btn:SetScript("OnClick", function(self, button)
            if not IsShiftKeyDown() then
                config.onClick()
            end
        end)
        
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(config.tooltip)
            if settings.buttonBarPosition == "INDEPENDENT" then
                GameTooltip:AddLine("Shift+Drag to move button bar", 0.7, 0.7, 0.7)
            end
            GameTooltip:Show()
            if settings.fadeButtons then
                buttonBar:SetAlpha(1)
            end
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
            if settings.fadeButtons and not parentFrame:IsMouseOver() then
                buttonBar:SetAlpha(settings.fadeAlpha)
            end
        end)
        
        -- Register buttons for drag and pass to parent bar
        btn:RegisterForDrag("LeftButton")
        btn:SetScript("OnDragStart", function(self)
            if IsShiftKeyDown() and settings.buttonBarPosition == "INDEPENDENT" then
                buttonBar:StartMoving()
            end
        end)
        btn:SetScript("OnDragStop", function(self)
            buttonBar:StopMovingOrSizing()
            if settings.buttonBarPosition == "INDEPENDENT" then
                settings.buttonBarX = buttonBar:GetLeft()
                settings.buttonBarY = buttonBar:GetBottom()
            end
        end)
        
        buttons[i] = btn
    end
    
    buttonBar.buttons = buttons
    parentFrame.buttonBar = buttonBar
    
    -- Position and layout the button bar
    self:PositionButtonBar(buttonBar, parentFrame)
    
    -- Fade behavior
    if settings.fadeButtons then
        buttonBar:SetAlpha(settings.fadeAlpha)
        parentFrame:HookScript("OnEnter", function() buttonBar:SetAlpha(1) end)
        parentFrame:HookScript("OnLeave", function() 
            if not buttonBar:IsMouseOver() then
                buttonBar:SetAlpha(settings.fadeAlpha)
            end
        end)
    end
end

function Chat:PositionButtonBar(buttonBar, parentFrame)
    local settings = self:GetSettings()
    local position = settings.buttonBarPosition or "LEFT"
    local btnSize = settings.buttonSize or 22
    local btnSpacing = settings.buttonSpacing or 2
    local numButtons = #buttonBar.buttons
    
    buttonBar:ClearAllPoints()
    
    -- Determine if vertical or horizontal layout
    local isVertical = (position == "LEFT" or position == "RIGHT")
    if position == "INDEPENDENT" then
        isVertical = settings.buttonBarVertical  -- User choice for independent
    end
    
    -- Calculate bar size based on orientation
    local barWidth, barHeight
    if isVertical then
        barWidth = btnSize + 6
        barHeight = (btnSize * numButtons) + (btnSpacing * (numButtons - 1)) + 6
    else
        barWidth = (btnSize * numButtons) + (btnSpacing * (numButtons - 1)) + 6
        barHeight = btnSize + 6
    end
    
    buttonBar:SetSize(barWidth, barHeight)
    
    -- Position buttons within the bar
    for i, btn in ipairs(buttonBar.buttons) do
        btn:SetSize(btnSize, btnSize)
        btn:ClearAllPoints()
        
        if isVertical then
            btn:SetPoint("TOP", buttonBar, "TOP", 0, -3 - ((i-1) * (btnSize + btnSpacing)))
        else
            btn:SetPoint("LEFT", buttonBar, "LEFT", 3 + ((i-1) * (btnSize + btnSpacing)), 0)
        end
    end
    
    -- Position the bar itself based on setting
    if position == "LEFT" then
        buttonBar:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 0, -TAB_HEIGHT)
        -- Adjust message frame to account for button bar
        self:AdjustMessageFrameForButtonBar(parentFrame, "LEFT", barWidth)
        
    elseif position == "RIGHT" then
        buttonBar:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", 0, -TAB_HEIGHT)
        self:AdjustMessageFrameForButtonBar(parentFrame, "RIGHT", barWidth)
        
    elseif position == "TOP" then
        -- Horizontal bar to the right of tabs, shifted slightly left from edge
        buttonBar:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", -5, -2)
        self:AdjustMessageFrameForButtonBar(parentFrame, "TOP", barWidth)
        
    elseif position == "INDEPENDENT" then
        -- Free-floating, draggable
        if settings.buttonBarX and settings.buttonBarY then
            buttonBar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", settings.buttonBarX, settings.buttonBarY)
        else
            buttonBar:SetPoint("LEFT", parentFrame, "RIGHT", 5, 0)
        end
        
        -- Enable dragging with shift
        buttonBar:EnableMouse(true)
        buttonBar:RegisterForDrag("LeftButton")
        buttonBar:SetScript("OnDragStart", function(self)
            if IsShiftKeyDown() then
                self:StartMoving()
            end
        end)
        buttonBar:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            settings.buttonBarX = self:GetLeft()
            settings.buttonBarY = self:GetBottom()
        end)
        
        self:AdjustMessageFrameForButtonBar(parentFrame, "INDEPENDENT", 0)
    end
end

function Chat:AdjustMessageFrameForButtonBar(parentFrame, position, barWidth)
    local settings = self:GetSettings()
    local messageFrame = parentFrame.messageFrame
    local bgFrame = parentFrame.bgFrame
    local tabBar = parentFrame.tabBar
    
    if not messageFrame then return end
    
    messageFrame:ClearAllPoints()
    
    local editBoxOffset = (settings.editBoxPosition == "BOTTOM") and EDIT_BOX_HEIGHT + 2 or 5
    
    if position == "LEFT" then
        -- Button bar on left - offset message frame and tabs
        messageFrame:SetPoint("TOPLEFT", barWidth + 5, -TAB_HEIGHT - 2)
        messageFrame:SetPoint("BOTTOMRIGHT", -5, editBoxOffset)
        if bgFrame then
            bgFrame:ClearAllPoints()
            bgFrame:SetPoint("TOPLEFT", barWidth, 0)
            bgFrame:SetPoint("BOTTOMRIGHT", 0, 0)
        end
        if tabBar then
            tabBar:ClearAllPoints()
            tabBar:SetPoint("TOPLEFT", barWidth + 3, 0)  -- 3px padding from button bar edge
            tabBar:SetPoint("TOPRIGHT", -3, 0)           -- 3px padding from right edge
            tabBar:SetHeight(TAB_HEIGHT)
        end
    elseif position == "RIGHT" then
        -- Button bar on right - offset message frame
        messageFrame:SetPoint("TOPLEFT", 5, -TAB_HEIGHT - 2)
        messageFrame:SetPoint("BOTTOMRIGHT", -barWidth - 5, editBoxOffset)
        if bgFrame then
            bgFrame:ClearAllPoints()
            bgFrame:SetPoint("TOPLEFT", 0, 0)
            bgFrame:SetPoint("BOTTOMRIGHT", -barWidth, 0)
        end
        if tabBar then
            tabBar:ClearAllPoints()
            tabBar:SetPoint("TOPLEFT", 3, 0)              -- 3px padding from left edge
            tabBar:SetPoint("TOPRIGHT", -barWidth - 3, 0) -- 3px padding from button bar edge
            tabBar:SetHeight(TAB_HEIGHT)
        end
    else
        -- TOP or INDEPENDENT - no offset needed for message frame
        messageFrame:SetPoint("TOPLEFT", 5, -TAB_HEIGHT - 2)
        messageFrame:SetPoint("BOTTOMRIGHT", -5, editBoxOffset)
        if bgFrame then
            bgFrame:ClearAllPoints()
            bgFrame:SetPoint("TOPLEFT", 0, 0)
            bgFrame:SetPoint("BOTTOMRIGHT", 0, 0)
        end
        if tabBar then
            tabBar:ClearAllPoints()
            tabBar:SetPoint("TOPLEFT", 3, 0)   -- 3px padding from left edge
            tabBar:SetPoint("TOPRIGHT", -3, 0) -- 3px padding from right edge
            tabBar:SetHeight(TAB_HEIGHT)
        end
    end
end

function Chat:SaveFramePosition()
    local settings = self:GetSettings()
    if customChatFrame then
        -- Get the current anchor point
        local point, relativeTo, relativePoint, x, y = customChatFrame:GetPoint(1)
        
        settings.framePoint = point
        settings.frameRelativePoint = relativePoint
        settings.frameX = x
        settings.frameY = y
        settings.frameWidth = customChatFrame:GetWidth()
        settings.frameHeight = customChatFrame:GetHeight()
    end
end

-- ============================================================================
-- MESSAGE SYSTEM HOOKS
-- ============================================================================

-- Helper function to format message with timestamp
function Chat:FormatMessageWithTimestamp(text, sender, event)
    local settings = self:GetSettings()
    
    -- Check if text is a valid string (not a secret value)
    if not text or type(text) ~= "string" then return text end
    
    -- Apply new features first (before timestamp)
    text = self:ApplyMessageFeatures(text, sender, event)
    
    -- Check again after features applied
    if not text or type(text) ~= "string" then return text end
    
    if not settings.showTimestamps then
        return text
    end
    
    -- Check if message already has a timestamp (from Blizzard)
    -- Blizzard timestamps look like |cffABCDEF[HH:MM]|r or just [HH:MM]
    -- Use pcall in case text is somehow still problematic
    local hasTimestamp = false
    pcall(function()
        hasTimestamp = text:match("^|cff%x%x%x%x%x%x%[%d") or text:match("^%[%d")
    end)
    if hasTimestamp then
        -- Already has a timestamp, don't add another
        return text
    end
    
    local format = settings.timestampFormat or "[%H:%M] "
    local timestamp
    
    -- Handle milliseconds specially since Lua's date() doesn't support it
    if format:find("%.%d%d%d") or format:find("MS") then
        -- Get milliseconds from GetTime()
        local ms = math.floor((GetTime() % 1) * 1000)
        local baseFormat = format:gsub("%.%d%d%d", ""):gsub("MS", "")
        timestamp = date(baseFormat)
        -- Insert milliseconds
        if format:find("MS") then
            timestamp = timestamp:gsub("]", "." .. string.format("%03d", ms) .. "]")
            timestamp = timestamp:gsub("(%d%d:%d%d:%d%d)(%s)", "%1." .. string.format("%03d", ms) .. "%2")
        else
            timestamp = timestamp:gsub("]", "." .. string.format("%03d", ms) .. "]")
        end
        -- Handle no-bracket formats
        if not timestamp:find("%]") then
            timestamp = timestamp .. "." .. string.format("%03d", ms) .. " "
        end
    else
        timestamp = date(format)
    end
    
    -- Get timestamp color
    local tsColor = settings.timestampColor
    local colorHex = "888888"
    if type(tsColor) == "table" and tsColor.r then
        local r = math.floor((tsColor.r or 0.5) * 255)
        local g = math.floor((tsColor.g or 0.5) * 255)
        local b = math.floor((tsColor.b or 0.5) * 255)
        colorHex = string.format("%02x%02x%02x", r, g, b)
    end
    
    return "|cff" .. colorHex .. timestamp .. "|r" .. text
end

-- Apply all message formatting features
function Chat:ApplyMessageFeatures(text, sender, event)
    -- Check if text is a valid string (not a secret value)
    if not text or type(text) ~= "string" then return text end
    
    local settings = self:GetSettings()
    
    -- Apply short channel names
    text = self:ShortenChannelName(text)
    
    -- Apply URL formatting
    text = self:FormatURLs(text)
    
    -- Apply class colors to names in text
    if sender and type(sender) == "string" and settings.enableClassColors then
        text = self:ColorPlayerName(sender, text)
    end
    
    -- Check for mentions and alert
    if sender and sender ~= UnitName("player") then
        if self:CheckForMention(text) then
            self:TriggerMentionAlert()
        end
    end
    
    -- Check for guild message alerts
    if event == "CHAT_MSG_GUILD" and sender and sender ~= UnitName("player") then
        self:TriggerGuildAlert()
    end
    
    return text
end

-- Hook a specific chat frame's AddMessage
function Chat:HookChatFrameMessages(frameIndex)
    self._hookedFrames = self._hookedFrames or {}
    
    -- Don't hook the same frame twice
    if self._hookedFrames[frameIndex] then return end
    
    local chatFrame = _G["ChatFrame" .. frameIndex]
    if chatFrame and chatFrame.AddMessage then
        local chatModule = self
        local i = frameIndex  -- Capture for closure
        
        hooksecurefunc(chatFrame, "AddMessage", function(frame, text, r, g, b, ...)
            if customChatFrame and customChatFrame.messageFrame then
                if customChatFrame.activeChatFrameIndex == i then
                    local formattedText = chatModule:FormatMessageWithTimestamp(text)
                    customChatFrame.messageFrame:AddMessage(formattedText, r or 1, g or 1, b or 1, ...)
                    customChatFrame.messageFrame:ScrollToBottom()
                end
            end
        end)
        
        self._hookedFrames[frameIndex] = true
        TweaksUI:PrintDebug("Chat: Hooked ChatFrame" .. frameIndex)
    else
        TweaksUI:PrintDebug("Chat: ChatFrame" .. frameIndex .. " not ready")
    end
end

function Chat:HookMessageSystem()
    if self._messagesHooked then return end
    self._messagesHooked = true
    
    local chatModule = self
    
    TweaksUI:PrintDebug("Chat: Hooking message system...")
    
    -- Track which frames we've hooked
    self._hookedFrames = self._hookedFrames or {}
    
    -- Hook all chat frames' AddMessage to capture messages
    -- This uses hooksecurefunc which fires AFTER the original function
    for i = 1, NUM_CHAT_WINDOWS do
        self:HookChatFrameMessages(i)
    end
    
    -- Also hook ChatFrame_MessageEventHandler as a backup
    -- This is the main function that processes all chat messages
    if ChatFrame_MessageEventHandler then
        hooksecurefunc("ChatFrame_MessageEventHandler", function(frame, event, ...)
            -- Only process if this is ChatFrame1 and we're viewing tab 1
            if frame == ChatFrame1 and customChatFrame and customChatFrame.activeChatFrameIndex == 1 then
                -- The AddMessage hook should catch this, but this is a backup
            end
        end)
        TweaksUI:PrintDebug("Chat: Hooked ChatFrame_MessageEventHandler")
    end
    
    -- Special handling for Combat Log (ChatFrame2)
    local combatLog = ChatFrame2
    if combatLog then
        if combatLog.AddHistoryLine then
            hooksecurefunc(combatLog, "AddHistoryLine", function(frame, text, r, g, b, ...)
                if customChatFrame and customChatFrame.messageFrame then
                    if customChatFrame.activeChatFrameIndex == 2 then
                        local formattedText = chatModule:FormatMessageWithTimestamp(text)
                        customChatFrame.messageFrame:AddMessage(formattedText, r or 1, g or 1, b or 1, ...)
                        customChatFrame.messageFrame:ScrollToBottom()
                    end
                end
            end)
        end
    end
    
    -- Copy existing messages from ChatFrame1 initially
    if ChatFrame1 and ChatFrame1.GetNumMessages then
        local numMessages = ChatFrame1:GetNumMessages()
        for i = 1, numMessages do
            local text, r, g, b = ChatFrame1:GetMessageInfo(i)
            if text and customChatFrame and customChatFrame.messageFrame then
                -- Don't add timestamps to historical messages
                customChatFrame.messageFrame:AddMessage(text, r or 1, g or 1, b or 1)
            end
        end
        -- Scroll to bottom after loading history
        if customChatFrame and customChatFrame.messageFrame then
            customChatFrame.messageFrame:ScrollToBottom()
        end
    end
    
    -- Register our own frame for chat events as ultimate fallback
    self:RegisterDirectChatEvents()
end

function Chat:RegisterDirectChatEvents()
    if self._directEventsRegistered then return end
    self._directEventsRegistered = true
    
    local chatEventFrame = CreateFrame("Frame")
    local chatModule = self
    
    -- Register for all chat message events
    local chatEvents = {
        "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
        "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM",
        "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
        "CHAT_MSG_RAID_WARNING", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
        "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
        "CHAT_MSG_CHANNEL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE",
        "CHAT_MSG_SYSTEM", "CHAT_MSG_LOOT", "CHAT_MSG_MONEY",
        "CHAT_MSG_SKILL", "CHAT_MSG_COMBAT_XP_GAIN", "CHAT_MSG_COMBAT_HONOR_GAIN",
    }
    
    for _, event in ipairs(chatEvents) do
        chatEventFrame:RegisterEvent(event)
    end
    
    chatEventFrame:SetScript("OnEvent", function(frame, event, message, sender, ...)
        if not customChatFrame then return end
        
        -- Check for mentions on incoming messages (not our own)
        local playerName = UnitName("player")
        
        -- Try to get sender name safely - secret values will cause pcall to fail
        -- We need a VALID string senderShort to do comparison, not a secret value
        local senderShort = nil
        local senderIsUsable = false
        if sender then
            local success, result = pcall(function()
                -- This will fail if sender is a secret value
                local short = Ambiguate(sender, "short")
                -- Also try to use it to make sure it's not secret
                local _ = short .. ""
                return short
            end)
            if success and result then
                senderShort = result
                senderIsUsable = true
            end
        end
        
        -- Check if message is usable (not a secret value)
        local messageIsUsable = false
        if message then
            local success = pcall(function()
                local _ = message .. ""
            end)
            messageIsUsable = success
        end
        
        if messageIsUsable and senderIsUsable and senderShort ~= playerName then
            -- Check if this is a chat type we want to monitor for mentions
            local mentionEvents = {
                CHAT_MSG_SAY = true,
                CHAT_MSG_YELL = true,
                CHAT_MSG_WHISPER = true,
                CHAT_MSG_BN_WHISPER = true,
                CHAT_MSG_PARTY = true,
                CHAT_MSG_PARTY_LEADER = true,
                CHAT_MSG_RAID = true,
                CHAT_MSG_RAID_LEADER = true,
                CHAT_MSG_RAID_WARNING = true,
                CHAT_MSG_GUILD = true,
                CHAT_MSG_OFFICER = true,
                CHAT_MSG_INSTANCE_CHAT = true,
                CHAT_MSG_INSTANCE_CHAT_LEADER = true,
                CHAT_MSG_CHANNEL = true,
                CHAT_MSG_EMOTE = true,
            }
            
            if mentionEvents[event] then
                if chatModule:CheckForMention(message) then
                    chatModule:TriggerMentionAlert()
                end
            end
            
            -- Check for guild alerts
            if event == "CHAT_MSG_GUILD" or event == "CHAT_MSG_OFFICER" then
                chatModule:TriggerGuildAlert()
            end
        end
        
        -- Route messages to custom tabs that are listening for this event
        for customIndex, msgFrame in pairs(customTabFrames) do
            if msgFrame.eventFilter and msgFrame.eventFilter[event] then
                -- Wrap entire message handling in pcall to handle secret values
                pcall(function()
                    -- This custom tab wants this message type
                    local formattedMessage = message
                    
                    -- Test if we can actually use sender and message (not secret values)
                    local canUseSender = false
                    local displayName = ""
                    if sender then
                        local success, result = pcall(function()
                            local name = Ambiguate(sender, "short")
                            local _ = name .. ""  -- Test concatenation
                            return name
                        end)
                        if success and result then
                            displayName = result
                            canUseSender = true
                        end
                    end
                    
                    local canUseMessage = false
                    if message then
                        local success = pcall(function()
                            local _ = message .. ""
                        end)
                        canUseMessage = success
                    end
                    
                    -- Add sender prefix for player messages
                    if canUseSender and canUseMessage then
                        -- Get color based on event type
                        local r, g, b = 1, 1, 1
                        if event:find("WHISPER") then
                            r, g, b = 1, 0.5, 1
                        elseif event:find("PARTY") then
                            r, g, b = 0.67, 0.67, 1
                        elseif event:find("RAID") then
                            r, g, b = 1, 0.5, 0
                        elseif event:find("GUILD") then
                            r, g, b = 0.25, 1, 0.25
                        elseif event:find("OFFICER") then
                            r, g, b = 0.25, 0.75, 0.25
                        elseif event:find("INSTANCE") then
                            r, g, b = 1, 0.5, 0
                        elseif event:find("YELL") then
                            r, g, b = 1, 0.25, 0.25
                        elseif event:find("EMOTE") then
                            r, g, b = 1, 0.5, 0.25
                        elseif event:find("SYSTEM") or event:find("LOOT") or event:find("MONEY") then
                            r, g, b = 1, 1, 0
                        end
                        
                        -- Format message with channel prefix
                        local prefix = ""
                        if event == "CHAT_MSG_SAY" then
                            prefix = "[" .. displayName .. "]: "
                        elseif event == "CHAT_MSG_YELL" then
                            prefix = "[" .. displayName .. "] yells: "
                        elseif event == "CHAT_MSG_WHISPER" then
                            prefix = "[" .. displayName .. "] whispers: "
                        elseif event == "CHAT_MSG_WHISPER_INFORM" then
                            prefix = "To [" .. displayName .. "]: "
                        elseif event:find("PARTY") then
                            prefix = "[Party][" .. displayName .. "]: "
                        elseif event:find("RAID") then
                            prefix = "[Raid][" .. displayName .. "]: "
                        elseif event:find("GUILD") then
                            prefix = "[Guild][" .. displayName .. "]: "
                        elseif event:find("OFFICER") then
                            prefix = "[Officer][" .. displayName .. "]: "
                        elseif event:find("INSTANCE") then
                            prefix = "[Instance][" .. displayName .. "]: "
                        elseif event:find("EMOTE") then
                            prefix = displayName .. " "
                        else
                            prefix = "[" .. displayName .. "]: "
                        end
                        
                        formattedMessage = prefix .. message
                        
                        -- Add timestamp
                        formattedMessage = chatModule:FormatMessageWithTimestamp(formattedMessage)
                        
                        msgFrame:AddMessage(formattedMessage, r, g, b)
                        msgFrame:ScrollToBottom()
                    elseif canUseMessage then
                        -- System message without sender
                        formattedMessage = chatModule:FormatMessageWithTimestamp(message)
                        msgFrame:AddMessage(formattedMessage, 1, 1, 0)
                        msgFrame:ScrollToBottom()
                    end
                    -- If neither sender nor message are usable, skip this message silently
                end)
            end
        end
    end)
    
    TweaksUI:PrintDebug("Chat: Registered direct chat events for custom tabs")
end

-- ============================================================================
-- CHAT WINDOW CHANGE EVENTS
-- ============================================================================

function Chat:RegisterChatEvents()
    if self._eventsRegistered then return end
    self._eventsRegistered = true
    
    -- Create event frame if needed
    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame")
    end
    
    local eventFrame = self.eventFrame
    
    -- Register for chat window change events
    eventFrame:RegisterEvent("UPDATE_CHAT_WINDOWS")
    eventFrame:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS")
    eventFrame:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")  -- Channel join/leave
    
    eventFrame:SetScript("OnEvent", function(frame, event, ...)
        -- Delay slightly to let Blizzard's system update first
        C_Timer.After(0.1, function()
            self:RefreshChannelTabs()
        end)
    end)
end

function Chat:UnregisterChatEvents()
    if self.eventFrame then
        self.eventFrame:UnregisterAllEvents()
    end
    self._eventsRegistered = false
end

-- ============================================================================
-- CHAT MENU
-- ============================================================================

function Chat:OpenChatMenu()
    local editBox = ChatFrame1EditBox
    if not editBox then return end
    
    -- Show the chat menu dropdown
    if ChatMenu and ChatMenu.ShowMenu then
        ChatMenu:ShowMenu()
    elseif ToggleChatMenu then
        ToggleChatMenu()
    else
        -- Fallback: just focus the edit box
        ChatFrame_OpenChat("")
    end
end

-- ============================================================================
-- COPY FRAME
-- ============================================================================

function Chat:CreateCopyFrame()
    if copyFrame then return copyFrame end
    
    local settings = self:GetSettings()
    
    local frame = CreateFrame("Frame", "TweaksUIChatCopyFrame", UIParent, "BackdropTemplate")
    frame:SetSize(500, 400)
    frame:SetPoint("CENTER")
    frame:SetBackdrop(darkBackdrop)
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("Copy Chat")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 15, -45)
    scrollFrame:SetPoint("BOTTOMRIGHT", -35, 15)
    
    -- Edit box for copyable text
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(scrollFrame:GetWidth())
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed", function() frame:Hide() end)
    
    scrollFrame:SetScrollChild(editBox)
    
    frame.editBox = editBox
    frame.scrollFrame = scrollFrame
    
    -- Drag to move
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    
    copyFrame = frame
    return frame
end

function Chat:ShowCopyFrame()
    if not copyFrame then
        self:CreateCopyFrame()
    end
    
    local settings = self:GetSettings()
    local lines = {}
    
    -- Get messages from our custom frame
    if customChatFrame and customChatFrame.messageFrame then
        local numMessages = customChatFrame.messageFrame:GetNumMessages()
        local startLine = math.max(1, numMessages - settings.copyLines + 1)
        
        for i = startLine, numMessages do
            local text = customChatFrame.messageFrame:GetMessageInfo(i)
            if text and type(text) == "string" then
                -- Strip color codes for cleaner copy - use pcall for safety
                local success, cleanText = pcall(function()
                    local t = text:gsub("|c%x%x%x%x%x%x%x%x", "")
                    t = t:gsub("|r", "")
                    return t
                end)
                if success then
                    table.insert(lines, cleanText)
                else
                    table.insert(lines, text)  -- Use original if stripping failed
                end
            end
        end
    end
    
    -- Filter out any nil or secret values before concatenating
    local cleanLines = {}
    for i, line in ipairs(lines) do
        if line ~= nil and type(line) == "string" then
            table.insert(cleanLines, line)
        end
    end
    
    copyFrame.editBox:SetText(table.concat(cleanLines, "\n"))
    copyFrame.editBox:HighlightText()
    copyFrame.editBox:SetCursorPosition(0)
    copyFrame:Show()
end

-- ============================================================================
-- PROFILE IMPORT/EXPORT
-- ============================================================================

-- JSON-like serialization
local function serializeValue(val)
    local t = type(val)
    if t == "string" then
        return "\"" .. val:gsub("\\", "\\\\"):gsub("\"", "\\\""):gsub("\n", "\\n") .. "\""
    elseif t == "number" then
        return tostring(val)
    elseif t == "boolean" then
        return val and "true" or "false"
    elseif t == "table" then
        local parts = {}
        local isArray = true
        local maxIndex = 0
        for k, v in pairs(val) do
            if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
                isArray = false
                break
            end
            maxIndex = math.max(maxIndex, k)
        end
        
        if isArray and maxIndex > 0 then
            for i = 1, maxIndex do
                table.insert(parts, serializeValue(val[i]))
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            for k, v in pairs(val) do
                table.insert(parts, serializeValue(tostring(k)) .. ":" .. serializeValue(v))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end
    return "null"
end

local function deserializeValue(str, pos)
    pos = pos or 1
    while pos <= #str and str:sub(pos, pos):match("%s") do
        pos = pos + 1
    end
    
    if pos > #str then return nil, pos end
    
    local char = str:sub(pos, pos)
    
    if char == '"' then
        local endPos = pos + 1
        local result = ""
        while endPos <= #str do
            local c = str:sub(endPos, endPos)
            if c == "\\" and endPos < #str then
                local next = str:sub(endPos + 1, endPos + 1)
                if next == "\\" or next == '"' then
                    result = result .. next
                    endPos = endPos + 2
                elseif next == "n" then
                    result = result .. "\n"
                    endPos = endPos + 2
                else
                    endPos = endPos + 1
                end
            elseif c == '"' then
                return result, endPos + 1
            else
                result = result .. c
                endPos = endPos + 1
            end
        end
        return nil, pos
    end
    
    if char:match("[%-0-9]") then
        local numStr = str:match("^%-?[0-9]+%.?[0-9]*", pos)
        if numStr then
            return tonumber(numStr), pos + #numStr
        end
    end
    
    if str:sub(pos, pos + 3) == "true" then
        return true, pos + 4
    elseif str:sub(pos, pos + 4) == "false" then
        return false, pos + 5
    elseif str:sub(pos, pos + 3) == "null" then
        return nil, pos + 4
    end
    
    if char == "[" then
        local arr = {}
        pos = pos + 1
        while pos <= #str do
            while pos <= #str and str:sub(pos, pos):match("%s") do
                pos = pos + 1
            end
            if str:sub(pos, pos) == "]" then
                return arr, pos + 1
            end
            local val
            val, pos = deserializeValue(str, pos)
            table.insert(arr, val)
            while pos <= #str and str:sub(pos, pos):match("[%s,]") do
                pos = pos + 1
            end
        end
        return arr, pos
    end
    
    if char == "{" then
        local obj = {}
        pos = pos + 1
        while pos <= #str do
            while pos <= #str and str:sub(pos, pos):match("%s") do
                pos = pos + 1
            end
            if str:sub(pos, pos) == "}" then
                return obj, pos + 1
            end
            local key
            key, pos = deserializeValue(str, pos)
            while pos <= #str and str:sub(pos, pos):match("[%s:]") do
                pos = pos + 1
            end
            local val
            val, pos = deserializeValue(str, pos)
            if key then
                local numKey = tonumber(key)
                if numKey then
                    obj[numKey] = val
                else
                    obj[key] = val
                end
            end
            while pos <= #str and str:sub(pos, pos):match("[%s,]") do
                pos = pos + 1
            end
        end
        return obj, pos
    end
    
    return nil, pos + 1
end

function Chat:SerializeSettings()
    local settings = self:GetSettings()
    if not settings then return nil end
    
    -- Create a filtered copy of settings (exclude runtime data like chatHistory)
    local filteredSettings = {}
    for key, value in pairs(settings) do
        if key ~= "chatHistory" then  -- Don't export chat history
            if type(value) == "table" then
                filteredSettings[key] = CopyTable(value)
            else
                filteredSettings[key] = value
            end
        end
    end
    
    local exportData = {
        version = 1,
        settings = filteredSettings,
    }
    
    local json = serializeValue(exportData)
    
    local LibDeflate = LibStub and LibStub("LibDeflate", true)
    if LibDeflate then
        local compressed = LibDeflate:CompressDeflate(json)
        local encoded = LibDeflate:EncodeForPrint(compressed)
        return "TUI_CHAT1:" .. encoded
    else
        return "TUI_CHAT1:" .. json
    end
end

function Chat:DeserializeSettings(encoded)
    if not encoded or not encoded:match("^TUI_CHAT1:") then
        return nil, "Invalid format: String must start with TUI_CHAT1:"
    end
    
    local data = encoded:sub(11) -- Remove "TUI_CHAT1:" prefix
    
    local LibDeflate = LibStub and LibStub("LibDeflate", true)
    local json
    if LibDeflate then
        local decoded = LibDeflate:DecodeForPrint(data)
        if decoded then
            json = LibDeflate:DecompressDeflate(decoded)
        end
    end
    
    if not json then
        json = data
    end
    
    if not json or json == "" then
        return nil, "Failed to decode settings string"
    end
    
    local result, _ = deserializeValue(json, 1)
    if not result then
        return nil, "Failed to parse settings data"
    end
    
    if not result.version then
        return nil, "Invalid settings: missing version"
    end
    
    return result, nil
end

function Chat:ImportSettings(importData)
    if not importData or not importData.settings then
        return false, "No settings data to import"
    end
    
    -- Get current settings reference
    local currentSettings = self:GetSettings()
    if not currentSettings then
        return false, "Could not access current settings"
    end
    
    -- Preserve existing chat history
    local existingHistory = currentSettings.chatHistory
    
    -- Deep copy imported settings
    for key, value in pairs(importData.settings) do
        if key ~= "chatHistory" then  -- Don't import chatHistory (it shouldn't be in export anyway)
            if type(value) == "table" then
                currentSettings[key] = CopyTable(value)
            else
                currentSettings[key] = value
            end
        end
    end
    
    -- Restore existing chat history
    if existingHistory then
        currentSettings.chatHistory = existingHistory
    end
    
    -- Refresh the chat frame
    self:RefreshChatFrame()
    
    return true, "Chat settings imported successfully"
end

-- Export window
local chatExportFrame = nil
function Chat:ShowExportWindow()
    if chatExportFrame then
        chatExportFrame:Show()
        chatExportFrame.editBox:SetText(self:SerializeSettings() or "Error generating export")
        return
    end
    
    local frame = CreateFrame("Frame", "TweaksUI_Chat_ExportFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(500, 350)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("TOP", 0, -5)
    frame.title:SetText("Export Chat Settings")
    
    local info = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    info:SetPoint("TOPLEFT", 15, -35)
    info:SetText("Copy this string to share your settings:")
    
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -55)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 45)
    
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetWidth(scrollFrame:GetWidth())
    editBox:SetText(self:SerializeSettings() or "Error generating export")
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed", function() frame:Hide() end)
    scrollFrame:SetScrollChild(editBox)
    frame.editBox = editBox
    
    local selectBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    selectBtn:SetSize(100, 22)
    selectBtn:SetPoint("BOTTOMLEFT", 10, 10)
    selectBtn:SetText("Select All")
    selectBtn:SetScript("OnClick", function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)
    
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeBtn:SetSize(80, 22)
    closeBtn:SetPoint("BOTTOMRIGHT", -10, 10)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    chatExportFrame = frame
    frame:Show()
end

-- Import window
local chatImportFrame = nil
function Chat:ShowImportWindow()
    if chatImportFrame then
        chatImportFrame:Show()
        chatImportFrame.editBox:SetText("")
        chatImportFrame.statusText:SetText("")
        return
    end
    
    local frame = CreateFrame("Frame", "TweaksUI_Chat_ImportFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(500, 380)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("TOP", 0, -5)
    frame.title:SetText("Import Chat Settings")
    
    local info = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    info:SetPoint("TOPLEFT", 15, -35)
    info:SetWidth(470)
    info:SetJustifyH("LEFT")
    info:SetText("Paste a settings string below:")
    
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -55)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 70)
    
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetWidth(scrollFrame:GetWidth())
    editBox:SetAutoFocus(true)
    editBox:SetScript("OnEscapePressed", function() frame:Hide() end)
    scrollFrame:SetScrollChild(editBox)
    frame.editBox = editBox
    
    local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("BOTTOMLEFT", 15, 45)
    statusText:SetPoint("BOTTOMRIGHT", -15, 45)
    statusText:SetJustifyH("LEFT")
    statusText:SetTextColor(1, 0.82, 0)
    frame.statusText = statusText
    
    local module = self
    local importBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    importBtn:SetSize(100, 22)
    importBtn:SetPoint("BOTTOMLEFT", 10, 10)
    importBtn:SetText("Import")
    importBtn:SetScript("OnClick", function()
        local importString = editBox:GetText()
        
        if not importString or importString == "" then
            statusText:SetTextColor(1, 0, 0)
            statusText:SetText("Error: Please paste a settings string")
            return
        end
        
        local data, err = module:DeserializeSettings(importString)
        if not data then
            statusText:SetTextColor(1, 0, 0)
            statusText:SetText("Error: " .. (err or "Invalid data"))
            return
        end
        
        local success, msg = module:ImportSettings(data)
        if success then
            statusText:SetTextColor(0, 1, 0)
            statusText:SetText("Success! " .. msg)
            C_Timer.After(1.5, function()
                frame:Hide()
            end)
        else
            statusText:SetTextColor(1, 0, 0)
            statusText:SetText("Error: " .. msg)
        end
    end)
    
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeBtn:SetSize(80, 22)
    closeBtn:SetPoint("BOTTOMRIGHT", -10, 10)
    closeBtn:SetText("Cancel")
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    chatImportFrame = frame
    frame:Show()
end

-- ============================================================================
-- CHAT HUB (Settings Panel)
-- ============================================================================

function Chat:ToggleChatHub()
    if chatHub and chatHub:IsShown() then
        chatHub:Hide()
        for _, panel in pairs(chatPanels) do
            if panel then panel:Hide() end
        end
    else
        self:CreateChatHub()
        chatHub:Show()
    end
end

function Chat:OpenChatHubDocked(parentPanel)
    self:CreateChatHub()
    
    -- Dock to parent panel if provided
    if parentPanel and chatHub then
        chatHub:ClearAllPoints()
        chatHub:SetPoint("TOPLEFT", parentPanel, "TOPRIGHT", 0, 0)
    end
    
    chatHub:Show()
end

function Chat:HideAllPanels()
    if chatHub then
        chatHub:Hide()
    end
    for _, panel in pairs(chatPanels) do
        if panel and panel.Hide then
            panel:Hide()
        end
    end
end

function Chat:CreateChatHub()
    if chatHub then return chatHub end
    
    local hub = CreateFrame("Frame", "TweaksUIChatHub", UIParent, "BackdropTemplate")
    hub:SetSize(HUB_WIDTH, 500)  -- Increased height for preset dropdown
    hub:SetBackdrop(darkBackdrop)
    hub:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    hub:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    hub:SetMovable(true)
    hub:EnableMouse(true)
    hub:SetClampedToScreen(true)
    hub:SetFrameStrata("DIALOG")
    
    -- Position near chat frame
    if customChatFrame then
        hub:SetPoint("BOTTOMLEFT", customChatFrame, "BOTTOMRIGHT", 10, 0)
    else
        hub:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 450, 20)
    end
    
    -- Title
    local title = hub:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("Chat Settings")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, hub, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -3, -3)
    closeBtn:SetScript("OnClick", function()
        hub:Hide()
        for _, panel in pairs(chatPanels) do
            if panel then panel:Hide() end
        end
    end)
    
    -- Drag to move
    hub:RegisterForDrag("LeftButton")
    hub:SetScript("OnDragStart", hub.StartMoving)
    hub:SetScript("OnDragStop", hub.StopMovingOrSizing)
    
    -- Close all panels when hub is hidden
    hub:SetScript("OnHide", function()
        for _, panel in pairs(chatPanels) do
            if panel then panel:Hide() end
        end
    end)
    
    -- Content area
    local yOffset = -38
    local buttonWidth = HUB_WIDTH - 20
    
    -- Add Preset Dropdown
    if TweaksUI.PresetDropdown then
        local presetContainer, nextY = TweaksUI.PresetDropdown:Create(
            hub,
            "chat",
            "Chat",
            yOffset,
            {
                width = 140,
                showSaveButton = true,
                showDeleteButton = true,
            }
        )
        yOffset = nextY - 8
    end
    
    -- General button
    local generalBtn = CreateFrame("Button", nil, hub, "UIPanelButtonTemplate")
    generalBtn:SetPoint("TOP", 0, yOffset)
    generalBtn:SetSize(buttonWidth, BUTTON_HEIGHT)
    generalBtn:SetText("General")
    generalBtn:SetScript("OnClick", function() self:TogglePanel("general") end)
    yOffset = yOffset - BUTTON_HEIGHT - BUTTON_SPACING
    
    -- Layout button
    local layoutBtn = CreateFrame("Button", nil, hub, "UIPanelButtonTemplate")
    layoutBtn:SetPoint("TOP", 0, yOffset)
    layoutBtn:SetSize(buttonWidth, BUTTON_HEIGHT)
    layoutBtn:SetText("Layout")
    layoutBtn:SetScript("OnClick", function() self:TogglePanel("layout") end)
    yOffset = yOffset - BUTTON_HEIGHT - BUTTON_SPACING
    
    -- Appearance button
    local appearanceBtn = CreateFrame("Button", nil, hub, "UIPanelButtonTemplate")
    appearanceBtn:SetPoint("TOP", 0, yOffset)
    appearanceBtn:SetSize(buttonWidth, BUTTON_HEIGHT)
    appearanceBtn:SetText("Appearance")
    appearanceBtn:SetScript("OnClick", function() self:TogglePanel("appearance") end)
    yOffset = yOffset - BUTTON_HEIGHT - BUTTON_SPACING
    
    -- Channels button
    local channelsBtn = CreateFrame("Button", nil, hub, "UIPanelButtonTemplate")
    channelsBtn:SetPoint("TOP", 0, yOffset)
    channelsBtn:SetSize(buttonWidth, BUTTON_HEIGHT)
    channelsBtn:SetText("Channels/Tabs")
    channelsBtn:SetScript("OnClick", function() self:TogglePanel("channels") end)
    yOffset = yOffset - BUTTON_HEIGHT - BUTTON_SPACING
    
    -- Behavior button (NEW)
    local behaviorBtn = CreateFrame("Button", nil, hub, "UIPanelButtonTemplate")
    behaviorBtn:SetPoint("TOP", 0, yOffset)
    behaviorBtn:SetSize(buttonWidth, BUTTON_HEIGHT)
    behaviorBtn:SetText("Behavior")
    behaviorBtn:SetScript("OnClick", function() self:TogglePanel("behavior") end)
    yOffset = yOffset - BUTTON_HEIGHT - BUTTON_SPACING
    
    -- Formatting button (NEW)
    local formattingBtn = CreateFrame("Button", nil, hub, "UIPanelButtonTemplate")
    formattingBtn:SetPoint("TOP", 0, yOffset)
    formattingBtn:SetSize(buttonWidth, BUTTON_HEIGHT)
    formattingBtn:SetText("Formatting")
    formattingBtn:SetScript("OnClick", function() self:TogglePanel("formatting") end)
    yOffset = yOffset - BUTTON_HEIGHT - BUTTON_SPACING
    
    -- Alerts & Filters button (NEW)
    local alertsBtn = CreateFrame("Button", nil, hub, "UIPanelButtonTemplate")
    alertsBtn:SetPoint("TOP", 0, yOffset)
    alertsBtn:SetSize(buttonWidth, BUTTON_HEIGHT)
    alertsBtn:SetText("Alerts & Filters")
    alertsBtn:SetScript("OnClick", function() self:TogglePanel("alerts") end)
    yOffset = yOffset - BUTTON_HEIGHT - BUTTON_SPACING * 2
    
    -- Separator
    local sep = hub:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOP", 0, yOffset)
    sep:SetSize(buttonWidth, 1)
    sep:SetColorTexture(0.4, 0.4, 0.4, 0.6)
    yOffset = yOffset - 12
    
    -- Import/Export section label
    local ieLabel = hub:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ieLabel:SetPoint("TOP", 0, yOffset)
    ieLabel:SetText("Import / Export")
    yOffset = yOffset - 18
    
    -- Export button
    local exportBtn = CreateFrame("Button", nil, hub, "UIPanelButtonTemplate")
    exportBtn:SetSize(buttonWidth / 2 - 4, 24)
    exportBtn:SetPoint("TOPLEFT", hub, "TOPLEFT", 10, yOffset)
    exportBtn:SetText("Export")
    exportBtn:SetScript("OnClick", function() self:ShowExportWindow() end)
    
    -- Import button
    local importBtn = CreateFrame("Button", nil, hub, "UIPanelButtonTemplate")
    importBtn:SetSize(buttonWidth / 2 - 4, 24)
    importBtn:SetPoint("TOPRIGHT", hub, "TOPRIGHT", -10, yOffset)
    importBtn:SetText("Import")
    importBtn:SetScript("OnClick", function() self:ShowImportWindow() end)
    
    yOffset = yOffset - 30
    
    -- Adjust hub height
    hub:SetHeight(-yOffset + 20)
    
    hub:Hide()
    chatHub = hub
    return hub
end

function Chat:TogglePanel(panelName)
    -- Hide all panels first
    for name, panel in pairs(chatPanels) do
        if panel and name ~= panelName then
            panel:Hide()
        end
    end
    
    -- Toggle the requested panel
    if chatPanels[panelName] then
        if chatPanels[panelName]:IsShown() then
            chatPanels[panelName]:Hide()
        else
            chatPanels[panelName]:Show()
        end
    else
        -- Create the panel
        if panelName == "general" then
            self:CreateGeneralPanel()
        elseif panelName == "layout" then
            self:CreateLayoutPanel()
        elseif panelName == "appearance" then
            self:CreateAppearancePanel()
        elseif panelName == "channels" then
            self:CreateChannelsPanel()
        elseif panelName == "behavior" then
            self:CreateBehaviorPanel()
        elseif panelName == "formatting" then
            self:CreateFormattingPanel()
        elseif panelName == "alerts" then
            self:CreateAlertsPanel()
        end
        if chatPanels[panelName] then
            chatPanels[panelName]:Show()
        end
    end
end

function Chat:CreateDockedPanel(name, title, height)
    local panel = CreateFrame("Frame", "TweaksUIChat" .. name .. "Panel", UIParent, "BackdropTemplate")
    panel:SetSize(PANEL_WIDTH, height)
    panel:SetBackdrop(darkBackdrop)
    panel:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    panel:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    panel:EnableMouse(true)
    panel:SetFrameStrata("DIALOG")
    
    if chatHub then
        panel:SetPoint("TOPLEFT", chatHub, "TOPRIGHT", 5, 0)
    end
    
    -- Title
    local titleText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("TOP", 0, -12)
    titleText:SetText(title)
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -3, -3)
    closeBtn:SetScript("OnClick", function() panel:Hide() end)
    
    -- Content scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -35)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(PANEL_WIDTH - 50, height - 50)
    scrollFrame:SetScrollChild(content)
    
    panel.content = content
    panel:Hide()
    
    chatPanels[name] = panel
    return panel
end

function Chat:CreateGeneralPanel()
    local panel = self:CreateDockedPanel("general", "General", 500)
    local content = panel.content
    local settings = self:GetSettings()
    local yOffset = -10
    
    -- Button Bar section
    local buttonBarLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    buttonBarLabel:SetPoint("TOPLEFT", 0, yOffset)
    buttonBarLabel:SetText("Button Bar")
    yOffset = yOffset - 25
    
    -- Show button bar checkbox
    local showButtonsCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    showButtonsCheck:SetPoint("TOPLEFT", 0, yOffset)
    showButtonsCheck.text:SetText("Show button bar")
    showButtonsCheck:SetChecked(settings.showButtonBar)
    showButtonsCheck:SetScript("OnClick", function(self)
        settings.showButtonBar = self:GetChecked()
        Chat:SaveSettings()
        if customChatFrame and customChatFrame.buttonBar then
            customChatFrame.buttonBar:SetShown(settings.showButtonBar)
        end
    end)
    yOffset = yOffset - 30
    
    -- Fade buttons checkbox
    local fadeButtonsCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    fadeButtonsCheck:SetPoint("TOPLEFT", 0, yOffset)
    fadeButtonsCheck.text:SetText("Fade buttons when not hovering")
    fadeButtonsCheck:SetChecked(settings.fadeButtons)
    fadeButtonsCheck:SetScript("OnClick", function(self)
        settings.fadeButtons = self:GetChecked()
        Chat:SaveSettings()
        -- Would need to recreate button bar to apply
    end)
    yOffset = yOffset - 40
    
    -- Window Fade section
    local windowFadeLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    windowFadeLabel:SetPoint("TOPLEFT", 0, yOffset)
    windowFadeLabel:SetText("Window Fade")
    yOffset = yOffset - 25
    
    -- Enable window fade checkbox
    local enableWindowFadeCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    enableWindowFadeCheck:SetPoint("TOPLEFT", 0, yOffset)
    enableWindowFadeCheck.text:SetText("Fade entire window when inactive")
    enableWindowFadeCheck:SetChecked(settings.enableWindowFade)
    enableWindowFadeCheck:SetScript("OnClick", function(self)
        settings.enableWindowFade = self:GetChecked()
        Chat:SaveSettings()
        if customChatFrame then
            if settings.enableWindowFade then
                customChatFrame.StartFadeTimer()
            else
                customChatFrame.FadeWindowIn()
            end
        end
    end)
    yOffset = yOffset - 30
    
    -- Fade delay slider with input
    local delayContainer = TweaksUI.Utilities:CreateSliderWithInput(content, {
        label = "Fade Delay:",
        min = 1,
        max = 60,
        step = 1,
        value = settings.windowFadeDelay,
        width = 180,
        labelWidth = 90,
        valueWidth = 45,
        formatStr = "%ds",
        onValueChanged = function(value)
            settings.windowFadeDelay = value
        end,
    })
    delayContainer:SetPoint("TOPLEFT", 20, yOffset)
    yOffset = yOffset - 35
    
    -- Faded opacity slider with input
    local opacityContainer = TweaksUI.Utilities:CreateSliderWithInput(content, {
        label = "Faded Opacity:",
        min = 0,
        max = 100,
        step = 5,
        value = settings.windowFadeAlpha * 100,
        width = 180,
        labelWidth = 90,
        valueWidth = 45,
        formatStr = "%d%%",
        onValueChanged = function(value)
            settings.windowFadeAlpha = value / 100
        end,
    })
    opacityContainer:SetPoint("TOPLEFT", 20, yOffset)
    yOffset = yOffset - 40
    
    -- Copy Chat section
    local copyLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    copyLabel:SetPoint("TOPLEFT", 0, yOffset)
    copyLabel:SetText("Copy Chat")
    yOffset = yOffset - 25
    
    -- Copy lines slider with input
    local linesContainer = TweaksUI.Utilities:CreateSliderWithInput(content, {
        label = "Copy Lines:",
        min = 50,
        max = 2000,
        step = 50,
        value = settings.copyLines,
        width = 200,
        labelWidth = 80,
        valueWidth = 50,
        onValueChanged = function(value)
            settings.copyLines = value
        end,
    })
    linesContainer:SetPoint("TOPLEFT", 0, yOffset)
end

function Chat:CreateLayoutPanel()
    local panel = self:CreateDockedPanel("layout", "Layout", 600)
    local content = panel.content
    local settings = self:GetSettings()
    local yOffset = -10
    
    -- Button Bar Position section
    local buttonPosLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    buttonPosLabel:SetPoint("TOPLEFT", 0, yOffset)
    buttonPosLabel:SetText("Button Bar Position")
    yOffset = yOffset - 25
    
    local buttonPositions = { 
        { value = "LEFT", label = "Left (vertical)" },
        { value = "RIGHT", label = "Right (vertical)" },
        { value = "TOP", label = "Top (horizontal)" },
        { value = "INDEPENDENT", label = "Independent (movable)" },
    }
    local buttonRadios = {}
    
    for i, pos in ipairs(buttonPositions) do
        local radio = CreateFrame("CheckButton", nil, content, "UIRadioButtonTemplate")
        radio:SetPoint("TOPLEFT", 0, yOffset)
        radio.text:SetText(pos.label)
        radio:SetChecked(settings.buttonBarPosition == pos.value)
        radio:SetScript("OnClick", function()
            settings.buttonBarPosition = pos.value
            for _, r in pairs(buttonRadios) do r:SetChecked(false) end
            radio:SetChecked(true)
            if customChatFrame and customChatFrame.buttonBar then
                Chat:PositionButtonBar(customChatFrame.buttonBar, customChatFrame)
                Chat:AttachEditBox(customChatFrame)
            end
        end)
        buttonRadios[i] = radio
        yOffset = yOffset - 22
    end
    
    yOffset = yOffset - 10
    
    -- Independent orientation checkbox (only relevant when INDEPENDENT)
    local verticalCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    verticalCheck:SetPoint("TOPLEFT", 20, yOffset)
    verticalCheck.text:SetText("Vertical layout (when Independent)")
    verticalCheck:SetChecked(settings.buttonBarVertical ~= false)
    verticalCheck:SetScript("OnClick", function(self)
        settings.buttonBarVertical = self:GetChecked()
        Chat:SaveSettings()
        if customChatFrame and customChatFrame.buttonBar and settings.buttonBarPosition == "INDEPENDENT" then
            Chat:PositionButtonBar(customChatFrame.buttonBar, customChatFrame)
        end
    end)
    yOffset = yOffset - 30
    
    -- Button Size slider with input
    local btnSizeContainer = TweaksUI.Utilities:CreateSliderWithInput(content, {
        label = "Button Size:",
        min = 16,
        max = 32,
        step = 2,
        value = settings.buttonSize or 22,
        width = 200,
        labelWidth = 90,
        valueWidth = 40,
        onValueChanged = function(value)
            settings.buttonSize = value
            if customChatFrame and customChatFrame.buttonBar then
                Chat:PositionButtonBar(customChatFrame.buttonBar, customChatFrame)
                Chat:AttachEditBox(customChatFrame)
            end
        end,
    })
    btnSizeContainer:SetPoint("TOPLEFT", 0, yOffset)
    yOffset = yOffset - 35
    
    -- Button Spacing slider with input
    local btnSpaceContainer = TweaksUI.Utilities:CreateSliderWithInput(content, {
        label = "Button Spacing:",
        min = 0,
        max = 10,
        step = 1,
        value = settings.buttonSpacing or 2,
        width = 200,
        labelWidth = 100,
        valueWidth = 40,
        onValueChanged = function(value)
            settings.buttonSpacing = value
            if customChatFrame and customChatFrame.buttonBar then
                Chat:PositionButtonBar(customChatFrame.buttonBar, customChatFrame)
            end
        end,
    })
    btnSpaceContainer:SetPoint("TOPLEFT", 0, yOffset)
    yOffset = yOffset - 50
    
    -- Edit Box Position section
    local editPosLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    editPosLabel:SetPoint("TOPLEFT", 0, yOffset)
    editPosLabel:SetText("Edit Box Position")
    yOffset = yOffset - 25
    
    local editPositions = { "TOP", "BOTTOM", "INDEPENDENT" }
    local editRadios = {}
    
    for i, pos in ipairs(editPositions) do
        local radio = CreateFrame("CheckButton", nil, content, "UIRadioButtonTemplate")
        radio:SetPoint("TOPLEFT", 0, yOffset)
        radio.text:SetText(pos:sub(1,1) .. pos:sub(2):lower())
        radio:SetChecked(settings.editBoxPosition == pos)
        radio:SetScript("OnClick", function()
            settings.editBoxPosition = pos
            for _, r in pairs(editRadios) do r:SetChecked(false) end
            radio:SetChecked(true)
            if customChatFrame then
                Chat:PositionButtonBar(customChatFrame.buttonBar, customChatFrame)
                Chat:AttachEditBox(customChatFrame)
            end
        end)
        editRadios[i] = radio
        yOffset = yOffset - 22
    end
    
    yOffset = yOffset - 10
    
    -- Auto-hide edit box checkbox
    local autoHideCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    autoHideCheck:SetPoint("TOPLEFT", 0, yOffset)
    autoHideCheck.text:SetText("Hide edit box until typing")
    autoHideCheck:SetChecked(settings.autoHideEditBox)
    autoHideCheck:SetScript("OnClick", function(self)
        settings.autoHideEditBox = self:GetChecked()
        Chat:SaveSettings()
        -- Apply immediately
        local editBox = ChatFrame1EditBox
        if editBox then
            if settings.autoHideEditBox then
                -- Hide if not focused
                if not editBox:HasFocus() then
                    editBox:SetAlpha(0)
                end
            else
                -- Show
                editBox:SetAlpha(1)
            end
        end
    end)
    autoHideCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Auto-Hide Edit Box", 1, 1, 1)
        GameTooltip:AddLine("Hides the chat input box when not typing.", 0.7, 0.7, 0.7, true)
        GameTooltip:AddLine("Press Enter or / to show it.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    autoHideCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)
    yOffset = yOffset - 30
    
    -- Info text
    local infoText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoText:SetPoint("TOPLEFT", 0, yOffset)
    infoText:SetWidth(PANEL_WIDTH - 60)
    infoText:SetText("|cff888888Use Edit Mode (Esc > Edit Mode) to move the chat frame.\nShift+drag button bar when set to Independent.\nShift+drag edit box when set to Independent.|r")
    infoText:SetJustifyH("LEFT")
    yOffset = yOffset - 50
    
    -- Reset Position button
    local resetBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    resetBtn:SetPoint("TOPLEFT", 0, yOffset)
    resetBtn:SetSize(150, 25)
    resetBtn:SetText("Reset All Positions")
    resetBtn:SetScript("OnClick", function()
        settings.frameX = nil
        settings.frameY = nil
        settings.frameWidth = 430
        settings.frameHeight = 200
        settings.buttonBarX = nil
        settings.buttonBarY = nil
        settings.editBoxX = nil
        settings.editBoxY = nil
        if customChatFrame then
            customChatFrame:ClearAllPoints()
            customChatFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 20, 20)
            customChatFrame:SetSize(430, 200)
            if customChatFrame.buttonBar then
                Chat:PositionButtonBar(customChatFrame.buttonBar, customChatFrame)
            end
            Chat:AttachEditBox(customChatFrame)
        end
        TweaksUI:Print("All positions reset.")
    end)
end

function Chat:CreateAppearancePanel()
    -- Create Appearance as a tabbed panel with 4 tabs: Background, Fonts, Colors, Timestamps
    local settings = self:GetSettings()
    local TP = TweaksUI.TabbedPanel
    
    -- =========================================================================
    -- TAB BUILDERS
    -- =========================================================================
    
    -- BACKGROUND TAB
    local function BuildBackgroundTab(scrollChild, panel)
        local y = -10
        
        y = TP:CreateCheckbox(scrollChild, y, {
            label = "Show background",
            get = function() return settings.showBackground ~= false end,
            set = function(value)
                settings.showBackground = value
                Chat:ApplyBackgroundSettings()
            end,
        })
        
        y = TP:CreateCheckbox(scrollChild, y, {
            label = "Show border",
            get = function() return settings.showBorder ~= false end,
            set = function(value)
                settings.showBorder = value
                Chat:ApplyBackgroundSettings()
            end,
        })
        
        y = y - 10
        
        y = TP:CreateSlider(scrollChild, y, {
            label = "Background Opacity:",
            min = 0, max = 100, step = 5,
            get = function() return (settings.bgAlpha or 0.7) * 100 end,
            set = function(value)
                settings.bgAlpha = value / 100
                Chat:ApplyBackgroundSettings()
            end,
            labelWidth = 120, width = 140, valueWidth = 45,
        })
        
        y = y - 10
        
        -- Background color
        -- Ensure bgColor is a table
        if type(settings.bgColor) ~= "table" then
            settings.bgColor = {r = 0, g = 0, b = 0}
        end
        
        y = TP:CreateColorPicker(scrollChild, y, {
            label = "Background Color",
            get = function() return settings.bgColor end,
            set = function(r, g, b)
                settings.bgColor = {r = r, g = g, b = b}
                Chat:ApplyBackgroundSettings()
            end,
        })
    end
    
    -- FONTS TAB
    local function BuildFontsTab(scrollChild, panel)
        local y = -10
        
        y = TP:CreateFontDropdown(scrollChild, y, {
            label = "Chat Font",
            width = 180,
            get = function() return settings.fontName or "Friz Quadrata TT" end,
            set = function(fontName)
                settings.fontName = fontName
                settings.fontPath = TweaksUI.Media:GetFont(fontName)
                Chat:ApplyFontSettings()
            end,
        })
        
        y = TP:CreateSlider(scrollChild, y, {
            label = "Font Size:",
            min = 8, max = 24, step = 1,
            get = function() return settings.fontSize or 14 end,
            set = function(value)
                settings.fontSize = value
                Chat:ApplyFontSettings()
            end,
            labelWidth = 70, width = 160, valueWidth = 40,
        })
        
        local outlines = {
            { value = "", text = "None" },
            { value = "OUTLINE", text = "Thin" },
            { value = "THICKOUTLINE", text = "Thick" },
        }
        
        y = TP:CreateDropdown(scrollChild, y, {
            label = "Font Outline",
            width = 140,
            items = outlines,
            get = function() return settings.fontOutline or "" end,
            set = function(value)
                settings.fontOutline = value
                Chat:ApplyFontSettings()
            end,
        })
    end
    
    -- COLORS TAB (Channel Colors)
    local function BuildColorsTab(scrollChild, panel)
        local y = -10
        
        -- Initialize channel colors if not set
        settings.channelColors = settings.channelColors or {}
        
        -- Channel color definitions
        local channels = {
            {key = "SAY", name = "Say", default = {r = 1, g = 1, b = 1}},
            {key = "YELL", name = "Yell", default = {r = 1, g = 0.25, b = 0.25}},
            {key = "WHISPER", name = "Whisper", default = {r = 1, g = 0.5, b = 1}},
            {key = "PARTY", name = "Party", default = {r = 0.67, g = 0.67, b = 1}},
            {key = "RAID", name = "Raid", default = {r = 1, g = 0.5, b = 0}},
            {key = "GUILD", name = "Guild", default = {r = 0.25, g = 1, b = 0.25}},
            {key = "OFFICER", name = "Officer", default = {r = 0.25, g = 0.75, b = 0.25}},
            {key = "INSTANCE_CHAT", name = "Instance", default = {r = 1, g = 0.5, b = 0}},
            {key = "EMOTE", name = "Emote", default = {r = 1, g = 0.5, b = 0.25}},
            {key = "SYSTEM", name = "System", default = {r = 1, g = 1, b = 0}},
        }
        
        for _, channel in ipairs(channels) do
            local color = settings.channelColors[channel.key] or channel.default
            if type(color) ~= "table" then
                color = channel.default
                settings.channelColors[channel.key] = color
            end
            
            y = TP:CreateColorPicker(scrollChild, y, {
                label = channel.name,
                get = function() return settings.channelColors[channel.key] or channel.default end,
                set = function(r, g, b)
                    settings.channelColors[channel.key] = {r = r, g = g, b = b}
                    Chat:ApplyChannelColors()
                end,
            })
        end
        
        y = y - 10
        
        -- Reset button
        y = TP:CreateButton(scrollChild, y, {
            label = "Reset to Defaults",
            width = 130,
            onClick = function()
                settings.channelColors = {}
                Chat:ApplyChannelColors()
                -- Refresh panel
                if chatPanels["appearance"] then
                    chatPanels["appearance"]:RefreshTab("colors")
                end
            end,
        })
    end
    
    -- TIMESTAMPS TAB
    local function BuildTimestampsTab(scrollChild, panel)
        local y = -10
        
        y = TP:CreateCheckbox(scrollChild, y, {
            label = "Enable timestamps",
            get = function() return settings.showTimestamps or false end,
            set = function(value)
                settings.showTimestamps = value
                Chat:ApplyTimestampSettings()
            end,
        })
        
        y = y - 10
        
        local formats = {
            { value = "[%H:%M] ", text = "HH:MM (15:45)" },
            { value = "[%H:%M:%S] ", text = "HH:MM:SS (15:45:30)" },
            { value = "[%I:%M %p] ", text = "H:MM AM/PM (3:45 PM)" },
            { value = "[%I:%M:%S %p] ", text = "H:MM:SS AM/PM" },
            { value = "%H:%M ", text = "HH:MM no brackets" },
            { value = "%H:%M:%S ", text = "HH:MM:SS no brackets" },
        }
        
        y = TP:CreateDropdown(scrollChild, y, {
            label = "Format",
            width = 180,
            items = formats,
            get = function() return settings.timestampFormat or "[%H:%M] " end,
            set = function(value)
                settings.timestampFormat = value
                Chat:ApplyTimestampSettings()
            end,
        })
        
        y = y - 10
        
        -- Handle timestamp color
        if type(settings.timestampColor) ~= "table" then
            settings.timestampColor = {r = 0.5, g = 0.5, b = 0.5}
        end
        
        y = TP:CreateColorPicker(scrollChild, y, {
            label = "Timestamp Color",
            get = function() return settings.timestampColor end,
            set = function(r, g, b)
                settings.timestampColor = {r = r, g = g, b = b}
                Chat:ApplyTimestampSettings()
            end,
        })
    end
    
    -- =========================================================================
    -- CREATE TABBED PANEL
    -- =========================================================================
    
    local tabbedPanel = TP:Create({
        name = "Chat_Appearance_Panel",
        title = "Appearance",
        width = 380,
        height = 450,
        scrollChildHeight = 500,
        tabs = {
            { key = "background", label = "Background", builder = BuildBackgroundTab },
            { key = "fonts", label = "Fonts", builder = BuildFontsTab },
            { key = "colors", label = "Colors", builder = BuildColorsTab },
            { key = "timestamps", label = "Timestamps", builder = BuildTimestampsTab },
        },
        onShow = function(self)
            if chatHub then
                self:ClearAllPoints()
                self:SetPoint("TOPLEFT", chatHub, "TOPRIGHT", 0, 0)
            end
        end,
    })
    
    -- Position next to hub initially
    if chatHub then
        tabbedPanel:ClearAllPoints()
        tabbedPanel:SetPoint("TOPLEFT", chatHub, "TOPRIGHT", 0, 0)
    end
    
    chatPanels["appearance"] = tabbedPanel
    tabbedPanel:Hide()
end

-- ============================================================================
-- CHANNELS/TABS PANEL
-- ============================================================================

-- Available channel types for filtering
local CHANNEL_TYPES = {
    {key = "SAY", name = "Say", events = {"CHAT_MSG_SAY"}},
    {key = "YELL", name = "Yell", events = {"CHAT_MSG_YELL"}},
    {key = "WHISPER", name = "Whisper", events = {"CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM"}},
    {key = "PARTY", name = "Party", events = {"CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER"}},
    {key = "RAID", name = "Raid", events = {"CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING"}},
    {key = "GUILD", name = "Guild", events = {"CHAT_MSG_GUILD"}},
    {key = "OFFICER", name = "Officer", events = {"CHAT_MSG_OFFICER"}},
    {key = "INSTANCE", name = "Instance", events = {"CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER"}},
    {key = "EMOTE", name = "Emote", events = {"CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE"}},
    {key = "SYSTEM", name = "System", events = {"CHAT_MSG_SYSTEM"}},
    {key = "LOOT", name = "Loot", events = {"CHAT_MSG_LOOT", "CHAT_MSG_MONEY"}},
    {key = "TRADE", name = "Trade/LFG", events = {"CHAT_MSG_CHANNEL"}},
}

function Chat:CreateChannelsPanel()
    local panel = self:CreateDockedPanel("channels", "Channels / Tabs", 580)
    local content = panel.content
    local settings = self:GetSettings()
    local yOffset = 0
    
    -- Initialize settings
    settings.tabSettings = settings.tabSettings or {}
    settings.customTabs = settings.customTabs or {}
    if settings.hideVoiceTab == nil then settings.hideVoiceTab = false end
    
    -- ========== VOICE TAB OPTION ==========
    local voiceHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    voiceHeader:SetPoint("TOPLEFT", 0, yOffset)
    voiceHeader:SetText("|cffffd100Voice Channel|r")
    yOffset = yOffset - 20
    
    local hideVoiceCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    hideVoiceCheck:SetPoint("TOPLEFT", 0, yOffset)
    hideVoiceCheck:SetSize(22, 22)
    hideVoiceCheck.text:SetText("Hide Voice Chat tab")
    hideVoiceCheck:SetChecked(settings.hideVoiceTab)
    hideVoiceCheck:SetScript("OnClick", function(self)
        settings.hideVoiceTab = self:GetChecked()
        Chat:SaveSettings()
        Chat:ApplyVoiceTabVisibility()
        Chat:RefreshChannelTabs()
    end)
    yOffset = yOffset - 30
    
    -- ========== CREATE NEW TABS SECTION ==========
    local customHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    customHeader:SetPoint("TOPLEFT", 0, yOffset)
    customHeader:SetText("|cffffd100Create New Tabs|r")
    yOffset = yOffset - 20
    
    -- Info text
    local infoText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    infoText:SetPoint("TOPLEFT", 0, yOffset)
    infoText:SetText("Right-click any tab to edit settings")
    infoText:SetTextColor(0.7, 0.7, 0.7)
    yOffset = yOffset - 20
    
    -- Create New Tab button (our dialog)
    local createBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    createBtn:SetPoint("TOPLEFT", 0, yOffset)
    createBtn:SetSize(140, 22)
    createBtn:SetText("New Tab (Quick)")
    createBtn:SetScript("OnClick", function()
        self:ShowCreateCustomTabDialog()
    end)
    
    -- Tooltip for our button
    createBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Create New Tab")
        GameTooltip:AddLine("Quick creation with channel presets", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    createBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    -- Cleanup button for extra tabs
    local cleanupBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    cleanupBtn:SetPoint("LEFT", createBtn, "RIGHT", 10, 0)
    cleanupBtn:SetSize(140, 22)
    cleanupBtn:SetText("Cleanup Extra Tabs")
    cleanupBtn:SetScript("OnClick", function()
        Chat:CleanupExtraChatFrames()
    end)
    cleanupBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Cleanup Extra Tabs")
        GameTooltip:AddLine("Closes chat frames beyond #10 that may cause errors", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    cleanupBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    yOffset = yOffset - 30
    
    -- ========== ACTIVE TABS SECTION ==========
    yOffset = yOffset - 10
    local activeHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    activeHeader:SetPoint("TOPLEFT", 0, yOffset)
    activeHeader:SetText("|cffffd100Active Chat Tabs|r")
    yOffset = yOffset - 20
    
    -- List all active chat frames with color options
    local foundTabs = 0
    for i = 1, NUM_CHAT_WINDOWS do
        local chatFrame = _G["ChatFrame" .. i]
        local chatTab = _G["ChatFrame" .. i .. "Tab"]
        
        if chatFrame and chatTab then
            local tabName = chatTab:GetText()
            if not tabName or tabName == "" then
                tabName = "Chat " .. i
            end
            
            -- Check if tab should be shown
            local isActive = (i == 1) or (chatTab:IsShown()) or (chatFrame.isDocked) or (i == 2)
            
            if isActive then
                foundTabs = foundTabs + 1
                
                -- Initialize settings for this tab
                settings.tabSettings[i] = settings.tabSettings[i] or {
                    customColor = nil,
                    useCustomColor = false
                }
                local tabSetting = settings.tabSettings[i]
                
                -- Tab row
                local rowFrame = CreateFrame("Frame", nil, content)
                rowFrame:SetPoint("TOPLEFT", 0, yOffset)
                rowFrame:SetSize(PANEL_WIDTH - 60, 28)
                
                -- Tab name label
                local nameLabel = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                nameLabel:SetPoint("LEFT", 0, 0)
                nameLabel:SetText(tabName)
                nameLabel:SetWidth(80)
                nameLabel:SetJustifyH("LEFT")
                
                -- Enable custom color checkbox
                local enableCheck = CreateFrame("CheckButton", nil, rowFrame, "UICheckButtonTemplate")
                enableCheck:SetPoint("LEFT", 85, 0)
                enableCheck:SetSize(20, 20)
                enableCheck:SetChecked(tabSetting.useCustomColor or false)
                enableCheck.tabIndex = i
                enableCheck:SetScript("OnClick", function(self)
                    settings.tabSettings[self.tabIndex].useCustomColor = self:GetChecked()
                    Chat:ApplyTabColors()
                end)
                
                -- Color swatch
                local color = tabSetting.customColor or {r = 0.2, g = 0.2, b = 0.3}
                if type(color) ~= "table" then
                    color = {r = 0.2, g = 0.2, b = 0.3}
                    tabSetting.customColor = color
                end
                
                local colorSwatch = CreateFrame("Button", nil, rowFrame)
                colorSwatch:SetPoint("LEFT", enableCheck, "RIGHT", 5, 0)
                colorSwatch:SetSize(24, 24)
                colorSwatch.tabIndex = i
                
                -- Border BEHIND
                local swatchBorder = colorSwatch:CreateTexture(nil, "BACKGROUND")
                swatchBorder:SetPoint("TOPLEFT", -2, 2)
                swatchBorder:SetPoint("BOTTOMRIGHT", 2, -2)
                swatchBorder:SetColorTexture(0.5, 0.5, 0.5, 1)
                
                -- Color ON TOP
                local swatchTex = colorSwatch:CreateTexture(nil, "ARTWORK")
                swatchTex:SetAllPoints()
                swatchTex:SetColorTexture(color.r or 0.2, color.g or 0.2, color.b or 0.3, 1)
                colorSwatch.tex = swatchTex
                
                colorSwatch:SetScript("OnClick", function(self)
                    local curColor = settings.tabSettings[self.tabIndex].customColor or {r = 0.2, g = 0.2, b = 0.3}
                    ColorPickerFrame:SetupColorPickerAndShow({
                        r = curColor.r or 0.2, g = curColor.g or 0.2, b = curColor.b or 0.3,
                        swatchFunc = function()
                            local newR, newG, newB = ColorPickerFrame:GetColorRGB()
                            settings.tabSettings[self.tabIndex].customColor = {r = newR, g = newG, b = newB}
                            self.tex:SetColorTexture(newR, newG, newB, 1)
                            Chat:ApplyTabColors()
                        end,
                        cancelFunc = function(prev)
                            settings.tabSettings[self.tabIndex].customColor = {r = prev.r, g = prev.g, b = prev.b}
                            self.tex:SetColorTexture(prev.r, prev.g, prev.b, 1)
                            Chat:ApplyTabColors()
                        end,
                    })
                end)
                
                -- Close tab button (only for non-essential tabs)
                if i > 2 then  -- Don't allow closing General or Combat Log
                    local closeBtn = CreateFrame("Button", nil, rowFrame)
                    closeBtn:SetPoint("LEFT", colorSwatch, "RIGHT", 10, 0)
                    closeBtn:SetSize(16, 16)
                    closeBtn:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
                    closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
                    closeBtn.chatFrameIndex = i
                    closeBtn:SetScript("OnClick", function(self)
                        local cf = _G["ChatFrame" .. self.chatFrameIndex]
                        if cf then
                            FCF_Close(cf)
                            C_Timer.After(0.2, function()
                                Chat:RefreshChannelTabs()
                                -- Rebuild panel
                                if chatPanels["channels"] then
                                    chatPanels["channels"]:Hide()
                                    chatPanels["channels"] = nil
                                    Chat:CreateChannelsPanel()
                                    chatPanels["channels"]:Show()
                                end
                            end)
                        end
                    end)
                    closeBtn:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetText("Close this tab")
                        GameTooltip:Show()
                    end)
                    closeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
                end
                
                yOffset = yOffset - 30
            end
        end
    end
    
    if foundTabs == 0 then
        local noTabsLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        noTabsLabel:SetPoint("TOPLEFT", 0, yOffset)
        noTabsLabel:SetText("No tabs available yet")
        noTabsLabel:SetTextColor(0.6, 0.6, 0.6)
        yOffset = yOffset - 25
    end
    
    -- Separator
    yOffset = yOffset - 10
    local sep1 = content:CreateTexture(nil, "ARTWORK")
    sep1:SetPoint("TOPLEFT", 0, yOffset)
    sep1:SetSize(PANEL_WIDTH - 60, 1)
    sep1:SetColorTexture(0.4, 0.4, 0.4, 1)
    yOffset = yOffset - 15
    
    -- ========== DEFAULT TAB COLORS SECTION ==========
    local defaultHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    defaultHeader:SetPoint("TOPLEFT", 0, yOffset)
    defaultHeader:SetText("|cffffd100Default Tab Colors|r")
    yOffset = yOffset - 25
    
    -- Unselected tab color
    local unselLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    unselLabel:SetPoint("TOPLEFT", 0, yOffset)
    unselLabel:SetText("Unselected:")
    
    settings.defaultTabColor = settings.defaultTabColor or {r = 0.15, g = 0.15, b = 0.15}
    local unselColor = settings.defaultTabColor
    
    local unselSwatch = CreateFrame("Button", nil, content)
    unselSwatch:SetPoint("LEFT", unselLabel, "RIGHT", 10, 0)
    unselSwatch:SetSize(24, 24)
    
    local unselBorder = unselSwatch:CreateTexture(nil, "BACKGROUND")
    unselBorder:SetPoint("TOPLEFT", -2, 2)
    unselBorder:SetPoint("BOTTOMRIGHT", 2, -2)
    unselBorder:SetColorTexture(0.5, 0.5, 0.5, 1)
    
    local unselTex = unselSwatch:CreateTexture(nil, "ARTWORK")
    unselTex:SetAllPoints()
    unselTex:SetColorTexture(unselColor.r, unselColor.g, unselColor.b, 1)
    unselSwatch.tex = unselTex
    
    unselSwatch:SetScript("OnClick", function(self)
        ColorPickerFrame:SetupColorPickerAndShow({
            r = unselColor.r, g = unselColor.g, b = unselColor.b,
            swatchFunc = function()
                local newR, newG, newB = ColorPickerFrame:GetColorRGB()
                settings.defaultTabColor = {r = newR, g = newG, b = newB}
                unselColor.r, unselColor.g, unselColor.b = newR, newG, newB
                self.tex:SetColorTexture(newR, newG, newB, 1)
                Chat:ApplyTabColors()
            end,
            cancelFunc = function(prev)
                settings.defaultTabColor = {r = prev.r, g = prev.g, b = prev.b}
                unselColor.r, unselColor.g, unselColor.b = prev.r, prev.g, prev.b
                self.tex:SetColorTexture(prev.r, prev.g, prev.b, 1)
                Chat:ApplyTabColors()
            end,
        })
    end)
    
    -- Selected color on same row
    local selLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    selLabel:SetPoint("LEFT", unselSwatch, "RIGHT", 20, 0)
    selLabel:SetText("Selected:")
    
    settings.selectedTabColor = settings.selectedTabColor or {r = 0.25, g = 0.25, b = 0.25}
    local selColor = settings.selectedTabColor
    
    local selSwatch = CreateFrame("Button", nil, content)
    selSwatch:SetPoint("LEFT", selLabel, "RIGHT", 10, 0)
    selSwatch:SetSize(24, 24)
    
    local selBorder = selSwatch:CreateTexture(nil, "BACKGROUND")
    selBorder:SetPoint("TOPLEFT", -2, 2)
    selBorder:SetPoint("BOTTOMRIGHT", 2, -2)
    selBorder:SetColorTexture(0.5, 0.5, 0.5, 1)
    
    local selTex = selSwatch:CreateTexture(nil, "ARTWORK")
    selTex:SetAllPoints()
    selTex:SetColorTexture(selColor.r, selColor.g, selColor.b, 1)
    selSwatch.tex = selTex
    
    selSwatch:SetScript("OnClick", function(self)
        ColorPickerFrame:SetupColorPickerAndShow({
            r = selColor.r, g = selColor.g, b = selColor.b,
            swatchFunc = function()
                local newR, newG, newB = ColorPickerFrame:GetColorRGB()
                settings.selectedTabColor = {r = newR, g = newG, b = newB}
                selColor.r, selColor.g, selColor.b = newR, newG, newB
                self.tex:SetColorTexture(newR, newG, newB, 1)
                Chat:ApplyTabColors()
            end,
            cancelFunc = function(prev)
                settings.selectedTabColor = {r = prev.r, g = prev.g, b = prev.b}
                selColor.r, selColor.g, selColor.b = prev.r, prev.g, prev.b
                self.tex:SetColorTexture(prev.r, prev.g, prev.b, 1)
                Chat:ApplyTabColors()
            end,
        })
    end)
end

-- ============================================================================
-- CUSTOM TAB DIALOGS
-- ============================================================================

local customTabDialog = nil

function Chat:ShowCreateCustomTabDialog()
    self:ShowCustomTabDialog(nil)  -- nil = create new
end

function Chat:ShowEditCustomTabDialog(tabIndex)
    self:ShowCustomTabDialog(tabIndex)  -- index = edit existing
end

function Chat:ShowCustomTabDialog(editIndex)
    local settings = self:GetSettings()
    local isEdit = (editIndex ~= nil)
    local editTab = isEdit and settings.customTabs[editIndex] or nil
    
    -- Create or show dialog
    if not customTabDialog then
        local dialog = CreateFrame("Frame", "TweaksUIChatCustomTabDialog", UIParent, "BackdropTemplate")
        dialog:SetSize(320, 400)
        dialog:SetPoint("CENTER")
        dialog:SetBackdrop(darkBackdrop)
        dialog:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
        dialog:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        dialog:SetFrameStrata("DIALOG")
        dialog:SetFrameLevel(100)
        dialog:EnableMouse(true)
        dialog:SetMovable(true)
        dialog:RegisterForDrag("LeftButton")
        dialog:SetScript("OnDragStart", dialog.StartMoving)
        dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
        
        -- Title
        local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -12)
        title:SetText("Create Custom Tab")
        dialog.title = title
        
        -- Close button
        local closeBtn = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", -3, -3)
        closeBtn:SetScript("OnClick", function() dialog:Hide() end)
        
        -- Tab name input
        local nameLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        nameLabel:SetPoint("TOPLEFT", 15, -45)
        nameLabel:SetText("Tab Name:")
        
        local nameInput = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
        nameInput:SetPoint("TOPLEFT", 15, -60)
        nameInput:SetSize(200, 25)
        nameInput:SetAutoFocus(false)
        dialog.nameInput = nameInput
        
        -- Channel checkboxes
        local channelLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        channelLabel:SetPoint("TOPLEFT", 15, -95)
        channelLabel:SetText("Show messages from:")
        
        dialog.channelChecks = {}
        local yPos = -115
        for i, channelInfo in ipairs(CHANNEL_TYPES) do
            local check = CreateFrame("CheckButton", nil, dialog, "UICheckButtonTemplate")
            check:SetPoint("TOPLEFT", 15 + ((i-1) % 2) * 140, yPos)
            check:SetSize(24, 24)
            check.text:SetText(channelInfo.name)
            check.channelKey = channelInfo.key
            dialog.channelChecks[channelInfo.key] = check
            
            if i % 2 == 0 then
                yPos = yPos - 25
            end
        end
        
        -- Tab color
        local colorLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        colorLabel:SetPoint("TOPLEFT", 15, yPos - 15)
        colorLabel:SetText("Tab Color:")
        
        local colorSwatch = CreateFrame("Button", nil, dialog)
        colorSwatch:SetPoint("LEFT", colorLabel, "RIGHT", 10, 0)
        colorSwatch:SetSize(24, 24)
        dialog.colorSwatch = colorSwatch
        dialog.tabColor = {r = 0.2, g = 0.3, b = 0.4}
        
        local swatchBorder = colorSwatch:CreateTexture(nil, "BACKGROUND")
        swatchBorder:SetPoint("TOPLEFT", -2, 2)
        swatchBorder:SetPoint("BOTTOMRIGHT", 2, -2)
        swatchBorder:SetColorTexture(0.5, 0.5, 0.5, 1)
        
        local swatchTex = colorSwatch:CreateTexture(nil, "ARTWORK")
        swatchTex:SetAllPoints()
        swatchTex:SetColorTexture(0.2, 0.3, 0.4, 1)
        colorSwatch.tex = swatchTex
        
        colorSwatch:SetScript("OnClick", function(self)
            local c = dialog.tabColor
            ColorPickerFrame:SetupColorPickerAndShow({
                r = c.r, g = c.g, b = c.b,
                swatchFunc = function()
                    local r, g, b = ColorPickerFrame:GetColorRGB()
                    dialog.tabColor = {r = r, g = g, b = b}
                    self.tex:SetColorTexture(r, g, b, 1)
                end,
                cancelFunc = function(prev)
                    dialog.tabColor = {r = prev.r, g = prev.g, b = prev.b}
                    self.tex:SetColorTexture(prev.r, prev.g, prev.b, 1)
                end,
            })
        end)
        
        -- Save button
        local saveBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
        saveBtn:SetPoint("BOTTOMLEFT", 15, 15)
        saveBtn:SetSize(100, 26)
        saveBtn:SetText("Save")
        saveBtn:SetScript("OnClick", function()
            local name = dialog.nameInput:GetText()
            if not name or name == "" then
                name = "Custom"
            end
            
            -- Collect selected channels
            local channels = {}
            for key, check in pairs(dialog.channelChecks) do
                if check:GetChecked() then
                    table.insert(channels, key)
                end
            end
            
            if #channels == 0 then
                TweaksUI:Print("Please select at least one channel type.")
                return
            end
            
            -- Create a new Blizzard chat window
            local newFrame = FCF_OpenNewWindow(name)
            if newFrame then
                local frameIndex = newFrame:GetID()
                
                -- Clear default message groups and set up our selected ones
                ChatFrame_RemoveAllMessageGroups(newFrame)
                ChatFrame_RemoveAllChannels(newFrame)
                
                -- Disable whispers/BN conversations (prevents voice chat tab)
                -- These are enabled by default in FCF_OpenNewWindow
                if ChatFrame_ReceiveAllPrivateMessages then
                    -- Don't call this - it adds whispers which we may not want
                end
                if ChatFrame_ReceiveAllBNConversations then
                    -- Don't call this - it adds BN conversations
                end
                
                -- Add selected message groups
                for _, channelKey in ipairs(channels) do
                    for _, channelInfo in ipairs(CHANNEL_TYPES) do
                        if channelInfo.key == channelKey then
                            for _, event in ipairs(channelInfo.events) do
                                -- Convert event name to message group
                                local group = event:gsub("CHAT_MSG_", "")
                                ChatFrame_AddMessageGroup(newFrame, group)
                            end
                        end
                    end
                end
                
                -- Dock the frame properly
                FCF_DockFrame(newFrame, #FCFDock_GetChatFrames(GENERAL_CHAT_DOCK) + 1, true)
                
                -- Store our custom settings for this tab
                settings.tabSettings[frameIndex] = settings.tabSettings[frameIndex] or {}
                settings.tabSettings[frameIndex].customColor = dialog.tabColor
                settings.tabSettings[frameIndex].useCustomColor = true
                
                TweaksUI:Print("Created new chat tab: " .. name)
            else
                TweaksUI:Print("Could not create new tab - maximum tabs reached")
            end
            
            dialog:Hide()
            
            -- Delay to let Blizzard's system update
            C_Timer.After(0.2, function()
                Chat:RefreshChannelTabs()
                
                -- Rebuild channels panel
                if chatPanels["channels"] then
                    chatPanels["channels"]:Hide()
                    chatPanels["channels"] = nil
                    Chat:CreateChannelsPanel()
                    chatPanels["channels"]:Show()
                end
            end)
        end)
        
        -- Cancel button
        local cancelBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
        cancelBtn:SetPoint("BOTTOMRIGHT", -15, 15)
        cancelBtn:SetSize(100, 26)
        cancelBtn:SetText("Cancel")
        cancelBtn:SetScript("OnClick", function() dialog:Hide() end)
        
        customTabDialog = dialog
    end
    
    -- Reset/populate dialog
    local dialog = customTabDialog
    
    if isEdit and editTab then
        dialog.title:SetText("Edit Custom Tab")
        dialog.nameInput:SetText(editTab.name or "")
        dialog.editIndex = editIndex
        
        -- Set channel checkboxes
        for key, check in pairs(dialog.channelChecks) do
            check:SetChecked(false)
        end
        for _, channelKey in ipairs(editTab.channels or {}) do
            if dialog.channelChecks[channelKey] then
                dialog.channelChecks[channelKey]:SetChecked(true)
            end
        end
        
        -- Set color
        local c = editTab.color or {r = 0.2, g = 0.3, b = 0.4}
        dialog.tabColor = {r = c.r, g = c.g, b = c.b}
        dialog.colorSwatch.tex:SetColorTexture(c.r, c.g, c.b, 1)
    else
        dialog.title:SetText("Create Custom Tab")
        dialog.nameInput:SetText("")
        dialog.editIndex = nil
        
        -- Clear checkboxes
        for _, check in pairs(dialog.channelChecks) do
            check:SetChecked(false)
        end
        
        -- Default color
        dialog.tabColor = {r = 0.2, g = 0.3, b = 0.4}
        dialog.colorSwatch.tex:SetColorTexture(0.2, 0.3, 0.4, 1)
    end
    
    dialog:Show()
end

function Chat:ApplyTabColors()
    if not customChatFrame or not customChatFrame.tabBar then return end
    
    local selectedIndex = customChatFrame.activeChatFrameIndex or 1
    self:UpdateTabVisuals(selectedIndex)
end

-- ============================================================================
-- TAB SETTINGS DIALOG (Right-click on tabs)
-- ============================================================================

local tabSettingsDialog = nil

function Chat:ShowTabSettingsDialog(chatFrameIndex)
    local chatFrame = _G["ChatFrame" .. chatFrameIndex]
    local chatTab = _G["ChatFrame" .. chatFrameIndex .. "Tab"]
    if not chatFrame then return end
    
    local settings = self:GetSettings()
    local tabName = chatTab and chatTab:GetText() or ("Chat " .. chatFrameIndex)
    
    -- Create dialog if needed
    if not tabSettingsDialog then
        local dialog = CreateFrame("Frame", "TweaksUIChatTabSettingsDialog", UIParent, "BackdropTemplate")
        dialog:SetSize(340, 480)
        dialog:SetPoint("CENTER")
        dialog:SetBackdrop(darkBackdrop)
        dialog:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
        dialog:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        dialog:SetFrameStrata("DIALOG")
        dialog:SetFrameLevel(100)
        dialog:EnableMouse(true)
        dialog:SetMovable(true)
        dialog:RegisterForDrag("LeftButton")
        dialog:SetScript("OnDragStart", dialog.StartMoving)
        dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
        dialog:SetClampedToScreen(true)
        
        -- Title
        local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -12)
        title:SetText("Tab Settings")
        dialog.title = title
        
        -- Close button
        local closeBtn = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", -3, -3)
        closeBtn:SetScript("OnClick", function() dialog:Hide() end)
        
        -- Tab name input
        local nameLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        nameLabel:SetPoint("TOPLEFT", 15, -45)
        nameLabel:SetText("Tab Name:")
        
        local nameInput = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
        nameInput:SetPoint("TOPLEFT", 15, -62)
        nameInput:SetSize(200, 22)
        nameInput:SetAutoFocus(false)
        dialog.nameInput = nameInput
        
        -- Message types section
        local msgLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        msgLabel:SetPoint("TOPLEFT", 15, -95)
        msgLabel:SetText("Show messages from:")
        
        -- Create checkboxes for all message types
        dialog.messageChecks = {}
        local messageTypes = {
            {group = "SAY", name = "Say"},
            {group = "YELL", name = "Yell"},
            {group = "WHISPER", name = "Whisper"},
            {group = "PARTY", name = "Party"},
            {group = "PARTY_LEADER", name = "Party Leader"},
            {group = "RAID", name = "Raid"},
            {group = "RAID_LEADER", name = "Raid Leader"},
            {group = "RAID_WARNING", name = "Raid Warning"},
            {group = "GUILD", name = "Guild"},
            {group = "OFFICER", name = "Officer"},
            {group = "INSTANCE_CHAT", name = "Instance"},
            {group = "EMOTE", name = "Emote"},
            {group = "SYSTEM", name = "System"},
            {group = "LOOT", name = "Loot"},
            {group = "MONEY", name = "Money"},
            {group = "SKILL", name = "Skill"},
            {group = "CHANNEL", name = "Channels"},
        }
        
        local yPos = -115
        for i, msgType in ipairs(messageTypes) do
            local check = CreateFrame("CheckButton", nil, dialog, "UICheckButtonTemplate")
            check:SetPoint("TOPLEFT", 15 + ((i-1) % 2) * 155, yPos)
            check:SetSize(22, 22)
            check.text:SetText(msgType.name)
            check.text:SetFontObject("GameFontHighlightSmall")
            check.messageGroup = msgType.group
            dialog.messageChecks[msgType.group] = check
            
            if i % 2 == 0 then
                yPos = yPos - 22
            end
        end
        
        -- Tab color section
        yPos = yPos - 30
        local colorLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        colorLabel:SetPoint("TOPLEFT", 15, yPos)
        colorLabel:SetText("Tab Background Color:")
        
        local useColorCheck = CreateFrame("CheckButton", nil, dialog, "UICheckButtonTemplate")
        useColorCheck:SetPoint("TOPLEFT", 15, yPos - 20)
        useColorCheck:SetSize(22, 22)
        useColorCheck.text:SetText("Use custom color")
        dialog.useColorCheck = useColorCheck
        
        local colorSwatch = CreateFrame("Button", nil, dialog)
        colorSwatch:SetPoint("LEFT", useColorCheck, "RIGHT", 120, 0)
        colorSwatch:SetSize(24, 24)
        
        local swatchBorder = colorSwatch:CreateTexture(nil, "BACKGROUND")
        swatchBorder:SetPoint("TOPLEFT", -2, 2)
        swatchBorder:SetPoint("BOTTOMRIGHT", 2, -2)
        swatchBorder:SetColorTexture(0.5, 0.5, 0.5, 1)
        
        local swatchTex = colorSwatch:CreateTexture(nil, "ARTWORK")
        swatchTex:SetAllPoints()
        swatchTex:SetColorTexture(0.2, 0.3, 0.4, 1)
        colorSwatch.tex = swatchTex
        dialog.colorSwatch = colorSwatch
        dialog.tabColor = {r = 0.2, g = 0.3, b = 0.4}
        
        colorSwatch:SetScript("OnClick", function(self)
            local c = dialog.tabColor
            ColorPickerFrame:SetupColorPickerAndShow({
                r = c.r, g = c.g, b = c.b,
                swatchFunc = function()
                    local r, g, b = ColorPickerFrame:GetColorRGB()
                    dialog.tabColor = {r = r, g = g, b = b}
                    self.tex:SetColorTexture(r, g, b, 1)
                end,
                cancelFunc = function(prev)
                    dialog.tabColor = {r = prev.r, g = prev.g, b = prev.b}
                    self.tex:SetColorTexture(prev.r, prev.g, prev.b, 1)
                end,
            })
        end)
        
        -- Save button
        local saveBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
        saveBtn:SetPoint("BOTTOMLEFT", 15, 50)
        saveBtn:SetSize(100, 26)
        saveBtn:SetText("Save")
        saveBtn:SetScript("OnClick", function()
            Chat:SaveTabSettings()
        end)
        
        -- Close tab button (only for non-essential tabs)
        local closeTabBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
        closeTabBtn:SetPoint("BOTTOM", 0, 50)
        closeTabBtn:SetSize(100, 26)
        closeTabBtn:SetText("Close Tab")
        closeTabBtn:SetScript("OnClick", function()
            local idx = dialog.chatFrameIndex
            if idx and idx > 2 then
                local cf = _G["ChatFrame" .. idx]
                if cf then
                    FCF_Close(cf)
                    dialog:Hide()
                    C_Timer.After(0.2, function()
                        Chat:RefreshChannelTabs()
                    end)
                end
            else
                TweaksUI:Print("Cannot close General or Combat Log tabs")
            end
        end)
        dialog.closeTabBtn = closeTabBtn
        
        -- Cancel button
        local cancelBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
        cancelBtn:SetPoint("BOTTOMRIGHT", -15, 50)
        cancelBtn:SetSize(100, 26)
        cancelBtn:SetText("Cancel")
        cancelBtn:SetScript("OnClick", function() dialog:Hide() end)
        
        -- Info text
        local infoText = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        infoText:SetPoint("BOTTOM", 0, 20)
        infoText:SetText("Changes are applied to the Blizzard chat system")
        infoText:SetTextColor(0.6, 0.6, 0.6)
        
        tabSettingsDialog = dialog
    end
    
    local dialog = tabSettingsDialog
    dialog.chatFrameIndex = chatFrameIndex
    
    -- Set title
    dialog.title:SetText("Settings: " .. tabName)
    
    -- Set name
    dialog.nameInput:SetText(tabName)
    
    -- Get current message groups for this chat frame
    for group, check in pairs(dialog.messageChecks) do
        local isRegistered = false
        -- Check if this message group is registered for this chat frame
        local messageTypeList = chatFrame.messageTypeList
        if messageTypeList then
            for _, registeredGroup in ipairs(messageTypeList) do
                if registeredGroup == group then
                    isRegistered = true
                    break
                end
            end
        end
        check:SetChecked(isRegistered)
    end
    
    -- Set color settings
    settings.tabSettings[chatFrameIndex] = settings.tabSettings[chatFrameIndex] or {}
    local tabSetting = settings.tabSettings[chatFrameIndex]
    
    dialog.useColorCheck:SetChecked(tabSetting.useCustomColor or false)
    
    local color = tabSetting.customColor or {r = 0.2, g = 0.3, b = 0.4}
    if type(color) ~= "table" then
        color = {r = 0.2, g = 0.3, b = 0.4}
    end
    dialog.tabColor = {r = color.r or 0.2, g = color.g or 0.3, b = color.b or 0.4}
    dialog.colorSwatch.tex:SetColorTexture(dialog.tabColor.r, dialog.tabColor.g, dialog.tabColor.b, 1)
    
    -- Show/hide close tab button based on tab index
    if chatFrameIndex <= 2 then
        dialog.closeTabBtn:Hide()
    else
        dialog.closeTabBtn:Show()
    end
    
    -- Grey out options for Combat Log (tab 2) since we just pass through Blizzard's frame
    local isCombatLog = (chatFrameIndex == 2)
    
    -- Disable/enable name input
    dialog.nameInput:SetEnabled(not isCombatLog)
    if isCombatLog then
        dialog.nameInput:SetTextColor(0.5, 0.5, 0.5)
    else
        dialog.nameInput:SetTextColor(1, 1, 1)
    end
    
    -- Disable/enable message checkboxes
    for group, check in pairs(dialog.messageChecks) do
        check:SetEnabled(not isCombatLog)
        if isCombatLog then
            check.text:SetTextColor(0.5, 0.5, 0.5)
        else
            check.text:SetTextColor(1, 0.82, 0)  -- Gold color like normal
        end
    end
    
    -- Store whether this is combat log for save function
    dialog.isCombatLog = isCombatLog
    
    -- Update title to indicate if read-only
    if isCombatLog then
        dialog.title:SetText("Settings: " .. tabName .. " |cff888888(Color only)|r")
    else
        dialog.title:SetText("Settings: " .. tabName)
    end
    
    dialog:Show()
end

function Chat:SaveTabSettings()
    local dialog = tabSettingsDialog
    if not dialog or not dialog.chatFrameIndex then return end
    
    local chatFrameIndex = dialog.chatFrameIndex
    local chatFrame = _G["ChatFrame" .. chatFrameIndex]
    local chatTab = _G["ChatFrame" .. chatFrameIndex .. "Tab"]
    if not chatFrame then return end
    
    local settings = self:GetSettings()
    
    -- Only update name and message groups if not Combat Log
    if not dialog.isCombatLog then
        -- Update tab name
        local newName = dialog.nameInput:GetText()
        if newName and newName ~= "" then
            FCF_SetWindowName(chatFrame, newName)
        end
        
        -- Update message groups
        -- First remove all current groups
        ChatFrame_RemoveAllMessageGroups(chatFrame)
        
        -- Then add the checked ones
        for group, check in pairs(dialog.messageChecks) do
            if check:GetChecked() then
                ChatFrame_AddMessageGroup(chatFrame, group)
            end
        end
    end
    
    -- Update color settings (always allowed)
    settings.tabSettings[chatFrameIndex] = settings.tabSettings[chatFrameIndex] or {}
    settings.tabSettings[chatFrameIndex].useCustomColor = dialog.useColorCheck:GetChecked()
    settings.tabSettings[chatFrameIndex].customColor = dialog.tabColor
    
    -- Apply colors
    self:ApplyTabColors()
    
    -- Refresh our tabs
    self:RefreshChannelTabs()
    
    dialog:Hide()
    TweaksUI:Print("Tab settings saved")
end


-- ============================================================================
-- APPLY SETTINGS FUNCTIONS
-- ============================================================================

function Chat:ApplyBackgroundSettings()
    if not customChatFrame then return end
    local settings = self:GetSettings()
    
    -- Ensure bgColor is a table with valid values
    local bgColor = settings.bgColor
    if type(bgColor) ~= "table" then
        bgColor = {r = 0, g = 0, b = 0}
    end
    local r, g, b = bgColor.r or 0, bgColor.g or 0, bgColor.b or 0
    local bgAlpha = settings.bgAlpha or 0.7
    
    if settings.showBackground ~= false then
        if customChatFrame.bgFrame then
            -- Don't override Combat Log's special opacity
            if customChatFrame.activeChatFrameIndex ~= 2 then
                customChatFrame.bgFrame:SetBackdropColor(r, g, b, bgAlpha)
            end
        end
    else
        if customChatFrame.bgFrame then
            customChatFrame.bgFrame:SetBackdropColor(0, 0, 0, 0)
        end
    end
    
    -- Handle border
    if customChatFrame.bgFrame and customChatFrame.bgFrame.SetBackdropBorderColor then
        if settings.showBorder ~= false then
            customChatFrame.bgFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        else
            customChatFrame.bgFrame:SetBackdropBorderColor(0, 0, 0, 0)
        end
    end
end

function Chat:ApplyFontSettings()
    if not customChatFrame or not customChatFrame.messageFrame then return end
    local settings = self:GetSettings()
    
    -- Use Media system if fontName is set, otherwise fall back to fontPath
    local fontPath
    if settings.fontName then
        fontPath = TweaksUI.Media:GetFontWithGlobal(settings.fontName)
    else
        fontPath = settings.fontPath or "Fonts\\FRIZQT__.TTF"
    end
    local fontSize = settings.fontSize or 14
    local fontOutline = TweaksUI.Media:GetOutlineWithGlobal(settings.fontOutline)
    
    customChatFrame.messageFrame:SetFont(fontPath, fontSize, fontOutline)
end

function Chat:ApplyChannelColors()
    local settings = self:GetSettings()
    if not settings.channelColors then return end
    
    -- Map our keys to Blizzard's chat type names
    local chatTypeMap = {
        SAY = "SAY",
        YELL = "YELL",
        WHISPER = "WHISPER",
        PARTY = "PARTY",
        RAID = "RAID",
        GUILD = "GUILD",
        OFFICER = "OFFICER",
        INSTANCE_CHAT = "INSTANCE_CHAT",
        CHANNEL = "CHANNEL",
        EMOTE = "EMOTE",
        SYSTEM = "SYSTEM",
    }
    
    for key, color in pairs(settings.channelColors) do
        if type(color) == "table" and color.r then
            local chatType = chatTypeMap[key]
            if chatType then
                -- Use Blizzard's API to change the chat color
                ChangeChatColor(chatType, color.r, color.g, color.b)
            end
            
            -- Also handle incoming whispers
            if key == "WHISPER" then
                ChangeChatColor("WHISPER_INFORM", color.r, color.g, color.b)
            end
            
            -- Handle raid subtypes
            if key == "RAID" then
                ChangeChatColor("RAID_LEADER", color.r, color.g, color.b)
                ChangeChatColor("RAID_WARNING", color.r, color.g, color.b)
            end
            
            -- Handle party subtypes
            if key == "PARTY" then
                ChangeChatColor("PARTY_LEADER", color.r, color.g, color.b)
            end
            
            -- Handle instance subtypes
            if key == "INSTANCE_CHAT" then
                ChangeChatColor("INSTANCE_CHAT_LEADER", color.r, color.g, color.b)
            end
        end
    end
end

function Chat:ApplyTimestampSettings()
    local settings = self:GetSettings()
    
    -- We handle timestamps ourselves in FormatMessageWithTimestamp
    -- Disable Blizzard's timestamps to avoid duplicates
    SetCVar("showTimestamps", "none")
    
    -- Note: New messages will automatically get timestamps via FormatMessageWithTimestamp
    -- Existing messages in the frame won't be updated (would need to reload chat)
end

-- ============================================================================
-- MESSAGE FADING
-- ============================================================================

local fadeTimers = {}

function Chat:SetupMessageFading()
    local settings = self:GetSettings()
    if not settings.enableFading then return end
    
    -- Hook into message display to track fade times
    if customChatFrame and customChatFrame.messageFrame then
        local messageFrame = customChatFrame.messageFrame
        
        -- Set up fading
        messageFrame:SetFading(settings.enableFading)
        messageFrame:SetTimeVisible(settings.fadeTime or 120)
        messageFrame:SetFadeDuration(settings.fadeDuration or 10)
    end
end

function Chat:ApplyFadingSettings()
    local settings = self:GetSettings()
    
    if customChatFrame and customChatFrame.messageFrame then
        local messageFrame = customChatFrame.messageFrame
        messageFrame:SetFading(settings.enableFading)
        if settings.enableFading then
            messageFrame:SetTimeVisible(settings.fadeTime or 120)
            messageFrame:SetFadeDuration(settings.fadeDuration or 10)
        end
    end
end

-- ============================================================================
-- URL DETECTION AND HANDLING
-- ============================================================================

local URL_PATTERNS = {
    -- Standard URLs
    "https?://[%w%.%-_/%%%?&=#+~:;,@!%$%(%)%*]+",
    -- www URLs
    "www%.[%w%.%-_/%%%?&=#+~:;,@!%$%(%)%*]+",
    -- IP addresses with port
    "%d+%.%d+%.%d+%.%d+:%d+",
    -- Simple domain patterns
    "[%w%-]+%.[%w%-]+%.%w+",
}

function Chat:FormatURLs(text)
    local settings = self:GetSettings()
    if not settings.enableURLs then return text end
    if not text or type(text) ~= "string" then return text end
    
    local urlColor = settings.urlColor or { r = 0.5, g = 0.7, b = 1.0 }
    local colorCode = string.format("|cff%02x%02x%02x", 
        math.floor(urlColor.r * 255), 
        math.floor(urlColor.g * 255), 
        math.floor(urlColor.b * 255))
    
    -- Track URLs we've already processed to avoid double-processing
    local processed = {}
    
    -- Use pcall to safely handle string manipulation (in case of secret values)
    local success, result = pcall(function()
        local newText = text
        for _, pattern in ipairs(URL_PATTERNS) do
            newText = newText:gsub("(" .. pattern .. ")", function(url)
                -- Skip if already processed or if it's inside a hyperlink
                if processed[url] then return url end
                processed[url] = true
                
                -- Create a clickable hyperlink
                -- Format: |Hurl:theactualurl|h[display text]|h
                return string.format("%s|Hurl:%s|h[%s]|h|r", colorCode, url, url)
            end)
        end
        return newText
    end)
    
    if success then
        return result
    else
        return text  -- Return original if formatting failed
    end
end

function Chat:HandleURLClick(url)
    -- Show a popup to copy the URL
    StaticPopupDialogs["TWEAKSUI_URL_COPY"] = {
        text = "Copy URL (Ctrl+C):",
        button1 = "Close",
        hasEditBox = true,
        editBoxWidth = 350,
        OnShow = function(self, data)
            self.EditBox:SetText(data)
            self.EditBox:HighlightText()
            self.EditBox:SetFocus()
        end,
        EditBoxOnEnterPressed = function(self)
            self:GetParent():Hide()
        end,
        EditBoxOnEscapePressed = function(self)
            self:GetParent():Hide()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("TWEAKSUI_URL_COPY", nil, nil, url)
end

-- ============================================================================
-- CLASS COLORED NAMES
-- ============================================================================

local CLASS_COLORS = RAID_CLASS_COLORS or {}

function Chat:GetClassColor(name, realm)
    -- Try to get class from various sources
    local class = nil
    
    -- Check if in group/raid
    if IsInGroup() then
        for i = 1, GetNumGroupMembers() do
            local unit = IsInRaid() and "raid"..i or "party"..i
            local unitName, unitRealm = UnitName(unit)
            if unitName == name then
                _, class = UnitClass(unit)
                break
            end
        end
    end
    
    -- Check guild roster
    if not class and IsInGuild() then
        local numMembers = GetNumGuildMembers()
        for i = 1, numMembers do
            local guildName, _, _, _, _, _, _, _, _, _, guildClass = GetGuildRosterInfo(i)
            if guildName then
                local shortName = Ambiguate(guildName, "short")
                if shortName == name then
                    class = guildClass
                    break
                end
            end
        end
    end
    
    -- Check friends
    if not class then
        local numFriends = C_FriendList.GetNumFriends()
        for i = 1, numFriends do
            local info = C_FriendList.GetFriendInfoByIndex(i)
            if info and info.name == name then
                class = info.className
                break
            end
        end
    end
    
    if class and CLASS_COLORS[class] then
        local c = CLASS_COLORS[class]
        return string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
    end
    
    return nil
end

function Chat:ColorPlayerName(name, text)
    local settings = self:GetSettings()
    if not settings.enableClassColors then return text end
    
    -- Check if name and text are valid strings (not secret values)
    if not name or type(name) ~= "string" then return text end
    if not text or type(text) ~= "string" then return text end
    
    local colorCode = self:GetClassColor(name)
    if colorCode then
        -- Use pcall to safely handle string operations
        local success, result = pcall(function()
            -- Replace the player name with colored version
            local pattern = "(%[?)(" .. name:gsub("%-", "%%-") .. ")(%]?)"
            return text:gsub(pattern, function(pre, n, post)
                return pre .. colorCode .. n .. "|r" .. post
            end)
        end)
        
        if success then
            return result
        end
    end
    
    return text
end

-- ============================================================================
-- SHORT CHANNEL NAMES
-- ============================================================================

local CHANNEL_ABBREVS = {
    ["General"] = "G",
    ["Trade"] = "T",
    ["LocalDefense"] = "LD",
    ["LookingForGroup"] = "LFG",
    ["WorldDefense"] = "WD",
    ["GuildRecruitment"] = "GR",
    ["Services"] = "S",
    ["NewcomerChat"] = "NC",
}

function Chat:ShortenChannelName(text)
    local settings = self:GetSettings()
    if not settings.enableShortChannels then return text end
    
    -- Check if text is a secret value (can't be manipulated)
    if text == nil then return text end
    if type(text) ~= "string" then return text end
    
    -- Use pcall to safely handle any secret value issues
    local success, result = pcall(function()
        -- Shorten numbered channels: [1. General] -> [1]
        local newText = text:gsub("%[(%d+)%. [^%]]+%]", "[%1]")
        
        -- Also handle named channels without numbers
        for long, short in pairs(CHANNEL_ABBREVS) do
            newText = newText:gsub("%[" .. long .. "%]", "[" .. short .. "]")
        end
        
        return newText
    end)
    
    if success then
        return result
    else
        return text  -- Return original if manipulation failed
    end
end

-- ============================================================================
-- STICKY CHAT
-- ============================================================================

function Chat:SetupStickyChat()
    local settings = self:GetSettings()
    if not settings.enableStickyChat then return end
    
    local chatModule = self
    
    -- Hook ChatEdit_UpdateHeader to save chat type changes
    hooksecurefunc("ChatEdit_UpdateHeader", function(editBox)
        if editBox and editBox.chatType and editBox.chatType ~= "" then
            -- Save the chat type
            settings.lastChatType = editBox.chatType
            -- Also save target for whispers
            if editBox.chatType == "WHISPER" and editBox.tellTarget then
                settings.lastWhisperTarget = editBox.tellTarget
            end
        end
    end)
    
    -- Hook ChatEdit_ActivateChat to restore on activation
    hooksecurefunc("ChatEdit_ActivateChat", function(editBox)
        if not settings.enableStickyChat then return end
        if not editBox then return end
        
        -- Small delay to let default behavior complete first
        C_Timer.After(0.01, function()
            if editBox and editBox:IsShown() then
                -- Only restore if it would default to SAY
                if editBox.chatType == "SAY" and settings.lastChatType and settings.lastChatType ~= "SAY" then
                    chatModule:RestoreStickyChat(editBox)
                end
            end
        end)
    end)
end

function Chat:RestoreStickyChat(editBox)
    local settings = self:GetSettings()
    if not settings.enableStickyChat then return end
    if not editBox then return end
    
    local chatType = settings.lastChatType
    if not chatType or chatType == "" then return end
    
    -- Check if this chat type is valid
    if not ChatTypeInfo[chatType] then return end
    
    -- Set the chat type
    editBox:SetAttribute("chatType", chatType)
    
    -- For whispers, also restore the target
    if chatType == "WHISPER" and settings.lastWhisperTarget then
        editBox:SetAttribute("tellTarget", settings.lastWhisperTarget)
    end
    
    -- Update the header display
    ChatEdit_UpdateHeader(editBox)
end

-- ============================================================================
-- CLICK ACTIONS (Alt-Invite, Shift-Copy)
-- ============================================================================

function Chat:SetupClickActions()
    local settings = self:GetSettings()
    
    -- Hook player link clicks
    local origSetItemRef = SetItemRef
    SetItemRef = function(link, text, button, chatFrame)
        local linkType, value = link:match("^([^:]+):(.+)")
        
        if linkType == "player" then
            local name = value:match("([^:]+)")
            
            -- Alt-click to invite
            if settings.enableAltInvite and IsAltKeyDown() then
                C_PartyInfo.InviteUnit(name)
                return
            end
            
            -- Shift-click to copy name
            if settings.enableShiftCopy and IsShiftKeyDown() then
                local editBox = ChatFrame1EditBox
                if editBox and editBox:IsShown() then
                    editBox:Insert(name)
                else
                    -- Copy to clipboard via popup
                    Chat:ShowCopyNamePopup(name)
                end
                return
            end
        end
        
        return origSetItemRef(link, text, button, chatFrame)
    end
end

function Chat:ShowCopyNamePopup(name)
    StaticPopupDialogs["TWEAKSUI_COPY_NAME"] = {
        text = "Copy Name (Ctrl+C):",
        button1 = "Close",
        hasEditBox = true,
        editBoxWidth = 200,
        OnShow = function(self, data)
            self.EditBox:SetText(data)
            self.EditBox:HighlightText()
            self.EditBox:SetFocus()
        end,
        EditBoxOnEnterPressed = function(self)
            self:GetParent():Hide()
        end,
        EditBoxOnEscapePressed = function(self)
            self:GetParent():Hide()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("TWEAKSUI_COPY_NAME", nil, nil, name)
end

-- ============================================================================
-- MENTION ALERTS
-- ============================================================================

function Chat:CheckForMention(text)
    local settings = self:GetSettings()
    if not settings.enableMentionAlerts then return false end
    
    -- Check if text is a valid string (not a secret value)
    if not text or type(text) ~= "string" then return false end
    
    -- Use pcall to safely handle string operations (secret values can cause issues)
    local success, result = pcall(function()
        local lowerText = text:lower()
        
        -- Check for player name (get dynamically, not at load time)
        local playerName = UnitName("player")
        if playerName then
            local lowerPlayerName = playerName:lower()
            -- Use plain text search (4th arg = true) to avoid pattern matching issues
            if lowerText:find(lowerPlayerName, 1, true) then
                TweaksUI:PrintDebug("Chat: Mention found - player name '" .. playerName .. "' in: " .. text:sub(1, 50))
                return true
            end
        end
        
        -- Check custom mention words
        local mentionWords = settings.mentionWords or {}
        for _, word in ipairs(mentionWords) do
            if word and word ~= "" then
                -- Use plain text search
                if lowerText:find(word:lower(), 1, true) then
                    TweaksUI:PrintDebug("Chat: Mention found - custom word '" .. word .. "' in: " .. text:sub(1, 50))
                    return true
                end
            end
        end
        
        return false
    end)
    
    if success then
        return result
    else
        return false  -- On error, assume no mention
    end
end

function Chat:TriggerMentionAlert()
    local settings = self:GetSettings()
    
    -- Blizzard SOUNDKIT options table
    local BLIZZARD_SOUNDS = {
        TELL_MESSAGE = SOUNDKIT.TELL_MESSAGE,
        RAID_WARNING = SOUNDKIT.RAID_WARNING,
        READY_CHECK = SOUNDKIT.READY_CHECK,
        PVP_THROUGH_QUEUE = SOUNDKIT.PVP_THROUGH_QUEUE,
        LFG_REWARDS = SOUNDKIT.LFG_REWARDS,
        ALARM_CLOCK_WARNING_2 = SOUNDKIT.ALARM_CLOCK_WARNING_2,
        ALARM_CLOCK_WARNING_3 = SOUNDKIT.ALARM_CLOCK_WARNING_3,
        UI_BONUS_LOOT_ROLL_END = SOUNDKIT.UI_BONUS_LOOT_ROLL_END,
    }
    
    -- Play sound
    if settings.mentionSound then
        if settings.mentionSoundSource == "custom" and settings.mentionSoundLSM and settings.mentionSoundLSM ~= "None" then
            -- Play LSM custom sound
            TweaksUI.Media:PlaySound(settings.mentionSoundLSM)
        else
            -- Play Blizzard SOUNDKIT sound
            local soundId = BLIZZARD_SOUNDS[settings.mentionSoundId] or SOUNDKIT.TELL_MESSAGE
            PlaySound(soundId)
        end
    end
    
    -- Flash taskbar/screen
    if settings.mentionFlash then
        FlashClientIcon()
    end
end

function Chat:TriggerGuildAlert()
    local settings = self:GetSettings()
    if not settings.enableGuildAlerts then return end
    
    -- Blizzard SOUNDKIT options table
    local BLIZZARD_SOUNDS = {
        TELL_MESSAGE = SOUNDKIT.TELL_MESSAGE,
        RAID_WARNING = SOUNDKIT.RAID_WARNING,
        READY_CHECK = SOUNDKIT.READY_CHECK,
        PVP_THROUGH_QUEUE = SOUNDKIT.PVP_THROUGH_QUEUE,
        LFG_REWARDS = SOUNDKIT.LFG_REWARDS,
        ALARM_CLOCK_WARNING_2 = SOUNDKIT.ALARM_CLOCK_WARNING_2,
        ALARM_CLOCK_WARNING_3 = SOUNDKIT.ALARM_CLOCK_WARNING_3,
        UI_BONUS_LOOT_ROLL_END = SOUNDKIT.UI_BONUS_LOOT_ROLL_END,
    }
    
    -- Play sound
    if settings.guildAlertSound then
        if settings.guildAlertSoundSource == "custom" and settings.guildAlertSoundLSM and settings.guildAlertSoundLSM ~= "None" then
            -- Play LSM custom sound
            TweaksUI.Media:PlaySound(settings.guildAlertSoundLSM)
        else
            -- Play Blizzard SOUNDKIT sound
            local soundId = BLIZZARD_SOUNDS[settings.guildAlertSoundId] or SOUNDKIT.TELL_MESSAGE
            PlaySound(soundId)
        end
    end
    
    -- Flash taskbar
    if settings.guildAlertFlash then
        FlashClientIcon()
    end
end

-- ============================================================================
-- CHAT FILTERS
-- ============================================================================

local SPAM_PATTERNS = {
    "www%.", "%.com", "%.net", "%.org",
    "gold", "power ?level", "boost",
    "wts", "wtb", "selling",
}

local GOLD_SELLER_PATTERNS = {
    "g2a", "mmoga", "ige", "igxe",
    "%d+g%s*=%s*%$", "%$%s*=%s*%d+g",
    "cheap gold", "fast delivery",
    "discount", "safe gold",
}

function Chat:ShouldFilterMessage(text, event, sender)
    local settings = self:GetSettings()
    local lowerText = text:lower()
    
    -- Gold seller filter
    if settings.filterGoldSellers then
        for _, pattern in ipairs(GOLD_SELLER_PATTERNS) do
            if lowerText:find(pattern) then
                return true, "Gold seller detected"
            end
        end
    end
    
    -- Custom filters
    for _, filter in ipairs(settings.customFilters or {}) do
        if filter and filter ~= "" and lowerText:find(filter:lower()) then
            return true, "Custom filter: " .. filter
        end
    end
    
    return false
end

-- ============================================================================
-- EDIT BOX CUSTOMIZATION
-- ============================================================================

function Chat:ApplyEditBoxSettings()
    local settings = self:GetSettings()
    
    -- Apply to all chat edit boxes
    for i = 1, NUM_CHAT_WINDOWS do
        local editBox = _G["ChatFrame" .. i .. "EditBox"]
        if editBox then
            -- Font
            if settings.editBoxFont or settings.editBoxFontSize then
                local fontPath = settings.editBoxFont or "Fonts\\FRIZQT__.TTF"
                local fontSize = settings.editBoxFontSize or 14
                editBox:SetFont(fontPath, fontSize, "")
            end
            
            -- Background
            if settings.editBoxBackground then
                local bg = settings.editBoxBackgroundColor or { r = 0, g = 0, b = 0, a = 0.7 }
                -- EditBox background handled by texture
            end
        end
    end
end

-- ============================================================================
-- WHISPER WINDOWS/TABS
-- ============================================================================

-- Create the separate whisper frame (if using separate mode)
function Chat:CreateWhisperFrame()
    local settings = self:GetSettings()
    
    if whisperFrame then return whisperFrame end
    
    local frame = CreateFrame("Frame", "TweaksUIWhisperFrame", UIParent, "BackdropTemplate")
    frame:SetSize(settings.whisperFrameWidth or 350, settings.whisperFrameHeight or 200)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetBackdrop(darkBackdrop)
    frame:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    frame:SetBackdropBorderColor(0.6, 0.4, 0.8, 1)  -- Purple border for whispers
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(250, 150, 600, 400)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetFrameStrata("MEDIUM")
    
    -- Set name for Edit Mode
    frame.editModeName = "TweaksUI Whispers"
    
    -- Title bar - only intercepts clicks when NOT in Edit Mode
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetHeight(22)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() 
        -- Only allow dragging via title bar when not in Edit Mode
        if not EditModeManagerFrame:IsShown() then
            frame:StartMoving() 
        end
    end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        self:SaveWhisperFramePosition()
    end)
    -- In Edit Mode, let clicks pass through to the selection overlay
    titleBar:SetScript("OnMouseDown", function(self, button)
        if EditModeManagerFrame:IsShown() then
            -- Pass through - the LibEditMode selection overlay will handle it
            self:EnableMouse(false)
            C_Timer.After(0.1, function() self:EnableMouse(true) end)
        end
    end)
    
    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", 8, 0)
    title:SetText("|cffDA70D6Whispers|r")
    frame.title = title
    
    -- Tab container
    local tabContainer = CreateFrame("Frame", nil, frame)
    tabContainer:SetHeight(22)
    tabContainer:SetPoint("TOPLEFT", 0, -22)
    tabContainer:SetPoint("TOPRIGHT", 0, -22)
    frame.tabContainer = tabContainer
    
    -- Message area
    local messageArea = CreateFrame("Frame", nil, frame)
    messageArea:SetPoint("TOPLEFT", 5, -46)
    messageArea:SetPoint("BOTTOMRIGHT", -5, 30)
    frame.messageArea = messageArea
    
    -- Edit box for replies
    local editBox = CreateFrame("EditBox", "TweaksUIWhisperEditBox", frame, "InputBoxTemplate")
    editBox:SetPoint("BOTTOMLEFT", 10, 5)
    editBox:SetPoint("BOTTOMRIGHT", -10, 5)
    editBox:SetHeight(20)
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        if text and text ~= "" and frame.currentTarget then
            SendChatMessage(text, "WHISPER", nil, frame.currentTarget)
            self:SetText("")
        end
        self:ClearFocus()
    end)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    frame.editBox = editBox
    
    -- Resize handle
    local resizeBtn = CreateFrame("Button", nil, frame)
    resizeBtn:SetSize(16, 16)
    resizeBtn:SetPoint("BOTTOMRIGHT", -2, 2)
    resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeBtn:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
    resizeBtn:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        self:SaveWhisperFramePosition()
    end)
    
    -- Register with Edit Mode
    self:RegisterWhisperFrameWithEditMode(frame)
    
    -- Restore position
    if settings.whisperFrameX and settings.whisperFrameY then
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", settings.whisperFrameX, settings.whisperFrameY)
    end
    
    frame:Hide()  -- Start hidden, show when whisper comes in
    whisperFrame = frame
    
    return frame
end

function Chat:SaveWhisperFramePosition()
    local settings = self:GetSettings()
    if whisperFrame then
        settings.whisperFrameX = whisperFrame:GetLeft()
        settings.whisperFrameY = whisperFrame:GetBottom()
        settings.whisperFrameWidth = whisperFrame:GetWidth()
        settings.whisperFrameHeight = whisperFrame:GetHeight()
    end
end

function Chat:RegisterWhisperFrameWithEditMode(frame)
    -- Use centralized EditModeManager
    if not TweaksUI.EditMode then 
        return 
    end
    
    local chatModule = self
    local settings = self:GetSettings()
    
    -- Callback for when position changes
    local function OnPositionChanged(movedFrame, point, x, y)
        chatModule:SaveWhisperFramePosition()
    end
    
    -- Register the frame with centralized manager
    TweaksUI.EditMode:RegisterFrame(frame, {
        name = "TweaksUI: Whisper Frame",
        onPositionChanged = OnPositionChanged,
        default = {
            point = "CENTER",
            x = 0,
            y = 0,
        },
    })
end

-- Create a tab for a specific person in the whisper frame
function Chat:CreateWhisperTab(sender)
    if not whisperFrame then
        self:CreateWhisperFrame()
    end
    
    local settings = self:GetSettings()
    
    -- Check if tab already exists
    if whisperTabs[sender] then
        whisperTabs[sender].lastActivity = GetTime()
        return whisperTabs[sender]
    end
    
    local tabContainer = whisperFrame.tabContainer
    
    -- Count existing tabs to position new one
    local tabCount = 0
    for _ in pairs(whisperTabs) do
        tabCount = tabCount + 1
    end
    
    -- Create tab button
    local tab = CreateFrame("Button", nil, tabContainer, "BackdropTemplate")
    tab:SetSize(80, 20)
    tab:SetPoint("LEFT", tabContainer, "LEFT", tabCount * 85 + 5, 0)
    tab:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    tab:SetBackdropColor(0.15, 0.15, 0.15, 1)
    tab:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    
    local tabText = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tabText:SetPoint("LEFT", 5, 0)
    tabText:SetText(sender)
    tabText:SetTextColor(0.85, 0.53, 0.85)  -- Purple for whispers
    tab.text = tabText
    
    -- Close button on tab
    local closeBtn = CreateFrame("Button", nil, tab)
    closeBtn:SetSize(14, 14)
    closeBtn:SetPoint("RIGHT", -2, 0)
    closeBtn:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
    closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-StopButton")
    closeBtn:GetHighlightTexture():SetVertexColor(1, 0.3, 0.3)
    closeBtn:SetScript("OnClick", function()
        self:CloseWhisperTab(sender)
    end)
    
    -- Create message frame for this sender
    local msgFrame = CreateFrame("ScrollingMessageFrame", nil, whisperFrame.messageArea)
    msgFrame:SetAllPoints(whisperFrame.messageArea)
    msgFrame:SetFading(false)
    msgFrame:SetMaxLines(500)
    msgFrame:SetFontObject(ChatFontNormal)
    msgFrame:SetJustifyH("LEFT")
    msgFrame:EnableMouseWheel(true)
    msgFrame:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            self:ScrollUp()
            self:ScrollUp()
            self:ScrollUp()
        else
            self:ScrollDown()
            self:ScrollDown()
            self:ScrollDown()
        end
    end)
    msgFrame:Hide()  -- Hidden until selected
    
    -- Tab click handler
    tab:SetScript("OnClick", function()
        self:SelectWhisperTab(sender)
    end)
    
    -- Store tab info
    whisperTabs[sender] = {
        tab = tab,
        messageFrame = msgFrame,
        lastActivity = GetTime()
    }
    
    -- Set up auto-close timer if configured
    if settings.whisperTabTimeout and settings.whisperTabTimeout > 0 then
        C_Timer.After(settings.whisperTabTimeout, function()
            self:CheckWhisperTabTimeout(sender)
        end)
    end
    
    -- Select this tab
    self:SelectWhisperTab(sender)
    
    -- Show the whisper frame
    whisperFrame:Show()
    
    return whisperTabs[sender]
end

function Chat:SelectWhisperTab(sender)
    if not whisperTabs[sender] then return end
    
    -- Hide all message frames, deselect all tabs
    for name, data in pairs(whisperTabs) do
        if data.messageFrame then
            data.messageFrame:Hide()
        end
        if data.tab then
            data.tab:SetBackdropColor(0.15, 0.15, 0.15, 1)
            data.tab:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        end
    end
    
    -- Show selected tab's message frame
    local tabData = whisperTabs[sender]
    if tabData.messageFrame then
        tabData.messageFrame:Show()
    end
    if tabData.tab then
        tabData.tab:SetBackdropColor(0.25, 0.15, 0.25, 1)
        tabData.tab:SetBackdropBorderColor(0.6, 0.4, 0.8, 1)
    end
    
    -- Update edit box target
    if whisperFrame then
        whisperFrame.currentTarget = sender
        whisperFrame.title:SetText("|cffDA70D6Whisper: " .. sender .. "|r")
    end
end

function Chat:CloseWhisperTab(sender)
    local tabData = whisperTabs[sender]
    if not tabData then return end
    
    -- Hide and remove UI elements
    if tabData.tab then
        tabData.tab:Hide()
        tabData.tab:SetParent(nil)
    end
    if tabData.messageFrame then
        tabData.messageFrame:Hide()
        tabData.messageFrame:SetParent(nil)
    end
    
    whisperTabs[sender] = nil
    
    -- Reposition remaining tabs
    self:RepositionWhisperTabs()
    
    -- Select another tab if any remain, or hide frame
    local nextSender = nil
    for name, _ in pairs(whisperTabs) do
        nextSender = name
        break
    end
    
    if nextSender then
        self:SelectWhisperTab(nextSender)
    elseif whisperFrame then
        whisperFrame:Hide()
        whisperFrame.currentTarget = nil
    end
end

function Chat:RepositionWhisperTabs()
    if not whisperFrame then return end
    
    local tabCount = 0
    for sender, data in pairs(whisperTabs) do
        if data.tab then
            data.tab:ClearAllPoints()
            data.tab:SetPoint("LEFT", whisperFrame.tabContainer, "LEFT", tabCount * 85 + 5, 0)
            tabCount = tabCount + 1
        end
    end
end

function Chat:CheckWhisperTabTimeout(sender)
    local settings = self:GetSettings()
    
    if whisperTabs[sender] then
        local elapsed = GetTime() - whisperTabs[sender].lastActivity
        if elapsed >= settings.whisperTabTimeout then
            self:CloseWhisperTab(sender)
        else
            -- Check again later
            local remaining = settings.whisperTabTimeout - elapsed
            C_Timer.After(remaining, function()
                self:CheckWhisperTabTimeout(sender)
            end)
        end
    end
end

-- Handle incoming whisper
function Chat:HandleWhisper(sender, message, isOutgoing, skipTabCreation)
    local settings = self:GetSettings()
    
    if not settings.enableWhisperTabs then 
        return 
    end
    
    -- Check if sender is valid and usable (not a secret value)
    if not sender then return end
    local testSuccess = pcall(function() local _ = sender .. "" end)
    if not testSuccess then return end
    
    -- Get just the name without realm - use pcall for safety
    local shortName = sender
    pcall(function()
        shortName = sender:match("([^-]+)") or sender
    end)
    
    if settings.whisperWindowMode == "separate" then
        -- Use separate whisper frame
        local tabData = whisperTabs[shortName]
        if not tabData and not skipTabCreation then
            tabData = self:CreateWhisperTab(shortName)
        end
        
        if tabData and tabData.messageFrame then
            tabData.lastActivity = GetTime()
            
            -- Format message
            local timestamp = date("[%H:%M] ")
            local color = isOutgoing and "|cffFF80FF" or "|cffDA70D6"
            local prefix = isOutgoing and "To " or "From "
            
            tabData.messageFrame:AddMessage(
                "|cff888888" .. timestamp .. "|r" .. color .. prefix .. shortName .. ": " .. message .. "|r"
            )
        end
    else
        -- Use tab in main chat frame
        if not skipTabCreation then
            self:HandleWhisperTabInMainChat(sender)
        end
    end
end

-- Original tab-in-main-chat behavior
function Chat:HandleWhisperTabInMainChat(sender)
    local settings = self:GetSettings()
    
    if not settings.enableWhisperTabs then 
        return 
    end
    
    -- Check if sender is valid and usable (not a secret value)
    if not sender then return end
    local testSuccess = pcall(function() local _ = sender .. "" end)
    if not testSuccess then return end
    
    -- Get short name - use pcall for safety
    local shortName = sender
    pcall(function()
        shortName = sender:match("([^-]+)") or sender
    end)
    
    -- Check if we already tracked this whisper tab
    if mainChatWhisperTabs[shortName] then
        local existingFrame = _G["ChatFrame" .. mainChatWhisperTabs[shortName]]
        if existingFrame and existingFrame:IsShown() then
            -- Tab exists - make sure our UI shows it and select it
            self:RefreshChannelTabs()
            self:SelectChatFrame(mainChatWhisperTabs[shortName])
            return mainChatWhisperTabs[shortName]
        else
            -- Frame was closed, remove from tracking
            mainChatWhisperTabs[shortName] = nil
        end
    end
    
    -- Check if we already have a tab for this sender in Blizzard's system
    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        local tab = _G["ChatFrame" .. i .. "Tab"]
        if cf and tab then
            local tabText = tab:GetText()
            if tabText and tabText == shortName then
                mainChatWhisperTabs[shortName] = i
                
                -- Make sure this frame has whisper message groups
                ChatFrame_AddMessageGroup(cf, "WHISPER")
                ChatFrame_AddMessageGroup(cf, "WHISPER_INFORM")
                
                -- Hook this frame if not already hooked
                self:HookChatFrameMessages(i)
                
                -- Found existing - refresh our tabs to show it
                self:RefreshChannelTabs()
                
                -- Auto-select this tab
                self:SelectChatFrame(i)
                
                return i
            end
        end
    end
    
    -- Create new whisper tab using Blizzard's system
    if not FCF_OpenNewWindow then
        return nil
    end
    
    local newFrame = FCF_OpenNewWindow(shortName)
    if newFrame then
        local frameIndex = newFrame:GetID()
        
        ChatFrame_RemoveAllMessageGroups(newFrame)
        ChatFrame_AddMessageGroup(newFrame, "WHISPER")
        ChatFrame_AddMessageGroup(newFrame, "WHISPER_INFORM")
        
        -- Hook this new frame
        self:HookChatFrameMessages(frameIndex)
        
        -- Track this tab
        mainChatWhisperTabs[shortName] = frameIndex
        
        self:RefreshChannelTabs()
        
        -- Auto-select the new tab
        self:SelectChatFrame(frameIndex)
        
        return frameIndex
    end
    
    return nil
end

-- Clean up tracking when tabs are closed
function Chat:CleanupWhisperTabTracking()
    for name, frameIndex in pairs(mainChatWhisperTabs) do
        local cf = _G["ChatFrame" .. frameIndex]
        if not cf or not cf:IsShown() then
            mainChatWhisperTabs[name] = nil
        end
    end
end

-- Cleanup extra chat frames beyond NUM_CHAT_WINDOWS (10)
-- These can cause errors in Blizzard's ChatConfigFrame
function Chat:CleanupExtraChatFrames()
    local closed = 0
    
    -- Check frames 11-20 for orphaned chat frames
    for i = 11, 20 do
        local chatFrame = _G["ChatFrame" .. i]
        if chatFrame then
            -- Try to close it properly
            if FCF_Close then
                pcall(function() 
                    FCF_Close(chatFrame) 
                    closed = closed + 1
                end)
            end
        end
    end
    
    -- Also clear our whisper tab tracking for any closed frames
    self:CleanupWhisperTabTracking()
    
    -- Refresh our tab display
    self:RefreshChannelTabs()
    
    if closed > 0 then
        TweaksUI:Print("Cleaned up " .. closed .. " extra chat frame(s). Recommend /reload to fully reset.")
    else
        TweaksUI:Print("No extra chat frames found to clean up.")
    end
end

-- Hook whisper events
function Chat:SetupWhisperHandler()
    local settings = self:GetSettings()
    
    -- Create whisper frame if using separate mode and enabled
    if settings.enableWhisperTabs and settings.whisperWindowMode == "separate" then
        self:CreateWhisperFrame()
    end
    
    -- Hide whispers from General tab if option is enabled
    if settings.enableWhisperTabs and settings.hideWhispersInGeneral then
        self:ApplyHideWhispersInGeneral(true)
    end
    
    -- Track recent tab creations to prevent duplicates when whispering yourself
    local recentTabCreations = {}
    
    -- Hook into chat events for whispers
    -- ALWAYS register events - check setting inside handler so it works if enabled later
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("CHAT_MSG_WHISPER")
    eventFrame:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
    
    eventFrame:SetScript("OnEvent", function(self, event, message, sender, ...)
        -- Check setting at runtime (so enabling later works)
        local currentSettings = Chat:GetSettings()
        if not currentSettings.enableWhisperTabs then
            return
        end
        
        -- Check if sender is valid and usable (not a secret value)
        if not sender then return end
        local testSuccess = pcall(function() local _ = sender .. "" end)
        if not testSuccess then return end
        
        -- Get short name - use pcall for safety
        local shortName = sender
        pcall(function()
            shortName = sender:match("([^-]+)") or sender
        end)
        local now = GetTime()
        
        -- Clean old entries first
        for name, time in pairs(recentTabCreations) do
            if now - time > 1 then
                recentTabCreations[name] = nil
            end
        end
        
        -- Check if we JUST created a tab for this person (within 0.5 sec)
        -- This prevents the duplicate when whispering yourself
        local skipTabCreation = false
        if recentTabCreations[shortName] and (now - recentTabCreations[shortName]) < 0.5 then
            skipTabCreation = true
        end
        
        if event == "CHAT_MSG_WHISPER" then
            Chat:HandleWhisper(sender, message, false, skipTabCreation)
        elseif event == "CHAT_MSG_WHISPER_INFORM" then
            Chat:HandleWhisper(sender, message, true, skipTabCreation)
        end
        
        -- Mark that we've handled this person
        if not skipTabCreation then
            recentTabCreations[shortName] = now
        end
    end)
end

-- Apply or remove whisper filtering from ChatFrame1 (General)
function Chat:ApplyHideWhispersInGeneral(hide)
    local chatFrame1 = ChatFrame1
    if not chatFrame1 then return end
    
    if hide then
        -- Remove WHISPER and WHISPER_INFORM from General tab
        ChatFrame_RemoveMessageGroup(chatFrame1, "WHISPER")
        ChatFrame_RemoveMessageGroup(chatFrame1, "WHISPER_INFORM")
    else
        -- Add them back
        ChatFrame_AddMessageGroup(chatFrame1, "WHISPER")
        ChatFrame_AddMessageGroup(chatFrame1, "WHISPER_INFORM")
    end
end


-- ============================================================================
-- SOCIAL FEATURES (Friend/Guild Status)
-- ============================================================================

function Chat:SetupSocialNotifications()
    local settings = self:GetSettings()
    
    if settings.showFriendStatus then
        -- Hook friend online/offline events
        local frame = CreateFrame("Frame")
        frame:RegisterEvent("FRIENDLIST_UPDATE")
        frame:RegisterEvent("BN_FRIEND_INFO_CHANGED")
        frame:SetScript("OnEvent", function(self, event, ...)
            -- Friend status changes are handled by Blizzard's default system
            -- We just ensure our chat frame shows them
        end)
    end
end

-- ============================================================================
-- SETTINGS PANELS FOR NEW FEATURES
-- ============================================================================

function Chat:CreateBehaviorPanel()
    local panel = self:CreateDockedPanel("behavior", "Behavior", 600)
    local content = panel.content
    local settings = self:GetSettings()
    local yOffset = 0
    
    -- ========== MESSAGE FADING SECTION ==========
    local fadeHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fadeHeader:SetPoint("TOPLEFT", 0, yOffset)
    fadeHeader:SetText("|cffffd100Message Fading|r")
    yOffset = yOffset - 25
    
    local enableFadeCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    enableFadeCheck:SetPoint("TOPLEFT", 0, yOffset)
    enableFadeCheck:SetSize(22, 22)
    enableFadeCheck.text:SetText("Enable message fading")
    enableFadeCheck:SetChecked(settings.enableFading)
    enableFadeCheck:SetScript("OnClick", function(self)
        settings.enableFading = self:GetChecked()
        Chat:ApplyFadingSettings()
    end)
    yOffset = yOffset - 25
    
    -- Fade time slider
    local fadeTimeContainer = TweaksUI.Utilities:CreateSliderWithInput(content, {
        label = "Visible time:",
        min = 10,
        max = 600,
        step = 10,
        value = settings.fadeTime or 120,
        width = 200,
        labelWidth = 80,
        valueWidth = 50,
        formatStr = "%ds",
        onValueChanged = function(value)
            settings.fadeTime = value
            Chat:ApplyFadingSettings()
        end,
    })
    fadeTimeContainer:SetPoint("TOPLEFT", 20, yOffset)
    yOffset = yOffset - 35
    
    -- ========== URL HANDLING SECTION ==========
    local urlHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    urlHeader:SetPoint("TOPLEFT", 0, yOffset)
    urlHeader:SetText("|cffffd100URL Handling|r")
    yOffset = yOffset - 25
    
    local enableURLCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    enableURLCheck:SetPoint("TOPLEFT", 0, yOffset)
    enableURLCheck:SetSize(22, 22)
    enableURLCheck.text:SetText("Highlight clickable URLs")
    enableURLCheck:SetChecked(settings.enableURLs)
    enableURLCheck:SetScript("OnClick", function(self)
        settings.enableURLs = self:GetChecked()
    end)
    yOffset = yOffset - 30
    
    -- ========== STICKY CHAT SECTION ==========
    local stickyHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    stickyHeader:SetPoint("TOPLEFT", 0, yOffset)
    stickyHeader:SetText("|cffffd100Sticky Chat|r")
    yOffset = yOffset - 25
    
    local enableStickyTabCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    enableStickyTabCheck:SetPoint("TOPLEFT", 0, yOffset)
    enableStickyTabCheck:SetSize(22, 22)
    enableStickyTabCheck.text:SetText("Remember last selected tab")
    enableStickyTabCheck:SetChecked(settings.enableStickyTab ~= false)  -- Default true
    enableStickyTabCheck:SetScript("OnClick", function(self)
        settings.enableStickyTab = self:GetChecked()
    end)
    yOffset = yOffset - 25
    
    local enableStickyCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    enableStickyCheck:SetPoint("TOPLEFT", 0, yOffset)
    enableStickyCheck:SetSize(22, 22)
    enableStickyCheck.text:SetText("Remember last chat channel (/say, /party, etc)")
    enableStickyCheck:SetChecked(settings.enableStickyChat)
    enableStickyCheck:SetScript("OnClick", function(self)
        settings.enableStickyChat = self:GetChecked()
    end)
    yOffset = yOffset - 30
    
    -- ========== WHISPER WINDOWS SECTION ==========
    local whisperHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    whisperHeader:SetPoint("TOPLEFT", 0, yOffset)
    whisperHeader:SetText("|cffffd100Whisper Windows|r")
    yOffset = yOffset - 25
    
    local enableWhisperCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    enableWhisperCheck:SetPoint("TOPLEFT", 0, yOffset)
    enableWhisperCheck:SetSize(22, 22)
    enableWhisperCheck.text:SetText("Auto-create windows for whispers")
    enableWhisperCheck:SetChecked(settings.enableWhisperTabs)
    enableWhisperCheck:SetScript("OnClick", function(self)
        settings.enableWhisperTabs = self:GetChecked()
        -- Apply immediately
        if settings.enableWhisperTabs then
            -- Create whisper frame if in separate mode
            if settings.whisperWindowMode == "separate" then
                Chat:CreateWhisperFrame()
            end
            -- Apply hide whispers filter if enabled
            if settings.hideWhispersInGeneral then
                Chat:ApplyHideWhispersInGeneral(true)
            end
            TweaksUI:Print("Whisper windows enabled - changes active immediately")
        else
            -- Hide whisper frame if it exists
            if whisperFrame then
                whisperFrame:Hide()
            end
            -- Remove hide whispers filter
            Chat:ApplyHideWhispersInGeneral(false)
            TweaksUI:Print("Whisper windows disabled")
        end
    end)
    yOffset = yOffset - 25
    
    -- Mode selection
    local modeLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    modeLabel:SetPoint("TOPLEFT", 20, yOffset)
    modeLabel:SetText("Window Mode:")
    
    local tabModeBtn = CreateFrame("CheckButton", nil, content, "UIRadioButtonTemplate")
    tabModeBtn:SetPoint("LEFT", modeLabel, "RIGHT", 10, 0)
    tabModeBtn:SetSize(20, 20)
    tabModeBtn.text:SetText("Tab in main chat")
    tabModeBtn:SetChecked(settings.whisperWindowMode ~= "separate")
    
    local separateModeBtn = CreateFrame("CheckButton", nil, content, "UIRadioButtonTemplate")
    separateModeBtn:SetPoint("LEFT", tabModeBtn.text, "RIGHT", 15, 0)
    separateModeBtn:SetSize(20, 20)
    separateModeBtn.text:SetText("Separate frame")
    separateModeBtn:SetChecked(settings.whisperWindowMode == "separate")
    
    tabModeBtn:SetScript("OnClick", function(self)
        settings.whisperWindowMode = "tab"
        tabModeBtn:SetChecked(true)
        separateModeBtn:SetChecked(false)
        -- Hide separate frame if it exists
        if whisperFrame then
            whisperFrame:Hide()
        end
        TweaksUI:Print("Whisper mode: Tab in main chat")
    end)
    
    separateModeBtn:SetScript("OnClick", function(self)
        settings.whisperWindowMode = "separate"
        tabModeBtn:SetChecked(false)
        separateModeBtn:SetChecked(true)
        -- Create and show the frame if whisper tabs are enabled
        if settings.enableWhisperTabs then
            Chat:CreateWhisperFrame()
            if whisperFrame then
                whisperFrame:Show()
            end
        end
        TweaksUI:Print("Whisper mode: Separate frame")
    end)
    yOffset = yOffset - 25
    
    -- Timeout slider with input
    local timeoutContainer = TweaksUI.Utilities:CreateSliderWithInput(content, {
        label = "Auto-close after:",
        min = 0,
        max = 600,
        step = 30,
        value = settings.whisperTabTimeout or 300,
        width = 200,
        labelWidth = 100,
        valueWidth = 50,
        formatStr = "%ds",
        onValueChanged = function(value)
            settings.whisperTabTimeout = value
        end,
    })
    timeoutContainer:SetPoint("TOPLEFT", 20, yOffset)
    yOffset = yOffset - 35
    
    -- Hide whispers in General checkbox
    local hideWhispersCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    hideWhispersCheck:SetPoint("TOPLEFT", 20, yOffset)
    hideWhispersCheck:SetSize(22, 22)
    hideWhispersCheck.text:SetText("Hide whispers in General tab")
    hideWhispersCheck:SetChecked(settings.hideWhispersInGeneral or false)
    hideWhispersCheck:SetScript("OnClick", function(self)
        settings.hideWhispersInGeneral = self:GetChecked()
        Chat:ApplyHideWhispersInGeneral(settings.hideWhispersInGeneral)
    end)
    yOffset = yOffset - 30
    
    chatPanels["behavior"] = panel
end

function Chat:CreateFormattingPanel()
    local panel = self:CreateDockedPanel("formatting", "Formatting", 450)
    local content = panel.content
    local settings = self:GetSettings()
    local yOffset = 0
    
    -- ========== CLASS COLORS SECTION ==========
    local classHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    classHeader:SetPoint("TOPLEFT", 0, yOffset)
    classHeader:SetText("|cffffd100Player Names|r")
    yOffset = yOffset - 25
    
    local enableClassCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    enableClassCheck:SetPoint("TOPLEFT", 0, yOffset)
    enableClassCheck:SetSize(22, 22)
    enableClassCheck.text:SetText("Color names by class")
    enableClassCheck:SetChecked(settings.enableClassColors)
    enableClassCheck:SetScript("OnClick", function(self)
        settings.enableClassColors = self:GetChecked()
    end)
    yOffset = yOffset - 30
    
    -- ========== SHORT CHANNELS SECTION ==========
    local channelHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    channelHeader:SetPoint("TOPLEFT", 0, yOffset)
    channelHeader:SetText("|cffffd100Channel Names|r")
    yOffset = yOffset - 25
    
    local enableShortCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    enableShortCheck:SetPoint("TOPLEFT", 0, yOffset)
    enableShortCheck:SetSize(22, 22)
    enableShortCheck.text:SetText("Use short channel names ([1] instead of [1. General])")
    enableShortCheck:SetChecked(settings.enableShortChannels)
    enableShortCheck:SetScript("OnClick", function(self)
        settings.enableShortChannels = self:GetChecked()
    end)
    yOffset = yOffset - 35
    
    -- ========== CLICK ACTIONS SECTION ==========
    local clickHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    clickHeader:SetPoint("TOPLEFT", 0, yOffset)
    clickHeader:SetText("|cffffd100Click Actions|r")
    yOffset = yOffset - 25
    
    local enableAltCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    enableAltCheck:SetPoint("TOPLEFT", 0, yOffset)
    enableAltCheck:SetSize(22, 22)
    enableAltCheck.text:SetText("Alt-click name to invite")
    enableAltCheck:SetChecked(settings.enableAltInvite)
    enableAltCheck:SetScript("OnClick", function(self)
        settings.enableAltInvite = self:GetChecked()
    end)
    yOffset = yOffset - 25
    
    local enableShiftCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    enableShiftCheck:SetPoint("TOPLEFT", 0, yOffset)
    enableShiftCheck:SetSize(22, 22)
    enableShiftCheck.text:SetText("Shift-click name to copy")
    enableShiftCheck:SetChecked(settings.enableShiftCopy)
    enableShiftCheck:SetScript("OnClick", function(self)
        settings.enableShiftCopy = self:GetChecked()
    end)
    yOffset = yOffset - 35
    
    chatPanels["formatting"] = panel
end

function Chat:CreateAlertsPanel()
    local panel = self:CreateDockedPanel("alerts", "Alerts & Filters", 500)
    local content = panel.content
    local settings = self:GetSettings()
    local yOffset = 0
    
    -- ========== MENTION ALERTS SECTION ==========
    local mentionHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mentionHeader:SetPoint("TOPLEFT", 0, yOffset)
    mentionHeader:SetText("|cffffd100Mention Alerts|r")
    yOffset = yOffset - 25
    
    local enableMentionCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    enableMentionCheck:SetPoint("TOPLEFT", 0, yOffset)
    enableMentionCheck:SetSize(22, 22)
    enableMentionCheck.text:SetText("Enable mention alerts")
    enableMentionCheck:SetChecked(settings.enableMentionAlerts)
    enableMentionCheck:SetScript("OnClick", function(self)
        settings.enableMentionAlerts = self:GetChecked()
    end)
    yOffset = yOffset - 25
    
    local mentionSoundCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    mentionSoundCheck:SetPoint("TOPLEFT", 20, yOffset)
    mentionSoundCheck:SetSize(22, 22)
    mentionSoundCheck.text:SetText("Play sound")
    mentionSoundCheck:SetChecked(settings.mentionSound)
    mentionSoundCheck:SetScript("OnClick", function(self)
        settings.mentionSound = self:GetChecked()
    end)
    yOffset = yOffset - 25
    
    -- Sound source selection (Blizzard or Custom/LSM)
    local sourceLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sourceLabel:SetPoint("TOPLEFT", 40, yOffset)
    sourceLabel:SetText("Sound Source:")
    
    local sourceDropdown = CreateFrame("Frame", "TweaksUIMentionSoundSourceDropdown", content, "UIDropDownMenuTemplate")
    sourceDropdown:SetPoint("LEFT", sourceLabel, "RIGHT", 0, -2)
    UIDropDownMenu_SetWidth(sourceDropdown, 100)
    UIDropDownMenu_SetText(sourceDropdown, settings.mentionSoundSource == "custom" and "Custom (LSM)" or "Blizzard")
    
    -- Blizzard sound options
    local BLIZZARD_SOUND_OPTIONS = {
        { id = "TELL_MESSAGE", name = "Whisper" },
        { id = "RAID_WARNING", name = "Raid Warning" },
        { id = "READY_CHECK", name = "Ready Check" },
        { id = "PVP_THROUGH_QUEUE", name = "PvP Queue Pop" },
        { id = "LFG_REWARDS", name = "LFG Rewards" },
        { id = "ALARM_CLOCK_WARNING_2", name = "Alarm Clock 2" },
        { id = "ALARM_CLOCK_WARNING_3", name = "Alarm Clock 3" },
        { id = "UI_BONUS_LOOT_ROLL_END", name = "Bonus Roll" },
    }
    
    local BLIZZARD_SOUNDS = {
        TELL_MESSAGE = SOUNDKIT.TELL_MESSAGE,
        RAID_WARNING = SOUNDKIT.RAID_WARNING,
        READY_CHECK = SOUNDKIT.READY_CHECK,
        PVP_THROUGH_QUEUE = SOUNDKIT.PVP_THROUGH_QUEUE,
        LFG_REWARDS = SOUNDKIT.LFG_REWARDS,
        ALARM_CLOCK_WARNING_2 = SOUNDKIT.ALARM_CLOCK_WARNING_2,
        ALARM_CLOCK_WARNING_3 = SOUNDKIT.ALARM_CLOCK_WARNING_3,
        UI_BONUS_LOOT_ROLL_END = SOUNDKIT.UI_BONUS_LOOT_ROLL_END,
    }
    
    yOffset = yOffset - 30
    
    -- Blizzard sound dropdown
    local blizzSoundLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    blizzSoundLabel:SetPoint("TOPLEFT", 40, yOffset)
    blizzSoundLabel:SetText("Blizzard Sound:")
    
    local blizzSoundDropdown = CreateFrame("Frame", "TweaksUIMentionBlizzSoundDropdown", content, "UIDropDownMenuTemplate")
    blizzSoundDropdown:SetPoint("LEFT", blizzSoundLabel, "RIGHT", 0, -2)
    UIDropDownMenu_SetWidth(blizzSoundDropdown, 120)
    
    local currentBlizzSoundName = "Whisper"
    for _, opt in ipairs(BLIZZARD_SOUND_OPTIONS) do
        if opt.id == settings.mentionSoundId then
            currentBlizzSoundName = opt.name
            break
        end
    end
    UIDropDownMenu_SetText(blizzSoundDropdown, currentBlizzSoundName)
    
    UIDropDownMenu_Initialize(blizzSoundDropdown, function(self, level)
        for _, opt in ipairs(BLIZZARD_SOUND_OPTIONS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = opt.name
            info.checked = (settings.mentionSoundId == opt.id)
            info.func = function()
                settings.mentionSoundId = opt.id
                UIDropDownMenu_SetText(blizzSoundDropdown, opt.name)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    
    yOffset = yOffset - 30
    
    -- Custom (LSM) sound dropdown
    local customSoundLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    customSoundLabel:SetPoint("TOPLEFT", 40, yOffset)
    customSoundLabel:SetText("Custom Sound:")
    
    local customSoundDropdown = CreateFrame("Frame", "TweaksUIMentionCustomSoundDropdown", content, "UIDropDownMenuTemplate")
    customSoundDropdown:SetPoint("LEFT", customSoundLabel, "RIGHT", 0, -2)
    UIDropDownMenu_SetWidth(customSoundDropdown, 140)
    UIDropDownMenu_SetText(customSoundDropdown, settings.mentionSoundLSM or "None")
    
    UIDropDownMenu_Initialize(customSoundDropdown, function(self, level)
        local soundList = TweaksUI.Media:GetSoundList()
        for _, soundName in ipairs(soundList) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = soundName
            info.checked = (settings.mentionSoundLSM == soundName)
            info.func = function()
                settings.mentionSoundLSM = soundName
                UIDropDownMenu_SetText(customSoundDropdown, soundName)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    
    -- Play button to preview selected sound
    local mentionPlayBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    mentionPlayBtn:SetPoint("LEFT", customSoundDropdown, "RIGHT", -10, 2)
    mentionPlayBtn:SetSize(50, 22)
    mentionPlayBtn:SetText("Play")
    mentionPlayBtn:SetScript("OnClick", function()
        if settings.mentionSoundSource == "custom" and settings.mentionSoundLSM and settings.mentionSoundLSM ~= "None" then
            TweaksUI.Media:PlaySound(settings.mentionSoundLSM)
        else
            local soundId = BLIZZARD_SOUNDS[settings.mentionSoundId] or SOUNDKIT.TELL_MESSAGE
            PlaySound(soundId)
        end
    end)
    
    -- Initialize source dropdown
    UIDropDownMenu_Initialize(sourceDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        info.text = "Blizzard"
        info.checked = (settings.mentionSoundSource ~= "custom")
        info.func = function()
            settings.mentionSoundSource = "blizzard"
            UIDropDownMenu_SetText(sourceDropdown, "Blizzard")
        end
        UIDropDownMenu_AddButton(info)
        
        info = UIDropDownMenu_CreateInfo()
        info.text = "Custom (LSM)"
        info.checked = (settings.mentionSoundSource == "custom")
        info.func = function()
            settings.mentionSoundSource = "custom"
            UIDropDownMenu_SetText(sourceDropdown, "Custom (LSM)")
        end
        UIDropDownMenu_AddButton(info)
    end)
    
    yOffset = yOffset - 30
    
    local mentionFlashCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    mentionFlashCheck:SetPoint("TOPLEFT", 20, yOffset)
    mentionFlashCheck:SetSize(22, 22)
    mentionFlashCheck.text:SetText("Flash taskbar")
    mentionFlashCheck:SetChecked(settings.mentionFlash)
    mentionFlashCheck:SetScript("OnClick", function(self)
        settings.mentionFlash = self:GetChecked()
    end)
    yOffset = yOffset - 25
    
    -- Custom mention words
    local mentionWordsLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    mentionWordsLabel:SetPoint("TOPLEFT", 20, yOffset)
    mentionWordsLabel:SetText("Additional alert words (comma separated):")
    yOffset = yOffset - 20
    
    local mentionWordsInput = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    mentionWordsInput:SetPoint("TOPLEFT", 20, yOffset)
    mentionWordsInput:SetSize(300, 25)
    mentionWordsInput:SetAutoFocus(false)
    mentionWordsInput:SetText(table.concat(settings.mentionWords or {}, ", "))
    
    -- Function to save the words
    local function SaveMentionWords(editBox)
        local text = editBox:GetText()
        settings.mentionWords = {}
        for word in text:gmatch("[^,]+") do
            word = word:match("^%s*(.-)%s*$")  -- trim whitespace
            if word and word ~= "" then
                table.insert(settings.mentionWords, word)
            end
        end
        TweaksUI:PrintDebug("Chat: Saved mention words: " .. table.concat(settings.mentionWords, ", "))
    end
    
    mentionWordsInput:SetScript("OnEnterPressed", function(self)
        SaveMentionWords(self)
        self:ClearFocus()
    end)
    
    mentionWordsInput:SetScript("OnEditFocusLost", function(self)
        SaveMentionWords(self)
    end)
    
    -- Also save when escape is pressed
    mentionWordsInput:SetScript("OnEscapePressed", function(self)
        SaveMentionWords(self)
        self:ClearFocus()
    end)
    yOffset = yOffset - 35
    
    -- ========== GUILD MESSAGE ALERTS SECTION ==========
    local guildHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    guildHeader:SetPoint("TOPLEFT", 0, yOffset)
    guildHeader:SetText("|cffffd100Guild Message Alerts|r")
    yOffset = yOffset - 25
    
    local enableGuildCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    enableGuildCheck:SetPoint("TOPLEFT", 0, yOffset)
    enableGuildCheck:SetSize(22, 22)
    enableGuildCheck.text:SetText("Enable guild message alerts")
    enableGuildCheck:SetChecked(settings.enableGuildAlerts)
    enableGuildCheck:SetScript("OnClick", function(self)
        settings.enableGuildAlerts = self:GetChecked()
    end)
    yOffset = yOffset - 25
    
    local guildSoundCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    guildSoundCheck:SetPoint("TOPLEFT", 20, yOffset)
    guildSoundCheck:SetSize(22, 22)
    guildSoundCheck.text:SetText("Play sound")
    guildSoundCheck:SetChecked(settings.guildAlertSound)
    guildSoundCheck:SetScript("OnClick", function(self)
        settings.guildAlertSound = self:GetChecked()
    end)
    yOffset = yOffset - 25
    
    -- Guild sound source selection (Blizzard or Custom/LSM)
    local guildSourceLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    guildSourceLabel:SetPoint("TOPLEFT", 40, yOffset)
    guildSourceLabel:SetText("Sound Source:")
    
    local guildSourceDropdown = CreateFrame("Frame", "TweaksUIGuildSoundSourceDropdown", content, "UIDropDownMenuTemplate")
    guildSourceDropdown:SetPoint("LEFT", guildSourceLabel, "RIGHT", 0, -2)
    UIDropDownMenu_SetWidth(guildSourceDropdown, 100)
    UIDropDownMenu_SetText(guildSourceDropdown, settings.guildAlertSoundSource == "custom" and "Custom (LSM)" or "Blizzard")
    
    -- Blizzard sound options
    local GUILD_BLIZZARD_OPTIONS = {
        { id = "TELL_MESSAGE", name = "Whisper" },
        { id = "RAID_WARNING", name = "Raid Warning" },
        { id = "READY_CHECK", name = "Ready Check" },
        { id = "PVP_THROUGH_QUEUE", name = "PvP Queue Pop" },
        { id = "LFG_REWARDS", name = "LFG Rewards" },
        { id = "ALARM_CLOCK_WARNING_2", name = "Alarm Clock 2" },
        { id = "ALARM_CLOCK_WARNING_3", name = "Alarm Clock 3" },
        { id = "UI_BONUS_LOOT_ROLL_END", name = "Bonus Roll" },
    }
    
    local GUILD_BLIZZARD_SOUNDS = {
        TELL_MESSAGE = SOUNDKIT.TELL_MESSAGE,
        RAID_WARNING = SOUNDKIT.RAID_WARNING,
        READY_CHECK = SOUNDKIT.READY_CHECK,
        PVP_THROUGH_QUEUE = SOUNDKIT.PVP_THROUGH_QUEUE,
        LFG_REWARDS = SOUNDKIT.LFG_REWARDS,
        ALARM_CLOCK_WARNING_2 = SOUNDKIT.ALARM_CLOCK_WARNING_2,
        ALARM_CLOCK_WARNING_3 = SOUNDKIT.ALARM_CLOCK_WARNING_3,
        UI_BONUS_LOOT_ROLL_END = SOUNDKIT.UI_BONUS_LOOT_ROLL_END,
    }
    
    yOffset = yOffset - 30
    
    -- Blizzard sound dropdown
    local guildBlizzSoundLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    guildBlizzSoundLabel:SetPoint("TOPLEFT", 40, yOffset)
    guildBlizzSoundLabel:SetText("Blizzard Sound:")
    
    local guildBlizzSoundDropdown = CreateFrame("Frame", "TweaksUIGuildBlizzSoundDropdown", content, "UIDropDownMenuTemplate")
    guildBlizzSoundDropdown:SetPoint("LEFT", guildBlizzSoundLabel, "RIGHT", 0, -2)
    UIDropDownMenu_SetWidth(guildBlizzSoundDropdown, 120)
    
    local currentGuildBlizzSoundName = "Whisper"
    for _, opt in ipairs(GUILD_BLIZZARD_OPTIONS) do
        if opt.id == settings.guildAlertSoundId then
            currentGuildBlizzSoundName = opt.name
            break
        end
    end
    UIDropDownMenu_SetText(guildBlizzSoundDropdown, currentGuildBlizzSoundName)
    
    UIDropDownMenu_Initialize(guildBlizzSoundDropdown, function(self, level)
        for _, opt in ipairs(GUILD_BLIZZARD_OPTIONS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = opt.name
            info.checked = (settings.guildAlertSoundId == opt.id)
            info.func = function()
                settings.guildAlertSoundId = opt.id
                UIDropDownMenu_SetText(guildBlizzSoundDropdown, opt.name)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    
    yOffset = yOffset - 30
    
    -- Custom (LSM) sound dropdown
    local guildCustomSoundLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    guildCustomSoundLabel:SetPoint("TOPLEFT", 40, yOffset)
    guildCustomSoundLabel:SetText("Custom Sound:")
    
    local guildCustomSoundDropdown = CreateFrame("Frame", "TweaksUIGuildCustomSoundDropdown", content, "UIDropDownMenuTemplate")
    guildCustomSoundDropdown:SetPoint("LEFT", guildCustomSoundLabel, "RIGHT", 0, -2)
    UIDropDownMenu_SetWidth(guildCustomSoundDropdown, 140)
    UIDropDownMenu_SetText(guildCustomSoundDropdown, settings.guildAlertSoundLSM or "None")
    
    UIDropDownMenu_Initialize(guildCustomSoundDropdown, function(self, level)
        local soundList = TweaksUI.Media:GetSoundList()
        for _, soundName in ipairs(soundList) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = soundName
            info.checked = (settings.guildAlertSoundLSM == soundName)
            info.func = function()
                settings.guildAlertSoundLSM = soundName
                UIDropDownMenu_SetText(guildCustomSoundDropdown, soundName)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    
    -- Play button to preview selected sound
    local guildPlayBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    guildPlayBtn:SetPoint("LEFT", guildCustomSoundDropdown, "RIGHT", -10, 2)
    guildPlayBtn:SetSize(50, 22)
    guildPlayBtn:SetText("Play")
    guildPlayBtn:SetScript("OnClick", function()
        if settings.guildAlertSoundSource == "custom" and settings.guildAlertSoundLSM and settings.guildAlertSoundLSM ~= "None" then
            TweaksUI.Media:PlaySound(settings.guildAlertSoundLSM)
        else
            local soundId = GUILD_BLIZZARD_SOUNDS[settings.guildAlertSoundId] or SOUNDKIT.TELL_MESSAGE
            PlaySound(soundId)
        end
    end)
    
    -- Initialize source dropdown
    UIDropDownMenu_Initialize(guildSourceDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        info.text = "Blizzard"
        info.checked = (settings.guildAlertSoundSource ~= "custom")
        info.func = function()
            settings.guildAlertSoundSource = "blizzard"
            UIDropDownMenu_SetText(guildSourceDropdown, "Blizzard")
        end
        UIDropDownMenu_AddButton(info)
        
        info = UIDropDownMenu_CreateInfo()
        info.text = "Custom (LSM)"
        info.checked = (settings.guildAlertSoundSource == "custom")
        info.func = function()
            settings.guildAlertSoundSource = "custom"
            UIDropDownMenu_SetText(guildSourceDropdown, "Custom (LSM)")
        end
        UIDropDownMenu_AddButton(info)
    end)
    
    yOffset = yOffset - 30
    
    local guildFlashCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    guildFlashCheck:SetPoint("TOPLEFT", 20, yOffset)
    guildFlashCheck:SetSize(22, 22)
    guildFlashCheck.text:SetText("Flash taskbar")
    guildFlashCheck:SetChecked(settings.guildAlertFlash)
    guildFlashCheck:SetScript("OnClick", function(self)
        settings.guildAlertFlash = self:GetChecked()
    end)
    yOffset = yOffset - 35
    
    -- ========== CHAT FILTERS SECTION ==========
    local filterHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    filterHeader:SetPoint("TOPLEFT", 0, yOffset)
    filterHeader:SetText("|cffffd100Chat Filters|r")
    yOffset = yOffset - 25
    
    local filterGoldCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    filterGoldCheck:SetPoint("TOPLEFT", 0, yOffset)
    filterGoldCheck:SetSize(22, 22)
    filterGoldCheck.text:SetText("Filter gold seller spam")
    filterGoldCheck:SetChecked(settings.filterGoldSellers)
    filterGoldCheck:SetScript("OnClick", function(self)
        settings.filterGoldSellers = self:GetChecked()
    end)
    yOffset = yOffset - 25
    
    -- Custom filters
    local customFilterLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    customFilterLabel:SetPoint("TOPLEFT", 0, yOffset)
    customFilterLabel:SetText("Custom filter words (comma separated):")
    yOffset = yOffset - 20
    
    local customFilterInput = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    customFilterInput:SetPoint("TOPLEFT", 0, yOffset)
    customFilterInput:SetSize(300, 25)
    customFilterInput:SetAutoFocus(false)
    customFilterInput:SetText(table.concat(settings.customFilters or {}, ", "))
    
    -- Function to save the filters
    local function SaveCustomFilters(editBox)
        local text = editBox:GetText()
        settings.customFilters = {}
        for word in text:gmatch("[^,]+") do
            word = word:match("^%s*(.-)%s*$")  -- trim
            if word and word ~= "" then
                table.insert(settings.customFilters, word)
            end
        end
    end
    
    customFilterInput:SetScript("OnEnterPressed", function(self)
        SaveCustomFilters(self)
        self:ClearFocus()
    end)
    
    customFilterInput:SetScript("OnEditFocusLost", function(self)
        SaveCustomFilters(self)
    end)
    
    customFilterInput:SetScript("OnEscapePressed", function(self)
        SaveCustomFilters(self)
        self:ClearFocus()
    end)
    yOffset = yOffset - 35
    
    -- ========== SOCIAL NOTIFICATIONS SECTION ==========
    local socialHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    socialHeader:SetPoint("TOPLEFT", 0, yOffset)
    socialHeader:SetText("|cffffd100Social Notifications|r")
    yOffset = yOffset - 25
    
    local friendStatusCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    friendStatusCheck:SetPoint("TOPLEFT", 0, yOffset)
    friendStatusCheck:SetSize(22, 22)
    friendStatusCheck.text:SetText("Show friend online/offline")
    friendStatusCheck:SetChecked(settings.showFriendStatus)
    friendStatusCheck:SetScript("OnClick", function(self)
        settings.showFriendStatus = self:GetChecked()
    end)
    yOffset = yOffset - 25
    
    local guildStatusCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    guildStatusCheck:SetPoint("TOPLEFT", 0, yOffset)
    guildStatusCheck:SetSize(22, 22)
    guildStatusCheck.text:SetText("Show guild member online/offline")
    guildStatusCheck:SetChecked(settings.showGuildStatus)
    guildStatusCheck:SetScript("OnClick", function(self)
        settings.showGuildStatus = self:GetChecked()
    end)
    yOffset = yOffset - 35
    
    chatPanels["alerts"] = panel
end

-- ============================================================================
-- APPLY ALL NEW FEATURES
-- ============================================================================

function Chat:ApplyAllNewFeatures()
    self:SetupMessageFading()
    self:SetupStickyChat()
    self:SetupClickActions()
    self:SetupSocialNotifications()
    self:SetupWhisperHandler()
end

-- ============================================================================
-- MESSAGE PROCESSING WITH NEW FEATURES
-- ============================================================================

function Chat:ProcessMessageWithFeatures(text, sender, event)
    local settings = self:GetSettings()
    
    -- Check filters first
    local shouldFilter, reason = self:ShouldFilterMessage(text, event, sender)
    if shouldFilter then
        TweaksUI:PrintDebug("Filtered message: " .. (reason or "unknown"))
        return nil
    end
    
    -- Apply URL formatting
    text = self:FormatURLs(text)
    
    -- Apply short channel names
    text = self:ShortenChannelName(text)
    
    -- Apply class colors to sender name
    if sender then
        text = self:ColorPlayerName(sender, text)
    end
    
    -- Check for mentions (don't alert on our own messages)
    local playerName = UnitName("player")
    if sender and sender ~= playerName then
        if self:CheckForMention(text) then
            self:TriggerMentionAlert()
        end
    end
    
    -- Handle whisper tabs
    if settings.enableWhisperTabs and (event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER") then
        self:HandleWhisperTab(sender)
    end
    
    return text
end

-- ============================================================================
-- LAYOUT INTEGRATION
-- ============================================================================

local chatLayoutWrapper = nil

function Chat:RegisterWithLayout()
    if not customChatFrame then return end
    if chatLayoutWrapper then return end  -- Already registered
    
    local Layout = TweaksUI.Layout
    local TUIFrame = TweaksUI.TUIFrame
    
    if not Layout or not TUIFrame then
        TweaksUI:PrintDebug("Chat: Layout or TUIFrame not available")
        return
    end
    
    local width = customChatFrame:GetWidth() or 430
    local height = customChatFrame:GetHeight() or 200
    
    -- Get current position
    local point, _, relPoint, x, y = customChatFrame:GetPoint(1)
    point = point or "BOTTOMLEFT"
    x = x or 20
    y = y or 20
    
    TweaksUI:PrintDebug("Chat: Registering with Layout (" .. width .. "x" .. height .. ")")
    
    -- Create TUIFrame wrapper
    chatLayoutWrapper = TUIFrame:New("chat", {
        width = width,
        height = height,
        name = "Chat Frame",
    })
    
    if not chatLayoutWrapper then
        TweaksUI:PrintDebug("Chat: Failed to create TUIFrame")
        return
    end
    
    -- Position wrapper at frame's current position
    chatLayoutWrapper.frame:ClearAllPoints()
    chatLayoutWrapper.frame:SetPoint(point, UIParent, point, x, y)
    chatLayoutWrapper.frame:SetSize(width, height)
    
    -- Parent the chat frame to the wrapper
    customChatFrame:SetParent(chatLayoutWrapper.frame)
    customChatFrame:ClearAllPoints()
    customChatFrame:SetPoint("TOPLEFT", chatLayoutWrapper.frame, "TOPLEFT", 0, 0)
    customChatFrame:SetPoint("BOTTOMRIGHT", chatLayoutWrapper.frame, "BOTTOMRIGHT", 0, 0)
    
    -- Disable chat frame's own move handling - Layout handles positioning now
    -- (Keep resize functionality though)
    customChatFrame:SetMovable(false)
    
    -- Register with Layout module
    local settings = self:GetSettings()
    Layout:RegisterElement("chat", {
        name = "Chat Frame",
        category = Layout.CATEGORIES.CHAT,
        tuiFrame = chatLayoutWrapper,
        defaultPosition = { point = point, x = x, y = y },
        onPositionChanged = function(id, saveData)
            -- Save position to our settings
            if saveData and settings then
                settings.framePoint = saveData.point or "BOTTOMLEFT"
                settings.frameRelativePoint = saveData.point or "BOTTOMLEFT"
                settings.frameX = saveData.x
                settings.frameY = saveData.y
            end
        end,
    })
    
    TweaksUI:PrintDebug("Chat: Registered with Layout")
end

-- Save settings to database
function Chat:SaveSettings()
    if settings then
        TweaksUI.Database:SetModuleSettings(TweaksUI.MODULE_IDS.CHAT, settings)
    end
end

-- Return the module
return Chat
