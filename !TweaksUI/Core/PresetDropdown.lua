-- TweaksUI Preset Dropdown Component
-- Reusable preset selector for module settings panels (1.5.0+)

local ADDON_NAME, TweaksUI = ...

TweaksUI.PresetDropdown = {}
local PresetDropdown = TweaksUI.PresetDropdown

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local DROPDOWN_WIDTH = 180
local BUTTON_HEIGHT = 24
local COLORS = {
    gold = { 1, 0.82, 0 },
    green = { 0.3, 0.8, 0.3 },
    gray = { 0.6, 0.6, 0.6 },
}

-- ============================================================================
-- STATIC POPUPS
-- ============================================================================

StaticPopupDialogs["TWEAKSUI_SAVE_MODULE_PRESET"] = {
    text = "Save current %s settings as preset:\n\nEnter preset name:",
    button1 = "Save",
    button2 = "Cancel",
    hasEditBox = true,
    maxLetters = 40,
    OnAccept = function(self, data)
        local text = self.EditBox:GetText()
        if text and text ~= "" then
            local success, err = TweaksUI.Presets:SaveCurrentAsPreset(data.moduleId, text)
            if success then
                TweaksUI:Print("Preset saved: " .. text)
                if data.dropdown then
                    PresetDropdown:RefreshDropdown(data.dropdown, data.moduleId)
                end
            else
                TweaksUI:PrintError(err or "Failed to save preset")
            end
        end
    end,
    OnShow = function(self, data)
        self.EditBox:SetText("")
        self.EditBox:SetFocus()
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        local text = self:GetText()
        if text and text ~= "" and parent.data then
            local success, err = TweaksUI.Presets:SaveCurrentAsPreset(parent.data.moduleId, text)
            if success then
                TweaksUI:Print("Preset saved: " .. text)
                if parent.data.dropdown then
                    PresetDropdown:RefreshDropdown(parent.data.dropdown, parent.data.moduleId)
                end
            else
                TweaksUI:PrintError(err or "Failed to save preset")
            end
        end
        parent:Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["TWEAKSUI_DELETE_MODULE_PRESET"] = {
    text = "Delete preset \"%s\"?\n\nThis cannot be undone.",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function(self, data)
        local success, err = TweaksUI.Presets:DeleteUserPreset(data.moduleId, data.presetName)
        if success then
            TweaksUI:Print("Preset deleted: " .. data.presetName)
            if data.dropdown then
                PresetDropdown:RefreshDropdown(data.dropdown, data.moduleId)
            end
        else
            TweaksUI:PrintError(err or "Failed to delete preset")
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["TWEAKSUI_APPLY_PRESET_CONFIRM"] = {
    text = "Apply preset \"%s\" to %s?\n\nThis will overwrite your current settings.",
    button1 = "Apply",
    button2 = "Cancel",
    OnAccept = function(self, data)
        local success, result = TweaksUI.Presets:ApplyPreset(data.moduleId, data.presetName, {
            scaleToResolution = true,
            createBackup = TweaksUI.Presets:IsAutoBackupEnabled(),
        })
        if success then
            TweaksUI:Print("Applied preset: " .. data.presetName)
            if result == "NEEDS_RELOAD" then
                StaticPopup_Show("TWEAKSUI_RELOAD_AFTER_PRESET")
            end
        else
            TweaksUI:PrintError(result or "Failed to apply preset")
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["TWEAKSUI_RELOAD_AFTER_PRESET"] = {
    text = "Preset applied. Some settings require a UI reload to take effect.\n\nReload now?",
    button1 = "Reload Now",
    button2 = "Later",
    OnAccept = function()
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- ============================================================================
-- DROPDOWN CREATION
-- ============================================================================

--[[
    Creates a preset dropdown row that can be added to any module's settings panel.
    
    @param parent - The parent frame to attach to
    @param moduleId - The module identifier (e.g., "cooldowns", "nameplates")
    @param moduleName - Display name for the module (e.g., "Cooldowns", "Nameplates")
    @param yOffset - Y offset from parent's TOPLEFT
    @param options - Optional table with:
        - width: dropdown width (default 180)
        - showSaveButton: show "Save as Preset" button (default true)
        - showDeleteButton: show delete button for user presets (default true)
        - onPresetApplied: callback function(presetName) called after preset applied
    
    @return container frame, next yOffset
]]
function PresetDropdown:Create(parent, moduleId, moduleName, yOffset, options)
    options = options or {}
    local dropdownWidth = options.width or DROPDOWN_WIDTH
    
    -- Container for the whole section
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", 0, yOffset)
    container:SetPoint("TOPRIGHT", 0, yOffset)
    container:SetHeight(70)  -- Taller for stacked layout
    container.moduleId = moduleId
    container.moduleName = moduleName
    
    -- Label
    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 10, 0)
    label:SetText("Preset:")
    label:SetTextColor(unpack(COLORS.gold))
    
    -- Dropdown (centered)
    local dropdownName = "TweaksUI_PresetDropdown_" .. moduleId
    local dropdown = CreateFrame("Frame", dropdownName, container, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOP", -10, -12)
    UIDropDownMenu_SetWidth(dropdown, dropdownWidth)
    UIDropDownMenu_SetText(dropdown, "Current Settings")
    dropdown.moduleId = moduleId
    dropdown.selectedPreset = nil
    container.dropdown = dropdown
    
    -- Initialize dropdown
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        PresetDropdown:InitializeDropdownMenu(self, level, moduleId, moduleName)
    end)
    
    -- Button row (below dropdown)
    local buttonY = -42
    local buttonSpacing = 5
    
    -- Apply button
    local applyBtn = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
    applyBtn:SetSize(70, BUTTON_HEIGHT - 2)
    applyBtn:SetText("Apply")
    applyBtn:Disable()  -- Disabled until a preset is selected
    applyBtn:SetScript("OnClick", function()
        if dropdown.selectedPreset then
            local dialog = StaticPopup_Show("TWEAKSUI_APPLY_PRESET_CONFIRM", dropdown.selectedPreset, moduleName)
            if dialog then
                dialog.data = {
                    moduleId = moduleId,
                    presetName = dropdown.selectedPreset,
                    onApplied = options.onPresetApplied,
                }
            end
        end
    end)
    container.applyBtn = applyBtn
    
    -- Save as Preset button
    local saveBtn = nil
    if options.showSaveButton ~= false then
        saveBtn = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
        saveBtn:SetSize(90, BUTTON_HEIGHT - 2)
        saveBtn:SetText("Save Preset")
        saveBtn:SetScript("OnClick", function()
            local dialog = StaticPopup_Show("TWEAKSUI_SAVE_MODULE_PRESET", moduleName)
            if dialog then
                dialog.data = {
                    moduleId = moduleId,
                    dropdown = dropdown,
                }
            end
        end)
        container.saveBtn = saveBtn
    end
    
    -- Center the buttons
    if saveBtn then
        -- Both buttons - center them together
        local totalWidth = 70 + buttonSpacing + 90
        applyBtn:SetPoint("TOP", container, "TOP", -totalWidth/2 + 35, buttonY)
        saveBtn:SetPoint("LEFT", applyBtn, "RIGHT", buttonSpacing, 0)
    else
        -- Just apply button
        applyBtn:SetPoint("TOP", container, "TOP", 0, buttonY)
    end
    
    -- Separator line below
    local sep = container:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", 10, -65)
    sep:SetPoint("TOPRIGHT", -10, -65)
    sep:SetHeight(1)
    sep:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    
    return container, yOffset - 70
end

-- ============================================================================
-- DROPDOWN MENU INITIALIZATION
-- ============================================================================

function PresetDropdown:InitializeDropdownMenu(dropdown, level, moduleId, moduleName)
    local info = UIDropDownMenu_CreateInfo()
    
    -- Level 1: Main menu
    if level == 1 or level == nil then
        -- Get presets for this module
        local builtIn = TweaksUI.Presets:GetBuiltInPresets(moduleId) or {}
        local userPresets = TweaksUI.Presets:GetUserPresets(moduleId) or {}
        
        -- "Current Settings" option (resets selection)
        info.text = "Current Settings"
        info.value = nil
        info.checked = (dropdown.selectedPreset == nil)
        info.func = function()
            dropdown.selectedPreset = nil
            UIDropDownMenu_SetText(dropdown, "Current Settings")
            if dropdown:GetParent().applyBtn then
                dropdown:GetParent().applyBtn:Disable()
            end
            CloseDropDownMenus()
        end
        UIDropDownMenu_AddButton(info, level)
        
        -- Built-in presets section
        if next(builtIn) then
            info = UIDropDownMenu_CreateInfo()
            info.text = "|cff888888Built-in Presets|r"
            info.isTitle = true
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
            
            for presetName, _ in pairs(builtIn) do
                info = UIDropDownMenu_CreateInfo()
                info.text = presetName
                info.value = presetName
                info.checked = (dropdown.selectedPreset == presetName)
                info.func = function()
                    dropdown.selectedPreset = presetName
                    UIDropDownMenu_SetText(dropdown, presetName)
                    if dropdown:GetParent().applyBtn then
                        dropdown:GetParent().applyBtn:Enable()
                    end
                    CloseDropDownMenus()
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end
        
        -- User presets section
        if next(userPresets) then
            info = UIDropDownMenu_CreateInfo()
            info.text = "|cff888888Your Presets|r"
            info.isTitle = true
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
            
            for presetName, _ in pairs(userPresets) do
                info = UIDropDownMenu_CreateInfo()
                info.text = presetName
                info.value = { type = "userPreset", name = presetName, moduleId = moduleId }
                info.checked = (dropdown.selectedPreset == presetName)
                info.hasArrow = true  -- Sub-menu for delete option
                info.notCheckable = false
                info.func = function()
                    dropdown.selectedPreset = presetName
                    UIDropDownMenu_SetText(dropdown, presetName)
                    if dropdown:GetParent().applyBtn then
                        dropdown:GetParent().applyBtn:Enable()
                    end
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end
        
        -- No presets message
        if not next(builtIn) and not next(userPresets) then
            info = UIDropDownMenu_CreateInfo()
            info.text = "|cff888888No presets available|r"
            info.disabled = true
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
        end
    
    -- Level 2: Submenu for user presets (delete option)
    elseif level == 2 then
        local menuValue = UIDROPDOWNMENU_MENU_VALUE
        if menuValue and type(menuValue) == "table" and menuValue.type == "userPreset" then
            local presetName = menuValue.name
            local presetModuleId = menuValue.moduleId
            
            -- Delete option
            info = UIDropDownMenu_CreateInfo()
            info.text = "|cffff6666Delete|r"
            info.notCheckable = true
            info.func = function()
                CloseDropDownMenus()
                local dialog = StaticPopup_Show("TWEAKSUI_DELETE_MODULE_PRESET", presetName)
                if dialog then
                    dialog.data = {
                        moduleId = presetModuleId,
                        presetName = presetName,
                        dropdown = dropdown,
                    }
                end
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end
end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

function PresetDropdown:RefreshDropdown(dropdown, moduleId)
    if not dropdown then return end
    
    -- Reset selection
    dropdown.selectedPreset = nil
    UIDropDownMenu_SetText(dropdown, "Current Settings")
    if dropdown:GetParent().applyBtn then
        dropdown:GetParent().applyBtn:Disable()
    end
    
    -- Re-initialize
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        PresetDropdown:InitializeDropdownMenu(self, level, moduleId, dropdown:GetParent().moduleName)
    end)
end

--[[
    Convenience function to add a preset dropdown to a module's settings content frame.
    Returns the new yOffset after the dropdown row.
    
    Usage in module settings panel:
        local yOffset = 0
        _, yOffset = TweaksUI.PresetDropdown:AddToPanel(content, "cooldowns", "Cooldowns", yOffset)
        -- Continue adding other settings below...
]]
function PresetDropdown:AddToPanel(parent, moduleId, moduleName, yOffset, options)
    return self:Create(parent, moduleId, moduleName, yOffset, options)
end

--[[
    Gets the list of preset names for a module (for Quick Setup dropdowns).
    Returns { builtIn = {name1, name2, ...}, user = {name1, name2, ...} }
]]
function PresetDropdown:GetPresetList(moduleId)
    local result = { builtIn = {}, user = {} }
    
    local builtIn = TweaksUI.Presets:GetBuiltInPresets(moduleId) or {}
    for name, _ in pairs(builtIn) do
        table.insert(result.builtIn, name)
    end
    table.sort(result.builtIn)
    
    local userPresets = TweaksUI.Presets:GetUserPresets(moduleId) or {}
    for name, _ in pairs(userPresets) do
        table.insert(result.user, name)
    end
    table.sort(result.user)
    
    return result
end
